# Kubernetes Service ACK 实战指南

> **文档类型**: 技术实践文档 | **适用环境**: 阿里云ACK/专有云 | **Kubernetes版本**: v1.25-v1.32  
> **重要程度**: ⭐⭐⭐⭐⭐ | **更新时间**: 2026-01 | **作者**: Kusheet Team

---

## 目录

1. [概述与目标](#1-概述与目标)
2. [核心概念深度解析](#2-核心概念深度解析)
3. [阿里云环境配置详解](#3-阿里云环境配置详解)
4. [ACK产品深度集成](#4-ack产品深度集成)
5. [生产级配置模板](#5-生产级配置模板)
6. [性能优化与调优](#6-性能优化与调优)
7. [安全加固实践](#7-安全加固实践)
8. [监控告警配置](#8-监控告警配置)
9. [故障排查手册](#9-故障排查手册)
10. [最佳实践总结](#10-最佳实践总结)

---

## 1. 概述与目标

### 1.1 文档定位

本文档旨在为阿里云环境下的Kubernetes Service配置提供：
- **完整的理论基础**：深入理解Service工作机制
- **实用的操作指南**：详细的配置步骤和最佳实践
- **生产级配置模板**：可直接使用的YAML示例
- **故障排查手册**：常见问题的诊断和解决方法

### 1.2 适用场景

**专有云环境 (Apsara Stack)**
- 企业内部私有化部署
- 网络隔离要求严格
- 自主运维管理模式

**公共云环境 (ACK)**
- 阿里云托管Kubernetes服务
- 混合云部署场景
- 快速弹性伸缩需求

### 1.3 预期收益

通过本文档的学习和实践，您将能够：
- ✅ 熟练掌握四种Service类型的配置和使用
- ✅ 深入理解阿里云负载均衡器的集成方式
- ✅ 实现生产级的服务暴露和流量管理
- ✅ 建立完善的服务监控和故障排查体系

---

## 2. 核心概念深度解析

### 2.1 Service 架构原理

#### 2.1.1 控制平面视角

```
[用户创建Service] 
    ↓
[kube-apiserver接收请求]
    ↓
[Endpoints Controller监听]
    ↓
[自动创建Endpoints对象]
    ↓
[通知各节点kube-proxy]
```

#### 2.1.2 数据平面视角

```
[客户端请求Service IP:Port]
    ↓
[kube-proxy拦截请求]
    ↓
[根据代理模式处理]
    ↓
[iptables/IPVS规则匹配]
    ↓
[转发到后端Pod]
```

### 2.2 四种Service类型深度对比

#### ClusterIP (默认类型)

**技术细节**
- 虚拟IP范围：通常在Service CIDR内 (如 172.21.0.0/16)
- IP分配方式：由kube-apiserver通过etcd分配
- 网络可达性：仅集群内部Pod可访问

**内部机制**
```bash
# 查看分配的ClusterIP
kubectl get svc -o wide

# 查看对应的Endpoints
kubectl get endpoints <service-name> -o yaml

# 验证DNS解析
kubectl run debug --image=busybox --rm -it -- nslookup <service-name>.<namespace>
```

#### NodePort

**端口分配机制**
- 端口范围：30000-32767 (可配置)
- 分配方式：随机分配或手动指定
- 访问方式：`<NodeIP>:<NodePort>`

**YAML配置示例**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nodeport-example
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - name: http
      protocol: TCP
      port: 80          # Service端口
      targetPort: 8080  # Pod端口
      nodePort: 30080   # 节点端口 (可选)
```

#### LoadBalancer

**云厂商集成原理**
```
[创建LoadBalancer类型Service]
    ↓
[触发Cloud Controller Manager]
    ↓
[调用云厂商API创建负载均衡器]
    ↓
[获取外部IP并更新Service状态]
    ↓
[配置负载均衡器后端服务器组]
```

#### ExternalName

**DNS CNAME机制**
- 不创建Endpoints对象
- CoreDNS返回CNAME记录
- 适用于外部服务集成

### 2.3 kube-proxy 三种代理模式详解

#### iptables 模式

**工作原理**
```bash
# iptables规则示例
-A KUBE-SERVICES -d 10.96.0.10/32 -p tcp -m tcp --dport 53 -j KUBE-SVC-TCOU7JCQXEZGVUNU
-A KUBE-SVC-TCOU7JCQXEZGVUNU -m statistic --mode random --probability 0.33332999982 -j KUBE-SEP-Z24YZ5JUCS5RYCOJ
-A KUBE-SVC-TCOU7JCQXEZGVUNU -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-HSO4J2JQ6L4R2TAY
-A KUBE-SVC-TCOU7JCQXEZGVUNU -j KUBE-SEP-QMKYJKG4WFHD4RKY
```

**性能特征**
- 优点：简单可靠，兼容性好
- 缺点：规则数量多时性能下降
- 适用规模：1000个Service以下

#### IPVS 模式

**内核模块依赖**
```bash
# 检查IPVS支持
lsmod | grep ip_vs

# 安装必要模块
modprobe ip_vs
modprobe ip_vs_rr  # 轮询调度
modprobe ip_vs_wrr # 加权轮询
modprobe ip_vs_sh  # 源哈希
```

**配置启用**
```yaml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
ipvs:
  scheduler: "rr"  # 调度算法
  excludeCIDRs: []
  strictARP: true
  tcpTimeout: 0s
  tcpFinTimeout: 0s
  udpTimeout: 0s
```

#### nftables 模式 (新兴技术)

**优势特性**
- 更好的性能表现
- 更清晰的规则语法
- 更强的可编程能力

**启用配置**
```yaml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: nftables
```

---

## 3. 阿里云环境配置详解

### 3.1 网络规划与设计

#### 3.1.1 专有云网络架构

**推荐网络规划**
```
VPC网络: 10.0.0.0/8
├── Master节点网段: 10.0.0.0/24
├── Worker节点网段: 10.0.1.0/24
├── Pod网络: 172.20.0.0/16
└── Service网络: 172.21.0.0/16
```

**网络隔离策略**
```yaml
# 网络策略示例
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: internal-services-only
spec:
  podSelector:
    matchLabels:
      app: internal-service
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
    ports:
    - protocol: TCP
      port: 8080
```

#### 3.1.2 公共云网络架构

**ACK网络配置**
```bash
# 创建ACK集群时的网络配置
VPC: 自动创建或使用现有VPC
Pod CIDR: 172.20.0.0/16
Service CIDR: 172.21.0.0/20
节点交换机: 多可用区分布
```

### 3.2 负载均衡器选择策略

#### 3.2.1 CLB (传统型负载均衡)

**适用场景**
- TCP/UDP四层协议
- 成本敏感的应用
- 简单的负载均衡需求

**配置示例**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: clb-service
  annotations:
    # 指定CLB实例
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-id: "lb-xxxxxxxxx"
    
    # CLB规格
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-spec: "slb.s1.small"
    
    # 带宽配置
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-bandwidth: "100"
    
    # 计费方式
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-charge-type: "paybybandwidth"
spec:
  selector:
    app: web-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: LoadBalancer
```

#### 3.2.2 NLB (网络型负载均衡)

**性能优势**
- 超低延迟 (