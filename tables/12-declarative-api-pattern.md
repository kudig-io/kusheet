# 12 - 声明式API模式 (Declarative API Pattern)

## 声明式API核心概念

| 概念 | 英文 | 说明 | 示例 |
|-----|-----|------|-----|
| 期望状态 | Desired State | 用户声明的目标状态 | spec.replicas=3 |
| 实际状态 | Actual State | 系统当前的实际状态 | status.replicas=2 |
| 调谐 | Reconciliation | 使实际状态趋向期望状态 | 创建1个新Pod |
| 幂等性 | Idempotency | 多次操作结果相同 | apply多次无副作用 |
| 最终一致性 | Eventual Consistency | 状态最终会收敛 | 系统自动重试直到成功 |

## API版本演进

| 版本级别 | 格式 | 稳定性 | 兼容性保证 | 典型用途 |
|---------|-----|-------|-----------|---------|
| Alpha | v1alpha1 | 不稳定 | 无保证，可能删除 | 实验功能 |
| Beta | v1beta1 | 较稳定 | 向后兼容 | 测试功能 |
| Stable | v1 | 稳定 | 长期支持 | 生产使用 |

## API资源分类

| 类别 | 作用域 | 示例资源 | 说明 |
|-----|-------|---------|------|
| Cluster-scoped | 集群级 | Node, PV, ClusterRole | 不属于任何命名空间 |
| Namespace-scoped | 命名空间级 | Pod, Service, Deployment | 属于特定命名空间 |

## API Group组织结构

| API Group | 包含资源 | 说明 |
|----------|---------|------|
| core (空) | Pod, Service, ConfigMap, Secret, PV, PVC | 核心资源 |
| apps | Deployment, StatefulSet, DaemonSet, ReplicaSet | 应用负载 |
| batch | Job, CronJob | 批处理 |
| networking.k8s.io | Ingress, NetworkPolicy | 网络 |
| storage.k8s.io | StorageClass, VolumeAttachment | 存储 |
| rbac.authorization.k8s.io | Role, ClusterRole, RoleBinding | 权限 |
| policy | PodDisruptionBudget | 策略 |
| autoscaling | HPA | 自动扩缩 |
| admissionregistration.k8s.io | ValidatingWebhookConfiguration | 准入控制 |

## RESTful API路径规范

| 资源类型 | HTTP方法 | 路径 | 操作 |
|---------|---------|-----|------|
| 集群资源列表 | GET | /api/v1/nodes | 列出所有节点 |
| 集群资源详情 | GET | /api/v1/nodes/{name} | 获取节点详情 |
| 命名空间资源列表 | GET | /api/v1/namespaces/{ns}/pods | 列出ns下所有Pod |
| 命名空间资源详情 | GET | /api/v1/namespaces/{ns}/pods/{name} | 获取Pod详情 |
| 创建资源 | POST | /api/v1/namespaces/{ns}/pods | 创建Pod |
| 更新资源 | PUT | /api/v1/namespaces/{ns}/pods/{name} | 完整更新Pod |
| 部分更新 | PATCH | /api/v1/namespaces/{ns}/pods/{name} | 部分更新Pod |
| 删除资源 | DELETE | /api/v1/namespaces/{ns}/pods/{name} | 删除Pod |
| 更新状态 | PUT | /api/v1/namespaces/{ns}/pods/{name}/status | 更新Pod状态 |
| Watch资源 | GET | /api/v1/namespaces/{ns}/pods?watch=true | 监听变化 |

## Spec vs Status设计模式

| 维度 | Spec | Status |
|-----|------|--------|
| 含义 | 期望状态 | 实际状态 |
| 写入者 | 用户 | 系统(控制器) |
| 读取者 | 控制器 | 用户、监控 |
| 存储位置 | etcd | etcd |
| 更新频率 | 用户操作时 | 控制器每次调谐 |
| 验证 | 严格验证 | 宽松验证 |

### Spec/Status示例

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:                          # 期望状态(用户定义)
  replicas: 3                  # 期望3个副本
  selector:
    matchLabels:
      app: nginx
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
status:                        # 实际状态(系统维护)
  replicas: 3                  # 当前总副本数
  readyReplicas: 3             # 就绪副本数
  updatedReplicas: 3           # 已更新副本数
  availableReplicas: 3         # 可用副本数
  observedGeneration: 5        # 控制器观察到的generation
  conditions:
  - type: Available
    status: "True"
    lastUpdateTime: "2024-01-15T10:00:00Z"
```

## 乐观并发控制 (Optimistic Concurrency)

| 概念 | 说明 |
|-----|------|
| resourceVersion | 每个资源的版本号，每次修改递增 |
| 冲突检测 | 更新时检查resourceVersion是否匹配 |
| 409 Conflict | 版本不匹配时返回冲突错误 |
| 重试策略 | 客户端需获取最新版本后重试 |

### 乐观锁工作流程

```
1. Client GET /api/v1/pods/nginx → resourceVersion: "1000"
2. Client修改spec
3. Client PUT /api/v1/pods/nginx (resourceVersion: "1000")
4. 
   情况A: 无冲突 → 成功，新resourceVersion: "1001"
   情况B: 有冲突(其他人已修改) → 409 Conflict
          → Client需重新GET最新版本后重试
```

## API操作语义

| 操作 | 语义 | 幂等性 | 说明 |
|-----|------|-------|------|
| CREATE | 创建新资源 | 否 | 资源已存在则失败 |
| GET | 读取资源 | 是 | 不改变状态 |
| LIST | 列出资源 | 是 | 不改变状态 |
| WATCH | 监听变化 | 是 | 长连接推送事件 |
| UPDATE | 完整替换 | 是 | 需提供完整spec |
| PATCH | 部分更新 | 是 | 仅提供变更部分 |
| DELETE | 删除资源 | 是 | 已删除再删除无错误 |

## Patch策略类型

| 类型 | Content-Type | 说明 | 适用场景 |
|-----|-------------|------|---------|
| Strategic Merge Patch | application/strategic-merge-patch+json | K8s特有，智能合并 | 大部分场景 |
| JSON Merge Patch | application/merge-patch+json | RFC 7386标准 | 简单覆盖 |
| JSON Patch | application/json-patch+json | RFC 6902标准 | 精确操作 |

### Strategic Merge Patch示例

```yaml
# 原始Deployment
spec:
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:1.20
      - name: sidecar
        image: sidecar:v1

# Patch内容(Strategic Merge)
spec:
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:1.21  # 只更新nginx镜像

# 结果: nginx更新，sidecar保留
```

## Finalizers机制

| 概念 | 说明 |
|-----|------|
| Finalizer | 删除前必须执行的清理操作标记 |
| 删除流程 | 设置deletionTimestamp → 执行Finalizer → 移除Finalizer → 真正删除 |
| 用途 | 清理外部资源、级联删除、审计日志 |

### Finalizer示例

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  finalizers:
  - kubernetes  # 系统Finalizer，清理ns内所有资源
```

## Owner References与级联删除

| 删除策略 | propagationPolicy | 行为 |
|---------|------------------|------|
| Orphan | Orphan | 删除Owner，保留子资源 |
| Background | Background | 删除Owner后异步删除子资源 |
| Foreground | Foreground | 先删除子资源，再删除Owner |

### OwnerReference示例

```yaml
# ReplicaSet创建的Pod自动包含OwnerReference
apiVersion: v1
kind: Pod
metadata:
  name: nginx-abc123
  ownerReferences:
  - apiVersion: apps/v1
    kind: ReplicaSet
    name: nginx-7b4f5d8c9
    uid: 12345678-1234-1234-1234-123456789012
    controller: true      # 标记为控制器
    blockOwnerDeletion: true
```

## API请求流程

| 阶段 | 说明 |
|-----|------|
| 1. 认证(Authentication) | 验证请求者身份 |
| 2. 授权(Authorization) | 检查RBAC权限 |
| 3. 准入控制(Admission) | Mutating + Validating Webhook |
| 4. 验证(Validation) | 资源schema验证 |
| 5. 持久化(Persistence) | 写入etcd |
| 6. 通知(Notification) | 触发Watch事件 |

## 最佳实践

| 实践 | 说明 |
|-----|------|
| 使用kubectl apply | 声明式管理，支持三方合并 |
| 版本控制YAML | 配合GitOps工作流 |
| 使用标签而非名称 | 松耦合，支持选择器 |
| 设置resourceVersion | 避免并发冲突 |
| 使用Finalizers | 确保外部资源清理 |
| 遵循API版本 | 生产使用stable版本 |

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)
