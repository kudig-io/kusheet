# 表格10：扩展和性能表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/setup/best-practices/cluster-large](https://kubernetes.io/docs/setup/best-practices/cluster-large/)

## 集群规模限制(官方测试)

| 维度 | 官方上限 | 推荐生产值 | 限制因素 | 版本改进 | 突破方法 |
|-----|---------|----------|---------|---------|---------|
| **节点数** | 5000 | 1000-3000 | etcd/apiserver性能 | v1.28+优化 | 多集群联邦 |
| **Pod数/集群** | 150,000 | 100,000 | apiserver/etcd | v1.27+优化 | 分集群部署 |
| **Pod数/节点** | 110(默认) | 110-250 | kubelet/CIDR | 可配置 | 调整max-pods和CIDR |
| **Service数** | 10,000 | 5,000 | kube-proxy规则 | v1.26+ IPVS | 使用IPVS模式 |
| **Endpoints/Service** | 5,000 | 1,000 | 端点对象大小 | EndpointSlice | 使用EndpointSlice |
| **Namespace数** | 10,000 | 1,000 | API对象数 | 稳定 | 合理规划 |
| **ConfigMap/Secret大小** | 1MB | 256KB | etcd单对象限制 | 稳定 | 拆分配置 |
| **etcd数据库大小** | 8GB(默认) | 8GB | 配额限制 | 可调整 | 增加quota |
| **API请求/秒** | 取决于配置 | 500-1000 | apiserver限流 | 可配置 | 调整限流参数 |

## HPA (Horizontal Pod Autoscaler) 配置

| 参数 | 默认值 | 推荐值 | 说明 | 版本支持 | 调优场景 |
|-----|-------|-------|------|---------|---------|
| **minReplicas** | 1 | >=2 | 最小副本数 | 稳定 | 保证高可用 |
| **maxReplicas** | 无 | 根据资源 | 最大副本数 | 稳定 | 防止资源耗尽 |
| **targetCPUUtilization** | 无 | 50-70% | CPU目标使用率 | 稳定 | 预留扩容空间 |
| **scaleDown.stabilizationWindowSeconds** | 300 | 300-600 | 缩容稳定窗口 | v1.23+ | 防止频繁缩容 |
| **scaleUp.stabilizationWindowSeconds** | 0 | 0-60 | 扩容稳定窗口 | v1.23+ | 快速响应 |
| **behavior.scaleDown.policies** | - | 自定义 | 缩容策略 | v1.23+ | 平滑缩容 |
| **behavior.scaleUp.policies** | - | 自定义 | 扩容策略 | v1.23+ | 快速扩容 |

```yaml
# HPA v2配置示例
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  minReplicas: 2
  maxReplicas: 100
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
```

## VPA (Vertical Pod Autoscaler) 配置

| 模式 | 行为 | 适用场景 | 注意事项 |
|-----|------|---------|---------|
| **Off** | 仅推荐，不更新 | 观察阶段 | 查看推荐值 |
| **Initial** | 仅创建时设置 | 新Pod使用推荐值 | 不影响运行中Pod |
| **Auto** | 自动更新Pod | 生产使用 | 会重启Pod |
| **Recreate** | 与Auto相同 | 别名 | - |

| 参数 | 说明 | 推荐值 |
|-----|------|-------|
| **minAllowed** | 最小资源 | 根据应用基线 |
| **maxAllowed** | 最大资源 | 节点资源限制 |
| **controlledResources** | 控制的资源类型 | [cpu, memory] |
| **containerPolicies** | 容器级策略 | 按容器配置 |

## Cluster Autoscaler 配置

| 参数 | 默认值 | 推荐值 | 说明 | 版本支持 |
|-----|-------|-------|------|---------|
| **scan-interval** | 10s | 10-30s | 扫描间隔 | 稳定 |
| **scale-down-delay-after-add** | 10m | 10m | 扩容后缩容延迟 | 稳定 |
| **scale-down-delay-after-delete** | 0s | 0s | 删除后缩容延迟 | 稳定 |
| **scale-down-unneeded-time** | 10m | 10m | 空闲节点等待时间 | 稳定 |
| **scale-down-utilization-threshold** | 0.5 | 0.5-0.7 | 缩容利用率阈值 | 稳定 |
| **max-node-provision-time** | 15m | 15m | 最大供应时间 | 稳定 |
| **max-graceful-termination-sec** | 600 | 600 | 优雅终止时间 | 稳定 |
| **expander** | random | least-waste | 扩容选择策略 | 稳定 |

## etcd性能调优

| 调优项 | 默认值 | 优化值 | 效果 | 注意事项 |
|-------|-------|-------|------|---------|
| **quota-backend-bytes** | 2GB | 8GB | 增加存储容量 | 需要更多内存 |
| **auto-compaction-mode** | periodic | revision | 更精确的压缩 | - |
| **auto-compaction-retention** | 0 | 1000(revision) | 减少存储增长 | 平衡历史和空间 |
| **snapshot-count** | 100000 | 10000 | 更频繁快照 | 更快恢复 |
| **heartbeat-interval** | 100ms | 100ms | 心跳频率 | 低延迟网络 |
| **election-timeout** | 1000ms | 1000ms | 选举超时 | >=5x心跳 |
| **磁盘类型** | - | NVMe SSD | 关键性能因素 | 必须 |
| **IOPS** | - | >3000 | 写入性能 | 监控 |
| **fsync延迟** | - | <10ms | WAL写入 | 监控 |

## API Server性能调优

| 调优项 | 默认值 | 大集群推荐值 | 效果 |
|-------|-------|------------|------|
| **max-requests-inflight** | 400 | 800-1600 | 提高并发能力 |
| **max-mutating-requests-inflight** | 200 | 400-800 | 提高变更并发 |
| **watch-cache-sizes** | 自动 | 手动调整 | 优化Watch性能 |
| **default-watch-cache-size** | 100 | 500 | 默认缓存大小 |
| **delete-collection-workers** | 1 | 4 | 加速批量删除 |
| **enable-priority-and-fairness** | true | true | 请求优先级 |

## kubelet性能调优

| 调优项 | 默认值 | 优化值 | 效果 |
|-------|-------|-------|------|
| **max-pods** | 110 | 110-250 | 增加Pod密度 |
| **serialize-image-pulls** | true | false | 并行拉取镜像 |
| **registry-qps** | 5 | 20 | 提高镜像拉取速度 |
| **registry-burst** | 10 | 40 | 突发拉取能力 |
| **event-qps** | 5 | 50 | 事件发送速度 |
| **event-burst** | 10 | 100 | 事件突发能力 |
| **kube-api-qps** | 5 | 50 | API请求速度 |
| **kube-api-burst** | 10 | 100 | API突发能力 |

## 调度器性能调优

| 调优项 | 默认值 | 优化值 | 效果 | 版本支持 |
|-------|-------|-------|------|---------|
| **percentageOfNodesToScore** | 0(自动) | 根据集群调整 | 减少评分节点数 | 稳定 |
| **parallelism** | 16 | 16-32 | 并行调度 | v1.25+ |
| **podInitialBackoffSeconds** | 1 | 1 | 初始退避 | 稳定 |
| **podMaxBackoffSeconds** | 10 | 10 | 最大退避 | 稳定 |

## 性能测试基准

| 场景 | 指标 | 良好 | 需优化 | 测试方法 |
|-----|------|------|-------|---------|
| **API延迟** | P99 | <1s | >2s | 监控apiserver指标 |
| **Pod启动时间** | P99 | <10s | >30s | 测试新Pod创建 |
| **调度延迟** | P99 | <5s | >15s | 监控scheduler指标 |
| **etcd写延迟** | P99 | <10ms | >25ms | 监控etcd指标 |
| **Watch延迟** | P99 | <100ms | >500ms | 监控watch指标 |
| **DNS查询** | P99 | <10ms | >100ms | DNS测试 |

## ACK性能优化

| 优化项 | ACK配置方式 | 效果 |
|-------|------------|------|
| **Terway CNI** | 创建时选择 | ENI直通，低延迟 |
| **托管控制平面** | Pro版 | 自动优化 |
| **节点池** | 按需配置 | 异构资源 |
| **弹性伸缩** | ESS集成 | 快速扩缩容 |
| **云盘ESSD** | StorageClass配置 | 高IOPS |

---

**性能原则**: 先监控，后优化，持续调整
