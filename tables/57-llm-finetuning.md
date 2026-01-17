# 表格57: LLM模型微调配置

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: Kubeflow Training Operator, PyTorch Distributed

## 微调方法对比

| 方法 | 参数量 | 显存需求 | 训练速度 | 精度保留 | 适用场景 | 框架支持 |
|-----|-------|---------|---------|---------|---------|---------|
| 全参数微调 | 100% | 极高(16x模型大小) | 慢 | 最高 | 小模型/充足资源 | 所有框架 |
| LoRA | 0.1-1% | 低(1.2x模型大小) | 快 | 高 | 通用微调 | PEFT/LoRAX |
| QLoRA | 0.1-1% | 极低(0.5x模型大小) | 中 | 高 | 资源受限 | PEFT+bitsandbytes |
| Prefix Tuning | <1% | 低 | 快 | 中 | 特定任务 | PEFT |
| P-Tuning v2 | <1% | 低 | 快 | 中 | NLU任务 | PEFT |
| Adapter | 1-5% | 中 | 中 | 高 | 多任务 | AdapterHub |
| DoRA | 0.1-1% | 低 | 快 | 高(优于LoRA) | 通用微调 | PEFT 0.8+ |
| LoRA+ | 0.1-1% | 低 | 快 | 高 | 优化学习率 | 自定义 |

## 显存需求估算

| 模型规模 | 全参数(FP16) | LoRA(FP16) | QLoRA(4bit) | 推理(FP16) |
|---------|-------------|------------|-------------|-----------|
| 7B | 112GB | 16GB | 6GB | 14GB |
| 13B | 208GB | 28GB | 10GB | 26GB |
| 30B | 480GB | 64GB | 24GB | 60GB |
| 70B | 1120GB | 140GB | 48GB | 140GB |

## LoRA配置参数

| 参数 | 典型值 | 说明 | 调优建议 |
|-----|-------|------|---------|
| `lora_r` | 8-64 | 秩大小,影响容量 | 越大越强但显存增加 |
| `lora_alpha` | 16-128 | 缩放因子 | 通常设为r的2倍 |
| `lora_dropout` | 0.05-0.1 | Dropout比例 | 防止过拟合 |
| `target_modules` | q_proj,v_proj | 目标模块 | 可扩展到所有线性层 |
| `bias` | none | 偏置训练策略 | none/all/lora_only |
| `task_type` | CAUSAL_LM | 任务类型 | SEQ_CLS/SEQ_2_SEQ_LM |
| `inference_mode` | False | 推理模式 | 训练时False |
| `modules_to_save` | embed_tokens | 额外保存模块 | 词表扩展时需要 |

## 常见模型target_modules

| 模型 | target_modules | 说明 |
|-----|---------------|------|
| LLaMA/LLaMA2/LLaMA3 | q_proj,k_proj,v_proj,o_proj,gate_proj,up_proj,down_proj | 全部线性层 |
| Mistral | q_proj,k_proj,v_proj,o_proj,gate_proj,up_proj,down_proj | 同LLaMA |
| Qwen/Qwen2 | c_attn,c_proj,w1,w2 | 自定义命名 |
| ChatGLM | query_key_value,dense,dense_h_to_4h,dense_4h_to_h | GLM架构 |
| Baichuan | W_pack,o_proj,gate_proj,up_proj,down_proj | 百川模型 |
| Yi | q_proj,k_proj,v_proj,o_proj,gate_proj,up_proj,down_proj | 同LLaMA |

## Kubernetes LoRA训练Job

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: llm-lora-finetune
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: trainer
        image: pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime
        command:
        - python
        - train_lora.py
        - --model_name=meta-llama/Llama-2-7b-hf
        - --lora_r=16
        - --lora_alpha=32
        - --learning_rate=2e-4
        - --num_epochs=3
        - --batch_size=4
        - --gradient_accumulation_steps=4
        env:
        - name: HF_TOKEN
          valueFrom:
            secretKeyRef:
              name: huggingface-secret
              key: token
        - name: WANDB_API_KEY
          valueFrom:
            secretKeyRef:
              name: wandb-secret
              key: api-key
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: 32Gi
          requests:
            nvidia.com/gpu: 1
            memory: 24Gi
        volumeMounts:
        - name: model-cache
          mountPath: /root/.cache/huggingface
        - name: dataset
          mountPath: /data
        - name: output
          mountPath: /output
      volumes:
      - name: model-cache
        persistentVolumeClaim:
          claimName: model-cache-pvc
      - name: dataset
        persistentVolumeClaim:
          claimName: dataset-pvc
      - name: output
        persistentVolumeClaim:
          claimName: output-pvc
      nodeSelector:
        accelerator: nvidia-a100
```

## QLoRA配置

```yaml
# QLoRA特有配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: qlora-config
data:
  config.yaml: |
    quantization:
      load_in_4bit: true
      bnb_4bit_compute_dtype: float16
      bnb_4bit_quant_type: nf4
      bnb_4bit_use_double_quant: true
    lora:
      r: 64
      alpha: 16
      dropout: 0.1
      target_modules:
        - q_proj
        - k_proj
        - v_proj
        - o_proj
        - gate_proj
        - up_proj
        - down_proj
    training:
      per_device_train_batch_size: 1
      gradient_accumulation_steps: 16
      warmup_steps: 100
      max_steps: 1000
      learning_rate: 2e-4
      optim: paged_adamw_32bit
```

## 分布式微调配置

```yaml
apiVersion: kubeflow.org/v1
kind: PyTorchJob
metadata:
  name: distributed-lora-finetune
spec:
  pytorchReplicaSpecs:
    Master:
      replicas: 1
      template:
        spec:
          containers:
          - name: trainer
            image: lora-trainer:v1
            command:
            - torchrun
            - --nproc_per_node=8
            - --nnodes=2
            - --node_rank=$(RANK)
            - --master_addr=$(MASTER_ADDR)
            - --master_port=29500
            - train_distributed.py
            resources:
              limits:
                nvidia.com/gpu: 8
    Worker:
      replicas: 1
      template:
        spec:
          containers:
          - name: trainer
            image: lora-trainer:v1
            resources:
              limits:
                nvidia.com/gpu: 8
```

## 微调数据集管理

| 数据格式 | 适用场景 | 示例 |
|---------|---------|------|
| Alpaca | 指令微调 | instruction/input/output |
| ShareGPT | 对话微调 | conversations数组 |
| JSONL | 通用 | 每行一个样本 |
| Parquet | 大规模数据 | 列式存储 |

## 超参数建议

| 模型规模 | 学习率 | Batch Size | LoRA r | Epochs |
|---------|--------|------------|--------|--------|
| 7B | 2e-4 | 4-8 | 16-32 | 2-3 |
| 13B | 1e-4 | 2-4 | 32-64 | 2-3 |
| 70B | 5e-5 | 1-2 | 64-128 | 1-2 |

## ACK微调支持

| 功能 | 说明 |
|-----|------|
| PAI-DLC | 分布式训练平台 |
| GPU实例 | A10/A100/V100 |
| 模型仓库 | ModelScope集成 |
| 监控 | ARMS训练监控 |

## DeepSpeed配置(ZeRO优化)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: deepspeed-config
data:
  ds_config.json: |
    {
      "bf16": {
        "enabled": true
      },
      "zero_optimization": {
        "stage": 3,
        "offload_optimizer": {
          "device": "cpu",
          "pin_memory": true
        },
        "offload_param": {
          "device": "cpu",
          "pin_memory": true
        },
        "overlap_comm": true,
        "contiguous_gradients": true,
        "sub_group_size": 1e9,
        "reduce_bucket_size": "auto",
        "stage3_prefetch_bucket_size": "auto",
        "stage3_param_persistence_threshold": "auto",
        "stage3_max_live_parameters": 1e9,
        "stage3_max_reuse_distance": 1e9,
        "gather_16bit_weights_on_model_save": true
      },
      "gradient_accumulation_steps": 8,
      "gradient_clipping": 1.0,
      "train_batch_size": "auto",
      "train_micro_batch_size_per_gpu": "auto",
      "wall_clock_breakdown": false
    }
```

## FSDP配置(PyTorch原生)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fsdp-config
data:
  fsdp_config.yaml: |
    fsdp_transformer_layer_cls_to_wrap:
      - LlamaDecoderLayer
      - MistralDecoderLayer
    fsdp_backward_prefetch: backward_pre
    fsdp_forward_prefetch: false
    fsdp_use_orig_params: true
    fsdp_cpu_offload: false
    fsdp_sharding_strategy: FULL_SHARD
    fsdp_state_dict_type: SHARDED_STATE_DICT
    fsdp_auto_wrap_policy: TRANSFORMER_BASED_WRAP
    fsdp_activation_checkpointing: true
```

## 多节点训练Job(Kubeflow)

```yaml
apiVersion: kubeflow.org/v1
kind: PyTorchJob
metadata:
  name: llm-finetune-multinode
spec:
  nprocPerNode: "8"
  pytorchReplicaSpecs:
    Master:
      replicas: 1
      restartPolicy: OnFailure
      template:
        metadata:
          annotations:
            sidecar.istio.io/inject: "false"
        spec:
          containers:
          - name: pytorch
            image: llm-trainer:v1
            imagePullPolicy: Always
            env:
            - name: NCCL_DEBUG
              value: INFO
            - name: NCCL_IB_DISABLE
              value: "0"
            - name: NCCL_NET_GDR_LEVEL
              value: "2"
            command:
            - torchrun
            - --nnodes=4
            - --nproc-per-node=8
            - --rdzv-backend=c10d
            - --rdzv-endpoint=$(MASTER_ADDR):29500
            - train.py
            - --model_name_or_path=/models/Llama-2-70b-hf
            - --use_lora
            - --lora_r=64
            - --lora_alpha=128
            - --per_device_train_batch_size=1
            - --gradient_accumulation_steps=8
            - --deepspeed=/config/ds_config.json
            resources:
              limits:
                nvidia.com/gpu: 8
                rdma/rdma_shared_device_a: 1  # RDMA支持
              requests:
                nvidia.com/gpu: 8
                memory: 500Gi
            volumeMounts:
            - name: models
              mountPath: /models
            - name: config
              mountPath: /config
            - name: shm
              mountPath: /dev/shm
          volumes:
          - name: models
            persistentVolumeClaim:
              claimName: model-pvc
          - name: config
            configMap:
              name: deepspeed-config
          - name: shm
            emptyDir:
              medium: Memory
              sizeLimit: 100Gi
          nodeSelector:
            accelerator: nvidia-a100-80g
          tolerations:
          - key: nvidia.com/gpu
            operator: Exists
            effect: NoSchedule
    Worker:
      replicas: 3
      restartPolicy: OnFailure
      template:
        spec:
          containers:
          - name: pytorch
            image: llm-trainer:v1
            # 与Master相同配置...
```

## 训练监控指标

| 指标 | 类型 | 说明 | 正常范围 |
|-----|-----|------|---------|
| `train_loss` | Gauge | 训练损失 | 逐步下降 |
| `learning_rate` | Gauge | 学习率 | 按计划变化 |
| `train_samples_per_second` | Gauge | 训练吞吐量 | 稳定 |
| `gpu_memory_allocated` | Gauge | GPU显存使用 | <95% |
| `gradient_norm` | Gauge | 梯度范数 | <10(未裁剪前) |
| `epoch` | Counter | 当前epoch | 递增 |

## 训练故障排查

| 问题 | 症状 | 原因 | 解决方案 |
|-----|------|------|---------|
| NCCL超时 | 训练挂起 | 网络问题 | 检查RDMA/IB配置 |
| OOM | CUDA OOM | 显存不足 | 减少batch/启用offload |
| Loss NaN | 训练发散 | 学习率过大 | 降低学习率/梯度裁剪 |
| 梯度消失 | Loss不下降 | 学习率过小 | 增加学习率/warmup |
| 收敛慢 | Loss下降慢 | 超参不当 | 调整LoRA r/alpha |

## 常用训练框架对比

| 框架 | 特点 | 适用场景 | K8s支持 |
|-----|------|---------|--------|
| transformers+PEFT | 简单易用 | 单机/小规模 | Job |
| DeepSpeed | ZeRO优化,CPU offload | 大规模分布式 | PyTorchJob |
| Megatron-LM | 张量并行 | 超大模型 | 自定义 |
| ColossalAI | 自动并行 | 通用 | PyTorchJob |
| LLaMA-Factory | 一站式微调 | 快速实验 | Job |
| Axolotl | 配置驱动 | 快速实验 | Job |
