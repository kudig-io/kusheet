# 表格13：存储表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/storage](https://kubernetes.io/docs/concepts/storage/)

## 存储类型对比

| 存储类型 | 特点 | 持久性 | 共享性 | 适用场景 | 版本支持 |
|---------|------|-------|-------|---------|---------|
| **emptyDir** | Pod生命周期，节点本地 | Pod删除后丢失 | 同Pod容器间 | 临时缓存，共享文件 | 稳定 |
| **hostPath** | 节点文件系统 | 节点级 | 同节点Pod | 访问节点文件，开发测试 | 稳定 |
| **PersistentVolume** | 独立存储资源 | 持久化 | 取决于类型 | 生产数据存储 | 稳定 |
| **ConfigMap** | 配置数据 | 集群级 | 所有Pod | 配置文件 | 稳定 |
| **Secret** | 敏感数据 | 集群级 | 所有Pod | 凭证，证书 | 稳定 |
| **CSI** | 容器存储接口 | 取决于后端 | 取决于后端 | 云存储，企业存储 | 稳定 |

## PV访问模式

| 访问模式 | 简写 | 描述 | 支持的存储类型 |
|---------|------|------|--------------|
| **ReadWriteOnce** | RWO | 单节点读写 | 大多数块存储 |
| **ReadOnlyMany** | ROX | 多节点只读 | NFS，云文件存储 |
| **ReadWriteMany** | RWX | 多节点读写 | NFS，CephFS，云文件存储 |
| **ReadWriteOncePod** | RWOP | 单Pod读写(v1.22+) | 部分CSI驱动 |

## PV回收策略

| 策略 | 行为 | 适用场景 | 版本支持 |
|-----|------|---------|---------|
| **Retain** | 保留PV和数据，手动清理 | 重要数据 | 稳定 |
| **Delete** | 删除PV和后端存储 | 动态供应的临时数据 | 稳定 |
| **Recycle** | 清空数据(rm -rf)后复用 | **已弃用** | 弃用 |

## CSI驱动对比

| CSI驱动 | 供应商 | 存储类型 | 功能 | 版本支持 | ACK集成 |
|--------|-------|---------|------|---------|---------|
| **disk-csi** | 阿里云 | 块存储(云盘) | 快照，扩容，拓扑 | v1.25+ | 原生 |
| **nas-csi** | 阿里云 | 文件存储(NAS) | RWX，扩容 | v1.25+ | 原生 |
| **oss-csi** | 阿里云 | 对象存储(OSS) | FUSE挂载 | v1.25+ | 原生 |
| **aws-ebs-csi** | AWS | EBS块存储 | 快照，扩容 | v1.25+ | - |
| **azure-disk-csi** | Azure | Managed Disk | 快照，扩容 | v1.25+ | - |
| **ceph-csi** | Ceph | RBD/CephFS | 快照，克隆 | v1.25+ | - |
| **nfs-csi** | 通用 | NFS | 简单共享 | v1.25+ | - |
| **local-path** | Rancher | 本地路径 | 简单本地存储 | v1.25+ | - |

## StorageClass参数

| 参数 | 说明 | 示例值 | 版本支持 |
|-----|------|-------|---------|
| **provisioner** | CSI驱动名称 | diskplugin.csi.alibabacloud.com | 稳定 |
| **parameters** | 驱动特定参数 | type: cloud_essd | 取决于驱动 |
| **reclaimPolicy** | 回收策略 | Delete/Retain | 稳定 |
| **allowVolumeExpansion** | 允许扩容 | true/false | v1.11+ |
| **volumeBindingMode** | 绑定模式 | Immediate/WaitForFirstConsumer | v1.12+ |
| **allowedTopologies** | 拓扑限制 | 可用区列表 | v1.12+ |
| **mountOptions** | 挂载选项 | ["noatime"] | 稳定 |

```yaml
# StorageClass示例 - 阿里云ESSD
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alicloud-disk-essd
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
  performanceLevel: PL1  # PL0/PL1/PL2/PL3
  fstype: ext4
  encrypted: "true"
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

## VolumeSnapshot(存储快照)

| 资源 | 用途 | 版本支持 |
|-----|------|---------|
| **VolumeSnapshot** | 创建快照请求 | v1.20+ GA |
| **VolumeSnapshotContent** | 实际快照资源 | v1.20+ GA |
| **VolumeSnapshotClass** | 快照类定义 | v1.20+ GA |

```yaml
# 创建快照
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: data-snapshot
spec:
  volumeSnapshotClassName: disk-snapshot
  source:
    persistentVolumeClaimName: data-pvc

---
# 从快照恢复
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc-restore
spec:
  storageClassName: alicloud-disk-essd
  dataSource:
    name: data-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
```

## 存储容量跟踪

| 功能 | 用途 | 版本支持 |
|-----|------|---------|
| **CSIStorageCapacity** | 报告可用存储容量 | v1.24+ GA |
| **Storage Capacity Tracking** | 调度感知存储容量 | v1.24+ GA |

## 本地存储

| 类型 | 配置方式 | 特点 | 适用场景 |
|-----|---------|------|---------|
| **hostPath** | 直接指定路径 | 简单但不安全 | 开发测试 |
| **local PV** | StorageClass+PV | 调度感知，延迟绑定 | 高性能本地SSD |
| **emptyDir.medium=Memory** | tmpfs | 内存文件系统 | 高速临时存储 |

```yaml
# Local PV示例
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv
spec:
  capacity:
    storage: 100Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
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
          - node-1
```

## 存储性能层级(阿里云)

| 云盘类型 | IOPS | 吞吐量 | 延迟 | 适用场景 |
|---------|------|-------|------|---------|
| **ESSD PL3** | 1,000,000 | 4,000MB/s | <0.1ms | 大型数据库 |
| **ESSD PL2** | 100,000 | 750MB/s | <0.1ms | 中型数据库 |
| **ESSD PL1** | 50,000 | 350MB/s | <0.1ms | 一般应用 |
| **ESSD PL0** | 10,000 | 180MB/s | <0.1ms | 开发测试 |
| **SSD** | 25,000 | 300MB/s | <0.5ms | 一般应用 |
| **高效云盘** | 5,000 | 140MB/s | 1-3ms | 冷数据 |

## 存储故障排查

| 问题 | 可能原因 | 诊断命令 | 解决方案 |
|-----|---------|---------|---------|
| **PVC Pending** | 无匹配PV/SC问题 | `kubectl describe pvc` | 检查SC，创建PV |
| **挂载失败** | CSI驱动问题 | `kubectl describe pod`, CSI日志 | 检查CSI |
| **性能差** | 存储类型选择 | `iostat`, `fio` | 升级存储类型 |
| **扩容失败** | 不支持扩容 | `kubectl describe pvc` | 检查SC配置 |
| **快照失败** | 驱动不支持 | `kubectl describe volumesnapshot` | 检查驱动 |

```bash
# 存储诊断命令
kubectl get pv,pvc,sc -A
kubectl describe pvc <name>
kubectl get volumesnapshot,volumesnapshotcontent -A

# CSI驱动状态
kubectl get pods -n kube-system | grep csi
kubectl logs -n kube-system <csi-pod>

# 节点存储信息
kubectl describe node <node> | grep -A 10 "Allocatable"
```

---

**存储原则**: 选择合适类型，规划容量，定期备份
