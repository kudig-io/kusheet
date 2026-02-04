# Kubernetes 灾难恢复策略 (Disaster Recovery Strategy)

> **适用版本**: Kubernetes v1.25 - v1.32  
> **文档版本**: v2.0 | 生产级灾难恢复参考指南  
> **最后更新**: 2026-01

## 灾难恢复整体架构

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                      Kubernetes Disaster Recovery Architecture                              │
├─────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                              DR Strategy Tiers                                         │ │
│  │                                                                                        │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │ │
│  │  │   Tier 1        │  │   Tier 2        │  │   Tier 3        │  │   Tier 4        │  │ │
│  │  │   Backup/       │  │   Active/       │  │   Active/       │  │   Multi-        │  │ │
│  │  │   Restore       │  │   Standby       │  │   Active        │  │   Active        │  │ │
│  │  │                 │  │                 │  │                 │  │                 │  │ │
│  │  │  RTO: 4-24h     │  │  RTO: 15m-4h    │  │  RTO: < 15m     │  │  RTO: ~ 0       │  │ │
│  │  │  RPO: 1-24h     │  │  RPO: 15m-1h    │  │  RPO: < 5m      │  │  RPO: ~ 0       │  │ │
│  │  │  Cost: $        │  │  Cost: $$       │  │  Cost: $$$      │  │  Cost: $$$$     │  │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘  │ │
│  └───────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                              Primary Region (Active)                                   │ │
│  │                                                                                        │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐ │ │
│  │  │                        Production Cluster                                        │ │ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │ │ │
│  │  │  │   AZ-1      │  │   AZ-2      │  │   AZ-3      │  │ Control     │            │ │ │
│  │  │  │             │  │             │  │             │  │ Plane       │            │ │ │
│  │  │  │ • Workers   │  │ • Workers   │  │ • Workers   │  │ • etcd      │            │ │ │
│  │  │  │ • Apps      │  │ • Apps      │  │ • Apps      │  │ • API Server│            │ │ │
│  │  │  │ • Storage   │  │ • Storage   │  │ • Storage   │  │ • Scheduler │            │ │ │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘            │ │ │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘ │ │
│  │                              │                                                        │ │
│  │                              │ Continuous Replication                                │ │
│  │                              ▼                                                        │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐ │ │
│  │  │  Backup & Replication Layer                                                      │ │ │
│  │  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐    │ │ │
│  │  │  │ etcd Backup   │  │ Velero        │  │ Volume        │  │ Database      │    │ │ │
│  │  │  │               │  │ Backup        │  │ Replication   │  │ Replication   │    │ │ │
│  │  │  │ • Snapshots   │  │ • Resources   │  │ • CSI Snap    │  │ • MySQL       │    │ │ │
│  │  │  │ • S3 Upload   │  │ • PV Data     │  │ • Async Copy  │  │ • PostgreSQL  │    │ │ │
│  │  │  └───────────────┘  └───────────────┘  └───────────────┘  └───────────────┘    │ │ │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────────────────────────────────┘ │
│                                          │                                                  │
│                                          │ Cross-Region Sync                               │
│                                          ▼                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                              DR Region (Standby/Active)                                │ │
│  │                                                                                        │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐ │ │
│  │  │                        DR Cluster                                                │ │ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │ │ │
│  │  │  │   AZ-1      │  │   AZ-2      │  │   AZ-3      │  │ Control     │            │ │ │
│  │  │  │             │  │             │  │             │  │ Plane       │            │ │ │
│  │  │  │ • Workers   │  │ • Workers   │  │ • Workers   │  │ • etcd      │            │ │ │
│  │  │  │ • Replicas  │  │ • Replicas  │  │ • Replicas  │  │ • API Server│            │ │ │
│  │  │  │ • Storage   │  │ • Storage   │  │ • Storage   │  │ • Ready     │            │ │ │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘            │ │ │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                              Global Traffic Management                                 │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐ │ │
│  │  │                     DNS / Global Load Balancer                                   │ │ │
│  │  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐    │ │ │
│  │  │  │ Route53       │  │ CloudFlare    │  │ Akamai GTM    │  │ Azure Traffic │    │ │ │
│  │  │  │               │  │               │  │               │  │ Manager       │    │ │ │
│  │  │  │ • Health      │  │ • Failover    │  │ • Weighted    │  │ • Priority    │    │ │ │
│  │  │  │   Checks      │  │ • Geo-routing │  │   Routing     │  │   Routing     │    │ │ │
│  │  │  └───────────────┘  └───────────────┘  └───────────────┘  └───────────────┘    │ │ │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                             │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

## DR 策略类型详细对比

| 策略类型 | RTO | RPO | 成本 | 复杂度 | 适用场景 | 数据一致性 |
|---------|-----|-----|------|-------|---------|-----------|
| **备份/恢复** | 4-24h | 1-24h | $ | 低 | 非关键应用 | 最终一致 |
| **Pilot Light** | 1-4h | 15m-1h | $$ | 中 | 标准业务 | 最终一致 |
| **Warm Standby** | 15m-1h | 5-15m | $$$ | 中高 | 重要业务 | 近实时 |
| **Active/Standby** | 5-15m | 1-5m | $$$$ | 高 | 关键业务 | 近实时 |
| **Active/Active** | < 1m | < 1m | $$$$$ | 很高 | 核心业务 | 强一致 |
| **Multi-Active** | ~0 | ~0 | $$$$$$ | 极高 | 金融/交易 | 强一致 |

### 各策略架构对比

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                           DR Strategy Comparison                                        │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│  Backup/Restore                    Pilot Light                                         │
│  ┌───────────────────────┐        ┌───────────────────────┐                           │
│  │  Primary              │        │  Primary              │                           │
│  │  ┌─────────────────┐ │        │  ┌─────────────────┐ │                           │
│  │  │ █████████████   │ │        │  │ █████████████   │ │                           │
│  │  │ Full Workload   │ │        │  │ Full Workload   │ │                           │
│  │  └─────────────────┘ │        │  └─────────────────┘ │                           │
│  │           │          │        │           │          │                           │
│  │           ▼ Backup   │        │           ▼ Sync     │                           │
│  │  ┌─────────────────┐ │        │  ┌─────────────────┐ │                           │
│  │  │ S3/Object Store │ │        │  │ S3 + Replicated │ │                           │
│  │  └─────────────────┘ │        │  │ Data            │ │                           │
│  └───────────────────────┘        │  └─────────────────┘ │                           │
│           │                       └───────────────────────┘                           │
│           │ Restore                          │                                        │
│           ▼                                  ▼                                        │
│  ┌───────────────────────┐        ┌───────────────────────┐                           │
│  │  DR (On-demand)       │        │  DR (Minimal)         │                           │
│  │  ┌─────────────────┐ │        │  ┌─────────────────┐ │                           │
│  │  │ ░░░░░░░░░░░░░   │ │        │  │ ▒▒▒ Core only   │ │                           │
│  │  │ Provision on    │ │        │  │ DB + etcd       │ │                           │
│  │  │ demand          │ │        │  │ running         │ │                           │
│  │  └─────────────────┘ │        │  └─────────────────┘ │                           │
│  └───────────────────────┘        └───────────────────────┘                           │
│                                                                                         │
│  Warm Standby                      Active/Active                                       │
│  ┌───────────────────────┐        ┌───────────────────────┐                           │
│  │  Primary              │        │  Region A             │                           │
│  │  ┌─────────────────┐ │        │  ┌─────────────────┐ │                           │
│  │  │ █████████████   │ │        │  │ █████████████   │ │                           │
│  │  │ Full Workload   │ │◄──────►│  │ Full Workload   │ │                           │
│  │  └─────────────────┘ │  Sync  │  └─────────────────┘ │                           │
│  │           │          │        │           ▲          │                           │
│  │           │ Replicate│        │           │          │                           │
│  │           ▼          │        │           │ Traffic  │                           │
│  └───────────────────────┘        │           │          │                           │
│           │                       └───────────────────────┘                           │
│           ▼                                  │                                        │
│  ┌───────────────────────┐                   │                                        │
│  │  DR (Scaled down)     │        ┌───────────────────────┐                           │
│  │  ┌─────────────────┐ │        │  Region B             │                           │
│  │  │ ▓▓▓▓▓▓▓ Reduced │ │        │  ┌─────────────────┐ │                           │
│  │  │ capacity but    │ │        │  │ █████████████   │ │                           │
│  │  │ running         │ │◄──────►│  │ Full Workload   │ │                           │
│  │  └─────────────────┘ │  Sync  │  └─────────────────┘ │                           │
│  └───────────────────────┘        └───────────────────────┘                           │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 多可用区 (Multi-AZ) 部署

### Multi-AZ 架构图

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                         Multi-AZ Kubernetes Deployment                                  │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│                              Region: us-west-2                                          │
│  ┌───────────────────────────────────────────────────────────────────────────────────┐ │
│  │                          Load Balancer (Cross-AZ)                                  │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐ │ │
│  │  │                         NLB / ALB / Ingress                                  │ │ │
│  │  │                              │                                               │ │ │
│  │  │              ┌───────────────┼───────────────┐                              │ │ │
│  │  │              │               │               │                              │ │ │
│  │  └──────────────┼───────────────┼───────────────┼──────────────────────────────┘ │ │
│  │                 ▼               ▼               ▼                                 │ │
│  │  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐                    │ │
│  │  │    AZ-2a        │ │    AZ-2b        │ │    AZ-2c        │                    │ │
│  │  │                 │ │                 │ │                 │                    │ │
│  │  │ ┌─────────────┐│ │ ┌─────────────┐│ │ ┌─────────────┐│                    │ │
│  │  │ │Control Plane││ │ │Control Plane││ │ │Control Plane││                    │ │
│  │  │ │• API Server ││ │ │• API Server ││ │ │• API Server ││                    │ │
│  │  │ │• etcd       ││ │ │• etcd       ││ │ │• etcd       ││                    │ │
│  │  │ │• Scheduler  ││ │ │• Scheduler  ││ │ │• Controller ││                    │ │
│  │  │ └─────────────┘│ │ └─────────────┘│ │ └─────────────┘│                    │ │
│  │  │                 │ │                 │ │                 │                    │ │
│  │  │ ┌─────────────┐│ │ ┌─────────────┐│ │ ┌─────────────┐│                    │ │
│  │  │ │ Worker Nodes││ │ │ Worker Nodes││ │ │ Worker Nodes││                    │ │
│  │  │ │             ││ │ │             ││ │ │             ││                    │ │
│  │  │ │ ┌─────────┐ ││ │ │ ┌─────────┐ ││ │ │ ┌─────────┐ ││                    │ │
│  │  │ │ │ App-1   │ ││ │ │ │ App-1   │ ││ │ │ │ App-1   │ ││                    │ │
│  │  │ │ │ replica │ ││ │ │ │ replica │ ││ │ │ │ replica │ ││                    │ │
│  │  │ │ └─────────┘ ││ │ │ └─────────┘ ││ │ │ └─────────┘ ││                    │ │
│  │  │ │ ┌─────────┐ ││ │ │ ┌─────────┐ ││ │ │ ┌─────────┐ ││                    │ │
│  │  │ │ │ DB      │ ││ │ │ │ DB      │ ││ │ │ │ DB      │ ││                    │ │
│  │  │ │ │ Primary │ ││ │ │ │ Replica │ ││ │ │ │ Replica │ ││                    │ │
│  │  │ │ └─────────┘ ││ │ │ └─────────┘ ││ │ │ └─────────┘ ││                    │ │
│  │  │ └─────────────┘│ │ └─────────────┘│ │ └─────────────┘│                    │ │
│  │  │                 │ │                 │ │                 │                    │ │
│  │  │ ┌─────────────┐│ │ ┌─────────────┐│ │ ┌─────────────┐│                    │ │
│  │  │ │   Storage   ││ │ │   Storage   ││ │ │   Storage   ││                    │ │
│  │  │ │   EBS/EFS   ││ │ │   EBS/EFS   ││ │ │   EBS/EFS   ││                    │ │
│  │  │ └─────────────┘│ │ └─────────────┘│ │ └─────────────┘│                    │ │
│  │  └─────────────────┘ └─────────────────┘ └─────────────────┘                    │ │
│  │           │                   │                   │                              │ │
│  │           └───────────────────┼───────────────────┘                              │ │
│  │                               │                                                   │ │
│  │                               ▼                                                   │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐ │ │
│  │  │                    Cross-AZ Storage (EFS/S3)                                 │ │ │
│  │  │                    • Shared file systems                                     │ │ │
│  │  │                    • Object storage                                          │ │ │
│  │  │                    • Database backups                                        │ │ │
│  │  └─────────────────────────────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### Multi-AZ 配置示例

```yaml
# multi-az-deployment.yaml
---
# Pod Anti-Affinity for AZ spread
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: production
spec:
  replicas: 6
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      # Topology spread constraints (K8s 1.19+)
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: web-app
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: web-app
      
      # Pod anti-affinity (alternative)
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: web-app
              topologyKey: topology.kubernetes.io/zone
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: web-app
                topologyKey: kubernetes.io/hostname
      
      containers:
        - name: web-app
          image: myapp:latest
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: 2
              memory: 2Gi
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
---
# StatefulSet with zone-aware storage
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
  namespace: production
spec:
  serviceName: database
  replicas: 3
  podManagementPolicy: Parallel
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: database
      containers:
        - name: mysql
          image: mysql:8.0
          ports:
            - containerPort: 3306
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: root-password
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: gp3-encrypted
        resources:
          requests:
            storage: 100Gi
---
# Zone-aware StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-encrypted
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer  # Zone-aware binding
allowVolumeExpansion: true
reclaimPolicy: Retain
---
# PodDisruptionBudget for HA
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-app-pdb
  namespace: production
spec:
  minAvailable: 2  # or maxUnavailable: 1
  selector:
    matchLabels:
      app: web-app
```

---

## 跨区域复制 (Cross-Region Replication)

### 跨区域架构图

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                       Cross-Region Disaster Recovery                                    │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│  ┌───────────────────────────────────────────────────────────────────────────────────┐ │
│  │                         Global DNS / Traffic Manager                               │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐ │ │
│  │  │                    Route53 / CloudFlare / Akamai GTM                         │ │ │
│  │  │                                                                              │ │ │
│  │  │  app.example.com ────► Health Check + Failover Policy                       │ │ │
│  │  │                              │                                               │ │ │
│  │  │              ┌───────────────┴───────────────┐                              │ │ │
│  │  │              │                               │                              │ │ │
│  │  │         Primary (100%)              Secondary (0% / Failover)               │ │ │
│  │  │              │                               │                              │ │ │
│  │  └──────────────┼───────────────────────────────┼──────────────────────────────┘ │ │
│  │                 │                               │                                 │ │
│  │                 ▼                               ▼                                 │ │
│  └───────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                         │
│  ┌─────────────────────────────────┐     ┌─────────────────────────────────┐         │
│  │       Primary Region            │     │       DR Region                 │         │
│  │       (us-west-2)               │     │       (us-east-1)               │         │
│  │                                 │     │                                 │         │
│  │  ┌───────────────────────────┐ │     │  ┌───────────────────────────┐ │         │
│  │  │   Production Cluster      │ │     │  │   DR Cluster              │ │         │
│  │  │                           │ │     │  │                           │ │         │
│  │  │   ┌─────────────────────┐│ │     │  │   ┌─────────────────────┐│ │         │
│  │  │   │ Control Plane       ││ │     │  │   │ Control Plane       ││ │         │
│  │  │   │ (3x etcd, HA)       ││ │     │  │   │ (3x etcd, HA)       ││ │         │
│  │  │   └─────────────────────┘│ │     │  │   └─────────────────────┘│ │         │
│  │  │                           │ │     │  │                           │ │         │
│  │  │   ┌─────────────────────┐│ │     │  │   ┌─────────────────────┐│ │         │
│  │  │   │ Worker Nodes (10)   ││ │     │  │   │ Worker Nodes (3-10) ││ │         │
│  │  │   │ Full Capacity       ││ │     │  │   │ Scaled down or      ││ │         │
│  │  │   └─────────────────────┘│ │     │  │   │ Auto-scale on DR    ││ │         │
│  │  │                           │ │     │  │   └─────────────────────┘│ │         │
│  │  │   ┌─────────────────────┐│ │     │  │   ┌─────────────────────┐│ │         │
│  │  │   │ Database (Primary)  │├─┼─────┼──┼──►│ Database (Replica)  ││ │         │
│  │  │   │ MySQL/PostgreSQL    ││ │ Async│  │   │ Read replica        ││ │         │
│  │  │   └─────────────────────┘│ │ Repl │  │   └─────────────────────┘│ │         │
│  │  └───────────────────────────┘ │     │  └───────────────────────────┘ │         │
│  │                                 │     │                                 │         │
│  │  ┌───────────────────────────┐ │     │  ┌───────────────────────────┐ │         │
│  │  │ S3 Bucket (Primary)      │ │     │  │ S3 Bucket (Replica)      │ │         │
│  │  │                          │ │     │  │                          │ │         │
│  │  │ • Velero backups         ├─┼─────┼──┤ • Cross-region           │ │         │
│  │  │ • etcd snapshots         │ │ CRR │  │   replication            │ │         │
│  │  │ • Application data       │ │     │  │ • Same data available    │ │         │
│  │  └───────────────────────────┘ │     │  └───────────────────────────┘ │         │
│  │                                 │     │                                 │         │
│  │  ┌───────────────────────────┐ │     │  ┌───────────────────────────┐ │         │
│  │  │ Volume Snapshots         │ │     │  │ Volume Snapshots         │ │         │
│  │  │                          │ │     │  │                          │ │         │
│  │  │ • EBS Snapshots          ├─┼─────┼──┤ • Cross-region copy      │ │         │
│  │  │ • CSI Snapshots          │ │Copy │  │ • Ready for restore      │ │         │
│  │  └───────────────────────────┘ │     │  └───────────────────────────┘ │         │
│  └─────────────────────────────────┘     └─────────────────────────────────┘         │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### 跨区域复制配置

```yaml
# cross-region-replication.yaml
---
# S3 Cross-Region Replication (via AWS CLI/Terraform)
# aws s3api put-bucket-replication
# Terraform/Pulumi configuration example:
#
# resource "aws_s3_bucket_replication_configuration" "velero" {
#   bucket = aws_s3_bucket.velero_primary.id
#   role   = aws_iam_role.replication.arn
#
#   rule {
#     id     = "velero-replication"
#     status = "Enabled"
#
#     destination {
#       bucket        = aws_s3_bucket.velero_dr.arn
#       storage_class = "STANDARD_IA"
#     }
#   }
# }

---
# Velero with multiple BSLs for cross-region
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: primary
  namespace: velero
spec:
  provider: aws
  objectStorage:
    bucket: velero-backups-us-west-2
    prefix: backups
  config:
    region: us-west-2
  default: true
  accessMode: ReadWrite
---
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: dr-region
  namespace: velero
spec:
  provider: aws
  objectStorage:
    bucket: velero-backups-us-east-1
    prefix: backups
  config:
    region: us-east-1
  accessMode: ReadOnly  # Read-only in primary cluster
---
# Schedule that backs up to both regions
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: cross-region-backup
  namespace: velero
spec:
  schedule: "0 */6 * * *"
  template:
    storageLocation: primary
    volumeSnapshotLocations:
      - primary
    includedNamespaces:
      - production
    ttl: 720h
    hooks:
      resources:
        - name: copy-to-dr
          post:
            - exec:
                command:
                  - /bin/sh
                  - -c
                  - |
                    # Trigger copy to DR region
                    aws s3 sync s3://velero-backups-us-west-2 s3://velero-backups-us-east-1
```

### EBS 快照跨区域复制

```bash
#!/bin/bash
# ebs-snapshot-cross-region-copy.sh

set -euo pipefail

SOURCE_REGION="${SOURCE_REGION:-us-west-2}"
DEST_REGION="${DEST_REGION:-us-east-1}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Find snapshots to copy
find_snapshots_to_copy() {
    aws ec2 describe-snapshots \
        --region "$SOURCE_REGION" \
        --owner-ids self \
        --filters "Name=tag:kubernetes.io/cluster/*,Values=owned" \
        --query 'Snapshots[?State==`completed`].{ID:SnapshotId,Time:StartTime,VolumeId:VolumeId}' \
        --output json
}

# Copy snapshot to DR region
copy_snapshot() {
    local snapshot_id="$1"
    local description="DR copy of $snapshot_id"
    
    log "Copying snapshot $snapshot_id to $DEST_REGION..."
    
    local new_snapshot_id=$(aws ec2 copy-snapshot \
        --region "$DEST_REGION" \
        --source-region "$SOURCE_REGION" \
        --source-snapshot-id "$snapshot_id" \
        --description "$description" \
        --query 'SnapshotId' \
        --output text)
    
    # Tag the new snapshot
    aws ec2 create-tags \
        --region "$DEST_REGION" \
        --resources "$new_snapshot_id" \
        --tags \
            Key=SourceSnapshot,Value="$snapshot_id" \
            Key=SourceRegion,Value="$SOURCE_REGION" \
            Key=CopyDate,Value="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            Key=Purpose,Value=DR
    
    log "Created snapshot $new_snapshot_id in $DEST_REGION"
}

# Cleanup old DR snapshots
cleanup_old_snapshots() {
    local cutoff_date=$(date -d "-${RETENTION_DAYS} days" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
                        date -v-${RETENTION_DAYS}d -u +%Y-%m-%dT%H:%M:%SZ)
    
    log "Cleaning up DR snapshots older than $cutoff_date..."
    
    aws ec2 describe-snapshots \
        --region "$DEST_REGION" \
        --owner-ids self \
        --filters "Name=tag:Purpose,Values=DR" \
        --query "Snapshots[?StartTime<'$cutoff_date'].SnapshotId" \
        --output text | tr '\t' '\n' | while read -r snapshot_id; do
        if [[ -n "$snapshot_id" ]]; then
            log "Deleting old snapshot: $snapshot_id"
            aws ec2 delete-snapshot --region "$DEST_REGION" --snapshot-id "$snapshot_id"
        fi
    done
}

# Main
main() {
    log "Starting cross-region snapshot copy..."
    
    local snapshots=$(find_snapshots_to_copy)
    local count=$(echo "$snapshots" | jq length)
    
    log "Found $count snapshots to process"
    
    echo "$snapshots" | jq -r '.[].ID' | while read -r snapshot_id; do
        # Check if already copied
        local existing=$(aws ec2 describe-snapshots \
            --region "$DEST_REGION" \
            --filters "Name=tag:SourceSnapshot,Values=$snapshot_id" \
            --query 'Snapshots[0].SnapshotId' \
            --output text)
        
        if [[ "$existing" == "None" || -z "$existing" ]]; then
            copy_snapshot "$snapshot_id"
        else
            log "Snapshot $snapshot_id already copied as $existing"
        fi
    done
    
    cleanup_old_snapshots
    
    log "Cross-region snapshot copy completed"
}

main "$@"
```

---

## 故障切换流程

### 故障切换决策树

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                           DR Failover Decision Tree                                     │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│                              ┌──────────────────┐                                       │
│                              │  Incident        │                                       │
│                              │  Detected        │                                       │
│                              └────────┬─────────┘                                       │
│                                       │                                                  │
│                                       ▼                                                  │
│                         ┌─────────────────────────────┐                                 │
│                         │  Is it a regional failure?  │                                 │
│                         └─────────────┬───────────────┘                                 │
│                                       │                                                  │
│                         ┌─────────────┴─────────────┐                                   │
│                         │                           │                                   │
│                        Yes                          No                                  │
│                         │                           │                                   │
│                         ▼                           ▼                                   │
│            ┌───────────────────────┐   ┌───────────────────────┐                       │
│            │ Initiate DR Failover  │   │ Is it AZ-level        │                       │
│            │                       │   │ failure?              │                       │
│            │ • Activate DR site    │   └───────────┬───────────┘                       │
│            │ • Switch DNS          │               │                                   │
│            │ • Promote DB replica  │   ┌───────────┴───────────┐                       │
│            └───────────────────────┘   │                       │                       │
│                                       Yes                      No                       │
│                                        │                       │                       │
│                                        ▼                       ▼                       │
│                         ┌───────────────────────┐ ┌───────────────────────┐            │
│                         │ Multi-AZ Failover     │ │ Application-level     │            │
│                         │                       │ │ Recovery              │            │
│                         │ • K8s auto-reschedule │ │                       │            │
│                         │ • PDB ensures         │ │ • Restart pods        │            │
│                         │   availability        │ │ • Scale replicas      │            │
│                         │ • Storage failover    │ │ • Rollback if needed  │            │
│                         └───────────────────────┘ └───────────────────────┘            │
│                                                                                         │
│  ┌───────────────────────────────────────────────────────────────────────────────────┐ │
│  │                          Failover Checklist                                        │ │
│  │                                                                                    │ │
│  │  □ 1. Confirm primary site is truly unavailable                                   │ │
│  │  □ 2. Check DR site readiness (health checks pass)                               │ │
│  │  □ 3. Verify data replication lag (RPO assessment)                               │ │
│  │  □ 4. Notify stakeholders (begin incident communication)                          │ │
│  │  □ 5. Execute database failover (promote replica to primary)                      │ │
│  │  □ 6. Scale DR workloads if needed                                               │ │
│  │  □ 7. Update DNS/traffic routing                                                 │ │
│  │  □ 8. Verify application functionality                                           │ │
│  │  □ 9. Monitor for issues                                                         │ │
│  │  □ 10. Document timeline and actions                                             │ │
│  └───────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### 自动化故障切换脚本

```bash
#!/bin/bash
# dr-failover.sh - Automated DR failover script

set -euo pipefail

# Configuration
PRIMARY_CLUSTER="${PRIMARY_CLUSTER:-primary-cluster}"
DR_CLUSTER="${DR_CLUSTER:-dr-cluster}"
PRIMARY_REGION="${PRIMARY_REGION:-us-west-2}"
DR_REGION="${DR_REGION:-us-east-1}"
HOSTED_ZONE_ID="${HOSTED_ZONE_ID:-}"
DOMAIN_NAME="${DOMAIN_NAME:-app.example.com}"
DB_CLUSTER_ID="${DB_CLUSTER_ID:-}"

# Notification
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
PAGERDUTY_KEY="${PAGERDUTY_KEY:-}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

send_notification() {
    local title="$1"
    local message="$2"
    local severity="${3:-info}"
    
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local color="good"
        [[ "$severity" == "warning" ]] && color="warning"
        [[ "$severity" == "critical" ]] && color="danger"
        
        curl -s -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{
                \"attachments\": [{
                    \"color\": \"$color\",
                    \"title\": \"$title\",
                    \"text\": \"$message\",
                    \"ts\": $(date +%s)
                }]
            }" || true
    fi
}

# Check primary cluster health
check_primary_health() {
    log "Checking primary cluster health..."
    
    kubectl config use-context "$PRIMARY_CLUSTER"
    
    # Check API server
    if ! kubectl cluster-info &>/dev/null; then
        log "Primary cluster API server is not responding"
        return 1
    fi
    
    # Check nodes
    local ready_nodes=$(kubectl get nodes --no-headers | grep -c " Ready" || echo "0")
    if [[ "$ready_nodes" -lt 1 ]]; then
        log "No ready nodes in primary cluster"
        return 1
    fi
    
    # Check critical workloads
    local unhealthy_pods=$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers | wc -l)
    if [[ "$unhealthy_pods" -gt 10 ]]; then
        log "Too many unhealthy pods in primary cluster: $unhealthy_pods"
        return 1
    fi
    
    log "Primary cluster is healthy"
    return 0
}

# Check DR cluster readiness
check_dr_readiness() {
    log "Checking DR cluster readiness..."
    
    kubectl config use-context "$DR_CLUSTER"
    
    # Check API server
    if ! kubectl cluster-info &>/dev/null; then
        log "ERROR: DR cluster API server is not responding"
        return 1
    fi
    
    # Check nodes
    local ready_nodes=$(kubectl get nodes --no-headers | grep -c " Ready" || echo "0")
    if [[ "$ready_nodes" -lt 1 ]]; then
        log "ERROR: No ready nodes in DR cluster"
        return 1
    fi
    
    # Check Velero
    if ! kubectl get deployment velero -n velero &>/dev/null; then
        log "ERROR: Velero not found in DR cluster"
        return 1
    fi
    
    log "DR cluster is ready"
    return 0
}

# Restore workloads in DR cluster
restore_workloads() {
    log "Restoring workloads in DR cluster..."
    
    kubectl config use-context "$DR_CLUSTER"
    
    # Find latest backup
    local latest_backup=$(velero backup get -o json | \
        jq -r '.items | sort_by(.status.completionTimestamp) | reverse | .[0].metadata.name')
    
    if [[ -z "$latest_backup" || "$latest_backup" == "null" ]]; then
        log "ERROR: No backup found"
        return 1
    fi
    
    log "Using backup: $latest_backup"
    
    # Check backup age
    local backup_time=$(velero backup get "$latest_backup" -o jsonpath='{.status.completionTimestamp}')
    log "Backup completed at: $backup_time"
    
    # Create restore
    local restore_name="dr-failover-$(date +%Y%m%d%H%M%S)"
    
    velero restore create "$restore_name" \
        --from-backup "$latest_backup" \
        --include-namespaces production,staging \
        --restore-volumes=true \
        --wait
    
    # Verify restore
    local restore_phase=$(velero restore get "$restore_name" -o jsonpath='{.status.phase}')
    if [[ "$restore_phase" != "Completed" ]]; then
        log "WARNING: Restore phase is $restore_phase"
    fi
    
    log "Workload restore completed"
}

# Scale workloads in DR
scale_dr_workloads() {
    log "Scaling workloads in DR cluster..."
    
    kubectl config use-context "$DR_CLUSTER"
    
    # Scale deployments to production capacity
    kubectl get deployments -n production -o json | \
        jq -r '.items[].metadata.name' | while read -r deployment; do
        # Get original replica count from annotation or default
        local replicas=$(kubectl get deployment "$deployment" -n production \
            -o jsonpath='{.metadata.annotations.dr-original-replicas}' 2>/dev/null || echo "3")
        
        kubectl scale deployment "$deployment" -n production --replicas="$replicas"
        log "Scaled deployment $deployment to $replicas replicas"
    done
    
    # Wait for pods to be ready
    kubectl wait --for=condition=available deployment --all -n production --timeout=300s || true
}

# Promote database replica
promote_database() {
    log "Promoting database replica in DR region..."
    
    if [[ -z "$DB_CLUSTER_ID" ]]; then
        log "No database cluster configured, skipping"
        return 0
    fi
    
    # For AWS RDS
    aws rds promote-read-replica-db-cluster \
        --db-cluster-identifier "${DB_CLUSTER_ID}-replica" \
        --region "$DR_REGION" || {
        log "WARNING: Database promotion failed or already promoted"
    }
    
    # Wait for database to be available
    aws rds wait db-cluster-available \
        --db-cluster-identifier "${DB_CLUSTER_ID}-replica" \
        --region "$DR_REGION"
    
    log "Database promotion completed"
}

# Update DNS to point to DR
update_dns() {
    log "Updating DNS to DR region..."
    
    if [[ -z "$HOSTED_ZONE_ID" ]]; then
        log "No hosted zone configured, skipping DNS update"
        return 0
    fi
    
    # Get DR cluster load balancer
    kubectl config use-context "$DR_CLUSTER"
    local dr_lb=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || \
        kubectl get svc -n ingress-nginx ingress-nginx-controller \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [[ -z "$dr_lb" ]]; then
        log "ERROR: Could not find DR load balancer"
        return 1
    fi
    
    # Update Route53
    aws route53 change-resource-record-sets \
        --hosted-zone-id "$HOSTED_ZONE_ID" \
        --change-batch "{
            \"Changes\": [{
                \"Action\": \"UPSERT\",
                \"ResourceRecordSet\": {
                    \"Name\": \"$DOMAIN_NAME\",
                    \"Type\": \"CNAME\",
                    \"TTL\": 60,
                    \"ResourceRecords\": [{
                        \"Value\": \"$dr_lb\"
                    }]
                }
            }]
        }"
    
    log "DNS updated to point to DR cluster: $dr_lb"
}

# Verify failover
verify_failover() {
    log "Verifying failover..."
    
    kubectl config use-context "$DR_CLUSTER"
    
    # Check pods
    local ready_pods=$(kubectl get pods -n production --field-selector=status.phase=Running --no-headers | wc -l)
    log "Running pods in production: $ready_pods"
    
    # Check services
    kubectl get svc -n production
    
    # Test endpoints
    local endpoint="https://$DOMAIN_NAME/health"
    local max_retries=10
    local retry=0
    
    while [[ $retry -lt $max_retries ]]; do
        if curl -sf "$endpoint" &>/dev/null; then
            log "Endpoint $endpoint is responding"
            break
        fi
        log "Waiting for endpoint to respond... (attempt $((retry+1))/$max_retries)"
        sleep 30
        ((retry++))
    done
    
    if [[ $retry -eq $max_retries ]]; then
        log "WARNING: Endpoint did not respond after $max_retries attempts"
    fi
}

# Generate failover report
generate_report() {
    local start_time="$1"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "=== DR Failover Report ==="
    log "Start Time: $(date -d @$start_time '+%Y-%m-%d %H:%M:%S')"
    log "End Time: $(date -d @$end_time '+%Y-%m-%d %H:%M:%S')"
    log "Duration: $duration seconds"
    log "Primary Region: $PRIMARY_REGION"
    log "DR Region: $DR_REGION"
    log "========================="
    
    send_notification "DR Failover Complete" \
        "Failover to $DR_REGION completed in $duration seconds" \
        "warning"
}

# Main failover process
main() {
    local start_time=$(date +%s)
    
    log "=== Starting DR Failover Process ==="
    send_notification "DR Failover Initiated" \
        "Starting failover from $PRIMARY_REGION to $DR_REGION" \
        "critical"
    
    # Pre-flight checks
    if check_primary_health; then
        log "WARNING: Primary cluster appears healthy. Are you sure you want to failover?"
        read -p "Continue? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log "Failover cancelled"
            exit 0
        fi
    fi
    
    # Verify DR readiness
    if ! check_dr_readiness; then
        log "ERROR: DR cluster is not ready"
        exit 1
    fi
    
    # Execute failover steps
    restore_workloads
    scale_dr_workloads
    promote_database
    update_dns
    verify_failover
    
    generate_report "$start_time"
    
    log "=== DR Failover Completed ==="
}

# Parse arguments
case "${1:-failover}" in
    failover)
        main
        ;;
    check-primary)
        check_primary_health
        ;;
    check-dr)
        check_dr_readiness
        ;;
    dns-only)
        update_dns
        ;;
    *)
        echo "Usage: $0 {failover|check-primary|check-dr|dns-only}"
        exit 1
        ;;
esac
```

---

## 集群联邦 (Federation)

### Karmada 多集群架构

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                          Karmada Multi-Cluster Federation                               │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│  ┌───────────────────────────────────────────────────────────────────────────────────┐ │
│  │                         Karmada Control Plane                                      │ │
│  │                                                                                    │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐ │ │
│  │  │                        karmada-apiserver                                     │ │ │
│  │  │                              │                                               │ │ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │ │ │
│  │  │  │ karmada-    │  │ karmada-    │  │ karmada-    │  │ karmada-    │        │ │ │
│  │  │  │ controller- │  │ scheduler   │  │ webhook     │  │ aggregated- │        │ │ │
│  │  │  │ manager     │  │             │  │             │  │ apiserver   │        │ │ │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │ │ │
│  │  └─────────────────────────────────────────────────────────────────────────────┘ │ │
│  │                                    │                                              │ │
│  │                    ┌───────────────┼───────────────┐                             │ │
│  │                    │               │               │                             │ │
│  │                    ▼               ▼               ▼                             │ │
│  │  ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐       │ │
│  │  │  PropagationPolicy  │ │  OverridePolicy     │ │  ResourceBinding    │       │ │
│  │  │                     │ │                     │ │                     │       │ │
│  │  │  • Cluster selector │ │  • Cluster-specific │ │  • Binding status   │       │ │
│  │  │  • Replica strategy │ │    overrides        │ │  • Work objects     │       │ │
│  │  │  • Spread by region │ │  • Config patches   │ │                     │       │ │
│  │  └─────────────────────┘ └─────────────────────┘ └─────────────────────┘       │ │
│  └───────────────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                                    │
│              ┌─────────────────────┼─────────────────────┐                             │
│              │                     │                     │                             │
│              ▼                     ▼                     ▼                             │
│  ┌───────────────────────┐ ┌───────────────────────┐ ┌───────────────────────┐       │
│  │   Member Cluster 1    │ │   Member Cluster 2    │ │   Member Cluster 3    │       │
│  │   (us-west-2)         │ │   (us-east-1)         │ │   (eu-west-1)         │       │
│  │                       │ │                       │ │                       │       │
│  │  ┌─────────────────┐ │ │  ┌─────────────────┐ │ │  ┌─────────────────┐ │       │
│  │  │ karmada-agent   │ │ │  │ karmada-agent   │ │ │  │ karmada-agent   │ │       │
│  │  │                 │ │ │  │                 │ │ │  │                 │ │       │
│  │  │ • Sync resources│ │ │  │ • Sync resources│ │ │  │ • Sync resources│ │       │
│  │  │ • Report status │ │ │  │ • Report status │ │ │  │ • Report status │ │       │
│  │  └─────────────────┘ │ │  └─────────────────┘ │ │  └─────────────────┘ │       │
│  │                       │ │                       │ │                       │       │
│  │  ┌─────────────────┐ │ │  ┌─────────────────┐ │ │  ┌─────────────────┐ │       │
│  │  │ Workloads       │ │ │  │ Workloads       │ │ │  │ Workloads       │ │       │
│  │  │ • Deployments   │ │ │  │ • Deployments   │ │ │  │ • Deployments   │ │       │
│  │  │ • Services      │ │ │  │ • Services      │ │ │  │ • Services      │ │       │
│  │  │ • ConfigMaps    │ │ │  │ • ConfigMaps    │ │ │  │ • ConfigMaps    │ │       │
│  │  └─────────────────┘ │ │  └─────────────────┘ │ │  └─────────────────┘ │       │
│  └───────────────────────┘ └───────────────────────┘ └───────────────────────────┘       │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### Karmada 配置示例

```yaml
# karmada-propagation.yaml
---
# PropagationPolicy for cross-cluster deployment
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
  name: web-app-propagation
  namespace: production
spec:
  resourceSelectors:
    - apiVersion: apps/v1
      kind: Deployment
      name: web-app
    - apiVersion: v1
      kind: Service
      name: web-app
    - apiVersion: v1
      kind: ConfigMap
      name: web-app-config
  placement:
    clusterAffinity:
      clusterNames:
        - cluster-us-west
        - cluster-us-east
        - cluster-eu-west
    replicaScheduling:
      replicaDivisionPreference: Weighted
      replicaSchedulingType: Divided
      weightPreference:
        staticWeightList:
          - targetCluster:
              clusterNames:
                - cluster-us-west
            weight: 2
          - targetCluster:
              clusterNames:
                - cluster-us-east
            weight: 2
          - targetCluster:
              clusterNames:
                - cluster-eu-west
            weight: 1
  # Failover configuration
  failover:
    application:
      decisionConditions:
        tolerationSeconds: 300
      purgeMode: Graciously
      gracePeriodSeconds: 600
---
# OverridePolicy for cluster-specific configuration
apiVersion: policy.karmada.io/v1alpha1
kind: OverridePolicy
metadata:
  name: web-app-override
  namespace: production
spec:
  resourceSelectors:
    - apiVersion: apps/v1
      kind: Deployment
      name: web-app
  overrideRules:
    - targetCluster:
        clusterNames:
          - cluster-us-west
      overriders:
        plaintext:
          - path: /spec/replicas
            operator: replace
            value: 5
          - path: /spec/template/spec/containers/0/env/-
            operator: add
            value:
              name: REGION
              value: us-west-2
    - targetCluster:
        clusterNames:
          - cluster-us-east
      overriders:
        plaintext:
          - path: /spec/replicas
            operator: replace
            value: 5
          - path: /spec/template/spec/containers/0/env/-
            operator: add
            value:
              name: REGION
              value: us-east-1
    - targetCluster:
        clusterNames:
          - cluster-eu-west
      overriders:
        plaintext:
          - path: /spec/replicas
            operator: replace
            value: 3
          - path: /spec/template/spec/containers/0/env/-
            operator: add
            value:
              name: REGION
              value: eu-west-1
---
# ClusterPropagationPolicy for cluster-scoped resources
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
        - cluster-us-west
        - cluster-us-east
        - cluster-eu-west
```

---

## DR 演练

### DR 演练检查清单

```yaml
# dr-drill-checklist.yaml
# DR Drill Runbook and Checklist
---
dr_drill:
  name: "Quarterly DR Drill"
  frequency: "Quarterly"
  duration: "4 hours"
  
  preparation:
    - task: "Notify all stakeholders"
      owner: "DR Lead"
      time: "T-7 days"
    
    - task: "Review and update runbooks"
      owner: "Platform Team"
      time: "T-5 days"
    
    - task: "Verify backup integrity"
      owner: "Backup Admin"
      time: "T-3 days"
    
    - task: "Check DR cluster capacity"
      owner: "Infrastructure Team"
      time: "T-2 days"
    
    - task: "Prepare monitoring dashboards"
      owner: "SRE Team"
      time: "T-1 day"
  
  execution:
    phase_1_preparation:
      duration: "30 minutes"
      tasks:
        - "Verify DR cluster health"
        - "Check latest backup availability"
        - "Confirm database replica sync status"
        - "Set up communication channels"
    
    phase_2_failover:
      duration: "60 minutes"
      tasks:
        - "Execute Velero restore"
        - "Scale workloads in DR"
        - "Promote database replica"
        - "Update DNS/traffic routing"
    
    phase_3_validation:
      duration: "60 minutes"
      tasks:
        - "Verify all services are running"
        - "Execute smoke tests"
        - "Validate data integrity"
        - "Check external integrations"
    
    phase_4_failback:
      duration: "60 minutes"
      tasks:
        - "Prepare primary for failback"
        - "Sync data back to primary"
        - "Switch traffic to primary"
        - "Verify primary functionality"
    
    phase_5_cleanup:
      duration: "30 minutes"
      tasks:
        - "Scale down DR workloads"
        - "Reset database replication"
        - "Update documentation"
        - "Collect metrics and feedback"
  
  success_criteria:
    - metric: "RTO"
      target: "< 1 hour"
    - metric: "RPO"
      target: "< 15 minutes"
    - metric: "Service availability"
      target: "> 99%"
    - metric: "Data integrity"
      target: "100%"
  
  post_drill:
    - "Document findings and issues"
    - "Update runbooks with learnings"
    - "Create action items for improvements"
    - "Schedule follow-up review"
```

### DR 演练自动化脚本

```bash
#!/bin/bash
# dr-drill.sh - Automated DR drill script

set -euo pipefail

DRILL_TYPE="${1:-full}"
DRILL_ID="drill-$(date +%Y%m%d%H%M%S)"
LOG_FILE="/var/log/dr-drill-${DRILL_ID}.log"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LOG_FILE"
}

# Phase 1: Preparation
phase_preparation() {
    log "=== Phase 1: Preparation ==="
    
    # Check DR cluster health
    log "Checking DR cluster health..."
    kubectl config use-context dr-cluster
    kubectl get nodes
    kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded | head -20
    
    # Check Velero status
    log "Checking Velero status..."
    velero backup-location get
    
    # Find latest backup
    log "Finding latest backup..."
    velero backup get --sort-by=.metadata.creationTimestamp | tail -5
    
    # Check database replica lag
    log "Checking database replica lag..."
    # aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,ReadReplicaDBInstanceIdentifiers]'
    
    log "Phase 1 completed"
}

# Phase 2: Failover
phase_failover() {
    log "=== Phase 2: Failover ==="
    local start_time=$(date +%s)
    
    # Restore from backup
    log "Starting Velero restore..."
    local backup_name=$(velero backup get -o json | jq -r '.items | sort_by(.status.completionTimestamp) | reverse | .[0].metadata.name')
    
    velero restore create "${DRILL_ID}-restore" \
        --from-backup "$backup_name" \
        --include-namespaces production-drill \
        --namespace-mappings production:production-drill \
        --wait
    
    # Scale workloads
    log "Scaling workloads..."
    kubectl scale deployment --all -n production-drill --replicas=2
    
    # Wait for pods
    log "Waiting for pods to be ready..."
    kubectl wait --for=condition=available deployment --all -n production-drill --timeout=300s || true
    
    local end_time=$(date +%s)
    local failover_time=$((end_time - start_time))
    
    log "Failover completed in $failover_time seconds (RTO: $failover_time seconds)"
}

# Phase 3: Validation
phase_validation() {
    log "=== Phase 3: Validation ==="
    
    # Check pod status
    log "Checking pod status..."
    kubectl get pods -n production-drill
    
    # Run smoke tests
    log "Running smoke tests..."
    local service_ip=$(kubectl get svc web-app -n production-drill -o jsonpath='{.spec.clusterIP}')
    
    if curl -sf "http://${service_ip}:8080/health" &>/dev/null; then
        log "Health check passed"
    else
        log "WARNING: Health check failed"
    fi
    
    # Validate data
    log "Validating data integrity..."
    # kubectl exec -it mysql-0 -n production-drill -- mysql -e "SELECT COUNT(*) FROM important_table;"
    
    log "Validation completed"
}

# Phase 4: Cleanup
phase_cleanup() {
    log "=== Phase 4: Cleanup ==="
    
    # Delete drill resources
    log "Cleaning up drill resources..."
    kubectl delete namespace production-drill --wait=false
    
    # Delete restore
    velero restore delete "${DRILL_ID}-restore" --confirm
    
    log "Cleanup completed"
}

# Generate report
generate_report() {
    log "=== DR Drill Report ==="
    log "Drill ID: $DRILL_ID"
    log "Drill Type: $DRILL_TYPE"
    log "Log File: $LOG_FILE"
    log ""
    
    # Calculate metrics
    local rto=$(grep "RTO:" "$LOG_FILE" | tail -1 || echo "N/A")
    log "Metrics:"
    log "  $rto"
    log ""
    
    # Issues found
    local issues=$(grep -c "WARNING\|ERROR" "$LOG_FILE" || echo "0")
    log "Issues found: $issues"
    
    # Send notification
    if [[ -n "${SLACK_WEBHOOK:-}" ]]; then
        curl -s -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"text\": \"DR Drill $DRILL_ID completed. Issues: $issues. Check logs for details.\"}"
    fi
}

# Main
main() {
    log "Starting DR Drill: $DRILL_ID (Type: $DRILL_TYPE)"
    
    case "$DRILL_TYPE" in
        full)
            phase_preparation
            phase_failover
            phase_validation
            phase_cleanup
            ;;
        failover-only)
            phase_preparation
            phase_failover
            phase_validation
            ;;
        validation-only)
            phase_validation
            ;;
        cleanup)
            phase_cleanup
            ;;
        *)
            echo "Usage: $0 {full|failover-only|validation-only|cleanup}"
            exit 1
            ;;
    esac
    
    generate_report
    
    log "DR Drill completed"
}

main
```

---

## 监控与告警

### DR 监控 Prometheus 规则

```yaml
# dr-monitoring-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: dr-monitoring
  namespace: monitoring
spec:
  groups:
    - name: dr.alerts
      rules:
        # Backup age alerts
        - alert: DRBackupTooOld
          expr: |
            (time() - velero_backup_last_successful_timestamp) > 21600
          for: 30m
          labels:
            severity: warning
          annotations:
            summary: "DR backup is too old"
            description: "Last successful backup was {{ $value | humanizeDuration }} ago"
        
        - alert: DRBackupCriticallyOld
          expr: |
            (time() - velero_backup_last_successful_timestamp) > 43200
          for: 30m
          labels:
            severity: critical
          annotations:
            summary: "DR backup is critically old"
            description: "Last successful backup was {{ $value | humanizeDuration }} ago. RPO may be violated!"
        
        # Database replication lag
        - alert: DatabaseReplicationLagHigh
          expr: |
            mysql_slave_status_seconds_behind_master > 300
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Database replication lag is high"
            description: "Replication lag is {{ $value }} seconds"
        
        - alert: DatabaseReplicationLagCritical
          expr: |
            mysql_slave_status_seconds_behind_master > 900
          for: 10m
          labels:
            severity: critical
          annotations:
            summary: "Database replication lag is critical"
            description: "Replication lag is {{ $value }} seconds. DR RPO at risk!"
        
        # DR cluster health
        - alert: DRClusterNotReady
          expr: |
            sum(kube_node_status_condition{condition="Ready",status="true",cluster="dr-cluster"}) < 3
          for: 10m
          labels:
            severity: critical
          annotations:
            summary: "DR cluster has insufficient ready nodes"
            description: "Only {{ $value }} nodes are ready in DR cluster"
        
        # Cross-region S3 replication
        - alert: S3ReplicationFailed
          expr: |
            aws_s3_replication_failed_count > 0
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "S3 cross-region replication failing"
            description: "{{ $value }} objects failed to replicate"
```

---

## 最佳实践清单

### DR 策略检查清单

| 检查项 | 频率 | 负责人 | 状态 |
|-------|------|-------|------|
| **备份验证** | 每日 | 自动化 | ☐ |
| **复制延迟检查** | 实时 | 监控 | ☐ |
| **DR 集群健康检查** | 每小时 | 自动化 | ☐ |
| **故障切换演练** | 每季度 | DR 团队 | ☐ |
| **Runbook 更新** | 每月 | 平台团队 | ☐ |
| **RTO/RPO 验证** | 每季度 | DR 团队 | ☐ |
| **跨区域网络测试** | 每月 | 网络团队 | ☐ |
| **数据完整性验证** | 每周 | DBA 团队 | ☐ |
| **DNS 故障切换测试** | 每月 | 运维团队 | ☐ |
| **成本审计** | 每月 | FinOps | ☐ |

### RPO/RTO 规划矩阵

| 业务层级 | RPO | RTO | DR 策略 | 预算 |
|---------|-----|-----|--------|------|
| **Tier 0** | < 1分钟 | < 5分钟 | Active/Active | $$$$$ |
| **Tier 1** | < 15分钟 | < 30分钟 | Warm Standby | $$$$ |
| **Tier 2** | < 1小时 | < 4小时 | Pilot Light | $$$ |
| **Tier 3** | < 4小时 | < 24小时 | Backup/Restore | $$ |
| **Tier 4** | < 24小时 | < 72小时 | Cold Backup | $ |

---

## 版本变更记录

| K8s版本 | 变更内容 | 影响 |
|--------|---------|------|
| v1.32 | TopologySpreadConstraints 增强 | 更精细的跨 AZ 调度 |
| v1.31 | PDB 改进 | 更好的可用性保障 |
| v1.30 | 节点优雅关闭增强 | 更平滑的故障切换 |
| v1.29 | 调度器优化 | 更快的故障恢复 |
| v1.28 | Karmada 1.8 兼容 | 改进的多集群支持 |
| v1.27 | 数据移动器 GA | 跨集群数据迁移 |
| v1.26 | VolumeSnapshot 增强 | 更可靠的卷快照 |
| v1.25 | CSI 快照 v1 | 稳定的快照功能 |

---

> **参考文档**:  
> - [Kubernetes 高可用](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/)
> - [Velero DR 文档](https://velero.io/docs/main/disaster-case/)
> - [Karmada 文档](https://karmada.io/docs/)
> - [AWS DR 白皮书](https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/)

---

*Kusheet - Kubernetes 知识速查表项目*
