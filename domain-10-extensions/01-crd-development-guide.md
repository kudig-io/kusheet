# 01 - CRD自定义资源定义开发指南

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-02 | **参考**: [kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)

## CRD核心概念与架构

### CRD vs API Extension对比

| 特性 | CRD (CustomResourceDefinition) | API Aggregation |
|-----|-------------------------------|----------------|
| **复杂度** | 简单，声明式 | 复杂，需要编程 |
| **存储** | etcd内置 | 自定义存储 |
| **验证** | OpenAPI v3 Schema | 自定义验证逻辑 |
| **转换** | 版本转换支持 | 完全自定义 |
| **适用场景** | 简单资源扩展 | 复杂业务逻辑 |

### CRD版本演化历程

```
v1.7  ──▶  v1.16  ──▶  v1.22  ──▶  v1.25+
 │          │          │          │
CRD v1beta1  CRD v1    结构化    结构化+默认值
(已废弃)    (稳定)    融合       融合+验证
```

## CRD开发完整流程

### 1. CRD定义规范

```yaml
# crd-example.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  # 名称格式: plural.group.domain
  name: mysqlclusters.database.example.com
spec:
  # 组名 - 通常使用反向域名
  group: database.example.com
  
  # 版本列表
  versions:
  - name: v1beta1
    # 是否作为存储版本
    storage: false
    # 是否提供服务
    served: true
    # OpenAPI v3 schema验证
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              replicas:
                type: integer
                minimum: 1
                maximum: 10
                default: 1
              version:
                type: string
                enum:
                - "5.7"
                - "8.0"
                default: "8.0"
              storage:
                type: object
                properties:
                  size:
                    type: string
                    pattern: "^[0-9]+Gi$"
                  class:
                    type: string
                required: ["size"]
            required: ["replicas", "storage"]
          status:
            type: object
            properties:
              phase:
                type: string
                enum:
                - Pending
                - Creating
                - Running
                - Failed
              replicas:
                type: integer
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                      enum: ["True", "False", "Unknown"]
                    reason:
                      type: string
                    message:
                      type: string
                    lastTransitionTime:
                      type: string
                      format: date-time
    
    # 子资源支持
    subresources:
      # 支持kubectl scale
      scale:
        specReplicasPath: .spec.replicas
        statusReplicasPath: .status.replicas
        labelSelectorPath: .status.labelSelector
      # 支持kubectl status
      status: {}
    
    # 打印列定义 (kubectl get显示)
    additionalPrinterColumns:
    - name: Replicas
      type: integer
      description: Number of replicas
      jsonPath: .spec.replicas
    - name: Status
      type: string
      description: Cluster status
      jsonPath: .status.phase
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
    
    # 版本转换策略
    conversion:
      strategy: None  # 或Webhook
  
  # 作用域: Namespaced或Cluster
  scope: Namespaced
  
  # 名称定义
  names:
    # 复数形式
    plural: mysqlclusters
    # 单数形式
    singular: mysqlcluster
    # Kind名称
    kind: MySQLCluster
    # 简短名称 (kubectl get mc)
    shortNames:
    - mc
    - mysql
    # 列表Kind
    listKind: MySQLClusterList
```

### 2. CR实例示例

```yaml
# mysql-cluster-example.yaml
apiVersion: database.example.com/v1beta1
kind: MySQLCluster
metadata:
  name: my-cluster
  namespace: default
spec:
  replicas: 3
  version: "8.0"
  storage:
    size: "100Gi"
    class: "fast-ssd"
  # 可选配置
  backup:
    enabled: true
    schedule: "0 2 * * *"
    retention: "7d"
status:
  phase: Pending
  replicas: 0
  conditions:
  - type: Available
    status: "False"
    reason: "Creating"
    message: "MySQL cluster is being created"
    lastTransitionTime: "2024-01-01T10:00:00Z"
```

## 高级CRD特性

### 1. 默认值与枚举

```yaml
# 高级schema特性
schema:
  openAPIV3Schema:
    type: object
    properties:
      spec:
        type: object
        properties:
          # 默认值
          logLevel:
            type: string
            default: "INFO"
            enum: ["DEBUG", "INFO", "WARN", "ERROR"]
          
          # 数组验证
          whitelist:
            type: array
            items:
              type: string
              pattern: "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$"
            maxItems: 100
          
          # 对象验证
          resources:
            type: object
            properties:
              limits:
                type: object
                properties:
                  cpu:
                    type: string
                    pattern: "^[0-9]+(m|)$"
                  memory:
                    type: string
                    pattern: "^[0-9]+(Mi|Gi)$"
                required: ["cpu", "memory"]
            required: ["limits"]
          
          # 条件验证 (oneOf/anyOf/allOf)
          config:
            oneOf:
            - required: ["file"]
            - required: ["inline"]
```

### 2. 版本转换配置

```yaml
# 多版本CRD
versions:
- name: v1alpha1
  storage: false
  served: true
- name: v1beta1
  storage: true
  served: true
  # 版本转换配置
  conversion:
    strategy: Webhook
    webhook:
      clientConfig:
        service:
          namespace: system
          name: webhook-service
          path: /convert
      conversionReviewVersions: ["v1", "v1beta1"]
```

### 3. 保留未知字段

```yaml
# 保留未知字段配置
schema:
  openAPIV3Schema:
    type: object
    # 保留status中的未知字段
    x-kubernetes-preserve-unknown-fields: true
    properties:
      spec:
        type: object
        # 只验证已知字段
        x-kubernetes-preserve-unknown-fields: true
```

## CRD部署与管理

### 1. 部署脚本

```bash
#!/bin/bash
# deploy-crd.sh

set -e

CRD_FILE="config/crd/bases/database.example.com_mysqlclusters.yaml"
NAMESPACE="mysql-operator-system"

echo "🔍 验证CRD文件..."
kubectl apply --dry-run=client -f ${CRD_FILE} -o yaml > /dev/null
echo "✅ CRD文件语法正确"

echo "🚀 部署CRD..."
kubectl apply -f ${CRD_FILE}

echo "⏳ 等待CRD就绪..."
until kubectl get crd mysqlclusters.database.example.com > /dev/null 2>&1; do
  echo "等待CRD注册..."
  sleep 2
done

echo "📋 验证CRD状态..."
kubectl get crd mysqlclusters.database.example.com -o wide

echo "🧪 测试CRD..."
cat <<EOF | kubectl apply -f -
apiVersion: database.example.com/v1beta1
kind: MySQLCluster
metadata:
  name: test-cluster
spec:
  replicas: 1
  storage:
    size: "10Gi"
EOF

echo "🧹 清理测试资源..."
kubectl delete mysqlcluster test-cluster

echo "🎉 CRD部署完成!"
```

### 2. CRD验证工具

```bash
# 使用kubeval验证
kubeval --strict --ignore-missing-schemas ${CRD_FILE}

# 使用conftest验证策略
conftest test -p policy/crd.rego ${CRD_FILE}

# 使用kubebuilder验证
kubebuilder alpha crd gen --input-dir=config/crd/bases/

# 验证CRD是否存在
kubectl get crd | grep mysqlcluster
```

## CRD最佳实践

### 1. 命名规范

```
# 推荐命名模式
plural.group.domain.com

# 示例
mysqlclusters.database.example.com  ✅
mysql.database.example.com          ❌ (不够明确)
databases.mysql.example.com         ✅
```

### 2. 版本管理策略

```yaml
# 版本演进建议
versions:
# v1alpha1 - 实验性功能
- name: v1alpha1
  served: false  # 不对外提供
  storage: false
  
# v1beta1 - Beta功能
- name: v1beta1
  served: true
  storage: false
  
# v1 - 稳定版本
- name: v1
  served: true
  storage: true  # 主存储版本
```

### 3. 安全考虑

```yaml
# 安全相关的CRD配置
metadata:
  annotations:
    # RBAC最小权限
    rbac.authorization.k8s.io/autoupdate: "true"
    
    # 资源配额
    quota.openshift.io/core-resource: "true"
    
    # 审计日志
    audit.kubernetes.io/log-level: "Metadata"

# 状态保护
subresources:
  status:
    # 只允许控制器更新status
    x-kubernetes-status-subresource: true
```

## CRD故障排除

### 常见问题诊断

```bash
# 1. CRD验证失败
kubectl describe crd mysqlclusters.database.example.com

# 2. 实例创建失败
kubectl get events --field-selector involvedObject.kind=MySQLCluster

# 3. Schema验证错误
kubectl api-resources | grep mysqlcluster

# 4. 版本转换问题
kubectl get mysqlcluster -o yaml | kubectl convert -f - --output-version=v1beta1

# 5. 权限问题
kubectl auth can-i create mysqlclusters.database.example.com
```

### 调试命令集合

```bash
# 查看CRD详细信息
kubectl get crd mysqlclusters.database.example.com -o yaml

# 查看CRD支持的版本
kubectl get crd mysqlclusters.database.example.com -o jsonpath='{.spec.versions[*].name}'

# 查看打印列配置
kubectl get crd mysqlclusters.database.example.com -o jsonpath='{.spec.versions[*].additionalPrinterColumns}'

# 测试CR实例
kubectl create -f test-instance.yaml --dry-run=server -o yaml

# 验证OpenAPI schema
kubectl get --raw "/openapi/v2" | jq '.definitions | keys[] | select(contains("mysqlcluster"))'
```

## CRD监控与运维

### 1. 监控指标

```yaml
# Prometheus监控配置
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: crd-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: crd-controller
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    metricRelabelings:
    - sourceLabels: [__name__]
      regex: 'workqueue_(.+)'
      targetLabel: __name__
      replacement: 'crd_controller_$1'
```

### 2. 健康检查

```bash
#!/bin/bash
# crd-health-check.sh

NAMESPACE="mysql-operator-system"
CRD_NAME="mysqlclusters.database.example.com"

echo "=== CRD健康检查 ==="

# 1. CRD存在性检查
if ! kubectl get crd ${CRD_NAME} >/dev/null 2>&1; then
  echo "❌ CRD ${CRD_NAME} 不存在"
  exit 1
fi
echo "✅ CRD存在"

# 2. CRD版本检查
VERSIONS=$(kubectl get crd ${CRD_NAME} -o jsonpath='{.spec.versions[*].name}')
echo "📋 支持版本: ${VERSIONS}"

# 3. 存储版本检查
STORAGE_VERSION=$(kubectl get crd ${CRD_NAME} -o jsonpath='{.spec.versions[?(@.storage==true)].name}')
echo "💾 存储版本: ${STORAGE_VERSION}"

# 4. 实例数量检查
INSTANCE_COUNT=$(kubectl get ${CRD_NAME} --all-namespaces --no-headers | wc -l)
echo "📊 实例总数: ${INSTANCE_COUNT}"

# 5. 控制器状态检查
CONTROLLER_POD=$(kubectl get pods -n ${NAMESPACE} -l control-plane=controller-manager -o name)
if [ -n "${CONTROLLER_POD}" ]; then
  kubectl get ${CONTROLLER_POD} -n ${NAMESPACE} -o wide
else
  echo "⚠️ 未找到控制器Pod"
fi

echo "✅ CRD健康检查完成"
```

---
**CRD开发原则**: 结构化定义、版本兼容、安全验证、可观测性

---
**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)