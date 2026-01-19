# 15 - Informer与WorkQueue深度解析 (Informer & WorkQueue Deep Dive)

## Informer核心组件

| 组件 | 英文 | 职责 |
|-----|-----|------|
| Reflector | 反射器 | 执行List-Watch,同步数据到Store |
| Store | 存储 | 内存存储,支持CRUD操作 |
| Indexer | 索引器 | 带索引的Store,支持快速查询 |
| Controller | 控制器 | 从Store弹出事件,分发给Handler |
| SharedInformer | 共享Informer | 多Handler共享一个Informer |

## Informer架构图

```
                    API Server
                        │
                        │ List & Watch
                        ▼
┌──────────────────────────────────────────────────────────┐
│                    SharedInformer                         │
│  ┌────────────────────────────────────────────────────┐  │
│  │                   Reflector                         │  │
│  │  ┌─────────────┐        ┌─────────────┐           │  │
│  │  │ ListWatcher │───────▶│ DeltaFIFO   │           │  │
│  │  └─────────────┘        └──────┬──────┘           │  │
│  └─────────────────────────────────┼──────────────────┘  │
│                                    │                      │
│                                    ▼                      │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                    Indexer (Cache)                   │ │
│  │  ┌───────────────────────────────────────────────┐  │ │
│  │  │ namespace: {ns1: [pod1,pod2], ns2: [pod3]}    │  │ │
│  │  │ labels: {app=nginx: [pod1,pod3]}              │  │ │
│  │  └───────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────┘ │
│                                    │                      │
│                                    ▼                      │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              Event Handler (Callbacks)               │ │
│  │  OnAdd()    OnUpdate()    OnDelete()                │ │
│  └─────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                            │
                            ▼
                       WorkQueue
                            │
                            ▼
                       Reconciler
```

## DeltaFIFO详解

| 概念 | 说明 |
|-----|------|
| Delta | 变更记录(对象+类型) |
| FIFO | 先进先出队列 |
| 去重 | 相同key的Delta合并 |
| 类型 | Added, Updated, Deleted, Replaced, Sync |

### Delta类型

| 类型 | 触发时机 |
|-----|---------|
| Added | 新资源创建 |
| Updated | 资源更新 |
| Deleted | 资源删除 |
| Replaced | 重新List替换 |
| Sync | 周期性重同步 |

## Indexer索引机制

| 概念 | 说明 |
|-----|------|
| IndexFunc | 索引函数,提取索引key |
| Indices | 索引名->Index的映射 |
| Index | 索引值->对象key集合的映射 |

### 内置索引函数

| 索引名 | IndexFunc | 用途 |
|-------|----------|------|
| namespace | MetaNamespaceIndexFunc | 按命名空间索引 |

### 自定义索引示例

```go
// 按标签索引
func LabelIndexFunc(obj interface{}) ([]string, error) {
    pod := obj.(*v1.Pod)
    labels := []string{}
    for k, v := range pod.Labels {
        labels = append(labels, fmt.Sprintf("%s=%s", k, v))
    }
    return labels, nil
}

// 注册索引
informer.AddIndexers(cache.Indexers{
    "byLabel": LabelIndexFunc,
})

// 使用索引查询
pods, _ := indexer.ByIndex("byLabel", "app=nginx")
```

## SharedInformerFactory

| 特性 | 说明 |
|-----|------|
| 资源复用 | 同类型资源共享一个Informer |
| 启动管理 | 统一启动所有Informer |
| 缓存同步 | 统一等待缓存同步 |

### 使用示例

```go
// 创建Factory
factory := informers.NewSharedInformerFactory(clientset, 30*time.Second)

// 获取特定资源的Informer
podInformer := factory.Core().V1().Pods()
deployInformer := factory.Apps().V1().Deployments()

// 添加事件处理器
podInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
    AddFunc:    onAdd,
    UpdateFunc: onUpdate,
    DeleteFunc: onDelete,
})

// 启动所有Informer
factory.Start(stopCh)

// 等待缓存同步
factory.WaitForCacheSync(stopCh)
```

## WorkQueue类型

| 类型 | 特性 | 用途 |
|-----|------|------|
| Interface | 基础队列 | 简单场景 |
| DelayingInterface | 延迟入队 | 延迟处理 |
| RateLimitingInterface | 限速重试 | 失败重试 |

## WorkQueue操作

| 方法 | 说明 |
|-----|------|
| Add(item) | 添加项目 |
| Get() | 获取项目(阻塞) |
| Done(item) | 标记处理完成 |
| Forget(item) | 清除重试计数 |
| AddAfter(item, d) | 延迟添加 |
| AddRateLimited(item) | 限速添加 |
| NumRequeues(item) | 获取重试次数 |
| ShutDown() | 关闭队列 |

### WorkQueue使用模式

```go
// 1. 创建限速队列
queue := workqueue.NewRateLimitingQueue(
    workqueue.DefaultControllerRateLimiter(),
)

// 2. 事件处理器入队
handler := cache.ResourceEventHandlerFuncs{
    AddFunc: func(obj interface{}) {
        key, _ := cache.MetaNamespaceKeyFunc(obj)
        queue.Add(key)
    },
    UpdateFunc: func(old, new interface{}) {
        key, _ := cache.MetaNamespaceKeyFunc(new)
        queue.Add(key)
    },
    DeleteFunc: func(obj interface{}) {
        key, _ := cache.DeletionHandlingMetaNamespaceKeyFunc(obj)
        queue.Add(key)
    },
}

// 3. 工作循环处理
for {
    key, quit := queue.Get()
    if quit {
        return
    }
    
    err := processItem(key)
    if err == nil {
        queue.Forget(key)
    } else {
        queue.AddRateLimited(key)
    }
    queue.Done(key)
}
```

## 限速器类型

| 限速器 | 算法 | 参数 |
|-------|-----|------|
| BucketRateLimiter | 令牌桶 | rate, burst |
| ItemExponentialFailureRateLimiter | 指数退避 | baseDelay, maxDelay |
| ItemFastSlowRateLimiter | 快慢切换 | fastDelay, slowDelay, maxFastAttempts |
| MaxOfRateLimiter | 取最大 | 组合多个限速器 |

### 默认限速器

```go
// DefaultControllerRateLimiter组合:
// 1. 指数退避: 5ms起始, 最大1000秒
// 2. 令牌桶: 10 QPS, burst=100
func DefaultControllerRateLimiter() RateLimiter {
    return NewMaxOfRateLimiter(
        NewItemExponentialFailureRateLimiter(5*time.Millisecond, 1000*time.Second),
        &BucketRateLimiter{Limiter: rate.NewLimiter(rate.Limit(10), 100)},
    )
}
```

## Resync机制

| 概念 | 说明 |
|-----|------|
| ResyncPeriod | 周期性重同步间隔 |
| 作用 | 确保控制器处理所有对象 |
| 触发 | 生成Sync类型Delta |

### Resync配置

```go
// 30秒重同步
factory := informers.NewSharedInformerFactory(clientset, 30*time.Second)

// 禁用重同步
factory := informers.NewSharedInformerFactory(clientset, 0)
```

## 性能优化建议

| 优化 | 说明 |
|-----|------|
| 共享Informer | 使用SharedInformerFactory |
| 合理Resync | 不要设置过短 |
| 索引优化 | 添加常用索引 |
| 过滤事件 | EventHandler中过滤无关事件 |
| 控制并发 | 合理设置worker数量 |

## 调试技巧

| 方法 | 说明 |
|-----|------|
| 查看缓存 | informer.GetStore().List() |
| 查看索引 | indexer.IndexKeys(indexName, value) |
| 队列长度 | queue.Len() |
| 重试次数 | queue.NumRequeues(key) |

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)
