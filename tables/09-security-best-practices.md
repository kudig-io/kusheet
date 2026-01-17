# Kubernetes 安全最佳实践

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/security](https://kubernetes.io/docs/concepts/security/)

## 安全架构分层

```
┌─────────────────────────────────────────────────────────────────┐
│                   Kubernetes 安全分层架构                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    基础设施安全                           │    │
│  │  • 节点加固 • 网络隔离 • 证书管理 • 系统补丁           │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    集群安全                               │    │
│  │  • API Server 加固 • etcd 加密 • RBAC • 审计日志        │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    工作负载安全                           │    │
│  │  • Pod Security • NetworkPolicy • Secrets管理 • 镜像扫描│    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    应用安全                               │    │
│  │  • 容器安全配置 • 最小权限 • 运行时防护                 │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Pod Security Standards (PSS)

### 安全级别对比

| 控制项 | Privileged | Baseline | Restricted |
|--------|------------|----------|------------|
| HostProcess | 允许 | 禁止 | 禁止 |
| Host Namespaces | 允许 | 禁止 | 禁止 |
| Privileged Containers | 允许 | 禁止 | 禁止 |
| Capabilities | 允许所有 | 限制危险CAP | 仅允许NET_BIND_SERVICE |
| HostPath Volumes | 允许 | 允许 | 禁止 |
| Host Ports | 允许 | 允许(限制) | 禁止 |
| AppArmor | 不要求 | 不要求 | runtime/default |
| SELinux | 不要求 | 不要求 | 限制类型 |
| /proc Mount Type | 允许 | 允许 | Default |
| Seccomp | 不要求 | 不要求 | RuntimeDefault/Localhost |
| Sysctls | 允许所有 | 限制危险 | 仅安全sysctls |
| Volume Types | 允许所有 | 允许所有 | 限制类型 |
| Privilege Escalation | 允许 | 允许 | 禁止 |
| Running as Non-root | 不要求 | 不要求 | 必须 |
| Non-root Groups | 不要求 | 不要求 | 必须 |
| Seccomp | 不要求 | 不要求 | RuntimeDefault |

### Pod Security Admission 配置

```yaml
# 命名空间级别配置
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    # 强制执行 restricted 级别
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.30
    # 审计 baseline 违规
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/audit-version: v1.30
    # 警告 baseline 违规
    pod-security.kubernetes.io/warn: baseline
    pod-security.kubernetes.io/warn-version: v1.30
---
# 符合 restricted 级别的 Pod 示例
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: production
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
      privileged: false
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  automountServiceAccountToken: false
```

## RBAC 安全配置

### 最小权限原则实施

```yaml
# 应用专用 ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp-sa
  namespace: production
automountServiceAccountToken: false  # 默认不挂载token
---
# 最小权限 Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: myapp-role
  namespace: production
rules:
# 仅允许读取特定 ConfigMap
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["myapp-config"]  # 限制具体资源
  verbs: ["get"]
# 仅允许读取特定 Secret
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["myapp-secret"]
  verbs: ["get"]
---
# RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: myapp-binding
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: myapp-role
subjects:
- kind: ServiceAccount
  name: myapp-sa
  namespace: production
```

### 危险权限检查

| 权限组合 | 风险级别 | 风险说明 | 检查命令 |
|----------|----------|----------|----------|
| pods/exec + create | 危险 | 容器内执行命令 | `kubectl auth can-i create pods/exec` |
| secrets + get/list | 高危 | 读取所有凭证 | `kubectl auth can-i list secrets` |
| * + * | 极危 | 完全控制 | `kubectl auth can-i '*' '*'` |
| pods + create | 高危 | 创建特权Pod | `kubectl auth can-i create pods` |
| nodes/proxy | 危险 | 访问节点API | `kubectl auth can-i create nodes/proxy` |
| serviceaccounts/token | 高危 | 生成任意SA token | `kubectl auth can-i create serviceaccounts/token` |

### RBAC 审计脚本

```bash
#!/bin/bash
# rbac-audit.sh - RBAC 安全审计脚本

echo "=== cluster-admin 绑定 ==="
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | 
  select(.roleRef.name == "cluster-admin") | 
  .metadata.name + ": " + 
  ([.subjects[]? | .kind + "/" + .name] | join(", "))'

echo -e "\n=== 危险权限: secrets 完全访问 ==="
kubectl get clusterroles -o json | jq -r '
  .items[] | 
  select(.rules[]? | 
    select(.resources? | contains(["secrets"])) | 
    select(.verbs? | contains(["*"]) or contains(["list"]))
  ) | .metadata.name'

echo -e "\n=== 危险权限: pods/exec ==="
kubectl get clusterroles -o json | jq -r '
  .items[] | 
  select(.rules[]? | 
    select(.resources? | contains(["pods/exec"]))
  ) | .metadata.name'

echo -e "\n=== 非 kube-system 的 ClusterRoleBindings ==="
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | 
  select(.subjects[]?.namespace != "kube-system" and .subjects[]?.namespace != null) |
  .metadata.name'

echo -e "\n=== ServiceAccount 权限检查 ==="
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  for sa in $(kubectl get sa -n $ns -o jsonpath='{.items[*].metadata.name}'); do
    echo "检查 $ns/$sa:"
    kubectl auth can-i --list --as=system:serviceaccount:$ns:$sa 2>/dev/null | grep -v "no\|Resources" | head -5
  done
done
```

## Secrets 安全管理

### etcd 加密配置

```yaml
# /etc/kubernetes/encryption/config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  - configmaps
  providers:
  # 推荐: 使用 KMS
  - kms:
      apiVersion: v2
      name: alicloud-kms
      endpoint: unix:///var/run/kmsplugin/socket.sock
      timeout: 3s
  # 备选: 使用 AES-GCM
  - aesgcm:
      keys:
      - name: key1
        secret: c2VjcmV0IGlzIHNlY3VyZSwgYnV0IHlvdSBuZWVkIHRvIHJvdGF0ZQ==
  # 必须保留 identity 用于读取未加密数据
  - identity: {}
```

### External Secrets Operator 配置

```yaml
# SecretStore - 阿里云 KMS
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: alicloud-kms
  namespace: production
spec:
  provider:
    alibabacloud:
      regionID: cn-hangzhou
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: alicloud-credentials
            key: access-key-id
          accessKeySecretSecretRef:
            name: alicloud-credentials
            key: access-key-secret
---
# ExternalSecret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: alicloud-kms
  target:
    name: db-credentials
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: production/database/username
  - secretKey: password
    remoteRef:
      key: production/database/password
```

## 网络安全

### 默认拒绝策略

```yaml
# 默认拒绝所有入站和出站流量
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# 允许必要流量
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-traffic
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # 允许来自 Ingress Controller 的流量
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
      podSelector:
        matchLabels:
          app.kubernetes.io/name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  # 允许访问数据库
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
  # 允许 DNS 查询
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
```

## 审计配置

### 完整审计策略

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# 不审计的请求
- level: None
  users: ["system:kube-proxy"]
  verbs: ["watch"]
  resources:
  - group: ""
    resources: ["endpoints", "services", "services/status"]

- level: None
  users: ["kubelet"]
  verbs: ["get"]
  resources:
  - group: ""
    resources: ["nodes", "nodes/status"]

- level: None
  userGroups: ["system:nodes"]
  verbs: ["get"]
  resources:
  - group: ""
    resources: ["secrets"]

# 安全敏感操作 - 完整记录
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets", "serviceaccounts/token"]
  - group: "rbac.authorization.k8s.io"
    resources: ["*"]
  - group: "certificates.k8s.io"
    resources: ["*"]

# Pod 执行和附加 - 完整记录
- level: RequestResponse
  resources:
  - group: ""
    resources: ["pods/exec", "pods/attach", "pods/portforward"]

# 配置变更 - 请求级别
- level: Request
  verbs: ["create", "update", "patch", "delete"]
  resources:
  - group: ""
    resources: ["configmaps", "persistentvolumeclaims"]
  - group: "apps"
    resources: ["deployments", "statefulsets", "daemonsets"]
  - group: "networking.k8s.io"
    resources: ["ingresses", "networkpolicies"]

# 默认 - 元数据
- level: Metadata
  omitStages:
  - RequestReceived
```

## 镜像安全

### 镜像策略配置

```yaml
# Kyverno 镜像策略
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-trusted-registry
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: validate-image-registry
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "镜像必须来自可信仓库"
      pattern:
        spec:
          containers:
          - image: "registry.example.com/* | registry-vpc.cn-*.aliyuncs.com/*"
          initContainers:
          - image: "registry.example.com/* | registry-vpc.cn-*.aliyuncs.com/*"
---
# 禁止 latest 标签
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: Enforce
  rules:
  - name: require-image-tag
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "镜像必须指定明确的标签，不能使用 latest"
      pattern:
        spec:
          containers:
          - image: "!*:latest"
---
# 要求镜像签名 (Sigstore/Cosign)
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  webhookTimeoutSeconds: 30
  rules:
  - name: check-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "registry.example.com/*"
      attestors:
      - count: 1
        entries:
        - keys:
            publicKeys: |-
              -----BEGIN PUBLIC KEY-----
              MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA...
              -----END PUBLIC KEY-----
```

## CIS Benchmark 检查

| 编号 | 检查项 | 自动化检查 | 修复方法 |
|------|--------|-----------|----------|
| 1.1.1 | API Server 配置文件权限 | kube-bench | `chmod 600 /etc/kubernetes/manifests/kube-apiserver.yaml` |
| 1.2.1 | --anonymous-auth=false | kube-bench | API Server 启动参数 |
| 1.2.6 | --authorization-mode 包含 RBAC | kube-bench | API Server 启动参数 |
| 1.2.16 | --audit-log-path 已设置 | kube-bench | 启用审计日志 |
| 2.1 | etcd 证书认证 | kube-bench | 配置 etcd TLS |
| 2.4 | etcd 对等通信加密 | kube-bench | 配置 peer TLS |
| 4.2.1 | kubelet 认证配置 | kube-bench | --anonymous-auth=false |
| 4.2.6 | --protect-kernel-defaults=true | kube-bench | kubelet 配置 |
| 5.1.1 | 避免使用 cluster-admin | 手动 | 最小权限原则 |
| 5.2.1 | 最小化特权容器 | kube-bench | PSA/PSP |

```bash
# 运行 kube-bench
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl wait --for=condition=complete job/kube-bench -n default --timeout=300s
kubectl logs job/kube-bench

# Trivy 安全扫描
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: trivy-k8s-scan
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: trivy
        image: aquasec/trivy:latest
        args:
        - k8s
        - --report=all
        - --severity=HIGH,CRITICAL
        - cluster
EOF
```

## 安全监控告警

```yaml
groups:
- name: kubernetes-security
  rules:
  - alert: PrivilegedContainerCreated
    expr: |
      count(kube_pod_container_info{container!=""}) by (namespace, pod) 
      * on(namespace, pod) group_left 
      kube_pod_spec_containers_security_context_privileged == 1
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "检测到特权容器: {{ $labels.namespace }}/{{ $labels.pod }}"
      
  - alert: PodRunningAsRoot
    expr: |
      kube_pod_container_status_running == 1 
      and on(namespace, pod) 
      kube_pod_spec_containers_security_context_run_as_user == 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Pod 以 root 用户运行: {{ $labels.namespace }}/{{ $labels.pod }}"
      
  - alert: ClusterAdminBindingCreated
    expr: |
      increase(apiserver_audit_event_total{
        verb="create",
        objectRef_resource="clusterrolebindings"
      }[5m]) > 0
    for: 0m
    labels:
      severity: warning
    annotations:
      summary: "新建 ClusterRoleBinding"
      
  - alert: SecretAccessAnomaly
    expr: |
      sum(rate(apiserver_audit_event_total{
        verb=~"get|list",
        objectRef_resource="secrets"
      }[5m])) by (user_username) > 100
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "用户 {{ $labels.user_username }} Secret 访问异常"
      
  - alert: HostPathVolumeUsed
    expr: |
      kube_pod_spec_volumes_hostpaths_path_only > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Pod 使用 hostPath: {{ $labels.namespace }}/{{ $labels.pod }}"
```

## 安全检查清单

```bash
#!/bin/bash
# security-checklist.sh - 安全检查脚本

echo "=== Kubernetes 安全检查 ==="

echo -e "\n[1] API Server 匿名认证检查"
kubectl get pods -n kube-system -l component=kube-apiserver -o yaml | grep -i "anonymous-auth"

echo -e "\n[2] RBAC 启用检查"
kubectl api-versions | grep -q "rbac.authorization.k8s.io" && echo "RBAC: 已启用" || echo "RBAC: 未启用"

echo -e "\n[3] 审计日志检查"
kubectl get pods -n kube-system -l component=kube-apiserver -o yaml | grep -i "audit-log"

echo -e "\n[4] PSA 命名空间检查"
kubectl get ns --show-labels | grep -E "pod-security|enforce"

echo -e "\n[5] 特权 Pod 检查"
kubectl get pods -A -o json | jq -r '
  .items[] | 
  select(.spec.containers[]?.securityContext?.privileged == true) | 
  .metadata.namespace + "/" + .metadata.name'

echo -e "\n[6] cluster-admin 绑定检查"
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | select(.roleRef.name == "cluster-admin") | 
  .metadata.name + ": " + ([.subjects[]?.name] | join(", "))'

echo -e "\n[7] hostPath 卷检查"
kubectl get pods -A -o json | jq -r '
  .items[] | 
  select(.spec.volumes[]?.hostPath != null) | 
  .metadata.namespace + "/" + .metadata.name'

echo -e "\n[8] NetworkPolicy 覆盖率"
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v "^kube-"); do
  np_count=$(kubectl get networkpolicy -n $ns --no-headers 2>/dev/null | wc -l)
  echo "$ns: $np_count 个策略"
done

echo -e "\n=== 检查完成 ==="
```

## CVE和安全漏洞参考表

> **官方安全公告**: [https://github.com/kubernetes/kubernetes/security/advisories](https://github.com/kubernetes/kubernetes/security/advisories)

| CVE | 严重性 | 影响版本 | 描述 | 修复版本 | 缓解措施 | 生产影响 |
|-----|-------|---------|------|---------|---------|---------|
| **CVE-2024-21626** | Critical | runc ≤1.1.11 | 容器逃逸漏洞 | runc 1.1.12+ | 升级containerd/runc | 高危-紧急升级 |
| **CVE-2024-10220** | High | 多版本 | Webhook DoS | v1.29+ | API限流配置 | SLA影响 |
| **CVE-2023-2727** | High | ≤v1.27.3 | RBAC绕过漏洞 | v1.27.4+ | 审计RBAC配置 | 安全扫描失败 |
| **CVE-2023-3955** | Medium | ≤v1.28.1 | 信息泄露漏洞 | v1.28.2+ | API访问限制 | 合规问题 |
| **CVE-2022-0185** | Critical | Linux内核 | 容器逃逸漏洞 | Kernel patch | 启用PSA | 紧急-内核升级 |
| **CVE-2022-3294** | High | ≤v1.25.4 | Node授权绕过 | v1.25.5+ | 审计节点权限 | 集群安全 |
| **CVE-2022-3162** | Medium | ≤v1.25.3 | 目录遍历漏洞 | v1.25.4+ | 限制卷访问 | 数据安全 |
| **etcd CVE系列** | High | etcd 3.4/3.5 | 数据完整性 | 升级etcd | 定期备份 | 数据风险 |
| **kubelet CVE系列** | Medium | 多版本 | 特权绕过 | 升级kubelet | RBAC强化 | 节点安全 |
| **CSI CVE系列** | Medium | CSI插件 | 越权访问 | 插件升级 | 最小权限 | 存储安全 |
| **Ingress CVE系列** | High | NGINX等控制器 | RCE漏洞 | 控制器升级 | WAF防护 | 入口安全 |

### CVE响应流程

```bash
# CVE检查脚本
#!/bin/bash

echo "=== Kubernetes CVE 检查 ==="

# 1. 检查K8s版本
echo "[1] Kubernetes 版本检查"
kubectl version --short 2>/dev/null || kubectl version

# 2. 检查容器运行时版本
echo -e "\n[2] 容器运行时版本"
containerd --version 2>/dev/null || echo "containerd未安装"
runc --version 2>/dev/null || echo "runc版本检查"

# 3. 检查etcd版本
echo -e "\n[3] etcd版本"
kubectl exec -n kube-system etcd-master -- etcd --version 2>/dev/null || echo "检查etcd Pod日志"

# 4. 检查已知CVE
echo -e "\n[4] CVE公告检查"
echo "请访问: https://kubernetes.io/docs/reference/issues-security/official-cve-feed/"

# 5. 安全扫描
echo -e "\n[5] 镜像安全扫描"
echo "建议使用 Trivy 扫描集群镜像"

echo -e "\n=== 检查完成 ==="
```

---

**安全原则**: 最小权限，深度防御，持续监控，及时响应
