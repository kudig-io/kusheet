# 表格70: RuntimeClass配置

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/containers/runtime-class](https://kubernetes.io/docs/concepts/containers/runtime-class/)

## RuntimeClass概述

| 字段 | 说明 |
|-----|------|
| `handler` | 运行时处理器名称(与CRI配置对应) |
| `overhead` | 运行时额外资源开销 |
| `scheduling` | 调度约束(nodeSelector/tolerations) |

## RuntimeClass配置

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
overhead:
  podFixed:
    cpu: "250m"
    memory: "120Mi"
scheduling:
  nodeSelector:
    runtime: gvisor
  tolerations:
  - key: runtime
    value: gvisor
    effect: NoSchedule
```

## 常用RuntimeClass

| 名称 | Handler | 用途 | 隔离级别 |
|-----|---------|------|---------|
| runc | runc | 默认运行时 | 进程隔离 |
| gvisor | runsc | 安全沙箱 | 内核隔离 |
| kata | kata-runtime | 轻量级VM | 虚拟化隔离 |
| nvidia | nvidia | GPU容器 | 进程隔离 |
| wasmedge | wasmedge | WebAssembly | Wasm沙箱 |

## containerd配置

```toml
# /etc/containerd/config.toml
version = 2

[plugins."io.containerd.grpc.v1.cri".containerd]
  default_runtime_name = "runc"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes]

  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
    runtime_type = "io.containerd.runc.v2"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
      SystemdCgroup = true

  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
    runtime_type = "io.containerd.runsc.v1"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc.options]
      TypeUrl = "io.containerd.runsc.v1.options"

  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata]
    runtime_type = "io.containerd.kata.v2"
    privileged_without_host_devices = true
```

## gVisor RuntimeClass

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
overhead:
  podFixed:
    cpu: "250m"
    memory: "120Mi"
---
# 使用gVisor的Pod
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  runtimeClassName: gvisor
  containers:
  - name: app
    image: nginx
    resources:
      limits:
        cpu: "1"
        memory: 512Mi
```

## Kata Containers RuntimeClass

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: kata
handler: kata-runtime
overhead:
  podFixed:
    cpu: "500m"
    memory: "160Mi"
scheduling:
  nodeSelector:
    kata-runtime: "true"
```

## 运行时对比

| 特性 | runc | gVisor | Kata |
|-----|------|--------|------|
| 启动时间 | <100ms | <500ms | 1-2s |
| 内存开销 | 0 | ~50MB | ~100MB |
| 系统调用兼容性 | 100% | ~90% | ~99% |
| 性能开销 | 0 | 5-30% | 10-20% |
| 安全隔离 | 低 | 高 | 最高 |
| 适用场景 | 通用 | 多租户 | 高安全 |

## NVIDIA RuntimeClass

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: nvidia
handler: nvidia
scheduling:
  nodeSelector:
    nvidia.com/gpu.present: "true"
---
# GPU Pod
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  runtimeClassName: nvidia
  containers:
  - name: cuda
    image: nvcr.io/nvidia/cuda:12.0-base
    resources:
      limits:
        nvidia.com/gpu: 1
```

## WebAssembly RuntimeClass

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: wasmedge
handler: wasmedge
overhead:
  podFixed:
    cpu: "50m"
    memory: "10Mi"
---
# Wasm Pod
apiVersion: v1
kind: Pod
metadata:
  name: wasm-app
spec:
  runtimeClassName: wasmedge
  containers:
  - name: wasm
    image: myregistry/wasm-app:v1
```

## 验证运行时

```bash
# 查看RuntimeClass
kubectl get runtimeclass

# 查看Pod使用的运行时
kubectl get pod <pod-name> -o jsonpath='{.spec.runtimeClassName}'

# 检查节点运行时
crictl info | jq '.config.containerd.runtimes'

# 测试运行时
kubectl run test --image=nginx --runtime-class=gvisor --rm -it -- cat /proc/version
```

## ACK运行时支持

| 运行时 | 支持状态 | 说明 |
|-------|---------|------|
| containerd | ✅ 默认 | 标准运行时 |
| 安全沙箱 | ✅ | 基于Kata的隔离 |
| 神龙裸金属 | ✅ | 高性能计算 |

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| v1.20 | RuntimeClass GA |
| v1.24 | RuntimeClass overhead改进 |
| v1.27 | 用户命名空间支持 |
| v1.29 | Wasm运行时支持改进 |
