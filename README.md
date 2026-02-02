# Kusheet - Kubernetes 生产运维全域知识库

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-02 | **表格数量**: 203

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
| **产品经理** | [01-架构](#域a-架构基础-architecture-fundamentals) → [153-成本](#域k-ai基础设施-ai-infrastructure) → [141-AI成本](#域k-ai基础设施-ai-infrastructure) | 架构概览、成本优化、AI能力 |
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

> 10 篇 | Kubernetes 整体架构、核心组件、API版本、集群配置

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 01 | K8s架构 | [kubernetes-architecture-overview](./tables/domain-a-architecture-fundamentals/01-kubernetes-architecture-overview.md) | 整体架构、组件关系、数据流 |
| 02 | 核心组件 | [core-components-deep-dive](./tables/domain-a-architecture-fundamentals/02-core-components-deep-dive.md) | 各组件职责与协作 |
| 03 | API版本 | [api-versions-features](./tables/domain-a-architecture-fundamentals/03-api-versions-features.md) | API版本演进、特性门控 |
| 04 | 源码结构 | [source-code-structure](./tables/domain-a-architecture-fundamentals/04-source-code-structure.md) | 源码目录、模块划分 |
| 05 | kubectl | [kubectl-commands-reference](./tables/domain-a-architecture-fundamentals/05-kubectl-commands-reference.md) | 命令大全、常用场景 |
| 06 | 集群配置 | [cluster-configuration-parameters](./tables/domain-a-architecture-fundamentals/06-cluster-configuration-parameters.md) | 集群级配置参数 |
| 07 | 升级策略 | [upgrade-paths-strategy](./tables/domain-a-architecture-fundamentals/07-upgrade-paths-strategy.md) | 版本升级路径、回滚策略 |
| 08 | 多租户 | [multi-tenancy-architecture](./tables/domain-a-architecture-fundamentals/08-multi-tenancy-architecture.md) | 多租户隔离模型 |
| 09 | 边缘计算 | [edge-computing-kubeedge](./tables/domain-a-architecture-fundamentals/09-edge-computing-kubeedge.md) | KubeEdge、边缘场景 |
| 10 | Win容器 | [windows-containers-support](./tables/domain-a-architecture-fundamentals/10-windows-containers-support.md) | Windows节点支持 |

---

### 域B: 设计原理 (Design Principles)

> 10 篇 | K8s设计哲学、声明式API、控制器模式、分布式原理

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 11 | 设计原则 | [kubernetes-design-principles](./tables/domain-b-design-principles/11-kubernetes-design-principles.md) | 核心设计哲学、最佳实践 |
| 12 | 声明式API | [declarative-api-pattern](./tables/domain-b-design-principles/12-declarative-api-pattern.md) | 声明式 vs 命令式 |
| 13 | 控制器模式 | [controller-pattern-reconciliation](./tables/domain-b-design-principles/13-controller-pattern-reconciliation.md) | Reconcile循环、最终一致性 |
| 14 | Watch/List | [watch-list-mechanism](./tables/domain-b-design-principles/14-watch-list-mechanism.md) | 事件监听机制 |
| 15 | Informer | [informer-workqueue](./tables/domain-b-design-principles/15-informer-workqueue.md) | SharedInformer、WorkQueue |
| 16 | 乐观并发 | [resource-version-optimistic-concurrency](./tables/domain-b-design-principles/16-resource-version-optimistic-concurrency.md) | ResourceVersion、冲突处理 |
| 17 | etcd共识 | [distributed-consensus-etcd](./tables/domain-b-design-principles/17-distributed-consensus-etcd.md) | Raft协议、数据一致性 |
| 18 | 高可用模式 | [high-availability-patterns](./tables/domain-b-design-principles/18-high-availability-patterns.md) | HA架构、故障转移 |
| 19 | 源码解读 | [kubernetes-source-code-walkthrough](./tables/domain-b-design-principles/19-kubernetes-source-code-walkthrough.md) | 核心代码路径 |
| 20 | CAP定理 | [cap-theorem-distributed-systems](./tables/domain-b-design-principles/20-cap-theorem-distributed-systems.md) | CAP权衡、分布式取舍 |

---

### 域C: 控制平面 (Control Plane)

> 13 篇 | etcd、API Server、控制器、调度器、CRI/CSI/CNI接口深度解析

#### C1: 核心组件深度解析

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 35 | etcd详解 | [etcd-deep-dive](./tables/35-etcd-deep-dive.md) | Raft、MVCC、备份恢复 |
| 36 | API Server | [kube-apiserver-deep-dive](./tables/36-kube-apiserver-deep-dive.md) | 认证授权、APF限流、审计 |
| 37 | KCM详解 | [kube-controller-manager-deep-dive](./tables/37-kube-controller-manager-deep-dive.md) | 40+控制器、Leader选举 |
| 38 | CCM详解 | [cloud-controller-manager-deep-dive](./tables/38-cloud-controller-manager-deep-dive.md) | 云厂商控制器集成 |
| 39 | Kubelet详解 | [kubelet-deep-dive](./tables/39-kubelet-deep-dive.md) | Pod生命周期、PLEG、CRI |
| 40 | kube-proxy | [kube-proxy-deep-dive](./tables/40-kube-proxy-deep-dive.md) | iptables/IPVS/nftables |
| 164 | Scheduler详解 | [kube-scheduler-deep-dive](./tables/164-kube-scheduler-deep-dive.md) | 调度框架、插件、抢占 |

#### C2: 接口深度解析 (CRI/CSI/CNI)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 165 | CRI详解 | [cri-container-runtime-deep-dive](./tables/165-cri-container-runtime-deep-dive.md) | containerd/CRI-O、安全容器 |
| 166 | CSI详解 | [csi-container-storage-deep-dive](./tables/166-csi-container-storage-deep-dive.md) | CSI规范、驱动开发、快照 |
| 167 | CNI详解 | [cni-container-network-deep-dive](./tables/167-cni-container-network-deep-dive.md) | CNI规范、Calico/Cilium |

#### C3: 控制平面调优与扩展

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 108 | APIServer调优 | [apiserver-tuning](./tables/108-apiserver-tuning.md) | 性能参数、限流配置 |
| 109 | APF限流 | [api-priority-fairness](./tables/109-api-priority-fairness.md) | 优先级、公平分配 |
| 110 | etcd运维 | [etcd-operations](./tables/110-etcd-operations.md) | 集群运维、故障恢复 |

---

### 域D: 工作负载与调度 (Workloads & Scheduling)

> 14 篇 | Pod、Deployment、调度策略、自动扩缩容、资源管理

#### D1: 工作负载控制器

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 21 | 工作负载 | [workload-controllers-overview](./tables/21-workload-controllers-overview.md) | Deployment/StatefulSet/DaemonSet |
| 22 | Pod生命周期 | [pod-lifecycle-events](./tables/22-pod-lifecycle-events.md) | Phase、Condition、事件 |
| 23 | Pod模式 | [advanced-pod-patterns](./tables/23-advanced-pod-patterns.md) | Init/Sidecar/Ambassador |
| 24 | 容器Hook | [container-lifecycle-hooks](./tables/24-container-lifecycle-hooks.md) | PostStart/PreStop |
| 25 | Sidecar | [sidecar-containers-patterns](./tables/25-sidecar-containers-patterns.md) | Native Sidecar(v1.28+) |

#### D2: 容器运行时

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 26 | CRI接口 | [container-runtime-interfaces](./tables/26-container-runtime-interfaces.md) | CRI规范、运行时选型 |
| 27 | RuntimeClass | [runtime-class-configuration](./tables/27-runtime-class-configuration.md) | 多运行时配置 |
| 28 | 镜像仓库 | [container-images-registry](./tables/28-container-images-registry.md) | 镜像拉取、仓库配置 |

#### D3: 调度与资源

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 29 | 节点管理 | [node-management-operations](./tables/29-node-management-operations.md) | 节点维护、cordon/drain |
| 30 | 调度器 | [scheduler-configuration](./tables/30-scheduler-configuration.md) | 调度策略、亲和性 |
| 31 | Kubelet | [kubelet-configuration](./tables/31-kubelet-configuration.md) | Kubelet参数配置 |
| 32 | HPA/VPA | [hpa-vpa-autoscaling](./tables/32-hpa-vpa-autoscaling.md) | 水平/垂直自动扩缩 |
| 33 | 容量规划 | [cluster-capacity-planning](./tables/33-cluster-capacity-planning.md) | 资源预估、容量模型 |
| 34 | 资源管理 | [resource-management](./tables/34-resource-management.md) | Request/Limit、QoS |

---

### 域E: 网络 (Networking)

> 32 篇 | CNI、Service、DNS、Ingress、Gateway API、网络策略

#### E1: 网络架构与CNI

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 41 | 网络架构 | [network-architecture-overview](./tables/41-network-architecture-overview.md) | K8s网络模型、三层网络 |
| 42 | CNI架构 | [cni-architecture-fundamentals](./tables/42-cni-architecture-fundamentals.md) | CNI规范、插件机制 |
| 43 | CNI对比 | [cni-plugins-comparison](./tables/43-cni-plugins-comparison.md) | Flannel/Calico/Cilium对比 |
| 44 | Flannel | [flannel-complete-guide](./tables/44-flannel-complete-guide.md) | VXLAN/host-gw模式 |
| 45 | Terway | [terway-advanced-guide](./tables/45-terway-advanced-guide.md) | 阿里云ENI网络 |
| 46 | CNI排障 | [cni-troubleshooting-optimization](./tables/46-cni-troubleshooting-optimization.md) | 网络故障诊断 |

#### E2: Service与服务发现

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 47 | Service概念 | [service-concepts-types](./tables/47-service-concepts-types.md) | ClusterIP/NodePort/LB |
| 48 | Service实现 | [service-implementation-details](./tables/48-service-implementation-details.md) | Endpoint、流量转发 |
| 49 | 拓扑感知 | [service-topology-aware](./tables/49-service-topology-aware.md) | 拓扑感知路由 |
| 50 | kube-proxy | [kube-proxy-modes-performance](./tables/50-kube-proxy-modes-performance.md) | 代理模式性能对比 |
| 51 | Service高级 | [service-advanced-features](./tables/51-service-advanced-features.md) | 会话亲和、外部流量 |
| 260 | Service ACK实战 | [service-ack-practical-guide](./tables/service-ack-practical-guide.md) | 阿里云环境完整配置指南 |

#### E3: DNS与服务发现

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 52 | DNS发现 | [dns-service-discovery](./tables/52-dns-service-discovery.md) | DNS服务发现机制 |
| 53 | CoreDNS架构 | [coredns-architecture-principles](./tables/53-coredns-architecture-principles.md) | CoreDNS架构原理 |
| 54 | Corefile | [coredns-configuration-corefile](./tables/54-coredns-configuration-corefile.md) | Corefile配置 |
| 55 | DNS插件 | [coredns-plugins-reference](./tables/55-coredns-plugins-reference.md) | 插件详解 |
| 56 | DNS排障 | [coredns-troubleshooting-optimization](./tables/56-coredns-troubleshooting-optimization.md) | DNS故障诊断 |

#### E4: 网络策略与安全

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 57 | 网络策略 | [network-policy-advanced](./tables/57-network-policy-advanced.md) | NetworkPolicy高级配置 |
| 58 | mTLS加密 | [network-encryption-mtls](./tables/58-network-encryption-mtls.md) | 服务间mTLS |
| 59 | Egress管理 | [egress-traffic-management](./tables/59-egress-traffic-management.md) | 出站流量控制 |
| 60 | 多集群网络 | [multi-cluster-networking](./tables/60-multi-cluster-networking.md) | 跨集群网络 |
| 61 | 网络排障 | [network-troubleshooting](./tables/61-network-troubleshooting.md) | 网络故障排查 |
| 62 | 网络调优 | [network-performance-tuning](./tables/62-network-performance-tuning.md) | 网络性能优化 |

#### E5: Ingress与流量入口

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 63 | Ingress基础 | [ingress-fundamentals](./tables/63-ingress-fundamentals.md) | Ingress核心架构、路由配置、TLS、生产实践 |
| 64 | Ingress控制器 | [ingress-controller-deep-dive](./tables/64-ingress-controller-deep-dive.md) | 控制器选型对比 |
| 65 | Nginx Ingress | [nginx-ingress-complete-guide](./tables/65-nginx-ingress-complete-guide.md) | Nginx配置详解 |
| 66 | Ingress TLS | [ingress-tls-certificate](./tables/66-ingress-tls-certificate.md) | TLS证书配置 |
| 67 | 高级路由 | [ingress-advanced-routing](./tables/67-ingress-advanced-routing.md) | 路由规则、重写 |
| 68 | Ingress安全 | [ingress-security-hardening](./tables/68-ingress-security-hardening.md) | 安全加固 |
| 69 | Ingress监控 | [ingress-monitoring-troubleshooting](./tables/69-ingress-monitoring-troubleshooting.md) | 监控与排障 |
| 70 | Ingress实践 | [ingress-production-best-practices](./tables/70-ingress-production-best-practices.md) | 生产最佳实践 |

#### E6: Gateway API与服务网格

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 71 | Gateway API | [gateway-api-overview](./tables/71-gateway-api-overview.md) | 新一代流量管理 |
| 72 | API网关 | [api-gateway-patterns](./tables/72-api-gateway-patterns.md) | 网关模式 |

---

### 域F: 存储 (Storage)

> 8 篇 | PV/PVC、StorageClass、CSI驱动、存储调优、备份恢复

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 73 | 存储架构 | [storage-architecture-overview](./tables/73-storage-architecture-overview.md) | K8s存储架构 |
| 74 | PV架构 | [pv-architecture-fundamentals](./tables/74-pv-architecture-fundamentals.md) | PersistentVolume详解 |
| 75 | PVC模式 | [pvc-patterns-practices](./tables/75-pvc-patterns-practices.md) | PVC使用模式 |
| 76 | StorageClass | [storageclass-dynamic-provisioning](./tables/76-storageclass-dynamic-provisioning.md) | 动态供给 |
| 77 | CSI驱动 | [csi-drivers-integration](./tables/77-csi-drivers-integration.md) | CSI驱动集成 |
| 78 | 存储调优 | [storage-performance-tuning](./tables/78-storage-performance-tuning.md) | IO性能优化 |
| 79 | 存储排障 | [pv-pvc-troubleshooting](./tables/79-pv-pvc-troubleshooting.md) | PV/PVC故障排查 |
| 80 | 存储备份 | [storage-backup-disaster-recovery](./tables/80-storage-backup-disaster-recovery.md) | 数据备份恢复 |

---

### 域G: 安全合规 (Security & Compliance)

> 12 篇 | 安全实践、RBAC、PSS、证书、镜像扫描、策略引擎

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 81 | 安全实践 | [security-best-practices](./tables/81-security-best-practices.md) | 安全最佳实践 |
| 82 | 安全加固 | [security-hardening-production](./tables/82-security-hardening-production.md) | 生产加固清单 |
| 83 | PSS标准 | [pod-security-standards](./tables/83-pod-security-standards.md) | Pod安全标准 |
| 84 | RBAC | [rbac-matrix-configuration](./tables/84-rbac-matrix-configuration.md) | 权限矩阵配置 |
| 85 | 证书管理 | [certificate-management](./tables/85-certificate-management.md) | PKI、cert-manager |
| 86 | 镜像扫描 | [image-security-scanning](./tables/86-image-security-scanning.md) | 漏洞扫描 |
| 87 | OPA/Kyverno | [policy-engines-opa-kyverno](./tables/87-policy-engines-opa-kyverno.md) | 策略引擎对比 |
| 88 | 合规认证 | [compliance-certification](./tables/88-compliance-certification.md) | SOC2/ISO/PCI |
| 89 | 审计实践 | [compliance-audit-practices](./tables/89-compliance-audit-practices.md) | 审计日志配置 |
| 90 | 密钥管理 | [secret-management-tools](./tables/90-secret-management-tools.md) | Vault/ESO集成 |
| 91 | 安全扫描 | [security-scanning-tools](./tables/91-security-scanning-tools.md) | Trivy/Falco |
| 92 | 策略验证 | [policy-validation-tools](./tables/92-policy-validation-tools.md) | 策略校验工具 |

---

### 域H: 可观测性 (Observability)

> 15 篇 | 监控、日志、链路追踪、性能分析、健康检查、混沌工程

#### H1: 监控与指标

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 93 | Prometheus | [monitoring-metrics-prometheus](./tables/93-monitoring-metrics-prometheus.md) | Prometheus监控体系 |
| 94 | 自定义指标 | [custom-metrics-adapter](./tables/94-custom-metrics-adapter.md) | Metrics API扩展 |
| 97 | 可观测工具 | [observability-tools](./tables/97-observability-tools.md) | 可观测性工具栈 |

#### H2: 日志与审计

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 95 | 日志审计 | [logging-auditing](./tables/95-logging-auditing.md) | 日志收集架构 |
| 96 | 事件审计 | [events-audit-logs](./tables/96-events-audit-logs.md) | K8s事件与审计 |
| 98 | 日志聚合 | [log-aggregation-tools](./tables/98-log-aggregation-tools.md) | EFK/Loki方案 |

#### H3: 诊断与分析

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 99 | 排障概览 | [troubleshooting-overview](./tables/99-troubleshooting-overview.md) | 生产级故障排查全攻略、版本特定问题、SOP流程 |
| 100 | 排障工具 | [troubleshooting-tools](./tables/100-troubleshooting-tools.md) | kubectl debug/netshoot |
| 101 | 性能分析 | [performance-profiling-tools](./tables/101-performance-profiling-tools.md) | pprof/perf |
| 105 | 健康检查 | [cluster-health-check](./tables/105-cluster-health-check.md) | 集群健康检查 |

#### H4: 质量保障

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 106 | 混沌工程 | [chaos-engineering](./tables/106-chaos-engineering.md) | Chaos Mesh/Litmus |
| 107 | 扩展性能 | [scaling-performance](./tables/107-scaling-performance.md) | 扩展性测试 |

---

### 域I: 平台运维 (Platform Operations)

> 16 篇 | 准入控制、CRD/Operator、备份恢复、多集群、容灾

#### I1: 控制平面扩展

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 111 | 准入控制 | [admission-controllers](./tables/111-admission-controllers.md) | Webhook配置 |
| 112 | CRD/Operator | [crd-operator-development](./tables/112-crd-operator-development.md) | Operator开发 |
| 113 | API聚合 | [api-aggregation](./tables/113-api-aggregation.md) | API聚合层 |
| 114 | Lease选举 | [lease-leader-election](./tables/114-lease-leader-election.md) | Leader选举机制 |
| 115 | 客户端库 | [client-libraries](./tables/115-client-libraries.md) | client-go/SDK |
| 116 | CLI工具 | [cli-enhancement-tools](./tables/116-cli-enhancement-tools.md) | k9s/kubectx |
| 117 | 插件扩展 | [addons-extensions](./tables/117-addons-extensions.md) | 常用插件 |

#### I2: 备份与容灾

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 118 | 备份概览 | [backup-recovery-overview](./tables/118-backup-recovery-overview.md) | 备份策略规划 |
| 119 | Velero | [backup-restore-velero](./tables/119-backup-restore-velero.md) | Velero完整配置 |
| 120 | 容灾策略 | [disaster-recovery-strategy](./tables/120-disaster-recovery-strategy.md) | DR架构设计 |

#### I3: 多集群管理

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 121 | 多集群 | [multi-cluster-management](./tables/121-multi-cluster-management.md) | 多集群架构 |
| 122 | 联邦集群 | [federated-cluster](./tables/122-federated-cluster.md) | KubeFed |
| 123 | 虚拟集群 | [virtual-clusters](./tables/123-virtual-clusters.md) | vCluster |

---

### 域J: 扩展生态 (Extensions & Ecosystem)

> 9 篇 | CI/CD、GitOps、Helm、服务网格

#### J1: CI/CD与GitOps

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 124 | CI/CD流水线 | [cicd-pipelines](./tables/124-cicd-pipelines.md) | Jenkins/Tekton |
| 125 | ArgoCD | [gitops-workflow-argocd](./tables/125-gitops-workflow-argocd.md) | GitOps工作流 |

#### J2: 包管理与构建

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 126 | Helm管理 | [helm-charts-management](./tables/126-helm-charts-management.md) | Chart开发 |
| 127 | 包管理 | [package-management-tools](./tables/127-package-management-tools.md) | Helm/Kustomize/Carvel |
| 128 | 镜像构建 | [image-build-tools](./tables/128-image-build-tools.md) | Buildah/Kaniko |

#### J3: 服务网格

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 129 | 服务网格 | [service-mesh-overview](./tables/129-service-mesh-overview.md) | Istio/Linkerd概览 |
| 130 | 网格进阶 | [service-mesh-advanced](./tables/130-service-mesh-advanced.md) | 流量管理、可观测 |

---

### 域K: AI基础设施 (AI Infrastructure)

> 35 篇 | GPU调度、分布式训练、LLM服务、模型管理、成本优化、云集成、专有云专题

#### K1: AI平台基础

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 131 | AI Infra概览 | [ai-infrastructure-overview](./tables/131-ai-infrastructure-overview.md) | AI平台架构 |
| 132 | ML工作负载 | [ai-ml-workloads](./tables/132-ai-ml-workloads.md) | 训练/推理工作负载 |
| 133 | GPU调度 | [gpu-scheduling-management](./tables/133-gpu-scheduling-management.md) | GPU资源管理 |
| 134 | GPU监控 | [gpu-monitoring-dcgm](./tables/134-gpu-monitoring-dcgm.md) | DCGM/nvidia-smi |
| 155 | 绿色计算 | [green-computing-sustainability](./tables/155-green-computing-sustainability.md) | 碳排放、能效 |
| 156 | 阿里云集成 | [alibaba-cloud-integration](./tables/156-alibaba-cloud-integration.md) | ACK AI能力 |

#### K2: 模型训练

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 135 | 分布式训练 | [distributed-training-frameworks](./tables/135-distributed-training-frameworks.md) | PyTorch DDP/FSDP |
| 136 | AI数据管道 | [ai-data-pipeline](./tables/136-ai-data-pipeline.md) | 数据预处理 |
| 137 | 实验管理 | [ai-experiment-management](./tables/137-ai-experiment-management.md) | MLflow/W&B |
| 138 | AutoML | [automl-hyperparameter-tuning](./tables/138-automl-hyperparameter-tuning.md) | Katib超参调优 |
| 139 | 模型仓库 | [model-registry](./tables/139-model-registry.md) | 模型版本管理 |
| 140 | AI安全 | [ai-security-model-protection](./tables/140-ai-security-model-protection.md) | 模型安全防护 |
| 141 | AI成本 | [ai-cost-analysis-finops](./tables/141-ai-cost-analysis-finops.md) | GPU成本分析 |

#### K3: LLM专题

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 142 | LLM数据管道 | [llm-data-pipeline](./tables/142-llm-data-pipeline.md) | 数据处理、Tokenizer |
| 143 | LLM微调 | [llm-finetuning](./tables/143-llm-finetuning.md) | LoRA/QLoRA |
| 144 | LLM推理 | [llm-inference-serving](./tables/144-llm-inference-serving.md) | vLLM/TGI部署 |
| 145 | LLM架构 | [llm-serving-architecture](./tables/145-llm-serving-architecture.md) | 推理服务架构 |
| 146 | LLM量化 | [llm-quantization](./tables/146-llm-quantization.md) | GPTQ/AWQ/GGUF |
| 147 | 向量库/RAG | [vector-database-rag](./tables/147-vector-database-rag.md) | Milvus/Qdrant |
| 148 | 多模态 | [multimodal-models](./tables/148-multimodal-models.md) | 多模态模型服务 |

#### K4: LLM运维

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 149 | LLM安全 | [llm-privacy-security](./tables/149-llm-privacy-security.md) | OWASP LLM Top 10 |
| 150 | LLM成本 | [llm-cost-monitoring](./tables/150-llm-cost-monitoring.md) | Token成本分析 |
| 151 | 模型版本 | [llm-model-versioning](./tables/151-llm-model-versioning.md) | 模型版本管理 |
| 152 | LLM可观测 | [llm-observability](./tables/152-llm-observability.md) | 推理监控 |

#### K5: 成本优化

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 153 | 成本优化 | [cost-optimization-overview](./tables/153-cost-optimization-overview.md) | 成本优化策略 |
| 154 | Kubecost | [cost-management-kubecost](./tables/154-cost-management-kubecost.md) | FinOps实践 |

#### K6: ACK 关联云服务

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 240 | ECS计算 | [ack-ecs-compute](./tables/240-ack-ecs-compute.md) | 实例规格、节点池、Spot策略 |
| 241 | 负载均衡 | [ack-slb-nlb-alb](./tables/241-ack-slb-nlb-alb.md) | CLB/NLB/ALB完整配置 |
| 242 | VPC网络 | [ack-vpc-network](./tables/242-ack-vpc-network.md) | 网络规划、NAT、专线 |
| 243 | RAM权限 | [ack-ram-authorization](./tables/243-ack-ram-authorization.md) | RRSA、权限矩阵、跨账号 |
| 244 | ROS编排 | [ack-ros-iac](./tables/244-ack-ros-iac.md) | 资源模板、与Terraform对比 |
| 245 | EBS存储 | [ack-ebs-storage](./tables/245-ack-ebs-storage.md) | ESSD性能、快照、加密 |

#### K7: 专有云专题 (Apsara Stack)

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 250 | 专有云ESS | [apsara-stack-ess-scaling](./tables/250-apsara-stack-ess-scaling.md) | 弹性架构、伸缩策略、ACK集成 |
| 251 | 专有云SLS | [apsara-stack-sls-logging](./tables/251-apsara-stack-sls-logging.md) | 日志架构、审计集成、性能调优 |
| 252 | 专有云POP | [apsara-stack-pop-operations](./tables/252-apsara-stack-pop-operations.md) | 平台运维、API接入、资源管理 |

---

### 域L: 故障排查 (Troubleshooting)

> 10 篇 | Pod/Node/Service/Deployment/证书/存储 综合故障诊断

#### L1: 深度诊断

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 102 | Pod Pending | [pod-pending-diagnosis](./tables/102-pod-pending-diagnosis.md) | Pod调度失败诊断 |
| 103 | Node NotReady | [node-notready-diagnosis](./tables/103-node-notready-diagnosis.md) | 节点异常诊断 |
| 104 | OOM诊断 | [oom-memory-diagnosis](./tables/104-oom-memory-diagnosis.md) | 内存问题排查 |

#### L2: 综合故障排查

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 157 | Pod排障 | [pod-comprehensive-troubleshooting](./tables/157-pod-comprehensive-troubleshooting.md) | Pod全面排障 |
| 158 | Node排障 | [node-comprehensive-troubleshooting](./tables/158-node-comprehensive-troubleshooting.md) | Node全面排障 |
| 159 | Service排障 | [service-comprehensive-troubleshooting](./tables/159-service-comprehensive-troubleshooting.md) | Service故障排查 |
| 160 | Deployment排障 | [deployment-comprehensive-troubleshooting](./tables/160-deployment-comprehensive-troubleshooting.md) | Deployment排障 |
| 161 | RBAC/Quota排障 | [rbac-quota-troubleshooting](./tables/161-rbac-quota-troubleshooting.md) | 权限配额问题 |
| 162 | 证书排障 | [certificate-troubleshooting](./tables/162-certificate-troubleshooting.md) | 证书问题诊断 |
| 163 | PVC排障 | [pvc-storage-troubleshooting](./tables/163-pvc-storage-troubleshooting.md) | 存储问题排查 |

---

### 域M: Docker基础 (Docker Fundamentals)

> 8 篇 | Docker架构、镜像管理、容器生命周期、网络、存储、Compose、安全、故障排查

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 200 | Docker架构 | [docker-architecture-overview](./tables/200-docker-architecture-overview.md) | Docker Engine、containerd、OCI标准 |
| 201 | 镜像管理 | [docker-images-management](./tables/201-docker-images-management.md) | 镜像层、Dockerfile、多阶段构建、安全扫描 |
| 202 | 容器生命周期 | [docker-container-lifecycle](./tables/202-docker-container-lifecycle.md) | 容器状态、资源限制、健康检查、日志 |
| 203 | Docker网络 | [docker-networking-deep-dive](./tables/203-docker-networking-deep-dive.md) | 网络驱动、DNS、端口映射、网络排障 |
| 204 | Docker存储 | [docker-storage-volumes](./tables/204-docker-storage-volumes.md) | 存储驱动、Volume、Bind Mount、备份 |
| 205 | Compose | [docker-compose-orchestration](./tables/205-docker-compose-orchestration.md) | Compose配置、多环境、生产配置 |
| 206 | Docker安全 | [docker-security-best-practices](./tables/206-docker-security-best-practices.md) | 镜像安全、运行时安全、Seccomp、能力 |
| 207 | Docker排障 | [docker-troubleshooting-guide](./tables/207-docker-troubleshooting-guide.md) | 常见问题诊断、网络/存储排障 |

---

### 域N: Linux基础 (Linux Fundamentals)

> 8 篇 | 系统架构、进程管理、文件系统、网络配置、存储管理、性能调优、安全加固、容器技术

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 210 | Linux架构 | [linux-system-architecture](./tables/210-linux-system-architecture.md) | 内核架构、启动过程、systemd、内核调优 |
| 211 | 进程管理 | [linux-process-management](./tables/211-linux-process-management.md) | 进程状态、信号、优先级、监控分析 |
| 212 | 文件系统 | [linux-filesystem-deep-dive](./tables/212-linux-filesystem-deep-dive.md) | VFS、文件系统类型、权限、inode |
| 213 | 网络配置 | [linux-networking-configuration](./tables/213-linux-networking-configuration.md) | ip/ss命令、路由、iptables、网络调优 |
| 214 | 存储管理 | [linux-storage-management](./tables/214-linux-storage-management.md) | LVM、软件RAID、I/O调度、配额 |
| 215 | 性能调优 | [linux-performance-tuning](./tables/215-linux-performance-tuning.md) | CPU/内存/I/O/网络分析、内核参数 |
| 216 | 安全加固 | [linux-security-hardening](./tables/216-linux-security-hardening.md) | 用户管理、SSH、PAM、SELinux、审计 |
| 217 | 容器技术 | [linux-container-fundamentals](./tables/217-linux-container-fundamentals.md) | Namespaces、Cgroups、OverlayFS、安全 |

---

### 域O: 网络基础 (Network Fundamentals)

> 6 篇 | 协议栈、TCP/UDP、DNS、负载均衡、网络安全、SDN

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 220 | 协议栈 | [network-protocols-stack](./tables/220-network-protocols-stack.md) | OSI/TCP-IP模型、数据封装、协议概览 |
| 221 | TCP/UDP | [tcp-udp-deep-dive](./tables/221-tcp-udp-deep-dive.md) | 连接管理、流量控制、拥塞控制、对比 |
| 222 | DNS | [dns-principles-configuration](./tables/222-dns-principles-configuration.md) | DNS解析、记录类型、配置、排障 |
| 223 | 负载均衡 | [load-balancing-technologies](./tables/223-load-balancing-technologies.md) | 算法、L4/L7负载均衡、健康检查 |
| 224 | 网络安全 | [network-security-fundamentals](./tables/224-network-security-fundamentals.md) | 攻击类型、防火墙、TLS、VPN |
| 225 | SDN | [sdn-network-virtualization](./tables/225-sdn-network-virtualization.md) | SDN架构、Overlay、容器网络、服务网格 |

---

### 域P: 存储基础 (Storage Fundamentals)

> 5 篇 | 存储技术、块/文件/对象存储、RAID、分布式存储、性能

---

## 实用工具

> **维护工具**: 项目管理和验证脚本

### 链接验证工具

| 工具 | 位置 | 功能 |
|:---|:---|:---|
| **链接验证脚本** | [topic-dictionary/validate-links.ps1](./topic-dictionary/validate-links.ps1) | 验证README和演示文档中的链接有效性 |

该PowerShell脚本可以帮助维护人员快速检查项目中所有文档链接的完整性，确保引用路径的准确性。

---

| # | 简称 | 表格 | 关键内容 |
|:---:|:---|:---|:---|
| 230 | 存储概述 | [storage-technologies-overview](./tables/230-storage-technologies-overview.md) | 存储类型、架构、协议、云存储 |
| 231 | 存储类型 | [block-file-object-storage](./tables/231-block-file-object-storage.md) | 块存储、文件存储、对象存储对比 |
| 232 | RAID | [raid-storage-redundancy](./tables/232-raid-storage-redundancy.md) | RAID级别、配置、监控、硬件/软件对比 |
| 233 | 分布式存储 | [distributed-storage-systems](./tables/233-distributed-storage-systems.md) | Ceph、MinIO、GlusterFS |
| 234 | 存储性能 | [storage-performance-iops](./tables/234-storage-performance-iops.md) | IOPS、吞吐量、延迟、测试优化 |

---

## 多维度查询附录

### 附录A: 开发者视角

> 关注点: 应用部署、服务暴露、配置管理、日志调试

| 场景 | 推荐文档 | 优先级 |
|:---|:---|:---:|
| **快速上手** | [05-kubectl](./tables/05-kubectl-commands-reference.md), [21-工作负载](./tables/21-workload-controllers-overview.md) | P0 |
| **部署应用** | [21-工作负载](./tables/21-workload-controllers-overview.md), [22-Pod生命周期](./tables/22-pod-lifecycle-events.md), [126-Helm](./tables/126-helm-charts-management.md) | P0 |
| **服务暴露** | [47-Service](./tables/47-service-concepts-types.md), [63-Ingress](./tables/63-ingress-fundamentals.md), [71-Gateway API](./tables/71-gateway-api-overview.md) | P0 |
| **配置管理** | [90-Secret管理](./tables/90-secret-management-tools.md), [84-RBAC](./tables/84-rbac-matrix-configuration.md) | P1 |
| **日志调试** | [95-日志](./tables/95-logging-auditing.md), [100-排障工具](./tables/100-troubleshooting-tools.md), [157-Pod排障](./tables/157-pod-comprehensive-troubleshooting.md) | P1 |
| **CI/CD集成** | [124-CI/CD](./tables/124-cicd-pipelines.md), [125-ArgoCD](./tables/125-gitops-workflow-argocd.md), [128-镜像构建](./tables/128-image-build-tools.md) | P1 |
| **Operator开发** | [112-CRD/Operator](./tables/112-crd-operator-development.md), [115-client-go](./tables/115-client-libraries.md), [13-控制器模式](./tables/13-controller-pattern-reconciliation.md) | P2 |
| **性能优化** | [32-HPA/VPA](./tables/32-hpa-vpa-autoscaling.md), [34-资源管理](./tables/34-resource-management.md) | P2 |

---

### 附录B: 运维工程师视角

> 关注点: 集群运维、故障排查、监控告警、容量管理

| 场景 | 推荐文档 | 优先级 |
|:---|:---|:---:|
| **集群部署** | [06-集群配置](./tables/06-cluster-configuration-parameters.md), [31-Kubelet](./tables/31-kubelet-configuration.md), [35-etcd](./tables/35-etcd-deep-dive.md) | P0 |
| **日常运维** | [29-节点管理](./tables/29-node-management-operations.md), [07-升级策略](./tables/07-upgrade-paths-strategy.md), [110-etcd运维](./tables/110-etcd-operations.md) | P0 |
| **监控告警** | [93-Prometheus](./tables/93-monitoring-metrics-prometheus.md), [97-可观测工具](./tables/97-observability-tools.md), [105-健康检查](./tables/105-cluster-health-check.md) | P0 |
| **故障排查** | [99-排障概览](./tables/99-troubleshooting-overview.md), [100-排障工具](./tables/100-troubleshooting-tools.md), [102-Pod Pending](./tables/102-pod-pending-diagnosis.md), [103-Node NotReady](./tables/103-node-notready-diagnosis.md) | P0 |
| **网络运维** | [46-CNI排障](./tables/46-cni-troubleshooting-optimization.md), [56-DNS排障](./tables/56-coredns-troubleshooting-optimization.md), [61-网络排障](./tables/61-network-troubleshooting.md) | P1 |
| **存储运维** | [79-存储排障](./tables/79-pv-pvc-troubleshooting.md), [163-PVC排障](./tables/163-pvc-storage-troubleshooting.md), [80-存储备份](./tables/80-storage-backup-disaster-recovery.md) | P1 |
| **备份恢复** | [118-备份概览](./tables/118-backup-recovery-overview.md), [119-Velero](./tables/119-backup-restore-velero.md), [120-容灾策略](./tables/120-disaster-recovery-strategy.md) | P1 |
| **容量规划** | [33-容量规划](./tables/33-cluster-capacity-planning.md), [107-扩展性能](./tables/107-scaling-performance.md) | P2 |
| **安全运维** | [82-安全加固](./tables/82-security-hardening-production.md), [85-证书管理](./tables/85-certificate-management.md), [162-证书排障](./tables/162-certificate-troubleshooting.md) | P2 |

---

### 附录C: 架构师视角

> 关注点: 架构设计、高可用、多集群、技术选型

| 场景 | 推荐文档 | 优先级 |
|:---|:---|:---:|
| **架构设计** | [01-K8s架构](./tables/01-kubernetes-architecture-overview.md), [02-核心组件](./tables/02-core-components-deep-dive.md), [11-设计原则](./tables/11-kubernetes-design-principles.md) | P0 |
| **设计原理** | [12-声明式API](./tables/12-declarative-api-pattern.md), [13-控制器模式](./tables/13-controller-pattern-reconciliation.md), [20-CAP定理](./tables/20-cap-theorem-distributed-systems.md) | P0 |
| **高可用设计** | [18-高可用模式](./tables/18-high-availability-patterns.md), [17-etcd共识](./tables/17-distributed-consensus-etcd.md), [120-容灾策略](./tables/120-disaster-recovery-strategy.md) | P0 |
| **控制平面** | [35-etcd](./tables/35-etcd-deep-dive.md), [36-API Server](./tables/36-kube-apiserver-deep-dive.md), [37-KCM](./tables/37-kube-controller-manager-deep-dive.md), [164-Scheduler](./tables/164-kube-scheduler-deep-dive.md) | P0 |
| **多集群架构** | [121-多集群](./tables/121-multi-cluster-management.md), [122-联邦集群](./tables/122-federated-cluster.md), [60-多集群网络](./tables/60-multi-cluster-networking.md) | P1 |
| **网络架构** | [41-网络架构](./tables/41-network-architecture-overview.md), [43-CNI对比](./tables/43-cni-plugins-comparison.md), [167-CNI详解](./tables/167-cni-container-network-deep-dive.md) | P1 |
| **存储架构** | [73-存储架构](./tables/73-storage-architecture-overview.md), [166-CSI详解](./tables/166-csi-container-storage-deep-dive.md) | P1 |
| **运行时选型** | [165-CRI详解](./tables/165-cri-container-runtime-deep-dive.md), [27-RuntimeClass](./tables/27-runtime-class-configuration.md) | P2 |
| **服务网格** | [129-服务网格](./tables/129-service-mesh-overview.md), [130-网格进阶](./tables/130-service-mesh-advanced.md) | P2 |
| **AI基础设施** | [131-AI Infra](./tables/131-ai-infrastructure-overview.md), [145-LLM架构](./tables/145-llm-serving-architecture.md) | P2 |

---

### 附录D: 测试工程师视角

> 关注点: 测试环境、混沌工程、性能测试、CI集成

| 场景 | 推荐文档 | 优先级 |
|:---|:---|:---:|
| **环境搭建** | [123-虚拟集群](./tables/123-virtual-clusters.md), [06-集群配置](./tables/06-cluster-configuration-parameters.md) | P0 |
| **混沌工程** | [106-混沌工程](./tables/106-chaos-engineering.md) | P0 |
| **性能测试** | [101-性能分析](./tables/101-performance-profiling-tools.md), [107-扩展性能](./tables/107-scaling-performance.md), [62-网络调优](./tables/62-network-performance-tuning.md) | P0 |
| **CI/CD集成** | [124-CI/CD](./tables/124-cicd-pipelines.md), [128-镜像构建](./tables/128-image-build-tools.md) | P1 |
| **安全测试** | [86-镜像扫描](./tables/86-image-security-scanning.md), [91-安全扫描](./tables/91-security-scanning-tools.md) | P1 |
| **可观测性** | [93-Prometheus](./tables/93-monitoring-metrics-prometheus.md), [95-日志](./tables/95-logging-auditing.md), [97-可观测工具](./tables/97-observability-tools.md) | P2 |
| **故障注入** | [106-混沌工程](./tables/106-chaos-engineering.md), [99-排障概览](./tables/99-troubleshooting-overview.md) | P2 |

---

### 附录E: 产品经理视角

> 关注点: 架构理解、成本分析、能力边界、技术选型

| 场景 | 推荐文档 | 优先级 |
|:---|:---|:---:|
| **架构理解** | [01-K8s架构](./tables/01-kubernetes-architecture-overview.md), [11-设计原则](./tables/11-kubernetes-design-principles.md) | P0 |
| **成本分析** | [153-成本优化](./tables/153-cost-optimization-overview.md), [154-Kubecost](./tables/154-cost-management-kubecost.md), [141-AI成本](./tables/141-ai-cost-analysis-finops.md) | P0 |
| **AI能力** | [131-AI Infra](./tables/131-ai-infrastructure-overview.md), [144-LLM推理](./tables/144-llm-inference-serving.md), [150-LLM成本](./tables/150-llm-cost-monitoring.md) | P1 |
| **多租户** | [08-多租户](./tables/08-multi-tenancy-architecture.md), [84-RBAC](./tables/84-rbac-matrix-configuration.md) | P1 |
| **合规认证** | [88-合规认证](./tables/88-compliance-certification.md), [89-审计实践](./tables/89-compliance-audit-practices.md) | P1 |
| **高可用** | [18-高可用模式](./tables/18-high-availability-patterns.md), [120-容灾策略](./tables/120-disaster-recovery-strategy.md) | P2 |
| **边缘计算** | [09-边缘计算](./tables/09-edge-computing-kubeedge.md) | P2 |
| **绿色计算** | [155-绿色计算](./tables/155-green-computing-sustainability.md) | P2 |

---

### 附录F: 终端用户视角

> 关注点: 应用部署、状态查看、日志获取、问题定位

| 场景 | 推荐文档 | 优先级 |
|:---|:---|:---:|
| **基础操作** | [05-kubectl](./tables/05-kubectl-commands-reference.md), [116-CLI工具](./tables/116-cli-enhancement-tools.md) | P0 |
| **应用部署** | [126-Helm](./tables/126-helm-charts-management.md), [125-ArgoCD](./tables/125-gitops-workflow-argocd.md) | P0 |
| **状态查看** | [22-Pod生命周期](./tables/22-pod-lifecycle-events.md), [105-健康检查](./tables/105-cluster-health-check.md) | P1 |
| **日志获取** | [95-日志](./tables/95-logging-auditing.md), [98-日志聚合](./tables/98-log-aggregation-tools.md) | P1 |
| **问题定位** | [157-Pod排障](./tables/157-pod-comprehensive-troubleshooting.md), [159-Service排障](./tables/159-service-comprehensive-troubleshooting.md) | P1 |
| **资源配置** | [34-资源管理](./tables/34-resource-management.md), [32-HPA/VPA](./tables/32-hpa-vpa-autoscaling.md) | P2 |

---

## 变更记录

### 2026-02 目录结构优化

**项目结构重组完成**:
- ✅ 创建 `domain-q-cloud-provider` 统一管理所有云厂商文档
- ✅ 将所有 `cloud-*` 目录移动到 `domain-q-cloud-provider/` 下
- ✅ 重命名 `presentations` → `topic-presentations`
- ✅ 重命名 `trouble-shooting` → `topic-trouble-shooting`
- ✅ 更新 README 中所有相关链接
- ✅ 验证所有链接有效性

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
- 域P: 存储基础 (5篇): 存储技术概述、块/文件/对象存储、RAID配置、分布式存储(Ceph/MinIO/GlusterFS)、存储性能与IOPS
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

> **涵盖范围**: 主流公有云和国内云厂商 | **更新时间**: 2026-01

本目录收录各云厂商的Kubernetes托管服务产品，提供产品概览、架构特点、核心功能和最佳实践。

### 国际云厂商

| 云厂商 | 产品名称 | 目录 | 核心特性 | 特色内容 |
|:---|:---|:---|:---|:---|
| **Amazon** | EKS (Elastic Kubernetes Service) | [cloud-aws-eks/aws-eks-overview.md](./domain-q-cloud-provider/cloud-aws-eks/aws-eks-overview.md) | 托管控制平面、IAM集成、Fargate无服务器 | EKS Anywhere混合云、Bottlerocket OS、Karpenter智能调度 |
| **Microsoft** | AKS (Azure Kubernetes Service) | [cloud-azure-aks/azure-aks-overview.md](./domain-q-cloud-provider/cloud-azure-aks/azure-aks-overview.md) | 免费控制平面、Azure AD集成、虚拟节点 | Azure Arc多云管理、Confidential Containers机密计算、Dapr集成 |
| **Google** | GKE (Google Kubernetes Engine) | [cloud-google-cloud-gke/google-cloud-gke-overview.md](./domain-q-cloud-provider/cloud-google-cloud-gke/google-cloud-gke-overview.md) | Autopilot模式、智能优化、Anthos多云 | Borg技术传承、Autopilot无服务器、Anthos Service Mesh |
| **Oracle** | OKE (Oracle Container Engine) | [cloud-oracle-oke/oracle-oke-overview.md](./domain-q-cloud-provider/cloud-oracle-oke/oracle-oke-overview.md) | OCI深度集成、裸金属节点、私有集群 | OCI原生集成、多云支持、企业级安全 |
| **IBM** | IKS (IBM Cloud Kubernetes Service) | [cloud-ibm-iks/ibm-iks-overview.md](./domain-q-cloud-provider/cloud-ibm-iks/ibm-iks-overview.md) | 企业级安全、多云支持、裸金属节点 | 企业级合规、多云混合部署、IBM Cloud集成 |

### 国内云厂商

| 云厂商 | 产品名称 | 目录 | 核心特性 | 特色内容 |
|:---|:---|:---|:---|:---|
| **阿里云** | ACK (Container Service for Kubernetes) | [cloud-alicloud-ack/alicloud-ack-overview.md](./domain-q-cloud-provider/cloud-alicloud-ack/alicloud-ack-overview.md) | 托管版/专有版、Terway网络、RRSA认证 | Terway网络插件、RRSA身份联合、Serverless节点、双模式架构 |
| **阿里云** | 专有云K8s | [cloud-alicloud-apsara-ack/250-apsara-stack-ess-scaling.md](./domain-q-cloud-provider/cloud-alicloud-apsara-ack/250-apsara-stack-ess-scaling.md) | 专有云环境、ESS伸缩、SLS日志 | 专有云定制、弹性伸缩、日志分析 |
| **字节跳动** | VEK (Volcengine Kubernetes) | [cloud-volcengine-vek/volcengine-vek-overview.md](./domain-q-cloud-provider/cloud-volcengine-vek/volcengine-vek-overview.md) | 字节内部经验、高性能调度、智能运维 | 字节跳动技术沉淀、高性能CNI、智能调度算法 |
| **腾讯云** | TKE (Tencent Kubernetes Engine) | [cloud-tencent-tke/tencent-tke-overview.md](./domain-q-cloud-provider/cloud-tencent-tke/tencent-tke-overview.md) | 万级节点、VPC-CNI、超级节点 | 腾讯内部实践、VPC网络优化、超级节点服务 |
| **华为云** | CCE (Cloud Container Engine) | [cloud-huawei-cce/huawei-cce-overview.md](./domain-q-cloud-provider/cloud-huawei-cce/huawei-cce-overview.md) | GPU节点、ASM服务网格、裸金属 | 华为技术优势、GPU加速、服务网格集成 |
| **天翼云** | TKE (Tianyi Cloud Kubernetes) | [cloud-ctyun-tke/ctyun-tke-overview.md](./domain-q-cloud-provider/cloud-ctyun-tke/ctyun-tke-overview.md) | 电信级SLA、5G融合、国产化支持 | 电信网络优势、5G融合、国产化适配 |
| **移动云** | CKE (China Mobile Cloud K8s) | [cloud-ecloud-cke/ecloud-cke-overview.md](./domain-q-cloud-provider/cloud-ecloud-cke/ecloud-cke-overview.md) | 运营商网络优势、CDN集成、专属宿主机 | 移动网络集成、CDN优化、专属计算资源 |
| **联通云** | UK8S (Unicom Cloud K8s) | [cloud-ucloud-uk8s/ucloud-uk8s-overview.md](./domain-q-cloud-provider/cloud-ucloud-uk8s/ucloud-uk8s-overview.md) | 联通网络支撑、5G切片、政企定制 | 联通网络基础、5G切片技术、政企解决方案 |

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
