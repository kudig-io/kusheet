# 资源与调度故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 中级

---

## 目录

1. [问题现象与影响分析](#1-问题现象与影响分析)
2. [排查方法与步骤](#2-排查方法与步骤)
3. [解决方案与风险控制](#3-解决方案与风险控制)

---

## 1. 问题现象与影响分析

### 1.1 资源配额问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 超出配额 | `exceeded quota` | kubectl | `kubectl describe quota` |
| Pod 创建被拒绝 | `forbidden: exceeded quota` | API Server | kubectl/Pod Events |
| LimitRange 违规 | `must be less than or equal to cpu/memory limit` | API Server | kubectl |
| PVC 配额超限 | `persistentvolumeclaims count limit exceeded` | API Server | kubectl |

### 1.2 OOM 问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 容器 OOMKilled | `OOMKilled` | kubectl | `kubectl describe pod` |
| 节点 OOM | `system OOM` | 系统日志 | `dmesg` |
| 内存压力 | `MemoryPressure` | 节点状态 | `kubectl describe node` |
| cgroup OOM | `Memory cgroup out of memory` | 系统日志 | `dmesg` |

### 1.3 调度失败问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 资源不足 | `Insufficient cpu/memory` | Pod Events | `kubectl describe pod` |
| 节点不可调度 | `0/N nodes are available` | Pod Events | `kubectl describe pod` |
| 亲和性不满足 | `didn't match node affinity` | Pod Events | `kubectl describe pod` |
| PVC 未绑定 | `unbound immediate PersistentVolumeClaims` | Pod Events | `kubectl describe pod` |

### 1.4 报错查看方式汇总

```bash
# 查看 ResourceQuota
kubectl get resourcequota -A
kubectl describe resourcequota <quota-name> -n <namespace>

# 查看 LimitRange
kubectl get limitrange -A
kubectl describe limitrange <lr-name> -n <namespace>

# 查看节点资源
kubectl describe nodes | grep -A10 "Allocated resources"
kubectl top nodes
kubectl top pods

# 查看 Pod 资源配置
kubectl get pod <pod-name> -o yaml | grep -A15 resources

# 查看 OOM 日志
kubectl describe pod <pod-name> | grep -i oom
dmesg | grep -i "oom\|killed"

# 查看调度失败原因
kubectl describe pod <pod-name> | grep -A10 Events
```

### 1.5 影响面分析

| 问题类型 | 影响范围 | 影响描述 |
|----------|----------|----------|
| 配额超限 | 命名空间 | 新资源无法创建 |
| OOMKilled | 单个 Pod | 容器被杀死，可能反复重启 |
| 节点 OOM | 整个节点 | 节点上多个 Pod 被杀死 |
| 调度失败 | 新 Pod | Pod 长期 Pending |

---

## 2. 排查方法与步骤

### 2.1 ResourceQuota 排查

```bash
# 步骤 1：查看命名空间配额使用情况
kubectl get resourcequota -n <namespace>
kubectl describe resourcequota <quota-name> -n <namespace>

# 输出示例：
# Name:            compute-quota
# Namespace:       default
# Resource         Used    Hard
# --------         ----    ----
# limits.cpu       4       8
# limits.memory    4Gi     16Gi
# pods             10      20
# requests.cpu     2       4
# requests.memory  2Gi     8Gi

# 步骤 2：检查哪些资源占用了配额
kubectl get pods -n <namespace> -o json | \
  jq -r '.items[] | "\(.metadata.name): CPU=\(.spec.containers[].resources.requests.cpu // "none"), MEM=\(.spec.containers[].resources.requests.memory // "none")"'

# 步骤 3：检查 LimitRange 约束
kubectl get limitrange -n <namespace>
kubectl describe limitrange <lr-name> -n <namespace>

# 步骤 4：计算当前使用量
kubectl get pods -n <namespace> -o json | \
  jq '[.items[].spec.containers[].resources.requests.memory // "0" | gsub("Mi"; "") | gsub("Gi"; "000") | tonumber] | add'
```

### 2.2 OOM 排查

```bash
# 步骤 1：确认 OOM 事件
kubectl describe pod <pod-name> | grep -i "oom\|killed"

# 步骤 2：查看容器退出状态
kubectl get pod <pod-name> -o yaml | grep -A10 "lastState:"

# 步骤 3：检查资源限制
kubectl get pod <pod-name> -o yaml | grep -A15 resources

# 步骤 4：查看实际内存使用
kubectl top pods
kubectl top pods --containers

# 步骤 5：查看节点内存状态
kubectl describe node <node-name> | grep -A5 "Allocated resources"
free -h  # 在节点上执行

# 步骤 6：查看系统 OOM 日志
dmesg | grep -i "oom\|killed" | tail -20

# 步骤 7：分析内存使用趋势
# 使用 Prometheus 查询
# container_memory_usage_bytes{pod="<pod-name>"}
```

### 2.3 调度失败排查

```bash
# 步骤 1：查看调度失败原因
kubectl describe pod <pod-name> | grep -A20 Events

# 步骤 2：检查资源请求
kubectl get pod <pod-name> -o yaml | grep -A10 resources

# 步骤 3：检查节点可用资源
kubectl describe nodes | grep -A10 "Allocated resources"

# 步骤 4：检查节点选择器
kubectl get pod <pod-name> -o yaml | grep -A5 nodeSelector
kubectl get nodes --show-labels

# 步骤 5：检查亲和性配置
kubectl get pod <pod-name> -o yaml | grep -A30 affinity

# 步骤 6：检查污点和容忍
kubectl get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints'
kubectl get pod <pod-name> -o yaml | grep -A10 tolerations

# 步骤 7：使用调度器日志分析
kubectl logs -n kube-system -l component=kube-scheduler | grep <pod-name>
```

---

## 3. 解决方案与风险控制

### 3.1 ResourceQuota 超限解决

#### 3.1.1 解决步骤

```bash
# 方案 1：增加配额
kubectl patch resourcequota <quota-name> -n <namespace> -p '{
  "spec": {
    "hard": {
      "limits.cpu": "16",
      "limits.memory": "32Gi",
      "pods": "40"
    }
  }
}'

# 方案 2：清理不需要的资源
# 删除已完成的 Job
kubectl delete jobs --field-selector=status.successful=1 -n <namespace>

# 删除 Evicted Pod
kubectl delete pods --field-selector=status.phase=Failed -n <namespace>

# 方案 3：优化资源请求
# 减少不必要的资源请求
kubectl patch deployment <name> -n <namespace> -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "<container>",
          "resources": {
            "requests": {"cpu": "100m", "memory": "128Mi"},
            "limits": {"cpu": "500m", "memory": "512Mi"}
          }
        }]
      }
    }
  }
}'

# 方案 4：创建新的 ResourceQuota（如需分配更多资源）
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: expanded-quota
  namespace: <namespace>
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
    pods: "50"
    persistentvolumeclaims: "10"
EOF
```

#### 3.1.2 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 增加配额前评估集群容量
2. 配额是多租户隔离的重要手段
3. 清理资源前确认不影响业务
4. 减少资源请求可能影响应用性能
5. 定期审计配额使用情况
```

### 3.2 OOM 问题解决

#### 3.2.1 解决步骤

```bash
# 方案 1：增加内存限制
kubectl patch deployment <name> -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "<container>",
          "resources": {
            "requests": {"memory": "512Mi"},
            "limits": {"memory": "1Gi"}
          }
        }]
      }
    }
  }
}'

# 方案 2：优化应用内存使用
# Java 应用示例 - 设置 JVM 参数
env:
- name: JAVA_OPTS
  value: "-Xms256m -Xmx512m -XX:+UseG1GC"

# 方案 3：使用 VPA（Vertical Pod Autoscaler）
cat << EOF | kubectl apply -f -
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: <vpa-name>
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: <deployment-name>
  updatePolicy:
    updateMode: "Auto"
EOF

# 方案 4：设置内存 QoS
# Guaranteed: requests = limits
# Burstable: requests < limits
# BestEffort: 无 requests/limits（不推荐）

# 方案 5：配置节点驱逐阈值
# 在 kubelet 配置中调整
# evictionHard:
#   memory.available: "100Mi"
# evictionSoft:
#   memory.available: "200Mi"
```

#### 3.2.2 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 内存限制过高可能影响节点稳定性
2. 内存限制过低会导致频繁 OOM
3. VPA 自动调整需要监控效果
4. JVM 应用注意堆外内存
5. 监控内存使用趋势，提前扩容
```

### 3.3 调度失败解决

#### 3.3.1 资源不足解决

```bash
# 方案 1：减少资源请求
kubectl patch deployment <name> -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "<container>",
          "resources": {
            "requests": {"cpu": "50m", "memory": "64Mi"}
          }
        }]
      }
    }
  }
}'

# 方案 2：扩容节点
# 使用 Cluster Autoscaler
kubectl get pods -n kube-system | grep cluster-autoscaler

# 或手动添加节点

# 方案 3：使用优先级抢占
cat << EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
EOF

# 在 Pod 中使用
spec:
  priorityClassName: high-priority

# 方案 4：调整节点亲和性
# 从 required 改为 preferred
kubectl patch deployment <name> -p '{
  "spec": {
    "template": {
      "spec": {
        "affinity": {
          "nodeAffinity": {
            "preferredDuringSchedulingIgnoredDuringExecution": [{
              "weight": 100,
              "preference": {
                "matchExpressions": [{
                  "key": "node-type",
                  "operator": "In",
                  "values": ["compute"]
                }]
              }
            }]
          }
        }
      }
    }
  }
}'
```

#### 3.3.2 污点容忍问题解决

```bash
# 添加容忍
kubectl patch deployment <name> -p '{
  "spec": {
    "template": {
      "spec": {
        "tolerations": [{
          "key": "node-role.kubernetes.io/master",
          "operator": "Exists",
          "effect": "NoSchedule"
        }]
      }
    }
  }
}'

# 或移除节点污点（如果合适）
kubectl taint nodes <node-name> <taint-key>-
```

#### 3.3.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 减少资源请求可能导致资源争抢
2. 优先级抢占可能影响低优先级 Pod
3. 添加容忍需要评估安全影响
4. 移除污点可能导致不合适的调度
5. 集群扩容需要评估成本
```

### 3.4 LimitRange 配置

```bash
# 创建 LimitRange 设置默认值
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: <namespace>
spec:
  limits:
  - default:  # 默认 limits
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:  # 默认 requests
      cpu: "100m"
      memory: "128Mi"
    max:  # 最大值
      cpu: "2"
      memory: "2Gi"
    min:  # 最小值
      cpu: "50m"
      memory: "64Mi"
    type: Container
EOF
```

---

## 附录

### A. 资源单位换算

| CPU | 说明 |
|-----|------|
| 1 | 1 核 CPU |
| 100m | 0.1 核 CPU |
| 1000m | 1 核 CPU |

| 内存 | 说明 |
|------|------|
| 128Mi | 128 MiB |
| 1Gi | 1 GiB |
| 1G | 1 GB (10^9 bytes) |

### B. QoS 等级

| QoS 等级 | 条件 | OOM 优先级 |
|----------|------|------------|
| Guaranteed | requests = limits | 最后被杀 |
| Burstable | requests < limits | 中等 |
| BestEffort | 无 requests/limits | 最先被杀 |

### C. 排查清单

- [ ] ResourceQuota 使用情况
- [ ] LimitRange 配置
- [ ] Pod 资源请求和限制
- [ ] 节点可用资源
- [ ] 节点选择器和亲和性
- [ ] 污点和容忍
- [ ] PVC 绑定状态
- [ ] 调度器日志
