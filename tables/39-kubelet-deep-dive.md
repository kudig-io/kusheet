# kubelet 深度解析 (kubelet Deep Dive)

> kubelet 是 Kubernetes 中运行在每个节点上的核心代理，负责管理节点上的 Pod 和容器生命周期

---

## 1. 架构概述 (Architecture Overview)

### 1.1 核心职责

| 职责 | 英文名 | 说明 |
|:---|:---|:---|
| **Pod生命周期管理** | Pod Lifecycle | 创建、启动、停止、删除Pod |
| **容器运行时交互** | Container Runtime | 通过CRI与containerd/CRI-O通信 |
| **资源管理** | Resource Management | CPU、内存、存储资源分配与限制 |
| **健康检查** | Health Probing | Liveness、Readiness、Startup探针 |
| **节点状态报告** | Node Status | 定期向API Server汇报节点状态 |
| **卷管理** | Volume Management | 挂载/卸载Pod所需存储卷 |
| **日志和监控** | Logging/Metrics | 容器日志收集、暴露指标 |
| **设备插件** | Device Plugins | GPU等特殊硬件资源管理 |
| **镜像管理** | Image Management | 镜像拉取、清理 |

### 1.2 整体架构

```
┌────────────────────────────────────────────────────────────────────────┐
│                              kubelet                                    │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                        API Server Client                          │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐                  │  │
│  │  │   Watch    │  │   Update   │  │   Report   │                  │  │
│  │  │   Pods     │  │   Status   │  │   Node     │                  │  │
│  │  └────────────┘  └────────────┘  └────────────┘                  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                 │                                       │
│  ┌──────────────────────────────┴─────────────────────────────────┐   │
│  │                     Pod Lifecycle Manager                       │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────────────────────┐│   │
│  │  │   PLEG     │  │   Sync     │  │    Status Manager          ││   │
│  │  │ (PodLifecycle│  │   Loop     │  │                           ││   │
│  │  │  EventGen) │  │            │  │                            ││   │
│  │  └────────────┘  └────────────┘  └────────────────────────────┘│   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                 │                                       │
│  ┌──────────────────────────────┴─────────────────────────────────┐   │
│  │                       Sub-Managers                              │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────────────────┐│   │
│  │  │  Prober  │ │  Volume  │ │  Image   │ │   Device Plugin     ││   │
│  │  │  Manager │ │  Manager │ │  Manager │ │   Manager           ││   │
│  │  └──────────┘ └──────────┘ └──────────┘ └─────────────────────┘│   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────────────────┐│   │
│  │  │   Evict  │ │  Secret  │ │ConfigMap │ │   Resource/cgroup   ││   │
│  │  │  Manager │ │  Manager │ │  Manager │ │   Manager           ││   │
│  │  └──────────┘ └──────────┘ └──────────┘ └─────────────────────┘│   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                 │                                       │
│                                 │ CRI (Container Runtime Interface)    │
│                                 ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Container Runtime                             │   │
│  │         containerd / CRI-O / docker (deprecated)                │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ OCI
                                  ▼
┌────────────────────────────────────────────────────────────────────────┐
│                          Low-Level Runtime                              │
│                          runc / kata / gVisor                          │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.3 关键组件说明

| 组件 | 英文名 | 职责 |
|:---|:---|:---|
| **PLEG** | Pod Lifecycle Event Generator | 检测容器状态变化，生成事件 |
| **SyncLoop** | Sync Loop | 主循环，处理Pod同步 |
| **ProbeManager** | Probe Manager | 执行健康检查探针 |
| **VolumeManager** | Volume Manager | 管理卷的挂载和卸载 |
| **ImageManager** | Image Manager | 管理容器镜像 |
| **EvictionManager** | Eviction Manager | 资源压力时驱逐Pod |
| **StatusManager** | Status Manager | 同步Pod状态到API Server |
| **SecretManager** | Secret Manager | 管理Secret的同步 |
| **ConfigMapManager** | ConfigMap Manager | 管理ConfigMap的同步 |
| **DevicePluginManager** | Device Plugin Manager | 管理设备插件 |

---

## 2. Pod 生命周期管理 (Pod Lifecycle)

### 2.1 Pod 同步流程

```
API Server Watch Event (Pod变化)
        │
        ▼
┌───────────────────────────────────────────────────────────────┐
│                    SyncLoop (主循环)                          │
│                                                               │
│  Event Sources:                                               │
│  ├─ configCh: API Server的Pod配置                            │
│  ├─ syncCh: 周期性同步 (默认1s)                              │
│  ├─ housekeepingCh: 清理任务 (默认2s)                        │
│  ├─ plegCh: PLEG事件 (容器状态变化)                          │
│  └─ livenessManager: 存活探针失败事件                        │
│                                                               │
└───────────────────────────────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────────────────┐
│                   SyncPod (单Pod同步)                         │
│                                                               │
│  1. 计算期望状态 vs 实际状态                                  │
│  2. 创建/更新 Pod Sandbox (pause容器)                         │
│  3. 创建/更新 Init Containers (顺序)                         │
│  4. 创建/更新 Regular Containers (并行)                      │
│  5. 启动探针检查                                              │
│  6. 更新Pod状态                                               │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

### 2.2 容器状态流转

```
                    ┌─────────────┐
                    │   Waiting   │
                    │ (等待创建)   │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ContainerCreating│   ImagePullBackOff │   ErrImagePull │
└──────┬──────┘    └─────────────┘    └─────────────┘
       │
       ▼
┌─────────────┐
│   Running   │◀──────────────────────────────────┐
└──────┬──────┘                                   │
       │                                          │
       ├─────────────────┬────────────────┬──────┘
       │                 │                │  (重启策略)
       ▼                 ▼                ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ Completed   │  │  Error      │  │ CrashLoop   │
│ (正常退出)   │  │ (异常退出)   │  │ BackOff     │
└─────────────┘  └─────────────┘  └─────────────┘
```

### 2.3 PLEG (Pod Lifecycle Event Generator)

| 事件类型 | 说明 | 触发条件 |
|:---|:---|:---|
| **ContainerStarted** | 容器启动 | 容器状态从非Running变为Running |
| **ContainerDied** | 容器死亡 | 容器状态从Running变为非Running |
| **ContainerRemoved** | 容器移除 | 容器从运行时删除 |
| **ContainerChanged** | 容器变化 | 容器配置发生变化 |
| **PodSync** | Pod同步 | 需要重新同步Pod状态 |

```bash
# PLEG 工作参数
--pleg-relist-period=1s          # PLEG重新列举周期
--pod-manifest-path=/etc/kubernetes/manifests  # 静态Pod目录
```

---

## 3. 健康检查探针 (Health Probes)

### 3.1 探针类型对比

| 探针类型 | 英文名 | 用途 | 失败后果 |
|:---|:---|:---|:---|
| **存活探针** | Liveness Probe | 检测容器是否存活 | 重启容器 |
| **就绪探针** | Readiness Probe | 检测容器是否就绪 | 从Service端点移除 |
| **启动探针** | Startup Probe | 检测容器是否完成启动 | 阻止其他探针执行 |

### 3.2 探针检查方式

| 方式 | 说明 | 适用场景 |
|:---|:---|:---|
| **HTTP GET** | 发送HTTP请求，2xx/3xx为成功 | Web服务 |
| **TCP Socket** | 建立TCP连接，连接成功为成功 | 数据库、缓存 |
| **Exec** | 在容器内执行命令，退出码0为成功 | 复杂检查逻辑 |
| **gRPC** | gRPC健康检查协议 | gRPC服务 |

### 3.3 探针配置示例

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: probe-demo
spec:
  containers:
  - name: app
    image: my-app:latest
    ports:
    - containerPort: 8080
    
    # 存活探针 - 检测死锁等问题
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
        httpHeaders:
        - name: Custom-Header
          value: Awesome
      initialDelaySeconds: 15    # 首次检查延迟
      periodSeconds: 10          # 检查周期
      timeoutSeconds: 3          # 超时时间
      successThreshold: 1        # 成功阈值
      failureThreshold: 3        # 失败阈值
    
    # 就绪探针 - 检测是否可接收流量
    readinessProbe:
      tcpSocket:
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 2
      successThreshold: 1
      failureThreshold: 3
    
    # 启动探针 - 慢启动应用
    startupProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 0
      periodSeconds: 10
      timeoutSeconds: 3
      successThreshold: 1
      failureThreshold: 30       # 允许5分钟启动时间

---
# gRPC 健康检查示例 (K8s 1.24+)
apiVersion: v1
kind: Pod
metadata:
  name: grpc-probe-demo
spec:
  containers:
  - name: grpc-app
    image: my-grpc-app:latest
    livenessProbe:
      grpc:
        port: 9090
        service: ""              # 空字符串检查整体健康
      initialDelaySeconds: 10
      periodSeconds: 10
```

### 3.4 探针最佳实践

| 最佳实践 | 说明 |
|:---|:---|
| 分离健康检查端点 | 不要在健康检查端点执行重操作 |
| 合理设置延迟 | initialDelaySeconds应大于应用启动时间 |
| 使用Startup Probe | 慢启动应用避免被Liveness杀死 |
| 不依赖外部服务 | 健康检查不应依赖数据库等外部服务 |
| 设置合理超时 | 超时时间应小于检查周期 |
| 区分存活和就绪 | 存活检测死锁，就绪检测是否可服务 |

---

## 4. 关键配置参数 (Configuration Parameters)

### 4.1 通用参数

| 参数 | 默认值 | 推荐值 | 说明 |
|:---|:---|:---|:---|
| `--config` | - | /var/lib/kubelet/config.yaml | 配置文件路径 |
| `--kubeconfig` | - | /etc/kubernetes/kubelet.conf | API Server连接配置 |
| `--container-runtime-endpoint` | - | unix:///run/containerd/containerd.sock | 容器运行时端点 |
| `--hostname-override` | 主机名 | - | 覆盖节点主机名 |
| `--node-ip` | 自动检测 | 节点IP | 节点IP地址 |
| `--cloud-provider` | - | external | 云提供商模式 |
| `--register-node` | true | true | 自动注册节点 |
| `--register-with-taints` | - | - | 注册时添加的Taint |

### 4.2 资源管理参数

| 参数 | 默认值 | 推荐值 | 说明 |
|:---|:---|:---|:---|
| `--kube-reserved` | 无 | cpu=100m,memory=256Mi | Kubernetes组件预留 |
| `--system-reserved` | 无 | cpu=100m,memory=256Mi | 系统进程预留 |
| `--eviction-hard` | 见下 | 根据节点调整 | 硬驱逐阈值 |
| `--eviction-soft` | 无 | 见下 | 软驱逐阈值 |
| `--eviction-soft-grace-period` | 无 | 见下 | 软驱逐宽限期 |
| `--max-pods` | 110 | 根据节点调整 | 节点最大Pod数 |
| `--pods-per-core` | 0 | 0 | 每核心Pod数限制 |
| `--enforce-node-allocatable` | pods | pods,kube-reserved,system-reserved | 强制分配策略 |

```yaml
# 驱逐配置示例 (KubeletConfiguration)
evictionHard:
  memory.available: "100Mi"
  nodefs.available: "10%"
  nodefs.inodesFree: "5%"
  imagefs.available: "15%"

evictionSoft:
  memory.available: "500Mi"
  nodefs.available: "15%"

evictionSoftGracePeriod:
  memory.available: "1m30s"
  nodefs.available: "1m30s"

evictionPressureTransitionPeriod: "5m"
```

### 4.3 Pod管理参数

| 参数 | 默认值 | 说明 |
|:---|:---|:---|
| `--pod-manifest-path` | - | 静态Pod配置目录 |
| `--file-check-frequency` | 20s | 静态Pod检查频率 |
| `--sync-frequency` | 1m | Pod配置同步频率 |
| `--max-open-files` | 1000000 | 最大打开文件数 |
| `--serialize-image-pulls` | true | 串行拉取镜像 |
| `--image-pull-progress-deadline` | 1m | 镜像拉取超时 |
| `--streaming-connection-idle-timeout` | 4h | 流式连接空闲超时 |

### 4.4 网络参数

| 参数 | 默认值 | 说明 |
|:---|:---|:---|
| `--cluster-dns` | - | 集群DNS服务IP |
| `--cluster-domain` | cluster.local | 集群域名 |
| `--resolv-conf` | /etc/resolv.conf | DNS解析配置 |
| `--network-plugin` | - | 已弃用，使用CNI |
| `--cni-bin-dir` | /opt/cni/bin | CNI插件目录 |
| `--cni-conf-dir` | /etc/cni/net.d | CNI配置目录 |
| `--hairpin-mode` | promiscuous-bridge | Hairpin NAT模式 |

### 4.5 安全参数

| 参数 | 默认值 | 说明 |
|:---|:---|:---|
| `--anonymous-auth` | false | 匿名访问(kubelet API) |
| `--authentication-token-webhook` | true | Webhook Token认证 |
| `--authorization-mode` | Webhook | 授权模式 |
| `--client-ca-file` | - | 客户端CA证书 |
| `--tls-cert-file` | - | Kubelet服务器证书 |
| `--tls-private-key-file` | - | Kubelet服务器私钥 |
| `--rotate-certificates` | true | 证书自动轮换 |
| `--protect-kernel-defaults` | false | 保护内核默认值 |
| `--make-iptables-util-chains` | true | 创建iptables链 |

---

## 5. 配置文件方式 (KubeletConfiguration)

### 5.1 完整配置示例

```yaml
# /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

# 认证授权
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
    cacheTTL: "2m"
  x509:
    clientCAFile: "/etc/kubernetes/pki/ca.crt"

authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: "5m"
    cacheUnauthorizedTTL: "30s"

# 集群DNS
clusterDNS:
  - "10.96.0.10"
clusterDomain: "cluster.local"
resolvConf: "/etc/resolv.conf"

# 资源管理
kubeReserved:
  cpu: "100m"
  memory: "256Mi"
  ephemeral-storage: "1Gi"
systemReserved:
  cpu: "100m"
  memory: "256Mi"
  ephemeral-storage: "1Gi"

# Pod配置
maxPods: 110
podPidsLimit: 4096
cpuManagerPolicy: "static"     # none/static
cpuManagerReconcilePeriod: "10s"
memoryManagerPolicy: "None"    # None/Static
topologyManagerPolicy: "none"  # none/best-effort/restricted/single-numa-node

# 驱逐配置
evictionHard:
  memory.available: "100Mi"
  nodefs.available: "10%"
  nodefs.inodesFree: "5%"
  imagefs.available: "15%"
evictionSoft:
  memory.available: "500Mi"
  nodefs.available: "15%"
evictionSoftGracePeriod:
  memory.available: "1m30s"
  nodefs.available: "1m30s"
evictionPressureTransitionPeriod: "5m"
evictionMaxPodGracePeriod: 30

# 镜像GC
imageMinimumGCAge: "2m"
imageGCHighThresholdPercent: 85
imageGCLowThresholdPercent: 80

# 容器日志
containerLogMaxSize: "10Mi"
containerLogMaxFiles: 5

# CGroups
cgroupDriver: "systemd"        # cgroupfs/systemd
cgroupsPerQOS: true
cgroupRoot: "/"
enforceNodeAllocatable:
  - "pods"
  - "kube-reserved"
  - "system-reserved"

# 特性门控
featureGates:
  GracefulNodeShutdown: true
  MemoryManager: true
  CPUManager: true
  TopologyManager: true

# 优雅关闭
shutdownGracePeriod: "30s"
shutdownGracePeriodCriticalPods: "10s"

# 日志
logging:
  format: "json"
  sanitization: false
  options:
    json:
      infoBufferSize: "0"

# 健康检查
healthzPort: 10248
healthzBindAddress: "127.0.0.1"

# 只读端口 (不推荐启用)
readOnlyPort: 0
```

---

## 6. cgroup 管理 (cgroup Management)

### 6.1 cgroup 驱动对比

| 驱动 | 说明 | 推荐 |
|:---|:---|:---|
| **cgroupfs** | kubelet直接操作cgroup文件系统 | 不推荐 |
| **systemd** | 通过systemd管理cgroup | 推荐(与系统一致) |

```bash
# 检查当前cgroup驱动
cat /var/lib/kubelet/config.yaml | grep cgroupDriver

# 检查容器运行时cgroup驱动 (containerd)
cat /etc/containerd/config.toml | grep SystemdCgroup

# 确保kubelet和容器运行时使用相同的cgroup驱动
```

### 6.2 cgroup v1 vs v2

| 特性 | cgroup v1 | cgroup v2 |
|:---|:---|:---|
| **层级结构** | 多层级(每控制器一个) | 单一统一层级 |
| **资源控制** | 分散在不同控制器 | 统一接口 |
| **Kubernetes支持** | 完全支持 | 1.25+ 稳定支持 |
| **推荐** | 兼容性好 | 新部署推荐 |

```bash
# 检查系统使用的cgroup版本
stat -fc %T /sys/fs/cgroup/

# cgroup v1: tmpfs
# cgroup v2: cgroup2fs

# 或者
mount | grep cgroup
```

### 6.3 Pod QoS 与 cgroup

| QoS 类别 | 条件 | cgroup 位置 | 驱逐优先级 |
|:---|:---|:---|:---|
| **Guaranteed** | requests = limits (全部资源) | /kubepods/pod<uid> | 最后 |
| **Burstable** | requests < limits 或部分设置 | /kubepods/burstable/pod<uid> | 中等 |
| **BestEffort** | 未设置requests和limits | /kubepods/besteffort/pod<uid> | 最先 |

```bash
# 查看Pod的cgroup
# systemd cgroup driver
cat /sys/fs/cgroup/memory/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-pod<uid>.slice/memory.limit_in_bytes

# 或使用crictl
crictl inspect <container-id> | jq .info.runtimeSpec.linux.cgroupsPath
```

---

## 7. 监控指标 (Monitoring Metrics)

### 7.1 关键指标表

| 指标名称 | 类型 | 说明 | 告警阈值 |
|:---|:---|:---|:---|
| `kubelet_running_pods` | Gauge | 运行中的Pod数 | - |
| `kubelet_running_containers` | Gauge | 运行中的容器数 | - |
| `kubelet_node_name` | Gauge | 节点名称(标签) | - |
| `kubelet_pleg_relist_duration_seconds` | Histogram | PLEG重列举耗时 | p99 > 1s |
| `kubelet_pleg_relist_interval_seconds` | Histogram | PLEG重列举间隔 | p99 > 3s |
| `kubelet_pod_start_duration_seconds` | Histogram | Pod启动耗时 | p99 > 60s |
| `kubelet_pod_worker_duration_seconds` | Histogram | Pod Worker耗时 | p99 > 10s |
| `kubelet_runtime_operations_total` | Counter | 运行时操作总数 | - |
| `kubelet_runtime_operations_duration_seconds` | Histogram | 运行时操作耗时 | p99 > 5s |
| `kubelet_runtime_operations_errors_total` | Counter | 运行时操作错误 | 持续增长 |
| `kubelet_cgroup_manager_duration_seconds` | Histogram | cgroup操作耗时 | p99 > 100ms |
| `kubelet_volume_stats_*` | Gauge | 卷统计信息 | - |
| `kubelet_eviction_stats_age_seconds` | Histogram | 驱逐统计 | - |
| `kubelet_http_requests_total` | Counter | HTTP请求总数 | - |

### 7.2 Prometheus 告警规则

```yaml
groups:
- name: kubelet
  rules:
  - alert: KubeletDown
    expr: absent(up{job="kubelet"} == 1)
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Kubelet is down on {{ $labels.instance }}"

  - alert: KubeletTooManyPods
    expr: kubelet_running_pods / kubelet_node_config_max_pods > 0.95
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Kubelet is running too many pods"
      description: "{{ $labels.instance }} is running {{ $value | humanizePercentage }} of max pods"

  - alert: KubeletPLEGDurationHigh
    expr: histogram_quantile(0.99, rate(kubelet_pleg_relist_duration_seconds_bucket[5m])) > 1
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Kubelet PLEG duration is high"
      description: "PLEG p99 duration is {{ $value }}s on {{ $labels.instance }}"

  - alert: KubeletPodStartLatencyHigh
    expr: histogram_quantile(0.99, rate(kubelet_pod_start_duration_seconds_bucket[5m])) > 60
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Kubelet pod start latency is high"

  - alert: KubeletRuntimeOperationErrors
    expr: increase(kubelet_runtime_operations_errors_total[5m]) > 10
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Kubelet runtime operations errors increasing"

  - alert: KubeletVolumePluginError
    expr: kubelet_volume_stats_inodes_free / kubelet_volume_stats_inodes < 0.1
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Volume is running low on inodes"

  - alert: KubeletClientCertExpiration
    expr: kubelet_certificate_manager_client_expiration_seconds - time() < 86400 * 7
    for: 1h
    labels:
      severity: warning
    annotations:
      summary: "Kubelet client certificate expires in less than 7 days"
```

---

## 8. 故障排查 (Troubleshooting)

### 8.1 常见问题诊断

| 症状 | 可能原因 | 诊断方法 | 解决方案 |
|:---|:---|:---|:---|
| **节点NotReady** | kubelet未运行/运行时故障 | systemctl status kubelet | 重启kubelet/运行时 |
| **Pod启动慢** | 镜像拉取慢/资源不足 | 检查events/PLEG指标 | 优化镜像/增加资源 |
| **Pod Eviction** | 资源压力 | kubectl describe node | 检查驱逐原因 |
| **容器CrashLoop** | 应用问题/资源不足 | kubectl logs/describe | 检查应用日志 |
| **镜像拉取失败** | 网络/认证问题 | crictl pull | 检查网络/凭证 |
| **卷挂载失败** | 存储问题/权限 | kubectl describe pod | 检查存储后端 |
| **PLEG不健康** | 运行时问题/高负载 | 检查PLEG指标 | 检查运行时/减少Pod |
| **OOM Kill** | 内存不足 | dmesg/journalctl | 增加limits/节点内存 |

### 8.2 诊断命令

```bash
# 检查 kubelet 状态
systemctl status kubelet
journalctl -u kubelet -f --no-pager

# 检查节点状态
kubectl describe node <node-name>
kubectl get node <node-name> -o yaml

# 检查节点条件
kubectl get nodes -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,MEMORY:.status.conditions[?(@.type=="MemoryPressure")].status,DISK:.status.conditions[?(@.type=="DiskPressure")].status,PID:.status.conditions[?(@.type=="PIDPressure")].status'

# 检查 kubelet 配置
cat /var/lib/kubelet/config.yaml

# 检查容器运行时
crictl info
crictl ps -a
crictl logs <container-id>

# 检查 PLEG 健康
curl -s http://localhost:10248/healthz
curl -s http://localhost:10255/metrics | grep pleg

# 检查 kubelet API (需认证)
curl -k https://localhost:10250/healthz
curl -k https://localhost:10250/pods

# 检查 cgroup
cat /sys/fs/cgroup/memory/kubepods/memory.limit_in_bytes
cat /sys/fs/cgroup/cpu/kubepods/cpu.cfs_quota_us

# 检查静态Pod
ls -la /etc/kubernetes/manifests/

# 检查证书
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates
```

### 8.3 常见日志模式

```bash
# 正常日志
I0101 00:00:00.000000   1 kubelet.go:2400] SyncLoop (PLEG): event for pod "nginx"
I0101 00:00:00.000000   1 kubelet.go:1925] syncPod(UID: xxx) completed successfully

# 警告日志
W0101 00:00:00.000000   1 eviction_manager.go:166] attempting to evict pod; usage: 95%
W0101 00:00:00.000000   1 image_gc_manager.go:321] Failed to garbage collect images

# 错误日志
E0101 00:00:00.000000   1 kubelet.go:2472] Container runtime network not ready
E0101 00:00:00.000000   1 pod_workers.go:191] Error syncing pod xxx: failed to pull image
E0101 00:00:00.000000   1 remote_runtime.go:116] RunPodSandbox from runtime failed
```

---

## 9. 性能优化 (Performance Tuning)

### 9.1 大规模节点优化

| 优化项 | 默认值 | 大节点推荐值 | 说明 |
|:---|:---|:---|:---|
| `--max-pods` | 110 | 250+ | 增加Pod容量 |
| `--kube-api-qps` | 50 | 100-200 | API QPS限制 |
| `--kube-api-burst` | 100 | 200-400 | API Burst限制 |
| `--serialize-image-pulls` | true | false | 并行拉取镜像 |
| `--registry-qps` | 5 | 20 | Registry QPS |
| `--registry-burst` | 10 | 40 | Registry Burst |
| `--event-qps` | 50 | 100 | Event QPS |
| `--event-burst` | 100 | 200 | Event Burst |

### 9.2 内存优化

```yaml
# 减少 ConfigMap/Secret 缓存
configMapAndSecretChangeDetectionStrategy: Watch  # Watch比Get更高效

# 启用内存管理器 (NUMA感知)
memoryManagerPolicy: Static
reservedMemory:
  - numaNode: 0
    limits:
      memory: "1Gi"
```

### 9.3 Linux 内核优化

```bash
# 文件描述符
cat >> /etc/security/limits.conf << EOF
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF

# 内核参数
cat >> /etc/sysctl.conf << EOF
# 网络
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1

# 文件系统
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192

# 内存
vm.swappiness = 0
vm.overcommit_memory = 1
vm.panic_on_oom = 0

# 进程
kernel.pid_max = 4194304
kernel.threads-max = 4194304
EOF

sysctl -p
```

---

## 10. 生产环境 Checklist

### 10.1 部署检查

| 检查项 | 状态 | 说明 |
|:---|:---|:---|
| [ ] 使用配置文件方式 | | 便于管理和版本控制 |
| [ ] cgroup驱动一致 | | kubelet与运行时使用相同驱动 |
| [ ] 资源预留配置 | | 配置kube-reserved/system-reserved |
| [ ] 驱逐阈值配置 | | 防止节点资源耗尽 |
| [ ] 证书自动轮换 | | 启用rotate-certificates |
| [ ] 监控告警配置 | | PLEG、Pod启动延迟等 |
| [ ] 日志收集配置 | | 便于问题排查 |

### 10.2 安全加固

| 加固项 | 配置 |
|:---|:---|
| 禁用匿名访问 | `anonymous-auth: false` |
| 启用Webhook认证 | `authentication.webhook.enabled: true` |
| 启用Webhook授权 | `authorization.mode: Webhook` |
| 禁用只读端口 | `readOnlyPort: 0` |
| 启用TLS | 配置证书文件 |
| 保护内核默认值 | `protectKernelDefaults: true` |

---

## 附录: kubelet API 端点

| 端点 | 端口 | 说明 |
|:---|:---|:---|
| `/healthz` | 10248 | 健康检查 |
| `/metrics` | 10250 | Prometheus指标 |
| `/metrics/cadvisor` | 10250 | cAdvisor指标 |
| `/metrics/probes` | 10250 | 探针指标 |
| `/metrics/resource` | 10250 | 资源指标 |
| `/pods` | 10250 | Pod列表 |
| `/runningpods` | 10250 | 运行中Pod |
| `/spec` | 10250 | 节点规格 |
| `/stats/summary` | 10250 | 统计摘要 |
| `/logs` | 10250 | 日志访问 |
| `/exec` | 10250 | 容器exec |
| `/attach` | 10250 | 容器attach |
| `/portForward` | 10250 | 端口转发 |
| `/containerLogs` | 10250 | 容器日志 |
