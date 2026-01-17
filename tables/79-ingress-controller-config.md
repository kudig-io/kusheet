# 表格79: Ingress控制器配置

## Ingress控制器对比

| 控制器 | 维护者 | 特点 | 适用场景 |
|-------|-------|------|---------|
| NGINX Ingress | Kubernetes社区 | 功能丰富,广泛使用 | 通用 |
| Traefik | Traefik Labs | 云原生,自动发现 | 动态环境 |
| HAProxy | HAProxy | 高性能,企业级 | 高流量 |
| Contour | VMware | Envoy代理 | 现代架构 |
| Kong | Kong Inc | API网关集成 | API管理 |
| ALB Ingress | 阿里云 | 云原生,SLB集成 | ACK |

## NGINX Ingress配置

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "10"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /api(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: api-service
            port:
              number: 8080
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

## NGINX Ingress常用注解

| 注解 | 默认值 | 说明 |
|-----|-------|------|
| `proxy-body-size` | 1m | 请求体大小限制 |
| `proxy-read-timeout` | 60 | 读取超时(秒) |
| `proxy-send-timeout` | 60 | 发送超时(秒) |
| `proxy-connect-timeout` | 5 | 连接超时(秒) |
| `ssl-redirect` | true | HTTP重定向HTTPS |
| `rewrite-target` | - | URL重写 |
| `use-regex` | false | 启用正则路径 |
| `limit-rps` | - | 请求速率限制 |
| `limit-connections` | - | 并发连接限制 |
| `whitelist-source-range` | - | IP白名单 |
| `auth-type` | - | 认证类型 |
| `auth-secret` | - | 认证密钥 |
| `canary` | false | 金丝雀发布 |
| `canary-weight` | - | 金丝雀权重 |

## 金丝雀发布

```yaml
# 稳定版本
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-stable
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-v1
            port:
              number: 80
---
# 金丝雀版本
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"
    # 或基于Header
    # nginx.ingress.kubernetes.io/canary-by-header: "X-Canary"
    # nginx.ingress.kubernetes.io/canary-by-header-value: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-v2
            port:
              number: 80
```

## 认证配置

```yaml
# Basic Auth
apiVersion: v1
kind: Secret
metadata:
  name: basic-auth
type: Opaque
data:
  auth: <base64-encoded htpasswd>
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: auth-ingress
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
spec:
  rules:
  - host: admin.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 80
```

## 速率限制

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rate-limit-ingress
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/limit-connections: "5"
    nginx.ingress.kubernetes.io/limit-whitelist: "10.0.0.0/8"
spec:
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
```

## ALB Ingress(ACK)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: alb-ingress
  annotations:
    alb.ingress.kubernetes.io/address-type: internet
    alb.ingress.kubernetes.io/load-balancer-name: my-alb
    alb.ingress.kubernetes.io/vswitch-ids: "vsw-xxx,vsw-yyy"
    alb.ingress.kubernetes.io/health-check-enabled: "true"
    alb.ingress.kubernetes.io/health-check-path: "/health"
spec:
  ingressClassName: alb
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

## Ingress监控

| 指标 | 类型 | 说明 |
|-----|-----|------|
| `nginx_ingress_controller_requests` | Counter | 请求总数 |
| `nginx_ingress_controller_request_duration_seconds` | Histogram | 请求延迟 |
| `nginx_ingress_controller_response_size` | Histogram | 响应大小 |
| `nginx_ingress_controller_nginx_process_connections` | Gauge | 连接数 |

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| v1.25 | IngressClass默认行为改进 |
| v1.28 | Ingress路径匹配增强 |
| v1.30 | Gateway API集成改进 |
