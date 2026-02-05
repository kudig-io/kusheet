# Domain-7: Kubernetes 安全与合规

> **文档数量**: 16 篇 | **最后更新**: 2026-02 | **适用版本**: Kubernetes v1.25-v1.32

---

## 概述

Kubernetes 安全与合规域全面覆盖 Kubernetes 安全体系、认证授权、网络安全、运行时安全、审计合规等核心安全主题。从基础安全配置到企业级合规要求，为企业构建安全可靠的 Kubernetes 平台提供完整指导。

**核心价值**：
- 🔒 **认证授权**：RBAC、OIDC、ServiceAccount 完整体系
- 🛡️ **网络安全**：NetworkPolicy、服务网格、零信任安全
- ⚡ **运行时安全**：Seccomp/AppArmor、威胁检测、运行时防护
- 📋 **合规审计**：审计策略、日志收集、合规性检查

---

## 文档目录

### 核心安全体系 (01-04)

| # | 文档 | 关键内容 | 安全层级 |
|:---:|:---|:---|:---|
| 01 | [认证授权体系](./01-authentication-authorization-system.md) | RBAC、OIDC、ServiceAccount、认证授权体系 | 身份安全 |
| 02 | [网络安全策略](./02-network-security-policies.md) | NetworkPolicy、服务网格、零信任安全模型 | 网络安全 |
| 03 | [运行时安全防护](./03-runtime-security-defense.md) | Seccomp/AppArmor、Falco威胁检测、运行时防护 | 运行时安全 |
| 04 | [审计合规管理](./04-audit-logging-compliance.md) | 审计策略、日志收集、合规性检查、SOC2/ISO认证 | 合规安全 |

### 安全实践工具 (05-16)

| # | 文档 | 关键内容 | 实践价值 |
|:---:|:---|:---|:---|
| 05 | [安全最佳实践](./05-security-best-practices.md) | 安全配置基线、最佳实践指南 | 实施参考 |
| 06 | [生产安全加固](./06-security-hardening-production.md) | 生产环境加固清单、安全配置 | 部署指南 |
| 07 | [Pod安全标准](./07-pod-security-standards.md) | Pod安全标准(PSS)、安全策略 | 应用安全 |
| 08 | [RBAC权限矩阵](./08-rbac-matrix-configuration.md) | 权限矩阵配置、最小权限原则 | 权限管理 |
| 09 | [证书管理体系](./09-certificate-management.md) | PKI、cert-manager、证书轮换 | 身份认证 |
| 10 | [镜像安全扫描](./10-image-security-scanning.md) | 镜像漏洞扫描、安全检查 | 镜像安全 |
| 11 | [策略引擎对比](./11-policy-engines-opa-kyverno.md) | OPA/Kyverno策略引擎对比 | 策略管理 |
| 12 | [合规认证指南](./12-compliance-certification.md) | SOC2/ISO/PCI合规认证 | 合规要求 |
| 13 | [合规审计实践](./13-compliance-audit-practices.md) | 审计日志配置实践、合规检查 | 审计实施 |
| 14 | [密钥管理工具](./14-secret-management-tools.md) | Vault/ESO集成、密钥轮换 | 密钥管理 |
| 15 | [安全扫描工具](./15-security-scanning-tools.md) | Trivy/Falco安全扫描工具 | 安全检测 |
| 16 | [策略验证工具](./16-policy-validation-tools.md) | 策略校验、合规检查工具 | 策略验证 |

---

## 安全架构全景图

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes 安全体系                         │
├─────────────────────────────────────────────────────────────┤
│  身份认证层      │  访问控制层      │  运行时层      │  合规层  │
│  (Authentication) │ (Authorization) │ (Runtime)   │ (Compliance)│
│                 │                 │             │          │
│  OIDC/SERVICE   │  RBAC/PSP/PSS   │ SECCOMP/    │ AUDIT/   │
│  ACCOUNT        │  NETWORKPOLICY  │ APPARMOR    │ LOGGING  │
│  CERT-MANAGER   │  SERVICE MESH   │ FALCO       │ SOC2/ISO │
└─────────────────────────────────────────────────────────────┘
```

---

## 学习路径建议

### 🔐 安全基础路径
**01 → 05 → 06 → 08**  
从认证授权开始，掌握基础安全配置和 RBAC 权限管理

### 🛡️ 网络安全路径  
**02 → 04 → 12 → 13**  
深入网络安全策略和合规审计要求

### ⚡ 运行时安全路径
**03 → 10 → 15**  
掌握运行时安全防护和镜像安全扫描

### 🏢 企业合规路径
**04 → 12 → 13 → 16**  
构建完整的合规体系和审计机制

---

## 相关领域

- **[Domain-3: 控制平面](../domain-3-control-plane)** - 控制平面安全配置
- **[Domain-8: 可观测性](../domain-8-observability)** - 安全监控和告警
- **[Domain-12: 故障排查](../domain-12-troubleshooting)** - 安全事件排查

---

**维护者**: Kusheet Security Team | **许可证**: MIT