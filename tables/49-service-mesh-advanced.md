# 表格49: 服务网格进阶配置

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [istio.io/docs](https://istio.io/latest/docs/)

## Istio流量管理CRD

| CRD | 用途 | 版本 |
|----|------|------|
| VirtualService | 流量路由规则 | networking.istio.io/v1 |
| DestinationRule | 目标策略 | networking.istio.io/v1 |
| Gateway | 入口网关 | networking.istio.io/v1 |
| ServiceEntry | 外部服务注册 | networking.istio.io/v1 |
| Sidecar | Sidecar配置 | networking.istio.io/v1 |
| EnvoyFilter | Envoy扩展 | networking.istio.io/v1alpha3 |
| WorkloadEntry | 工作负载注册 | networking.istio.io/v1 |
| WorkloadGroup | 工作负载组 | networking.istio.io/v1 |

## VirtualService配置

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  # 基于Header路由
  - match:
    - headers:
        end-user:
          exact: jason
    route:
    - destination:
        host: reviews
        subset: v2
  # 流量分割
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 90
    - destination:
        host: reviews
        subset: v2
      weight: 10
    # 重试配置
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: gateway-error,connect-failure,refused-stream
    # 超时配置
    timeout: 10s
    # 故障注入
    fault:
      delay:
        percentage:
          value: 10
        fixedDelay: 5s
      abort:
        percentage:
          value: 5
        httpStatus: 503
```

## DestinationRule配置

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        h2UpgradePolicy: UPGRADE
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
    loadBalancer:
      simple: ROUND_ROBIN
      # 或一致性哈希
      # consistentHash:
      #   httpHeaderName: x-user-id
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
    trafficPolicy:
      connectionPool:
        http:
          http2MaxRequests: 500
```

## Gateway配置

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: myapp-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: myapp-tls
    hosts:
    - "myapp.example.com"
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "myapp.example.com"
    tls:
      httpsRedirect: true
```

## mTLS配置

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT  # STRICT/PERMISSIVE/DISABLE
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: httpbin
  namespace: default
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/sleep"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/info*"]
    when:
    - key: request.auth.claims[iss]
      values: ["https://example.com"]
```

## Istio可观测性配置

```yaml
# Telemetry API (v1.12+)
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: mesh-default
  namespace: istio-system
spec:
  accessLogging:
  - providers:
    - name: envoy
  tracing:
  - providers:
    - name: zipkin
    randomSamplingPercentage: 10
  metrics:
  - providers:
    - name: prometheus
```

## Cilium服务网格

| 特性 | 说明 |
|-----|------|
| 无Sidecar | 基于eBPF,无Sidecar开销 |
| L3/L4策略 | NetworkPolicy原生支持 |
| L7策略 | HTTP/gRPC/Kafka协议感知 |
| mTLS | 透明加密 |
| 服务地图 | Hubble可视化 |

```yaml
# Cilium L7 Policy
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: l7-policy
spec:
  endpointSelector:
    matchLabels:
      app: myapp
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      rules:
        http:
        - method: GET
          path: "/api/.*"
```

## Linkerd配置

```yaml
# ServiceProfile
apiVersion: linkerd.io/v1alpha2
kind: ServiceProfile
metadata:
  name: webapp.default.svc.cluster.local
  namespace: default
spec:
  routes:
  - name: GET /api/users
    condition:
      method: GET
      pathRegex: /api/users
    responseClasses:
    - condition:
        status:
          min: 500
          max: 599
      isFailure: true
  retryBudget:
    retryRatio: 0.2
    minRetriesPerSecond: 10
    ttl: 10s
```

## 服务网格性能对比

| 指标 | Istio+Envoy | Cilium | Linkerd |
|-----|-------------|--------|---------|
| 延迟增加 | 2-5ms | <1ms | 1-2ms |
| 内存开销 | 50-100MB/Pod | 共享 | 20-30MB/Pod |
| CPU开销 | 中等 | 低 | 低 |
| 功能丰富度 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

## ACK服务网格(ASM)

| 功能 | 说明 |
|-----|------|
| 托管控制平面 | 无需管理istiod |
| 多集群网格 | 跨集群服务发现 |
| 智能路由 | 基于AI的流量管理 |
| 可观测性 | ARMS集成 |
| 证书管理 | 自动证书轮换 |
