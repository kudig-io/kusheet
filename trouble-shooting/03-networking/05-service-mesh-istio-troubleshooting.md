# Service Mesh (Istio) 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32, Istio v1.18 - v1.24 | **最后更新**: 2026-01 | **难度**: 高级
>
> **版本说明**:
> - Istio v1.18+ 推荐 Ambient Mesh (无 sidecar 模式)
> - Istio v1.20+ Gateway API 支持 GA
> - Istio v1.22+ 支持 K8s v1.30+ 的 SidecarContainers 特性

---

## 第一部分：问题现象与影响分析

### 1.1 Istio 架构

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         Istio Control Plane                              │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌────────────────────────────────────────────────────────────────┐    │
│   │                          istiod                                 │    │
│   │  ┌────────────┐  ┌────────────┐  ┌────────────┐               │    │
│   │  │   Pilot    │  │   Citadel  │  │   Galley   │               │    │
│   │  │ (Config    │  │ (证书管理) │  │ (配置验证) │               │    │
│   │  │  Distribution)│            │  │            │               │    │
│   │  └────────────┘  └────────────┘  └────────────┘               │    │
│   └────────────────────────────────────────────────────────────────┘    │
│                                   │                                      │
│                            xDS Protocol                                  │
│                     (LDS, RDS, CDS, EDS, SDS)                           │
│                                   │                                      │
└───────────────────────────────────┼──────────────────────────────────────┘
                                    │
┌───────────────────────────────────┼──────────────────────────────────────┐
│                    Data Plane (Sidecar Proxies)                          │
├───────────────────────────────────┼──────────────────────────────────────┤
│                                   │                                      │
│   ┌─────────────────────┐   ┌─────┴───────────────┐                     │
│   │      Pod A          │   │      Pod B          │                     │
│   │  ┌──────────────┐   │   │  ┌──────────────┐   │                     │
│   │  │   App        │   │   │  │   App        │   │                     │
│   │  │   Container  │   │   │  │   Container  │   │                     │
│   │  └──────┬───────┘   │   │  └──────┬───────┘   │                     │
│   │         │           │   │         │           │                     │
│   │  ┌──────┴───────┐   │   │  ┌──────┴───────┐   │                     │
│   │  │   Envoy      │   │   │  │   Envoy      │   │                     │
│   │  │   Sidecar    │◄──┼───┼──►   Sidecar    │   │                     │
│   │  │   Proxy      │   │   │  │   Proxy      │   │                     │
│   │  └──────────────┘   │   │  └──────────────┘   │                     │
│   └─────────────────────┘   └─────────────────────┘                     │
│                                                                          │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                    Ingress Gateway                                │  │
│   │  ┌─────────────────────────────────────────────────────────┐    │  │
│   │  │   Envoy Proxy (接收外部流量)                            │    │  │
│   │  │   - VirtualService 路由                                 │    │  │
│   │  │   - Gateway 配置                                        │    │  │
│   │  └─────────────────────────────────────────────────────────┘    │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

流量路径:
                                                    
  外部流量    Ingress Gateway    Sidecar A    Sidecar B    目标服务
     │              │               │             │            │
     │─── HTTPS ───>│               │             │            │
     │              │── mTLS ──────>│             │            │
     │              │               │── mTLS ────>│            │
     │              │               │             │── local ──>│
     │              │               │             │            │
     │              │               │<── mTLS ────│            │
     │              │<── mTLS ──────│             │            │
     │<── HTTPS ────│               │             │            │
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 错误信息 | 查看方式 |
|----------|----------|----------|----------|
| Sidecar 注入失败 | Pod 只有应用容器无 istio-proxy | 无 | `kubectl get pod -o yaml` |
| 503 Service Unavailable | 服务间调用返回 503 | upstream connect error | 应用日志/Envoy 日志 |
| 证书问题 | mTLS 握手失败 | TLS error | istio-proxy 日志 |
| 配置不同步 | VirtualService 不生效 | config not found | `istioctl proxy-config` |
| Gateway 不工作 | 外部无法访问服务 | connection refused | `curl` 测试 |
| 高延迟 | 服务响应变慢 | timeout | Prometheus metrics |
| 内存/CPU 过高 | Sidecar 资源占用异常 | OOMKilled | `kubectl top` |
| Mixer 遥测问题 | 指标/日志丢失 | N/A | Prometheus/Jaeger |

### 1.3 影响分析

| 问题类型 | 直接影响 | 间接影响 | 影响范围 |
|----------|----------|----------|----------|
| istiod 故障 | 配置无法下发 | 新配置不生效，但现有流量不受影响 | 整个 mesh |
| Sidecar 注入失败 | 流量不经过 mesh | 无法使用 Istio 功能 | 特定 Pod |
| mTLS 问题 | 服务间通信失败 | 业务中断 | 通信双方 |
| Gateway 故障 | 外部流量无法进入 | 服务对外不可用 | 所有入站流量 |
| 配置错误 | 流量路由异常 | 请求到达错误目标 | 受影响的服务 |

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
Istio 问题
    │
    ▼
┌───────────────────────┐
│  问题类型是什么？      │
└───────────────────────┘
    │
    ├── 服务间通信失败 ────────────────────────────────────┐
    │                                                       │
    │   ┌─────────────────────────────────────────┐        │
    │   │ curl 测试返回什么错误?                  │        │
    │   └─────────────────────────────────────────┘        │
    │          │                                            │
    │          ▼                                            │
    │   ┌─────────────────────────────────────────┐        │
    │   │ "503 Service Unavailable"?              │        │
    │   └─────────────────────────────────────────┘        │
    │      │                │                               │
    │     是               否 (404/Connection refused)      │
    │      │                │                               │
    │      ▼                ▼                               │
    │   ┌───────────┐   ┌────────────────┐                 │
    │   │ 检查上游  │   │ 检查 Service   │                 │
    │   │ Endpoint  │   │ 或 VirtualService│                │
    │   │ 和 mTLS   │   │ 配置           │                 │
    │   └───────────┘   └────────────────┘                 │
    │                                                       │
    ├── Sidecar 问题 ──────────────────────────────────────┤
    │                                                       │
    │   ┌─────────────────────────────────────────┐        │
    │   │ Pod 有 istio-proxy 容器吗?              │        │
    │   │ kubectl get pod <pod> -o yaml           │        │
    │   └─────────────────────────────────────────┘        │
    │      │                │                               │
    │     否               是                               │
    │      │                │                               │
    │      ▼                ▼                               │
    │   ┌───────────┐   ┌────────────────┐                 │
    │   │ 检查注入  │   │ istio-proxy    │                 │
    │   │ 配置和    │   │ 容器状态       │                 │
    │   │ 标签      │   │ 是否正常？     │                 │
    │   └───────────┘   └────────────────┘                 │
    │                          │                            │
    │                          ▼                            │
    │                   ┌────────────────┐                 │
    │                   │ 检查 proxy     │                 │
    │                   │ 日志和配置     │                 │
    │                   └────────────────┘                 │
    │                                                       │
    ├── Ingress Gateway 问题 ──────────────────────────────┤
    │                                                       │
    │   ┌─────────────────────────────────────────┐        │
    │   │ Gateway Pod 运行正常?                   │        │
    │   │ kubectl get pods -n istio-system        │        │
    │   └─────────────────────────────────────────┘        │
    │      │                │                               │
    │     否               是                               │
    │      │                │                               │
    │      ▼                ▼                               │
    │   ┌───────────┐   ┌────────────────┐                 │
    │   │ 检查 Pod  │   │ 检查 Gateway   │                 │
    │   │ 事件/日志 │   │ + VirtualService│                │
    │   └───────────┘   │ 配置           │                 │
    │                   └────────────────┘                 │
    │                                                       │
    └── istiod 控制面问题 ─────────────────────────────────┤
                                                            │
        ┌─────────────────────────────────────────┐        │
        │ istiod Pod 运行正常?                    │        │
        │ kubectl get pods -n istio-system        │        │
        └─────────────────────────────────────────┘        │
               │                │                           │
              否               是                           │
               │                │                           │
               ▼                ▼                           │
        ┌───────────┐   ┌────────────────┐                 │
        │ 检查 Pod  │   │ 检查配置同步   │                 │
        │ 启动问题  │   │ istioctl ps    │                 │
        └───────────┘   └────────────────┘                 │
                                                            │
                                                            ▼
                                                     ┌────────────┐
                                                     │ 问题定位   │
                                                     │ 完成       │
                                                     └────────────┘
```

### 2.2 排查命令集

#### istioctl 诊断命令

```bash
# 检查 mesh 整体状态
istioctl version
istioctl verify-install

# 分析配置问题
istioctl analyze -A
istioctl analyze -n <namespace>

# 检查代理同步状态
istioctl proxy-status
istioctl ps  # 简写

# 查看特定 Pod 的 Envoy 配置
istioctl proxy-config cluster <pod-name>.<namespace>
istioctl proxy-config listener <pod-name>.<namespace>
istioctl proxy-config route <pod-name>.<namespace>
istioctl proxy-config endpoint <pod-name>.<namespace>
istioctl proxy-config secret <pod-name>.<namespace>

# 检查服务网格的入口
istioctl proxy-config listener istio-ingressgateway-xxx.istio-system

# 验证目标规则和虚拟服务
istioctl experimental describe pod <pod-name>
istioctl experimental describe service <svc-name>
```

#### Sidecar 和 Envoy 检查

```bash
# 检查 Pod 是否有 sidecar
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].name}'

# 查看 istio-proxy 日志
kubectl logs <pod-name> -c istio-proxy
kubectl logs <pod-name> -c istio-proxy --tail=100 -f

# 进入 istio-proxy 容器
kubectl exec -it <pod-name> -c istio-proxy -- /bin/bash

# 在容器内检查 Envoy
# 查看 Envoy 版本
pilot-agent version

# 查看 Envoy 管理接口
curl localhost:15000/help
curl localhost:15000/config_dump
curl localhost:15000/clusters
curl localhost:15000/stats

# 检查 Envoy 健康状态
curl localhost:15021/healthz/ready

# 查看证书
curl localhost:15000/certs
```

#### 控制面检查

```bash
# 检查 istiod
kubectl get pods -n istio-system -l app=istiod
kubectl logs -n istio-system -l app=istiod --tail=100

# 检查 istiod 的配置推送
kubectl logs -n istio-system -l app=istiod | grep -i "push\|error"

# 检查 Ingress Gateway
kubectl get pods -n istio-system -l app=istio-ingressgateway
kubectl logs -n istio-system -l app=istio-ingressgateway

# 检查 Gateway Service
kubectl get svc -n istio-system istio-ingressgateway
```

#### Istio 资源检查

```bash
# 列出所有 Istio 资源
kubectl get gateway,virtualservice,destinationrule,serviceentry,envoyfilter -A

# 检查特定资源
kubectl describe virtualservice <name> -n <namespace>
kubectl describe destinationrule <name> -n <namespace>
kubectl describe gateway <name> -n <namespace>

# 检查 PeerAuthentication (mTLS)
kubectl get peerauthentication -A
kubectl describe peerauthentication <name> -n <namespace>

# 检查 AuthorizationPolicy
kubectl get authorizationpolicy -A
kubectl describe authorizationpolicy <name> -n <namespace>
```

### 2.3 排查注意事项

| 注意事项 | 说明 | 风险等级 |
|----------|------|----------|
| 配置变更需要时间同步 | 新配置需要几秒到几十秒同步到所有 proxy | 低 |
| 修改全局 mTLS 需谨慎 | 可能导致服务间通信中断 | 高 |
| EnvoyFilter 影响面广 | 自定义 Envoy 配置可能影响意外的流量 | 高 |
| Sidecar 注入需要重启 Pod | 修改注入配置后需要重启 Pod 才能生效 | 中 |
| Gateway 配置需要匹配 | Gateway 和 VirtualService 的 hosts 必须匹配 | 中 |

## 第三部分：解决方案与风险控制

### 3.1 Sidecar 注入失败

**问题现象**：Pod 没有 `istio-proxy` 容器，流量不经过 mesh。

**解决步骤**：

```bash
# 步骤 1: 检查 namespace 标签
kubectl get namespace <namespace> -o jsonpath='{.metadata.labels}'
# 应该有 istio-injection=enabled

# 如果没有，添加标签
kubectl label namespace <namespace> istio-injection=enabled

# 步骤 2: 检查是否有排除注入的 annotation
kubectl get pod <pod-name> -o jsonpath='{.metadata.annotations}'
# 检查是否有 sidecar.istio.io/inject: "false"

# 步骤 3: 检查 istio-sidecar-injector 是否正常
kubectl get mutatingwebhookconfiguration istio-sidecar-injector
kubectl get pods -n istio-system -l app=istiod

# 步骤 4: 重启 Pod 使注入生效
kubectl rollout restart deployment <deployment-name> -n <namespace>

# 步骤 5: 验证注入成功
kubectl get pod <new-pod-name> -o jsonpath='{.spec.containers[*].name}'
# 应该看到 istio-proxy 容器
```

**手动注入 Sidecar**：

```bash
# 如果自动注入不工作，可以手动注入
kubectl get deployment <name> -n <namespace> -o yaml | \
  istioctl kube-inject -f - | \
  kubectl apply -f -
```

### 3.2 503 Service Unavailable

**问题现象**：服务间调用返回 503，Envoy 日志显示 `upstream connect error`。

**解决步骤**：

```bash
# 步骤 1: 检查目标服务的 Endpoint
kubectl get endpoints <service-name> -n <namespace>

# 步骤 2: 检查 Envoy 是否能看到上游
kubectl exec <source-pod> -c istio-proxy -- curl localhost:15000/clusters | grep <dest-service>

# 步骤 3: 检查 mTLS 配置是否匹配
# 查看源端的 DestinationRule
kubectl get destinationrule -A | grep <dest-service>

# 查看目标端的 PeerAuthentication
kubectl get peerauthentication -n <dest-namespace>

# 步骤 4: 如果 mTLS 不匹配，修复配置
# 例如：目标要求 STRICT mTLS，但源端没有配置
```

**mTLS 配置示例**：

```yaml
# PeerAuthentication - 设置服务接受的认证方式
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: my-namespace
spec:
  mtls:
    mode: STRICT  # STRICT, PERMISSIVE, DISABLE

---
# DestinationRule - 设置访问服务时使用的 TLS 模式
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-service-dr
  namespace: my-namespace
spec:
  host: my-service.my-namespace.svc.cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL  # ISTIO_MUTUAL, MUTUAL, SIMPLE, DISABLE
```

```bash
# 步骤 5: 检查目标 Pod 是否健康
kubectl get pods -n <dest-namespace> -l app=<dest-app>
kubectl logs <dest-pod> -c <app-container>

# 步骤 6: 查看详细的 Envoy 日志
kubectl logs <source-pod> -c istio-proxy | grep -i "upstream\|503"
```

### 3.3 VirtualService 路由不生效

**问题现象**：配置的路由规则不生效，流量没有按预期转发。

**解决步骤**：

```bash
# 步骤 1: 检查 VirtualService 是否正确应用
kubectl get virtualservice -n <namespace>
istioctl analyze -n <namespace>

# 步骤 2: 检查配置是否同步到 Proxy
istioctl proxy-config route <pod-name>.<namespace> | grep <service-name>

# 步骤 3: 验证 VirtualService 的 hosts 是否匹配
kubectl get virtualservice <name> -o yaml | grep -A10 "hosts:"

# 步骤 4: 检查是否有冲突的配置
kubectl get virtualservice -A -o yaml | grep -B5 -A10 "<service-name>"

# 步骤 5: 检查 DestinationRule subset 是否存在
kubectl get destinationrule <name> -o yaml | grep -A20 "subsets:"
```

**常见配置错误**：

```yaml
# 错误示例 1: hosts 不匹配
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-vs
spec:
  hosts:
  - my-service  # 应该是完整 FQDN 或短名称必须在同一 namespace
  # ...

# 正确写法
spec:
  hosts:
  - my-service.my-namespace.svc.cluster.local
  # 或者如果 VirtualService 和 Service 在同一 namespace
  - my-service

---
# 错误示例 2: subset 未在 DestinationRule 中定义
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  http:
  - route:
    - destination:
        host: my-service
        subset: v2  # 必须在 DestinationRule 中定义

---
# 对应的 DestinationRule
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-service-dr
spec:
  host: my-service
  subsets:
  - name: v2  # 必须定义
    labels:
      version: v2
```

### 3.4 Ingress Gateway 无法访问

**问题现象**：外部流量无法通过 Gateway 访问服务。

**解决步骤**：

```bash
# 步骤 1: 确认 Gateway Pod 和 Service 正常
kubectl get pods -n istio-system -l app=istio-ingressgateway
kubectl get svc -n istio-system istio-ingressgateway

# 获取 Gateway 外部 IP
export INGRESS_HOST=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')

# 步骤 2: 检查 Gateway 资源配置
kubectl get gateway -A
kubectl describe gateway <gateway-name> -n <namespace>

# 步骤 3: 检查 VirtualService 是否绑定到 Gateway
kubectl get virtualservice <vs-name> -o yaml | grep -A5 "gateways:"

# 步骤 4: 验证 hosts 匹配
# Gateway 和 VirtualService 的 hosts 必须有交集

# 步骤 5: 检查 Gateway 的 Envoy 配置
istioctl proxy-config listener istio-ingressgateway-xxx.istio-system
istioctl proxy-config route istio-ingressgateway-xxx.istio-system

# 步骤 6: 测试连接
curl -v http://$INGRESS_HOST:$INGRESS_PORT/path -H "Host: your-host.example.com"
```

**Gateway 配置示例**：

```yaml
# Gateway
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: my-gateway
  namespace: istio-system  # Gateway 通常在 istio-system
spec:
  selector:
    istio: ingressgateway  # 匹配 Ingress Gateway Pod 标签
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*.example.com"  # hosts 必须与 VirtualService 匹配

---
# VirtualService
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-vs
  namespace: my-namespace
spec:
  hosts:
  - "app.example.com"  # 必须与 Gateway hosts 匹配
  gateways:
  - istio-system/my-gateway  # 引用 Gateway (namespace/name)
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: my-service
        port:
          number: 80
```

### 3.5 mTLS 证书问题

**问题现象**：TLS 握手失败，服务间通信报证书错误。

**解决步骤**：

```bash
# 步骤 1: 检查证书状态
istioctl proxy-config secret <pod-name>.<namespace>

# 步骤 2: 检查证书是否过期
kubectl exec <pod> -c istio-proxy -- curl localhost:15000/certs | jq '.certificates'

# 步骤 3: 检查 istiod 证书签发
kubectl logs -n istio-system -l app=istiod | grep -i "cert\|error"

# 步骤 4: 检查 PeerAuthentication 配置
kubectl get peerauthentication -A -o yaml

# 步骤 5: 如果需要，重新触发证书轮换
# 方法 1: 重启 Pod
kubectl rollout restart deployment <name> -n <namespace>

# 方法 2: 重启 istiod (影响更大)
kubectl rollout restart deployment istiod -n istio-system
```

### 3.6 配置同步问题

**问题现象**：配置已应用但不生效，`istioctl analyze` 无警告。

**解决步骤**：

```bash
# 步骤 1: 检查 proxy 同步状态
istioctl proxy-status

# 输出说明:
# SYNCED - 配置已同步
# NOT SENT - 配置未发送
# STALE - 配置过时

# 步骤 2: 如果显示 STALE 或 NOT SENT
# 检查 istiod 日志
kubectl logs -n istio-system -l app=istiod | grep -i "error\|push"

# 步骤 3: 手动触发同步
# 重启 istiod
kubectl rollout restart deployment istiod -n istio-system

# 或者重启特定 Pod 的 sidecar
kubectl delete pod <pod-name> -n <namespace>

# 步骤 4: 验证配置已同步
istioctl proxy-config listener <pod-name>.<namespace> -o json | jq '.'
```

### 3.7 Envoy Sidecar 资源问题

**问题现象**：istio-proxy 容器 CPU/内存过高或 OOMKilled。

**解决步骤**：

```bash
# 步骤 1: 检查资源使用
kubectl top pod <pod-name>
kubectl describe pod <pod-name> | grep -A10 "istio-proxy"

# 步骤 2: 检查 Envoy 统计信息
kubectl exec <pod> -c istio-proxy -- curl localhost:15000/stats | grep -E "memory|cx_total"

# 步骤 3: 调整 sidecar 资源限制
# 方法 1: 全局配置 (ConfigMap)
kubectl edit configmap istio-sidecar-injector -n istio-system
# 修改 values.global.proxy.resources

# 方法 2: 针对特定 Pod (annotation)
```

**Pod 级别资源配置**：

```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    # 自定义 sidecar 资源
    sidecar.istio.io/proxyCPU: "100m"
    sidecar.istio.io/proxyCPULimit: "2000m"
    sidecar.istio.io/proxyMemory: "128Mi"
    sidecar.istio.io/proxyMemoryLimit: "1024Mi"
spec:
  containers:
  - name: my-app
    # ...
```

```bash
# 步骤 4: 减少 Envoy 配置量 (如果配置过多)
# 使用 Sidecar 资源限制配置范围
```

**Sidecar 资源限制范围**：

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: my-namespace
spec:
  egress:
  - hosts:
    - "./*"  # 只看到本 namespace 的服务
    - "istio-system/*"  # 和 istio-system 的服务
  # 而不是全 mesh 的所有服务
```

### 3.8 调试流量问题

**问题现象**：需要详细了解流量路径和问题原因。

**调试方法**：

```bash
# 方法 1: 启用 Envoy 详细日志
kubectl exec <pod> -c istio-proxy -- curl -X POST localhost:15000/logging?level=debug

# 查看调试日志
kubectl logs <pod> -c istio-proxy -f

# 完成后恢复日志级别
kubectl exec <pod> -c istio-proxy -- curl -X POST localhost:15000/logging?level=warning

# 方法 2: 使用 istioctl 调试
istioctl experimental describe pod <pod-name>

# 方法 3: 检查 Envoy config dump
kubectl exec <pod> -c istio-proxy -- curl localhost:15000/config_dump > config_dump.json

# 方法 4: 使用 Kiali 可视化
# 访问 Kiali dashboard 查看流量图
kubectl port-forward svc/kiali -n istio-system 20001:20001
```

### 3.9 AuthorizationPolicy 问题

**问题现象**：请求被拒绝，返回 403 RBAC 错误。

**解决步骤**：

```bash
# 步骤 1: 检查 AuthorizationPolicy
kubectl get authorizationpolicy -A
kubectl describe authorizationpolicy <name> -n <namespace>

# 步骤 2: 检查源 Pod 的身份
kubectl exec <source-pod> -c istio-proxy -- curl localhost:15000/certs | jq '.certificates[0].ca_cert'

# 步骤 3: 验证 RBAC 调试日志
kubectl exec <dest-pod> -c istio-proxy -- curl -X POST localhost:15000/logging?rbac=debug
kubectl logs <dest-pod> -c istio-proxy | grep -i "rbac"

# 步骤 4: 常见问题检查
# - principal 格式是否正确 (cluster.local/ns/xxx/sa/xxx)
# - namespace 是否匹配
# - 操作 (GET/POST) 是否在允许列表
```

**AuthorizationPolicy 示例**：

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-specific-service
  namespace: target-namespace
spec:
  selector:
    matchLabels:
      app: target-app
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/source-namespace/sa/source-service-account
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]
```

### 3.10 安全生产风险提示

| 操作 | 风险等级 | 潜在风险 | 建议措施 |
|------|----------|----------|----------|
| 启用 STRICT mTLS | 高 | 非 mesh 服务无法通信 | 先用 PERMISSIVE 模式过渡 |
| 删除 VirtualService | 中 | 流量可能无法路由 | 确认无服务依赖 |
| 修改全局配置 | 高 | 影响整个 mesh | 先在测试环境验证 |
| 重启 istiod | 高 | 短暂配置推送中断 | 选择低峰期，确保高可用 |
| 启用 EnvoyFilter | 高 | 可能影响意外流量 | 严格限制 workloadSelector |
| 修改 AuthorizationPolicy | 中 | 可能意外阻止合法流量 | 使用 dry-run 测试 |

### 附录：快速诊断命令

```bash
# ===== Istio 一键诊断脚本 =====

echo "=== Istio 版本 ==="
istioctl version

echo -e "\n=== 控制面状态 ==="
kubectl get pods -n istio-system

echo -e "\n=== Proxy 同步状态 ==="
istioctl proxy-status

echo -e "\n=== 配置分析 ==="
istioctl analyze -A 2>&1 | head -30

echo -e "\n=== Istio 资源 ==="
echo "VirtualServices:"
kubectl get virtualservice -A
echo -e "\nDestinationRules:"
kubectl get destinationrule -A
echo -e "\nGateways:"
kubectl get gateway -A
echo -e "\nPeerAuthentication:"
kubectl get peerauthentication -A

echo -e "\n=== 最近的 istiod 错误 ==="
kubectl logs -n istio-system -l app=istiod --tail=20 | grep -i error
```

### 附录：常用 Istio 资源模板

```yaml
# 基本的服务暴露配置
---
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: app-gateway
  namespace: istio-system
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
      credentialName: app-tls-secret  # K8s secret in istio-system
    hosts:
    - "app.example.com"

---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: app-vs
  namespace: app-namespace
spec:
  hosts:
  - "app.example.com"
  gateways:
  - istio-system/app-gateway
  http:
  - match:
    - uri:
        prefix: /api/v1
    route:
    - destination:
        host: api-v1-service
        port:
          number: 80
  - match:
    - uri:
        prefix: /api/v2
    route:
    - destination:
        host: api-v2-service
        port:
          number: 80

---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: api-dr
  namespace: app-namespace
spec:
  host: api-v1-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        h2UpgradePolicy: UPGRADE
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
```
