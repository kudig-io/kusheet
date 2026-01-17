# 表格44：联邦集群管理表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [karmada.io](https://karmada.io/) | [clusternet.io](https://clusternet.io/)

## 多集群管理方案对比

| 方案 | 维护方 | 架构模式 | 适用场景 | 成熟度 | ACK集成 |
|-----|-------|---------|---------|-------|---------|
| **Karmada** | CNCF | Push | 跨集群调度 | 生产就绪 | 支持 |
| **Clusternet** | 腾讯 | Pull | 多集群管理 | 生产就绪 | - |
| **Liqo** | 社区 | Peer-to-Peer | 集群互联 | 发展中 | - |
| **OCM** | Red Hat | Hub-Spoke | 多集群管理 | 生产就绪 | - |
| **ACK One** | 阿里云 | 托管 | 多集群管理 | 生产就绪 | 原生 |
| **Rancher** | SUSE | 管理平面 | 多集群管理 | 生产就绪 | - |

## Karmada架构

| 组件 | 位置 | 功能 |
|-----|------|------|
| **karmada-apiserver** | 控制平面 | 联邦API入口 |
| **karmada-controller-manager** | 控制平面 | 资源分发控制 |
| **karmada-scheduler** | 控制平面 | 跨集群调度 |
| **karmada-webhook** | 控制平面 | 准入控制 |
| **karmada-agent** | 成员集群 | 执行器(Pull模式) |

```bash
# Karmada安装
kubectl apply -f https://github.com/karmada-io/karmada/releases/download/v1.8.0/install.yaml

# 或使用karmadactl
karmadactl init --kubeconfig=/path/to/karmada-apiserver.config

# 加入成员集群
karmadactl join cluster1 --kubeconfig=/path/to/karmada.config --cluster-kubeconfig=/path/to/cluster1.config

# 查看成员集群
kubectl get clusters --kubeconfig=/path/to/karmada.config
```

## Karmada资源分发

```yaml
# PropagationPolicy - 分发策略
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
  name: nginx-propagation
spec:
  resourceSelectors:
  - apiVersion: apps/v1
    kind: Deployment
    name: nginx
  placement:
    clusterAffinity:
      clusterNames:
      - cluster-beijing
      - cluster-shanghai
      - cluster-guangzhou
    replicaScheduling:
      replicaSchedulingType: Divided  # Duplicated或Divided
      replicaDivisionPreference: Weighted
      weightPreference:
        staticWeightList:
        - targetCluster:
            clusterNames:
            - cluster-beijing
          weight: 2
        - targetCluster:
            clusterNames:
            - cluster-shanghai
          weight: 1
        - targetCluster:
            clusterNames:
            - cluster-guangzhou
          weight: 1
---
# ClusterPropagationPolicy - 集群级分发
apiVersion: policy.karmada.io/v1alpha1
kind: ClusterPropagationPolicy
metadata:
  name: namespace-propagation
spec:
  resourceSelectors:
  - apiVersion: v1
    kind: Namespace
    name: production
  placement:
    clusterAffinity:
      clusterNames:
      - cluster-beijing
      - cluster-shanghai
```

## Karmada覆盖策略

```yaml
# OverridePolicy - 覆盖配置
apiVersion: policy.karmada.io/v1alpha1
kind: OverridePolicy
metadata:
  name: nginx-override
spec:
  resourceSelectors:
  - apiVersion: apps/v1
    kind: Deployment
    name: nginx
  overrideRules:
  - targetCluster:
      clusterNames:
      - cluster-beijing
    overriders:
      plaintext:
      - path: /spec/replicas
        operator: replace
        value: 3
      - path: /spec/template/spec/containers/0/image
        operator: replace
        value: registry.cn-beijing.aliyuncs.com/ns/nginx:latest
  - targetCluster:
      clusterNames:
      - cluster-shanghai
    overriders:
      plaintext:
      - path: /spec/replicas
        operator: replace
        value: 2
      imageOverrider:
      - component: Registry
        operator: replace
        value: registry.cn-shanghai.aliyuncs.com
```

## 跨集群服务发现

```yaml
# ServiceExport - 导出服务
apiVersion: multicluster.x-k8s.io/v1alpha1
kind: ServiceExport
metadata:
  name: nginx
  namespace: default
---
# ServiceImport - 导入服务
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

## Karmada故障转移

```yaml
# 故障转移策略
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
  name: nginx-failover
spec:
  resourceSelectors:
  - apiVersion: apps/v1
    kind: Deployment
    name: nginx
  placement:
    clusterAffinity:
      clusterNames:
      - cluster-beijing
      - cluster-shanghai
    spreadConstraints:
    - maxGroups: 2
      minGroups: 1
      spreadByField: cluster
  failover:
    application:
      decisionConditions:
        tolerationSeconds: 60  # 60秒后触发故障转移
      purgeMode: Graciously
```

## ACK One多集群

```yaml
# ACK One Fleet
# 控制台创建舰队后，添加集群

# 舰队级应用分发
apiVersion: fleet.alibabacloud.com/v1alpha1
kind: ApplicationSet
metadata:
  name: nginx-fleet
spec:
  generators:
  - clusters: {}  # 所有集群
  template:
    metadata:
      name: nginx-{{cluster}}
    spec:
      source:
        repoURL: https://github.com/org/repo
        path: manifests
        targetRevision: HEAD
      destination:
        server: '{{server}}'
        namespace: default
```

## 多集群网络

| 方案 | 网络模式 | 延迟 | 适用场景 |
|-----|---------|------|---------|
| **Submariner** | 隧道 | 中 | 跨集群Pod通信 |
| **Cilium Cluster Mesh** | eBPF | 低 | 高性能互联 |
| **Istio Multi-Cluster** | Envoy | 中 | 服务网格 |
| **云厂商VPC互联** | VPC Peering | 低 | 同云厂商 |

```bash
# Submariner安装
subctl deploy-broker --kubeconfig broker-cluster-config
subctl join --kubeconfig cluster1-config broker-info.subm --clusterid cluster1
subctl join --kubeconfig cluster2-config broker-info.subm --clusterid cluster2

# 验证
subctl show connections
subctl diagnose all
```

## 多集群监控

```yaml
# Thanos多集群监控
# 每个集群部署Thanos Sidecar
# 中心部署Thanos Query聚合

# 集群标签
external_labels:
  cluster: cluster-beijing
  region: cn-beijing
```

## 多集群最佳实践

| 实践 | 说明 | 优先级 |
|-----|------|-------|
| **集群标准化** | 统一版本和配置 | P0 |
| **网络规划** | CIDR不重叠 | P0 |
| **故障转移** | 配置自动故障转移 | P1 |
| **统一监控** | 聚合所有集群指标 | P1 |
| **GitOps** | 统一配置管理 | P1 |
| **流量管理** | GSLB流量分发 | P1 |

## 多集群场景

| 场景 | 推荐方案 | 说明 |
|-----|---------|------|
| **灾备** | 主备集群 | Karmada/ACK One |
| **多地域** | 就近访问 | Karmada+GSLB |
| **多云** | 统一管理 | Karmada/Rancher |
| **开发测试** | 环境隔离 | 独立集群+GitOps |
| **大规模** | 联邦 | Karmada |

---

**多集群原则**: 统一管理，自动故障转移，就近访问
