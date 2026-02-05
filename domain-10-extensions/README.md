# Domain-10: Kubernetes 扩展生态

> **文档数量**: 13 篇 | **最后更新**: 2026-02 | **适用版本**: Kubernetes v1.25-v1.32

---

## 概述

Kubernetes 扩展生态域涵盖 CRD 开发、Operator 模式、准入控制、包管理、CI/CD、GitOps 等扩展开发和运维核心技术。为企业构建可扩展的 Kubernetes 平台提供完整的技术栈和实践指南。

**核心价值**：
- 🧩 **扩展开发**：CRD、Operator、准入控制器开发实践
- 📦 **包管理**：Helm/Kustomize、Chart 开发、包分发
- 🔁 **CI/CD集成**：流水线设计、GitOps 工作流、自动化部署
- 🔧 **运维基础**：基础运维命令、集群管理、故障排查

---

## 文档目录

### 扩展开发 (01-04)

| # | 文档 | 关键内容 | 开发难度 |
|:---:|:---|:---|:---|
| 01 | [CRD开发指南](./01-crd-development-guide.md) | 自定义资源定义开发、CRD 最佳实践 | 中级 |
| 02 | [Operator开发模式](./02-operator-development-patterns.md) | Kubebuilder开发实践、控制器模式 | 高级 |
| 03 | [准入控制配置](./03-admission-webhook-configuration.md) | Webhook配置与实现、验证变更 | 中级 |
| 04 | [API聚合扩展](./04-api-aggregation-extension.md) | API Server扩展机制、聚合层设计 | 高级 |

### 包管理与分发 (05-07)

| # | 文档 | 关键内容 | 管理价值 |
|:---:|:---|:---|:---|
| 05 | [包管理工具](./05-package-management-tools.md) | Helm/Kustomize/Carvel对比、选型指南 | 基础 |
| 06 | [Helm管理](./06-helm-charts-management.md) | Chart开发基础、模板语法、最佳实践 | 实用 |
| 07 | [Helm进阶](./07-helm-advanced-operations.md) | 高级运维、CI/CD集成、依赖管理 | 进阶 |

### CI/CD与GitOps (08-09)

| # | 文档 | 关键内容 | 自动化程度 |
|:---:|:---|:---|:---|
| 08 | [CI/CD流水线](./08-cicd-pipelines.md) | Jenkins/Tekton/云效、流水线设计 | 高 |
| 09 | [GitOps工作流](./09-gitops-workflow-argocd.md) | ArgoCD、GitOps工作流、多集群管理 | 高 |

### 构建与部署工具 (10)

| # | 文档 | 关键内容 | 构建效率 |
|:---:|:---|:---|:---|
| 10 | [镜像构建工具](./10-image-build-tools.md) | Buildah/Kaniko/ko构建工具、安全构建 | 高 |

### 服务网格 (11-12)

| # | 文档 | 关键内容 | 服务治理 |
|:---:|:---|:---|:---|
| 11 | [服务网格概览](./11-service-mesh-overview.md) | Istio/Linkerd概览、服务网格架构 | 中级 |
| 12 | [网格进阶](./12-service-mesh-advanced.md) | 流量管理、可观测、安全策略 | 高级 |

### 运维基础 (13)

| # | 文档 | 关键内容 | 运维技能 |
|:---:|:---|:---|:---|
| 13 | [运维基础](./13-kubernetes-operations-fundamentals.md) | 基础运维命令、集群管理、故障排查 | 基础 |

---

## 扩展开发生命周期

```
需求分析 → CRD设计(01) → Operator开发(02) → 
准入控制(03) → API扩展(04) → 包管理(05-07) → 
CI/CD集成(08-09) → 部署验证(10) → 服务治理(11-12)
```

---

## 学习路径建议

### 🎯 扩展开发路径
**01 → 02 → 03 → 04**  
从 CRD 开发开始，逐步掌握完整的扩展开发技能

### 📦 包管理路径  
**05 → 06 → 07**  
掌握 Helm 包管理和高级运维操作

### 🔁 自动化路径
**08 → 09**  
深入 CI/CD 流水线和 GitOps 工作流实践

### 🔧 运维提升路径
**13 → 11 → 12**  
从基础运维开始，逐步掌握服务网格高级特性

---

## 技术栈全景图

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes 扩展生态                         │
├─────────────────────────────────────────────────────────────┤
│  开发层    │  管理层    │  部署层    │  治理层    │  运维层    │
│  CRD/      │  HELM/     │  CI/CD/    │  SERVICE   │  BASIC     │
│  OPERATOR  │  KUSTOMIZE │  GITOPS    │  MESH      │  OPS       │
└─────────────────────────────────────────────────────────────┘
```

---

## 相关领域

- **[Domain-2: 设计原理](../domain-2-design-principles)** - 扩展设计原则
- **[Domain-9: 平台运维](../domain-9-platform-ops)** - 平台扩展管理
- **[Domain-12: 故障排查](../domain-12-troubleshooting)** - 扩展故障处理

---

**维护者**: Kusheet Extensions Team | **许可证**: MIT