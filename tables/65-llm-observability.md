# 表格65: LLM可观测性与调试

## LLM可观测性维度

| 维度 | 监控内容 | 工具 |
|-----|---------|------|
| 性能 | 延迟/吞吐量/GPU利用率 | Prometheus/Grafana |
| 质量 | 输出质量/准确率/幻觉率 | LangSmith/Phoenix |
| 成本 | Token消耗/GPU成本 | 自定义仪表板 |
| 安全 | 有害内容/数据泄露 | 安全网关 |
| 用户 | 满意度/反馈 | 应用层追踪 |

## LLM追踪框架

| 框架 | 功能 | 开源 | 集成难度 |
|-----|------|------|---------|
| LangSmith | 全链路追踪 | ❌ | 低 |
| Phoenix (Arize) | 可观测性 | ✅ | 低 |
| Langfuse | 追踪分析 | ✅ | 低 |
| OpenLLMetry | OpenTelemetry | ✅ | 中 |
| Helicone | 代理追踪 | ✅ | 低 |
| Weights & Biases | 实验追踪 | ❌ | 低 |

## Phoenix部署

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: phoenix-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: phoenix
  template:
    metadata:
      labels:
        app: phoenix
    spec:
      containers:
      - name: phoenix
        image: arizephoenix/phoenix:latest
        ports:
        - containerPort: 6006
          name: http
        - containerPort: 4317
          name: otlp-grpc
        env:
        - name: PHOENIX_WORKING_DIR
          value: "/data"
        resources:
          limits:
            cpu: "2"
            memory: 4Gi
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: phoenix-data
---
apiVersion: v1
kind: Service
metadata:
  name: phoenix
spec:
  selector:
    app: phoenix
  ports:
  - name: http
    port: 6006
  - name: otlp-grpc
    port: 4317
```

## Langfuse部署

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: langfuse
spec:
  replicas: 1
  selector:
    matchLabels:
      app: langfuse
  template:
    spec:
      containers:
      - name: langfuse
        image: langfuse/langfuse:latest
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: langfuse-secrets
              key: database-url
        - name: NEXTAUTH_SECRET
          valueFrom:
            secretKeyRef:
              name: langfuse-secrets
              key: nextauth-secret
        - name: NEXTAUTH_URL
          value: "https://langfuse.example.com"
        - name: SALT
          valueFrom:
            secretKeyRef:
              name: langfuse-secrets
              key: salt
        ports:
        - containerPort: 3000
        resources:
          limits:
            cpu: "2"
            memory: 2Gi
```

## OpenTelemetry LLM配置

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-llm-config
data:
  collector.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    
    processors:
      batch:
        timeout: 1s
        send_batch_size: 1024
      
      attributes:
        actions:
          - key: llm.model
            action: insert
          - key: llm.tokens.input
            action: insert
          - key: llm.tokens.output
            action: insert
    
    exporters:
      otlp/jaeger:
        endpoint: jaeger:4317
        tls:
          insecure: true
      prometheus:
        endpoint: 0.0.0.0:8889
    
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch, attributes]
          exporters: [otlp/jaeger]
        metrics:
          receivers: [otlp]
          processors: [batch]
          exporters: [prometheus]
```

## LLM应用追踪代码

```python
# LangChain + Langfuse集成示例
apiVersion: v1
kind: ConfigMap
metadata:
  name: llm-tracing-code
data:
  tracing.py: |
    from langfuse.callback import CallbackHandler
    from langchain.llms import VLLM
    from langchain.chains import LLMChain
    
    # 初始化Langfuse回调
    langfuse_handler = CallbackHandler(
        public_key="pk-xxx",
        secret_key="sk-xxx",
        host="http://langfuse:3000"
    )
    
    # 创建LLM链
    llm = VLLM(
        model="/models/llama-2-7b",
        callbacks=[langfuse_handler]
    )
    
    chain = LLMChain(
        llm=llm,
        prompt=prompt_template,
        callbacks=[langfuse_handler]
    )
    
    # 追踪会话
    with langfuse_handler.trace(
        name="user_query",
        user_id="user123",
        metadata={"source": "api"}
    ) as trace:
        result = chain.run(query)
```

## LLM监控指标

| 指标 | 类型 | 说明 |
|-----|-----|------|
| `llm_request_duration_seconds` | Histogram | 请求延迟分布 |
| `llm_tokens_input_total` | Counter | 输入Token总数 |
| `llm_tokens_output_total` | Counter | 输出Token总数 |
| `llm_first_token_latency_seconds` | Histogram | 首Token延迟 |
| `llm_model_load_time_seconds` | Gauge | 模型加载时间 |
| `llm_cache_hit_ratio` | Gauge | 缓存命中率 |
| `llm_error_rate` | Gauge | 错误率 |

## Grafana仪表板

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: llm-dashboard
data:
  dashboard.json: |
    {
      "panels": [
        {
          "title": "请求延迟分布",
          "type": "histogram",
          "targets": [{
            "expr": "histogram_quantile(0.95, llm_request_duration_seconds_bucket)"
          }]
        },
        {
          "title": "Token吞吐量",
          "type": "graph",
          "targets": [{
            "expr": "rate(llm_tokens_output_total[5m])"
          }]
        },
        {
          "title": "GPU利用率",
          "type": "gauge",
          "targets": [{
            "expr": "avg(DCGM_FI_DEV_GPU_UTIL)"
          }]
        }
      ]
    }
```

## 调试工具

| 工具 | 用途 | 命令/方法 |
|-----|------|---------|
| 日志分析 | 查看推理日志 | `kubectl logs` |
| 性能分析 | GPU profiling | nsys/nvprof |
| 内存分析 | 显存使用 | nvidia-smi |
| 追踪可视化 | 调用链 | Jaeger UI |

## ACK可观测性

| 功能 | 说明 |
|-----|------|
| ARMS | 应用监控 |
| SLS | 日志服务 |
| Prometheus托管 | 指标采集 |
| 链路追踪 | 分布式追踪 |
