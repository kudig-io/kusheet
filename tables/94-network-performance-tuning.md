# 网络性能调优

> Kubernetes 版本: v1.25 - v1.32 | 适用环境: 生产集群

## 网络性能关键参数

| 层级 | 参数 | 默认值 | 推荐值 | 影响 |
|------|------|--------|--------|------|
| Node | net.core.somaxconn | 128 | 32768 | 监听队列长度 |
| Node | net.core.netdev_max_backlog | 1000 | 16384 | 网卡队列长度 |
| Node | net.ipv4.tcp_max_syn_backlog | 128 | 8192 | SYN 队列长度 |
| Node | net.ipv4.tcp_tw_reuse | 0 | 1 | TIME_WAIT 复用 |
| Node | net.ipv4.ip_local_port_range | 32768-60999 | 1024-65535 | 本地端口范围 |
| Node | net.netfilter.nf_conntrack_max | 65536 | 1048576 | 连接跟踪表大小 |
| Pod | net.core.somaxconn | 128 | 65535 | Pod 监听队列 |

## 节点网络优化配置

```yaml
# 节点 sysctl 配置 (通过 DaemonSet 应用)
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: network-tuning
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: network-tuning
  template:
    metadata:
      labels:
        app: network-tuning
    spec:
      hostNetwork: true
      hostPID: true
      nodeSelector:
        kubernetes.io/os: linux
      tolerations:
      - operator: Exists
      initContainers:
      - name: sysctl
        image: busybox:1.36
        securityContext:
          privileged: true
        command:
        - sh
        - -c
        - |
          sysctl -w net.core.somaxconn=32768
          sysctl -w net.core.netdev_max_backlog=16384
          sysctl -w net.ipv4.tcp_max_syn_backlog=8192
          sysctl -w net.ipv4.tcp_tw_reuse=1
          sysctl -w net.ipv4.ip_local_port_range="1024 65535"
          sysctl -w net.ipv4.tcp_fin_timeout=30
          sysctl -w net.ipv4.tcp_keepalive_time=600
          sysctl -w net.ipv4.tcp_keepalive_intvl=30
          sysctl -w net.ipv4.tcp_keepalive_probes=10
          sysctl -w net.netfilter.nf_conntrack_max=1048576
          sysctl -w net.netfilter.nf_conntrack_tcp_timeout_established=86400
          sysctl -w net.netfilter.nf_conntrack_tcp_timeout_close_wait=3600
          sysctl -w net.core.rmem_max=16777216
          sysctl -w net.core.wmem_max=16777216
          sysctl -w net.ipv4.tcp_rmem="4096 12582912 16777216"
          sysctl -w net.ipv4.tcp_wmem="4096 12582912 16777216"
      containers:
      - name: pause
        image: registry.k8s.io/pause:3.9
```

## Pod 级网络优化

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: high-performance-app
spec:
  securityContext:
    sysctls:
    # 安全 sysctl (默认允许)
    - name: net.ipv4.ping_group_range
      value: "0 2147483647"
    # 需要 PodSecurityPolicy 或 unsafe-sysctls 启用
    - name: net.core.somaxconn
      value: "65535"
    - name: net.ipv4.tcp_syncookies
      value: "1"
  containers:
  - name: app
    image: nginx:1.25
    resources:
      limits:
        cpu: 2
        memory: 4Gi
```

## kube-proxy 模式对比与优化

| 模式 | 性能 | 功能 | 适用场景 |
|------|------|------|----------|
| iptables | 中 | 完整 | 小中规模集群 |
| ipvs | 高 | 完整 | 大规模集群 |
| nftables | 高 | 完整 | v1.29+ 新集群 |
| eBPF (Cilium) | 最高 | 增强 | 高性能需求 |

### IPVS 模式配置

```yaml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
ipvs:
  scheduler: rr  # rr, lc, dh, sh, sed, nq
  syncPeriod: 30s
  minSyncPeriod: 2s
  tcpTimeout: 0s
  tcpFinTimeout: 0s
  udpTimeout: 0s
conntrack:
  maxPerCore: 32768
  min: 131072
  tcpEstablishedTimeout: 86400s
  tcpCloseWaitTimeout: 1h
```

### Cilium eBPF 配置

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: cilium
  namespace: kube-system
spec:
  values:
    kubeProxyReplacement: strict
    k8sServiceHost: <api-server-ip>
    k8sServicePort: 6443
    bpf:
      masquerade: true
      clockProbe: false
      preallocateMaps: true
      tproxy: true
    loadBalancer:
      algorithm: maglev
      mode: dsr  # Direct Server Return
    bandwidthManager:
      enabled: true
      bbr: true
    hubble:
      enabled: true
      relay:
        enabled: true
```

## Service 网络优化

```yaml
apiVersion: v1
kind: Service
metadata:
  name: high-performance-svc
  annotations:
    # 会话保持
    service.kubernetes.io/topology-mode: Auto
spec:
  type: ClusterIP
  # 本地流量策略 - 减少跨节点流量
  internalTrafficPolicy: Local
  # 外部流量策略
  externalTrafficPolicy: Local
  # 会话亲和性
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: high-performance
```

## Ingress/Gateway 性能优化

```yaml
# Nginx Ingress 高性能配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  # Worker 配置
  worker-processes: "auto"
  worker-connections: "65535"
  # Keepalive
  keep-alive: "75"
  keep-alive-requests: "10000"
  upstream-keepalive-connections: "320"
  upstream-keepalive-requests: "10000"
  upstream-keepalive-timeout: "60"
  # 代理缓冲
  proxy-buffer-size: "16k"
  proxy-buffers-number: "4"
  proxy-body-size: "100m"
  # 超时
  proxy-connect-timeout: "10"
  proxy-read-timeout: "60"
  proxy-send-timeout: "60"
  # SSL 优化
  ssl-protocols: "TLSv1.2 TLSv1.3"
  ssl-session-cache: "true"
  ssl-session-cache-size: "10m"
  ssl-session-timeout: "10m"
  # 日志
  enable-access-log-for-default-backend: "false"
  # 其他
  enable-brotli: "true"
  use-gzip: "true"
```

## 连接跟踪表诊断

```bash
# 查看 conntrack 表大小和使用情况
cat /proc/sys/net/netfilter/nf_conntrack_max
cat /proc/sys/net/netfilter/nf_conntrack_count

# 查看 conntrack 表状态分布
conntrack -S
conntrack -L -o extended | awk '{print $3}' | sort | uniq -c | sort -rn

# 清理 conntrack 表
conntrack -F

# 查看 TIME_WAIT 连接数
ss -tan state time-wait | wc -l

# 查看网络统计
netstat -s | grep -i "listen"
ss -s
```

## 网络性能测试

```bash
# Pod 间带宽测试 (iperf3)
kubectl run iperf-server --image=networkstatic/iperf3 -- iperf3 -s
kubectl run iperf-client --image=networkstatic/iperf3 -- iperf3 -c iperf-server -t 30

# 延迟测试
kubectl exec -it test-pod -- ping -c 100 <service-ip>

# DNS 解析性能
kubectl exec -it test-pod -- sh -c 'for i in $(seq 1 100); do nslookup kubernetes.default; done' | grep "Query time"

# TCP 连接测试
kubectl exec -it test-pod -- sh -c 'ab -n 10000 -c 100 http://service-name/'
```

## 网络监控指标

| 指标 | 说明 | 告警阈值 |
|------|------|----------|
| node_network_receive_bytes_total | 接收字节数 | 接近网卡限制 |
| node_network_transmit_bytes_total | 发送字节数 | 接近网卡限制 |
| node_nf_conntrack_entries | conntrack 条目数 | > 80% max |
| node_netstat_Tcp_RetransSegs | TCP 重传次数 | 持续增长 |
| container_network_receive_packets_dropped | 丢包数 | > 0 |

## 监控告警规则

```yaml
groups:
- name: network
  rules:
  - alert: ConntrackTableFull
    expr: |
      node_nf_conntrack_entries / node_nf_conntrack_entries_limit > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "节点 {{ $labels.instance }} conntrack 表使用率 > 80%"
      
  - alert: NetworkReceiveErrors
    expr: |
      rate(node_network_receive_errs_total[5m]) > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "节点 {{ $labels.instance }} 网络接收错误"
      
  - alert: HighTCPRetransmissions
    expr: |
      rate(node_netstat_Tcp_RetransSegs[5m]) 
      / rate(node_netstat_Tcp_OutSegs[5m]) > 0.01
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "节点 {{ $labels.instance }} TCP 重传率 > 1%"
      
  - alert: PodNetworkDrops
    expr: |
      sum(rate(container_network_receive_packets_dropped_total[5m])) by (pod, namespace) > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} 存在丢包"
```

## 常见网络问题与解决

| 问题 | 现象 | 解决方案 |
|------|------|----------|
| conntrack 表满 | 新连接失败 | 增加 nf_conntrack_max |
| DNS 解析慢 | 应用启动慢 | 使用 NodeLocal DNSCache |
| Service 延迟高 | 跨节点流量大 | 使用 internalTrafficPolicy: Local |
| Pod 间带宽低 | 性能不达预期 | 检查 CNI 配置和 MTU |
| 连接超时 | 间歇性失败 | 检查 keepalive 和超时设置 |
