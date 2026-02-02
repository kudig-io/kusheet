# CSI 存储驱动故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32, CSI Spec v1.8+ | **最后更新**: 2026-01 | **难度**: 高级
>
> **版本说明**:
> - v1.25+ VolumeAttributesClass (Alpha) 支持动态卷属性修改
> - v1.27+ ReadWriteOncePod AccessMode GA
> - v1.29+ VolumeGroupSnapshot (Alpha)
> - v1.31+ VolumeAttributesClass 进入 Beta

## 概述

Container Storage Interface (CSI) 是 Kubernetes 存储扩展的标准接口，用于连接各种存储后端（云存储、NFS、Ceph、本地存储等）。本文档覆盖 CSI 驱动相关故障的诊断与解决方案。

---

## 第一部分：问题现象与影响分析

### 1.1 CSI 架构

```
┌─────────────────────────────────────────────────────────────────┐
│                      CSI 架构                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────┐    ┌────────────────────┐               │
│  │  CSI Controller    │    │    CSI Node        │               │
│  │  (Deployment)      │    │    (DaemonSet)     │               │
│  └─────────┬──────────┘    └─────────┬──────────┘               │
│            │                         │                           │
│            ▼                         ▼                           │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    CSI Sidecar 容器                       │   │
│  ├────────────────┬──────────────┬──────────────────────────┤   │
│  │ csi-provisioner│ csi-attacher │ csi-snapshotter          │   │
│  │ (动态供应 PV)   │ (挂载/卸载)   │ (快照管理)               │   │
│  ├────────────────┼──────────────┼──────────────────────────┤   │
│  │ csi-resizer    │ csi-node-    │ livenessprobe            │   │
│  │ (扩容)         │ registrar    │ (健康检查)               │   │
│  └────────────────┴──────────────┴──────────────────────────┘   │
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   存储后端                                │   │
│  │   AWS EBS | GCP PD | Azure Disk | Ceph | NFS | ...       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 错误信息示例 | 查看方式 |
|---------|---------|-------------|---------|
| PVC Pending | PVC 无法绑定 | `waiting for a volume to be created` | `kubectl get pvc` |
| 卷挂载失败 | Pod ContainerCreating | `MountVolume.SetUp failed` | `kubectl describe pod` |
| 卷卸载失败 | Pod Terminating 卡住 | `UnmountVolume failed` | `kubectl describe pod` |
| CSI 驱动不可用 | 所有操作失败 | `CSI driver not found` | `kubectl get csidrivers` |
| 扩容失败 | PVC 容量不变 | `failed to expand volume` | `kubectl describe pvc` |
| 快照失败 | VolumeSnapshot 未就绪 | `snapshot creation failed` | `kubectl describe vs` |
| 多挂载冲突 | 卷被多个节点挂载 | `Multi-Attach error` | `kubectl describe pod` |

### 1.3 CSI 组件职责

| 组件 | 部署方式 | 职责 |
|-----|---------|-----|
| csi-provisioner | Controller | 监听 PVC，调用 CreateVolume 创建卷 |
| csi-attacher | Controller | 监听 VolumeAttachment，调用 ControllerPublish |
| csi-node-driver-registrar | Node | 向 kubelet 注册 CSI 驱动 |
| csi-snapshotter | Controller | 管理 VolumeSnapshot |
| csi-resizer | Controller | 处理 PVC 扩容请求 |
| livenessprobe | Both | CSI 驱动健康检查 |

### 1.4 影响分析

| 故障类型 | 直接影响 | 间接影响 | 影响范围 |
|---------|---------|---------|---------|
| CSI Controller 故障 | 无法创建/删除卷 | 新 PVC 无法绑定 | 使用该 StorageClass 的所有新 PVC |
| CSI Node 故障 | 无法挂载卷 | Pod 无法启动 | 该节点上需要挂载卷的 Pod |
| 存储后端故障 | 所有存储操作失败 | 数据不可用 | 使用该存储后端的所有 Pod |
| 驱动注册失败 | kubelet 无法识别 CSI | 卷操作全部失败 | 整个集群的存储功能 |

---

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
CSI 存储故障
      │
      ├─── PVC Pending？
      │         │
      │         ├─ StorageClass 存在？ ──→ 检查 SC 配置
      │         ├─ CSI Controller 运行？ ──→ 检查 provisioner Pod
      │         ├─ 后端配额/容量？ ──→ 检查存储后端
      │         └─ 参数错误？ ──→ 检查 SC 参数
      │
      ├─── 挂载失败？
      │         │
      │         ├─ CSI Node 运行？ ──→ 检查 DaemonSet
      │         ├─ 驱动已注册？ ──→ 检查 node registrar
      │         ├─ VolumeAttachment？ ──→ 检查 attacher
      │         └─ 节点权限/网络？ ──→ 检查节点连接
      │
      └─── 卸载/删除问题？
                │
                ├─ Finalizer 阻塞？ ──→ 检查/移除 finalizer
                ├─ 卷仍在使用？ ──→ 检查 Pod 状态
                └─ 后端清理失败？ ──→ 检查后端日志
```

### 2.2 排查命令集

#### 2.2.1 CSI 驱动检查

```bash
# 查看已注册的 CSI 驱动
kubectl get csidrivers

# 查看 CSI 驱动详情
kubectl describe csidriver <driver-name>

# 查看 CSI Node 信息
kubectl get csinodes
kubectl describe csinode <node-name>

# 检查 CSI Controller Pod
kubectl get pods -n <csi-namespace> -l app=<csi-controller>
kubectl logs -n <csi-namespace> <csi-controller-pod> -c csi-provisioner

# 检查 CSI Node Pod
kubectl get pods -n <csi-namespace> -l app=<csi-node> -o wide
kubectl logs -n <csi-namespace> <csi-node-pod> -c <driver-container>
```

#### 2.2.2 StorageClass 检查

```bash
# 查看 StorageClass
kubectl get storageclass

# 查看默认 StorageClass
kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'

# 查看 StorageClass 详情
kubectl describe storageclass <name>

# 检查 provisioner
kubectl get storageclass <name> -o jsonpath='{.provisioner}'
```

#### 2.2.3 PVC/PV 检查

```bash
# 查看 PVC 状态
kubectl get pvc -n <namespace>

# 查看 PVC 详情和事件
kubectl describe pvc <name> -n <namespace>

# 查看 PV
kubectl get pv

# 查看 PV 详情
kubectl describe pv <name>

# 检查 PV 的 CSI 信息
kubectl get pv <name> -o jsonpath='{.spec.csi}'
```

#### 2.2.4 VolumeAttachment 检查

```bash
# 查看 VolumeAttachment
kubectl get volumeattachment

# 查看详情
kubectl describe volumeattachment <name>

# 查看特定 PV 的 attachment
kubectl get volumeattachment -o jsonpath='{.items[?(@.spec.source.persistentVolumeName=="<pv-name>")]}'
```

#### 2.2.5 节点存储检查

```bash
# 检查节点上的 CSI 插件 socket
kubectl debug node/<node> -it --image=busybox -- ls -la /host/var/lib/kubelet/plugins/

# 检查 CSI 插件注册
kubectl debug node/<node> -it --image=busybox -- ls -la /host/var/lib/kubelet/plugins_registry/

# 检查挂载点
kubectl debug node/<node> -it --image=busybox -- mount | grep csi
```

### 2.3 排查注意事项

| 注意事项 | 说明 |
|---------|-----|
| 日志位置 | CSI 驱动日志在 sidecar 容器和主容器中 |
| Socket 路径 | CSI socket 在 /var/lib/kubelet/plugins/<driver>/csi.sock |
| 驱动注册 | node-driver-registrar 负责向 kubelet 注册 |
| Finalizer | PVC/PV 有 finalizer 防止误删除 |
| 访问模式 | ReadWriteOnce/ReadWriteMany 影响多节点挂载 |

---

## 第三部分：解决方案与风险控制

### 3.1 PVC 创建问题

#### 场景 1：PVC Pending - StorageClass 不存在

**问题现象：**
```
Events:
  Warning  ProvisioningFailed  storageclass.storage.k8s.io "fast-ssd" not found
```

**解决步骤：**

```bash
# 1. 检查 PVC 使用的 StorageClass
kubectl get pvc <name> -o jsonpath='{.spec.storageClassName}'

# 2. 查看可用的 StorageClass
kubectl get storageclass

# 3. 方案 A: 创建缺失的 StorageClass
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

# 4. 方案 B: 修改 PVC 使用现有 StorageClass
kubectl patch pvc <name> -p '{"spec":{"storageClassName":"standard"}}'
# 注意: 已创建的 PVC 无法修改 storageClassName，需删除重建
```

#### 场景 2：PVC Pending - CSI Provisioner 故障

**问题现象：**
```
Events:
  Warning  ProvisioningFailed  failed to provision volume: rpc error: code = Internal
```

**解决步骤：**

```bash
# 1. 检查 CSI Controller Pod 状态
kubectl get pods -n <csi-namespace> -l app=<csi-controller>

# 2. 查看 provisioner 日志
kubectl logs -n <csi-namespace> <csi-controller-pod> -c csi-provisioner

# 3. 查看 CSI 驱动日志
kubectl logs -n <csi-namespace> <csi-controller-pod> -c <driver-container>

# 4. 常见问题及解决

# 问题 A: 凭据过期/错误
# 检查 Secret
kubectl get secret -n <csi-namespace> <credentials-secret> -o yaml
# 更新凭据
kubectl create secret generic <credentials-secret> \
  --from-literal=access-key=<new-key> \
  --from-literal=secret-key=<new-secret> \
  -n <csi-namespace> --dry-run=client -o yaml | kubectl apply -f -

# 问题 B: 配额不足
# 检查云提供商配额
# 清理未使用的卷

# 问题 C: 参数错误
# 检查 StorageClass 参数
kubectl get storageclass <name> -o yaml

# 5. 重启 CSI Controller
kubectl rollout restart deployment <csi-controller> -n <csi-namespace>
```

### 3.2 卷挂载问题

#### 场景 1：MountVolume.SetUp failed

**问题现象：**
```
Events:
  Warning  FailedMount  MountVolume.SetUp failed for volume "pvc-xxx": rpc error: code = Internal
```

**解决步骤：**

```bash
# 1. 检查 CSI Node Pod 状态
kubectl get pods -n <csi-namespace> -l app=<csi-node> -o wide

# 2. 检查特定节点的 CSI Node Pod
kubectl logs -n <csi-namespace> <csi-node-pod-on-target-node> -c <driver-container>

# 3. 检查 node-driver-registrar 日志
kubectl logs -n <csi-namespace> <csi-node-pod> -c node-driver-registrar

# 4. 检查 CSI 驱动是否在节点注册
kubectl get csinode <node-name> -o yaml

# 5. 检查 VolumeAttachment
kubectl get volumeattachment | grep <pv-name>
kubectl describe volumeattachment <va-name>

# 6. 在节点上检查
kubectl debug node/<node> -it --image=busybox -- sh
# 检查 CSI socket
ls -la /host/var/lib/kubelet/plugins/<driver-name>/csi.sock
# 检查挂载点
mount | grep <pv-name>
```

#### 场景 2：Multi-Attach error

**问题现象：**
```
Events:
  Warning  FailedAttachVolume  Multi-Attach error for volume "pvc-xxx": Volume is already exclusively attached to one node
```

**解决步骤：**

```bash
# 1. 检查卷当前挂载到哪个节点
kubectl get volumeattachment | grep <pv-name>

# 2. 找出使用该卷的 Pod
kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.volumes[].persistentVolumeClaim.claimName=="<pvc-name>") | "\(.metadata.namespace)/\(.metadata.name)"'

# 3. 方案 A: 等待旧 Pod 完全终止
kubectl get pods -o wide | grep <pvc-name>
kubectl delete pod <old-pod> --force --grace-period=0

# 4. 方案 B: 强制卸载 (谨慎!)
# 删除 VolumeAttachment
kubectl delete volumeattachment <va-name>

# 5. 方案 C: 使用支持多挂载的存储
# 更换为 ReadWriteMany 访问模式的存储 (如 NFS, CephFS)
```

#### 场景 3：挂载超时

**解决步骤：**

```bash
# 1. 检查存储后端连通性
# 在节点上测试
kubectl debug node/<node> -it --image=busybox -- sh
ping <storage-endpoint>
nc -zv <storage-endpoint> <port>

# 2. 检查网络策略
kubectl get networkpolicy -n <csi-namespace>

# 3. 增加挂载超时 (如果支持)
# 在 StorageClass 中设置
# parameters:
#   attachTimeout: "120"

# 4. 检查云提供商限制
# 如 AWS EBS 挂载数量限制
```

### 3.3 卷卸载/删除问题

#### 场景 1：PVC 删除卡住

**问题现象：**
PVC 处于 Terminating 状态

**解决步骤：**

```bash
# 1. 检查 PVC 的 finalizers
kubectl get pvc <name> -o jsonpath='{.metadata.finalizers}'

# 2. 检查是否有 Pod 在使用
kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.volumes[].persistentVolumeClaim.claimName=="<pvc-name>") | "\(.metadata.namespace)/\(.metadata.name)"'

# 3. 删除使用该 PVC 的 Pod
kubectl delete pod <pod-name>

# 4. 如果仍然卡住，检查 CSI 驱动日志
kubectl logs -n <csi-namespace> <csi-controller-pod> -c csi-provisioner | grep <pvc-name>

# 5. 最后手段: 移除 finalizer (可能导致后端资源泄漏!)
kubectl patch pvc <name> -p '{"metadata":{"finalizers":null}}'
```

#### 场景 2：PV 删除后后端卷残留

**解决步骤：**

```bash
# 1. 检查 PV 的 reclaimPolicy
kubectl get pv <name> -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'

# 2. 如果是 Retain，需要手动清理后端
# 获取后端卷 ID
kubectl get pv <name> -o jsonpath='{.spec.csi.volumeHandle}'

# 3. 在云提供商控制台或 CLI 删除卷
# AWS: aws ec2 delete-volume --volume-id <vol-id>
# GCP: gcloud compute disks delete <disk-name>

# 4. 如果要自动删除，修改 reclaimPolicy
kubectl patch pv <name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}'
```

### 3.4 扩容问题

#### 场景 1：PVC 扩容失败

**解决步骤：**

```bash
# 1. 检查 StorageClass 是否允许扩容
kubectl get storageclass <name> -o jsonpath='{.allowVolumeExpansion}'

# 2. 如果不允许，需要创建新的 StorageClass
kubectl patch storageclass <name> -p '{"allowVolumeExpansion":true}'

# 3. 检查 CSI 驱动是否支持扩容
kubectl get csidriver <driver-name> -o yaml | grep -A5 "capabilities"

# 4. 执行扩容
kubectl patch pvc <name> -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# 5. 检查扩容状态
kubectl get pvc <name> -o jsonpath='{.status.conditions}'

# 6. 某些存储需要重启 Pod 才能识别新容量
kubectl delete pod <pod-name>
kubectl exec <new-pod> -- df -h /mount/path
```

### 3.5 常见 CSI 驱动故障排查

#### AWS EBS CSI Driver

```bash
# 检查驱动状态
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# 检查 Controller
kubectl logs -n kube-system -l app=ebs-csi-controller -c csi-provisioner
kubectl logs -n kube-system -l app=ebs-csi-controller -c ebs-plugin

# 检查 Node
kubectl logs -n kube-system -l app=ebs-csi-node -c ebs-plugin

# 常见问题:
# 1. IAM 权限不足 - 检查节点 IAM Role
# 2. AZ 不匹配 - EBS 必须与节点在同一 AZ
# 3. 卷数量限制 - 检查实例类型的 EBS 限制
```

#### GCP PD CSI Driver

```bash
# 检查驱动状态
kubectl get pods -n gce-pd-csi-driver

# 检查日志
kubectl logs -n gce-pd-csi-driver -l app=gcp-compute-persistent-disk-csi-driver -c csi-provisioner

# 常见问题:
# 1. Service Account 权限不足
# 2. Zone 不匹配
# 3. 配额限制
```

#### Ceph CSI Driver

```bash
# 检查驱动状态
kubectl get pods -n rook-ceph -l app=csi-rbdplugin

# 检查日志
kubectl logs -n rook-ceph -l app=csi-rbdplugin-provisioner -c csi-provisioner
kubectl logs -n rook-ceph -l app=csi-rbdplugin -c csi-rbdplugin

# 常见问题:
# 1. Ceph 集群不健康
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status
# 2. 认证失败 - 检查 Secret
# 3. Pool 不存在
```

### 3.6 完整的 CSI StorageClass 示例

```yaml
# AWS EBS gp3
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
  # kmsKeyId: <kms-key-arn>  # 可选: 使用 KMS 加密
volumeBindingMode: WaitForFirstConsumer  # 延迟绑定到调度节点
allowVolumeExpansion: true
reclaimPolicy: Delete
---
# NFS CSI
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-csi
provisioner: nfs.csi.k8s.io
parameters:
  server: nfs-server.example.com
  share: /exported/path
volumeBindingMode: Immediate
allowVolumeExpansion: true
reclaimPolicy: Delete
mountOptions:
  - hard
  - nfsvers=4.1
```

---

### 3.7 安全生产风险提示

| 操作 | 风险等级 | 风险说明 | 建议 |
|-----|---------|---------|-----|
| 删除 CSI Controller | 高 | 无法创建/删除卷 | 确保有备份方案 |
| 移除 PVC finalizer | 高 | 后端存储资源可能泄漏 | 仅在确认后端已清理时使用 |
| 删除 VolumeAttachment | 中 | 可能导致数据不一致 | 确保 Pod 已停止 |
| 修改 reclaimPolicy | 中 | 影响卷删除行为 | 明确数据保留策略 |
| 强制卸载卷 | 高 | 可能导致数据损坏 | 最后手段，确保数据已同步 |
| 更新 CSI 驱动 | 中 | 可能影响挂载操作 | 低峰期更新，准备回滚 |

---

## 附录

### 常用命令速查

```bash
# CSI 驱动
kubectl get csidrivers
kubectl get csinodes
kubectl describe csidriver <name>

# StorageClass
kubectl get storageclass
kubectl describe storageclass <name>

# PVC/PV
kubectl get pvc,pv
kubectl describe pvc <name>
kubectl describe pv <name>

# VolumeAttachment
kubectl get volumeattachment
kubectl describe volumeattachment <name>

# CSI Pod 日志
kubectl logs -n <ns> <csi-controller-pod> -c csi-provisioner
kubectl logs -n <ns> <csi-node-pod> -c <driver>
```

### 相关文档

- [PV/PVC 故障排查](./01-pv-pvc-troubleshooting.md)
- [Pod 故障排查](../05-workloads/01-pod-troubleshooting.md)
- [StatefulSet 故障排查](../05-workloads/03-statefulset-troubleshooting.md)
