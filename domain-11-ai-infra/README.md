# Domain-11: AI基础设施

> **文档数量**: 30 篇 | **最后更新**: 2026-02 | **适用版本**: Kubernetes v1.25-v1.32 + AI/ML Stack

---

## 概述

AI基础设施域全面覆盖 Kubernetes 上的 AI/ML 工作负载管理、GPU调度优化、分布式训练、模型部署、推理服务等核心技术。从基础AI架构到LLM大模型全栈解决方案，为企业构建生产级AI平台提供完整指导。

**核心价值**：
- 🚀 **GPU调度**：GPU资源调度、共享分配、性能优化
- 🧠 **分布式训练**：多机多卡训练、弹性扩缩容、故障恢复
- 📦 **模型管理**：模型注册、版本控制、部署流水线
- 🔮 **推理服务**：高性能推理、模型压缩、在线服务

---

## 文档目录

### AI基础架构 (01-06)

| # | 文档 | 关键内容 | AI基础 |
|:---:|:---|:---|:---|
| 01 | [AI基础设施概览](./01-ai-infrastructure-overview.md) | AI平台架构、K8s AI生态、部署模式 | 架构基础 |
| 02 | [AI/ML工作负载](./02-ai-ml-workloads.md) | 训练/推理工作负载特征、资源需求 | 负载分析 |
| 03 | [GPU调度管理](./03-gpu-scheduling-management.md) | GPU资源调度、设备插件、共享机制 | 资源调度 |
| 04 | [GPU监控DCGM](./04-gpu-monitoring-dcgm.md) | DCGM监控、GPU指标收集、性能分析 | 监控体系 |
| 05 | [分布式训练](./05-distributed-training-frameworks.md) | Horovod/PyTorch-DDP、弹性训练、故障恢复 | 训练框架 |
| 06 | [AI数据管道](./06-ai-data-pipeline.md) | 数据预处理、特征工程、Pipeline设计 | 数据处理 |

### 模型全生命周期 (07-14)

| # | 文档 | 关键内容 | 模型管理 |
|:---:|:---|:---|:---|
| 07 | [实验管理](./07-ai-experiment-management.md) | MLflow实验跟踪、超参调优、结果分析 | 实验管理 |
| 08 | [AutoML超参调优](./08-automl-hyperparameter-tuning.md) | Katib、Optuna、超参搜索策略 | 自动化 |
| 09 | [模型注册中心](./09-model-registry.md) | Model Registry、版本控制、元数据管理 | 注册管理 |
| 10 | [模型部署管理](./10-model-deployment-management.md) | 模型打包、部署策略、蓝绿发布 | 部署运维 |
| 11 | [AI安全防护](./11-ai-security-model-protection.md) | 模型安全、对抗攻击防护、隐私保护 | 安全防护 |
| 12 | [AI成本分析](./12-ai-cost-analysis-finops.md) | GPU成本优化、Spot实例、FinOps实践 | 成本管控 |
| 13 | [AI平台可观测](./13-ai-platform-observability.md) | AI监控指标、模型性能追踪、异常检测 | 可观测性 |
| 14 | [性能故障排查](./14-troubleshooting-performance.md) | AI性能瓶颈分析、故障诊断、优化建议 | 故障处理 |

### LLM大模型专项 (15-25)

| # | 文档 | 关键内容 | 大模型 |
|:---:|:---|:---|:---|
| 15 | [LLM数据管道](./15-llm-data-pipeline.md) | 大模型数据处理、清洗、预训练数据准备 | 数据工程 |
| 16 | [LLM微调训练](./16-llm-finetuning.md) | LoRA/QLoRA微调、指令微调、持续学习 | 模型训练 |
| 17 | [LLM推理服务](./17-llm-inference-serving.md) | 推理优化、批处理、长序列处理 | 推理部署 |
| 18 | [LLM服务架构](./18-llm-serving-architecture.md) | 推理服务架构、负载均衡、缓存策略 | 服务设计 |
| 19 | [LLM量化压缩](./19-llm-quantization.md) | 模型量化、蒸馏、剪枝、压缩部署 | 模型优化 |
| 20 | [向量数据库RAG](./20-vector-database-rag.md) | 向量检索、RAG架构、知识库构建 | 检索增强 |
| 21 | [多模态模型](./21-multimodal-models.md) | 多模态融合、视觉语言模型、跨模态检索 | 多模态 |
| 22 | [LLM隐私安全](./22-llm-privacy-security.md) | 数据隐私、模型安全、合规要求 | 安全合规 |
| 23 | [LLM成本监控](./23-llm-cost-monitoring.md) | 大模型成本分析、预算控制、计费优化 | 成本管理 |
| 24 | [LLM版本管理](./24-llm-model-versioning.md) | 模型版本控制、AB测试、灰度发布 | 版本管理 |
| 25 | [LLM可观测性](./25-llm-observability.md) | 大模型监控、Prompt追踪、生成质量评估 | 大模型监控 |

### 成本与可持续 (26-30)

| # | 文档 | 关键内容 | 成本优化 |
|:---:|:---|:---|:---|
| 26 | [成本优化概览](./26-cost-optimization-overview.md) | AI成本优化策略、资源配置、预算管理 | 成本策略 |
| 27 | [Kubecost管理](./27-cost-management-kubecost.md) | Kubecost配置、成本分析、优化建议 | 成本工具 |
| 28 | [绿色计算](./28-green-computing-sustainability.md) | 绿色AI、能耗优化、可持续发展 | 可持续性 |
| 29 | [阿里云集成](./29-alibaba-cloud-integration.md) | 阿里云AI服务集成、ACK优化配置 | 云厂商 |
| 30 | [AI安全合规](./30-ai-security-compliance.md) | AI合规要求、数据治理、安全审计 | 合规管理 |

---

## AI平台架构全景图

```
┌─────────────────────────────────────────────────────────────┐
│                    AI Infrastructure Platform                  │
├─────────────────────────────────────────────────────────────┤
│  应用层    │  服务层    │  平台层    │  基础设施层  │  硬件层    │
│  LLM应用   │  推理服务   │  模型管理   │  K8s调度    │  GPU集群   │
│  RAG系统   │  训练服务   │  实验管理   │  存储网络    │  CPU节点   │
└─────────────────────────────────────────────────────────────┘
```

---

## 学习路径建议

### 🎯 AI入门路径
**01 → 02 → 03 → 04**  
从AI基础设施概览开始，掌握GPU调度和监控基础

### 🚀 大模型路径  
**15 → 16 → 17 → 18**  
专注LLM大模型的数据处理、训练和推理服务

### 🏢 企业级路径
**09 → 10 → 26 → 27**  
构建完整的模型管理和成本优化体系

### 🔬 研究开发路径
**05 → 06 → 07 → 08**  
深入分布式训练和AutoML自动化研究

---

## 相关领域

- **[Domain-3: 控制平面](../domain-3-control-plane)** - GPU调度器配置
- **[Domain-9: 平台运维](../domain-9-platform-ops)** - AI平台运维
- **[Domain-12: 故障排查](../domain-12-troubleshooting)** - AI性能问题诊断

---

**维护者**: Kusheet AI Team | **许可证**: MIT