# 表格21：CI/CD管道表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [argoproj.github.io/argo-cd](https://argoproj.github.io/argo-cd/)

## CI/CD工具对比

| 工具 | 类型 | 特点 | K8S集成 | 学习曲线 | ACK集成 |
|-----|------|------|--------|---------|---------|
| **ArgoCD** | GitOps CD | 声明式，可视化强 | 原生 | 中 | 支持 |
| **Flux** | GitOps CD | 轻量，CNCF项目 | 原生 | 低 | 支持 |
| **Tekton** | CI/CD Pipeline | K8S原生，灵活 | 原生 | 高 | 支持 |
| **Jenkins** | CI/CD | 成熟生态，插件丰富 | 插件 | 中 | 支持 |
| **Jenkins X** | K8S原生CI/CD | GitOps+预览环境 | 原生 | 高 | - |
| **GitLab CI** | 一体化CI/CD | 代码+CI一体 | Runner | 中 | 支持 |
| **GitHub Actions** | CI/CD | GitHub原生 | Action | 低 | 支持 |
| **云效** | 阿里云CI/CD | 云原生集成 | 原生 | 低 | 原生 |

## ArgoCD配置

```yaml
# ArgoCD安装
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Application定义
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
    path: manifests/production
    helm:
      valueFiles:
      - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
---
# ApplicationSet - 多环境
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-envs
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - env: dev
        cluster: dev-cluster
      - env: staging
        cluster: staging-cluster
      - env: production
        cluster: prod-cluster
  template:
    metadata:
      name: 'myapp-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/repo.git
        targetRevision: HEAD
        path: 'manifests/{{env}}'
      destination:
        server: '{{cluster}}'
        namespace: '{{env}}'
```

## Flux配置

```bash
# Flux安装
flux bootstrap github \
  --owner=my-org \
  --repository=fleet-infra \
  --branch=main \
  --path=./clusters/production \
  --personal
```

```yaml
# GitRepository源
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: myapp
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/org/repo
  ref:
    branch: main
  secretRef:
    name: git-credentials
---
# Kustomization
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: myapp
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: myapp
  path: ./manifests/production
  prune: true
  healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: myapp
    namespace: production
---
# HelmRelease
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: myapp
  namespace: production
spec:
  interval: 5m
  chart:
    spec:
      chart: myapp
      version: '1.x'
      sourceRef:
        kind: HelmRepository
        name: myrepo
        namespace: flux-system
  values:
    replicaCount: 3
    image:
      tag: v1.2.3
```

## Tekton配置

```yaml
# Pipeline定义
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: build-and-deploy
spec:
  params:
  - name: git-url
    type: string
  - name: git-revision
    type: string
    default: main
  - name: image
    type: string
  workspaces:
  - name: source
  - name: docker-credentials
  tasks:
  - name: clone
    taskRef:
      name: git-clone
    workspaces:
    - name: output
      workspace: source
    params:
    - name: url
      value: $(params.git-url)
    - name: revision
      value: $(params.git-revision)
  - name: build-push
    taskRef:
      name: kaniko
    runAfter: [clone]
    workspaces:
    - name: source
      workspace: source
    - name: dockerconfig
      workspace: docker-credentials
    params:
    - name: IMAGE
      value: $(params.image)
  - name: deploy
    taskRef:
      name: kubernetes-actions
    runAfter: [build-push]
    params:
    - name: script
      value: |
        kubectl set image deployment/myapp app=$(params.image)
        kubectl rollout status deployment/myapp
---
# PipelineRun
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  generateName: build-deploy-run-
spec:
  pipelineRef:
    name: build-and-deploy
  params:
  - name: git-url
    value: https://github.com/org/repo
  - name: image
    value: registry.cn-hangzhou.aliyuncs.com/ns/app:v1.0.0
  workspaces:
  - name: source
    volumeClaimTemplate:
      spec:
        accessModes: [ReadWriteOnce]
        resources:
          requests:
            storage: 1Gi
  - name: docker-credentials
    secret:
      secretName: docker-credentials
```

## 部署策略

| 策略 | 描述 | 风险 | 回滚速度 | 适用场景 |
|-----|------|------|---------|---------|
| **滚动更新** | 逐步替换Pod | 低 | 快 | 默认策略 |
| **蓝绿部署** | 两套环境切换 | 低 | 最快 | 零停机要求 |
| **金丝雀发布** | 小流量验证 | 最低 | 快 | 重要变更 |
| **A/B测试** | 按特征路由 | 低 | 快 | 功能验证 |
| **影子部署** | 复制流量测试 | 无 | N/A | 性能测试 |

```yaml
# 滚动更新策略
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%

---
# 蓝绿部署(通过Service切换)
# Blue Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
---
# Green Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
---
# Service (切换selector实现蓝绿)
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
    version: blue  # 切换到green实现蓝绿
```

## 金丝雀发布(Argo Rollouts)

```yaml
# Argo Rollouts金丝雀
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
      - name: app
        image: myapp:v2
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {duration: 5m}
      - setWeight: 30
      - pause: {duration: 5m}
      - setWeight: 50
      - pause: {duration: 5m}
      - setWeight: 100
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
        startingStep: 1
        args:
        - name: service-name
          value: myapp-canary
---
# 分析模板
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    interval: 1m
    successCondition: result[0] >= 0.95
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(istio_requests_total{destination_service_name="{{args.service-name}}",response_code!~"5.*"}[5m])) /
          sum(rate(istio_requests_total{destination_service_name="{{args.service-name}}"}[5m]))
```

## CI/CD最佳实践

| 实践 | 说明 | 工具支持 |
|-----|------|---------|
| **GitOps** | Git作为唯一真相源 | ArgoCD/Flux |
| **基础设施即代码** | 所有配置版本控制 | Terraform/Pulumi |
| **不可变部署** | 新版本新Pod | K8S默认 |
| **环境一致性** | 开发=生产 | Kustomize/Helm |
| **自动化测试** | 部署前/后测试 | Tekton/GitHub Actions |
| **渐进式交付** | 金丝雀/蓝绿 | Argo Rollouts/Flagger |
| **自动回滚** | 基于指标回滚 | Argo Rollouts |

## ACK DevOps集成

| 功能 | 产品 | 集成方式 |
|-----|------|---------|
| **代码仓库** | 云效Codeup | 原生 |
| **CI构建** | 云效Flow | 原生 |
| **镜像仓库** | ACR | 原生 |
| **CD部署** | 云效AppStack | 原生 |
| **GitOps** | ArgoCD | 组件安装 |

---

**CI/CD原则**: GitOps优先，自动化测试，渐进式交付
