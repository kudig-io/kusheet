# 存储技术概述

> **适用版本**: 通用 | **最后更新**: 2026-01

---

## 目录

- [存储技术分类](#存储技术分类)
- [存储架构演进](#存储架构演进)
- [存储协议](#存储协议)
- [存储选型指南](#存储选型指南)
- [云存储服务](#云存储服务)
- [存储性能指标](#存储性能指标)

---

## 存储技术分类

### 存储类型

| 类型 | 说明 | 特点 | 使用场景 |
|:---|:---|:---|:---|
| **块存储** | 原始块设备 | 高性能、低延迟 | 数据库、虚拟机 |
| **文件存储** | 文件系统共享 | 易于访问、共享 | NAS、文件共享 |
| **对象存储** | 对象+元数据 | 大规模、低成本 | 备份、静态资源 |

### 访问模式对比

```
┌─────────────────────────────────────────────────────────────────┐
│  块存储 (Block)                                                  │
│  应用 → 文件系统 → 块设备驱动 → SCSI/NVMe → 存储设备             │
├─────────────────────────────────────────────────────────────────┤
│  文件存储 (File)                                                 │
│  应用 → NFS/SMB 客户端 → 网络 → NAS 服务器 → 文件系统            │
├─────────────────────────────────────────────────────────────────┤
│  对象存储 (Object)                                               │
│  应用 → HTTP/S3 API → 网络 → 对象存储服务                        │
└─────────────────────────────────────────────────────────────────┘
```

### 详细对比

| 特性 | 块存储 | 文件存储 | 对象存储 |
|:---|:---|:---|:---|
| 访问方式 | 块设备 | 文件路径 | HTTP API |
| 性能 | 最高 | 中等 | 较低 |
| 可扩展性 | 有限 | 中等 | 海量 |
| 共享访问 | 单节点 | 多节点 | 多节点 |
| 成本 | 较高 | 中等 | 较低 |
| 协议 | iSCSI, FC | NFS, SMB | S3, Swift |

---

## 存储架构演进

### DAS (直连存储)

```
┌─────────────┐
│   服务器    │
└──────┬──────┘
       │ SATA/SAS/NVMe
┌──────┴──────┐
│  本地磁盘   │
└─────────────┘
```

**特点**: 简单、高性能、不可共享

### SAN (存储区域网络)

```
┌─────────────┐     ┌─────────────┐
│   服务器 1   │     │   服务器 2   │
└──────┬──────┘     └──────┬──────┘
       │ FC/iSCSI          │
       └──────────┬────────┘
           ┌──────┴──────┐
           │  SAN 交换机  │
           └──────┬──────┘
           ┌──────┴──────┐
           │  存储阵列   │
           └─────────────┘
```

**特点**: 高性能、块级共享、专用网络

### NAS (网络附加存储)

```
┌─────────────┐     ┌─────────────┐
│   服务器 1   │     │   服务器 2   │
└──────┬──────┘     └──────┬──────┘
       │ NFS/SMB           │
       └──────────┬────────┘
           ┌──────┴──────┐
           │  IP 网络    │
           └──────┬──────┘
           ┌──────┴──────┐
           │  NAS 设备   │
           └─────────────┘
```

**特点**: 文件共享、易于管理、通用网络

### SDS (软件定义存储)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   节点 1    │     │   节点 2    │     │   节点 3    │
│ CPU+内存+磁盘│     │ CPU+内存+磁盘│     │ CPU+内存+磁盘│
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                    ┌──────┴──────┐
                    │  存储软件   │
                    │ Ceph/MinIO │
                    └─────────────┘
```

**特点**: 横向扩展、通用硬件、灵活

---

## 存储协议

### 块存储协议

| 协议 | 传输 | 特点 | 使用场景 |
|:---|:---|:---|:---|
| **FC** | 光纤 | 高性能、低延迟 | 企业级 SAN |
| **iSCSI** | TCP/IP | 成本低、灵活 | 中小规模 SAN |
| **NVMe-oF** | RDMA/TCP | 超低延迟 | 高性能需求 |
| **FCoE** | 以太网 | FC over Ethernet | 融合网络 |

### 文件存储协议

| 协议 | 平台 | 特点 |
|:---|:---|:---|
| **NFS** | Linux/Unix | 开放标准、广泛支持 |
| **SMB/CIFS** | Windows | Windows 原生 |
| **GlusterFS** | Linux | 分布式扩展 |

### 对象存储协议

| 协议 | 说明 |
|:---|:---|
| **S3** | AWS 标准、事实标准 |
| **Swift** | OpenStack 对象存储 |
| **Azure Blob** | Azure 对象存储 |
| **GCS** | Google Cloud Storage |

---

## 存储选型指南

### 按场景选择

| 场景 | 推荐类型 | 推荐方案 |
|:---|:---|:---|
| 数据库 | 块存储 | SSD、NVMe |
| 虚拟机 | 块存储 | SAN、本地 SSD |
| 文件共享 | 文件存储 | NAS/NFS |
| 备份归档 | 对象存储 | S3/MinIO |
| 容器持久化 | 块/文件 | CSI 驱动 |
| 大数据 | 对象存储 | HDFS/S3 |

### 按性能需求

| 需求 | IOPS | 延迟 | 推荐 |
|:---|:---|:---|:---|
| 极高性能 | 100K+ | <1ms | NVMe SSD |
| 高性能 | 10K-100K | 1-5ms | SSD |
| 标准 | 1K-10K | 5-20ms | SAS HDD |
| 归档 | <1K | >20ms | SATA HDD |

---

## 云存储服务

### 主要云存储

| 云厂商 | 块存储 | 文件存储 | 对象存储 |
|:---|:---|:---|:---|
| **AWS** | EBS | EFS | S3 |
| **Azure** | Disk | Files | Blob |
| **GCP** | PD | Filestore | GCS |
| **阿里云** | 云盘 | NAS | OSS |

### Kubernetes 存储

| 类型 | CSI 驱动 |
|:---|:---|
| **云盘** | AWS EBS CSI, AliDisk CSI |
| **网络文件** | EFS CSI, NFS CSI |
| **分布式** | Ceph CSI, Longhorn |
| **本地** | Local PV |

---
---
## 存储性能指标

### 核心指标

| 指标 | 说明 | 单位 |
|:---|:---|:---|
| **IOPS** | 每秒 I/O 操作数 | ops/s |
| **吞吐量** | 每秒数据传输量 | MB/s |
| **延迟** | 响应时间 | ms/μs |
| **队列深度** | 并发请求数 | - |

### 性能参考

| 存储类型 | 随机 IOPS | 顺序吞吐 | 延迟 |
|:---|:---:|:---:|:---:|
| NVMe SSD | 100K-1M | 3-7 GB/s | <100μs |
| SATA SSD | 20K-100K | 500-600 MB/s | <500μs |
| SAS HDD | 100-200 | 150-200 MB/s | 5-10ms |
| SATA HDD | 50-100 | 100-150 MB/s | 10-20ms |

### 性能测试

```bash
# fio 测试
fio --name=test --rw=randread --bs=4k --numjobs=4 \
    --size=1G --runtime=60 --filename=/dev/sdb
```

---
## 生产环境最佳实践

### 企业级存储选型指南

#### 按业务场景选型

| 业务场景 | 存储类型 | 推荐配置 | SLA要求 |
|:---|:---|:---|:---|
| **核心数据库** | 块存储(NVMe) | RAID 10 + LVM | 99.99% |
| **虚拟化平台** | 块存储(SSD) | RAID 5/6 + LVM | 99.95% |
| **文件共享** | 文件存储(NFS) | RAID 6 + XFS | 99.9% |
| **备份归档** | 对象存储(S3) | 多副本/纠删码 | 99.999% |
| **容器持久化** | 块存储(CSI) | 本地SSD + 快照 | 99.9% |

#### 高可用架构设计

```
┌─────────────────────────────────────────────────────────────────┐
│                      应用层负载均衡                               │
├─────────────────────────────────────────────────────────────────┤
│                   存储访问层(HAProxy)                            │
├─────────────────────────────────────────────────────────────────┤
│  块存储集群  │  文件存储集群  │  对象存储集群                     │
│ (Ceph RBD)  │ (CephFS/NFS)  │ (Ceph RGW/MinIO)                  │
├─────────────────────────────────────────────────────────────────┤
│                分布式存储底座(Ceph/分布式架构)                    │
│         OSD节点1    OSD节点2    OSD节点3    OSD节点4             │
└─────────────────────────────────────────────────────────────────┘
```

### 监控告警体系

#### 核心监控指标

| 组件 | 关键指标 | 告警阈值 | 告警级别 |
|:---|:---|:---:|:---:|
| **块存储** | IOPS利用率 | >80% | Warning |
| **块存储** | 延迟 | >20ms | Critical |
| **文件存储** | 连接数 | >1000 | Warning |
| **对象存储** | 请求成功率 | <99.5% | Critical |
| **RAID** | 重建进度 | <50%/hr | Warning |
| **存储池** | 使用率 | >85% | Warning |

#### Prometheus监控配置

```yaml
# 存储监控规则
groups:
- name: storage.rules
  rules:
  # 块存储监控
  - alert: BlockStorageHighLatency
    expr: node_disk_read_time_seconds_total / node_disk_reads_completed_total > 0.02
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "块存储延迟过高 ({{ $labels.device }})"
      description: "平均延迟 {{ $value }}s 超过阈值"

  # 文件系统监控
  - alert: FileSystemUsageHigh
    expr: 100 - (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 > 85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "文件系统使用率过高 ({{ $labels.mountpoint }})"
      description: "使用率达到 {{ $value }}%"

  # RAID状态监控
  - alert: RaidDegraded
    expr: node_md_disks_active < node_md_disks
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "RAID阵列降级"
      description: "{{ $labels.device }} 状态异常"
```

### 故障排查流程

#### 存储故障诊断矩阵

| 故障现象 | 可能原因 | 诊断步骤 | 解决方案 |
|:---|:---|:---|:---|
| **I/O延迟高** | 存储瓶颈/网络问题 | iostat, blktrace分析 | 优化队列深度/更换介质 |
| **空间不足** | 配额限制/碎片化 | df, du分析 | 清理无用数据/扩容 |
| **访问失败** | 权限问题/网络中断 | 检查mount状态/网络连通性 | 修复权限/恢复网络 |
| **性能下降** | 缓存失效/硬件老化 | smartctl, ioping测试 | 清理缓存/更换硬件 |

#### 标准化排障脚本

```bash
#!/bin/bash
# 存储健康检查脚本

STORAGE_HEALTH_CHECK() {
    echo "=== 存储健康检查报告 $(date) ==="
    
    # 1. 块设备状态检查
    echo "1. 块设备状态:"
    iostat -x 1 3 | grep -E "Device|sd|nvme"
    
    # 2. 文件系统使用率
    echo -e "\n2. 文件系统使用率:"
    df -h | grep -E "(sd|nvme|mapper)"
    
    # 3. RAID状态检查
    echo -e "\n3. RAID状态:"
    cat /proc/mdstat 2>/dev/null || echo "未配置软件RAID"
    
    # 4. SMART状态检查
    echo -e "\n4. 磁盘健康状态:"
    for disk in /dev/sd*; do
        [[ -b $disk ]] && smartctl -H $disk 2>/dev/null | grep "SMART overall-health"
    done
    
    # 5. I/O性能测试
    echo -e "\n5. I/O性能基准:"
    dd if=/dev/zero of=/tmp/io_test bs=1M count=100 oflag=direct 2>&1 | tail -1
    
    # 清理测试文件
    rm -f /tmp/io_test
}

# 执行检查
STORAGE_HEALTH_CHECK > /var/log/storage-health-$(date +%Y%m%d).log
```

### 性能调优策略

#### Linux系统层面优化

```bash
# 1. I/O调度器优化
echo deadline > /sys/block/sda/queue/scheduler  # 数据库场景
echo mq-deadline > /sys/block/nvme0n1/queue/scheduler  # NVMe场景

# 2. 文件系统挂载优化
mount -o noatime,nobarrier,data=ordered /dev/sdb1 /data

# 3. 内核参数调优
cat >> /etc/sysctl.conf << EOF
# 存储相关优化
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.swappiness = 1
EOF

# 4. 队列深度调整
echo 1024 > /sys/block/sda/queue/nr_requests
```

#### 应用层面优化

| 应用类型 | 优化策略 | 配置示例 |
|:---|:---|:---|
| **数据库** | 预分配空间、禁用atime | innodb_flush_method=O_DIRECT |
| **虚拟化** | 大页内存、CPU绑定 | numactl --cpunodebind=0 |
| **容器** | 本地存储、限制IOPS | --device-write-iops=/dev/sda:1000 |
| **大数据** | 顺序读写、批量操作 | hdfs dfs -D dfs.block.size=134217728 |

### 成本优化方案

#### 存储分层策略

| 层级 | 存储类型 | 成本系数 | 适用场景 |
|:---|:---|:---:|:---|
| **热数据** | NVMe SSD | 1.0 | 核心业务数据 |
| **温数据** | SATA SSD | 0.4 | 频繁访问数据 |
| **冷数据** | SAS HDD | 0.2 | 归档备份数据 |
| **冰数据** | 对象存储 | 0.05 | 长期保存数据 |

#### 自动分层实现

```bash
# LVM自动分层配置
lvcreate -L 100G -T vg_storage/thin_pool
lvcreate -V 50G -T vg_storage/thin_pool -n hot_data
lvcreate -V 200G -T vg_storage/thin_pool -n warm_data

# 结合tiered storage策略
cat > /etc/systemd/system/storage-tier.service << EOF
[Unit]
Description=Storage Tier Management
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/storage-tier.sh
EOF
```

---

## 相关文档

- [02-block-file-object-storage](./02-block-file-object-storage.md) - 存储类型详解
- [214-linux-storage-management](./214-linux-storage-management.md) - Linux 存储管理
- [70-storage-architecture](./70-storage-architecture.md) - K8s 存储架构
