# Kusheet - Kubernetes 生产运维速查表

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **表格数量**: 100

面向生产环境 Kubernetes 运维的全面参考手册，涵盖架构、配置、监控、安全、AI/LLM、故障排查等核心领域。

## 内容特点

- **生产导向**: 所有配置和示例均基于生产环境最佳实践
- **完整示例**: 提供可直接使用的 YAML 配置和 Shell 脚本
- **版本追踪**: 明确标注各功能的版本支持和演进
- **ACK集成**: 包含阿里云 Kubernetes (ACK) 特定配置
- **AI/LLM支持**: 完整的大模型训练、推理、运维参考

---

## 目录

### 一、基础架构 (01-20)

核心组件、配置参数、监控安全、网络存储等基础设施。

| 编号 | 表格 | 描述 | 关键内容 |
|:---:|------|------|----------|
| 01 | [kubernetes-architecture](tables/01-kubernetes-architecture.md) | Kubernetes架构 | 集群架构图、规模限制、HA部署模式 |
| 02 | [core-components](tables/02-core-components.md) | 核心组件 | 组件配置、版本兼容矩阵、诊断命令 |
| 03 | [features-and-api](tables/03-features-and-api.md) | 功能和API | API版本演进、Gateway API、CRD示例 |
| 04 | [code-structure](tables/04-code-structure.md) | 代码结构 | 源码目录、关键包、开发命令 |
| 05 | [kubectl-commands](tables/05-kubectl-commands.md) | kubectl命令 | 高级查询、debug详解、插件推荐 |
| 06 | [configuration-parameters](tables/06-configuration-parameters.md) | 配置参数 | 分规模参数推荐、完整配置文件 |
| 07 | [monitoring-metrics](tables/07-monitoring-metrics.md) | 监控指标 | 全组件指标、Prometheus告警规则 |
| 08 | [troubleshooting](tables/08-troubleshooting.md) | 故障排查 | 诊断流程图、排查脚本、根因分析 |
| 09 | [security-best-practices](tables/09-security-best-practices.md) | 安全最佳实践 | PSS对比、RBAC审计、CVE参考 |
| 10 | [scaling-performance](tables/10-scaling-performance.md) | 扩展和性能 | HPA/VPA/CA配置、etcd调优 |
| 11 | [upgrade-paths](tables/11-upgrade-paths.md) | 升级路径 | 版本支持策略、偏差策略、升级检查 |
| 12 | [network-components](tables/12-network-components.md) | 网络组件 | CNI插件、Service网络、DNS |
| 13 | [storage](tables/13-storage.md) | 存储 | PV/PVC、StorageClass、CSI驱动 |
| 14 | [addons-extensions](tables/14-addons-extensions.md) | 附加组件 | 必备组件、可观测性、安全工具 |
| 15 | [alibaba-cloud-integration](tables/15-alibaba-cloud-integration.md) | 阿里云集成 | ACK配置、Terway、版本对齐 |
| 16 | [resource-management](tables/16-resource-management.md) | 资源管理 | Requests/Limits、QoS、配额 |
| 17 | [logging-auditing](tables/17-logging-auditing.md) | 日志审计 | 日志架构、审计配置、SLS集成 |
| 18 | [backup-recovery](tables/18-backup-recovery.md) | 备份恢复 | etcd备份、Velero、恢复流程 |
| 19 | [multi-tenancy](tables/19-multi-tenancy.md) | 多租户 | 隔离级别、RBAC、NetworkPolicy |
| 20 | [service-mesh](tables/20-service-mesh.md) | 服务网格 | Istio、Linkerd、流量管理 |

### 二、扩展功能 (21-40)

CI/CD、调度、控制器、Operator等扩展能力。

| 编号 | 表格 | 描述 | 关键内容 |
|:---:|------|------|----------|
| 21 | [cicd-pipelines](tables/21-cicd-pipelines.md) | CI/CD流水线 | ArgoCD、Flux、Tekton配置 |
| 22 | [cost-optimization](tables/22-cost-optimization.md) | 成本优化 | 成本分析、Spot实例、资源右置 |
| 23 | [compliance-certification](tables/23-compliance-certification.md) | 合规认证 | CIS Benchmark、等保合规 |
| 24 | [edge-computing](tables/24-edge-computing.md) | 边缘计算 | KubeEdge、OpenYurt、边缘场景 |
| 25 | [ai-ml-workloads](tables/25-ai-ml-workloads.md) | AI/ML工作负载 | 训练/推理架构、分布式训练 |
| 26 | [gpu-scheduling](tables/26-gpu-scheduling.md) | GPU调度 | GPU/MIG/cGPU配置、NVIDIA插件 |
| 27 | [node-management](tables/27-node-management.md) | 节点管理 | 节点生命周期、维护、污点容忍 |
| 28 | [scheduler-config](tables/28-scheduler-config.md) | 调度器配置 | 多Profile、插件配置、自定义调度 |
| 29 | [admission-controllers](tables/29-admission-controllers.md) | 准入控制器 | Webhook配置、CEL验证 |
| 30 | [etcd-operations](tables/30-etcd-operations.md) | etcd运维 | 备份恢复、性能调优、告警规则 |
| 31 | [crd-operator](tables/31-crd-operator.md) | CRD和Operator | CRD开发、Operator模式、SDK |
| 32 | [api-aggregation](tables/32-api-aggregation.md) | API聚合 | APIService、聚合层配置 |
| 33 | [dns-service-discovery](tables/33-dns-service-discovery.md) | DNS服务发现 | CoreDNS配置、DNS策略 |
| 34 | [configmap-secret](tables/34-configmap-secret.md) | ConfigMap/Secret | 配置管理、加密、外部Secret |
| 35 | [workload-controllers](tables/35-workload-controllers.md) | 工作负载控制器 | 控制器详解、生命周期、策略 |
| 36 | [cluster-health-check](tables/36-cluster-health-check.md) | 集群健康检查 | 健康检查脚本、巡检清单 |
| 37 | [pod-lifecycle-events](tables/37-pod-lifecycle-events.md) | Pod生命周期 | 状态转换、Hook、优雅终止 |
| 38 | [ingress-api-gateway](tables/38-ingress-api-gateway.md) | Ingress/API网关 | Nginx、ALB、Gateway API |
| 39 | [container-runtime](tables/39-container-runtime.md) | 容器运行时 | containerd、CRI-O、沙箱运行时 |
| 40 | [custom-metrics](tables/40-custom-metrics.md) | 自定义指标 | Prometheus Adapter、外部指标 |

### 三、高级特性 (41-55)

灾备、安全、GitOps、混沌工程等高级能力。

| 编号 | 表格 | 描述 | 关键内容 |
|:---:|------|------|----------|
| 41 | [disaster-recovery](tables/41-disaster-recovery.md) | 灾难恢复(基础) | DR策略、数据保护 |
| 42 | [rbac-matrix](tables/42-rbac-matrix.md) | RBAC权限矩阵 | 权限矩阵、审计脚本、SA配置 |
| 43 | [image-security-scan](tables/43-image-security-scan.md) | 镜像安全扫描 | Trivy、Harbor、漏洞管理 |
| 44 | [federated-cluster](tables/44-federated-cluster.md) | 联邦集群 | 多集群管理、KubeFed |
| 45 | [green-computing](tables/45-green-computing.md) | 绿色计算 | 能效优化、碳排放 |
| 46 | [client-libraries](tables/46-client-libraries.md) | 客户端库 | client-go、各语言SDK |
| 47 | [helm-charts](tables/47-helm-charts.md) | Helm Charts | Chart开发、仓库管理 |
| 48 | [gitops-workflow](tables/48-gitops-workflow.md) | GitOps工作流 | GitOps最佳实践、工具对比 |
| 49 | [service-mesh-advanced](tables/49-service-mesh-advanced.md) | 服务网格高级 | mTLS、流量镜像、故障注入 |
| 50 | [policy-engines](tables/50-policy-engines.md) | 策略引擎 | Gatekeeper、Kyverno、VAP |
| 51 | [container-images](tables/51-container-images.md) | 容器镜像 | 镜像构建、多架构、签名 |
| 52 | [chaos-engineering](tables/52-chaos-engineering.md) | 混沌工程 | Chaos Mesh、LitmusChaos |
| 53 | [cost-management](tables/53-cost-management.md) | 成本管理 | Kubecost、FinOps实践 |
| 54 | [windows-containers](tables/54-windows-containers.md) | Windows容器 | Windows节点、混合集群 |
| 55 | [virtual-clusters](tables/55-virtual-clusters.md) | 虚拟集群 | vCluster、HNC、多租户 |

### 四、AI/LLM工作负载 (56-65)

大模型数据处理、训练、推理、运维全流程。

| 编号 | 表格 | 描述 | 关键内容 |
|:---:|------|------|----------|
| 56 | [llm-data-pipeline](tables/56-llm-data-pipeline.md) | LLM数据流水线 | 数据处理、预训练数据 |
| 57 | [llm-finetuning](tables/57-llm-finetuning.md) | LLM微调 | LoRA、QLoRA、分布式微调 |
| 58 | [llm-inference-serving](tables/58-llm-inference-serving.md) | LLM推理服务 | vLLM、TGI、KServe |
| 59 | [vector-database-rag](tables/59-vector-database-rag.md) | 向量数据库/RAG | Milvus、Qdrant、RAG架构 |
| 60 | [llm-quantization](tables/60-llm-quantization.md) | LLM量化 | GPTQ、AWQ、量化部署 |
| 61 | [multimodal-models](tables/61-multimodal-models.md) | 多模态模型 | 视觉语言模型、部署配置 |
| 62 | [llm-privacy-security](tables/62-llm-privacy-security.md) | LLM隐私安全 | 数据脱敏、模型保护 |
| 63 | [llm-cost-monitoring](tables/63-llm-cost-monitoring.md) | LLM成本监控 | Token计费、成本优化 |
| 64 | [llm-model-versioning](tables/64-llm-model-versioning.md) | LLM模型版本 | 模型管理、A/B测试 |
| 65 | [llm-observability](tables/65-llm-observability.md) | LLM可观测性 | 推理监控、日志追踪 |

### 五、网络与安全 (66-85)

Pod安全、证书、网络策略、CNI、流量管理等。

| 编号 | 表格 | 描述 | 关键内容 |
|:---:|------|------|----------|
| 66 | [pod-security-standards](tables/66-pod-security-standards.md) | Pod安全标准 | PSS三级别、迁移指南 |
| 67 | [certificate-management](tables/67-certificate-management.md) | 证书管理 | cert-manager、证书轮换 |
| 68 | [api-priority-fairness](tables/68-api-priority-fairness.md) | API优先级 | FlowSchema、限流配置 |
| 69 | [lease-leader-election](tables/69-lease-leader-election.md) | 租约/选举 | Lease对象、选举机制 |
| 70 | [runtime-class](tables/70-runtime-class.md) | RuntimeClass | 运行时选择、沙箱配置 |
| 71 | [gateway-api](tables/71-gateway-api.md) | Gateway API | HTTPRoute、GRPCRoute |
| 72 | [service-topology](tables/72-service-topology.md) | Service拓扑 | 拓扑感知、本地优先 |
| 73 | [events-audit-logs](tables/73-events-audit-logs.md) | 事件和审计 | Event分析、审计策略 |
| 74 | [container-lifecycle](tables/74-container-lifecycle.md) | 容器生命周期 | 启动/停止顺序、Hook |
| 75 | [sidecar-containers](tables/75-sidecar-containers.md) | Sidecar容器 | v1.28+ Sidecar支持 |
| 76 | [cni-plugins-comparison](tables/76-cni-plugins-comparison.md) | CNI插件对比 | Calico、Cilium、Terway |
| 77 | [service-implementation](tables/77-service-implementation.md) | Service实现 | ClusterIP、NodePort、LB |
| 78 | [network-policy-advanced](tables/78-network-policy-advanced.md) | NetworkPolicy高级 | 高级规则、Cilium策略 |
| 79 | [ingress-controller-config](tables/79-ingress-controller-config.md) | Ingress控制器 | Nginx配置、注解详解 |
| 80 | [multi-cluster-networking](tables/80-multi-cluster-networking.md) | 多集群网络 | 跨集群通信、Submariner |
| 81 | [network-troubleshooting](tables/81-network-troubleshooting.md) | 网络故障排查 | 连通性诊断、抓包分析 |
| 82 | [dns-optimization](tables/82-dns-optimization.md) | DNS优化 | NodeLocal DNS、性能调优 |
| 83 | [network-encryption-mtls](tables/83-network-encryption-mtls.md) | 网络加密/mTLS | 加密配置、证书管理 |
| 84 | [network-performance-tuning](tables/84-network-performance-tuning.md) | 网络性能调优 | 内核参数、瓶颈诊断 |
| 85 | [egress-traffic-management](tables/85-egress-traffic-management.md) | 出口流量管理 | Egress Gateway、NAT |

### 六、运维诊断 (86-100)

故障诊断、性能调优、容量规划、备份恢复等。

| 编号 | 表格 | 描述 | 关键内容 |
|:---:|------|------|----------|
| 86 | [pod-pending-diagnosis](tables/86-pod-pending-diagnosis.md) | Pod Pending诊断 | 调度失败原因、解决方案 |
| 87 | [node-notready-diagnosis](tables/87-node-notready-diagnosis.md) | Node NotReady诊断 | 节点故障诊断流程 |
| 88 | [oom-memory-diagnosis](tables/88-oom-memory-diagnosis.md) | OOM/内存诊断 | OOM原因分析、内存优化 |
| 89 | [pv-pvc-troubleshooting](tables/89-pv-pvc-troubleshooting.md) | PV/PVC故障排查 | 存储问题诊断 |
| 90 | [cluster-capacity-planning](tables/90-cluster-capacity-planning.md) | 集群容量规划 | 资源规划、扩容策略 |
| 91 | [kubelet-configuration](tables/91-kubelet-configuration.md) | kubelet配置 | 完整配置参数、优化 |
| 92 | [hpa-vpa-autoscaling](tables/92-hpa-vpa-autoscaling.md) | HPA/VPA自动扩缩 | 配置详解、调优策略 |
| 93 | [apiserver-tuning](tables/93-apiserver-tuning.md) | API Server调优 | 性能优化、限流配置 |
| 94 | [network-performance-tuning](tables/94-network-performance-tuning.md) | 网络性能调优(高级) | eBPF、XDP、sysctl优化 |
| 95 | [storage-performance-tuning](tables/95-storage-performance-tuning.md) | 存储性能调优 | IOPS优化、缓存配置 |
| 96 | [backup-restore](tables/96-backup-restore.md) | 备份恢复(高级) | Velero高级、跨集群恢复 |
| 97 | [disaster-recovery](tables/97-disaster-recovery.md) | 灾难恢复(高级) | 多活架构、故障切换 |
| 98 | [multi-cluster-management](tables/98-multi-cluster-management.md) | 多集群管理 | Rancher、ACK One |
| 99 | [security-hardening](tables/99-security-hardening.md) | 安全加固 | 系统加固、CVE参考 |
| 100 | [compliance-audit](tables/100-compliance-audit.md) | 合规审计 | 审计报告、合规检查 |

---

## 快速导航

### 按场景查找

| 场景 | 推荐表格 |
|------|---------|
| **集群部署** | 01, 02, 06, 11, 15 |
| **日常运维** | 05, 08, 27, 36, 86-89 |
| **性能优化** | 10, 28, 84, 91-95 |
| **安全加固** | 09, 42, 50, 66, 99 |
| **故障排查** | 08, 81, 86-89 |
| **监控告警** | 07, 40, 65 |
| **备份恢复** | 18, 30, 96, 97 |
| **多租户** | 19, 42, 55 |
| **CI/CD** | 21, 48, 51 |
| **AI/LLM** | 25, 26, 56-65 |
| **网络** | 12, 76-85 |

### 按组件查找

| 组件 | 相关表格 |
|------|---------|
| **API Server** | 02, 06, 29, 68, 93 |
| **etcd** | 02, 06, 30, 97 |
| **Scheduler** | 02, 28, 86 |
| **Controller Manager** | 02, 35 |
| **kubelet** | 02, 06, 87, 91 |
| **kube-proxy** | 02, 12, 77 |
| **CoreDNS** | 12, 33, 82 |
| **CNI** | 12, 76, 78, 84 |
| **CSI** | 13, 89, 95 |
| **GPU** | 25, 26, 56-60 |

---

## 版本兼容性

| 表格版本 | Kubernetes版本 | 更新日期 |
|---------|---------------|---------|
| 当前版本 | v1.25 - v1.32 | 2026-01 |

### 版本特性追踪

| 版本 | 关键特性 |
|------|---------|
| **v1.32** | DRA GA、就地Pod调整GA |
| **v1.31** | AppArmor GA、Gateway API v1 |
| **v1.30** | CEL准入策略GA、Sidecar容器GA |
| **v1.29** | LB IP模式、调度改进 |
| **v1.28** | Sidecar容器Beta、ValidatingAdmissionPolicy Beta |
| **v1.27** | kubectl auth whoami、就地调整Alpha |
| **v1.26** | nftables Alpha |
| **v1.25** | PSP移除、PSA GA、调试容器GA |

---

## 使用说明

### 表格格式

每个表格包含:
- **版本信息**: 适用的 Kubernetes 版本范围
- **参考链接**: 官方文档链接
- **配置示例**: 完整可用的 YAML/Shell 示例
- **最佳实践**: 生产环境推荐配置
- **ACK集成**: 阿里云 Kubernetes 特定内容

### 搜索建议

```bash
# 在表格目录中搜索关键词
grep -r "关键词" tables/

# 搜索特定配置
grep -r "apiVersion: apps/v1" tables/

# 搜索告警规则
grep -r "PrometheusRule" tables/
```

---

## 贡献

欢迎提交 Issue 和 Pull Request 来改进内容。

## 许可

MIT License

---

**维护者**: Kusheet Team | **反馈**: [提交Issue](../../issues)
