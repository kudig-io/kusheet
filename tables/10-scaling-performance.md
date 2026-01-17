# 表格10：扩展和性能表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/setup/best-practices/cluster-large](https://kubernetes.io/docs/setup/best-practices/cluster-large/)

## 集群规模架构

```
集群规模分级与架构选择:
┌─────────────────────────────────────────────────────────────────────────────┐
│  规模分级              节点数        Pod数          推荐架构                │
│  ├─ 小型集群          <50          <1,000         单Master/托管版          │
│  ├─ 中型集群          50-200       1k-10k         3 Master HA             │
│  ├─ 大型集群          200-1000     10k-50k        3-5 Master HA           │
│  └─ 超大型集群        1000+        50k+           多集群联邦/分片          │
│                                                                             │
│  关键瓶颈点:                                                                │
│  ├─ etcd: 存储容量、写入延迟、Watch压力                                     │
│  ├─ API Server: 请求并发、Watch连接数                                       │
│  ├─ Scheduler: 调度延迟、队列深度                                           │
│  ├─ Controller: 控制器队列、同步延迟                                        │
│  └─ kube-proxy: Service数量、规则同步                                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 集群规模限制(官方测试)

| 维度 | 官方上限 | 生产推荐值 | 限制因素 | 版本改进 | 突破方法 |
|-----|---------|----------|---------|---------|---------|
| **节点数** | 5000 | 1000-3000 | etcd/apiserver性能 | v1.28+优化 | 多集群联邦 |
| **Pod数/集群** | 150,000 | 100,000 | apiserver/etcd内存 | v1.27+优化 | 分集群部署 |
| **Pod数/节点** | 110(默认) | 110-250 | kubelet/CIDR | 可配置max-pods | 调整CIDR |
| **Service数** | 10,000 | 5,000 | kube-proxy规则 | IPVS模式 | 使用IPVS |
| **Endpoints/Service** | 5,000 | 1,000 | Endpoints对象大小 | EndpointSlice | 自动使用 |
| **Namespace数** | 10,000 | 1,000 | API对象数 | 稳定 | 合理规划 |
| **ConfigMap/Secret大小** | 1MB | 256KB | etcd单对象限制 | 稳定 | 拆分/外部存储 |
| **etcd数据库大小** | 8GB(默认) | 8GB | 配额限制 | 可调整 | 增加quota |
| **API QPS** | 取决于配置 | 500-1000 | apiserver限流 | APF | 调整限流 |
| **单NS资源数** | 无硬限制 | <10,000 | 列表查询性能 | 稳定 | 分散资源 |

## HPA (Horizontal Pod Autoscaler) 完整配置

### HPA v2配置参数

| 参数 | 默认值 | 推荐值 | 说明 | 版本支持 |
|-----|-------|-------|------|---------|
| **minReplicas** | 1 | >=2 | 最小副本数 | 稳定 |
| **maxReplicas** | 无 | 根据资源 | 最大副本数 | 稳定 |
| **targetCPUUtilization** | 无 | 50-70% | CPU目标使用率 | 稳定 |
| **targetMemoryUtilization** | 无 | 60-80% | 内存目标使用率 | 稳定 |
| **scaleDown.stabilizationWindowSeconds** | 300 | 300-600 | 缩容稳定窗口 | v1.23+ |
| **scaleUp.stabilizationWindowSeconds** | 0 | 0-60 | 扩容稳定窗口 | v1.23+ |
| **scaleDown.policies.type** | - | Percent/Pods | 缩容策略类型 | v1.23+ |
| **scaleUp.policies.type** | - | Percent/Pods | 扩容策略类型 | v1.23+ |

### HPA生产配置示例

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: production-app-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: production-app
  minReplicas: 3
  maxReplicas: 100
  
  # 多指标扩缩容
  metrics:
  # CPU利用率
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  
  # 内存利用率
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
  
  # 自定义指标 (需要Prometheus Adapter)
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"
  
  # 外部指标 (如消息队列长度)
  - type: External
    external:
      metric:
        name: queue_messages_ready
        selector:
          matchLabels:
            queue: "orders"
      target:
        type: AverageValue
        averageValue: "50"
  
  # 扩缩容行为控制
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300    # 5分钟稳定窗口防止抖动
      policies:
      - type: Percent
        value: 10                         # 每次最多缩10%
        periodSeconds: 60
      - type: Pods
        value: 2                          # 或每次最多缩2个Pod
        periodSeconds: 60
      selectPolicy: Min                   # 选择最保守的策略
    scaleUp:
      stabilizationWindowSeconds: 0       # 立即响应扩容
      policies:
      - type: Percent
        value: 100                        # 可翻倍扩容
        periodSeconds: 15
      - type: Pods
        value: 4                          # 或每15秒最多扩4个Pod
        periodSeconds: 15
      selectPolicy: Max                   # 选择最激进的策略
```

### HPA自定义指标配置 (Prometheus Adapter)

```yaml
# Prometheus Adapter配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: adapter-config
  namespace: monitoring
data:
  config.yaml: |
    rules:
    # HTTP请求速率
    - seriesQuery: 'http_requests_total{namespace!="",pod!=""}'
      resources:
        overrides:
          namespace: {resource: "namespace"}
          pod: {resource: "pod"}
      name:
        matches: "^(.*)_total$"
        as: "${1}_per_second"
      metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[2m])) by (<<.GroupBy>>)'
    
    # 自定义业务指标
    - seriesQuery: 'app_queue_length{namespace!="",pod!=""}'
      resources:
        overrides:
          namespace: {resource: "namespace"}
          pod: {resource: "pod"}
      name:
        matches: "^(.*)$"
        as: "${1}"
      metricsQuery: 'avg(<<.Series>>{<<.LabelMatchers>>}) by (<<.GroupBy>>)'
```

## VPA (Vertical Pod Autoscaler) 配置

### VPA模式对比

| 模式 | 行为 | 适用场景 | Pod重启 | 注意事项 |
|-----|------|---------|--------|---------|
| **Off** | 仅推荐，不更新 | 观察阶段 | 无 | 查看推荐值 |
| **Initial** | 仅创建时设置 | 新Pod使用推荐值 | 无 | 不影响运行中Pod |
| **Auto** | 自动更新Pod | 生产使用 | 会重启 | **会重启Pod** |
| **Recreate** | 与Auto相同 | 别名 | 会重启 | - |

### VPA配置示例

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: production-app-vpa
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: production-app
  updatePolicy:
    updateMode: "Auto"                    # Off/Initial/Auto
    minReplicas: 2                        # 保持最少2个副本
  resourcePolicy:
    containerPolicies:
    - containerName: app
      minAllowed:
        cpu: "100m"
        memory: "128Mi"
      maxAllowed:
        cpu: "4"
        memory: "8Gi"
      controlledResources: ["cpu", "memory"]
      controlledValues: RequestsAndLimits  # RequestsOnly/RequestsAndLimits
    - containerName: sidecar
      mode: "Off"                         # 不自动调整sidecar
```

### VPA与HPA共存注意事项

```yaml
# VPA和HPA可以共存，但需要注意:
# 1. VPA不能控制HPA使用的相同资源(如CPU)
# 2. 推荐配置:
#    - HPA: 基于CPU/自定义指标扩缩Pod数量
#    - VPA: 仅调整内存(controlledResources: ["memory"])

apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: app
      controlledResources: ["memory"]     # 仅控制内存，CPU由HPA管理
      minAllowed:
        memory: "256Mi"
      maxAllowed:
        memory: "4Gi"
```

## Cluster Autoscaler 配置

### CA参数详解

| 参数 | 默认值 | 推荐值 | 说明 |
|-----|-------|-------|------|
| `--scan-interval` | 10s | 10-30s | 扫描间隔 |
| `--scale-down-delay-after-add` | 10m | 10m | 扩容后缩容延迟 |
| `--scale-down-delay-after-delete` | 0s | 0s | 删除后缩容延迟 |
| `--scale-down-delay-after-failure` | 3m | 3m | 失败后缩容延迟 |
| `--scale-down-unneeded-time` | 10m | 10m | 空闲节点等待时间 |
| `--scale-down-utilization-threshold` | 0.5 | 0.5-0.7 | 缩容利用率阈值 |
| `--max-node-provision-time` | 15m | 15m | 最大供应时间 |
| `--max-graceful-termination-sec` | 600 | 600 | 优雅终止时间 |
| `--expander` | random | least-waste | 扩容选择策略 |
| `--balance-similar-node-groups` | false | true | 平衡节点组 |
| `--skip-nodes-with-local-storage` | true | true | 跳过本地存储节点 |
| `--skip-nodes-with-system-pods` | true | true | 跳过系统Pod节点 |

### CA Expander策略对比

| 策略 | 说明 | 适用场景 |
|-----|------|---------|
| **random** | 随机选择节点组 | 节点组相似 |
| **least-waste** | 选择浪费最少的 | 优化资源利用 |
| **most-pods** | 选择能容纳最多Pod的 | 快速扩容 |
| **priority** | 按优先级选择 | 混合实例类型 |
| **grpc** | 自定义gRPC服务 | 复杂调度需求 |

### CA配置示例

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-autoscaler-config
  namespace: kube-system
data:
  # 节点组配置
  node-groups: |
    - name: general-pool
      minSize: 3
      maxSize: 100
      
    - name: gpu-pool
      minSize: 0
      maxSize: 10
      
    - name: spot-pool
      minSize: 0
      maxSize: 50
      
  # 扩容优先级配置
  expander-priorities: |
    100:
      - spot-pool       # 优先使用Spot实例
    50:
      - general-pool    # 其次使用通用节点
    10:
      - gpu-pool        # 最后使用GPU节点
```

## etcd性能调优

### etcd关键参数

| 调优项 | 默认值 | 优化值 | 效果 | 注意事项 |
|-------|-------|-------|------|---------|
| **quota-backend-bytes** | 2GB | 8GB | 增加存储容量 | 需要更多内存 |
| **auto-compaction-mode** | periodic | revision | 更精确的压缩 | - |
| **auto-compaction-retention** | 0 | 1000(revision) | 减少存储增长 | 平衡历史和空间 |
| **snapshot-count** | 100000 | 10000 | 更频繁快照 | 更快恢复 |
| **heartbeat-interval** | 100ms | 100ms | 心跳频率 | 低延迟网络 |
| **election-timeout** | 1000ms | 1000ms | 选举超时 | >=5x心跳 |

### etcd硬件要求

| 集群规模 | CPU | 内存 | 磁盘类型 | IOPS | 网络 |
|---------|-----|------|---------|------|------|
| **小型(<50节点)** | 2核 | 4GB | SSD | 1000+ | 1Gbps |
| **中型(50-200)** | 4核 | 8GB | SSD | 3000+ | 1Gbps |
| **大型(200-1000)** | 8核 | 16GB | NVMe | 5000+ | 10Gbps |
| **超大型(1000+)** | 16核 | 32GB | NVMe | 10000+ | 10Gbps |

### etcd维护脚本

```bash
#!/bin/bash
# etcd健康检查和维护

ENDPOINTS="https://127.0.0.1:2379"
CACERT="/etc/kubernetes/pki/etcd/ca.crt"
CERT="/etc/kubernetes/pki/etcd/server.crt"
KEY="/etc/kubernetes/pki/etcd/server.key"

# 健康检查
echo "=== etcd健康状态 ==="
etcdctl --endpoints=$ENDPOINTS --cacert=$CACERT --cert=$CERT --key=$KEY endpoint health

# 成员状态
echo -e "\n=== 成员状态 ==="
etcdctl --endpoints=$ENDPOINTS --cacert=$CACERT --cert=$CERT --key=$KEY endpoint status -w table

# 数据库大小
echo -e "\n=== 数据库大小 ==="
etcdctl --endpoints=$ENDPOINTS --cacert=$CACERT --cert=$CERT --key=$KEY endpoint status -w json | jq '.[].Status.dbSize'

# 检查碎片率
echo -e "\n=== 碎片率检查 ==="
DB_SIZE=$(etcdctl --endpoints=$ENDPOINTS --cacert=$CACERT --cert=$CERT --key=$KEY endpoint status -w json | jq -r '.[0].Status.dbSize')
DB_SIZE_IN_USE=$(etcdctl --endpoints=$ENDPOINTS --cacert=$CACERT --cert=$CERT --key=$KEY endpoint status -w json | jq -r '.[0].Status.dbSizeInUse')
FRAG_RATIO=$(echo "scale=2; ($DB_SIZE - $DB_SIZE_IN_USE) / $DB_SIZE * 100" | bc)
echo "碎片率: ${FRAG_RATIO}%"

# 如果碎片率超过50%，执行压缩和碎片整理
if (( $(echo "$FRAG_RATIO > 50" | bc -l) )); then
    echo -e "\n=== 执行碎片整理 ==="
    # 获取当前revision
    REV=$(etcdctl --endpoints=$ENDPOINTS --cacert=$CACERT --cert=$CERT --key=$KEY endpoint status -w json | jq -r '.[0].Status.header.revision')
    # 压缩
    etcdctl --endpoints=$ENDPOINTS --cacert=$CACERT --cert=$CERT --key=$KEY compact $REV
    # 碎片整理(每个节点单独执行)
    etcdctl --endpoints=$ENDPOINTS --cacert=$CACERT --cert=$CERT --key=$KEY defrag
fi

# 创建快照备份
echo -e "\n=== 创建备份 ==="
BACKUP_DIR="/var/backup/etcd"
mkdir -p $BACKUP_DIR
etcdctl --endpoints=$ENDPOINTS --cacert=$CACERT --cert=$CERT --key=$KEY snapshot save $BACKUP_DIR/snapshot-$(date +%Y%m%d-%H%M%S).db
echo "备份完成: $BACKUP_DIR"
```

## API Server性能调优

| 调优项 | 默认值 | 大集群推荐值 | 效果 |
|-------|-------|------------|------|
| **max-requests-inflight** | 400 | 800-1600 | 提高非变更请求并发 |
| **max-mutating-requests-inflight** | 200 | 400-800 | 提高变更请求并发 |
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
| **pods-per-core** | 0 | 按需 | 每核Pod数限制 |

## 调度器性能调优

| 调优项 | 默认值 | 优化值 | 效果 |
|-------|-------|-------|------|
| **percentageOfNodesToScore** | 0(自动) | 50(大集群) | 减少评分节点数 |
| **parallelism** | 16 | 16-32 | 并行调度 |
| **podInitialBackoffSeconds** | 1 | 1 | 初始退避 |
| **podMaxBackoffSeconds** | 10 | 10 | 最大退避 |

## 性能测试基准

| 场景 | 指标 | 良好 | 需优化 | 测试方法 |
|-----|------|------|-------|---------|
| **API延迟** | P99 | <1s | >2s | `apiserver_request_duration_seconds` |
| **Pod启动时间** | P99 | <10s | >30s | 测试新Pod创建 |
| **调度延迟** | P99 | <5s | >15s | `scheduler_pod_scheduling_duration_seconds` |
| **etcd写延迟** | P99 | <10ms | >25ms | `etcd_disk_wal_fsync_duration_seconds` |
| **Watch延迟** | P99 | <100ms | >500ms | 监控watch指标 |
| **DNS查询** | P99 | <10ms | >100ms | DNS压测 |

### 性能测试工具

```bash
# Kubernetes性能测试套件
# 1. 安装perf-tests
git clone https://github.com/kubernetes/perf-tests.git
cd perf-tests/clusterloader2

# 2. 运行负载测试
go run cmd/clusterloader.go --testconfig=testing/load/config.yaml \
  --provider=local \
  --kubeconfig=$HOME/.kube/config \
  --report-dir=./reports

# 3. API Server压测
# 安装k6或locust进行HTTP压测
# 示例k6脚本
# k6 run api-load-test.js

# 4. 调度性能测试
kubectl create -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: scheduler-load-test
spec:
  parallelism: 100
  completions: 1000
  template:
    spec:
      containers:
      - name: test
        image: busybox
        command: ["sleep", "10"]
      restartPolicy: Never
EOF

# 观察调度延迟
kubectl get --raw /metrics | grep scheduler_pod_scheduling_duration_seconds
```

## ACK性能优化

| 优化项 | ACK配置方式 | 效果 |
|-------|------------|------|
| **Terway CNI** | 创建时选择 | ENI直通，低延迟 |
| **托管控制平面** | Pro版 | 自动优化 |
| **节点池** | 按需配置 | 异构资源 |
| **弹性伸缩** | ESS集成 | 快速扩缩容 |
| **云盘ESSD** | StorageClass配置 | 高IOPS |
| **IPVS模式** | 创建时选择 | 大规模Service |
| **NodeLocal DNSCache** | 组件安装 | DNS加速 |

---

**性能原则**: 
1. 监控先行，数据驱动优化
2. 单次调整一个参数
3. 在staging环境验证
4. 保持参数变更记录
5. 考虑成本与性能平衡
