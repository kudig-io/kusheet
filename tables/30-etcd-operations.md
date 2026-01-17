# 表格30: etcd运维操作

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [etcd.io/docs](https://etcd.io/docs/)

## etcd集群规格建议

| 集群规模 | 节点数 | CPU | 内存 | 磁盘类型 | 磁盘大小 | IOPS | 网络延迟 |
|---------|-------|-----|------|---------|---------|------|---------|
| <100节点 | 3 | 2核 | 8GB | SSD | 50GB | 3000 | <10ms |
| 100-500节点 | 3 | 4核 | 16GB | SSD | 100GB | 8000 | <5ms |
| 500-1000节点 | 5 | 8核 | 32GB | NVMe | 200GB | 16000 | <2ms |
| 1000-3000节点 | 5 | 16核 | 64GB | NVMe | 500GB | 25000+ | <2ms |
| >3000节点 | 5 | 32核 | 128GB | NVMe RAID | 1TB | 50000+ | <1ms |

## etcd关键参数

| 参数 | 默认值 | 推荐值 | 说明 | 调优场景 |
|-----|-------|-------|------|---------|
| `--quota-backend-bytes` | 2GB | 8GB | 后端配额 | 大集群必调 |
| `--max-request-bytes` | 1.5MB | 10MB | 最大请求大小 | 大Secret/ConfigMap |
| `--heartbeat-interval` | 100ms | 100-500ms | 心跳间隔 | 跨地域部署 |
| `--election-timeout` | 1000ms | 1000-5000ms | 选举超时 | 网络不稳定 |
| `--snapshot-count` | 100000 | 10000 | 快照触发计数 | 频繁写入 |
| `--auto-compaction-retention` | 0 | 1h | 自动压缩保留 | 减少存储 |
| `--auto-compaction-mode` | periodic | revision | 压缩模式 | 按需选择 |
| `--max-txn-ops` | 128 | 512 | 事务最大操作数 | 大批量操作 |
| `--max-watcher-per-resource` | 10000 | 10000 | 每资源最大watch | 大规模watch |
| `--grpc-keepalive-min-time` | 5s | 5s | gRPC保活最小间隔 | 长连接 |
| `--grpc-keepalive-interval` | 2h | 2h | gRPC保活间隔 | 连接稳定 |
| `--grpc-keepalive-timeout` | 20s | 20s | gRPC保活超时 | 快速检测 |

## etcdctl常用命令

| 操作 | 命令 | 说明 |
|-----|------|------|
| 集群状态 | `etcdctl endpoint status --cluster -w table` | 查看集群状态 |
| 成员列表 | `etcdctl member list -w table` | 列出成员 |
| 健康检查 | `etcdctl endpoint health --cluster` | 检查健康 |
| 写入数据 | `etcdctl put /key value` | 写入键值 |
| 读取数据 | `etcdctl get /key` | 读取键值 |
| 前缀查询 | `etcdctl get /prefix --prefix` | 前缀查询 |
| 删除数据 | `etcdctl del /key` | 删除键值 |
| 创建快照 | `etcdctl snapshot save backup.db` | 创建快照 |
| 恢复快照 | `etcdctl snapshot restore backup.db` | 恢复快照 |
| 压缩历史 | `etcdctl compact <revision>` | 压缩revision |
| 碎片整理 | `etcdctl defrag --cluster` | 碎片整理 |
| 告警查看 | `etcdctl alarm list` | 查看告警 |
| 告警清除 | `etcdctl alarm disarm` | 清除告警 |

## etcd监控指标

| 指标名称 | 类型 | 告警阈值 | 说明 |
|---------|-----|---------|------|
| `etcd_server_has_leader` | Gauge | =0 | Leader存在 |
| `etcd_server_leader_changes_seen_total` | Counter | >3/1h | Leader切换次数 |
| `etcd_disk_backend_commit_duration_seconds` | Histogram | p99>250ms | 磁盘提交延迟 |
| `etcd_disk_wal_fsync_duration_seconds` | Histogram | p99>100ms | WAL同步延迟 |
| `etcd_network_peer_round_trip_time_seconds` | Histogram | p99>100ms | 节点间RTT |
| `etcd_server_proposals_committed_total` | Counter | - | 提交的提案数 |
| `etcd_server_proposals_failed_total` | Counter | >0 | 失败的提案数 |
| `etcd_mvcc_db_total_size_in_bytes` | Gauge | >quota*0.8 | 数据库大小 |
| `etcd_mvcc_db_total_size_in_use_in_bytes` | Gauge | - | 使用中的大小 |
| `etcd_server_slow_apply_total` | Counter | >0 | 慢apply计数 |

## 备份与恢复

### 备份命令
```bash
# 使用etcdctl备份
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /backup/etcd-$(date +%Y%m%d-%H%M%S).db

# 验证备份
etcdctl snapshot status /backup/etcd-*.db -w table
```

### 恢复命令
```bash
# 停止API Server
# 恢复快照(每个节点执行不同参数)
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd.db \
  --name etcd-0 \
  --data-dir /var/lib/etcd-new \
  --initial-cluster etcd-0=https://10.0.0.1:2380,etcd-1=https://10.0.0.2:2380,etcd-2=https://10.0.0.3:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls https://10.0.0.1:2380

# 替换数据目录
mv /var/lib/etcd /var/lib/etcd-old
mv /var/lib/etcd-new /var/lib/etcd
# 重启etcd和API Server
```

## etcd故障处理

| 故障类型 | 症状 | 诊断命令 | 解决方案 |
|---------|-----|---------|---------|
| Leader丢失 | API Server超时 | `etcdctl endpoint status` | 检查网络/磁盘 |
| 配额超限 | NOSPACE告警 | `etcdctl alarm list` | 压缩+碎片整理 |
| 磁盘性能差 | 高延迟告警 | `fio`测试 | 升级SSD/NVMe |
| 成员不一致 | 日志报错 | `etcdctl member list` | 移除重新加入 |
| WAL损坏 | 启动失败 | 检查日志 | 从快照恢复 |

## 碎片整理操作

```bash
# 获取当前大小
etcdctl endpoint status --cluster -w table

# 执行压缩
rev=$(etcdctl endpoint status --write-out="json" | jq -r '.[] | .Status.header.revision')
etcdctl compact $rev

# 执行碎片整理(逐节点执行)
etcdctl defrag --endpoints=https://10.0.0.1:2379
etcdctl defrag --endpoints=https://10.0.0.2:2379
etcdctl defrag --endpoints=https://10.0.0.3:2379

# 清除告警
etcdctl alarm disarm
```

## ACK托管etcd

| 特性 | 说明 |
|-----|------|
| 自动备份 | 每天自动备份,保留7天 |
| 自动恢复 | 故障自动恢复 |
| 监控告警 | ARMS集成监控 |
| 扩缩容 | 3节点→5节点 |
| 跨AZ部署 | 高可用部署 |

## 版本对应关系

| K8s版本 | etcd版本 | 说明 |
|--------|---------|------|
| v1.25 | 3.5.4+ | 稳定版本 |
| v1.26 | 3.5.6+ | 安全修复 |
| v1.27 | 3.5.7+ | 性能优化 |
| v1.28 | 3.5.9+ | 稳定性提升 |
| v1.29 | 3.5.10+ | Bug修复 |
| v1.30 | 3.5.12+ | 安全更新 |
| v1.31 | 3.5.13+ | 最新稳定 |
| v1.32 | 3.5.15+ | 当前推荐 |

## 成员管理操作

```bash
# 添加成员
etcdctl member add etcd-3 --peer-urls=https://10.0.0.4:2380

# 移除成员
etcdctl member remove <member_id>

# 更新成员
etcdctl member update <member_id> --peer-urls=https://10.0.0.4:2380

# 强制移除成员(仅紧急情况)
etcdctl member remove <member_id> --force
```

## 灾难恢复操作

```bash
#!/bin/bash
# 完整灾难恢复脚本

# 1. 停止所有控制平面组件
systemctl stop kube-apiserver kube-controller-manager kube-scheduler

# 2. 停止所有etcd节点
for node in etcd-0 etcd-1 etcd-2; do
  ssh $node "systemctl stop etcd"
done

# 3. 备份旧数据目录
for node in etcd-0 etcd-1 etcd-2; do
  ssh $node "mv /var/lib/etcd /var/lib/etcd.bak.$(date +%Y%m%d)"
done

# 4. 在每个节点恢复快照
# 节点0
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-backup.db \
  --name etcd-0 \
  --initial-cluster "etcd-0=https://10.0.0.1:2380,etcd-1=https://10.0.0.2:2380,etcd-2=https://10.0.0.3:2380" \
  --initial-cluster-token etcd-cluster-recovery \
  --initial-advertise-peer-urls https://10.0.0.1:2380 \
  --data-dir /var/lib/etcd

# 节点1
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-backup.db \
  --name etcd-1 \
  --initial-cluster "etcd-0=https://10.0.0.1:2380,etcd-1=https://10.0.0.2:2380,etcd-2=https://10.0.0.3:2380" \
  --initial-cluster-token etcd-cluster-recovery \
  --initial-advertise-peer-urls https://10.0.0.2:2380 \
  --data-dir /var/lib/etcd

# 5. 启动etcd集群
for node in etcd-0 etcd-1 etcd-2; do
  ssh $node "systemctl start etcd"
done

# 6. 验证集群状态
etcdctl endpoint status --cluster -w table
etcdctl endpoint health --cluster

# 7. 启动控制平面组件
systemctl start kube-apiserver kube-controller-manager kube-scheduler
```

## 定期维护脚本

```bash
#!/bin/bash
# etcd定期维护脚本 - 建议每天执行

set -e

ETCD_ENDPOINTS="https://10.0.0.1:2379,https://10.0.0.2:2379,https://10.0.0.3:2379"
ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"
BACKUP_DIR="/backup/etcd"
RETENTION_DAYS=7

export ETCDCTL_API=3
alias etcdctl="etcdctl --endpoints=$ETCD_ENDPOINTS --cacert=$ETCD_CACERT --cert=$ETCD_CERT --key=$ETCD_KEY"

echo "=== $(date) etcd维护开始 ==="

# 1. 健康检查
echo "1. 执行健康检查..."
etcdctl endpoint health --cluster
if [ $? -ne 0 ]; then
  echo "ERROR: 集群不健康，跳过维护"
  exit 1
fi

# 2. 创建备份
echo "2. 创建备份..."
BACKUP_FILE="$BACKUP_DIR/etcd-$(date +%Y%m%d-%H%M%S).db"
etcdctl snapshot save $BACKUP_FILE
etcdctl snapshot status $BACKUP_FILE -w table

# 3. 清理旧备份
echo "3. 清理旧备份..."
find $BACKUP_DIR -name "etcd-*.db" -mtime +$RETENTION_DAYS -delete

# 4. 获取当前revision
echo "4. 获取当前revision..."
CURRENT_REV=$(etcdctl endpoint status --write-out=json | jq -r '.[0].Status.header.revision')
echo "当前revision: $CURRENT_REV"

# 5. 执行压缩
echo "5. 执行压缩..."
etcdctl compact $CURRENT_REV

# 6. 逐节点碎片整理
echo "6. 执行碎片整理..."
for endpoint in $(echo $ETCD_ENDPOINTS | tr ',' ' '); do
  echo "整理节点: $endpoint"
  etcdctl defrag --endpoints=$endpoint
  sleep 5
done

# 7. 检查告警
echo "7. 检查告警..."
ALARMS=$(etcdctl alarm list)
if [ -n "$ALARMS" ]; then
  echo "WARNING: 存在告警: $ALARMS"
  etcdctl alarm disarm
fi

# 8. 输出状态
echo "8. 最终状态..."
etcdctl endpoint status --cluster -w table

echo "=== $(date) etcd维护完成 ==="
```

## Prometheus告警规则

```yaml
groups:
- name: etcd
  rules:
  - alert: EtcdNoLeader
    expr: etcd_server_has_leader == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "etcd集群无Leader"
      description: "etcd集群 {{ $labels.job }} 无Leader超过1分钟"

  - alert: EtcdHighNumberOfLeaderChanges
    expr: increase(etcd_server_leader_changes_seen_total[1h]) > 3
    labels:
      severity: warning
    annotations:
      summary: "etcd Leader频繁切换"
      description: "etcd集群1小时内Leader切换 {{ $value }} 次"

  - alert: EtcdDatabaseSpaceExceeded
    expr: etcd_mvcc_db_total_size_in_bytes / etcd_server_quota_backend_bytes > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd数据库空间即将耗尽"
      description: "etcd数据库使用率 {{ $value | humanizePercentage }}"

  - alert: EtcdDatabaseSpaceCritical
    expr: etcd_mvcc_db_total_size_in_bytes / etcd_server_quota_backend_bytes > 0.95
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "etcd数据库空间严重不足"
      
  - alert: EtcdHighFsyncDuration
    expr: histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m])) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd WAL fsync延迟过高"
      description: "etcd WAL fsync P99延迟 {{ $value }}s"

  - alert: EtcdHighCommitDuration
    expr: histogram_quantile(0.99, rate(etcd_disk_backend_commit_duration_seconds_bucket[5m])) > 0.25
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd后端提交延迟过高"

  - alert: EtcdMemberCommunicationSlow
    expr: histogram_quantile(0.99, rate(etcd_network_peer_round_trip_time_seconds_bucket[5m])) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd成员间通信延迟过高"

  - alert: EtcdHighProposalFailures
    expr: increase(etcd_server_proposals_failed_total[5m]) > 5
    labels:
      severity: warning
    annotations:
      summary: "etcd提案失败过多"

  - alert: EtcdSlowApply
    expr: increase(etcd_server_slow_apply_total[5m]) > 0
    labels:
      severity: warning
    annotations:
      summary: "etcd存在慢apply"
```

## Grafana Dashboard关键面板

| 面板 | PromQL | 说明 |
|-----|--------|------|
| 集群状态 | `etcd_server_has_leader` | Leader存在性 |
| 数据库大小 | `etcd_mvcc_db_total_size_in_bytes` | 存储使用 |
| Leader变更 | `rate(etcd_server_leader_changes_seen_total[5m])` | 稳定性 |
| 请求延迟 | `histogram_quantile(0.99, rate(etcd_disk_backend_commit_duration_seconds_bucket[5m]))` | 性能 |
| QPS | `rate(etcd_server_proposals_committed_total[5m])` | 吞吐量 |
| 活跃Watch | `etcd_debugging_mvcc_watcher_total` | 连接数 |

## 最佳实践

| 实践 | 说明 | 优先级 |
|-----|------|-------|
| 独立SSD/NVMe | etcd对磁盘IO极敏感 | 必须 |
| 跨AZ部署 | 3节点跨3个AZ | 推荐 |
| 定期备份 | 至少每天一次 | 必须 |
| 定期压缩 | 避免空间耗尽 | 必须 |
| 监控告警 | 关键指标必须告警 | 必须 |
| 版本更新 | 跟随K8s版本推荐 | 推荐 |
| 网络隔离 | etcd专用网络 | 推荐 |
| TLS加密 | 节点间和客户端通信 | 必须 |
