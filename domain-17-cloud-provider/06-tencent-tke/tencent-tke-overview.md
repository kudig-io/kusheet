# 腾讯云 TKE (Tencent Kubernetes Engine) 概述

## 产品简介

腾讯云 Kubernetes 服务(TKE)是腾讯云提供的托管容器服务，基于腾讯内部海量业务实践经验，为企业提供高性能、高可靠的容器化应用部署和管理平台。TKE承载了腾讯内部包括微信、QQ、王者荣耀等核心业务的容器化部署，具备处理亿级用户并发的能力。

> **官方文档**: [TKE 官方文档](https://cloud.tencent.com/document/product/457)
> **发布时间**: 2018年
> **最新版本**: Kubernetes 1.28 (2024年支持)
> **服务规模**: 支持万级节点、十万级Pod的大规模集群

## 产品架构深度解析

### 控制平面架构

TKE 提供三种集群管理模式，满足不同场景需求：

**托管集群 (Managed Cluster)**
- 腾讯云完全托管控制平面基础设施
- 控制平面跨三个可用区高可用部署
- 自动故障检测、切换和恢复机制
- 支持私有网络和公网访问端点
- 99.95% SLA可用性承诺

**独立集群 (Independent Cluster)**
- 用户自管理控制平面，更高的安全隔离性
- 适用于金融、政务等特殊合规要求场景
- 支持混合云和跨云部署
- 可与腾讯云其他服务深度集成

**超级节点集群 (Super Node Cluster)**
- 无服务器计算模式，无需管理底层节点
- 按Pod资源使用量计费，成本优化显著
- 适合突发性、批处理类工作负载
- 自动弹性伸缩，秒级响应

### 节点管理架构

**节点池管理**
- 支持多种实例规格家族(SA、SR、SC、SD系列)
- 自动节点扩缩容(Cluster Autoscaler集成)
- Spot实例支持，最高可节省80%成本
- 节点自动修复和升级机制
- GPU节点池专门优化AI/ML工作负载

**网络架构**
- VPC-CNI网络插件，每个Pod获得独立VPC IP
- 支持Kubernetes NetworkPolicy网络策略
- 高性能网络转发，延迟低于1ms
- 支持IPv4/IPv6双栈网络
- 与腾讯云负载均衡、安全组深度集成

### 存储架构
- **CBS云硬盘**: 高性能块存储，支持SSD、高性能SSD
- **CFS文件存储**: NFS协议文件共享，支持POSIX语义
- **COS对象存储**: 通过CSI驱动集成，适合大文件存储
- **本地存储**: 高性能本地NVMe SSD，适合数据库场景

## 生产环境部署最佳实践

### 集群规划与设计

**多环境分层架构**
```
├── 开发环境 (dev-cluster)
│   ├── 单可用区部署，节约成本
│   ├── SA2.SMALL2节点 (1核2GB)
│   ├── 基础监控配置(云监控+CFS日志)
│   └── 公网访问端点，便于调试
├── 测试环境 (test-cluster)
│   ├── 多可用区部署(2AZ)
│   ├── SA3.MEDIUM4节点 (2核4GB)
│   ├── 增强监控告警(自定义指标)
│   ├── 私网访问端点+堡垒机
│   └── 自动化测试流水线集成
└── 生产环境 (prod-cluster)
    ├── 三可用区高可用架构(3AZ)
    ├── SA4.LARGE8/SA5.LARGE16混合节点
    ├── 完整安全加固(网络策略+RBAC+审计)
    ├── 全面可观测性(Prometheus+Grafana+APM)
    ├── 灾备容灾配置(跨地域备份+故障转移)
    └── 业务连续性保障(SLA 99.95%)
```

**节点规格选型矩阵**

| 工作负载类型 | 推荐实例规格 | 配置详情 | 适用场景 | 成本优化建议 |
|-------------|-------------|---------|---------|-------------|
| Web应用/API | SA3.MEDIUM4 | 2核4GB RAM, 50GB系统盘 | 标准Web服务、API网关 | 使用Spot实例节省30-50% |
| 微服务治理 | SA4.LARGE8 | 4核8GB RAM, 100GB系统盘 | 高并发微服务应用 | 混合使用按量+预留实例 |
| 数据库中间件 | SR1.LARGE8 | 4核32GB RAM, 100GB高性能SSD | MySQL、Redis、ES等 | 使用本地SSD提升IOPS |
| AI推理服务 | SC3.LARGE8 + GPU | 4核8GB + T4/V100 GPU | 模型推理、图像处理 | GPU节点池按需扩容 |
| 大数据计算 | SD3.LARGE8 | 4核8GB + 本地NVMe SSD | Spark、Kafka、Flink | 利用本地存储降低延时 |
| 批处理任务 | Spot实例池 | 多种规格混合 | 日志分析、数据ETL | Spot实例节省60-80%成本 |

### 安全加固配置

**网络策略实施**
```yaml
# 生产环境网络策略 - 零信任安全模型
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: production-default-deny
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# 允许特定服务间通信
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 3306
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090  # Prometheus
```

**RBAC最小权限配置**
```yaml
# 生产环境ServiceAccount最小权限配置
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-prod-sa
  namespace: production
  annotations:
    tke.cloud.tencent.com/role-arn: qcs::cam::uin/12345678:roleName/app-role
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: app-minimal-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["create", "get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-rolebinding
  namespace: production
subjects:
- kind: ServiceAccount
  name: app-prod-sa
roleRef:
  kind: Role
  name: app-minimal-role
  apiGroup: rbac.authorization.k8s.io
```

**安全组和访问控制**
```bash
# 生产环境安全组配置脚本
#!/bin/bash
# TKE安全组最佳实践配置

REGION="ap-beijing"
CLUSTER_ID="cls-xxxxxxxx"
VPC_ID="vpc-xxxxxxxx"

# 创建安全组
tccli vpc CreateSecurityGroup \
    --GroupName "tke-prod-sg" \
    --GroupDescription "Production TKE cluster security group"

SG_ID=$(tccli vpc DescribeSecurityGroups \
    --Filters.0.Name "group-name" \
    --Filters.0.Values.0 "tke-prod-sg" \
    --query "SecurityGroupSet[0].SecurityGroupId" \
    --output text)

# 配置入站规则
tccli vpc CreateSecurityGroupPolicies \
    --SecurityGroupId $SG_ID \
    --SecurityGroupPolicySet.Ingress.0.Protocol "TCP" \
    --SecurityGroupPolicySet.Ingress.0.Port "443" \
    --SecurityGroupPolicySet.Ingress.0.CidrBlock "0.0.0.0/0" \
    --SecurityGroupPolicySet.Ingress.0.Action "ACCEPT" \
    --SecurityGroupPolicySet.Ingress.0.PolicyDescription "Kubernetes API Server"

# 配置出站规则
tccli vpc CreateSecurityGroupPolicies \
    --SecurityGroupId $SG_ID \
    --SecurityGroupPolicySet.Egress.0.Protocol "ALL" \
    --SecurityGroupPolicySet.Egress.0.CidrBlock "0.0.0.0/0" \
    --SecurityGroupPolicySet.Egress.0.Action "ACCEPT" \
    --SecurityGroupPolicySet.Egress.0.PolicyDescription "Allow all outbound traffic"
```

### 监控告警体系

**核心监控指标配置**
```yaml
# Prometheus监控配置 - TKE生产环境
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "tke-rules.yaml"

scrape_configs:
  # Kubernetes组件监控
  - job_name: 'kubernetes-apiservers'
    kubernetes_sd_configs:
    - role: endpoints
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
    - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
      action: keep
      regex: default;kubernetes;https

  # 节点监控
  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
    - role: node
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
    - action: labelmap
      regex: __meta_kubernetes_node_label_(.+)
```

**关键告警规则**
```yaml
# TKE核心告警规则
groups:
- name: tke.production.alerts
  rules:
  # 集群健康告警
  - alert: TKEClusterDown
    expr: up{job="kubernetes-apiservers"} == 0
    for: 2m
    labels:
      severity: critical
      team: sre
    annotations:
      summary: "TKE集群不可用"
      description: "集群 {{ $labels.cluster }} 的API Server已经宕机超过2分钟"

  # 节点资源告警
  - alert: NodeCPUUsageHigh
    expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
    for: 5m
    labels:
      severity: warning
      team: sre
    annotations:
      summary: "节点CPU使用率过高"
      description: "节点 {{ $labels.instance }} 的CPU使用率超过85%"

  # Pod异常告警
  - alert: PodCrashLooping
    expr: rate(kube_pod_container_status_restarts_total[5m]) * 60 * 5 > 0
    for: 5m
    labels:
      severity: critical
      team: app
    annotations:
      summary: "Pod频繁重启"
      description: "Pod {{ $labels.pod }} 在5分钟内重启次数过多"

  # 存储空间告警
  - alert: PersistentVolumeUsageHigh
    expr: kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes * 100 > 90
    for: 10m
    labels:
      severity: warning
      team: sre
    annotations:
      summary: "持久卷使用率过高"
      description: "PV {{ $labels.persistentvolumeclaim }} 使用率超过90%"
```

**腾讯云监控集成**
```bash
#!/bin/bash
# TKE监控告警配置脚本

CLUSTER_ID="cls-xxxxxxxx"
NAMESPACE="production"

# 创建告警策略
tccli monitor CreateAlarmPolicy \
    --PolicyName "tke-prod-critical-alerts" \
    --MonitorType "MT_QCE" \
    --Namespace "qce/tke" \
    --Conditions.0.MetricName "KubeAPIServerDown" \
    --Conditions.0.Period 60 \
    --Conditions.0.Operator eq \
    --Conditions.0.Value 0 \
    --EventConditions.0.MetricName "NodeNotReady" \
    --EventConditions.0.Period 300 \
    --EventConditions.0.Operator gt \
    --EventConditions.0.Value 0 \
    --NoticeIds notice-xxxxxx

# 配置告警接收人
tccli monitor BindingAlarmPolicyObject \
    --Module "monitor" \
    --GroupId "group-xxxxxx" \
    --PolicyId "policy-xxxxxx" \
    --Instances.0.Dimensions.0.Key "clusterId" \
    --Instances.0.Dimensions.0.Value "$CLUSTER_ID"
```

### 成本优化策略

**混合实例策略配置**
```yaml
# TKE混合实例节点池配置
apiVersion: ccsgroup.cloud.tencent.com/v1beta1
kind: NodePool
metadata:
  name: cost-optimized-pool
  namespace: kube-system
spec:
  type: managed
  scalingGroup:
    # 按量付费实例(稳定工作负载)
    instanceType: SA4.LARGE8
    systemDiskSize: 100
    systemDiskType: CLOUD_PREMIUM
    
    # Spot实例(弹性工作负载)
    spotInstanceType: SA3.MEDIUM4
    spotStrategy: SPOT_AS_PRICE_GO
    spotMaxPrice: "0.5"
    
    # 混合比例配置
    minSize: 5
    maxSize: 50
    desiredSize: 10
    
    # 标签和污点
    labels:
      node-type: mixed
      cost-optimized: "true"
    taints:
    - key: spot-instance
      value: "true"
      effect: NoSchedule
      
    # 自动扩缩容配置
    autoScaling:
      enabled: true
      scaleDownDelay: 10m
      scaleUpDelay: 2m
```

**资源配额和限制管理**
```yaml
# 生产环境资源配额管理
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-resource-quota
  namespace: production
spec:
  hard:
    # CPU资源限制
    requests.cpu: "100"
    limits.cpu: "200"
    
    # 内存资源限制
    requests.memory: 200Gi
    limits.memory: 400Gi
    
    # 存储资源限制
    requests.storage: 5Ti
    persistentvolumeclaims: "200"
    
    # 服务资源限制
    services.loadbalancers: "50"
    services.nodeports: "20"
    
    # 对象数量限制
    pods: "5000"
    configmaps: "1000"
    secrets: "1000"

---
# LimitRange配置 - 默认资源请求和限制
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limit-range
  namespace: production
spec:
  limits:
  - type: Container
    default:
      cpu: "1"
      memory: 1Gi
    defaultRequest:
      cpu: "100m"
      memory: 128Mi
    max:
      cpu: "8"
      memory: 16Gi
    min:
      cpu: "10m"
      memory: 4Mi
```

**成本分析和优化脚本**
```bash
#!/bin/bash
# TKE成本分析和优化工具

CLUSTER_ID="cls-xxxxxxxx"
REGION="ap-beijing"

echo "=== TKE集群成本分析报告 ==="
echo "集群ID: $CLUSTER_ID"
echo "分析时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# 获取集群基本信息
CLUSTER_INFO=$(tccli tke DescribeClusterDetail --ClusterId $CLUSTER_ID)
CLUSTER_NAME=$(echo $CLUSTER_INFO | jq -r '.ClusterName')
NODE_COUNT=$(echo $CLUSTER_INFO | jq -r '.ClusterNodeNum')

echo "集群名称: $CLUSTER_NAME"
echo "节点数量: $NODE_COUNT"
echo

# 分析节点成本
echo "=== 节点成本分析 ==="
tccli tke DescribeClusterInstances --ClusterId $CLUSTER_ID | jq -r '
.Clusters[] | 
"实例ID: \(.InstanceId) | 规格: \(.InstanceType) | 状态: \(.InstanceState) | 创建时间: \(.CreatedTime)"'

# Spot实例使用情况
SPOT_INSTANCES=$(tccli tke DescribeClusterInstances --ClusterId $CLUSTER_ID | jq '[.Clusters[] | select(.InstanceChargeType=="SPOT_PAID")] | length')
echo "Spot实例数量: $SPOT_INSTANCES"

# 成本优化建议
echo
echo "=== 成本优化建议 ==="
echo "1. 检查是否有长时间空闲的节点可以缩减"
echo "2. 考虑将部分工作负载迁移到Spot实例"
echo "3. 优化Pod的资源请求和限制配置"
echo "4. 启用水平Pod自动扩缩容(HPA)"
echo "5. 定期清理不再使用的资源"

# 生成优化配置建议
cat << EOF > cost-optimization-recommendations.yaml
# TKE成本优化建议配置

# 1. 启用Cluster Autoscaler
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: cluster-autoscaler
        image: ccr.ccs.tencentyun.com/library/cluster-autoscaler:v1.20.0
        command:
        - ./cluster-autoscaler
        - --cloud-provider=tencentcloud
        - --nodes=1:50:node-pool-name
        - --scale-down-delay-after-add=10m
        - --scale-down-unneeded-time=10m

# 2. 配置HPA
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
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
EOF

echo "优化配置建议已保存到: cost-optimization-recommendations.yaml"
```

## 故障排查与应急响应

### 常见问题诊断流程

**节点状态异常排查**
```bash
#!/bin/bash
# TKE节点状态异常诊断脚本

NODE_NAME=$1
CLUSTER_ID="cls-xxxxxxxx"

echo "=== TKE节点状态诊断: $NODE_NAME ==="

# 1. 检查节点基本信息
echo "1. 节点基本信息检查..."
kubectl describe node $NODE_NAME | grep -E "(Conditions|Addresses|Capacity|Allocatable)"

# 2. 检查节点组件状态
echo "2. 节点组件状态检查..."
kubectl get pods -n kube-system -o wide | grep $NODE_NAME

# 3. 检查系统资源使用情况
echo "3. 系统资源使用情况..."
kubectl top node $NODE_NAME

# 4. 检查节点事件
echo "4. 节点相关事件..."
kubectl get events --field-selector involvedObject.name=$NODE_NAME --sort-by=.lastTimestamp

# 5. 检查腾讯云节点状态
echo "5. 腾讯云节点状态检查..."
tccli tke DescribeClusterInstances \
    --ClusterId $CLUSTER_ID \
    --InstanceIds.0 $NODE_NAME \
    --query "Clusters[0].{Status: InstanceState, CreatedTime: CreatedTime}"

# 6. 检查网络连通性
echo "6. 网络连通性检查..."
kubectl run debug-pod --image=busybox --restart=Never --rm -it -- ping -c 4 $NODE_NAME

# 7. 检查磁盘空间
echo "7. 磁盘空间检查..."
kubectl debug node/$NODE_NAME -it --image=busybox -- df -h

echo "=== 诊断完成 ==="
```

**Pod调度失败深度分析**
```bash
#!/bin/bash
# TKE Pod调度失败分析工具

POD_NAME=$1
NAMESPACE=${2:-default}

echo "=== TKE Pod调度失败分析: $POD_NAME ==="

# 1. 查看Pod详细信息和事件
echo "1. Pod详细信息和调度事件..."
kubectl describe pod $POD_NAME -n $NAMESPACE

# 2. 检查资源配额和限制
echo "2. 命名空间资源配额检查..."
kubectl describe quota -n $NAMESPACE
kubectl describe limitrange -n $NAMESPACE

# 3. 分析节点资源情况
echo "3. 集群资源使用情况..."
kubectl top nodes
echo "可用节点列表:"
kubectl get nodes -l '!node-role.kubernetes.io/master' --show-labels

# 4. 检查节点选择器和污点容忍
echo "4. 节点选择器和污点容忍检查..."
SELECTOR=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.nodeSelector}')
echo "Node Selector: $SELECTOR"

TOLERATIONS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.tolerations}')
echo "Tolerations: $TOLERATIONS"

# 5. 检查节点污点
echo "5. 集群节点污点情况..."
kubectl get nodes -o jsonpath='{.items[*].spec.taints}' | tr ' ' '\n' | sort | uniq -c

# 6. 模拟调度器决策
echo "6. 模拟调度器决策过程..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: scheduler-test
  namespace: $NAMESPACE
spec:
  containers:
  - name: test
    image: nginx
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
  nodeName: ""  # 空字符串触发调度
EOF

# 清理测试Pod
kubectl delete pod scheduler-test -n $NAMESPACE --ignore-not-found=true

echo "=== 分析完成，请根据上述信息定位调度失败原因 ==="
```

**网络连接问题排查**
```bash
#!/bin/bash
# TKE网络连接问题诊断工具

echo "=== TKE网络连接问题诊断 ==="

# 1. 检查CNI插件状态
echo "1. CNI插件状态检查..."
kubectl get daemonset -n kube-system | grep tke-route-eni
kubectl get pods -n kube-system -l k8s-app=tke-route-eni -o wide

# 2. 验证Pod网络连通性
echo "2. Pod网络连通性测试..."
TEST_POD=$(kubectl get pods -l run=debug -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$TEST_POD" ]; then
    kubectl run debug --image=nicolaka/netshoot --restart=Never -- sleep 3600
    sleep 10
    TEST_POD="debug"
fi

# 测试DNS解析
echo "DNS解析测试:"
kubectl exec $TEST_POD -- nslookup kubernetes.default

# 测试集群内部连接
echo "集群内部连接测试:"
kubectl exec $TEST_POD -- ping -c 4 8.8.8.8

# 3. 检查网络策略
echo "3. 网络策略检查..."
kubectl get networkpolicies --all-namespaces

# 4. 检查安全组配置
echo "4. 安全组配置检查..."
# 这里需要根据实际集群ID查询安全组规则

# 5. 检查路由表
echo "5. 路由表检查..."
kubectl exec $TEST_POD -- ip route

echo "=== 网络诊断完成 ==="
```

### 应急响应预案

**一级故障响应流程 (Critical - 影响核心业务)**
```markdown
## 一级故障响应 (P1 - Critical)

**响应时间要求**: < 15分钟
**影响范围**: 核心业务中断，用户大面积受影响

### 响应流程:

1. **立即响应阶段 (0-5分钟)**
   - SRE值班人员立即响应告警
   - 通知相关技术负责人和业务方
   - 启动War Room应急会议
   - 确认故障影响范围和严重程度

2. **快速诊断阶段 (5-15分钟)**
   - 并行执行多个诊断路径:
     * API Server可用性检查
     * 核心组件状态检查
     * 网络连通性验证
     * 存储系统状态确认
   - 确定故障根本原因
   - 评估服务恢复时间

3. **应急处置阶段 (15-60分钟)**
   - 执行预先制定的应急预案
   - 启用备用系统或降级方案
   - 实施临时修复措施
   - 持续监控服务状态

4. **服务恢复阶段 (60分钟+)**
   - 验证核心功能恢复正常
   - 逐步恢复全部服务能力
   - 监控系统稳定性指标
   - 确认用户体验恢复正常

5. **事后总结阶段**
   - 故障复盘会议
   - 根因分析报告
   - 改进措施制定
   - 预案更新完善
```

**二级故障响应流程 (Major - 影响部分功能)**
```markdown
## 二级故障响应 (P2 - Major)

**响应时间要求**: < 1小时
**影响范围**: 部分功能异常，局部用户受影响

### 响应流程:

1. **问题确认 (0-15分钟)**
   - 记录故障详细信息
   - 分析影响范围和用户群体
   - 评估业务影响程度

2. **方案制定 (15-45分钟)**
   - 技术团队分析故障原因
   - 制定修复方案和技术路线
   - 评审方案可行性和风险
   - 准备回滚计划

3. **分阶段实施 (45分钟-2小时)**
   - 在测试环境验证修复方案
   - 分批次实施修复措施
   - 每个阶段完成后验证效果
   - 根据实际情况调整实施策略

4. **效果验证 (2-4小时)**
   - 监控关键业务指标
   - 验证用户功能正常使用
   - 确认系统性能达标
   - 更新相关文档和知识库

5. **持续改进**
   - 分析故障根本原因
   - 完善监控告警体系
   - 优化应急响应流程
   - 更新技术文档
```

### 自动化运维工具

**集群健康检查自动化脚本**
```bash
#!/bin/bash
# TKE集群自动化健康检查脚本

CLUSTER_ID="cls-xxxxxxxx"
CHECK_TIME=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="/var/log/tke-health-check-${CHECK_TIME}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== TKE集群健康检查报告 ==="
echo "检查时间: $(date)"
echo "集群ID: $CLUSTER_ID"
echo "=========================="

# 1. 集群状态检查
echo "1. 集群状态检查..."
CLUSTER_STATUS=$(tccli tke DescribeClusters \
    --ClusterIds.0 $CLUSTER_ID \
    --query "Clusters[0].ClusterStatus" \
    --output text)

if [ "$CLUSTER_STATUS" != "Running" ]; then
    echo "❌ 集群状态异常: $CLUSTER_STATUS"
    exit 1
else
    echo "✅ 集群状态正常"
fi

# 2. 节点健康检查
echo "2. 节点健康检查..."
kubectl config use-context tke-$CLUSTER_ID

NODE_STATS=$(kubectl get nodes --no-headers | awk '{print $2}' | sort | uniq -c)
echo "节点状态统计:"
echo "$NODE_STATS"

NOT_READY_COUNT=$(kubectl get nodes --no-headers | grep -v Ready | wc -l)
if [ $NOT_READY_COUNT -gt 0 ]; then
    echo "❌ 发现 $NOT_READY_COUNT 个NotReady节点"
    kubectl get nodes | grep -v Ready
else
    echo "✅ 所有节点状态正常"
fi

# 3. 核心组件检查
echo "3. 核心组件检查..."
CORE_COMPONENTS=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "tke-route-eni")
for component in "${CORE_COMPONENTS[@]}"; do
    count=$(kubectl get pods -n kube-system -l component=$component --no-headers 2>/dev/null | grep Running | wc -l)
    if [ $count -gt 0 ]; then
        echo "✅ $component: $count 个实例运行正常"
    else
        echo "❌ $component: 组件异常"
    fi
done

# 4. 资源使用情况检查
echo "4. 资源使用情况检查..."
echo "CPU使用率top 5节点:"
kubectl top nodes | head -6

echo "内存使用率top 5节点:"
kubectl top nodes --sort-by=memory | head -6

# 5. 存储空间检查
echo "5. 存储空间检查..."
kubectl get pv --no-headers | wc -l | xargs echo "PV总数:"
kubectl get pvc --all-namespaces --no-headers | wc -l | xargs echo "PVC总数:"

# 6. 告警状态检查
echo "6. 告警状态检查..."
ACTIVE_ALERTS=$(kubectl get pods -n monitoring -l app=prometheus -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null | grep -c false || echo "0")
if [ $ACTIVE_ALERTS -eq 0 ]; then
    echo "✅ 监控系统运行正常"
else
    echo "⚠️  监控系统存在 $ACTIVE_ALERTS 个活动告警"
fi

# 7. 生成健康报告
HEALTH_SCORE=100

# 根据检查结果扣分
[ $NOT_READY_COUNT -gt 0 ] && HEALTH_SCORE=$((HEALTH_SCORE - 20))
[ "$(echo "$NODE_STATS" | grep -c "SchedulingDisabled")" -gt 0 ] && HEALTH_SCORE=$((HEALTH_SCORE - 10))

echo "=========================="
echo "集群健康评分: $HEALTH_SCORE/100"
echo "检查报告已保存到: $LOG_FILE"

if [ $HEALTH_SCORE -lt 80 ]; then
    echo "⚠️  集群健康状况需要关注"
    exit 1
else
    echo "✅ 集群健康状况良好"
    exit 0
fi
```

**自动化故障恢复脚本**
```bash
#!/bin/bash
# TKE自动化故障恢复工具

CLUSTER_ID="cls-xxxxxxxx"
MAX_RETRY=3

# 故障检测函数
detect_cluster_issues() {
    local issues=()
    
    # 检查API Server响应
    if ! kubectl cluster-info >/dev/null 2>&1; then
        issues+=("api_server_unreachable")
    fi
    
    # 检查节点状态
    local not_ready_nodes=$(kubectl get nodes | grep -v Ready | wc -l)
    if [ $not_ready_nodes -gt 0 ]; then
        issues+=("node_not_ready:$not_ready_nodes")
    fi
    
    # 检查核心组件
    local unhealthy_components=$(kubectl get pods -n kube-system | grep -v Running | grep -v Completed | wc -l)
    if [ $unhealthy_components -gt 5 ]; then
        issues+=("component_unhealthy:$unhealthy_components")
    fi
    
    echo "${issues[@]}"
}

# 自动恢复函数
auto_recovery() {
    local issue=$1
    
    case $issue in
        api_server_unreachable)
            echo "尝试恢复API Server..."
            tccli tke RestartClusterInstances --ClusterId $CLUSTER_ID
            ;;
        node_not_ready*)
            local count=$(echo $issue | cut -d: -f2)
            echo "处理${count}个NotReady节点..."
            kubectl get nodes | grep NotReady | awk '{print $1}' | xargs -I {} kubectl drain {} --ignore-daemonsets --delete-local-data
            ;;
        component_unhealthy*)
            echo "重启异常组件..."
            kubectl delete pods -n kube-system -l component=kube-apiserver
            ;;
    esac
}

# 主执行逻辑
main() {
    echo "开始TKE集群自动故障检测和恢复..."
    
    local issues=($(detect_cluster_issues))
    
    if [ ${#issues[@]} -eq 0 ]; then
        echo "✅ 集群状态正常，无需恢复"
        exit 0
    fi
    
    echo "发现以下问题: ${issues[*]}"
    
    for issue in "${issues[@]}"; do
        echo "处理问题: $issue"
        
        for ((i=1; i<=MAX_RETRY; i++)); do
            echo "第${i}次尝试恢复..."
            auto_recovery "$issue"
            
            sleep 30
            
            # 验证恢复结果
            local remaining_issues=($(detect_cluster_issues))
            if [[ ! " ${remaining_issues[*]} " =~ " ${issue} " ]]; then
                echo "✅ 问题 $issue 已解决"
                break
            elif [ $i -eq $MAX_RETRY ]; then
                echo "❌ 问题 $issue 恢复失败，需要人工干预"
                # 发送告警通知
                send_alert "TKE集群自动恢复失败" "问题: $issue，请人工处理"
            fi
        done
    done
    
    echo "自动恢复流程完成"
}

# 告警通知函数
send_alert() {
    local title=$1
    local message=$2
    
    # 这里可以集成企业微信、钉钉、邮件等通知方式
    echo "发送告警: $title - $message"
    
    # 示例：调用企业微信机器人
    # curl -X POST -H 'Content-Type: application/json' \
    #     -d "{\"msgtype\": \"text\", \"text\": {\"content\": \"$title\n$message\"}}" \
    #     "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=YOUR_WEBHOOK_KEY"
}

# 执行主函数
main "$@"
```

## 版本升级与维护

### Kubernetes版本管理策略

**版本升级前检查清单**
```bash
#!/bin/bash
# TKE版本升级预检查脚本

CLUSTER_ID="cls-xxxxxxxx"
TARGET_VERSION="1.28"

echo "=== TKE版本升级预检查 ==="
echo "目标版本: $TARGET_VERSION"
echo "集群ID: $CLUSTER_ID"
echo

# 1. 检查当前版本兼容性
echo "1. 当前版本兼容性检查..."
CURRENT_VERSION=$(kubectl version --short | grep Server | awk '{print $3}' | sed 's/v//')
echo "当前版本: $CURRENT_VERSION"

# 版本跳跃检查
VERSION_JUMP=$(echo "$TARGET_VERSION $CURRENT_VERSION" | awk '{print ($1-$2)}')
if (( $(echo "$VERSION_JUMP > 1" | bc -l) )); then
    echo "⚠️  版本跳跃过大，建议逐版本升级"
fi

# 2. 检查应用兼容性
echo "2. 应用兼容性检查..."
DEPRECATED_APIS=$(kubectl get --raw /metrics | grep deprecated | wc -l)
if [ $DEPRECATED_APIS -gt 0 ]; then
    echo "❌ 发现使用废弃API的应用"
    kubectl get --raw /metrics | grep deprecated
else
    echo "✅ 未发现废弃API使用"
fi

# 3. 检查存储兼容性
echo "3. 存储兼容性检查..."
kubectl get sc -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner

# 4. 检查网络插件兼容性
echo "4. 网络插件兼容性检查..."
CNI_VERSION=$(kubectl get ds -n kube-system tke-route-eni -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "当前CNI版本: $CNI_VERSION"

# 5. 生成升级风险评估报告
cat > upgrade-risk-assessment.md << EOF
# TKE版本升级风险评估报告

## 基本信息
- 集群ID: $CLUSTER_ID
- 当前版本: $CURRENT_VERSION
- 目标版本: $TARGET_VERSION
- 检查时间: $(date)

## 风险评估

### 高风险项
$(if [ $DEPRECATED_APIS -gt 0 ]; then echo "- 存在使用废弃API的应用"; fi)

### 中风险项
$(if (( $(echo "$VERSION_JUMP > 1" | bc -l) )); then echo "- 版本跳跃较大"; fi)

### 低风险项
- 无

## 建议措施
1. 在测试环境先行升级验证
2. 备份关键应用数据
3. 准备回滚方案
4. 安排维护窗口时间

## 升级时间窗口建议
- 建议在业务低峰期进行
- 预计升级时间: 2-4小时
- 回滚时间: 1-2小时
EOF

echo "风险评估报告已生成: upgrade-risk-assessment.md"
```

**自动化升级流程**
```yaml
# TKE自动化升级流水线
apiVersion: batch/v1
kind: Job
metadata:
  name: tke-upgrade-pipeline
  namespace: kube-system
spec:
  template:
    spec:
      containers:
      - name: upgrade-controller
        image: ccr.ccs.tencentyun.com/tke/upgrade-controller:v1.0
        env:
        - name: CLUSTER_ID
          value: "cls-xxxxxxxx"
        - name: TARGET_VERSION
          value: "1.28"
        - name: UPGRADE_STRATEGY
          value: "RollingUpdate"
        - name: MAX_UNAVAILABLE
          value: "1"
        volumeMounts:
        - name: upgrade-scripts
          mountPath: /scripts
        command:
        - /scripts/upgrade-workflow.sh
      volumes:
      - name: upgrade-scripts
        configMap:
          name: upgrade-scripts
      restartPolicy: Never
  backoffLimit: 3

---
# 升级脚本ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: upgrade-scripts
  namespace: kube-system
data:
  upgrade-workflow.sh: |
    #!/bin/bash
    set -e
    
    echo "开始TKE集群升级流程..."
    
    # 1. 预检查阶段
    echo "执行预检查..."
    /scripts/pre-upgrade-check.sh
    
    # 2. 备份阶段
    echo "执行备份..."
    /scripts/backup-cluster.sh
    
    # 3. 控制平面升级
    echo "升级控制平面..."
    tccli tke UpdateClusterVersion \
        --ClusterId $CLUSTER_ID \
        --KubernetesVersion $TARGET_VERSION
    
    # 4. 等待控制平面稳定
    echo "等待控制平面稳定..."
    sleep 300
    
    # 5. 节点池升级
    echo "升级节点池..."
    NODE_POOLS=$(tccli tke DescribeClusterNodePools --ClusterId $CLUSTER_ID --query "NodePoolSet[*].NodePoolId" --output text)
    
    for pool in $NODE_POOLS; do
        echo "升级节点池: $pool"
        tccli tke ModifyNodePoolInstanceTypes \
            --ClusterId $CLUSTER_ID \
            --NodePoolId $pool \
            --InstanceTypes.0 $NEW_INSTANCE_TYPE
        
        # 滚动升级节点
        tccli tke ModifyClusterNodePool \
            --ClusterId $CLUSTER_ID \
            --NodePoolId $pool \
            --MaxNodesSurge 1 \
            --UpgradeComponents.KubernetesVersion $TARGET_VERSION
    done
    
    # 6. 验证阶段
    echo "执行升级验证..."
    /scripts/post-upgrade-validation.sh
    
    echo "升级完成！"
```

## 核心特性与优势

### 技术架构优势

**高性能网络**
- 基于腾讯自研Gaia网络虚拟化技术
- 单Pod网络延迟<1ms
- 支持百万级并发连接
- 智能路由优化和负载均衡

**大规模集群支持**
- 单集群支持万级节点
- 单集群支持十万级Pod
- 业界领先的调度性能
- 毫秒级容器启动时间

**安全可靠**
- 多层次安全防护体系
- 符合等保2.0三级要求
- 完整的审计日志记录
- 数据加密传输和存储

### 生态集成优势

**腾讯云服务深度集成**
- 与CLB/NLB/ALB负载均衡无缝集成
- 与COS对象存储、CFS文件存储深度整合
- 与CMQ消息队列、CKafka等中间件联动
- 与云监控、日志服务一体化运维

**开放生态支持**
- 支持Helm、Kustomize等主流包管理工具
- 兼容Prometheus、Grafana等监控方案
- 支持Istio、Linkerd等服务网格
- 丰富的第三方应用商店集成

## 客户案例

**大型互联网公司A**
- **挑战**: 支撑亿级用户并发访问的核心业务容器化
- **解决方案**: 部署3个万级节点TKE集群，采用多可用区高可用架构
- **成果**: 系统稳定性提升至99.99%，资源利用率提高40%

**金融科技公司B**
- **挑战**: 满足金融监管合规要求的容器平台建设
- **解决方案**: 采用独立集群模式，配合腾讯云安全合规服务
- **成果**: 通过等保三级测评，实现业务快速迭代上线

**游戏公司C**
- **挑战**: 游戏业务的弹性扩缩容需求
- **解决方案**: 利用TKE超级节点和Spot实例组合
- **成果**: 成本降低60%，自动扩缩容响应时间<30秒

## 总结

腾讯云TKE作为国内领先的Kubernetes托管服务，凭借腾讯内部海量业务实践和技术积累，为企业提供了高性能、高可靠的容器化解决方案。通过完善的生产环境最佳实践、安全加固方案、监控告警体系和成本优化策略，帮助企业在云原生转型过程中实现业务价值最大化。