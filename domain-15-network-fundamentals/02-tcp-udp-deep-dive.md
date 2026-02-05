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

## 生产环境 TCP 连接池优化

### 连接池管理策略

#### 连接池配置参数

| 参数 | 说明 | 生产环境推荐值 | 影响 |
|:---|:---|:---:|:---|
| **max_connections** | 最大连接数 | 1000-5000 | 内存占用 |
| **min_connections** | 最小空闲连接 | 10-50 | 响应速度 |
| **idle_timeout** | 空闲超时 | 300-600秒 | 资源回收 |
| **max_lifetime** | 连接最大生存期 | 3600秒 | 防止僵死 |
| **validation_timeout** | 验证超时 | 5秒 | 健康检查 |

#### 连接池监控指标

```bash
# TCP 连接池状态监控
monitor_connection_pool() {
    local SERVICE_NAME=$1
    local PORT=$2
    
    echo "=== $SERVICE_NAME 连接池状态 ==="
    
    # 当前连接数统计
    CURRENT_CONNS=$(ss -tn state established "( dport = :$PORT or sport = :$PORT )" | wc -l)
    echo "当前活跃连接数: $CURRENT_CONNS"
    
    # 连接状态分布
    echo "连接状态分布:"
    ss -tn state established "( dport = :$PORT or sport = :$PORT )" | awk '{print $1}' | sort | uniq -c
    
    # 进程连接数
    echo "进程连接数:"
    lsof -i :$PORT | grep -c ESTABLISHED
    
    # 系统TCP统计
    echo "TCP 统计信息:"
    cat /proc/net/snmp | grep Tcp: | tail -1 | awk '{print "Active Opens:", $7, "Passive Opens:", $8, "Attempt Fails:", $10}'
}

# 使用示例
# monitor_connection_pool "web_service" 8080
```

### TCP 性能监控与告警

#### 关键性能指标

| 指标 | 正常范围 | 告警阈值 | 监控工具 |
|:---|:---:|:---:|:---|
| **RTT** | < 10ms | > 50ms | ping, tcpdump |
| **重传率** | < 1% | > 5% | ss, netstat |
| **连接建立时间** | < 100ms | > 500ms | tcpdump |
| **吞吐量** | 根据带宽调整 | < 50%峰值 | iperf3 |

#### 生产环境监控脚本

```bash
#!/bin/bash
# TCP 性能监控脚本

SERVICE_PORT=8080
THRESHOLD_RTT=50      # ms
THRESHOLD_RETRANS=5   # %
THRESHOLD_CONN_TIME=500  # ms

# 监控函数
monitor_tcp_performance() {
    local target_host=$1
    
    # 测试 RTT
    RTT=$(ping -c 5 $target_host | tail -1 | awk -F'/' '{print $5}')
    
    # 检查连接建立时间
    CONN_TIME=$(timeout 10 bash -c "time telnet $target_host $SERVICE_PORT" 2>&1 | grep real | awk '{print $2}' | cut -d'm' -f1)
    
    # 检查重传率
    RETRANS_STATS=$(ss -i state established "( dport = :$SERVICE_PORT )" | grep -c retrans)
    TOTAL_CONNS=$(ss -t state established "( dport = :$SERVICE_PORT )" | wc -l)
    
    if [ $TOTAL_CONNS -gt 0 ]; then
        RETRANS_RATE=$((RETRANS_STATS * 100 / TOTAL_CONNS))
    else
        RETRANS_RATE=0
    fi
    
    # 告警判断
    if (( $(echo "$RTT > $THRESHOLD_RTT" | bc -l) )) || \
       [ $RETRANS_RATE -gt $THRESHOLD_RETRANS ] || \
       (( $(echo "$CONN_TIME > $THRESHOLD_CONN_TIME" | bc -l) )); then
        
        echo "$(date): TCP性能异常 - RTT:${RTT}ms 重传率:${RETRANS_RATE}% 连接时间:${CONN_TIME}ms"
        # 发送告警通知...
    fi
}

# 持续监控
while true; do
    monitor_tcp_performance "localhost"
    sleep 30
done
```

### TCP 生产调优参数

#### 应用层调优

```bash
# 应用层面 TCP 优化
# /etc/sysctl.conf

# 增加本地端口范围
net.ipv4.ip_local_port_range = 1024 65535

# TCP 时间等待优化
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0  # 已废弃，使用 tw_reuse 替代

# TCP 缓冲区优化
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# TCP 窗口缩放
net.ipv4.tcp_window_scaling = 1

# 快速回收 TIME_WAIT
net.ipv4.tcp_fin_timeout = 30

# TCP 保活设置
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3
```

#### 负载均衡器 TCP 优化

```nginx
# Nginx TCP 优化配置
upstream backend_tcp {
    server 10.0.0.10:8080;
    server 10.0.0.11:8080;
    
    # 连接池设置
    keepalive 32;
    keepalive_requests 1000;
    keepalive_timeout 60s;
    
    # 负载均衡算法
    least_conn;
}

server {
    listen 8080;
    
    # TCP 优化参数
    tcp_nodelay on;
    tcp_nopush on;
    
    proxy_pass backend_tcp;
    proxy_timeout 90s;
    proxy_responses 1;
    
    # 健康检查
    health_check interval=5s fails=3 passes=2;
}
```

## 高级TCP连接池配置与优化

### 连接池高级配置策略

#### 动态连接池调整

```bash
# 智能连接池管理脚本
#!/bin/bash
# 根据负载动态调整连接池大小

SERVICE_NAME="mysql"
POOL_CONFIG_FILE="/etc/connection-pool/${SERVICE_NAME}.conf"
METRICS_ENDPOINT="http://localhost:9104/metrics"

# 连接池配置模板
adjust_connection_pool() {
    local current_load=$1
    local pool_size=0
    local min_pool=10
    local max_pool=1000
    
    # 根据负载计算最优连接池大小
    if [ $current_load -lt 30 ]; then
        pool_size=50
    elif [ $current_load -lt 70 ]; then
        pool_size=200
    else
        pool_size=500
    fi
    
    # 确保在合理范围内
    pool_size=$((pool_size > min_pool ? pool_size : min_pool))
    pool_size=$((pool_size < max_pool ? pool_size : max_pool))
    
    # 更新配置文件
    cat > $POOL_CONFIG_FILE << EOF
{
    "service": "$SERVICE_NAME",
    "max_connections": $pool_size,
    "min_connections": $((pool_size/10)),
    "idle_timeout": 300,
    "max_lifetime": 3600,
    "validation_timeout": 5,
    "acquire_increment": 5,
    "acquire_retry_attempts": 3,
    "acquire_retry_delay": 1000
}
EOF
    
    echo "$(date): 连接池大小调整为 $pool_size (负载: ${current_load}%)"
}

# 监控负载并调整
monitor_and_adjust() {
    while true; do
        # 获取系统负载
        load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
        load_percent=$(echo "$load_avg * 100 / $(nproc)" | bc)
        
        # 获取应用特定指标 (如果可用)
        if curl -sf $METRICS_ENDPOINT >/dev/null 2>&1; then
            app_load=$(curl -s $METRICS_ENDPOINT | grep "app_request_rate" | awk '{print $2}')
            if [ ! -z "$app_load" ]; then
                load_percent=$((load_percent + app_load/10))
            fi
        fi
        
        # 调整连接池
        adjust_connection_pool $load_percent
        
        sleep 60
    done
}

# 启动监控
# monitor_and_adjust &
```

#### 连接池故障自愈机制

```bash
# 连接池健康检查与自愈
connection_pool_health_check() {
    local service_name=$1
    local pool_stats=$(curl -s "http://localhost:8080/actuator/metrics/connection.pool.active")
    
    # 解析连接池状态
    active_connections=$(echo $pool_stats | jq '.measurements[0].value')
    max_connections=$(echo $pool_stats | jq '.measurements[1].value')
    
    utilization_rate=$((active_connections * 100 / max_connections))
    
    # 健康检查逻辑
    if [ $utilization_rate -gt 90 ]; then
        echo "$(date): 连接池使用率过高 (${utilization_rate}%)"
        # 触发扩容
        scale_up_connection_pool $service_name
    elif [ $utilization_rate -lt 10 ]; then
        echo "$(date): 连接池使用率过低 (${utilization_rate}%)"
        # 触发缩容
        scale_down_connection_pool $service_name
    fi
    
    # 检查连接泄漏
    leaked_connections=$(check_connection_leaks $service_name)
    if [ $leaked_connections -gt 0 ]; then
        echo "$(date): 发现连接泄漏: $leaked_connections 个"
        # 触发连接清理
        cleanup_leaked_connections $service_name
    fi
}

# 连接泄漏检测
check_connection_leaks() {
    local service_name=$1
    local threshold_minutes=30
    
    # 检查长时间未使用的连接
    ss -tn state established | grep $service_name | \
        awk '{print $4}' | cut -d: -f2 | \
        while read port; do
            lsof -i :$port | grep -E "(ESTABLISHED.*[0-9]+:[0-9]+:[0-9]+:[0-9]+)" | \
            while read line; do
                conn_time=$(echo $line | awk '{print $9}')
                # 如果连接时间超过阈值，则认为可能泄漏
                if [ $conn_time -gt $threshold_minutes ]; then
                    echo $line
                fi
            done | wc -l
        done
}
```

## TCP高级性能调优与监控

### TCP高级调优参数详解

#### BBR拥塞控制算法深度配置

```bash
# BBR拥塞控制高级配置
configure_bbr_advanced() {
    # 启用BBR
    echo "bbr" > /proc/sys/net/ipv4/tcp_congestion_control
    
    # BBR高级参数调优
    cat >> /etc/sysctl.conf << EOF
# BBR拥塞控制高级配置
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_early_retrans = 3
net.ipv4.tcp_recovery = 1
net.ipv4.tcp_thin_linear_timeouts = 1
EOF

    # 应用配置
    sysctl -p
    
    # 验证配置
    echo "当前拥塞控制算法: $(cat /proc/sys/net/ipv4/tcp_congestion_control)"
    echo "默认队列规则: $(cat /proc/sys/net/core/default_qdisc)"
}

# 不同场景的BBR配置
configure_bbr_for_scenario() {
    local scenario=$1  # high_latency, low_loss, high_loss
    
    case $scenario in
        "high_latency")
            # 高延迟网络优化
            echo 16777216 > /proc/sys/net/core/rmem_max
            echo 16777216 > /proc/sys/net/core/wmem_max
            echo "4096 65536 16777216" > /proc/sys/net/ipv4/tcp_rmem
            echo "4096 65536 16777216" > /proc/sys/net/ipv4/tcp_wmem
            ;;
        "low_loss")
            # 低丢包网络优化
            echo "cubic" > /proc/sys/net/ipv4/tcp_congestion_control
            echo 4194304 > /proc/sys/net/core/rmem_max
            echo 4194304 > /proc/sys/net/core/wmem_max
            ;;
        "high_loss")
            # 高丢包网络优化
            echo "bbr" > /proc/sys/net/ipv4/tcp_congestion_control
            echo 33554432 > /proc/sys/net/core/rmem_max
            echo 33554432 > /proc/sys/net/core/wmem_max
            ;;
    esac
}
```

#### TCP Fast Open 配置

```bash
# TCP Fast Open 生产环境配置
enable_tcp_fast_open() {
    # 服务端配置
    echo 3 > /proc/sys/net/ipv4/tcp_fastopen  # 启用服务端和客户端
    
    # 应用到sysctl
    cat >> /etc/sysctl.conf << EOF
# TCP Fast Open 配置
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fastopen_key = 0123456789abcdef0123456789abcdef
net.ipv4.tcp_fastopen_cookie = 1
EOF

    # Nginx配置示例
    cat >> /etc/nginx/nginx.conf << EOF
server {
    listen 80 fastopen=256;
    # 其他配置...
}
EOF

    # 验证配置
    ss -ltn | grep -E "fastopen|FO"
}
```

### 高级TCP监控与告警系统

#### TCP状态深度监控

```bash
#!/bin/bash
# TCP状态深度监控脚本

MONITOR_INTERVAL=30
ALERT_THRESHOLD=1000  # TIME_WAIT连接数阈值

tcp_state_monitor() {
    echo "=== TCP状态深度监控报告 ==="
    echo "监控时间: $(date)"
    echo ""
    
    # 1. TCP连接状态统计
    echo "1. TCP连接状态分布:"
    ss -tan | awk 'NR>1 {print $1}' | sort | uniq -c | sort -nr
    
    # 2. 详细的TIME_WAIT分析
    echo -e "\n2. TIME_WAIT连接详情:"
    time_wait_count=$(ss -tan state time-wait | wc -l)
    echo "TIME_WAIT连接总数: $time_wait_count"
    
    if [ $time_wait_count -gt $ALERT_THRESHOLD ]; then
        echo "⚠️  WARNING: TIME_WAIT连接数超过阈值 ($ALERT_THRESHOLD)"
        # 按远程地址统计
        ss -tan state time-wait | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -10
    fi
    
    # 3. SYN队列状态
    echo -e "\n3. SYN队列状态:"
    netstat -s | grep -i "listen\|syn"
    
    # 4. 重传统计
    echo -e "\n4. TCP重传统计:"
    cat /proc/net/snmp | grep Tcp: | tail -1 | awk '{
        print "主动打开:", $7
        print "被动打开:", $8
        print "失败尝试:", $10
        print "重传段数:", $12
        print "丢弃段数:", $14
    }'
    
    # 5. 缓冲区使用情况
    echo -e "\n5. TCP缓冲区使用:"
    cat /proc/net/sockstat | grep TCP:
    
    # 6. 异常连接检测
    echo -e "\n6. 异常连接检测:"
    # 检测半开连接
    half_open=$(ss -tan state syn-sent | wc -l)
    echo "SYN_SENT状态连接: $half_open"
    
    # 检测异常CLOSE_WAIT
    close_wait=$(ss -tan state close-wait | wc -l)
    if [ $close_wait -gt 100 ]; then
        echo "⚠️  WARNING: CLOSE_WAIT连接过多: $close_wait"
    fi
}

# 持续监控
while true; do
    tcp_state_monitor > /var/log/tcp_monitor_$(date +%Y%m%d_%H%M%S).log
    sleep $MONITOR_INTERVAL
done
```

#### TCP性能瓶颈分析工具

```bash
# TCP性能瓶颈分析脚本
analyze_tcp_bottlenecks() {
    local target_host=$1
    local duration=${2:-60}  # 默认监控60秒
    
    echo "=== TCP性能瓶颈分析: $target_host ==="
    
    # 1. 基础连通性测试
    echo "1. 基础连通性测试:"
    ping -c 5 $target_host
    
    # 2. 端口连通性测试
    echo -e "\n2. 端口连通性测试:"
    nc -zv $target_host 80 2>&1
    nc -zv $target_host 443 2>&1
    
    # 3. TCP窗口大小测试
    echo -e "\n3. TCP窗口大小分析:"
    ss -i state established dst $target_host
    
    # 4. 网络路径分析
    echo -e "\n4. 网络路径质量分析:"
    mtr --report --report-cycles 10 $target_host
    
    # 5. 持续性能监控
    echo -e "\n5. 持续性能监控 ($duration 秒):"
    
    # 启动后台监控
    {
        for i in $(seq 1 $duration); do
            timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            
            # RTT测量
            rtt=$(ping -c 1 $target_host | tail -1 | awk -F'/' '{print $5}')
            
            # 连接数统计
            conn_count=$(ss -tan dst $target_host | wc -l)
            
            # 重传统计
            retrans=$(ss -i state established dst $target_host | grep -c retrans)
            
            echo "$timestamp,RTT:${rtt}ms,Connections:$conn_count,Retransmissions:$retrans"
            sleep 1
        done
    } > /tmp/tcp_analysis_$$.csv &
    
    ANALYSIS_PID=$!
    wait $ANALYSIS_PID
    
    # 6. 生成分析报告
    echo -e "\n6. 性能分析报告:"
    awk -F',' '
    NR==1 {next}
    {
        rtt_sum += $2
        conn_sum += $3
        retrans_sum += $4
        count++
    }
    END {
        printf "平均RTT: %.2f ms\n", rtt_sum/count
        printf "平均连接数: %.0f\n", conn_sum/count
        printf "平均重传数: %.0f\n", retrans_sum/count
    }' /tmp/tcp_analysis_$$.csv
    
    # 清理临时文件
    rm -f /tmp/tcp_analysis_$$.csv
}

# 使用示例
# analyze_tcp_bottlenecks "10.0.0.100" 120
```

## UDP高级应用场景优化

### 实时音视频UDP优化

#### WebRTC UDP优化配置

```bash
# WebRTC实时通信UDP优化
optimize_webrtc_udp() {
    # 内核参数优化
    cat >> /etc/sysctl.conf << EOF
# WebRTC UDP优化
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.ipv4.udp_mem = 196608 262144 393216
net.netfilter.nf_conntrack_udp_timeout = 30
net.netfilter.nf_conntrack_udp_timeout_stream = 180
EOF

    # 应用配置
    sysctl -p

    # iptables优化规则
    iptables -I INPUT -p udp --dport 10000:20000 -j ACCEPT
    iptables -I OUTPUT -p udp --sport 10000:20000 -j ACCEPT

    # 设置UDP缓冲区大小 (应用程序级别)
    echo 'net.core.rmem_max=134217728' >> /etc/security/limits.conf
    echo 'net.core.wmem_max=134217728' >> /etc/security/limits.conf
}

# SFU (Selective Forwarding Unit) 优化
optimize_sfu_udp() {
    local sfu_port_range="30000:40000"
    
    # 端口范围优化
    cat >> /etc/sysctl.conf << EOF
# SFU UDP端口优化
net.ipv4.ip_local_port_range = 1024 65535
net.netfilter.nf_conntrack_max = 1048576
net.netfilter.nf_conntrack_buckets = 65536
EOF

    # 应用配置
    sysctl -p

    # 防火墙配置
    iptables -A INPUT -p udp --dport $sfu_port_range -m conntrack --ctstate NEW -j ACCEPT
    iptables -A INPUT -p udp --dport $sfu_port_range -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
}
```

### UDP广播与多播优化

#### 多播UDP配置

```bash
# 多播UDP生产环境配置
configure_multicast_udp() {
    local multicast_group="239.255.0.1"
    local interface="eth0"
    
    # 启用多播路由
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo 1 > /proc/sys/net/ipv4/conf/all/mc_forwarding
    
    # 配置接口多播
    ip link set $interface multicast on
    ip addr add $multicast_group/32 dev $interface autojoin
    
    # IGMP优化
    cat >> /etc/sysctl.conf << EOF
# IGMP多播优化
net.ipv4.igmp_qrv = 2
net.ipv4.igmp_qqi = 125
net.ipv4.igmp_unsolicited_report_interval = 10
EOF

    # 多播路由配置
    cat > /etc/smcroute.conf << EOF
# SMCRoute多播路由配置
mgroup from $interface group $multicast_group
EOF

    # 应用配置
    sysctl -p
    systemctl restart smcroute
}

# 多播性能监控
monitor_multicast_performance() {
    echo "=== 多播性能监控 ==="
    
    # 多播组成员统计
    echo "多播组成员:"
    cat /proc/net/igmp
    
    # 网络接口多播统计
    echo -e "\n接口多播统计:"
    ip -s maddr show
    
    # 多播路由表
    echo -e "\n多播路由表:"
    ip mroute show
    
    # 多播包统计
    echo -e "\n多播包统计:"
    cat /proc/net/snmp | grep UdpLite:
}

# 多播故障诊断
diagnose_multicast_issues() {
    local multicast_addr=$1
    
    echo "=== 多播故障诊断: $multicast_addr ==="
    
    # 1. 检查多播路由
    echo "1. 多播路由检查:"
    ip mroute show $multicast_addr
    
    # 2. 检查IGMP成员关系
    echo -e "\n2. IGMP成员关系:"
    cat /proc/net/igmp | grep $(echo $multicast_addr | tr . " ")
    
    # 3. 网络接口状态
    echo -e "\n3. 网络接口多播状态:"
    for iface in $(ip link show | grep -E "^[0-9]+" | awk -F': ' '{print $2}'); do
        echo "$iface: $(ip link show $iface | grep -o 'MULTICAST')"
    done
    
    # 4. 防火墙检查
    echo -e "\n4. 防火墙多播规则:"
    iptables -L INPUT -v -n | grep -i multi
    iptables -L OUTPUT -v -n | grep -i multi
}
```

### UDP安全防护配置

#### DDoS防护与速率限制

```bash
# UDP DDoS防护配置
configure_udp_ddos_protection() {
    local max_packets_per_second=1000
    
    # iptables速率限制规则
    iptables -A INPUT -p udp -m hashlimit \
        --hashlimit-above ${max_packets_per_second}/sec \
        --hashlimit-mode srcip \
        --hashlimit-name udp_limit \
        -j DROP
    
    # UDP洪水攻击防护
    iptables -A INPUT -p udp -m u32 --u32 "0>>22&0x3C@8&0xFFFF=0x1401" -j DROP  # DNS查询
    iptables -A INPUT -p udp -m u32 --u32 "0>>22&0x3C@8&0xFFFF=0x1801" -j DROP  # DNS响应
    
    # NTP放大攻击防护
    iptables -A INPUT -p udp --dport 123 -m length --length 0:48 -j DROP
    
    # SNMP放大攻击防护
    iptables -A INPUT -p udp --dport 161 -j DROP
    
    # 保存规则
    iptables-save > /etc/iptables/rules.v4
}

# UDP异常流量检测
detect_udp_anomalies() {
    echo "=== UDP异常流量检测 ==="
    
    # 检测UDP端口扫描
    echo "UDP端口扫描检测:"
    netstat -un | awk '{print $4}' | cut -d: -f2 | sort | uniq -c | sort -nr | head -10
    
    # 检测UDP洪水攻击
    echo -e "\nUDP流量速率分析:"
    while true; do
        packet_count=$(cat /proc/net/dev | grep eth0 | awk '{print $3}')
        sleep 1
        new_packet_count=$(cat /proc/net/dev | grep eth0 | awk '{print $3}')
        rate=$((new_packet_count - packet_count))
        
        if [ $rate -gt 10000 ]; then  # 阈值10000 packets/sec
            echo "$(date): UDP流量异常高: ${rate} packets/sec"
        fi
    done
}
```

---

## 相关文档

- [01-network-protocols-stack](./01-network-protocols-stack.md) - 网络协议栈
- [04-load-balancing-technologies](./04-load-balancing-technologies.md) - 负载均衡
- [213-linux-networking-configuration](./213-linux-networking-configuration.md) - Linux 网络配置
