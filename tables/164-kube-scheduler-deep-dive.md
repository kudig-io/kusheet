# Kubernetes Scheduler 深度解析 (Kube-Scheduler Deep Dive)

## 目录

1. [调度器架构概述](#1-调度器架构概述)
2. [调度框架与插件系统](#2-调度框架与插件系统)
3. [调度流程详解](#3-调度流程详解)
4. [内置插件详解](#4-内置插件详解)
5. [调度策略与算法](#5-调度策略与算法)
6. [优先级与抢占机制](#6-优先级与抢占机制)
7. [高级调度特性](#7-高级调度特性)
8. [调度器配置](#8-调度器配置)
9. [监控与可观测性](#9-监控与可观测性)
10. [故障排查与调优](#10-故障排查与调优)
11. [生产实践案例](#11-生产实践案例)

---

## 1. 调度器架构概述

### 1.1 调度器核心职责

| 职责 | 描述 | 关键机制 |
|------|------|----------|
| Pod 分配 (Pod Assignment) | 为 Pending 状态的 Pod 选择最优节点 | 过滤 (Filter) + 评分 (Score) |
| 资源匹配 (Resource Matching) | 确保节点资源满足 Pod 需求 | Requests/Limits 计算 |
| 约束满足 (Constraint Satisfaction) | 满足亲和性、容忍度等约束 | Affinity/Anti-Affinity/Toleration |
| 负载均衡 (Load Balancing) | 在集群节点间均衡分配工作负载 | Scoring 策略 |
| 高可用保障 (HA Guarantee) | 确保 Pod 的分布满足高可用要求 | PodTopologySpread |

### 1.2 调度器架构图

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Kube-Scheduler Architecture                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                              Informer Cache                                  ││
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐││
│  │  │ Pod Informer│ │Node Informer│ │ PV Informer │ │ PVC/SC/CSINode Informer │││
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                        │                                         │
│                                        ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                           Scheduling Queue                                   ││
│  │  ┌─────────────────┐ ┌─────────────────────┐ ┌────────────────────────────┐ ││
│  │  │  ActiveQ (heap) │ │ BackoffQ (heap)      │ │ UnschedulablePods (map)    │ ││
│  │  │  优先级排序      │ │ 退避重试等待         │ │ 不可调度 Pod 暂存          │ ││
│  │  └─────────────────┘ └─────────────────────┘ └────────────────────────────┘ ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                        │                                         │
│                                        ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                          Scheduling Framework                                ││
│  │  ┌───────────────────────────────────────────────────────────────────────┐  ││
│  │  │                      Scheduling Cycle (串行)                           │  ││
│  │  │  ┌─────────┐ ┌─────────┐ ┌──────────┐ ┌───────┐ ┌────────┐ ┌────────┐│  ││
│  │  │  │PreFilter│→│ Filter  │→│PostFilter│→│PreScore│→│ Score  │→│Reserve ││  ││
│  │  │  └─────────┘ └─────────┘ └──────────┘ └───────┘ └────────┘ └────────┘│  ││
│  │  └───────────────────────────────────────────────────────────────────────┘  ││
│  │  ┌───────────────────────────────────────────────────────────────────────┐  ││
│  │  │                        Binding Cycle (并行)                            │  ││
│  │  │  ┌─────────┐ ┌─────────┐ ┌───────────┐ ┌─────────────────────────────┐│  ││
│  │  │  │ Permit  │→│PreBind  │→│   Bind    │→│        PostBind             ││  ││
│  │  │  └─────────┘ └─────────┘ └───────────┘ └─────────────────────────────┘│  ││
│  │  └───────────────────────────────────────────────────────────────────────┘  ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                        │                                         │
│                                        ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                              API Server                                      ││
│  │                        (Pod Binding / Status Update)                         ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 1.3 调度器组件详解

| 组件 | 功能描述 | 关键实现 |
|------|----------|----------|
| Informer Cache | 缓存集群资源状态，减少 API Server 压力 | SharedIndexInformer |
| Scheduling Queue | 管理待调度 Pod 的优先级队列 | PriorityQueue (三队列模型) |
| Scheduling Framework | 可插拔的调度框架，支持扩展点 | Framework Interface |
| Node Info Snapshot | 节点信息快照，用于调度决策 | NodeInfo 结构体 |
| Scheduler Cache | 调度缓存，存储调度状态 | schedulerCache |

### 1.4 调度队列详解

| 队列类型 | 用途 | 触发条件 |
|----------|------|----------|
| ActiveQ | 活跃队列，待调度 Pod | 新 Pod 创建、退避完成 |
| BackoffQ | 退避队列，调度失败重试 | 调度失败、错误 |
| UnschedulablePods | 不可调度队列 | Filter 全失败、资源不足 |

```yaml
# 队列流转示例
# Pod 创建 → ActiveQ
# 调度失败 → BackoffQ (退避时间递增)
# 退避完成 → ActiveQ
# 资源持续不足 → UnschedulablePods
# 集群状态变化 → 重新入队 ActiveQ
```

---

## 2. 调度框架与插件系统

### 2.1 调度框架扩展点 (Extension Points)

| 扩展点 | 阶段 | 功能 | 调用方式 |
|--------|------|------|----------|
| PreEnqueue | 入队前 | 入队前预检查 | 串行 |
| QueueSort | 队列排序 | 决定 Pod 调度顺序 | 单一插件 |
| PreFilter | 过滤前 | 预处理、计算共享状态 | 串行 |
| Filter | 过滤 | 过滤不满足条件的节点 | 并行 |
| PostFilter | 过滤后 | 过滤失败后处理（抢占） | 串行 |
| PreScore | 评分前 | 评分前预处理 | 串行 |
| Score | 评分 | 为候选节点打分 | 并行 |
| NormalizeScore | 分数归一化 | 将分数归一化到 [0,100] | 串行 |
| Reserve | 预留 | 预留节点资源（乐观锁定） | 串行 |
| Permit | 许可 | 批准/拒绝/等待绑定 | 串行 |
| PreBind | 绑定前 | 绑定前准备工作 | 串行 |
| Bind | 绑定 | 执行实际绑定操作 | 串行(单一) |
| PostBind | 绑定后 | 绑定后清理/通知 | 串行 |

### 2.2 扩展点执行流程

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          Scheduling Extension Points Flow                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌──────────────────────────────── Scheduling Cycle ────────────────────────────┐│
│  │                                                                               ││
│  │    ┌───────────┐                                                              ││
│  │    │PreEnqueue │ ── 检查 Pod 是否可以入队                                     ││
│  │    └─────┬─────┘                                                              ││
│  │          ▼                                                                    ││
│  │    ┌───────────┐                                                              ││
│  │    │ QueueSort │ ── 决定 Pod 在队列中的优先级                                 ││
│  │    └─────┬─────┘                                                              ││
│  │          ▼                                                                    ││
│  │    ┌───────────┐      失败                                                    ││
│  │    │ PreFilter │ ─────────────────────────────────────────────────────►拒绝   ││
│  │    └─────┬─────┘                                                              ││
│  │          ▼ 成功                                                               ││
│  │    ┌───────────┐      所有节点被过滤                                          ││
│  │    │  Filter   │ ─────────────────────┐                                       ││
│  │    └─────┬─────┘                      ▼                                       ││
│  │          │                    ┌─────────────┐                                 ││
│  │          │                    │ PostFilter  │ ── 抢占逻辑                     ││
│  │          │                    └─────────────┘                                 ││
│  │          ▼ 有可用节点                                                         ││
│  │    ┌───────────┐                                                              ││
│  │    │ PreScore  │ ── 评分前预处理                                              ││
│  │    └─────┬─────┘                                                              ││
│  │          ▼                                                                    ││
│  │    ┌───────────┐                                                              ││
│  │    │   Score   │ ── 为每个候选节点打分 (并行执行各插件)                       ││
│  │    └─────┬─────┘                                                              ││
│  │          ▼                                                                    ││
│  │    ┌───────────┐                                                              ││
│  │    │ Normalize │ ── 将分数归一化到 [0,100]                                    ││
│  │    └─────┬─────┘                                                              ││
│  │          ▼                                                                    ││
│  │    ┌───────────┐                                                              ││
│  │    │  Reserve  │ ── 乐观预留选中节点资源                                      ││
│  │    └─────┬─────┘                                                              ││
│  │          ▼                                                                    ││
│  └──────────┼───────────────────────────────────────────────────────────────────┘│
│             │                                                                    │
│  ┌──────────┼──────────────────────── Binding Cycle ────────────────────────────┐│
│  │          ▼                                                                    ││
│  │    ┌───────────┐      wait                                                    ││
│  │    │  Permit   │ ─────────────────► 等待 (带超时)                             ││
│  │    └─────┬─────┘                                                              ││
│  │          ▼ approve                                                            ││
│  │    ┌───────────┐                                                              ││
│  │    │  PreBind  │ ── 绑定前准备 (如：PV 绑定)                                  ││
│  │    └─────┬─────┘                                                              ││
│  │          ▼                                                                    ││
│  │    ┌───────────┐                                                              ││
│  │    │   Bind    │ ── 将 Pod 绑定到节点 (写入 API Server)                       ││
│  │    └─────┬─────┘                                                              ││
│  │          ▼                                                                    ││
│  │    ┌───────────┐                                                              ││
│  │    │ PostBind  │ ── 绑定后处理 (清理、通知)                                   ││
│  │    └───────────┘                                                              ││
│  │                                                                               ││
│  └───────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 插件接口定义

| 接口名称 | 方法签名 | 返回值 |
|----------|----------|--------|
| PreEnqueuePlugin | `PreEnqueue(ctx, pod)` | `*Status` |
| QueueSortPlugin | `Less(p1, p2 *PodInfo) bool` | `bool` |
| PreFilterPlugin | `PreFilter(ctx, state, pod)` | `(*PreFilterResult, *Status)` |
| FilterPlugin | `Filter(ctx, state, pod, nodeInfo)` | `*Status` |
| PostFilterPlugin | `PostFilter(ctx, state, pod, filteredNodes)` | `(*PostFilterResult, *Status)` |
| PreScorePlugin | `PreScore(ctx, state, pod, nodes)` | `*Status` |
| ScorePlugin | `Score(ctx, state, pod, nodeName)` | `(int64, *Status)` |
| ScoreExtensions | `NormalizeScore(ctx, state, pod, scores)` | `*Status` |
| ReservePlugin | `Reserve(ctx, state, pod, nodeName)` | `*Status` |
| ReservePlugin | `Unreserve(ctx, state, pod, nodeName)` | - |
| PermitPlugin | `Permit(ctx, state, pod, nodeName)` | `(*Status, time.Duration)` |
| PreBindPlugin | `PreBind(ctx, state, pod, nodeName)` | `*Status` |
| BindPlugin | `Bind(ctx, state, pod, nodeName)` | `*Status` |
| PostBindPlugin | `PostBind(ctx, state, pod, nodeName)` | - |

### 2.4 插件状态码

| 状态码 | 含义 | 调度行为 |
|--------|------|----------|
| Success | 插件执行成功 | 继续下一步 |
| Error | 内部错误 | 终止调度，Pod 入 BackoffQ |
| Unschedulable | 当前不可调度 | 节点被过滤/Pod 入 UnschedulablePods |
| UnschedulableAndUnresolvable | 不可调度且无法通过抢占解决 | 跳过抢占逻辑 |
| Wait | 需要等待 (Permit 阶段) | 等待直到超时或批准 |
| Skip | 跳过此插件 | 继续执行下一个插件 |

---

## 3. 调度流程详解

### 3.1 完整调度流程

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Complete Scheduling Workflow                           │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  1. Pod 创建                                                                     │
│     kubectl apply -f pod.yaml                                                   │
│            │                                                                     │
│            ▼                                                                     │
│  2. API Server 存储 Pod (spec.nodeName 为空)                                    │
│            │                                                                     │
│            ▼                                                                     │
│  3. Scheduler Watch 到新 Pod                                                    │
│     ┌──────────────────────────────────────────────────────────────────────┐    │
│     │ Pod Informer → EventHandler → SchedulingQueue.Add(pod)              │    │
│     └──────────────────────────────────────────────────────────────────────┘    │
│            │                                                                     │
│            ▼                                                                     │
│  4. 调度循环 (scheduleOne)                                                       │
│     ┌──────────────────────────────────────────────────────────────────────┐    │
│     │ a. 从 ActiveQ 取出最高优先级 Pod                                      │    │
│     │ b. 创建调度周期 (SchedulingCycle)                                     │    │
│     │ c. 获取节点信息快照 (Snapshot)                                        │    │
│     └──────────────────────────────────────────────────────────────────────┘    │
│            │                                                                     │
│            ▼                                                                     │
│  5. 过滤阶段 (Filtering)                                                         │
│     ┌──────────────────────────────────────────────────────────────────────┐    │
│     │ PreFilter → Filter (并行评估所有节点) → PostFilter (如果需要)        │    │
│     │                                                                      │    │
│     │ Filter 插件并行检查每个节点:                                          │    │
│     │ - NodeResourcesFit: 检查资源是否满足                                  │    │
│     │ - NodeAffinity: 检查节点亲和性                                        │    │
│     │ - PodTopologySpread: 检查拓扑分布                                     │    │
│     │ - TaintToleration: 检查污点容忍                                       │    │
│     │ - NodePorts: 检查端口可用性                                           │    │
│     │ - ...更多 Filter 插件                                                 │    │
│     └──────────────────────────────────────────────────────────────────────┘    │
│            │                                                                     │
│            ▼                                                                     │
│  6. 评分阶段 (Scoring)                                                           │
│     ┌──────────────────────────────────────────────────────────────────────┐    │
│     │ PreScore → Score (并行为每个节点打分) → NormalizeScore               │    │
│     │                                                                      │    │
│     │ 每个插件为每个候选节点打分:                                            │    │
│     │ FinalScore = Σ(PluginScore × PluginWeight)                           │    │
│     │                                                                      │    │
│     │ 选择最高分节点 (如有并列则随机选择)                                    │    │
│     └──────────────────────────────────────────────────────────────────────┘    │
│            │                                                                     │
│            ▼                                                                     │
│  7. 预留阶段 (Reserve)                                                           │
│     ┌──────────────────────────────────────────────────────────────────────┐    │
│     │ 乐观预留: 在 Scheduler Cache 中标记资源已分配                         │    │
│     │ 防止并发调度将同一资源分配给多个 Pod                                   │    │
│     └──────────────────────────────────────────────────────────────────────┘    │
│            │                                                                     │
│            ▼                                                                     │
│  8. 绑定周期 (Binding Cycle) - 异步执行                                         │
│     ┌──────────────────────────────────────────────────────────────────────┐    │
│     │ Permit → PreBind → Bind → PostBind                                   │    │
│     │                                                                      │    │
│     │ Bind: 调用 API Server 更新 Pod.spec.nodeName                         │    │
│     └──────────────────────────────────────────────────────────────────────┘    │
│            │                                                                     │
│            ▼                                                                     │
│  9. Kubelet 检测到分配的 Pod, 开始创建容器                                       │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 调度决策算法

| 阶段 | 算法 | 复杂度 | 说明 |
|------|------|--------|------|
| Filter | 并行过滤 | O(N × P) | N=节点数, P=Filter 插件数 |
| Score | 并行评分 | O(F × S) | F=可行节点数, S=Score 插件数 |
| Select | 最高分选择 | O(F) | 选择分数最高的节点 |
| 总体 | - | O(N × P + F × S) | 通常 F << N |

### 3.3 调度性能优化机制

| 优化机制 | 描述 | 配置参数 |
|----------|------|----------|
| percentageOfNodesToScore | 评分节点百分比 | 默认 0 (自动计算) |
| parallelism | 并行度 | 默认 16 |
| Pod Preemption | 抢占低优先级 Pod | PriorityClass |
| Scheduling Queue | 三队列模型优化 | - |
| Node Info Cache | 节点信息缓存 | - |
| Incremental Scoring | 增量评分 | - |

```yaml
# 调度器性能配置示例
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
percentageOfNodesToScore: 50  # 只评分 50% 的可行节点
parallelism: 32               # 增加并行度
profiles:
- schedulerName: default-scheduler
  plugins:
    score:
      enabled:
      - name: NodeResourcesBalancedAllocation
        weight: 1
      - name: ImageLocality
        weight: 1
```

---

## 4. 内置插件详解

### 4.1 Filter 插件

| 插件名称 | 功能描述 | 过滤条件 |
|----------|----------|----------|
| NodeUnschedulable | 检查节点是否可调度 | node.spec.unschedulable == false |
| NodeName | 检查 Pod 指定的节点名 | pod.spec.nodeName 匹配 |
| TaintToleration | 检查污点容忍 | Pod 容忍节点所有 NoSchedule 污点 |
| NodeAffinity | 检查节点亲和性 | 满足 requiredDuringScheduling 规则 |
| NodePorts | 检查端口可用性 | Pod 需要的 HostPort 在节点上可用 |
| NodeResourcesFit | 检查资源是否满足 | 节点剩余资源 >= Pod 请求资源 |
| VolumeBinding | 检查存储卷绑定 | PVC 可以绑定到节点的 PV |
| VolumeZone | 检查存储卷可用区 | Pod 的 PV 与节点在同一可用区 |
| PodTopologySpread | 检查拓扑分布 | 满足 whenUnsatisfiable: DoNotSchedule |
| InterPodAffinity | 检查 Pod 间亲和性 | 满足 requiredDuringScheduling 规则 |

### 4.2 NodeResourcesFit 详解

```yaml
# NodeResourcesFit 策略配置
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
- schedulerName: default-scheduler
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        # 评分策略类型
        type: LeastAllocated  # 或 MostAllocated, RequestedToCapacityRatio
        resources:
        - name: cpu
          weight: 1
        - name: memory
          weight: 1
        - name: nvidia.com/gpu
          weight: 2
```

| 评分策略 | 公式 | 适用场景 |
|----------|------|----------|
| LeastAllocated | `(capacity - requested) / capacity × 100` | 默认策略，均衡负载 |
| MostAllocated | `requested / capacity × 100` | 紧凑分配，节省成本 |
| RequestedToCapacityRatio | 自定义曲线函数 | 精细控制资源分配 |

```yaml
# RequestedToCapacityRatio 配置示例
pluginConfig:
- name: NodeResourcesFit
  args:
    scoringStrategy:
      type: RequestedToCapacityRatio
      resources:
      - name: cpu
        weight: 1
      - name: memory
        weight: 1
      requestedToCapacityRatio:
        shape:
        - utilization: 0
          score: 0
        - utilization: 50
          score: 7
        - utilization: 100
          score: 10
```

### 4.3 Score 插件

| 插件名称 | 功能描述 | 评分逻辑 |
|----------|----------|----------|
| NodeResourcesBalancedAllocation | 资源均衡分配 | CPU/内存使用率差异最小化 |
| ImageLocality | 镜像本地化 | 节点已有镜像则得分更高 |
| InterPodAffinity | Pod 间亲和性评分 | 满足 preferredDuringScheduling 得分 |
| NodeAffinity | 节点亲和性评分 | 满足 preferredDuringScheduling 得分 |
| TaintToleration | 污点容忍评分 | 容忍更多污点则得分更高 |
| PodTopologySpread | 拓扑分布评分 | 分布越均匀得分越高 |
| SelectorSpread | 选择器分布 | 跨节点/可用区分布 (已废弃) |

### 4.4 ImageLocality 详解

| 镜像状态 | 评分影响 | 说明 |
|----------|----------|------|
| 镜像已存在于节点 | +分 (按镜像大小加权) | 减少拉取时间 |
| 镜像不存在 | 0 分 | 需要拉取镜像 |
| 多个容器镜像 | 累加分数 | 所有容器镜像分数之和 |

```go
// ImageLocality 评分算法 (简化版)
func calculateScore(nodeImageStates map[string]*ImageStateSummary, pod *v1.Pod) int64 {
    var totalScore int64
    for _, container := range pod.Spec.Containers {
        if state, ok := nodeImageStates[container.Image]; ok {
            // 根据镜像大小计算分数
            totalScore += state.Size / (1024 * 1024) // MB
        }
    }
    return min(totalScore, framework.MaxNodeScore)
}
```

### 4.5 PodTopologySpread 详解

```yaml
# PodTopologySpread 配置示例
apiVersion: v1
kind: Pod
metadata:
  name: web-server
  labels:
    app: web
spec:
  topologySpreadConstraints:
  - maxSkew: 1                           # 最大不均衡度
    topologyKey: topology.kubernetes.io/zone  # 拓扑键 (可用区)
    whenUnsatisfiable: DoNotSchedule     # 不满足时的行为
    labelSelector:
      matchLabels:
        app: web
    matchLabelKeys:
    - pod-template-hash                  # 按 ReplicaSet 分组
    minDomains: 3                        # 最小域数量
  - maxSkew: 2
    topologyKey: kubernetes.io/hostname  # 拓扑键 (节点)
    whenUnsatisfiable: ScheduleAnyway    # 软约束
    labelSelector:
      matchLabels:
        app: web
```

| 参数 | 说明 | 默认值 |
|------|------|--------|
| maxSkew | 最大不均衡度 | 无默认，必填 |
| topologyKey | 拓扑域标签键 | 无默认，必填 |
| whenUnsatisfiable | 不满足时行为 | DoNotSchedule |
| labelSelector | Pod 标签选择器 | 无默认 |
| matchLabelKeys | 动态标签键匹配 | 空 (v1.25+) |
| minDomains | 最小域数量 | 无 (v1.25+ beta) |
| nodeAffinityPolicy | 节点亲和性策略 | Honor |
| nodeTaintsPolicy | 节点污点策略 | Honor |

### 4.6 InterPodAffinity 详解

```yaml
# InterPodAffinity 配置示例
apiVersion: v1
kind: Pod
metadata:
  name: web-server
spec:
  affinity:
    podAffinity:
      # 硬性要求: 必须与 cache Pod 在同一可用区
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - cache
        topologyKey: topology.kubernetes.io/zone
        namespaces:
        - production
      # 软性偏好: 优先与 db Pod 在同一节点
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: db
          topologyKey: kubernetes.io/hostname
    podAntiAffinity:
      # 硬性要求: 不能与同一 app 的 Pod 在同一节点
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: web
        topologyKey: kubernetes.io/hostname
```

| 亲和性类型 | 作用 | 典型场景 |
|------------|------|----------|
| podAffinity.required | 必须与指定 Pod 共存 | 数据本地性 |
| podAffinity.preferred | 优先与指定 Pod 共存 | 降低延迟 |
| podAntiAffinity.required | 必须与指定 Pod 分离 | 高可用 |
| podAntiAffinity.preferred | 优先与指定 Pod 分离 | 分散负载 |

---

## 5. 调度策略与算法

### 5.1 资源分配策略对比

| 策略 | 算法公式 | 优点 | 缺点 | 适用场景 |
|------|----------|------|------|----------|
| LeastAllocated | `score = (capacity - allocated) / capacity × 100` | 负载均衡 | 资源利用率较低 | 通用场景 |
| MostAllocated | `score = allocated / capacity × 100` | 资源利用率高 | 可能造成热点 | 云环境节省成本 |
| RequestedToCapacityRatio | 自定义曲线 | 精细控制 | 配置复杂 | 特殊资源调度 |
| BalancedAllocation | `score = 1 - |cpuFraction - memFraction|` | CPU/内存均衡 | 单一维度 | 混合负载 |

### 5.2 LeastAllocated 详解

```
# LeastAllocated 计算公式
cpuScore = (nodeCapacity.cpu - nodeAllocated.cpu) / nodeCapacity.cpu × 100
memScore = (nodeCapacity.mem - nodeAllocated.mem) / nodeCapacity.mem × 100

finalScore = (cpuScore × cpuWeight + memScore × memWeight) / (cpuWeight + memWeight)

# 示例计算
节点A: 8 core CPU, 16GB RAM
已分配: 2 core CPU, 4GB RAM
Pod请求: 1 core CPU, 2GB RAM

cpuScore = (8 - 2) / 8 × 100 = 75
memScore = (16 - 4) / 16 × 100 = 75
finalScore = (75 × 1 + 75 × 1) / 2 = 75
```

### 5.3 MostAllocated 详解

```
# MostAllocated 计算公式
cpuScore = nodeAllocated.cpu / nodeCapacity.cpu × 100
memScore = nodeAllocated.mem / nodeCapacity.mem × 100

finalScore = (cpuScore × cpuWeight + memScore × memWeight) / (cpuWeight + memWeight)

# 示例计算
节点A: 8 core CPU, 16GB RAM
已分配: 6 core CPU, 12GB RAM
Pod请求: 1 core CPU, 2GB RAM

cpuScore = 6 / 8 × 100 = 75
memScore = 12 / 16 × 100 = 75
finalScore = 75
```

### 5.4 Bin Packing 与 Spreading 对比

| 特性 | Bin Packing (装箱) | Spreading (分散) |
|------|---------------------|------------------|
| 目标 | 紧凑分配，减少节点数 | 分散分配，均衡负载 |
| 评分策略 | MostAllocated | LeastAllocated |
| 资源利用率 | 高 | 中等 |
| 容错性 | 较低 (故障影响大) | 较高 |
| 成本 | 较低 (可释放空闲节点) | 较高 |
| 适用场景 | 云环境成本优化 | 高可用要求场景 |

### 5.5 调度权重配置

```yaml
# 自定义插件权重配置
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
- schedulerName: default-scheduler
  plugins:
    score:
      enabled:
      - name: NodeResourcesFit
        weight: 1
      - name: NodeResourcesBalancedAllocation
        weight: 1
      - name: ImageLocality
        weight: 1
      - name: InterPodAffinity
        weight: 2
      - name: NodeAffinity
        weight: 2
      - name: PodTopologySpread
        weight: 2
      - name: TaintToleration
        weight: 3
```

| 权重场景 | 推荐配置 | 说明 |
|----------|----------|------|
| 资源均衡优先 | NodeResourcesFit: 3, Others: 1 | 优先考虑资源分配 |
| 亲和性优先 | InterPodAffinity: 3, NodeAffinity: 3 | 优先考虑数据本地性 |
| 高可用优先 | PodTopologySpread: 3 | 优先考虑分布均匀性 |
| 镜像优先 | ImageLocality: 3 | 优先考虑启动速度 |

---

## 6. 优先级与抢占机制

### 6.1 PriorityClass 配置

```yaml
# PriorityClass 定义示例
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000           # 优先级值 (越高越优先)
globalDefault: false     # 是否为默认优先级
preemptionPolicy: PreemptLowerPriority  # 抢占策略
description: "用于关键业务 Pod"

---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority
value: 100
globalDefault: false
preemptionPolicy: Never  # 禁止抢占
description: "用于可中断的批处理任务"
```

### 6.2 系统内置 PriorityClass

| PriorityClass 名称 | 优先级值 | 用途 |
|--------------------|----------|------|
| system-node-critical | 2000001000 | 节点关键组件 (如 kube-proxy) |
| system-cluster-critical | 2000000000 | 集群关键组件 (如 CoreDNS) |
| (用户自定义) | -2147483648 ~ 1000000000 | 用户工作负载 |

### 6.3 抢占流程详解

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Preemption Workflow                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  1. 高优先级 Pod 调度失败 (所有节点过滤失败)                                      │
│                │                                                                 │
│                ▼                                                                 │
│  2. PostFilter 阶段触发抢占逻辑                                                  │
│     ┌──────────────────────────────────────────────────────────────────────┐    │
│     │ DefaultPreemption.PostFilter() 被调用                                │    │
│     └──────────────────────────────────────────────────────────────────────┘    │
│                │                                                                 │
│                ▼                                                                 │
│  3. 选择抢占候选节点                                                             │
│     ┌──────────────────────────────────────────────────────────────────────┐    │
│     │ 对每个节点:                                                           │    │
│     │ a. 找出可被抢占的低优先级 Pod                                         │    │
│     │ b. 检查抢占后是否满足高优先级 Pod 需求                                 │    │
│     │ c. 计算抢占代价 (被驱逐 Pod 数量、优先级等)                            │    │
│     └──────────────────────────────────────────────────────────────────────┘    │
│                │                                                                 │
│                ▼                                                                 │
│  4. 选择最优抢占节点 (代价最小)                                                  │
│     ┌──────────────────────────────────────────────────────────────────────┐    │
│     │ 选择标准:                                                             │    │
│     │ - 被抢占 Pod 优先级之和最小                                           │    │
│     │ - 被抢占 Pod 数量最少                                                 │    │
│     │ - 优先选择已有 Terminating Pod 的节点                                 │    │
│     └──────────────────────────────────────────────────────────────────────┘    │
│                │                                                                 │
│                ▼                                                                 │
│  5. 执行抢占                                                                     │
│     ┌──────────────────────────────────────────────────────────────────────┐    │
│     │ a. 设置高优先级 Pod 的 nominatedNodeName                             │    │
│     │ b. 向 API Server 发送删除请求 (驱逐低优先级 Pod)                      │    │
│     │ c. Pod 进入 Terminating 状态                                          │    │
│     └──────────────────────────────────────────────────────────────────────┘    │
│                │                                                                 │
│                ▼                                                                 │
│  6. 等待驱逐完成, 高优先级 Pod 重新调度                                          │
│     ┌──────────────────────────────────────────────────────────────────────┐    │
│     │ 高优先级 Pod 重新进入调度队列                                         │    │
│     │ nominatedNodeName 作为调度提示 (非强制)                               │    │
│     └──────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 6.4 抢占策略配置

| 策略 | 描述 | 配置值 |
|------|------|--------|
| PreemptLowerPriority | 可以抢占低优先级 Pod | 默认值 |
| Never | 不进行抢占 | 用于可中断任务 |

```yaml
# 禁用抢占的 PriorityClass
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: batch-priority
value: 500
preemptionPolicy: Never  # 此优先级的 Pod 不会抢占其他 Pod
description: "批处理任务优先级"
```

### 6.5 Pod Disruption Budget (PDB) 与抢占

```yaml
# PDB 配置示例
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
spec:
  minAvailable: 2        # 最少可用 Pod 数
  # maxUnavailable: 1    # 或: 最大不可用数
  selector:
    matchLabels:
      app: web
```

| PDB 与抢占的交互 | 行为 |
|------------------|------|
| 抢占受 PDB 保护的 Pod | 仅在满足 PDB 条件时允许 |
| 所有候选 Pod 都受 PDB 保护 | 抢占失败，Pod 保持 Pending |
| 部分候选 Pod 受 PDB 保护 | 优先抢占不受保护的 Pod |

---

## 7. 高级调度特性

### 7.1 多调度器部署

```yaml
# 自定义调度器部署
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-scheduler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      component: custom-scheduler
  template:
    metadata:
      labels:
        component: custom-scheduler
    spec:
      serviceAccountName: custom-scheduler
      containers:
      - name: scheduler
        image: registry.k8s.io/kube-scheduler:v1.31.0
        command:
        - kube-scheduler
        - --config=/etc/kubernetes/scheduler-config.yaml
        - --leader-elect=true
        - --leader-elect-resource-name=custom-scheduler
        volumeMounts:
        - name: config
          mountPath: /etc/kubernetes/
      volumes:
      - name: config
        configMap:
          name: custom-scheduler-config

---
# 使用自定义调度器的 Pod
apiVersion: v1
kind: Pod
metadata:
  name: custom-scheduled-pod
spec:
  schedulerName: custom-scheduler  # 指定调度器名称
  containers:
  - name: app
    image: nginx
```

### 7.2 调度器配置文件 (多 Profile)

```yaml
# 多 Profile 调度器配置
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
leaderElection:
  leaderElect: true
  resourceName: kube-scheduler
clientConnection:
  kubeconfig: /etc/kubernetes/scheduler.kubeconfig
profiles:
# Profile 1: 默认调度器
- schedulerName: default-scheduler
  plugins:
    score:
      enabled:
      - name: NodeResourcesFit
        weight: 1
      - name: NodeResourcesBalancedAllocation
        weight: 1
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: LeastAllocated

# Profile 2: 高密度调度器 (Bin Packing)
- schedulerName: bin-packing-scheduler
  plugins:
    score:
      enabled:
      - name: NodeResourcesFit
        weight: 1
      disabled:
      - name: NodeResourcesBalancedAllocation
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: MostAllocated

# Profile 3: GPU 专用调度器
- schedulerName: gpu-scheduler
  plugins:
    score:
      enabled:
      - name: NodeResourcesFit
        weight: 2
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: LeastAllocated
        resources:
        - name: nvidia.com/gpu
          weight: 10
        - name: cpu
          weight: 1
        - name: memory
          weight: 1
```

### 7.3 扩展调度器 (Scheduler Extender)

```yaml
# Scheduler Extender 配置 (已废弃，推荐使用 Framework Plugin)
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
extenders:
- urlPrefix: "http://localhost:8888/"
  filterVerb: "filter"
  preemptVerb: "preempt"
  prioritizeVerb: "prioritize"
  bindVerb: "bind"
  weight: 1
  enableHTTPS: false
  httpTimeout: 30s
  nodeCacheCapable: false
  managedResources:
  - name: "example.com/custom-resource"
    ignoredByScheduler: true
  ignorable: true
```

### 7.4 Gang Scheduling (Volcano)

```yaml
# Volcano PodGroup 示例
apiVersion: scheduling.volcano.sh/v1beta1
kind: PodGroup
metadata:
  name: spark-job-pg
spec:
  minMember: 3           # 最小成员数 (必须同时调度)
  minResources:
    cpu: "4"
    memory: "8Gi"
  queue: default
  priorityClassName: high-priority

---
apiVersion: v1
kind: Pod
metadata:
  name: spark-driver
  annotations:
    scheduling.k8s.io/group-name: spark-job-pg
spec:
  schedulerName: volcano
  containers:
  - name: driver
    image: spark:3.5
    resources:
      requests:
        cpu: "2"
        memory: "4Gi"
```

| Gang Scheduling 特性 | 描述 |
|---------------------|------|
| All-or-Nothing | 要么全部调度，要么全不调度 |
| Min Member | 最小成员数要求 |
| Queue | 支持多队列和资源配额 |
| 典型场景 | Spark/Flink 作业、分布式训练 |

### 7.5 Koordinator 协调调度

```yaml
# Koordinator Reservation 示例
apiVersion: scheduling.koordinator.sh/v1alpha1
kind: Reservation
metadata:
  name: gpu-reservation
spec:
  template:
    spec:
      containers:
      - name: placeholder
        resources:
          requests:
            nvidia.com/gpu: "2"
            cpu: "4"
            memory: "16Gi"
  owners:
  - labelSelector:
      matchLabels:
        app: ml-training
  ttl: 1h
  expires: "2024-12-31T23:59:59Z"
```

| Koordinator 特性 | 描述 |
|-----------------|------|
| Reservation | 资源预留 |
| Gang Scheduling | 组调度 |
| Elastic Quota | 弹性配额 |
| Device Scheduling | 设备调度 (GPU/RDMA) |
| QoS 管理 | 服务质量保障 |

### 7.6 Descheduler 重调度

```yaml
# Descheduler 配置示例
apiVersion: descheduler/v1alpha2
kind: DeschedulerPolicy
profiles:
- name: default
  pluginConfig:
  - name: RemoveDuplicates
    args:
      excludeOwnerKinds:
      - DaemonSet
  - name: LowNodeUtilization
    args:
      thresholds:
        cpu: 20
        memory: 20
        pods: 20
      targetThresholds:
        cpu: 50
        memory: 50
        pods: 50
  - name: RemovePodsHavingTooManyRestarts
    args:
      podRestartThreshold: 100
      includingInitContainers: true
  plugins:
    balance:
      enabled:
      - RemoveDuplicates
      - LowNodeUtilization
    deschedule:
      enabled:
      - RemovePodsHavingTooManyRestarts
```

| Descheduler 策略 | 功能 |
|------------------|------|
| RemoveDuplicates | 移除同节点重复 Pod |
| LowNodeUtilization | 从高负载节点驱逐 Pod |
| RemovePodsHavingTooManyRestarts | 移除重启过多的 Pod |
| RemovePodsViolatingTopologySpreadConstraint | 修复拓扑分布违规 |
| RemovePodsViolatingNodeAffinity | 修复节点亲和性违规 |
| RemovePodsViolatingInterPodAntiAffinity | 修复 Pod 反亲和违规 |
| PodLifeTime | 移除长时间运行的 Pod |

---

## 8. 调度器配置

### 8.1 完整配置文件示例

```yaml
# /etc/kubernetes/scheduler-config.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
parallelism: 16
leaderElection:
  leaderElect: true
  leaseDuration: 15s
  renewDeadline: 10s
  retryPeriod: 2s
  resourceLock: leases
  resourceName: kube-scheduler
  resourceNamespace: kube-system
clientConnection:
  kubeconfig: /etc/kubernetes/scheduler.kubeconfig
  acceptContentTypes: ""
  contentType: application/vnd.kubernetes.protobuf
  qps: 100
  burst: 200
percentageOfNodesToScore: 0  # 0 表示自动计算
podInitialBackoffSeconds: 1
podMaxBackoffSeconds: 10
profiles:
- schedulerName: default-scheduler
  percentageOfNodesToScore: 50
  plugins:
    queueSort:
      enabled:
      - name: PrioritySort
    preFilter:
      enabled:
      - name: NodeResourcesFit
      - name: NodePorts
      - name: VolumeBinding
      - name: PodTopologySpread
      - name: InterPodAffinity
      - name: VolumeZone
    filter:
      enabled:
      - name: NodeUnschedulable
      - name: NodeName
      - name: TaintToleration
      - name: NodeAffinity
      - name: NodePorts
      - name: NodeResourcesFit
      - name: VolumeBinding
      - name: VolumeZone
      - name: PodTopologySpread
      - name: InterPodAffinity
    postFilter:
      enabled:
      - name: DefaultPreemption
    preScore:
      enabled:
      - name: InterPodAffinity
      - name: PodTopologySpread
      - name: TaintToleration
    score:
      enabled:
      - name: NodeResourcesBalancedAllocation
        weight: 1
      - name: ImageLocality
        weight: 1
      - name: InterPodAffinity
        weight: 1
      - name: NodeResourcesFit
        weight: 1
      - name: NodeAffinity
        weight: 1
      - name: PodTopologySpread
        weight: 2
      - name: TaintToleration
        weight: 1
    reserve:
      enabled:
      - name: VolumeBinding
    permit: {}
    preBind:
      enabled:
      - name: VolumeBinding
    bind:
      enabled:
      - name: DefaultBinder
    postBind: {}
  pluginConfig:
  - name: DefaultPreemption
    args:
      minCandidateNodesPercentage: 10
      minCandidateNodesAbsolute: 100
  - name: InterPodAffinity
    args:
      hardPodAffinityWeight: 1
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: LeastAllocated
        resources:
        - name: cpu
          weight: 1
        - name: memory
          weight: 1
  - name: PodTopologySpread
    args:
      defaultingType: System
      defaultConstraints:
      - maxSkew: 3
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
      - maxSkew: 5
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
  - name: VolumeBinding
    args:
      bindTimeoutSeconds: 600
```

### 8.2 配置参数详解

| 参数 | 默认值 | 描述 |
|------|--------|------|
| parallelism | 16 | 调度并行度 |
| percentageOfNodesToScore | 0 (自动) | 评分节点百分比 |
| podInitialBackoffSeconds | 1 | 初始退避时间 |
| podMaxBackoffSeconds | 10 | 最大退避时间 |
| leaderElection.leaseDuration | 15s | 租约持续时间 |
| leaderElection.renewDeadline | 10s | 租约续期截止时间 |
| leaderElection.retryPeriod | 2s | 重试周期 |
| clientConnection.qps | 50 | API 请求 QPS |
| clientConnection.burst | 100 | API 请求突发数 |

### 8.3 percentageOfNodesToScore 自动计算

```go
// 自动计算逻辑 (简化版)
func calculatePercentageOfNodesToScore(numAllNodes int32) int32 {
    if numAllNodes < 50 {
        return 100  // 小于 50 节点，评分所有节点
    }
    if numAllNodes < 100 {
        return 50
    }
    // 节点越多，百分比越低
    percentage := 50 - (numAllNodes - 100) / 125
    if percentage < 5 {
        return 5  // 最低 5%
    }
    return percentage
}
```

| 集群规模 | 自动计算的百分比 | 评分节点数 |
|----------|------------------|------------|
| 50 节点 | 100% | 50 |
| 100 节点 | 50% | 50 |
| 500 节点 | ~18% | ~90 |
| 1000 节点 | ~14% | ~140 |
| 5000 节点 | 5% | 250 |

### 8.4 命令行参数

| 参数 | 描述 | 默认值 |
|------|------|--------|
| --config | 配置文件路径 | 无 |
| --leader-elect | 启用 Leader 选举 | true |
| --leader-elect-resource-name | Leader 选举资源名 | kube-scheduler |
| --leader-elect-resource-namespace | Leader 选举命名空间 | kube-system |
| --kube-api-qps | API 请求 QPS | 50 |
| --kube-api-burst | API 请求突发数 | 100 |
| --profiling | 启用性能分析 | true |
| --contention-profiling | 启用竞争分析 | false |
| --v | 日志级别 | 0 |

---

## 9. 监控与可观测性

### 9.1 核心监控指标

| 指标名称 | 类型 | 描述 | 重要性 |
|----------|------|------|--------|
| scheduler_scheduling_attempt_duration_seconds | Histogram | 调度尝试耗时 | 高 |
| scheduler_e2e_scheduling_duration_seconds | Histogram | 端到端调度延迟 | 高 |
| scheduler_pending_pods | Gauge | 待调度 Pod 数量 | 高 |
| scheduler_queue_incoming_pods_total | Counter | 入队 Pod 总数 | 中 |
| scheduler_framework_extension_point_duration_seconds | Histogram | 扩展点执行耗时 | 中 |
| scheduler_schedule_attempts_total | Counter | 调度尝试总数 | 高 |
| scheduler_pod_scheduling_duration_seconds | Histogram | Pod 调度耗时 | 高 |
| scheduler_preemption_attempts_total | Counter | 抢占尝试总数 | 中 |
| scheduler_preemption_victims | Gauge | 抢占受害者数量 | 中 |

### 9.2 指标查询示例 (PromQL)

```promql
# 调度成功率
sum(rate(scheduler_schedule_attempts_total{result="scheduled"}[5m])) /
sum(rate(scheduler_schedule_attempts_total[5m]))

# P99 调度延迟
histogram_quantile(0.99, 
  sum(rate(scheduler_e2e_scheduling_duration_seconds_bucket[5m])) by (le)
)

# 待调度 Pod 数量
scheduler_pending_pods{queue="active"}

# 各扩展点执行耗时
histogram_quantile(0.99,
  sum(rate(scheduler_framework_extension_point_duration_seconds_bucket[5m])) 
  by (le, extension_point)
)

# 抢占发生率
rate(scheduler_preemption_attempts_total[5m])

# Filter 插件过滤节点分布
scheduler_plugin_evaluation_total{operation="filter"}
```

### 9.3 告警规则配置

```yaml
# Prometheus 告警规则
groups:
- name: scheduler-alerts
  rules:
  - alert: SchedulerPendingPodsHigh
    expr: scheduler_pending_pods{queue="active"} > 100
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "调度器待调度 Pod 数量过高"
      description: "活跃队列中有 {{ $value }} 个 Pod 等待调度"

  - alert: SchedulerSchedulingLatencyHigh
    expr: |
      histogram_quantile(0.99, 
        sum(rate(scheduler_e2e_scheduling_duration_seconds_bucket[5m])) by (le)
      ) > 1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "调度延迟过高"
      description: "P99 调度延迟为 {{ $value }}s"

  - alert: SchedulerSchedulingFailuresHigh
    expr: |
      sum(rate(scheduler_schedule_attempts_total{result="error"}[5m])) /
      sum(rate(scheduler_schedule_attempts_total[5m])) > 0.1
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "调度失败率过高"
      description: "调度失败率为 {{ $value | humanizePercentage }}"

  - alert: SchedulerUnschedulablePodsHigh
    expr: scheduler_pending_pods{queue="unschedulable"} > 50
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "不可调度 Pod 数量过高"
      description: "有 {{ $value }} 个 Pod 无法调度"

  - alert: SchedulerPreemptionRateHigh
    expr: rate(scheduler_preemption_attempts_total[5m]) > 1
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "抢占发生率过高"
      description: "抢占尝试频率为 {{ $value }}/s"
```

### 9.4 Grafana Dashboard 面板

| 面板名称 | 展示内容 | 数据源 |
|----------|----------|--------|
| Scheduling Rate | 每秒调度 Pod 数 | scheduler_schedule_attempts_total |
| Scheduling Latency | P50/P90/P99 调度延迟 | scheduler_e2e_scheduling_duration_seconds |
| Pending Pods | 各队列待调度 Pod 数 | scheduler_pending_pods |
| Plugin Execution Time | 各插件执行耗时 | scheduler_framework_extension_point_duration_seconds |
| Preemption Stats | 抢占统计 | scheduler_preemption_* |
| Success/Failure Rate | 调度成功/失败率 | scheduler_schedule_attempts_total |

### 9.5 日志分析

```bash
# 查看调度器日志
kubectl logs -n kube-system -l component=kube-scheduler --tail=1000

# 过滤特定 Pod 的调度日志
kubectl logs -n kube-system -l component=kube-scheduler | grep "pod-name"

# 查看调度失败原因
kubectl logs -n kube-system -l component=kube-scheduler | grep "Unable to schedule"

# 启用详细日志 (调整日志级别)
# 在调度器启动参数中添加 --v=4 或更高
```

| 日志级别 | 内容 |
|----------|------|
| v=0 | 基本信息 |
| v=2 | 调度决策结果 |
| v=4 | 调度过程详情 |
| v=5 | 插件执行详情 |
| v=6+ | Debug 级别 |

---

## 10. 故障排查与调优

### 10.1 常见调度问题

| 问题 | 可能原因 | 排查方法 | 解决方案 |
|------|----------|----------|----------|
| Pod 一直 Pending | 资源不足 | `kubectl describe pod` | 扩容节点或调整 requests |
| Pod 一直 Pending | 节点亲和性不匹配 | 检查 nodeAffinity | 调整亲和性规则或添加节点标签 |
| Pod 一直 Pending | 污点无法容忍 | 检查 taints/tolerations | 添加 tolerations |
| Pod 一直 Pending | PVC 绑定失败 | 检查 PVC/PV 状态 | 创建匹配的 PV 或修复 StorageClass |
| 调度延迟高 | 集群规模大 | 检查 percentageOfNodesToScore | 调整评分节点百分比 |
| 调度延迟高 | 插件执行慢 | 检查插件指标 | 优化或禁用耗时插件 |
| 调度不均衡 | 评分策略问题 | 检查节点资源分布 | 调整评分权重 |
| 抢占频繁 | 优先级配置问题 | 检查 PriorityClass | 调整优先级值 |

### 10.2 Pod Pending 问题排查

```bash
# 1. 查看 Pod 事件
kubectl describe pod <pod-name> -n <namespace>

# 2. 查看 Pod 调度状态
kubectl get pod <pod-name> -o jsonpath='{.status.conditions[?(@.type=="PodScheduled")]}'

# 3. 检查节点资源
kubectl describe nodes | grep -A 5 "Allocated resources"

# 4. 检查节点污点
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# 5. 检查 PVC 状态
kubectl get pvc -n <namespace>

# 6. 模拟调度 (Dry Run)
kubectl create -f pod.yaml --dry-run=server -o yaml
```

### 10.3 调度事件分析

```bash
# 查看调度相关事件
kubectl get events --field-selector reason=FailedScheduling
kubectl get events --field-selector reason=Scheduled

# 常见失败事件示例
Events:
  Type     Reason            Message
  ----     ------            -------
  Warning  FailedScheduling  0/10 nodes are available: 3 node(s) had taints, 
                             7 Insufficient cpu.
  Warning  FailedScheduling  0/10 nodes are available: 10 node(s) didn't match 
                             Pod's node affinity/selector.
  Warning  FailedScheduling  0/10 nodes are available: 10 node(s) didn't have 
                             free ports for the requested pod ports.
  Warning  FailedScheduling  0/10 nodes are available: 10 Insufficient 
                             nvidia.com/gpu.
```

### 10.4 性能调优建议

| 调优项 | 建议配置 | 适用场景 |
|--------|----------|----------|
| parallelism | 16-32 | 大规模集群 |
| percentageOfNodesToScore | 10-30% | 超大规模集群 (>1000节点) |
| podInitialBackoffSeconds | 1 | 默认即可 |
| podMaxBackoffSeconds | 10-30 | 资源紧张场景可增加 |
| QPS/Burst | 100/200 | 大规模集群 |
| 禁用不需要的插件 | - | 减少调度延迟 |

### 10.5 调度器高可用配置

```yaml
# 高可用调度器部署
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-scheduler
  namespace: kube-system
spec:
  replicas: 2  # 多副本部署
  selector:
    matchLabels:
      component: kube-scheduler
  template:
    spec:
      priorityClassName: system-cluster-critical
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                component: kube-scheduler
            topologyKey: kubernetes.io/hostname
      containers:
      - name: kube-scheduler
        image: registry.k8s.io/kube-scheduler:v1.31.0
        command:
        - kube-scheduler
        - --config=/etc/kubernetes/scheduler-config.yaml
        - --leader-elect=true  # 启用 Leader 选举
        livenessProbe:
          httpGet:
            path: /healthz
            port: 10259
            scheme: HTTPS
          initialDelaySeconds: 15
        readinessProbe:
          httpGet:
            path: /healthz
            port: 10259
            scheme: HTTPS
```

### 10.6 调度器健康检查端点

| 端点 | 路径 | 端口 | 用途 |
|------|------|------|------|
| healthz | /healthz | 10259 (HTTPS) | 健康检查 |
| livez | /livez | 10259 (HTTPS) | 存活检查 |
| readyz | /readyz | 10259 (HTTPS) | 就绪检查 |
| metrics | /metrics | 10259 (HTTPS) | Prometheus 指标 |

---

## 11. 生产实践案例

### 11.1 案例一: 多租户资源隔离调度

```yaml
# 场景: 不同租户使用不同节点池
# 方案: 节点标签 + Pod 亲和性 + PriorityClass

# 1. 节点标签
# kubectl label nodes node-1 node-2 node-3 tenant=team-a
# kubectl label nodes node-4 node-5 node-6 tenant=team-b

# 2. PriorityClass
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: team-a-high
value: 1000
description: "Team A 高优先级"

---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: team-b-high
value: 1000
description: "Team B 高优先级"

---
# 3. Pod 配置
apiVersion: v1
kind: Pod
metadata:
  name: team-a-app
spec:
  priorityClassName: team-a-high
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: tenant
            operator: In
            values:
            - team-a
  tolerations:
  - key: "tenant"
    operator: "Equal"
    value: "team-a"
    effect: "NoSchedule"
  containers:
  - name: app
    image: nginx
```

### 11.2 案例二: GPU 工作负载调度优化

```yaml
# 场景: 优化 GPU 资源利用率
# 方案: 自定义调度器配置 + 资源评分优化

# 1. 调度器配置
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
profiles:
- schedulerName: gpu-scheduler
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: MostAllocated  # Bin Packing 策略
        resources:
        - name: nvidia.com/gpu
          weight: 10        # GPU 权重最高
        - name: cpu
          weight: 1
        - name: memory
          weight: 1

---
# 2. GPU Pod 示例
apiVersion: v1
kind: Pod
metadata:
  name: gpu-training
spec:
  schedulerName: gpu-scheduler
  containers:
  - name: training
    image: tensorflow/tensorflow:latest-gpu
    resources:
      requests:
        nvidia.com/gpu: 2
        cpu: "4"
        memory: "16Gi"
      limits:
        nvidia.com/gpu: 2
        cpu: "8"
        memory: "32Gi"
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: gpu-type
            operator: In
            values:
            - nvidia-a100
```

### 11.3 案例三: 跨可用区高可用部署

```yaml
# 场景: 确保应用跨可用区分布
# 方案: PodTopologySpread + PDB

# 1. Deployment 配置
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-frontend
spec:
  replicas: 6
  selector:
    matchLabels:
      app: web-frontend
  template:
    metadata:
      labels:
        app: web-frontend
    spec:
      topologySpreadConstraints:
      # 可用区级别均衡 (硬约束)
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: web-frontend
        minDomains: 3
      # 节点级别均衡 (软约束)
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: web-frontend
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: web-frontend
              topologyKey: kubernetes.io/hostname
      containers:
      - name: web
        image: nginx:1.25

---
# 2. PDB 配置
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-frontend-pdb
spec:
  minAvailable: 4  # 最少保持 4 个 Pod 可用
  selector:
    matchLabels:
      app: web-frontend
```

### 11.4 案例四: 批处理作业调度优化

```yaml
# 场景: 批处理作业与在线服务共存
# 方案: PriorityClass 分级 + 抢占策略

# 1. PriorityClass 定义
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: online-service
value: 10000
preemptionPolicy: PreemptLowerPriority
description: "在线服务 - 可抢占批处理任务"

---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: batch-job
value: 1000
preemptionPolicy: Never  # 不抢占其他 Pod
description: "批处理任务 - 可被抢占"

---
# 2. 在线服务 Pod
apiVersion: v1
kind: Pod
metadata:
  name: api-server
spec:
  priorityClassName: online-service
  containers:
  - name: api
    image: api-server:v1
    resources:
      requests:
        cpu: "2"
        memory: "4Gi"

---
# 3. 批处理任务 Pod
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processing
spec:
  template:
    spec:
      priorityClassName: batch-job
      restartPolicy: OnFailure
      tolerations:
      - key: "batch"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
      containers:
      - name: processor
        image: batch-processor:v1
        resources:
          requests:
            cpu: "4"
            memory: "8Gi"
```

### 11.5 案例五: 数据本地性调度 (Spark/Flink)

```yaml
# 场景: 大数据处理需要数据本地性
# 方案: Pod 亲和性 + 节点标签

# 1. 数据节点标签
# kubectl label nodes data-node-1 hdfs.node=datanode spark.locality=true
# kubectl label nodes data-node-2 hdfs.node=datanode spark.locality=true

# 2. Spark Executor Pod
apiVersion: v1
kind: Pod
metadata:
  name: spark-executor
  labels:
    spark-role: executor
    spark-app: data-pipeline
spec:
  affinity:
    # 优先调度到数据节点
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: spark.locality
            operator: In
            values:
            - "true"
    # 与 Driver 在同一可用区
    podAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 50
        podAffinityTerm:
          labelSelector:
            matchLabels:
              spark-role: driver
              spark-app: data-pipeline
          topologyKey: topology.kubernetes.io/zone
    # Executor 分散到不同节点
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 30
        podAffinityTerm:
          labelSelector:
            matchLabels:
              spark-role: executor
              spark-app: data-pipeline
          topologyKey: kubernetes.io/hostname
  containers:
  - name: executor
    image: spark:3.5
    resources:
      requests:
        cpu: "4"
        memory: "8Gi"
```

### 11.6 调度最佳实践总结

| 场景 | 推荐方案 | 关键配置 |
|------|----------|----------|
| 高可用部署 | PodTopologySpread + PDB | maxSkew: 1, DoNotSchedule |
| 资源隔离 | NodeAffinity + Taints | 节点标签 + 污点容忍 |
| 成本优化 | MostAllocated + Descheduler | Bin Packing 策略 |
| 混合负载 | PriorityClass 分级 | 在线服务高优先级 |
| 大规模集群 | percentageOfNodesToScore 调优 | 10-30% 评分节点 |
| GPU 调度 | 自定义权重 | GPU 资源权重提高 |
| 数据本地性 | PodAffinity | 与数据节点亲和 |
| 批处理作业 | preemptionPolicy: Never | 可被抢占，不抢占他人 |

---

## 附录

### A. 调度器版本变更

| Kubernetes 版本 | 调度器变更 |
|-----------------|------------|
| v1.18 | Scheduling Framework GA |
| v1.19 | PodTopologySpread 默认启用 |
| v1.20 | DefaultPodTopologySpread 插件 |
| v1.21 | Pod affinity NamespaceSelector |
| v1.22 | SuspendJob 支持 |
| v1.24 | minDomains for PodTopologySpread (beta) |
| v1.25 | matchLabelKeys for PodTopologySpread (beta) |
| v1.26 | NodeInclusionPolicyInPodTopologySpread (beta) |
| v1.27 | SchedulerQueueingHints (beta) |
| v1.29 | QueueingHint 优化 |
| v1.30 | SchedulingGates GA |
| v1.31 | PodTopologySpread 完善 |

### B. 常用 kubectl 命令

```bash
# 查看 Pod 调度结果
kubectl get pod -o wide

# 查看 Pod 调度事件
kubectl describe pod <pod-name> | grep -A 10 Events

# 查看节点资源使用
kubectl top nodes

# 查看节点标签
kubectl get nodes --show-labels

# 查看节点污点
kubectl describe node <node-name> | grep Taints

# 查看 PriorityClass
kubectl get priorityclass

# 查看调度器 Leader
kubectl get lease -n kube-system kube-scheduler

# 强制重新调度 Pod
kubectl delete pod <pod-name>
```

### C. 参考资源

| 资源 | 链接 |
|------|------|
| Scheduler 配置参考 | https://kubernetes.io/docs/reference/scheduling/config/ |
| Scheduling Framework | https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/ |
| Pod Priority and Preemption | https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/ |
| Pod Topology Spread | https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/ |
| Volcano 文档 | https://volcano.sh/docs/ |
| Koordinator 文档 | https://koordinator.sh/docs/ |
| Descheduler 文档 | https://github.com/kubernetes-sigs/descheduler |

---

*本文档持续更新，建议结合官方文档和实际集群环境进行验证。*
