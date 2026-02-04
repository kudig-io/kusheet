# 50 - 策略引擎与合规

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/policy](https://kubernetes.io/docs/concepts/policy/)

## 策略引擎对比

| 引擎 | 语言 | 架构 | 适用场景 | 学习曲线 | 社区活跃度 |
|-----|-----|------|---------|---------|-----------|
| **OPA/Gatekeeper** | Rego | Webhook | 通用策略,跨平台 | 高 | ⭐⭐⭐⭐⭐ |
| **Kyverno** | YAML/CEL | Webhook | K8s原生策略 | 低 | ⭐⭐⭐⭐⭐ |
| **Kubewarden** | Wasm | Webhook | 多语言策略 | 中 | ⭐⭐⭐ |
| **ValidatingAdmissionPolicy** | CEL | 内置 | 简单验证,无外部依赖 | 低 | K8s原生 |
| **Polaris** | YAML | CLI/Webhook | 最佳实践检查 | 低 | ⭐⭐⭐⭐ |

## 策略引擎选型建议

| 场景 | 推荐引擎 | 原因 |
|-----|---------|------|
| K8s原生,简单策略 | ValidatingAdmissionPolicy | 无外部依赖,v1.30 GA |
| K8s专用,完整功能 | Kyverno | YAML易学,功能全面 |
| 跨平台策略复用 | OPA/Gatekeeper | Rego策略可复用 |
| 多语言策略开发 | Kubewarden | Wasm支持多语言 |

## Gatekeeper架构组件

| 组件 | 功能 |
|-----|------|
| ConstraintTemplate | 定义策略模板(Rego) |
| Constraint | 实例化策略 |
| Config | 同步资源到OPA |
| Audit | 审计现有资源 |
| Mutation | 变更资源(Beta) |

## Gatekeeper ConstraintTemplate

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8srequiredlabels
      
      violation[{"msg": msg, "details": {"missing_labels": missing}}] {
        provided := {label | input.review.object.metadata.labels[label]}
        required := {label | label := input.parameters.labels[_]}
        missing := required - provided
        count(missing) > 0
        msg := sprintf("Missing required labels: %v", [missing])
      }
```

## Gatekeeper Constraint

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-team-label
spec:
  enforcementAction: deny  # deny/dryrun/warn
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Namespace"]
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
    excludedNamespaces:
    - kube-system
    - gatekeeper-system
  parameters:
    labels:
    - team
    - environment
```

## Kyverno策略类型

| 类型 | 用途 | 示例 |
|-----|------|------|
| validate | 验证资源 | 要求标签存在 |
| mutate | 修改资源 | 添加默认标签 |
| generate | 生成资源 | 自动创建NetworkPolicy |
| verifyImages | 镜像签名验证 | cosign验证 |

## Kyverno ClusterPolicy示例

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: Enforce  # Enforce/Audit
  background: true
  rules:
  - name: check-team-label
    match:
      any:
      - resources:
          kinds:
          - Deployment
          - StatefulSet
    exclude:
      any:
      - resources:
          namespaces:
          - kube-system
    validate:
      message: "Label 'team' is required"
      pattern:
        metadata:
          labels:
            team: "?*"
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-default-resources
spec:
  rules:
  - name: add-default-limits
    match:
      any:
      - resources:
          kinds:
          - Pod
    mutate:
      patchStrategicMerge:
        spec:
          containers:
          - (name): "*"
            resources:
              limits:
                +(memory): "256Mi"
                +(cpu): "200m"
```

## Kyverno镜像签名验证

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  webhookTimeoutSeconds: 30
  rules:
  - name: verify-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "myregistry.io/*"
      attestors:
      - entries:
        - keyless:
            subject: "*@example.com"
            issuer: "https://accounts.google.com"
            rekor:
              url: https://rekor.sigstore.dev
```

## ValidatingAdmissionPolicy (K8s原生)

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-runasnonroot
spec:
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  - expression: "object.spec.containers.all(c, has(c.securityContext) && has(c.securityContext.runAsNonRoot) && c.securityContext.runAsNonRoot == true)"
    message: "All containers must run as non-root"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-runasnonroot-binding
spec:
  policyName: require-runasnonroot
  validationActions:
  - Deny
  matchResources:
    namespaceSelector:
      matchLabels:
        policy: enforced
```

## 常见合规策略

| 策略类别 | 策略示例 | Gatekeeper | Kyverno | VAP |
|---------|---------|-----------|---------|-----|
| **安全基线** | 禁止特权容器 | ✅ | ✅ | ✅ |
| **资源管理** | 要求资源限制 | ✅ | ✅ | ✅ |
| **命名规范** | 标签/注解要求 | ✅ | ✅ | ✅ |
| **镜像安全** | 镜像仓库白名单 | ✅ | ✅ | ✅ |
| **镜像签名** | cosign签名验证 | ✅ | ✅ | ❌ |
| **网络安全** | 要求NetworkPolicy | ✅ | ✅ | ❌ |
| **存储安全** | 禁止hostPath | ✅ | ✅ | ✅ |
| **运行时安全** | 只读根文件系统 | ✅ | ✅ | ✅ |
| **资源生成** | 自动创建资源 | ❌ | ✅ | ❌ |

## 完整策略库示例

```yaml
# Kyverno: Pod安全基线策略集
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged-containers
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: privileged-containers
    match:
      any:
      - resources:
          kinds: [Pod]
    validate:
      message: "特权容器被禁止"
      pattern:
        spec:
          containers:
          - securityContext:
              privileged: "false"
          =(initContainers):
          - securityContext:
              privileged: "false"
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-host-namespaces
spec:
  validationFailureAction: Enforce
  rules:
  - name: host-namespaces
    match:
      any:
      - resources:
          kinds: [Pod]
    validate:
      message: "禁止使用Host命名空间"
      pattern:
        spec:
          =(hostPID): false
          =(hostIPC): false
          =(hostNetwork): false
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: Enforce
  rules:
  - name: validate-resources
    match:
      any:
      - resources:
          kinds: [Pod]
    validate:
      message: "必须设置CPU和内存限制"
      pattern:
        spec:
          containers:
          - resources:
              limits:
                memory: "?*"
                cpu: "?*"
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-image-registries
spec:
  validationFailureAction: Enforce
  rules:
  - name: validate-registries
    match:
      any:
      - resources:
          kinds: [Pod]
    validate:
      message: "镜像必须来自允许的仓库"
      pattern:
        spec:
          containers:
          - image: "registry.example.com/* | gcr.io/my-project/*"
---
# Kyverno: 自动添加默认配置
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-network-policy
spec:
  rules:
  - name: generate-networkpolicy
    match:
      any:
      - resources:
          kinds: [Namespace]
    exclude:
      any:
      - resources:
          namespaces: [kube-system, kube-public]
    generate:
      apiVersion: networking.k8s.io/v1
      kind: NetworkPolicy
      name: default-deny-ingress
      namespace: "{{request.object.metadata.name}}"
      data:
        spec:
          podSelector: {}
          policyTypes:
          - Ingress
```

## CIS Kubernetes Benchmark

| 章节 | 检查项数 | 说明 | 自动化检测 |
|-----|---------|------|-----------|
| 1. 控制平面组件 | 89 | API Server/etcd等配置 | kube-bench |
| 2. etcd | 7 | etcd安全配置 | kube-bench |
| 3. 控制平面配置 | 12 | 认证授权配置 | kube-bench |
| 4. 工作节点 | 26 | kubelet安全配置 | kube-bench |
| 5. 策略 | 28 | RBAC/PSA/NetworkPolicy | Gatekeeper/Kyverno |

```bash
# kube-bench检测
# 主节点检测
kube-bench run --targets master

# 工作节点检测
kube-bench run --targets node

# 全面检测并输出JSON
kube-bench run --json > results.json

# ACK托管集群检测
kube-bench run --benchmark ack-1.0
```

## 策略审计与报告

```yaml
# Gatekeeper审计配置
apiVersion: config.gatekeeper.sh/v1alpha1
kind: Config
metadata:
  name: config
  namespace: gatekeeper-system
spec:
  sync:
    syncOnly:
    - group: ""
      version: "v1"
      kind: "Namespace"
    - group: "apps"
      version: "v1"
      kind: "Deployment"
  # 审计间隔
  match:
  - excludedNamespaces: ["kube-system", "gatekeeper-system"]
---
# Kyverno策略报告
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: check-deprecated-apis
spec:
  validationFailureAction: Audit  # 仅审计不阻断
  background: true
  rules:
  - name: check-deprecated
    match:
      any:
      - resources:
          kinds: [Ingress]
    validate:
      message: "使用了已废弃的API版本"
      deny:
        conditions:
        - key: "{{request.object.apiVersion}}"
          operator: Equals
          value: "extensions/v1beta1"
```

```bash
# 查看Kyverno策略报告
kubectl get polr -A                    # PolicyReport
kubectl get cpolr                      # ClusterPolicyReport

# 查看Gatekeeper约束违规
kubectl get constraints -o wide
kubectl describe k8srequiredlabels require-team-label
```

## ACK安全策略

| 功能 | 说明 | 配置方式 |
|-----|------|---------|
| **内置策略库** | 预定义安全策略 | 控制台一键启用 |
| **策略审计** | 合规检查报告 | 安全中心 |
| **Gatekeeper托管** | 一键部署 | 组件管理 |
| **Kyverno托管** | 一键部署 | 组件管理 |
| **镜像签名** | ACR签名集成 | notation/cosign |
| **安全基线** | CIS Benchmark检测 | 安全中心 |

```bash
# ACK安装Gatekeeper
# 控制台: 集群 -> 运维管理 -> 组件管理 -> 安装gatekeeper

# ACK安装Kyverno  
# 控制台: 集群 -> 应用目录 -> 搜索kyverno -> 安装

# ACK内置策略启用
# 控制台: 集群 -> 安全管理 -> 策略管理 -> 启用策略
```

## 版本变更记录

| 版本 | 变更内容 | 影响 |
|------|---------|------|
| v1.25 | PodSecurity Admission GA | PSP替代方案 |
| v1.26 | ValidatingAdmissionPolicy Alpha | 原生CEL策略 |
| v1.28 | ValidatingAdmissionPolicy Beta | 生产预览 |
| v1.30 | ValidatingAdmissionPolicy GA | 推荐使用 |
| v1.31 | MutatingAdmissionPolicy Alpha | 原生变更策略 |

---

**策略管理原则**: 最小权限 + 纵深防御 + 持续审计 + 自动化合规检测

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)