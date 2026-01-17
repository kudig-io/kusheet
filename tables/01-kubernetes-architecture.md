# 表格1：Kubernetes架构表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/architecture](https://kubernetes.io/docs/concepts/architecture/)

## 架构总览

| 组件名称 | 描述 | 关键依赖 | 引入版本 | 重要变更版本 | 生产运维注意事项 |
|---------|------|---------|---------|-------------|-----------------|
| **Control Plane (控制平面)** | 集群的大脑，负责全局决策（调度、检测响应事件）| etcd, 网络连通性 | v1.0 | v1.20+ HA增强 | 至少3节点部署实现HA；ACK Pro版自动托管控制平面 |
| **kube-apiserver** | 集群API入口，所有组件通信中心 | etcd, 证书 | v1.0 | v1.29+ 审计增强 | 启用审计日志；配置适当的请求限流(--max-requests-inflight) |
| **etcd** | 分布式KV存储，保存所有集群状态 | 磁盘IO, 网络 | v1.0 | v1.6+ v3 API默认 | 独立SSD磁盘；定期快照备份；监控磁盘延迟<10ms |
| **kube-scheduler** | Pod调度决策，选择最优节点 | apiserver | v1.0 | v1.25+ 调度框架 | 配置调度策略；监控调度延迟和失败率 |
| **kube-controller-manager** | 运行控制器循环（Node、Replication等）| apiserver | v1.0 | v1.27+ 控制器分离 | 调整--concurrent-*参数优化大集群性能 |
| **cloud-controller-manager** | 云厂商特定控制器（LoadBalancer、Node等）| apiserver, 云API | v1.6 | v1.25+ 稳定 | ACK自动集成；监控云API调用限流 |
| **Worker Node (工作节点)** | 运行实际工作负载的节点 | kubelet, 容器运行时 | v1.0 | - | 根据负载类型选择节点规格；标签分组管理 |
| **kubelet** | 节点代理，管理Pod生命周期 | 容器运行时, apiserver | v1.0 | v1.24+ cgroup v2 | 配置适当的--max-pods；监控节点资源压力 |
| **kube-proxy** | 网络代理，实现Service抽象 | iptables/IPVS | v1.0 | v1.26+ nftables | 大集群推荐IPVS模式；监控conntrack表使用 |
| **Container Runtime** | 容器执行环境 | CRI接口 | v1.0 | v1.24+ 移除dockershim | 推荐containerd；定期清理未用镜像 |
| **CoreDNS** | 集群DNS服务 | apiserver | v1.12+ 默认 | v1.28+ DNS缓存优化 | 根据集群规模调整副本数和缓存大小 |
| **CNI Plugin** | 容器网络接口实现 | 节点网络 | v1.0 | v1.25+ 双栈增强 | 选择适合场景的CNI（Calico/Flannel/Cilium）|

## 架构层次详解

| 架构层 | 包含组件 | 职责 | 高可用配置 | 扩展限制(官方测试) | ACK特定集成 |
|-------|---------|------|-----------|-------------------|-------------|
| **管理层** | apiserver, controller-manager, scheduler | 集群决策与API | 3/5节点奇数部署，负载均衡 | 5000节点/集群 | ACK Pro托管，自动HA |
| **数据层** | etcd | 状态持久化 | 3/5节点Raft集群 | 8GB默认配额，可调 | 独立etcd集群选项 |
| **计算层** | kubelet, 容器运行时 | 工作负载执行 | 节点故障自动驱逐 | 110 Pods/节点默认 | 弹性伸缩组集成 |
| **网络层** | kube-proxy, CNI, CoreDNS | 服务发现与通信 | 多副本DaemonSet | 5000 Services/集群 | Terway CNI原生支持 |
| **存储层** | CSI驱动, PV/PVC | 持久化存储 | 跨AZ复制 | 取决于后端存储 | 云盘CSI自动集成 |

## 版本演进关键里程碑

| 版本 | 架构变更 | 影响范围 | 迁移注意事项 | 生产影响评估 |
|-----|---------|---------|-------------|-------------|
| **v1.6** | etcd v3 API成为默认 | 数据存储 | 需要数据迁移工具 | 性能提升，存储效率改善 |
| **v1.12** | CoreDNS替代kube-dns | DNS服务 | 配置迁移 | DNS性能和稳定性提升 |
| **v1.16** | CRD v1 API稳定 | 扩展机制 | API版本更新 | 自定义资源更可靠 |
| **v1.20** | Dockershim弃用公告 | 容器运行时 | 规划迁移到containerd | 需要运维团队准备 |
| **v1.24** | 移除Dockershim | 容器运行时 | 必须使用CRI运行时 | **破坏性变更**，需提前迁移 |
| **v1.25** | PodSecurityPolicy移除 | 安全策略 | 迁移到PSA | 安全模型变更 |
| **v1.26** | 非优雅节点关闭GA | 节点管理 | 配置启用 | 提高节点故障恢复能力 |
| **v1.27** | 就地Pod资源调整Alpha | 资源管理 | 可选启用 | 减少Pod重启 |
| **v1.28** | Sidecar容器支持 | Pod设计 | 新功能Beta | 改善sidecar生命周期 |
| **v1.29** | 负载均衡器IP模式 | 网络 | 新功能 | 简化云LB配置 |
| **v1.30** | 节点交换内存支持 | 节点资源 | 可选启用 | 支持更多工作负载类型 |
| **v1.31** | AppArmor GA | 安全 | 从注解迁移到字段 | 安全配置标准化 |
| **v1.32** | 动态资源分配改进 | 资源管理 | 需要DRA驱动 | GPU等特殊设备管理优化 |

## 生产部署架构模式

| 部署模式 | 节点配置 | 适用场景 | 成本级别 | 可用性SLA | ACK对应方案 |
|---------|---------|---------|---------|----------|-------------|
| **单Master** | 1控制+N工作 | 开发测试 | 低 | 99% | ACK基础版 |
| **HA三Master** | 3控制+N工作 | 小型生产 | 中 | 99.9% | ACK Pro版 |
| **HA五Master** | 5控制+N工作 | 大型生产/金融 | 高 | 99.99% | ACK Pro+独立etcd |
| **多集群联邦** | 多个独立集群 | 跨地域/多租户 | 很高 | 99.99%+ | ACK One |

## 常见生产问题

| 问题类型 | 症状 | 根因分析 | 诊断命令 | 解决方案 |
|---------|------|---------|---------|---------|
| etcd性能下降 | API响应慢，调度延迟 | 磁盘IO瓶颈 | `etcdctl endpoint status` | 使用SSD，调整压缩参数 |
| 控制平面过载 | 请求超时，503错误 | 请求量过大 | `kubectl get --raw /metrics` | 增加副本，启用缓存 |
| 节点NotReady | Pod无法调度 | kubelet问题 | `kubectl describe node` | 检查kubelet日志，网络连通性 |
| DNS解析失败 | 服务发现异常 | CoreDNS问题 | `kubectl logs -n kube-system coredns-*` | 调整CoreDNS资源，检查上游DNS |
| 网络分区 | Pod间通信失败 | CNI配置错误 | `kubectl exec -- ping` | 检查CNI状态，节点网络 |

---

**导出说明**: 本表格采用标准Markdown格式，可直接使用pandas读取或导出为CSV/Excel:
```python
import pandas as pd
tables = pd.read_html('01-kubernetes-architecture.md')
```
