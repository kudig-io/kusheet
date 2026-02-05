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

### 企业级RAID选型指南

| 应用场景 | 推荐RAID级别 | 磁盘数量 | 容量利用率 | 冗余能力 |
|:---|:---:|:---:|:---:|:---:|
| **数据库主库** | RAID 10 | 4-8 | 50% | 任意1块盘/每组1块盘 |
| **数据库从库** | RAID 5/6 | 4-6 | 75-80% | 1-2块盘 |
| **虚拟化存储** | RAID 10 | 6-8 | 50% | 高性能+高可靠性 |
| **文件服务器** | RAID 6 | 6-8 | 80% | 成本效益平衡 |
| **备份存储** | RAID 6 | 8-12 | 85% | 最大容量利用 |

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

### 企业级RAID性能基准

| RAID级别 | 随机读IOPS | 随机写IOPS | 顺序读MB/s | 顺序写MB/s | 重建时间(4TB×6盘) |
|:---|:---:|:---:|:---:|:---:|:---:|
| RAID 0 | 15,000 | 5,000 | 1,200 | 1,200 | N/A |
| RAID 1 | 12,000 | 2,500 | 800 | 400 | 2-3小时 |
| RAID 5 | 10,000 | 1,500 | 900 | 600 | 8-12小时 |
| RAID 6 | 8,000 | 1,200 | 800 | 500 | 12-18小时 |
| RAID 10 | 20,000 | 4,000 | 1,100 | 800 | 4-6小时 |

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

### 企业级RAID配置最佳实践

```bash
# 1. 磁盘分区对齐优化
parted /dev/sdb mklabel gpt
parted /dev/sdb mkpart primary 1MiB 100%

# 2. RAID创建时指定chunk size
mdadm --create /dev/md0 --level=5 \
  --raid-devices=4 --chunk=512 \
  /dev/sd{b,c,d,e}1

# 3. 文件系统优化
mkfs.xfs -f -d agcount=32 -l size=128m /dev/md0

# 4. 挂载选项优化
mount -o noatime,nobarrier,logbufs=8,logbsize=256k /dev/md0 /data
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
watch cat /proc/mdstat  # 实时监控
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

### 企业级RAID运维实践

#### 自动化监控脚本

```bash
# RAID健康检查脚本
cat > /usr/local/bin/raid-health-check.sh << 'EOF'
#!/bin/bash

RAID_HEALTH_CHECK() {
    local alert_email="admin@example.com"
    local raid_device=${1:-"/dev/md0"}
    
    echo "=== RAID健康检查报告 $(date) ==="
    
    # 1. 检查RAID状态
    local mdstat_status=$(cat /proc/mdstat | grep $(basename $raid_device))
    if [[ $mdstat_status == *"UU"* ]]; then
        echo "✓ RAID状态正常: $mdstat_status"
    else
        echo "✗ RAID状态异常: $mdstat_status"
        echo "发送告警邮件..."
        echo "RAID设备 $raid_device 状态异常: $mdstat_status" | \
            mail -s "RAID Alert" $alert_email
    fi
    
    # 2. 检查磁盘健康
    echo -e "\n磁盘SMART状态:"
    for disk in $(mdadm --detail $raid_device | grep active | awk '{print $7}'); do
        local smart_status=$(smartctl -H $disk 2>/dev/null | grep "SMART overall-health")
        echo "$disk: $smart_status"
    done
    
    # 3. 检查重建进度
    if [[ $mdstat_status == *"recovery"* ]] || [[ $mdstat_status == *"resync"* ]]; then
        local progress=$(echo $mdstat_status | grep -o '[0-9]*\.[0-9]*%')
        echo -e "\n⚠ 重建进行中: $progress"
        
        # 如果重建速度过慢，发送警告
        local speed=$(echo $mdstat_status | grep -o '[0-9]*K/sec')
        if [[ $(echo $speed | tr -d 'K/sec') -lt 1000 ]]; then
            echo "⚠ 重建速度较慢: $speed"
        fi
    fi
}

# 检查所有RAID设备
for raid_dev in $(ls /dev/md* 2>/dev/null | grep -v p); do
    RAID_HEALTH_CHECK $raid_dev
done
EOF

chmod +x /usr/local/bin/raid-health-check.sh

# 添加到crontab每小时执行
echo "0 * * * * /usr/local/bin/raid-health-check.sh" >> /etc/crontab
```

#### 性能监控与告警

```yaml
# Prometheus RAID监控规则
groups:
- name: raid.rules
  rules:
  # RAID降级告警
  - alert: RaidArrayDegraded
    expr: node_md_disks_active < node_md_disks
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "RAID阵列降级 ({{ $labels.device }})"
      description: "活动磁盘数 {{ $value }} 小于总磁盘数"

  # RAID重建监控
  - alert: RaidRebuildSlow
    expr: rate(node_md_blocks_synced[5m]) < 1000000
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "RAID重建速度缓慢"
      description: "重建速度 {{ $value }} blocks/sec 低于阈值"

  # 磁盘故障预测
  - alert: DiskFailurePredicted
    expr: node_smartctl_device_smart_healthy == 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "磁盘故障预测"
      description: "{{ $labels.device }} SMART状态异常"
```

#### 故障恢复标准操作程序(SOP)

```
RAID故障恢复SOP:

1. 故障检测阶段
   ├── 自动告警触发
   ├── 确认故障磁盘 (mdadm --detail)
   └── 记录故障时间

2. 应急响应阶段
   ├── 评估影响范围
   ├── 启动备用系统
   └── 通知相关人员

3. 故障处理阶段
   ├── 标记故障磁盘 (mdadm --fail)
   ├── 移除故障磁盘 (mdadm --remove)
   ├── 更换物理磁盘
   └── 添加新磁盘 (mdadm --add)

4. 验证恢复阶段
   ├── 监控重建进度
   ├── 验证数据完整性
   └── 性能基准测试

5. 文档记录阶段
   ├── 更新维护记录
   ├── 分析故障原因
   └── 优化预防措施
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

### 企业级RAID管理最佳实践

#### 硬件RAID配置示例

```bash
# LSI MegaRAID配置示例
# 查看控制器信息
MegaCli -AdpAllInfo -aALL

# 查看物理磁盘状态
MegaCli -PDList -aALL

# 创建RAID 10虚拟磁盘
MegaCli -CfgLdAdd -r10 [0:0,0:1,1:0,1:1] WB RA Direct -a0

# 设置热备盘
MegaCli -PDHSP -Set -PhysDrv [2:0] -a0

# 启用后台初始化
MegaCli -LDInit -Start -L0 -a0
```

#### 软件RAID优化配置

```bash
# 1. 内核参数优化
cat >> /etc/sysctl.conf << EOF
# RAID相关优化
dev.raid.speed_limit_min = 1000
dev.raid.speed_limit_max = 200000
EOF

# 2. 调整重建优先级
echo 100000 > /proc/sys/dev/raid/speed_limit_max
echo 1000 > /proc/sys/dev/raid/speed_limit_min

# 3. 启用NCQ优化
for disk in /dev/sd*; do
    if [ -b $disk ]; then
        echo 1 > /sys/block/$(basename $disk)/queue/nomerges
    fi
done
```

---

## 相关文档

- [01-storage-technologies-overview](./01-storage-technologies-overview.md) - 存储技术概述
- [214-linux-storage-management](./214-linux-storage-management.md) - Linux 存储管理
- [04-distributed-storage-systems](./04-distributed-storage-systems.md) - 分布式存储
