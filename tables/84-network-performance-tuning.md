# 表格84: 网络性能调优

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/cluster-administration/networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/)

## 网络性能瓶颈

| 瓶颈类型 | 症状 | 诊断方法 |
|---------|-----|---------|
| 带宽不足 | 吞吐量低 | iperf3测试 |
| 延迟高 | 响应慢 | ping/hping |
| 丢包 | 连接不稳定 | netstat/ss |
| conntrack满 | 新连接失败 | conntrack -L |
| 队列溢出 | 间歇性问题 | ethtool -S |

## 内核网络参数

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: network-tuning
data:
  sysctl.conf: |
    # conntrack优化
    net.netfilter.nf_conntrack_max = 1048576
    net.netfilter.nf_conntrack_tcp_timeout_established = 86400
    net.netfilter.nf_conntrack_tcp_timeout_close_wait = 3600
    
    # 网络缓冲区
    net.core.rmem_max = 134217728
    net.core.wmem_max = 134217728
    net.core.rmem_default = 16777216
    net.core.wmem_default = 16777216
    net.core.netdev_max_backlog = 65536
    net.core.somaxconn = 65535
    
    # TCP优化
    net.ipv4.tcp_rmem = 4096 87380 134217728
    net.ipv4.tcp_wmem = 4096 65536 134217728
    net.ipv4.tcp_max_syn_backlog = 65536
    net.ipv4.tcp_slow_start_after_idle = 0
    net.ipv4.tcp_tw_reuse = 1
    net.ipv4.tcp_fin_timeout = 30
    net.ipv4.tcp_keepalive_time = 600
    net.ipv4.tcp_keepalive_probes = 5
    net.ipv4.tcp_keepalive_intvl = 15
    
    # 本地端口范围
    net.ipv4.ip_local_port_range = 1024 65535
    
    # MTU发现
    net.ipv4.tcp_mtu_probing = 1
```

## kubelet网络配置

```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
maxPods: 250
podPidsLimit: 4096
```

## kube-proxy性能优化

```yaml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs  # 大规模使用IPVS
ipvs:
  scheduler: rr
  syncPeriod: 30s
  minSyncPeriod: 2s
conntrack:
  maxPerCore: 65536
  min: 524288
  tcpEstablishedTimeout: 86400s
  tcpCloseWaitTimeout: 3600s
```

## CNI带宽限制

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: bandwidth-limited
  annotations:
    kubernetes.io/ingress-bandwidth: "10M"
    kubernetes.io/egress-bandwidth: "10M"
spec:
  containers:
  - name: app
    image: myapp
```

## Cilium带宽管理

```yaml
# Helm values
apiVersion: v1
kind: ConfigMap
metadata:
  name: cilium-bandwidth
data:
  values.yaml: |
    bandwidthManager:
      enabled: true
      bbr: true  # 启用BBR拥塞控制
```

## 网卡多队列

```bash
# 检查网卡队列
ethtool -l eth0

# 设置网卡队列数
ethtool -L eth0 combined 8

# 配置IRQ亲和性
# 将网卡中断分散到多个CPU
for i in /proc/irq/*/eth0*/smp_affinity_list; do
  echo "0-7" > $i
done
```

## MTU优化

| 环境 | 推荐MTU | 说明 |
|-----|--------|------|
| 物理网络 | 1500 | 默认 |
| VXLAN | 1450 | 50字节开销 |
| WireGuard | 1420 | 80字节开销 |
| Jumbo Frame | 9000 | 需网络支持 |

## 性能测试命令

```bash
# 带宽测试
iperf3 -s  # 服务端
iperf3 -c <server-ip> -t 30 -P 4  # 客户端,4并发

# 延迟测试
ping -c 100 <target>
hping3 -S -p 80 -c 100 <target>

# 连接数测试
wrk -t4 -c400 -d30s http://<service>/

# TCP连接状态
ss -s
netstat -an | awk '/^tcp/ {++state[$NF]} END {for(k in state) print k,state[k]}'

# conntrack使用
conntrack -L | wc -l
cat /proc/sys/net/netfilter/nf_conntrack_count
cat /proc/sys/net/netfilter/nf_conntrack_max
```

## 网络监控指标

| 指标 | 类型 | 告警阈值 |
|-----|-----|---------|
| `node_network_receive_bytes_total` | Counter | - |
| `node_network_transmit_bytes_total` | Counter | - |
| `node_network_receive_drop_total` | Counter | >0持续 |
| `node_network_transmit_drop_total` | Counter | >0持续 |
| `node_netstat_Tcp_CurrEstab` | Gauge | 接近端口范围 |
| `node_nf_conntrack_entries` | Gauge | >80%max |

## 性能告警规则

```yaml
groups:
- name: network-performance
  rules:
  - alert: HighNetworkDrops
    expr: rate(node_network_receive_drop_total[5m]) > 0
    for: 5m
    labels:
      severity: warning
      
  - alert: ConntrackNearFull
    expr: node_nf_conntrack_entries / node_nf_conntrack_entries_limit > 0.8
    for: 5m
    labels:
      severity: critical
      
  - alert: HighNetworkLatency
    expr: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) > 1
    for: 10m
    labels:
      severity: warning
```

## ACK网络优化

| 功能 | 说明 |
|-----|------|
| Terway ENIIP | 零网络损耗 |
| eRDMA | 高性能RDMA |
| 智能网卡 | 硬件卸载 |
| 网络优化镜像 | 预优化内核参数 |
