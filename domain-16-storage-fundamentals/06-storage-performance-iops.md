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

### 企业级性能基准参考

#### 不同存储介质性能对比

| 存储类型 | 随机 IOPS | 顺序吞吐 | 延迟 | 典型应用场景 |
|:---|:---:|:---:|:---:|:---|
| **NVMe SSD (企业级)** | 500K-1M | 6-8 GB/s | <50μs | 数据库、虚拟化 |
| **SATA SSD (企业级)** | 80K-150K | 500-600 MB/s | <200μs | 通用应用 |
| **SAS 15K HDD** | 150-200 | 150-200 MB/s | 3-5ms | 归档、备份 |
| **SATA 7.2K HDD** | 70-120 | 100-150 MB/s | 8-15ms | 冷数据存储 |

#### 云存储性能基准

| 云厂商 | 存储类型 | 最大 IOPS | 最大吞吐 | 典型延迟 |
|:---|:---|:---:|:---:|:---:|
| **AWS** | io2 Block Express | 256K | 4,000 MB/s | <1ms |
| **AWS** | gp3 | 16K | 1,000 MB/s | 1-3ms |
| **Azure** | Premium SSD v2 | 160K | 1,200 MB/s | <1ms |
| **GCP** | pd-ssd | 100K | 1,200 MB/s | 0.4ms |
| **阿里云** | ESSD PL-X | 100K | 4,000 MB/s | <0.1ms |

#### 应用场景性能需求

| 应用类型 | IOPS需求 | 延迟要求 | 吞吐要求 | 推荐存储 |
|:---|:---:|:---:|:---:|:---|
| **OLTP数据库** | 10K-100K | <5ms | 100-500 MB/s | NVMe SSD |
| **OLAP分析** | 1K-10K | <20ms | 500MB-2GB/s | SATA SSD |
| **虚拟桌面** | 5K-20K | <10ms | 200-800 MB/s | SAS SSD |
| **Web应用** | 1K-5K | <50ms | 100-300 MB/s | SATA SSD |
| **文件服务器** | 500-2K | <100ms | 50-200 MB/s | SAS HDD |
| **备份归档** | 吞吐优先 | 可接受较高 | 100MB-1GB/s | SATA HDD |

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

### 企业级性能测试套件

```bash
# 综合性能测试脚本
cat > /usr/local/bin/storage-benchmark.sh << 'EOF'
#!/bin/bash

STORAGE_BENCHMARK() {
    local device=$1
    local result_dir="/var/log/benchmark/$(date +%Y%m%d)"
    mkdir -p $result_dir
    
    echo "=== 存储性能基准测试 ==="
    echo "测试设备: $device"
    echo "测试时间: $(date)"
    
    # 1. 基础信息收集
    echo "1. 设备信息收集:"
    smartctl -i $device > $result_dir/device_info.txt
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT $device > $result_dir/lsblk_info.txt
    
    # 2. 4K随机读写测试
    echo "2. 4K随机读写测试:"
    fio --name=randrw_4k \
        --rw=randrw --rwmixread=70 \
        --bs=4k --numjobs=4 --iodepth=32 \
        --size=2G --runtime=120 --time_based \
        --filename=$device --direct=1 \
        --output-format=json \
        --output=$result_dir/fio_randrw_4k.json
    
    # 3. 顺序读写测试
    echo "3. 顺序读写测试:"
    fio --name=seq_rw \
        --rw=readwrite --rwmixread=50 \
        --bs=1m --numjobs=2 --iodepth=8 \
        --size=4G --runtime=120 --time_based \
        --filename=$device --direct=1 \
        --output-format=json \
        --output=$result_dir/fio_seq_rw.json
    
    # 4. 不同块大小测试
    echo "4. 块大小性能对比:"
    for bs in 512 4k 64k 1m; do
        fio --name=bs_test_${bs} \
            --rw=randread \
            --bs=$bs --numjobs=4 --iodepth=16 \
            --size=1G --runtime=60 \
            --filename=$device --direct=1 \
            --output-format=normal \
            --output=$result_dir/fio_bs_${bs}.txt
    done
    
    # 5. 生成报告
    echo "5. 生成测试报告:"
    cat > $result_dir/report.txt << REPORT_END
存储性能基准测试报告
====================
测试设备: $device
测试时间: $(date)
测试结果摘要:
$(grep -A 5 "read.*IOPS\|write.*IOPS" $result_dir/fio_randrw_4k.json)
REPORT_END

    echo "测试完成，结果保存在: $result_dir"
}

# 执行测试
STORAGE_BENCHMARK /dev/sdb
EOF

chmod +x /usr/local/bin/storage-benchmark.sh
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

# 文件系统创建优化
mkfs.xfs -f -d agcount=32 -l size=128m /dev/sdb1
```

### 队列深度调整

```bash
# 查看队列深度
cat /sys/block/sda/queue/nr_requests

# 调整队列深度
echo 256 > /sys/block/sda/queue/nr_requests
```

### 企业级性能调优实践

#### 系统层面优化

```bash
# 内核参数调优
cat >> /etc/sysctl.conf << EOF
# 存储性能优化
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.swappiness = 1
vm.vfs_cache_pressure = 50

# 网络存储优化
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
EOF

# 应用优化参数
cat >> /etc/security/limits.conf << EOF
# 存储I/O优化
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
EOF
```

#### 应用层面优化

```bash
# 数据库存储优化示例
cat > /etc/systemd/system/mysql.service.d/storage-optimization.conf << EOF
[Service]
# 存储相关优化
Environment="MYSQLD_OPTS=--innodb-flush-method=O_DIRECT --innodb-io-capacity=2000"
LimitNOFILE=65536
IOSchedulingClass=best-effort
IOSchedulingPriority=0
EOF

# 虚拟化存储优化
cat > /etc/libvirt/qemu.conf << EOF
# 存储性能优化
hugetlbfs_mount = "/dev/hugepages"
clear_emulator_capabilities = 0
EOF
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

### 企业级性能优化案例

#### 数据库场景优化

```sql
-- MySQL存储优化配置
[mysqld]
# InnoDB存储引擎优化
innodb_flush_method = O_DIRECT
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000
innodb_flush_neighbors = 0
innodb_log_file_size = 2G
innodb_buffer_pool_size = 8G

# 存储相关参数
bulk_insert_buffer_size = 256M
sort_buffer_size = 32M
read_rnd_buffer_size = 16M
```

#### 虚拟化平台优化

```xml
<!-- KVM虚拟机存储优化 -->
<domain type='kvm'>
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none' io='native'/>
      <source file='/var/lib/libvirt/images/vm.qcow2'/>
      <target dev='vda' bus='virtio'/>
      <iotune>
        <total_iops_sec>5000</total_iops_sec>
        <total_bytes_sec>52428800</total_bytes_sec>
      </iotune>
    </disk>
  </devices>
</domain>
```

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

### 企业级监控解决方案

#### Prometheus监控配置

```yaml
# 存储性能监控规则
groups:
- name: storage-performance.rules
  rules:
  # I/O延迟监控
  - alert: HighDiskLatency
    expr: rate(node_disk_read_time_seconds_total[1m]) / rate(node_disk_reads_completed_total[1m]) > 0.05
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "磁盘读延迟过高 ({{ $labels.device }})"
      description: "平均读延迟 {{ $value }}s 超过阈值"

  # I/O利用率监控
  - alert: HighDiskUtilization
    expr: rate(node_disk_io_time_seconds_total[1m]) > 0.9
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "磁盘利用率过高 ({{ $labels.device }})"
      description: "利用率 {{ $value }}% 超过阈值"

  # IOPS异常监控
  - alert: AbnormalIOPS
    expr: rate(node_disk_reads_completed_total[1m]) + rate(node_disk_writes_completed_total[1m]) > 10000
    for: 1m
    labels:
      severity: info
    annotations:
      summary: "IOPS异常 ({{ $labels.device }})"
      description: "当前IOPS {{ $value }} 超过基线"
```

#### Grafana仪表板配置

```json
{
  "dashboard": {
    "title": "存储性能监控",
    "panels": [
      {
        "title": "IOPS趋势",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(node_disk_reads_completed_total[1m])",
            "legendFormat": "读IOPS - {{device}}"
          },
          {
            "expr": "rate(node_disk_writes_completed_total[1m])",
            "legendFormat": "写IOPS - {{device}}"
          }
        ]
      },
      {
        "title": "延迟分析",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(node_disk_read_time_seconds_total[1m]) / rate(node_disk_reads_completed_total[1m]) * 1000",
            "legendFormat": "读延迟(ms) - {{device}}"
          },
          {
            "expr": "rate(node_disk_write_time_seconds_total[1m]) / rate(node_disk_writes_completed_total[1m]) * 1000",
            "legendFormat": "写延迟(ms) - {{device}}"
          }
        ]
      }
    ]
  }
}
```

#### 自动化性能分析脚本

```bash
# 存储性能分析工具
cat > /usr/local/bin/storage-analyzer.sh << 'EOF'
#!/bin/bash

STORAGE_ANALYZER() {
    local device=${1:-"/dev/sda"}
    local duration=${2:-60}
    
    echo "=== 存储性能分析报告 ==="
    echo "分析设备: $device"
    echo "分析时长: ${duration}秒"
    echo "开始时间: $(date)"
    
    # 1. 基线性能采集
    echo "1. 采集基线性能数据..."
    iostat -x $device $duration 1 > /tmp/iostat_baseline.txt &
    PID=$!
    
    # 2. 同时运行负载测试
    echo "2. 运行负载测试..."
    fio --name=analyze_test \
        --rw=randrw --rwmixread=70 \
        --bs=4k --numjobs=4 --iodepth=16 \
        --size=1G --runtime=$duration --time_based \
        --filename=$device --direct=1 \
        --output=/tmp/fio_results.json > /dev/null 2>&1 &
    
    wait $PID
    
    # 3. 分析结果
    echo "3. 性能分析结果:"
    
    # 提取关键指标
    local avg_iops=$(grep "await" /tmp/iostat_baseline.txt | tail -1 | awk '{print $4+$5}')
    local avg_lat=$(grep "await" /tmp/iostat_baseline.txt | tail -1 | awk '{print $10}')
    local util_pct=$(grep "%util" /tmp/iostat_baseline.txt | tail -1 | awk '{print $14}')
    
    echo "平均IOPS: $avg_iops"
    echo "平均延迟: ${avg_lat}ms"
    echo "利用率: ${util_pct}%"
    
    # 4. 性能评估
    echo "4. 性能评估:"
    if (( $(echo "$avg_lat > 20" | bc -l) )); then
        echo "⚠ 延迟偏高，建议优化"
    fi
    
    if (( $(echo "$util_pct > 80" | bc -l) )); then
        echo "⚠ 利用率过高，可能存在瓶颈"
    fi
    
    # 5. 生成建议
    echo "5. 优化建议:"
    if (( $(echo "$avg_iops < 1000" | bc -l) )); then
        echo "- 考虑升级存储介质"
    fi
    
    if [ "$util_pct" -gt 90 ]; then
        echo "- 考虑增加存储资源或优化应用I/O模式"
    fi
}

# 执行分析
STORAGE_ANALYZER /dev/sdb 120
EOF

chmod +x /usr/local/bin/storage-analyzer.sh
```

---

## 相关文档

- [01-storage-technologies-overview](./01-storage-technologies-overview.md) - 存储技术概述
- [215-linux-performance-tuning](./215-linux-performance-tuning.md) - Linux 性能调优
- [214-linux-storage-management](./214-linux-storage-management.md) - Linux 存储管理
