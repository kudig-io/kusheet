# 13 - 存储核心组件 (Storage Components)

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [Kubernetes Storage](https://kubernetes.io/docs/concepts/storage/)

## 目录

1. [存储架构概览](#存储架构概览)
2. [PV/PVC/StorageClass](#pvpvcstorageclass)
3. [访问模式与回收策略](#访问模式与回收策略)
4. [动态卷供给](#动态卷供给)
5. [CSI驱动生态](#csi驱动生态)
6. [卷扩容与快照](#卷扩容与快照)
7. [存储性能优化](#存储性能优化)
8. [存储故障排查](#存储故障排查)
9. [云原生存储方案](#云原生存储方案)
10. [数据持久化决策](#数据持久化决策)

---

## 存储架构概览

### 存储抽象层次

```
应用层 (Application)
    ↓
PVC (PersistentVolumeClaim) - 命名空间级声明
    ↓
PV (PersistentVolume) - 集群级资源
    ↓
StorageClass - 动态供给模板
    ↓
CSI Driver - 存储插件接口
    ↓
底层存储 (云盘/NAS/Ceph/Local)
```

### 存储系统分类

| 存储类型 | 特点 | 访问模式 | 性能 | 适用场景 | 成本 |
|---------|------|---------|------|---------|------|
| **块存储 (Block)** | 高性能，独占 | RWO | 高IOPS | 数据库，高IO应用 | 中 |
| **文件存储 (File)** | 共享访问 | RWO/ROX/RWX | 中等 | 共享文件，日志 | 中-高 |
| **对象存储 (Object)** | 海量存储 | 应用API | 低延迟 | 静态资源，备份 | 低 |
| **本地存储 (Local)** | 最高性能 | RWO | 极高 | 缓存，临时数据 | 低 |

---

## PV/PVC/StorageClass

### PersistentVolume (PV) 完整配置

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: data-pv
  labels:
    type: ssd
    zone: cn-hangzhou-h
spec:
  capacity:
    storage: 100Gi
  volumeMode: Filesystem  # 或 Block
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain  # Delete/Recycle(已弃用)
  storageClassName: alicloud-disk-essd
  mountOptions:
    - hard
    - nfsvers=4.1
  nodeAffinity:  # 拓扑约束
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: topology.kubernetes.io/zone
          operator: In
          values:
          - cn-hangzhou-h
  csi:
    driver: diskplugin.csi.alibabacloud.com
    volumeHandle: d-bp1234567890abcdef
    fsType: ext4
    volumeAttributes:
      performanceLevel: "PL1"
      type: "cloud_essd"
```

### PersistentVolumeClaim (PVC) 完整配置

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
  namespace: production
  annotations:
    volume.beta.kubernetes.io/storage-provisioner: diskplugin.csi.alibabacloud.com
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: alicloud-disk-essd
  resources:
    requests:
      storage: 100Gi
  selector:  # 可选: 选择特定PV
    matchLabels:
      type: ssd
  volumeMode: Filesystem  # 或 Block
  dataSource:  # 可选: 从快照恢复
    name: data-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

### StorageClass 生产级配置

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alicloud-disk-essd-pl1
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
  performanceLevel: PL1  # PL0/PL1/PL2/PL3
  encrypted: "true"  # 启用加密
  kmsKeyId: "key-id"  # KMS密钥
  resourceGroupId: "rg-xxx"  # 资源组
reclaimPolicy: Delete  # Retain/Delete
allowVolumeExpansion: true  # 允许扩容
volumeBindingMode: WaitForFirstConsumer  # 延迟绑定，确保拓扑匹配
mountOptions:
  - noatime
  - nodiratime
```

### 多StorageClass策略

| StorageClass名称 | 云盘类型 | 性能等级 | IOPS | 适用场景 | 月成本(100GB) |
|----------------|---------|---------|------|---------|--------------|
| **fast-ssd-pl3** | ESSD | PL3 | 1,000,000 | 核心数据库 | 350元 |
| **fast-ssd-pl2** | ESSD | PL2 | 100,000 | 一般数据库 | 210元 |
| **standard-ssd** | ESSD | PL1 | 50,000 | 应用存储 | 150元 |
| **economy-ssd** | ESSD | PL0 | 10,000 | 开发测试 | 105元 |
| **shared-nas** | NAS | 通用型 | - | 共享文件 | 120元 |
| **local-nvme** | 本地盘 | NVMe | 极高 | 缓存层 | 包含在ECS |

---

## 访问模式与回收策略

### 访问模式 (AccessModes)

| 模式 | 缩写 | 说明 | 支持存储类型 | 典型场景 |
|-----|------|------|------------|---------|
| **ReadWriteOnce** | RWO | 单节点读写 | 块存储，本地盘 | 数据库，应用状态 |
| **ReadOnlyMany** | ROX | 多节点只读 | 文件存储，对象存储 | 配置文件，静态资源 |
| **ReadWriteMany** | RWX | 多节点读写 | NAS，分布式文件系统 | 共享日志，媒体文件 |
| **ReadWriteOncePod** | RWOP | 单Pod独占 (v1.27+) | 块存储 | 严格单写场景 |

### 访问模式兼容性矩阵

| 存储类型 | RWO | ROX | RWX | RWOP |
|---------|-----|-----|-----|------|
| **阿里云云盘 (ESSD)** | ✓ | ✗ | ✗ | ✓ (v1.27+) |
| **阿里云NAS** | ✓ | ✓ | ✓ | ✓ (v1.27+) |
| **阿里云OSS (CSI)** | ✓ | ✓ | ✓ | ✗ |
| **Ceph RBD** | ✓ | ✗ | ✗ | ✓ (v1.27+) |
| **CephFS** | ✓ | ✓ | ✓ | ✓ (v1.27+) |
| **Local Path** | ✓ | ✗ | ✗ | ✓ (v1.27+) |
| **NFS** | ✓ | ✓ | ✓ | ✓ (v1.27+) |

### 回收策略 (ReclaimPolicy)

| 策略 | 行为 | 数据安全 | 适用场景 |
|-----|------|---------|---------|
| **Retain** | PVC删除后保留PV和数据 | 高 | 生产环境，关键数据 |
| **Delete** | PVC删除后删除PV和底层存储 | 低 | 临时数据，开发测试 |
| **Recycle** | 删除数据后重用PV (已弃用) | 不推荐 | 不推荐使用 |

#### 生产环境回收策略最佳实践

```yaml
# 方案1: StorageClass级别设置Retain
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: production-disk
provisioner: diskplugin.csi.alibabacloud.com
reclaimPolicy: Retain  # 生产环境必须使用Retain
parameters:
  type: cloud_essd
  performanceLevel: PL1

---
# 方案2: 动态修改PV回收策略
# 在PVC创建后，将自动创建的PV的策略改为Retain
kubectl patch pv <pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
```

---

## 动态卷供给

### 动态供给流程图

```
1. 用户创建PVC
    ↓
2. StorageClass定义供给器
    ↓
3. CSI Driver创建底层存储
    ↓
4. 自动创建PV并绑定到PVC
    ↓
5. Pod挂载PVC使用存储
```

### VolumeBindingMode 对比

| 模式 | 行为 | 优点 | 缺点 | 适用场景 |
|-----|------|------|------|---------|
| **Immediate** | PVC创建后立即供给 | 快速，简单 | 可能导致拓扑不匹配 | 无拓扑约束 |
| **WaitForFirstConsumer** | 等待Pod调度后供给 | 确保拓扑匹配 | 首次启动较慢 | 云环境，多可用区 |

### 延迟绑定配置示例

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: topology-aware-disk
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
volumeBindingMode: WaitForFirstConsumer  # 延迟绑定
allowedTopologies:
- matchLabelExpressions:
  - key: topology.kubernetes.io/zone
    values:
    - cn-hangzhou-h
    - cn-hangzhou-i
```

---

## CSI驱动生态

### CSI (Container Storage Interface) 架构

```
┌─────────────────────────────────────┐
│         Kubernetes                  │
│  ┌──────────────┐  ┌─────────────┐ │
│  │ API Server   │  │ Scheduler   │ │
│  └──────────────┘  └─────────────┘ │
└─────────────────────────────────────┘
           ↓ CSI API
┌─────────────────────────────────────┐
│     CSI Controller Plugin           │
│  (Provisioner, Attacher, Resizer)   │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│     CSI Node Plugin (DaemonSet)     │
│  (Node Driver Registrar, Mounter)   │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│     底层存储系统                     │
└─────────────────────────────────────┘
```

### 主流CSI驱动对比

| CSI驱动 | 存储类型 | 访问模式 | 快照 | 扩容 | 克隆 | 成熟度 |
|--------|---------|---------|------|------|------|-------|
| **阿里云云盘 CSI** | 块存储 | RWO | ✓ | ✓ | ✓ | 高 |
| **阿里云NAS CSI** | 文件存储 | RWX | ✓ | ✓ | ✓ | 高 |
| **阿里云OSS CSI** | 对象存储 | RWX | ✗ | ✓ | ✗ | 中 |
| **Ceph RBD CSI** | 块存储 | RWO | ✓ | ✓ | ✓ | 高 |
| **CephFS CSI** | 文件存储 | RWX | ✓ | ✓ | ✓ | 高 |
| **NFS CSI** | 文件存储 | RWX | ✗ | ✗ | ✗ | 中 |
| **Local Path** | 本地存储 | RWO | ✗ | ✗ | ✗ | 中 |
| **Longhorn** | 分布式块存储 | RWO/RWX | ✓ | ✓ | ✓ | 高 |

### 阿里云存储CSI配置

```yaml
# 云盘CSI驱动配置
apiVersion: storage.k8s.io/v1
kind: CSIDriver
metadata:
  name: diskplugin.csi.alibabacloud.com
spec:
  attachRequired: true
  podInfoOnMount: false
  volumeLifecycleModes:
  - Persistent
  - Ephemeral

---
# NAS CSI驱动配置
apiVersion: storage.k8s.io/v1
kind: CSIDriver
metadata:
  name: nasplugin.csi.alibabacloud.com
spec:
  attachRequired: false
  podInfoOnMount: false
  volumeLifecycleModes:
  - Persistent

---
# OSS CSI驱动配置
apiVersion: storage.k8s.io/v1
kind: CSIDriver
metadata:
  name: ossplugin.csi.alibabacloud.com
spec:
  attachRequired: false
  podInfoOnMount: false
  volumeLifecycleModes:
  - Persistent
```

---

## 卷扩容与快照

### 在线扩容 (Volume Expansion)

#### 扩容前提条件

1. StorageClass 设置 `allowVolumeExpansion: true`
2. CSI驱动支持扩容
3. 底层存储支持在线扩容

#### 扩容操作流程

```bash
# 1. 修改PVC大小
kubectl edit pvc data-pvc
# 修改 spec.resources.requests.storage: 200Gi

# 2. 观察扩容状态
kubectl get pvc data-pvc -w
# 状态: Resizing -> FileSystemResizePending -> Bound

# 3. 对于某些文件系统，需要重启Pod完成文件系统扩容
kubectl rollout restart deployment/myapp

# 4. 验证扩容
kubectl exec -it myapp-pod -- df -h
```

#### 扩容注意事项

| 注意事项 | 说明 |
|---------|------|
| **不支持缩容** | Kubernetes不支持PVC缩容，只能扩容 |
| **阿里云限制** | 云盘扩容后不能小于当前大小，每次扩容最少10GB |
| **文件系统扩容** | ext4/xfs等需要Pod重启，某些云盘支持在线扩容 |
| **停机时间** | 在线扩容可能需要几分钟，规划维护窗口 |

### 卷快照 (Volume Snapshot)

#### VolumeSnapshotClass 配置

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: alicloud-disk-snapshot
driver: diskplugin.csi.alibabacloud.com
deletionPolicy: Retain  # Delete/Retain
parameters:
  forceDelete: "false"
  instantAccess: "true"  # 即时访问
  instantAccessRetentionDays: "1"
```

#### 创建快照

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: data-snapshot-20260118
  namespace: production
spec:
  volumeSnapshotClassName: alicloud-disk-snapshot
  source:
    persistentVolumeClaimName: data-pvc
```

#### 从快照恢复

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc-restored
spec:
  storageClassName: alicloud-disk-essd
  dataSource:
    name: data-snapshot-20260118
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
```

#### 快照最佳实践

```yaml
# 定时快照CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: volume-snapshot-cronjob
spec:
  schedule: "0 2 * * *"  # 每天凌晨2点
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: snapshot-controller
          containers:
          - name: snapshot
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              DATE=$(date +%Y%m%d-%H%M%S)
              cat <<EOF | kubectl apply -f -
              apiVersion: snapshot.storage.k8s.io/v1
              kind: VolumeSnapshot
              metadata:
                name: data-snapshot-$DATE
                namespace: production
              spec:
                volumeSnapshotClassName: alicloud-disk-snapshot
                source:
                  persistentVolumeClaimName: data-pvc
              EOF
              # 清理7天前的快照
              kubectl get volumesnapshot -n production -o json | \
                jq -r ".items[] | select(.metadata.creationTimestamp < \"$(date -d '7 days ago' --iso-8601)\") | .metadata.name" | \
                xargs -I {} kubectl delete volumesnapshot {} -n production
          restartPolicy: OnFailure
```

---

## 存储性能优化

### 块存储性能调优

#### IOPS与吞吐量关系

| 云盘类型 | 容量 | 基准IOPS | 最大IOPS | 吞吐量(MB/s) |
|---------|------|---------|---------|-------------|
| **ESSD PL0** | 40-32768GB | 10,000 | 10,000 | 180 |
| **ESSD PL1** | 20-32768GB | 1,800+50/GB | 50,000 | 350 |
| **ESSD PL2** | 461-32768GB | 4,000+50/GB | 100,000 | 750 |
| **ESSD PL3** | 1261-32768GB | 10,000+50/GB | 1,000,000 | 4,000 |

#### 性能优化配置

```yaml
# 高性能存储配置
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: high-performance-disk
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
  performanceLevel: PL2
  provisionedIops: "100000"  # 预配置IOPS
  burstingEnabled: "true"  # 启用突发
mountOptions:
  - noatime  # 不更新访问时间，减少IO
  - nodiratime  # 目录不更新访问时间
  - discard  # 支持TRIM
  - barrier=0  # 禁用写屏障(提升性能，降低可靠性)
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

### 文件系统选择

| 文件系统 | 优点 | 缺点 | 适用场景 |
|---------|------|------|---------|
| **ext4** | 稳定，兼容性好 | 性能中等 | 通用场景 |
| **xfs** | 大文件性能好 | 小文件性能差 | 大文件，日志 |
| **btrfs** | 快照，压缩 | 相对不成熟 | 高级特性需求 |

### NAS性能优化

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nas-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteMany
  mountOptions:
    - vers=4.1  # 使用NFSv4.1
    - noresvport  # 不使用保留端口
    - rsize=1048576  # 读取大小1MB
    - wsize=1048576  # 写入大小1MB
    - hard  # 硬挂载
    - timeo=600  # 超时时间
    - retrans=2  # 重试次数
    - nolock  # 禁用锁(提升性能)
  csi:
    driver: nasplugin.csi.alibabacloud.com
    volumeHandle: "nas-id:/path"
```

### 存储IO隔离

```yaml
# 使用不同的StorageClass实现IO隔离
---
# 核心业务使用高性能云盘
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: core-db-pvc
spec:
  storageClassName: fast-ssd-pl3
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 500Gi

---
# 日志使用经济型云盘
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: logs-pvc
spec:
  storageClassName: economy-ssd
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 200Gi
```

---

## 存储故障排查

### 常见问题诊断流程图

```
Pod无法启动
    ↓
检查Pod Events
    ↓
┌─────────────┬────────────────┬──────────────┐
│ FailedMount │ FailedAttach   │ FailedScheduling │
│             │                │                  │
│ 检查PVC状态 │ 检查Node上挂载 │ 检查拓扑约束     │
│ 检查权限    │ 检查设备数量   │ 检查资源配额     │
└─────────────┴────────────────┴──────────────┘
```

### 存储问题排查命令

```bash
# 1. 检查PVC状态
kubectl get pvc -A
kubectl describe pvc <pvc-name>

# 2. 检查PV状态
kubectl get pv
kubectl describe pv <pv-name>

# 3. 检查StorageClass
kubectl get sc
kubectl describe sc <sc-name>

# 4. 检查CSI驱动状态
kubectl get csidrivers
kubectl get csinodes
kubectl describe csinode <node-name>

# 5. 检查CSI Controller和Node Plugin
kubectl get pods -n kube-system | grep csi
kubectl logs -n kube-system csi-diskplugin-xxxx -c disk-plugin
kubectl logs -n kube-system csi-diskplugin-xxxx -c disk-provisioner

# 6. 检查VolumeAttachment
kubectl get volumeattachment
kubectl describe volumeattachment <va-name>

# 7. 查看节点上挂载的设备
kubectl debug node/<node-name> -it --image=busybox
chroot /host
lsblk
df -h
mount | grep /var/lib/kubelet
```

### 常见错误与解决方案

| 错误信息 | 原因 | 解决方案 |
|---------|------|---------|
| **waiting for a volume to be created** | PVC等待PV绑定 | 检查StorageClass和provisioner |
| **FailedAttachVolume** | 卷无法挂载到节点 | 检查CSI驱动，节点可用区，云盘配额 |
| **FailedMount** | 卷无法挂载到容器 | 检查权限，文件系统类型，mountOptions |
| **Multi-Attach error** | 云盘被多个节点挂载 | RWO卷只能被一个节点使用，等待旧Pod终止 |
| **Volume is already attached** | 云盘未正确卸载 | 手动detach云盘，或强制删除Node对象 |
| **Timeout expired waiting for volumes** | 调度超时 | 检查拓扑约束，增加节点或放宽约束 |

### 强制清理挂载卷

```bash
# 1. 删除Pod
kubectl delete pod <pod-name> --grace-period=0 --force

# 2. 删除VolumeAttachment
kubectl delete volumeattachment <va-name>

# 3. 在节点上手动umount
kubectl debug node/<node-name> -it --image=busybox
chroot /host
umount /var/lib/kubelet/pods/<pod-uid>/volumes/kubernetes.io~csi/<pvc-name>/mount

# 4. 阿里云控制台手动卸载云盘

# 5. 重新创建Pod
kubectl apply -f pod.yaml
```

---

## 云原生存储方案

### 方案一: 本地临时卷 (适合无状态应用)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cache-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: cache
      mountPath: /cache
  volumes:
  - name: cache
    emptyDir:
      sizeLimit: 10Gi  # 限制大小
      medium: Memory  # 使用内存(tmpfs)，极高性能
```

### 方案二: 本地持久卷 (适合高性能需求)

```yaml
# 本地磁盘StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete

---
# 本地PV (需要手动创建)
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-node1
spec:
  capacity:
    storage: 500Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /mnt/disks/ssd1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - node1
```

### 方案三: 云盘动态供给 (推荐生产方案)

```yaml
# 见前文StorageClass配置
# 优点: 自动化，灵活，可靠
# 缺点: 成本相对高，性能受云盘限制
```

### 方案四: Longhorn 分布式存储

```bash
# 安装Longhorn
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml

# 等待组件就绪
kubectl get pods -n longhorn-system -w

# 访问UI
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
```

```yaml
# Longhorn StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  numberOfReplicas: "3"  # 副本数
  staleReplicaTimeout: "2880"
  dataLocality: "disabled"  # best-effort/disabled
  fromBackup: ""
```

---

## 数据持久化决策

### 决策树

```
数据是否需要持久化?
    ├─ 否 → emptyDir (临时数据)
    └─ 是
        ├─ 是否需要多节点共享?
        │   ├─ 是 → NAS / CephFS (RWX)
        │   └─ 否
        │       ├─ 是否需要极高性能?
        │       │   ├─ 是 → 本地SSD (Local PV)
        │       │   └─ 否
        │       │       ├─ 云原生环境?
        │       │       │   ├─ 是 → 云盘CSI (ESSD)
        │       │       │   └─ 否 → Ceph RBD / Longhorn
        │       │       └─ 数据库场景?
        │       │           ├─ 是 → ESSD PL2/PL3
        │       │           └─ 否 → ESSD PL1
        └─ 是否需要对象存储?
            └─ 是 → OSS / S3 (应用直接对接)
```

### 存储选型对比表

| 场景 | 推荐方案 | 访问模式 | 性能 | 可靠性 | 成本 |
|-----|---------|---------|------|-------|------|
| **MySQL/PostgreSQL** | ESSD PL2/PL3 | RWO | 高 | 高 | 中-高 |
| **Redis缓存** | 本地NVMe + 主从 | RWO | 极高 | 中 | 低 |
| **MongoDB** | ESSD PL1 + 副本集 | RWO | 中-高 | 高 | 中 |
| **Elasticsearch** | ESSD PL1 | RWO | 中-高 | 高 | 中 |
| **Kafka** | ESSD PL1 / 本地盘 | RWO | 高 | 高 | 低-中 |
| **共享文件** | NAS通用型 | RWX | 中 | 高 | 中 |
| **日志存储** | NAS/本地盘 | RWO/RWX | 中 | 中 | 低 |
| **镜像仓库** | OSS + 缓存层 | - | 中 | 高 | 低 |
| **备份** | OSS | - | 低 | 高 | 低 |
| **AI训练数据** | CPFS / NAS极速 | RWX | 极高 | 高 | 高 |

### 成本优化建议

| 优化项 | 方法 | 节省比例 |
|-------|------|---------|
| **使用ESSD PL0** | 非关键应用降级 | 30% |
| **快照代替全量备份** | 使用CSI快照 | 70% |
| **冷数据归档OSS** | 生命周期管理 | 80% |
| **按需扩容** | 监控使用率，按需扩容 | 20-40% |
| **本地盘+远程备份** | 高性能+低成本备份 | 50% |

### 架构师视角: 存储分层策略

```
┌─────────────────────────────────────┐
│  热数据层 (Local NVMe)              │  极高性能，缓存
│  IOPS: 100K+  延迟: <0.1ms          │
└─────────────────────────────────────┘
            ↓ 降冷
┌─────────────────────────────────────┐
│  温数据层 (ESSD PL1/PL2)            │  高性能，主存储
│  IOPS: 10K-100K  延迟: <1ms         │
└─────────────────────────────────────┘
            ↓ 归档
┌─────────────────────────────────────┐
│  冷数据层 (ESSD PL0)                │  经济型，低频访问
│  IOPS: 10K  延迟: <5ms              │
└─────────────────────────────────────┘
            ↓ 备份
┌─────────────────────────────────────┐
│  归档层 (OSS Archive)               │  极低成本，长期保存
│  访问延迟: 分钟级                    │
└─────────────────────────────────────┘
```

### 产品经理视角: 存储需求模板

#### 需求收集清单

```markdown
1. 数据类型: □ 关系型数据库 □ NoSQL □ 文件 □ 对象 □ 缓存
2. 数据大小: ____ TB (预计增长: ____% /年)
3. 访问模式: □ 随机读写 □ 顺序读写 □ 读多写少 □ 写多读少
4. 性能要求:
   - IOPS: ____ (峰值: ____)
   - 吞吐量: ____ MB/s
   - 延迟: < ____ ms
5. 可靠性:
   - RPO: ____ (最多丢失多少数据)
   - RTO: ____ (多久恢复)
   - 副本数: ____
6. 共享需求: □ 单Pod独占 □ 多Pod共享只读 □ 多Pod共享读写
7. 数据生命周期:
   - 热数据保留: ____ 天
   - 冷数据归档: ____ 天
   - 备份保留: ____ 天
8. 合规要求: □ 加密 □ 审计 □ 地域限制
9. 预算: ____ 元/月
```

### 运维视角: 存储监控指标

```yaml
# Prometheus监控规则示例
groups:
- name: storage_alerts
  rules:
  # PVC使用率告警
  - alert: PVCUsageHigh
    expr: |
      (kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) > 0.85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "PVC {{ $labels.persistentvolumeclaim }} usage > 85%"
      
  # PVC即将满
  - alert: PVCAlmostFull
    expr: |
      (kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) > 0.95
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "PVC {{ $labels.persistentvolumeclaim }} usage > 95%"
      
  # PV不可用
  - alert: PersistentVolumeUnavailable
    expr: |
      kube_persistentvolume_status_phase{phase!="Bound"} > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "PV {{ $labels.persistentvolume }} is not Bound"
      
  # CSI驱动异常
  - alert: CSIDriverDown
    expr: |
      up{job="csi-driver"} == 0
    for: 3m
    labels:
      severity: critical
    annotations:
      summary: "CSI Driver {{ $labels.instance }} is down"
```

---

## 生产级存储配置示例

### MySQL StatefulSet + ESSD

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
        resources:
          requests:
            cpu: 2
            memory: 4Gi
          limits:
            cpu: 4
            memory: 8Gi
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd-pl2
      resources:
        requests:
          storage: 500Gi
```

### 共享文件存储 + NAS

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: shared-files-pv
spec:
  capacity:
    storage: 1Ti
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: alicloud-nas
  mountOptions:
    - vers=4.1
    - noresvport
    - rsize=1048576
    - wsize=1048576
  csi:
    driver: nasplugin.csi.alibabacloud.com
    volumeHandle: "nas-xxx.cn-hangzhou.nas.aliyuncs.com:/share"

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-files-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: alicloud-nas
  resources:
    requests:
      storage: 1Ti

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: file-processor
spec:
  replicas: 5
  selector:
    matchLabels:
      app: file-processor
  template:
    metadata:
      labels:
        app: file-processor
    spec:
      containers:
      - name: processor
        image: processor:latest
        volumeMounts:
        - name: shared-files
          mountPath: /data
      volumes:
      - name: shared-files
        persistentVolumeClaim:
          claimName: shared-files-pvc
```

---

**表格维护**: Kusheet Project | **作者**: Allen Galler (allengaller@gmail.com)