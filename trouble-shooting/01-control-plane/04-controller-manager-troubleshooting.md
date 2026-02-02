# Controller Manager 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 高级

---

## 目录

1. [问题现象与影响分析](#1-问题现象与影响分析)
2. [排查方法与步骤](#2-排查方法与步骤)
3. [解决方案与风险控制](#3-解决方案与风险控制)

---

## 1. 问题现象与影响分析

### 1.1 常见问题现象

#### 1.1.1 Controller Manager 服务不可用

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 进程未运行 | `kube-controller-manager not running` | systemd/容器 | `systemctl status kube-controller-manager` |
| 连接 API Server 失败 | `error retrieving resource lock` | CM 日志 | CM 日志 |
| 证书错误 | `x509: certificate has expired` | CM 日志 | CM 日志 |
| Leader 选举失败 | `failed to acquire lease` | CM 日志 | CM 日志 |
| 配置错误 | `unable to start controller` | CM 日志 | CM 启动日志 |

#### 1.1.2 控制器功能异常

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| Deployment 不更新 | RS 副本数不变 | kubectl | `kubectl get rs` |
| ReplicaSet 不扩缩容 | Pod 数量不变 | kubectl | `kubectl get pods` |
| Service Endpoints 不更新 | Endpoints 为空 | kubectl | `kubectl get endpoints` |
| Node 状态不更新 | Node 长期 NotReady | kubectl | `kubectl get nodes` |
| Job 不完成 | Job 状态不变 | kubectl | `kubectl get jobs` |
| PV 不绑定 | PVC 长期 Pending | kubectl | `kubectl get pvc` |
| SA Token 不创建 | Pod 启动失败 | Pod Events | `kubectl describe pod` |

#### 1.1.3 特定控制器故障

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| Node Controller 异常 | `nodes are not ready` | CM 日志 | CM 日志 |
| Endpoint Controller 异常 | `unable to sync endpoints` | CM 日志 | CM 日志 |
| ReplicaSet Controller 异常 | `unable to manage pods` | CM 日志 | CM 日志 |
| Namespace Controller 异常 | namespace 无法删除 | kubectl | `kubectl get ns` |
| GC Controller 异常 | 孤儿资源累积 | kubectl | `kubectl get all` |

#### 1.1.4 性能问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 控制循环延迟 | `controller sync took too long` | CM 日志 | CM 日志 |
| 工作队列堆积 | 大量待处理事件 | Prometheus | 监控系统 |
| API 限流 | `rate limiter Wait returned an error` | CM 日志 | CM 日志 |
| 内存使用高 | OOM Kill | 系统日志 | `dmesg` |

### 1.2 报错查看方式汇总

```bash
# 查看 Controller Manager 进程状态（systemd 管理）
systemctl status kube-controller-manager

# 查看 Controller Manager 日志（systemd 管理）
journalctl -u kube-controller-manager -f --no-pager -l

# 查看 Controller Manager 日志（静态 Pod 方式）
kubectl logs -n kube-system kube-controller-manager-<node-name> --tail=500

# 查看 Controller Manager 容器日志
crictl logs $(crictl ps -q --name kube-controller-manager)

# 检查健康状态
curl -k https://127.0.0.1:10257/healthz

# 查看详细健康状态
curl -k 'https://127.0.0.1:10257/healthz?verbose'

# 查看 Leader 信息
kubectl get leases -n kube-system kube-controller-manager -o yaml

# 查看控制器启用状态
curl -k https://127.0.0.1:10257/metrics | grep controller_manager

# 查看各控制器工作队列
curl -k https://127.0.0.1:10257/metrics | grep workqueue
```

### 1.3 影响面分析

#### 1.3.1 直接影响

| 影响范围 | 影响程度 | 影响描述 |
|----------|----------|----------|
| **Deployment 管理** | 失效 | Deployment 无法创建/更新 ReplicaSet |
| **ReplicaSet 管理** | 失效 | ReplicaSet 无法维护 Pod 副本数 |
| **Service Endpoints** | 失效 | Endpoints 无法自动更新 |
| **Node 管理** | 失效 | Node 状态无法检测和更新 |
| **命名空间清理** | 失效 | 删除的命名空间无法清理资源 |
| **垃圾回收** | 失效 | 孤儿资源无法自动清理 |
| **ServiceAccount** | 失效 | Token 无法自动创建 |
| **PV/PVC 绑定** | 失效 | PVC 无法自动绑定 PV |

#### 1.3.2 间接影响

| 影响范围 | 影响程度 | 影响描述 |
|----------|----------|----------|
| **现有工作负载** | 短期无影响 | 已运行的 Pod 继续运行 |
| **自愈能力** | 丧失 | Pod 崩溃后无法自动重建 |
| **滚动更新** | 阻塞 | 无法完成 Deployment 更新 |
| **扩缩容** | 失效 | 手动和自动扩缩容都无法执行 |
| **服务发现** | 部分影响 | 新 Pod 无法加入 Endpoints |
| **故障转移** | 失效 | 节点故障后 Pod 无法迁移 |
| **资源清理** | 累积 | 删除的资源无法清理 |

#### 1.3.3 控制器影响矩阵

| 控制器 | 管理资源 | 故障影响 |
|--------|----------|----------|
| **Deployment Controller** | Deployment → ReplicaSet | 无法滚动更新 |
| **ReplicaSet Controller** | ReplicaSet → Pod | 无法维护副本数 |
| **DaemonSet Controller** | DaemonSet → Pod | 新节点无 DaemonSet Pod |
| **StatefulSet Controller** | StatefulSet → Pod | 有状态应用无法管理 |
| **Job Controller** | Job → Pod | Job 无法执行 |
| **CronJob Controller** | CronJob → Job | 定时任务不执行 |
| **Endpoint Controller** | Service → Endpoints | 服务发现异常 |
| **Node Controller** | Node 状态 | 节点状态不更新 |
| **ServiceAccount Controller** | SA → Token | Pod 无法获取 Token |
| **PV/PVC Controller** | PVC → PV 绑定 | 存储无法挂载 |
| **Namespace Controller** | Namespace 清理 | NS 无法删除 |
| **GC Controller** | 孤儿资源 | 资源泄露 |

---

## 2. 排查方法与步骤

### 2.1 排查原理

Controller Manager 运行多个控制器，负责维护集群期望状态。排查需要从以下层面：

1. **服务层面**：Controller Manager 进程是否正常
2. **连接层面**：与 API Server 的连接是否正常
3. **选举层面**：Leader 选举是否成功
4. **控制器层面**：各控制器是否正常工作
5. **性能层面**：控制循环是否有延迟

### 2.2 排查逻辑决策树

```
开始排查
    │
    ├─► 检查 CM 进程状态
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
    ├─► 检查 Leader 选举
    │       │
    │       ├─► 非 Leader ──► 检查是否有其他 Leader
    │       │
    │       └─► 是 Leader ──► 继续下一步
    │
    ├─► 检查控制器状态
    │       │
    │       ├─► 控制器异常 ──► 分析具体控制器问题
    │       │
    │       └─► 控制器正常 ──► 继续下一步
    │
    └─► 检查性能
            │
            ├─► 延迟高 ──► 分析资源使用和 API 限流
            │
            └─► 性能正常 ──► 完成排查
```

### 2.3 排查步骤和具体命令

#### 2.3.1 第一步：检查进程状态

```bash
# 检查进程是否存在
ps aux | grep kube-controller-manager | grep -v grep

# systemd 管理的服务状态
systemctl status kube-controller-manager

# 静态 Pod 方式检查
crictl ps -a | grep kube-controller-manager

# 查看进程启动参数
cat /proc/$(pgrep kube-controller-manager)/cmdline | tr '\0' '\n'

# 检查健康端点
curl -k https://127.0.0.1:10257/healthz

# 查看详细健康状态
curl -k 'https://127.0.0.1:10257/healthz?verbose'
```

#### 2.3.2 第二步：检查 API Server 连接

```bash
# 查看 CM 日志中的连接错误
journalctl -u kube-controller-manager | grep -iE "(unable to connect|connection refused|error)" | tail -20

# 测试 kubeconfig 是否有效
kubectl --kubeconfig=/etc/kubernetes/controller-manager.conf get nodes

# 检查证书有效期
openssl x509 -in /etc/kubernetes/pki/controller-manager.crt -noout -dates 2>/dev/null

# 检查 API Server 可达性
curl -k https://<api-server-ip>:6443/healthz
```

#### 2.3.3 第三步：检查 Leader 选举

```bash
# 查看 Controller Manager Lease
kubectl get leases -n kube-system kube-controller-manager -o yaml

# 检查当前哪个 CM 是 Leader
kubectl get leases -n kube-system kube-controller-manager -o jsonpath='{.spec.holderIdentity}'

# 查看 CM 日志中的选举信息
journalctl -u kube-controller-manager | grep -iE "(became leader|acquired lease|lost lease)"

# 高可用场景：检查所有 CM 实例
for node in master-1 master-2 master-3; do
  echo "=== $node ==="
  ssh $node "crictl ps | grep kube-controller-manager"
done
```

#### 2.3.4 第四步：检查控制器状态

```bash
# 查看所有启用的控制器
curl -k https://127.0.0.1:10257/metrics | grep controller_manager_controller_started

# 检查各控制器工作队列深度
curl -k https://127.0.0.1:10257/metrics | grep workqueue_depth

# 检查控制器同步延迟
curl -k https://127.0.0.1:10257/metrics | grep workqueue_work_duration_seconds

# 检查控制器错误率
curl -k https://127.0.0.1:10257/metrics | grep workqueue_retries_total

# 查看 CM 日志中的控制器错误
journalctl -u kube-controller-manager | grep -iE "controller.*error" | tail -30

# 检查特定控制器
# Deployment Controller
kubectl get deployments -A -o wide
kubectl describe deployment <name> | grep -A20 Events

# ReplicaSet Controller
kubectl get rs -A
kubectl describe rs <name> | grep -A20 Events

# Endpoint Controller
kubectl get endpoints -A
kubectl describe endpoints <name>

# Node Controller
kubectl get nodes
kubectl describe node <name> | grep -A20 Conditions
```

#### 2.3.5 第五步：检查资源同步状态

```bash
# 检查 Deployment 是否正常同步
kubectl get deployments -A -o wide
# 检查 READY 列是否与 DESIRED 一致

# 检查 ReplicaSet 状态
kubectl get rs -A -o wide
# 检查 READY 是否与 DESIRED 一致

# 检查 Service Endpoints 是否更新
kubectl get endpoints -A
# 检查 ENDPOINTS 列是否有 IP

# 检查 Node Controller 是否正常
kubectl get nodes
# 检查 STATUS 列

# 检查 PVC 绑定状态
kubectl get pvc -A
# 检查 STATUS 是否为 Bound

# 检查命名空间删除状态
kubectl get ns
# 检查是否有长期 Terminating 的 NS
```

#### 2.3.6 第六步：检查性能和资源

```bash
# 检查 CM 资源使用
top -p $(pgrep kube-controller-manager) -b -n 1

# 检查内存使用
cat /proc/$(pgrep kube-controller-manager)/status | grep -E "(VmRSS|VmSize)"

# 检查文件描述符
ls /proc/$(pgrep kube-controller-manager)/fd | wc -l

# 检查 CM metrics 中的资源指标
curl -k https://127.0.0.1:10257/metrics | grep -E "process_resident_memory|process_cpu"

# 检查工作队列堆积
curl -k https://127.0.0.1:10257/metrics | grep workqueue_depth

# 检查 API 请求延迟
curl -k https://127.0.0.1:10257/metrics | grep rest_client_request_duration_seconds

# 检查 API 请求错误
curl -k https://127.0.0.1:10257/metrics | grep rest_client_requests_total | grep -v '="200"'
```

#### 2.3.7 第七步：检查日志

```bash
# 实时查看日志
journalctl -u kube-controller-manager -f --no-pager

# 查看最近的错误日志
journalctl -u kube-controller-manager -p err --since "1 hour ago"

# 静态 Pod 方式查看日志
crictl logs $(crictl ps -q --name kube-controller-manager) 2>&1 | tail -500

# 查找特定控制器错误
journalctl -u kube-controller-manager | grep -i "deployment" | tail -50
journalctl -u kube-controller-manager | grep -i "replicaset" | tail -50
journalctl -u kube-controller-manager | grep -i "endpoint" | tail -50
journalctl -u kube-controller-manager | grep -i "node" | tail -50

# 查找同步错误
journalctl -u kube-controller-manager | grep -iE "(sync.*error|failed to sync)" | tail -50
```

### 2.4 排查注意事项

#### 2.4.1 安全注意事项

| 注意项 | 说明 | 建议 |
|--------|------|------|
| **kubeconfig 安全** | CM 的 kubeconfig 有高权限 | 不要泄露 |
| **证书安全** | 证书用于 API Server 认证 | 妥善保管 |
| **云凭证** | CM 可能有云平台凭证 | 注意保密 |

#### 2.4.2 操作注意事项

| 注意项 | 说明 | 建议 |
|--------|------|------|
| **高可用场景** | 多 CM 实例需要 Leader 选举 | 确保只有一个 Leader |
| **控制器耦合** | 某些控制器相互依赖 | 全面检查 |
| **资源累积** | CM 故障可能导致资源累积 | 恢复后检查 |
| **日志级别** | 高日志级别会影响性能 | 调试完成后恢复 |

---

## 3. 解决方案与风险控制

### 3.1 Controller Manager 进程未运行

#### 3.1.1 解决步骤

```bash
# 步骤 1：检查启动失败原因
journalctl -u kube-controller-manager -b --no-pager | tail -100

# 步骤 2：检查配置文件语法
python3 -c "import yaml; yaml.safe_load(open('/etc/kubernetes/manifests/kube-controller-manager.yaml'))"

# 步骤 3：检查证书文件
ls -la /etc/kubernetes/pki/
ls -la /etc/kubernetes/controller-manager.conf

# 步骤 4：验证 kubeconfig
kubectl --kubeconfig=/etc/kubernetes/controller-manager.conf cluster-info

# 步骤 5：修复问题后重启
# systemd 方式
systemctl restart kube-controller-manager

# 静态 Pod 方式
mv /etc/kubernetes/manifests/kube-controller-manager.yaml /tmp/
sleep 5
mv /tmp/kube-controller-manager.yaml /etc/kubernetes/manifests/

# 步骤 6：验证恢复
kubectl get pods -n kube-system | grep controller-manager
curl -k https://127.0.0.1:10257/healthz
```

#### 3.1.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 重启期间控制循环中断 | 在维护窗口操作 |
| **低** | 配置检查一般无风险 | - |
| **中** | 配置修改可能引入新问题 | 修改前备份 |

#### 3.1.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. CM 不可用期间集群自愈能力丧失
2. 已运行的 Pod 不受直接影响
3. 高可用集群确保其他 CM 实例正常
4. 修改配置前备份原始文件
5. 恢复后检查各控制器是否正常工作
```

### 3.2 Deployment/ReplicaSet 控制器异常

#### 3.2.1 解决步骤

```bash
# 步骤 1：确认问题
kubectl get deployments -A -o wide
kubectl get rs -A -o wide

# 步骤 2：检查具体 Deployment 状态
kubectl describe deployment <name> -n <namespace>

# 步骤 3：查看 CM 日志中的相关错误
journalctl -u kube-controller-manager | grep -i "deployment\|replicaset" | tail -50

# 步骤 4：检查 API 请求是否被限流
curl -k https://127.0.0.1:10257/metrics | grep rest_client_requests_total

# 步骤 5：如果是限流问题，调整 CM 参数
# 修改 CM 启动参数：
# --kube-api-qps=50          # 默认 20
# --kube-api-burst=100       # 默认 30

# 步骤 6：手动触发同步（通过添加标签强制更新）
kubectl annotate deployment <name> -n <namespace> force-sync=$(date +%s)

# 步骤 7：验证恢复
kubectl rollout status deployment <name> -n <namespace>
```

#### 3.2.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **低** | 增加 API QPS 可能增加 API Server 负载 | 监控 API Server |
| **低** | 手动触发同步一般无风险 | 仅用于诊断 |
| **中** | 参数修改需要重启 | 在维护窗口操作 |

#### 3.2.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. Deployment 控制器异常会影响应用滚动更新
2. 增加 API QPS 需要评估 API Server 承载能力
3. 手动 annotate 不会影响实际应用
4. 检查是否有大量 Deployment 同时更新导致负载过高
5. 考虑分批滚动更新减少峰值负载
```

### 3.3 Endpoints 控制器异常

#### 3.3.1 解决步骤

```bash
# 步骤 1：确认问题
kubectl get endpoints -A
# 检查是否有 Service 的 Endpoints 为空

# 步骤 2：检查 Service 和 Pod 标签匹配
kubectl get svc <name> -o yaml | grep -A5 selector
kubectl get pods -l <selector-key>=<selector-value>

# 步骤 3：查看 CM 日志中的 Endpoints 错误
journalctl -u kube-controller-manager | grep -i "endpoint" | tail -50

# 步骤 4：检查 Pod 是否 Ready
kubectl get pods -o wide
kubectl describe pod <name> | grep -A5 Conditions

# 步骤 5：手动检查 Endpoints 对象
kubectl get endpoints <service-name> -o yaml

# 步骤 6：强制重建 Endpoints
# 方法 1：重启关联的 Pod
kubectl rollout restart deployment <name>

# 方法 2：删除并重建 Service
kubectl delete svc <name>
kubectl apply -f <service-yaml>

# 步骤 7：验证恢复
kubectl get endpoints <service-name>
```

#### 3.3.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 重启 Pod 会导致短暂服务中断 | 在维护窗口操作 |
| **高** | 删除 Service 会导致服务不可用 | 确保有 YAML 可恢复 |
| **低** | 查看日志和状态无风险 | - |

#### 3.3.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. Endpoints 为空会导致服务无法访问
2. 删除 Service 前确保有配置备份
3. 检查 Service selector 是否正确匹配 Pod
4. 使用 EndpointSlice（v1.21+）可能有不同表现
5. 考虑使用 headless Service 排除 Endpoints Controller 问题
```

### 3.4 Node Controller 异常

#### 3.4.1 解决步骤

```bash
# 步骤 1：确认问题
kubectl get nodes
# 检查是否有节点长期处于 NotReady 状态

# 步骤 2：检查 CM 日志中的 Node Controller 错误
journalctl -u kube-controller-manager | grep -i "node" | tail -50

# 步骤 3：检查 Node Controller 参数
# 查看当前配置
cat /etc/kubernetes/manifests/kube-controller-manager.yaml | grep -E "node-monitor|pod-eviction"

# 步骤 4：检查节点上的 kubelet 状态
ssh <node-ip> "systemctl status kubelet"
ssh <node-ip> "journalctl -u kubelet --since '10 minutes ago' | tail -50"

# 步骤 5：调整 Node Controller 参数（如果容忍度过低）
# 修改 CM 启动参数：
# --node-monitor-period=5s           # 默认 5s
# --node-monitor-grace-period=40s    # 默认 40s
# --pod-eviction-timeout=5m0s        # 默认 5m0s

# 步骤 6：手动更新节点状态（测试用）
kubectl cordon <node-name>
kubectl uncordon <node-name>

# 步骤 7：验证恢复
kubectl get nodes
```

#### 3.4.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 调整监控周期可能延迟故障检测 | 根据网络质量调整 |
| **中** | cordon/uncordon 会影响调度 | 仅用于诊断 |
| **低** | 查看日志无风险 | - |

#### 3.4.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. Node Controller 异常会延迟节点故障检测
2. Pod 驱逐超时过短可能导致不必要的驱逐
3. 网络不稳定时考虑增加 grace-period
4. 检查节点 kubelet 是否正常是首要步骤
5. 大规模节点 NotReady 可能是网络问题而非 CM 问题
```

### 3.5 Namespace 无法删除

#### 3.5.1 解决步骤

```bash
# 步骤 1：确认问题
kubectl get ns
# 检查是否有 Terminating 状态的 namespace

# 步骤 2：检查 namespace 中的资源
kubectl get all -n <namespace>
kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get -n <namespace>

# 步骤 3：检查 finalizers
kubectl get ns <namespace> -o yaml | grep -A5 finalizers

# 步骤 4：查看 CM 日志中的 Namespace Controller 错误
journalctl -u kube-controller-manager | grep -i "namespace" | tail -50

# 步骤 5：强制删除（移除 finalizers）
# ⚠️ 警告：这可能导致资源泄露
kubectl get ns <namespace> -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/<namespace>/finalize" -f -

# 步骤 6：验证删除
kubectl get ns <namespace>

# 步骤 7：清理可能遗留的资源
kubectl get all -A | grep <namespace>
```

#### 3.5.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **高** | 强制删除可能导致资源泄露 | 先尝试正常删除资源 |
| **中** | 遗留的 CRD 资源可能影响后续使用 | 检查并清理 CRD 资源 |
| **低** | 查看 finalizers 无风险 | - |

#### 3.5.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 移除 finalizers 是最后手段，可能导致资源泄露
2. 先检查是否有 webhook 阻止删除
3. 检查是否有 CRD 资源未被删除
4. 云资源（如 LoadBalancer）可能需要手动清理
5. 记录强制删除的 namespace 用于后续检查
```

### 3.6 PersistentVolume Controller 异常

#### 3.6.1 解决步骤

```bash
# 步骤 1：确认问题
kubectl get pv
kubectl get pvc -A
# 检查是否有 PVC 长期处于 Pending 状态

# 步骤 2：检查 PVC 详情
kubectl describe pvc <name> -n <namespace>
# 查看 Events 中的错误信息

# 步骤 3：检查 StorageClass
kubectl get sc
kubectl describe sc <name>

# 步骤 4：查看 CM 日志中的 PV Controller 错误
journalctl -u kube-controller-manager | grep -i "persistentvolume" | tail -50

# 步骤 5：检查 CSI 驱动状态（如使用 CSI）
kubectl get pods -n kube-system | grep csi

# 步骤 6：手动创建 PV（如果自动配置失败）
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: manual-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: <storage-class>
  # ... 具体存储配置
EOF

# 步骤 7：验证绑定
kubectl get pvc <name> -n <namespace>
```

#### 3.6.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 手动创建 PV 可能与自动配置冲突 | 确认 StorageClass 配置 |
| **低** | 查看状态和日志无风险 | - |
| **中** | CSI 驱动问题可能需要深入排查 | 查看 CSI 驱动文档 |

#### 3.6.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. PV/PVC 绑定失败会导致 Pod 无法启动
2. 检查云厂商存储配额和权限
3. StorageClass 配置错误是常见原因
4. CSI 驱动需要正确的 RBAC 权限
5. 生产环境建议使用自动存储配置
```

### 3.7 Controller Manager 性能优化

#### 3.7.1 解决步骤

```bash
# 步骤 1：确认性能问题
curl -k https://127.0.0.1:10257/metrics | grep workqueue_depth
curl -k https://127.0.0.1:10257/metrics | grep workqueue_work_duration_seconds

# 步骤 2：检查资源使用
top -p $(pgrep kube-controller-manager) -b -n 1

# 步骤 3：优化 CM 参数
# 修改启动参数：
# --kube-api-qps=50                 # 增加 API 请求速率
# --kube-api-burst=100              # 增加 burst 限制
# --concurrent-deployment-syncs=10  # 增加并发同步数
# --concurrent-replicaset-syncs=10
# --concurrent-endpoint-syncs=10
# --concurrent-service-syncs=5
# --concurrent-gc-syncs=30

# 步骤 4：调整资源限制（静态 Pod 方式）
# 在 manifest 中增加 resources 配置
# resources:
#   requests:
#     cpu: "200m"
#     memory: "512Mi"
#   limits:
#     cpu: "2000m"
#     memory: "2Gi"

# 步骤 5：重启 CM 应用配置
mv /etc/kubernetes/manifests/kube-controller-manager.yaml /tmp/
sleep 5
mv /tmp/kube-controller-manager.yaml /etc/kubernetes/manifests/

# 步骤 6：验证性能改善
curl -k https://127.0.0.1:10257/metrics | grep workqueue_depth
```

#### 3.7.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 增加并发可能增加 API Server 负载 | 监控 API Server |
| **中** | 资源限制变更需要重启 | 在维护窗口操作 |
| **低** | 查看指标无风险 | - |

#### 3.7.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 增加并发数需要评估 API Server 承载能力
2. 大规模集群（1000+ 节点）需要仔细调优
3. 监控 CM 内存使用，避免 OOM
4. 调整参数后观察至少 1 小时
5. 保留原始配置用于回滚
```

---

## 附录

### A. Controller Manager 关键指标

| 指标名称 | 说明 | 告警阈值建议 |
|----------|------|--------------|
| `workqueue_depth` | 工作队列深度 | > 100 |
| `workqueue_work_duration_seconds` | 处理时长 | P99 > 1s |
| `workqueue_retries_total` | 重试次数 | 异常增长 |
| `rest_client_requests_total` | API 请求数 | 错误率 > 1% |
| `process_resident_memory_bytes` | 内存使用 | > 2GB |

### B. 常见启动参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--controllers` | * | 启用的控制器列表 |
| `--kube-api-qps` | 20 | API 请求速率限制 |
| `--kube-api-burst` | 30 | API 请求 burst 限制 |
| `--concurrent-deployment-syncs` | 5 | Deployment 并发同步数 |
| `--node-monitor-period` | 5s | 节点监控周期 |
| `--node-monitor-grace-period` | 40s | 节点不健康容忍时间 |
| `--pod-eviction-timeout` | 5m | Pod 驱逐超时时间 |

### C. 控制器列表参考

```bash
# 查看所有可用控制器
kube-controller-manager --controllers=* --help 2>&1 | grep -A100 "controllers"

# 常见控制器
# - deployment
# - replicaset
# - daemonset
# - statefulset
# - job
# - cronjob
# - endpoint
# - endpointslice
# - namespace
# - node
# - persistentvolume-binder
# - persistentvolume-expander
# - serviceaccount
# - serviceaccount-token
# - garbagecollector
# - resourcequota
```
