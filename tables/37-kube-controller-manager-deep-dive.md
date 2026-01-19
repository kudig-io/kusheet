# kube-controller-manager 深度解析 (KCM Deep Dive)

> kube-controller-manager (KCM) 是 Kubernetes 控制平面的核心组件，运行所有内置控制器，确保集群状态与期望状态一致

---

## 1. 架构概述 (Architecture Overview)

### 1.1 核心设计理念

| 概念 | 英文名 | 说明 |
|:---|:---|:---|
| **控制循环** | Control Loop | 持续监控并调整实际状态到期望状态 |
| **声明式管理** | Declarative | 用户声明期望状态，控制器实现 |
| **最终一致性** | Eventual Consistency | 系统最终会收敛到期望状态 |
| **单一职责** | Single Responsibility | 每个控制器只负责一种资源类型 |
| **水平触发** | Level-Triggered | 基于状态差异而非事件触发 |

### 1.2 整体架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        kube-controller-manager                          │
│                                                                         │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐  │
│  │ Leader Election  │  │  Controller      │  │   Shared Informers   │  │
│  │    (Lease)       │  │  Manager         │  │   (Watch Cache)      │  │
│  └────────┬─────────┘  └────────┬─────────┘  └──────────┬───────────┘  │
│           │                     │                        │              │
│           ▼                     ▼                        ▼              │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                        Controllers                                │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────────┐ │  │
│  │  │ Deployment │ │ ReplicaSet │ │   Node     │ │ ServiceAccount │ │  │
│  │  │ Controller │ │ Controller │ │ Controller │ │   Controller   │ │  │
│  │  └────────────┘ └────────────┘ └────────────┘ └────────────────┘ │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────────┐ │  │
│  │  │ Endpoint   │ │ Namespace  │ │   PV/PVC   │ │     Job        │ │  │
│  │  │ Controller │ │ Controller │ │ Controller │ │   Controller   │ │  │
│  │  └────────────┘ └────────────┘ └────────────┘ └────────────────┘ │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────────┐ │  │
│  │  │ DaemonSet  │ │ StatefulSet│ │    HPA     │ │   CronJob      │ │  │
│  │  │ Controller │ │ Controller │ │ Controller │ │   Controller   │ │  │
│  │  └────────────┘ └────────────┘ └────────────┘ └────────────────┘ │  │
│  │  ... (40+ Controllers)                                           │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────┬────────────────────────────┘
                                             │
                                             ▼
                                    ┌────────────────┐
                                    │  kube-apiserver│
                                    └────────┬───────┘
                                             │
                                             ▼
                                    ┌────────────────┐
                                    │      etcd      │
                                    └────────────────┘
```

### 1.3 控制器工作模式

```
                    ┌─────────────────────────────────┐
                    │         Controller Loop         │
                    └─────────────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                             ▼
        ┌─────────────────────┐      ┌─────────────────────┐
        │    Watch/Inform     │      │    Work Queue       │
        │  (Shared Informer)  │      │  (Rate Limited)     │
        └──────────┬──────────┘      └──────────┬──────────┘
                   │                            │
                   │  Event                     │  Pop Item
                   ▼                            ▼
        ┌─────────────────────┐      ┌─────────────────────┐
        │   Event Handler     │      │   Reconcile Logic   │
        │  Add/Update/Delete  │─────▶│   (Sync Handler)    │
        └─────────────────────┘      └──────────┬──────────┘
                                                │
                                  ┌─────────────┴─────────────┐
                                  ▼                           ▼
                        ┌────────────────┐         ┌──────────────────┐
                        │    Success     │         │     Failure      │
                        │   (Done)       │         │   (Requeue)      │
                        └────────────────┘         └──────────────────┘
```

---

## 2. 内置控制器详解 (Built-in Controllers)

### 2.1 工作负载控制器

| 控制器 | 监控资源 | 管理资源 | 核心职责 |
|:---|:---|:---|:---|
| **DeploymentController** | Deployment | ReplicaSet | 滚动更新、回滚、版本管理 |
| **ReplicaSetController** | ReplicaSet | Pod | 维护Pod副本数 |
| **StatefulSetController** | StatefulSet | Pod, PVC | 有状态应用管理、有序部署 |
| **DaemonSetController** | DaemonSet | Pod | 每节点运行一个Pod |
| **JobController** | Job | Pod | 批处理任务、完成追踪 |
| **CronJobController** | CronJob | Job | 定时任务调度 |
| **ReplicationController** | RC | Pod | 旧版副本控制(已弃用) |

### 2.2 服务与网络控制器

| 控制器 | 监控资源 | 管理资源 | 核心职责 |
|:---|:---|:---|:---|
| **EndpointsController** | Service, Pod | Endpoints | 维护Service端点列表 |
| **EndpointSliceController** | Service, Pod | EndpointSlice | 分片端点(大规模集群) |
| **ServiceController** | Service | Cloud LB | 云负载均衡器管理 |
| **IngressController** | - | - | (非KCM,独立部署) |

### 2.3 存储控制器

| 控制器 | 监控资源 | 管理资源 | 核心职责 |
|:---|:---|:---|:---|
| **PersistentVolumeController** | PV, PVC | PV, PVC | PV/PVC绑定 |
| **AttachDetachController** | Pod, Node | VolumeAttachment | 卷挂载/卸载 |
| **PVCProtectionController** | PVC | PVC Finalizer | 防止使用中的PVC被删除 |
| **PVProtectionController** | PV | PV Finalizer | 防止使用中的PV被删除 |
| **VolumeExpansionController** | PVC | PVC | 卷扩容 |

### 2.4 节点与生命周期控制器

| 控制器 | 监控资源 | 管理资源 | 核心职责 |
|:---|:---|:---|:---|
| **NodeController** | Node | Node, Pod | 节点状态管理、Pod驱逐 |
| **NodeLifecycleController** | Node | Pod | Taint管理、NotReady处理 |
| **PodGCController** | Pod | Pod | 清理已完成/孤儿Pod |
| **TTLController** | Job, Pod | Job, Pod | TTL后自动清理 |
| **TTLAfterFinishedController** | Job | Job | Job完成后TTL清理 |

### 2.5 安全与配置控制器

| 控制器 | 监控资源 | 管理资源 | 核心职责 |
|:---|:---|:---|:---|
| **ServiceAccountController** | Namespace | ServiceAccount | 创建默认SA |
| **TokenController** | ServiceAccount | Secret | SA Token管理 |
| **CertificateController** | CSR | CSR | 证书签名请求处理 |
| **NamespaceController** | Namespace | 所有NS内资源 | NS删除时清理资源 |
| **ResourceQuotaController** | ResourceQuota | ResourceQuota | 配额使用量更新 |
| **GarbageCollectorController** | 所有资源 | 所有资源 | 级联删除、孤儿清理 |

### 2.6 HPA/VPA 控制器

| 控制器 | 监控资源 | 管理资源 | 核心职责 |
|:---|:---|:---|:---|
| **HPAController** | HPA, Metrics | Deployment/RS等 | 水平自动伸缩 |
| **DisruptionController** | PDB | PDB Status | PDB状态管理 |

---

## 3. 核心控制器源码解析 (Key Controllers Deep Dive)

### 3.1 Deployment Controller

```
Deployment Controller 工作流程:

1. Watch Deployment/ReplicaSet/Pod 变化
2. 同步 Deployment 状态
   │
   ├─▶ 检查是否需要创建新 ReplicaSet
   │   └─ PodTemplateSpec 发生变化时创建新RS
   │
   ├─▶ 根据更新策略执行滚动更新
   │   ├─ RollingUpdate: 逐步替换Pod
   │   │   ├─ maxSurge: 最大超出副本数
   │   │   └─ maxUnavailable: 最大不可用数
   │   └─ Recreate: 先删后建
   │
   └─▶ 更新 Deployment Status
       ├─ replicas: 当前副本数
       ├─ updatedReplicas: 已更新副本数
       ├─ readyReplicas: 就绪副本数
       ├─ availableReplicas: 可用副本数
       └─ conditions: 状态条件
```

```yaml
# Deployment 滚动更新策略
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%        # 最多可超出25%，即12个Pod
      maxUnavailable: 25%  # 最多25%不可用，即保证75%可用
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: nginx:1.25
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

### 3.2 Node Controller

```
Node Controller 工作流程:

1. 监控 Node 状态变化
   │
   ├─▶ 节点心跳检测
   │   ├─ NodeLease 更新 (默认10s)
   │   └─ NodeStatus 更新 (默认1m)
   │
   ├─▶ 状态判定
   │   ├─ Ready → NotReady: 开始计时
   │   ├─ NotReady 持续 > pod-eviction-timeout: 驱逐Pod
   │   └─ Unknown: 联系不到kubelet
   │
   ├─▶ Taint 管理
   │   ├─ node.kubernetes.io/not-ready
   │   ├─ node.kubernetes.io/unreachable
   │   ├─ node.kubernetes.io/memory-pressure
   │   ├─ node.kubernetes.io/disk-pressure
   │   └─ node.kubernetes.io/pid-pressure
   │
   └─▶ Pod 驱逐
       ├─ 速率限制 (防止雪崩)
       │   ├─ --node-eviction-rate (默认0.1/s)
       │   └─ --secondary-node-eviction-rate (大规模故障时)
       └─ 添加 DeletionTimestamp 触发删除
```

### 3.3 Garbage Collector Controller

```
GC Controller 级联删除流程:

                    ┌─────────────────────┐
                    │     Deployment      │
                    │  (Owner Reference)  │
                    └──────────┬──────────┘
                               │ ownerReferences
                               ▼
                    ┌─────────────────────┐
                    │     ReplicaSet      │
                    │  (Owner Reference)  │
                    └──────────┬──────────┘
                               │ ownerReferences
                               ▼
                    ┌─────────────────────┐
                    │        Pods         │
                    └─────────────────────┘

删除策略:
├─ Foreground (前台级联删除)
│   └─ 先删除所有依赖资源，最后删除Owner
│
├─ Background (后台级联删除) [默认]
│   └─ 先删除Owner，GC异步清理依赖资源
│
└─ Orphan (孤儿策略)
    └─ 只删除Owner，保留依赖资源
```

```yaml
# 删除策略示例
# Foreground 删除
kubectl delete deployment web --cascade=foreground

# Background 删除 (默认)
kubectl delete deployment web --cascade=background

# Orphan 删除
kubectl delete deployment web --cascade=orphan
```

---

## 4. 关键配置参数 (Configuration Parameters)

### 4.1 通用参数

| 参数 | 默认值 | 推荐值 | 说明 |
|:---|:---|:---|:---|
| `--kubeconfig` | - | /etc/kubernetes/controller-manager.conf | API Server连接配置 |
| `--authentication-kubeconfig` | - | 同上 | 认证配置 |
| `--authorization-kubeconfig` | - | 同上 | 授权配置 |
| `--bind-address` | 0.0.0.0 | 0.0.0.0 | 监听地址 |
| `--secure-port` | 10257 | 10257 | 安全端口 |
| `--leader-elect` | true | true | 启用Leader选举 |
| `--leader-elect-lease-duration` | 15s | 15s | Lease持续时间 |
| `--leader-elect-renew-deadline` | 10s | 10s | Lease续约截止时间 |
| `--leader-elect-retry-period` | 2s | 2s | Lease重试周期 |

### 4.2 控制器通用参数

| 参数 | 默认值 | 推荐值 | 说明 |
|:---|:---|:---|:---|
| `--concurrent-deployment-syncs` | 5 | 5-10 | Deployment并发同步数 |
| `--concurrent-replicaset-syncs` | 5 | 5-10 | ReplicaSet并发同步数 |
| `--concurrent-endpoint-syncs` | 5 | 5-10 | Endpoints并发同步数 |
| `--concurrent-service-syncs` | 1 | 1-5 | Service并发同步数 |
| `--concurrent-gc-syncs` | 20 | 20-50 | GC并发同步数 |
| `--concurrent-namespace-syncs` | 10 | 10-20 | Namespace并发同步数 |
| `--concurrent-resource-quota-syncs` | 5 | 5-10 | ResourceQuota并发同步数 |
| `--concurrent-statefulset-syncs` | 5 | 5-10 | StatefulSet并发同步数 |
| `--concurrent-job-syncs` | 5 | 5-10 | Job并发同步数 |
| `--concurrent-horizontal-pod-autoscaler-syncs` | 5 | 5-10 | HPA并发同步数 |

### 4.3 节点控制器参数

| 参数 | 默认值 | 推荐值 | 说明 |
|:---|:---|:---|:---|
| `--node-monitor-period` | 5s | 5s | 节点监控周期 |
| `--node-monitor-grace-period` | 40s | 40s | 节点不响应宽限期 |
| `--pod-eviction-timeout` | 5m | 5m | Pod驱逐超时 |
| `--node-eviction-rate` | 0.1 | 0.1 | 正常情况驱逐速率(节点/秒) |
| `--secondary-node-eviction-rate` | 0.01 | 0.01 | 大规模故障驱逐速率 |
| `--large-cluster-size-threshold` | 50 | 50 | 大集群阈值 |
| `--unhealthy-zone-threshold` | 0.55 | 0.55 | 不健康Zone阈值 |

### 4.4 服务账号参数

| 参数 | 默认值 | 说明 |
|:---|:---|:---|
| `--service-account-private-key-file` | - | SA Token签名私钥 |
| `--root-ca-file` | - | 根CA证书(注入到SA) |
| `--use-service-account-credentials` | false | 使用独立SA凭证 |

### 4.5 云控制器参数

| 参数 | 默认值 | 说明 |
|:---|:---|:---|
| `--cloud-provider` | - | 云提供商(external/空) |
| `--external-cloud-volume-plugin` | - | 外部卷插件 |
| `--configure-cloud-routes` | true | 配置云路由 |
| `--allocate-node-cidrs` | false | 分配Node CIDR |
| `--cluster-cidr` | - | 集群Pod CIDR |
| `--service-cluster-ip-range` | - | Service IP范围 |
| `--node-cidr-mask-size` | 24 | 节点CIDR掩码大小 |

### 4.6 证书控制器参数

| 参数 | 默认值 | 说明 |
|:---|:---|:---|
| `--cluster-signing-cert-file` | - | 集群签名证书 |
| `--cluster-signing-key-file` | - | 集群签名私钥 |
| `--cluster-signing-duration` | 8760h (1年) | 签名证书有效期 |
| `--experimental-cluster-signing-duration` | - | 已弃用 |

---

## 5. Leader 选举机制 (Leader Election)

### 5.1 选举流程

```
Leader Election 流程:

1. 创建/获取 Lease 资源
   │
   ├─▶ 检查 Lease 是否存在
   │   ├─ 不存在: 创建新Lease并成为Leader
   │   └─ 存在: 检查持有者和过期时间
   │
   ├─▶ 竞争 Leader
   │   ├─ Lease未过期且是其他节点持有: 等待
   │   ├─ Lease已过期: 尝试获取
   │   └─ 自己持有: 续约
   │
   └─▶ Leader 职责
       ├─ 周期性续约 (renew-deadline内)
       ├─ 运行所有控制器
       └─ 失去Leader时停止控制器

    ┌──────────────────────────────────────────────────┐
    │                   Lease Object                    │
    │  ┌────────────────────────────────────────────┐  │
    │  │ Namespace: kube-system                      │  │
    │  │ Name: kube-controller-manager               │  │
    │  │ HolderIdentity: kcm-master-1                │  │
    │  │ LeaseDurationSeconds: 15                    │  │
    │  │ AcquireTime: 2024-01-01T00:00:00Z          │  │
    │  │ RenewTime: 2024-01-01T00:00:10Z            │  │
    │  │ LeaseTransitions: 3                         │  │
    │  └────────────────────────────────────────────┘  │
    └──────────────────────────────────────────────────┘
```

### 5.2 查看 Leader 状态

```bash
# 查看 Leader Lease
kubectl get lease -n kube-system kube-controller-manager -o yaml

# 输出示例
apiVersion: coordination.k8s.io/v1
kind: Lease
metadata:
  name: kube-controller-manager
  namespace: kube-system
spec:
  holderIdentity: master-1_xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  leaseDurationSeconds: 15
  acquireTime: "2024-01-01T00:00:00.000000Z"
  renewTime: "2024-01-01T00:05:00.000000Z"
  leaseTransitions: 1

# 查看当前 Leader
kubectl get endpoints -n kube-system kube-controller-manager -o yaml
```

---

## 6. 监控指标 (Monitoring Metrics)

### 6.1 关键指标表

| 指标名称 | 类型 | 说明 | 告警阈值 |
|:---|:---|:---|:---|
| `workqueue_adds_total` | Counter | 工作队列添加总数 | - |
| `workqueue_depth` | Gauge | 工作队列当前深度 | > 100 |
| `workqueue_queue_duration_seconds` | Histogram | 项在队列中等待时间 | p99 > 30s |
| `workqueue_work_duration_seconds` | Histogram | 处理项耗时 | p99 > 10s |
| `workqueue_retries_total` | Counter | 重试总数 | 异常增长 |
| `workqueue_longest_running_processor_seconds` | Gauge | 最长运行处理器时间 | > 300s |
| `leader_election_master_status` | Gauge | Leader状态(1=Leader) | - |
| `rest_client_requests_total` | Counter | API请求总数 | - |
| `rest_client_request_duration_seconds` | Histogram | API请求延迟 | p99 > 1s |
| `process_resident_memory_bytes` | Gauge | 内存使用 | > 4GB |
| `process_cpu_seconds_total` | Counter | CPU使用 | - |

### 6.2 Prometheus 告警规则

```yaml
groups:
- name: kube-controller-manager
  rules:
  - alert: KubeControllerManagerDown
    expr: absent(up{job="kube-controller-manager"} == 1)
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "kube-controller-manager is down"

  - alert: KubeControllerManagerNoLeader
    expr: sum(leader_election_master_status{job="kube-controller-manager"}) == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "kube-controller-manager has no leader"

  - alert: KubeControllerManagerWorkQueueDepthHigh
    expr: workqueue_depth{job="kube-controller-manager"} > 100
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Controller work queue depth is high"
      description: "Queue {{ $labels.name }} depth is {{ $value }}"

  - alert: KubeControllerManagerWorkQueueLatencyHigh
    expr: histogram_quantile(0.99, rate(workqueue_queue_duration_seconds_bucket{job="kube-controller-manager"}[5m])) > 30
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Controller work queue latency is high"

  - alert: KubeControllerManagerSyncLoopLatencyHigh
    expr: histogram_quantile(0.99, rate(workqueue_work_duration_seconds_bucket{job="kube-controller-manager"}[5m])) > 10
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Controller sync loop latency is high"

  - alert: KubeControllerManagerHighRetries
    expr: increase(workqueue_retries_total{job="kube-controller-manager"}[1h]) > 1000
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Controller has high retry rate"
```

---

## 7. 故障排查 (Troubleshooting)

### 7.1 常见问题诊断

| 症状 | 可能原因 | 诊断方法 | 解决方案 |
|:---|:---|:---|:---|
| **控制器不工作** | 非Leader/未启动 | 检查Leader状态 | 检查选举配置 |
| **Pod未创建** | RS/Deployment控制器问题 | 检查控制器日志 | 排查具体错误 |
| **Pod不被驱逐** | Node控制器配置 | 检查超时配置 | 调整eviction-timeout |
| **PVC未绑定** | PV控制器问题 | 检查PV/PVC状态 | 检查StorageClass |
| **GC不工作** | GC控制器阻塞 | 检查GC队列深度 | 增加并发数 |
| **Endpoint未更新** | Endpoint控制器延迟 | 检查队列深度 | 检查API Server负载 |
| **HPA不生效** | Metrics不可用 | 检查metrics-server | 确保metrics可用 |
| **Namespace删不掉** | Finalizer阻塞 | kubectl get ns -o yaml | 移除stuck finalizer |

### 7.2 诊断命令

```bash
# 检查 KCM 状态
systemctl status kube-controller-manager
journalctl -u kube-controller-manager -f --no-pager

# 检查 Leader 状态
kubectl get lease -n kube-system kube-controller-manager -o yaml

# 检查控制器指标
curl -k https://localhost:10257/metrics | grep workqueue_depth

# 检查特定控制器日志
journalctl -u kube-controller-manager | grep -i deployment
journalctl -u kube-controller-manager | grep -i "sync error"

# 检查事件
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# 检查 Deployment 状态
kubectl describe deployment <name>
kubectl rollout status deployment <name>
kubectl rollout history deployment <name>

# 检查 ReplicaSet
kubectl get rs -o wide
kubectl describe rs <name>

# 检查控制器健康
kubectl get componentstatuses  # 已弃用但可能仍可用
curl -k https://localhost:10257/healthz
```

### 7.3 常见日志模式

```bash
# 正常日志
I0101 00:00:00.000000   1 leaderelection.go:248] successfully acquired lease kube-system/kube-controller-manager
I0101 00:00:00.000000   1 event.go:282] Event: Normal Scheduled "Successfully assigned default/nginx to node-1"

# 警告日志
W0101 00:00:00.000000   1 reflector.go:324] watch of *v1.Pod ended with: too old resource version
W0101 00:00:00.000000   1 replica_set.go:503] ReplicaSet default/nginx-rs has timed out progressing

# 错误日志
E0101 00:00:00.000000   1 replica_set.go:456] Sync "default/nginx-rs" failed with pods "nginx-xxx" is forbidden
E0101 00:00:00.000000   1 gc_controller.go:274] garbage collector: error getting object for gvk xxx
```

---

## 8. 性能优化 (Performance Tuning)

### 8.1 大规模集群优化

| 优化项 | 默认值 | 大集群推荐值 | 说明 |
|:---|:---|:---|:---|
| `--concurrent-deployment-syncs` | 5 | 10-20 | 增加Deployment处理并发 |
| `--concurrent-gc-syncs` | 20 | 30-50 | 增加GC处理并发 |
| `--concurrent-endpoint-syncs` | 5 | 10-20 | 增加Endpoint处理并发 |
| `--kube-api-qps` | 20 | 100-200 | 增加API QPS限制 |
| `--kube-api-burst` | 30 | 200-400 | 增加API Burst限制 |

### 8.2 资源配置建议

| 集群规模 | CPU | 内存 | 说明 |
|:---|:---|:---|:---|
| 小型 (<100节点) | 0.5-1核 | 512MB-1GB | |
| 中型 (100-500节点) | 1-2核 | 1-2GB | |
| 大型 (500-1000节点) | 2-4核 | 2-4GB | |
| 超大型 (>1000节点) | 4-8核 | 4-8GB | |

---

## 9. 高可用部署 (High Availability)

### 9.1 HA 配置要点

```yaml
# 多实例部署配置要点
# 1. 所有实例使用相同配置
# 2. 启用Leader选举
# 3. 使用相同的service-account-private-key-file

# 关键参数
--leader-elect=true
--leader-elect-lease-duration=15s
--leader-elect-renew-deadline=10s
--leader-elect-retry-period=2s
--leader-elect-resource-lock=leases  # 推荐使用leases
--leader-elect-resource-namespace=kube-system
```

### 9.2 健康检查端点

| 端点 | 用途 | 检查内容 |
|:---|:---|:---|
| `/healthz` | 整体健康检查 | 所有检查项聚合 |
| `/healthz/leaderElection` | Leader选举检查 | 选举状态 |
| `/metrics` | Prometheus指标 | 运行时指标 |

```bash
# 健康检查
curl -k https://localhost:10257/healthz
curl -k https://localhost:10257/healthz?verbose
```

---

## 10. 生产环境 Checklist

### 10.1 部署检查

| 检查项 | 状态 | 说明 |
|:---|:---|:---|
| [ ] 多实例部署 | | 高可用保证 |
| [ ] Leader选举正常 | | 选举机制工作 |
| [ ] 证书配置正确 | | API认证正常 |
| [ ] SA私钥配置 | | Token签名正常 |
| [ ] 监控告警配置 | | 运维保障 |
| [ ] 资源限制配置 | | 防止资源耗尽 |
| [ ] 日志收集配置 | | 问题排查 |

### 10.2 运维检查

| 检查项 | 频率 | 命令/方法 |
|:---|:---|:---|
| Leader状态 | 每日 | 检查Lease资源 |
| 队列深度 | 每日 | 检查workqueue_depth指标 |
| 同步延迟 | 每日 | 检查workqueue_work_duration |
| 重试率 | 每日 | 检查workqueue_retries |
| 内存使用 | 每日 | 检查process_resident_memory |
| 证书有效期 | 每月 | openssl检查 |

---

## 附录: 控制器启动/禁用

```bash
# 禁用特定控制器
--controllers=*,-bootstrapsigner,-tokencleaner

# 只启用特定控制器
--controllers=deployment,replicaset,namespace

# 查看所有可用控制器
kube-controller-manager --help | grep -A 100 "controllers stringSlice"

# 常见控制器名称
# deployment, replicaset, statefulset, daemonset
# job, cronjob
# namespace, serviceaccount, endpoint, endpointslice
# persistentvolume-binder, attachdetach
# node, nodelifecycle, podgc
# garbagecollector, resourcequota
# horizontalpodautoscaling, disruption
# csrsigning, csrapproving, csrcleaner
# serviceaccount-token, root-ca-cert-publisher
```
