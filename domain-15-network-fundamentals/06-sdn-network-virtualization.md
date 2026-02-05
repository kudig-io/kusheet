# SDN 与网络虚拟化

> **适用版本**: 通用 | **最后更新**: 2026-01

---

## 目录

- [SDN 概述](#sdn-概述)
- [网络虚拟化技术](#网络虚拟化技术)
- [Overlay 网络](#overlay-网络)
- [容器网络模型](#容器网络模型)
- [服务网格](#服务网格)
- [云网络架构](#云网络架构)

---

## SDN 概述

### SDN 架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        应用层                                    │
│              网络应用: 负载均衡、防火墙、监控                      │
├─────────────────────────────────────────────────────────────────┤
│                        控制层                                    │
│              SDN 控制器: 路由计算、策略下发                        │
│              OpenDaylight, ONOS, Tungsten Fabric                │
├─────────────────────────────────────────────────────────────────┤
│                        数据层                                    │
│              网络设备: 交换机、路由器 (OpenFlow)                   │
└─────────────────────────────────────────────────────────────────┘
```

### SDN 特点

| 特点 | 说明 |
|:---|:---|
| **控制平面分离** | 集中控制、分布转发 |
| **可编程** | API 驱动网络配置 |
| **灵活性** | 动态调整网络策略 |
| **自动化** | 简化网络运维 |

### SDN 协议

| 协议 | 功能 |
|:---|:---|
| **OpenFlow** | 控制器-交换机通信 |
| **OVSDB** | OVS 配置管理 |
| **NetConf** | 设备配置 |
| **YANG** | 数据模型 |

---

## 网络虚拟化技术

### 虚拟化类型

| 技术 | 说明 | 使用场景 |
|:---|:---|:---|
| **VLAN** | 二层隔离 | 传统网络 |
| **VXLAN** | Overlay 封装 | 数据中心 |
| **GRE** | 隧道封装 | 点对点 |
| **GENEVE** | 通用封装 | 云原生 |

### Open vSwitch (OVS)

```bash
# 创建网桥
ovs-vsctl add-br br0

# 添加端口
ovs-vsctl add-port br0 eth0

# 添加 VXLAN 隧道
ovs-vsctl add-port br0 vxlan0 -- set interface vxlan0 \
  type=vxlan options:remote_ip=10.0.0.2 options:key=100

# 查看配置
ovs-vsctl show

# 流表操作
ovs-ofctl dump-flows br0
```

### Linux 网桥

```bash
# 创建网桥
ip link add br0 type bridge

# 添加接口
ip link set eth0 master br0

# 启用 STP
ip link set br0 type bridge stp_state 1

# 查看
bridge link show
bridge fdb show
```

---

## Overlay 网络

### VXLAN 原理

```
┌─────────────────────────────────────────────────────────────────┐
│  原始帧: [Eth Header][IP Header][TCP/UDP Header][Payload]        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ VXLAN 封装
┌─────────────────────────────────────────────────────────────────┐
│[Outer Eth][Outer IP][UDP:4789][VXLAN Header][原始帧]             │
│                              VNI: 虚拟网络标识 (24bit)           │
└─────────────────────────────────────────────────────────────────┘
```

### VXLAN 配置

```bash
# 创建 VXLAN 接口
ip link add vxlan100 type vxlan id 100 \
  dstport 4789 \
  remote 10.0.0.2 \
  local 10.0.0.1 \
  dev eth0

# 创建网桥并绑定
ip link add br-vxlan100 type bridge
ip link set vxlan100 master br-vxlan100

# 启用
ip link set vxlan100 up
ip link set br-vxlan100 up
```

### Overlay 对比

| 技术 | 封装开销 | 多租户 | 特点 |
|:---|:---:|:---:|:---|
| VXLAN | 50 字节 | VNI (16M) | 广泛支持 |
| GENEVE | 可变 | 灵活 | 现代标准 |
| GRE | 24+ 字节 | Key | 简单 |
| IPsec | 变化 | SPI | 加密 |

---

## 容器网络模型

### CNI 插件对比

| 插件 | 类型 | 特点 | 适用场景 |
|:---|:---|:---|:---|
| **Calico** | L3 路由 | BGP、网络策略 | 大规模集群 |
| **Cilium** | eBPF | 高性能、可观测 | 云原生 |
| **Flannel** | Overlay | 简单易用 | 小规模 |
| **Weave** | Overlay | 加密、多播 | 安全需求 |

### 网络策略

```yaml
# NetworkPolicy 示例
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: frontend
      ports:
        - port: 80
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: database
      ports:
        - port: 5432
```

---

## 服务网格

### 服务网格架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        控制平面                                  │
│              Istiod: 配置管理、证书颁发、服务发现                  │
└─────────────────────────┬───────────────────────────────────────┘
                          │ xDS API
            ┌─────────────┼─────────────┐
            ▼             ▼             ▼
       ┌─────────┐   ┌─────────┐   ┌─────────┐
       │ Envoy   │   │ Envoy   │   │ Envoy   │
       │ Sidecar │   │ Sidecar │   │ Sidecar │
       └────┬────┘   └────┬────┘   └────┬────┘
            │             │             │
       ┌────┴────┐   ┌────┴────┐   ┌────┴────┐
       │ Service │   │ Service │   │ Service │
       │    A    │   │    B    │   │    C    │
       └─────────┘   └─────────┘   └─────────┘
```

### 服务网格功能

| 功能 | 说明 |
|:---|:---|
| mTLS | 服务间加密通信 |
| 流量管理 | 路由、重试、超时 |
| 可观测性 | 指标、日志、追踪 |
| 策略执行 | 访问控制、限流 |

---

## 云网络架构

### VPC 网络

```
┌─────────────────────────────────────────────────────────────────┐
│                         VPC 10.0.0.0/16                          │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ 公有子网 10.0.1.0/24           私有子网 10.0.2.0/24        │ │
│  │ ┌──────────┐                  ┌──────────┐                │ │
│  │ │  NAT GW  │                  │ 应用服务  │                │ │
│  │ └────┬─────┘                  └──────────┘                │ │
│  │      │                               │                     │ │
│  │ ┌────┴─────┐                  ┌──────┴───┐                │ │
│  │ │ 路由表    │                  │ 路由表    │                │ │
│  │ │ 0/0→IGW  │                  │ 0/0→NAT  │                │ │
│  │ └──────────┘                  └──────────┘                │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│                    ┌─────────┴─────────┐                        │
│                    │   Internet GW     │                        │
│                    └───────────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```

### 云网络组件

| 组件 | 功能 |
|:---|:---|
| **VPC** | 虚拟私有云 |
| **子网** | 网络分段 |
| **安全组** | 实例级防火墙 |
| **NACL** | 子网级 ACL |
| **NAT 网关** | 私有子网出口 |
| **VPN/专线** | 混合云连接 |

## 网络虚拟化性能优化

### 网络虚拟化性能瓶颈分析

#### 性能影响因素

| 影响因素 | 性能损耗 | 优化策略 |
|:---|:---:|:---|
| **封装开销** | 24-50 字节 | GSO/GRO, 硬件卸载 |
| **虚拟交换** | 10-30% CPU | DPDK, SR-IOV |
| **网络策略** | 5-15% 性能 | eBPF, 硬件加速 |
| **多租户隔离** | 5-10% 资源 | 命名空间优化 |

#### 性能测试基准

```bash
# 网络虚拟化性能测试脚本
#!/bin/bash

TEST_DURATION=60  # 测试持续时间(秒)
RESULT_DIR="/tmp/network-perf-results"

mkdir -p $RESULT_DIR

# 物理网络基线测试
test_physical_network() {
    echo "=== 物理网络性能测试 ==="
    
    # TCP 吞吐量测试
    iperf3 -s -p 5201 &
    SERVER_PID=$!
    sleep 2
    
    iperf3 -c localhost -p 5201 -t $TEST_DURATION -P 4 > $RESULT_DIR/physical_tcp.txt
    kill $SERVER_PID
    
    # UDP 延迟测试
    ping -c 100 localhost > $RESULT_DIR/physical_ping.txt
}

# Overlay 网络测试
test_overlay_network() {
    echo "=== Overlay 网络性能测试 ==="
    
    # 创建测试网络
    docker network create --driver overlay test-overlay-net
    
    # 部署测试容器
    docker service create --name perf-test-source \
        --network test-overlay-net \
        --replicas 1 \
        alpine sleep 3600
    
    docker service create --name perf-test-target \
        --network test-overlay-net \
        --replicas 1 \
        alpine iperf3 -s
    
    sleep 10
    
    # 执行性能测试
    docker exec $(docker ps -q -f name=perf-test-source) \
        iperf3 -c perf-test-target -t $TEST_DURATION -P 4 > $RESULT_DIR/overlay_tcp.txt
    
    # 清理测试环境
    docker service rm perf-test-source perf-test-target
    docker network rm test-overlay-net
}

# eBPF 网络策略性能测试
test_ebpf_performance() {
    echo "=== eBPF 网络策略性能测试 ==="
    
    # 启用 Cilium
    kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/v1.12/install/kubernetes/quick-install.yaml
    
    # 部署测试应用
    kubectl create deployment nginx --image=nginx
    kubectl scale deployment nginx --replicas=10
    
    # 应用网络策略
    cat <<EOF | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: nginx-policy
spec:
  endpointSelector:
    matchLabels:
      app: nginx
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: client
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
EOF
    
    # 性能测试
    kubectl run client --image=busybox --restart=Never -- sleep 3600
    kubectl wait --for=condition=Ready pod/client
    
    # 测试网络策略前后性能
    kubectl exec client -- wrk -t4 -c100 -d${TEST_DURATION}s http://nginx/ > $RESULT_DIR/ebpf_wrk.txt
    
    # 清理
    kubectl delete deployment nginx
    kubectl delete pod client
    kubectl delete cnp nginx-policy
}

# 生成性能报告
generate_report() {
    echo "=== 网络虚拟化性能报告 ===" > $RESULT_DIR/performance-report.txt
    echo "测试时间: $(date)" >> $RESULT_DIR/performance-report.txt
    echo "==========================" >> $RESULT_DIR/performance-report.txt
    
    # 分析结果
    if [ -f "$RESULT_DIR/physical_tcp.txt" ]; then
        echo "物理网络 TCP 吞吐量:" >> $RESULT_DIR/performance-report.txt
        grep "sender" $RESULT_DIR/physical_tcp.txt >> $RESULT_DIR/performance-report.txt
    fi
    
    if [ -f "$RESULT_DIR/overlay_tcp.txt" ]; then
        echo -e "\nOverlay 网络 TCP 吞吐量:" >> $RESULT_DIR/performance-report.txt
        grep "sender" $RESULT_DIR/overlay_tcp.txt >> $RESULT_DIR/performance-report.txt
    fi
    
    if [ -f "$RESULT_DIR/ebpf_wrk.txt" ]; then
        echo -e "\neBPF 网络策略性能:" >> $RESULT_DIR/performance-report.txt
        grep "Requests/sec" $RESULT_DIR/ebpf_wrk.txt >> $RESULT_DIR/performance-report.txt
    fi
    
    echo -e "\n性能对比分析:" >> $RESULT_DIR/performance-report.txt
    echo "详细结果请查看各测试文件" >> $RESULT_DIR/performance-report.txt
    
    # 发送报告
    cat $RESULT_DIR/performance-report.txt
}

# 执行测试
test_physical_network
test_overlay_network
test_ebpf_performance
generate_report
```

### 网络虚拟化优化策略

#### 内核网络优化

```bash
# /etc/sysctl.conf - 网络虚拟化性能优化

# GRO/GSO 优化
net.core.gro_receive_offload = 1
net.core.gso_send_offload = 1

# 网络缓冲区优化
net.core.netdev_budget = 300
net.core.netdev_max_backlog = 5000

# 虚拟网络优化
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_thin_linear_timeouts = 1

# XDP/eBPF 支持
net.core.bpf_jit_enable = 1
net.core.bpf_jit_harden = 0
net.core.bpf_jit_kallsyms = 1

# 应用配置
sysctl -p
```

#### 硬件加速配置

```bash
# SR-IOV 配置
enable_sriov() {
    local PF_INTERFACE=$1
    local VF_COUNT=$2
    
    # 启用 SR-IOV
    echo $VF_COUNT > /sys/class/net/$PF_INTERFACE/device/sriov_numvfs
    
    # 配置 VF
    for i in $(seq 0 $((VF_COUNT-1))); do
        # 设置 VF MAC 地址
        ip link set $PF_INTERFACE vf $i mac 00:11:22:33:44:$(printf "%02x" $i)
        
        # 设置 VF VLAN
        ip link set $PF_INTERFACE vf $i vlan 100
        
        # 启用 VF
        ip link set $PF_INTERFACE vf $i state enable
    done
}

# DPDK 环境配置
setup_dpdk() {
    # 绑定网卡到 DPDK
    modprobe uio
    insmod /usr/src/dpdk/build/kmod/igb_uio.ko
    
    # 绑定物理网卡
    /usr/src/dpdk/usertools/dpdk-devbind.py --bind=igb_uio 0000:01:00.0
    
    # 设置大页内存
    echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
    
    # 挂载大页
    mkdir -p /mnt/huge
    mount -t hugetlbfs nodev /mnt/huge
}
```

## 多租户网络隔离方案

### 网络隔离架构设计

#### 多租户隔离模型

```
┌─────────────────────────────────────────────────────────────────┐
│                        多租户网络隔离架构                          │
├─────────────────────────────────────────────────────────────────┤
│  租户边界隔离                                                   │
│  ├─ VPC 网络隔离                                               │
│  ├─ 网络命名空间                                               │
│  └─ 路由表隔离                                                 │
├─────────────────────────────────────────────────────────────────┤
│  应用层隔离                                                     │
│  ├─ NetworkPolicy                                              │
│  ├─ Service Mesh                                               │
│  └─ API 网关                                                   │
├─────────────────────────────────────────────────────────────────┤
│  数据层隔离                                                     │
│  ├─ 数据库存储隔离                                             │
│  ├─ 缓存实例隔离                                               │
│  └─ 文件系统隔离                                               │
└─────────────────────────────────────────────────────────────────┘
```

#### Kubernetes 多租户网络策略

```yaml
# 多租户网络隔离策略
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: tenant-isolation
spec:
  # 租户间网络隔离
  endpointSelector:
    matchExpressions:
      - {key: tenant, operator: Exists}
  
  # 禁止跨租户通信
  egress:
    - toEndpoints:
        - matchLabels:
            tenant: ${TENANT_ID}
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
            - port: "443"
              protocol: TCP
  
  # 允许必要的基础设施通信
  ingress:
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
            - port: "53"
              protocol: TCP

---
# 租户内部服务发现策略
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: intra-tenant-communication
  namespace: tenant-a
spec:
  endpointSelector:
    matchLabels:
      tenant: tenant-a
  
  # 允许租户内部服务通信
  ingress:
    - fromEndpoints:
        - matchLabels:
            tenant: tenant-a
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
  
  # 限制对外部服务的访问
  egress:
    - toCIDR:
        - 10.0.0.0/8
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
```

#### 租户资源配额管理

```yaml
# 租户网络资源配额
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-network-quota
  namespace: tenant-a
spec:
  hard:
    # 网络策略数量限制
    count/networkpolicies.networking.k8s.io: "50"
    
    # 服务数量限制
    services: "100"
    
    # 负载均衡器数量限制
    services.loadbalancers: "10"
    
    # NodePort 数量限制
    services.nodeports: "20"
    
    # Ingress 数量限制
    count/ingresses.networking.k8s.io: "20"

---
# 租户网络资源限制
apiVersion: v1
kind: LimitRange
metadata:
  name: tenant-network-limits
  namespace: tenant-a
spec:
  limits:
    - type: Container
      default:
        # 默认网络带宽限制
        kubernetes.io/egress-bandwidth: "100M"
        kubernetes.io/ingress-bandwidth: "100M"
      defaultRequest:
        kubernetes.io/egress-bandwidth: "10M"
        kubernetes.io/ingress-bandwidth: "10M"
```

### 租户网络监控与计量

```bash
# 多租户网络监控脚本
#!/bin/bash

TENANT_NAMESPACES=("tenant-a" "tenant-b" "tenant-c")
METRICS_OUTPUT="/var/log/tenant-network-metrics.log"

collect_tenant_metrics() {
    echo "=== 租户网络指标收集 ===" >> $METRICS_OUTPUT
    echo "收集时间: $(date)" >> $METRICS_OUTPUT
    
    for tenant in "${TENANT_NAMESPACES[@]}"; do
        echo "--- 租户: $tenant ---" >> $METRICS_OUTPUT
        
        # 网络策略数量
        policy_count=$(kubectl get networkpolicy -n $tenant --no-headers 2>/dev/null | wc -l)
        echo "网络策略数量: $policy_count" >> $METRICS_OUTPUT
        
        # 服务数量
        service_count=$(kubectl get svc -n $tenant --no-headers 2>/dev/null | wc -l)
        echo "服务数量: $service_count" >> $METRICS_OUTPUT
        
        # Pod 网络流量统计
        pod_traffic=$(kubectl top pods -n $tenant 2>/dev/null | awk 'NR>1 {sum+=$2} END {print sum}')
        echo "Pod CPU 使用: ${pod_traffic:-0}m" >> $METRICS_OUTPUT
        
        # 网络连接数
        connection_count=$(ss -t -n | grep -c ":.*:$tenant" 2>/dev/null || echo 0)
        echo "网络连接数: $connection_count" >> $METRICS_OUTPUT
        
        echo "" >> $METRICS_OUTPUT
    done
}

# 定期收集指标
while true; do
    collect_tenant_metrics
    sleep 300  # 每5分钟收集一次
done
```

## 生产环境部署指南

### 网络虚拟化生产部署

#### 部署架构规划

```
┌─────────────────────────────────────────────────────────────────┐
│                        生产环境网络架构                           │
├─────────────────────────────────────────────────────────────────┤
│  边界层                                                         │
│  ├─ 公网入口 (Cloud Load Balancer)                             │
│  ├─ WAF 防火墙                                                 │
│  └─ DDoS 防护                                                  │
├─────────────────────────────────────────────────────────────────┤
│  接入层                                                         │
│  ├─ Ingress Controller                                         │
│  ├─ API 网关                                                   │
│  └─ SSL 终止                                                   │
├─────────────────────────────────────────────────────────────────┤
│  核心网络层                                                     │
│  ├─ CNI 网络插件 (Calico/Cilium)                               │
│  ├─ 网络策略引擎                                               │
│  └─ 服务网格 (可选)                                            │
├─────────────────────────────────────────────────────────────────┤
│  应用层                                                         │
│  ├─ 微服务集群                                                 │
│  ├─ 数据库集群                                                 │
│  └─ 缓存集群                                                   │
└─────────────────────────────────────────────────────────────────┘
```

#### 生产环境 Calico 部署

```yaml
# Calico 生产环境配置
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  # 网络插件配置
  calicoNetwork:
    ipPools:
    - cidr: 10.244.0.0/16
      encapsulation: VXLAN
      natOutgoing: Enabled
      nodeSelector: all()
    
    # BGP 配置 (生产环境推荐)
    bgp: Enabled
    
    # MTU 配置
    mtu: 1450
    
    # 网络策略
    nodeAddressAutodetectionV4:
      firstFound: true
  
  # 资源配置
  componentResources:
  - componentName: Typha
    resourceRequirements:
      requests:
        cpu: 100m
        memory: 200Mi
      limits:
        cpu: 200m
        memory: 400Mi
  
  - componentName: CalicoNode
    resourceRequirements:
      requests:
        cpu: 250m
        memory: 250Mi
      limits:
        cpu: 500m
        memory: 500Mi

---
# 网络策略默认配置
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: default-deny
spec:
  order: 1000
  selector: all()
  types:
  - Ingress
  - Egress
  ingress:
  - action: Deny
  egress:
  - action: Deny

---
# 允许 DNS 查询
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: allow-dns
spec:
  order: 100
  selector: all()
  types:
  - Egress
  egress:
  - action: Allow
    protocol: UDP
    destination:
      ports:
      - 53
    destination:
      nets:
      - 10.96.0.10/32  # CoreDNS Service IP
```

#### 生产环境 Cilium 部署

```yaml
# Cilium 生产环境配置
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: cilium
  namespace: kube-system
spec:
  chart: cilium
  repo: https://helm.cilium.io/
  version: 1.12.0
  valuesContent: |-
    # 启用 eBPF 模式
    kubeProxyReplacement: "strict"
    
    # 启用 Hubble 可观测性
    hubble:
      enabled: true
      relay:
        enabled: true
      ui:
        enabled: true
    
    # 启用网络策略
    policyEnforcementMode: "always"
    
    # 启用加密
    encryption:
      enabled: true
      type: wireguard
    
    # 资源限制
    resources:
      requests:
        cpu: 100m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 1Gi
    
    # 监控配置
    prometheus:
      enabled: true
      serviceMonitor:
        enabled: true
    
    # 调试配置
    debug:
      enabled: false

---
# 生产环境网络策略示例
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: production-security
spec:
  description: "Production environment security policies"
  
  # 允许 kube-dns 通信
  - endpointSelector:
      matchLabels:
        k8s:io.kubernetes.pod.namespace: kube-system
        k8s-app: kube-dns
    ingress:
      - fromEntities:
          - cluster
        toPorts:
          - ports:
              - port: "53"
                protocol: ANY
  
  # 应用间通信策略
  - endpointSelector:
      matchLabels:
        app: web
    ingress:
      - fromEndpoints:
          - matchLabels:
              app: frontend
        toPorts:
          - ports:
              - port: "8080"
                protocol: TCP
  
  # 数据库访问控制
  - endpointSelector:
      matchLabels:
        app: database
    ingress:
      - fromEndpoints:
          - matchLabels:
              app: web
        toPorts:
          - ports:
              - port: "5432"
                protocol: TCP
```

#### 部署验证脚本

```bash
#!/bin/bash
# 网络虚拟化部署验证脚本

NAMESPACE="kube-system"
TIMEOUT=300  # 5分钟超时

echo "=== 网络虚拟化部署验证 ==="

# 检查 CNI 插件状态
check_cni_status() {
    echo "1. 检查 CNI 插件状态..."
    
    # 检查 Calico
    if kubectl get pods -n $NAMESPACE | grep -q "calico"; then
        echo "✓ Calico 部署状态:"
        kubectl get pods -n $NAMESPACE -l k8s-app=calico-node
        CALICO_PODS=$(kubectl get pods -n $NAMESPACE -l k8s-app=calico-node --no-headers | wc -l)
        READY_PODS=$(kubectl get pods -n $NAMESPACE -l k8s-app=calico-node --no-headers | grep Running | wc -l)
        echo "  Calico Pods: $READY_PODS/$CALICO_PODS Ready"
    fi
    
    # 检查 Cilium
    if kubectl get pods -n $NAMESPACE | grep -q "cilium"; then
        echo "✓ Cilium 部署状态:"
        kubectl get pods -n $NAMESPACE -l k8s-app=cilium
        CILIUM_PODS=$(kubectl get pods -n $NAMESPACE -l k8s-app=cilium --no-headers | wc -l)
        READY_PODS=$(kubectl get pods -n $NAMESPACE -l k8s-app=cilium --no-headers | grep Running | wc -l)
        echo "  Cilium Pods: $READY_PODS/$CILIUM_PODS Ready"
    fi
}

# 检查网络连通性
check_network_connectivity() {
    echo "2. 检查网络连通性..."
    
    # 部署测试 Pod
    kubectl create deployment test-net --image=busybox --replicas=2 -- sleep 3600
    kubectl wait --for=condition=Ready pod -l app=test-net --timeout=${TIMEOUT}s
    
    # 测试 Pod 间通信
    POD1=$(kubectl get pods -l app=test-net -o jsonpath='{.items[0].metadata.name}')
    POD2=$(kubectl get pods -l app=test-net -o jsonpath='{.items[1].metadata.name}')
    
    # 获取 Pod IP
    POD1_IP=$(kubectl get pod $POD1 -o jsonpath='{.status.podIP}')
    POD2_IP=$(kubectl get pod $POD2 -o jsonpath='{.status.podIP}')
    
    echo "  测试 Pod IPs: $POD1_IP, $POD2_IP"
    
    # 测试连通性
    if kubectl exec $POD1 -- ping -c 3 $POD2_IP >/dev/null 2>&1; then
        echo "✓ Pod 间网络连通性正常"
    else
        echo "✗ Pod 间网络连通性异常"
        return 1
    fi
    
    # 清理测试资源
    kubectl delete deployment test-net
}

# 检查网络策略
check_network_policies() {
    echo "3. 检查网络策略..."
    
    POLICY_COUNT=$(kubectl get networkpolicies --all-namespaces --no-headers 2>/dev/null | wc -l)
    echo "  网络策略总数: $POLICY_COUNT"
    
    if [ $POLICY_COUNT -gt 0 ]; then
        echo "✓ 网络策略已配置"
        kubectl get networkpolicies --all-namespaces
    else
        echo "⚠ 未配置网络策略"
    fi
}

# 检查监控组件
check_monitoring() {
    echo "4. 检查监控组件..."
    
    # 检查 Hubble (Cilium)
    if kubectl get pods -n $NAMESPACE | grep -q "hubble"; then
        HUBBLE_PODS=$(kubectl get pods -n $NAMESPACE -l k8s-app=hubble --no-headers | wc -l)
        READY_HUBBLE=$(kubectl get pods -n $NAMESPACE -l k8s-app=hubble --no-headers | grep Running | wc -l)
        echo "  Hubble Pods: $READY_HUBBLE/$HUBBLE_PODS Ready"
    fi
    
    # 检查 Prometheus 监控
    if kubectl get servicemonitors -n $NAMESPACE >/dev/null 2>&1; then
        MONITORS=$(kubectl get servicemonitors -n $NAMESPACE --no-headers | wc -l)
        echo "  ServiceMonitors: $MONITORS"
    fi
}

# 执行验证
check_cni_status
echo ""
check_network_connectivity
echo ""
check_network_policies
echo ""
check_monitoring

echo ""
echo "=== 验证完成 ==="
```

---

## 相关文档

- [01-network-protocols-stack](./01-network-protocols-stack.md) - 网络协议栈
- [203-docker-networking-deep-dive](./203-docker-networking-deep-dive.md) - Docker 网络
- [45-cni-network-plugins](./45-cni-network-plugins.md) - CNI 插件
