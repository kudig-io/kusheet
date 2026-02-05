# Docker 网络深度解析

> **适用版本**: Docker 20.10+ / Docker 24.0+ / Docker 25.0+ | **最后更新**: 2026-01
> 
> **生产环境运维专家注**: 包含网络隔离、服务发现、负载均衡、网络安全组、跨主机网络等企业级网络配置，重点解决多租户环境下的网络安全性问题。

---

## 目录

- [Docker 网络模型](#docker-网络模型)
- [网络驱动类型](#网络驱动类型)
- [容器网络命名空间](#容器网络命名空间)
- [Docker DNS 解析](#docker-dns-解析)
- [端口映射原理](#端口映射原理)
- [网络配置实践](#网络配置实践)
- [网络故障排查](#网络故障排查)

---

## Docker 网络模型

### 网络架构概览

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Docker Host                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                      │
│  │ Container 1 │    │ Container 2 │    │ Container 3 │                      │
│  │  (eth0)     │    │  (eth0)     │    │  (eth0)     │                      │
│  │  172.17.0.2 │    │  172.17.0.3 │    │  172.18.0.2 │                      │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘                      │
│         │                  │                  │                              │
│    ┌────┴────┐        ┌────┴────┐        ┌────┴────┐                        │
│    │  veth   │        │  veth   │        │  veth   │                        │
│    └────┬────┘        └────┬────┘        └────┬────┘                        │
│         │                  │                  │                              │
│  ┌──────┴──────────────────┴──────┐    ┌─────┴──────┐                       │
│  │        docker0 (bridge)         │    │   br-xxx   │                       │
│  │          172.17.0.1             │    │ 172.18.0.1 │                       │
│  └──────────────┬──────────────────┘    └─────┬──────┘                       │
│                 │                             │                              │
│  ┌──────────────┴─────────────────────────────┴─────────┐                   │
│  │                    iptables NAT                       │                   │
│  └──────────────────────────┬────────────────────────────┘                   │
│                             │                                                │
├─────────────────────────────┼────────────────────────────────────────────────┤
│                          eth0 (Host NIC)                                     │
│                          192.168.1.100                                       │
└─────────────────────────────┴────────────────────────────────────────────────┘
                              │
                              ▼
                         外部网络
```

### 网络组件

| 组件 | 说明 | 功能 |
|:---|:---|:---|
| **docker0** | 默认网桥 | 容器间通信、NAT 出口 |
| **veth pair** | 虚拟网卡对 | 连接容器与网桥 |
| **iptables** | 防火墙/NAT | 端口映射、网络隔离 |
| **libnetwork** | Docker 网络库 | 网络驱动框架 |
| **CNM** | 容器网络模型 | 网络抽象层 |

---

## 网络驱动类型

### 驱动对比

| 驱动 | 类型 | 隔离性 | 性能 | 使用场景 |
|:---|:---|:---|:---|:---|
| **bridge** | 本地 | 中 | 中 | 默认模式、单机容器 |
| **host** | 本地 | 无 | 高 | 性能敏感、无隔离需求 |
| **none** | 本地 | 完全 | - | 自定义网络栈 |
| **overlay** | 分布式 | 高 | 中 | Swarm/多主机 |
| **macvlan** | 本地 | 高 | 高 | 需要直接二层访问 |
| **ipvlan** | 本地 | 高 | 高 | 共享 MAC 地址 |

### Bridge 网络

```bash
# 创建自定义网桥
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --ip-range 172.20.240.0/20 \
  --gateway 172.20.0.1 \
  --opt com.docker.network.bridge.name=br-mynet \
  --opt com.docker.network.bridge.enable_icc=true \
  --opt com.docker.network.bridge.enable_ip_masquerade=true \
  --opt com.docker.network.driver.mtu=1500 \
  mynetwork

# 使用自定义网络
docker run -d --network mynetwork --name web nginx

# 连接已存在容器到网络
docker network connect mynetwork existing_container

# 指定 IP
docker run -d --network mynetwork --ip 172.20.0.100 nginx
```

#### Bridge 网络选项

| 选项 | 默认值 | 说明 |
|:---|:---|:---|
| `com.docker.network.bridge.name` | 自动生成 | Linux 网桥名称 |
| `com.docker.network.bridge.enable_ip_masquerade` | true | 启用 NAT |
| `com.docker.network.bridge.enable_icc` | true | 容器间通信 |
| `com.docker.network.bridge.host_binding_ipv4` | 0.0.0.0 | 端口绑定地址 |
| `com.docker.network.driver.mtu` | 1500 | MTU 大小 |

### Host 网络

```bash
# 使用 host 网络
docker run -d --network host nginx

# 容器直接使用主机网络栈
# - 无网络隔离
# - 端口直接绑定主机
# - 无需端口映射
```

**适用场景**:
- 高性能网络需求
- 监控/网络工具
- 不需要网络隔离

**限制**:
- 端口冲突风险
- 安全性降低
- Linux only (Mac/Windows 不支持)

### None 网络

```bash
# 禁用网络
docker run -d --network none myapp

# 容器只有 loopback 接口
# 需要自行配置网络
```

### Overlay 网络

```bash
# 创建 overlay 网络 (需要 Swarm 模式)
docker network create \
  --driver overlay \
  --subnet 10.0.9.0/24 \
  --attachable \
  --opt encrypted \
  my-overlay

# 特点:
# - 跨主机容器通信
# - VXLAN 封装
# - 自动服务发现
# - 支持加密
```

### Macvlan 网络

```bash
# 创建 macvlan 网络
docker network create \
  --driver macvlan \
  --subnet 192.168.1.0/24 \
  --gateway 192.168.1.1 \
  -o parent=eth0 \
  macvlan-net

# 802.1q trunk 模式
docker network create \
  --driver macvlan \
  --subnet 192.168.10.0/24 \
  --gateway 192.168.10.1 \
  -o parent=eth0.10 \
  macvlan-vlan10
```

**特点**:
- 容器拥有独立 MAC 地址
- 直接连接物理网络
- 可被外部直接访问
- 无需 NAT

### IPvlan 网络

```bash
# L2 模式
docker network create \
  --driver ipvlan \
  --subnet 192.168.1.0/24 \
  --gateway 192.168.1.1 \
  -o parent=eth0 \
  -o ipvlan_mode=l2 \
  ipvlan-l2

# L3 模式
docker network create \
  --driver ipvlan \
  --subnet 192.168.1.0/24 \
  -o parent=eth0 \
  -o ipvlan_mode=l3 \
  ipvlan-l3
```

**与 Macvlan 区别**:
- IPvlan: 所有容器共享父接口 MAC
- Macvlan: 每个容器独立 MAC

---

## 容器网络命名空间

### Linux 网络命名空间

```bash
# 查看命名空间
ls /var/run/docker/netns/

# 进入容器网络命名空间
docker inspect -f '{{.NetworkSettings.SandboxKey}}' container_name
nsenter --net=/var/run/docker/netns/xxx ip addr

# 使用 docker exec
docker exec container_name ip addr
docker exec container_name cat /etc/resolv.conf
docker exec container_name cat /etc/hosts
```

### 网络命名空间隔离

```
┌─────────────────────────────────────────────────────────────────┐
│                        主机网络命名空间                          │
│                                                                  │
│    eth0 ──┬── docker0 ──┬── veth1 ──┬── veth1-peer             │
│           │             │           │                            │
│           │             │           └────────────────────────────┤
│           │             │                                        │
│           │             └── veth2 ──┬── veth2-peer               │
│           │                         │                            │
│           │                         └────────────────────────────┤
└───────────┼──────────────────────────────────────────────────────┤
            │                                                       │
            │  ┌────────────────┐      ┌────────────────┐          │
            │  │ 容器1命名空间    │      │ 容器2命名空间    │          │
            │  │                │      │                │          │
            │  │  eth0 ◄───────┤      │  eth0 ◄───────┤          │
            │  │  172.17.0.2   │      │  172.17.0.3   │          │
            │  │  lo           │      │  lo           │          │
            │  └────────────────┘      └────────────────┘          │
            │                                                       │
```

### 共享网络命名空间

```bash
# Pod 模式: 容器共享网络
docker run -d --name pause --network bridge registry.k8s.io/pause:3.9
docker run -d --network container:pause nginx
docker run -d --network container:pause myapp

# 所有容器共享:
# - 相同 IP
# - 相同端口空间
# - 通过 localhost 通信
```

---

## Docker DNS 解析

### 内置 DNS 服务器

```
容器 DNS 解析流程:
┌─────────────┐     ┌─────────────────┐     ┌──────────────┐
│   容器      │────►│   Docker DNS    │────►│   上游 DNS   │
│  (resolver) │     │   (127.0.0.11)  │     │   (主机DNS)  │
└─────────────┘     └─────────────────┘     └──────────────┘
                            │
                            ▼
              ┌─────────────────────────────┐
              │   自定义网络容器名解析        │
              │   web → 172.18.0.5          │
              │   db → 172.18.0.6           │
              └─────────────────────────────┘
```

### DNS 配置

```bash
# 容器 resolv.conf
docker exec container_name cat /etc/resolv.conf
# nameserver 127.0.0.11
# options ndots:0

# 自定义 DNS
docker run -d \
  --dns 8.8.8.8 \
  --dns 8.8.4.4 \
  --dns-search example.com \
  --dns-opt timeout:2 \
  --dns-opt attempts:3 \
  nginx

# 全局 DNS 配置 (daemon.json)
{
  "dns": ["8.8.8.8", "8.8.4.4"],
  "dns-opts": ["timeout:2", "attempts:3"],
  "dns-search": ["example.com"]
}
```

### 服务发现

```bash
# 创建自定义网络
docker network create mynet

# 容器自动注册 DNS
docker run -d --network mynet --name webserver nginx
docker run -d --network mynet --name database mysql

# 通过容器名访问
docker exec webserver ping database
# database 解析为 172.18.0.x

# 网络别名
docker run -d --network mynet --network-alias db --name mysql mysql
# 可以通过 db 或 mysql 访问
```

### hosts 文件管理

```bash
# 添加 host 条目
docker run -d \
  --add-host "api.internal:192.168.1.10" \
  --add-host "db.internal:192.168.1.11" \
  myapp

# 查看 hosts
docker exec container_name cat /etc/hosts
```

---

## 端口映射原理

### iptables 实现

```bash
# 端口映射
docker run -d -p 8080:80 nginx

# 查看 iptables 规则
iptables -t nat -L -n -v

# DNAT 规则 (入站)
-A DOCKER -p tcp -m tcp --dport 8080 -j DNAT --to-destination 172.17.0.2:80

# MASQUERADE 规则 (出站)
-A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
```

### 端口映射类型

```bash
# 指定主机端口
docker run -d -p 8080:80 nginx

# 随机主机端口
docker run -d -P nginx

# 指定主机 IP
docker run -d -p 127.0.0.1:8080:80 nginx

# 所有接口
docker run -d -p 0.0.0.0:8080:80 nginx

# UDP 端口
docker run -d -p 514:514/udp syslog

# 端口范围
docker run -d -p 8080-8090:80-90 myapp

# 多端口映射
docker run -d -p 80:80 -p 443:443 nginx
```

### docker-proxy

```bash
# 默认使用用户态代理
ps aux | grep docker-proxy
# docker-proxy -proto tcp -host-ip 0.0.0.0 -host-port 8080 -container-ip 172.17.0.2 -container-port 80

# 禁用 docker-proxy (使用纯 iptables)
{
  "userland-proxy": false
}
```

### 查看端口映射

```bash
# 查看容器端口
docker port container_name

# 查看详细网络信息
docker inspect -f '{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{(index $conf 0).HostPort}}{{println}}{{end}}' container_name
```

---

## 网络配置实践

### 多层网络架构

```bash
# 创建前端网络
docker network create frontend

# 创建后端网络
docker network create backend

# Web 服务器 (仅前端)
docker run -d --name nginx --network frontend -p 80:80 nginx

# 应用服务器 (前端+后端)
docker run -d --name app --network frontend myapp
docker network connect backend app

# 数据库 (仅后端)
docker run -d --name mysql --network backend mysql

# 网络隔离:
# - nginx 可访问 app
# - app 可访问 nginx 和 mysql
# - nginx 不可访问 mysql
```

### 生产网络配置

```yaml
# docker-compose.yml
version: "3.9"

networks:
  frontend:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24
          gateway: 172.20.0.1
    driver_opts:
      com.docker.network.bridge.enable_icc: "true"
      com.docker.network.bridge.enable_ip_masquerade: "true"
      com.docker.network.driver.mtu: "1450"
      
  backend:
    driver: bridge
    internal: true  # 禁止外部访问
    ipam:
      config:
        - subnet: 172.21.0.0/24

services:
  nginx:
    image: nginx:alpine
    networks:
      - frontend
    ports:
      - "80:80"
      - "443:443"
      
  app:
    image: myapp:latest
    networks:
      frontend:
        ipv4_address: 172.20.0.10
        aliases:
          - api
          - backend
      backend:
        aliases:
          - app
    dns:
      - 8.8.8.8
    dns_search:
      - example.com
      
  mysql:
    image: mysql:8
    networks:
      backend:
        ipv4_address: 172.21.0.10
    environment:
      MYSQL_ROOT_PASSWORD: secret
```

### 网络安全配置

```bash
# 禁用容器间通信
docker network create --opt com.docker.network.bridge.enable_icc=false secure-net

# 内部网络 (无外部访问)
docker network create --internal internal-net

# 使用 iptables 规则隔离
iptables -I DOCKER-USER -s 172.17.0.2 -d 172.17.0.3 -j DROP
```

---

## 网络故障排查

### 诊断命令

```bash
# 网络列表
docker network ls

# 网络详情
docker network inspect bridge

# 容器网络配置
docker inspect -f '{{json .NetworkSettings.Networks}}' container_name | jq

# 容器 IP 地址
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' container_name
```

### 连通性测试

```bash
# 进入容器测试
docker exec -it container_name sh

# 安装网络工具 (alpine)
apk add --no-cache curl bind-tools iputils

# ping 测试
ping -c 3 other_container

# DNS 解析
nslookup other_container
dig other_container

# HTTP 测试
curl -v http://other_container:80

# 端口测试
nc -zv other_container 80
```

### 使用 netshoot 调试

```bash
# 启动调试容器
docker run --rm -it --network container:target_container nicolaka/netshoot

# 常用命令
ip addr                    # 查看 IP
ip route                   # 查看路由
ss -tlnp                   # 查看监听端口
tcpdump -i eth0             # 抓包
nmap -sT target_host       # 端口扫描
iptables -L -n -v          # 查看防火墙
traceroute target_host     # 路由追踪
```

### 常见问题

| 问题 | 症状 | 排查方法 | 解决方案 |
|:---|:---|:---|:---|
| **容器无法上网** | ping 外部失败 | 检查 NAT 规则 | 重启 Docker/检查 iptables |
| **容器间无法通信** | ping 内部失败 | 检查是否同网络 | 确保同一网络或连接网络 |
| **DNS 解析失败** | nslookup 失败 | 检查 /etc/resolv.conf | 配置正确的 DNS |
| **端口映射失败** | 外部无法访问 | docker port 查看映射 | 检查防火墙/端口冲突 |
| **网络性能差** | 延迟高 | 检查 MTU | 调整 MTU 配置 |

### 清理网络资源

```bash
# 删除未使用的网络
docker network prune

# 强制删除网络
docker network rm mynetwork

# 从网络断开所有容器
docker network disconnect -f mynetwork $(docker network inspect -f '{{range .Containers}}{{.Name}} {{end}}' mynetwork)
```

---

## 相关文档

- [200-docker-architecture-overview](./200-docker-architecture-overview.md) - Docker 架构
- [202-docker-container-lifecycle](./202-docker-container-lifecycle.md) - 容器生命周期
- [204-docker-storage-volumes](./204-docker-storage-volumes.md) - Docker 存储
- [220-network-protocols-stack](./220-network-protocols-stack.md) - 网络协议栈
- [213-linux-networking-configuration](./213-linux-networking-configuration.md) - Linux 网络配置
