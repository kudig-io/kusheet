# 106 - 全栈可观测性工具 (Observability Stack)

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01

## 可观测性三大支柱

| 支柱 (Pillar) | 核心工具 (Tools) | 数据类型 (Data Type) | 生产价值 |
|--------------|----------------|-------------------|---------|
| **Metrics (指标)** | Prometheus, VictoriaMetrics | 时序数据 | 性能监控、告警 |
| **Logs (日志)** | Loki, Elasticsearch | 文本流 | 故障排查、审计 |
| **Traces (链路)** | Jaeger, Tempo | 分布式追踪 | 性能分析、依赖图 |

## Prometheus 生产级部署

### 1. 高可用架构
```yaml
# Prometheus Operator 配置
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: k8s
  namespace: monitoring
spec:
  replicas: 2
  retention: 15d
  retentionSize: "50GB"
  storage:
    volumeClaimTemplate:
      spec:
        storageClassName: alicloud-disk-essd
        resources:
          requests:
            storage: 100Gi
  serviceMonitorSelector:
    matchLabels:
      prometheus: kube-prometheus
  resources:
    requests:
      memory: 4Gi
      cpu: 2
    limits:
      memory: 8Gi
      cpu: 4
```

### 2. 关键告警规则
```yaml
groups:
- name: kubernetes-critical
  rules:
  - alert: KubePodCrashLooping
    expr: rate(kube_pod_container_status_restarts_total[15m]) * 60 * 5 > 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Pod {{ $labels.pod }} 频繁重启"
      
  - alert: KubeNodeNotReady
    expr: kube_node_status_condition{condition="Ready",status="true"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "节点 {{ $labels.node }} NotReady"
```

## Grafana 仪表盘最佳实践

### 推荐 Dashboard ID
- **Kubernetes Cluster**: 7249
- **Node Exporter**: 1860
- **NGINX Ingress**: 9614
- **etcd**: 3070
- **GPU (DCGM)**: 12239

### 变量模板
```json
{
  "templating": {
    "list": [
      {
        "name": "namespace",
        "type": "query",
        "query": "label_values(kube_pod_info, namespace)"
      },
      {
        "name": "pod",
        "type": "query",
        "query": "label_values(kube_pod_info{namespace=~"$namespace"}, pod)"
      }
    ]
  }
}
```

## Loki 日志聚合

### 1. Promtail 采集配置
```yaml
scrape_configs:
  - job_name: kubernetes-pods
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        target_label: app
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod
```

### 2. LogQL 查询示例
```logql
# 查询错误日志
{namespace="production", app="myapp"} |= "ERROR"

# 统计错误率
rate({namespace="production"} |= "ERROR" [5m])

# JSON 日志解析
{app="api"} | json | level="error" | line_format "{{.message}}"
```

## OpenTelemetry 统一可观测

### Collector 配置
```yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024

exporters:
  prometheus:
    endpoint: "0.0.0.0:8889"
  jaeger:
    endpoint: jaeger-collector:14250
  loki:
    endpoint: http://loki:3100/loki/api/v1/push

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [jaeger]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [loki]
```

## 成本优化策略

| 策略 (Strategy) | 实施方式 (Implementation) | 节省比例 |
|----------------|--------------------------|---------|
| **采样率控制** | Traces 采样 10% | 90% 存储 |
| **日志过滤** | 丢弃 DEBUG 级别 | 70% 存储 |
| **指标降采样** | 长期存储降精度 | 50% 存储 |
| **数据分层** | 热数据 SSD, 冷数据 OSS | 60% 成本 |


---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)