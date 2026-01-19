# etcd 深度解析 (etcd Deep Dive)

> etcd 是 Kubernetes 的核心存储组件，所有集群状态数据的唯一真相来源 (Single Source of Truth)

---

## 1. etcd 架构概述 (Architecture Overview)

### 1.1 核心架构组件

| 组件 | 英文名 | 职责 | 关键特性 |
|:---|:---|:---|:---|
| **Raft模块** | Raft Module | 分布式共识 | Leader选举、日志复制、安全性保证 |
| **WAL** | Write-Ahead Log | 持久化日志 | 顺序写入、崩溃恢复、数据完整性 |
| **快照** | Snapshot | 状态压缩 | 减少WAL大小、加速恢复 |
| **MVCC存储** | MVCC Store | 多版本存储 | 历史版本、Watch支持、事务隔离 |
| **BoltDB** | BoltDB Backend | 持久化后端 | B+树索引、页面管理、ACID事务 |
| **gRPC服务** | gRPC Server | API层 | 客户端通信、流式Watch |
| **Auth模块** | Auth Module | 认证授权 | 用户管理、角色权限、TLS |
| **Compaction** | Compaction | 版本压缩 | 历史清理、空间回收 |

### 1.2 数据流架构

```
┌─────────────────────────────────────────────────────────────────┐
│                         Client Request                           │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      gRPC Server Layer                           │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────────┐ │
│  │   KV    │  │  Watch  │  │  Lease  │  │  Maintenance/Auth   │ │
│  └────┬────┘  └────┬────┘  └────┬────┘  └──────────┬──────────┘ │
└───────┼────────────┼────────────┼───────────────────┼────────────┘
        │            │            │                   │
        ▼            ▼            ▼                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                        etcd Server                               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Raft Consensus                         │   │
│  │  ┌─────────┐  ┌─────────────┐  ┌─────────────────────┐   │   │
│  │  │ Leader  │  │  Followers  │  │  Learners (Non-vote) │   │   │
│  │  └────┬────┘  └──────┬──────┘  └──────────┬──────────┘   │   │
│  └───────┼──────────────┼────────────────────┼──────────────┘   │
│          │              │                    │                   │
│          ▼              ▼                    ▼                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   WAL (Write-Ahead Log)                   │   │
│  └──────────────────────────────────────────────────────────┘   │
│          │                                                       │
│          ▼                                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              MVCC Store (Multi-Version)                   │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐   │   │
│  │  │  TreeIndex  │  │  Backend    │  │  Lease Manager  │   │   │
│  │  │  (B-tree)   │  │  (BoltDB)   │  │                 │   │   │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘   │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 Raft 共识状态机

| 状态 | 英文 | 描述 | 转换条件 |
|:---|:---|:---|:---|
| **Follower** | 跟随者 | 被动接收日志 | 初始状态/选举失败/发现更高任期 |
| **Candidate** | 候选者 | 发起选举 | 选举超时触发 |
| **Leader** | 领导者 | 处理所有写请求 | 获得多数票 |
| **Learner** | 学习者 | 非投票成员 | 手动配置/新节点加入 |

```
                    ┌────────────────┐
                    │    Follower    │
                    └───────┬────────┘
                            │ election timeout
                            ▼
                    ┌────────────────┐
         ┌──────────│   Candidate   │──────────┐
         │          └───────┬────────┘          │
         │ discovers        │ receives          │ discovers
         │ higher term      │ majority votes    │ current leader
         │                  ▼                   │
         │          ┌────────────────┐          │
         └──────────│    Leader     │──────────┘
                    └────────────────┘
```

---

## 2. 关键配置参数 (Configuration Parameters)

### 2.1 集群配置

| 参数 | 默认值 | 推荐值(生产) | 说明 |
|:---|:---|:---|:---|
| `--name` | default | 唯一节点名 | 节点标识符 |
| `--data-dir` | ${name}.etcd | /var/lib/etcd | 数据目录(SSD必须) |
| `--wal-dir` | 空(同data-dir) | 独立SSD | WAL分离提升性能 |
| `--listen-peer-urls` | http://localhost:2380 | https://0.0.0.0:2380 | 节点间通信地址 |
| `--listen-client-urls` | http://localhost:2379 | https://0.0.0.0:2379 | 客户端访问地址 |
| `--initial-advertise-peer-urls` | http://localhost:2380 | https://节点IP:2380 | 广播给其他节点的地址 |
| `--advertise-client-urls` | http://localhost:2379 | https://节点IP:2379 | 广播给客户端的地址 |
| `--initial-cluster` | - | node1=url1,node2=url2,node3=url3 | 初始集群成员列表 |
| `--initial-cluster-state` | new | new/existing | 新建/加入已有集群 |
| `--initial-cluster-token` | etcd-cluster | 唯一token | 集群标识,防止跨集群通信 |

### 2.2 性能调优参数

| 参数 | 默认值 | 推荐值 | 影响 |
|:---|:---|:---|:---|
| `--heartbeat-interval` | 100ms | 100-500ms | Leader心跳间隔 |
| `--election-timeout` | 1000ms | 1000-5000ms | 选举超时(≥10x heartbeat) |
| `--snapshot-count` | 100000 | 10000-100000 | 触发快照的事务数 |
| `--quota-backend-bytes` | 2GB | 8GB | 存储配额(K8s集群建议8GB) |
| `--max-request-bytes` | 1.5MB | 10MB | 单请求最大字节数 |
| `--grpc-keepalive-min-time` | 5s | 5s | gRPC keepalive最小间隔 |
| `--grpc-keepalive-interval` | 2h | 2h | gRPC keepalive间隔 |
| `--grpc-keepalive-timeout` | 20s | 20s | gRPC keepalive超时 |
| `--auto-compaction-retention` | 0 | 1h | 自动压缩保留时间 |
| `--auto-compaction-mode` | periodic | revision | 压缩模式(periodic/revision) |

### 2.3 安全配置

| 参数 | 用途 | 示例值 |
|:---|:---|:---|
| `--cert-file` | 服务器证书 | /etc/etcd/ssl/server.crt |
| `--key-file` | 服务器私钥 | /etc/etcd/ssl/server.key |
| `--trusted-ca-file` | CA证书 | /etc/etcd/ssl/ca.crt |
| `--peer-cert-file` | 节点间证书 | /etc/etcd/ssl/peer.crt |
| `--peer-key-file` | 节点间私钥 | /etc/etcd/ssl/peer.key |
| `--peer-trusted-ca-file` | 节点间CA | /etc/etcd/ssl/ca.crt |
| `--client-cert-auth` | 客户端证书验证 | true |
| `--peer-client-cert-auth` | 节点间证书验证 | true |

---

## 3. Kubernetes 数据模型 (K8s Data Model in etcd)

### 3.1 Key 命名规范

| 资源类型 | Key 格式 | 示例 |
|:---|:---|:---|
| **Namespaced资源** | /registry/{resource}/{namespace}/{name} | /registry/pods/default/nginx |
| **Cluster资源** | /registry/{resource}/{name} | /registry/nodes/node-1 |
| **API组资源** | /registry/{group}/{resource}/{namespace}/{name} | /registry/apps/deployments/default/web |
| **CRD资源** | /registry/{group}/{resource}/{namespace}/{name} | /registry/example.com/myresources/default/test |
| **Lease** | /registry/leases/{namespace}/{name} | /registry/leases/kube-system/kube-scheduler |
| **Event** | /registry/events/{namespace}/{name} | /registry/events/default/pod.event.xxx |
| **ConfigMap** | /registry/configmaps/{namespace}/{name} | /registry/configmaps/kube-system/coredns |
| **Secret** | /registry/secrets/{namespace}/{name} | /registry/secrets/default/my-secret |

### 3.2 存储格式

```go
// Kubernetes 资源在 etcd 中的存储格式
type StoredObject struct {
    // Key: /registry/pods/default/nginx
    // Value: protobuf编码的Pod对象
    
    // 实际存储的元数据
    ResourceVersion string    // etcd的ModRevision
    CreationTime    time.Time // 创建时间
    Data            []byte    // protobuf编码的资源数据
}

// 查看实际存储
// etcdctl get /registry/pods/default/nginx --print-value-only | \
//   protoc --decode_raw
```

### 3.3 数据量估算

| 集群规模 | Pod数 | 预估etcd大小 | 建议配额 |
|:---|:---|:---|:---|
| 小型 (<100节点) | <1000 | 100MB-500MB | 2GB |
| 中型 (100-500节点) | 1000-5000 | 500MB-2GB | 4GB |
| 大型 (500-1000节点) | 5000-10000 | 2GB-5GB | 8GB |
| 超大型 (>1000节点) | >10000 | 5GB-10GB | 16GB |

---

## 4. 运维操作手册 (Operations Guide)

### 4.1 集群健康检查

```bash
# 检查集群健康状态
etcdctl endpoint health --cluster \
  --cacert=/etc/etcd/ssl/ca.crt \
  --cert=/etc/etcd/ssl/client.crt \
  --key=/etc/etcd/ssl/client.key

# 检查集群状态详情
etcdctl endpoint status --cluster -w table \
  --cacert=/etc/etcd/ssl/ca.crt \
  --cert=/etc/etcd/ssl/client.crt \
  --key=/etc/etcd/ssl/client.key

# 输出示例:
+---------------------------+------------------+---------+---------+-----------+...
|         ENDPOINT          |        ID        | VERSION | DB SIZE | IS LEADER |...
+---------------------------+------------------+---------+---------+-----------+...
| https://10.0.0.1:2379     | 8e9e05c52164694d |  3.5.9  |  5.6 MB |   true    |...
| https://10.0.0.2:2379     | 1a32fd88dfa58d02 |  3.5.9  |  5.6 MB |   false   |...
| https://10.0.0.3:2379     | fc84e17a3f0c76a4 |  3.5.9  |  5.6 MB |   false   |...
+---------------------------+------------------+---------+---------+-----------+...

# 检查成员列表
etcdctl member list -w table

# 检查Leader
etcdctl endpoint status --cluster | grep "true" | awk -F',' '{print $1}'
```

### 4.2 备份与恢复

```bash
# ===== 备份 =====
# 创建快照备份
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-$(date +%Y%m%d-%H%M%S).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ssl/ca.crt \
  --cert=/etc/etcd/ssl/client.crt \
  --key=/etc/etcd/ssl/client.key

# 验证快照
etcdctl snapshot status /backup/etcd-20240101-120000.db -w table

# 输出:
+----------+----------+------------+------------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+----------+----------+------------+------------+
| 3c5d8f2a |   123456 |       5432 |     5.6 MB |
+----------+----------+------------+------------+

# 定时备份脚本
cat > /usr/local/bin/etcd-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR=/backup/etcd
RETENTION_DAYS=7
BACKUP_FILE="$BACKUP_DIR/etcd-$(date +%Y%m%d-%H%M%S).db"

# 创建备份
ETCDCTL_API=3 etcdctl snapshot save "$BACKUP_FILE" \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ssl/ca.crt \
  --cert=/etc/etcd/ssl/client.crt \
  --key=/etc/etcd/ssl/client.key

# 验证备份
if etcdctl snapshot status "$BACKUP_FILE" >/dev/null 2>&1; then
    echo "Backup successful: $BACKUP_FILE"
    # 清理旧备份
    find "$BACKUP_DIR" -name "etcd-*.db" -mtime +$RETENTION_DAYS -delete
else
    echo "Backup failed!"
    exit 1
fi
EOF
chmod +x /usr/local/bin/etcd-backup.sh

# Cron定时任务 (每小时备份)
echo "0 * * * * root /usr/local/bin/etcd-backup.sh >> /var/log/etcd-backup.log 2>&1" \
  >> /etc/crontab
```

```bash
# ===== 恢复 =====
# 停止所有etcd节点
systemctl stop etcd

# 节点1恢复
etcdctl snapshot restore /backup/etcd-20240101-120000.db \
  --name etcd-1 \
  --initial-cluster etcd-1=https://10.0.0.1:2380,etcd-2=https://10.0.0.2:2380,etcd-3=https://10.0.0.3:2380 \
  --initial-cluster-token etcd-cluster-restored \
  --initial-advertise-peer-urls https://10.0.0.1:2380 \
  --data-dir /var/lib/etcd-restored

# 节点2恢复 (在节点2上执行)
etcdctl snapshot restore /backup/etcd-20240101-120000.db \
  --name etcd-2 \
  --initial-cluster etcd-1=https://10.0.0.1:2380,etcd-2=https://10.0.0.2:2380,etcd-3=https://10.0.0.3:2380 \
  --initial-cluster-token etcd-cluster-restored \
  --initial-advertise-peer-urls https://10.0.0.2:2380 \
  --data-dir /var/lib/etcd-restored

# 节点3恢复 (在节点3上执行)
etcdctl snapshot restore /backup/etcd-20240101-120000.db \
  --name etcd-3 \
  --initial-cluster etcd-1=https://10.0.0.1:2380,etcd-2=https://10.0.0.2:2380,etcd-3=https://10.0.0.3:2380 \
  --initial-cluster-token etcd-cluster-restored \
  --initial-advertise-peer-urls https://10.0.0.3:2380 \
  --data-dir /var/lib/etcd-restored

# 更新data-dir配置并启动
mv /var/lib/etcd /var/lib/etcd.old
mv /var/lib/etcd-restored /var/lib/etcd
systemctl start etcd
```

### 4.3 成员管理

```bash
# 添加新成员 (Learner模式,推荐)
etcdctl member add etcd-4 --learner \
  --peer-urls=https://10.0.0.4:2380

# 提升Learner为正式成员
etcdctl member promote <member_id>

# 直接添加成员 (不推荐,可能影响集群稳定性)
etcdctl member add etcd-4 \
  --peer-urls=https://10.0.0.4:2380

# 移除成员
etcdctl member remove <member_id>

# 更新成员peer URLs
etcdctl member update <member_id> \
  --peer-urls=https://new-ip:2380
```

### 4.4 数据压缩与碎片整理

```bash
# 获取当前revision
CURRENT_REV=$(etcdctl endpoint status -w json | jq -r '.[0].Status.header.revision')

# 手动压缩 (保留最近1000个revision)
etcdctl compact $((CURRENT_REV - 1000))

# 碎片整理 (每个节点依次执行)
etcdctl defrag --endpoints=https://10.0.0.1:2379
etcdctl defrag --endpoints=https://10.0.0.2:2379
etcdctl defrag --endpoints=https://10.0.0.3:2379

# 检查碎片整理效果
etcdctl endpoint status --cluster -w table

# 自动压缩配置 (推荐)
# etcd启动参数添加:
# --auto-compaction-retention=1h
# --auto-compaction-mode=periodic
```

---

## 5. 监控指标 (Monitoring Metrics)

### 5.1 关键指标表

| 指标名称 | 类型 | 告警阈值 | 说明 |
|:---|:---|:---|:---|
| `etcd_server_has_leader` | Gauge | = 0 | 是否有Leader(0=无Leader,严重) |
| `etcd_server_leader_changes_seen_total` | Counter | > 3/hour | Leader切换次数 |
| `etcd_server_proposals_failed_total` | Counter | > 0 | 提案失败数 |
| `etcd_server_proposals_pending` | Gauge | > 5 | 待处理提案数 |
| `etcd_server_proposals_committed_total` | Counter | - | 已提交提案总数 |
| `etcd_server_proposals_applied_total` | Counter | - | 已应用提案总数 |
| `etcd_mvcc_db_total_size_in_bytes` | Gauge | > 6GB (75% quota) | 数据库大小 |
| `etcd_mvcc_db_total_size_in_use_in_bytes` | Gauge | - | 实际使用大小 |
| `etcd_disk_wal_fsync_duration_seconds` | Histogram | p99 > 10ms | WAL fsync延迟 |
| `etcd_disk_backend_commit_duration_seconds` | Histogram | p99 > 25ms | 后端提交延迟 |
| `etcd_network_peer_round_trip_time_seconds` | Histogram | p99 > 50ms | 节点间RTT |
| `etcd_server_slow_apply_total` | Counter | > 0 | 慢apply计数 |
| `etcd_server_slow_read_indexes_total` | Counter | > 0 | 慢read index计数 |
| `grpc_server_handled_total` | Counter | - | gRPC请求总数 |
| `process_resident_memory_bytes` | Gauge | > 8GB | 内存使用 |

### 5.2 Prometheus 告警规则

```yaml
groups:
- name: etcd
  rules:
  # 无Leader告警
  - alert: EtcdNoLeader
    expr: etcd_server_has_leader == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "etcd cluster has no leader"
      description: "etcd cluster {{ $labels.job }} has no leader for more than 1 minute"

  # Leader频繁切换
  - alert: EtcdHighLeaderChanges
    expr: increase(etcd_server_leader_changes_seen_total[1h]) > 3
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd leader changes too frequently"
      description: "etcd {{ $labels.instance }} leader changed {{ $value }} times in last hour"

  # 数据库大小告警
  - alert: EtcdDatabaseSizeHigh
    expr: etcd_mvcc_db_total_size_in_bytes > 6442450944  # 6GB
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd database size is high"
      description: "etcd {{ $labels.instance }} database size is {{ $value | humanize1024 }}"

  # WAL fsync延迟高
  - alert: EtcdWALFsyncDurationHigh
    expr: histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m])) > 0.01
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd WAL fsync latency is high"
      description: "etcd {{ $labels.instance }} WAL fsync p99 latency is {{ $value }}s"

  # 提案失败
  - alert: EtcdProposalsFailed
    expr: increase(etcd_server_proposals_failed_total[5m]) > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd proposals are failing"
      description: "etcd {{ $labels.instance }} has {{ $value }} failed proposals in last 5 minutes"

  # 成员数量异常
  - alert: EtcdMemberCountMismatch
    expr: count(etcd_server_id) by (job) != 3
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd member count is not 3"
      description: "etcd cluster {{ $labels.job }} has {{ $value }} members (expected 3)"

  # 网络RTT高
  - alert: EtcdNetworkRTTHigh
    expr: histogram_quantile(0.99, rate(etcd_network_peer_round_trip_time_seconds_bucket[5m])) > 0.05
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd peer network RTT is high"
      description: "etcd {{ $labels.instance }} peer RTT p99 is {{ $value }}s"
```

### 5.3 Grafana Dashboard 面板

| 面板名称 | 指标 | 可视化类型 |
|:---|:---|:---|
| Cluster Health | etcd_server_has_leader | Stat/Singlestat |
| Leader Changes | etcd_server_leader_changes_seen_total | Graph (rate) |
| Database Size | etcd_mvcc_db_total_size_in_bytes | Gauge |
| QPS | grpc_server_handled_total | Graph (rate) |
| WAL Fsync Latency | etcd_disk_wal_fsync_duration_seconds | Heatmap |
| Backend Commit Latency | etcd_disk_backend_commit_duration_seconds | Heatmap |
| Peer RTT | etcd_network_peer_round_trip_time_seconds | Heatmap |
| Memory Usage | process_resident_memory_bytes | Graph |
| Proposals | etcd_server_proposals_* | Graph (rate) |
| Keys Count | etcd_debugging_mvcc_keys_total | Graph |

---

## 6. 性能优化 (Performance Tuning)

### 6.1 硬件选型建议

| 组件 | 建议配置 | 说明 |
|:---|:---|:---|
| **CPU** | 4-8核 | etcd单线程写入,多核用于并发读 |
| **内存** | 16-32GB | 建议为quota的2-4倍 |
| **存储** | NVMe SSD, ≥1000 IOPS | 必须使用SSD,避免使用网络存储 |
| **网络** | ≥1Gbps, RTT<10ms | 低延迟网络至关重要 |
| **专用磁盘** | 独立SSD | WAL和数据分离可提升性能 |

### 6.2 参数优化矩阵

| 场景 | heartbeat-interval | election-timeout | snapshot-count | quota-backend-bytes |
|:---|:---|:---|:---|:---|
| 低延迟网络 (<1ms RTT) | 100ms | 1000ms | 100000 | 8GB |
| 普通网络 (1-10ms RTT) | 250ms | 2500ms | 50000 | 8GB |
| 高延迟网络 (>10ms RTT) | 500ms | 5000ms | 25000 | 8GB |
| 跨Region部署 | 1000ms | 10000ms | 10000 | 8GB |

### 6.3 Linux 内核优化

```bash
# 文件描述符限制
cat >> /etc/security/limits.conf << EOF
* soft nofile 65536
* hard nofile 65536
etcd soft nofile 65536
etcd hard nofile 65536
EOF

# 内核参数优化
cat >> /etc/sysctl.conf << EOF
# 网络优化
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_max_syn_backlog = 32768
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1

# 内存优化
vm.swappiness = 0
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

# 文件系统
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
EOF

sysctl -p

# 磁盘I/O调度器 (SSD推荐none或mq-deadline)
echo none > /sys/block/nvme0n1/queue/scheduler

# 禁用透明大页 (THP)
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
```

---

## 7. 故障排查 (Troubleshooting)

### 7.1 常见问题诊断表

| 症状 | 可能原因 | 诊断命令 | 解决方案 |
|:---|:---|:---|:---|
| **集群无Leader** | 网络分区/节点故障 | `etcdctl endpoint health --cluster` | 检查网络,恢复节点 |
| **写入超时** | 磁盘慢/网络延迟 | `etcdctl endpoint status -w table` | 检查磁盘IOPS,网络RTT |
| **空间不足** | 未配置压缩/碎片多 | `etcdctl endpoint status` | 执行压缩和碎片整理 |
| **频繁Leader切换** | 网络不稳定/磁盘慢 | 检查Prometheus指标 | 优化网络/升级磁盘 |
| **成员无法加入** | 集群配置错误 | `etcdctl member list` | 检查initial-cluster配置 |
| **数据不一致** | 时钟漂移/网络问题 | 比较各节点revision | 同步NTP,检查网络 |
| **内存OOM** | 大量Watch/未压缩 | `top -p $(pgrep etcd)` | 限制Watch数量,增加压缩 |
| **认证失败** | 证书过期/配置错误 | 检查证书有效期 | 更新证书 |

### 7.2 日志分析

```bash
# 查看etcd日志 (systemd)
journalctl -u etcd -f --no-pager

# 关键日志模式
# Leader选举
journalctl -u etcd | grep -E "(became leader|lost leader|elected)"

# 慢请求
journalctl -u etcd | grep -E "(slow|took too long)"

# 磁盘问题
journalctl -u etcd | grep -E "(disk|fdatasync)"

# 网络问题
journalctl -u etcd | grep -E "(connection|unreachable|peer)"

# 空间告警
journalctl -u etcd | grep -E "(quota|space|compact)"
```

### 7.3 紧急恢复流程

```bash
# 场景1: 单节点故障 (3节点集群)
# 1. 确认集群状态
etcdctl endpoint health --cluster

# 2. 移除故障成员
etcdctl member remove <failed_member_id>

# 3. 添加新成员
etcdctl member add etcd-new --peer-urls=https://new-ip:2380

# 4. 在新节点启动etcd (使用 --initial-cluster-state=existing)

# 场景2: 多数节点故障 (需要从备份恢复)
# 参考 4.2 备份与恢复 章节

# 场景3: 空间配额耗尽
# 1. 临时增加配额
etcdctl alarm disarm

# 2. 执行压缩
CURRENT_REV=$(etcdctl endpoint status -w json | jq -r '.[0].Status.header.revision')
etcdctl compact $CURRENT_REV

# 3. 碎片整理
etcdctl defrag --endpoints=https://127.0.0.1:2379

# 4. 永久解决: 增加quota-backend-bytes配置
```

---

## 8. 安全最佳实践 (Security Best Practices)

### 8.1 TLS 配置

```bash
# 生成CA证书
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# ca-csr.json
{
  "CN": "etcd-ca",
  "key": { "algo": "rsa", "size": 2048 },
  "names": [{ "O": "etcd" }]
}

# 生成服务器证书
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=server \
  server-csr.json | cfssljson -bare server

# server-csr.json
{
  "CN": "etcd-server",
  "hosts": [
    "127.0.0.1",
    "10.0.0.1",
    "10.0.0.2",
    "10.0.0.3",
    "etcd-0.etcd.default.svc.cluster.local",
    "etcd-1.etcd.default.svc.cluster.local",
    "etcd-2.etcd.default.svc.cluster.local"
  ],
  "key": { "algo": "rsa", "size": 2048 },
  "names": [{ "O": "etcd" }]
}
```

### 8.2 RBAC 配置

```bash
# 启用认证
etcdctl user add root --new-user-password="rootpass"
etcdctl role add root
etcdctl user grant-role root root
etcdctl auth enable

# 创建只读用户
etcdctl user add readonly --new-user-password="readpass"
etcdctl role add reader
etcdctl role grant-permission reader read --prefix /
etcdctl user grant-role readonly reader

# 创建特定前缀的读写用户
etcdctl user add appuser --new-user-password="apppass"
etcdctl role add app-rw
etcdctl role grant-permission app-rw readwrite --prefix /app/
etcdctl user grant-role appuser app-rw
```

### 8.3 网络隔离

```yaml
# Kubernetes NetworkPolicy (如果etcd运行在K8s内)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: etcd-network-policy
  namespace: kube-system
spec:
  podSelector:
    matchLabels:
      component: etcd
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # 只允许API Server访问客户端端口
  - from:
    - podSelector:
        matchLabels:
          component: kube-apiserver
    ports:
    - protocol: TCP
      port: 2379
  # 允许etcd节点间通信
  - from:
    - podSelector:
        matchLabels:
          component: etcd
    ports:
    - protocol: TCP
      port: 2380
  egress:
  # 允许etcd节点间通信
  - to:
    - podSelector:
        matchLabels:
          component: etcd
    ports:
    - protocol: TCP
      port: 2380
```

---

## 9. 版本对照与升级 (Version Compatibility)

### 9.1 etcd 与 Kubernetes 版本对应

| Kubernetes 版本 | 推荐 etcd 版本 | 最低 etcd 版本 | 备注 |
|:---|:---|:---|:---|
| v1.32 | 3.5.15+ | 3.5.0 | 推荐使用最新3.5.x |
| v1.31 | 3.5.12+ | 3.5.0 | |
| v1.30 | 3.5.10+ | 3.5.0 | |
| v1.29 | 3.5.9+ | 3.5.0 | |
| v1.28 | 3.5.9+ | 3.5.0 | |
| v1.27 | 3.5.7+ | 3.5.0 | |
| v1.26 | 3.5.6+ | 3.4.0 | |
| v1.25 | 3.5.4+ | 3.4.0 | |

### 9.2 升级策略

```bash
# 滚动升级步骤 (3.5.x -> 3.5.y)
# 原则: 一次升级一个节点,先Follower后Leader

# 1. 确认当前版本和集群状态
etcdctl endpoint status --cluster -w table

# 2. 获取当前Leader
LEADER=$(etcdctl endpoint status --cluster -w json | jq -r '.[] | select(.Status.leader == .Status.header.member_id) | .Endpoint')

# 3. 先升级Follower节点
# 在Follower节点执行:
systemctl stop etcd
# 替换etcd二进制文件
cp /usr/local/bin/etcd /usr/local/bin/etcd.bak
cp etcd-new-version /usr/local/bin/etcd
systemctl start etcd

# 4. 验证节点状态
etcdctl endpoint health --endpoints=https://follower-ip:2379

# 5. 重复步骤3-4升级其他Follower

# 6. 最后升级Leader节点
# 先转移Leader (可选,减少中断时间)
etcdctl move-leader <new_leader_id>
# 然后升级原Leader

# 7. 验证整个集群
etcdctl endpoint status --cluster -w table
```

---

## 10. 生产环境 Checklist

### 10.1 部署前检查

| 检查项 | 状态 | 说明 |
|:---|:---|:---|
| [ ] 节点数为奇数 (3/5/7) | | 保证Quorum |
| [ ] 使用NVMe/SSD存储 | | 性能要求 |
| [ ] 独立数据盘 | | 避免IO争抢 |
| [ ] 配置TLS加密 | | 安全要求 |
| [ ] 配置自动备份 | | 数据保护 |
| [ ] 配置监控告警 | | 运维保障 |
| [ ] 配置自动压缩 | | 空间管理 |
| [ ] 网络延迟<10ms | | 性能要求 |
| [ ] 时钟同步(NTP) | | 避免数据不一致 |
| [ ] 配置合理的quota | | 防止OOM |

### 10.2 日常运维检查

| 检查项 | 频率 | 命令/方法 |
|:---|:---|:---|
| 集群健康状态 | 每日 | `etcdctl endpoint health --cluster` |
| Leader状态 | 每日 | `etcdctl endpoint status` |
| 数据库大小 | 每日 | 检查Prometheus指标 |
| 备份状态 | 每日 | 验证备份文件存在且有效 |
| 证书有效期 | 每月 | `openssl x509 -in cert.pem -noout -dates` |
| 碎片整理 | 每周/月 | `etcdctl defrag` |
| 版本检查 | 每季度 | 检查是否有安全更新 |

---

## 附录: etcdctl 命令速查

```bash
# 基础操作
etcdctl put key value                    # 写入
etcdctl get key                          # 读取
etcdctl get --prefix /registry/          # 前缀查询
etcdctl del key                          # 删除
etcdctl watch key                        # 监听变化

# 集群管理
etcdctl member list                      # 成员列表
etcdctl member add name --peer-urls=url  # 添加成员
etcdctl member remove id                 # 移除成员
etcdctl endpoint health --cluster        # 健康检查
etcdctl endpoint status --cluster        # 状态详情

# 维护操作
etcdctl snapshot save file.db            # 快照备份
etcdctl snapshot restore file.db         # 恢复
etcdctl compact revision                 # 压缩
etcdctl defrag                           # 碎片整理
etcdctl alarm list                       # 告警列表
etcdctl alarm disarm                     # 清除告警

# 认证管理
etcdctl auth enable                      # 启用认证
etcdctl user add name                    # 添加用户
etcdctl role add name                    # 添加角色
etcdctl user grant-role user role        # 授权

# 常用选项
--endpoints=url1,url2,url3               # 指定端点
--cacert=ca.crt                          # CA证书
--cert=client.crt                        # 客户端证书
--key=client.key                         # 客户端私钥
-w table|json|simple                     # 输出格式
```
