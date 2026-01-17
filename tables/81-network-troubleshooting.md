# 表格81: 网络故障诊断

## 网络问题分类

| 类型 | 症状 | 常见原因 |
|-----|------|---------|
| DNS解析失败 | 无法解析服务名 | CoreDNS故障/策略阻断 |
| Pod间不通 | 跨节点通信失败 | CNI问题/NetworkPolicy |
| Service不通 | ClusterIP无响应 | Endpoints为空/kube-proxy |
| 外部访问失败 | 无法访问外网 | NAT/防火墙/策略 |
| 延迟高 | 响应慢 | 网络拥塞/MTU问题 |

## 诊断工具箱Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: network-debug
spec:
  containers:
  - name: debug
    image: nicolaka/netshoot:latest
    command: ["sleep", "infinity"]
    securityContext:
      capabilities:
        add: ["NET_ADMIN", "NET_RAW"]
```

## DNS诊断命令

```bash
# 测试DNS解析
kubectl exec -it network-debug -- nslookup kubernetes.default

# 检查DNS配置
kubectl exec -it network-debug -- cat /etc/resolv.conf

# 测试外部DNS
kubectl exec -it network-debug -- nslookup google.com

# 查看CoreDNS日志
kubectl logs -n kube-system -l k8s-app=kube-dns

# 查看CoreDNS配置
kubectl get cm coredns -n kube-system -o yaml

# DNS性能测试
kubectl exec -it network-debug -- \
  bash -c "for i in {1..100}; do nslookup kubernetes.default > /dev/null; done"
```

## 连通性诊断

```bash
# Pod到Pod
kubectl exec -it network-debug -- ping <pod-ip>
kubectl exec -it network-debug -- curl -v <pod-ip>:<port>

# Pod到Service
kubectl exec -it network-debug -- curl -v <service-name>:<port>
kubectl exec -it network-debug -- curl -v <cluster-ip>:<port>

# Pod到外部
kubectl exec -it network-debug -- curl -v https://www.aliyun.com

# 路由追踪
kubectl exec -it network-debug -- traceroute <target-ip>

# TCP连接测试
kubectl exec -it network-debug -- nc -zv <host> <port>
```

## CNI诊断

```bash
# Calico诊断
kubectl exec -n kube-system <calico-node-pod> -- calico-node -bird-live
kubectl exec -n kube-system <calico-node-pod> -- calico-node -felix-live
calicoctl node status
calicoctl get ipPool -o wide

# Cilium诊断
cilium status
cilium connectivity test
cilium monitor
cilium bpf endpoint list
cilium bpf nat list

# 通用CNI检查
ls /etc/cni/net.d/
cat /etc/cni/net.d/10-*.conflist
ls /opt/cni/bin/
```

## kube-proxy诊断

```bash
# 查看kube-proxy模式
kubectl get cm kube-proxy -n kube-system -o yaml | grep mode

# iptables规则检查
iptables -t nat -L KUBE-SERVICES -n | head -50
iptables -t nat -L KUBE-SVC-* -n

# IPVS规则检查
ipvsadm -Ln
ipvsadm -Ln --stats

# kube-proxy日志
kubectl logs -n kube-system -l k8s-app=kube-proxy
```

## NetworkPolicy诊断

```bash
# 查看策略
kubectl get networkpolicy -A
kubectl describe networkpolicy <name>

# Calico策略
calicoctl get networkpolicy -A -o wide
calicoctl get globalnetworkpolicy -o wide

# Cilium策略
cilium policy get
cilium endpoint list
cilium monitor --type policy-verdict
```

## 抓包分析

```bash
# Pod内抓包
kubectl exec -it network-debug -- tcpdump -i eth0 -nn port 80

# 节点抓包
tcpdump -i any host <pod-ip> -nn

# 抓包保存
kubectl exec -it network-debug -- tcpdump -i eth0 -w /tmp/capture.pcap
kubectl cp network-debug:/tmp/capture.pcap ./capture.pcap
```

## MTU问题诊断

```bash
# 检查MTU
kubectl exec -it network-debug -- ip link show
kubectl exec -it network-debug -- cat /sys/class/net/eth0/mtu

# MTU路径发现
kubectl exec -it network-debug -- ping -M do -s 1472 <target>

# 分片测试
kubectl exec -it network-debug -- ping -s 1500 -M want <target>
```

## 性能诊断

```bash
# 带宽测试
# 服务端
kubectl exec -it iperf-server -- iperf3 -s
# 客户端
kubectl exec -it iperf-client -- iperf3 -c <server-ip>

# 延迟测试
kubectl exec -it network-debug -- hping3 -S -p 80 -c 10 <target>

# 连接数测试
kubectl exec -it network-debug -- ab -n 1000 -c 100 http://<service>/
```

## 常见问题速查

| 问题 | 诊断命令 | 可能原因 |
|-----|---------|---------|
| DNS超时 | `nslookup -timeout=1` | CoreDNS过载 |
| 跨节点不通 | `traceroute` | CNI隧道/路由 |
| Service不通 | `ipvsadm -Ln` | Endpoints为空 |
| 随机超时 | `tcpdump` | conntrack表满 |
| 性能差 | `iperf3` | MTU/带宽限制 |

## ACK网络诊断

| 工具 | 说明 |
|-----|------|
| 节点诊断 | 控制台一键诊断 |
| Terway诊断 | `terway-cli` |
| 网络拓扑 | 可视化网络拓扑 |
| 日志服务 | 网络日志分析 |
