# 136 - PersistentVolume 架构与核心原理 (PV Architecture & Fundamentals)

> **适用版本**: Kubernetes v1.25 - v1.32 | **难度**: 高级 | **最后更新**: 2026-01

---

## 1. PV 存储架构分层模型

```
┌─────────────────────────────────────────────────────────────────┐
│                      应用层 (Application Layer)                  │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐            │
│  │   Pod   │  │   Pod   │  │   Pod   │  │   Pod   │            │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘            │
│       │            │            │            │                  │
├───────┼────────────┼────────────┼────────────┼──────────────────┤
│       ▼            ▼            ▼            ▼                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              PVC 层 (PersistentVolumeClaim)              │   │
│  │   声明式存储请求：容量、访问模式、StorageClass           │   │
│  └─────────────────────────┬───────────────────────────────┘   │
│                            │ 绑定 (Binding)                     │
├────────────────────────────┼────────────────────────────────────┤
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              PV 层 (PersistentVolume)                    │   │
│  │   集群级存储资源：容量、访问模式、回收策略、存储后端     │   │
│  └─────────────────────────┬───────────────────────────────┘   │
│                            │                                    │
├────────────────────────────┼────────────────────────────────────┤
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              CSI 驱动层 (CSI Driver Layer)               │   │
│  │   Provisioner │ Attacher │ Resizer │ Snapshotter        │   │
│  └─────────────────────────┬───────────────────────────────┘   │
│                            │                                    │
├────────────────────────────┼────────────────────────────────────┤
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              存储后端 (Storage Backend)                  │   │
│  │   云盘(EBS/ESSD) │ NFS │ Ceph │ Local │ iSCSI           │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. PV 核心规格字段详解

| 字段 | 类型 | 必填 | 说明 |
|:---|:---|:---:|:---|
| `capacity.storage` | Quantity | 是 | 存储容量，如 `100Gi` |
| `accessModes` | []string | 是 | 访问模式：RWO/ROX/RWX/RWOP |
| `persistentVolumeReclaimPolicy` | string | 否 | 回收策略：Retain/Delete/Recycle |
| `storageClassName` | string | 否 | 关联的 StorageClass 名称 |
| `volumeMode` | string | 否 | 卷模式：Filesystem(默认)/Block |
| `mountOptions` | []string | 否 | 挂载选项，如 `["noatime","discard"]` |
| `nodeAffinity` | NodeAffinity | 否 | 节点亲和性约束（Local PV必须） |
| `csi` | CSIPersistentVolumeSource | 否 | CSI 卷配置 |

---

## 3. PV 生命周期状态机

```
                    ┌─────────────────────────────────────────────┐
                    │                                             │
                    ▼                                             │
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐     │
│ Pending  │───▶│Available │───▶│  Bound   │───▶│ Released │─────┤
└──────────┘    └──────────┘    └──────────┘    └──────────┘     │
     │               │               │               │            │
     │               │               │               ├──▶ Retain ─┘
     │               │               │               │    (手动回收)
     │               │               │               │
     │               │               │               ├──▶ Delete
     │               │               │               │    (自动删除)
     │               │               │               │
     ▼               ▼               ▼               ▼
┌──────────────────────────────────────────────────────────────┐
│                        Failed                                 │
│              (CSI驱动错误/存储后端故障)                       │
└──────────────────────────────────────────────────────────────┘
```

### 状态说明

| 状态 (Phase) | 含义 | 触发条件 |
|:---|:---|:---|
| **Pending** | 等待中 | PV 创建中，后端存储尚未就绪 |
| **Available** | 可用 | PV 已就绪，等待 PVC 绑定 |
| **Bound** | 已绑定 | PV 已与 PVC 绑定 |
| **Released** | 已释放 | PVC 删除后，PV 等待回收 |
| **Failed** | 失败 | 自动回收失败或后端错误 |

---

## 4. 访问模式 (Access Modes) 深度解析

| 模式 | 全称 | 说明 | 典型场景 |
|:---:|:---|:---|:---|
| **RWO** | ReadWriteOnce | 单节点读写 | 数据库、有状态应用 |
| **ROX** | ReadOnlyMany | 多节点只读 | 静态资源、配置文件 |
| **RWX** | ReadWriteMany | 多节点读写 | 共享存储、日志收集 |
| **RWOP** | ReadWriteOncePod | 单Pod读写(v1.22+) | 严格单实例应用 |

### 存储后端访问模式支持矩阵

| 存储类型 | RWO | ROX | RWX | RWOP |
|:---|:---:|:---:|:---:|:---:|
| AWS EBS | ✅ | ❌ | ❌ | ✅ |
| 阿里云 ESSD | ✅ | ❌ | ❌ | ✅ |
| 阿里云 NAS | ✅ | ✅ | ✅ | ✅ |
| GCP Persistent Disk | ✅ | ✅ | ❌ | ✅ |
| Azure Disk | ✅ | ❌ | ❌ | ✅ |
| Azure Files | ✅ | ✅ | ✅ | ✅ |
| NFS | ✅ | ✅ | ✅ | ❌ |
| Ceph RBD | ✅ | ✅ | ❌ | ✅ |
| CephFS | ✅ | ✅ | ✅ | ✅ |
| Local PV | ✅ | ❌ | ❌ | ✅ |
| iSCSI | ✅ | ✅ | ❌ | ✅ |

---

## 5. 回收策略 (Reclaim Policy) 详解

| 策略 | 行为 | 适用场景 | 风险 |
|:---|:---|:---|:---|
| **Retain** | 保留数据，需手动清理 | 生产环境、重要数据 | 存储泄漏 |
| **Delete** | 自动删除 PV 和后端存储 | 临时数据、测试环境 | 数据丢失 |
| **Recycle** | 清空数据后重新可用 | 已废弃(v1.14) | 不推荐 |

### 生产环境建议

```yaml
# 生产环境：Retain 策略 + 定期备份
apiVersion: v1
kind: PersistentVolume
metadata:
  name: prod-mysql-pv
  labels:
    env: production
    backup: required
spec:
  capacity:
    storage: 500Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain  # 生产必须
  storageClassName: alicloud-disk-essd-pl1
  csi:
    driver: diskplugin.csi.alibabacloud.com
    volumeHandle: d-bp1xxxxxxxxxxxxx
    fsType: ext4
```

---

## 6. PV 绑定机制与算法

### 绑定流程

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│  PVC 创建   │────▶│  PV Controller   │────▶│  匹配算法   │
└─────────────┘     └──────────────────┘     └──────┬──────┘
                                                    │
                    ┌───────────────────────────────┘
                    ▼
    ┌───────────────────────────────────────────────────┐
    │              PV 匹配条件检查                       │
    │  1. StorageClass 匹配                             │
    │  2. AccessModes 包含                              │
    │  3. Capacity >= 请求容量                          │
    │  4. Selector 标签匹配 (如有)                      │
    │  5. VolumeMode 匹配                               │
    │  6. NodeAffinity 满足 (WaitForFirstConsumer)     │
    └───────────────────────────────────────────────────┘
                    │
                    ▼
    ┌───────────────────────────────────────────────────┐
    │              绑定优先级排序                        │
    │  1. 精确容量匹配优先                              │
    │  2. 最小满足容量优先                              │
    │  3. 先创建的 PV 优先                              │
    └───────────────────────────────────────────────────┘
```

### 绑定延迟模式 (VolumeBindingMode)

| 模式 | 说明 | 优点 | 缺点 |
|:---|:---|:---|:---|
| **Immediate** | PVC 创建时立即绑定 | 快速 | 可能跨可用区 |
| **WaitForFirstConsumer** | Pod 调度时绑定 | 拓扑感知 | 稍慢 |

```yaml
# 推荐：WaitForFirstConsumer 避免跨可用区问题
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: topology-aware-essd
provisioner: diskplugin.csi.alibabacloud.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: cloud_essd
  performanceLevel: PL1
allowedTopologies:
  - matchLabelExpressions:
      - key: topology.diskplugin.csi.alibabacloud.com/zone
        values:
          - cn-hangzhou-h
          - cn-hangzhou-i
```

---

## 7. Local PV 配置详解

### Local PV 架构特点

| 特性 | 说明 |
|:---|:---|
| **数据本地性** | 数据存储在节点本地磁盘，无网络开销 |
| **节点绑定** | Pod 必须调度到 PV 所在节点 |
| **无高可用** | 节点故障 = 数据不可用 |
| **手动管理** | 需要预先创建，不支持动态供给 |

### Local PV 完整配置

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-node1-ssd
  labels:
    storage-tier: nvme
spec:
  capacity:
    storage: 1Ti
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-nvme
  local:
    path: /mnt/disks/nvme0n1
  nodeAffinity:  # Local PV 必须配置
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - node-1
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-nvme
provisioner: kubernetes.io/no-provisioner  # 静态供给
volumeBindingMode: WaitForFirstConsumer    # 必须
reclaimPolicy: Retain
```

### Local PV 自动发现 (local-static-provisioner)

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: local-volume-provisioner
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: local-volume-provisioner
  template:
    metadata:
      labels:
        app: local-volume-provisioner
    spec:
      serviceAccountName: local-volume-provisioner
      containers:
        - name: provisioner
          image: registry.k8s.io/sig-storage/local-volume-provisioner:v2.5.0
          env:
            - name: MY_NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
          volumeMounts:
            - name: local-disks
              mountPath: /mnt/disks
              mountPropagation: HostToContainer
            - name: provisioner-config
              mountPath: /etc/provisioner/config
      volumes:
        - name: local-disks
          hostPath:
            path: /mnt/disks
        - name: provisioner-config
          configMap:
            name: local-provisioner-config
```

---

## 8. PV 监控与告警

### Prometheus 监控指标

| 指标 | 说明 | 告警阈值建议 |
|:---|:---|:---|
| `kube_persistentvolume_status_phase` | PV 状态分布 | Failed > 0 |
| `kube_persistentvolume_capacity_bytes` | PV 容量 | - |
| `kubelet_volume_stats_used_bytes` | 已使用空间 | > 85% |
| `kubelet_volume_stats_available_bytes` | 可用空间 | < 10Gi |
| `kubelet_volume_stats_inodes_used` | inode 使用量 | > 90% |

### 告警规则配置

```yaml
groups:
  - name: pv-alerts
    rules:
      - alert: PersistentVolumeFailed
        expr: kube_persistentvolume_status_phase{phase="Failed"} == 1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "PV {{ $labels.persistentvolume }} 状态异常"
          
      - alert: PersistentVolumeUsageHigh
        expr: |
          kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "PV 使用率超过 85%"
          
      - alert: PersistentVolumeInodeExhaustion
        expr: |
          kubelet_volume_stats_inodes_used / kubelet_volume_stats_inodes > 0.90
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "PV inode 使用率超过 90%"
```

---

## 9. 常见问题排查

### 问题诊断命令

```bash
# 查看 PV 状态
kubectl get pv -o wide

# 查看 PV 详情
kubectl describe pv <pv-name>

# 查看 PV 事件
kubectl get events --field-selector involvedObject.kind=PersistentVolume

# 查看 CSI 驱动日志
kubectl logs -n kube-system -l app=csi-provisioner --tail=100

# 检查节点存储状态
kubectl get csinodes
kubectl describe csinode <node-name>
```

### 常见问题与解决

| 问题 | 可能原因 | 解决方案 |
|:---|:---|:---|
| PV 一直 Pending | CSI 驱动未就绪 | 检查 CSI Pod 状态 |
| PVC 无法绑定 PV | 容量/访问模式不匹配 | 检查 PV 规格 |
| Pod 挂载失败 | 节点无权限访问存储 | 检查 IAM/安全组 |
| 删除 PV 卡住 | Finalizer 未清除 | 检查是否有残留引用 |
| 扩容失败 | 存储类型不支持 | 确认 CSI 支持 ExpandVolume |

---

## 10. 最佳实践清单

| 类别 | 建议 |
|:---|:---|
| **命名规范** | `{env}-{app}-{type}-{index}`，如 `prod-mysql-data-01` |
| **标签管理** | 添加 `env`、`app`、`backup` 等标签便于管理 |
| **回收策略** | 生产环境使用 `Retain`，测试环境可用 `Delete` |
| **绑定模式** | 使用 `WaitForFirstConsumer` 避免跨可用区 |
| **容量规划** | 预留 20% 余量，配置扩容告警 |
| **监控告警** | 监控使用率、inode、状态异常 |
| **定期备份** | Retain 策略 + VolumeSnapshot 定期快照 |

---

**表格底部标记**: Kusheet Project | 作者: Allen Galler (allengaller@gmail.com)
