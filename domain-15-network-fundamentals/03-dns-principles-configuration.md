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

## DNS高级安全防护体系

### DNS安全威胁模型与防护策略

#### DNS攻击类型深度分析

| 攻击类型 | 攻击原理 | 影响范围 | 防护措施 | 检测方法 |
|:---|:---|:---|:---|:---|
| **DNS劫持** | 修改DNS解析结果 | 全网用户 | DNSSEC、HTTPS DNS | 解析结果验证 |
| **DNS污染** | 注入虚假DNS响应 | 区域性影响 | DoH/DoT加密 | 延迟分析 |
| **DNS放大攻击** | 利用DNS反射放大流量 | 基础设施瘫痪 | RRL、ACL限制 | 流量模式分析 |
| **域名抢注** | 注册相似域名钓鱼 | 特定品牌 | 商标保护、监控 | 域名监控 |
| **DNS隧道** | 利用DNS传输恶意数据 | 数据泄露 | DPI检测、策略阻断 | 异常查询检测 |

#### DNSSEC高级配置与管理

```bash
# DNSSEC生产环境部署指南

# 1. 区域签名配置 (BIND示例)
configure_dnssec_zone() {
    local zone_name=$1
    local zone_file="/var/named/${zone_name}.zone"
    
    # 生成密钥对
    cd /var/named
    dnssec-keygen -a RSASHA256 -b 2048 -n ZONE $zone_name
    dnssec-keygen -a RSASHA256 -b 2048 -n ZONE -f KSK $zone_name
    
    # 获取密钥ID
    ksk_key=$(ls K${zone_name}.+008+*.key | grep KSK | sed 's/.*+\([0-9]\+\)\.key/\1/')
    zsk_key=$(ls K${zone_name}.+008+*.key | grep -v KSK | sed 's/.*+\([0-9]\+\)\.key/\1/')
    
    # 更新区域文件
    cat >> $zone_file << EOF

\$INCLUDE K${zone_name}.+008+${ksk_key}.key
\$INCLUDE K${zone_name}.+008+${zsk_key}.key

\$DNSKEY 3600 IN DNSKEY 257 3 8 AwEAA... ; KSK
\$DNSKEY 3600 IN DNSKEY 256 3 8 AwEAA... ; ZSK
EOF

    # 签名区域
    dnssec-signzone -S -o $zone_name -k K${zone_name}.+008+${ksk_key} $zone_file
    
    # 配置named.conf
    cat >> /etc/named.conf << EOF
zone "${zone_name}" {
    type master;
    file "${zone_name}.signed";
    allow-transfer { key transfer-key; };
    also-notify { 10.0.0.2; };
};
EOF
}

# 2. DNSSEC验证配置
configure_dnssec_validation() {
    # 递归服务器DNSSEC验证
    cat >> /etc/named.conf << EOF
options {
    dnssec-enable yes;
    dnssec-validation yes;
    dnssec-lookaside auto;
};

# 信任锚点配置
managed-keys {
    "." initial-key 257 3 8 "AwEAA...";  # 根区域KSK
};
EOF

    # 验证DNSSEC状态
    dig +dnssec +multiline cloudflare.com
    delv @1.1.1.1 cloudflare.com
}

# 3. DNSSEC密钥轮换策略
implement_key_rotation() {
    local zone_name=$1
    local rotation_interval=3600  # 1小时
    
    # 密钥轮换脚本
    cat > /usr/local/bin/dnssec-key-rotation.sh << EOF
#!/bin/bash
ZONE="$zone_name"
WORKDIR="/var/named"

cd \$WORKDIR

# 生成新ZSK
NEW_ZSK=\$(dnssec-keygen -a RSASHA256 -b 2048 -n ZONE \$ZONE)
NEW_ZSK_ID=\$(echo \$NEW_ZSK | sed 's/.*+\([0-9]\+\)/\1/')

# 签名区域 (预发布新密钥)
dnssec-settime -I now+7d \${NEW_ZSK}.key
dnssec-signzone -S -o \$ZONE -k K\${ZONE}.+008+*.key

# 发布新密钥
rndc reload \$ZONE

# 等待传播
sleep 3600

# 激活新密钥
dnssec-settime -A now \${NEW_ZSK}.key
dnssec-signzone -S -o \$ZONE -k K\${ZONE}.+008+*.key

# 清理旧密钥
find . -name "K\${ZONE}.+008+*.key" -mtime +30 -delete
find . -name "K\${ZONE}.+008+*.private" -mtime +30 -delete
EOF

    chmod +x /usr/local/bin/dnssec-key-rotation.sh
    
    # 设置定时任务
    echo "0 */6 * * * /usr/local/bin/dnssec-key-rotation.sh" >> /var/spool/cron/root
}
```

### DNS高级安全监控与告警

#### DNS异常行为检测系统

```bash
#!/bin/bash
# DNS安全监控与异常检测系统

DNS_LOG_FILE="/var/log/named/query.log"
ALERT_EMAIL="security@company.com"
MONITOR_INTERVAL=60

# DNS查询异常检测
detect_dns_anomalies() {
    echo "=== DNS安全监控报告 ==="
    echo "监控时间: $(date)"
    echo ""
    
    # 1. 查询量异常检测
    echo "1. DNS查询量分析:"
    current_queries=$(tail -1000 $DNS_LOG_FILE | wc -l)
    avg_queries=$(tail -10000 $DNS_LOG_FILE | head -5000 | wc -l)
    avg_queries=$((avg_queries / 5))
    
    echo "当前查询速率: $current_queries queries/10min"
    echo "平均查询速率: $avg_queries queries/10min"
    
    if [ $current_queries -gt $((avg_queries * 3)) ]; then
        echo "⚠️  WARNING: DNS查询量异常激增"
        # 发送告警
    fi
    
    # 2. 异常域名查询检测
    echo -e "\n2. 异常域名查询检测:"
    suspicious_domains=$(tail -1000 $DNS_LOG_FILE | \
        grep -E "(\.tk|\.ml|\.ga|\.cf)" | \
        awk '{print $NF}' | sort | uniq -c | sort -nr | head -10)
    
    if [ ! -z "$suspicious_domains" ]; then
        echo "可疑域名查询:"
        echo "$suspicious_domains"
    fi
    
    # 3. DNS隧道检测
    echo -e "\n3. DNS隧道行为检测:"
    tunnel_indicators=$(tail -1000 $DNS_LOG_FILE | \
        awk '{print $NF}' | \
        grep -E "(\.jpg$|\.png$|\.exe$|\.dll$)" | \
        wc -l)
    
    if [ $tunnel_indicators -gt 10 ]; then
        echo "⚠️  WARNING: 发现潜在DNS隧道行为: $tunnel_indicators 次"
    fi
    
    # 4. DGA域名检测
    echo -e "\n4. 疑似DGA域名检测:"
    dga_suspicious=$(tail -1000 $DNS_LOG_FILE | \
        awk '{print $NF}' | \
        grep -E "^[a-z0-9]{16,}\.[a-z]{2,}$" | \
        wc -l)
    
    if [ $dga_suspicious -gt 5 ]; then
        echo "⚠️  WARNING: 发现疑似DGA域名查询: $dga_suspicious 次"
    fi
    
    # 5. 查询类型异常
    echo -e "\n5. DNS查询类型分析:"
    tail -1000 $DNS_LOG_FILE | \
        grep -o "query: [A-Z]*" | \
        sort | uniq -c | sort -nr
    
    # 6. 源IP异常分析
    echo -e "\n6. 查询源IP分布:"
    tail -1000 $DNS_LOG_FILE | \
        grep -o "client [0-9.]*#" | \
        cut -d' ' -f2 | cut -d'#' -f1 | \
        sort | uniq -c | sort -nr | head -10
}

# DNSSEC验证失败检测
monitor_dnssec_failures() {
    echo -e "\n=== DNSSEC验证监控 ==="
    
    # 检查验证失败日志
    validation_failures=$(journalctl -u named -n 1000 | \
        grep -c "validation failure")
    
    if [ $validation_failures -gt 0 ]; then
        echo "⚠️  WARNING: DNSSEC验证失败: $validation_failures 次"
        journalctl -u named -n 100 | grep "validation failure"
    fi
}

# 持续监控循环
while true; do
    {
        detect_dns_anomalies
        monitor_dnssec_failures
        echo -e "\n=== 监控完成 ===\n"
    } > /var/log/dns_security_report_$(date +%Y%m%d_%H%M%S).log
    
    sleep $MONITOR_INTERVAL
done
```

## 大规模DNS集群优化

### DNS集群架构设计

#### 高可用DNS集群部署

```yaml
# Kubernetes DNS集群高可用部署
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coredns-ha
  namespace: kube-system
spec:
  replicas: 5
  selector:
    matchLabels:
      k8s-app: kube-dns-ha
  template:
    metadata:
      labels:
        k8s-app: kube-dns-ha
    spec:
      # 节点亲和性确保跨节点部署
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: k8s-app
                  operator: In
                  values: ["kube-dns-ha"]
              topologyKey: kubernetes.io/hostname
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: k8s-app
                operator: In
                values: ["kube-dns-ha"]
            topologyKey: topology.kubernetes.io/zone
      
      # 资源限制和请求
      containers:
      - name: coredns
        image: coredns/coredns:1.9.3
        args: [ "-conf", "/etc/coredns/Corefile" ]
        volumeMounts:
        - name: config-volume
          mountPath: /etc/coredns
          readOnly: true
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        - containerPort: 9153
          name: metrics
          protocol: TCP
        
        # 健康检查
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          periodSeconds: 10
          failureThreshold: 5
        
        readinessProbe:
          httpGet:
            path: /ready
            port: 8181
            scheme: HTTP
          initialDelaySeconds: 30
          timeoutSeconds: 3
          periodSeconds: 5
          failureThreshold: 3
        
        # 资源配置
        resources:
          limits:
            memory: 1Gi
            cpu: 1000m
          requests:
            cpu: 100m
            memory: 128Mi
      
      volumes:
      - name: config-volume
        configMap:
          name: coredns-ha-config
---
# Service配置
apiVersion: v1
kind: Service
metadata:
  name: kube-dns-ha
  namespace: kube-system
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9153"
spec:
  selector:
    k8s-app: kube-dns-ha
  clusterIP: None  # Headless Service
  ports:
  - name: dns
    port: 53
    protocol: UDP
    targetPort: 53
  - name: dns-tcp
    port: 53
    protocol: TCP
    targetPort: 53
  - name: metrics
    port: 9153
    protocol: TCP
    targetPort: 9153
```

#### DNS负载均衡与故障切换

```bash
# DNS集群负载均衡配置
configure_dns_load_balancing() {
    # 使用外部负载均衡器
    cat > /etc/haproxy/haproxy.cfg << EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode udp
    option udplog
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend dns_frontend
    bind *:53
    mode udp
    default_backend dns_backend

backend dns_backend
    mode udp
    balance leastconn
    option httpchk GET /health
    server dns1 10.0.0.10:53 check port 8080 inter 2000 rise 2 fall 3
    server dns2 10.0.0.11:53 check port 8080 inter 2000 rise 2 fall 3
    server dns3 10.0.0.12:53 check port 8080 inter 2000 rise 2 fall 3
EOF

    # 启动HAProxy
    systemctl restart haproxy
    
    # 配置Keepalived实现高可用
    cat > /etc/keepalived/keepalived.conf << EOF
vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.0.0.100/24 dev eth0
    }
}
EOF
    
    systemctl restart keepalived
}

# DNS集群健康检查
dns_cluster_health_check() {
    local dns_servers=("10.0.0.10" "10.0.0.11" "10.0.0.12")
    local test_domain="google.com"
    
    echo "=== DNS集群健康检查 ==="
    
    for server in "${dns_servers[@]}"; do
        echo "检查服务器: $server"
        
        # 基本连通性测试
        if ! nc -zu $server 53 2>/dev/null; then
            echo "❌ 服务器 $server 端口53不可达"
            continue
        fi
        
        # DNS解析测试
        resolution_result=$(dig @$server $test_domain A +short)
        if [ -z "$resolution_result" ]; then
            echo "❌ 服务器 $server DNS解析失败"
        else
            echo "✅ 服务器 $server 正常工作"
            echo "   解析结果: $resolution_result"
        fi
        
        # 响应时间测试
        response_time=$(dig @$server $test_domain | grep "Query time" | awk '{print $4}')
        echo "   响应时间: ${response_time}ms"
        
        echo ""
    done
}
```

### DNS性能优化与调优

#### CoreDNS高级性能调优

```yaml
# CoreDNS生产环境高性能配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-performance-config
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        # 高性能转发配置
        forward . 8.8.8.8 8.8.4.4 {
            max_concurrent 1000
            health_check 5s
            expire 30s
            policy sequential
        }
        
        # 高效缓存配置
        cache 300 {
            success 5000
            denial 2500
            prefetch 10 1m 10%
        }
        
        # 负载均衡
        loadbalance round_robin
        
        # 高性能选项
        bufsize 1232
        template IN A example.com {
            match .*\.example\.com
            answer "{{ .Name }} 60 IN A 10.0.0.1"
            fallthrough
        }
        
        # 监控和日志
        prometheus :9153
        log . {
            class error
        }
        errors
    }

    # 本地域名优化
    cluster.local:53 {
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
            ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
            max_concurrent 100
            health_check 10s
        }
        cache 30 {
            success 1000
            denial 100
        }
        reload
    }
```

#### DNS查询优化策略

```bash
# DNS查询性能优化脚本
optimize_dns_queries() {
    # 1. 并行DNS查询优化
    echo "优化/etc/resolv.conf并行查询:"
    cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
options timeout:1 attempts:2 rotate ndots:1
EOF

    # 2. 应用层DNS优化
    cat >> /etc/environment << EOF
# Java DNS优化
JAVA_OPTS="-Dsun.net.inetaddr.ttl=30 -Dsun.net.inetaddr.negative.ttl=10"

# Python DNS优化
PYTHONPATH="/opt/dns-cache:$PYTHONPATH"
EOF

    # 3. 本地DNS缓存优化
    install_dnsmasq_local_cache() {
        # 安装dnsmasq
        apt-get install -y dnsmasq
        
        # 配置本地缓存
        cat > /etc/dnsmasq.conf << EOF
port=53
listen-address=127.0.0.1
cache-size=10000
min-cache-ttl=300
max-cache-ttl=3600
local-ttl=300
neg-ttl=60
EOF
        
        # 更新resolv.conf使用本地缓存
        echo "nameserver 127.0.0.1" > /etc/resolv.conf
        
        systemctl restart dnsmasq
    }
    
    # 4. DNS预取优化
    setup_dns_prefetch() {
        cat > /usr/local/bin/dns-prefetch.sh << 'EOF'
#!/bin/bash
# DNS预取脚本

DOMAIN_LIST="/etc/dns-prefetch/domains.txt"
PREFETCH_INTERVAL=300  # 5分钟

while true; do
    if [ -f "$DOMAIN_LIST" ]; then
        while read domain; do
            # 并行预取多个域名
            dig +short @$UPSTREAM_DNS $domain A &
            dig +short @$UPSTREAM_DNS $domain AAAA &
        done < $DOMAIN_LIST
        wait  # 等待所有后台任务完成
    fi
    
    sleep $PREFETCH_INTERVAL
done
EOF
        
        chmod +x /usr/local/bin/dns-prefetch.sh
        
        # 创建预取域名列表
        mkdir -p /etc/dns-prefetch
        cat > /etc/dns-prefetch/domains.txt << EOF
google.com
github.com
docker.io
kubernetes.io
EOF
    }
}

# DNS性能基准测试
benchmark_dns_performance() {
    local test_domains=(
        "google.com"
        "github.com"
        "stackoverflow.com"
        "reddit.com"
        "youtube.com"
    )
    
    echo "=== DNS性能基准测试 ==="
    echo "测试时间: $(date)"
    echo ""
    
    for domain in "${test_domains[@]}"; do
        echo "测试域名: $domain"
        
        # 测试多次取平均值
        total_time=0
        for i in {1..5}; do
            query_time=$(dig @$1 $domain | grep "Query time" | awk '{print $4}')
            total_time=$((total_time + query_time))
        done
        
        avg_time=$((total_time / 5))
        echo "平均响应时间: ${avg_time}ms"
        echo ""
    done
}

# 使用示例
# benchmark_dns_performance "8.8.8.8"
```
-Dnetworkaddress.cache.ttl=60
-Dnetworkaddress.cache.negative.ttl=10

# glibc DNS 缓存配置
# /etc/nsswitch.conf
hosts: files dns [!UNAVAIL=return] myhostname

# /etc/resolv.conf 优化
options timeout:1 attempts:2 rotate
```

#### CoreDNS 生产环境配置

```yaml
# CoreDNS 生产级配置
.:53 {
    # 上游 DNS 服务器
    forward . 8.8.8.8 8.8.4.4 {
        max_fails 3
        expire 90s
        health_check 5s
        policy sequential
    }
    
    # 缓存配置
    cache 300 {  # 5分钟缓存
        success 10000
        denial 5000
        prefetch 10 1m 10%
    }
    
    # 负载均衡
    loadbalance round_robin
    
    # 日志和监控
    log
    errors
    
    # 健康检查
    health {
        lameduck 5s
    }
    
    # 指标导出
    prometheus :9153
    
    # 递归限制
    loop
}

# 本地域名解析
example.com:53 {
    file /etc/coredns/db.example.com
    log
    errors
}
```

### DNS 安全最佳实践

#### DNSSEC 配置

```bash
# 启用 DNSSEC 验证
# /etc/systemd/resolved.conf
[Resolve]
DNSSEC=yes
DNSOverTLS=yes

# 验证 DNSSEC 状态
dig +dnssec +multiline cloudflare.com

# 检查 DNSSEC 信任链
delv @1.1.1.1 cloudflare.com
```

#### 防止 DNS 放大攻击

```bash
# iptables 防护规则
iptables -A INPUT -p udp --dport 53 -m u32 --u32 "0>>22&0x3C@8&0xFFFF=0x1401" -j DROP
iptables -A INPUT -p udp --dport 53 -m u32 --u32 "0>>22&0x3C@8&0xFFFF=0x1801" -j DROP

# 限制查询速率
iptables -A INPUT -p udp --dport 53 -m hashlimit \
  --hashlimit-above 10/sec --hashlimit-mode srcip --hashlimit-name dns \
  -j DROP

# 限制响应大小
echo 'max-cache-ttl: 300' >> /etc/unbound/unbound.conf
echo 'max-udp-size: 1232' >> /etc/unbound/unbound.conf
```

#### 私有 DNS 安全配置

```yaml
# CoreDNS 安全配置
.:53 {
    # 仅允许内网查询
    acl {
        allow net 10.0.0.0/8
        allow net 172.16.0.0/12
        allow net 192.168.0.0/16
        block
    }
    
    # 查询日志
    log . "{remote}:{port} - {>id} \"{type} {class} {name} {proto} {size} {>do} {>bufsize}\" {rcode} {>rflags} {rsize} {duration}"
    
    # 转发到可信上游
    forward . tls://1.1.1.1 tls://1.0.0.1 {
        tls_servername cloudflare-dns.com
        health_check 5s
    }
    
    # 缓存和安全
    cache 300
    bufsize 1232
    edns0
}
```

### 大规模 DNS 部署最佳实践

#### 高可用架构设计

```
┌─────────────────────────────────────────────────────────────────┐
│                        DNS 高可用架构                             │
├─────────────────────────────────────────────────────────────────┤
│  全局负载均衡                                                   │
│  - GeoDNS (地理位置)                                           │
│  - Anycast (任播)                                              │
├─────────────────────────────────────────────────────────────────┤
│  区域 DNS 服务器                                                │
│  - 主服务器 (Primary)                                          │
│  - 从服务器 (Secondary)                                        │
│  - 隐藏主服务器 (Hidden Master)                                │
├─────────────────────────────────────────────────────────────────┤
│  本地缓存层                                                     │
│  - Edge Cache (边缘缓存)                                       │
│  - Local Resolvers (本地解析器)                                │
└─────────────────────────────────────────────────────────────────┘
```

#### DNS 集群部署配置

```yaml
# Kubernetes DNS 集群配置
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coredns
  namespace: kube-system
spec:
  replicas: 3
  selector:
    matchLabels:
      k8s-app: kube-dns
  template:
    metadata:
      labels:
        k8s-app: kube-dns
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: k8s-app
                  operator: In
                  values: ["kube-dns"]
              topologyKey: kubernetes.io/hostname
      
      containers:
      - name: coredns
        image: coredns/coredns:1.9.3
        args: [ "-conf", "/etc/coredns/Corefile" ]
        volumeMounts:
        - name: config-volume
          mountPath: /etc/coredns
          readOnly: true
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        - containerPort: 9153
          name: metrics
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /ready
            port: 8181
            scheme: HTTP
        resources:
          limits:
            memory: 170Mi
            cpu: 100m
          requests:
            cpu: 100m
            memory: 70Mi

---
# Service 配置
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  annotations:
    prometheus.io/port: "9153"
    prometheus.io/scrape: "true"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: 10.96.0.10
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP
  - name: metrics
    port: 9153
    protocol: TCP
```

#### DNS 性能监控告警

```bash
# DNS 性能监控脚本
#!/bin/bash

MONITOR_DNS_SERVER="8.8.8.8"
THRESHOLD_LATENCY=50  # ms
THRESHOLD_FAILURE=3   # 连续失败次数

failure_count=0

while true; do
    # 测试 DNS 解析延迟
    latency=$(dig @$MONITOR_DNS_SERVER google.com | grep "Query time" | awk '{print $4}')
    
    # 检查解析是否成功
    if [ -z "$latency" ] || [ "$latency" == "0" ]; then
        failure_count=$((failure_count + 1))
        echo "$(date): DNS 查询失败，连续失败次数: $failure_count"
        
        if [ $failure_count -ge $THRESHOLD_FAILURE ]; then
            echo "$(date): DNS 服务严重故障!"
            # 发送紧急告警
            failure_count=0
        fi
    else
        failure_count=0
        
        # 检查延迟是否超标
        if [ $latency -gt $THRESHOLD_LATENCY ]; then
            echo "$(date): DNS 延迟过高: ${latency}ms"
            # 发送警告
        fi
    fi
    
    sleep 30
done
```

#### DNS 故障切换策略

```bash
# DNS 故障自动切换脚本
#!/bin/bash

PRIMARY_DNS="8.8.8.8"
SECONDARY_DNS="1.1.1.1"
RESOLV_CONF="/etc/resolv.conf"

check_dns_health() {
    local dns_server=$1
    local test_domain="google.com"
    
    # 测试 DNS 可达性
    if dig @$dns_server $test_domain >/dev/null 2>&1; then
        return 0  # 健康
    else
        return 1  # 故障
    fi
}

switch_dns() {
    local new_primary=$1
    local new_secondary=$2
    
    echo "nameserver $new_primary" > $RESOLV_CONF
    echo "nameserver $new_secondary" >> $RESOLV_CONF
    echo "options timeout:2 attempts:3 rotate" >> $RESOLV_CONF
    
    echo "$(date): DNS 已切换到 $new_primary, $new_secondary"
    # 记录日志或发送通知
}

# 主监控循环
while true; do
    if ! check_dns_health $PRIMARY_DNS; then
        echo "$(date): 主 DNS $PRIMARY_DNS 故障，切换到备用"
        switch_dns $SECONDARY_DNS $PRIMARY_DNS
        break
    fi
    
    sleep 60
done
```

---

## 相关文档

- [01-network-protocols-stack](./01-network-protocols-stack.md) - 网络协议栈
- [203-docker-networking-deep-dive](./203-docker-networking-deep-dive.md) - Docker 网络
- [60-coredns-configuration](./60-coredns-configuration.md) - CoreDNS 配置
