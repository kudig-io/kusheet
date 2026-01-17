# Kubernetes 故障排查指南

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/tasks/debug](https://kubernetes.io/docs/tasks/debug/)

## 故障排查方法论

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes 故障排查流程                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. 确认故障范围                                                 │
│     ├── 单个 Pod/应用？                                         │
│     ├── 整个节点？                                               │
│     ├── 整个集群？                                               │
│     └── 网络/存储？                                              │
│                        ▼                                         │
│  2. 收集信息                                                     │
│     ├── kubectl describe <resource>                             │
│     ├── kubectl logs <pod>                                      │
│     ├── kubectl get events                                      │
│     └── Prometheus/监控数据                                      │
│                        ▼                                         │
│  3. 分析根因                                                     │
│     ├── 资源问题？(CPU/Memory/Disk)                             │
│     ├── 配置问题？(YAML/参数)                                   │
│     ├── 网络问题？(CNI/DNS/Policy)                              │
│     └── 依赖问题？(存储/外部服务)                               │
│                        ▼                                         │
│  4. 修复验证                                                     │
│     ├── 应用修复                                                 │
│     ├── 验证恢复                                                 │
│     └── 记录经验                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Pod 故障排查

### Pod 状态流转

```
                            ┌─────────────────────────────────┐
                            │         Pod 生命周期             │
                            └─────────────────────────────────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    │                     │                     │
                    ▼                     ▼                     ▼
            ┌───────────┐         ┌───────────┐         ┌───────────┐
            │  Pending  │         │  Running  │         │ Succeeded │
            └─────┬─────┘         └─────┬─────┘         └───────────┘
                  │                     │                     
    ┌─────────────┼─────────────┐       │                     
    │             │             │       │                     
    ▼             ▼             ▼       ▼                     
┌────────┐ ┌──────────┐ ┌─────────┐ ┌────────┐              
│Unsched-│ │Container │ │ Image   │ │ Failed │              
│ulable  │ │Creating  │ │ Pull    │ │        │              
└────────┘ └──────────┘ │ BackOff │ └────────┘              
                        └─────────┘                          
```

### Pod Pending 诊断

| 原因 | Events关键字 | 诊断方法 | 解决方案 |
|------|-------------|----------|----------|
| 资源不足 | FailedScheduling, Insufficient | `kubectl describe node` | 扩容节点或减少requests |
| 节点选择失败 | FailedScheduling, node selector | 检查nodeSelector/affinity | 修正选择器或添加标签 |
| 污点不容忍 | FailedScheduling, taint | `kubectl describe node \| grep Taints` | 添加tolerations |
| PVC未绑定 | FailedScheduling, unbound | `kubectl get pvc` | 检查StorageClass |
| 调度门限制 | SchedulingGated | `kubectl get pod -o yaml` | v1.27+移除调度门 |

```bash
# Pod Pending 诊断命令
kubectl describe pod <pod-name> | grep -A 20 Events
kubectl get events --field-selector involvedObject.name=<pod-name>

# 查看调度器日志
kubectl logs -n kube-system -l component=kube-scheduler --tail=100

# 检查节点资源
kubectl describe nodes | grep -A 5 "Allocated resources"

# 检查节点污点
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

### Pod CrashLoopBackOff 诊断

| 原因 | 日志特征 | 诊断方法 | 解决方案 |
|------|----------|----------|----------|
| 应用崩溃 | 应用错误日志 | `kubectl logs --previous` | 修复应用代码 |
| OOM | OOMKilled | `kubectl describe pod` | 增加内存limits |
| 探针失败 | Liveness probe failed | 检查探针配置 | 调整探针参数 |
| 配置错误 | 配置解析错误 | 检查ConfigMap/Secret | 修正配置 |
| 依赖未就绪 | 连接拒绝 | 检查依赖服务 | 使用initContainer |
| 权限问题 | Permission denied | 检查SecurityContext | 配置正确的权限 |

```bash
# CrashLoopBackOff 诊断
kubectl logs <pod> --previous
kubectl logs <pod> -c <container> --previous
kubectl describe pod <pod> | grep -A 10 "Last State"

# 检查容器退出码
kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[*].lastState.terminated.exitCode}'

# 进入容器调试 (如果可以启动)
kubectl exec -it <pod> -- /bin/sh

# 使用调试容器 (v1.25+)
kubectl debug -it <pod> --image=busybox --target=<container>
```

### Pod OOMKilled 诊断

```bash
# 检查OOM事件
kubectl describe pod <pod> | grep -i oom
dmesg | grep -i oom | tail -20

# 查看容器内存使用
kubectl top pod <pod> --containers

# 查看节点内存
kubectl top nodes
kubectl describe node <node> | grep -A 5 "Allocated resources"

# 检查cgroup内存限制
cat /sys/fs/cgroup/memory/kubepods/pod<uid>/<container-id>/memory.limit_in_bytes
```

### Pod 网络问题诊断

```bash
# 测试Pod间连通性
kubectl exec -it <pod1> -- ping <pod2-ip>
kubectl exec -it <pod1> -- nc -zv <service-name> <port>

# DNS诊断
kubectl exec -it <pod> -- nslookup kubernetes.default
kubectl exec -it <pod> -- cat /etc/resolv.conf

# 检查NetworkPolicy
kubectl get networkpolicy -A
kubectl describe networkpolicy <name>

# 抓包分析
kubectl debug -it <pod> --image=nicolaka/netshoot -- tcpdump -i any port 80
```

## Node 故障排查

### Node 状态诊断

| 状态 | 含义 | 诊断命令 | 解决方案 |
|------|------|----------|----------|
| Ready=False | kubelet问题/资源耗尽 | `systemctl status kubelet` | 检查kubelet日志 |
| Ready=Unknown | 节点失联 | 检查网络连通性 | 检查节点网络 |
| MemoryPressure | 内存不足 | `free -h` | 驱逐Pod/扩容 |
| DiskPressure | 磁盘不足 | `df -h` | 清理磁盘/扩容 |
| PIDPressure | PID耗尽 | `ps aux \| wc -l` | 限制Pod PID |
| NetworkUnavailable | CNI问题 | 检查CNI状态 | 修复CNI |

```bash
# Node NotReady 完整诊断流程
echo "=== Node 状态 ==="
kubectl describe node <node-name> | grep -A 10 Conditions

echo "=== kubelet 状态 ==="
ssh <node> "systemctl status kubelet"

echo "=== kubelet 日志 ==="
ssh <node> "journalctl -u kubelet -n 100 --no-pager"

echo "=== 容器运行时状态 ==="
ssh <node> "crictl info"
ssh <node> "crictl ps"

echo "=== 系统资源 ==="
ssh <node> "free -h && df -h && uptime"

echo "=== 网络连通性 ==="
ssh <node> "curl -k https://<api-server>:6443/healthz"

echo "=== CNI状态 ==="
ssh <node> "ls /etc/cni/net.d/"
ssh <node> "crictl pods"
```

### kubelet 问题诊断

| 问题 | 日志关键字 | 原因 | 解决方案 |
|------|-----------|------|----------|
| PLEG不健康 | PLEG is not healthy | 容器运行时慢 | 重启containerd |
| 节点资源不足 | eviction manager | 资源压力 | 清理资源 |
| 证书问题 | certificate | 证书过期/错误 | 更新证书 |
| API连接失败 | connection refused | 网络/API问题 | 检查网络 |
| 容器创建失败 | failed to create | CRI问题 | 检查运行时 |

```bash
# kubelet 常见问题诊断
# PLEG问题
journalctl -u kubelet | grep -i pleg

# 证书问题
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates

# 资源问题
cat /var/lib/kubelet/config.yaml | grep -A 10 eviction

# 运行时问题
crictl info
crictl ps -a | head -20
```

## Service/网络 故障排查

### Service 连接问题诊断流程

```
┌─────────────────────────────────────────────────────────────────┐
│                    Service 连接问题诊断流程                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Service 是否存在？                                          │
│     kubectl get svc <name>                                      │
│                        │                                         │
│                        ▼                                         │
│  2. Endpoints 是否有后端？                                      │
│     kubectl get endpoints <name>                                │
│     ├── 无 Endpoints → 检查 selector 是否匹配 Pod 标签          │
│     └── 有 Endpoints → 继续                                     │
│                        │                                         │
│                        ▼                                         │
│  3. Pod 是否就绪？                                              │
│     kubectl get pods -l <selector> -o wide                      │
│     ├── Pod 未 Ready → 检查 Pod 状态                            │
│     └── Pod Ready → 继续                                        │
│                        │                                         │
│                        ▼                                         │
│  4. kube-proxy 规则是否正确？                                   │
│     iptables -t nat -L | grep <service-ip>                      │
│     ipvsadm -Ln | grep <service-ip>                             │
│                        │                                         │
│                        ▼                                         │
│  5. Pod 端口是否监听？                                          │
│     kubectl exec <pod> -- netstat -tlnp                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

```bash
# Service 诊断脚本
SERVICE_NAME=$1
NAMESPACE=${2:-default}

echo "=== Service 信息 ==="
kubectl get svc $SERVICE_NAME -n $NAMESPACE -o wide

echo "=== Endpoints ==="
kubectl get endpoints $SERVICE_NAME -n $NAMESPACE

echo "=== EndpointSlices ==="
kubectl get endpointslices -n $NAMESPACE -l kubernetes.io/service-name=$SERVICE_NAME

echo "=== 后端 Pods ==="
SELECTOR=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.selector}' | tr -d '{}' | tr ':' '=' | tr ',' ' ')
kubectl get pods -n $NAMESPACE -l "$SELECTOR" -o wide

echo "=== 连接测试 ==="
kubectl run test-$RANDOM --rm -it --image=busybox --restart=Never -- \
  wget -qO- --timeout=5 $SERVICE_NAME.$NAMESPACE.svc.cluster.local
```

### DNS 问题诊断

```bash
# DNS 完整诊断
echo "=== CoreDNS Pods ==="
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide

echo "=== CoreDNS 日志 ==="
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50

echo "=== DNS 解析测试 ==="
kubectl run dnstest --rm -it --image=busybox --restart=Never -- nslookup kubernetes.default

echo "=== resolv.conf ==="
kubectl run dnstest --rm -it --image=busybox --restart=Never -- cat /etc/resolv.conf

echo "=== CoreDNS ConfigMap ==="
kubectl get configmap coredns -n kube-system -o yaml
```

## 存储故障排查

### PVC 状态诊断

| PVC状态 | 含义 | 诊断方法 | 解决方案 |
|---------|------|----------|----------|
| Pending | 等待绑定 | 检查StorageClass/PV | 创建PV或检查CSI |
| Bound | 已绑定 | 正常 | - |
| Lost | PV丢失 | 检查后端存储 | 恢复PV |

```bash
# PVC Pending 诊断
kubectl describe pvc <pvc-name>
kubectl get storageclass
kubectl get pv

# CSI 驱动诊断
kubectl get csidrivers
kubectl get csinodes
kubectl get pods -n kube-system -l app=csi-provisioner
kubectl logs -n kube-system -l app=csi-provisioner --tail=100

# 卷挂载问题
kubectl describe pod <pod> | grep -A 20 Volumes
kubectl describe pod <pod> | grep -A 20 Events
```

## etcd/控制平面 故障排查

### etcd 诊断

```bash
#!/bin/bash
# etcd 健康检查脚本

ETCDCTL="etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key"

echo "=== 集群健康 ==="
$ETCDCTL endpoint health --cluster

echo "=== 集群状态 ==="
$ETCDCTL endpoint status --cluster -w table

echo "=== 成员列表 ==="
$ETCDCTL member list -w table

echo "=== 数据库大小 ==="
$ETCDCTL endpoint status --cluster -w json | jq '.[].Status.dbSize'

echo "=== 性能检查 ==="
$ETCDCTL check perf

echo "=== 告警检查 ==="
$ETCDCTL alarm list
```

### etcd 常见问题修复

```bash
# 数据库满 - 压缩和碎片整理
# 1. 获取当前revision
rev=$(etcdctl endpoint status --write-out="json" | jq '.[0].Status.header.revision')

# 2. 压缩历史
etcdctl compact $rev

# 3. 碎片整理
etcdctl defrag --cluster

# 4. 清除告警
etcdctl alarm disarm

# Leader频繁切换 - 检查网络延迟
for endpoint in etcd-0:2379 etcd-1:2379 etcd-2:2379; do
  echo "=== $endpoint ==="
  etcdctl endpoint status --endpoints=$endpoint -w table
done

# 备份恢复
# 备份
etcdctl snapshot save /backup/etcd-snapshot-$(date +%Y%m%d).db

# 恢复
etcdctl snapshot restore /backup/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restore \
  --initial-cluster=master-0=https://10.0.0.10:2380 \
  --initial-advertise-peer-urls=https://10.0.0.10:2380
```

## 监控告警规则

```yaml
groups:
- name: kubernetes-troubleshooting
  rules:
  # Pod 问题
  - alert: PodCrashLooping
    expr: |
      rate(kube_pod_container_status_restarts_total[15m]) * 60 * 15 > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} 频繁重启"
      
  - alert: PodNotReady
    expr: |
      kube_pod_status_ready{condition="true"} == 0
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} 长时间未就绪"
      
  - alert: PodPending
    expr: |
      kube_pod_status_phase{phase="Pending"} == 1
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} 长时间 Pending"
      
  # Node 问题  
  - alert: NodeNotReady
    expr: |
      kube_node_status_condition{condition="Ready",status="true"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "节点 {{ $labels.node }} NotReady"
      
  - alert: NodeMemoryPressure
    expr: |
      kube_node_status_condition{condition="MemoryPressure",status="true"} == 1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "节点 {{ $labels.node }} 内存压力"
      
  - alert: NodeDiskPressure
    expr: |
      kube_node_status_condition{condition="DiskPressure",status="true"} == 1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "节点 {{ $labels.node }} 磁盘压力"
      
  # 控制平面问题
  - alert: KubeAPIServerDown
    expr: absent(up{job="kubernetes-apiservers"} == 1)
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "API Server 不可用"
      
  - alert: EtcdNoLeader
    expr: etcd_server_has_leader == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "etcd 集群无 Leader"
      
  # DNS 问题
  - alert: CoreDNSDown
    expr: absent(up{job="coredns"} == 1)
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "CoreDNS 不可用"
      
  - alert: CoreDNSLatencyHigh
    expr: |
      histogram_quantile(0.99, sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le)) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "CoreDNS P99 延迟 > 100ms"
```

## 快速诊断脚本

```bash
#!/bin/bash
# k8s-full-diagnose.sh - 完整诊断脚本

echo "================================================"
echo "Kubernetes 集群诊断报告"
echo "时间: $(date)"
echo "================================================"

echo -e "\n=== 1. 集群概览 ==="
kubectl cluster-info
kubectl get nodes -o wide
kubectl version --short

echo -e "\n=== 2. 控制平面健康 ==="
kubectl get --raw='/readyz?verbose' 2>/dev/null | grep -E "^\[|readyz"
kubectl get cs 2>/dev/null

echo -e "\n=== 3. 问题资源 ==="
echo "--- 问题 Pods ---"
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers | head -20

echo "--- Pending PVCs ---"
kubectl get pvc -A --field-selector=status.phase=Pending --no-headers

echo "--- NotReady Nodes ---"
kubectl get nodes --no-headers | grep -v " Ready "

echo -e "\n=== 4. 资源使用 ==="
kubectl top nodes 2>/dev/null || echo "Metrics Server 未安装"
echo "--- Top 10 CPU Pods ---"
kubectl top pods -A --sort-by=cpu 2>/dev/null | head -11

echo -e "\n=== 5. 最近事件 ==="
kubectl get events -A --sort-by='.lastTimestamp' | grep -v "Normal" | tail -20

echo -e "\n=== 6. 重启统计 (Top 10) ==="
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.restartCount}{end}{"\n"}{end}' 2>/dev/null | \
  sort -t$'\t' -k3 -nr | head -10

echo -e "\n=== 7. kube-system 状态 ==="
kubectl get pods -n kube-system -o wide

echo -e "\n=== 诊断完成 ==="
```

## ACK 特定诊断

```bash
# ACK 集群诊断
aliyun cs DescribeClusterDetail --ClusterId <cluster-id>

# ACK 节点诊断
aliyun cs DescribeClusterNodes --ClusterId <cluster-id>

# ACK 组件状态
aliyun cs DescribeClusterAddonsVersion --ClusterId <cluster-id>

# 获取集群事件
aliyun cs DescribeEvents --ClusterId <cluster-id>
```
