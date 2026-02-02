# GPU 与设备插件故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32, NVIDIA Driver 470+, Device Plugin v0.13+ | **最后更新**: 2026-01 | **难度**: 高级
>
> **版本说明**:
> - v1.26+ DRA (Dynamic Resource Allocation) Alpha
> - v1.31+ DRA 进入 Beta
> - NVIDIA MIG 需要 Driver 450+ 和 Device Plugin v0.12+
> - 时间片共享需要 Device Plugin v0.13+

---

## 第一部分：问题现象与影响分析

### 1.1 Kubernetes 设备插件架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Kubernetes Node                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                        kubelet                               │   │
│   │  ┌──────────────────────────────────────────────────────┐   │   │
│   │  │            Device Plugin Manager                      │   │   │
│   │  │  - 监听 /var/lib/kubelet/device-plugins/             │   │   │
│   │  │  - 管理设备插件注册                                   │   │   │
│   │  │  - 处理设备分配请求                                   │   │   │
│   │  └──────────────────────────────────────────────────────┘   │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                       │
│              gRPC (Unix Socket)                                      │
│                              │                                       │
│   ┌──────────────────────────┴──────────────────────────────────┐   │
│   │                   Device Plugins                             │   │
│   │                                                              │   │
│   │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐ │   │
│   │  │  NVIDIA GPU    │  │  AMD GPU       │  │  RDMA/InfiniBand│ │   │
│   │  │  Plugin        │  │  Plugin        │  │  Plugin        │ │   │
│   │  │                │  │                │  │                │ │   │
│   │  │ nvidia.com/gpu │  │ amd.com/gpu    │  │ rdma/hca       │ │   │
│   │  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘ │   │
│   │          │                   │                   │          │   │
│   └──────────┼───────────────────┼───────────────────┼──────────┘   │
│              │                   │                   │              │
│   ┌──────────┴───────────────────┴───────────────────┴──────────┐   │
│   │                     Hardware Layer                          │   │
│   │  ┌────────────┐    ┌────────────┐    ┌────────────┐        │   │
│   │  │  NVIDIA    │    │  AMD       │    │  Mellanox  │        │   │
│   │  │  GPU Cards │    │  GPU Cards │    │  NICs      │        │   │
│   │  └────────────┘    └────────────┘    └────────────┘        │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

设备插件注册流程:
┌────────────┐    1. 启动并连接    ┌────────────┐
│   Device   │ ─────────────────> │   kubelet  │
│   Plugin   │                    │  (Manager) │
└────────────┘                    └────────────┘
      │                                  │
      │    2. Register(ResourceName)     │
      │ ─────────────────────────────>   │
      │                                  │
      │    3. ListAndWatch()             │
      │ <───────────────────────────     │
      │                                  │
      │    4. 返回设备列表               │
      │ ─────────────────────────────>   │
      │                                  │
      │    5. Allocate() on Pod request  │
      │ <───────────────────────────     │
      │                                  │
      │    6. 返回挂载/环境变量配置      │
      │ ─────────────────────────────>   │
      └──────────────────────────────────┘
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 错误信息 | 查看方式 |
|----------|----------|----------|----------|
| GPU 不可见 | Node 上看不到 GPU 资源 | Capacity 中无 nvidia.com/gpu | `kubectl describe node` |
| Pod 调度失败 | GPU Pod 一直 Pending | Insufficient nvidia.com/gpu | `kubectl describe pod` |
| 设备插件崩溃 | 插件 Pod CrashLoopBackOff | plugin registration failed | `kubectl logs` |
| 驱动问题 | 容器内无法使用 GPU | CUDA driver version insufficient | 应用日志 |
| 设备分配失败 | Pod 启动失败 | failed to allocate device | kubelet 日志 |
| 设备健康检查 | GPU 标记为 unhealthy | device marked as unhealthy | 插件日志 |
| 共享 GPU | 资源碎片化 | 无法精细分配 GPU 资源 | Node 资源状态 |
| MIG 问题 | MIG 设备不可用 | MIG mode enabled but no instances | nvidia-smi |

### 1.3 影响分析

| 问题类型 | 直接影响 | 间接影响 | 影响范围 |
|----------|----------|----------|----------|
| GPU 不可见 | ML 工作负载无法调度 | 模型训练/推理停滞 | 所有 GPU 工作负载 |
| 设备插件崩溃 | 新 Pod 无法获取 GPU | 已运行 Pod 不受影响 | 新调度的 Pod |
| 驱动不兼容 | CUDA 程序运行失败 | 应用崩溃 | 特定 CUDA 版本应用 |
| 设备分配失败 | Pod 启动失败 | 工作负载不可用 | 请求该设备的 Pod |

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
GPU/设备 Pod 问题
        │
        ▼
┌───────────────────┐
│  Pod 状态是什么？  │
└───────────────────┘
        │
        ├── Pending ──────────────────────────────────────┐
        │                                                  │
        │   ┌─────────────────────────────────────────┐   │
        │   │ 检查调度事件                            │   │
        │   │ kubectl describe pod <pod>              │   │
        │   └─────────────────────────────────────────┘   │
        │                  │                               │
        │                  ▼                               │
        │   ┌─────────────────────────────────────────┐   │
        │   │ Insufficient nvidia.com/gpu?            │   │
        │   └─────────────────────────────────────────┘   │
        │          │                │                      │
        │         是               否                      │
        │          │                │                      │
        │          ▼                ▼                      │
        │   ┌────────────┐   ┌────────────────┐           │
        │   │ 检查 Node  │   │ 检查其他资源   │           │
        │   │ GPU 容量   │   │ 或 affinity    │           │
        │   └────────────┘   └────────────────┘           │
        │          │                                       │
        │          ▼                                       │
        │   ┌─────────────────────────────────────────┐   │
        │   │ Node 有 GPU Capacity?                   │   │
        │   └─────────────────────────────────────────┘   │
        │          │                │                      │
        │         否               是                      │
        │          │                │                      │
        │          ▼                ▼                      │
        │   ┌────────────┐   ┌────────────────┐           │
        │   │ 设备插件   │   │ 检查已分配     │           │
        │   │ 问题       │   │ vs 可用数量    │           │
        │   └────────────┘   └────────────────┘           │
        │                                                  │
        ├── ContainerCreating ────────────────────────────┤
        │                                                  │
        │   ┌─────────────────────────────────────────┐   │
        │   │ 检查 kubelet 日志                       │   │
        │   │ journalctl -u kubelet | grep -i gpu     │   │
        │   └─────────────────────────────────────────┘   │
        │                  │                               │
        │                  ▼                               │
        │   ┌─────────────────────────────────────────┐   │
        │   │ device allocation 错误?                 │   │
        │   └─────────────────────────────────────────┘   │
        │          │                │                      │
        │         是               否                      │
        │          │                │                      │
        │          ▼                ▼                      │
        │   ┌────────────┐   ┌────────────────┐           │
        │   │ 设备插件   │   │ 检查其他容器   │           │
        │   │ Allocate   │   │ 启动问题       │           │
        │   │ 失败       │   │                │           │
        │   └────────────┘   └────────────────┘           │
        │                                                  │
        └── Running 但 GPU 不工作 ────────────────────────┤
                                                           │
            ┌─────────────────────────────────────────┐   │
            │ 容器内检查 nvidia-smi                   │   │
            │ kubectl exec <pod> -- nvidia-smi        │   │
            └─────────────────────────────────────────┘   │
                           │                               │
                           ▼                               │
            ┌─────────────────────────────────────────┐   │
            │ nvidia-smi 能否正常运行?                │   │
            └─────────────────────────────────────────┘   │
                   │                │                      │
                  否               是                      │
                   │                │                      │
                   ▼                ▼                      │
            ┌────────────┐   ┌────────────────┐           │
            │ 驱动/设备  │   │ 应用层 CUDA    │           │
            │ 挂载问题   │   │ 版本兼容问题   │           │
            └────────────┘   └────────────────┘           │
                                                           │
                                                           ▼
                                                    ┌────────────┐
                                                    │ 问题定位   │
                                                    │ 完成       │
                                                    └────────────┘
```

### 2.2 排查命令集

#### 设备插件状态检查

```bash
# 检查设备插件 DaemonSet 状态
kubectl get ds -n kube-system | grep -E "nvidia|gpu|device"

# 检查设备插件 Pod 状态
kubectl get pods -n kube-system -l app=nvidia-device-plugin-daemonset
kubectl get pods -n gpu-operator-resources

# 查看设备插件日志
kubectl logs -n kube-system -l app=nvidia-device-plugin-daemonset --tail=100

# 检查 NVIDIA GPU Operator 组件 (如果使用)
kubectl get pods -n gpu-operator -o wide
```

#### Node GPU 资源检查

```bash
# 查看节点 GPU 资源
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, capacity: .status.capacity, allocatable: .status.allocatable}' | grep -A5 -B1 gpu

# 详细查看单个节点
kubectl describe node <node-name> | grep -A10 "Capacity\|Allocatable\|Allocated"

# 查看 GPU 资源分配情况
kubectl get pods -A -o json | jq '.items[] | select(.spec.containers[].resources.limits."nvidia.com/gpu" != null) | {namespace: .metadata.namespace, name: .metadata.name, node: .spec.nodeName, gpu: .spec.containers[].resources.limits."nvidia.com/gpu"}'
```

#### 主机层 GPU 检查

```bash
# SSH 到 GPU 节点后执行

# NVIDIA GPU 状态
nvidia-smi

# 详细 GPU 信息
nvidia-smi -q

# GPU 进程
nvidia-smi pmon -c 1

# 驱动版本
cat /proc/driver/nvidia/version

# 检查 NVIDIA 设备文件
ls -la /dev/nvidia*

# 检查 NVIDIA 内核模块
lsmod | grep nvidia

# 检查设备插件 socket
ls -la /var/lib/kubelet/device-plugins/

# 检查容器运行时 GPU 配置
# containerd
cat /etc/containerd/config.toml | grep -A10 nvidia

# Docker
cat /etc/docker/daemon.json | jq '.runtimes'
```

#### kubelet 设备相关日志

```bash
# kubelet 设备插件相关日志
journalctl -u kubelet | grep -i "device\|plugin\|gpu\|nvidia" | tail -50

# 设备分配日志
journalctl -u kubelet | grep -i "allocate" | tail -20

# ListAndWatch 相关
journalctl -u kubelet | grep -i "ListAndWatch" | tail -20
```

### 2.3 排查注意事项

| 注意事项 | 说明 | 风险等级 |
|----------|------|----------|
| 不要随意重启设备插件 | 会影响正在运行的 GPU 工作负载的监控 | 中 |
| 驱动升级需要排空节点 | 升级驱动需要先迁移 GPU 工作负载 | 高 |
| MIG 配置变更需重启 | 更改 MIG 模式需要重启 GPU | 高 |
| 时间片配置谨慎调整 | 影响所有共享 GPU 的 Pod 性能 | 中 |
| 检查 CUDA 版本兼容性 | 驱动版本决定支持的最高 CUDA 版本 | 中 |

## 第三部分：解决方案与风险控制

### 3.1 设备插件未注册/不可用

**问题现象**：Node 上看不到 GPU 资源，`kubectl describe node` 中 Capacity 无 `nvidia.com/gpu`。

**解决步骤**：

```bash
# 步骤 1: 检查设备插件 DaemonSet 是否存在且运行正常
kubectl get ds -n kube-system nvidia-device-plugin-daemonset
kubectl get pods -n kube-system -l app=nvidia-device-plugin-daemonset -o wide

# 如果没有安装，部署 NVIDIA Device Plugin
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.0/nvidia-device-plugin.yml

# 步骤 2: 检查插件 Pod 日志
kubectl logs -n kube-system -l app=nvidia-device-plugin-daemonset

# 步骤 3: 在节点上检查基础设施
# SSH 到节点
nvidia-smi  # 确认驱动工作正常

# 检查设备插件 socket 目录
ls -la /var/lib/kubelet/device-plugins/

# 检查 nvidia 运行时是否配置
# 对于 containerd
cat /etc/containerd/config.toml | grep -A20 "\[plugins.*containerd.*runtimes.*nvidia\]"

# 步骤 4: 如果运行时未配置，配置 nvidia-container-runtime
# /etc/containerd/config.toml 添加:
```

**containerd 配置示例**：

```toml
# /etc/containerd/config.toml

version = 2

[plugins."io.containerd.grpc.v1.cri".containerd]
  default_runtime_name = "nvidia"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
  runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
  BinaryName = "/usr/bin/nvidia-container-runtime"
```

```bash
# 重启 containerd (需要排空节点上的工作负载)
systemctl restart containerd

# 步骤 5: 重启设备插件
kubectl delete pods -n kube-system -l app=nvidia-device-plugin-daemonset

# 步骤 6: 验证 GPU 资源出现
kubectl describe node <gpu-node> | grep -i nvidia
```

### 3.2 GPU Pod 调度失败 (Insufficient)

**问题现象**：GPU Pod 一直 Pending，事件显示 `Insufficient nvidia.com/gpu`。

**解决步骤**：

```bash
# 步骤 1: 检查集群 GPU 资源总量
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable."nvidia\.com/gpu"

# 步骤 2: 检查 GPU 资源使用情况
kubectl get pods -A -o json | jq -r '
  .items[] | 
  select(.spec.containers[].resources.limits."nvidia.com/gpu" != null) |
  [.metadata.namespace, .metadata.name, .spec.nodeName, 
   (.spec.containers[] | .resources.limits."nvidia.com/gpu" // "0")] | 
  @tsv' | column -t

# 步骤 3: 计算可用 GPU
# 总容量 - 已分配 = 可用

# 步骤 4: 如果资源不足，考虑以下选项:
# a. 等待其他 GPU 工作负载完成
# b. 添加更多 GPU 节点
# c. 使用 GPU 共享方案 (MIG, 时间片)
# d. 优化请求的 GPU 数量
```

**检查 Pod 是否请求过多 GPU**：

```yaml
# 检查 Pod 配置
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  containers:
  - name: cuda-container
    image: nvidia/cuda:12.0-runtime
    resources:
      limits:
        nvidia.com/gpu: 1  # 确认是否真的需要这么多
```

### 3.3 设备插件 Allocate 失败

**问题现象**：Pod 在 ContainerCreating 状态卡住，kubelet 日志显示 allocate 失败。

**解决步骤**：

```bash
# 步骤 1: 查看 kubelet 日志定位具体错误
journalctl -u kubelet | grep -i "allocate\|device" | tail -50

# 步骤 2: 检查设备插件健康状态
kubectl logs -n kube-system -l app=nvidia-device-plugin-daemonset | grep -i "health\|error\|fail"

# 步骤 3: 在节点上检查 GPU 设备状态
nvidia-smi -q | grep -A5 "GPU Current Temp\|Power Draw\|ECC"

# 步骤 4: 检查设备文件权限
ls -la /dev/nvidia*

# 步骤 5: 如果设备不健康，可能需要:
# a. 重置 GPU
nvidia-smi --gpu-reset -i 0  # 危险操作，会影响使用该 GPU 的所有进程

# b. 检查硬件问题
nvidia-smi -q | grep -i "retired\|error"

# 步骤 6: 重启设备插件刷新设备列表
kubectl delete pods -n kube-system -l app=nvidia-device-plugin-daemonset
```

### 3.4 容器内 GPU 不可用

**问题现象**：Pod 运行中，但容器内 `nvidia-smi` 失败或 CUDA 程序报错。

**解决步骤**：

```bash
# 步骤 1: 进入容器检查
kubectl exec -it <pod-name> -- bash

# 容器内执行
nvidia-smi
# 如果失败，检查设备是否挂载
ls -la /dev/nvidia*

# 检查环境变量
env | grep -i nvidia
env | grep -i cuda

# 步骤 2: 检查 Pod 配置是否正确请求了 GPU
kubectl get pod <pod-name> -o yaml | grep -A10 resources

# 步骤 3: 检查容器运行时是否正确配置
# 在节点上
crictl inspect <container-id> | grep -i nvidia

# 步骤 4: 如果环境变量缺失，检查设备插件配置
# 设备插件应该返回正确的环境变量
```

**正确的 GPU Pod 配置示例**：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  restartPolicy: OnFailure
  containers:
  - name: cuda-test
    image: nvidia/cuda:12.0-base-ubuntu22.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1  # 必须在 limits 中指定
```

### 3.5 CUDA 版本不兼容

**问题现象**：应用报错 `CUDA driver version is insufficient for CUDA runtime version`。

**解决步骤**：

```bash
# 步骤 1: 检查节点驱动版本支持的 CUDA 版本
nvidia-smi  # 右上角显示支持的最高 CUDA 版本

# 步骤 2: 检查应用使用的 CUDA 版本
kubectl exec <pod-name> -- cat /usr/local/cuda/version.txt
# 或
kubectl exec <pod-name> -- nvcc --version

# 步骤 3: 确认兼容性
# NVIDIA 驱动版本与 CUDA 版本对应关系:
# https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html

# 步骤 4: 解决方案
# a. 升级节点驱动 (需要排空节点)
# b. 使用较低版本的 CUDA 镜像
```

**版本兼容性参考**：

| CUDA Version | Minimum Driver Version |
|--------------|------------------------|
| CUDA 12.x    | >= 525.60.13           |
| CUDA 11.8    | >= 520.61.05           |
| CUDA 11.7    | >= 515.43.04           |
| CUDA 11.6    | >= 510.39.01           |

### 3.6 MIG (Multi-Instance GPU) 问题

**问题现象**：MIG 模式启用但设备不可用，或 MIG 实例不符合预期。

**解决步骤**：

```bash
# 步骤 1: 检查 GPU 是否支持 MIG (A100, A30, H100 等)
nvidia-smi -q | grep "MIG Mode"

# 步骤 2: 查看当前 MIG 配置
nvidia-smi mig -lgi  # 列出 GPU Instances
nvidia-smi mig -lci  # 列出 Compute Instances

# 步骤 3: 如果需要重新配置 MIG
# 首先排空节点上的 GPU 工作负载
kubectl drain <node> --ignore-daemonsets

# 启用 MIG 模式 (需要重启)
nvidia-smi -mig 1 -i 0

# 重启节点或重置 GPU
# 重启后创建 MIG 实例
nvidia-smi mig -cgi 9,9,9,9,9,9,9 -i 0  # 创建 7 个 1g.5gb 实例
nvidia-smi mig -cci -i 0  # 创建计算实例

# 步骤 4: 验证 MIG 设备
nvidia-smi -L

# 步骤 5: 重启设备插件以发现新的 MIG 设备
kubectl delete pods -n kube-system -l app=nvidia-device-plugin-daemonset

# 步骤 6: 恢复节点
kubectl uncordon <node>
```

**MIG 设备请求示例**：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mig-pod
spec:
  containers:
  - name: mig-container
    image: nvidia/cuda:12.0-runtime
    resources:
      limits:
        # MIG 设备资源名称格式
        nvidia.com/mig-1g.5gb: 1  # 请求 1 个 1g.5gb MIG 实例
```

### 3.7 GPU 时间片共享问题

**问题现象**：使用时间片共享时性能下降或调度异常。

**配置时间片共享**：

```yaml
# NVIDIA Device Plugin ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: nvidia-device-plugin-config
  namespace: kube-system
data:
  config.yaml: |
    version: v1
    sharing:
      timeSlicing:
        renameByDefault: false
        failRequestsGreaterThanOne: false
        resources:
        - name: nvidia.com/gpu
          replicas: 4  # 每个 GPU 虚拟成 4 个
```

**解决步骤**：

```bash
# 步骤 1: 应用时间片配置
kubectl apply -f nvidia-device-plugin-config.yaml

# 步骤 2: 重启设备插件使配置生效
kubectl rollout restart ds/nvidia-device-plugin-daemonset -n kube-system

# 步骤 3: 验证虚拟 GPU 数量
kubectl describe node <gpu-node> | grep nvidia.com/gpu
# 应该看到 Capacity 变成原来的 4 倍

# 步骤 4: 监控时间片使用情况
# 时间片共享会导致 GPU 利用率显示异常，需要关注实际性能
```

### 3.8 RDMA/InfiniBand 设备问题

**问题现象**：高性能网络设备不可用，分布式训练性能差。

**解决步骤**：

```bash
# 步骤 1: 检查 RDMA 设备插件
kubectl get ds -n kube-system | grep rdma

# 步骤 2: 在节点上检查 RDMA 设备
ibstat
ibv_devices
rdma link

# 步骤 3: 检查节点资源
kubectl describe node <node> | grep -i rdma

# 步骤 4: 部署 RDMA 设备插件 (如果未部署)
# 以 k8s-rdma-shared-dev-plugin 为例
kubectl apply -f https://raw.githubusercontent.com/Mellanox/k8s-rdma-shared-dev-plugin/master/images/k8s-rdma-shared-dev-plugin-ds.yaml
```

**RDMA Pod 配置示例**：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: rdma-pod
spec:
  containers:
  - name: rdma-container
    image: your-rdma-app
    resources:
      limits:
        rdma/hca_shared_devices_a: 1  # RDMA 设备资源
        nvidia.com/gpu: 1             # GPU 设备
    securityContext:
      capabilities:
        add: ["IPC_LOCK"]  # RDMA 需要的能力
```

### 3.9 安全生产风险提示

| 操作 | 风险等级 | 潜在风险 | 建议措施 |
|------|----------|----------|----------|
| 升级 GPU 驱动 | 高 | 所有 GPU 工作负载中断 | 排空节点，灰度升级 |
| 重置 GPU (`nvidia-smi --gpu-reset`) | 高 | 杀死所有使用该 GPU 的进程 | 确保无运行工作负载 |
| 修改 MIG 配置 | 高 | 需要重启，影响所有 GPU Pod | 排空节点后操作 |
| 重启设备插件 | 中 | 新 Pod 短时无法调度 | 选择低峰期 |
| 修改时间片配置 | 中 | 影响 GPU 资源计算和调度 | 充分测试后上线 |
| 修改容器运行时配置 | 中 | 需重启 containerd | 排空节点后操作 |

### 附录：快速诊断命令

```bash
# ===== 一键诊断脚本 =====

echo "=== GPU Node 状态 ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable."nvidia\.com/gpu"

echo -e "\n=== 设备插件状态 ==="
kubectl get pods -n kube-system -l app=nvidia-device-plugin-daemonset -o wide

echo -e "\n=== GPU Pod 分布 ==="
kubectl get pods -A -o json | jq -r '
  .items[] | 
  select(.spec.containers[].resources.limits."nvidia.com/gpu" != null) |
  [.metadata.namespace, .metadata.name, .spec.nodeName, .status.phase] | 
  @tsv' | column -t

echo -e "\n=== Pending GPU Pods ==="
kubectl get pods -A --field-selector=status.phase=Pending -o json | jq -r '
  .items[] | 
  select(.spec.containers[].resources.limits."nvidia.com/gpu" != null) |
  [.metadata.namespace, .metadata.name] | 
  @tsv'

echo -e "\n=== 设备插件日志 (最近 10 条) ==="
kubectl logs -n kube-system -l app=nvidia-device-plugin-daemonset --tail=10 2>/dev/null || echo "无法获取日志"

# ===== 节点级检查 (需要 SSH 到节点) =====
# nvidia-smi
# ls -la /var/lib/kubelet/device-plugins/
# journalctl -u kubelet | grep -i gpu | tail -20
```

### 附录：常用设备插件部署

```yaml
# NVIDIA Device Plugin (标准部署)
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin-daemonset
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: nvidia-device-plugin-ds
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        name: nvidia-device-plugin-ds
    spec:
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      priorityClassName: system-node-critical
      containers:
      - image: nvcr.io/nvidia/k8s-device-plugin:v0.14.0
        name: nvidia-device-plugin-ctr
        env:
        - name: FAIL_ON_INIT_ERROR
          value: "false"
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - name: device-plugin
          mountPath: /var/lib/kubelet/device-plugins
      volumes:
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/device-plugins
      nodeSelector:
        # 只在有 GPU 的节点上运行
        nvidia.com/gpu.present: "true"
```
