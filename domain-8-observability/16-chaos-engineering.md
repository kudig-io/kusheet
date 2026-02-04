# 52 - 混沌工程实践

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [chaos-mesh.org](https://chaos-mesh.org/)

## 混沌工程架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      混沌工程实践架构                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     混沌工程生命周期                                  │  │
│   │                                                                      │  │
│   │   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐     │  │
│   │   │  计划    │───▶│  执行    │───▶│  观察    │───▶│  分析    │     │  │
│   │   │ Planning │    │ Execute  │    │ Observe  │    │ Analyze  │     │  │
│   │   └──────────┘    └──────────┘    └──────────┘    └──────────┘     │  │
│   │        │                                               │            │  │
│   │        └───────────────────────────────────────────────┘            │  │
│   │                          反馈循环                                    │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     Chaos Mesh 架构                                  │  │
│   │                                                                      │  │
│   │   ┌────────────────────────────────────────────────────────────┐   │  │
│   │   │                   Chaos Dashboard                           │   │  │
│   │   │  • Web UI管理界面    • 实验创建/管理    • 实时状态监控      │   │  │
│   │   └────────────────────────────────────────────────────────────┘   │  │
│   │                              │                                      │  │
│   │   ┌────────────────────────────────────────────────────────────┐   │  │
│   │   │              Chaos Controller Manager                       │   │  │
│   │   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │   │  │
│   │   │  │ PodChaos     │  │ NetworkChaos │  │ IOChaos      │     │   │  │
│   │   │  │ Controller   │  │ Controller   │  │ Controller   │     │   │  │
│   │   │  └──────────────┘  └──────────────┘  └──────────────┘     │   │  │
│   │   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │   │  │
│   │   │  │ StressChaos  │  │ TimeChaos    │  │ DNSChaos     │     │   │  │
│   │   │  │ Controller   │  │ Controller   │  │ Controller   │     │   │  │
│   │   │  └──────────────┘  └──────────────┘  └──────────────┘     │   │  │
│   │   └────────────────────────────────────────────────────────────┘   │  │
│   │                              │                                      │  │
│   │   ┌────────────────────────────────────────────────────────────┐   │  │
│   │   │                   Chaos Daemon (DaemonSet)                  │   │  │
│   │   │  • 每个节点运行         • 注入故障到容器                    │   │  │
│   │   │  • 使用eBPF/ptrace      • 网络/IO/进程注入                  │   │  │
│   │   └────────────────────────────────────────────────────────────┘   │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     故障注入层次                                     │  │
│   │                                                                      │  │
│   │   ┌─────────────────────────────────────────────────────────────┐  │  │
│   │   │ Layer 4: 应用层    │ HTTPChaos, JVMChaos, GRPCChaos        │  │  │
│   │   ├─────────────────────────────────────────────────────────────┤  │  │
│   │   │ Layer 3: 服务层    │ DNSChaos, PodChaos, NetworkChaos      │  │  │
│   │   ├─────────────────────────────────────────────────────────────┤  │  │
│   │   │ Layer 2: 系统层    │ IOChaos, StressChaos, TimeChaos       │  │  │
│   │   ├─────────────────────────────────────────────────────────────┤  │  │
│   │   │ Layer 1: 基础设施  │ AWSChaos, GCPChaos, PhysicalMachine   │  │  │
│   │   └─────────────────────────────────────────────────────────────┘  │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 混沌工程原则

| 原则 | 说明 | 实践方式 | 重要性 |
|-----|------|---------|-------|
| **建立稳态假设** | 定义系统正常行为指标 | SLI/SLO定义,基线测量 | P0 |
| **真实世界事件** | 模拟真实故障场景 | 基于历史故障,概率建模 | P0 |
| **生产环境实验** | 真实环境才能发现真实问题 | 灰度实验,金丝雀发布 | P1 |
| **自动化持续** | 持续运行实验 | CI/CD集成,定期执行 | P1 |
| **最小爆炸半径** | 控制实验影响范围 | 渐进式扩大,紧急停止 | P0 |
| **记录与学习** | 记录发现并改进系统 | 事后复盘,知识库 | P1 |

## 混沌工程工具对比

| 工具 | 架构 | 支持场景 | K8s原生 | 学习曲线 | 社区活跃度 | 适用场景 |
|-----|------|---------|--------|---------|-----------|---------|
| **Chaos Mesh** | Operator | 全场景 | ✅ | 中 | ⭐⭐⭐⭐⭐ | K8s环境首选 |
| **LitmusChaos** | Operator | 全场景 | ✅ | 中 | ⭐⭐⭐⭐⭐ | GitOps集成 |
| **Chaos Monkey** | 独立 | 实例终止 | ❌ | 低 | ⭐⭐⭐ | Netflix生态 |
| **Gremlin** | SaaS | 全场景 | ✅ | 低 | ⭐⭐⭐⭐ | 企业级托管 |
| **AWS FIS** | 托管 | AWS资源 | ❌ | 低 | ⭐⭐⭐⭐ | AWS环境 |
| **Chaosblade** | Agent | 全场景 | ✅ | 中 | ⭐⭐⭐⭐ | 阿里生态 |
| **Toxiproxy** | Proxy | 网络故障 | ❌ | 低 | ⭐⭐⭐ | 测试环境 |
| **Pumba** | CLI | 容器故障 | ✅ | 低 | ⭐⭐⭐ | Docker环境 |

## Chaos Mesh故障类型详解

| 类型 | CRD | 说明 | 注入方式 | 典型场景 |
|-----|-----|------|---------|---------|
| **Pod故障** | PodChaos | 杀Pod/容器失败 | API调用 | 测试自愈能力 |
| **网络故障** | NetworkChaos | 延迟/丢包/分区 | tc/iptables | 测试服务降级 |
| **文件系统** | IOChaos | IO延迟/错误 | fuse/eBPF | 测试存储故障 |
| **内核故障** | KernelChaos | 内核错误注入 | eBPF | 测试系统稳定性 |
| **时间偏移** | TimeChaos | 时钟偏移 | VDSO hook | 测试时间敏感逻辑 |
| **压力测试** | StressChaos | CPU/内存压力 | stress-ng | 测试资源竞争 |
| **JVM故障** | JVMChaos | Java异常注入 | Byteman | 测试Java应用 |
| **HTTP故障** | HTTPChaos | HTTP请求故障 | eBPF/sidecar | 测试API容错 |
| **DNS故障** | DNSChaos | DNS解析故障 | CoreDNS注入 | 测试DNS依赖 |
| **云平台故障** | AWSChaos/GCPChaos | 云资源故障 | 云API | 测试云故障转移 |

## Chaos Mesh安装部署

### Helm安装

```bash
# 添加Helm仓库
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update

# 创建命名空间
kubectl create namespace chaos-mesh

# 安装Chaos Mesh
helm install chaos-mesh chaos-mesh/chaos-mesh \
  -n chaos-mesh \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
  --set dashboard.securityMode=true \
  --set dashboard.service.type=ClusterIP

# 验证安装
kubectl get pods -n chaos-mesh
kubectl get crd | grep chaos-mesh

# 访问Dashboard(通过port-forward)
kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333
```

### RBAC配置

```yaml
# chaos-mesh-rbac.yaml - 细粒度RBAC控制
apiVersion: v1
kind: ServiceAccount
metadata:
  name: chaos-operator
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: chaos-operator-role
  namespace: production
rules:
# 允许在production命名空间执行混沌实验
- apiGroups: ["chaos-mesh.org"]
  resources: ["*"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch", "delete"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch", "create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: chaos-operator-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: chaos-operator
  namespace: production
roleRef:
  kind: Role
  name: chaos-operator-role
  apiGroup: rbac.authorization.k8s.io
```

## PodChaos详细配置

### Pod Kill实验

```yaml
# pod-kill-experiment.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-kill-experiment
  namespace: chaos-mesh
  labels:
    experiment-type: resilience
    target-service: api-server
spec:
  # 故障动作: pod-kill/pod-failure/container-kill
  action: pod-kill
  
  # 选择模式
  # one: 随机选择一个
  # all: 选择所有匹配的
  # fixed: 固定数量
  # fixed-percent: 固定百分比
  # random-max-percent: 随机最大百分比
  mode: fixed-percent
  value: "30"  # 杀死30%的Pod
  
  # 目标选择器
  selector:
    namespaces:
    - production
    labelSelectors:
      app: api-server
      tier: backend
    # 可选: 节点选择
    nodeSelectors:
      node-type: worker
    # 可选: Pod名称正则
    pods:
      production:
      - api-server-*
    # 可选: 排除特定Pod
    expressionSelectors:
    - key: version
      operator: NotIn
      values:
      - canary
      
  # 持续时间
  duration: "60s"
  
  # 优雅终止期(仅pod-kill有效)
  gracePeriod: 0
  
  # 调度器配置(可选)
  scheduler:
    cron: "@every 4h"  # 每4小时执行一次
    
---
# container-kill实验 - 只杀死容器不杀Pod
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: container-kill-experiment
  namespace: chaos-mesh
spec:
  action: container-kill
  mode: one
  selector:
    namespaces:
    - production
    labelSelectors:
      app: web-server
  containerNames:
  - nginx  # 只杀nginx容器,保留sidecar
  duration: "30s"
  
---
# pod-failure实验 - 模拟Pod故障但不删除
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-failure-experiment
  namespace: chaos-mesh
spec:
  action: pod-failure
  mode: fixed
  value: "2"  # 使2个Pod故障
  selector:
    namespaces:
    - production
    labelSelectors:
      app: worker
  duration: "120s"  # 故障持续2分钟后自动恢复
```

## NetworkChaos详细配置

### 网络延迟实验

```yaml
# network-delay-experiment.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-delay-to-database
  namespace: chaos-mesh
spec:
  action: delay
  mode: all
  
  # 源选择器(受影响的Pod)
  selector:
    namespaces:
    - production
    labelSelectors:
      app: api-server
      
  # 延迟配置
  delay:
    latency: "100ms"       # 基础延迟
    correlation: "25"       # 相关性(0-100),影响延迟变化的一致性
    jitter: "50ms"         # 抖动范围
    
  # 方向: to/from/both
  direction: to
  
  # 目标选择器(延迟目标)
  target:
    selector:
      namespaces:
      - database
      labelSelectors:
        app: mysql
    mode: all
    
  # 外部目标(可选,用于外部服务)
  externalTargets:
  - "api.external-service.com"
  
  duration: "5m"

---
# 网络丢包实验
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-loss-experiment
  namespace: chaos-mesh
spec:
  action: loss
  mode: all
  selector:
    namespaces:
    - production
    labelSelectors:
      app: frontend
  loss:
    loss: "25"              # 丢包率25%
    correlation: "25"
  direction: both
  duration: "3m"

---
# 网络分区实验
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-partition-experiment
  namespace: chaos-mesh
spec:
  action: partition
  mode: all
  selector:
    namespaces:
    - production
    labelSelectors:
      app: service-a
  direction: both
  target:
    selector:
      namespaces:
      - production
      labelSelectors:
        app: service-b
    mode: all
  duration: "2m"

---
# 带宽限制实验
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: bandwidth-limit-experiment
  namespace: chaos-mesh
spec:
  action: bandwidth
  mode: all
  selector:
    namespaces:
    - production
    labelSelectors:
      app: data-processor
  bandwidth:
    rate: "1mbps"           # 限制带宽为1Mbps
    limit: 20971520         # 队列大小(bytes)
    buffer: 10000           # 缓冲区大小
  direction: to
  target:
    selector:
      namespaces:
      - storage
      labelSelectors:
        app: minio
    mode: all
  duration: "5m"

---
# 网络重复包实验
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-duplicate-experiment
  namespace: chaos-mesh
spec:
  action: duplicate
  mode: all
  selector:
    namespaces:
    - production
    labelSelectors:
      app: message-queue
  duplicate:
    duplicate: "10"         # 10%的包会被复制
    correlation: "25"
  direction: both
  duration: "3m"

---
# 网络包损坏实验
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-corrupt-experiment
  namespace: chaos-mesh
spec:
  action: corrupt
  mode: all
  selector:
    namespaces:
    - production
    labelSelectors:
      app: tcp-service
  corrupt:
    corrupt: "5"            # 5%的包会损坏
    correlation: "25"
  direction: both
  duration: "2m"
```

## StressChaos详细配置

```yaml
# stress-chaos-experiment.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: cpu-memory-stress
  namespace: chaos-mesh
spec:
  mode: one
  selector:
    namespaces:
    - production
    labelSelectors:
      app: compute-intensive
      
  # CPU压力配置
  stressors:
    cpu:
      workers: 2            # CPU压力worker数量
      load: 80              # CPU负载百分比
      
    # 内存压力配置
    memory:
      workers: 2            # 内存压力worker数量
      size: "512MB"         # 每个worker消耗的内存
      # 或使用百分比
      # size: "80%"
      
  # 容器级别压力(可选)
  containerNames:
  - main-app
  
  duration: "5m"

---
# 仅CPU压力
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: cpu-stress-only
  namespace: chaos-mesh
spec:
  mode: fixed
  value: "3"
  selector:
    namespaces:
    - production
    labelSelectors:
      app: api-server
  stressors:
    cpu:
      workers: 4
      load: 90
  duration: "3m"

---
# 仅内存压力(测试OOM处理)
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: memory-stress-oom-test
  namespace: chaos-mesh
spec:
  mode: one
  selector:
    namespaces:
    - production
    labelSelectors:
      app: memory-sensitive
  stressors:
    memory:
      workers: 1
      size: "90%"           # 消耗90%的容器内存限制
      oomScoreAdj: 1000     # 提高OOM优先级
  duration: "2m"
```

## IOChaos详细配置

```yaml
# io-chaos-experiment.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: IOChaos
metadata:
  name: io-latency-experiment
  namespace: chaos-mesh
spec:
  action: latency
  mode: one
  selector:
    namespaces:
    - production
    labelSelectors:
      app: database
      
  # 挂载卷路径
  volumePath: /var/lib/mysql
  
  # 文件路径模式(支持通配符)
  path: /var/lib/mysql/data/**
  
  # 延迟配置
  delay: "100ms"
  
  # 影响百分比
  percent: 50               # 50%的IO操作受影响
  
  # IO操作类型过滤
  methods:
  - read
  - write
  - fsync
  
  # 容器名称
  containerNames:
  - mysql
  
  duration: "5m"

---
# IO错误注入
apiVersion: chaos-mesh.org/v1alpha1
kind: IOChaos
metadata:
  name: io-fault-experiment
  namespace: chaos-mesh
spec:
  action: fault
  mode: one
  selector:
    namespaces:
    - production
    labelSelectors:
      app: storage-app
  volumePath: /data
  path: /data/critical/**
  errno: 5                  # EIO错误码
  percent: 10               # 10%的IO返回错误
  methods:
  - write
  duration: "3m"

---
# IO属性修改(返回错误的文件属性)
apiVersion: chaos-mesh.org/v1alpha1
kind: IOChaos
metadata:
  name: io-attr-override
  namespace: chaos-mesh
spec:
  action: attrOverride
  mode: one
  selector:
    namespaces:
    - production
    labelSelectors:
      app: file-processor
  volumePath: /data
  path: /data/input/**
  attr:
    size: 0                 # 文件大小显示为0
  percent: 100
  duration: "2m"
```

## DNSChaos详细配置

```yaml
# dns-chaos-experiment.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: DNSChaos
metadata:
  name: dns-error-experiment
  namespace: chaos-mesh
spec:
  action: error
  mode: all
  selector:
    namespaces:
    - production
    labelSelectors:
      app: external-api-client
      
  # DNS域名模式
  patterns:
  - "api.external-service.com"
  - "*.third-party.io"
  
  duration: "3m"

---
# DNS随机响应
apiVersion: chaos-mesh.org/v1alpha1
kind: DNSChaos
metadata:
  name: dns-random-experiment
  namespace: chaos-mesh
spec:
  action: random
  mode: all
  selector:
    namespaces:
    - production
    labelSelectors:
      app: dns-dependent
  patterns:
  - "internal-service.default.svc.cluster.local"
  duration: "2m"
```

## TimeChaos详细配置

```yaml
# time-chaos-experiment.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: TimeChaos
metadata:
  name: time-skew-experiment
  namespace: chaos-mesh
spec:
  mode: all
  selector:
    namespaces:
    - production
    labelSelectors:
      app: scheduler-service
      
  # 时间偏移配置
  timeOffset: "-2h"         # 时间回拨2小时
  # 或向前: "+30m"
  
  # 时钟ID(可选)
  # CLOCK_REALTIME: 0 (默认)
  # CLOCK_MONOTONIC: 1
  clockIds:
  - 0
  
  # 容器名称
  containerNames:
  - main-app
  
  duration: "5m"

---
# 测试闰秒场景
apiVersion: chaos-mesh.org/v1alpha1
kind: TimeChaos
metadata:
  name: leap-second-test
  namespace: chaos-mesh
spec:
  mode: one
  selector:
    namespaces:
    - production
    labelSelectors:
      app: time-sensitive
  timeOffset: "-1s"
  duration: "10s"
```

## HTTPChaos详细配置

```yaml
# http-chaos-experiment.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: http-delay-experiment
  namespace: chaos-mesh
spec:
  mode: all
  selector:
    namespaces:
    - production
    labelSelectors:
      app: api-gateway
      
  # 目标配置
  target: Request           # Request/Response
  port: 8080
  
  # 路径匹配
  path: "/api/v1/*"
  method: "GET"
  
  # 延迟配置
  delay: "2s"
  
  duration: "5m"

---
# HTTP错误注入
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: http-abort-experiment
  namespace: chaos-mesh
spec:
  mode: all
  selector:
    namespaces:
    - production
    labelSelectors:
      app: backend-service
  target: Response
  port: 8080
  path: "/api/orders/*"
  method: "POST"
  
  # 中止配置
  abort: true
  
  # 或返回特定状态码
  # code: 503
  
  duration: "3m"

---
# HTTP响应修改
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: http-replace-experiment
  namespace: chaos-mesh
spec:
  mode: all
  selector:
    namespaces:
    - production
    labelSelectors:
      app: api-server
  target: Response
  port: 8080
  path: "/api/health"
  
  # 替换响应体
  replace:
    body: '{"status": "degraded"}'
    headers:
      X-Chaos-Injected: "true"
    code: 200
    
  duration: "5m"
```

## JVMChaos详细配置

```yaml
# jvm-chaos-experiment.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: JVMChaos
metadata:
  name: jvm-exception-experiment
  namespace: chaos-mesh
spec:
  mode: one
  selector:
    namespaces:
    - production
    labelSelectors:
      app: java-service
      
  # 目标类和方法
  class: "com.example.service.OrderService"
  method: "processOrder"
  
  # 动作类型
  action: exception
  
  # 异常配置
  exception: "java.lang.RuntimeException"
  message: "Chaos injected exception"
  
  # 容器名称
  containerNames:
  - java-app
  
  # JVM Agent端口
  port: 9288
  
  duration: "3m"

---
# JVM GC压力
apiVersion: chaos-mesh.org/v1alpha1
kind: JVMChaos
metadata:
  name: jvm-gc-stress
  namespace: chaos-mesh
spec:
  mode: one
  selector:
    namespaces:
    - production
    labelSelectors:
      app: java-service
  action: stress
  # GC压力
  memType: heap
  duration: "5m"

---
# JVM方法延迟
apiVersion: chaos-mesh.org/v1alpha1
kind: JVMChaos
metadata:
  name: jvm-latency-experiment
  namespace: chaos-mesh
spec:
  mode: one
  selector:
    namespaces:
    - production
    labelSelectors:
      app: java-service
  class: "com.example.dao.UserDao"
  method: "findById"
  action: latency
  latency: 2000             # 方法执行延迟2秒
  duration: "5m"

---
# JVM方法返回值修改
apiVersion: chaos-mesh.org/v1alpha1
kind: JVMChaos
metadata:
  name: jvm-return-experiment
  namespace: chaos-mesh
spec:
  mode: one
  selector:
    namespaces:
    - production
    labelSelectors:
      app: java-service
  class: "com.example.service.ConfigService"
  method: "isFeatureEnabled"
  action: return
  value: "false"            # 强制返回false
  duration: "3m"
```

## Workflow编排

### 串行执行

```yaml
# serial-workflow.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: serial-chaos-workflow
  namespace: chaos-mesh
spec:
  entry: serial-entry
  templates:
  # 入口模板 - 串行执行
  - name: serial-entry
    templateType: Serial
    deadline: "30m"
    children:
    - network-delay-step
    - verify-step-1
    - pod-kill-step
    - verify-step-2
    - stress-step
    
  # 步骤1: 网络延迟
  - name: network-delay-step
    templateType: NetworkChaos
    deadline: "5m"
    networkChaos:
      action: delay
      mode: all
      selector:
        namespaces: [production]
        labelSelectors:
          app: frontend
      delay:
        latency: "200ms"
      duration: "3m"
      
  # 验证步骤1
  - name: verify-step-1
    templateType: Suspend
    deadline: "2m"
    suspend:
      duration: "1m"        # 暂停1分钟进行验证
      
  # 步骤2: Pod故障
  - name: pod-kill-step
    templateType: PodChaos
    deadline: "3m"
    podChaos:
      action: pod-kill
      mode: fixed-percent
      value: "20"
      selector:
        namespaces: [production]
        labelSelectors:
          app: api-server
          
  # 验证步骤2
  - name: verify-step-2
    templateType: Suspend
    deadline: "2m"
    suspend:
      duration: "1m"
      
  # 步骤3: 资源压力
  - name: stress-step
    templateType: StressChaos
    deadline: "6m"
    stressChaos:
      mode: one
      selector:
        namespaces: [production]
        labelSelectors:
          app: worker
      stressors:
        cpu:
          workers: 2
          load: 70
      duration: "5m"
```

### 并行执行

```yaml
# parallel-workflow.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: parallel-chaos-workflow
  namespace: chaos-mesh
spec:
  entry: parallel-entry
  templates:
  # 入口模板 - 并行执行
  - name: parallel-entry
    templateType: Parallel
    deadline: "10m"
    children:
    - network-chaos-branch
    - pod-chaos-branch
    - stress-chaos-branch
    
  # 分支1: 网络故障
  - name: network-chaos-branch
    templateType: NetworkChaos
    deadline: "5m"
    networkChaos:
      action: delay
      mode: all
      selector:
        namespaces: [production]
        labelSelectors:
          app: service-a
      delay:
        latency: "100ms"
      duration: "4m"
      
  # 分支2: Pod故障
  - name: pod-chaos-branch
    templateType: PodChaos
    deadline: "5m"
    podChaos:
      action: pod-failure
      mode: one
      selector:
        namespaces: [production]
        labelSelectors:
          app: service-b
      duration: "4m"
      
  # 分支3: 资源压力
  - name: stress-chaos-branch
    templateType: StressChaos
    deadline: "5m"
    stressChaos:
      mode: one
      selector:
        namespaces: [production]
        labelSelectors:
          app: service-c
      stressors:
        memory:
          workers: 1
          size: "256MB"
      duration: "4m"
```

### 复杂编排

```yaml
# complex-workflow.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: complex-chaos-workflow
  namespace: chaos-mesh
spec:
  entry: main
  templates:
  # 主流程
  - name: main
    templateType: Serial
    deadline: "1h"
    children:
    - prepare-phase
    - chaos-phase
    - cleanup-phase
    
  # 准备阶段
  - name: prepare-phase
    templateType: Suspend
    deadline: "5m"
    suspend:
      duration: "30s"       # 准备时间
      
  # 混沌阶段 - 包含多个并行实验
  - name: chaos-phase
    templateType: Parallel
    deadline: "30m"
    children:
    - frontend-chaos-serial
    - backend-chaos-serial
    
  # 前端服务混沌测试流程
  - name: frontend-chaos-serial
    templateType: Serial
    deadline: "15m"
    children:
    - frontend-network-delay
    - frontend-pod-kill
    
  - name: frontend-network-delay
    templateType: NetworkChaos
    deadline: "6m"
    networkChaos:
      action: delay
      mode: all
      selector:
        namespaces: [production]
        labelSelectors:
          tier: frontend
      delay:
        latency: "150ms"
      duration: "5m"
      
  - name: frontend-pod-kill
    templateType: PodChaos
    deadline: "4m"
    podChaos:
      action: pod-kill
      mode: one
      selector:
        namespaces: [production]
        labelSelectors:
          tier: frontend
          
  # 后端服务混沌测试流程
  - name: backend-chaos-serial
    templateType: Serial
    deadline: "15m"
    children:
    - backend-io-chaos
    - backend-stress
    
  - name: backend-io-chaos
    templateType: IOChaos
    deadline: "6m"
    ioChaos:
      action: latency
      mode: one
      selector:
        namespaces: [production]
        labelSelectors:
          tier: backend
      volumePath: /data
      delay: "50ms"
      percent: 30
      duration: "5m"
      
  - name: backend-stress
    templateType: StressChaos
    deadline: "6m"
    stressChaos:
      mode: one
      selector:
        namespaces: [production]
        labelSelectors:
          tier: backend
      stressors:
        cpu:
          workers: 2
          load: 60
      duration: "5m"
      
  # 清理阶段
  - name: cleanup-phase
    templateType: Suspend
    deadline: "5m"
    suspend:
      duration: "1m"        # 清理和观察时间
```

## LitmusChaos配置

### ChaosEngine配置

```yaml
# litmus-chaos-engine.yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: nginx-chaos-engine
  namespace: production
spec:
  # 应用信息
  appinfo:
    appns: production
    applabel: "app=nginx"
    appkind: deployment
    
  # 服务账户
  chaosServiceAccount: litmus-admin
  
  # 任务清理策略
  jobCleanUpPolicy: delete
  
  # 实验列表
  experiments:
  - name: pod-delete
    spec:
      components:
        env:
        - name: TOTAL_CHAOS_DURATION
          value: "60"
        - name: CHAOS_INTERVAL
          value: "10"
        - name: FORCE
          value: "false"
        - name: PODS_AFFECTED_PERC
          value: "50"
          
  - name: pod-network-latency
    spec:
      components:
        env:
        - name: TOTAL_CHAOS_DURATION
          value: "120"
        - name: NETWORK_LATENCY
          value: "100"
        - name: CONTAINER_RUNTIME
          value: "containerd"
          
  # 探针配置
  probe:
  - name: http-probe
    type: httpProbe
    httpProbe/inputs:
      url: "http://nginx-service:80/health"
      insecureSkipVerify: false
      method:
        get:
          criteria: "=="
          responseCode: "200"
    mode: Continuous
    runProperties:
      probeTimeout: 5
      interval: 5
      retry: 3
      
---
# Litmus服务账户
apiVersion: v1
kind: ServiceAccount
metadata:
  name: litmus-admin
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: litmus-admin
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "events", "configmaps", "secrets", "services"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets", "replicasets", "daemonsets"]
  verbs: ["get", "list", "watch", "update", "patch"]
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["litmuschaos.io"]
  resources: ["chaosengines", "chaosexperiments", "chaosresults"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

## 稳态指标与监控

### 稳态指标定义

| 指标类别 | 指标名称 | 计算方式 | 阈值建议 | 监控工具 |
|---------|---------|---------|---------|---------|
| **可用性** | 成功请求率 | 成功请求/总请求 | >99.9% | Prometheus |
| **延迟** | P99响应时间 | histogram_quantile | <500ms | Prometheus |
| **延迟** | P50响应时间 | histogram_quantile | <100ms | Prometheus |
| **吞吐量** | QPS | rate(requests_total) | ±10%波动 | Prometheus |
| **错误率** | 5xx比例 | 5xx请求/总请求 | <0.1% | Prometheus |
| **资源** | CPU使用率 | container_cpu_usage | <80% | cAdvisor |
| **资源** | 内存使用率 | container_memory_working_set | <85% | cAdvisor |
| **队列** | 消息堆积 | 队列深度 | <1000 | 中间件监控 |
| **连接** | DB连接池使用率 | 活跃连接/最大连接 | <80% | 应用指标 |
| **恢复** | MTTR | 故障到恢复时间 | <5min | 告警系统 |

### Prometheus告警规则

```yaml
# chaos-alerting-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: chaos-experiment-alerts
  namespace: monitoring
spec:
  groups:
  - name: chaos.steadystate
    interval: 30s
    rules:
    # 可用性下降告警
    - alert: ChaosSteadyStateAvailabilityBreach
      expr: |
        sum(rate(http_requests_total{status=~"2.."}[1m])) / 
        sum(rate(http_requests_total[1m])) < 0.999
      for: 1m
      labels:
        severity: warning
        chaos_related: "true"
      annotations:
        summary: "稳态假设违反: 可用性低于99.9%"
        description: "当前可用性: {{ $value | printf \"%.4f\" }}"
        
    # 延迟上升告警
    - alert: ChaosSteadyStateLatencyBreach
      expr: |
        histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[1m])) by (le)) > 0.5
      for: 1m
      labels:
        severity: warning
        chaos_related: "true"
      annotations:
        summary: "稳态假设违反: P99延迟超过500ms"
        description: "当前P99延迟: {{ $value | printf \"%.3f\" }}s"
        
    # 错误率上升告警
    - alert: ChaosSteadyStateErrorRateBreach
      expr: |
        sum(rate(http_requests_total{status=~"5.."}[1m])) / 
        sum(rate(http_requests_total[1m])) > 0.001
      for: 1m
      labels:
        severity: critical
        chaos_related: "true"
      annotations:
        summary: "稳态假设违反: 5xx错误率超过0.1%"
        description: "当前错误率: {{ $value | printf \"%.4f\" }}"
        
    # Pod恢复时间告警
    - alert: ChaosPodRecoveryTooSlow
      expr: |
        time() - kube_pod_start_time{namespace="production"} > 120
        and on(pod) kube_pod_status_phase{phase="Pending"} == 1
      for: 2m
      labels:
        severity: warning
        chaos_related: "true"
      annotations:
        summary: "Pod恢复时间超过2分钟"
```

### Grafana Dashboard

```json
{
  "dashboard": {
    "title": "Chaos Engineering Dashboard",
    "panels": [
      {
        "title": "服务可用性",
        "type": "gauge",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{status=~\"2..\"}[5m])) / sum(rate(http_requests_total[5m])) * 100"
          }
        ],
        "thresholds": {
          "mode": "absolute",
          "steps": [
            {"color": "red", "value": null},
            {"color": "yellow", "value": 99},
            {"color": "green", "value": 99.9}
          ]
        }
      },
      {
        "title": "请求延迟分布",
        "type": "heatmap",
        "targets": [
          {
            "expr": "sum(rate(http_request_duration_seconds_bucket[5m])) by (le)"
          }
        ]
      },
      {
        "title": "活跃混沌实验",
        "type": "stat",
        "targets": [
          {
            "expr": "count(chaos_mesh_experiments{status=\"Running\"})"
          }
        ]
      },
      {
        "title": "Pod重启次数",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(increase(kube_pod_container_status_restarts_total{namespace=\"production\"}[5m])) by (pod)"
          }
        ]
      }
    ]
  }
}
```

## 实验场景设计

### 场景1: 服务自愈能力验证

```yaml
# scenario-1-self-healing.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: self-healing-test
  namespace: chaos-mesh
  annotations:
    scenario: "验证服务自愈能力"
    hypothesis: "当30%的Pod被杀死时,系统应在60秒内恢复到正常状态"
spec:
  entry: main
  templates:
  - name: main
    templateType: Serial
    children:
    - baseline-check
    - pod-kill-chaos
    - recovery-observation
    
  - name: baseline-check
    templateType: Suspend
    suspend:
      duration: "30s"
      
  - name: pod-kill-chaos
    templateType: PodChaos
    podChaos:
      action: pod-kill
      mode: fixed-percent
      value: "30"
      selector:
        namespaces: [production]
        labelSelectors:
          app: api-server
          
  - name: recovery-observation
    templateType: Suspend
    suspend:
      duration: "2m"
```

### 场景2: 服务降级验证

```yaml
# scenario-2-graceful-degradation.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: graceful-degradation-test
  namespace: chaos-mesh
  annotations:
    scenario: "验证服务降级机制"
    hypothesis: "当下游服务响应慢时,应触发超时和降级,不影响核心功能"
spec:
  entry: main
  templates:
  - name: main
    templateType: Serial
    children:
    - inject-downstream-latency
    - observe-degradation
    
  - name: inject-downstream-latency
    templateType: NetworkChaos
    networkChaos:
      action: delay
      mode: all
      selector:
        namespaces: [production]
        labelSelectors:
          app: recommendation-service
      delay:
        latency: "5s"
      duration: "5m"
      
  - name: observe-degradation
    templateType: Suspend
    suspend:
      duration: "6m"
```

### 场景3: 数据库故障转移

```yaml
# scenario-3-db-failover.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: db-failover-test
  namespace: chaos-mesh
  annotations:
    scenario: "验证数据库故障转移"
    hypothesis: "当主数据库不可用时,应在30秒内切换到从库"
spec:
  entry: main
  templates:
  - name: main
    templateType: Serial
    children:
    - partition-primary-db
    - verify-failover
    - restore-network
    
  - name: partition-primary-db
    templateType: NetworkChaos
    networkChaos:
      action: partition
      mode: all
      selector:
        namespaces: [database]
        labelSelectors:
          app: mysql
          role: primary
      direction: both
      target:
        selector:
          namespaces: [production]
        mode: all
      duration: "3m"
      
  - name: verify-failover
    templateType: Suspend
    suspend:
      duration: "4m"
      
  - name: restore-network
    templateType: Suspend
    suspend:
      duration: "30s"
```

### 场景4: 资源竞争测试

```yaml
# scenario-4-resource-contention.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: resource-contention-test
  namespace: chaos-mesh
  annotations:
    scenario: "验证资源竞争处理"
    hypothesis: "当节点资源紧张时,系统应正确处理并保证关键服务可用"
spec:
  entry: main
  templates:
  - name: main
    templateType: Parallel
    children:
    - cpu-stress
    - memory-stress
    
  - name: cpu-stress
    templateType: StressChaos
    stressChaos:
      mode: fixed
      value: "2"
      selector:
        namespaces: [production]
        labelSelectors:
          tier: worker
      stressors:
        cpu:
          workers: 4
          load: 85
      duration: "5m"
      
  - name: memory-stress
    templateType: StressChaos
    stressChaos:
      mode: fixed
      value: "2"
      selector:
        namespaces: [production]
        labelSelectors:
          tier: worker
      stressors:
        memory:
          workers: 2
          size: "70%"
      duration: "5m"
```

## 实验报告模板

```yaml
# experiment-report-template.yaml
experiment:
  name: "API服务Pod故障恢复测试"
  id: "chaos-exp-2026011701"
  date: "2026-01-17"
  owner: "SRE Team"
  reviewer: "Platform Team"
  
# 稳态假设
hypothesis:
  description: "当30%的API Pod被杀死时,系统应在60秒内恢复到正常状态"
  steady_state_metrics:
    - metric: "success_rate"
      operator: ">"
      expected: "99%"
      actual: "99.2%"
      pass: true
    - metric: "p99_latency"
      operator: "<"
      expected: "200ms"
      actual: "180ms"
      pass: true
    - metric: "error_rate"
      operator: "<"
      expected: "0.1%"
      actual: "0.05%"
      pass: true

# 实验执行
execution:
  blast_radius: "production/api-server (3/10 pods)"
  duration: "60s"
  start_time: "2026-01-17T10:00:00Z"
  end_time: "2026-01-17T10:02:30Z"
  monitoring_dashboard: "https://grafana.example.com/d/chaos-123"
  chaos_resource: "podchaos/api-server-kill-test"
  
# 结果
results:
  hypothesis_validated: true
  metrics:
    success_rate: "99.2%"
    p99_latency: "180ms"
    error_rate: "0.05%"
    recovery_time: "45s"
  observations:
    - "HPA响应及时,新Pod在30秒内启动"
    - "负载均衡正确移除了不健康的Pod"
    - "无数据丢失,所有请求都被正确重试"
    - "监控告警在15秒内触发"
    
# 发现的问题
findings:
  - severity: "medium"
    description: "Pod启动时间较长(约25秒),主要是镜像拉取"
    recommendation: "启用镜像预热或使用更小的基础镜像"
  - severity: "low"
    description: "部分Pod集中在同一节点"
    recommendation: "增加Pod反亲和性配置"
    
# 改进建议
recommendations:
  - priority: "P1"
    action: "增加Pod反亲和性,避免Pod集中在同一节点"
    owner: "Platform Team"
    deadline: "2026-01-24"
  - priority: "P2"
    action: "优化启动探针配置,减少Pod就绪时间"
    owner: "Dev Team"
    deadline: "2026-01-31"
  - priority: "P2"
    action: "配置镜像预热Job"
    owner: "Platform Team"
    deadline: "2026-02-07"
    
# 后续行动
follow_up:
  next_experiment: "增加blast_radius到50%进行测试"
  scheduled_date: "2026-02-01"
```

## ACK混沌工程集成

```bash
# ACK安装Chaos Mesh
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update

# 安装到ACK集群
helm install chaos-mesh chaos-mesh/chaos-mesh \
  -n chaos-mesh --create-namespace \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
  --set dashboard.securityMode=true \
  --set dashboard.service.type=LoadBalancer \
  --set controllerManager.replicaCount=3

# 配置ARMS集成(可观测)
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: chaos-mesh-arms-config
  namespace: chaos-mesh
data:
  arms-endpoint: "https://arms.cn-hangzhou.aliyuncs.com"
  arms-license-key: "<your-license-key>"
EOF

# 配置SLS日志采集
kubectl apply -f - <<EOF
apiVersion: log.alibabacloud.com/v1alpha1
kind: AliyunLogConfig
metadata:
  name: chaos-mesh-logs
  namespace: chaos-mesh
spec:
  logstore: chaos-mesh-logs
  shardCount: 2
  lifeCycle: 30
  logtailConfig:
    inputType: plugin
    configName: chaos-mesh-logs
    inputDetail:
      plugin:
        inputs:
        - type: service_docker_stdout
          detail:
            Stderr: true
            Stdout: true
            IncludeLabel:
              app: chaos-mesh
EOF
```

## 最佳实践

### 混沌工程实施清单

| 阶段 | 活动 | 说明 | 检查项 |
|-----|------|------|-------|
| **准备** | 定义稳态假设 | SLI/SLO基线 | □ 指标定义完成 |
| **准备** | 选择实验范围 | 从小范围开始 | □ blast radius确定 |
| **准备** | 配置监控 | Dashboard/告警 | □ 监控就绪 |
| **准备** | 准备回滚方案 | 紧急停止机制 | □ 回滚流程验证 |
| **执行** | 通知相关团队 | 实验日历 | □ 团队已通知 |
| **执行** | 运行实验 | 监控稳态指标 | □ 实验运行中 |
| **执行** | 实时观察 | 关注异常 | □ 持续监控 |
| **分析** | 收集数据 | 指标/日志/事件 | □ 数据收集完成 |
| **分析** | 验证假设 | 对比稳态指标 | □ 假设验证完成 |
| **分析** | 记录发现 | 问题和改进点 | □ 报告生成 |
| **改进** | 制定改进计划 | 优先级排序 | □ 改进计划制定 |
| **改进** | 实施改进 | 跟踪进度 | □ 改进已实施 |
| **改进** | 重新测试 | 验证改进效果 | □ 重测通过 |

### 安全考虑

```yaml
# 生产环境安全配置
# 1. 限制实验范围
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: safe-pod-chaos
spec:
  # 限制只能在非关键命名空间执行
  selector:
    namespaces:
    - production-non-critical
    # 排除关键服务
    expressionSelectors:
    - key: critical
      operator: NotIn
      values:
      - "true"
  # 限制影响范围
  mode: fixed
  value: "1"              # 最多影响1个Pod
  duration: "30s"         # 限制持续时间

---
# 2. 配置准入控制
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: chaos-mesh-validation
webhooks:
- name: validate.chaos-mesh.org
  rules:
  - apiGroups: ["chaos-mesh.org"]
    apiVersions: ["v1alpha1"]
    operations: ["CREATE", "UPDATE"]
    resources: ["*"]
  # 只允许特定用户创建混沌实验
  namespaceSelector:
    matchLabels:
      chaos-mesh-enabled: "true"
```

## 版本变更记录

| 工具 | 版本 | 变更内容 | 影响 |
|-----|------|---------|------|
| Chaos Mesh | 2.5 | 多集群支持改进 | 跨集群实验 |
| Chaos Mesh | 2.6 | 物理机故障注入 | 扩展到VM |
| Chaos Mesh | 2.7 | HTTPChaos增强 | gRPC支持 |
| LitmusChaos | 3.0 | GitOps模式支持 | CI/CD集成 |
| LitmusChaos | 3.1 | ChaosHub改进 | 实验市场 |

---

**混沌工程原则**: 从小范围开始 → 定义稳态假设 → 自动化持续运行 → 及时回滚机制 → 记录学习改进

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)
