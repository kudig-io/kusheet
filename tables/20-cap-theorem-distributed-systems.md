# 20 - CAP定理与分布式系统基础 (CAP Theorem & Distributed Systems)

## 分布式系统核心挑战

| 挑战 | 英文 | 说明 |
|-----|-----|------|
| 网络不可靠 | Network Unreliability | 延迟、丢包、分区 |
| 时钟不同步 | Clock Skew | 各节点时间不一致 |
| 部分失败 | Partial Failure | 部分节点故障 |
| 并发冲突 | Concurrency | 多节点并发操作 |
| 数据一致性 | Consistency | 多副本数据同步 |

## CAP定理

| 属性 | 英文 | 定义 |
|-----|-----|------|
| C | Consistency | 所有节点同一时刻看到相同数据 |
| A | Availability | 每个请求都能得到(非错误)响应 |
| P | Partition Tolerance | 网络分区时系统仍能运行 |

> CAP定理: 分布式系统最多只能同时满足三个属性中的两个

## CAP权衡

| 选择 | 牺牲 | 典型系统 | 说明 |
|-----|------|---------|------|
| CP | 可用性 | etcd, ZooKeeper, HBase | 分区时拒绝写入 |
| AP | 一致性 | Cassandra, DynamoDB | 最终一致性 |
| CA | 分区容错 | 单机数据库 | 不支持分布式 |

## 一致性模型

| 模型 | 英文 | 说明 | 示例 |
|-----|-----|------|-----|
| 强一致性 | Strong Consistency | 读取总是返回最新写入 | 单机数据库 |
| 线性一致性 | Linearizability | 操作有全局顺序 | etcd |
| 顺序一致性 | Sequential Consistency | 操作顺序一致但不实时 | - |
| 因果一致性 | Causal Consistency | 因果相关操作有序 | - |
| 最终一致性 | Eventual Consistency | 最终数据会一致 | DNS, Cassandra |

## 分布式系统理论

| 理论 | 说明 |
|-----|------|
| FLP不可能定理 | 异步系统中,共识无法在有限时间完成 |
| 两军问题 | 不可靠信道无法达成共识 |
| 拜占庭将军问题 | 存在恶意节点的共识 |
| PACELC | CAP扩展,考虑延迟 |

## PACELC定理

| 条件 | 选择 | 说明 |
|-----|------|------|
| 分区时(P) | A vs C | 可用性还是一致性 |
| 正常时(E) | L vs C | 延迟还是一致性 |

| 系统 | 分区时 | 正常时 |
|-----|-------|-------|
| MySQL (主从) | PC | EC |
| MongoDB | PA | EC |
| Cassandra | PA | EL |
| etcd | PC | EC |

## 共识算法对比

| 算法 | 容错 | 性能 | 复杂度 | 用途 |
|-----|------|-----|-------|-----|
| Paxos | CFT | 高 | 高 | 理论基础 |
| Raft | CFT | 高 | 中 | etcd, Consul |
| PBFT | BFT | 低 | 高 | 区块链 |
| Zab | CFT | 高 | 中 | ZooKeeper |

> CFT: Crash Fault Tolerant (崩溃容错)
> BFT: Byzantine Fault Tolerant (拜占庭容错)

## 复制策略

| 策略 | 英文 | 一致性 | 延迟 | 可用性 |
|-----|-----|-------|-----|-------|
| 同步复制 | Synchronous | 强 | 高 | 低 |
| 异步复制 | Asynchronous | 弱 | 低 | 高 |
| 半同步复制 | Semi-synchronous | 中 | 中 | 中 |
| 多数派复制 | Quorum | 强 | 中 | 中 |

## Quorum机制

| 参数 | 说明 |
|-----|------|
| N | 副本总数 |
| W | 写成功需要的副本数 |
| R | 读成功需要的副本数 |

| 条件 | 保证 |
|-----|------|
| W + R > N | 强一致性读 |
| W > N/2 | 写入不冲突 |
| R = 1, W = N | 写慢读快 |
| R = N, W = 1 | 读慢写快 |

### etcd的Quorum

```
N = 3 (3节点集群)
W = 2 (多数派写入)
R = 1 (从Leader读取)

写入流程:
1. Client发送写请求到Leader
2. Leader追加日志
3. Leader并行复制到Followers
4. 收到2/3确认后提交
5. 响应Client成功
```

## 故障类型

| 类型 | 英文 | 说明 | 检测 |
|-----|-----|------|------|
| 崩溃故障 | Crash Failure | 节点停止工作 | 心跳超时 |
| 遗漏故障 | Omission Failure | 消息丢失 | 超时重传 |
| 时序故障 | Timing Failure | 响应超时 | 超时检测 |
| 拜占庭故障 | Byzantine Failure | 任意行为(含恶意) | 签名验证 |

## 分布式时钟

| 类型 | 说明 | 用途 |
|-----|------|------|
| 物理时钟 | 实际时间,有偏差 | 日志时间戳 |
| 逻辑时钟 | Lamport时钟 | 事件排序 |
| 向量时钟 | Vector Clock | 因果关系 |
| 混合逻辑时钟 | HLC | 兼顾物理和逻辑 |

### Lamport时钟规则

```
1. 本地事件: C = C + 1
2. 发送消息: 附带当前C值
3. 接收消息: C = max(C, 收到的C) + 1
```

## K8s中的分布式设计

| 组件 | 分布式策略 |
|-----|----------|
| etcd | Raft共识,CP模型 |
| API Server | 无状态,可水平扩展 |
| Scheduler | Leader选举,单活 |
| Controller Manager | Leader选举,单活 |
| kubelet | 本地状态,最终一致 |

## 最佳实践

| 实践 | 说明 |
|-----|------|
| 选择合适一致性 | 根据业务需求选择 |
| 处理网络分区 | 设计分区恢复策略 |
| 使用幂等操作 | 重试安全 |
| 实现超时重试 | 应对网络不可靠 |
| 监控一致性 | 检测数据不一致 |

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)
