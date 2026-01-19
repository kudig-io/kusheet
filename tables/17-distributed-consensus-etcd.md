# 17 - 分布式共识与etcd原理 (Distributed Consensus & etcd)

## 分布式系统基础

| 概念 | 英文 | 说明 |
|-----|-----|------|
| 分布式系统 | Distributed System | 多节点协同工作的系统 |
| 共识 | Consensus | 多节点就某个值达成一致 |
| 一致性 | Consistency | 数据在各节点间保持一致 |
| 可用性 | Availability | 系统持续提供服务的能力 |
| 分区容错 | Partition Tolerance | 网络分区时仍能工作 |

## CAP定理

| 属性 | 英文 | 说明 | K8s选择 |
|-----|-----|------|--------|
| C | Consistency | 所有节点看到相同数据 | ✓ 优先 |
| A | Availability | 每个请求都能得到响应 | 部分牺牲 |
| P | Partition Tolerance | 网络分区时继续运行 | ✓ 必须 |

> K8s/etcd选择CP模式: 牺牲部分可用性换取强一致性

## Raft共识算法

| 概念 | 说明 |
|-----|------|
| Leader | 领导者,处理所有写请求 |
| Follower | 跟随者,复制Leader日志 |
| Candidate | 候选者,选举期间的状态 |
| Term | 任期,逻辑时钟 |
| Log | 日志,操作记录 |

### Raft状态转换

```
                    超时,开始选举
Follower ──────────────────────────► Candidate
    ▲                                    │
    │                                    │
    │ 发现更高term                       │ 获得多数票
    │ 或收到Leader心跳                   ▼
    └────────────────────────────── Leader
```

## Raft选举过程

| 阶段 | 操作 |
|-----|------|
| 1. 超时 | Follower选举超时,转为Candidate |
| 2. 增加term | term+1,投票给自己 |
| 3. 请求投票 | 向其他节点发送RequestVote |
| 4. 收集选票 | 等待多数派响应 |
| 5a. 当选 | 获得多数票,成为Leader |
| 5b. 落选 | 收到更高term,退回Follower |
| 5c. 平局 | 超时重新选举 |

## Raft日志复制

| 阶段 | 操作 |
|-----|------|
| 1 | Client发送写请求到Leader |
| 2 | Leader追加日志条目(uncommitted) |
| 3 | Leader并行发送AppendEntries给Followers |
| 4 | Followers追加日志,返回成功 |
| 5 | Leader收到多数确认,提交(commit)日志 |
| 6 | Leader响应Client成功 |
| 7 | 后续心跳通知Followers提交 |

## etcd核心特性

| 特性 | 说明 |
|-----|------|
| 强一致性 | 基于Raft保证 |
| Watch机制 | 监听key变化 |
| MVCC | 多版本并发控制 |
| 事务 | 支持原子事务操作 |
| TTL | 键值过期时间 |
| Lease | 租约机制 |

## etcd数据模型

| 概念 | 说明 |
|-----|------|
| Key-Value | 扁平化键值存储 |
| Revision | 全局递增版本号 |
| ModRevision | 键的最后修改版本 |
| CreateRevision | 键的创建版本 |
| Version | 键的修改次数 |

### K8s在etcd中的存储结构

```
/registry/
├── pods/
│   ├── default/
│   │   ├── nginx-abc123
│   │   └── nginx-def456
│   └── kube-system/
│       └── coredns-xyz789
├── deployments/
│   └── default/
│       └── nginx
├── services/
│   └── default/
│       └── kubernetes
├── secrets/
│   └── default/
│       └── default-token-xxxxx
└── ...
```

## etcd集群架构

| 配置 | 节点数 | 容错能力 | 说明 |
|-----|-------|---------|------|
| 单节点 | 1 | 0 | 开发测试 |
| 最小HA | 3 | 1 | 生产最小配置 |
| 推荐HA | 5 | 2 | 生产推荐 |
| 大规模 | 7 | 3 | 大型集群 |

> 公式: 容忍故障节点数 = (N-1)/2

## etcd性能指标

| 指标 | 建议值 | 说明 |
|-----|-------|------|
| 磁盘延迟 | <10ms | WAL写入延迟 |
| 网络延迟 | <10ms | 节点间RTT |
| IOPS | >3000 | 磁盘IO能力 |
| 磁盘类型 | SSD | 必须使用SSD |

## etcd运维操作

| 操作 | 命令 |
|-----|------|
| 查看成员 | `etcdctl member list` |
| 查看状态 | `etcdctl endpoint status` |
| 健康检查 | `etcdctl endpoint health` |
| 添加成员 | `etcdctl member add <name> --peer-urls=<url>` |
| 移除成员 | `etcdctl member remove <id>` |
| 备份 | `etcdctl snapshot save backup.db` |
| 恢复 | `etcdctl snapshot restore backup.db` |
| 碎片整理 | `etcdctl defrag` |

### etcd备份脚本

```bash
#!/bin/bash
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-$(date +%Y%m%d%H%M).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

## etcd与API Server交互

| 操作 | API Server | etcd |
|-----|-----------|------|
| 创建资源 | POST /api/v1/pods | Put key |
| 读取资源 | GET /api/v1/pods/name | Get key |
| 更新资源 | PUT /api/v1/pods/name | Txn (compare+put) |
| 删除资源 | DELETE /api/v1/pods/name | Delete key |
| 监听变化 | Watch /api/v1/pods | Watch prefix |

## etcd调优参数

| 参数 | 默认值 | 建议值 | 说明 |
|-----|-------|-------|------|
| quota-backend-bytes | 2GB | 8GB | 存储配额 |
| snapshot-count | 100000 | 10000 | 快照触发条数 |
| heartbeat-interval | 100ms | 100ms | 心跳间隔 |
| election-timeout | 1000ms | 1000ms | 选举超时 |
| auto-compaction-retention | 0 | 1h | 自动压缩保留 |

## 常见问题

| 问题 | 原因 | 解决 |
|-----|------|------|
| 空间不足 | 超过quota | 压缩+碎片整理 |
| 选举频繁 | 网络/磁盘慢 | 优化基础设施 |
| 延迟高 | 磁盘IOPS不足 | 使用SSD |
| 脑裂 | 网络分区 | 检查网络 |

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)
