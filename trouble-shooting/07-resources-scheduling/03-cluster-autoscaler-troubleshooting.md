# Cluster Autoscaler 节点自动扩缩容故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32, Cluster Autoscaler v1.25+ | **最后更新**: 2026-01 | **难度**: 高级
>
> **版本说明**:
> - CA 版本需与 K8s 版本对应 (如 CA v1.30.x 对应 K8s v1.30.x)
> - v1.27+ 支持 scale-down-delay-after-add 等细粒度配置
> - v1.29+ 改进的 GPU 节点缩容安全性
> - 支持云厂商: AWS, GCP, Azure, AliCloud, 及自定义 cloud provider

---

## 第一部分：问题现象与影响分析

### 1.1 Cluster Autoscaler 架构

```
┌──────────────────────────────────────────────────────────────────────────┐
│                      Cluster Autoscaler                                  │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌────────────────────────────────────────────────────────────────┐    │
│   │                    Main Control Loop                            │    │
│   │                                                                 │    │
│   │  ┌─────────────┐   ┌─────────────┐   ┌─────────────────────┐  │    │
│   │  │  扩容检测   │   │  缩容检测   │   │    节点组管理       │  │    │
│   │  │  Scale Up   │   │  Scale Down │   │  Node Group Manager │  │    │
│   │  │             │   │             │   │                     │  │    │
│   │  │ 检测 Pending│   │ 检测空闲    │   │ - AWS ASG           │  │    │
│   │  │ Pod         │   │ 节点        │   │ - GCP MIG           │  │    │
│   │  └──────┬──────┘   └──────┬──────┘   │ - Azure VMSS        │  │    │
│   │         │                 │          │ - 阿里云 ESS        │  │    │
│   │         │                 │          └─────────────────────┘  │    │
│   │         │                 │                    │               │    │
│   └─────────┼─────────────────┼────────────────────┼───────────────┘    │
│             │                 │                    │                     │
│             ▼                 ▼                    ▼                     │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                     Cloud Provider API                           │   │
│   │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │   │
│   │  │   AWS    │  │   GCP    │  │  Azure   │  │  阿里云/其他云   │ │   │
│   │  │ EC2 ASG  │  │ GCE MIG  │  │  VMSS    │  │  弹性伸缩       │ │   │
│   │  └──────────┘  └──────────┘  └──────────┘  └──────────────────┘ │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

扩容决策流程:
┌────────────────┐
│  Pod Pending   │
│  (Unschedulable)│
└───────┬────────┘
        │
        ▼
┌────────────────┐     否      ┌────────────────┐
│ 是否因资源不足 │ ──────────> │  忽略该 Pod    │
│ 无法调度?      │             │ (其他原因Pending)│
└───────┬────────┘             └────────────────┘
        │ 是
        ▼
┌────────────────┐
│  模拟添加节点  │
│  是否能调度?   │
└───────┬────────┘
        │ 是
        ▼
┌────────────────┐     否      ┌────────────────┐
│  节点组是否    │ ──────────> │  无法扩容      │
│  允许扩容?     │             │  (达到上限)    │
└───────┬────────┘             └────────────────┘
        │ 是
        ▼
┌────────────────┐
│  调用云 API    │
│  增加节点数量  │
└───────┬────────┘
        │
        ▼
┌────────────────┐
│  等待节点 Ready│
│  重新调度 Pod  │
└────────────────┘

缩容决策流程:
┌────────────────┐
│  扫描所有节点  │
└───────┬────────┘
        │
        ▼
┌────────────────────────────────────────────────┐
│  节点是否满足缩容条件?                         │
│  - 利用率 < 阈值 (默认 50%)                    │
│  - 所有 Pod 可迁移                             │
│  - 无阻止缩容的 annotation                     │
│  - 非 Master/系统节点                          │
└───────┬────────────────────────────────────────┘
        │ 是
        ▼
┌────────────────┐
│  标记为缩容    │
│  候选节点      │
└───────┬────────┘
        │
        ▼
┌────────────────┐
│  等待冷却期    │
│ (scale-down-   │
│  unneeded-time)│
└───────┬────────┘
        │
        ▼
┌────────────────┐
│  驱逐 Pod      │
│  删除节点      │
└────────────────┘
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 错误信息 | 查看方式 |
|----------|----------|----------|----------|
| 不扩容 | Pending Pod 但节点不增加 | 无 | CA 日志、Pod Events |
| 扩容慢 | 节点增加但耗时过长 | 无 | 云平台控制台 |
| 不缩容 | 空闲节点不被删除 | 无 | CA 日志、状态 ConfigMap |
| 缩容导致中断 | Pod 被驱逐后服务不可用 | 无 | Pod Events |
| 云 API 错误 | 无法调用云平台 API | authorization error | CA 日志 |
| 节点组配置错误 | 节点组未被发现 | node group not found | CA 日志 |
| 扩容到错误节点组 | Pod 调度到非预期节点 | 无 | Pod 所在节点 |
| 达到配额限制 | 无法创建更多节点 | quota exceeded | CA 日志、云平台 |

### 1.3 影响分析

| 问题类型 | 直接影响 | 间接影响 | 影响范围 |
|----------|----------|----------|----------|
| 不扩容 | Pending Pod 无法运行 | 业务无法扩展 | 所有需要资源的新 Pod |
| 扩容慢 | 业务响应延迟 | 用户体验下降 | 等待扩容的工作负载 |
| 不缩容 | 资源浪费、成本增加 | 预算超支 | 财务/成本 |
| 过度缩容 | 服务可用性下降 | SLA 违约 | 受影响的服务 |
| 云 API 故障 | 完全无法扩缩容 | 集群弹性丧失 | 整个集群 |

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
Cluster Autoscaler 问题
        │
        ▼
┌───────────────────────┐
│  问题类型是什么？      │
└───────────────────────┘
        │
        ├── 不扩容 ───────────────────────────────────────────┐
        │                                                      │
        │   ┌─────────────────────────────────────────┐       │
        │   │ 检查 CA Pod 是否运行                    │       │
        │   │ kubectl get pods -n kube-system | grep  │       │
        │   │ cluster-autoscaler                      │       │
        │   └─────────────────────────────────────────┘       │
        │                  │                                   │
        │                  ▼                                   │
        │   ┌─────────────────────────────────────────┐       │
        │   │ CA 运行正常?                            │       │
        │   └─────────────────────────────────────────┘       │
        │          │                │                          │
        │         否               是                          │
        │          │                │                          │
        │          ▼                ▼                          │
        │   ┌────────────┐   ┌────────────────┐               │
        │   │ 检查 CA    │   │ Pending Pod    │               │
        │   │ 部署和配置 │   │ 是否因资源不足 │               │
        │   └────────────┘   │ 无法调度?      │               │
        │                    └────────────────┘               │
        │                           │                          │
        │                           ▼                          │
        │                    ┌────────────────┐               │
        │                    │ 检查节点组配置 │               │
        │                    │ 和云 API 权限  │               │
        │                    └────────────────┘               │
        │                                                      │
        ├── 不缩容 ───────────────────────────────────────────┤
        │                                                      │
        │   ┌─────────────────────────────────────────┐       │
        │   │ 检查节点是否满足缩容条件                │       │
        │   │ 1. 利用率是否低于阈值                   │       │
        │   │ 2. Pod 是否可迁移                       │       │
        │   │ 3. 是否有阻止缩容的 annotation          │       │
        │   └─────────────────────────────────────────┘       │
        │                  │                                   │
        │                  ▼                                   │
        │   ┌─────────────────────────────────────────┐       │
        │   │ 检查 CA 状态 ConfigMap                  │       │
        │   │ kubectl get cm cluster-autoscaler-status│       │
        │   └─────────────────────────────────────────┘       │
        │                                                      │
        ├── 云 API 错误 ──────────────────────────────────────┤
        │                                                      │
        │   ┌─────────────────────────────────────────┐       │
        │   │ 检查 CA 日志中的 API 错误               │       │
        │   │ kubectl logs -l app=cluster-autoscaler  │       │
        │   └─────────────────────────────────────────┘       │
        │                  │                                   │
        │                  ▼                                   │
        │   ┌─────────────────────────────────────────┐       │
        │   │ 验证云凭证和 IAM 权限                   │       │
        │   └─────────────────────────────────────────┘       │
        │                                                      │
        └── 配置问题 ─────────────────────────────────────────┤
                                                               │
            ┌─────────────────────────────────────────┐       │
            │ 检查 CA 启动参数和配置                  │       │
            │ - --nodes 参数                          │       │
            │ - --scale-down-* 参数                   │       │
            │ - --expander 策略                       │       │
            └─────────────────────────────────────────┘       │
                                                               │
                                                               ▼
                                                        ┌────────────┐
                                                        │ 问题定位   │
                                                        │ 完成       │
                                                        └────────────┘
```

### 2.2 排查命令集

#### CA 状态检查

```bash
# 检查 CA Pod 状态
kubectl get pods -n kube-system -l app=cluster-autoscaler
kubectl get pods -n kube-system | grep -i autoscaler

# 查看 CA 日志
kubectl logs -n kube-system -l app=cluster-autoscaler --tail=200
kubectl logs -n kube-system -l app=cluster-autoscaler -f

# 查看 CA 状态 ConfigMap (如果启用)
kubectl get cm cluster-autoscaler-status -n kube-system -o yaml

# 检查 CA Deployment 配置
kubectl get deployment cluster-autoscaler -n kube-system -o yaml

# 查看 CA 版本
kubectl get deployment cluster-autoscaler -n kube-system -o jsonpath='{.spec.template.spec.containers[0].image}'
```

#### Pending Pod 分析

```bash
# 查找因资源不足 Pending 的 Pod
kubectl get pods -A --field-selector=status.phase=Pending

# 查看 Pending 原因
kubectl describe pod <pending-pod> | grep -A10 "Events"

# 检查调度失败原因
kubectl get events -A --field-selector reason=FailedScheduling

# 模拟调度检查
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory

# 检查节点资源使用
kubectl top nodes
```

#### 节点组检查

```bash
# 查看所有节点及标签
kubectl get nodes --show-labels

# 检查节点所属的节点组 (AWS)
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.eks\.amazonaws\.com/nodegroup}{"\n"}{end}'

# 检查节点所属的节点组 (GCP)
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.cloud\.google\.com/gke-nodepool}{"\n"}{end}'

# 查看节点的 CA 注解
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, annotations: .metadata.annotations | with_entries(select(.key | startswith("cluster-autoscaler")))}'
```

#### 缩容检查

```bash
# 检查节点是否有阻止缩容的 annotation
kubectl get nodes -o json | jq '.items[] | select(.metadata.annotations."cluster-autoscaler.kubernetes.io/scale-down-disabled" == "true") | .metadata.name'

# 检查节点上的 Pod 是否阻止缩容
kubectl get pods -A -o wide --field-selector spec.nodeName=<node-name>

# 检查 PDB
kubectl get pdb -A

# 查看节点资源利用率
kubectl top node <node-name>
```

### 2.3 排查注意事项

| 注意事项 | 说明 | 风险等级 |
|----------|------|----------|
| CA 配置变更需重启 | 修改启动参数后需要重启 CA Pod | 低 |
| 缩容会驱逐 Pod | 确保 PDB 和副本数配置正确 | 高 |
| 节点组最小值设置 | 设为 0 可能导致完全缩容 | 高 |
| 云 API 配额限制 | 频繁扩缩可能触发配额限制 | 中 |
| 扩容有延迟 | 新节点启动需要几分钟 | 低 |

## 第三部分：解决方案与风险控制

### 3.1 CA 不扩容 - Pod Pending

**问题现象**：有 Pending Pod 但集群不自动添加节点。

**解决步骤**：

```bash
# 步骤 1: 确认 CA 正在运行
kubectl get pods -n kube-system -l app=cluster-autoscaler

# 步骤 2: 检查 Pending Pod 的原因
kubectl describe pod <pending-pod>
# 关注 Events 中的 FailedScheduling 原因

# 步骤 3: 确认是资源不足导致的 Pending
# 如果原因是 nodeSelector/affinity 不匹配，CA 不会扩容
# 如果原因是 Insufficient cpu/memory，CA 应该扩容

# 步骤 4: 检查 CA 日志
kubectl logs -n kube-system -l app=cluster-autoscaler | grep -i "scale up\|unschedulable"

# 步骤 5: 检查节点组配置
# 确认节点组最大值未达到上限
kubectl logs -n kube-system -l app=cluster-autoscaler | grep -i "max size\|target size"

# 步骤 6: 验证云 API 权限
kubectl logs -n kube-system -l app=cluster-autoscaler | grep -i "error\|failed\|unauthorized"
```

**常见原因与解决**：

```bash
# 原因 1: Pod 有 nodeSelector 但无对应节点组
# 解决: 创建带有对应标签的节点组

# 原因 2: 节点组已达最大值
# 解决: 增加节点组最大值
# 在云平台控制台或 CA 配置中修改

# 原因 3: Pod 请求的资源超过单节点容量
# 检查 Pod 资源请求
kubectl get pod <pod> -o yaml | grep -A5 "resources:"
# 解决: 减少资源请求或使用更大实例类型

# 原因 4: CA 未配置该节点组
# 检查 CA 启动参数
kubectl get deployment cluster-autoscaler -n kube-system -o yaml | grep -A20 "args:"
```

### 3.2 扩容到错误的节点组

**问题现象**：Pod 被调度到非预期的节点组。

**解决步骤**：

```bash
# 步骤 1: 检查 CA 的 expander 策略
kubectl get deployment cluster-autoscaler -n kube-system -o yaml | grep expander
# 默认是 random，可能导致随机选择节点组

# 步骤 2: 配置合适的 expander 策略
# 可选: random, most-pods, least-waste, price, priority
```

**配置 priority expander**：

```yaml
# ConfigMap for priority expander
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-autoscaler-priority-expander
  namespace: kube-system
data:
  priorities: |-
    10:
      - .*spot.*           # 优先使用 spot 实例
    50:
      - .*standard.*       # 其次使用标准实例

---
# CA Deployment 添加参数
# --expander=priority
# --expenderpriority-ds-config-map=cluster-autoscaler-priority-expander
```

```bash
# 步骤 3: 使用 nodeSelector 或 nodeAffinity 精确控制
kubectl get pod <pod> -o yaml | grep -A10 "nodeSelector\|affinity"
```

**Pod 节点亲和性示例**：

```yaml
apiVersion: v1
kind: Pod
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-type
            operator: In
            values:
            - gpu  # 指定调度到 gpu 节点组
```

### 3.3 CA 不缩容 - 节点空闲

**问题现象**：节点利用率很低但不被删除。

**解决步骤**：

```bash
# 步骤 1: 检查节点利用率
kubectl top nodes
# 默认缩容阈值是 50%

# 步骤 2: 检查是否有阻止缩容的原因
kubectl logs -n kube-system -l app=cluster-autoscaler | grep -i "scale down\|cannot\|blocking"

# 步骤 3: 检查节点上的 Pod
kubectl get pods -A -o wide --field-selector spec.nodeName=<node>

# 步骤 4: 常见阻止缩容的原因

# 原因 1: 节点有 annotation 阻止缩容
kubectl get node <node> -o yaml | grep "scale-down-disabled"
# 解决: 移除 annotation
kubectl annotate node <node> cluster-autoscaler.kubernetes.io/scale-down-disabled-

# 原因 2: 有无法迁移的 Pod (本地存储)
kubectl get pods -A -o wide --field-selector spec.nodeName=<node> -o json | jq '.items[] | select(.spec.volumes[]?.emptyDir != null or .spec.volumes[]?.hostPath != null) | .metadata.name'

# 原因 3: Pod 有 PodDisruptionBudget 阻止驱逐
kubectl get pdb -A

# 原因 4: Pod 有 annotation 阻止驱逐
kubectl get pods -A -o json | jq '.items[] | select(.metadata.annotations."cluster-autoscaler.kubernetes.io/safe-to-evict" == "false") | .metadata.name'

# 原因 5: 系统 Pod (kube-system) 阻止缩容
# CA 默认不缩容有 kube-system Pod 的节点 (可配置)
```

**允许缩容的 Pod annotation**：

```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    # 明确允许驱逐
    cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
```

### 3.4 云 API 权限错误

**问题现象**：CA 日志显示云 API 调用失败。

**解决步骤**：

```bash
# 步骤 1: 检查 CA 日志中的错误
kubectl logs -n kube-system -l app=cluster-autoscaler | grep -i "error\|forbidden\|unauthorized"

# 步骤 2: 根据云平台检查权限
```

**AWS IAM 权限示例**：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags",
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:DescribeInstanceTypes"
      ],
      "Resource": "*"
    }
  ]
}
```

**GCP IAM 角色**：

```bash
# 需要的角色
# - roles/compute.instanceGroupManager
# - roles/compute.instances.admin

# 检查服务账号
kubectl get deployment cluster-autoscaler -n kube-system -o jsonpath='{.spec.template.spec.serviceAccountName}'
```

**阿里云 RAM 权限**：

```json
{
  "Version": "1",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ess:Describe*",
        "ess:ModifyScalingGroup",
        "ecs:DescribeInstances"
      ],
      "Resource": "*"
    }
  ]
}
```

### 3.5 扩容延迟过长

**问题现象**：触发扩容后，新节点很长时间才能使用。

**解决步骤**：

```bash
# 步骤 1: 分析延迟来源
# a. CA 检测到需要扩容的时间
# b. 云 API 创建实例的时间
# c. 节点启动和注册到集群的时间
# d. 节点变为 Ready 的时间

# 步骤 2: 检查 CA 扫描间隔
kubectl get deployment cluster-autoscaler -n kube-system -o yaml | grep scan-interval
# 默认 10s

# 步骤 3: 减少节点启动时间
# 使用预热的 AMI/镜像
# 减少 cloud-init 脚本
# 使用更快的实例类型

# 步骤 4: 考虑 over-provisioning
# 保持一些空闲节点用于快速调度
```

**Over-provisioning 示例**：

```yaml
# 低优先级 placeholder Pod，占用资源但可被抢占
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: overprovisioning
value: -1  # 最低优先级
globalDefault: false
description: "Priority class for overprovisioning"

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: overprovisioning
  namespace: kube-system
spec:
  replicas: 3
  selector:
    matchLabels:
      app: overprovisioning
  template:
    metadata:
      labels:
        app: overprovisioning
    spec:
      priorityClassName: overprovisioning
      containers:
      - name: pause
        image: k8s.gcr.io/pause:3.9
        resources:
          requests:
            cpu: "1"      # 预留资源
            memory: "1Gi"
```

### 3.6 缩容导致服务中断

**问题现象**：缩容时 Pod 被驱逐导致服务不可用。

**解决步骤**：

```bash
# 步骤 1: 确保有足够的副本数
kubectl get deployment <name> -o jsonpath='{.spec.replicas}'

# 步骤 2: 配置 PodDisruptionBudget
```

**PDB 配置示例**：

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  minAvailable: 2  # 或使用 maxUnavailable: 1
  selector:
    matchLabels:
      app: my-app
```

```bash
# 步骤 3: 配置 Pod 反亲和性，避免同节点
```

**Pod 反亲和性示例**：

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: my-app
              topologyKey: kubernetes.io/hostname
```

```bash
# 步骤 4: 调整 CA 缩容参数
# --scale-down-delay-after-add: 扩容后多久才能缩容 (默认 10m)
# --scale-down-delay-after-delete: 删除节点后多久才能再删除 (默认 0)
# --scale-down-unneeded-time: 节点空闲多久才被删除 (默认 10m)
```

### 3.7 节点组未被发现

**问题现象**：CA 日志显示无法找到节点组。

**解决步骤**：

```bash
# 步骤 1: 检查 CA 配置的节点组
kubectl get deployment cluster-autoscaler -n kube-system -o yaml | grep -A5 "\-\-nodes"

# 步骤 2: 验证节点组标签/标记
# AWS: 检查 ASG 标签
# k8s.io/cluster-autoscaler/enabled = true
# k8s.io/cluster-autoscaler/<cluster-name> = owned

# 步骤 3: 使用 autodiscovery 模式 (推荐)
```

**autodiscovery 配置示例**：

```yaml
# AWS EKS
containers:
- command:
  - ./cluster-autoscaler
  - --cloud-provider=aws
  - --namespace=kube-system
  - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled=true,k8s.io/cluster-autoscaler/<cluster-name>=owned
  - --balance-similar-node-groups
  - --skip-nodes-with-system-pods=false
```

### 3.8 安全生产风险提示

| 操作 | 风险等级 | 潜在风险 | 建议措施 |
|------|----------|----------|----------|
| 设置节点组最小值为 0 | 高 | 可能缩容所有节点 | 至少保留 1-2 个节点 |
| 快速缩容配置 | 高 | 服务中断 | 配置合适的 PDB |
| 修改 CA 配置 | 中 | 短暂扩缩异常 | 选择低峰期 |
| 云 API 权限变更 | 中 | CA 无法工作 | 先测试再应用 |
| 使用 spot/抢占式实例 | 中 | 可能被回收 | 配置 on-demand 节点组兜底 |
| 启用激进缩容 | 高 | Pod 频繁驱逐 | 充分测试 |

### 附录：快速诊断命令

```bash
# ===== Cluster Autoscaler 一键诊断脚本 =====

echo "=== CA Pod 状态 ==="
kubectl get pods -n kube-system -l app=cluster-autoscaler

echo -e "\n=== Pending Pods ==="
kubectl get pods -A --field-selector=status.phase=Pending | head -20

echo -e "\n=== 节点资源使用 ==="
kubectl top nodes 2>/dev/null || echo "metrics-server 未安装"

echo -e "\n=== 节点组信息 ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,INSTANCE-TYPE:.metadata.labels."node\.kubernetes\.io/instance-type"

echo -e "\n=== CA 最近日志 ==="
kubectl logs -n kube-system -l app=cluster-autoscaler --tail=20 2>/dev/null | grep -i "scale\|error" | tail -10

echo -e "\n=== 阻止缩容的节点 ==="
kubectl get nodes -o json | jq -r '.items[] | select(.metadata.annotations["cluster-autoscaler.kubernetes.io/scale-down-disabled"] == "true") | .metadata.name'

echo -e "\n=== PDB 配置 ==="
kubectl get pdb -A
```

### 附录：CA 常用启动参数

```yaml
# Cluster Autoscaler Deployment 常用参数
containers:
- command:
  - ./cluster-autoscaler
  - --cloud-provider=aws  # 云提供商: aws, gce, azure, alicloud
  - --namespace=kube-system
  
  # 节点发现
  - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled=true
  # 或手动指定
  # - --nodes=1:10:my-asg-name
  
  # 扩容配置
  - --scale-down-enabled=true
  - --scale-down-delay-after-add=10m      # 扩容后多久可以缩容
  - --scale-down-delay-after-delete=0s    # 删除后多久可以再删除
  - --scale-down-delay-after-failure=3m   # 失败后多久重试
  - --scale-down-unneeded-time=10m        # 空闲多久才删除
  - --scale-down-utilization-threshold=0.5  # 利用率阈值
  
  # 扩容策略
  - --expander=least-waste  # random, most-pods, least-waste, price, priority
  - --balance-similar-node-groups=true
  
  # 系统配置
  - --skip-nodes-with-system-pods=false   # 是否跳过有系统 Pod 的节点
  - --skip-nodes-with-local-storage=false # 是否跳过有本地存储的节点
  - --scan-interval=10s                   # 扫描间隔
  - --max-node-provision-time=15m         # 最大节点准备时间
  
  # 日志
  - --v=4
```
