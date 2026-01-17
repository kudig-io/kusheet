# 表格41：灾备策略表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/tasks/administer-cluster](https://kubernetes.io/docs/tasks/administer-cluster/)

## 灾备类型

| 类型 | 描述 | RPO | RTO | 成本 | 适用场景 |
|-----|------|-----|-----|------|---------|
| **备份恢复** | 定期备份，故障时恢复 | 小时级 | 小时级 | 低 | 开发/测试 |
| **主备切换** | 备用集群热备 | 分钟级 | 分钟级 | 中 | 重要业务 |
| **双活** | 两个集群同时服务 | 秒级 | 秒级 | 高 | 核心业务 |
| **多活** | 多个集群同时服务 | 秒级 | 秒级 | 很高 | 全球业务 |

## 灾备组件

| 组件 | 用途 | 备份策略 | 恢复方法 |
|-----|------|---------|---------|
| **etcd** | 集群状态 | 定期快照 | 快照恢复 |
| **资源定义** | K8S资源YAML | Velero/GitOps | 重新apply |
| **持久化数据** | PV数据 | CSI快照/Velero | 快照恢复 |
| **配置** | ConfigMap/Secret | GitOps | 重新apply |
| **证书** | TLS证书 | 证书备份 | 重新生成/恢复 |

## 多AZ部署

```yaml
# 跨AZ部署拓扑约束
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 6
  template:
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: myapp
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: myapp
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: myapp
              topologyKey: kubernetes.io/hostname
```

## 跨地域复制

| 方案 | 数据同步 | 延迟 | 适用场景 |
|-----|---------|------|---------|
| **数据库主从** | 异步复制 | 秒-分钟 | 数据库 |
| **对象存储复制** | 异步复制 | 分钟 | 文件数据 |
| **消息队列** | 跨区消费 | 秒级 | 事件驱动 |
| **Velero跨区备份** | 定期同步 | 小时 | 灾难恢复 |

## 灾备演练

| 演练类型 | 频率 | 范围 | 验证内容 |
|---------|------|------|---------|
| **桌面演练** | 季度 | 流程 | 流程文档 |
| **组件故障** | 月度 | 单组件 | 自动恢复 |
| **节点故障** | 月度 | 节点 | Pod迁移 |
| **AZ故障** | 季度 | 可用区 | 业务连续性 |
| **全量恢复** | 半年 | 集群 | 完整恢复能力 |

```bash
# 模拟节点故障
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl cordon <node>

# 模拟Pod故障
kubectl delete pod <pod> --grace-period=0 --force

# 模拟网络分区(需要网络工具)
# iptables -A INPUT -s <ip> -j DROP

# 恢复
kubectl uncordon <node>
```

## Velero跨区备份

```yaml
# Velero备份位置(多区域)
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: primary
  namespace: velero
spec:
  provider: alibabacloud
  objectStorage:
    bucket: velero-backup-primary
    prefix: backups
  config:
    region: cn-hangzhou
---
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: secondary
  namespace: velero
spec:
  provider: alibabacloud
  objectStorage:
    bucket: velero-backup-secondary
    prefix: backups
  config:
    region: cn-shanghai
---
# 定时备份(同时备份到两个位置)
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"
  template:
    includedNamespaces:
    - production
    - staging
    storageLocation: primary
    ttl: 720h  # 30天
    snapshotVolumes: true
```

## 集群联邦灾备

```yaml
# Karmada策略(跨集群调度)
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
  name: app-propagation
spec:
  resourceSelectors:
  - apiVersion: apps/v1
    kind: Deployment
    name: app
  placement:
    clusterAffinity:
      clusterNames:
      - cluster-beijing
      - cluster-shanghai
    replicaScheduling:
      replicaSchedulingType: Divided
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
---
# 故障转移策略
apiVersion: policy.karmada.io/v1alpha1
kind: OverridePolicy
metadata:
  name: failover-policy
spec:
  targetCluster:
    clusterNames:
    - cluster-shanghai
  overrideRules:
  - targetCluster:
      clusterNames:
      - cluster-shanghai
    overriders:
      plaintext:
      - path: /spec/replicas
        operator: replace
        value: 0  # 正常情况下备集群0副本
```

## RPO/RTO目标设定

| 业务级别 | RPO目标 | RTO目标 | 成本级别 |
|---------|--------|--------|---------|
| **关键业务** | <1分钟 | <5分钟 | 很高 |
| **重要业务** | <15分钟 | <30分钟 | 高 |
| **一般业务** | <1小时 | <2小时 | 中 |
| **非关键业务** | <24小时 | <24小时 | 低 |

## 灾备检查清单

| 检查项 | 验证方法 | 频率 |
|-------|---------|------|
| **etcd备份完整性** | 测试恢复 | 周 |
| **Velero备份成功** | 查看备份状态 | 日 |
| **跨区数据同步** | 数据一致性检查 | 日 |
| **DNS切换能力** | 模拟切换 | 月 |
| **恢复流程文档** | 文档审核 | 季 |
| **全量恢复测试** | 恢复演练 | 半年 |

## ACK灾备方案

| 方案 | 配置方式 | 适用场景 |
|-----|---------|---------|
| **跨AZ** | 多AZ节点池 | 高可用 |
| **跨地域备份** | Velero+OSS | 灾难恢复 |
| **多集群** | ACK One | 双活/多活 |
| **混合云** | ACK+本地 | 云灾备 |

---

**灾备原则**: 定期演练，自动化恢复，多层防护
