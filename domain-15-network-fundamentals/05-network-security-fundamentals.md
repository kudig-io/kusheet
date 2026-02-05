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

## 零信任网络安全架构

### 零信任核心原则

#### 零信任架构模型

```
┌─────────────────────────────────────────────────────────────────┐
│                        零信任安全架构                              │
├─────────────────────────────────────────────────────────────────┤
│  身份认证层                                                     │
│  ├─ 多因素认证 (MFA)                                           │
│  ├─ 证书认证                                                   │
│  └─ 生物识别                                                   │
├─────────────────────────────────────────────────────────────────┤
│  设备信任层                                                     │
│  ├─ 设备注册与认证                                             │
│  ├─ 设备合规性检查                                             │
│  └─ 设备行为分析                                               │
├─────────────────────────────────────────────────────────────────┤
│  网络微隔离层                                                   │
│  ├─ 网络策略动态调整                                           │
│  ├─ 流量加密                                                   │
│  └─ 访问控制列表                                               │
├─────────────────────────────────────────────────────────────────┤
│  应用访问层                                                     │
│  ├─ API 网关                                                   │
│  ├─ 服务网格                                                   │
│  └─ 细粒度权限控制                                             │
└─────────────────────────────────────────────────────────────────┘
```

#### 零信任实施框架

| 组件 | 功能 | 技术实现 |
|:---|:---|:---|
| **身份提供者** | 用户/设备身份管理 | Keycloak, Okta, Azure AD |
| **策略引擎** | 访问控制策略 | OPA, Kyverno |
| **策略执行点** | 策略实施 | Istio, Cilium, Firewalls |
| **信任评估** | 持续信任评估 | SIEM, UEBA |
| **日志审计** | 安全事件记录 | ELK, Splunk |

### DDoS 防护体系

#### DDoS 攻击类型与防护

| 攻击类型 | 特征 | 防护策略 | 推荐工具 |
|:---|:---|:---|:---|
| **SYN Flood** | TCP连接耗尽 | SYN Cookie、连接限制 | iptables, Cloudflare |
| **UDP Flood** | 带宽饱和 | 速率限制、黑洞路由 | BGP Flowspec |
| **HTTP Flood** | 应用层攻击 | 请求频率限制、验证码 | Nginx, ModSecurity |
| **DNS Amplification** | DNS反射放大 | DNS Response Rate Limiting | BIND, PowerDNS |

#### DDoS 防护架构设计

```
┌─────────────────────────────────────────────────────────────────┐
│                        DDoS 多层防护架构                          │
├─────────────────────────────────────────────────────────────────┤
│  第一层: 云端防护                                               │
│  ├─ CDN 缓存 (Cloudflare/AWS Shield)                           │
│  ├─ 云防火墙                                                   │
│  └─ Anycast 网络                                               │
├─────────────────────────────────────────────────────────────────┤
│  第二层: 边界防护                                               │
│  ├─ 硬件防火墙 (Fortinet/Palo Alto)                            │
│  ├─ DDoS 清洗设备                                              │
│  └─ 流量监控                                                   │
├─────────────────────────────────────────────────────────────────┤
│  第三层: 应用防护                                               │
│  ├─ WAF (Web 应用防火墙)                                       │
│  ├─ 负载均衡器限流                                             │
│  └─ 应用层防护                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Linux 系统 DDoS 防护配置

```bash
# iptables DDoS 防护规则集
#!/bin/bash

# 清除现有规则
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# 默认策略
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# 允许已建立连接
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 允许本地回环
iptables -A INPUT -i lo -j ACCEPT

# SYN Flood 防护
iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
iptables -A INPUT -p tcp --syn -j DROP

# Ping of Death 防护
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

# UDP Flood 防护
iptables -A INPUT -p udp -m limit --limit 10/s --limit-burst 20 -j ACCEPT
iptables -A INPUT -p udp -j DROP

# 端口扫描防护
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP

# SSH 暴力破解防护
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# HTTP 限流 (Nginx 前置)
iptables -A INPUT -p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j DROP

# HTTPS 限流
iptables -A INPUT -p tcp --dport 443 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j DROP

# 保存规则
iptables-save > /etc/iptables/rules.v4
```

#### BGP Flowspec DDoS 防护

```bash
# BGP Flowspec 配置示例
# Juniper MX 系列路由器配置

set routing-options autonomous-system 65001

# 定义 Flowspec 策略
set policy-options policy-statement DDoS-Protection term syn-flood from protocol tcp
set policy-options policy-statement DDoS-Protection term syn-flood from destination-port 80
set policy-options policy-statement DDoS-Protection term syn-flood from tcp-flags "syn&ack"
set policy-options policy-statement DDoS-Protection term syn-flood then rate-limit 10000
set policy-options policy-statement DDoS-Protection term syn-flood then discard

# 应用到 BGP
set protocols bgp group flowspec neighbor 10.0.0.2
set protocols bgp group flowspec family inet flowspec
set protocols bgp group flowspec export DDoS-Protection
```

### 安全运营最佳实践

#### 安全监控体系

##### 日志收集与分析架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        安全监控体系                               │
├─────────────────────────────────────────────────────────────────┤
│  数据采集层                                                     │
│  ├─ 系统日志 (rsyslog/syslog-ng)                               │
│  ├─ 网络流量 (NetFlow/sFlow)                                   │
│  ├─ 应用日志 (ELK/Filebeat)                                    │
│  └─ 安全日志 (auditd, SELinux)                                 │
├─────────────────────────────────────────────────────────────────┤
│  存储分析层                                                     │
│  ├─ 日志存储 (Elasticsearch)                                   │
│  ├─ 流量分析 (ntopng)                                          │
│  └─ 威胁情报 (MISP)                                            │
├─────────────────────────────────────────────────────────────────┤
│  告警响应层                                                     │
│  ├─ 实时告警 (AlertManager)                                    │
│  ├─ 安全编排 (SOAR)                                            │
│  └─ 事件响应 (Incident Response)                               │
└─────────────────────────────────────────────────────────────────┘
```

#### 安全监控脚本

```bash
#!/bin/bash
# 安全监控与告警脚本

LOG_FILE="/var/log/security-monitor.log"
ALERT_EMAIL="security@company.com"

# 监控函数集合
monitor_security_events() {
    echo "$(date): 开始安全监控检查" >> $LOG_FILE
    
    # 1. 检查异常登录尝试
    check_failed_logins
    
    # 2. 检查可疑网络连接
    check_suspicious_connections
    
    # 3. 检查系统文件完整性
    check_file_integrity
    
    # 4. 检查资源使用异常
    check_resource_abuse
    
    # 5. 检查防火墙日志
    check_firewall_logs
}

check_failed_logins() {
    local failed_attempts=$(grep "Failed password" /var/log/auth.log | \
        awk '{print $11}' | sort | uniq -c | sort -nr | head -5)
    
    if [ -n "$failed_attempts" ]; then
        echo "$(date): 发现异常登录尝试:" >> $LOG_FILE
        echo "$failed_attempts" >> $LOG_FILE
        
        # 如果某个IP尝试超过10次，触发告警
        echo "$failed_attempts" | while read count ip; do
            if [ $count -gt 10 ]; then
                echo "高风险登录尝试: IP $ip 尝试登录 $count 次" | \
                    mail -s "安全告警: 异常登录尝试" $ALERT_EMAIL
            fi
        done
    fi
}

check_suspicious_connections() {
    local suspicious_ports="22 23 3389 5900"
    local external_connections=$(ss -tn state established | \
        grep -E "($(echo $suspicious_ports | tr ' ' '|'))" | \
        awk '{print $4}' | cut -d: -f2 | sort | uniq)
    
    if [ -n "$external_connections" ]; then
        echo "$(date): 发现可疑外部连接到端口: $external_connections" >> $LOG_FILE
        echo "可疑连接: $external_connections" | \
            mail -s "安全告警: 可疑网络连接" $ALERT_EMAIL
    fi
}

check_file_integrity() {
    # 检查关键系统文件是否被修改
    local critical_files="/etc/passwd /etc/shadow /etc/group"
    
    for file in $critical_files; do
        if [ -f "${file}.hash" ]; then
            current_hash=$(sha256sum $file | awk '{print $1}')
            stored_hash=$(cat ${file}.hash)
            
            if [ "$current_hash" != "$stored_hash" ]; then
                echo "$(date): 文件 $file 被修改!" >> $LOG_FILE
                echo "文件完整性告警: $file" | \
                    mail -s "安全告警: 文件被修改" $ALERT_EMAIL
                
                # 更新哈希值
                sha256sum $file > ${file}.hash
            fi
        else
            # 首次创建哈希文件
            sha256sum $file > ${file}.hash
        fi
    done
}

check_resource_abuse() {
    # 检查 CPU 使用率异常的进程
    local high_cpu_processes=$(ps aux --sort=-%cpu | head -10 | \
        awk '$3 > 80 {print $2":"$3"%:"$11}')
    
    if [ -n "$high_cpu_processes" ]; then
        echo "$(date): 发现高 CPU 使用率进程:" >> $LOG_FILE
        echo "$high_cpu_processes" >> $LOG_FILE
    fi
    
    # 检查内存使用异常
    local high_mem_processes=$(ps aux --sort=-%mem | head -10 | \
        awk '$4 > 80 {print $2":"$4"%:"$11}')
    
    if [ -n "$high_mem_processes" ]; then
        echo "$(date): 发现高内存使用率进程:" >> $LOG_FILE
        echo "$high_mem_processes" >> $LOG_FILE
    fi
}

check_firewall_logs() {
    local dropped_packets=$(grep "DROPPED" /var/log/firewall.log | wc -l)
    
    if [ $dropped_packets -gt 1000 ]; then
        echo "$(date): 防火墙丢弃包数量异常: $dropped_packets" >> $LOG_FILE
        echo "防火墙异常: 丢弃包数量 $dropped_packets" | \
            mail -s "安全告警: 防火墙异常" $ALERT_EMAIL
    fi
}

# 定期执行监控
while true; do
    monitor_security_events
    sleep 300  # 每5分钟执行一次
done
```

#### 安全合规检查清单

```bash
#!/bin/bash
# 安全合规性检查脚本

REPORT_FILE="/tmp/security-compliance-report-$(date +%Y%m%d).txt"

echo "=== 安全合规性检查报告 ===" > $REPORT_FILE
echo "检查时间: $(date)" >> $REPORT_FILE
echo "================================" >> $REPORT_FILE

# 1. 系统基本信息
echo "1. 系统信息检查" >> $REPORT_FILE
echo "操作系统: $(uname -a)" >> $REPORT_FILE
echo "内核版本: $(uname -r)" >> $REPORT_FILE
echo "系统启动时间: $(uptime -s)" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# 2. 用户账户检查
echo "2. 用户账户安全检查" >> $REPORT_FILE
echo "空密码账户:" >> $REPORT_FILE
awk -F: '($2 == "") {print $1}' /etc/shadow >> $REPORT_FILE

echo "UID为0的账户:" >> $REPORT_FILE
awk -F: '($3 == 0) {print $1}' /etc/passwd >> $REPORT_FILE

echo "最近登录用户:" >> $REPORT_FILE
last | head -10 >> $REPORT_FILE
echo "" >> $REPORT_FILE

# 3. 服务检查
echo "3. 网络服务检查" >> $REPORT_FILE
echo "监听端口:" >> $REPORT_FILE
ss -tlnp >> $REPORT_FILE

echo "运行中的服务:" >> $REPORT_FILE
systemctl list-units --type=service --state=running >> $REPORT_FILE
echo "" >> $REPORT_FILE

# 4. 文件权限检查
echo "4. 关键文件权限检查" >> $REPORT_FILE
critical_files=(
    "/etc/passwd"
    "/etc/shadow"
    "/etc/group"
    "/etc/ssh/sshd_config"
    "/etc/sudoers"
)

for file in "${critical_files[@]}"; do
    if [ -f "$file" ]; then
        echo "$file: $(ls -l $file)" >> $REPORT_FILE
    fi
done
echo "" >> $REPORT_FILE

# 5. 安全配置检查
echo "5. 安全配置检查" >> $REPORT_FILE

# SSH 配置检查
if [ -f "/etc/ssh/sshd_config" ]; then
    echo "SSH 配置检查:" >> $REPORT_FILE
    grep -E "^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)" /etc/ssh/sshd_config >> $REPORT_FILE
fi

# 防火墙状态
echo "防火墙状态:" >> $REPORT_FILE
if command -v ufw >/dev/null; then
    ufw status >> $REPORT_FILE
elif command -v firewall-cmd >/dev/null; then
    firewall-cmd --list-all >> $REPORT_FILE
else
    iptables -L >> $REPORT_FILE
fi

echo "" >> $REPORT_FILE

# 6. 系统更新检查
echo "6. 系统更新状态" >> $REPORT_FILE
if command -v apt >/dev/null; then
    echo "待更新包数量: $(apt list --upgradable 2>/dev/null | wc -l)" >> $REPORT_FILE
elif command -v yum >/dev/null; then
    echo "待更新包数量: $(yum check-update 2>/dev/null | wc -l)" >> $REPORT_FILE
fi
echo "" >> $REPORT_FILE

# 发送报告
mail -s "安全合规检查报告 - $(date +%Y-%m-%d)" security@company.com < $REPORT_FILE

echo "安全合规检查完成，报告已生成: $REPORT_FILE"
```

---

## 相关文档

- [01-network-protocols-stack](./01-network-protocols-stack.md) - 网络协议栈
- [213-linux-networking-configuration](./213-linux-networking-configuration.md) - Linux 网络配置
- [216-linux-security-hardening](./216-linux-security-hardening.md) - Linux 安全加固
