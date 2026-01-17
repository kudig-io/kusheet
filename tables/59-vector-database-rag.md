# 表格59: 向量数据库与RAG

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/workloads](https://kubernetes.io/docs/concepts/workloads/)

## 向量数据库对比

| 数据库 | 类型 | 索引算法 | K8s部署 | 适用规模 |
|-------|-----|---------|--------|---------|
| Milvus | 分布式 | HNSW/IVF/DiskANN | Helm/Operator | 大规模 |
| Qdrant | 分布式 | HNSW | Helm | 中大规模 |
| Weaviate | 分布式 | HNSW | Helm | 中大规模 |
| Chroma | 嵌入式 | HNSW | 简单部署 | 小规模 |
| Pinecone | SaaS | 私有 | - | 任意 |
| pgvector | PostgreSQL扩展 | IVFFlat/HNSW | 标准PG部署 | 中小规模 |

## Milvus集群部署

```yaml
# Milvus Helm values
apiVersion: v1
kind: ConfigMap
metadata:
  name: milvus-config
data:
  values.yaml: |
    cluster:
      enabled: true
    etcd:
      replicaCount: 3
      persistence:
        size: 10Gi
    minio:
      mode: distributed
      replicas: 4
      persistence:
        size: 100Gi
    pulsar:
      enabled: true
      components:
        autorecovery: true
    proxy:
      replicas: 2
      resources:
        limits:
          cpu: "2"
          memory: 4Gi
    queryNode:
      replicas: 2
      resources:
        limits:
          cpu: "4"
          memory: 8Gi
          nvidia.com/gpu: 1  # GPU加速查询
    dataNode:
      replicas: 2
      resources:
        limits:
          cpu: "2"
          memory: 8Gi
    indexNode:
      replicas: 1
      resources:
        limits:
          cpu: "4"
          memory: 16Gi
          nvidia.com/gpu: 1  # GPU加速索引
```

## Qdrant部署

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: qdrant
spec:
  serviceName: qdrant
  replicas: 3
  selector:
    matchLabels:
      app: qdrant
  template:
    metadata:
      labels:
        app: qdrant
    spec:
      containers:
      - name: qdrant
        image: qdrant/qdrant:latest
        ports:
        - containerPort: 6333
          name: http
        - containerPort: 6334
          name: grpc
        env:
        - name: QDRANT__CLUSTER__ENABLED
          value: "true"
        - name: QDRANT__CLUSTER__P2P__PORT
          value: "6335"
        resources:
          limits:
            cpu: "2"
            memory: 4Gi
          requests:
            cpu: "1"
            memory: 2Gi
        volumeMounts:
        - name: storage
          mountPath: /qdrant/storage
  volumeClaimTemplates:
  - metadata:
      name: storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 50Gi
```

## RAG Pipeline架构

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   文档源     │───▶│  文档处理     │───▶│  向量化     │
│ (PDF/Web等) │    │ (分块/清洗)   │    │ (Embedding) │
└─────────────┘    └──────────────┘    └──────┬──────┘
                                              │
                                              ▼
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   LLM生成   │◀───│  上下文增强   │◀───│  向量检索   │
│  (Response) │    │  (Prompt)    │    │  (TopK)     │
└─────────────┘    └──────────────┘    └─────────────┘
```

## RAG服务部署

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rag-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: rag-service
  template:
    metadata:
      labels:
        app: rag-service
    spec:
      containers:
      - name: rag
        image: rag-service:v1
        env:
        - name: VECTOR_DB_HOST
          value: "milvus.default.svc.cluster.local"
        - name: VECTOR_DB_PORT
          value: "19530"
        - name: LLM_ENDPOINT
          value: "http://vllm-llama:8000/v1"
        - name: EMBEDDING_MODEL
          value: "BAAI/bge-large-zh-v1.5"
        - name: CHUNK_SIZE
          value: "512"
        - name: CHUNK_OVERLAP
          value: "50"
        - name: TOP_K
          value: "5"
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: "2"
            memory: 4Gi
```

## Embedding服务

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: embedding-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: embedding
  template:
    spec:
      containers:
      - name: embedding
        image: sentence-transformers/all-MiniLM-L6-v2
        # 或使用TEI (Text Embeddings Inference)
        # image: ghcr.io/huggingface/text-embeddings-inference:latest
        env:
        - name: MODEL_ID
          value: "BAAI/bge-large-zh-v1.5"
        ports:
        - containerPort: 8080
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: 8Gi
```

## 向量索引参数

| 索引类型 | 参数 | 推荐值 | 说明 |
|---------|-----|-------|------|
| HNSW | M | 16-64 | 连接数 |
| HNSW | efConstruction | 128-256 | 构建时搜索宽度 |
| HNSW | ef | 64-256 | 查询时搜索宽度 |
| IVF | nlist | sqrt(n) | 聚类中心数 |
| IVF | nprobe | nlist/10 | 查询探测数 |

## 检索策略

| 策略 | 说明 | 适用场景 |
|-----|------|---------|
| 语义检索 | 向量相似度 | 通用查询 |
| 混合检索 | 向量+关键词 | 精确匹配需求 |
| 重排序 | Cross-encoder | 高精度要求 |
| HyDE | 假设文档扩展 | 复杂问题 |

## ACK向量数据库

| 服务 | 说明 |
|-----|------|
| 云数据库AnalyticDB | PG向量扩展 |
| Lindorm | 宽表+向量 |
| Elasticsearch | 向量检索支持 |
| Milvus托管 | 即将支持 |
