# API Server 性能调优

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)

## API Server 关键参数

| 参数 | 默认值 | 推荐值 | 说明 |
|------|--------|--------|------|
| --max-requests-inflight | 400 | 800-1600 | 非 mutating 请求并发数 |
| --max-mutating-requests-inflight | 200 | 400-800 | mutating 请求并发数 |
| --request-timeout | 1m0s | 1m0s | 请求超时 |
| --min-request-timeout | 1800 | 1800 | Watch 最小超时 |
| --watch-cache-sizes | 100 | 按对象调整 | Watch 缓存大小 |
| --default-watch-cache-size | 100 | 500-1000 | 默认 Watch 缓存 |
| --etcd-servers-overrides | - | 按类型分离 | etcd 分库 |
| --audit-log-maxage | 0 | 7 | 审计日志保留天数 |
| --audit-log-maxsize | 0 | 100 | 审计日志大小(MB) |
| --audit-log-maxbackup | 0 | 10 | 审计日志备份数 |

## 大规模集群配置

```yaml
# /etc/kubernetes/manifests/kube-apiserver.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - name: kube-apiserver
    image: registry.k8s.io/kube-apiserver:v1.30.0
    command:
    - kube-apiserver
    # 认证授权
    - --authorization-mode=Node,RBAC
    - --enable-admission-plugins=NodeRestriction,ResourceQuota,LimitRanger
    # 并发控制
    - --max-requests-inflight=1600
    - --max-mutating-requests-inflight=800
    # 超时设置
    - --request-timeout=60s
    - --min-request-timeout=1800
    # Watch 缓存
    - --default-watch-cache-size=1000
    - --watch-cache-sizes=pods#5000,nodes#1000,services#1000
    # etcd 配置
    - --etcd-servers=https://etcd-0:2379,https://etcd-1:2379,https://etcd-2:2379
    - --etcd-compaction-interval=5m
    - --etcd-count-metric-poll-period=1m
    # 审计配置
    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    - --audit-log-maxage=7
    - --audit-log-maxsize=100
    - --audit-log-maxbackup=10
    - --audit-log-format=json
    # API 优先级和公平性 (APF)
    - --enable-priority-and-fairness=true
    # 性能调优
    - --profiling=false
    - --goaway-chance=0
    resources:
      requests:
        cpu: 2000m
        memory: 4Gi
      limits:
        cpu: 4000m
        memory: 8Gi
```

## API 优先级和公平性 (APF) 配置

```yaml
# PriorityLevelConfiguration - 定义优先级
apiVersion: flowcontrol.apiserver.k8s.io/v1
kind: PriorityLevelConfiguration
metadata:
  name: workload-high
spec:
  type: Limited
  limited:
    nominalConcurrencyShares: 100
    limitResponse:
      type: Queue
      queuing:
        queues: 64
        handSize: 8
        queueLengthLimit: 50
    lendablePercent: 0
    borrowingLimitPercent: 0
---
# FlowSchema - 匹配请求到优先级
apiVersion: flowcontrol.apiserver.k8s.io/v1
kind: FlowSchema
metadata:
  name: pods-high-priority
spec:
  priorityLevelConfiguration:
    name: workload-high
  matchingPrecedence: 1000
  distinguisherMethod:
    type: ByUser
  rules:
  - subjects:
    - kind: ServiceAccount
      serviceAccount:
        name: critical-app
        namespace: production
    resourceRules:
    - verbs: ["get", "list", "watch", "create", "update", "delete"]
      apiGroups: [""]
      resources: ["pods", "pods/status"]
      namespaces: ["production"]
```

## APF 内置优先级

| 优先级 | 并发份额 | 用途 |
|--------|----------|------|
| exempt | 无限制 | system:masters |
| system | 30 | 系统组件 |
| leader-election | 10 | 选举请求 |
| workload-high | 40 | 高优先工作负载 |
| workload-low | 100 | 普通工作负载 |
| global-default | 20 | 默认 |
| catch-all | 5 | 兜底 |

## 审计策略配置

```yaml
# /etc/kubernetes/audit/policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# 不记录的请求
- level: None
  users: ["system:kube-proxy"]
  verbs: ["watch"]
  resources:
  - group: ""
    resources: ["endpoints", "services", "services/status"]
    
- level: None
  users: ["kubelet"]
  verbs: ["get"]
  resources:
  - group: ""
    resources: ["nodes", "nodes/status"]
    
- level: None
  userGroups: ["system:nodes"]
  verbs: ["get"]
  resources:
  - group: ""
    resources: ["secrets"]

# 元数据级别
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
    
# 请求级别
- level: Request
  verbs: ["create", "update", "patch", "delete"]
  resources:
  - group: ""
    resources: ["pods", "deployments", "services"]
  - group: "apps"
    resources: ["deployments", "statefulsets", "daemonsets"]

# 完整记录安全相关
- level: RequestResponse
  resources:
  - group: "rbac.authorization.k8s.io"
  - group: "authentication.k8s.io"
```

## etcd 分库配置 (大规模集群)

```yaml
# 事件独立 etcd
- --etcd-servers-overrides=/events#https://etcd-events:2379

# 多资源分离 (超大规模)
- --etcd-servers-overrides=/events#https://etcd-events:2379;/pods#https://etcd-pods:2379
```

## API Server 诊断命令

```bash
# 查看 API Server 指标
kubectl get --raw /metrics | grep apiserver_request

# 查看当前请求并发数
kubectl get --raw /metrics | grep apiserver_current_inflight_requests

# 查看 APF 状态
kubectl get --raw /debug/api_priority_and_fairness/dump_priority_levels
kubectl get --raw /debug/api_priority_and_fairness/dump_queues

# 查看请求延迟分布
kubectl get --raw /metrics | grep apiserver_request_duration_seconds

# 查看 Watch 连接数
kubectl get --raw /metrics | grep apiserver_watch_events

# 查看认证授权延迟
kubectl get --raw /metrics | grep authentication_duration
kubectl get --raw /metrics | grep authorization_duration

# etcd 请求延迟
kubectl get --raw /metrics | grep etcd_request_duration
```

## 性能监控指标

| 指标 | 说明 | 告警阈值 |
|------|------|----------|
| apiserver_request_duration_seconds | 请求延迟 | P99 > 1s |
| apiserver_current_inflight_requests | 当前并发 | > 80% 限制 |
| apiserver_request_total | 请求总数 | 用于趋势 |
| etcd_request_duration_seconds | etcd 延迟 | P99 > 100ms |
| apiserver_storage_objects | 存储对象数 | 接近 etcd 限制 |
| apiserver_watch_events_total | Watch 事件 | 用于趋势 |

## 监控告警规则

```yaml
groups:
- name: apiserver
  rules:
  - alert: APIServerLatencyHigh
    expr: |
      histogram_quantile(0.99, sum(rate(apiserver_request_duration_seconds_bucket{verb!="WATCH"}[5m])) by (le, verb, resource)) > 1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "API Server {{ $labels.verb }} {{ $labels.resource }} P99 延迟 > 1s"
      
  - alert: APIServerErrorRateHigh
    expr: |
      sum(rate(apiserver_request_total{code=~"5.."}[5m])) 
      / sum(rate(apiserver_request_total[5m])) > 0.01
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "API Server 错误率超过 1%"
      
  - alert: APIServerRequestsThrottled
    expr: |
      sum(rate(apiserver_dropped_requests_total[5m])) > 0
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "API Server 请求被限流"
      
  - alert: APIServerTooManyRequests
    expr: |
      sum(apiserver_current_inflight_requests) 
      / sum(apiserver_current_inflight_requests_limit) > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "API Server 并发请求接近限制"
      
  - alert: EtcdRequestLatencyHigh
    expr: |
      histogram_quantile(0.99, sum(rate(etcd_request_duration_seconds_bucket[5m])) by (le, operation)) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd {{ $labels.operation }} 请求延迟 > 100ms"
```

## 常见问题与调优

| 问题 | 现象 | 解决方案 |
|------|------|----------|
| 请求超时 | 504/408 错误增多 | 增加 request-timeout |
| 请求被拒 | 429 Too Many Requests | 调整 APF 或增加并发限制 |
| Watch 断开 | Watch 频繁重连 | 增加 watch-cache-sizes |
| 审计日志大 | 磁盘空间不足 | 调整审计级别和保留策略 |
| etcd 慢 | 请求延迟高 | etcd 分库或优化 etcd |
| OOM | API Server 重启 | 增加内存限制 |

## ACK API Server 配置

```bash
# 查看托管 API Server 状态
kubectl get cs

# 通过 ACK 控制台配置
# 集群信息 -> 集群配置 -> API Server 参数

# 常用托管集群配置项
# - 审计日志开关
# - 审计日志保留时间
# - API Server 访问控制 (公网/私网)
```
