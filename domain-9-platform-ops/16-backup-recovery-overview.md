# Kubernetes 备份与恢复概述 (Backup & Recovery Overview)

> **适用版本**: Kubernetes v1.25 - v1.32  
> **文档版本**: v2.0 | 生产级备份与恢复参考指南  
> **最后更新**: 2026-01

## 备份与恢复整体架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    Kubernetes Backup & Recovery Architecture                        │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                         Backup Strategy Layer                                │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │   │
│  │  │   Full      │  │ Incremental │  │ Differential│  │ Continuous  │        │   │
│  │  │   Backup    │  │   Backup    │  │   Backup    │  │   Backup    │        │   │
│  │  │             │  │             │  │             │  │   (CDP)     │        │   │
│  │  │  Complete   │  │  Changes    │  │  Changes    │  │  Real-time  │        │   │
│  │  │  Snapshot   │  │  Since Last │  │  Since Full │  │  Replication│        │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                            │
│                                        ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                         Backup Target Layer                                  │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │   │
│  │  │  Control Plane  │  │   Workloads     │  │  Persistent     │             │   │
│  │  │                 │  │                 │  │  Data           │             │   │
│  │  │  • etcd         │  │  • Deployments  │  │  • PVC/PV       │             │   │
│  │  │  • Certificates │  │  • StatefulSets │  │  • CSI Snapshots│             │   │
│  │  │  • Kubeconfigs  │  │  • ConfigMaps   │  │  • Volume Data  │             │   │
│  │  │  • Static Pods  │  │  • Secrets      │  │  • Database     │             │   │
│  │  │  • RBAC         │  │  • CRDs/CRs     │  │  • File Storage │             │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘             │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                            │
│                                        ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                         Backup Tools Layer                                   │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐ │   │
│  │  │  etcdctl  │  │  Velero   │  │  Kasten   │  │  Stash    │  │  Longhorn │ │   │
│  │  │           │  │           │  │  K10      │  │           │  │           │ │   │
│  │  │ etcd-only │  │ Full K8s  │  │Enterprise │  │ CRD-based │  │ Built-in  │ │   │
│  │  │ snapshot  │  │ backup    │  │ DR        │  │ backup    │  │ snapshots │ │   │
│  │  └───────────┘  └───────────┘  └───────────┘  └───────────┘  └───────────┘ │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                            │
│                                        ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                         Storage Backend Layer                                │   │
│  │  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐ │   │
│  │  │   Object Storage    │  │    Block Storage    │  │     File Storage    │ │   │
│  │  │                     │  │                     │  │                     │ │   │
│  │  │  • AWS S3           │  │  • AWS EBS          │  │  • AWS EFS          │ │   │
│  │  │  • Azure Blob       │  │  • Azure Disk       │  │  • Azure Files      │ │   │
│  │  │  • GCS              │  │  • GCE PD           │  │  • GCP Filestore    │ │   │
│  │  │  • Alibaba OSS      │  │  • Alibaba Cloud    │  │  • Alibaba NAS      │ │   │
│  │  │  • MinIO            │  │    Disk             │  │  • NFS              │ │   │
│  │  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                         Recovery Layer                                       │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │   │
│  │  │  Point-in-Time  │  │  Selective      │  │  Cross-Cluster  │             │   │
│  │  │  Recovery       │  │  Restore        │  │  Migration      │             │   │
│  │  │                 │  │                 │  │                 │             │   │
│  │  │  Restore to     │  │  Namespace/     │  │  DR failover    │             │   │
│  │  │  specific time  │  │  Resource level │  │  & migration    │             │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘             │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 备份类型全面对比

| 备份类型 | 备份范围 | 恢复速度 | 存储效率 | RPO | 适用场景 | 复杂度 |
|---------|---------|---------|---------|-----|---------|-------|
| **Full Backup** | 完整集群 | 最快 | 最低 | 备份周期 | 基线备份 | 低 |
| **Incremental** | 变更数据 | 中等 | 高 | 分钟级 | 频繁变更 | 中 |
| **Differential** | 自Full后变更 | 较快 | 中 | 小时级 | 平衡方案 | 中 |
| **Continuous** | 实时同步 | 最快 | 最高 | 秒级 | 关键业务 | 高 |
| **etcd Snapshot** | etcd数据 | 快 | 高 | 分钟级 | 控制平面 | 低 |
| **Volume Snapshot** | PV数据 | 快 | 高 | 分钟级 | 持久化数据 | 低 |
| **GitOps Backup** | 声明式配置 | 中等 | 最高 | 提交级 | IaC环境 | 低 |

## 备份范围详细矩阵

| 备份目标 | 备份工具 | 数据类型 | 备份方法 | 恢复方式 | 优先级 |
|---------|---------|---------|---------|---------|-------|
| **etcd数据** | etcdctl | 集群状态 | 快照 | 快照恢复 | P0 |
| **证书文件** | rsync/tar | PKI证书 | 文件复制 | 文件还原 | P0 |
| **Static Pods** | rsync/tar | 清单文件 | 文件复制 | 文件还原 | P0 |
| **kubeconfig** | rsync/tar | 认证配置 | 文件复制 | 文件还原 | P0 |
| **Deployments** | Velero/kubectl | 工作负载 | API导出 | API创建 | P1 |
| **StatefulSets** | Velero | 有状态应用 | API+PV | API+PV恢复 | P1 |
| **ConfigMaps** | Velero/kubectl | 配置数据 | API导出 | API创建 | P1 |
| **Secrets** | Velero | 敏感数据 | 加密导出 | 加密恢复 | P1 |
| **PVC/PV** | CSI Snapshot | 存储数据 | 卷快照 | 快照恢复 | P1 |
| **CRDs** | Velero/kubectl | 自定义资源 | API导出 | API创建 | P2 |
| **RBAC** | Velero/kubectl | 权限配置 | API导出 | API创建 | P2 |
| **NetworkPolicy** | Velero/kubectl | 网络策略 | API导出 | API创建 | P2 |
| **应用数据库** | 数据库工具 | 业务数据 | 逻辑/物理 | 数据库恢复 | P0 |

## 备份工具对比矩阵

| 特性 | etcdctl | Velero | Kasten K10 | Stash | Longhorn |
|-----|---------|--------|------------|-------|----------|
| **etcd备份** | ✅ 原生 | ❌ | ❌ | ❌ | ❌ |
| **资源备份** | ❌ | ✅ | ✅ | ✅ | ❌ |
| **PV备份** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **应用感知** | ❌ | ✅ Hooks | ✅ Blueprint | ✅ Hooks | ❌ |
| **增量备份** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **跨集群恢复** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **调度备份** | 需Cron | ✅ | ✅ | ✅ | ✅ |
| **加密** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **S3兼容** | ❌ | ✅ | ✅ | ✅ | ✅ |
| **Web UI** | ❌ | ❌ | ✅ | ❌ | ✅ |
| **成本** | 免费 | 免费 | 商业 | 免费 | 免费 |
| **社区支持** | 高 | 高 | 商业 | 中 | 高 |

---

## etcd 备份与恢复详解

### etcd 备份架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        etcd Backup Architecture                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     etcd Cluster (3 nodes)                       │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │   │
│  │  │   etcd-0      │  │   etcd-1      │  │   etcd-2      │       │   │
│  │  │   (Leader)    │  │   (Follower)  │  │   (Follower)  │       │   │
│  │  │               │  │               │  │               │       │   │
│  │  │  Raft Log     │◄─┤  Raft Log     │◄─┤  Raft Log     │       │   │
│  │  │  + Snapshot   │  │  + Snapshot   │  │  + Snapshot   │       │   │
│  │  └───────┬───────┘  └───────────────┘  └───────────────┘       │   │
│  │          │                                                       │   │
│  │          │ etcdctl snapshot save                                │   │
│  │          ▼                                                       │   │
│  │  ┌───────────────────────────────────────────────────────────┐ │   │
│  │  │              Snapshot File (.db)                           │ │   │
│  │  │                                                            │ │   │
│  │  │  • Consistent point-in-time snapshot                      │ │   │
│  │  │  • Contains all key-value pairs                           │ │   │
│  │  │  • Includes revision information                          │ │   │
│  │  │  • Hash for integrity verification                        │ │   │
│  │  └───────────────────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                              │                                          │
│                              │ Upload                                   │
│                              ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Backup Storage Destinations                   │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │   │
│  │  │  Local Disk │  │  S3/OSS     │  │  NFS Mount  │             │   │
│  │  │             │  │             │  │             │             │   │
│  │  │ /backup/    │  │ s3://bucket │  │ /nfs/backup │             │   │
│  │  │ etcd/       │  │ /etcd/      │  │ /etcd/      │             │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘             │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Recovery Options                              │   │
│  │                                                                  │   │
│  │  Option 1: In-place restore (same cluster)                      │   │
│  │  ┌─────────────────────────────────────────────────────────┐   │   │
│  │  │ 1. Stop all etcd members                                 │   │   │
│  │  │ 2. etcdctl snapshot restore on each node                │   │   │
│  │  │ 3. Update data-dir in etcd configuration                │   │   │
│  │  │ 4. Start etcd members one by one                        │   │   │
│  │  └─────────────────────────────────────────────────────────┘   │   │
│  │                                                                  │   │
│  │  Option 2: New cluster restore                                  │   │
│  │  ┌─────────────────────────────────────────────────────────┐   │   │
│  │  │ 1. Provision new etcd nodes                             │   │   │
│  │  │ 2. etcdctl snapshot restore with new cluster config     │   │   │
│  │  │ 3. Start new etcd cluster                               │   │   │
│  │  │ 4. Update API server etcd endpoints                     │   │   │
│  │  └─────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### etcd 备份脚本 (生产级)

```bash
#!/bin/bash
# etcd-backup.sh - Production etcd backup script
# Supports: etcd v3.4+, Kubernetes v1.25+

set -euo pipefail

# ============== Configuration ==============
BACKUP_DIR="${BACKUP_DIR:-/backup/etcd}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
ETCD_ENDPOINTS="${ETCD_ENDPOINTS:-https://127.0.0.1:2379}"
ETCD_CACERT="${ETCD_CACERT:-/etc/kubernetes/pki/etcd/ca.crt}"
ETCD_CERT="${ETCD_CERT:-/etc/kubernetes/pki/etcd/server.crt}"
ETCD_KEY="${ETCD_KEY:-/etc/kubernetes/pki/etcd/server.key}"

# S3 Upload Configuration (optional)
S3_BUCKET="${S3_BUCKET:-}"
S3_PREFIX="${S3_PREFIX:-etcd-backups}"

# Notification Configuration
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
PAGERDUTY_KEY="${PAGERDUTY_KEY:-}"

# ============== Functions ==============
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    log "ERROR: $1" >&2
    send_alert "etcd Backup Failed" "$1"
    exit 1
}

send_alert() {
    local title="$1"
    local message="$2"
    
    # Slack notification
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        curl -s -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"text\": \"*${title}*\n${message}\"}" || true
    fi
    
    # PagerDuty notification
    if [[ -n "$PAGERDUTY_KEY" ]]; then
        curl -s -X POST "https://events.pagerduty.com/v2/enqueue" \
            -H 'Content-Type: application/json' \
            -d "{
                \"routing_key\": \"${PAGERDUTY_KEY}\",
                \"event_action\": \"trigger\",
                \"payload\": {
                    \"summary\": \"${title}: ${message}\",
                    \"source\": \"etcd-backup\",
                    \"severity\": \"critical\"
                }
            }" || true
    fi
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check etcdctl
    if ! command -v etcdctl &> /dev/null; then
        error "etcdctl not found in PATH"
    fi
    
    # Check etcd connectivity
    if ! ETCDCTL_API=3 etcdctl \
        --endpoints="$ETCD_ENDPOINTS" \
        --cacert="$ETCD_CACERT" \
        --cert="$ETCD_CERT" \
        --key="$ETCD_KEY" \
        endpoint health &>/dev/null; then
        error "Cannot connect to etcd cluster"
    fi
    
    # Check backup directory
    mkdir -p "$BACKUP_DIR"
    
    log "Prerequisites check passed"
}

get_etcd_status() {
    log "Getting etcd cluster status..."
    
    ETCDCTL_API=3 etcdctl \
        --endpoints="$ETCD_ENDPOINTS" \
        --cacert="$ETCD_CACERT" \
        --cert="$ETCD_CERT" \
        --key="$ETCD_KEY" \
        endpoint status --write-out=table
    
    ETCDCTL_API=3 etcdctl \
        --endpoints="$ETCD_ENDPOINTS" \
        --cacert="$ETCD_CACERT" \
        --cert="$ETCD_CERT" \
        --key="$ETCD_KEY" \
        member list --write-out=table
}

create_snapshot() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local hostname=$(hostname -s)
    local snapshot_file="${BACKUP_DIR}/etcd-snapshot-${hostname}-${timestamp}.db"
    
    log "Creating etcd snapshot: $snapshot_file"
    
    ETCDCTL_API=3 etcdctl \
        --endpoints="$ETCD_ENDPOINTS" \
        --cacert="$ETCD_CACERT" \
        --cert="$ETCD_CERT" \
        --key="$ETCD_KEY" \
        snapshot save "$snapshot_file"
    
    # Verify snapshot
    log "Verifying snapshot..."
    ETCDCTL_API=3 etcdctl snapshot status "$snapshot_file" --write-out=table
    
    # Calculate checksum
    local checksum=$(sha256sum "$snapshot_file" | awk '{print $1}')
    echo "$checksum  $(basename $snapshot_file)" > "${snapshot_file}.sha256"
    
    log "Snapshot created successfully: $snapshot_file (SHA256: $checksum)"
    
    echo "$snapshot_file"
}

compress_snapshot() {
    local snapshot_file="$1"
    local compressed_file="${snapshot_file}.gz"
    
    log "Compressing snapshot..."
    gzip -c "$snapshot_file" > "$compressed_file"
    
    local original_size=$(stat -c%s "$snapshot_file" 2>/dev/null || stat -f%z "$snapshot_file")
    local compressed_size=$(stat -c%s "$compressed_file" 2>/dev/null || stat -f%z "$compressed_file")
    local ratio=$(echo "scale=2; $compressed_size * 100 / $original_size" | bc)
    
    log "Compression complete: ${original_size} -> ${compressed_size} bytes (${ratio}%)"
    
    # Remove original after compression
    rm -f "$snapshot_file"
    
    echo "$compressed_file"
}

upload_to_s3() {
    local file="$1"
    
    if [[ -z "$S3_BUCKET" ]]; then
        log "S3 upload skipped (S3_BUCKET not configured)"
        return 0
    fi
    
    local s3_path="s3://${S3_BUCKET}/${S3_PREFIX}/$(basename $file)"
    
    log "Uploading to S3: $s3_path"
    
    if command -v aws &> /dev/null; then
        aws s3 cp "$file" "$s3_path" --storage-class STANDARD_IA
        aws s3 cp "${file%.gz}.db.sha256" "${s3_path%.gz}.db.sha256"
        log "S3 upload completed"
    else
        log "WARNING: aws CLI not found, skipping S3 upload"
    fi
}

cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    
    # Local cleanup
    find "$BACKUP_DIR" -name "etcd-snapshot-*.db*" -type f -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
    find "$BACKUP_DIR" -name "*.sha256" -type f -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
    
    # S3 cleanup (if configured)
    if [[ -n "$S3_BUCKET" ]] && command -v aws &> /dev/null; then
        local cutoff_date=$(date -d "-${RETENTION_DAYS} days" +%Y-%m-%d 2>/dev/null || \
                           date -v-${RETENTION_DAYS}d +%Y-%m-%d)
        
        aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/" | \
            awk -v cutoff="$cutoff_date" '$1 < cutoff {print $4}' | \
            while read -r file; do
                aws s3 rm "s3://${S3_BUCKET}/${S3_PREFIX}/${file}"
                log "Deleted old S3 backup: $file"
            done
    fi
    
    log "Cleanup completed"
}

generate_report() {
    local snapshot_file="$1"
    
    log "=== Backup Report ==="
    log "Backup File: $snapshot_file"
    log "File Size: $(ls -lh "$snapshot_file" | awk '{print $5}')"
    log "Backup Time: $(date)"
    
    # List recent backups
    log "Recent backups:"
    ls -lht "$BACKUP_DIR"/etcd-snapshot-*.gz 2>/dev/null | head -10 || true
    
    # etcd cluster health
    log "etcd cluster health:"
    ETCDCTL_API=3 etcdctl \
        --endpoints="$ETCD_ENDPOINTS" \
        --cacert="$ETCD_CACERT" \
        --cert="$ETCD_CERT" \
        --key="$ETCD_KEY" \
        endpoint health 2>&1 || true
}

# ============== Main Execution ==============
main() {
    log "Starting etcd backup process..."
    
    check_prerequisites
    get_etcd_status
    
    local snapshot_file=$(create_snapshot)
    local compressed_file=$(compress_snapshot "$snapshot_file")
    
    upload_to_s3 "$compressed_file"
    cleanup_old_backups
    generate_report "$compressed_file"
    
    log "etcd backup completed successfully!"
    send_alert "etcd Backup Success" "Backup completed: $(basename $compressed_file)"
}

main "$@"
```

### etcd 恢复脚本 (生产级)

```bash
#!/bin/bash
# etcd-restore.sh - Production etcd restore script
# WARNING: This will replace all etcd data!

set -euo pipefail

# ============== Configuration ==============
SNAPSHOT_FILE="${1:-}"
ETCD_DATA_DIR="${ETCD_DATA_DIR:-/var/lib/etcd}"
ETCD_NAME="${ETCD_NAME:-$(hostname -s)}"
ETCD_INITIAL_CLUSTER="${ETCD_INITIAL_CLUSTER:-}"
ETCD_INITIAL_CLUSTER_TOKEN="${ETCD_INITIAL_CLUSTER_TOKEN:-etcd-cluster}"
ETCD_INITIAL_ADVERTISE_PEER_URLS="${ETCD_INITIAL_ADVERTISE_PEER_URLS:-https://$(hostname -f):2380}"

# ============== Functions ==============
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    log "ERROR: $1" >&2
    exit 1
}

usage() {
    cat << EOF
Usage: $0 <snapshot-file> [options]

Options:
  ETCD_DATA_DIR                  etcd data directory (default: /var/lib/etcd)
  ETCD_NAME                      etcd member name (default: hostname)
  ETCD_INITIAL_CLUSTER           Initial cluster configuration
  ETCD_INITIAL_CLUSTER_TOKEN     Cluster token (default: etcd-cluster)

Example:
  $0 /backup/etcd/etcd-snapshot-20240115_120000.db.gz

  ETCD_INITIAL_CLUSTER="etcd-0=https://etcd-0:2380,etcd-1=https://etcd-1:2380" \\
  $0 /backup/etcd/etcd-snapshot.db.gz
EOF
    exit 1
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    if [[ -z "$SNAPSHOT_FILE" ]]; then
        usage
    fi
    
    if [[ ! -f "$SNAPSHOT_FILE" ]]; then
        error "Snapshot file not found: $SNAPSHOT_FILE"
    fi
    
    if ! command -v etcdctl &> /dev/null; then
        error "etcdctl not found in PATH"
    fi
    
    log "Prerequisites check passed"
}

verify_snapshot() {
    local snapshot="$1"
    
    log "Verifying snapshot integrity..."
    
    # Decompress if needed
    if [[ "$snapshot" == *.gz ]]; then
        local uncompressed="${snapshot%.gz}"
        log "Decompressing snapshot..."
        gunzip -c "$snapshot" > "$uncompressed"
        snapshot="$uncompressed"
    fi
    
    # Verify snapshot
    ETCDCTL_API=3 etcdctl snapshot status "$snapshot" --write-out=table
    
    # Check SHA256 if available
    if [[ -f "${snapshot}.sha256" ]]; then
        log "Verifying SHA256 checksum..."
        if sha256sum -c "${snapshot}.sha256" &>/dev/null; then
            log "Checksum verification passed"
        else
            error "Checksum verification failed!"
        fi
    fi
    
    echo "$snapshot"
}

stop_etcd() {
    log "Stopping etcd service..."
    
    # For systemd-based etcd
    if systemctl is-active etcd &>/dev/null; then
        systemctl stop etcd
        log "etcd service stopped"
    fi
    
    # For kubeadm-based etcd (static pod)
    if [[ -f /etc/kubernetes/manifests/etcd.yaml ]]; then
        mv /etc/kubernetes/manifests/etcd.yaml /etc/kubernetes/manifests/etcd.yaml.bak
        log "etcd static pod manifest moved"
        sleep 10  # Wait for kubelet to stop the pod
    fi
    
    # Verify etcd is stopped
    if pgrep -x etcd &>/dev/null; then
        log "WARNING: etcd still running, attempting to kill..."
        pkill -9 etcd || true
        sleep 5
    fi
}

backup_current_data() {
    log "Backing up current etcd data..."
    
    if [[ -d "$ETCD_DATA_DIR" ]]; then
        local backup_name="${ETCD_DATA_DIR}.pre-restore.$(date +%Y%m%d_%H%M%S)"
        mv "$ETCD_DATA_DIR" "$backup_name"
        log "Current data backed up to: $backup_name"
    fi
}

restore_snapshot() {
    local snapshot="$1"
    local restore_dir="${ETCD_DATA_DIR}.restore"
    
    log "Restoring etcd snapshot..."
    
    # Build restore command
    local restore_cmd="ETCDCTL_API=3 etcdctl snapshot restore $snapshot"
    restore_cmd+=" --name=$ETCD_NAME"
    restore_cmd+=" --data-dir=$restore_dir"
    restore_cmd+=" --initial-cluster-token=$ETCD_INITIAL_CLUSTER_TOKEN"
    restore_cmd+=" --initial-advertise-peer-urls=$ETCD_INITIAL_ADVERTISE_PEER_URLS"
    
    if [[ -n "$ETCD_INITIAL_CLUSTER" ]]; then
        restore_cmd+=" --initial-cluster=$ETCD_INITIAL_CLUSTER"
    else
        restore_cmd+=" --initial-cluster=${ETCD_NAME}=${ETCD_INITIAL_ADVERTISE_PEER_URLS}"
    fi
    
    log "Executing: $restore_cmd"
    eval "$restore_cmd"
    
    # Move restored data to final location
    mv "$restore_dir" "$ETCD_DATA_DIR"
    
    log "Snapshot restored to: $ETCD_DATA_DIR"
}

start_etcd() {
    log "Starting etcd service..."
    
    # For kubeadm-based etcd (static pod)
    if [[ -f /etc/kubernetes/manifests/etcd.yaml.bak ]]; then
        mv /etc/kubernetes/manifests/etcd.yaml.bak /etc/kubernetes/manifests/etcd.yaml
        log "etcd static pod manifest restored"
    fi
    
    # For systemd-based etcd
    if systemctl list-unit-files etcd.service &>/dev/null; then
        systemctl start etcd
        log "etcd service started"
    fi
    
    # Wait for etcd to become healthy
    log "Waiting for etcd to become healthy..."
    local retries=30
    while [[ $retries -gt 0 ]]; do
        if ETCDCTL_API=3 etcdctl endpoint health &>/dev/null; then
            log "etcd is healthy!"
            return 0
        fi
        sleep 2
        ((retries--))
    done
    
    error "etcd failed to become healthy after restore"
}

verify_restore() {
    log "Verifying restore..."
    
    ETCDCTL_API=3 etcdctl endpoint status --write-out=table
    ETCDCTL_API=3 etcdctl member list --write-out=table
    
    # Check key count
    local key_count=$(ETCDCTL_API=3 etcdctl get "" --prefix --keys-only 2>/dev/null | wc -l)
    log "Total keys in etcd: $key_count"
    
    log "Restore verification completed"
}

# ============== Main Execution ==============
main() {
    log "=== etcd Restore Process ==="
    log "WARNING: This will replace all etcd data!"
    
    check_prerequisites
    
    read -p "Are you sure you want to proceed? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log "Restore cancelled"
        exit 0
    fi
    
    local snapshot=$(verify_snapshot "$SNAPSHOT_FILE")
    stop_etcd
    backup_current_data
    restore_snapshot "$snapshot"
    start_etcd
    verify_restore
    
    log "=== etcd Restore Completed Successfully ==="
}

main "$@"
```

### etcd 定时备份 CronJob

```yaml
# etcd-backup-cronjob.yaml
# Kubernetes CronJob for automated etcd backups
apiVersion: batch/v1
kind: CronJob
metadata:
  name: etcd-backup
  namespace: kube-system
  labels:
    app: etcd-backup
    component: backup
spec:
  # Run every 6 hours
  schedule: "0 */6 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      activeDeadlineSeconds: 1800  # 30 minutes timeout
      backoffLimit: 3
      template:
        metadata:
          labels:
            app: etcd-backup
        spec:
          hostNetwork: true
          nodeSelector:
            node-role.kubernetes.io/control-plane: ""
          tolerations:
            - key: node-role.kubernetes.io/control-plane
              effect: NoSchedule
            - key: node-role.kubernetes.io/master
              effect: NoSchedule
          restartPolicy: OnFailure
          serviceAccountName: etcd-backup
          containers:
            - name: etcd-backup
              image: registry.k8s.io/etcd:3.5.12-0
              imagePullPolicy: IfNotPresent
              command:
                - /bin/sh
                - -c
                - |
                  set -ex
                  
                  BACKUP_DIR=/backup/etcd
                  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
                  SNAPSHOT_FILE="${BACKUP_DIR}/etcd-snapshot-${TIMESTAMP}.db"
                  
                  # Create backup directory
                  mkdir -p ${BACKUP_DIR}
                  
                  # Create snapshot
                  etcdctl snapshot save ${SNAPSHOT_FILE} \
                    --endpoints=https://127.0.0.1:2379 \
                    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
                    --cert=/etc/kubernetes/pki/etcd/server.crt \
                    --key=/etc/kubernetes/pki/etcd/server.key
                  
                  # Verify snapshot
                  etcdctl snapshot status ${SNAPSHOT_FILE} --write-out=table
                  
                  # Compress snapshot
                  gzip ${SNAPSHOT_FILE}
                  
                  # Calculate checksum
                  sha256sum ${SNAPSHOT_FILE}.gz > ${SNAPSHOT_FILE}.gz.sha256
                  
                  # Upload to S3 (if configured)
                  if [ -n "${S3_BUCKET:-}" ]; then
                    aws s3 cp ${SNAPSHOT_FILE}.gz s3://${S3_BUCKET}/etcd-backups/
                    aws s3 cp ${SNAPSHOT_FILE}.gz.sha256 s3://${S3_BUCKET}/etcd-backups/
                  fi
                  
                  # Cleanup old backups (keep last 7 days)
                  find ${BACKUP_DIR} -name "etcd-snapshot-*.gz*" -mtime +7 -delete
                  
                  echo "Backup completed: ${SNAPSHOT_FILE}.gz"
              env:
                - name: ETCDCTL_API
                  value: "3"
                - name: S3_BUCKET
                  valueFrom:
                    secretKeyRef:
                      name: etcd-backup-s3
                      key: bucket
                      optional: true
                - name: AWS_ACCESS_KEY_ID
                  valueFrom:
                    secretKeyRef:
                      name: etcd-backup-s3
                      key: access-key
                      optional: true
                - name: AWS_SECRET_ACCESS_KEY
                  valueFrom:
                    secretKeyRef:
                      name: etcd-backup-s3
                      key: secret-key
                      optional: true
                - name: AWS_DEFAULT_REGION
                  valueFrom:
                    secretKeyRef:
                      name: etcd-backup-s3
                      key: region
                      optional: true
              volumeMounts:
                - name: etcd-certs
                  mountPath: /etc/kubernetes/pki/etcd
                  readOnly: true
                - name: backup-storage
                  mountPath: /backup
              resources:
                requests:
                  cpu: 100m
                  memory: 256Mi
                limits:
                  cpu: 500m
                  memory: 512Mi
          volumes:
            - name: etcd-certs
              hostPath:
                path: /etc/kubernetes/pki/etcd
                type: DirectoryOrCreate
            - name: backup-storage
              persistentVolumeClaim:
                claimName: etcd-backup-pvc
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: etcd-backup
  namespace: kube-system
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: etcd-backup-pvc
  namespace: kube-system
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard
  resources:
    requests:
      storage: 50Gi
```

---

## Velero 备份概述

### Velero 架构图

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           Velero Backup Architecture                                │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                          Velero Server                                       │   │
│  │  ┌─────────────────────────────────────────────────────────────────────┐   │   │
│  │  │                     velero-deployment                                │   │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │   │   │
│  │  │  │  Backup     │  │  Restore    │  │  Schedule   │                 │   │   │
│  │  │  │  Controller │  │  Controller │  │  Controller │                 │   │   │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘                 │   │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │   │   │
│  │  │  │  GC         │  │  Restic     │  │  CSI        │                 │   │   │
│  │  │  │  Controller │  │  Repository │  │  Snapshotter│                 │   │   │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘                 │   │   │
│  │  └─────────────────────────────────────────────────────────────────────┘   │   │
│  │                                    │                                        │   │
│  │                                    │ CRD Reconciliation                    │   │
│  │                                    ▼                                        │   │
│  │  ┌─────────────────────────────────────────────────────────────────────┐   │   │
│  │  │                   Custom Resource Definitions                        │   │   │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │   │   │
│  │  │  │ Backup   │ │ Restore  │ │ Schedule │ │ BSL      │ │ VSL      │  │   │   │
│  │  │  │          │ │          │ │          │ │ (Backup  │ │ (Volume  │  │   │   │
│  │  │  │          │ │          │ │          │ │ Storage  │ │ Snapshot │  │   │   │
│  │  │  │          │ │          │ │          │ │ Location)│ │ Location)│  │   │   │
│  │  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘  │   │   │
│  │  └─────────────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                    │                                                │
│                 ┌──────────────────┼──────────────────┐                            │
│                 │                  │                  │                            │
│                 ▼                  ▼                  ▼                            │
│  ┌─────────────────────┐ ┌─────────────────┐ ┌─────────────────────┐              │
│  │   Object Storage    │ │  Volume Snapshot │ │   Restic/Kopia     │              │
│  │   Plugin            │ │  Plugin          │ │   Repository       │              │
│  │                     │ │                  │ │                    │              │
│  │  AWS S3             │ │  AWS EBS CSI     │ │  S3/Azure/GCS      │              │
│  │  Azure Blob         │ │  Azure Disk CSI  │ │  backup repository │              │
│  │  GCS                │ │  GCE PD CSI      │ │                    │              │
│  │  Alibaba OSS        │ │  Alibaba CSI     │ │  File-level backup │              │
│  │  MinIO              │ │  Longhorn        │ │  for non-CSI PVs   │              │
│  └─────────────────────┘ └─────────────────┘ └─────────────────────┘              │
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                          Node Agent DaemonSet                                │   │
│  │  ┌─────────────────────────────────────────────────────────────────────┐   │   │
│  │  │  node-agent (runs on each node)                                      │   │   │
│  │  │                                                                      │   │   │
│  │  │  • Restic/Kopia backup agent                                        │   │   │
│  │  │  • File-level backup for PVs                                        │   │   │
│  │  │  • Mounts PVs and performs backup                                   │   │   │
│  │  │  • Supports encryption and deduplication                            │   │   │
│  │  └─────────────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Velero 安装配置

```yaml
# velero-installation.yaml
# Velero installation with AWS S3 backend
---
# Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: velero
  labels:
    app.kubernetes.io/name: velero
---
# S3 credentials secret
apiVersion: v1
kind: Secret
metadata:
  name: cloud-credentials
  namespace: velero
type: Opaque
stringData:
  cloud: |
    [default]
    aws_access_key_id=<AWS_ACCESS_KEY_ID>
    aws_secret_access_key=<AWS_SECRET_ACCESS_KEY>
---
# BackupStorageLocation for S3
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: default
  namespace: velero
spec:
  provider: aws
  objectStorage:
    bucket: my-velero-bucket
    prefix: backups
  credential:
    name: cloud-credentials
    key: cloud
  config:
    region: us-west-2
    s3ForcePathStyle: "false"
    s3Url: ""  # Leave empty for AWS S3, set for MinIO/compatible
  default: true
  accessMode: ReadWrite
  backupSyncPeriod: 1m
---
# VolumeSnapshotLocation for EBS
apiVersion: velero.io/v1
kind: VolumeSnapshotLocation
metadata:
  name: default
  namespace: velero
spec:
  provider: aws
  credential:
    name: cloud-credentials
    key: cloud
  config:
    region: us-west-2
```

### Velero Helm 安装

```bash
#!/bin/bash
# velero-helm-install.sh

# Add Velero Helm repository
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update

# Create namespace and credentials
kubectl create namespace velero

# Create credentials secret
cat > credentials-velero <<EOF
[default]
aws_access_key_id=${AWS_ACCESS_KEY_ID}
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
EOF

kubectl create secret generic cloud-credentials \
  --namespace velero \
  --from-file=cloud=credentials-velero

rm credentials-velero

# Install Velero with Helm
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --set-file credentials.secretContents.cloud=<(cat <<EOF
[default]
aws_access_key_id=${AWS_ACCESS_KEY_ID}
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
EOF
) \
  --set configuration.backupStorageLocation[0].name=default \
  --set configuration.backupStorageLocation[0].provider=aws \
  --set configuration.backupStorageLocation[0].bucket=${VELERO_BUCKET} \
  --set configuration.backupStorageLocation[0].config.region=${AWS_REGION} \
  --set configuration.volumeSnapshotLocation[0].name=default \
  --set configuration.volumeSnapshotLocation[0].provider=aws \
  --set configuration.volumeSnapshotLocation[0].config.region=${AWS_REGION} \
  --set initContainers[0].name=velero-plugin-for-aws \
  --set initContainers[0].image=velero/velero-plugin-for-aws:v1.9.0 \
  --set initContainers[0].volumeMounts[0].mountPath=/target \
  --set initContainers[0].volumeMounts[0].name=plugins \
  --set deployNodeAgent=true \
  --set nodeAgent.resources.requests.cpu=100m \
  --set nodeAgent.resources.requests.memory=256Mi \
  --set nodeAgent.resources.limits.cpu=1 \
  --set nodeAgent.resources.limits.memory=1Gi \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=128Mi \
  --set resources.limits.cpu=1 \
  --set resources.limits.memory=512Mi

# Verify installation
kubectl get pods -n velero
velero backup-location get
```

---

## CSI 快照备份

### CSI 快照架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          CSI Volume Snapshot Architecture                           │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                        Kubernetes API Server                                 │   │
│  │  ┌─────────────────────────────────────────────────────────────────────┐   │   │
│  │  │               Snapshot CRDs (snapshot.storage.k8s.io)                │   │   │
│  │  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │   │   │
│  │  │  │ VolumeSnapshot   │  │VolumeSnapshotClass│  │VolumeSnapshotCont│  │   │   │
│  │  │  │                  │  │                   │  │ ent              │  │   │   │
│  │  │  │ User-facing      │  │ Snapshot class    │  │ Actual snapshot  │  │   │   │
│  │  │  │ resource         │  │ parameters        │  │ binding          │  │   │   │
│  │  │  └──────────────────┘  └──────────────────┘  └──────────────────┘  │   │   │
│  │  └─────────────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                            │
│                                        ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                      Snapshot Controller (cluster-wide)                      │   │
│  │                                                                              │   │
│  │  • Watches VolumeSnapshot resources                                         │   │
│  │  • Creates/deletes VolumeSnapshotContent                                   │   │
│  │  • Manages snapshot lifecycle                                               │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                            │
│                                        ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                         CSI Driver Sidecar                                   │   │
│  │  ┌─────────────────────────────────────────────────────────────────────┐   │   │
│  │  │                   csi-snapshotter sidecar                            │   │   │
│  │  │                                                                      │   │   │
│  │  │  • Communicates with CSI driver                                     │   │   │
│  │  │  • Translates K8s resources to CSI calls                           │   │   │
│  │  │  • CreateSnapshot / DeleteSnapshot / ListSnapshots                  │   │   │
│  │  └─────────────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                            │
│                                        │ CSI gRPC                                   │
│                                        ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                          CSI Driver                                          │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │   │
│  │  │ AWS EBS CSI │  │ Azure Disk  │  │ GCE PD CSI  │  │Alibaba Disk │       │   │
│  │  │             │  │ CSI         │  │             │  │ CSI         │       │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                            │
│                                        │ Cloud API                                  │
│                                        ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                        Cloud Provider Storage                                │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │   │
│  │  │  AWS EBS    │  │  Azure Disk │  │  GCE PD     │  │Alibaba Cloud│       │   │
│  │  │  Snapshot   │  │  Snapshot   │  │  Snapshot   │  │ Disk Snap   │       │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### CSI 快照配置

```yaml
# csi-snapshot-class.yaml
# VolumeSnapshotClass for different cloud providers
---
# AWS EBS VolumeSnapshotClass
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ebs-snapshot-class
  labels:
    velero.io/csi-volumesnapshot-class: "true"
driver: ebs.csi.aws.com
deletionPolicy: Retain
parameters:
  # Optional: Add tags to snapshots
  # tagSpecification_1: "key=Environment,value=Production"
  # tagSpecification_2: "key=Backup,value=Automated"
---
# Azure Disk VolumeSnapshotClass
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: azure-disk-snapshot-class
  labels:
    velero.io/csi-volumesnapshot-class: "true"
driver: disk.csi.azure.com
deletionPolicy: Retain
parameters:
  incremental: "true"  # Use incremental snapshots
---
# GCE PD VolumeSnapshotClass
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: gce-pd-snapshot-class
  labels:
    velero.io/csi-volumesnapshot-class: "true"
driver: pd.csi.storage.gke.io
deletionPolicy: Retain
parameters:
  snapshot-type: STANDARD  # or ARCHIVE for cost savings
---
# Alibaba Cloud Disk VolumeSnapshotClass
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: alicloud-disk-snapshot-class
  labels:
    velero.io/csi-volumesnapshot-class: "true"
driver: diskplugin.csi.alibabacloud.com
deletionPolicy: Retain
parameters:
  forceDelete: "false"
```

### CSI 快照使用示例

```yaml
# csi-snapshot-example.yaml
---
# Create a VolumeSnapshot
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: mysql-data-snapshot
  namespace: production
  labels:
    app: mysql
    backup-type: scheduled
spec:
  volumeSnapshotClassName: ebs-snapshot-class
  source:
    persistentVolumeClaimName: mysql-data-pvc
---
# Create PVC from snapshot (restore)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-data-restored
  namespace: production
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 100Gi
  dataSource:
    name: mysql-data-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

---

## 应用级备份

### 数据库备份 CronJob

```yaml
# database-backup-cronjob.yaml
# MySQL backup with S3 upload
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mysql-backup
  namespace: production
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      activeDeadlineSeconds: 3600
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: mysql-backup
              image: mysql:8.0
              command:
                - /bin/bash
                - -c
                - |
                  set -ex
                  
                  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
                  BACKUP_FILE="/backup/mysql-${MYSQL_DATABASE}-${TIMESTAMP}.sql.gz"
                  
                  # Create backup
                  mysqldump \
                    --host=${MYSQL_HOST} \
                    --port=${MYSQL_PORT} \
                    --user=${MYSQL_USER} \
                    --password=${MYSQL_PASSWORD} \
                    --single-transaction \
                    --routines \
                    --triggers \
                    --events \
                    --set-gtid-purged=OFF \
                    ${MYSQL_DATABASE} | gzip > ${BACKUP_FILE}
                  
                  # Verify backup
                  gunzip -t ${BACKUP_FILE}
                  
                  # Upload to S3
                  aws s3 cp ${BACKUP_FILE} s3://${S3_BUCKET}/mysql-backups/
                  
                  # Cleanup old local backups
                  find /backup -name "mysql-*.sql.gz" -mtime +3 -delete
                  
                  echo "Backup completed: ${BACKUP_FILE}"
              env:
                - name: MYSQL_HOST
                  value: "mysql-primary.production.svc"
                - name: MYSQL_PORT
                  value: "3306"
                - name: MYSQL_DATABASE
                  value: "production"
                - name: MYSQL_USER
                  valueFrom:
                    secretKeyRef:
                      name: mysql-credentials
                      key: username
                - name: MYSQL_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: mysql-credentials
                      key: password
                - name: S3_BUCKET
                  valueFrom:
                    secretKeyRef:
                      name: backup-s3-credentials
                      key: bucket
                - name: AWS_ACCESS_KEY_ID
                  valueFrom:
                    secretKeyRef:
                      name: backup-s3-credentials
                      key: access-key
                - name: AWS_SECRET_ACCESS_KEY
                  valueFrom:
                    secretKeyRef:
                      name: backup-s3-credentials
                      key: secret-key
                - name: AWS_DEFAULT_REGION
                  valueFrom:
                    secretKeyRef:
                      name: backup-s3-credentials
                      key: region
              volumeMounts:
                - name: backup-storage
                  mountPath: /backup
              resources:
                requests:
                  cpu: 100m
                  memory: 256Mi
                limits:
                  cpu: 1
                  memory: 1Gi
          volumes:
            - name: backup-storage
              emptyDir:
                sizeLimit: 10Gi
---
# PostgreSQL backup CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgresql-backup
  namespace: production
spec:
  schedule: "0 2 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      activeDeadlineSeconds: 3600
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: pg-backup
              image: postgres:16
              command:
                - /bin/bash
                - -c
                - |
                  set -ex
                  
                  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
                  BACKUP_FILE="/backup/postgresql-${PGDATABASE}-${TIMESTAMP}.sql.gz"
                  
                  # Create backup with pg_dump
                  pg_dump \
                    --format=custom \
                    --compress=9 \
                    --verbose \
                    --file=${BACKUP_FILE} \
                    ${PGDATABASE}
                  
                  # Verify backup
                  pg_restore --list ${BACKUP_FILE} > /dev/null
                  
                  # Upload to S3
                  aws s3 cp ${BACKUP_FILE} s3://${S3_BUCKET}/postgresql-backups/
                  
                  echo "Backup completed: ${BACKUP_FILE}"
              env:
                - name: PGHOST
                  value: "postgresql-primary.production.svc"
                - name: PGPORT
                  value: "5432"
                - name: PGDATABASE
                  value: "production"
                - name: PGUSER
                  valueFrom:
                    secretKeyRef:
                      name: postgresql-credentials
                      key: username
                - name: PGPASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: postgresql-credentials
                      key: password
                - name: S3_BUCKET
                  valueFrom:
                    secretKeyRef:
                      name: backup-s3-credentials
                      key: bucket
                - name: AWS_ACCESS_KEY_ID
                  valueFrom:
                    secretKeyRef:
                      name: backup-s3-credentials
                      key: access-key
                - name: AWS_SECRET_ACCESS_KEY
                  valueFrom:
                    secretKeyRef:
                      name: backup-s3-credentials
                      key: secret-key
              volumeMounts:
                - name: backup-storage
                  mountPath: /backup
              resources:
                requests:
                  cpu: 100m
                  memory: 256Mi
                limits:
                  cpu: 1
                  memory: 1Gi
          volumes:
            - name: backup-storage
              emptyDir:
                sizeLimit: 10Gi
```

---

## 备份监控与告警

### Prometheus 监控规则

```yaml
# backup-monitoring-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: backup-monitoring
  namespace: monitoring
  labels:
    prometheus: k8s
    role: alert-rules
spec:
  groups:
    - name: backup.rules
      interval: 60s
      rules:
        # etcd backup metrics
        - record: etcd_backup_last_success_timestamp_seconds
          expr: |
            max by (cluster) (
              kube_cronjob_status_last_successful_time{cronjob="etcd-backup"}
            )
        
        - record: etcd_backup_age_hours
          expr: |
            (time() - etcd_backup_last_success_timestamp_seconds) / 3600
        
        # Velero backup metrics
        - record: velero_backup_success_total
          expr: |
            sum by (schedule) (
              velero_backup_success_total
            )
        
        - record: velero_backup_failure_total
          expr: |
            sum by (schedule) (
              velero_backup_failure_total
            )
        
        - record: velero_backup_duration_seconds_avg
          expr: |
            avg by (schedule) (
              velero_backup_duration_seconds
            )

    - name: backup.alerts
      rules:
        # etcd backup alerts
        - alert: EtcdBackupTooOld
          expr: etcd_backup_age_hours > 24
          for: 30m
          labels:
            severity: warning
          annotations:
            summary: "etcd backup is too old"
            description: "Last successful etcd backup was {{ $value | humanizeDuration }} ago"
        
        - alert: EtcdBackupCriticallyOld
          expr: etcd_backup_age_hours > 48
          for: 30m
          labels:
            severity: critical
          annotations:
            summary: "etcd backup is critically old"
            description: "Last successful etcd backup was {{ $value | humanizeDuration }} ago. Immediate action required!"
        
        - alert: EtcdBackupJobFailed
          expr: |
            kube_job_status_failed{job_name=~"etcd-backup.*"} > 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "etcd backup job failed"
            description: "etcd backup job {{ $labels.job_name }} has failed"
        
        # Velero backup alerts
        - alert: VeleroBackupFailed
          expr: |
            increase(velero_backup_failure_total[24h]) > 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Velero backup failed"
            description: "Velero backup schedule {{ $labels.schedule }} has failed"
        
        - alert: VeleroBackupPartiallyFailed
          expr: |
            velero_backup_partial_failure_total > 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Velero backup partially failed"
            description: "Velero backup has partial failures. Check backup logs."
        
        - alert: VeleroBackupMissing
          expr: |
            time() - velero_backup_last_successful_timestamp > 86400
          for: 30m
          labels:
            severity: warning
          annotations:
            summary: "No successful Velero backup in 24 hours"
            description: "Schedule {{ $labels.schedule }} has not completed successfully in 24 hours"
        
        - alert: VeleroBackupStorageLocationUnavailable
          expr: |
            velero_backup_storage_location_available == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Velero backup storage location unavailable"
            description: "Backup storage location {{ $labels.name }} is unavailable"
        
        - alert: VeleroRestoreFailed
          expr: |
            increase(velero_restore_failure_total[1h]) > 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Velero restore failed"
            description: "Velero restore operation has failed. Investigate immediately."
        
        # Database backup alerts
        - alert: DatabaseBackupJobFailed
          expr: |
            kube_job_status_failed{job_name=~".*-backup.*", namespace="production"} > 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Database backup job failed"
            description: "Database backup job {{ $labels.job_name }} in namespace {{ $labels.namespace }} has failed"
        
        - alert: DatabaseBackupMissing
          expr: |
            time() - kube_cronjob_status_last_successful_time{cronjob=~".*-backup"} > 86400
          for: 30m
          labels:
            severity: warning
          annotations:
            summary: "No successful database backup in 24 hours"
            description: "CronJob {{ $labels.cronjob }} has not completed successfully in 24 hours"
        
        # Backup storage alerts
        - alert: BackupStorageNearCapacity
          expr: |
            (
              sum by (persistentvolumeclaim) (kubelet_volume_stats_used_bytes{persistentvolumeclaim=~".*backup.*"})
              /
              sum by (persistentvolumeclaim) (kubelet_volume_stats_capacity_bytes{persistentvolumeclaim=~".*backup.*"})
            ) > 0.85
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "Backup storage is near capacity"
            description: "Backup PVC {{ $labels.persistentvolumeclaim }} is {{ $value | humanizePercentage }} full"
```

### Grafana Dashboard 配置

```json
{
  "dashboard": {
    "title": "Backup & Recovery Overview",
    "uid": "backup-overview",
    "tags": ["backup", "velero", "etcd"],
    "panels": [
      {
        "title": "etcd Backup Status",
        "type": "stat",
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "(time() - max(kube_cronjob_status_last_successful_time{cronjob=\"etcd-backup\"})) / 3600",
            "legendFormat": "Hours since last backup"
          }
        ],
        "options": {
          "colorMode": "value",
          "graphMode": "area"
        },
        "fieldConfig": {
          "defaults": {
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 12},
                {"color": "red", "value": 24}
              ]
            },
            "unit": "h"
          }
        }
      },
      {
        "title": "Velero Backup Success Rate (24h)",
        "type": "gauge",
        "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
        "targets": [
          {
            "expr": "sum(increase(velero_backup_success_total[24h])) / (sum(increase(velero_backup_success_total[24h])) + sum(increase(velero_backup_failure_total[24h]))) * 100",
            "legendFormat": "Success Rate"
          }
        ],
        "options": {
          "showThresholdLabels": false,
          "showThresholdMarkers": true
        },
        "fieldConfig": {
          "defaults": {
            "min": 0,
            "max": 100,
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 80},
                {"color": "green", "value": 95}
              ]
            },
            "unit": "percent"
          }
        }
      },
      {
        "title": "Backup Timeline",
        "type": "timeseries",
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 4},
        "targets": [
          {
            "expr": "increase(velero_backup_success_total[1h])",
            "legendFormat": "Velero Success"
          },
          {
            "expr": "increase(velero_backup_failure_total[1h])",
            "legendFormat": "Velero Failure"
          }
        ]
      },
      {
        "title": "Backup Duration by Schedule",
        "type": "barchart",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12},
        "targets": [
          {
            "expr": "avg by (schedule) (velero_backup_duration_seconds)",
            "legendFormat": "{{schedule}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "s"
          }
        }
      },
      {
        "title": "Backup Storage Location Status",
        "type": "table",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 12},
        "targets": [
          {
            "expr": "velero_backup_storage_location_available",
            "legendFormat": "{{name}}"
          }
        ],
        "transformations": [
          {
            "id": "organize",
            "options": {
              "renameByName": {
                "name": "Location",
                "Value": "Available"
              }
            }
          }
        ]
      }
    ]
  }
}
```

---

## 备份验证脚本

```bash
#!/bin/bash
# backup-verification.sh - Comprehensive backup verification script

set -euo pipefail

# Configuration
VELERO_NAMESPACE="${VELERO_NAMESPACE:-velero}"
ETCD_BACKUP_DIR="${ETCD_BACKUP_DIR:-/backup/etcd}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

success() {
    log "${GREEN}✓ $1${NC}"
}

warning() {
    log "${YELLOW}⚠ $1${NC}"
}

error() {
    log "${RED}✗ $1${NC}"
}

send_notification() {
    local title="$1"
    local message="$2"
    local status="$3"
    
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local color="good"
        [[ "$status" == "warning" ]] && color="warning"
        [[ "$status" == "error" ]] && color="danger"
        
        curl -s -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{
                \"attachments\": [{
                    \"color\": \"$color\",
                    \"title\": \"$title\",
                    \"text\": \"$message\",
                    \"ts\": $(date +%s)
                }]
            }" || true
    fi
}

# Verify etcd backups
verify_etcd_backups() {
    log "=== Verifying etcd Backups ==="
    local status="success"
    
    # Check if backup directory exists
    if [[ ! -d "$ETCD_BACKUP_DIR" ]]; then
        error "etcd backup directory not found: $ETCD_BACKUP_DIR"
        return 1
    fi
    
    # Find latest backup
    local latest_backup=$(ls -t "$ETCD_BACKUP_DIR"/etcd-snapshot-*.db* 2>/dev/null | head -1)
    
    if [[ -z "$latest_backup" ]]; then
        error "No etcd backups found"
        return 1
    fi
    
    # Check backup age
    local backup_age_hours=$(( ($(date +%s) - $(stat -c %Y "$latest_backup" 2>/dev/null || stat -f %m "$latest_backup")) / 3600 ))
    
    if [[ $backup_age_hours -gt 24 ]]; then
        error "Latest etcd backup is $backup_age_hours hours old (threshold: 24h)"
        status="error"
    elif [[ $backup_age_hours -gt 12 ]]; then
        warning "Latest etcd backup is $backup_age_hours hours old"
        status="warning"
    else
        success "Latest etcd backup: $(basename $latest_backup) ($backup_age_hours hours ago)"
    fi
    
    # Verify backup integrity
    log "Verifying backup integrity..."
    local snapshot_file="$latest_backup"
    
    # Decompress if needed
    if [[ "$snapshot_file" == *.gz ]]; then
        local temp_file=$(mktemp)
        gunzip -c "$snapshot_file" > "$temp_file"
        snapshot_file="$temp_file"
    fi
    
    if ETCDCTL_API=3 etcdctl snapshot status "$snapshot_file" &>/dev/null; then
        success "etcd backup integrity verified"
        ETCDCTL_API=3 etcdctl snapshot status "$snapshot_file" --write-out=table
    else
        error "etcd backup integrity check failed"
        status="error"
    fi
    
    # Cleanup temp file
    [[ -f "${temp_file:-}" ]] && rm -f "$temp_file"
    
    # Count backups
    local backup_count=$(ls "$ETCD_BACKUP_DIR"/etcd-snapshot-*.db* 2>/dev/null | wc -l)
    log "Total etcd backups available: $backup_count"
    
    echo "$status"
}

# Verify Velero backups
verify_velero_backups() {
    log "=== Verifying Velero Backups ==="
    local status="success"
    
    # Check Velero deployment
    if ! kubectl get deployment velero -n "$VELERO_NAMESPACE" &>/dev/null; then
        error "Velero deployment not found"
        return 1
    fi
    
    # Check Velero pod status
    local velero_pods=$(kubectl get pods -n "$VELERO_NAMESPACE" -l app.kubernetes.io/name=velero -o jsonpath='{.items[*].status.phase}')
    if [[ "$velero_pods" != *"Running"* ]]; then
        error "Velero pod is not running"
        status="error"
    else
        success "Velero pod is running"
    fi
    
    # Check backup storage locations
    log "Checking backup storage locations..."
    kubectl get backupstoragelocation -n "$VELERO_NAMESPACE" -o wide
    
    local unavailable_bsls=$(kubectl get backupstoragelocation -n "$VELERO_NAMESPACE" -o jsonpath='{.items[?(@.status.phase!="Available")].metadata.name}')
    if [[ -n "$unavailable_bsls" ]]; then
        error "Unavailable backup storage locations: $unavailable_bsls"
        status="error"
    else
        success "All backup storage locations available"
    fi
    
    # Check recent backups
    log "Checking recent backups..."
    local recent_backups=$(velero backup get --output json 2>/dev/null | jq -r '.items | sort_by(.status.completionTimestamp) | reverse | .[0:5]')
    
    echo "$recent_backups" | jq -r '.[] | "\(.metadata.name) - \(.status.phase) - \(.status.completionTimestamp)"' 2>/dev/null || true
    
    # Check for failed backups in last 24h
    local failed_count=$(velero backup get --output json 2>/dev/null | jq '[.items[] | select(.status.phase=="Failed")] | length')
    
    if [[ "$failed_count" -gt 0 ]]; then
        warning "$failed_count failed backup(s) found"
        status="warning"
    fi
    
    # Check schedules
    log "Checking backup schedules..."
    velero schedule get 2>/dev/null || true
    
    # Verify latest backup from each schedule
    local schedules=$(velero schedule get --output json 2>/dev/null | jq -r '.items[].metadata.name')
    
    for schedule in $schedules; do
        local last_backup=$(velero backup get --output json 2>/dev/null | \
            jq -r "[.items[] | select(.metadata.labels[\"velero.io/schedule-name\"]==\"$schedule\")] | sort_by(.status.completionTimestamp) | reverse | .[0]")
        
        if [[ "$last_backup" != "null" ]]; then
            local backup_name=$(echo "$last_backup" | jq -r '.metadata.name')
            local backup_phase=$(echo "$last_backup" | jq -r '.status.phase')
            local backup_time=$(echo "$last_backup" | jq -r '.status.completionTimestamp')
            
            if [[ "$backup_phase" == "Completed" ]]; then
                success "Schedule '$schedule': $backup_name ($backup_phase) - $backup_time"
            else
                warning "Schedule '$schedule': $backup_name ($backup_phase) - $backup_time"
                status="warning"
            fi
        else
            warning "No backups found for schedule: $schedule"
            status="warning"
        fi
    done
    
    echo "$status"
}

# Verify CSI snapshots
verify_csi_snapshots() {
    log "=== Verifying CSI Volume Snapshots ==="
    local status="success"
    
    # Check VolumeSnapshotClasses
    log "VolumeSnapshotClasses:"
    kubectl get volumesnapshotclasses 2>/dev/null || {
        warning "No VolumeSnapshotClasses found (CSI snapshots may not be configured)"
        echo "warning"
        return
    }
    
    # Check recent VolumeSnapshots
    log "Recent VolumeSnapshots:"
    kubectl get volumesnapshots --all-namespaces -o wide 2>/dev/null || true
    
    # Check for failed snapshots
    local failed_snapshots=$(kubectl get volumesnapshots --all-namespaces -o json 2>/dev/null | \
        jq -r '[.items[] | select(.status.readyToUse==false)] | length')
    
    if [[ "$failed_snapshots" -gt 0 ]]; then
        warning "$failed_snapshots volume snapshot(s) not ready"
        status="warning"
    else
        success "All volume snapshots are ready"
    fi
    
    echo "$status"
}

# Verify database backups
verify_database_backups() {
    log "=== Verifying Database Backup Jobs ==="
    local status="success"
    
    # Check for backup CronJobs
    local backup_cronjobs=$(kubectl get cronjobs --all-namespaces -o json 2>/dev/null | \
        jq -r '.items[] | select(.metadata.name | contains("backup"))')
    
    if [[ -z "$backup_cronjobs" ]]; then
        warning "No database backup CronJobs found"
        echo "warning"
        return
    fi
    
    # Check each backup CronJob
    kubectl get cronjobs --all-namespaces -o json 2>/dev/null | \
        jq -r '.items[] | select(.metadata.name | contains("backup")) | "\(.metadata.namespace)/\(.metadata.name)"' | \
    while read -r cronjob; do
        local namespace=$(echo "$cronjob" | cut -d'/' -f1)
        local name=$(echo "$cronjob" | cut -d'/' -f2)
        
        local last_success=$(kubectl get cronjob "$name" -n "$namespace" -o jsonpath='{.status.lastSuccessfulTime}' 2>/dev/null)
        local last_schedule=$(kubectl get cronjob "$name" -n "$namespace" -o jsonpath='{.status.lastScheduleTime}' 2>/dev/null)
        
        if [[ -n "$last_success" ]]; then
            local age_hours=$(( ($(date +%s) - $(date -d "$last_success" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$last_success" +%s)) / 3600 ))
            
            if [[ $age_hours -gt 48 ]]; then
                error "$cronjob: Last success $age_hours hours ago"
                status="error"
            elif [[ $age_hours -gt 24 ]]; then
                warning "$cronjob: Last success $age_hours hours ago"
                [[ "$status" != "error" ]] && status="warning"
            else
                success "$cronjob: Last success $age_hours hours ago"
            fi
        else
            warning "$cronjob: No successful backup recorded"
            [[ "$status" != "error" ]] && status="warning"
        fi
    done
    
    echo "$status"
}

# Generate report
generate_report() {
    local etcd_status="$1"
    local velero_status="$2"
    local csi_status="$3"
    local db_status="$4"
    
    log "=== Backup Verification Report ==="
    log "Timestamp: $(date)"
    log ""
    log "Status Summary:"
    log "  etcd Backups:     $etcd_status"
    log "  Velero Backups:   $velero_status"
    log "  CSI Snapshots:    $csi_status"
    log "  Database Backups: $db_status"
    log ""
    
    # Determine overall status
    local overall="success"
    [[ "$etcd_status" == "warning" || "$velero_status" == "warning" || "$csi_status" == "warning" || "$db_status" == "warning" ]] && overall="warning"
    [[ "$etcd_status" == "error" || "$velero_status" == "error" || "$csi_status" == "error" || "$db_status" == "error" ]] && overall="error"
    
    log "Overall Status: $overall"
    
    # Send notification
    send_notification "Backup Verification Report" \
        "etcd: $etcd_status | Velero: $velero_status | CSI: $csi_status | DB: $db_status" \
        "$overall"
}

# Main execution
main() {
    log "Starting backup verification..."
    
    local etcd_status=$(verify_etcd_backups 2>&1 | tee /dev/stderr | tail -1)
    local velero_status=$(verify_velero_backups 2>&1 | tee /dev/stderr | tail -1)
    local csi_status=$(verify_csi_snapshots 2>&1 | tee /dev/stderr | tail -1)
    local db_status=$(verify_database_backups 2>&1 | tee /dev/stderr | tail -1)
    
    generate_report "$etcd_status" "$velero_status" "$csi_status" "$db_status"
}

main "$@"
```

---

## 备份最佳实践清单

### 备份策略检查清单

| 检查项 | 频率 | 负责人 | 状态 |
|-------|------|-------|------|
| **etcd备份** | 每6小时 | 平台团队 | ☐ |
| **Velero全量备份** | 每日 | 平台团队 | ☐ |
| **CSI快照** | 每日 | 应用团队 | ☐ |
| **数据库备份** | 每日 | DBA团队 | ☐ |
| **备份验证测试** | 每周 | 平台团队 | ☐ |
| **恢复演练** | 每月 | 全团队 | ☐ |
| **备份存储容量检查** | 每周 | 运维团队 | ☐ |
| **跨区域备份同步** | 每日 | 平台团队 | ☐ |
| **备份加密验证** | 每月 | 安全团队 | ☐ |
| **备份保留策略审计** | 每季度 | 合规团队 | ☐ |

### RPO/RTO 设计指南

| 应用层级 | RPO目标 | RTO目标 | 备份策略 | 成本等级 |
|---------|--------|--------|---------|---------|
| **Tier 0 (关键)** | < 1分钟 | < 15分钟 | 同步复制 + CDP | $$$$$ |
| **Tier 1 (重要)** | < 1小时 | < 1小时 | 增量备份 + 快照 | $$$$ |
| **Tier 2 (标准)** | < 4小时 | < 4小时 | 每日全量 + 增量 | $$$ |
| **Tier 3 (开发)** | < 24小时 | < 24小时 | 每日全量 | $$ |
| **Tier 4 (测试)** | < 7天 | < 48小时 | 每周全量 | $ |

---

## 版本变更记录

| K8s版本 | 变更内容 | 影响 |
|--------|---------|------|
| v1.32 | VolumeSnapshot GA 增强 | 更稳定的快照功能 |
| v1.31 | Velero 1.14 兼容性 | 新的插件架构 |
| v1.30 | CSI 快照 webhook 改进 | 更好的验证 |
| v1.29 | etcd 3.5 备份优化 | 更快的快照速度 |
| v1.28 | Kopia 替代 Restic | 更好的去重和加密 |
| v1.27 | 数据移动器 GA | 跨存储类迁移 |
| v1.26 | 备份 hook 增强 | 更灵活的应用感知 |
| v1.25 | VolumeSnapshot v1 | 稳定的快照 API |

---

> **参考文档**:  
> - [etcd 运维指南](https://etcd.io/docs/latest/op-guide/)
> - [Velero 官方文档](https://velero.io/docs/)
> - [Kubernetes CSI 快照](https://kubernetes.io/docs/concepts/storage/volume-snapshots/)
> - [ACK 备份恢复](https://help.aliyun.com/document_detail/86987.html)

---

*Kusheet - Kubernetes 知识速查表项目*
