# 表格62: LLM隐私与安全

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/security](https://kubernetes.io/docs/concepts/security/)

## LLM安全风险类型

| 风险类型 | 描述 | 防护措施 |
|---------|------|---------|
| 提示注入 | 恶意指令注入 | 输入过滤/沙箱 |
| 数据泄露 | 训练数据提取 | 差分隐私 |
| 越狱攻击 | 绕过安全限制 | 对齐训练/检测 |
| 对抗样本 | 欺骗模型输出 | 对抗训练 |
| 隐私推断 | 推断用户信息 | 联邦学习 |
| 模型窃取 | API反向工程 | 速率限制/水印 |

## 输入过滤配置

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: llm-safety-config
data:
  input_filter.yaml: |
    filters:
      # 敏感词过滤
      sensitive_words:
        enabled: true
        action: block  # block/mask/warn
        word_list: /config/sensitive_words.txt
      
      # 提示注入检测
      prompt_injection:
        enabled: true
        action: block
        patterns:
          - "ignore previous instructions"
          - "disregard all prior"
          - "system prompt"
        ml_detection: true
        threshold: 0.85
      
      # PII检测
      pii_detection:
        enabled: true
        action: mask
        types:
          - phone
          - email
          - id_card
          - bank_card
          - address
      
      # 长度限制
      length_limit:
        max_tokens: 4096
        max_characters: 16384
```

## 输出审计配置

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: output-audit-config
data:
  audit.yaml: |
    output_filters:
      # 有害内容检测
      harmful_content:
        enabled: true
        categories:
          - hate_speech
          - violence
          - adult_content
          - self_harm
        threshold: 0.7
        action: block
      
      # 代码安全检查
      code_security:
        enabled: true
        check_types:
          - sql_injection
          - xss
          - command_injection
        action: warn
      
      # 事实核查
      fact_check:
        enabled: false
        external_api: "https://factcheck.example.com"
    
    logging:
      enabled: true
      log_inputs: true
      log_outputs: true
      retention_days: 90
      storage: elasticsearch
```

## 安全网关部署

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llm-security-gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: llm-gateway
  template:
    metadata:
      labels:
        app: llm-gateway
    spec:
      containers:
      - name: gateway
        image: llm-security-gateway:v1
        env:
        - name: UPSTREAM_LLM
          value: "http://vllm-service:8000"
        - name: FILTER_CONFIG
          value: "/config/input_filter.yaml"
        - name: AUDIT_CONFIG
          value: "/config/audit.yaml"
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: "2"
            memory: 4Gi
        volumeMounts:
        - name: config
          mountPath: /config
      volumes:
      - name: config
        configMap:
          name: llm-safety-config
```

## 差分隐私训练

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: dp-training
spec:
  template:
    spec:
      containers:
      - name: trainer
        image: dp-llm-trainer:v1
        args:
        - --model_name=meta-llama/Llama-2-7b-hf
        - --dp_epsilon=8.0
        - --dp_delta=1e-5
        - --max_grad_norm=1.0
        - --noise_multiplier=1.1
        - --batch_size=16
        env:
        - name: OPACUS_ENABLED
          value: "true"
        resources:
          limits:
            nvidia.com/gpu: 4
```

## RBAC访问控制

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: llm-user
  namespace: llm-system
rules:
- apiGroups: [""]
  resources: ["services"]
  resourceNames: ["llm-inference"]
  verbs: ["get"]
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: llm-access-policy
data:
  policy.yaml: |
    access_control:
      default_policy: deny
      roles:
        admin:
          allowed_models: ["*"]
          max_tokens_per_request: 8192
          rate_limit: 1000/min
        developer:
          allowed_models: ["llama-2-7b", "mistral-7b"]
          max_tokens_per_request: 4096
          rate_limit: 100/min
        user:
          allowed_models: ["llama-2-7b"]
          max_tokens_per_request: 2048
          rate_limit: 20/min
```

## 模型水印

```python
# 水印配置示例
apiVersion: v1
kind: ConfigMap
metadata:
  name: watermark-config
data:
  watermark.py: |
    # 输出水印配置
    WATERMARK_CONFIG = {
        "enabled": True,
        "algorithm": "kirchenbauer",  # 或 "aar"
        "gamma": 0.25,
        "delta": 2.0,
        "seeding_scheme": "selfhash",
        "detection_threshold": 4.0
    }
```

## 安全监控指标

| 指标 | 类型 | 说明 |
|-----|-----|------|
| `blocked_requests_total` | Counter | 被阻止请求数 |
| `prompt_injection_detected` | Counter | 提示注入检测数 |
| `pii_masked_total` | Counter | PII脱敏数 |
| `harmful_content_blocked` | Counter | 有害内容阻止数 |
| `safety_score` | Histogram | 安全评分分布 |

## ACK LLM安全

| 功能 | 说明 |
|-----|------|
| 内容安全 | 阿里云内容安全API |
| 数据脱敏 | 敏感数据识别脱敏 |
| 审计日志 | 操作审计日志 |
| RAM集成 | 细粒度访问控制 |
