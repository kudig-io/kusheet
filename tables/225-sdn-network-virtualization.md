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

---

## 相关文档

- [220-network-protocols-stack](./220-network-protocols-stack.md) - 网络协议栈
- [203-docker-networking-deep-dive](./203-docker-networking-deep-dive.md) - Docker 网络
- [45-cni-network-plugins](./45-cni-network-plugins.md) - CNI 插件
