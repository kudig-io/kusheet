# 表格22：成本优化表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubecost.com](https://www.kubecost.com/)

## 成本组成分析

| 成本类别 | 占比(典型) | 优化空间 | 优化方法 |
|---------|-----------|---------|---------|
| **计算(CPU/Memory)** | 60-70% | 高 | 右置大小，自动扩缩容 |
| **存储** | 15-25% | 中 | 存储分层，生命周期管理 |
| **网络** | 5-15% | 中 | 流量优化，CDN |
| **管理/运维** | 5-10% | 低 | 自动化 |

## 资源右置大小(Right-sizing)

| 问题 | 检测方法 | 优化建议 | 工具 |
|-----|---------|---------|------|
| **过度配置** | 实际使用<50%请求 | 降低requests | VPA/Kubecost |
| **配置不足** | 频繁OOM/CPU节流 | 增加limits | 监控告警 |
| **未设限制** | QoS为BestEffort | 设置requests/limits | LimitRange |
| **闲置资源** | 使用率长期<10% | 缩容或删除 | Kubecost |

```yaml
# VPA推荐配置
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
    updateMode: "Off"  # 仅推荐，不自动更新
  resourcePolicy:
    containerPolicies:
    - containerName: "*"
      controlledResources: ["cpu", "memory"]
```

## 节点池优化

| 策略 | 描述 | 节省比例 | 风险 | 适用场景 |
|-----|------|---------|------|---------|
| **Spot/抢占实例** | 使用竞价实例 | 50-90% | 可能被回收 | 无状态/可中断任务 |
| **预留实例** | 提前购买折扣 | 30-60% | 预付款 | 稳定基线负载 |
| **节省计划** | 承诺使用量折扣 | 20-50% | 承诺 | 可预测负载 |
| **混合节点池** | 按需+Spot组合 | 30-50% | 中等 | 生产环境 |
| **自动扩缩容** | 按需扩缩 | 20-40% | 扩容延迟 | 弹性负载 |

```yaml
# ACK Spot节点池配置
apiVersion: v1
kind: NodePool
metadata:
  name: spot-pool
spec:
  nodeConfig:
    instanceTypes:
    - ecs.c6.xlarge
    - ecs.c6.2xlarge
    spotStrategy: SpotWithPriceLimit
    spotPriceLimit: 0.5  # 最高出价
  scaling:
    minSize: 0
    maxSize: 100
    desiredSize: 5
  taints:
  - key: spot
    value: "true"
    effect: NoSchedule
```

## Cluster Autoscaler优化

| 参数 | 优化值 | 效果 |
|-----|-------|------|
| **scale-down-utilization-threshold** | 0.5 | 利用率<50%触发缩容 |
| **scale-down-unneeded-time** | 10m | 空闲10分钟后缩容 |
| **scale-down-delay-after-add** | 10m | 扩容后10分钟内不缩容 |
| **expander** | least-waste | 选择浪费最少的节点组 |
| **skip-nodes-with-local-storage** | false | 允许缩容带本地存储节点 |

## 存储成本优化

| 策略 | 描述 | 节省比例 | 实现方式 |
|-----|------|---------|---------|
| **存储分层** | 冷热数据分离 | 30-50% | 多StorageClass |
| **快照生命周期** | 自动删除旧快照 | 20-40% | 快照策略 |
| **PVC回收** | 清理未使用PVC | 变化 | 定期审计 |
| **压缩/去重** | 存储优化 | 20-40% | 存储系统配置 |

```yaml
# 存储分层StorageClass
# 高性能层
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: high-performance
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
  performanceLevel: PL2
---
# 标准层
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
  performanceLevel: PL0
---
# 归档层
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: archive
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_efficiency
```

## 网络成本优化

| 策略 | 描述 | 实现方式 |
|-----|------|---------|
| **同区部署** | 减少跨AZ流量 | 拓扑约束 |
| **本地DNS缓存** | 减少DNS查询 | NodeLocal DNSCache |
| **服务网格优化** | 减少Sidecar开销 | eBPF模式 |
| **压缩传输** | 减少数据量 | gzip/brotli |
| **CDN** | 缓存静态内容 | 云CDN |

```yaml
# 同区拓扑约束
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: myapp
```

## 成本监控工具

| 工具 | 功能 | 部署方式 | 成本 |
|-----|------|---------|------|
| **Kubecost** | 全面成本分析 | Helm | 开源/商业 |
| **OpenCost** | CNCF成本监控 | Helm | 开源 |
| **云厂商成本工具** | 云账单分析 | 原生 | 免费 |
| **Prometheus+Grafana** | 自定义指标 | Helm | 开源 |

```bash
# Kubecost安装
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm install kubecost kubecost/cost-analyzer \
  --namespace kubecost \
  --create-namespace \
  --set prometheus.server.persistentVolume.enabled=false
```

## 成本分配标签

```yaml
# 成本分配标签规范
metadata:
  labels:
    # 业务标签
    app.kubernetes.io/name: myapp
    app.kubernetes.io/component: frontend
    # 成本标签
    cost-center: "engineering"
    team: "platform"
    environment: "production"
    project: "project-a"
```

## 成本优化清单

| 优化项 | 潜在节省 | 实施难度 | 优先级 |
|-------|---------|---------|-------|
| **启用自动扩缩容** | 20-40% | 低 | P0 |
| **使用Spot实例** | 50-90% | 中 | P0 |
| **资源右置大小** | 20-30% | 低 | P0 |
| **清理闲置资源** | 变化 | 低 | P1 |
| **存储分层** | 30-50% | 中 | P1 |
| **预留实例/节省计划** | 30-60% | 低 | P1 |
| **网络优化** | 10-20% | 中 | P2 |

## ACK成本优化

| 功能 | 配置方式 | 效果 |
|-----|---------|------|
| **Spot节点池** | 节点池配置 | 计算成本降低 |
| **弹性伸缩** | ESS集成 | 按需付费 |
| **预留实例券** | 购买 | 长期折扣 |
| **节省计划** | 购买 | 承诺折扣 |
| **资源画像** | ARMS | 推荐配置 |

---

**成本原则**: 监控先行，右置大小，弹性优先，持续优化
