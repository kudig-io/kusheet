# 137 - PersistentVolumeClaim 使用模式与最佳实践 (PVC Patterns & Practices)

> **适用版本**: Kubernetes v1.25 - v1.32 | **难度**: 高级 | **最后更新**: 2026-01

---

## 1. PVC 设计架构

```
┌────────────────────────────────────────────────────────────────┐
│                    开发者视角 (Developer)                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  PVC: "我需要 100Gi 存储，支持读写，性能要求高"          │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                    平台视角 (Platform)                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  StorageClass: "high-performance → ESSD PL2 + 拓扑感知" │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                    基础设施视角 (Infrastructure)                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  CSI Driver → 云厂商 API → 创建/挂载/扩容/快照           │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

---

## 2. PVC 规格字段详解

| 字段 | 类型 | 必填 | 说明 |
|:---|:---|:---:|:---|
| `accessModes` | []string | 是 | 访问模式：RWO/ROX/RWX/RWOP |
| `resources.requests.storage` | Quantity | 是 | 请求的存储容量 |
| `resources.limits.storage` | Quantity | 否 | 存储容量上限（通常不设） |
| `storageClassName` | string | 否 | 指定 StorageClass，空字符串禁用动态供给 |
| `volumeMode` | string | 否 | Filesystem(默认) / Block |
| `volumeName` | string | 否 | 指定绑定的 PV 名称（静态绑定） |
| `selector` | LabelSelector | 否 | 通过标签选择 PV |
| `dataSource` | TypedLocalObjectReference | 否 | 克隆/恢复数据源 |
| `dataSourceRef` | TypedObjectReference | 否 | 跨命名空间数据源(v1.26+) |

---

## 3. PVC 使用模式

### 模式一：动态供给 (Dynamic Provisioning) - 推荐

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-data
  namespace: production
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: alicloud-disk-essd  # 指定 StorageClass
  resources:
    requests:
      storage: 100Gi
```

### 模式二：静态绑定 (Static Binding)

```yaml
# 预先创建 PV
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-data-pv
spec:
  capacity:
    storage: 500Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""  # 空字符串表示静态
  nfs:
    server: 10.0.0.100
    path: /exports/data
---
# PVC 绑定指定 PV
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-data
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ""  # 必须为空
  volumeName: nfs-data-pv  # 指定 PV
  resources:
    requests:
      storage: 500Gi
```

### 模式三：标签选择器绑定 (Selector Binding)

```yaml
# PV 带标签
apiVersion: v1
kind: PersistentVolume
metadata:
  name: fast-ssd-pv-01
  labels:
    storage-tier: fast
    region: cn-hangzhou
spec:
  capacity:
    storage: 200Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: manual
  local:
    path: /mnt/ssd
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values: ["node-1"]
---
# PVC 通过选择器匹配
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: manual
  selector:
    matchLabels:
      storage-tier: fast
    matchExpressions:
      - key: region
        operator: In
        values: ["cn-hangzhou", "cn-shanghai"]
  resources:
    requests:
      storage: 100Gi
```

---

## 4. PVC 与 Pod 绑定模式

### 方式一：直接挂载

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mysql
spec:
  containers:
    - name: mysql
      image: mysql:8.0
      volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: mysql-data
```

### 方式二：StatefulSet volumeClaimTemplates (推荐有状态应用)

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
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
  volumeClaimTemplates:  # 自动为每个 Pod 创建 PVC
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: alicloud-disk-essd
        resources:
          requests:
            storage: 100Gi
# 自动创建: data-mysql-0, data-mysql-1, data-mysql-2
```

### 方式三：多 Pod 共享 PVC (RWX)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 5
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.24
          volumeMounts:
            - name: shared-data
              mountPath: /usr/share/nginx/html
      volumes:
        - name: shared-data
          persistentVolumeClaim:
            claimName: shared-nas  # 必须是 RWX
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-nas
spec:
  accessModes:
    - ReadWriteMany  # 多 Pod 共享
  storageClassName: alicloud-nas
  resources:
    requests:
      storage: 100Gi
```

---

## 5. PVC 高级配置

### 5.1 基于快照创建 PVC (克隆)

```yaml
# 创建快照
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: mysql-snapshot-20260118
spec:
  volumeSnapshotClassName: alicloud-disk-snapshot
  source:
    persistentVolumeClaimName: mysql-data
---
# 从快照恢复
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-data-restored
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: alicloud-disk-essd
  resources:
    requests:
      storage: 100Gi  # 必须 >= 源 PVC
  dataSource:
    name: mysql-snapshot-20260118
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

### 5.2 PVC 克隆 (Volume Cloning)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-data-clone
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: alicloud-disk-essd
  resources:
    requests:
      storage: 100Gi
  dataSource:
    name: mysql-data  # 源 PVC
    kind: PersistentVolumeClaim
```

### 5.3 临时卷 (Ephemeral Volumes) - v1.25+

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: data-processor
spec:
  containers:
    - name: processor
      image: data-processor:v1
      volumeMounts:
        - name: scratch
          mountPath: /tmp/work
  volumes:
    - name: scratch
      ephemeral:  # 临时卷，Pod 删除时自动清理
        volumeClaimTemplate:
          spec:
            accessModes: ["ReadWriteOnce"]
            storageClassName: alicloud-disk-efficiency
            resources:
              requests:
                storage: 50Gi
```

---

## 6. PVC 容量管理

### 6.1 在线扩容 (Volume Expansion)

```yaml
# StorageClass 必须支持扩容
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: expandable-essd
provisioner: diskplugin.csi.alibabacloud.com
allowVolumeExpansion: true  # 启用扩容
parameters:
  type: cloud_essd
```

```bash
# 扩容 PVC
kubectl patch pvc mysql-data -p '{"spec":{"resources":{"requests":{"storage":"200Gi"}}}}'

# 查看扩容状态
kubectl get pvc mysql-data -o jsonpath='{.status.conditions}'

# 等待扩容完成
kubectl wait --for=condition=FileSystemResizePending pvc/mysql-data --timeout=300s
```

### 6.2 扩容状态检查

| Condition | 含义 |
|:---|:---|
| `FileSystemResizePending` | 底层卷已扩容，等待文件系统扩展 |
| `Resizing` | 正在扩容中 |
| 无 condition | 扩容完成 |

### 6.3 扩容失败回滚

```bash
# 如果扩容失败，需要恢复原始大小
# 注意：不是所有存储都支持缩容

# 方案一：从备份恢复
kubectl apply -f mysql-snapshot-restore.yaml

# 方案二：手动清理（危险）
kubectl patch pvc mysql-data -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'
```

---

## 7. 资源配额与限制

### 7.1 命名空间存储配额

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storage-quota
  namespace: team-a
spec:
  hard:
    requests.storage: "1Ti"                           # 总存储限制
    persistentvolumeclaims: "50"                      # PVC 数量限制
    alicloud-disk-essd.storageclass.storage.k8s.io/requests.storage: "500Gi"  # 指定 SC 限制
    alicloud-disk-essd.storageclass.storage.k8s.io/persistentvolumeclaims: "20"
```

### 7.2 LimitRange 限制单个 PVC

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: storage-limits
  namespace: team-a
spec:
  limits:
    - type: PersistentVolumeClaim
      max:
        storage: 100Gi    # 单个 PVC 最大
      min:
        storage: 1Gi      # 单个 PVC 最小
      default:
        storage: 10Gi     # 默认值
```

---

## 8. 多场景 PVC 模板

### 8.1 MySQL 高可用集群

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-cluster
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
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: mysql
              topologyKey: kubernetes.io/hostname
      containers:
        - name: mysql
          image: mysql:8.0
          resources:
            requests:
              memory: "4Gi"
              cpu: "2"
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
            - name: log
              mountPath: /var/log/mysql
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: alicloud-disk-essd-pl2  # 高性能
        resources:
          requests:
            storage: 200Gi
    - metadata:
        name: log
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: alicloud-disk-efficiency  # 日志用普通盘
        resources:
          requests:
            storage: 50Gi
```

### 8.2 Elasticsearch 冷热分离

```yaml
# Hot 节点 - 高性能 SSD
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: es-hot
spec:
  replicas: 3
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: alicloud-disk-essd-pl2
        resources:
          requests:
            storage: 500Gi
---
# Warm 节点 - 普通 SSD
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: es-warm
spec:
  replicas: 2
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: alicloud-disk-essd-pl0
        resources:
          requests:
            storage: 2Ti
---
# Cold 节点 - 高效云盘
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: es-cold
spec:
  replicas: 2
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: alicloud-disk-efficiency
        resources:
          requests:
            storage: 10Ti
```

### 8.3 AI/ML 训练数据集

```yaml
# 共享训练数据集 (NAS)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: training-dataset
  namespace: ml-platform
spec:
  accessModes:
    - ReadOnlyMany  # 多训练 Pod 只读共享
  storageClassName: alicloud-nas-extreme  # 极速 NAS
  resources:
    requests:
      storage: 10Ti
---
# 模型输出目录 (每个任务独立)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: model-output-job-001
  namespace: ml-platform
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: alicloud-disk-essd-pl1
  resources:
    requests:
      storage: 100Gi
```

---

## 9. 故障排查

### 9.1 PVC 状态诊断流程

```
PVC Pending?
    │
    ├── StorageClass 存在? ──No──▶ 创建 StorageClass 或修正名称
    │
    ├── CSI Driver 就绪? ──No──▶ kubectl get pods -n kube-system | grep csi
    │
    ├── 配额充足? ──No──▶ kubectl describe quota -n <ns>
    │
    ├── 节点有符合拓扑? ──No──▶ 检查 allowedTopologies
    │
    └── 检查 Events ──▶ kubectl describe pvc <name>
```

### 9.2 常用诊断命令

```bash
# 查看 PVC 状态
kubectl get pvc -A -o wide

# 查看 PVC 详情
kubectl describe pvc <name> -n <namespace>

# 查看绑定的 PV
kubectl get pv $(kubectl get pvc <name> -o jsonpath='{.spec.volumeName}')

# 检查存储配额
kubectl describe resourcequota -n <namespace>

# 查看 CSI 驱动状态
kubectl get csidrivers
kubectl get csinodes

# 查看存储相关事件
kubectl get events --field-selector reason=ProvisioningFailed
kubectl get events --field-selector reason=FailedMount
```

### 9.3 常见问题与解决

| 问题 | 原因 | 解决方案 |
|:---|:---|:---|
| PVC 一直 Pending | StorageClass 不存在 | 检查 SC 名称拼写 |
| PVC 一直 Pending | CSI 驱动未就绪 | 检查 CSI Pod 状态 |
| PVC 一直 Pending | 存储配额不足 | 扩大配额或清理资源 |
| PVC Bound 但 Pod 挂载失败 | 跨可用区 | 使用 WaitForFirstConsumer |
| 扩容后容量未变 | 需要重启 Pod | 删除 Pod 触发重新挂载 |
| 删除 PVC 卡住 | 有 Pod 仍在使用 | 先删除使用该 PVC 的 Pod |

---

## 10. 最佳实践清单

| 类别 | 建议 |
|:---|:---|
| **命名规范** | `{app}-{type}-{env}`，如 `mysql-data-prod` |
| **StorageClass** | 根据性能需求选择，不要使用 default |
| **容量规划** | 预留 30% 余量，配置扩容告警 |
| **访问模式** | 明确需求，RWO 性能最优 |
| **StatefulSet** | 有状态应用使用 volumeClaimTemplates |
| **备份策略** | 定期 VolumeSnapshot，保留多版本 |
| **监控告警** | 容量 > 80%、inode > 90% 告警 |
| **回收策略** | 生产 Retain，测试可 Delete |

---

**表格底部标记**: Kusheet Project | 作者: Allen Galler (allengaller@gmail.com)
