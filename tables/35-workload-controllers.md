# 表格35: 工作负载控制器详解

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/workloads/controllers](https://kubernetes.io/docs/concepts/workloads/controllers/)

## 控制器类型对比

| 控制器 | 用途 | Pod标识 | 扩缩容 | 更新策略 | 有序性 | 网络标识 |
|-------|-----|---------|-------|---------|-------|---------|
| **Deployment** | 无状态应用 | 随机 | ✅ | RollingUpdate/Recreate | ❌ | 无固定 |
| **StatefulSet** | 有状态应用 | 有序固定 | ✅ | RollingUpdate/OnDelete | ✅ | 固定DNS |
| **DaemonSet** | 节点守护进程 | 每节点一个 | 自动 | RollingUpdate/OnDelete | ❌ | 节点绑定 |
| **ReplicaSet** | 副本管理 | 随机 | ✅ | - | ❌ | 无固定 |
| **Job** | 一次性任务 | 随机 | ❌ | - | ❌ | 无固定 |
| **CronJob** | 定时任务 | 随机 | ❌ | - | ❌ | 无固定 |
| **ReplicationController** | 副本管理(废弃) | 随机 | ✅ | - | ❌ | 无固定 |

## Deployment配置

| 字段 | 类型 | 默认值 | 说明 |
|-----|-----|-------|------|
| `spec.replicas` | int | 1 | 副本数 |
| `spec.selector` | LabelSelector | 必需 | Pod选择器 |
| `spec.template` | PodTemplateSpec | 必需 | Pod模板 |
| `spec.strategy.type` | string | RollingUpdate | 更新策略 |
| `spec.strategy.rollingUpdate.maxSurge` | int/% | 25% | 最大超出副本数 |
| `spec.strategy.rollingUpdate.maxUnavailable` | int/% | 25% | 最大不可用副本数 |
| `spec.minReadySeconds` | int | 0 | 最小就绪秒数 |
| `spec.revisionHistoryLimit` | int | 10 | 保留历史版本数 |
| `spec.progressDeadlineSeconds` | int | 600 | 进度超时时间 |
| `spec.paused` | bool | false | 暂停部署 |

## Deployment示例

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0  # 零停机更新
  minReadySeconds: 10
  revisionHistoryLimit: 5
  progressDeadlineSeconds: 300
  template:
    metadata:
      labels:
        app: nginx
      annotations:
        prometheus.io/scrape: "true"
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
          name: http
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
          successThreshold: 1
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 20
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "nginx -s quit; sleep 10"]
      terminationGracePeriodSeconds: 30
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: nginx
```

## Deployment滚动更新策略

| 策略组合 | maxSurge | maxUnavailable | 效果 | 适用场景 |
|---------|----------|----------------|------|---------|
| 零停机 | 1 | 0 | 先创建再删除 | 生产环境 |
| 快速更新 | 25% | 25% | 同时创建删除 | 开发测试 |
| 资源受限 | 0 | 1 | 先删除再创建 | 资源紧张 |
| 金丝雀 | 1 | 0 + pause | 分批发布 | 风险控制 |

```bash
# 滚动更新操作
kubectl set image deployment/nginx nginx=nginx:1.26
kubectl rollout status deployment/nginx
kubectl rollout history deployment/nginx
kubectl rollout undo deployment/nginx
kubectl rollout undo deployment/nginx --to-revision=2
kubectl rollout pause deployment/nginx   # 暂停发布
kubectl rollout resume deployment/nginx  # 恢复发布

# 金丝雀发布(手动控制)
kubectl set image deployment/nginx nginx=nginx:1.26
kubectl rollout pause deployment/nginx
# 验证后继续
kubectl rollout resume deployment/nginx
```

## StatefulSet配置

| 字段 | 类型 | 说明 |
|-----|-----|------|
| `spec.serviceName` | string | Headless Service名称(必需) |
| `spec.podManagementPolicy` | string | OrderedReady/Parallel |
| `spec.updateStrategy.type` | string | RollingUpdate/OnDelete |
| `spec.updateStrategy.rollingUpdate.partition` | int | 分区更新阈值 |
| `spec.volumeClaimTemplates` | []PVC | PVC模板 |
| `spec.persistentVolumeClaimRetentionPolicy` | Policy | PVC保留策略(v1.27+) |
| `spec.minReadySeconds` | int | 最小就绪秒数 |
| `spec.ordinals.start` | int | 起始序号(v1.27+) |

## StatefulSet示例

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql-headless
  replicas: 3
  podManagementPolicy: OrderedReady  # 或Parallel
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0       # 分区更新:只更新序号>=partition的Pod
      maxUnavailable: 1  # v1.24+
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      initContainers:
      - name: init-mysql
        image: mysql:8.0
        command:
        - bash
        - "-c"
        - |
          # 根据序号设置server-id
          [[ $HOSTNAME =~ -([0-9]+)$ ]] || exit 1
          ordinal=${BASH_REMATCH[1]}
          echo [mysqld] > /mnt/conf.d/server-id.cnf
          echo server-id=$((100 + $ordinal)) >> /mnt/conf.d/server-id.cnf
        volumeMounts:
        - name: conf
          mountPath: /mnt/conf.d
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2
            memory: 4Gi
        livenessProbe:
          exec:
            command: ["mysqladmin", "ping"]
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command: ["mysql", "-h", "127.0.0.1", "-e", "SELECT 1"]
          initialDelaySeconds: 5
          periodSeconds: 2
      volumes:
      - name: conf
        emptyDir: {}
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: alicloud-disk-ssd
      resources:
        requests:
          storage: 100Gi
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Delete   # 删除StatefulSet时删除PVC
    whenScaled: Retain    # 缩容时保留PVC
---
# Headless Service
apiVersion: v1
kind: Service
metadata:
  name: mysql-headless
spec:
  clusterIP: None
  selector:
    app: mysql
  ports:
  - port: 3306
    name: mysql
```

## StatefulSet Pod标识

| Pod名称 | DNS名称 | 说明 |
|--------|--------|------|
| mysql-0 | mysql-0.mysql-headless.ns.svc.cluster.local | 第一个Pod |
| mysql-1 | mysql-1.mysql-headless.ns.svc.cluster.local | 第二个Pod |
| mysql-2 | mysql-2.mysql-headless.ns.svc.cluster.local | 第三个Pod |

## DaemonSet配置

| 字段 | 说明 | 默认值 |
|-----|------|-------|
| `spec.updateStrategy.type` | RollingUpdate/OnDelete | RollingUpdate |
| `spec.updateStrategy.rollingUpdate.maxSurge` | 最大超出(v1.22+) | 0 |
| `spec.updateStrategy.rollingUpdate.maxUnavailable` | 最大不可用 | 1 |
| `spec.minReadySeconds` | 最小就绪秒数 | 0 |
| `spec.revisionHistoryLimit` | 历史版本保留数 | 10 |

```yaml
# DaemonSet示例 - 日志采集
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: fluentd
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 0
  template:
    metadata:
      labels:
        name: fluentd
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: fluentd
        image: fluent/fluentd:v1.16
        resources:
          limits:
            memory: 500Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: containers
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: containers
        hostPath:
          path: /var/lib/docker/containers
      # 选择运行节点
      nodeSelector:
        kubernetes.io/os: linux
```

## Job配置

| 字段 | 类型 | 默认值 | 说明 |
|-----|-----|-------|------|
| `spec.completions` | int | 1 | 完成次数 |
| `spec.parallelism` | int | 1 | 并行度 |
| `spec.backoffLimit` | int | 6 | 重试次数 |
| `spec.activeDeadlineSeconds` | int | - | 超时时间 |
| `spec.ttlSecondsAfterFinished` | int | - | 完成后TTL |
| `spec.completionMode` | string | NonIndexed | NonIndexed/Indexed |
| `spec.suspend` | bool | false | 挂起Job |
| `spec.podFailurePolicy` | Policy | - | 失败策略(v1.26+) |
| `spec.backoffLimitPerIndex` | int | - | 按索引重试(v1.29+) |

## Job示例

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processing
spec:
  completions: 10
  parallelism: 3
  completionMode: Indexed
  backoffLimit: 3
  ttlSecondsAfterFinished: 3600
  podFailurePolicy:
    rules:
    - action: FailJob
      onExitCodes:
        containerName: processor
        operator: In
        values: [1, 2]
    - action: Ignore
      onPodConditions:
      - type: DisruptionTarget
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: processor
        image: processor:v1
        env:
        - name: JOB_COMPLETION_INDEX
          valueFrom:
            fieldRef:
              fieldPath: metadata.annotations['batch.kubernetes.io/job-completion-index']
```

## CronJob配置

| 字段 | 说明 | 默认值 |
|-----|------|-------|
| `spec.schedule` | Cron表达式 | 必需 |
| `spec.timeZone` | 时区(v1.27+ GA) | UTC |
| `spec.concurrencyPolicy` | Allow/Forbid/Replace | Allow |
| `spec.startingDeadlineSeconds` | 启动截止时间 | 无限制 |
| `spec.successfulJobsHistoryLimit` | 成功历史保留数 | 3 |
| `spec.failedJobsHistoryLimit` | 失败历史保留数 | 1 |
| `spec.suspend` | 挂起CronJob | false |

```yaml
# CronJob示例 - 数据库备份
apiVersion: batch/v1
kind: CronJob
metadata:
  name: db-backup
spec:
  schedule: "0 2 * * *"  # 每天凌晨2点
  timeZone: "Asia/Shanghai"
  concurrencyPolicy: Forbid  # 禁止并发执行
  startingDeadlineSeconds: 300
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 2
      activeDeadlineSeconds: 3600
      ttlSecondsAfterFinished: 86400
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: mysql:8.0
            command:
            - /bin/sh
            - -c
            - |
              mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASSWORD \
                --all-databases | gzip > /backup/backup-$(date +%Y%m%d).sql.gz
            env:
            - name: DB_HOST
              value: mysql-0.mysql-headless
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: username
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: password
            volumeMounts:
            - name: backup
              mountPath: /backup
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: backup-pvc
```

## Cron表达式参考

| 表达式 | 说明 |
|-------|------|
| `*/5 * * * *` | 每5分钟 |
| `0 * * * *` | 每小时整点 |
| `0 2 * * *` | 每天凌晨2点 |
| `0 2 * * 0` | 每周日凌晨2点 |
| `0 2 1 * *` | 每月1日凌晨2点 |
| `0 2 1 1 *` | 每年1月1日凌晨2点 |

## 版本变更记录

| 版本 | 变更内容 | 影响 |
|------|---------|------|
| v1.24 | StatefulSet maxUnavailable | 并行更新支持 |
| v1.25 | StatefulSet minReadySeconds GA | 就绪检查更精确 |
| v1.26 | Job podFailurePolicy Beta | 更精细的失败处理 |
| v1.27 | StatefulSet startOrdinal, CronJob timeZone GA | 序号/时区控制 |
| v1.28 | Job podReplacementPolicy Alpha | Pod替换策略 |
| v1.29 | Job backoffLimitPerIndex GA | 按索引重试 |
| v1.30 | Job managedBy字段 | 外部Job控制器 |
| v1.31 | Job successPolicy GA | 成功策略控制 |

---

**工作负载选择原则**: 无状态用Deployment + 有状态用StatefulSet + 节点级用DaemonSet + 一次性用Job + 定时用CronJob
