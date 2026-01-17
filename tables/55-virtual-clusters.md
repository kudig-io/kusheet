# 表格55: 虚拟集群与多租户

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/security/multi-tenancy](https://kubernetes.io/docs/concepts/security/multi-tenancy/)

## 多租户隔离模式

| 模式 | 隔离级别 | 资源效率 | 管理复杂度 | 适用场景 |
|-----|---------|---------|-----------|---------|
| 命名空间 | 软隔离 | 高 | 低 | 团队隔离 |
| 虚拟集群 | 强隔离 | 中 | 中 | 多租户平台 |
| 物理集群 | 完全隔离 | 低 | 高 | 安全敏感 |

## 虚拟集群工具对比

| 工具 | 架构 | API兼容性 | 成熟度 | 社区 |
|-----|------|---------|-------|------|
| vCluster | 嵌入式控制平面 | 完全 | ⭐⭐⭐⭐⭐ | 活跃 |
| Kamaji | 外部控制平面 | 完全 | ⭐⭐⭐⭐ | 活跃 |
| Cluster API | 独立集群 | 完全 | ⭐⭐⭐⭐⭐ | CNCF |
| Hierarchical Namespaces | 命名空间层次 | 部分 | ⭐⭐⭐ | K8s SIG |

## vCluster架构

| 组件 | 位置 | 功能 |
|-----|------|------|
| syncer | 虚拟集群Pod | 资源同步 |
| kube-apiserver | 虚拟集群Pod | API服务器 |
| etcd/SQLite | 虚拟集群Pod | 数据存储 |
| kube-controller-manager | 虚拟集群Pod | 控制器管理 |
| kube-scheduler | 可选 | 调度器 |

## vCluster安装

```bash
# 安装vCluster CLI
curl -L -o vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-amd64"
chmod +x vcluster
sudo mv vcluster /usr/local/bin

# 创建虚拟集群
vcluster create my-vcluster -n host-namespace

# 连接虚拟集群
vcluster connect my-vcluster -n host-namespace

# 使用Helm安装
helm upgrade --install my-vcluster vcluster \
  --repo https://charts.loft.sh \
  --namespace host-namespace \
  --create-namespace
```

## vCluster配置

```yaml
# values.yaml
sync:
  # 同步的资源类型
  pods:
    enabled: true
  services:
    enabled: true
  configmaps:
    enabled: true
  secrets:
    enabled: true
  persistentvolumeclaims:
    enabled: true
  ingresses:
    enabled: true
  
# 控制平面配置
controlPlane:
  distro:
    k8s:
      enabled: true
  statefulSet:
    resources:
      limits:
        cpu: "1"
        memory: 2Gi
      requests:
        cpu: 200m
        memory: 256Mi
    persistence:
      size: 5Gi

# 同步选项
sync:
  toHost:
    pods:
      enabled: true
    services:
      enabled: true
  fromHost:
    nodes:
      enabled: true
    
# 隔离配置
isolation:
  enabled: true
  resourceQuota:
    enabled: true
  limitRange:
    enabled: true
  networkPolicy:
    enabled: true
```

## Hierarchical Namespaces (HNC)

```yaml
# 安装HNC
kubectl apply -f https://github.com/kubernetes-sigs/hierarchical-namespaces/releases/latest/download/default.yaml

# 创建父命名空间
apiVersion: v1
kind: Namespace
metadata:
  name: org-team-a

# 创建子命名空间
apiVersion: hnc.x-k8s.io/v1alpha2
kind: SubnamespaceAnchor
metadata:
  name: dev
  namespace: org-team-a
---
apiVersion: hnc.x-k8s.io/v1alpha2
kind: SubnamespaceAnchor
metadata:
  name: staging
  namespace: org-team-a
```

## HNC资源继承

```yaml
# 在父命名空间创建资源(自动传播到子命名空间)
apiVersion: v1
kind: ConfigMap
metadata:
  name: team-config
  namespace: org-team-a
  labels:
    hnc.x-k8s.io/inherited-from: org-team-a
data:
  team: team-a
  
# 配置传播规则
apiVersion: hnc.x-k8s.io/v1alpha2
kind: HNCConfiguration
metadata:
  name: config
spec:
  resources:
  - resource: secrets
    mode: Propagate  # Propagate/Remove/Ignore
  - resource: roles
    mode: Propagate
  - resource: rolebindings
    mode: Propagate
  - resource: networkpolicies
    mode: Propagate
```

## 多租户RBAC策略

```yaml
# 租户管理员角色
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tenant-admin
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets", "daemonsets"]
  verbs: ["*"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies", "ingresses"]
  verbs: ["*"]
---
# 租户RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tenant-admin-binding
  namespace: tenant-a
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: tenant-admin
subjects:
- kind: Group
  name: tenant-a-admins
  apiGroup: rbac.authorization.k8s.io
```

## 租户隔离NetworkPolicy

```yaml
# 默认拒绝所有流量
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: tenant-a
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# 允许同命名空间通信
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: tenant-a
spec:
  podSelector: {}
  ingress:
  - from:
    - podSelector: {}
  egress:
  - to:
    - podSelector: {}
```

## 租户ResourceQuota

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-quota
  namespace: tenant-a
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    pods: "100"
    services: "20"
    secrets: "100"
    configmaps: "100"
    persistentvolumeclaims: "20"
    requests.storage: 100Gi
```

## ACK多租户方案

| 功能 | 说明 |
|-----|------|
| ACK One | 多集群统一管理 |
| 弹性配额 | 租户间资源共享 |
| 命名空间配额 | 资源限制 |
| 网络隔离 | Terway NetworkPolicy |
| 日志隔离 | SLS日志隔离 |

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| v1.25 | PSA替代PSP实现租户安全 |
| v1.27 | 资源配额改进 |
| v1.28 | CEL准入策略增强 |
| v1.30 | ValidatingAdmissionPolicy GA |
