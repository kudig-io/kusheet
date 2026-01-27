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

---

## 相关文档

- [230-storage-technologies-overview](./230-storage-technologies-overview.md) - 存储技术概述
- [231-block-file-object-storage](./231-block-file-object-storage.md) - 存储类型详解
- [70-storage-architecture](./70-storage-architecture.md) - K8s 存储架构
