# Job 与 CronJob 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 中级
>
> **版本说明**:
> - v1.25+ CronJob 时区支持 (spec.timeZone) GA
> - v1.26+ Job 的 pod failure policy GA
> - v1.27+ Job 的 backoffLimitPerIndex (Alpha)
> - v1.29+ Job 的 succeededIndexes 支持稀疏索引

## 概述

Job 用于运行一次性任务，确保指定数量的 Pod 成功完成；CronJob 基于时间调度周期性创建 Job。本文档覆盖 Job/CronJob 常见故障的诊断与解决方案。

---

## 第一部分：问题现象与影响分析

### 1.1 常见问题现象

#### Job 问题

| 问题类型 | 现象描述 | 错误信息示例 | 查看方式 |
|---------|---------|-------------|---------|
| Job 无法完成 | Job 状态一直不是 Complete | `active: 1, succeeded: 0` | `kubectl get job` |
| Pod 反复失败 | Pod 不断重建但都失败 | `BackoffLimitExceeded` | `kubectl describe job` |
| Job 卡住 | Pod 运行但不退出 | 长时间处于 Running | `kubectl get pods` |
| 并行执行异常 | 并行数不符合预期 | `parallelism` 与实际 Pod 数不符 | `kubectl get pods` |
| 超时失败 | Job 因超时被终止 | `DeadlineExceeded` | `kubectl describe job` |
| 资源不足 | Pod 无法调度 | `Insufficient cpu/memory` | `kubectl describe pod` |

#### CronJob 问题

| 问题类型 | 现象描述 | 错误信息示例 | 查看方式 |
|---------|---------|-------------|---------|
| 未按时触发 | 到时间点没有创建 Job | `LAST SCHEDULE` 时间异常 | `kubectl get cronjob` |
| Job 积压 | 并发 Job 数量过多 | `TooManyMissedTimes` | `kubectl get jobs` |
| 时区问题 | 执行时间与预期不符 | 实际触发时间偏移 | 对比时间戳 |
| Job 未清理 | 历史 Job 堆积 | 大量 Completed/Failed Job | `kubectl get jobs` |
| 挂起状态 | CronJob 被暂停 | `SUSPEND: True` | `kubectl get cronjob` |

### 1.2 错误信息来源

| 来源 | 查看命令 | 说明 |
|-----|---------|-----|
| Job 状态 | `kubectl get job <name>` | 完成数/并行数/失败数 |
| Job 事件 | `kubectl describe job <name>` | Job 控制器事件 |
| Pod 状态 | `kubectl get pods -l job-name=<job>` | Job 创建的 Pod |
| Pod 日志 | `kubectl logs <pod-name>` | 任务执行日志 |
| CronJob 状态 | `kubectl get cronjob <name>` | 调度时间/上次执行 |
| Controller Manager 日志 | `kubectl logs -n kube-system kube-controller-manager-*` | Job/CronJob 控制器日志 |

### 1.3 影响分析

| 故障类型 | 直接影响 | 间接影响 | 影响范围 |
|---------|---------|---------|---------|
| Job 无法完成 | 任务未执行或部分完成 | 数据处理中断，下游任务阻塞 | 依赖该任务的系统 |
| CronJob 未触发 | 定时任务未执行 | 定期数据同步/清理/备份失败 | 业务连续性 |
| Job 积压 | 资源被大量 Pod 占用 | 集群资源紧张，其他工作负载受影响 | 整个命名空间或集群 |
| 并行执行异常 | 任务执行效率低下 | 处理延迟，SLA 无法满足 | 业务时效性 |
| 历史 Job 未清理 | etcd 存储占用增加 | API Server 性能下降 | 集群稳定性 |

---

## 第二部分：排查原理与方法

### 2.1 Job 工作原理

```
┌─────────────────────────────────────────────────────────────────┐
│                       Job Controller                             │
├─────────────────────────────────────────────────────────────────┤
│  1. 创建指定数量 (completions) 的 Pod 来执行任务                 │
│  2. 支持并行执行 (parallelism) 多个 Pod                          │
│  3. Pod 失败时根据 backoffLimit 决定是否重试                     │
│  4. 可设置 activeDeadlineSeconds 限制总执行时间                  │
│  5. 完成后保留 Job 资源用于查看状态                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      关键配置参数                                │
├──────────────────┬──────────────────┬───────────────────────────┤
│  completions     │   parallelism    │    backoffLimit           │
│  (需成功完成数)   │  (并行 Pod 数)    │   (失败重试次数)          │
└──────────────────┴──────────────────┴───────────────────────────┘
```

### 2.2 CronJob 工作原理

```
┌─────────────────────────────────────────────────────────────────┐
│                     CronJob Controller                           │
├─────────────────────────────────────────────────────────────────┐
│  1. 按 schedule (cron 表达式) 定时创建 Job                       │
│  2. concurrencyPolicy 控制并发 Job 行为                          │
│  3. startingDeadlineSeconds 控制错过调度的容忍时间               │
│  4. successfulJobsHistoryLimit/failedJobsHistoryLimit 控制历史数 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    concurrencyPolicy 策略                        │
├──────────────────┬──────────────────┬───────────────────────────┤
│      Allow       │     Forbid       │      Replace              │
│  (允许并发运行)   │ (跳过新 Job)     │  (替换运行中的 Job)        │
└──────────────────┴──────────────────┴───────────────────────────┘
```

### 2.3 排查决策树

```
Job/CronJob 故障
       │
       ├─── Job 未完成？
       │         │
       │         ├─ Pod 未创建 ──→ 检查 Job 配置 / 资源配额
       │         ├─ Pod Pending ──→ 检查调度约束 / 节点资源
       │         ├─ Pod 失败重试 ──→ 检查应用日志 / 退出码
       │         └─ Pod 运行未退出 ──→ 检查应用逻辑 / 死锁
       │
       ├─── CronJob 未触发？
       │         │
       │         ├─ suspend: true ──→ 取消挂起
       │         ├─ schedule 格式错误 ──→ 修正 cron 表达式
       │         ├─ 时区偏差 ──→ 检查 timeZone 配置
       │         └─ startingDeadlineSeconds 过短 ──→ 调整或检查调度延迟
       │
       ├─── Job 积压/并发问题？
       │         │
       │         ├─ concurrencyPolicy: Allow ──→ 考虑改为 Forbid/Replace
       │         ├─ Job 执行时间过长 ──→ 优化任务或调整调度间隔
       │         └─ 资源不足 ──→ 扩容或限制并行数
       │
       └─── 历史 Job 未清理？
                 │
                 ├─ 检查 history limits ──→ 调整 successfulJobsHistoryLimit
                 └─ 手动清理 ──→ 删除历史 Job
```

### 2.4 排查命令集

#### 2.4.1 Job 基础检查

```bash
# 查看 Job 状态
kubectl get jobs -o wide

# 查看 Job 详细信息
kubectl describe job <name>

# 查看 Job YAML
kubectl get job <name> -o yaml

# 查看 Job 创建的 Pod
kubectl get pods -l job-name=<job-name>

# 查看 Pod 状态和退出码
kubectl get pods -l job-name=<job-name> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.status.containerStatuses[0].state}{"\n"}{end}'

# 查看 Pod 日志
kubectl logs job/<job-name>
kubectl logs <pod-name>
```

#### 2.4.2 CronJob 检查

```bash
# 查看 CronJob 状态
kubectl get cronjob -o wide

# 查看 CronJob 详细信息
kubectl describe cronjob <name>

# 查看 CronJob YAML
kubectl get cronjob <name> -o yaml

# 查看 CronJob 创建的 Job
kubectl get jobs -l <cronjob-label>

# 检查上次调度时间
kubectl get cronjob <name> -o jsonpath='{.status.lastScheduleTime}'

# 检查下次调度时间 (需要计算)
# 使用在线工具验证 cron 表达式
```

#### 2.4.3 失败分析

```bash
# 查看失败的 Pod
kubectl get pods -l job-name=<job-name> --field-selector=status.phase=Failed

# 查看 Pod 退出码
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}'

# 查看上一次运行的日志
kubectl logs <pod-name> --previous

# 查看 Job 失败原因
kubectl get job <name> -o jsonpath='{.status.conditions}'

# 检查 BackoffLimit
kubectl get job <name> -o jsonpath='{.spec.backoffLimit}'
```

#### 2.4.4 控制器日志

```bash
# 查看 Job 控制器日志
kubectl logs -n kube-system -l component=kube-controller-manager --tail=100 | grep -i "job\|cronjob"

# 查看特定 Job 相关日志
kubectl logs -n kube-system -l component=kube-controller-manager | grep <job-name>
```

### 2.5 排查注意事项

| 注意事项 | 说明 |
|---------|-----|
| 退出码含义 | 0=成功，非0=失败；137=OOM，143=SIGTERM |
| backoffLimit | 默认值为 6，超过后 Job 标记为 Failed |
| activeDeadlineSeconds | 从 Job 启动开始计时，包含等待调度时间 |
| 时区问题 | CronJob 默认使用 kube-controller-manager 的时区 |
| 历史保留 | 默认保留 3 个成功 Job，1 个失败 Job |
| 并发策略 | Forbid 可能导致任务跳过，Replace 会强制终止运行中的任务 |

---

## 第三部分：解决方案与风险控制

### 3.1 Job 无法完成

#### 场景 1：Pod 反复失败 (BackoffLimitExceeded)

**问题现象：**
```bash
$ kubectl describe job data-import
Events:
  Warning  BackoffLimitExceeded  Job has reached the specified backoff limit
```

**解决步骤：**

```bash
# 1. 查看 Pod 失败原因
kubectl get pods -l job-name=<job-name>
kubectl describe pod <failed-pod>

# 2. 查看应用日志
kubectl logs <failed-pod>
kubectl logs <failed-pod> --previous

# 3. 检查退出码
kubectl get pod <failed-pod> -o jsonpath='{.status.containerStatuses[0].state.terminated}'
# exitCode: 137 = OOM
# exitCode: 1 = 应用错误
# exitCode: 143 = SIGTERM

# 4. 根据原因修复

# 4a. OOM 问题 - 增加内存
kubectl delete job <job-name>
# 修改 Job YAML 增加 resources.limits.memory

# 4b. 应用错误 - 修复代码或配置
kubectl get configmap <cm-name> -o yaml
kubectl get secret <secret-name> -o yaml

# 4c. 需要增加重试次数
kubectl patch job <job-name> --type='json' -p='[{"op": "replace", "path": "/spec/backoffLimit", "value": 10}]'
# 注意：backoffLimit 不可动态修改已存在的 Job，需删除重建

# 5. 重新创建 Job
kubectl create -f job.yaml
```

#### 场景 2：Job 超时 (DeadlineExceeded)

**问题现象：**
```bash
$ kubectl get job
NAME          COMPLETIONS   DURATION   AGE
data-export   0/1           2h         2h

$ kubectl describe job data-export
  Warning  DeadlineExceeded  Job was active longer than specified deadline
```

**解决步骤：**

```bash
# 1. 查看 activeDeadlineSeconds 设置
kubectl get job <job-name> -o jsonpath='{.spec.activeDeadlineSeconds}'

# 2. 分析任务为何超时
kubectl logs job/<job-name>

# 3. 方案 A: 增加超时时间
# 需要删除重建 Job
kubectl delete job <job-name>
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: <job-name>
spec:
  activeDeadlineSeconds: 7200  # 增加到 2 小时
  template:
    spec:
      ...
EOF

# 4. 方案 B: 优化任务执行时间
# - 增加并行度
# - 优化代码逻辑
# - 减少处理数据量

# 5. 方案 C: 拆分为多个小任务
```

#### 场景 3：Pod 运行但不退出

**问题现象：**
```bash
$ kubectl get pods -l job-name=my-job
NAME           READY   STATUS    RESTARTS   AGE
my-job-abc12   1/1     Running   0          2h
```

**解决步骤：**

```bash
# 1. 检查 Pod 内进程状态
kubectl exec <pod-name> -- ps aux

# 2. 检查是否有死锁或阻塞
kubectl exec <pod-name> -- cat /proc/1/stack  # 如果可用

# 3. 查看实时日志
kubectl logs <pod-name> -f

# 4. 检查资源使用
kubectl top pod <pod-name>

# 5. 如果是代码问题，需要修复后重建
kubectl delete job <job-name>

# 6. 设置 activeDeadlineSeconds 避免无限运行
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: <job-name>
spec:
  activeDeadlineSeconds: 3600  # 1 小时超时
  template:
    ...
EOF
```

---

### 3.2 CronJob 调度问题

#### 场景 1：CronJob 未按时触发

**问题现象：**
```bash
$ kubectl get cronjob
NAME       SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
backup     0 2 * * *     False     0        25h             7d
# LAST SCHEDULE 显示 25h 前，说明今天的调度未触发
```

**解决步骤：**

```bash
# 1. 检查 CronJob 状态
kubectl describe cronjob <name>

# 2. 验证 cron 表达式
# 使用在线工具: https://crontab.guru/
# 0 2 * * * = 每天凌晨 2:00

# 3. 检查时区设置 (Kubernetes 1.24+)
kubectl get cronjob <name> -o jsonpath='{.spec.timeZone}'

# 4. 检查 kube-controller-manager 时区
kubectl exec -n kube-system kube-controller-manager-<node> -- date

# 5. 检查 startingDeadlineSeconds
kubectl get cronjob <name> -o jsonpath='{.spec.startingDeadlineSeconds}'
# 如果设置过短且调度有延迟，可能跳过执行

# 6. 检查是否被挂起
kubectl get cronjob <name> -o jsonpath='{.spec.suspend}'

# 7. 手动触发测试
kubectl create job --from=cronjob/<cronjob-name> <manual-job-name>

# 8. 查看控制器日志
kubectl logs -n kube-system -l component=kube-controller-manager | grep cronjob
```

#### 场景 2：配置时区

**Kubernetes 1.24+ 支持 timeZone 字段：**

```bash
# 设置时区
kubectl patch cronjob <name> --type='json' -p='[{"op": "add", "path": "/spec/timeZone", "value": "Asia/Shanghai"}]'

# 验证时区
kubectl get cronjob <name> -o jsonpath='{.spec.timeZone}'
```

**旧版本 Kubernetes 解决方案：**

```yaml
# 方案 1: 调整 cron 表达式补偿时差
# 如果 controller-manager 使用 UTC，要在 CST 02:00 执行
# 需要设置为 UTC 18:00 (前一天) = "0 18 * * *"

# 方案 2: 在容器内处理时区
spec:
  template:
    spec:
      containers:
      - name: job
        env:
        - name: TZ
          value: "Asia/Shanghai"
```

#### 场景 3：Job 积压

**问题现象：**
```bash
$ kubectl get jobs
NAME                    COMPLETIONS   DURATION   AGE
backup-27893400         0/1           5m         5m
backup-27893340         0/1           65m        65m
backup-27893280         1/1           45m        125m
# 多个 Job 同时存在
```

**解决步骤：**

```bash
# 1. 检查并发策略
kubectl get cronjob <name> -o jsonpath='{.spec.concurrencyPolicy}'

# 2. 修改为 Forbid (跳过新调度) 或 Replace (替换运行中的)
kubectl patch cronjob <name> --type='json' -p='[{"op": "replace", "path": "/spec/concurrencyPolicy", "value": "Forbid"}]'

# 3. 清理积压的 Job
kubectl delete jobs -l <cronjob-label> --field-selector=status.successful=0

# 4. 优化任务执行时间
# - 增加资源配额
# - 优化代码逻辑
# - 调整调度间隔

# 5. 设置历史保留限制
kubectl patch cronjob <name> --type='json' -p='[
  {"op": "replace", "path": "/spec/successfulJobsHistoryLimit", "value": 3},
  {"op": "replace", "path": "/spec/failedJobsHistoryLimit", "value": 1}
]'
```

#### 场景 4：取消挂起状态

```bash
# 检查是否挂起
kubectl get cronjob <name> -o jsonpath='{.spec.suspend}'

# 取消挂起
kubectl patch cronjob <name> -p '{"spec":{"suspend":false}}'

# 立即触发一次
kubectl create job --from=cronjob/<name> <job-name>-manual
```

---

### 3.3 并行执行问题

#### 场景 1：配置并行任务

```bash
# 查看当前并行配置
kubectl get job <name> -o jsonpath='{.spec.parallelism}'
kubectl get job <name> -o jsonpath='{.spec.completions}'

# 场景: 需要处理 100 个任务，并行 10 个
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-process
spec:
  completions: 100    # 总共需要成功 100 次
  parallelism: 10     # 同时运行 10 个 Pod
  template:
    spec:
      containers:
      - name: worker
        image: myapp:v1
        command: ["./process", "--task-id", "\$(JOB_COMPLETION_INDEX)"]
        env:
        - name: JOB_COMPLETION_INDEX
          valueFrom:
            fieldRef:
              fieldPath: metadata.annotations['batch.kubernetes.io/job-completion-index']
      restartPolicy: Never
EOF
```

#### 场景 2：使用 Indexed Job (Kubernetes 1.21+)

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: indexed-job
spec:
  completions: 5
  parallelism: 5
  completionMode: Indexed  # 启用索引模式
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command:
        - /bin/sh
        - -c
        - echo "Processing index $JOB_COMPLETION_INDEX"
        env:
        - name: JOB_COMPLETION_INDEX
          valueFrom:
            fieldRef:
              fieldPath: metadata.annotations['batch.kubernetes.io/job-completion-index']
      restartPolicy: Never
```

---

### 3.4 资源和清理问题

#### 场景 1：清理历史 Job

```bash
# 查看所有 Job
kubectl get jobs

# 删除已完成的 Job
kubectl delete jobs --field-selector=status.successful=1

# 删除失败的 Job
kubectl delete jobs --field-selector=status.successful=0

# 删除特定 CronJob 的所有历史 Job
kubectl delete jobs -l <cronjob-label>

# 批量清理超过 N 天的 Job (需要 jq)
kubectl get jobs -o json | jq -r '.items[] | select(.status.completionTime != null) | select((now - (.status.completionTime | fromdateiso8601)) > 86400*7) | .metadata.name' | xargs kubectl delete job
```

#### 场景 2：配置自动清理

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup
spec:
  schedule: "0 2 * * *"
  successfulJobsHistoryLimit: 3   # 保留 3 个成功的 Job
  failedJobsHistoryLimit: 1       # 保留 1 个失败的 Job
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 86400  # Job 完成 24 小时后自动删除
      template:
        spec:
          containers:
          - name: backup
            image: backup:v1
          restartPolicy: OnFailure
```

#### 场景 3：Job TTL 自动清理 (Kubernetes 1.23+)

```bash
# 为现有 Job 设置 TTL (注意：已完成的 Job 无法修改)
# 需要在 Job 创建时设置
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: cleanup-job
spec:
  ttlSecondsAfterFinished: 3600  # 完成后 1 小时自动删除
  template:
    spec:
      containers:
      - name: task
        image: busybox
        command: ["echo", "done"]
      restartPolicy: Never
EOF
```

---

### 3.5 完整示例

#### Job 示例

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-migration
spec:
  # 完成配置
  completions: 1          # 需要成功完成 1 次
  parallelism: 1          # 并行数
  backoffLimit: 3         # 失败重试次数
  activeDeadlineSeconds: 3600  # 最大运行时间 1 小时
  ttlSecondsAfterFinished: 86400  # 完成后 24 小时清理
  
  template:
    spec:
      restartPolicy: OnFailure  # 或 Never
      
      containers:
      - name: migrator
        image: myapp/migrator:v1
        
        command:
        - /migrate
        - --source=old-db
        - --target=new-db
        
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
        
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        
        volumeMounts:
        - name: config
          mountPath: /etc/config
      
      volumes:
      - name: config
        configMap:
          name: migration-config
```

#### CronJob 示例

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-backup
spec:
  # 调度配置
  schedule: "0 2 * * *"           # 每天凌晨 2:00
  timeZone: "Asia/Shanghai"       # 时区 (1.24+)
  
  # 并发策略
  concurrencyPolicy: Forbid       # 禁止并发
  startingDeadlineSeconds: 3600   # 错过调度的容忍时间
  suspend: false                  # 是否挂起
  
  # 历史保留
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  
  jobTemplate:
    spec:
      backoffLimit: 2
      activeDeadlineSeconds: 7200
      ttlSecondsAfterFinished: 172800  # 48 小时后清理
      
      template:
        spec:
          restartPolicy: OnFailure
          
          containers:
          - name: backup
            image: backup-tool:v1
            
            command:
            - /backup.sh
            - --database=production
            - --destination=s3://backups/
            
            env:
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: aws-secret
                  key: access-key
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: aws-secret
                  key: secret-key
            
            resources:
              requests:
                cpu: 200m
                memory: 256Mi
              limits:
                cpu: 500m
                memory: 512Mi
```

---

### 3.6 安全生产风险提示

| 操作 | 风险等级 | 风险说明 | 建议 |
|-----|---------|---------|-----|
| 删除运行中的 Job | 中 | 任务中断，可能数据不完整 | 等待完成或确认可中断后删除 |
| 修改 CronJob schedule | 低 | 可能导致下次执行时间变化 | 验证新 cron 表达式，确认预期时间 |
| 设置 concurrencyPolicy: Replace | 中 | 强制终止运行中的 Job | 确保任务支持中断，或使用 Forbid |
| 降低 backoffLimit | 中 | 减少重试机会，可能过早失败 | 根据任务特性合理设置 |
| 设置过短的 activeDeadlineSeconds | 中 | 正常任务可能超时被终止 | 预留足够执行时间，考虑重试开销 |
| 清理历史 Job | 低 | 丢失历史执行记录 | 确认日志已收集后清理 |
| 批量创建 Job | 中 | 可能导致资源争抢 | 控制并行度，使用资源配额 |

---

## 附录

### 常用排查命令速查

```bash
# Job 状态
kubectl get jobs -o wide
kubectl describe job <name>
kubectl get job <name> -o yaml

# CronJob 状态
kubectl get cronjob -o wide
kubectl describe cronjob <name>
kubectl get cronjob <name> -o yaml

# Pod 状态
kubectl get pods -l job-name=<job>
kubectl logs job/<job-name>
kubectl logs <pod-name> --previous

# 手动触发 CronJob
kubectl create job --from=cronjob/<name> <job-name>-manual

# 清理操作
kubectl delete jobs --field-selector=status.successful=1
kubectl delete job <name>

# 更新操作
kubectl patch cronjob <name> -p '{"spec":{"suspend":true}}'
kubectl patch cronjob <name> -p '{"spec":{"suspend":false}}'
```

### Cron 表达式参考

```
┌───────────── 分钟 (0 - 59)
│ ┌───────────── 小时 (0 - 23)
│ │ ┌───────────── 日 (1 - 31)
│ │ │ ┌───────────── 月 (1 - 12)
│ │ │ │ ┌───────────── 星期 (0 - 6) (周日 = 0)
│ │ │ │ │
* * * * *

常用示例:
0 * * * *      每小时整点
0 2 * * *      每天凌晨 2:00
0 2 * * 0      每周日凌晨 2:00
0 2 1 * *      每月 1 日凌晨 2:00
*/15 * * * *   每 15 分钟
0 9-17 * * 1-5 工作日 9:00-17:00 每小时
```

### 相关文档

- [Pod 故障排查](./01-pod-troubleshooting.md)
- [资源配额故障排查](../07-resources-scheduling/01-resources-quota-troubleshooting.md)
- [调度故障排查](../01-control-plane/03-scheduler-troubleshooting.md)
