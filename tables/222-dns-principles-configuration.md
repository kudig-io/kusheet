# DNS 原理与配置

> **适用版本**: DNS 协议 | **最后更新**: 2026-01

---

## 目录

- [DNS 基础概念](#dns-基础概念)
- [DNS 解析过程](#dns-解析过程)
- [DNS 记录类型](#dns-记录类型)
- [DNS 服务器配置](#dns-服务器配置)
- [DNS 性能优化](#dns-性能优化)
- [DNS 故障排查](#dns-故障排查)

---

## DNS 基础概念

### DNS 架构

```
┌─────────────────────────────────────────────────────────────────┐
│                           根域 (.)                              │
│                    a.root-servers.net ... m.root-servers.net   │
└─────────────────────────────────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
   ┌─────────┐            ┌─────────┐            ┌─────────┐
   │  .com   │            │  .org   │            │  .net   │
   │ TLD 域   │            │ TLD 域   │            │ TLD 域   │
   └─────────┘            └─────────┘            └─────────┘
        │                       │
        ▼                       ▼
   ┌─────────┐            ┌─────────┐
   │example  │            │ apache  │
   │.com     │            │ .org    │
   │权威域    │            │ 权威域   │
   └─────────┘            └─────────┘
```

### 域名层级

| 层级 | 示例 | 说明 |
|:---|:---|:---|
| 根域 | . | 全球 13 组根服务器 |
| 顶级域 TLD | com, org, cn | 通用/国家 |
| 二级域 | example.com | 注册域名 |
| 子域 | www.example.com | 自定义子域 |

### DNS 服务器类型

| 类型 | 功能 |
|:---|:---|
| **权威服务器** | 存储域名记录 |
| **递归服务器** | 代理查询 |
| **缓存服务器** | 缓存结果 |
| **转发器** | 转发查询 |

---

## DNS 解析过程

### 递归查询流程

```
客户端                递归服务器              权威服务器
   │                     │                      │
   │───www.example.com?─►│                      │
   │                     │                      │
   │                     │───.com NS?──────────►│ 根
   │                     │◄──.com NS────────────│
   │                     │                      │
   │                     │───example.com NS?───►│ .com TLD
   │                     │◄──example.com NS─────│
   │                     │                      │
   │                     │───www.example.com?──►│ example.com
   │                     │◄──IP: 93.184.216.34──│
   │                     │                      │
   │◄──IP: 93.184.216.34─│                      │
```

### 查询类型

| 类型 | 说明 |
|:---|:---|
| **递归查询** | 客户端→递归服务器 |
| **迭代查询** | 递归服务器→权威服务器 |

---

## DNS 记录类型

### 常用记录

| 类型 | 说明 | 示例 |
|:---|:---|:---|
| **A** | IPv4 地址 | www → 1.2.3.4 |
| **AAAA** | IPv6 地址 | www → 2001:db8::1 |
| **CNAME** | 别名 | www → example.com |
| **MX** | 邮件服务器 | @ → mail.example.com |
| **NS** | 域名服务器 | @ → ns1.example.com |
| **TXT** | 文本记录 | SPF, DKIM 验证 |
| **SOA** | 权威起始 | 区域元数据 |
| **PTR** | 反向解析 | IP → 域名 |
| **SRV** | 服务记录 | _sip._tcp.example.com |

### 记录示例

```
; Zone: example.com
$TTL 3600

@       IN SOA  ns1.example.com. admin.example.com. (
                2026012701 ; Serial
                7200       ; Refresh
                3600       ; Retry
                1209600    ; Expire
                3600       ; Minimum TTL
)

@       IN NS   ns1.example.com.
@       IN NS   ns2.example.com.
@       IN MX   10 mail.example.com.
@       IN A    93.184.216.34
@       IN AAAA 2606:2800:220:1:248:1893:25c8:1946

ns1     IN A    93.184.216.10
ns2     IN A    93.184.216.11
www     IN CNAME @
mail    IN A    93.184.216.20
```

---

## DNS 服务器配置

### 客户端配置

```bash
# /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
options timeout:2 attempts:3
search example.com
```

### 常用公共 DNS

| 服务商 | IPv4 | IPv6 |
|:---|:---|:---|
| Google | 8.8.8.8, 8.8.4.4 | 2001:4860:4860::8888 |
| Cloudflare | 1.1.1.1, 1.0.0.1 | 2606:4700:4700::1111 |
| 阿里 | 223.5.5.5, 223.6.6.6 | - |
| 腾讯 | 119.29.29.29 | - |

### CoreDNS 配置

```
# Corefile
.:53 {
    forward . 8.8.8.8 8.8.4.4
    cache 30
    log
    errors
}

example.com:53 {
    file /etc/coredns/example.com.zone
    log
}
```

---

## DNS 性能优化

### TTL 策略

| 场景 | 推荐 TTL |
|:---|:---|
| 静态记录 | 3600-86400 秒 |
| 动态变更 | 60-300 秒 |
| CDN | 60-300 秒 |
| 故障切换 | 30-60 秒 |

### 本地缓存

```bash
# systemd-resolved
/etc/systemd/resolved.conf
[Resolve]
DNS=8.8.8.8 8.8.4.4
Cache=yes

# 查看缓存
resolvectl statistics
```

### 预取与预热

```bash
# DNS 预解析 (HTML)
<link rel="dns-prefetch" href="//example.com">

# 批量预热
cat domains.txt | xargs -I {} dig {} @resolver +short
```

---

## DNS 故障排查

### 诊断命令

```bash
# dig 查询
dig example.com
dig @8.8.8.8 example.com
dig example.com MX
dig +trace example.com

# nslookup
nslookup example.com
nslookup -type=MX example.com

# host
host example.com
host -t AAAA example.com
```

### dig 输出解读

```bash
$ dig example.com

; <<>> DiG 9.16.1 <<>> example.com
;; ANSWER SECTION:
example.com.        3600    IN    A    93.184.216.34

;; Query time: 32 msec
;; SERVER: 8.8.8.8#53(8.8.8.8)
;; WHEN: Mon Jan 27 10:00:00 CST 2026
;; MSG SIZE  rcvd: 56
```

### 常见问题

| 问题 | 症状 | 解决方案 |
|:---|:---|:---|
| 解析失败 | NXDOMAIN | 检查域名是否正确 |
| 超时 | 无响应 | 检查 DNS 服务器连通性 |
| 结果错误 | 错误 IP | 检查 DNS 缓存/记录 |
| TTL 过长 | 更新不生效 | 等待 TTL 过期或刷新缓存 |

```bash
# 刷新本地缓存
# Linux (systemd-resolved)
resolvectl flush-caches

# Windows
ipconfig /flushdns
```

---

## 相关文档

- [220-network-protocols-stack](./220-network-protocols-stack.md) - 网络协议栈
- [203-docker-networking-deep-dive](./203-docker-networking-deep-dive.md) - Docker 网络
- [60-coredns-configuration](./60-coredns-configuration.md) - CoreDNS 配置
