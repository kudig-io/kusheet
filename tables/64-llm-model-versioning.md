# 表格64: LLM模型版本管理

## 模型版本管理工具

| 工具 | 类型 | 功能 | K8s集成 |
|-----|-----|------|--------|
| MLflow | 开源 | 全生命周期管理 | ✅ |
| DVC | 开源 | 数据/模型版本 | ✅ |
| Weights & Biases | SaaS | 实验追踪 | ✅ |
| Neptune.ai | SaaS | 实验管理 | ✅ |
| ClearML | 开源/SaaS | MLOps平台 | ✅ |
| ModelScope | 开源 | 模型仓库 | ✅ |

## MLflow Model Registry

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mlflow-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mlflow
  template:
    metadata:
      labels:
        app: mlflow
    spec:
      containers:
      - name: mlflow
        image: mlflow/mlflow:latest
        command:
        - mlflow
        - server
        - --backend-store-uri=postgresql://mlflow:password@postgres:5432/mlflow
        - --default-artifact-root=s3://mlflow-artifacts/
        - --host=0.0.0.0
        - --port=5000
        env:
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: s3-credentials
              key: access-key
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: s3-credentials
              key: secret-key
        ports:
        - containerPort: 5000
        resources:
          limits:
            cpu: "2"
            memory: 4Gi
```

## 模型注册流程

```python
# 模型注册示例
apiVersion: v1
kind: ConfigMap
metadata:
  name: model-registry-script
data:
  register_model.py: |
    import mlflow
    from mlflow import MlflowClient
    
    client = MlflowClient()
    
    # 注册模型
    model_uri = "runs:/<run_id>/model"
    model_name = "llama-2-7b-finetuned"
    
    result = mlflow.register_model(
        model_uri=model_uri,
        name=model_name,
        tags={
            "task": "text-generation",
            "base_model": "llama-2-7b",
            "quantization": "none",
            "framework": "transformers"
        }
    )
    
    # 设置版本阶段
    client.transition_model_version_stage(
        name=model_name,
        version=result.version,
        stage="Staging"  # None/Staging/Production/Archived
    )
    
    # 添加模型描述
    client.update_model_version(
        name=model_name,
        version=result.version,
        description="Fine-tuned on custom dataset, improved accuracy by 5%"
    )
```

## 模型部署CRD

```yaml
apiVersion: serving.kubeflow.org/v1beta1
kind: InferenceService
metadata:
  name: llm-model
  annotations:
    serving.kubeflow.org/model-version: "v1.2.0"
    serving.kubeflow.org/model-registry: "mlflow"
spec:
  predictor:
    model:
      modelFormat:
        name: pytorch
      storageUri: "models://llama-2-7b-finetuned/Production"
    resources:
      limits:
        nvidia.com/gpu: 1
```

## A/B测试配置

```yaml
apiVersion: serving.kubeflow.org/v1beta1
kind: InferenceService
metadata:
  name: llm-ab-test
spec:
  predictor:
    canaryTrafficPercent: 10
    model:
      modelFormat:
        name: pytorch
      storageUri: "models://llama-2-7b-v2/Production"
    resources:
      limits:
        nvidia.com/gpu: 1
  transformer:
    containers:
    - name: ab-router
      image: ab-router:v1
      env:
      - name: CONTROL_MODEL
        value: "v1"
      - name: TREATMENT_MODEL
        value: "v2"
      - name: TRAFFIC_SPLIT
        value: "90:10"
```

## 模型回滚配置

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: model-rollback
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: rollback
        image: mlflow-client:v1
        command:
        - python
        - rollback.py
        env:
        - name: MODEL_NAME
          value: "llama-2-7b-finetuned"
        - name: TARGET_VERSION
          value: "3"
        - name: MLFLOW_TRACKING_URI
          value: "http://mlflow:5000"
```

## 模型元数据Schema

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: model-metadata-schema
data:
  schema.yaml: |
    model_metadata:
      required:
        - name
        - version
        - base_model
        - task_type
        - created_at
      optional:
        - description
        - training_dataset
        - evaluation_metrics
        - hardware_requirements
        - quantization
        - license
      
    evaluation_metrics:
      llm:
        - perplexity
        - mmlu_score
        - hellaswag_score
        - truthfulqa_score
        - human_eval
      
    hardware_requirements:
      - min_gpu_memory_gb
      - recommended_gpu_type
      - estimated_latency_ms
```

## 模型版本状态

| 状态 | 说明 | 操作 |
|-----|------|------|
| None | 未分类 | 初始状态 |
| Staging | 测试中 | 验证评估 |
| Production | 生产使用 | 正式部署 |
| Archived | 已归档 | 保留历史 |

## 模型审计日志

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: model-audit-config
data:
  audit.yaml: |
    audit:
      enabled: true
      events:
        - model_registered
        - model_deployed
        - stage_transition
        - model_deleted
        - inference_started
      storage:
        type: elasticsearch
        index: model-audit-logs
      retention_days: 365
```

## ACK模型管理

| 功能 | 说明 |
|-----|------|
| PAI-EAS | 模型服务部署 |
| ModelScope | 模型仓库 |
| OSS | 模型存储 |
| RAM | 访问控制 |
