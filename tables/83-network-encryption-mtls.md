# 表格83: 网络加密与mTLS

## 网络加密方案

| 方案 | 层级 | 性能影响 | 管理复杂度 | 适用场景 |
|-----|------|---------|-----------|---------|
| WireGuard | L3 | 低(3-5%) | 低 | CNI加密 |
| IPsec | L3 | 中(5-10%) | 中 | 传统方案 |
| mTLS(Istio) | L7 | 中(5-15%) | 中 | 服务网格 |
| Cilium加密 | L3/L4 | 低 | 低 | eBPF加密 |

## Calico WireGuard加密

```yaml
apiVersion: projectcalico.org/v3
kind: FelixConfiguration
metadata:
  name: default
spec:
  wireguardEnabled: true
  wireguardListeningPort: 51820
  wireguardMTU: 1400
  wireguardHostEncryptionEnabled: true  # 主机流量也加密
---
# 验证加密状态
# calicoctl get node <node-name> -o yaml | grep wireguard
```

## Cilium加密配置

```yaml
# Helm values
apiVersion: v1
kind: ConfigMap
metadata:
  name: cilium-encryption
data:
  values.yaml: |
    encryption:
      enabled: true
      type: wireguard
      # 或使用IPsec
      # type: ipsec
      # ipsec:
      #   keyFile: /etc/ipsec.d/keys/ipsec.keys
    
    # WireGuard节点加密
    l7Proxy: false
    
    # 透明加密(不需要服务网格)
    encryption:
      nodeEncryption: true
```

## Istio mTLS配置

```yaml
# 命名空间级别严格mTLS
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT  # STRICT/PERMISSIVE/DISABLE
---
# 工作负载级别配置
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: workload-mtls
  namespace: production
spec:
  selector:
    matchLabels:
      app: sensitive-service
  mtls:
    mode: STRICT
  portLevelMtls:
    8080:
      mode: STRICT
    9090:
      mode: PERMISSIVE  # 监控端口允许明文
```

## Istio证书轮换

```yaml
# 配置证书轮换
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    certificates:
    - secretName: cacerts
      dnsNames:
      - istio-ca-secret
    defaultConfig:
      proxyMetadata:
        # 工作负载证书有效期(默认24h)
        SECRET_TTL: "24h"
        # 证书轮换检查间隔
        SECRET_GRACE_PERIOD_RATIO: "0.5"
```

## 自定义CA配置

```yaml
# 使用自定义CA
apiVersion: v1
kind: Secret
metadata:
  name: cacerts
  namespace: istio-system
type: Opaque
data:
  ca-cert.pem: <base64-encoded-cert>
  ca-key.pem: <base64-encoded-key>
  cert-chain.pem: <base64-encoded-chain>
  root-cert.pem: <base64-encoded-root>
```

## SPIFFE身份验证

```yaml
# Istio AuthorizationPolicy使用SPIFFE ID
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: httpbin-policy
  namespace: production
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/production/sa/sleep"
        - "cluster.local/ns/production/sa/curl"
    to:
    - operation:
        methods: ["GET"]
        paths: ["/status/*"]
```

## 加密验证命令

```bash
# 验证Calico WireGuard
calicoctl get node -o yaml | grep -i wireguard
wg show

# 验证Cilium加密
cilium status | grep Encryption
cilium encrypt status

# 验证Istio mTLS
istioctl x authz check <pod-name>
kubectl exec <pod> -c istio-proxy -- \
  openssl s_client -connect <service>:443 -showcerts

# 检查证书
istioctl proxy-config secret <pod-name>
```

## 加密监控指标

| 指标 | 类型 | 说明 |
|-----|-----|------|
| `istio_tcp_sent_bytes_total` | Counter | TLS发送字节 |
| `istio_tcp_received_bytes_total` | Counter | TLS接收字节 |
| `cilium_encrypt_packets_total` | Counter | 加密包数 |
| `cilium_decrypt_packets_total` | Counter | 解密包数 |

## 性能影响对比

| 方案 | CPU增加 | 延迟增加 | 吞吐量下降 |
|-----|--------|---------|-----------|
| WireGuard | 2-5% | 0.1-0.5ms | <5% |
| IPsec | 5-15% | 0.5-2ms | 5-15% |
| Istio mTLS | 5-10% | 1-5ms | 5-15% |
| Cilium WG | 2-5% | 0.1-0.5ms | <5% |

## 零信任网络

```yaml
# 默认拒绝所有流量
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  {}  # 空规则=拒绝所有
---
# 显式允许特定服务
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend
  namespace: production
spec:
  selector:
    matchLabels:
      app: backend
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/production/sa/frontend"]
```

## ACK加密方案

| 功能 | 说明 |
|-----|------|
| Terway加密 | VPC流量加密 |
| ASM mTLS | 托管mTLS |
| 专有网络 | VPC隔离 |
| SSL证书 | 证书托管 |
