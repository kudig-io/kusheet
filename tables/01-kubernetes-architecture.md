# Kubernetes 架构参考

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/architecture](https://kubernetes.io/docs/concepts/architecture/)

## 架构总览

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Kubernetes Cluster                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────── Control Plane ─────────────────────────────┐  │
│  │                                                                           │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │  │
│  │  │ API Server  │  │  Scheduler  │  │ Controller  │  │ Cloud Controller│  │  │
│  │  │   :6443     │  │   :10259    │  │   Manager   │  │    Manager      │  │  │
│  │  │             │  │             │  │   :10257    │  │    :10258       │  │  │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └───────┬─────────┘  │  │
│  │         │                │                │                 │            │  │
│  │         └────────────────┴────────────────┴─────────────────┘            │  │
│  │                                   │                                       │  │
│  │                          ┌────────┴────────┐                              │  │
│  │                          │      etcd       │                              │  │
│  │                          │   :2379/:2380   │                              │  │
│  │                          └─────────────────┘                              │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                      │                                          │
│                                      │ HTTPS/gRPC                               │
│                                      ▼                                          │
│  ┌─────────────────────────────── Worker Nodes ──────────────────────────────┐  │
│  │                                                                           │  │
│  │  ┌─────────────────────────────── Node 1 ─────────────────────────────┐  │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │  │  │
│  │  │  │ kubelet  │  │kube-proxy│  │ Container│  │   CNI Plugin     │   │  │  │
│  │  │  │  :10250  │  │  :10249  │  │ Runtime  │  │ (Calico/Cilium)  │   │  │  │
│  │  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────────┬─────────┘   │  │  │
│  │  │       └──────────────┴────────────┴─────────────────┘             │  │  │
│  │  │                              │                                     │  │  │
│  │  │  ┌───────────────────────────┼───────────────────────────────┐    │  │  │
│  │  │  │      ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐         │    │  │  │
│  │  │  │      │ Pod │  │ Pod │  │ Pod │  │ Pod │  │ Pod │  ...    │    │  │  │
│  │  │  │      └─────┘  └─────┘  └─────┘  └─────┘  └─────┘         │    │  │  │
│  │  │  └──────────────────────────────────────────────────────────┘    │  │  │
│  │  └────────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                           │  │
│  │  ┌─────────────────────────────── Node N ─────────────────────────────┐  │  │
│  │  │                            ...                                     │  │  │
│  │  └────────────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## 控制平面组件

| 组件 | 功能 | 端口 | HA方式 | 故障影响 | 监控指标 |
|------|------|------|--------|----------|----------|
| kube-apiserver | REST API入口，认证授权 | 6443 | 多副本+LB | 集群完全不可用 | apiserver_request_* |
| etcd | 分布式KV存储 | 2379/2380 | Raft集群 | 数据丢失风险 | etcd_server_* |
| kube-scheduler | Pod调度决策 | 10259 | leader选举 | 新Pod无法调度 | scheduler_* |
| kube-controller-manager | 控制器循环 | 10257 | leader选举 | 资源无法协调 | workqueue_* |
| cloud-controller-manager | 云厂商集成 | 10258 | leader选举 | 云资源无法管理 | - |

## 工作节点组件

| 组件 | 功能 | 端口 | 故障影响 | 诊断命令 |
|------|------|------|----------|----------|
| kubelet | Pod生命周期管理 | 10250/10255 | 节点NotReady | `systemctl status kubelet` |
| kube-proxy | Service网络代理 | 10249/10256 | Service不可达 | `iptables -L -t nat` |
| containerd | 容器运行时 | unix socket | 容器无法创建 | `crictl ps` |
| CNI Plugin | Pod网络 | - | Pod网络不通 | `calicoctl node status` |

## 版本演进关键变更

| 版本 | 关键变更 | 影响 | 迁移操作 |
|------|----------|------|----------|
| v1.24 | 移除dockershim | 必须使用CRI运行时 | 迁移到containerd |
| v1.25 | 移除PSP | 安全策略变更 | 迁移到PSA |
| v1.26 | nftables支持 | kube-proxy新后端 | 可选启用 |
| v1.27 | 就地Pod资源调整Alpha | 减少Pod重启 | 可选启用 |
| v1.28 | Sidecar容器Beta | 改善sidecar生命周期 | 可选启用 |
| v1.29 | 负载均衡器IP模式 | 简化云LB配置 | 自动生效 |
| v1.30 | 节点交换内存支持 | 支持更多工作负载 | 可选启用 |
| v1.31 | AppArmor GA | 安全配置标准化 | 迁移注解到字段 |
| v1.32 | DRA改进 | GPU等设备管理优化 | 需要DRA驱动 |

## 集群规模限制

| 维度 | 官方支持上限 | 生产建议 | 超限影响 |
|------|-------------|----------|----------|
| 节点数 | 5000 | 3000 | 控制平面过载 |
| Pod总数 | 150000 | 100000 | etcd/apiserver压力 |
| Pod/节点 | 110 | 110 | kubelet压力 |
| Service数 | 10000 | 5000 | kube-proxy压力 |
| 后端/Service | 5000 | 1000 | EndpointSlice膨胀 |
| Namespace数 | 10000 | 1000 | API压力 |
| ConfigMap大小 | 1MB | 256KB | etcd压力 |
| Secret大小 | 1MB | 256KB | etcd压力 |

## 高可用部署架构

### 堆叠etcd拓扑 (推荐小规模)

```yaml
# kubeadm 配置
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.30.0
controlPlaneEndpoint: "api-lb.example.com:6443"
etcd:
  local:
    dataDir: /var/lib/etcd
    extraArgs:
      quota-backend-bytes: "8589934592"
      auto-compaction-retention: "1"
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
apiServer:
  extraArgs:
    max-requests-inflight: "800"
    max-mutating-requests-inflight: "400"
    audit-log-path: "/var/log/kubernetes/audit/audit.log"
    audit-policy-file: "/etc/kubernetes/audit-policy.yaml"
    encryption-provider-config: "/etc/kubernetes/encryption-config.yaml"
  extraVolumes:
  - name: audit-log
    hostPath: /var/log/kubernetes/audit
    mountPath: /var/log/kubernetes/audit
  - name: audit-policy
    hostPath: /etc/kubernetes/audit-policy.yaml
    mountPath: /etc/kubernetes/audit-policy.yaml
    readOnly: true
controllerManager:
  extraArgs:
    concurrent-deployment-syncs: "10"
    concurrent-replicaset-syncs: "10"
scheduler:
  extraArgs:
    kube-api-qps: "100"
    kube-api-burst: "200"
```

### 外部etcd拓扑 (推荐大规模)

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.30.0
controlPlaneEndpoint: "api-lb.example.com:6443"
etcd:
  external:
    endpoints:
    - https://etcd-0.example.com:2379
    - https://etcd-1.example.com:2379
    - https://etcd-2.example.com:2379
    caFile: /etc/kubernetes/pki/etcd/ca.crt
    certFile: /etc/kubernetes/pki/etcd/apiserver-etcd-client.crt
    keyFile: /etc/kubernetes/pki/etcd/apiserver-etcd-client.key
```

## 网络架构

| 网络类型 | CIDR范围 | 用途 | 配置位置 |
|----------|----------|------|----------|
| Pod Network | 10.244.0.0/16 | Pod IP分配 | CNI配置 |
| Service Network | 10.96.0.0/12 | Service ClusterIP | apiserver启动参数 |
| Node Network | 物理/云网络 | 节点通信 | 基础设施 |

### CNI选型对比

| CNI | 模式 | 性能 | NetworkPolicy | 适用场景 |
|-----|------|------|---------------|----------|
| Calico | BGP/IPIP/VXLAN | 高 | 完整支持 | 通用生产环境 |
| Cilium | eBPF | 最高 | 完整+增强 | 高性能/安全要求 |
| Flannel | VXLAN/host-gw | 中 | 不支持 | 简单场景 |
| Terway | ENI/ENIIP | 高 | 支持 | 阿里云ACK |
| AWS VPC CNI | ENI | 高 | 支持 | AWS EKS |

## 存储架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Storage Architecture                      │
├─────────────────────────────────────────────────────────────┤
│  Pod                                                         │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ volumeMounts:                                        │    │
│  │   - name: data                                       │    │
│  │     mountPath: /data                                 │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                  │
│                           ▼                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ PersistentVolumeClaim (PVC)                         │    │
│  │   - storageClassName: alicloud-disk-essd            │    │
│  │   - accessModes: [ReadWriteOnce]                    │    │
│  │   - resources.requests.storage: 100Gi               │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                  │
│                           ▼                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ StorageClass                                         │    │
│  │   - provisioner: disk.csi.aliyun.com                │    │
│  │   - parameters:                                      │    │
│  │       type: cloud_essd                              │    │
│  │       performanceLevel: PL1                         │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                  │
│                           ▼                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ CSI Driver                                           │    │
│  │   - Controller (Provisioner, Attacher, Resizer)     │    │
│  │   - Node Plugin (NodePublish, NodeStage)            │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                  │
│                           ▼                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Backend Storage (云盘/NAS/OSS)                       │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## 生产部署检查清单

### 控制平面

```bash
# 检查控制平面组件状态
kubectl get componentstatuses  # 已弃用但可用
kubectl get --raw='/readyz?verbose'
kubectl get --raw='/livez?verbose'

# 检查 API Server 指标
kubectl get --raw /metrics | grep apiserver_request_duration

# 检查 etcd 健康
etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  endpoint health --cluster

# 检查 etcd 大小
etcdctl endpoint status --cluster -w table
```

### 工作节点

```bash
# 检查节点状态
kubectl get nodes -o wide
kubectl describe node <node-name> | grep -A 10 Conditions

# 检查 kubelet
systemctl status kubelet
journalctl -u kubelet -f --no-pager | tail -100

# 检查容器运行时
crictl info
crictl ps
crictl images

# 检查 kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=100
iptables -L -t nat | head -50  # iptables模式
ipvsadm -Ln  # IPVS模式
```

## 常见生产问题诊断

| 问题 | 症状 | 诊断命令 | 解决方案 |
|------|------|----------|----------|
| etcd磁盘满 | API响应503 | `etcdctl endpoint status` | 压缩+碎片整理 |
| API过载 | 请求超时 | `kubectl get --raw /metrics \| grep inflight` | 增加并发限制 |
| 调度失败 | Pod Pending | `kubectl describe pod` | 检查资源/亲和性 |
| 节点NotReady | Pod驱逐 | `kubectl describe node` | 检查kubelet |
| DNS失败 | 服务发现异常 | `kubectl logs -n kube-system coredns-*` | 检查CoreDNS |

## Prometheus 监控规则

```yaml
groups:
- name: kubernetes-control-plane
  rules:
  - alert: KubeAPIServerDown
    expr: absent(up{job="kubernetes-apiservers"} == 1)
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Kubernetes API Server 不可用"
      
  - alert: KubeAPIServerLatencyHigh
    expr: |
      histogram_quantile(0.99, sum(rate(apiserver_request_duration_seconds_bucket{verb!="WATCH"}[5m])) by (le, verb)) > 1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "API Server P99 延迟 > 1s"
      
  - alert: EtcdNoLeader
    expr: etcd_server_has_leader == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "etcd 集群无 Leader"
      
  - alert: EtcdDatabaseSizeHigh
    expr: etcd_mvcc_db_total_size_in_bytes / etcd_server_quota_backend_bytes > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd 数据库使用率 > 80%"
      
  - alert: KubeSchedulerPendingPods
    expr: scheduler_pending_pods > 50
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "待调度 Pod 积压 > 50"
```

## ACK 架构特点

| 版本 | 控制平面 | etcd | 特点 |
|------|----------|------|------|
| ACK 标准版 | 用户管理 | 用户管理 | 完全控制 |
| ACK Pro版 | 托管 | 托管 | 零运维、自动HA |
| ACK Serverless | 托管 | 托管 | 按需付费、无节点管理 |

### ACK Pro 托管架构

```
┌──────────────────────────────────────────────────────────────┐
│                     阿里云 ACK Pro                            │
├──────────────────────────────────────────────────────────────┤
│  ┌─────────────────── 阿里云托管 ───────────────────────┐    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │    │
│  │  │ API Server  │  │  Scheduler  │  │ Controller  │  │    │
│  │  │ (托管HA)    │  │ (托管HA)    │  │  (托管HA)   │  │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  │    │
│  │                                                      │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │              etcd (托管集群)                 │    │    │
│  │  │         自动备份、自动扩容、跨AZ            │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  └──────────────────────────────────────────────────────┘    │
│                            │                                  │
│                            ▼                                  │
│  ┌──────────────── 用户 VPC ────────────────────────────┐    │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐    │    │
│  │  │ Worker  │ │ Worker  │ │ Worker  │ │ Worker  │    │    │
│  │  │ Node 1  │ │ Node 2  │ │ Node 3  │ │ Node N  │    │    │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘    │    │
│  │                                                      │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │   Terway CNI (ENI/ENIIP模式)                │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

### ACK 集群创建参数

```bash
# 使用 aliyun CLI 创建 ACK Pro 集群
aliyun cs POST /clusters --body '{
  "name": "production-cluster",
  "cluster_type": "ManagedKubernetes",
  "kubernetes_version": "1.30.1-aliyun.1",
  "region_id": "cn-hangzhou",
  "vpcid": "vpc-xxx",
  "container_cidr": "10.244.0.0/16",
  "service_cidr": "10.96.0.0/16",
  "num_of_nodes": 3,
  "master_instance_types": ["ecs.g7.xlarge"],
  "worker_instance_types": ["ecs.g7.2xlarge"],
  "worker_system_disk_category": "cloud_essd",
  "worker_system_disk_size": 120,
  "worker_data_disks": [{
    "category": "cloud_essd",
    "size": 200,
    "encrypted": "true"
  }],
  "addons": [
    {"name": "terway-eniip"},
    {"name": "csi-plugin"},
    {"name": "csi-provisioner"},
    {"name": "nginx-ingress-controller"},
    {"name": "arms-prometheus"}
  ],
  "tags": [
    {"key": "env", "value": "production"}
  ]
}'
```
