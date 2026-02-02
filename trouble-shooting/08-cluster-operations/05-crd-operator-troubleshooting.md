# CRD 与 Operator 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 高级
>
> **版本说明**:
> - v1.25+ CRD 验证表达式 (CEL) GA
> - v1.27+ CRD SelectableFields (Alpha)
> - v1.30+ CRD 验证规则支持更复杂的 CEL 表达式
> - Operator SDK v1.32+ / Kubebuilder v3.12+ 推荐

---

## 第一部分：问题现象与影响分析

### 1.1 CRD 与 Operator 架构

```
┌──────────────────────────────────────────────────────────────────────┐
│                    Kubernetes API Server                             │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌────────────────────────────────────────────────────────────┐    │
│   │                Custom Resource Definitions                  │    │
│   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │    │
│   │  │ certificates │  │ certificates │  │    your      │     │    │
│   │  │ .cert-manager│  │ .k8s.io     │  │   custom     │     │    │
│   │  │    .io       │  │             │  │   resource   │     │    │
│   │  └──────────────┘  └──────────────┘  └──────────────┘     │    │
│   └────────────────────────────────────────────────────────────┘    │
│                                                                      │
│   ┌────────────────────────────────────────────────────────────┐    │
│   │              API Extension Layer                            │    │
│   │  - Aggregated API Servers                                   │    │
│   │  - Conversion Webhooks                                      │    │
│   │  - Validation/Mutation Webhooks                             │    │
│   └────────────────────────────────────────────────────────────┘    │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
                                   │
                           Watch/List CR
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│                        Operator Pattern                              │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌────────────────────────────────────────────────────────────┐    │
│   │                   Operator Controller                       │    │
│   │                                                             │    │
│   │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │    │
│   │  │  Informer   │───>│  WorkQueue  │───>│ Reconcile   │    │    │
│   │  │  (Watch)    │    │             │    │   Loop      │    │    │
│   │  └─────────────┘    └─────────────┘    └─────────────┘    │    │
│   │                                               │             │    │
│   │                                               ▼             │    │
│   │                              ┌─────────────────────────┐   │    │
│   │                              │  Create/Update/Delete   │   │    │
│   │                              │  - Deployments          │   │    │
│   │                              │  - Services             │   │    │
│   │                              │  - ConfigMaps           │   │    │
│   │                              │  - Other resources      │   │    │
│   │                              └─────────────────────────┘   │    │
│   │                                                             │    │
│   └────────────────────────────────────────────────────────────┘    │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

Reconcile 循环详解:
┌─────────────┐
│   事件触发  │ (Create/Update/Delete CR)
└─────────────┘
       │
       ▼
┌─────────────┐
│  入队请求   │ (Object Key: namespace/name)
└─────────────┘
       │
       ▼
┌─────────────┐     ┌─────────────┐
│  Reconcile  │────>│ 获取 CR     │
│   函数      │     │ 当前状态    │
└─────────────┘     └─────────────┘
       │                   │
       │                   ▼
       │            ┌─────────────┐
       │            │ 比较期望    │
       │            │ vs 实际状态 │
       │            └─────────────┘
       │                   │
       │                   ▼
       │            ┌─────────────┐
       │            │ 执行调谐    │
       │            │ (创建/更新) │
       │            └─────────────┘
       │                   │
       ▼                   ▼
┌─────────────┐     ┌─────────────┐
│ 返回 Result │<────│ 更新 CR     │
│ (Requeue?)  │     │ Status      │
└─────────────┘     └─────────────┘
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 错误信息 | 查看方式 |
|----------|----------|----------|----------|
| CRD 不存在 | 无法创建自定义资源 | no matches for kind | `kubectl apply` 输出 |
| CRD 版本冲突 | API 版本不匹配 | unable to recognize | `kubectl get crd` |
| CR 验证失败 | CR 创建/更新被拒绝 | admission webhook denied | `kubectl apply` 输出 |
| Operator 崩溃 | 控制器 Pod 重启 | CrashLoopBackOff | `kubectl get pods` |
| Reconcile 失败 | CR 状态不更新 | Status 无变化 | CR 状态字段 |
| 无限重试 | Reconcile 持续失败 | 日志中重复错误 | Operator 日志 |
| Finalizer 阻塞 | 资源无法删除 | Terminating 状态 | `kubectl get` |
| Webhook 超时 | CR 操作超时 | context deadline exceeded | API Server 日志 |

### 1.3 影响分析

| 问题类型 | 直接影响 | 间接影响 | 影响范围 |
|----------|----------|----------|----------|
| CRD 缺失 | 无法使用自定义资源 | 依赖该 CRD 的组件失效 | 整个 CRD 类型 |
| Operator 崩溃 | CR 不被处理 | 业务工作负载无法管理 | 所有该类型 CR |
| Reconcile 失败 | 单个 CR 状态异常 | 关联资源不同步 | 特定 CR 实例 |
| Webhook 问题 | CR 操作被阻塞 | 新资源无法创建 | 所有 CR 操作 |
| Finalizer 阻塞 | 资源删除卡住 | namespace 可能无法删除 | 特定资源 |

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
CRD/Operator 问题
        │
        ▼
┌───────────────────────┐
│  问题发生在哪个阶段？  │
└───────────────────────┘
        │
        ├── CR 创建/更新失败 ───────────────────────────────┐
        │                                                    │
        │   ┌─────────────────────────────────────────┐     │
        │   │ kubectl apply -f cr.yaml 报错?          │     │
        │   └─────────────────────────────────────────┘     │
        │                  │                                 │
        │                  ▼                                 │
        │   ┌─────────────────────────────────────────┐     │
        │   │ "no matches for kind"?                  │     │
        │   └─────────────────────────────────────────┘     │
        │          │                │                        │
        │         是               否                        │
        │          │                │                        │
        │          ▼                ▼                        │
        │   ┌────────────┐   ┌────────────────┐             │
        │   │ CRD 未安装 │   │ "admission     │             │
        │   │ 或版本错误 │   │ webhook denied"│             │
        │   └────────────┘   └────────────────┘             │
        │                           │                        │
        │                           ▼                        │
        │                    ┌────────────┐                 │
        │                    │ Webhook    │                 │
        │                    │ 验证失败   │                 │
        │                    └────────────┘                 │
        │                                                    │
        ├── CR 状态不更新 ──────────────────────────────────┤
        │                                                    │
        │   ┌─────────────────────────────────────────┐     │
        │   │ 检查 Operator 状态                      │     │
        │   │ kubectl get pods -n <operator-ns>       │     │
        │   └─────────────────────────────────────────┘     │
        │                  │                                 │
        │                  ▼                                 │
        │   ┌─────────────────────────────────────────┐     │
        │   │ Operator Pod 运行正常?                  │     │
        │   └─────────────────────────────────────────┘     │
        │          │                │                        │
        │         否               是                        │
        │          │                │                        │
        │          ▼                ▼                        │
        │   ┌────────────┐   ┌────────────────┐             │
        │   │ 检查 Pod   │   │ 检查 Operator  │             │
        │   │ 启动日志   │   │ Reconcile 日志 │             │
        │   └────────────┘   └────────────────┘             │
        │                                                    │
        ├── CR 删除卡住 ────────────────────────────────────┤
        │                                                    │
        │   ┌─────────────────────────────────────────┐     │
        │   │ 检查 Finalizers                         │     │
        │   │ kubectl get <cr> -o yaml | grep final   │     │
        │   └─────────────────────────────────────────┘     │
        │                  │                                 │
        │                  ▼                                 │
        │   ┌─────────────────────────────────────────┐     │
        │   │ 有 Finalizer 且删除时间已设置?          │     │
        │   └─────────────────────────────────────────┘     │
        │          │                │                        │
        │         是               否                        │
        │          │                │                        │
        │          ▼                ▼                        │
        │   ┌────────────┐   ┌────────────────┐             │
        │   │ Operator   │   │ 其他问题       │             │
        │   │ 无法清理   │   │                │             │
        │   │ Finalizer  │   │                │             │
        │   └────────────┘   └────────────────┘             │
        │                                                    │
        └── Operator 本身问题 ──────────────────────────────┤
                                                             │
            ┌─────────────────────────────────────────┐     │
            │ 检查 Operator Deployment/Pod            │     │
            │ kubectl logs <operator-pod> -f          │     │
            └─────────────────────────────────────────┘     │
                           │                                 │
                           ▼                                 │
            ┌─────────────────────────────────────────┐     │
            │ 是否有 RBAC 权限错误?                   │     │
            └─────────────────────────────────────────┘     │
                   │                │                        │
                  是               否                        │
                   │                │                        │
                   ▼                ▼                        │
            ┌────────────┐   ┌────────────────┐             │
            │ 检查       │   │ 检查代码逻辑   │             │
            │ RBAC 配置  │   │ 或依赖服务     │             │
            └────────────┘   └────────────────┘             │
                                                             │
                                                             ▼
                                                      ┌────────────┐
                                                      │ 问题定位   │
                                                      │ 完成       │
                                                      └────────────┘
```

### 2.2 排查命令集

#### CRD 状态检查

```bash
# 列出所有 CRD
kubectl get crd

# 检查特定 CRD 详情
kubectl describe crd <crd-name>

# 检查 CRD 版本和状态
kubectl get crd <crd-name> -o yaml | grep -A20 "status:"

# 检查 CRD 是否有多个版本
kubectl get crd <crd-name> -o jsonpath='{.spec.versions[*].name}'

# 检查 CRD 的存储版本
kubectl get crd <crd-name> -o jsonpath='{.status.storedVersions}'

# 检查 Conversion Webhook 配置
kubectl get crd <crd-name> -o yaml | grep -A10 "conversion:"
```

#### CR 状态检查

```bash
# 列出自定义资源
kubectl get <resource-type> -A

# 查看 CR 详细信息
kubectl describe <resource-type> <name> -n <namespace>

# 检查 CR 的 Status
kubectl get <resource-type> <name> -n <namespace> -o jsonpath='{.status}'

# 检查 CR 的 Finalizers
kubectl get <resource-type> <name> -n <namespace> -o jsonpath='{.metadata.finalizers}'

# 检查 CR 的删除时间戳 (如果处于删除中)
kubectl get <resource-type> <name> -n <namespace> -o jsonpath='{.metadata.deletionTimestamp}'

# 查看 CR 的事件
kubectl get events -n <namespace> --field-selector involvedObject.name=<cr-name>
```

#### Operator 状态检查

```bash
# 检查 Operator 部署
kubectl get deployment -n <operator-namespace>
kubectl get pods -n <operator-namespace>

# 查看 Operator 日志
kubectl logs -n <operator-namespace> -l control-plane=controller-manager -f
kubectl logs -n <operator-namespace> <operator-pod> --tail=100

# 检查 Operator 的 RBAC
kubectl get clusterrole | grep <operator-name>
kubectl describe clusterrole <operator-role>

kubectl get clusterrolebinding | grep <operator-name>
kubectl describe clusterrolebinding <operator-binding>

# 检查 Operator 的 ServiceAccount
kubectl get sa -n <operator-namespace>
kubectl describe sa <operator-sa> -n <operator-namespace>
```

#### Webhook 检查

```bash
# 列出 Validating Webhooks
kubectl get validatingwebhookconfigurations

# 列出 Mutating Webhooks
kubectl get mutatingwebhookconfigurations

# 检查特定 Webhook 配置
kubectl describe validatingwebhookconfiguration <name>

# 检查 Webhook 服务
kubectl get svc -n <webhook-namespace>
kubectl get endpoints -n <webhook-namespace>

# 检查 Webhook Pod 日志
kubectl logs -n <webhook-namespace> <webhook-pod>
```

### 2.3 排查注意事项

| 注意事项 | 说明 | 风险等级 |
|----------|------|----------|
| 删除 CRD 会级联删除所有 CR | CRD 删除操作不可逆 | 高 |
| 手动移除 Finalizer 可能导致资源泄露 | Finalizer 存在是有原因的 | 高 |
| CRD 版本升级需要谨慎 | 可能导致数据迁移问题 | 中 |
| Webhook 故障影响面广 | 可能阻塞整个资源类型的操作 | 高 |
| Operator RBAC 变更需重启 | 权限变更后 Pod 需要重启 | 低 |

## 第三部分：解决方案与风险控制

### 3.1 CRD 未找到/版本错误

**问题现象**：`kubectl apply` 报 `no matches for kind "XXX" in version "xxx/v1"`

**解决步骤**：

```bash
# 步骤 1: 确认 CRD 是否存在
kubectl get crd | grep <expected-crd-name>

# 步骤 2: 如果不存在，安装 CRD
# 通常 CRD 随 Operator 一起安装
kubectl apply -f <operator-installation.yaml>
# 或单独安装 CRD
kubectl apply -f <crd-definition.yaml>

# 步骤 3: 如果 CRD 存在但版本不匹配，检查可用版本
kubectl get crd <crd-name> -o jsonpath='{.spec.versions[*].name}'

# 步骤 4: 修改 CR 的 apiVersion 以匹配
# 例如从 v1alpha1 改为 v1beta1

# 步骤 5: 验证
kubectl apply -f <cr.yaml> --dry-run=client
```

**CRD 版本示例**：

```yaml
# 检查 CR 的 apiVersion 是否与 CRD 支持的版本匹配
apiVersion: mygroup.example.com/v1  # 确保此版本在 CRD 中已定义
kind: MyResource
metadata:
  name: my-resource
spec:
  # ...
```

### 3.2 Webhook 验证失败

**问题现象**：`admission webhook "xxx" denied the request: xxx`

**解决步骤**：

```bash
# 步骤 1: 分析拒绝原因
# 错误信息通常会说明拒绝原因

# 步骤 2: 检查 Webhook 配置
kubectl get validatingwebhookconfigurations -o yaml | grep -A20 <webhook-name>

# 步骤 3: 查看 Webhook 服务日志
kubectl logs -n <namespace> -l app=<webhook-app> --tail=50

# 步骤 4: 检查 CR 是否符合验证规则
# 常见问题:
# - 必填字段缺失
# - 字段值不在允许范围
# - 资源命名不符合规范

# 步骤 5: 修复 CR 配置后重试
kubectl apply -f <fixed-cr.yaml>
```

**临时禁用 Webhook（紧急情况）**：

```bash
# ⚠️ 警告：这会跳过所有验证，仅在紧急情况使用

# 方法 1: 添加 failurePolicy: Ignore
kubectl patch validatingwebhookconfiguration <name> --type='json' \
  -p='[{"op": "replace", "path": "/webhooks/0/failurePolicy", "value": "Ignore"}]'

# 方法 2: 删除 Webhook 配置（更危险）
kubectl delete validatingwebhookconfiguration <name>

# 恢复后务必重新启用
```

### 3.3 Operator Reconcile 失败

**问题现象**：CR 状态不更新，Operator 日志显示 reconcile 错误。

**解决步骤**：

```bash
# 步骤 1: 查看 Operator 日志定位错误
kubectl logs -n <operator-ns> <operator-pod> -f | grep -i "error\|reconcile"

# 步骤 2: 常见 Reconcile 错误分析

# 错误类型 1: RBAC 权限不足
# 日志: "cannot create/update/delete xxx: forbidden"
# 解决: 检查并修复 ClusterRole/ClusterRoleBinding
kubectl describe clusterrole <operator-role>
# 添加缺失的权限

# 错误类型 2: 依赖资源不存在
# 日志: "xxx not found"
# 解决: 创建依赖资源或检查 CR 配置

# 错误类型 3: 资源规格错误
# 日志: "invalid spec: xxx"
# 解决: 修复 CR 规格定义

# 步骤 3: 触发重新 Reconcile
# 方法 1: 添加/修改 annotation
kubectl annotate <resource-type> <name> force-reconcile=$(date +%s) -n <namespace>

# 方法 2: 重启 Operator (影响所有 CR)
kubectl rollout restart deployment <operator-deployment> -n <operator-namespace>
```

### 3.4 RBAC 权限问题

**问题现象**：Operator 日志显示 `forbidden` 或 `unauthorized` 错误。

**解决步骤**：

```bash
# 步骤 1: 识别缺失的权限
kubectl logs -n <operator-ns> <operator-pod> | grep -i "forbidden\|cannot"
# 示例输出: cannot create deployments.apps in namespace "xxx"

# 步骤 2: 检查当前 ClusterRole
kubectl get clusterrole <operator-role> -o yaml

# 步骤 3: 添加缺失的权限
kubectl edit clusterrole <operator-role>
```

**ClusterRole 权限示例**：

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: my-operator-role
rules:
# 对自定义资源的完全控制
- apiGroups: ["mygroup.example.com"]
  resources: ["myresources", "myresources/status", "myresources/finalizers"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]

# 对 Deployment 的操作权限
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]

# 对 Service 的操作权限
- apiGroups: [""]
  resources: ["services", "configmaps", "secrets"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]

# 对事件的创建权限
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "patch"]
```

```bash
# 步骤 4: 重启 Operator 使新权限生效
kubectl rollout restart deployment <operator-deployment> -n <operator-namespace>
```

### 3.5 Finalizer 导致资源删除卡住

**问题现象**：CR 一直处于 `Terminating` 状态无法删除。

**解决步骤**：

```bash
# 步骤 1: 检查 Finalizers
kubectl get <resource-type> <name> -n <namespace> -o jsonpath='{.metadata.finalizers}'

# 步骤 2: 检查删除时间戳
kubectl get <resource-type> <name> -n <namespace> -o jsonpath='{.metadata.deletionTimestamp}'

# 步骤 3: 检查 Operator 是否在处理 Finalizer
kubectl logs -n <operator-ns> <operator-pod> | grep -i "finalizer\|cleanup"

# 步骤 4: 如果 Operator 正常但清理失败，检查日志找出原因
# 常见原因:
# - 依赖资源删除失败
# - 外部资源清理失败 (如云资源)
# - RBAC 权限不足

# 步骤 5: 解决阻塞原因后，Operator 应自动移除 Finalizer

# 步骤 6: 如果必须强制删除 (最后手段，可能导致资源泄露)
kubectl patch <resource-type> <name> -n <namespace> --type='json' \
  -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
```

**警告**：强制移除 Finalizer 可能导致：
- 云资源 (如 EBS 卷、LoadBalancer) 未被清理
- 相关的 Kubernetes 资源未被删除
- 产生孤儿资源

### 3.6 Operator Pod 启动失败

**问题现象**：Operator Pod CrashLoopBackOff 或一直 Pending。

**解决步骤**：

```bash
# 步骤 1: 检查 Pod 状态和事件
kubectl describe pod <operator-pod> -n <operator-namespace>

# 步骤 2: 根据状态诊断

# 如果是 ImagePullBackOff
kubectl get pod <operator-pod> -n <operator-ns> -o jsonpath='{.status.containerStatuses[0].state}'
# 检查镜像拉取凭证

# 如果是 CrashLoopBackOff
kubectl logs <operator-pod> -n <operator-ns> --previous

# 步骤 3: 常见启动错误

# 错误 1: 无法连接 API Server
# 检查 ServiceAccount 和 Token

# 错误 2: Leader Election 失败
# 检查 Lease 对象
kubectl get lease -n <operator-ns>

# 错误 3: 依赖的 CRD 不存在
# 安装所需 CRD

# 步骤 4: 修复后重新部署
kubectl rollout restart deployment <operator-deployment> -n <operator-ns>
```

### 3.7 CRD 版本升级/迁移

**问题现象**：CRD 版本升级后，旧版本 CR 不兼容。

**解决步骤**：

```bash
# 步骤 1: 检查当前存储版本
kubectl get crd <crd-name> -o jsonpath='{.status.storedVersions}'

# 步骤 2: 如果需要版本转换，配置 Conversion Webhook
# 或使用 kubectl-convert 工具

# 步骤 3: 验证 Conversion Webhook 运行正常
kubectl get svc -n <webhook-namespace>
kubectl logs -n <webhook-namespace> <conversion-webhook-pod>

# 步骤 4: 测试版本转换
kubectl get <resource-type> <name> -o yaml
# 应该能以任何支持的版本获取

# 步骤 5: 升级 CRD (保留旧版本)
kubectl apply -f <new-crd-with-conversion.yaml>

# 步骤 6: 迁移所有 CR 到新版本
# 逐个更新 CR 的 apiVersion

# 步骤 7: 移除旧版本 (可选，需谨慎)
# 只有确认所有 CR 已迁移后才能移除
```

**带 Conversion Webhook 的 CRD 示例**：

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: myresources.mygroup.example.com
spec:
  group: mygroup.example.com
  names:
    kind: MyResource
    plural: myresources
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true  # 存储版本
    schema:
      openAPIV3Schema:
        # ...
  - name: v1beta1
    served: true
    storage: false
    schema:
      openAPIV3Schema:
        # ...
  conversion:
    strategy: Webhook
    webhook:
      conversionReviewVersions: ["v1"]
      clientConfig:
        service:
          namespace: my-operator-system
          name: my-operator-webhook-service
          path: /convert
        caBundle: <base64-encoded-ca-cert>
```

### 3.8 Namespace 删除卡住 (因 CR Finalizer)

**问题现象**：删除 namespace 时卡在 Terminating 状态，因为包含有 Finalizer 的 CR。

**解决步骤**：

```bash
# 步骤 1: 找出阻塞删除的资源
kubectl api-resources --verbs=list --namespaced -o name | \
  xargs -n 1 kubectl get -n <namespace> --ignore-not-found --show-kind

# 步骤 2: 检查每个资源的 Finalizers
kubectl get <resource-type> -n <namespace> -o json | jq '.items[] | {name: .metadata.name, finalizers: .metadata.finalizers}'

# 步骤 3: 确保 Operator 运行中以处理 Finalizers
kubectl get pods -A | grep <operator-name>

# 步骤 4: 如果 Operator 已删除或无法处理
# 方法 1: 重新部署 Operator 让它清理
# 方法 2: 手动清理 Finalizers (有风险)

# 步骤 5: 强制清理所有 CR 的 Finalizers (最后手段)
for cr in $(kubectl get <resource-type> -n <namespace> -o name); do
  kubectl patch $cr -n <namespace> --type='json' \
    -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
done

# 步骤 6: 如果 namespace 仍然卡住，清理 namespace finalizer
kubectl get namespace <namespace> -o json | jq '.spec.finalizers = []' | \
  kubectl replace --raw "/api/v1/namespaces/<namespace>/finalize" -f -
```

### 3.9 安全生产风险提示

| 操作 | 风险等级 | 潜在风险 | 建议措施 |
|------|----------|----------|----------|
| 删除 CRD | 极高 | 所有 CR 数据丢失 | 先备份所有 CR，确认无依赖 |
| 强制移除 Finalizer | 高 | 资源泄露、状态不一致 | 尽量让 Operator 正常清理 |
| 修改 Webhook failurePolicy | 高 | 跳过验证可能导致无效配置 | 仅紧急情况临时使用 |
| 升级 CRD 版本 | 中 | 可能导致 CR 不可用 | 保留旧版本，充分测试 |
| 重启 Operator | 低 | 短暂的 reconcile 中断 | 选择低峰期 |
| 修改 RBAC | 低 | 可能导致权限过大或不足 | 遵循最小权限原则 |

### 附录：快速诊断命令

```bash
# ===== CRD/Operator 一键诊断脚本 =====

echo "=== CRD 列表 ==="
kubectl get crd | head -20

echo -e "\n=== 检查特定 CRD 状态 ==="
# 替换 <crd-name> 为实际 CRD 名称
# kubectl describe crd <crd-name> | grep -A5 "Status:"

echo -e "\n=== Operator Pods 状态 ==="
kubectl get pods -A -l control-plane=controller-manager

echo -e "\n=== Webhook 配置 ==="
kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations

echo -e "\n=== 处于 Terminating 的 CR (可能有 Finalizer 问题) ==="
kubectl get all -A | grep Terminating

echo -e "\n=== 最近的 Operator 事件 ==="
kubectl get events -A --sort-by='.lastTimestamp' | grep -i operator | tail -10
```

### 附录：常见 Operator 框架

| 框架 | 语言 | 特点 | 典型日志位置 |
|------|------|------|--------------|
| Kubebuilder | Go | 官方推荐，功能完整 | controller-manager Pod |
| Operator SDK | Go/Ansible/Helm | 多语言支持 | manager Pod |
| KUDO | Declarative | 声明式，无需编码 | KUDO controller Pod |
| Metacontroller | JSON | 轻量级，Webhook 模式 | metacontroller Pod + 自定义 Webhook |
| kopf | Python | Python 原生，简单易用 | kopf controller Pod |

### 附录：Operator 开发最佳实践

```yaml
# 1. 设置合理的 Reconcile 重试策略
# controller-runtime 示例配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: controller-manager-config
data:
  controller_manager_config.yaml: |
    apiVersion: controller-runtime.sigs.k8s.io/v1alpha1
    kind: ControllerManagerConfig
    health:
      healthProbeBindAddress: :8081
    metrics:
      bindAddress: 127.0.0.1:8080
    leaderElection:
      leaderElect: true
      resourceName: my-operator-leader-lock

# 2. 正确使用 Status 子资源
# CRD 定义中启用 status 子资源
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
spec:
  # ...
  subresources:
    status: {}  # 启用 status 子资源
    
# 3. Finalizer 使用模式
# 在 Reconcile 中的标准模式:
# - 如果资源未被删除且没有 Finalizer，添加 Finalizer
# - 如果资源被标记删除，执行清理逻辑，然后移除 Finalizer
# - 清理失败则返回错误，触发重试
```
