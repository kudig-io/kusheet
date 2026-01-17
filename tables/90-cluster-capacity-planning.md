# 表格90: 集群容量规划

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/setup/best-practices/cluster-large](https://kubernetes.io/docs/setup/best-practices/cluster-large/)

## Kubernetes集群规模限制

| 资源类型 | 单集群限制 | 说明 |
|---------|-----------|------|
| 节点数 | 5,000 | 官方测试上限 |
| Pod总数 | 150,000 | 取决于etcd性能 |
| 每节点Pod数 | 110 | kubelet默认限制 |
| 每节点容器数 | 300 | 实践建议 |
| Service数 | 10,000 | iptables模式限制 |
| Endpoints/Service | 5,000 | EndpointSlice缓解 |
| ConfigMap大小 | 1MB | 单个ConfigMap |
| Secret大小 | 1MB | 单个Secret |

## 节点容量规划

| 节点规格 | 推荐Pod数 | 推荐用途 |
|---------|----------|---------|
| 2C4G | 10-20 | 开发测试 |
| 4C8G | 20-40 | 轻量生产 |
| 8C16G | 40-60 | 标准生产 |
| 16C32G | 60-80 | 密集部署 |
| 32C64G | 80-110 | 大规模部署 |

## 资源预留计算

```yaml
# kubelet资源预留配置
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
systemReserved:
  cpu: "500m"
  memory: "1Gi"
  ephemeral-storage: "1Gi"
kubeReserved:
  cpu: "500m"
  memory: "1Gi"
  ephemeral-storage: "1Gi"
evictionHard:
  memory.available: "100Mi"
  nodefs.available: "10%"
  imagefs.available: "15%"
```

## 容量计算公式

```
可调度CPU = 节点CPU - systemReserved.cpu - kubeReserved.cpu
可调度内存 = 节点内存 - systemReserved.memory - kubeReserved.memory - evictionThreshold

示例(8C16G节点):
可调度CPU = 8000m - 500m - 500m = 7000m
可调度内存 = 16Gi - 1Gi - 1Gi - 100Mi ≈ 13.9Gi
```

## 容量监控指标

```bash
# 检查节点可分配资源
kubectl describe nodes | grep -A 6 "Allocatable"

# 检查节点已分配资源
kubectl describe nodes | grep -A 6 "Allocated resources"

# 计算集群总容量
kubectl get nodes -o json | jq '[.items[].status.allocatable.cpu] | map(gsub("m";"") | tonumber) | add'
kubectl get nodes -o json | jq '[.items[].status.allocatable.memory] | map(gsub("Ki";"") | tonumber) | add / 1024 / 1024'

# Prometheus查询
# 集群CPU总量: sum(kube_node_status_allocatable{resource="cpu"})
# 集群内存总量: sum(kube_node_status_allocatable{resource="memory"})
# CPU使用率: sum(rate(container_cpu_usage_seconds_total[5m])) / sum(kube_node_status_allocatable{resource="cpu"})
```

## 容量规划维度

| 维度 | 考虑因素 | 计算方法 |
|-----|---------|---------|
| **CPU** | 业务负载特征,突发需求 | 平均使用量 × 1.5 |
| **内存** | 应用内存占用,缓存需求 | 峰值使用量 × 1.3 |
| **存储** | 数据增长率,备份需求 | 当前用量 × 增长系数 |
| **网络** | 带宽需求,跨AZ流量 | 峰值带宽 × 1.5 |
| **Pod数** | 微服务数量,副本数 | 服务数 × 平均副本 |

## 多节点池策略

```yaml
# ACK节点池规划示例
节点池配置:
  通用节点池:
    规格: ecs.g6.2xlarge (8C32G)
    数量: 10-50 (弹性)
    用途: 无状态服务
    
  内存优化池:
    规格: ecs.r6.2xlarge (8C64G)
    数量: 5-20
    用途: 缓存、数据库
    
  GPU节点池:
    规格: ecs.gn6v-c8g1.2xlarge
    数量: 2-10
    用途: AI推理
    
  高IO节点池:
    规格: ecs.i2.xlarge
    数量: 3-10
    用途: 存储密集型
```

## 弹性伸缩配置

```yaml
# Cluster Autoscaler配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-autoscaler-config
data:
  config: |
    {
      "nodeGroups": [
        {
          "name": "general",
          "minSize": 3,
          "maxSize": 50,
          "scaleDownUtilizationThreshold": 0.5,
          "scaleDownUnneededTime": "10m"
        }
      ],
      "scaleDownDelayAfterAdd": "10m",
      "scaleDownDelayAfterDelete": "1m",
      "scaleDownDelayAfterFailure": "3m"
    }
```

## 容量预警阈值

| 指标 | 警告阈值 | 严重阈值 | 处理措施 |
|-----|---------|---------|---------|
| CPU使用率 | 70% | 85% | 扩容节点 |
| 内存使用率 | 75% | 90% | 扩容节点 |
| Pod数量 | 80%限制 | 95%限制 | 扩容节点 |
| 存储使用率 | 70% | 85% | 扩容存储 |

## 监控告警

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: capacity-alerts
spec:
  groups:
  - name: capacity
    rules:
    - alert: ClusterCPUCapacityLow
      expr: |
        sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) /
        sum(kube_node_status_allocatable{resource="cpu"}) > 0.8
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "集群CPU使用率超过80%"
        
    - alert: ClusterMemoryCapacityLow
      expr: |
        sum(container_memory_usage_bytes{container!=""}) /
        sum(kube_node_status_allocatable{resource="memory"}) > 0.85
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "集群内存使用率超过85%"
        
    - alert: ClusterPodCapacityLow
      expr: |
        sum(kube_pod_status_phase{phase="Running"}) /
        sum(kube_node_status_allocatable{resource="pods"}) > 0.85
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "集群Pod容量使用超过85%"
```

## 容量规划报告模板

```markdown
# 集群容量规划报告

## 当前状态
- 节点数: X
- 总CPU: X cores
- 总内存: X GB
- Pod数: X

## 使用情况
- CPU使用率: X%
- 内存使用率: X%
- Pod使用率: X%

## 增长预测
- 月均增长率: X%
- 预计耗尽时间: X个月

## 扩容建议
- 短期(1个月): 增加X节点
- 中期(3个月): 增加X节点
- 长期(12个月): 增加X节点

## 优化建议
1. 调整资源requests/limits
2. 清理无用资源
3. 优化应用资源使用
```

---

**容量规划原则**: 预留20%缓冲 + 监控使用趋势 + 定期评估 + 自动弹性伸缩
