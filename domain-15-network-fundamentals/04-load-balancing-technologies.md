# 负载均衡技术

> **适用版本**: 通用 | **最后更新**: 2026-01

---

## 目录

- [负载均衡概述](#负载均衡概述)
- [负载均衡算法](#负载均衡算法)
- [四层负载均衡](#四层负载均衡)
- [七层负载均衡](#七层负载均衡)
- [健康检查](#健康检查)
- [会话保持](#会话保持)

---

## 负载均衡概述

### 负载均衡类型

| 类型 | OSI 层 | 特点 | 代表产品 |
|:---|:---:|:---|:---|
| **DNS 负载均衡** | 应用层 | 简单、全局 | Route 53, CloudFlare |
| **四层负载均衡** | 传输层 | 高性能、低延迟 | LVS, HAProxy, NLB |
| **七层负载均衡** | 应用层 | 灵活路由、内容感知 | Nginx, HAProxy, ALB |

### 部署架构

```
                        互联网
                           │
                    ┌──────┴──────┐
                    │ DNS 负载均衡 │
                    └──────┬──────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
      ┌─────────┐    ┌─────────┐    ┌─────────┐
      │ 区域 A   │    │ 区域 B   │    │ 区域 C   │
      │ L4 LB   │    │ L4 LB   │    │ L4 LB   │
      └────┬────┘    └────┬────┘    └────┬────┘
           │              │              │
      ┌────┴────┐    ┌────┴────┐    ┌────┴────┐
      │ L7 LB   │    │ L7 LB   │    │ L7 LB   │
      └────┬────┘    └────┬────┘    └────┬────┘
           │              │              │
      ┌────┴────┐    ┌────┴────┐    ┌────┴────┐
      │后端服务  │    │后端服务  │    │后端服务  │
      └─────────┘    └─────────┘    └─────────┘
```

---

## 负载均衡算法

### 常用算法

| 算法 | 说明 | 适用场景 |
|:---|:---|:---|
| **轮询 (RR)** | 依次分配 | 服务器性能相同 |
| **加权轮询 (WRR)** | 按权重分配 | 服务器性能不同 |
| **最少连接 (LC)** | 选择连接最少 | 长连接场景 |
| **加权最少连接 (WLC)** | 结合权重和连接数 | 通用场景 |
| **IP 哈希** | 按客户端 IP 哈希 | 需要会话保持 |
| **一致性哈希** | 减少重新映射 | 缓存场景 |
| **最快响应** | 选择响应最快 | 动态负载 |

### 算法选择

| 场景 | 推荐算法 |
|:---|:---|
| 无状态服务 | 轮询/加权轮询 |
| 有状态服务 | IP 哈希/一致性哈希 |
| 长连接服务 | 最少连接 |
| 缓存服务 | 一致性哈希 |
| 异构服务器 | 加权算法 |

---

## 四层负载均衡

### LVS (Linux Virtual Server)

| 模式 | 说明 | 特点 |
|:---|:---|:---|
| **NAT** | 地址转换 | 简单、有瓶颈 |
| **DR** | 直接路由 | 高性能、同网段 |
| **TUN** | IP 隧道 | 跨网段、复杂 |

#### LVS-DR 配置

```bash
# Director 配置
ipvsadm -A -t 10.0.0.100:80 -s rr
ipvsadm -a -t 10.0.0.100:80 -r 10.0.0.10:80 -g
ipvsadm -a -t 10.0.0.100:80 -r 10.0.0.11:80 -g

# Real Server 配置
ip addr add 10.0.0.100/32 dev lo
echo 1 > /proc/sys/net/ipv4/conf/all/arp_ignore
echo 2 > /proc/sys/net/ipv4/conf/all/arp_announce
```

### IPVS (Kubernetes)

```bash
# 启用 IPVS 模式
# kube-proxy 配置
mode: ipvs
ipvs:
  scheduler: rr

# 查看规则
ipvsadm -Ln
```

---

## 七层负载均衡

### Nginx 配置

```nginx
upstream backend {
    # 算法
    least_conn;
    # ip_hash;
    
    # 服务器列表
    server 10.0.0.10:8080 weight=5;
    server 10.0.0.11:8080 weight=3;
    server 10.0.0.12:8080 backup;
    
    # 健康检查 (商业版)
    # health_check interval=10s fails=3 passes=2;
    
    # 连接保持
    keepalive 32;
}

server {
    listen 80;
    
    location / {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### HAProxy 配置

```
global
    maxconn 50000
    log stdout format raw local0

defaults
    mode http
    timeout connect 5s
    timeout client 50s
    timeout server 50s

frontend http_front
    bind *:80
    default_backend http_back

backend http_back
    balance roundrobin
    option httpchk GET /health
    server web1 10.0.0.10:8080 check weight 5
    server web2 10.0.0.11:8080 check weight 3
    server web3 10.0.0.12:8080 check backup
```

---

## 健康检查

### 检查类型

| 类型 | 层次 | 检查内容 |
|:---|:---|:---|
| **TCP** | L4 | 端口连通 |
| **HTTP** | L7 | 状态码/内容 |
| **HTTPS** | L7 | 证书+状态码 |
| **自定义** | L7 | 脚本/命令 |

### 配置参数

| 参数 | 说明 | 推荐值 |
|:---|:---|:---|
| interval | 检查间隔 | 5-30s |
| timeout | 超时时间 | 3-5s |
| unhealthy | 失败阈值 | 2-3 |
| healthy | 成功阈值 | 2-3 |

### Nginx 健康检查

```nginx
upstream backend {
    server 10.0.0.10:8080 max_fails=3 fail_timeout=30s;
    server 10.0.0.11:8080 max_fails=3 fail_timeout=30s;
}
```

---

## 会话保持

### 实现方式

| 方式 | 说明 | 优缺点 |
|:---|:---|:---|
| **源 IP** | 按客户端 IP | 简单、NAT 问题 |
| **Cookie** | 插入 Cookie | 灵活、需要 L7 |
| **URL 参数** | URL 中标识 | 对应用透明 |
| **Session 共享** | 外部存储 | 无状态后端 |

### Nginx Cookie 会话

```nginx
upstream backend {
    server 10.0.0.10:8080;
    server 10.0.0.11:8080;
    
    sticky cookie srv_id expires=1h domain=.example.com path=/;
}
```

### 无状态设计 (推荐)

```
┌─────────┐     ┌─────────┐     ┌─────────┐
│ 后端 1   │     │ 后端 2   │     │ 后端 3   │
└────┬────┘     └────┬────┘     └────┬────┘
     │               │               │
     └───────────────┼───────────────┘
                     │
              ┌──────┴──────┐
              │ Redis/MySQL │
              │  Session    │
              └─────────────┘
```

## 负载均衡器选型与性能基准

### 负载均衡器选型指南

#### 选型决策矩阵

| 需求场景 | 推荐方案 | 理由 | 典型配置 |
|:---|:---|:---|:---|
| **高并发Web** | Nginx + LVS | 成熟稳定、性能优异 | 4核8GB + 10Gbps |
| **微服务架构** | Envoy/Istio | 服务网格、可观测性强 | 2核4GB + 1Gbps |
| **UDP流媒体** | HAProxy + DPDK | 低延迟、高吞吐 | 8核16GB + 25Gbps |
| **全球部署** | Cloud Load Balancer | 地理分布、自动扩缩 | 按需付费 |
| **金融交易** | F5 BIG-IP | 企业级、安全合规 | 专用硬件 |

#### 性能基准测试

```bash
# L4 负载均衡器性能测试 (iperf3)
# 服务端
iperf3 -s -p 5201

# 客户端多连接测试
for i in {1..100}; do
    iperf3 -c lb-server -p 5201 -t 60 -P 10 -i 1 &
done
wait

# L7 负载均衡器 HTTP 性能测试 (wrk)
# 安装 wrk
git clone https://github.com/wg/wrk.git && cd wrk && make

# 基准测试
wrk -t12 -c400 -d30s --timeout 10s http://lb-domain/

# 详细测试报告
wrk -t12 -c400 -d60s --timeout 30s \
    -H "Connection: close" \
    --latency \
    http://lb-domain/api/health
```

#### 负载均衡器性能对比

| 负载均衡器 | L4性能 (req/s) | L7性能 (req/s) | 内存占用 | 特色功能 |
|:---|:---:|:---:|:---:|:---|
| **Nginx** | 200K+ | 80K+ | 50MB | 成熟、模块丰富 |
| **HAProxy** | 300K+ | 120K+ | 30MB | 高性能、会话保持 |
| **Envoy** | 150K+ | 60K+ | 80MB | 服务网格、xDS |
| **Traefik** | 80K+ | 40K+ | 40MB | Let's Encrypt、Docker |
| **F5 BIG-IP** | 500K+ | 200K+ | 2GB+ | 企业级、硬件加速 |

### 高可用负载均衡架构

#### 双活架构设计

```
┌─────────────────────────────────────────────────────────────────┐
│                        双活负载均衡架构                           │
├─────────────────────────────────────────────────────────────────┤
│  全局负载均衡层 (Global Load Balancer)                          │
│  ├─ DNS 负载均衡 (GeoDNS)                                      │
│  ├─ CDN 负载均衡 (Cloudflare/AWS CloudFront)                   │
│  └─ BGP Anycast                                                │
├─────────────────────────────────────────────────────────────────┤
│  区域负载均衡层 (Regional Load Balancer)                        │
│  ├─ L4 负载均衡 (LVS/HAProxy)                                  │
│  ├─ L7 负载均衡 (Nginx/Envoy)                                  │
│  └─ 健康检查集群                                               │
├─────────────────────────────────────────────────────────────────┤
│  应用服务层                                                     │
│  ├─ 应用服务器集群                                             │
│  ├─ 数据库读写分离                                             │
│  └─ 缓存集群 (Redis/Memcached)                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Keepalived + LVS 高可用配置

```bash
# Keepalived 配置 (MASTER)
# /etc/keepalived/keepalived.conf
global_defs {
    router_id LVS_MASTER
    vrrp_skip_check_adv_addr
    vrrp_garp_interval 0
    vrrp_gna_interval 0
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 110
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    
    virtual_ipaddress {
        10.0.0.100/24 dev eth0
    }
    
    # 健康检查脚本
    track_script {
        chk_haproxy
    }
}

virtual_server 10.0.0.100 80 {
    delay_loop 6
    lb_algo rr
    lb_kind DR
    persistence_timeout 50
    protocol TCP
    
    real_server 10.0.0.10 8080 {
        weight 1
        TCP_CHECK {
            connect_timeout 3
            retry 3
            delay_before_retry 3
        }
    }
    
    real_server 10.0.0.11 8080 {
        weight 1
        TCP_CHECK {
            connect_timeout 3
            retry 3
            delay_before_retry 3
        }
    }
}

# 健康检查脚本
# /etc/keepalived/check_haproxy.sh
#!/bin/bash
if pgrep haproxy >/dev/null; then
    exit 0
else
    exit 1
fi
```

#### 负载均衡器监控告警

```bash
# 负载均衡器健康监控脚本
#!/bin/bash

LB_HOST="10.0.0.100"
LB_PORT="80"
THRESHOLD_RESPONSE_TIME=1000  # ms
THRESHOLD_ERROR_RATE=5        # %

# 监控函数
monitor_load_balancer() {
    local timestamp=$(date '+%s')
    
    # HTTP 响应时间测试
    RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" \
        http://$LB_HOST:$LB_PORT/health 2>/dev/null)
    
    RESPONSE_TIME_MS=$(echo "$RESPONSE_TIME * 1000" | bc)
    
    # 错误率检查
    ERROR_COUNT=0
    TOTAL_REQUESTS=100
    
    for i in $(seq 1 $TOTAL_REQUESTS); do
        if ! curl -f -s http://$LB_HOST:$LB_PORT/health >/dev/null 2>&1; then
            ERROR_COUNT=$((ERROR_COUNT + 1))
        fi
    done
    
    ERROR_RATE=$((ERROR_COUNT * 100 / TOTAL_REQUESTS))
    
    # 告警判断
    if (( $(echo "$RESPONSE_TIME_MS > $THRESHOLD_RESPONSE_TIME" | bc -l) )) || \
       [ $ERROR_RATE -gt $THRESHOLD_ERROR_RATE ]; then
        
        echo "$(date): 负载均衡器异常 - 响应时间:${RESPONSE_TIME_MS}ms 错误率:${ERROR_RATE}%"
        # 发送告警通知...
        
        # 自动故障切换
        trigger_failover
    fi
}

trigger_failover() {
    echo "$(date): 触发故障切换机制"
    # 实际的故障切换逻辑...
    systemctl restart keepalived
}

# 持续监控
while true; do
    monitor_load_balancer
    sleep 30
done
```

### 负载均衡器性能调优

#### 内核参数优化

```bash
# /etc/sysctl.conf - 负载均衡器专用优化

# 网络连接优化
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65535

# TCP 性能优化
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3

# 内存优化
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# 连接跟踪优化
net.netfilter.nf_conntrack_max = 1048576
net.netfilter.nf_conntrack_buckets = 65536
net.netfilter.nf_conntrack_tcp_timeout_established = 600

# 应用配置
sysctl -p
```

#### Nginx 负载均衡器优化配置

```nginx
# Nginx 负载均衡器生产级配置
user nginx;
worker_processes auto;
worker_cpu_affinity auto;

error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

# 进程优化
worker_rlimit_nofile 65535;

events {
    worker_connections 65535;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # 日志格式优化
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    '$request_time $upstream_response_time';
    
    access_log /var/log/nginx/access.log main;
    
    # 性能优化
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 1000;
    client_body_timeout 12;
    client_header_timeout 12;
    send_timeout 10;
    
    # 缓冲区优化
    client_body_buffer_size 128k;
    client_max_body_size 10m;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 4k;
    output_buffers 1 32k;
    postpone_output 1460;
    
    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # 负载均衡配置
    upstream backend {
        # 算法选择
        least_conn;
        
        # 服务器列表
        server 10.0.0.10:8080 weight=5 max_fails=3 fail_timeout=30s;
        server 10.0.0.11:8080 weight=3 max_fails=3 fail_timeout=30s;
        server 10.0.0.12:8080 backup;
        
        # 连接池设置
        keepalive 32;
        keepalive_requests 1000;
        keepalive_timeout 60s;
        
        # 健康检查
        zone backend 64k;
    }
    
    server {
        listen 80 reuseport;
        server_name _;
        
        # 限流配置
        limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
        
        location / {
            proxy_pass http://backend;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # 超时设置
            proxy_connect_timeout 5s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
            
            # 缓冲区设置
            proxy_buffering on;
            proxy_buffer_size 4k;
            proxy_buffers 8 4k;
            
            # 限流应用
            limit_req zone=api burst=20 nodelay;
        }
        
        # 健康检查端点
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
```

#### HAProxy 负载均衡器优化配置

```haproxy
# HAProxy 生产级配置
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    
    # 性能调优
    nbproc 4
    cpu-map 1-4 0-3
    maxconn 100000
    tune.ssl.default-dh-param 2048
    tune.bufsize 16384
    tune.maxrewrite 1024

defaults
    log global
    mode http
    option httplog
    option dontlognull
    option http-server-close
    option forwardfor except 127.0.0.0/8
    retries 3
    timeout connect 5000
    timeout client 50000
    timeout server 50000
    timeout http-keep-alive 1000
    timeout check 5000
    maxconn 3000

# 统计页面
listen stats
    bind :1936
    stats enable
    stats uri /stats
    stats realm HAProxy\ Statistics
    stats auth admin:password
    stats admin if TRUE

frontend http_front
    bind *:80
    bind *:443 ssl crt /etc/haproxy/certs/ strict-sni alpn h2,http/1.1
    
    # ACL 规则
    acl is_api path_beg /api/
    acl is_static path_end .jpg .png .css .js
    
    # 限流配置
    stick-table type ip size 1m expire 5m store gpc0,http_req_rate(10s)
    tcp-request content track-sc0 src
    tcp-request content reject if { sc0_get_gpc0 gt 100 }
    
    default_backend app_servers

backend app_servers
    balance leastconn
    option httpchk GET /health
    http-check expect status 200
    
    # 服务器配置
    server app1 10.0.0.10:8080 check weight 5 inter 2000 rise 2 fall 3
    server app2 10.0.0.11:8080 check weight 3 inter 2000 rise 2 fall 3
    server app3 10.0.0.12:8080 check backup inter 2000 rise 2 fall 3
    
    # 连接池优化
    option http-keep-alive
    http-reuse safe
    fullconn 10000
    
    # 响应头设置
    rspadd X-Via:\ HAPROXY
```

---

## 相关文档

- [01-network-protocols-stack](./01-network-protocols-stack.md) - 网络协议栈
- [02-tcp-udp-deep-dive](./02-tcp-udp-deep-dive.md) - TCP/UDP 详解
- [40-service-types-comparison](./40-service-types-comparison.md) - K8s Service 类型
