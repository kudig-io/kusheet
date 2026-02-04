# 69 - Lease 与 Leader 选举机制 (Lease & Leader Election)

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 高级

## Lease 机制架构概览

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         Kubernetes Lease 机制全景                                    │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │                          Lease 核心用途                                       │   │
│  │                                                                               │   │
│  │  ┌─────────────────────┐  ┌─────────────────────┐  ┌───────────────────────┐ │   │
│  │  │   Leader Election   │  │    Node Heartbeat   │  │   Custom Coordination │ │   │
│  │  │                     │  │                     │  │                       │ │   │
│  │  │ • kube-controller   │  │ • kubelet 心跳      │  │ • 分布式锁            │ │   │
│  │  │ • kube-scheduler    │  │ • 节点健康状态      │  │ • 任务协调            │ │   │
│  │  │ • cloud-controller  │  │ • 40s 租约          │  │ • 自定义 Operator     │ │   │
│  │  │ • custom operators  │  │                     │  │                       │ │   │
│  │  └─────────────────────┘  └─────────────────────┘  └───────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │                          Lease 工作流程                                       │   │
│  │                                                                               │   │
│  │  ┌────────────┐    ┌────────────┐    ┌────────────┐    ┌────────────────┐   │   │
│  │  │   Acquire  │───▶│   Hold     │───▶│   Renew    │───▶│    Release     │   │   │
│  │  │   获取租约  │    │   持有租约  │    │   续租     │    │    释放租约    │   │   │
│  │  └────────────┘    └────────────┘    └────────────┘    └────────────────┘   │   │
│  │        │                 │                 │                  │             │   │
│  │        ▼                 ▼                 ▼                  ▼             │   │
│  │  ┌────────────┐    ┌────────────┐    ┌────────────┐    ┌────────────────┐   │   │
│  │  │ Create or  │    │ Execute    │    │ Update     │    │ Delete or      │   │   │
│  │  │ Update     │    │ Leader     │    │ renewTime  │    │ Let Expire     │   │   │
│  │  │ Lease Obj  │    │ Logic      │    │ Field      │    │                │   │   │
│  │  └────────────┘    └────────────┘    └────────────┘    └────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │                          时间线参数关系                                       │   │
│  │                                                                               │   │
│  │  |◄─────────────── LeaseDuration (15s) ──────────────►|                     │   │
│  │  |◄──── RenewDeadline (10s) ────►|                                          │   │
│  │  |◄── RetryPeriod (2s) ──►|                                                 │   │
│  │                                                                               │   │
│  │  约束关系: LeaseDuration > RenewDeadline > RetryPeriod × 2                   │   │
│  │                                                                               │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Lease 对象详解

### Lease 字段说明

| 字段 | 类型 | 说明 | 典型值 |
|-----|-----|------|--------|
| `spec.holderIdentity` | string | 当前持有者标识 (通常是 Pod 名) | `controller-manager-xxx` |
| `spec.leaseDurationSeconds` | int | 租约持续时间 (秒) | 15-40 |
| `spec.acquireTime` | MicroTime | 获取租约的时间 | RFC3339 微秒 |
| `spec.renewTime` | MicroTime | 最后续租时间 | RFC3339 微秒 |
| `spec.leaseTransitions` | int | 租约转移次数 (Leader 变更计数) | 递增整数 |

### 系统 Lease 用途矩阵

| Lease 名称 | 命名空间 | 用途 | 持有者 | 租约时长 |
|-------|---------|------|--------|---------|
| `kube-controller-manager` | kube-system | 控制器管理器 Leader 选举 | CM Pod | 15s |
| `kube-scheduler` | kube-system | 调度器 Leader 选举 | Scheduler Pod | 15s |
| `cloud-controller-manager` | kube-system | 云控制器 Leader 选举 | CCM Pod | 15s |
| `<node-name>` | kube-node-lease | 节点心跳 | kubelet | 40s |
| `kube-apiserver-<id>` | kube-system | API Server 身份 (v1.26+) | API Server | 3600s |

### 完整 Lease 对象示例

```yaml
# 节点心跳 Lease
apiVersion: coordination.k8s.io/v1
kind: Lease
metadata:
  name: node-worker-1
  namespace: kube-node-lease
  ownerReferences:
    - apiVersion: v1
      kind: Node
      name: node-worker-1
      uid: abc123-def456
  labels:
    node.kubernetes.io/instance-type: ecs.g6.xlarge
spec:
  holderIdentity: node-worker-1
  leaseDurationSeconds: 40
  acquireTime: "2024-01-15T10:00:00.000000Z"
  renewTime: "2024-01-15T10:30:25.123456Z"
  leaseTransitions: 0
---
# 控制器 Leader 选举 Lease
apiVersion: coordination.k8s.io/v1
kind: Lease
metadata:
  name: kube-controller-manager
  namespace: kube-system
spec:
  holderIdentity: kube-controller-manager-master-1_abc123
  leaseDurationSeconds: 15
  acquireTime: "2024-01-15T08:00:00.000000Z"
  renewTime: "2024-01-15T10:30:22.456789Z"
  leaseTransitions: 3
```

## Leader 选举参数详解

### 核心参数

| 参数 | 默认值 | 说明 | 调优建议 |
|-----|-------|------|---------|
| `--leader-elect` | true | 启用 Leader 选举 | 生产环境必须启用 |
| `--leader-elect-lease-duration` | 15s | 租约持续时间 | 网络不稳定可增加 |
| `--leader-elect-renew-deadline` | 10s | 续租截止时间 | < leaseDuration |
| `--leader-elect-retry-period` | 2s | 重试间隔 | < renewDeadline/2 |
| `--leader-elect-resource-lock` | leases | 锁资源类型 | 保持默认 |
| `--leader-elect-resource-name` | 组件名 | 锁资源名称 | 自定义组件需指定 |
| `--leader-elect-resource-namespace` | kube-system | 锁资源命名空间 | 根据需要调整 |

### 参数关系与约束

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Leader 选举时间参数关系                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  LeaseDuration = 15s (租约有效期)                                        │
│  ├── RenewDeadline = 10s (必须在此时间内完成续租)                        │
│  │   └── RetryPeriod = 2s (续租重试间隔)                                 │
│  │                                                                       │
│  时间线:                                                                 │
│  |←─────────────── LeaseDuration (15s) ───────────────→|                │
│  |←───── RenewDeadline (10s) ─────→|                   |                │
│  |←─ Retry ─→|←─ Retry ─→|←─ Retry ─→|←─ Retry ─→|    |                │
│  |   (2s)    |   (2s)    |   (2s)    |   (2s)    |    |                │
│  T0          T2          T4          T6          T8   T10  ...  T15     │
│  ↑           ↑           ↑           ↑           ↑         ↑           │
│  获取        重试1       重试2       重试3       重试4      续租        │
│  租约                                            (最后机会) 失败        │
│                                                                          │
│  约束规则:                                                               │
│  1. LeaseDuration > RenewDeadline                                       │
│  2. RenewDeadline > RetryPeriod × 2                                     │
│  3. RetryPeriod 应允许多次重试机会                                       │
│                                                                          │
│  推荐配置:                                                               │
│  - 稳定网络: 15s / 10s / 2s (默认)                                      │
│  - 不稳定网络: 30s / 20s / 4s                                           │
│  - 高可用要求: 10s / 8s / 2s (更快故障转移)                             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## client-go Leader 选举实现

### 完整示例代码

```go
package main

import (
    "context"
    "flag"
    "fmt"
    "os"
    "os/signal"
    "syscall"
    "time"

    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/rest"
    "k8s.io/client-go/tools/clientcmd"
    "k8s.io/client-go/tools/leaderelection"
    "k8s.io/client-go/tools/leaderelection/resourcelock"
    "k8s.io/klog/v2"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

var (
    leaseLockName      = flag.String("lease-lock-name", "my-controller-lock", "租约锁名称")
    leaseLockNamespace = flag.String("lease-lock-namespace", "default", "租约锁命名空间")
    leaseDuration      = flag.Duration("lease-duration", 15*time.Second, "租约持续时间")
    renewDeadline      = flag.Duration("renew-deadline", 10*time.Second, "续租截止时间")
    retryPeriod        = flag.Duration("retry-period", 2*time.Second, "重试间隔")
)

func main() {
    klog.InitFlags(nil)
    flag.Parse()

    // 获取 Pod 身份
    id := os.Getenv("POD_NAME")
    if id == "" {
        hostname, _ := os.Hostname()
        id = hostname
    }
    
    klog.Infof("Starting leader election with identity: %s", id)

    // 创建 Kubernetes 客户端
    config, err := getConfig()
    if err != nil {
        klog.Fatalf("Failed to get config: %v", err)
    }

    clientset, err := kubernetes.NewForConfig(config)
    if err != nil {
        klog.Fatalf("Failed to create clientset: %v", err)
    }

    // 创建上下文，支持优雅退出
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    // 监听终止信号
    sigCh := make(chan os.Signal, 1)
    signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
    go func() {
        sig := <-sigCh
        klog.Infof("Received signal %v, shutting down", sig)
        cancel()
    }()

    // 创建 Lease 锁
    lock := &resourcelock.LeaseLock{
        LeaseMeta: metav1.ObjectMeta{
            Name:      *leaseLockName,
            Namespace: *leaseLockNamespace,
        },
        Client: clientset.CoordinationV1(),
        LockConfig: resourcelock.ResourceLockConfig{
            Identity: id,
        },
    }

    // 配置 Leader 选举
    leaderElectionConfig := leaderelection.LeaderElectionConfig{
        Lock:            lock,
        ReleaseOnCancel: true,  // 取消时释放租约
        LeaseDuration:   *leaseDuration,
        RenewDeadline:   *renewDeadline,
        RetryPeriod:     *retryPeriod,
        Callbacks: leaderelection.LeaderCallbacks{
            OnStartedLeading: func(ctx context.Context) {
                klog.Info("Started leading - running controller logic")
                runController(ctx)
            },
            OnStoppedLeading: func() {
                klog.Info("Stopped leading")
                // 可选: 清理资源或退出
                os.Exit(0)
            },
            OnNewLeader: func(identity string) {
                if identity == id {
                    klog.Info("Still the leader")
                    return
                }
                klog.Infof("New leader elected: %s", identity)
            },
        },
    }

    // 启动 Leader 选举
    leaderelection.RunOrDie(ctx, leaderElectionConfig)
}

func getConfig() (*rest.Config, error) {
    // 优先使用集群内配置
    config, err := rest.InClusterConfig()
    if err == nil {
        return config, nil
    }

    // 回退到 kubeconfig
    kubeconfig := os.Getenv("KUBECONFIG")
    if kubeconfig == "" {
        kubeconfig = os.Getenv("HOME") + "/.kube/config"
    }
    return clientcmd.BuildConfigFromFlags("", kubeconfig)
}

func runController(ctx context.Context) {
    klog.Info("Controller is running...")
    
    ticker := time.NewTicker(5 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-ctx.Done():
            klog.Info("Controller context cancelled, stopping")
            return
        case <-ticker.C:
            // 执行控制器逻辑
            klog.Info("Performing controller work...")
            doWork()
        }
    }
}

func doWork() {
    // 实际的控制器工作逻辑
    klog.Info("Processing work items...")
}
```

### controller-runtime Leader 选举

```go
package main

import (
    "flag"
    "os"
    "time"

    "k8s.io/apimachinery/pkg/runtime"
    utilruntime "k8s.io/apimachinery/pkg/util/runtime"
    clientgoscheme "k8s.io/client-go/kubernetes/scheme"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/healthz"
    "sigs.k8s.io/controller-runtime/pkg/log/zap"
    "sigs.k8s.io/controller-runtime/pkg/manager"
)

var (
    scheme   = runtime.NewScheme()
    setupLog = ctrl.Log.WithName("setup")
)

func init() {
    utilruntime.Must(clientgoscheme.AddToScheme(scheme))
}

func main() {
    var (
        metricsAddr          string
        healthProbeAddr      string
        enableLeaderElection bool
        leaderElectionID     string
        leaseDuration        time.Duration
        renewDeadline        time.Duration
        retryPeriod          time.Duration
    )

    flag.StringVar(&metricsAddr, "metrics-addr", ":8080", "Metrics 地址")
    flag.StringVar(&healthProbeAddr, "health-probe-addr", ":8081", "健康检查地址")
    flag.BoolVar(&enableLeaderElection, "leader-elect", true, "启用 Leader 选举")
    flag.StringVar(&leaderElectionID, "leader-election-id", "my-controller", "Leader 选举 ID")
    flag.DurationVar(&leaseDuration, "lease-duration", 15*time.Second, "租约持续时间")
    flag.DurationVar(&renewDeadline, "renew-deadline", 10*time.Second, "续租截止时间")
    flag.DurationVar(&retryPeriod, "retry-period", 2*time.Second, "重试间隔")

    opts := zap.Options{Development: true}
    opts.BindFlags(flag.CommandLine)
    flag.Parse()

    ctrl.SetLogger(zap.New(zap.UseFlagOptions(&opts)))

    // 创建 Manager
    mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
        Scheme:                  scheme,
        MetricsBindAddress:      metricsAddr,
        HealthProbeBindAddress:  healthProbeAddr,
        
        // Leader 选举配置
        LeaderElection:          enableLeaderElection,
        LeaderElectionID:        leaderElectionID,
        LeaderElectionNamespace: getLeaderElectionNamespace(),
        LeaseDuration:           &leaseDuration,
        RenewDeadline:           &renewDeadline,
        RetryPeriod:             &retryPeriod,
        
        // Leader 选举释放配置
        LeaderElectionReleaseOnCancel: true,
    })
    if err != nil {
        setupLog.Error(err, "unable to create manager")
        os.Exit(1)
    }

    // 注册健康检查
    if err := mgr.AddHealthzCheck("healthz", healthz.Ping); err != nil {
        setupLog.Error(err, "unable to set up health check")
        os.Exit(1)
    }
    if err := mgr.AddReadyzCheck("readyz", healthz.Ping); err != nil {
        setupLog.Error(err, "unable to set up ready check")
        os.Exit(1)
    }

    // 添加 Leader 选举就绪检查
    if err := mgr.AddReadyzCheck("leader-election", mgr.GetLeaderElectionElector().Check); err != nil {
        setupLog.Error(err, "unable to set up leader election ready check")
        os.Exit(1)
    }

    // 设置控制器
    if err := setupControllers(mgr); err != nil {
        setupLog.Error(err, "unable to setup controllers")
        os.Exit(1)
    }

    setupLog.Info("starting manager")
    if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
        setupLog.Error(err, "problem running manager")
        os.Exit(1)
    }
}

func getLeaderElectionNamespace() string {
    // 优先使用环境变量
    if ns := os.Getenv("LEADER_ELECTION_NAMESPACE"); ns != "" {
        return ns
    }
    // 尝试从 ServiceAccount 获取
    if data, err := os.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/namespace"); err == nil {
        return string(data)
    }
    return "default"
}

func setupControllers(mgr manager.Manager) error {
    // 注册控制器
    // if err := (&MyReconciler{
    //     Client: mgr.GetClient(),
    //     Scheme: mgr.GetScheme(),
    // }).SetupWithManager(mgr); err != nil {
    //     return err
    // }
    return nil
}
```

## Kubernetes Deployment 配置

```yaml
# leader-election-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-controller
  namespace: my-system
spec:
  replicas: 3  # 多副本高可用
  selector:
    matchLabels:
      app: my-controller
  template:
    metadata:
      labels:
        app: my-controller
    spec:
      serviceAccountName: my-controller
      containers:
        - name: controller
          image: my-controller:v1.0.0
          args:
            - --leader-elect=true
            - --leader-election-id=my-controller
            - --lease-duration=15s
            - --renew-deadline=10s
            - --retry-period=2s
            - --metrics-addr=:8080
            - --health-probe-addr=:8081
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: LEADER_ELECTION_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          ports:
            - name: metrics
              containerPort: 8080
            - name: health
              containerPort: 8081
          livenessProbe:
            httpGet:
              path: /healthz
              port: health
            initialDelaySeconds: 15
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /readyz
              port: health
            initialDelaySeconds: 5
            periodSeconds: 5
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
      # 反亲和性 - 分散到不同节点
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: my-controller
                topologyKey: kubernetes.io/hostname
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-controller
  namespace: my-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: my-controller-leader-election
  namespace: my-system
rules:
  # Leader 选举所需权限
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: my-controller-leader-election
  namespace: my-system
subjects:
  - kind: ServiceAccount
    name: my-controller
    namespace: my-system
roleRef:
  kind: Role
  name: my-controller-leader-election
  apiGroup: rbac.authorization.k8s.io
```

## 节点心跳 Lease 机制

### kubelet 心跳配置

| kubelet 参数 | 默认值 | 说明 | 调优建议 |
|------------|-------|------|---------|
| `--node-lease-duration-seconds` | 40 | 节点租约持续时间 | 大集群可增加 |
| `--node-status-update-frequency` | 10s | NodeStatus 更新频率 | 保持默认或减少 |
| `--node-status-report-frequency` | 5m | 完整状态报告频率 | 保持默认 |

### 节点心跳工作流程

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         节点心跳与健康检测                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  kubelet                          kube-node-lease                API Server     │
│     │                                  │                             │          │
│     │  ─── 创建/更新 Lease ──────────▶ │                             │          │
│     │       (每 10s)                   │                             │          │
│     │                                  │                             │          │
│     │  ─── 更新 NodeStatus ──────────────────────────────────────▶ │          │
│     │       (每 10s, 仅变更时)                                       │          │
│     │                                  │                             │          │
│     │                                  │    node-lifecycle-controller │          │
│     │                                  │           │                  │          │
│     │                                  │  ◄─────── 检查 Lease ────── │          │
│     │                                  │           │                  │          │
│     │                                  │           ▼                  │          │
│     │                                  │    Lease.renewTime          │          │
│     │                                  │    + leaseDuration          │          │
│     │                                  │    < now()?                 │          │
│     │                                  │           │                  │          │
│     │                                  │     Yes   │   No            │          │
│     │                                  │     ┌─────┴─────┐           │          │
│     │                                  │     ▼           ▼           │          │
│     │                                  │  标记节点    节点健康        │          │
│     │                                  │  NotReady                   │          │
│     │                                  │     │                       │          │
│     │                                  │     ▼                       │          │
│     │                                  │  等待宽限期                  │          │
│     │                                  │  (pod-eviction-timeout)     │          │
│     │                                  │     │                       │          │
│     │                                  │     ▼                       │          │
│     │                                  │  驱逐 Pod                   │          │
│     │                                  │                             │          │
└─────────────────────────────────────────────────────────────────────────────────┘

时间参数:
- Lease Duration: 40s (节点租约有效期)
- Node Monitor Grace Period: 40s (节点监控宽限期)
- Pod Eviction Timeout: 5m (Pod 驱逐超时)

判定流程:
1. kubelet 每 10s 更新 Lease.renewTime
2. node-lifecycle-controller 检查: now() - renewTime > leaseDuration?
3. 如果超时, 标记节点为 NotReady
4. NotReady 超过 pod-eviction-timeout 后驱逐 Pod
```

## Lease 监控与告警

### 监控命令

```bash
# ==================== 查看 Lease ====================

# 查看所有 Lease
kubectl get leases -A

# 查看节点心跳 Lease
kubectl get leases -n kube-node-lease

# 查看控制平面 Leader 选举
kubectl get leases -n kube-system

# 详细查看特定 Lease
kubectl get lease kube-controller-manager -n kube-system -o yaml

# 查看 Lease 变更历史
kubectl get lease kube-scheduler -n kube-system -o jsonpath='{.spec.leaseTransitions}'

# ==================== 监控 Leader 状态 ====================

# 查看当前 Leader
kubectl get lease kube-controller-manager -n kube-system \
  -o jsonpath='{.spec.holderIdentity}'

# 查看最后续租时间
kubectl get lease kube-controller-manager -n kube-system \
  -o jsonpath='{.spec.renewTime}'

# 批量查看所有控制平面 Leader
for lease in kube-controller-manager kube-scheduler cloud-controller-manager; do
  echo "=== $lease ==="
  kubectl get lease $lease -n kube-system -o jsonpath=\
'{.spec.holderIdentity} (transitions: {.spec.leaseTransitions}, renewed: {.spec.renewTime})'
  echo
done

# ==================== 节点健康检查 ====================

# 查看所有节点 Lease 的续租时间
kubectl get leases -n kube-node-lease \
  -o custom-columns=NODE:.metadata.name,RENEWED:.spec.renewTime

# 找出可能不健康的节点 (Lease 未更新)
kubectl get leases -n kube-node-lease -o json | \
  jq -r '.items[] | select(
    (now - (.spec.renewTime | fromdateiso8601)) > 60
  ) | .metadata.name'
```

### Prometheus 监控规则

```yaml
# prometheus-lease-rules.yaml
groups:
  - name: lease-monitoring
    interval: 30s
    rules:
      # Leader 选举转换次数
      - record: kubernetes:leader_election:transitions_total
        expr: |
          max by (lease_name) (
            kube_lease_spec_lease_transitions{namespace="kube-system"}
          )

      # 租约到期时间
      - record: kubernetes:lease:time_until_expiry_seconds
        expr: |
          (
            kube_lease_spec_renew_time + 
            kube_lease_spec_lease_duration_seconds
          ) - time()

      # Leader 选举健康检查
      - alert: LeaderElectionLost
        expr: |
          changes(kube_lease_spec_holder_identity{namespace="kube-system"}[5m]) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Leader 选举频繁切换"
          description: "{{ $labels.lease_name }} 在5分钟内切换了超过2次 Leader"

      # 控制平面 Leader 丢失
      - alert: ControlPlaneLeaderMissing
        expr: |
          absent(kube_lease_spec_holder_identity{
            namespace="kube-system",
            lease_name=~"kube-controller-manager|kube-scheduler"
          })
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "控制平面 Leader 丢失"
          description: "{{ $labels.lease_name }} 没有 Leader"

      # 节点心跳超时
      - alert: NodeHeartbeatTimeout
        expr: |
          (time() - kube_lease_spec_renew_time{namespace="kube-node-lease"}) 
          > kube_lease_spec_lease_duration_seconds{namespace="kube-node-lease"} * 1.5
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "节点心跳超时"
          description: "节点 {{ $labels.lease_name }} 的 Lease 超过1.5倍租约时间未更新"

      # 大量 Leader 转换
      - alert: HighLeaderTransitionRate
        expr: |
          increase(kube_lease_spec_lease_transitions{namespace="kube-system"}[1h]) > 5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Leader 转换频率过高"
          description: "{{ $labels.lease_name }} 在1小时内转换了 {{ $value }} 次"
```

## Leader 选举故障排查

### 常见问题诊断

| 问题 | 症状 | 排查方法 | 解决方案 |
|-----|------|---------|---------|
| **双主** | 两个实例同时工作 | 检查 NTP 同步、网络分区 | 修复时间同步、检查网络 |
| **无主** | 无实例执行工作 | 检查 API Server 连接、RBAC | 修复网络、检查权限 |
| **频繁切换** | Leader 频繁变化 | 检查网络稳定性、资源 | 增加租约时间、优化网络 |
| **续租失败** | Leader 意外丢失 | 检查 API Server 负载 | 扩容 API Server、优化参数 |
| **选举超时** | 新 Leader 选举慢 | 检查 etcd 性能 | 优化 etcd、调整参数 |

### 故障排查脚本

```bash
#!/bin/bash
# lease-troubleshoot.sh

echo "=== 控制平面 Leader 状态 ==="
for component in kube-controller-manager kube-scheduler cloud-controller-manager; do
  echo "--- $component ---"
  kubectl get lease $component -n kube-system -o jsonpath=\
'Holder: {.spec.holderIdentity}
Transitions: {.spec.leaseTransitions}
Renewed: {.spec.renewTime}
Duration: {.spec.leaseDurationSeconds}s
' 2>/dev/null || echo "Not found"
  echo
done

echo "=== 节点 Lease 状态 ==="
kubectl get leases -n kube-node-lease \
  -o custom-columns=\
'NODE:.metadata.name,RENEWED:.spec.renewTime,DURATION:.spec.leaseDurationSeconds'

echo ""
echo "=== 可能不健康的节点 (Lease > 60s 未更新) ==="
kubectl get leases -n kube-node-lease -o json | \
  jq -r '.items[] | select(
    (now - (.spec.renewTime | fromdateiso8601)) > 60
  ) | "\(.metadata.name): \(now - (.spec.renewTime | fromdateiso8601) | floor)s ago"'

echo ""
echo "=== 最近的 Leader 变更事件 ==="
kubectl get events -n kube-system \
  --field-selector reason=LeaderElection \
  --sort-by='.lastTimestamp' \
  | tail -10

echo ""
echo "=== NTP 同步状态 ==="
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "--- $node ---"
  kubectl debug node/$node -it --image=busybox -- \
    /bin/sh -c "ntpq -p 2>/dev/null || echo 'NTP check not available'" &
done
wait
```

## Lease 最佳实践

### 参数调优建议

| 场景 | LeaseDuration | RenewDeadline | RetryPeriod | 说明 |
|-----|---------------|---------------|-------------|------|
| **默认** | 15s | 10s | 2s | 标准配置 |
| **高可用** | 10s | 8s | 2s | 更快故障转移 |
| **不稳定网络** | 30s | 20s | 4s | 容忍网络抖动 |
| **大规模集群** | 60s | 40s | 5s | 减少 API 压力 |
| **边缘场景** | 120s | 90s | 10s | 高延迟网络 |

### 最佳实践清单

- [ ] **启用 Leader 选举**: 生产环境必须启用
- [ ] **合理设置超时**: LeaseDuration > RenewDeadline > RetryPeriod × 2
- [ ] **NTP 时间同步**: 确保集群节点时间同步
- [ ] **监控 Transitions**: 关注 leaseTransitions 指标
- [ ] **优雅退出**: 配置 ReleaseOnCancel=true
- [ ] **唯一身份**: 使用 Pod 名作为 identity
- [ ] **反亲和性**: 多副本分散到不同节点
- [ ] **健康检查**: 配置 liveness/readiness 探针
- [ ] **RBAC 权限**: 最小权限原则
- [ ] **告警配置**: 监控 Leader 切换和心跳

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| v1.14 | Node Lease GA |
| v1.17 | Lease 成为默认 Leader 选举资源 |
| v1.20 | Endpoints 不再用于选举 |
| v1.26 | API Server Identity Lease |
| v1.27 | Lease 优化，减少 API 调用 |
| v1.29 | 更细粒度的 Lease 监控指标 |

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)
