# 107 - 日志聚合与分析工具 (Log Aggregation)

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01

## 日志方案技术选型

| 方案 (Solution) | 架构 (Architecture) | 成本 (Cost) | 查询性能 | 适用规模 |
|----------------|-------------------|------------|---------|---------|
| **Loki + Promtail** | 轻量级、索引简化 | 极低 | 中 | 中小型集群 |
| **ELK (Elasticsearch)** | 全文索引 | 高 | 高 | 大型企业 |
| **Fluentd + S3** | 归档存储 | 低 | 低 | 合规审计 |
| **阿里云 SLS** | 托管服务 | 中 | 高 | ACK 推荐 |

## Fluentd 生产级配置

### 1. DaemonSet 部署
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      serviceAccountName: fluentd
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1.16-debian-elasticsearch7
        env:
        - name: FLUENT_ELASTICSEARCH_HOST
          value: "elasticsearch.logging.svc.cluster.local"
        - name: FLUENT_ELASTICSEARCH_PORT
          value: "9200"
        resources:
          limits:
            memory: 500Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: containers
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: containers
        hostPath:
          path: /var/lib/docker/containers
```

### 2. 日志解析与过滤
```conf
<filter kubernetes.**>
  @type parser
  key_name log
  <parse>
    @type json
    time_key time
    time_format %Y-%m-%dT%H:%M:%S.%NZ
  </parse>
</filter>

<filter kubernetes.**>
  @type grep
  <exclude>
    key level
    pattern /^(DEBUG|TRACE)$/
  </exclude>
</filter>
```

## Filebeat 轻量级采集

### 1. 容器日志采集
```yaml
filebeat.inputs:
- type: container
  paths:
    - /var/log/containers/*.log
  processors:
    - add_kubernetes_metadata:
        host: ${NODE_NAME}
        matchers:
        - logs_path:
            logs_path: "/var/log/containers/"

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  index: "k8s-logs-%{+yyyy.MM.dd}"
```

### 2. 多行日志合并
```yaml
filebeat.inputs:
- type: log
  paths:
    - /var/log/app/*.log
  multiline.pattern: '^\d{4}-\d{2}-\d{2}'
  multiline.negate: true
  multiline.match: after
```

## Vector 高性能日志路由

### 配置示例
```toml
[sources.kubernetes_logs]
type = "kubernetes_logs"

[transforms.parse_json]
type = "remap"
inputs = ["kubernetes_logs"]
source = '''
. = parse_json!(.message)
'''

[sinks.loki]
type = "loki"
inputs = ["parse_json"]
endpoint = "http://loki:3100"
encoding.codec = "json"
labels.namespace = "{{ kubernetes.namespace }}"
labels.pod = "{{ kubernetes.pod_name }}"
```

## 日志分析最佳实践

| 实践 (Practice) | 说明 (Description) |
|----------------|-------------------|
| **结构化日志** | 使用 JSON 格式输出 |
| **统一时间戳** | ISO 8601 格式 |
| **关联 ID** | Trace ID / Request ID |
| **敏感信息脱敏** | 密码、Token 打码 |
| **日志分级** | ERROR/WARN/INFO/DEBUG |
| **保留策略** | 热数据 7d, 冷数据 90d |


---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)