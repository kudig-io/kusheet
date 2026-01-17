# 表格37：Pod生命周期事件表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)

## Pod阶段(Phase)

| 阶段 | 描述 | 触发条件 | 正常/异常 | 后续状态 |
|-----|------|---------|----------|---------|
| **Pending** | 已创建，等待调度或镜像拉取 | 创建Pod | 正常(短暂) | Running/Failed |
| **Running** | 至少一个容器运行中 | 容器启动成功 | 正常 | Succeeded/Failed |
| **Succeeded** | 所有容器成功终止 | Job完成 | 正常(Job) | 终态 |
| **Failed** | 所有容器终止，至少一个失败 | 容器退出非0 | 异常 | 终态 |
| **Unknown** | 无法获取Pod状态 | 节点通信失败 | 异常 | 取决于恢复 |

## 容器状态

| 状态 | 描述 | Reason字段 | 常见原因 |
|-----|------|-----------|---------|
| **Waiting** | 等待启动 | ContainerCreating | 拉取镜像 |
| | | ImagePullBackOff | 镜像拉取失败 |
| | | CrashLoopBackOff | 容器反复崩溃 |
| | | CreateContainerError | 容器创建失败 |
| | | ErrImagePull | 镜像拉取错误 |
| **Running** | 运行中 | - | 正常运行 |
| **Terminated** | 已终止 | Completed | 正常完成 |
| | | Error | 异常退出 |
| | | OOMKilled | 内存超限 |
| | | ContainerStatusUnknown | 状态未知 |

## Pod Condition

| Condition | True含义 | False含义 | 检查命令 |
|----------|---------|----------|---------|
| **PodScheduled** | 已调度到节点 | 调度中/失败 | `kubectl describe pod` |
| **Initialized** | Init容器完成 | Init未完成 | 检查init容器 |
| **ContainersReady** | 所有容器就绪 | 有容器未就绪 | 检查就绪探针 |
| **Ready** | Pod就绪，可接收流量 | Pod未就绪 | 检查所有条件 |
| **DisruptionTarget** | 将被驱逐 | 正常 | v1.25+ |

## 常见事件及处理

| 事件类型 | Event Reason | 描述 | 排查命令 | 解决方案 |
|---------|-------------|------|---------|---------|
| **调度** | FailedScheduling | 无法调度 | `kubectl describe pod` | 检查资源/污点/亲和性 |
| | Scheduled | 调度成功 | - | 正常 |
| **镜像** | Pulling | 拉取镜像中 | - | 等待 |
| | Pulled | 镜像拉取完成 | - | 正常 |
| | Failed | 拉取失败 | 检查镜像名和凭证 | 修复镜像配置 |
| **容器** | Created | 容器创建 | - | 正常 |
| | Started | 容器启动 | - | 正常 |
| | Killing | 容器终止中 | - | 正常 |
| | BackOff | 重启退避 | `kubectl logs --previous` | 修复应用问题 |
| **探针** | Unhealthy | 探针失败 | `kubectl describe pod` | 调整探针参数 |
| **资源** | FailedMount | 挂载失败 | 检查PV/Secret | 修复存储配置 |
| | NodeNotReady | 节点NotReady | `kubectl get nodes` | 修复节点 |
| **驱逐** | Evicted | Pod被驱逐 | `kubectl describe pod` | 调整资源/节点 |

## 事件查看命令

```bash
# 查看Pod事件
kubectl describe pod <pod-name>

# 使用events命令(v1.26+)
kubectl events --for pod/<pod-name>

# 查看所有事件
kubectl get events --sort-by='.lastTimestamp'

# 过滤Warning事件
kubectl get events --field-selector=type=Warning

# 查看特定命名空间事件
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# 持续监控事件
kubectl get events -w
```

## Pod重启原因分析

| 重启原因 | 诊断方法 | 常见原因 | 解决方案 |
|---------|---------|---------|---------|
| **OOMKilled** | `kubectl describe pod` | 内存超限 | 增加memory limits |
| **应用崩溃** | `kubectl logs --previous` | 应用bug | 修复应用 |
| **存活探针失败** | `kubectl describe pod` | 探针配置错误 | 调整探针参数 |
| **节点重启** | 节点事件 | 节点维护/故障 | 配置PDB |
| **抢占** | 事件 | 高优先级Pod抢占 | 调整优先级 |

## 探针配置最佳实践

| 探针类型 | 用途 | 默认值 | 推荐配置 |
|---------|------|-------|---------|
| **livenessProbe** | 容器是否存活 | 无 | 应用真正死锁时才失败 |
| **readinessProbe** | 是否就绪接收流量 | 无 | 应用可处理请求时成功 |
| **startupProbe** | 启动完成检查 | 无 | 慢启动应用使用 |

```yaml
# 探针配置示例
spec:
  containers:
  - name: app
    image: app:latest
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 3
    startupProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 0
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 30  # 最多等待5分钟启动
```

## Pod终止流程

| 步骤 | 操作 | 超时 | 配置 |
|-----|------|------|------|
| 1 | Pod标记为Terminating | - | - |
| 2 | 从Service Endpoints移除 | - | - |
| 3 | 执行preStop钩子 | terminationGracePeriodSeconds | lifecycle.preStop |
| 4 | 发送SIGTERM | - | - |
| 5 | 等待优雅终止 | terminationGracePeriodSeconds | spec.terminationGracePeriodSeconds |
| 6 | 发送SIGKILL | - | - |

```yaml
# 优雅终止配置
spec:
  terminationGracePeriodSeconds: 60  # 默认30s
  containers:
  - name: app
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh", "-c", "sleep 10 && kill -SIGTERM 1"]
```

## Pod驱逐场景

| 驱逐类型 | 触发条件 | 版本变更 | 预防措施 |
|---------|---------|---------|---------|
| **资源压力驱逐** | 内存/磁盘/PID压力 | v1.26增强 | 设置资源请求 |
| **节点维护** | kubectl drain | 稳定 | 配置PDB |
| **抢占驱逐** | 高优先级Pod抢占 | 稳定 | 使用适当优先级 |
| **污点驱逐** | 节点污点变化 | 稳定 | 配置容忍 |
| **API驱逐** | Eviction API调用 | 稳定 | 配置PDB |

## PDB配置

```yaml
# 保证最少可用数
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2  # 或使用百分比: "50%"
  selector:
    matchLabels:
      app: myapp
---
# 限制最大不可用数
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb-max
spec:
  maxUnavailable: 1  # 或 "25%"
  selector:
    matchLabels:
      app: myapp
```

## Pod状态监控

```bash
# 监控Pod状态变化
kubectl get pods -w

# 检查重启次数高的Pod
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.restartCount}{"\t"}{end}{"\n"}{end}' | awk '$3>5'

# 检查OOMKilled的Pod
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.lastState.terminated.reason}{"\t"}{end}{"\n"}{end}' | grep OOMKilled
```

---

**生命周期原则**: 正确配置探针，设置PDB，处理优雅终止
