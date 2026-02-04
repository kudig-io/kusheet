# GitOps配置管理 (GitOps Configuration Management)

## 概述

GitOps是一种基于Git的运维理念和实践方法，通过将基础设施和应用程序配置存储在Git仓库中，实现声明式的配置管理和自动化的部署流程。

## 核心理念

### 声明式配置
```
期望状态(Declarative) → 实际状态 → 自动同步
```

### Git作为单一事实来源
- 所有配置变更都通过Git提交
- 完整的变更历史和审计跟踪
- 基于Pull Request的协作流程

### 自动化同步
- 持续监控实际状态与期望状态的差异
- 自动应用配置变更
- 状态漂移自动检测和修复

## ArgoCD实现

### 架构组成
```
Git Repository → ArgoCD Server → Kubernetes Cluster
     ↑                ↓
Web UI/CLI ← Status Monitoring ← Health Checks
```

### 核心组件
```yaml
# ArgoCD部署配置
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-server
spec:
  replicas: 2
  selector:
    matchLabels:
      app: argocd-server
  template:
    metadata:
      labels:
        app: argocd-server
    spec:
      containers:
      - name: argocd-server
        image: quay.io/argoproj/argocd:v2.7.0
        ports:
        - containerPort: 8080
        - containerPort: 8083
        command:
        - argocd-server
        - --insecure
        - --staticassets
        - /shared/app
```

### Application配置
```yaml
# 应用定义示例
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas
```

### 项目管理
```yaml
# 项目配置
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  description: Production project
  sourceRepos:
  - 'https://github.com/myorg/production-apps.git'
  destinations:
  - namespace: 'production-*'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  namespaceResourceBlacklist:
  - group: ''
    kind: ResourceQuota
  roles:
  - name: app-developer
    policies:
    - p, proj:production:app-developer, applications, get, production/*, allow
    - p, proj:production:app-developer, applications, sync, production/*, allow
    groups:
    - myorg:app-developers
```

## FluxCD实现

### 核心组件
```yaml
# FluxCD部署
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flux
spec:
  replicas: 1
  selector:
    matchLabels:
      name: flux
  template:
    metadata:
      labels:
        name: flux
    spec:
      serviceAccountName: flux
      volumes:
      - name: git-key
        secret:
          secretName: flux-git-deploy
      containers:
      - name: flux
        image: fluxcd/flux:1.25.0
        ports:
        - containerPort: 3030
        volumeMounts:
        - name: git-key
          mountPath: /etc/fluxd/ssh
          readOnly: true
        args:
        - --git-url=git@github.com:myorg/myrepo
        - --git-path=clusters/production
        - --git-branch=main
        - --sync-garbage-collection
```

### HelmRelease配置
```yaml
# Helm Release管理
apiVersion: helm.fluxcd.io/v1
kind: HelmRelease
metadata:
  name: podinfo
  namespace: default
spec:
  releaseName: podinfo
  chart:
    repository: https://stefanprodan.github.io/podinfo
    name: podinfo
    version: 4.0.6
  values:
    replicaCount: 2
    image:
      repository: stefanprodan/podinfo
      tag: 5.0.3
    service:
      type: ClusterIP
      port: 9898
  rollback:
    enable: true
    retries: 5
  timeout: 300
```

### Kustomize配置
```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
- ingress.yaml

namespace: production

commonLabels:
  app: myapp
  version: v1.0.0

images:
- name: myapp
  newName: myregistry/myapp
  newTag: v1.0.0

patchesStrategicMerge:
- patch-deployment.yaml
```

## 配置仓库结构

### 标准目录结构
```
infrastructure/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   └── rbac/
├── overlays/
│   ├── dev/
│   ├── staging/
│   └── prod/
applications/
├── app1/
│   ├── base/
│   └── overlays/
└── app2/
    ├── base/
    └── overlays/
clusters/
├── dev/
│   ├── infrastructure.yaml
│   └── applications.yaml
├── staging/
└── prod/
```

### 环境差异化配置
```yaml
# base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"

---
# overlays/prod/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: myapp
        resources:
          requests:
            memory: "256Mi"
            cpu: "500m"
          limits:
            memory: "512Mi"
            cpu: "1000m"
```

## 安全最佳实践

### 访问控制
```yaml
# RBAC配置
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-manager
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-manager-role
rules:
- apiGroups:
  - '*'
  resources:
  - '*'
  verbs:
  - '*'
- nonResourceURLs:
  - '*'
  verbs:
  - '*'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-manager-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-manager-role
subjects:
- kind: ServiceAccount
  name: argocd-manager
  namespace: kube-system
```

### 密钥管理
```yaml
# SealedSecret配置
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: my-secret
  namespace: production
spec:
  encryptedData:
    username: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEq.....
    password: AgBy3i4OJDTXkT2TTUTyyrws9B6CGi....
  template:
    metadata:
      name: my-secret
      namespace: production
    data:
      username: ""
      password: ""
```

### 签名验证
```yaml
# Cosign签名验证
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: podinfo
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    semver:
      range: 5.0.x
  verification:
    provider: cosign
    secretRef:
      name: cosign-pub
```

## 部署策略

### 蓝绿部署
```yaml
# 蓝绿部署配置
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: blue-green-app
spec:
  source:
    repoURL: https://github.com/myorg/blue-green-demo.git
    targetRevision: HEAD
    path: blue-green
  destination:
    server: https://kubernetes.default.svc
    namespace: blue-green
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
  strategy:
    blueGreen:
      activeService: active-service
      previewService: preview-service
      autoPromotionEnabled: false
```

### 金丝雀发布
```yaml
# Flagger金丝雀部署
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  service:
    port: 9898
    targetPort: 9898
  analysis:
    interval: 1m
    threshold: 10
    maxWeight: 50
    stepWeight: 5
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 1m
```

## 监控和告警

### ArgoCD健康检查
```yaml
# 健康检查配置
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: health-check-app
spec:
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas
  info:
  - name: url
    value: https://myapp.example.com
```

### 部署状态监控
```promql
# ArgoCD指标查询
argocd_app_info{namespace="argocd", dest_namespace="production"}
argocd_app_sync_total{namespace="argocd"}
argocd_app_sync_status{namespace="argocd", status="Synced"}
```

## 最佳实践

### 1. 配置管理原则
- 使用声明式而非命令式配置
- 保持配置的幂等性和可重复性
- 实施配置版本控制和变更审计

### 2. 安全考虑
- 最小权限原则配置RBAC
- 敏感信息加密存储
- 定期轮换密钥和证书

### 3. 部署策略
- 灰度发布逐步验证
- 自动回滚机制保障
- 多环境一致性保证

### 4. 监控告警
- 实时同步状态监控
- 部署成功率跟踪
- 配置漂移检测告警

通过GitOps实践，可以实现基础设施和应用配置的标准化管理，提高部署的可靠性和可追溯性，降低运维复杂度。