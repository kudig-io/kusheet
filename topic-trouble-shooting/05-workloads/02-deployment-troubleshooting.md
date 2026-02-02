# Deployment 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 中级
>
> **版本说明**:
> - v1.25+ 支持 minReadySeconds 与 PodReadinessGate 配合
> - v1.27+ 支持更精细的 Pod 删除策略
> - v1.28+ 支持 SidecarContainers (initContainers restartPolicy: Always)

---

## 第一部分：问题现象与影响分析

### 1.1 Deployment 控制器架构

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        Deployment Controller                              │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌────────────────────────────────────────────────────────────────┐    │
│   │                      Deployment                                 │    │
│   │  spec.replicas: 3                                              │    │
│   │  spec.strategy.type: RollingUpdate                             │    │
│   │  spec.strategy.rollingUpdate:                                  │    │
│   │    maxUnavailable: 25%                                         │    │
│   │    maxSurge: 25%                                               │    │
│   └────────────────────────────┬───────────────────────────────────┘    │
│                                │                                         │
│                    Deployment Controller                                 │
│                    (管理 ReplicaSet)                                     │
│                                │                                         │
│            ┌──────────────────┼──────────────────┐                      │
│            │                  │                  │                       │
│            ▼                  ▼                  ▼                       │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                 │
│   │ ReplicaSet  │    │ ReplicaSet  │    │ ReplicaSet  │                 │
│   │ (revision 1)│    │ (revision 2)│    │ (revision 3)│                 │
│   │ replicas: 0 │    │ replicas: 0 │    │ replicas: 3 │  ← 当前版本     │
│   └─────────────┘    └─────────────┘    └──────┬──────┘                 │
│                                                │                         │
│                               ReplicaSet Controller                      │
│                               (管理 Pod)                                 │
│                                                │                         │
│                      ┌────────────┬────────────┼────────────┐           │
│                      ▼            ▼            ▼            ▼           │
│                 ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐         │
│                 │ Pod-1  │  │ Pod-2  │  │ Pod-3  │  │ Pod-4  │         │
│                 │ Ready  │  │ Ready  │  │ Ready  │  │Creating│ surge  │
│                 └────────┘  └────────┘  └────────┘  └────────┘         │
│                                                                          │
│   滚动更新过程：                                                         │
│   1. 创建新 RS (或扩容已有新版本 RS)                                     │
│   2. 根据 maxSurge 创建新 Pod                                           │
│   3. 新 Pod Ready 后，根据 maxUnavailable 删除旧 Pod                     │
│   4. 重复直到完成                                                        │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### 1.2 常见问题现象

#### 1.2.1 Deployment 创建/更新问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 创建失败 | `admission webhook denied` | API Server | kubectl apply 输出 |
| 资源配额超限 | `exceeded quota` | API Server | kubectl apply 输出 |
| 副本数不足 | `replicas not ready` | kubectl | `kubectl get deployment` |
| 滚动更新卡住 | `waiting for rollout to finish` | kubectl | `kubectl rollout status` |
| 更新超时 | `deployment exceeded progress deadline` | Events | `kubectl describe deployment` |
| 回滚失败 | `rollback failed` | kubectl | kubectl rollout 输出 |
| 镜像更新未生效 | Pod 仍使用旧镜像 | kubectl | `kubectl get pods -o yaml` |

#### 1.2.2 ReplicaSet 问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| RS 副本数不增 | 新 RS replicas 为 0 | kubectl | `kubectl get rs` |
| 旧 RS 未清理 | revisionHistoryLimit 超限 | kubectl | `kubectl get rs` |
| RS 卡在 0 副本 | 新 RS 无法创建 Pod | kubectl | `kubectl describe rs` |
| 多个 RS 活跃 | 滚动更新未完成 | kubectl | `kubectl get rs` |

#### 1.2.3 Pod 调度/运行问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| Pod Pending | `Insufficient cpu/memory` | Pod Events | `kubectl describe pod` |
| Pod CrashLoop | `CrashLoopBackOff` | kubectl | `kubectl get pods` |
| Pod 不健康 | `Readiness probe failed` | Pod Events | `kubectl describe pod` |
| Pod 反复重启 | restartCount 持续增加 | kubectl | `kubectl get pods` |
| Init 容器失败 | `Init:CrashLoopBackOff` | kubectl | `kubectl get pods` |

### 1.3 报错查看方式汇总

```bash
# 查看 Deployment 状态
kubectl get deployment <name> -o wide
kubectl describe deployment <name>

# 查看 Deployment 条件状态
kubectl get deployment <name> -o jsonpath='{.status.conditions[*].type}'

# 查看 Deployment 事件
kubectl get events --field-selector=involvedObject.name=<deployment-name> --sort-by='.lastTimestamp'

# 查看 ReplicaSet 状态
kubectl get rs -l app=<label> --sort-by='.metadata.creationTimestamp'
kubectl describe rs <rs-name>

# 查看 Pod 状态
kubectl get pods -l app=<label> -o wide --show-labels
kubectl describe pod <pod-name>

# 查看滚动更新状态
kubectl rollout status deployment <name> --timeout=5m
kubectl rollout history deployment <name>

# 查看 Deployment YAML（含 status）
kubectl get deployment <name> -o yaml
```

### 1.4 影响面分析

| 问题类型 | 直接影响 | 间接影响 | 影响范围 |
|----------|----------|----------|----------|
| 创建失败 | 服务无法部署 | 依赖服务不可用 | 应用级 |
| 滚动更新卡住 | 新旧版本并存 | 状态不一致、流量异常 | 应用级 |
| 副本数不足 | 服务能力下降 | 响应延迟增加 | 性能 |
| Pod 反复重启 | 服务不稳定 | 请求失败、数据不一致 | 可用性 |
| progressDeadline 超时 | 更新标记失败 | 告警触发、人工干预 | 运维 |

---

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
Deployment 问题
    │
    ├─► 检查 Deployment 状态
    │       │
    │       ├─► Deployment 不存在 ──► 检查创建命令和 YAML
    │       │
    │       ├─► Available=False ──► 检查 Pod 状态
    │       │
    │       └─► Progressing=False ──► 检查更新策略和资源
    │
    ├─► 检查 ReplicaSet 状态
    │       │
    │       ├─► 新 RS replicas=0 ──► 检查 Webhook/Admission
    │       │
    │       ├─► 新 RS 创建 Pod 失败 ──► 检查 Pod Events
    │       │
    │       └─► 旧 RS 未缩容 ──► 检查 maxUnavailable 和 Pod 健康
    │
    ├─► 检查 Pod 状态
    │       │
    │       ├─► Pending ──► 检查资源、调度、亲和性
    │       │       │
    │       │       ├─► Insufficient resources ──► 扩容节点或减少 requests
    │       │       ├─► Node selector mismatch ──► 修正标签或选择器
    │       │       ├─► Taints not tolerated ──► 添加 tolerations
    │       │       └─► PVC not bound ──► 检查存储类和 PV
    │       │
    │       ├─► ImagePullBackOff ──► 检查镜像和凭证
    │       │
    │       ├─► CrashLoopBackOff ──► 检查容器日志和配置
    │       │       │
    │       │       ├─► 应用启动失败 ──► 修复应用代码/配置
    │       │       ├─► 健康检查失败 ──► 调整探针配置
    │       │       └─► 依赖服务不可用 ──► 添加 init container 或重试
    │       │
    │       ├─► Running but Not Ready ──► 检查 readinessProbe
    │       │
    │       └─► OOMKilled ──► 增加内存限制
    │
    └─► 检查滚动更新
            │
            ├─► 更新卡住 ──► 检查 progressDeadlineSeconds
            │
            ├─► 新旧 Pod 并存过久 ──► 检查 minReadySeconds
            │
            └─► 更新后回滚 ──► 检查新版本问题
```

### 2.2 排查命令集

#### 2.2.1 Deployment 状态检查

```bash
# 查看 Deployment 概览
kubectl get deployment <name> -o wide

# 查看详细状态条件
kubectl get deployment <name> -o jsonpath='{range .status.conditions[*]}{.type}: {.status} - {.reason}{"\n"}{end}'

# 预期输出：
# Available: True - MinimumReplicasAvailable
# Progressing: True - NewReplicaSetAvailable

# 查看副本状态
kubectl get deployment <name> -o jsonpath='
  desired: {.spec.replicas}
  current: {.status.replicas}
  ready: {.status.readyReplicas}
  available: {.status.availableReplicas}
  updated: {.status.updatedReplicas}
'

# 查看更新策略
kubectl get deployment <name> -o jsonpath='{.spec.strategy}'

# 查看 revision 历史
kubectl rollout history deployment <name>
kubectl rollout history deployment <name> --revision=<n>
```

#### 2.2.2 ReplicaSet 检查

```bash
# 列出所有 RS，按时间排序
kubectl get rs -l app=<label> --sort-by='.metadata.creationTimestamp'

# 查看 RS 详细信息
kubectl describe rs <rs-name>

# 查看当前活跃的 RS
kubectl get rs -l app=<label> -o jsonpath='{range .items[?(@.spec.replicas>0)]}{.metadata.name}: {.spec.replicas}/{.status.readyReplicas}{"\n"}{end}'

# 检查 RS 的 Pod 模板哈希
kubectl get rs -l app=<label> -o jsonpath='{range .items[*]}{.metadata.name}: {.metadata.labels.pod-template-hash}{"\n"}{end}'
```

#### 2.2.3 Pod 状态检查

```bash
# 查看 Pod 列表和状态
kubectl get pods -l app=<label> -o wide

# 查看 Pod 事件
kubectl describe pod <pod-name> | tail -20

# 查看容器日志
kubectl logs <pod-name> --tail=100
kubectl logs <pod-name> --previous  # 崩溃前的日志
kubectl logs <pod-name> -c <init-container-name>  # init 容器日志

# 查看 Pod 资源使用
kubectl top pod <pod-name> --containers

# 检查 Pod 的 owner reference
kubectl get pod <pod-name> -o jsonpath='{.metadata.ownerReferences[*].name}'
```

#### 2.2.4 滚动更新监控

```bash
# 实时监控更新状态
kubectl rollout status deployment <name> -w

# 查看更新事件
kubectl get events --field-selector=involvedObject.kind=Deployment,involvedObject.name=<name> -w

# 监控 Pod 变化
kubectl get pods -l app=<label> -w

# 检查更新是否卡住
kubectl get deployment <name> -o jsonpath='{.status.conditions[?(@.type=="Progressing")].status}'
```

### 2.3 排查注意事项

| 注意项 | 说明 | 风险 |
|--------|------|------|
| 不要随意删除 RS | RS 保留用于回滚 | 丢失回滚能力 |
| 谨慎调整 progressDeadlineSeconds | 过短会误报失败 | 触发不必要告警 |
| 注意 minReadySeconds | 影响更新速度 | 更新时间过长 |
| 检查 PDB | 可能阻止 Pod 删除 | 更新卡住 |
| 注意资源配额 | 新 Pod 可能超限 | 创建失败 |

---

## 第三部分：解决方案与风险控制

### 3.1 滚动更新卡住

#### 3.1.1 诊断原因

```bash
# 检查 Deployment 条件
kubectl get deployment <name> -o jsonpath='{.status.conditions[?(@.type=="Progressing")]}'

# 检查是否是 progressDeadline 超时
# reason: ProgressDeadlineExceeded 表示超时

# 检查新 RS 的 Pod 状态
NEW_RS=$(kubectl get rs -l app=<label> --sort-by='.metadata.creationTimestamp' -o jsonpath='{.items[-1].metadata.name}')
kubectl describe rs $NEW_RS

# 检查 Pod 为什么没有 Ready
kubectl get pods -l app=<label> -o jsonpath='{range .items[?(@.status.phase!="Running")]}{.metadata.name}: {.status.phase}{"\n"}{end}'
```

#### 3.1.2 解决方案

```bash
# 方案 1：暂停更新，排查问题
kubectl rollout pause deployment <name>
# 排查并修复问题后恢复
kubectl rollout resume deployment <name>

# 方案 2：回滚到上一版本
kubectl rollout undo deployment <name>

# 方案 3：回滚到特定版本
kubectl rollout history deployment <name>
kubectl rollout undo deployment <name> --to-revision=<n>

# 方案 4：增加 progressDeadlineSeconds（如果只是启动慢）
kubectl patch deployment <name> -p '{"spec":{"progressDeadlineSeconds":900}}'

# 方案 5：调整更新策略（减少并发）
kubectl patch deployment <name> -p '{
  "spec": {
    "strategy": {
      "type": "RollingUpdate",
      "rollingUpdate": {
        "maxUnavailable": 0,
        "maxSurge": 1
      }
    }
  }
}'

# 方案 6：强制重建所有 Pod (Recreate 策略)
kubectl patch deployment <name> -p '{"spec":{"strategy":{"type":"Recreate"}}}'
# 注意：会导致服务中断
```

### 3.2 Pod 健康检查失败导致更新卡住

#### 3.2.1 诊断

```bash
# 检查 readinessProbe 配置
kubectl get deployment <name> -o jsonpath='{.spec.template.spec.containers[*].readinessProbe}' | jq

# 检查 Pod 的 Ready 条件
kubectl get pod <pod-name> -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'

# 检查探针失败详情
kubectl describe pod <pod-name> | grep -A5 "Readiness"
```

#### 3.2.2 解决方案

```bash
# 调整探针参数
kubectl patch deployment <name> --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/readinessProbe",
    "value": {
      "httpGet": {
        "path": "/health",
        "port": 8080
      },
      "initialDelaySeconds": 30,
      "periodSeconds": 10,
      "timeoutSeconds": 5,
      "successThreshold": 1,
      "failureThreshold": 3
    }
  }
]'

# 或者临时移除探针（仅用于紧急恢复）
kubectl patch deployment <name> --type='json' -p='[
  {"op": "remove", "path": "/spec/template/spec/containers/0/readinessProbe"}
]'
```

### 3.3 资源不足导致 Pod Pending

#### 3.3.1 解决方案

```bash
# 方案 1：减少资源请求
kubectl patch deployment <name> --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/resources/requests",
    "value": {"cpu": "100m", "memory": "128Mi"}
  }
]'

# 方案 2：清理无用资源
kubectl delete pods --field-selector=status.phase=Failed -A
kubectl delete jobs --field-selector=status.successful=1 -A

# 方案 3：使用优先级抢占
cat << EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
EOF

kubectl patch deployment <name> -p '{"spec":{"template":{"spec":{"priorityClassName":"high-priority"}}}}'
```

### 3.4 镜像拉取失败

#### 3.4.1 解决方案

```bash
# 检查镜像名称是否正确
kubectl get deployment <name> -o jsonpath='{.spec.template.spec.containers[*].image}'

# 创建镜像拉取凭证
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<password> \
  -n <namespace>

# 关联凭证到 Deployment
kubectl patch deployment <name> -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"regcred"}]}}}}'

# 强制重新拉取镜像
kubectl patch deployment <name> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container>","imagePullPolicy":"Always"}]}}}}'
kubectl rollout restart deployment <name>
```

### 3.5 常用更新策略配置

```yaml
# 保守策略：最小化风险
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0       # 始终保持完整副本数
      maxSurge: 1             # 每次只多创建 1 个
  minReadySeconds: 30         # Pod Ready 后等待 30s 才继续
  progressDeadlineSeconds: 600

# 快速策略：快速完成更新
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 50%
  minReadySeconds: 5
  progressDeadlineSeconds: 300

# 蓝绿部署：先创建所有新 Pod
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 100%          # 先创建同等数量新 Pod
```

### 3.6 安全生产风险提示

| 操作 | 风险等级 | 风险描述 | 防护措施 |
|------|----------|----------|----------|
| 回滚 (rollout undo) | 中 | 立即触发回滚 | 确认目标版本稳定 |
| 修改 strategy | 中 | 影响后续更新行为 | 了解策略含义 |
| 删除 RS | 高 | 丢失回滚能力 | 通常不要手动删除 |
| Recreate 策略 | 高 | 服务完全中断 | 仅用于可中断服务 |
| 强制删除 Pod | 中 | 可能丢失数据 | 确认 Pod 无状态 |
| 移除探针 | 中 | 失去健康检测 | 仅临时措施 |
| 调整 progressDeadline | 低 | 影响超时判断 | 根据实际启动时间设置 |

```
⚠️  安全生产风险提示：
1. 回滚前确认目标版本是稳定的，检查 rollout history
2. 大规模 Deployment 更新需要足够的集群资源余量
3. 修改 maxUnavailable=0 + maxSurge=0 会导致更新无法进行
4. progressDeadlineSeconds 只影响状态报告，不会自动回滚
5. 如果配置了 PDB，确保 PDB 允许足够的 Pod 不可用
6. 有状态应用的 Deployment 更新需要特别注意数据一致性
```

---

## 附录

### A. Deployment 状态字段说明

| 字段 | 说明 | 健康值 |
|------|------|--------|
| replicas | 当前副本总数 | 等于或接近 spec.replicas |
| readyReplicas | 就绪副本数 | 等于 spec.replicas |
| availableReplicas | 可用副本数 | 等于 spec.replicas |
| unavailableReplicas | 不可用副本数 | 0 |
| updatedReplicas | 已更新副本数 | 等于 spec.replicas |
| observedGeneration | 已观察到的版本 | 等于 metadata.generation |

### B. Deployment 条件状态

| 条件 | 状态 | 原因 | 说明 |
|------|------|------|------|
| Available | True | MinimumReplicasAvailable | 至少有最小副本数可用 |
| Available | False | MinimumReplicasUnavailable | 可用副本数不足 |
| Progressing | True | NewReplicaSetAvailable | 新 RS 已就绪 |
| Progressing | True | ReplicaSetUpdated | RS 正在更新 |
| Progressing | False | ProgressDeadlineExceeded | 更新超时 |
| ReplicaFailure | True | FailedCreate | Pod 创建失败 |

### C. 常用命令速查

```bash
# 更新镜像
kubectl set image deployment/<name> <container>=<image>:<tag>

# 扩缩容
kubectl scale deployment <name> --replicas=<n>

# 查看状态
kubectl rollout status deployment <name>

# 查看历史
kubectl rollout history deployment <name>

# 回滚
kubectl rollout undo deployment <name>
kubectl rollout undo deployment <name> --to-revision=<n>

# 暂停/恢复
kubectl rollout pause deployment <name>
kubectl rollout resume deployment <name>

# 重启所有 Pod
kubectl rollout restart deployment <name>

# 查看更新原因
kubectl describe deployment <name> | grep -A10 Conditions
```

### D. 排查清单

- [ ] Deployment 状态条件 (Available, Progressing)
- [ ] ReplicaSet 副本数和状态
- [ ] Pod 状态 (Pending, CrashLoop, Ready)
- [ ] Pod 事件和日志
- [ ] 资源配额和限制
- [ ] 镜像和镜像拉取凭证
- [ ] 更新策略参数
- [ ] 探针配置
- [ ] PDB 约束
- [ ] 节点资源可用性
