# 13 - 控制器模式与调谐循环 (Controller Pattern & Reconciliation)

## 控制器核心概念

| 概念 | 英文 | 说明 |
|-----|-----|------|
| 控制器 | Controller | 监听资源变化并执行调谐的组件 |
| 调谐 | Reconciliation | 使实际状态趋向期望状态的过程 |
| 控制循环 | Control Loop | 持续运行的调谐循环 |
| Level-triggered | 电平触发 | 基于当前状态而非事件触发 |
| Edge-triggered | 边沿触发 | 基于状态变化事件触发 |

## Level-triggered vs Edge-triggered

| 维度 | Level-triggered (电平触发) | Edge-triggered (边沿触发) |
|-----|---------------------------|--------------------------|
| 触发条件 | 当前状态不符合期望 | 状态变化事件 |
| 幂等性 | 天然幂等 | 需要额外处理 |
| 事件丢失 | 不影响正确性 | 可能导致状态不一致 |
| 重启恢复 | 自动恢复 | 需要重放事件 |
| K8s采用 | ✓ 主要方式 | 作为优化触发 |

## 控制器组成部分

| 组件 | 英文 | 职责 |
|-----|-----|------|
| Informer | 信息器 | 监听API Server变化，维护本地缓存 |
| Lister | 列表器 | 从本地缓存读取资源 |
| WorkQueue | 工作队列 | 存储待处理的资源key |
| Reconciler | 调谐器 | 执行实际的调谐逻辑 |

## Informer工作机制

| 阶段 | 说明 |
|-----|------|
| List | 启动时全量获取资源列表 |
| Watch | 持续监听增量变化事件 |
| 缓存同步 | 将变化同步到本地缓存(Indexer) |
| 事件分发 | 通过EventHandler分发到WorkQueue |

### Informer架构

```
API Server
    │
    │ List & Watch
    ▼
┌─────────────────────────────────────────────┐
│                 Informer                     │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐ │
│  │ Reflector│───▶│  Store  │───▶│ Indexer │ │
│  └─────────┘    └─────────┘    └─────────┘ │
│       │                              │      │
│       ▼                              ▼      │
│  ┌─────────────────────────────────────┐   │
│  │         EventHandler                 │   │
│  │  OnAdd() / OnUpdate() / OnDelete()   │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
         │
         ▼
    WorkQueue
         │
         ▼
    Controller (Reconcile)
```

## WorkQueue特性

| 特性 | 说明 |
|-----|------|
| 去重(De-dup) | 相同key只保留一个 |
| 限速(Rate Limiting) | 失败重试带退避 |
| 公平(Fair) | 不同key公平处理 |
| 关机(Shutdown) | 优雅关闭支持 |

### WorkQueue类型

| 类型 | 用途 |
|-----|------|
| FIFO Queue | 基础队列 |
| Delaying Queue | 延迟入队 |
| Rate Limiting Queue | 限速重试 |

## 调谐循环代码模式

```go
// 控制器主循环
func (c *Controller) Run(workers int, stopCh <-chan struct{}) error {
    defer c.workqueue.ShutDown()
    
    // 等待缓存同步
    if !cache.WaitForCacheSync(stopCh, c.informer.HasSynced) {
        return fmt.Errorf("failed to sync caches")
    }
    
    // 启动工作协程
    for i := 0; i < workers; i++ {
        go wait.Until(c.runWorker, time.Second, stopCh)
    }
    
    <-stopCh
    return nil
}

// 工作协程
func (c *Controller) runWorker() {
    for c.processNextItem() {
    }
}

// 处理单个项目
func (c *Controller) processNextItem() bool {
    key, quit := c.workqueue.Get()
    if quit {
        return false
    }
    defer c.workqueue.Done(key)
    
    err := c.syncHandler(key.(string))
    c.handleErr(err, key)
    return true
}

// 错误处理
func (c *Controller) handleErr(err error, key interface{}) {
    if err == nil {
        c.workqueue.Forget(key)
        return
    }
    
    if c.workqueue.NumRequeues(key) < maxRetries {
        c.workqueue.AddRateLimited(key)
        return
    }
    
    c.workqueue.Forget(key)
    runtime.HandleError(err)
}
```

## 调谐函数模式

```go
func (c *Controller) syncHandler(key string) error {
    namespace, name, err := cache.SplitMetaNamespaceKey(key)
    if err != nil {
        return err
    }
    
    // 1. 获取资源
    obj, err := c.lister.Get(name)
    if errors.IsNotFound(err) {
        // 资源已删除，执行清理
        return nil
    }
    if err != nil {
        return err
    }
    
    // 2. 检查是否需要处理
    if !c.needsReconcile(obj) {
        return nil
    }
    
    // 3. 执行调谐逻辑
    result, err := c.reconcile(obj)
    if err != nil {
        return err
    }
    
    // 4. 更新状态
    if result.StatusChanged {
        _, err = c.client.UpdateStatus(obj)
    }
    
    return err
}
```

## 内置控制器详解

| 控制器 | 监听资源 | 管理资源 | 核心逻辑 |
|-------|---------|---------|---------|
| Deployment | Deployment | ReplicaSet | 滚动更新、版本管理 |
| ReplicaSet | ReplicaSet, Pod | Pod | 维护副本数 |
| StatefulSet | StatefulSet, Pod | Pod, PVC | 有序部署、持久存储 |
| DaemonSet | DaemonSet, Node, Pod | Pod | 每节点一个Pod |
| Job | Job, Pod | Pod | 完成后清理 |
| CronJob | CronJob | Job | 定时创建Job |
| Endpoints | Service, Pod | Endpoints | 维护端点列表 |
| Namespace | Namespace | 所有ns资源 | 级联删除 |
| Node | Node | Pod | 节点健康管理 |
| GC | 所有资源 | 所有资源 | 孤儿资源清理 |

## ReplicaSet控制器逻辑

| 步骤 | 操作 |
|-----|------|
| 1 | 获取ReplicaSet对象 |
| 2 | 列出所有匹配selector的Pod |
| 3 | 过滤掉正在删除的Pod |
| 4 | 计算当前副本数与期望值差异 |
| 5 | 差异>0: 创建新Pod |
| 6 | 差异<0: 删除多余Pod |
| 7 | 更新ReplicaSet status |

## Deployment控制器逻辑

| 步骤 | 操作 |
|-----|------|
| 1 | 获取Deployment对象 |
| 2 | 列出所有关联的ReplicaSet |
| 3 | 计算新旧ReplicaSet |
| 4 | 根据更新策略(RollingUpdate/Recreate)执行 |
| 5 | 调整新RS副本数(scale up) |
| 6 | 调整旧RS副本数(scale down) |
| 7 | 更新Deployment status |

## 并发控制最佳实践

| 实践 | 说明 |
|-----|------|
| 使用resourceVersion | 乐观锁避免冲突 |
| 处理409冲突 | 重新获取后重试 |
| 单一所有者 | 避免多控制器管理同一资源 |
| 使用OwnerReferences | 明确资源所属关系 |
| 幂等操作 | 确保重复执行结果一致 |

## 控制器开发框架

| 框架 | 特点 | 适用场景 |
|-----|------|---------|
| client-go | 官方底层库 | 深度定制 |
| controller-runtime | 高级抽象 | 快速开发 |
| Kubebuilder | 脚手架+controller-runtime | 标准Operator |
| Operator SDK | 多语言支持 | Go/Ansible/Helm |

## 调试技巧

| 方法 | 说明 |
|-----|------|
| 日志级别 | 调整klog verbosity |
| 事件记录 | 使用EventRecorder |
| 指标暴露 | Prometheus metrics |
| 健康检查 | /healthz, /readyz |
| pprof | 性能分析 |

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)
