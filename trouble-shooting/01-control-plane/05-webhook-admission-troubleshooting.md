# Webhook 与准入控制故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 高级
>
> **版本说明**:
> - ValidatingAdmissionPolicy (v1.30+ GA) 可替代部分 Webhook 场景
> - v1.28+ 支持 matchConditions 字段优化 Webhook 匹配
> - v1.27+ 支持 Webhook 的 matchPolicy: Equivalent

## 概述

Kubernetes 准入控制器 (Admission Controllers) 是 API 请求处理流程中的关键环节，包括内置控制器和可扩展的 Webhook。Webhook 分为 MutatingAdmissionWebhook (修改资源) 和 ValidatingAdmissionWebhook (验证资源)。本文档覆盖准入控制相关故障的诊断与解决方案。

---

## 第一部分：问题现象与影响分析

### 1.1 准入控制流程

```
                         API 请求流程
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Authentication                             │
│                        (身份认证)                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Authorization                              │
│                        (权限授权)                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Mutating Admission Webhooks                     │
│              (修改型准入 Webhook, 按顺序执行)                     │
│                                                                  │
│  例如: Istio Sidecar 注入, 添加默认资源限制                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Object Schema Validation                    │
│                       (对象模式验证)                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Validating Admission Webhooks                    │
│              (验证型准入 Webhook, 并行执行)                       │
│                                                                  │
│  例如: OPA/Gatekeeper 策略验证, 安全策略检查                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Persist to etcd                          │
│                        (持久化到 etcd)                           │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 错误信息示例 | 查看方式 |
|---------|---------|-------------|---------|
| Webhook 超时 | 资源创建/更新缓慢或失败 | `timeout: request did not complete within requested timeout` | `kubectl describe` |
| Webhook 拒绝 | 资源创建/更新被拒绝 | `admission webhook "xxx" denied the request` | `kubectl apply` 输出 |
| Webhook 不可达 | TLS 握手失败或连接失败 | `failed calling webhook: connection refused` | API Server 日志 |
| 证书问题 | TLS 验证失败 | `x509: certificate signed by unknown authority` | API Server 日志 |
| 配置错误 | Webhook 未生效或错误触发 | 资源未被修改/验证 | 检查资源和配置 |
| 资源占用 | Webhook 服务性能问题 | 高延迟，CPU/内存占用高 | `kubectl top` |
| 循环依赖 | Webhook 自身资源被拦截 | Webhook Pod 无法创建 | 系统命名空间检查 |

### 1.3 影响分析

| 故障类型 | 直接影响 | 间接影响 | 影响范围 |
|---------|---------|---------|---------|
| Webhook 不可达 | 资源创建/更新失败 | 部署流程阻塞 | 受影响的资源类型和命名空间 |
| Webhook 超时 | API 响应缓慢 | 用户体验下降，CI/CD 超时 | 整个集群 API 操作 |
| Webhook 拒绝 | 合法资源被误拦截 | 业务无法正常部署 | 匹配 Webhook 规则的资源 |
| 证书过期 | Webhook 全部失效 | 所有相关准入检查失败 | 对应 Webhook 的所有请求 |
| 系统 Webhook 故障 | 集群核心功能受损 | 如 Pod 无法注入 Sidecar | 依赖该功能的所有服务 |

---

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
Webhook/准入控制故障
        │
        ├─── 资源被拒绝？
        │         │
        │         ├─ 查看拒绝原因 ──→ 检查 Webhook 日志/策略
        │         ├─ 确认是否应该被拒绝 ──→ 调整资源或策略
        │         └─ Webhook 配置错误 ──→ 修正 matchLabels/rules
        │
        ├─── 连接/超时问题？
        │         │
        │         ├─ Webhook 服务是否运行 ──→ 检查 Deployment/Pod
        │         ├─ Service 是否可达 ──→ 检查 Endpoints
        │         ├─ TLS 证书是否有效 ──→ 检查证书配置
        │         └─ 超时设置是否合理 ──→ 调整 timeoutSeconds
        │
        ├─── Webhook 未生效？
        │         │
        │         ├─ 检查 failurePolicy ──→ Ignore vs Fail
        │         ├─ 检查 matchPolicy ──→ Exact vs Equivalent
        │         ├─ 检查 namespaceSelector ──→ 确认匹配
        │         └─ 检查 objectSelector ──→ 确认匹配
        │
        └─── 系统影响？
                  │
                  ├─ 检查系统命名空间排除 ──→ 添加 kube-system 排除
                  └─ 检查循环依赖 ──→ 使用 reinvocationPolicy
```

### 2.2 排查命令集

#### 2.2.1 查看 Webhook 配置

```bash
# 列出所有 MutatingWebhookConfiguration
kubectl get mutatingwebhookconfigurations

# 列出所有 ValidatingWebhookConfiguration
kubectl get validatingwebhookconfigurations

# 查看特定 Webhook 详情
kubectl get mutatingwebhookconfigurations <name> -o yaml
kubectl get validatingwebhookconfigurations <name> -o yaml

# 查看 Webhook 详细描述
kubectl describe mutatingwebhookconfigurations <name>
kubectl describe validatingwebhookconfigurations <name>
```

#### 2.2.2 检查 Webhook 服务状态

```bash
# 查看 Webhook 服务
kubectl get svc -n <webhook-namespace>

# 查看 Endpoints
kubectl get endpoints -n <webhook-namespace> <service-name>

# 查看 Webhook Pod 状态
kubectl get pods -n <webhook-namespace> -l <selector>

# 查看 Webhook Pod 日志
kubectl logs -n <webhook-namespace> <pod-name>

# 检查 Webhook 服务端口
kubectl get svc -n <webhook-namespace> <service-name> -o jsonpath='{.spec.ports}'
```

#### 2.2.3 证书检查

```bash
# 查看 Webhook 使用的 CA Bundle
kubectl get mutatingwebhookconfigurations <name> -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | base64 -d | openssl x509 -noout -text

# 查看 Webhook 服务证书
kubectl get secret -n <namespace> <secret-name> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text

# 检查证书过期时间
kubectl get secret -n <namespace> <secret-name> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -enddate
```

#### 2.2.4 API Server 审计日志

```bash
# 查看 API Server 日志中的 Webhook 调用
kubectl logs -n kube-system kube-apiserver-<node> | grep -i webhook

# 查看准入控制相关错误
kubectl logs -n kube-system kube-apiserver-<node> | grep -i admission

# 查看特定 Webhook 的调用记录
kubectl logs -n kube-system kube-apiserver-<node> | grep <webhook-name>
```

#### 2.2.5 测试 Webhook 连接

```bash
# 从集群内部测试 Webhook 服务连接
kubectl run curl-test --rm -it --image=curlimages/curl --restart=Never -- \
  curl -k https://<webhook-service>.<namespace>.svc:<port>/validate

# 检查网络策略是否阻止
kubectl get networkpolicy -n <webhook-namespace>

# 检查 Service 到 Pod 的连通性
kubectl exec -n <namespace> <pod> -- nc -zv <webhook-service> <port>
```

### 2.3 排查注意事项

| 注意事项 | 说明 |
|---------|-----|
| 系统命名空间 | 确保 kube-system 等系统命名空间被排除，避免影响核心组件 |
| failurePolicy | `Fail` 会在 Webhook 不可用时拒绝请求；`Ignore` 会跳过 |
| 超时设置 | 默认 10 秒，过短可能导致复杂验证超时 |
| 证书管理 | 推荐使用 cert-manager 自动管理 Webhook 证书 |
| 顺序执行 | MutatingWebhook 按顺序执行，注意依赖关系 |
| 并行执行 | ValidatingWebhook 并行执行，任一拒绝即失败 |

---

## 第三部分：解决方案与风险控制

### 3.1 Webhook 连接失败

#### 场景 1：Webhook 服务不可达

**问题现象：**
```
Error from server (InternalError): error when creating "pod.yaml": 
Internal error occurred: failed calling webhook "validate.example.com": 
Post "https://webhook-service.default.svc:443/validate": dial tcp 10.96.x.x:443: connect: connection refused
```

**解决步骤：**

```bash
# 1. 检查 Webhook 服务和 Pod 状态
kubectl get svc,pods -n <webhook-namespace> -l <app-label>

# 2. 检查 Endpoints
kubectl get endpoints -n <webhook-namespace> <service-name>
# 如果 Endpoints 为空，说明 Pod 未就绪或 selector 不匹配

# 3. 检查 Pod 日志
kubectl logs -n <webhook-namespace> <pod-name>

# 4. 修复 Pod/Deployment 问题后验证
kubectl get endpoints <service-name> -n <webhook-namespace>

# 5. 如果紧急需要跳过 Webhook，设置 failurePolicy 为 Ignore
kubectl patch mutatingwebhookconfiguration <name> --type='json' -p='[{"op": "replace", "path": "/webhooks/0/failurePolicy", "value": "Ignore"}]'

# 6. 或者直接删除 Webhook 配置 (谨慎!)
kubectl delete mutatingwebhookconfiguration <name>
```

**风险提示：**
- 设置 `failurePolicy: Ignore` 会跳过 Webhook 验证，可能导致不合规资源被创建
- 删除 Webhook 配置会完全禁用该 Webhook 的功能

#### 场景 2：TLS 证书问题

**问题现象：**
```
failed calling webhook: x509: certificate signed by unknown authority
```

**解决步骤：**

```bash
# 1. 检查 Webhook 配置中的 CA Bundle
kubectl get mutatingwebhookconfiguration <name> -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | base64 -d | openssl x509 -noout -issuer

# 2. 检查 Webhook 服务实际使用的证书
kubectl get secret -n <namespace> <tls-secret> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -issuer

# 3. 确保 CA Bundle 与签发证书的 CA 一致

# 4. 如果使用 cert-manager，检查 Certificate 资源
kubectl get certificate -n <namespace>
kubectl describe certificate -n <namespace> <cert-name>

# 5. 更新 Webhook 的 CA Bundle
# 获取正确的 CA
CA_BUNDLE=$(kubectl get secret -n <namespace> <ca-secret> -o jsonpath='{.data.ca\.crt}')

# 更新 Webhook 配置
kubectl patch mutatingwebhookconfiguration <name> --type='json' -p="[{\"op\": \"replace\", \"path\": \"/webhooks/0/clientConfig/caBundle\", \"value\": \"${CA_BUNDLE}\"}]"
```

#### 场景 3：证书过期

**解决步骤：**

```bash
# 1. 检查证书过期时间
kubectl get secret -n <namespace> <tls-secret> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -enddate

# 2. 如果使用 cert-manager，触发证书更新
kubectl delete certificate -n <namespace> <cert-name>
# cert-manager 会自动重新签发

# 3. 手动更新证书
# 生成新证书
openssl req -x509 -newkey rsa:2048 -keyout tls.key -out tls.crt -days 365 -nodes \
  -subj "/CN=<service>.<namespace>.svc" \
  -addext "subjectAltName=DNS:<service>.<namespace>.svc,DNS:<service>.<namespace>.svc.cluster.local"

# 更新 Secret
kubectl create secret tls <secret-name> -n <namespace> --cert=tls.crt --key=tls.key --dry-run=client -o yaml | kubectl apply -f -

# 4. 更新 Webhook CA Bundle (如果是自签名证书)
CA_BUNDLE=$(cat tls.crt | base64 | tr -d '\n')
kubectl patch mutatingwebhookconfiguration <name> --type='json' -p="[{\"op\": \"replace\", \"path\": \"/webhooks/0/clientConfig/caBundle\", \"value\": \"${CA_BUNDLE}\"}]"

# 5. 重启 Webhook Pod
kubectl rollout restart deployment -n <namespace> <webhook-deployment>
```

---

### 3.2 Webhook 超时问题

#### 场景 1：调整超时设置

**问题现象：**
```
timeout: request did not complete within requested timeout 10s
```

**解决步骤：**

```bash
# 1. 查看当前超时设置
kubectl get mutatingwebhookconfiguration <name> -o jsonpath='{.webhooks[0].timeoutSeconds}'

# 2. 增加超时时间 (最大 30 秒)
kubectl patch mutatingwebhookconfiguration <name> --type='json' -p='[{"op": "replace", "path": "/webhooks/0/timeoutSeconds", "value": 30}]'

# 3. 检查 Webhook 服务性能
kubectl top pods -n <webhook-namespace>

# 4. 查看 Webhook 日志分析延迟原因
kubectl logs -n <webhook-namespace> <pod-name> --tail=100

# 5. 优化 Webhook 服务
# - 增加副本数
kubectl scale deployment -n <namespace> <webhook-deployment> --replicas=3

# - 增加资源限制
kubectl patch deployment -n <namespace> <webhook-deployment> --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value": "500m"}]'
```

---

### 3.3 Webhook 配置问题

#### 场景 1：Webhook 未生效

**问题现象：**
资源创建成功，但未被 Webhook 修改或验证

**解决步骤：**

```bash
# 1. 检查 Webhook 规则配置
kubectl get mutatingwebhookconfiguration <name> -o yaml

# 2. 验证 rules 是否匹配目标资源
# 检查 apiGroups, apiVersions, resources, operations

# 3. 检查 namespaceSelector
kubectl get mutatingwebhookconfiguration <name> -o jsonpath='{.webhooks[0].namespaceSelector}'

# 4. 检查 objectSelector
kubectl get mutatingwebhookconfiguration <name> -o jsonpath='{.webhooks[0].objectSelector}'

# 5. 验证目标 namespace 是否有匹配标签
kubectl get ns <namespace> --show-labels

# 6. 修正 Webhook 规则
kubectl patch mutatingwebhookconfiguration <name> --type='json' -p='[
  {"op": "replace", "path": "/webhooks/0/rules", "value": [
    {
      "apiGroups": [""],
      "apiVersions": ["v1"],
      "operations": ["CREATE", "UPDATE"],
      "resources": ["pods"],
      "scope": "Namespaced"
    }
  ]}
]'
```

#### 场景 2：排除系统命名空间

**问题现象：**
Webhook 影响了 kube-system 等系统命名空间，导致系统组件无法工作

**解决步骤：**

```bash
# 1. 为系统命名空间添加排除标签
kubectl label namespace kube-system webhook.example.com/exclude=true
kubectl label namespace kube-node-lease webhook.example.com/exclude=true

# 2. 更新 Webhook 的 namespaceSelector
kubectl patch mutatingwebhookconfiguration <name> --type='json' -p='[
  {"op": "replace", "path": "/webhooks/0/namespaceSelector", "value": {
    "matchExpressions": [
      {
        "key": "webhook.example.com/exclude",
        "operator": "NotIn",
        "values": ["true"]
      },
      {
        "key": "kubernetes.io/metadata.name",
        "operator": "NotIn",
        "values": ["kube-system", "kube-public", "kube-node-lease"]
      }
    ]
  }}
]'

# 3. 或者使用 Kubernetes 1.22+ 的内置标签
kubectl patch mutatingwebhookconfiguration <name> --type='json' -p='[
  {"op": "replace", "path": "/webhooks/0/namespaceSelector", "value": {
    "matchExpressions": [
      {
        "key": "kubernetes.io/metadata.name",
        "operator": "NotIn",
        "values": ["kube-system", "kube-public", "kube-node-lease"]
      }
    ]
  }}
]'
```

---

### 3.4 常见 Webhook 故障排查

#### 场景 1：Istio Sidecar 注入失败

**问题现象：**
Pod 创建后没有 istio-proxy sidecar 容器

**解决步骤：**

```bash
# 1. 检查 Istio Webhook 状态
kubectl get mutatingwebhookconfiguration istio-sidecar-injector -o yaml

# 2. 检查 istiod 服务状态
kubectl get pods -n istio-system -l app=istiod

# 3. 检查命名空间是否启用注入
kubectl get ns <namespace> --show-labels | grep istio-injection

# 4. 启用命名空间级别注入
kubectl label namespace <namespace> istio-injection=enabled

# 5. 或使用 Pod 注解启用
# 在 Pod spec 中添加:
# annotations:
#   sidecar.istio.io/inject: "true"

# 6. 检查 Webhook 日志
kubectl logs -n istio-system -l app=istiod | grep -i inject

# 7. 验证注入
kubectl delete pod <pod-name>  # 重建 Pod
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].name}'
```

#### 场景 2：OPA/Gatekeeper 策略拒绝

**问题现象：**
```
admission webhook "validation.gatekeeper.sh" denied the request: 
[denied by require-labels] All resources must have a 'team' label
```

**解决步骤：**

```bash
# 1. 查看 Gatekeeper 约束
kubectl get constraints

# 2. 查看特定约束详情
kubectl describe <constraint-kind> <constraint-name>

# 3. 查看违规详情
kubectl get <constraint-kind> <constraint-name> -o jsonpath='{.status.violations}'

# 4. 方案 A: 修改资源满足约束
kubectl patch <resource> <name> --type='json' -p='[{"op": "add", "path": "/metadata/labels/team", "value": "myteam"}]'

# 5. 方案 B: 添加豁免
kubectl patch <constraint-kind> <constraint-name> --type='json' -p='[
  {"op": "add", "path": "/spec/match/excludedNamespaces/-", "value": "<namespace>"}
]'

# 6. 方案 C: 临时禁用约束 (谨慎!)
kubectl patch <constraint-kind> <constraint-name> --type='json' -p='[
  {"op": "replace", "path": "/spec/enforcementAction", "value": "warn"}
]'
```

#### 场景 3：cert-manager Webhook 故障

**问题现象：**
```
Error from server (InternalError): error when creating "certificate.yaml": 
Internal error occurred: failed calling webhook "webhook.cert-manager.io"
```

**解决步骤：**

```bash
# 1. 检查 cert-manager 组件状态
kubectl get pods -n cert-manager

# 2. 检查 webhook 服务
kubectl get svc -n cert-manager cert-manager-webhook

# 3. 检查 webhook 日志
kubectl logs -n cert-manager -l app.kubernetes.io/component=webhook

# 4. 检查 webhook 证书
kubectl get secret -n cert-manager cert-manager-webhook-ca -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -enddate

# 5. 重启 cert-manager webhook
kubectl rollout restart deployment -n cert-manager cert-manager-webhook

# 6. 如果问题持续，重新安装 cert-manager
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.x.x/cert-manager.yaml
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.x.x/cert-manager.yaml
```

---

### 3.5 紧急故障恢复

#### 场景 1：Webhook 导致集群无法操作

**问题现象：**
所有资源创建/更新都被 Webhook 拦截

**紧急恢复步骤：**

```bash
# 方案 1: 删除问题 Webhook 配置
kubectl delete mutatingwebhookconfiguration <name>
kubectl delete validatingwebhookconfiguration <name>

# 方案 2: 设置 failurePolicy 为 Ignore
kubectl patch mutatingwebhookconfiguration <name> --type='json' -p='[{"op": "replace", "path": "/webhooks/0/failurePolicy", "value": "Ignore"}]'

# 方案 3: 如果 kubectl 也无法使用，直接操作 etcd
# 这是最后手段，非常危险!
ETCDCTL_API=3 etcdctl del /registry/admissionregistration.k8s.io/mutatingwebhookconfigurations/<name> \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 方案 4: 通过 API Server 参数禁用特定准入控制器
# 编辑 /etc/kubernetes/manifests/kube-apiserver.yaml
# 添加: --disable-admission-plugins=MutatingAdmissionWebhook
```

**风险提示：**
- 删除 Webhook 会禁用所有相关的准入检查
- 直接操作 etcd 可能导致数据不一致
- 修改 API Server 参数需要重启，可能导致短暂不可用

---

### 3.6 完整的 Webhook 配置示例

```yaml
# MutatingWebhookConfiguration 示例
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: example-mutating-webhook
webhooks:
- name: mutate.example.com
  # 准入规则
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    operations: ["CREATE", "UPDATE"]
    resources: ["pods"]
    scope: "Namespaced"
  
  # 服务配置
  clientConfig:
    service:
      namespace: webhook-system
      name: webhook-service
      port: 443
      path: /mutate
    caBundle: <base64-encoded-ca-cert>
  
  # 行为配置
  failurePolicy: Fail           # Fail 或 Ignore
  matchPolicy: Equivalent       # Exact 或 Equivalent
  sideEffects: None             # None, NoneOnDryRun, 或 Unknown
  timeoutSeconds: 10            # 1-30 秒
  
  # 选择器
  namespaceSelector:
    matchExpressions:
    - key: kubernetes.io/metadata.name
      operator: NotIn
      values: ["kube-system", "kube-public"]
  
  objectSelector:
    matchLabels:
      webhook-enabled: "true"
  
  # 准入审查版本
  admissionReviewVersions: ["v1", "v1beta1"]
  
  # 重新调用策略 (防止 mutating webhook 之间的冲突)
  reinvocationPolicy: IfNeeded  # Never 或 IfNeeded
---
# ValidatingWebhookConfiguration 示例
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: example-validating-webhook
webhooks:
- name: validate.example.com
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    operations: ["CREATE", "UPDATE"]
    resources: ["pods"]
    scope: "Namespaced"
  
  clientConfig:
    service:
      namespace: webhook-system
      name: webhook-service
      port: 443
      path: /validate
    caBundle: <base64-encoded-ca-cert>
  
  failurePolicy: Fail
  matchPolicy: Equivalent
  sideEffects: None
  timeoutSeconds: 10
  
  namespaceSelector:
    matchExpressions:
    - key: environment
      operator: In
      values: ["production", "staging"]
  
  admissionReviewVersions: ["v1", "v1beta1"]
```

---

### 3.7 安全生产风险提示

| 操作 | 风险等级 | 风险说明 | 建议 |
|-----|---------|---------|-----|
| 删除 Webhook 配置 | 高 | 完全禁用相关准入检查 | 仅在紧急情况使用，事后恢复 |
| 设置 failurePolicy: Ignore | 中 | Webhook 故障时跳过检查 | 仅用于临时恢复，尽快修复 |
| 修改系统 Webhook | 高 | 可能影响集群核心功能 | 谨慎操作，先在测试环境验证 |
| 更新 Webhook 证书 | 中 | 配置错误可能导致 Webhook 失效 | 备份原配置，验证证书链 |
| 修改 Webhook 规则 | 中 | 可能导致误拦截或漏检 | 充分测试 rules 和 selector |
| 调整超时时间 | 低 | 可能影响 API 响应性能 | 根据实际 Webhook 性能调整 |

---

## 附录

### 常用排查命令速查

```bash
# 查看 Webhook 配置
kubectl get mutatingwebhookconfigurations
kubectl get validatingwebhookconfigurations
kubectl describe mutatingwebhookconfiguration <name>

# 服务状态检查
kubectl get svc,pods,endpoints -n <webhook-namespace>
kubectl logs -n <webhook-namespace> <pod-name>

# 证书检查
kubectl get secret -n <ns> <secret> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text

# 紧急操作
kubectl delete mutatingwebhookconfiguration <name>
kubectl patch mutatingwebhookconfiguration <name> --type='json' -p='[{"op": "replace", "path": "/webhooks/0/failurePolicy", "value": "Ignore"}]'
```

### 相关文档

- [API Server 故障排查](./01-apiserver-troubleshooting.md)
- [证书故障排查](../06-security-auth/02-certificate-troubleshooting.md)
- [RBAC 故障排查](../06-security-auth/01-rbac-troubleshooting.md)
