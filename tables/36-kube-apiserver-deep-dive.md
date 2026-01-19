# kube-apiserver 深度解析 (kube-apiserver Deep Dive)

> kube-apiserver 是 Kubernetes 控制平面的核心组件，提供 RESTful API 接口，是所有组件通信的唯一入口

---

## 1. 架构概述 (Architecture Overview)

### 1.1 核心功能模块

| 模块 | 英文名 | 职责 | 关键特性 |
|:---|:---|:---|:---|
| **认证模块** | Authentication | 身份验证 | X509证书、Token、OIDC、Webhook |
| **授权模块** | Authorization | 权限控制 | RBAC、ABAC、Node、Webhook |
| **准入控制** | Admission Control | 请求验证/修改 | Validating、Mutating、动态准入 |
| **API聚合** | API Aggregation | API扩展 | 自定义API Server、CRD |
| **存储层** | Storage Layer | 数据持久化 | etcd后端、缓存、Watch |
| **审计日志** | Audit Logging | 操作审计 | 请求记录、合规追踪 |
| **限流机制** | Rate Limiting | 流量控制 | APF(API Priority and Fairness) |

### 1.2 请求处理流程

```
                                   ┌─────────────────────────────────────────────────────┐
                                   │                  kube-apiserver                      │
                                   │                                                      │
┌──────────┐    HTTPS/REST         │  ┌──────────┐   ┌──────────┐   ┌────────────────┐  │
│  Client  │ ─────────────────────▶│  │  认证    │──▶│  授权    │──▶│  准入控制      │  │
│ kubectl  │                       │  │ AuthN    │   │ AuthZ    │   │ Admission      │  │
│ pod/svc  │                       │  └──────────┘   └──────────┘   └───────┬────────┘  │
└──────────┘                       │        │              │                 │           │
                                   │        │              │                 ▼           │
                                   │  ┌─────┴──────────────┴─────────────────────────┐  │
                                   │  │              API Handler (REST)               │  │
                                   │  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ │  │
                                   │  │  │  GET   │ │  POST  │ │  PUT   │ │ DELETE │ │  │
                                   │  │  └────────┘ └────────┘ └────────┘ └────────┘ │  │
                                   │  └─────────────────────────┬─────────────────────┘  │
                                   │                            │                        │
                                   │                            ▼                        │
                                   │  ┌─────────────────────────────────────────────┐   │
                                   │  │           Registry / Storage                 │   │
                                   │  │  ┌─────────────┐    ┌──────────────────┐    │   │
                                   │  │  │   Cacher    │    │   etcd Backend   │    │   │
                                   │  │  │  (Watch)    │    │                  │    │   │
                                   │  │  └─────────────┘    └──────────────────┘    │   │
                                   │  └─────────────────────────────────────────────┘   │
                                   └─────────────────────────────────────────────────────┘
                                                              │
                                                              ▼
                                                        ┌──────────┐
                                                        │   etcd   │
                                                        └──────────┘
```

### 1.3 API 组织结构

| API组 | 路径前缀 | 包含资源 | 说明 |
|:---|:---|:---|:---|
| **Core (Legacy)** | /api/v1 | pods, services, configmaps, secrets, nodes | 核心资源 |
| **apps** | /apis/apps/v1 | deployments, statefulsets, daemonsets, replicasets | 应用工作负载 |
| **batch** | /apis/batch/v1 | jobs, cronjobs | 批处理任务 |
| **networking.k8s.io** | /apis/networking.k8s.io/v1 | ingresses, networkpolicies | 网络资源 |
| **storage.k8s.io** | /apis/storage.k8s.io/v1 | storageclasses, volumeattachments | 存储资源 |
| **rbac.authorization.k8s.io** | /apis/rbac.authorization.k8s.io/v1 | roles, rolebindings, clusterroles | RBAC资源 |
| **autoscaling** | /apis/autoscaling/v2 | hpa | 自动伸缩 |
| **policy** | /apis/policy/v1 | poddisruptionbudgets | 策略资源 |
| **certificates.k8s.io** | /apis/certificates.k8s.io/v1 | certificatesigningrequests | 证书管理 |

---

## 2. 认证机制 (Authentication)

### 2.1 认证方式对比

| 认证方式 | 英文名 | 适用场景 | 优点 | 缺点 |
|:---|:---|:---|:---|:---|
| **X509客户端证书** | Client Certificates | 组件间通信、管理员 | 安全性高、无需额外系统 | 证书管理复杂、轮换困难 |
| **Bearer Token** | Static Token | 简单场景、测试 | 配置简单 | 安全性低、无法动态管理 |
| **Bootstrap Token** | Bootstrap Token | 节点加入集群 | 专为节点引导设计 | 临时性、有效期短 |
| **ServiceAccount Token** | SA Token | Pod内访问API | 自动管理、Namespace隔离 | 绑定到ServiceAccount |
| **OIDC** | OpenID Connect | 企业SSO集成 | 标准协议、集成方便 | 需要OIDC Provider |
| **Webhook Token** | Webhook Authentication | 自定义认证 | 灵活性高 | 增加延迟、需维护Webhook |
| **认证代理** | Authenticating Proxy | 前置认证 | 可集成多种认证系统 | 架构复杂 |

### 2.2 X509 证书认证配置

```bash
# API Server 证书参数
--client-ca-file=/etc/kubernetes/pki/ca.crt           # 客户端CA
--tls-cert-file=/etc/kubernetes/pki/apiserver.crt     # 服务器证书
--tls-private-key-file=/etc/kubernetes/pki/apiserver.key  # 服务器私钥

# 证书中的用户信息映射
# Common Name (CN) -> Username
# Organization (O) -> Groups

# 示例: 创建管理员证书
cat > admin-csr.json << EOF
{
  "CN": "admin",
  "key": { "algo": "rsa", "size": 2048 },
  "names": [{ "O": "system:masters" }]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem \
  -config=ca-config.json -profile=client \
  admin-csr.json | cfssljson -bare admin
```

### 2.3 ServiceAccount Token 配置

```yaml
# ServiceAccount Token 自动挂载
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-service-account
  namespace: default
automountServiceAccountToken: true  # 默认true

---
# Pod 使用特定 ServiceAccount
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  serviceAccountName: my-service-account
  containers:
  - name: app
    image: my-app:latest
    # Token 自动挂载到 /var/run/secrets/kubernetes.io/serviceaccount/
```

```bash
# API Server ServiceAccount 相关参数
--service-account-key-file=/etc/kubernetes/pki/sa.pub      # SA公钥
--service-account-signing-key-file=/etc/kubernetes/pki/sa.key  # SA私钥
--service-account-issuer=https://kubernetes.default.svc    # Token签发者

# Bound ServiceAccount Token (推荐)
--service-account-extend-token-expiration=true
--service-account-max-token-expiration=48h
```

### 2.4 OIDC 配置

```bash
# API Server OIDC 参数
--oidc-issuer-url=https://accounts.google.com  # OIDC Provider URL
--oidc-client-id=kubernetes                     # Client ID
--oidc-username-claim=email                     # 用户名映射字段
--oidc-username-prefix=oidc:                    # 用户名前缀
--oidc-groups-claim=groups                      # 组映射字段
--oidc-groups-prefix=oidc:                      # 组前缀
--oidc-ca-file=/etc/kubernetes/pki/oidc-ca.crt # OIDC Provider CA

# 使用示例 (kubectl)
kubectl config set-credentials oidc-user \
  --auth-provider=oidc \
  --auth-provider-arg=idp-issuer-url=https://accounts.google.com \
  --auth-provider-arg=client-id=kubernetes \
  --auth-provider-arg=refresh-token=<refresh_token> \
  --auth-provider-arg=id-token=<id_token>
```

---

## 3. 授权机制 (Authorization)

### 3.1 授权模式对比

| 模式 | 英文名 | 说明 | 适用场景 |
|:---|:---|:---|:---|
| **AlwaysAllow** | 始终允许 | 跳过授权检查 | 仅开发/测试 |
| **AlwaysDeny** | 始终拒绝 | 拒绝所有请求 | 维护模式 |
| **ABAC** | Attribute-Based | 基于属性的访问控制 | 已弃用 |
| **RBAC** | Role-Based | 基于角色的访问控制 | 生产环境标准 |
| **Node** | 节点授权 | kubelet专用授权 | 节点访问控制 |
| **Webhook** | Webhook授权 | 外部授权服务 | 自定义授权逻辑 |

```bash
# API Server 授权配置
--authorization-mode=Node,RBAC  # 推荐配置
```

### 3.2 RBAC 核心资源

| 资源类型 | 作用域 | 说明 | 示例 |
|:---|:---|:---|:---|
| **Role** | Namespace | 命名空间级别角色 | 开发者角色 |
| **ClusterRole** | Cluster | 集群级别角色 | 管理员角色、聚合角色 |
| **RoleBinding** | Namespace | 绑定Role/ClusterRole到主体 | 绑定用户到角色 |
| **ClusterRoleBinding** | Cluster | 集群级别绑定 | 集群管理员绑定 |

```yaml
# ClusterRole 示例: 只读访问所有资源
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-reader
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/healthz", "/metrics"]
  verbs: ["get"]

---
# Role 示例: 特定Namespace的Deployment管理
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: deployment-manager
rules:
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]

---
# RoleBinding 示例
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-deployment-manager
  namespace: production
subjects:
- kind: User
  name: developer@example.com
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
- kind: ServiceAccount
  name: ci-cd-sa
  namespace: ci-cd
roleRef:
  kind: Role
  name: deployment-manager
  apiGroup: rbac.authorization.k8s.io
```

### 3.3 内置 ClusterRole

| ClusterRole | 说明 | 权限范围 |
|:---|:---|:---|
| `cluster-admin` | 超级管理员 | 所有资源的所有操作 |
| `admin` | 管理员 | 命名空间内大部分资源的管理权限 |
| `edit` | 编辑者 | 读写大部分资源，不含RBAC |
| `view` | 查看者 | 只读访问大部分资源 |
| `system:node` | 节点角色 | kubelet所需权限 |
| `system:kube-scheduler` | 调度器角色 | 调度器所需权限 |
| `system:kube-controller-manager` | 控制器角色 | KCM所需权限 |

---

## 4. 准入控制 (Admission Control)

### 4.1 准入控制器类型

| 类型 | 英文名 | 执行时机 | 功能 |
|:---|:---|:---|:---|
| **变更准入** | Mutating Admission | 授权后、验证前 | 修改请求对象 |
| **验证准入** | Validating Admission | 变更准入后 | 验证请求合法性 |

### 4.2 内置准入控制器

| 控制器名称 | 类型 | 功能 | 默认启用 |
|:---|:---|:---|:---|
| **NamespaceLifecycle** | Validating | 阻止在终止中的NS创建资源 | Yes |
| **LimitRanger** | Mutating | 应用默认资源限制 | Yes |
| **ServiceAccount** | Mutating | 自动挂载SA Token | Yes |
| **DefaultStorageClass** | Mutating | 设置默认StorageClass | Yes |
| **DefaultTolerationSeconds** | Mutating | 设置默认容忍时间 | Yes |
| **MutatingAdmissionWebhook** | Mutating | 调用外部Webhook | Yes |
| **ValidatingAdmissionWebhook** | Validating | 调用外部Webhook | Yes |
| **ResourceQuota** | Validating | 检查资源配额 | Yes |
| **PodSecurity** | Validating | Pod安全标准 (替代PSP) | Yes (1.25+) |
| **NodeRestriction** | Validating | 限制kubelet修改范围 | Yes |
| **PriorityClass** | Validating | 验证PriorityClass | Yes |

```bash
# API Server 准入控制配置
--enable-admission-plugins=NodeRestriction,PodSecurity
--disable-admission-plugins=PodSecurityPolicy  # PSP已弃用
```

### 4.3 动态准入 Webhook

```yaml
# MutatingWebhookConfiguration 示例
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: pod-injector
webhooks:
- name: pod-injector.example.com
  admissionReviewVersions: ["v1", "v1beta1"]
  sideEffects: None
  timeoutSeconds: 5
  failurePolicy: Fail  # Fail/Ignore
  matchPolicy: Equivalent
  reinvocationPolicy: IfNeeded
  clientConfig:
    service:
      name: pod-injector
      namespace: kube-system
      path: "/mutate"
      port: 443
    caBundle: <base64-encoded-ca-cert>
  rules:
  - operations: ["CREATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
    scope: "Namespaced"
  namespaceSelector:
    matchLabels:
      injection: enabled
  objectSelector:
    matchLabels:
      inject: "true"

---
# ValidatingWebhookConfiguration 示例
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: pod-policy
webhooks:
- name: pod-policy.example.com
  admissionReviewVersions: ["v1"]
  sideEffects: None
  timeoutSeconds: 10
  failurePolicy: Fail
  clientConfig:
    service:
      name: pod-policy
      namespace: kube-system
      path: "/validate"
      port: 443
    caBundle: <base64-encoded-ca-cert>
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
```

---

## 5. API Priority and Fairness (APF)

### 5.1 APF 核心概念

| 概念 | 英文名 | 说明 |
|:---|:---|:---|
| **优先级级别** | PriorityLevel | 定义请求队列和并发限制 |
| **流Schema** | FlowSchema | 将请求分类到PriorityLevel |
| **队列** | Queue | 请求等待队列 |
| **座位** | Seat | 并发执行槽位 |

### 5.2 内置 PriorityLevel

| 名称 | 类型 | 并发份额 | 说明 |
|:---|:---|:---|:---|
| `system` | Exempt | - | 系统关键请求，不排队 |
| `leader-election` | Limited | 10 | Leader选举相关 |
| `node-high` | Limited | 40 | 节点高优先级请求 |
| `workload-high` | Limited | 40 | 工作负载高优先级 |
| `workload-low` | Limited | 100 | 普通工作负载请求 |
| `global-default` | Limited | 20 | 默认级别 |
| `exempt` | Exempt | - | 豁免流量控制 |
| `catch-all` | Limited | 5 | 兜底级别 |

### 5.3 APF 配置示例

```yaml
# 自定义 PriorityLevel
apiVersion: flowcontrol.apiserver.k8s.io/v1beta3
kind: PriorityLevelConfiguration
metadata:
  name: custom-high-priority
spec:
  type: Limited
  limited:
    nominalConcurrencyShares: 50
    limitResponse:
      type: Queue
      queuing:
        queues: 64
        handSize: 6
        queueLengthLimit: 50

---
# 自定义 FlowSchema
apiVersion: flowcontrol.apiserver.k8s.io/v1beta3
kind: FlowSchema
metadata:
  name: critical-service-requests
spec:
  priorityLevelConfiguration:
    name: custom-high-priority
  matchingPrecedence: 100
  distinguisherMethod:
    type: ByUser
  rules:
  - subjects:
    - kind: ServiceAccount
      serviceAccount:
        name: critical-app
        namespace: production
    resourceRules:
    - verbs: ["*"]
      apiGroups: ["*"]
      resources: ["*"]
      namespaces: ["production"]
```

---

## 6. 关键配置参数 (Configuration Parameters)

### 6.1 核心参数

| 参数 | 默认值 | 推荐值 | 说明 |
|:---|:---|:---|:---|
| `--bind-address` | 0.0.0.0 | 0.0.0.0 | 监听地址 |
| `--secure-port` | 6443 | 6443 | HTTPS端口 |
| `--advertise-address` | 自动检测 | 节点IP | 广播地址 |
| `--etcd-servers` | - | etcd集群地址 | etcd连接地址 |
| `--etcd-cafile` | - | /etc/kubernetes/pki/etcd/ca.crt | etcd CA |
| `--etcd-certfile` | - | /etc/kubernetes/pki/apiserver-etcd-client.crt | etcd客户端证书 |
| `--etcd-keyfile` | - | /etc/kubernetes/pki/apiserver-etcd-client.key | etcd客户端私钥 |
| `--service-cluster-ip-range` | 10.0.0.0/24 | 10.96.0.0/12 | Service IP范围 |
| `--service-node-port-range` | 30000-32767 | 30000-32767 | NodePort范围 |

### 6.2 性能调优参数

| 参数 | 默认值 | 推荐值(大集群) | 说明 |
|:---|:---|:---|:---|
| `--max-requests-inflight` | 400 | 800-1600 | 非变更请求最大并发 |
| `--max-mutating-requests-inflight` | 200 | 400-800 | 变更请求最大并发 |
| `--target-ram-mb` | - | 根据集群规模设置 | 目标内存(用于缓存) |
| `--watch-cache-sizes` | - | 根据资源调整 | Watch缓存大小 |
| `--default-watch-cache-size` | 100 | 100-1000 | 默认Watch缓存 |
| `--etcd-count-metric-poll-period` | 1m | 1m | etcd计数指标轮询周期 |
| `--request-timeout` | 60s | 60s | 请求超时时间 |
| `--min-request-timeout` | 1800s | 1800s | 最小请求超时(用于Watch) |

### 6.3 安全参数

| 参数 | 说明 | 推荐配置 |
|:---|:---|:---|
| `--anonymous-auth` | 匿名访问 | false |
| `--enable-admission-plugins` | 启用的准入控制器 | NodeRestriction,PodSecurity |
| `--audit-log-path` | 审计日志路径 | /var/log/kubernetes/audit.log |
| `--audit-policy-file` | 审计策略文件 | /etc/kubernetes/audit-policy.yaml |
| `--audit-log-maxage` | 审计日志保留天数 | 30 |
| `--audit-log-maxbackup` | 审计日志备份数 | 10 |
| `--audit-log-maxsize` | 审计日志最大大小(MB) | 100 |
| `--profiling` | 性能分析端点 | false (生产环境) |
| `--enable-swagger-ui` | Swagger UI | false |

---

## 7. 审计日志 (Audit Logging)

### 7.1 审计级别

| 级别 | 英文 | 记录内容 |
|:---|:---|:---|
| **None** | 无 | 不记录 |
| **Metadata** | 元数据 | 请求元数据(用户、时间、资源、动作) |
| **Request** | 请求 | 元数据 + 请求体 |
| **RequestResponse** | 请求响应 | 元数据 + 请求体 + 响应体 |

### 7.2 审计策略示例

```yaml
# /etc/kubernetes/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# 不记录的请求
- level: None
  users: ["system:kube-proxy"]
  verbs: ["watch"]
  resources:
  - group: ""
    resources: ["endpoints", "services", "services/status"]

# 不记录健康检查
- level: None
  nonResourceURLs:
  - /healthz*
  - /version
  - /swagger*
  - /readyz*
  - /livez*

# 不记录高频只读操作
- level: None
  resources:
  - group: ""
    resources: ["events"]

# Secrets 只记录元数据(不记录内容)
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]

# 记录所有删除操作的请求和响应
- level: RequestResponse
  verbs: ["delete", "deletecollection"]

# 记录写操作的请求体
- level: Request
  verbs: ["create", "update", "patch"]
  resources:
  - group: ""
    resources: ["pods", "services", "deployments"]

# 默认记录元数据
- level: Metadata
  omitStages:
  - "RequestReceived"
```

### 7.3 审计后端配置

```bash
# 日志文件后端
--audit-log-path=/var/log/kubernetes/audit.log
--audit-log-maxage=30
--audit-log-maxbackup=10
--audit-log-maxsize=100

# Webhook 后端
--audit-webhook-config-file=/etc/kubernetes/audit-webhook-config.yaml
--audit-webhook-initial-backoff=10s
--audit-webhook-batch-max-size=400
--audit-webhook-batch-max-wait=30s
```

```yaml
# audit-webhook-config.yaml
apiVersion: v1
kind: Config
clusters:
- name: audit-webhook
  cluster:
    server: https://audit-service.kube-system.svc:443/audit
    certificate-authority: /etc/kubernetes/pki/audit-ca.crt
contexts:
- name: default
  context:
    cluster: audit-webhook
current-context: default
```

---

## 8. 监控指标 (Monitoring Metrics)

### 8.1 关键指标表

| 指标名称 | 类型 | 说明 | 告警阈值 |
|:---|:---|:---|:---|
| `apiserver_request_total` | Counter | 请求总数(按verb、resource、code) | - |
| `apiserver_request_duration_seconds` | Histogram | 请求延迟 | p99 > 1s |
| `apiserver_current_inflight_requests` | Gauge | 当前并发请求数 | > max * 0.8 |
| `apiserver_response_sizes` | Histogram | 响应大小分布 | - |
| `apiserver_admission_controller_admission_duration_seconds` | Histogram | 准入控制延迟 | p99 > 100ms |
| `apiserver_admission_webhook_admission_duration_seconds` | Histogram | Webhook延迟 | p99 > 500ms |
| `etcd_request_duration_seconds` | Histogram | etcd请求延迟 | p99 > 200ms |
| `apiserver_storage_objects` | Gauge | 存储对象数 | - |
| `apiserver_watch_events_total` | Counter | Watch事件数 | - |
| `apiserver_longrunning_requests` | Gauge | 长连接请求数(Watch) | - |
| `process_resident_memory_bytes` | Gauge | 内存使用 | > 16GB |
| `process_cpu_seconds_total` | Counter | CPU使用 | - |

### 8.2 Prometheus 告警规则

```yaml
groups:
- name: kube-apiserver
  rules:
  - alert: KubeAPIServerDown
    expr: absent(up{job="kube-apiserver"} == 1)
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "kube-apiserver is down"

  - alert: KubeAPIServerLatencyHigh
    expr: histogram_quantile(0.99, rate(apiserver_request_duration_seconds_bucket{verb!="WATCH"}[5m])) > 1
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "kube-apiserver latency is high"
      description: "API server p99 latency is {{ $value }}s"

  - alert: KubeAPIServerErrorsHigh
    expr: sum(rate(apiserver_request_total{code=~"5.."}[5m])) / sum(rate(apiserver_request_total[5m])) > 0.01
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "kube-apiserver error rate is high"

  - alert: KubeAPIServerSaturated
    expr: apiserver_current_inflight_requests / apiserver_current_inflight_requests_limit > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "kube-apiserver is saturated"

  - alert: KubeAPIServerAdmissionWebhookLatency
    expr: histogram_quantile(0.99, rate(apiserver_admission_webhook_admission_duration_seconds_bucket[5m])) > 0.5
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Admission webhook latency is high"

  - alert: KubeAPIServerEtcdLatencyHigh
    expr: histogram_quantile(0.99, rate(etcd_request_duration_seconds_bucket[5m])) > 0.2
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "etcd request latency from apiserver is high"
```

---

## 9. 高可用部署 (High Availability)

### 9.1 HA 架构模式

| 模式 | 说明 | 适用场景 |
|:---|:---|:---|
| **堆叠模式** | etcd与控制平面部署在同一节点 | 中小规模集群 |
| **外部etcd模式** | etcd独立部署 | 大规模集群、高可用要求高 |

### 9.2 负载均衡配置

```yaml
# HAProxy 配置示例
frontend kube-apiserver
    bind *:6443
    mode tcp
    option tcplog
    default_backend kube-apiserver

backend kube-apiserver
    mode tcp
    option tcp-check
    balance roundrobin
    default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
    server master1 10.0.0.1:6443 check
    server master2 10.0.0.2:6443 check
    server master3 10.0.0.3:6443 check
```

```yaml
# Nginx 配置示例
stream {
    upstream kube-apiserver {
        least_conn;
        server 10.0.0.1:6443 max_fails=3 fail_timeout=30s;
        server 10.0.0.2:6443 max_fails=3 fail_timeout=30s;
        server 10.0.0.3:6443 max_fails=3 fail_timeout=30s;
    }
    
    server {
        listen 6443;
        proxy_pass kube-apiserver;
        proxy_timeout 10m;
        proxy_connect_timeout 1s;
    }
}
```

### 9.3 健康检查端点

| 端点 | 用途 | 检查内容 |
|:---|:---|:---|
| `/healthz` | 整体健康检查 | 所有健康检查的聚合结果 |
| `/livez` | 存活检查 | 进程是否正常运行 |
| `/readyz` | 就绪检查 | 是否可以接收请求 |
| `/healthz/etcd` | etcd连接检查 | etcd是否可访问 |
| `/healthz/poststarthook/*` | 启动钩子检查 | 各启动钩子状态 |

```bash
# 健康检查命令
curl -k https://localhost:6443/healthz
curl -k https://localhost:6443/livez
curl -k https://localhost:6443/readyz
curl -k https://localhost:6443/healthz?verbose
```

---

## 10. 故障排查 (Troubleshooting)

### 10.1 常见问题诊断

| 症状 | 可能原因 | 诊断方法 | 解决方案 |
|:---|:---|:---|:---|
| **连接超时** | 网络问题/服务未启动 | telnet检查端口/systemctl status | 检查网络配置/启动服务 |
| **认证失败 (401)** | 证书错误/Token无效 | 检查证书有效期和配置 | 更新证书/Token |
| **授权失败 (403)** | RBAC配置不足 | kubectl auth can-i | 添加适当的RBAC权限 |
| **etcd连接失败** | etcd不可用/证书问题 | etcdctl endpoint health | 检查etcd集群状态 |
| **请求超时** | 负载过高/etcd慢 | 检查指标和日志 | 扩容/优化性能 |
| **OOM** | 内存不足 | dmesg/检查内存使用 | 增加内存/优化配置 |
| **证书过期** | 证书未轮换 | openssl检查有效期 | kubeadm certs renew |

### 10.2 诊断命令

```bash
# 检查 API Server 状态
systemctl status kube-apiserver
journalctl -u kube-apiserver -f --no-pager

# 检查证书有效期
kubeadm certs check-expiration
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates

# 检查 API 可访问性
kubectl get --raw /healthz
kubectl get --raw /livez
kubectl get --raw /readyz

# 检查 RBAC 权限
kubectl auth can-i create pods --as=system:serviceaccount:default:default
kubectl auth can-i --list --as=developer@example.com

# 检查准入控制器
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations

# 查看请求详情
kubectl -v=9 get pods  # 详细输出

# 检查 API 资源
kubectl api-resources
kubectl api-versions
```

### 10.3 证书轮换

```bash
# kubeadm 管理的集群
kubeadm certs renew all

# 手动轮换 (非kubeadm)
# 1. 生成新证书
cfssl gencert ... | cfssljson -bare apiserver

# 2. 备份旧证书
cp /etc/kubernetes/pki/apiserver.{crt,key} /etc/kubernetes/pki/backup/

# 3. 替换证书
cp apiserver.pem /etc/kubernetes/pki/apiserver.crt
cp apiserver-key.pem /etc/kubernetes/pki/apiserver.key

# 4. 重启 API Server
systemctl restart kube-apiserver
```

---

## 11. 生产环境 Checklist

### 11.1 部署检查

| 检查项 | 状态 | 说明 |
|:---|:---|:---|
| [ ] 多实例部署 (3+) | | 高可用保证 |
| [ ] 负载均衡配置 | | 流量分发 |
| [ ] TLS配置完整 | | 通信加密 |
| [ ] 证书有效期充足 | | 避免过期中断 |
| [ ] 审计日志启用 | | 合规要求 |
| [ ] RBAC配置完善 | | 最小权限原则 |
| [ ] 监控告警配置 | | 运维保障 |
| [ ] 资源限制配置 | | 防止资源耗尽 |
| [ ] 网络策略配置 | | 网络安全 |
| [ ] 定期备份etcd | | 数据保护 |

### 11.2 安全加固

| 加固项 | 推荐配置 |
|:---|:---|
| 匿名访问 | --anonymous-auth=false |
| 不安全端口 | --insecure-port=0 (已在1.24+移除) |
| 性能分析 | --profiling=false |
| AlwaysAllow授权 | 不使用，使用RBAC |
| 审计日志 | 启用并配置合理的保留策略 |
| 准入控制 | 启用NodeRestriction,PodSecurity |
| 加密存储 | --encryption-provider-config |

---

## 附录: 常用 API 端点

```bash
# 核心 API
/api/v1/namespaces
/api/v1/pods
/api/v1/services
/api/v1/nodes

# 扩展 API
/apis/apps/v1/deployments
/apis/batch/v1/jobs
/apis/networking.k8s.io/v1/ingresses

# 集群信息
/version                    # 版本信息
/api                        # 核心API组
/apis                       # 所有API组
/openapi/v2                 # OpenAPI规范

# 健康检查
/healthz
/livez
/readyz

# 指标
/metrics
/metrics/cadvisor

# 调试 (需要启用profiling)
/debug/pprof/
```
