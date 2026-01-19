# 14 - Watch/List机制与事件驱动 (Watch/List Mechanism & Event-Driven)

## Watch/List核心概念

| 概念 | 英文 | 说明 |
|-----|-----|------|
| List | 列表 | 全量获取资源列表 |
| Watch | 监听 | 增量监听资源变化 |
| ResourceVersion | 资源版本 | 变更序列号,用于增量同步 |
| Bookmark | 书签 | 周期性同步resourceVersion |

## List操作详解

| 参数 | 说明 | 示例 |
|-----|------|-----|
| labelSelector | 标签过滤 | app=nginx |
| fieldSelector | 字段过滤 | status.phase=Running |
| limit | 分页大小 | 500 |
| continue | 分页token | 上次返回的token |
| resourceVersion | 版本控制 | 0=任意版本,空=最新 |

### List请求示例

```bash
# 基础List
GET /api/v1/namespaces/default/pods

# 带标签选择器
GET /api/v1/namespaces/default/pods?labelSelector=app=nginx

# 分页List
GET /api/v1/pods?limit=500
GET /api/v1/pods?limit=500&continue=<token>

# 指定resourceVersion
GET /api/v1/pods?resourceVersion=0        # 从缓存读取
GET /api/v1/pods?resourceVersion=          # 最新数据
GET /api/v1/pods?resourceVersion=12345     # 至少这个版本
```

## Watch操作详解

| 事件类型 | 说明 |
|---------|------|
| ADDED | 资源被创建 |
| MODIFIED | 资源被修改 |
| DELETED | 资源被删除 |
| BOOKMARK | resourceVersion同步(不含资源) |
| ERROR | 发生错误 |

### Watch请求示例

```bash
# 基础Watch
GET /api/v1/namespaces/default/pods?watch=true

# 从指定版本开始Watch
GET /api/v1/pods?watch=true&resourceVersion=12345

# Watch单个资源
GET /api/v1/namespaces/default/pods/nginx?watch=true

# 带标签选择器的Watch
GET /api/v1/pods?watch=true&labelSelector=app=nginx
```

### Watch事件格式

```json
{"type":"ADDED","object":{"apiVersion":"v1","kind":"Pod",...}}
{"type":"MODIFIED","object":{"apiVersion":"v1","kind":"Pod",...}}
{"type":"DELETED","object":{"apiVersion":"v1","kind":"Pod",...}}
{"type":"BOOKMARK","object":{"metadata":{"resourceVersion":"12345"}}}
```

## ResourceVersion语义

| 值 | 语义 | 用途 |
|---|------|-----|
| 空 | 最新版本 | 获取最新数据 |
| "0" | 任意版本 | 可从缓存读取 |
| 具体值 | 至少该版本 | Watch起始点 |

## List-Watch组合模式

| 阶段 | 操作 | 说明 |
|-----|------|------|
| 1. 初始List | GET /pods | 获取全量数据 |
| 2. 记录RV | resourceVersion | 保存列表的RV |
| 3. 启动Watch | GET /pods?watch&rv=X | 从RV开始Watch |
| 4. 处理事件 | ADDED/MODIFIED/DELETED | 更新本地缓存 |
| 5. 处理错误 | 410 Gone | 重新执行List |

### 410 Gone错误处理

```
Watch过程中可能收到410 Gone错误:
- 原因: etcd已清理旧版本数据
- 处理: 重新执行List-Watch

代码示例:
if apierrors.IsResourceExpired(err) || apierrors.IsGone(err) {
    // 重新List
    return c.resync()
}
```

## Informer中的List-Watch

| 组件 | 职责 |
|-----|------|
| Reflector | 执行List-Watch,写入Store |
| Store/Indexer | 本地缓存,支持索引 |
| Controller | 从Store读取,分发事件 |

### Reflector核心逻辑

```go
func (r *Reflector) ListAndWatch(stopCh <-chan struct{}) error {
    // 1. List全量数据
    list, err := r.listerWatcher.List(options)
    resourceVersion := list.GetResourceVersion()
    
    // 2. 同步到Store
    r.store.Replace(items, resourceVersion)
    
    // 3. Watch增量变化
    for {
        w, err := r.listerWatcher.Watch(resourceVersion)
        if err != nil {
            return err
        }
        
        err = r.watchHandler(w, stopCh)
        if err != nil {
            if apierrors.IsResourceExpired(err) {
                return nil // 触发重新List
            }
            return err
        }
    }
}
```

## Watch缓存(Watch Cache)

| 特性 | 说明 |
|-----|------|
| 位置 | API Server内存 |
| 作用 | 减少etcd压力 |
| 容量 | 默认100个事件/资源类型 |
| 淘汰 | 滑动窗口,旧事件淘汰 |

### Watch缓存配置

```yaml
# kube-apiserver参数
--default-watch-cache-size=100     # 默认缓存大小
--watch-cache-sizes=pods=1000      # 特定资源缓存大小
```

## 性能优化

| 优化 | 说明 |
|-----|------|
| 使用labelSelector | 减少传输数据量 |
| 使用fieldSelector | 服务端过滤 |
| 启用Watch Cache | 减少etcd负载 |
| 分页List | 避免大量数据OOM |
| 使用Informer | 本地缓存减少API调用 |

## Bookmark机制

| 作用 | 说明 |
|-----|------|
| 同步RV | 定期更新客户端resourceVersion |
| 防止410 | 保持RV在etcd保留范围内 |
| 无数据传输 | 只传resourceVersion,不传对象 |

### 启用Bookmark

```go
watchOptions := metav1.ListOptions{
    Watch:               true,
    AllowWatchBookmarks: true,
    ResourceVersion:     rv,
}
```

## 事件驱动架构

| 组件 | 生产者 | 消费者 |
|-----|-------|-------|
| API Server | 生产Watch事件 | - |
| Informer | 消费Watch事件 | 生产EventHandler事件 |
| WorkQueue | 消费EventHandler事件 | 提供给Reconciler |
| Reconciler | 消费WorkQueue事件 | - |

## 常见问题排查

| 问题 | 原因 | 解决 |
|-----|------|------|
| 410 Gone | RV过旧 | 重新List |
| Watch断开 | 网络问题/API Server重启 | 自动重连 |
| 事件延迟 | API Server负载高 | 优化查询/扩容 |
| 内存溢出 | List数据量过大 | 启用分页 |

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)
