# 表格28: 调度器配置与优化

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/scheduling-eviction](https://kubernetes.io/docs/concepts/scheduling-eviction/)

## 调度流程

```
Pod创建 → 调度队列 → PreEnqueue → QueueSort → PreFilter → Filter → PostFilter
                                                                      ↓
                          PostBind ← Bind ← PreBind ← Permit ← Reserve ← Score
```

## 调度器配置文件结构

| 配置项 | 类型 | 默认值 | 说明 | 调优建议 |
|-------|-----|-------|------|---------|
| `parallelism` | int | 16 | 并行调度goroutine数 | 大集群可增加到32-64 |
| `percentageOfNodesToScore` | int | 0(自动) | 评分节点百分比 | 大集群降低到10-30 |
| `podInitialBackoffSeconds` | int | 1 | 初始退避时间 | 保持默认 |
| `podMaxBackoffSeconds` | int | 10 | 最大退避时间 | 保持默认 |
| `profiles` | []Profile | default | 调度器配置档案 | 按需配置多个 |
| `leaderElection` | LeaderElection | enabled | 选举配置 | HA必须启用 |
| `clientConnection.qps` | float | 50 | API QPS | 大集群可增加 |
| `clientConnection.burst` | int | 100 | API Burst | 大集群可增加 |

## 调度插件阶段

| 阶段 | 用途 | 默认插件 | 可扩展 |
|-----|------|---------|-------|
| PreEnqueue | 入队前检查 | SchedulingGates | ✅ |
| QueueSort | 队列排序 | PrioritySort | ✅ |
| PreFilter | 预过滤检查 | NodeResourcesFit | ✅ |
| Filter | 节点过滤 | NodeAffinity, PodTopologySpread | ✅ |
| PostFilter | 过滤后处理 | DefaultPreemption | ✅ |
| PreScore | 评分前准备 | TaintToleration | ✅ |
| Score | 节点评分 | NodeResourcesBalancedAllocation | ✅ |
| NormalizeScore | 分数归一化 | - | ✅ |
| Reserve | 资源预留 | VolumeBinding | ✅ |
| Permit | 许可检查 | - | ✅ |
| PreBind | 绑定前准备 | VolumeBinding | ✅ |
| Bind | 执行绑定 | DefaultBinder | ✅ |
| PostBind | 绑定后处理 | - | ✅ |

## 默认调度插件

| 插件名称 | 阶段 | 功能 | v1.25 | v1.32 |
|---------|-----|------|-------|-------|
| NodeResourcesFit | Filter/Score | 资源适配 | ✅ | ✅ |
| NodeAffinity | Filter/Score | 节点亲和 | ✅ | ✅ |
| PodTopologySpread | Filter/Score | 拓扑分布 | ✅ | ✅ |
| InterPodAffinity | Filter/Score | Pod亲和 | ✅ | ✅ |
| TaintToleration | Filter/Score | 污点容忍 | ✅ | ✅ |
| NodePorts | Filter | 端口冲突 | ✅ | ✅ |
| VolumeBinding | Filter/PreBind | 卷绑定 | ✅ | ✅ |
| NodeResourcesBalancedAllocation | Score | 资源均衡 | ✅ | ✅ |
| ImageLocality | Score | 镜像本地性 | ✅ | ✅ |
| DefaultPreemption | PostFilter | 抢占调度 | ✅ | ✅ |

## 调度配置示例

```yaml
# /etc/kubernetes/scheduler-config.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
parallelism: 32
percentageOfNodesToScore: 30
leaderElection:
  leaderElect: true
  leaseDuration: 15s
  renewDeadline: 10s
  retryPeriod: 2s
clientConnection:
  kubeconfig: /etc/kubernetes/scheduler.conf
  qps: 100
  burst: 200
profiles:
# 默认调度器配置
- schedulerName: default-scheduler
  plugins:
    # 评分插件配置
    score:
      enabled:
      - name: NodeResourcesBalancedAllocation
        weight: 2
      - name: ImageLocality
        weight: 1
      - name: InterPodAffinity
        weight: 2
      - name: NodeAffinity
        weight: 2
      - name: PodTopologySpread
        weight: 2
      disabled:
      - name: NodeResourcesLeastAllocated
    # 过滤插件配置  
    filter:
      enabled:
      - name: NodeResourcesFit
      - name: NodeAffinity
      - name: PodTopologySpread
      - name: TaintToleration
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: MostAllocated  # 资源整合策略
        resources:
        - name: cpu
          weight: 1
        - name: memory
          weight: 1
        - name: nvidia.com/gpu
          weight: 10
  - name: PodTopologySpread
    args:
      defaultingType: List
      defaultConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
# GPU专用调度器
- schedulerName: gpu-scheduler
  plugins:
    filter:
      enabled:
      - name: NodeResourcesFit
    score:
      enabled:
      - name: NodeResourcesFit
        weight: 10
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: MostAllocated
        resources:
        - name: nvidia.com/gpu
          weight: 10
        - name: cpu
          weight: 1
        - name: memory
          weight: 1
# 批处理调度器(低优先级任务)
- schedulerName: batch-scheduler
  plugins:
    score:
      enabled:
      - name: NodeResourcesFit
        weight: 1
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: LeastAllocated  # 负载均衡
```

```bash
# 启动调度器
kube-scheduler --config=/etc/kubernetes/scheduler-config.yaml
```

## 调度策略类型

| 策略 | 配置值 | 适用场景 | 效果 |
|-----|-------|---------|------|
| 最少分配 | LeastAllocated | 资源充足集群 | 负载均衡 |
| 最多分配 | MostAllocated | 节省成本 | 资源整合 |
| 容量比例 | RequestedToCapacityRatio | 灵活控制 | 自定义曲线 |

## PodTopologySpread配置

| 参数 | 类型 | 默认值 | 说明 | 版本 |
|-----|-----|-------|------|-----|
| `maxSkew` | int | 1 | 最大倾斜度 | v1.19+ |
| `topologyKey` | string | - | 拓扑键 | v1.19+ |
| `whenUnsatisfiable` | string | DoNotSchedule | 不满足时行为 | v1.19+ |
| `labelSelector` | LabelSelector | - | Pod选择器 | v1.19+ |
| `minDomains` | int | - | 最小域数 | v1.25+ |
| `nodeAffinityPolicy` | string | Honor | 亲和策略 | v1.26+ |
| `nodeTaintsPolicy` | string | Honor | 污点策略 | v1.26+ |
| `matchLabelKeys` | []string | - | 匹配标签键 | v1.27+ |

```yaml
# PodTopologySpread完整示例
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 6
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
        version: v1
    spec:
      topologySpreadConstraints:
      # 跨可用区均匀分布
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: web
        minDomains: 2  # 至少分布在2个zone
        nodeAffinityPolicy: Honor
        nodeTaintsPolicy: Honor
      # 跨节点均匀分布
      - maxSkew: 2
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: web
        # v1.27+ 同版本Pod分布
        matchLabelKeys:
        - version
      containers:
      - name: web
        image: nginx:1.25
```

## 抢占调度配置

| 配置项 | 默认值 | 说明 |
|-------|-------|------|
| PriorityClass | system-cluster-critical | 最高优先级 |
| preemptionPolicy | PreemptLowerPriority | 抢占策略 |
| nominatedNodeName | - | 提名节点 |

## 优先级类别

| 名称 | 优先级值 | 用途 | 抢占策略 | 说明 |
|-----|---------|------|---------|------|
| system-node-critical | 2000001000 | 关键系统组件 | PreemptLowerPriority | DaemonSet等 |
| system-cluster-critical | 2000000000 | 集群关键组件 | PreemptLowerPriority | kube-dns等 |
| 自定义高优先级 | 1000000 | 核心业务 | PreemptLowerPriority | 生产关键服务 |
| 自定义普通 | 0 | 普通业务 | PreemptLowerPriority | 一般应用 |
| 自定义低优先级 | -1000 | 可抢占任务 | Never | 批处理任务 |

```yaml
# 优先级类配置
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: "高优先级业务应用"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: batch-priority
value: -1000
globalDefault: false
preemptionPolicy: Never  # 不抢占其他Pod
description: "批处理任务,可被抢占"
---
# 使用优先级
apiVersion: v1
kind: Pod
metadata:
  name: high-priority-pod
spec:
  priorityClassName: high-priority
  containers:
  - name: app
    image: app:v1
```

## 调度门控(Scheduling Gates)

```yaml
# v1.27+ GA - Pod调度门控
apiVersion: v1
kind: Pod
metadata:
  name: gated-pod
spec:
  schedulingGates:
  - name: "example.com/resource-ready"
  - name: "example.com/quota-check"
  containers:
  - name: app
    image: app:v1
```

```bash
# 移除调度门控(允许调度)
kubectl patch pod gated-pod --type=json \
  -p='[{"op": "remove", "path": "/spec/schedulingGates/0"}]'
```

## ACK调度增强

| 功能 | 组件 | 说明 | 使用场景 |
|-----|------|------|---------|
| **GPU调度** | ack-ai-scheduler | GPU拓扑感知调度 | AI/ML训练 |
| **Gang调度** | ack-scheduler-plugins | 原子批量调度 | 分布式训练 |
| **容量调度** | ack-scheduler-plugins | 弹性配额 | 多租户 |
| **协同调度** | Koordinator | 混部调度 | 在线+离线混部 |
| **负载感知** | Koordinator | 基于真实负载调度 | 提高资源利用率 |

```yaml
# Koordinator负载感知调度
apiVersion: v1
kind: Pod
metadata:
  name: load-aware-pod
  labels:
    koordinator.sh/enable-colocation: "true"
spec:
  schedulerName: koord-scheduler
  containers:
  - name: app
    image: app:v1
    resources:
      requests:
        cpu: "1"
        memory: "2Gi"
---
# Gang调度 - Volcano
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: distributed-training
spec:
  minAvailable: 4  # 最少4个Pod同时调度
  schedulerName: volcano
  queue: default
  policies:
  - event: PodEvicted
    action: RestartJob
  tasks:
  - replicas: 4
    name: worker
    template:
      spec:
        containers:
        - name: worker
          image: training:v1
          resources:
            limits:
              nvidia.com/gpu: 8
---
# 弹性配额(ElasticQuota)
apiVersion: scheduling.sigs.k8s.io/v1alpha1
kind: ElasticQuota
metadata:
  name: team-a-quota
  namespace: team-a
spec:
  min:
    cpu: "10"
    memory: "20Gi"
  max:
    cpu: "100"
    memory: "200Gi"
```

## 调度性能调优

| 场景 | 参数 | 建议值 | 说明 |
|-----|------|-------|------|
| 大集群(>1000节点) | percentageOfNodesToScore | 10-20 | 减少评分节点 |
| 高并发调度 | parallelism | 32-64 | 增加并行度 |
| API压力大 | clientConnection.qps | 100-200 | 增加QPS |
| 调度延迟高 | podInitialBackoffSeconds | 0.5 | 减少退避 |

## 调度器监控指标

```yaml
# 关键Prometheus指标
scheduler_pending_pods                    # 等待调度的Pod数
scheduler_schedule_attempts_total         # 调度尝试总数
scheduler_scheduling_duration_seconds     # 调度耗时
scheduler_pod_scheduling_duration_seconds # Pod调度耗时
scheduler_preemption_attempts_total       # 抢占尝试数
scheduler_framework_extension_point_duration_seconds  # 插件耗时

# PrometheusRule
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: scheduler-alerts
spec:
  groups:
  - name: scheduler
    rules:
    - alert: SchedulerHighPendingPods
      expr: scheduler_pending_pods > 100
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "调度器待处理Pod过多"
        
    - alert: SchedulerHighLatency
      expr: |
        histogram_quantile(0.99, 
          sum(rate(scheduler_scheduling_duration_seconds_bucket[5m])) by (le)
        ) > 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "调度延迟P99超过1秒"
```

## 调度故障排查

```bash
# 查看Pod调度状态
kubectl describe pod <pod-name> | grep -A 10 Events

# 查看调度器日志
kubectl logs -n kube-system -l component=kube-scheduler --tail=100

# 检查节点资源
kubectl describe nodes | grep -A 10 "Allocated resources"

# 模拟调度
kubectl get pod <pod-name> -o yaml | kubectl apply --dry-run=server -f -

# 查看调度器配置
kubectl get configmap -n kube-system kube-scheduler -o yaml
```

## 版本变更记录

| 版本 | 变更内容 | 影响 |
|------|---------|------|
| v1.25 | NodeInclusionPolicies稳定 | TopologySpread更灵活 |
| v1.26 | PodSchedulingReadiness GA | 调度门控可用 |
| v1.27 | SchedulerQueueingHints Alpha, matchLabelKeys | 调度性能提升 |
| v1.28 | MatchLabelKeysInPodTopologySpread GA | 滚动更新更均匀 |
| v1.29 | QueueingHints Beta | 队列管理优化 |
| v1.30 | SchedulerQueueingHints GA | 生产可用 |
| v1.31 | 调度器性能改进 | 大集群调度更快 |
| v1.32 | Pod调度门控增强 | 更灵活的调度控制 |

---

**调度优化原则**: 合理配置percentageOfNodesToScore + 使用TopologySpread均衡分布 + 配置优先级防止资源争抢 + 监控调度延迟
