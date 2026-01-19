# cloud-controller-manager 深度解析 (CCM Deep Dive)

> cloud-controller-manager (CCM) 是 Kubernetes 与云提供商集成的核心组件，负责管理云特定的控制逻辑

---

## 1. 架构概述 (Architecture Overview)

### 1.1 CCM 设计背景

| 方面 | 传统模式 | CCM模式 |
|:---|:---|:---|
| **云逻辑位置** | 内嵌在kube-controller-manager | 独立组件 |
| **发布周期** | 与K8s绑定 | 可独立发布 |
| **维护责任** | K8s社区 | 云提供商 |
| **代码耦合** | 高耦合 | 低耦合 |
| **升级灵活性** | 需等待K8s版本 | 可独立升级 |

### 1.2 整体架构

```
                              ┌────────────────────────────────────────────────┐
                              │            cloud-controller-manager            │
                              │                                                │
                              │  ┌──────────────────────────────────────────┐ │
                              │  │           Cloud Provider Interface       │ │
                              │  │                                          │ │
                              │  │  ┌────────────┐  ┌────────────────────┐ │ │
                              │  │  │  Instances │  │  LoadBalancer      │ │ │
                              │  │  │  Interface │  │  Interface         │ │ │
                              │  │  └────────────┘  └────────────────────┘ │ │
                              │  │  ┌────────────┐  ┌────────────────────┐ │ │
                              │  │  │   Routes   │  │     Zones          │ │ │
                              │  │  │  Interface │  │   Interface        │ │ │
                              │  │  └────────────┘  └────────────────────┘ │ │
                              │  └──────────────────────────────────────────┘ │
                              │                      │                        │
                              │  ┌──────────────────┴──────────────────────┐ │
                              │  │              Controllers                 │ │
                              │  │  ┌─────────────┐  ┌─────────────────┐   │ │
                              │  │  │    Node     │  │   Service (LB)  │   │ │
                              │  │  │  Controller │  │   Controller    │   │ │
                              │  │  └─────────────┘  └─────────────────┘   │ │
                              │  │  ┌─────────────┐                        │ │
                              │  │  │    Route    │                        │ │
                              │  │  │  Controller │                        │ │
                              │  │  └─────────────┘                        │ │
                              │  └─────────────────────────────────────────┘ │
                              └────────────────────┬───────────────────────────┘
                                                   │
                           ┌───────────────────────┼───────────────────────┐
                           │                       │                       │
                           ▼                       ▼                       ▼
                    ┌─────────────┐         ┌─────────────┐         ┌─────────────┐
                    │    Cloud    │         │    Cloud    │         │    Cloud    │
                    │  Instances  │         │     LB      │         │   Routes    │
                    │   (VMs)     │         │  Service    │         │   (VPC)     │
                    └─────────────┘         └─────────────┘         └─────────────┘
```

### 1.3 从 KCM 分离的控制器

| 控制器 | 移至CCM | 原KCM保留 | 说明 |
|:---|:---|:---|:---|
| **Node Controller** | 云相关部分 | 生命周期管理 | 节点地址、标签、污点 |
| **Service Controller** | 完全移出 | - | LoadBalancer类型Service |
| **Route Controller** | 完全移出 | - | 配置Pod CIDR路由 |
| **Volume Controller** | 部分移出 | PV/PVC绑定 | 云盘Attach/Detach |

---

## 2. 核心控制器详解 (Core Controllers)

### 2.1 Node Controller

| 功能 | 说明 | 云API调用 |
|:---|:---|:---|
| **初始化节点** | 添加云特定信息 | GetInstance, GetZone |
| **更新节点地址** | 同步云实例IP | GetNodeAddresses |
| **添加标签** | 实例类型、区域等 | GetInstanceType, GetZone |
| **设置Provider ID** | 云实例唯一标识 | GetInstanceID |
| **检测节点删除** | 同步删除云实例 | InstanceExists |
| **添加污点** | 节点未初始化时 | - |

```yaml
# CCM 添加的节点信息示例
apiVersion: v1
kind: Node
metadata:
  name: node-1
  labels:
    # CCM添加的标签
    topology.kubernetes.io/region: us-west-2
    topology.kubernetes.io/zone: us-west-2a
    node.kubernetes.io/instance-type: m5.large
    kubernetes.io/os: linux
    kubernetes.io/arch: amd64
spec:
  # CCM设置的Provider ID
  providerID: aws:///us-west-2a/i-0123456789abcdef0
status:
  addresses:
  # CCM更新的地址
  - type: InternalIP
    address: 10.0.1.10
  - type: ExternalIP
    address: 54.xxx.xxx.xxx
  - type: Hostname
    address: ip-10-0-1-10.us-west-2.compute.internal
```

### 2.2 Service Controller

```
Service Controller 工作流程:

Watch Service (type=LoadBalancer) 变化
        │
        ▼
┌───────────────────────────────────────────────────────┐
│                   处理 LoadBalancer Service            │
│                                                        │
│  1. 创建 Service                                       │
│     └─▶ EnsureLoadBalancer()                          │
│         ├─ 创建云LB实例                                │
│         ├─ 配置监听器 (Port/Protocol)                  │
│         ├─ 添加后端实例 (Node)                         │
│         ├─ 配置健康检查                                │
│         └─ 返回LB IP/Hostname                         │
│                                                        │
│  2. 更新 Service                                       │
│     └─▶ UpdateLoadBalancer()                          │
│         ├─ 更新端口配置                                │
│         ├─ 更新后端实例                                │
│         └─ 更新健康检查配置                            │
│                                                        │
│  3. 删除 Service                                       │
│     └─▶ EnsureLoadBalancerDeleted()                   │
│         └─ 删除云LB实例及关联资源                      │
└───────────────────────────────────────────────────────┘
```

```yaml
# LoadBalancer Service 示例
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    # AWS特定注解
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    # 阿里云特定注解
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-spec: "slb.s1.small"
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-address-type: "intranet"
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
status:
  loadBalancer:
    ingress:
    - ip: 10.0.0.100          # 或 hostname
      # hostname: xxx.elb.amazonaws.com
```

### 2.3 Route Controller

```
Route Controller 工作流程:

目标: 确保每个节点的Pod CIDR在云VPC路由表中可达

Watch Node 变化
        │
        ▼
┌───────────────────────────────────────────────────────┐
│                   处理节点路由                         │
│                                                        │
│  1. 新节点加入                                         │
│     └─▶ CreateRoute()                                  │
│         ├─ 获取节点 PodCIDR                            │
│         ├─ 创建路由规则                                │
│         │   Destination: PodCIDR                       │
│         │   NextHop: Node Instance                     │
│         └─ 更新VPC路由表                               │
│                                                        │
│  2. 节点删除                                           │
│     └─▶ DeleteRoute()                                  │
│         └─ 删除对应的路由规则                          │
│                                                        │
│  3. 定期同步                                           │
│     └─▶ reconcile()                                    │
│         ├─ 获取所有期望路由                            │
│         ├─ 获取云端实际路由                            │
│         └─ 同步差异 (增删改)                           │
└───────────────────────────────────────────────────────┘

路由示例 (AWS VPC):
┌─────────────────────────────────────────────────────────┐
│  Destination     │   Target           │   Status        │
├─────────────────────────────────────────────────────────┤
│  10.0.0.0/16     │   local            │   active        │
│  10.244.0.0/24   │   i-node1          │   active        │
│  10.244.1.0/24   │   i-node2          │   active        │
│  10.244.2.0/24   │   i-node3          │   active        │
│  0.0.0.0/0       │   igw-xxx          │   active        │
└─────────────────────────────────────────────────────────┘
```

---

## 3. Cloud Provider Interface

### 3.1 核心接口定义

```go
// Cloud Provider 主接口
type Interface interface {
    Initialize(clientBuilder cloudprovider.ControllerClientBuilder, stop <-chan struct{})
    LoadBalancer() (LoadBalancer, bool)
    Instances() (Instances, bool)
    InstancesV2() (InstancesV2, bool)
    Zones() (Zones, bool)
    Clusters() (Clusters, bool)
    Routes() (Routes, bool)
    ProviderName() string
    HasClusterID() bool
}

// LoadBalancer 接口
type LoadBalancer interface {
    GetLoadBalancer(ctx context.Context, clusterName string, service *v1.Service) (*v1.LoadBalancerStatus, bool, error)
    GetLoadBalancerName(ctx context.Context, clusterName string, service *v1.Service) string
    EnsureLoadBalancer(ctx context.Context, clusterName string, service *v1.Service, nodes []*v1.Node) (*v1.LoadBalancerStatus, error)
    UpdateLoadBalancer(ctx context.Context, clusterName string, service *v1.Service, nodes []*v1.Node) error
    EnsureLoadBalancerDeleted(ctx context.Context, clusterName string, service *v1.Service) error
}

// Instances 接口
type Instances interface {
    NodeAddresses(ctx context.Context, name types.NodeName) ([]v1.NodeAddress, error)
    NodeAddressesByProviderID(ctx context.Context, providerID string) ([]v1.NodeAddress, error)
    InstanceID(ctx context.Context, nodeName types.NodeName) (string, error)
    InstanceType(ctx context.Context, name types.NodeName) (string, error)
    InstanceTypeByProviderID(ctx context.Context, providerID string) (string, error)
    AddSSHKeyToAllInstances(ctx context.Context, user string, keyData []byte) error
    CurrentNodeName(ctx context.Context, hostname string) (types.NodeName, error)
    InstanceExistsByProviderID(ctx context.Context, providerID string) (bool, error)
    InstanceShutdownByProviderID(ctx context.Context, providerID string) (bool, error)
}

// Routes 接口
type Routes interface {
    ListRoutes(ctx context.Context, clusterName string) ([]*cloudprovider.Route, error)
    CreateRoute(ctx context.Context, clusterName string, nameHint string, route *cloudprovider.Route) error
    DeleteRoute(ctx context.Context, clusterName string, route *cloudprovider.Route) error
}
```

### 3.2 主流云提供商实现

| 云提供商 | 项目 | LoadBalancer | Routes | 节点管理 |
|:---|:---|:---|:---|:---|
| **AWS** | cloud-provider-aws | NLB/ALB/CLB | VPC Routes | EC2 |
| **Azure** | cloud-provider-azure | Azure LB | Route Tables | VMSS/VM |
| **GCP** | cloud-provider-gcp | GCP LB | VPC Routes | GCE |
| **阿里云** | cloud-provider-alibaba-cloud | SLB/NLB/ALB | VPC Routes | ECS |
| **腾讯云** | cloud-provider-tencent | CLB | VPC Routes | CVM |
| **OpenStack** | cloud-provider-openstack | Octavia LB | Neutron Routes | Nova |

---

## 4. 主流云平台配置 (Cloud Provider Configs)

### 4.1 AWS (Amazon Web Services)

```yaml
# aws-cloud-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloud-config
  namespace: kube-system
data:
  cloud.conf: |
    [Global]
    Zone=us-west-2a
    VPC=vpc-xxxxxxxxx
    SubnetID=subnet-xxxxxxxxx
    RouteTableID=rtb-xxxxxxxxx
    RoleARN=arn:aws:iam::123456789012:role/kubernetes-cloud-controller
    KubernetesClusterTag=kubernetes.io/cluster/my-cluster
    KubernetesClusterID=my-cluster
    
    [ServiceOverride "ec2"]
    Service=ec2
    Region=us-west-2
    URL=https://ec2.us-west-2.amazonaws.com
    SigningRegion=us-west-2
```

```yaml
# AWS LoadBalancer Service 注解
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    # 负载均衡器类型
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"  # nlb/nlb-ip/external
    
    # 内网/外网
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"
    
    # 子网选择
    service.beta.kubernetes.io/aws-load-balancer-subnets: "subnet-xxx,subnet-yyy"
    
    # 安全组
    service.beta.kubernetes.io/aws-load-balancer-extra-security-groups: "sg-xxx"
    
    # SSL/TLS
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:xxx"
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
    
    # 健康检查
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/healthz"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-interval: "10"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-timeout: "5"
    
    # 跨AZ负载均衡
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    
    # 代理协议
    service.beta.kubernetes.io/aws-load-balancer-proxy-protocol: "*"
    
    # 访问日志
    service.beta.kubernetes.io/aws-load-balancer-access-log-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-name: "my-logs"
spec:
  type: LoadBalancer
  ports:
  - port: 443
    targetPort: 8443
```

### 4.2 阿里云 (Alibaba Cloud)

```yaml
# alibaba-cloud-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloud-config
  namespace: kube-system
data:
  cloud-config.conf: |
    {
      "Global": {
        "accessKeyID": "xxx",
        "accessKeySecret": "xxx",
        "region": "cn-hangzhou",
        "vpcid": "vpc-xxx",
        "vswitchid": "vsw-xxx",
        "clusterID": "my-cluster"
      }
    }
```

```yaml
# 阿里云 LoadBalancer Service 注解
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    # 负载均衡器规格
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-spec: "slb.s2.small"
    
    # 内网/外网
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-address-type: "intranet"
    
    # 交换机
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-vswitch-id: "vsw-xxx"
    
    # 付费模式
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-charge-type: "paybytraffic"
    
    # 调度算法
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-scheduler: "wrr"  # wrr/wlc/rr
    
    # 健康检查
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-health-check-flag: "on"
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-health-check-type: "tcp"
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-health-check-interval: "10"
    
    # 会话保持
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-persistence-timeout: "1800"
    
    # 复用已有SLB
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-id: "lb-xxx"
    
    # 带宽限制
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-bandwidth: "100"
    
    # SSL证书
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-cert-id: "xxx"
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-protocol-port: "https:443"
spec:
  type: LoadBalancer
  ports:
  - port: 443
    targetPort: 8443
```

### 4.3 Azure

```yaml
# azure-cloud-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloud-config
  namespace: kube-system
data:
  cloud-config: |
    {
      "cloud": "AzurePublicCloud",
      "tenantId": "xxx",
      "subscriptionId": "xxx",
      "resourceGroup": "my-rg",
      "location": "eastus",
      "vnetName": "my-vnet",
      "vnetResourceGroup": "my-vnet-rg",
      "subnetName": "my-subnet",
      "securityGroupName": "my-nsg",
      "routeTableName": "my-route-table",
      "primaryAvailabilitySetName": "my-avset",
      "cloudProviderBackoff": true,
      "cloudProviderBackoffRetries": 6,
      "cloudProviderBackoffExponent": 1.5,
      "cloudProviderBackoffDuration": 5,
      "cloudProviderBackoffJitter": 1,
      "cloudProviderRateLimit": true,
      "cloudProviderRateLimitQPS": 3,
      "cloudProviderRateLimitBucket": 10,
      "useManagedIdentityExtension": true
    }
```

```yaml
# Azure LoadBalancer Service 注解
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    # 负载均衡器SKU
    service.beta.kubernetes.io/azure-load-balancer-sku: "standard"
    
    # 内网负载均衡
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
    service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "my-subnet"
    
    # 指定公网IP
    service.beta.kubernetes.io/azure-load-balancer-ipv4: "1.2.3.4"
    
    # DNS标签
    service.beta.kubernetes.io/azure-dns-label-name: "myapp"
    
    # 资源组
    service.beta.kubernetes.io/azure-load-balancer-resource-group: "my-lb-rg"
    
    # 健康检查
    service.beta.kubernetes.io/azure-load-balancer-health-probe-protocol: "tcp"
    service.beta.kubernetes.io/azure-load-balancer-health-probe-interval: "10"
    service.beta.kubernetes.io/azure-load-balancer-health-probe-num-of-probe: "2"
    
    # 混合部署 (VM + VMSS)
    service.beta.kubernetes.io/azure-load-balancer-mode: "auto"
spec:
  type: LoadBalancer
  ports:
  - port: 443
    targetPort: 8443
```

### 4.4 GCP (Google Cloud Platform)

```yaml
# gcp-cloud-config.yaml (通常通过GOOGLE_APPLICATION_CREDENTIALS环境变量配置)
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloud-config
  namespace: kube-system
data:
  gce.conf: |
    [Global]
    project-id = my-project
    network-name = my-network
    subnetwork-name = my-subnet
    node-tags = my-cluster-node
    node-instance-prefix = gke-my-cluster
    multizone = true
    regional = true
```

```yaml
# GCP LoadBalancer Service 注解
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    # 内网负载均衡
    cloud.google.com/load-balancer-type: "Internal"
    
    # 指定子网
    networking.gke.io/internal-load-balancer-subnet: "my-subnet"
    
    # 全局访问 (跨区域)
    networking.gke.io/internal-load-balancer-allow-global-access: "true"
    
    # 后端配置
    cloud.google.com/backend-config: '{"default": "my-backend-config"}'
    
    # NEG (Network Endpoint Groups)
    cloud.google.com/neg: '{"ingress": true}'
spec:
  type: LoadBalancer
  ports:
  - port: 443
    targetPort: 8443
```

---

## 5. 关键配置参数 (Configuration Parameters)

### 5.1 通用参数

| 参数 | 默认值 | 说明 |
|:---|:---|:---|
| `--cloud-provider` | - | 云提供商名称(如: aws, azure, gce, alicloud) |
| `--cloud-config` | - | 云配置文件路径 |
| `--kubeconfig` | - | API Server连接配置 |
| `--authentication-kubeconfig` | - | 认证配置 |
| `--authorization-kubeconfig` | - | 授权配置 |
| `--leader-elect` | true | 启用Leader选举 |
| `--leader-elect-lease-duration` | 15s | Lease持续时间 |
| `--leader-elect-renew-deadline` | 10s | Lease续约截止时间 |
| `--leader-elect-retry-period` | 2s | Lease重试周期 |

### 5.2 控制器特定参数

| 参数 | 默认值 | 说明 |
|:---|:---|:---|
| `--controllers` | * | 启用的控制器列表 |
| `--configure-cloud-routes` | true | 是否配置云路由 |
| `--allocate-node-cidrs` | false | 是否分配节点CIDR |
| `--cluster-cidr` | - | 集群Pod CIDR |
| `--cluster-name` | kubernetes | 集群名称 |
| `--concurrent-service-syncs` | 1 | Service并发同步数 |
| `--node-monitor-period` | 5s | 节点监控周期 |
| `--node-sync-period` | - | 节点同步周期 |
| `--route-reconciliation-period` | 10s | 路由协调周期 |

### 5.3 安全参数

| 参数 | 默认值 | 说明 |
|:---|:---|:---|
| `--bind-address` | 0.0.0.0 | 监听地址 |
| `--secure-port` | 10258 | 安全端口 |
| `--tls-cert-file` | - | TLS证书 |
| `--tls-private-key-file` | - | TLS私钥 |
| `--use-service-account-credentials` | false | 使用SA凭证访问API |

---

## 6. 部署方式 (Deployment)

### 6.1 DaemonSet 部署 (推荐)

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cloud-controller-manager
  namespace: kube-system
  labels:
    k8s-app: cloud-controller-manager
spec:
  selector:
    matchLabels:
      k8s-app: cloud-controller-manager
  template:
    metadata:
      labels:
        k8s-app: cloud-controller-manager
    spec:
      nodeSelector:
        node-role.kubernetes.io/control-plane: ""
      tolerations:
      - key: node.cloudprovider.kubernetes.io/uninitialized
        value: "true"
        effect: NoSchedule
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      serviceAccountName: cloud-controller-manager
      priorityClassName: system-cluster-critical
      containers:
      - name: cloud-controller-manager
        image: registry.k8s.io/cloud-controller-manager:v1.28.0
        command:
        - /cloud-controller-manager
        - --cloud-provider=<provider>
        - --cloud-config=/etc/kubernetes/cloud.conf
        - --kubeconfig=/etc/kubernetes/cloud-controller-manager.conf
        - --leader-elect=true
        - --use-service-account-credentials=true
        - --allocate-node-cidrs=true
        - --cluster-cidr=10.244.0.0/16
        - --configure-cloud-routes=true
        - --controllers=*
        - --v=2
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 10258
            scheme: HTTPS
          initialDelaySeconds: 15
          periodSeconds: 10
          timeoutSeconds: 15
        volumeMounts:
        - name: cloud-config
          mountPath: /etc/kubernetes/cloud.conf
          readOnly: true
        - name: kubeconfig
          mountPath: /etc/kubernetes/cloud-controller-manager.conf
          readOnly: true
      volumes:
      - name: cloud-config
        configMap:
          name: cloud-config
      - name: kubeconfig
        secret:
          secretName: cloud-controller-manager-kubeconfig
```

### 6.2 RBAC 配置

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloud-controller-manager
  namespace: kube-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:cloud-controller-manager
rules:
# 节点管理
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["nodes/status"]
  verbs: ["patch", "update"]

# Service管理
- apiGroups: [""]
  resources: ["services", "services/status"]
  verbs: ["get", "list", "watch", "update", "patch"]

# Endpoints管理
- apiGroups: [""]
  resources: ["endpoints"]
  verbs: ["create", "get", "list", "watch", "update"]

# Events
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "patch", "update"]

# ServiceAccount Token
- apiGroups: [""]
  resources: ["serviceaccounts", "serviceaccounts/token"]
  verbs: ["create", "get"]

# Configmaps (Leader选举)
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "create", "update"]

# Leases (Leader选举)
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["get", "create", "update"]

# Secret (云凭证)
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:cloud-controller-manager
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:cloud-controller-manager
subjects:
- kind: ServiceAccount
  name: cloud-controller-manager
  namespace: kube-system
```

### 6.3 KCM 配置调整

```bash
# 在 kube-controller-manager 中禁用云相关控制器
# 因为这些控制器已移至 CCM
--cloud-provider=external
--controllers=*,-cloud-node-lifecycle,-route,-service
```

### 6.4 Kubelet 配置调整

```bash
# 在 kubelet 中配置外部云提供商
--cloud-provider=external
# 节点将带有 node.cloudprovider.kubernetes.io/uninitialized taint
# 等待 CCM 初始化后移除
```

---

## 7. 监控指标 (Monitoring Metrics)

### 7.1 关键指标表

| 指标名称 | 类型 | 说明 |
|:---|:---|:---|
| `cloudprovider_<provider>_api_request_duration_seconds` | Histogram | 云API请求延迟 |
| `cloudprovider_<provider>_api_request_errors_total` | Counter | 云API请求错误数 |
| `node_collector_zone_health` | Gauge | Zone健康状态 |
| `node_collector_zone_size` | Gauge | Zone节点数量 |
| `leader_election_master_status` | Gauge | Leader状态 |
| `workqueue_depth` | Gauge | 工作队列深度 |
| `workqueue_retries_total` | Counter | 重试次数 |

### 7.2 Prometheus 告警规则

```yaml
groups:
- name: cloud-controller-manager
  rules:
  - alert: CloudControllerManagerDown
    expr: absent(up{job="cloud-controller-manager"} == 1)
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "cloud-controller-manager is down"

  - alert: CloudControllerManagerNoLeader
    expr: sum(leader_election_master_status{job="cloud-controller-manager"}) == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "cloud-controller-manager has no leader"

  - alert: CloudAPIErrorRateHigh
    expr: rate(cloudprovider_*_api_request_errors_total[5m]) > 0.1
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Cloud API error rate is high"

  - alert: LoadBalancerSyncFailed
    expr: increase(workqueue_retries_total{name="service"}[1h]) > 10
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "LoadBalancer sync is failing repeatedly"
```

---

## 8. 故障排查 (Troubleshooting)

### 8.1 常见问题诊断

| 症状 | 可能原因 | 诊断方法 | 解决方案 |
|:---|:---|:---|:---|
| **节点未初始化** | CCM未运行/认证失败 | 检查节点Taint | 检查CCM状态和日志 |
| **LB未创建** | 云API失败/配额不足 | kubectl describe svc | 检查云API错误/配额 |
| **LB IP未分配** | 创建中/失败 | 检查Events | 等待或检查错误 |
| **节点地址未更新** | 云实例信息不同步 | 检查Node status | 检查CCM日志 |
| **路由未创建** | 路由控制器问题 | 检查云路由表 | 检查CCM日志和权限 |
| **Provider ID为空** | 初始化失败 | kubectl get node -o yaml | 重启CCM/检查日志 |

### 8.2 诊断命令

```bash
# 检查 CCM 状态
kubectl get pods -n kube-system -l k8s-app=cloud-controller-manager
kubectl logs -n kube-system -l k8s-app=cloud-controller-manager -f

# 检查节点初始化状态
kubectl get nodes -o custom-columns=NAME:.metadata.name,PROVIDER:.spec.providerID,TAINTS:.spec.taints

# 检查未初始化的节点
kubectl get nodes -o json | jq '.items[] | select(.spec.taints[]?.key == "node.cloudprovider.kubernetes.io/uninitialized") | .metadata.name'

# 检查 LoadBalancer Service 状态
kubectl get svc -A -o wide | grep LoadBalancer
kubectl describe svc <service-name>

# 检查 Service Events
kubectl get events --field-selector involvedObject.kind=Service

# 检查 Leader 状态
kubectl get lease -n kube-system cloud-controller-manager -o yaml

# 检查云API请求日志
kubectl logs -n kube-system <ccm-pod> | grep -i "api\|error\|failed"
```

### 8.3 常见日志模式

```bash
# 正常日志
I0101 00:00:00.000000   1 leaderelection.go:248] successfully acquired lease kube-system/cloud-controller-manager
I0101 00:00:00.000000   1 node_controller.go:232] Initializing node node-1 with cloud provider
I0101 00:00:00.000000   1 service_controller.go:456] Ensuring load balancer for service default/my-service

# 警告日志
W0101 00:00:00.000000   1 node_controller.go:340] Node node-1 is unreachable, adding taint

# 错误日志
E0101 00:00:00.000000   1 service_controller.go:567] Error syncing load balancer: failed to ensure load balancer: API error
E0101 00:00:00.000000   1 node_controller.go:234] Failed to get instance info: instance not found
```

---

## 9. 生产环境 Checklist

### 9.1 部署检查

| 检查项 | 状态 | 说明 |
|:---|:---|:---|
| [ ] CCM多实例部署 | | 高可用保证 |
| [ ] Leader选举正常 | | 选举机制工作 |
| [ ] 云凭证配置正确 | | API认证正常 |
| [ ] RBAC权限充足 | | 所有操作可执行 |
| [ ] KCM已禁用云控制器 | | 避免冲突 |
| [ ] Kubelet配置external | | 正确的提供商模式 |
| [ ] 监控告警配置 | | 运维保障 |

### 9.2 安全建议

| 建议项 | 说明 |
|:---|:---|
| 最小权限原则 | 只授予必要的云API权限 |
| 凭证轮换 | 定期轮换云访问凭证 |
| 网络隔离 | 限制CCM网络出口 |
| 审计日志 | 启用云API审计 |
| 密钥管理 | 使用Secret管理敏感信息 |

---

## 10. 与其他组件的关系

### 10.1 组件交互图

```
┌─────────────────────────────────────────────────────────────────┐
│                     Control Plane                                │
│                                                                  │
│  ┌──────────────────┐         ┌──────────────────────────────┐ │
│  │  kube-apiserver  │◀───────▶│  cloud-controller-manager    │ │
│  └────────┬─────────┘         └──────────────┬───────────────┘ │
│           │                                   │                  │
│           │                                   │ Cloud API        │
│           │                                   ▼                  │
│           │                   ┌──────────────────────────────┐  │
│           │                   │       Cloud Provider          │  │
│           │                   │  (AWS/Azure/GCP/Alicloud)     │  │
│           │                   └──────────────────────────────┘  │
│           │                                                      │
│  ┌────────┴─────────┐                                           │
│  │ kube-controller- │  --cloud-provider=external                │
│  │     manager      │  (禁用cloud-node,route,service控制器)     │
│  └──────────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘
           │
           │
           ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Worker Node                                │
│                                                                  │
│  ┌──────────────────┐                                           │
│  │     kubelet      │  --cloud-provider=external                │
│  │                  │  (等待CCM初始化节点)                       │
│  └──────────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘
```

### 10.2 节点初始化流程

```
1. Kubelet 启动 (--cloud-provider=external)
   │
   ├─▶ 注册节点到 API Server
   │   └─ 自动添加 Taint: node.cloudprovider.kubernetes.io/uninitialized=true:NoSchedule
   │
   ├─▶ CCM Node Controller 检测到新节点
   │   ├─ 调用云API获取实例信息
   │   ├─ 设置 spec.providerID
   │   ├─ 更新 status.addresses
   │   ├─ 添加云相关标签 (zone, instance-type等)
   │   └─ 移除 uninitialized Taint
   │
   └─▶ 节点可以调度 Pod
```
