# 表格2：核心组件表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/overview/components](https://kubernetes.io/docs/concepts/overview/components/)

## 控制平面组件

| 组件 | 角色 | 默认端口 | 关键配置标志 | 版本特定变更 | 监控端点 | 故障模式 | 运维最佳实践 |
|-----|------|---------|-------------|-------------|---------|---------|-------------|
| **kube-apiserver** | API网关，认证授权，准入控制 | 6443 | `--etcd-servers`, `--service-cluster-ip-range`, `--authorization-mode` | v1.29: 审计日志增强; v1.30: CEL准入策略GA | `/metrics`, `/healthz`, `/livez`, `/readyz` | 过载导致503; 证书过期 | 启用审计日志; 配置`--max-requests-inflight=400`; 监控请求延迟P99 |
| **etcd** | 分布式一致性存储，集群状态持久化 | 2379/2380 | `--data-dir`, `--quota-backend-bytes`, `--snapshot-count` | v1.6: v3 API默认; v1.22: 3.5.x推荐 | `/metrics`, `/health` | 磁盘满导致只读; 网络分区 | SSD存储; `--quota-backend-bytes=8589934592`(8GB); 每小时自动快照 |
| **kube-scheduler** | Pod到节点的调度决策 | 10259 | `--config`, `--leader-elect` | v1.25: 调度框架Beta; v1.27: 调度门GA | `/metrics`, `/healthz` | 调度延迟过高; 资源计算错误 | 自定义调度配置文件; 监控`scheduler_pending_pods`指标 |
| **kube-controller-manager** | 运行核心控制器循环 | 10257 | `--controllers`, `--concurrent-deployment-syncs`, `--leader-elect` | v1.27: 控制器拆分可选 | `/metrics`, `/healthz` | 控制器goroutine泄漏 | 调整并发参数; 监控控制器队列深度 |
| **cloud-controller-manager** | 云厂商集成（LB、节点、路由）| 10258 | `--cloud-provider`, `--controllers` | v1.25: 外部云控制器稳定 | `/metrics`, `/healthz` | 云API限流; 凭证过期 | 配置云API重试; ACK自动管理 |

## 节点组件

| 组件 | 角色 | 默认端口 | 关键配置标志 | 版本特定变更 | 监控端点 | 故障模式 | 运维最佳实践 |
|-----|------|---------|-------------|-------------|---------|---------|-------------|
| **kubelet** | 节点代理，Pod生命周期管理 | 10250/10255 | `--config`, `--container-runtime-endpoint`, `--max-pods` | v1.24: cgroup v2默认; v1.27: 就地资源调整Alpha | `/metrics`, `/healthz`, `/pods` | PLEG超时; 磁盘压力驱逐 | 配置`--max-pods=110`; 预留系统资源`--system-reserved` |
| **kube-proxy** | Service网络代理 | 10249/10256 | `--proxy-mode`, `--cluster-cidr` | v1.26: nftables Alpha; v1.29: IPVS改进 | `/metrics`, `/healthz` | conntrack表满; iptables规则过多 | 大集群用IPVS模式; 监控`kubeproxy_sync_proxy_rules_duration_seconds` |
| **containerd** | CRI兼容容器运行时 | - | `/etc/containerd/config.toml` | v1.24: 成为默认运行时; v1.30: 2.0支持 | `/metrics` | 镜像拉取失败; 容器创建超时 | 配置镜像加速器; 定期`crictl rmi --prune` |
| **CRI-O** | 轻量级CRI运行时 | - | `/etc/crio/crio.conf` | v1.25+: 与K8S版本对齐 | `/metrics` | 运行时崩溃 | OpenShift默认; 配置适当的运行时类 |

## 附加组件

| 组件 | 角色 | 部署方式 | 关键配置 | 版本特定变更 | 监控指标 | 常见问题 | 运维最佳实践 |
|-----|------|---------|---------|-------------|---------|---------|-------------|
| **CoreDNS** | 集群DNS服务 | Deployment | `Corefile` ConfigMap | v1.28: DNS缓存优化; v1.30: 性能提升 | `coredns_dns_requests_total`, `coredns_dns_responses_total` | 查询超时; 上游失败 | 副本数=max(2, nodes/100); 启用缓存插件 |
| **Metrics Server** | 资源指标API | Deployment | `--kubelet-insecure-tls`(测试) | v0.6+: 稳定API | `metrics_server_*` | kubelet连接失败 | 生产使用TLS; HPA/VPA依赖 |
| **Ingress Controller** | 入口流量路由 | Deployment/DaemonSet | 因控制器而异 | v1.19: networking.k8s.io/v1稳定 | 控制器特定 | 证书错误; 后端不可达 | 高可用部署; 配置健康检查 |
| **CNI Plugin** | 容器网络 | DaemonSet/主机安装 | `/etc/cni/net.d/` | v1.25: 双栈增强; v1.28: 网络策略改进 | 插件特定 | IP分配失败; 网络分区 | 选择适合场景的CNI; 监控网络指标 |

## 组件版本兼容性矩阵

| 组件 | v1.25 | v1.26 | v1.27 | v1.28 | v1.29 | v1.30 | v1.31 | v1.32 |
|-----|-------|-------|-------|-------|-------|-------|-------|-------|
| **etcd** | 3.5.x | 3.5.x | 3.5.x | 3.5.x | 3.5.x | 3.5.x | 3.5.x | 3.5.x |
| **containerd** | 1.6+ | 1.6+ | 1.7+ | 1.7+ | 1.7+ | 1.7+/2.0 | 1.7+/2.0 | 2.0+ |
| **CoreDNS** | 1.9+ | 1.9+ | 1.10+ | 1.10+ | 1.11+ | 1.11+ | 1.11+ | 1.11+ |
| **Metrics Server** | 0.6+ | 0.6+ | 0.6+ | 0.7+ | 0.7+ | 0.7+ | 0.7+ | 0.7+ |
| **Calico** | 3.24+ | 3.25+ | 3.26+ | 3.27+ | 3.27+ | 3.28+ | 3.28+ | 3.28+ |
| **Cilium** | 1.12+ | 1.13+ | 1.14+ | 1.14+ | 1.15+ | 1.15+ | 1.16+ | 1.16+ |

## 组件资源推荐配置

| 组件 | 小集群(<50节点) | 中集群(50-200节点) | 大集群(200-1000节点) | 超大集群(1000+节点) |
|-----|----------------|-------------------|---------------------|-------------------|
| **kube-apiserver** | 2核4G | 4核8G | 8核16G | 16核32G |
| **etcd** | 2核4G SSD | 4核8G SSD | 8核16G NVMe | 16核32G NVMe |
| **kube-scheduler** | 1核2G | 2核4G | 4核8G | 8核16G |
| **kube-controller-manager** | 2核4G | 4核8G | 8核16G | 16核32G |
| **CoreDNS** | 2副本,100m/128Mi | 3副本,200m/256Mi | 5副本,500m/512Mi | 10副本,1核/1Gi |
| **Metrics Server** | 1副本,100m/200Mi | 2副本,200m/400Mi | 3副本,500m/1Gi | 5副本,1核/2Gi |

## 组件启动顺序与依赖

| 启动顺序 | 组件 | 依赖条件 | 启动超时 | 健康检查 | 故障影响 |
|---------|------|---------|---------|---------|---------|
| 1 | **etcd** | 网络, 存储 | 60s | `etcdctl endpoint health` | 整个集群不可用 |
| 2 | **kube-apiserver** | etcd健康 | 30s | `curl -k https://localhost:6443/healthz` | 所有API调用失败 |
| 3 | **kube-controller-manager** | apiserver可用 | 30s | `/healthz` 端点 | 控制器停止协调 |
| 4 | **kube-scheduler** | apiserver可用 | 30s | `/healthz` 端点 | 新Pod无法调度 |
| 5 | **kubelet** | apiserver可用 | 30s | `curl http://localhost:10248/healthz` | 节点NotReady |
| 6 | **kube-proxy** | apiserver, kubelet | 30s | `/healthz` 端点 | Service网络故障 |
| 7 | **CoreDNS** | kube-proxy, CNI | 60s | DNS查询测试 | 服务发现失败 |
| 8 | **CNI** | kubelet | 60s | Pod网络测试 | Pod网络不通 |

## 关键配置参数速查

| 组件 | 参数 | 默认值 | 推荐生产值 | 说明 | 版本注意 |
|-----|------|-------|----------|------|---------|
| **apiserver** | `--max-requests-inflight` | 400 | 800 | 最大并发非变更请求 | - |
| **apiserver** | `--max-mutating-requests-inflight` | 200 | 400 | 最大并发变更请求 | - |
| **apiserver** | `--watch-cache-sizes` | 默认 | 根据对象调整 | Watch缓存大小 | v1.28+优化 |
| **etcd** | `--quota-backend-bytes` | 2GB | 8GB | 存储配额 | - |
| **etcd** | `--auto-compaction-retention` | 0 | 1h | 自动压缩保留 | - |
| **kubelet** | `--max-pods` | 110 | 110-250 | 单节点最大Pod数 | 需调整CIDR |
| **kubelet** | `--image-gc-high-threshold` | 85 | 80 | 镜像GC高水位 | - |
| **kubelet** | `--eviction-hard` | 默认 | 自定义 | 驱逐阈值 | v1.26+增强 |
| **scheduler** | `--kube-api-qps` | 50 | 100 | API请求QPS | - |
| **controller** | `--concurrent-deployment-syncs` | 5 | 10 | Deployment并发数 | - |
| **kube-proxy** | `--proxy-mode` | iptables | ipvs | 代理模式 | 大集群推荐IPVS |

## 组件日志关键字与排查

| 组件 | 日志路径/命令 | 关键错误关键字 | 可能原因 | 排查步骤 |
|-----|--------------|---------------|---------|---------|
| **apiserver** | `journalctl -u kube-apiserver` | `connection refused`, `etcd leader changed` | etcd不健康 | 检查etcd状态 |
| **etcd** | `journalctl -u etcd` | `mvcc: database space exceeded`, `rafthttp: failed to dial` | 存储满/网络问题 | 压缩+碎片整理 |
| **scheduler** | `kubectl logs -n kube-system kube-scheduler-*` | `unable to schedule pod`, `Preempting` | 资源不足 | 检查节点资源 |
| **kubelet** | `journalctl -u kubelet` | `PLEG is not healthy`, `failed to pull image` | 容器运行时问题 | 重启containerd |
| **kube-proxy** | `kubectl logs -n kube-system kube-proxy-*` | `conntrack table full` | conntrack表满 | 增大conntrack限制 |
| **CoreDNS** | `kubectl logs -n kube-system coredns-*` | `i/o timeout`, `SERVFAIL` | 上游DNS问题 | 检查上游DNS |

## ACK特定组件集成

| 组件 | ACK托管方式 | 配置入口 | 特殊优化 | 监控集成 |
|-----|------------|---------|---------|---------|
| **控制平面** | 全托管(Pro版) | 控制台 | 自动HA, 自动升级 | ARMS自动接入 |
| **etcd** | 托管或独立 | 控制台 | 自动备份 | 云监控集成 |
| **CoreDNS** | 托管 | ConfigMap | 阿里云DNS集成 | SLS日志 |
| **Ingress** | ALB/Nginx可选 | 控制台+YAML | SLB自动绑定 | ALB监控 |
| **CNI** | Terway/Flannel | 创建时选择 | ENI直通性能 | 网络监控 |

---

**诊断脚本示例**:
```bash
# 快速检查所有组件状态
kubectl get componentstatuses  # 已弃用但仍可用
kubectl get --raw='/readyz?verbose'
kubectl get nodes -o wide
kubectl get pods -n kube-system
```
