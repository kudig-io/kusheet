# Linux 存储管理

> **适用版本**: Linux Kernel 5.x/6.x | **最后更新**: 2026-01

---

## 目录

- [块设备与分区](#块设备与分区)
- [LVM 逻辑卷管理](#lvm-逻辑卷管理)
- [软件 RAID](#软件-raid)
- [I/O 调度器](#io-调度器)
- [存储性能分析](#存储性能分析)
- [磁盘配额](#磁盘配额)

---

## 块设备与分区

### 块设备概述

| 设备类型 | 命名 | 说明 |
|:---|:---|:---|
| SATA/SAS | /dev/sd[a-z] | 传统硬盘 |
| NVMe | /dev/nvme[0-9]n[1-9] | NVMe SSD |
| 虚拟磁盘 | /dev/vd[a-z] | virtio 磁盘 |
| 设备映射 | /dev/dm-[0-9] | LVM/LUKS |

### 查看块设备

```bash
# 列出块设备
lsblk
lsblk -f    # 显示文件系统

# 详细信息
blkid

# 磁盘信息
fdisk -l
```

### 分区操作

```bash
# GPT 分区 (推荐)
gdisk /dev/sdb
# n - 新建分区
# w - 写入保存

# parted
parted /dev/sdb
(parted) mklabel gpt
(parted) mkpart primary xfs 0% 100%
```

---

## LVM 逻辑卷管理

### LVM 架构

```
┌─────────────────────────────────────────────────────────────────┐
│  Logical Volume (LV)          逻辑卷: 文件系统挂载              │
│     /dev/vg01/lv_data                                           │
├─────────────────────────────────────────────────────────────────┤
│  Volume Group (VG)            卷组: 存储池                       │
│     vg01                                                        │
├─────────────────────────────────────────────────────────────────┤
│  Physical Volume (PV)         物理卷: 磁盘/分区                  │
│     /dev/sdb1    /dev/sdc1    /dev/sdd1                        │
└─────────────────────────────────────────────────────────────────┘
```

### LVM 操作

```bash
# 创建物理卷
pvcreate /dev/sdb1 /dev/sdc1

# 查看物理卷
pvs
pvdisplay

# 创建卷组
vgcreate vg01 /dev/sdb1 /dev/sdc1

# 查看卷组
vgs
vgdisplay

# 创建逻辑卷
lvcreate -L 100G -n lv_data vg01
lvcreate -l 100%FREE -n lv_data vg01   # 使用全部空间

# 查看逻辑卷
lvs
lvdisplay

# 格式化并挂载
mkfs.xfs /dev/vg01/lv_data
mount /dev/vg01/lv_data /data
```

### LVM 扩展

```bash
# 扩展 VG (添加新磁盘)
pvcreate /dev/sdd1
vgextend vg01 /dev/sdd1

# 扩展 LV
lvextend -L +50G /dev/vg01/lv_data
lvextend -l +100%FREE /dev/vg01/lv_data

# 扩展文件系统
# ext4
resize2fs /dev/vg01/lv_data

# xfs
xfs_growfs /data
```

### LVM 快照

```bash
# 创建快照
lvcreate -L 10G -s -n lv_data_snap /dev/vg01/lv_data

# 挂载快照
mount /dev/vg01/lv_data_snap /mnt/snapshot

# 合并/恢复快照
lvconvert --merge /dev/vg01/lv_data_snap

# 删除快照
lvremove /dev/vg01/lv_data_snap
```

---

## 软件 RAID

### RAID 级别

| 级别 | 最少磁盘 | 容量利用 | 特点 |
|:---|:---:|:---:|:---|
| RAID 0 | 2 | 100% | 条带化，无冗余 |
| RAID 1 | 2 | 50% | 镜像 |
| RAID 5 | 3 | (n-1)/n | 分布式校验 |
| RAID 6 | 4 | (n-2)/n | 双校验 |
| RAID 10 | 4 | 50% | 镜像+条带 |

### mdadm 操作

```bash
# 创建 RAID 1
mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb1 /dev/sdc1

# 创建 RAID 5
mdadm --create /dev/md0 --level=5 --raid-devices=3 /dev/sdb1 /dev/sdc1 /dev/sdd1

# 查看状态
cat /proc/mdstat
mdadm --detail /dev/md0

# 保存配置
mdadm --detail --scan >> /etc/mdadm.conf
```

### RAID 管理

```bash
# 添加磁盘
mdadm --add /dev/md0 /dev/sde1

# 标记故障
mdadm --fail /dev/md0 /dev/sdc1

# 移除磁盘
mdadm --remove /dev/md0 /dev/sdc1

# 停止 RAID
mdadm --stop /dev/md0

# 重新组装
mdadm --assemble /dev/md0 /dev/sdb1 /dev/sdc1
```

---

## I/O 调度器

### 调度器类型

| 调度器 | 特点 | 适用场景 |
|:---|:---|:---|
| **none** | 无调度 | NVMe SSD |
| **mq-deadline** | 截止时间 | 通用 |
| **bfq** | 公平队列 | 桌面交互 |
| **kyber** | 低延迟 | 高性能 |

### 配置调度器

```bash
# 查看当前调度器
cat /sys/block/sda/queue/scheduler

# 临时修改
echo mq-deadline > /sys/block/sda/queue/scheduler

# 永久配置 (GRUB)
# GRUB_CMDLINE_LINUX="elevator=mq-deadline"
```

---

## 存储性能分析

### I/O 监控

```bash
# iostat
iostat -xz 1

# iotop
iotop -oP

# dstat
dstat -d
```

### iostat 字段

| 字段 | 说明 |
|:---|:---|
| r/s | 每秒读请求 |
| w/s | 每秒写请求 |
| rMB/s | 读吞吐 |
| wMB/s | 写吞吐 |
| await | 平均等待 (ms) |
| %util | 磁盘利用率 |

### 性能测试

```bash
# fio 测试
fio --name=test --rw=randread --bs=4k --numjobs=4 \
    --size=1G --runtime=60 --filename=/dev/sdb

# dd 简单测试
dd if=/dev/zero of=/test bs=1M count=1024 oflag=direct
dd if=/test of=/dev/null bs=1M iflag=direct
```

---

## 磁盘配额

### 启用配额

```bash
# 挂载选项
mount -o usrquota,grpquota /dev/sdb1 /data

# /etc/fstab
/dev/sdb1  /data  xfs  defaults,usrquota,grpquota  0  2

# 初始化 (ext4)
quotacheck -cug /data
quotaon /data
```

### 配置配额

```bash
# 编辑用户配额
edquota -u username

# 批量设置
setquota -u username 1000000 1500000 0 0 /data
# 参数: 用户 软块 硬块 软inode 硬inode 路径

# 查看配额
quota -u username
repquota /data
```

---

## 相关文档

- [212-linux-filesystem-deep-dive](./212-linux-filesystem-deep-dive.md) - 文件系统
- [232-raid-storage-redundancy](./232-raid-storage-redundancy.md) - RAID 详解
- [230-storage-technologies-overview](./230-storage-technologies-overview.md) - 存储技术概述
