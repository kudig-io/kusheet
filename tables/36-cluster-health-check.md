# 表格36：集群健康检查表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/tasks/debug/debug-cluster](https://kubernetes.io/docs/tasks/debug/debug-cluster/)

## 控制平面健康检查

| 检查项 | 诊断命令 | 预期输出 | 异常阈值 | 版本变更 | 排查步骤 |
|-------|---------|---------|---------|---------|---------|
| **API Server可用性** | `kubectl get --raw='/healthz'` | ok | 非ok | 稳定 | 检查apiserver日志，etcd连接 |
| **API Server详细健康** | `kubectl get --raw='/readyz?verbose'` | 全部通过 | 任何failed | v1.28增强 | 检查具体失败项 |
| **etcd健康** | `etcdctl endpoint health` | healthy | unhealthy | 稳定 | 检查etcd日志，磁盘IO |
| **etcd集群状态** | `etcdctl endpoint status --cluster` | 有leader | 无leader | 稳定 | 检查网络，重启etcd |
| **Scheduler健康** | `kubectl get --raw='/healthz/scheduler'` | ok | 非ok | 稳定 | 检查scheduler日志 |
| **Controller健康** | `kubectl get --raw='/healthz/controller-manager'` | ok | 非ok | 稳定 | 检查controller日志 |
| **组件状态(旧)** | `kubectl get componentstatuses` | Healthy | Unhealthy | 已弃用 | 使用/readyz替代 |

## 节点健康检查

| 检查项 | 诊断命令 | 预期输出 | 异常阈值 | 排查步骤 |
|-------|---------|---------|---------|---------|
| **节点状态** | `kubectl get nodes` | Ready | NotReady | 检查kubelet状态 |
| **节点详情** | `kubectl describe node <name>` | 无异常Condition | 有True的异常条件 | 检查具体条件 |
| **节点资源** | `kubectl top nodes` | 正常值 | CPU>90%或Memory>90% | 扩容或驱逐Pod |
| **节点磁盘** | `kubectl describe node \| grep -A5 Conditions` | DiskPressure=False | DiskPressure=True | 清理磁盘 |
| **节点内存** | 同上 | MemoryPressure=False | MemoryPressure=True | 驱逐Pod |
| **节点PID** | 同上 | PIDPressure=False | PIDPressure=True | 限制Pod PID |
| **节点网络** | 同上 | NetworkUnavailable=False | NetworkUnavailable=True | 检查CNI |
| **kubelet状态** | `systemctl status kubelet` | active | inactive/failed | 重启kubelet |
| **容器运行时** | `crictl info` | 正常信息 | 错误信息 | 检查containerd |

## 节点Condition对照

| Condition | True含义 | False含义 | 检查方法 |
|----------|---------|----------|---------|
| **Ready** | 节点健康可调度 | 节点不健康 | kubelet状态 |
| **MemoryPressure** | 内存不足 | 内存充足 | free -h |
| **DiskPressure** | 磁盘不足 | 磁盘充足 | df -h |
| **PIDPressure** | PID不足 | PID充足 | ps aux \| wc -l |
| **NetworkUnavailable** | 网络未配置 | 网络正常 | CNI状态 |

## Pod健康检查

| 检查项 | 诊断命令 | 预期输出 | 异常情况 |
|-------|---------|---------|---------|
| **Pod状态** | `kubectl get pods -A` | Running/Succeeded | Pending/Failed/CrashLoopBackOff |
| **问题Pod** | `kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded` | 无结果 | 有结果 |
| **Pod事件** | `kubectl events --for pod/<name>` | 正常事件 | Warning事件 |
| **容器日志** | `kubectl logs <pod>` | 正常日志 | 错误日志 |
| **容器重启** | `kubectl get pods -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}'` | 0或低 | 高重启次数 |

## 网络健康检查

| 检查项 | 诊断命令 | 预期输出 | 异常处理 |
|-------|---------|---------|---------|
| **DNS解析** | `kubectl exec -it <pod> -- nslookup kubernetes` | 成功解析 | 检查CoreDNS |
| **Service访问** | `kubectl exec -it <pod> -- curl <service>` | 正常响应 | 检查Endpoints |
| **Pod间通信** | `kubectl exec -it <pod> -- ping <other-pod-ip>` | 成功ping | 检查CNI |
| **外部访问** | `kubectl exec -it <pod> -- curl ifconfig.me` | IP地址 | 检查NAT/Egress |
| **CoreDNS状态** | `kubectl get pods -n kube-system -l k8s-app=kube-dns` | Running | 检查CoreDNS日志 |
| **kube-proxy状态** | `kubectl get pods -n kube-system -l k8s-app=kube-proxy` | Running | 检查kube-proxy日志 |

## 存储健康检查

| 检查项 | 诊断命令 | 预期输出 | 异常处理 |
|-------|---------|---------|---------|
| **PV状态** | `kubectl get pv` | Bound/Available | Released/Failed需处理 |
| **PVC状态** | `kubectl get pvc -A` | Bound | Pending检查SC |
| **SC状态** | `kubectl get sc` | 存在默认SC | 创建SC |
| **CSI驱动** | `kubectl get csidrivers` | 驱动列表 | 安装CSI驱动 |

## 安全健康检查

| 检查项 | 诊断命令 | 预期输出 | 风险等级 |
|-------|---------|---------|---------|
| **RBAC启用** | `kubectl api-versions \| grep rbac` | 存在rbac | P0 |
| **审计日志** | 检查apiserver参数 | --audit-log-path存在 | P1 |
| **匿名认证** | 检查apiserver参数 | --anonymous-auth=false | P1 |
| **PSA启用** | `kubectl get ns -L pod-security.kubernetes.io/enforce` | 有标签 | P1 |
| **NetworkPolicy** | `kubectl get networkpolicy -A` | 存在策略 | P1 |

## 自动化健康检查脚本

```bash
#!/bin/bash
# k8s-health-check.sh

echo "====== Kubernetes集群健康检查 ======"
echo "时间: $(date)"
echo ""

# 1. 控制平面检查
echo "=== 1. 控制平面健康 ==="
echo "API Server: $(kubectl get --raw='/healthz' 2>/dev/null || echo 'FAILED')"
echo "etcd: $(kubectl get --raw='/healthz/etcd' 2>/dev/null || echo 'FAILED')"

# 2. 节点状态
echo -e "\n=== 2. 节点状态 ==="
kubectl get nodes -o wide
NOT_READY=$(kubectl get nodes --no-headers | grep -v " Ready" | wc -l)
echo "NotReady节点数: $NOT_READY"

# 3. 系统Pod状态
echo -e "\n=== 3. kube-system Pod状态 ==="
kubectl get pods -n kube-system --no-headers | grep -v "Running\|Completed" || echo "全部正常"

# 4. 问题Pod
echo -e "\n=== 4. 问题Pod ==="
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | head -20 || echo "无问题Pod"

# 5. 资源使用
echo -e "\n=== 5. 节点资源使用 ==="
kubectl top nodes 2>/dev/null || echo "Metrics Server未安装"

# 6. PVC状态
echo -e "\n=== 6. PVC状态 ==="
kubectl get pvc -A --no-headers | grep -v "Bound" || echo "全部已绑定"

# 7. 最近事件
echo -e "\n=== 7. 最近Warning事件 ==="
kubectl get events -A --field-selector=type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -10

# 8. 证书过期检查
echo -e "\n=== 8. 证书状态 ==="
kubeadm certs check-expiration 2>/dev/null || echo "非kubeadm集群或无权限"

echo -e "\n====== 检查完成 ======"
```

## 健康检查指标(Prometheus)

| 指标 | 告警条件 | 严重性 |
|-----|---------|-------|
| `up{job="kubernetes-apiservers"}` | == 0 | Critical |
| `etcd_server_has_leader` | == 0 | Critical |
| `kube_node_status_condition{condition="Ready",status="true"}` | == 0 | Critical |
| `kube_pod_status_phase{phase="Failed"}` | > 0 持续5m | Warning |
| `kubelet_pleg_relist_duration_seconds_bucket` | P99 > 3s | Warning |
| `scheduler_pending_pods` | > 100 持续10m | Warning |

## ACK健康检查

| 功能 | 入口 | 检查内容 |
|-----|------|---------|
| **集群诊断** | 控制台 | 全面健康检查 |
| **节点诊断** | 控制台 | 节点问题排查 |
| **网络诊断** | 控制台 | 网络连通性 |
| **ARMS监控** | ARMS控制台 | 组件指标 |

## 健康检查告警规则

```yaml
# PrometheusRule - 集群健康检查告警
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cluster-health-alerts
  namespace: monitoring
spec:
  groups:
  - name: cluster-health
    rules:
    - alert: KubeAPIServerDown
      expr: up{job="kubernetes-apiservers"} == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "API Server不可用"
        description: "Kubernetes API Server已停止响应"
    - alert: EtcdNoLeader
      expr: etcd_server_has_leader == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "etcd无Leader"
        description: "etcd集群没有选出Leader"
    - alert: NodeNotReady
      expr: kube_node_status_condition{condition="Ready",status="true"} == 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "节点NotReady"
        description: "节点 {{ $labels.node }} 状态为NotReady"
    - alert: PodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total[15m]) > 0.1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod频繁重启"
        description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} 频繁重启"
```

---

**健康检查原则**: 定期检查，自动化监控，快速响应
