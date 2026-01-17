# 表格48: GitOps工作流

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [opengitops.dev](https://opengitops.dev/)

## GitOps核心原则

| 原则 | 说明 | 实践方式 |
|-----|------|---------|
| **声明式** | 描述期望状态而非操作步骤 | YAML/Helm/Kustomize |
| **版本化** | 所有配置存储在Git | Git仓库管理 |
| **自动拉取** | 自动检测变更并应用 | Reconciliation Loop |
| **持续协调** | 检测漂移并自动修复 | Self-Healing |

## GitOps工具对比

| 工具 | 架构 | 同步方式 | 多集群 | Helm支持 | 社区活跃度 |
|-----|------|---------|-------|---------|-----------|
| **ArgoCD** | Pull | 应用级 | ✅ | ✅ | ⭐⭐⭐⭐⭐ |
| **FluxCD v2** | Pull | Kustomize/Helm | ✅ | ✅ | ⭐⭐⭐⭐⭐ |
| **Jenkins X** | Push | Pipeline | ✅ | ✅ | ⭐⭐⭐ |
| **Rancher Fleet** | Pull | Bundle | ✅ | ✅ | ⭐⭐⭐⭐ |
| **Weave GitOps** | Pull | Flux封装 | ✅ | ✅ | ⭐⭐⭐⭐ |

## ArgoCD核心概念

| 概念 | 说明 |
|-----|------|
| Application | 部署单元,关联Git仓库和目标集群 |
| AppProject | 应用分组和权限控制 |
| Repository | Git仓库配置 |
| Cluster | 目标集群配置 |
| Sync | 同步操作 |
| Health | 健康状态 |

## ArgoCD Application配置

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: HEAD
    path: deploy/kubernetes
    # Helm方式
    # helm:
    #   valueFiles:
    #   - values-prod.yaml
    #   parameters:
    #   - name: image.tag
    #     value: v1.0.0
    # Kustomize方式
    # kustomize:
    #   images:
    #   - myapp=myregistry/myapp:v1.0.0
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true           # 自动删除多余资源
      selfHeal: true        # 自动修复漂移
      allowEmpty: false     # 禁止空应用
    syncOptions:
    - CreateNamespace=true
    - PruneLast=true
    - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

## ArgoCD AppProject配置

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  description: Production applications
  sourceRepos:
  - https://github.com/org/*
  - https://charts.bitnami.com/bitnami
  destinations:
  - namespace: '*'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  namespaceResourceBlacklist:
  - group: ''
    kind: ResourceQuota
  roles:
  - name: developer
    policies:
    - p, proj:production:developer, applications, get, production/*, allow
    - p, proj:production:developer, applications, sync, production/*, allow
    groups:
    - developers
```

## FluxCD核心组件

| 组件 | 功能 |
|-----|------|
| source-controller | 管理Git/Helm/OCI仓库 |
| kustomize-controller | Kustomize部署 |
| helm-controller | Helm Release管理 |
| notification-controller | 通知和事件 |
| image-automation-controller | 镜像自动更新 |
| image-reflector-controller | 镜像扫描 |

## FluxCD GitRepository配置

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: myapp
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/org/repo.git
  ref:
    branch: main
  secretRef:
    name: git-credentials
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: myapp
  namespace: flux-system
spec:
  interval: 10m
  targetNamespace: production
  sourceRef:
    kind: GitRepository
    name: myapp
  path: ./deploy/production
  prune: true
  healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: myapp
    namespace: production
  timeout: 2m
```

## FluxCD HelmRelease配置

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: myapp
  namespace: production
spec:
  interval: 5m
  chart:
    spec:
      chart: myapp
      version: '>=1.0.0 <2.0.0'
      sourceRef:
        kind: HelmRepository
        name: myrepo
        namespace: flux-system
  values:
    replicas: 3
    image:
      tag: v1.0.0
  valuesFrom:
  - kind: ConfigMap
    name: myapp-values
  upgrade:
    remediation:
      retries: 3
  rollback:
    cleanupOnFail: true
```

## 镜像自动更新

```yaml
# FluxCD镜像策略
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: myapp
  namespace: flux-system
spec:
  image: myregistry/myapp
  interval: 1m
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: myapp
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: myapp
  policy:
    semver:
      range: '>=1.0.0'
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageUpdateAutomation
metadata:
  name: myapp
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: myapp
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        name: fluxbot
        email: flux@example.com
      messageTemplate: 'Update image to {{range .Updated.Images}}{{println .}}{{end}}'
    push:
      branch: main
  update:
    path: ./deploy
    strategy: Setters
```

## GitOps最佳实践

| 实践 | 说明 | 实施方法 |
|-----|------|---------|
| **单一事实来源** | Git是唯一配置来源 | 禁止kubectl apply手动变更 |
| **声明式配置** | 描述期望状态 | 使用YAML/Helm/Kustomize |
| **版本控制** | 所有变更可追溯 | Git commit history |
| **PR审核** | 变更需要审批 | Branch Protection Rules |
| **自动同步** | 检测漂移自动修复 | selfHeal: true |
| **渐进式交付** | 金丝雀/蓝绿部署 | Argo Rollouts/Flagger |
| **多环境管理** | 分支/目录策略 | Kustomize overlays |
| **密钥管理** | 安全存储敏感信息 | Sealed Secrets/SOPS/ESO |

## 多环境管理策略

```
# 目录结构策略(推荐)
repo/
├── base/                    # 基础配置
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   └── production/
│       ├── kustomization.yaml
│       └── patches/
└── apps/                    # ArgoCD Application定义
    ├── dev.yaml
    ├── staging.yaml
    └── production.yaml
```

```yaml
# ApplicationSet实现多环境部署
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - cluster: dev
        url: https://dev-cluster.example.com
        namespace: myapp-dev
      - cluster: staging
        url: https://staging-cluster.example.com
        namespace: myapp-staging
      - cluster: production
        url: https://prod-cluster.example.com
        namespace: myapp-prod
  template:
    metadata:
      name: 'myapp-{{cluster}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/repo.git
        targetRevision: HEAD
        path: 'overlays/{{cluster}}'
      destination:
        server: '{{url}}'
        namespace: '{{namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

## 密钥管理方案

| 方案 | 加密方式 | 适用场景 | 复杂度 |
|-----|---------|---------|-------|
| **Sealed Secrets** | 非对称加密 | 简单场景 | 低 |
| **SOPS** | 多后端(KMS/PGP) | 灵活需求 | 中 |
| **External Secrets** | 外部密钥服务 | 企业级 | 中 |
| **Vault** | HashiCorp Vault | 完整密钥管理 | 高 |

```yaml
# Sealed Secrets示例
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: db-credentials
  namespace: production
spec:
  encryptedData:
    username: AgBy3i4OJSWK+PiTySYZZA9...
    password: AgBy3i4OJSWK+PiTySYZZA9...
---
# SOPS配置(.sops.yaml)
creation_rules:
  - path_regex: .*/secrets/.*\.yaml$
    kms: arn:aws:kms:us-east-1:123456:key/abc-123
    # 或使用阿里云KMS
    # alibaba_kms: acs:kms:cn-hangzhou:123456:key/abc-123
```

## 渐进式交付

```yaml
# Argo Rollouts金丝雀部署
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 10
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:v2
  strategy:
    canary:
      steps:
      - setWeight: 10      # 10%流量
      - pause: {duration: 5m}
      - setWeight: 30      # 30%流量
      - pause: {duration: 5m}
      - setWeight: 50      # 50%流量
      - pause: {duration: 10m}
      - setWeight: 100     # 全量
      canaryService: myapp-canary
      stableService: myapp-stable
      trafficRouting:
        istio:
          virtualService:
            name: myapp
            routes:
            - primary
      analysis:
        templates:
        - templateName: success-rate
        startingStep: 2
        args:
        - name: service-name
          value: myapp-canary
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  metrics:
  - name: success-rate
    interval: 1m
    successCondition: result[0] >= 0.95
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(http_requests_total{service="{{args.service-name}}",status=~"2.."}[5m])) /
          sum(rate(http_requests_total{service="{{args.service-name}}"}[5m]))
```

## ACK GitOps支持

| 功能 | 说明 | 配置方式 |
|-----|------|---------|
| **ArgoCD托管** | 一键部署 | 应用目录安装 |
| **FluxCD支持** | 应用目录安装 | Helm Chart |
| **多集群管理** | ACK One集成 | 联邦GitOps |
| **镜像扫描** | ACR集成 | 自动触发扫描 |
| **RRSA集成** | 无密钥访问 | OIDC配置 |

```bash
# ACK安装ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd --create-namespace

# ACK配置ArgoCD访问ACR
kubectl create secret docker-registry acr-credentials \
  --docker-server=registry.cn-hangzhou.aliyuncs.com \
  --docker-username=<username> \
  --docker-password=<password> \
  -n argocd

# 配置ArgoCD仓库凭证
argocd repo add https://github.com/org/repo.git \
  --username <username> \
  --password <token>
```

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| ArgoCD 2.8 | ApplicationSet改进,多源应用 |
| ArgoCD 2.9 | Server-Side Apply默认启用 |
| ArgoCD 2.10 | 改进的Diff算法 |
| FluxCD 2.2 | OCI仓库GA支持 |
| FluxCD 2.3 | 改进的垃圾回收 |

---

**GitOps原则**: Git是唯一事实来源 + 声明式配置 + 自动同步 + 渐进式交付 + 安全密钥管理
