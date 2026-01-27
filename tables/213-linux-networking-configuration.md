# Linux 网络配置与管理

> **适用版本**: Linux Kernel 5.x/6.x | **最后更新**: 2026-01

---

## 目录

- [网络配置基础](#网络配置基础)
- [网络命令工具](#网络命令工具)
- [路由与 NAT](#路由与-nat)
- [iptables 防火墙](#iptables-防火墙)
- [网络排查工具](#网络排查工具)
- [网络性能调优](#网络性能调优)

---

## 网络配置基础

### 网络配置文件

#### RHEL/CentOS (NetworkManager)

```bash
# /etc/NetworkManager/system-connections/eth0.nmconnection
[connection]
id=eth0
type=ethernet
interface-name=eth0

[ipv4]
method=manual
addresses=192.168.1.100/24
gateway=192.168.1.1
dns=8.8.8.8;8.8.4.4
```

#### Ubuntu (Netplan)

```yaml
# /etc/netplan/01-network.yaml
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
```

```bash
# 应用配置
netplan apply
```

### 临时配置

```bash
# 设置 IP
ip addr add 192.168.1.100/24 dev eth0

# 启用接口
ip link set eth0 up

# 添加默认网关
ip route add default via 192.168.1.1

# 设置 DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

---

## 网络命令工具

### ip 命令

```bash
# 查看地址
ip addr show
ip a

# 查看接口
ip link show

# 查看路由
ip route show
ip r

# 查看邻居 (ARP)
ip neigh show

# 查看统计
ip -s link show eth0
```

### ss 命令

```bash
# 所有连接
ss -a

# 监听端口
ss -tlnp

# TCP 连接
ss -tnp

# UDP 连接
ss -unp

# 按状态过滤
ss -t state established
ss -t state time-wait

# 按端口过滤
ss -t dst :80
```

| 选项 | 说明 |
|:---|:---|
| `-t` | TCP |
| `-u` | UDP |
| `-l` | 监听 |
| `-n` | 不解析 |
| `-p` | 显示进程 |
| `-a` | 所有 |

### netstat (旧版)

```bash
netstat -tlnp    # 监听端口
netstat -anp     # 所有连接
netstat -rn      # 路由表
netstat -s       # 统计信息
```

---

## 路由与 NAT

### 路由配置

```bash
# 查看路由表
ip route show

# 添加路由
ip route add 10.0.0.0/8 via 192.168.1.1
ip route add 10.0.0.0/8 dev eth0

# 删除路由
ip route del 10.0.0.0/8

# 默认路由
ip route add default via 192.168.1.1
```

### IP 转发

```bash
# 临时启用
echo 1 > /proc/sys/net/ipv4/ip_forward

# 永久配置
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p
```

### NAT 配置

```bash
# SNAT (源地址转换)
iptables -t nat -A POSTROUTING -s 10.0.0.0/8 -o eth0 -j MASQUERADE

# DNAT (目标地址转换)
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to 192.168.1.100:8080
```

---

## iptables 防火墙

### 基本概念

| 表 | 链 | 用途 |
|:---|:---|:---|
| **filter** | INPUT, OUTPUT, FORWARD | 数据包过滤 |
| **nat** | PREROUTING, POSTROUTING, OUTPUT | 地址转换 |
| **mangle** | 全部 | 数据包修改 |
| **raw** | PREROUTING, OUTPUT | 连接跟踪 |

### 基本操作

```bash
# 查看规则
iptables -L -n -v
iptables -t nat -L -n

# 清空规则
iptables -F

# 默认策略
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
```

### 常用规则

```bash
# 允许已建立连接
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 允许本地回环
iptables -A INPUT -i lo -j ACCEPT

# 允许 SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# 允许 HTTP/HTTPS
iptables -A INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT

# 允许 ICMP
iptables -A INPUT -p icmp -j ACCEPT

# 拒绝其他
iptables -A INPUT -j DROP
```

### 保存规则

```bash
# RHEL/CentOS
iptables-save > /etc/sysconfig/iptables
iptables-restore < /etc/sysconfig/iptables

# Ubuntu
iptables-save > /etc/iptables/rules.v4
```

---

## 网络排查工具

### 连通性测试

```bash
# ping
ping -c 4 8.8.8.8

# traceroute
traceroute 8.8.8.8
mtr 8.8.8.8

# 端口测试
nc -zv host 80
telnet host 80
```

### DNS 排查

```bash
# 查询
nslookup domain.com
dig domain.com
host domain.com

# 指定 DNS
dig @8.8.8.8 domain.com

# 详细查询
dig +trace domain.com
```

### 抓包分析

```bash
# tcpdump
tcpdump -i eth0
tcpdump -i eth0 port 80
tcpdump -i eth0 host 192.168.1.1
tcpdump -i eth0 -w capture.pcap

# 常用选项
tcpdump -n          # 不解析
tcpdump -v          # 详细
tcpdump -X          # 显示内容
```

### 常用诊断

```bash
# ARP 表
arp -n
ip neigh

# 网络接口统计
ifstat
sar -n DEV 1

# 连接统计
ss -s
nstat
```

---

## 网络性能调优

### 内核参数

```bash
# /etc/sysctl.d/99-network.conf

# TCP 缓冲区
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# 连接队列
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# TIME_WAIT
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1

# 保活
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 15
```

```bash
# 应用配置
sysctl --system
```

### 网卡优化

```bash
# 查看网卡配置
ethtool eth0

# 设置 ring buffer
ethtool -G eth0 rx 4096 tx 4096

# 开启硬件卸载
ethtool -K eth0 tso on gso on gro on
```

---

## 相关文档

- [210-linux-system-architecture](./210-linux-system-architecture.md) - 系统架构
- [220-network-protocols-stack](./220-network-protocols-stack.md) - 网络协议栈
- [221-tcp-udp-deep-dive](./221-tcp-udp-deep-dive.md) - TCP/UDP 详解
