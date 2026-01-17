# 存储性能调优

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/storage](https://kubernetes.io/docs/concepts/storage/)

## 存储类型性能对比

| 存储类型 | IOPS | 吞吐量 | 延迟 | 适用场景 |
|----------|------|--------|------|----------|
| Local SSD | 100k+ | 1GB/s+ | <0.1ms | 数据库、缓存 |
| 云 SSD | 25k-100k | 350MB/s | <1ms | 通用工作负载 |
| 云高效云盘 | 5k-25k | 150MB/s | 1-3ms | 开发测试 |
| NFS/NAS | 变化大 | 100-500MB/s | 1-10ms | 共享存储 |
| 对象存储 | N/A | 高吞吐 | 50-200ms | 大文件、备份 |

## StorageClass 性能配置

```yaml
# 高性能 SSD 存储类
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: high-performance-ssd
provisioner: disk.csi.aliyun.com
parameters:
  type: cloud_essd
  performanceLevel: PL3  # ESSD 性能级别
  fsType: ext4
  encrypted: "true"
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# 通用 SSD 存储类
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard-ssd
provisioner: disk.csi.aliyun.com
parameters:
  type: cloud_ssd
  fsType: ext4
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# 本地存储类 (高性能)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-ssd
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

## 本地存储配置

```yaml
# 本地 PV (Local Persistent Volume)
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
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-ssd
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
---
# 本地存储 Provisioner (TopoLVM)
apiVersion: topolvm.io/v1
kind: LogicalVolume
metadata:
  name: app-data
spec:
  deviceClass: ssd
  size: 100Gi
```

## CSI 驱动性能优化

```yaml
# CSI 驱动参数优化 (阿里云)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alicloud-disk-essd-optimized
provisioner: disk.csi.aliyun.com
parameters:
  type: cloud_essd
  performanceLevel: PL2
  # 多 Attach (ReadWriteMany 场景)
  multiAttach: "true"
  # 加密
  encrypted: "true"
  kmsKeyId: "<kms-key-id>"
  # 快照
  snapshotId: ""
  # 磁盘类别
  zoned: "true"
mountOptions:
- noatime
- nodiratime
- barrier=0
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

## 文件系统优化

```yaml
# Pod 挂载选项
apiVersion: v1
kind: Pod
metadata:
  name: storage-optimized-pod
spec:
  containers:
  - name: app
    image: myapp:v1
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: data-pvc
---
# PV 挂载选项 (通过 StorageClass)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: optimized-ext4
provisioner: disk.csi.aliyun.com
parameters:
  type: cloud_essd
  fsType: ext4
mountOptions:
- noatime           # 不更新访问时间
- nodiratime        # 不更新目录访问时间
- data=ordered      # ext4 数据模式
- barrier=0         # 禁用写屏障 (有电池备份)
- discard           # SSD TRIM 支持
```

## 数据库存储优化

```yaml
# MySQL 高性能存储配置
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql
  replicas: 1
  template:
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
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
        - name: config
          mountPath: /etc/mysql/conf.d
        resources:
          requests:
            cpu: 2
            memory: 4Gi
          limits:
            cpu: 4
            memory: 8Gi
      volumes:
      - name: config
        configMap:
          name: mysql-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: high-performance-ssd
      resources:
        requests:
          storage: 200Gi
---
# MySQL 配置优化
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
data:
  performance.cnf: |
    [mysqld]
    innodb_buffer_pool_size = 3G
    innodb_log_file_size = 1G
    innodb_flush_log_at_trx_commit = 2
    innodb_flush_method = O_DIRECT
    innodb_io_capacity = 10000
    innodb_io_capacity_max = 20000
    innodb_read_io_threads = 8
    innodb_write_io_threads = 8
    sync_binlog = 0
```

## 存储性能测试

```bash
# 使用 fio 测试存储性能
kubectl run fio --image=nixery.dev/fio --rm -it -- fio \
  --name=test \
  --ioengine=libaio \
  --rw=randwrite \
  --bs=4k \
  --direct=1 \
  --size=1G \
  --numjobs=4 \
  --time_based \
  --runtime=60 \
  --group_reporting \
  --filename=/data/test

# 顺序读写测试
fio --name=seq-read --ioengine=libaio --rw=read --bs=1M --direct=1 --size=1G --numjobs=1
fio --name=seq-write --ioengine=libaio --rw=write --bs=1M --direct=1 --size=1G --numjobs=1

# 随机读写测试
fio --name=rand-read --ioengine=libaio --rw=randread --bs=4k --direct=1 --size=1G --numjobs=4
fio --name=rand-write --ioengine=libaio --rw=randwrite --bs=4k --direct=1 --size=1G --numjobs=4

# dd 快速测试
dd if=/dev/zero of=/data/testfile bs=1G count=1 oflag=direct
dd if=/data/testfile of=/dev/null bs=1G count=1 iflag=direct
```

## 存储监控指标

| 指标 | 说明 | 告警阈值 |
|------|------|----------|
| kubelet_volume_stats_used_bytes | 卷使用量 | > 80% 容量 |
| kubelet_volume_stats_inodes_used | inode 使用量 | > 80% 总量 |
| node_disk_io_time_seconds_total | 磁盘 IO 时间 | 持续 > 80% |
| node_disk_read_bytes_total | 读取字节数 | 接近限制 |
| node_disk_write_bytes_total | 写入字节数 | 接近限制 |

## 监控告警规则

```yaml
groups:
- name: storage
  rules:
  - alert: PVCUsageHigh
    expr: |
      kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "PVC {{ $labels.persistentvolumeclaim }} 使用率 > 80%"
      
  - alert: PVCInodeUsageHigh
    expr: |
      kubelet_volume_stats_inodes_used / kubelet_volume_stats_inodes > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "PVC {{ $labels.persistentvolumeclaim }} inode 使用率 > 80%"
      
  - alert: DiskIOSaturated
    expr: |
      rate(node_disk_io_time_seconds_total[5m]) > 0.8
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "节点 {{ $labels.instance }} 磁盘 {{ $labels.device }} IO 饱和"
      
  - alert: DiskLatencyHigh
    expr: |
      rate(node_disk_read_time_seconds_total[5m]) 
      / rate(node_disk_reads_completed_total[5m]) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "节点 {{ $labels.instance }} 磁盘读延迟 > 100ms"
```

## CSI 驱动诊断

```bash
# 查看 CSI 驱动状态
kubectl get csidrivers
kubectl get csinodes

# 查看 CSI 控制器
kubectl get pods -n kube-system -l app=csi-provisioner
kubectl logs -n kube-system -l app=csi-provisioner -c csi-provisioner

# 查看节点 CSI 插件
kubectl get pods -n kube-system -l app=csi-plugin
kubectl logs -n kube-system -l app=csi-plugin -c csi-plugin

# VolumeAttachment 状态
kubectl get volumeattachments

# 存储诊断
kubectl describe pvc <pvc-name>
kubectl describe pv <pv-name>
kubectl get events --field-selector reason=ProvisioningFailed
```

## 常见存储问题与解决

| 问题 | 现象 | 解决方案 |
|------|------|----------|
| IOPS 不足 | 应用响应慢 | 升级存储类型或 PL 级别 |
| 延迟高 | 数据库性能差 | 使用本地存储或高性能云盘 |
| 空间不足 | PVC Pending | 扩展 PVC 或清理数据 |
| inode 耗尽 | 无法创建文件 | 清理小文件或重建 PV |
| 挂载失败 | Pod Pending | 检查 CSI 驱动和节点亲和性 |
| 扩容失败 | resize 报错 | 检查 StorageClass 是否允许扩容 |
