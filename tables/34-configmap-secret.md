# 表格34: ConfigMap与Secret管理

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/configuration](https://kubernetes.io/docs/concepts/configuration/)

## ConfigMap创建方式

| 方式 | 命令 | 说明 | 适用场景 |
|-----|------|------|---------|
| 字面值 | `kubectl create cm name --from-literal=key=value` | 直接指定键值 | 简单配置 |
| 文件 | `kubectl create cm name --from-file=config.txt` | 文件内容作为值 | 配置文件 |
| 目录 | `kubectl create cm name --from-file=/config/` | 目录下所有文件 | 多配置文件 |
| env文件 | `kubectl create cm name --from-env-file=.env` | 环境变量格式 | .env文件 |
| YAML | `kubectl apply -f configmap.yaml` | 声明式配置 | GitOps |

## ConfigMap使用方式

| 方式 | 说明 | 热更新 | 注意事项 |
|-----|------|-------|---------|
| 环境变量 | `env.valueFrom.configMapKeyRef` | ❌ | Pod重启才生效 |
| envFrom | 所有键注入环境变量 | ❌ | 注意键名冲突 |
| Volume挂载 | 挂载为文件 | ✅(默认60s) | kubelet同步周期 |
| subPath挂载 | 挂载单个文件 | ❌ | 不支持热更新 |
| Projected Volume | 多源合并挂载 | ✅ | 灵活组合 |

## ConfigMap示例

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # 简单键值
  database_url: "mysql://localhost:3306/db"
  log_level: "info"
  
  # 多行配置文件
  config.yaml: |
    server:
      port: 8080
      timeout: 30s
    database:
      host: localhost
      port: 3306
  
  # 二进制数据使用binaryData
binaryData:
  logo.png: <base64-encoded-data>
immutable: false  # v1.21+支持不可变ConfigMap
```

## Secret类型

| 类型 | 用途 | 自动创建 |
|-----|------|---------|
| Opaque | 通用密钥 | 手动 |
| kubernetes.io/service-account-token | SA Token | 自动 |
| kubernetes.io/dockerconfigjson | 镜像拉取凭证 | 手动 |
| kubernetes.io/basic-auth | 基本认证 | 手动 |
| kubernetes.io/ssh-auth | SSH认证 | 手动 |
| kubernetes.io/tls | TLS证书 | 手动 |
| bootstrap.kubernetes.io/token | Bootstrap Token | 手动 |

## Secret创建命令

```bash
# 通用Secret
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123

# Docker Registry凭证
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=pass \
  --docker-email=user@example.com

# TLS证书
kubectl create secret tls tls-secret \
  --cert=tls.crt \
  --key=tls.key

# 从文件创建
kubectl create secret generic ssh-key \
  --from-file=ssh-privatekey=/path/to/id_rsa
```

## Secret在Pod中使用

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-example
spec:
  containers:
  - name: app
    image: myapp
    env:
    # 单个键引用
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
    # 所有键注入
    envFrom:
    - secretRef:
        name: db-secret
        optional: false
    # Volume挂载
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: db-secret
      defaultMode: 0400  # 权限设置
      items:            # 选择性挂载
      - key: password
        path: db-password
  imagePullSecrets:     # 镜像拉取凭证
  - name: regcred
```

## 不可变ConfigMap/Secret

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: immutable-config
data:
  key: value
immutable: true  # 设置后不可修改,只能删除重建
```

| 特性 | 说明 |
|-----|------|
| 性能提升 | 减少API Server压力 |
| 安全性 | 防止意外修改 |
| 限制 | 只能删除重建 |
| 版本支持 | v1.21+ GA |

## Secret加密存储

| 加密方式 | 配置 | 说明 |
|---------|-----|------|
| identity | 默认 | 无加密(base64) |
| secretbox | 推荐 | 本地密钥加密 |
| aescbc | 可选 | AES-CBC加密 |
| aesgcm | 可选 | AES-GCM加密 |
| kms | 企业级 | KMS服务加密 |

## 加密配置示例

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: <base64-encoded-32-byte-key>
  - identity: {}  # 回退方案
```

## 最佳实践

| 实践 | 说明 | 实施方法 |
|-----|------|---------|
| **最小权限** | RBAC限制Secret访问 | 按namespace授权 |
| **加密存储** | 启用etcd加密 | EncryptionConfiguration |
| **外部密钥管理** | 使用Vault/KMS | External Secrets Operator |
| **自动轮换** | 定期更新密钥 | 配置refreshInterval |
| **避免日志泄露** | 不在日志中打印 | 代码审查 |
| **使用CSI** | 外部Secret Provider | Secrets Store CSI |
| **不可变配置** | 防止意外修改 | immutable: true |
| **版本管理** | 配置变更追踪 | 使用名称后缀 |

## External Secrets Operator

| 后端 | 说明 | 配置示例 |
|-----|------|---------|
| AWS Secrets Manager | AWS密钥服务 | `provider: aws` |
| HashiCorp Vault | 开源密钥管理 | `provider: vault` |
| Azure Key Vault | Azure密钥服务 | `provider: azurekv` |
| GCP Secret Manager | GCP密钥服务 | `provider: gcpsm` |
| 阿里云KMS | ACK集成 | `provider: alicloud` |

```yaml
# External Secrets Operator配置示例
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: alicloud-kms
  namespace: production
spec:
  provider:
    alicloud:
      regionID: cn-hangzhou
      auth:
        rrsa:
          oidcProviderArn: acs:ram::1234567890:oidc-provider/ack-rrsa
          oidcTokenFilePath: /var/run/secrets/tokens/oidc-token
          roleArn: acs:ram::1234567890:role/ack-external-secrets
          sessionName: external-secrets
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: alicloud-kms
    kind: SecretStore
  target:
    name: db-secret
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: /prod/database/username
  - secretKey: password
    remoteRef:
      key: /prod/database/password
```

## Secrets Store CSI Driver

```yaml
# CSI Driver SecretProviderClass
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: alicloud-secrets
spec:
  provider: alicloud
  parameters:
    keyvaultName: "my-keyvault"
    objects: |
      array:
        - |
          objectName: "db-password"
          objectType: "secret"
        - |
          objectName: "api-key"
          objectType: "secret"
  # 同步为Kubernetes Secret
  secretObjects:
  - secretName: synced-secret
    type: Opaque
    data:
    - objectName: db-password
      key: password
---
# 在Pod中使用
apiVersion: v1
kind: Pod
metadata:
  name: secrets-csi-pod
spec:
  containers:
  - name: app
    image: app:v1
    volumeMounts:
    - name: secrets-store
      mountPath: "/mnt/secrets"
      readOnly: true
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: synced-secret
          key: password
  volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: alicloud-secrets
```

## ACK Secret管理

| 功能 | 说明 | 配置方式 |
|-----|------|---------|
| **KMS加密** | etcd数据加密 | 集群创建时启用 |
| **External Secrets** | 集成阿里云凭据管家 | Helm部署 |
| **RRSA** | 无密钥访问云服务 | OIDC配置 |
| **Secret轮换** | 自动更新密钥 | External Secrets |

```bash
# ACK启用KMS加密
# 集群创建时选择"Secret落盘加密"

# 查看加密状态
kubectl get secrets -o json | jq '.items[].metadata.annotations["encryption.alibabacloud.com/encrypted"]'

# RRSA配置
# 1. 集群启用RRSA
aliyun cs POST /clusters/{ClusterId}/components/rrsa-controller/enable

# 2. 配置RAM角色信任策略
{
  "Statement": [{
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": {
        "oidc:sub": "system:serviceaccount:${namespace}:${sa-name}"
      }
    },
    "Effect": "Allow",
    "Principal": {
      "Federated": ["acs:ram::${account-id}:oidc-provider/ack-rrsa-${cluster-id}"]
    }
  }],
  "Version": "1"
}
```

## 配置热更新实现

```yaml
# 方法1: 使用Reloader控制器
# 自动重启Pod当ConfigMap/Secret变更
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  annotations:
    reloader.stakater.com/auto: "true"
    # 或指定ConfigMap
    configmap.reloader.stakater.com/reload: "app-config"
spec:
  template:
    spec:
      containers:
      - name: app
        image: app:v1
---
# 方法2: 使用checksum annotation
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    spec:
      containers:
      - name: app
        image: app:v1
---
# 方法3: 应用内监听文件变化
# 挂载为Volume,应用使用fsnotify监听
```

## 版本变更记录

| 版本 | 变更内容 | 影响 |
|------|---------|------|
| v1.21 | ConfigMap/Secret immutable GA | 不可变配置可用 |
| v1.24 | SA Token不再自动创建Secret | 使用TokenRequest API |
| v1.25 | Secret/ConfigMap不可变性GA | 生产推荐 |
| v1.27 | Secret projected volume改进 | 更灵活的Token挂载 |
| v1.29 | ServiceAccount token改进 | 更安全的Token管理 |
| v1.30 | ConfigMap大小限制提示 | 超过1MiB警告 |

---

**配置管理原则**: 敏感数据用Secret + 启用etcd加密 + 外部密钥管理 + 配置版本追踪 + 最小权限访问
