# Kubernetes Ingress流量入口生产环境运维培训

> **适用版本**: Kubernetes v1.26-v1.32  
> **文档类型**: PPT演示文稿 | **目标受众**: 运维工程师、SRE、架构师  
> **内容定位**: 理论深入 + 源码级分析 + 生产实战案例

---

## 目录

1. [Ingress核心概念与架构](#1-ingress核心概念与架构)
2. [Ingress控制器深度对比](#2-ingress控制器深度对比)
3. [Ingress资源配置详解](#3-ingress资源配置详解)
4. [TLS证书管理](#4-tls证书管理)
5. [高级流量管理](#5-高级流量管理)
6. [性能优化实践](#6-性能优化实践)
7. [监控与告警](#7-监控与告警)
8. [故障排查手册](#8-故障排查手册)
9. [安全加固配置](#9-安全加固配置)
10. [实战案例演练](#10-实战案例演练)
11. [总结与Q&A](#11-总结与qa)

---

## 1. Ingress核心概念与架构

### 1.1 Ingress架构全景

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Kubernetes Ingress 架构全景                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  互联网用户                                                                  │
│       │                                                                     │
│       ▼                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    云负载均衡器 (SLB/ELB/ALB)                        │   │
│  │                    外部IP: 203.0.113.100                            │   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 │                                           │
│                                 ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Ingress Controller                                │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │  Nginx / ALB / Traefik / HAProxy / Istio Gateway            │   │   │
│  │  │                                                             │   │   │
│  │  │  功能:                                                      │   │   │
│  │  │  • 监听Ingress资源变化                                      │   │   │
│  │  │  • 动态生成反向代理配置                                      │   │   │
│  │  │  • SSL/TLS终结                                              │   │   │
│  │  │  • 基于Host/Path的路由                                      │   │   │
│  │  │  • 负载均衡                                                 │   │   │
│  │  │  • 限流、熔断、重试                                         │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 │                                           │
│                                 │ 基于Ingress规则路由                        │
│                                 │                                           │
│          ┌──────────────────────┼──────────────────────┐                   │
│          │                      │                      │                    │
│          ▼                      ▼                      ▼                    │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐         │
│  │ Service: api     │  │ Service: web     │  │ Service: admin   │         │
│  │ api.example.com  │  │ www.example.com  │  │ admin.example.com│         │
│  │ /api/*           │  │ /                │  │ /                │         │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘         │
│           │                     │                     │                    │
│           ▼                     ▼                     ▼                    │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐         │
│  │    Pod Group     │  │    Pod Group     │  │    Pod Group     │         │
│  │    (API服务)     │  │    (Web前端)     │  │    (管理后台)    │         │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Ingress vs LoadBalancer Service

| 特性 | Ingress | LoadBalancer Service |
|------|---------|---------------------|
| **协议支持** | HTTP/HTTPS (L7) | TCP/UDP (L4) |
| **路由能力** | Host/Path路由 | 仅端口映射 |
| **SSL终结** | 支持，统一管理 | 需要每个Service单独配置 |
| **IP消耗** | 一个IP多个服务 | 每个Service一个IP |
| **成本** | 低 | 高 |
| **灵活性** | 高 | 低 |
| **配置复杂度** | 中 | 低 |
| **适用场景** | Web应用、API | 非HTTP服务 |

### 1.3 Ingress工作流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Ingress 请求处理流程                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. 资源创建阶段                                                         │
│     ┌─────────────────────────────────────────────────────────────┐    │
│     │ 用户创建Ingress → API Server存储 → Controller Watch到变更   │    │
│     │            → Controller读取Ingress规则                      │    │
│     │            → 生成/更新代理配置(nginx.conf等)                 │    │
│     │            → 热重载配置生效                                 │    │
│     └─────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  2. 请求处理阶段                                                         │
│     ┌─────────────────────────────────────────────────────────────┐    │
│     │ 客户端请求 → DNS解析 → 到达LoadBalancer/NodePort            │    │
│     │          → Ingress Controller接收                           │    │
│     │          → 匹配Host头 → 匹配Path → 选择后端Service          │    │
│     │          → 负载均衡选择Pod → 转发请求                       │    │
│     │          → Pod响应 → Controller返回给客户端                 │    │
│     └─────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  3. TLS处理 (如果配置了HTTPS)                                            │
│     ┌─────────────────────────────────────────────────────────────┐    │
│     │ 客户端HTTPS请求 → Controller进行TLS握手                     │    │
│     │                 → 证书验证 → 解密请求                       │    │
│     │                 → HTTP请求转发到后端 (通常是明文HTTP)       │    │
│     │                 → 后端响应 → 加密响应返回客户端             │    │
│     └─────────────────────────────────────────────────────────────┘    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.4 版本演进

| 版本 | 重要特性 | 说明 |
|------|---------|------|
| **v1.18** | networking.k8s.io/v1beta1 | Ingress进入Beta |
| **v1.19** | IngressClass引入 | 支持多Ingress Controller |
| **v1.22** | networking.k8s.io/v1 GA | Ingress正式稳定 |
| **v1.26** | 后端协议注解标准化 | appProtocol支持 |
| **v1.28** | Gateway API成熟 | 下一代Ingress |
| **v1.30** | Ingress性能优化 | 大规模集群支持 |

---

## 2. Ingress控制器深度对比

### 2.1 主流控制器对比矩阵

| 特性 | Nginx Ingress | ALB Ingress | Traefik | HAProxy | Istio Gateway |
|------|--------------|-------------|---------|---------|---------------|
| **性能** | 高 | 极高(云原生) | 中高 | 高 | 中 |
| **配置复杂度** | 中 | 低 | 低 | 高 | 高 |
| **功能丰富度** | 高 | 中 | 高 | 中 | 极高 |
| **社区活跃度** | 极高 | 高(云厂商) | 高 | 中 | 极高 |
| **热更新** | 支持 | 原生 | 原生 | 支持 | 原生 |
| **金丝雀发布** | 注解支持 | 原生 | 原生 | 有限 | 原生 |
| **WAF集成** | ModSecurity | 云WAF | 插件 | 有限 | 无 |
| **监控集成** | Prometheus | 云监控 | 内置 | 内置 | Prometheus |
| **适用场景** | 通用 | 阿里云/AWS | K8s原生 | 高性能 | 服务网格 |

### 2.2 Nginx Ingress Controller

```yaml
# Nginx Ingress Controller部署
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ingress-nginx
    spec:
      serviceAccountName: ingress-nginx
      
      # 反亲和性 - 跨节点分布
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app.kubernetes.io/name: ingress-nginx
              topologyKey: kubernetes.io/hostname
      
      containers:
      - name: controller
        image: registry.k8s.io/ingress-nginx/controller:v1.9.4
        args:
        - /nginx-ingress-controller
        - --publish-service=$(POD_NAMESPACE)/ingress-nginx-controller
        - --election-id=ingress-nginx-leader
        - --controller-class=k8s.io/ingress-nginx
        - --ingress-class=nginx
        - --configmap=$(POD_NAMESPACE)/ingress-nginx-controller
        - --validating-webhook=:8443
        - --validating-webhook-certificate=/usr/local/certificates/cert
        - --validating-webhook-key=/usr/local/certificates/key
        
        # 性能优化参数
        - --enable-metrics=true
        - --metrics-per-host=false
        - --default-backend-service=$(POD_NAMESPACE)/default-backend
        
        ports:
        - name: http
          containerPort: 80
          protocol: TCP
        - name: https
          containerPort: 443
          protocol: TCP
        - name: metrics
          containerPort: 10254
          protocol: TCP
        - name: webhook
          containerPort: 8443
          protocol: TCP
        
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        
        livenessProbe:
          httpGet:
            path: /healthz
            port: 10254
          initialDelaySeconds: 10
          periodSeconds: 10
        
        readinessProbe:
          httpGet:
            path: /healthz
            port: 10254
          initialDelaySeconds: 10
          periodSeconds: 10

---
# Nginx配置ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
data:
  # 代理配置
  proxy-body-size: "100m"
  proxy-connect-timeout: "60"
  proxy-read-timeout: "60"
  proxy-send-timeout: "60"
  
  # 缓冲配置
  proxy-buffer-size: "128k"
  proxy-buffers-number: "4"
  
  # 连接配置
  worker-processes: "auto"
  worker-connections: "65536"
  keep-alive: "75"
  keep-alive-requests: "1000"
  
  # 日志配置
  log-format-upstream: '$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $request_length $request_time [$proxy_upstream_name] [$proxy_alternative_upstream_name] $upstream_addr $upstream_response_length $upstream_response_time $upstream_status $req_id'
  
  # 限流配置
  limit-req-status-code: "429"
  limit-conn-status-code: "429"
  
  # SSL配置
  ssl-protocols: "TLSv1.2 TLSv1.3"
  ssl-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256"
  ssl-prefer-server-ciphers: "true"
  
  # 安全配置
  hide-headers: "X-Powered-By,Server"
  server-tokens: "false"
  
  # 性能优化
  use-gzip: "true"
  gzip-types: "application/json application/javascript text/css text/plain"
  enable-brotli: "true"
```

### 2.3 阿里云ALB Ingress Controller

```yaml
# ALB Ingress Controller (阿里云ACK专用)
apiVersion: alibabacloud.com/v1
kind: AlbConfig
metadata:
  name: default
spec:
  config:
    # ALB实例配置
    name: "k8s-alb"
    addressType: Internet        # Internet | Intranet
    zoneMappings:
    - vSwitchId: vsw-xxx
      zoneId: cn-hangzhou-a
    - vSwitchId: vsw-yyy
      zoneId: cn-hangzhou-b
    
    # 访问日志
    accessLogConfig:
      logProject: "k8s-logs"
      logStore: "alb-access-log"
    
    # 带宽配置
    billingConfig:
      bandwidthPackageId: ""
      internetChargeType: PayByTraffic
    
    # 删除保护
    deletionProtectionConfig:
      enabled: true

---
# ALB Ingress示例
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: alb-ingress
  namespace: production
  annotations:
    # 使用ALB Ingress Class
    kubernetes.io/ingress.class: alb
    
    # ALB特有注解
    alb.ingress.kubernetes.io/address-type: internet
    alb.ingress.kubernetes.io/vswitch-ids: "vsw-xxx,vsw-yyy"
    
    # 健康检查
    alb.ingress.kubernetes.io/healthcheck-enabled: "true"
    alb.ingress.kubernetes.io/healthcheck-path: "/health"
    alb.ingress.kubernetes.io/healthcheck-protocol: "HTTP"
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "5"
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "3"
    
    # 会话保持
    alb.ingress.kubernetes.io/sticky-session: "true"
    alb.ingress.kubernetes.io/sticky-session-type: "insert"
    alb.ingress.kubernetes.io/cookie-timeout: "1800"
    
    # 限流
    alb.ingress.kubernetes.io/traffic-limit-qps: "1000"
    
    # 重定向
    alb.ingress.kubernetes.io/ssl-redirect: "true"
    
    # 金丝雀发布
    alb.ingress.kubernetes.io/canary: "true"
    alb.ingress.kubernetes.io/canary-weight: "20"
spec:
  ingressClassName: alb
  tls:
  - hosts:
    - api.example.com
    secretName: api-tls-secret
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
              number: 80
```

### 2.4 Traefik Ingress Controller

```yaml
# Traefik部署 (Helm values)
# helm install traefik traefik/traefik --namespace traefik --create-namespace -f values.yaml

# values.yaml
deployment:
  replicas: 3

# 入口点配置
ports:
  web:
    port: 80
    exposedPort: 80
    protocol: TCP
  websecure:
    port: 443
    exposedPort: 443
    protocol: TCP
    tls:
      enabled: true

# 日志配置
logs:
  general:
    level: INFO
  access:
    enabled: true
    format: json

# 监控配置
metrics:
  prometheus:
    enabled: true
    entryPoint: metrics

# 中间件
additionalArguments:
- "--providers.kubernetescrd"
- "--providers.kubernetesingress"
- "--entrypoints.web.http.redirections.entrypoint.to=websecure"
- "--entrypoints.web.http.redirections.entrypoint.scheme=https"

---
# Traefik IngressRoute (CRD方式)
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: api-route
  namespace: production
spec:
  entryPoints:
  - websecure
  routes:
  - match: Host(`api.example.com`) && PathPrefix(`/v1`)
    kind: Rule
    services:
    - name: api-v1
      port: 80
      weight: 80
    - name: api-v2
      port: 80
      weight: 20  # 金丝雀发布
    middlewares:
    - name: rate-limit
    - name: secure-headers
  - match: Host(`api.example.com`) && PathPrefix(`/v2`)
    kind: Rule
    services:
    - name: api-v2
      port: 80
  tls:
    secretName: api-tls-secret

---
# 限流中间件
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: rate-limit
  namespace: production
spec:
  rateLimit:
    average: 100
    burst: 200
    period: 1s
    sourceCriterion:
      ipStrategy:
        depth: 1

---
# 安全头中间件
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: secure-headers
  namespace: production
spec:
  headers:
    stsSeconds: 31536000
    stsIncludeSubdomains: true
    stsPreload: true
    forceSTSHeader: true
    contentTypeNosniff: true
    browserXssFilter: true
    customFrameOptionsValue: "SAMEORIGIN"
```

---

## 3. Ingress资源配置详解

### 3.1 基础Ingress配置

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: production-ingress
  namespace: production
  labels:
    app: production
    environment: prod
  annotations:
    # Nginx Ingress特有注解
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
    
spec:
  # Ingress类 - 指定使用哪个Controller
  ingressClassName: nginx
  
  # TLS配置
  tls:
  - hosts:
    - api.example.com
    - www.example.com
    secretName: example-tls-secret
  - hosts:
    - admin.example.com
    secretName: admin-tls-secret
  
  # 路由规则
  rules:
  # API服务
  - host: api.example.com
    http:
      paths:
      - path: /v1
        pathType: Prefix
        backend:
          service:
            name: api-v1
            port:
              number: 80
      - path: /v2
        pathType: Prefix
        backend:
          service:
            name: api-v2
            port:
              number: 80
  
  # Web前端
  - host: www.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-frontend
            port:
              number: 80
      - path: /static
        pathType: Prefix
        backend:
          service:
            name: static-files
            port:
              number: 80
  
  # 管理后台
  - host: admin.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-panel
            port:
              number: 80
  
  # 默认后端 (可选)
  defaultBackend:
    service:
      name: default-backend
      port:
        number: 80
```

### 3.2 Path类型详解

```yaml
# pathType: Exact - 精确匹配
# /foo 匹配 /foo
# /foo 不匹配 /foo/
# /foo 不匹配 /foo/bar

# pathType: Prefix - 前缀匹配
# /foo 匹配 /foo, /foo/, /foo/bar
# / 匹配所有路径

# pathType: ImplementationSpecific - 由Controller决定
# 行为取决于具体的Ingress Controller实现

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-type-demo
spec:
  ingressClassName: nginx
  rules:
  - host: example.com
    http:
      paths:
      # 精确匹配 /api
      - path: /api
        pathType: Exact
        backend:
          service:
            name: api-exact
            port:
              number: 80
      
      # 前缀匹配 /api/v1
      - path: /api/v1
        pathType: Prefix
        backend:
          service:
            name: api-v1
            port:
              number: 80
      
      # 前缀匹配 /api/v2 (优先级高于 /api)
      - path: /api/v2
        pathType: Prefix
        backend:
          service:
            name: api-v2
            port:
              number: 80
      
      # 默认匹配
      - path: /
        pathType: Prefix
        backend:
          service:
            name: default-service
            port:
              number: 80
```

### 3.3 Nginx Ingress高级注解

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: advanced-ingress
  annotations:
    # === 路由与重写 ===
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/app-root: "/index.html"
    
    # === 代理配置 ===
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
    nginx.ingress.kubernetes.io/proxy-buffer-size: "128k"
    nginx.ingress.kubernetes.io/proxy-buffers-number: "4"
    
    # === SSL/TLS ===
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-passthrough: "false"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"  # HTTP|HTTPS|GRPC|GRPCS
    
    # === 负载均衡 ===
    nginx.ingress.kubernetes.io/upstream-hash-by: "$request_uri"
    nginx.ingress.kubernetes.io/load-balance: "round_robin"  # round_robin|least_conn|ip_hash
    
    # === 会话亲和 ===
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/affinity-mode: "balanced"
    nginx.ingress.kubernetes.io/session-cookie-name: "SERVERID"
    nginx.ingress.kubernetes.io/session-cookie-max-age: "3600"
    nginx.ingress.kubernetes.io/session-cookie-path: "/"
    nginx.ingress.kubernetes.io/session-cookie-samesite: "Strict"
    nginx.ingress.kubernetes.io/session-cookie-secure: "true"
    
    # === 限流 ===
    nginx.ingress.kubernetes.io/limit-rps: "100"
    nginx.ingress.kubernetes.io/limit-connections: "50"
    nginx.ingress.kubernetes.io/limit-rate: "1m"
    nginx.ingress.kubernetes.io/limit-rate-after: "10m"
    nginx.ingress.kubernetes.io/limit-whitelist: "10.0.0.0/8,192.168.0.0/16"
    
    # === CORS ===
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://example.com"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-headers: "Content-Type, Authorization"
    nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
    nginx.ingress.kubernetes.io/cors-max-age: "86400"
    
    # === 安全 ===
    nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8"
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
    
    # === 自定义配置 ===
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Request-Id: $request_id";
      more_set_headers "X-Response-Time: $request_time";
    nginx.ingress.kubernetes.io/server-snippet: |
      location /nginx-status {
        stub_status on;
        allow 10.0.0.0/8;
        deny all;
      }
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /api(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
```

---

## 4. TLS证书管理

### 4.1 手动证书配置

```yaml
# 创建TLS Secret
apiVersion: v1
kind: Secret
metadata:
  name: example-tls-secret
  namespace: production
type: kubernetes.io/tls
data:
  # base64编码的证书和私钥
  tls.crt: LS0tLS1CRUdJTi... # base64 encoded certificate
  tls.key: LS0tLS1CRUdJTi... # base64 encoded private key

---
# 使用证书的Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - api.example.com
    - www.example.com
    secretName: example-tls-secret
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
              number: 80
```

### 4.2 cert-manager自动证书

```yaml
# 安装cert-manager
# kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Let's Encrypt ClusterIssuer (生产环境)
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    # HTTP-01 验证
    - http01:
        ingress:
          class: nginx
    # DNS-01 验证 (支持通配符)
    - dns01:
        cloudflare:
          email: admin@example.com
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
      selector:
        dnsZones:
        - "example.com"

---
# Let's Encrypt ClusterIssuer (测试环境)
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
    - http01:
        ingress:
          class: nginx

---
# Certificate资源
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-cert
  namespace: production
spec:
  secretName: example-tls-secret
  duration: 2160h    # 90天
  renewBefore: 360h  # 提前15天续期
  
  subject:
    organizations:
    - Example Inc.
  
  commonName: example.com
  dnsNames:
  - example.com
  - www.example.com
  - api.example.com
  - "*.example.com"  # 通配符需要DNS-01验证
  
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
    group: cert-manager.io

---
# 使用注解自动申请证书的Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: auto-tls-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - api.example.com
    secretName: api-example-tls  # cert-manager会自动创建此Secret
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
              number: 80
```

### 4.3 阿里云证书管理

```yaml
# 阿里云ACK证书管理
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: aliyun-cert-ingress
  annotations:
    # 使用阿里云SSL证书
    nginx.ingress.kubernetes.io/ssl-certificate-id: "xxx-yyy-zzz"
    
    # 或使用云解析证书
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-cert-id: "xxx-yyy-zzz"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - api.example.com
    # 不需要指定secretName，使用阿里云证书
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
              number: 80
```

---

## 5. 高级流量管理

### 5.1 金丝雀发布 (Canary)

```yaml
# 主版本Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: production-ingress
  namespace: production
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-stable
            port:
              number: 80

---
# 金丝雀版本Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: canary-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    
    # 方式1: 按权重分流 (10%流量到金丝雀)
    nginx.ingress.kubernetes.io/canary-weight: "10"
    
    # 方式2: 按Header分流
    # nginx.ingress.kubernetes.io/canary-by-header: "X-Canary"
    # nginx.ingress.kubernetes.io/canary-by-header-value: "true"
    
    # 方式3: 按Cookie分流
    # nginx.ingress.kubernetes.io/canary-by-cookie: "canary"
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-canary
            port:
              number: 80

---
# 金丝雀发布脚本
# canary-deploy.sh
#!/bin/bash

# 阶段1: 10%流量
kubectl patch ingress canary-ingress -n production \
  -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-weight":"10"}}}'
echo "金丝雀流量: 10%"
sleep 300  # 观察5分钟

# 阶段2: 30%流量
kubectl patch ingress canary-ingress -n production \
  -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-weight":"30"}}}'
echo "金丝雀流量: 30%"
sleep 300

# 阶段3: 50%流量
kubectl patch ingress canary-ingress -n production \
  -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-weight":"50"}}}'
echo "金丝雀流量: 50%"
sleep 300

# 阶段4: 全量切换
# 将stable服务指向新版本，删除金丝雀Ingress
kubectl set image deployment/api-stable api=api:v2 -n production
kubectl delete ingress canary-ingress -n production
echo "全量发布完成"
```

### 5.2 蓝绿发布

```yaml
# 蓝色环境 (当前生产)
apiVersion: v1
kind: Service
metadata:
  name: api-blue
  namespace: production
spec:
  selector:
    app: api
    version: blue
  ports:
  - port: 80
    targetPort: 8080

---
# 绿色环境 (新版本)
apiVersion: v1
kind: Service
metadata:
  name: api-green
  namespace: production
spec:
  selector:
    app: api
    version: green
  ports:
  - port: 80
    targetPort: 8080

---
# 流量切换Service
apiVersion: v1
kind: Service
metadata:
  name: api-active
  namespace: production
spec:
  selector:
    app: api
    version: blue  # 切换时改为green
  ports:
  - port: 80
    targetPort: 8080

---
# Ingress指向active Service
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-active
            port:
              number: 80

---
# 蓝绿切换脚本
# blue-green-switch.sh
#!/bin/bash

NAMESPACE="production"
CURRENT=$(kubectl get svc api-active -n $NAMESPACE -o jsonpath='{.spec.selector.version}')

if [ "$CURRENT" == "blue" ]; then
    NEW_VERSION="green"
else
    NEW_VERSION="blue"
fi

echo "切换: $CURRENT -> $NEW_VERSION"

# 检查新版本Pod就绪
kubectl rollout status deployment/api-$NEW_VERSION -n $NAMESPACE

# 执行切换
kubectl patch svc api-active -n $NAMESPACE \
  -p "{\"spec\":{\"selector\":{\"app\":\"api\",\"version\":\"$NEW_VERSION\"}}}"

echo "切换完成，当前版本: $NEW_VERSION"
```

### 5.3 A/B测试

```yaml
# 基于Header的A/B测试
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ab-test-a
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-by-header: "X-AB-Test"
    nginx.ingress.kubernetes.io/canary-by-header-value: "variant-a"
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-variant-a
            port:
              number: 80

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ab-test-b
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-by-header: "X-AB-Test"
    nginx.ingress.kubernetes.io/canary-by-header-value: "variant-b"
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-variant-b
            port:
              number: 80
```

---

## 6. 性能优化实践

### 6.1 Nginx Ingress性能调优

```yaml
# ConfigMap性能配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
data:
  # Worker进程配置
  worker-processes: "auto"
  worker-cpu-affinity: "auto"
  worker-shutdown-timeout: "240s"
  
  # 连接配置
  worker-connections: "65536"
  max-worker-open-files: "65536"
  
  # Keep-alive配置
  keep-alive: "75"
  keep-alive-requests: "10000"
  upstream-keepalive-connections: "320"
  upstream-keepalive-timeout: "60"
  upstream-keepalive-requests: "10000"
  
  # 超时配置
  proxy-connect-timeout: "5"
  proxy-read-timeout: "60"
  proxy-send-timeout: "60"
  
  # 缓冲配置
  proxy-buffer-size: "128k"
  proxy-buffers-number: "4"
  client-body-buffer-size: "128k"
  client-header-buffer-size: "1k"
  large-client-header-buffers: "4 8k"
  
  # 压缩配置
  use-gzip: "true"
  gzip-level: "5"
  gzip-min-length: "256"
  gzip-types: "application/atom+xml application/javascript application/json application/rss+xml application/vnd.ms-fontobject application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/svg+xml image/x-icon text/css text/plain text/x-component"
  
  # HTTP/2配置
  use-http2: "true"
  http2-max-concurrent-streams: "128"
  http2-max-field-size: "4k"
  http2-max-header-size: "16k"
  
  # 负载均衡配置
  load-balance: "ewma"  # round_robin | least_conn | ip_hash | ewma
  
  # 日志优化
  access-log-buffered: "true"
  access-log-buffer-size: "16k"
  error-log-level: "error"
  
  # 安全与性能平衡
  ssl-session-cache: "true"
  ssl-session-cache-size: "10m"
  ssl-session-timeout: "10m"
  ssl-session-tickets: "true"
  
  # 连接限制
  limit-conn-zone-variable: "$binary_remote_addr"
  limit-req-zone-variable: "$binary_remote_addr"
```

### 6.2 资源配置优化

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  replicas: 3  # 高可用至少3副本
  template:
    spec:
      # 资源配置
      containers:
      - name: controller
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "2000m"
            memory: "2Gi"
        
        # 环境变量优化
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: LD_PRELOAD
          value: /usr/local/lib/libmimalloc.so  # 使用mimalloc提升性能
      
      # 调度策略
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app.kubernetes.io/name: ingress-nginx
            topologyKey: kubernetes.io/hostname
        
        # 优先调度到高性能节点
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: node.kubernetes.io/instance-type
                operator: In
                values:
                - ecs.g6.xlarge
                - ecs.g6.2xlarge
      
      # 优先级
      priorityClassName: system-cluster-critical
      
      # 容忍污点
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
```

### 6.3 HPA自动扩缩容

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ingress-nginx-hpa
  namespace: ingress-nginx
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ingress-nginx-controller
  
  minReplicas: 3
  maxReplicas: 20
  
  metrics:
  # CPU使用率
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  
  # 内存使用率
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
  
  # 自定义指标 - 每秒请求数
  - type: Pods
    pods:
      metric:
        name: nginx_ingress_controller_requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"
  
  # 扩缩容行为
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
      - type: Pods
        value: 5
        periodSeconds: 60
      selectPolicy: Max
    
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 120
      selectPolicy: Min
```

---

## 7. 监控与告警

### 7.1 关键监控指标

| 指标类别 | 指标名称 | 告警阈值 | 说明 |
|---------|---------|---------|------|
| **请求** | `nginx_ingress_controller_requests` | N/A | 请求总数 |
| **延迟** | `nginx_ingress_controller_request_duration_seconds` | P99>1s | 请求延迟 |
| **错误** | `nginx_ingress_controller_requests{status=~"5.."}` | >1% | 5xx错误率 |
| **连接** | `nginx_ingress_controller_nginx_process_connections` | >80% | 活跃连接数 |
| **上游** | `nginx_ingress_controller_upstream_latency_seconds` | P99>0.5s | 后端延迟 |
| **SSL** | `nginx_ingress_controller_ssl_certificate_expiry_time_seconds` | <7d | 证书过期 |

### 7.2 Prometheus告警规则

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: ingress-nginx-alerts
  namespace: monitoring
spec:
  groups:
  - name: ingress-nginx.rules
    rules:
    # 高错误率告警
    - alert: IngressHighErrorRate
      expr: |
        sum(rate(nginx_ingress_controller_requests{status=~"5.."}[5m])) by (ingress, namespace)
        / 
        sum(rate(nginx_ingress_controller_requests[5m])) by (ingress, namespace)
        > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Ingress错误率过高"
        description: "{{ $labels.namespace }}/{{ $labels.ingress }} 5xx错误率超过5%"
    
    # 高延迟告警
    - alert: IngressHighLatency
      expr: |
        histogram_quantile(0.99,
          sum(rate(nginx_ingress_controller_request_duration_seconds_bucket[5m])) by (le, ingress, namespace)
        ) > 2
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Ingress延迟过高"
        description: "{{ $labels.namespace }}/{{ $labels.ingress }} P99延迟超过2秒"
    
    # 证书即将过期
    - alert: IngressCertExpiringSoon
      expr: |
        nginx_ingress_controller_ssl_certificate_expiry_time_seconds - time() < 7 * 24 * 3600
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "SSL证书即将过期"
        description: "{{ $labels.host }} 的证书将在7天内过期"
    
    # 证书已过期
    - alert: IngressCertExpired
      expr: |
        nginx_ingress_controller_ssl_certificate_expiry_time_seconds - time() < 0
      for: 0m
      labels:
        severity: critical
      annotations:
        summary: "SSL证书已过期"
        description: "{{ $labels.host }} 的证书已过期"
    
    # Controller不可用
    - alert: IngressControllerDown
      expr: |
        up{job="ingress-nginx"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Ingress Controller不可用"
        description: "{{ $labels.instance }} Ingress Controller已下线"
    
    # 上游后端不可用
    - alert: IngressBackendUnavailable
      expr: |
        sum(nginx_ingress_controller_upstream_peers{state="down"}) by (upstream) > 0
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "Ingress后端不可用"
        description: "{{ $labels.upstream }} 有后端服务器不可用"
    
    # 连接数过高
    - alert: IngressHighConnections
      expr: |
        nginx_ingress_controller_nginx_process_connections{state="active"} > 50000
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Ingress连接数过高"
        description: "{{ $labels.instance }} 活跃连接数超过50000"
```

### 7.3 Grafana Dashboard

```json
{
  "dashboard": {
    "title": "Nginx Ingress Controller",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [{
          "expr": "sum(rate(nginx_ingress_controller_requests[5m])) by (ingress)",
          "legendFormat": "{{ ingress }}"
        }]
      },
      {
        "title": "Error Rate",
        "type": "graph",
        "targets": [{
          "expr": "sum(rate(nginx_ingress_controller_requests{status=~\"5..\"}[5m])) by (ingress) / sum(rate(nginx_ingress_controller_requests[5m])) by (ingress)",
          "legendFormat": "{{ ingress }}"
        }]
      },
      {
        "title": "P99 Latency",
        "type": "graph",
        "targets": [{
          "expr": "histogram_quantile(0.99, sum(rate(nginx_ingress_controller_request_duration_seconds_bucket[5m])) by (le, ingress))",
          "legendFormat": "{{ ingress }}"
        }]
      },
      {
        "title": "Active Connections",
        "type": "graph",
        "targets": [{
          "expr": "nginx_ingress_controller_nginx_process_connections{state=\"active\"}",
          "legendFormat": "{{ instance }}"
        }]
      }
    ]
  }
}
```

---

## 8. 故障排查手册

### 8.1 故障诊断流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Ingress 故障诊断流程                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Ingress无法访问?                                                        │
│      │                                                                  │
│      ├── 检查Ingress资源                                                 │
│      │   kubectl get ingress -n <namespace>                            │
│      │   kubectl describe ingress <name> -n <namespace>                │
│      │                                                                  │
│      ├── 检查Ingress Controller                                         │
│      │   kubectl get pods -n ingress-nginx                             │
│      │   kubectl logs -n ingress-nginx <controller-pod>                │
│      │                                                                  │
│      ├── 检查后端Service                                                 │
│      │   kubectl get svc <backend-service> -n <namespace>              │
│      │   kubectl get endpoints <backend-service> -n <namespace>        │
│      │                                                                  │
│      ├── 检查DNS解析                                                     │
│      │   nslookup <hostname>                                           │
│      │   dig <hostname>                                                │
│      │                                                                  │
│      ├── 检查LoadBalancer/NodePort                                      │
│      │   kubectl get svc -n ingress-nginx                              │
│      │   检查外部IP是否分配                                              │
│      │                                                                  │
│      └── 检查网络连通性                                                  │
│          curl -v http://<ingress-ip>                                   │
│          curl -v -H "Host: example.com" http://<ingress-ip>            │
│                                                                         │
│  SSL/TLS问题?                                                            │
│      │                                                                  │
│      ├── 检查证书Secret                                                  │
│      │   kubectl get secret <tls-secret> -n <namespace>                │
│      │   kubectl describe secret <tls-secret>                          │
│      │                                                                  │
│      ├── 验证证书内容                                                    │
│      │   kubectl get secret <secret> -o jsonpath='{.data.tls\.crt}' |  │
│      │   base64 -d | openssl x509 -text -noout                         │
│      │                                                                  │
│      └── 检查证书匹配                                                    │
│          openssl s_client -connect <host>:443 -servername <host>       │
│                                                                         │
│  502/504错误?                                                            │
│      │                                                                  │
│      ├── 后端Pod不健康                                                   │
│      │   kubectl get pods -l <selector> -n <namespace>                 │
│      │                                                                  │
│      ├── Service选择器不匹配                                             │
│      │   kubectl describe svc <service> -n <namespace>                 │
│      │                                                                  │
│      ├── 超时配置过短                                                    │
│      │   检查proxy-read-timeout等注解                                   │
│      │                                                                  │
│      └── 后端处理时间过长                                                │
│          检查应用性能                                                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 8.2 诊断命令集

```bash
#!/bin/bash
# Ingress诊断脚本

NAMESPACE=${1:-default}
INGRESS_NAME=$2

echo "=========================================="
echo "Ingress诊断报告"
echo "命名空间: $NAMESPACE"
echo "Ingress: $INGRESS_NAME"
echo "时间: $(date)"
echo "=========================================="

# 1. Ingress状态
echo -e "\n=== 1. Ingress状态 ==="
kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o wide

echo -e "\n=== 2. Ingress详情 ==="
kubectl describe ingress $INGRESS_NAME -n $NAMESPACE

# 3. TLS Secret
echo -e "\n=== 3. TLS Secret检查 ==="
TLS_SECRET=$(kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o jsonpath='{.spec.tls[0].secretName}')
if [ -n "$TLS_SECRET" ]; then
    kubectl get secret $TLS_SECRET -n $NAMESPACE
    echo "证书信息:"
    kubectl get secret $TLS_SECRET -n $NAMESPACE -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep -E "Subject:|Issuer:|Not Before:|Not After:"
fi

# 4. 后端Service
echo -e "\n=== 4. 后端Service检查 ==="
BACKENDS=$(kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o jsonpath='{.spec.rules[*].http.paths[*].backend.service.name}')
for svc in $BACKENDS; do
    echo "Service: $svc"
    kubectl get svc $svc -n $NAMESPACE -o wide
    kubectl get endpoints $svc -n $NAMESPACE
done

# 5. Ingress Controller
echo -e "\n=== 5. Ingress Controller状态 ==="
kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

echo -e "\n=== 6. Controller日志 (最近20行) ==="
CONTROLLER_POD=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}')
kubectl logs $CONTROLLER_POD -n ingress-nginx --tail=20

# 7. Nginx配置检查
echo -e "\n=== 7. Nginx配置检查 ==="
kubectl exec -n ingress-nginx $CONTROLLER_POD -- nginx -T 2>/dev/null | grep -A 20 "server_name.*$(kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o jsonpath='{.spec.rules[0].host}')"

# 8. 连通性测试
echo -e "\n=== 8. 连通性测试 ==="
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
HOST=$(kubectl get ingress $INGRESS_NAME -n $NAMESPACE -o jsonpath='{.spec.rules[0].host}')

if [ -n "$INGRESS_IP" ]; then
    echo "测试: curl -H 'Host: $HOST' http://$INGRESS_IP"
    curl -s -o /dev/null -w "HTTP状态码: %{http_code}\n" -H "Host: $HOST" "http://$INGRESS_IP" --connect-timeout 5
fi

echo -e "\n诊断完成"
```

### 8.3 常见故障解决

#### 8.3.1 404 Not Found

```bash
# 问题: 访问返回404

# 1. 检查Host头是否正确
curl -v -H "Host: api.example.com" http://<ingress-ip>/

# 2. 检查Ingress规则中的host是否匹配
kubectl get ingress <name> -o jsonpath='{.spec.rules[*].host}'

# 3. 检查path是否正确
kubectl get ingress <name> -o jsonpath='{.spec.rules[*].http.paths[*].path}'

# 4. 检查后端Service是否有Endpoints
kubectl get endpoints <service-name>

# 解决方案
# 确保Host头、path、Service配置正确匹配
```

#### 8.3.2 502 Bad Gateway

```bash
# 问题: 返回502错误

# 1. 检查后端Pod状态
kubectl get pods -l <selector> -o wide
kubectl describe pod <pod-name>

# 2. 检查Service的targetPort
kubectl get svc <service> -o jsonpath='{.spec.ports[*].targetPort}'
# 确保与Pod的containerPort匹配

# 3. 直接测试后端Pod
kubectl port-forward <pod-name> 8080:8080
curl http://localhost:8080/

# 4. 检查Controller日志
kubectl logs -n ingress-nginx <controller-pod> | grep "502"

# 解决方案
# - 修复后端Pod问题
# - 确保targetPort正确
# - 增加超时配置
```

#### 8.3.3 SSL证书问题

```bash
# 问题: SSL证书错误

# 1. 检查证书是否存在
kubectl get secret <tls-secret> -n <namespace>

# 2. 验证证书域名
kubectl get secret <tls-secret> -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -text | grep -A1 "Subject Alternative Name"

# 3. 检查证书是否过期
kubectl get secret <tls-secret> -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -dates

# 4. 验证证书链完整性
openssl s_client -connect <host>:443 -servername <host>

# 解决方案
# - 更新证书Secret
# - 确保证书域名匹配
# - 包含完整证书链
```

---

## 9. 安全加固配置

### 9.1 WAF配置 (ModSecurity)

```yaml
# 启用ModSecurity
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
data:
  enable-modsecurity: "true"
  enable-owasp-modsecurity-crs: "true"
  modsecurity-snippet: |
    SecRuleEngine On
    SecRequestBodyAccess On
    SecAuditEngine RelevantOnly
    SecAuditLogParts ABIJDEFHZ
    SecAuditLogType Serial
    SecAuditLog /var/log/modsecurity/audit.log
    
    # 自定义规则
    SecRule ARGS "@contains <script>" "id:1001,deny,status:403,msg:'XSS Attack Detected'"
    SecRule REQUEST_URI "@contains ../." "id:1002,deny,status:403,msg:'Path Traversal Detected'"
    
    # 排除特定路径
    SecRule REQUEST_URI "@beginsWith /api/upload" "id:1003,phase:1,nolog,pass,ctl:ruleRemoveById=200002"

---
# 特定Ingress启用WAF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  annotations:
    nginx.ingress.kubernetes.io/enable-modsecurity: "true"
    nginx.ingress.kubernetes.io/enable-owasp-core-rules: "true"
    nginx.ingress.kubernetes.io/modsecurity-transaction-id: "$request_id"
spec:
  # ...
```

### 9.2 访问控制

```yaml
# IP白名单
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whitelist-ingress
  annotations:
    nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,192.168.0.0/16,203.0.113.0/24"
spec:
  # ...

---
# Basic Auth认证
apiVersion: v1
kind: Secret
metadata:
  name: basic-auth
  namespace: production
type: Opaque
data:
  auth: YWRtaW46JGFwcjEkSDZVR2RVSVQJY3JOelVzVXRsYlVvdS5XUk0zbnkvLgo=
  # 生成方式: htpasswd -c auth admin && base64 auth

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: basic-auth-ingress
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
spec:
  # ...

---
# OAuth2代理认证
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: oauth-ingress
  annotations:
    nginx.ingress.kubernetes.io/auth-url: "https://oauth2-proxy.example.com/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://oauth2-proxy.example.com/oauth2/start?rd=$escaped_request_uri"
    nginx.ingress.kubernetes.io/auth-response-headers: "X-Auth-Request-User, X-Auth-Request-Email"
spec:
  # ...
```

### 9.3 安全头配置

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-headers-ingress
  annotations:
    # HSTS
    nginx.ingress.kubernetes.io/hsts: "true"
    nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
    nginx.ingress.kubernetes.io/hsts-include-subdomains: "true"
    nginx.ingress.kubernetes.io/hsts-preload: "true"
    
    # 安全头配置
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Frame-Options: SAMEORIGIN";
      more_set_headers "X-Content-Type-Options: nosniff";
      more_set_headers "X-XSS-Protection: 1; mode=block";
      more_set_headers "Referrer-Policy: strict-origin-when-cross-origin";
      more_set_headers "Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'";
      more_set_headers "Permissions-Policy: geolocation=(), microphone=(), camera=()";
spec:
  # ...
```

---

## 10. 实战案例演练

### 10.1 案例一：电商平台Ingress架构

```yaml
# 电商平台Ingress配置
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ecommerce-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://www.example.com"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - www.example.com
    - api.example.com
    - admin.example.com
    secretName: ecommerce-tls
  rules:
  # 主站
  - host: www.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-frontend
            port:
              number: 80
      - path: /static
        pathType: Prefix
        backend:
          service:
            name: static-cdn
            port:
              number: 80
  
  # API
  - host: api.example.com
    http:
      paths:
      - path: /v1
        pathType: Prefix
        backend:
          service:
            name: api-v1
            port:
              number: 80
      - path: /v2
        pathType: Prefix
        backend:
          service:
            name: api-v2
            port:
              number: 80
  
  # 管理后台
  - host: admin.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-panel
            port:
              number: 80

---
# 管理后台增加IP白名单
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: admin-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,203.0.113.50/32"
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: admin-auth
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - admin.example.com
    secretName: admin-tls
  rules:
  - host: admin.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-panel
            port:
              number: 80
```

### 10.2 案例二：微服务网关配置

```yaml
# 微服务网关Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: microservices-gateway
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "10"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "30"
    nginx.ingress.kubernetes.io/limit-rps: "100"
    nginx.ingress.kubernetes.io/limit-connections: "50"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - gateway.example.com
    secretName: gateway-tls
  rules:
  - host: gateway.example.com
    http:
      paths:
      # 用户服务
      - path: /user(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: user-service
            port:
              number: 80
      
      # 订单服务
      - path: /order(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: order-service
            port:
              number: 80
      
      # 商品服务
      - path: /product(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: product-service
            port:
              number: 80
      
      # 支付服务 (更长超时)
      - path: /payment(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: payment-service
            port:
              number: 80

---
# 支付服务特殊配置
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: payment-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "120"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "120"
    nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8"
spec:
  ingressClassName: nginx
  rules:
  - host: gateway.example.com
    http:
      paths:
      - path: /payment
        pathType: Prefix
        backend:
          service:
            name: payment-service
            port:
              number: 80
```

---

## 11. 总结与Q&A

### 11.1 核心要点回顾

| 主题 | 关键要点 |
|------|----------|
| **Controller选择** | Nginx(通用) / ALB(云原生) / Traefik(K8s原生) |
| **TLS管理** | cert-manager自动化 + Let's Encrypt |
| **流量管理** | 金丝雀(权重/Header) + 蓝绿(Service切换) |
| **性能优化** | 连接池 + Keep-alive + 压缩 + HTTP/2 |
| **安全加固** | WAF + IP白名单 + 安全头 + OAuth2 |

### 11.2 最佳实践清单

- [ ] 生产环境至少3副本Ingress Controller
- [ ] 使用cert-manager自动管理证书
- [ ] 配置合理的超时和缓冲参数
- [ ] 启用监控和告警
- [ ] 配置WAF防护
- [ ] 实施访问控制和安全头
- [ ] 定期检查证书有效期
- [ ] 测试金丝雀/蓝绿发布流程

### 11.3 常见问题解答

**Q: Nginx Ingress和云厂商ALB Ingress如何选择？**
A: 追求灵活性和定制化用Nginx；追求云原生和自动化用ALB。大多数场景Nginx足够。

**Q: 如何实现零停机部署？**
A: 使用金丝雀发布逐步切换流量，或蓝绿部署通过Service切换实现秒级切换。

**Q: Ingress Controller高可用如何保证？**
A: 多副本部署 + 反亲和性 + 跨AZ分布 + HPA自动扩缩容。

**Q: 证书更新会导致中断吗？**
A: cert-manager自动续期不会中断；手动更新Secret时Nginx会热重载，短暂影响。

---

## 阿里云ACK专属配置

### ACK Ingress配置

```yaml
# ACK Nginx Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ack-nginx-ingress
  annotations:
    # ACK特有注解
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    
    # 阿里云SLB配置
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-spec: "slb.s2.small"
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-address-type: "internet"
spec:
  # ...

---
# ACK ALB Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ack-alb-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/address-type: internet
    alb.ingress.kubernetes.io/vswitch-ids: "vsw-xxx,vsw-yyy"
    alb.ingress.kubernetes.io/slb-spec: "alb.s2.small"
spec:
  # ...
```

---

## 附录 A: 常用命令速查表

```bash
# Ingress 管理
kubectl get ingress -A -o wide
kubectl describe ingress <name> -n <namespace>
kubectl get ingress <name> -o yaml

# IngressClass 检查
kubectl get ingressclass
kubectl describe ingressclass <name>

# Ingress Controller 检查
kubectl get pods -n ingress-nginx -o wide
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100
kubectl exec -n ingress-nginx <pod> -- nginx -T  # 查看Nginx配置

# TLS 证书检查
kubectl get secrets -A | grep tls
kubectl describe secret <tls-secret> -n <namespace>
kubectl get secret <tls-secret> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# cert-manager 检查
kubectl get certificates -A
kubectl get certificaterequests -A
kubectl get orders -A
kubectl get challenges -A
kubectl describe certificate <name> -n <namespace>

# 连通性测试
curl -v -H "Host: example.com" http://<ingress-ip>/path
curl -v --resolve example.com:443:<ingress-ip> https://example.com/path

# Ingress Controller 指标
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 10254:10254
# 访问 http://localhost:10254/metrics
```

## 附录 B: 配置模板索引

| 模板名称 | 适用场景 | 章节位置 |
|----------|----------|----------|
| 基础 HTTP Ingress | 简单路由 | 3.1 节 |
| HTTPS TLS Ingress | 加密传输 | 4.1 节 |
| 多域名 Ingress | 多站点托管 | 3.2 节 |
| 路径重写配置 | URL 改写 | 3.3 节 |
| 金丝雀发布配置 | 灰度发布 | 5.1 节 |
| 蓝绿部署配置 | 零停机发布 | 5.2 节 |
| 限流配置 | 流量控制 | 6.1 节 |
| 认证配置 | Basic Auth/OAuth | 9.2 节 |
| WAF 配置 | 安全防护 | 9.3 节 |
| ACK ALB Ingress | 阿里云原生 | ACK专属配置 |

## 附录 C: 故障排查索引

| 故障现象 | 可能原因 | 排查方法 | 章节位置 |
|----------|----------|----------|----------|
| 503 Service Unavailable | 后端 Pod 不健康 | kubectl get endpoints | 8.1 节 |
| 404 Not Found | Ingress 规则不匹配 | 检查 path 配置 | 8.2 节 |
| 502 Bad Gateway | 后端服务端口错误 | 检查 Service 端口 | 8.2 节 |
| SSL 证书错误 | 证书过期/不匹配 | openssl 检查证书 | 8.3 节 |
| Ingress 无外部 IP | LB 创建失败 | 检查云控制器日志 | 8.4 节 |
| 金丝雀不生效 | 注解配置错误 | 检查 nginx annotations | 8.5 节 |
| 响应超时 | 后端处理慢 | 调整 proxy-read-timeout | 8.6 节 |

## 附录 D: 监控指标参考

| 指标名称 | 类型 | 说明 | 告警阈值 |
|----------|------|------|----------|
| `nginx_ingress_controller_requests` | Counter | 请求总数 | - |
| `nginx_ingress_controller_request_duration_seconds` | Histogram | 请求延迟 | P99 > 1s |
| `nginx_ingress_controller_response_size` | Histogram | 响应大小 | - |
| `nginx_ingress_controller_nginx_process_connections` | Gauge | 当前连接数 | > 80% 最大连接 |
| `nginx_ingress_controller_ssl_expire_time_seconds` | Gauge | 证书过期时间 | < 7天 |
| `nginx_ingress_controller_success` | Counter | 2xx/3xx 响应 | - |
| `nginx_ingress_controller_errors` | Counter | 4xx/5xx 响应 | 5xx > 1% |

## 附录 E: Nginx Ingress 常用注解

| 注解 | 说明 | 示例值 |
|------|------|--------|
| `nginx.ingress.kubernetes.io/rewrite-target` | URL 重写 | `/$2` |
| `nginx.ingress.kubernetes.io/ssl-redirect` | 强制 HTTPS | `"true"` |
| `nginx.ingress.kubernetes.io/proxy-body-size` | 请求体大小限制 | `"100m"` |
| `nginx.ingress.kubernetes.io/proxy-read-timeout` | 后端读取超时 | `"300"` |
| `nginx.ingress.kubernetes.io/limit-rps` | 请求限流 | `"100"` |
| `nginx.ingress.kubernetes.io/canary` | 金丝雀发布 | `"true"` |
| `nginx.ingress.kubernetes.io/canary-weight` | 金丝雀权重 | `"10"` |
| `nginx.ingress.kubernetes.io/whitelist-source-range` | IP 白名单 | `"10.0.0.0/8"` |

---

**文档版本**: v2.0  
**适用版本**: Kubernetes v1.26-v1.32  
**更新日期**: 2026年1月  
**作者**: Kusheet Project  
**联系方式**: Allen Galler (allengaller@gmail.com)

---

*全文完 - Kubernetes Ingress 流量入口生产环境运维培训*
