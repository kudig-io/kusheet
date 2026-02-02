# API 优先级与公平性 (APF) 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 高级
>
> **版本说明**:
> - APF 自 v1.20 Beta, v1.29+ GA (默认启用)
> - v1.26+ 支持 borrowingLimitPercent 借用限制
> - v1.29+ FlowSchema 支持 subject.serviceAccount 的 namespace 通配符

---

## 第一部分：问题现象与影响分析

### 1.1 API Priority and Fairness 架构

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    API Priority and Fairness (APF)                       │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌────────────────────────────────────────────────────────────────┐    │
│   │                    请求进入 API Server                          │    │
│   └────────────────────────────┬───────────────────────────────────┘    │
│                                │                                         │
│                                ▼                                         │
│   ┌────────────────────────────────────────────────────────────────┐    │
│   │              FlowSchema (请求分类)                              │    │
│   │                                                                 │    │
│   │  根据以下条件匹配请求:                                          │    │
│   │  - 用户/组                                                      │    │
│   │  - ServiceAccount                                               │    │
│   │  - 请求动词 (get, list, watch, create, etc.)                   │    │
│   │  - 资源类型                                                     │    │
│   │  - Namespace                                                    │    │
│   │                                                                 │    │
│   │  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐   │    │
│   │  │ system-leader │ │  workload-   │ │   catch-all          │   │    │
│   │  │  -election   │ │  controller  │ │                      │   │    │
│   │  │ (优先级 200) │ │ (优先级 150) │ │ (优先级 0)           │   │    │
│   │  └──────┬───────┘ └──────┬───────┘ └──────────┬───────────┘   │    │
│   │         │                │                    │                │    │
│   └─────────┼────────────────┼────────────────────┼────────────────┘    │
│             │                │                    │                      │
│             └────────────────┼────────────────────┘                      │
│                              │                                           │
│                              ▼                                           │
│   ┌────────────────────────────────────────────────────────────────┐    │
│   │              PriorityLevelConfiguration (优先级配置)            │    │
│   │                                                                 │    │
│   │  定义:                                                          │    │
│   │  - 并发数限制 (concurrencyShares)                              │    │
│   │  - 队列配置 (queues, queueLengthLimit)                         │    │
│   │  - 超时处理                                                     │    │
│   │                                                                 │    │
│   │  ┌────────────────────────────────────────────────────────┐   │    │
│   │  │  exempt       │ 不受限制 (system:masters 等)            │   │    │
│   │  │  system       │ 系统组件请求                            │   │    │
│   │  │  leader-elect │ Leader 选举                             │   │    │
│   │  │  workload-high│ 高优先级工作负载                        │   │    │
│   │  │  workload-low │ 普通工作负载                            │   │    │
│   │  │  global-default│ 默认/兜底                              │   │    │
│   │  └────────────────────────────────────────────────────────┘   │    │
│   │                                                                 │    │
│   └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│   请求处理流程:                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                                                                 │   │
│   │   请求 ──► FlowSchema匹配 ──► 分配到优先级队列                 │   │
│   │                                    │                            │   │
│   │                                    ▼                            │   │
│   │                              ┌──────────┐                       │   │
│   │                              │ 队列管理 │                       │   │
│   │                              │ (公平调度)│                       │   │
│   │                              └────┬─────┘                       │   │
│   │                                   │                             │   │
│   │                    ┌──────────────┼──────────────┐              │   │
│   │                    │              │              │              │   │
│   │                    ▼              ▼              ▼              │   │
│   │              立即执行        排队等待       拒绝(429)          │   │
│   │           (有并发配额)    (配额已满)     (队列已满)           │   │
│   │                                                                 │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 错误信息 | 查看方式 |
|----------|----------|----------|----------|
| 请求被限流 | API 返回 429 | Too Many Requests | kubectl 输出、应用日志 |
| 请求延迟高 | API 响应慢 | 无 | 监控指标 |
| 系统请求被影响 | 控制器/调度器慢 | 无 | 组件日志 |
| FlowSchema 不匹配 | 请求分类错误 | 无 | APF 指标 |
| 优先级配置错误 | 资源配置无效 | Invalid | kubectl describe |
| 配额分配不均 | 部分请求饥饿 | 无 | APF 指标 |
| 队列溢出 | 请求被丢弃 | 无 | APF 指标 |

### 1.3 影响分析

| 问题类型 | 直接影响 | 间接影响 | 影响范围 |
|----------|----------|----------|----------|
| 请求 429 限流 | 客户端操作失败 | 部署/扩缩容延迟 | 受限的请求类型 |
| 系统请求受影响 | 控制器工作异常 | 集群状态不一致 | 整个集群 |
| 不公平调度 | 部分用户体验差 | 资源使用不均衡 | 特定用户/应用 |
| 配置错误 | APF 行为异常 | 可能导致级联问题 | 按配置影响范围 |

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
APF 问题
    │
    ▼
┌───────────────────────┐
│  问题类型是什么？      │
└───────────────────────┘
    │
    ├── 请求被限流 (429) ────────────────────────────────────┐
    │                                                         │
    │   ┌─────────────────────────────────────────┐          │
    │   │ 确定请求被分配到哪个优先级              │          │
    │   │ 检查 APF 指标                           │          │
    │   └─────────────────────────────────────────┘          │
    │                  │                                      │
    │                  ▼                                      │
    │   ┌─────────────────────────────────────────┐          │
    │   │ 该优先级的并发配额是否足够?             │          │
    │   └─────────────────────────────────────────┘          │
    │          │                │                             │
    │         否               是                             │
    │          │                │                             │
    │          ▼                ▼                             │
    │   ┌────────────┐   ┌────────────────┐                  │
    │   │ 调整优先级 │   │ 检查请求是否   │                  │
    │   │ 或并发配置 │   │ 分配到错误级别 │                  │
    │   └────────────┘   └────────────────┘                  │
    │                                                         │
    ├── FlowSchema 配置问题 ─────────────────────────────────┤
    │                                                         │
    │   ┌─────────────────────────────────────────┐          │
    │   │ 检查 FlowSchema 匹配规则                │          │
    │   │ kubectl get flowschema                  │          │
    │   └─────────────────────────────────────────┘          │
    │                  │                                      │
    │                  ▼                                      │
    │   ┌─────────────────────────────────────────┐          │
    │   │ 请求是否匹配了预期的 FlowSchema?        │          │
    │   └─────────────────────────────────────────┘          │
    │          │                │                             │
    │         否               是                             │
    │          │                │                             │
    │          ▼                ▼                             │
    │   ┌────────────┐   ┌────────────────┐                  │
    │   │ 检查匹配   │   │ FlowSchema     │                  │
    │   │ 规则和优先 │   │ 配置正确       │                  │
    │   │ 级顺序     │   │                │                  │
    │   └────────────┘   └────────────────┘                  │
    │                                                         │
    └── 性能/延迟问题 ───────────────────────────────────────┤
                                                              │
        ┌─────────────────────────────────────────┐          │
        │ 检查各优先级的请求排队情况              │          │
        │ 监控 APF 相关指标                       │          │
        └─────────────────────────────────────────┘          │
                   │                                          │
                   ▼                                          │
        ┌─────────────────────────────────────────┐          │
        │ 是否有优先级队列持续饱和?               │          │
        └─────────────────────────────────────────┘          │
                                                              │
                                                              ▼
                                                       ┌────────────┐
                                                       │ 问题定位   │
                                                       │ 完成       │
                                                       └────────────┘
```

### 2.2 排查命令集

#### APF 资源检查

```bash
# 列出所有 FlowSchema
kubectl get flowschema
kubectl get flowschema -o wide

# 查看 FlowSchema 详情
kubectl describe flowschema <name>

# 列出所有 PriorityLevelConfiguration
kubectl get prioritylevelconfiguration
kubectl get prioritylevelconfiguration -o wide

# 查看优先级配置详情
kubectl describe prioritylevelconfiguration <name>

# 查看 APF 配置 YAML
kubectl get flowschema <name> -o yaml
kubectl get prioritylevelconfiguration <name> -o yaml
```

#### APF 指标检查

```bash
# 从 API Server 获取 APF 指标
kubectl get --raw /metrics | grep apiserver_flowcontrol

# 关键指标:
# apiserver_flowcontrol_dispatched_requests_total - 已分派的请求
# apiserver_flowcontrol_rejected_requests_total - 被拒绝的请求 (429)
# apiserver_flowcontrol_current_inqueue_requests - 当前排队的请求
# apiserver_flowcontrol_current_executing_requests - 当前执行中的请求
# apiserver_flowcontrol_request_queue_length_after_enqueue - 入队后的队列长度
# apiserver_flowcontrol_request_wait_duration_seconds - 等待时间

# 查看被拒绝的请求
kubectl get --raw /metrics | grep 'apiserver_flowcontrol_rejected_requests_total'

# 查看各优先级的执行情况
kubectl get --raw /metrics | grep 'apiserver_flowcontrol_current_executing_requests'
```

#### 调试 API

```bash
# 查看当前请求会匹配哪个 FlowSchema (调试)
# 需要开启 API Server 的调试端点

# 列出内置的 FlowSchema
kubectl get flowschema | grep -v "^NAME"

# 检查系统级别的配置
kubectl get flowschema -o json | jq '.items[] | {name: .metadata.name, priority: .spec.matchingPrecedence, plc: .spec.priorityLevelConfiguration.name}'
```

### 2.3 排查注意事项

| 注意事项 | 说明 | 风险等级 |
|----------|------|----------|
| 不要删除系统 FlowSchema | 可能影响集群核心功能 | 高 |
| 谨慎修改 exempt 级别 | 可能导致管理员被锁定 | 高 |
| 配置变更后观察指标 | APF 配置变更可能有延迟效果 | 中 |
| 注意 FlowSchema 优先级顺序 | 数字越小优先级越高 (先匹配) | 中 |

## 第三部分：解决方案与风险控制

### 3.1 请求被 429 限流

**问题现象**：客户端收到 `429 Too Many Requests` 错误。

**解决步骤**：

```bash
# 步骤 1: 确认哪些请求被限流
kubectl get --raw /metrics | grep 'apiserver_flowcontrol_rejected_requests_total' | grep -v "^#"

# 输出示例:
# apiserver_flowcontrol_rejected_requests_total{flow_schema="service-accounts",priority_level="workload-low",reason="queue-full"} 42

# 步骤 2: 检查对应的优先级配置
kubectl describe prioritylevelconfiguration workload-low

# 步骤 3: 检查并发限制和队列配置
kubectl get prioritylevelconfiguration workload-low -o yaml

# 步骤 4: 根据情况调整配置
# 方案 1: 增加并发配额
# 方案 2: 增加队列长度
# 方案 3: 将请求分配到更高优先级
```

**调整优先级配置示例**：

```yaml
apiVersion: flowcontrol.apiserver.k8s.io/v1beta3
kind: PriorityLevelConfiguration
metadata:
  name: workload-high
spec:
  type: Limited
  limited:
    # 增加并发份额
    nominalConcurrencyShares: 40  # 默认通常是 30
    
    # 队列配置
    limitResponse:
      type: Queue
      queuing:
        queues: 64          # 队列数量
        handSize: 6         # 每次调度从几个队列中选
        queueLengthLimit: 50  # 每个队列最大长度
```

### 3.2 自定义 FlowSchema

**问题现象**：需要为特定应用/用户配置专门的流控规则。

**配置示例**：

```yaml
# 为重要应用创建专用 FlowSchema
apiVersion: flowcontrol.apiserver.k8s.io/v1beta3
kind: FlowSchema
metadata:
  name: important-app
spec:
  # 匹配优先级 (数字越小越先匹配)
  matchingPrecedence: 1000
  
  # 关联的优先级配置
  priorityLevelConfiguration:
    name: workload-high
  
  # 匹配规则
  rules:
  - subjects:
    - kind: ServiceAccount
      serviceAccount:
        name: important-app-sa
        namespace: production
    resourceRules:
    - verbs: ["*"]
      apiGroups: ["*"]
      resources: ["*"]
      namespaces: ["production"]

---
# 为特定用户组创建 FlowSchema
apiVersion: flowcontrol.apiserver.k8s.io/v1beta3
kind: FlowSchema
metadata:
  name: developers
spec:
  matchingPrecedence: 2000
  priorityLevelConfiguration:
    name: workload-low
  rules:
  - subjects:
    - kind: Group
      group:
        name: developers
    resourceRules:
    - verbs: ["get", "list", "watch"]
      apiGroups: ["*"]
      resources: ["*"]
      namespaces: ["*"]
```

### 3.3 保护系统组件

**问题现象**：用户请求影响了系统组件（如 kube-controller-manager）。

**解决步骤**：

```bash
# 步骤 1: 检查系统组件的 FlowSchema
kubectl get flowschema | grep -E "system|leader|workload"

# 步骤 2: 验证系统组件请求的优先级
kubectl get flowschema system-leader-election -o yaml
kubectl get flowschema system-nodes -o yaml

# 步骤 3: 如果系统 FlowSchema 被意外修改，恢复默认配置
# 删除自定义的 FlowSchema (系统会自动重建默认的)
kubectl get flowschema -o name | grep -v "system\|exempt\|catch-all" | xargs kubectl delete

# 步骤 4: 确保系统优先级配置正确
kubectl get prioritylevelconfiguration
```

**系统默认优先级顺序**：

```
exempt          - 完全不受限制 (system:masters)
system          - 系统组件请求
leader-election - Leader 选举
workload-high   - 高优先级工作负载
workload-low    - 普通工作负载
global-default  - 默认兜底
```

### 3.4 查看请求分类情况

**问题现象**：不确定请求被分配到哪个 FlowSchema/PriorityLevel。

**解决步骤**：

```bash
# 步骤 1: 查看 APF 分派指标
kubectl get --raw /metrics | grep 'apiserver_flowcontrol_dispatched_requests_total' | head -20

# 步骤 2: 查看各 FlowSchema 的请求统计
kubectl get --raw /metrics | grep 'apiserver_flowcontrol_dispatched_requests_total' | \
  grep -oP 'flow_schema="[^"]+' | sort | uniq -c | sort -rn

# 步骤 3: 检查 catch-all 是否有大量请求
kubectl get --raw /metrics | grep 'apiserver_flowcontrol_dispatched_requests_total' | grep 'catch-all'

# 如果 catch-all 有大量请求，说明这些请求没有匹配到更具体的 FlowSchema
# 应该为它们创建专用的 FlowSchema

# 步骤 4: 检查 FlowSchema 匹配规则
kubectl get flowschema -o json | jq '.items[] | {name: .metadata.name, precedence: .spec.matchingPrecedence, rules: .spec.rules}'
```

### 3.5 调整并发限制

**问题现象**：需要增加整体或特定优先级的并发处理能力。

**解决步骤**：

```bash
# 步骤 1: 了解当前配置
kubectl get prioritylevelconfiguration -o custom-columns=\
NAME:.metadata.name,\
TYPE:.spec.type,\
SHARES:.spec.limited.nominalConcurrencyShares

# 步骤 2: 计算实际并发限制
# 公式: 
# 实际并发 = ServerConcurrencyLimit * (shares / totalShares)
# 
# ServerConcurrencyLimit 由 API Server 的 --max-requests-inflight 和 
# --max-mutating-requests-inflight 决定

# 步骤 3: 调整配置
kubectl edit prioritylevelconfiguration workload-high
```

**调整示例**：

```yaml
apiVersion: flowcontrol.apiserver.k8s.io/v1beta3
kind: PriorityLevelConfiguration
metadata:
  name: workload-high
spec:
  type: Limited
  limited:
    # 增加份额以获得更多并发配额
    nominalConcurrencyShares: 50  # 增加
    
    # 借用配置 (可以临时借用其他级别的空闲配额)
    lendablePercent: 0  # 不借出
    borrowingLimitPercent: 100  # 可以借入最多 100%
    
    limitResponse:
      type: Queue
      queuing:
        queues: 64
        handSize: 6
        queueLengthLimit: 50
```

### 3.6 处理队列溢出

**问题现象**：请求队列满导致请求被丢弃。

**解决步骤**：

```bash
# 步骤 1: 检查队列状态指标
kubectl get --raw /metrics | grep 'apiserver_flowcontrol_request_queue_length'

# 步骤 2: 检查队列配置
kubectl get prioritylevelconfiguration <name> -o jsonpath='{.spec.limited.limitResponse.queuing}'

# 步骤 3: 调整队列参数
kubectl edit prioritylevelconfiguration <name>
```

**队列配置优化**：

```yaml
spec:
  limited:
    limitResponse:
      type: Queue
      queuing:
        # 增加队列数量 (提高公平性)
        queues: 128
        
        # 增加每个队列的长度 (容纳更多请求)
        queueLengthLimit: 100
        
        # handSize 影响调度公平性
        # 较小的值更公平，较大的值吞吐量更高
        handSize: 8
```

### 3.7 监控和告警配置

**Prometheus 告警规则示例**：

```yaml
groups:
- name: apf-alerts
  rules:
  # 请求被拒绝告警
  - alert: APIServerAPFRejectedRequests
    expr: rate(apiserver_flowcontrol_rejected_requests_total[5m]) > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "API Server 正在拒绝请求"
      description: "FlowSchema {{ $labels.flow_schema }} 的请求被拒绝，原因: {{ $labels.reason }}"

  # 队列长度过高告警
  - alert: APIServerAPFQueueLengthHigh
    expr: apiserver_flowcontrol_current_inqueue_requests > 50
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "APF 队列长度过高"
      description: "优先级 {{ $labels.priority_level }} 的队列长度: {{ $value }}"

  # 请求等待时间过长
  - alert: APIServerAPFHighLatency
    expr: histogram_quantile(0.99, rate(apiserver_flowcontrol_request_wait_duration_seconds_bucket[5m])) > 1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "APF 请求等待时间过长"
      description: "优先级 {{ $labels.priority_level }} P99 等待时间: {{ $value }}s"
```

### 3.8 安全生产风险提示

| 操作 | 风险等级 | 潜在风险 | 建议措施 |
|------|----------|----------|----------|
| 删除系统 FlowSchema | 极高 | 可能影响集群核心功能 | 绝对避免 |
| 修改 exempt 级别 | 高 | 可能锁定管理员 | 保持默认 |
| 大幅调整并发配额 | 中 | 可能影响其他工作负载 | 逐步调整 |
| 创建新 FlowSchema | 低 | 可能意外匹配请求 | 仔细设置优先级 |
| 修改队列参数 | 低 | 可能影响响应特性 | 观察指标变化 |

### 附录：快速诊断命令

```bash
# ===== APF 一键诊断脚本 =====

echo "=== FlowSchema 列表 ==="
kubectl get flowschema -o custom-columns=\
NAME:.metadata.name,\
PRECEDENCE:.spec.matchingPrecedence,\
PL:.spec.priorityLevelConfiguration.name

echo -e "\n=== PriorityLevelConfiguration 列表 ==="
kubectl get prioritylevelconfiguration -o custom-columns=\
NAME:.metadata.name,\
TYPE:.spec.type,\
SHARES:.spec.limited.nominalConcurrencyShares

echo -e "\n=== 被拒绝的请求 (最近) ==="
kubectl get --raw /metrics 2>/dev/null | grep 'apiserver_flowcontrol_rejected_requests_total' | grep -v "^#" | head -10

echo -e "\n=== 当前排队请求 ==="
kubectl get --raw /metrics 2>/dev/null | grep 'apiserver_flowcontrol_current_inqueue_requests' | grep -v "^#"

echo -e "\n=== 当前执行中请求 ==="
kubectl get --raw /metrics 2>/dev/null | grep 'apiserver_flowcontrol_current_executing_requests' | grep -v "^#"

echo -e "\n=== 请求分派统计 (Top 10) ==="
kubectl get --raw /metrics 2>/dev/null | grep 'apiserver_flowcontrol_dispatched_requests_total' | \
  grep -oP 'flow_schema="[^"]+' | sort | uniq -c | sort -rn | head -10
```

### 附录：默认 APF 配置

```yaml
# Kubernetes 默认的关键 FlowSchema

# 1. 豁免级别 - 完全不受限制
# 匹配 system:masters 组
---
apiVersion: flowcontrol.apiserver.k8s.io/v1beta3
kind: FlowSchema
metadata:
  name: exempt
spec:
  matchingPrecedence: 1
  priorityLevelConfiguration:
    name: exempt
  rules:
  - subjects:
    - kind: Group
      group:
        name: system:masters

# 2. 系统组件
---
apiVersion: flowcontrol.apiserver.k8s.io/v1beta3
kind: FlowSchema
metadata:
  name: system-nodes
spec:
  matchingPrecedence: 500
  priorityLevelConfiguration:
    name: system
  rules:
  - subjects:
    - kind: Group
      group:
        name: system:nodes

# 3. Leader 选举
---
apiVersion: flowcontrol.apiserver.k8s.io/v1beta3
kind: FlowSchema
metadata:
  name: system-leader-election
spec:
  matchingPrecedence: 100
  priorityLevelConfiguration:
    name: leader-election
  rules:
  - subjects:
    - kind: User
      user:
        name: system:kube-controller-manager
    - kind: User
      user:
        name: system:kube-scheduler
    resourceRules:
    - verbs: ["get", "create", "update"]
      apiGroups: ["coordination.k8s.io"]
      resources: ["leases"]

# 4. ServiceAccount 默认 FlowSchema
---
apiVersion: flowcontrol.apiserver.k8s.io/v1beta3
kind: FlowSchema
metadata:
  name: service-accounts
spec:
  matchingPrecedence: 9000
  priorityLevelConfiguration:
    name: workload-low
  rules:
  - subjects:
    - kind: Group
      group:
        name: system:serviceaccounts
```
