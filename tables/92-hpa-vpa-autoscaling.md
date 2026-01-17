# HPA/VPA 自动伸缩配置

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

## HPA 版本演进

| 版本 | API Version | 关键特性 |
|------|-------------|----------|
| v1.23+ | autoscaling/v2 | GA，行为策略 |
| v1.27+ | autoscaling/v2 | ContainerResource 指标 |
| v1.30+ | autoscaling/v2 | 可配置容忍度 |

## HPA 指标类型

| 指标类型 | 说明 | 使用场景 |
|----------|------|----------|
| Resource | CPU/Memory 使用率 | 基础伸缩 |
| Pods | Pod 自定义指标 | 应用级指标 |
| Object | K8s 对象指标 | Ingress QPS 等 |
| External | 外部系统指标 | 消息队列长度 |
| ContainerResource | 容器级资源 | 多容器 Pod |

## HPA 完整配置示例

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 3
  maxReplicas: 100
  metrics:
  # CPU 指标
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  # Memory 指标
  - type: Resource
    resource:
      name: memory
      target:
        type: AverageValue
        averageValue: 500Mi
  # 自定义指标 (Prometheus Adapter)
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"
  # 外部指标 (消息队列)
  - type: External
    external:
      metric:
        name: queue_messages_ready
        selector:
          matchLabels:
            queue: orders
      target:
        type: AverageValue
        averageValue: "30"
  # 伸缩行为策略
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
        value: 4
        periodSeconds: 15
      selectPolicy: Max
```

## HPA 行为策略详解

| 参数 | 说明 | 推荐值 |
|------|------|--------|
| stabilizationWindowSeconds | 稳定窗口期 | 扩容:0, 缩容:300 |
| selectPolicy | 策略选择 | Max(扩容), Min(缩容) |
| policies.type | 策略类型 | Percent/Pods |
| policies.value | 变更数量 | 根据场景调整 |
| policies.periodSeconds | 执行周期 | 15-60s |

## VPA 模式对比

| 模式 | 说明 | 是否重启 Pod | 使用场景 |
|------|------|-------------|----------|
| Off | 仅推荐 | 否 | 观察学习阶段 |
| Initial | 仅创建时设置 | 新 Pod 生效 | 保守应用 |
| Auto | 自动调整 | 是 | 完全自动化 |
| Recreate | 重建调整 | 是 | 同 Auto |

## VPA 配置示例

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: web-app-vpa
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  updatePolicy:
    updateMode: "Auto"
    minReplicas: 2  # 保持最少副本数
  resourcePolicy:
    containerPolicies:
    - containerName: web
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 4
        memory: 8Gi
      controlledResources: ["cpu", "memory"]
      controlledValues: RequestsAndLimits
    - containerName: sidecar
      mode: "Off"  # 不调整 sidecar
```

## KEDA 事件驱动伸缩

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: order-processor
  namespace: production
spec:
  scaleTargetRef:
    name: order-processor
  pollingInterval: 15
  cooldownPeriod: 300
  minReplicaCount: 1
  maxReplicaCount: 100
  fallback:
    failureThreshold: 3
    replicas: 6
  triggers:
  # Kafka 消息积压
  - type: kafka
    metadata:
      bootstrapServers: kafka:9092
      consumerGroup: order-group
      topic: orders
      lagThreshold: "100"
  # Prometheus 指标
  - type: prometheus
    metadata:
      serverAddress: http://prometheus:9090
      metricName: http_requests_total
      threshold: "100"
      query: sum(rate(http_requests_total{app="order"}[2m]))
  # 定时伸缩 (预测性)
  - type: cron
    metadata:
      timezone: Asia/Shanghai
      start: 0 8 * * *
      end: 0 20 * * *
      desiredReplicas: "10"
```

## HPA 与 VPA 协同使用

```yaml
# 方案1: HPA CPU + VPA Memory
---
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
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
---
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  resourcePolicy:
    containerPolicies:
    - containerName: "*"
      controlledResources: ["memory"]  # 仅调整 memory
```

## Prometheus Adapter 自定义指标

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-adapter-config
  namespace: monitoring
data:
  config.yaml: |
    rules:
    # Pod 级指标
    - seriesQuery: 'http_requests_total{namespace!="",pod!=""}'
      resources:
        overrides:
          namespace: {resource: "namespace"}
          pod: {resource: "pod"}
      name:
        matches: "^(.*)_total$"
        as: "${1}_per_second"
      metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[2m])) by (<<.GroupBy>>)'
    # External 指标
    - seriesQuery: 'rabbitmq_queue_messages{queue!=""}'
      resources:
        template: <<.Resource>>
      name:
        matches: "^(.*)$"
        as: "queue_messages_ready"
      metricsQuery: 'sum(<<.Series>>{<<.LabelMatchers>>}) by (queue)'
```

## 自动伸缩诊断命令

```bash
# 查看 HPA 状态和事件
kubectl get hpa -A
kubectl describe hpa <name> -n <namespace>

# 查看 HPA 计算详情
kubectl get hpa <name> -o yaml | grep -A 20 status

# 查看自定义指标
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1" | jq .
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/default/pods/*/http_requests_per_second"

# 查看外部指标
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1" | jq .

# VPA 推荐值查看
kubectl describe vpa <name> -n <namespace>

# KEDA 状态
kubectl get scaledobjects -A
kubectl describe scaledobject <name>
```

## 常见问题与解决

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| HPA 不生效 | metrics-server 未部署 | 部署 metrics-server |
| 指标获取失败 | Prometheus Adapter 配置错误 | 检查 ConfigMap 规则 |
| 频繁扩缩容 | 稳定窗口过短 | 调整 stabilizationWindowSeconds |
| VPA 推荐不准 | 数据收集不足 | 等待 24h+ 数据 |
| HPA/VPA 冲突 | 同时调整 CPU | VPA 仅管 memory |

## 监控告警规则

```yaml
groups:
- name: autoscaling
  rules:
  - alert: HPAMaxedOut
    expr: |
      kube_horizontalpodautoscaler_status_current_replicas
      == kube_horizontalpodautoscaler_spec_max_replicas
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "HPA {{ $labels.horizontalpodautoscaler }} 已达最大副本数"
      
  - alert: HPAScalingDisabled
    expr: |
      kube_horizontalpodautoscaler_status_condition{condition="ScalingActive",status="false"} == 1
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "HPA {{ $labels.horizontalpodautoscaler }} 伸缩被禁用"
      
  - alert: VPARecommendationExceedsLimits
    expr: |
      kube_verticalpodautoscaler_status_recommendation_containerrecommendations_target
      > kube_verticalpodautoscaler_spec_resourcepolicy_containerpolicies_maxallowed
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "VPA 推荐值超过允许上限"
```
