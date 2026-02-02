# Gateway API 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32, Gateway API v1.0 - v1.2 | **最后更新**: 2026-01 | **难度**: 高级
>
> **版本说明**:
> - Gateway API v1.0 (2023-10) HTTPRoute/Gateway/GatewayClass GA
> - Gateway API v1.1 (2024-05) 新增 BackendTLSPolicy, 支持 session persistence
> - Gateway API v1.2 (2024-10) GRPCRoute GA, 新增 BackendLBPolicy
> - K8s v1.31+ 内置支持 Gateway API CRD

---

## 第一部分：问题现象与影响分析

### 1.1 Gateway API 架构

```
┌──────────────────────────────────────────────────────────────────────────┐
│                      Gateway API 资源模型                                │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌────────────────────────────────────────────────────────────────┐    │
│   │                     GatewayClass                                │    │
│   │  (集群级别资源 - 定义 Gateway 的类型和控制器)                   │    │
│   │                                                                 │    │
│   │  controllerName: gateway.nginx.org/nginx-gateway-controller     │    │
│   │  parametersRef: --> 指向控制器特定配置                          │    │
│   └───────────────────────────┬────────────────────────────────────┘    │
│                               │                                          │
│                     引用 GatewayClass                                    │
│                               │                                          │
│   ┌───────────────────────────┴────────────────────────────────────┐    │
│   │                       Gateway                                   │    │
│   │  (namespace 级别 - 定义监听器和端口)                           │    │
│   │                                                                 │    │
│   │  listeners:                                                     │    │
│   │  - name: http                                                   │    │
│   │    port: 80                                                     │    │
│   │    protocol: HTTP                                               │    │
│   │    allowedRoutes:                                               │    │
│   │      namespaces: {from: All/Same/Selector}                     │    │
│   └───────────────────────────┬────────────────────────────────────┘    │
│                               │                                          │
│                       Route 绑定到 Gateway                               │
│                               │                                          │
│   ┌───────────────────────────┴────────────────────────────────────┐    │
│   │                      xRoutes                                    │    │
│   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │    │
│   │  │  HTTPRoute   │  │  GRPCRoute   │  │   TCPRoute   │         │    │
│   │  │              │  │              │  │              │         │    │
│   │  │ - hostnames  │  │ - hostnames  │  │ - rules      │         │    │
│   │  │ - rules      │  │ - rules      │  │              │         │    │
│   │  │ - backendRefs│  │ - backendRefs│  │              │         │    │
│   │  └──────────────┘  └──────────────┘  └──────────────┘         │    │
│   │                                                                 │    │
│   │  ┌──────────────┐  ┌──────────────┐                           │    │
│   │  │   TLSRoute   │  │   UDPRoute   │                           │    │
│   │  └──────────────┘  └──────────────┘                           │    │
│   └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

角色和职责分离:
┌─────────────────────┐
│  集群管理员          │
│  (Cluster Admin)    │
└──────────┬──────────┘
           │
           │ 创建和管理
           ▼
┌─────────────────────┐
│    GatewayClass     │ ◄─── 定义可用的 Gateway 类型
└──────────┬──────────┘
           │
           │ 基于 GatewayClass 创建
           ▼
┌─────────────────────┐
│  平台管理员          │
│  (Platform Admin)   │
└──────────┬──────────┘
           │
           │ 创建和管理
           ▼
┌─────────────────────┐
│      Gateway        │ ◄─── 定义入口点和监听器
└──────────┬──────────┘
           │
           │ Route 绑定
           ▼
┌─────────────────────┐
│  应用开发者          │
│  (App Developer)    │
└──────────┬──────────┘
           │
           │ 创建和管理
           ▼
┌─────────────────────┐
│     HTTPRoute       │ ◄─── 定义路由规则
│     GRPCRoute       │
│       ...           │
└─────────────────────┘

流量路径:
                                                    
  客户端      Gateway Pod      Service        Pod
     │             │              │            │
     │── HTTP ────>│              │            │
     │             │── 路由匹配 ──>            │
     │             │  (HTTPRoute) │            │
     │             │              │            │
     │             │──────────────>            │
     │             │     (Backend)│            │
     │             │              │── 转发 ───>│
     │             │              │            │
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 错误信息 | 查看方式 |
|----------|----------|----------|----------|
| GatewayClass 未就绪 | Gateway 创建失败 | InvalidGatewayClass | Gateway status |
| Gateway 未就绪 | Listener 未 Ready | ListenerNotReady | Gateway status |
| Route 未绑定 | 路由规则不生效 | RouteNotAccepted | Route status |
| 后端不可达 | 503 错误 | BackendNotFound | Route status |
| TLS 配置错误 | HTTPS 握手失败 | Invalid certificate | Gateway 日志 |
| 跨 namespace 路由失败 | Route 无法绑定 | RefNotPermitted | Route status |
| 路由冲突 | 路由规则被覆盖 | Conflicted | Route status |
| 控制器未运行 | 所有资源不生效 | 无 | 控制器 Pod 状态 |

### 1.3 影响分析

| 问题类型 | 直接影响 | 间接影响 | 影响范围 |
|----------|----------|----------|----------|
| 控制器故障 | 所有 Gateway 资源不生效 | 入站流量中断 | 整个集群 |
| Gateway 未就绪 | 特定入口点不可用 | 对应服务不可访问 | Gateway 下所有 Route |
| Route 未绑定 | 特定路由不生效 | 对应路径不可访问 | 特定 Route |
| TLS 错误 | HTTPS 访问失败 | 安全通信失败 | 受影响的监听器 |

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
Gateway API 问题
        │
        ▼
┌───────────────────────┐
│  问题发生在哪一层？    │
└───────────────────────┘
        │
        ├── GatewayClass 层 ─────────────────────────────────┐
        │                                                     │
        │   ┌─────────────────────────────────────────┐      │
        │   │ GatewayClass 状态是否 Accepted?         │      │
        │   │ kubectl get gatewayclass                │      │
        │   └─────────────────────────────────────────┘      │
        │          │                │                         │
        │         否               是                         │
        │          │                │                         │
        │          ▼                ▼                         │
        │   ┌────────────┐   ┌────────────────┐              │
        │   │ 检查控制器 │   │ GatewayClass   │              │
        │   │ 是否运行   │   │ 正常，检查     │              │
        │   │            │   │ Gateway 层     │              │
        │   └────────────┘   └────────────────┘              │
        │                                                     │
        ├── Gateway 层 ──────────────────────────────────────┤
        │                                                     │
        │   ┌─────────────────────────────────────────┐      │
        │   │ Gateway 状态是否 Programmed?            │      │
        │   │ kubectl get gateway -o yaml             │      │
        │   └─────────────────────────────────────────┘      │
        │          │                │                         │
        │         否               是                         │
        │          │                │                         │
        │          ▼                ▼                         │
        │   ┌────────────┐   ┌────────────────┐              │
        │   │ 检查 Listener│  │ Gateway 正常   │              │
        │   │ 状态和配置  │  │ 检查 Route 层  │              │
        │   └────────────┘   └────────────────┘              │
        │                                                     │
        ├── Route 层 ────────────────────────────────────────┤
        │                                                     │
        │   ┌─────────────────────────────────────────┐      │
        │   │ Route 状态是否 Accepted?                │      │
        │   │ kubectl get httproute -o yaml           │      │
        │   └─────────────────────────────────────────┘      │
        │          │                │                         │
        │         否               是                         │
        │          │                │                         │
        │          ▼                ▼                         │
        │   ┌────────────┐   ┌────────────────┐              │
        │   │ 检查 Parent│   │ Route 已接受   │              │
        │   │ Ref 和权限 │   │ 检查后端状态   │              │
        │   └────────────┘   └────────────────┘              │
        │                                                     │
        └── Backend 层 ──────────────────────────────────────┤
                                                              │
            ┌─────────────────────────────────────────┐      │
            │ BackendRef 状态是否 ResolvedRefs?       │      │
            └─────────────────────────────────────────┘      │
                   │                │                         │
                  否               是                         │
                   │                │                         │
                   ▼                ▼                         │
            ┌────────────┐   ┌────────────────┐              │
            │ 检查 Service│  │ 检查 Pod 和    │              │
            │ 是否存在    │  │ Endpoints      │              │
            └────────────┘   └────────────────┘              │
                                                              │
                                                              ▼
                                                       ┌────────────┐
                                                       │ 问题定位   │
                                                       │ 完成       │
                                                       └────────────┘
```

### 2.2 排查命令集

#### Gateway API 资源检查

```bash
# 检查 Gateway API CRD 是否安装
kubectl get crd | grep gateway

# 检查 GatewayClass
kubectl get gatewayclass
kubectl describe gatewayclass <name>

# 检查 Gateway
kubectl get gateway -A
kubectl describe gateway <name> -n <namespace>
kubectl get gateway <name> -n <namespace> -o yaml

# 检查 HTTPRoute
kubectl get httproute -A
kubectl describe httproute <name> -n <namespace>
kubectl get httproute <name> -n <namespace> -o yaml

# 检查其他 Route 类型
kubectl get grpcroute,tcproute,tlsroute,udproute -A
```

#### 状态检查

```bash
# 检查 Gateway 详细状态
kubectl get gateway <name> -n <namespace> -o jsonpath='{.status}' | jq

# 检查所有 Listener 状态
kubectl get gateway <name> -n <namespace> -o jsonpath='{.status.listeners[*]}' | jq

# 检查 HTTPRoute 状态
kubectl get httproute <name> -n <namespace> -o jsonpath='{.status}' | jq

# 检查 Route 的 Parent 状态
kubectl get httproute <name> -n <namespace> -o jsonpath='{.status.parents[*]}' | jq
```

#### 控制器检查

```bash
# 根据不同的 Gateway 控制器实现

# NGINX Gateway Fabric
kubectl get pods -n nginx-gateway
kubectl logs -n nginx-gateway -l app.kubernetes.io/name=nginx-gateway

# Envoy Gateway
kubectl get pods -n envoy-gateway-system
kubectl logs -n envoy-gateway-system -l control-plane=envoy-gateway

# Istio Gateway API
kubectl get pods -n istio-system -l app=istiod
kubectl logs -n istio-system -l app=istiod | grep -i gateway

# Contour
kubectl get pods -n projectcontour
kubectl logs -n projectcontour -l app=contour

# Traefik
kubectl get pods -n traefik
kubectl logs -n traefik -l app.kubernetes.io/name=traefik
```

#### 后端检查

```bash
# 检查 Service
kubectl get svc <service-name> -n <namespace>
kubectl get endpoints <service-name> -n <namespace>

# 检查 Pod 状态
kubectl get pods -n <namespace> -l <selector>

# 测试连接
kubectl run test --rm -it --image=curlimages/curl -- curl http://<service>.<namespace>
```

### 2.3 排查注意事项

| 注意事项 | 说明 | 风险等级 |
|----------|------|----------|
| 状态字段是核心 | 问题诊断主要依赖 status 字段 | - |
| 跨 namespace 需要 ReferenceGrant | Route 引用其他 namespace 的 Service 需要授权 | 中 |
| 控制器特定行为 | 不同实现可能有差异 | 低 |
| CRD 版本兼容性 | 注意 Gateway API 版本 (v1, v1beta1, v1alpha2) | 中 |
| 多控制器冲突 | 避免多个控制器处理同一 GatewayClass | 高 |

## 第三部分：解决方案与风险控制

### 3.1 GatewayClass 未被接受

**问题现象**：GatewayClass 状态不是 Accepted。

**解决步骤**：

```bash
# 步骤 1: 检查 GatewayClass 状态
kubectl get gatewayclass -o wide
kubectl describe gatewayclass <name>

# 步骤 2: 确认控制器是否运行
kubectl get pods -A | grep -i gateway

# 步骤 3: 检查控制器日志
kubectl logs -n <controller-namespace> -l <controller-label>

# 步骤 4: 验证 controllerName 是否匹配
kubectl get gatewayclass <name> -o jsonpath='{.spec.controllerName}'
# 确保与控制器声明的名称一致
```

**GatewayClass 示例**：

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx
spec:
  # 必须与控制器的 controller name 完全匹配
  controllerName: gateway.nginx.org/nginx-gateway-controller
  
  # 可选：控制器特定参数
  parametersRef:
    group: gateway.nginx.org
    kind: NginxProxy
    name: nginx-proxy-config
```

### 3.2 Gateway Listener 未就绪

**问题现象**：Gateway 的 Listener 状态不是 Ready/Programmed。

**解决步骤**：

```bash
# 步骤 1: 查看 Gateway 详细状态
kubectl get gateway <name> -n <namespace> -o yaml

# 检查 listeners 状态
# status.listeners[].conditions 应该包含:
# - type: Accepted (已接受配置)
# - type: Programmed (已编程到数据平面)
# - type: ResolvedRefs (引用已解析)

# 步骤 2: 检查常见问题

# 问题 1: 端口冲突
kubectl get gateway -A -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.listeners[*].port}{"\n"}{end}'

# 问题 2: 协议不支持
# 确保控制器支持配置的协议 (HTTP, HTTPS, TLS, TCP, UDP)

# 问题 3: TLS 配置错误
kubectl get secret <tls-secret> -n <namespace>
```

**Gateway 配置示例**：

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: default
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    hostname: "*.example.com"  # 可选：限制主机名
    allowedRoutes:
      namespaces:
        from: All  # All, Same, Selector
  
  - name: https
    port: 443
    protocol: HTTPS
    hostname: "secure.example.com"
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: tls-secret
        namespace: default  # 需要 ReferenceGrant 如果跨 namespace
    allowedRoutes:
      namespaces:
        from: Same
```

### 3.3 HTTPRoute 未被接受

**问题现象**：HTTPRoute 状态显示未被接受或未绑定到 Gateway。

**解决步骤**：

```bash
# 步骤 1: 检查 HTTPRoute 状态
kubectl get httproute <name> -n <namespace> -o yaml

# 关注 status.parents[].conditions:
# - type: Accepted
# - type: ResolvedRefs

# 步骤 2: 验证 parentRefs 配置
kubectl get httproute <name> -n <namespace> -o jsonpath='{.spec.parentRefs}'

# 步骤 3: 检查 Gateway 是否允许该 namespace 的 Route
kubectl get gateway <gateway-name> -n <gateway-namespace> -o jsonpath='{.spec.listeners[*].allowedRoutes}'
```

**常见问题与解决**：

```yaml
# 问题 1: ParentRef 配置错误
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-route
  namespace: app-namespace
spec:
  parentRefs:
  - name: my-gateway
    namespace: gateway-namespace  # 如果 Gateway 在不同 namespace
    sectionName: http  # 可选：指定特定 Listener
  # ...

# 问题 2: Hostname 不匹配
# Route 的 hostnames 必须与 Gateway Listener 的 hostname 兼容
spec:
  hostnames:
  - "app.example.com"  # 必须被 Listener 的 hostname 模式匹配

# 问题 3: Route 类型不匹配
# HTTP Listener 只接受 HTTPRoute
# HTTPS Listener (TLS Terminate) 接受 HTTPRoute
# TLS Listener (TLS Passthrough) 只接受 TLSRoute
```

### 3.4 跨 Namespace 引用失败

**问题现象**：Route 无法引用其他 namespace 的 Service 或 Gateway。

**解决步骤**：

```bash
# 步骤 1: 检查是否有 ReferenceGrant
kubectl get referencegrant -A

# 步骤 2: 创建 ReferenceGrant 允许跨 namespace 引用
```

**ReferenceGrant 示例**：

```yaml
# 允许 app-namespace 中的 HTTPRoute 引用 backend-namespace 中的 Service
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-app-to-backend
  namespace: backend-namespace  # 被引用资源所在的 namespace
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: app-namespace  # 发起引用的 namespace
  to:
  - group: ""  # core API group
    kind: Service

---
# 允许 app-namespace 中的 Gateway 引用 cert-namespace 中的 Secret
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-gateway-to-secret
  namespace: cert-namespace
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: Gateway
    namespace: gateway-namespace
  to:
  - group: ""
    kind: Secret
```

### 3.5 后端服务不可达

**问题现象**：Route 已接受但请求返回 503 或连接失败。

**解决步骤**：

```bash
# 步骤 1: 检查 Route 的 backendRefs 状态
kubectl get httproute <name> -n <namespace> -o jsonpath='{.status.parents[*].conditions}' | jq

# 步骤 2: 验证 Service 存在
kubectl get svc <service-name> -n <namespace>

# 步骤 3: 检查 Endpoints
kubectl get endpoints <service-name> -n <namespace>

# 步骤 4: 检查 Pod 状态
kubectl get pods -n <namespace> -l <service-selector>

# 步骤 5: 从 Gateway Pod 测试连接
kubectl exec -n <gateway-namespace> <gateway-pod> -- curl http://<service>.<namespace>:<port>
```

**HTTPRoute backendRefs 示例**：

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-route
spec:
  parentRefs:
  - name: my-gateway
  hostnames:
  - "app.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: api-service  # Service 名称
      port: 80           # Service 端口
      weight: 100        # 权重 (用于流量分割)
    
    # 跨 namespace 引用 (需要 ReferenceGrant)
    - name: other-service
      namespace: other-namespace
      port: 8080
```

### 3.6 TLS 证书问题

**问题现象**：HTTPS 访问失败，TLS 握手错误。

**解决步骤**：

```bash
# 步骤 1: 检查 Secret 是否存在
kubectl get secret <tls-secret> -n <namespace>

# 步骤 2: 验证 Secret 类型和内容
kubectl get secret <tls-secret> -n <namespace> -o yaml
# 应该是 type: kubernetes.io/tls
# 包含 tls.crt 和 tls.key

# 步骤 3: 验证证书有效性
kubectl get secret <tls-secret> -n <namespace> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# 检查:
# - 证书是否过期
# - 证书的 CN/SAN 是否匹配 hostname
# - 证书链是否完整

# 步骤 4: 检查 Gateway Listener 配置
kubectl get gateway <name> -n <namespace> -o jsonpath='{.spec.listeners[*].tls}'
```

**TLS 配置示例**：

```yaml
# 创建 TLS Secret
kubectl create secret tls my-tls-secret \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n <namespace>

---
# Gateway 配置
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: https-gateway
spec:
  gatewayClassName: nginx
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    hostname: "secure.example.com"
    tls:
      mode: Terminate  # 或 Passthrough
      certificateRefs:
      - kind: Secret
        name: my-tls-secret
        # namespace: 如果跨 namespace 需要 ReferenceGrant
```

### 3.7 路由冲突

**问题现象**：多个 Route 规则冲突，流量路由不符合预期。

**解决步骤**：

```bash
# 步骤 1: 列出所有绑定到同一 Gateway 的 Route
kubectl get httproute -A -o json | jq '.items[] | select(.spec.parentRefs[].name == "<gateway-name>") | {name: .metadata.name, namespace: .metadata.namespace, hostnames: .spec.hostnames}'

# 步骤 2: 检查是否有 hostname 和 path 冲突
# Gateway API 有明确的优先级规则:
# 1. 更具体的 hostname (精确 > 通配符)
# 2. 更长的 path
# 3. 更多的 header/query 匹配
# 4. 字母顺序 (namespace/name)

# 步骤 3: 检查 Route 状态是否显示 Conflicted
kubectl get httproute <name> -n <namespace> -o jsonpath='{.status.parents[*].conditions}' | jq '.[] | select(.type == "Accepted")'
```

**路由优先级示例**：

```yaml
# Route 1: 更具体的路径优先
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: specific-route
spec:
  parentRefs:
  - name: my-gateway
  rules:
  - matches:
    - path:
        type: Exact  # Exact 比 PathPrefix 更具体
        value: /api/users
    backendRefs:
    - name: users-service
      port: 80

---
# Route 2: 更通用的路径
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: general-route
spec:
  parentRefs:
  - name: my-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: api-service
      port: 80
```

### 3.8 控制器未处理资源

**问题现象**：所有 Gateway API 资源都不生效。

**解决步骤**：

```bash
# 步骤 1: 检查 Gateway API CRD 是否安装
kubectl get crd | grep gateway.networking.k8s.io

# 如果没有，安装 Gateway API CRD
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# 步骤 2: 检查控制器 Pod 状态
kubectl get pods -A | grep -i gateway

# 步骤 3: 查看控制器日志
kubectl logs -n <controller-namespace> <controller-pod>

# 步骤 4: 检查控制器 RBAC
kubectl get clusterrole | grep -i gateway
kubectl describe clusterrole <gateway-controller-role>

# 步骤 5: 验证控制器版本与 CRD 版本兼容
kubectl get crd gateways.gateway.networking.k8s.io -o jsonpath='{.spec.versions[*].name}'
```

### 3.9 安全生产风险提示

| 操作 | 风险等级 | 潜在风险 | 建议措施 |
|------|----------|----------|----------|
| 删除 GatewayClass | 高 | 所有依赖的 Gateway 可能失效 | 确认无依赖 |
| 修改 Gateway Listener | 中 | 可能中断现有路由 | 使用新 Listener 名称 |
| 删除 ReferenceGrant | 高 | 跨 namespace 引用立即失效 | 提前迁移 |
| 升级 Gateway API CRD | 中 | 版本不兼容可能导致问题 | 先测试 |
| 修改 allowedRoutes | 中 | 可能意外允许/拒绝 Route | 仔细审核 |

### 附录：快速诊断命令

```bash
# ===== Gateway API 一键诊断脚本 =====

echo "=== Gateway API CRD 版本 ==="
kubectl get crd gateways.gateway.networking.k8s.io -o jsonpath='{.spec.versions[*].name}' 2>/dev/null || echo "Gateway API CRD 未安装"

echo -e "\n=== GatewayClass 状态 ==="
kubectl get gatewayclass -o wide

echo -e "\n=== Gateway 状态 ==="
kubectl get gateway -A -o wide

echo -e "\n=== HTTPRoute 状态 ==="
kubectl get httproute -A

echo -e "\n=== ReferenceGrant ==="
kubectl get referencegrant -A

echo -e "\n=== 控制器 Pod 状态 ==="
kubectl get pods -A | grep -i "gateway\|envoy\|contour\|traefik" | head -10

echo -e "\n=== Gateway 详细状态 (第一个) ==="
FIRST_GW=$(kubectl get gateway -A -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
FIRST_GW_NS=$(kubectl get gateway -A -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)
if [ -n "$FIRST_GW" ]; then
  kubectl get gateway $FIRST_GW -n $FIRST_GW_NS -o jsonpath='{.status.conditions}' | jq 2>/dev/null
fi
```

### 附录：常用 Gateway API 控制器安装

```bash
# NGINX Gateway Fabric
kubectl apply -f https://github.com/nginxinc/nginx-gateway-fabric/releases/download/v1.0.0/crds.yaml
kubectl apply -f https://github.com/nginxinc/nginx-gateway-fabric/releases/download/v1.0.0/nginx-gateway.yaml

# Envoy Gateway
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v0.5.0 -n envoy-gateway-system --create-namespace

# Istio (with Gateway API)
istioctl install --set profile=minimal
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# Contour
kubectl apply -f https://projectcontour.io/quickstart/contour-gateway-provisioner.yaml
```

### 附录：完整配置示例

```yaml
# 1. GatewayClass
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: example-gateway-class
spec:
  controllerName: example.com/gateway-controller

---
# 2. Gateway
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: example-gateway
  namespace: gateway-infra
spec:
  gatewayClassName: example-gateway-class
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: All
  - name: https
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: example-tls
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            gateway-access: "true"

---
# 3. HTTPRoute
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: example-route
  namespace: app-namespace
spec:
  parentRefs:
  - name: example-gateway
    namespace: gateway-infra
  hostnames:
  - "app.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: app-service
      port: 80

---
# 4. ReferenceGrant (如果需要跨 namespace)
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-routes
  namespace: app-namespace
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: Gateway
    namespace: gateway-infra
  to:
  - group: ""
    kind: Service
```
