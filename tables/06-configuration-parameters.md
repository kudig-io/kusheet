# 表格6：配置参数表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/reference/command-line-tools-reference](https://kubernetes.io/docs/reference/command-line-tools-reference/)

## 参数调优原则

```
参数调优方法论:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  1. 基线评估 → 2. 监控指标 → 3. 识别瓶颈 → 4. 调整参数 → 5. 验证效果        │
│                                                                             │
│  关键原则:                                                                  │
│  • 每次只调整一个参数，观察效果                                              │
│  • 保持参数变更记录，便于回滚                                                │
│  • 在staging环境验证后再应用到生产                                           │
│  • 根据集群规模选择合适的参数范围                                            │
│                                                                             │
│  集群规模分级:                                                              │
│  ┌──────────┬──────────┬──────────┬───────────┐                            │
│  │   小型   │   中型   │   大型   │   超大型  │                            │
│  ├──────────┼──────────┼──────────┼───────────┤                            │
│  │ <50节点  │ 50-200   │ 200-1000 │ 1000+     │                            │
│  │ <1000Pod │ 1-5k Pod │ 5-50k Pod│ 50k+ Pod  │                            │
│  └──────────┴──────────┴──────────┴───────────┘                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

## kube-apiserver 关键参数

### 核心参数

| 参数 | 默认值 | 小型集群 | 中型集群 | 大型集群 | 说明 | 影响 |
|-----|-------|---------|---------|---------|------|------|
| `--etcd-servers` | 无 | 单节点 | 3节点 | 5节点 | etcd端点列表 | 必须配置 |
| `--service-cluster-ip-range` | 10.0.0.0/24 | /16 | /16 | /12 | Service IP范围 | 影响Service数量上限 |
| `--service-node-port-range` | 30000-32767 | 默认 | 默认 | 可扩展 | NodePort范围 | 避免端口冲突 |
| `--max-requests-inflight` | 400 | 400 | 800 | 1600 | 非变更并发请求 | 影响API吞吐量 |
| `--max-mutating-requests-inflight` | 200 | 200 | 400 | 800 | 变更并发请求 | 影响写入性能 |
| `--request-timeout` | 60s | 60s | 60s | 120s | 请求超时 | 复杂操作需延长 |
| `--default-watch-cache-size` | 100 | 100 | 200 | 500 | Watch缓存大小 | 影响内存使用 |
| `--delete-collection-workers` | 1 | 1 | 2 | 4 | 批量删除并发数 | 加速批量删除 |

### 安全参数

| 参数 | 默认值 | 推荐生产值 | 说明 | 安全影响 |
|-----|-------|----------|------|---------|
| `--authorization-mode` | AlwaysAllow | RBAC,Node | 授权模式 | **必须启用RBAC** |
| `--anonymous-auth` | true | false | 匿名认证 | 生产应禁用 |
| `--enable-admission-plugins` | 默认列表 | 见下文 | 准入控制插件 | 根据安全需求配置 |
| `--audit-log-path` | 无 | /var/log/audit.log | 审计日志路径 | **生产必须启用** |
| `--audit-log-maxage` | 0 | 30 | 日志保留天数 | 合规要求 |
| `--audit-log-maxbackup` | 0 | 10 | 日志备份数 | 存储管理 |
| `--audit-log-maxsize` | 0 | 100 | 单文件大小MB | 防止磁盘满 |
| `--encryption-provider-config` | 无 | 配置文件路径 | etcd加密 | 敏感数据保护 |
| `--profiling` | true | false | 性能分析端点 | 生产应禁用 |
| `--tls-min-version` | 无 | VersionTLS12 | 最低TLS版本 | 安全加固 |
| `--tls-cipher-suites` | 默认 | 安全套件列表 | TLS加密套件 | 禁用弱加密 |

### 推荐的准入控制插件

```bash
# 生产环境推荐启用的准入控制插件
--enable-admission-plugins=\
NamespaceLifecycle,\
LimitRanger,\
ServiceAccount,\
DefaultStorageClass,\
DefaultTolerationSeconds,\
MutatingAdmissionWebhook,\
ValidatingAdmissionWebhook,\
ResourceQuota,\
PodSecurity,\
NodeRestriction,\
Priority,\
RuntimeClass,\
TaintNodesByCondition

# v1.30+ 推荐添加
ValidatingAdmissionPolicy
```

### API优先级和公平性配置

```yaml
# FlowSchema示例 - 保护系统关键请求
apiVersion: flowcontrol.apiserver.k8s.io/v1
kind: FlowSchema
metadata:
  name: system-critical
spec:
  priorityLevelConfiguration:
    name: system
  matchingPrecedence: 100
  rules:
  - subjects:
    - kind: ServiceAccount
      serviceAccount:
        name: "*"
        namespace: kube-system
    resourceRules:
    - verbs: ["*"]
      apiGroups: ["*"]
      resources: ["*"]
---
# PriorityLevelConfiguration
apiVersion: flowcontrol.apiserver.k8s.io/v1
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
```

## etcd 关键参数

### 性能参数

| 参数 | 默认值 | SSD推荐 | NVMe推荐 | 说明 | 性能影响 |
|-----|-------|--------|---------|------|---------|
| `--quota-backend-bytes` | 2GB | 8GB | 8GB | 存储配额 | 大集群需增加 |
| `--snapshot-count` | 100000 | 10000 | 5000 | 快照触发事务数 | 影响恢复时间 |
| `--auto-compaction-mode` | periodic | revision | revision | 压缩模式 | revision更精确 |
| `--auto-compaction-retention` | 0 | 1000 | 1000 | 压缩保留 | 减少存储增长 |
| `--max-txn-ops` | 128 | 256 | 512 | 单事务最大操作 | 复杂操作需增加 |
| `--max-request-bytes` | 1.5MB | 10MB | 10MB | 最大请求大小 | 大ConfigMap需要 |
| `--heartbeat-interval` | 100ms | 100ms | 50ms | 心跳间隔 | 低延迟网络可减少 |
| `--election-timeout` | 1000ms | 1000ms | 500ms | 选举超时 | >=5倍心跳 |

### etcd集群配置示例

```yaml
# etcd静态Pod配置关键参数
apiVersion: v1
kind: Pod
metadata:
  name: etcd
  namespace: kube-system
spec:
  containers:
  - name: etcd
    image: registry.k8s.io/etcd:3.5.12-0
    command:
    - etcd
    # 成员配置
    - --name=$(NODE_NAME)
    - --data-dir=/var/lib/etcd
    - --listen-peer-urls=https://$(POD_IP):2380
    - --listen-client-urls=https://$(POD_IP):2379,https://127.0.0.1:2379
    - --advertise-client-urls=https://$(POD_IP):2379
    - --initial-advertise-peer-urls=https://$(POD_IP):2380
    - --initial-cluster=master1=https://10.0.0.1:2380,master2=https://10.0.0.2:2380,master3=https://10.0.0.3:2380
    - --initial-cluster-state=new
    - --initial-cluster-token=etcd-cluster-token
    
    # 性能调优
    - --quota-backend-bytes=8589934592           # 8GB
    - --snapshot-count=10000
    - --auto-compaction-mode=revision
    - --auto-compaction-retention=1000
    - --max-txn-ops=256
    - --max-request-bytes=10485760               # 10MB
    
    # TLS配置
    - --cert-file=/etc/kubernetes/pki/etcd/server.crt
    - --key-file=/etc/kubernetes/pki/etcd/server.key
    - --client-cert-auth=true
    - --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
    - --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt
    - --peer-key-file=/etc/kubernetes/pki/etcd/peer.key
    - --peer-client-cert-auth=true
    - --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
    
    # 加密套件(安全加固)
    - --cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
    
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 2000m
        memory: 4Gi
    volumeMounts:
    - name: etcd-data
      mountPath: /var/lib/etcd
    - name: etcd-certs
      mountPath: /etc/kubernetes/pki/etcd
```

## kube-scheduler 关键参数

| 参数 | 默认值 | 小型集群 | 大型集群 | 说明 | 影响 |
|-----|-------|---------|---------|------|------|
| `--config` | 无 | 推荐使用 | 必须使用 | 配置文件路径 | 高级调度配置 |
| `--leader-elect` | true | true | true | 领导选举 | HA必需 |
| `--leader-elect-lease-duration` | 15s | 15s | 15s | 租约时长 | 影响故障切换 |
| `--leader-elect-renew-deadline` | 10s | 10s | 10s | 续租期限 | 小于租约时长 |
| `--kube-api-qps` | 50 | 50 | 200 | API请求QPS | 大集群需增加 |
| `--kube-api-burst` | 100 | 100 | 400 | API请求突发 | 大集群需增加 |
| `--profiling` | true | false | false | 性能分析 | 生产应禁用 |

### 调度器配置文件示例

```yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: /etc/kubernetes/scheduler.conf
  qps: 200
  burst: 400

leaderElection:
  leaderElect: true
  leaseDuration: 15s
  renewDeadline: 10s
  retryPeriod: 2s

profiles:
- schedulerName: default-scheduler
  percentageOfNodesToScore: 50         # 大集群减少评分节点比例
  
  plugins:
    # 启用调度门控(v1.30+ GA)
    preEnqueue:
      enabled:
      - name: SchedulingGates
    
    # 过滤插件
    filter:
      enabled:
      - name: NodeUnschedulable
      - name: NodeName
      - name: TaintToleration
      - name: NodeAffinity
      - name: NodePorts
      - name: NodeResourcesFit
      - name: VolumeBinding
      - name: VolumeZone
      - name: PodTopologySpread
      - name: InterPodAffinity
    
    # 评分插件
    score:
      enabled:
      - name: NodeResourcesBalancedAllocation
        weight: 1
      - name: ImageLocality
        weight: 1
      - name: InterPodAffinity
        weight: 1
      - name: NodeAffinity
        weight: 1
      - name: PodTopologySpread
        weight: 2
      - name: TaintToleration
        weight: 1

  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: LeastAllocated           # 或 MostAllocated, RequestedToCapacityRatio
        resources:
        - name: cpu
          weight: 1
        - name: memory
          weight: 1

  - name: PodTopologySpread
    args:
      defaultingType: List
      defaultConstraints:
      - maxSkew: 3
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
      - maxSkew: 5
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway

# GPU调度专用配置(可选)
- schedulerName: gpu-scheduler
  plugins:
    filter:
      enabled:
      - name: NodeResourcesFit
    score:
      enabled:
      - name: NodeResourcesFit
        weight: 10
  pluginConfig:
  - name: NodeResourcesFit
    args:
      scoringStrategy:
        type: MostAllocated            # GPU节点优先填满
        resources:
        - name: nvidia.com/gpu
          weight: 10
```

## kube-controller-manager 关键参数

| 参数 | 默认值 | 小型集群 | 大型集群 | 说明 | 影响 |
|-----|-------|---------|---------|------|------|
| `--leader-elect` | true | true | true | 领导选举 | HA必需 |
| `--controllers` | * | * | 自定义 | 启用的控制器 | 可禁用不需要的 |
| `--concurrent-deployment-syncs` | 5 | 5 | 20 | Deployment并发 | 加速部署处理 |
| `--concurrent-replicaset-syncs` | 5 | 5 | 20 | RS并发 | 加速RS处理 |
| `--concurrent-service-syncs` | 5 | 5 | 20 | Service并发 | 加速Service处理 |
| `--concurrent-namespace-syncs` | 10 | 10 | 20 | NS并发 | 加速NS处理 |
| `--concurrent-gc-syncs` | 20 | 20 | 50 | GC并发 | 加速资源回收 |
| `--node-monitor-grace-period` | 40s | 40s | 40s | 节点监控宽限期 | 影响NotReady判定 |
| `--node-monitor-period` | 5s | 5s | 5s | 节点检查周期 | 影响检测速度 |
| `--pod-eviction-timeout` | 5m | 5m | 5m | Pod驱逐超时 | 影响故障恢复 |
| `--kube-api-qps` | 20 | 20 | 100 | API请求QPS | 大集群需增加 |
| `--kube-api-burst` | 30 | 30 | 200 | API请求突发 | 大集群需增加 |
| `--terminated-pod-gc-threshold` | 12500 | 12500 | 12500 | 终止Pod GC阈值 | 控制对象数量 |

### 节点故障检测与Pod驱逐参数关系

```
节点故障检测流程:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  节点状态更新周期          节点监控宽限期          Pod驱逐超时              │
│  (kubelet)                (controller-manager)   (controller-manager)      │
│                                                                             │
│  node-status-update-      node-monitor-          pod-eviction-             │
│  frequency: 10s           grace-period: 40s      timeout: 5m               │
│       │                         │                      │                   │
│       └── kubelet每10s          └── 40s内没有          └── 节点NotReady后   │
│           更新节点状态              心跳则标记              5分钟开始驱逐    │
│                                    NotReady              Pod                │
│                                                                             │
│  总故障检测到驱逐时间 ≈ 40s + 5m = 5分40秒                                   │
│                                                                             │
│  快速故障检测配置(谨慎使用):                                                 │
│  • node-monitor-grace-period: 20s                                          │
│  • pod-eviction-timeout: 30s                                               │
│  • 总时间 ≈ 50秒 (但可能导致误判)                                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

## kubelet 关键参数

### 核心参数

| 参数 | 默认值 | 推荐值 | 说明 | 影响 |
|-----|-------|-------|------|------|
| `--config` | 无 | 配置文件路径 | kubelet配置 | **推荐使用配置文件** |
| `--container-runtime-endpoint` | 无 | unix:///run/containerd/containerd.sock | CRI端点 | v1.24+必须指定 |
| `--max-pods` | 110 | 110-250 | 节点最大Pod数 | 需配合CIDR规划 |
| `--pod-max-pids` | -1 | 4096 | Pod最大PID数 | 防止PID耗尽 |
| `--serialize-image-pulls` | true | false | 串行拉取镜像 | false可并行加速 |
| `--registry-qps` | 5 | 20 | 镜像仓库QPS | 大量Pod启动时增加 |
| `--registry-burst` | 10 | 40 | 镜像仓库突发 | 大量Pod启动时增加 |
| `--rotate-certificates` | true | true | 证书轮换 | 安全必需 |
| `--protect-kernel-defaults` | false | true | 保护内核默认值 | 安全加固 |
| `--read-only-port` | 10255 | 0 | 只读端口 | **生产应禁用(设为0)** |

### kubelet配置文件示例

```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

# 认证授权
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
    cacheTTL: 2m0s
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 5m0s
    cacheUnauthorizedTTL: 30s

# TLS配置
tlsCertFile: /var/lib/kubelet/pki/kubelet.crt
tlsPrivateKeyFile: /var/lib/kubelet/pki/kubelet.key
tlsMinVersion: VersionTLS12
tlsCipherSuites:
- TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
- TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
- TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
- TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384

# 容量配置
maxPods: 110
podPidsLimit: 4096

# 资源管理
systemReserved:
  cpu: "500m"
  memory: "1Gi"
  ephemeral-storage: "1Gi"
kubeReserved:
  cpu: "500m"
  memory: "1Gi"
  ephemeral-storage: "1Gi"
enforceNodeAllocatable:
- pods
- kube-reserved
- system-reserved

# 驱逐配置
evictionHard:
  memory.available: "500Mi"
  nodefs.available: "10%"
  nodefs.inodesFree: "5%"
  imagefs.available: "15%"
  pid.available: "5%"
evictionSoft:
  memory.available: "1Gi"
  nodefs.available: "15%"
  imagefs.available: "20%"
evictionSoftGracePeriod:
  memory.available: "2m"
  nodefs.available: "2m"
  imagefs.available: "2m"
evictionMinimumReclaim:
  memory.available: "500Mi"
  nodefs.available: "1Gi"
  imagefs.available: "2Gi"
evictionPressureTransitionPeriod: 5m0s
evictionMaxPodGracePeriod: 300

# 镜像管理
imageGCHighThresholdPercent: 80
imageGCLowThresholdPercent: 70
imageMinimumGCAge: 2m0s

# 容器日志
containerLogMaxSize: "50Mi"
containerLogMaxFiles: 5

# 节点状态
nodeStatusUpdateFrequency: 10s
nodeStatusReportFrequency: 5m0s
nodeLeaseDurationSeconds: 40

# 优雅关闭 (v1.25+ GA)
shutdownGracePeriod: 60s
shutdownGracePeriodCriticalPods: 20s
shutdownGracePeriodByPodPriority:
- priority: 2000001000    # system-cluster-critical
  shutdownGracePeriodSeconds: 20
- priority: 2000000000    # system-node-critical
  shutdownGracePeriodSeconds: 15
- priority: 1000000000    # high priority
  shutdownGracePeriodSeconds: 10
- priority: 0
  shutdownGracePeriodSeconds: 5

# 其他配置
serializeImagePulls: false
registryPullQPS: 20
registryBurst: 40
rotateCertificates: true
protectKernelDefaults: true
streamingConnectionIdleTimeout: 4h0m0s
makeIPTablesUtilChains: true

# cgroup配置
cgroupDriver: systemd
cgroupsPerQOS: true

# Feature Gates
featureGates:
  GracefulNodeShutdown: true
  TopologyManager: true
  MemoryManager: false
```

### 驱逐阈值配置对照表

| 驱逐信号 | 硬驱逐默认值 | 软驱逐推荐值 | 最小回收量 | 说明 |
|---------|------------|------------|----------|------|
| `memory.available` | 100Mi | 500Mi-1Gi | 500Mi | 可用内存 |
| `nodefs.available` | 10% | 15% | 1Gi | 节点文件系统可用 |
| `nodefs.inodesFree` | 5% | 10% | - | 节点inode可用 |
| `imagefs.available` | 15% | 20% | 2Gi | 镜像文件系统可用 |
| `pid.available` | 无 | 5% | 1000 | 可用PID数 |

## kube-proxy 关键参数

| 参数 | 默认值 | iptables模式 | IPVS模式 | nftables模式 | 说明 |
|-----|-------|-------------|---------|-------------|------|
| `--proxy-mode` | iptables | iptables | ipvs | nftables | 代理模式 |
| `--cluster-cidr` | 无 | Pod CIDR | Pod CIDR | Pod CIDR | 影响SNAT行为 |
| `--ipvs-scheduler` | - | - | rr/lc/sh | - | IPVS调度算法 |
| `--ipvs-min-sync-period` | - | - | 1s | - | 最小同步周期 |
| `--ipvs-sync-period` | - | - | 30s | - | 同步周期 |
| `--iptables-min-sync-period` | 1s | 1s | - | - | 最小同步周期 |
| `--iptables-sync-period` | 30s | 30s | - | - | 同步周期 |
| `--conntrack-max-per-core` | 32768 | 65536 | 65536 | 65536 | 每核conntrack数 |
| `--conntrack-min` | 131072 | 262144 | 262144 | 262144 | 最小conntrack数 |

### kube-proxy配置文件示例 (IPVS模式)

```yaml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
bindAddress: 0.0.0.0
clientConnection:
  kubeconfig: /var/lib/kube-proxy/kubeconfig.conf
  qps: 50
  burst: 100

mode: ipvs

ipvs:
  scheduler: rr                        # rr(轮询), lc(最少连接), sh(源地址哈希)
  minSyncPeriod: 1s
  syncPeriod: 30s
  strictARP: true                      # MetalLB需要启用
  tcpTimeout: 0s
  tcpFinTimeout: 0s
  udpTimeout: 0s
  excludeCIDRs: []

iptables:
  masqueradeAll: false
  masqueradeBit: 14
  minSyncPeriod: 1s
  syncPeriod: 30s

conntrack:
  maxPerCore: 65536
  min: 262144
  tcpCloseWaitTimeout: 1h0m0s
  tcpEstablishedTimeout: 24h0m0s

clusterCIDR: 10.244.0.0/16
healthzBindAddress: 0.0.0.0:10256
metricsBindAddress: 127.0.0.1:10249     # 安全考虑，只监听本地

nodePortAddresses: []
oomScoreAdj: -999
winkernel:
  enableDSR: false
  networkName: ""
  sourceVip: ""
```

### 代理模式对比

| 特性 | iptables | IPVS | nftables |
|-----|---------|------|---------|
| **性能** | 中等 | 高 | 高 |
| **Service数量** | <5000 | >10000 | >10000 |
| **规则更新** | 全量更新 | 增量更新 | 增量更新 |
| **负载均衡算法** | 随机 | 多种(rr,lc,sh等) | 多种 |
| **连接保持** | 支持 | 支持 | 支持 |
| **会话亲和** | 支持 | 支持 | 支持 |
| **版本支持** | 所有版本 | 所有版本 | v1.26+ Beta |
| **推荐场景** | 小集群 | **大集群推荐** | 新部署尝试 |

## Feature Gates 配置

### 按版本的默认状态

| 功能门控 | v1.25 | v1.28 | v1.30 | v1.32 | 说明 | 启用建议 |
|---------|-------|-------|-------|-------|------|---------|
| `PodSecurity` | GA | GA | GA | GA | Pod安全准入 | 默认启用 |
| `ServerSideApply` | GA | GA | GA | GA | 服务端应用 | 默认启用 |
| `EphemeralContainers` | GA | GA | GA | GA | 调试容器 | 默认启用 |
| `GracefulNodeShutdown` | Beta | GA | GA | GA | 优雅关闭 | 推荐启用 |
| `InPlacePodVerticalScaling` | - | Alpha | Beta | GA | 就地调整 | v1.32+可用 |
| `SidecarContainers` | - | Beta | GA | GA | Sidecar支持 | v1.30+推荐 |
| `ValidatingAdmissionPolicy` | - | Beta | GA | GA | CEL验证 | v1.30+推荐 |
| `UserNamespacesSupport` | Alpha | Beta | Beta | GA | 用户命名空间 | 安全增强 |
| `DynamicResourceAllocation` | Alpha | Beta | Beta | GA | 动态资源 | GPU场景 |
| `TopologyAwareHints` | Beta | GA | GA | GA | 拓扑感知 | 性能优化 |
| `MinDomainsInPodTopologySpread` | Beta | GA | GA | GA | 最小域数 | 高可用 |

### Feature Gates配置示例

```bash
# kube-apiserver
--feature-gates=ValidatingAdmissionPolicy=true,UserNamespacesSupport=true

# kube-controller-manager
--feature-gates=ValidatingAdmissionPolicy=true

# kube-scheduler
--feature-gates=PodSchedulingReadiness=true

# kubelet
--feature-gates=GracefulNodeShutdown=true,TopologyManager=true,InPlacePodVerticalScaling=true
```

## kubeconfig 结构与管理

### 完整kubeconfig示例

```yaml
apiVersion: v1
kind: Config
preferences:
  colors: true

# 集群定义
clusters:
- name: production
  cluster:
    server: https://prod-apiserver.example.com:6443
    certificate-authority-data: <base64-encoded-ca>
    # 或使用文件路径
    # certificate-authority: /path/to/ca.crt
    tls-server-name: kubernetes

- name: staging
  cluster:
    server: https://staging-apiserver.example.com:6443
    certificate-authority-data: <base64-encoded-ca>

# 用户凭证定义
users:
- name: admin
  user:
    client-certificate-data: <base64-encoded-cert>
    client-key-data: <base64-encoded-key>

- name: developer
  user:
    # 使用token认证
    token: <bearer-token>

- name: oidc-user
  user:
    # OIDC认证
    auth-provider:
      name: oidc
      config:
        idp-issuer-url: https://idp.example.com
        client-id: kubernetes
        client-secret: <secret>
        refresh-token: <refresh-token>
        id-token: <id-token>

- name: exec-user
  user:
    # Exec认证 (云厂商常用)
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws
      args:
      - eks
      - get-token
      - --cluster-name
      - my-cluster
      env:
      - name: AWS_PROFILE
        value: default
      interactiveMode: Never
      provideClusterInfo: false

# 上下文定义
contexts:
- name: prod-admin
  context:
    cluster: production
    user: admin
    namespace: default

- name: prod-dev
  context:
    cluster: production
    user: developer
    namespace: development

- name: staging-admin
  context:
    cluster: staging
    user: admin
    namespace: default

# 当前上下文
current-context: prod-admin
```

## ACK 特定配置建议

| 配置项 | ACK托管版 | ACK专有版 | ACK Serverless | 说明 |
|-------|----------|----------|----------------|------|
| **控制平面参数** | 控制台/API | 手动配置 | 自动管理 | 托管版限制部分参数 |
| **kubelet配置** | 节点池模板 | 手动配置 | N/A | 通过节点池统一管理 |
| **kube-proxy模式** | 创建时选择 | 创建时选择 | Terway IPVLAN | 推荐IPVS |
| **审计日志** | 自动集成SLS | 手动配置 | 自动集成 | 托管版自动接入 |
| **证书轮换** | 自动 | 手动 | 自动 | 托管版自动管理 |
| **etcd** | 托管 | 自建 | 托管 | 托管版无需管理 |

### ACK节点池配置示例

```yaml
# ACK节点池kubelet配置 (通过节点池API设置)
{
  "kubeletConfig": {
    "maxPods": 64,
    "evictionHard": {
      "memory.available": "500Mi",
      "nodefs.available": "10%"
    },
    "systemReserved": {
      "cpu": "500m",
      "memory": "1Gi"
    },
    "kubeReserved": {
      "cpu": "500m", 
      "memory": "1Gi"
    },
    "featureGates": {
      "GracefulNodeShutdown": true
    }
  }
}
```

## 配置检查命令

```bash
# 查看API Server参数
kubectl get pods -n kube-system -l component=kube-apiserver -o yaml | grep -A 100 'command:'

# 查看当前生效的kubelet配置
kubectl get configmap -n kube-system kubelet-config -o yaml
kubectl proxy &
curl -s http://localhost:8001/api/v1/nodes/<node>/proxy/configz | jq

# 查看Feature Gates状态
kubectl get --raw /metrics | grep kubernetes_feature_enabled

# 查看etcd参数
kubectl get pods -n kube-system -l component=etcd -o yaml | grep -A 50 'command:'

# 检查kube-proxy模式
kubectl get configmap -n kube-system kube-proxy -o yaml | grep mode

# 查看调度器配置
kubectl get configmap -n kube-system scheduler-config -o yaml

# 查看控制器管理器参数
kubectl get pods -n kube-system -l component=kube-controller-manager -o yaml | grep -A 100 'command:'

# 验证参数变更效果
kubectl get --raw /metrics | grep apiserver_request
kubectl get --raw /metrics | grep scheduler_pending
```

---

**配置原则**: 
1. 始终在staging环境测试配置变更
2. 保持变更记录，便于回滚
3. 根据监控指标调整，而非盲目照搬
4. 大集群配置需要更保守的调整策略
