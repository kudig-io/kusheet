# 表格71: Gateway API配置

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [gateway-api.sigs.k8s.io](https://gateway-api.sigs.k8s.io/)

## Gateway API vs Ingress

| 特性 | Ingress | Gateway API | 说明 |
|-----|---------|-------------|------|
| **角色分离** | ❌ | ✅ (平台/开发者) | 平台管理Gateway,开发者配置Route |
| **多协议** | HTTP(S) | HTTP/HTTPS/TCP/UDP/gRPC/TLS | 统一多协议支持 |
| **流量分割** | ❌ | ✅ 原生支持 | 基于权重的流量分配 |
| **请求修改** | 注解依赖 | ✅ 标准化 | 统一的Filter机制 |
| **后端引用** | Service | Service/任意后端 | 更灵活的后端选择 |
| **跨命名空间** | ❌ | ✅ ReferenceGrant | 安全的跨NS引用 |
| **状态丰富度** | 简单 | 详细条件状态 | 更好的可观测性 |
| **扩展性** | 注解 | Policy附件 | 标准化扩展机制 |

## Gateway API CRD

| CRD | 作用域 | 说明 |
|-----|-------|------|
| GatewayClass | Cluster | 定义网关类型(平台管理) |
| Gateway | Namespace | 网关实例(平台/团队) |
| HTTPRoute | Namespace | HTTP路由规则(开发者) |
| GRPCRoute | Namespace | gRPC路由规则 |
| TCPRoute | Namespace | TCP路由规则 |
| UDPRoute | Namespace | UDP路由规则 |
| TLSRoute | Namespace | TLS路由规则 |
| ReferenceGrant | Namespace | 跨命名空间引用授权 |

## GatewayClass配置

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: istio
spec:
  controllerName: istio.io/gateway-controller
  description: "Istio Gateway Controller"
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx
spec:
  controllerName: nginx.org/gateway-controller
```

## Gateway配置

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: production-gateway
  namespace: gateway-system
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    hostname: "*.example.com"
    allowedRoutes:
      namespaces:
        from: All
  - name: https
    port: 443
    protocol: HTTPS
    hostname: "*.example.com"
    tls:
      mode: Terminate
      certificateRefs:
      - name: wildcard-cert
        kind: Secret
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            shared-gateway: "true"
  addresses:
  - type: IPAddress
    value: 10.0.0.100
```

## HTTPRoute配置

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp-route
  namespace: production
spec:
  parentRefs:
  - name: production-gateway
    namespace: gateway-system
  hostnames:
  - "myapp.example.com"
  rules:
  # 精确路径匹配
  - matches:
    - path:
        type: Exact
        value: /api/v1/users
      method: GET
    backendRefs:
    - name: users-service
      port: 8080
  # 前缀匹配 + Header条件
  - matches:
    - path:
        type: PathPrefix
        value: /api
      headers:
      - name: x-version
        value: v2
    backendRefs:
    - name: api-v2
      port: 8080
  # 流量分割
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: frontend-v1
      port: 80
      weight: 90
    - name: frontend-v2
      port: 80
      weight: 10
```

## HTTPRoute过滤器

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: filtered-route
spec:
  parentRefs:
  - name: gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /old-path
    filters:
    # 请求重定向
    - type: RequestRedirect
      requestRedirect:
        hostname: new.example.com
        statusCode: 301
  - matches:
    - path:
        type: PathPrefix
        value: /api
    filters:
    # URL重写
    - type: URLRewrite
      urlRewrite:
        hostname: backend.internal
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /v1
    # 添加请求头
    - type: RequestHeaderModifier
      requestHeaderModifier:
        add:
        - name: X-Custom-Header
          value: custom-value
        set:
        - name: Host
          value: backend.internal
        remove:
        - X-Remove-Me
    backendRefs:
    - name: backend
      port: 8080
```

## GRPCRoute配置

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GRPCRoute
metadata:
  name: grpc-route
spec:
  parentRefs:
  - name: gateway
  hostnames:
  - grpc.example.com
  rules:
  - matches:
    - method:
        service: mypackage.MyService
        method: MyMethod
    backendRefs:
    - name: grpc-service
      port: 50051
```

## ReferenceGrant(跨命名空间)

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-gateway-to-backend
  namespace: backend-ns
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: frontend-ns
  to:
  - group: ""
    kind: Service
    name: backend-service
```

## Gateway API实现

| 实现 | 成熟度 | 支持协议 |
|-----|-------|---------|
| Istio | GA | HTTP/HTTPS/TCP/gRPC |
| NGINX Gateway Fabric | GA | HTTP/HTTPS |
| Contour | GA | HTTP/HTTPS |
| Envoy Gateway | GA | HTTP/HTTPS/gRPC |
| Traefik | GA | HTTP/HTTPS |
| HAProxy | Beta | HTTP/HTTPS |

## ACK Gateway支持

| 功能 | 说明 | 配置方式 |
|-----|------|---------|
| **ALB Ingress** | 支持Gateway API | 组件安装 |
| **ASM网关** | Istio Gateway API | ASM控制台 |
| **MSE云原生网关** | 企业级网关 | MSE控制台 |
| **Higress** | 开源云原生网关 | Helm安装 |

```yaml
# ACK ALB Gateway配置
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: alb
spec:
  controllerName: ingress.k8s.alibabacloud/alb
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: alb-gateway
spec:
  gatewayClassName: alb
  listeners:
  - name: http
    port: 80
    protocol: HTTP
  - name: https
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      certificateRefs:
      - name: alb-cert
```

## 迁移指南 (Ingress -> Gateway API)

| Ingress配置 | Gateway API对应 |
|------------|----------------|
| `spec.rules[].host` | HTTPRoute `hostnames` |
| `spec.rules[].http.paths` | HTTPRoute `rules[].matches` |
| `spec.tls` | Gateway `listeners[].tls` |
| `backend.service` | HTTPRoute `backendRefs` |
| 注解 | Policy附件/Filter |

## 版本变更记录

| 版本 | 变更内容 | 状态 |
|------|---------|------|
| v0.5.0 | HTTPRoute/Gateway GA | 生产可用 |
| v0.6.0 | ReferenceGrant GA | 生产可用 |
| v0.8.0 | GRPCRoute GA | 生产可用 |
| v1.0.0 | 核心API稳定 | GA |
| v1.1.0 | BackendLBPolicy | Beta |
| v1.2.0 | 改进的状态报告 | 最新 |

---

**Gateway API原则**: 角色分离(平台/开发者) + 标准化配置 + 多协议支持 + 安全的跨NS引用
