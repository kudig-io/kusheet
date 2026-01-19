# kube-proxy 深度解析 (kube-proxy Deep Dive)

> kube-proxy 是 Kubernetes 的网络代理组件，运行在每个节点上，负责实现 Service 的负载均衡和网络转发

---

## 1. 架构概述 (Architecture Overview)

### 1.1 核心职责

| 职责 | 英文名 | 说明 |
|:---|:---|:---|
| **Service代理** | Service Proxy | 为Service提供虚拟IP和负载均衡 |
| **流量转发** | Traffic Forwarding | 将访问Service的流量转发到后端Pod |
| **端点发现** | Endpoint Discovery | 监听Endpoints/EndpointSlice变化 |
| **规则同步** | Rule Synchronization | 维护iptables/IPVS规则 |
| **会话亲和性** | Session Affinity | 支持ClientIP会话保持 |
| **健康检查** | Health Check | 负载均衡健康检查(IPVS模式) |

### 1.2 整体架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              kube-proxy                                  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                      Informer / Watch                              │ │
│  │  ┌─────────────┐  ┌─────────────────┐  ┌─────────────────────┐   │ │
│  │  │   Service   │  │    Endpoints    │  │   EndpointSlice     │   │ │
│  │  │   Informer  │  │    Informer     │  │   Informer          │   │ │
│  │  └──────┬──────┘  └────────┬────────┘  └──────────┬──────────┘   │ │
│  └─────────┼──────────────────┼─────────────────────┼────────────────┘ │
│            │                  │                     │                   │
│            ▼                  ▼                     ▼                   │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                    Service Map / Endpoint Map                      │ │
│  │            (Service信息 + Endpoint/EndpointSlice信息)               │ │
│  └──────────────────────────────┬────────────────────────────────────┘ │
│                                 │                                       │
│                                 ▼                                       │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                        Proxy Provider                              │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                │ │
│  │  │  iptables   │  │    IPVS     │  │  nftables   │                │ │
│  │  │  Proxier    │  │   Proxier   │  │  Proxier    │                │ │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                │ │
│  └─────────┼────────────────┼───────────────┼────────────────────────┘ │
│            │                │               │                           │
└────────────┼────────────────┼───────────────┼───────────────────────────┘
             │                │               │
             ▼                ▼               ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Linux Kernel                                     │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐            │
│  │   iptables/    │  │     IPVS       │  │    nftables    │            │
│  │   netfilter    │  │   (LVS)        │  │                │            │
│  └────────────────┘  └────────────────┘  └────────────────┘            │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.3 代理模式对比

| 特性 | iptables | IPVS | nftables |
|:---|:---|:---|:---|
| **性能** | O(n) 规则匹配 | O(1) 哈希查找 | O(n) 但更高效 |
| **连接数** | 适合小规模 | 适合大规模 | 适合中大规模 |
| **负载均衡算法** | 随机 | 多种算法 | 随机 |
| **会话亲和** | ClientIP | ClientIP + 更多 | ClientIP |
| **规则更新** | 全量更新 | 增量更新 | 增量更新 |
| **调试难度** | 中等 | 简单(ipvsadm) | 中等 |
| **内核要求** | 无特殊要求 | 需要IPVS模块 | 需要nftables |
| **推荐场景** | 小集群(<1000 Services) | 大集群 | 新部署 |
| **K8s支持** | 默认 | 稳定 | Beta (1.29+) |

---

## 2. iptables 模式详解

### 2.1 iptables 链结构

```
                     ┌─────────────────────────────────┐
                     │          Incoming Packet         │
                     └───────────────┬─────────────────┘
                                     │
                                     ▼
┌───────────────────────────────────────────────────────────────────────┐
│                          PREROUTING Chain                              │
│  ┌──────────────────────────────────────────────────────────────────┐│
│  │  KUBE-SERVICES (jump to Service chains)                          ││
│  └──────────────────────────────────────────────────────────────────┘│
└───────────────────────────────────────────────────────────────────────┘
                                     │
                    ┌────────────────┴────────────────┐
                    │ Destination                      │
                    │ is local?                        │
                    └────────────────┬────────────────┘
                    Yes              │              No
                    │                │               │
                    ▼                │               ▼
┌─────────────────────────┐         │    ┌─────────────────────────┐
│      INPUT Chain        │         │    │     FORWARD Chain       │
│  ┌────────────────────┐ │         │    │                         │
│  │   KUBE-FIREWALL    │ │         │    │                         │
│  │   KUBE-NODE-PORT   │ │         │    │                         │
│  └────────────────────┘ │         │    └─────────────────────────┘
└─────────────────────────┘         │
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────┐
│                          OUTPUT Chain                                  │
│  ┌──────────────────────────────────────────────────────────────────┐│
│  │  KUBE-SERVICES (for locally generated traffic)                    ││
│  └──────────────────────────────────────────────────────────────────┘│
└───────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌───────────────────────────────────────────────────────────────────────┐
│                         POSTROUTING Chain                              │
│  ┌──────────────────────────────────────────────────────────────────┐│
│  │  KUBE-POSTROUTING (MASQUERADE/SNAT)                              ││
│  └──────────────────────────────────────────────────────────────────┘│
└───────────────────────────────────────────────────────────────────────┘
```

### 2.2 iptables 规则示例

```bash
# 查看kube-proxy创建的iptables规则

# NAT表 - KUBE-SERVICES链 (入口)
iptables -t nat -L KUBE-SERVICES -n --line-numbers
# Chain KUBE-SERVICES (2 references)
# 1  KUBE-SVC-XXX  tcp  --  0.0.0.0/0  10.96.0.1   tcp dpt:443  /* default/kubernetes:https */
# 2  KUBE-SVC-YYY  tcp  --  0.0.0.0/0  10.96.0.10  tcp dpt:53   /* kube-system/kube-dns:dns-tcp */
# 3  KUBE-NODEPORTS  all  --  0.0.0.0/0  0.0.0.0/0  ADDRTYPE match dst-type LOCAL

# Service链 - 负载均衡到Endpoint
iptables -t nat -L KUBE-SVC-XXX -n
# Chain KUBE-SVC-XXX (1 references)
# 1  KUBE-MARK-MASQ   all  --  !10.244.0.0/16  10.96.0.1   /* default/kubernetes:https */
# 2  KUBE-SEP-AAA     all  --  0.0.0.0/0      0.0.0.0/0   /* default/kubernetes:https */ statistic mode random probability 0.33333
# 3  KUBE-SEP-BBB     all  --  0.0.0.0/0      0.0.0.0/0   /* default/kubernetes:https */ statistic mode random probability 0.50000
# 4  KUBE-SEP-CCC     all  --  0.0.0.0/0      0.0.0.0/0   /* default/kubernetes:https */

# Endpoint链 - DNAT到具体Pod
iptables -t nat -L KUBE-SEP-AAA -n
# Chain KUBE-SEP-AAA (1 references)
# 1  KUBE-MARK-MASQ  all  --  10.0.0.1/32    0.0.0.0/0   /* default/kubernetes:https */
# 2  DNAT           tcp  --  0.0.0.0/0      0.0.0.0/0   /* default/kubernetes:https */ tcp to:10.0.0.1:6443

# MASQUERADE链 - 源地址转换
iptables -t nat -L KUBE-POSTROUTING -n
# Chain KUBE-POSTROUTING (1 references)
# 1  RETURN      all  --  0.0.0.0/0  0.0.0.0/0  mark match ! 0x4000/0x4000
# 2  MARK        all  --  0.0.0.0/0  0.0.0.0/0  MARK xor 0x4000
# 3  MASQUERADE  all  --  0.0.0.0/0  0.0.0.0/0  /* kubernetes service traffic requiring SNAT */ random-fully
```

### 2.3 iptables 规则计算

```
一个Service的iptables规则数量:
- 每个Service: ~4条规则
- 每个Endpoint: ~3条规则
- NodePort: 额外~2条规则

示例: 1000 Services, 每个3个Endpoints
总规则数 ≈ 1000 × 4 + 1000 × 3 × 3 = 13000 条

规则更新时间 (全量): O(n), 与规则数成正比
大量规则时可能需要秒级时间完成更新
```

---

## 3. IPVS 模式详解

### 3.1 IPVS 架构

```
┌────────────────────────────────────────────────────────────────────────┐
│                            IPVS Mode                                    │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                       Virtual Server                            │   │
│  │                    (Service ClusterIP:Port)                     │   │
│  │                                                                  │   │
│  │     VIP: 10.96.0.1:443 -> kubernetes.default.svc                │   │
│  │     VIP: 10.96.0.10:53 -> kube-dns.kube-system.svc              │   │
│  └────────────────────────────────────────────────────────────────┘   │
│                              │                                          │
│                              │ 负载均衡算法                             │
│                              ▼                                          │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                       Real Server                               │   │
│  │                    (Pod Endpoint IP:Port)                       │   │
│  │                                                                  │   │
│  │     RS1: 10.244.0.1:6443 (weight=1)                            │   │
│  │     RS2: 10.244.0.2:6443 (weight=1)                            │   │
│  │     RS3: 10.244.0.3:6443 (weight=1)                            │   │
│  └────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  转发模式: NAT (Masquerading)                                           │
│                                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

### 3.2 IPVS 负载均衡算法

| 算法 | 英文名 | 说明 | 适用场景 |
|:---|:---|:---|:---|
| **rr** | Round Robin | 轮询 | 后端性能相同 |
| **wrr** | Weighted Round Robin | 加权轮询 | 后端性能不同 |
| **lc** | Least Connection | 最少连接 | 长连接服务 |
| **wlc** | Weighted Least Connection | 加权最少连接 | 长连接+性能差异 |
| **sh** | Source Hashing | 源地址哈希 | 会话保持需求 |
| **dh** | Destination Hashing | 目标地址哈希 | 缓存服务器 |
| **sed** | Shortest Expected Delay | 最短预期延迟 | 低延迟需求 |
| **nq** | Never Queue | 不排队 | 交互式服务 |

```bash
# 默认算法
--ipvs-scheduler=rr

# 配置示例
kube-proxy --proxy-mode=ipvs --ipvs-scheduler=lc
```

### 3.3 IPVS 命令操作

```bash
# 查看所有虚拟服务
ipvsadm -Ln

# 输出示例:
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.96.0.1:443 rr
  -> 10.0.0.1:6443                Masq    1      10         50
  -> 10.0.0.2:6443                Masq    1      8          45
  -> 10.0.0.3:6443                Masq    1      12         55
TCP  10.96.0.10:53 rr
  -> 10.244.0.10:53               Masq    1      0          100
  -> 10.244.0.11:53               Masq    1      0          95

# 查看连接统计
ipvsadm -Ln --stats

# 查看连接速率
ipvsadm -Ln --rate

# 查看连接表
ipvsadm -Lnc

# 清除统计
ipvsadm -Z
```

### 3.4 IPVS 需要的 iptables 规则

```bash
# IPVS模式仍需要少量iptables规则用于MASQUERADE
# 规则数量远少于纯iptables模式

# NAT表规则
iptables -t nat -L KUBE-POSTROUTING -n
# 1  MASQUERADE  all  --  0.0.0.0/0  0.0.0.0/0  /* kubernetes service traffic ... */ mark match 0x4000/0x4000

# KUBE-MARK-MASQ 用于标记需要MASQUERADE的流量
iptables -t nat -L KUBE-MARK-MASQ -n
# 1  MARK  all  --  0.0.0.0/0  0.0.0.0/0  MARK or 0x4000
```

### 3.5 IPVS 模式配置

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
    mode: "ipvs"
    ipvs:
      scheduler: "rr"           # 调度算法
      syncPeriod: "30s"         # 同步周期
      minSyncPeriod: "2s"       # 最小同步周期
      strictARP: true           # 严格ARP (推荐)
      tcpTimeout: "900s"        # TCP超时
      tcpFinTimeout: "120s"     # TCP FIN超时
      udpTimeout: "300s"        # UDP超时
      excludeCIDRs: []          # 排除的CIDR
```

---

## 4. nftables 模式 (Beta)

### 4.1 nftables 特性

| 特性 | 说明 |
|:---|:---|
| **现代化设计** | 替代iptables的新一代框架 |
| **更好的性能** | 批量规则更新 |
| **原子操作** | 规则更新原子性 |
| **统一语法** | IPv4/IPv6统一处理 |
| **K8s支持** | 1.29+作为Beta功能 |

### 4.2 启用 nftables 模式

```bash
# 启用特性门控
kube-proxy --feature-gates=NFTablesProxyMode=true --proxy-mode=nftables
```

```yaml
# ConfigMap配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-proxy
  namespace: kube-system
data:
  config.conf: |
    apiVersion: kubeproxy.config.k8s.io/v1alpha1
    kind: KubeProxyConfiguration
    mode: "nftables"
    featureGates:
      NFTablesProxyMode: true
```

---

## 5. 关键配置参数 (Configuration Parameters)

### 5.1 通用参数

| 参数 | 默认值 | 说明 |
|:---|:---|:---|
| `--proxy-mode` | iptables | 代理模式(iptables/ipvs/nftables) |
| `--kubeconfig` | - | API Server连接配置 |
| `--config` | - | 配置文件路径 |
| `--cluster-cidr` | - | 集群Pod CIDR |
| `--hostname-override` | - | 节点主机名覆盖 |
| `--bind-address` | 0.0.0.0 | 监听地址 |
| `--healthz-bind-address` | 0.0.0.0:10256 | 健康检查地址 |
| `--metrics-bind-address` | 127.0.0.1:10249 | 指标地址 |

### 5.2 iptables 模式参数

| 参数 | 默认值 | 说明 |
|:---|:---|:---|
| `--iptables-sync-period` | 30s | 规则同步周期 |
| `--iptables-min-sync-period` | 1s | 最小同步周期 |
| `--iptables-masquerade-bit` | 14 | MASQUERADE标记位 |
| `--iptables-localhost-nodeports` | true | 本地NodePort |

### 5.3 IPVS 模式参数

| 参数 | 默认值 | 说明 |
|:---|:---|:---|
| `--ipvs-scheduler` | rr | 调度算法 |
| `--ipvs-sync-period` | 30s | 同步周期 |
| `--ipvs-min-sync-period` | 2s | 最小同步周期 |
| `--ipvs-strict-arp` | false | 严格ARP模式 |
| `--ipvs-tcp-timeout` | 0 | TCP超时(0=系统默认) |
| `--ipvs-tcpfin-timeout` | 0 | TCP FIN超时 |
| `--ipvs-udp-timeout` | 0 | UDP超时 |
| `--ipvs-exclude-cidrs` | - | 排除的CIDR列表 |

### 5.4 NodePort 参数

| 参数 | 默认值 | 说明 |
|:---|:---|:---|
| `--nodeport-addresses` | - | NodePort监听地址(CIDR) |

### 5.5 完整配置文件示例

```yaml
# /var/lib/kube-proxy/config.conf
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration

# 客户端配置
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig.conf"
  acceptContentTypes: ""
  burst: 10
  contentType: "application/vnd.kubernetes.protobuf"
  qps: 5

# 代理模式
mode: "ipvs"                    # iptables/ipvs/nftables

# 集群配置
clusterCIDR: "10.244.0.0/16"
hostnameOverride: ""

# 健康检查
healthzBindAddress: "0.0.0.0:10256"
metricsBindAddress: "127.0.0.1:10249"

# iptables配置
iptables:
  masqueradeAll: false
  masqueradeBit: 14
  minSyncPeriod: "1s"
  syncPeriod: "30s"
  localhostNodePorts: true

# IPVS配置
ipvs:
  scheduler: "rr"
  syncPeriod: "30s"
  minSyncPeriod: "2s"
  strictARP: true
  tcpTimeout: "0s"
  tcpFinTimeout: "0s"
  udpTimeout: "0s"
  excludeCIDRs: []

# NodePort配置
nodePortAddresses: []           # 空=所有地址

# conntrack配置
conntrack:
  maxPerCore: 32768
  min: 131072
  tcpCloseWaitTimeout: "1h0m0s"
  tcpEstablishedTimeout: "24h0m0s"

# 检测配置
detectLocalMode: ""             # ClusterCIDR/NodeCIDR/BridgeInterface
detectLocal:
  bridgeInterface: ""
  interfaceNamePrefix: ""

# 特性门控
featureGates:
  NFTablesProxyMode: false

# 日志配置
logging:
  format: "text"
  sanitization: false
  verbosity: 0
```

---

## 6. Service 类型详解

### 6.1 Service 类型对比

| 类型 | 说明 | 访问方式 | kube-proxy处理 |
|:---|:---|:---|:---|
| **ClusterIP** | 集群内部虚拟IP | 集群内部Pod | 转发到Endpoints |
| **NodePort** | 节点端口暴露 | NodeIP:NodePort | ClusterIP + 节点端口转发 |
| **LoadBalancer** | 外部负载均衡 | 外部LB IP | NodePort + 云LB集成 |
| **ExternalName** | DNS CNAME | DNS解析 | 不处理(DNS级别) |
| **Headless** | 无ClusterIP | DNS直接返回Pod IP | 不处理(无VIP) |

### 6.2 流量转发路径

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ClusterIP Service                                 │
│                                                                         │
│  Client Pod ──▶ ClusterIP:Port ──▶ kube-proxy ──▶ Pod Endpoint         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                         NodePort Service                                 │
│                                                                         │
│  External ──▶ NodeIP:NodePort ──▶ kube-proxy ──▶ Pod Endpoint          │
│                                                                         │
│  或                                                                      │
│                                                                         │
│  Internal ──▶ ClusterIP:Port ──▶ kube-proxy ──▶ Pod Endpoint           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                       LoadBalancer Service                               │
│                                                                         │
│  External ──▶ LB IP:Port ──▶ NodeIP:NodePort ──▶ kube-proxy ──▶ Pod    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 6.3 externalTrafficPolicy

| 策略 | 说明 | 优点 | 缺点 |
|:---|:---|:---|:---|
| **Cluster** (默认) | 转发到任意节点的Pod | 负载均衡好 | 额外跳转、SNAT |
| **Local** | 只转发到本节点Pod | 保留源IP、低延迟 | 负载不均、需本地Pod |

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: NodePort
  externalTrafficPolicy: Local  # 保留客户端源IP
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080
```

### 6.4 internalTrafficPolicy (K8s 1.21+)

| 策略 | 说明 | 适用场景 |
|:---|:---|:---|
| **Cluster** (默认) | 转发到任意Pod | 标准负载均衡 |
| **Local** | 优先转发到本节点Pod | 减少跨节点流量 |

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  internalTrafficPolicy: Local  # 优先本地Pod
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
```

---

## 7. 监控指标 (Monitoring Metrics)

### 7.1 关键指标表

| 指标名称 | 类型 | 说明 | 告警阈值 |
|:---|:---|:---|:---|
| `kubeproxy_sync_proxy_rules_duration_seconds` | Histogram | 规则同步耗时 | p99 > 5s |
| `kubeproxy_sync_proxy_rules_last_timestamp_seconds` | Gauge | 上次同步时间戳 | - |
| `kubeproxy_sync_proxy_rules_no_local_endpoints_total` | Counter | 无本地Endpoint的同步 | - |
| `kubeproxy_network_programming_duration_seconds` | Histogram | 网络编程延迟 | p99 > 10s |
| `kubeproxy_sync_proxy_rules_iptables_total` | Counter | iptables规则数 | - |
| `kubeproxy_sync_proxy_rules_endpoint_changes_total` | Counter | Endpoint变化数 | - |
| `kubeproxy_sync_proxy_rules_service_changes_total` | Counter | Service变化数 | - |
| `rest_client_requests_total` | Counter | API请求数 | - |
| `rest_client_request_duration_seconds` | Histogram | API请求延迟 | p99 > 1s |
| `process_resident_memory_bytes` | Gauge | 内存使用 | > 256MB |

### 7.2 Prometheus 告警规则

```yaml
groups:
- name: kube-proxy
  rules:
  - alert: KubeProxyDown
    expr: absent(up{job="kube-proxy"} == 1)
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "kube-proxy is down on {{ $labels.instance }}"

  - alert: KubeProxySyncDurationHigh
    expr: histogram_quantile(0.99, rate(kubeproxy_sync_proxy_rules_duration_seconds_bucket[5m])) > 5
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "kube-proxy sync duration is high"
      description: "kube-proxy sync p99 duration is {{ $value }}s on {{ $labels.instance }}"

  - alert: KubeProxyNetworkProgrammingLatencyHigh
    expr: histogram_quantile(0.99, rate(kubeproxy_network_programming_duration_seconds_bucket[5m])) > 10
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "kube-proxy network programming latency is high"

  - alert: KubeProxySyncStale
    expr: time() - kubeproxy_sync_proxy_rules_last_timestamp_seconds > 300
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "kube-proxy sync is stale"
      description: "kube-proxy on {{ $labels.instance }} hasn't synced for {{ $value }}s"
```

---

## 8. 故障排查 (Troubleshooting)

### 8.1 常见问题诊断

| 症状 | 可能原因 | 诊断方法 | 解决方案 |
|:---|:---|:---|:---|
| **Service不可达** | kube-proxy未运行/规则问题 | 检查iptables/IPVS规则 | 重启kube-proxy |
| **NodePort不工作** | 端口被占用/防火墙 | netstat检查端口 | 释放端口/配置防火墙 |
| **负载不均衡** | 会话亲和/算法问题 | 检查Service配置 | 调整配置 |
| **连接超时** | conntrack满/规则错误 | 检查conntrack表 | 增加conntrack限制 |
| **IPVS虚拟服务缺失** | 同步问题 | ipvsadm -Ln | 检查日志 |
| **规则同步慢** | Service/Endpoint过多 | 检查同步指标 | 考虑IPVS模式 |
| **内存占用高** | 规则数量大 | 检查内存使用 | 升级IPVS |

### 8.2 诊断命令

```bash
# 检查 kube-proxy 状态
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy -f

# 检查 kube-proxy 配置
kubectl get configmap -n kube-system kube-proxy -o yaml

# 检查 iptables 规则
iptables -t nat -L -n -v | grep -E "KUBE-|Chain"
iptables -t nat -L KUBE-SERVICES -n --line-numbers
iptables -t nat -L KUBE-NODEPORTS -n --line-numbers

# 检查 IPVS 规则
ipvsadm -Ln
ipvsadm -Ln --stats
ipvsadm -Ln --rate

# 检查 conntrack
conntrack -L | wc -l
conntrack -S
cat /proc/sys/net/netfilter/nf_conntrack_count
cat /proc/sys/net/netfilter/nf_conntrack_max

# 检查 Service 和 Endpoints
kubectl get svc -A
kubectl get endpoints -A
kubectl get endpointslices -A

# 检查健康状态
curl http://localhost:10256/healthz
curl http://localhost:10249/metrics

# 检查网络连通性
kubectl run test --rm -it --image=busybox -- wget -qO- http://<service-cluster-ip>:<port>

# 在节点上测试
curl http://<cluster-ip>:<port>
curl http://<node-ip>:<node-port>
```

### 8.3 常见日志模式

```bash
# 正常日志
I0101 00:00:00.000000   1 service.go:379] Adding new service "default/kubernetes:https"
I0101 00:00:00.000000   1 proxier.go:797] Syncing iptables rules
I0101 00:00:00.000000   1 proxier.go:1023] syncProxyRules took 10.123ms

# 警告日志
W0101 00:00:00.000000   1 proxier.go:532] No endpoints found for service "default/my-service"
W0101 00:00:00.000000   1 bounded_frequency_runner.go:137] sync-runner: ran immediately (outstanding: true)

# 错误日志
E0101 00:00:00.000000   1 proxier.go:1234] Failed to execute iptables-restore: exit status 1
E0101 00:00:00.000000   1 reflector.go:138] Watch of *v1.Endpoints ended with: context canceled
```

---

## 9. 性能优化 (Performance Tuning)

### 9.1 大规模集群优化

| 优化项 | iptables模式 | IPVS模式 |
|:---|:---|:---|
| **同步周期** | 增加minSyncPeriod | 增加minSyncPeriod |
| **conntrack** | 增加max限制 | 增加max限制 |
| **模式选择** | 考虑切换IPVS | 已是最优 |
| **Endpoint规模** | 使用EndpointSlices | 使用EndpointSlices |

### 9.2 conntrack 优化

```bash
# 增加 conntrack 限制
cat >> /etc/sysctl.conf << EOF
# conntrack优化
net.netfilter.nf_conntrack_max = 1000000
net.netfilter.nf_conntrack_tcp_timeout_established = 86400
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 3600
EOF

sysctl -p
```

### 9.3 iptables 转 IPVS

```bash
# 1. 确保内核模块加载
modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh
modprobe nf_conntrack

# 2. 验证模块
lsmod | grep ip_vs

# 3. 更新 kube-proxy ConfigMap
kubectl edit configmap kube-proxy -n kube-system
# 修改 mode: "ipvs"

# 4. 重启 kube-proxy
kubectl rollout restart daemonset kube-proxy -n kube-system

# 5. 验证
ipvsadm -Ln
```

---

## 10. 生产环境 Checklist

### 10.1 部署检查

| 检查项 | 状态 | 说明 |
|:---|:---|:---|
| [ ] 选择合适的代理模式 | | 大集群使用IPVS |
| [ ] 配置conntrack限制 | | 防止连接表满 |
| [ ] 配置监控告警 | | 同步延迟、错误等 |
| [ ] 启用EndpointSlices | | 大规模Endpoint |
| [ ] 配置strictARP (IPVS) | | 避免ARP问题 |
| [ ] 配置nodePortAddresses | | 限制NodePort监听 |

### 10.2 模式选择建议

| 集群规模 | Service数量 | 推荐模式 | 说明 |
|:---|:---|:---|:---|
| 小型 | <100 | iptables | 简单可靠 |
| 中型 | 100-500 | IPVS | 更好的性能 |
| 大型 | 500-2000 | IPVS | 必须使用 |
| 超大型 | >2000 | IPVS | 考虑Service拆分 |

---

## 附录: 无 kube-proxy 模式 (eBPF替代)

### Cilium 替代 kube-proxy

```bash
# 使用Cilium替代kube-proxy
# 1. 禁用kube-proxy
kubectl -n kube-system delete daemonset kube-proxy

# 2. 安装Cilium (kube-proxy replacement)
helm install cilium cilium/cilium --version 1.14.0 \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=<API_SERVER_IP> \
  --set k8sServicePort=<API_SERVER_PORT>

# 3. 验证
cilium status
```

### 优势

| 特性 | kube-proxy | Cilium eBPF |
|:---|:---|:---|
| **性能** | 中等 | 极高 |
| **规则复杂度** | O(n) iptables | O(1) eBPF |
| **功能** | 基础 | 高级(L7策略等) |
| **可观测性** | 基础 | 深度(Hubble) |
