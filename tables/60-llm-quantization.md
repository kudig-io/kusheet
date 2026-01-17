# 表格60: LLM模型量化部署

## 量化方法对比

| 方法 | 精度损失 | 压缩比 | 推理速度 | 显存节省 | 复杂度 |
|-----|---------|-------|---------|---------|-------|
| FP16 | 极低 | 2x | 基准 | 50% | 低 |
| INT8 | 低 | 4x | 1.5-2x | 75% | 中 |
| INT4 (GPTQ) | 中 | 8x | 2-3x | 87% | 高 |
| INT4 (AWQ) | 低 | 8x | 2-3x | 87% | 中 |
| GGUF Q4_K_M | 中 | 8x | CPU友好 | 87% | 低 |
| FP8 | 极低 | 2x | 1.5x | 50% | 低 |

## GPTQ量化配置

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: gptq-quantize
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: quantizer
        image: pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime
        command:
        - python
        - -m
        - auto_gptq.quantize
        args:
        - --model_name=/models/Llama-2-7b-hf
        - --output_dir=/output/Llama-2-7b-gptq
        - --bits=4
        - --group_size=128
        - --desc_act=true
        - --dataset=c4
        - --num_samples=128
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: 32Gi
        volumeMounts:
        - name: models
          mountPath: /models
        - name: output
          mountPath: /output
      volumes:
      - name: models
        persistentVolumeClaim:
          claimName: model-pvc
      - name: output
        persistentVolumeClaim:
          claimName: output-pvc
```

## AWQ量化配置

```python
# AWQ量化脚本配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: awq-config
data:
  quantize.py: |
    from awq import AutoAWQForCausalLM
    from transformers import AutoTokenizer
    
    model_path = "/models/Llama-2-7b-hf"
    quant_path = "/output/Llama-2-7b-awq"
    
    quant_config = {
        "zero_point": True,
        "q_group_size": 128,
        "w_bit": 4,
        "version": "GEMM"
    }
    
    model = AutoAWQForCausalLM.from_pretrained(model_path)
    tokenizer = AutoTokenizer.from_pretrained(model_path)
    
    model.quantize(tokenizer, quant_config=quant_config)
    model.save_quantized(quant_path)
    tokenizer.save_pretrained(quant_path)
```

## 量化模型部署(vLLM)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-quantized
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm-quantized
  template:
    metadata:
      labels:
        app: vllm-quantized
    spec:
      containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        args:
        - --model=/models/Llama-2-7b-awq
        - --quantization=awq
        - --dtype=float16
        - --gpu-memory-utilization=0.9
        - --max-model-len=4096
        ports:
        - containerPort: 8000
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: 16Gi  # 量化后显存需求降低
        volumeMounts:
        - name: models
          mountPath: /models
        - name: shm
          mountPath: /dev/shm
      volumes:
      - name: models
        persistentVolumeClaim:
          claimName: quantized-models
      - name: shm
        emptyDir:
          medium: Memory
          sizeLimit: 8Gi
```

## llama.cpp部署(CPU推理)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llama-cpp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: llama-cpp
  template:
    spec:
      containers:
      - name: llama
        image: ghcr.io/ggerganov/llama.cpp:server
        args:
        - --model=/models/llama-2-7b-chat.Q4_K_M.gguf
        - --ctx-size=4096
        - --threads=8
        - --n-gpu-layers=0  # CPU模式
        - --host=0.0.0.0
        - --port=8080
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: "8"
            memory: 16Gi
          requests:
            cpu: "4"
            memory: 8Gi
        volumeMounts:
        - name: models
          mountPath: /models
      volumes:
      - name: models
        persistentVolumeClaim:
          claimName: gguf-models
```

## 量化精度对比

| 模型 | 量化方式 | MMLU | HellaSwag | 显存(GB) |
|-----|---------|------|-----------|---------|
| Llama-2-7B | FP16 | 45.3 | 76.0 | 14 |
| Llama-2-7B | GPTQ-4bit | 44.8 | 75.2 | 4 |
| Llama-2-7B | AWQ-4bit | 45.1 | 75.8 | 4 |
| Llama-2-7B | Q4_K_M | 44.5 | 74.9 | 4 |

## TensorRT-LLM量化

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: trtllm-quantize
spec:
  template:
    spec:
      containers:
      - name: trtllm
        image: nvcr.io/nvidia/tritonserver:24.01-trtllm-python-py3
        command:
        - python
        - /app/tensorrt_llm/examples/quantization/quantize.py
        args:
        - --model_dir=/models/Llama-2-7b-hf
        - --output_dir=/output/trtllm-int8
        - --dtype=float16
        - --qformat=int8_sq
        - --calib_size=512
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: 48Gi
```

## 动态量化(运行时)

```yaml
# bitsandbytes动态量化
env:
- name: LOAD_IN_8BIT
  value: "true"
# 或
- name: LOAD_IN_4BIT  
  value: "true"
- name: BNB_4BIT_COMPUTE_DTYPE
  value: "float16"
- name: BNB_4BIT_QUANT_TYPE
  value: "nf4"
```

## 量化模型选择指南

| 场景 | 推荐量化 | 理由 |
|-----|---------|------|
| 生产GPU推理 | AWQ | 精度好,速度快 |
| 低端GPU | GPTQ/AWQ 4bit | 显存占用小 |
| CPU推理 | GGUF Q4_K_M | CPU优化 |
| 边缘设备 | GGUF Q3_K_S | 极致压缩 |
| 高精度要求 | FP8/INT8 | 精度损失小 |
