# 表格87: 节点NotReady状态诊断

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/architecture/nodes](https://kubernetes.io/docs/concepts/architecture/nodes/)

## Node Condition状态

| Condition | 正常值 | 异常含义 | 影响 |
|-----------|-------|---------|------|
| **Ready** | True | kubelet不健康 | Pod无法调度 |
| **MemoryPressure** | False | 内存不足 | 可能驱逐Pod |
| **DiskPressure** | False | 磁盘空间不足 | 可能驱逐Pod |
| **PIDPressure** | False | 进程数过多 | 可能驱逐Pod |
| **NetworkUnavailable** | False | 网络配置问题 | Pod网络故障 |

## NotReady常见原因

| 原因类别 | 具体原因 | 诊断方法 | 解决方案 |
|---------|---------|---------|---------|
| **kubelet问题** | kubelet进程崩溃 | `systemctl status kubelet` | 重启kubelet |
| **kubelet问题** | kubelet配置错误 | 检查kubelet日志 | 修正配置 |
| **容器运行时** | containerd/docker故障 | `systemctl status containerd` | 重启运行时 |
| **容器运行时** | 运行时OOM | 检查内存使用 | 增加内存或清理 |
| **网络问题** | CNI插件故障 | 检查CNI Pod | 重启CNI |
| **网络问题** | 节点网络不通 | ping测试 | 检查网络配置 |
| **证书问题** | 证书过期 | 检查证书有效期 | 更新证书 |
| **资源耗尽** | 内存耗尽 | `free -m` | 清理或扩容 |
| **资源耗尽** | 磁盘满 | `df -h` | 清理磁盘 |
| **内核问题** | 内核panic | dmesg日志 | 重启节点 |

## 诊断流程

```bash
# 1. 检查节点状态
kubectl get nodes
kubectl describe node <node-name>

# 2. 检查节点Conditions
kubectl get node <node-name> -o jsonpath='{.status.conditions}' | jq

# 3. SSH到节点检查
ssh <node-ip>

# 4. 检查kubelet状态
systemctl status kubelet
journalctl -u kubelet -n 100 --no-pager

# 5. 检查容器运行时
systemctl status containerd
crictl info
crictl ps

# 6. 检查系统资源
free -m
df -h
top -bn1 | head -20

# 7. 检查网络
ip addr
ip route
ping <api-server-ip>
```

## kubelet问题诊断

```bash
# 检查kubelet进程
ps aux | grep kubelet
systemctl status kubelet

# 查看kubelet日志
journalctl -u kubelet -f
journalctl -u kubelet --since "10 minutes ago"

# 检查kubelet配置
cat /var/lib/kubelet/config.yaml
cat /etc/kubernetes/kubelet.conf

# 检查kubelet证书
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates

# 重启kubelet
systemctl restart kubelet
systemctl enable kubelet
```

## 容器运行时诊断

```bash
# containerd状态
systemctl status containerd
journalctl -u containerd -n 50

# 检查containerd配置
cat /etc/containerd/config.toml

# 检查容器状态
crictl ps -a
crictl pods

# 清理无用容器/镜像
crictl rmi --prune
crictl rm $(crictl ps -a -q --state exited)

# 重启containerd
systemctl restart containerd
```

## 资源耗尽诊断

```bash
# 内存检查
free -m
cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached"

# 找出内存占用最高的进程
ps aux --sort=-%mem | head -20

# 磁盘检查
df -h
df -i  # inode使用情况

# 找出磁盘占用最大的目录
du -sh /var/lib/docker/* 2>/dev/null | sort -hr | head -10
du -sh /var/lib/containerd/* 2>/dev/null | sort -hr | head -10
du -sh /var/log/* | sort -hr | head -10

# 清理容器日志
find /var/log/containers -name "*.log" -mtime +7 -delete
truncate -s 0 /var/log/containers/*.log

# 清理未使用镜像
crictl rmi --prune
```

## 网络问题诊断

```bash
# 检查网络接口
ip addr show
ip link show

# 检查路由
ip route show

# 检查CNI配置
ls -la /etc/cni/net.d/
cat /etc/cni/net.d/*.conf

# 检查CNI插件
ls -la /opt/cni/bin/

# 测试API Server连通性
curl -k https://<api-server>:6443/healthz

# 检查iptables规则
iptables -t nat -L -n | head -50
```

## 证书问题诊断

```bash
# 检查kubelet证书
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -text | grep -E "Not Before|Not After"

# 检查API Server CA
openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -dates

# 重新生成kubelet证书(kubeadm)
kubeadm certs renew all

# 手动更新kubelet证书
# 删除旧证书,kubelet会自动申请新证书
rm /var/lib/kubelet/pki/kubelet-client-current.pem
systemctl restart kubelet
```

## 节点恢复操作

```bash
# 1. 尝试重启kubelet
systemctl restart kubelet
sleep 30
kubectl get node <node-name>

# 2. 如果仍然NotReady,重启容器运行时
systemctl restart containerd
systemctl restart kubelet
sleep 60
kubectl get node <node-name>

# 3. 如果仍然失败,考虑重启节点
# 先驱逐Pod
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
# 重启
reboot

# 4. 节点恢复后取消隔离
kubectl uncordon <node-name>
```

## 监控告警

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: node-alerts
spec:
  groups:
  - name: node.status
    rules:
    - alert: NodeNotReady
      expr: kube_node_status_condition{condition="Ready",status="true"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "节点 {{ $labels.node }} NotReady"
        
    - alert: NodeMemoryPressure
      expr: kube_node_status_condition{condition="MemoryPressure",status="true"} == 1
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "节点 {{ $labels.node }} 内存压力"
        
    - alert: NodeDiskPressure
      expr: kube_node_status_condition{condition="DiskPressure",status="true"} == 1
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "节点 {{ $labels.node }} 磁盘压力"
```

## ACK节点诊断

```bash
# ACK节点诊断(控制台)
# 集群 -> 节点管理 -> 节点诊断

# 使用aliyun CLI
aliyun cs DescribeClusterNodes --ClusterId <cluster-id>

# 节点重置(ACK)
aliyun cs POST /clusters/{ClusterId}/nodes/{NodeId}/repair
```

---

**NotReady诊断原则**: 检查kubelet → 检查容器运行时 → 检查资源 → 检查网络 → 检查证书 → 必要时重启
