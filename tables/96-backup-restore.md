# Kubernetes 备份与恢复

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/tasks/administer-cluster](https://kubernetes.io/docs/tasks/administer-cluster/)

## 备份范围与策略

| 备份对象 | 工具 | 频率 | 保留策略 |
|----------|------|------|----------|
| etcd 数据 | etcdctl | 每小时 | 7天滚动 |
| 集群资源 | Velero | 每天 | 30天 |
| 命名空间 | Velero | 按需 | 项目周期 |
| PV 数据 | Velero + CSI | 每天 | 30天 |
| 配置文件 | Git | 实时 | 永久 |
| 证书密钥 | 手动/自动 | 更新时 | 多副本 |

## etcd 备份

```bash
#!/bin/bash
# etcd 备份脚本

BACKUP_DIR="/var/backups/etcd"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/etcd-snapshot-${DATE}.db"

# 创建备份目录
mkdir -p ${BACKUP_DIR}

# 执行快照备份
ETCDCTL_API=3 etcdctl snapshot save ${BACKUP_FILE} \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key

# 验证备份
ETCDCTL_API=3 etcdctl snapshot status ${BACKUP_FILE} --write-out=table

# 压缩备份
gzip ${BACKUP_FILE}

# 上传到对象存储
aws s3 cp ${BACKUP_FILE}.gz s3://k8s-backups/etcd/

# 清理7天前的本地备份
find ${BACKUP_DIR} -name "etcd-snapshot-*.db.gz" -mtime +7 -delete

echo "etcd backup completed: ${BACKUP_FILE}.gz"
```

## etcd 恢复

```bash
#!/bin/bash
# etcd 恢复脚本

BACKUP_FILE=$1
RESTORE_DIR="/var/lib/etcd-restore"

# 停止 kube-apiserver
mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/

# 停止 etcd
mv /etc/kubernetes/manifests/etcd.yaml /tmp/

# 等待 Pod 停止
sleep 30

# 恢复快照
ETCDCTL_API=3 etcdctl snapshot restore ${BACKUP_FILE} \
  --data-dir=${RESTORE_DIR} \
  --initial-cluster=master-0=https://10.0.0.10:2380 \
  --initial-cluster-token=etcd-cluster-1 \
  --initial-advertise-peer-urls=https://10.0.0.10:2380 \
  --name=master-0

# 替换 etcd 数据目录
rm -rf /var/lib/etcd
mv ${RESTORE_DIR} /var/lib/etcd

# 启动 etcd
mv /tmp/etcd.yaml /etc/kubernetes/manifests/

# 等待 etcd 启动
sleep 30

# 启动 kube-apiserver
mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/

echo "etcd restore completed"
```

## Velero 安装配置

```yaml
# Velero 安装 (阿里云 OSS)
---
apiVersion: v1
kind: Secret
metadata:
  name: cloud-credentials
  namespace: velero
stringData:
  cloud: |
    [default]
    alicloud_access_key_id=<ACCESS_KEY>
    alicloud_secret_access_key=<SECRET_KEY>
---
# Helm 安装
# helm install velero vmware-tanzu/velero \
#   --namespace velero \
#   --create-namespace \
#   --set-file credentials.secretContents.cloud=./credentials-velero \
#   --set configuration.provider=alibabacloud \
#   --set configuration.backupStorageLocation.bucket=velero-backups \
#   --set configuration.backupStorageLocation.config.region=cn-hangzhou \
#   --set configuration.volumeSnapshotLocation.config.region=cn-hangzhou \
#   --set initContainers[0].name=velero-plugin-alibabacloud \
#   --set initContainers[0].image=registry.cn-hangzhou.aliyuncs.com/acs/velero-plugin-alibabacloud:v1.0.0 \
#   --set initContainers[0].volumeMounts[0].mountPath=/target \
#   --set initContainers[0].volumeMounts[0].name=plugins
```

## Velero 备份配置

```yaml
# 定时备份计划
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-cluster-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"  # 每天凌晨2点
  template:
    includedNamespaces:
    - "*"
    excludedNamespaces:
    - kube-system
    - velero
    includedResources:
    - "*"
    excludedResources:
    - events
    - events.events.k8s.io
    storageLocation: default
    volumeSnapshotLocations:
    - default
    ttl: 720h  # 30天
    snapshotVolumes: true
    defaultVolumesToFsBackup: false
---
# 命名空间备份
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: production-backup
  namespace: velero
spec:
  includedNamespaces:
  - production
  includedResources:
  - "*"
  labelSelector:
    matchLabels:
      backup: "true"
  storageLocation: default
  volumeSnapshotLocations:
  - default
  ttl: 720h
  snapshotVolumes: true
  hooks:
    resources:
    - name: mysql-backup-hook
      includedNamespaces:
      - production
      labelSelector:
        matchLabels:
          app: mysql
      pre:
      - exec:
          container: mysql
          command:
          - /bin/sh
          - -c
          - "mysql -u root -p$MYSQL_ROOT_PASSWORD -e 'FLUSH TABLES WITH READ LOCK;'"
          onError: Fail
          timeout: 30s
      post:
      - exec:
          container: mysql
          command:
          - /bin/sh
          - -c
          - "mysql -u root -p$MYSQL_ROOT_PASSWORD -e 'UNLOCK TABLES;'"
          onError: Continue
          timeout: 30s
```

## Velero 恢复操作

```bash
# 查看可用备份
velero backup get

# 查看备份详情
velero backup describe <backup-name> --details

# 恢复整个备份
velero restore create --from-backup <backup-name>

# 恢复指定命名空间
velero restore create --from-backup <backup-name> \
  --include-namespaces production

# 恢复到不同命名空间
velero restore create --from-backup <backup-name> \
  --namespace-mappings production:production-restored

# 仅恢复指定资源
velero restore create --from-backup <backup-name> \
  --include-resources deployments,services,configmaps

# 跳过恢复某些资源
velero restore create --from-backup <backup-name> \
  --exclude-resources persistentvolumeclaims

# 查看恢复状态
velero restore get
velero restore describe <restore-name> --details
velero restore logs <restore-name>
```

## CSI 快照备份

```yaml
# VolumeSnapshotClass
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: alicloud-disk-snapshot
driver: disk.csi.aliyun.com
deletionPolicy: Retain
parameters:
  forceDelete: "true"
---
# 手动创建快照
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: mysql-data-snapshot
  namespace: production
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
  namespace: production
spec:
  storageClassName: alicloud-disk-essd
  dataSource:
    name: mysql-data-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
```

## 备份验证脚本

```bash
#!/bin/bash
# 备份验证脚本

BACKUP_NAME=$1
TEST_NAMESPACE="backup-test-$(date +%s)"

echo "Creating test namespace: ${TEST_NAMESPACE}"
kubectl create namespace ${TEST_NAMESPACE}

echo "Restoring backup to test namespace..."
velero restore create test-restore-${TEST_NAMESPACE} \
  --from-backup ${BACKUP_NAME} \
  --namespace-mappings production:${TEST_NAMESPACE} \
  --wait

echo "Verifying restored resources..."
kubectl get all -n ${TEST_NAMESPACE}

# 检查 Pod 状态
FAILED_PODS=$(kubectl get pods -n ${TEST_NAMESPACE} --field-selector=status.phase!=Running,status.phase!=Succeeded -o name | wc -l)
if [ ${FAILED_PODS} -gt 0 ]; then
  echo "WARNING: ${FAILED_PODS} pods are not running"
  kubectl get pods -n ${TEST_NAMESPACE} --field-selector=status.phase!=Running,status.phase!=Succeeded
fi

# 清理测试命名空间
echo "Cleanup test namespace..."
kubectl delete namespace ${TEST_NAMESPACE}

echo "Backup verification completed"
```

## 备份监控告警

```yaml
groups:
- name: backup
  rules:
  - alert: VeleroBackupFailed
    expr: |
      velero_backup_failure_total > 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Velero 备份失败"
      
  - alert: VeleroBackupMissing
    expr: |
      time() - velero_backup_last_successful_timestamp > 86400
    for: 1h
    labels:
      severity: warning
    annotations:
      summary: "超过24小时没有成功备份"
      
  - alert: EtcdBackupMissing
    expr: |
      time() - etcd_backup_last_successful_timestamp > 3600
    for: 30m
    labels:
      severity: warning
    annotations:
      summary: "超过1小时没有 etcd 备份"
```

## 备份最佳实践

| 项目 | 建议 |
|------|------|
| 备份频率 | etcd: 每小时, 应用: 每天 |
| 保留策略 | 滚动保留 + 月度归档 |
| 存储位置 | 异地对象存储 |
| 加密 | 启用静态加密 |
| 验证 | 每周执行恢复验证 |
| 文档 | 维护恢复手册 |
| RTO/RPO | 明确定义并测试 |
