# 表格53: 成本管理与FinOps

## Kubernetes成本构成

| 成本类型 | 组成部分 | 优化方向 |
|---------|---------|---------|
| 计算成本 | CPU、内存、GPU | 资源优化、弹性伸缩 |
| 存储成本 | PV、快照、备份 | 存储分层、清理策略 |
| 网络成本 | 跨AZ流量、公网流量 | 拓扑调度、流量优化 |
| 管理成本 | 控制平面、监控工具 | 托管服务选择 |

## 成本监控工具

| 工具 | 类型 | 功能 | 成本 |
|-----|-----|------|------|
| Kubecost | 开源/商业 | 成本分配、优化建议 | 免费版可用 |
| OpenCost | 开源 | 成本监控、CNCF项目 | 免费 |
| CloudHealth | 商业 | 多云成本管理 | 付费 |
| Spot.io | 商业 | 成本优化自动化 | 付费 |
| ACK成本分析 | 托管 | 阿里云原生 | 包含在ACK中 |

## Kubecost部署

```bash
# Helm安装
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm install kubecost kubecost/cost-analyzer \
  --namespace kubecost \
  --create-namespace \
  --set prometheus.nodeExporter.enabled=false \
  --set prometheus.serviceAccounts.nodeExporter.create=false
```

## 资源请求优化

| 问题 | 检测方法 | 优化建议 |
|-----|---------|---------|
| 过度请求 | 实际使用<<请求值 | VPA建议调整 |
| 请求不足 | OOM/Throttling频繁 | 增加请求值 |
| 无请求设置 | 审计无资源定义Pod | 强制资源定义 |
| 不均衡分配 | CPU/内存比例失衡 | 调整比例 |

## VPA资源建议

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: myapp-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  updatePolicy:
    updateMode: "Off"  # 仅建议,不自动更新
  resourcePolicy:
    containerPolicies:
    - containerName: "*"
      minAllowed:
        cpu: 50m
        memory: 64Mi
      maxAllowed:
        cpu: 2
        memory: 4Gi
```

## 节点优化策略

| 策略 | 说明 | 节省比例 |
|-----|------|---------|
| 抢占式实例 | 使用Spot/抢占式实例 | 50-90% |
| 预留实例 | 长期负载预留 | 30-60% |
| 节点自动缩放 | 按需扩缩节点 | 20-40% |
| 节点池优化 | 选择合适规格 | 10-30% |
| Bin Packing | 提高装箱率 | 15-25% |

## Cluster Autoscaler成本优化配置

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-autoscaler-config
data:
  config.yaml: |
    # 优先使用抢占式节点池
    expanders:
    - priority
    
    # 节点池优先级
    priorities: |
      10:
        - .*spot.*
      50:
        - .*ondemand.*
    
    # 缩容配置
    scale-down-enabled: true
    scale-down-delay-after-add: 10m
    scale-down-unneeded-time: 10m
    scale-down-utilization-threshold: 0.5
```

## 命名空间成本分配

```yaml
# 使用标签进行成本分配
apiVersion: v1
kind: Namespace
metadata:
  name: team-a
  labels:
    team: team-a
    department: engineering
    cost-center: "12345"
    environment: production
```

## 成本分配Prometheus查询

```promql
# 按命名空间统计CPU成本
sum by (namespace) (
  container_cpu_usage_seconds_total{container!=""}
) * on (node) group_left() 
node_hourly_cost

# 按标签统计内存成本
sum by (label_team) (
  container_memory_usage_bytes{container!=""}
) * on (node) group_left() 
node_hourly_cost / 1024 / 1024 / 1024

# 闲置资源统计
(
  sum(kube_pod_container_resource_requests{resource="cpu"}) -
  sum(container_cpu_usage_seconds_total)
) / sum(kube_pod_container_resource_requests{resource="cpu"})
```

## ResourceQuota成本控制

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: team-a
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    limits.cpu: "200"
    limits.memory: 400Gi
    requests.nvidia.com/gpu: "4"
    persistentvolumeclaims: "20"
    requests.storage: 500Gi
```

## 成本优化检查清单

| 检查项 | 命令/方法 | 目标 |
|-------|---------|------|
| 资源利用率 | Kubecost/Prometheus | >60% |
| 闲置Pod | `kubectl get pods --field-selector=status.phase=Running` | 清理无用Pod |
| 过期PVC | 检查未绑定PVC | 删除闲置存储 |
| 未使用镜像 | `crictl images` | 定期清理 |
| 日志保留 | 检查日志存储 | 优化保留策略 |
| 跨AZ流量 | 网络监控 | 拓扑感知调度 |

## ACK成本优化功能

| 功能 | 说明 |
|-----|------|
| 成本分析 | 按命名空间/标签成本统计 |
| 资源画像 | VPA资源建议 |
| 混合节点池 | 按需+抢占式混合 |
| 调度优化 | 提高资源利用率 |
| 弹性配额 | 团队间资源共享 |

## FinOps成熟度模型

| 阶段 | 能力 | 目标 |
|-----|------|------|
| Crawl | 成本可见性 | 知道花了多少钱 |
| Walk | 成本分配 | 知道谁花了钱 |
| Run | 成本优化 | 持续优化成本 |
