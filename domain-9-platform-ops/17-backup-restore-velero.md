# Velero 备份与恢复完整指南 (Velero Backup & Restore)

> **适用版本**: Kubernetes v1.25 - v1.32 | Velero v1.12 - v1.14  
> **文档版本**: v2.0 | 生产级 Velero 配置参考  
> **最后更新**: 2026-01

## Velero 完整架构

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                           Velero Complete Architecture                                  │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│  ┌───────────────────────────────────────────────────────────────────────────────────┐ │
│  │                              Control Plane                                         │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐ │ │
│  │  │                        Velero Server Deployment                              │ │ │
│  │  │                                                                              │ │ │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │ │ │
│  │  │  │   Backup     │  │   Restore    │  │   Schedule   │  │  GC/Sync     │    │ │ │
│  │  │  │  Controller  │  │  Controller  │  │  Controller  │  │  Controller  │    │ │ │
│  │  │  │              │  │              │  │              │  │              │    │ │ │
│  │  │  │ • Create     │  │ • Restore    │  │ • Cron-based │  │ • Cleanup    │    │ │ │
│  │  │  │ • Finalize   │  │ • Validate   │  │ • Auto-create│  │ • Sync BSL   │    │ │ │
│  │  │  │ • Upload     │  │ • Apply      │  │ • Retention  │  │ • Delete old │    │ │ │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │ │ │
│  │  │                                                                              │ │ │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                       │ │ │
│  │  │  │  BSL Sync    │  │  Download    │  │  Restic Repo │                       │ │ │
│  │  │  │  Controller  │  │  Request     │  │  Controller  │                       │ │ │
│  │  │  │              │  │  Controller  │  │              │                       │ │ │
│  │  │  │ • Validate   │  │ • Log access │  │ • Init repos │                       │ │ │
│  │  │  │ • Status     │  │ • Content    │  │ • Maintain   │                       │ │ │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘                       │ │ │
│  │  └─────────────────────────────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────────────────────────────┘ │
│                                          │                                              │
│                    ┌─────────────────────┼─────────────────────┐                       │
│                    │                     │                     │                       │
│                    ▼                     ▼                     ▼                       │
│  ┌─────────────────────────┐ ┌─────────────────────┐ ┌─────────────────────────┐     │
│  │    Object Storage       │ │   Volume Snapshots  │ │     Node Agent          │     │
│  │    Plugin               │ │   Plugin            │ │     DaemonSet           │     │
│  │                         │ │                     │ │                         │     │
│  │  ┌───────────────────┐ │ │  ┌───────────────┐  │ │  ┌───────────────────┐  │     │
│  │  │ velero-plugin-aws │ │ │  │ AWS EBS CSI   │  │ │  │   node-agent      │  │     │
│  │  │ velero-plugin-gcp │ │ │  │ Azure Disk    │  │ │  │                   │  │     │
│  │  │ velero-plugin-    │ │ │  │ GCE PD        │  │ │  │ • Kopia/Restic    │  │     │
│  │  │ microsoft-azure   │ │ │  │ Alibaba Disk  │  │ │  │ • File-level      │  │     │
│  │  │ velero-plugin-    │ │ │  │ Longhorn      │  │ │  │ • PV mount        │  │     │
│  │  │ alibabacloud      │ │ │  │ OpenEBS       │  │ │  │ • Dedup/Encrypt   │  │     │
│  │  └───────────────────┘ │ │  └───────────────┘  │ │  └───────────────────┘  │     │
│  └─────────────────────────┘ └─────────────────────┘ └─────────────────────────┘     │
│                    │                     │                     │                       │
│                    ▼                     ▼                     ▼                       │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐ │
│  │                           Storage Backends                                       │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │ │
│  │  │   AWS S3    │  │ Azure Blob  │  │    GCS      │  │Alibaba OSS  │            │ │
│  │  │             │  │   Storage   │  │             │  │             │            │ │
│  │  │ • Backups   │  │ • Backups   │  │ • Backups   │  │ • Backups   │            │ │
│  │  │ • Restic    │  │ • Restic    │  │ • Restic    │  │ • Restic    │            │ │
│  │  │   Repos     │  │   Repos     │  │   Repos     │  │   Repos     │            │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘            │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                             │ │
│  │  │   MinIO     │  │    NFS      │  │   Custom    │                             │ │
│  │  │  (S3 API)   │  │   Mount     │  │   Provider  │                             │ │
│  │  │             │  │             │  │             │                             │ │
│  │  │ • On-prem   │  │ • Local     │  │ • Plugin    │                             │ │
│  │  │ • Air-gap   │  │ • Testing   │  │   system    │                             │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                             │ │
│  └─────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                         │
│  ┌───────────────────────────────────────────────────────────────────────────────────┐ │
│  │                              CRD Resources                                         │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │ │
│  │  │ Backup   │ │ Restore  │ │ Schedule │ │ BSL      │ │ VSL      │ │ PVB/PVR  │  │ │
│  │  │          │ │          │ │          │ │          │ │          │ │          │  │ │
│  │  │ Backup   │ │ Restore  │ │ Backup   │ │ Object   │ │ Snapshot │ │ Pod Vol  │  │ │
│  │  │ request  │ │ request  │ │ schedule │ │ storage  │ │ location │ │ backup/  │  │ │
│  │  │          │ │          │ │          │ │ location │ │          │ │ restore  │  │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘  │ │
│  └───────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

## Velero CRD 详解

### CRD 资源对比矩阵

| CRD | 用途 | 作用域 | 主要字段 | 状态字段 |
|-----|------|-------|---------|---------|
| **Backup** | 创建备份请求 | Namespace | includedNamespaces, excludedResources, hooks | phase, progress, errors |
| **Restore** | 创建恢复请求 | Namespace | backupName, includedNamespaces, restorePVs | phase, progress, warnings |
| **Schedule** | 定时备份调度 | Namespace | schedule, template, useOwnerReferencesInBackup | lastBackup, phase |
| **BackupStorageLocation** | 对象存储配置 | Namespace | provider, bucket, config, credential | phase, lastSyncedTime |
| **VolumeSnapshotLocation** | 快照存储配置 | Namespace | provider, config, credential | phase |
| **PodVolumeBackup** | Pod卷备份状态 | Namespace | pod, volume, backupStorageLocation | phase, snapshotID |
| **PodVolumeRestore** | Pod卷恢复状态 | Namespace | pod, volume, snapshotID | phase |
| **BackupRepository** | Kopia/Restic仓库 | Namespace | volumeNamespace, backupStorageLocation | phase, lastMaintenanceTime |

---

## Velero 安装配置

### 多云提供商安装

```bash
#!/bin/bash
# velero-multicloud-install.sh - Multi-cloud Velero installation

set -euo pipefail

VELERO_VERSION="${VELERO_VERSION:-1.14.0}"
CLOUD_PROVIDER="${CLOUD_PROVIDER:-aws}"

# Download Velero CLI
install_velero_cli() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    [[ "$arch" == "x86_64" ]] && arch="amd64"
    [[ "$arch" == "aarch64" ]] && arch="arm64"
    
    curl -fsSL "https://github.com/vmware-tanzu/velero/releases/download/v${VELERO_VERSION}/velero-v${VELERO_VERSION}-${os}-${arch}.tar.gz" | \
        tar -xzf - -C /tmp
    
    sudo mv "/tmp/velero-v${VELERO_VERSION}-${os}-${arch}/velero" /usr/local/bin/
    velero version --client-only
}

# AWS Installation
install_aws() {
    cat > credentials-velero <<EOF
[default]
aws_access_key_id=${AWS_ACCESS_KEY_ID}
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
EOF

    velero install \
        --provider aws \
        --plugins velero/velero-plugin-for-aws:v1.9.0 \
        --bucket "${VELERO_BUCKET}" \
        --backup-location-config region="${AWS_REGION}" \
        --snapshot-location-config region="${AWS_REGION}" \
        --secret-file ./credentials-velero \
        --use-node-agent \
        --default-volumes-to-fs-backup
    
    rm -f credentials-velero
}

# Azure Installation
install_azure() {
    cat > credentials-velero <<EOF
AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
AZURE_TENANT_ID=${AZURE_TENANT_ID}
AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
AZURE_RESOURCE_GROUP=${AZURE_RESOURCE_GROUP}
AZURE_CLOUD_NAME=AzurePublicCloud
EOF

    velero install \
        --provider azure \
        --plugins velero/velero-plugin-for-microsoft-azure:v1.9.0 \
        --bucket "${AZURE_BLOB_CONTAINER}" \
        --backup-location-config \
            resourceGroup="${AZURE_RESOURCE_GROUP}",storageAccount="${AZURE_STORAGE_ACCOUNT}",subscriptionId="${AZURE_SUBSCRIPTION_ID}" \
        --snapshot-location-config \
            apiTimeout=5m,resourceGroup="${AZURE_RESOURCE_GROUP}",subscriptionId="${AZURE_SUBSCRIPTION_ID}" \
        --secret-file ./credentials-velero \
        --use-node-agent
    
    rm -f credentials-velero
}

# GCP Installation
install_gcp() {
    velero install \
        --provider gcp \
        --plugins velero/velero-plugin-for-gcp:v1.9.0 \
        --bucket "${GCP_BUCKET}" \
        --backup-location-config serviceAccount="${GCP_SERVICE_ACCOUNT}" \
        --snapshot-location-config project="${GCP_PROJECT}",snapshotLocation="${GCP_REGION}" \
        --secret-file "${GOOGLE_APPLICATION_CREDENTIALS}" \
        --use-node-agent
}

# Alibaba Cloud Installation
install_alicloud() {
    cat > credentials-velero <<EOF
ALIBABA_CLOUD_ACCESS_KEY_ID=${ALIBABA_ACCESS_KEY_ID}
ALIBABA_CLOUD_ACCESS_KEY_SECRET=${ALIBABA_ACCESS_KEY_SECRET}
EOF

    velero install \
        --provider alibabacloud \
        --plugins registry.cn-hangzhou.aliyuncs.com/acs/velero-plugin-alibabacloud:v1.8 \
        --bucket "${OSS_BUCKET}" \
        --backup-location-config region="${ALIBABA_REGION}" \
        --snapshot-location-config region="${ALIBABA_REGION}" \
        --secret-file ./credentials-velero \
        --use-node-agent
    
    rm -f credentials-velero
}

# MinIO (On-premises) Installation
install_minio() {
    cat > credentials-velero <<EOF
[default]
aws_access_key_id=${MINIO_ACCESS_KEY}
aws_secret_access_key=${MINIO_SECRET_KEY}
EOF

    velero install \
        --provider aws \
        --plugins velero/velero-plugin-for-aws:v1.9.0 \
        --bucket "${MINIO_BUCKET}" \
        --backup-location-config \
            region=minio,s3ForcePathStyle=true,s3Url="${MINIO_URL}" \
        --use-volume-snapshots=false \
        --secret-file ./credentials-velero \
        --use-node-agent
    
    rm -f credentials-velero
}

# Main
case "$CLOUD_PROVIDER" in
    aws) install_aws ;;
    azure) install_azure ;;
    gcp) install_gcp ;;
    alicloud) install_alicloud ;;
    minio) install_minio ;;
    *) echo "Unknown provider: $CLOUD_PROVIDER"; exit 1 ;;
esac

# Verify installation
kubectl get pods -n velero
velero backup-location get
velero snapshot-location get
```

### Helm 高级安装配置

```yaml
# velero-values.yaml - Production Helm values
image:
  repository: velero/velero
  tag: v1.14.0
  pullPolicy: IfNotPresent

# Node Agent (Restic/Kopia) configuration
deployNodeAgent: true
nodeAgent:
  podVolumePath: /var/lib/kubelet/pods
  privileged: true
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 2
      memory: 2Gi
  tolerations:
    - operator: Exists

# Main Velero deployment
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2
    memory: 2Gi

# Init containers for plugins
initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.9.0
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - mountPath: /target
        name: plugins
  - name: velero-plugin-for-csi
    image: velero/velero-plugin-for-csi:v0.7.0
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - mountPath: /target
        name: plugins

# Backup storage locations
configuration:
  backupStorageLocation:
    - name: default
      provider: aws
      bucket: my-velero-bucket
      prefix: backups
      default: true
      config:
        region: us-west-2
        s3ForcePathStyle: "false"
    - name: secondary
      provider: aws
      bucket: my-velero-bucket-dr
      prefix: backups-dr
      config:
        region: us-east-1
      accessMode: ReadOnly

  volumeSnapshotLocation:
    - name: default
      provider: aws
      config:
        region: us-west-2
    - name: dr-region
      provider: aws
      config:
        region: us-east-1

  # Default backup TTL
  defaultBackupTTL: 720h  # 30 days
  
  # Enable CSI snapshots
  features: EnableCSI
  
  # Uploader type: kopia or restic
  uploaderType: kopia
  
  # Garbage collection frequency
  garbageCollectionFrequency: 1h

# Credentials secret
credentials:
  useSecret: true
  name: cloud-credentials
  secretContents:
    cloud: |
      [default]
      aws_access_key_id=<ACCESS_KEY>
      aws_secret_access_key=<SECRET_KEY>

# Service account
serviceAccount:
  server:
    create: true
    name: velero
    annotations:
      # For AWS IRSA
      # eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/velero-role

# Pod security
podSecurityContext:
  runAsUser: 0
  fsGroup: 0

# Schedule templates
schedules:
  daily-full-backup:
    disabled: false
    schedule: "0 2 * * *"
    useOwnerReferencesInBackup: false
    template:
      ttl: 720h  # 30 days
      storageLocation: default
      volumeSnapshotLocations:
        - default
      includedNamespaces:
        - "*"
      excludedNamespaces:
        - kube-system
        - velero
      excludedResources:
        - events
        - events.events.k8s.io
      snapshotVolumes: true
      defaultVolumesToFsBackup: false
      hooks:
        resources: []
  
  weekly-archive:
    disabled: false
    schedule: "0 3 * * 0"
    template:
      ttl: 2160h  # 90 days
      storageLocation: secondary
      includedNamespaces:
        - production
        - staging
      snapshotVolumes: true

# Metrics
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    namespace: monitoring
    additionalLabels:
      release: prometheus
```

---

## 备份操作详解

### Backup 资源完整配置

```yaml
# backup-full-example.yaml
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: production-full-backup
  namespace: velero
  labels:
    backup-type: full
    environment: production
spec:
  # 包含的命名空间 (空数组 = 所有)
  includedNamespaces:
    - production
    - staging
  
  # 排除的命名空间
  excludedNamespaces:
    - kube-system
    - kube-public
  
  # 包含的资源类型 (空数组 = 所有)
  includedResources:
    - deployments
    - statefulsets
    - services
    - configmaps
    - secrets
    - persistentvolumeclaims
    - persistentvolumes
  
  # 排除的资源类型
  excludedResources:
    - events
    - events.events.k8s.io
    - pods
  
  # 标签选择器 (可选)
  labelSelector:
    matchLabels:
      backup: enabled
  
  # 或使用标签表达式
  orLabelSelectors:
    - matchLabels:
        app: frontend
    - matchLabels:
        app: backend
  
  # 是否包含集群范围资源
  includeClusterResources: true
  
  # 集群范围资源排除
  excludedClusterScopedResources:
    - storageclasses
    - nodes
  
  # 存储位置
  storageLocation: default
  
  # 卷快照位置
  volumeSnapshotLocations:
    - default
  
  # 是否创建卷快照
  snapshotVolumes: true
  
  # 默认使用文件系统备份 (Restic/Kopia)
  defaultVolumesToFsBackup: false
  
  # 备份保留时间 (TTL)
  ttl: 720h  # 30 days
  
  # 备份顺序控制
  orderedResources:
    # 先备份 CRDs，再备份 CR
    customresourcedefinitions: []
    namespaces:
      - production
      - staging
  
  # 备份钩子
  hooks:
    resources:
      # MySQL 备份前执行
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
                - |
                  mysqldump --all-databases --single-transaction \
                    --flush-logs --master-data=2 \
                    > /backup/pre-backup-dump.sql
              onError: Fail
              timeout: 5m
        post:
          - exec:
              container: mysql
              command:
                - /bin/bash
                - -c
                - rm -f /backup/pre-backup-dump.sql
              onError: Continue
              timeout: 1m
      
      # PostgreSQL quiesce
      - name: postgresql-hook
        includedNamespaces:
          - production
        labelSelector:
          matchLabels:
            app: postgresql
        pre:
          - exec:
              container: postgresql
              command:
                - /bin/bash
                - -c
                - psql -c "SELECT pg_start_backup('velero', false, false);"
              onError: Fail
              timeout: 30s
        post:
          - exec:
              container: postgresql
              command:
                - /bin/bash
                - -c
                - psql -c "SELECT pg_stop_backup(false, true);"
              onError: Continue
              timeout: 30s
      
      # Redis BGSAVE
      - name: redis-hook
        includedNamespaces:
          - production
        labelSelector:
          matchLabels:
            app: redis
        pre:
          - exec:
              container: redis
              command:
                - redis-cli
                - BGSAVE
              onError: Continue
              timeout: 30s
  
  # 元数据
  metadata:
    labels:
      created-by: velero
      backup-policy: daily
```

### 备份命令行操作

```bash
#!/bin/bash
# velero-backup-operations.sh

# ============== 创建备份 ==============

# 基础全量备份
velero backup create full-backup-$(date +%Y%m%d) \
  --wait

# 指定命名空间备份
velero backup create ns-backup-prod \
  --include-namespaces production,staging \
  --wait

# 使用标签选择器
velero backup create labeled-backup \
  --selector app=myapp \
  --wait

# 排除特定资源
velero backup create exclude-events \
  --exclude-resources events,events.events.k8s.io \
  --wait

# 仅备份资源定义（不含PV）
velero backup create resources-only \
  --snapshot-volumes=false \
  --default-volumes-to-fs-backup=false \
  --wait

# 使用 Restic/Kopia 文件系统备份
velero backup create fs-backup \
  --default-volumes-to-fs-backup \
  --wait

# 备份特定 PVC
velero backup create pvc-backup \
  --include-namespaces production \
  --include-resources persistentvolumeclaims,persistentvolumes \
  --wait

# 从 Schedule 创建备份
velero backup create --from-schedule daily-backup

# ============== 查看备份 ==============

# 列出所有备份
velero backup get

# 详细信息
velero backup describe full-backup-20240115

# 查看备份日志
velero backup logs full-backup-20240115

# 查看备份详情 (YAML)
velero backup get full-backup-20240115 -o yaml

# 查看备份包含的资源
velero backup describe full-backup-20240115 --details

# ============== 删除备份 ==============

# 删除单个备份
velero backup delete full-backup-20240115

# 删除所有过期备份
velero backup delete --all --confirm

# 根据标签删除
velero backup delete --selector backup-type=test --confirm
```

---

## 恢复操作详解

### Restore 资源完整配置

```yaml
# restore-full-example.yaml
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: production-restore
  namespace: velero
spec:
  # 源备份名称
  backupName: production-full-backup
  
  # 包含的命名空间
  includedNamespaces:
    - production
  
  # 排除的命名空间
  excludedNamespaces: []
  
  # 包含的资源
  includedResources:
    - "*"
  
  # 排除的资源
  excludedResources:
    - nodes
    - events
    - events.events.k8s.io
  
  # 命名空间映射 (恢复到不同命名空间)
  namespaceMapping:
    production: production-restored
    staging: staging-restored
  
  # 标签选择器
  labelSelector:
    matchLabels:
      restore: enabled
  
  # 是否恢复 PV
  restorePVs: true
  
  # 恢复状态 (保留原有副本数等)
  restoreStatus:
    includedResources:
      - deployments
      - replicasets
  
  # 现有资源处理策略
  existingResourcePolicy: none  # none, update
  
  # 保留 NodePort
  preserveNodePorts: true
  
  # 包含集群资源
  includeClusterResources: true
  
  # 资源修改器
  resourceModifier:
    version: v1
    patches:
      # 修改 ConfigMap 中的配置
      - operations:
          - operation: replace
            path: /data/DATABASE_HOST
            value: new-db-host.svc
        conditions:
          resourceNameRegex: ".*-config"
          namespaces:
            - production
          groupResource: configmaps
      
      # 修改 Deployment 副本数
      - operations:
          - operation: replace
            path: /spec/replicas
            value: "1"
        conditions:
          groupResource: deployments.apps
          namespaces:
            - production
  
  # 恢复钩子
  hooks:
    resources:
      # MySQL 恢复后初始化
      - name: mysql-init-hook
        includedNamespaces:
          - production
        labelSelector:
          matchLabels:
            app: mysql
        postHooks:
          - init:
              initContainers:
                - name: mysql-restore-check
                  image: mysql:8.0
                  command:
                    - /bin/bash
                    - -c
                    - |
                      until mysqladmin ping -h localhost; do
                        echo "Waiting for MySQL..."
                        sleep 5
                      done
                      echo "MySQL is ready"
              timeout: 10m
          - exec:
              container: mysql
              command:
                - /bin/bash
                - -c
                - |
                  mysql -e "FLUSH PRIVILEGES;"
                  echo "MySQL privileges flushed"
              execTimeout: 1m
              waitTimeout: 5m
              onError: Continue
      
      # 应用缓存预热
      - name: cache-warmup
        includedNamespaces:
          - production
        labelSelector:
          matchLabels:
            app: backend
        postHooks:
          - exec:
              container: backend
              command:
                - /bin/bash
                - -c
                - |
                  curl -X POST http://localhost:8080/admin/cache/warmup
              execTimeout: 5m
              waitTimeout: 10m
              onError: Continue
```

### 恢复命令行操作

```bash
#!/bin/bash
# velero-restore-operations.sh

# ============== 基础恢复 ==============

# 从最新备份恢复
velero restore create --from-backup production-full-backup --wait

# 恢复到不同命名空间
velero restore create \
  --from-backup production-full-backup \
  --namespace-mappings production:production-dr \
  --wait

# 仅恢复特定资源
velero restore create \
  --from-backup production-full-backup \
  --include-resources deployments,services,configmaps \
  --wait

# 排除 PVC 恢复
velero restore create \
  --from-backup production-full-backup \
  --restore-volumes=false \
  --wait

# ============== 高级恢复 ==============

# 使用标签选择器恢复
velero restore create \
  --from-backup production-full-backup \
  --selector app=myapp \
  --wait

# 覆盖现有资源
velero restore create \
  --from-backup production-full-backup \
  --existing-resource-policy update \
  --wait

# 恢复从 Schedule 创建的最新备份
LATEST_BACKUP=$(velero backup get -l velero.io/schedule-name=daily-backup \
  --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
velero restore create --from-backup "$LATEST_BACKUP" --wait

# ============== 查看恢复状态 ==============

# 列出所有恢复
velero restore get

# 查看恢复详情
velero restore describe production-restore-20240115

# 查看恢复日志
velero restore logs production-restore-20240115

# 查看恢复警告和错误
velero restore describe production-restore-20240115 --details

# ============== 部分恢复场景 ==============

# 仅恢复 ConfigMaps 和 Secrets
velero restore create config-restore \
  --from-backup production-full-backup \
  --include-resources configmaps,secrets \
  --wait

# 恢复单个命名空间
velero restore create single-ns-restore \
  --from-backup production-full-backup \
  --include-namespaces production \
  --wait

# 排除特定标签的资源
velero restore create exclude-labeled \
  --from-backup production-full-backup \
  --selector 'restore-exclude notin (true)' \
  --wait
```

---

## 调度配置详解

### Schedule 资源完整配置

```yaml
# schedule-examples.yaml
---
# 每日完整备份
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-full-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"  # 每天凌晨 2 点
  useOwnerReferencesInBackup: false
  template:
    ttl: 720h  # 30 天
    storageLocation: default
    volumeSnapshotLocations:
      - default
    includedNamespaces:
      - "*"
    excludedNamespaces:
      - kube-system
      - velero
      - monitoring
    excludedResources:
      - events
      - events.events.k8s.io
    snapshotVolumes: true
    defaultVolumesToFsBackup: false
    metadata:
      labels:
        schedule: daily
        type: full
---
# 每小时增量备份 (仅关键应用)
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: hourly-critical-backup
  namespace: velero
spec:
  schedule: "0 * * * *"  # 每小时
  template:
    ttl: 168h  # 7 天
    storageLocation: default
    includedNamespaces:
      - production
    labelSelector:
      matchLabels:
        tier: critical
    snapshotVolumes: true
    defaultVolumesToFsBackup: true
    metadata:
      labels:
        schedule: hourly
        type: incremental
---
# 每周归档备份 (长期保留)
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: weekly-archive
  namespace: velero
spec:
  schedule: "0 3 * * 0"  # 每周日凌晨 3 点
  template:
    ttl: 8760h  # 365 天
    storageLocation: archive
    includedNamespaces:
      - production
      - staging
    excludedResources:
      - events
      - events.events.k8s.io
      - pods
    snapshotVolumes: true
    metadata:
      labels:
        schedule: weekly
        type: archive
        compliance: required
---
# 数据库专用备份 (带 Hooks)
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: database-backup
  namespace: velero
spec:
  schedule: "0 */4 * * *"  # 每 4 小时
  template:
    ttl: 168h
    storageLocation: default
    includedNamespaces:
      - databases
    labelSelector:
      matchLabels:
        backup: database
    snapshotVolumes: true
    defaultVolumesToFsBackup: true
    hooks:
      resources:
        - name: mysql-quiesce
          includedNamespaces:
            - databases
          labelSelector:
            matchLabels:
              app: mysql
          pre:
            - exec:
                container: mysql
                command:
                  - /bin/bash
                  - -c
                  - mysql -e "FLUSH TABLES WITH READ LOCK; SELECT SLEEP(30);"
                onError: Fail
                timeout: 60s
          post:
            - exec:
                container: mysql
                command:
                  - /bin/bash
                  - -c
                  - mysql -e "UNLOCK TABLES;"
                onError: Continue
                timeout: 30s
    metadata:
      labels:
        schedule: 4hourly
        type: database
```

---

## 跨集群迁移

### 迁移架构图

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                        Cross-Cluster Migration with Velero                              │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│  ┌───────────────────────────────────┐       ┌───────────────────────────────────┐    │
│  │        Source Cluster             │       │       Destination Cluster          │    │
│  │                                   │       │                                    │    │
│  │  ┌─────────────────────────────┐ │       │  ┌─────────────────────────────┐  │    │
│  │  │      Velero Server          │ │       │  │      Velero Server          │  │    │
│  │  │                             │ │       │  │                             │  │    │
│  │  │  • Create Backup            │ │       │  │  • Sync from BSL            │  │    │
│  │  │  • Upload to BSL            │ │       │  │  • Create Restore           │  │    │
│  │  │  • Volume Snapshots         │ │       │  │  • Restore Resources        │  │    │
│  │  └─────────────────────────────┘ │       │  └─────────────────────────────┘  │    │
│  │             │                     │       │             │                      │    │
│  │             │ Backup              │       │             │ Restore              │    │
│  │             ▼                     │       │             ▼                      │    │
│  │  ┌─────────────────────────────┐ │       │  ┌─────────────────────────────┐  │    │
│  │  │      Workloads              │ │       │  │      Workloads              │  │    │
│  │  │                             │ │       │  │                             │  │    │
│  │  │  • Deployments              │ │ ─────►│  │  • Deployments              │  │    │
│  │  │  • StatefulSets             │ │       │  │  • StatefulSets             │  │    │
│  │  │  • ConfigMaps/Secrets       │ │       │  │  • ConfigMaps/Secrets       │  │    │
│  │  │  • PVCs                     │ │       │  │  • PVCs                     │  │    │
│  │  └─────────────────────────────┘ │       │  └─────────────────────────────┘  │    │
│  └───────────────────────────────────┘       └───────────────────────────────────┘    │
│                    │                                          ▲                        │
│                    │                                          │                        │
│                    │          ┌─────────────────────┐        │                        │
│                    │          │   Shared Storage    │        │                        │
│                    │          │                     │        │                        │
│                    └─────────►│  ┌───────────────┐ │────────┘                        │
│                               │  │  S3 Bucket    │ │                                  │
│                               │  │               │ │                                  │
│                               │  │ • Backup      │ │                                  │
│                               │  │   Manifests   │ │                                  │
│                               │  │ • Restic/     │ │                                  │
│                               │  │   Kopia Repo  │ │                                  │
│                               │  │ • Logs        │ │                                  │
│                               │  └───────────────┘ │                                  │
│                               │                     │                                  │
│                               │  Volume Snapshots   │                                  │
│                               │  (Cross-region)     │                                  │
│                               └─────────────────────┘                                  │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### 跨集群迁移脚本

```bash
#!/bin/bash
# cross-cluster-migration.sh - Complete migration workflow

set -euo pipefail

# Configuration
SOURCE_CLUSTER="${SOURCE_CLUSTER:-source-cluster}"
DEST_CLUSTER="${DEST_CLUSTER:-dest-cluster}"
NAMESPACES="${NAMESPACES:-production,staging}"
BACKUP_NAME="migration-$(date +%Y%m%d%H%M%S)"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Step 1: Pre-migration checks on source
pre_migration_checks_source() {
    log "=== Pre-migration checks on source cluster ==="
    
    kubectl config use-context "$SOURCE_CLUSTER"
    
    # Check Velero status
    velero backup-location get
    velero snapshot-location get
    
    # List resources to migrate
    for ns in ${NAMESPACES//,/ }; do
        log "Resources in namespace $ns:"
        kubectl get all,configmaps,secrets,pvc -n "$ns" --no-headers | wc -l
    done
    
    # Check for unsupported resources
    log "Checking for potential issues..."
    kubectl get pvc --all-namespaces -o json | \
        jq -r '.items[] | select(.spec.storageClassName == null) | "\(.metadata.namespace)/\(.metadata.name)"' | \
        while read -r pvc; do
            log "WARNING: PVC without storageClassName: $pvc"
        done
}

# Step 2: Create backup on source
create_source_backup() {
    log "=== Creating backup on source cluster ==="
    
    kubectl config use-context "$SOURCE_CLUSTER"
    
    # Create comprehensive backup
    velero backup create "$BACKUP_NAME" \
        --include-namespaces "${NAMESPACES}" \
        --include-cluster-resources=true \
        --default-volumes-to-fs-backup \
        --wait
    
    # Verify backup
    velero backup describe "$BACKUP_NAME" --details
    
    # Check for errors
    local errors=$(velero backup describe "$BACKUP_NAME" -o json | jq -r '.status.errors // 0')
    if [[ "$errors" != "0" && "$errors" != "null" ]]; then
        log "ERROR: Backup has $errors errors"
        velero backup logs "$BACKUP_NAME"
        exit 1
    fi
    
    log "Backup $BACKUP_NAME created successfully"
}

# Step 3: Prepare destination cluster
prepare_destination() {
    log "=== Preparing destination cluster ==="
    
    kubectl config use-context "$DEST_CLUSTER"
    
    # Ensure Velero is installed
    if ! kubectl get deployment velero -n velero &>/dev/null; then
        log "ERROR: Velero not installed on destination cluster"
        exit 1
    fi
    
    # Configure BSL to same bucket
    velero backup-location get
    
    # Sync backups from source
    log "Syncing backups from shared storage..."
    sleep 30  # Wait for sync
    
    # Verify backup is visible
    velero backup get "$BACKUP_NAME" || {
        log "ERROR: Backup not found on destination"
        exit 1
    }
}

# Step 4: Pre-restore preparation
pre_restore_preparation() {
    log "=== Pre-restore preparation ==="
    
    kubectl config use-context "$DEST_CLUSTER"
    
    # Create namespaces if needed (for namespace mapping)
    for ns in ${NAMESPACES//,/ }; do
        local target_ns="${ns}-migrated"
        if ! kubectl get namespace "$target_ns" &>/dev/null; then
            kubectl create namespace "$target_ns"
            log "Created namespace: $target_ns"
        fi
    done
    
    # Create storage classes if different
    # kubectl apply -f storage-class-mapping.yaml
    
    # Create secrets for external services
    # kubectl apply -f external-secrets.yaml
}

# Step 5: Restore on destination
restore_on_destination() {
    log "=== Restoring on destination cluster ==="
    
    kubectl config use-context "$DEST_CLUSTER"
    
    local restore_name="${BACKUP_NAME}-restore"
    
    # Build namespace mapping
    local ns_mapping=""
    for ns in ${NAMESPACES//,/ }; do
        [[ -n "$ns_mapping" ]] && ns_mapping+=","
        ns_mapping+="${ns}:${ns}-migrated"
    done
    
    # Create restore
    velero restore create "$restore_name" \
        --from-backup "$BACKUP_NAME" \
        --namespace-mappings "$ns_mapping" \
        --restore-volumes=true \
        --wait
    
    # Check restore status
    velero restore describe "$restore_name" --details
    
    local phase=$(velero restore describe "$restore_name" -o json | jq -r '.status.phase')
    if [[ "$phase" != "Completed" ]]; then
        log "WARNING: Restore phase is $phase"
        velero restore logs "$restore_name"
    fi
}

# Step 6: Post-migration validation
post_migration_validation() {
    log "=== Post-migration validation ==="
    
    kubectl config use-context "$DEST_CLUSTER"
    
    for ns in ${NAMESPACES//,/ }; do
        local target_ns="${ns}-migrated"
        log "Validating namespace: $target_ns"
        
        # Check pods
        kubectl get pods -n "$target_ns"
        
        # Check PVCs
        kubectl get pvc -n "$target_ns"
        
        # Check services
        kubectl get svc -n "$target_ns"
        
        # Wait for pods to be ready
        kubectl wait --for=condition=ready pod -l app --timeout=300s -n "$target_ns" || true
    done
    
    log "=== Migration Summary ==="
    log "Source Cluster: $SOURCE_CLUSTER"
    log "Destination Cluster: $DEST_CLUSTER"
    log "Backup: $BACKUP_NAME"
    log "Namespaces: $NAMESPACES"
}

# Main
main() {
    log "Starting cross-cluster migration..."
    
    pre_migration_checks_source
    create_source_backup
    prepare_destination
    pre_restore_preparation
    restore_on_destination
    post_migration_validation
    
    log "Migration completed successfully!"
}

main "$@"
```

---

## Hooks 机制详解

### Hook 类型对比

| Hook 类型 | 执行时机 | 用途 | 超时默认值 |
|----------|---------|------|-----------|
| **Backup Pre Hook** | 备份前 | 应用静默、刷新缓存 | 30s |
| **Backup Post Hook** | 备份后 | 解除静默、清理 | 30s |
| **Restore Init Hook** | Pod 创建时 | 数据初始化、迁移 | 无限制 |
| **Restore Exec Hook** | Pod 就绪后 | 配置验证、缓存预热 | 30s |

### 完整 Hook 示例

```yaml
# hooks-comprehensive.yaml
---
# Backup with comprehensive hooks
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: app-backup-with-hooks
  namespace: velero
spec:
  includedNamespaces:
    - production
  hooks:
    resources:
      # MySQL - Flush and Lock
      - name: mysql-backup-hooks
        includedNamespaces:
          - production
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: mysql
        pre:
          - exec:
              container: mysql
              command:
                - /bin/bash
                - -c
                - |
                  set -e
                  echo "Starting MySQL backup preparation..."
                  
                  # Flush all tables to disk
                  mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "FLUSH TABLES WITH READ LOCK;"
                  
                  # Record binlog position
                  mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SHOW MASTER STATUS\G" > /backup/binlog-position.txt
                  
                  # Sync filesystem
                  sync
                  
                  echo "MySQL ready for backup"
              onError: Fail
              timeout: 60s
        post:
          - exec:
              container: mysql
              command:
                - /bin/bash
                - -c
                - |
                  mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "UNLOCK TABLES;"
                  echo "MySQL tables unlocked"
              onError: Continue
              timeout: 30s
      
      # PostgreSQL - pg_start_backup
      - name: postgresql-backup-hooks
        includedNamespaces:
          - production
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: postgresql
        pre:
          - exec:
              container: postgresql
              command:
                - /bin/bash
                - -c
                - |
                  set -e
                  psql -U postgres -c "SELECT pg_start_backup('velero_backup', false, false);"
                  echo "PostgreSQL backup started"
              onError: Fail
              timeout: 30s
        post:
          - exec:
              container: postgresql
              command:
                - /bin/bash
                - -c
                - |
                  psql -U postgres -c "SELECT pg_stop_backup(false, true);"
                  echo "PostgreSQL backup stopped"
              onError: Continue
              timeout: 30s
      
      # MongoDB - fsync and lock
      - name: mongodb-backup-hooks
        includedNamespaces:
          - production
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: mongodb
        pre:
          - exec:
              container: mongodb
              command:
                - /bin/bash
                - -c
                - |
                  mongosh --eval "db.fsyncLock()"
                  echo "MongoDB fsync locked"
              onError: Fail
              timeout: 60s
        post:
          - exec:
              container: mongodb
              command:
                - /bin/bash
                - -c
                - |
                  mongosh --eval "db.fsyncUnlock()"
                  echo "MongoDB unlocked"
              onError: Continue
              timeout: 30s
      
      # Elasticsearch - Flush
      - name: elasticsearch-backup-hooks
        includedNamespaces:
          - production
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: elasticsearch
        pre:
          - exec:
              container: elasticsearch
              command:
                - /bin/bash
                - -c
                - |
                  curl -X POST "localhost:9200/_flush/synced?pretty"
                  echo "Elasticsearch synced flush completed"
              onError: Continue
              timeout: 120s
      
      # Redis - BGSAVE
      - name: redis-backup-hooks
        includedNamespaces:
          - production
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: redis
        pre:
          - exec:
              container: redis
              command:
                - /bin/bash
                - -c
                - |
                  redis-cli BGSAVE
                  while [ $(redis-cli LASTSAVE) == $(redis-cli LASTSAVE) ]; do
                    sleep 1
                  done
                  echo "Redis BGSAVE completed"
              onError: Continue
              timeout: 300s
---
# Restore with init and exec hooks
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: app-restore-with-hooks
  namespace: velero
spec:
  backupName: app-backup-with-hooks
  hooks:
    resources:
      # MySQL - Post-restore initialization
      - name: mysql-restore-hooks
        includedNamespaces:
          - production
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: mysql
        postHooks:
          - init:
              initContainers:
                - name: wait-for-mysql
                  image: mysql:8.0
                  command:
                    - /bin/bash
                    - -c
                    - |
                      echo "Waiting for MySQL to be ready..."
                      until mysqladmin ping -h localhost -u root -p${MYSQL_ROOT_PASSWORD} --silent; do
                        echo "MySQL is not ready yet..."
                        sleep 5
                      done
                      echo "MySQL is ready!"
              timeout: 600s
          - exec:
              container: mysql
              command:
                - /bin/bash
                - -c
                - |
                  echo "Running post-restore MySQL tasks..."
                  
                  # Analyze tables
                  mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "
                    SELECT CONCAT('ANALYZE TABLE ', table_schema, '.', table_name, ';')
                    FROM information_schema.tables
                    WHERE table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
                  " | mysql -u root -p${MYSQL_ROOT_PASSWORD}
                  
                  # Reset replication if needed
                  mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "RESET SLAVE ALL;"
                  
                  echo "MySQL post-restore tasks completed"
              execTimeout: 300s
              waitTimeout: 600s
              onError: Continue
      
      # Application - Cache warmup
      - name: app-warmup-hooks
        includedNamespaces:
          - production
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: backend
        postHooks:
          - exec:
              container: backend
              command:
                - /bin/bash
                - -c
                - |
                  echo "Warming up application caches..."
                  
                  # Wait for app to be ready
                  until curl -sf http://localhost:8080/health; do
                    echo "Waiting for application..."
                    sleep 5
                  done
                  
                  # Trigger cache warmup
                  curl -X POST http://localhost:8080/admin/cache/warmup
                  
                  # Verify cache is populated
                  curl http://localhost:8080/admin/cache/stats
                  
                  echo "Cache warmup completed"
              execTimeout: 600s
              waitTimeout: 900s
              onError: Continue
```

---

## 监控与告警

### Prometheus 监控配置

```yaml
# velero-prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: velero-monitoring
  namespace: monitoring
  labels:
    prometheus: k8s
    role: alert-rules
spec:
  groups:
    - name: velero.rules
      interval: 60s
      rules:
        # Recording rules
        - record: velero_backup_success_rate
          expr: |
            sum(increase(velero_backup_success_total[24h])) / 
            (sum(increase(velero_backup_success_total[24h])) + 
             sum(increase(velero_backup_failure_total[24h])))
        
        - record: velero_backup_duration_seconds_p95
          expr: |
            histogram_quantile(0.95, sum(rate(velero_backup_duration_seconds_bucket[1h])) by (le, schedule))
        
        - record: velero_restore_success_rate
          expr: |
            sum(increase(velero_restore_success_total[24h])) / 
            (sum(increase(velero_restore_success_total[24h])) + 
             sum(increase(velero_restore_failed_total[24h])))

    - name: velero.alerts
      rules:
        # Backup alerts
        - alert: VeleroBackupFailed
          expr: increase(velero_backup_failure_total[1h]) > 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Velero backup failed"
            description: "Velero backup has failed. Check velero logs for details."
            runbook_url: "https://runbooks.example.com/velero-backup-failed"
        
        - alert: VeleroBackupPartiallyFailed
          expr: increase(velero_backup_partial_failure_total[1h]) > 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Velero backup partially failed"
            description: "Velero backup completed with warnings or partial failures."
        
        - alert: VeleroScheduledBackupMissing
          expr: |
            time() - velero_backup_last_successful_timestamp{schedule!=""} > 86400
          for: 30m
          labels:
            severity: warning
          annotations:
            summary: "Scheduled backup missing"
            description: "Schedule {{ $labels.schedule }} has not completed successfully in 24 hours."
        
        - alert: VeleroBackupDurationHigh
          expr: velero_backup_duration_seconds_p95 > 3600
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "Backup duration is high"
            description: "Backup schedule {{ $labels.schedule }} P95 duration is {{ $value | humanizeDuration }}."
        
        # Storage alerts
        - alert: VeleroBackupStorageLocationUnavailable
          expr: velero_backup_storage_location_available == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Backup storage location unavailable"
            description: "Backup storage location {{ $labels.name }} is not available."
        
        - alert: VeleroVolumeSnapshotLocationUnavailable
          expr: velero_volume_snapshot_location_available == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Volume snapshot location unavailable"
            description: "Volume snapshot location {{ $labels.name }} is not available."
        
        # Restore alerts
        - alert: VeleroRestoreFailed
          expr: increase(velero_restore_failed_total[1h]) > 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Velero restore failed"
            description: "Velero restore operation has failed. Investigate immediately."
        
        # Pod volume backup alerts
        - alert: VeleroPodVolumeBackupFailed
          expr: |
            sum by (namespace, pod) (
              kube_pod_status_phase{phase="Failed"} * on(pod, namespace) 
              group_left() (label_replace(velero_pod_volume_backup_duration_seconds, "pod", "$1", "pod", "(.*)"))
            ) > 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Pod volume backup failed"
            description: "Pod volume backup for {{ $labels.namespace }}/{{ $labels.pod }} has failed."
        
        # Velero server health
        - alert: VeleroServerDown
          expr: |
            absent(up{job="velero"}) or up{job="velero"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Velero server is down"
            description: "Velero server is not responding. Backups and restores will not work."
        
        - alert: VeleroNodeAgentDown
          expr: |
            kube_daemonset_status_number_unavailable{daemonset="node-agent"} > 0
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Velero node agent unavailable"
            description: "{{ $value }} Velero node agent pods are unavailable."
```

### ServiceMonitor 配置

```yaml
# velero-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: velero
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: velero
  namespaceSelector:
    matchNames:
      - velero
  endpoints:
    - port: http-monitoring
      interval: 30s
      path: /metrics
```

---

## 故障排除

### 常见问题诊断

```bash
#!/bin/bash
# velero-troubleshoot.sh

# ============== Velero 健康检查 ==============
check_velero_health() {
    echo "=== Velero Health Check ==="
    
    # Check Velero deployment
    kubectl get deployment velero -n velero
    kubectl get pods -n velero -l app.kubernetes.io/name=velero
    
    # Check node-agent DaemonSet
    kubectl get daemonset node-agent -n velero 2>/dev/null || echo "Node agent not deployed"
    
    # Check CRDs
    kubectl get crd | grep velero
    
    # Check BSL status
    velero backup-location get
    
    # Check VSL status
    velero snapshot-location get
}

# ============== 备份问题诊断 ==============
diagnose_backup_issue() {
    local backup_name="${1:-}"
    
    if [[ -z "$backup_name" ]]; then
        echo "Usage: diagnose_backup_issue <backup-name>"
        return 1
    fi
    
    echo "=== Diagnosing Backup: $backup_name ==="
    
    # Get backup status
    velero backup describe "$backup_name" --details
    
    # Get backup logs
    echo "=== Backup Logs ==="
    velero backup logs "$backup_name"
    
    # Check for specific errors
    echo "=== Error Analysis ==="
    velero backup logs "$backup_name" 2>/dev/null | grep -i "error\|fail\|warn" || echo "No errors found"
    
    # Check Velero server logs
    echo "=== Velero Server Logs ==="
    kubectl logs -n velero -l app.kubernetes.io/name=velero --tail=100 | grep -i "$backup_name"
}

# ============== 恢复问题诊断 ==============
diagnose_restore_issue() {
    local restore_name="${1:-}"
    
    if [[ -z "$restore_name" ]]; then
        echo "Usage: diagnose_restore_issue <restore-name>"
        return 1
    fi
    
    echo "=== Diagnosing Restore: $restore_name ==="
    
    # Get restore status
    velero restore describe "$restore_name" --details
    
    # Get restore logs
    echo "=== Restore Logs ==="
    velero restore logs "$restore_name"
    
    # Check for warnings
    echo "=== Warnings ==="
    velero restore describe "$restore_name" -o json | jq -r '.status.warnings // []'
}

# ============== BSL 问题诊断 ==============
diagnose_bsl_issue() {
    echo "=== BSL Diagnostics ==="
    
    # Check all BSLs
    kubectl get backupstoragelocation -n velero -o yaml
    
    # Check credentials
    echo "=== Checking Credentials ==="
    kubectl get secret -n velero -l velero.io/secret-for=backup-storage-location
    
    # Test connectivity (AWS S3)
    local bucket=$(kubectl get bsl default -n velero -o jsonpath='{.spec.objectStorage.bucket}')
    local region=$(kubectl get bsl default -n velero -o jsonpath='{.spec.config.region}')
    
    echo "Testing S3 connectivity to bucket: $bucket in region: $region"
    
    # Check Velero server logs for BSL errors
    kubectl logs -n velero -l app.kubernetes.io/name=velero --tail=50 | grep -i "backup storage location"
}

# ============== Volume 备份问题诊断 ==============
diagnose_volume_backup() {
    echo "=== Volume Backup Diagnostics ==="
    
    # Check PodVolumeBackups
    kubectl get podvolumebackups -n velero
    
    # Check node-agent pods
    kubectl get pods -n velero -l name=node-agent
    
    # Check node-agent logs
    echo "=== Node Agent Logs ==="
    kubectl logs -n velero -l name=node-agent --tail=50 -c node-agent
    
    # Check BackupRepository status
    kubectl get backuprepository -n velero
}

# ============== 清理问题资源 ==============
cleanup_stuck_resources() {
    echo "=== Cleaning up stuck resources ==="
    
    # Find stuck backups
    local stuck_backups=$(kubectl get backup -n velero -o json | \
        jq -r '.items[] | select(.status.phase == "InProgress" or .status.phase == "New") | .metadata.name')
    
    for backup in $stuck_backups; do
        echo "Found stuck backup: $backup"
        read -p "Delete? (y/n): " confirm
        if [[ "$confirm" == "y" ]]; then
            kubectl delete backup "$backup" -n velero --force --grace-period=0
        fi
    done
    
    # Find stuck restores
    local stuck_restores=$(kubectl get restore -n velero -o json | \
        jq -r '.items[] | select(.status.phase == "InProgress" or .status.phase == "New") | .metadata.name')
    
    for restore in $stuck_restores; do
        echo "Found stuck restore: $restore"
        read -p "Delete? (y/n): " confirm
        if [[ "$confirm" == "y" ]]; then
            kubectl delete restore "$restore" -n velero --force --grace-period=0
        fi
    done
}

# Main menu
case "${1:-}" in
    health) check_velero_health ;;
    backup) diagnose_backup_issue "$2" ;;
    restore) diagnose_restore_issue "$2" ;;
    bsl) diagnose_bsl_issue ;;
    volume) diagnose_volume_backup ;;
    cleanup) cleanup_stuck_resources ;;
    *)
        echo "Usage: $0 {health|backup|restore|bsl|volume|cleanup}"
        ;;
esac
```

### 常见错误及解决方案

| 错误 | 原因 | 解决方案 |
|-----|------|---------|
| `BackupStorageLocation is unavailable` | 存储连接失败 | 检查凭证、网络、Bucket权限 |
| `error getting credentials` | Secret 配置错误 | 验证 Secret 格式和内容 |
| `volume snapshot location not found` | VSL 未配置 | 创建 VolumeSnapshotLocation |
| `CSI snapshot class not found` | CSI 驱动问题 | 安装 CSI 驱动和快照控制器 |
| `pod volume backup failed` | Node agent 问题 | 检查 node-agent DaemonSet |
| `timeout waiting for pod` | Hook 超时 | 增加 timeout 值 |
| `resource already exists` | 恢复冲突 | 使用 `existingResourcePolicy: update` |
| `insufficient permissions` | RBAC 问题 | 检查 ServiceAccount 权限 |

---

## 最佳实践清单

### Velero 配置检查清单

| 检查项 | 说明 | 状态 |
|-------|------|------|
| **多 BSL 配置** | 配置主备存储位置 | ☐ |
| **跨区域备份** | 启用跨区域快照复制 | ☐ |
| **备份加密** | 启用 Kopia/Restic 加密 | ☐ |
| **定期调度** | 配置每日/每周备份计划 | ☐ |
| **保留策略** | 设置合理的 TTL | ☐ |
| **监控告警** | 配置 Prometheus 规则 | ☐ |
| **恢复测试** | 定期执行恢复演练 | ☐ |
| **Hook 配置** | 为数据库配置静默钩子 | ☐ |
| **资源排除** | 排除 events 等临时资源 | ☐ |
| **RBAC 最小权限** | 限制 Velero ServiceAccount 权限 | ☐ |

---

## 版本变更记录

| Velero版本 | K8s版本 | 主要变更 |
|-----------|--------|---------|
| v1.14 | v1.25-v1.32 | Kopia GA、改进的 CSI 快照、资源修改器 |
| v1.13 | v1.24-v1.30 | 数据移动器增强、备份仓库改进 |
| v1.12 | v1.23-v1.29 | Kopia beta、改进的恢复钩子 |
| v1.11 | v1.22-v1.28 | CSI 快照增强、多架构支持 |
| v1.10 | v1.21-v1.27 | 资源过滤改进、备份进度追踪 |
| v1.9 | v1.20-v1.26 | 恢复钩子、命名空间映射增强 |

---

> **参考文档**:  
> - [Velero 官方文档](https://velero.io/docs/)
> - [Velero GitHub](https://github.com/vmware-tanzu/velero)
> - [Velero 插件列表](https://velero.io/plugins/)

---

*Kusheet - Kubernetes 知识速查表项目*
