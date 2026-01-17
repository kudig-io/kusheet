# 表格6：配置参数表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/reference/command-line-tools-reference](https://kubernetes.io/docs/reference/command-line-tools-reference/)

## kube-apiserver 关键参数

| 参数 | 默认值 | 推荐生产值 | 版本变更 | 说明 | 安全/性能影响 |
|-----|-------|----------|---------|------|--------------|
| `--etcd-servers` | 无 | etcd集群地址 | 稳定 | etcd端点列表 | 必须配置；多节点逗号分隔 |
| `--service-cluster-ip-range` | 10.0.0.0/24 | 根据规模调整 | 稳定 | Service IP范围 | 不能与Pod/Node CIDR重叠 |
| `--service-node-port-range` | 30000-32767 | 默认或扩展 | 稳定 | NodePort范围 | 避免与系统端口冲突 |
| `--max-requests-inflight` | 400 | 800-1600 | 稳定 | 最大非变更并发请求 | 大集群需增加 |
| `--max-mutating-requests-inflight` | 200 | 400-800 | 稳定 | 最大变更并发请求 | 大集群需增加 |
| `--authorization-mode` | AlwaysAllow | RBAC,Node | 稳定 | 授权模式 | 生产必须启用RBAC |
| `--enable-admission-plugins` | 默认列表 | 添加所需插件 | v1.30 CEL GA | 启用准入插件 | 根据安全需求配置 |
| `--audit-log-path` | 无 | /var/log/audit.log | v1.29增强 | 审计日志路径 | 生产必须启用 |
| `--audit-log-maxage` | 0 | 30 | 稳定 | 审计日志保留天数 | 合规要求 |
| `--audit-log-maxbackup` | 0 | 10 | 稳定 | 审计日志备份数 | 存储管理 |
| `--audit-log-maxsize` | 0 | 100 | 稳定 | 单个日志文件MB | 防止磁盘满 |
| `--encryption-provider-config` | 无 | 配置文件路径 | 稳定 | etcd加密配置 | 敏感数据加密 |
| `--tls-cert-file` | 无 | 证书路径 | 稳定 | TLS证书 | 安全必需 |
| `--tls-private-key-file` | 无 | 私钥路径 | 稳定 | TLS私钥 | 安全必需 |
| `--anonymous-auth` | true | false | 稳定 | 匿名认证 | 生产应禁用 |
| `--profiling` | true | false | 稳定 | 性能分析端点 | 生产应禁用 |
| `--feature-gates` | 默认 | 按需启用 | 每版本更新 | 功能门控 | 测试新功能 |
| `--request-timeout` | 60s | 60s-120s | 稳定 | 请求超时 | 复杂操作可能需要延长 |
| `--watch-cache-sizes` | 自动 | 根据资源调整 | v1.28优化 | Watch缓存大小 | 大集群优化 |

## etcd 关键参数

| 参数 | 默认值 | 推荐生产值 | 版本变更 | 说明 | 安全/性能影响 |
|-----|-------|----------|---------|------|--------------|
| `--data-dir` | 无 | SSD路径 | 稳定 | 数据目录 | 必须使用SSD |
| `--quota-backend-bytes` | 2GB | 8GB | 稳定 | 存储配额 | 大集群需增加 |
| `--snapshot-count` | 100000 | 10000 | 稳定 | 快照触发事务数 | 平衡性能和恢复 |
| `--auto-compaction-mode` | periodic | revision | 稳定 | 压缩模式 | revision更精确 |
| `--auto-compaction-retention` | 0 | 1h或1000 | 稳定 | 压缩保留 | 减少存储增长 |
| `--max-txn-ops` | 128 | 256-512 | 稳定 | 单事务最大操作数 | 复杂操作需增加 |
| `--max-request-bytes` | 1.5MB | 10MB | 稳定 | 最大请求大小 | 大ConfigMap需要 |
| `--heartbeat-interval` | 100ms | 100ms | 稳定 | 心跳间隔 | 网络延迟高时调整 |
| `--election-timeout` | 1000ms | 1000-2000ms | 稳定 | 选举超时 | 至少5倍心跳 |
| `--listen-peer-urls` | 无 | https://ip:2380 | 稳定 | 对等通信地址 | 集群通信 |
| `--listen-client-urls` | 无 | https://ip:2379 | 稳定 | 客户端地址 | API Server连接 |
| `--cert-file` | 无 | 证书路径 | 稳定 | TLS证书 | 加密通信 |
| `--key-file` | 无 | 私钥路径 | 稳定 | TLS私钥 | 加密通信 |
| `--peer-cert-file` | 无 | 对等证书 | 稳定 | 对等TLS证书 | 集群安全 |

## kube-scheduler 关键参数

| 参数 | 默认值 | 推荐生产值 | 版本变更 | 说明 | 安全/性能影响 |
|-----|-------|----------|---------|------|--------------|
| `--config` | 无 | 配置文件路径 | v1.25框架稳定 | 调度配置 | 推荐使用配置文件 |
| `--leader-elect` | true | true | 稳定 | 领导选举 | HA必需 |
| `--leader-elect-lease-duration` | 15s | 15s | 稳定 | 租约时长 | 影响故障切换时间 |
| `--leader-elect-renew-deadline` | 10s | 10s | 稳定 | 续租期限 | 小于租约时长 |
| `--leader-elect-retry-period` | 2s | 2s | 稳定 | 重试间隔 | 影响选举速度 |
| `--kube-api-qps` | 50 | 100-200 | 稳定 | API请求QPS | 大集群需增加 |
| `--kube-api-burst` | 100 | 200-400 | 稳定 | API请求突发 | 大集群需增加 |
| `--profiling` | true | false | 稳定 | 性能分析 | 生产应禁用 |

## kube-controller-manager 关键参数

| 参数 | 默认值 | 推荐生产值 | 版本变更 | 说明 | 安全/性能影响 |
|-----|-------|----------|---------|------|--------------|
| `--leader-elect` | true | true | 稳定 | 领导选举 | HA必需 |
| `--controllers` | * | 默认或自定义 | 稳定 | 启用的控制器 | 可禁用不需要的控制器 |
| `--concurrent-deployment-syncs` | 5 | 10-20 | 稳定 | Deployment并发数 | 大量Deployment时增加 |
| `--concurrent-replicaset-syncs` | 5 | 10-20 | 稳定 | RS并发数 | 大量RS时增加 |
| `--concurrent-service-syncs` | 5 | 10-20 | 稳定 | Service并发数 | 大量Service时增加 |
| `--concurrent-namespace-syncs` | 10 | 20 | 稳定 | NS并发数 | 大量NS时增加 |
| `--concurrent-gc-syncs` | 20 | 30-50 | 稳定 | GC并发数 | 频繁删除时增加 |
| `--node-monitor-grace-period` | 40s | 40s | 稳定 | 节点监控宽限期 | 影响NotReady判定 |
| `--node-monitor-period` | 5s | 5s | 稳定 | 节点检查周期 | 影响检测速度 |
| `--pod-eviction-timeout` | 5m | 5m | 稳定 | Pod驱逐超时 | 影响故障恢复速度 |
| `--kube-api-qps` | 20 | 50-100 | 稳定 | API请求QPS | 大集群需增加 |
| `--kube-api-burst` | 30 | 100-200 | 稳定 | API请求突发 | 大集群需增加 |
| `--terminated-pod-gc-threshold` | 12500 | 12500 | 稳定 | 终止Pod GC阈值 | 控制API对象数量 |

## kubelet 关键参数

| 参数 | 默认值 | 推荐生产值 | 版本变更 | 说明 | 安全/性能影响 |
|-----|-------|----------|---------|------|--------------|
| `--config` | 无 | 配置文件路径 | 推荐 | kubelet配置 | 推荐使用配置文件 |
| `--container-runtime-endpoint` | 无 | unix:///run/containerd/containerd.sock | v1.24必需 | CRI端点 | v1.24+必须指定 |
| `--max-pods` | 110 | 110-250 | 稳定 | 节点最大Pod数 | 需配合CIDR规划 |
| `--pod-max-pids` | -1 | 4096 | 稳定 | Pod最大PID数 | 防止PID耗尽 |
| `--image-gc-high-threshold` | 85 | 80 | 稳定 | 镜像GC高水位% | 控制磁盘使用 |
| `--image-gc-low-threshold` | 80 | 70 | 稳定 | 镜像GC低水位% | GC目标 |
| `--eviction-hard` | 见下文 | 自定义 | v1.26增强 | 硬驱逐阈值 | 保护节点稳定 |
| `--eviction-soft` | 无 | 自定义 | 稳定 | 软驱逐阈值 | 优雅驱逐 |
| `--eviction-soft-grace-period` | 无 | 按需配置 | 稳定 | 软驱逐宽限期 | 配合软驱逐使用 |
| `--system-reserved` | 无 | cpu=500m,memory=1Gi | 稳定 | 系统预留资源 | 保护系统进程 |
| `--kube-reserved` | 无 | cpu=500m,memory=1Gi | 稳定 | K8S预留资源 | 保护K8S组件 |
| `--enforce-node-allocatable` | pods | pods,kube-reserved,system-reserved | 稳定 | 强制可分配 | 配合预留使用 |
| `--node-status-update-frequency` | 10s | 10s | 稳定 | 状态更新频率 | 影响控制平面负载 |
| `--serialize-image-pulls` | true | false | 稳定 | 串行拉取镜像 | 并行可提速但增加负载 |
| `--registry-qps` | 5 | 10-20 | 稳定 | 镜像仓库QPS | 大量Pod启动时增加 |
| `--registry-burst` | 10 | 20-40 | 稳定 | 镜像仓库突发 | 大量Pod启动时增加 |
| `--rotate-certificates` | true | true | 稳定 | 证书轮换 | 安全必需 |
| `--protect-kernel-defaults` | false | true | 稳定 | 保护内核默认值 | 安全加固 |
| `--read-only-port` | 10255 | 0 | 稳定 | 只读端口 | 生产应禁用(设为0) |

### kubelet 驱逐阈值默认值

| 驱逐信号 | 默认硬阈值 | 推荐生产值 | 说明 |
|---------|-----------|----------|------|
| `memory.available` | 100Mi | 500Mi-1Gi | 可用内存 |
| `nodefs.available` | 10% | 15% | 节点文件系统可用 |
| `nodefs.inodesFree` | 5% | 10% | 节点inode可用 |
| `imagefs.available` | 15% | 15% | 镜像文件系统可用 |
| `pid.available` | 无 | 1000 | 可用PID数 |

## kube-proxy 关键参数

| 参数 | 默认值 | 推荐生产值 | 版本变更 | 说明 | 安全/性能影响 |
|-----|-------|----------|---------|------|--------------|
| `--proxy-mode` | iptables | ipvs | v1.26 nftables | 代理模式 | 大集群推荐IPVS |
| `--cluster-cidr` | 无 | Pod CIDR | 稳定 | 集群CIDR | 影响SNAT行为 |
| `--ipvs-scheduler` | rr | 按需选择 | 稳定(IPVS模式) | IPVS调度算法 | rr/lc/sh等 |
| `--ipvs-min-sync-period` | 0s | 1s | 稳定 | 最小同步周期 | 减少同步频率 |
| `--ipvs-sync-period` | 30s | 30s | 稳定 | 同步周期 | 规则更新频率 |
| `--iptables-min-sync-period` | 1s | 1s | 稳定 | iptables最小同步 | 减少CPU使用 |
| `--iptables-sync-period` | 30s | 30s | 稳定 | iptables同步周期 | 规则更新频率 |
| `--conntrack-max-per-core` | 32768 | 65536 | 稳定 | 每核conntrack数 | 高流量需增加 |
| `--conntrack-min` | 131072 | 262144 | 稳定 | 最小conntrack数 | 高流量需增加 |
| `--masquerade-all` | false | 按需 | 稳定 | 全部SNAT | 某些CNI需要 |
| `--metrics-bind-address` | 0.0.0.0:10249 | 127.0.0.1:10249 | 稳定 | 指标端点 | 限制访问 |

## Feature Gates 配置

| 功能门控 | v1.25默认 | v1.28默认 | v1.32默认 | 推荐设置 | 用途 |
|---------|----------|----------|----------|---------|------|
| `PodSecurity` | true | true | true | true | Pod安全准入 |
| `ServerSideApply` | true | true | true | true | 服务端应用 |
| `EphemeralContainers` | true | true | true | true | 临时调试容器 |
| `GracefulNodeShutdown` | true | true | true | true | 优雅节点关闭 |
| `InPlacePodVerticalScaling` | false | false | true | 按需 | 就地Pod调整 |
| `SidecarContainers` | false | false | true | 按需 | Sidecar容器 |
| `ValidatingAdmissionPolicy` | false | true | true | true | CEL验证策略 |
| `UserNamespacesSupport` | false | false | true | 按需 | 用户命名空间 |
| `DynamicResourceAllocation` | false | false | true | 按需 | 动态资源分配(GPU) |

## kubeconfig 结构

```yaml
apiVersion: v1
kind: Config
current-context: production
preferences: {}

clusters:
- cluster:
    certificate-authority-data: <base64>  # 或 certificate-authority: /path/to/ca.crt
    server: https://apiserver:6443
  name: production-cluster

contexts:
- context:
    cluster: production-cluster
    user: admin
    namespace: default  # 默认命名空间
  name: production

users:
- name: admin
  user:
    client-certificate-data: <base64>  # 或 client-certificate: /path/to/cert
    client-key-data: <base64>          # 或 client-key: /path/to/key
    # 或使用token
    # token: <bearer-token>
    # 或使用exec认证
    # exec:
    #   apiVersion: client.authentication.k8s.io/v1beta1
    #   command: aws
    #   args: ["eks", "get-token", "--cluster-name", "my-cluster"]
```

## ACK 特定配置建议

| 配置项 | ACK托管版 | ACK专有版 | 说明 |
|-------|----------|----------|------|
| **控制平面参数** | 控制台配置 | 手动配置 | 托管版通过控制台调整 |
| **kubelet配置** | 节点池配置 | 手动配置 | 通过节点池模板管理 |
| **kube-proxy模式** | 创建时选择 | 创建时选择 | 推荐IPVS |
| **审计日志** | 自动集成SLS | 手动配置 | 托管版自动接入日志服务 |
| **证书轮换** | 自动 | 手动 | 托管版自动管理证书 |

---

**配置检查命令**:
```bash
# 查看API Server参数
kubectl get pods -n kube-system -l component=kube-apiserver -o yaml | grep -A 50 'command:'

# 查看kubelet配置
kubectl get configmap -n kube-system kubelet-config-<version> -o yaml
kubectl get nodes <node> -o jsonpath='{.status.config.active}'

# 查看Feature Gates状态
kubectl get --raw /metrics | grep kubernetes_feature_enabled
```
