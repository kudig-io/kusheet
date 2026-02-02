# Kubernetes 工作负载(Workload)生产环境运维培训

> **适用版本**: Kubernetes v1.26-v1.32  
> **文档类型**: PPT演示文稿 | **目标受众**: 运维工程师、SRE、架构师  
> **内容定位**: 理论深入 + 源码级分析 + 生产实战案例

---

## 目录

1. [工作负载基础架构](#1-工作负载基础架构)
2. [核心控制器深度解析](#2-核心控制器深度解析)
3. [Pod调度策略与优化](#3-pod调度策略与优化)
4. [生产环境配置实践](#4-生产环境配置实践)
5. [自动扩缩容体系](#5-自动扩缩容体系)
6. [监控与告警](#6-监控与告警)
7. [故障排查手册](#7-故障排查手册)
8. [安全加固配置](#8-安全加固配置)
9. [实战案例演练](#9-实战案例演练)
10. [总结与Q&A](#10-总结与qa)

---

## 1. 工作负载基础架构

### 1.1 工作负载核心概念

**定义**: 工作负载(Workload)是Kubernetes中运行应用程序的抽象层，通过控制器模式管理Pod的生命周期。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Kubernetes 工作负载架构全景                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                      Control Plane                               │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │   │
│  │  │ API Server  │  │ Scheduler   │  │ Controller Manager      │  │   │
│  │  │             │  │             │  │ ├─ DeploymentController │  │   │
│  │  │ 资源定义存储 │  │ Pod调度决策  │  │ ├─ ReplicaSetController│  │   │
│  │  │             │  │             │  │ ├─ StatefulSetController│  │   │
│  │  │             │  │             │  │ ├─ DaemonSetController  │  │   │
│  │  │             │  │             │  │ └─ JobController        │  │   │
│  │  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘  │   │
│  └─────────┼────────────────┼─────────────────────┼────────────────┘   │
│            │                │                     │                     │
│            ▼                ▼                     ▼                     │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                       Worker Nodes                               │   │
│  │  ┌───────────────────────────────────────────────────────────┐  │   │
│  │  │ kubelet                                                    │  │   │
│  │  │ ├─ Pod生命周期管理                                          │  │   │
│  │  │ ├─ 容器运行时接口(CRI)                                      │  │   │
│  │  │ └─ 资源监控上报                                             │  │   │
│  │  └───────────────────────────────────────────────────────────┘  │   │
│  │                              │                                   │   │
│  │                              ▼                                   │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │   │
│  │  │   Pod-1     │  │   Pod-2     │  │   Pod-N     │             │   │
│  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │             │   │
│  │  │ │Container│ │  │ │Container│ │  │ │Container│ │             │   │
│  │  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │             │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘             │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 控制器模式核心原理

**Reconciliation Loop (调和循环)** - Kubernetes控制器的核心设计模式：

```
┌─────────────────────────────────────────────────────────────────┐
│                     控制器调和循环                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    观察     ┌─────────────┐                   │
│  │  期望状态   │ ◄────────── │  API Server │                   │
│  │  (Spec)    │             │   (etcd)    │                   │
│  └──────┬──────┘             └──────┬──────┘                   │
│         │                          │                           │
│         │ 比较                     │ 获取                       │
│         │                          │                           │
│         ▼                          ▼                           │
│  ┌─────────────────────────────────────────┐                   │
│  │              Controller                  │                   │
│  │  ┌───────────────────────────────────┐  │                   │
│  │  │      if 期望状态 != 实际状态       │  │                   │
│  │  │          执行调和操作              │  │                   │
│  │  │      else                          │  │                   │
│  │  │          等待下一次事件            │  │                   │
│  │  └───────────────────────────────────┘  │                   │
│  └──────────────────┬──────────────────────┘                   │
│                     │                                           │
│                     │ 执行                                       │
│                     ▼                                           │
│  ┌─────────────┐          ┌─────────────┐                      │
│  │  实际状态   │ ◄─────── │  集群资源   │                      │
│  │  (Status)  │   反馈    │  (Pods等)   │                      │
│  └─────────────┘          └─────────────┘                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**源码级理解** - Controller核心逻辑 (k8s.io/controller-runtime):
```go
// 控制器核心接口
type Reconciler interface {
    // Reconcile 执行调和逻辑
    // 返回 Result{} 表示成功
    // 返回 Result{Requeue: true} 表示需要重新入队
    // 返回 error 表示失败，会自动重试
    Reconcile(ctx context.Context, req Request) (Result, error)
}

// 典型的Reconcile实现模式
func (r *DeploymentReconciler) Reconcile(ctx context.Context, req Request) (Result, error) {
    // 1. 获取资源
    deployment := &appsv1.Deployment{}
    if err := r.Get(ctx, req.NamespacedName, deployment); err != nil {
        return Result{}, client.IgnoreNotFound(err)
    }
    
    // 2. 检查是否被删除
    if !deployment.DeletionTimestamp.IsZero() {
        return r.handleDeletion(ctx, deployment)
    }
    
    // 3. 调和子资源 (ReplicaSet)
    if err := r.reconcileReplicaSets(ctx, deployment); err != nil {
        return Result{}, err
    }
    
    // 4. 更新状态
    return r.updateStatus(ctx, deployment)
}
```

### 1.3 工作负载类型对比矩阵

| 控制器 | 核心用途 | Pod标识 | 扩缩容 | 更新策略 | 有序性 | 典型场景 |
|--------|----------|---------|--------|----------|--------|----------|
| **Deployment** | 无状态应用 | 随机Hash | HPA/VPA/手动 | RollingUpdate/Recreate | 无 | Web服务、API网关 |
| **StatefulSet** | 有状态应用 | 固定序号(0,1,2...) | HPA/手动 | RollingUpdate/OnDelete | 有序 | 数据库、消息队列 |
| **DaemonSet** | 节点守护 | 节点绑定 | 自动跟随节点 | RollingUpdate/OnDelete | 无 | 日志采集、监控Agent |
| **Job** | 一次性任务 | 随机Hash | 并行度控制 | N/A | 无 | 批处理、数据迁移 |
| **CronJob** | 定时任务 | 随机Hash | 并发策略 | N/A | 无 | 定时备份、报表生成 |
| **ReplicaSet** | 副本控制 | 随机Hash | 手动 | N/A | 无 | 被Deployment管理 |

### 1.4 版本演进与特性支持

| Kubernetes版本 | 新增特性 | 重要变更 |
|---------------|----------|----------|
| **v1.26** | Pod调度就绪门控GA | JobPodFailurePolicy GA |
| **v1.27** | StatefulSet启动探针 | Pod调度优化 |
| **v1.28** | Sidecar容器KEP | Job索引完成GA |
| **v1.29** | PodReadyToStartContainers | 调度器性能提升 |
| **v1.30** | Job成功/失败策略增强 | StatefulSet持久化卷保留策略 |
| **v1.31** | 动态资源分配增强 | Pod生命周期优化 |
| **v1.32** | Sidecar容器GA | 控制器性能优化 |

---

## 2. 核心控制器深度解析

### 2.1 Deployment 深度解析

#### 2.1.1 Deployment 工作流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Deployment 完整工作流程                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  用户创建/更新 Deployment                                                │
│         │                                                               │
│         ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ Deployment Controller                                            │   │
│  │ 1. 计算期望的ReplicaSet配置                                       │   │
│  │ 2. 创建新ReplicaSet或扩缩现有ReplicaSet                           │   │
│  │ 3. 根据更新策略执行滚动更新                                        │   │
│  └──────────────────────────┬──────────────────────────────────────┘   │
│                             │                                           │
│                             ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ ReplicaSet Controller                                            │   │
│  │ 1. 计算当前Pod数量与期望副本数差异                                 │   │
│  │ 2. 创建或删除Pod以达到期望状态                                     │   │
│  └──────────────────────────┬──────────────────────────────────────┘   │
│                             │                                           │
│                             ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ Scheduler                                                        │   │
│  │ 1. 为新创建的Pod选择合适的节点                                     │   │
│  │ 2. 考虑资源、亲和性、污点等约束                                    │   │
│  └──────────────────────────┬──────────────────────────────────────┘   │
│                             │                                           │
│                             ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ kubelet                                                          │   │
│  │ 1. 拉取镜像、创建容器                                              │   │
│  │ 2. 执行探针检查                                                    │   │
│  │ 3. 上报Pod状态                                                     │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 2.1.2 生产级 Deployment 配置

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: production-api
  namespace: production
  labels:
    app: api-server
    version: v2.1.0
    environment: production
    team: platform
  annotations:
    kubernetes.io/change-cause: "升级到v2.1.0，修复内存泄漏问题"
spec:
  replicas: 6
  revisionHistoryLimit: 10    # 保留历史版本数，用于回滚
  progressDeadlineSeconds: 600 # 更新超时时间
  minReadySeconds: 30          # Pod就绪后等待时间
  
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%           # 最大超出副本数
      maxUnavailable: 0       # 零停机更新
  
  selector:
    matchLabels:
      app: api-server
  
  template:
    metadata:
      labels:
        app: api-server
        version: v2.1.0
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      # 优雅终止时间
      terminationGracePeriodSeconds: 60
      
      # 服务账号
      serviceAccountName: api-server-sa
      
      # 安全上下文
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      
      # 拓扑分布约束 - 跨可用区分布
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: api-server
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: api-server
      
      # 反亲和性 - 避免同节点部署
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: api-server
              topologyKey: kubernetes.io/hostname
      
      containers:
      - name: api-server
        image: registry.example.com/api-server:v2.1.0
        imagePullPolicy: IfNotPresent
        
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        - name: metrics
          containerPort: 9090
          protocol: TCP
        
        # 资源配置
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "2000m"
            memory: "2Gi"
        
        # 环境变量
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: GOMAXPROCS
          valueFrom:
            resourceFieldRef:
              resource: limits.cpu
        
        # 配置文件挂载
        envFrom:
        - configMapRef:
            name: api-server-config
        - secretRef:
            name: api-server-secrets
        
        # 启动探针 - 应用启动检查
        startupProbe:
          httpGet:
            path: /healthz/startup
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 30    # 最多等待150秒启动
        
        # 就绪探针 - 流量接收检查
        readinessProbe:
          httpGet:
            path: /healthz/ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3
        
        # 存活探针 - 应用健康检查
        livenessProbe:
          httpGet:
            path: /healthz/live
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 15
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 3
        
        # 生命周期钩子
        lifecycle:
          postStart:
            exec:
              command:
              - /bin/sh
              - -c
              - echo "Pod started at $(date)" >> /var/log/lifecycle.log
          preStop:
            exec:
              command:
              - /bin/sh
              - -c
              - |
                echo "Graceful shutdown initiated"
                # 等待正在处理的请求完成
                sleep 15
                # 发送优雅停止信号
                kill -SIGTERM 1
                sleep 10
        
        # 安全上下文
        securityContext:
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
        
        # 卷挂载
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /var/cache
        - name: logs
          mountPath: /var/log
      
      # 卷定义
      volumes:
      - name: tmp
        emptyDir:
          sizeLimit: 100Mi
      - name: cache
        emptyDir:
          sizeLimit: 500Mi
      - name: logs
        emptyDir:
          sizeLimit: 1Gi
      
      # 镜像拉取凭证
      imagePullSecrets:
      - name: registry-credentials
```

### 2.2 StatefulSet 深度解析

#### 2.2.1 StatefulSet 核心特性

**有状态应用的三大保证**:
1. **稳定的网络标识**: Pod名称固定为 `{statefulset-name}-{ordinal}`
2. **稳定的存储**: 每个Pod绑定独立的PVC，Pod重建后仍使用同一PVC
3. **有序部署和扩缩**: 按序号顺序创建和删除Pod

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    StatefulSet 工作原理                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  StatefulSet: mysql-cluster                                             │
│  replicas: 3                                                            │
│                                                                         │
│  创建顺序: mysql-cluster-0 → mysql-cluster-1 → mysql-cluster-2         │
│  删除顺序: mysql-cluster-2 → mysql-cluster-1 → mysql-cluster-0         │
│                                                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │ mysql-cluster-0 │  │ mysql-cluster-1 │  │ mysql-cluster-2 │         │
│  │   (Primary)     │  │   (Replica)     │  │   (Replica)     │         │
│  │                 │  │                 │  │                 │         │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌───────────┐  │         │
│  │  │ Container │  │  │  │ Container │  │  │  │ Container │  │         │
│  │  └───────────┘  │  │  └───────────┘  │  │  └───────────┘  │         │
│  │       │         │  │       │         │  │       │         │         │
│  │       ▼         │  │       ▼         │  │       ▼         │         │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌───────────┐  │         │
│  │  │data-mysql │  │  │  │data-mysql │  │  │  │data-mysql │  │         │
│  │  │-cluster-0 │  │  │  │-cluster-1 │  │  │  │-cluster-2 │  │         │
│  │  │  (PVC)    │  │  │  │  (PVC)    │  │  │  │  (PVC)    │  │         │
│  │  └───────────┘  │  │  └───────────┘  │  │  └───────────┘  │         │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘         │
│           │                   │                   │                     │
│           ▼                   ▼                   ▼                     │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Headless Service                              │   │
│  │                    mysql-cluster                                 │   │
│  │                    ClusterIP: None                               │   │
│  │                                                                  │   │
│  │  DNS Records:                                                    │   │
│  │  mysql-cluster-0.mysql-cluster.namespace.svc.cluster.local      │   │
│  │  mysql-cluster-1.mysql-cluster.namespace.svc.cluster.local      │   │
│  │  mysql-cluster-2.mysql-cluster.namespace.svc.cluster.local      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 2.2.2 生产级 StatefulSet 配置

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-cluster
  namespace: database
  labels:
    app: mysql
    cluster: production
spec:
  serviceName: mysql-headless
  replicas: 3
  
  # Pod管理策略
  podManagementPolicy: OrderedReady  # 有序创建 (默认)
  # podManagementPolicy: Parallel    # 并行创建 (提升扩容速度)
  
  # 更新策略
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0           # 金丝雀发布：设置>0可保留部分Pod不更新
      maxUnavailable: 1      # v1.24+ 支持
  
  # PVC保留策略 (v1.27+)
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Retain      # StatefulSet删除时保留PVC
    whenScaled: Retain       # 缩容时保留PVC
  
  # 最小就绪时间
  minReadySeconds: 30
  
  selector:
    matchLabels:
      app: mysql
  
  template:
    metadata:
      labels:
        app: mysql
        cluster: production
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9104"
    spec:
      terminationGracePeriodSeconds: 120
      
      # 初始化容器
      initContainers:
      - name: init-mysql
        image: mysql:8.0
        command:
        - bash
        - -c
        - |
          set -ex
          # 根据Pod序号生成server-id
          [[ $(hostname) =~ -([0-9]+)$ ]] || exit 1
          ordinal=${BASH_REMATCH[1]}
          echo "[mysqld]" > /mnt/conf.d/server-id.cnf
          echo "server-id=$((100 + ordinal))" >> /mnt/conf.d/server-id.cnf
          
          # 第一个Pod作为Primary
          if [[ $ordinal -eq 0 ]]; then
            cp /mnt/config-map/primary.cnf /mnt/conf.d/
          else
            cp /mnt/config-map/replica.cnf /mnt/conf.d/
          fi
        volumeMounts:
        - name: conf
          mountPath: /mnt/conf.d
        - name: config-map
          mountPath: /mnt/config-map
      
      - name: clone-mysql
        image: gcr.io/google-samples/xtrabackup:1.0
        command:
        - bash
        - -c
        - |
          set -ex
          [[ -d /var/lib/mysql/mysql ]] && exit 0
          [[ $(hostname) =~ -([0-9]+)$ ]] || exit 1
          ordinal=${BASH_REMATCH[1]}
          [[ $ordinal -eq 0 ]] && exit 0
          
          # 从前一个Pod克隆数据
          ncat --recv-only mysql-cluster-$((ordinal-1)).mysql-headless 3307 | \
            xbstream -x -C /var/lib/mysql
          xtrabackup --prepare --target-dir=/var/lib/mysql
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
      
      containers:
      - name: mysql
        image: mysql:8.0
        
        ports:
        - name: mysql
          containerPort: 3306
        - name: xtrabackup
          containerPort: 3307
        
        resources:
          requests:
            cpu: "1"
            memory: "2Gi"
          limits:
            cpu: "4"
            memory: "8Gi"
        
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secrets
              key: root-password
        - name: MYSQL_DATABASE
          value: "production"
        
        livenessProbe:
          exec:
            command:
            - mysqladmin
            - ping
            - -u
            - root
            - -p${MYSQL_ROOT_PASSWORD}
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        
        readinessProbe:
          exec:
            command:
            - mysql
            - -u
            - root
            - -p${MYSQL_ROOT_PASSWORD}
            - -e
            - "SELECT 1"
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
        
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
      
      - name: xtrabackup
        image: gcr.io/google-samples/xtrabackup:1.0
        ports:
        - name: xtrabackup
          containerPort: 3307
        command:
        - bash
        - -c
        - |
          set -ex
          cd /var/lib/mysql
          
          if [[ -f xtrabackup_slave_info && "x$(<xtrabackup_slave_info)" != "x" ]]; then
            cat xtrabackup_slave_info | sed -E 's/;$//g' > change_master_to.sql.in
            rm -f xtrabackup_slave_info xtrabackup_binlog_info
          elif [[ -f xtrabackup_binlog_info ]]; then
            [[ $(cat xtrabackup_binlog_info) =~ ^(.*?)[[:space:]]+(.*?)$ ]] || exit 1
            rm -f xtrabackup_binlog_info xtrabackup_slave_info
            echo "CHANGE MASTER TO MASTER_LOG_FILE='${BASH_REMATCH[1]}',\
                  MASTER_LOG_POS=${BASH_REMATCH[2]}" > change_master_to.sql.in
          fi
          
          if [[ -f change_master_to.sql.in ]]; then
            echo "Waiting for mysqld to be ready"
            until mysql -h 127.0.0.1 -e "SELECT 1"; do sleep 1; done
            
            echo "Initializing replication from clone position"
            mysql -h 127.0.0.1 \
                  -e "$(<change_master_to.sql.in), \
                      MASTER_HOST='mysql-cluster-0.mysql-headless', \
                      MASTER_USER='root', \
                      MASTER_PASSWORD='${MYSQL_ROOT_PASSWORD}', \
                      MASTER_CONNECT_RETRY=10; \
                    START SLAVE;" || exit 1
            mv change_master_to.sql.in change_master_to.sql.orig
          fi
          
          exec ncat --listen --keep-open --send-only --max-conns=1 3307 -c \
            "xtrabackup --backup --slave-info --stream=xbstream --host=127.0.0.1 --user=root --password=${MYSQL_ROOT_PASSWORD}"
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
      
      - name: metrics
        image: prom/mysqld-exporter:v0.14.0
        ports:
        - name: metrics
          containerPort: 9104
        env:
        - name: DATA_SOURCE_NAME
          value: "root:${MYSQL_ROOT_PASSWORD}@(localhost:3306)/"
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
      
      volumes:
      - name: conf
        emptyDir: {}
      - name: config-map
        configMap:
          name: mysql-config
  
  # 卷声明模板 - 为每个Pod创建独立PVC
  volumeClaimTemplates:
  - metadata:
      name: data
      labels:
        app: mysql
    spec:
      accessModes:
      - ReadWriteOnce
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 100Gi
---
# Headless Service
apiVersion: v1
kind: Service
metadata:
  name: mysql-headless
  namespace: database
  labels:
    app: mysql
spec:
  clusterIP: None
  selector:
    app: mysql
  ports:
  - name: mysql
    port: 3306
    targetPort: 3306
  - name: xtrabackup
    port: 3307
    targetPort: 3307
---
# 读写分离Service
apiVersion: v1
kind: Service
metadata:
  name: mysql-read
  namespace: database
  labels:
    app: mysql
    role: read
spec:
  selector:
    app: mysql
  ports:
  - name: mysql
    port: 3306
    targetPort: 3306
```

### 2.3 DaemonSet 深度解析

#### 2.3.1 DaemonSet 核心特性

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    DaemonSet 工作原理                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  DaemonSet: node-exporter                                               │
│  确保每个节点运行一个Pod                                                  │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                        Kubernetes Cluster                        │   │
│  │                                                                  │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐        │   │
│  │  │   Node-1      │  │   Node-2      │  │   Node-3      │        │   │
│  │  │   (Master)    │  │   (Worker)    │  │   (Worker)    │        │   │
│  │  │               │  │               │  │               │        │   │
│  │  │ ┌───────────┐ │  │ ┌───────────┐ │  │ ┌───────────┐ │        │   │
│  │  │ │node-export│ │  │ │node-export│ │  │ │node-export│ │        │   │
│  │  │ │er-xxxxx   │ │  │ │er-yyyyy   │ │  │ │er-zzzzz   │ │        │   │
│  │  │ └───────────┘ │  │ └───────────┘ │  │ └───────────┘ │        │   │
│  │  │               │  │               │  │               │        │   │
│  │  │ Toleration:   │  │               │  │               │        │   │
│  │  │ master taint  │  │               │  │               │        │   │
│  │  └───────────────┘  └───────────────┘  └───────────────┘        │   │
│  │                                                                  │   │
│  │  新节点加入 → 自动创建Pod                                          │   │
│  │  节点移除 → 自动删除Pod                                            │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 2.3.2 生产级 DaemonSet 配置

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
  labels:
    app: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1       # 滚动更新时最大不可用节点数
      maxSurge: 0             # DaemonSet不支持maxSurge
  
  minReadySeconds: 10
  revisionHistoryLimit: 10
  
  template:
    metadata:
      labels:
        app: node-exporter
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9100"
    spec:
      # 使用宿主机网络
      hostNetwork: true
      hostPID: true
      hostIPC: true
      
      # 优先级类 - 确保关键组件优先调度
      priorityClassName: system-node-critical
      
      # 服务账号
      serviceAccountName: node-exporter
      
      # 容忍所有污点 - 确保在所有节点运行
      tolerations:
      - operator: Exists
        effect: NoSchedule
      - operator: Exists
        effect: NoExecute
      - operator: Exists
        effect: PreferNoSchedule
      
      # 节点选择器 - 可选择性部署
      # nodeSelector:
      #   kubernetes.io/os: linux
      
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        fsGroup: 65534
      
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.7.0
        
        args:
        - --path.procfs=/host/proc
        - --path.sysfs=/host/sys
        - --path.rootfs=/host/root
        - --collector.filesystem.mount-points-exclude=^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/.+)($|/)
        - --collector.filesystem.fs-types-exclude=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs)$
        - --web.listen-address=:9100
        - --web.telemetry-path=/metrics
        
        ports:
        - name: metrics
          containerPort: 9100
          hostPort: 9100
          protocol: TCP
        
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
        
        securityContext:
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
            add:
            - SYS_TIME    # 需要读取系统时间
        
        livenessProbe:
          httpGet:
            path: /
            port: 9100
          initialDelaySeconds: 10
          periodSeconds: 15
          timeoutSeconds: 5
        
        readinessProbe:
          httpGet:
            path: /
            port: 9100
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 5
        
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: root
          mountPath: /host/root
          readOnly: true
          mountPropagation: HostToContainer
      
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: root
        hostPath:
          path: /
```

### 2.4 Job/CronJob 深度解析

#### 2.4.1 Job 完成策略与并行控制

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processing-job
  namespace: batch
spec:
  # 完成条件
  completions: 10            # 需要成功完成的Pod数
  parallelism: 3             # 并行运行的Pod数
  
  # 完成模式 (v1.24+)
  completionMode: Indexed    # NonIndexed(默认) | Indexed
  
  # 重试策略
  backoffLimit: 6            # 最大重试次数
  backoffLimitPerIndex: 1    # 每个索引的重试次数 (Indexed模式)
  
  # 超时配置
  activeDeadlineSeconds: 3600  # 任务超时时间
  
  # TTL自动清理 (v1.23+)
  ttlSecondsAfterFinished: 86400  # 完成后保留24小时
  
  # Pod失败策略 (v1.26+)
  podFailurePolicy:
    rules:
    - action: FailJob         # 匹配时直接失败Job
      onExitCodes:
        containerName: worker
        operator: In
        values: [1, 2, 3]     # 这些退出码表示不可恢复错误
    - action: Ignore          # 匹配时忽略此失败
      onPodConditions:
      - type: DisruptionTarget
    - action: Count           # 计入backoffLimit
      onExitCodes:
        operator: NotIn
        values: [0]
  
  # 挂起功能 (v1.24+)
  suspend: false
  
  template:
    metadata:
      labels:
        app: data-processor
    spec:
      restartPolicy: OnFailure  # Never | OnFailure
      
      containers:
      - name: worker
        image: data-processor:v1.0
        
        command:
        - /bin/sh
        - -c
        - |
          # 获取任务索引 (Indexed模式)
          echo "Processing batch index: $JOB_COMPLETION_INDEX"
          
          # 执行处理逻辑
          /app/process --batch-id=$JOB_COMPLETION_INDEX \
                       --total-batches=$JOB_COMPLETIONS
        
        env:
        - name: JOB_COMPLETION_INDEX
          valueFrom:
            fieldRef:
              fieldPath: metadata.annotations['batch.kubernetes.io/job-completion-index']
        - name: JOB_COMPLETIONS
          value: "10"
        
        resources:
          requests:
            cpu: "1"
            memory: "2Gi"
          limits:
            cpu: "2"
            memory: "4Gi"
        
        volumeMounts:
        - name: data
          mountPath: /data
      
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: batch-data-pvc
```

#### 2.4.2 CronJob 并发与历史控制

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-backup
  namespace: backup
spec:
  # Cron表达式
  schedule: "0 2 * * *"        # 每天凌晨2点
  # schedule: "*/5 * * * *"    # 每5分钟
  # schedule: "0 */6 * * *"    # 每6小时
  
  # 时区设置 (v1.27+)
  timeZone: "Asia/Shanghai"
  
  # 并发策略
  concurrencyPolicy: Forbid    # Allow | Forbid | Replace
  # Allow: 允许并发运行
  # Forbid: 跳过新任务如果上一个还在运行
  # Replace: 取消运行中的任务，启动新任务
  
  # 启动截止时间 - 错过调度后的最大启动延迟
  startingDeadlineSeconds: 300
  
  # 历史记录保留
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  
  # 挂起功能
  suspend: false
  
  jobTemplate:
    spec:
      backoffLimit: 3
      activeDeadlineSeconds: 7200
      ttlSecondsAfterFinished: 3600
      
      template:
        metadata:
          labels:
            app: backup-job
        spec:
          restartPolicy: OnFailure
          
          serviceAccountName: backup-sa
          
          containers:
          - name: backup
            image: backup-tool:v2.0
            
            command:
            - /bin/sh
            - -c
            - |
              set -e
              
              # 生成备份文件名
              BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
              BACKUP_FILE="backup-${BACKUP_DATE}.tar.gz"
              
              echo "Starting backup: ${BACKUP_FILE}"
              
              # 执行备份
              /app/backup --output=/backup/${BACKUP_FILE}
              
              # 上传到对象存储
              /app/upload --file=/backup/${BACKUP_FILE} \
                          --destination=s3://backups/daily/
              
              # 清理本地文件
              rm -f /backup/${BACKUP_FILE}
              
              echo "Backup completed successfully"
            
            env:
            - name: DB_HOST
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: host
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: password
            - name: S3_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: s3-credentials
                  key: access-key
            - name: S3_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: s3-credentials
                  key: secret-key
            
            resources:
              requests:
                cpu: "500m"
                memory: "1Gi"
              limits:
                cpu: "2"
                memory: "4Gi"
            
            volumeMounts:
            - name: backup-volume
              mountPath: /backup
          
          volumes:
          - name: backup-volume
            emptyDir:
              sizeLimit: 50Gi
```

---

## 3. Pod调度策略与优化

### 3.1 调度器工作原理

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Kubernetes 调度器工作流程                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  待调度Pod                                                               │
│      │                                                                  │
│      ▼                                                                  │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     调度周期 (Scheduling Cycle)                   │   │
│  │                                                                  │   │
│  │  1. 预过滤 (PreFilter)                                           │   │
│  │     └─ 检查Pod是否满足调度条件                                     │   │
│  │                                                                  │   │
│  │  2. 过滤 (Filter)                                                │   │
│  │     ├─ NodeResourcesFit: 资源是否充足                             │   │
│  │     ├─ NodePorts: 端口是否冲突                                    │   │
│  │     ├─ NodeAffinity: 节点亲和性                                   │   │
│  │     ├─ PodTopologySpread: 拓扑分布约束                            │   │
│  │     ├─ TaintToleration: 污点容忍                                  │   │
│  │     └─ ... 更多过滤插件                                           │   │
│  │                                                                  │   │
│  │  3. 后过滤 (PostFilter)                                          │   │
│  │     └─ 如果没有可用节点，尝试抢占                                   │   │
│  │                                                                  │   │
│  │  4. 预打分 (PreScore)                                            │   │
│  │     └─ 为打分阶段准备数据                                         │   │
│  │                                                                  │   │
│  │  5. 打分 (Score)                                                 │   │
│  │     ├─ NodeResourcesBalancedAllocation: 资源均衡                  │   │
│  │     ├─ ImageLocality: 镜像本地性                                  │   │
│  │     ├─ InterPodAffinity: Pod亲和性                               │   │
│  │     ├─ NodeAffinity: 节点亲和性偏好                               │   │
│  │     └─ ... 更多打分插件                                           │   │
│  │                                                                  │   │
│  │  6. 标准化打分 (NormalizeScore)                                   │   │
│  │     └─ 将各插件分数归一化到0-100                                   │   │
│  │                                                                  │   │
│  │  7. 选择节点 (Select)                                            │   │
│  │     └─ 选择得分最高的节点                                         │   │
│  └──────────────────────────┬──────────────────────────────────────┘   │
│                             │                                           │
│                             ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     绑定周期 (Binding Cycle)                      │   │
│  │                                                                  │   │
│  │  8. 预绑定 (PreBind)                                             │   │
│  │     └─ 准备绑定前的工作（如PV绑定）                                 │   │
│  │                                                                  │   │
│  │  9. 绑定 (Bind)                                                  │   │
│  │     └─ 将Pod绑定到选定节点                                        │   │
│  │                                                                  │   │
│  │  10. 后绑定 (PostBind)                                           │   │
│  │      └─ 绑定完成后的清理工作                                       │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 节点亲和性配置

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-workload
spec:
  template:
    spec:
      affinity:
        # 节点亲和性
        nodeAffinity:
          # 硬性要求 - 必须满足
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              # 必须是GPU节点
              - key: node.kubernetes.io/instance-type
                operator: In
                values:
                - gpu.large
                - gpu.xlarge
              # 必须在特定可用区
              - key: topology.kubernetes.io/zone
                operator: In
                values:
                - cn-hangzhou-a
                - cn-hangzhou-b
            # 或者满足另一组条件
            - matchExpressions:
              - key: accelerator
                operator: In
                values:
                - nvidia-tesla-v100
                - nvidia-a100
          
          # 软性偏好 - 尽量满足
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              # 优先选择有本地SSD的节点
              - key: storage-type
                operator: In
                values:
                - local-ssd
          - weight: 50
            preference:
              matchExpressions:
              # 其次选择高性能网络节点
              - key: network
                operator: In
                values:
                - high-performance
```

### 3.3 Pod亲和性与反亲和性

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-frontend
spec:
  template:
    spec:
      affinity:
        # Pod亲和性 - 与特定Pod靠近
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: cache
            topologyKey: kubernetes.io/hostname
            namespaces:
            - production
          
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: backend-api
              topologyKey: topology.kubernetes.io/zone
        
        # Pod反亲和性 - 与特定Pod分离
        podAntiAffinity:
          # 硬性要求：同一应用的Pod不能在同一节点
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: web-frontend
            topologyKey: kubernetes.io/hostname
          
          # 软性偏好：尽量分布在不同可用区
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: web-frontend
              topologyKey: topology.kubernetes.io/zone
```

### 3.4 拓扑分布约束 (TopologySpreadConstraints)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: high-availability-app
spec:
  replicas: 12
  template:
    spec:
      topologySpreadConstraints:
      # 跨可用区均匀分布
      - maxSkew: 1                              # 最大倾斜度
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule        # 不满足时不调度
        labelSelector:
          matchLabels:
            app: high-availability-app
        minDomains: 3                           # 最小域数量 (v1.25+)
        nodeAffinityPolicy: Honor               # 考虑节点亲和性 (v1.26+)
        nodeTaintsPolicy: Honor                 # 考虑节点污点 (v1.26+)
      
      # 跨节点均匀分布
      - maxSkew: 2
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway       # 不满足时仍调度到最优节点
        labelSelector:
          matchLabels:
            app: high-availability-app
      
      # 跨机架分布 (如果有机架标签)
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/rack
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: high-availability-app
```

### 3.5 污点与容忍

```yaml
# 节点污点配置
# kubectl taint nodes node1 dedicated=gpu:NoSchedule
# kubectl taint nodes node2 maintenance=true:NoExecute

apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-training
spec:
  template:
    spec:
      tolerations:
      # 容忍GPU专用节点污点
      - key: dedicated
        operator: Equal
        value: gpu
        effect: NoSchedule
      
      # 容忍所有NoSchedule污点 (慎用)
      - operator: Exists
        effect: NoSchedule
      
      # 容忍节点维护污点，但最多等待3600秒
      - key: maintenance
        operator: Equal
        value: "true"
        effect: NoExecute
        tolerationSeconds: 3600
      
      # 容忍节点不可达 (默认添加)
      - key: node.kubernetes.io/not-ready
        operator: Exists
        effect: NoExecute
        tolerationSeconds: 300
      - key: node.kubernetes.io/unreachable
        operator: Exists
        effect: NoExecute
        tolerationSeconds: 300
```

### 3.6 优先级与抢占

```yaml
# 定义优先级类
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
preemptionPolicy: PreemptLowerPriority  # 允许抢占低优先级Pod
description: "高优先级业务，可抢占其他Pod"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority
value: 100
preemptionPolicy: Never                  # 不允许抢占其他Pod
description: "低优先级任务，不抢占其他Pod"
---
# 使用优先级类
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-service
spec:
  template:
    spec:
      priorityClassName: high-priority
      containers:
      - name: app
        image: critical-app:v1
```

---

## 4. 生产环境配置实践

### 4.1 资源配额与限制

#### 4.1.1 命名空间资源配额

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    # 计算资源限制
    requests.cpu: "100"
    requests.memory: "200Gi"
    limits.cpu: "200"
    limits.memory: "400Gi"
    
    # Pod数量限制
    pods: "100"
    
    # 存储资源限制
    requests.storage: "500Gi"
    persistentvolumeclaims: "50"
    
    # 服务资源限制
    services: "20"
    services.loadbalancers: "5"
    services.nodeports: "10"
    
    # Secret/ConfigMap限制
    secrets: "100"
    configmaps: "100"
    
    # 特定StorageClass配额
    fast-ssd.storageclass.storage.k8s.io/requests.storage: "100Gi"
    fast-ssd.storageclass.storage.k8s.io/persistentvolumeclaims: "10"
    
    # 优先级类配额
    count/pods.high-priority: "20"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
  namespace: production
spec:
  limits:
  # 容器默认限制
  - type: Container
    default:
      cpu: "1"
      memory: "1Gi"
    defaultRequest:
      cpu: "100m"
      memory: "256Mi"
    min:
      cpu: "50m"
      memory: "64Mi"
    max:
      cpu: "8"
      memory: "16Gi"
    maxLimitRequestRatio:
      cpu: "10"
      memory: "4"
  
  # Pod级别限制
  - type: Pod
    max:
      cpu: "16"
      memory: "32Gi"
  
  # PVC限制
  - type: PersistentVolumeClaim
    min:
      storage: "1Gi"
    max:
      storage: "100Gi"
```

### 4.2 PodDisruptionBudget (PDB) 配置

```yaml
# 基于最小可用数
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-server-pdb
  namespace: production
spec:
  minAvailable: 3            # 至少保持3个Pod可用
  selector:
    matchLabels:
      app: api-server
  # 不健康Pod驱逐策略 (v1.27+)
  unhealthyPodEvictionPolicy: IfHealthyBudget
  # IfHealthyBudget: 仅当健康Pod满足预算时才驱逐不健康Pod
  # AlwaysAllow: 总是允许驱逐不健康Pod
---
# 基于最大不可用数
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: worker-pdb
  namespace: production
spec:
  maxUnavailable: 1          # 最多允许1个Pod不可用
  selector:
    matchLabels:
      app: worker
---
# 基于百分比
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: cache-pdb
  namespace: production
spec:
  minAvailable: "80%"        # 至少保持80%的Pod可用
  selector:
    matchLabels:
      app: cache
```

### 4.3 健康检查最佳实践

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: robust-service
spec:
  template:
    spec:
      containers:
      - name: app
        image: robust-app:v1
        
        # 启动探针 - 处理慢启动应用
        startupProbe:
          httpGet:
            path: /healthz/startup
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 30   # 最长等待5分钟启动
        
        # 就绪探针 - 控制流量
        readinessProbe:
          httpGet:
            path: /healthz/ready
            port: 8080
            httpHeaders:
            - name: X-Health-Check
              value: readiness
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3    # 连续3次失败后移出Service
        
        # 存活探针 - 重启不健康容器
        livenessProbe:
          httpGet:
            path: /healthz/live
            port: 8080
          initialDelaySeconds: 60  # 等待启动完成
          periodSeconds: 15
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 3      # 连续3次失败后重启
        
        # TCP探针示例
        # livenessProbe:
        #   tcpSocket:
        #     port: 8080
        #   initialDelaySeconds: 30
        #   periodSeconds: 10
        
        # 命令探针示例
        # livenessProbe:
        #   exec:
        #     command:
        #     - /bin/sh
        #     - -c
        #     - /app/healthcheck.sh
        #   initialDelaySeconds: 30
        #   periodSeconds: 10
        
        # gRPC探针示例 (v1.27+)
        # livenessProbe:
        #   grpc:
        #     port: 50051
        #     service: health.v1.Health
        #   initialDelaySeconds: 30
        #   periodSeconds: 10
```

### 4.4 优雅终止配置

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: graceful-app
spec:
  template:
    spec:
      terminationGracePeriodSeconds: 60  # 优雅终止超时时间
      
      containers:
      - name: app
        image: graceful-app:v1
        
        lifecycle:
          preStop:
            exec:
              command:
              - /bin/sh
              - -c
              - |
                echo "Graceful shutdown initiated at $(date)"
                
                # 1. 停止接收新连接
                # 通知负载均衡器停止发送新流量
                curl -X POST http://localhost:8080/admin/drain
                
                # 2. 等待现有请求完成
                # 给正在处理的请求一些时间完成
                sleep 15
                
                # 3. 清理资源
                # 关闭数据库连接、刷新缓存等
                curl -X POST http://localhost:8080/admin/cleanup
                
                # 4. 等待清理完成
                sleep 5
                
                echo "Graceful shutdown completed at $(date)"
        
        # 应用需要处理SIGTERM信号
        # 在收到SIGTERM后：
        # 1. 停止接受新请求
        # 2. 完成正在处理的请求
        # 3. 释放资源
        # 4. 正常退出
```

---

## 5. 自动扩缩容体系

### 5.1 HPA/VPA/KEDA 对比

| 特性 | HPA | VPA | KEDA |
|------|-----|-----|------|
| **扩缩维度** | 水平(Pod数量) | 垂直(资源大小) | 水平+事件驱动 |
| **触发条件** | CPU/内存/自定义指标 | 历史资源使用 | 外部事件源 |
| **扩缩速度** | 中等(15秒检查) | 慢(需重启Pod) | 快(秒级响应) |
| **零副本支持** | 不支持(min≥1) | 不支持 | 支持 |
| **适用场景** | 稳定负载变化 | 资源优化 | 事件驱动/批处理 |
| **复杂度** | 低 | 中 | 中高 |

### 5.2 HPA 高级配置

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: advanced-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  
  minReplicas: 3
  maxReplicas: 50
  
  metrics:
  # CPU使用率
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  
  # 内存使用率
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  
  # 基于Pod的自定义指标
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"
  
  # 基于Object的外部指标
  - type: Object
    object:
      metric:
        name: queue_messages_ready
        selector:
          matchLabels:
            queue: "main-queue"
      describedObject:
        apiVersion: v1
        kind: Service
        name: rabbitmq
      target:
        type: Value
        value: "100"
  
  # 外部指标 (来自Prometheus等)
  - type: External
    external:
      metric:
        name: pubsub_subscription_num_undelivered_messages
        selector:
          matchLabels:
            subscription: "orders-subscription"
      target:
        type: AverageValue
        averageValue: "10"
  
  # 容器级别指标 (v1.27+)
  - type: ContainerResource
    containerResource:
      name: cpu
      container: app
      target:
        type: Utilization
        averageUtilization: 70
  
  # 扩缩行为控制
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60     # 扩容稳定窗口
      selectPolicy: Max                   # 选择最大扩容量
      policies:
      - type: Percent
        value: 100                        # 每次最多扩容100%
        periodSeconds: 60
      - type: Pods
        value: 10                         # 或每次最多扩容10个Pod
        periodSeconds: 60
    
    scaleDown:
      stabilizationWindowSeconds: 300    # 缩容稳定窗口(5分钟)
      selectPolicy: Min                   # 选择最小缩容量
      policies:
      - type: Percent
        value: 10                         # 每次最多缩容10%
        periodSeconds: 120
      - type: Pods
        value: 2                          # 或每次最多缩容2个Pod
        periodSeconds: 120
```

### 5.3 VPA 配置

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: app-vpa
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  
  updatePolicy:
    updateMode: Auto          # Off | Initial | Recreate | Auto
    # Off: 仅推荐，不应用
    # Initial: 仅在Pod创建时应用
    # Recreate: 通过删除重建应用
    # Auto: 自动选择最佳方式
    
    minReplicas: 2            # VPA操作时保持最小副本数
  
  resourcePolicy:
    containerPolicies:
    - containerName: app
      minAllowed:
        cpu: "100m"
        memory: "128Mi"
      maxAllowed:
        cpu: "4"
        memory: "8Gi"
      controlledResources:
      - cpu
      - memory
      controlledValues: RequestsAndLimits  # RequestsOnly | RequestsAndLimits
    
    - containerName: sidecar
      mode: "Off"             # 不自动调整此容器
```

### 5.4 KEDA 事件驱动扩缩容

```yaml
# 安装KEDA: helm install keda kedacore/keda --namespace keda --create-namespace

apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: kafka-consumer-scaler
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: kafka-consumer
  
  minReplicaCount: 1
  maxReplicaCount: 100
  
  pollingInterval: 15         # 检查间隔(秒)
  cooldownPeriod: 60          # 缩容冷却期(秒)
  
  # 支持缩容到0
  idleReplicaCount: 0
  
  # 高级配置
  advanced:
    restoreToOriginalReplicaCount: true  # 删除ScaledObject时恢复原始副本数
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          stabilizationWindowSeconds: 300
  
  triggers:
  # Kafka触发器
  - type: kafka
    metadata:
      bootstrapServers: kafka-cluster:9092
      consumerGroup: my-consumer-group
      topic: orders
      lagThreshold: "100"     # 每个分区积压阈值
    authenticationRef:
      name: kafka-credentials
  
  # Prometheus触发器
  - type: prometheus
    metadata:
      serverAddress: http://prometheus:9090
      metricName: http_requests_total
      query: sum(rate(http_requests_total{job="api-server"}[2m]))
      threshold: "1000"
  
  # RabbitMQ触发器
  - type: rabbitmq
    metadata:
      host: amqp://rabbitmq:5672
      queueName: tasks
      queueLength: "50"
  
  # Redis触发器
  - type: redis
    metadata:
      address: redis:6379
      listName: pending-jobs
      listLength: "10"
  
  # Cron触发器 - 定时扩缩容
  - type: cron
    metadata:
      timezone: Asia/Shanghai
      start: "0 8 * * *"      # 每天8点
      end: "0 20 * * *"       # 每天20点
      desiredReplicas: "10"
---
# 认证配置
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: kafka-credentials
  namespace: production
spec:
  secretTargetRef:
  - parameter: username
    name: kafka-secret
    key: username
  - parameter: password
    name: kafka-secret
    key: password
```

---

## 6. 监控与告警

### 6.1 关键监控指标

| 指标类别 | 具体指标 | 告警阈值 | 说明 |
|----------|----------|----------|------|
| **副本状态** | `kube_deployment_status_replicas_available` | 差异>1 | 可用副本数异常 |
| **更新状态** | `kube_deployment_status_condition{condition="Progressing"}` | =false持续10m | 更新卡住 |
| **资源使用** | `container_cpu_usage_seconds_total` | >80%持续5m | CPU使用率高 |
| **内存使用** | `container_memory_working_set_bytes` | >90%持续5m | 内存使用率高 |
| **重启次数** | `kube_pod_container_status_restarts_total` | 增长>5/h | 容器频繁重启 |
| **OOM次数** | `kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}` | >0 | 内存溢出 |
| **调度失败** | `kube_pod_status_phase{phase="Pending"}` | >5持续5m | 调度问题 |
| **探针失败** | `prober_probe_total{result="failed"}` | 增长>10/m | 健康检查失败 |

### 6.2 Prometheus 告警规则

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: workload-alerts
  namespace: monitoring
spec:
  groups:
  - name: deployment.rules
    rules:
    # Deployment副本数不足
    - alert: DeploymentReplicasMismatch
      expr: |
        kube_deployment_spec_replicas != kube_deployment_status_replicas_available
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Deployment副本数不匹配"
        description: "{{ $labels.namespace }}/{{ $labels.deployment }} 期望{{ $value }}个副本，当前可用副本数不足"
    
    # Deployment更新卡住
    - alert: DeploymentRolloutStuck
      expr: |
        kube_deployment_status_condition{condition="Progressing",status="false"} == 1
      for: 15m
      labels:
        severity: critical
      annotations:
        summary: "Deployment更新卡住"
        description: "{{ $labels.namespace }}/{{ $labels.deployment }} 滚动更新已卡住超过15分钟"
    
    # Deployment没有可用副本
    - alert: DeploymentNoAvailableReplicas
      expr: |
        kube_deployment_status_replicas_available == 0 
        and kube_deployment_spec_replicas > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Deployment无可用副本"
        description: "{{ $labels.namespace }}/{{ $labels.deployment }} 没有可用的副本"
  
  - name: pod.rules
    rules:
    # Pod频繁重启
    - alert: PodFrequentlyRestarting
      expr: |
        increase(kube_pod_container_status_restarts_total[1h]) > 5
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Pod频繁重启"
        description: "{{ $labels.namespace }}/{{ $labels.pod }} 在过去1小时内重启了{{ $value }}次"
    
    # Pod OOM
    - alert: PodOOMKilled
      expr: |
        kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1
      for: 0m
      labels:
        severity: warning
      annotations:
        summary: "Pod因OOM被终止"
        description: "{{ $labels.namespace }}/{{ $labels.pod }} 的容器{{ $labels.container }}因内存溢出被终止"
    
    # Pod处于Pending状态过长
    - alert: PodPendingTooLong
      expr: |
        kube_pod_status_phase{phase="Pending"} == 1
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "Pod长时间处于Pending状态"
        description: "{{ $labels.namespace }}/{{ $labels.pod }} 已处于Pending状态超过15分钟"
    
    # Pod未就绪
    - alert: PodNotReady
      expr: |
        kube_pod_status_ready{condition="false"} == 1
        and kube_pod_status_phase{phase="Running"} == 1
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Pod未就绪"
        description: "{{ $labels.namespace }}/{{ $labels.pod }} 运行中但未就绪超过10分钟"
  
  - name: resource.rules
    rules:
    # CPU使用率高
    - alert: ContainerHighCPU
      expr: |
        (sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (namespace, pod, container)
        / sum(kube_pod_container_resource_limits{resource="cpu"}) by (namespace, pod, container)) > 0.8
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "容器CPU使用率高"
        description: "{{ $labels.namespace }}/{{ $labels.pod }}/{{ $labels.container }} CPU使用率超过80%"
    
    # 内存使用率高
    - alert: ContainerHighMemory
      expr: |
        (sum(container_memory_working_set_bytes{container!=""}) by (namespace, pod, container)
        / sum(kube_pod_container_resource_limits{resource="memory"}) by (namespace, pod, container)) > 0.9
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "容器内存使用率高"
        description: "{{ $labels.namespace }}/{{ $labels.pod }}/{{ $labels.container }} 内存使用率超过90%"
  
  - name: statefulset.rules
    rules:
    # StatefulSet副本数不匹配
    - alert: StatefulSetReplicasMismatch
      expr: |
        kube_statefulset_status_replicas_ready != kube_statefulset_status_replicas
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "StatefulSet副本数不匹配"
        description: "{{ $labels.namespace }}/{{ $labels.statefulset }} 期望{{ $value }}个副本就绪"
    
    # StatefulSet更新卡住
    - alert: StatefulSetUpdateNotRolledOut
      expr: |
        max without (revision) (
          kube_statefulset_status_current_revision
            unless
          kube_statefulset_status_update_revision
        ) * (
          kube_statefulset_replicas
            != 
          kube_statefulset_status_replicas_updated
        ) > 0
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "StatefulSet更新未完成"
        description: "{{ $labels.namespace }}/{{ $labels.statefulset }} 更新未完成"
  
  - name: job.rules
    rules:
    # Job失败
    - alert: JobFailed
      expr: |
        kube_job_status_failed > 0
      for: 0m
      labels:
        severity: warning
      annotations:
        summary: "Job执行失败"
        description: "{{ $labels.namespace }}/{{ $labels.job_name }} 执行失败"
    
    # Job运行时间过长
    - alert: JobRunningTooLong
      expr: |
        time() - kube_job_status_start_time > 3600
        and kube_job_status_active > 0
      for: 0m
      labels:
        severity: warning
      annotations:
        summary: "Job运行时间过长"
        description: "{{ $labels.namespace }}/{{ $labels.job_name }} 已运行超过1小时"
```

---

## 7. 故障排查手册

### 7.1 故障诊断流程图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Pod 故障诊断流程                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Pod状态异常?                                                            │
│      │                                                                  │
│      ├── Pending ──┐                                                    │
│      │             ├── 检查调度: kubectl describe pod <pod>             │
│      │             ├── Events显示调度失败原因                            │
│      │             ├── 资源不足? → 扩容节点或调整requests                │
│      │             ├── 节点选择器不匹配? → 检查nodeSelector/affinity    │
│      │             ├── 污点无法容忍? → 添加tolerations                  │
│      │             └── PVC未绑定? → 检查StorageClass和PV                │
│      │                                                                  │
│      ├── ImagePullBackOff ──┐                                          │
│      │                      ├── 检查镜像名称是否正确                      │
│      │                      ├── 检查镜像仓库凭证                          │
│      │                      ├── 检查网络连接到镜像仓库                    │
│      │                      └── 验证镜像是否存在                          │
│      │                                                                  │
│      ├── CrashLoopBackOff ──┐                                          │
│      │                      ├── kubectl logs <pod> --previous          │
│      │                      ├── 检查应用启动日志                         │
│      │                      ├── 检查探针配置是否过于严格                  │
│      │                      ├── 检查资源限制是否过小                      │
│      │                      └── 检查配置文件/环境变量                     │
│      │                                                                  │
│      ├── Running但不健康 ──┐                                            │
│      │                    ├── 检查readinessProbe结果                    │
│      │                    ├── kubectl exec进入Pod调试                   │
│      │                    ├── 检查Service Endpoints                     │
│      │                    └── 检查NetworkPolicy                         │
│      │                                                                  │
│      ├── Evicted ──┐                                                   │
│      │             ├── 检查节点资源压力                                   │
│      │             ├── kubectl describe node <node>                    │
│      │             ├── 磁盘压力? → 清理节点或增加存储                     │
│      │             ├── 内存压力? → 调整Pod资源或驱逐策略                  │
│      │             └── PID压力? → 检查进程泄漏                           │
│      │                                                                  │
│      └── Terminating卡住 ──┐                                           │
│                            ├── 检查finalizers                           │
│                            ├── kubectl get pod -o yaml | grep finaliz  │
│                            ├── 强制删除: kubectl delete pod --force     │
│                            └── 检查preStop hook是否卡住                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7.2 常用诊断命令

```bash
#!/bin/bash
# 工作负载诊断脚本

NAMESPACE=${1:-default}
WORKLOAD_TYPE=${2:-deployment}
WORKLOAD_NAME=$3

echo "=========================================="
echo "工作负载诊断报告"
echo "命名空间: $NAMESPACE"
echo "工作负载: $WORKLOAD_TYPE/$WORKLOAD_NAME"
echo "时间: $(date)"
echo "=========================================="

# 1. 基础状态检查
echo -e "\n=== 1. 工作负载状态 ==="
kubectl get $WORKLOAD_TYPE $WORKLOAD_NAME -n $NAMESPACE -o wide

echo -e "\n=== 2. Pod列表 ==="
kubectl get pods -n $NAMESPACE -l app=$WORKLOAD_NAME -o wide

echo -e "\n=== 3. 详细描述 ==="
kubectl describe $WORKLOAD_TYPE $WORKLOAD_NAME -n $NAMESPACE

echo -e "\n=== 4. Pod事件 ==="
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -i $WORKLOAD_NAME | tail -20

echo -e "\n=== 5. 资源使用情况 ==="
kubectl top pods -n $NAMESPACE -l app=$WORKLOAD_NAME

echo -e "\n=== 6. 容器日志 (最近50行) ==="
POD=$(kubectl get pods -n $NAMESPACE -l app=$WORKLOAD_NAME -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD" ]; then
    kubectl logs $POD -n $NAMESPACE --tail=50
fi

echo -e "\n=== 7. 前一个容器日志 (如果存在) ==="
if [ -n "$POD" ]; then
    kubectl logs $POD -n $NAMESPACE --previous --tail=20 2>/dev/null || echo "无前一个容器日志"
fi

echo -e "\n=== 8. HPA状态 ==="
kubectl get hpa -n $NAMESPACE | grep $WORKLOAD_NAME

echo -e "\n=== 9. PDB状态 ==="
kubectl get pdb -n $NAMESPACE | grep $WORKLOAD_NAME

echo -e "\n=== 10. Service/Endpoints ==="
kubectl get svc,ep -n $NAMESPACE | grep $WORKLOAD_NAME
```

### 7.3 常见故障解决方案

#### 7.3.1 Pod Pending - 资源不足

```bash
# 诊断步骤
kubectl describe pod <pod-name> -n <namespace>
# 查看Events中的调度失败原因

# 检查节点资源
kubectl describe nodes | grep -A 5 "Allocated resources"

# 解决方案
# 1. 降低Pod资源请求
kubectl patch deployment <name> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container>","resources":{"requests":{"cpu":"100m","memory":"256Mi"}}}]}}}}'

# 2. 扩容节点池 (阿里云ACK)
# aliyun cs ModifyClusterNodePool --ClusterId <cluster-id> --NodepoolId <pool-id> --scaling_config '{"max_instances":10}'
```

#### 7.3.2 CrashLoopBackOff - 应用崩溃

```bash
# 获取容器日志
kubectl logs <pod-name> -n <namespace> --previous

# 检查退出码
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
# 退出码含义:
# 0: 正常退出
# 1: 应用错误
# 137: OOM或SIGKILL
# 143: SIGTERM

# 临时禁用探针进行调试
kubectl patch deployment <name> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container>","livenessProbe":null,"readinessProbe":null}]}}}}'

# 进入容器调试
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh
```

#### 7.3.3 滚动更新卡住

```bash
# 检查更新状态
kubectl rollout status deployment/<name> -n <namespace>

# 查看更新历史
kubectl rollout history deployment/<name> -n <namespace>

# 检查新旧ReplicaSet
kubectl get rs -n <namespace> -l app=<app-label>

# 暂停更新
kubectl rollout pause deployment/<name> -n <namespace>

# 回滚到上一版本
kubectl rollout undo deployment/<name> -n <namespace>

# 回滚到指定版本
kubectl rollout undo deployment/<name> -n <namespace> --to-revision=2

# 强制重新部署
kubectl rollout restart deployment/<name> -n <namespace>
```

---

## 8. 安全加固配置

### 8.1 Pod安全标准 (Pod Security Standards)

```yaml
# 命名空间级别安全策略
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    # Pod安全标准 (v1.25+)
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
---
# 符合restricted标准的Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: production
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      
      containers:
      - name: app
        image: secure-app:v1
        securityContext:
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          privileged: false
          runAsNonRoot: true
          runAsUser: 1000
```

### 8.2 RBAC 最小权限配置

```yaml
# 为工作负载创建专用ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-service-account
  namespace: production
automountServiceAccountToken: false  # 默认不挂载token
---
# 最小权限Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: production
rules:
# 只读访问ConfigMap和Secret
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  resourceNames: ["app-config", "app-secrets"]
  verbs: ["get", "watch"]
# 读写访问特定Endpoints (如leader选举)
- apiGroups: [""]
  resources: ["endpoints"]
  resourceNames: ["app-leader"]
  verbs: ["get", "watch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-role-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: app-service-account
  namespace: production
roleRef:
  kind: Role
  name: app-role
  apiGroup: rbac.authorization.k8s.io
---
# 在Deployment中使用
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  template:
    spec:
      serviceAccountName: app-service-account
      automountServiceAccountToken: true  # 需要时才挂载
```

### 8.3 网络策略

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-network-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: secure-app
  policyTypes:
  - Ingress
  - Egress
  
  ingress:
  # 只允许来自同命名空间的Ingress Controller
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
      podSelector:
        matchLabels:
          app.kubernetes.io/name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  
  # 允许来自同命名空间特定应用的访问
  - from:
    - podSelector:
        matchLabels:
          app: api-gateway
    ports:
    - protocol: TCP
      port: 8080
  
  # 允许Prometheus抓取指标
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
      podSelector:
        matchLabels:
          app: prometheus
    ports:
    - protocol: TCP
      port: 9090
  
  egress:
  # 允许访问CoreDNS
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  
  # 允许访问数据库
  - to:
    - namespaceSelector:
        matchLabels:
          name: database
      podSelector:
        matchLabels:
          app: mysql
    ports:
    - protocol: TCP
      port: 3306
  
  # 允许访问Redis
  - to:
    - namespaceSelector:
        matchLabels:
          name: cache
      podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
```

---

## 9. 实战案例演练

### 9.1 案例一：电商大促扩容

**场景**: 双11大促期间，需要将API服务从10个副本扩容到100个副本，同时确保服务稳定

```yaml
# 1. 提前配置HPA
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-server-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-server
  minReplicas: 10
  maxReplicas: 100
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
      - type: Percent
        value: 200
        periodSeconds: 30
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
---
# 2. 配置PDB保护
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-server-pdb
  namespace: production
spec:
  minAvailable: "90%"
  selector:
    matchLabels:
      app: api-server
---
# 3. 预扩容脚本
# kubectl scale deployment api-server -n production --replicas=50
# 观察扩容状态
# kubectl rollout status deployment api-server -n production
# 确认所有Pod就绪
# kubectl get pods -n production -l app=api-server | grep -c Running
```

### 9.2 案例二：数据库主从切换

**场景**: MySQL主库故障，需要将从库提升为主库

```bash
#!/bin/bash
# mysql-failover.sh

NAMESPACE="database"
STATEFULSET="mysql-cluster"

echo "1. 检查当前状态"
kubectl get pods -n $NAMESPACE -l app=mysql -o wide

echo "2. 停止复制并提升mysql-cluster-1为主库"
kubectl exec -n $NAMESPACE mysql-cluster-1 -c mysql -- mysql -e "
STOP SLAVE;
RESET SLAVE ALL;
SET GLOBAL read_only=0;
"

echo "3. 将mysql-cluster-2指向新主库"
kubectl exec -n $NAMESPACE mysql-cluster-2 -c mysql -- mysql -e "
STOP SLAVE;
CHANGE MASTER TO 
  MASTER_HOST='mysql-cluster-1.mysql-headless',
  MASTER_USER='repl',
  MASTER_PASSWORD='repl_password',
  MASTER_AUTO_POSITION=1;
START SLAVE;
"

echo "4. 更新Service指向新主库"
kubectl patch svc mysql-primary -n $NAMESPACE -p '{"spec":{"selector":{"statefulset.kubernetes.io/pod-name":"mysql-cluster-1"}}}'

echo "5. 验证切换结果"
kubectl exec -n $NAMESPACE mysql-cluster-1 -c mysql -- mysql -e "SHOW MASTER STATUS\G"
kubectl exec -n $NAMESPACE mysql-cluster-2 -c mysql -- mysql -e "SHOW SLAVE STATUS\G"
```

### 9.3 案例三：滚动更新回滚

**场景**: 新版本上线后发现严重Bug，需要紧急回滚

```bash
#!/bin/bash
# rollback.sh

NAMESPACE="production"
DEPLOYMENT="api-server"
TARGET_REVISION=$1

echo "1. 暂停当前更新"
kubectl rollout pause deployment/$DEPLOYMENT -n $NAMESPACE

echo "2. 查看更新历史"
kubectl rollout history deployment/$DEPLOYMENT -n $NAMESPACE

echo "3. 查看指定版本详情"
kubectl rollout history deployment/$DEPLOYMENT -n $NAMESPACE --revision=$TARGET_REVISION

echo "4. 执行回滚"
if [ -z "$TARGET_REVISION" ]; then
    # 回滚到上一版本
    kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE
else
    # 回滚到指定版本
    kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE --to-revision=$TARGET_REVISION
fi

echo "5. 监控回滚状态"
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE

echo "6. 验证回滚结果"
kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT -o wide

echo "7. 检查新Pod的镜像版本"
kubectl get pods -n $NAMESPACE -l app=$DEPLOYMENT -o jsonpath='{.items[*].spec.containers[*].image}'
```

---

## 10. 总结与Q&A

### 10.1 核心要点回顾

| 主题 | 关键要点 |
|------|----------|
| **控制器选型** | Deployment(无状态)、StatefulSet(有状态)、DaemonSet(节点守护)、Job/CronJob(批处理) |
| **调度策略** | nodeSelector → nodeAffinity → podAffinity → topologySpreadConstraints |
| **高可用** | 多副本 + PDB + 跨AZ分布 + 优雅终止 |
| **自动扩缩** | HPA(水平) + VPA(垂直) + KEDA(事件驱动) |
| **监控告警** | 副本状态 + 资源使用 + 重启次数 + 探针状态 |
| **安全加固** | Pod Security Standards + RBAC + NetworkPolicy |

### 10.2 最佳实践清单

- [ ] 为所有Deployment配置合理的resources requests/limits
- [ ] 配置完整的健康检查：startupProbe + readinessProbe + livenessProbe
- [ ] 使用topologySpreadConstraints实现跨AZ高可用
- [ ] 为关键服务配置PodDisruptionBudget
- [ ] 配置优雅终止和preStop钩子
- [ ] 启用HPA并配置合理的扩缩策略
- [ ] 实施Pod Security Standards
- [ ] 配置NetworkPolicy限制网络访问
- [ ] 建立完善的监控告警体系
- [ ] 定期进行故障演练和回滚测试

### 10.3 常见问题解答

**Q: Deployment和StatefulSet如何选择？**
A: 无状态应用(Web服务、API)用Deployment；有状态应用(数据库、消息队列)用StatefulSet，需要稳定网络标识和持久化存储时必选StatefulSet。

**Q: HPA和VPA能同时使用吗？**
A: 可以，但需要注意：VPA不能调整HPA已管理的CPU/内存指标。推荐HPA管理副本数，VPA管理其他资源或仅用于推荐模式。

**Q: 如何实现真正的零停机更新？**
A: 1) maxUnavailable=0确保不主动删除旧Pod；2) 配置合理的readinessProbe；3) 设置minReadySeconds等待新Pod稳定；4) 配置preStop钩子优雅处理请求。

**Q: Pod频繁重启如何排查？**
A: 1) 检查日志kubectl logs --previous；2) 检查退出码确定是OOM还是应用错误；3) 检查探针配置是否过于严格；4) 检查资源限制是否足够。

---

## 阿里云ACK专属配置

### ACK节点池配置

```yaml
# ACK节点池Deployment亲和性
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ack-optimized-app
spec:
  template:
    spec:
      nodeSelector:
        # ACK节点池标签
        alibabacloud.com/nodepool-id: "np-xxxxxxxx"
      
      tolerations:
      # 容忍ACK专用节点污点
      - key: "alibabacloud.com/nodepool-id"
        operator: "Equal"
        value: "np-xxxxxxxx"
        effect: "NoSchedule"
```

### ACK弹性伸缩集成

```yaml
# ACK cluster-autoscaler配置
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ack-hpa
  annotations:
    # ACK特定注解
    ack.alibabacloud.com/scaledown-delay: "5m"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 50
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
```

---

## 附录 A: 常用命令速查表

```bash
# Deployment 管理
kubectl get deployments -A -o wide
kubectl describe deployment <name> -n <namespace>
kubectl rollout status deployment/<name>
kubectl rollout history deployment/<name>
kubectl rollout undo deployment/<name> --to-revision=<n>
kubectl scale deployment/<name> --replicas=<n>

# StatefulSet 管理
kubectl get statefulsets -A -o wide
kubectl describe statefulset <name> -n <namespace>
kubectl rollout restart statefulset/<name>

# DaemonSet 管理
kubectl get daemonsets -A -o wide
kubectl rollout status daemonset/<name>

# Job/CronJob 管理
kubectl get jobs -A
kubectl get cronjobs -A
kubectl create job <name> --from=cronjob/<cronjob-name>

# Pod 调试
kubectl get pods -A -o wide --show-labels
kubectl describe pod <name> -n <namespace>
kubectl logs <pod-name> -c <container> --tail=100 -f
kubectl exec -it <pod-name> -c <container> -- /bin/sh
kubectl top pods -n <namespace>

# 资源配额
kubectl get resourcequotas -A
kubectl describe resourcequota <name> -n <namespace>

# HPA/VPA
kubectl get hpa -A
kubectl describe hpa <name>
kubectl get vpa -A
```

## 附录 B: 配置模板索引

| 模板名称 | 适用场景 | 章节位置 |
|----------|----------|----------|
| Deployment 生产配置 | 无状态应用部署 | 2.1 节 |
| StatefulSet 配置 | 有状态应用部署 | 2.2 节 |
| DaemonSet 配置 | 节点级守护进程 | 2.3 节 |
| Job/CronJob 配置 | 批处理任务 | 2.4 节 |
| 亲和性调度配置 | 高级调度策略 | 3.1 节 |
| 拓扑分布约束 | 跨可用区分布 | 3.2 节 |
| HPA 自动伸缩 | 基于指标扩缩容 | 5.1 节 |
| VPA 垂直伸缩 | 自动资源调整 | 5.2 节 |
| PodDisruptionBudget | 可用性保障 | 4.3 节 |
| 安全加固配置 | SecurityContext | 8.1 节 |

## 附录 C: 故障排查索引

| 故障现象 | 可能原因 | 排查方法 | 章节位置 |
|----------|----------|----------|----------|
| Pod Pending | 资源不足/调度约束 | kubectl describe pod | 7.1 节 |
| Pod CrashLoopBackOff | 应用启动失败 | kubectl logs | 7.2 节 |
| Pod ImagePullBackOff | 镜像拉取失败 | 检查镜像仓库 | 7.2 节 |
| Pod OOMKilled | 内存超限 | 调整 resources.limits | 7.3 节 |
| Deployment 滚动更新卡住 | 健康检查失败 | 检查 probes 配置 | 7.4 节 |
| HPA 不生效 | metrics-server 异常 | kubectl top pods | 7.5 节 |
| StatefulSet Pod 启动顺序异常 | PVC 绑定失败 | kubectl get pvc | 7.6 节 |

## 附录 D: 监控指标参考

| 指标名称 | 类型 | 说明 | 告警阈值 |
|----------|------|------|----------|
| `kube_deployment_status_replicas_available` | Gauge | 可用副本数 | < desired |
| `kube_pod_container_status_restarts_total` | Counter | 容器重启次数 | > 5/hour |
| `container_cpu_usage_seconds_total` | Counter | CPU 使用量 | > 80% limit |
| `container_memory_usage_bytes` | Gauge | 内存使用量 | > 80% limit |
| `kube_pod_status_phase` | Gauge | Pod 状态 | != Running |
| `kube_horizontalpodautoscaler_status_current_replicas` | Gauge | HPA 当前副本 | - |

---

**文档版本**: v2.0  
**适用版本**: Kubernetes v1.26-v1.32  
**更新日期**: 2026年1月  
**作者**: Kusheet Project  
**联系方式**: Allen Galler (allengaller@gmail.com)

---

*全文完 - Kubernetes 工作负载生产环境运维培训*
