# ConfigMap 与 Secret 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 中级
>
> **版本说明**:
> - v1.25+ Secret 自动挂载的 ServiceAccount 令牌变更
> - v1.27+ 支持 projected volume 的 clusterTrustBundle
> - v1.30+ 支持 image volume source (Alpha)

## 概述

ConfigMap 和 Secret 是 Kubernetes 中管理配置数据和敏感信息的核心资源。配置注入失败、数据更新不生效、权限问题等是常见故障。本文档覆盖 ConfigMap/Secret 相关故障的诊断与解决方案。

---

## 第一部分：问题现象与影响分析

### 1.1 ConfigMap/Secret 使用方式

```
┌─────────────────────────────────────────────────────────────────┐
│                ConfigMap/Secret 使用方式                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────┐                                             │
│  │ ConfigMap/     │                                             │
│  │ Secret         │                                             │
│  └───────┬────────┘                                             │
│          │                                                       │
│          ├──────────────┬──────────────┬───────────────┐        │
│          ▼              ▼              ▼               ▼        │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────┐ │
│  │   环境变量    │ │   卷挂载     │ │  容器命令参数 │ │ imagePull │
│  │  (env/envFrom)│ │  (volume)    │ │  (command)   │ │ Secrets │ │
│  └──────────────┘ └──────────────┘ └──────────────┘ └────────┘ │
│                                                                  │
│  特点:                                                           │
│  - 环境变量: Pod 启动时注入，更新需重启 Pod                       │
│  - 卷挂载: 支持热更新 (kubelet sync period)                       │
│  - imagePullSecrets: 用于私有镜像仓库认证                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 错误信息示例 | 查看方式 |
|---------|---------|-------------|---------|
| ConfigMap 不存在 | Pod 启动失败 | `configmap "xxx" not found` | `kubectl describe pod` |
| Secret 不存在 | Pod 启动失败 | `secret "xxx" not found` | `kubectl describe pod` |
| Key 不存在 | 环境变量为空或 Pod 失败 | `key "xxx" is not defined` | `kubectl describe pod` |
| 挂载失败 | Pod ContainerCreating | `MountVolume.SetUp failed` | `kubectl describe pod` |
| 权限不足 | 无法读取 Secret | `secrets "xxx" is forbidden` | `kubectl logs` |
| 数据未更新 | 应用使用旧配置 | 无明显错误 | 应用日志 |
| 编码问题 | Secret 数据乱码 | 数据内容异常 | `kubectl get secret -o yaml` |
| 大小超限 | 创建失败 | `etcd: request is too large` | `kubectl apply` 输出 |
| subPath 不更新 | 配置不热更新 | 无错误，配置不变 | 容器内文件检查 |

### 1.3 影响分析

| 故障类型 | 直接影响 | 间接影响 | 影响范围 |
|---------|---------|---------|---------|
| ConfigMap 不存在 | Pod 无法启动 | 服务不可用 | 引用该 ConfigMap 的所有 Pod |
| Secret 不存在 | Pod 无法启动或认证失败 | 服务不可用、安全凭据失效 | 引用该 Secret 的所有 Pod |
| 配置未更新 | 应用行为不符合预期 | 功能异常、配置不一致 | 依赖该配置的服务 |
| imagePullSecret 问题 | 镜像拉取失败 | Pod 无法启动 | 需要该凭据的所有 Pod |
| Secret 泄露 | 敏感信息暴露 | 安全风险 | 整个系统安全 |

---

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
ConfigMap/Secret 故障
        │
        ├─── Pod 启动失败？
        │         │
        │         ├─ "not found" ──→ 检查资源是否存在/命名空间是否正确
        │         ├─ "key not defined" ──→ 检查 key 名称是否正确
        │         ├─ "forbidden" ──→ 检查 RBAC 权限
        │         └─ "MountVolume failed" ──→ 检查挂载配置
        │
        ├─── 配置未生效？
        │         │
        │         ├─ 使用环境变量 ──→ 需要重启 Pod
        │         ├─ 使用 subPath ──→ 不支持热更新，需重启
        │         ├─ 使用卷挂载 ──→ 等待 kubelet 同步 (默认 1 分钟)
        │         └─ 应用未重新加载 ──→ 检查应用是否支持热加载
        │
        ├─── Secret 数据问题？
        │         │
        │         ├─ 数据乱码 ──→ 检查 base64 编码
        │         ├─ 数据不完整 ──→ 检查 YAML 格式/换行符
        │         └─ 无法解码 ──→ 使用 stringData 或正确编码
        │
        └─── 镜像拉取问题？
                  │
                  ├─ imagePullSecrets 未配置 ──→ 添加 imagePullSecrets
                  ├─ Secret 数据错误 ──→ 重新创建 docker-registry secret
                  └─ ServiceAccount 未关联 ──→ 配置 SA 的 imagePullSecrets
```

### 2.2 排查命令集

#### 2.2.1 ConfigMap 检查

```bash
# 查看 ConfigMap 列表
kubectl get configmap -n <namespace>

# 查看 ConfigMap 详情
kubectl describe configmap <name> -n <namespace>

# 查看 ConfigMap 数据
kubectl get configmap <name> -n <namespace> -o yaml

# 查看特定 key 的值
kubectl get configmap <name> -n <namespace> -o jsonpath='{.data.<key>}'

# 检查 ConfigMap 大小
kubectl get configmap <name> -n <namespace> -o json | wc -c
```

#### 2.2.2 Secret 检查

```bash
# 查看 Secret 列表
kubectl get secret -n <namespace>

# 查看 Secret 详情 (不显示数据)
kubectl describe secret <name> -n <namespace>

# 查看 Secret 数据 (base64 编码)
kubectl get secret <name> -n <namespace> -o yaml

# 解码 Secret 数据
kubectl get secret <name> -n <namespace> -o jsonpath='{.data.<key>}' | base64 -d

# 查看 Secret 类型
kubectl get secret <name> -n <namespace> -o jsonpath='{.type}'

# 检查 docker-registry secret
kubectl get secret <name> -n <namespace> -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq
```

#### 2.2.3 Pod 引用检查

```bash
# 检查 Pod 的环境变量配置
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].env}' | jq

# 检查 Pod 的 envFrom 配置
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].envFrom}' | jq

# 检查 Pod 的卷挂载
kubectl get pod <pod-name> -o jsonpath='{.spec.volumes}' | jq

# 检查容器内的环境变量
kubectl exec <pod-name> -- env | grep <KEY>

# 检查容器内挂载的文件
kubectl exec <pod-name> -- cat /path/to/config/file

# 检查挂载目录内容
kubectl exec <pod-name> -- ls -la /path/to/config/
```

#### 2.2.4 热更新检查

```bash
# 修改 ConfigMap 后检查 Pod 内文件更新时间
kubectl exec <pod-name> -- stat /path/to/config/file

# 查看 kubelet 同步周期
kubectl get configmap -n kube-system kubelet-config -o yaml | grep syncFrequency

# 强制触发 kubelet 同步 (重启 kubelet)
# 注意: 仅在必要时使用
systemctl restart kubelet
```

### 2.3 排查注意事项

| 注意事项 | 说明 |
|---------|-----|
| 命名空间 | ConfigMap/Secret 是命名空间级别资源，必须与 Pod 在同一命名空间 |
| 大小限制 | 单个 ConfigMap/Secret 大小限制约 1MB (etcd 限制) |
| Base64 编码 | Secret data 字段需要 base64 编码，stringData 字段不需要 |
| 热更新限制 | 环境变量和 subPath 挂载不支持热更新 |
| 同步延迟 | 卷挂载更新有延迟 (kubelet sync period + cache TTL) |
| 不可变配置 | immutable: true 的 ConfigMap/Secret 无法修改 |

---

## 第三部分：解决方案与风险控制

### 3.1 资源不存在问题

#### 场景 1：ConfigMap/Secret 不存在

**问题现象：**
```
Events:
  Warning  FailedMount  MountVolume.SetUp failed: configmap "app-config" not found
```

**解决步骤：**

```bash
# 1. 确认资源是否存在
kubectl get configmap app-config -n <namespace>
kubectl get secret app-secret -n <namespace>

# 2. 检查命名空间是否正确
kubectl get configmap -A | grep app-config

# 3. 如果不存在，创建 ConfigMap
kubectl create configmap app-config \
  --from-file=config.yaml=/path/to/config.yaml \
  -n <namespace>

# 4. 或从字面值创建
kubectl create configmap app-config \
  --from-literal=key1=value1 \
  --from-literal=key2=value2 \
  -n <namespace>

# 5. 创建 Secret
kubectl create secret generic app-secret \
  --from-literal=password=mypassword \
  -n <namespace>

# 6. 验证 Pod 状态
kubectl get pods -n <namespace> -w
```

#### 场景 2：Key 不存在

**问题现象：**
```
Events:
  Warning  Failed  Error: configmap "app-config" doesn't have key "database.url"
```

**解决步骤：**

```bash
# 1. 查看 ConfigMap 的所有 key
kubectl get configmap app-config -n <namespace> -o jsonpath='{.data}' | jq 'keys'

# 2. 添加缺失的 key
kubectl patch configmap app-config -n <namespace> --type='json' -p='[
  {"op": "add", "path": "/data/database.url", "value": "jdbc:mysql://localhost:3306/db"}
]'

# 3. 或者编辑 ConfigMap
kubectl edit configmap app-config -n <namespace>

# 4. 如果是 optional: true，Pod 会继续启动但变量为空
# 检查是否应该设置为 optional
```

### 3.2 配置更新问题

#### 场景 1：环境变量不更新

**原理说明：**
环境变量在 Pod 启动时注入，更新 ConfigMap/Secret 后不会自动更新。

**解决步骤：**

```bash
# 方案 1: 重启 Pod (推荐用于无状态应用)
kubectl rollout restart deployment <name> -n <namespace>

# 方案 2: 删除 Pod 让其重建
kubectl delete pod <pod-name> -n <namespace>

# 方案 3: 使用滚动更新触发重启
# 修改 Deployment 的注解触发更新
kubectl patch deployment <name> -n <namespace> -p \
  '{"spec":{"template":{"metadata":{"annotations":{"configmap-version":"v2"}}}}}'

# 方案 4: 使用 Reloader 等工具自动重启
# 安装 stakater/Reloader 后，添加注解:
# annotations:
#   reloader.stakater.com/auto: "true"
```

#### 场景 2：卷挂载配置不更新

**问题现象：**
修改 ConfigMap 后，Pod 内的文件内容没有变化

**解决步骤：**

```bash
# 1. 确认没有使用 subPath
kubectl get pod <pod-name> -o yaml | grep -A10 volumeMounts
# 如果有 subPath，则不支持热更新

# 2. 检查 ConfigMap 是否已更新
kubectl get configmap <name> -o yaml

# 3. 等待 kubelet 同步 (默认最长 1-2 分钟)
# kubelet syncFrequency (默认 1 分钟) + configMapAndSecretChangeDetectionStrategy

# 4. 检查 Pod 内文件
kubectl exec <pod-name> -- cat /path/to/config/file
kubectl exec <pod-name> -- ls -la /path/to/config/

# 5. 如果使用 subPath 且需要热更新
# 方案 A: 移除 subPath，挂载整个目录
# 方案 B: 使用 sidecar 监听配置变化
# 方案 C: 应用自身支持配置文件监听
```

#### 场景 3：应用不重新加载配置

**解决方案：**

```bash
# 方案 1: 应用支持 SIGHUP 信号重新加载
kubectl exec <pod-name> -- kill -HUP 1

# 方案 2: 使用 inotify 监听文件变化
# 在应用中实现或使用 sidecar

# 方案 3: 使用 Prometheus Reload / 类似机制
curl -X POST http://<pod-ip>:<port>/-/reload

# 方案 4: 应用使用配置中心 (Consul/Apollo/Nacos)
# 而非直接读取文件
```

### 3.3 Secret 数据问题

#### 场景 1：Secret 数据编码问题

**问题现象：**
Secret 数据解码后是乱码或不完整

**解决步骤：**

```bash
# 1. 检查当前数据
kubectl get secret <name> -o jsonpath='{.data.password}' | base64 -d

# 2. 如果有换行符问题
kubectl get secret <name> -o jsonpath='{.data.password}' | base64 -d | xxd

# 3. 使用 stringData 创建 (无需手动编码)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
type: Opaque
stringData:
  password: "myP@ssw0rd"
  config.yaml: |
    database:
      host: localhost
      port: 3306
EOF

# 4. 正确编码包含特殊字符的值
echo -n 'myP@ssw0rd' | base64
# 注意: 使用 echo -n 避免换行符

# 5. 验证解码
kubectl get secret my-secret -o jsonpath='{.data.password}' | base64 -d && echo
```

#### 场景 2：创建 Docker Registry Secret

**解决步骤：**

```bash
# 1. 创建 docker-registry 类型的 Secret
kubectl create secret docker-registry my-registry-secret \
  --docker-server=registry.example.com \
  --docker-username=admin \
  --docker-password=password123 \
  --docker-email=admin@example.com \
  -n <namespace>

# 2. 验证 Secret 内容
kubectl get secret my-registry-secret -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq

# 3. 在 Pod 中使用
# spec:
#   imagePullSecrets:
#   - name: my-registry-secret

# 4. 或配置到 ServiceAccount
kubectl patch serviceaccount default -n <namespace> -p '{"imagePullSecrets": [{"name": "my-registry-secret"}]}'

# 5. 验证镜像拉取
kubectl run test --image=registry.example.com/myapp:v1 --restart=Never
```

### 3.4 权限问题

#### 场景 1：ServiceAccount 无权限访问 Secret

**问题现象：**
```
Error: secrets "my-secret" is forbidden: User "system:serviceaccount:default:myapp" cannot get resource "secrets"
```

**解决步骤：**

```bash
# 1. 创建 Role 允许访问特定 Secret
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: <namespace>
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["my-secret"]  # 限制特定 Secret
  verbs: ["get", "watch", "list"]
EOF

# 2. 绑定 Role 到 ServiceAccount
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-secrets
  namespace: <namespace>
subjects:
- kind: ServiceAccount
  name: myapp
  namespace: <namespace>
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
EOF

# 3. 验证权限
kubectl auth can-i get secrets/my-secret --as=system:serviceaccount:<namespace>:myapp -n <namespace>
```

### 3.5 完整配置示例

#### ConfigMap 使用示例

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # 简单键值对
  LOG_LEVEL: "info"
  DATABASE_HOST: "mysql.default.svc"
  
  # 多行配置文件
  app.properties: |
    server.port=8080
    spring.datasource.url=jdbc:mysql://mysql:3306/mydb
    
  # JSON 配置
  config.json: |
    {
      "debug": false,
      "timeout": 30
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:v1
        
        # 方式 1: 单个环境变量
        env:
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: LOG_LEVEL
              optional: false  # 如果 key 不存在则 Pod 启动失败
        
        # 方式 2: 批量导入所有 key 作为环境变量
        envFrom:
        - configMapRef:
            name: app-config
            optional: false
        
        # 方式 3: 卷挂载 (支持热更新)
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config
          readOnly: true
        
        # 方式 4: 挂载单个文件 (不支持热更新!)
        - name: config-volume
          mountPath: /app/config.json
          subPath: config.json
          
      volumes:
      - name: config-volume
        configMap:
          name: app-config
          # 可选: 只挂载特定 key
          items:
          - key: app.properties
            path: application.properties
          - key: config.json
            path: config.json
```

#### Secret 使用示例

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:  # 使用 stringData 无需 base64 编码
  DB_PASSWORD: "myP@ssw0rd"
  API_KEY: "sk-xxxxxxxxxxxx"
  
  # 证书文件
  tls.crt: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: DB_PASSWORD
              
        volumeMounts:
        - name: secret-volume
          mountPath: /etc/secrets
          readOnly: true
          
      volumes:
      - name: secret-volume
        secret:
          secretName: app-secret
          defaultMode: 0400  # 设置文件权限
```

### 3.6 不可变 ConfigMap/Secret

```yaml
# 不可变配置 (Kubernetes 1.21+)
apiVersion: v1
kind: ConfigMap
metadata:
  name: immutable-config
immutable: true  # 创建后无法修改
data:
  config.yaml: |
    version: 1.0
---
# 优势:
# 1. 防止意外修改
# 2. 显著提升集群性能 (kubelet 不再监听变化)
# 3. 适用于稳定配置

# 更新方式: 创建新的 ConfigMap，更新 Pod 引用
```

---

### 3.7 安全生产风险提示

| 操作 | 风险等级 | 风险说明 | 建议 |
|-----|---------|---------|-----|
| 删除 ConfigMap/Secret | 高 | 引用它的 Pod 可能启动失败 | 先确认无 Pod 引用，或设置 optional |
| 修改 Secret 数据 | 中 | 可能影响正在运行的服务认证 | 评估影响后分批更新 |
| 重启 Pod 应用配置 | 中 | 服务短暂中断 | 使用滚动更新，确保多副本 |
| 设置 immutable | 低 | 无法回滚修改 | 确认配置稳定后再设置 |
| 暴露 Secret 内容 | 高 | 敏感信息泄露 | 使用 RBAC 限制访问，审计日志 |
| 大文件存储 | 中 | 超过 etcd 限制，影响性能 | 大文件使用 PV 或外部存储 |

---

## 附录

### 常用命令速查

```bash
# ConfigMap 操作
kubectl create configmap <name> --from-file=<path>
kubectl create configmap <name> --from-literal=key=value
kubectl get configmap <name> -o yaml
kubectl edit configmap <name>
kubectl delete configmap <name>

# Secret 操作
kubectl create secret generic <name> --from-literal=key=value
kubectl create secret docker-registry <name> --docker-server=... --docker-username=... --docker-password=...
kubectl get secret <name> -o jsonpath='{.data.<key>}' | base64 -d

# 检查 Pod 配置
kubectl get pod <name> -o jsonpath='{.spec.containers[*].env}'
kubectl exec <pod> -- env | grep <KEY>
kubectl exec <pod> -- cat /path/to/config

# 触发 Pod 重启
kubectl rollout restart deployment <name>
```

### 相关文档

- [Pod 故障排查](./01-pod-troubleshooting.md)
- [RBAC 故障排查](../06-security-auth/01-rbac-troubleshooting.md)
- [kubelet 故障排查](../02-node-components/01-kubelet-troubleshooting.md)
