# Kubernetes Workload 生产环境运维专家培训

> **适用版本**: Kubernetes v1.26-v1.32 | **文档类型**: 专家级培训材料  
> **目标受众**: 生产环境运维专家、SRE、平台架构师  
> **培训时长**: 3-4小时 | **难度等级**: ⭐⭐⭐⭐⭐ 专家级  
> **学习目标**: 掌握企业级工作负载管理的核心技能与最佳实践  

---

## 📚 培训大纲与时间规划

### 🔰 第一阶段：基础理论篇 (60分钟)
1. **工作负载基础架构原理** (20分钟)
   - 控制器模式深度解析
   - 工作负载类型对比分析
   - 生命周期管理机制

2. **核心控制器工作机制** (25分钟)
   - Deployment控制器实现原理
   - StatefulSet有序性保障
   - DaemonSet节点部署策略

3. **调度策略与资源管理** (15分钟)
   - 调度器工作原理
   - 资源请求与限制配置
   - 亲和性与反亲和性策略

### ⚡ 第二阶段：生产实践篇 (90分钟)
4. **企业级部署配置实践** (30分钟)
   - 高可用应用部署方案
   - 多环境配置管理
   - 滚动更新策略优化

5. **自动扩缩容体系构建** (25分钟)
   - HPA/VPA配置与调优
   - 自定义指标扩缩容
   - 集群自动伸缩配置

6. **监控告警体系完善** (35分钟)
   - 应用健康检查配置
   - Prometheus指标采集
   - 关键业务告警设置

### 🛠️ 第三阶段：故障处理篇 (60分钟)
7. **常见故障诊断与处理** (25分钟)
   - Pod启动失败问题排查
   - 应用性能瓶颈分析
   - 资源不足故障处理

8. **应急响应与恢复** (20分钟)
   - 应用故障应急预案
   - 快速回滚操作流程
   - 灾难恢复策略

9. **预防性维护措施** (15分钟)
   - 应用健康检查机制
   - 自动化运维脚本
   - 定期巡检清单

### 🎯 第四阶段：高级应用篇 (30分钟)
10. **安全加固与合规** (15分钟)
    - 应用安全配置策略
    - 网络策略与访问控制
    - 安全最佳实践

11. **总结与答疑** (15分钟)
    - 关键要点回顾
    - 实际问题解答
    - 后续学习建议

---

## 🎯 学习成果预期

完成本次培训后，学员将能够：
- ✅ 独立设计和部署企业级应用架构
- ✅ 快速诊断和解决复杂的应用问题
- ✅ 制定完整的自动扩缩容和监控方案
- ✅ 实施系统性的应用安全管理策略
- ✅ 建立标准化的运维操作和应急响应流程

---

## 📖 文档约定

### 图例说明
```
📘 理论知识点
⚡ 实践操作步骤
⚠️ 注意事项
💡 最佳实践
🔧 故障排查
📈 性能调优
🛡️ 安全配置
```

### 代码块标识
```yaml
# Deployment 配置示例
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: example
  template:
    metadata:
      labels:
        app: example
    spec:
      containers:
      - name: app
        image: nginx:1.20
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
```

```bash
# 命令行操作示例
kubectl get deployments,pods -A
```

### 表格规范
| 配置项 | 默认值 | 推荐值 | 说明 |
|--------|--------|--------|------|
| maxSurge | 25% | 1 | 滚动更新最大激增数 |

---

*本文档遵循企业级技术文档标准，内容经过生产环境验证*

## 🔰 第一阶段：基础理论篇

### 1. 工作负载基础架构原理

#### 📘 控制器模式深度解析

**控制器模式架构：**
```
期望状态 → 控制器 → 当前状态 → 调谐循环 → 期望状态
```

**核心组件协作：**
```go
// 控制器核心逻辑伪代码
func (c *Controller) reconcile(key string) error {
    // 1. 获取当前对象状态
    obj, err := c.informer.GetByKey(key)
    if err != nil {
        return err
    }
    
    // 2. 计算期望状态
    desiredState := c.computeDesiredState(obj)
    
    // 3. 获取当前状态
    currentState := c.getCurrentState(obj)
    
    // 4. 执行调谐操作
    if !reflect.DeepEqual(currentState, desiredState) {
        return c.syncHandler(obj, desiredState)
    }
    
    return nil
}
```

**控制器生命周期：**
```
对象创建 → 初始化 → 持续监控 → 状态调谐 → 对象终止
```

#### ⚡ 工作负载类型对比分析

**Kubernetes工作负载类型对比：**

| 工作负载类型 | 适用场景 | 特点 | 扩展性 | 数据持久性 |
|-------------|----------|------|--------|------------|
| Deployment | 无状态应用 | 自动滚动更新 | 高 | 无 |
| StatefulSet | 有状态应用 | 有序部署/删除 | 中 | 高 |
| DaemonSet | 节点级服务 | 每节点一个实例 | 低 | 中 |
| Job | 批处理任务 | 一次性执行 | 无 | 无 |
| CronJob | 定时任务 | 周期性执行 | 无 | 无 |

#### 💡 生命周期管理机制

**Pod生命周期状态流转：**
```
Pending → Running → Succeeded/Failed → Unknown
```

**详细状态说明：**
- **Pending**: Pod已被接受但未完全运行
- **Running**: Pod已绑定到节点并正在运行
- **Succeeded**: Pod成功完成退出
- **Failed**: Pod执行失败退出
- **Unknown**: Pod状态未知

### 2. 核心控制器工作机制

#### 📘 Deployment控制器实现原理

**Deployment控制器架构：**
```
Deployment → ReplicaSet → Pod
```

**滚动更新机制：**
```yaml
# Deployment滚动更新配置
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: example
  template:
    metadata:
      labels:
        app: example
    spec:
      containers:
      - name: app
        image: nginx:1.20
        ports:
        - containerPort: 80
```

**更新过程详解：**
```
1. 创建新的ReplicaSet (RS-new)
2. 逐步增加RS-new副本数
3. 同时减少旧ReplicaSet (RS-old)副本数
4. 直到RS-new达到期望副本数，RS-old为0
```

#### ⚡ StatefulSet有序性保障

**StatefulSet特性：**
- 稳定的网络标识符
- 稳定的持久存储
- 有序部署和扩展
- 有序删除和终止

**配置示例：**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-cluster
spec:
  serviceName: mysql-headless
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "password123"
  volumeClaimTemplates:
  - metadata:
      name: mysql-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 100Gi
```

#### 💡 DaemonSet节点部署策略

**DaemonSet部署机制：**
```
每个符合条件的节点 → 一个Pod实例
```

**节点选择配置：**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-elasticsearch
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      tolerations:
      # 允许调度到master节点
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: fluentd-elasticsearch
        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
```

### 3. 调度策略与资源管理

#### 📘 调度器工作原理

**调度流程：**
```
Pod创建 → 调度队列 → 预选阶段 → 优选阶段 → 绑定阶段 → Pod调度完成
```

**调度器架构：**
```go
// 调度器核心流程
func (sched *Scheduler) scheduleOne(ctx context.Context) {
    // 1. 从队列获取待调度Pod
    pod := sched.NextPod()
    
    // 2. 预选阶段 - 过滤不合适的节点
    filteredNodes := sched.predicates.Run(pod, allNodes)
    
    // 3. 优选阶段 - 为节点打分
    scoredNodes := sched.priorities.Run(pod, filteredNodes)
    
    // 4. 选择最优节点
    selectedNode := sched.selectHost(scoredNodes)
    
    // 5. 绑定Pod到节点
    sched.bind(pod, selectedNode)
}
```

#### ⚡ 资源请求与限制配置

**资源配置最佳实践：**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
spec:
  containers:
  - name: app
    image: nginx
    resources:
      # 资源请求 - 保证最小资源
      requests:
        memory: "64Mi"
        cpu: "250m"
      # 资源限制 - 防止资源耗尽
      limits:
        memory: "128Mi"
        cpu: "500m"
    # QoS类别影响调度和驱逐策略
```

**QoS类别说明：**
- **Guaranteed**: requests = limits（最高优先级）
- **Burstable**: requests < limits（中等优先级）
- **BestEffort**: 无资源限制（最低优先级）

#### 💡 亲和性与反亲和性策略

**节点亲和性配置：**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: affinity-demo
spec:
  replicas: 3
  template:
    spec:
      # 节点亲和性
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values:
                - amd64
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            preference:
              matchExpressions:
              - key: disk-type
                operator: In
                values:
                - ssd
        # Pod亲和性
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - cache
            topologyKey: kubernetes.io/hostname
        # Pod反亲和性
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - web
              topologyKey: kubernetes.io/hostname
```

## ⚡ 第二阶段：生产实践篇

### 4. 企业级部署配置实践

#### 📘 高可用应用部署方案

**多区域高可用架构：**
```
Region A (主) ── 多活部署 ── Region B (备)
     │                         │
     ▼                         ▼
  多可用区部署              多可用区部署
```

**高可用Deployment配置：**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ha-application
  namespace: production
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: ha-app
  template:
    metadata:
      labels:
        app: ha-app
        version: v1.2.0
    spec:
      # 多可用区分布
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: ha-app
      # 节点亲和性
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-type
                operator: In
                values:
                - production
      containers:
      - name: app
        image: company/app:v1.2.0
        ports:
        - containerPort: 8080
        # 健康检查配置
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        # 资源配置
        resources:
          requests:
            memory: "256Mi"
            cpu: "500m"
          limits:
            memory: "512Mi"
            cpu: "1000m"
```

#### ⚡ 多环境配置管理

**ConfigMap和Secret管理：**
```yaml
# 多环境配置管理
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: production
data:
  # 应用配置
  app.properties: |
    server.port=8080
    logging.level=INFO
    database.url=jdbc:mysql://mysql-prod:3306/app
  # 环境变量
  ENV: production
  VERSION: v1.2.0
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: production
type: Opaque
data:
  # 敏感信息需要base64编码
  database.password: cGFzc3dvcmQxMjM=
  api.key: YWJjZGVmZ2hpams=
```

**环境变量注入：**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
spec:
  template:
    spec:
      containers:
      - name: app
        image: company/app:v1.2.0
        envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: app-secrets
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
```

#### 💡 滚动更新策略优化

**渐进式发布配置：**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: progressive-deployment
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      # 最大不可用Pod数量
      maxUnavailable: 1
      # 最大超出期望副本数
      maxSurge: 2
  minReadySeconds: 30
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: progressive-app
  template:
    metadata:
      labels:
        app: progressive-app
        version: v2.0.0
    spec:
      containers:
      - name: app
        image: company/app:v2.0.0
        # 启动探针确保应用完全启动
        startupProbe:
          httpGet:
            path: /health
            port: 8080
          failureThreshold: 30
          periodSeconds: 10
```

### 5. 自动扩缩容体系构建

#### 📘 HPA/VPA配置与调优

**Horizontal Pod Autoscaler配置：**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app-deployment
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "100"
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
      - type: Pods
        value: 4
        periodSeconds: 60
      selectPolicy: Max
```

**Vertical Pod Autoscaler配置：**
```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: app-vpa
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: app-deployment
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: app
      maxAllowed:
        cpu: 2
        memory: "4Gi"
      minAllowed:
        cpu: "100m"
        memory: "128Mi"
```

#### ⚡ 自定义指标扩缩容

**Prometheus Adapter配置：**
```yaml
# 自定义指标配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: adapter-config
  namespace: custom-metrics
data:
  config.yaml: |
    rules:
    - seriesQuery: 'http_requests_total{namespace!="",pod!=""}'
      resources: {overrides: {namespace: {resource: "namespace"}, pod: {resource: "pod"}}}
      name:
        matches: "^(.*)_total"
        as: "${1}_per_second"
      metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[2m])) by (<<.GroupBy>>)'
```

**基于自定义指标的HPA：**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: custom-metric-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "50"
  - type: External
    external:
      metric:
        name: queue_messages_ready
        selector:
          matchLabels:
            queue: worker-tasks
      target:
        type: Value
        value: "30"
```

#### 💡 集群自动伸缩配置

**Cluster Autoscaler配置：**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.21.0
        name: cluster-autoscaler
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/my-cluster
        - --balance-similar-node-groups
        - --scale-down-delay-after-add=10m
        - --scale-down-unneeded-time=10m
        - --scale-down-utilization-threshold=0.5
        env:
        - name: AWS_REGION
          value: us-west-2
```

### 6. 监控告警体系完善

#### 📘 应用健康检查配置

**多层次健康检查：**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-check-app
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: app
        image: company/app:latest
        ports:
        - containerPort: 8080
        # 启动探针 - 应用启动检查
        startupProbe:
          httpGet:
            path: /startup
            port: 8080
          failureThreshold: 30
          periodSeconds: 10
        # 存活探针 - 应用健康检查
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        # 就绪探针 - 服务可用性检查
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
```

#### ⚡ Prometheus指标采集

**应用指标暴露：**
```yaml
# ServiceMonitor配置
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: app-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    relabelings:
    - sourceLabels: [__meta_kubernetes_pod_name]
      targetLabel: instance
    metricRelabelings:
    - sourceLabels: [__name__]
      regex: 'app_(.*)'
      targetLabel: __name__
      replacement: 'myapp_$1'
```

**应用指标示例：**
```go
// Go应用指标示例
import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    httpRequestTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "app_http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )
    httpRequestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "app_http_request_duration_seconds",
            Help:    "HTTP request duration in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "endpoint"},
    )
)

func init() {
    prometheus.MustRegister(httpRequestTotal)
    prometheus.MustRegister(httpRequestDuration)
}
```

#### 💡 关键业务告警设置

**AlertManager规则配置：**
```yaml
groups:
- name: application.rules
  rules:
  - alert: ApplicationDown
    expr: up{job="application"} == 0
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "应用服务不可用"
      description: "应用 {{ $labels.instance }} 已经宕机超过2分钟"

  - alert: HighErrorRate
    expr: rate(app_http_requests_total{status=~"5.."}[5m]) / rate(app_http_requests_total[5m]) > 0.05
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "错误率过高 ({{ $value | humanizePercentage }})"
      description: "应用错误率超过5%，当前为 {{ $value | humanizePercentage }}"

  - alert: HighLatency
    expr: histogram_quantile(0.99, rate(app_http_request_duration_seconds_bucket[5m])) > 2
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "高延迟 ({{ $value }}s)"
      description: "99%的请求延迟超过2秒，当前为 {{ $value }}秒"

  - alert: LowAvailability
    expr: avg_over_time(up{job="application"}[1h]) < 0.99
    for: 10m
    labels:
      severity: critical
    annotations:
      summary: "可用性低于SLA"
      description: "应用1小时可用性低于99%，当前为 {{ $value | humanizePercentage }}"
```

## 🛠️ 第三阶段：故障处理篇

### 7. 常见故障诊断与处理

#### 🔧 Pod启动失败问题排查

**诊断流程图：**
```
Pod启动失败
    │
    ├── 检查Pod状态和事件
    │   ├── kubectl describe pod <pod-name>
    │   └── kubectl get events --field-selector involvedObject.name=<pod-name>
    │
    ├── 验证资源配置
    │   ├── 检查资源请求和限制
    │   └── 验证节点资源可用性
    │
    ├── 检查镜像和存储
    │   ├── 镜像拉取状态
    │   └── 存储卷挂载情况
    │
    └── 应用层面检查
        ├── 健康检查配置
        └── 应用日志分析
```

**常用诊断命令：**
```bash
# 1. 检查Pod详细状态
kubectl describe pod <pod-name> -n <namespace>

# 2. 查看Pod日志
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous  # 查看上一个容器实例日志

# 3. 检查资源配额
kubectl describe quota -n <namespace>
kubectl describe limitrange -n <namespace>

# 4. 验证节点资源
kubectl describe nodes | grep -A 5 "Allocated resources"

# 5. 检查镜像拉取状态
kubectl get events --field-selector involvedObject.name=<pod-name> | grep Pulling
```

#### ⚡ 应用性能瓶颈分析

**性能分析工具链：**
```bash
# 1. 资源使用情况监控
kubectl top pods -n <namespace>
kubectl top nodes

# 2. 应用内部性能分析
kubectl exec -it <pod-name> -n <namespace> -- top
kubectl exec -it <pod-name> -n <namespace> -- ps aux

# 3. 网络性能分析
kubectl exec -it <pod-name> -n <namespace> -- netstat -an
kubectl exec -it <pod-name> -n <namespace> -- ss -tuln

# 4. Java应用堆栈分析
kubectl exec -it <java-pod> -n <namespace> -- jstack 1
kubectl exec -it <java-pod> -n <namespace> -- jstat -gc 1

# 5. 内存分析
kubectl exec -it <pod-name> -n <namespace> -- free -m
kubectl exec -it <pod-name> -n <namespace> -- df -h
```

#### 💡 资源不足故障处理

**资源不足诊断和处理：**
```bash
# 1. 识别资源不足的Pod
kubectl get pods -A | grep -E "(Evicted|OOMKilled|Pending)"

# 2. 检查节点资源压力
kubectl describe nodes | grep -A 10 "Conditions" | grep -E "(MemoryPressure|DiskPressure)"

# 3. 临时解决方案 - 调整资源限制
kubectl patch deployment <deployment-name> -n <namespace> -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "app",
          "resources": {
            "requests": {
              "memory": "128Mi",
              "cpu": "100m"
            },
            "limits": {
              "memory": "256Mi",
              "cpu": "200m"
            }
          }
        }]
      }
    }
  }
}'

# 4. 长期解决方案 - 集群扩容
kubectl autoscale deployment <deployment-name> -n <namespace> --cpu-percent=70 --min=3 --max=10
```

### 8. 应急响应与恢复

#### 📘 应用故障应急预案

**紧急恢复流程：**
```bash
# 1. 快速故障确认
kubectl get pods -n <namespace> | grep -E "(CrashLoopBackOff|Error|Pending)"
kubectl get deployments -n <namespace> | grep -v "AVAILABLE"

# 2. 临时解决方案 - 回滚到稳定版本
kubectl rollout undo deployment/<deployment-name> -n <namespace>
kubectl rollout status deployment/<deployment-name> -n <namespace> --timeout=300s

# 3. 应急重启策略
kubectl delete pods -n <namespace> -l app=<app-label>
kubectl scale deployment <deployment-name> -n <namespace> --replicas=0
kubectl scale deployment <deployment-name> -n <namespace> --replicas=3

# 4. 验证服务恢复
kubectl get svc <service-name> -n <namespace> -o wide
curl -s http://<service-ip>:<port>/health | jq .
```

**应急配置文件：**
```yaml
# 应急部署配置
apiVersion: apps/v1
kind: Deployment
metadata:
  name: emergency-deployment
  namespace: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: emergency-app
  template:
    metadata:
      labels:
        app: emergency-app
    spec:
      containers:
      - name: app
        image: company/emergency-app:latest
        ports:
        - containerPort: 8080
        # 简化健康检查
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 30
        # 最小资源配置
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

#### ⚡ 快速回滚操作流程

**5分钟应急响应清单：**
```markdown
## 应用紧急故障处理清单 ⏱️

✅ **第1分钟**: 确认故障范围和影响
- 检查受影响的服务和用户
- 确认故障严重程度和影响范围

✅ **第2-3分钟**: 实施临时缓解措施
- 执行版本回滚操作
- 启用备用服务实例
- 配置流量切换

✅ **第4分钟**: 执行根本原因修复
- 修复配置文件错误
- 重启故障应用实例
- 恢复正确的环境变量

✅ **第5分钟**: 验证服务恢复正常
- 测试关键业务功能
- 监控应用性能指标
- 确认用户体验正常
```

#### 💡 灾难恢复策略

**DR恢复计划：**
```bash
#!/bin/bash
# 应用灾难恢复脚本

# 1. 评估损坏范围
kubectl get deployments,pods,services -n production > damage-assessment.txt

# 2. 激活备用环境
kubectl config use-context backup-cluster

# 3. 恢复关键应用
./deploy-critical-applications.sh

# 4. 数据同步恢复
./restore-application-data.sh

# 5. 验证业务连续性
./validate-business-functions.sh
```

### 9. 预防性维护措施

#### 📘 应用健康检查机制

**自动化健康检查脚本：**
```bash
#!/bin/bash
# 应用健康检查脚本

NAMESPACE="production"
APP_LABEL="app=myapp"

# 1. Pod状态检查
UNHEALTHY_PODS=$(kubectl get pods -n $NAMESPACE -l $APP_LABEL | grep -E "(CrashLoopBackOff|Error|Pending)" | wc -l)
if [ $UNHEALTHY_PODS -gt 0 ]; then
    echo "❌ 发现 $UNHEALTHY_PODS 个不健康的Pod"
fi

# 2. 资源使用检查
HIGH_CPU_PODS=$(kubectl top pods -n $NAMESPACE -l $APP_LABEL | awk '$2 > 80 {print $1}')
if [ ! -z "$HIGH_CPU_PODS" ]; then
    echo "⚠️ 以下Pod CPU使用率超过80%:"
    echo "$HIGH_CPU_PODS"
fi

# 3. 副本数检查
DESIRED_REPLICAS=$(kubectl get deployment -n $NAMESPACE -l $APP_LABEL -o jsonpath='{.items[0].spec.replicas}')
AVAILABLE_REPLICAS=$(kubectl get deployment -n $NAMESPACE -l $APP_LABEL -o jsonpath='{.items[0].status.availableReplicas}')
if [ "$AVAILABLE_REPLICAS" -lt "$DESIRED_REPLICAS" ]; then
    echo "⚠️ 副本数不足: $AVAILABLE_REPLICAS/$DESIRED_REPLICAS"
fi

# 4. 健康检查验证
kubectl get pods -n $NAMESPACE -l $APP_LABEL -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' | \
    grep -v true && echo "❌ 发现未就绪的容器"

echo "✅ 应用健康检查完成"
```

#### ⚡ 自动化运维脚本

**日常维护脚本集合：**
```bash
#!/bin/bash
# 应用日常维护脚本

NAMESPACE="production"

# 函数：清理完成的Job
cleanup_completed_jobs() {
    echo "🧹 清理已完成的Job..."
    kubectl delete jobs --field-selector status.successful=1 -n $NAMESPACE
}

# 函数：滚动重启应用
rolling_restart() {
    echo "🔄 执行滚动重启..."
    DEPLOYMENTS=$(kubectl get deployments -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
    for deployment in $DEPLOYMENTS; do
        kubectl rollout restart deployment/$deployment -n $NAMESPACE
        kubectl rollout status deployment/$deployment -n $NAMESPACE --timeout=300s
    done
}

# 函数：备份应用配置
backup_configs() {
    echo "💾 备份应用配置..."
    kubectl get deployments,configmaps,secrets -n $NAMESPACE -o yaml > app-config-backup-$(date +%Y%m%d-%H%M%S).yaml
}

# 函数：性能基准测试
performance_benchmark() {
    echo "📊 执行性能基准测试..."
    kubectl run benchmark --image=busybox --rm -it -- sh -c "
        for i in \$(seq 1 100); do
            curl -s -w '%{time_total}\n' -o /dev/null http://myapp-service.$NAMESPACE.svc.cluster.local/health
        done
    "
}

# 主菜单
case "${1:-menu}" in
    "cleanup")
        cleanup_completed_jobs
        ;;
    "restart")
        rolling_restart
        ;;
    "backup")
        backup_configs
        ;;
    "benchmark")
        performance_benchmark
        ;;
    "menu"|*)
        echo "应用维护工具"
        echo "用法: $0 {cleanup|restart|backup|benchmark}"
        ;;
esac
```

#### 💡 定期巡检清单

**月度巡检检查表：**
```markdown
# 应用月度巡检清单 📋

## 🔍 基础设施检查
- [ ] 应用Pod运行状态正常
- [ ] Deployment副本数符合预期
- [ ] 资源使用率在合理范围内
- [ ] 健康检查配置正确

## 📊 性能指标检查
- [ ] 应用响应时间 < SLA要求
- [ ] 错误率 < 0.1%
- [ ] CPU/内存使用率 < 80%
- [ ] 自动扩缩容功能正常

## 🔧 配置合规检查
- [ ] 应用配置符合标准
- [ ] 安全策略配置完整
- [ ] 监控告警规则有效
- [ ] 备份配置最新

## 🛡️ 安全检查
- [ ] 镜像安全扫描通过
- [ ] 访问控制策略生效
- [ ] 安全补丁及时更新
- [ ] 日志审计功能正常

## 📈 容量规划
- [ ] 应用负载增长趋势分析
- [ ] 资源需求评估
- [ ] 性能瓶颈识别
- [ ] 扩容计划制定
```

## 🎯 第四阶段：高级应用篇

### 10. 安全加固与合规

#### 🛡️ 应用安全配置策略

**Pod安全策略配置：**
```yaml
# Pod安全策略
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
  - ALL
  volumes:
  - configMap
  - emptyDir
  - projected
  - secret
  - downwardAPI
  - persistentVolumeClaim
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: MustRunAsNonRoot
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: MustRunAs
    ranges:
    - min: 1
      max: 65535
  fsGroup:
    rule: MustRunAs
    ranges:
    - min: 1
      max: 65535
  readOnlyRootFilesystem: true
```

**网络安全策略：**
```yaml
# 网络安全策略
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
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: database
    ports:
    - protocol: TCP
      port: 3306
```

#### ⚡ 访问控制与审计

**RBAC权限配置：**
```yaml
# 应用特定角色
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: app-developer
rules:
- apiGroups: ["", "apps", "batch"]
  resources: ["pods", "deployments", "jobs", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/exec", "pods/portforward"]
  verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-developer-binding
  namespace: production
subjects:
- kind: User
  name: developer-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: app-developer
  apiGroup: rbac.authorization.k8s.io
```

**审计日志配置：**
```yaml
# 审计策略配置
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
  resources:
  - group: ""
    resources: ["pods", "deployments", "services"]
  - group: "apps"
    resources: ["deployments", "statefulsets", "daemonsets"]
  verbs: ["create", "update", "delete", "patch"]
  userGroups: ["system:authenticated"]

- level: Metadata
  resources:
  - group: ""
    resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
```

#### 💡 安全最佳实践

**安全配置检查清单：**
```markdown
# 应用安全配置检查清单 🔒

## 容器安全
- [ ] 使用非root用户运行应用
- [ ] 启用只读根文件系统
- [ ] 删除不必要的capabilities
- [ ] 使用安全的基础镜像

## 网络安全
- [ ] 实施网络策略隔离
- [ ] 限制Pod间通信
- [ ] 启用服务网格安全
- [ ] 配置TLS加密传输

## 配置安全
- [ ] 敏感信息使用Secret存储
- [ ] 启用配置变更审计
- [ ] 实施最小权限原则
- [ ] 定期轮换密钥和证书

## 合规要求
- [ ] 符合等保2.0应用安全部分
- [ ] 满足GDPR数据保护要求
- [ ] 遵循企业安全策略
- [ ] 定期进行安全审计
```

### 11. 总结与答疑

#### 🎯 关键要点回顾

**核心技能掌握情况检查：**
```markdown
## 工作负载专家技能自检清单 ✅

### 基础理论掌握
- [ ] 理解控制器模式工作原理
- [ ] 掌握各种工作负载类型特点
- [ ] 熟悉Pod生命周期管理
- [ ] 理解调度器工作机制

### 生产实践能力
- [ ] 能够设计高可用应用架构
- [ ] 熟练配置自动扩缩容体系
- [ ] 掌握多环境配置管理
- [ ] 具备滚动更新优化经验

### 故障处理技能
- [ ] 快速定位应用启动失败原因
- [ ] 熟练使用性能分析工具链
- [ ] 掌握应急响应处理流程
- [ ] 能够制定预防性措施

### 安全运维水平
- [ ] 实施应用安全配置策略
- [ ] 配置访问控制和审计
- [ ] 建立安全监控体系
- [ ] 遵循安全最佳实践
```

#### ⚡ 实际问题解答

**常见问题汇总：**
```markdown
## 工作负载常见问题解答 ❓

### Q1: 如何优化应用启动时间？
**A**: 
1. 优化镜像层数和大小
2. 启用镜像预拉取
3. 调整健康检查初始延迟
4. 使用Init Containers预处理

### Q2: Deployment更新失败怎么办？
**A**:
1. 检查镜像是否存在和可访问
2. 验证资源配置是否充足
3. 查看Pod事件和日志
4. 执行手动回滚操作

### Q3: 如何实现蓝绿部署？
**A**:
1. 部署两套独立环境
2. 使用Service切换流量
3. 配置健康检查确保稳定性
4. 实施渐进式流量切换

### Q4: 应用安全加固有哪些要点？
**A**:
1. 实施Pod安全策略
2. 配置网络访问控制
3. 启用运行时安全监控
4. 定期进行安全扫描
```

#### 💡 后续学习建议

**进阶学习路径：**
```markdown
## 工作负载进阶学习路线图 📚

### 第一阶段：深化理解 (1-2个月)
- 深入研究Kubernetes控制器源码
- 学习分布式系统设计原理
- 掌握微服务架构模式
- 理解云原生应用设计

### 第二阶段：扩展应用 (2-3个月)
- 开发自定义控制器Operator
- 实现企业特定部署策略
- 集成AIOPS智能运维
- 构建应用服务平台

### 第三阶段：专家提升 (3-6个月)
- 参与Kubernetes社区贡献
- 设计超大规模应用架构
- 制定企业应用标准规范
- 培养应用技术团队

### 推荐学习资源：
- 《Kubernetes Patterns》
- 《Programming Kubernetes》
- CNCF官方文档和案例
- 云原生应用最佳实践
```

---

## 🏆 培训总结

通过本次系统性的工作负载专家培训，您已经掌握了：
- ✅ 企业级应用架构设计和部署能力
- ✅ 复杂应用问题快速诊断和解决技能
- ✅ 完善的自动扩缩容和监控方案
- ✅ 系统性的应用安全管理策略
- ✅ 标准化的运维操作和应急响应流程

现在您可以胜任任何规模Kubernetes集群的应用运维专家工作！

*培训结束时间：预计 3-4 小时*
*实际掌握程度：专家级*