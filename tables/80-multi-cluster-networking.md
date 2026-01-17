# 表格80: 多集群网络互联

## 多集群网络方案

| 方案 | 架构 | 延迟 | 复杂度 | 适用场景 |
|-----|------|------|-------|---------|
| Submariner | 隧道 | 中 | 中 | 混合云 |
| Cilium Cluster Mesh | eBPF隧道 | 低 | 中 | 同质集群 |
| Istio多集群 | 服务网格 | 中 | 高 | 服务治理 |
| Skupper | 应用层 | 中 | 低 | 简单互联 |
| VPN/专线 | 网络层 | 低 | 高 | 企业网络 |
| ACK One | 托管 | 低 | 低 | 阿里云 |

## Submariner部署

```bash
# 安装subctl
curl -Ls https://get.submariner.io | bash

# 部署Broker集群
subctl deploy-broker --kubeconfig broker-kubeconfig

# 加入集群
subctl join --kubeconfig cluster1-kubeconfig broker-info.subm \
  --clusterid cluster1 \
  --natt=false

subctl join --kubeconfig cluster2-kubeconfig broker-info.subm \
  --clusterid cluster2 \
  --natt=false
```

## Submariner ServiceExport

```yaml
# 集群1: 导出服务
apiVersion: multicluster.x-k8s.io/v1alpha1
kind: ServiceExport
metadata:
  name: my-service
  namespace: default
---
# 集群2: 访问导出的服务
# my-service.default.svc.clusterset.local
```

## Cilium Cluster Mesh配置

```yaml
# Helm values - 集群1
apiVersion: v1
kind: ConfigMap
metadata:
  name: cilium-cluster1
data:
  values.yaml: |
    cluster:
      name: cluster1
      id: 1
    
    clustermesh:
      useAPIServer: true
      apiserver:
        replicas: 2
        service:
          type: LoadBalancer
    
    hubble:
      relay:
        enabled: true
      ui:
        enabled: true
---
# 集群连接
# cilium clustermesh connect --destination-context cluster2
```

## Cilium ClusterMesh服务发现

```yaml
# 全局服务注解
apiVersion: v1
kind: Service
metadata:
  name: global-service
  annotations:
    service.cilium.io/global: "true"
    service.cilium.io/shared: "true"  # 共享到其他集群
spec:
  selector:
    app: myapp
  ports:
  - port: 80
```

## Istio多集群配置

```yaml
# 主集群配置
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: primary
spec:
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster1
      network: network1
  meshConfig:
    defaultConfig:
      proxyMetadata:
        ISTIO_META_DNS_CAPTURE: "true"
        ISTIO_META_DNS_AUTO_ALLOCATE: "true"
---
# 远程集群密钥
apiVersion: v1
kind: Secret
metadata:
  name: istio-remote-secret-cluster2
  namespace: istio-system
  labels:
    istio/multiCluster: "true"
data:
  cluster2: <base64-kubeconfig>
```

## 跨集群服务路由

```yaml
# Istio VirtualService跨集群路由
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: cross-cluster-routing
spec:
  hosts:
  - myservice.default.svc.cluster.local
  http:
  - match:
    - headers:
        x-region:
          exact: "us-west"
    route:
    - destination:
        host: myservice.default.svc.cluster.local
        subset: cluster-us-west
  - route:
    - destination:
        host: myservice.default.svc.cluster.local
        subset: cluster-us-east
      weight: 50
    - destination:
        host: myservice.default.svc.cluster.local
        subset: cluster-us-west
      weight: 50
```

## ACK One多集群

```yaml
# 多集群服务
apiVersion: networking.alibabacloud.com/v1
kind: MultiClusterService
metadata:
  name: global-service
  namespace: default
spec:
  types:
  - CrossCluster
  ports:
  - port: 80
    protocol: TCP
  clusters:
  - name: cluster1
    weight: 50
  - name: cluster2
    weight: 50
```

## 多集群DNS

| 方案 | DNS格式 | 说明 |
|-----|--------|------|
| Submariner | `<svc>.<ns>.svc.clusterset.local` | MCS标准 |
| Cilium | `<svc>.<ns>.svc.cluster.local` | 透明 |
| Istio | `<svc>.<ns>.global` | 可配置 |
| ACK One | `<svc>.<ns>.svc.cluster.local` | 透明 |

## 故障转移配置

```yaml
# Cilium全局服务故障转移
apiVersion: v1
kind: Service
metadata:
  name: ha-service
  annotations:
    service.cilium.io/global: "true"
    service.cilium.io/affinity: "local"  # 优先本地
spec:
  selector:
    app: ha-app
  ports:
  - port: 80
```

## 监控指标

| 指标 | 类型 | 说明 |
|-----|-----|------|
| `submariner_connections` | Gauge | 集群连接数 |
| `cilium_clustermesh_remote_clusters` | Gauge | 远程集群数 |
| `istio_requests_total` | Counter | 跨集群请求 |

## 版本要求

| 方案 | 最低K8s版本 |
|-----|-----------|
| Submariner | v1.21+ |
| Cilium Cluster Mesh | v1.21+ |
| Istio Multi-cluster | v1.22+ |
| ACK One | v1.24+ |
