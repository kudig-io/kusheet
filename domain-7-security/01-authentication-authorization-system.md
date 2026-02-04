# 01 - Kubernetes认证授权体系详解

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-02 | **参考**: [kubernetes.io/docs/reference/access-authn-authz](https://kubernetes.io/docs/reference/access-authn-authz/)

## 认证授权架构全景

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        Kubernetes 认证授权体系架构                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌────────────────────────────────────────────────────────────────────────────────┐ │
│  │                             Authentication (认证)                              │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │ │
│  │  │ X.509证书    │  │ Bearer Token │  │  Bootstrap   │  │ ServiceAccount│       │ │
│  │  │ Client Cert  │  │     JWT      │  │    Token     │  │    Token      │       │ │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │ │
│  │         │                 │                 │                 │                │ │
│  │         └─────────────────┼─────────────────┼─────────────────┘                │ │
│  │                           │                 │                                  │ │
│  │                    ┌──────▼──────┐    ┌────▼────┐                             │ │
│  │                    │   Webhook   │    │  OIDC   │                             │ │
│  │                    │  Token Auth │    │ Connect │                             │ │
│  │                    └─────────────┘    └─────────┘                             │ │
│  └────────────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                                │
│  ┌─────────────────────────────────▼──────────────────────────────────────────────┐ │
│  │                             Authorization (授权)                               │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │ │
│  │  │     RBAC     │  │     ABAC     │  │     Node     │  │   Webhook    │       │ │
│  │  │ (推荐方案)   │  │ (已弃用)     │  │ (节点授权)   │  │ (外部授权)   │       │ │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │ │
│  │         │                 │                 │                 │                │ │
│  │         └─────────────────┼─────────────────┼─────────────────┘                │ │
│  │                           │                 │                                  │ │
│  │                    ┌──────▼─────────────────▼──────┐                          │ │
│  │                    │    AlwaysAllow / AlwaysDeny   │                          │ │
│  │                    └───────────────────────────────┘                          │ │
│  └────────────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                                │
│  ┌─────────────────────────────────▼──────────────────────────────────────────────┐ │
│  │                          Admission Control (准入控制)                          │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐   │ │
│  │  │                    Validating Admission Webhooks                        │   │ │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐         │   │ │
│  │  │  │  Pod安全   │  │   镜像策略  │  │   网络策略  │  │   资源配额  │         │   │ │
│  │  │  │  准入控制  │  │   验证      │  │   验证      │  │   验证      │         │   │ │
│  │  │  └────────────┘  └────────────┘  └────────────┘  └────────────┘         │   │ │
│  │  └─────────────────────────────────────────────────────────────────────────┘   │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐   │ │
│  │  │                    Mutating Admission Webhooks                          │   │ │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐         │   │ │
│  │  │  │   注入      │  │   默认值    │  │   标签      │  │   资源      │         │   │ │
│  │  │  │  Sidecar   │  │   设置      │  │   添加      │  │   限制      │         │   │ │
│  │  │  └────────────┘  └────────────┘  └────────────┘  └────────────┘         │   │ │
│  │  └─────────────────────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 认证机制详解

### X.509客户端证书认证

| 配置项 | 说明 | 生产建议 | 安全等级 |
|-------|------|---------|---------|
| **客户端证书** | 用户身份凭证 | 有效期1年，定期轮换 | 高 |
| **CA证书** | 签发机构证书 | 离线存储，严格保护 | 极高 |
| **证书字段** | CN作为用户名，O作为组 | 标准化命名规范 | 中 |
| **证书吊销** | CRL/OCSP检查 | 启用实时检查 | 高 |

```yaml
# API Server认证配置
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
spec:
  containers:
  - name: kube-apiserver
    command:
    - kube-apiserver
    # 客户端证书认证
    - --client-ca-file=/etc/kubernetes/pki/ca.crt
    - --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
    # 证书有效期检查
    - --authentication-token-webhook-cache-ttl=2m0s
    # 匿名认证禁用
    - --anonymous-auth=false
```

### ServiceAccount Token认证

| Token类型 | 版本 | 特点 | 使用场景 |
|----------|------|------|---------|
| **Legacy Token** | v1.24前 | Secret中存储 | 传统应用 |
| **Bound Token** | v1.24+ | JWT格式，有时效性 | 现代应用 |
| **Projected Token** | v1.20+ | 可配置audience | 多集群场景 |

```yaml
# ServiceAccount配置
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: production
automountServiceAccountToken: false  # 安全最佳实践

---
# Pod使用特定Token
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  serviceAccountName: app-sa
  containers:
  - name: app
    image: myapp:v1.0
    volumeMounts:
    - name: projected-token
      mountPath: /var/run/secrets/tokens
  volumes:
  - name: projected-token
    projected:
      sources:
      - serviceAccountToken:
          path: token
          expirationSeconds: 3600  # 1小时过期
          audience: api-server
```

### OIDC认证集成

```yaml
# API Server OIDC配置
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
spec:
  containers:
  - name: kube-apiserver
    command:
    - kube-apiserver
    # OIDC配置
    - --oidc-issuer-url=https://accounts.google.com
    - --oidc-client-id=kubernetes-cluster
    - --oidc-username-claim=email
    - --oidc-groups-claim=groups
    - --oidc-username-prefix=oidc:
    - --oidc-groups-prefix=oidc:
    # 令牌验证
    - --oidc-ca-file=/etc/kubernetes/oidc-ca.crt
    - --oidc-required-claim=hd=example.com
```

## 授权机制详解

### RBAC权限模型

| 组件 | 作用域 | 说明 |
|-----|-------|------|
| **Role** | 命名空间 | 定义命名空间内权限 |
| **ClusterRole** | 集群 | 定义集群级权限 |
| **RoleBinding** | 命名空间 | 将Role绑定给用户/组/SA |
| **ClusterRoleBinding** | 集群 | 将ClusterRole绑定给用户/组/SA |

```yaml
# 自定义ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
  resourceNames: ["debug-pod"]  # 限制具体Pod

---
# RoleBinding示例
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-access
  namespace: production
subjects:
- kind: User
  name: alice@example.com
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### 权限继承与聚合

```yaml
# 聚合ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-viewer
  labels:
    rbac.authorization.k8s.io/aggregate-to-view: "true"
rules:
- apiGroups: ["monitoring.coreos.com"]
  resources: ["prometheuses", "alertmanagers"]
  verbs: ["get", "list", "watch"]

---
# 基于聚合的Role
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: view
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.authorization.k8s.io/aggregate-to-view: "true"
rules: []  # 规则由聚合自动填充
```

## 准入控制机制

### 准入控制器类型

| 控制器 | 类型 | 作用 | 版本要求 |
|-------|------|------|---------|
| **NodeRestriction** | 内置 | 限制节点自我修改 | 稳定 |
| **PodSecurity** | 内置 | 替代PSP | v1.25+ GA |
| **ResourceQuota** | 内置 | 资源配额限制 | 稳定 |
| **LimitRanger** | 内置 | 默认资源配置 | 稳定 |
| **ValidatingWebhook** | 外部 | 自定义验证逻辑 | 稳定 |
| **MutatingWebhook** | 外部 | 自定义变更逻辑 | 稳定 |

```yaml
# ValidatingWebhook配置
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: pod-validate-webhook
webhooks:
- name: validate-pod.example.com
  clientConfig:
    service:
      namespace: webhook-system
      name: pod-validator
      path: "/validate"
    caBundle: <CA_BUNDLE>
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  admissionReviewVersions: ["v1", "v1beta1"]
  sideEffects: None
  timeoutSeconds: 5
```

## 安全最佳实践

### 认证安全

| 实践 | 说明 | 优先级 | 实施方法 |
|-----|------|-------|---------|
| **多因素认证** | 结合证书+OTP | P0 | 集成OIDC+MFA |
| **证书轮换** | 定期更新客户端证书 | P0 | 自动化脚本 |
| **Token时效性** | 设置合理过期时间 | P1 | Bound Token |
| **审计认证失败** | 记录认证失败事件 | P1 | 启用审计日志 |

### 授权安全

| 实践 | 说明 | 优先级 | 实施方法 |
|-----|------|-------|---------|
| **最小权限原则** | 仅授予必需权限 | P0 | Role而非ClusterRole |
| **避免cluster-admin** | 限制超级管理员使用 | P0 | 定期审计 |
| **组管理权限** | 通过组管理用户权限 | P1 | OIDC组映射 |
| **定期权限审查** | 清理过期权限 | P1 | 自动化脚本 |

### 准入控制安全

| 实践 | 说明 | 优先级 | 实施方法 |
|-----|------|-------|---------|
| **启用Pod安全标准** | PSA替代PSP | P0 | NS标签配置 |
| **镜像策略验证** | 签名/扫描验证 | P0 | OPA/Kyverno |
| **网络策略默认拒绝** | 零信任网络 | P1 | NetworkPolicy |
| **资源限制强制** | 防止资源耗尽 | P1 | LimitRange |

## 故障排查指南

### 认证问题排查

```bash
# 1. 检查当前用户身份
kubectl auth whoami

# 2. 验证证书有效性
openssl x509 -in ~/.kube/client.crt -noout -text | grep -E "(Subject|Validity)"

# 3. 检查API Server认证配置
kubectl get pod -n kube-system -l component=kube-apiserver -o yaml | grep -A5 authentication

# 4. 测试Token有效性
TOKEN=$(kubectl get secret $(kubectl get serviceaccount default -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d)
curl -k -H "Authorization: Bearer $TOKEN" https://<api-server>:6443/api/v1/namespaces
```

### 授权问题排查

```bash
# 1. 检查具体权限
kubectl auth can-i create pods --namespace production
kubectl auth can-i '*' '*' --as system:serviceaccount:production:app-sa

# 2. 查看用户所有权限
kubectl auth can-i --list --as alice@example.com

# 3. 审计权限绑定
kubectl get rolebindings,clusterrolebindings -A -o wide

# 4. 查找cluster-admin绑定
kubectl get clusterrolebindings -o json | jq '.items[] | select(.roleRef.name=="cluster-admin")'
```

### 准入控制排查

```bash
# 1. 检查准入控制器状态
kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations

# 2. 查看Webhook调用日志
kubectl logs -n webhook-system deployment/webhook-server

# 3. 临时禁用Webhook进行测试
kubectl delete validatingwebhookconfiguration <webhook-name>
```

## 监控与告警

```yaml
# Prometheus告警规则
groups:
- name: authentication
  rules:
  - alert: HighAuthenticationFailures
    expr: |
      sum(rate(apiserver_request_total{code="401"}[5m])) > 10
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "认证失败次数异常增高"
      
  - alert: ClusterAdminUsage
    expr: |
      sum(rate(apiserver_audit_event_total{user_username!="system:*",user_groups=~".*cluster-admin.*"}[5m])) > 0
    for: 1m
    labels:
      severity: info
    annotations:
      summary: "cluster-admin权限被使用"
```

---
**认证授权原则**: 多因素认证 + 最小权限 + 准入控制 + 持续审计
---
**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)