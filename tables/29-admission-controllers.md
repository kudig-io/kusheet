# 表格29: 准入控制器配置

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/reference/access-authn-authz/admission-controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)

## 准入控制流程

```
API请求 → 认证 → 授权 → Mutating Admission → Object Schema验证 → Validating Admission → 持久化到etcd
                         ↓                                        ↓
                    修改请求内容                              验证请求合法性
```

## 内置准入控制器

| 控制器名称 | 类型 | 默认启用 | 功能 | v1.32状态 |
|-----------|-----|---------|------|----------|
| AlwaysAdmit | Validating | ❌ | 允许所有请求 | 仅测试用 |
| AlwaysDeny | Validating | ❌ | 拒绝所有请求 | 仅测试用 |
| AlwaysPullImages | Mutating | ❌ | 强制拉取镜像 | 可选 |
| CertificateApproval | Validating | ✅ | CSR审批权限 | GA |
| CertificateSigning | Validating | ✅ | CSR签名权限 | GA |
| CertificateSubjectRestriction | Validating | ✅ | CSR主体限制 | GA |
| DefaultIngressClass | Mutating | ✅ | 默认Ingress类 | GA |
| DefaultStorageClass | Mutating | ✅ | 默认存储类 | GA |
| DefaultTolerationSeconds | Mutating | ✅ | 默认容忍时间 | GA |
| DenyServiceExternalIPs | Validating | ❌ | 禁止外部IP | 可选 |
| EventRateLimit | Validating | ❌ | 事件限流 | Alpha |
| ExtendedResourceToleration | Mutating | ❌ | 扩展资源容忍 | 可选 |
| ImagePolicyWebhook | Validating | ❌ | 镜像策略 | 可选 |
| LimitPodHardAntiAffinityTopology | Validating | ❌ | 限制反亲和 | 可选 |
| LimitRanger | Mutating+Validating | ✅ | 资源限制 | GA |
| MutatingAdmissionWebhook | Mutating | ✅ | 自定义变更 | GA |
| NamespaceAutoProvision | Mutating | ❌ | 自动创建NS | 可选 |
| NamespaceExists | Validating | ✅ | NS存在检查 | GA |
| NamespaceLifecycle | Validating | ✅ | NS生命周期 | GA |
| NodeRestriction | Validating | ✅ | 节点权限限制 | GA |
| OwnerReferencesPermissionEnforcement | Validating | ❌ | owner引用权限 | 可选 |
| PodNodeSelector | Validating | ❌ | 节点选择器限制 | 可选 |
| PodSecurity | Validating | ✅(v1.25+) | Pod安全标准 | GA |
| PodTolerationRestriction | Validating | ❌ | 容忍限制 | 可选 |
| Priority | Mutating | ✅ | 优先级注入 | GA |
| ResourceQuota | Validating | ✅ | 资源配额 | GA |
| RuntimeClass | Mutating | ✅ | 运行时类注入 | GA |
| ServiceAccount | Mutating+Validating | ✅ | SA自动挂载 | GA |
| StorageObjectInUseProtection | Validating | ✅ | 存储保护 | GA |
| TaintNodesByCondition | Mutating | ✅ | 节点污点 | GA |
| ValidatingAdmissionPolicy | Validating | ✅(v1.30+) | CEL验证策略 | GA |
| ValidatingAdmissionWebhook | Validating | ✅ | 自定义验证 | GA |

## 已废弃/移除的控制器

| 控制器名称 | 废弃版本 | 移除版本 | 替代方案 |
|-----------|---------|---------|---------|
| PodSecurityPolicy | v1.21 | v1.25 | PodSecurity |
| SecurityContextDeny | v1.27 | - | PodSecurity |

## 推荐启用顺序

```bash
# kube-apiserver启动参数
--enable-admission-plugins=\
NamespaceLifecycle,\
LimitRanger,\
ServiceAccount,\
TaintNodesByCondition,\
Priority,\
DefaultTolerationSeconds,\
DefaultStorageClass,\
StorageObjectInUseProtection,\
PersistentVolumeClaimResize,\
RuntimeClass,\
CertificateApproval,\
CertificateSigning,\
CertificateSubjectRestriction,\
DefaultIngressClass,\
MutatingAdmissionWebhook,\
ValidatingAdmissionPolicy,\
ValidatingAdmissionWebhook,\
ResourceQuota,\
PodSecurity,\
NodeRestriction

# 禁用特定控制器
--disable-admission-plugins=AlwaysAdmit
```

## 控制器执行顺序

| 阶段 | 控制器类型 | 执行顺序 | 说明 |
|-----|-----------|---------|------|
| 1 | Mutating | 按配置顺序 | 可修改请求,可执行多次 |
| 2 | Object Validation | 内置 | Schema验证 |
| 3 | Validating | 并行执行 | 只能拒绝,不能修改 |

## Webhook配置

| 字段 | 类型 | 必需 | 说明 | 默认值 |
|-----|-----|-----|------|-------|
| `name` | string | ✅ | Webhook名称(FQDN格式) | - |
| `clientConfig.url` | string | ⚠️ | Webhook URL(外部) | - |
| `clientConfig.service` | ServiceRef | ⚠️ | 集群内服务引用 | - |
| `clientConfig.caBundle` | []byte | ✅ | CA证书(Base64) | - |
| `rules` | []Rule | ✅ | 匹配规则 | - |
| `failurePolicy` | Fail/Ignore | ❌ | 失败策略 | Fail |
| `matchPolicy` | Exact/Equivalent | ❌ | 版本匹配策略 | Equivalent |
| `sideEffects` | None/Some/NoneOnDryRun/Unknown | ✅ | 副作用声明 | - |
| `timeoutSeconds` | int | ❌ | 超时时间 | 10s |
| `admissionReviewVersions` | []string | ✅ | API版本 | - |
| `matchConditions` | []MatchCondition | ❌ | CEL匹配条件(v1.28+) | - |
| `namespaceSelector` | LabelSelector | ❌ | 命名空间选择器 | 匹配所有 |
| `objectSelector` | LabelSelector | ❌ | 对象选择器 | 匹配所有 |
| `reinvocationPolicy` | Never/IfNeeded | ❌ | 重新调用策略(Mutating) | Never |

## Webhook配置示例

```yaml
# ValidatingWebhookConfiguration完整示例
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: pod-policy.example.com
  labels:
    app: pod-policy
webhooks:
- name: pod-policy.example.com
  clientConfig:
    service:
      namespace: webhook-system
      name: webhook-service
      path: /validate-pods
      port: 443
    caBundle: LS0tLS1CRUdJTi...  # Base64编码的CA证书
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    operations: ["CREATE", "UPDATE"]
    resources: ["pods"]
    scope: Namespaced
  failurePolicy: Fail
  sideEffects: None
  admissionReviewVersions: ["v1", "v1beta1"]
  # v1.28+ CEL匹配条件
  matchConditions:
  - name: exclude-system-namespaces
    expression: "!request.namespace.startsWith('kube-')"
  - name: exclude-leases
    expression: "request.resource.resource != 'leases'"
  # 命名空间选择
  namespaceSelector:
    matchExpressions:
    - key: environment
      operator: In
      values: ["production", "staging"]
  # 对象选择
  objectSelector:
    matchLabels:
      webhook-enabled: "true"
  timeoutSeconds: 5
---
# MutatingWebhookConfiguration示例
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: sidecar-injector.example.com
webhooks:
- name: sidecar-injector.example.com
  clientConfig:
    service:
      namespace: injection-system
      name: sidecar-injector
      path: /inject
      port: 443
    caBundle: LS0tLS1CRUdJTi...
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    operations: ["CREATE"]
    resources: ["pods"]
    scope: Namespaced
  failurePolicy: Ignore  # Sidecar注入失败不阻止Pod创建
  sideEffects: None
  admissionReviewVersions: ["v1"]
  reinvocationPolicy: IfNeeded  # 如果其他webhook修改了pod则重新调用
  namespaceSelector:
    matchLabels:
      sidecar-injection: enabled
  timeoutSeconds: 10
```

## Webhook服务端实现

```yaml
# Webhook Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webhook-server
  namespace: webhook-system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webhook-server
  template:
    metadata:
      labels:
        app: webhook-server
    spec:
      containers:
      - name: webhook
        image: webhook-server:v1
        ports:
        - containerPort: 8443
          name: webhook
        volumeMounts:
        - name: tls
          mountPath: /etc/webhook/certs
          readOnly: true
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8443
            scheme: HTTPS
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8443
            scheme: HTTPS
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 128Mi
      volumes:
      - name: tls
        secret:
          secretName: webhook-server-tls
---
apiVersion: v1
kind: Service
metadata:
  name: webhook-service
  namespace: webhook-system
spec:
  ports:
  - port: 443
    targetPort: 8443
    protocol: TCP
  selector:
    app: webhook-server
```

## ValidatingAdmissionPolicy (v1.30+ GA)

| 字段 | 说明 | 示例 |
|-----|------|------|
| `spec.matchConstraints` | 匹配条件 | 资源类型、操作等 |
| `spec.validations` | CEL验证规则 | `object.spec.replicas <= 100` |
| `spec.auditAnnotations` | 审计注解 | 记录验证结果 |
| `spec.failurePolicy` | 失败策略 | Fail/Ignore |
| `spec.matchConditions` | CEL匹配条件 | 细粒度过滤 |
| `spec.variables` | 变量定义 | CEL变量 |
| `spec.paramKind` | 参数类型引用 | 外部配置 |

## ValidatingAdmissionPolicy详细示例

```yaml
# 基础策略: 副本数限制
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: replica-limit
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: ["apps"]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["deployments", "replicasets", "statefulsets"]
  validations:
  - expression: "object.spec.replicas <= 100"
    message: "副本数不能超过100"
    reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: replica-limit-binding
spec:
  policyName: replica-limit
  validationActions:
  - Deny
  - Audit
  matchResources:
    namespaceSelector:
      matchLabels:
        environment: production
---
# 高级策略: 使用变量和参数
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: image-registry-policy
spec:
  failurePolicy: Fail
  paramKind:
    apiVersion: v1
    kind: ConfigMap
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  variables:
  - name: allowedRegistries
    expression: "params.data.allowedRegistries.split(',')"
  - name: containers
    expression: "object.spec.containers + object.spec.?initContainers.orValue([])"
  validations:
  - expression: |
      variables.containers.all(c,
        variables.allowedRegistries.exists(r, c.image.startsWith(r))
      )
    messageExpression: |
      "镜像必须来自允许的仓库: " + variables.allowedRegistries.join(", ")
    reason: Invalid
  auditAnnotations:
  - key: "policy-checked-images"
    valueExpression: "variables.containers.map(c, c.image).join(', ')"
---
# 参数ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: image-registry-params
  namespace: default
data:
  allowedRegistries: "registry.example.com,gcr.io/my-project,docker.io/myorg"
---
# 绑定到参数
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: image-registry-binding
spec:
  policyName: image-registry-policy
  paramRef:
    name: image-registry-params
    namespace: default
  validationActions:
  - Deny
---
# 复杂策略: Pod安全检查
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: pod-security-baseline
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  matchConditions:
  - name: exclude-system-pods
    expression: "!request.namespace.startsWith('kube-')"
  variables:
  - name: allContainers
    expression: |
      object.spec.containers + 
      object.spec.?initContainers.orValue([]) + 
      object.spec.?ephemeralContainers.orValue([])
  validations:
  # 禁止特权容器
  - expression: |
      !variables.allContainers.exists(c, 
        c.?securityContext.?privileged.orValue(false) == true
      )
    message: "不允许特权容器"
    reason: Forbidden
  # 禁止hostPID
  - expression: "!object.spec.?hostPID.orValue(false)"
    message: "不允许使用hostPID"
    reason: Forbidden
  # 禁止hostNetwork
  - expression: "!object.spec.?hostNetwork.orValue(false)"
    message: "不允许使用hostNetwork"
    reason: Forbidden
  # 必须有资源限制
  - expression: |
      variables.allContainers.all(c,
        has(c.resources) && has(c.resources.limits) && 
        has(c.resources.limits.memory) && has(c.resources.limits.cpu)
      )
    message: "所有容器必须设置CPU和内存限制"
    reason: Invalid
  # 必须以非root运行
  - expression: |
      variables.allContainers.all(c,
        c.?securityContext.?runAsNonRoot.orValue(
          object.spec.?securityContext.?runAsNonRoot.orValue(false)
        ) == true
      )
    message: "容器必须以非root用户运行"
    reason: Forbidden
```

## 常用CEL表达式

| 场景 | 表达式 | 说明 |
|-----|-------|------|
| 必须有标签 | `has(object.metadata.labels.app)` | 检查app标签存在 |
| 标签值验证 | `object.metadata.labels.env in ['prod', 'staging', 'dev']` | 枚举值检查 |
| 镜像前缀 | `object.spec.containers.all(c, c.image.startsWith('registry.example.com/'))` | 镜像仓库限制 |
| 镜像Tag | `object.spec.containers.all(c, !c.image.endsWith(':latest'))` | 禁止latest |
| 镜像Digest | `object.spec.containers.all(c, c.image.contains('@sha256:'))` | 强制digest |
| 资源限制 | `object.spec.containers.all(c, has(c.resources.limits))` | 必须有limits |
| CPU限制 | `object.spec.containers.all(c, int(c.resources.limits.cpu.replace('m','')) <= 4000)` | CPU上限 |
| 内存限制 | `object.spec.containers.all(c, c.resources.limits.memory.endsWith('Gi'))` | 内存单位 |
| 禁止特权 | `!object.spec.containers.exists(c, c.securityContext.privileged == true)` | 安全检查 |
| 副本限制 | `object.spec.replicas <= 50` | 副本数上限 |
| 非空注解 | `object.metadata.?annotations['owner'].orValue('') != ''` | 必须有owner |
| 正则匹配 | `object.metadata.name.matches('^[a-z][a-z0-9-]*$')` | 命名规范 |
| 数组长度 | `size(object.spec.containers) <= 5` | 容器数限制 |
| 条件组合 | `has(object.metadata.labels.app) && has(object.metadata.labels.version)` | 多标签检查 |

## CEL高级表达式

```yaml
# 复杂条件示例
validations:
# 1. 检查annotation格式
- expression: |
    object.metadata.?annotations.all(k, v,
      k.startsWith('example.com/') ? v.matches('^[a-zA-Z0-9-]+$') : true
    )
  message: "example.com/前缀的annotation值必须是字母数字"

# 2. 检查环境变量不包含敏感词
- expression: |
    object.spec.containers.all(c,
      !c.?env.orValue([]).exists(e, 
        e.name.contains('PASSWORD') && has(e.value)
      )
    )
  message: "密码类环境变量应使用Secret引用"

# 3. 检查PVC大小
- expression: |
    int(object.spec.resources.requests.storage.replace('Gi','')) <= 100
  message: "PVC大小不能超过100Gi"

# 4. 检查节点亲和性
- expression: |
    has(object.spec.affinity) && 
    has(object.spec.affinity.nodeAffinity)
  message: "必须配置节点亲和性"

# 5. 更新时不允许修改immutable字段
- expression: |
    request.operation != 'UPDATE' || 
    object.spec.selector == oldObject.spec.selector
  message: "不允许修改selector"
```

## ACK准入控制增强

| 功能 | 说明 | 配置方式 | 使用场景 |
|-----|------|---------|---------|
| **Gatekeeper** | OPA策略引擎 | Helm/组件管理 | 复杂策略 |
| **ACK策略管理** | 内置安全策略 | 控制台 | 快速启用 |
| **镜像签名验证** | cosign/notation集成 | Webhook | 供应链安全 |
| **镜像扫描准入** | Trivy/ACR集成 | Webhook | 漏洞阻断 |
| **PodSecurity** | 原生Pod安全 | 命名空间标签 | 基础安全 |

```yaml
# ACK Gatekeeper ConstraintTemplate示例
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8srequiredlabels
      
      violation[{"msg": msg}] {
        provided := {label | input.review.object.metadata.labels[label]}
        required := {label | label := input.parameters.labels[_]}
        missing := required - provided
        count(missing) > 0
        msg := sprintf("缺少必需标签: %v", [missing])
      }
---
# Constraint实例
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-team-label
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
    - apiGroups: ["apps"]
      kinds: ["Deployment", "StatefulSet"]
    namespaceSelector:
      matchExpressions:
      - key: gatekeeper.sh/excluded
        operator: DoesNotExist
  parameters:
    labels:
    - "team"
    - "app"
```

## 准入控制故障排查

```bash
# 检查Webhook配置
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations

# 查看Webhook详情
kubectl get validatingwebhookconfiguration <name> -o yaml

# 检查Webhook服务是否可达
kubectl get endpoints -n webhook-system webhook-service

# 测试Webhook连接
kubectl run test-webhook --image=curlimages/curl --rm -it --restart=Never -- \
  curl -k https://webhook-service.webhook-system.svc:443/healthz

# 查看API Server审计日志中的准入决策
kubectl logs -n kube-system kube-apiserver-<node> | grep -i admission

# 检查ValidatingAdmissionPolicy
kubectl get validatingadmissionpolicies
kubectl get validatingadmissionpolicybindings

# 模拟验证(dry-run)
kubectl apply --dry-run=server -f pod.yaml

# 查看策略匹配情况
kubectl get validatingadmissionpolicy <policy> -o yaml | grep -A 20 status
```

## 准入控制性能优化

| 优化项 | 建议 | 影响 |
|-------|-----|------|
| **Webhook超时** | 设置5-10秒 | 避免API延迟 |
| **failurePolicy** | 非关键用Ignore | 提高可用性 |
| **namespaceSelector** | 精确匹配 | 减少调用 |
| **matchConditions** | 使用CEL过滤 | 减少网络调用 |
| **Webhook副本** | >=2副本 | 高可用 |
| **ValidatingAdmissionPolicy** | 优先使用 | 无网络开销 |

## Prometheus监控指标

```yaml
# 准入控制相关指标
apiserver_admission_controller_admission_duration_seconds  # 控制器耗时
apiserver_admission_webhook_admission_duration_seconds     # Webhook耗时
apiserver_admission_webhook_rejection_count                # Webhook拒绝数
apiserver_admission_step_admission_duration_seconds        # 准入步骤耗时

# PrometheusRule
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: admission-alerts
spec:
  groups:
  - name: admission
    rules:
    - alert: WebhookHighLatency
      expr: |
        histogram_quantile(0.99, 
          sum(rate(apiserver_admission_webhook_admission_duration_seconds_bucket[5m])) by (le, name)
        ) > 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Webhook {{ $labels.name }} P99延迟超过1秒"
        
    - alert: WebhookHighRejectionRate
      expr: |
        sum(rate(apiserver_admission_webhook_rejection_count[5m])) by (name) > 10
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Webhook {{ $labels.name }} 拒绝率过高"
        
    - alert: AdmissionControllerError
      expr: |
        sum(rate(apiserver_admission_controller_admission_duration_seconds_count{rejected="true"}[5m])) > 0
      for: 1m
      labels:
        severity: info
      annotations:
        summary: "准入控制器拒绝请求"
```

## 版本变更记录

| 版本 | 变更内容 | 影响 |
|------|---------|------|
| v1.25 | PodSecurity GA, PSP完全移除 | 必须迁移到PodSecurity |
| v1.26 | ValidatingAdmissionPolicy Alpha | 新的原生策略方式 |
| v1.27 | matchConditions添加到Webhook | 减少不必要的Webhook调用 |
| v1.28 | ValidatingAdmissionPolicy Beta, 支持变量 | 更强大的CEL表达式 |
| v1.29 | ValidatingAdmissionPolicy支持消息表达式 | 动态错误消息 |
| v1.30 | ValidatingAdmissionPolicy GA | 生产可用 |
| v1.31 | MutatingAdmissionPolicy Alpha | 原生变更策略 |
| v1.32 | MutatingAdmissionPolicy Beta | 更完善的变更支持 |

---

**准入控制原则**: 使用ValidatingAdmissionPolicy优先 + Webhook作为补充 + 合理设置failurePolicy + 监控Webhook延迟
