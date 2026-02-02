# Pod 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 中级

---

## 目录

1. [问题现象与影响分析](#1-问题现象与影响分析)
2. [排查方法与步骤](#2-排查方法与步骤)
3. [解决方案与风险控制](#3-解决方案与风险控制)

---

## 1. 问题现象与影响分析

### 1.1 Pod 状态问题

| 状态 | 说明 | 常见原因 | 查看方式 |
|------|------|----------|----------|
| **Pending** | 等待调度或资源 | 资源不足、节点选择器不匹配 | `kubectl describe pod` |
| **ContainerCreating** | 容器创建中 | 镜像拉取、卷挂载 | `kubectl describe pod` |
| **ImagePullBackOff** | 镜像拉取失败 | 镜像不存在、认证失败 | `kubectl describe pod` |
| **CrashLoopBackOff** | 容器反复崩溃 | 应用错误、配置错误 | `kubectl logs` |
| **Error** | 容器错误退出 | 应用异常 | `kubectl logs` |
| **OOMKilled** | 内存超限 | 内存限制过低 | `kubectl describe pod` |
| **Evicted** | 被驱逐 | 节点资源不足 | `kubectl describe pod` |
| **Terminating** | 正在终止 | 删除操作、finalizer | `kubectl get pod` |
| **Unknown** | 状态未知 | 节点通信问题 | `kubectl describe pod` |

### 1.2 报错查看方式汇总

```bash
# 查看 Pod 状态
kubectl get pods -o wide
kubectl get pods -o yaml

# 查看 Pod 事件
kubectl describe pod <pod-name>

# 查看容器日志
kubectl logs <pod-name>
kubectl logs <pod-name> -c <container-name>
kubectl logs <pod-name> --previous  # 查看崩溃前的日志

# 查看 Pod 资源使用
kubectl top pods

# 进入容器调试
kubectl exec -it <pod-name> -- sh

# 查看节点事件
kubectl get events --sort-by='.lastTimestamp'

# 查看 Pod 的 YAML 规格
kubectl get pod <pod-name> -o yaml
```

### 1.3 影响面分析

| 问题类型 | 影响范围 | 影响描述 |
|----------|----------|----------|
| Pod Pending | 服务可用性 | 新 Pod 无法启动，可能影响服务 |
| CrashLoopBackOff | 服务稳定性 | 服务反复重启，不稳定 |
| OOMKilled | 服务可用性 | 内存耗尽导致服务中断 |
| Evicted | 多个 Pod | 节点资源问题影响多个 Pod |

---

## 2. 排查方法与步骤

### 2.1 Pending 状态排查

```bash
# 步骤 1：查看 Pod 事件
kubectl describe pod <pod-name> | grep -A20 Events

# 步骤 2：根据事件判断原因
# 资源不足
# - "Insufficient cpu/memory"
# - "0/N nodes are available"

# 节点选择器不匹配
# - "didn't match node selector"
# - "node(s) had taints that the pod didn't tolerate"

# 步骤 3：检查资源请求
kubectl get pod <pod-name> -o yaml | grep -A10 resources

# 步骤 4：检查节点可用资源
kubectl describe nodes | grep -A10 "Allocated resources"
kubectl top nodes

# 步骤 5：检查节点选择器和亲和性
kubectl get pod <pod-name> -o yaml | grep -A20 nodeSelector
kubectl get pod <pod-name> -o yaml | grep -A30 affinity

# 步骤 6：检查污点和容忍
kubectl get nodes -o custom-columns='NAME:.metadata.name,TAINTS:.spec.taints'
kubectl get pod <pod-name> -o yaml | grep -A10 tolerations
```

### 2.2 ImagePullBackOff 排查

```bash
# 步骤 1：查看错误详情
kubectl describe pod <pod-name> | grep -A5 "Failed"

# 步骤 2：检查镜像名称
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].image}'

# 步骤 3：测试镜像拉取
crictl pull <image-name>

# 步骤 4：检查镜像仓库认证
kubectl get secrets -n <namespace> | grep -i registry
kubectl get pod <pod-name> -o yaml | grep -A5 imagePullSecrets

# 步骤 5：检查网络连通性
curl -v https://<registry-url>/v2/

# 步骤 6：如果是私有仓库，创建认证 Secret
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<password> \
  -n <namespace>
```

### 2.3 CrashLoopBackOff 排查

```bash
# 步骤 1：查看容器日志
kubectl logs <pod-name>
kubectl logs <pod-name> --previous

# 步骤 2：查看容器退出码
kubectl describe pod <pod-name> | grep -A5 "Last State"

# 常见退出码：
# 0: 正常退出
# 1: 应用错误
# 137: OOMKilled (128 + 9)
# 139: Segmentation fault (128 + 11)
# 143: SIGTERM (128 + 15)

# 步骤 3：检查容器命令
kubectl get pod <pod-name> -o yaml | grep -A5 command

# 步骤 4：检查环境变量
kubectl get pod <pod-name> -o yaml | grep -A50 env

# 步骤 5：检查配置文件挂载
kubectl get pod <pod-name> -o yaml | grep -A20 volumeMounts

# 步骤 6：进入容器调试（如果容器能运行）
kubectl exec -it <pod-name> -- sh

# 步骤 7：使用调试容器
kubectl debug <pod-name> -it --image=busybox --target=<container-name>
```

### 2.4 OOMKilled 排查

```bash
# 步骤 1：确认 OOMKilled
kubectl describe pod <pod-name> | grep -i oom

# 步骤 2：查看资源限制
kubectl get pod <pod-name> -o yaml | grep -A10 resources

# 步骤 3：查看实际内存使用
kubectl top pods
kubectl top pods --containers

# 步骤 4：分析内存使用趋势
# 使用 Prometheus/Grafana 查看历史数据

# 步骤 5：调整内存限制
kubectl patch deployment <deployment-name> -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "<container-name>",
          "resources": {
            "limits": {"memory": "512Mi"},
            "requests": {"memory": "256Mi"}
          }
        }]
      }
    }
  }
}'

# 步骤 6：验证调整
kubectl rollout status deployment <deployment-name>
```

### 2.5 Terminating 状态排查

```bash
# 步骤 1：查看 Pod 状态
kubectl get pod <pod-name> -o yaml | grep -A5 deletionTimestamp

# 步骤 2：检查 finalizers
kubectl get pod <pod-name> -o jsonpath='{.metadata.finalizers}'

# 步骤 3：检查容器是否响应 SIGTERM
kubectl logs <pod-name>

# 步骤 4：强制删除（如果卡住）
kubectl delete pod <pod-name> --grace-period=0 --force

# 步骤 5：如果仍然卡住，移除 finalizers
kubectl patch pod <pod-name> -p '{"metadata":{"finalizers":null}}'
```

---

## 3. 解决方案与风险控制

### 3.1 资源不足导致 Pending

#### 3.1.1 解决步骤

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

# 方案 2：清理资源
# 删除已完成的 Job
kubectl delete jobs --field-selector=status.successful=1

# 删除 Evicted Pod
kubectl delete pods --field-selector=status.phase=Failed

# 方案 3：扩容节点
# 使用 Cluster Autoscaler 或手动添加节点

# 方案 4：调整优先级
# 创建 PriorityClass
cat << EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
description: "High priority workloads"
EOF
```

#### 3.1.2 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 减少资源请求可能影响应用性能
2. 清理资源前确认不影响业务
3. 扩容节点需要评估成本
4. 优先级抢占可能影响其他 Pod
```

### 3.2 CrashLoopBackOff 解决

#### 3.2.1 常见原因和解决

```bash
# 原因 1：配置文件错误
# 检查 ConfigMap/Secret
kubectl get configmap <name> -o yaml
kubectl get secret <name> -o yaml

# 原因 2：环境变量缺失
# 检查所需环境变量
kubectl get pod <pod-name> -o yaml | grep -A50 env

# 原因 3：启动命令错误
# 修复命令
kubectl patch deployment <name> -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "<container>",
          "command": ["<correct-command>"],
          "args": ["<correct-args>"]
        }]
      }
    }
  }
}'

# 原因 4：依赖服务不可用
# 添加 init container 等待依赖
cat << EOF | kubectl apply -f -
spec:
  initContainers:
  - name: wait-for-service
    image: busybox
    command: ['sh', '-c', 'until nc -z <service> <port>; do sleep 2; done']
EOF

# 原因 5：健康检查过于严格
# 调整探针配置
kubectl patch deployment <name> -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "<container>",
          "livenessProbe": {
            "initialDelaySeconds": 60,
            "periodSeconds": 10,
            "timeoutSeconds": 5
          }
        }]
      }
    }
  }
}'
```

#### 3.2.2 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 修改启动命令需要充分测试
2. 调整探针可能延迟故障检测
3. 依赖服务问题应从根本解决
4. 应用日志是最重要的诊断信息
```

### 3.3 镜像拉取问题解决

#### 3.3.1 解决步骤

```bash
# 步骤 1：创建镜像仓库凭证
kubectl create secret docker-registry regcred \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email> \
  -n <namespace>

# 步骤 2：关联到 ServiceAccount
kubectl patch serviceaccount default -n <namespace> -p '{
  "imagePullSecrets": [{"name": "regcred"}]
}'

# 或者在 Pod spec 中指定
kubectl patch deployment <name> -p '{
  "spec": {
    "template": {
      "spec": {
        "imagePullSecrets": [{"name": "regcred"}]
      }
    }
  }
}'

# 步骤 3：如果是网络问题，配置镜像代理
# 修改 containerd 配置添加 mirror

# 步骤 4：验证镜像拉取
kubectl rollout restart deployment <name>
kubectl get pods -w
```

#### 3.3.2 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 镜像仓库凭证是敏感信息
2. 不要在命令历史中留下密码
3. 考虑使用云平台的凭证管理
4. 镜像代理可能有版本延迟
```

---

## 附录

### A. Pod 退出码参考

| 退出码 | 含义 | 常见原因 |
|--------|------|----------|
| 0 | 正常退出 | 任务完成 |
| 1 | 应用错误 | 代码异常 |
| 126 | 命令不可执行 | 权限问题 |
| 127 | 命令未找到 | 路径错误 |
| 137 | SIGKILL | OOMKilled |
| 139 | SIGSEGV | 段错误 |
| 143 | SIGTERM | 正常终止 |

### B. 常用调试命令

```bash
# 查看 Pod 详细信息
kubectl get pod <name> -o yaml

# 查看容器日志
kubectl logs <pod> -c <container> --tail=100 -f

# 查看之前容器的日志
kubectl logs <pod> --previous

# 进入容器
kubectl exec -it <pod> -- /bin/sh

# 调试容器
kubectl debug <pod> -it --image=busybox

# 复制文件
kubectl cp <pod>:/path/to/file ./local-file

# 端口转发
kubectl port-forward <pod> 8080:80
```

### C. 排查清单

- [ ] Pod 状态和事件
- [ ] 容器日志（当前和之前）
- [ ] 资源请求和限制
- [ ] 节点选择器和亲和性
- [ ] 镜像和镜像拉取凭证
- [ ] 环境变量和配置挂载
- [ ] 探针配置
- [ ] 依赖服务状态
