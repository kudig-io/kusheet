# HPA 与 VPA 自动扩缩容故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32, metrics-server v0.6+ | **最后更新**: 2026-01 | **难度**: 中级-高级
>
> **版本说明**:
> - v1.25+ HPA v2 API GA (autoscaling/v2)
> - v1.26+ 支持 HPA 的 ContainerResource metrics
> - v1.27+ HPAContainerMetrics GA
> - VPA v1.0+ 支持推荐模式和自动更新模式

## 概述

Horizontal Pod Autoscaler (HPA) 和 Vertical Pod Autoscaler (VPA) 是 Kubernetes 的自动扩缩容机制。HPA 通过调整 Pod 副本数实现水平扩展，VPA 通过调整 Pod 资源请求/限制实现垂直扩展。本文档覆盖自动扩缩容相关故障的诊断与解决方案。

---

## 第一部分：问题现象与影响分析

### 1.1 自动扩缩容架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    Metrics Pipeline                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │   kubelet    │───▶│ metrics-server│───▶│  API Server  │       │
│  │  (cAdvisor)  │    │              │    │ (metrics.k8s.io) │    │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
│                                                  │               │
│  ┌──────────────┐    ┌──────────────┐           │               │
│  │  Prometheus  │───▶│ Prometheus   │───────────┘               │
│  │              │    │   Adapter    │  (custom.metrics.k8s.io)   │
│  └──────────────┘    └──────────────┘                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              HPA Controller / VPA Recommender                    │
│                                                                  │
│  ┌────────────────────┐    ┌────────────────────┐               │
│  │        HPA         │    │        VPA         │               │
│  │  (水平扩缩 - 副本数) │    │  (垂直扩缩 - 资源)  │               │
│  │                    │    │                    │               │
│  │  - 目标利用率       │    │  - 资源推荐         │               │
│  │  - 最小/最大副本    │    │  - 自动更新 Pod     │               │
│  │  - 扩缩策略         │    │  - 更新模式         │               │
│  └────────────────────┘    └────────────────────┘               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 HPA 常见问题

| 问题类型 | 现象描述 | 错误信息示例 | 查看方式 |
|---------|---------|-------------|---------|
| 指标获取失败 | HPA 显示 unknown 或 <unknown> | `unable to get metrics for resource` | `kubectl get hpa` |
| 不扩容 | 负载高但副本数不变 | `ScalingActive False` | `kubectl describe hpa` |
| 不缩容 | 负载低但副本数不减少 | 副本数持续高于 minReplicas | `kubectl get hpa` |
| 扩容振荡 | 副本数频繁增减 | 事件显示反复 SuccessfulRescale | `kubectl describe hpa` |
| 扩容不足 | 副本数达到 max 但仍不够 | `ScaleUpLimit` | `kubectl describe hpa` |
| metrics-server 故障 | 所有 HPA 失效 | `the HPA was unable to compute the replica count` | API Server 日志 |

### 1.3 VPA 常见问题

| 问题类型 | 现象描述 | 错误信息示例 | 查看方式 |
|---------|---------|-------------|---------|
| 推荐值不生成 | VPA status 中无推荐值 | `recommendation` 为空 | `kubectl describe vpa` |
| Pod 不更新 | VPA 有推荐但 Pod 资源不变 | updateMode 配置问题 | `kubectl describe vpa` |
| 资源推荐过大/过小 | 推荐值与实际需求差距大 | 应用性能问题 | `kubectl describe vpa` |
| VPA 与 HPA 冲突 | 资源和副本同时变化 | 扩缩容行为异常 | 同时检查 HPA 和 VPA |
| Pod 重启过频 | VPA 频繁调整导致重启 | Pod 频繁 Terminating | `kubectl get pods -w` |
| VPA 组件故障 | Recommender/Updater 不工作 | VPA 相关 Pod 异常 | `kubectl get pods -n kube-system` |

### 1.4 影响分析

| 故障类型 | 直接影响 | 间接影响 | 影响范围 |
|---------|---------|---------|---------|
| HPA 不扩容 | 服务过载，响应变慢 | 用户体验下降，可能级联故障 | 受影响的服务 |
| HPA 不缩容 | 资源浪费 | 成本增加，资源紧张 | 集群资源 |
| HPA 振荡 | 服务不稳定，频繁扩缩 | 连接中断，服务质量波动 | 受影响的服务及其客户端 |
| metrics-server 故障 | 所有 HPA 失效 | kubectl top 不可用 | 整个集群 |
| VPA 过度调整 | Pod 频繁重启 | 服务可用性下降 | 受影响的工作负载 |

---

## 第二部分：排查原理与方法

### 2.1 HPA 工作原理

```
HPA 扩缩容决策流程
        │
        ▼
┌─────────────────────┐
│  1. 获取当前指标值   │ ◄── metrics-server / custom metrics
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  2. 计算期望副本数   │ ◄── desiredReplicas = currentReplicas * (currentMetric / targetMetric)
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  3. 应用稳定窗口    │ ◄── 扩容: 3分钟 (默认)，缩容: 5分钟 (默认)
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  4. 应用扩缩策略    │ ◄── behavior.scaleUp / behavior.scaleDown
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  5. 限制在 min/max  │ ◄── minReplicas <= replicas <= maxReplicas
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  6. 更新目标副本数   │ ◄── 修改 Deployment/StatefulSet replicas
└─────────────────────┘
```

### 2.2 排查决策树

```
HPA/VPA 故障
     │
     ├─── HPA 显示 <unknown>？
     │         │
     │         ├─ metrics-server 运行？ ──→ 检查 metrics-server Pod
     │         ├─ API 可用？ ──→ kubectl top nodes/pods
     │         └─ 目标有 resources.requests？ ──→ 添加资源请求
     │
     ├─── HPA 不扩容？
     │         │
     │         ├─ 当前指标低于阈值 ──→ 检查指标计算方式
     │         ├─ 已达到 maxReplicas ──→ 调整 max 或优化应用
     │         ├─ 扩容策略限制 ──→ 检查 behavior.scaleUp
     │         └─ ScalingActive=False ──→ 查看具体原因
     │
     ├─── HPA 不缩容？
     │         │
     │         ├─ 稳定窗口内 ──→ 等待稳定窗口过期
     │         ├─ 缩容策略限制 ──→ 检查 behavior.scaleDown
     │         └─ 指标仍高于目标 ──→ 验证指标准确性
     │
     ├─── VPA 不推荐/不更新？
     │         │
     │         ├─ Recommender 运行？ ──→ 检查 vpa-recommender Pod
     │         ├─ updateMode 配置 ──→ 检查是否为 "Off"
     │         ├─ 数据不足 ──→ 等待收集更多数据
     │         └─ Pod 控制器不支持 ──→ 检查 targetRef
     │
     └─── metrics-server 故障？
               │
               ├─ Pod 状态 ──→ kubectl get pods -n kube-system
               ├─ 证书问题 ──→ 检查 --kubelet-insecure-tls
               └─ 资源不足 ──→ 检查 metrics-server 资源使用
```

### 2.3 排查命令集

#### 2.3.1 HPA 基础检查

```bash
# 查看 HPA 状态
kubectl get hpa -o wide

# 查看 HPA 详细信息
kubectl describe hpa <name>

# 查看 HPA YAML
kubectl get hpa <name> -o yaml

# 查看 HPA 事件
kubectl get events --field-selector involvedObject.kind=HorizontalPodAutoscaler

# 检查目标工作负载
kubectl get deployment <name> -o jsonpath='{.spec.replicas}'
```

#### 2.3.2 metrics-server 检查

```bash
# 检查 metrics-server 状态
kubectl get pods -n kube-system -l k8s-app=metrics-server

# 查看 metrics-server 日志
kubectl logs -n kube-system -l k8s-app=metrics-server

# 测试 metrics API
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods"

# 验证 kubectl top 命令
kubectl top nodes
kubectl top pods

# 检查 API 服务注册
kubectl get apiservices | grep metrics
```

#### 2.3.3 自定义指标检查

```bash
# 检查 custom metrics API
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1" | jq

# 查看可用的自定义指标
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/<ns>/pods/*/requests_per_second" | jq

# 检查 prometheus-adapter 状态
kubectl get pods -n monitoring -l app=prometheus-adapter
kubectl logs -n monitoring -l app=prometheus-adapter
```

#### 2.3.4 VPA 检查

```bash
# 查看 VPA 状态
kubectl get vpa -o wide

# 查看 VPA 详细信息和推荐值
kubectl describe vpa <name>

# 查看 VPA YAML
kubectl get vpa <name> -o yaml

# 检查 VPA 组件状态
kubectl get pods -n kube-system | grep vpa

# 查看 VPA Recommender 日志
kubectl logs -n kube-system -l app=vpa-recommender

# 查看 VPA Updater 日志
kubectl logs -n kube-system -l app=vpa-updater
```

### 2.4 排查注意事项

| 注意事项 | 说明 |
|---------|-----|
| 资源请求必需 | HPA (CPU/内存) 需要 Pod 设置 resources.requests |
| 稳定窗口 | HPA 默认扩容等待 3 分钟，缩容等待 5 分钟 |
| 指标延迟 | metrics-server 默认每 15 秒采集一次 |
| VPA 重启 Pod | VPA 更新资源需要重建 Pod |
| HPA 与 VPA | 不建议同时使用 HPA 和 VPA 针对 CPU/内存 |
| 最小副本数 | minReplicas 不能为 0 (除非启用 scale to zero) |

---

## 第三部分：解决方案与风险控制

### 3.1 HPA 指标获取问题

#### 场景 1：HPA 显示 <unknown>

**问题现象：**
```bash
$ kubectl get hpa
NAME      REFERENCE            TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
myapp     Deployment/myapp     <unknown>/50%   1         10        1          5m
```

**解决步骤：**

```bash
# 1. 检查 metrics-server 状态
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl logs -n kube-system -l k8s-app=metrics-server

# 2. 测试 metrics API
kubectl top pods
# 如果报错，说明 metrics-server 有问题

# 3. 检查 Pod 是否设置了资源请求
kubectl get deployment <name> -o jsonpath='{.spec.template.spec.containers[*].resources}'

# 4. 如果没有资源请求，添加 resources.requests
kubectl patch deployment <name> --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/resources", "value": {
    "requests": {
      "cpu": "100m",
      "memory": "128Mi"
    },
    "limits": {
      "cpu": "500m",
      "memory": "512Mi"
    }
  }}
]'

# 5. 等待 Pod 重建后再次检查 HPA
kubectl get hpa -w
```

#### 场景 2：修复 metrics-server

**常见问题及解决：**

```bash
# 问题 1: metrics-server 无法启动 (证书问题)
# 解决: 添加 --kubelet-insecure-tls 参数
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}
]'

# 问题 2: metrics-server 无法连接 kubelet
# 解决: 添加 --kubelet-preferred-address-types
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"}
]'

# 问题 3: metrics-server 资源不足
# 解决: 增加资源限制
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value": "200m"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "256Mi"}
]'

# 问题 4: 重新安装 metrics-server
kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

---

### 3.2 HPA 扩缩容问题

#### 场景 1：HPA 不扩容

**问题现象：**
CPU 使用率超过目标但副本数不增加

**解决步骤：**

```bash
# 1. 查看 HPA 状态和条件
kubectl describe hpa <name>

# 2. 检查 ScalingActive 条件
# 如果 ScalingActive=False，查看原因

# 3. 常见原因及解决

# 原因 A: 已达到 maxReplicas
kubectl get hpa <name> -o jsonpath='{.spec.maxReplicas}'
# 解决: 增加 maxReplicas
kubectl patch hpa <name> --type='json' -p='[{"op": "replace", "path": "/spec/maxReplicas", "value": 20}]'

# 原因 B: 扩容策略限制
kubectl get hpa <name> -o jsonpath='{.spec.behavior.scaleUp}'
# 解决: 调整扩容策略
kubectl patch hpa <name> --type='json' -p='[
  {"op": "replace", "path": "/spec/behavior/scaleUp", "value": {
    "stabilizationWindowSeconds": 0,
    "policies": [
      {"type": "Percent", "value": 100, "periodSeconds": 15},
      {"type": "Pods", "value": 4, "periodSeconds": 15}
    ],
    "selectPolicy": "Max"
  }}
]'

# 原因 C: 指标计算方式 (Utilization vs AverageValue)
kubectl get hpa <name> -o yaml | grep -A5 metrics

# 4. 验证实际指标值
kubectl top pods -l <selector>

# 5. 手动计算期望副本数
# desiredReplicas = currentReplicas * (currentMetric / targetMetric)
```

#### 场景 2：HPA 不缩容

**解决步骤：**

```bash
# 1. 检查缩容稳定窗口
kubectl get hpa <name> -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}'
# 默认是 300 秒 (5 分钟)

# 2. 调整缩容稳定窗口
kubectl patch hpa <name> --type='json' -p='[
  {"op": "replace", "path": "/spec/behavior/scaleDown/stabilizationWindowSeconds", "value": 60}
]'

# 3. 检查缩容策略
kubectl get hpa <name> -o jsonpath='{.spec.behavior.scaleDown}'

# 4. 调整缩容策略 (更激进)
kubectl patch hpa <name> --type='json' -p='[
  {"op": "replace", "path": "/spec/behavior/scaleDown", "value": {
    "stabilizationWindowSeconds": 60,
    "policies": [
      {"type": "Percent", "value": 50, "periodSeconds": 15}
    ],
    "selectPolicy": "Max"
  }}
]'

# 5. 验证当前指标确实低于目标
kubectl top pods -l <selector>
```

#### 场景 3：HPA 扩容振荡

**问题现象：**
副本数频繁增加减少

**解决步骤：**

```bash
# 1. 检查事件历史
kubectl describe hpa <name> | grep -A20 Events

# 2. 增加稳定窗口
kubectl patch hpa <name> --type='json' -p='[
  {"op": "replace", "path": "/spec/behavior/scaleUp/stabilizationWindowSeconds", "value": 300},
  {"op": "replace", "path": "/spec/behavior/scaleDown/stabilizationWindowSeconds", "value": 300}
]'

# 3. 限制扩缩容速率
kubectl patch hpa <name> --type='json' -p='[
  {"op": "replace", "path": "/spec/behavior", "value": {
    "scaleUp": {
      "stabilizationWindowSeconds": 300,
      "policies": [
        {"type": "Pods", "value": 2, "periodSeconds": 60}
      ],
      "selectPolicy": "Min"
    },
    "scaleDown": {
      "stabilizationWindowSeconds": 300,
      "policies": [
        {"type": "Percent", "value": 10, "periodSeconds": 60}
      ],
      "selectPolicy": "Min"
    }
  }}
]'

# 4. 调整目标利用率，预留缓冲
# 例如从 80% 降到 70%
kubectl patch hpa <name> --type='json' -p='[
  {"op": "replace", "path": "/spec/metrics/0/resource/target/averageUtilization", "value": 70}
]'
```

---

### 3.3 VPA 问题排查

#### 场景 1：VPA 无推荐值

**问题现象：**
```bash
$ kubectl describe vpa myapp-vpa
Status:
  Recommendation:  # 空的
```

**解决步骤：**

```bash
# 1. 检查 VPA Recommender 状态
kubectl get pods -n kube-system -l app=vpa-recommender
kubectl logs -n kube-system -l app=vpa-recommender

# 2. 确认目标工作负载存在且有 Pod 运行
kubectl get deployment <target-name>
kubectl get pods -l <selector>

# 3. 确认 VPA 的 targetRef 正确
kubectl get vpa <name> -o jsonpath='{.spec.targetRef}'

# 4. VPA 需要收集足够数据才能给出推荐
# 等待至少 24 小时，或检查是否有历史数据

# 5. 检查 VPA 的 resourcePolicy
kubectl get vpa <name> -o jsonpath='{.spec.resourcePolicy}'

# 6. 如果 Recommender 有问题，重启
kubectl rollout restart deployment vpa-recommender -n kube-system
```

#### 场景 2：VPA 不更新 Pod

**问题现象：**
VPA 有推荐值但 Pod 资源未更新

**解决步骤：**

```bash
# 1. 检查 updateMode
kubectl get vpa <name> -o jsonpath='{.spec.updatePolicy.updateMode}'

# updateMode 说明:
# - "Off": 只生成推荐，不自动更新 (用于观察)
# - "Initial": 只在 Pod 创建时应用推荐
# - "Recreate": 通过驱逐 Pod 应用推荐 (需要重建)
# - "Auto": 自动选择最优方式

# 2. 如果是 "Off"，改为 "Auto" 或 "Recreate"
kubectl patch vpa <name> --type='json' -p='[
  {"op": "replace", "path": "/spec/updatePolicy/updateMode", "value": "Auto"}
]'

# 3. 检查 VPA Updater 状态
kubectl get pods -n kube-system -l app=vpa-updater
kubectl logs -n kube-system -l app=vpa-updater

# 4. 手动触发 Pod 重建 (应用推荐)
kubectl delete pod <pod-name>

# 5. 验证新 Pod 的资源配置
kubectl get pod <new-pod-name> -o jsonpath='{.spec.containers[*].resources}'
```

#### 场景 3：VPA 与 HPA 冲突

**解决方案：**

```bash
# 方案 1: HPA 使用 CPU，VPA 只管理内存
# VPA 配置
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: myapp-vpa
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: myapp
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: '*'
      controlledResources: ["memory"]  # 只管理内存
      controlledValues: RequestsAndLimits
EOF

# 方案 2: VPA 只推荐不自动更新
kubectl patch vpa <name> --type='json' -p='[
  {"op": "replace", "path": "/spec/updatePolicy/updateMode", "value": "Off"}
]'
# 然后手动参考 VPA 推荐调整资源

# 方案 3: HPA 使用自定义指标，VPA 管理 CPU/内存
# HPA 配置使用 requests_per_second 等业务指标
```

---

### 3.4 完整的 HPA 配置示例

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  
  minReplicas: 2
  maxReplicas: 20
  
  metrics:
  # CPU 指标
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  
  # 内存指标
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  
  # 自定义指标示例
  # - type: Pods
  #   pods:
  #     metric:
  #       name: requests_per_second
  #     target:
  #       type: AverageValue
  #       averageValue: 1000
  
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0  # 立即扩容
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
    
    scaleDown:
      stabilizationWindowSeconds: 300  # 5 分钟稳定窗口
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
      selectPolicy: Min
```

### 3.5 完整的 VPA 配置示例

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: myapp-vpa
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: myapp
  
  updatePolicy:
    updateMode: "Auto"  # Off, Initial, Recreate, Auto
    minReplicas: 2      # 最小保留副本数 (更新时)
  
  resourcePolicy:
    containerPolicies:
    - containerName: '*'
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 2
        memory: 4Gi
      controlledResources: ["cpu", "memory"]
      controlledValues: RequestsAndLimits  # RequestsOnly 或 RequestsAndLimits
    
    # 排除特定容器
    - containerName: sidecar
      mode: "Off"
```

---

### 3.6 监控和告警

```bash
# 监控 HPA 状态
kubectl get hpa -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.currentReplicas}{"\t"}{.status.desiredReplicas}{"\n"}{end}'

# 监控 VPA 推荐
kubectl get vpa -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.recommendation.containerRecommendations[*].target}{"\n"}{end}'

# Prometheus 告警规则示例
cat <<EOF
groups:
- name: autoscaling
  rules:
  - alert: HPAMaxedOut
    expr: |
      kube_horizontalpodautoscaler_status_current_replicas == kube_horizontalpodautoscaler_spec_max_replicas
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "HPA {{ \$labels.horizontalpodautoscaler }} 已达到最大副本数"
  
  - alert: HPANotScaling
    expr: |
      kube_horizontalpodautoscaler_status_condition{condition="ScalingActive", status="false"} == 1
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "HPA {{ \$labels.horizontalpodautoscaler }} 扩缩容失效"
EOF
```

---

### 3.7 安全生产风险提示

| 操作 | 风险等级 | 风险说明 | 建议 |
|-----|---------|---------|-----|
| 修改 maxReplicas | 中 | 可能导致资源耗尽 | 评估集群容量后设置合理上限 |
| 删除 metrics-server | 高 | 所有 HPA 失效，kubectl top 不可用 | 确保有替代监控方案 |
| VPA updateMode: Auto | 中 | 自动重建 Pod 可能影响服务 | 确保有足够副本数，设置 PDB |
| 同时使用 HPA 和 VPA | 中 | 可能产生扩缩容冲突 | VPA 只管理内存，或使用 Off 模式 |
| 缩短稳定窗口 | 低 | 可能导致扩缩容振荡 | 根据业务特点调整 |
| 过高的 maxReplicas | 中 | 资源耗尽，影响其他服务 | 配合 ResourceQuota 使用 |

---

## 附录

### 常用排查命令速查

```bash
# HPA 检查
kubectl get hpa -o wide
kubectl describe hpa <name>
kubectl top pods -l <selector>

# metrics-server 检查
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl logs -n kube-system -l k8s-app=metrics-server
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods"

# VPA 检查
kubectl get vpa -o wide
kubectl describe vpa <name>
kubectl get pods -n kube-system | grep vpa

# 手动扩缩容 (调试用)
kubectl scale deployment <name> --replicas=<n>
```

### 相关文档

- [资源配额故障排查](./01-resources-quota-troubleshooting.md)
- [Controller Manager 故障排查](../01-control-plane/04-controller-manager-troubleshooting.md)
- [Deployment 故障排查](../05-workloads/02-deployment-troubleshooting.md)
