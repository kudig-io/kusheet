# 表格20：服务网格集成表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [istio.io/latest/docs](https://istio.io/latest/docs/) | [linkerd.io/docs](https://linkerd.io/docs/)

## 服务网格对比

| 特性 | Istio | Linkerd | Cilium SM | Consul Connect |
|-----|-------|---------|-----------|---------------|
| **架构** | Envoy Sidecar | Rust Sidecar | eBPF无Sidecar | Envoy Sidecar |
| **资源开销** | 高 | 低 | 很低 | 中 |
| **学习曲线** | 陡峭 | 平缓 | 中等 | 中等 |
| **功能丰富度** | 最全面 | 核心功能 | 核心功能 | 全面 |
| **mTLS** | 自动 | 自动 | 自动 | 自动 |
| **流量管理** | 强大 | 基本 | 基本 | 强大 |
| **可观测性** | 全面 | 好 | 好 | 好 |
| **K8S版本** | v1.25+ | v1.25+ | v1.25+ | v1.25+ |
| **ACK集成** | ASM托管 | 手动 | 手动 | 手动 |

## Istio核心组件

| 组件 | 功能 | 部署方式 | 版本要求 |
|-----|------|---------|---------|
| **istiod** | 控制平面(Pilot+Citadel+Galley合并) | Deployment | v1.5+ |
| **Envoy** | 数据平面代理 | Sidecar注入 | 自动 |
| **Ingress Gateway** | 入口网关 | Deployment | 可选 |
| **Egress Gateway** | 出口网关 | Deployment | 可选 |

## Istio安装

```bash
# 使用istioctl安装
istioctl install --set profile=demo -y

# 启用Sidecar注入
kubectl label namespace default istio-injection=enabled

# 验证安装
kubectl get pods -n istio-system
istioctl analyze
```

```yaml
# IstioOperator配置
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-control-plane
spec:
  profile: default
  components:
    pilot:
      k8s:
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        service:
          type: LoadBalancer
  meshConfig:
    accessLogFile: /dev/stdout
    enableTracing: true
    defaultConfig:
      tracing:
        sampling: 100
```

## 流量管理

```yaml
# VirtualService - 路由规则
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - match:
    - headers:
        end-user:
          exact: jason
    route:
    - destination:
        host: reviews
        subset: v2
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 90
    - destination:
        host: reviews
        subset: v2
      weight: 10
---
# DestinationRule - 目标规则
apiVersion: networking.istio.io/v1beta1
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
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

## 安全配置(mTLS)

```yaml
# PeerAuthentication - 强制mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
---
# AuthorizationPolicy - 授权策略
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: frontend-ingress
  namespace: production
spec:
  selector:
    matchLabels:
      app: frontend
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/production/sa/api-gateway"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]
```

## 可观测性配置

```yaml
# Telemetry配置
apiVersion: telemetry.istio.io/v1alpha1
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
    - name: jaeger
    randomSamplingPercentage: 10
  metrics:
  - providers:
    - name: prometheus
```

## Linkerd安装

```bash
# 安装CLI
curl -sL https://run.linkerd.io/install | sh

# 检查环境
linkerd check --pre

# 安装控制平面
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -

# 检查安装
linkerd check

# 注入Sidecar
kubectl get deploy -o yaml | linkerd inject - | kubectl apply -f -

# 或自动注入
kubectl annotate namespace default linkerd.io/inject=enabled
```

## Linkerd流量管理

```yaml
# ServiceProfile - 路由配置
apiVersion: linkerd.io/v1alpha2
kind: ServiceProfile
metadata:
  name: webapp.production.svc.cluster.local
  namespace: production
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
---
# TrafficSplit - 金丝雀发布
apiVersion: split.smi-spec.io/v1alpha1
kind: TrafficSplit
metadata:
  name: webapp-split
  namespace: production
spec:
  service: webapp
  backends:
  - service: webapp-stable
    weight: 900m
  - service: webapp-canary
    weight: 100m
```

## 服务网格流量模式

| 模式 | 描述 | 用途 | 配置资源 |
|-----|------|------|---------|
| **蓝绿部署** | 100%流量切换 | 版本切换 | VirtualService |
| **金丝雀发布** | 逐步流量迁移 | 渐进式发布 | VirtualService/TrafficSplit |
| **A/B测试** | 基于特征路由 | 功能测试 | VirtualService+match |
| **镜像流量** | 复制流量到另一服务 | 测试生产流量 | VirtualService+mirror |
| **故障注入** | 人为注入延迟/错误 | 混沌测试 | VirtualService+fault |
| **熔断** | 异常服务隔离 | 故障保护 | DestinationRule |
| **限流** | 请求速率限制 | 保护服务 | EnvoyFilter |

## 服务网格监控

| 指标类型 | Istio | Linkerd | 采集方式 |
|---------|-------|---------|---------|
| **请求量** | istio_requests_total | request_total | Prometheus |
| **延迟** | istio_request_duration | response_latency | Prometheus |
| **错误率** | 5xx/总请求 | 失败/总请求 | 计算 |
| **连接数** | istio_tcp_connections_opened_total | tcp_open_total | Prometheus |

## ACK服务网格(ASM)

| 功能 | ASM | 自建Istio |
|-----|-----|----------|
| **控制平面** | 托管 | 自行维护 |
| **升级** | 自动 | 手动 |
| **多集群** | 原生支持 | 配置复杂 |
| **监控** | ARMS集成 | 自行配置 |
| **日志** | SLS集成 | 自行配置 |
| **成本** | 按实例计费 | 资源成本 |

```bash
# ASM网格创建
aliyun servicemesh CreateServiceMesh \
  --RegionId cn-hangzhou \
  --MeshType standard \
  --VSwitches vsw-xxx

# 添加集群到网格
aliyun servicemesh AddClusterIntoServiceMesh \
  --ServiceMeshId xxx \
  --ClusterId ack-xxx
```

## 服务网格故障排查

```bash
# Istio诊断
istioctl analyze
istioctl proxy-status
istioctl proxy-config cluster <pod> -n <ns>
istioctl proxy-config route <pod> -n <ns>

# 查看Envoy日志
kubectl logs <pod> -c istio-proxy

# Linkerd诊断
linkerd check
linkerd stat deploy -n <ns>
linkerd tap deploy/<name> -n <ns>

# 查看代理配置
linkerd diagnostics proxy-metrics -n <ns> <pod>
```

## 服务网格最佳实践

| 实践 | 说明 | 优先级 |
|-----|------|-------|
| **渐进式采用** | 先在非关键服务启用 | P0 |
| **资源预留** | Sidecar资源规划 | P0 |
| **mTLS强制** | STRICT模式 | P1 |
| **可观测性** | 采样率配置 | P1 |
| **超时重试** | 合理配置 | P1 |
| **熔断配置** | 防止级联故障 | P1 |

---

**服务网格原则**: 渐进采用，监控先行，安全默认
