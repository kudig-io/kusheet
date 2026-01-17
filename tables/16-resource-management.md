# 表格16：资源管理表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/configuration/manage-resources-containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

## 资源类型概览

| 资源名称 | 用途 | API组/版本 | 版本引入 | 稳定版本 | 生产必要性 |
|---------|------|-----------|---------|---------|-----------|
| **ResourceQuota** | 命名空间资源配额 | core/v1 | v1.0 | v1.0 | 多租户必需 |
| **LimitRange** | 默认资源限制 | core/v1 | v1.0 | v1.0 | 推荐 |
| **HorizontalPodAutoscaler** | 水平自动扩缩容 | autoscaling/v2 | v1.1 | v1.23 | 弹性必需 |
| **VerticalPodAutoscaler** | 垂直自动扩缩容 | autoscaling.k8s.io/v1 | 外部项目 | v1.0 | 推荐 |
| **PodDisruptionBudget** | 中断预算 | policy/v1 | v1.4 | v1.21 | 高可用必需 |
| **PriorityClass** | Pod优先级 | scheduling.k8s.io/v1 | v1.8 | v1.14 | 推荐 |

## ResourceQuota配置

| 配额类型 | 资源名 | 说明 | 示例值 |
|---------|-------|------|-------|
| **计算资源** | requests.cpu | CPU请求总量 | 100 |
| | requests.memory | 内存请求总量 | 100Gi |
| | limits.cpu | CPU限制总量 | 200 |
| | limits.memory | 内存限制总量 | 200Gi |
| **对象计数** | pods | Pod数量 | 100 |
| | services | Service数量 | 50 |
| | secrets | Secret数量 | 100 |
| | configmaps | ConfigMap数量 | 100 |
| | persistentvolumeclaims | PVC数量 | 50 |
| | services.loadbalancers | LoadBalancer数量 | 5 |
| | services.nodeports | NodePort数量 | 10 |
| **存储** | requests.storage | 存储请求总量 | 500Gi |
| | <sc>.storageclass.storage.k8s.io/requests.storage | 特定SC存储配额 | 100Gi |

```yaml
# ResourceQuota示例
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: production
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    limits.cpu: "200"
    limits.memory: 400Gi
    pods: "100"
    services: "50"
    secrets: "100"
    configmaps: "100"
    persistentvolumeclaims: "50"
    requests.storage: 500Gi
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["high", "medium"]
```

## LimitRange配置

| 限制类型 | 适用对象 | 参数 | 说明 |
|---------|---------|------|------|
| **Container** | 容器 | default | 默认limits |
| | | defaultRequest | 默认requests |
| | | max | 最大限制 |
| | | min | 最小请求 |
| | | maxLimitRequestRatio | 最大limits/requests比率 |
| **Pod** | Pod | max | Pod级最大 |
| | | min | Pod级最小 |
| **PersistentVolumeClaim** | PVC | max | 最大存储 |
| | | min | 最小存储 |

```yaml
# LimitRange示例
apiVersion: v1
kind: LimitRange
metadata:
  name: resource-limits
  namespace: production
spec:
  limits:
  - type: Container
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "4"
      memory: "8Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
    maxLimitRequestRatio:
      cpu: "10"
      memory: "10"
  - type: Pod
    max:
      cpu: "8"
      memory: "16Gi"
  - type: PersistentVolumeClaim
    max:
      storage: "100Gi"
    min:
      storage: "1Gi"
```

## HPA配置详解

| 指标类型 | 来源 | 配置方式 | 版本支持 |
|---------|------|---------|---------|
| **Resource** | Metrics Server | CPU/Memory利用率 | v1.23+ GA |
| **Pods** | Custom Metrics API | Pod级自定义指标 | v1.23+ |
| **Object** | Custom Metrics API | K8S对象指标 | v1.23+ |
| **External** | External Metrics API | 外部系统指标 | v1.23+ |

```yaml
# HPA v2完整示例
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  minReplicas: 2
  maxReplicas: 100
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
  - type: Pods
    pods:
      metric:
        name: requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"
  - type: External
    external:
      metric:
        name: queue_length
        selector:
          matchLabels:
            queue: main
      target:
        type: AverageValue
        averageValue: "30"
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
      - type: Pods
        value: 5
        periodSeconds: 60
      selectPolicy: Min
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 10
        periodSeconds: 15
      selectPolicy: Max
```

## VPA配置

| 更新模式 | 行为 | Pod重启 | 适用场景 |
|---------|------|--------|---------|
| **Off** | 仅推荐 | 否 | 观察分析 |
| **Initial** | 仅新Pod | 否 | 保守模式 |
| **Auto** | 自动更新 | 是 | 生产使用 |

```yaml
# VPA示例
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: "*"
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 4
        memory: 8Gi
      controlledResources: ["cpu", "memory"]
      controlledValues: RequestsAndLimits
```

## PodDisruptionBudget配置

| 参数 | 说明 | 示例值 | 注意事项 |
|-----|------|-------|---------|
| **minAvailable** | 最少可用数 | 2 或 50% | 与maxUnavailable互斥 |
| **maxUnavailable** | 最多不可用数 | 1 或 25% | 与minAvailable互斥 |
| **unhealthyPodEvictionPolicy** | 不健康Pod驱逐策略 | IfHealthyBudget | v1.27+ |

```yaml
# PDB示例
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2  # 或 maxUnavailable: 1
  selector:
    matchLabels:
      app: myapp
  unhealthyPodEvictionPolicy: IfHealthyBudget  # v1.27+
```

## PriorityClass配置

| 参数 | 说明 | 范围 |
|-----|------|------|
| **value** | 优先级值 | -2147483648 ~ 1000000000 |
| **globalDefault** | 是否为默认 | true/false |
| **preemptionPolicy** | 抢占策略 | PreemptLowerPriority/Never |

```yaml
# PriorityClass示例
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "高优先级，可抢占低优先级Pod"

---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority-no-preempt
value: 100
preemptionPolicy: Never
description: "低优先级，不触发抢占"
```

## 资源请求与限制最佳实践

| 实践 | 说明 | 推荐配置 |
|-----|------|---------|
| **始终设置requests** | 调度依据 | 基于实际使用 |
| **设置合理limits** | 防止资源耗尽 | requests的1.5-2倍 |
| **CPU可不设limits** | 允许突发 | 某些场景适用 |
| **Memory必须设limits** | 防止OOM | 必须设置 |
| **QoS等级规划** | 影响驱逐顺序 | 按重要性设置 |

## QoS等级

| QoS等级 | 条件 | 驱逐优先级 | 适用场景 |
|--------|------|-----------|---------|
| **Guaranteed** | requests=limits(CPU和Memory) | 最低 | 关键服务 |
| **Burstable** | requests<limits或部分设置 | 中等 | 一般服务 |
| **BestEffort** | 无requests和limits | 最高 | 非关键任务 |

## 资源监控与告警

| 指标 | 告警阈值 | 说明 |
|-----|---------|------|
| **ResourceQuota使用率** | >80% | 接近配额限制 |
| **CPU使用率** | >85% | 可能需要扩容 |
| **Memory使用率** | >90% | OOM风险 |
| **HPA当前副本=最大值** | 触发 | 需要调整maxReplicas |
| **PDB违规** | >0 | 维护影响可用性 |

---

**资源管理原则**: 设置合理配额，启用自动扩缩容，监控资源使用
