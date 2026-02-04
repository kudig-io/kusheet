# 139 - CSI 驱动开发与集成 (CSI Drivers Integration)

> **适用版本**: Kubernetes v1.25 - v1.32 | **难度**: 专家级 | **最后更新**: 2026-01

---

## 1. CSI 架构概览

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Kubernetes 集群                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                     Control Plane                                │   │
│   │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐        │   │
│   │  │  API Server   │  │  Controller   │  │   Scheduler   │        │   │
│   │  │               │  │   Manager     │  │               │        │   │
│   │  └───────┬───────┘  └───────────────┘  └───────────────┘        │   │
│   │          │                                                       │   │
│   └──────────┼───────────────────────────────────────────────────────┘   │
│              │                                                           │
│   ┌──────────┼───────────────────────────────────────────────────────┐   │
│   │          ▼                CSI Controller                         │   │
│   │  ┌─────────────────────────────────────────────────────────────┐ │   │
│   │  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │ │   │
│   │  │  │ Provisioner │ │  Attacher   │ │  Resizer    │           │ │   │
│   │  │  │  Sidecar    │ │  Sidecar    │ │  Sidecar    │           │ │   │
│   │  │  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘           │ │   │
│   │  │         │               │               │                   │ │   │
│   │  │         └───────────────┼───────────────┘                   │ │   │
│   │  │                         │                                   │ │   │
│   │  │                  ┌──────▼──────┐                            │ │   │
│   │  │                  │ CSI Driver  │                            │ │   │
│   │  │                  │ Controller  │                            │ │   │
│   │  │                  │   Plugin    │                            │ │   │
│   │  │                  └─────────────┘                            │ │   │
│   │  └─────────────────────────────────────────────────────────────┘ │   │
│   └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│   ┌──────────────────────────────────────────────────────────────────┐   │
│   │                        Node (DaemonSet)                          │   │
│   │  ┌─────────────────────────────────────────────────────────────┐ │   │
│   │  │  ┌─────────────┐  ┌─────────────┐                           │ │   │
│   │  │  │ Registrar   │  │ CSI Driver  │                           │ │   │
│   │  │  │  Sidecar    │  │ Node Plugin │◀────▶ Storage Backend    │ │   │
│   │  │  └─────────────┘  └─────────────┘                           │ │   │
│   │  └─────────────────────────────────────────────────────────────┘ │   │
│   │                                                                  │   │
│   │  ┌─────────────┐                                                 │   │
│   │  │   Kubelet   │ ◀────▶ /var/lib/kubelet/plugins/              │   │
│   │  └─────────────┘                                                 │   │
│   └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. CSI 组件职责

| 组件 | 部署方式 | 职责 |
|:---|:---|:---|
| **external-provisioner** | Deployment | 监听 PVC，调用 CreateVolume |
| **external-attacher** | Deployment | 监听 VolumeAttachment，调用 Attach/Detach |
| **external-resizer** | Deployment | 监听 PVC 扩容，调用 ExpandVolume |
| **external-snapshotter** | Deployment | 监听 VolumeSnapshot，调用 CreateSnapshot |
| **node-driver-registrar** | DaemonSet | 向 kubelet 注册 CSI 驱动 |
| **livenessprobe** | Sidecar | CSI 驱动健康检查 |
| **CSI Driver** | 自定义 | 实现存储后端操作 |

---

## 3. CSI 服务接口规范

### 3.1 Identity Service

| RPC | 说明 |
|:---|:---|
| `GetPluginInfo` | 返回驱动名称和版本 |
| `GetPluginCapabilities` | 返回驱动支持的能力 |
| `Probe` | 健康检查 |

### 3.2 Controller Service

| RPC | 说明 | 触发场景 |
|:---|:---|:---|
| `CreateVolume` | 创建存储卷 | PVC 创建 |
| `DeleteVolume` | 删除存储卷 | PVC/PV 删除 |
| `ControllerPublishVolume` | 挂载卷到节点 | Pod 调度 |
| `ControllerUnpublishVolume` | 从节点卸载卷 | Pod 删除 |
| `ValidateVolumeCapabilities` | 验证卷能力 | - |
| `ListVolumes` | 列出所有卷 | - |
| `GetCapacity` | 获取可用容量 | - |
| `ControllerExpandVolume` | 扩容卷 | PVC 扩容 |
| `CreateSnapshot` | 创建快照 | VolumeSnapshot |
| `DeleteSnapshot` | 删除快照 | VolumeSnapshot 删除 |
| `ListSnapshots` | 列出快照 | - |

### 3.3 Node Service

| RPC | 说明 | 触发场景 |
|:---|:---|:---|
| `NodeStageVolume` | 准备卷（格式化、挂载到暂存目录） | Pod 调度 |
| `NodeUnstageVolume` | 清理暂存目录 | Pod 删除 |
| `NodePublishVolume` | 挂载到 Pod 目录 | Pod 启动 |
| `NodeUnpublishVolume` | 从 Pod 目录卸载 | Pod 删除 |
| `NodeGetVolumeStats` | 获取卷统计信息 | kubelet 监控 |
| `NodeExpandVolume` | 节点侧扩容 | 文件系统扩展 |
| `NodeGetCapabilities` | 获取节点能力 | - |
| `NodeGetInfo` | 获取节点信息 | - |

---

## 4. 阿里云 CSI 驱动部署

### 4.1 Controller 部署

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: csi-provisioner
  namespace: kube-system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: csi-provisioner
  template:
    metadata:
      labels:
        app: csi-provisioner
    spec:
      serviceAccountName: csi-admin
      priorityClassName: system-cluster-critical
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
      containers:
        # Provisioner Sidecar
        - name: external-provisioner
          image: registry.cn-hangzhou.aliyuncs.com/acs/csi-provisioner:v3.5.0
          args:
            - --csi-address=/csi/csi.sock
            - --feature-gates=Topology=true
            - --volume-name-prefix=pv
            - --strict-topology=true
            - --timeout=150s
            - --leader-election=true
            - --retry-interval-start=500ms
            - --default-fstype=ext4
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
              
        # Attacher Sidecar
        - name: external-attacher
          image: registry.cn-hangzhou.aliyuncs.com/acs/csi-attacher:v4.3.0
          args:
            - --csi-address=/csi/csi.sock
            - --leader-election=true
            - --timeout=120s
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
              
        # Resizer Sidecar
        - name: external-resizer
          image: registry.cn-hangzhou.aliyuncs.com/acs/csi-resizer:v1.8.0
          args:
            - --csi-address=/csi/csi.sock
            - --leader-election=true
            - --timeout=120s
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
              
        # Snapshotter Sidecar
        - name: external-snapshotter
          image: registry.cn-hangzhou.aliyuncs.com/acs/csi-snapshotter:v6.2.1
          args:
            - --csi-address=/csi/csi.sock
            - --leader-election=true
            - --snapshot-name-prefix=snap
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
              
        # CSI Driver Plugin
        - name: csi-plugin
          image: registry.cn-hangzhou.aliyuncs.com/acs/csi-plugin:v1.26.0
          args:
            - --endpoint=unix:///csi/csi.sock
            - --driver=diskplugin.csi.alibabacloud.com,nasplugin.csi.alibabacloud.com
          env:
            - name: ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: aliyun-csi-secret
                  key: access-key-id
            - name: ACCESS_KEY_SECRET
              valueFrom:
                secretKeyRef:
                  name: aliyun-csi-secret
                  key: access-key-secret
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
              
      volumes:
        - name: socket-dir
          emptyDir: {}
```

### 4.2 Node DaemonSet 部署

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: csi-node
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: csi-node
  template:
    metadata:
      labels:
        app: csi-node
    spec:
      serviceAccountName: csi-node
      priorityClassName: system-node-critical
      hostNetwork: true
      hostPID: true
      containers:
        # Node Registrar
        - name: node-driver-registrar
          image: registry.cn-hangzhou.aliyuncs.com/acs/csi-node-driver-registrar:v2.8.0
          args:
            - --csi-address=/csi/csi.sock
            - --kubelet-registration-path=/var/lib/kubelet/plugins/diskplugin.csi.alibabacloud.com/csi.sock
          volumeMounts:
            - name: plugin-dir
              mountPath: /csi
            - name: registration-dir
              mountPath: /registration
              
        # Liveness Probe
        - name: liveness-probe
          image: registry.cn-hangzhou.aliyuncs.com/acs/livenessprobe:v2.10.0
          args:
            - --csi-address=/csi/csi.sock
            - --health-port=9808
          volumeMounts:
            - name: plugin-dir
              mountPath: /csi
              
        # CSI Node Plugin
        - name: csi-plugin
          image: registry.cn-hangzhou.aliyuncs.com/acs/csi-plugin:v1.26.0
          args:
            - --endpoint=unix:///csi/csi.sock
            - --driver=diskplugin.csi.alibabacloud.com
            - --nodeid=$(NODE_ID)
          env:
            - name: NODE_ID
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
          securityContext:
            privileged: true
          volumeMounts:
            - name: plugin-dir
              mountPath: /csi
            - name: pods-mount-dir
              mountPath: /var/lib/kubelet
              mountPropagation: Bidirectional
            - name: host-dev
              mountPath: /dev
            - name: host-sys
              mountPath: /sys
              
      volumes:
        - name: plugin-dir
          hostPath:
            path: /var/lib/kubelet/plugins/diskplugin.csi.alibabacloud.com
            type: DirectoryOrCreate
        - name: registration-dir
          hostPath:
            path: /var/lib/kubelet/plugins_registry
            type: Directory
        - name: pods-mount-dir
          hostPath:
            path: /var/lib/kubelet
            type: Directory
        - name: host-dev
          hostPath:
            path: /dev
        - name: host-sys
          hostPath:
            path: /sys
```

---

## 5. CSI 驱动能力矩阵

| CSI 驱动 | 供应商 | 动态供给 | 扩容 | 快照 | 克隆 | 拓扑感知 |
|:---|:---|:---:|:---:|:---:|:---:|:---:|
| **diskplugin.csi.alibabacloud.com** | 阿里云 | ✅ | ✅ | ✅ | ✅ | ✅ |
| **nasplugin.csi.alibabacloud.com** | 阿里云 | ✅ | ✅ | ❌ | ❌ | ❌ |
| **ebs.csi.aws.com** | AWS | ✅ | ✅ | ✅ | ✅ | ✅ |
| **efs.csi.aws.com** | AWS | ✅ | ❌ | ❌ | ❌ | ❌ |
| **pd.csi.storage.gke.io** | GCP | ✅ | ✅ | ✅ | ✅ | ✅ |
| **disk.csi.azure.com** | Azure | ✅ | ✅ | ✅ | ✅ | ✅ |
| **file.csi.azure.com** | Azure | ✅ | ✅ | ❌ | ❌ | ❌ |
| **csi.vsphere.vmware.com** | VMware | ✅ | ✅ | ✅ | ✅ | ✅ |
| **rbd.csi.ceph.com** | Ceph RBD | ✅ | ✅ | ✅ | ✅ | ❌ |
| **cephfs.csi.ceph.com** | CephFS | ✅ | ✅ | ✅ | ✅ | ❌ |

---

## 6. VolumeSnapshot 管理

### 6.1 VolumeSnapshotClass

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: alicloud-disk-snapshot
driver: diskplugin.csi.alibabacloud.com
deletionPolicy: Delete  # Delete/Retain
parameters:
  # 阿里云快照参数
  snapshotType: standard  # standard/flash
  instantAccess: "true"   # 即时可用
  retentionDays: "30"     # 保留天数
```

### 6.2 创建快照

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: mysql-data-snapshot-20260118
  namespace: production
  labels:
    app: mysql
    backup-type: daily
spec:
  volumeSnapshotClassName: alicloud-disk-snapshot
  source:
    persistentVolumeClaimName: mysql-data
```

### 6.3 定时快照 (CronJob)

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-snapshot
  namespace: production
spec:
  schedule: "0 2 * * *"  # 每天凌晨 2 点
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: snapshot-creator
          containers:
            - name: snapshot-creator
              image: bitnami/kubectl:1.28
              command:
                - /bin/bash
                - -c
                - |
                  DATE=$(date +%Y%m%d)
                  cat <<EOF | kubectl apply -f -
                  apiVersion: snapshot.storage.k8s.io/v1
                  kind: VolumeSnapshot
                  metadata:
                    name: mysql-data-snapshot-${DATE}
                    namespace: production
                  spec:
                    volumeSnapshotClassName: alicloud-disk-snapshot
                    source:
                      persistentVolumeClaimName: mysql-data
                  EOF
                  
                  # 清理 7 天前的快照
                  kubectl get volumesnapshot -n production -o name | \
                    xargs -I{} sh -c 'kubectl get {} -o jsonpath="{.metadata.creationTimestamp}" | \
                    xargs -I@ sh -c "[ \$(( \$(date +%s) - \$(date -d @ +%s) )) -gt 604800 ] && kubectl delete {}"'
          restartPolicy: OnFailure
```

### 6.4 从快照恢复

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-data-restored
  namespace: production
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: alicloud-disk-essd
  resources:
    requests:
      storage: 100Gi
  dataSource:
    name: mysql-data-snapshot-20260118
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

---

## 7. CSI 驱动健康检查

### 7.1 检查命令

```bash
# 查看 CSI 驱动注册状态
kubectl get csidrivers

# 查看节点 CSI 状态
kubectl get csinodes -o wide

# 查看 CSI 驱动详情
kubectl describe csidriver diskplugin.csi.alibabacloud.com

# 查看 CSI Controller Pod 状态
kubectl get pods -n kube-system -l app=csi-provisioner

# 查看 CSI Node Pod 状态
kubectl get pods -n kube-system -l app=csi-node -o wide

# 检查 CSI Socket
kubectl exec -n kube-system csi-node-xxxxx -c csi-plugin -- ls -la /csi/csi.sock

# CSI 驱动日志
kubectl logs -n kube-system -l app=csi-provisioner -c csi-plugin --tail=100
kubectl logs -n kube-system -l app=csi-node -c csi-plugin --tail=100
```

### 7.2 常见问题诊断

| 问题 | 可能原因 | 诊断命令 |
|:---|:---|:---|
| CSI 驱动未注册 | Node plugin 未启动 | `kubectl get csinodes` |
| 供给失败 | 权限/配额问题 | `kubectl logs csi-provisioner` |
| 挂载失败 | 节点无权限 | `kubectl logs csi-node` |
| 快照失败 | Snapshotter 未部署 | `kubectl get pods -l app=csi-snapshotter` |
| 扩容失败 | 不支持扩容 | 检查 StorageClass `allowVolumeExpansion` |

---

## 8. CSI 最佳实践

| 类别 | 建议 |
|:---|:---|
| **高可用** | Controller 部署 2+ 副本，启用 leader-election |
| **权限** | 使用最小权限 ServiceAccount |
| **监控** | 配置 livenessprobe，监控 CSI 指标 |
| **日志** | 设置合适的日志级别，配置日志收集 |
| **版本** | 使用与 K8s 版本兼容的 CSI sidecar |
| **拓扑** | 启用 topology 特性，避免跨可用区 |
| **超时** | 根据存储后端调整超时时间 |
| **重试** | 配置合理的重试策略 |

---

**表格底部标记**: Kusheet Project | 作者: Allen Galler (allengaller@gmail.com)
