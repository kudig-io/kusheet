# 表格42：RBAC权限矩阵表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/reference/access-authn-authz/rbac](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

## 内置ClusterRole

| 角色 | 权限范围 | 授予对象 | 使用场景 | 风险等级 | 危险操作 |
|-----|---------|---------|---------|---------|---------|
| **cluster-admin** | 全部资源，全部操作 | 超级管理员 | 集群管理 | 极高 | 节点删除/etcd访问/RBAC修改 |
| **admin** | 命名空间内全部权限 | 项目管理员 | 命名空间管理 | 高 | Secret访问/RBAC修改 |
| **edit** | 读写大部分资源 | 开发人员 | 日常开发 | 中 | Pod exec/Secret访问 |
| **view** | 只读权限 | 查看人员 | 监控/审计 | 低 | 敏感信息泄露 |
| **system:aggregate-to-admin** | 聚合到admin的规则 | 扩展角色 | CRD权限扩展 | 高 | 取决于聚合内容 |
| **system:aggregate-to-edit** | 聚合到edit的规则 | 扩展角色 | CRD权限扩展 | 中 | 取决于聚合内容 |
| **system:aggregate-to-view** | 聚合到view的规则 | 扩展角色 | CRD权限扩展 | 低 | 取决于聚合内容 |

## RBAC API组与资源

| API Group | 常见资源 | 说明 |
|-----------|---------|------|
| `""` (core) | pods, services, secrets, configmaps, pvc, nodes, namespaces | 核心API资源 |
| `apps` | deployments, statefulsets, daemonsets, replicasets | 工作负载控制器 |
| `batch` | jobs, cronjobs | 批处理任务 |
| `networking.k8s.io` | networkpolicies, ingresses, ingressclasses | 网络资源 |
| `rbac.authorization.k8s.io` | roles, rolebindings, clusterroles, clusterrolebindings | RBAC资源 |
| `storage.k8s.io` | storageclasses, volumeattachments, csidrivers | 存储资源 |
| `policy` | poddisruptionbudgets, podsecuritypolicies(废弃) | 策略资源 |
| `autoscaling` | horizontalpodautoscalers | 自动扩缩 |
| `certificates.k8s.io` | certificatesigningrequests | 证书管理 |
| `coordination.k8s.io` | leases | 租约/选举 |
| `admissionregistration.k8s.io` | validatingwebhookconfigurations, mutatingwebhookconfigurations | 准入控制 |
| `apiextensions.k8s.io` | customresourcedefinitions | CRD定义 |

## Verbs权限说明

| Verb | 说明 | HTTP方法 | 危险程度 | 注意事项 |
|------|------|----------|---------|---------|
| `get` | 读取单个资源 | GET | 低 | Secret需特别注意 |
| `list` | 列出资源集合 | GET | 低 | 可能泄露大量信息 |
| `watch` | 监听资源变更 | GET (streaming) | 低 | 长连接资源消耗 |
| `create` | 创建新资源 | POST | 中 | 可能创建特权Pod |
| `update` | 完整更新资源 | PUT | 中 | 可修改关键字段 |
| `patch` | 部分更新资源 | PATCH | 中 | 可修改关键字段 |
| `delete` | 删除单个资源 | DELETE | 高 | 不可逆操作 |
| `deletecollection` | 批量删除 | DELETE | 极高 | 可删除整个命名空间内容 |
| `impersonate` | 身份模拟 | - | 极高 | 可冒充任何用户 |
| `bind` | 绑定角色 | - | 极高 | 可提升自身权限 |
| `escalate` | 权限提升 | - | 极高 | 可创建超越自身权限的角色 |

## 权限矩阵(核心资源)

| 资源 | cluster-admin | admin | edit | view | 安全风险说明 |
|-----|---------------|-------|------|------|-------------|
| **Pods** | 全部 | 全部 | 全部 | 只读 | create可启动特权容器 |
| **Pods/exec** | ✓ | ✓ | ✓ | - | 可在容器内执行任意命令 |
| **Pods/attach** | ✓ | ✓ | ✓ | - | 可附加到运行中容器 |
| **Pods/portforward** | ✓ | ✓ | ✓ | - | 可绕过网络策略 |
| **Pods/log** | ✓ | ✓ | ✓ | ✓ | 可能泄露敏感日志 |
| **Pods/ephemeralcontainers** | ✓ | ✓ | ✓ | - | v1.25+ 调试容器 |
| **Deployments** | ✓ | ✓ | ✓ | 只读 | 可部署恶意工作负载 |
| **StatefulSets** | ✓ | ✓ | ✓ | 只读 | 可访问持久化数据 |
| **DaemonSets** | ✓ | ✓ | ✓ | 只读 | 可在所有节点运行 |
| **Services** | ✓ | ✓ | ✓ | 只读 | 可暴露内部服务 |
| **ConfigMaps** | ✓ | ✓ | ✓ | 只读 | 可能包含敏感配置 |
| **Secrets** | ✓ | ✓ | ✓ | - | 敏感凭据存储 |
| **PVC** | ✓ | ✓ | ✓ | 只读 | 可访问持久化数据 |
| **ServiceAccounts** | ✓ | ✓ | ✓ | 只读 | 可创建Token |
| **ServiceAccounts/token** | ✓ | ✓ | ✓ | - | v1.24+ TokenRequest |
| **Roles/RoleBindings** | ✓ | ✓ | - | - | 可提升命名空间内权限 |
| **ResourceQuotas** | ✓ | 只读 | - | 只读 | - |
| **LimitRanges** | ✓ | 只读 | - | 只读 | - |
| **Nodes** | ✓ | - | - | 只读 | 节点信息泄露 |
| **Nodes/proxy** | ✓ | - | - | - | 可访问kubelet API |
| **Namespaces** | ✓ | - | - | 只读 | - |
| **PV** | ✓ | - | - | 只读 | 可能访问其他命名空间数据 |
| **ClusterRoles** | ✓ | - | - | - | 可创建特权角色 |
| **ClusterRoleBindings** | ✓ | - | - | - | 可授予集群级权限 |

## 权限矩阵(扩展资源)

| 资源 | cluster-admin | admin | edit | view | 版本要求 |
|-----|---------------|-------|------|------|---------|
| **CronJobs** | ✓ | ✓ | ✓ | 只读 | - |
| **Jobs** | ✓ | ✓ | ✓ | 只读 | - |
| **HPA** | ✓ | ✓ | ✓ | 只读 | - |
| **PDB** | ✓ | ✓ | ✓ | 只读 | - |
| **NetworkPolicies** | ✓ | ✓ | ✓ | 只读 | - |
| **Ingresses** | ✓ | ✓ | ✓ | 只读 | - |
| **IngressClasses** | ✓ | - | - | 只读 | v1.18+ |
| **CSIDrivers** | ✓ | - | - | 只读 | - |
| **StorageClasses** | ✓ | - | - | 只读 | - |
| **VolumeSnapshots** | ✓ | ✓ | ✓ | 只读 | snapshot.storage.k8s.io |
| **Leases** | ✓ | ✓ | ✓ | 只读 | - |
| **EndpointSlices** | ✓ | ✓ | ✓ | 只读 | v1.21+ |
| **ValidatingWebhookConfigurations** | ✓ | - | - | - | - |
| **MutatingWebhookConfigurations** | ✓ | - | - | - | - |
| **APIServices** | ✓ | - | - | - | - |
| **CRDs** | ✓ | - | - | - | - |

## 危险权限组合

| 权限组合 | 风险等级 | 攻击路径 | 缓解措施 |
|---------|---------|---------|---------|
| `pods/exec` + `pods` create | 极高 | 创建特权Pod后exec进入 | 限制Pod安全上下文 |
| `secrets` + `serviceaccounts/token` | 极高 | 获取高权限SA的Token | 限制SA Token创建 |
| `nodes/proxy` | 极高 | 直接访问kubelet API | 仅授予cluster-admin |
| `daemonsets` create | 高 | 在所有节点运行恶意代码 | 限制到特定命名空间 |
| `rolebindings` create + `roles` create | 高 | 自我授权提升权限 | 使用bind权限控制 |
| `persistentvolumes` create | 高 | 访问主机路径或其他PV | 限制hostPath |
| `pods/attach` + `pods/exec` | 高 | 完全控制运行中容器 | 按需授权 |
| `impersonate` users/groups | 极高 | 冒充任何用户 | 严格限制 |
| `escalate` | 极高 | 创建超越自身的角色 | 仅授予管理员 |

## 自定义角色示例

```yaml
# 开发者角色(扩展edit)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: production
rules:
# 工作负载管理
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets", "daemonsets", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Pod管理
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec"]
  verbs: ["get", "list", "watch", "create", "delete"]
# 服务管理
- apiGroups: [""]
  resources: ["services", "endpoints"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# 配置管理
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Secrets只读
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
# 事件查看
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
# Ingress管理
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
# 运维角色
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ops
rules:
# 节点只读
- apiGroups: [""]
  resources: ["nodes", "nodes/status"]
  verbs: ["get", "list", "watch"]
# Pod全命名空间只读
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
# 事件查看
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
# 指标查看
- apiGroups: ["metrics.k8s.io"]
  resources: ["nodes", "pods"]
  verbs: ["get", "list"]
---
# 安全审计员角色
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: security-auditor
rules:
# RBAC审计
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  verbs: ["get", "list", "watch"]
# Pod安全策略审计
- apiGroups: [""]
  resources: ["pods", "serviceaccounts"]
  verbs: ["get", "list", "watch"]
# 网络策略审计
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["get", "list", "watch"]
# Secret元数据(不含内容)
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["list"]  # 仅list,不含get
# 审计日志
- apiGroups: ["audit.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
---
# 只读Secret角色
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
---
# CI/CD角色
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cicd
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments/scale"]
  verbs: ["update", "patch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "delete"]
---
# 资源限制的只读角色(resourceNames限制)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: specific-secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-config", "db-credentials"]  # 仅允许访问指定Secret
  verbs: ["get"]
---
# 监控系统角色
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/metrics", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics", "/metrics/cadvisor"]
  verbs: ["get"]
```

## 角色绑定

```yaml
# RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: production
subjects:
- kind: User
  name: alice
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
- kind: ServiceAccount
  name: ci-sa
  namespace: ci-system
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
---
# ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ops-binding
subjects:
- kind: Group
  name: ops-team
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: ops
  apiGroup: rbac.authorization.k8s.io
```

## 聚合ClusterRole

```yaml
# 聚合规则
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-edit
  labels:
    rbac.authorization.k8s.io/aggregate-to-edit: "true"  # 聚合到edit
rules:
- apiGroups: ["monitoring.coreos.com"]
  resources: ["servicemonitors", "podmonitors"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
# 基于聚合的ClusterRole(自动包含上面的规则)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: edit
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.authorization.k8s.io/aggregate-to-edit: "true"
rules: []  # 规则由聚合自动填充
```

## 权限检查

```bash
# 检查当前用户权限
kubectl auth can-i create pods
kubectl auth can-i '*' '*'

# 检查特定用户权限
kubectl auth can-i create pods --as alice
kubectl auth can-i create pods --as alice --namespace production

# 列出所有权限
kubectl auth can-i --list
kubectl auth can-i --list --namespace production

# 检查SA权限
kubectl auth can-i create pods --as system:serviceaccount:default:mysa

# 查看当前身份
kubectl auth whoami  # v1.27+
```

## 权限审计

```bash
# 查看所有ClusterRoleBinding
kubectl get clusterrolebindings -o wide

# 查找cluster-admin绑定
kubectl get clusterrolebindings -o json | jq '.items[] | select(.roleRef.name=="cluster-admin") | {name:.metadata.name, subjects:.subjects}'

# 查看用户的所有角色
kubectl get rolebindings,clusterrolebindings -A -o json | jq '.items[] | select(.subjects[]?.name=="alice")'

# 检查过度授权
kubectl get clusterrolebindings -o json | jq '.items[] | select(.subjects[]?.kind=="ServiceAccount") | select(.roleRef.name=="cluster-admin") | .metadata.name'

# 列出所有具有cluster-admin权限的主体
kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .subjects[] | "\(.kind)/\(.namespace // "cluster")/\(.name)"'

# 查找可以创建Pod的角色
kubectl get clusterroles -o json | jq '.items[] | select(.rules[]? | select(.resources[]? == "pods" and (.verbs[]? == "create" or .verbs[]? == "*"))) | .metadata.name'

# 查找具有Secret访问权限的ServiceAccount
kubectl get rolebindings,clusterrolebindings -A -o json | jq '.items[] | select(.subjects[]?.kind=="ServiceAccount") | {binding: .metadata.name, namespace: .metadata.namespace, role: .roleRef.name, sa: [.subjects[] | select(.kind=="ServiceAccount")]}'
```

## RBAC审计脚本

```bash
#!/bin/bash
# rbac-audit.sh - RBAC安全审计脚本

echo "=== RBAC Security Audit Report ==="
echo "Generated: $(date)"
echo ""

# 1. cluster-admin权限检查
echo "## 1. cluster-admin权限持有者"
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | select(.roleRef.name=="cluster-admin") |
  "Binding: \(.metadata.name)\n  Subjects: \([.subjects[]? | "\(.kind):\(.namespace // "N/A")/\(.name)"] | join(", "))\n"'

# 2. 危险权限检查
echo "## 2. 危险权限角色"
for role in $(kubectl get clusterroles -o name); do
  DANGEROUS=$(kubectl get $role -o json | jq '
    [.rules[]? | select(
      (.verbs[]? == "*") or
      (.resources[]? == "*") or
      (.resources[]? == "secrets" and (.verbs[]? == "get" or .verbs[]? == "*")) or
      (.resources[]? == "pods/exec") or
      (.resources[]? == "nodes/proxy")
    )] | length')
  if [ "$DANGEROUS" -gt 0 ]; then
    echo "  - $role (危险规则数: $DANGEROUS)"
  fi
done

# 3. ServiceAccount审计
echo ""
echo "## 3. 具有高权限的ServiceAccount"
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | select(.subjects[]?.kind=="ServiceAccount") |
  select(.roleRef.name | test("admin|edit|cluster-admin")) |
  "  - \(.metadata.name): \([.subjects[] | select(.kind=="ServiceAccount") | "\(.namespace)/\(.name)"] | join(", ")) -> \(.roleRef.name)"'

# 4. 未绑定的ServiceAccount检查
echo ""
echo "## 4. 默认SA权限检查"
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  BINDINGS=$(kubectl get rolebindings,clusterrolebindings -A -o json 2>/dev/null | \
    jq -r ".items[] | select(.subjects[]? | select(.kind==\"ServiceAccount\" and .name==\"default\" and .namespace==\"$ns\")) | .metadata.name" | wc -l)
  if [ "$BINDINGS" -gt 0 ]; then
    echo "  - $ns/default: $BINDINGS 个绑定"
  fi
done

# 5. 过期/无效绑定检查
echo ""
echo "## 5. 无效绑定检查"
kubectl get rolebindings,clusterrolebindings -A -o json | jq -r '
  .items[] | select(.subjects == null or (.subjects | length) == 0) |
  "  - \(.metadata.namespace // "cluster-scope")/\(.metadata.name): 无subjects"'

echo ""
echo "=== Audit Complete ==="
```

## ServiceAccount安全配置

```yaml
# 安全的ServiceAccount配置
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: production
automountServiceAccountToken: false  # 禁用自动挂载
---
# 需要API访问时的Pod配置
apiVersion: v1
kind: Pod
metadata:
  name: api-client
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: true  # 显式启用
  containers:
  - name: app
    image: app:v1
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      capabilities:
        drop: ["ALL"]
---
# 限制Token有效期(v1.22+)
apiVersion: v1
kind: Pod
metadata:
  name: short-lived-token
spec:
  serviceAccountName: app-sa
  containers:
  - name: app
    image: app:v1
    volumeMounts:
    - name: token
      mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      readOnly: true
  volumes:
  - name: token
    projected:
      sources:
      - serviceAccountToken:
          path: token
          expirationSeconds: 3600  # 1小时过期
          audience: api  # 限制audience
      - configMap:
          name: kube-root-ca.crt
          items:
          - key: ca.crt
            path: ca.crt
      - downwardAPI:
          items:
          - path: namespace
            fieldRef:
              fieldPath: metadata.namespace
```

## Bound Service Account Token

```yaml
# v1.24+ TokenRequest API
apiVersion: v1
kind: Pod
metadata:
  name: bound-token-pod
spec:
  serviceAccountName: app-sa
  containers:
  - name: app
    image: app:v1
    env:
    - name: TOKEN_PATH
      value: /var/run/secrets/tokens/api-token
    volumeMounts:
    - name: api-token
      mountPath: /var/run/secrets/tokens
      readOnly: true
  volumes:
  - name: api-token
    projected:
      sources:
      - serviceAccountToken:
          path: api-token
          expirationSeconds: 7200  # 2小时
          audience: https://kubernetes.default.svc
```

```bash
# 手动创建限时Token
kubectl create token app-sa \
  --duration=1h \
  --audience=https://my-app.example.com \
  -n production
```

## RBAC最佳实践

| 实践 | 说明 | 优先级 | 实施方法 |
|-----|------|-------|---------|
| **最小权限** | 仅授予必需权限 | P0 | 使用resourceNames限制具体资源 |
| **避免cluster-admin** | 使用更细粒度角色 | P0 | 创建自定义ClusterRole |
| **独立ServiceAccount** | 每工作负载独立SA | P1 | 为每个Deployment创建SA |
| **禁用SA自动挂载** | automountServiceAccountToken: false | P1 | 在SA和Pod层面设置 |
| **定期审计** | 检查权限绑定 | P1 | 定时运行审计脚本 |
| **使用组** | 通过组管理权限 | P2 | 配置OIDC组映射 |
| **限制通配符** | 避免使用* | P1 | 显式列出资源和动作 |
| **命名空间隔离** | 使用Role而非ClusterRole | P1 | 按命名空间授权 |
| **Token有效期** | 使用短期Token | P2 | 配置TokenRequest |
| **审计日志** | 启用RBAC审计 | P1 | 配置审计策略 |

## RBAC故障排查

```bash
# 检查为什么权限被拒绝
kubectl auth can-i create pods --as alice -v=8

# 检查角色规则
kubectl get role developer -n production -o yaml

# 检查绑定
kubectl get rolebinding -n production -o wide

# 检查SA的Token
kubectl get sa app-sa -n production -o yaml

# 检查API Server审计日志中的RBAC决策
# 审计日志路径: /var/log/kubernetes/audit.log
grep "authorization.k8s.io" /var/log/kubernetes/audit.log | jq 'select(.responseStatus.code != 200)'

# 使用kubectl-who-can插件
kubectl who-can create pods
kubectl who-can get secrets -n production
```

## RBAC Prometheus指标

```yaml
# PrometheusRule for RBAC监控
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: rbac-alerts
spec:
  groups:
  - name: rbac
    rules:
    - alert: ClusterAdminBindingCreated
      expr: |
        increase(apiserver_request_total{
          resource="clusterrolebindings",
          verb="create"
        }[5m]) > 0
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "新的ClusterRoleBinding被创建"
        
    - alert: UnauthorizedAccessAttempts
      expr: |
        sum(rate(apiserver_audit_event_total{
          responseStatus_code="403"
        }[5m])) > 10
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "检测到大量未授权访问尝试"
        
    - alert: ServiceAccountTokenCreation
      expr: |
        increase(apiserver_request_total{
          resource="serviceaccounts/token",
          verb="create"
        }[5m]) > 10
      for: 5m
      labels:
        severity: info
      annotations:
        summary: "检测到大量SA Token创建"
```

## ACK RAM集成

```yaml
# RAM用户绑定
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ram-admin
subjects:
- kind: User
  name: "UID:<ram-user-id>"  # RAM用户ID
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
---
# RAM角色绑定
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ram-role-binding
subjects:
- kind: User
  name: "RAM Role:<ram-role-name>"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
---
# RAM用户组绑定
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ram-group-binding
subjects:
- kind: Group
  name: "RAM Group:<ram-group-name>"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
```

## ACK预置角色

| ACK角色 | 对应K8s权限 | 说明 |
|--------|------------|------|
| **集群管理员** | cluster-admin | 完全管理权限 |
| **运维人员** | admin (所有namespace) | 命名空间管理 |
| **开发人员** | edit (指定namespace) | 工作负载管理 |
| **受限用户** | view (指定namespace) | 只读权限 |
| **自定义** | 自定义ClusterRole/Role | 按需配置 |

```bash
# ACK获取kubeconfig(含RAM权限)
aliyun cs GET /k8s/<cluster-id>/user_config --PrivateIpAddress true

# 使用RAM角色访问集群
aliyun cs GET /k8s/<cluster-id>/user_config \
  --TemporaryDurationMinutes 60 \
  --RoleArn acs:ram::<account-id>:role/<role-name>
```

## OIDC集成配置

```yaml
# API Server OIDC配置
# /etc/kubernetes/manifests/kube-apiserver.yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --oidc-issuer-url=https://accounts.google.com
    - --oidc-client-id=kubernetes
    - --oidc-username-claim=email
    - --oidc-groups-claim=groups
    - --oidc-username-prefix=oidc:
    - --oidc-groups-prefix=oidc:
---
# OIDC用户绑定
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: oidc-admin
subjects:
- kind: User
  name: "oidc:admin@example.com"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
---
# OIDC组绑定
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: oidc-developers
subjects:
- kind: Group
  name: "oidc:developers"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
```

## 版本变更

| 版本 | 变更内容 |
|-----|---------|
| v1.24 | 不再自动创建Secret for SA, 使用TokenRequest API |
| v1.25 | PodSecurityPolicy彻底移除 |
| v1.27 | `kubectl auth whoami`命令添加 |
| v1.28 | ValidatingAdmissionPolicy GA |
| v1.29 | 改进的审计日志格式 |

---

**RBAC原则**: 最小权限 + 定期审计 + 组管理 + 短期Token + 命名空间隔离
