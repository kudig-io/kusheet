# RAID 与存储冗余

> **适用版本**: 通用 | **最后更新**: 2026-01

---

## 目录

- [RAID 概述](#raid-概述)
- [RAID 级别详解](#raid-级别详解)
- [RAID 配置实践](#raid-配置实践)
- [RAID 监控与维护](#raid-监控与维护)
- [硬件 vs 软件 RAID](#硬件-vs-软件-raid)

---

## RAID 概述

### RAID 目标

| 目标 | 说明 |
|:---|:---|
| **性能** | 条带化提升吞吐 |
| **冗余** | 镜像或校验保护数据 |
| **容量** | 多磁盘聚合 |

### RAID 类型

| 类型 | 说明 |
|:---|:---|
| 硬件 RAID | RAID 卡控制、独立缓存 |
| 软件 RAID | 操作系统控制、消耗 CPU |
| 混合 RAID | HBA + 软件 RAID |

---

## RAID 级别详解

### RAID 级别对比

| 级别 | 最少盘 | 容量利用 | 容错 | 读性能 | 写性能 |
|:---|:---:|:---:|:---:|:---:|:---:|
| RAID 0 | 2 | 100% | 无 | 高 | 高 |
| RAID 1 | 2 | 50% | 1盘 | 高 | 中 |
| RAID 5 | 3 | (n-1)/n | 1盘 | 高 | 中 |
| RAID 6 | 4 | (n-2)/n | 2盘 | 高 | 低 |
| RAID 10 | 4 | 50% | 每组1盘 | 最高 | 高 |

### RAID 0 (条带化)

```
┌─────────┐ ┌─────────┐
│  Disk 0 │ │  Disk 1 │
├─────────┤ ├─────────┤
│ Block 0 │ │ Block 1 │
│ Block 2 │ │ Block 3 │
│ Block 4 │ │ Block 5 │
└─────────┘ └─────────┘
```

- **优点**: 性能最高、容量100%
- **缺点**: 无冗余、任一盘故障数据丢失
- **场景**: 临时数据、性能测试

### RAID 1 (镜像)

```
┌─────────┐ ┌─────────┐
│  Disk 0 │ │  Disk 1 │
├─────────┤ ├─────────┤
│ Block 0 │ │ Block 0 │
│ Block 1 │ │ Block 1 │
│ Block 2 │ │ Block 2 │
└─────────┘ └─────────┘
```

- **优点**: 简单、读性能好、高冗余
- **缺点**: 容量利用率50%
- **场景**: 系统盘、小规模关键数据

### RAID 5 (分布式校验)

```
┌─────────┐ ┌─────────┐ ┌─────────┐
│  Disk 0 │ │  Disk 1 │ │  Disk 2 │
├─────────┤ ├─────────┤ ├─────────┤
│ Block 0 │ │ Block 1 │ │ Parity  │
│ Block 2 │ │ Parity  │ │ Block 3 │
│ Parity  │ │ Block 4 │ │ Block 5 │
└─────────┘ └─────────┘ └─────────┘
```

- **优点**: 容量利用率高、容忍1盘故障
- **缺点**: 写惩罚、重建慢
- **场景**: 通用存储

### RAID 6 (双重校验)

- **优点**: 容忍2盘故障
- **缺点**: 写性能更低
- **场景**: 大容量、高可靠需求

### RAID 10 (1+0)

```
     ┌───────────────────────┐
     │      RAID 0 条带      │
     └───────┬───────┬───────┘
             │       │
     ┌───────┴──┐ ┌──┴───────┐
     │ RAID 1   │ │ RAID 1   │
     ├─────┬────┤ ├────┬─────┤
     │Disk0│Disk1│ │Disk2│Disk3│
     └─────┴────┘ └────┴─────┘
```

- **优点**: 高性能、高可靠
- **缺点**: 容量利用率50%
- **场景**: 数据库、高性能需求

---

## RAID 配置实践

### 软件 RAID (mdadm)

```bash
# 创建 RAID 1
mdadm --create /dev/md0 --level=1 \
  --raid-devices=2 /dev/sdb1 /dev/sdc1

# 创建 RAID 5
mdadm --create /dev/md0 --level=5 \
  --raid-devices=3 /dev/sdb1 /dev/sdc1 /dev/sdd1

# 创建 RAID 10
mdadm --create /dev/md0 --level=10 \
  --raid-devices=4 /dev/sdb1 /dev/sdc1 /dev/sdd1 /dev/sde1

# 保存配置
mdadm --detail --scan >> /etc/mdadm.conf

# 查看状态
cat /proc/mdstat
mdadm --detail /dev/md0
```

### 格式化使用

```bash
# 格式化
mkfs.xfs /dev/md0

# 挂载
mount /dev/md0 /data

# /etc/fstab
/dev/md0 /data xfs defaults 0 0
```

---

## RAID 监控与维护

### 状态监控

```bash
# 查看状态
cat /proc/mdstat
mdadm --detail /dev/md0

# 邮件告警
# /etc/mdadm.conf
MAILADDR admin@example.com

# 启动监控
mdadm --monitor --scan --daemonise
```

### 磁盘故障处理

```bash
# 标记故障
mdadm --fail /dev/md0 /dev/sdc1

# 移除磁盘
mdadm --remove /dev/md0 /dev/sdc1

# 添加新盘
mdadm --add /dev/md0 /dev/sdf1

# 查看重建进度
cat /proc/mdstat
```

### 热备盘

```bash
# 创建时添加热备
mdadm --create /dev/md0 --level=5 \
  --raid-devices=3 --spare-devices=1 \
  /dev/sdb1 /dev/sdc1 /dev/sdd1 /dev/sde1

# 后续添加热备
mdadm --add /dev/md0 /dev/sdf1
```

---

## 硬件 vs 软件 RAID

### 对比

| 特性 | 硬件 RAID | 软件 RAID |
|:---|:---|:---|
| 性能 | 高 (专用处理器) | 中 (消耗 CPU) |
| 成本 | 高 | 低 |
| 管理 | 专用工具 | 系统命令 |
| 缓存 | 有 (含电池) | 使用系统内存 |
| 可移植性 | 依赖RAID卡 | 跨系统兼容 |

### 选择建议

| 场景 | 推荐 |
|:---|:---|
| 企业数据库 | 硬件 RAID + BBU |
| 虚拟化存储 | 硬件 RAID |
| 通用服务器 | 软件 RAID 可接受 |
| 云/分布式 | 无 RAID，应用层冗余 |

---

## 相关文档

- [230-storage-technologies-overview](./230-storage-technologies-overview.md) - 存储技术概述
- [214-linux-storage-management](./214-linux-storage-management.md) - Linux 存储管理
- [233-distributed-storage-systems](./233-distributed-storage-systems.md) - 分布式存储
