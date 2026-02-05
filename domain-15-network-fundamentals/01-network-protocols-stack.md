# 网络协议栈详解

> **适用版本**: TCP/IP 协议族 | **最后更新**: 2026-01

---

## 目录

- [网络模型对比](#网络模型对比)
- [OSI 七层模型](#osi-七层模型)
- [TCP/IP 四层模型](#tcpip-四层模型)
- [数据封装过程](#数据封装过程)
- [常用协议概览](#常用协议概览)
- [Linux 网络栈](#linux-网络栈)

---

## 网络模型对比

### OSI vs TCP/IP

```
┌─────────────────┐    ┌─────────────────┐
│   OSI 7层模型   │    │  TCP/IP 4层模型  │
├─────────────────┤    ├─────────────────┤
│  7. 应用层      │    │                 │
├─────────────────┤    │   应用层        │
│  6. 表示层      │    │   HTTP/DNS/SSH  │
├─────────────────┤    │                 │
│  5. 会话层      │    │                 │
├─────────────────┤    ├─────────────────┤
│  4. 传输层      │    │   传输层        │
│     TCP/UDP     │    │   TCP/UDP       │
├─────────────────┤    ├─────────────────┤
│  3. 网络层      │    │   网络层        │
│     IP/ICMP     │    │   IP/ICMP       │
├─────────────────┤    ├─────────────────┤
│  2. 数据链路层   │    │                 │
│     Ethernet    │    │   网络接口层     │
├─────────────────┤    │   Ethernet/ARP  │
│  1. 物理层      │    │                 │
└─────────────────┘    └─────────────────┘
```

---

## OSI 七层模型

| 层次 | 名称 | 功能 | 协议/设备 |
|:---:|:---|:---|:---|
| 7 | 应用层 | 网络应用接口 | HTTP, FTP, DNS, SSH |
| 6 | 表示层 | 数据格式转换 | SSL/TLS, JPEG, ASCII |
| 5 | 会话层 | 会话管理 | NetBIOS, RPC |
| 4 | 传输层 | 端到端传输 | TCP, UDP |
| 3 | 网络层 | 路由寻址 | IP, ICMP, 路由器 |
| 2 | 数据链路层 | 帧传输 | Ethernet, 交换机 |
| 1 | 物理层 | 比特传输 | 网线, 光纤, 集线器 |

---

## TCP/IP 四层模型

### 应用层

| 协议 | 端口 | 功能 |
|:---|:---:|:---|
| HTTP/HTTPS | 80/443 | Web 服务 |
| DNS | 53 | 域名解析 |
| SSH | 22 | 远程登录 |
| FTP | 21 | 文件传输 |
| SMTP | 25 | 邮件发送 |
| SNMP | 161 | 网络管理 |

### 传输层

| 协议 | 特点 | 使用场景 |
|:---|:---|:---|
| **TCP** | 可靠、有序、流控 | Web, SSH, 邮件 |
| **UDP** | 无连接、快速 | DNS, 视频, 游戏 |

### 网络层

| 协议 | 功能 |
|:---|:---|
| **IP** | 寻址和路由 |
| **ICMP** | 错误报告、ping |
| **ARP** | IP→MAC 解析 |
| **RARP** | MAC→IP 解析 |

### 网络接口层

| 协议/标准 | 功能 |
|:---|:---|
| **Ethernet** | 有线局域网 |
| **Wi-Fi** | 无线局域网 |
| **PPP** | 点对点协议 |

---

## 数据封装过程

```
发送端                                         接收端
┌───────────────┐                       ┌───────────────┐
│    应用层     │ ──── 数据 ────────►   │    应用层     │
├───────────────┤                       ├───────────────┤
│    传输层     │ ──── 段 ─────────►    │    传输层     │
│    TCP头+数据  │                       │               │
├───────────────┤                       ├───────────────┤
│    网络层     │ ──── 包 ─────────►    │    网络层     │
│  IP头+TCP头+数据│                       │               │
├───────────────┤                       ├───────────────┤
│   数据链路层   │ ──── 帧 ─────────►   │   数据链路层   │
│MAC头+IP头+TCP头+数据+FCS│               │               │
├───────────────┤                       ├───────────────┤
│    物理层     │ ──── 比特 ────────►   │    物理层     │
└───────────────┘                       └───────────────┘
```

### MTU 与分片

| 网络类型 | 典型 MTU |
|:---|:---:|
| Ethernet | 1500 |
| PPPoE | 1492 |
| VXLAN/GENEVE | 1450 |
| 隧道 | 1400-1450 |

```bash
# 查看 MTU
ip link show eth0 | grep mtu

# 设置 MTU
ip link set eth0 mtu 1450

# 测试 MTU
ping -M do -s 1472 target
```

---

## 常用协议概览

### IP 协议

| 字段 | 说明 |
|:---|:---|
| Version | 版本 (IPv4/IPv6) |
| TTL | 生存时间 |
| Protocol | 上层协议 (TCP=6, UDP=17) |
| Source IP | 源地址 |
| Dest IP | 目标地址 |

### ICMP 类型

| 类型 | 说明 |
|:---:|:---|
| 0 | Echo Reply (ping 响应) |
| 3 | Destination Unreachable |
| 5 | Redirect |
| 8 | Echo Request (ping 请求) |
| 11 | Time Exceeded |

### ARP 工作流程

```
1. 主机 A 需要发送数据给 IP_B
2. 检查 ARP 缓存，无 IP_B 的 MAC
3. 广播 ARP Request: "谁是 IP_B?"
4. IP_B 回复 ARP Reply: "我是 IP_B，MAC 是..."
5. A 缓存 IP_B→MAC_B 映射
6. 发送数据帧到 MAC_B
```

```bash
# 查看 ARP 缓存
arp -n
ip neigh show

# 清除 ARP 缓存
ip neigh flush all
```

---

## Linux 网络栈

### 网络栈架构

```
┌─────────────────────────────────────────────────────────────────┐
│                         用户空间                                 │
│  应用程序 (socket API)                                          │
└───────────────────────────┬─────────────────────────────────────┘
                            │ 系统调用
┌───────────────────────────┴─────────────────────────────────────┐
│                         内核空间                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Socket 层                                                │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  传输层 (TCP/UDP)                                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Netfilter (iptables/nftables)                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  网络层 (IP 路由)                                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  网络设备驱动                                             │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 查看网络配置

```bash
# 接口信息
ip addr show
ip link show

# 路由表
ip route show

# 连接状态
ss -tunap

# 网络统计
netstat -s
nstat
```

---
## 生产环境网络运维最佳实践

### 网络性能监控

#### 关键性能指标 (KPIs)

| 指标类别 | 指标名称 | 正常范围 | 监控工具 |
|:---|:---|:---|:---|
| **带宽利用率** | RX/TX bytes/sec | < 70% | iftop, nethogs |
| **连接数** | Active connections | 根据应用调整 | ss, netstat |
| **延迟** | RTT (Round Trip Time) | < 1ms (局域网) | ping, mtr |
| **丢包率** | Packet loss | < 0.1% | ping, tcpdump |
| **错误率** | Errors/drops | 0 | ethtool, dmesg |

#### 生产环境监控配置

```bash
# 网络接口监控脚本
#!/bin/bash
INTERFACE="eth0"
THRESHOLD_RX=80  # 80% of capacity
THRESHOLD_TX=80

while true; do
    # 获取接口统计
    RX_BYTES=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
    TX_BYTES=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
    
    # 计算速率 (bytes/sec)
    sleep 1
    RX_BYTES_NEW=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
    TX_BYTES_NEW=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
    
    RX_RATE=$((($RX_BYTES_NEW - $RX_BYTES) / 1))
    TX_RATE=$((($TX_BYTES_NEW - $TX_BYTES) / 1))
    
    # 检查阈值
    if [ $RX_RATE -gt $((1000*1000*$THRESHOLD_RX/100)) ] || \
       [ $TX_RATE -gt $((1000*1000*$THRESHOLD_TX/100)) ]; then
        echo "$(date): High network usage on $INTERFACE - RX: $RX_RATE B/s, TX: $TX_RATE B/s"
        # 发送告警...
    fi
done
```

### 网络故障诊断方法论

#### 三层诊断法

```
┌─────────────────────────────────────────────────────────────────┐
│                        网络故障诊断三层法                         │
├─────────────────────────────────────────────────────────────────┤
│  第一层: 物理层检查                                              │
│  - 网线/光纤连接状态                                            │
│  - 网卡指示灯                                                   │
│  - 交换机端口状态                                               │
├─────────────────────────────────────────────────────────────────┤
│  第二层: 数据链路层检查                                          │
│  - ARP 表项                                                     │
│  - MAC 地址学习                                                 │
│  - VLAN 配置                                                    │
├─────────────────────────────────────────────────────────────────┤
│  第三层及以上: 网络层及应用层检查                                │
│  - 路由表                                                       │
│  - DNS 解析                                                     │
│  - 应用层连通性                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 常用诊断命令组合

```bash
# 网络连通性全套诊断
diagnose_network() {
    local TARGET=$1
    
    echo "=== 网络诊断报告: $TARGET ==="
    
    # 1. 基础连通性
    echo "1. ICMP 连通性测试:"
    ping -c 4 $TARGET
    
    # 2. 端口可达性
    echo -e "\n2. 端口连通性测试:"
    nc -zv $TARGET 80 2>&1
    nc -zv $TARGET 443 2>&1
    
    # 3. 路径跟踪
    echo -e "\n3. 网络路径跟踪:"
    traceroute $TARGET
    
    # 4. DNS 解析
    echo -e "\n4. DNS 解析检查:"
    dig $TARGET
    nslookup $TARGET
    
    # 5. 路由表检查
    echo -e "\n5. 路由表检查:"
    ip route get $TARGET
    
    # 6. 连接状态
    echo -e "\n6. 当前连接状态:"
    ss -tuln | grep $(echo $TARGET | cut -d. -f1-3)
}

# 使用示例
# diagnose_network google.com
```

### 网络调优最佳实践

#### 内核网络参数优化

```bash
# /etc/sysctl.conf - 生产环境网络优化

# TCP 调优
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0

# 连接队列优化
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65535

# 内存优化
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 3

# 安全相关
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_forward = 0

# 应用配置
sysctl -p
```

#### 网络设备调优

```bash
# 网卡中断绑定优化
echo "优化网卡中断处理:"
IRQ_LIST=$(grep eth0 /proc/interrupts | awk '{print $1}' | tr -d ':')
CPU_CORES=$(nproc)

for irq in $IRQ_LIST; do
    echo "Binding IRQ $irq to CPU cores"
    echo $((irq % CPU_CORES)) > /proc/irq/$irq/smp_affinity_list
done

# 开启网卡多队列
ethtool -L eth0 combined 8

# 调整Ring Buffer
ethtool -G eth0 rx 4096 tx 4096
```

## 网络性能基准测试

### 网络性能测试工具矩阵

| 测试工具 | 适用场景 | 测试指标 | 优势特点 |
|:---|:---|:---|:---|
| **iperf3** | 带宽测试 | 吞吐量、延迟、抖动 | 标准化、支持多种协议 |
| **netperf** | 性能基准 | TCP_RR、UDP_RR | 详细统计、低开销 |
| **nuttcp** | 网络容量 | 实际吞吐量 | 真实环境模拟 |
| **mtr** | 路径分析 | 跳数、丢包、延迟 | 实时路径追踪 |
| **tcptrace** | 流量分析 | 连接状态、重传率 | 深度包分析 |

### 生产环境网络基准测试方案

```bash
#!/bin/bash
# 网络性能基准测试脚本

TEST_DURATION=60
TEST_TARGET="10.0.0.100"
RESULTS_DIR="/var/log/network-benchmarks"
DATE_TAG=$(date +%Y%m%d_%H%M%S)

mkdir -p $RESULTS_DIR

# 1. 基础带宽测试
echo "=== 基础带宽测试 ==="
iperf3 -c $TEST_TARGET -t $TEST_DURATION -P 4 -i 5 > $RESULTS_DIR/bandwidth_${DATE_TAG}.txt

# 2. TCP请求响应测试
echo "=== TCP请求响应测试 ==="
netperf -H $TEST_TARGET -t TCP_RR -l $TEST_DURATION > $RESULTS_DIR/tcp_rr_${DATE_TAG}.txt

# 3. UDP延迟测试
echo "=== UDP延迟测试 ==="
netperf -H $TEST_TARGET -t UDP_RR -l $TEST_DURATION > $RESULTS_DIR/udp_rr_${DATE_TAG}.txt

# 4. 路径质量分析
echo "=== 网络路径质量分析 ==="
mtr --report --report-cycles 10 $TEST_TARGET > $RESULTS_DIR/mtr_${DATE_TAG}.txt

# 5. 连接状态分析
echo "=== 连接状态分析 ==="
ss -tuln > $RESULTS_DIR/connections_${DATE_TAG}.txt

# 生成综合报告
generate_benchmark_report() {
    echo "=== 网络性能基准测试报告 ===" > $RESULTS_DIR/report_${DATE_TAG}.txt
    echo "测试时间: $(date)" >> $RESULTS_DIR/report_${DATE_TAG}.txt
    echo "测试目标: $TEST_TARGET" >> $RESULTS_DIR/report_${DATE_TAG}.txt
    echo "" >> $RESULTS_DIR/report_${DATE_TAG}.txt
    
    # 解析测试结果
    if [ -f "$RESULTS_DIR/bandwidth_${DATE_TAG}.txt" ]; then
        echo "带宽测试结果:" >> $RESULTS_DIR/report_${DATE_TAG}.txt
        grep "sender" $RESULTS_DIR/bandwidth_${DATE_TAG}.txt >> $RESULTS_DIR/report_${DATE_TAG}.txt
    fi
    
    echo "" >> $RESULTS_DIR/report_${DATE_TAG}.txt
    echo "详细结果请查看各测试文件" >> $RESULTS_DIR/report_${DATE_TAG}.txt
}

generate_benchmark_report

# 自动告警机制
check_performance_degradation() {
    local current_bandwidth=$(grep "sender" $RESULTS_DIR/bandwidth_${DATE_TAG}.txt | awk '{print $7}')
    local baseline_bandwidth=800  # Mbps 基线值
    
    if (( $(echo "$current_bandwidth < $baseline_bandwidth" | bc -l) )); then
        echo "WARNING: Network performance degradation detected!"
        echo "Current: ${current_bandwidth}Mbps, Baseline: ${baseline_bandwidth}Mbps"
        # 发送告警...
    fi
}

check_performance_degradation
```

## 高级网络故障诊断技巧

### 网络故障诊断决策树

```
┌─────────────────────────────────────────────────────────────────┐
│                    网络故障诊断决策树                             │
├─────────────────────────────────────────────────────────────────┤
│  问题现象: 网络连接超时                                          │
│  ↓                                                               │
│  是否能ping通网关? ──否──→ 检查本地网络配置                     │
│  ↓ 是                                                           │
│  是否能ping通外网? ──否──→ 检查路由和防火墙                     │
│  ↓ 是                                                           │
│  DNS解析是否正常? ──否──→ 检查DNS配置和上游服务器               │
│  ↓ 是                                                           │
│  应用端口是否开放? ──否──→ 检查服务状态和防火墙规则             │
│  ↓ 是                                                           │
│  是否存在性能瓶颈? ──是──→ 进行性能分析和优化                   │
└─────────────────────────────────────────────────────────────────┘
```

### 高级诊断命令组合

```bash
# 网络性能深度分析脚本
advanced_network_diagnostics() {
    local target=$1
    
    echo "=== 高级网络诊断报告: $target ==="
    
    # 1. 网络接口详细信息
    echo "1. 网络接口状态:"
    ip -s link show
    echo ""
    
    # 2. 详细的路由信息
    echo "2. 路由表详情:"
    ip route show table all
    echo ""
    
    # 3. ARP表分析
    echo "3. ARP表状态:"
    ip neigh show
    echo ""
    
    # 4. 网络统计信息
    echo "4. 网络统计:"
    cat /proc/net/dev | grep -v "lo\|face"
    echo ""
    
    # 5. TCP连接状态分析
    echo "5. TCP连接状态分布:"
    ss -tan | awk 'NR>1 {print $1}' | sort | uniq -c | sort -nr
    echo ""
    
    # 6. 网络错误统计
    echo "6. 网络错误统计:"
    netstat -i
    echo ""
    
    # 7. 高级traceroute
    echo "7. 详细路径追踪:"
    traceroute -4 -T -p 80 $target
    echo ""
    
    # 8. MTU路径发现
    echo "8. MTU路径测试:"
    tracepath $target
    echo ""
    
    # 9. 网络质量测试
    echo "9. 网络质量分析:"
    mtr -c 10 -r $target
    echo ""
    
    # 10. 系统网络参数检查
    echo "10. 关键网络参数:"
    sysctl net.ipv4.tcp_congestion_control
    sysctl net.core.rmem_max
    sysctl net.core.wmem_max
}

# 使用示例
# advanced_network_diagnostics "8.8.8.8"
```

## 生产环境调优案例

### 案例1: 高并发Web服务器网络优化

```bash
# 场景: 高并发Web服务器出现连接堆积
# 问题: 大量TIME_WAIT连接导致新连接无法建立

# 优化方案:
optimize_high_concurrency_web() {
    # 1. 调整TCP参数
    cat >> /etc/sysctl.conf << EOF
# 高并发Web服务器优化
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0  # 已废弃，但仍需注意
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
EOF

    # 2. 应用层优化
    cat >> /etc/nginx/nginx.conf << EOF
worker_connections 65535;
worker_rlimit_nofile 65535;
use epoll;
multi_accept on;
EOF

    # 3. 监控脚本
    cat > /usr/local/bin/monitor_connections.sh << 'EOF'
#!/bin/bash
while true; do
    current_conns=$(ss -tan | wc -l)
    time_wait_conns=$(ss -tan state time-wait | wc -l)
    
    if [ $time_wait_conns -gt 10000 ]; then
        echo "$(date): TIME_WAIT连接过多: $time_wait_conns"
        # 可以触发自动清理或其他动作
    fi
    
    sleep 60
done
EOF
    
    chmod +x /usr/local/bin/monitor_connections.sh
}

# 执行优化
# optimize_high_concurrency_web
```

### 案例2: 数据库主从复制网络优化

```bash
# 场景: MySQL主从复制延迟严重
# 问题: 网络不稳定导致binlog传输延迟

optimize_database_replication() {
    # 1. 网络层面优化
    cat >> /etc/sysctl.conf << EOF
# 数据库复制网络优化
net.ipv4.tcp_congestion_control = cubic
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
EOF

    # 2. 应用层面优化
    mysql -e "SET GLOBAL slave_net_timeout = 60;"
    mysql -e "SET GLOBAL slave_transaction_retries = 10;"
    
    # 3. 监控复制延迟
    cat > /usr/local/bin/monitor_replication.sh << 'EOF'
#!/bin/bash
while true; do
    delay=$(mysql -e "SHOW SLAVE STATUS\G" | grep Seconds_Behind_Master | awk '{print $2}')
    if [ "$delay" != "NULL" ] && [ $delay -gt 10 ]; then
        echo "$(date): 复制延迟警告: ${delay}秒"
        # 发送告警
    fi
    sleep 30
done
EOF
    
    chmod +x /usr/local/bin/monitor_replication.sh
}

# 执行优化
# optimize_database_replication
```

### 案例3: 容器网络性能优化

```bash
# 场景: Kubernetes集群中Pod网络性能不佳
# 问题: CNI网络插件导致额外的网络开销

optimize_container_network() {
    # 1. 内核参数优化
    cat >> /etc/sysctl.conf << EOF
# 容器网络优化
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-ip6tables = 0
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 1
EOF

    # 2. Docker daemon优化
    cat > /etc/docker/daemon.json << EOF
{
    "iptables": false,
    "ip-forward": true,
    "ip-masq": false,
    "userland-proxy": false,
    "live-restore": true,
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOF

    # 3. CNI配置优化 (以Calico为例)
    kubectl patch felixconfiguration default -p '{"spec":{"genericXDPEnabled":true}}'
    
    # 4. 网络策略优化
    cat > network-optimization.yaml << EOF
apiVersion: crd.projectcalico.org/v1
kind: FelixConfiguration
metadata:
  name: default
spec:
  bpfEnabled: true
  bpfLogLevel: ""
  floatingIPs: Disabled
  healthPort: 9099
  logSeverityScreen: Info
  reportingInterval: 0s
EOF

    # 5. 性能监控
    cat > /usr/local/bin/container_network_monitor.sh << 'EOF'
#!/bin/bash
while true; do
    # 监控容器网络接口
    container_ifaces=$(ip link show | grep -E "cali|eth0@" | awk -F': ' '{print $2}')
    
    for iface in $container_ifaces; do
        rx_bytes=$(cat /sys/class/net/$iface/statistics/rx_bytes)
        tx_bytes=$(cat /sys/class/net/$iface/statistics/tx_bytes)
        echo "$(date): $iface RX: $rx_bytes TX: $tx_bytes"
    done
    
    sleep 60
done
EOF
    
    chmod +x /usr/local/bin/container_network_monitor.sh
}

# 执行优化
# optimize_container_network
```

---

## 相关文档

- [02-tcp-udp-deep-dive](./02-tcp-udp-deep-dive.md) - TCP/UDP 详解
- [03-dns-principles-configuration](./03-dns-principles-configuration.md) - DNS 原理
- [213-linux-networking-configuration](./213-linux-networking-configuration.md) - Linux 网络配置
