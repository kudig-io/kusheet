# Kusheet - Kubernetes 生产运维全域知识库

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **表格数量**: 167

---

## 项目定位

Kusheet 是面向**生产环境**的 Kubernetes + AI Infrastructure 运维全域知识库，涵盖从基础架构到 AI/LLM 工作负载的完整技术栈。

### 核心特色

- **生产级配置**: 所有 YAML/Shell 示例可直接用于生产环境  
- **AI Infra专题**: 覆盖GPU调度、分布式训练、模型服务、成本优化
- **多维度索引**: 按技术域、场景、角色、组件快速定位

---

## 完整表格清单 (167 Tables)

### 01-10: 架构与基础 (Architecture & Fundamentals)

| 编号 | 简称 | 表格 |
|:---:|:---:|:---|
| 01 | K8s架构 | [kubernetes-architecture-overview](./tables/01-kubernetes-architecture-overview.md) |
| 02 | 核心组件 | [core-components-deep-dive](./tables/02-core-components-deep-dive.md) |
| 03 | API版本 | [api-versions-features](./tables/03-api-versions-features.md) |
| 04 | 源码结构 | [source-code-structure](./tables/04-source-code-structure.md) |
| 05 | kubectl | [kubectl-commands-reference](./tables/05-kubectl-commands-reference.md) |
| 06 | 集群配置 | [cluster-configuration-parameters](./tables/06-cluster-configuration-parameters.md) |
| 07 | 升级策略 | [upgrade-paths-strategy](./tables/07-upgrade-paths-strategy.md) |
| 08 | 多租户 | [multi-tenancy-architecture](./tables/08-multi-tenancy-architecture.md) |
| 09 | 边缘计算 | [edge-computing-kubeedge](./tables/09-edge-computing-kubeedge.md) |
| 10 | Win容器 | [windows-containers-support](./tables/10-windows-containers-support.md) |

### 11-20: K8S原理与机制 (Principles & Mechanisms)

| 编号 | 简称 | 表格 |
|:---:|:---:|:---|
| 11 | 设计原则 | [kubernetes-design-principles](./tables/11-kubernetes-design-principles.md) |
| 12 | 声明式API | [declarative-api-pattern](./tables/12-declarative-api-pattern.md) |
| 13 | 控制器模式 | [controller-pattern-reconciliation](./tables/13-controller-pattern-reconciliation.md) |
| 14 | Watch/List | [watch-list-mechanism](./tables/14-watch-list-mechanism.md) |
| 15 | Informer | [informer-workqueue](./tables/15-informer-workqueue.md) |
| 16 | 乐观并发 | [resource-version-optimistic-concurrency](./tables/16-resource-version-optimistic-concurrency.md) |
| 17 | etcd共识 | [distributed-consensus-etcd](./tables/17-distributed-consensus-etcd.md) |
| 18 | 高可用模式 | [high-availability-patterns](./tables/18-high-availability-patterns.md) |
| 19 | 源码解读 | [kubernetes-source-code-walkthrough](./tables/19-kubernetes-source-code-walkthrough.md) |
| 20 | CAP定理 | [cap-theorem-distributed-systems](./tables/20-cap-theorem-distributed-systems.md) |

### 21-34: 工作负载与调度 (Workloads & Scheduling)

| 编号 | 简称 | 表格 |
|:---:|:---:|:---|
| 21 | 工作负载 | [workload-controllers-overview](./tables/21-workload-controllers-overview.md) |
| 22 | Pod生命周期 | [pod-lifecycle-events](./tables/22-pod-lifecycle-events.md) |
| 23 | Pod模式 | [advanced-pod-patterns](./tables/23-advanced-pod-patterns.md) |
| 24 | 容器Hook | [container-lifecycle-hooks](./tables/24-container-lifecycle-hooks.md) |
| 25 | Sidecar | [sidecar-containers-patterns](./tables/25-sidecar-containers-patterns.md) |
| 26 | CRI接口 | [container-runtime-interfaces](./tables/26-container-runtime-interfaces.md) |
| 27 | RuntimeClass | [runtime-class-configuration](./tables/27-runtime-class-configuration.md) |
| 28 | 镜像仓库 | [container-images-registry](./tables/28-container-images-registry.md) |
| 29 | 节点管理 | [node-management-operations](./tables/29-node-management-operations.md) |
| 30 | 调度器 | [scheduler-configuration](./tables/30-scheduler-configuration.md) |
| 31 | Kubelet | [kubelet-configuration](./tables/31-kubelet-configuration.md) |
| 32 | HPA/VPA | [hpa-vpa-autoscaling](./tables/32-hpa-vpa-autoscaling.md) |
| 33 | 容量规划 | [cluster-capacity-planning](./tables/33-cluster-capacity-planning.md) |
| 34 | 资源管理 | [resource-management](./tables/34-resource-management.md) |

### 35-40: 核心组件深度解析 (Core Components Deep Dive)

| 编号 | 简称 | 表格 |
|:---:|:---:|:---|
| 35 | etcd详解 | [etcd-deep-dive](./tables/35-etcd-deep-dive.md) |
| 36 | API Server | [kube-apiserver-deep-dive](./tables/36-kube-apiserver-deep-dive.md) |
| 37 | KCM详解 | [kube-controller-manager-deep-dive](./tables/37-kube-controller-manager-deep-dive.md) |
| 38 | CCM详解 | [cloud-controller-manager-deep-dive](./tables/38-cloud-controller-manager-deep-dive.md) |
| 39 | Kubelet详解 | [kubelet-deep-dive](./tables/39-kubelet-deep-dive.md) |
| 40 | kube-proxy | [kube-proxy-deep-dive](./tables/40-kube-proxy-deep-dive.md) |

### 164-167: 调度与接口深度解析 (Scheduler & Interface Deep Dive)

| 编号 | 简称 | 表格 |
|:---:|:---:|:---|
| 164 | Scheduler详解 | [kube-scheduler-deep-dive](./tables/164-kube-scheduler-deep-dive.md) |
| 165 | CRI详解 | [cri-container-runtime-deep-dive](./tables/165-cri-container-runtime-deep-dive.md) |
| 166 | CSI详解 | [csi-container-storage-deep-dive](./tables/166-csi-container-storage-deep-dive.md) |
| 167 | CNI详解 | [cni-container-network-deep-dive](./tables/167-cni-container-network-deep-dive.md) |

### 41-72: 网络 (Networking)

| 编号 | 简称 | 表格 |
|:---:|:---:|:---|
| 41 | 网络架构 | [network-architecture-overview](./tables/41-network-architecture-overview.md) |
| 42 | CNI架构 | [cni-architecture-fundamentals](./tables/42-cni-architecture-fundamentals.md) |
| 43 | CNI对比 | [cni-plugins-comparison](./tables/43-cni-plugins-comparison.md) |
| 44 | Flannel | [flannel-complete-guide](./tables/44-flannel-complete-guide.md) |
| 45 | Terway | [terway-advanced-guide](./tables/45-terway-advanced-guide.md) |
| 46 | CNI排障 | [cni-troubleshooting-optimization](./tables/46-cni-troubleshooting-optimization.md) |
| 47 | Service概念 | [service-concepts-types](./tables/47-service-concepts-types.md) |
| 48 | Service实现 | [service-implementation-details](./tables/48-service-implementation-details.md) |
| 49 | 拓扑感知 | [service-topology-aware](./tables/49-service-topology-aware.md) |
| 50 | kube-proxy | [kube-proxy-modes-performance](./tables/50-kube-proxy-modes-performance.md) |
| 51 | Service高级 | [service-advanced-features](./tables/51-service-advanced-features.md) |
| 52 | DNS发现 | [dns-service-discovery](./tables/52-dns-service-discovery.md) |
| 53 | CoreDNS架构 | [coredns-architecture-principles](./tables/53-coredns-architecture-principles.md) |
| 54 | Corefile | [coredns-configuration-corefile](./tables/54-coredns-configuration-corefile.md) |
| 55 | DNS插件 | [coredns-plugins-reference](./tables/55-coredns-plugins-reference.md) |
| 56 | DNS排障 | [coredns-troubleshooting-optimization](./tables/56-coredns-troubleshooting-optimization.md) |
| 57 | 网络策略 | [network-policy-advanced](./tables/57-network-policy-advanced.md) |
| 58 | mTLS加密 | [network-encryption-mtls](./tables/58-network-encryption-mtls.md) |
| 59 | Egress管理 | [egress-traffic-management](./tables/59-egress-traffic-management.md) |
| 60 | 多集群网络 | [multi-cluster-networking](./tables/60-multi-cluster-networking.md) |
| 61 | 网络排障 | [network-troubleshooting](./tables/61-network-troubleshooting.md) |
| 62 | 网络调优 | [network-performance-tuning](./tables/62-network-performance-tuning.md) |
| 63 | Ingress基础 | [ingress-fundamentals](./tables/63-ingress-fundamentals.md) |
| 64 | Ingress控制器 | [ingress-controller-deep-dive](./tables/64-ingress-controller-deep-dive.md) |
| 65 | Nginx Ingress | [nginx-ingress-complete-guide](./tables/65-nginx-ingress-complete-guide.md) |
| 66 | Ingress TLS | [ingress-tls-certificate](./tables/66-ingress-tls-certificate.md) |
| 67 | 高级路由 | [ingress-advanced-routing](./tables/67-ingress-advanced-routing.md) |
| 68 | Ingress安全 | [ingress-security-hardening](./tables/68-ingress-security-hardening.md) |
| 69 | Ingress监控 | [ingress-monitoring-troubleshooting](./tables/69-ingress-monitoring-troubleshooting.md) |
| 70 | Ingress实践 | [ingress-production-best-practices](./tables/70-ingress-production-best-practices.md) |
| 71 | Gateway API | [gateway-api-overview](./tables/71-gateway-api-overview.md) |
| 72 | API网关 | [api-gateway-patterns](./tables/72-api-gateway-patterns.md) |

### 73-80: 存储 (Storage)

| 编号 | 简称 | 表格 |
|:---:|:---:|:---|
| 73 | 存储架构 | [storage-architecture-overview](./tables/73-storage-architecture-overview.md) |
| 74 | PV架构 | [pv-architecture-fundamentals](./tables/74-pv-architecture-fundamentals.md) |
| 75 | PVC模式 | [pvc-patterns-practices](./tables/75-pvc-patterns-practices.md) |
| 76 | StorageClass | [storageclass-dynamic-provisioning](./tables/76-storageclass-dynamic-provisioning.md) |
| 77 | CSI驱动 | [csi-drivers-integration](./tables/77-csi-drivers-integration.md) |
| 78 | 存储调优 | [storage-performance-tuning](./tables/78-storage-performance-tuning.md) |
| 79 | 存储排障 | [pv-pvc-troubleshooting](./tables/79-pv-pvc-troubleshooting.md) |
| 80 | 存储备份 | [storage-backup-disaster-recovery](./tables/80-storage-backup-disaster-recovery.md) |

### 81-92: 安全与合规 (Security & Compliance)

| 编号 | 简称 | 表格 |
|:---:|:---:|:---|
| 81 | 安全实践 | [security-best-practices](./tables/81-security-best-practices.md) |
| 82 | 安全加固 | [security-hardening-production](./tables/82-security-hardening-production.md) |
| 83 | PSS标准 | [pod-security-standards](./tables/83-pod-security-standards.md) |
| 84 | RBAC | [rbac-matrix-configuration](./tables/84-rbac-matrix-configuration.md) |
| 85 | 证书管理 | [certificate-management](./tables/85-certificate-management.md) |
| 86 | 镜像扫描 | [image-security-scanning](./tables/86-image-security-scanning.md) |
| 87 | OPA/Kyverno | [policy-engines-opa-kyverno](./tables/87-policy-engines-opa-kyverno.md) |
| 88 | 合规认证 | [compliance-certification](./tables/88-compliance-certification.md) |
| 89 | 审计实践 | [compliance-audit-practices](./tables/89-compliance-audit-practices.md) |
| 90 | 密钥管理 | [secret-management-tools](./tables/90-secret-management-tools.md) |
| 91 | 安全扫描 | [security-scanning-tools](./tables/91-security-scanning-tools.md) |
| 92 | 策略验证 | [policy-validation-tools](./tables/92-policy-validation-tools.md) |

### 93-107: 可观测性与运维 (Observability & Operations)

| 编号 | 简称 | 表格 |
|:---:|:---:|:---|
| 93 | Prometheus | [monitoring-metrics-prometheus](./tables/93-monitoring-metrics-prometheus.md) |
| 94 | 自定义指标 | [custom-metrics-adapter](./tables/94-custom-metrics-adapter.md) |
| 95 | 日志审计 | [logging-auditing](./tables/95-logging-auditing.md) |
| 96 | 事件审计 | [events-audit-logs](./tables/96-events-audit-logs.md) |
| 97 | 可观测工具 | [observability-tools](./tables/97-observability-tools.md) |
| 98 | 日志聚合 | [log-aggregation-tools](./tables/98-log-aggregation-tools.md) |
| 99 | 排障概览 | [troubleshooting-overview](./tables/99-troubleshooting-overview.md) |
| 100 | 排障工具 | [troubleshooting-tools](./tables/100-troubleshooting-tools.md) |
| 101 | 性能分析 | [performance-profiling-tools](./tables/101-performance-profiling-tools.md) |
| 102 | Pod Pending | [pod-pending-diagnosis](./tables/102-pod-pending-diagnosis.md) |
| 103 | Node NotReady | [node-notready-diagnosis](./tables/103-node-notready-diagnosis.md) |
| 104 | OOM诊断 | [oom-memory-diagnosis](./tables/104-oom-memory-diagnosis.md) |
| 105 | 健康检查 | [cluster-health-check](./tables/105-cluster-health-check.md) |
| 106 | 混沌工程 | [chaos-engineering](./tables/106-chaos-engineering.md) |
| 107 | 扩展性能 | [scaling-performance](./tables/107-scaling-performance.md) |

### 108-117: 控制平面与扩展 (Control Plane & Extensions)

| 编号 | 简称 | 表格 |
|:---:|:---:|:---|
| 108 | APIServer调优 | [apiserver-tuning](./tables/108-apiserver-tuning.md) |
| 109 | APF限流 | [api-priority-fairness](./tables/109-api-priority-fairness.md) |
| 110 | etcd运维 | [etcd-operations](./tables/110-etcd-operations.md) |
| 111 | 准入控制 | [admission-controllers](./tables/111-admission-controllers.md) |
| 112 | CRD/Operator | [crd-operator-development](./tables/112-crd-operator-development.md) |
| 113 | API聚合 | [api-aggregation](./tables/113-api-aggregation.md) |
| 114 | Lease选举 | [lease-leader-election](./tables/114-lease-leader-election.md) |
| 115 | 客户端库 | [client-libraries](./tables/115-client-libraries.md) |
| 116 | CLI工具 | [cli-enhancement-tools](./tables/116-cli-enhancement-tools.md) |
| 117 | 插件扩展 | [addons-extensions](./tables/117-addons-extensions.md) |

### 118-123: 备份与多集群 (Backup & Multi-Cluster)

| 编号 | 简称 | 表格 |
|:---:|:---:|:---|
| 118 | 备份概览 | [backup-recovery-overview](./tables/118-backup-recovery-overview.md) |
| 119 | Velero | [backup-restore-velero](./tables/119-backup-restore-velero.md) |
| 120 | 容灾策略 | [disaster-recovery-strategy](./tables/120-disaster-recovery-strategy.md) |
| 121 | 多集群 | [multi-cluster-management](./tables/121-multi-cluster-management.md) |
| 122 | 联邦集群 | [federated-cluster](./tables/122-federated-cluster.md) |
| 123 | 虚拟集群 | [virtual-clusters](./tables/123-virtual-clusters.md) |

### 124-130: CI/CD与GitOps (CI/CD & GitOps)

| 编号 | 简称 | 表格 |
|:---:|:---:|:---|
| 124 | CI/CD流水线 | [cicd-pipelines](./tables/124-cicd-pipelines.md) |
| 125 | ArgoCD | [gitops-workflow-argocd](./tables/125-gitops-workflow-argocd.md) |
| 126 | Helm管理 | [helm-charts-management](./tables/126-helm-charts-management.md) |
| 127 | 包管理 | [package-management-tools](./tables/127-package-management-tools.md) |
| 128 | 镜像构建 | [image-build-tools](./tables/128-image-build-tools.md) |
| 129 | 服务网格 | [service-mesh-overview](./tables/129-service-mesh-overview.md) |
| 130 | 网格进阶 | [service-mesh-advanced](./tables/130-service-mesh-advanced.md) |

### 131-141: AI基础设施 (AI Infrastructure)

| 编号 | 简称 | 表格 |
|:---:|:---:|:---|
| 131 | AI Infra概览 | [ai-infrastructure-overview](./tables/131-ai-infrastructure-overview.md) |
| 132 | ML工作负载 | [ai-ml-workloads](./tables/132-ai-ml-workloads.md) |
| 133 | GPU调度 | [gpu-scheduling-management](./tables/133-gpu-scheduling-management.md) |
| 134 | GPU监控 | [gpu-monitoring-dcgm](./tables/134-gpu-monitoring-dcgm.md) |
| 135 | 分布式训练 | [distributed-training-frameworks](./tables/135-distributed-training-frameworks.md) |
| 136 | AI数据管道 | [ai-data-pipeline](./tables/136-ai-data-pipeline.md) |
| 137 | 实验管理 | [ai-experiment-management](./tables/137-ai-experiment-management.md) |
| 138 | AutoML | [automl-hyperparameter-tuning](./tables/138-automl-hyperparameter-tuning.md) |
| 139 | 模型仓库 | [model-registry](./tables/139-model-registry.md) |
| 140 | AI安全 | [ai-security-model-protection](./tables/140-ai-security-model-protection.md) |
| 141 | AI成本 | [ai-cost-analysis-finops](./tables/141-ai-cost-analysis-finops.md) |

### 142-152: LLM专题 (LLM Topics)

| 编号 | 简称 | 表格 |
|:---:|:---:|:---|
| 142 | LLM数据管道 | [llm-data-pipeline](./tables/142-llm-data-pipeline.md) |
| 143 | LLM微调 | [llm-finetuning](./tables/143-llm-finetuning.md) |
| 144 | LLM推理 | [llm-inference-serving](./tables/144-llm-inference-serving.md) |
| 145 | LLM架构 | [llm-serving-architecture](./tables/145-llm-serving-architecture.md) |
| 146 | LLM量化 | [llm-quantization](./tables/146-llm-quantization.md) |
| 147 | 向量库/RAG | [vector-database-rag](./tables/147-vector-database-rag.md) |
| 148 | 多模态 | [multimodal-models](./tables/148-multimodal-models.md) |
| 149 | LLM安全 | [llm-privacy-security](./tables/149-llm-privacy-security.md) |
| 150 | LLM成本 | [llm-cost-monitoring](./tables/150-llm-cost-monitoring.md) |
| 151 | 模型版本 | [llm-model-versioning](./tables/151-llm-model-versioning.md) |
| 152 | LLM可观测 | [llm-observability](./tables/152-llm-observability.md) |

### 153-156: 成本与云平台 (Cost & Cloud)

| 编号 | 简称 | 表格 |
|:---:|:---:|:---|
| 153 | 成本优化 | [cost-optimization-overview](./tables/153-cost-optimization-overview.md) |
| 154 | Kubecost | [cost-management-kubecost](./tables/154-cost-management-kubecost.md) |
| 155 | 绿色计算 | [green-computing-sustainability](./tables/155-green-computing-sustainability.md) |
| 156 | 阿里云集成 | [alibaba-cloud-integration](./tables/156-alibaba-cloud-integration.md) |

### 157-163: 综合故障排查 (Comprehensive Troubleshooting)

| 编号 | 简称 | 表格 |
|:---:|:---:|:---|
| 157 | Pod排障 | [pod-comprehensive-troubleshooting](./tables/157-pod-comprehensive-troubleshooting.md) |
| 158 | Node排障 | [node-comprehensive-troubleshooting](./tables/158-node-comprehensive-troubleshooting.md) |
| 159 | Service排障 | [service-comprehensive-troubleshooting](./tables/159-service-comprehensive-troubleshooting.md) |
| 160 | Deployment排障 | [deployment-comprehensive-troubleshooting](./tables/160-deployment-comprehensive-troubleshooting.md) |
| 161 | RBAC/Quota排障 | [rbac-quota-troubleshooting](./tables/161-rbac-quota-troubleshooting.md) |
| 162 | 证书排障 | [certificate-troubleshooting](./tables/162-certificate-troubleshooting.md) |
| 163 | PVC排障 | [pvc-storage-troubleshooting](./tables/163-pvc-storage-troubleshooting.md) |

---

## 按运维场景索引 (Index by Ops Scenario)

### 故障排查与诊断 (Troubleshooting & Diagnosis)
- [46-cni-troubleshooting-optimization](./tables/46-cni-troubleshooting-optimization.md)
- [56-coredns-troubleshooting-optimization](./tables/56-coredns-troubleshooting-optimization.md)
- [61-network-troubleshooting](./tables/61-network-troubleshooting.md)
- [69-ingress-monitoring-troubleshooting](./tables/69-ingress-monitoring-troubleshooting.md)
- [79-pv-pvc-troubleshooting](./tables/79-pv-pvc-troubleshooting.md)
- [99-troubleshooting-overview](./tables/99-troubleshooting-overview.md)
- [100-troubleshooting-tools](./tables/100-troubleshooting-tools.md)
- [102-pod-pending-diagnosis](./tables/102-pod-pending-diagnosis.md)
- [103-node-notready-diagnosis](./tables/103-node-notready-diagnosis.md)
- [104-oom-memory-diagnosis](./tables/104-oom-memory-diagnosis.md)
- [105-cluster-health-check](./tables/105-cluster-health-check.md)
- [157-pod-comprehensive-troubleshooting](./tables/157-pod-comprehensive-troubleshooting.md)
- [158-node-comprehensive-troubleshooting](./tables/158-node-comprehensive-troubleshooting.md)
- [159-service-comprehensive-troubleshooting](./tables/159-service-comprehensive-troubleshooting.md)
- [160-deployment-comprehensive-troubleshooting](./tables/160-deployment-comprehensive-troubleshooting.md)
- [161-rbac-quota-troubleshooting](./tables/161-rbac-quota-troubleshooting.md)
- [162-certificate-troubleshooting](./tables/162-certificate-troubleshooting.md)
- [163-pvc-storage-troubleshooting](./tables/163-pvc-storage-troubleshooting.md)

### 安全与合规 (Security & Compliance)
- [81-security-best-practices](./tables/81-security-best-practices.md)
- [82-security-hardening-production](./tables/82-security-hardening-production.md)
- [83-pod-security-standards](./tables/83-pod-security-standards.md)
- [84-rbac-matrix-configuration](./tables/84-rbac-matrix-configuration.md)
- [85-certificate-management](./tables/85-certificate-management.md)
- [86-image-security-scanning](./tables/86-image-security-scanning.md)
- [87-policy-engines-opa-kyverno](./tables/87-policy-engines-opa-kyverno.md)
- [88-compliance-certification](./tables/88-compliance-certification.md)
- [89-compliance-audit-practices](./tables/89-compliance-audit-practices.md)
- [90-secret-management-tools](./tables/90-secret-management-tools.md)
- [91-security-scanning-tools](./tables/91-security-scanning-tools.md)
- [92-policy-validation-tools](./tables/92-policy-validation-tools.md)
- [140-ai-security-model-protection](./tables/140-ai-security-model-protection.md)
- [149-llm-privacy-security](./tables/149-llm-privacy-security.md)

### 性能与成本 (Performance & Cost)
- [32-hpa-vpa-autoscaling](./tables/32-hpa-vpa-autoscaling.md)
- [33-cluster-capacity-planning](./tables/33-cluster-capacity-planning.md)
- [56-coredns-troubleshooting-optimization](./tables/56-coredns-troubleshooting-optimization.md)
- [62-network-performance-tuning](./tables/62-network-performance-tuning.md)
- [78-storage-performance-tuning](./tables/78-storage-performance-tuning.md)
- [101-performance-profiling-tools](./tables/101-performance-profiling-tools.md)
- [107-scaling-performance](./tables/107-scaling-performance.md)
- [108-apiserver-tuning](./tables/108-apiserver-tuning.md)
- [141-ai-cost-analysis-finops](./tables/141-ai-cost-analysis-finops.md)
- [150-llm-cost-monitoring](./tables/150-llm-cost-monitoring.md)
- [153-cost-optimization-overview](./tables/153-cost-optimization-overview.md)
- [154-cost-management-kubecost](./tables/154-cost-management-kubecost.md)

### 备份与容灾 (Backup & Disaster Recovery)
- [80-storage-backup-disaster-recovery](./tables/80-storage-backup-disaster-recovery.md)
- [118-backup-recovery-overview](./tables/118-backup-recovery-overview.md)
- [119-backup-restore-velero](./tables/119-backup-restore-velero.md)
- [120-disaster-recovery-strategy](./tables/120-disaster-recovery-strategy.md)

---

## 按核心组件索引 (Index by Core Component)

### 架构与基础 (Architecture & Fundamentals)
- [01-kubernetes-architecture-overview](./tables/01-kubernetes-architecture-overview.md)
- [02-core-components-deep-dive](./tables/02-core-components-deep-dive.md)
- [03-api-versions-features](./tables/03-api-versions-features.md)
- [04-source-code-structure](./tables/04-source-code-structure.md)
- [07-upgrade-paths-strategy](./tables/07-upgrade-paths-strategy.md)

### 调度与节点 (Scheduler & Node)
- [29-node-management-operations](./tables/29-node-management-operations.md)
- [30-scheduler-configuration](./tables/30-scheduler-configuration.md)
- [31-kubelet-configuration](./tables/31-kubelet-configuration.md)
- [103-node-notready-diagnosis](./tables/103-node-notready-diagnosis.md)
- [164-kube-scheduler-deep-dive](./tables/164-kube-scheduler-deep-dive.md)

### 容器运行时接口 (CRI)
- [26-container-runtime-interfaces](./tables/26-container-runtime-interfaces.md)
- [27-runtime-class-configuration](./tables/27-runtime-class-configuration.md)
- [165-cri-container-runtime-deep-dive](./tables/165-cri-container-runtime-deep-dive.md)

### 网络 (Networking)
- [41-network-architecture-overview](./tables/41-network-architecture-overview.md)
- [42-cni-architecture-fundamentals](./tables/42-cni-architecture-fundamentals.md)
- [43-cni-plugins-comparison](./tables/43-cni-plugins-comparison.md)
- [44-flannel-complete-guide](./tables/44-flannel-complete-guide.md)
- [45-terway-advanced-guide](./tables/45-terway-advanced-guide.md)
- [47-service-concepts-types](./tables/47-service-concepts-types.md)
- [50-kube-proxy-modes-performance](./tables/50-kube-proxy-modes-performance.md)
- [52-dns-service-discovery](./tables/52-dns-service-discovery.md)
- [53-coredns-architecture-principles](./tables/53-coredns-architecture-principles.md)
- [54-coredns-configuration-corefile](./tables/54-coredns-configuration-corefile.md)
- [55-coredns-plugins-reference](./tables/55-coredns-plugins-reference.md)
- [56-coredns-troubleshooting-optimization](./tables/56-coredns-troubleshooting-optimization.md)
- [57-network-policy-advanced](./tables/57-network-policy-advanced.md)
- [63-ingress-fundamentals](./tables/63-ingress-fundamentals.md)
- [71-gateway-api-overview](./tables/71-gateway-api-overview.md)
- [167-cni-container-network-deep-dive](./tables/167-cni-container-network-deep-dive.md)

### 存储 (Storage)
- [73-storage-architecture-overview](./tables/73-storage-architecture-overview.md)
- [74-pv-architecture-fundamentals](./tables/74-pv-architecture-fundamentals.md)
- [75-pvc-patterns-practices](./tables/75-pvc-patterns-practices.md)
- [76-storageclass-dynamic-provisioning](./tables/76-storageclass-dynamic-provisioning.md)
- [77-csi-drivers-integration](./tables/77-csi-drivers-integration.md)
- [78-storage-performance-tuning](./tables/78-storage-performance-tuning.md)
- [79-pv-pvc-troubleshooting](./tables/79-pv-pvc-troubleshooting.md)
- [80-storage-backup-disaster-recovery](./tables/80-storage-backup-disaster-recovery.md)
- [166-csi-container-storage-deep-dive](./tables/166-csi-container-storage-deep-dive.md)

### 容器与工作负载 (Containers & Workloads)
- [21-workload-controllers-overview](./tables/21-workload-controllers-overview.md)
- [22-pod-lifecycle-events](./tables/22-pod-lifecycle-events.md)
- [23-advanced-pod-patterns](./tables/23-advanced-pod-patterns.md)
- [24-container-lifecycle-hooks](./tables/24-container-lifecycle-hooks.md)
- [25-sidecar-containers-patterns](./tables/25-sidecar-containers-patterns.md)
- [26-container-runtime-interfaces](./tables/26-container-runtime-interfaces.md)
- [27-runtime-class-configuration](./tables/27-runtime-class-configuration.md)

---

## AI/LLM 专题索引 (AI/LLM Special Index)

### 基础设施与训练 (Infrastructure & Training)
- [131-ai-infrastructure-overview](./tables/131-ai-infrastructure-overview.md)
- [132-ai-ml-workloads](./tables/132-ai-ml-workloads.md)
- [133-gpu-scheduling-management](./tables/133-gpu-scheduling-management.md)
- [134-gpu-monitoring-dcgm](./tables/134-gpu-monitoring-dcgm.md)
- [135-distributed-training-frameworks](./tables/135-distributed-training-frameworks.md)
- [136-ai-data-pipeline](./tables/136-ai-data-pipeline.md)
- [137-ai-experiment-management](./tables/137-ai-experiment-management.md)
- [138-automl-hyperparameter-tuning](./tables/138-automl-hyperparameter-tuning.md)

### 模型服务与推理 (Model Serving & Inference)
- [139-model-registry](./tables/139-model-registry.md)
- [142-llm-data-pipeline](./tables/142-llm-data-pipeline.md)
- [143-llm-finetuning](./tables/143-llm-finetuning.md)
- [144-llm-inference-serving](./tables/144-llm-inference-serving.md)
- [145-llm-serving-architecture](./tables/145-llm-serving-architecture.md)
- [146-llm-quantization](./tables/146-llm-quantization.md)
- [147-vector-database-rag](./tables/147-vector-database-rag.md)
- [148-multimodal-models](./tables/148-multimodal-models.md)

### 可观测与成本 (Observability & Cost)
- [140-ai-security-model-protection](./tables/140-ai-security-model-protection.md)
- [141-ai-cost-analysis-finops](./tables/141-ai-cost-analysis-finops.md)
- [149-llm-privacy-security](./tables/149-llm-privacy-security.md)
- [150-llm-cost-monitoring](./tables/150-llm-cost-monitoring.md)
- [151-llm-model-versioning](./tables/151-llm-model-versioning.md)
- [152-llm-observability](./tables/152-llm-observability.md)

---

## 扩展专题索引 (Extended Topics Index)

### 可观测性与监控 (Observability & Monitoring)
- [93-monitoring-metrics-prometheus](./tables/93-monitoring-metrics-prometheus.md)
- [94-custom-metrics-adapter](./tables/94-custom-metrics-adapter.md)
- [95-logging-auditing](./tables/95-logging-auditing.md)
- [96-events-audit-logs](./tables/96-events-audit-logs.md)
- [97-observability-tools](./tables/97-observability-tools.md)
- [98-log-aggregation-tools](./tables/98-log-aggregation-tools.md)

### 多集群与联邦 (Multi-Cluster & Federation)
- [60-multi-cluster-networking](./tables/60-multi-cluster-networking.md)
- [121-multi-cluster-management](./tables/121-multi-cluster-management.md)
- [122-federated-cluster](./tables/122-federated-cluster.md)
- [123-virtual-clusters](./tables/123-virtual-clusters.md)

### 服务网格 (Service Mesh)
- [58-network-encryption-mtls](./tables/58-network-encryption-mtls.md)
- [129-service-mesh-overview](./tables/129-service-mesh-overview.md)
- [130-service-mesh-advanced](./tables/130-service-mesh-advanced.md)

### 开发工具与扩展 (Dev Tools & Extensions)
- [05-kubectl-commands-reference](./tables/05-kubectl-commands-reference.md)
- [115-client-libraries](./tables/115-client-libraries.md)
- [116-cli-enhancement-tools](./tables/116-cli-enhancement-tools.md)
- [117-addons-extensions](./tables/117-addons-extensions.md)
- [126-helm-charts-management](./tables/126-helm-charts-management.md)
- [127-package-management-tools](./tables/127-package-management-tools.md)
- [128-image-build-tools](./tables/128-image-build-tools.md)

### 阿里云专题 (Alibaba Cloud)
- [45-terway-advanced-guide](./tables/45-terway-advanced-guide.md)
- [156-alibaba-cloud-integration](./tables/156-alibaba-cloud-integration.md)

### 混沌工程与测试 (Chaos Engineering & Testing)
- [106-chaos-engineering](./tables/106-chaos-engineering.md)

### 绿色计算与边缘 (Green Computing & Edge)
- [09-edge-computing-kubeedge](./tables/09-edge-computing-kubeedge.md)
- [10-windows-containers-support](./tables/10-windows-containers-support.md)
- [155-green-computing-sustainability](./tables/155-green-computing-sustainability.md)

---

## 变更记录 (Changelog)

### 2026-01 增强更新

**核心组件深度解析系列** (35-40, 164):
- 35-etcd-deep-dive: Raft共识、MVCC存储、集群配置、备份恢复、监控调优
- 36-kube-apiserver-deep-dive: 认证授权、准入控制、APF限流、审计日志、高可用
- 37-kube-controller-manager-deep-dive: 40+控制器详解、Leader选举、监控指标
- 38-cloud-controller-manager-deep-dive: Node/Service/Route控制器、AWS/Azure/GCP/阿里云配置
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

**中等文件增强** (5-10KB → 40-60KB):
- 25-sidecar-containers-patterns: Native Sidecar(v1.28+)、通信模式、资源配置
- 59-egress-traffic-management: Cilium/Istio Gateway、云NAT配置、监控告警
- 85-certificate-management: PKI架构、cert-manager、mTLS配置
- 149-llm-privacy-security: OWASP LLM Top 10、差分隐私、审计日志
- 150-llm-cost-monitoring: GPU成本模型、Kubecost配置、预算管理
- 154-cost-management-kubecost: FinOps成熟度模型、成本分配、优化策略
