# 140 - 存储备份与灾难恢复 (Storage Backup & Disaster Recovery)

> **适用版本**: Kubernetes v1.25 - v1.32 | **难度**: 高级 | **最后更新**: 2026-01

---

## 1. 备份策略架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         多层备份策略                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │  Layer 1: 集群级备份 (Cluster-Level)                            │   │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │   │
│   │  │   Velero    │  │   Kasten    │  │   Trilio    │             │   │
│   │  │ K8s 资源+PV │  │    K10      │  │    TVK      │             │   │
│   │  └─────────────┘  └─────────────┘  └─────────────┘             │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │  Layer 2: 应用级备份 (Application-Level)                        │   │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │   │
│   │  │  mysqldump  │  │  pg_dump    │  │  mongodump  │             │   │
│   │  │  xtrabackup │  │  pg_basebackup│ │  restic    │             │   │
│   │  └─────────────┘  └─────────────┘  └─────────────┘             │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │  Layer 3: 存储级备份 (Storage-Level)                            │   │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │   │
│   │  │VolumeSnapshot│ │ 云盘快照    │  │  存储复制   │             │   │
│   │  │   CSI原生   │  │ EBS/ESSD   │  │ 跨区域复制  │             │   │
│   │  └─────────────┘  └─────────────┘  └─────────────┘             │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. RPO/RTO 指标定义

| 指标 | 定义 | 业务影响 |
|:---|:---|:---|
| **RPO** (Recovery Point Objective) | 可接受的数据丢失时间 | RPO=1h 表示最多丢失1小时数据 |
| **RTO** (Recovery Time Objective) | 恢复所需的最大时间 | RTO=4h 表示必须在4小时内恢复 |

### 备份策略与 RPO/RTO 对照

| 备份策略 | 典型 RPO | 典型 RTO | 成本 | 适用场景 |
|:---|:---:|:---:|:---:|:---|
| 实时复制 | 0 | 分钟级 | 高 | 核心交易系统 |
| 持续备份 | 分钟 | 小时级 | 中高 | 重要业务系统 |
| 每小时快照 | 1 小时 | 小时级 | 中 | 一般生产系统 |
| 每日备份 | 24 小时 | 天级 | 低 | 开发测试环境 |

---

## 3. Velero 企业备份方案

### 3.1 Velero 架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           源集群 (Source Cluster)                        │
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                        Velero Server                             │   │
│   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │   │
│   │  │   Backup     │  │   Restore    │  │   Schedule   │           │   │
│   │  │  Controller  │  │  Controller  │  │  Controller  │           │   │
│   │  └──────┬───────┘  └──────────────┘  └──────────────┘           │   │
│   │         │                                                        │   │
│   │         ▼                                                        │   │
│   │  ┌──────────────────────────────────────────────────────────┐   │   │
│   │  │              BackupStorageLocation                        │   │   │
│   │  │         (OSS/S3/GCS/Azure Blob)                          │   │   │
│   │  └──────────────────────────────────────────────────────────┘   │   │
│   │         │                                                        │   │
│   │         ▼                                                        │   │
│   │  ┌──────────────────────────────────────────────────────────┐   │   │
│   │  │            VolumeSnapshotLocation                         │   │   │
│   │  │         (云盘快照/CSI Snapshot)                           │   │   │
│   │  └──────────────────────────────────────────────────────────┘   │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          目标集群 (Target Cluster)                       │
│                              (恢复时使用)                                │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Velero 安装 (阿里云)

```bash
# 安装 Velero CLI
wget https://github.com/vmware-tanzu/velero/releases/download/v1.13.0/velero-v1.13.0-linux-amd64.tar.gz
tar -xvf velero-v1.13.0-linux-amd64.tar.gz
mv velero-v1.13.0-linux-amd64/velero /usr/local/bin/

# 创建凭证文件
cat > credentials-velero <<EOF
ALIBABA_CLOUD_ACCESS_KEY_ID=<your-access-key-id>
ALIBABA_CLOUD_ACCESS_KEY_SECRET=<your-access-key-secret>
EOF

# 安装 Velero (阿里云插件)
velero install \
  --provider alibabacloud \
  --plugins registry.cn-hangzhou.aliyuncs.com/acs/velero-plugin-alibabacloud:v1.8 \
  --bucket velero-backup-bucket \
  --secret-file ./credentials-velero \
  --backup-location-config region=cn-hangzhou \
  --snapshot-location-config region=cn-hangzhou \
  --use-volume-snapshots=true \
  --use-node-agent
```

### 3.3 备份配置

```yaml
# BackupStorageLocation
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: default
  namespace: velero
spec:
  provider: alibabacloud
  objectStorage:
    bucket: velero-backup-bucket
    prefix: cluster-prod
  config:
    region: cn-hangzhou
---
# VolumeSnapshotLocation
apiVersion: velero.io/v1
kind: VolumeSnapshotLocation
metadata:
  name: default
  namespace: velero
spec:
  provider: alibabacloud
  config:
    region: cn-hangzhou
```

### 3.4 定时备份策略

```yaml
# 每日全量备份
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-full-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"  # 每天凌晨 2 点
  template:
    includedNamespaces:
      - production
      - staging
    excludedResources:
      - events
      - events.events.k8s.io
    storageLocation: default
    volumeSnapshotLocations:
      - default
    ttl: 720h  # 保留 30 天
    snapshotVolumes: true
---
# 每小时增量备份 (关键命名空间)
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: hourly-critical-backup
  namespace: velero
spec:
  schedule: "0 * * * *"  # 每小时
  template:
    includedNamespaces:
      - production
    labelSelector:
      matchLabels:
        backup: critical
    storageLocation: default
    ttl: 168h  # 保留 7 天
    snapshotVolumes: true
```

### 3.5 备份前后 Hook

```yaml
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: mysql-backup-with-hooks
  namespace: velero
spec:
  includedNamespaces:
    - production
  labelSelector:
    matchLabels:
      app: mysql
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
                - /bin/bash
                - -c
                - "mysql -u root -p$MYSQL_ROOT_PASSWORD -e 'FLUSH TABLES WITH READ LOCK; FLUSH LOGS;'"
              onError: Fail
              timeout: 60s
        post:
          - exec:
              container: mysql
              command:
                - /bin/bash
                - -c
                - "mysql -u root -p$MYSQL_ROOT_PASSWORD -e 'UNLOCK TABLES;'"
              onError: Continue
              timeout: 30s
```

---

## 4. 恢复操作

### 4.1 完整恢复

```bash
# 查看可用备份
velero backup get

# 恢复整个备份
velero restore create --from-backup daily-full-backup-20260118

# 查看恢复状态
velero restore describe <restore-name>
velero restore logs <restore-name>
```

### 4.2 选择性恢复

```bash
# 仅恢复指定命名空间
velero restore create --from-backup daily-full-backup-20260118 \
  --include-namespaces production

# 仅恢复指定资源类型
velero restore create --from-backup daily-full-backup-20260118 \
  --include-resources deployments,services,configmaps

# 恢复到新命名空间
velero restore create --from-backup daily-full-backup-20260118 \
  --namespace-mappings production:production-restored

# 排除 PVC (仅恢复配置)
velero restore create --from-backup daily-full-backup-20260118 \
  --exclude-resources persistentvolumeclaims
```

### 4.3 跨集群恢复

```bash
# 在目标集群安装 Velero，使用相同的 BackupStorageLocation

# 同步备份元数据
velero backup-location get

# 执行恢复
velero restore create cross-cluster-restore \
  --from-backup daily-full-backup-20260118
```

---

## 5. CSI VolumeSnapshot 自动备份

### 5.1 快照 CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: volume-snapshot-daily
  namespace: backup-system
spec:
  schedule: "0 3 * * *"
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: snapshot-manager
          containers:
            - name: snapshot-creator
              image: bitnami/kubectl:1.28
              command:
                - /bin/bash
                - -c
                - |
                  #!/bin/bash
                  set -e
                  DATE=$(date +%Y%m%d-%H%M)
                  
                  # 获取需要备份的 PVC 列表
                  PVCS=$(kubectl get pvc -A -l backup=enabled -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}')
                  
                  for PVC in $PVCS; do
                    NAMESPACE=$(echo $PVC | cut -d'/' -f1)
                    NAME=$(echo $PVC | cut -d'/' -f2)
                    SNAPSHOT_NAME="${NAME}-snap-${DATE}"
                    
                    echo "Creating snapshot: $SNAPSHOT_NAME"
                    
                    cat <<EOF | kubectl apply -f -
                  apiVersion: snapshot.storage.k8s.io/v1
                  kind: VolumeSnapshot
                  metadata:
                    name: ${SNAPSHOT_NAME}
                    namespace: ${NAMESPACE}
                    labels:
                      backup-type: daily
                      source-pvc: ${NAME}
                  spec:
                    volumeSnapshotClassName: alicloud-disk-snapshot
                    source:
                      persistentVolumeClaimName: ${NAME}
                  EOF
                  done
                  
                  # 清理过期快照 (保留 7 天)
                  kubectl get volumesnapshot -A -l backup-type=daily \
                    -o jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name},{.metadata.creationTimestamp}{"\n"}{end}' | \
                  while IFS=',' read NS NAME TS; do
                    AGE_DAYS=$(( ($(date +%s) - $(date -d "$TS" +%s)) / 86400 ))
                    if [ $AGE_DAYS -gt 7 ]; then
                      echo "Deleting old snapshot: $NS/$NAME (age: $AGE_DAYS days)"
                      kubectl delete volumesnapshot -n $NS $NAME
                    fi
                  done
          restartPolicy: OnFailure
```

---

## 6. 应用级备份示例

### 6.1 MySQL 备份

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mysql-backup
  namespace: production
spec:
  schedule: "0 1 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: mysqldump
              image: mysql:8.0
              command:
                - /bin/bash
                - -c
                - |
                  DATE=$(date +%Y%m%d)
                  mysqldump -h mysql-primary -u backup -p$MYSQL_BACKUP_PASSWORD \
                    --all-databases \
                    --single-transaction \
                    --quick \
                    --lock-tables=false \
                    --routines \
                    --triggers \
                    | gzip > /backup/mysql-full-${DATE}.sql.gz
                  
                  # 上传到 OSS
                  ossutil cp /backup/mysql-full-${DATE}.sql.gz \
                    oss://backup-bucket/mysql/mysql-full-${DATE}.sql.gz
                  
                  # 清理本地文件
                  rm /backup/mysql-full-${DATE}.sql.gz
              env:
                - name: MYSQL_BACKUP_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: mysql-credentials
                      key: backup-password
              volumeMounts:
                - name: backup-volume
                  mountPath: /backup
          volumes:
            - name: backup-volume
              emptyDir: {}
          restartPolicy: OnFailure
```

### 6.2 PostgreSQL 备份

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: production
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: pg-backup
              image: postgres:15
              command:
                - /bin/bash
                - -c
                - |
                  DATE=$(date +%Y%m%d)
                  
                  # 逻辑备份
                  PGPASSWORD=$PGPASSWORD pg_dumpall -h postgres-primary -U backup \
                    | gzip > /backup/postgres-full-${DATE}.sql.gz
                  
                  # 或使用 pg_basebackup (物理备份)
                  # pg_basebackup -h postgres-primary -U replication -D /backup/base-${DATE} -Ft -z -P
              env:
                - name: PGPASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: postgres-credentials
                      key: backup-password
          restartPolicy: OnFailure
```

---

## 7. 跨区域灾难恢复

### 7.1 DR 架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        主区域 (cn-hangzhou)                              │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Production Cluster                            │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐                          │   │
│  │  │   App   │  │   DB    │  │  Cache  │                          │   │
│  │  │ Pods    │  │ Pods    │  │  Pods   │                          │   │
│  │  └────┬────┘  └────┬────┘  └─────────┘                          │   │
│  │       │            │                                             │   │
│  │       ▼            ▼                                             │   │
│  │  ┌─────────────────────────────────────┐                        │   │
│  │  │        ESSD / NAS Storage           │                        │   │
│  │  └──────────────────┬──────────────────┘                        │   │
│  │                     │                                            │   │
│  └─────────────────────┼────────────────────────────────────────────┘   │
│                        │ 异步复制                                        │
└────────────────────────┼────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        灾备区域 (cn-shanghai)                            │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    DR Cluster (Standby)                          │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐                          │   │
│  │  │   App   │  │   DB    │  │  Cache  │   (Scaled Down)          │   │
│  │  │ Pods    │  │ Replica │  │  Pods   │                          │   │
│  │  └────┬────┘  └────┬────┘  └─────────┘                          │   │
│  │       │            │                                             │   │
│  │       ▼            ▼                                             │   │
│  │  ┌─────────────────────────────────────┐                        │   │
│  │  │      复制的 Storage (只读)           │                        │   │
│  │  └─────────────────────────────────────┘                        │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7.2 灾备级别定义

| 级别 | 名称 | RPO | RTO | 方案 | 成本 |
|:---:|:---|:---:|:---:|:---|:---:|
| Tier-1 | 热备 | 0 | <15min | 同步复制+自动切换 | 高 |
| Tier-2 | 温备 | <1h | <1h | 异步复制+半自动切换 | 中 |
| Tier-3 | 冷备 | <24h | <4h | 定期备份+手动恢复 | 低 |
| Tier-4 | 备份 | <24h | <1d | 仅备份，手动重建 | 最低 |

### 7.3 自动 DR 切换脚本

```bash
#!/bin/bash
# dr-failover.sh - 灾难恢复切换脚本

set -e

PRIMARY_CLUSTER="ack-hangzhou-prod"
DR_CLUSTER="ack-shanghai-dr"
NAMESPACES="production staging"

echo "=== 开始灾难恢复切换 ==="

# 1. 切换 kubectl 上下文
kubectl config use-context $DR_CLUSTER

# 2. 确认存储复制状态
echo "检查存储复制状态..."
# 检查阿里云 DTS 复制状态或其他复制工具状态

# 3. 提升 DR 集群存储为读写
echo "提升存储为读写模式..."
# 具体操作取决于存储类型

# 4. 扩展 DR 集群工作负载
for NS in $NAMESPACES; do
  echo "扩展命名空间 $NS 的工作负载..."
  
  # 恢复 Deployment 副本数
  kubectl get deployment -n $NS -o name | xargs -I{} \
    kubectl scale {} -n $NS --replicas=$(kubectl get {} -n $NS -o jsonpath='{.metadata.annotations.original-replicas}')
  
  # 恢复 StatefulSet 副本数
  kubectl get statefulset -n $NS -o name | xargs -I{} \
    kubectl scale {} -n $NS --replicas=$(kubectl get {} -n $NS -o jsonpath='{.metadata.annotations.original-replicas}')
done

# 5. 更新 DNS 或负载均衡
echo "更新流量入口..."
# aliyun dns update-record ...
# 或更新 SLB 配置

# 6. 验证服务
echo "验证服务状态..."
kubectl get pods -A | grep -v Running

echo "=== 灾难恢复切换完成 ==="
```

---

## 8. 备份监控与告警

```yaml
groups:
  - name: backup-alerts
    rules:
      - alert: VeleroBackupFailed
        expr: |
          increase(velero_backup_failure_total[1h]) > 0
        for: 5m
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
          summary: "Velero 备份超过 24 小时未成功"
          
      - alert: VolumeSnapshotFailed
        expr: |
          kube_volumesnapshot_status_ready_to_use == 0
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: "VolumeSnapshot 创建失败"
```

---

## 9. 最佳实践清单

| 类别 | 建议 |
|:---|:---|
| **备份策略** | 实施 3-2-1 策略：3份副本、2种介质、1份异地 |
| **定期验证** | 每月执行一次恢复演练 |
| **加密** | 备份数据启用加密 |
| **保留策略** | 定义并执行备份保留策略 |
| **监控告警** | 监控备份成功率、备份时长 |
| **文档** | 维护恢复操作手册 |
| **权限** | 最小权限原则，备份账号分离 |
| **测试** | 在非生产环境测试恢复流程 |

---

**表格底部标记**: Kusheet Project | 作者: Allen Galler (allengaller@gmail.com)
