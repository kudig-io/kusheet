# 40 - 自定义指标和监控扩展表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

## Kubernetes Metrics API

| API | 路径 | 提供者 | 用途 | 版本支持 |
|-----|------|-------|------|---------|
| **Resource Metrics** | metrics.k8s.io/v1beta1 | Metrics Server | CPU/Memory | 稳定 |
| **Custom Metrics** | custom.metrics.k8s.io/v1beta1 | Prometheus Adapter等 | 自定义Pod指标 | 稳定 |
| **External Metrics** | external.metrics.k8s.io/v1beta1 | 外部适配器 | 外部系统指标 | 稳定 |

## Metrics Server

```yaml
# Metrics Server部署
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-server
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      containers:
      - name: metrics-server
        image: registry.k8s.io/metrics-server/metrics-server:v0.7.0
        args:
        - --cert-dir=/tmp
        - --secure-port=10250
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        - --kubelet-use-node-status-port
        - --metric-resolution=15s
        # 测试环境可能需要
        # - --kubelet-insecure-tls
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
```

## Prometheus Adapter

```yaml
# Prometheus Adapter Helm安装
# helm install prometheus-adapter prometheus-community/prometheus-adapter -f values.yaml

# values.yaml示例
prometheus:
  url: http://prometheus.monitoring.svc
  port: 9090

rules:
  default: true
  custom:
  # 自定义指标规则
  - seriesQuery: 'http_requests_total{namespace!="",pod!=""}'
    resources:
      overrides:
        namespace: {resource: "namespace"}
        pod: {resource: "pod"}
    name:
      matches: "^(.*)_total$"
      as: "${1}_per_second"
    metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[2m])) by (<<.GroupBy>>)'
  
  # 外部指标规则
  external:
  - seriesQuery: 'queue_messages_total{queue_name!=""}'
    resources:
      template: <<.Resource>>
    name:
      matches: "^(.*)_total$"
      as: "${1}"
    metricsQuery: 'sum(<<.Series>>{<<.LabelMatchers>>}) by (<<.GroupBy>>)'
```

## Custom Metrics HPA

```yaml
# 基于自定义指标的HPA
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa-custom
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  minReplicas: 2
  maxReplicas: 20
  metrics:
  # 资源指标
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  # 自定义Pod指标
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"
  # 自定义对象指标
  - type: Object
    object:
      metric:
        name: requests_per_second
      describedObject:
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        name: main-ingress
      target:
        type: Value
        value: "10000"
  # 外部指标
  - type: External
    external:
      metric:
        name: queue_messages
        selector:
          matchLabels:
            queue: main-queue
      target:
        type: AverageValue
        averageValue: "30"
```

## KEDA(Kubernetes Event-driven Autoscaling)

```yaml
# KEDA安装
# kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.12.0/keda-2.12.0.yaml

# ScaledObject示例
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: rabbitmq-scaledobject
spec:
  scaleTargetRef:
    name: consumer-deployment
  pollingInterval: 30
  cooldownPeriod: 300
  minReplicaCount: 1
  maxReplicaCount: 100
  triggers:
  - type: rabbitmq
    metadata:
      host: amqp://user:pass@rabbitmq:5672/
      queueName: tasks
      queueLength: "50"
---
# Prometheus触发器
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: prometheus-scaledobject
spec:
  scaleTargetRef:
    name: app-deployment
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus:9090
      metricName: http_requests_total
      threshold: "100"
      query: sum(rate(http_requests_total{deployment="app"}[2m]))
---
# Cron触发器(定时扩缩容)
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: cron-scaledobject
spec:
  scaleTargetRef:
    name: app-deployment
  triggers:
  - type: cron
    metadata:
      timezone: Asia/Shanghai
      start: 0 8 * * 1-5   # 工作日8点
      end: 0 20 * * 1-5    # 工作日20点
      desiredReplicas: "10"
```

## 应用暴露自定义指标

```go
// Go应用暴露Prometheus指标示例
package main

import (
    "net/http"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    httpRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "path", "status"},
    )
    httpRequestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request duration in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "path"},
    )
)

func init() {
    prometheus.MustRegister(httpRequestsTotal)
    prometheus.MustRegister(httpRequestDuration)
}

func main() {
    http.Handle("/metrics", promhttp.Handler())
    http.ListenAndServe(":8080", nil)
}
```

```yaml
# Pod配置Prometheus抓取
apiVersion: v1
kind: Pod
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
spec:
  containers:
  - name: app
    image: app:latest
    ports:
    - containerPort: 8080
      name: metrics
```

## ServiceMonitor(Prometheus Operator)

```yaml
# ServiceMonitor定义
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: app-monitor
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
  namespaceSelector:
    matchNames:
    - production
---
# PodMonitor定义
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: app-pod-monitor
spec:
  selector:
    matchLabels:
      app: myapp
  podMetricsEndpoints:
  - port: metrics
    interval: 30s
```

## 指标聚合规则

```yaml
# PrometheusRule定义
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: app-rules
spec:
  groups:
  - name: app.rules
    interval: 30s
    rules:
    # 记录规则(预计算)
    - record: job:http_requests:rate5m
      expr: sum(rate(http_requests_total[5m])) by (job)
    # 告警规则
    - alert: HighErrorRate
      expr: |
        sum(rate(http_requests_total{status=~"5.."}[5m])) by (job)
        /
        sum(rate(http_requests_total[5m])) by (job) > 0.05
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value | humanizePercentage }}"
```

## 验证自定义指标

```bash
# 验证Custom Metrics API
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1" | jq
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/default/pods/*/http_requests_per_second" | jq

# 验证External Metrics API
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1" | jq
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1/namespaces/default/queue_messages" | jq

# 检查HPA状态
kubectl describe hpa <name>
kubectl get hpa -w
```

## ACK监控扩展

| 功能 | 产品 | 集成方式 |
|-----|------|---------|
| **Prometheus托管** | ARMS | 组件安装 |
| **自定义指标HPA** | ARMS Adapter | 自动配置 |
| **业务监控** | ARMS应用监控 | Agent注入 |
| **日志指标** | SLS | 日志聚合 |

---

**监控扩展原则**: 暴露业务指标，配置合理阈值，实现自动扩缩容

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)