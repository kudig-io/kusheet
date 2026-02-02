# Kubernetes 证书故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32, cert-manager v1.12+ | **最后更新**: 2026-01 | **难度**: 高级
>
> **版本说明**:
> - v1.25+ 移除内置 ServiceAccount 令牌自动挂载
> - v1.27+ 支持 ClusterTrustBundle (Alpha)
> - kubeadm 证书默认有效期 1 年，CA 10 年
> - cert-manager v1.14+ 支持 Gateway API 集成

## 概述

Kubernetes 使用 TLS 证书保护组件间通信和 API 访问安全。证书问题是集群故障的常见原因，包括证书过期、签名错误、CA 不信任等。本文档覆盖 Kubernetes 证书相关故障的诊断与解决方案。

---

## 第一部分：问题现象与影响分析

### 1.1 Kubernetes 证书体系

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes PKI 体系                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐     │
│  │  Root CA     │     │  etcd CA     │     │ Front Proxy  │     │
│  │  (cluster)   │     │  (可独立)     │     │     CA       │     │
│  └──────┬───────┘     └──────┬───────┘     └──────┬───────┘     │
│         │                    │                    │              │
│         ▼                    ▼                    ▼              │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                     签发的证书                           │    │
│  │  - API Server 服务端证书                                 │    │
│  │  - API Server -> kubelet 客户端证书                      │    │
│  │  - API Server -> etcd 客户端证书                         │    │
│  │  - etcd 服务端/对等证书                                  │    │
│  │  - Controller Manager 客户端证书                         │    │
│  │  - Scheduler 客户端证书                                  │    │
│  │  - kubelet 客户端/服务端证书                             │    │
│  │  - Front Proxy 客户端证书 (API 聚合)                     │    │
│  │  - ServiceAccount 签名密钥对                             │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 错误信息示例 | 查看方式 |
|---------|---------|-------------|---------|
| 证书过期 | 组件无法启动或通信失败 | `certificate has expired` | `openssl x509 -enddate` |
| CA 不信任 | TLS 握手失败 | `x509: certificate signed by unknown authority` | 组件日志 |
| 证书主体不匹配 | 连接被拒绝 | `x509: certificate is valid for X, not Y` | 组件日志 |
| 密钥不匹配 | TLS 握手失败 | `tls: private key does not match public key` | 组件启动日志 |
| 证书链不完整 | 验证失败 | `x509: certificate signed by unknown authority` | 客户端日志 |
| SAN 缺失 | 主机名验证失败 | `x509: cannot validate certificate for IP` | API Server 访问 |
| 证书权限问题 | 组件无法读取证书 | `permission denied` | 组件日志 |
| kubeconfig 失效 | kubectl 无法连接 | `Unable to connect to the server` | kubectl 命令 |

### 1.3 证书位置参考 (kubeadm 集群)

| 证书文件 | 路径 | 用途 |
|---------|-----|-----|
| CA 证书 | `/etc/kubernetes/pki/ca.crt` | 集群根 CA |
| CA 密钥 | `/etc/kubernetes/pki/ca.key` | CA 签名密钥 |
| API Server 证书 | `/etc/kubernetes/pki/apiserver.crt` | API Server TLS |
| API Server 密钥 | `/etc/kubernetes/pki/apiserver.key` | API Server 私钥 |
| API Server kubelet 客户端 | `/etc/kubernetes/pki/apiserver-kubelet-client.crt` | 访问 kubelet |
| etcd CA | `/etc/kubernetes/pki/etcd/ca.crt` | etcd 根 CA |
| etcd 服务端 | `/etc/kubernetes/pki/etcd/server.crt` | etcd TLS |
| Front Proxy CA | `/etc/kubernetes/pki/front-proxy-ca.crt` | API 聚合 CA |
| SA 公钥 | `/etc/kubernetes/pki/sa.pub` | ServiceAccount 验证 |
| SA 私钥 | `/etc/kubernetes/pki/sa.key` | ServiceAccount 签名 |

### 1.4 影响分析

| 故障类型 | 直接影响 | 间接影响 | 影响范围 |
|---------|---------|---------|---------|
| CA 证书过期 | 所有组件通信失败 | 集群完全不可用 | 整个集群 |
| API Server 证书过期 | API 无法访问 | kubectl/所有控制器失效 | 整个集群 |
| etcd 证书过期 | etcd 无法启动 | API Server 无后端存储 | 整个集群 |
| kubelet 证书过期 | 节点 NotReady | Pod 无法调度到该节点 | 单节点 |
| ServiceAccount 密钥问题 | Token 无法验证 | Pod 无法访问 API | 整个集群 |
| Front Proxy 证书过期 | API 聚合失败 | metrics-server 等扩展 API 不可用 | 扩展 API |

---

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
证书故障
    │
    ├─── 组件无法启动？
    │         │
    │         ├─ 查看组件日志 ──→ 定位具体证书问题
    │         ├─ 检查证书文件存在性
    │         └─ 检查文件权限
    │
    ├─── TLS 握手失败？
    │         │
    │         ├─ 证书过期 ──→ 更新证书
    │         ├─ CA 不信任 ──→ 配置正确的 CA
    │         ├─ 主体不匹配 ──→ 重新签发证书
    │         └─ SAN 缺失 ──→ 添加 SAN 重签
    │
    ├─── kubectl 无法连接？
    │         │
    │         ├─ kubeconfig 证书过期 ──→ 更新 kubeconfig
    │         ├─ API Server 证书过期 ──→ 更新 API Server 证书
    │         └─ CA 变更 ──→ 更新 kubeconfig 的 CA
    │
    └─── ServiceAccount 认证失败？
              │
              ├─ Token 无效 ──→ 检查 SA 密钥对
              └─ Token 过期 ──→ 检查 TokenRequest API
```

### 2.2 排查命令集

#### 2.2.1 证书基本信息检查

```bash
# 查看证书过期时间
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -enddate

# 查看证书完整信息
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text

# 查看证书主体 (Subject)
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -subject

# 查看证书签发者 (Issuer)
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -issuer

# 查看 SAN (Subject Alternative Names)
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -ext subjectAltName

# 批量检查所有证书过期时间
for crt in /etc/kubernetes/pki/*.crt /etc/kubernetes/pki/etcd/*.crt; do
  echo "=== $crt ==="
  openssl x509 -in "$crt" -noout -enddate
done
```

#### 2.2.2 kubeadm 证书检查

```bash
# 检查所有证书过期时间 (kubeadm 集群)
kubeadm certs check-expiration

# 输出示例:
# CERTIFICATE                EXPIRES                  RESIDUAL TIME   EXTERNALLY MANAGED
# admin.conf                 Jan 15, 2025 08:30 UTC   364d            no
# apiserver                  Jan 15, 2025 08:30 UTC   364d            no
# apiserver-etcd-client      Jan 15, 2025 08:30 UTC   364d            no
# ...
```

#### 2.2.3 验证证书与密钥匹配

```bash
# 获取证书公钥哈希
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -modulus | md5sum

# 获取私钥哈希
openssl rsa -in /etc/kubernetes/pki/apiserver.key -noout -modulus | md5sum

# 两者应该相同
```

#### 2.2.4 验证证书链

```bash
# 验证证书是否由指定 CA 签发
openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/apiserver.crt

# 应该输出: /etc/kubernetes/pki/apiserver.crt: OK
```

#### 2.2.5 远程检查证书

```bash
# 检查 API Server 证书
echo | openssl s_client -connect <api-server-ip>:6443 -servername kubernetes 2>/dev/null | openssl x509 -noout -text

# 检查 etcd 证书
echo | openssl s_client -connect <etcd-ip>:2379 -servername etcd 2>/dev/null | openssl x509 -noout -text

# 检查证书过期时间
echo | openssl s_client -connect <api-server-ip>:6443 2>/dev/null | openssl x509 -noout -enddate
```

#### 2.2.6 kubeconfig 检查

```bash
# 查看 kubeconfig 中的证书
kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}' | base64 -d | openssl x509 -noout -text

# 检查 kubeconfig 证书过期时间
kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}' | base64 -d | openssl x509 -noout -enddate

# 检查 CA 证书
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d | openssl x509 -noout -text
```

### 2.3 排查注意事项

| 注意事项 | 说明 |
|---------|-----|
| 备份优先 | 任何证书操作前先备份 /etc/kubernetes/pki 目录 |
| 时间同步 | 确保所有节点时间同步，时钟偏差会导致证书验证失败 |
| 证书轮换 | kubeadm 1.8+ 支持自动轮换 kubelet 证书 |
| 外部 CA | 如使用外部 CA，需自行管理证书更新 |
| etcd 独立 | 独立 etcd 集群的证书需单独管理 |
| 高可用 | 多 master 集群需确保所有节点证书同步更新 |

---

## 第三部分：解决方案与风险控制

### 3.1 证书过期处理

#### 场景 1：kubeadm 集群证书更新 (推荐)

**问题现象：**
```bash
$ kubeadm certs check-expiration
CERTIFICATE                EXPIRES                  RESIDUAL TIME
apiserver                  Jan 15, 2024 08:30 UTC   -5d     # 已过期
```

**解决步骤：**

```bash
# 1. 备份现有证书
cp -r /etc/kubernetes/pki /etc/kubernetes/pki.backup.$(date +%Y%m%d)
cp -r /etc/kubernetes/*.conf /etc/kubernetes/conf.backup.$(date +%Y%m%d)

# 2. 更新所有证书 (kubeadm 1.17+)
kubeadm certs renew all

# 3. 重启控制平面组件
# 方式 A: 如果使用静态 Pod
systemctl restart kubelet

# 方式 B: 如果是 systemd 服务
systemctl restart kube-apiserver kube-controller-manager kube-scheduler

# 4. 更新 kubeconfig 文件
kubeadm kubeconfig user --client-name=admin --org system:masters > /etc/kubernetes/admin.conf
cp /etc/kubernetes/admin.conf ~/.kube/config

# 5. 验证证书已更新
kubeadm certs check-expiration

# 6. 验证集群可用
kubectl get nodes
kubectl get pods -n kube-system
```

#### 场景 2：单独更新特定证书

```bash
# 只更新 API Server 证书
kubeadm certs renew apiserver

# 只更新 API Server 到 kubelet 的客户端证书
kubeadm certs renew apiserver-kubelet-client

# 只更新 etcd 证书
kubeadm certs renew etcd-server
kubeadm certs renew etcd-peer
kubeadm certs renew etcd-healthcheck-client

# 只更新 admin.conf
kubeadm certs renew admin.conf

# 重启相关组件
systemctl restart kubelet
```

#### 场景 3：手动生成证书 (非 kubeadm 集群)

```bash
# 1. 生成 API Server 证书
cat > apiserver-csr.json <<EOF
{
  "CN": "kube-apiserver",
  "hosts": [
    "127.0.0.1",
    "10.96.0.1",
    "<master-ip>",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster.local"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "Kubernetes"
    }
  ]
}
EOF

# 2. 使用 cfssl 签发
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
  -profile=kubernetes apiserver-csr.json | cfssljson -bare apiserver

# 3. 替换证书文件
cp apiserver.pem /etc/kubernetes/pki/apiserver.crt
cp apiserver-key.pem /etc/kubernetes/pki/apiserver.key

# 4. 重启 API Server
systemctl restart kube-apiserver
```

---

### 3.2 CA 证书问题

#### 场景 1：CA 证书即将过期

**风险评估：**
- CA 证书过期会导致所有由其签发的证书失效
- 需要重新签发所有证书
- 高风险操作，建议在维护窗口执行

**解决步骤：**

```bash
# 1. 检查 CA 过期时间
openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -enddate

# 2. 备份所有证书和配置
tar -czvf k8s-pki-backup-$(date +%Y%m%d).tar.gz /etc/kubernetes/pki /etc/kubernetes/*.conf

# 3. 更新 CA 证书 (kubeadm 1.20+)
kubeadm certs renew all --config /etc/kubernetes/kubeadm-config.yaml

# 4. 对于旧版本，可能需要手动延长 CA
# 使用 openssl 重新生成 CA (保持相同密钥)
openssl x509 -req -days 3650 -in ca.csr -signkey /etc/kubernetes/pki/ca.key \
  -out /etc/kubernetes/pki/ca.crt -extensions v3_ca

# 5. 重新签发所有证书
kubeadm certs renew all

# 6. 更新所有 kubeconfig
kubeadm kubeconfig user --client-name=admin --org system:masters > /etc/kubernetes/admin.conf
# 复制到其他 master 节点

# 7. 更新 worker 节点
# 在每个 worker 节点上
systemctl stop kubelet
rm /var/lib/kubelet/pki/*
systemctl start kubelet
# kubelet 会自动申请新证书 (如果启用了证书轮换)

# 8. 验证
kubectl get nodes
kubectl get csr
```

#### 场景 2：CA 不信任错误

**问题现象：**
```
x509: certificate signed by unknown authority
```

**解决步骤：**

```bash
# 1. 确认证书的签发 CA
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -issuer

# 2. 确认客户端使用的 CA
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d | openssl x509 -noout -subject

# 3. 如果不匹配，更新 kubeconfig 中的 CA
kubectl config set-cluster kubernetes --certificate-authority=/etc/kubernetes/pki/ca.crt

# 4. 或者重新生成 kubeconfig
kubeadm kubeconfig user --client-name=admin --org system:masters > ~/.kube/config
```

---

### 3.3 kubelet 证书问题

#### 场景 1：kubelet 证书过期导致节点 NotReady

**问题现象：**
```bash
$ kubectl get nodes
NAME     STATUS     ROLES    AGE    VERSION
node-1   NotReady   <none>   180d   v1.25.0
```

**解决步骤：**

```bash
# 1. 在问题节点上检查 kubelet 证书
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -enddate

# 2. 检查 kubelet 日志
journalctl -u kubelet | grep -i "certificate\|x509"

# 3. 如果启用了证书轮换，重启 kubelet 应该自动申请新证书
systemctl restart kubelet

# 4. 在 master 上批准 CSR (如果需要)
kubectl get csr
kubectl certificate approve <csr-name>

# 5. 如果未启用证书轮换，手动重新加入节点
# 在 master 上生成 join token
kubeadm token create --print-join-command

# 在 worker 上重置并重新加入
kubeadm reset
kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

#### 场景 2：启用 kubelet 证书自动轮换

```bash
# 1. 编辑 kubelet 配置
cat >> /var/lib/kubelet/config.yaml <<EOF
rotateCertificates: true
serverTLSBootstrap: true
EOF

# 2. 或通过启动参数
# --rotate-certificates=true
# --rotate-server-certificates=true

# 3. 重启 kubelet
systemctl restart kubelet

# 4. 配置自动批准 CSR (可选，需要评估安全性)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: auto-approve-csrs
subjects:
- kind: Group
  name: system:bootstrappers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: system:certificates.k8s.io:certificatesigningrequests:nodeclient
  apiGroup: rbac.authorization.k8s.io
EOF
```

---

### 3.4 etcd 证书问题

#### 场景 1：etcd 证书过期

**问题现象：**
```
etcdserver: request timed out
transport: authentication handshake failed: x509: certificate has expired
```

**解决步骤：**

```bash
# 1. 备份 etcd 数据
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key

# 2. 更新 etcd 证书
kubeadm certs renew etcd-server
kubeadm certs renew etcd-peer
kubeadm certs renew etcd-healthcheck-client
kubeadm certs renew apiserver-etcd-client

# 3. 重启 etcd
# 如果是静态 Pod
mv /etc/kubernetes/manifests/etcd.yaml /tmp/
sleep 10
mv /tmp/etcd.yaml /etc/kubernetes/manifests/

# 如果是 systemd 服务
systemctl restart etcd

# 4. 验证 etcd 健康
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key
```

---

### 3.5 ServiceAccount Token 问题

#### 场景 1：Pod 无法访问 API (Token 认证失败)

**问题现象：**
```
Unauthorized
error: You must be logged in to the server (Unauthorized)
```

**解决步骤：**

```bash
# 1. 检查 SA 密钥对
ls -la /etc/kubernetes/pki/sa.*

# 2. 验证 API Server 配置
ps aux | grep kube-apiserver | grep service-account

# 3. 验证 Controller Manager 配置
ps aux | grep kube-controller-manager | grep service-account

# 4. 确保 API Server 和 Controller Manager 使用相同的密钥对
# API Server: --service-account-key-file=/etc/kubernetes/pki/sa.pub
# Controller Manager: --service-account-private-key-file=/etc/kubernetes/pki/sa.key

# 5. 重新生成 SA 密钥对 (如果需要)
openssl genrsa -out /etc/kubernetes/pki/sa.key 2048
openssl rsa -in /etc/kubernetes/pki/sa.key -pubout -out /etc/kubernetes/pki/sa.pub

# 6. 重启组件
systemctl restart kubelet

# 7. 删除并重建 Pod (让 Pod 获取新 Token)
kubectl delete pod <pod-name>
```

---

### 3.6 证书 SAN 问题

#### 场景 1：添加新 IP/域名到证书

**问题现象：**
```
x509: certificate is valid for 10.96.0.1, not 192.168.1.100
```

**解决步骤：**

```bash
# 1. 查看当前证书 SAN
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -ext subjectAltName

# 2. 创建 kubeadm 配置文件
cat > kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
apiServer:
  certSANs:
  - "kubernetes"
  - "kubernetes.default"
  - "kubernetes.default.svc"
  - "kubernetes.default.svc.cluster.local"
  - "10.96.0.1"
  - "192.168.1.100"        # 新增 IP
  - "k8s.example.com"      # 新增域名
  - "<master-ip>"
EOF

# 3. 备份旧证书
mv /etc/kubernetes/pki/apiserver.crt /etc/kubernetes/pki/apiserver.crt.bak
mv /etc/kubernetes/pki/apiserver.key /etc/kubernetes/pki/apiserver.key.bak

# 4. 重新生成证书
kubeadm certs renew apiserver --config kubeadm-config.yaml

# 5. 重启 API Server
systemctl restart kubelet

# 6. 验证新 SAN
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -ext subjectAltName
```

---

### 3.7 完整的证书检查脚本

```bash
#!/bin/bash
# Kubernetes 证书健康检查脚本

echo "=== Kubernetes Certificate Health Check ==="
echo ""

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查证书过期时间
check_cert() {
    local cert=$1
    local name=$2
    
    if [ ! -f "$cert" ]; then
        echo -e "${RED}[MISSING]${NC} $name - File not found: $cert"
        return
    fi
    
    local expiry=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
    local now_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
    
    if [ $days_left -lt 0 ]; then
        echo -e "${RED}[EXPIRED]${NC} $name - Expired $((days_left * -1)) days ago"
    elif [ $days_left -lt 30 ]; then
        echo -e "${YELLOW}[WARNING]${NC} $name - Expires in $days_left days ($expiry)"
    else
        echo -e "${GREEN}[OK]${NC} $name - Expires in $days_left days"
    fi
}

# 检查主要证书
echo "--- Control Plane Certificates ---"
check_cert "/etc/kubernetes/pki/ca.crt" "CA Certificate"
check_cert "/etc/kubernetes/pki/apiserver.crt" "API Server"
check_cert "/etc/kubernetes/pki/apiserver-kubelet-client.crt" "API Server -> kubelet"
check_cert "/etc/kubernetes/pki/front-proxy-ca.crt" "Front Proxy CA"
check_cert "/etc/kubernetes/pki/front-proxy-client.crt" "Front Proxy Client"

echo ""
echo "--- etcd Certificates ---"
check_cert "/etc/kubernetes/pki/etcd/ca.crt" "etcd CA"
check_cert "/etc/kubernetes/pki/etcd/server.crt" "etcd Server"
check_cert "/etc/kubernetes/pki/etcd/peer.crt" "etcd Peer"
check_cert "/etc/kubernetes/pki/etcd/healthcheck-client.crt" "etcd Health Check Client"

echo ""
echo "--- kubeconfig Certificates ---"
for conf in admin.conf controller-manager.conf scheduler.conf; do
    if [ -f "/etc/kubernetes/$conf" ]; then
        cert_data=$(grep client-certificate-data /etc/kubernetes/$conf | awk '{print $2}')
        if [ -n "$cert_data" ]; then
            expiry=$(echo "$cert_data" | base64 -d | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
            expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
            now_epoch=$(date +%s)
            days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
            
            if [ $days_left -lt 0 ]; then
                echo -e "${RED}[EXPIRED]${NC} $conf"
            elif [ $days_left -lt 30 ]; then
                echo -e "${YELLOW}[WARNING]${NC} $conf - Expires in $days_left days"
            else
                echo -e "${GREEN}[OK]${NC} $conf - Expires in $days_left days"
            fi
        fi
    fi
done

echo ""
echo "=== Check Complete ==="
```

---

### 3.8 安全生产风险提示

| 操作 | 风险等级 | 风险说明 | 建议 |
|-----|---------|---------|-----|
| 更新 CA 证书 | 高 | 需要重签所有证书，集群可能中断 | 在维护窗口执行，提前做好灾备 |
| 更新 API Server 证书 | 中 | 短暂 API 不可用 | 确保 HA 配置，快速重启 |
| 更新 etcd 证书 | 高 | 数据存储可能中断 | 先备份 etcd，确认恢复流程 |
| 更新 kubelet 证书 | 低 | 单节点短暂 NotReady | 逐节点滚动更新 |
| 修改证书 SAN | 中 | 需要重启 API Server | 提前通知用户 |
| 手动生成证书 | 中 | 配置错误导致组件无法通信 | 仔细验证证书属性和链 |
| 删除/重置 CSR | 低 | kubelet 证书轮换中断 | 确认 CSR 状态后操作 |

---

## 附录

### 常用命令速查

```bash
# 证书检查
kubeadm certs check-expiration
openssl x509 -in <cert> -noout -enddate
openssl x509 -in <cert> -noout -text
openssl verify -CAfile <ca> <cert>

# 证书更新
kubeadm certs renew all
kubeadm certs renew <cert-name>

# kubeconfig 更新
kubeadm kubeconfig user --client-name=admin --org system:masters

# 远程检查
echo | openssl s_client -connect <ip>:6443 | openssl x509 -noout -text

# CSR 管理
kubectl get csr
kubectl certificate approve <csr>
kubectl certificate deny <csr>
```

### 相关文档

- [API Server 故障排查](../01-control-plane/01-apiserver-troubleshooting.md)
- [etcd 故障排查](../01-control-plane/02-etcd-troubleshooting.md)
- [kubelet 故障排查](../02-node-components/01-kubelet-troubleshooting.md)
- [RBAC 故障排查](./01-rbac-troubleshooting.md)
