# Kusheet - Kubernetes 生产运维全域知识库

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-02 | **表格数量**: 219

---

## 目录

- [项目定位](#项目定位)
- [快速导航(按角色)](#快速导航按角色)
- [知识体系架构](#知识体系架构)
- [演示文档(topic-presentations)](#演示文档topic-presentations)
  - [域A: 架构基础](#域a-架构基础-architecture-fundamentals)
  - [域B: 设计原理](#域b-设计原理-design-principles)
  - [域C: 控制平面](#域c-控制平面-control-plane)
  - [域D: 工作负载与调度](#域d-工作负载与调度-workloads--scheduling)
  - [域E: 网络](#域e-网络-networking)
  - [域F: 存储](#域f-存储-storage)
  - [域G: 安全合规](#域g-安全合规-security--compliance)
  - [域H: 可观测性](#域h-可观测性-observability)
  - [域I: 平台运维](#域i-平台运维-platform-operations)
  - [域J: 扩展生态](#域j-扩展生态-extensions--ecosystem)
  - [域K: AI基础设施](#域k-ai基础设施-ai-infrastructure)
  - [域L: 故障排查](#域l-故障排查-troubleshooting)
  - [域M: Docker基础](#域m-docker基础-docker-fundamentals)
  - [域N: Linux基础](#域n-linux基础-linux-fundamentals)
  - [域O: 网络基础](#域o-网络基础-network-fundamentals)
  - [域P: 存储基础](#域p-存储基础-storage-fundamentals)
- [多维度查询附录](#多维度查询附录)
  - [附录A: 开发者视角](#附录a-开发者视角)
  - [附录B: 运维工程师视角](#附录b-运维工程师视角)
  - [附录C: 架构师视角](#附录c-架构师视角)
  - [附录D: 测试工程师视角](#附录d-测试工程师视角)
  - [附录E: 产品经理视角](#附录e-产品经理视角)
  - [附录F: 终端用户视角](#附录f-终端用户视角)
- [变更记录](#变更记录)

---

## 项目定位

Kusheet 是面向**生产环境**的 Kubernetes + AI Infrastructure 运维全域知识库，涵盖从基础架构到 AI/LLM 工作负载的完整技术栈。

| 特性 | 说明 |
|:---|:---|
| **生产级配置** | 所有 YAML/Shell 示例可直接用于生产环境 |
| **AI Infra专题** | 覆盖GPU调度、分布式训练、模型服务、成本优化 |
| **多维度索引** | 按技术域、场景、角色、组件快速定位 |
| **深度解析** | 控制平面组件源码级剖析、CRI/CSI/CNI接口详解 |

---

## 快速导航(按角色)

| 角色 | 推荐起点 | 核心关注域 |
|:---|:---|:---|
| **开发者** | [05-kubectl](#域a-架构基础-architecture-fundamentals) → [21-工作负载](#域d-工作负载与调度-workloads--scheduling) → [47-Service](#域e-网络-networking) | 工作负载、网络、CI/CD |
| **运维工程师** | [35-etcd](#域c-控制平面-control-plane) → [99-排障](#域l-故障排查-troubleshooting) → [93-监控](#域h-可观测性-observability) | 控制平面、可观测性、故障排查 |
| **架构师** | [01-架构](#域a-架构基础-architecture-fundamentals) → [11-设计原则](#域b-设计原理-design-principles) → [18-高可用](#域b-设计原理-design-principles) | 架构基础、设计原理、多集群 |
| **测试工程师** | [106-混沌工程](#域h-可观测性-observability) → [124-CI/CD](#域j-扩展生态-extensions--ecosystem) | 混沌工程、CI/CD、可观测性 |
| **产品经理** | [01-架构](#域a-架构基础-architecture-fundamentals) → [26-成本](#域k-ai基础设施-ai-infrastructure) → [12-AI成本](#域k-ai基础设施-ai-infrastructure) | 架构概览、成本优化、AI能力 |
| **终端用户** | [05-kubectl](#域a-架构基础-architecture-fundamentals) → [126-Helm](#域j-扩展生态-extensions--ecosystem) → [125-GitOps](#域j-扩展生态-extensions--ecosystem) | CLI工具、部署管理 |

---

## 知识体系架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Kubernetes 知识体系架构                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  [域A] 架构基础    [域B] 设计原理    [域C] 控制平面                          │
│     ↓                  ↓                 ↓                                  │
│  [域D] 工作负载 ←→ [域E] 网络 ←→ [域F] 存储                                  │
│     ↓                  ↓                 ↓                                  │
│  [域G] 安全合规    [域H] 可观测性   [域I] 平台运维                           │
│     ↓                  ↓                 ↓                                  │
│  [域J] 扩展生态    [域K] AI基础设施  [域L] 故障排查                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                          底层基础知识域                                      │
│  [域M] Docker基础  [域N] Linux基础  [域O] 网络基础  [域P] 存储基础           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 域A: 架构基础 (Architecture Fundamentals)

> 16 篇 | **从生产环境运维专家角度深度优化**，新增企业级高可用架构设计、零信任安全实施、基于机器学习的性能优化、高级威胁检测等专家级内容

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 01 | K8s架构 | [kubernetes-architecture-overview](./domain-1-architecture-fundamentals/01-kubernetes-architecture-overview.md) | **新增第11章生产环境运维专家增强指南**：企业级高可用架构、零信任安全架构、成本优化专家策略、故障应急响应专家手册 |
| 02 | 核心组件 | [core-components-deep-dive](./domain-1-architecture-fundamentals/02-core-components-deep-dive.md) | 各组件职责与协作 |
| 03 | API版本 | [api-versions-features](./domain-1-architecture-fundamentals/03-api-versions-features.md) | API版本演进、特性门控 |
| 04 | 源码结构 | [source-code-structure](./domain-1-architecture-fundamentals/04-source-code-structure.md) | 源码目录、模块划分 |
| 05 | kubectl | [kubectl-commands-reference](./domain-1-architecture-fundamentals/05-kubectl-commands-reference.md) | 命令大全、常用场景 |
| 06 | 集群配置 | [cluster-configuration-parameters](./domain-1-architecture-fundamentals/06-cluster-configuration-parameters.md) | 集群级配置参数 |
| 07 | 升级策略 | [upgrade-paths-strategy](./domain-1-architecture-fundamentals/07-upgrade-paths-strategy.md) | **新增第8章生产环境升级专家实践**：蓝绿部署、金丝雀升级、智能预检系统、零停机方案、自动回滚机制 |
| 08 | 多租户 | [multi-tenancy-architecture](./domain-1-architecture-fundamentals/08-multi-tenancy-architecture.md) | 多租户隔离模型 |
| 09 | 边缘计算 | [edge-computing-kubeedge](./domain-1-architecture-fundamentals/09-edge-computing-kubeedge.md) | KubeEdge、边缘场景 |
| 10 | Win容器 | [windows-containers-support](./domain-1-architecture-fundamentals/10-windows-containers-support.md) | Windows节点支持 |
| 11 | 源码解读 | [kubernetes-source-code-architecture](./domain-1-architecture-fundamentals/11-kubernetes-source-code-architecture.md) | 核心代码路径 |
| 12 | 部署模式 | [cluster-deployment-patterns](./domain-1-architecture-fundamentals/12-cluster-deployment-patterns.md) | 集群部署模式 |
| 13 | 性能调优 | [performance-tuning-guide](./domain-1-architecture-fundamentals/13-performance-tuning-guide.md) | **新增第8章生产环境性能优化专家实践**：超大规模集群优化、智能自动调优系统、容器运行时性能优化、网络性能专家优化 |
| 14 | 安全架构 | [security-architecture](./domain-1-architecture-fundamentals/14-security-architecture.md) | **新增第8章企业级安全运营专家实践**：零信任安全架构深度实施、高级威胁检测系统、容器安全专家防护体系、合规自动化与审计专家系统 |
| 15 | 可观测性 | [observability-architecture](./domain-1-architecture-fundamentals/15-observability-architecture.md) | 可观测性架构 |
| 16 | 迁移策略 | [upgrade-migration-strategy](./domain-1-architecture-fundamentals/16-upgrade-migration-strategy.md) | 升级迁移策略 |

---

### 域B: 设计原理 (Design Principles)

> 18 篇 | K8s设计哲学、声明式API、控制器模式、分布式原理、可观测性、安全设计、性能优化

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 11 | 设计原则 | [design-principles-foundations](./domain-2-design-principles/01-design-principles-foundations.md) | 核心设计哲学、最佳实践 |
| 12 | 声明式API | [declarative-api-pattern](./domain-2-design-principles/02-declarative-api-pattern.md) | 声明式 vs 命令式 |
| 13 | 控制器模式 | [controller-pattern](./domain-2-design-principles/03-controller-pattern.md) | Reconcile循环、最终一致性 |
| 14 | Watch/List | [watch-list-mechanism](./domain-2-design-principles/04-watch-list-mechanism.md) | 事件监听机制 |
| 15 | Informer | [informer-workqueue](./domain-2-design-principles/05-informer-workqueue.md) | SharedInformer、WorkQueue |
| 16 | 乐观并发 | [resource-version-control](./domain-2-design-principles/06-resource-version-control.md) | ResourceVersion、冲突处理 |
| 17 | etcd共识 | [distributed-consensus-etcd](./domain-2-design-principles/07-distributed-consensus-etcd.md) | Raft协议、数据一致性 |
| 18 | 高可用模式 | [high-availability-patterns](./domain-2-design-principles/08-high-availability-patterns.md) | HA架构、故障转移 |
| 19 | 源码解读 | [source-code-walkthrough](./domain-2-design-principles/09-source-code-walkthrough.md) | 核心代码路径 |
| 20 | CAP定理 | [cap-theorem-distributed-systems](./domain-2-design-principles/10-cap-theorem-distributed-systems.md) | CAP权衡、分布式取舍 |
| 21 | 扩展设计 | [extensibility-design-patterns](./domain-2-design-principles/11-extensibility-design-patterns.md) | CRD、扩展机制设计 |
| 22 | Operator | [operator-development-guide](./domain-2-design-principles/12-operator-development-guide.md) | Operator模式实践 |
| 23 | 准入控制 | [admission-control-webhooks](./domain-2-design-principles/13-admission-control-webhooks.md) | Webhook、验证变更 |
| 24 | 服务网格 | [service-mesh-architecture](./domain-2-design-principles/14-service-mesh-architecture.md) | 微服务、服务网格设计 |
| 25 | 混沌工程 | [chaos-engineering](./domain-2-design-principles/15-chaos-engineering.md) | 故障注入、韧性测试 |
| 26 | 可观测性 | [observability-design-principles](./domain-2-design-principles/16-observability-design-principles.md) | 监控、日志、追踪设计 |
| 27 | 安全设计 | [security-design-patterns](./domain-2-design-principles/17-security-design-patterns.md) | 零信任、最小权限原则 |
| 28 | 性能优化 | [performance-optimization-principles](./domain-2-design-principles/18-performance-optimization-principles.md) | 调度、资源、网络优化 |

---

### 域C: 控制平面 (Control Plane)

> 23 篇 | 控制平面架构、组件详解、接口深度解析、调优扩展、故障排查

#### C1: 核心主题文档 (01-10)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 01 | 架构总览 | [plane-architecture-overview](./domain-3-control-plane/01-plane-architecture-overview.md) | 控制平面整体架构、组件关系 |
| 02 | 组件交互 | [plane-components-interaction](./domain-3-control-plane/02-plane-components-interaction.md) | 组件间通信、数据流分析 |
| 03 | 高可用部署 | [plane-high-availability](./domain-3-control-plane/03-plane-high-availability.md) | HA架构设计、部署模式 |
| 04 | 安全加固 | [plane-security-hardening](./domain-3-control-plane/04-plane-security-hardening.md) | 安全配置、加固指南 |
| 05 | 监控可观测 | [plane-monitoring-observability](./domain-3-control-plane/05-plane-monitoring-observability.md) | 监控指标、可观测性 |
| 06 | 故障排查 | [plane-troubleshooting](./domain-3-control-plane/06-plane-troubleshooting.md) | 故障诊断、排查手册 |
| 07 | 升级迁移 | [plane-upgrade-migration](./domain-3-control-plane/07-plane-upgrade-migration.md) | 版本升级、迁移策略 |
| 08 | 性能基准 | [plane-performance-benchmarking](./domain-3-control-plane/08-plane-performance-benchmarking.md) | 性能测试、基准数据 |
| 09 | 扩缩容指南 | [plane-scalability-guide](./domain-3-control-plane/09-plane-scalability-guide.md) | 水平垂直扩展、自动扩缩 |
| 10 | 备份灾备 | [plane-backup-disaster-recovery](./domain-3-control-plane/10-plane-backup-disaster-recovery.md) | 备份策略、灾备方案 |

#### C2: 组件深度解析 (11-20)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 11 | etcd详解 | [etcd-deep-dive](./domain-3-control-plane/11-etcd-deep-dive.md) | Raft共识、MVCC存储、备份恢复 |
| 12 | API Server | [apiserver-deep-dive](./domain-3-control-plane/12-apiserver-deep-dive.md) | 认证授权、APF限流、审计日志 |
| 13 | KCM详解 | [kube-controller-manager-deep-dive](./domain-3-control-plane/13-kube-controller-manager-deep-dive.md) | 40+控制器、Leader选举 |
| 14 | CCM详解 | [cloud-controller-manager-deep-dive](./domain-3-control-plane/14-cloud-controller-manager-deep-dive.md) | 云厂商控制器集成 |
| 15 | Kubelet详解 | [kubelet-deep-dive](./domain-3-control-plane/15-kubelet-deep-dive.md) | Pod生命周期、PLEG、CRI接口 |
| 16 | kube-proxy | [kube-proxy-deep-dive](./domain-3-control-plane/16-kube-proxy-deep-dive.md) | iptables/IPVS/nftables模式 |
| 17 | APIServer调优 | [apiserver-tuning](./domain-3-control-plane/17-apiserver-tuning.md) | 性能参数、限流配置 |
| 18 | APF限流 | [api-priority-fairness](./domain-3-control-plane/18-api-priority-fairness.md) | 优先级、公平分配机制 |
| 19 | etcd运维 | [etcd-operations](./domain-3-control-plane/19-etcd-operations.md) | 集群运维、故障恢复 |
| 20 | Scheduler详解 | [kube-scheduler-deep-dive](./domain-3-control-plane/20-kube-scheduler-deep-dive.md) | 调度框架、插件、抢占机制 |

#### C3: 接口深度解析 (21-23)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 21 | CRI详解 | [container-runtime-deep-dive](./domain-3-control-plane/21-container-runtime-deep-dive.md) | containerd/CRI-O、安全容器 |
| 22 | CSI详解 | [container-storage-deep-dive](./domain-3-control-plane/22-container-storage-deep-dive.md) | CSI规范、驱动开发、快照功能 |
| 23 | CNI详解 | [container-network-deep-dive](./domain-3-control-plane/23-container-network-deep-dive.md) | CNI规范、Calico/Cilium网络 |

---

### 域D: 工作负载与调度 (Workloads & Scheduling)

> 14 篇 | Pod、Deployment、调度策略、自动扩缩容、资源管理

#### D1: 工作负载控制器

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 21 | 工作负载 | [workload-controllers-overview](./domain-4-workloads/21-workload-controllers-overview.md) | Deployment/StatefulSet/DaemonSet |
| 22 | Pod生命周期 | [pod-lifecycle-events](./domain-4-workloads/22-pod-lifecycle-events.md) | Phase、Condition、事件 |
| 23 | Pod模式 | [advanced-pod-patterns](./domain-4-workloads/23-advanced-pod-patterns.md) | Init/Sidecar/Ambassador |
| 24 | 容器Hook | [container-lifecycle-hooks](./domain-4-workloads/24-container-lifecycle-hooks.md) | PostStart/PreStop |
| 25 | Sidecar | [sidecar-containers-patterns](./domain-4-workloads/25-sidecar-containers-patterns.md) | Native Sidecar(v1.28+) |

#### D2: 容器运行时

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 26 | CRI接口 | [container-runtime-interfaces](./domain-4-workloads/26-container-runtime-interfaces.md) | CRI规范、运行时选型 |
| 27 | RuntimeClass | [runtime-class-configuration](./domain-4-workloads/27-runtime-class-configuration.md) | 多运行时配置 |
| 28 | 镜像仓库 | [container-images-registry](./domain-4-workloads/28-container-images-registry.md) | 镜像拉取、仓库配置 |

#### D3: 调度与资源

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 29 | 节点管理 | [node-management-operations](./domain-4-workloads/29-node-management-operations.md) | 节点维护、cordon/drain |
| 30 | 调度器 | [scheduler-configuration](./domain-4-workloads/30-scheduler-configuration.md) | 调度策略、亲和性 |
| 31 | Kubelet | [kubelet-configuration](./domain-4-workloads/31-kubelet-configuration.md) | Kubelet参数配置 |
| 32 | HPA/VPA | [hpa-vpa-autoscaling](./domain-4-workloads/32-hpa-vpa-autoscaling.md) | 水平/垂直自动扩缩 |
| 33 | 容量规划 | [cluster-capacity-planning](./domain-4-workloads/33-cluster-capacity-planning.md) | 资源预估、容量模型 |
| 34 | 资源管理 | [resource-management](./domain-4-workloads/34-resource-management.md) | Request/Limit、QoS |

---

### 域E: 网络 (Networking)

> 36 篇 | CNI、Service、DNS、Ingress、Gateway API、网络策略、服务网格、多集群网络

#### E1: 网络安全与策略

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 01 | NetworkPolicy实践 | [networkpolicy-deep-practice](./domain-5-networking/01-networkpolicy-deep-practice.md) | 生产级网络策略配置、零信任安全模型、策略设计模式 |
| 02 | 服务网格 | [service-mesh-deep-dive](./domain-5-networking/02-service-mesh-deep-dive.md) | Istio/Linkerd生产部署、Sidecar模式、流量治理 |
| 03 | 多集群网络 | [multi-cluster-federation](./domain-5-networking/03-multi-cluster-federation.md) | Cluster Federation、跨集群通信、VPC对等连接 |
| 04 | DNS优化 | [dns-service-discovery-coredns](./domain-5-networking/04-dns-service-discovery-coredns.md) | CoreDNS调优、NodeLocal DNSCache、性能监控 |

#### E2: 网络架构与CNI

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 05 | 网络架构 | [network-architecture-overview](./domain-5-networking/05-network-architecture-overview.md) | K8s网络模型、三层网络 |
| 06 | CNI架构 | [cni-architecture-fundamentals](./domain-5-networking/06-cni-architecture-fundamentals.md) | CNI规范、插件机制 |
| 07 | CNI对比 | [cni-plugins-comparison](./domain-5-networking/07-cni-plugins-comparison.md) | Flannel/Calico/Cilium对比 |
| 08 | Flannel | [flannel-complete-guide](./domain-5-networking/08-flannel-complete-guide.md) | VXLAN/host-gw模式 |
| 09 | Terway | [terway-advanced-guide](./domain-5-networking/09-terway-advanced-guide.md) | 阿里云ENI网络 |
| 10 | CNI排障 | [cni-troubleshooting-optimization](./domain-5-networking/10-cni-troubleshooting-optimization.md) | 网络故障诊断 |

#### E3: Service与服务发现

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 11 | Service概念 | [service-concepts-types](./domain-5-networking/11-service-concepts-types.md) | ClusterIP/NodePort/LB |
| 12 | Service实现 | [service-implementation-details](./domain-5-networking/12-service-implementation-details.md) | Endpoint、流量转发 |
| 13 | 拓扑感知 | [service-topology-aware](./domain-5-networking/13-service-topology-aware.md) | 拓扑感知路由 |
| 14 | kube-proxy | [kube-proxy-modes-performance](./domain-5-networking/14-kube-proxy-modes-performance.md) | 代理模式性能对比 |
| 15 | Service高级 | [service-advanced-features](./domain-5-networking/15-service-advanced-features.md) | 会话亲和、外部流量 |
| 260 | Service ACK实战 | [service-ack-practical-guide](./tables/service-ack-practical-guide.md) | 阿里云环境完整配置指南 |

#### E4: DNS与服务发现

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 16 | DNS发现 | [dns-service-discovery](./domain-5-networking/16-dns-service-discovery.md) | DNS服务发现机制 |
| 17 | CoreDNS架构 | [coredns-architecture-principles](./domain-5-networking/17-coredns-architecture-principles.md) | CoreDNS架构原理 |
| 18 | Corefile | [coredns-configuration-corefile](./domain-5-networking/18-coredns-configuration-corefile.md) | Corefile配置 |
| 19 | DNS插件 | [coredns-plugins-reference](./domain-5-networking/19-coredns-plugins-reference.md) | 插件详解 |
| 20 | DNS排障 | [coredns-troubleshooting-optimization](./domain-5-networking/20-coredns-troubleshooting-optimization.md) | DNS故障诊断 |

#### E5: 网络策略与安全

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 21 | 网络策略 | [network-policy-advanced](./domain-5-networking/21-network-policy-advanced.md) | NetworkPolicy高级配置 |
| 22 | mTLS加密 | [network-encryption-mtls](./domain-5-networking/22-network-encryption-mtls.md) | 服务间mTLS |
| 23 | Egress管理 | [egress-traffic-management](./domain-5-networking/23-egress-traffic-management.md) | 出站流量控制 |
| 24 | 多集群网络 | [multi-cluster-networking](./domain-5-networking/24-multi-cluster-networking.md) | 跨集群网络 |
| 25 | 网络排障 | [network-troubleshooting](./domain-5-networking/25-network-troubleshooting.md) | 网络故障排查 |
| 26 | 网络调优 | [network-performance-tuning](./domain-5-networking/26-network-performance-tuning.md) | 网络性能优化 |

#### E6: Ingress与流量入口

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 27 | Ingress基础 | [ingress-fundamentals](./domain-5-networking/27-ingress-fundamentals.md) | Ingress核心架构、路由配置、TLS、生产实践 |
| 28 | Ingress控制器 | [ingress-controller-deep-dive](./domain-5-networking/28-ingress-controller-deep-dive.md) | 控制器选型对比 |
| 29 | Nginx Ingress | [nginx-ingress-complete-guide](./domain-5-networking/29-nginx-ingress-complete-guide.md) | Nginx配置详解 |
| 30 | Ingress TLS | [ingress-tls-certificate](./domain-5-networking/30-ingress-tls-certificate.md) | TLS证书配置 |
| 31 | 高级路由 | [ingress-advanced-routing](./domain-5-networking/31-ingress-advanced-routing.md) | 路由规则、重写 |
| 32 | Ingress安全 | [ingress-security-hardening](./domain-5-networking/32-ingress-security-hardening.md) | 安全加固 |
| 33 | Ingress监控 | [ingress-monitoring-troubleshooting](./domain-5-networking/33-ingress-monitoring-troubleshooting.md) | 监控与排障 |
| 34 | Ingress实践 | [ingress-production-best-practices](./domain-5-networking/34-ingress-production-best-practices.md) | 生产最佳实践 |

#### E7: Gateway API与服务网格

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 35 | Gateway API | [gateway-api-overview](./domain-5-networking/35-gateway-api-overview.md) | 新一代流量管理 |
| 36 | API网关 | [api-gateway-patterns](./domain-5-networking/36-api-gateway-patterns.md) | 网关模式 |

---

### 域F: 存储 (Storage)

> 8 篇 | PV/PVC、StorageClass、CSI驱动、存储调优、备份恢复

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 73 | 存储架构 | [storage-architecture-overview](./domain-6-storage/73-storage-architecture-overview.md) | K8s存储架构 |
| 74 | PV架构 | [pv-architecture-fundamentals](./domain-6-storage/74-pv-architecture-fundamentals.md) | PersistentVolume详解 |
| 75 | PVC模式 | [pvc-patterns-practices](./domain-6-storage/75-pvc-patterns-practices.md) | PVC使用模式 |
| 76 | StorageClass | [storageclass-dynamic-provisioning](./domain-6-storage/76-storageclass-dynamic-provisioning.md) | 动态供给 |
| 77 | CSI驱动 | [csi-drivers-integration](./domain-6-storage/77-csi-drivers-integration.md) | CSI驱动集成 |
| 78 | 存储调优 | [storage-performance-tuning](./domain-6-storage/78-storage-performance-tuning.md) | IO性能优化 |
| 79 | 存储排障 | [pv-pvc-troubleshooting](./domain-6-storage/79-pv-pvc-troubleshooting.md) | PV/PVC故障排查 |
| 80 | 存储备份 | [storage-backup-disaster-recovery](./domain-6-storage/80-storage-backup-disaster-recovery.md) | 数据备份恢复 |

---

### 域G: 安全合规 (Security & Compliance)

> 16 篇 | 认证授权、网络安全、运行时安全、审计合规、安全实践、策略引擎

#### G1: 核心安全体系 (01-04)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 01 | 认证授权 | [authentication-authorization-system](./domain-7-security/01-authentication-authorization-system.md) | RBAC、OIDC、ServiceAccount、认证授权体系 |
| 02 | 网络安全 | [network-security-policies](./domain-7-security/02-network-security-policies.md) | NetworkPolicy、服务网格、零信任安全模型 |
| 03 | 运行时安全 | [runtime-security-defense](./domain-7-security/03-runtime-security-defense.md) | Seccomp/AppArmor、Falco威胁检测、运行时防护 |
| 04 | 审计合规 | [audit-logging-compliance](./domain-7-security/04-audit-logging-compliance.md) | 审计策略、日志收集、合规性检查、SOC2/ISO认证 |

#### G2: 安全实践与工具 (05-16)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 05 | 安全实践 | [security-best-practices](./domain-7-security/05-security-best-practices.md) | 安全最佳实践 |
| 06 | 安全加固 | [security-hardening-production](./domain-7-security/06-security-hardening-production.md) | 生产加固清单 |
| 07 | PSS标准 | [pod-security-standards](./domain-7-security/07-pod-security-standards.md) | Pod安全标准 |
| 08 | RBAC矩阵 | [rbac-matrix-configuration](./domain-7-security/08-rbac-matrix-configuration.md) | 权限矩阵配置 |
| 09 | 证书管理 | [certificate-management](./domain-7-security/09-certificate-management.md) | PKI、cert-manager |
| 10 | 镜像扫描 | [image-security-scanning](./domain-7-security/10-image-security-scanning.md) | 漏洞扫描 |
| 11 | 策略引擎 | [policy-engines-opa-kyverno](./domain-7-security/11-policy-engines-opa-kyverno.md) | OPA/Kyverno策略引擎对比 |
| 12 | 合规认证 | [compliance-certification](./domain-7-security/12-compliance-certification.md) | SOC2/ISO/PCI合规认证 |
| 13 | 审计实践 | [compliance-audit-practices](./domain-7-security/13-compliance-audit-practices.md) | 审计日志配置实践 |
| 14 | 密钥管理 | [secret-management-tools](./domain-7-security/14-secret-management-tools.md) | Vault/ESO集成 |
| 15 | 安全扫描 | [security-scanning-tools](./domain-7-security/15-security-scanning-tools.md) | Trivy/Falco安全扫描工具 |
| 16 | 策略验证 | [policy-validation-tools](./domain-7-security/16-policy-validation-tools.md) | 策略校验工具 |

---

### 域H: 可观测性 (Observability)

> 17 篇 | 架构体系、监控指标、日志审计、链路追踪、告警管理、故障排查、性能分析、混沌工程

#### H1: 监控与指标

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 01 | 架构概览 | [observability-architecture-overview](./domain-8-observability/01-observability-architecture-overview.md) | 可观测性架构体系 |
| 02 | 指标监控 | [monitoring-metrics-system](./domain-8-observability/02-monitoring-metrics-system.md) | Prometheus监控体系 |
| 03 | 日志架构 | [logging-architecture](./domain-8-observability/03-logging-architecture.md) | 日志收集架构 |
| 04 | 链路追踪 | [distributed-tracing](./domain-8-observability/04-distributed-tracing.md) | OpenTelemetry/Jaeger |
| 05 | 告警管理 | [alerting-management](./domain-8-observability/05-alerting-management.md) | SLO驱动告警策略 |
| 06 | Prometheus | [monitoring-metrics-prometheus](./domain-8-observability/06-monitoring-metrics-prometheus.md) | Prometheus监控体系 |
| 07 | 自定义指标 | [custom-metrics-adapter](./domain-8-observability/07-custom-metrics-adapter.md) | Metrics API扩展 |
| 10 | 可观测工具 | [observability-tools](./domain-8-observability/10-observability-tools.md) | 可观测性工具栈 |

#### H2: 日志与审计

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 08 | 日志审计 | [logging-auditing](./domain-8-observability/08-logging-auditing.md) | 日志收集架构 |
| 09 | 事件审计 | [events-audit-logs](./domain-8-observability/09-events-audit-logs.md) | K8s事件与审计 |
| 11 | 日志聚合 | [log-aggregation-tools](./domain-8-observability/11-log-aggregation-tools.md) | EFK/Loki方案 |

#### H3: 诊断与分析

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 12 | 排障概览 | [troubleshooting-overview](./domain-8-observability/12-troubleshooting-overview.md) | 生产级故障排查全攻略、版本特定问题、SOP流程 |
| 13 | 排障工具 | [troubleshooting-tools](./domain-8-observability/13-troubleshooting-tools.md) | kubectl debug/netshoot |
| 14 | 性能分析 | [performance-profiling-tools](./domain-8-observability/14-performance-profiling-tools.md) | pprof/perf |
| 15 | 健康检查 | [cluster-health-check](./domain-8-observability/15-cluster-health-check.md) | 集群健康检查 |

#### H4: 质量保障

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 16 | 混沌工程 | [chaos-engineering](./domain-8-observability/16-chaos-engineering.md) | Chaos Mesh/Litmus |
| 17 | 扩展性能 | [scaling-performance](./domain-8-observability/17-scaling-performance.md) | 扩展性测试 |

---

### 域I: 平台运维 (Platform Operations)

> 21 篇 | 运维体系、集群管理、监控告警、GitOps、自动化、成本优化、安全合规、灾备恢复

#### I1: 运维基础体系 (01-08)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 01 | 运维概览 | [platform-ops-overview](./domain-9-platform-ops/01-platform-ops-overview.md) | 平台运维职责、技术架构、成熟度模型 |
| 02 | 集群管理 | [cluster-lifecycle-management](./domain-9-platform-ops/02-cluster-lifecycle-management.md) | 集群生命周期、创建配置、扩缩容策略 |
| 03 | 监控告警 | [monitoring-alerting-system](./domain-9-platform-ops/03-monitoring-alerting-system.md) | Prometheus/Grafana、AlertManager、SLO/SLI |
| 04 | GitOps配置 | [gitops-configuration-management](./domain-9-platform-ops/04-gitops-configuration-management.md) | ArgoCD/FluxCD、声明式配置、自动化同步 |
| 05 | 自动化工具 | [automation-toolchain](./domain-9-platform-ops/05-automation-toolchain.md) | IaC、CI/CD、配置管理、故障自愈 |
| 06 | 成本优化 | [cost-optimization-finops](./domain-9-platform-ops/06-cost-optimization-finops.md) | Kubecost、资源优化、Spot实例、FinOps实践 |
| 07 | 安全合规 | [security-compliance](./domain-9-platform-ops/07-security-compliance.md) | 零信任安全、RBAC、网络策略、合规审计 |
| 08 | 灾备连续 | [disaster-recovery-business-continuity](./domain-9-platform-ops/08-disaster-recovery-business-continuity.md) | 备份恢复、多活架构、应急响应、RTO/RPO |

#### I2: 控制平面扩展 (09-15)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 09 | 准入控制 | [admission-controllers](./domain-9-platform-ops/09-admission-controllers.md) | Webhook配置、准入策略、验证变更 |
| 10 | CRD/Operator | [crd-operator-development](./domain-9-platform-ops/10-crd-operator-development.md) | 自定义资源、Operator开发、控制器模式 |
| 11 | API聚合 | [api-aggregation](./domain-9-platform-ops/11-api-aggregation.md) | API聚合层、扩展API Server |
| 12 | Lease选举 | [lease-leader-election](./domain-9-platform-ops/12-lease-leader-election.md) | Leader选举机制、高可用保障 |
| 13 | 客户端库 | [client-libraries](./domain-9-platform-ops/13-client-libraries.md) | client-go、SDK、编程接口 |
| 14 | CLI工具 | [cli-enhancement-tools](./domain-9-platform-ops/14-cli-enhancement-tools.md) | k9s、kubectx、kubectl插件 |
| 15 | 插件扩展 | [addons-extensions](./domain-9-platform-ops/15-addons-extensions.md) | 常用插件、扩展组件、生态工具 |

#### I3: 备份与容灾 (16-18)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 16 | 备份概览 | [backup-recovery-overview](./domain-9-platform-ops/16-backup-recovery-overview.md) | 备份策略规划、恢复演练、最佳实践 |
| 17 | Velero备份 | [backup-restore-velero](./domain-9-platform-ops/17-backup-restore-velero.md) | Velero完整配置、跨区域备份、恢复验证 |
| 18 | 容灾策略 | [disaster-recovery-strategy](./domain-9-platform-ops/18-disaster-recovery-strategy.md) | DR架构设计、多活部署、应急响应 |

#### I4: 多集群管理 (19-21)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 19 | 多集群 | [multi-cluster-management](./domain-9-platform-ops/19-multi-cluster-management.md) | 多集群架构、联邦管理、资源统筹 |
| 20 | 联邦集群 | [federated-cluster](./domain-9-platform-ops/20-federated-cluster.md) | KubeFed、跨集群协调、统一管理 |
| 21 | 虚拟集群 | [virtual-clusters](./domain-9-platform-ops/21-virtual-clusters.md) | vCluster、租户隔离、轻量级集群 |

---

### 域J: 扩展生态 (Extensions & Ecosystem)

> 13 篇 | 扩展开发、包管理、CI/CD、GitOps、构建工具、服务网格、运维基础

#### J1: 扩展开发 (01-04)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 01 | CRD开发 | [crd-development-guide](./domain-10-extensions/01-crd-development-guide.md) | 自定义资源定义开发 |
| 02 | Operator模式 | [operator-development-patterns](./domain-10-extensions/02-operator-development-patterns.md) | Kubebuilder开发实践 |
| 03 | 准入控制 | [admission-webhook-configuration](./domain-10-extensions/03-admission-webhook-configuration.md) | Webhook配置与实现 |
| 04 | API聚合 | [api-aggregation-extension](./domain-10-extensions/04-api-aggregation-extension.md) | API Server扩展机制 |

#### J2: 包管理与分发 (05-07)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 05 | 包管理 | [package-management-tools](./domain-10-extensions/05-package-management-tools.md) | Helm/Kustomize/Carvel对比 |
| 06 | Helm管理 | [helm-charts-management](./domain-10-extensions/06-helm-charts-management.md) | Chart开发基础 |
| 07 | Helm进阶 | [helm-advanced-operations](./domain-10-extensions/07-helm-advanced-operations.md) | 高级运维、CI/CD集成 |

#### J3: CI/CD与GitOps (08-09)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 08 | CI/CD流水线 | [cicd-pipelines](./domain-10-extensions/08-cicd-pipelines.md) | Jenkins/Tekton/云效 |
| 09 | ArgoCD | [gitops-workflow-argocd](./domain-10-extensions/09-gitops-workflow-argocd.md) | GitOps工作流、多集群管理 |

#### J4: 构建与部署工具 (10)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 10 | 镜像构建 | [image-build-tools](./domain-10-extensions/10-image-build-tools.md) | Buildah/Kaniko/ko构建工具 |

#### J5: 服务网格 (11-12)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 11 | 服务网格 | [service-mesh-overview](./domain-10-extensions/11-service-mesh-overview.md) | Istio/Linkerd概览 |
| 12 | 网格进阶 | [service-mesh-advanced](./domain-10-extensions/12-service-mesh-advanced.md) | 流量管理、可观测 |

#### J6: 运维基础 (13)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 13 | 运维基础 | [kubernetes-operations-fundamentals](./domain-10-extensions/13-kubernetes-operations-fundamentals.md) | 基础运维命令、集群管理、故障排查 |

---

### 域K: AI基础设施 (AI Infrastructure)

> 30 篇 | AI平台基础、模型训练、LLM专题、运维监控、成本优化

#### K1: AI平台基础 (01-04)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 01 | AI Infra概览 | [ai-infrastructure-overview](./domain-11-ai-infra/01-ai-infrastructure-overview.md) | AI基础设施架构全景 |
| 02 | ML工作负载 | [ai-ml-workloads](./domain-11-ai-infra/02-ai-ml-workloads.md) | 训练/推理工作负载运维 |
| 03 | GPU调度 | [gpu-scheduling-management](./domain-11-ai-infra/03-gpu-scheduling-management.md) | GPU资源调度与管理 |
| 04 | GPU监控 | [gpu-monitoring-dcgm](./domain-11-ai-infra/04-gpu-monitoring-dcgm.md) | DCGM/nvidia-smi监控 |

#### K2: 模型训练与数据 (05-12)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 05 | 分布式训练 | [distributed-training-frameworks](./domain-11-ai-infra/05-distributed-training-frameworks.md) | PyTorch DDP/FSDP |
| 06 | AI数据管道 | [ai-data-pipeline](./domain-11-ai-infra/06-ai-data-pipeline.md) | 数据预处理与特征工程 |
| 07 | 实验管理 | [ai-experiment-management](./domain-11-ai-infra/07-ai-experiment-management.md) | MLflow/W&B平台 |
| 08 | AutoML | [automl-hyperparameter-tuning](./domain-11-ai-infra/08-automl-hyperparameter-tuning.md) | Katib超参数调优 |
| 09 | 模型仓库 | [model-registry](./domain-11-ai-infra/09-model-registry.md) | 模型注册与版本管理 |
| 10 | 模型部署 | [model-deployment-management](./domain-11-ai-infra/10-model-deployment-management.md) | 模型生命周期管理 |
| 11 | AI安全 | [ai-security-model-protection](./domain-11-ai-infra/11-ai-security-model-protection.md) | 模型安全防护 |
| 12 | AI成本 | [ai-cost-analysis-finops](./domain-11-ai-infra/12-ai-cost-analysis-finops.md) | GPU成本分析与FinOps |

#### K3: AI平台运维 (13-14)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 13 | 平台可观测 | [ai-platform-observability](./domain-11-ai-infra/13-ai-platform-observability.md) | AI平台可观测性体系 |
| 14 | 故障排查 | [troubleshooting-performance](./domain-11-ai-infra/14-troubleshooting-performance.md) | 故障排查与性能优化 |

#### K4: LLM训练与推理 (15-21)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 15 | LLM数据管道 | [llm-data-pipeline](./domain-11-ai-infra/15-llm-data-pipeline.md) | 数据处理、Tokenizer |
| 16 | LLM微调 | [llm-finetuning](./domain-11-ai-infra/16-llm-finetuning.md) | LoRA/QLoRA微调 |
| 17 | LLM推理 | [llm-inference-serving](./domain-11-ai-infra/17-llm-inference-serving.md) | vLLM/TGI部署 |
| 18 | LLM架构 | [llm-serving-architecture](./domain-11-ai-infra/18-llm-serving-architecture.md) | 推理服务架构 |
| 19 | LLM量化 | [llm-quantization](./domain-11-ai-infra/19-llm-quantization.md) | GPTQ/AWQ/GGUF |
| 20 | 向量库/RAG | [vector-database-rag](./domain-11-ai-infra/20-vector-database-rag.md) | Milvus/Qdrant/RAG |
| 21 | 多模态 | [multimodal-models](./domain-11-ai-infra/21-multimodal-models.md) | 多模态模型部署 |

#### K5: LLM运维与监控 (22-25)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 22 | LLM安全 | [llm-privacy-security](./domain-11-ai-infra/22-llm-privacy-security.md) | OWASP LLM Top 10 |
| 23 | LLM成本 | [llm-cost-monitoring](./domain-11-ai-infra/23-llm-cost-monitoring.md) | Token成本分析 |
| 24 | 模型版本 | [llm-model-versioning](./domain-11-ai-infra/24-llm-model-versioning.md) | 模型版本管理 |
| 25 | LLM可观测 | [llm-observability](./domain-11-ai-infra/25-llm-observability.md) | 推理监控 |

#### K6: 成本与可持续 (26-30)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 26 | 成本优化 | [cost-optimization-overview](./domain-11-ai-infra/26-cost-optimization-overview.md) | 成本优化策略 |
| 27 | Kubecost | [cost-management-kubecost](./domain-11-ai-infra/27-cost-management-kubecost.md) | FinOps实践 |
| 28 | 绿色计算 | [green-computing-sustainability](./domain-11-ai-infra/28-green-computing-sustainability.md) | 碳排放、能效 |
| 29 | 阿里云集成 | [alibaba-cloud-integration](./domain-11-ai-infra/29-alibaba-cloud-integration.md) | ACK AI能力 |
| 30 | 安全合规 | [ai-security-compliance](./domain-11-ai-infra/30-ai-security-compliance.md) | AI平台安全加固 |

### 域Q: 云厂商Kubernetes服务 (Cloud Provider Kubernetes Services)

> 13 篇 | 主流公有云和国内云厂商的Kubernetes托管服务详解

#### Q1: 国际云厂商 (01-05)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 01 | 阿里云ACK | [alicloud-ack-overview](./domain-17-cloud-provider/01-alicloud-ack/alicloud-ack-overview.md) | 托管版/专有版双模式、Terway网络插件、RRSA身份联合、ASI Serverless节点 |
| 02 | 专有云ACK | [alicloud-apsara-ack](./domain-17-cloud-provider/02-alicloud-apsara-ack/250-apsara-stack-ess-scaling.md) | 专有云环境ESS伸缩、SLS日志服务、POP平台运维 |
| 03 | AWS EKS | [aws-eks-overview](./domain-17-cloud-provider/03-aws-eks/aws-eks-overview.md) | 托管控制平面、IAM集成、EKS Anywhere混合云、Bottlerocket OS |
| 04 | Azure AKS | [azure-aks-overview](./domain-17-cloud-provider/04-azure-aks/azure-aks-overview.md) | 免费控制平面、Azure AD集成、Confidential Containers、Dapr集成 |
| 05 | GCP GKE | [google-cloud-gke-overview](./domain-17-cloud-provider/05-google-cloud-gke/google-cloud-gke-overview.md) | Autopilot模式、Anthos Service Mesh、Config Connector、Borg技术传承 |

#### Q2: 国内云厂商 (06-13)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 06 | 腾讯云TKE | [tencent-tke-overview](./domain-17-cloud-provider/06-tencent-tke/tencent-tke-overview.md) | 万级节点支持、VPC-CNI网络、超级节点、CODING DevOps集成 |
| 07 | 华为云CCE | [huawei-cce-overview](./domain-17-cloud-provider/07-huawei-cce/huawei-cce-overview.md) | GPU节点优化、ASM服务网格、裸金属节点、软件开发生产线 |
| 08 | 天翼云TKE | [ctyun-tke-overview](./domain-17-cloud-provider/08-ctyun-tke/ctyun-tke-overview.md) | 电信级SLA、5G融合、国产化支持、边缘计算优化 |
| 09 | 移动云CKE | [ecloud-cke-overview](./domain-17-cloud-provider/09-ecloud-cke/ecloud-cke-overview.md) | 运营商网络优势、CDN集成、专属宿主机、政企定制方案 |
| 10 | IBM IKS | [ibm-iks-overview](./domain-17-cloud-provider/10-ibm-iks/ibm-iks-overview.md) | 企业级安全、多云支持、裸金属节点、Red Hat OpenShift集成 |
| 11 | Oracle OKE | [oracle-oke-overview](./domain-17-cloud-provider/11-oracle-oke/oracle-oke-overview.md) | OCI深度集成、裸金属节点、私有集群、企业级安全 |
| 12 | UCloud UK8S | [ucloud-uk8s-overview](./domain-17-cloud-provider/12-ucloud-uk8s/ucloud-uk8s-overview.md) | 联通网络支撑、5G切片技术、政企解决方案、混合云部署 |
| 13 | 字节云VEK | [volcengine-vek-overview](./domain-17-cloud-provider/13-volcengine-vek/volcengine-vek-overview.md) | 字节内部经验、高性能调度、智能运维、火山引擎生态 |

#### Q3: ACK关联产品 (240-245)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 240 | ECS计算 | [ack-ecs-compute](./domain-17-cloud-provider/01-alicloud-ack/240-ack-ecs-compute.md) | 实例规格选型、节点池配置、Spot策略、弹性伸缩组集成 |
| 241 | 负载均衡 | [ack-slb-nlb-alb](./domain-17-cloud-provider/01-alicloud-ack/241-ack-slb-nlb-alb.md) | CLB/NLB/ALB完整配置、生产级注解参考、多协议支持 |
| 242 | VPC网络 | [ack-vpc-network](./domain-17-cloud-provider/01-alicloud-ack/242-ack-vpc-network.md) | 网络规划、NAT网关、专线连接、安全组配置 |
| 243 | RAM权限 | [ack-ram-authorization](./domain-17-cloud-provider/01-alicloud-ack/243-ack-ram-authorization.md) | RRSA认证、权限矩阵、跨账号授权、安全最佳实践 |
| 244 | ROS编排 | [ack-ros-iac](./domain-17-cloud-provider/01-alicloud-ack/244-ack-ros-iac.md) | 资源模板、与Terraform对比、基础设施即代码 |
| 245 | EBS存储 | [ack-ebs-storage](./domain-17-cloud-provider/01-alicloud-ack/245-ack-ebs-storage.md) | ESSD性能优化、快照管理、加密配置、存储类动态供应 |

---

### 域L: 故障排查 (Troubleshooting)

> 38 篇 | 控制平面/节点/网络/存储/安全 全方位故障诊断

#### L1: 基础故障排查 (01-14)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 01 | API Server排障 | [control-plane-apiserver-troubleshooting](./domain-12-troubleshooting/01-control-plane-apiserver-troubleshooting.md) | API Server不可用、性能问题、认证授权故障 |
| 02 | etcd排障 | [control-plane-etcd-troubleshooting](./domain-12-troubleshooting/02-control-plane-etcd-troubleshooting.md) | etcd集群不可用、数据一致性、性能优化 |
| 03 | CNI网络排障 | [networking-cni-troubleshooting](./domain-12-troubleshooting/03-networking-cni-troubleshooting.md) | Pod网络不通、DNS解析失败、跨节点通信 |
| 04 | CSI驱动排障 | [storage-csi-troubleshooting](./domain-12-troubleshooting/04-storage-csi-troubleshooting.md) | 卷创建/挂载失败、存储性能问题、CSI组件故障 |
| 05 | Pod Pending诊断 | [pod-pending-diagnosis](./domain-12-troubleshooting/05-pod-pending-diagnosis.md) | Pod调度失败深度诊断 |
| 06 | Node NotReady诊断 | [node-notready-diagnosis](./domain-12-troubleshooting/06-node-notready-diagnosis.md) | 节点异常深度诊断 |
| 07 | OOM内存诊断 | [oom-memory-diagnosis](./domain-12-troubleshooting/07-oom-memory-diagnosis.md) | 内存溢出、驱逐问题排查 |
| 08 | Pod综合排障 | [pod-comprehensive-troubleshooting](./domain-12-troubleshooting/08-pod-comprehensive-troubleshooting.md) | Pod全状态故障排查 |
| 09 | Node综合排障 | [node-comprehensive-troubleshooting](./domain-12-troubleshooting/09-node-comprehensive-troubleshooting.md) | Node全方位故障诊断 |
| 10 | Service综合排障 | [service-comprehensive-troubleshooting](./domain-12-troubleshooting/10-service-comprehensive-troubleshooting.md) | Service访问失败、Endpoints问题 |
| 11 | Deployment排障 | [deployment-comprehensive-troubleshooting](./domain-12-troubleshooting/11-deployment-comprehensive-troubleshooting.md) | Deployment滚动更新、回滚问题 |
| 12 | RBAC/Quota排障 | [rbac-quota-troubleshooting](./domain-12-troubleshooting/12-rbac-quota-troubleshooting.md) | 权限不足、配额限制问题 |
| 13 | 证书排障 | [certificate-troubleshooting](./domain-12-troubleshooting/13-certificate-troubleshooting.md) | 证书过期、轮换问题 |
| 14 | PVC存储排障 | [pvc-storage-troubleshooting](./domain-12-troubleshooting/14-pvc-storage-troubleshooting.md) | PVC绑定、存储类问题 |

#### L2: 高级故障排查 (15-38)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 15 | Ingress排障 | [ingress-troubleshooting](./domain-12-troubleshooting/15-ingress-troubleshooting.md) | Ingress控制器、路由规则、TLS证书 |
| 16 | NetworkPolicy排障 | [networkpolicy-troubleshooting](./domain-12-troubleshooting/16-networkpolicy-troubleshooting.md) | 网络策略、安全组、微隔离 |
| 17 | HPA/VPA排障 | [hpa-vpa-troubleshooting](./domain-12-troubleshooting/17-hpa-vpa-troubleshooting.md) | 自动扩缩容配置、指标监控 |
| 18 | CronJob排障 | [cronjob-troubleshooting](./domain-12-troubleshooting/18-cronjob-troubleshooting.md) | 定时任务、并发控制、资源清理 |
| 19 | ConfigMap/Secret排障 | [configmap-secret-troubleshooting](./domain-12-troubleshooting/19-configmap-secret-troubleshooting.md) | 配置注入、热更新、安全性 |
| 20 | DaemonSet排障 | [daemonset-troubleshooting](./domain-12-troubleshooting/20-daemonset-troubleshooting.md) | 节点级服务、系统守护进程 |
| 21 | StatefulSet排障 | [statefulset-troubleshooting](./domain-12-troubleshooting/21-statefulset-troubleshooting.md) | 有状态应用、持久化、有序部署 |
| 22 | Job排障 | [job-troubleshooting](./domain-12-troubleshooting/22-job-troubleshooting.md) | 批处理任务、并行执行、完成策略 |
| 23 | Namespace排障 | [namespace-troubleshooting](./domain-12-troubleshooting/23-namespace-troubleshooting.md) | 资源隔离、配额管理、生命周期 |
| 24 | Quota/LimitRange排障 | [quota-limitrange-troubleshooting](./domain-12-troubleshooting/24-quota-limitrange-troubleshooting.md) | 资源限制、配额超限、默认值配置 |
| 25 | 网络连通性排障 | [network-connectivity-troubleshooting](./domain-12-troubleshooting/25-network-connectivity-troubleshooting.md) | Pod通信、Service访问、DNS解析 |
| 26 | DNS排障 | [dns-troubleshooting](./domain-12-troubleshooting/26-dns-troubleshooting.md) | CoreDNS配置、外部解析、缓存优化 |
| 27 | 镜像仓库排障 | [image-registry-troubleshooting](./domain-12-troubleshooting/27-image-registry-troubleshooting.md) | 镜像拉取、认证管理、网络代理 |
| 28 | 集群扩缩容排障 | [cluster-autoscaler-troubleshooting](./domain-12-troubleshooting/28-cluster-autoscaler-troubleshooting.md) | 扩缩容策略、节点驱逐、云API集成 |
| 29 | 云提供商排障 | [cloud-provider-troubleshooting](./domain-12-troubleshooting/29-cloud-provider-troubleshooting.md) | 认证权限、LoadBalancer、存储卷 |
| 30 | 监控告警排障 | [monitoring-alerting-troubleshooting](./domain-12-troubleshooting/30-monitoring-alerting-troubleshooting.md) | Prometheus、Alertmanager、Grafana |
| 31 | 备份恢复排障 | [backup-restore-troubleshooting](./domain-12-troubleshooting/31-backup-restore-troubleshooting.md) | Velero备份、etcd快照、灾难恢复 |
| 32 | 安全排障 | [security-troubleshooting](./domain-12-troubleshooting/32-security-troubleshooting.md) | 认证授权、网络安全、镜像安全 |
| 33 | 性能瓶颈排障 | [performance-bottleneck-troubleshooting](./domain-12-troubleshooting/33-performance-bottleneck-troubleshooting.md) | CPU/内存/存储/I/O瓶颈分析 |
| 34 | 升级迁移排障 | [upgrade-migration-troubleshooting](./domain-12-troubleshooting/34-upgrade-migration-troubleshooting.md) | 版本兼容性、滚动升级、回滚策略 |
| 35 | 节点组件排障 | [node-component-troubleshooting](./domain-12-troubleshooting/35-node-component-troubleshooting.md) | kubelet、容器运行时、kube-proxy |
| 36 | Helm Chart排障 | [helm-chart-troubleshooting](./domain-12-troubleshooting/36-helm-chart-troubleshooting.md) | Chart渲染、依赖管理、Release状态 |
| 37 | 多集群管理排障 | [multi-cluster-management-troubleshooting](./domain-12-troubleshooting/37-multi-cluster-management-troubleshooting.md) | 联邦控制、跨集群网络、故障转移 |
| 38 | GitOps/ArgoCD排障 | [gitops-argocd-troubleshooting](./domain-12-troubleshooting/38-gitops-argocd-troubleshooting.md) | ArgoCD同步失败、应用状态、RBAC配置 |

---

### 域M: Docker基础 (Docker Fundamentals)

> 11 篇 | Docker架构、镜像管理、容器生命周期、网络、存储、Compose、安全、故障排查、性能监控、日志管理、自动化运维，**从生产环境运维专家角度深度优化，新增企业级CI/CD集成方案和容器平台最佳实践**

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 01 | Docker架构 | [docker-architecture-overview](./domain-13-docker/01-docker-architecture-overview.md) | Docker Engine、containerd、OCI标准 |
| 02 | 镜像管理 | [docker-images-management](./domain-13-docker/02-docker-images-management.md) | 镜像层、Dockerfile、多阶段构建、安全扫描 |
| 03 | 容器生命周期 | [docker-container-lifecycle](./domain-13-docker/03-docker-container-lifecycle.md) | 容器状态、资源限制、健康检查、日志 |
| 04 | Docker网络 | [docker-networking-deep-dive](./domain-13-docker/04-docker-networking-deep-dive.md) | 网络驱动、DNS、端口映射、网络排障 |
| 05 | Docker存储 | [docker-storage-volumes](./domain-13-docker/05-docker-storage-volumes.md) | 存储驱动、Volume、Bind Mount、备份 |
| 06 | Compose | [docker-compose-orchestration](./domain-13-docker/06-docker-compose-orchestration.md) | Compose配置、多环境、生产配置 |
| 07 | Docker安全 | [docker-security-best-practices](./domain-13-docker/07-docker-security-best-practices.md) | 镜像安全、运行时安全、Seccomp、能力 |
| 08 | Docker排障 | [docker-troubleshooting-guide](./domain-13-docker/08-docker-troubleshooting-guide.md) | 常见问题诊断、网络/存储排障 |
| 09 | 性能监控 | [docker-performance-monitoring](./domain-13-docker/09-docker-performance-monitoring.md) | 监控指标、调优策略、容量规划 |
| 10 | 日志管理 | [docker-logging-management](./domain-13-docker/10-docker-logging-management.md) | 日志收集、分析、ELK集成 |
| 11 | 自动化运维 | [docker-automation-devops](./domain-13-docker/11-docker-automation-devops.md) | CI/CD、IaC、自动部署、**新增企业级DevOps工具链集成和智能运维方案** |

---

### 域N: Linux基础 (Linux Fundamentals)

> 9 篇 | 系统架构、进程管理、文件系统、网络配置、存储管理、性能调优、安全加固、容器技术、运维基础，**从生产环境运维专家角度深度优化，新增大量企业级最佳实践和自动化运维方案**

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 01 | Linux架构 | [linux-system-architecture](./domain-14-linux/01-linux-system-architecture.md) | 内核架构、启动过程、systemd、内核调优、**生产环境系统基线配置、监控告警、安全加固** |
| 02 | 进程管理 | [linux-process-management](./domain-14-linux/02-linux-process-management.md) | 进程状态、信号、优先级、监控分析、**生产环境进程管理、性能诊断、自动化运维** |
| 03 | 文件系统 | [linux-filesystem-deep-dive](./domain-14-linux/03-linux-filesystem-deep-dive.md) | VFS、文件系统类型、权限、inode、**生产环境文件系统选择与优化** |
| 04 | 网络配置 | [linux-networking-configuration](./domain-14-linux/04-linux-networking-configuration.md) | ip/ss命令、路由、iptables、网络调优、**生产环境网络安全配置与性能优化** |
| 05 | 存储管理 | [linux-storage-management](./domain-14-linux/05-linux-storage-management.md) | LVM、软件RAID、I/O调度、配额、**生产环境存储架构与性能调优** |
| 06 | 性能调优 | [linux-performance-tuning](./domain-14-linux/06-linux-performance-tuning.md) | CPU/内存/I/O/网络分析、内核参数、**生产环境性能监控与瓶颈诊断** |
| 07 | 安全加固 | [linux-security-hardening](./domain-14-linux/07-linux-security-hardening.md) | 用户管理、SSH、PAM、SELinux、审计、**生产环境企业级安全策略与合规要求** |
| 08 | 容器技术 | [linux-container-fundamentals](./domain-14-linux/08-linux-container-fundamentals.md) | Namespaces、Cgroups、OverlayFS、安全、**生产环境容器安全与性能优化** |
| 09 | 运维基础 | [linux-operations-basics](./domain-14-linux/09-linux-operations-basics.md) | 系统监控、故障排查、备份恢复、自动化、**生产环境运维流程与应急响应，新增企业级监控告警体系和标准化故障处理SOP** |

---

### 域O: 网络基础 (Network Fundamentals)

> 6 篇 | 协议栈、TCP/UDP、DNS、负载均衡、网络安全、SDN，从生产环境运维专家角度深度优化

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 01 | 协议栈 | [network-protocols-stack](./domain-15-network-fundamentals/01-network-protocols-stack.md) | OSI/TCP-IP模型、数据封装、协议概览、**生产环境网络诊断与性能调优** |
| 02 | TCP/UDP | [tcp-udp-deep-dive](./domain-15-network-fundamentals/02-tcp-udp-deep-dive.md) | 连接管理、流量控制、拥塞控制、对比、**生产环境连接池优化与性能监控** |
| 03 | DNS | [dns-principles-configuration](./domain-15-network-fundamentals/03-dns-principles-configuration.md) | DNS解析、记录类型、配置、排障、**DNS缓存优化、安全配置、大规模部署最佳实践** |
| 04 | 负载均衡 | [load-balancing-technologies](./domain-15-network-fundamentals/04-load-balancing-technologies.md) | 算法、L4/L7负载均衡、健康检查、**负载均衡器选型、性能基准、高可用部署** |
| 05 | 网络安全 | [network-security-fundamentals](./domain-15-network-fundamentals/05-network-security-fundamentals.md) | 攻击类型、防火墙、TLS、VPN、**零信任网络架构、DDoS防护、安全运营最佳实践** |
| 06 | SDN | [sdn-network-virtualization](./domain-15-network-fundamentals/06-sdn-network-virtualization.md) | SDN架构、Overlay、容器网络、服务网格、**网络虚拟化性能优化、多租户隔离、生产部署指南** |

---

### 域P: 存储基础 (Storage Fundamentals)

> 6 篇 | 从生产环境运维专家角度深度优化的存储技术体系，涵盖存储架构、类型详解、RAID配置、分布式系统、性能调优和企业级运维实践

---

## 实用工具

> **维护工具**: 项目管理和验证脚本

### 运维知识中枢 (topic-dictionary)

> **生产环境运维专家级知识库** | 7个核心文档 | 覆盖运维最佳实践、故障分析、性能调优等专业领域

| # | 文档名称 | 关键内容 | 适用场景 |
|:---:|:---|:---|:---|
| 01 | [运维最佳实践](./topic-dictionary/01-operations-best-practices.md) | **生产环境配置标准、高可用架构模式、安全加固指南、监控告警最佳实践、灾备恢复方案、自动化运维策略、成本优化实践、多集群管理规范** | 企业级Kubernetes生产环境部署和运维 |
| 02 | [故障模式分析](./topic-dictionary/02-failure-patterns-analysis.md) | **常见故障模式分类、根因分析方法论、故障树分析(FMEA)、MTTR优化策略、故障复盘模板、预防措施体系** | 故障诊断、根因分析、问题预防 |
| 03 | [性能调优专家](./topic-dictionary/03-performance-tuning-expert.md) | **系统性能瓶颈识别、资源优化策略、调度器调优参数、网络性能优化、存储IO调优、应用层性能优化、监控与基准测试** | 性能优化、容量规划、系统调优 |
| 04 | [SRE成熟度模型](./topic-dictionary/04-sre-maturity-model.md) | **运维成熟度评估标准、自动化能力分级、监控体系建设指南、运维流程标准化、团队能力建设路径、成熟度评估工具** | SRE团队建设、运维能力提升、组织成熟度评估 |
| 05 | [概念参考手册](./topic-dictionary/05-concept-reference.md) | **Kubernetes核心概念、API与认证机制、控制平面组件、工作负载资源、网络与服务发现、存储管理、安全与权限控制、可观测性与监控、分布式系统理论、AI/ML工程概念** | 技术概念查询、知识学习、术语参考 |
| 06 | [命令行清单](./topic-dictionary/06-cli-commands.md) | **kubectl基础命令、集群管理命令、Pod调试与交互命令、资源创建与管理命令、集群配置参数、GPU调度与管理命令、AI/ML工作负载命令、故障排查工具命令、安全与认证命令、监控与告警命令** | 日常运维操作、故障排查、命令参考 |
| 07 | [工具生态系统](./topic-dictionary/07-tool-ecosystem.md) | **Kubernetes核心工具、容器运行时工具、容器网络工具、容器存储工具、Ingress控制器、服务网格工具、DNS与服务发现、包管理与部署工具、GitOps与CI/CD工具、基础设施即代码工具、镜像构建与仓库工具** | 工具选型、技术栈搭建、生态集成 |

### 链接验证工具

| 工具 | 位置 | 功能 |
|:---|:---|:---|
| **链接验证脚本** | [topic-dictionary/validate-links.ps1](./topic-dictionary/validate-links.ps1) | 验证README和演示文档中的链接有效性 |

该PowerShell脚本可以帮助维护人员快速检查项目中所有文档链接的完整性，确保引用路径的准确性。

---

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 01 | 存储概述 | [storage-technologies-overview](./domain-16-storage-fundamentals/01-storage-technologies-overview.md) | 存储类型、架构、协议、云存储、**生产环境最佳实践与性能调优策略** |
| 02 | 存储类型 | [block-file-object-storage](./domain-16-storage-fundamentals/02-block-file-object-storage.md) | 块存储、文件存储、对象存储对比、**企业级配置与故障排查** |
| 03 | RAID | [raid-storage-redundancy](./domain-16-storage-fundamentals/03-raid-storage-redundancy.md) | RAID级别、配置、监控、硬件/软件对比、**实际运维经验与性能基准** |
| 04 | 分布式存储 | [distributed-storage-systems](./domain-16-storage-fundamentals/04-distributed-storage-systems.md) | Ceph、MinIO、GlusterFS、**生产部署指南与监控运维** |
| 05 | 存储管理 | [storage-management-operations](./domain-16-storage-fundamentals/05-storage-management-operations.md) | **企业级存储运维实践**、监控告警、容量规划、备份恢复、故障处理、性能优化 |
| 06 | 存储性能 | [storage-performance-iops](./domain-16-storage-fundamentals/06-storage-performance-iops.md) | IOPS、吞吐量、延迟、测试优化、**真实环境测试数据与调优案例** |

---

## 多维度查询附录

### 附录A: 开发者视角

> 关注点: 应用部署、服务暴露、配置管理、日志调试

| 场景 | 推荐文档 | 优先级 |
|:---|:---|:---:|
| **快速上手** | [05-kubectl](./tables/05-kubectl-commands-reference.md), [21-工作负载](./domain-4-workloads/21-workload-controllers-overview.md) | P0 |
| **部署应用** | [21-工作负载](./domain-4-workloads/21-workload-controllers-overview.md), [22-Pod生命周期](./domain-4-workloads/22-pod-lifecycle-events.md), [06-Helm管理](./domain-10-extensions/06-helm-charts-management.md) | P0 |
| **服务暴露** | [47-Service](./domain-5-networking/47-service-concepts-types.md), [63-Ingress](./domain-5-networking/63-ingress-fundamentals.md), [71-Gateway API](./domain-5-networking/71-gateway-api-overview.md) | P0 |
| **配置管理** | [14-Secret管理](./domain-7-security/14-secret-management-tools.md), [08-RBAC矩阵](./domain-7-security/08-rbac-matrix-configuration.md) | P1 |
| **日志调试** | [95-日志](./domain-8-observability/95-logging-auditing.md), [100-排障工具](./domain-8-observability/100-troubleshooting-tools.md), [08-Pod排障](./domain-12-troubleshooting/08-pod-comprehensive-troubleshooting.md) | P1 |
| **CI/CD集成** | [08-CI/CD](./domain-10-extensions/08-cicd-pipelines.md), [09-ArgoCD](./domain-10-extensions/09-gitops-workflow-argocd.md), [10-镜像构建](./domain-10-extensions/10-image-build-tools.md) | P1 |
| **Operator开发** | [112-CRD/Operator](./domain-9-platform-ops/112-crd-operator-development.md), [115-client-go](./domain-9-platform-ops/115-client-libraries.md), [13-控制器模式](./tables/13-controller-pattern-reconciliation.md) | P2 |
| **性能优化** | [32-HPA/VPA](./domain-4-workloads/32-hpa-vpa-autoscaling.md), [34-资源管理](./domain-4-workloads/34-resource-management.md) | P2 |

---

### 附录B: 运维工程师视角

> 关注点: 集群运维、故障排查、监控告警、容量管理

| 场景 | 推荐文档 | 优先级 |
|:---|:---|:---:|
| **集群部署** | [06-集群配置](./tables/06-cluster-configuration-parameters.md), [31-Kubelet](./domain-4-workloads/31-kubelet-configuration.md), [35-etcd](./domain-3-control-plane/35-etcd-deep-dive.md) | P0 |
| **日常运维** | [29-节点管理](./domain-4-workloads/29-node-management-operations.md), [07-升级策略](./tables/07-upgrade-paths-strategy.md), [110-etcd运维](./tables/110-etcd-operations.md) | P0 |
| **监控告警** | [93-Prometheus](./domain-8-observability/93-monitoring-metrics-prometheus.md), [97-可观测工具](./domain-8-observability/97-observability-tools.md), [105-健康检查](./domain-8-observability/105-cluster-health-check.md) | P0 |
| **故障排查** | [99-排障概览](./domain-8-observability/99-troubleshooting-overview.md), [100-排障工具](./domain-8-observability/100-troubleshooting-tools.md), [01-API Server](./domain-12-troubleshooting/01-control-plane-apiserver-troubleshooting.md), [02-etcd](./domain-12-troubleshooting/02-control-plane-etcd-troubleshooting.md), [05-Pod Pending](./domain-12-troubleshooting/05-pod-pending-diagnosis.md), [06-Node NotReady](./domain-12-troubleshooting/06-node-notready-diagnosis.md), [15-Ingress](./domain-12-troubleshooting/15-ingress-troubleshooting.md), [35-节点组件](./domain-12-troubleshooting/35-node-component-troubleshooting.md) | P0 |
| **网络运维** | [03-CNI排障](./domain-12-troubleshooting/03-networking-cni-troubleshooting.md), [16-NetworkPolicy](./domain-12-troubleshooting/16-networkpolicy-troubleshooting.md), [25-网络连通性](./domain-12-troubleshooting/25-network-connectivity-troubleshooting.md), [26-DNS排障](./domain-12-troubleshooting/26-dns-troubleshooting.md), [46-CNI排障](./domain-5-networking/46-cni-troubleshooting-optimization.md), [56-DNS排障](./domain-5-networking/56-coredns-troubleshooting-optimization.md), [61-网络排障](./domain-5-networking/61-network-troubleshooting.md) | P1 |
| **存储运维** | [04-CSI排障](./domain-12-troubleshooting/04-storage-csi-troubleshooting.md), [14-PVC排障](./domain-12-troubleshooting/14-pvc-storage-troubleshooting.md), [31-备份恢复](./domain-12-troubleshooting/31-backup-restore-troubleshooting.md), [79-存储排障](./domain-6-storage/79-pv-pvc-troubleshooting.md), [80-存储备份](./domain-6-storage/80-storage-backup-disaster-recovery.md) | P1 |
| **备份恢复** | [16-备份概览](./domain-9-platform-ops/16-backup-recovery-overview.md), [17-Velero](./domain-9-platform-ops/17-backup-restore-velero.md), [18-容灾策略](./domain-9-platform-ops/18-disaster-recovery-strategy.md) | P1 |
| **容量规划** | [33-容量规划](./domain-4-workloads/33-cluster-capacity-planning.md), [107-扩展性能](./domain-8-observability/107-scaling-performance.md) | P2 |
| **安全架构** | [01-认证授权](./domain-7-security/01-authentication-authorization-system.md), [02-网络安全](./domain-7-security/02-network-security-policies.md), [03-运行时安全](./domain-7-security/03-runtime-security-defense.md), [04-审计合规](./domain-7-security/04-audit-logging-compliance.md), [12-合规认证](./domain-7-security/12-compliance-certification.md), [07-安全合规](./domain-9-platform-ops/07-security-compliance.md) | P1 |

---

### 附录C: 架构师视角

> 关注点: 架构设计、高可用、多集群、技术选型

| 场景 | 推荐文档 | 优先级 |
|:---|:---|:---:|
| **架构设计** | [01-K8s架构](./tables/01-kubernetes-architecture-overview.md), [02-核心组件](./tables/02-core-components-deep-dive.md), [11-设计原则](./tables/11-kubernetes-design-principles.md) | P0 |
| **设计原理** | [12-声明式API](./tables/12-declarative-api-pattern.md), [13-控制器模式](./tables/13-controller-pattern-reconciliation.md), [20-CAP定理](./tables/20-cap-theorem-distributed-systems.md) | P0 |
| **高可用设计** | [18-高可用模式](./tables/18-high-availability-patterns.md), [17-etcd共识](./tables/17-distributed-consensus-etcd.md), [18-容灾策略](./domain-9-platform-ops/18-disaster-recovery-strategy.md) | P0 |
| **控制平面** | [35-etcd](./domain-3-control-plane/35-etcd-deep-dive.md), [36-API Server](./domain-3-control-plane/36-kube-apiserver-deep-dive.md), [37-KCM](./domain-3-control-plane/37-kube-controller-manager-deep-dive.md), [164-Scheduler](./domain-3-control-plane/164-kube-scheduler-deep-dive.md) | P0 |
| **多集群架构** | [19-多集群](./domain-9-platform-ops/19-multi-cluster-management.md), [20-联邦集群](./domain-9-platform-ops/20-federated-cluster.md), [60-多集群网络](./domain-5-networking/60-multi-cluster-networking.md) | P1 |
| **网络架构** | [41-网络架构](./domain-5-networking/41-network-architecture-overview.md), [43-CNI对比](./domain-5-networking/43-cni-plugins-comparison.md), [167-CNI详解](./domain-3-control-plane/167-cni-container-network-deep-dive.md) | P1 |
| **存储架构** | [73-存储架构](./domain-6-storage/73-storage-architecture-overview.md), [166-CSI详解](./domain-3-control-plane/166-csi-container-storage-deep-dive.md) | P1 |
| **运行时选型** | [165-CRI详解](./domain-3-control-plane/165-cri-container-runtime-deep-dive.md), [27-RuntimeClass](./domain-4-workloads/27-runtime-class-configuration.md) | P2 |
| **服务网格** | [11-服务网格](./domain-10-extensions/11-service-mesh-overview.md), [12-网格进阶](./domain-10-extensions/12-service-mesh-advanced.md) | P2 |
| **AI基础设施** | [01-AI Infra](./domain-11-ai-infra/01-ai-infrastructure-overview.md), [18-LLM架构](./domain-11-ai-infra/18-llm-serving-architecture.md) | P2 |

---

### 附录D: 测试工程师视角

> 关注点: 测试环境、混沌工程、性能测试、CI集成

| 场景 | 推荐文档 | 优先级 |
|:---|:---|:---:|
| **环境搭建** | [21-虚拟集群](./domain-9-platform-ops/21-virtual-clusters.md), [06-集群配置](./tables/06-cluster-configuration-parameters.md) | P0 |
| **混沌工程** | [106-混沌工程](./domain-8-observability/106-chaos-engineering.md) | P0 |
| **性能测试** | [101-性能分析](./domain-8-observability/101-performance-profiling-tools.md), [107-扩展性能](./domain-8-observability/107-scaling-performance.md), [62-网络调优](./domain-5-networking/62-network-performance-tuning.md) | P0 |
| **CI/CD集成** | [08-CI/CD](./domain-10-extensions/08-cicd-pipelines.md), [10-镜像构建](./domain-10-extensions/10-image-build-tools.md) | P1 |
| **安全测试** | [10-镜像扫描](./domain-7-security/10-image-security-scanning.md), [15-安全扫描](./domain-7-security/15-security-scanning-tools.md) | P1 |
| **可观测性** | [93-Prometheus](./domain-8-observability/93-monitoring-metrics-prometheus.md), [95-日志](./domain-8-observability/95-logging-auditing.md), [97-可观测工具](./domain-8-observability/97-observability-tools.md) | P2 |
| **故障注入** | [106-混沌工程](./domain-8-observability/106-chaos-engineering.md), [99-排障概览](./domain-8-observability/99-troubleshooting-overview.md) | P2 |

---

### 附录E: 产品经理视角

> 关注点: 架构理解、成本分析、能力边界、技术选型

| 场景 | 推荐文档 | 优先级 |
|:---|:---|:---:|
| **架构理解** | [01-K8s架构](./tables/01-kubernetes-architecture-overview.md), [11-设计原则](./tables/11-kubernetes-design-principles.md) | P0 |
| **成本分析** | [26-成本优化](./domain-11-ai-infra/26-cost-optimization-overview.md), [27-Kubecost](./domain-11-ai-infra/27-cost-management-kubecost.md), [12-AI成本](./domain-11-ai-infra/12-ai-cost-analysis-finops.md) | P0 |
| **AI能力** | [01-AI Infra](./domain-11-ai-infra/01-ai-infrastructure-overview.md), [17-LLM推理](./domain-11-ai-infra/17-llm-inference-serving.md), [23-LLM成本](./domain-11-ai-infra/23-llm-cost-monitoring.md) | P1 |
| **多租户** | [08-多租户](./tables/08-multi-tenancy-architecture.md), [08-RBAC矩阵](./domain-7-security/08-rbac-matrix-configuration.md) | P1 |
| **合规认证** | [12-合规认证](./domain-7-security/12-compliance-certification.md), [13-审计实践](./domain-7-security/13-compliance-audit-practices.md) | P1 |
| **高可用** | [18-高可用模式](./tables/18-high-availability-patterns.md), [18-容灾策略](./domain-9-platform-ops/18-disaster-recovery-strategy.md) | P2 |
| **边缘计算** | [09-边缘计算](./tables/09-edge-computing-kubeedge.md) | P2 |
| **绿色计算** | [28-绿色计算](./domain-11-ai-infra/28-green-computing-sustainability.md) | P2 |

---

### 附录F: 终端用户视角

> 关注点: 应用部署、状态查看、日志获取、问题定位

| 场景 | 推荐文档 | 优先级 |
|:---|:---|:---:|
| **基础操作** | [05-kubectl](./tables/05-kubectl-commands-reference.md), [14-CLI工具](./domain-9-platform-ops/14-cli-enhancement-tools.md) | P0 |
| **应用部署** | [06-Helm管理](./domain-10-extensions/06-helm-charts-management.md), [09-ArgoCD](./domain-10-extensions/09-gitops-workflow-argocd.md) | P0 |
| **状态查看** | [22-Pod生命周期](./domain-4-workloads/22-pod-lifecycle-events.md), [105-健康检查](./domain-8-observability/105-cluster-health-check.md) | P1 |
| **日志获取** | [95-日志](./domain-8-observability/95-logging-auditing.md), [98-日志聚合](./domain-8-observability/98-log-aggregation-tools.md) | P1 |
| **问题定位** | [08-Pod综合排障](./domain-12-troubleshooting/08-pod-comprehensive-troubleshooting.md), [10-Service排障](./domain-12-troubleshooting/10-service-comprehensive-troubleshooting.md), [15-Ingress排障](./domain-12-troubleshooting/15-ingress-troubleshooting.md), [35-节点组件](./domain-12-troubleshooting/35-node-component-troubleshooting.md) | P1 |
| **资源配置** | [34-资源管理](./domain-4-workloads/34-resource-management.md), [32-HPA/VPA](./domain-4-workloads/32-hpa-vpa-autoscaling.md) | P2 |

---

## 变更记录

### 2026-02 Topic Dictionary 运维知识中枢全面升级

**生产环境运维专家级知识库重构完成**:
- ✅ 新增4个专业运维文档：运维最佳实践(01)、故障模式分析(02)、性能调优专家(03)、SRE成熟度模型(04)
- ✅ 现有文档重新编号：概念参考手册(05)、命令行清单(06)、工具生态系统(07)
- ✅ 所有文档按01-07连续编号，确保结构清晰和易维护性
- ✅ 丰富运维最佳实践内容：生产环境配置标准、高可用架构、安全加固、监控告警、灾备恢复等
- ✅ 完善故障分析体系：故障模式分类、根因分析方法论、MTTR优化策略、预防措施体系
- ✅ 强化性能调优能力：瓶颈识别、资源优化、调度器调优、网络存储优化等专家级指导
- ✅ 建立SRE成熟度模型：评估标准、自动化分级、监控体系建设、团队能力建设路径
- ✅ 更新根目录README，添加详细的topic-dictionary介绍和导航
- ✅ 提供完整的生产环境运维知识体系，覆盖从基础操作到专家级实践

### 2026-02 Domain-17 云厂商Kubernetes服务全面升级

**云厂商Kubernetes服务文档体系重构完成**:
- ✅ 重新组织domain-17-cloud-provider目录结构，采用数字编号(01-13)标准化命名
- ✅ 丰富核心云厂商文档内容，增加生产环境运维专家级详细配置
- ✅ 补充阿里云ACK、AWS EKS、GCP GKE、Azure AKS、腾讯云TKE、天翼云TKE、IBM IKS等主要厂商的深度技术文档
- ✅ 完善安全加固、监控告警、成本优化、故障排查等生产实践内容
- ✅ 更新README中domain-17章节结构，重新分类国际云厂商和国内云厂商
- ✅ 整合ACK关联产品文档(240-245)到新的目录结构中
- ✅ 提供完整的多云Kubernetes生产环境运维实践指南

### 2026-02 Kubernetes扩展生态体系完善

**Domain-10扩展生态文档体系重构完成**:
- ✅ 补充完整的扩展开发生态文档(01-04): CRD开发指南、Operator开发模式、准入控制器配置、API聚合扩展
- ✅ 重构扩展生态文档结构: 运维基础技能(05) + CI/CD与GitOps(06-07) + 包管理与构建(08-11) + 服务网格(12-13) + 扩展开发(01-04)
- ✅ 重新编号所有扩展生态文档: 124-130 → 01-13
- ✅ 更新README中domain-10扩展生态章节结构和链接
- ✅ 同步更新各角色附录中的扩展生态相关文档引用
- ✅ 提供完整的Kubernetes扩展开发与运维实践指南

### 2026-02 平台运维体系完善

**Domain-9平台运维文档体系重构完成**:
- ✅ 新增核心运维体系文档(01-08): 运维概览、集群管理、监控告警、GitOps、自动化工具链、成本优化、安全合规、灾备连续性
- ✅ 重构平台运维文档结构: 运维基础体系(01-08) + 控制平面扩展(09-15) + 备份容灾(16-18) + 多集群管理(19-21)
- ✅ 重新编号所有平台运维文档: 111-123 → 01-21
- ✅ 更新README中domain-9平台运维章节结构和链接
- ✅ 同步更新各角色附录中的平台运维相关文档引用
- ✅ 提供完整的Kubernetes生产环境平台运维实践指南

### 2026-02 安全合规体系增强

**Domain-7安全文档体系重构完成**:
- ✅ 新增核心安全体系文档(01-04): 认证授权、网络安全、运行时安全、审计合规
- ✅ 重构安全文档结构: 核心安全体系(01-04) + 安全实践工具(05-16)
- ✅ 重新编号所有安全文档: 81-92 → 01-16
- ✅ 更新README中domain-7安全合规章节结构和链接
- ✅ 同步更新各角色附录中的安全相关文档引用
- ✅ 提供完整的Kubernetes生产环境安全实践指南

### 2026-02 目录结构优化

**项目结构重组完成**:
- ✅ 创建 `domain-17-cloud-provider` 统一管理所有云厂商文档
- ✅ 将所有 `cloud-*` 目录移动到 `domain-17-cloud-provider/` 下
- ✅ 重命名 `presentations` → `topic-presentations`
- ✅ 重命名 `trouble-shooting` → `topic-trouble-shooting`
- ✅ 更新 README 中所有相关链接
- ✅ 验证所有链接有效性

### 2026-02 域名数字化改造

**域名命名标准化完成**:
- ✅ 将所有域名从字母格式(`domain-a-`, `domain-b-`)转换为数字格式(`domain-1-`, `domain-2-`)
- ✅ 更新 README 中所有 219 个文件链接指向正确的数字域名目录
- ✅ 验证所有链接有效性，确保文档可正常访问
- ✅ 更新域统计信息和表格数量统计

### 2026-02 扩展生态文档体系优化

**Domain-10扩展生态文档体系重构完成**:
- ✅ 重新排序所有扩展生态文档，按开发流程逻辑顺序排列：扩展开发→包管理→CI/CD→服务网格→运维基础
- ✅ 重新编号所有扩展生态文档: 01-13，保持连续性
- ✅ 更新README中domain-10扩展生态章节结构和链接
- ✅ 同步更新各角色附录中的扩展生态相关文档引用
- ✅ 提供完整的Kubernetes扩展开发生态实践指南

### 2026-02 AI基础设施文档体系优化

**Domain-11 AI基础设施文档体系重构完成**:
- ✅ 重新排序所有AI/LLM文档，按知识体系逻辑顺序排列：AI基础→模型训练→LLM专题→运维监控→成本优化
- ✅ 重新编号所有AI/LLM文档: 01-30，保持连续性
- ✅ 更新README中domain-11 AI基础设施章节结构和链接
- ✅ 同步更新各角色附录中的AI/LLM相关文档引用
- ✅ 提供完整的AI/LLM生产环境实践指南

### 2026-02 故障排查文档体系优化

**Domain-12故障排查文档体系完善完成**:
- ✅ 修正所有故障排查文档的标题编号，使其与文件名保持一致
- ✅ 验证所有38篇故障排查文档的完整性和一致性
- ✅ 更新README中domain-12故障排查章节结构和链接
- ✅ 同步更新各角色附录中的故障排查相关文档引用
- ✅ 提供完整的Kubernetes生产环境故障排查实践指南

### 2026-02 故障排查文档体系优化

**Domain-12故障排查文档体系完善完成**:
- ✅ 全面检查所有38篇故障排查文档的内容质量和结构完整性
- ✅ 优化文档结构，补充缺失的目录、概述和解决方案章节
- ✅ 统一编号系统，确保文件名与标题编号完全一致
- ✅ 更新SUMMARY.md文档清单，使用01-38的新编号系统
- ✅ 提升文档质量标准，增加自动化诊断工具和最佳实践
- ✅ 提供完整的Kubernetes生产环境故障排查知识体系

### 2026-02 根目录结构优化

**项目结构重组完成**:
- ✅ 根目录精简至仅保留 README.md
- ✅ `validate-links.ps1` 脚本移至 `topic-dictionary/` 目录
- ✅ 完善的分类目录结构：topic-dictionary、presentations、updates 等
- ✅ 提升项目专业性和维护便利性

### 2026-01 增强更新

**底层基础知识域新增** (200-234):
- 域M: Docker基础 (8篇): 架构概述、镜像管理、容器生命周期、网络详解、存储卷、Compose编排、安全最佳实践、故障排查
- 域N: Linux基础 (8篇): 系统架构、进程管理、文件系统、网络配置、存储管理、性能调优、安全加固、容器技术(Namespaces/Cgroups)
- 域O: 网络基础 (6篇): 协议栈(OSI/TCP-IP)、TCP/UDP详解、DNS原理配置、负载均衡技术、网络安全、SDN与网络虚拟化
- 域P: 存储基础 (6篇): 从生产环境运维专家角度深度优化的存储技术体系，涵盖存储架构、类型详解、RAID配置、分布式系统、性能调优和企业级运维实践
- **阿里云 ACK 关联产品增强** (240-245): ECS 计算资源、SLB/NLB/ALB 负载均衡、VPC 网络规划、RAM 权限与 RRSA、ROS 资源编排、EBS 云盘存储
- **专有云 (Apsara Stack) 专题** (250-252): ESS 弹性伸缩、SLS 日志服务、POP 平台运维 (ASOP)

**核心组件深度解析系列** (35-40, 164):
- 35-etcd-deep-dive: Raft共识、MVCC存储、集群配置、备份恢复、监控调优
- 36-kube-apiserver-deep-dive: 认证授权、准入控制、APF限流、审计日志、高可用
- 37-kube-controller-manager-deep-dive: 40+控制器详解、Leader选举、监控指标
- 38-cloud-controller-manager-deep-dive: CCM完整深度解析(v2.0全面重构)，12章节资深专家级内容，架构演进与设计背景、核心控制器(Node/Service/Route)详细工作流、Cloud Provider Interface完整定义、**阿里云CCM生产级配置**(CLB/NLB/ALB完整注解速查表60+条、生产级YAML示例、RRSA认证、ReadinessGate v2.10+、版本v2.9-v2.12兼容性)、AWS CCM(NLB完整配置、目标类型ip/instance、SSL/访问日志)、Azure CCM(Standard LB、VMSS、Managed Identity)、GCP CCM(Internal LB、NEG、BackendConfig)、生产环境DaemonSet完整部署、RBAC权限矩阵、15+关键指标与Prometheus告警规则、Grafana Dashboard配置、故障排查矩阵与诊断命令集、K8s v1.28-v1.32版本兼容性矩阵、功能可用性对比表
- 39-kubelet-deep-dive: Pod生命周期、PLEG、健康探测、cgroup管理、CRI接口
- 40-kube-proxy-deep-dive: iptables/IPVS/nftables模式、负载均衡、性能调优
- 164-kube-scheduler-deep-dive: 调度框架、插件系统、评分策略、抢占机制、高级调度

**接口深度解析系列** (165-167):
- 165-cri-container-runtime-deep-dive: Docker演进、containerd/CRI-O架构、runc/crun/youki、gVisor/Kata安全容器
- 166-csi-container-storage-deep-dive: CSI规范、Sidecar组件、AWS EBS/阿里云/Ceph驱动、快照/克隆/扩展
- 167-cni-container-network-deep-dive: CNI规范、Calico BGP/eBPF、Cilium eBPF、NetworkPolicy实现

**AI/LLM系列增强** (142-152):
- 142-llm-data-pipeline: 完整数据处理架构、tokenizer配置、质量评估
- 143-llm-finetuning: LoRA/QLoRA配置、分布式训练、Kubernetes Job模板
- 144-llm-inference-serving: vLLM/TGI部署、KServe配置、性能优化
- 146-llm-quantization: GPTQ/AWQ/GGUF配置、精度对比、部署示例
- 147-vector-database-rag: Milvus/Qdrant部署、RAG架构、混合检索

**工具类文件增强** (90-101, 127-128):
- 90-secret-management-tools: Vault/ESO完整配置、密钥轮换自动化
- 91-security-scanning-tools: Trivy/Falco/Kubescape集成配置
- 100-troubleshooting-tools: kubectl debug/ephemeral containers/netshoot
- 101-performance-profiling-tools: pprof/perf/async-profiler集成
- 127-package-management-tools: Helm/Kustomize/Carvel完整对比
- 128-image-build-tools: Buildah/Kaniko/ko多阶段构建配置

**kubectl 命令完整参考** (05):
- 05-kubectl-commands-reference: 生产级kubectl命令完整参考(v3.0)，14章节资深专家级内容，kubectl架构原理、版本兼容性矩阵(v1.25-v1.32)、资源查看命令(get/describe/explain/api-resources/events)、资源创建管理(create/apply/delete/run/expose)、Pod调试交互(exec/logs/cp/attach/debug)、资源编辑补丁(edit/patch/replace/set/label/annotate)、部署管理(rollout/scale/autoscale)、集群管理(cluster-info/top/cordon/drain/taint)、配置上下文(kubeconfig/config)、高级调试(port-forward/proxy/wait/debug)、认证授权(auth/certificate/RBAC)、插件扩展(plugin/Krew/15+推荐生产插件)、性能优化最佳实践、生产环境运维脚本(巡检/诊断/清理/备份)、故障排查速查表、JSONPath高级表达式、HPA v2 YAML示例

**Service/网络深度增强** (47, 63):
- 47-service-concepts-types: Service完整深度解析(v3.0)，12章节资深专家级内容，架构图、字段完整参考表、生产级AWS/阿里云/GCP/Azure多云LB配置、kube-proxy三模式(iptables/IPVS/nftables)详解、EndpointSlice深度解析、DNS集成优化、Headless Service生产配置、gRPC负载均衡、拓扑感知路由(v1.30+ trafficDistribution)、会话亲和性、监控指标、故障排查矩阵
- 63-ingress-fundamentals: Ingress完整深度解析(v3.0)，12章节资深专家级内容，核心架构图、API结构详解、pathType匹配规则、IngressClass多控制器配置、Ingress Controller工作流程、TLS/cert-manager自动证书、金丝雀发布/限流/认证高级配置、NGINX注解完整参考、版本演进与迁移指南、kubectl操作命令、Gateway API对比与迁移路径、资源依赖关系图、故障排查矩阵、生产环境检查清单

**中等文件增强** (5-10KB → 40-60KB):
- 25-sidecar-containers-patterns: Native Sidecar(v1.28+)、通信模式、资源配置
- 59-egress-traffic-management: Cilium/Istio Gateway、云NAT配置、监控告警
- 85-certificate-management: PKI架构、cert-manager、mTLS配置
- 149-llm-privacy-security: OWASP LLM Top 10、差分隐私、审计日志
- 150-llm-cost-monitoring: GPU成本模型、Kubecost配置、预算管理
- 154-cost-management-kubecost: FinOps成熟度模型、成本分配、优化策略

**故障排查核心增强** (99):
- 99-troubleshooting-overview: 生产环境故障排查全攻略(v3.0)，15章节资深专家级内容，故障排查四步方法论、通用诊断命令矩阵、Pod故障深度排查(Pending/CrashLoopBackOff/OOMKilled/ImagePullBackOff完整诊断脚本)、Node NotReady深度排查(kubelet/容器运行时/证书/资源压力)、Service/网络故障(DNS/NetworkPolicy/kube-proxy)、存储故障(PVC/CSI驱动)、控制平面故障(API Server/etcd/Controller Manager)、调度器故障、应用部署故障(Deployment/HPA)、安全权限故障(RBAC/PSS)、性能问题排查、集群升级故障、v1.25-v1.32版本特定已知问题矩阵、生产级综合诊断脚本(k8s-full-diagnose.sh)、kubectl debug高级用法、Prometheus告警规则、Grafana Dashboard配置、生产SOP流程与值班快速参考

**集群配置参数完全参考** (06):
- 06-cluster-configuration-parameters: 生产级集群配置参数完全参考(v3.0全面重构)，10章节资深专家级内容:
  - kube-apiserver: 9子章节(核心网络存储/Service网络/认证/授权/准入控制/APF限流/审计日志/安全加密/性能缓存)，完整准入插件列表、APF FlowSchema配置示例、生产审计策略、etcd加密配置、Watch缓存优化
  - etcd: 9子章节(集群配置/网络监听/TLS安全/性能调优/Raft共识/压缩配置/备份恢复/监控指标/生产配置示例)，备份脚本、恢复流程、Prometheus告警规则
  - kube-scheduler: 6子章节(基础配置/Leader选举/API通信/调度框架KubeSchedulerConfiguration/调度插件说明/多调度器配置)，完整调度插件配置、评分策略
  - kube-controller-manager: 9子章节(基础配置/Leader选举/控制器启用/并发控制/节点生命周期/GC资源管理/API通信/证书签名/ServiceAccount)，40+控制器说明表、并发参数调优
  - kubelet: 11子章节(基础配置/CRI容器运行时/Pod容器限制/资源预留/驱逐阈值/镜像管理/节点状态/安全参数/cgroup参数/优雅关闭/配置文件示例)，资源预留计算公式、完整KubeletConfiguration YAML
  - kube-proxy: 7子章节(基础配置/代理模式/IPVS参数/iptables参数/nftables参数/Conntrack参数/配置文件示例)，IPVS调度算法对比、完整KubeProxyConfiguration YAML
  - Feature Gates: v1.25-v1.32完整版本演进表(20+特性门控)、版本状态说明、生产推荐配置
  - 生产配置示例: kubeconfig多集群配置、kubeadm完整ClusterConfiguration、集群规模配置参考表
  - 云厂商特定配置: 阿里云ACK(托管版/专有版对比、节点池kubelet配置)、AWS EKS(aws-auth ConfigMap)、Azure AKS(CLI配置)、GCP GKE(Autopilot/Standard对比)
  - 配置检查与验证: 命令集、验证清单

---

## 云厂商Kubernetes产品目录

> **涵盖范围**: 主流公有云和国内云厂商 | **更新时间**: 2026-02

本目录收录各云厂商的Kubernetes托管服务产品，提供产品概览、架构特点、核心功能和最佳实践。

### 国际云厂商

| 云厂商 | 产品名称 | 目录 | 核心特性 | 特色内容 |
|:---|:---|:---|:---|:---|
| **Amazon** | EKS (Elastic Kubernetes Service) | [03-aws-eks/aws-eks-overview.md](./domain-17-cloud-provider/03-aws-eks/aws-eks-overview.md) | 托管控制平面、IAM集成、Fargate无服务器 | EKS Anywhere混合云、Bottlerocket OS、Karpenter智能调度 |
| **Microsoft** | AKS (Azure Kubernetes Service) | [04-azure-aks/azure-aks-overview.md](./domain-17-cloud-provider/04-azure-aks/azure-aks-overview.md) | 免费控制平面、Azure AD集成、虚拟节点 | Azure Arc多云管理、Confidential Containers机密计算、Dapr集成 |
| **Google** | GKE (Google Kubernetes Engine) | [05-google-cloud-gke/google-cloud-gke-overview.md](./domain-17-cloud-provider/05-google-cloud-gke/google-cloud-gke-overview.md) | Autopilot模式、智能优化、Anthos多云 | Borg技术传承、Autopilot无服务器、Anthos Service Mesh |
| **Oracle** | OKE (Oracle Container Engine) | [11-oracle-oke/oracle-oke-overview.md](./domain-17-cloud-provider/11-oracle-oke/oracle-oke-overview.md) | OCI深度集成、裸金属节点、私有集群 | OCI原生集成、多云支持、企业级安全 |
| **IBM** | IKS (IBM Cloud Kubernetes Service) | [10-ibm-iks/ibm-iks-overview.md](./domain-17-cloud-provider/10-ibm-iks/ibm-iks-overview.md) | 企业级安全、多云支持、裸金属节点 | 企业级合规、多云混合部署、IBM Cloud集成 |

### 国内云厂商

| 云厂商 | 产品名称 | 目录 | 核心特性 | 特色内容 |
|:---|:---|:---|:---|:---|
| **阿里云** | ACK (Container Service for Kubernetes) | [01-alicloud-ack/alicloud-ack-overview.md](./domain-17-cloud-provider/01-alicloud-ack/alicloud-ack-overview.md) | 托管版/专有版、Terway网络、RRSA认证 | Terway网络插件、RRSA身份联合、Serverless节点、双模式架构 |
| **阿里云** | 专有云K8s | [02-alicloud-apsara-ack/250-apsara-stack-ess-scaling.md](./domain-17-cloud-provider/02-alicloud-apsara-ack/250-apsara-stack-ess-scaling.md) | 专有云环境、ESS伸缩、SLS日志 | 专有云定制、弹性伸缩、日志分析 |
| **字节跳动** | VEK (Volcengine Kubernetes) | [13-volcengine-vek/volcengine-vek-overview.md](./domain-17-cloud-provider/13-volcengine-vek/volcengine-vek-overview.md) | 字节内部经验、高性能调度、智能运维 | 字节跳动技术沉淀、高性能CNI、智能调度算法 |
| **腾讯云** | TKE (Tencent Kubernetes Engine) | [06-tencent-tke/tencent-tke-overview.md](./domain-17-cloud-provider/06-tencent-tke/tencent-tke-overview.md) | 万级节点、VPC-CNI、超级节点 | 腾讯内部实践、VPC网络优化、超级节点服务 |
| **华为云** | CCE (Cloud Container Engine) | [07-huawei-cce/huawei-cce-overview.md](./domain-17-cloud-provider/07-huawei-cce/huawei-cce-overview.md) | GPU节点、ASM服务网格、裸金属 | 华为技术优势、GPU加速、服务网格集成 |
| **天翼云** | TKE (Tianyi Cloud Kubernetes) | [08-ctyun-tke/ctyun-tke-overview.md](./domain-17-cloud-provider/08-ctyun-tke/ctyun-tke-overview.md) | 电信级SLA、5G融合、国产化支持 | 电信网络优势、5G融合、国产化适配 |
| **移动云** | CKE (China Mobile Cloud K8s) | [09-ecloud-cke/ecloud-cke-overview.md](./domain-17-cloud-provider/09-ecloud-cke/ecloud-cke-overview.md) | 运营商网络优势、CDN集成、专属宿主机 | 移动网络集成、CDN优化、专属计算资源 |
| **联通云** | UK8S (Unicom Cloud K8s) | [12-ucloud-uk8s/ucloud-uk8s-overview.md](./domain-17-cloud-provider/12-ucloud-uk8s/ucloud-uk8s-overview.md) | 联通网络支撑、5G切片、政企定制 | 联通网络基础、5G切片技术、政企解决方案 |

**特点**:
- ✅ 系统化整理各厂商K8s产品信息
- ✅ 无遗漏覆盖主流云服务商
- ✅ 完整的产品特性和架构对比
- ✅ 生产环境最佳实践指导
- ✅ 多维度分类索引便于查找

---

## 演示文档(topic-presentations)

> **适用环境**: 阿里云专有云、公共云 ACK 集群 | **目标读者**: DevOps 工程师、平台运维工程师

以下演示文档提供从入门到实战的完整技术体系，包含PPT演示内容和生产级配置实践。

| 主题 | 文档 | 关键内容 | 文件大小 |
|:---|:---|:---|:---:|
| **CoreDNS** | [kubernetes-coredns-presentation.md](./topic-presentations/kubernetes-coredns-presentation.md) | 架构原理、Corefile配置、ACK优化、监控告警、性能调优、生产级部署 | 100.5KB |
| **Ingress** | [kubernetes-ingress-presentation.md](./topic-presentations/kubernetes-ingress-presentation.md) | 控制器选型、路由配置、TLS证书、阿里云集成、安全加固、故障排查 | 69.3KB |
| **Service** | [kubernetes-service-presentation.md](./topic-presentations/kubernetes-service-presentation.md) | Service类型详解、负载均衡、阿里云LB集成、网络策略、高可用配置 | 66.0KB |
| **存储** | [kubernetes-storage-presentation.md](./topic-presentations/kubernetes-storage-presentation.md) | PV/PVC架构、StorageClass、CSI驱动、阿里云存储、备份恢复 | 82.4KB |
| **工作负载** | [kubernetes-workload-presentation.md](./topic-presentations/kubernetes-workload-presentation.md) | Pod生命周期、控制器模式、调度策略、资源管理、自动扩缩容 | 100.3KB |
| **Terway网络** | [kubernetes-terway-presentation.md](./topic-presentations/kubernetes-terway-presentation.md) | Terway架构、网络模式、阿里云ACK集成、固定IP、安全组集成 | 162.5KB |

**特点**:
- ✅ 系统化内容组织，无遗漏知识点
- ✅ 阿里云环境专属配置和最佳实践
- ✅ 完整的分类索引和风险说明
- ✅ 生产级YAML配置模板
- ✅ 故障排查和性能优化指导

---

## 许可证

本项目采用 [MIT License](LICENSE) 开源协议。

---

## 变更历史

### 2026-02-05 Domain-17 云厂商知识库生产级重构完成
- ✅ 完成所有13个云厂商Kubernetes服务文档的生产级内容丰富
- ✅ 从运维专家角度提供详细的架构设计、安全加固、监控告警配置
- ✅ 针对不同云厂商特色提供定制化最佳实践方案
- ✅ 统一文档结构，确保从01开始递增编号
- ✅ 更新README中的链接引用和目录结构
- ✅ 涵盖阿里云ACK、AWS EKS、GCP GKE、Azure AKS、腾讯云TKE、华为云CCE、天翼云TKE、移动云CKE、IBM IKS、Oracle OKE、联通云UK8S、火山引擎VEK等主流云厂商

### 2026-02-05 Domain-12 文档质量优化
- ✅ 完成 38 篇故障排查文档的内容质量检查
- ✅ 统一文档标题层级结构（数字层级标准化）
- ✅ 优化关键文档的目录结构和内容组织
- ✅ 提升文档的生产环境适用性和专家级质量
- ✅ 建立完整的质量检查和优化流程
