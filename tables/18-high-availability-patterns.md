# 18 - 高可用架构模式 (High Availability Patterns)

## 高可用核心指标

| 指标 | 英文 | 说明 | 计算方式 |
|-----|-----|------|---------|
| 可用性 | Availability | 系统正常运行时间比例 | 正常时间/总时间 |
| MTBF | Mean Time Between Failures | 平均故障间隔 | 运行时间/故障次数 |
| MTTR | Mean Time To Repair | 平均修复时间 | 修复时间/故障次数 |
| RTO | Recovery Time Objective | 恢复时间目标 | 业务可接受停机时间 |
| RPO | Recovery Point Objective | 恢复点目标 | 可接受数据丢失量 |

## 可用性等级

| 等级 | 年停机时间 | 月停机时间 | 典型场景 |
|-----|----------|----------|---------|
| 99% | 3.65天 | 7.3小时 | 内部系统 |
| 99.9% | 8.76小时 | 43分钟 | 一般业务 |
| 99.99% | 52.6分钟 | 4.3分钟 | 核心业务 |
| 99.999% | 5.26分钟 | 26秒 | 金融/电信 |

## K8s控制平面高可用

| 组件 | 部署模式 | 最小副本 | 推荐副本 |
|-----|---------|---------|---------|
| etcd | 集群 | 3 | 5 |
| kube-apiserver | 多副本+LB | 2 | 3 |
| kube-scheduler | 主备选举 | 2 | 3 |
| kube-controller-manager | 主备选举 | 2 | 3 |

### 控制平面架构

```
                    ┌─────────────────┐
                    │   Load Balancer │
                    │  (VIP/云LB/HAProxy)
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
  │ Master-1    │    │ Master-2    │    │ Master-3    │
  │ ┌─────────┐ │    │ ┌─────────┐ │    │ ┌─────────┐ │
  │ │apiserver│ │    │ │apiserver│ │    │ │apiserver│ │
  │ ├─────────┤ │    │ ├─────────┤ │    │ ├─────────┤ │
  │ │scheduler│ │    │ │scheduler│ │    │ │scheduler│ │
  │ │(standby)│ │    │ │(leader) │ │    │ │(standby)│ │
  │ ├─────────┤ │    │ ├─────────┤ │    │ ├─────────┤ │
  │ │ctrl-mgr │ │    │ │ctrl-mgr │ │    │ │ctrl-mgr │ │
  │ │(leader) │ │    │ │(standby)│ │    │ │(standby)│ │
  │ ├─────────┤ │    │ ├─────────┤ │    │ ├─────────┤ │
  │ │  etcd   │ │    │ │  etcd   │ │    │ │  etcd   │ │
  │ └─────────┘ │    │ └─────────┘ │    │ └─────────┘ │
  └─────────────┘    └─────────────┘    └─────────────┘
```

## Leader选举机制

| 组件 | 选举方式 | 锁资源 |
|-----|---------|-------|
| kube-scheduler | Lease对象 | kube-system/kube-scheduler |
| kube-controller-manager | Lease对象 | kube-system/kube-controller-manager |
| 自定义控制器 | Lease/ConfigMap/Endpoint | 自定义 |

### Lease选举参数

| 参数 | 说明 | 默认值 |
|-----|------|-------|
| --leader-elect | 启用选举 | true |
| --leader-elect-lease-duration | 租约时长 | 15s |
| --leader-elect-renew-deadline | 续约截止时间 | 10s |
| --leader-elect-retry-period | 重试间隔 | 2s |

## 工作负载高可用

| 策略 | 说明 | 配置 |
|-----|------|------|
| 多副本 | 运行多个Pod | replicas >= 2 |
| 反亲和性 | 分散到不同节点 | podAntiAffinity |
| 跨AZ分布 | 分散到不同可用区 | topologySpreadConstraints |
| PDB | 限制同时不可用数 | PodDisruptionBudget |

### 高可用Deployment示例

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ha-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ha-app
  template:
    metadata:
      labels:
        app: ha-app
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: ha-app
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: ha-app
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: ha-app
            topologyKey: kubernetes.io/hostname
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ha-app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: ha-app
```

## 故障检测与恢复

| 机制 | 检测对象 | 恢复动作 |
|-----|---------|---------|
| livenessProbe | 应用健康 | 重启容器 |
| readinessProbe | 应用就绪 | 移除Endpoints |
| Node Controller | 节点心跳 | 驱逐Pod |
| ReplicaSet | Pod数量 | 创建新Pod |

## 节点故障处理

| 阶段 | 时间 | 动作 |
|-----|------|------|
| 节点失联 | 0s | 心跳丢失 |
| Unknown状态 | 40s | node-monitor-grace-period |
| 开始驱逐 | 5m | pod-eviction-timeout |
| 创建新Pod | 5m+ | ReplicaSet调谐 |

### 加速故障恢复

```yaml
# kubelet配置
nodeStatusUpdateFrequency: 10s      # 上报频率(默认10s)

# kube-controller-manager配置
--node-monitor-period=5s            # 检查周期(默认5s)
--node-monitor-grace-period=40s     # 宽限期(默认40s)
--pod-eviction-timeout=30s          # 驱逐超时(默认5m)
```

## 跨可用区高可用

| 层级 | 策略 |
|-----|------|
| 集群级 | 控制平面跨AZ部署 |
| 节点级 | 节点池跨AZ分布 |
| Pod级 | topologySpreadConstraints |
| 存储级 | 跨AZ复制存储 |
| 网络级 | 多AZ负载均衡 |

## 服务高可用模式

| 模式 | 说明 | 适用场景 |
|-----|------|---------|
| Active-Active | 多副本同时服务 | 无状态服务 |
| Active-Passive | 主备切换 | 有状态服务 |
| N+1 | N个活动+1个备用 | 容量冗余 |
| N+M | N个活动+M个备用 | 高冗余要求 |

## 健康检查最佳实践

| 实践 | 说明 |
|-----|------|
| 区分liveness和readiness | 不同目的,不同配置 |
| 合理设置超时 | 避免误判 |
| 使用startupProbe | 慢启动应用 |
| 专用健康端点 | 不依赖业务逻辑 |
| 级联检查 | 检查关键依赖 |

## 常见故障场景

| 故障 | 影响 | 缓解措施 |
|-----|------|---------|
| 单节点故障 | 部分Pod不可用 | 多副本+反亲和 |
| AZ故障 | 单AZ Pod不可用 | 跨AZ分布 |
| 控制平面故障 | 无法变更资源 | 控制平面HA |
| etcd故障 | 集群不可用 | etcd集群化 |
| 网络分区 | 部分节点隔离 | 多网络路径 |

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)
