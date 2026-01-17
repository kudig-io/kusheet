# 表格89: PV/PVC存储故障排查

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/storage/persistent-volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

## PVC状态说明

| 状态 | 含义 | 常见原因 | 处理方式 |
|-----|------|---------|---------|
| **Pending** | 等待绑定 | 无可用PV/SC配置错误 | 检查SC和PV |
| **Bound** | 已绑定 | 正常状态 | - |
| **Lost** | PV丢失 | PV被删除/不可用 | 恢复PV |

## PV状态说明

| 状态 | 含义 | 说明 |
|-----|------|------|
| **Available** | 可用 | 未绑定到PVC |
| **Bound** | 已绑定 | 绑定到PVC |
| **Released** | 已释放 | PVC已删除,待回收 |
| **Failed** | 失败 | 自动回收失败 |

## PVC Pending诊断

```bash
# 1. 检查PVC状态和事件
kubectl get pvc -n <namespace>
kubectl describe pvc <pvc-name> -n <namespace>

# 2. 检查StorageClass
kubectl get sc
kubectl describe sc <storageclass-name>

# 3. 检查PV
kubectl get pv
kubectl describe pv <pv-name>

# 4. 检查CSI驱动
kubectl get csidrivers
kubectl get pods -n kube-system | grep csi

# 5. 检查CSI控制器日志
kubectl logs -n kube-system -l app=csi-provisioner --tail=100
```

## 常见PVC Pending原因

| 原因 | 诊断方法 | 解决方案 |
|-----|---------|---------|
| **无匹配PV** | 检查PV标签/容量 | 创建匹配的PV |
| **SC不存在** | `kubectl get sc` | 创建StorageClass |
| **SC配置错误** | 检查SC参数 | 修正SC配置 |
| **CSI驱动故障** | 检查CSI Pod | 重启CSI驱动 |
| **配额限制** | 检查ResourceQuota | 调整配额 |
| **节点亲和性** | 检查allowedTopologies | 调整拓扑配置 |
| **云API限流** | 检查云API错误 | 等待或联系云厂商 |

## CSI驱动诊断

```bash
# 检查CSI驱动状态
kubectl get csidrivers
kubectl get csinodes

# 检查CSI控制器
kubectl get pods -n kube-system -l app=csi-controller
kubectl logs -n kube-system <csi-controller-pod> -c csi-provisioner

# 检查CSI节点插件
kubectl get pods -n kube-system -l app=csi-node -o wide
kubectl logs -n kube-system <csi-node-pod> -c csi-driver

# 检查VolumeAttachment
kubectl get volumeattachments
kubectl describe volumeattachment <name>
```

## 挂载失败诊断

```bash
# Pod挂载失败事件
kubectl describe pod <pod-name> | grep -A 10 "Events"

# 检查节点挂载
kubectl get pods -o wide  # 找到节点
ssh <node-ip>
mount | grep <pv-name>
ls -la /var/lib/kubelet/pods/<pod-uid>/volumes/

# 检查kubelet日志
journalctl -u kubelet | grep -i "mount\|volume"

# 检查文件系统
lsblk
fdisk -l
```

## 云盘存储问题(ACK)

```bash
# 检查阿里云磁盘插件
kubectl get pods -n kube-system -l app=csi-plugin

# 检查磁盘状态(aliyun CLI)
aliyun ecs DescribeDisks --DiskIds '["d-xxx"]'

# 检查挂载关系
aliyun ecs DescribeDisks --InstanceId <instance-id>

# 手动分离磁盘(谨慎操作)
aliyun ecs DetachDisk --DiskId d-xxx --InstanceId i-xxx
```

## 存储扩容

```yaml
# PVC扩容(需要SC支持)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi  # 从50Gi扩容到100Gi
  storageClassName: alicloud-disk-ssd
```

```bash
# 检查扩容支持
kubectl get sc <name> -o jsonpath='{.allowVolumeExpansion}'

# 扩容PVC
kubectl patch pvc <pvc-name> -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'

# 检查扩容状态
kubectl get pvc <pvc-name> -o jsonpath='{.status.conditions}'
```

## 快照和恢复

```yaml
# 创建快照
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: data-snapshot
spec:
  volumeSnapshotClassName: alicloud-disk-snapshot
  source:
    persistentVolumeClaimName: data-pvc
---
# 从快照恢复
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc-restored
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: alicloud-disk-ssd
  dataSource:
    name: data-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

## 常见解决方案

| 问题 | 解决方案 |
|-----|---------|
| PVC一直Pending | 检查SC是否存在,CSI驱动是否正常 |
| 挂载超时 | 检查节点到存储的网络,重启CSI |
| 扩容失败 | 确认SC支持扩容,检查配额 |
| 只读文件系统 | 检查PV accessModes,节点文件系统 |
| IO性能差 | 检查存储类型,考虑升级 |

## 监控告警

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: storage-alerts
spec:
  groups:
  - name: storage
    rules:
    - alert: PVCPending
      expr: kube_persistentvolumeclaim_status_phase{phase="Pending"} == 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} Pending"
        
    - alert: PVCNearFull
      expr: |
        kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.85
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "PVC使用率超过85%"
```

---

**存储故障排查原则**: PVC Pending先查SC → 挂载失败查CSI和节点 → 性能问题查存储类型 → 定期监控容量
