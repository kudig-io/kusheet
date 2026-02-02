# 日志与监控故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32, Prometheus v2.45+, Grafana v10+ | **最后更新**: 2026-01 | **难度**: 高级
>
> **版本说明**:
> - Prometheus v2.45+ 支持 native histogram
> - Prometheus Operator v0.70+ 支持 scrapeClass
> - Fluent Bit v2.x 推荐替代 Fluentd
> - Loki v2.9+ 支持 TSDB 存储

## 概述

Kubernetes 集群的可观测性依赖于日志收集、指标监控和告警系统。本文档覆盖常见的日志收集 (Fluentd/Fluent Bit/Loki) 和监控系统 (Prometheus/Grafana) 故障的诊断与解决方案。

---

## 第一部分：问题现象与影响分析

### 1.1 可观测性架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes 可观测性体系                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐ │
│  │     日志       │    │     指标       │    │     追踪       │ │
│  │   Logging      │    │   Metrics      │    │   Tracing      │ │
│  └───────┬────────┘    └───────┬────────┘    └───────┬────────┘ │
│          │                     │                     │          │
│          ▼                     ▼                     ▼          │
│  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐ │
│  │ Fluentd/Fluent │    │  Prometheus    │    │    Jaeger/     │ │
│  │ Bit/Vector     │    │  /VictoriaM    │    │    Zipkin      │ │
│  └───────┬────────┘    └───────┬────────┘    └───────┬────────┘ │
│          │                     │                     │          │
│          ▼                     ▼                     ▼          │
│  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐ │
│  │ Elasticsearch/ │    │    Grafana     │    │    Grafana/    │ │
│  │ Loki/OpenSearch│    │  /AlertManager │    │    Jaeger UI   │ │
│  └────────────────┘    └────────────────┘    └────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 日志系统常见问题

| 问题类型 | 现象描述 | 可能原因 | 查看方式 |
|---------|---------|---------|---------|
| 日志丢失 | 部分 Pod 日志未收集 | 采集器故障/配置错误 | Kibana/Grafana 查询 |
| 日志延迟 | 日志出现明显滞后 | 队列积压/后端慢 | 采集器指标 |
| 采集器崩溃 | DaemonSet Pod CrashLoop | 内存不足/配置错误 | `kubectl get pods` |
| 后端不可用 | 无法写入 ES/Loki | 后端服务故障 | 采集器日志 |
| 日志格式错误 | 解析失败/字段缺失 | 解析器配置错误 | 采集器日志 |
| 磁盘空间不足 | 日志堆积无法写入 | 清理策略/容量规划 | 节点/Pod 存储 |

### 1.3 监控系统常见问题

| 问题类型 | 现象描述 | 可能原因 | 查看方式 |
|---------|---------|---------|---------|
| 指标缺失 | 部分目标无指标 | 服务发现失败/抓取失败 | Prometheus Targets |
| 抓取超时 | Scrape failed | 网络问题/目标慢 | Prometheus 日志 |
| 存储问题 | Prometheus OOM/慢查询 | 数据量大/资源不足 | `kubectl top` |
| 告警不触发 | AlertManager 未收到 | 规则错误/AM 故障 | Prometheus Alerts |
| 告警风暴 | 大量重复告警 | 阈值设置/抑制规则 | AlertManager |
| Grafana 无数据 | Dashboard 显示空 | 数据源配置/查询错误 | Grafana 设置 |

### 1.4 影响分析

| 故障类型 | 直接影响 | 间接影响 | 影响范围 |
|---------|---------|---------|---------|
| 日志系统故障 | 无法查看应用日志 | 问题排查困难，合规风险 | 所有应用 |
| Prometheus 故障 | 指标不可用 | HPA 失效，告警失效 | 整个监控体系 |
| AlertManager 故障 | 告警无法发送 | 问题无法及时发现 | 告警通知 |
| Grafana 故障 | 仪表板不可用 | 可视化监控中断 | 运维人员 |
| 存储后端故障 | 历史数据不可查 | 趋势分析/审计中断 | 数据分析 |

---

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
日志/监控故障
      │
      ├─── 日志问题？
      │         │
      │         ├─ 日志丢失 ──→ 检查采集器状态/配置/后端
      │         ├─ 日志延迟 ──→ 检查队列/后端性能/网络
      │         ├─ 采集器崩溃 ──→ 检查资源/配置/权限
      │         └─ 格式错误 ──→ 检查解析器配置
      │
      ├─── 监控问题？
      │         │
      │         ├─ 指标缺失 ──→ 检查服务发现/抓取配置
      │         ├─ Prometheus 慢 ──→ 检查资源/查询/存储
      │         ├─ 告警问题 ──→ 检查规则/AlertManager
      │         └─ Grafana 无数据 ──→ 检查数据源/查询
      │
      └─── 存储问题？
                │
                ├─ ES/Loki 故障 ──→ 检查集群状态/存储
                └─ 磁盘空间不足 ──→ 清理/扩容
```

### 2.2 日志系统排查命令

#### 2.2.1 Fluentd/Fluent Bit 检查

```bash
# 检查采集器 DaemonSet 状态
kubectl get ds -n logging
kubectl get pods -n logging -o wide

# 查看采集器日志
kubectl logs -n logging -l app=fluent-bit --tail=100
kubectl logs -n logging -l app=fluentd --tail=100

# 检查采集器指标 (如果启用)
kubectl port-forward -n logging svc/fluent-bit 2020:2020
curl http://localhost:2020/api/v1/metrics

# 检查配置
kubectl get configmap -n logging fluent-bit-config -o yaml
kubectl get configmap -n logging fluentd-config -o yaml

# 检查节点日志目录挂载
kubectl exec -n logging <fluent-bit-pod> -- ls -la /var/log/containers/
kubectl exec -n logging <fluent-bit-pod> -- ls -la /var/log/pods/
```

#### 2.2.2 Elasticsearch/OpenSearch 检查

```bash
# 检查集群健康状态
kubectl exec -n logging <es-pod> -- curl -s localhost:9200/_cluster/health | jq

# 检查索引状态
kubectl exec -n logging <es-pod> -- curl -s localhost:9200/_cat/indices?v

# 检查节点状态
kubectl exec -n logging <es-pod> -- curl -s localhost:9200/_cat/nodes?v

# 检查磁盘使用
kubectl exec -n logging <es-pod> -- curl -s localhost:9200/_cat/allocation?v

# 检查分片状态
kubectl exec -n logging <es-pod> -- curl -s localhost:9200/_cat/shards?v | head -20
```

#### 2.2.3 Loki 检查

```bash
# 检查 Loki 状态
kubectl get pods -n logging -l app=loki

# 查看 Loki 日志
kubectl logs -n logging -l app=loki --tail=100

# 检查 Loki 就绪状态
kubectl exec -n logging <loki-pod> -- wget -qO- http://localhost:3100/ready

# 检查 Loki 指标
kubectl exec -n logging <loki-pod> -- wget -qO- http://localhost:3100/metrics | head -50

# 检查 Promtail 状态
kubectl get pods -n logging -l app=promtail
kubectl logs -n logging -l app=promtail --tail=100
```

### 2.3 监控系统排查命令

#### 2.3.1 Prometheus 检查

```bash
# 检查 Prometheus 状态
kubectl get pods -n monitoring -l app=prometheus

# 查看 Prometheus 日志
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus --tail=100

# 检查 Prometheus 配置
kubectl get configmap -n monitoring prometheus-server -o yaml

# 端口转发访问 UI
kubectl port-forward -n monitoring svc/prometheus-server 9090:80

# 检查目标状态
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health, lastError: .lastError}'

# 检查告警规则
curl -s http://localhost:9090/api/v1/rules | jq

# 检查存储状态
curl -s http://localhost:9090/api/v1/status/tsdb | jq
```

#### 2.3.2 AlertManager 检查

```bash
# 检查 AlertManager 状态
kubectl get pods -n monitoring -l app=alertmanager

# 查看 AlertManager 日志
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager --tail=100

# 端口转发访问 UI
kubectl port-forward -n monitoring svc/alertmanager 9093:9093

# 检查当前告警
curl -s http://localhost:9093/api/v2/alerts | jq

# 检查静默规则
curl -s http://localhost:9093/api/v2/silences | jq

# 检查配置
kubectl get secret -n monitoring alertmanager-<name> -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d
```

#### 2.3.3 Grafana 检查

```bash
# 检查 Grafana 状态
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# 查看 Grafana 日志
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=100

# 端口转发访问
kubectl port-forward -n monitoring svc/grafana 3000:80

# 检查数据源配置
kubectl get configmap -n monitoring grafana-datasources -o yaml

# 检查 Dashboard 配置
kubectl get configmap -n monitoring -l grafana_dashboard=1
```

---

## 第三部分：解决方案与风险控制

### 3.1 日志采集问题

#### 场景 1：Fluent Bit 采集器崩溃

**问题现象：**
```bash
$ kubectl get pods -n logging
NAME                READY   STATUS             RESTARTS   AGE
fluent-bit-abc12    0/1     CrashLoopBackOff   5          10m
```

**解决步骤：**

```bash
# 1. 查看崩溃日志
kubectl logs -n logging <fluent-bit-pod> --previous

# 2. 常见原因及解决

# 原因 A: 内存不足 (OOM)
kubectl describe pod -n logging <fluent-bit-pod> | grep -A5 "Last State"
# 解决: 增加内存限制
kubectl patch daemonset fluent-bit -n logging --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "256Mi"}
]'

# 原因 B: 配置错误
kubectl get configmap -n logging fluent-bit-config -o yaml | grep -A20 "\[OUTPUT\]"
# 检查输出配置是否正确

# 原因 C: 后端不可达
kubectl exec -n logging <fluent-bit-pod> -- nc -zv <es-host> <es-port>

# 3. 重启 DaemonSet
kubectl rollout restart daemonset fluent-bit -n logging

# 4. 验证状态
kubectl get pods -n logging -l app=fluent-bit -w
```

#### 场景 2：日志丢失

**解决步骤：**

```bash
# 1. 确认日志在节点上存在
kubectl debug node/<node> -it --image=busybox -- ls -la /host/var/log/containers/

# 2. 检查采集器是否读取到日志
kubectl logs -n logging <fluent-bit-pod> | grep -i "input"

# 3. 检查采集器配置的日志路径
kubectl get configmap -n logging fluent-bit-config -o yaml | grep -A10 "\[INPUT\]"

# 4. 确认采集器有权限读取
kubectl exec -n logging <fluent-bit-pod> -- cat /var/log/containers/<log-file> | head

# 5. 检查过滤/解析是否导致丢弃
kubectl get configmap -n logging fluent-bit-config -o yaml | grep -A10 "\[FILTER\]"

# 6. 检查后端写入是否成功
kubectl logs -n logging <fluent-bit-pod> | grep -i "error\|retry\|failed"

# 7. 如果是 ES 写入问题，检查索引状态
kubectl exec -n logging <es-pod> -- curl -s localhost:9200/_cat/indices?v | grep red
```

#### 场景 3：日志延迟

**解决步骤：**

```bash
# 1. 检查采集器队列状态
kubectl logs -n logging <fluent-bit-pod> | grep -i "buffer\|queue\|backpressure"

# 2. 检查后端写入延迟
kubectl logs -n logging <fluent-bit-pod> | grep -i "retry\|timeout"

# 3. 优化 Fluent Bit 配置
# 增加 buffer 和 flush 间隔
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: logging
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info
        Daemon        off
        HTTP_Server   On
        HTTP_Listen   0.0.0.0
        HTTP_Port     2020
        
    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        Parser            docker
        Tag               kube.*
        Refresh_Interval  5
        Mem_Buf_Limit     50MB
        Skip_Long_Lines   On
        
    [OUTPUT]
        Name            es
        Match           *
        Host            elasticsearch
        Port            9200
        Retry_Limit     5
        Buffer_Size     512KB
EOF

# 4. 检查后端性能
kubectl top pods -n logging | grep elasticsearch

# 5. 如果是 ES 慢，考虑扩容或优化
```

---

### 3.2 Elasticsearch/Loki 后端问题

#### 场景 1：Elasticsearch 集群红色状态

**问题现象：**
```bash
$ kubectl exec -n logging <es-pod> -- curl -s localhost:9200/_cluster/health
{"status":"red",...}
```

**解决步骤：**

```bash
# 1. 检查未分配的分片
kubectl exec -n logging <es-pod> -- curl -s localhost:9200/_cat/shards?v | grep UNASSIGNED

# 2. 查看分片未分配原因
kubectl exec -n logging <es-pod> -- curl -s 'localhost:9200/_cluster/allocation/explain' | jq

# 3. 常见原因及解决

# 原因 A: 磁盘空间不足
kubectl exec -n logging <es-pod> -- curl -s localhost:9200/_cat/allocation?v
# 解决: 删除旧索引
kubectl exec -n logging <es-pod> -- curl -X DELETE 'localhost:9200/logs-2024.01.*'

# 原因 B: 节点数不足
kubectl get pods -n logging -l app=elasticsearch
# 解决: 扩容 ES 节点

# 原因 C: 手动重新分配分片
kubectl exec -n logging <es-pod> -- curl -X POST 'localhost:9200/_cluster/reroute?retry_failed=true'

# 4. 验证集群恢复
kubectl exec -n logging <es-pod> -- curl -s localhost:9200/_cluster/health | jq '.status'
```

#### 场景 2：Loki 查询超时

**解决步骤：**

```bash
# 1. 检查 Loki 资源使用
kubectl top pods -n logging -l app=loki

# 2. 增加 Loki 资源
kubectl patch deployment loki -n logging --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "2Gi"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value": "1"}
]'

# 3. 优化 Loki 配置
kubectl edit configmap loki-config -n logging
# 调整 query_timeout, max_concurrent 等参数

# 4. 检查存储后端 (如 S3/GCS)
kubectl logs -n logging -l app=loki | grep -i "storage\|s3\|gcs"

# 5. 考虑部署 Loki 分布式模式
```

---

### 3.3 Prometheus 问题

#### 场景 1：Prometheus 指标缺失

**问题现象：**
部分服务在 Targets 页面显示 DOWN

**解决步骤：**

```bash
# 1. 检查 Prometheus Targets
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
# 访问 http://localhost:9090/targets

# 2. 查看失败的 target 错误信息
curl -s 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets[] | select(.health=="down")'

# 3. 常见错误及解决

# 错误 A: connection refused
# 确认目标服务的 metrics 端口正确
kubectl get svc <service-name> -o yaml | grep -A5 ports
kubectl exec <prometheus-pod> -- wget -qO- http://<target-ip>:<port>/metrics | head

# 错误 B: context deadline exceeded (超时)
# 增加 scrape_timeout
kubectl edit configmap prometheus-server -n monitoring
# scrape_timeout: 30s

# 错误 C: 403 Forbidden
# 检查 RBAC 权限
kubectl get clusterrolebinding | grep prometheus
kubectl get clusterrole prometheus -o yaml

# 错误 D: 证书错误
# 配置跳过 TLS 验证或配置正确的 CA
# tls_config:
#   insecure_skip_verify: true

# 4. 重新加载 Prometheus 配置
curl -X POST http://localhost:9090/-/reload
```

#### 场景 2：Prometheus OOM 或慢查询

**解决步骤：**

```bash
# 1. 检查资源使用
kubectl top pods -n monitoring -l app.kubernetes.io/name=prometheus

# 2. 检查 TSDB 状态
curl -s http://localhost:9090/api/v1/status/tsdb | jq

# 3. 优化存储配置
kubectl edit statefulset prometheus-server -n monitoring
# 添加或调整:
# --storage.tsdb.retention.time=15d
# --storage.tsdb.retention.size=50GB
# --query.max-concurrency=10

# 4. 增加资源限制
kubectl patch statefulset prometheus-server -n monitoring --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "4Gi"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value": "2"}
]'

# 5. 优化抓取配置，减少指标数量
# 使用 metric_relabel_configs 过滤不需要的指标
# - source_labels: [__name__]
#   regex: 'go_.*'
#   action: drop

# 6. 考虑使用 Thanos/VictoriaMetrics 等方案进行扩展
```

---

### 3.4 AlertManager 问题

#### 场景 1：告警未发送

**解决步骤：**

```bash
# 1. 检查 Prometheus 告警状态
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | {alertname: .labels.alertname, state: .state}'

# 2. 检查 AlertManager 是否收到告警
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
curl -s http://localhost:9093/api/v2/alerts | jq

# 3. 检查 AlertManager 配置
kubectl get secret -n monitoring alertmanager-<name> -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d

# 4. 验证通知渠道
# 检查 Slack/Email/PagerDuty 等配置

# 5. 检查 AlertManager 日志
kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager | grep -i "error\|failed"

# 6. 测试告警发送
# 创建测试告警
curl -X POST http://localhost:9093/api/v2/alerts -H 'Content-Type: application/json' -d '[
  {
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning"
    },
    "annotations": {
      "summary": "This is a test alert"
    }
  }
]'
```

#### 场景 2：告警风暴

**解决步骤：**

```bash
# 1. 配置告警分组
kubectl edit secret alertmanager-<name> -n monitoring
# route:
#   group_by: ['alertname', 'cluster']
#   group_wait: 30s
#   group_interval: 5m
#   repeat_interval: 4h

# 2. 配置抑制规则
# inhibit_rules:
# - source_match:
#     severity: 'critical'
#   target_match:
#     severity: 'warning'
#   equal: ['alertname', 'cluster']

# 3. 创建静默规则
curl -X POST http://localhost:9093/api/v2/silences -H 'Content-Type: application/json' -d '{
  "matchers": [
    {"name": "alertname", "value": "TestAlert", "isRegex": false}
  ],
  "startsAt": "2024-01-01T00:00:00Z",
  "endsAt": "2024-01-02T00:00:00Z",
  "createdBy": "admin",
  "comment": "Silencing test alerts"
}'

# 4. 调整告警阈值
# 检查并调整 Prometheus 告警规则
kubectl get prometheusrule -n monitoring
kubectl edit prometheusrule <name> -n monitoring
```

---

### 3.5 Grafana 问题

#### 场景 1：Grafana 数据源无数据

**解决步骤：**

```bash
# 1. 检查数据源配置
kubectl port-forward -n monitoring svc/grafana 3000:80
# 访问 Settings -> Data Sources -> 测试连接

# 2. 检查 Prometheus 数据源 URL
# 确保 URL 可从 Grafana Pod 访问
kubectl exec -n monitoring <grafana-pod> -- wget -qO- http://prometheus-server/api/v1/query?query=up

# 3. 检查认证配置
kubectl get configmap -n monitoring grafana-datasources -o yaml

# 4. 常见问题
# - URL 错误: 使用服务名而非 IP
# - 网络策略阻止: 检查 NetworkPolicy
# - 认证失败: 配置正确的 token/password

# 5. 重启 Grafana
kubectl rollout restart deployment grafana -n monitoring
```

#### 场景 2：Dashboard 加载缓慢

**解决步骤：**

```bash
# 1. 检查 Grafana 资源使用
kubectl top pods -n monitoring -l app.kubernetes.io/name=grafana

# 2. 优化查询
# - 减少时间范围
# - 增加查询步长 (step)
# - 使用 recording rules 预计算

# 3. 增加 Grafana 资源
kubectl patch deployment grafana -n monitoring --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "1Gi"}
]'

# 4. 启用缓存
kubectl edit configmap grafana-config -n monitoring
# [database]
# cache_mode = redis
```

---

### 3.6 日志系统配置示例

#### Fluent Bit 配置示例

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: logging
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info
        Daemon        off
        Parsers_File  parsers.conf
        HTTP_Server   On
        HTTP_Listen   0.0.0.0
        HTTP_Port     2020

    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        Parser            docker
        Tag               kube.*
        Refresh_Interval  5
        Mem_Buf_Limit     50MB
        Skip_Long_Lines   On
        DB                /var/log/flb_kube.db

    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Merge_Log           On
        K8S-Logging.Parser  On
        K8S-Logging.Exclude On

    [OUTPUT]
        Name            es
        Match           *
        Host            elasticsearch
        Port            9200
        Index           kubernetes
        Type            _doc
        Logstash_Format On
        Logstash_Prefix kubernetes
        Retry_Limit     5
        Buffer_Size     False
        
  parsers.conf: |
    [PARSER]
        Name        docker
        Format      json
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L
        Time_Keep   On
```

---

### 3.7 监控告警规则示例

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kubernetes-alerts
  namespace: monitoring
spec:
  groups:
  - name: kubernetes
    rules:
    - alert: KubernetesPodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"
    
    - alert: KubernetesNodeNotReady
      expr: kube_node_status_condition{condition="Ready",status="true"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Node {{ $labels.node }} is not ready"
    
    - alert: KubernetesPodNotHealthy
      expr: sum by (namespace, pod) (kube_pod_status_phase{phase=~"Pending|Unknown|Failed"}) > 0
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is not healthy"
```

---

### 3.8 安全生产风险提示

| 操作 | 风险等级 | 风险说明 | 建议 |
|-----|---------|---------|-----|
| 删除 ES 索引 | 高 | 历史日志永久丢失 | 确认备份策略，删除前导出重要数据 |
| 重启日志采集器 | 低 | 短暂日志丢失 | 滚动重启，确认 buffer 持久化 |
| 修改 Prometheus 存储 | 中 | 可能丢失历史指标 | 备份 TSDB 数据，低峰期操作 |
| 修改告警规则 | 中 | 可能漏报或误报 | 充分测试，逐步灰度 |
| AlertManager 配置更改 | 中 | 可能影响告警发送 | 测试通知渠道后再上线 |
| Grafana 数据源修改 | 低 | Dashboard 可能无数据 | 先测试连接，保留旧配置 |

---

## 附录

### 常用排查命令速查

```bash
# 日志系统
kubectl get pods -n logging
kubectl logs -n logging -l app=fluent-bit
kubectl exec -n logging <es-pod> -- curl -s localhost:9200/_cluster/health

# 监控系统
kubectl get pods -n monitoring
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
kubectl port-forward -n monitoring svc/grafana 3000:80

# API 检查
curl -s http://localhost:9090/api/v1/targets | jq
curl -s http://localhost:9093/api/v2/alerts | jq

# 资源检查
kubectl top pods -n logging
kubectl top pods -n monitoring
```

### 相关文档

- [DaemonSet 故障排查](../05-workloads/04-daemonset-troubleshooting.md) (日志采集器)
- [StatefulSet 故障排查](../05-workloads/03-statefulset-troubleshooting.md) (ES/Prometheus)
- [Service 故障排查](../03-networking/03-service-ingress-troubleshooting.md)
- [HPA/VPA 故障排查](../07-resources-scheduling/02-autoscaling-troubleshooting.md) (依赖 metrics)
