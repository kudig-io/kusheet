# CNI 容器网络接口深度解析 (Container Network Interface Deep Dive)

## 目录

1. [CNI 架构概述](#1-cni-架构概述)
2. [CNI 规范详解](#2-cni-规范详解)
3. [CNI 插件类型](#3-cni-插件类型)
4. [Calico 深度解析](#4-calico-深度解析)
5. [Cilium 深度解析](#5-cilium-深度解析)
6. [其他主流 CNI](#6-其他主流-cni)
7. [网络策略实现](#7-网络策略实现)
8. [CNI 配置与调优](#8-cni-配置与调优)
9. [监控与故障排查](#9-监控与故障排查)
10. [生产实践案例](#10-生产实践案例)

---

## 1. CNI 架构概述

### 1.1 CNI 发展历史

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          CNI Evolution Timeline                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  2015          2016          2017          2018          2019          2020     │
│    │             │             │             │             │             │       │
│    ▼             ▼             ▼             ▼             ▼             ▼       │
│  CNI          CNI 0.3      Calico       Cilium        Calico        Cilium     │
│  诞生         规范化       IPIP模式     eBPF实现      eBPF模式      成熟        │
│  (CoreOS)                 成熟          发布          引入                      │
│                                                                                  │
│  2021          2022          2023          2024          2025                   │
│    │             │             │             │             │                     │
│    ▼             ▼             ▼             ▼             ▼                     │
│  CNI 1.0      Cilium       Calico       CNI 1.1      eBPF                       │
│  发布         1.12         eBPF GA      Multi-NIC    主流                       │
│              Service Mesh  替代kube-proxy                                       │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 CNI 核心概念

| 概念 | 描述 | 作用 |
|------|------|------|
| **Container Runtime** | 容器运行时 (containerd/CRI-O) | 调用 CNI 插件 |
| **CNI Plugin** | 网络插件可执行文件 | 配置容器网络 |
| **CNI Config** | JSON 配置文件 | 定义网络参数 |
| **Network Namespace** | 网络命名空间 | 隔离容器网络 |
| **IPAM** | IP 地址管理 | 分配 IP 地址 |
| **Chaining** | 插件链 | 组合多个插件 |

### 1.3 CNI 架构图

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              CNI Architecture                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                              Kubernetes                                  │    │
│  │  ┌─────────────┐                                                         │    │
│  │  │   Kubelet   │                                                         │    │
│  │  └──────┬──────┘                                                         │    │
│  │         │ CRI                                                            │    │
│  │         ▼                                                                │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │                    Container Runtime                                 ││    │
│  │  │              (containerd / CRI-O)                                    ││    │
│  │  └──────────────────────────┬──────────────────────────────────────────┘│    │
│  └─────────────────────────────┼────────────────────────────────────────────┘    │
│                                │                                                 │
│                                │ CNI ADD/DEL/CHECK/VERSION                       │
│                                ▼                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                           CNI Plugin Chain                               │    │
│  │                                                                          │    │
│  │  ┌───────────────┐     ┌───────────────┐     ┌───────────────────────┐  │    │
│  │  │  Main Plugin  │ ──► │  IPAM Plugin  │ ──► │   Meta/Chained Plugin │  │    │
│  │  │               │     │               │     │                       │  │    │
│  │  │ - bridge      │     │ - host-local  │     │ - portmap             │  │    │
│  │  │ - macvlan     │     │ - dhcp        │     │ - bandwidth           │  │    │
│  │  │ - ipvlan      │     │ - static      │     │ - firewall            │  │    │
│  │  │ - ptp         │     │ - calico-ipam │     │ - tuning              │  │    │
│  │  │ - vlan        │     │ - cilium-ipam │     │ - sbr                 │  │    │
│  │  │ - calico      │     │               │     │                       │  │    │
│  │  │ - cilium      │     │               │     │                       │  │    │
│  │  └───────────────┘     └───────────────┘     └───────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                │                                                 │
│                                │ 配置网络命名空间                                │
│                                ▼                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                        Pod Network Namespace                             │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │  eth0 (veth pair) ────────────────────────► Host veth               ││    │
│  │  │  IP: 10.244.1.10/24                                                 ││    │
│  │  │  Gateway: 10.244.1.1                                                ││    │
│  │  │                                                                      ││    │
│  │  │  路由表:                                                             ││    │
│  │  │  default via 10.244.1.1 dev eth0                                    ││    │
│  │  │  10.244.1.0/24 dev eth0 scope link                                  ││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 1.4 CNI 调用流程

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           CNI Invocation Flow                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  1. Kubelet 请求创建 Pod                                                        │
│     │                                                                            │
│     ▼                                                                            │
│  2. Container Runtime 创建 Pod Sandbox                                          │
│     │                                                                            │
│     ▼                                                                            │
│  3. Container Runtime 创建网络命名空间                                           │
│     ip netns add <netns>                                                        │
│     │                                                                            │
│     ▼                                                                            │
│  4. Container Runtime 读取 CNI 配置                                             │
│     /etc/cni/net.d/10-calico.conflist                                           │
│     │                                                                            │
│     ▼                                                                            │
│  5. Container Runtime 调用 CNI 插件                                             │
│     环境变量:                                                                    │
│       CNI_COMMAND=ADD                                                           │
│       CNI_CONTAINERID=<container-id>                                            │
│       CNI_NETNS=/var/run/netns/<netns>                                          │
│       CNI_IFNAME=eth0                                                           │
│       CNI_PATH=/opt/cni/bin                                                     │
│     标准输入: CNI 配置 JSON                                                      │
│     │                                                                            │
│     ▼                                                                            │
│  6. CNI 插件执行网络配置                                                         │
│     ├── 创建 veth pair                                                          │
│     ├── 将 veth 一端移入 Pod netns                                              │
│     ├── 配置 IP 地址                                                            │
│     ├── 配置路由                                                                │
│     └── 配置 iptables/eBPF 规则                                                 │
│     │                                                                            │
│     ▼                                                                            │
│  7. CNI 插件返回结果                                                            │
│     标准输出: {                                                                  │
│       "cniVersion": "1.0.0",                                                    │
│       "interfaces": [...],                                                      │
│       "ips": [{"address": "10.244.1.10/24", ...}],                              │
│       "routes": [...]                                                           │
│     }                                                                           │
│     │                                                                            │
│     ▼                                                                            │
│  8. Pod 网络就绪                                                                │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. CNI 规范详解

### 2.1 CNI 操作

| 操作 | 描述 | 返回值 |
|------|------|--------|
| **ADD** | 添加容器到网络 | 网络配置结果 |
| **DEL** | 从网络删除容器 | 空/错误 |
| **CHECK** | 检查容器网络状态 | 空/错误 |
| **VERSION** | 获取支持的版本 | 版本列表 |

### 2.2 CNI 配置格式

```json
// /etc/cni/net.d/10-mynet.conflist
{
  "cniVersion": "1.0.0",
  "name": "mynet",
  "plugins": [
    {
      "type": "bridge",
      "bridge": "cni0",
      "isGateway": true,
      "isDefaultGateway": true,
      "forceAddress": false,
      "ipMasq": true,
      "hairpinMode": true,
      "mtu": 1500,
      "ipam": {
        "type": "host-local",
        "ranges": [
          [
            {
              "subnet": "10.244.0.0/16",
              "rangeStart": "10.244.1.10",
              "rangeEnd": "10.244.1.250",
              "gateway": "10.244.1.1"
            }
          ]
        ],
        "routes": [
          {"dst": "0.0.0.0/0"},
          {"dst": "10.96.0.0/12"}
        ],
        "dataDir": "/var/lib/cni/networks/mynet"
      }
    },
    {
      "type": "portmap",
      "capabilities": {
        "portMappings": true
      },
      "snat": true
    },
    {
      "type": "bandwidth",
      "capabilities": {
        "bandwidth": true
      }
    }
  ]
}
```

### 2.3 CNI 结果格式

```json
// CNI ADD 返回结果
{
  "cniVersion": "1.0.0",
  "interfaces": [
    {
      "name": "eth0",
      "mac": "0a:58:0a:f4:01:0a",
      "sandbox": "/var/run/netns/cni-xxxxx"
    },
    {
      "name": "vethxxxxx",
      "mac": "0a:58:0a:f4:01:01"
    }
  ],
  "ips": [
    {
      "address": "10.244.1.10/24",
      "gateway": "10.244.1.1",
      "interface": 0
    }
  ],
  "routes": [
    {
      "dst": "0.0.0.0/0",
      "gw": "10.244.1.1"
    },
    {
      "dst": "10.96.0.0/12"
    }
  ],
  "dns": {
    "nameservers": ["10.96.0.10"],
    "domain": "cluster.local",
    "search": ["default.svc.cluster.local", "svc.cluster.local", "cluster.local"]
  }
}
```

### 2.4 CNI 环境变量

| 环境变量 | 描述 | 示例 |
|----------|------|------|
| CNI_COMMAND | 操作类型 | ADD/DEL/CHECK/VERSION |
| CNI_CONTAINERID | 容器 ID | abc123def456 |
| CNI_NETNS | 网络命名空间路径 | /var/run/netns/cni-xxx |
| CNI_IFNAME | 接口名称 | eth0 |
| CNI_ARGS | 额外参数 | K8S_POD_NAME=nginx;K8S_POD_NAMESPACE=default |
| CNI_PATH | 插件搜索路径 | /opt/cni/bin |

---

## 3. CNI 插件类型

### 3.1 主要插件 (Main Plugins)

| 插件 | 描述 | 适用场景 |
|------|------|----------|
| **bridge** | Linux 网桥模式 | 单节点/小规模集群 |
| **macvlan** | MAC VLAN 模式 | 需要独立 MAC 地址 |
| **ipvlan** | IP VLAN 模式 | 高性能场景 |
| **ptp** | 点对点 veth | 简单网络 |
| **vlan** | VLAN 模式 | 传统网络集成 |
| **host-device** | 直接使用主机设备 | SR-IOV/硬件直通 |
| **calico** | Calico CNI | 生产级网络 |
| **cilium** | Cilium CNI | eBPF 网络 |
| **flannel** | Flannel CNI | 简单 overlay |
| **weave** | Weave Net CNI | 多集群网络 |

### 3.2 IPAM 插件

| 插件 | 描述 | 特点 |
|------|------|------|
| **host-local** | 本地 IP 分配 | 简单，无需外部依赖 |
| **dhcp** | DHCP 分配 | 集成现有 DHCP |
| **static** | 静态 IP | 固定 IP 场景 |
| **calico-ipam** | Calico IPAM | IP Pool 管理 |
| **whereabouts** | 跨节点 IPAM | 无需 etcd |

### 3.3 Meta/Chained 插件

| 插件 | 描述 | 功能 |
|------|------|------|
| **portmap** | 端口映射 | hostPort 支持 |
| **bandwidth** | 带宽限制 | 流量整形 |
| **firewall** | 防火墙规则 | iptables 规则 |
| **tuning** | 系统调优 | sysctl 配置 |
| **sbr** | 源路由 | 多网卡路由 |
| **vrf** | VRF 设备 | 路由隔离 |

### 3.4 CNI 插件对比

| 特性 | bridge | macvlan | ipvlan | Calico | Cilium |
|------|--------|---------|--------|--------|--------|
| **性能** | 中 | 高 | 高 | 高 | 最高 |
| **复杂度** | 低 | 中 | 中 | 高 | 高 |
| **跨节点** | 需 overlay | 需路由 | 需路由 | 支持 | 支持 |
| **NetworkPolicy** | 否 | 否 | 否 | 是 | 是 |
| **加密** | 否 | 否 | 否 | WireGuard | WireGuard/IPsec |
| **eBPF** | 否 | 否 | 否 | 可选 | 原生 |
| **Service Mesh** | 否 | 否 | 否 | 否 | 是 |

---

## 4. Calico 深度解析

### 4.1 Calico 架构

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Calico Architecture                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                           Control Plane                                  │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │                    calico-kube-controllers                           ││    │
│  │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌───────────────┐  ││    │
│  │  │  │  Node   │ │ Policy  │ │Workload │ │Service  │ │ Namespace     │  ││    │
│  │  │  │Controller│ │Controller│ │Endpoint│ │Account  │ │ Controller    │  ││    │
│  │  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └───────────────┘  ││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  │                                    │                                     │    │
│  │                                    │ Kubernetes API / Calico Datastore   │    │
│  │                                    ▼                                     │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │                         Calico Datastore                             ││    │
│  │  │        (Kubernetes API Server / etcd)                                ││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                    │                                             │
│  ══════════════════════════════════╪═════════════════════════════════════════   │
│                                    │                                             │
│  ┌─────────────────────────────────┼───────────────────────────────────────┐    │
│  │                           Node (每个节点)                                │    │
│  │                                 │                                        │    │
│  │  ┌─────────────────────────────┴───────────────────────────────────────┐│    │
│  │  │                          calico-node (DaemonSet)                     ││    │
│  │  │                                                                      ││    │
│  │  │  ┌───────────────────────────────────────────────────────────────┐  ││    │
│  │  │  │                         Felix                                  │  ││    │
│  │  │  │  - 编程主机路由表                                              │  ││    │
│  │  │  │  - 编程 iptables/eBPF 规则                                     │  ││    │
│  │  │  │  - 实现 NetworkPolicy                                          │  ││    │
│  │  │  │  - 管理接口                                                    │  ││    │
│  │  │  └───────────────────────────────────────────────────────────────┘  ││    │
│  │  │                                                                      ││    │
│  │  │  ┌───────────────────────────────────────────────────────────────┐  ││    │
│  │  │  │                          BIRD                                  │  ││    │
│  │  │  │  - BGP 客户端                                                  │  ││    │
│  │  │  │  - 分发路由信息                                                │  ││    │
│  │  │  │  - 与 ToR/路由器 对接                                          │  ││    │
│  │  │  └───────────────────────────────────────────────────────────────┘  ││    │
│  │  │                                                                      ││    │
│  │  │  ┌───────────────────────────────────────────────────────────────┐  ││    │
│  │  │  │                       confd                                    │  ││    │
│  │  │  │  - 监听 Calico 配置变化                                        │  ││    │
│  │  │  │  - 生成 BIRD 配置文件                                          │  ││    │
│  │  │  └───────────────────────────────────────────────────────────────┘  ││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  │                                                                          │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │                       calico-cni (CNI Plugin)                        ││    │
│  │  │  - 响应 kubelet CNI 调用                                             ││    │
│  │  │  - 创建 veth pair                                                    ││    │
│  │  │  - 配置容器网络命名空间                                              ││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Calico 网络模式

| 模式 | 描述 | 性能 | 适用场景 |
|------|------|------|----------|
| **BGP (无封装)** | 纯三层路由 | 最高 | 支持 BGP 的数据中心 |
| **IPIP** | IP-in-IP 封装 | 高 | 跨子网通信 |
| **VXLAN** | VXLAN 封装 | 中高 | 通用，无需 BGP |
| **CrossSubnet** | 混合模式 | 高 | 部分跨子网 |

```yaml
# Calico IPPool 配置
apiVersion: crd.projectcalico.org/v1
kind: IPPool
metadata:
  name: default-ipv4-ippool
spec:
  cidr: 10.244.0.0/16
  blockSize: 26              # 每节点 /26 块 (64 个 IP)
  ipipMode: CrossSubnet      # Never, Always, CrossSubnet
  vxlanMode: Never           # Never, Always, CrossSubnet
  natOutgoing: true
  nodeSelector: all()
  allowedUses:
  - Workload
  - Tunnel

---
# VXLAN 模式
apiVersion: crd.projectcalico.org/v1
kind: IPPool
metadata:
  name: vxlan-pool
spec:
  cidr: 10.244.0.0/16
  ipipMode: Never
  vxlanMode: Always
  natOutgoing: true

---
# BGP 纯路由模式
apiVersion: crd.projectcalico.org/v1
kind: IPPool
metadata:
  name: bgp-pool
spec:
  cidr: 10.244.0.0/16
  ipipMode: Never
  vxlanMode: Never
  natOutgoing: false  # 使用 BGP 时通常不需要
```

### 4.3 Calico BGP 配置

```yaml
# BGPConfiguration - 全局配置
apiVersion: crd.projectcalico.org/v1
kind: BGPConfiguration
metadata:
  name: default
spec:
  asNumber: 64512
  nodeToNodeMeshEnabled: true  # 节点间 full-mesh BGP
  serviceClusterIPs:
  - cidr: 10.96.0.0/12
  serviceExternalIPs:
  - cidr: 192.168.100.0/24
  serviceLoadBalancerIPs:
  - cidr: 192.168.200.0/24

---
# BGPPeer - 与外部路由器对接
apiVersion: crd.projectcalico.org/v1
kind: BGPPeer
metadata:
  name: rack1-tor
spec:
  peerIP: 192.168.1.1
  asNumber: 64513
  nodeSelector: rack == "rack1"
  password:
    secretKeyRef:
      name: bgp-secrets
      key: rack1-password
  sourceAddress: None
  failureDetectionMode: BFD  # 启用 BFD

---
# 节点级 BGP 配置
apiVersion: crd.projectcalico.org/v1
kind: Node
metadata:
  name: node1
spec:
  bgp:
    asNumber: 64512
    ipv4Address: 192.168.1.10/24
    ipv4IPIPTunnelAddr: 10.244.0.1
  orchRefs:
  - nodeName: node1
    orchestrator: k8s
```

### 4.4 Calico 安装配置

```bash
# 使用 Operator 安装 Calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml

# 创建 Installation 资源
cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    bgp: Enabled
    hostPorts: Enabled
    multiInterfaceMode: None
    nodeAddressAutodetectionV4:
      firstFound: true
    ipPools:
    - blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLAN
      natOutgoing: Enabled
      nodeSelector: all()
  registry: quay.io/
  variant: Calico
---
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
EOF

# 验证安装
kubectl get tigerastatus
kubectl get pods -n calico-system
```

### 4.5 Calico eBPF 模式

```yaml
# 启用 eBPF 数据平面
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    linuxDataplane: BPF  # 关键配置
    hostPorts: Enabled
    ipPools:
    - blockSize: 26
      cidr: 10.244.0.0/16
      natOutgoing: Enabled
  cni:
    type: Calico
  flexVolumePath: /usr/libexec/kubernetes/kubelet-plugins/volume/exec/
  nodeMetricsPort: 9091
  typhaMetricsPort: 9093

---
# FelixConfiguration 启用 eBPF
apiVersion: crd.projectcalico.org/v1
kind: FelixConfiguration
metadata:
  name: default
spec:
  bpfEnabled: true
  bpfDisableUnprivileged: true
  bpfLogLevel: Info
  bpfDataIfacePattern: "^(en.*|eth.*|tunl0$|vxlan.calico$|wireguard.cali$)"
  bpfConnectTimeLoadBalancingEnabled: true
  bpfExternalServiceMode: Tunnel
  bpfKubeProxyIptablesCleanupEnabled: true
  bpfKubeProxyMinSyncPeriod: 1s
  # 禁用 kube-proxy (eBPF 替代)
  # kubectl patch ds -n kube-system kube-proxy -p '{"spec":{"template":{"spec":{"nodeSelector":{"non-calico": "true"}}}}}'
```

### 4.6 Calico NetworkPolicy

```yaml
# Kubernetes NetworkPolicy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: production
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53

---
# Calico GlobalNetworkPolicy
apiVersion: crd.projectcalico.org/v1
kind: GlobalNetworkPolicy
metadata:
  name: deny-all-egress-to-internet
spec:
  order: 100
  selector: projectcalico.org/namespace != "kube-system"
  types:
  - Egress
  egress:
  - action: Deny
    destination:
      notNets:
      - 10.0.0.0/8
      - 172.16.0.0/12
      - 192.168.0.0/16
    protocol: TCP
  - action: Deny
    destination:
      notNets:
      - 10.0.0.0/8
      - 172.16.0.0/12
      - 192.168.0.0/16
    protocol: UDP

---
# Calico NetworkPolicy (扩展功能)
apiVersion: crd.projectcalico.org/v1
kind: NetworkPolicy
metadata:
  name: allow-tcp-443
  namespace: production
spec:
  selector: app == "web"
  ingress:
  - action: Allow
    protocol: TCP
    source:
      serviceAccounts:
        names:
        - frontend-sa
        namespace: production
    destination:
      ports:
      - 443
  - action: Allow
    protocol: TCP
    source:
      nets:
      - 10.0.0.0/8
    destination:
      ports:
      - 80
      - 443
    http:  # HTTP 规则 (需要 Istio)
      methods:
      - GET
      - POST
      paths:
      - prefix: /api/
```

---

## 5. Cilium 深度解析

### 5.1 Cilium 架构

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            Cilium Architecture                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                           Control Plane                                  │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │                      cilium-operator                                 ││    │
│  │  │  - IPAM 管理                                                         ││    │
│  │  │  - CRD 生命周期管理                                                  ││    │
│  │  │  - 集群范围资源同步                                                  ││    │
│  │  │  - BGP 控制平面 (可选)                                               ││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  │                                    │                                     │    │
│  │                                    │ K8s API                             │    │
│  │                                    ▼                                     │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │                     Kubernetes API Server                            ││    │
│  │  │  - CiliumNetworkPolicy                                               ││    │
│  │  │  - CiliumClusterwideNetworkPolicy                                    ││    │
│  │  │  - CiliumEndpoint                                                    ││    │
│  │  │  - CiliumIdentity                                                    ││    │
│  │  │  - CiliumNode                                                        ││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                    │                                             │
│  ══════════════════════════════════╪═════════════════════════════════════════   │
│                                    │                                             │
│  ┌─────────────────────────────────┼───────────────────────────────────────┐    │
│  │                           Node (每个节点)                                │    │
│  │                                 │                                        │    │
│  │  ┌─────────────────────────────┴───────────────────────────────────────┐│    │
│  │  │                      cilium-agent (DaemonSet)                        ││    │
│  │  │                                                                      ││    │
│  │  │  ┌───────────────────────────────────────────────────────────────┐  ││    │
│  │  │  │                    eBPF Datapath                               │  ││    │
│  │  │  │                                                                │  ││    │
│  │  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐│  ││    │
│  │  │  │  │  XDP Hook   │  │  TC Hook    │  │    Socket Hook          ││  ││    │
│  │  │  │  │ (入口过滤)   │  │ (策略执行)  │  │  (L7 代理)              ││  ││    │
│  │  │  │  └─────────────┘  └─────────────┘  └─────────────────────────┘│  ││    │
│  │  │  │                                                                │  ││    │
│  │  │  │  ┌─────────────────────────────────────────────────────────┐  │  ││    │
│  │  │  │  │                   eBPF Maps                              │  │  ││    │
│  │  │  │  │  - Endpoint Map     - Policy Map                        │  │  ││    │
│  │  │  │  │  - CT (Connection Track) Map                            │  │  ││    │
│  │  │  │  │  - NAT Map          - Service Map                       │  │  ││    │
│  │  │  │  │  - Identity Map     - Metrics Map                       │  │  ││    │
│  │  │  │  └─────────────────────────────────────────────────────────┘  │  ││    │
│  │  │  └───────────────────────────────────────────────────────────────┘  ││    │
│  │  │                                                                      ││    │
│  │  │  ┌───────────────────────────────────────────────────────────────┐  ││    │
│  │  │  │                   Envoy Proxy (可选)                          │  ││    │
│  │  │  │  - L7 策略执行                                                │  ││    │
│  │  │  │  - HTTP/gRPC 可见性                                           │  ││    │
│  │  │  │  - mTLS 终止                                                  │  ││    │
│  │  │  └───────────────────────────────────────────────────────────────┘  ││    │
│  │  │                                                                      ││    │
│  │  │  ┌───────────────────────────────────────────────────────────────┐  ││    │
│  │  │  │                   Hubble (可观测性)                           │  ││    │
│  │  │  │  - 流量可见性                                                 │  ││    │
│  │  │  │  - 策略决策日志                                               │  ││    │
│  │  │  │  - 服务依赖图                                                 │  ││    │
│  │  │  └───────────────────────────────────────────────────────────────┘  ││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Cilium eBPF 数据路径

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          Cilium eBPF Datapath                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  入站流量 (Ingress)                                                              │
│                                                                                  │
│  NIC ──► XDP ──► TC Ingress ──► Network Stack ──► Socket ──► Application        │
│          │         │                                 │                           │
│          │         │                                 │                           │
│          ▼         ▼                                 ▼                           │
│      ┌───────┐ ┌───────────┐                   ┌───────────┐                    │
│      │ XDP   │ │ TC BPF    │                   │ Socket    │                    │
│      │ Prog  │ │ Programs  │                   │ BPF Prog  │                    │
│      │       │ │           │                   │           │                    │
│      │- Drop │ │- Policy   │                   │- L7 proxy │                    │
│      │  DDoS │ │  Check    │                   │- Sockmap  │                    │
│      │- LB   │ │- NAT      │                   │  redirect │                    │
│      │  hash │ │- Conntrack│                   │           │                    │
│      └───────┘ └───────────┘                   └───────────┘                    │
│                                                                                  │
│  出站流量 (Egress)                                                               │
│                                                                                  │
│  Application ──► Socket ──► TC Egress ──► NIC                                   │
│                     │            │                                               │
│                     │            │                                               │
│                     ▼            ▼                                               │
│               ┌───────────┐ ┌───────────┐                                       │
│               │ Socket    │ │ TC BPF    │                                       │
│               │ BPF Prog  │ │ Programs  │                                       │
│               │           │ │           │                                       │
│               │- Sockmap  │ │- Policy   │                                       │
│               │  bypass   │ │  Check    │                                       │
│               │- L7 proxy │ │- NAT      │                                       │
│               │           │ │- LB       │                                       │
│               └───────────┘ └───────────┘                                       │
│                                                                                  │
│  eBPF Maps (共享状态)                                                           │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                                                                          │    │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────────────────┐│    │
│  │  │ Endpoint   │ │ Policy     │ │ Service    │ │ Connection Tracking    ││    │
│  │  │ Map        │ │ Map        │ │ Map        │ │ Map                    ││    │
│  │  │            │ │            │ │            │ │                        ││    │
│  │  │ Endpoint→  │ │ Identity→  │ │ VIP:Port→  │ │ 5-tuple → CT entry    ││    │
│  │  │   Config   │ │   Rules    │ │   Backend  │ │   (state, NAT info)   ││    │
│  │  └────────────┘ └────────────┘ └────────────┘ └────────────────────────┘│    │
│  │                                                                          │    │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────────────────┐│    │
│  │  │ Identity   │ │ NAT        │ │ LB         │ │ Metrics                ││    │
│  │  │ Map        │ │ Map        │ │ Maglev Map │ │ Map                    ││    │
│  │  │            │ │            │ │            │ │                        ││    │
│  │  │ IP/Label→  │ │ Old addr→  │ │ Hash→      │ │ Per-endpoint           ││    │
│  │  │   Identity │ │   New addr │ │   Backend  │ │   Statistics           ││    │
│  │  └────────────┘ └────────────┘ └────────────┘ └────────────────────────┘│    │
│  │                                                                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 Cilium 安装配置

```bash
# 使用 Helm 安装 Cilium
helm repo add cilium https://helm.cilium.io/
helm repo update

# 安装 Cilium (替代 kube-proxy)
helm install cilium cilium/cilium --version 1.15.0 \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="${API_SERVER_IP}" \
  --set k8sServicePort="${API_SERVER_PORT}" \
  --set ipam.mode=kubernetes \
  --set tunnel=disabled \
  --set autoDirectNodeRoutes=true \
  --set bpf.masquerade=true \
  --set ipv4NativeRoutingCIDR="10.0.0.0/8" \
  --set loadBalancer.algorithm=maglev \
  --set loadBalancer.mode=dsr \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set prometheus.enabled=true \
  --set operator.prometheus.enabled=true

# 验证安装
cilium status
cilium connectivity test
```

### 5.4 Cilium 配置选项

```yaml
# Cilium ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: cilium-config
  namespace: kube-system
data:
  # IPAM 模式
  ipam: kubernetes  # cluster-pool, kubernetes, eni, azure, alibabacloud
  cluster-pool-ipv4-cidr: "10.0.0.0/8"
  cluster-pool-ipv4-mask-size: "24"
  
  # 隧道模式
  tunnel: vxlan  # disabled, vxlan, geneve
  tunnel-port: "8472"
  
  # 原生路由
  auto-direct-node-routes: "true"
  ipv4-native-routing-cidr: "10.0.0.0/8"
  
  # kube-proxy 替代
  kube-proxy-replacement: "true"
  enable-bpf-masquerade: "true"
  
  # 负载均衡
  loadbalancer-algorithm: maglev  # random, maglev
  loadbalancer-mode: dsr  # snat, dsr, hybrid
  
  # eBPF 配置
  enable-bpf-clock-probe: "true"
  enable-endpoint-health-checking: "true"
  bpf-map-dynamic-size-ratio: "0.0025"
  bpf-policy-map-max: "16384"
  bpf-ct-global-tcp-max: "524288"
  bpf-ct-global-any-max: "262144"
  
  # 加密
  enable-wireguard: "true"
  enable-wireguard-userspace-fallback: "false"
  
  # 带宽管理
  enable-bandwidth-manager: "true"
  
  # BBR 拥塞控制
  enable-bbr: "true"
  
  # L7 代理
  enable-envoy-config: "true"
  
  # 监控
  prometheus-serve-addr: ":9962"
  operator-prometheus-serve-addr: ":9963"
  enable-metrics: "true"
  metrics: "+cilium_endpoint_state,+cilium_services_events_total"
  
  # Hubble
  enable-hubble: "true"
  hubble-listen-address: ":4244"
  hubble-metrics-server: ":9965"
  hubble-metrics: "dns,drop,tcp,flow,icmp,http"
  
  # 调试
  debug: "false"
  debug-verbose: ""
  monitor-aggregation: medium
  monitor-aggregation-interval: 5s
```

### 5.5 Cilium NetworkPolicy

```yaml
# CiliumNetworkPolicy (L3/L4)
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-web
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: web
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    - matchLabels:
        io.kubernetes.pod.namespace: monitoring
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      - port: "443"
        protocol: TCP
  - fromCIDR:
    - 10.0.0.0/8
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
  egress:
  - toEndpoints:
    - matchLabels:
        app: database
    toPorts:
    - ports:
      - port: "5432"
        protocol: TCP
  - toFQDNs:
    - matchName: "api.example.com"
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP

---
# CiliumNetworkPolicy (L7 HTTP)
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: http-policy
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: GET
          path: "/api/v1/.*"
        - method: POST
          path: "/api/v1/users"
          headers:
          - 'Content-Type: application/json'
        - method: DELETE
          path: "/api/v1/users/[0-9]+"

---
# CiliumClusterwideNetworkPolicy
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: deny-external-egress
spec:
  endpointSelector:
    matchExpressions:
    - key: io.kubernetes.pod.namespace
      operator: NotIn
      values:
      - kube-system
      - cilium
  egressDeny:
  - toCIDR:
    - 0.0.0.0/0
    exceptCIDRs:
    - 10.0.0.0/8
    - 172.16.0.0/12
    - 192.168.0.0/16
```

### 5.6 Cilium Service Mesh

```yaml
# 启用 Cilium Service Mesh (Envoy)
helm upgrade cilium cilium/cilium --namespace kube-system \
  --set envoy.enabled=true \
  --set ingressController.enabled=true \
  --set ingressController.loadbalancerMode=dedicated

---
# CiliumEnvoyConfig (L7 负载均衡)
apiVersion: cilium.io/v2
kind: CiliumEnvoyConfig
metadata:
  name: envoy-lb-config
spec:
  services:
  - name: my-service
    namespace: default
  resources:
  - "@type": type.googleapis.com/envoy.config.listener.v3.Listener
    name: envoy-lb-listener
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: envoy-lb-listener
          route_config:
            name: local_route
            virtual_hosts:
            - name: local_service
              domains: ["*"]
              routes:
              - match:
                  prefix: "/"
                route:
                  cluster: default/my-service
```

---

## 6. 其他主流 CNI

### 6.1 Flannel

```yaml
# Flannel 配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-flannel-cfg
  namespace: kube-flannel
data:
  cni-conf.json: |
    {
      "name": "cbr0",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "hairpinMode": true,
            "isDefaultGateway": true
          }
        },
        {
          "type": "portmap",
          "capabilities": {
            "portMappings": true
          }
        }
      ]
    }
  net-conf.json: |
    {
      "Network": "10.244.0.0/16",
      "Backend": {
        "Type": "vxlan",
        "VNI": 1,
        "Port": 8472,
        "DirectRouting": true
      }
    }
```

| Flannel 后端 | 描述 | 性能 |
|--------------|------|------|
| vxlan | VXLAN 封装 | 中 |
| host-gw | 主机网关路由 | 高 (需同子网) |
| wireguard | WireGuard 加密 | 中 |
| ipip | IP-in-IP 封装 | 中 |
| ipsec | IPsec 加密 | 低 |

### 6.2 Weave Net

```bash
# 安装 Weave Net
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

# 设置密码加密
kubectl create secret -n kube-system generic weave-passwd \
  --from-literal=weave-passwd=s3cr3t

# Weave 配置
kubectl patch daemonset weave-net -n kube-system \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name": "WEAVE_PASSWORD", "valueFrom": {"secretKeyRef": {"name": "weave-passwd", "key": "weave-passwd"}}}}]'
```

### 6.3 Antrea

```yaml
# Antrea 配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: antrea-config
  namespace: kube-system
data:
  antrea-agent.conf: |
    featureGates:
      AntreaProxy: true
      EndpointSlice: true
      Traceflow: true
      NetworkPolicyStats: true
      FlowExporter: true
      AntreaPolicy: true
      Multicast: false
      Egress: true
      NodePortLocal: true
      AntreaIPAM: false
    trafficEncapMode: encap  # encap, noEncap, hybrid
    tunnelType: geneve  # geneve, vxlan, gre
    enablePrometheusMetrics: true
    flowExporter:
      enable: true
      flowCollectorAddr: "flow-aggregator.flow-aggregator.svc:4739:tcp"
    nodePortLocal:
      enable: true
      portRange: "61000-62000"
```

### 6.4 CNI 选型对比

| CNI | 性能 | NetworkPolicy | 加密 | Service Mesh | 复杂度 | 适用场景 |
|-----|------|---------------|------|--------------|--------|----------|
| **Calico** | 高 | 完整 | WireGuard | 否 | 中 | 通用生产 |
| **Cilium** | 最高 | 完整+L7 | WireGuard/IPsec | 是 | 高 | 高性能/安全 |
| **Flannel** | 中 | 无 | WireGuard | 否 | 低 | 简单场景 |
| **Weave** | 中 | 有限 | 内置 | 否 | 低 | 多集群 |
| **Antrea** | 高 | 完整 | IPsec | 否 | 中 | VMware 环境 |
| **AWS VPC CNI** | 最高 | 需 Calico | - | 否 | 中 | AWS EKS |
| **Azure CNI** | 高 | 需 Calico | - | 否 | 中 | AKS |

---

## 7. 网络策略实现

### 7.1 NetworkPolicy 工作原理

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                     NetworkPolicy Implementation                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  Kubernetes NetworkPolicy Controller                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                                                                          │    │
│  │  1. Watch NetworkPolicy 资源                                             │    │
│  │  2. Watch Pod/Namespace 资源                                             │    │
│  │  3. 计算受影响的 Pod                                                     │    │
│  │  4. 生成规则                                                             │    │
│  │                                                                          │    │
│  └───────────────────────────────────┬─────────────────────────────────────┘    │
│                                      │                                           │
│                                      ▼                                           │
│  ┌─────────────────────────┬─────────────────────────┬─────────────────────┐    │
│  │       Calico Felix      │    Cilium Agent         │     Antrea Agent    │    │
│  ├─────────────────────────┼─────────────────────────┼─────────────────────┤    │
│  │                         │                         │                     │    │
│  │  ┌───────────────────┐  │  ┌───────────────────┐  │  ┌───────────────┐  │    │
│  │  │    iptables       │  │  │    eBPF Maps      │  │  │   OVS Flows   │  │    │
│  │  │                   │  │  │                   │  │  │               │  │    │
│  │  │ -A FORWARD -m set │  │  │ Policy Map:       │  │  │ table=90,     │  │    │
│  │  │   --match-set     │  │  │   Identity ->     │  │  │ priority=200  │  │    │
│  │  │   cali40s:xxx src │  │  │     Rules         │  │  │ nw_src=10.x   │  │    │
│  │  │   -j ACCEPT       │  │  │                   │  │  │ actions=allow │  │    │
│  │  └───────────────────┘  │  └───────────────────┘  │  └───────────────┘  │    │
│  │                         │                         │                     │    │
│  │  ┌───────────────────┐  │  ┌───────────────────┐  │                     │    │
│  │  │  eBPF (可选)      │  │  │  XDP/TC Programs  │  │                     │    │
│  │  └───────────────────┘  │  └───────────────────┘  │                     │    │
│  │                         │                         │                     │    │
│  └─────────────────────────┴─────────────────────────┴─────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 NetworkPolicy 最佳实践

```yaml
# 默认拒绝所有入站流量
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress

---
# 默认拒绝所有出站流量
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress

---
# 允许 DNS 查询
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53

---
# 允许同命名空间内通信
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}

---
# 允许 Prometheus 抓取
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
      podSelector:
        matchLabels:
          app: prometheus
    ports:
    - protocol: TCP
      port: 9090
    - protocol: TCP
      port: 9091
```

---

## 8. CNI 配置与调优

### 8.1 MTU 配置

| 网络模式 | MTU 计算 | 推荐值 |
|----------|----------|--------|
| 无封装 | 物理网络 MTU | 1500 |
| VXLAN | 物理 MTU - 50 | 1450 |
| Geneve | 物理 MTU - 50 | 1450 |
| IPIP | 物理 MTU - 20 | 1480 |
| WireGuard | 物理 MTU - 60 | 1440 |

```yaml
# Calico MTU 配置
apiVersion: crd.projectcalico.org/v1
kind: FelixConfiguration
metadata:
  name: default
spec:
  mtu: 1440  # VXLAN + WireGuard
  wireguardMTU: 1400

# Cilium MTU 配置
# helm values
tunnel: vxlan
mtu: 1450
```

### 8.2 IPAM 配置

```yaml
# Calico IPAM
apiVersion: crd.projectcalico.org/v1
kind: IPPool
metadata:
  name: default-pool
spec:
  cidr: 10.244.0.0/16
  blockSize: 26  # 每节点 64 个 IP
  nodeSelector: all()

# Cilium IPAM
# cluster-pool 模式
ipam:
  mode: cluster-pool
  operator:
    clusterPoolIPv4PodCIDRList:
    - 10.0.0.0/8
    clusterPoolIPv4MaskSize: 24

# Kubernetes IPAM
ipam:
  mode: kubernetes
```

### 8.3 性能调优

```yaml
# Calico 性能调优
apiVersion: crd.projectcalico.org/v1
kind: FelixConfiguration
metadata:
  name: default
spec:
  # 数据存储
  datastoreType: kubernetes
  
  # 日志
  logSeverityScreen: Info
  logFilePath: none
  
  # iptables
  iptablesRefreshInterval: 90s
  iptablesPostWriteCheckIntervalSecs: 1
  iptablesLockFilePath: /run/xtables.lock
  iptablesLockTimeoutSecs: 0
  iptablesLockProbeIntervalMillis: 50
  
  # 路由
  routeRefreshInterval: 90s
  removeExternalRoutes: true
  
  # 健康检查
  healthEnabled: true
  healthHost: localhost
  healthPort: 9099
  
  # 流量控制
  flowLogsFlushInterval: 300s
  flowLogsFileAggregationKindForAllowed: 1
  
  # eBPF 模式
  bpfEnabled: true
  bpfLogLevel: Info
  bpfConnectTimeLoadBalancingEnabled: true
  bpfMapSizeConntrack: 512000
  bpfMapSizeNATFrontend: 65536
  bpfMapSizeNATBackend: 262144
  bpfMapSizeNATAffinity: 65536

---
# Cilium 性能调优
# helm values
bpf:
  mapDynamicSizeRatio: 0.0025
  ctGlobalTcpMax: 524288
  ctGlobalAnyMax: 262144
  natMax: 524288
  policyMapMax: 16384

enableBandwidthManager: true
enableBBR: true
enableRecorder: false

loadBalancer:
  algorithm: maglev
  mode: dsr  # 直接服务器返回

hubble:
  enabled: true
  metrics:
    enabled:
    - dns
    - drop
    - tcp
    - flow
    - icmp
    - http
```

---

## 9. 监控与故障排查

### 9.1 CNI 监控指标

| 指标 | 描述 | 来源 |
|------|------|------|
| **cilium_endpoint_count** | 端点数量 | Cilium |
| **cilium_policy_verdict** | 策略决策 | Cilium |
| **cilium_forward_count_total** | 转发数据包 | Cilium |
| **cilium_drop_count_total** | 丢弃数据包 | Cilium |
| **felix_cluster_num_hosts** | 集群节点数 | Calico |
| **felix_iptables_save_errors** | iptables 错误 | Calico |
| **felix_int_dataplane_failures** | 数据平面失败 | Calico |

### 9.2 故障排查命令

```bash
# Calico 排查
# 检查 Calico 状态
kubectl get pods -n calico-system
calicoctl node status
calicoctl get nodes
calicoctl get ippool -o wide
calicoctl get bgpconfig
calicoctl get bgppeer

# 检查端点
calicoctl get workloadendpoint -A
calicoctl get hostendpoint

# 检查策略
calicoctl get networkpolicy -A
calicoctl get globalnetworkpolicy

# 检查 Felix
kubectl logs -n calico-system -l k8s-app=calico-node -c calico-node

# Cilium 排查
# 检查 Cilium 状态
cilium status
cilium endpoint list
cilium service list
cilium bpf lb list
cilium bpf ct list global

# 检查策略
cilium policy get
cilium endpoint get <endpoint-id>

# Hubble 流量观察
hubble observe
hubble observe --pod nginx
hubble observe --verdict DROPPED
hubble observe --protocol http

# 连通性测试
cilium connectivity test

# 通用排查
# 检查 Pod 网络
kubectl exec -it <pod> -- ip addr
kubectl exec -it <pod> -- ip route
kubectl exec -it <pod> -- cat /etc/resolv.conf

# 检查节点网络
ip addr
ip route
iptables -L -n -v
iptables -t nat -L -n -v

# 检查 CNI 配置
ls /etc/cni/net.d/
cat /etc/cni/net.d/10-*.conflist

# 检查 CNI 插件
ls /opt/cni/bin/

# 网络连通性测试
kubectl run test --rm -it --image=nicolaka/netshoot -- /bin/bash
# 在容器内
ping <target-ip>
traceroute <target-ip>
curl -v http://<service>:<port>
```

### 9.3 常见问题

| 问题 | 可能原因 | 排查 | 解决 |
|------|----------|------|------|
| Pod 无法通信 | NetworkPolicy 阻止 | 检查策略 | 调整策略规则 |
| DNS 解析失败 | CoreDNS 问题 | 检查 CoreDNS Pod | 重启 CoreDNS |
| 跨节点通信失败 | 隧道/路由问题 | 检查隧道接口 | 检查 MTU、防火墙 |
| Service 不可达 | kube-proxy/eBPF 问题 | 检查 iptables/BPF | 重启相关组件 |
| IP 分配失败 | IPAM 耗尽 | 检查 IP Pool | 扩展 IP 范围 |
| 策略不生效 | 标签不匹配 | 检查 Pod 标签 | 修正标签 |

---

## 10. 生产实践案例

### 10.1 案例一: 多可用区高可用网络

```yaml
# 场景: 跨可用区集群网络配置

# Calico BGP 配置 - 每个可用区一个 AS
apiVersion: crd.projectcalico.org/v1
kind: BGPConfiguration
metadata:
  name: default
spec:
  nodeToNodeMeshEnabled: false  # 禁用 full-mesh
  asNumber: 64512
  serviceClusterIPs:
  - cidr: 10.96.0.0/12

---
# Zone A BGP Peer
apiVersion: crd.projectcalico.org/v1
kind: BGPPeer
metadata:
  name: zone-a-tor
spec:
  peerIP: 192.168.1.1
  asNumber: 64513
  nodeSelector: topology.kubernetes.io/zone == "zone-a"

---
# Zone B BGP Peer
apiVersion: crd.projectcalico.org/v1
kind: BGPPeer
metadata:
  name: zone-b-tor
spec:
  peerIP: 192.168.2.1
  asNumber: 64514
  nodeSelector: topology.kubernetes.io/zone == "zone-b"

---
# 每个可用区独立 IP Pool
apiVersion: crd.projectcalico.org/v1
kind: IPPool
metadata:
  name: zone-a-pool
spec:
  cidr: 10.244.0.0/18
  nodeSelector: topology.kubernetes.io/zone == "zone-a"
  ipipMode: CrossSubnet
  vxlanMode: Never
  natOutgoing: true

---
apiVersion: crd.projectcalico.org/v1
kind: IPPool
metadata:
  name: zone-b-pool
spec:
  cidr: 10.244.64.0/18
  nodeSelector: topology.kubernetes.io/zone == "zone-b"
  ipipMode: CrossSubnet
  vxlanMode: Never
  natOutgoing: true
```

### 10.2 案例二: 零信任网络架构

```yaml
# 场景: 实现零信任网络，所有流量默认拒绝

# 1. 全局默认拒绝
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: default-deny-all
spec:
  endpointSelector: {}
  ingressDeny:
  - {}
  egressDeny:
  - {}

---
# 2. 允许必要的系统流量
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: allow-kube-system
spec:
  endpointSelector:
    matchLabels:
      io.kubernetes.pod.namespace: kube-system
  ingress:
  - {}
  egress:
  - {}

---
# 3. 允许 DNS
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: allow-dns
spec:
  endpointSelector: {}
  egress:
  - toEndpoints:
    - matchLabels:
        io.kubernetes.pod.namespace: kube-system
        k8s-app: kube-dns
    toPorts:
    - ports:
      - port: "53"
        protocol: UDP
      - port: "53"
        protocol: TCP

---
# 4. 允许健康检查
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: allow-health-check
spec:
  endpointSelector: {}
  ingress:
  - fromEntities:
    - health

---
# 5. 应用级策略 (显式允许)
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: frontend-policy
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: frontend
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: ingress-nginx
    toPorts:
    - ports:
      - port: "80"
  egress:
  - toEndpoints:
    - matchLabels:
        app: backend
    toPorts:
    - ports:
      - port: "8080"
      rules:
        http:
        - method: GET
        - method: POST
```

### 10.3 案例三: 多集群网络互联

```yaml
# 场景: 两个 Kubernetes 集群网络互联

# Cilium ClusterMesh 配置
# Cluster 1
helm install cilium cilium/cilium --namespace kube-system \
  --set cluster.name=cluster1 \
  --set cluster.id=1 \
  --set clustermesh.useAPIServer=true \
  --set clustermesh.apiserver.replicas=2 \
  --set clustermesh.apiserver.service.type=LoadBalancer

# Cluster 2
helm install cilium cilium/cilium --namespace kube-system \
  --set cluster.name=cluster2 \
  --set cluster.id=2 \
  --set clustermesh.useAPIServer=true \
  --set clustermesh.apiserver.replicas=2 \
  --set clustermesh.apiserver.service.type=LoadBalancer

# 连接集群
cilium clustermesh connect --destination-context cluster2

---
# 全局 Service (跨集群负载均衡)
apiVersion: v1
kind: Service
metadata:
  name: global-api
  annotations:
    io.cilium/global-service: "true"
spec:
  selector:
    app: api
  ports:
  - port: 8080
    targetPort: 8080

---
# 跨集群 NetworkPolicy
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-cross-cluster
  namespace: production
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
  - fromEndpoints:
    - matchLabels:
        io.cilium.k8s.policy.cluster: cluster1
        app: frontend
    - matchLabels:
        io.cilium.k8s.policy.cluster: cluster2
        app: frontend
```

### 10.4 CNI 选型建议

| 场景 | 推荐 CNI | 理由 |
|------|----------|------|
| **AWS EKS** | VPC CNI + Calico | 原生 VPC 集成，Calico 提供 NetworkPolicy |
| **Azure AKS** | Azure CNI + Calico | 原生集成，Calico 策略 |
| **GKE** | GKE CNI + Calico | 原生集成 |
| **私有云/IDC** | Calico BGP | 与现有网络设施集成 |
| **高性能/安全** | Cilium | eBPF 性能，L7 策略 |
| **简单场景** | Flannel | 易于部署和维护 |
| **多集群** | Cilium ClusterMesh | 原生多集群支持 |
| **服务网格** | Cilium | 原生 Service Mesh 能力 |

---

## 附录

### A. CNI 规范版本

| CNI 版本 | 发布时间 | 主要变更 |
|----------|----------|----------|
| 0.1.0 | 2015 | 初始版本 |
| 0.3.0 | 2016 | 多网卡支持 |
| 0.4.0 | 2018 | CHECK 操作 |
| 1.0.0 | 2021 | 稳定版本 |
| 1.1.0 | 2023 | GC 支持 |

### B. 参考资源

| 资源 | 链接 |
|------|------|
| CNI 规范 | https://github.com/containernetworking/cni |
| Calico 文档 | https://docs.tigera.io/calico/ |
| Cilium 文档 | https://docs.cilium.io/ |
| Flannel 文档 | https://github.com/flannel-io/flannel |
| Kubernetes 网络 | https://kubernetes.io/docs/concepts/cluster-administration/networking/ |

---

*本文档持续更新，建议结合官方文档和实际环境进行验证。*
