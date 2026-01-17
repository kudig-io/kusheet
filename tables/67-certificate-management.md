# 表格67: 证书管理与TLS配置

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/)

## Kubernetes证书类型

| 证书类型 | 用途 | 有效期建议 |
|---------|------|-----------|
| CA证书 | 签发其他证书 | 10年 |
| API Server证书 | API Server HTTPS | 1年 |
| kubelet客户端证书 | kubelet认证 | 1年 |
| etcd证书 | etcd通信加密 | 1年 |
| Service Account密钥 | SA Token签名 | - |
| Front-proxy证书 | API聚合层 | 1年 |

## kubeadm证书位置

| 证书 | 路径 | 说明 |
|-----|------|------|
| CA | /etc/kubernetes/pki/ca.crt | 集群CA |
| API Server | /etc/kubernetes/pki/apiserver.crt | API Server证书 |
| API Server kubelet | /etc/kubernetes/pki/apiserver-kubelet-client.crt | 访问kubelet |
| etcd CA | /etc/kubernetes/pki/etcd/ca.crt | etcd CA |
| etcd Server | /etc/kubernetes/pki/etcd/server.crt | etcd服务端 |
| Front Proxy CA | /etc/kubernetes/pki/front-proxy-ca.crt | 聚合层CA |
| SA Key | /etc/kubernetes/pki/sa.key | SA签名密钥 |

## 证书检查命令

```bash
# 查看证书有效期
kubeadm certs check-expiration

# 使用openssl查看
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates

# 查看证书详情
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text

# 检查kubelet证书
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates
```

## kubeadm证书更新

```bash
# 更新所有证书
kubeadm certs renew all

# 更新特定证书
kubeadm certs renew apiserver
kubeadm certs renew apiserver-kubelet-client
kubeadm certs renew etcd-server

# 更新后重启控制平面
systemctl restart kubelet
```

## cert-manager安装

```bash
# Helm安装
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

## cert-manager CRD

| CRD | 用途 | 作用域 |
|-----|------|-------|
| Issuer | 证书签发者 | Namespaced |
| ClusterIssuer | 集群证书签发者 | Cluster |
| Certificate | 证书请求 | Namespaced |
| CertificateRequest | 证书请求详情 | Namespaced |
| Order | ACME订单 | Namespaced |
| Challenge | ACME挑战 | Namespaced |

## ClusterIssuer配置

```yaml
# Let's Encrypt Issuer
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
    - http01:
        ingress:
          class: nginx
    - dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
---
# 自签名Issuer
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
# CA Issuer
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-key-pair
```

## Certificate配置

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-tls
  namespace: production
spec:
  secretName: myapp-tls-secret
  duration: 2160h  # 90天
  renewBefore: 360h  # 15天前更新
  isCA: false
  privateKey:
    algorithm: RSA
    size: 2048
  usages:
  - server auth
  - client auth
  dnsNames:
  - myapp.example.com
  - www.myapp.example.com
  ipAddresses:
  - 192.168.1.100
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
```

## Ingress自动证书

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls-auto  # cert-manager自动创建
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 80
```

## TLS Secret格式

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: myapp-tls-secret
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
  ca.crt: <base64-encoded-ca>  # 可选
```

## mTLS配置(Service Mesh)

```yaml
# Istio PeerAuthentication
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
```

## 证书监控告警

| 指标 | 告警阈值 | 说明 |
|-----|---------|------|
| 证书过期时间 | <30天 | 提前告警 |
| 证书更新失败 | >0 | 立即告警 |
| CA即将过期 | <90天 | 提前告警 |

## ACK证书管理

| 功能 | 说明 |
|-----|------|
| 托管证书 | 阿里云SSL证书 |
| cert-manager | 应用目录安装 |
| ACM私有CA | 企业级CA服务 |
| 自动续期 | 证书到期自动续期 |

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| v1.25 | kubelet证书自动轮换GA |
| v1.27 | ClusterTrustBundle Alpha |
| v1.29 | ClusterTrustBundle Beta |
| v1.30 | 证书签名改进 |
