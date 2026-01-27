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

---

## 相关文档

- [220-network-protocols-stack](./220-network-protocols-stack.md) - 网络协议栈
- [221-tcp-udp-deep-dive](./221-tcp-udp-deep-dive.md) - TCP/UDP 详解
- [40-service-types-comparison](./40-service-types-comparison.md) - K8s Service 类型
