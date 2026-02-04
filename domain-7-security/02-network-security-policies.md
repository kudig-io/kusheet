# 02 - 网络安全策略与零信任架构

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-02 | **参考**: [kubernetes.io/docs/concepts/services-networking/network-policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

## 网络安全架构全景

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          Kubernetes 网络安全架构                                    │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌────────────────────────────────────────────────────────────────────────────────┐ │
│  │                        Zero Trust Network Security                             │ │
│  │                                                                                │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │ │
│  │  │                      NetworkPolicy 层级防护                              │  │ │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐         │  │ │
│  │  │  │ 默认拒绝策略 │  │ 命名空间隔离 │  │ 应用间通信 │  │ 出站流量控制 │         │  │ │
│  │  │  │ deny-all    │  │ Namespace   │  │ App-to-App │  │ Egress Control│         │  │ │
│  │  │  └────────────┘  └────────────┘  └────────────┘  └────────────┘         │  │ │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                                │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │ │
│  │  │                      Service Mesh mTLS 加密                              │  │ │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐         │  │ │
│  │  │  │   Istio    │  │  Linkerd   │  │   Cilium   │  │   Consul   │         │  │ │
│  │  │  │            │  │            │  │            │  │            │         │  │ │
│  │  │  │ • 自动mTLS  │  │ • 轻量级   │  │ • eBPF     │  │ • 企业级   │         │  │ │
│  │  │  │ • 流量治理  │  │ • Rust实现 │  │ • 可观测性 │  │ • 多云支持 │         │  │ │
│  │  │  └────────────┘  └────────────┘  └────────────┘  └────────────┘         │  │ │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                                │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │ │
│  │  │                      CNI 网络插件安全                                 │  │ │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐         │  │ │
│  │  │  │   Calico   │  │  Cilium    │  │   Flannel  │  │   Weave    │         │  │ │
│  │  │  │            │  │            │  │            │  │            │         │  │ │
│  │  │  │ • BGP/eBPF │  │ • eBPF     │  │ • VXLAN    │  │ • 加密     │         │  │ │
│  │  │  │ • 网络策略 │  │ • 可观测性 │  │ • 简单     │  │ • Mesh     │         │  │ │
│  │  │  └────────────┘  └────────────┘  └────────────┘  └────────────┘         │  │ │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                                │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │ │
│  │  │                      外部访问控制                                    │  │ │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐         │  │ │
│  │  │  │   Ingress  │  │  Gateway   │  │   Load     │  │   WAF      │         │  │ │
│  │  │  │   控制器   │  │    API     │  │ Balancer   │  │   防护     │         │  │ │
│  │  │  │ • TLS终止  │  │ • 新一代   │  │ • 云集成   │  │ • 安全防护 │         │  │ │
│  │  │  │ • 认证授权 │  │ • 流量治理 │  │ • 健康检查 │  │ • 攻击检测 │         │  │ │
│  │  │  └────────────┘  └────────────┘  └────────────┘  └────────────┘         │  │ │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## NetworkPolicy 核心概念

### 策略类型详解

| 策略类型 | 说明 | 配置示例 | 适用场景 |
|---------|------|---------|---------|
| **Ingress** | 控制入站流量 | `policyTypes: ["Ingress"]` | 服务暴露防护 |
| **Egress** | 控制出站流量 | `policyTypes: ["Egress"]` | 数据外泄防护 |
| **双向策略** | 同时控制双向 | `policyTypes: ["Ingress", "Egress"]` | 完全隔离 |

### 选择器匹配规则

| 匹配类型 | 语法 | 示例 | 说明 |
|---------|------|------|------|
| **标签选择** | `matchLabels` | `app: web` | 精确匹配 |
| **表达式选择** | `matchExpressions` | `{key: tier, operator: In, values: [frontend]}` | 复杂条件 |
| **命名空间选择** | `namespaceSelector` | `name: production` | 跨命名空间 |
| **IP块选择** | `ipBlock` | `cidr: 10.0.0.0/8` | CIDR范围 |

## 生产级NetworkPolicy配置

### 01. 默认拒绝所有流量

```yaml
# 01-default-deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}  # 选择所有Pod
  policyTypes:
  - Ingress
  - Egress
  # 不允许任何流量
```

### 02. 允许DNS查询

```yaml
# 02-allow-dns.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
spec:
  podSelector: {}  # 所有Pod都可以访问DNS
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

### 03. Web应用完整策略

```yaml
# 03-web-application-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-application
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  - Egress
  
  # 入站规则
  ingress:
  # 1. 允许来自Ingress控制器的流量
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
      podSelector:
        matchLabels:
          app: nginx-ingress
    ports:
    - protocol: TCP
      port: 8080
      
  # 2. 允许来自监控系统的流量
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
      podSelector:
        matchLabels:
          app: prometheus
    ports:
    - protocol: TCP
      port: 8080
      
  # 3. 允许同一应用内的Pod通信
  - from:
    - podSelector:
        matchLabels:
          app: web
    ports:
    - protocol: TCP
      port: 8080

  # 出站规则
  egress:
  # 1. 允许访问数据库
  - to:
    - namespaceSelector:
        matchLabels:
          name: database
      podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
      
  # 2. 允许访问缓存服务
  - to:
    - namespaceSelector:
        matchLabels:
          name: cache
      podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
      
  # 3. 允许访问外部API (通过出口网关)
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 10.0.0.0/8
        - 172.16.0.0/12
        - 192.168.0.0/16
    ports:
    - protocol: TCP
      port: 443
```

### 04. 数据库安全策略

```yaml
# 04-database-security.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-security
  namespace: database
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
  - Ingress
  - Egress
  
  # 严格控制入站流量
  ingress:
  # 1. 只允许应用层访问
  - from:
    - namespaceSelector:
        matchLabels:
          env: production
      podSelector:
        matchLabels:
          app: web
    ports:
    - protocol: TCP
      port: 5432
      
  # 2. 允许备份工具访问
  - from:
    - namespaceSelector:
        matchLabels:
          name: backup
      podSelector:
        matchLabels:
          app: backup-tool
    ports:
    - protocol: TCP
      port: 5432
      
  # 限制出站流量
  egress:
  # 只允许访问必要的外部服务
  - to:
    - ipBlock:
        cidr: 169.254.169.254/32  # AWS元数据服务
    ports:
    - protocol: TCP
      port: 80
```

## Service Mesh 零信任安全

### Istio mTLS配置

```yaml
# 05-istio-mtls.yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT  # 强制mTLS

---
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: permissive-mode
  namespace: legacy-apps
spec:
  mtls:
    mode: PERMISSIVE  # 兼容模式，逐步迁移

---
# DestinationRule配置客户端mTLS
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: database-mtls
  namespace: production
spec:
  host: postgres.database.svc.cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
```

### Cilium Network Policy

```yaml
# 06-cilium-network-policy.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: enhanced-web-policy
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: web
      
  # 增强的入站规则
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: nginx-ingress
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/api/*"
        - method: "POST"
          path: "/api/users"
          
  # 增强的出站规则
  egress:
  - toEndpoints:
    - matchLabels:
        app: postgres
    toPorts:
    - ports:
      - port: "5432"
        protocol: TCP
      rules:
        postgres:
          database: "myapp"
          user: "app_user"
          
  # L7策略示例
  - toEntities:
    - world
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/api/*"
```

## 云原生网络安全最佳实践

### 多层防护策略

| 防护层 | 技术方案 | 配置要点 | 安全等级 |
|-------|---------|---------|---------|
| **网络层** | CNI插件 | Calico/Cilium eBPF | 高 |
| **策略层** | NetworkPolicy | 默认拒绝，显式允许 | 高 |
| **传输层** | mTLS | Istio/Linkerd服务网格 | 极高 |
| **应用层** | WAF/API网关 | Ingress控制器集成 | 中 |
| **监控层** | 流量分析 | Cilium Hubble/CNIs | 高 |

### 零信任实施步骤

```bash
#!/bin/bash
# zero-trust-deployment.sh

echo "=== Kubernetes 零信任安全部署 ==="

# 1. 部署Cilium CNI (支持eBPF和NetworkPolicy)
echo "1. 部署Cilium..."
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=localhost \
  --set k8sServicePort=6443

# 2. 应用默认拒绝策略
echo "2. 应用默认拒绝策略..."
kubectl apply -f 01-default-deny-all.yaml

# 3. 部署DNS策略
echo "3. 部署DNS访问策略..."
kubectl apply -f 02-allow-dns.yaml

# 4. 部署应用特定策略
echo "4. 部署应用安全策略..."
kubectl apply -f 03-web-application-policy.yaml
kubectl apply -f 04-database-security.yaml

# 5. 验证策略生效
echo "5. 验证网络策略..."
kubectl get networkpolicies -A
```

### 安全监控与告警

```yaml
# 07-network-security-monitoring.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: network-security-alerts
  namespace: monitoring
spec:
  groups:
  - name: network-security
    rules:
    # 检测网络策略违规
    - alert: NetworkPolicyViolation
      expr: |
        sum(rate(cilium_drop_count_total{reason="Policy denied"}[5m])) > 0
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "检测到网络策略违规流量"
        
    # 检测异常外部连接
    - alert: UnexpectedExternalTraffic
      expr: |
        sum(rate(cilium_l7_requests_total{type="egress", destination_namespace!="kube-system"}[5m])) 
        by (destination_ip) > 100
      for: 5m
      labels:
        severity: info
      annotations:
        summary: "检测到异常的外部流量 ({{ $labels.destination_ip }})"
        
    # 检测mTLS降级
    - alert: MTLSDowngradeAttempt
      expr: |
        sum(rate(istio_tcp_connections_opened_total{connection_security_policy!="mutual_tls"}[5m])) > 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "检测到mTLS降级连接尝试"
```

## 故障排查与诊断

### 网络策略诊断命令

```bash
# 1. 查看所有网络策略
kubectl get networkpolicies -A

# 2. 查看特定命名空间策略详情
kubectl describe networkpolicy -n production

# 3. 测试Pod连通性
kubectl run debug-pod --image=busybox --restart=Never --rm -it -- sh
# 在Pod内测试
ping <target-pod-ip>
wget -qO- http://<service-name>.<namespace>.svc.cluster.local

# 4. 使用Cilium诊断工具
cilium connectivity test
cilium policy trace --src-pod <source-pod> --dst-pod <dest-pod>

# 5. 查看网络策略日志
kubectl logs -n kube-system -l k8s-app=cilium
```

### 常见问题解决

| 问题现象 | 可能原因 | 解决方案 |
|---------|---------|---------|
| **Pod无法访问Service** | NetworkPolicy过于严格 | 检查ingress规则，添加必要端口 |
| **DNS解析失败** | 未放行DNS流量 | 应用DNS访问策略 |
| **跨命名空间通信失败** | namespaceSelector配置错误 | 验证标签匹配 |
| **外部API调用被阻断** | egress策略限制 | 添加外部访问规则 |

## 合规性检查清单

| 检查项 | 命令/方法 | 合规要求 | 优先级 |
|-------|---------|---------|-------|
| 默认拒绝策略 | `kubectl get networkpolicy -n <ns>` | 所有命名空间必须配置 | P0 |
| DNS访问策略 | 检查DNS相关策略 | 必须显式允许 | P0 |
| 数据库访问控制 | 审计数据库策略 | 最小权限原则 | P0 |
| 外部流量控制 | 检查egress策略 | 限制必要端口 | P1 |
| 服务网格启用 | `kubectl get peerauthentications` | 生产环境强制mTLS | P0 |
| 策略覆盖率 | 统计受保护Pod比例 | >95%覆盖率 | P1 |

---
**网络安全原则**: 默认拒绝 + 显式允许 + 零信任 + 持续监控
---
**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)