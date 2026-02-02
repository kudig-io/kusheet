# DaemonSet 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 中级
>
> **版本说明**:
> - v1.25+ DaemonSet MaxSurge 滚动更新策略 GA
> - v1.29+ 改进的调度器抢占与 DaemonSet 交互

## 概述

DaemonSet 确保所有（或部分）节点运行一个 Pod 副本，常用于日志收集、监控代理、网络插件等系统级服务。本文档覆盖 DaemonSet 常见故障的诊断与解决方案。

---

## 第一部分：问题现象与影响分析

### 1.1 常见问题现象

| 问题类型 | 现象描述 | 错误信息示例 | 查看方式 |
|---------|---------|-------------|---------|
| Pod 未调度到节点 | 部分节点没有 DaemonSet Pod | `DESIRED` 与 `CURRENT` 不一致 | `kubectl get ds` |
| Pod 处于 Pending | DaemonSet Pod 无法调度 | `0/N nodes are available` | `kubectl describe pod` |
| Pod CrashLoopBackOff | Pod 反复重启 | `CrashLoopBackOff` | `kubectl get pods` |
| 节点污点阻止调度 | Pod 因污点无法调度到特定节点 | `node(s) had taints that the pod didn't tolerate` | `kubectl describe pod` |
| 更新卡住 | 滚动更新进度停滞 | `UPDATED` 数量不增加 | `kubectl rollout status ds` |
| 资源不足 | 节点资源不足无法运行 Pod | `Insufficient cpu/memory` | `kubectl describe pod` |
| 镜像拉取失败 | Pod 无法拉取镜像 | `ImagePullBackOff` | `kubectl describe pod` |
| 权限不足 | 容器缺少必要权限 | `permission denied` | `kubectl logs` |

### 1.2 错误信息来源

| 来源 | 查看命令 | 说明 |
|-----|---------|-----|
| DaemonSet 状态 | `kubectl get ds <name> -o wide` | 期望/当前/就绪数量 |
| DaemonSet 事件 | `kubectl describe ds <name>` | 控制器级别事件 |
| Pod 事件 | `kubectl describe pod <pod-name>` | Pod 调度和运行事件 |
| Pod 日志 | `kubectl logs <pod-name>` | 应用级别错误 |
| Controller Manager 日志 | `kubectl logs -n kube-system kube-controller-manager-<node>` | DaemonSet 控制器日志 |
| 节点状态 | `kubectl describe node <node>` | 节点污点、资源状态 |

### 1.3 影响分析

| 故障类型 | 直接影响 | 间接影响 | 影响范围 |
|---------|---------|---------|---------|
| Pod 未调度到节点 | 特定节点缺少系统服务 | 日志丢失、监控盲区、网络不通 | 受影响节点 |
| Pod CrashLoopBackOff | 系统服务不可用 | 依赖该服务的功能失效 | 单节点或全集群 |
| CNI DaemonSet 故障 | 节点网络初始化失败 | 节点上所有 Pod 无法通信 | 全集群网络 |
| 日志收集 DS 故障 | 日志无法采集 | 问题排查困难，合规风险 | 可观测性 |
| 监控代理 DS 故障 | 指标无法采集 | 告警失效，问题无法及时发现 | 监控体系 |

---

## 第二部分：排查原理与方法

### 2.1 DaemonSet 工作原理

```
┌─────────────────────────────────────────────────────────────────┐
│                    DaemonSet Controller                          │
├─────────────────────────────────────────────────────────────────┤
│  1. 监听节点变化，确保每个匹配节点运行一个 Pod                    │
│  2. 新节点加入自动调度 Pod，节点删除自动清理 Pod                  │
│  3. 通过 nodeSelector/nodeAffinity/tolerations 控制调度范围       │
│  4. 支持 RollingUpdate 和 OnDelete 两种更新策略                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      调度控制机制                                │
├──────────────────┬──────────────────┬───────────────────────────┤
│   nodeSelector   │   nodeAffinity   │      tolerations          │
│   (简单标签选择)  │  (复杂亲和性规则) │   (容忍节点污点)          │
└──────────────────┴──────────────────┴───────────────────────────┘
```

### 2.2 DaemonSet 状态字段解析

```bash
$ kubectl get ds -o wide
NAME        DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
fluentd     5         5         5       5            5           <none>          10d
```

| 字段 | 含义 | 异常判断 |
|-----|-----|---------|
| DESIRED | 应该运行 Pod 的节点数 | 与实际节点数不符可能是 selector 问题 |
| CURRENT | 当前已创建的 Pod 数 | 小于 DESIRED 说明调度有问题 |
| READY | 已就绪的 Pod 数 | 小于 CURRENT 说明 Pod 启动有问题 |
| UP-TO-DATE | 已更新到最新版本的 Pod 数 | 小于 DESIRED 说明更新未完成 |
| AVAILABLE | 可用的 Pod 数 | 小于 READY 可能是 minReadySeconds 未满足 |

### 2.3 排查决策树

```
DaemonSet 故障
       │
       ├─── DESIRED 数量不对？
       │         │
       │         ├─ 为 0 ──→ 检查 nodeSelector/nodeAffinity 配置
       │         │
       │         └─ 小于节点数 ──→ 检查节点标签匹配
       │
       ├─── CURRENT < DESIRED？
       │         │
       │         ├─ Pod Pending ──→ 检查污点容忍/资源/镜像
       │         │
       │         └─ 无 Pod 创建 ──→ 检查控制器日志
       │
       ├─── READY < CURRENT？
       │         │
       │         ├─ CrashLoopBackOff ──→ 检查应用日志/权限/配置
       │         │
       │         ├─ Running 但 NotReady ──→ 检查健康检查配置
       │         │
       │         └─ ContainerCreating ──→ 检查镜像/存储/网络
       │
       └─── UP-TO-DATE < DESIRED？
                 │
                 ├─ 更新策略 OnDelete ──→ 需手动删除旧 Pod
                 │
                 └─ RollingUpdate 卡住 ──→ 检查 maxUnavailable/Pod 问题
```

### 2.4 排查命令集

#### 2.4.1 基础状态检查

```bash
# 查看 DaemonSet 状态
kubectl get ds -o wide

# 查看详细信息和事件
kubectl describe ds <name>

# 查看 DaemonSet YAML
kubectl get ds <name> -o yaml

# 查看各节点的 Pod 分布
kubectl get pods -l <label-selector> -o wide

# 对比节点数和 Pod 数
echo "Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "DS Pods: $(kubectl get pods -l <label-selector> --no-headers | wc -l)"
```

#### 2.4.2 节点和调度检查

```bash
# 查看所有节点及其标签
kubectl get nodes --show-labels

# 查看节点污点
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# 查看特定节点详情
kubectl describe node <node-name>

# 检查 DaemonSet 的 nodeSelector
kubectl get ds <name> -o jsonpath='{.spec.template.spec.nodeSelector}'

# 检查 DaemonSet 的 tolerations
kubectl get ds <name> -o jsonpath='{.spec.template.spec.tolerations}' | jq

# 检查 DaemonSet 的 nodeAffinity
kubectl get ds <name> -o jsonpath='{.spec.template.spec.affinity.nodeAffinity}' | jq
```

#### 2.4.3 Pod 状态检查

```bash
# 查看所有 DaemonSet Pod
kubectl get pods -l <label-selector> -o wide

# 查看 Pending 状态的 Pod
kubectl get pods -l <label-selector> --field-selector=status.phase=Pending

# 查看非 Running 状态的 Pod
kubectl get pods -l <label-selector> --field-selector=status.phase!=Running

# 查看 Pod 详细事件
kubectl describe pod <pod-name>

# 查看 Pod 日志
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # 上次崩溃的日志
```

#### 2.4.4 更新状态检查

```bash
# 查看更新状态
kubectl rollout status ds <name>

# 查看更新历史
kubectl rollout history ds <name>

# 查看更新策略
kubectl get ds <name> -o jsonpath='{.spec.updateStrategy}'

# 查看各 Pod 的版本
kubectl get pods -l <label-selector> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.controller-revision-hash}{"\n"}{end}'
```

#### 2.4.5 控制器日志检查

```bash
# 查看 DaemonSet 控制器日志
kubectl logs -n kube-system -l component=kube-controller-manager --tail=100 | grep -i daemonset

# 查看特定 DaemonSet 相关日志
kubectl logs -n kube-system -l component=kube-controller-manager | grep <daemonset-name>
```

### 2.5 排查注意事项

| 注意事项 | 说明 |
|---------|-----|
| 系统关键组件 | CNI、kube-proxy 等系统 DaemonSet 故障会影响整个集群 |
| 节点污点 | 控制平面节点默认有污点，需要配置 tolerations 才能调度 |
| 资源预留 | DaemonSet Pod 在每个节点运行，需考虑节点资源容量 |
| 更新影响 | 系统级 DaemonSet 更新可能导致服务短暂中断 |
| 优先级 | 可配置 priorityClassName 确保关键 DaemonSet 优先调度 |

---

## 第三部分：解决方案与风险控制

### 3.1 Pod 未调度到节点

#### 场景 1：nodeSelector 不匹配

**问题现象：**
```bash
$ kubectl get ds
NAME      DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE
monitor   0         0         0       0            0
```

**解决步骤：**

```bash
# 1. 检查 DaemonSet 的 nodeSelector
kubectl get ds <name> -o jsonpath='{.spec.template.spec.nodeSelector}'
# 输出示例: {"disk":"ssd"}

# 2. 查看哪些节点有该标签
kubectl get nodes -l disk=ssd

# 3. 方案 A: 为节点添加标签
kubectl label nodes <node-name> disk=ssd

# 4. 方案 B: 修改 DaemonSet 的 nodeSelector
kubectl patch ds <name> --type='json' -p='[{"op": "remove", "path": "/spec/template/spec/nodeSelector"}]'

# 或修改为正确的标签
kubectl patch ds <name> --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/nodeSelector", "value": {"node-role": "worker"}}]'

# 5. 验证 Pod 调度
kubectl get pods -l <label-selector> -o wide
```

**风险提示：**
- 修改 nodeSelector 会导致 Pod 重新调度
- 确保标签变更不会影响其他工作负载

#### 场景 2：节点污点阻止调度

**问题现象：**
```
Events:
  Warning  FailedScheduling  0/5 nodes are available: 3 node(s) had taints that the pod didn't tolerate, 2 node(s) had untolerated taint {node-role.kubernetes.io/master: }
```

**解决步骤：**

```bash
# 1. 查看节点污点
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# 2. 查看 DaemonSet 当前的 tolerations
kubectl get ds <name> -o jsonpath='{.spec.template.spec.tolerations}' | jq

# 3. 添加污点容忍
kubectl patch ds <name> --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/tolerations/-", "value": {"key": "node-role.kubernetes.io/master", "operator": "Exists", "effect": "NoSchedule"}}
]'

# 4. 常见的系统污点容忍配置
# 容忍所有污点 (谨慎使用)
kubectl patch ds <name> --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/tolerations", "value": [
    {"operator": "Exists"}
  ]}
]'

# 5. 验证 Pod 调度到 master 节点
kubectl get pods -l <label-selector> -o wide | grep master
```

**常用 tolerations 配置：**

```yaml
# 容忍控制平面节点
tolerations:
- key: node-role.kubernetes.io/master
  operator: Exists
  effect: NoSchedule
- key: node-role.kubernetes.io/control-plane
  operator: Exists
  effect: NoSchedule

# 容忍 NotReady 节点 (用于网络插件等)
- key: node.kubernetes.io/not-ready
  operator: Exists
  effect: NoSchedule
- key: node.kubernetes.io/unreachable
  operator: Exists
  effect: NoSchedule
- key: node.kubernetes.io/disk-pressure
  operator: Exists
  effect: NoSchedule
- key: node.kubernetes.io/memory-pressure
  operator: Exists
  effect: NoSchedule
- key: node.kubernetes.io/network-unavailable
  operator: Exists
  effect: NoSchedule
```

---

### 3.2 Pod 启动失败

#### 场景 1：CrashLoopBackOff

**问题现象：**
```bash
$ kubectl get pods -l app=fluentd
NAME            READY   STATUS             RESTARTS   AGE
fluentd-abc12   0/1     CrashLoopBackOff   5          10m
```

**解决步骤：**

```bash
# 1. 查看 Pod 事件
kubectl describe pod <pod-name>

# 2. 查看容器日志
kubectl logs <pod-name>
kubectl logs <pod-name> --previous

# 3. 常见原因及解决方案

# 3a. 配置错误 - 检查 ConfigMap/Secret
kubectl get configmap <cm-name> -o yaml
kubectl get secret <secret-name> -o yaml

# 3b. 权限不足 - 检查 SecurityContext
kubectl get ds <name> -o jsonpath='{.spec.template.spec.containers[*].securityContext}' | jq

# 添加必要权限
kubectl patch ds <name> --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/securityContext", "value": {
    "privileged": true,
    "runAsUser": 0
  }}
]'

# 3c. 资源限制过低 - 调整 resources
kubectl patch ds <name> --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "512Mi"}
]'

# 4. 验证 Pod 恢复
kubectl get pods -l <label-selector> -w
```

#### 场景 2：权限和安全上下文问题

**问题现象：**
```
Error: permission denied
Error: cannot open /var/log/containers: Permission denied
```

**解决步骤：**

```bash
# 1. 检查当前安全上下文
kubectl get ds <name> -o yaml | grep -A20 securityContext

# 2. 为需要特权的 DaemonSet 配置安全上下文
kubectl patch ds <name> --type='strategic' -p='
spec:
  template:
    spec:
      containers:
      - name: <container-name>
        securityContext:
          privileged: true
          runAsUser: 0
          capabilities:
            add:
            - SYS_ADMIN
            - NET_ADMIN
'

# 3. 如果使用 hostPath，确保有正确的 SELinux 标签
kubectl patch ds <name> --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/securityContext/seLinuxOptions", "value": {"type": "spc_t"}}
]'

# 4. 配置 ServiceAccount (如需 API 访问)
kubectl create serviceaccount <sa-name>
kubectl create clusterrolebinding <binding-name> --clusterrole=<role> --serviceaccount=<namespace>:<sa-name>
kubectl patch ds <name> -p '{"spec":{"template":{"spec":{"serviceAccountName":"<sa-name>"}}}}'
```

---

### 3.3 更新问题

#### 场景 1：滚动更新卡住

**问题现象：**
```bash
$ kubectl rollout status ds fluentd
Waiting for daemon set "fluentd" rollout to finish: 2 out of 5 new pods have been updated...
```

**解决步骤：**

```bash
# 1. 查看更新状态详情
kubectl get ds <name> -o yaml | grep -A10 status:

# 2. 检查哪些 Pod 未更新
kubectl get pods -l <label-selector> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.nodeName}{"\t"}{.metadata.labels.controller-revision-hash}{"\n"}{end}'

# 3. 检查未更新节点上的 Pod 状态
kubectl describe pod <stuck-pod>

# 4. 查看更新策略
kubectl get ds <name> -o jsonpath='{.spec.updateStrategy}'

# 5. 如果是 maxUnavailable 限制，调整策略
kubectl patch ds <name> --type='json' -p='[
  {"op": "replace", "path": "/spec/updateStrategy/rollingUpdate/maxUnavailable", "value": 2}
]'

# 6. 如果特定 Pod 卡住，手动删除触发重建
kubectl delete pod <stuck-pod>

# 7. 验证更新继续
kubectl rollout status ds <name>
```

#### 场景 2：OnDelete 策略下的更新

**解决步骤：**

```bash
# 1. 确认更新策略
kubectl get ds <name> -o jsonpath='{.spec.updateStrategy.type}'
# 输出: OnDelete

# 2. OnDelete 策略需要手动删除 Pod 触发更新
# 查看需要更新的 Pod
kubectl get pods -l <label-selector> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.controller-revision-hash}{"\n"}{end}'

# 3. 逐个删除 Pod (DaemonSet 会自动用新版本重建)
kubectl delete pod <pod-name>

# 4. 或批量更新所有 Pod (谨慎!)
kubectl delete pods -l <label-selector>

# 5. 如需改为 RollingUpdate 策略
kubectl patch ds <name> --type='json' -p='[
  {"op": "replace", "path": "/spec/updateStrategy/type", "value": "RollingUpdate"}
]'
```

#### 场景 3：回滚更新

**解决步骤：**

```bash
# 1. 查看更新历史
kubectl rollout history ds <name>

# 2. 查看特定版本
kubectl rollout history ds <name> --revision=<n>

# 3. 回滚到上一版本
kubectl rollout undo ds <name>

# 4. 回滚到指定版本
kubectl rollout undo ds <name> --to-revision=<n>

# 5. 验证回滚
kubectl rollout status ds <name>
kubectl get pods -l <label-selector> -o wide
```

---

### 3.4 资源问题

#### 场景 1：节点资源不足

**问题现象：**
```
Events:
  Warning  FailedScheduling  0/5 nodes are available: 5 Insufficient memory.
```

**解决步骤：**

```bash
# 1. 查看节点资源使用情况
kubectl top nodes
kubectl describe nodes | grep -A10 "Allocated resources"

# 2. 查看 DaemonSet 资源需求
kubectl get ds <name> -o jsonpath='{.spec.template.spec.containers[*].resources}' | jq

# 3. 降低资源请求
kubectl patch ds <name> --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value": "128Mi"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value": "100m"}
]'

# 4. 设置资源优先级 (确保关键 DaemonSet 优先调度)
kubectl patch ds <name> -p '{"spec":{"template":{"spec":{"priorityClassName":"system-node-critical"}}}}'

# 5. 验证 Pod 调度
kubectl get pods -l <label-selector> -o wide
```

---

### 3.5 系统关键 DaemonSet 故障

#### 场景 1：CNI DaemonSet 故障 (如 Calico/Flannel)

**问题现象：**
- 节点 NotReady
- 新 Pod 无法获取 IP
- Pod 间网络不通

**解决步骤：**

```bash
# 1. 检查 CNI DaemonSet 状态
kubectl get ds -n kube-system | grep -E "calico|flannel|cilium|weave"

# 2. 查看 CNI Pod 状态
kubectl get pods -n kube-system -l k8s-app=calico-node -o wide

# 3. 检查 CNI Pod 日志
kubectl logs -n kube-system <cni-pod> -c calico-node

# 4. 检查节点上的 CNI 配置
kubectl debug node/<node> -it --image=busybox -- cat /host/etc/cni/net.d/10-calico.conflist

# 5. 重启 CNI Pod
kubectl delete pod -n kube-system <cni-pod>

# 6. 如果问题持续，检查 CNI 二进制文件
kubectl debug node/<node> -it --image=busybox -- ls -la /host/opt/cni/bin/

# 7. 验证网络恢复
kubectl run test --rm -it --image=busybox --restart=Never -- ping <other-pod-ip>
```

**风险提示：**
- CNI 故障会导致节点网络中断
- 重启 CNI Pod 可能导致短暂网络中断
- 生产环境应逐节点处理

#### 场景 2：kube-proxy DaemonSet 故障

**问题现象：**
- Service 无法访问
- ClusterIP/NodePort 不通

**解决步骤：**

```bash
# 1. 检查 kube-proxy 状态
kubectl get ds -n kube-system kube-proxy

# 2. 查看 kube-proxy Pod
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide

# 3. 查看日志
kubectl logs -n kube-system <kube-proxy-pod>

# 4. 检查 iptables/ipvs 规则
kubectl exec -n kube-system <kube-proxy-pod> -- iptables-save | grep <service-name>
# 或
kubectl exec -n kube-system <kube-proxy-pod> -- ipvsadm -Ln

# 5. 重启 kube-proxy
kubectl rollout restart ds/kube-proxy -n kube-system

# 6. 验证服务访问
kubectl run test --rm -it --image=busybox --restart=Never -- wget -qO- <service-ip>
```

---

### 3.6 完整的 DaemonSet 示例

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
  labels:
    app: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      # 容忍常见污点
      tolerations:
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node.kubernetes.io/not-ready
        operator: Exists
        effect: NoSchedule
      
      # 使用 hostNetwork 采集节点指标
      hostNetwork: true
      hostPID: true
      
      # 确保优先调度
      priorityClassName: system-node-critical
      
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.5.0
        args:
        - --path.procfs=/host/proc
        - --path.sysfs=/host/sys
        - --path.rootfs=/host/root
        ports:
        - containerPort: 9100
          hostPort: 9100
          name: metrics
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
        securityContext:
          privileged: true
          runAsUser: 0
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: root
          mountPath: /host/root
          readOnly: true
        readinessProbe:
          httpGet:
            path: /
            port: 9100
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 9100
          initialDelaySeconds: 15
          periodSeconds: 20
      
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: root
        hostPath:
          path: /
      
      serviceAccountName: node-exporter
      terminationGracePeriodSeconds: 30
```

---

### 3.7 安全生产风险提示

| 操作 | 风险等级 | 风险说明 | 建议 |
|-----|---------|---------|-----|
| 删除系统 DaemonSet | 高 | 可能导致集群网络/功能中断 | 除非确认影响，否则不要删除 |
| 配置 privileged | 中 | 容器获得节点完全权限 | 仅在必要时启用，限制最小权限 |
| 批量删除 Pod | 中 | 可能导致服务短暂中断 | 逐节点滚动更新，而非批量操作 |
| 修改 CNI DaemonSet | 高 | 可能导致集群网络中断 | 提前备份配置，低峰期操作 |
| 添加容忍所有污点 | 中 | Pod 可能调度到不适合的节点 | 精确配置需要容忍的污点 |
| 修改更新策略 | 低 | 影响后续更新行为 | 理解 RollingUpdate 和 OnDelete 区别 |
| 使用 hostNetwork | 中 | 端口冲突风险，安全边界模糊 | 确认端口未被占用，评估安全影响 |

---

## 附录

### 常用排查命令速查

```bash
# DaemonSet 状态
kubectl get ds -o wide
kubectl describe ds <name>
kubectl get ds <name> -o yaml

# Pod 分布
kubectl get pods -l <selector> -o wide
kubectl get pods -l <selector> -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase

# 节点信息
kubectl get nodes --show-labels
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# 更新操作
kubectl rollout status ds <name>
kubectl rollout history ds <name>
kubectl rollout undo ds <name>
kubectl rollout restart ds <name>

# 日志
kubectl logs <pod>
kubectl logs <pod> --previous
kubectl logs -n kube-system -l k8s-app=kube-dns
```

### 相关文档

- [Pod 故障排查](./01-pod-troubleshooting.md)
- [kubelet 故障排查](../02-node-components/01-kubelet-troubleshooting.md)
- [CNI 故障排查](../03-networking/01-cni-troubleshooting.md)
- [kube-proxy 故障排查](../02-node-components/02-kube-proxy-troubleshooting.md)
