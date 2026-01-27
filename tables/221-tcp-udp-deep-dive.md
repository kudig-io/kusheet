# TCP/UDP 协议深度解析

> **适用版本**: TCP/IP 协议族 | **最后更新**: 2026-01

---

## 目录

- [TCP 协议详解](#tcp-协议详解)
- [TCP 连接管理](#tcp-连接管理)
- [TCP 流量控制](#tcp-流量控制)
- [TCP 拥塞控制](#tcp-拥塞控制)
- [UDP 协议详解](#udp-协议详解)
- [TCP vs UDP 选择](#tcp-vs-udp-选择)

---

## TCP 协议详解

### TCP 特性

| 特性 | 说明 |
|:---|:---|
| **面向连接** | 三次握手建立连接 |
| **可靠传输** | 确认、重传、校验 |
| **有序交付** | 序列号保证顺序 |
| **流量控制** | 滑动窗口机制 |
| **拥塞控制** | 避免网络拥塞 |

### TCP 头部结构

| 字段 | 长度 | 说明 |
|:---|:---:|:---|
| 源端口 | 16 bit | 发送端口 |
| 目标端口 | 16 bit | 接收端口 |
| 序列号 | 32 bit | 数据序号 |
| 确认号 | 32 bit | ACK 序号 |
| 数据偏移 | 4 bit | 头部长度 |
| 标志位 | 6 bit | SYN/ACK/FIN 等 |
| 窗口大小 | 16 bit | 接收窗口 |
| 校验和 | 16 bit | 完整性校验 |

### TCP 标志位

| 标志 | 说明 |
|:---|:---|
| **SYN** | 同步，建立连接 |
| **ACK** | 确认 |
| **FIN** | 结束，关闭连接 |
| **RST** | 重置连接 |
| **PSH** | 推送，立即传递 |
| **URG** | 紧急数据 |

---

## TCP 连接管理

### 三次握手

```
     客户端                              服务端
        │                                  │
        │────── SYN (seq=x) ──────────►   │
        │                                  │
        │◄──── SYN+ACK (seq=y, ack=x+1)───│
        │                                  │
        │────── ACK (ack=y+1) ─────────►  │
        │                                  │
     ESTABLISHED                      ESTABLISHED
```

### 四次挥手

```
     客户端                              服务端
        │                                  │
        │────── FIN (seq=u) ──────────►   │
        │                                  │
        │◄──── ACK (ack=u+1) ─────────────│
        │                                  │
        │◄──── FIN (seq=v) ───────────────│
        │                                  │
        │────── ACK (ack=v+1) ─────────►  │
        │                                  │
     TIME_WAIT (2MSL)                  CLOSED
```

### TCP 状态

| 状态 | 说明 |
|:---|:---|
| LISTEN | 等待连接 |
| SYN_SENT | 发送 SYN 后 |
| SYN_RECEIVED | 收到 SYN 后 |
| ESTABLISHED | 连接建立 |
| FIN_WAIT_1 | 发送 FIN 后 |
| FIN_WAIT_2 | 收到 ACK 后 |
| TIME_WAIT | 等待 2MSL |
| CLOSE_WAIT | 收到 FIN 后 |
| LAST_ACK | 发送 FIN 后 |
| CLOSED | 关闭 |

### 查看 TCP 状态

```bash
# 状态统计
ss -s

# 按状态过滤
ss -t state established
ss -t state time-wait

# 详细连接
ss -tnp
netstat -antp
```

---

## TCP 流量控制

### 滑动窗口

```
发送方缓冲区
┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐
│已确认│已确认│已发送│已发送│可发送│可发送│不可发│不可发│
│     │     │未确认│未确认│     │     │     │     │
└─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘
              └─────────────────┘
                   发送窗口
```

### 窗口大小

```bash
# 查看窗口参数
sysctl net.ipv4.tcp_window_scaling
sysctl net.core.rmem_max
sysctl net.core.wmem_max

# TCP 缓冲区设置
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
```

---

## TCP 拥塞控制

### 拥塞控制算法

| 算法 | 特点 | 适用场景 |
|:---|:---|:---|
| **reno** | 经典算法 | 低延迟网络 |
| **cubic** | Linux 默认 | 通用场景 |
| **bbr** | Google 开发 | 高延迟/丢包网络 |
| **vegas** | 基于延迟 | 低丢包网络 |

### 拥塞控制配置

```bash
# 查看可用算法
sysctl net.ipv4.tcp_available_congestion_control

# 查看当前算法
sysctl net.ipv4.tcp_congestion_control

# 设置 BBR
sysctl -w net.ipv4.tcp_congestion_control=bbr

# 永久配置
echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
```

### 拥塞控制阶段

| 阶段 | 说明 |
|:---|:---|
| 慢启动 | cwnd 指数增长 |
| 拥塞避免 | cwnd 线性增长 |
| 快速重传 | 3 个重复 ACK |
| 快速恢复 | 减半 cwnd |

---

## UDP 协议详解

### UDP 特性

| 特性 | 说明 |
|:---|:---|
| **无连接** | 无需建立连接 |
| **不可靠** | 无确认和重传 |
| **无序** | 不保证顺序 |
| **快速** | 开销小、延迟低 |

### UDP 头部结构

| 字段 | 长度 | 说明 |
|:---|:---:|:---|
| 源端口 | 16 bit | 发送端口 |
| 目标端口 | 16 bit | 接收端口 |
| 长度 | 16 bit | 报文长度 |
| 校验和 | 16 bit | 可选校验 |

### UDP 适用场景

| 场景 | 原因 |
|:---|:---|
| DNS 查询 | 简单请求响应 |
| 视频流 | 实时性要求 |
| 在线游戏 | 低延迟要求 |
| VoIP | 实时语音 |
| DHCP | 广播通信 |

---

## TCP vs UDP 选择

### 对比

| 特性 | TCP | UDP |
|:---|:---|:---|
| 连接 | 面向连接 | 无连接 |
| 可靠性 | 可靠 | 不可靠 |
| 有序性 | 有序 | 无序 |
| 头部开销 | 20+ 字节 | 8 字节 |
| 传输效率 | 较低 | 较高 |
| 流控/拥控 | 有 | 无 |

### 选择建议

| 需求 | 推荐协议 |
|:---|:---|
| 数据完整性重要 | TCP |
| 实时性要求高 | UDP |
| 大文件传输 | TCP |
| 广播/多播 | UDP |
| 简单请求响应 | UDP |
| 持久连接 | TCP |

---

## 相关文档

- [220-network-protocols-stack](./220-network-protocols-stack.md) - 网络协议栈
- [223-load-balancing-technologies](./223-load-balancing-technologies.md) - 负载均衡
- [213-linux-networking-configuration](./213-linux-networking-configuration.md) - Linux 网络配置
