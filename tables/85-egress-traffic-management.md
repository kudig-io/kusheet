# 表格85: Egress流量管理

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/services-networking/network-policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

## Egress流量控制方案

| 方案 | 功能 | 复杂度 | 适用场景 |
|-----|------|-------|---------|
| NetworkPolicy | 基础出站控制 | 低 | L3/L4限制 |
| Egress Gateway | 统一出口IP | 中 | IP白名单 |
| NAT Gateway | 云原生NAT | 低 | 云环境 |
| Service Mesh | L7控制 | 高 | 精细控制 |

## NetworkPolicy Egress规则

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: egress-control
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  # 允许访问内部服务
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
  # 允许访问DNS
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
  # 允许访问特定外部IP
  - to:
    - ipBlock:
        cidr: 203.0.113.0/24
    ports:
    - protocol: TCP
      port: 443
```

## Cilium Egress Gateway

```yaml
# 启用Egress Gateway
apiVersion: v1
kind: ConfigMap
metadata:
  name: cilium-egress
data:
  values.yaml: |
    egressGateway:
      enabled: true
---
# 配置Egress策略
apiVersion: cilium.io/v2
kind: CiliumEgressGatewayPolicy
metadata:
  name: egress-external-api
spec:
  selectors:
  - podSelector:
      matchLabels:
        io.kubernetes.pod.namespace: production
        app: api-client
  destinationCIDRs:
  - "203.0.113.0/24"
  egressGateway:
    nodeSelector:
      matchLabels:
        egress-gateway: "true"
    egressIP: 10.0.0.100  # 固定出口IP
```

## Istio Egress Gateway

```yaml
# Egress Gateway部署
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: egress-gateway
  namespace: istio-system
spec:
  selector:
    istio: egressgateway
  servers:
  - port:
      number: 443
      name: tls
      protocol: TLS
    hosts:
    - api.external.com
    tls:
      mode: PASSTHROUGH
---
# VirtualService路由到Egress Gateway
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: external-api
spec:
  hosts:
  - api.external.com
  gateways:
  - mesh
  - egress-gateway
  tls:
  - match:
    - gateways:
      - mesh
      port: 443
      sniHosts:
      - api.external.com
    route:
    - destination:
        host: istio-egressgateway.istio-system.svc.cluster.local
        port:
          number: 443
  - match:
    - gateways:
      - egress-gateway
      port: 443
      sniHosts:
      - api.external.com
    route:
    - destination:
        host: api.external.com
        port:
          number: 443
---
# ServiceEntry定义外部服务
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: external-api
spec:
  hosts:
  - api.external.com
  ports:
  - number: 443
    name: https
    protocol: TLS
  resolution: DNS
  location: MESH_EXTERNAL
```

## ACK NAT Gateway

```yaml
# 使用NAT网关注解
apiVersion: v1
kind: Pod
metadata:
  name: nat-enabled
  annotations:
    k8s.aliyun.com/pod-eip: "true"
    k8s.aliyun.com/eip-bindingtype: "NAT"
spec:
  containers:
  - name: app
    image: myapp
```

## Egress IP固定

```yaml
# Calico Egress IP
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  serviceClusterIPs:
  - cidr: 10.96.0.0/12
  serviceExternalIPs:
  - cidr: 203.0.113.0/24
```

## 外部服务访问控制

```yaml
# Istio ServiceEntry白名单
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: allowed-external
spec:
  hosts:
  - "*.googleapis.com"
  - "api.github.com"
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  resolution: DNS
  location: MESH_EXTERNAL
---
# 阻止未定义的外部访问
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-external
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: egressgateway
  action: DENY
  rules:
  - to:
    - operation:
        hosts:
        - "*.example.com"  # 阻止访问
```

## Egress监控

| 指标 | 类型 | 说明 |
|-----|-----|------|
| `istio_tcp_sent_bytes_total` | Counter | 出站字节数 |
| `cilium_forward_bytes_total` | Counter | 转发字节数 |
| `egress_requests_total` | Counter | 出站请求数 |
| `egress_errors_total` | Counter | 出站错误数 |

## Egress故障排查

```bash
# 检查出站连接
kubectl exec <pod> -- curl -v https://api.external.com

# 检查NetworkPolicy
kubectl get networkpolicy -o yaml

# 检查Cilium Egress
cilium bpf egress list
cilium policy get

# 检查Istio路由
istioctl proxy-config routes <egress-gateway-pod>
```

## ACK出站方案

| 方案 | 说明 |
|-----|------|
| NAT网关 | VPC出口 |
| SNAT | Pod共享出口IP |
| EIP | Pod独立公网IP |
| Terway Trunk | 弹性网卡 |

## 最佳实践

| 实践 | 说明 |
|-----|------|
| 最小权限 | 仅允许必要外部访问 |
| 审计日志 | 记录所有出站流量 |
| 固定IP | 便于外部防火墙配置 |
| L7控制 | URL级别访问控制 |
| 监控告警 | 异常流量检测 |
