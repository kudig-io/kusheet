# 块存储、文件存储、对象存储

> **适用版本**: 通用 | **最后更新**: 2026-01

---

## 目录

- [块存储详解](#块存储详解)
- [文件存储详解](#文件存储详解)
- [对象存储详解](#对象存储详解)
- [存储融合方案](#存储融合方案)
- [访问模式对比](#访问模式对比)

---

## 块存储详解

### 块存储特点

| 特性 | 说明 |
|:---|:---|
| **数据单位** | 固定大小块 (512B-4KB) |
| **访问方式** | 块设备接口 |
| **文件系统** | 需要格式化 |
| **性能** | 最高 |
| **共享** | 通常单节点 |

### 块存储协议

| 协议 | 传输介质 | 延迟 | 场景 |
|:---|:---|:---|:---|
| SATA/SAS | 本地 | 低 | 直连存储 |
| FC | 光纤 | 很低 | 企业 SAN |
| iSCSI | 以太网 | 中等 | IP SAN |
| NVMe-oF | RDMA/TCP | 极低 | 高性能 |

### iSCSI 配置

```bash
# 目标端 (Target)
targetcli
/> backstores/block create disk0 /dev/sdb
/> iscsi/ create iqn.2026-01.com.example:target1
/> iscsi/iqn.../tpg1/luns create /backstores/block/disk0
/> iscsi/iqn.../tpg1/acls create iqn.2026-01.com.example:client1

# 发起端 (Initiator)
iscsiadm -m discovery -t sendtargets -p 192.168.1.100
iscsiadm -m node --login
lsblk  # 查看新设备
```

### 块存储场景

| 场景 | 特点 |
|:---|:---|
| 数据库 | 高 IOPS、低延迟 |
| 虚拟机 | 灵活分配 |
| 容器持久卷 | 单 Pod 挂载 |

### 企业级块存储最佳实践

#### 高可用配置

```bash
# 多路径配置 (multipath)
cat > /etc/multipath.conf << EOF
defaults {
    user_friendly_names yes
    find_multipaths yes
    polling_interval 10
}

devices {
    device {
        vendor "NETAPP"
        product "LUN"
        path_grouping_policy group_by_prio
        prio alua
        path_checker tur
        hardware_handler "1 alua"
        failback immediate
    }
}
EOF

# 启动多路径服务
systemctl enable multipathd
systemctl start multipathd
multipath -ll  # 查看多路径状态
```

#### 性能监控与告警

```bash
# 块设备性能监控脚本
cat > /usr/local/bin/block-storage-monitor.sh << 'EOF'
#!/bin/bash

BLOCK_STORAGE_ALERT() {
    local device=$1
    local threshold_iops=${2:-10000}
    local threshold_latency=${3:-20}
    
    # 获取当前性能数据
    local stats=$(iostat -x 1 2 -d $device | tail -1)
    local iops=$(echo $stats | awk '{print $4+$5}')  # r/s + w/s
    local latency=$(echo $stats | awk '{print $10}')   # await
    
    # 告警判断
    if (( $(echo "$iops > $threshold_iops" | bc -l) )); then
        logger -t STORAGE "ALERT: $device IOPS ($iops) exceeds threshold ($threshold_iops)"
        # 发送告警通知
    fi
    
    if (( $(echo "$latency > $threshold_latency" | bc -l) )); then
        logger -t STORAGE "ALERT: $device latency (${latency}ms) exceeds threshold (${threshold_latency}ms)"
        # 发送告警通知
    fi
}

# 监控所有块设备
for dev in $(lsblk -d -n -o NAME | grep -E "sd|nvme"); do
    BLOCK_STORAGE_ALERT "/dev/$dev" 5000 15
done
EOF

chmod +x /usr/local/bin/block-storage-monitor.sh
```

#### 故障排查流程

```
块存储故障诊断流程:

1. 症状识别
   ├── I/O错误 -> dmesg | grep -i error
   ├── 性能下降 -> iostat -x 1
   └── 连接中断 -> multipath -ll

2. 根因分析
   ├── 硬件故障 -> smartctl -a /dev/sdX
   ├── 网络问题 -> ping target_ip, tcpdump
   ├── 配置错误 -> cat /etc/multipath.conf
   └── 资源争用 -> iotop, pidstat

3. 解决方案
   ├── 硬件更换 -> 热插拔替换
   ├── 网络修复 -> 检查交换机、网线
   ├── 配置调整 -> 重启multipathd
   └── 负载均衡 -> 调整队列深度
```

---

## 文件存储详解

### 文件存储特点

| 特性 | 说明 |
|:---|:---|
| **数据单位** | 文件和目录 |
| **访问方式** | 文件路径 |
| **文件系统** | 服务端管理 |
| **共享** | 多节点并发 |
| **协议** | NFS, SMB |

### NFS 配置

```bash
# 服务端
# /etc/exports
/data/share 192.168.1.0/24(rw,sync,no_root_squash,fsid=0)

exportfs -ra
systemctl restart nfs-server

# 客户端
mount -t nfs 192.168.1.100:/data/share /mnt/nfs

# 永久挂载
# /etc/fstab
192.168.1.100:/data/share /mnt/nfs nfs defaults,_netdev,hard,intr 0 0
```

### NFS 版本对比

| 版本 | 特点 |
|:---|:---|
| NFSv3 | 无状态、广泛兼容 |
| NFSv4 | 状态型、安全增强 |
| NFSv4.1 | 并行 NFS、多路径 |
| NFSv4.2 | 服务端拷贝、稀疏文件 |

### 文件存储场景

| 场景 | 特点 |
|:---|:---|
| 文件共享 | 多用户访问 |
| 容器共享卷 | 多 Pod 读写 |
| 开发环境 | 代码共享 |

### 企业级文件存储运维

#### 高性能NFS配置

```bash
# NFS服务端优化配置
cat > /etc/nfs.conf << EOF
[nfsd]
threads=32
host_cache_size=1024
tcp=y
vers4=y
vers4.1=y

[exportfs]
debug=0
manage_gids=y
EOF

# 内核网络参数优化
cat >> /etc/sysctl.conf << EOF
# NFS性能优化
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 1048576 16777216
net.ipv4.tcp_wmem = 4096 1048576 16777216
EOF

# 文件系统优化
mount -o noatime,nodiratime,rsize=1048576,wsize=1048576,hard,intr \
    /dev/sdb1 /nfs/export
```

#### 监控告警体系

```yaml
# Prometheus NFS监控配置
groups:
- name: nfs.rules
  rules:
  # NFS客户端连接数监控
  - alert: NFSClientsTooMany
    expr: node_nfs_net_connections > 1000
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "NFS客户端连接数过多"
      description: "当前连接数 {{ $value }} 超过阈值"

  # NFS操作延迟监控
  - alert: NFSOperationSlow
    expr: rate(node_nfs_requests_total{method="READ"}[5m]) > 0 and 
          rate(node_nfs_duration_seconds_sum{method="READ"}[5m]) / 
          rate(node_nfs_requests_total{method="READ"}[5m]) > 0.5
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "NFS读操作延迟过高"
      description: "平均延迟 {{ $value }}s 超过阈值"

  # 存储空间监控
  - alert: NFSSpaceLow
    expr: 100 - (node_filesystem_free_bytes{mountpoint=~"/nfs/.*"} / 
                 node_filesystem_size_bytes{mountpoint=~"/nfs/.*"}) * 100 > 90
    for: 10m
    labels:
      severity: critical
    annotations:
      summary: "NFS存储空间不足"
      description: "{{ $labels.mountpoint }} 使用率 {{ $value }}%"
```

#### 故障诊断工具集

```bash
# NFS故障诊断脚本
cat > /usr/local/bin/nfs-diagnostic.sh << 'EOF'
#!/bin/bash

NFS_DIAGNOSTIC() {
    echo "=== NFS诊断报告 $(date) ==="
    
    # 1. NFS服务状态
    echo "1. NFS服务状态:"
    systemctl is-active nfs-server
    
    # 2. 导出目录检查
    echo -e "\n2. 导出目录配置:"
    exportfs -v
    
    # 3. 客户端连接统计
    echo -e "\n3. 客户端连接统计:"
    ss -tuln | grep :2049
    
    # 4. 性能统计
    echo -e "\n4. NFS统计信息:"
    nfsstat -c  # 客户端统计
    nfsstat -s  # 服务端统计
    
    # 5. 网络连通性测试
    echo -e "\n5. 网络测试:"
    for client in $(showmount -e localhost | tail -n +2 | cut -d' ' -f1); do
        ping -c 3 $client 2>&1 | head -2
    done
}

NFS_DIAGNOSTIC > /var/log/nfs-diagnostic-$(date +%Y%m%d-%H%M%S).log
EOF

chmod +x /usr/local/bin/nfs-diagnostic.sh
```

---

## 对象存储详解

### 对象存储特点

| 特性 | 说明 |
|:---|:---|
| **数据单位** | 对象 (数据+元数据) |
| **访问方式** | HTTP API |
| **地址** | 唯一 Key |
| **规模** | 海量扩展 |
| **成本** | 较低 |

### S3 API 基本操作

| 操作 | 说明 |
|:---|:---|
| PUT | 上传对象 |
| GET | 下载对象 |
| DELETE | 删除对象 |
| HEAD | 获取元数据 |
| LIST | 列出对象 |

### MinIO 部署

```bash
# 单节点
docker run -d \
  -p 9000:9000 \
  -p 9001:9001 \
  -e MINIO_ROOT_USER=admin \
  -e MINIO_ROOT_PASSWORD=password \
  -v /data/minio:/data \
  minio/minio server /data --console-address ":9001"

# 客户端使用
mc alias set myminio http://localhost:9000 admin password
mc mb myminio/mybucket
mc cp file.txt myminio/mybucket/
```

### 对象存储场景

| 场景 | 特点 |
|:---|:---|
| 备份归档 | 大容量、低成本 |
| 静态资源 | CDN 源站 |
| 大数据 | 数据湖 |
| AI/ML | 训练数据 |

### 企业级对象存储运维

#### 高可用MinIO集群部署

```yaml
# Docker Compose MinIO分布式部署
version: '3.7'

services:
  minio1:
    image: minio/minio:RELEASE.2023-10-07T15-07-38Z
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - /data/minio1:/data
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin123
    command: server http://minio{1...4}/data --console-address ":9001"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3

  minio2:
    # 类似配置...
  
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - minio1
      - minio2
      - minio3
      - minio4
```

#### 对象存储监控告警

```python
# Python对象存储健康检查脚本
cat > /usr/local/bin/object-storage-health.py << 'EOF'
#!/usr/bin/env python3
import boto3
import sys
from datetime import datetime

def check_s3_health(endpoint, access_key, secret_key, bucket_name):
    """检查S3兼容存储健康状态"""
    try:
        # 创建S3客户端
        s3 = boto3.client(
            's3',
            endpoint_url=endpoint,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            region_name='us-east-1'
        )
        
        # 检查桶是否存在
        s3.head_bucket(Bucket=bucket_name)
        
        # 测试上传下载
        test_key = f"health-check-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        test_data = b"health check data"
        
        # 上传测试
        s3.put_object(Bucket=bucket_name, Key=test_key, Body=test_data)
        
        # 下载验证
        response = s3.get_object(Bucket=bucket_name, Key=test_key)
        downloaded_data = response['Body'].read()
        
        # 清理测试对象
        s3.delete_object(Bucket=bucket_name, Key=test_key)
        
        if downloaded_data == test_data:
            print("OK: Object storage health check passed")
            return True
        else:
            print("ERROR: Data integrity check failed")
            return False
            
    except Exception as e:
        print(f"ERROR: Health check failed - {str(e)}")
        return False

if __name__ == "__main__":
    # 配置参数
    ENDPOINT = "http://minio.example.com:9000"
    ACCESS_KEY = "minioadmin"
    SECRET_KEY = "minioadmin123"
    BUCKET_NAME = "health-check"
    
    if check_s3_health(ENDPOINT, ACCESS_KEY, SECRET_KEY, BUCKET_NAME):
        sys.exit(0)
    else:
        sys.exit(1)
EOF

chmod +x /usr/local/bin/object-storage-health.py
```

#### 性能基准测试

```bash
# s3-benchmark工具测试
wget https://github.com/waschinski/s3-benchmark/releases/download/v1.0.0/s3-benchmark_linux_amd64
chmod +x s3-benchmark_linux_amd64

# 执行基准测试
./s3-benchmark_linux_amd64 \
  --endpoint http://minio.example.com:9000 \
  --access-key minioadmin \
  --secret-key minioadmin123 \
  --bucket test-bucket \
  --object-size 1MB \
  --num-objects 1000 \
  --concurrency 10
```

---

## 存储融合方案

### Ceph 统一存储

```
┌─────────────────────────────────────────────────────────────────┐
│                         应用访问                                 │
├─────────────┬─────────────┬─────────────┬─────────────┬─────────┤
│    RBD      │   CephFS    │     RGW     │    librados │         │
│   块存储    │   文件存储   │   对象存储   │   原生接口   │         │
├─────────────┴─────────────┴─────────────┴─────────────┴─────────┤
│                         RADOS 存储层                             │
│                     OSD    |    MON    |    MGR                 │
└─────────────────────────────────────────────────────────────────┘
```

| 组件 | 功能 |
|:---|:---|
| **RBD** | 块设备 (Kubernetes PV) |
| **CephFS** | POSIX 文件系统 |
| **RGW** | S3 兼容对象存储 |

### 存储网关

| 场景 | 方案 |
|:---|:---|
| 块→文件 | NFS 网关 |
| 文件→对象 | S3FS、Goofys |
| 对象→文件 | NFS 网关 |

---

## 访问模式对比

### 性能对比

| 类型 | 随机读写 | 顺序读写 | 元数据 |
|:---|:---:|:---:|:---:|
| 块存储 | 最高 | 最高 | N/A |
| 文件存储 | 中等 | 中等 | 中等 |
| 对象存储 | 较低 | 高 | 高开销 |

### 适用场景总结

| 需求 | 块 | 文件 | 对象 |
|:---|:---:|:---:|:---:|
| 数据库 | ✓ | - | - |
| 虚拟机 | ✓ | - | - |
| 文件共享 | - | ✓ | - |
| 多节点写入 | - | ✓ | ✓ |
| 海量小文件 | - | - | ✓ |
| 备份归档 | - | - | ✓ |
| Web 静态 | - | - | ✓ |

### 企业级存储选型决策矩阵

| 评估维度 | 权重 | 块存储 | 文件存储 | 对象存储 |
|:---|:---:|:---:|:---:|:---:|
| **性能要求** | 30% | 9 | 6 | 4 |
| **共享需求** | 20% | 3 | 9 | 8 |
| **成本控制** | 20% | 4 | 6 | 9 |
| **运维复杂度** | 15% | 6 | 7 | 8 |
| **扩展性** | 15% | 5 | 7 | 9 |
| **综合得分** | 100% | 6.1 | 6.9 | 7.3 |

**决策建议**: 根据业务场景选择最适合的存储类型，混合部署是常见做法。

---

## 相关文档

- [01-storage-technologies-overview](./01-storage-technologies-overview.md) - 存储技术概述
- [03-raid-storage-redundancy](./03-raid-storage-redundancy.md) - RAID 配置
- [70-storage-architecture](./70-storage-architecture.md) - K8s 存储架构
