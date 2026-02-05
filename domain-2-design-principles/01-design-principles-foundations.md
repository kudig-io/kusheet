# 11 - Kubernetes设计原则与哲学 (Design Principles & Philosophy)

## 核心设计理念

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Kubernetes设计原则金字塔                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                           ┌─────────────┐                                   │
│                           │  可扩展性   │                                   │
│                           │ Extensibility│                                   │
│                           └──────┬──────┘                                   │
│                                  │                                          │
│                    ┌─────────────┴─────────────┐                            │
│                    │        自愈能力           │                            │
│                    │    Self-Healing           │                            │
│                    └─────────────┬─────────────┘                            │
│                                  │                                          │
│              ┌───────────────────┴───────────────────┐                      │
│              │          声明式配置                    │                      │
│              │    Declarative Configuration          │                      │
│              └───────────────────┬───────────────────┘                      │
│                                  │                                          │
│        ┌─────────────────────────┴─────────────────────────┐                │
│        │              控制器模式 (Controller Pattern)       │                │
│        │         期望状态 → 观察 → 比较 → 行动 → 循环        │                │
│        └─────────────────────────┬─────────────────────────┘                │
│                                  │                                          │
│   ┌──────────────────────────────┴──────────────────────────────┐           │
│   │                  API驱动 (API-Driven)                        │           │
│   │    一切皆资源 (Everything is a Resource)                     │           │
│   └──────────────────────────────┬──────────────────────────────┘           │
│                                  │                                          │
│   ┌──────────────────────────────┴──────────────────────────────┐           │
│   │              不可变基础设施 (Immutable Infrastructure)       │           │
│   └─────────────────────────────────────────────────────────────┘           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 设计原则对比矩阵

| 原则 | 英文名 | 核心思想 | 实现方式 | 典型应用 |
|-----|-------|---------|---------|---------|
| 声明式 | Declarative | 描述"是什么"而非"怎么做" | YAML/JSON资源定义 | Deployment、Service |
| 控制循环 | Control Loop | 持续调谐期望与实际状态 | Controller/Operator | ReplicaSet控制器 |
| 松耦合 | Loose Coupling | 组件间通过API交互 | RESTful API | 各组件独立部署 |
| 可组合 | Composable | 小组件组合成复杂系统 | Pod组合容器 | Sidecar模式 |
| 可移植 | Portable | 跨环境一致性运行 | 抽象层设计 | CRI/CNI/CSI |
| 自愈 | Self-Healing | 自动检测并恢复故障 | 健康检查+重启策略 | livenessProbe |
| 水平扩展 | Horizontal Scaling | 通过副本数扩展 | HPA/ReplicaSet | 无状态应用扩缩 |
| 服务发现 | Service Discovery | 自动注册和发现服务 | DNS/Service | CoreDNS |

## 声明式 vs 命令式

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      声明式(Declarative) vs 命令式(Imperative)               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  命令式 (Imperative)                    声明式 (Declarative)                │
│  ┌─────────────────────┐               ┌─────────────────────┐              │
│  │ 1. 创建Pod          │               │ 期望状态:           │              │
│  │ 2. 等待启动         │               │   replicas: 3       │              │
│  │ 3. 检查健康         │      VS       │   image: nginx:1.21 │              │
│  │ 4. 如果失败重试     │               │   ports: [80]       │              │
│  │ 5. 创建Service      │               │                     │              │
│  │ 6. ...              │               │ 系统自动达成期望    │              │
│  └─────────────────────┘               └─────────────────────┘              │
│                                                                              │
│  特点:                                  特点:                               │
│  • 需要知道"怎么做"                    • 只需声明"是什么"                  │
│  • 需要处理所有异常                    • 系统自动处理异常                  │
│  • 难以实现幂等性                      • 天然幂等                          │
│  • 操作顺序敏感                        • 顺序无关                          │
│                                                                              │
│  kubectl命令对比:                                                           │
│  ┌────────────────────────────────┬────────────────────────────────┐        │
│  │ 命令式                         │ 声明式                         │        │
│  ├────────────────────────────────┼────────────────────────────────┤        │
│  │ kubectl run nginx --image=... │ kubectl apply -f nginx.yaml    │        │
│  │ kubectl scale --replicas=3    │ (修改yaml后) kubectl apply     │        │
│  │ kubectl set image deploy/...  │ kubectl apply -f updated.yaml  │        │
│  │ kubectl delete pod nginx      │ kubectl delete -f nginx.yaml   │        │
│  └────────────────────────────────┴────────────────────────────────┘        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 声明式API设计原则

| 原则 | 说明 | 示例 |
|-----|------|-----|
| 幂等性(Idempotency) | 多次执行结果相同 | apply同一YAML多次结果一致 |
| 可观察性(Observable) | 状态可查询 | `kubectl get pod -o yaml` |
| 可预测性(Predictable) | 相同输入产生相同输出 | 声明3副本则始终维持3个 |
| 可组合性(Composable) | 资源可组合 | Deployment引用ConfigMap |
| 版本化(Versioned) | API有版本 | v1, v1beta1, v1alpha1 |

## 控制器模式详解 (Controller Pattern)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           控制器调谐循环                                     │
│                      (Controller Reconciliation Loop)                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│     ┌───────────────────────────────────────────────────────────────┐       │
│     │                      期望状态 (Desired State)                  │       │
│     │                 spec.replicas = 3                              │       │
│     └───────────────────────────┬───────────────────────────────────┘       │
│                                 │                                           │
│                                 ▼                                           │
│     ┌───────────────────────────────────────────────────────────────┐       │
│     │                         比较 (Diff)                           │       │
│     │              期望状态 vs 实际状态                              │       │
│     └───────────────────────────┬───────────────────────────────────┘       │
│                                 │                                           │
│              ┌──────────────────┴──────────────────┐                        │
│              ▼                                     ▼                        │
│     ┌─────────────────┐                   ┌─────────────────┐              │
│     │   状态一致      │                   │   状态不一致    │              │
│     │   (No Action)   │                   │   (Take Action) │              │
│     └────────┬────────┘                   └────────┬────────┘              │
│              │                                     │                        │
│              │                                     ▼                        │
│              │                   ┌─────────────────────────────────┐        │
│              │                   │         执行调谐操作            │        │
│              │                   │  • 创建缺少的Pod               │        │
│              │                   │  • 删除多余的Pod               │        │
│              │                   │  • 更新配置                    │        │
│              │                   └─────────────────┬───────────────┘        │
│              │                                     │                        │
│              │                                     ▼                        │
│              │                   ┌─────────────────────────────────┐        │
│              │                   │      更新实际状态 (Status)      │        │
│              └───────────────────┤      status.replicas = 3        │        │
│                                  └─────────────────────────────────┘        │
│                                           │                                 │
│                                           │ 等待下一次触发                  │
│                                           │ (Event/Timer)                   │
│                                           ▼                                 │
│                                  ┌─────────────────┐                        │
│                                  │   重新开始循环  │                        │
│                                  └─────────────────┘                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 内置控制器列表

| 控制器 | 职责 | 观察资源 | 操作资源 |
|-------|-----|---------|---------|
| ReplicaSet Controller | 维护Pod副本数 | ReplicaSet | Pod |
| Deployment Controller | 管理ReplicaSet滚动更新 | Deployment | ReplicaSet |
| StatefulSet Controller | 有状态应用管理 | StatefulSet | Pod, PVC |
| DaemonSet Controller | 每节点运行一个Pod | DaemonSet, Node | Pod |
| Job Controller | 批处理任务 | Job | Pod |
| CronJob Controller | 定时任务 | CronJob | Job |
| Endpoint Controller | 维护Endpoint列表 | Service, Pod | Endpoints |
| EndpointSlice Controller | 维护EndpointSlice | Service, Pod | EndpointSlice |
| Namespace Controller | 命名空间清理 | Namespace | 各类资源 |
| ServiceAccount Controller | 服务账号管理 | Namespace | ServiceAccount, Secret |
| Node Controller | 节点状态管理 | Node | Pod (驱逐) |
| PV Controller | 持久卷绑定 | PV, PVC | PV, PVC |
| Garbage Collector | 级联删除 | OwnerReferences | 各类资源 |

### 控制器伪代码

```go
// 控制器核心逻辑伪代码
func (c *Controller) Run(stopCh <-chan struct{}) {
    // 启动Informer
    c.informerFactory.Start(stopCh)
    
    // 等待缓存同步
    if !cache.WaitForCacheSync(stopCh, c.informer.HasSynced) {
        return
    }
    
    // 启动工作协程
    for i := 0; i < c.workers; i++ {
        go wait.Until(c.runWorker, time.Second, stopCh)
    }
    
    <-stopCh
}

func (c *Controller) runWorker() {
    for c.processNextWorkItem() {
    }
}

func (c *Controller) processNextWorkItem() bool {
    // 从队列获取key
    key, quit := c.workqueue.Get()
    if quit {
        return false
    }
    defer c.workqueue.Done(key)
    
    // 执行调谐逻辑
    err := c.syncHandler(key.(string))
    if err == nil {
        // 成功则忘记此key
        c.workqueue.Forget(key)
        return true
    }
    
    // 失败则重新入队(带退避)
    c.workqueue.AddRateLimited(key)
    return true
}

func (c *Controller) syncHandler(key string) error {
    namespace, name, _ := cache.SplitMetaNamespaceKey(key)
    
    // 1. 获取期望状态 (Desired State)
    obj, err := c.lister.Get(name)
    if errors.IsNotFound(err) {
        // 资源已删除，执行清理
        return c.cleanup(namespace, name)
    }
    
    // 2. 获取实际状态 (Actual State)
    actual, err := c.getActualState(namespace, name)
    
    // 3. 比较差异 (Diff)
    diff := c.calculateDiff(obj.Spec, actual)
    
    // 4. 执行调谐 (Reconcile)
    if diff.NeedsUpdate {
        return c.reconcile(obj, diff)
    }
    
    // 5. 更新状态 (Update Status)
    return c.updateStatus(obj, actual)
}
```

## API资源模型

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Kubernetes API资源结构                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         API Resource                                 │    │
│  ├─────────────────────────────────────────────────────────────────────┤    │
│  │                                                                      │    │
│  │  TypeMeta (类型元数据)                                               │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │ apiVersion: apps/v1                                          │    │    │
│  │  │ kind: Deployment                                             │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  │                                                                      │    │
│  │  ObjectMeta (对象元数据)                                             │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │ name: nginx-deployment                                       │    │    │
│  │  │ namespace: default                                           │    │    │
│  │  │ uid: a1b2c3d4-e5f6-7890-...                                  │    │    │
│  │  │ resourceVersion: "12345"                                     │    │    │
│  │  │ generation: 3                                                │    │    │
│  │  │ creationTimestamp: "2024-01-15T10:00:00Z"                    │    │    │
│  │  │ labels: {...}                                                │    │    │
│  │  │ annotations: {...}                                           │    │    │
│  │  │ ownerReferences: [...]                                       │    │    │
│  │  │ finalizers: [...]                                            │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  │                                                                      │    │
│  │  Spec (期望状态 - 用户定义)                                          │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │ replicas: 3                                                  │    │    │
│  │  │ selector: {matchLabels: {app: nginx}}                        │    │    │
│  │  │ template: {spec: {containers: [...]}}                        │    │    │
│  │  │ strategy: {type: RollingUpdate}                              │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  │                                                                      │    │
│  │  Status (实际状态 - 系统维护)                                        │    │
│  │  ┌─────────────────────────────────────────────────────────────┐    │    │
│  │  │ replicas: 3                                                  │    │    │
│  │  │ readyReplicas: 3                                             │    │    │
│  │  │ updatedReplicas: 3                                           │    │    │
│  │  │ availableReplicas: 3                                         │    │    │
│  │  │ observedGeneration: 3                                        │    │    │
│  │  │ conditions: [{type: Available, status: True}]                │    │    │
│  │  └─────────────────────────────────────────────────────────────┘    │    │
│  │                                                                      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 核心字段说明

| 字段 | 类型 | 说明 | 可变性 |
|-----|-----|------|-------|
| apiVersion | TypeMeta | API版本 (如apps/v1) | 不可变 |
| kind | TypeMeta | 资源类型 (如Deployment) | 不可变 |
| name | ObjectMeta | 资源名称 | 不可变 |
| namespace | ObjectMeta | 命名空间 | 不可变 |
| uid | ObjectMeta | 全局唯一标识符 | 系统生成 |
| resourceVersion | ObjectMeta | 乐观锁版本号 | 每次修改更新 |
| generation | ObjectMeta | spec变更版本号 | spec变更时+1 |
| labels | ObjectMeta | 标签(用于选择) | 可变 |
| annotations | ObjectMeta | 注解(存储元数据) | 可变 |
| ownerReferences | ObjectMeta | 所有者引用(级联删除) | 可变 |
| finalizers | ObjectMeta | 删除前执行的清理钩子 | 可变 |
| spec | Spec | 期望状态(用户定义) | 可变 |
| status | Status | 实际状态(系统更新) | 只读(用户) |

## 不可变基础设施 (Immutable Infrastructure)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          不可变基础设施原则                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  传统可变基础设施                        不可变基础设施                     │
│  ┌────────────────────────────┐        ┌────────────────────────────┐      │
│  │  服务器 A                  │        │  镜像 v1.0                 │      │
│  │  ├── 安装软件              │        │  ├── 所有依赖已打包        │      │
│  │  ├── 配置变更              │   VS   │  ├── 配置外部化(ConfigMap) │      │
│  │  ├── 补丁更新              │        │  ├── 版本化管理            │      │
│  │  ├── 手动修复              │        │  └── 不可修改              │      │
│  │  └── 状态漂移...           │        └────────────────────────────┘      │
│  └────────────────────────────┘                                             │
│                                                                              │
│  问题:                                  优势:                               │
│  • 配置漂移(Configuration Drift)       • 一致性保证                        │
│  • 雪花服务器(Snowflake Servers)       • 可重复部署                        │
│  • 难以审计和回滚                       • 快速回滚                          │
│  • 环境差异导致Bug                      • 环境一致性                        │
│                                                                              │
│  Kubernetes实现:                                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  1. 容器镜像不可变                                                   │   │
│  │     • 更新应用 = 构建新镜像 + 替换Pod                                │   │
│  │     • 不在运行中容器内做变更                                         │   │
│  │                                                                      │   │
│  │  2. Pod不可变(大部分字段)                                            │   │
│  │     • 修改spec = 删除旧Pod + 创建新Pod                               │   │
│  │     • 通过Deployment实现滚动更新                                     │   │
│  │                                                                      │   │
│  │  3. 配置与代码分离                                                   │   │
│  │     • ConfigMap: 配置数据                                            │   │
│  │     • Secret: 敏感数据                                               │   │
│  │     • 支持热更新(不重启Pod)                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 服务发现与负载均衡

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Kubernetes服务发现机制                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                          Client Pod                                  │   │
│  │                              │                                       │   │
│  │                              ▼                                       │   │
│  │                   ┌─────────────────────┐                           │   │
│  │                   │   DNS查询           │                           │   │
│  │                   │ my-svc.ns.svc.cluster.local                     │   │
│  │                   └──────────┬──────────┘                           │   │
│  │                              │                                       │   │
│  │                              ▼                                       │   │
│  │                   ┌─────────────────────┐                           │   │
│  │                   │     CoreDNS         │                           │   │
│  │                   │  返回ClusterIP      │                           │   │
│  │                   │   10.96.100.50      │                           │   │
│  │                   └──────────┬──────────┘                           │   │
│  │                              │                                       │   │
│  │                              ▼                                       │   │
│  │                   ┌─────────────────────┐                           │   │
│  │                   │   kube-proxy        │                           │   │
│  │                   │ (iptables/IPVS)     │                           │   │
│  │                   │  负载均衡到后端Pod  │                           │   │
│  │                   └──────────┬──────────┘                           │   │
│  │                              │                                       │   │
│  │              ┌───────────────┼───────────────┐                      │   │
│  │              ▼               ▼               ▼                      │   │
│  │         ┌─────────┐    ┌─────────┐    ┌─────────┐                  │   │
│  │         │ Pod 1   │    │ Pod 2   │    │ Pod 3   │                  │   │
│  │         │10.244.1.5│    │10.244.2.8│    │10.244.3.2│                  │   │
│  │         └─────────┘    └─────────┘    └─────────┘                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  服务发现方式:                                                              │
│  ┌────────────────────┬────────────────────────────────────────────────┐   │
│  │ 方式               │ 说明                                            │   │
│  ├────────────────────┼────────────────────────────────────────────────┤   │
│  │ DNS (推荐)         │ 通过FQDN解析: svc.ns.svc.cluster.local         │   │
│  │ 环境变量           │ {SVC_NAME}_SERVICE_HOST, {SVC_NAME}_SERVICE_PORT│   │
│  │ API查询            │ 通过API获取Endpoints列表                        │   │
│  └────────────────────┴────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 自愈机制 (Self-Healing)

| 故障类型 | 检测机制 | 恢复机制 | 配置方式 |
|---------|---------|---------|---------|
| 容器崩溃 | 进程退出码 | 容器重启 | restartPolicy |
| 应用死锁 | livenessProbe | 容器重启 | HTTP/TCP/Exec探针 |
| 应用未就绪 | readinessProbe | 从Service移除 | HTTP/TCP/Exec探针 |
| 启动缓慢 | startupProbe | 延迟其他探针 | HTTP/TCP/Exec探针 |
| Pod失败 | kubelet检测 | ReplicaSet重建 | 副本数维持 |
| 节点故障 | Node Controller | Pod驱逐+重调度 | podEvictionTimeout |
| 资源不足 | OOMKiller | Pod重启/驱逐 | requests/limits |

### 探针配置示例

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: self-healing-demo
spec:
  containers:
  - name: app
    image: myapp:v1
    
    # 启动探针 - 慢启动应用
    startupProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 0
      periodSeconds: 10
      failureThreshold: 30  # 允许5分钟启动时间
    
    # 存活探针 - 检测死锁/僵尸进程
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 0
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3   # 连续3次失败则重启
    
    # 就绪探针 - 流量控制
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
      successThreshold: 1
      failureThreshold: 3
    
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  
  # 重启策略
  restartPolicy: Always  # Always, OnFailure, Never
```

## 松耦合架构 (Loosely Coupled Architecture)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Kubernetes松耦合组件交互                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                        ┌─────────────────────┐                              │
│                        │     API Server      │                              │
│                        │   (唯一交互中心)    │                              │
│                        └──────────┬──────────┘                              │
│                                   │                                         │
│         ┌─────────────────────────┼─────────────────────────┐               │
│         │                         │                         │               │
│         ▼                         ▼                         ▼               │
│  ┌─────────────┐          ┌─────────────┐          ┌─────────────┐         │
│  │ Scheduler   │          │ Controller  │          │   kubelet   │         │
│  │             │          │  Manager    │          │             │         │
│  │ • 只读Pod   │          │ • 读写资源  │          │ • 读Pod     │         │
│  │ • 写Binding │          │ • Watch变更 │          │ • 写Status  │         │
│  └─────────────┘          └─────────────┘          └─────────────┘         │
│                                                                              │
│  组件间不直接通信:                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  ✗ Scheduler直接告诉kubelet运行Pod                                  │   │
│  │  ✓ Scheduler更新Pod的nodeName，kubelet Watch到后自行处理            │   │
│  │                                                                      │   │
│  │  ✗ Controller直接调用kubelet API                                    │   │
│  │  ✓ Controller更新资源状态，kubelet通过Watch感知变化                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  优势:                                                                      │
│  • 组件可独立升级                                                          │
│  • 组件故障不影响其他组件                                                  │
│  • 易于扩展新组件                                                          │
│  • 测试更容易(Mock API Server即可)                                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 可扩展性设计 (Extensibility)

| 扩展点 | 机制 | 用途 | 示例 |
|-------|-----|-----|-----|
| CRD | Custom Resource Definition | 自定义资源类型 | Prometheus、Istio资源 |
| Operator | 自定义控制器 | 自动化运维逻辑 | MySQL Operator |
| Admission Webhook | 准入控制钩子 | 请求拦截/修改 | Pod注入、策略校验 |
| API Aggregation | API聚合层 | 扩展API Server | metrics-server |
| Scheduler Extender | 调度扩展 | 自定义调度逻辑 | GPU调度 |
| CSI | 容器存储接口 | 自定义存储驱动 | 云存储插件 |
| CNI | 容器网络接口 | 自定义网络插件 | Calico、Cilium |
| CRI | 容器运行时接口 | 自定义运行时 | containerd、CRI-O |
| Device Plugin | 设备插件 | 自定义硬件资源 | GPU、FPGA |

## 最佳实践

| 实践 | 说明 | 原因 |
|-----|------|------|
| 使用声明式管理 | kubectl apply而非create | 幂等、可追踪 |
| 使用标签选择器 | 而非硬编码名称 | 松耦合、灵活 |
| 配置与代码分离 | 使用ConfigMap/Secret | 环境无关 |
| 设置资源限制 | requests/limits | 防止资源争抢 |
| 使用健康检查 | liveness/readiness探针 | 自愈能力 |
| 使用命名空间隔离 | 逻辑分组资源 | 多租户、权限 |
| 使用RBAC | 最小权限原则 | 安全 |
| 使用Deployment | 而非直接创建Pod | 声明式、回滚 |

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)
