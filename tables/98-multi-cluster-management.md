# 多集群管理

> Kubernetes 版本: v1.25 - v1.32 | 适用环境: 生产集群

## 多集群架构模式

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| 独立管理 | 各集群独立运维 | 简单多集群 |
| 中心化管理 | 统一控制平面 | 企业级管理 |
| 联邦 | 跨集群资源分发 | 高可用部署 |
| 服务网格 | 跨集群服务发现 | 微服务架构 |

## 多集群管理工具对比

| 工具 | 类型 | 特点 | 适用规模 |
|------|------|------|----------|
| Rancher | 管理平台 | 全功能、易用 | 中大规模 |
| KubeSphere | 管理平台 | 国产、功能全 | 中大规模 |
| Loft | 虚拟集群 | 轻量、多租户 | 开发测试 |
| Karmada | 联邦 | CNCF、原生 | 大规模 |
| Clusternet | 联邦 | 腾讯开源 | 中大规模 |
| Admiralty | 调度 | 跨集群调度 | 特定场景 |

## kubeconfig 多集群配置

```yaml
# ~/.kube/config
apiVersion: v1
kind: Config
clusters:
- name: production-cn-hangzhou
  cluster:
    server: https://prod-hz.example.com:6443
    certificate-authority-data: <CA_DATA>
- name: production-cn-shanghai
  cluster:
    server: https://prod-sh.example.com:6443
    certificate-authority-data: <CA_DATA>
- name: staging
  cluster:
    server: https://staging.example.com:6443
    certificate-authority-data: <CA_DATA>

users:
- name: admin-hz
  user:
    client-certificate-data: <CERT_DATA>
    client-key-data: <KEY_DATA>
- name: admin-sh
  user:
    client-certificate-data: <CERT_DATA>
    client-key-data: <KEY_DATA>
- name: admin-staging
  user:
    client-certificate-data: <CERT_DATA>
    client-key-data: <KEY_DATA>

contexts:
- name: prod-hz
  context:
    cluster: production-cn-hangzhou
    user: admin-hz
    namespace: default
- name: prod-sh
  context:
    cluster: production-cn-shanghai
    user: admin-sh
    namespace: default
- name: staging
  context:
    cluster: staging
    user: admin-staging
    namespace: default

current-context: prod-hz
```

## Karmada 联邦部署

```yaml
# PropagationPolicy - 资源分发策略
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
  name: nginx-propagation
  namespace: default
spec:
  resourceSelectors:
  - apiVersion: apps/v1
    kind: Deployment
    name: nginx
  placement:
    clusterAffinity:
      clusterNames:
      - cluster-hz
      - cluster-sh
    replicaScheduling:
      replicaDivisionPreference: Weighted
      replicaSchedulingType: Divided
      weightPreference:
        staticWeightList:
        - targetCluster:
            clusterNames:
            - cluster-hz
          weight: 2
        - targetCluster:
            clusterNames:
            - cluster-sh
          weight: 1
---
# OverridePolicy - 集群差异化配置
apiVersion: policy.karmada.io/v1alpha1
kind: OverridePolicy
metadata:
  name: nginx-override
  namespace: default
spec:
  resourceSelectors:
  - apiVersion: apps/v1
    kind: Deployment
    name: nginx
  overrideRules:
  - targetCluster:
      clusterNames:
      - cluster-hz
    overriders:
      plaintext:
      - path: "/spec/replicas"
        operator: replace
        value: 5
      - path: "/spec/template/spec/containers/0/image"
        operator: replace
        value: registry-hz.example.com/nginx:1.25
  - targetCluster:
      clusterNames:
      - cluster-sh
    overriders:
      plaintext:
      - path: "/spec/replicas"
        operator: replace
        value: 3
```

## 跨集群服务发现 (Istio)

```yaml
# 多集群 Istio 配置
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-multicluster
spec:
  profile: default
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster-hz
      network: network1
  meshConfig:
    defaultConfig:
      proxyMetadata:
        ISTIO_META_DNS_CAPTURE: "true"
        ISTIO_META_DNS_AUTO_ALLOCATE: "true"
---
# 跨集群服务访问
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-svc-cluster-sh
spec:
  hosts:
  - api.cluster-sh.svc.cluster.local
  location: MESH_EXTERNAL
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: DNS
  endpoints:
  - address: api.cluster-sh.example.com
    ports:
      http: 80
```

## 多集群 GitOps (ArgoCD)

```yaml
# ArgoCD 多集群配置
apiVersion: v1
kind: Secret
metadata:
  name: cluster-production-hz
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
stringData:
  name: production-hz
  server: https://prod-hz.example.com:6443
  config: |
    {
      "bearerToken": "<SERVICE_ACCOUNT_TOKEN>",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "<CA_DATA>"
      }
    }
---
# ApplicationSet 多集群部署
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: multi-cluster-app
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          env: production
  template:
    metadata:
      name: '{{name}}-app'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/app.git
        targetRevision: main
        path: manifests/{{metadata.labels.region}}
      destination:
        server: '{{server}}'
        namespace: app
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

## 多集群监控

```yaml
# Thanos 多集群监控架构
---
# Sidecar 配置 (每个集群)
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: prometheus
spec:
  template:
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v2.47.0
        args:
        - --config.file=/etc/prometheus/prometheus.yml
        - --storage.tsdb.path=/prometheus
        - --storage.tsdb.min-block-duration=2h
        - --storage.tsdb.max-block-duration=2h
      - name: thanos-sidecar
        image: quay.io/thanos/thanos:v0.32.0
        args:
        - sidecar
        - --tsdb.path=/prometheus
        - --prometheus.url=http://localhost:9090
        - --objstore.config-file=/etc/thanos/objstore.yml
        - --grpc-address=0.0.0.0:10901
---
# Query 全局查询 (中心集群)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: thanos-query
spec:
  template:
    spec:
      containers:
      - name: thanos-query
        image: quay.io/thanos/thanos:v0.32.0
        args:
        - query
        - --http-address=0.0.0.0:9090
        - --grpc-address=0.0.0.0:10901
        - --store=prometheus-hz.monitoring:10901
        - --store=prometheus-sh.monitoring:10901
        - --store=thanos-store.monitoring:10901
```

## 多集群管理命令

```bash
# kubectx/kubens 切换集群和命名空间
kubectx prod-hz
kubens production

# kubectl 指定集群
kubectl --context=prod-hz get nodes
kubectl --context=prod-sh get nodes

# 批量操作多集群
for ctx in prod-hz prod-sh staging; do
  echo "=== Cluster: $ctx ==="
  kubectl --context=$ctx get nodes
done

# 多集群资源统计
for ctx in $(kubectl config get-contexts -o name); do
  echo "=== $ctx ==="
  kubectl --context=$ctx get pods -A --no-headers | wc -l
done
```

## 集群注册与管理

```bash
# Karmada 集群注册
karmadactl join cluster-hz \
  --kubeconfig=/etc/karmada/karmada-apiserver.config \
  --cluster-kubeconfig=/root/.kube/config-hz

# 查看成员集群
karmadactl get clusters

# Rancher 集群导入
# 通过 UI 或 API 导入

# ACK 多集群
# 通过控制台管理多个 ACK 集群
```

## 多集群网络互联

```yaml
# Submariner 跨集群网络
apiVersion: submariner.io/v1alpha1
kind: Broker
metadata:
  name: submariner-broker
  namespace: submariner-k8s-broker
spec:
  globalnetEnabled: true
---
# ServiceExport 跨集群服务发布
apiVersion: multicluster.x-k8s.io/v1alpha1
kind: ServiceExport
metadata:
  name: nginx
  namespace: default
---
# ServiceImport 跨集群服务导入
apiVersion: multicluster.x-k8s.io/v1alpha1
kind: ServiceImport
metadata:
  name: nginx
  namespace: default
spec:
  type: ClusterSetIP
  ports:
  - port: 80
    protocol: TCP
```

## 多集群最佳实践

| 项目 | 建议 |
|------|------|
| 命名规范 | 统一集群和资源命名规范 |
| 配置管理 | GitOps 统一管理配置 |
| 镜像仓库 | 每个区域部署镜像仓库 |
| 监控日志 | 聚合到统一平台 |
| 网络互联 | 规划网络 CIDR 避免冲突 |
| 证书管理 | 统一证书管理和轮换 |
| RBAC | 跨集群统一权限管理 |
