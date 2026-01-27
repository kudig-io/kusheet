# ACK 关联产品 - 负载均衡 (SLB/NLB/ALB)

> **适用版本**: ACK v1.25 - v1.32 | **最后更新**: 2026-01

---

## 目录

- [负载均衡选型指南](#负载均衡选型指南)
- [Service (NLB/CLB) 详解](#service-nlbclb-详解)
- [ALB Ingress 高级配置](#alb-ingress-高级配置)
- [生产级注解 (Annotations) 速查表](#生产级注解-annotations-速查表)
- [故障排查与性能调优](#故障排查与性能调优)

---

## 负载均衡选型指南

| 产品 | 工作层级 | 性能/规格 | 适用场景 | 核心优势 |
|:---|:---|:---|:---|:---|
| **NLB (网络型)** | 四层 (TCP/UDP) | 1亿以上并发连接 | 高并发、超低延迟 | 弹性极强、支持多可用区打散 |
| **ALB (应用型)** | 七层 (HTTP/S) | 性能按需水平扩展 | 复杂路由、微服务治理 | 原生支持 gRPC, HTTP/2, QUIC |
| **CLB (传统型)** | 四/七层 | 规格固定 | 简单负载需求、存量迁移 | 经典稳定、成本可控 |

---

## Service (NLB/CLB) 详解

### 生产级 NLB Service 示例

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nlb-service
  annotations:
    # 负载均衡类型设为 nlb
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-type: "nlb"
    # 指定规格 (示例为不限规格，按需计费)
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-spec: "nlb.s1.small"
    # 内网或外网 (internet / intranet)
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-address-type: "internet"
    # 强制覆盖已有监听，确保配置同步
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-force-override-listeners: "true"
spec:
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
  selector:
    app: my-app
  type: LoadBalancer
```

---

## ALB Ingress 高级配置

### ALB IngressClass

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
spec:
  controller: ingress.k8s.alibabacloud/alb
```

### 关键高级功能

- **金丝雀发布 (Canary)**: 基于权重或 Header 的流量切换。
- **SSL 卸载**: 在 ALB 端统一管理证书，减轻后端压力。
- **gRPC 支持**: 专门针对 AI/微服务的高性能通信。
- **自定义转发规则**: 基于 URL/Host/Header/Cookie 的精准控制。

---

## 生产级注解 (Annotations) 速查表

### 核心管理类

| 注解 | 默认值 | 说明 |
|:---|:---|:---|
| `.../loadbalancer-id` | - | 指定已有负载均衡实例 ID (复用模式) |
| `.../loadbalancer-force-override-listeners` | `false` | 是否强制刷新监听配置 |
| `.../loadbalancer-resource-group-id` | - | 指定资源组 ID，利于云资源管理 |

### 网络与性能类

| 注解 | 推荐值 | 说明 |
|:---|:---|:---|
| `.../loadbalancer-bandwidth` | 100 - 5000 | 总带宽限制 (仅外网有效) |
| `.../loadbalancer-scheduler` | `wrr` | 调度算法: `wrr` (加权轮询), `wlc` (加权最小连接) |
| `.../loadbalancer-vswitch-id` | - | 指定 SLB 所在的虚拟交换机，实现多可用区控制 |

---

## 故障排查与性能调优

### 常见故障诊断

| 现象 | 可能原因 | 解决方法 |
|:---|:---|:---|
| **SLB 无法创建** | 权限不足 / 规格售罄 | 检查 RAM 权限；尝试更换规格或可用区 |
| **健康检查失败** | 安全组未放通 / 后端路径错误 | 检查 `service-ns` 安全组及应用健康检查端口路径 |
| **流量不均** | 调度算法不匹配 / 会话保持过长 | 检查 `wrr` 权重设置；调整会话保持时间 |

### 性能调优建议

1. **启用 Local 流量策略**: 设置 `externalTrafficPolicy: Local` 可保存客户端源 IP 并减少跨节点损耗。
2. **多可用区打散**: 生产环境应当配置跨 2-3 个可用区的 SLB，提高容灾能力。
3. **NLB 优先选型**: 对于 K8s 内部具有大量并发的需求，NLB 的弹性性能显著优于 CLB。

---

## 相关文档

- [223-load-balancing-technologies.md](./223-load-balancing-technologies.md) - 负载均衡通用技术
- [63-ingress-fundamentals.md](./63-ingress-fundamentals.md) - Ingress 基础与选型
- [156-alibaba-cloud-integration.md](./156-alibaba-cloud-integration.md) - 阿里云集成总表
