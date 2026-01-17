# 表格27: 节点管理与维护

## 节点生命周期状态

| 状态 | Condition | 描述 | 处理策略 |
|-----|-----------|------|---------|
| Ready | Ready=True | 节点健康可调度 | 正常运行 |
| NotReady | Ready=False | 节点不健康 | 检查kubelet/网络 |
| Unknown | Ready=Unknown | 状态未知 | 检查节点连接 |
| MemoryPressure | MemoryPressure=True | 内存压力 | 驱逐低优先级Pod |
| DiskPressure | DiskPressure=True | 磁盘压力 | 清理镜像/日志 |
| PIDPressure | PIDPressure=True | PID耗尽 | 清理进程 |
| NetworkUnavailable | NetworkUnavailable=True | 网络未就绪 | 检查CNI |

## 节点污点(Taint)管理

| 污点键 | Effect | 场景 | 命令 |
|-------|--------|------|------|
| `node.kubernetes.io/not-ready` | NoExecute | 节点未就绪 | 系统自动添加 |
| `node.kubernetes.io/unreachable` | NoExecute | 节点不可达 | 系统自动添加 |
| `node.kubernetes.io/memory-pressure` | NoSchedule | 内存压力 | 系统自动添加 |
| `node.kubernetes.io/disk-pressure` | NoSchedule | 磁盘压力 | 系统自动添加 |
| `node.kubernetes.io/pid-pressure` | NoSchedule | PID压力 | 系统自动添加 |
| `node.kubernetes.io/unschedulable` | NoSchedule | 禁止调度 | `kubectl cordon` |
| `node-role.kubernetes.io/control-plane` | NoSchedule | 控制平面节点 | kubeadm自动添加 |

## 节点维护操作

| 操作 | 命令 | 说明 | 注意事项 |
|-----|------|------|---------|
| 禁止调度 | `kubectl cordon <node>` | 标记不可调度 | 已有Pod不受影响 |
| 恢复调度 | `kubectl uncordon <node>` | 恢复可调度 | - |
| 驱逐Pod | `kubectl drain <node>` | 安全迁移Pod | 需配合PDB使用 |
| 强制驱逐 | `kubectl drain --force --ignore-daemonsets` | 强制迁移 | 可能导致数据丢失 |
| 删除节点 | `kubectl delete node <node>` | 从集群移除 | 先drain |
| 查看详情 | `kubectl describe node <node>` | 查看节点信息 | 包含事件和条件 |

## drain命令参数

| 参数 | 默认值 | 说明 |
|-----|-------|------|
| `--ignore-daemonsets` | false | 忽略DaemonSet管理的Pod |
| `--delete-emptydir-data` | false | 删除emptyDir数据 |
| `--force` | false | 强制删除无控制器的Pod |
| `--grace-period` | -1 | 优雅终止等待时间 |
| `--timeout` | 0 | 操作超时时间 |
| `--pod-selector` | "" | 仅驱逐匹配的Pod |
| `--disable-eviction` | false | 使用删除而非驱逐API |

## 节点资源配置

| 资源类型 | kubelet参数 | 默认值 | 推荐值 | 说明 |
|---------|------------|-------|-------|------|
| 系统预留 | `--system-reserved` | - | cpu=500m,memory=1Gi | 系统进程预留 |
| K8s预留 | `--kube-reserved` | - | cpu=500m,memory=1Gi | K8s组件预留 |
| 驱逐阈值 | `--eviction-hard` | memory<100Mi | memory<500Mi | 硬驱逐阈值 |
| 软驱逐 | `--eviction-soft` | - | memory<1Gi | 软驱逐阈值 |
| 软驱逐宽限期 | `--eviction-soft-grace-period` | - | memory=2m | 宽限期 |
| 最小回收 | `--eviction-minimum-reclaim` | - | memory=500Mi | 最小回收量 |

## 节点标签规范

| 标签键 | 示例值 | 用途 |
|-------|-------|------|
| `kubernetes.io/hostname` | node-1 | 主机名(系统) |
| `kubernetes.io/os` | linux | 操作系统(系统) |
| `kubernetes.io/arch` | amd64 | CPU架构(系统) |
| `topology.kubernetes.io/zone` | cn-hangzhou-h | 可用区(ACK自动) |
| `topology.kubernetes.io/region` | cn-hangzhou | 地域(ACK自动) |
| `node.kubernetes.io/instance-type` | ecs.g6.xlarge | 实例规格(ACK自动) |
| `workload-type` | compute/memory/gpu | 工作负载类型(自定义) |
| `environment` | production/staging | 环境标识(自定义) |

## 节点问题检测器(NPD)

| 检测类型 | 条件名称 | 检测内容 | ACK默认 |
|---------|---------|---------|--------|
| 内核死锁 | KernelDeadlock | 内核死锁检测 | ✅ |
| OOM | OOMKilling | OOM事件 | ✅ |
| 磁盘IO | IOError | 磁盘IO错误 | ✅ |
| 文件系统 | FilesystemCorruption | 文件系统损坏 | ✅ |
| 容器运行时 | ContainerRuntimeUnhealthy | CRI健康 | ✅ |
| 时钟同步 | ClockSkew | NTP同步 | ✅ |
| 网络 | NetworkUnavailable | 网络连通性 | ✅ |

## ACK节点池管理

| 功能 | 说明 | 配置方式 |
|-----|------|---------|
| 节点池 | 同配置节点组 | 控制台/CLI |
| 弹性伸缩 | 基于负载自动扩缩 | cluster-autoscaler |
| 抢占式实例 | 低成本实例 | 节点池配置 |
| 定期维护 | 自动排空更新 | 维护窗口配置 |
| 节点镜像 | 自定义OS镜像 | 节点池配置 |
| 安全组 | 节点网络隔离 | 节点池配置 |

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| v1.25 | Taint-based eviction默认启用 |
| v1.26 | PodDisruptionConditions默认启用 |
| v1.27 | 节点swap支持Beta |
| v1.28 | Sidecar容器原生支持 |
| v1.29 | 节点优雅关机改进 |
| v1.30 | 用户命名空间支持改进 |
