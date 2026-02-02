# PodDisruptionBudget (PDB) 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 中级
>
> **版本说明**:
> - v1.26+ PDB 支持 unhealthyPodEvictionPolicy 字段
> - v1.27+ unhealthyPodEvictionPolicy GA
> - 设置 AlwaysAllow 可允许驱逐不健康 Pod，避免 drain 卡住

---

## 第一部分：问题现象与影响分析

### 1.1 PodDisruptionBudget 工作原理

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    PodDisruptionBudget 机制                              │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌────────────────────────────────────────────────────────────────┐    │
│   │                   PodDisruptionBudget                           │    │
│   │                                                                 │    │
│   │  spec:                                                          │    │
│   │    selector:                                                    │    │
│   │      matchLabels:                                               │    │
│   │        app: my-app      ◄─── 选择受保护的 Pod                   │    │
│   │    minAvailable: 2      ◄─── 或使用 maxUnavailable: 1          │    │
│   │                                                                 │    │
│   └────────────────────────────┬───────────────────────────────────┘    │
│                                │                                         │
│                         保护目标 Pod                                     │
│                                │                                         │
│   ┌────────────────────────────┴───────────────────────────────────┐    │
│   │                    目标 Pod (匹配 selector)                     │    │
│   │                                                                 │    │
│   │    ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐                │    │
│   │    │Pod 1│  │Pod 2│  │Pod 3│  │Pod 4│  │Pod 5│                │    │
│   │    │ ✓   │  │ ✓   │  │ ✓   │  │ ✓   │  │ ✓   │                │    │
│   │    └─────┘  └─────┘  └─────┘  └─────┘  └─────┘                │    │
│   │                                                                 │    │
│   │    Total: 5    minAvailable: 2    可中断: 3                    │    │
│   │                                                                 │    │
│   └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

PDB 保护场景:
┌──────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│   自愿中断 (Voluntary Disruptions) - PDB 保护                           │
│   ┌─────────────────┬─────────────────┬─────────────────┐               │
│   │  kubectl drain  │  节点维护       │  Cluster        │               │
│   │  (节点排空)     │  (升级/重启)    │  Autoscaler     │               │
│   │                 │                 │  (缩容)         │               │
│   └────────┬────────┴────────┬────────┴────────┬────────┘               │
│            │                 │                 │                         │
│            └─────────────────┼─────────────────┘                         │
│                              │                                           │
│                              ▼                                           │
│                     ┌────────────────┐                                  │
│                     │   Eviction     │                                  │
│                     │     API        │                                  │
│                     └───────┬────────┘                                  │
│                             │                                           │
│                             ▼                                           │
│                     ┌────────────────┐                                  │
│                     │  检查 PDB      │                                  │
│                     │  是否允许驱逐  │                                  │
│                     └───────┬────────┘                                  │
│                             │                                           │
│            ┌────────────────┼────────────────┐                          │
│            │                │                │                          │
│            ▼                ▼                ▼                          │
│       允许驱逐         等待重试         拒绝驱逐                        │
│    (disruptionsAllowed   (可能后续       (当前不满足                    │
│         > 0)             可以驱逐)        minAvailable)                 │
│                                                                          │
│   非自愿中断 (Involuntary) - PDB 不保护                                 │
│   ┌─────────────────┬─────────────────┬─────────────────┐               │
│   │  节点故障       │  OOM Kill       │  容器崩溃       │               │
│   │  (硬件/内核)    │  (资源不足)     │  (应用错误)     │               │
│   └─────────────────┴─────────────────┴─────────────────┘               │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

PDB 状态计算:
┌────────────────────────────────────────────────────────────────────────┐
│                                                                        │
│  Total Pods (匹配 selector): 5                                         │
│                                                                        │
│  健康 Pod 数 (Ready): 5                                                │
│                                                                        │
│  期望最小可用 (minAvailable): 2                                        │
│                 或                                                      │
│  最大不可用 (maxUnavailable): 1                                        │
│                                                                        │
│  ────────────────────────────────────────────                          │
│                                                                        │
│  disruptionsAllowed = currentHealthy - minAvailable                    │
│                     = 5 - 2 = 3                                        │
│                                                                        │
│  或者使用 maxUnavailable:                                               │
│  disruptionsAllowed = maxUnavailable - (total - currentHealthy)        │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 错误信息 | 查看方式 |
|----------|----------|----------|----------|
| drain 卡住 | kubectl drain 无法完成 | Cannot evict pod | kubectl drain 输出 |
| 缩容失败 | Cluster Autoscaler 无法删节点 | pod has pdb | CA 日志 |
| 滚动更新慢 | Deployment 更新等待时间长 | 无 | kubectl rollout status |
| PDB 无效 | selector 不匹配任何 Pod | 无 | kubectl describe pdb |
| 过度保护 | 合法操作被阻止 | disruptions blocked | kubectl drain 输出 |
| 保护不足 | 中断时服务不可用 | 无 | 监控/告警 |
| 状态不更新 | disruptionsAllowed 不正确 | 无 | kubectl get pdb |
| 冲突配置 | 多个 PDB 匹配同一 Pod | multiple PDBs | kubectl describe |

### 1.3 影响分析

| 问题类型 | 直接影响 | 间接影响 | 影响范围 |
|----------|----------|----------|----------|
| drain 阻塞 | 节点无法维护 | 升级流程停滞 | 集群运维 |
| 缩容阻塞 | 资源无法释放 | 成本增加 | 集群成本 |
| 保护不足 | 服务中断 | 用户影响 | 业务可用性 |
| 配置错误 | PDB 无效 | 失去保护 | 特定应用 |

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
PDB 问题
    │
    ▼
┌───────────────────────┐
│  问题类型是什么？      │
└───────────────────────┘
    │
    ├── drain/驱逐被阻止 ────────────────────────────────────┐
    │                                                         │
    │   ┌─────────────────────────────────────────┐          │
    │   │ 检查 PDB 状态                           │          │
    │   │ kubectl get pdb -A                      │          │
    │   └─────────────────────────────────────────┘          │
    │                  │                                      │
    │                  ▼                                      │
    │   ┌─────────────────────────────────────────┐          │
    │   │ disruptionsAllowed = 0?                 │          │
    │   └─────────────────────────────────────────┘          │
    │          │                │                             │
    │         是               否                             │
    │          │                │                             │
    │          ▼                ▼                             │
    │   ┌────────────┐   ┌────────────────┐                  │
    │   │ 检查 Pod   │   │ 检查其他阻止   │                  │
    │   │ 健康状态   │   │ 驱逐的原因     │                  │
    │   └────────────┘   └────────────────┘                  │
    │                                                         │
    ├── PDB 似乎无效 ────────────────────────────────────────┤
    │                                                         │
    │   ┌─────────────────────────────────────────┐          │
    │   │ 检查 selector 是否匹配 Pod              │          │
    │   │ kubectl describe pdb <name>             │          │
    │   └─────────────────────────────────────────┘          │
    │                  │                                      │
    │                  ▼                                      │
    │   ┌─────────────────────────────────────────┐          │
    │   │ currentHealthy/expectedPods > 0?        │          │
    │   └─────────────────────────────────────────┘          │
    │          │                │                             │
    │         否               是                             │
    │          │                │                             │
    │          ▼                ▼                             │
    │   ┌────────────┐   ┌────────────────┐                  │
    │   │ selector   │   │ 检查 minAvail/ │                  │
    │   │ 不匹配     │   │ maxUnavail 配置│                  │
    │   └────────────┘   └────────────────┘                  │
    │                                                         │
    └── 滚动更新问题 ────────────────────────────────────────┤
                                                              │
        ┌─────────────────────────────────────────┐          │
        │ 检查 Deployment 和 PDB 配置             │          │
        │ 是否兼容                                │          │
        └─────────────────────────────────────────┘          │
                   │                                          │
                   ▼                                          │
        ┌─────────────────────────────────────────┐          │
        │ maxSurge + maxUnavailable 是否                     │
        │ 与 PDB 兼容?                            │          │
        └─────────────────────────────────────────┘          │
                                                              │
                                                              ▼
                                                       ┌────────────┐
                                                       │ 问题定位   │
                                                       │ 完成       │
                                                       └────────────┘
```

### 2.2 排查命令集

#### PDB 状态检查

```bash
# 列出所有 PDB
kubectl get pdb -A

# 查看 PDB 详细状态
kubectl describe pdb <name> -n <namespace>

# 查看 PDB YAML
kubectl get pdb <name> -n <namespace> -o yaml

# 查看 PDB 状态字段
kubectl get pdb <name> -n <namespace> -o jsonpath='{.status}'

# 检查关键状态
kubectl get pdb -A -o custom-columns=\
NAME:.metadata.name,\
NAMESPACE:.metadata.namespace,\
MIN-AVAILABLE:.spec.minAvailable,\
MAX-UNAVAILABLE:.spec.maxUnavailable,\
ALLOWED-DISRUPTIONS:.status.disruptionsAllowed,\
CURRENT-HEALTHY:.status.currentHealthy,\
DESIRED-HEALTHY:.status.desiredHealthy,\
EXPECTED-PODS:.status.expectedPods
```

#### Pod 匹配检查

```bash
# 检查 PDB 匹配的 Pod
kubectl get pods -n <namespace> -l <selector-from-pdb>

# 检查 Pod 标签
kubectl get pods -n <namespace> --show-labels

# 检查 Pod 健康状态
kubectl get pods -n <namespace> -o wide

# 查看不健康的 Pod
kubectl get pods -n <namespace> | grep -v "Running\|Completed"
```

#### 驱逐检查

```bash
# 模拟驱逐 (dry-run)
kubectl drain <node> --dry-run=client --ignore-daemonsets --delete-emptydir-data

# 查看驱逐事件
kubectl get events -A --field-selector reason=Evicted

# 检查节点上的 Pod
kubectl get pods -A --field-selector spec.nodeName=<node>

# 强制驱逐 (忽略 PDB，危险)
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --disable-eviction
```

### 2.3 排查注意事项

| 注意事项 | 说明 | 风险等级 |
|----------|------|----------|
| --disable-eviction 会绕过 PDB | 可能导致服务中断 | 高 |
| minAvailable 不能大于副本数 | 会导致永远无法驱逐 | 高 |
| 100% minAvailable 很危险 | 任何 Pod 都无法被驱逐 | 高 |
| 多个 PDB 匹配同一 Pod | 所有 PDB 都必须满足 | 中 |
| PDB 不保护非自愿中断 | OOM/节点故障不受保护 | - |

## 第三部分：解决方案与风险控制

### 3.1 kubectl drain 卡住

**问题现象**：`kubectl drain` 一直等待，无法完成。

**解决步骤**：

```bash
# 步骤 1: 确认阻止驱逐的 Pod
kubectl drain <node> --dry-run=client --ignore-daemonsets --delete-emptydir-data 2>&1

# 步骤 2: 检查相关 PDB
kubectl get pdb -A
kubectl get pdb -A -o wide

# 步骤 3: 找出 disruptionsAllowed = 0 的 PDB
kubectl get pdb -A -o json | jq '.items[] | select(.status.disruptionsAllowed == 0) | {name: .metadata.name, namespace: .metadata.namespace}'

# 步骤 4: 检查为什么不允许中断
kubectl describe pdb <pdb-name> -n <namespace>
# 检查:
# - expectedPods vs currentHealthy
# - minAvailable 设置

# 步骤 5: 检查不健康的 Pod
kubectl get pods -n <namespace> -l <selector> | grep -v Running

# 步骤 6: 修复不健康的 Pod 后，PDB 应该允许驱逐
```

**常见原因与解决**：

```bash
# 原因 1: Pod 不健康导致 currentHealthy < minAvailable
# 解决: 修复不健康的 Pod
kubectl get pods -n <namespace> -o wide
kubectl describe pod <unhealthy-pod>
kubectl logs <unhealthy-pod>

# 原因 2: minAvailable 设置过高
# 例如: 3 个副本，minAvailable: 3 = 无法驱逐任何 Pod
# 解决: 调整 minAvailable 或增加副本数

# 原因 3: 只有 1 个副本且 minAvailable: 1
# 解决: 增加副本数到至少 2，或使用 maxUnavailable: 1
```

### 3.2 PDB selector 不匹配

**问题现象**：PDB 创建但未保护任何 Pod，expectedPods = 0。

**解决步骤**：

```bash
# 步骤 1: 检查 PDB 的 selector
kubectl get pdb <name> -n <namespace> -o yaml | grep -A10 selector

# 步骤 2: 检查 Pod 的标签
kubectl get pods -n <namespace> --show-labels

# 步骤 3: 验证 selector 是否匹配
kubectl get pods -n <namespace> -l <selector-from-pdb>

# 步骤 4: 修正 PDB selector 或 Pod 标签
```

**正确配置示例**：

```yaml
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app      # ← Pod 标签
  template:
    metadata:
      labels:
        app: my-app    # ← Pod 标签 (必须与 selector 匹配)
    spec:
      containers:
      - name: app
        image: nginx

---
# PDB
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: my-app      # ← 必须与 Pod 标签匹配
```

### 3.3 滚动更新受 PDB 阻塞

**问题现象**：Deployment 滚动更新非常慢或卡住。

**解决步骤**：

```bash
# 步骤 1: 检查 Deployment 状态
kubectl rollout status deployment <name> -n <namespace>

# 步骤 2: 检查 PDB 状态
kubectl get pdb -n <namespace>

# 步骤 3: 分析配置兼容性
# 关键: Deployment 的 maxUnavailable + PDB 的 minAvailable
```

**配置兼容性分析**：

```yaml
# 场景: 3 副本 Deployment

# ❌ 不兼容配置 (会导致滚动更新卡住)
# Deployment:
#   replicas: 3
#   maxSurge: 0
#   maxUnavailable: 1
# PDB:
#   minAvailable: 3
#
# 分析: 需要至少 3 个 Pod，但 maxUnavailable=1 要终止 1 个
#       PDB 不允许任何中断，滚动更新无法进行

# ✓ 兼容配置
# 方案 1: 使用 maxSurge
# Deployment:
spec:
  replicas: 3
  strategy:
    rollingUpdate:
      maxSurge: 1        # 允许临时多 1 个 Pod
      maxUnavailable: 0  # 不允许少于期望值
# PDB:
spec:
  minAvailable: 3
# 分析: 先创建新 Pod (4个)，再删除旧 Pod，始终 >= 3

# 方案 2: 调整 minAvailable
# PDB:
spec:
  minAvailable: 2        # 允许 1 个不可用
# 或
spec:
  maxUnavailable: 1      # 等效于 minAvailable: 2 (当 3 副本时)
```

### 3.4 过度保护导致运维困难

**问题现象**：合法的运维操作（升级、维护）被 PDB 阻止。

**解决步骤**：

```bash
# 步骤 1: 评估当前 PDB 配置是否合理
kubectl get pdb -A -o wide

# 步骤 2: 对于紧急维护，临时调整 PDB
kubectl patch pdb <name> -n <namespace> --type='json' \
  -p='[{"op": "replace", "path": "/spec/minAvailable", "value": 1}]'

# 步骤 3: 维护完成后恢复
kubectl patch pdb <name> -n <namespace> --type='json' \
  -p='[{"op": "replace", "path": "/spec/minAvailable", "value": 2}]'

# 步骤 4: 或者删除 PDB (更危险)
kubectl delete pdb <name> -n <namespace>
# 维护后重新创建
```

**最佳实践配置**：

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  # 推荐: 使用百分比而非绝对值
  maxUnavailable: 25%  # 允许最多 25% 不可用
  
  # 或者
  minAvailable: 75%    # 保持至少 75% 可用
  
  selector:
    matchLabels:
      app: my-app
```

### 3.5 多个 PDB 匹配同一 Pod

**问题现象**：Pod 被多个 PDB 匹配，驱逐行为不符合预期。

**解决步骤**：

```bash
# 步骤 1: 找出匹配同一 Pod 的所有 PDB
kubectl get pdb -A -o json | jq '.items[] | {name: .metadata.name, namespace: .metadata.namespace, selector: .spec.selector}'

# 步骤 2: 检查 Pod 的标签
kubectl get pod <pod-name> -n <namespace> --show-labels

# 步骤 3: 确认哪些 PDB 匹配此 Pod
# 多个 PDB 匹配时，所有 PDB 都必须允许驱逐

# 步骤 4: 调整 selector 避免重叠
# 使用更具体的标签
```

**避免重叠的配置**：

```yaml
# 使用更具体的标签区分不同组件
# Component A
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: component-a-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: my-app
      component: api  # 更具体的标签

---
# Component B
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: component-b-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: my-app
      component: worker  # 不同的组件标签
```

### 3.6 紧急情况绕过 PDB

**问题现象**：紧急需要排空节点但 PDB 阻止。

**解决步骤**：

```bash
# 方法 1: 强制驱逐 (绕过 PDB，高风险)
kubectl drain <node> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --disable-eviction  # 绕过 Eviction API，直接删除 Pod

# 方法 2: 临时删除 PDB
kubectl delete pdb <name> -n <namespace>
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
# 维护后重新创建 PDB

# 方法 3: 临时调整 PDB
kubectl patch pdb <name> -n <namespace> --type='json' \
  -p='[{"op": "replace", "path": "/spec/minAvailable", "value": 0}]'
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
# 恢复 PDB
kubectl patch pdb <name> -n <namespace> --type='json' \
  -p='[{"op": "replace", "path": "/spec/minAvailable", "value": 2}]'

# 方法 4: 直接删除 Pod (不通过驱逐)
kubectl delete pod <pod-name> -n <namespace>
# 注意: 这不会触发 PDB 检查，但也不会优雅终止
```

### 3.7 PDB 与 Cluster Autoscaler 冲突

**问题现象**：CA 无法缩容节点，因为 PDB 阻止驱逐。

**解决步骤**：

```bash
# 步骤 1: 检查 CA 日志
kubectl logs -n kube-system -l app=cluster-autoscaler | grep -i pdb

# 步骤 2: 检查节点上的 Pod 及其 PDB
kubectl get pods -A --field-selector spec.nodeName=<node> -o wide
kubectl get pdb -A

# 步骤 3: 确保 PDB 配置允许缩容
# Pod 数量应该大于 minAvailable
```

**适合缩容的 PDB 配置**：

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: scalable-app-pdb
spec:
  # 使用 maxUnavailable 而不是绝对的 minAvailable
  maxUnavailable: 1
  
  # 或使用百分比
  # maxUnavailable: 25%
  
  selector:
    matchLabels:
      app: my-app
```

### 3.8 安全生产风险提示

| 操作 | 风险等级 | 潜在风险 | 建议措施 |
|------|----------|----------|----------|
| --disable-eviction | 高 | 绕过 PDB 保护，可能中断服务 | 仅紧急情况使用 |
| 删除 PDB | 高 | 失去驱逐保护 | 维护后立即恢复 |
| minAvailable = 100% | 高 | 完全无法驱逐 | 避免这种配置 |
| 修改生产 PDB | 中 | 可能影响可用性保证 | 选择低峰期 |
| 创建新 PDB | 低 | 可能影响后续维护 | 验证配置合理性 |

### 附录：快速诊断命令

```bash
# ===== PDB 一键诊断脚本 =====

echo "=== 所有 PDB 状态 ==="
kubectl get pdb -A -o wide

echo -e "\n=== 无法中断的 PDB (disruptionsAllowed=0) ==="
kubectl get pdb -A -o json | jq -r '.items[] | select(.status.disruptionsAllowed == 0) | "\(.metadata.namespace)/\(.metadata.name): expected=\(.status.expectedPods), healthy=\(.status.currentHealthy), minAvail=\(.spec.minAvailable)"'

echo -e "\n=== PDB 配置详情 ==="
kubectl get pdb -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
MIN-AVAILABLE:.spec.minAvailable,\
MAX-UNAVAILABLE:.spec.maxUnavailable,\
ALLOWED:.status.disruptionsAllowed,\
HEALTHY:.status.currentHealthy,\
EXPECTED:.status.expectedPods

echo -e "\n=== 不健康的 Pod (可能影响 PDB) ==="
kubectl get pods -A | grep -v "Running\|Completed" | head -20

echo -e "\n=== 驱逐事件 ==="
kubectl get events -A --field-selector reason=Evicted --sort-by='.lastTimestamp' | tail -10
```

### 附录：常用 PDB 配置模板

```yaml
# 1. 基本高可用配置 (3+ 副本)
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ha-app-pdb
spec:
  maxUnavailable: 1  # 或 minAvailable: 2
  selector:
    matchLabels:
      app: ha-app

---
# 2. 百分比配置 (推荐用于可扩展应用)
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: scalable-app-pdb
spec:
  maxUnavailable: 25%  # 最多 25% 不可用
  selector:
    matchLabels:
      app: scalable-app

---
# 3. StatefulSet 配置
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: stateful-app-pdb
spec:
  minAvailable: 2  # 保证法定人数
  selector:
    matchLabels:
      app: stateful-app

---
# 4. 单副本应用 (不推荐，但有时必须)
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: single-replica-pdb
spec:
  maxUnavailable: 0  # 不允许任何中断
  # 警告: 这会阻止所有自愿驱逐
  selector:
    matchLabels:
      app: critical-single-app
```
