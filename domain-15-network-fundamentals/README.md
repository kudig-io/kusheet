# Domain-15: 网络基础

> **文档数量**: 6 篇 | **最后更新**: 2026-02 | **适用版本**: TCP/IP协议栈通用

---

## 概述

网络基础域深入讲解计算机网络核心原理，涵盖OSI七层模型、TCP/UDP协议详解、DNS系统、负载均衡技术、网络安全基础和SDN网络虚拟化等关键技术。为理解Kubernetes网络奠定坚实的理论基础。

**核心价值**：
- 🌐 **协议基础**：OSI/TCP-IP模型、TCP/UDP协议栈深度解析
- 📡 **域名系统**：DNS原理、解析过程、配置优化
- ⚖️ **负载均衡**：四层/七层负载均衡技术、算法原理
- 🔒 **网络安全**：防火墙、加密传输、安全协议
- 🔄 **网络虚拟化**：SDN、NFV、网络功能虚拟化

---

## 文档目录

| # | 文档 | 关键内容 | 技术深度 |
|:---:|:---|:---|:---|
| 01 | [网络协议栈](./01-network-protocols-stack.md) | OSI七层模型、TCP/IP四层模型、协议封装 | 基础理论 |
| 02 | [TCP/UDP详解](./02-tcp-udp-deep-dive.md) | TCP三次握手/四次挥手、UDP无连接特性、性能对比 | 协议深度 |
| 03 | [DNS原理配置](./03-dns-principles-configuration.md) | DNS解析流程、递归迭代查询、CoreDNS配置 | 系统服务 |
| 04 | [负载均衡技术](./04-load-balancing-technologies.md) | L4/L7负载均衡、算法策略、健康检查 | 负载分发 |
| 05 | [网络安全基础](./05-network-security-fundamentals.md) | 防火墙、TLS/SSL、加密算法、安全协议 | 安全防护 |
| 06 | [SDN网络虚拟化](./06-sdn-network-virtualization.md) | SDN架构、OpenFlow、网络功能虚拟化(NFV) | 网络创新 |

---

## 网络协议栈全景图

```
应用层 (HTTP/DNS/FTP)     ← 应用协议
    ↓
传输层 (TCP/UDP)          ← 端到端通信
    ↓
网络层 (IP/ICMP)          ← 路由寻址
    ↓
数据链路层 (以太网/WiFi)   ← 局域网通信
    ↓
物理层 (光纤/电缆)        ← 物理传输
```

---

## 学习路径建议

### 🎯 基础入门路径
**01 → 02 → 03**  
从网络协议栈开始，深入TCP/UDP协议，掌握DNS系统

### 🔧 实践应用路径  
**04 → 05**  
学习负载均衡技术和网络安全防护实践

### 🚀 进阶拓展路径
**06**  
探索SDN网络虚拟化和现代网络架构

---

## 核心概念关系

```
TCP/IP模型
    ├── 应用层 ↔ HTTP/DNS/FTP等应用协议
    ├── 传输层 ↔ TCP可靠传输 / UDP快速传输
    ├── 网络层 ↔ IP路由寻址 / ICMP控制消息
    └── 链路层 ↔ 以太网帧 / WiFi无线传输
```

---

## 相关领域

- **[Domain-5: Kubernetes网络](../domain-5-networking)** - K8s网络实现
- **[Domain-14: Linux基础](../domain-14-linux)** - Linux网络配置
- **[Domain-16: 存储基础](../domain-16-storage-fundamentals)** - 网络存储协议

---

**维护者**: Kusheet Network Team | **许可证**: MIT