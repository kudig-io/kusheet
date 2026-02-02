# 节点故障专项排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 高级
>
> **版本说明**:
> - v1.25+ 支持 PodDisruptionConditions 特性
> - v1.26+ GracefulNodeShutdown 默认启用
> - v1.28+ SidecarContainers 支持优雅终止

## 概述

Kubernetes 节点是运行 Pod 的基础设施，节点问题会直接影响其上所有工作负载。本文档覆盖节点资源压力、亲和性调度、污点容忍、节点生命周期等故障的诊断与解决方案。

---

## 第一部分：问题现象与影响分析

### 1.1 节点状态与条件

```
┌─────────────────────────────────────────────────────────────────┐
│                      节点状态条件                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Node Conditions                        │   │
│  ├────────────────────┬─────────────────────────────────────┤   │
│  │ Ready              │ kubelet 正常，可调度 Pod            │   │
│  │ MemoryPressure     │ 节点内存不足                        │   │
│  │ DiskPressure       │ 节点磁盘空间不足                    │   │
│  │ PIDPressure        │ 节点 PID 数量不足                   │   │
│  │ NetworkUnavailable │ 节点网络配置不正确                   │   │
│  └────────────────────┴─────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Node Taints                            │   │
│  ├────────────────────────────────────────────────────────────┤  │
│  │ 系统自动添加:                                              │   │
│  │ - node.kubernetes.io/not-ready                            │   │
│  │ - node.kubernetes.io/unreachable                          │   │
│  │ - node.kubernetes.io/memory-pressure                      │   │
│  │ - node.kubernetes.io/disk-pressure                        │   │
│  │ - node.kubernetes.io/pid-pressure                         │   │
│  │ - node.kubernetes.io/network-unavailable                  │   │
│  │ - node.kubernetes.io/unschedulable                        │   │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 可能原因 | 查看方式 |
|---------|---------|---------|---------|
| 节点 NotReady | 节点状态不正常 | kubelet 故障/网络问题/资源压力 | `kubectl get nodes` |
| 内存压力 | MemoryPressure=True | 内存使用过高/泄漏 | `kubectl describe node` |
| 磁盘压力 | DiskPressure=True | 磁盘空间不足/inode 耗尽 | `kubectl describe node` |
| PID 压力 | PIDPressure=True | 进程数过多 | `kubectl describe node` |
| Pod 无法调度 | Pod Pending | 污点/亲和性/资源不足 | `kubectl describe pod` |
| Pod 被驱逐 | Pod Evicted | 节点资源压力 | `kubectl get pods` |
| 节点不可调度 | SchedulingDisabled | 节点被 cordon | `kubectl get nodes` |

### 1.3 影响分析

| 故障类型 | 直接影响 | 间接影响 | 影响范围 |
|---------|---------|---------|---------|
| 节点 NotReady | 节点上 Pod 状态未知 | 服务可用性下降 | 单节点所有 Pod |
| 资源压力 | Pod 被驱逐 | 服务中断，数据可能丢失 | 单节点优先级低的 Pod |
| 网络不可用 | Pod 无法通信 | Service 不可达 | 单节点所有 Pod |
| 多节点故障 | 大量 Pod 不可用 | 服务完全中断 | 受影响节点上的所有服务 |

---

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
节点故障
    │
    ├─── 节点 NotReady？
    │         │
    │         ├─ kubelet 状态 ──→ systemctl status kubelet
    │         ├─ 容器运行时 ──→ systemctl status containerd
    │         ├─ 网络问题 ──→ 检查节点网络连通性
    │         └─ 资源压力 ──→ 检查 Conditions
    │
    ├─── 资源压力？
    │         │
    │         ├─ MemoryPressure ──→ 检查内存使用/OOM
    │         ├─ DiskPressure ──→ 检查磁盘/inode
    │         └─ PIDPressure ──→ 检查进程数
    │
    ├─── Pod 无法调度？
    │         │
    │         ├─ 污点问题 ──→ 检查节点污点和 Pod 容忍
    │         ├─ 亲和性问题 ──→ 检查节点标签和亲和性规则
    │         ├─ 资源不足 ──→ 检查可用资源
    │         └─ 拓扑约束 ──→ 检查 topologySpreadConstraints
    │
    └─── Pod 被驱逐？
              │
              ├─ 优先级 ──→ 检查 PriorityClass
              ├─ QoS 类别 ──→ 检查资源配置
              └─ 驱逐策略 ──→ 检查 kubelet 配置
```

### 2.2 排查命令集

#### 2.2.1 节点状态检查

```bash
# 查看所有节点状态
kubectl get nodes -o wide

# 查看节点详细信息
kubectl describe node <node-name>

# 查看节点条件
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.status=="True")].type}{"\n"}{end}'

# 查看节点资源使用
kubectl top nodes

# 查看节点上的 Pod
kubectl get pods --all-namespaces --field-selector spec.nodeName=<node-name>

# 查看节点标签
kubectl get nodes --show-labels

# 查看节点污点
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

#### 2.2.2 资源压力检查

```bash
# 内存使用详情
kubectl describe node <node-name> | grep -A5 "Allocated resources"

# SSH 到节点检查
ssh <node>

# 内存使用
free -h
cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached"

# 磁盘使用
df -h
df -i  # inode 使用

# 进程数
ps aux | wc -l
cat /proc/sys/kernel/pid_max

# 检查 OOM 事件
dmesg | grep -i "oom\|out of memory"
journalctl -k | grep -i oom

# kubelet 资源预留配置
cat /var/lib/kubelet/config.yaml | grep -A10 "eviction\|system"
```

#### 2.2.3 调度相关检查

```bash
# 检查节点可调度性
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.unschedulable}{"\n"}{end}'

# 检查节点污点
kubectl describe node <node-name> | grep -A10 Taints

# 检查节点标签
kubectl get node <node-name> -o jsonpath='{.metadata.labels}' | jq

# 检查节点资源容量和可分配
kubectl describe node <node-name> | grep -A15 "Capacity:\|Allocatable:"

# 检查 Pod 的 nodeSelector
kubectl get pod <pod-name> -o jsonpath='{.spec.nodeSelector}'

# 检查 Pod 的亲和性
kubectl get pod <pod-name> -o jsonpath='{.spec.affinity}' | jq

# 检查 Pod 的容忍
kubectl get pod <pod-name> -o jsonpath='{.spec.tolerations}' | jq
```

#### 2.2.4 驱逐相关检查

```bash
# 查看被驱逐的 Pod
kubectl get pods --all-namespaces --field-selector=status.phase=Failed | grep Evicted

# 查看驱逐事件
kubectl get events --field-selector reason=Evicted

# 检查 kubelet 驱逐配置
cat /var/lib/kubelet/config.yaml | grep -A20 eviction
```

### 2.3 排查注意事项

| 注意事项 | 说明 |
|---------|-----|
| NotReady 超时 | 默认 40s 后节点标记为 NotReady |
| 驱逐保护 | 设置 PodDisruptionBudget 防止过度驱逐 |
| 系统预留 | kubelet 应配置 system-reserved 和 kube-reserved |
| 软驱逐/硬驱逐 | 软驱逐有宽限期，硬驱逐立即执行 |
| 优先级驱逐 | 低优先级 Pod 先被驱逐 |

---

## 第三部分：解决方案与风险控制

### 3.1 节点 NotReady 问题

#### 场景 1：kubelet 服务异常

**解决步骤：**

```bash
# 1. SSH 到节点检查 kubelet 状态
systemctl status kubelet

# 2. 查看 kubelet 日志
journalctl -u kubelet -n 100 --no-pager
journalctl -u kubelet -f  # 实时查看

# 3. 常见问题及解决

# 问题 A: kubelet 配置错误
cat /var/lib/kubelet/config.yaml
# 修复配置后重启
systemctl restart kubelet

# 问题 B: 证书过期
ls -la /var/lib/kubelet/pki/
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -enddate
# 重新加入集群或手动更新证书

# 问题 C: 磁盘空间不足
df -h
# 清理空间
crictl rmi --prune
docker system prune -af  # 如果使用 Docker
journalctl --vacuum-size=500M

# 4. 重启 kubelet
systemctl restart kubelet

# 5. 验证节点状态
kubectl get node <node-name> -w
```

#### 场景 2：网络不可达

**解决步骤：**

```bash
# 1. 检查节点网络
ping <master-ip>
nc -zv <master-ip> 6443

# 2. 检查防火墙规则
iptables -L -n
firewall-cmd --list-all

# 3. 检查 CNI 状态
ls /etc/cni/net.d/
ls /opt/cni/bin/
kubectl get pods -n kube-system -l k8s-app=calico-node -o wide

# 4. 重启网络组件
systemctl restart NetworkManager
# 或重启 CNI Pod
kubectl delete pod -n kube-system -l k8s-app=calico-node --field-selector spec.nodeName=<node>
```

### 3.2 资源压力问题

#### 场景 1：内存压力 (MemoryPressure)

**问题现象：**
```bash
$ kubectl describe node <node>
Conditions:
  MemoryPressure   True
```

**解决步骤：**

```bash
# 1. 检查内存使用
kubectl top pods --all-namespaces --sort-by=memory | head -20

# 2. 在节点上检查
ssh <node>
free -h
ps aux --sort=-%mem | head -20

# 3. 找出内存占用高的 Pod
kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.nodeName=="<node>") | "\(.metadata.namespace)/\(.metadata.name)"'

# 4. 解决方案

# 方案 A: 驱逐低优先级 Pod
kubectl delete pod <pod-name> -n <namespace>

# 方案 B: 调整 Pod 内存限制
kubectl patch deployment <name> --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "512Mi"}
]'

# 方案 C: 清理系统缓存 (临时)
sync; echo 3 > /proc/sys/vm/drop_caches

# 方案 D: 调整 kubelet 驱逐阈值
# /var/lib/kubelet/config.yaml
# evictionHard:
#   memory.available: "500Mi"
# evictionSoft:
#   memory.available: "1Gi"
# evictionSoftGracePeriod:
#   memory.available: "1m"

systemctl restart kubelet
```

#### 场景 2：磁盘压力 (DiskPressure)

**解决步骤：**

```bash
# 1. 检查磁盘使用
df -h
df -i  # inode

# 2. 找出大文件/目录
du -sh /var/log/*
du -sh /var/lib/docker/*  # Docker
du -sh /var/lib/containerd/*  # containerd

# 3. 清理方案

# 清理容器日志
find /var/log/containers -name "*.log" -mtime +7 -delete
truncate -s 0 /var/log/containers/*.log

# 清理未使用的镜像
crictl rmi --prune
# 或
docker system prune -af

# 清理已完成的容器
crictl rm $(crictl ps -a -q --state exited)

# 清理系统日志
journalctl --vacuum-size=500M
journalctl --vacuum-time=7d

# 4. 调整 kubelet 驱逐阈值
# evictionHard:
#   imagefs.available: "15%"
#   nodefs.available: "10%"

# 5. 配置镜像垃圾回收
# imageGCHighThresholdPercent: 85
# imageGCLowThresholdPercent: 80
```

#### 场景 3：PID 压力 (PIDPressure)

**解决步骤：**

```bash
# 1. 检查 PID 使用
cat /proc/sys/kernel/pid_max
ps aux | wc -l

# 2. 找出进程数多的应用
ps aux --sort=-nlwp | head -20

# 3. 检查容器进程
for container in $(crictl ps -q); do
  echo "Container $container: $(crictl exec $container ps aux 2>/dev/null | wc -l) processes"
done

# 4. 增加系统 PID 限制 (临时)
echo 65536 > /proc/sys/kernel/pid_max

# 5. 永久修改
echo "kernel.pid_max = 65536" >> /etc/sysctl.conf
sysctl -p

# 6. 调整 kubelet 配置
# podPidsLimit: 4096  # 每个 Pod 最大 PID 数
```

### 3.3 调度问题

#### 场景 1：污点阻止调度

**问题现象：**
```
Events:
  Warning  FailedScheduling  0/3 nodes are available: 3 node(s) had taints that the pod didn't tolerate
```

**解决步骤：**

```bash
# 1. 查看节点污点
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# 2. 查看具体节点污点
kubectl describe node <node> | grep -A5 Taints

# 3. 方案 A: 为 Pod 添加容忍
kubectl patch deployment <name> --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/tolerations", "value": [
    {"key": "node-type", "operator": "Equal", "value": "special", "effect": "NoSchedule"}
  ]}
]'

# 4. 方案 B: 移除节点污点
kubectl taint nodes <node> key:NoSchedule-

# 5. 常见污点容忍配置
# tolerations:
# - key: "node-role.kubernetes.io/master"
#   operator: "Exists"
#   effect: "NoSchedule"
# - key: "node.kubernetes.io/not-ready"
#   operator: "Exists"
#   effect: "NoExecute"
#   tolerationSeconds: 300
```

#### 场景 2：亲和性导致无法调度

**问题现象：**
```
Events:
  Warning  FailedScheduling  0/3 nodes are available: 3 node(s) didn't match Pod's node affinity/selector
```

**解决步骤：**

```bash
# 1. 查看 Pod 的 nodeSelector
kubectl get pod <pod-name> -o jsonpath='{.spec.nodeSelector}'

# 2. 查看 Pod 的 nodeAffinity
kubectl get pod <pod-name> -o jsonpath='{.spec.affinity.nodeAffinity}' | jq

# 3. 查看节点标签
kubectl get nodes --show-labels

# 4. 方案 A: 为节点添加所需标签
kubectl label nodes <node> <key>=<value>

# 5. 方案 B: 修改 Pod 的 nodeSelector
kubectl patch deployment <name> --type='json' -p='[
  {"op": "remove", "path": "/spec/template/spec/nodeSelector"}
]'

# 6. 方案 C: 使用软亲和性 (preferredDuringScheduling)
# 而非硬亲和性 (requiredDuringScheduling)
```

#### 场景 3：拓扑分布约束导致无法调度

**问题现象：**
```
Events:
  Warning  FailedScheduling  doesn't satisfy spreadConstraint
```

**解决步骤：**

```bash
# 1. 查看 Pod 的拓扑约束
kubectl get pod <pod-name> -o jsonpath='{.spec.topologySpreadConstraints}' | jq

# 2. 检查节点拓扑标签
kubectl get nodes -L topology.kubernetes.io/zone

# 3. 调整约束配置
# topologySpreadConstraints:
# - maxSkew: 1
#   topologyKey: topology.kubernetes.io/zone
#   whenUnsatisfiable: ScheduleAnyway  # 改为软约束
#   labelSelector:
#     matchLabels:
#       app: myapp
```

### 3.4 节点维护操作

#### 场景 1：安全地维护节点

```bash
# 1. 标记节点不可调度
kubectl cordon <node>

# 2. 驱逐节点上的 Pod (优雅)
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

# 3. 如果有不可驱逐的 Pod
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --force

# 4. 执行维护操作
# ...

# 5. 恢复节点
kubectl uncordon <node>

# 6. 验证
kubectl get nodes
kubectl get pods -o wide | grep <node>
```

#### 场景 2：处理节点故障

```bash
# 1. 如果节点永久故障，删除节点
kubectl delete node <node>

# 2. Pod 会被重新调度 (如果有副本控制器)
kubectl get pods -o wide

# 3. 强制删除卡在故障节点的 Pod
kubectl delete pod <pod-name> --force --grace-period=0

# 4. 如果节点恢复，重新加入集群
kubeadm token create --print-join-command
# 在节点上执行 join 命令
```

### 3.5 完整的节点调度配置示例

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  template:
    spec:
      # 节点选择器 (简单匹配)
      nodeSelector:
        node-type: worker
        disk: ssd
      
      # 节点亲和性 (复杂规则)
      affinity:
        nodeAffinity:
          # 硬亲和性: 必须满足
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values:
                - amd64
          # 软亲和性: 优先满足
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: zone
                operator: In
                values:
                - zone-a
        
        # Pod 反亲和性: 分散部署
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: myapp
              topologyKey: kubernetes.io/hostname
      
      # 拓扑分布约束
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: myapp
      
      # 污点容忍
      tolerations:
      - key: "node-role.kubernetes.io/master"
        operator: "Exists"
        effect: "NoSchedule"
      - key: "node.kubernetes.io/not-ready"
        operator: "Exists"
        effect: "NoExecute"
        tolerationSeconds: 300
      - key: "node.kubernetes.io/unreachable"
        operator: "Exists"
        effect: "NoExecute"
        tolerationSeconds: 300
      
      containers:
      - name: app
        image: myapp:v1
```

---

### 3.6 节点健康检查脚本

```bash
#!/bin/bash
# 节点健康检查脚本

echo "=== Kubernetes Node Health Check ==="

# 检查节点状态
echo -e "\n--- Node Status ---"
kubectl get nodes -o wide

# 检查节点条件
echo -e "\n--- Node Conditions ---"
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.status=="True")].type}{"\n"}{end}'

# 检查资源使用
echo -e "\n--- Node Resources ---"
kubectl top nodes

# 检查节点污点
echo -e "\n--- Node Taints ---"
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# 检查不可调度节点
echo -e "\n--- Unschedulable Nodes ---"
kubectl get nodes -o jsonpath='{range .items[?(@.spec.unschedulable==true)]}{.metadata.name}{"\n"}{end}'

# 检查被驱逐的 Pod
echo -e "\n--- Evicted Pods ---"
kubectl get pods --all-namespaces --field-selector=status.phase=Failed | grep Evicted | head -10

echo -e "\n=== Check Complete ==="
```

---

### 3.7 安全生产风险提示

| 操作 | 风险等级 | 风险说明 | 建议 |
|-----|---------|---------|-----|
| kubectl drain | 中 | Pod 被驱逐，服务短暂中断 | 确保有足够副本，设置 PDB |
| kubectl delete node | 高 | 节点上 Pod 变为 Terminating | 先 drain，确保 Pod 已迁移 |
| 移除污点 | 中 | 可能导致大量 Pod 调度到节点 | 评估节点容量 |
| 修改 kubelet 配置 | 中 | 需要重启 kubelet | 低峰期操作 |
| 强制驱逐 | 高 | 数据可能丢失 | 仅在必要时使用 |
| 清理系统缓存 | 低 | 短暂性能下降 | 监控系统状态 |

---

## 附录

### 常用命令速查

```bash
# 节点状态
kubectl get nodes -o wide
kubectl describe node <node>
kubectl top nodes

# 污点管理
kubectl taint nodes <node> key=value:NoSchedule
kubectl taint nodes <node> key:NoSchedule-

# 标签管理
kubectl label nodes <node> key=value
kubectl label nodes <node> key-

# 维护操作
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets
kubectl uncordon <node>

# 资源检查
kubectl describe node <node> | grep -A15 "Allocated resources"
kubectl get pods --field-selector spec.nodeName=<node>
```

### 相关文档

- [kubelet 故障排查](./01-kubelet-troubleshooting.md)
- [Scheduler 故障排查](../01-control-plane/03-scheduler-troubleshooting.md)
- [资源配额故障排查](../07-resources-scheduling/01-resources-quota-troubleshooting.md)
- [Pod 故障排查](../05-workloads/01-pod-troubleshooting.md)
