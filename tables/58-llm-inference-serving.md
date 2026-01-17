# 表格58: LLM推理服务部署

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [vllm.ai](https://vllm.ai/)

## 推理框架对比

| 框架 | 特点 | 量化支持 | 并发能力 | 适用场景 | 显存效率 |
|-----|------|---------|---------|---------|---------|
| **vLLM** | PagedAttention,高吞吐 | AWQ/GPTQ/FP8 | 高 | 生产推理 | ⭐⭐⭐⭐⭐ |
| **TGI** | HuggingFace官方 | GPTQ/bitsandbytes | 高 | 通用部署 | ⭐⭐⭐⭐ |
| **TensorRT-LLM** | NVIDIA优化 | INT8/FP8 | 最高 | NVIDIA GPU | ⭐⭐⭐⭐⭐ |
| **Triton** | 多模型服务 | 多种 | 高 | 多模型场景 | ⭐⭐⭐⭐ |
| **llama.cpp** | CPU/低资源 | GGUF量化 | 中 | 边缘部署 | ⭐⭐⭐⭐ |
| **Ollama** | 简单易用 | GGUF | 中 | 开发测试 | ⭐⭐⭐ |
| **SGLang** | 结构化生成优化 | AWQ/GPTQ | 高 | 复杂推理 | ⭐⭐⭐⭐ |

## 模型显存需求估算

| 模型规模 | FP16 | INT8 | INT4 | 推荐GPU |
|---------|------|------|------|--------|
| 7B | ~14GB | ~7GB | ~4GB | A10/L4 |
| 13B | ~26GB | ~13GB | ~7GB | A100-40G |
| 34B | ~68GB | ~34GB | ~17GB | A100-80G |
| 70B | ~140GB | ~70GB | ~35GB | 2xA100-80G |
| 120B+ | ~240GB | ~120GB | ~60GB | 4xA100-80G |

## vLLM Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-llama
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm-llama
  template:
    metadata:
      labels:
        app: vllm-llama
    spec:
      containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        args:
        - --model=/models/Llama-2-7b-chat-hf
        - --tensor-parallel-size=1
        - --gpu-memory-utilization=0.9
        - --max-model-len=4096
        - --dtype=float16
        ports:
        - containerPort: 8000
          name: http
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: 32Gi
          requests:
            nvidia.com/gpu: 1
            memory: 24Gi
        volumeMounts:
        - name: models
          mountPath: /models
        - name: shm
          mountPath: /dev/shm
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 120
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 60
          periodSeconds: 10
      volumes:
      - name: models
        persistentVolumeClaim:
          claimName: model-storage
      - name: shm
        emptyDir:
          medium: Memory
          sizeLimit: 16Gi
      nodeSelector:
        accelerator: nvidia-a100
---
apiVersion: v1
kind: Service
metadata:
  name: vllm-llama
spec:
  selector:
    app: vllm-llama
  ports:
  - port: 8000
    targetPort: 8000
  type: ClusterIP
```

## TGI Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tgi-mistral
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tgi-mistral
  template:
    metadata:
      labels:
        app: tgi-mistral
    spec:
      containers:
      - name: tgi
        image: ghcr.io/huggingface/text-generation-inference:latest
        env:
        - name: MODEL_ID
          value: "mistralai/Mistral-7B-Instruct-v0.2"
        - name: QUANTIZE
          value: "gptq"
        - name: NUM_SHARD
          value: "1"
        - name: MAX_INPUT_LENGTH
          value: "4096"
        - name: MAX_TOTAL_TOKENS
          value: "8192"
        - name: HUGGING_FACE_HUB_TOKEN
          valueFrom:
            secretKeyRef:
              name: hf-secret
              key: token
        ports:
        - containerPort: 80
        resources:
          limits:
            nvidia.com/gpu: 1
```

## 推理服务HPA配置

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: vllm-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: vllm-llama
  minReplicas: 1
  maxReplicas: 4
  metrics:
  - type: Pods
    pods:
      metric:
        name: gpu_utilization
      target:
        type: AverageValue
        averageValue: "80"
  - type: Pods
    pods:
      metric:
        name: request_queue_length
      target:
        type: AverageValue
        averageValue: "10"
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Pods
        value: 1
        periodSeconds: 120
    scaleDown:
      stabilizationWindowSeconds: 300
```

## 多模型推理(Triton)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: triton-llm
spec:
  template:
    spec:
      containers:
      - name: triton
        image: nvcr.io/nvidia/tritonserver:24.01-trtllm-python-py3
        args:
        - tritonserver
        - --model-repository=/models
        - --http-port=8000
        - --grpc-port=8001
        - --metrics-port=8002
        ports:
        - containerPort: 8000
          name: http
        - containerPort: 8001
          name: grpc
        - containerPort: 8002
          name: metrics
```

## 推理监控指标

| 指标 | 类型 | 说明 |
|-----|-----|------|
| `vllm:num_requests_running` | Gauge | 运行中请求数 |
| `vllm:num_requests_waiting` | Gauge | 等待队列长度 |
| `vllm:gpu_cache_usage_perc` | Gauge | KV Cache使用率 |
| `vllm:avg_generation_throughput` | Gauge | 生成吞吐量 |
| `tgi_request_duration_seconds` | Histogram | 请求延迟分布 |
| `tgi_request_generated_tokens` | Histogram | 生成token数分布 |

## 推理优化参数

| 参数 | 说明 | 推荐值 |
|-----|------|-------|
| `gpu-memory-utilization` | GPU显存利用率 | 0.85-0.95 |
| `max-num-seqs` | 最大并发序列 | 256 |
| `max-num-batched-tokens` | 批处理token数 | 8192 |
| `block-size` | PagedAttention块大小 | 16 |
| `swap-space` | CPU交换空间(GB) | 4 |

## ACK推理服务

| 功能 | 说明 | 配置方式 |
|-----|------|---------|
| **EAS** | 弹性推理服务 | PAI-EAS部署 |
| **模型优化** | Blade推理加速 | SDK集成 |
| **弹性伸缩** | 按请求自动扩缩 | HPA配置 |
| **流量管理** | A/B测试,金丝雀 | Istio/APISIX |
| **GPU共享** | cGPU显存隔离 | 资源配置 |

```yaml
# ACK GPU共享推理部署
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-shared-gpu
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        resources:
          limits:
            # ACK cGPU配置 - 每个实例4GB显存
            aliyun.com/gpu-mem: 4
          requests:
            aliyun.com/gpu-mem: 4
---
# KServe推理服务
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: llama-inference
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM
      storageUri: "pvc://model-pvc/llama-7b"
      resources:
        limits:
          nvidia.com/gpu: 1
        requests:
          nvidia.com/gpu: 1
    minReplicas: 1
    maxReplicas: 5
```

## 推理服务最佳实践

| 实践 | 说明 | 实施方法 |
|-----|------|---------|
| **模型预热** | 启动时加载模型到显存 | initContainer预热 |
| **健康检查** | 确保模型已加载 | /health端点 |
| **请求队列** | 控制并发请求数 | max_num_seqs |
| **显存管理** | 合理设置KV Cache | gpu-memory-utilization |
| **批处理优化** | 动态批处理 | continuous batching |
| **量化部署** | 降低显存占用 | AWQ/GPTQ |

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| vLLM 0.3 | 支持AWQ量化 |
| vLLM 0.4 | FP8量化支持 |
| vLLM 0.5 | 多模态支持改进 |
| TGI 2.0 | 性能大幅提升 |

---

**推理部署原则**: 选择合适框架 + 量化降低资源 + 合理配置批处理 + 监控关键指标 + 自动弹性伸缩
