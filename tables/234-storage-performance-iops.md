# 存储性能与 IOPS

> **适用版本**: 通用 | **最后更新**: 2026-01

---

## 目录

- [存储性能指标](#存储性能指标)
- [性能测试方法](#性能测试方法)
- [性能优化策略](#性能优化策略)
- [性能基准参考](#性能基准参考)
- [监控与分析](#监控与分析)

---

## 存储性能指标

### 核心指标

| 指标 | 说明 | 单位 |
|:---|:---|:---|
| **IOPS** | 每秒 I/O 操作数 | ops/s |
| **吞吐量** | 每秒数据传输量 | MB/s, GB/s |
| **延迟** | I/O 响应时间 | ms, μs |
| **队列深度** | 并发 I/O 请求数 | - |

### 指标关系

```
吞吐量 = IOPS × 块大小 (Block Size)

示例:
- 100K IOPS × 4KB = 400 MB/s
- 1K IOPS × 1MB = 1 GB/s
```

### I/O 模式

| 模式 | 特点 | 典型场景 |
|:---|:---|:---|
| 顺序读 | 连续地址读取 | 视频播放、备份 |
| 顺序写 | 连续地址写入 | 日志、流媒体 |
| 随机读 | 分散地址读取 | 数据库查询 |
| 随机写 | 分散地址写入 | 数据库更新 |

---

## 性能测试方法

### fio 测试

```bash
# 随机读 IOPS
fio --name=randread \
    --rw=randread \
    --bs=4k \
    --numjobs=4 \
    --iodepth=32 \
    --size=1G \
    --runtime=60 \
    --filename=/dev/sdb \
    --direct=1

# 随机写 IOPS
fio --name=randwrite \
    --rw=randwrite \
    --bs=4k \
    --numjobs=4 \
    --iodepth=32 \
    --size=1G \
    --runtime=60 \
    --filename=/dev/sdb \
    --direct=1

# 顺序读吞吐
fio --name=seqread \
    --rw=read \
    --bs=1m \
    --numjobs=1 \
    --iodepth=8 \
    --size=4G \
    --runtime=60 \
    --filename=/dev/sdb \
    --direct=1

# 混合读写
fio --name=randrw \
    --rw=randrw \
    --rwmixread=70 \
    --bs=4k \
    --numjobs=4 \
    --iodepth=32 \
    --size=1G \
    --runtime=60 \
    --filename=/dev/sdb \
    --direct=1
```

### fio 参数说明

| 参数 | 说明 |
|:---|:---|
| `--rw` | 读写模式 (read/write/randread/randwrite/randrw) |
| `--bs` | 块大小 |
| `--numjobs` | 并发作业数 |
| `--iodepth` | 队列深度 |
| `--direct` | 绕过缓存 |
| `--runtime` | 运行时间 |

### dd 简单测试

```bash
# 写测试
dd if=/dev/zero of=/test/file bs=1M count=1024 oflag=direct

# 读测试
dd if=/test/file of=/dev/null bs=1M iflag=direct
```

---

## 性能优化策略

### I/O 调度器

| 调度器 | 特点 | 推荐场景 |
|:---|:---|:---|
| none | 无调度 | NVMe SSD |
| mq-deadline | 截止时间 | 通用 |
| bfq | 公平队列 | 桌面交互 |
| kyber | 低延迟 | 高性能需求 |

```bash
# 查看调度器
cat /sys/block/sda/queue/scheduler

# 设置调度器
echo mq-deadline > /sys/block/sda/queue/scheduler
```

### 文件系统优化

```bash
# XFS 挂载优化
mount -o noatime,nodiratime,logbufs=8,logbsize=256k /dev/sdb1 /data

# ext4 挂载优化  
mount -o noatime,nodiratime,data=writeback /dev/sdb1 /data
```

### 队列深度调整

```bash
# 查看队列深度
cat /sys/block/sda/queue/nr_requests

# 调整队列深度
echo 256 > /sys/block/sda/queue/nr_requests
```

---

## 性能基准参考

### 存储介质性能

| 类型 | 随机 IOPS | 顺序吞吐 | 延迟 |
|:---|:---:|:---:|:---:|
| NVMe SSD | 100K-1M | 3-7 GB/s | <100μs |
| SATA SSD | 20K-100K | 500-600 MB/s | <500μs |
| SAS 15K HDD | 150-200 | 200 MB/s | 3-5ms |
| SATA 7.2K HDD | 50-100 | 150 MB/s | 8-15ms |

### 云存储参考

| 云厂商 | 类型 | 最大 IOPS | 最大吞吐 |
|:---|:---|:---:|:---:|
| AWS | gp3 | 16,000 | 1,000 MB/s |
| AWS | io2 | 256,000 | 4,000 MB/s |
| Azure | Premium SSD v2 | 80,000 | 1,200 MB/s |
| GCP | pd-ssd | 100,000 | 2,400 MB/s |

### 应用参考

| 场景 | IOPS 需求 | 延迟需求 |
|:---|:---|:---|
| 数据库 (OLTP) | 10K-100K | <5ms |
| 虚拟化 | 5K-50K | <10ms |
| 文件服务器 | 1K-10K | <20ms |
| 备份存储 | 吞吐优先 | 可接受较高 |

---

## 监控与分析

### 实时监控

```bash
# iostat
iostat -xz 1

# 关注字段
# r/s, w/s: IOPS
# rMB/s, wMB/s: 吞吐
# await: 延迟
# %util: 利用率

# iotop
iotop -oP

# dstat
dstat -d --disk-util
```

### 性能分析

```bash
# blktrace 追踪
blktrace -d /dev/sdb -o trace
blkparse -i trace.blktrace.* -o trace.txt

# 查看队列统计
cat /sys/block/sda/stat
```

### 监控告警指标

| 指标 | 警告阈值 | 严重阈值 |
|:---|:---:|:---:|
| await | > 20ms | > 100ms |
| %util | > 80% | > 95% |
| avgqu-sz | > 10 | > 50 |

---

## 相关文档

- [230-storage-technologies-overview](./230-storage-technologies-overview.md) - 存储技术概述
- [215-linux-performance-tuning](./215-linux-performance-tuning.md) - Linux 性能调优
- [214-linux-storage-management](./214-linux-storage-management.md) - Linux 存储管理
