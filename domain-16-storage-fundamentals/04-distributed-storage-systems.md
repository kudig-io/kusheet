# 分布式存储系统

> **适用版本**: 通用 | **最后更新**: 2026-01

---

## 目录

- [分布式存储概述](#分布式存储概述)
- [Ceph 存储系统](#ceph-存储系统)
- [MinIO 对象存储](#minio-对象存储)
- [GlusterFS 文件存储](#glusterfs-文件存储)
- [存储系统选型](#存储系统选型)

---

## 分布式存储概述

### 核心特性

| 特性 | 说明 |
|:---|:---|
| **横向扩展** | 增加节点扩展容量和性能 |
| **数据冗余** | 多副本或纠删码 |
| **故障自愈** | 自动检测和恢复 |
| **一致性** | 分布式一致性保证 |

### 数据保护策略

| 策略 | 优点 | 缺点 |
|:---|:---|:---|
| **多副本** | 简单、恢复快 | 空间效率低 |
| **纠删码** | 空间效率高 | 计算开销大 |

### 企业级分布式存储架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    负载均衡层 (HAProxy/Nginx)                    │
├─────────────────────────────────────────────────────────────────┤
│               API网关层 (认证、限流、监控)                        │
├─────────────────────────────────────────────────────────────────┤
│  对象存储API  │  块存储API  │  文件存储API  │  管理API            │
│   (S3兼容)   │   (RBD)    │  (CephFS/NFS) │  (Dashboard)        │
├─────────────────────────────────────────────────────────────────┤
│                  分布式存储引擎层 (RADOS)                         │
│         Monitor集群  │  Manager集群  │  Metadata Server         │
├─────────────────────────────────────────────────────────────────┤
│                    数据存储层                                    │
│    OSD节点1    │    OSD节点2    │    OSD节点3    │    OSD节点4    │
│  ● 存储设备    │  ● 存储设备    │  ● 存储设备    │  ● 存储设备    │
│  ● 数据分片    │  ● 数据分片    │  ● 数据分片    │  ● 数据分片    │
│  ● 副本管理    │  ● 副本管理    │  ● 副本管理    │  ● 副本管理    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Ceph 存储系统

### 架构组件

```
┌─────────────────────────────────────────────────────────────────┐
│                        客户端访问                                │
│     RBD (块)        CephFS (文件)       RGW (对象/S3)           │
├─────────────────────────────────────────────────────────────────┤
│                        RADOS 层                                  │
│          分布式对象存储 (可靠自主分布式对象存储)                   │
├─────────────────────────────────────────────────────────────────┤
│  OSD (存储)  │  MON (监控)  │  MGR (管理)  │  MDS (元数据)       │
└─────────────────────────────────────────────────────────────────┘
```

| 组件 | 功能 |
|:---|:---|
| **OSD** | 存储数据、复制、恢复 |
| **MON** | 集群状态、认证 |
| **MGR** | 监控、管理界面 |
| **MDS** | CephFS 元数据 |

### Ceph 部署 (cephadm)

```bash
# 引导集群
cephadm bootstrap --mon-ip 192.168.1.10

# 添加主机
ceph orch host add node2 192.168.1.11
ceph orch host add node3 192.168.1.12

# 部署 OSD
ceph orch apply osd --all-available-devices

# 部署服务
ceph orch apply mon 3
ceph orch apply mgr 2
ceph orch apply rgw default

# 查看状态
ceph status
ceph osd tree
```

### 企业级Ceph生产部署

#### 高可用架构配置

```yaml
# cephadm配置文件
service_specifications:
  - service_type: mon
    placement:
      count: 3
      hosts:
        - node1
        - node2  
        - node3
    spec:
      crush_locations:
        - {hostname: node1, rack: rack1}
        - {hostname: node2, rack: rack1}
        - {hostname: node3, rack: rack2}

  - service_type: mgr
    placement:
      count: 2
      hosts:
        - node1
        - node2

  - service_type: osd
    placement:
      host_pattern: '*'
    spec:
      data_devices:
        all: true
      encrypted: true
      crush_device_class: ssd

  - service_type: mds
    placement:
      count: 3
    spec:
      metadata_server_standby_count: 2
```

#### 性能调优配置

```bash
# Ceph集群性能优化
cat > /etc/ceph/ceph.conf << EOF
[global]
# 网络优化
public network = 192.168.1.0/24
cluster network = 192.168.2.0/24

# OSD优化
osd max backfills = 4
osd recovery max active = 4
osd recovery op priority = 1

# Journal优化
osd journal size = 10240

# 内存优化
osd memory target = 8G
osd memory cache size = 4G

# 文件系统优化
osd mkfs options xfs = -f -i size=2048
osd mount options xfs = noatime,inode64,logbsize=256k,logbufs=8
EOF
```

### Kubernetes CSI

```yaml
# StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-rbd
provisioner: rbd.csi.ceph.com
parameters:
  clusterID: <cluster-id>
  pool: kubernetes
  csi.storage.k8s.io/provisioner-secret-name: csi-rbd-secret
  csi.storage.k8s.io/node-stage-secret-name: csi-rbd-secret
reclaimPolicy: Delete
allowVolumeExpansion: true
```

### Ceph监控告警体系

#### Prometheus监控配置

```yaml
# Ceph监控ServiceMonitor
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ceph-cluster
  namespace: monitoring
spec:
  endpoints:
  - interval: 30s
    path: /metrics
    port: prometheus-http-metrics
  namespaceSelector:
    matchNames:
    - rook-ceph
  selector:
    matchLabels:
      app: rook-ceph-mgr
```

#### 关键告警规则

```yaml
groups:
- name: ceph.rules
  rules:
  # 集群健康状态
  - alert: CephClusterUnhealthy
    expr: ceph_health_status != 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Ceph集群状态异常"
      description: "集群健康状态码 {{ $value }}"

  # OSD故障
  - alert: CephOSDDown
    expr: ceph_osd_up == 0
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "OSD节点下线"
      description: "OSD {{ $labels.osd }} 已下线"

  # 存储空间不足
  - alert: CephStorageFull
    expr: ceph_cluster_total_used_bytes / ceph_cluster_total_bytes * 100 > 85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Ceph存储空间不足"
      description: "存储使用率 {{ $value }}% 超过阈值"

  # PG不一致
  - alert: CephPGsInactive
    expr: ceph_pg_active < ceph_pg_total
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "PG状态异常"
      description: "不活跃PG数量 {{ $value }}"
```

---

## MinIO 对象存储

### 分布式部署

```bash
# 4节点集群
docker run -d \
  --name minio1 \
  --net=host \
  -e MINIO_ROOT_USER=admin \
  -e MINIO_ROOT_PASSWORD=password \
  -v /data/minio:/data \
  minio/minio server \
  http://node{1...4}/data --console-address ":9001"
```

### 纠删码配置

```bash
# 默认 EC 配置: 数据块4 + 校验块4
# 可容忍 4 块盘故障
```

### MinIO 客户端

```bash
# 配置
mc alias set myminio http://minio.example.com:9000 admin password

# 操作
mc mb myminio/mybucket
mc cp file.txt myminio/mybucket/
mc ls myminio/mybucket/
```

### 企业级MinIO运维实践

#### 高可用部署配置

```yaml
# Docker Compose高可用部署
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
      MINIO_VOLUMES: "http://minio{1...4}/data"
      MINIO_BROWSER_REDIRECT_URL: "https://minio.example.com"
    command: server http://minio{1...4}/data --console-address ":9001"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.hostname == node1

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - minio1
      - minio2
      - minio3
      - minio4
```

#### 性能监控脚本

```python
# MinIO性能监控脚本
cat > /usr/local/bin/minio-monitor.py << 'EOF'
#!/usr/bin/env python3
import requests
import json
import sys
from datetime import datetime

def check_minio_health(endpoint, access_key, secret_key):
    """检查MinIO健康状态和性能指标"""
    try:
        # 健康检查
        health_url = f"{endpoint}/minio/health/live"
        response = requests.get(health_url, timeout=5)
        
        if response.status_code != 200:
            print(f"ERROR: MinIO健康检查失败 - 状态码 {response.status_code}")
            return False
            
        # 获取存储使用情况
        admin_url = f"{endpoint}/minio/admin/v3/info"
        headers = {
            'Authorization': f'Bearer {access_key}:{secret_key}'
        }
        
        info_response = requests.get(admin_url, headers=headers, timeout=10)
        if info_response.status_code == 200:
            info = info_response.json()
            
            # 提取关键指标
            total_space = info.get('servers', [{}])[0].get('total', 0)
            used_space = info.get('servers', [{}])[0].get('used', 0)
            usage_percent = (used_space / total_space) * 100 if total_space > 0 else 0
            
            print(f"INFO: 存储使用率 {usage_percent:.2f}%")
            
            # 告警阈值检查
            if usage_percent > 85:
                print(f"WARNING: 存储使用率过高 {usage_percent:.2f}%")
                
        return True
        
    except Exception as e:
        print(f"ERROR: 监控检查失败 - {str(e)}")
        return False

if __name__ == "__main__":
    ENDPOINT = "http://minio.example.com:9000"
    ACCESS_KEY = "minioadmin"
    SECRET_KEY = "minioadmin123"
    
    if check_minio_health(ENDPOINT, ACCESS_KEY, SECRET_KEY):
        sys.exit(0)
    else:
        sys.exit(1)
EOF

chmod +x /usr/local/bin/minio-monitor.py
```

---

## GlusterFS 文件存储

### 卷类型

| 类型 | 说明 | 最少节点 |
|:---|:---|:---:|
| Distribute | 分布式 | 1 |
| Replicate | 副本 | 2 |
| Stripe | 条带化 | 2 |
| Distributed-Replicate | 分布式副本 | 4 |

### 快速部署

```bash
# 安装
yum install glusterfs-server
systemctl start glusterd

# 添加节点
gluster peer probe node2
gluster peer probe node3

# 创建副本卷
gluster volume create vol1 replica 3 \
  node1:/data/brick1 \
  node2:/data/brick1 \
  node3:/data/brick1

# 启动
gluster volume start vol1

# 客户端挂载
mount -t glusterfs node1:/vol1 /mnt/glusterfs
```

### 企业级GlusterFS运维

#### 高可用配置

```bash
# 创建高可用卷
gluster volume create ha-vol replica 3 arbiter 1 \
  node1:/data/brick1 \
  node2:/data/brick1 \
  node3:/data/brick1

# 启用自愈功能
gluster volume set ha-vol cluster.self-heal-daemon on
gluster volume set ha-vol cluster.heal-timeout 60

# 性能优化
gluster volume set ha-vol performance.cache-size 256MB
gluster volume set ha-vol performance.write-behind-window-size 4MB
```

#### 监控告警配置

```bash
# GlusterFS监控脚本
cat > /usr/local/bin/gluster-monitor.sh << 'EOF'
#!/bin/bash

GLUSTER_MONITOR() {
    echo "=== GlusterFS监控报告 $(date) ==="
    
    # 1. 集群状态检查
    echo "1. 集群节点状态:"
    gluster peer status
    
    # 2. 卷状态检查
    echo -e "\n2. 卷状态:"
    gluster volume status
    
    # 3. 卷信息
    echo -e "\n3. 卷详细信息:"
    gluster volume info
    
    # 4. 性能统计
    echo -e "\n4. 性能统计:"
    gluster volume profile ha-vol info cumulative
    
    # 5. 磁盘使用率检查
    echo -e "\n5. 存储使用情况:"
    df -h | grep brick
    
    # 6. 告警检查
    local unhealthy_nodes=$(gluster peer status | grep -c "Peer in Cluster (Disconnected)")
    if [ $unhealthy_nodes -gt 0 ]; then
        echo "ALERT: 发现 $unhealthy_nodes 个断开连接的节点"
    fi
}

GLUSTER_MONITOR > /var/log/gluster-monitor-$(date +%Y%m%d-%H%M%S).log
EOF

chmod +x /usr/local/bin/gluster-monitor.sh
```

---

## 存储系统选型

### 对比

| 特性 | Ceph | MinIO | GlusterFS |
|:---|:---|:---|:---|
| 存储类型 | 块+文件+对象 | 对象 | 文件 |
| 复杂度 | 高 | 低 | 中 |
| 性能 | 高 | 高 | 中 |
| K8s 集成 | 成熟 | 成熟 | 一般 |

### 选型建议

| 需求 | 推荐方案 |
|:---|:---|
| 统一存储 | Ceph |
| S3 兼容对象存储 | MinIO |
| 简单文件共享 | GlusterFS/NFS |
| K8s 持久卷 | Ceph RBD/Longhorn |

### 企业级存储架构决策矩阵

| 评估维度 | 权重 | Ceph | MinIO | GlusterFS |
|:---|:---:|:---:|:---:|:---:|
| **功能完整性** | 25% | 9 | 6 | 7 |
| **运维复杂度** | 20% | 4 | 8 | 6 |
| **性能表现** | 20% | 8 | 9 | 6 |
| **成本效益** | 15% | 6 | 8 | 7 |
| **生态集成** | 20% | 8 | 7 | 5 |
| **综合得分** | 100% | 6.9 | 7.4 | 6.3 |

**决策建议**: 
- 大型企业选择Ceph获得完整存储解决方案
- 中小企业选择MinIO满足对象存储需求
- 简单文件共享场景可考虑GlusterFS

---

## 相关文档

- [01-storage-technologies-overview](./01-storage-technologies-overview.md) - 存储技术概述
- [02-block-file-object-storage](./02-block-file-object-storage.md) - 存储类型详解
- [70-storage-architecture](./70-storage-architecture.md) - K8s 存储架构
