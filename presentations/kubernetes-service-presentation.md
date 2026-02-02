# Kubernetes Service网络生产环境运维培训

> **适用版本**: Kubernetes v1.26-v1.32  
> **文档类型**: PPT演示文稿 | **目标受众**: 运维工程师、SRE、架构师  
> **内容定位**: 理论深入 + 源码级分析 + 生产实战案例

---

## 目录

1. [Service核心概念与架构](#1-service核心概念与架构)
2. [kube-proxy深度解析](#2-kube-proxy深度解析)
3. [Service类型详解](#3-service类型详解)
4. [EndpointSlice机制](#4-endpointslice机制)
5. [服务发现与DNS](#5-服务发现与dns)
6. [性能优化实践](#6-性能优化实践)
7. [监控与告警](#7-监控与告警)
8. [故障排查手册](#8-故障排查手册)
9. [安全配置](#9-安全配置)
10. [实战案例演练](#10-实战案例演练)
11. [总结与Q&A](#11-总结与qa)

---

## 1. Service核心概念与架构

### 1.1 Service架构全景

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Kubernetes Service 网络架构                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  外部流量入口                                                                │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  互联网 / 内网客户端                                                  │   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 │                                           │
│                                 ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    LoadBalancer / NodePort                           │   │
│  │                    外部访问入口                                       │   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 │                                           │
│                                 ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Kubernetes Service                                │   │
│  │  ┌─────────────────────────────────────────────────────────────┐    │   │
│  │  │  Service: my-app-svc                                        │    │   │
│  │  │  ClusterIP: 10.96.100.50                                    │    │   │
│  │  │  Port: 80 → TargetPort: 8080                                │    │   │
│  │  │  Selector: app=my-app                                       │    │   │
│  │  └──────────────────────────┬──────────────────────────────────┘    │   │
│  └─────────────────────────────┼───────────────────────────────────────┘   │
│                                │                                            │
│                                │ kube-proxy                                 │
│                                │ (iptables/ipvs/ebpf)                       │
│                                │                                            │
│                                ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Endpoints / EndpointSlice                         │   │
│  │  ┌─────────────────────────────────────────────────────────────┐    │   │
│  │  │  Endpoints: my-app-svc                                      │    │   │
│  │  │  Subsets:                                                   │    │   │
│  │  │    - Addresses: [10.244.1.10, 10.244.2.15, 10.244.3.20]    │    │   │
│  │  │      Ports: [{port: 8080, protocol: TCP}]                  │    │   │
│  │  └─────────────────────────────────────────────────────────────┘    │   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 │                                           │
│          ┌──────────────────────┼──────────────────────┐                   │
│          │                      │                      │                    │
│          ▼                      ▼                      ▼                    │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐             │
│  │    Pod 1     │      │    Pod 2     │      │    Pod 3     │             │
│  │ 10.244.1.10  │      │ 10.244.2.15  │      │ 10.244.3.20  │             │
│  │   :8080      │      │   :8080      │      │   :8080      │             │
│  │              │      │              │      │              │             │
│  │  app=my-app  │      │  app=my-app  │      │  app=my-app  │             │
│  └──────────────┘      └──────────────┘      └──────────────┘             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Service工作原理

**核心流程**:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Service 请求处理流程                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. 服务注册阶段                                                         │
│     ┌─────────────────────────────────────────────────────────────┐    │
│     │ Pod创建 → Endpoint Controller → 更新Endpoints/EndpointSlice │    │
│     │                                → kube-proxy监听并同步规则    │    │
│     └─────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  2. 服务发现阶段                                                         │
│     ┌─────────────────────────────────────────────────────────────┐    │
│     │ 客户端Pod → 查询CoreDNS → 获取Service ClusterIP             │    │
│     │                        → 或直接使用Service名称               │    │
│     └─────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  3. 请求转发阶段                                                         │
│     ┌─────────────────────────────────────────────────────────────┐    │
│     │ 客户端请求 → 目标ClusterIP:Port → kube-proxy规则匹配        │    │
│     │            → DNAT转换           → 负载均衡选择后端Pod        │    │
│     │            → 请求到达Pod        → 响应原路返回                │    │
│     └─────────────────────────────────────────────────────────────┘    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.3 Service类型对比矩阵

| 类型 | ClusterIP | 外部访问 | 负载均衡 | 适用场景 |
|------|-----------|---------|---------|---------|
| **ClusterIP** | 自动分配 | 仅集群内 | kube-proxy | 内部微服务 |
| **Headless** | None | 仅集群内 | 无(直连Pod) | StatefulSet |
| **NodePort** | 自动分配 | 节点IP:Port | kube-proxy | 开发测试 |
| **LoadBalancer** | 自动分配 | 云LB IP | 云LB+kube-proxy | 生产外网 |
| **ExternalName** | 无 | CNAME记录 | 无 | 外部服务引用 |

### 1.4 版本演进

| 版本 | 重要特性 | 说明 |
|------|---------|------|
| **v1.26** | 混合协议Service | 同一Service支持TCP/UDP |
| **v1.27** | Service内部流量策略增强 | PreferClose策略 |
| **v1.28** | EndpointSlice性能优化 | 减少控制面负载 |
| **v1.29** | LoadBalancer状态 | 新增status.loadBalancer字段 |
| **v1.30** | 拓扑感知路由优化 | 更智能的本地路由 |
| **v1.31** | Service代理优化 | IPVS性能提升 |
| **v1.32** | 多网络Service | 支持多网络栈 |

---

## 2. kube-proxy深度解析

### 2.1 kube-proxy架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    kube-proxy 架构详解                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         API Server                                   │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐           │   │
│  │  │   Services    │  │   Endpoints   │  │EndpointSlices │           │   │
│  │  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘           │   │
│  └──────────┼──────────────────┼──────────────────┼─────────────────────┘   │
│             │                  │                  │                         │
│             │   Watch/List     │                  │                         │
│             ▼                  ▼                  ▼                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    kube-proxy (每个节点一个)                         │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │                  Proxy Mode (代理模式)                        │   │   │
│  │  │                                                               │   │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │   │   │
│  │  │  │  iptables   │  │    ipvs     │  │    nftables │          │   │   │
│  │  │  │   (默认)    │  │  (高性能)   │  │  (v1.29+)  │          │   │   │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘          │   │   │
│  │  │                                                               │   │   │
│  │  │  ┌─────────────────────────────────────────────────────────┐ │   │   │
│  │  │  │               Sync Loop (同步循环)                       │ │   │   │
│  │  │  │  1. 从API Server获取Service/Endpoints变更              │ │   │   │
│  │  │  │  2. 计算需要更新的规则                                   │ │   │   │
│  │  │  │  3. 原子性更新内核规则                                   │ │   │   │
│  │  │  └─────────────────────────────────────────────────────────┘ │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────┐   │   │
│  │  │                  Health Check Proxy                           │   │   │
│  │  │  为LoadBalancer类型Service提供健康检查端点                    │   │   │
│  │  └──────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                      │
│                                      ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Linux Kernel                                      │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐           │   │
│  │  │   iptables    │  │  IPVS/LVS     │  │   nftables    │           │   │
│  │  │   规则链      │  │  虚拟服务器   │  │   规则表      │           │   │
│  │  └───────────────┘  └───────────────┘  └───────────────┘           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 三种代理模式对比

| 特性 | iptables | IPVS | nftables |
|------|----------|------|----------|
| **规则数量扩展性** | O(n) 线性增长 | O(1) 常量查找 | O(log n) |
| **CPU消耗** | 高(大规模时) | 低 | 中 |
| **内存消耗** | 高 | 中 | 低 |
| **连接跟踪** | 是 | 是 | 是 |
| **负载均衡算法** | 随机 | rr/lc/dh/sh/sed/nq | 随机 |
| **会话保持** | 有限支持 | 完整支持 | 有限支持 |
| **适用规模** | <1000 Service | >1000 Service | 新一代方案 |
| **内核要求** | 通用 | 需要IPVS模块 | Linux 5.13+ |
| **稳定性** | 生产就绪 | 生产就绪 | Beta |

### 2.3 iptables模式详解

```bash
# iptables规则链流程
# 入站流量: PREROUTING → KUBE-SERVICES → KUBE-SVC-xxx → KUBE-SEP-xxx → DNAT
# 出站流量: OUTPUT → KUBE-SERVICES → KUBE-SVC-xxx → KUBE-SEP-xxx → DNAT

# 查看Service相关规则
iptables -t nat -L KUBE-SERVICES -n --line-numbers

# 规则示例
# Chain KUBE-SERVICES
# 1  KUBE-SVC-xxx  tcp  --  0.0.0.0/0  10.96.100.50  tcp dpt:80  # Service入口
# 
# Chain KUBE-SVC-xxx
# 1  KUBE-SEP-aaa  all  --  0.0.0.0/0  0.0.0.0/0  statistic mode random probability 0.33333
# 2  KUBE-SEP-bbb  all  --  0.0.0.0/0  0.0.0.0/0  statistic mode random probability 0.50000
# 3  KUBE-SEP-ccc  all  --  0.0.0.0/0  0.0.0.0/0  # 剩余100%
#
# Chain KUBE-SEP-aaa
# 1  DNAT        tcp  --  0.0.0.0/0  0.0.0.0/0  tcp to:10.244.1.10:8080  # 目标Pod
```

### 2.4 IPVS模式详解

```bash
# IPVS配置示例

# 查看IPVS规则
ipvsadm -Ln

# 输出示例
# IP Virtual Server version 1.2.1 (size=4096)
# Prot LocalAddress:Port Scheduler Flags
#   -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
# TCP  10.96.100.50:80 rr
#   -> 10.244.1.10:8080             Masq    1      5          10
#   -> 10.244.2.15:8080             Masq    1      3          8
#   -> 10.244.3.20:8080             Masq    1      4          12

# IPVS支持的调度算法
# rr  - Round Robin (轮询)
# lc  - Least Connection (最少连接)
# dh  - Destination Hashing (目标哈希)
# sh  - Source Hashing (源地址哈希)
# sed - Shortest Expected Delay (最短延迟)
# nq  - Never Queue (永不排队)
```

### 2.5 kube-proxy配置

```yaml
# kube-proxy ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-proxy
  namespace: kube-system
data:
  config.conf: |
    apiVersion: kubeproxy.config.k8s.io/v1alpha1
    kind: KubeProxyConfiguration
    
    # 代理模式
    mode: "ipvs"  # iptables | ipvs | nftables(v1.29+)
    
    # IPVS配置
    ipvs:
      scheduler: "rr"              # 调度算法
      syncPeriod: "30s"           # 规则同步周期
      minSyncPeriod: "2s"         # 最小同步间隔
      strictARP: true             # 严格ARP(推荐)
      tcpTimeout: "0s"            # TCP超时
      tcpFinTimeout: "0s"         # TCP FIN超时
      udpTimeout: "0s"            # UDP超时
      excludeCIDRs: []            # 排除的CIDR
    
    # iptables配置 (即使使用IPVS也需要部分iptables)
    iptables:
      masqueradeAll: false
      masqueradeBit: 14
      minSyncPeriod: "1s"
      syncPeriod: "30s"
    
    # 连接跟踪配置
    conntrack:
      maxPerCore: 32768
      min: 131072
      tcpCloseWaitTimeout: "1h"
      tcpEstablishedTimeout: "24h"
    
    # 客户端配置
    clientConnection:
      kubeconfig: "/var/lib/kube-proxy/kubeconfig.conf"
      acceptContentTypes: ""
      burst: 10
      contentType: "application/vnd.kubernetes.protobuf"
      qps: 5
    
    # 集群配置
    clusterCIDR: "10.244.0.0/16"
    
    # 健康检查
    healthzBindAddress: "0.0.0.0:10256"
    metricsBindAddress: "0.0.0.0:10249"
    
    # 功能开关
    featureGates:
      ServiceInternalTrafficPolicy: true
      TopologyAwareHints: true
```

---

## 3. Service类型详解

### 3.1 ClusterIP Service

```yaml
# 标准ClusterIP Service
apiVersion: v1
kind: Service
metadata:
  name: api-server
  namespace: production
  labels:
    app: api-server
    tier: backend
  annotations:
    # 服务描述
    description: "API Server internal service"
    # Prometheus监控
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
spec:
  type: ClusterIP
  
  # ClusterIP分配
  clusterIP: ""  # 空字符串表示自动分配，也可以指定固定IP
  # clusterIP: 10.96.100.50  # 固定IP (需在Service CIDR范围内)
  
  # IP族配置 (双栈支持)
  ipFamilies:
  - IPv4
  # - IPv6  # 如需双栈
  ipFamilyPolicy: SingleStack  # SingleStack | PreferDualStack | RequireDualStack
  
  # 选择器
  selector:
    app: api-server
  
  # 端口配置
  ports:
  - name: http
    port: 80              # Service端口
    targetPort: 8080      # Pod端口
    protocol: TCP
  - name: grpc
    port: 9090
    targetPort: 9090
    protocol: TCP
  - name: metrics
    port: 9091
    targetPort: 9091
    protocol: TCP
  
  # 会话亲和性
  sessionAffinity: None   # None | ClientIP
  # sessionAffinityConfig:
  #   clientIP:
  #     timeoutSeconds: 10800  # 3小时
  
  # 内部流量策略 (v1.21+)
  internalTrafficPolicy: Cluster  # Cluster | Local
  # Local: 优先本节点Pod，减少跨节点流量

---
# Headless Service (无ClusterIP)
apiVersion: v1
kind: Service
metadata:
  name: mysql-headless
  namespace: database
spec:
  type: ClusterIP
  clusterIP: None  # 关键：设为None
  selector:
    app: mysql
  ports:
  - name: mysql
    port: 3306
    targetPort: 3306
  # Headless Service的DNS返回所有Pod IP
  # 用于StatefulSet等需要直连Pod的场景
```

### 3.2 NodePort Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
  namespace: production
spec:
  type: NodePort
  selector:
    app: web-frontend
  ports:
  - name: http
    port: 80
    targetPort: 8080
    nodePort: 30080      # 指定NodePort (30000-32767)
    protocol: TCP
  - name: https
    port: 443
    targetPort: 8443
    nodePort: 30443
    protocol: TCP
  
  # 外部流量策略
  externalTrafficPolicy: Local  # Cluster | Local
  # Cluster: 负载均衡到所有后端Pod (可能跨节点SNAT)
  # Local: 仅负载均衡到本节点Pod (保留客户端IP，但可能不均衡)
  
  # 健康检查NodePort (当externalTrafficPolicy=Local时)
  healthCheckNodePort: 30100  # 自动分配或指定
```

### 3.3 LoadBalancer Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-lb
  namespace: production
  annotations:
    # 阿里云SLB配置
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-spec: "slb.s2.small"
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-address-type: "internet"
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-charge-type: "paybytraffic"
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-bandwidth: "100"
    
    # AWS ELB配置
    # service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    # service.beta.kubernetes.io/aws-load-balancer-internal: "false"
    
    # GCP配置
    # cloud.google.com/load-balancer-type: "External"
spec:
  type: LoadBalancer
  
  selector:
    app: web-frontend
  
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  - name: https
    port: 443
    targetPort: 8443
    protocol: TCP
  
  # 外部流量策略
  externalTrafficPolicy: Local
  
  # 负载均衡器IP (可选，需云平台支持)
  loadBalancerIP: ""  # 指定静态IP
  
  # 源IP限制 (安全)
  loadBalancerSourceRanges:
  - "10.0.0.0/8"
  - "192.168.0.0/16"
  
  # 分配负载均衡器类 (v1.24+)
  loadBalancerClass: "service.k8s.io/aws-nlb"  # 可选

---
# 查看LoadBalancer状态
# kubectl get svc web-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 3.4 ExternalName Service

```yaml
# 引用外部服务
apiVersion: v1
kind: Service
metadata:
  name: external-database
  namespace: production
spec:
  type: ExternalName
  externalName: database.example.com  # 外部域名
  # 不需要selector
  
# 使用方式：
# 集群内访问 external-database.production.svc.cluster.local
# 将被解析为 database.example.com 的CNAME记录

---
# 无选择器Service + 手动Endpoints (引用外部IP)
apiVersion: v1
kind: Service
metadata:
  name: external-mysql
  namespace: production
spec:
  type: ClusterIP
  ports:
  - port: 3306
    targetPort: 3306
  # 注意：没有selector

---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-mysql  # 必须与Service同名
  namespace: production
subsets:
- addresses:
  - ip: 192.168.1.100  # 外部MySQL IP
  - ip: 192.168.1.101
  ports:
  - port: 3306
```

### 3.5 多协议Service (v1.26+)

```yaml
# 同时支持TCP和UDP
apiVersion: v1
kind: Service
metadata:
  name: dns-service
  namespace: kube-system
spec:
  type: ClusterIP
  selector:
    k8s-app: kube-dns
  ports:
  - name: dns-tcp
    port: 53
    targetPort: 53
    protocol: TCP
  - name: dns-udp
    port: 53
    targetPort: 53
    protocol: UDP
  # v1.26之前需要创建两个Service
  # v1.26+可以在同一Service中混合协议

---
# SCTP协议支持 (需要CNI支持)
apiVersion: v1
kind: Service
metadata:
  name: sctp-service
spec:
  type: ClusterIP
  selector:
    app: sctp-app
  ports:
  - port: 30000
    targetPort: 30000
    protocol: SCTP
```

---

## 4. EndpointSlice机制

### 4.1 EndpointSlice架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    EndpointSlice vs Endpoints 对比                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  传统Endpoints (已弃用)                                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Service: large-service (1000 Pods)                                 │   │
│  │  └── Endpoints: large-service                                       │   │
│  │      └── 所有1000个Pod地址在一个对象中                               │   │
│  │          - 对象大小可能超过etcd限制(1.5MB)                           │   │
│  │          - 任何Pod变化都要更新整个对象                               │   │
│  │          - Watch事件包含全部数据                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  EndpointSlice (推荐)                                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Service: large-service (1000 Pods)                                 │   │
│  │  └── EndpointSlice: large-service-abc (100 endpoints)              │   │
│  │  └── EndpointSlice: large-service-def (100 endpoints)              │   │
│  │  └── EndpointSlice: large-service-ghi (100 endpoints)              │   │
│  │  └── ... (共10个EndpointSlice)                                      │   │
│  │      - 每个Slice最多100个端点                                        │   │
│  │      - Pod变化只更新对应的Slice                                      │   │
│  │      - Watch事件数据量小                                             │   │
│  │      - 支持拓扑信息                                                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 EndpointSlice详解

```yaml
# EndpointSlice示例 (通常由系统自动管理)
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: api-server-abc12
  namespace: production
  labels:
    kubernetes.io/service-name: api-server  # 关联的Service
    endpointslice.kubernetes.io/managed-by: endpointslice-controller.k8s.io
  ownerReferences:
  - apiVersion: v1
    kind: Service
    name: api-server
    uid: xxx-xxx-xxx

# 地址类型
addressType: IPv4  # IPv4 | IPv6 | FQDN

# 端点列表 (最多100个)
endpoints:
- addresses:
  - "10.244.1.10"
  conditions:
    ready: true        # Pod是否就绪
    serving: true      # 是否正在服务 (v1.22+)
    terminating: false # 是否正在终止 (v1.22+)
  hostname: api-server-0
  nodeName: node-1
  zone: cn-hangzhou-a  # 可用区信息 (拓扑感知)
  targetRef:
    kind: Pod
    name: api-server-0
    namespace: production
    uid: pod-uid-xxx
  # 已弃用字段
  # deprecatedTopology:
  #   kubernetes.io/hostname: node-1
  #   topology.kubernetes.io/zone: cn-hangzhou-a

- addresses:
  - "10.244.2.15"
  conditions:
    ready: true
    serving: true
    terminating: false
  nodeName: node-2
  zone: cn-hangzhou-b
  targetRef:
    kind: Pod
    name: api-server-1
    namespace: production

# 端口定义
ports:
- name: http
  port: 8080
  protocol: TCP
  appProtocol: http  # 应用层协议提示 (v1.20+)
- name: grpc
  port: 9090
  protocol: TCP
  appProtocol: grpc
```

### 4.3 拓扑感知路由

```yaml
# 启用拓扑感知路由 (v1.23+ GA)
apiVersion: v1
kind: Service
metadata:
  name: api-server
  namespace: production
  annotations:
    # 启用拓扑感知提示
    service.kubernetes.io/topology-mode: Auto  # Auto | PreferClose | Disabled(默认)
    
    # 旧版注解 (已弃用，但仍支持)
    # service.kubernetes.io/topology-aware-hints: "Auto"
spec:
  type: ClusterIP
  selector:
    app: api-server
  ports:
  - port: 80
    targetPort: 8080

# 拓扑感知工作原理:
# 1. EndpointSlice Controller为每个endpoint添加zone信息
# 2. kube-proxy根据hints生成规则，优先路由到同zone的Pod
# 3. 如果同zone没有足够的Pod，会自动回退到跨zone路由

# 查看拓扑提示
# kubectl get endpointslices -l kubernetes.io/service-name=api-server -o yaml
# 查找 hints.forZones 字段
```

### 4.4 EndpointSlice优化配置

```yaml
# kube-controller-manager配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-controller-manager-config
data:
  config.yaml: |
    apiVersion: kubecontrollermanager.config.k8s.io/v1alpha1
    kind: KubeControllerManagerConfiguration
    
    # EndpointSlice Controller配置
    endpointSliceController:
      # 每个Slice最大端点数
      maxEndpointsPerSlice: 100
      
      # 并发同步数
      concurrentEndpointSliceSyncs: 5
    
    # Endpoints Controller配置 (兼容旧版)
    endpointController:
      concurrentEndpointSyncs: 5
```

---

## 5. 服务发现与DNS

### 5.1 DNS解析规则

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Kubernetes Service DNS解析规则                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  DNS记录格式                                                                 │
│                                                                             │
│  1. Service A记录                                                           │
│     <service>.<namespace>.svc.<cluster-domain>                             │
│     例: api-server.production.svc.cluster.local → 10.96.100.50            │
│                                                                             │
│  2. Service SRV记录                                                         │
│     _<port-name>._<protocol>.<service>.<namespace>.svc.<cluster-domain>   │
│     例: _http._tcp.api-server.production.svc.cluster.local                │
│         → 0 100 8080 api-server.production.svc.cluster.local              │
│                                                                             │
│  3. Headless Service (返回所有Pod IP)                                       │
│     <service>.<namespace>.svc.<cluster-domain>                             │
│     例: mysql-headless.database.svc.cluster.local                         │
│         → 10.244.1.10, 10.244.2.15, 10.244.3.20                           │
│                                                                             │
│  4. StatefulSet Pod A记录                                                   │
│     <pod-name>.<service>.<namespace>.svc.<cluster-domain>                 │
│     例: mysql-0.mysql-headless.database.svc.cluster.local → 10.244.1.10  │
│                                                                             │
│  5. ExternalName CNAME记录                                                  │
│     <service>.<namespace>.svc.<cluster-domain>                             │
│     例: external-db.production.svc.cluster.local                          │
│         → CNAME database.example.com                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Pod DNS配置

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: custom-dns-pod
spec:
  # DNS策略
  dnsPolicy: ClusterFirst  # Default | ClusterFirst | ClusterFirstWithHostNet | None
  # Default: 使用节点DNS配置
  # ClusterFirst: 优先使用集群DNS(默认)
  # ClusterFirstWithHostNet: 使用hostNetwork时仍优先使用集群DNS
  # None: 完全自定义，需配置dnsConfig
  
  # 自定义DNS配置
  dnsConfig:
    nameservers:
    - "10.96.0.10"           # 额外的DNS服务器
    searches:
    - "production.svc.cluster.local"
    - "svc.cluster.local"
    - "cluster.local"
    options:
    - name: ndots
      value: "5"             # 域名中点数小于5时追加搜索域
    - name: timeout
      value: "2"             # DNS查询超时
    - name: attempts
      value: "3"             # 重试次数
    - name: single-request-reopen  # 解决并发查询问题
  
  containers:
  - name: app
    image: myapp:v1
```

---

## 6. 性能优化实践

### 6.1 大规模集群优化

```yaml
# 1. 使用IPVS模式
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-proxy
  namespace: kube-system
data:
  config.conf: |
    mode: "ipvs"
    ipvs:
      scheduler: "lc"          # 最少连接算法
      syncPeriod: "30s"
      minSyncPeriod: "2s"
      strictARP: true

---
# 2. 启用拓扑感知路由减少跨AZ流量
apiVersion: v1
kind: Service
metadata:
  name: high-traffic-service
  annotations:
    service.kubernetes.io/topology-mode: "Auto"
spec:
  internalTrafficPolicy: Local  # 优先本节点Pod

---
# 3. 合理配置会话亲和性
apiVersion: v1
kind: Service
metadata:
  name: stateful-service
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600     # 1小时会话保持
```

### 6.2 连接池优化

```yaml
# 应用层连接池配置示例 (Envoy Sidecar)
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: api-server-pool
spec:
  host: api-server.production.svc.cluster.local
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100    # 最大TCP连接数
        connectTimeout: 30s
        tcpKeepalive:
          time: 7200s
          interval: 75s
          probes: 9
      http:
        h2UpgradePolicy: UPGRADE  # HTTP/2升级
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
        maxRequestsPerConnection: 100
        maxRetries: 3
    
    # 负载均衡配置
    loadBalancer:
      simple: LEAST_REQUEST   # 最少请求算法
    
    # 熔断配置
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
```

### 6.3 网络性能测试

```bash
#!/bin/bash
# Service网络性能测试脚本

NAMESPACE="benchmark"
SERVICE_NAME="test-service"

echo "=== Service网络性能测试 ==="

# 1. 部署测试服务
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-benchmark
  namespace: $NAMESPACE
spec:
  replicas: 10
  selector:
    matchLabels:
      app: nginx-benchmark
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: $SERVICE_NAME
  namespace: $NAMESPACE
spec:
  selector:
    app: nginx-benchmark
  ports:
  - port: 80
    targetPort: 80
EOF

# 等待部署就绪
kubectl wait --for=condition=available deployment/nginx-benchmark -n $NAMESPACE --timeout=120s

# 2. 获取Service ClusterIP
CLUSTER_IP=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')

# 3. 部署测试Pod
kubectl run benchmark-client --image=fortio/fortio -n $NAMESPACE -- sleep infinity
kubectl wait --for=condition=ready pod/benchmark-client -n $NAMESPACE --timeout=60s

# 4. 运行性能测试
echo "=== 延迟测试 ==="
kubectl exec -n $NAMESPACE benchmark-client -- fortio load -c 50 -qps 0 -n 10000 http://$CLUSTER_IP/

echo "=== 吞吐量测试 ==="
kubectl exec -n $NAMESPACE benchmark-client -- fortio load -c 100 -qps 0 -t 60s http://$CLUSTER_IP/

echo "=== 连接建立测试 ==="
kubectl exec -n $NAMESPACE benchmark-client -- fortio load -c 1 -qps 0 -n 1000 -keepalive=false http://$CLUSTER_IP/

# 5. 清理
kubectl delete deployment nginx-benchmark -n $NAMESPACE
kubectl delete svc $SERVICE_NAME -n $NAMESPACE
kubectl delete pod benchmark-client -n $NAMESPACE

echo "测试完成"
```

---

## 7. 监控与告警

### 7.1 关键监控指标

| 指标类别 | 指标名称 | 告警阈值 | 说明 |
|---------|---------|---------|------|
| **Service状态** | `kube_service_info` | N/A | Service基本信息 |
| **Endpoints** | `kube_endpoint_address_available` | =0 | 无可用端点 |
| **EndpointSlice** | `kube_endpointslice_endpoints` | 变化大 | 端点数量异常波动 |
| **kube-proxy** | `kubeproxy_sync_proxy_rules_duration_seconds` | >1s | 规则同步慢 |
| **kube-proxy** | `kubeproxy_network_programming_duration_seconds` | >5s | 网络编程延迟 |
| **连接数** | `node_netstat_Tcp_CurrEstab` | 异常高 | 连接数异常 |

### 7.2 Prometheus告警规则

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: service-alerts
  namespace: monitoring
spec:
  groups:
  - name: service.rules
    rules:
    # Service无可用端点
    - alert: ServiceNoEndpoints
      expr: |
        kube_endpoint_address_available == 0
        and on(endpoint, namespace) kube_endpoint_info
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Service无可用端点"
        description: "{{ $labels.namespace }}/{{ $labels.endpoint }} 没有可用的端点"
    
    # Service端点数量异常下降
    - alert: ServiceEndpointsDegraded
      expr: |
        (
          kube_endpoint_address_available
          / kube_endpoint_address_not_ready
        ) < 0.5
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Service端点健康率低"
        description: "{{ $labels.namespace }}/{{ $labels.endpoint }} 健康端点比例低于50%"
    
    # kube-proxy规则同步延迟
    - alert: KubeProxySyncSlow
      expr: |
        histogram_quantile(0.99, 
          sum(rate(kubeproxy_sync_proxy_rules_duration_seconds_bucket[5m])) by (le, instance)
        ) > 1
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "kube-proxy规则同步延迟"
        description: "{{ $labels.instance }} P99规则同步延迟超过1秒"
    
    # kube-proxy网络编程延迟
    - alert: KubeProxyNetworkProgrammingSlow
      expr: |
        histogram_quantile(0.99,
          sum(rate(kubeproxy_network_programming_duration_seconds_bucket[5m])) by (le, instance)
        ) > 5
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "kube-proxy网络编程延迟"
        description: "{{ $labels.instance }} P99网络编程延迟超过5秒"
    
    # LoadBalancer Service无外部IP
    - alert: LoadBalancerNoExternalIP
      expr: |
        kube_service_spec_type{type="LoadBalancer"} == 1
        unless on(namespace, service)
        kube_service_status_load_balancer_ingress
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "LoadBalancer Service无外部IP"
        description: "{{ $labels.namespace }}/{{ $labels.service }} 未分配外部IP"

  - name: kube-proxy.rules
    rules:
    # kube-proxy Pod不健康
    - alert: KubeProxyDown
      expr: |
        up{job="kube-proxy"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "kube-proxy实例不可用"
        description: "{{ $labels.instance }} kube-proxy已下线"
    
    # IPVS连接数过高
    - alert: IPVSConnectionsHigh
      expr: |
        sum(node_ipvs_connections_total) by (instance) > 100000
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "IPVS连接数过高"
        description: "{{ $labels.instance }} IPVS连接数超过10万"
```

---

## 8. 故障排查手册

### 8.1 故障诊断流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Service 故障诊断流程                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Service无法访问?                                                        │
│      │                                                                  │
│      ├── 检查Service是否存在                                            │
│      │   kubectl get svc <name> -n <namespace>                         │
│      │                                                                  │
│      ├── 检查Endpoints/EndpointSlice                                    │
│      │   kubectl get endpoints <name> -n <namespace>                   │
│      │   kubectl get endpointslices -l kubernetes.io/service-name=<name>│
│      │   └── 无端点? → 检查Pod标签是否匹配selector                      │
│      │                                                                  │
│      ├── 检查Pod状态                                                     │
│      │   kubectl get pods -l <selector> -n <namespace>                 │
│      │   └── Pod不健康? → 检查Pod详情和日志                              │
│      │                                                                  │
│      ├── 测试直连Pod                                                     │
│      │   kubectl exec -it <client-pod> -- curl <pod-ip>:<port>         │
│      │   └── 直连失败? → 网络策略或CNI问题                               │
│      │                                                                  │
│      ├── 检查kube-proxy                                                  │
│      │   kubectl get pods -n kube-system -l k8s-app=kube-proxy         │
│      │   kubectl logs -n kube-system <kube-proxy-pod>                  │
│      │                                                                  │
│      └── 检查iptables/ipvs规则                                          │
│          iptables -t nat -L KUBE-SERVICES -n | grep <cluster-ip>       │
│          ipvsadm -Ln | grep <cluster-ip>                               │
│                                                                         │
│  NodePort无法访问?                                                       │
│      │                                                                  │
│      ├── 检查节点防火墙                                                  │
│      │   iptables -L INPUT -n | grep <nodeport>                        │
│      │                                                                  │
│      ├── 检查云安全组                                                    │
│      │   确保NodePort范围(30000-32767)已开放                            │
│      │                                                                  │
│      └── 检查externalTrafficPolicy                                      │
│          Local模式下需要访问有Pod的节点                                  │
│                                                                         │
│  LoadBalancer无外部IP?                                                   │
│      │                                                                  │
│      ├── 检查云控制器日志                                                │
│      │   kubectl logs -n kube-system <cloud-controller-pod>            │
│      │                                                                  │
│      ├── 检查云平台配额                                                  │
│      │   LB数量/EIP配额是否充足                                         │
│      │                                                                  │
│      └── 检查Service注解                                                 │
│          确保云平台特定注解正确                                          │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 8.2 诊断命令集

```bash
#!/bin/bash
# Service诊断脚本

NAMESPACE=${1:-default}
SERVICE_NAME=$2

echo "=========================================="
echo "Service诊断报告"
echo "命名空间: $NAMESPACE"
echo "Service: $SERVICE_NAME"
echo "时间: $(date)"
echo "=========================================="

# 1. Service状态
echo -e "\n=== 1. Service状态 ==="
kubectl get svc $SERVICE_NAME -n $NAMESPACE -o wide

echo -e "\n=== 2. Service详情 ==="
kubectl describe svc $SERVICE_NAME -n $NAMESPACE

# 3. Endpoints
echo -e "\n=== 3. Endpoints ==="
kubectl get endpoints $SERVICE_NAME -n $NAMESPACE -o wide

# 4. EndpointSlices
echo -e "\n=== 4. EndpointSlices ==="
kubectl get endpointslices -n $NAMESPACE -l kubernetes.io/service-name=$SERVICE_NAME

# 5. 后端Pod
echo -e "\n=== 5. 后端Pod ==="
SELECTOR=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.selector}' | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")')
kubectl get pods -n $NAMESPACE -l $SELECTOR -o wide

# 6. kube-proxy状态
echo -e "\n=== 6. kube-proxy状态 ==="
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide

# 7. iptables规则 (在节点上执行)
echo -e "\n=== 7. 检查iptables规则 ==="
CLUSTER_IP=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
echo "ClusterIP: $CLUSTER_IP"
echo "检查命令: iptables -t nat -L KUBE-SERVICES -n | grep $CLUSTER_IP"

# 8. IPVS规则 (如果使用IPVS模式)
echo -e "\n=== 8. 检查IPVS规则 ==="
echo "检查命令: ipvsadm -Ln | grep $CLUSTER_IP"

# 9. DNS解析测试
echo -e "\n=== 9. DNS解析测试 ==="
kubectl run dns-test-$RANDOM --rm -it --image=busybox:1.36 --restart=Never -- nslookup $SERVICE_NAME.$NAMESPACE.svc.cluster.local

# 10. 连通性测试
echo -e "\n=== 10. 连通性测试 ==="
PORT=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')
kubectl run connectivity-test-$RANDOM --rm -it --image=curlimages/curl:latest --restart=Never -- curl -s -o /dev/null -w "%{http_code}" http://$SERVICE_NAME.$NAMESPACE.svc.cluster.local:$PORT --connect-timeout 5
```

### 8.3 常见故障解决

#### 8.3.1 Service无Endpoints

```bash
# 问题: Service没有Endpoints

# 1. 检查Selector是否正确
kubectl get svc <service> -n <namespace> -o jsonpath='{.spec.selector}'
kubectl get pods -n <namespace> --show-labels | grep <label-value>

# 2. 检查Pod是否Ready
kubectl get pods -n <namespace> -l <selector> -o wide
kubectl describe pod <pod-name> -n <namespace>

# 3. 检查Pod的containerPort是否与Service的targetPort匹配
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].ports}'

# 解决方案
# 1. 修正Service的selector
kubectl patch svc <service> -n <namespace> -p '{"spec":{"selector":{"app":"correct-label"}}}'

# 2. 修正Pod的labels
kubectl label pod <pod-name> -n <namespace> app=correct-label --overwrite
```

#### 8.3.2 跨命名空间访问失败

```bash
# 问题: 从其他命名空间无法访问Service

# 1. 使用完整DNS名称
# <service>.<namespace>.svc.cluster.local
curl http://api-server.production.svc.cluster.local

# 2. 检查NetworkPolicy
kubectl get networkpolicy -n <namespace>

# 3. 创建允许跨命名空间访问的NetworkPolicy
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-cross-namespace
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api-server
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          access: allowed
    ports:
    - protocol: TCP
      port: 8080
EOF
```

---

## 9. 安全配置

### 9.1 Network Policy

```yaml
# Service安全访问策略
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-server-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api-server
  policyTypes:
  - Ingress
  - Egress
  
  ingress:
  # 只允许特定来源访问
  - from:
    # 来自同命名空间的web-frontend
    - podSelector:
        matchLabels:
          app: web-frontend
    # 来自监控命名空间的Prometheus
    - namespaceSelector:
        matchLabels:
          name: monitoring
      podSelector:
        matchLabels:
          app: prometheus
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 9090  # metrics
  
  egress:
  # 允许访问数据库
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 3306
  
  # 允许DNS查询
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
```

### 9.2 LoadBalancer安全配置

```yaml
apiVersion: v1
kind: Service
metadata:
  name: secure-lb
  namespace: production
  annotations:
    # 阿里云SLB访问控制
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-acl-status: "on"
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-acl-id: "acl-xxx"
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-acl-type: "white"
spec:
  type: LoadBalancer
  
  # 源IP范围限制
  loadBalancerSourceRanges:
  - "10.0.0.0/8"         # 内网
  - "203.0.113.0/24"     # 公司出口IP
  
  # 外部流量策略
  externalTrafficPolicy: Local  # 保留客户端IP
  
  selector:
    app: api-server
  ports:
  - port: 443
    targetPort: 8443
```

---

## 10. 实战案例演练

### 10.1 案例一：微服务架构Service配置

```yaml
# API Gateway Service
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: production
  annotations:
    service.kubernetes.io/topology-mode: "Auto"
spec:
  type: ClusterIP
  selector:
    app: api-gateway
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: grpc
    port: 9090
    targetPort: 9090
  internalTrafficPolicy: Local

---
# User Service
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: production
spec:
  type: ClusterIP
  selector:
    app: user-service
  ports:
  - port: 8080
    targetPort: 8080
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600

---
# Order Service (需要高可用)
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: production
  annotations:
    service.kubernetes.io/topology-mode: "Auto"
spec:
  type: ClusterIP
  selector:
    app: order-service
  ports:
  - port: 8080
    targetPort: 8080
  internalTrafficPolicy: Cluster  # 跨节点负载均衡
```

### 10.2 案例二：数据库Headless Service

```yaml
# MySQL集群Headless Service
apiVersion: v1
kind: Service
metadata:
  name: mysql-headless
  namespace: database
spec:
  clusterIP: None  # Headless
  selector:
    app: mysql
  ports:
  - name: mysql
    port: 3306
    targetPort: 3306
  publishNotReadyAddresses: true  # 发布未就绪的地址(用于初始化)

---
# MySQL读写分离 - 写Service
apiVersion: v1
kind: Service
metadata:
  name: mysql-write
  namespace: database
spec:
  type: ClusterIP
  selector:
    app: mysql
    role: primary  # 只选择主节点
  ports:
  - port: 3306
    targetPort: 3306

---
# MySQL读写分离 - 读Service
apiVersion: v1
kind: Service
metadata:
  name: mysql-read
  namespace: database
spec:
  type: ClusterIP
  selector:
    app: mysql
    role: replica  # 只选择从节点
  ports:
  - port: 3306
    targetPort: 3306
```

### 10.3 案例三：服务迁移（蓝绿部署）

```bash
#!/bin/bash
# Service蓝绿切换脚本

NAMESPACE="production"
SERVICE_NAME="api-server"
BLUE_LABEL="version=blue"
GREEN_LABEL="version=green"

# 当前版本
CURRENT=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.selector.version}')

if [ "$CURRENT" == "blue" ]; then
    NEW_VERSION="green"
else
    NEW_VERSION="blue"
fi

echo "当前版本: $CURRENT"
echo "切换到: $NEW_VERSION"

# 确认新版本Pod就绪
READY_PODS=$(kubectl get pods -n $NAMESPACE -l app=api-server,version=$NEW_VERSION -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | tr ' ' '\n' | grep -c True)

if [ "$READY_PODS" -lt 1 ]; then
    echo "错误: 新版本没有就绪的Pod"
    exit 1
fi

echo "新版本就绪Pod数: $READY_PODS"

# 切换流量
kubectl patch svc $SERVICE_NAME -n $NAMESPACE -p "{\"spec\":{\"selector\":{\"app\":\"api-server\",\"version\":\"$NEW_VERSION\"}}}"

echo "流量已切换到 $NEW_VERSION"

# 验证切换
kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.selector}'
kubectl get endpoints $SERVICE_NAME -n $NAMESPACE
```

---

## 11. 总结与Q&A

### 11.1 核心要点回顾

| 主题 | 关键要点 |
|------|----------|
| **Service类型选择** | ClusterIP(内部) → NodePort(测试) → LoadBalancer(生产) |
| **kube-proxy模式** | 小规模用iptables，大规模用IPVS |
| **性能优化** | 拓扑感知路由 + 本地流量策略 + 合理的会话亲和 |
| **高可用** | 多副本后端 + 健康检查 + 跨AZ分布 |
| **安全** | NetworkPolicy + LoadBalancer源IP限制 |

### 11.2 最佳实践清单

- [ ] 生产环境使用IPVS模式
- [ ] 启用拓扑感知路由减少跨AZ流量
- [ ] 合理配置internalTrafficPolicy
- [ ] 为LoadBalancer配置源IP限制
- [ ] 配置Service监控告警
- [ ] 实施NetworkPolicy限制访问
- [ ] 定期检查kube-proxy健康状态
- [ ] 测试故障恢复流程

### 11.3 常见问题解答

**Q: ClusterIP和Headless Service如何选择？**
A: 需要负载均衡用ClusterIP；需要直连Pod(如StatefulSet)用Headless。

**Q: externalTrafficPolicy Local和Cluster有什么区别？**
A: Local保留客户端IP但可能负载不均；Cluster会SNAT但负载均衡更好。

**Q: 为什么大规模集群要用IPVS？**
A: IPVS使用哈希表查找规则，复杂度O(1)；iptables是线性遍历，复杂度O(n)。

**Q: EndpointSlice相比Endpoints有什么优势？**
A: 分片存储，单个Pod变化只更新对应Slice，大大减少API Server和etcd负载。

---

## 阿里云ACK专属配置

### ACK LoadBalancer配置

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ack-loadbalancer
  namespace: production
  annotations:
    # SLB规格
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-spec: "slb.s3.medium"
    # 网络类型
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-address-type: "internet"
    # 计费方式
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-charge-type: "paybytraffic"
    # 带宽限制
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-bandwidth: "100"
    # 健康检查
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-health-check-flag: "on"
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-health-check-type: "http"
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-health-check-uri: "/health"
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-health-check-connect-port: "80"
    # 会话保持
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-sticky-session: "on"
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-sticky-session-type: "insert"
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-cookie-timeout: "1800"
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local
  selector:
    app: web-frontend
  ports:
  - port: 80
    targetPort: 8080
```

---

## 附录 A: 常用命令速查表

```bash
# Service 管理
kubectl get svc -A -o wide
kubectl describe svc <name> -n <namespace>
kubectl get svc <name> -o yaml

# Endpoints/EndpointSlice 检查
kubectl get endpoints -A
kubectl get endpointslices -A
kubectl describe endpoints <svc-name> -n <namespace>

# kube-proxy 检查
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=100

# IPVS 规则检查 (需要在节点上执行)
kubectl exec -n kube-system <kube-proxy-pod> -- ipvsadm -Ln
kubectl exec -n kube-system <kube-proxy-pod> -- ipvsadm -Ln --stats

# iptables 规则检查
kubectl exec -n kube-system <kube-proxy-pod> -- iptables -t nat -L KUBE-SERVICES -n

# 网络连通性测试
kubectl run nettest --rm -it --image=nicolaka/netshoot -- curl -v http://<service-name>:<port>
kubectl run nettest --rm -it --image=nicolaka/netshoot -- nslookup <service-name>

# LoadBalancer 状态
kubectl get svc <name> -o jsonpath='{.status.loadBalancer.ingress}'

# 服务发现测试
kubectl run dns-test --rm -it --image=busybox:1.36 -- nslookup <service>.<namespace>.svc.cluster.local
```

## 附录 B: 配置模板索引

| 模板名称 | 适用场景 | 章节位置 |
|----------|----------|----------|
| ClusterIP Service | 集群内部服务 | 3.1 节 |
| NodePort Service | 外部访问 (开发测试) | 3.2 节 |
| LoadBalancer Service | 生产外部访问 | 3.3 节 |
| Headless Service | StatefulSet/直接Pod访问 | 3.4 节 |
| ExternalName Service | 外部服务别名 | 3.5 节 |
| 拓扑感知 Service | 跨AZ流量优化 | 6.2 节 |
| 会话亲和性配置 | 有状态会话保持 | 6.3 节 |
| NetworkPolicy | 服务访问控制 | 9.1 节 |
| ACK SLB 配置 | 阿里云负载均衡 | ACK专属配置 |

## 附录 C: 故障排查索引

| 故障现象 | 可能原因 | 排查方法 | 章节位置 |
|----------|----------|----------|----------|
| Service 无法访问 | Endpoints 为空 | kubectl get endpoints | 8.1 节 |
| ClusterIP 超时 | kube-proxy 异常 | 检查 kube-proxy 日志 | 8.2 节 |
| NodePort 无法访问 | 防火墙/安全组 | 检查节点端口开放 | 8.3 节 |
| LoadBalancer Pending | 云控制器异常 | 检查 cloud-controller | 8.4 节 |
| DNS 解析失败 | CoreDNS 异常 | nslookup 测试 | 5.1 节 |
| 跨节点访问慢 | externalTrafficPolicy | 检查流量策略 | 6.1 节 |
| 会话不保持 | sessionAffinity 未配置 | 检查 Service 配置 | 6.3 节 |

## 附录 D: 监控指标参考

| 指标名称 | 类型 | 说明 | 告警阈值 |
|----------|------|------|----------|
| `kube_service_info` | Gauge | Service 信息 | - |
| `kube_endpoint_address_available` | Gauge | 可用 Endpoint 数 | = 0 |
| `kube_endpoint_address_not_ready` | Gauge | 未就绪 Endpoint 数 | > 0 持续5分钟 |
| `kubeproxy_sync_proxy_rules_duration_seconds` | Histogram | kube-proxy 同步延迟 | P99 > 1s |
| `kubeproxy_network_programming_duration_seconds` | Histogram | 网络规则编程延迟 | P99 > 5s |
| `kube_service_status_load_balancer_ingress` | Gauge | LB IP 状态 | 无 IP |

---

**文档版本**: v2.0  
**适用版本**: Kubernetes v1.26-v1.32  
**更新日期**: 2026年1月  
**作者**: Kusheet Project  
**联系方式**: Allen Galler (allengaller@gmail.com)

---

*全文完 - Kubernetes Service 网络生产环境运维培训*
