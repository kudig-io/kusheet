# 表格25：AI/ML工作负载表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/tasks/manage-gpus](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/)

## AI/ML框架与K8S集成

| 框架 | 用途 | K8S集成方式 | 版本要求 | ACK支持 |
|-----|------|------------|---------|---------|
| **Kubeflow** | ML平台 | Operator/CRD | v1.8+ | 支持 |
| **Ray** | 分布式计算 | Operator | v1.25+ | 支持 |
| **Volcano** | 批处理调度 | 调度器扩展 | v1.25+ | 支持 |
| **Arena** | CLI工具 | kubectl插件 | v1.25+ | 原生 |
| **Seldon** | 模型服务 | Operator | v1.25+ | - |
| **KServe** | 模型推理 | Operator | v1.25+ | 支持 |
| **MLflow** | 实验管理 | Deployment | v1.25+ | - |

## GPU调度

| 调度方式 | 描述 | 资源名 | 版本支持 | 适用场景 |
|---------|------|-------|---------|---------|
| **整卡调度** | 一个Pod一块GPU | nvidia.com/gpu | 稳定 | 独占需求 |
| **GPU共享** | 多Pod共享GPU | aliyun.com/gpu-mem | v1.25+ | 推理服务 |
| **MIG** | GPU多实例 | nvidia.com/mig-* | v1.25+ | 资源隔离 |
| **vGPU** | 虚拟化GPU | - | 取决于方案 | 多租户 |

```yaml
# GPU Pod示例
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  containers:
  - name: cuda
    image: nvidia/cuda:12.0-base
    resources:
      limits:
        nvidia.com/gpu: 1  # 请求1块GPU
    command: ["nvidia-smi"]
---
# GPU共享(ACK)
apiVersion: v1
kind: Pod
metadata:
  name: gpu-share-pod
spec:
  containers:
  - name: tensorflow
    image: tensorflow/tensorflow:latest-gpu
    resources:
      limits:
        aliyun.com/gpu-mem: 4  # 4GB GPU显存
```

## NVIDIA Device Plugin

```yaml
# NVIDIA Device Plugin DaemonSet
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin-daemonset
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: nvidia-device-plugin-ds
  template:
    metadata:
      labels:
        name: nvidia-device-plugin-ds
    spec:
      tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      containers:
      - name: nvidia-device-plugin-ctr
        image: nvcr.io/nvidia/k8s-device-plugin:v0.14.0
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
```

## 分布式训练

| 框架 | 分布式模式 | K8S资源 | 适用场景 |
|-----|-----------|---------|---------|
| **PyTorch DDP** | 数据并行 | PyTorchJob | 多GPU训练 |
| **Horovod** | Ring-AllReduce | MPIJob | 大规模训练 |
| **TensorFlow PS** | 参数服务器 | TFJob | 异步训练 |
| **DeepSpeed** | ZeRO优化 | PyTorchJob | 大模型训练 |
| **Megatron-LM** | 模型并行 | 自定义 | 超大模型 |

```yaml
# PyTorchJob分布式训练
apiVersion: kubeflow.org/v1
kind: PyTorchJob
metadata:
  name: pytorch-ddp-example
spec:
  pytorchReplicaSpecs:
    Master:
      replicas: 1
      restartPolicy: OnFailure
      template:
        spec:
          containers:
          - name: pytorch
            image: pytorch/pytorch:2.0.0-cuda11.7-cudnn8-runtime
            resources:
              limits:
                nvidia.com/gpu: 4
            command:
            - python
            - -m
            - torch.distributed.launch
            - --nproc_per_node=4
            - train.py
    Worker:
      replicas: 3
      restartPolicy: OnFailure
      template:
        spec:
          containers:
          - name: pytorch
            image: pytorch/pytorch:2.0.0-cuda11.7-cudnn8-runtime
            resources:
              limits:
                nvidia.com/gpu: 4
```

## 模型推理服务

| 服务方式 | 框架 | 特点 | 适用场景 |
|---------|------|------|---------|
| **KServe** | 标准推理 | 自动扩缩容，金丝雀 | 生产推理 |
| **Triton** | 高性能推理 | 多框架，批处理 | 高吞吐 |
| **TorchServe** | PyTorch推理 | 原生支持 | PyTorch模型 |
| **TF Serving** | TensorFlow推理 | 版本管理 | TF模型 |
| **Seldon** | 复杂推理 | 图执行，AB测试 | MLOps |

```yaml
# KServe InferenceService
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: sklearn-model
spec:
  predictor:
    sklearn:
      storageUri: s3://bucket/model
      resources:
        limits:
          cpu: "1"
          memory: 2Gi
        requests:
          cpu: "100m"
          memory: 1Gi
---
# GPU推理
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: llm-model
spec:
  predictor:
    pytorch:
      storageUri: s3://bucket/llm-model
      resources:
        limits:
          nvidia.com/gpu: 1
          memory: 32Gi
```

## Volcano批处理调度

| 功能 | 描述 | 配置方式 |
|-----|------|---------|
| **Gang调度** | 全部Pod就绪才调度 | minMember设置 |
| **队列管理** | 资源配额队列 | Queue CRD |
| **公平调度** | 多任务公平 | weight配置 |
| **抢占** | 高优先级抢占 | priority配置 |

```yaml
# Volcano Job
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: distributed-training
spec:
  minAvailable: 4
  schedulerName: volcano
  plugins:
    svc: []
    ssh: []
    env: []
  queue: default
  tasks:
  - name: worker
    replicas: 4
    template:
      spec:
        containers:
        - name: worker
          image: training:latest
          resources:
            limits:
              nvidia.com/gpu: 2
        restartPolicy: OnFailure
```

## AI工作负载资源规划

| 工作负载类型 | GPU需求 | 内存需求 | 存储需求 | 网络需求 |
|------------|--------|---------|---------|---------|
| **模型训练** | 高(多GPU) | 高 | 高(数据+检查点) | 高(分布式) |
| **模型微调** | 中 | 中-高 | 中 | 中 |
| **模型推理** | 低-中 | 中 | 低 | 中(延迟敏感) |
| **数据处理** | 低 | 中-高 | 高 | 中 |
| **实验开发** | 低-中 | 中 | 低 | 低 |

## ACK AI套件

| 功能 | 产品 | 用途 |
|-----|------|------|
| **GPU调度** | ACK GPU | 整卡/共享调度 |
| **分布式训练** | Arena | 训练任务管理 |
| **模型推理** | EAS | 模型服务 |
| **数据管理** | Fluid | 数据加速 |
| **实验管理** | PAI-DLC | 深度学习容器 |

```bash
# Arena训练提交
arena submit pytorch \
  --name=pytorch-dist \
  --gpus=4 \
  --workers=2 \
  --image=pytorch:latest \
  "python train.py --distributed"

# Arena查看
arena list
arena get pytorch-dist
arena logs pytorch-dist
```

## AI最佳实践

| 实践 | 说明 | 优先级 |
|-----|------|-------|
| **资源隔离** | 训练/推理分节点池 | P0 |
| **GPU监控** | DCGM指标监控 | P0 |
| **数据本地化** | 训练数据就近存储 | P1 |
| **检查点保存** | 定期保存训练状态 | P1 |
| **弹性训练** | 支持节点变化 | P2 |
| **混合精度** | 提高训练效率 | P2 |

---

**AI原则**: GPU高效利用，数据就近，弹性扩展
