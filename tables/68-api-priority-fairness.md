# 表格68: API优先级与公平性(APF)

## APF概述

| 概念 | 说明 |
|-----|------|
| PriorityLevel | 定义请求优先级和资源配额 |
| FlowSchema | 将请求分类到优先级 |
| 公平排队 | 防止某类请求独占资源 |
| 借用机制 | 空闲配额可被其他级别借用 |

## 内置PriorityLevel

| 名称 | 用途 | 配额份额 | 队列数 |
|-----|------|---------|-------|
| exempt | 免除限流 | 无限制 | - |
| system | 系统组件 | 高 | 64 |
| leader-election | Leader选举 | 高 | 16 |
| workload-high | 高优先级工作负载 | 中 | 128 |
| workload-low | 低优先级工作负载 | 低 | 64 |
| global-default | 默认 | 低 | 128 |
| catch-all | 兜底 | 最低 | 64 |

## PriorityLevelConfiguration

```yaml
apiVersion: flowcontrol.apiserver.k8s.io/v1
kind: PriorityLevelConfiguration
metadata:
  name: custom-priority
spec:
  type: Limited
  limited:
    # 名义并发份额
    nominalConcurrencyShares: 100
    # 限制响应配置
    limitResponse:
      type: Queue
      queuing:
        queues: 64           # 队列数
        handSize: 6          # 每请求分发队列数
        queueLengthLimit: 50 # 队列长度限制
    # 借用配置(v1.29+)
    lendablePercent: 50      # 可借出百分比
    borrowingLimitPercent: 100  # 可借入百分比
```

## FlowSchema

```yaml
apiVersion: flowcontrol.apiserver.k8s.io/v1
kind: FlowSchema
metadata:
  name: high-priority-requests
spec:
  # 匹配优先级(数字越小越先匹配)
  matchingPrecedence: 1000
  # 关联的PriorityLevel
  priorityLevelConfiguration:
    name: workload-high
  # 请求匹配规则
  rules:
  - subjects:
    - kind: ServiceAccount
      serviceAccount:
        name: important-sa
        namespace: production
    resourceRules:
    - verbs: ["*"]
      apiGroups: ["*"]
      resources: ["*"]
      namespaces: ["production"]
---
apiVersion: flowcontrol.apiserver.k8s.io/v1
kind: FlowSchema
metadata:
  name: controller-requests
spec:
  matchingPrecedence: 800
  priorityLevelConfiguration:
    name: workload-high
  rules:
  - subjects:
    - kind: ServiceAccount
      serviceAccount:
        name: "*"
        namespace: kube-system
    resourceRules:
    - verbs: ["watch", "list"]
      apiGroups: ["*"]
      resources: ["*"]
```

## 区分Flow类型

| 规则字段 | 说明 | 示例 |
|---------|------|------|
| `subjects` | 请求发起者 | ServiceAccount, User, Group |
| `resourceRules` | 资源请求规则 | verbs, apiGroups, resources |
| `nonResourceRules` | 非资源请求 | /healthz, /metrics |

## APF监控指标

| 指标 | 类型 | 说明 |
|-----|-----|------|
| `apiserver_flowcontrol_request_concurrency_limit` | Gauge | 并发限制 |
| `apiserver_flowcontrol_current_executing_requests` | Gauge | 当前执行请求数 |
| `apiserver_flowcontrol_current_inqueue_requests` | Gauge | 当前排队请求数 |
| `apiserver_flowcontrol_dispatched_requests_total` | Counter | 已分发请求总数 |
| `apiserver_flowcontrol_rejected_requests_total` | Counter | 拒绝请求总数 |
| `apiserver_flowcontrol_request_wait_duration_seconds` | Histogram | 等待时间 |
| `apiserver_flowcontrol_request_execution_seconds` | Histogram | 执行时间 |

## Prometheus告警规则

```yaml
groups:
- name: apf-alerts
  rules:
  - alert: APIServerHighRejectionRate
    expr: |
      sum(rate(apiserver_flowcontrol_rejected_requests_total[5m])) 
      / sum(rate(apiserver_flowcontrol_dispatched_requests_total[5m])) > 0.01
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "API Server请求拒绝率过高"
      
  - alert: APIServerQueueSaturation
    expr: |
      sum by (priority_level) (apiserver_flowcontrol_current_inqueue_requests) 
      / sum by (priority_level) (apiserver_flowcontrol_nominal_limit_seats) > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "API Server队列接近饱和"
```

## 调试命令

```bash
# 查看PriorityLevel
kubectl get prioritylevelconfigurations

# 查看FlowSchema
kubectl get flowschemas

# 查看匹配详情
kubectl get flowschema <name> -o yaml

# 查看APF状态
kubectl get --raw /debug/api_priority_and_fairness/dump_priority_levels

# 查看请求分布
kubectl get --raw /debug/api_priority_and_fairness/dump_queues
```

## 请求头信息

| 响应头 | 说明 |
|-------|------|
| `X-Kubernetes-PF-FlowSchema-UID` | 匹配的FlowSchema |
| `X-Kubernetes-PF-PriorityLevel-UID` | 使用的PriorityLevel |

## 最佳实践

| 实践 | 说明 |
|-----|------|
| 保护控制器 | 为关键控制器设置高优先级 |
| 限制批量操作 | 大规模list/watch使用低优先级 |
| 监控拒绝率 | 及时发现配置问题 |
| 渐进调整 | 小步迭代优化配额 |
| 借用机制 | 合理配置提高利用率 |

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| v1.20 | APF Beta |
| v1.29 | APF GA,借用机制GA |
| v1.30 | 监控指标增强 |
| v1.31 | Seat计算优化 |
