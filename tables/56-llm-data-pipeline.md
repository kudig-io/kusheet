# 表格56：大模型训练数据管道表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubeflow.org/docs/components/pipelines](https://www.kubeflow.org/docs/components/pipelines/)

## 数据管道组件

| 组件 | 用途 | 数据格式 | K8S集成 | 适用场景 |
|-----|------|---------|--------|---------|
| **Apache Beam** | 批流一体ETL | 任意 | Dataflow Operator | 大规模数据处理 |
| **Spark** | 分布式处理 | Parquet/ORC | Spark Operator | 批处理 |
| **Flink** | 流处理 | 任意 | Flink Operator | 实时处理 |
| **Ray Data** | 分布式数据 | 任意 | Ray Operator | ML数据预处理 |
| **Dask** | 并行计算 | 任意 | Dask Operator | 科学计算 |
| **Fluid** | 数据加速 | 任意 | CRD | 数据缓存加速 |

## 数据格式对比

| 格式 | 特点 | 压缩 | 适用场景 | 读取性能 |
|-----|------|------|---------|---------|
| **TFRecord** | TensorFlow原生 | 支持 | TF训练 | 高 |
| **Parquet** | 列式存储 | 高效 | 大数据分析 | 很高 |
| **Arrow** | 内存格式 | 无 | 跨语言共享 | 最高 |
| **JSONL** | 文本行 | 支持 | LLM训练数据 | 中 |
| **WebDataset** | TAR打包 | 支持 | 图像数据集 | 高 |
| **MDS** | Mosaic格式 | 支持 | LLM训练 | 很高 |

## Fluid数据加速

```yaml
# Fluid Dataset
apiVersion: data.fluid.io/v1alpha1
kind: Dataset
metadata:
  name: training-data
spec:
  mounts:
  - mountPoint: oss://bucket/training-data/
    name: data
    options:
      fs.oss.accessKeyId: <ak>
      fs.oss.accessKeySecret: <sk>
      fs.oss.endpoint: oss-cn-hangzhou-internal.aliyuncs.com
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-role.kubernetes.io/worker
          operator: Exists
---
# AlluxioRuntime加速
apiVersion: data.fluid.io/v1alpha1
kind: AlluxioRuntime
metadata:
  name: training-data
spec:
  replicas: 3
  tieredstore:
    levels:
    - mediumtype: MEM
      path: /dev/shm
      quota: 10Gi
      high: "0.95"
      low: "0.7"
    - mediumtype: SSD
      path: /mnt/ssd
      quota: 100Gi
      high: "0.95"
      low: "0.7"
  fuse:
    args:
    - fuse
    - --fuse-opts=kernel_cache,ro,max_read=131072
---
# 训练Pod使用加速数据
apiVersion: v1
kind: Pod
metadata:
  name: training-pod
spec:
  containers:
  - name: trainer
    image: pytorch:latest
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: training-data
```

## 数据管道(Kubeflow Pipelines)

```python
# Kubeflow Pipeline示例
from kfp import dsl
from kfp.dsl import component, pipeline

@component(base_image='python:3.9')
def download_data(url: str, output_path: str):
    import urllib.request
    urllib.request.urlretrieve(url, output_path)

@component(base_image='python:3.9-pandas')
def preprocess_data(input_path: str, output_path: str):
    import pandas as pd
    df = pd.read_csv(input_path)
    # 数据清洗
    df = df.dropna()
    df.to_parquet(output_path)

@component(base_image='python:3.9')
def tokenize_data(input_path: str, output_path: str, tokenizer_name: str):
    from transformers import AutoTokenizer
    import pandas as pd
    
    tokenizer = AutoTokenizer.from_pretrained(tokenizer_name)
    df = pd.read_parquet(input_path)
    # 分词处理
    tokenized = tokenizer(df['text'].tolist(), padding=True, truncation=True)
    # 保存

@pipeline(name='llm-data-pipeline')
def llm_data_pipeline(data_url: str, tokenizer: str = 'bert-base-uncased'):
    download_task = download_data(url=data_url, output_path='/tmp/raw.csv')
    preprocess_task = preprocess_data(
        input_path='/tmp/raw.csv',
        output_path='/tmp/processed.parquet'
    ).after(download_task)
    tokenize_task = tokenize_data(
        input_path='/tmp/processed.parquet',
        output_path='/tmp/tokenized',
        tokenizer_name=tokenizer
    ).after(preprocess_task)
```

## 数据管道最佳实践

| 实践 | 说明 | 优先级 |
|-----|------|-------|
| **数据本地化** | 使用Fluid缓存 | P0 |
| **并行处理** | 分布式数据加载 | P0 |
| **格式优化** | 使用列式存储 | P1 |
| **增量处理** | 避免全量重处理 | P1 |
| **数据版本** | DVC/MLflow跟踪 | P1 |
| **质量检查** | 数据验证管道 | P2 |

## 数据存储方案(ACK)

| 存储 | 类型 | 性能 | 成本 | 适用场景 |
|-----|------|------|------|---------|
| **OSS** | 对象存储 | 中 | 低 | 原始数据存储 |
| **NAS** | 文件存储 | 高 | 中 | 共享数据集 |
| **CPFS** | 并行文件系统 | 很高 | 高 | 大规模训练 |
| **云盘ESSD** | 块存储 | 最高 | 高 | 高性能缓存 |
| **Fluid** | 缓存层 | 很高 | 中 | 数据加速 |

---

**数据管道原则**: 数据本地化，格式优化，增量处理
