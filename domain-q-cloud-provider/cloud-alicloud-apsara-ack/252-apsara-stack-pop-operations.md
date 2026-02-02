# 专有云 (Apsara Stack) - POP 平台运维 (ASOP)

> **环境**: Apsara Stack 企业版/精简版 | **最后更新**: 2026-01

---

## 目录

- [ASOP 运维架构概述](#asop-运维架构概述)
- [POP 网关与 API 接入](#pop-网关与-api-接入)
- [多租户资源隔离与配额](#多租户资源隔离与配额)
- [自动化巡检与监控链路](#自动化巡检与监控链路)
- [常见 POP 错误码与处理](#常见-pop-错误码与处理)

---

## ASOP 运维架构概述

**ASOP (Apsara Stack Operations Platform)** 是专有云的统一运维中枢。它不仅管理 ECS/SLB 等云产品，还负责底层物理资源与安全。

### 核心子系统

| 组件名称 | 核心职责 | 运维关注点 |
|:---|:---|:---|
| **Tianji (天基)** | 自动化部署与基线管理 | 集群部署进度、补丁分发 |
| **Tianmu (天目)** | 统一监控平台 | 物理机告警、容器健康度 |
| **Kong (控)** | POP 接口网关 | 请求节流、API 安全认证 |
| **Fuxi (伏羲)** | 分布式任务调度 | 离线任务、大规模作业调度 |

---

## POP 网关与 API 接入

POP (Platform Open API) 是上层系统 (如 ACK) 与底层云产品交互的桥梁。

### API 调用链 (示例: 创建 ECS)

```mermaid
graph LR
    A[ACK Console] --> B[POP Gateway]
    B --> C[ECS Controller]
    C --> D[Tianji / Computing]
```

### 调用规范

1. **接入地址**: 通常为私网 VIP (如 `pop.apsarastack.com`)。
2. **认证方式**: 采用 `AccessKey / AccessSecret`，需在 **RAM** 中为子用户配置。
3. **SDK**: 专有云通常需要使用特定版本的云产品 SDK (如 `aliyun-python-sdk-core`)。

---

## 多租户资源隔离与配额

专有云通过 **组织 (Organization)** 和 **资源集 (Resource Group)** 实现多租户能力。

### 配额管理 (Quota)

- **计算配额**: CPU 核心数、内存容量。
- **存储配额**: ESSD 容量、OSS Bucket 数。
- **网络配额**: 弹性 IP (EIP) 数量、SLB 实例数。

> [!IMPORTANT]
> **运维注意**: ACK 扩容失败最常见的原因是底层配额不足，需在 ASOP 门户的 "资源管理" 模块手动扩充。

---

## 自动化巡检与监控链路

### 监控集成逻辑

1. **基础监控**: Tianmu 采集物理服务器指标。
2. **云产品监控**: 通过 POP 接口抓取 SLB/RDS 等健康状态。
3. **告警分发**: 支持 Webhook、邮件、甚至短信 (需对接短信网关)。

### 常用巡检命令 (ASOP 运维节点)

```bash
# 检查 POP 网关连通性
curl -v http://pop.apsarastack.com/ping

# 通过 CLI 查询特定租户的配额使用率
aliyun pop-cli GetQuota --OwnerId 12345
```

---

## 常见 POP 错误码与处理

| 错误码 | 含义 | 建议行动 |
|:---|:---|:---|
| `QuotaExceeded` | 配额超出限制 | 在 ASOP 中调优租户 Quota |
| `InvalidAccessKeyId` | AK 错误或已禁用 | 检查 RAM 控制台密钥状态 |
| `ResourceBusy` | 资源正在变更中 | 等待上一个操作完成 (如 ECS 正在停止) |
| `Forbidden.Unauthorized` | 权限不足 | 在 RAM 中赋予对应的角色权限 |

---

## 相关文档

- [243-ack-ram-authorization.md](./243-ack-ram-authorization.md) - RAM 权限授权详解
- [250-apsara-stack-ess-scaling.md](./250-apsara-stack-ess-scaling.md) - 专有云 ESS 弹性伸缩
- [156-alibaba-cloud-integration.md](./156-alibaba-cloud-integration.md) - 阿里云集成总表
