# Scheduler 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 高级

---

## 目录

1. [问题现象与影响分析](#1-问题现象与影响分析)
2. [排查方法与步骤](#2-排查方法与步骤)
3. [解决方案与风险控制](#3-解决方案与风险控制)

---

## 1. 问题现象与影响分析

### 1.1 常见问题现象

#### 1.1.1 Scheduler 服务不可用

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 进程未运行 | `kube-scheduler not running` | systemd/容器 | `systemctl status kube-scheduler` |
| 连接 API Server 失败 | `error retrieving resource lock` | Scheduler 日志 | Scheduler 日志 |
| 证书错误 | `x509: certificate signed by unknown authority` | Scheduler 日志 | Scheduler 日志 |
| Leader 选举失败 | `failed to acquire lease` | Scheduler 日志 | Scheduler 日志 |
| 配置错误 | `unable to load scheduler config` | Scheduler 日志 | Scheduler 启动日志 |

#### 1.1.2 Pod 调度失败

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 资源不足 | `Insufficient cpu/memory` | Pod Events | `kubectl describe pod` |
| 节点不满足条件 | `0/N nodes are available` | Pod Events | `kubectl describe pod` |
| 亲和性不满足 | `node(s) didn't match pod affinity/anti-affinity rules` | Pod Events | `kubectl describe pod` |
| 污点不容忍 | `node(s) had taints that the pod didn't tolerate` | Pod Events | `kubectl describe pod` |
| PVC 未绑定 | `persistentvolumeclaim not found` | Pod Events | `kubectl describe pod` |
| 端口冲突 | `node(s) didn't have free ports for the requested pod ports` | Pod Events | `kubectl describe pod` |
| 拓扑约束不满足 | `node(s) didn't match pod topology spread constraints` | Pod Events | `kubectl describe pod` |

#### 1.1.3 调度性能问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 调度延迟高 | `scheduling_duration_seconds increased` | Prometheus | 监控系统 |
| 调度队列堆积 | 大量 Pod 处于 Pending | kubectl | `kubectl get pods --field-selector=status.phase=Pending` |
| 插件执行慢 | `plugin <name> took too long` | Scheduler 日志 | Scheduler 日志 |
| 抢占频繁 | `preemption attempts increased` | Scheduler 日志 | Scheduler 日志 |

#### 1.1.4 调度策略问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 自定义调度器未生效 | Pod 未被预期调度器调度 | Pod Spec | `kubectl get pod -o yaml` |
| 优先级调度异常 | 高优先级 Pod 未抢占 | Pod Events | `kubectl describe pod` |
| 调度门控阻塞 | `schedulingGates not cleared` | Pod Events | `kubectl describe pod` (v1.28+) |
| 扩展点错误 | `extension point <name> failed` | Scheduler 日志 | Scheduler 日志 |

### 1.2 报错查看方式汇总

```bash
# 查看 Scheduler 进程状态（systemd 管理）
systemctl status kube-scheduler

# 查看 Scheduler 日志（systemd 管理）
journalctl -u kube-scheduler -f --no-pager -l

# 查看 Scheduler 日志（静态 Pod 方式）
kubectl logs -n kube-system kube-scheduler-<node-name> --tail=500

# 查看 Scheduler 容器日志
crictl logs $(crictl ps -q --name kube-scheduler)

# 检查 Scheduler 健康状态
curl -k https://127.0.0.1:10259/healthz

# 查看 Scheduler Leader 信息
kubectl get leases -n kube-system kube-scheduler -o yaml

# 查看调度失败的 Pod
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# 查看 Pod 调度事件
kubectl describe pod <pod-name> | grep -A20 Events

# 查看 Scheduler 指标
curl -k https://127.0.0.1:10259/metrics | grep scheduler
```

### 1.3 影响面分析

#### 1.3.1 直接影响

| 影响范围 | 影响程度 | 影响描述 |
|----------|----------|----------|
| **新 Pod 调度** | 完全不可用 | 新创建的 Pod 无法被调度到节点 |
| **Pod 重调度** | 不可用 | 需要重调度的 Pod（如节点驱逐）无法调度 |
| **抢占机制** | 失效 | 高优先级 Pod 无法抢占低优先级 Pod |
| **资源分配** | 停滞 | 集群资源无法被合理分配 |

#### 1.3.2 间接影响

| 影响范围 | 影响程度 | 影响描述 |
|----------|----------|----------|
| **现有工作负载** | 无直接影响 | 已运行的 Pod 继续运行 |
| **Deployment 扩容** | 失败 | 新副本无法调度 |
| **DaemonSet 部署** | 部分影响 | 新节点上的 DaemonSet Pod 无法调度 |
| **Job/CronJob** | 失败 | 新的 Job Pod 无法调度 |
| **故障恢复** | 延迟 | 节点故障后 Pod 无法重新调度 |
| **自动扩缩容** | 失效 | HPA 扩容的 Pod 无法调度 |
| **滚动更新** | 阻塞 | 新版本 Pod 无法调度，更新无法完成 |

#### 1.3.3 影响评估矩阵

| 故障持续时间 | 影响程度 | 业务影响 | 响应优先级 |
|--------------|----------|----------|------------|
| < 5 分钟 | 低 | 少量 Pod 调度延迟 | P2 |
| 5-30 分钟 | 中 | 新部署和扩容受阻 | P1 |
| 30-60 分钟 | 高 | 故障恢复受影响 | P0 |
| > 60 分钟 | 严重 | 业务连续性风险 | P0 紧急 |

---

## 2. 排查方法与步骤

### 2.1 排查原理

Scheduler 负责将 Pod 分配到合适的节点。排查需要从以下层面：

1. **服务层面**：Scheduler 进程是否正常运行
2. **连接层面**：与 API Server 的连接是否正常
3. **选举层面**：Leader 选举是否成功（高可用场景）
4. **算法层面**：调度算法是否正确执行
5. **配置层面**：调度策略和插件配置

### 2.2 排查逻辑决策树

```
开始排查
    │
    ├─► 检查 Scheduler 状态
    │       │
    │       ├─► 进程不存在 ──► 检查启动失败原因
    │       │
    │       └─► 进程存在 ──► 继续下一步
    │
    ├─► 检查 API Server 连接
    │       │
    │       ├─► 连接失败 ──► 检查网络和证书
    │       │
    │       └─► 连接正常 ──► 继续下一步
    │
    ├─► 检查 Leader 选举（HA 场景）
    │       │
    │       ├─► 非 Leader ──► 检查是否有其他 Leader
    │       │
    │       └─► 是 Leader ──► 继续下一步
    │
    ├─► 检查调度失败原因
    │       │
    │       ├─► 资源不足 ──► 检查节点资源
    │       │
    │       ├─► 约束不满足 ──► 检查亲和性/污点配置
    │       │
    │       └─► 其他原因 ──► 根据事件分析
    │
    └─► 检查调度性能
            │
            ├─► 延迟高 ──► 分析插件执行时间
            │
            └─► 性能正常 ──► 完成排查
```

### 2.3 排查步骤和具体命令

#### 2.3.1 第一步：检查 Scheduler 进程状态

```bash
# 检查进程是否存在
ps aux | grep kube-scheduler | grep -v grep

# systemd 管理的服务状态
systemctl status kube-scheduler

# 静态 Pod 方式检查
crictl ps -a | grep kube-scheduler

# 查看进程启动参数
cat /proc/$(pgrep kube-scheduler)/cmdline | tr '\0' '\n'

# 检查健康端点
curl -k https://127.0.0.1:10259/healthz

# 查看详细健康状态
curl -k 'https://127.0.0.1:10259/healthz?verbose'
```

#### 2.3.2 第二步：检查 API Server 连接

```bash
# 查看 Scheduler 日志中的连接错误
journalctl -u kube-scheduler | grep -iE "(unable to connect|connection refused|error)"

# 测试 kubeconfig 是否有效
kubectl --kubeconfig=/etc/kubernetes/scheduler.conf get nodes

# 检查证书有效期
openssl x509 -in /etc/kubernetes/pki/scheduler.crt -noout -dates 2>/dev/null || \
openssl x509 -in /etc/kubernetes/scheduler.conf -noout -dates 2>/dev/null

# 检查 API Server 可达性
curl -k https://<api-server-ip>:6443/healthz
```

#### 2.3.3 第三步：检查 Leader 选举

```bash
# 查看 Scheduler Lease
kubectl get leases -n kube-system kube-scheduler -o yaml

# 输出示例：
# spec:
#   holderIdentity: master-1_<uuid>
#   leaseDurationSeconds: 15
#   renewTime: "2024-01-15T10:30:00Z"

# 检查当前哪个 Scheduler 是 Leader
kubectl get leases -n kube-system kube-scheduler -o jsonpath='{.spec.holderIdentity}'

# 查看 Scheduler 日志中的选举信息
journalctl -u kube-scheduler | grep -iE "(became leader|acquired lease|lost lease)"

# 高可用场景：检查所有 Scheduler 实例
for node in master-1 master-2 master-3; do
  echo "=== $node ==="
  ssh $node "crictl ps | grep kube-scheduler"
done
```

#### 2.3.4 第四步：检查调度失败原因

```bash
# 查看所有 Pending Pod
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# 查看 Pod 调度事件
kubectl describe pod <pod-name> -n <namespace> | grep -A30 Events

# 查看 Pod 的调度条件
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A20 conditions

# 检查节点资源
kubectl describe nodes | grep -A10 "Allocated resources"

# 查看节点可用资源
kubectl top nodes

# 检查节点污点
kubectl get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints'

# 检查特定 Pod 的亲和性配置
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A50 affinity

# 检查 PVC 状态
kubectl get pvc -n <namespace>

# 查看调度器记录的失败原因
kubectl get events --field-selector=reason=FailedScheduling --sort-by='.metadata.creationTimestamp'
```

#### 2.3.5 第五步：检查调度配置

```bash
# 查看 Scheduler 配置文件
cat /etc/kubernetes/scheduler-config.yaml

# 检查 Scheduler 启动参数
crictl inspect $(crictl ps -q --name kube-scheduler) | jq '.info.config.process.args'

# 查看默认调度器配置（v1.25+）
kubectl get configmap -n kube-system kube-scheduler -o yaml

# 检查调度器 Profile
cat /etc/kubernetes/scheduler-config.yaml | grep -A50 profiles

# 验证配置语法
kube-scheduler --config=/etc/kubernetes/scheduler-config.yaml --dry-run
```

#### 2.3.6 第六步：检查调度性能

```bash
# 获取调度器指标
curl -k https://127.0.0.1:10259/metrics | grep -E "scheduler_"

# 关键指标说明：
# scheduler_scheduling_duration_seconds - 调度延迟
# scheduler_pending_pods - 等待调度的 Pod 数
# scheduler_preemption_attempts_total - 抢占尝试次数
# scheduler_pod_scheduling_attempts - Pod 调度尝试次数

# 检查调度延迟分布
curl -k https://127.0.0.1:10259/metrics | grep scheduler_scheduling_duration_seconds

# 检查 Pending Pod 数量
curl -k https://127.0.0.1:10259/metrics | grep scheduler_pending_pods

# 检查调度队列状态
curl -k https://127.0.0.1:10259/metrics | grep scheduler_queue_incoming_pods_total

# 检查插件执行时间
curl -k https://127.0.0.1:10259/metrics | grep scheduler_plugin_execution_duration_seconds
```

#### 2.3.7 第七步：检查日志

```bash
# 实时查看日志
journalctl -u kube-scheduler -f --no-pager

# 查看最近的错误日志
journalctl -u kube-scheduler -p err --since "1 hour ago"

# 静态 Pod 方式查看日志
crictl logs $(crictl ps -q --name kube-scheduler) 2>&1 | tail -500

# 查找调度失败相关日志
journalctl -u kube-scheduler | grep -iE "(failed|unable|error|cannot)" | tail -50

# 提高日志级别进行调试（临时）
# 修改启动参数添加 --v=4 或更高

# 查看特定 Pod 的调度日志
journalctl -u kube-scheduler | grep "<pod-name>" | tail -20
```

### 2.4 排查注意事项

#### 2.4.1 安全注意事项

| 注意项 | 说明 | 建议 |
|--------|------|------|
| **kubeconfig 安全** | Scheduler 的 kubeconfig 有集群权限 | 不要泄露 |
| **证书安全** | 证书用于 API Server 认证 | 妥善保管 |
| **配置敏感性** | 调度配置影响资源分配 | 变更需审批 |

#### 2.4.2 操作注意事项

| 注意项 | 说明 | 建议 |
|--------|------|------|
| **高可用场景** | 多 Scheduler 实例需要 Leader 选举 | 确保只有一个 Leader |
| **配置变更** | 配置变更需要重启 Scheduler | 在维护窗口操作 |
| **日志级别** | 高日志级别会影响性能 | 调试完成后恢复 |
| **自定义调度器** | 检查是否使用了自定义调度器 | 确认 schedulerName |

---

## 3. 解决方案与风险控制

### 3.1 Scheduler 进程未运行

#### 3.1.1 解决步骤

```bash
# 步骤 1：检查启动失败原因
journalctl -u kube-scheduler -b --no-pager | tail -100

# 步骤 2：检查配置文件语法
# 验证 YAML 语法
python3 -c "import yaml; yaml.safe_load(open('/etc/kubernetes/manifests/kube-scheduler.yaml'))"

# 步骤 3：检查证书文件
ls -la /etc/kubernetes/pki/
ls -la /etc/kubernetes/scheduler.conf

# 步骤 4：验证 kubeconfig
kubectl --kubeconfig=/etc/kubernetes/scheduler.conf cluster-info

# 步骤 5：修复问题后重启
# systemd 方式
systemctl restart kube-scheduler

# 静态 Pod 方式
mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/
sleep 5
mv /tmp/kube-scheduler.yaml /etc/kubernetes/manifests/

# 步骤 6：验证恢复
kubectl get pods -n kube-system | grep scheduler
curl -k https://127.0.0.1:10259/healthz
```

#### 3.1.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 重启期间新 Pod 无法调度 | 在维护窗口操作 |
| **低** | 配置检查一般无风险 | - |
| **中** | 配置修改可能引入新问题 | 修改前备份 |

#### 3.1.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. Scheduler 不可用期间新 Pod 将处于 Pending 状态
2. 已运行的 Pod 不受影响
3. 高可用集群确保其他 Scheduler 实例正常
4. 修改配置前备份原始文件
5. 验证恢复后检查 Pending Pod 是否被调度
```

### 3.2 Pod 因资源不足无法调度

#### 3.2.1 解决步骤

```bash
# 步骤 1：确认资源不足情况
kubectl describe pod <pod-name> | grep -A10 Events

# 步骤 2：检查节点资源使用
kubectl describe nodes | grep -A15 "Allocated resources"
kubectl top nodes

# 步骤 3：检查 Pod 资源请求
kubectl get pod <pod-name> -o yaml | grep -A10 resources

# 步骤 4：解决方案选择
# 方案 A：减少 Pod 资源请求（如果请求过大）
kubectl patch deployment <name> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container>","resources":{"requests":{"cpu":"100m","memory":"128Mi"}}}]}}}}'

# 方案 B：扩容节点资源（添加新节点）
# 联系运维或云平台添加节点

# 方案 C：清理无用资源
kubectl get pods --all-namespaces | grep -E "(Evicted|Error|Completed)" | awk '{print $1,$2}' | xargs -L1 kubectl delete pod -n

# 方案 D：使用集群自动扩缩容（CA）
# 确保 Cluster Autoscaler 已配置并正常工作
kubectl get pods -n kube-system | grep cluster-autoscaler

# 步骤 5：验证调度成功
kubectl get pod <pod-name> -w
```

#### 3.2.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **低** | 减少资源请求可能影响性能 | 根据实际需求调整 |
| **中** | 添加节点需要时间 | 评估业务紧急程度 |
| **低** | 清理资源一般无风险 | 确认是无用资源 |

#### 3.2.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 减少资源请求前确认应用实际需求
2. 不要过度减少 request 导致资源争抢
3. 清理资源前确认不会影响业务
4. 添加节点后验证节点状态正常
5. 考虑设置 ResourceQuota 防止资源过度使用
```

### 3.3 Pod 因亲和性/污点无法调度

#### 3.3.1 解决步骤

```bash
# 步骤 1：检查 Pod 亲和性配置
kubectl get pod <pod-name> -o yaml | grep -A30 affinity

# 步骤 2：检查节点标签
kubectl get nodes --show-labels

# 步骤 3：检查节点污点
kubectl get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints'

# 步骤 4：检查 Pod 容忍度
kubectl get pod <pod-name> -o yaml | grep -A10 tolerations

# 步骤 5：解决方案选择
# 方案 A：修改 Pod 亲和性配置
kubectl patch deployment <name> -p '{"spec":{"template":{"spec":{"affinity":null}}}}'

# 方案 B：添加节点标签
kubectl label nodes <node-name> <key>=<value>

# 方案 C：移除节点污点
kubectl taint nodes <node-name> <key>-

# 方案 D：添加 Pod 容忍度
kubectl patch deployment <name> -p '{"spec":{"template":{"spec":{"tolerations":[{"key":"<key>","operator":"Exists","effect":"NoSchedule"}]}}}}'

# 步骤 6：验证调度
kubectl get pod <pod-name> -w
```

#### 3.3.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 修改亲和性可能影响高可用 | 评估调度策略变更影响 |
| **低** | 添加标签一般无风险 | 确认标签用途 |
| **中** | 移除污点可能导致不合适的调度 | 评估污点的作用 |

#### 3.3.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 修改亲和性前理解原有配置的目的
2. 节点污点通常有特定用途，移除前需评估
3. 批量修改亲和性可能导致大量 Pod 重调度
4. 建议使用软亲和性（preferred）而非硬亲和性（required）
5. 变更后监控 Pod 分布情况
```

### 3.4 Scheduler 性能问题

#### 3.4.1 解决步骤

```bash
# 步骤 1：确认性能瓶颈
curl -k https://127.0.0.1:10259/metrics | grep scheduler_scheduling_duration_seconds

# 步骤 2：检查调度队列
curl -k https://127.0.0.1:10259/metrics | grep scheduler_pending_pods

# 步骤 3：分析插件执行时间
curl -k https://127.0.0.1:10259/metrics | grep scheduler_plugin_execution_duration_seconds

# 步骤 4：优化调度器配置
# 调整并行度（v1.25+）
cat > /etc/kubernetes/scheduler-config.yaml << EOF
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
parallelism: 32  # 默认 16
profiles:
  - schedulerName: default-scheduler
    plugins:
      preScore:
        disabled:
          - name: InterPodAffinity  # 禁用高开销插件（如不需要）
EOF

# 步骤 5：重启 Scheduler 应用配置
mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/
sleep 5
mv /tmp/kube-scheduler.yaml /etc/kubernetes/manifests/

# 步骤 6：验证性能改善
curl -k https://127.0.0.1:10259/metrics | grep scheduler_scheduling_duration_seconds
```

#### 3.4.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 禁用插件可能影响调度策略 | 确认插件作用后再禁用 |
| **中** | 配置变更需要重启 | 在维护窗口操作 |
| **低** | 调整并行度一般无风险 | 根据 CPU 资源调整 |

#### 3.4.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 禁用插件前理解其功能
2. InterPodAffinity 插件对性能影响大，但某些场景必需
3. 增加并行度会增加 CPU 使用
4. 配置变更后监控调度延迟
5. 大规模集群建议使用调度框架扩展
```

### 3.5 自定义调度器问题

#### 3.5.1 解决步骤

```bash
# 步骤 1：确认 Pod 使用的调度器
kubectl get pod <pod-name> -o yaml | grep schedulerName

# 步骤 2：检查自定义调度器状态
kubectl get pods -n kube-system | grep <scheduler-name>

# 步骤 3：查看自定义调度器日志
kubectl logs -n kube-system <custom-scheduler-pod>

# 步骤 4：如果自定义调度器故障，临时使用默认调度器
kubectl patch deployment <name> -p '{"spec":{"template":{"spec":{"schedulerName":"default-scheduler"}}}}'

# 步骤 5：修复自定义调度器
# 检查调度器 Deployment
kubectl describe deployment -n kube-system <custom-scheduler>

# 检查调度器 RBAC
kubectl get clusterrolebinding | grep <custom-scheduler>

# 步骤 6：恢复使用自定义调度器
kubectl patch deployment <name> -p '{"spec":{"template":{"spec":{"schedulerName":"<custom-scheduler>"}}}}'
```

#### 3.5.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 切换调度器可能影响调度策略 | 临时措施，尽快修复原调度器 |
| **低** | 日志查看无风险 | - |
| **中** | RBAC 变更可能影响权限 | 谨慎修改 |

#### 3.5.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 自定义调度器可能有特定的调度策略
2. 切换到默认调度器是临时解决方案
3. 确保自定义调度器有正确的 RBAC 权限
4. 自定义调度器需要正确处理 Leader 选举
5. 监控自定义调度器的健康状态
```

---

## 附录

### A. Scheduler 关键指标

| 指标名称 | 说明 | 告警阈值建议 |
|----------|------|--------------|
| `scheduler_scheduling_duration_seconds` | 调度延迟 | P99 > 1s |
| `scheduler_pending_pods` | Pending Pod 数 | > 100 |
| `scheduler_preemption_attempts_total` | 抢占尝试数 | 异常增长 |
| `scheduler_pod_scheduling_attempts` | 调度尝试次数 | 每 Pod > 10 |
| `scheduler_queue_incoming_pods_total` | 入队 Pod 数 | 监控趋势 |

### B. 常见启动参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--config` | - | 调度器配置文件路径 |
| `--leader-elect` | true | 是否启用 Leader 选举 |
| `--bind-address` | 0.0.0.0 | 监听地址 |
| `--secure-port` | 10259 | HTTPS 端口 |
| `--v` | 0 | 日志级别 |

### C. 调度失败常见原因速查

| 错误信息 | 原因 | 解决方向 |
|----------|------|----------|
| `Insufficient cpu` | CPU 资源不足 | 添加节点或减少请求 |
| `Insufficient memory` | 内存资源不足 | 添加节点或减少请求 |
| `node(s) had taints` | 节点有污点 | 添加容忍度或移除污点 |
| `didn't match node selector` | 节点选择器不匹配 | 修改选择器或添加标签 |
| `didn't match pod affinity` | 亲和性不满足 | 修改亲和性配置 |
| `PersistentVolumeClaim not found` | PVC 不存在 | 创建 PVC |
| `didn't have free ports` | 端口冲突 | 修改 hostPort |
