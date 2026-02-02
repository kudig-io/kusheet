# Kubernetes 存储(Storage)生产环境运维培训

> **适用版本**: Kubernetes v1.26-v1.32  
> **文档类型**: PPT演示文稿 | **目标受众**: 运维工程师、SRE、架构师  
> **内容定位**: 理论深入 + 源码级分析 + 生产实战案例

---

## 目录

1. [存储架构基础](#1-存储架构基础)
2. [CSI驱动深度解析](#2-csi驱动深度解析)
3. [PV/PVC核心机制](#3-pvpvc核心机制)
4. [StorageClass高级配置](#4-storageclass高级配置)
5. [存储性能优化](#5-存储性能优化)
6. [快照与克隆](#6-快照与克隆)
7. [监控与告警](#7-监控与告警)
8. [故障排查手册](#8-故障排查手册)
9. [数据保护与灾备](#9-数据保护与灾备)
10. [实战案例演练](#10-实战案例演练)
11. [总结与Q&A](#11-总结与qa)

---

## 1. 存储架构基础

### 1.1 Kubernetes存储架构全景

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Kubernetes 存储架构全景                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        应用层 (Application Layer)                     │   │
│  │                                                                      │   │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐        │   │
│  │  │     Pod A      │  │     Pod B      │  │     Pod C      │        │   │
│  │  │  ┌──────────┐  │  │  ┌──────────┐  │  │  ┌──────────┐  │        │   │
│  │  │  │VolumeMnt │  │  │  │VolumeMnt │  │  │  │VolumeMnt │  │        │   │
│  │  │  │ /data    │  │  │  │ /data    │  │  │  │ /data    │  │        │   │
│  │  │  └────┬─────┘  │  │  └────┬─────┘  │  │  └────┬─────┘  │        │   │
│  │  └───────┼────────┘  └───────┼────────┘  └───────┼────────┘        │   │
│  └──────────┼───────────────────┼───────────────────┼─────────────────┘   │
│             │                   │                   │                      │
│             ▼                   ▼                   ▼                      │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    抽象层 (Abstraction Layer)                         │   │
│  │                                                                      │   │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐        │   │
│  │  │      PVC       │  │      PVC       │  │      PVC       │        │   │
│  │  │ mysql-data-pvc │  │ redis-data-pvc │  │ shared-data-pvc│        │   │
│  │  │  RWO 100Gi    │  │   RWO 50Gi    │  │   RWX 200Gi   │        │   │
│  │  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘        │   │
│  │          │ 绑定              │ 绑定              │ 绑定             │   │
│  │          ▼                   ▼                   ▼                  │   │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐        │   │
│  │  │       PV       │  │       PV       │  │       PV       │        │   │
│  │  │ pv-mysql-001  │  │ pv-redis-001  │  │  pv-nas-001   │        │   │
│  │  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘        │   │
│  └──────────┼───────────────────┼───────────────────┼─────────────────┘   │
│             │                   │                   │                      │
│             ▼                   ▼                   ▼                      │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    供给层 (Provisioning Layer)                        │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │                    StorageClass                               │   │   │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │   │   │
│  │  │  │ fast-ssd     │  │ standard     │  │ shared-nas   │       │   │   │
│  │  │  │ (ESSD PL1)  │  │ (云盘高效)   │  │ (NAS标准)    │       │   │   │
│  │  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │   │   │
│  │  └─────────┼─────────────────┼─────────────────┼────────────────┘   │   │
│  │            │                 │                 │                     │   │
│  │            ▼                 ▼                 ▼                     │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │                    CSI Driver                                 │   │   │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │   │   │
│  │  │  │disk.csi.xxx  │  │disk.csi.xxx  │  │ nas.csi.xxx  │       │   │   │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘       │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                      │
│                                      ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    后端存储 (Backend Storage)                         │   │
│  │                                                                      │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│  │  │  云盘/SSD    │  │   NAS/NFS   │  │  对象存储    │              │   │
│  │  │  Block       │  │  FileSystem │  │   S3/OSS    │              │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 存储类型对比矩阵

| 存储类型 | 访问模式 | 性能特点 | 典型IOPS | 适用场景 | 成本 |
|---------|---------|---------|---------|---------|------|
| **本地存储(Local)** | RWO | 最高性能 | 100K+ | 高性能数据库、缓存 | 低 |
| **块存储(Block)** | RWO | 高性能 | 1K-100K | 数据库、单实例应用 | 中 |
| **文件存储(NFS/NAS)** | RWX | 中等性能 | 1K-10K | 共享文件、CMS | 中高 |
| **对象存储(S3/OSS)** | N/A | 高吞吐 | N/A | 大文件、归档、备份 | 低 |

### 1.3 访问模式详解

| 访问模式 | 缩写 | 说明 | 支持的存储类型 |
|---------|------|------|---------------|
| **ReadWriteOnce** | RWO | 单节点读写 | 块存储、本地存储 |
| **ReadOnlyMany** | ROX | 多节点只读 | 块存储、文件存储、对象存储 |
| **ReadWriteMany** | RWX | 多节点读写 | 文件存储(NFS/NAS) |
| **ReadWriteOncePod** | RWOP | 单Pod独占(v1.22+) | 块存储(需CSI支持) |

### 1.4 存储版本演进

| Kubernetes版本 | 存储特性 | 说明 |
|---------------|---------|------|
| **v1.26** | CSI卷健康监控GA | 自动检测卷健康状态 |
| **v1.27** | 卷组快照Alpha | 多卷一致性快照 |
| **v1.28** | VolumeAttributesClass Alpha | 动态修改卷属性 |
| **v1.29** | SELinux卷挂载优化 | 改进安全上下文处理 |
| **v1.30** | 卷填充器GA | 预填充数据源支持 |
| **v1.31** | VolumeAttributesClass Beta | 生产就绪 |
| **v1.32** | 存储容量跟踪增强 | 更精确的容量管理 |

---

## 2. CSI驱动深度解析

### 2.1 CSI架构原理

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CSI (Container Storage Interface) 架构                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Kubernetes Control Plane                          │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │  外部组件 (External Components)                                │   │   │
│  │  │                                                               │   │   │
│  │  │  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐  │   │   │
│  │  │  │ csi-provisioner │  │ csi-attacher    │  │csi-resizer   │  │   │   │
│  │  │  │                 │  │                 │  │              │  │   │   │
│  │  │  │ 监听PVC创建     │  │ 监听VolumeAtt   │  │监听PVC扩容   │  │   │   │
│  │  │  │ 调用CreateVol   │  │ 调用Attach      │  │调用ExpandVol │  │   │   │
│  │  │  └────────┬────────┘  └────────┬────────┘  └──────┬───────┘  │   │   │
│  │  │           │                    │                  │          │   │   │
│  │  │  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐  │   │   │
│  │  │  │ csi-snapshotter │  │ csi-liveness    │  │csi-node-driv │  │   │   │
│  │  │  │                 │  │                 │  │er-registrar  │  │   │   │
│  │  │  │ 监听VolumeSnap  │  │ 健康检查        │  │节点CSI注册   │  │   │   │
│  │  │  │ 调用CreateSnap  │  │ Liveness探针    │  │              │  │   │   │
│  │  │  └────────┬────────┘  └────────┬────────┘  └──────┬───────┘  │   │   │
│  │  └───────────┼────────────────────┼──────────────────┼──────────┘   │   │
│  └──────────────┼────────────────────┼──────────────────┼──────────────┘   │
│                 │                    │                  │                   │
│                 │    gRPC调用        │    gRPC调用      │                   │
│                 ▼                    ▼                  ▼                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    CSI Driver                                        │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │                    Controller Service                         │   │   │
│  │  │                                                               │   │   │
│  │  │  CreateVolume()    DeleteVolume()    ControllerPublishVolume()│   │   │
│  │  │  CreateSnapshot()  DeleteSnapshot()  ControllerExpandVolume() │   │   │
│  │  │  ListVolumes()     GetCapacity()     ControllerGetCapabilities│   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │                    Node Service                               │   │   │
│  │  │                                                               │   │   │
│  │  │  NodeStageVolume()      NodeUnstageVolume()                   │   │   │
│  │  │  NodePublishVolume()    NodeUnpublishVolume()                 │   │   │
│  │  │  NodeExpandVolume()     NodeGetCapabilities()                 │   │   │
│  │  │  NodeGetInfo()          NodeGetVolumeStats()                  │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │                    Identity Service                           │   │   │
│  │  │                                                               │   │   │
│  │  │  GetPluginInfo()    GetPluginCapabilities()    Probe()        │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                      │
│                                      ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Backend Storage API                               │   │
│  │  云厂商API / 存储系统API / 本地存储操作                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 CSI卷生命周期

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CSI 卷完整生命周期                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. 创建阶段 (Provisioning)                                              │
│     ┌───────────────────────────────────────────────────────────────┐   │
│     │  用户创建PVC → Provisioner监听 → CreateVolume() → 创建PV      │   │
│     └───────────────────────────────────────────────────────────────┘   │
│                                      │                                   │
│                                      ▼                                   │
│  2. 挂载阶段 (Attaching)                                                 │
│     ┌───────────────────────────────────────────────────────────────┐   │
│     │  Pod调度到节点 → Attacher监听 → ControllerPublishVolume()     │   │
│     │                                → 卷挂载到节点                  │   │
│     └───────────────────────────────────────────────────────────────┘   │
│                                      │                                   │
│                                      ▼                                   │
│  3. 暂存阶段 (Staging) - 可选                                            │
│     ┌───────────────────────────────────────────────────────────────┐   │
│     │  kubelet调用 → NodeStageVolume() → 格式化并挂载到暂存路径     │   │
│     │                                  /var/lib/kubelet/plugins/xxx │   │
│     └───────────────────────────────────────────────────────────────┘   │
│                                      │                                   │
│                                      ▼                                   │
│  4. 发布阶段 (Publishing)                                                │
│     ┌───────────────────────────────────────────────────────────────┐   │
│     │  kubelet调用 → NodePublishVolume() → bind mount到Pod目录      │   │
│     │                                    /var/lib/kubelet/pods/xxx  │   │
│     └───────────────────────────────────────────────────────────────┘   │
│                                      │                                   │
│                                      ▼                                   │
│  5. 使用阶段 (In Use)                                                    │
│     ┌───────────────────────────────────────────────────────────────┐   │
│     │  容器挂载卷 → 读写数据 → 监控卷状态和使用量                     │   │
│     └───────────────────────────────────────────────────────────────┘   │
│                                      │                                   │
│                                      ▼                                   │
│  6. 取消发布 (Unpublishing)                                              │
│     ┌───────────────────────────────────────────────────────────────┐   │
│     │  Pod删除 → NodeUnpublishVolume() → 取消bind mount             │   │
│     └───────────────────────────────────────────────────────────────┘   │
│                                      │                                   │
│                                      ▼                                   │
│  7. 取消暂存 (Unstaging) - 可选                                          │
│     ┌───────────────────────────────────────────────────────────────┐   │
│     │  无Pod使用 → NodeUnstageVolume() → 卸载暂存目录                │   │
│     └───────────────────────────────────────────────────────────────┘   │
│                                      │                                   │
│                                      ▼                                   │
│  8. 分离阶段 (Detaching)                                                 │
│     ┌───────────────────────────────────────────────────────────────┐   │
│     │  卷不再需要 → ControllerUnpublishVolume() → 从节点分离        │   │
│     └───────────────────────────────────────────────────────────────┘   │
│                                      │                                   │
│                                      ▼                                   │
│  9. 删除阶段 (Deletion) - 可选                                           │
│     ┌───────────────────────────────────────────────────────────────┐   │
│     │  PVC删除 + ReclaimPolicy=Delete → DeleteVolume() → 删除后端卷 │   │
│     └───────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.3 常见CSI驱动对比

| CSI驱动 | 存储类型 | 访问模式 | 快照支持 | 扩容支持 | 克隆支持 |
|--------|---------|---------|---------|---------|---------|
| **AWS EBS CSI** | 块存储 | RWO | ✅ | ✅ | ✅ |
| **AWS EFS CSI** | 文件存储 | RWX | ❌ | ❌ | ❌ |
| **GCE PD CSI** | 块存储 | RWO/ROX | ✅ | ✅ | ✅ |
| **Azure Disk CSI** | 块存储 | RWO | ✅ | ✅ | ✅ |
| **Azure File CSI** | 文件存储 | RWX | ✅ | ✅ | ❌ |
| **Alibaba Cloud Disk** | 块存储 | RWO | ✅ | ✅ | ✅ |
| **Alibaba Cloud NAS** | 文件存储 | RWX | ❌ | ✅ | ❌ |
| **Ceph RBD** | 块存储 | RWO | ✅ | ✅ | ✅ |
| **CephFS** | 文件存储 | RWX | ✅ | ✅ | ✅ |
| **NFS-CSI** | 文件存储 | RWX | ❌ | ❌ | ❌ |
| **Local Path** | 本地存储 | RWO | ❌ | ❌ | ❌ |

---

## 3. PV/PVC核心机制

### 3.1 PV生命周期状态

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    PV 生命周期状态机                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                          ┌─────────────┐                                │
│                          │  Available  │ ← PV创建后的初始状态             │
│                          └──────┬──────┘                                │
│                                 │                                        │
│                    PVC绑定请求  │                                        │
│                                 ▼                                        │
│                          ┌─────────────┐                                │
│                          │    Bound    │ ← PV已绑定到PVC                 │
│                          └──────┬──────┘                                │
│                                 │                                        │
│                       PVC删除   │                                        │
│                                 ▼                                        │
│                          ┌─────────────┐                                │
│           ┌──────────────│  Released   │──────────────┐                 │
│           │              └─────────────┘              │                 │
│           │                                           │                 │
│    Reclaim=Retain                              Reclaim=Delete           │
│           │                                           │                 │
│           ▼                                           ▼                 │
│    ┌─────────────┐                            ┌─────────────┐           │
│    │  Released   │ (保留，需手动处理)          │   Deleted   │           │
│    │  (Manual)   │                            │   (自动)    │           │
│    └─────────────┘                            └─────────────┘           │
│           │                                                             │
│    手动清理后重新可用                                                     │
│           │                                                             │
│           ▼                                                             │
│    ┌─────────────┐                                                      │
│    │  Available  │                                                      │
│    └─────────────┘                                                      │
│                                                                         │
│  特殊状态:                                                               │
│    ┌─────────────┐                                                      │
│    │   Failed    │ ← 回收失败或异常状态                                  │
│    └─────────────┘                                                      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 PVC绑定机制详解

```yaml
# 动态供给 - 推荐方式
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-data
  namespace: production
  labels:
    app: mysql
    environment: production
spec:
  # 访问模式
  accessModes:
  - ReadWriteOnce
  
  # 存储类 - 触发动态供给
  storageClassName: fast-ssd
  
  # 容量请求
  resources:
    requests:
      storage: 100Gi
  
  # 卷模式 (可选)
  volumeMode: Filesystem  # Filesystem (默认) | Block
  
  # 数据源 (可选) - 用于克隆或从快照恢复
  # dataSource:
  #   name: mysql-snapshot
  #   kind: VolumeSnapshot
  #   apiGroup: snapshot.storage.k8s.io
  
  # 数据源引用 (v1.26+) - 支持跨命名空间
  # dataSourceRef:
  #   name: mysql-snapshot
  #   kind: VolumeSnapshot
  #   apiGroup: snapshot.storage.k8s.io
  #   namespace: backup

---
# 静态供给 - 绑定已存在的PV
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: legacy-data
  namespace: production
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: ""  # 空字符串表示静态供给
  volumeName: pv-legacy-001  # 指定要绑定的PV名称
  resources:
    requests:
      storage: 50Gi  # 必须 <= PV容量

---
# 对应的静态PV
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-legacy-001
  labels:
    type: legacy
spec:
  capacity:
    storage: 50Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""  # 静态供给
  
  # CSI卷源
  csi:
    driver: disk.csi.example.com
    volumeHandle: vol-xxxxxxxxx  # 已存在的卷ID
    fsType: ext4
    volumeAttributes:
      type: cloud_ssd

---
# 选择器绑定 - 按标签选择PV
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: selected-data
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: ""
  resources:
    requests:
      storage: 100Gi
  selector:
    matchLabels:
      type: high-performance
    matchExpressions:
    - key: environment
      operator: In
      values:
      - production
      - staging
```

### 3.3 Pod挂载PVC

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: production
spec:
  template:
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        
        volumeMounts:
        # 标准挂载
        - name: data
          mountPath: /var/lib/mysql
        
        # 子路径挂载 - 在同一PVC中使用不同目录
        - name: data
          mountPath: /var/log/mysql
          subPath: logs
        
        # 只读挂载
        - name: config
          mountPath: /etc/mysql/conf.d
          readOnly: true
        
        # 子路径表达式 - 使用环境变量 (v1.17+)
        - name: data
          mountPath: /var/lib/mysql/data
          subPathExpr: $(POD_NAME)
        
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
      
      volumes:
      # PVC卷
      - name: data
        persistentVolumeClaim:
          claimName: mysql-data
      
      # ConfigMap卷
      - name: config
        configMap:
          name: mysql-config

---
# StatefulSet - 使用volumeClaimTemplates
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-cluster
  namespace: production
spec:
  serviceName: mysql-headless
  replicas: 3
  
  template:
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
  
  # 为每个Pod创建独立的PVC
  volumeClaimTemplates:
  - metadata:
      name: data
      labels:
        app: mysql
    spec:
      accessModes:
      - ReadWriteOnce
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 100Gi
  
  # PVC保留策略 (v1.27+)
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Retain   # StatefulSet删除时保留PVC
    whenScaled: Delete    # 缩容时删除PVC (谨慎使用)
```

---

## 4. StorageClass高级配置

### 4.1 StorageClass完整配置

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
  annotations:
    # 设为默认StorageClass
    storageclass.kubernetes.io/is-default-class: "false"
    # 描述信息
    description: "High-performance SSD storage for databases"

# CSI驱动名称
provisioner: disk.csi.example.com

# 驱动参数 - 传递给CSI驱动
parameters:
  # 存储类型
  type: cloud_essd
  performanceLevel: PL1
  
  # 文件系统类型
  fsType: ext4
  
  # 加密配置
  encrypted: "true"
  kmsKeyId: "alias/storage-key"
  
  # 可用区配置
  zoneId: cn-hangzhou-a,cn-hangzhou-b
  
  # 标签传递
  csi.storage.k8s.io/pv-name: "${pv.name}"
  csi.storage.k8s.io/pvc-name: "${pvc.name}"
  csi.storage.k8s.io/pvc-namespace: "${pvc.namespace}"

# 回收策略
reclaimPolicy: Retain  # Delete | Retain | Recycle(废弃)

# 允许卷扩容
allowVolumeExpansion: true

# 卷绑定模式
volumeBindingMode: WaitForFirstConsumer  # Immediate | WaitForFirstConsumer

# 挂载选项
mountOptions:
- noatime
- nodiratime
- discard

# 允许的拓扑 - 限制卷可创建的位置
allowedTopologies:
- matchLabelExpressions:
  - key: topology.kubernetes.io/zone
    values:
    - cn-hangzhou-a
    - cn-hangzhou-b
  - key: topology.kubernetes.io/region
    values:
    - cn-hangzhou
```

### 4.2 不同场景StorageClass配置

```yaml
# 高性能数据库存储
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: database-storage
provisioner: disk.csi.example.com
parameters:
  type: cloud_essd
  performanceLevel: PL2  # 高IOPS
  fsType: xfs            # XFS更适合数据库
reclaimPolicy: Retain    # 保护数据
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
mountOptions:
- noatime
- nodiratime
- nobarrier

---
# 共享文件存储
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: shared-storage
provisioner: nas.csi.example.com
parameters:
  server: "nas-xxx.cn-hangzhou.nas.example.com"
  protocolType: "NFS"
  mountOptions: "noresvport,nolock"
  reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: Immediate  # NAS可以立即绑定

---
# 开发测试存储 (低成本)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: dev-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: disk.csi.example.com
parameters:
  type: cloud_efficiency  # 高效云盘
  fsType: ext4
reclaimPolicy: Delete     # 测试环境自动清理
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer

---
# 本地高性能存储
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-ssd
provisioner: kubernetes.io/no-provisioner  # 静态供给
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

### 4.3 绑定模式详解

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    VolumeBindingMode 对比                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Immediate 模式 (立即绑定)                                               │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                                                                   │  │
│  │  PVC创建 ──→ 立即供给PV ──→ 绑定完成 ──→ Pod调度时可能跨AZ       │  │
│  │                                                                   │  │
│  │  优点: 快速绑定                                                    │  │
│  │  缺点: 可能导致Pod与PV在不同可用区，造成跨AZ网络延迟              │  │
│  │  适用: NAS等不受拓扑限制的存储                                     │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  WaitForFirstConsumer 模式 (延迟绑定) - 推荐                             │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                                                                   │  │
│  │  PVC创建 ──→ Pending ──→ Pod调度 ──→ 在Pod所在节点的AZ供给PV     │  │
│  │                                                                   │  │
│  │  优点: 保证Pod和PV在同一拓扑域，避免跨AZ访问                       │  │
│  │  缺点: 绑定延迟到Pod调度时                                         │  │
│  │  适用: 块存储等受拓扑限制的存储                                    │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  实际效果对比:                                                           │
│                                                                         │
│  Immediate:                                                             │
│    Node-A (cn-hangzhou-a)     Node-B (cn-hangzhou-b)                   │
│    ┌─────────────────┐        ┌─────────────────┐                      │
│    │     Pod         │        │                 │                      │
│    │   ┌───────┐     │        │  ┌───────────┐  │                      │
│    │   │ mount │◄────┼────────┼──│    PV     │  │  跨AZ访问!           │
│    │   └───────┘     │        │  └───────────┘  │                      │
│    └─────────────────┘        └─────────────────┘                      │
│                                                                         │
│  WaitForFirstConsumer:                                                  │
│    Node-A (cn-hangzhou-a)     Node-B (cn-hangzhou-b)                   │
│    ┌─────────────────┐        ┌─────────────────┐                      │
│    │     Pod         │        │                 │                      │
│    │   ┌───────┐     │        │                 │                      │
│    │   │ mount │◄────┤        │                 │  同AZ访问             │
│    │   └───────┘     │        │                 │                      │
│    │  ┌───────────┐  │        │                 │                      │
│    │  │    PV     │  │        │                 │                      │
│    │  └───────────┘  │        │                 │                      │
│    └─────────────────┘        └─────────────────┘                      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 5. 存储性能优化

### 5.1 存储性能基准测试

```yaml
# 使用fio进行存储性能测试
apiVersion: batch/v1
kind: Job
metadata:
  name: storage-benchmark
  namespace: benchmark
spec:
  template:
    spec:
      containers:
      - name: fio
        image: ljishen/fio:latest
        command:
        - /bin/sh
        - -c
        - |
          echo "=== 存储性能基准测试 ==="
          echo "测试时间: $(date)"
          echo ""
          
          # 1. 顺序写测试
          echo "=== 1. 顺序写测试 ==="
          fio --name=seq-write \
              --directory=/data \
              --size=4G \
              --bs=1M \
              --rw=write \
              --ioengine=libaio \
              --direct=1 \
              --numjobs=4 \
              --runtime=60 \
              --time_based \
              --group_reporting
          
          # 2. 顺序读测试
          echo "=== 2. 顺序读测试 ==="
          fio --name=seq-read \
              --directory=/data \
              --size=4G \
              --bs=1M \
              --rw=read \
              --ioengine=libaio \
              --direct=1 \
              --numjobs=4 \
              --runtime=60 \
              --time_based \
              --group_reporting
          
          # 3. 随机写测试 (IOPS)
          echo "=== 3. 随机写测试 ==="
          fio --name=rand-write \
              --directory=/data \
              --size=1G \
              --bs=4K \
              --rw=randwrite \
              --ioengine=libaio \
              --direct=1 \
              --numjobs=16 \
              --iodepth=64 \
              --runtime=60 \
              --time_based \
              --group_reporting
          
          # 4. 随机读测试 (IOPS)
          echo "=== 4. 随机读测试 ==="
          fio --name=rand-read \
              --directory=/data \
              --size=1G \
              --bs=4K \
              --rw=randread \
              --ioengine=libaio \
              --direct=1 \
              --numjobs=16 \
              --iodepth=64 \
              --runtime=60 \
              --time_based \
              --group_reporting
          
          # 5. 混合读写测试 (70读/30写)
          echo "=== 5. 混合读写测试 ==="
          fio --name=mixed-rw \
              --directory=/data \
              --size=1G \
              --bs=4K \
              --rw=randrw \
              --rwmixread=70 \
              --ioengine=libaio \
              --direct=1 \
              --numjobs=16 \
              --iodepth=64 \
              --runtime=60 \
              --time_based \
              --group_reporting
          
          # 清理测试文件
          rm -f /data/*.0.*
          
          echo ""
          echo "=== 测试完成 ==="
        
        resources:
          requests:
            cpu: "2"
            memory: "4Gi"
          limits:
            cpu: "4"
            memory: "8Gi"
        
        volumeMounts:
        - name: test-volume
          mountPath: /data
      
      volumes:
      - name: test-volume
        persistentVolumeClaim:
          claimName: benchmark-pvc
      
      restartPolicy: Never
  backoffLimit: 0

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: benchmark-pvc
  namespace: benchmark
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast-ssd  # 测试目标StorageClass
  resources:
    requests:
      storage: 100Gi
```

### 5.2 性能调优参数

```yaml
# 高性能存储配置
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: high-performance
provisioner: disk.csi.example.com
parameters:
  type: cloud_essd
  performanceLevel: PL2
  fsType: xfs  # XFS对大文件和数据库更友好
mountOptions:
# 文件系统挂载优化
- noatime          # 不更新访问时间，减少写操作
- nodiratime       # 目录不更新访问时间
- nobarrier        # 禁用写屏障(SSD推荐)
- discard          # 启用TRIM支持
- inode64          # 支持大文件系统
- logbufs=8        # XFS日志缓冲区数量
- logbsize=256k    # XFS日志缓冲区大小
- allocsize=64m    # 预分配大小

---
# 数据库专用存储配置
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: database-optimized
provisioner: disk.csi.example.com
parameters:
  type: cloud_essd
  performanceLevel: PL3  # 最高性能
  fsType: xfs
mountOptions:
- noatime
- nodiratime
- nobarrier
- inode64
# MySQL/PostgreSQL优化
- largeio          # 大IO优化
- swalloc          # 条带对齐分配
```

### 5.3 存储性能指标参考

| 存储类型 | 顺序读(MB/s) | 顺序写(MB/s) | 随机读IOPS | 随机写IOPS | 延迟(ms) |
|---------|------------|------------|-----------|-----------|---------|
| **云盘高效** | 140 | 140 | 3,000 | 3,000 | 1-3 |
| **云盘SSD** | 300 | 256 | 25,000 | 25,000 | 0.5-2 |
| **ESSD PL0** | 180 | 180 | 10,000 | 10,000 | 0.2-1 |
| **ESSD PL1** | 350 | 350 | 50,000 | 50,000 | 0.1-0.5 |
| **ESSD PL2** | 750 | 750 | 100,000 | 100,000 | 0.1-0.3 |
| **ESSD PL3** | 4,000 | 4,000 | 1,000,000 | 1,000,000 | <0.1 |
| **NAS标准** | 150 | 150 | 2,000 | 2,000 | 3-10 |
| **NAS极速** | 600 | 600 | 30,000 | 30,000 | 0.2-1 |
| **本地SSD** | 2,000+ | 2,000+ | 200,000+ | 200,000+ | <0.1 |

---

## 6. 快照与克隆

### 6.1 VolumeSnapshot配置

```yaml
# 快照类
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-disk-snapclass
  annotations:
    snapshot.storage.kubernetes.io/is-default-class: "true"
driver: disk.csi.example.com
deletionPolicy: Delete  # Delete | Retain
parameters:
  # 快照类型
  snapshotType: instant
  # 快照标签
  tags: "env=production,app=mysql"

---
# 创建快照
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: mysql-snapshot-20260130
  namespace: production
  labels:
    app: mysql
    snapshot-type: scheduled
spec:
  volumeSnapshotClassName: csi-disk-snapclass
  source:
    persistentVolumeClaimName: mysql-data

---
# 从快照恢复
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-restored
  namespace: production
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast-ssd
  dataSource:
    name: mysql-snapshot-20260130
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  resources:
    requests:
      storage: 100Gi  # 必须 >= 源PVC容量
```

### 6.2 自动快照策略

```yaml
# 定时快照CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mysql-snapshot-job
  namespace: production
spec:
  schedule: "0 2 * * *"  # 每天凌晨2点
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: snapshot-manager
          containers:
          - name: snapshot-creator
            image: bitnami/kubectl:latest
            command:
            - /bin/bash
            - -c
            - |
              set -e
              
              # 生成快照名称
              SNAPSHOT_NAME="mysql-snapshot-$(date +%Y%m%d-%H%M%S)"
              
              echo "Creating snapshot: ${SNAPSHOT_NAME}"
              
              # 创建快照
              cat <<EOF | kubectl apply -f -
              apiVersion: snapshot.storage.k8s.io/v1
              kind: VolumeSnapshot
              metadata:
                name: ${SNAPSHOT_NAME}
                namespace: production
                labels:
                  app: mysql
                  snapshot-type: scheduled
                  created-by: cronjob
              spec:
                volumeSnapshotClassName: csi-disk-snapclass
                source:
                  persistentVolumeClaimName: mysql-data
              EOF
              
              # 等待快照就绪
              echo "Waiting for snapshot to be ready..."
              kubectl wait --for=jsonpath='{.status.readyToUse}'=true \
                volumesnapshot/${SNAPSHOT_NAME} \
                -n production \
                --timeout=300s
              
              echo "Snapshot ${SNAPSHOT_NAME} created successfully"
              
              # 清理旧快照 (保留最近7个)
              echo "Cleaning up old snapshots..."
              kubectl get volumesnapshot -n production \
                -l snapshot-type=scheduled \
                --sort-by='.metadata.creationTimestamp' \
                -o name | head -n -7 | xargs -r kubectl delete -n production
              
              echo "Cleanup completed"
          
          restartPolicy: OnFailure

---
# ServiceAccount和RBAC
apiVersion: v1
kind: ServiceAccount
metadata:
  name: snapshot-manager
  namespace: production

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: snapshot-manager-role
  namespace: production
rules:
- apiGroups: ["snapshot.storage.k8s.io"]
  resources: ["volumesnapshots"]
  verbs: ["get", "list", "create", "delete", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: snapshot-manager-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: snapshot-manager
  namespace: production
roleRef:
  kind: Role
  name: snapshot-manager-role
  apiGroup: rbac.authorization.k8s.io
```

### 6.3 PVC克隆

```yaml
# 从现有PVC克隆
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-clone
  namespace: production
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast-ssd
  dataSource:
    name: mysql-data        # 源PVC名称
    kind: PersistentVolumeClaim
  resources:
    requests:
      storage: 100Gi        # 可以 >= 源PVC容量

---
# 跨命名空间克隆 (v1.26+)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-clone-from-backup
  namespace: production
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast-ssd
  dataSourceRef:
    name: mysql-backup-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
    namespace: backup       # 跨命名空间引用
  resources:
    requests:
      storage: 100Gi
```

---

## 7. 监控与告警

### 7.1 关键存储指标

| 指标类别 | 指标名称 | 告警阈值 | 说明 |
|---------|---------|---------|------|
| **容量** | `kubelet_volume_stats_available_bytes` | <20% | 可用空间不足 |
| **容量** | `kubelet_volume_stats_inodes_free` | <10% | inode不足 |
| **使用率** | `kubelet_volume_stats_used_bytes` | >80% | 使用率高 |
| **PVC状态** | `kube_persistentvolumeclaim_status_phase` | =Pending>5m | PVC未绑定 |
| **PV状态** | `kube_persistentvolume_status_phase` | =Failed | PV异常 |
| **挂载** | `node_filesystem_avail_bytes` | <10% | 节点磁盘不足 |

### 7.2 Prometheus告警规则

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: storage-alerts
  namespace: monitoring
spec:
  groups:
  - name: storage.rules
    rules:
    # PVC容量不足告警
    - alert: PVCStorageAlmostFull
      expr: |
        (
          kubelet_volume_stats_available_bytes
          / kubelet_volume_stats_capacity_bytes
        ) < 0.2
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "PVC存储空间即将耗尽"
        description: "{{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} 可用空间低于20%"
    
    # PVC容量严重不足
    - alert: PVCStorageCritical
      expr: |
        (
          kubelet_volume_stats_available_bytes
          / kubelet_volume_stats_capacity_bytes
        ) < 0.1
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "PVC存储空间严重不足"
        description: "{{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} 可用空间低于10%，需立即处理"
    
    # inode不足告警
    - alert: PVCInodeAlmostFull
      expr: |
        (
          kubelet_volume_stats_inodes_free
          / kubelet_volume_stats_inodes
        ) < 0.1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "PVC inode即将耗尽"
        description: "{{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} 可用inode低于10%"
    
    # PVC长时间Pending
    - alert: PVCPendingTooLong
      expr: |
        kube_persistentvolumeclaim_status_phase{phase="Pending"} == 1
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "PVC长时间处于Pending状态"
        description: "{{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} 已Pending超过15分钟"
    
    # PV状态异常
    - alert: PVFailed
      expr: |
        kube_persistentvolume_status_phase{phase=~"Failed|Released"} == 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "PV状态异常"
        description: "{{ $labels.persistentvolume }} 状态为{{ $labels.phase }}"
    
    # 快照失败
    - alert: VolumeSnapshotFailed
      expr: |
        kube_volumesnapshot_status_ready_to_use == 0
        and time() - kube_volumesnapshot_status_creation_time > 600
      for: 0m
      labels:
        severity: warning
      annotations:
        summary: "快照创建失败"
        description: "{{ $labels.namespace }}/{{ $labels.volumesnapshot }} 创建超过10分钟仍未就绪"
    
    # 存储扩容失败
    - alert: PVCResizeFailed
      expr: |
        kube_persistentvolumeclaim_status_condition{condition="Resizing",status="true"} == 1
      for: 30m
      labels:
        severity: warning
      annotations:
        summary: "PVC扩容操作未完成"
        description: "{{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} 扩容操作已进行30分钟"
```

### 7.3 Grafana Dashboard配置

```json
{
  "dashboard": {
    "title": "Kubernetes Storage Monitoring",
    "panels": [
      {
        "title": "PVC Usage Overview",
        "type": "table",
        "targets": [
          {
            "expr": "sum by(namespace, persistentvolumeclaim) (kubelet_volume_stats_used_bytes) / sum by(namespace, persistentvolumeclaim) (kubelet_volume_stats_capacity_bytes) * 100",
            "legendFormat": "{{ namespace }}/{{ persistentvolumeclaim }}"
          }
        ]
      },
      {
        "title": "Storage Capacity Trend",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(kubelet_volume_stats_capacity_bytes) by (namespace)",
            "legendFormat": "{{ namespace }} - Total"
          },
          {
            "expr": "sum(kubelet_volume_stats_used_bytes) by (namespace)",
            "legendFormat": "{{ namespace }} - Used"
          }
        ]
      },
      {
        "title": "PVC Status Distribution",
        "type": "piechart",
        "targets": [
          {
            "expr": "count by(phase) (kube_persistentvolumeclaim_status_phase)",
            "legendFormat": "{{ phase }}"
          }
        ]
      }
    ]
  }
}
```

---

## 8. 故障排查手册

### 8.1 故障诊断流程图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    存储故障诊断流程                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  PVC状态异常?                                                            │
│      │                                                                  │
│      ├── Pending ──┐                                                    │
│      │             ├── 检查StorageClass是否存在                          │
│      │             │   kubectl get sc                                   │
│      │             ├── 检查CSI驱动状态                                    │
│      │             │   kubectl get pods -n kube-system | grep csi       │
│      │             ├── 检查配额是否充足                                   │
│      │             │   kubectl describe resourcequota -n <ns>           │
│      │             ├── 检查绑定模式                                      │
│      │             │   WaitForFirstConsumer需要Pod调度后才绑定           │
│      │             └── 检查拓扑约束                                       │
│      │                 卷只能在特定AZ创建                                 │
│      │                                                                  │
│      ├── Lost ──┐                                                       │
│      │          ├── PV被意外删除                                         │
│      │          ├── 后端存储异常                                         │
│      │          └── 需要手动恢复或从备份还原                              │
│      │                                                                  │
│      └── Bound但Pod挂载失败 ──┐                                         │
│                              ├── 检查Pod Events                          │
│                              │   kubectl describe pod <pod>             │
│                              ├── 检查节点CSI插件                          │
│                              │   kubectl logs -n kube-system csi-xxx    │
│                              ├── 检查卷是否已被其他Pod挂载(RWO限制)      │
│                              └── 检查文件系统是否损坏                     │
│                                                                         │
│  挂载超时?                                                               │
│      │                                                                  │
│      ├── 检查VolumeAttachment                                           │
│      │   kubectl get volumeattachment                                   │
│      ├── 检查节点到存储后端网络                                          │
│      └── 检查CSI controller日志                                         │
│                                                                         │
│  扩容失败?                                                               │
│      │                                                                  │
│      ├── 确认StorageClass支持扩容                                        │
│      │   allowVolumeExpansion: true                                     │
│      ├── 检查后端存储配额                                                │
│      ├── 检查扩容条件(如需要重启Pod)                                     │
│      └── 检查CSI驱动日志                                                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 8.2 常用诊断命令

```bash
#!/bin/bash
# 存储诊断脚本

NAMESPACE=${1:-default}
PVC_NAME=$2

echo "=========================================="
echo "存储诊断报告"
echo "命名空间: $NAMESPACE"
echo "PVC: $PVC_NAME"
echo "时间: $(date)"
echo "=========================================="

# 1. PVC状态
echo -e "\n=== 1. PVC状态 ==="
kubectl get pvc $PVC_NAME -n $NAMESPACE -o wide

echo -e "\n=== 2. PVC详细信息 ==="
kubectl describe pvc $PVC_NAME -n $NAMESPACE

# 3. 对应PV
echo -e "\n=== 3. 对应PV ==="
PV_NAME=$(kubectl get pvc $PVC_NAME -n $NAMESPACE -o jsonpath='{.spec.volumeName}')
if [ -n "$PV_NAME" ]; then
    kubectl get pv $PV_NAME -o wide
    kubectl describe pv $PV_NAME
fi

# 4. StorageClass
echo -e "\n=== 4. StorageClass ==="
SC_NAME=$(kubectl get pvc $PVC_NAME -n $NAMESPACE -o jsonpath='{.spec.storageClassName}')
kubectl get sc $SC_NAME -o yaml

# 5. CSI驱动状态
echo -e "\n=== 5. CSI驱动状态 ==="
kubectl get pods -n kube-system | grep -E "csi|provisioner|attacher"

# 6. VolumeAttachment
echo -e "\n=== 6. VolumeAttachment ==="
kubectl get volumeattachment | grep $PV_NAME

# 7. 使用此PVC的Pod
echo -e "\n=== 7. 使用此PVC的Pod ==="
kubectl get pods -n $NAMESPACE -o json | jq -r ".items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName==\"$PVC_NAME\") | .metadata.name"

# 8. 存储相关Events
echo -e "\n=== 8. 相关Events ==="
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -iE "pvc|pv|volume|storage|attach|mount" | tail -20

# 9. CSI驱动日志
echo -e "\n=== 9. CSI Controller日志 (最近20行) ==="
CSI_POD=$(kubectl get pods -n kube-system -l app=csi-provisioner -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$CSI_POD" ]; then
    kubectl logs $CSI_POD -n kube-system --tail=20
fi

# 10. 容量使用情况
echo -e "\n=== 10. 容量使用情况 ==="
if [ -n "$PV_NAME" ]; then
    kubectl get --raw /api/v1/persistentvolumes/$PV_NAME/status 2>/dev/null | jq '.status.capacity'
fi
```

### 8.3 常见故障解决方案

#### 8.3.1 PVC Pending - 无法绑定

```bash
# 问题: PVC一直处于Pending状态

# 1. 检查StorageClass
kubectl get sc
kubectl describe sc <storage-class-name>

# 2. 检查CSI驱动
kubectl get pods -n kube-system | grep csi
kubectl logs -n kube-system <csi-controller-pod> -c csi-provisioner

# 3. 检查配额
kubectl describe resourcequota -n <namespace>

# 4. 如果是WaitForFirstConsumer模式，创建Pod触发绑定
# 检查绑定模式
kubectl get sc <sc-name> -o jsonpath='{.volumeBindingMode}'

# 5. 检查拓扑约束
kubectl describe pvc <pvc-name> -n <namespace>
# 查看Events中的调度约束信息
```

#### 8.3.2 Pod挂载卷失败

```bash
# 问题: Pod无法挂载PVC

# 1. 检查Pod Events
kubectl describe pod <pod-name> -n <namespace>
# 查找 "FailedMount" 或 "FailedAttachVolume" 事件

# 2. 检查VolumeAttachment
kubectl get volumeattachment
kubectl describe volumeattachment <va-name>

# 3. 检查节点CSI插件
kubectl logs -n kube-system <csi-node-pod> -c csi-driver

# 4. RWO卷被其他Pod占用
# 检查哪个Pod正在使用该PVC
kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName=="<pvc-name>") | "\(.metadata.namespace)/\(.metadata.name)"'

# 5. 强制分离卷 (谨慎使用)
kubectl delete volumeattachment <va-name>
```

#### 8.3.3 PVC扩容失败

```bash
# 问题: PVC扩容不生效

# 1. 确认StorageClass支持扩容
kubectl get sc <sc-name> -o jsonpath='{.allowVolumeExpansion}'

# 2. 检查PVC状态
kubectl get pvc <pvc-name> -n <namespace> -o yaml
# 查看 status.conditions 中的 FileSystemResizePending

# 3. 对于需要重启Pod才能完成扩容的情况
kubectl delete pod <pod-name> -n <namespace>
# Pod重建后文件系统会自动扩展

# 4. 检查CSI驱动日志
kubectl logs -n kube-system <csi-controller-pod> -c csi-resizer

# 5. 手动触发文件系统扩展 (如果支持在线扩展)
kubectl exec <pod-name> -n <namespace> -- df -h
kubectl exec <pod-name> -n <namespace> -- resize2fs /dev/xxx  # ext4
kubectl exec <pod-name> -n <namespace> -- xfs_growfs /mount/point  # xfs
```

---

## 9. 数据保护与灾备

### 9.1 备份策略

```yaml
# 使用Velero进行备份
# 安装: velero install --provider aws --bucket velero-backups --secret-file ./credentials-velero

# 定时备份策略
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"  # 每天凌晨2点
  template:
    # 备份范围
    includedNamespaces:
    - production
    - database
    
    # 排除资源
    excludedResources:
    - events
    - events.events.k8s.io
    
    # 包含PV数据
    snapshotVolumes: true
    
    # 存储位置
    storageLocation: default
    
    # 卷快照位置
    volumeSnapshotLocations:
    - default
    
    # TTL
    ttl: 720h  # 30天
    
    # 标签选择器
    labelSelector:
      matchLabels:
        backup: enabled
  
  # 保留策略
  useOwnerReferencesInBackup: false

---
# 手动备份
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: mysql-backup-20260130
  namespace: velero
spec:
  includedNamespaces:
  - database
  includedResources:
  - persistentvolumeclaims
  - persistentvolumes
  - statefulsets
  - services
  - configmaps
  - secrets
  labelSelector:
    matchLabels:
      app: mysql
  snapshotVolumes: true
  storageLocation: default
  ttl: 720h
```

### 9.2 灾难恢复

```bash
#!/bin/bash
# 灾难恢复脚本

BACKUP_NAME=$1
TARGET_NAMESPACE=${2:-production}

echo "=== 开始灾难恢复 ==="
echo "备份名称: $BACKUP_NAME"
echo "目标命名空间: $TARGET_NAMESPACE"

# 1. 列出可用备份
echo -e "\n1. 可用备份列表:"
velero backup get

# 2. 查看备份详情
echo -e "\n2. 备份详情:"
velero backup describe $BACKUP_NAME

# 3. 验证备份内容
echo -e "\n3. 备份内容:"
velero backup logs $BACKUP_NAME | head -50

# 4. 执行恢复 (恢复到原命名空间)
echo -e "\n4. 执行恢复..."
velero restore create --from-backup $BACKUP_NAME \
    --include-namespaces $TARGET_NAMESPACE \
    --restore-volumes=true

# 5. 恢复到不同命名空间
# velero restore create --from-backup $BACKUP_NAME \
#     --namespace-mappings production:production-restored \
#     --restore-volumes=true

# 6. 监控恢复进度
echo -e "\n5. 恢复状态:"
velero restore get

# 7. 验证恢复结果
echo -e "\n6. 验证恢复结果:"
kubectl get pvc -n $TARGET_NAMESPACE
kubectl get pods -n $TARGET_NAMESPACE
```

### 9.3 跨区域复制

```yaml
# 配置跨区域存储复制
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: geo-replicated
provisioner: disk.csi.example.com
parameters:
  type: cloud_essd
  # 启用跨区域复制
  replicationEnabled: "true"
  replicationRegions: "cn-hangzhou,cn-shanghai"
  
---
# 使用数据同步工具 (如Rook-Ceph RBD Mirror)
apiVersion: ceph.rook.io/v1
kind: CephBlockPoolRadosNamespace
metadata:
  name: mirrored-pool
spec:
  mirroring:
    enabled: true
    mode: image
    snapshotSchedules:
    - interval: 24h
      startTime: "00:00:00-00:00"
```

---

## 10. 实战案例演练

### 10.1 案例一：MySQL高可用存储方案

```yaml
# MySQL主从集群存储配置
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: mysql-storage
provisioner: disk.csi.example.com
parameters:
  type: cloud_essd
  performanceLevel: PL2
  fsType: xfs
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
mountOptions:
- noatime
- nodiratime

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  namespace: database
spec:
  serviceName: mysql-headless
  replicas: 3
  template:
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
        - name: logs
          mountPath: /var/log/mysql
  
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: mysql-storage
      resources:
        requests:
          storage: 100Gi
  - metadata:
      name: logs
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: mysql-storage
      resources:
        requests:
          storage: 20Gi
  
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Retain
    whenScaled: Retain
```

### 10.2 案例二：共享存储方案

```yaml
# 多Pod共享文件存储
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: shared-nas
provisioner: nas.csi.example.com
parameters:
  server: "nas-xxx.cn-hangzhou.nas.example.com"
  protocolType: "NFS"
  archiveOnDelete: "false"
reclaimPolicy: Retain
allowVolumeExpansion: true

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-uploads
  namespace: production
spec:
  accessModes:
  - ReadWriteMany  # 多Pod共享
  storageClassName: shared-nas
  resources:
    requests:
      storage: 500Gi

---
# 多个Deployment共享同一PVC
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: production
spec:
  replicas: 5
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        volumeMounts:
        - name: uploads
          mountPath: /var/www/uploads
      volumes:
      - name: uploads
        persistentVolumeClaim:
          claimName: shared-uploads
```

### 10.3 案例三：存储在线迁移

```bash
#!/bin/bash
# PVC在线迁移脚本

SOURCE_PVC="mysql-data"
TARGET_SC="fast-ssd-new"
NAMESPACE="database"

echo "=== PVC在线迁移 ==="
echo "源PVC: $SOURCE_PVC"
echo "目标StorageClass: $TARGET_SC"

# 1. 创建快照
echo "1. 创建源PVC快照..."
cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: migration-snapshot
  namespace: $NAMESPACE
spec:
  source:
    persistentVolumeClaimName: $SOURCE_PVC
EOF

# 等待快照就绪
kubectl wait --for=jsonpath='{.status.readyToUse}'=true \
  volumesnapshot/migration-snapshot -n $NAMESPACE --timeout=300s

# 2. 从快照创建新PVC
echo "2. 从快照创建新PVC..."
CAPACITY=$(kubectl get pvc $SOURCE_PVC -n $NAMESPACE -o jsonpath='{.spec.resources.requests.storage}')
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${SOURCE_PVC}-new
  namespace: $NAMESPACE
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: $TARGET_SC
  dataSource:
    name: migration-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  resources:
    requests:
      storage: $CAPACITY
EOF

# 等待新PVC绑定
kubectl wait --for=jsonpath='{.status.phase}'=Bound \
  pvc/${SOURCE_PVC}-new -n $NAMESPACE --timeout=300s

# 3. 更新应用使用新PVC
echo "3. 请手动更新应用配置，将PVC引用从 $SOURCE_PVC 改为 ${SOURCE_PVC}-new"
echo "   完成后执行: kubectl rollout restart deployment/<app> -n $NAMESPACE"

# 4. 验证后清理旧资源
echo "4. 验证迁移成功后，执行以下命令清理:"
echo "   kubectl delete pvc $SOURCE_PVC -n $NAMESPACE"
echo "   kubectl delete volumesnapshot migration-snapshot -n $NAMESPACE"
```

---

## 11. 总结与Q&A

### 11.1 核心要点回顾

| 主题 | 关键要点 |
|------|----------|
| **存储类型选择** | 块存储(RWO/数据库) vs 文件存储(RWX/共享) vs 对象存储(大文件) |
| **动态供给** | 优先使用StorageClass + CSI实现自动化供给 |
| **性能优化** | 选择合适的存储类型、文件系统、挂载选项 |
| **数据保护** | 快照 + 备份 + 跨区域复制实现多层保护 |
| **监控告警** | 容量使用率 + PVC状态 + CSI驱动健康 |

### 11.2 最佳实践清单

- [ ] 使用WaitForFirstConsumer绑定模式避免跨AZ问题
- [ ] 生产环境使用Retain回收策略保护数据
- [ ] 配置存储容量告警(80%警告/90%严重)
- [ ] 实施定期快照和备份策略
- [ ] 测试灾难恢复流程
- [ ] 使用合适的性能级别存储(不过度配置)
- [ ] 配置inode监控(小文件场景)
- [ ] 定期进行存储性能基准测试

### 11.3 常见问题解答

**Q: 如何选择StorageClass的性能级别？**
A: 根据IOPS和吞吐量需求选择：
- 开发测试：高效云盘/ESSD PL0
- 一般生产：ESSD PL1 (50K IOPS)
- 数据库：ESSD PL2 (100K IOPS)
- 极高性能：ESSD PL3或本地SSD

**Q: PVC扩容后为什么容量没变？**
A: 部分存储需要重启Pod才能完成文件系统扩展。检查PVC的FileSystemResizePending条件。

**Q: RWX存储支持哪些CSI驱动？**
A: NAS/NFS类驱动支持RWX，如阿里云NAS、AWS EFS、Azure Files、CephFS等。

**Q: 如何实现跨AZ的存储高可用？**
A: 1) 使用支持多AZ的存储(如NAS)；2) 应用层复制(如MySQL主从)；3) 存储层复制(如Ceph跨AZ)

---

## 阿里云ACK专属配置

### ACK存储类配置

```yaml
# 阿里云云盘ESSD
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alicloud-disk-essd
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
  performanceLevel: PL1
  fsType: ext4
  # 多可用区配置
  zoneId: cn-hangzhou-a,cn-hangzhou-b
  # 加密
  encrypted: "true"
  kmsKeyId: "alias/ack-disk-key"
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer

---
# 阿里云NAS
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alicloud-nas
provisioner: nasplugin.csi.alibabacloud.com
parameters:
  server: "xxx.cn-hangzhou.nas.aliyuncs.com"
  volumeAs: subpath
  archiveOnDelete: "false"
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: Immediate
```

---

## 附录 A: 常用命令速查表

```bash
# PV/PVC 管理
kubectl get pv -o wide
kubectl get pvc -A -o wide
kubectl describe pv <pv-name>
kubectl describe pvc <pvc-name> -n <namespace>
kubectl patch pvc <pvc-name> -n <namespace> -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'

# StorageClass 管理
kubectl get storageclass
kubectl describe storageclass <name>
kubectl get storageclass <name> -o yaml

# CSI 驱动检查
kubectl get csidrivers
kubectl get csinodes
kubectl get volumeattachments

# 快照管理
kubectl get volumesnapshots -A
kubectl get volumesnapshotcontents
kubectl get volumesnapshotclasses

# 存储容量
kubectl get csistoragecapacities -A

# Pod 存储挂载检查
kubectl get pod <pod-name> -o jsonpath='{.spec.volumes}'
kubectl exec <pod-name> -- df -h
kubectl exec <pod-name> -- mount | grep <volume-name>

# 存储性能测试
kubectl exec <pod-name> -- fio --name=randwrite --ioengine=libaio --iodepth=16 --rw=randwrite --bs=4k --size=1G --numjobs=4 --runtime=60 --time_based --group_reporting
```

## 附录 B: 配置模板索引

| 模板名称 | 适用场景 | 章节位置 |
|----------|----------|----------|
| ESSD 云盘 StorageClass | 高性能块存储 | ACK专属配置 |
| NAS 存储配置 | 共享文件存储 | ACK专属配置 |
| 本地存储 PV | 高IOPS需求 | 3.2 节 |
| 动态卷供应 | 自动化存储分配 | 4.1 节 |
| 卷快照配置 | 数据备份 | 6.1 节 |
| 卷克隆配置 | 数据复制 | 6.2 节 |
| 加密存储配置 | 安全合规 | 9.2 节 |
| 跨AZ存储配置 | 高可用部署 | 9.3 节 |

## 附录 C: 故障排查索引

| 故障现象 | 可能原因 | 排查方法 | 章节位置 |
|----------|----------|----------|----------|
| PVC Pending | StorageClass 不存在 | kubectl describe pvc | 8.1 节 |
| PVC Bound 但 Pod Pending | VolumeAttachment 失败 | kubectl get volumeattachments | 8.2 节 |
| 挂载失败 | CSI 驱动异常 | 检查 csi-plugin Pod | 8.2 节 |
| 存储性能差 | 磁盘类型/IOPS 限制 | fio 基准测试 | 5.1 节 |
| 扩容失败 | StorageClass 不支持 | 检查 allowVolumeExpansion | 8.3 节 |
| 快照失败 | VolumeSnapshotClass 缺失 | kubectl get volumesnapshotclasses | 8.4 节 |
| 数据丢失 | ReclaimPolicy=Delete | 检查 PV 回收策略 | 8.5 节 |

## 附录 D: 监控指标参考

| 指标名称 | 类型 | 说明 | 告警阈值 |
|----------|------|------|----------|
| `kubelet_volume_stats_capacity_bytes` | Gauge | 卷总容量 | - |
| `kubelet_volume_stats_used_bytes` | Gauge | 卷已用容量 | > 80% |
| `kubelet_volume_stats_available_bytes` | Gauge | 卷可用容量 | < 20% |
| `kubelet_volume_stats_inodes` | Gauge | inode 总数 | - |
| `kubelet_volume_stats_inodes_used` | Gauge | inode 已用 | > 90% |
| `csi_sidecar_operations_seconds` | Histogram | CSI 操作延迟 | P99 > 30s |

---

**文档版本**: v2.0  
**适用版本**: Kubernetes v1.26-v1.32  
**更新日期**: 2026年1月  
**作者**: Kusheet Project  
**联系方式**: Allen Galler (allengaller@gmail.com)

---

*全文完 - Kubernetes 存储生产环境运维培训*
