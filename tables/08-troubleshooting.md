# 表格8：故障排除表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/tasks/debug](https://kubernetes.io/docs/tasks/debug/)

## Pod故障排查

| 症状 | 可能原因 | 诊断命令 | 版本特定修复 | 解决方案 | 生产预防措施 |
|------|---------|---------|-------------|---------|-------------|
| **Pod卡在Pending** | 资源不足/调度约束 | `kubectl describe pod <name>` | v1.27+调度事件增强 | 检查Events，扩容节点或调整资源请求 | 配置集群自动扩缩容 |
| **Pod卡在ContainerCreating** | 镜像拉取失败/卷挂载失败 | `kubectl describe pod <name>`, `kubectl logs <name> -c <init>` | v1.28+ Sidecar增强 | 检查镜像仓库凭证，PV/PVC状态 | 配置镜像预拉取，使用本地镜像缓存 |
| **CrashLoopBackOff** | 应用崩溃/配置错误 | `kubectl logs <name> --previous`, `kubectl describe pod` | - | 查看应用日志，检查启动命令和探针 | 配置适当的存活/就绪探针 |
| **ImagePullBackOff** | 镜像不存在/凭证错误/网络问题 | `kubectl describe pod <name>` | - | 验证镜像名称和tag，检查imagePullSecrets | 使用私有镜像仓库，配置镜像拉取策略 |
| **OOMKilled** | 内存超限 | `kubectl describe pod`, `dmesg \| grep -i oom` | v1.27+就地调整 | 增加内存limits，优化应用内存使用 | 设置合理的资源限制，监控内存使用 |
| **Evicted** | 节点资源压力 | `kubectl describe pod`, `kubectl describe node` | v1.26驱逐增强 | 检查节点资源，调整驱逐阈值 | 配置资源配额，预留系统资源 |
| **Pod无法删除(Terminating)** | Finalizer阻塞/节点失联 | `kubectl get pod -o yaml \| grep finalizer` | v1.27+强制删除优化 | 移除finalizer或强制删除 | 避免在finalizer中执行长时间操作 |
| **Init容器失败** | 初始化依赖未满足 | `kubectl logs <pod> -c <init-container>` | v1.28 Sidecar | 检查init容器日志，确认依赖服务就绪 | 使用就绪探针确保依赖 |
| **Pod频繁重启** | 资源不足/探针配置错误 | `kubectl get pods -w`, `kubectl describe pod` | - | 调整探针参数，增加资源 | 配置PDB防止同时重启 |
| **Pod网络不通** | CNI问题/NetworkPolicy | `kubectl exec -- ping`, `kubectl get networkpolicy` | v1.25+双栈增强 | 检查CNI状态，排查NetworkPolicy规则 | 测试NetworkPolicy规则 |

## Node故障排查

| 症状 | 可能原因 | 诊断命令 | 版本特定修复 | 解决方案 | 生产预防措施 |
|------|---------|---------|-------------|---------|-------------|
| **NotReady** | kubelet停止/网络断开/资源耗尽 | `kubectl describe node`, `systemctl status kubelet` | v1.26优雅关机GA | 检查kubelet日志，节点网络，重启kubelet | 配置节点自动修复，监控节点健康 |
| **MemoryPressure** | 内存使用过高 | `kubectl describe node`, `free -h` | - | 驱逐Pod释放内存，扩容节点 | 配置内存驱逐阈值，资源配额 |
| **DiskPressure** | 磁盘使用过高 | `kubectl describe node`, `df -h` | - | 清理磁盘，扩容，删除未用镜像 | 配置磁盘驱逐阈值，镜像GC |
| **PIDPressure** | PID耗尽 | `kubectl describe node`, `ps aux \| wc -l` | v1.25+ PID限制 | 限制Pod PID，清理僵尸进程 | 配置pod-max-pids |
| **NetworkUnavailable** | CNI问题 | `kubectl describe node`, CNI日志 | - | 重启CNI，检查网络配置 | 监控CNI健康 |
| **节点无法加入集群** | 证书过期/token过期/网络 | `kubeadm token list`, `journalctl -u kubelet` | v1.27+证书轮换 | 重新生成token，检查证书有效期 | 配置证书自动轮换 |
| **节点kubelet高CPU** | 过多Pod/PLEG问题 | `top`, `kubelet --v=4日志` | v1.28 PLEG优化 | 减少节点Pod数，检查容器运行时 | 限制每节点Pod数 |
| **节点突然重启** | OOM/内核panic/硬件故障 | `dmesg`, `/var/log/messages` | - | 检查系统日志，硬件检测 | 配置节点监控告警 |

## Service/网络故障排查

| 症状 | 可能原因 | 诊断命令 | 版本特定修复 | 解决方案 | 生产预防措施 |
|------|---------|---------|-------------|---------|-------------|
| **Service无法访问** | Endpoints为空/kube-proxy问题 | `kubectl get endpoints`, `kubectl describe svc` | v1.29 IPVS改进 | 检查Pod标签选择器，kube-proxy日志 | 配置Service健康检查 |
| **DNS解析失败** | CoreDNS问题/上游DNS | `kubectl exec -- nslookup kubernetes` | v1.28 DNS缓存 | 检查CoreDNS日志，上游DNS连通性 | 配置DNS冗余，监控DNS延迟 |
| **跨节点Pod不通** | CNI路由问题/防火墙 | `kubectl exec -- ping <pod-ip>` | - | 检查CNI配置，节点间路由 | 测试跨节点连通性 |
| **LoadBalancer Pending** | 云控制器问题/配额限制 | `kubectl describe svc`, 云控制器日志 | - | 检查云API权限，配额 | 监控云资源配额 |
| **Ingress不工作** | 控制器问题/后端不健康 | `kubectl describe ingress`, 控制器日志 | v1.28 Gateway API | 检查Ingress控制器，后端Service | 配置Ingress健康检查 |
| **NetworkPolicy不生效** | CNI不支持/规则错误 | `kubectl describe networkpolicy` | v1.25+增强 | 确认CNI支持，检查规则 | 测试NetworkPolicy |
| **conntrack表满** | 连接数过多 | `conntrack -C`, `dmesg` | v1.26+ nftables | 增加conntrack限制 | 监控conntrack使用 |

## 存储故障排查

| 症状 | 可能原因 | 诊断命令 | 版本特定修复 | 解决方案 | 生产预防措施 |
|------|---------|---------|-------------|---------|-------------|
| **PVC Pending** | 无匹配PV/StorageClass问题 | `kubectl describe pvc`, `kubectl get sc` | v1.29 CSI增强 | 检查StorageClass，创建PV | 配置默认StorageClass |
| **PV挂载失败** | CSI驱动问题/权限 | `kubectl describe pod`, CSI日志 | - | 检查CSI驱动状态，权限 | 监控CSI驱动健康 |
| **PV Released不回收** | 回收策略/数据保护 | `kubectl get pv` | - | 手动清理或修改回收策略 | 根据需求配置回收策略 |
| **多Pod挂载同一PVC失败** | AccessMode不支持 | `kubectl describe pvc` | - | 使用RWX存储或分离存储 | 选择正确的AccessMode |
| **存储性能差** | IOPS限制/网络存储 | `iostat`, `fio测试` | - | 升级存储类型，使用本地存储 | 选择适合的存储类型 |
| **卷扩容失败** | StorageClass不支持/空间不足 | `kubectl describe pvc` | v1.27+扩容增强 | 确认扩容支持，检查后端空间 | 使用支持扩容的StorageClass |

## etcd/控制平面故障排查

| 症状 | 可能原因 | 诊断命令 | 版本特定修复 | 解决方案 | 生产预防措施 |
|------|---------|---------|-------------|---------|-------------|
| **API Server 5xx错误** | etcd问题/过载 | `kubectl get --raw /healthz`, apiserver日志 | v1.29审计增强 | 检查etcd健康，增加限流 | 监控API延迟和错误率 |
| **etcd存储满** | 数据增长/压缩失败 | `etcdctl endpoint status` | - | 压缩+碎片整理，增加配额 | 定期压缩，监控存储使用 |
| **etcd Leader频繁切换** | 网络问题/磁盘慢 | `etcdctl endpoint status`, etcd日志 | - | 检查网络延迟，使用SSD | 监控Leader变更，独立etcd节点 |
| **调度延迟高** | 调度器过载/资源计算复杂 | scheduler日志, `scheduler_pending_pods`指标 | v1.25框架优化 | 优化调度配置，检查插件 | 监控调度延迟 |
| **控制器积压** | 事件过多/API限流 | controller-manager日志, `workqueue_depth`指标 | - | 调整并发参数，检查API限流 | 监控队列深度 |
| **证书过期** | 未配置自动轮换 | `kubeadm certs check-expiration` | v1.27证书轮换GA | 更新证书，配置自动轮换 | 配置证书自动轮换，监控过期 |

## 应用部署故障排查

| 症状 | 可能原因 | 诊断命令 | 版本特定修复 | 解决方案 | 生产预防措施 |
|------|---------|---------|-------------|---------|-------------|
| **Deployment卡住** | 新Pod无法就绪 | `kubectl rollout status`, `kubectl describe deploy` | - | 检查新Pod状态，回滚 | 配置maxSurge/maxUnavailable |
| **滚动更新太慢** | 就绪探针超时/PDB限制 | `kubectl describe deploy`, `kubectl get pdb` | - | 调整更新策略和探针 | 配置适当的探针超时 |
| **回滚失败** | 历史版本不可用 | `kubectl rollout history` | - | 检查历史版本，手动指定版本 | 保留足够的修订历史 |
| **HPA不扩缩容** | Metrics不可用/阈值配置 | `kubectl describe hpa`, `kubectl top pods` | v1.23 HPA v2 GA | 检查Metrics Server，阈值设置 | 监控HPA状态 |
| **Job失败** | 应用错误/资源不足 | `kubectl describe job`, `kubectl logs` | - | 检查Job日志，调整资源 | 配置backoffLimit和deadline |
| **CronJob未执行** | 调度时间错误/暂停 | `kubectl describe cronjob` | v1.25时区支持 | 检查调度表达式和时区 | 监控CronJob执行 |

## 快速诊断脚本

```bash
#!/bin/bash
# k8s-diagnose.sh - 快速诊断脚本

echo "=== 集群状态 ==="
kubectl cluster-info
kubectl get nodes -o wide
kubectl get cs 2>/dev/null || kubectl get --raw='/readyz?verbose'

echo -e "\n=== 问题Pod ==="
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

echo -e "\n=== 最近事件 ==="
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

echo -e "\n=== 节点资源 ==="
kubectl top nodes 2>/dev/null || echo "Metrics Server未安装"

echo -e "\n=== 待调度Pod ==="
kubectl get pods -A -o wide | grep -i pending

echo -e "\n=== 重启次数Top10 ==="
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.restartCount}{end}{"\n"}{end}' | sort -t$'\t' -k3 -nr | head -10

echo -e "\n=== CoreDNS状态 ==="
kubectl get pods -n kube-system -l k8s-app=kube-dns

echo -e "\n=== 存储状态 ==="
kubectl get pv,pvc -A | grep -v Bound
```

---

**排查原则**: 1.看Events 2.看Logs 3.看Describe 4.看Metrics
