# Pod 安全与 SecurityContext 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 中级-高级
>
> **版本说明**:
> - v1.25+ Pod Security Admission (PSA) GA，替代 PodSecurityPolicy
> - v1.25+ PodSecurityPolicy (PSP) 已移除
> - v1.28+ 支持 AppArmor 作为 GA 特性
> - v1.30+ 支持 user namespace (Alpha→Beta)

## 概述

Kubernetes 通过 Pod Security Standards (PSS)、SecurityContext 和 Pod Security Admission (PSA) 控制 Pod 的安全配置。安全配置不当会导致 Pod 无法启动、权限不足或安全风险。本文档覆盖 Pod 安全相关故障的诊断与解决方案。

---

## 第一部分：问题现象与影响分析

### 1.1 Pod 安全控制体系

```
┌─────────────────────────────────────────────────────────────────┐
│                    Pod 安全控制层次                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │         Pod Security Admission (PSA) - 命名空间级别         │ │
│  │                                                             │ │
│  │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │ │
│  │   │  Privileged │  │  Baseline   │  │  Restricted │        │ │
│  │   │  (最宽松)    │  │  (默认安全)  │  │  (最严格)   │        │ │
│  │   └─────────────┘  └─────────────┘  └─────────────┘        │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│                              ▼                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              SecurityContext - Pod/Container 级别           │ │
│  │                                                             │ │
│  │  Pod 级别:                    Container 级别:                │ │
│  │  - runAsUser/runAsGroup       - runAsUser/runAsGroup        │ │
│  │  - runAsNonRoot               - runAsNonRoot                │ │
│  │  - fsGroup                    - privileged                  │ │
│  │  - sysctls                    - capabilities                │ │
│  │  - seccompProfile             - readOnlyRootFilesystem      │ │
│  │  - seLinuxOptions             - allowPrivilegeEscalation    │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 错误信息示例 | 查看方式 |
|---------|---------|-------------|---------|
| PSA 拒绝 | Pod 创建被拒绝 | `violates PodSecurity "restricted"` | `kubectl apply` 输出 |
| 权限不足 | 容器操作失败 | `permission denied` | 容器日志 |
| UID/GID 问题 | 文件访问失败 | `cannot open file: permission denied` | 容器日志 |
| Capabilities 缺失 | 特权操作失败 | `operation not permitted` | 容器日志 |
| 只读文件系统 | 写入失败 | `read-only file system` | 容器日志 |
| SELinux 冲突 | 资源访问被拒 | `SELinux policy denial` | 主机日志 |
| Seccomp 限制 | 系统调用被阻止 | `operation not permitted` | 容器日志 |
| 特权容器被拒 | Pod 无法创建 | `privileged containers are not allowed` | 事件 |

### 1.3 Pod Security Standards 级别

| 级别 | 说明 | 限制内容 |
|-----|-----|---------|
| Privileged | 完全不受限 | 无限制，允许所有特权操作 |
| Baseline | 防止已知提权 | 禁止 hostNetwork/hostPID/hostIPC/privileged 等 |
| Restricted | 最佳安全实践 | 必须 runAsNonRoot、禁止特权、限制 capabilities 等 |

### 1.4 影响分析

| 故障类型 | 直接影响 | 间接影响 | 影响范围 |
|---------|---------|---------|---------|
| PSA 拒绝 Pod | Pod 无法创建 | 服务不可用 | 受 PSA 策略保护的命名空间 |
| 权限不足 | 应用功能异常 | 服务部分不可用 | 单个 Pod |
| 特权操作被拒 | 系统级操作失败 | 监控/日志采集等功能失效 | 需要特权的 DaemonSet |
| 安全配置过松 | 潜在安全风险 | 容器逃逸/提权风险 | 整个集群安全 |

---

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
Pod 安全故障
      │
      ├─── Pod 创建被拒绝？
      │         │
      │         ├─ PSA violation ──→ 检查命名空间 PSA 配置
      │         ├─ Webhook 拒绝 ──→ 检查准入控制 Webhook
      │         └─ 配置冲突 ──→ 检查 SecurityContext 配置
      │
      ├─── 容器运行时权限问题？
      │         │
      │         ├─ permission denied ──→ 检查 runAsUser/fsGroup
      │         ├─ operation not permitted ──→ 检查 capabilities/seccomp
      │         ├─ read-only file system ──→ 检查 readOnlyRootFilesystem
      │         └─ SELinux denial ──→ 检查 seLinuxOptions
      │
      └─── 需要特权操作？
                │
                ├─ 确认必要性 ──→ 评估安全风险
                ├─ 配置最小权限 ──→ 只授予必要 capabilities
                └─ 使用豁免 ──→ 配置 PSA exemptions
```

### 2.2 排查命令集

#### 2.2.1 PSA 配置检查

```bash
# 查看命名空间的 PSA 配置
kubectl get namespace <namespace> -o yaml | grep -A5 "labels:"

# 检查 PSA 标签
kubectl get namespace <namespace> -o jsonpath='{.metadata.labels}' | jq

# PSA 标签格式:
# pod-security.kubernetes.io/enforce: restricted
# pod-security.kubernetes.io/audit: restricted
# pod-security.kubernetes.io/warn: restricted

# 列出所有有 PSA 配置的命名空间
kubectl get namespaces -L pod-security.kubernetes.io/enforce
```

#### 2.2.2 SecurityContext 检查

```bash
# 查看 Pod 的 SecurityContext
kubectl get pod <pod-name> -o jsonpath='{.spec.securityContext}' | jq

# 查看容器的 SecurityContext
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].securityContext}' | jq

# 查看运行中容器的实际 UID
kubectl exec <pod-name> -- id

# 查看进程权限
kubectl exec <pod-name> -- cat /proc/1/status | grep -E "Uid|Gid|Cap"

# 检查 capabilities
kubectl exec <pod-name> -- cat /proc/1/status | grep Cap
# 解码 capabilities
capsh --decode=<hex-value>
```

#### 2.2.3 文件权限检查

```bash
# 检查挂载卷的权限
kubectl exec <pod-name> -- ls -la /path/to/volume

# 检查文件所有者
kubectl exec <pod-name> -- stat /path/to/file

# 检查进程运行用户
kubectl exec <pod-name> -- ps aux
```

#### 2.2.4 安全审计

```bash
# 查看 Pod 安全相关事件
kubectl get events --field-selector reason=FailedCreate | grep -i security

# 查看 API Server 审计日志 (如果启用)
kubectl logs -n kube-system kube-apiserver-<node> | grep -i "pod-security"

# 检查 OPA/Gatekeeper 约束
kubectl get constraints
kubectl describe constraint <name>
```

### 2.3 排查注意事项

| 注意事项 | 说明 |
|---------|-----|
| PSA 模式 | enforce(拒绝)、audit(审计)、warn(警告) 三种模式 |
| 继承关系 | 容器 SecurityContext 会覆盖 Pod 级别配置 |
| UID 0 | root 用户 UID=0，restricted 策略禁止 |
| fsGroup | 影响挂载卷的组所有权 |
| 特权必要性 | 评估是否真正需要特权，考虑最小权限原则 |

---

## 第三部分：解决方案与风险控制

### 3.1 PSA 策略问题

#### 场景 1：Pod 被 PSA 拒绝

**问题现象：**
```
Error: pods "myapp" is forbidden: violates PodSecurity "restricted:latest": 
  allowPrivilegeEscalation != false 
  unrestricted capabilities
  runAsNonRoot != true
```

**解决步骤：**

```bash
# 1. 查看命名空间 PSA 配置
kubectl get namespace <namespace> -o yaml | grep pod-security

# 2. 方案 A: 修改 Pod 配置满足 restricted 要求
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: myapp:v1
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
EOF

# 3. 方案 B: 降低命名空间 PSA 级别 (不推荐生产环境)
kubectl label namespace <namespace> \
  pod-security.kubernetes.io/enforce=baseline \
  --overwrite

# 4. 方案 C: 使用 warn/audit 模式先观察
kubectl label namespace <namespace> \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted \
  --overwrite
```

#### 场景 2：系统组件需要特权

**解决步骤：**

```bash
# 1. 为系统命名空间设置 privileged 级别
kubectl label namespace kube-system \
  pod-security.kubernetes.io/enforce=privileged \
  --overwrite

# 2. 或配置 PSA 豁免 (需要修改 API Server 配置)
# /etc/kubernetes/manifests/kube-apiserver.yaml
# --admission-control-config-file=/etc/kubernetes/psa-config.yaml

# psa-config.yaml 示例:
cat <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: PodSecurity
  configuration:
    apiVersion: pod-security.admission.config.k8s.io/v1
    kind: PodSecurityConfiguration
    defaults:
      enforce: "restricted"
      enforce-version: "latest"
    exemptions:
      usernames: []
      runtimeClasses: []
      namespaces:
      - kube-system
      - monitoring
EOF
```

### 3.2 权限问题

#### 场景 1：文件访问权限不足

**问题现象：**
```
Error: cannot open /data/config.json: permission denied
```

**解决步骤：**

```bash
# 1. 检查当前运行用户
kubectl exec <pod-name> -- id

# 2. 检查文件权限
kubectl exec <pod-name> -- ls -la /data/

# 3. 方案 A: 设置正确的 runAsUser/runAsGroup
kubectl patch deployment <name> --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/securityContext", "value": {
    "runAsUser": 1000,
    "runAsGroup": 1000,
    "fsGroup": 1000
  }}
]'

# 4. 方案 B: 使用 initContainer 修改权限
# spec:
#   initContainers:
#   - name: fix-permissions
#     image: busybox
#     command: ["sh", "-c", "chown -R 1000:1000 /data"]
#     volumeMounts:
#     - name: data
#       mountPath: /data
#     securityContext:
#       runAsUser: 0

# 5. 方案 C: 设置 fsGroup (对挂载卷生效)
# spec:
#   securityContext:
#     fsGroup: 1000  # 挂载卷的组所有权
```

#### 场景 2：需要特定 Capabilities

**问题现象：**
```
Error: operation not permitted (binding to port 80)
```

**解决步骤：**

```bash
# 1. 确认需要哪个 capability
# 绑定低端口: NET_BIND_SERVICE
# 网络操作: NET_ADMIN, NET_RAW
# 系统管理: SYS_ADMIN

# 2. 添加最小必要 capabilities
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: app
    image: myapp:v1
    securityContext:
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE  # 只添加必要的
    ports:
    - containerPort: 80
EOF

# 3. 或者使用高端口避免需要特权
# 在容器内监听 8080，通过 Service 映射到 80

# 4. 常用 capabilities 参考
# NET_BIND_SERVICE: 绑定 <1024 端口
# NET_ADMIN: 网络配置
# NET_RAW: 使用 RAW socket (ping)
# SYS_ADMIN: 挂载操作等
# SYS_PTRACE: 调试
# CHOWN: 改变文件所有权
# DAC_OVERRIDE: 绕过文件权限检查
# SETUID/SETGID: 改变 UID/GID
```

### 3.3 只读文件系统问题

#### 场景 1：readOnlyRootFilesystem 导致写入失败

**问题现象：**
```
Error: read-only file system
```

**解决步骤：**

```bash
# 1. 检查是否设置了 readOnlyRootFilesystem
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].securityContext.readOnlyRootFilesystem}'

# 2. 方案 A: 使用 emptyDir 作为可写目录
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: app
    image: myapp:v1
    securityContext:
      readOnlyRootFilesystem: true  # 保持只读
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache
    - name: logs
      mountPath: /var/log
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: logs
    emptyDir: {}
EOF

# 3. 方案 B: 关闭只读 (降低安全性，不推荐)
# securityContext:
#   readOnlyRootFilesystem: false

# 4. 常见需要写入的目录
# /tmp - 临时文件
# /var/cache - 缓存
# /var/log - 日志
# /var/run - PID 文件
# /home/<user> - 用户目录
```

### 3.4 Seccomp 配置

#### 场景 1：Seccomp 阻止系统调用

**问题现象：**
应用报错 "operation not permitted" 但没有明显权限问题

**解决步骤：**

```bash
# 1. 检查当前 seccomp 配置
kubectl get pod <pod-name> -o jsonpath='{.spec.securityContext.seccompProfile}'

# 2. 使用 RuntimeDefault (推荐)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault  # 使用容器运行时默认配置
  containers:
  - name: app
    image: myapp:v1
EOF

# 3. 临时禁用 seccomp (不推荐，仅用于调试)
# seccompProfile:
#   type: Unconfined

# 4. 使用自定义 seccomp 配置文件
# 需要在节点上放置配置文件 /var/lib/kubelet/seccomp/myprofile.json
# seccompProfile:
#   type: Localhost
#   localhostProfile: myprofile.json
```

### 3.5 特权容器场景

#### 场景 1：需要特权容器的正确配置

```yaml
# 仅在必要时使用特权容器
# 常见场景: CNI 插件、存储驱动、监控代理

apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
spec:
  # 建议: 尽可能使用最小权限
  containers:
  - name: app
    image: myapp:v1
    securityContext:
      # 完全特权模式 (应避免)
      # privileged: true
      
      # 推荐: 只授予必要权限
      capabilities:
        add:
        - NET_ADMIN
        - SYS_ADMIN
        drop:
        - ALL
      
      # 如果需要访问主机设备
      # privileged: true  # 或挂载特定设备

  # 如需访问主机命名空间 (谨慎使用)
  # hostNetwork: true
  # hostPID: true
  # hostIPC: true
```

### 3.6 完整的安全配置示例

#### Restricted 级别 Pod 配置

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  # Pod 级别安全配置
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
    # 可选: SELinux 配置
    # seLinuxOptions:
    #   level: "s0:c123,c456"
  
  containers:
  - name: app
    image: myapp:v1
    
    # 容器级别安全配置
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
        # 只添加必需的 capabilities
        # add:
        # - NET_BIND_SERVICE
    
    # 资源限制 (也是安全实践)
    resources:
      limits:
        cpu: "1"
        memory: "512Mi"
      requests:
        cpu: "100m"
        memory: "128Mi"
    
    # 可写目录
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/app
  
  volumes:
  - name: tmp
    emptyDir:
      sizeLimit: 100Mi
  - name: cache
    emptyDir:
      sizeLimit: 500Mi
  
  # 使用非 root ServiceAccount
  serviceAccountName: app-sa
  automountServiceAccountToken: false  # 如不需要 API 访问
```

#### 命名空间 PSA 配置

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    # 强制执行 restricted 策略
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    
    # 审计和警告也使用 restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
```

---

### 3.7 安全最佳实践检查清单

```bash
# 1. 检查是否使用 root 运行
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.securityContext.runAsUser}{"\n"}{end}' | grep -E "\t0$|\t$"

# 2. 检查特权容器
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[*].securityContext.privileged}{"\n"}{end}' | grep true

# 3. 检查 hostNetwork/hostPID/hostIPC
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.hostNetwork==true or .spec.hostPID==true or .spec.hostIPC==true) | "\(.metadata.namespace)/\(.metadata.name)"'

# 4. 检查 allowPrivilegeEscalation
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[*].securityContext.allowPrivilegeEscalation}{"\n"}{end}' | grep -v false

# 5. 检查命名空间 PSA 配置
kubectl get namespaces -L pod-security.kubernetes.io/enforce
```

---

### 3.8 安全生产风险提示

| 操作 | 风险等级 | 风险说明 | 建议 |
|-----|---------|---------|-----|
| 使用 privileged: true | 高 | 容器获得主机完全权限，可能逃逸 | 仅在绝对必要时使用 |
| 使用 hostNetwork | 高 | 容器共享主机网络，端口冲突风险 | 评估替代方案 |
| 设置 runAsUser: 0 | 中 | root 权限增加攻击面 | 使用非 root 用户 |
| 添加 SYS_ADMIN | 高 | 近似 root 权限 | 细化到具体所需能力 |
| 禁用 readOnlyRootFilesystem | 低 | 可能被写入恶意文件 | 使用 emptyDir 替代 |
| 放宽 PSA 策略 | 中 | 降低命名空间安全基线 | 只放宽到必要级别 |

---

## 附录

### 常用命令速查

```bash
# 检查 PSA 配置
kubectl get namespace <ns> -L pod-security.kubernetes.io/enforce

# 配置 PSA
kubectl label namespace <ns> pod-security.kubernetes.io/enforce=restricted

# 检查 SecurityContext
kubectl get pod <pod> -o jsonpath='{.spec.securityContext}'
kubectl get pod <pod> -o jsonpath='{.spec.containers[*].securityContext}'

# 容器内检查
kubectl exec <pod> -- id
kubectl exec <pod> -- cat /proc/1/status | grep Cap

# 解码 Capabilities
capsh --decode=<hex>
```

### 相关文档

- [Pod 故障排查](../05-workloads/01-pod-troubleshooting.md)
- [RBAC 故障排查](./01-rbac-troubleshooting.md)
- [Webhook/准入控制故障排查](../01-control-plane/05-webhook-admission-troubleshooting.md)
