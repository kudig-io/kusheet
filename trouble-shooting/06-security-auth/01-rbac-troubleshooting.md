# RBAC 与认证故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 中级-高级

---

## 目录

1. [问题现象与影响分析](#1-问题现象与影响分析)
2. [排查方法与步骤](#2-排查方法与步骤)
3. [解决方案与风险控制](#3-解决方案与风险控制)

---

## 1. 问题现象与影响分析

### 1.1 常见问题现象

#### 1.1.1 认证失败

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 未认证 | `Unauthorized` (401) | API Server | kubectl/API 响应 |
| Token 无效 | `invalid bearer token` | API Server | kubectl |
| 证书错误 | `x509: certificate signed by unknown authority` | kubectl | kubectl |
| kubeconfig 错误 | `unable to load kubeconfig` | kubectl | kubectl |

#### 1.1.2 授权失败

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 无权限 | `Forbidden` (403) | API Server | kubectl/API 响应 |
| 资源禁止 | `User cannot <verb> <resource>` | API Server | kubectl |
| ServiceAccount 无权限 | `pods is forbidden` | Pod 内应用 | 应用日志 |
| 命名空间权限不足 | `forbidden: User cannot...in namespace` | kubectl | kubectl |

#### 1.1.3 ServiceAccount 问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| SA 不存在 | `serviceaccounts not found` | Pod Events | `kubectl describe pod` |
| Token 未挂载 | `no credentials provided` | Pod 内应用 | 应用日志 |
| Token 过期 | `token has expired` | API Server | API 响应 |

### 1.2 报错查看方式汇总

```bash
# 测试认证
kubectl auth whoami
kubectl get pods  # 如果失败会显示认证/授权错误

# 检查权限
kubectl auth can-i <verb> <resource>
kubectl auth can-i create pods --as=system:serviceaccount:<ns>:<sa>

# 查看 RBAC 配置
kubectl get roles,rolebindings -n <namespace>
kubectl get clusterroles,clusterrolebindings

# 查看 ServiceAccount
kubectl get serviceaccounts -n <namespace>
kubectl describe serviceaccount <sa-name> -n <namespace>

# 查看 kubeconfig
kubectl config view
kubectl config current-context

# 查看 API Server 审计日志
cat /var/log/kubernetes/audit/audit.log | grep "403\|401"
```

### 1.3 影响面分析

| 问题类型 | 影响范围 | 影响描述 |
|----------|----------|----------|
| 认证失败 | 用户操作 | 无法执行任何操作 |
| RBAC 权限不足 | 特定操作 | 无法执行特定资源操作 |
| SA 权限问题 | 应用功能 | 应用无法访问 Kubernetes API |
| 证书问题 | 所有操作 | 客户端无法连接 API Server |

---

## 2. 排查方法与步骤

### 2.1 认证问题排查

```bash
# 步骤 1：确认当前身份
kubectl auth whoami
# 或者
kubectl config current-context

# 步骤 2：检查 kubeconfig
kubectl config view
cat ~/.kube/config | grep -A10 "current-context"

# 步骤 3：验证证书
# 检查客户端证书
openssl x509 -in ~/.kube/client.crt -noout -text

# 检查证书有效期
openssl x509 -in ~/.kube/client.crt -noout -dates

# 步骤 4：测试 Token（ServiceAccount）
TOKEN=$(kubectl get secret <sa-token-secret> -o jsonpath='{.data.token}' | base64 -d)
curl -k -H "Authorization: Bearer $TOKEN" https://<api-server>:6443/api/v1/namespaces

# 步骤 5：检查 API Server 认证配置
cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -E "authentication|authorization"
```

### 2.2 RBAC 权限排查

```bash
# 步骤 1：检查是否有权限
kubectl auth can-i <verb> <resource>
# 例如
kubectl auth can-i create pods
kubectl auth can-i get secrets -n kube-system
kubectl auth can-i '*' '*'  # 检查是否有管理员权限

# 步骤 2：以特定身份检查权限
kubectl auth can-i create pods --as=<user>
kubectl auth can-i create pods --as=system:serviceaccount:<ns>:<sa>

# 步骤 3：查看角色绑定
# 查看用户绑定的角色
kubectl get rolebindings,clusterrolebindings -A -o json | \
  jq -r '.items[] | select(.subjects[]?.name=="<user>") | .metadata.name'

# 步骤 4：查看角色权限
kubectl describe role <role-name> -n <namespace>
kubectl describe clusterrole <clusterrole-name>

# 步骤 5：列出所有权限
kubectl auth can-i --list
kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa>
```

### 2.3 ServiceAccount 排查

```bash
# 步骤 1：检查 Pod 使用的 ServiceAccount
kubectl get pod <pod-name> -o jsonpath='{.spec.serviceAccountName}'

# 步骤 2：检查 ServiceAccount 是否存在
kubectl get serviceaccount <sa-name> -n <namespace>

# 步骤 3：检查 Token 是否挂载到 Pod
kubectl exec <pod-name> -- cat /var/run/secrets/kubernetes.io/serviceaccount/token

# 步骤 4：检查 ServiceAccount 的 RBAC 绑定
kubectl get rolebindings,clusterrolebindings -A -o json | \
  jq -r '.items[] | select(.subjects[]?.kind=="ServiceAccount" and .subjects[]?.name=="<sa>") | .metadata.name'

# 步骤 5：测试 ServiceAccount 权限
kubectl auth can-i create pods --as=system:serviceaccount:<ns>:<sa>
```

---

## 3. 解决方案与风险控制

### 3.1 创建 RBAC 权限

#### 3.1.1 为用户授予权限

```bash
# 创建 Role（命名空间级别）
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: <namespace>
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
EOF

# 创建 RoleBinding
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: <namespace>
subjects:
- kind: User
  name: <username>
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

# 创建 ClusterRole（集群级别）
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]
EOF

# 创建 ClusterRoleBinding
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-secrets-global
subjects:
- kind: User
  name: <username>
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

#### 3.1.2 为 ServiceAccount 授予权限

```bash
# 创建 ServiceAccount
kubectl create serviceaccount <sa-name> -n <namespace>

# 绑定 Role 到 ServiceAccount
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: <sa-name>-binding
  namespace: <namespace>
subjects:
- kind: ServiceAccount
  name: <sa-name>
  namespace: <namespace>
roleRef:
  kind: Role
  name: <role-name>
  apiGroup: rbac.authorization.k8s.io
EOF

# 或者使用内置的 ClusterRole
kubectl create rolebinding <sa-name>-view \
  --clusterrole=view \
  --serviceaccount=<namespace>:<sa-name> \
  -n <namespace>
```

#### 3.1.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 遵循最小权限原则
2. 不要授予不必要的 cluster-admin 权限
3. 优先使用 Role 而非 ClusterRole
4. 定期审计 RBAC 配置
5. 避免使用 "*" 通配符
```

### 3.2 证书问题解决

#### 3.2.1 更新 kubeconfig 证书

```bash
# 步骤 1：从 admin.conf 复制最新证书
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# 步骤 2：如果需要为其他用户创建 kubeconfig
# 创建用户证书
openssl genrsa -out user.key 2048
openssl req -new -key user.key -out user.csr -subj "/CN=<username>/O=<group>"

# 创建 CSR 对象
cat << EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: <username>
spec:
  request: $(cat user.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

# 批准 CSR
kubectl certificate approve <username>

# 获取证书
kubectl get csr <username> -o jsonpath='{.status.certificate}' | base64 -d > user.crt

# 创建 kubeconfig
kubectl config set-credentials <username> \
  --client-certificate=user.crt \
  --client-key=user.key \
  --embed-certs=true

kubectl config set-context <username>-context \
  --cluster=kubernetes \
  --namespace=default \
  --user=<username>
```

#### 3.2.2 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 证书私钥是敏感信息，妥善保管
2. 定期轮转用户证书
3. 使用短期证书减少泄露风险
4. 考虑使用 OIDC 等集中认证方案
```

### 3.3 常见 RBAC 配置示例

```bash
# 只读访问 Pod 和日志
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: <namespace>
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
EOF

# 部署应用所需权限
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: <namespace>
  name: deployer
rules:
- apiGroups: ["", "apps", "extensions"]
  resources: ["deployments", "replicasets", "pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

# Operator 所需权限（需要管理 CRD）
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: my-operator
rules:
- apiGroups: ["my.domain.com"]
  resources: ["myresources"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["*"]
EOF
```

---

## 附录

### A. 内置 ClusterRole

| 角色 | 权限 | 适用场景 |
|------|------|----------|
| `cluster-admin` | 全部权限 | 集群管理员 |
| `admin` | 命名空间管理权限 | 命名空间管理员 |
| `edit` | 读写核心资源 | 开发人员 |
| `view` | 只读权限 | 只读用户 |

### B. 常用 verbs

| Verb | 说明 | 对应操作 |
|------|------|----------|
| `get` | 获取单个资源 | `kubectl get <resource> <name>` |
| `list` | 列出资源 | `kubectl get <resources>` |
| `watch` | 监听变化 | `kubectl get -w` |
| `create` | 创建资源 | `kubectl create` |
| `update` | 更新资源 | `kubectl apply` |
| `patch` | 部分更新 | `kubectl patch` |
| `delete` | 删除资源 | `kubectl delete` |

### C. 排查清单

- [ ] kubeconfig 配置正确
- [ ] 证书有效且未过期
- [ ] 用户有正确的 RoleBinding/ClusterRoleBinding
- [ ] Role/ClusterRole 包含所需权限
- [ ] ServiceAccount 存在且 Token 已挂载
- [ ] API Group 和 Resource 名称正确
- [ ] Namespace 范围匹配
