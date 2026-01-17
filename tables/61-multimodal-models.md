# 表格61: 多模态模型部署

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/workloads](https://kubernetes.io/docs/concepts/workloads/)

## 多模态模型类型

| 类型 | 代表模型 | 功能 | 资源需求 |
|-----|---------|------|---------|
| 视觉-语言 | LLaVA, Qwen-VL | 图像理解/问答 | GPU 16GB+ |
| 语音-语言 | Whisper, Qwen-Audio | 语音识别/理解 | GPU 8GB+ |
| 文生图 | Stable Diffusion, DALL-E | 图像生成 | GPU 12GB+ |
| 文生视频 | Sora, Gen-2 | 视频生成 | GPU 24GB+ |
| 全模态 | GPT-4o, Gemini | 多模态融合 | 大规模 |

## LLaVA部署

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llava-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: llava
  template:
    metadata:
      labels:
        app: llava
    spec:
      containers:
      - name: llava
        image: llava-server:v1.6
        env:
        - name: MODEL_PATH
          value: "/models/llava-v1.6-34b"
        - name: LOAD_8BIT
          value: "true"
        ports:
        - containerPort: 8000
          name: http
        resources:
          limits:
            nvidia.com/gpu: 2
            memory: 48Gi
          requests:
            nvidia.com/gpu: 2
            memory: 32Gi
        volumeMounts:
        - name: models
          mountPath: /models
        - name: shm
          mountPath: /dev/shm
      volumes:
      - name: models
        persistentVolumeClaim:
          claimName: multimodal-models
      - name: shm
        emptyDir:
          medium: Memory
          sizeLimit: 16Gi
      nodeSelector:
        accelerator: nvidia-a100
```

## Qwen-VL部署

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: qwen-vl
spec:
  replicas: 1
  selector:
    matchLabels:
      app: qwen-vl
  template:
    spec:
      containers:
      - name: qwen-vl
        image: qwen-vl-server:latest
        command:
        - python
        - -m
        - vllm.entrypoints.openai.api_server
        args:
        - --model=/models/Qwen-VL-Chat
        - --trust-remote-code
        - --dtype=float16
        - --max-model-len=8192
        ports:
        - containerPort: 8000
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: 24Gi
        volumeMounts:
        - name: models
          mountPath: /models
```

## Stable Diffusion部署

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stable-diffusion
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sd
  template:
    metadata:
      labels:
        app: sd
    spec:
      containers:
      - name: sd
        image: stable-diffusion-webui:latest
        env:
        - name: MODEL_PATH
          value: "/models/sd-xl-base-1.0"
        - name: ENABLE_ATTENTION_SLICING
          value: "true"
        - name: ENABLE_VAE_TILING
          value: "true"
        ports:
        - containerPort: 7860
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: 16Gi
        volumeMounts:
        - name: models
          mountPath: /models
        - name: outputs
          mountPath: /outputs
      volumes:
      - name: models
        persistentVolumeClaim:
          claimName: sd-models
      - name: outputs
        emptyDir: {}
```

## Whisper语音识别

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whisper-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: whisper
  template:
    spec:
      containers:
      - name: whisper
        image: whisper-server:latest
        env:
        - name: MODEL_SIZE
          value: "large-v3"
        - name: DEVICE
          value: "cuda"
        - name: COMPUTE_TYPE
          value: "float16"
        ports:
        - containerPort: 8080
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: 12Gi
        volumeMounts:
        - name: models
          mountPath: /root/.cache/whisper
```

## 多模态API网关

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multimodal-gateway
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
spec:
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /v1/chat/vision
        pathType: Prefix
        backend:
          service:
            name: llava-service
            port:
              number: 8000
      - path: /v1/images/generate
        pathType: Prefix
        backend:
          service:
            name: stable-diffusion
            port:
              number: 7860
      - path: /v1/audio/transcriptions
        pathType: Prefix
        backend:
          service:
            name: whisper-service
            port:
              number: 8080
```

## 图像预处理配置

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: image-processor-config
data:
  config.yaml: |
    preprocessing:
      max_image_size: 1024
      supported_formats:
        - jpeg
        - png
        - webp
        - gif
      resize_mode: "fit"  # fit/crop/pad
      normalize: true
    storage:
      temp_dir: /tmp/images
      max_cache_size: 10Gi
      cleanup_interval: 3600
```

## 多模态监控指标

| 指标 | 类型 | 说明 |
|-----|-----|------|
| `image_processing_seconds` | Histogram | 图像处理时间 |
| `image_size_bytes` | Histogram | 输入图像大小 |
| `model_inference_seconds` | Histogram | 模型推理时间 |
| `tokens_generated_total` | Counter | 生成token总数 |
| `images_generated_total` | Counter | 生成图像数 |

## ACK多模态支持

| 功能 | 说明 |
|-----|------|
| PAI-EAS | 多模态模型服务 |
| OSS集成 | 图像/视频存储 |
| CDN加速 | 媒体内容分发 |
| 弹性GPU | 按需GPU实例 |
