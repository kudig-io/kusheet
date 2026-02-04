# 10 - 扩展和性能表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/setup/best-practices/cluster-large](https://kubernetes.io/docs/setup/best-practices/cluster-large/)

## 集群规模架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Kubernetes 集群规模限制与优化                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     集群规模层次                                     │  │
│   │                                                                      │  │
│   │   小型集群 (< 100节点)                                               │  │
│   │   ├── 单etcd实例可满足                                              │  │
│   │   ├── 默认配置即可                                                   │  │
│   │   └── 适合: 开发/测试/小型生产                                       │  │
│   │                                                                      │  │
│   │   中型集群 (100-500节点)                                             │  │
│   │   ├── etcd 3节点集群                                                │  │
│   │   ├── 需要调优API Server                                            │  │
│   │   └── 适合: 中型生产环境                                             │  │
│   │                                                                      │  │
│   │   大型集群 (500-2000节点)                                            │  │
│   │   ├── etcd 5节点集群 + SSD                                          │  │
│   │   ├── 多API Server实例                                              │  │
│   │   ├── 需要全面调优                                                   │  │
│   │   └── 适合: 大型生产环境                                             │  │
│   │                                                                      │  │
│   │   超大型集群 (2000-5000节点)                                         │  │
│   │   ├── 专用etcd集群 + NVMe                                           │  │
│   │   ├── API Server负载均衡                                            │  │
│   │   ├── 考虑多集群联邦                                                 │  │
│   │   └── 适合: 超大规模场景                                             │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     自动扩缩容架构                                    │  │
│   │                                                                      │  │
│   │            ┌─────────────┐                                          │  │
│   │            │   Metrics   │                                          │  │
│   │            │   Server    │                                          │  │
│   │            └──────┬──────┘                                          │  │
│   │                   │                                                  │  │
│   │    ┌──────────────┼──────────────┐                                  │  │
│   │    ▼              ▼              ▼                                  │  │
│   │ ┌──────┐     ┌──────┐     ┌──────────────┐                         │  │
│   │ │ HPA  │     │ VPA  │     │   Cluster    │                         │  │
│   │ │      │     │      │     │  Autoscaler  │                         │  │
│   │ └──┬───┘     └──┬───┘     └──────┬───────┘                         │  │
│   │    │            │                │                                  │  │
│   │    ▼            ▼                ▼                                  │  │
│   │ ┌──────────────────────────────────────────┐                       │  │
│   │ │              Workloads                    │                       │  │
│   │ │  Deployment  StatefulSet  DaemonSet      │                       │  │
│   │ └──────────────────────────────────────────┘                       │  │
│   │                   │                                                  │  │
│   │                   ▼                                                  │  │
│   │ ┌──────────────────────────────────────────┐                       │  │
│   │ │              Node Pool                    │                       │  │
│   │ │  Worker Nodes (auto-scaling)             │                       │  │
│   │ └──────────────────────────────────────────┘                       │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

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
| **容器数/Pod** | 无硬限制 | <10 | Pod规格/网络 | 稳定 | Sidecar优化 |
| **Watch连接数** | 取决于配置 | <50000 | apiserver内存 | v1.27+优化 | 调整缓存 |

### 规模限制计算公式

```
# Pod CIDR规划
每节点最大Pod数 = 2^(32 - podCIDR前缀) - 2
例: podCIDR /24 = 2^(32-24) - 2 = 254 Pods

# 集群CIDR规划
集群最大节点数 = 2^(clusterCIDR前缀 - podCIDR前缀)
例: clusterCIDR /16, podCIDR /24 = 2^(24-16) = 256 节点

# etcd存储估算
单个Pod对象 ≈ 1-2 KB
单个Service对象 ≈ 0.5-1 KB
100,000 Pods ≈ 100-200 MB etcd存储
```

## HPA (Horizontal Pod Autoscaler) 配置

### HPA参数详解

| 参数 | 默认值 | 推荐值 | 说明 | 版本支持 | 调优场景 |
|-----|-------|-------|------|---------|---------|
| **minReplicas** | 1 | >=2 | 最小副本数 | 稳定 | 保证高可用 |
| **maxReplicas** | 无 | 根据资源 | 最大副本数 | 稳定 | 防止资源耗尽 |
| **targetCPUUtilization** | 无 | 50-70% | CPU目标使用率 | 稳定 | 预留扩容空间 |
| **targetMemoryUtilization** | 无 | 60-80% | 内存目标使用率 | 稳定 | 内存敏感应用 |
| **scaleDown.stabilizationWindowSeconds** | 300 | 300-600 | 缩容稳定窗口 | v1.23+ | 防止频繁缩容 |
| **scaleUp.stabilizationWindowSeconds** | 0 | 0-60 | 扩容稳定窗口 | v1.23+ | 快速响应 |
| **scaleDown.policies** | - | 自定义 | 缩容策略 | v1.23+ | 平滑缩容 |
| **scaleUp.policies** | - | 自定义 | 扩容策略 | v1.23+ | 快速扩容 |

### HPA完整配置示例

```yaml
# hpa-complete-config.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
    
  # 副本数范围
  minReplicas: 3
  maxReplicas: 100
  
  # 多指标扩缩
  metrics:
  # CPU使用率
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
        
  # 内存使用率
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
        
  # 自定义指标 - QPS
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"
        
  # 外部指标 - 消息队列深度
  - type: External
    external:
      metric:
        name: queue_messages_ready
        selector:
          matchLabels:
            queue: "orders"
      target:
        type: Value
        value: "5000"
        
  # 容器级别指标(v1.27+)
  - type: ContainerResource
    containerResource:
      name: cpu
      container: app
      target:
        type: Utilization
        averageUtilization: 60
        
  # 扩缩容行为
  behavior:
    # 扩容行为
    scaleUp:
      stabilizationWindowSeconds: 0      # 立即扩容
      policies:
      # 每15秒最多扩容100%
      - type: Percent
        value: 100
        periodSeconds: 15
      # 每15秒最多扩容4个Pod
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max                   # 选择扩容更多的策略
      
    # 缩容行为
    scaleDown:
      stabilizationWindowSeconds: 300    # 5分钟稳定窗口
      policies:
      # 每60秒最多缩容10%
      - type: Percent
        value: 10
        periodSeconds: 60
      # 每60秒最多缩容2个Pod
      - type: Pods
        value: 2
        periodSeconds: 60
      selectPolicy: Min                   # 选择缩容更少的策略
```

### HPA自定义指标配置

```yaml
# prometheus-adapter配置
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
      
    # 消息队列深度
    - seriesQuery: 'rabbitmq_queue_messages_ready{namespace!="",queue!=""}'
      resources:
        overrides:
          namespace: {resource: "namespace"}
      name:
        matches: "^(.*)$"
        as: "${1}"
      metricsQuery: 'sum(<<.Series>>{<<.LabelMatchers>>}) by (<<.GroupBy>>)'

---
# 验证自定义指标
# kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1" | jq
# kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/default/pods/*/http_requests_per_second" | jq
```

### HPA故障排查

```bash
#!/bin/bash
# hpa-troubleshoot.sh

HPA_NAME=${1:-"app-hpa"}
NAMESPACE=${2:-"default"}

echo "====== HPA故障排查: $NAMESPACE/$HPA_NAME ======"

# 1. HPA状态
echo "=== 1. HPA状态 ==="
kubectl get hpa $HPA_NAME -n $NAMESPACE -o wide

# 2. HPA详情
echo -e "\n=== 2. HPA详情 ==="
kubectl describe hpa $HPA_NAME -n $NAMESPACE

# 3. 目标Deployment状态
echo -e "\n=== 3. 目标工作负载 ==="
TARGET=$(kubectl get hpa $HPA_NAME -n $NAMESPACE -o jsonpath='{.spec.scaleTargetRef.name}')
kubectl get deployment $TARGET -n $NAMESPACE

# 4. Metrics Server状态
echo -e "\n=== 4. Metrics Server ==="
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl top pods -n $NAMESPACE | head -10

# 5. 当前指标值
echo -e "\n=== 5. 当前指标 ==="
kubectl get hpa $HPA_NAME -n $NAMESPACE -o jsonpath='{.status.currentMetrics}' | jq

# 6. HPA事件
echo -e "\n=== 6. HPA事件 ==="
kubectl events -n $NAMESPACE --for="hpa/$HPA_NAME" | tail -20

# 7. 扩缩容历史
echo -e "\n=== 7. 最近扩缩容活动 ==="
kubectl get events -n $NAMESPACE --field-selector reason=SuccessfulRescale --sort-by='.lastTimestamp' | tail -10
```

## VPA (Vertical Pod Autoscaler) 配置

### VPA模式对比

| 模式 | 行为 | 适用场景 | 注意事项 | 推荐度 |
|-----|------|---------|---------|-------|
| **Off** | 仅推荐,不更新 | 观察阶段 | 查看推荐值 | 初期 |
| **Initial** | 仅创建时设置 | 新Pod使用推荐值 | 不影响运行中Pod | 过渡期 |
| **Auto** | 自动更新Pod | 生产使用 | 会重启Pod | 生产 |
| **Recreate** | 与Auto相同 | 别名 | - | - |

### VPA完整配置

```yaml
# vpa-complete-config.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: app-vpa
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
    
  # 更新策略
  updatePolicy:
    updateMode: "Auto"               # Off/Initial/Recreate/Auto
    minReplicas: 2                   # 最小保留副本数(v1.26+)
    
  # 资源策略
  resourcePolicy:
    containerPolicies:
    # 主应用容器
    - containerName: app
      minAllowed:
        cpu: "100m"
        memory: "128Mi"
      maxAllowed:
        cpu: "4"
        memory: "8Gi"
      controlledResources: ["cpu", "memory"]
      controlledValues: RequestsAndLimits  # RequestsOnly/RequestsAndLimits
      
    # Sidecar容器 - 不自动调整
    - containerName: sidecar
      mode: "Off"
      
  # 推荐器配置
  recommenders:
  - name: default
  
---
# VPA推荐模式(安全观察)
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: app-vpa-recommend
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  updatePolicy:
    updateMode: "Off"                # 仅推荐,不自动更新
  resourcePolicy:
    containerPolicies:
    - containerName: "*"
      minAllowed:
        cpu: "50m"
        memory: "64Mi"
      maxAllowed:
        cpu: "8"
        memory: "16Gi"
```

### 查看VPA推荐

```bash
#!/bin/bash
# vpa-recommendations.sh

echo "====== VPA推荐值查看 ======"

# 列出所有VPA
kubectl get vpa -A

# 获取详细推荐
for vpa in $(kubectl get vpa -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}'); do
    ns=$(echo $vpa | cut -d'/' -f1)
    name=$(echo $vpa | cut -d'/' -f2)
    echo -e "\n=== VPA: $vpa ==="
    kubectl get vpa $name -n $ns -o jsonpath='
Target: {.spec.targetRef.kind}/{.spec.targetRef.name}
Mode: {.spec.updatePolicy.updateMode}
Recommendations:
{range .status.recommendation.containerRecommendations[*]}
  Container: {.containerName}
    Lower Bound:  CPU={.lowerBound.cpu}, Memory={.lowerBound.memory}
    Target:       CPU={.target.cpu}, Memory={.target.memory}
    Upper Bound:  CPU={.upperBound.cpu}, Memory={.upperBound.memory}
    Uncapped:     CPU={.uncappedTarget.cpu}, Memory={.uncappedTarget.memory}
{end}'
    echo ""
done
```

## Cluster Autoscaler 配置

### CA参数详解

| 参数 | 默认值 | 推荐值 | 说明 | 版本支持 |
|-----|-------|-------|------|---------|
| **scan-interval** | 10s | 10-30s | 扫描间隔 | 稳定 |
| **scale-down-delay-after-add** | 10m | 10m | 扩容后缩容延迟 | 稳定 |
| **scale-down-delay-after-delete** | 0s | 0s | 删除后缩容延迟 | 稳定 |
| **scale-down-delay-after-failure** | 3m | 3m | 失败后缩容延迟 | 稳定 |
| **scale-down-unneeded-time** | 10m | 10m | 空闲节点等待时间 | 稳定 |
| **scale-down-unready-time** | 20m | 20m | NotReady节点等待 | 稳定 |
| **scale-down-utilization-threshold** | 0.5 | 0.5-0.7 | 缩容利用率阈值 | 稳定 |
| **max-node-provision-time** | 15m | 15m | 最大供应时间 | 稳定 |
| **max-graceful-termination-sec** | 600 | 600 | 优雅终止时间 | 稳定 |
| **expander** | random | least-waste | 扩容选择策略 | 稳定 |
| **skip-nodes-with-local-storage** | true | false | 跳过本地存储节点 | 稳定 |
| **skip-nodes-with-system-pods** | true | true | 跳过系统Pod节点 | 稳定 |
| **balance-similar-node-groups** | false | true | 平衡节点组 | 稳定 |

### Cluster Autoscaler部署

```yaml
# cluster-autoscaler-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      priorityClassName: system-cluster-critical
      containers:
      - name: cluster-autoscaler
        image: registry.k8s.io/autoscaling/cluster-autoscaler:v1.28.0
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --balance-similar-node-groups=true
        - --scale-down-delay-after-add=10m
        - --scale-down-unneeded-time=10m
        - --scale-down-utilization-threshold=0.5
        - --max-node-provision-time=15m
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/<cluster-name>
        resources:
          limits:
            cpu: 100m
            memory: 600Mi
          requests:
            cpu: 100m
            memory: 600Mi
        env:
        - name: AWS_REGION
          value: us-west-2

---
# RBAC配置
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-autoscaler
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-autoscaler
rules:
- apiGroups: [""]
  resources: ["events", "endpoints"]
  verbs: ["create", "patch"]
- apiGroups: [""]
  resources: ["pods/eviction"]
  verbs: ["create"]
- apiGroups: [""]
  resources: ["pods/status"]
  verbs: ["update"]
- apiGroups: [""]
  resources: ["endpoints"]
  resourceNames: ["cluster-autoscaler"]
  verbs: ["get", "update"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["watch", "list", "get", "update"]
- apiGroups: [""]
  resources: ["namespaces", "pods", "services", "replicationcontrollers", "persistentvolumeclaims", "persistentvolumes"]
  verbs: ["watch", "list", "get"]
- apiGroups: ["extensions"]
  resources: ["replicasets", "daemonsets"]
  verbs: ["watch", "list", "get"]
- apiGroups: ["policy"]
  resources: ["poddisruptionbudgets"]
  verbs: ["watch", "list"]
- apiGroups: ["apps"]
  resources: ["statefulsets", "replicasets", "daemonsets"]
  verbs: ["watch", "list", "get"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses", "csinodes", "csidrivers", "csistoragecapacities"]
  verbs: ["watch", "list", "get"]
- apiGroups: ["batch", "extensions"]
  resources: ["jobs"]
  verbs: ["get", "list", "watch", "patch"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["create"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  resourceNames: ["cluster-autoscaler"]
  verbs: ["get", "update"]
```

### Expander策略对比

| 策略 | 说明 | 适用场景 | 优缺点 |
|-----|------|---------|-------|
| **random** | 随机选择节点组 | 通用 | 简单,但可能不优 |
| **most-pods** | 选择能调度最多Pod的组 | 快速调度 | 可能浪费资源 |
| **least-waste** | 选择资源浪费最少的组 | 成本优化 | 推荐生产使用 |
| **price** | 选择价格最低的组 | 成本敏感 | 需要云厂商支持 |
| **priority** | 按优先级选择 | 混合实例类型 | 需要配置优先级 |
| **grpc** | 外部gRPC服务决策 | 自定义逻辑 | 最灵活但复杂 |

```yaml
# priority expander配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-autoscaler-priority-expander
  namespace: kube-system
data:
  priorities: |
    10:
      - .*spot.*
    50:
      - .*on-demand.*
    100:
      - .*reserved.*
```

## etcd性能调优

### etcd调优参数

| 调优项 | 默认值 | 优化值 | 效果 | 注意事项 |
|-------|-------|-------|------|---------|
| **quota-backend-bytes** | 2GB | 8GB | 增加存储容量 | 需要更多内存 |
| **auto-compaction-mode** | periodic | revision | 更精确的压缩 | - |
| **auto-compaction-retention** | 0 | 1000(revision) | 减少存储增长 | 平衡历史和空间 |
| **snapshot-count** | 100000 | 10000 | 更频繁快照 | 更快恢复 |
| **heartbeat-interval** | 100ms | 100ms | 心跳频率 | 低延迟网络 |
| **election-timeout** | 1000ms | 1000ms | 选举超时 | >=5x心跳 |
| **max-request-bytes** | 1.5MB | 10MB | 单请求大小 | 大对象支持 |
| **max-txn-ops** | 128 | 256 | 事务操作数 | 批量操作 |

### etcd配置示例

```yaml
# etcd启动参数(kubeadm)
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
etcd:
  local:
    extraArgs:
      quota-backend-bytes: "8589934592"        # 8GB
      auto-compaction-mode: "revision"
      auto-compaction-retention: "1000"
      snapshot-count: "10000"
      max-request-bytes: "10485760"            # 10MB
      # 性能调优
      heartbeat-interval: "100"
      election-timeout: "1000"
      # 日志级别
      log-level: "warn"
    extraVolumes:
    - name: etcd-data
      hostPath: /var/lib/etcd
      mountPath: /var/lib/etcd
      pathType: DirectoryOrCreate

---
# etcd监控指标检查
# etcdctl endpoint status --cluster -w table
# etcdctl endpoint health --cluster
# etcdctl check perf
```

### etcd磁盘要求

| 集群规模 | 磁盘类型 | IOPS要求 | 写延迟要求 | 磁盘大小 |
|---------|---------|---------|----------|---------|
| <100节点 | SSD | >1000 | <10ms | 20GB |
| 100-500节点 | SSD | >3000 | <5ms | 50GB |
| 500-2000节点 | NVMe SSD | >5000 | <2ms | 100GB |
| >2000节点 | NVMe SSD | >10000 | <1ms | 200GB |

## API Server性能调优

### API Server参数

| 调优项 | 默认值 | 大集群推荐值 | 效果 | 适用场景 |
|-------|-------|------------|------|---------|
| **max-requests-inflight** | 400 | 800-1600 | 提高并发能力 | 高负载 |
| **max-mutating-requests-inflight** | 200 | 400-800 | 提高变更并发 | 频繁更新 |
| **watch-cache-sizes** | 自动 | 手动调整 | 优化Watch性能 | 大量Watch |
| **default-watch-cache-size** | 100 | 500 | 默认缓存大小 | 通用 |
| **delete-collection-workers** | 1 | 4 | 加速批量删除 | 大量删除 |
| **enable-priority-and-fairness** | true | true | 请求优先级 | 所有环境 |
| **request-timeout** | 60s | 60s | 请求超时 | 保持默认 |
| **min-request-timeout** | 1800s | 1800s | Watch最小超时 | 保持默认 |

### API Server配置示例

```yaml
# kube-apiserver配置(kubeadm)
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
apiServer:
  extraArgs:
    # 请求限流
    max-requests-inflight: "1600"
    max-mutating-requests-inflight: "800"
    # Watch缓存
    default-watch-cache-size: "500"
    watch-cache-sizes: "pods#1000,nodes#500,services#500"
    # 删除优化
    delete-collection-workers: "4"
    # 审计日志
    audit-log-maxage: "7"
    audit-log-maxbackup: "3"
    audit-log-maxsize: "100"
    # API优先级和公平性
    enable-priority-and-fairness: "true"
    # 性能
    profiling: "false"
    
  # 资源配置
  extraVolumes:
  - name: audit-logs
    hostPath: /var/log/kubernetes/audit
    mountPath: /var/log/kubernetes/audit
    pathType: DirectoryOrCreate
```

### API Priority and Fairness配置

```yaml
# 高优先级FlowSchema
apiVersion: flowcontrol.apiserver.k8s.io/v1beta3
kind: FlowSchema
metadata:
  name: critical-workloads
spec:
  priorityLevelConfiguration:
    name: workload-high
  matchingPrecedence: 500
  distinguisherMethod:
    type: ByUser
  rules:
  - subjects:
    - kind: ServiceAccount
      serviceAccount:
        name: critical-app
        namespace: production
    resourceRules:
    - verbs: ["*"]
      apiGroups: ["*"]
      resources: ["*"]
      namespaces: ["production"]

---
# 高优先级PriorityLevel
apiVersion: flowcontrol.apiserver.k8s.io/v1beta3
kind: PriorityLevelConfiguration
metadata:
  name: workload-high
spec:
  type: Limited
  limited:
    nominalConcurrencyShares: 100
    limitResponse:
      type: Queue
      queuing:
        queues: 64
        handSize: 8
        queueLengthLimit: 50
    lendablePercent: 25
    borrowingLimitPercent: 25
```

## kubelet性能调优

### kubelet参数

| 调优项 | 默认值 | 优化值 | 效果 | 场景 |
|-------|-------|-------|------|-----|
| **max-pods** | 110 | 110-250 | 增加Pod密度 | 高密度部署 |
| **serialize-image-pulls** | true | false | 并行拉取镜像 | 快速部署 |
| **registry-qps** | 5 | 20 | 提高镜像拉取速度 | 快速部署 |
| **registry-burst** | 10 | 40 | 突发拉取能力 | 快速部署 |
| **event-qps** | 5 | 50 | 事件发送速度 | 事件密集 |
| **event-burst** | 10 | 100 | 事件突发能力 | 事件密集 |
| **kube-api-qps** | 50 | 100 | API请求速度 | 高负载 |
| **kube-api-burst** | 100 | 200 | API突发能力 | 高负载 |
| **pods-per-core** | 0 | 10 | 每核心Pod数 | 资源控制 |
| **image-gc-high-threshold** | 85 | 80 | 镜像GC高阈值 | 磁盘管理 |
| **image-gc-low-threshold** | 80 | 70 | 镜像GC低阈值 | 磁盘管理 |

### kubelet配置示例

```yaml
# /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

# Pod限制
maxPods: 250
podsPerCore: 10

# 镜像拉取
serializeImagePulls: false
registryPullQPS: 20
registryBurst: 40

# 事件
eventRecordQPS: 50
eventBurst: 100

# API请求
kubeAPIQPS: 100
kubeAPIBurst: 200

# 资源驱逐
evictionHard:
  memory.available: "100Mi"
  nodefs.available: "10%"
  nodefs.inodesFree: "5%"
  imagefs.available: "15%"
evictionSoft:
  memory.available: "200Mi"
  nodefs.available: "15%"
evictionSoftGracePeriod:
  memory.available: "1m"
  nodefs.available: "1m"
evictionPressureTransitionPeriod: 30s

# 镜像GC
imageGCHighThresholdPercent: 80
imageGCLowThresholdPercent: 70

# 系统预留
systemReserved:
  cpu: "500m"
  memory: "1Gi"
kubeReserved:
  cpu: "500m"
  memory: "1Gi"

# 日志
containerLogMaxSize: "50Mi"
containerLogMaxFiles: 5

# 特性门控
featureGates:
  RotateKubeletServerCertificate: true
  GracefulNodeShutdown: true
```

## 调度器性能调优

### Scheduler参数

| 调优项 | 默认值 | 优化值 | 效果 | 版本支持 |
|-------|-------|-------|------|---------|
| **percentageOfNodesToScore** | 0(自动) | 根据集群调整 | 减少评分节点数 | 稳定 |
| **parallelism** | 16 | 16-32 | 并行调度 | v1.25+ |
| **podInitialBackoffSeconds** | 1 | 1 | 初始退避 | 稳定 |
| **podMaxBackoffSeconds** | 10 | 10 | 最大退避 | 稳定 |

### 调度器配置

```yaml
# kube-scheduler-config.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration

# 并行度
parallelism: 32

# 百分比评分(大集群优化)
# 100节点以下: 100%
# 100-1000节点: 自动计算
# 1000节点以上: 考虑设置为50或更低
percentageOfNodesToScore: 50

# 调度队列
podInitialBackoffSeconds: 1
podMaxBackoffSeconds: 10

# Leader选举
leaderElection:
  leaderElect: true
  leaseDuration: 15s
  renewDeadline: 10s
  retryPeriod: 2s

# 调度配置文件
profiles:
- schedulerName: default-scheduler
  plugins:
    # 启用/禁用插件
    score:
      enabled:
      - name: NodeResourcesBalancedAllocation
        weight: 1
      - name: ImageLocality
        weight: 1
      - name: InterPodAffinity
        weight: 1
      - name: NodeResourcesFit
        weight: 1
      - name: NodeAffinity
        weight: 1
      - name: PodTopologySpread
        weight: 2
      disabled:
      - name: NodeResourcesLeastAllocated
```

## 性能测试基准

### 性能指标要求

| 场景 | 指标 | 良好 | 一般 | 需优化 | 测试方法 |
|-----|------|------|------|-------|---------|
| **API延迟** | P99 | <1s | <2s | >2s | 监控apiserver指标 |
| **Pod启动时间** | P99 | <10s | <20s | >30s | 测试新Pod创建 |
| **调度延迟** | P99 | <5s | <10s | >15s | 监控scheduler指标 |
| **etcd写延迟** | P99 | <10ms | <20ms | >25ms | 监控etcd指标 |
| **Watch延迟** | P99 | <100ms | <300ms | >500ms | 监控watch指标 |
| **DNS查询** | P99 | <10ms | <50ms | >100ms | DNS测试 |
| **Service响应** | P99 | <50ms | <100ms | >200ms | 端到端测试 |

### 性能测试脚本

```bash
#!/bin/bash
# k8s-performance-test.sh

echo "====== Kubernetes性能测试 ======"

# 1. API Server延迟测试
echo "=== 1. API Server延迟 ==="
for i in {1..10}; do
    time kubectl get pods -A &>/dev/null
done 2>&1 | grep real | awk '{print $2}'

# 2. Pod创建时间测试
echo -e "\n=== 2. Pod创建时间 ==="
START=$(date +%s.%N)
kubectl run perf-test-$RANDOM --image=nginx:alpine --restart=Never
kubectl wait --for=condition=Ready pod/perf-test-* --timeout=60s
END=$(date +%s.%N)
echo "Pod创建到Ready: $(echo "$END - $START" | bc)秒"
kubectl delete pod perf-test-* --force --grace-period=0 &>/dev/null

# 3. etcd性能(需要etcdctl)
echo -e "\n=== 3. etcd性能检查 ==="
if command -v etcdctl &>/dev/null; then
    etcdctl check perf 2>/dev/null || echo "需要etcd访问权限"
fi

# 4. DNS解析时间
echo -e "\n=== 4. DNS解析时间 ==="
kubectl run dns-test --image=busybox:1.36 --rm -it --restart=Never -- \
    time nslookup kubernetes.default.svc.cluster.local 2>/dev/null

# 5. 当前集群规模
echo -e "\n=== 5. 集群规模 ==="
echo "节点数: $(kubectl get nodes --no-headers | wc -l)"
echo "Pod数: $(kubectl get pods -A --no-headers | wc -l)"
echo "Service数: $(kubectl get svc -A --no-headers | wc -l)"
echo "Namespace数: $(kubectl get ns --no-headers | wc -l)"
```

### Prometheus监控查询

```yaml
# 性能监控指标
# API Server请求延迟
histogram_quantile(0.99, sum(rate(apiserver_request_duration_seconds_bucket{verb!="WATCH"}[5m])) by (verb, le))

# API Server请求QPS
sum(rate(apiserver_request_total[5m])) by (verb, resource)

# etcd请求延迟
histogram_quantile(0.99, sum(rate(etcd_request_duration_seconds_bucket[5m])) by (operation, le))

# 调度延迟
histogram_quantile(0.99, sum(rate(scheduler_e2e_scheduling_duration_seconds_bucket[5m])) by (le))

# Pod启动延迟
histogram_quantile(0.99, sum(rate(kubelet_pod_start_duration_seconds_bucket[5m])) by (le))

# Watch缓存命中率
sum(rate(apiserver_cache_list_fetched_objects_total[5m])) / sum(rate(apiserver_cache_list_total_objects_total[5m]))
```

## ACK性能优化

### ACK特有优化

| 优化项 | ACK配置方式 | 效果 | 适用场景 |
|-------|------------|------|---------|
| **Terway CNI** | 创建时选择 | ENI直通,低延迟 | 网络性能敏感 |
| **托管控制平面** | Pro版 | 自动优化 | 生产环境 |
| **节点池** | 按需配置 | 异构资源 | 混合负载 |
| **弹性伸缩** | ESS集成 | 快速扩缩容 | 弹性负载 |
| **云盘ESSD** | StorageClass配置 | 高IOPS | 存储密集 |
| **神龙裸金属** | 节点池选择 | 极致性能 | 高性能计算 |

```yaml
# ACK高性能节点池配置
apiVersion: v1
kind: NodePool
metadata:
  name: high-performance-pool
spec:
  instanceTypes:
  - ecs.g7.4xlarge
  - ecs.g7.8xlarge
  systemDiskCategory: cloud_essd
  systemDiskSize: 120
  systemDiskPerformanceLevel: PL1
  
  # 弹性伸缩
  scaling:
    enable: true
    minSize: 3
    maxSize: 100
    type: cpu                        # cpu/gpu/mem
    
  # kubelet配置
  kubeletConfiguration:
    maxPods: 200
    serializeImagePulls: false
    registryPullQPS: 20
    registryBurst: 40
    
  # 节点标签
  labels:
    node-type: high-performance
    
  # 节点污点
  taints:
  - key: dedicated
    value: high-performance
    effect: NoSchedule
```

## 版本变更记录

| 版本 | 变更内容 | 性能影响 |
|-----|---------|---------|
| v1.25 | Scheduler并行度可配置 | 调度性能提升 |
| v1.26 | IPVS模式改进 | Service性能提升 |
| v1.27 | Watch缓存优化 | API性能提升 |
| v1.28 | etcd优化 | 大集群支持 |
| v1.29 | 调度器优化 | 调度延迟降低 |
| v1.30 | API优先级增强 | 请求隔离改进 |

---

**性能原则**: 先监控 → 定位瓶颈 → 针对性优化 → 持续调整 → 回归验证

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)
