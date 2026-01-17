# 表格86: Pod Pending状态诊断

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/scheduling-eviction](https://kubernetes.io/docs/concepts/scheduling-eviction/)

## Pod Pending常见原因

| 原因类别 | 具体原因 | 诊断方法 | 解决方案 |
|---------|---------|---------|---------|
| **资源不足** | CPU/内存不足 | `kubectl describe pod` | 扩容节点/调整requests |
| **资源不足** | GPU不足 | 检查GPU资源 | 添加GPU节点 |
| **节点选择** | nodeSelector不匹配 | 检查节点标签 | 修正标签或选择器 |
| **节点选择** | nodeAffinity不满足 | 检查亲和性规则 | 调整亲和性配置 |
| **节点选择** | taints无法容忍 | 检查污点 | 添加tolerations |
| **调度约束** | PodTopologySpread | 检查分布约束 | 调整maxSkew |
| **调度约束** | Pod反亲和 | 检查反亲和规则 | 调整或放宽规则 |
| **存储问题** | PVC未绑定 | `kubectl get pvc` | 检查StorageClass |
| **存储问题** | 卷挂载失败 | 检查PV状态 | 检查存储后端 |
| **配额限制** | ResourceQuota超限 | 检查配额 | 调整配额或资源 |
| **配额限制** | LimitRange违规 | 检查限制范围 | 调整Pod资源配置 |
| **调度器问题** | 调度器不可用 | 检查调度器Pod | 恢复调度器 |

## 诊断流程

```bash
# 1. 查看Pod事件
kubectl describe pod <pod-name> -n <namespace> | grep -A 20 Events

# 2. 检查调度失败原因
kubectl get events --field-selector reason=FailedScheduling -n <namespace>

# 3. 检查节点资源
kubectl describe nodes | grep -A 10 "Allocated resources"

# 4. 检查可调度节点
kubectl get nodes -o wide
kubectl describe nodes | grep -E "Taints|Unschedulable"

# 5. 模拟调度(需要调度器日志)
kubectl logs -n kube-system -l component=kube-scheduler | grep <pod-name>
```

## 资源不足诊断

```bash
# 检查集群资源使用情况
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# 计算可用资源
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
CPU:.status.allocatable.cpu,\
MEMORY:.status.allocatable.memory,\
PODS:.status.allocatable.pods

# 检查节点资源压力
kubectl describe nodes | grep -E "MemoryPressure|DiskPressure|PIDPressure"

# 检查pending pod的资源请求
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].resources.requests}'
```

## 节点选择问题诊断

```bash
# 检查Pod的nodeSelector
kubectl get pod <pod-name> -o jsonpath='{.spec.nodeSelector}'

# 检查节点标签
kubectl get nodes --show-labels

# 检查Pod的亲和性
kubectl get pod <pod-name> -o jsonpath='{.spec.affinity}' | jq

# 检查节点污点
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
TAINTS:.spec.taints

# 检查Pod的容忍
kubectl get pod <pod-name> -o jsonpath='{.spec.tolerations}' | jq
```

## 存储问题诊断

```bash
# 检查PVC状态
kubectl get pvc -n <namespace>

# 检查PVC事件
kubectl describe pvc <pvc-name> -n <namespace>

# 检查StorageClass
kubectl get sc
kubectl describe sc <storageclass-name>

# 检查PV状态
kubectl get pv
kubectl describe pv <pv-name>

# 检查CSI驱动
kubectl get csidrivers
kubectl get pods -n kube-system | grep csi
```

## 配额问题诊断

```bash
# 检查ResourceQuota
kubectl get resourcequota -n <namespace>
kubectl describe resourcequota -n <namespace>

# 检查LimitRange
kubectl get limitrange -n <namespace>
kubectl describe limitrange -n <namespace>

# 检查命名空间资源使用
kubectl describe ns <namespace> | grep -A 20 "Resource Quotas"
```

## 常见解决方案

| 问题 | 解决方案 | 命令示例 |
|-----|---------|---------|
| CPU不足 | 扩容或调整requests | 调整Deployment资源配置 |
| 内存不足 | 扩容或调整requests | 添加节点或降低requests |
| 节点标签不匹配 | 添加节点标签 | `kubectl label node <node> key=value` |
| 污点无法容忍 | 添加toleration | 修改Pod spec |
| PVC未绑定 | 检查StorageClass | 确保SC存在且可用 |
| 配额超限 | 调整配额或释放资源 | 修改ResourceQuota |

## 紧急处理

```bash
# 临时跳过调度约束(仅测试)
kubectl patch deployment <name> -p '{"spec":{"template":{"spec":{"nodeSelector":null}}}}'

# 强制删除Pending Pod
kubectl delete pod <pod-name> --force --grace-period=0

# 临时扩容节点(ACK)
aliyun cs POST /clusters/{ClusterId}/nodepools/{NodepoolId}/nodes \
  --body '{"count": 2}'
```

## 监控告警

```yaml
# PrometheusRule - Pending Pod告警
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: pod-pending-alerts
spec:
  groups:
  - name: pod.pending
    rules:
    - alert: PodPendingTooLong
      expr: |
        sum by (namespace, pod) (
          kube_pod_status_phase{phase="Pending"} == 1
        ) * on (namespace, pod) group_left()
        (time() - kube_pod_created) > 300
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} Pending超过5分钟"
```

---

**Pending诊断原则**: 先看Events确定原因 → 资源/节点/存储/配额逐一排查 → 针对性解决
