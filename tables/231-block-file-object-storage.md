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
/data/share 192.168.1.0/24(rw,sync,no_root_squash)

exportfs -ra
systemctl restart nfs-server

# 客户端
mount -t nfs 192.168.1.100:/data/share /mnt/nfs

# 永久挂载
# /etc/fstab
192.168.1.100:/data/share /mnt/nfs nfs defaults 0 0
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

---

## 相关文档

- [230-storage-technologies-overview](./230-storage-technologies-overview.md) - 存储技术概述
- [232-raid-storage-redundancy](./232-raid-storage-redundancy.md) - RAID 配置
- [70-storage-architecture](./70-storage-architecture.md) - K8s 存储架构
