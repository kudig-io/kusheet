# 表格63: LLM成本监控与优化

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/cluster-administration](https://kubernetes.io/docs/concepts/cluster-administration/)

## LLM成本构成

| 成本类型 | 占比 | 优化方向 |
|---------|-----|---------|
| GPU计算 | 60-80% | 量化/批处理/弹性伸缩 |
| 存储 | 10-20% | 模型压缩/缓存 |
| 网络 | 5-10% | CDN/本地缓存 |
| 人力运维 | 5-10% | 自动化 |

## 成本监控指标

| 指标 | 计算方式 | 说明 |
|-----|---------|------|
| 单请求成本 | GPU时间 × 单价 / 请求数 | 请求平均成本 |
| Token成本 | 总成本 / 总Token | 每Token成本 |
| GPU利用率 | 实际使用 / 分配资源 | 资源效率 |
| 空闲成本 | 空闲时间 × GPU单价 | 浪费成本 |

## 成本监控ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: llm-cost-config
data:
  pricing.yaml: |
    gpu_pricing:
      nvidia-a100-80gb:
        on_demand: 3.5  # $/hour
        spot: 1.2
        reserved_1y: 2.1
      nvidia-a10:
        on_demand: 1.5
        spot: 0.5
        reserved_1y: 0.9
      nvidia-t4:
        on_demand: 0.5
        spot: 0.15
        reserved_1y: 0.3
    
    model_costs:
      llama-2-70b:
        input_tokens: 0.0008  # $/1K tokens
        output_tokens: 0.0016
      llama-2-7b:
        input_tokens: 0.0001
        output_tokens: 0.0002
      gpt-4:
        input_tokens: 0.03
        output_tokens: 0.06
```

## 成本追踪Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm-cost-tracker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cost-tracker
  template:
    spec:
      containers:
      - name: tracker
        image: llm-cost-tracker:v1
        env:
        - name: PROMETHEUS_URL
          value: "http://prometheus:9090"
        - name: PRICING_CONFIG
          value: "/config/pricing.yaml"
        ports:
        - containerPort: 8080
          name: metrics
        volumeMounts:
        - name: config
          mountPath: /config
      volumes:
      - name: config
        configMap:
          name: llm-cost-config
```

## Prometheus成本查询

```yaml
# 成本告警规则
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: llm-cost-alerts
spec:
  groups:
  - name: llm-costs
    rules:
    - alert: HighLLMCostPerRequest
      expr: |
        sum(rate(llm_request_cost_dollars[1h])) / 
        sum(rate(llm_requests_total[1h])) > 0.1
      for: 30m
      labels:
        severity: warning
      annotations:
        summary: "LLM单请求成本过高"
        
    - alert: LowGPUUtilization
      expr: |
        avg(DCGM_FI_DEV_GPU_UTIL{job="llm-inference"}) < 30
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "GPU利用率过低,考虑缩容"
        
    - alert: HighIdleCost
      expr: |
        sum(llm_gpu_idle_cost_dollars[1h]) > 100
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "GPU空闲成本过高"
```

## 成本优化策略

| 策略 | 节省比例 | 实现方式 |
|-----|---------|---------|
| 模型量化 | 50-75% | INT4/INT8量化 |
| 批处理优化 | 20-40% | 动态批处理 |
| 抢占式实例 | 60-80% | Spot实例 |
| 弹性伸缩 | 30-50% | 按需扩缩 |
| 缓存复用 | 10-30% | KV Cache/语义缓存 |
| 模型蒸馏 | 40-60% | 小模型替代 |

## 语义缓存配置

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: semantic-cache
spec:
  template:
    spec:
      containers:
      - name: cache
        image: gptcache:latest
        env:
        - name: CACHE_BACKEND
          value: "redis"
        - name: REDIS_URL
          value: "redis://redis:6379"
        - name: SIMILARITY_THRESHOLD
          value: "0.95"
        - name: EMBEDDING_MODEL
          value: "sentence-transformers/all-MiniLM-L6-v2"
        - name: MAX_CACHE_SIZE
          value: "100000"
        ports:
        - containerPort: 8080
```

## 弹性伸缩配置

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: llm-cost-aware-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: vllm-inference
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: External
    external:
      metric:
        name: request_queue_length
      target:
        type: AverageValue
        averageValue: "5"
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Pods
        value: 2
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Pods
        value: 1
        periodSeconds: 120
```

## 成本报表Dashboard

| 维度 | 指标 | 周期 |
|-----|------|------|
| 模型 | 各模型成本占比 | 日/周/月 |
| 团队 | 团队成本分摊 | 月 |
| 应用 | 应用成本追踪 | 日/周 |
| 时段 | 高峰/低谷成本 | 日 |

## ACK成本优化

| 功能 | 说明 |
|-----|------|
| 抢占式实例 | 低成本GPU |
| 弹性配额 | 资源共享 |
| 成本分析 | 细粒度成本 |
| 闲置检测 | 资源浪费告警 |
