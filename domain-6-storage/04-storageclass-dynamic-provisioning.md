# 138 - StorageClass 与动态存储供给 (StorageClass & Dynamic Provisioning)

> **适用版本**: Kubernetes v1.25 - v1.32 | **难度**: 高级 | **最后更新**: 2026-01

---

## 1. 动态供给工作流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         动态存储供给流程                                  │
└─────────────────────────────────────────────────────────────────────────┘

  用户创建 PVC                     PV Controller                CSI Driver
       │                              │                            │
       │  1. PVC 提交                 │                            │
       ├─────────────────────────────▶│                            │
       │                              │                            │
       │                              │  2. 查找匹配 StorageClass  │
       │                              ├───────────┐                │
       │                              │           │                │
       │                              │◀──────────┘                │
       │                              │                            │
       │                              │  3. 调用 CSI Provisioner   │
       │                              ├───────────────────────────▶│
       │                              │                            │
       │                              │                            │  4. 创建存储卷
       │                              │                            ├─────────────┐
       │                              │                            │             │
       │                              │                            │◀────────────┘
       │                              │                            │
       │                              │  5. 返回 Volume Handle     │
       │                              │◀───────────────────────────┤
       │                              │                            │
       │                              │  6. 创建 PV 对象           │
       │                              ├───────────┐                │
       │                              │           │                │
       │                              │◀──────────┘                │
       │                              │                            │
       │  7. 绑定 PVC-PV             │                            │
       │◀─────────────────────────────┤                            │
       │                              │                            │
```

---

## 2. StorageClass 规格字段详解

| 字段 | 类型 | 必填 | 说明 |
|:---|:---|:---:|:---|
| `provisioner` | string | 是 | CSI 驱动名称，如 `diskplugin.csi.alibabacloud.com` |
| `parameters` | map[string]string | 否 | 传递给 provisioner 的参数 |
| `reclaimPolicy` | string | 否 | 回收策略：Delete(默认)/Retain |
| `allowVolumeExpansion` | bool | 否 | 是否允许扩容 |
| `volumeBindingMode` | string | 否 | Immediate(默认)/WaitForFirstConsumer |
| `allowedTopologies` | []TopologySelectorTerm | 否 | 拓扑约束 |
| `mountOptions` | []string | 否 | 挂载选项 |

---

## 3. VolumeBindingMode 深度解析

### 3.1 Immediate 模式

```
PVC 创建 ──▶ 立即选择 PV/创建存储 ──▶ 绑定完成 ──▶ Pod 调度
                    │
                    ▼
              可能选择错误的可用区
              导致 Pod 调度失败
```

### 3.2 WaitForFirstConsumer 模式 (推荐)

```
PVC 创建 ──▶ 等待 Pod 调度 ──▶ 根据 Pod 节点选择存储 ──▶ 创建存储 ──▶ 绑定
                                        │
                                        ▼
                                  确保存储与 Pod 同可用区
```

### 对比表

| 特性 | Immediate | WaitForFirstConsumer |
|:---|:---|:---|
| 绑定时机 | PVC 创建时 | Pod 调度时 |
| 拓扑感知 | 否 | 是 |
| 跨可用区风险 | 高 | 无 |
| 适用场景 | 无拓扑要求 | 云环境、Local PV |

---

## 4. 多云平台 StorageClass 配置

### 4.1 阿里云 ACK

```yaml
# ESSD 云盘 - 高性能
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alicloud-disk-essd-pl2
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
  performanceLevel: PL2           # PL0/PL1/PL2/PL3
  fsType: ext4
  encrypted: "true"               # 加密
  kmsKeyId: ""                    # KMS 密钥(可选)
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
allowedTopologies:
  - matchLabelExpressions:
      - key: topology.diskplugin.csi.alibabacloud.com/zone
        values:
          - cn-hangzhou-h
          - cn-hangzhou-i
---
# NAS 文件存储 - 共享
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alicloud-nas-subpath
provisioner: nasplugin.csi.alibabacloud.com
parameters:
  volumeAs: subpath
  server: "xxx.cn-hangzhou.nas.aliyuncs.com:/share/"
  archiveOnDelete: "true"         # 删除时归档而非删除
mountOptions:
  - nolock
  - tcp
  - noresvport
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: Immediate
```

### 阿里云 ESSD 性能等级对比

| 等级 | 单盘最大 IOPS | 单盘最大吞吐(MB/s) | 单盘最大容量 | 适用场景 |
|:---:|:---:|:---:|:---:|:---|
| PL0 | 10,000 | 180 | 64Ti | 开发测试 |
| PL1 | 50,000 | 350 | 64Ti | 中小型数据库 |
| PL2 | 100,000 | 750 | 64Ti | 大型数据库 |
| PL3 | 1,000,000 | 4,000 | 64Ti | 核心交易系统 |

### 4.2 AWS EKS

```yaml
# gp3 通用 SSD
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"                    # 默认 3000，最大 16000
  throughput: "125"               # 默认 125 MB/s，最大 1000
  encrypted: "true"
  fsType: ext4
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# io2 高性能 SSD
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: io2-high-perf
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "64000"                   # 最大 64000
  encrypted: "true"
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
---
# EFS 共享文件系统
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-xxxxxxxxx
  directoryPerms: "700"
  basePath: "/dynamic_provisioning"
```

### 4.3 GCP GKE

```yaml
# pd-ssd 标准 SSD
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: pd-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd   # 区域复制
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# pd-extreme 极致性能
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: pd-extreme
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-extreme
  provisioned-iops-on-create: "100000"
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
```

### 4.4 Azure AKS

```yaml
# Premium SSD v2
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-premium-v2
provisioner: disk.csi.azure.com
parameters:
  skuName: PremiumV2_LRS
  DiskIOPSReadWrite: "5000"
  DiskMBpsReadWrite: "200"
  LogicalSectorSize: "4096"
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# Azure Files 共享
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-premium
provisioner: file.csi.azure.com
parameters:
  skuName: Premium_LRS
  shareName: myshare
reclaimPolicy: Delete
volumeBindingMode: Immediate
mountOptions:
  - dir_mode=0777
  - file_mode=0777
```

---

## 5. 拓扑约束配置

### 5.1 单可用区限制

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: zone-h-only
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
volumeBindingMode: WaitForFirstConsumer
allowedTopologies:
  - matchLabelExpressions:
      - key: topology.diskplugin.csi.alibabacloud.com/zone
        values:
          - cn-hangzhou-h
```

### 5.2 多可用区约束

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: multi-zone
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
volumeBindingMode: WaitForFirstConsumer
allowedTopologies:
  - matchLabelExpressions:
      - key: topology.diskplugin.csi.alibabacloud.com/zone
        values:
          - cn-hangzhou-h
          - cn-hangzhou-i
          - cn-hangzhou-j
```

### 5.3 区域复制存储 (跨可用区高可用)

```yaml
# GCP 区域持久磁盘
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: regional-pd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd
volumeBindingMode: WaitForFirstConsumer
allowedTopologies:
  - matchLabelExpressions:
      - key: topology.gke.io/zone
        values:
          - us-central1-a
          - us-central1-b
```

---

## 6. 默认 StorageClass 管理

### 6.1 设置默认 StorageClass

```bash
# 查看当前默认
kubectl get sc -o custom-columns='NAME:.metadata.name,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class'

# 设置默认
kubectl patch storageclass alicloud-disk-essd -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# 取消默认
kubectl patch storageclass old-default -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

### 6.2 禁用动态供给

```yaml
# PVC 指定空字符串禁用动态供给，必须静态绑定
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: manual-pvc
spec:
  storageClassName: ""  # 空字符串 = 禁用动态供给
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

---

## 7. 企业级 StorageClass 设计

### 7.1 分层存储策略

```yaml
# Tier-0: 极致性能 - 核心数据库
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tier0-ultra-performance
  labels:
    tier: "0"
    cost: high
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
  performanceLevel: PL3
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# Tier-1: 高性能 - 生产应用
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tier1-high-performance
  labels:
    tier: "1"
    cost: medium-high
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
  performanceLevel: PL1
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# Tier-2: 标准性能 - 一般应用
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tier2-standard
  labels:
    tier: "2"
    cost: medium
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
  performanceLevel: PL0
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# Tier-3: 经济型 - 归档/备份
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tier3-economy
  labels:
    tier: "3"
    cost: low
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_efficiency
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

### 7.2 按团队隔离

```yaml
# 团队 A 专用存储
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: team-a-storage
  labels:
    team: a
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
  performanceLevel: PL1
  # 可通过 ResourceQuota 限制使用量
---
# ResourceQuota 限制
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-a-storage-quota
  namespace: team-a
spec:
  hard:
    team-a-storage.storageclass.storage.k8s.io/requests.storage: "1Ti"
    team-a-storage.storageclass.storage.k8s.io/persistentvolumeclaims: "100"
```

---

## 8. 性能调优参数

### 8.1 挂载选项优化

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: optimized-sc
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
  performanceLevel: PL2
mountOptions:
  - noatime          # 禁用访问时间更新
  - nodiratime       # 禁用目录访问时间
  - discard          # 启用 TRIM (SSD)
  - data=ordered     # ext4 数据模式
  - barrier=0        # 禁用写屏障 (性能优先，风险)
```

### 8.2 文件系统选择

| 文件系统 | 优点 | 缺点 | 适用场景 |
|:---|:---|:---|:---|
| **ext4** | 稳定、通用 | 大文件性能一般 | 通用场景 |
| **xfs** | 大文件优秀、高并发 | 小文件稍弱 | 数据库、大数据 |
| **btrfs** | 快照、压缩 | 稳定性争议 | 开发测试 |

```yaml
# XFS 适合大文件和数据库
parameters:
  fsType: xfs

# ext4 通用场景
parameters:
  fsType: ext4
```

---

## 9. 监控与运维

### 9.1 监控指标

```yaml
# Prometheus 告警规则
groups:
  - name: storageclass-alerts
    rules:
      - alert: StorageClassProvisionFailed
        expr: |
          increase(storage_operation_errors_total{operation="provision"}[5m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "StorageClass 供给失败"
          
      - alert: StorageClassNoProvisioner
        expr: |
          kube_storageclass_info unless on(provisioner) kube_pod_info{namespace="kube-system"}
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "StorageClass provisioner 未运行"
```

### 9.2 运维命令

```bash
# 查看所有 StorageClass
kubectl get sc -o wide

# 查看 SC 详情
kubectl describe sc <name>

# 查看 CSI 驱动
kubectl get csidrivers

# 查看供给统计
kubectl get pvc -A --no-headers | awk '{print $6}' | sort | uniq -c

# 查看失败的 PVC
kubectl get pvc -A --field-selector status.phase=Pending
```

---

## 10. 最佳实践清单

| 类别 | 建议 |
|:---|:---|
| **绑定模式** | 云环境必须使用 `WaitForFirstConsumer` |
| **回收策略** | 生产 Retain，测试 Delete |
| **拓扑约束** | 配置 allowedTopologies 避免跨可用区 |
| **扩容支持** | 启用 allowVolumeExpansion |
| **分层设计** | 按性能/成本分 3-4 个层级 |
| **默认 SC** | 设置合理的默认 StorageClass |
| **命名规范** | `{cloud}-{type}-{level}`，如 `alicloud-essd-pl1` |
| **监控告警** | 监控供给失败、CSI 驱动状态 |

---

**表格底部标记**: Kusheet Project | 作者: Allen Galler (allengaller@gmail.com)
