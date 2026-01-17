# 表格26: GPU调度与管理

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/tasks/manage-gpus](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/)

## GPU资源类型

| 资源类型 | 资源名称 | 供应商 | 版本支持 | ACK支持 | 说明 | 部署方式 |
|---------|---------|-------|---------|---------|------|---------|
| NVIDIA GPU | `nvidia.com/gpu` | NVIDIA | v1.8+ | ✅ | 通过Device Plugin暴露 | DaemonSet |
| AMD GPU | `amd.com/gpu` | AMD | v1.18+ | ⚠️ | 需手动部署插件 | DaemonSet |
| Intel GPU | `gpu.intel.com/i915` | Intel | v1.20+ | ⚠️ | 集成显卡支持 | DaemonSet |
| 虚拟GPU | `aliyun.com/gpu-mem` | 阿里云 | v1.20+ | ✅ | cGPU显存隔离 | ACK组件 |
| GPU份额 | `aliyun.com/gpu-core` | 阿里云 | v1.20+ | ✅ | cGPU算力隔离 | ACK组件 |
| MIG切片 | `nvidia.com/mig-1g.5gb` | NVIDIA | v1.22+ | ✅ | A100/A30 MIG | Device Plugin |
| 时间片共享 | `nvidia.com/gpu.shared` | NVIDIA | v1.25+ | ✅ | 时间片复用 | Time-Slicing |
| vGPU | `nvidia.com/vgpu` | NVIDIA | v1.22+ | ⚠️ | 虚拟化GPU | vGPU Manager |

## GPU调度策略

| 策略名称 | 实现方式 | 适用场景 | v1.25 | v1.28 | v1.32 | 资源利用率 |
|---------|---------|---------|-------|-------|-------|-----------|
| 独占调度 | 整卡分配 | 训练任务 | ✅ | ✅ | ✅ | 低(30-50%) |
| 共享调度 | 时间片复用 | 推理服务 | ✅ | ✅ | ✅ | 中(50-70%) |
| 显存隔离 | cGPU/vGPU | 混合部署 | ✅ | ✅ | ✅ | 高(70-90%) |
| MIG切片 | 硬件分区 | 多租户 | ✅ | ✅ | ✅ | 高(80-95%) |
| 拓扑感知 | NUMA亲和 | 分布式训练 | ✅ | ✅ | ✅ | 高 |
| Gang调度 | 原子调度 | 多GPU任务 | Coscheduler | Coscheduler | ✅原生 | N/A |

## NVIDIA Device Plugin配置

| 参数 | 默认值 | 推荐值 | 说明 |
|-----|-------|-------|------|
| `--mig-strategy` | none | mixed | MIG设备策略 |
| `--pass-device-specs` | false | true | 传递设备规格 |
| `--device-list-strategy` | envvar | volume-mounts | 设备列表传递方式 |
| `--device-id-strategy` | uuid | index | 设备ID策略 |
| `--nvidia-driver-root` | / | /run/nvidia/driver | 驱动根路径 |

## GPU Pod配置示例

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-training
spec:
  containers:
  - name: trainer
    image: nvcr.io/nvidia/pytorch:23.10-py3
    resources:
      limits:
        nvidia.com/gpu: 2  # 请求2块GPU
        # 或使用ACK cGPU:
        # aliyun.com/gpu-mem: 8  # 8GB显存
        # aliyun.com/gpu-core: 50  # 50%算力
    env:
    - name: NVIDIA_VISIBLE_DEVICES
      value: "all"
    - name: NVIDIA_DRIVER_CAPABILITIES
      value: "compute,utility"
  nodeSelector:
    accelerator: nvidia-tesla-v100
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
```

## GPU监控指标

| 指标名称 | 类型 | 来源 | 告警阈值 | 说明 |
|---------|-----|------|---------|------|
| `DCGM_FI_DEV_GPU_UTIL` | Gauge | DCGM | >95% 5min | GPU利用率 |
| `DCGM_FI_DEV_MEM_COPY_UTIL` | Gauge | DCGM | >90% | 显存带宽利用率 |
| `DCGM_FI_DEV_FB_USED` | Gauge | DCGM | >90% | 显存使用量 |
| `DCGM_FI_DEV_GPU_TEMP` | Gauge | DCGM | >80°C | GPU温度 |
| `DCGM_FI_DEV_POWER_USAGE` | Gauge | DCGM | >TDP*0.9 | 功耗 |
| `DCGM_FI_DEV_XID_ERRORS` | Counter | DCGM | >0 | XID错误计数 |
| `DCGM_FI_DEV_NVLINK_BANDWIDTH` | Gauge | DCGM | - | NVLink带宽 |

## ACK GPU实例类型

| 实例规格 | GPU型号 | GPU数量 | 显存 | 适用场景 | 按量价格参考 |
|---------|--------|--------|------|---------|-------------|
| ecs.gn6i-c4g1.xlarge | T4 | 1 | 16GB | 推理 | ¥8.5/小时 |
| ecs.gn6v-c8g1.2xlarge | V100 | 1 | 16GB | 训练 | ¥26/小时 |
| ecs.gn7i-c8g1.2xlarge | A10 | 1 | 24GB | 推理/训练 | ¥18/小时 |
| ecs.gn7e-c16g1.4xlarge | A100 | 1 | 80GB | 大模型 | ¥65/小时 |
| ecs.ebmgn7e.32xlarge | A100 | 8 | 640GB | 分布式训练 | ¥520/小时 |

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| v1.25 | Device Plugin API稳定(GA) |
| v1.26 | DRA (Dynamic Resource Allocation) Alpha |
| v1.27 | DRA结构化参数支持 |
| v1.28 | DRA Beta |
| v1.31 | DRA进入GA准备阶段 |
| v1.32 | ResourceClaim状态追踪增强 |

## NVIDIA Device Plugin部署

```yaml
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
      - name: nvidia-device-plugin-ctr
        image: nvcr.io/nvidia/k8s-device-plugin:v0.14.3
        env:
        - name: FAIL_ON_INIT_ERROR
          value: "false"
        - name: MIG_STRATEGY
          value: "mixed"  # none/single/mixed
        - name: DEVICE_LIST_STRATEGY
          value: "envvar"  # envvar/volume-mounts
        - name: PASS_DEVICE_SPECS
          value: "true"
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
        feature.node.kubernetes.io/pci-10de.present: "true"
```

## GPU时间片共享配置

```yaml
# NVIDIA GPU时间片共享ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: time-slicing-config
  namespace: kube-system
data:
  any: |-
    version: v1
    flags:
      migStrategy: none
    sharing:
      timeSlicing:
        renameByDefault: false
        failRequestsGreaterThanOne: false
        resources:
        - name: nvidia.com/gpu
          replicas: 4  # 每块GPU虚拟为4份
---
# 应用配置到Device Plugin
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin-daemonset
spec:
  template:
    spec:
      containers:
      - name: nvidia-device-plugin-ctr
        env:
        - name: CONFIG_FILE
          value: /etc/nvidia/time-slicing-config/any
        volumeMounts:
        - name: time-slicing-config
          mountPath: /etc/nvidia/time-slicing-config
      volumes:
      - name: time-slicing-config
        configMap:
          name: time-slicing-config
```

## MIG配置详解

| MIG Profile | GPU型号 | 显存 | SM数量 | 适用场景 |
|-------------|--------|------|--------|---------|
| 1g.5gb | A100-40G | 5GB | 14 | 小型推理 |
| 1g.10gb | A100-80G | 10GB | 14 | 推理服务 |
| 2g.10gb | A100-40G | 10GB | 28 | 中型任务 |
| 3g.20gb | A100-40G | 20GB | 42 | 训练/推理 |
| 4g.20gb | A100-40G | 20GB | 56 | 较大任务 |
| 7g.40gb | A100-40G | 40GB | 98 | 完整GPU |
| 7g.80gb | A100-80G | 80GB | 98 | 完整GPU |

```bash
# MIG配置命令
# 启用MIG模式
nvidia-smi -i 0 -mig 1

# 创建MIG实例
nvidia-smi mig -i 0 -cgi 9,9,9,9,9,9,9 -C

# 查看MIG配置
nvidia-smi mig -lgi
nvidia-smi mig -lci

# 销毁MIG实例
nvidia-smi mig -i 0 -dci
nvidia-smi mig -i 0 -dgi
```

## ACK cGPU配置

```yaml
# cGPU显存隔离Pod
apiVersion: v1
kind: Pod
metadata:
  name: cgpu-pod
spec:
  containers:
  - name: cuda-container
    image: nvidia/cuda:12.0-base
    resources:
      limits:
        # 请求4GB显存
        aliyun.com/gpu-mem: 4
      requests:
        aliyun.com/gpu-mem: 4
---
# cGPU算力+显存隔离
apiVersion: v1
kind: Pod
metadata:
  name: cgpu-full-isolation
spec:
  containers:
  - name: cuda-container
    image: nvidia/cuda:12.0-base
    resources:
      limits:
        aliyun.com/gpu-mem: 8   # 8GB显存
        aliyun.com/gpu-core: 50  # 50%算力
      requests:
        aliyun.com/gpu-mem: 8
        aliyun.com/gpu-core: 50
```

## GPU拓扑感知调度

```yaml
# 使用Topology Manager
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cpuManagerPolicy: static
topologyManagerPolicy: best-effort  # none/best-effort/restricted/single-numa-node
topologyManagerScope: container     # container/pod
reservedSystemCPUs: "0-1"
---
# GPU拓扑亲和Pod
apiVersion: v1
kind: Pod
metadata:
  name: gpu-topology-aware
spec:
  containers:
  - name: cuda
    image: nvidia/cuda:12.0-base
    resources:
      limits:
        nvidia.com/gpu: 2
        cpu: "8"
        memory: 32Gi
      requests:
        nvidia.com/gpu: 2
        cpu: "8"
        memory: 32Gi
  # 确保GPU在同一NUMA节点
  nodeSelector:
    nvidia.com/gpu.count: "8"
```

## Gang调度配置(Volcano)

```yaml
apiVersion: scheduling.volcano.sh/v1beta1
kind: PodGroup
metadata:
  name: distributed-training
spec:
  minMember: 4
  minResources:
    nvidia.com/gpu: 32
  queue: default
---
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: pytorch-distributed
spec:
  minAvailable: 4
  schedulerName: volcano
  plugins:
    ssh: []
    svc: []
  tasks:
  - replicas: 4
    name: worker
    template:
      spec:
        containers:
        - name: pytorch
          image: pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime
          command:
          - python
          - -m
          - torch.distributed.launch
          - --nproc_per_node=8
          - train.py
          resources:
            limits:
              nvidia.com/gpu: 8
        restartPolicy: OnFailure
```

## GPU故障诊断

| 问题 | 症状 | 诊断命令 | 解决方案 |
|-----|------|---------|---------|
| GPU不可见 | Pod无法请求GPU | `kubectl describe node \| grep nvidia` | 检查Device Plugin |
| XID错误 | 程序崩溃 | `nvidia-smi -q -d ECC,PAGE_RETIREMENT` | 检查GPU健康状态 |
| OOM | CUDA OOM | `nvidia-smi --query-gpu=memory.used --format=csv` | 减少批大小/使用梯度检查点 |
| 性能低 | 训练慢 | `nvidia-smi dmon` | 检查PCIe带宽/NVLink |
| 驱动不匹配 | 初始化失败 | `nvidia-smi` | 更新驱动或CUDA版本 |

```bash
# GPU诊断脚本
#!/bin/bash
echo "=== GPU状态 ==="
nvidia-smi

echo "=== GPU详细信息 ==="
nvidia-smi -q

echo "=== GPU进程 ==="
nvidia-smi pmon -s um -d 1 -c 5

echo "=== 节点GPU资源 ==="
kubectl describe node | grep -A 10 "Allocatable:" | grep nvidia

echo "=== GPU Pod ==="
kubectl get pods -A -o wide | grep -i gpu
```

## Prometheus GPU监控规则

```yaml
groups:
- name: gpu-alerts
  rules:
  - alert: GPUHighUtilization
    expr: DCGM_FI_DEV_GPU_UTIL > 95
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "GPU利用率过高"
      
  - alert: GPUHighTemperature
    expr: DCGM_FI_DEV_GPU_TEMP > 85
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "GPU温度过高"
      
  - alert: GPUMemoryAlmostFull
    expr: DCGM_FI_DEV_FB_USED / DCGM_FI_DEV_FB_FREE > 0.95
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "GPU显存即将耗尽"
      
  - alert: GPUXIDError
    expr: increase(DCGM_FI_DEV_XID_ERRORS[5m]) > 0
    labels:
      severity: critical
    annotations:
      summary: "检测到GPU XID错误"
```

## 最佳实践

| 场景 | 推荐配置 | 说明 |
|-----|---------|------|
| 训练任务 | 独占GPU + Gang调度 | 确保资源充足 |
| 推理服务 | 时间片/MIG共享 | 提高利用率 |
| 混合负载 | cGPU显存隔离 | 灵活分配 |
| 大模型 | 多GPU + NVLink | 高带宽互联 |
| 开发测试 | 共享GPU | 节省成本 |
