# 表格88: OOM和内存问题诊断

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/configuration/manage-resources-containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

## OOM类型

| 类型 | 触发者 | 表现 | 日志特征 |
|-----|-------|------|---------|
| **容器OOM** | cgroup限制 | 容器重启,OOMKilled | `OOMKilled` exitCode=137 |
| **节点OOM** | 系统内核 | 进程被kill | dmesg: `oom-killer` |
| **Pod驱逐** | kubelet | Pod被驱逐 | Evicted状态 |

## OOM诊断流程

```bash
# 1. 检查Pod状态
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].lastState}'

# 2. 检查Pod事件
kubectl describe pod <pod-name> | grep -A 5 "Last State"

# 3. 检查容器退出原因
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].lastState.terminated.reason}'

# 4. 检查节点内存
kubectl top nodes
kubectl describe node <node> | grep -A 5 "Allocated resources"

# 5. 检查节点dmesg日志(需SSH)
dmesg | grep -i "oom\|killed"
```

## 容器OOM诊断

```bash
# 检查容器内存限制
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].resources.limits.memory}'

# 检查实际内存使用
kubectl top pod <pod-name> --containers

# 检查内存使用历史(Prometheus)
# container_memory_usage_bytes{pod="<pod-name>"}

# 检查OOM事件
kubectl get events --field-selector reason=OOMKilled -A

# 容器内存详情
kubectl exec <pod-name> -- cat /sys/fs/cgroup/memory/memory.usage_in_bytes
kubectl exec <pod-name> -- cat /sys/fs/cgroup/memory/memory.limit_in_bytes
```

## 节点OOM诊断

```bash
# SSH到节点
ssh <node-ip>

# 检查系统内存
free -m
cat /proc/meminfo

# 检查OOM日志
dmesg | grep -i oom
journalctl -k | grep -i oom

# 找出内存占用最高的进程
ps aux --sort=-%mem | head -20

# 检查kubelet内存阈值
cat /var/lib/kubelet/config.yaml | grep -A 10 eviction
```

## 内存配置最佳实践

| 配置项 | 建议值 | 说明 |
|-------|-------|------|
| requests.memory | 实际使用的1.2倍 | 留有余量 |
| limits.memory | requests的1.5-2倍 | 允许突发 |
| limits/requests比 | 不超过2 | 避免过度超卖 |

```yaml
# 推荐的内存配置
apiVersion: v1
kind: Pod
metadata:
  name: memory-optimized
spec:
  containers:
  - name: app
    image: app:v1
    resources:
      requests:
        memory: "256Mi"   # 基于实际使用量
      limits:
        memory: "512Mi"   # requests的2倍
```

## JVM应用内存配置

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: java-app
spec:
  containers:
  - name: java
    image: java-app:v1
    env:
    # 容器感知内存设置
    - name: JAVA_OPTS
      value: >-
        -XX:+UseContainerSupport
        -XX:MaxRAMPercentage=75.0
        -XX:InitialRAMPercentage=50.0
        -XX:+HeapDumpOnOutOfMemoryError
        -XX:HeapDumpPath=/tmp/heapdump.hprof
    resources:
      requests:
        memory: "1Gi"
      limits:
        memory: "2Gi"
    volumeMounts:
    - name: heap-dumps
      mountPath: /tmp
  volumes:
  - name: heap-dumps
    emptyDir: {}
```

## Node内存驱逐阈值

```yaml
# kubelet配置
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
evictionHard:
  memory.available: "100Mi"      # 硬驱逐阈值
  nodefs.available: "10%"
  nodefs.inodesFree: "5%"
  imagefs.available: "15%"
evictionSoft:
  memory.available: "300Mi"      # 软驱逐阈值
  nodefs.available: "15%"
evictionSoftGracePeriod:
  memory.available: "1m"
  nodefs.available: "1m"
evictionPressureTransitionPeriod: 30s
```

## 内存问题预防

```yaml
# VPA自动调整内存
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: app
      minAllowed:
        memory: "128Mi"
      maxAllowed:
        memory: "4Gi"
      controlledResources: ["memory"]
```

## 监控告警

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: memory-alerts
spec:
  groups:
  - name: memory
    rules:
    - alert: ContainerOOMKilled
      expr: |
        increase(kube_pod_container_status_restarts_total[5m]) > 0
        and on (namespace, pod, container)
        kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1
      labels:
        severity: warning
      annotations:
        summary: "容器 {{ $labels.container }} OOM重启"
        
    - alert: ContainerMemoryHigh
      expr: |
        container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "容器内存使用超过90%"
        
    - alert: NodeMemoryHigh
      expr: |
        (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.85
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "节点 {{ $labels.instance }} 内存使用超过85%"
```

## 内存问题排查清单

| 检查项 | 命令 | 期望结果 |
|-------|------|---------|
| Pod内存使用 | `kubectl top pod` | 低于limits |
| 节点内存 | `kubectl top nodes` | 低于85% |
| OOM事件 | `kubectl get events` | 无OOMKilled |
| 容器重启 | `kubectl get pods` | RESTARTS=0 |
| 内存压力 | `kubectl describe node` | MemoryPressure=False |

---

**OOM防治原则**: 合理设置limits > 监控内存使用 > 配置VPA > JVM容器感知 > 设置驱逐阈值
