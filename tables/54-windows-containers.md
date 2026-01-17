# 表格54: Windows容器支持

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/windows](https://kubernetes.io/docs/concepts/windows/)

## Windows节点要求

| 要求 | 最低版本 | 说明 |
|-----|---------|------|
| Windows Server | 2019 LTSC | 长期支持版本 |
| Windows Server | 2022 LTSC | 推荐版本 |
| Docker/containerd | containerd 1.6+ | 容器运行时 |
| Kubernetes | v1.22+ | 稳定支持 |

## Windows容器类型

| 类型 | 隔离方式 | 性能 | 兼容性 |
|-----|---------|------|-------|
| Process | 进程隔离 | 高 | 需版本匹配 |
| Hyper-V | 虚拟机隔离 | 中 | 更好兼容性 |

## 支持的功能对比

| 功能 | Linux | Windows | 说明 |
|-----|-------|---------|------|
| Pod | ✅ | ✅ | 完全支持 |
| Service | ✅ | ✅ | ClusterIP/NodePort/LB |
| Deployment | ✅ | ✅ | 完全支持 |
| StatefulSet | ✅ | ✅ | 完全支持 |
| DaemonSet | ✅ | ✅ | 完全支持 |
| ConfigMap/Secret | ✅ | ✅ | 完全支持 |
| PersistentVolume | ✅ | ✅ | 部分CSI驱动 |
| hostPath | ✅ | ✅ | 路径格式不同 |
| emptyDir | ✅ | ✅ | 完全支持 |
| hostNetwork | ✅ | ❌ | 不支持 |
| hostPID | ✅ | ❌ | 不支持 |
| privileged | ✅ | ❌ | 不支持 |
| runAsUser | ✅ | ⚠️ | 有限支持 |
| seccomp | ✅ | ❌ | 不支持 |
| AppArmor | ✅ | ❌ | 不支持 |
| ResourceQuota | ✅ | ✅ | 完全支持 |
| HPA | ✅ | ✅ | 完全支持 |

## Windows节点配置

```yaml
apiVersion: v1
kind: Node
metadata:
  labels:
    kubernetes.io/os: windows
    node.kubernetes.io/windows-build: "10.0.17763"
spec:
  taints:
  - key: os
    value: windows
    effect: NoSchedule
```

## Windows Pod配置

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: windows-app
spec:
  nodeSelector:
    kubernetes.io/os: windows
  tolerations:
  - key: os
    value: windows
    effect: NoSchedule
  containers:
  - name: iis
    image: mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2022
    ports:
    - containerPort: 80
    resources:
      limits:
        cpu: "2"
        memory: 2Gi
      requests:
        cpu: "1"
        memory: 1Gi
```

## Windows Service配置

```yaml
apiVersion: v1
kind: Service
metadata:
  name: windows-service
spec:
  type: LoadBalancer
  selector:
    app: windows-app
  ports:
  - port: 80
    targetPort: 80
```

## 混合集群部署

```yaml
# Linux工作负载
apiVersion: apps/v1
kind: Deployment
metadata:
  name: linux-backend
spec:
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      nodeSelector:
        kubernetes.io/os: linux
      containers:
      - name: api
        image: myapi:latest
---
# Windows工作负载
apiVersion: apps/v1
kind: Deployment
metadata:
  name: windows-frontend
spec:
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      nodeSelector:
        kubernetes.io/os: windows
      tolerations:
      - key: os
        value: windows
        effect: NoSchedule
      containers:
      - name: aspnet
        image: mcr.microsoft.com/dotnet/aspnet:6.0-windowsservercore-ltsc2022
```

## Windows CNI支持

| CNI | 支持版本 | 网络模式 |
|-----|---------|---------|
| Flannel | v0.14+ | overlay/host-gw |
| Calico | v3.12+ | vxlan/BGP |
| Azure CNI | - | Azure原生 |

## Windows存储支持

| 存储类型 | 支持 | 说明 |
|---------|-----|------|
| emptyDir | ✅ | 完全支持 |
| hostPath | ✅ | Windows路径格式 |
| Azure Disk | ✅ | CSI驱动 |
| Azure File | ✅ | SMB协议 |
| AWS EBS | ⚠️ | 有限支持 |
| 本地PV | ✅ | 完全支持 |

## Windows镜像选择

| 基础镜像 | 大小 | 用途 |
|---------|-----|------|
| nanoserver | ~100MB | 最小镜像,.NET Core |
| servercore | ~2GB | 完整Windows Server |
| windows | ~4GB | 完整桌面体验 |

## Windows调试命令

```powershell
# 查看Windows节点
kubectl get nodes -l kubernetes.io/os=windows

# 进入Windows Pod
kubectl exec -it <pod-name> -- powershell

# 查看容器日志
kubectl logs <pod-name>

# 查看Windows事件
Get-EventLog -LogName Application -Newest 50
```

## ACK Windows节点池

| 功能 | 支持 |
|-----|------|
| Windows 2019 | ✅ |
| Windows 2022 | ✅ |
| 弹性伸缩 | ✅ |
| 混合集群 | ✅ |

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| v1.25 | Windows HostProcess容器GA |
| v1.26 | Windows特权容器改进 |
| v1.27 | Windows CSI代理改进 |
| v1.28 | Windows网络策略增强 |
