# 06 - Linux 性能调优与瓶颈分析：生产环境性能优化专家指南

> **适用版本**: Linux Kernel 5.x/6.x | **最后更新**: 2026-02 | **作者**: Allen Galler (allengaller@gmail.com)

---

## 摘要

本文档从生产环境性能优化专家视角，系统讲解 Linux 系统性能分析、瓶颈诊断和调优优化的核心方法。涵盖CPU、内存、I/O、网络等全栈性能监控，提供科学的性能分析方法论和实用的调优策略，帮助企业构建高性能的计算基础设施。

**核心价值**：
- 📊 **性能监控体系**：建立完整的系统性能监控和告警机制
- 🔍 **瓶颈诊断方法**：科学的性能问题定位和根因分析流程
- ⚡ **调优优化策略**：针对不同场景的系统参数调优和优化方案
- 🛠️ **分析工具链**：性能分析工具的选择、配置和使用技巧
- 📈 **容量规划**：基于性能数据的资源规划和扩容决策

---

## 目录

- [性能分析方法论](#性能分析方法论)
- [CPU 性能分析](#cpu-性能分析)
- [内存性能分析](#内存性能分析)
- [I/O 性能分析](#io-性能分析)
- [网络性能分析](#网络性能分析)
- [内核参数优化](#内核参数优化)

---

## 性能分析方法论

### USE 方法

| 指标 | 说明 | 检查命令 |
|:---|:---|:---|
| **Utilization** | 资源使用率 | top, vmstat, iostat |
| **Saturation** | 资源饱和度 | runq, swapping |
| **Errors** | 错误计数 | dmesg, /var/log |

### 分析工具概览

| 工具 | CPU | 内存 | I/O | 网络 |
|:---:|:---:|:---:|:---:|:---:|
| top/htop | ✓ | ✓ | ✓ | - |
| vmstat | ✓ | ✓ | ✓ | - |
| iostat | - | - | ✓ | - |
| mpstat | ✓ | - | - | - |
| sar | ✓ | ✓ | ✓ | ✓ |
| perf | ✓ | - | - | - |
| ss/netstat | - | - | - | ✓ |

---

## CPU 性能分析

### 监控工具

```bash
# top
top
# 快捷键: 1-显示各CPU, P-按CPU排序, M-按内存排序

# htop
htop

# mpstat - CPU 统计
mpstat -P ALL 1

# 负载平均
uptime
cat /proc/loadavg

# 中断
cat /proc/interrupts
```

### 性能指标

| 指标 | 正常范围 | 说明 |
|:---|:---|:---|
| **%us** | < 70% | 用户态 CPU |
| **%sy** | < 30% | 内核态 CPU |
| **%wa** | < 5% | I/O 等待 |
| **%st** | < 5% | 虚拟机偷取 |
| **load avg** | < CPU核数 | 负载平均 |

### perf 分析

```bash
# CPU 热点分析
perf top

# 记录性能数据
perf record -g command
perf report

# 统计计数
perf stat command

# 火焰图
perf record -g command
perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg
```

---

## 内存性能分析

### 监控工具

```bash
# free
free -h

# vmstat
vmstat 1
# r - 运行队列
# swpd - swap 使用
# free - 空闲内存
# si/so - swap in/out

# 进程内存
ps aux --sort=-%mem | head
pmap -x <pid>

# /proc/meminfo
cat /proc/meminfo
```

### 关键指标

| 指标 | 位置 | 说明 |
|:---|:---|:---|
| MemTotal | /proc/meminfo | 总内存 |
| MemAvailable | /proc/meminfo | 可用内存 |
| Buffers | /proc/meminfo | 块设备缓冲 |
| Cached | /proc/meminfo | 页缓存 |
| SwapFree | /proc/meminfo | 空闲 swap |

### 内存调优参数

```bash
# /etc/sysctl.d/99-memory.conf

# Swap 倾向 (0-100)
vm.swappiness = 10

# 脏页刷盘
vm.dirty_ratio = 20
vm.dirty_background_ratio = 5

# 内存过量分配
# 0=启发式, 1=总是允许, 2=禁止
vm.overcommit_memory = 0

# OOM 调整
vm.panic_on_oom = 0
```

---

## I/O 性能分析

### 监控工具

```bash
# iostat
iostat -xz 1

# iotop
iotop -oP

# 块设备队列
cat /sys/block/sda/queue/nr_requests

# 进程 I/O
pidstat -d 1
```

### 关键指标

| 指标 | 正常范围 | 说明 |
|:---|:---|:---|
| **await** | < 10ms (SSD) | 平均等待 |
| **%util** | < 80% | 磁盘利用率 |
| **avgqu-sz** | < 4 | 平均队列长度 |
| **r/s, w/s** | 根据设备 | IOPS |

### 性能测试

```bash
# fio 随机读
fio --name=randread --rw=randread --bs=4k --numjobs=4 \
    --size=1G --runtime=60 --filename=/dev/sdb --direct=1

# fio 随机写
fio --name=randwrite --rw=randwrite --bs=4k --numjobs=4 \
    --size=1G --runtime=60 --filename=/dev/sdb --direct=1
```

---

## 网络性能分析

### 监控工具

```bash
# ss - 连接统计
ss -s

# sar - 网络统计
sar -n DEV 1

# 接口流量
cat /proc/net/dev
ifstat

# 带宽测试
iperf3 -s            # 服务端
iperf3 -c <server>   # 客户端
```

### 关键指标

| 指标 | 说明 | 监控方法 |
|:---|:---|:---|
| **带宽** | 吞吐量 | sar -n DEV |
| **PPS** | 每秒包数 | sar -n DEV |
| **延迟** | RTT | ping, mtr |
| **连接数** | TCP 连接 | ss -s |
| **丢包** | 丢包率 | netstat -s |

### 网络调优

```bash
# /etc/sysctl.d/99-network.conf

# 缓冲区大小
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# 连接队列
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# TIME_WAIT
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
```

---

## 内核参数优化

### 生产环境参数

```bash
# /etc/sysctl.d/99-production.conf

# 网络
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_forward = 1

# 内存
vm.swappiness = 10
vm.max_map_count = 262144
vm.dirty_ratio = 20
vm.dirty_background_ratio = 5

# 文件
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192

# 网络缓冲
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
```

### 应用配置

```bash
sysctl --system
```

### ulimit 配置

```bash
# /etc/security/limits.conf
*       soft    nofile    65536
*       hard    nofile    65536
*       soft    nproc     65536
*       hard    nproc     65536
```

---

## 相关文档

- [210-linux-system-architecture](./210-linux-system-architecture.md) - 系统架构
- [211-linux-process-management](./211-linux-process-management.md) - 进程管理
- [213-linux-networking-configuration](./213-linux-networking-configuration.md) - 网络配置
