# 网络安全基础

> **适用版本**: 通用 | **最后更新**: 2026-01

---

## 目录

- [网络安全概述](#网络安全概述)
- [常见攻击类型](#常见攻击类型)
- [防火墙技术](#防火墙技术)
- [TLS/SSL 加密](#tlsssl-加密)
- [VPN 技术](#vpn-技术)
- [安全最佳实践](#安全最佳实践)

---

## 网络安全概述

### 安全三要素 (CIA)

| 要素 | 说明 | 保护措施 |
|:---|:---|:---|
| **机密性** | 防止未授权访问 | 加密、访问控制 |
| **完整性** | 防止未授权修改 | 哈希、签名 |
| **可用性** | 保证服务可访问 | 冗余、DDoS 防护 |

### 安全层次

```
┌─────────────────────────────────────────────────────────────────┐
│  应用层安全: WAF, 认证授权, 输入验证                             │
├─────────────────────────────────────────────────────────────────┤
│  传输层安全: TLS/SSL, 证书管理                                   │
├─────────────────────────────────────────────────────────────────┤
│  网络层安全: 防火墙, IDS/IPS, VPN                                │
├─────────────────────────────────────────────────────────────────┤
│  物理层安全: 网络隔离, 物理访问控制                               │
└─────────────────────────────────────────────────────────────────┘
```

---

## 常见攻击类型

### 攻击分类

| 攻击类型 | 说明 | 防护措施 |
|:---|:---|:---|
| **DDoS** | 分布式拒绝服务 | 流量清洗、CDN |
| **中间人 (MitM)** | 窃听/篡改通信 | TLS、证书验证 |
| **端口扫描** | 探测开放端口 | 防火墙、最小暴露 |
| **SQL 注入** | 注入恶意 SQL | 参数化查询、WAF |
| **XSS** | 跨站脚本攻击 | 输入过滤、CSP |
| **CSRF** | 跨站请求伪造 | Token 验证 |

### DDoS 类型

| 类型 | 层次 | 特点 |
|:---|:---|:---|
| **SYN Flood** | L4 | 消耗连接资源 |
| **UDP Flood** | L4 | 带宽消耗 |
| **HTTP Flood** | L7 | 消耗应用资源 |
| **DNS 放大** | L4/L7 | 利用 DNS 反射 |

---

## 防火墙技术

### 防火墙类型

| 类型 | 说明 | 代表产品 |
|:---|:---|:---|
| **包过滤** | 基于规则过滤 | iptables, nftables |
| **状态检测** | 跟踪连接状态 | 现代防火墙 |
| **应用网关** | 应用层代理 | WAF |
| **下一代 (NGFW)** | 深度检测 | Palo Alto, Fortinet |

### iptables 安全规则

```bash
# 默认策略
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# 允许已建立连接
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 允许本地回环
iptables -A INPUT -i lo -j ACCEPT

# 允许 SSH (限速)
iptables -A INPUT -p tcp --dport 22 -m state --state NEW \
  -m recent --set --name SSH
iptables -A INPUT -p tcp --dport 22 -m state --state NEW \
  -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# 丢弃无效包
iptables -A INPUT -m state --state INVALID -j DROP

# 防 SYN Flood
iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
```

### 网络分区

```
┌─────────────────────────────────────────────────────────────────┐
│                           互联网                                 │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │    边界防火墙      │
                    └─────────┬─────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
        ┌─────────┐     ┌─────────┐     ┌─────────┐
        │  DMZ    │     │  内网    │     │ 管理网  │
        │ Web/API │     │ 业务系统 │     │ 运维系统 │
        └─────────┘     └─────────┘     └─────────┘
```

---

## TLS/SSL 加密

### TLS 握手

```
客户端                                      服务端
   │                                          │
   │──────── ClientHello ──────────────────►  │
   │         (支持的加密套件, 随机数)           │
   │                                          │
   │◄─────── ServerHello ─────────────────────│
   │         (选择的套件, 证书, 随机数)         │
   │                                          │
   │──────── 密钥交换/验证 ────────────────►   │
   │                                          │
   │         [开始加密通信]                    │
```

### TLS 版本

| 版本 | 状态 | 说明 |
|:---|:---|:---|
| SSL 2.0/3.0 | 废弃 | 严重漏洞 |
| TLS 1.0/1.1 | 废弃 | 不推荐使用 |
| **TLS 1.2** | 推荐 | 广泛支持 |
| **TLS 1.3** | 推荐 | 更安全、更快 |

### 证书配置 (Nginx)

```nginx
server {
    listen 443 ssl http2;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    # TLS 版本
    ssl_protocols TLSv1.2 TLSv1.3;
    
    # 加密套件
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers on;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=31536000" always;
}
```

---

## VPN 技术

### VPN 类型

| 类型 | 协议 | 特点 |
|:---|:---|:---|
| **IPSec** | ESP/AH | 企业级、复杂 |
| **OpenVPN** | UDP/TCP | 开源、灵活 |
| **WireGuard** | UDP | 现代、高性能 |
| **SSL VPN** | HTTPS | 浏览器兼容 |

### WireGuard 配置

```ini
# 服务端 /etc/wireguard/wg0.conf
[Interface]
PrivateKey = SERVER_PRIVATE_KEY
Address = 10.0.0.1/24
ListenPort = 51820

[Peer]
PublicKey = CLIENT_PUBLIC_KEY
AllowedIPs = 10.0.0.2/32

# 客户端
[Interface]
PrivateKey = CLIENT_PRIVATE_KEY
Address = 10.0.0.2/24

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = server.example.com:51820
AllowedIPs = 0.0.0.0/0
```

```bash
# 启动
wg-quick up wg0
```

---

## 安全最佳实践

### 网络安全清单

| 项目 | 措施 |
|:---|:---|
| 最小暴露 | 仅开放必要端口 |
| 默认拒绝 | 白名单策略 |
| 加密通信 | 强制 TLS |
| 网络分段 | 隔离敏感区域 |
| 监控告警 | 异常流量检测 |
| 定期审计 | 规则审查 |

### 端口安全

```bash
# 查看监听端口
ss -tlnp

# 检查暴露端口
nmap -sT localhost
```

### 日志监控

```bash
# 连接日志
conntrack -L

# 防火墙日志
iptables -A INPUT -j LOG --log-prefix "DROPPED: "
```

---

## 相关文档

- [220-network-protocols-stack](./220-network-protocols-stack.md) - 网络协议栈
- [213-linux-networking-configuration](./213-linux-networking-configuration.md) - Linux 网络配置
- [216-linux-security-hardening](./216-linux-security-hardening.md) - Linux 安全加固
