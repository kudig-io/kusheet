# PV/PVC 存储故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 中级-高级

---

## 目录

1. [问题现象与影响分析](#1-问题现象与影响分析)
2. [排查方法与步骤](#2-排查方法与步骤)
3. [解决方案与风险控制](#3-解决方案与风险控制)

---

## 1. 问题现象与影响分析

### 1.1 常见问题现象

#### 1.1.1 PVC 绑定问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| PVC Pending | `waiting for first consumer` | kubectl | `kubectl get pvc` |
| PVC Pending | `no persistent volumes available` | PVC Events | `kubectl describe pvc` |
| PVC Pending | `storageclass not found` | PVC Events | `kubectl describe pvc` |
| PVC 绑定失败 | `does not match accessModes` | PVC Events | `kubectl describe pvc` |
| PVC 绑定失败 | `capacity smaller than requested` | PVC Events | `kubectl describe pvc` |

#### 1.1.2 卷挂载问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 挂载失败 | `MountVolume.SetUp failed` | Pod Events | `kubectl describe pod` |
| 挂载超时 | `timed out waiting for the condition` | Pod Events | `kubectl describe pod` |
| 设备忙 | `device is busy` | kubelet 日志 | kubelet 日志 |
| 多重挂载 | `volume is already exclusively mounted` | Pod Events | `kubectl describe pod` |
| 权限错误 | `permission denied` | 容器日志 | `kubectl logs` |

#### 1.1.3 CSI 驱动问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| CSI Driver 不可用 | `CSI driver not found` | Pod Events | `kubectl describe pod` |
| Provisioner 失败 | `failed to provision volume` | PVC Events | `kubectl describe pvc` |
| Attach 失败 | `AttachVolume.Attach failed` | Pod Events | `kubectl describe pod` |
| CSI Pod 异常 | CrashLoopBackOff | kubectl | `kubectl get pods -n kube-system` |

### 1.2 报错查看方式汇总

```bash
# 查看 PVC 状态
kubectl get pvc -A
kubectl describe pvc <pvc-name>

# 查看 PV 状态
kubectl get pv
kubectl describe pv <pv-name>

# 查看 StorageClass
kubectl get sc
kubectl describe sc <storage-class-name>

# 查看 CSI 驱动
kubectl get csidrivers
kubectl get pods -n kube-system | grep csi

# 查看 CSI 日志
kubectl logs -n kube-system <csi-controller-pod> -c csi-provisioner
kubectl logs -n kube-system <csi-node-pod> -c csi-driver

# 查看卷挂载状态
kubectl get volumeattachments

# 查看节点上的挂载
mount | grep <pv-name>
ls -la /var/lib/kubelet/pods/<pod-uid>/volumes/
```

### 1.3 影响面分析

| 影响范围 | 影响程度 | 影响描述 |
|----------|----------|----------|
| **Pod 启动** | 阻塞 | 使用 PVC 的 Pod 无法启动 |
| **数据持久化** | 失效 | 数据无法写入持久卷 |
| **StatefulSet** | 受影响 | 有状态应用无法正常工作 |
| **数据库** | 高风险 | 数据库可能无法启动或丢失数据 |

---

## 2. 排查方法与步骤

### 2.1 排查 PVC Pending

```bash
# 步骤 1：查看 PVC 状态和事件
kubectl describe pvc <pvc-name>

# 步骤 2：检查 StorageClass 是否存在
kubectl get sc
kubectl describe sc <storage-class-name>

# 步骤 3：检查是否有可用 PV（静态供给）
kubectl get pv

# 步骤 4：检查 CSI Provisioner
kubectl get pods -n kube-system | grep csi
kubectl logs -n kube-system <csi-controller-pod> -c csi-provisioner

# 步骤 5：检查云平台配额（如适用）
# 阿里云磁盘配额
aliyun ecs DescribeDisks --RegionId=<region>

# 步骤 6：检查 PVC 规格
kubectl get pvc <pvc-name> -o yaml | grep -E "storage|accessModes|storageClassName"
```

### 2.2 排查卷挂载失败

```bash
# 步骤 1：查看 Pod 事件
kubectl describe pod <pod-name>

# 步骤 2：检查 VolumeAttachment 状态
kubectl get volumeattachments
kubectl describe volumeattachment <va-name>

# 步骤 3：检查 CSI Node 插件
kubectl get pods -n kube-system -o wide | grep csi
kubectl logs -n kube-system <csi-node-pod>

# 步骤 4：检查节点上的挂载
ssh <node>
mount | grep <pv-name>
ls -la /var/lib/kubelet/pods/<pod-uid>/volumes/

# 步骤 5：检查设备是否存在
lsblk
ls /dev/disk/by-id/

# 步骤 6：检查文件系统
blkid /dev/<device>
```

### 2.3 排查 CSI 驱动问题

```bash
# 步骤 1：检查 CSI Driver 注册
kubectl get csidrivers
kubectl describe csidriver <driver-name>

# 步骤 2：检查 CSI Controller Pod
kubectl get pods -n kube-system -l app=<csi-controller>
kubectl logs -n kube-system <csi-controller-pod> --all-containers

# 步骤 3：检查 CSI Node Pod
kubectl get pods -n kube-system -l app=<csi-node> -o wide
kubectl logs -n kube-system <csi-node-pod> --all-containers

# 步骤 4：检查 RBAC 权限
kubectl get clusterrolebinding | grep csi
kubectl describe clusterrolebinding <csi-rolebinding>

# 步骤 5：检查 CSI Socket
ls -la /var/lib/kubelet/plugins/<csi-driver-name>/csi.sock
```

---

## 3. 解决方案与风险控制

### 3.1 PVC Pending 解决

#### 3.1.1 StorageClass 不存在

```bash
# 查看可用的 StorageClass
kubectl get sc

# 创建默认 StorageClass（示例：阿里云）
cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alicloud-disk-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_ssd
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF

# 或修改 PVC 使用正确的 StorageClass
kubectl patch pvc <pvc-name> -p '{"spec":{"storageClassName":"<correct-sc>"}}'
```

#### 3.1.2 容量或访问模式不匹配

```bash
# 检查 PV 和 PVC 的规格
kubectl get pv -o custom-columns='NAME:.metadata.name,CAPACITY:.spec.capacity.storage,ACCESS:.spec.accessModes'
kubectl get pvc -o custom-columns='NAME:.metadata.name,CAPACITY:.spec.resources.requests.storage,ACCESS:.spec.accessModes'

# 创建匹配的 PV（静态供给）
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: manual-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: <storage-class>
  csi:
    driver: <csi-driver>
    volumeHandle: <volume-id>
EOF
```

#### 3.1.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 删除 PVC 可能导致数据丢失（取决于 reclaimPolicy）
2. 修改 StorageClass 对已创建的 PVC 无效
3. WaitForFirstConsumer 需要 Pod 调度后才绑定
4. 云平台配额限制会阻止卷创建
5. 生产环境建议使用 Retain 策略
```

### 3.2 卷挂载失败解决

#### 3.2.1 设备已被挂载

```bash
# 步骤 1：检查哪个 Pod 正在使用
kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName=="<pvc-name>") | .metadata.namespace + "/" + .metadata.name'

# 步骤 2：如果是旧 Pod 残留，清理
kubectl delete pod <old-pod-name> --grace-period=0 --force

# 步骤 3：等待 VolumeAttachment 清理
kubectl get volumeattachments | grep <pv-name>
kubectl delete volumeattachment <va-name>

# 步骤 4：在节点上强制卸载（危险操作）
ssh <node>
umount /var/lib/kubelet/pods/<pod-uid>/volumes/kubernetes.io~csi/<pv-name>/mount

# 步骤 5：验证挂载状态
mount | grep <pv-name>
```

#### 3.2.2 文件系统问题

```bash
# 步骤 1：检查设备
lsblk
blkid /dev/<device>

# 步骤 2：检查文件系统
fsck -n /dev/<device>

# 步骤 3：如果需要格式化（会丢失数据！）
mkfs.ext4 /dev/<device>

# 步骤 4：修复文件系统权限
mount /dev/<device> /mnt
chown -R <uid>:<gid> /mnt
chmod -R 755 /mnt
umount /mnt
```

#### 3.2.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 强制卸载可能导致数据损坏
2. 格式化会删除所有数据
3. 修复前确保有数据备份
4. 云盘操作前检查快照
5. 多重挂载场景注意数据一致性
```

### 3.3 CSI 驱动问题解决

#### 3.3.1 重新部署 CSI 驱动

```bash
# 步骤 1：删除旧的 CSI 部署
kubectl delete -f <csi-deployment.yaml>

# 步骤 2：检查残留资源
kubectl get pods -n kube-system | grep csi
kubectl get csidrivers
kubectl get csinode

# 步骤 3：重新部署 CSI 驱动
# 阿里云示例
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/alibaba-cloud-csi-driver/master/deploy/ack/csi-plugin.yaml

# AWS EBS CSI 示例
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"

# 步骤 4：验证部署
kubectl get pods -n kube-system | grep csi
kubectl get csidrivers
kubectl get csinode

# 步骤 5：测试卷创建
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: <storage-class>
EOF

kubectl get pvc test-pvc
```

#### 3.3.2 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 重新部署 CSI 期间新卷无法创建
2. 已挂载的卷通常不受影响
3. 确保使用与集群版本兼容的 CSI 版本
4. 云凭证配置正确是关键
5. CSI 驱动有严格的 RBAC 要求
```

---

## 附录

### A. StorageClass 参数说明

| 参数 | 说明 | 示例值 |
|------|------|--------|
| `provisioner` | CSI 驱动名称 | `diskplugin.csi.alibabacloud.com` |
| `reclaimPolicy` | 回收策略 | `Delete`/`Retain` |
| `volumeBindingMode` | 绑定模式 | `Immediate`/`WaitForFirstConsumer` |
| `allowVolumeExpansion` | 允许扩容 | `true`/`false` |

### B. 常见 CSI 驱动

| 云平台 | CSI 驱动 |
|--------|----------|
| 阿里云 | `diskplugin.csi.alibabacloud.com` |
| AWS | `ebs.csi.aws.com` |
| Azure | `disk.csi.azure.com` |
| GCP | `pd.csi.storage.gke.io` |
| Ceph | `rbd.csi.ceph.com` |

### C. 排查清单

- [ ] StorageClass 存在且配置正确
- [ ] CSI 驱动 Pod 正常运行
- [ ] PVC 规格（容量、访问模式）兼容
- [ ] VolumeAttachment 状态正常
- [ ] 云平台配额充足
- [ ] 节点有权限访问存储
- [ ] 文件系统健康
