# Kustomize 部署故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32, Kustomize v5.0+ | **最后更新**: 2026-01 | **难度**: 中级
>
> **版本说明**:
> - kubectl 内置 kustomize 版本可能落后，建议独立安装
> - Kustomize v5.0+ 支持 composition 和改进的 patch 策略
> - Kustomize v5.3+ 支持 helmCharts 字段的更多选项
> - K8s v1.27+ kubectl 内置 Kustomize v5.0

---

## 第一部分：问题现象与影响分析

### 1.1 Kustomize 工作原理

```
┌──────────────────────────────────────────────────────────────────────────┐
│                       Kustomize 构建流程                                 │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌────────────────────────────────────────────────────────────────┐    │
│   │                    Base (基础配置)                              │    │
│   │                                                                 │    │
│   │  base/                                                          │    │
│   │  ├── kustomization.yaml   # 资源清单                            │    │
│   │  ├── deployment.yaml      # 基础 Deployment                     │    │
│   │  ├── service.yaml         # 基础 Service                        │    │
│   │  └── configmap.yaml       # 基础 ConfigMap                      │    │
│   │                                                                 │    │
│   └────────────────────────────┬───────────────────────────────────┘    │
│                                │                                         │
│                           引用 Base                                      │
│                                │                                         │
│   ┌────────────────────────────┴───────────────────────────────────┐    │
│   │                  Overlays (环境覆盖)                            │    │
│   │                                                                 │    │
│   │  overlays/                                                      │    │
│   │  ├── dev/                                                       │    │
│   │  │   ├── kustomization.yaml   # 引用 base + dev 特定配置        │    │
│   │  │   ├── replica-patch.yaml   # 副本数补丁                      │    │
│   │  │   └── config-patch.yaml    # 配置补丁                        │    │
│   │  ├── staging/                                                   │    │
│   │  │   └── kustomization.yaml                                     │    │
│   │  └── prod/                                                      │    │
│   │      └── kustomization.yaml                                     │    │
│   │                                                                 │    │
│   └────────────────────────────┬───────────────────────────────────┘    │
│                                │                                         │
│                         kustomize build                                  │
│                                │                                         │
│                                ▼                                         │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                     合并后的 YAML                                │   │
│   │  (可直接 kubectl apply)                                         │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

Kustomize 处理阶段:
┌──────────────┐
│  读取 Base   │
│  资源文件    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  应用        │
│  Transformers│  (patches, images, labels, etc.)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  应用        │
│  Generators  │  (configMapGenerator, secretGenerator)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  应用        │
│  Validators  │  (验证最终输出)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  输出合并后  │
│  的 YAML     │
└──────────────┘
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 错误信息 | 查看方式 |
|----------|----------|----------|----------|
| kustomization.yaml 错误 | 构建失败 | error loading kustomization | `kustomize build` |
| 资源找不到 | base/patch 文件缺失 | no such file or directory | `kustomize build` |
| Patch 不匹配 | 补丁未应用 | no resources matched | `kustomize build` |
| 合并冲突 | 字段覆盖异常 | conflict in merge | `kustomize build` |
| 生成器错误 | ConfigMap/Secret 生成失败 | error generating | `kustomize build` |
| 名称前缀/后缀问题 | 资源引用断裂 | reference not found | kubectl apply |
| 标签选择器不匹配 | Service 无法找到 Pod | selector mismatch | kubectl describe |
| 应用失败 | kubectl apply 报错 | various | kubectl apply |

### 1.3 影响分析

| 问题类型 | 直接影响 | 间接影响 | 影响范围 |
|----------|----------|----------|----------|
| 构建失败 | 无法生成部署配置 | 部署流程中断 | CI/CD 流水线 |
| Patch 不生效 | 配置未按预期修改 | 环境配置错误 | 特定环境 |
| 引用断裂 | Service 无法关联 Deployment | 服务不可用 | 应用服务 |
| 配置错误 | 应用行为异常 | 业务故障 | 受影响的应用 |

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
Kustomize 问题
        │
        ▼
┌───────────────────────┐
│  问题发生在哪个阶段？  │
└───────────────────────┘
        │
        ├── kustomize build 失败 ────────────────────────────┐
        │                                                     │
        │   ┌─────────────────────────────────────────┐      │
        │   │ 错误类型是什么?                         │      │
        │   └─────────────────────────────────────────┘      │
        │          │                                          │
        │          ├── YAML 语法错误 ──► 检查 YAML 格式      │
        │          │                                          │
        │          ├── 文件未找到 ──► 检查路径和文件名        │
        │          │                                          │
        │          ├── Patch 目标未找到 ──► 检查 target       │
        │          │                                          │
        │          └── Generator 错误 ──► 检查生成器配置      │
        │                                                     │
        ├── build 成功但输出不符合预期 ──────────────────────┤
        │                                                     │
        │   ┌─────────────────────────────────────────┐      │
        │   │ kustomize build 检查输出                │      │
        │   └─────────────────────────────────────────┘      │
        │          │                                          │
        │          ├── Patch 未应用 ──► 检查 patch 匹配      │
        │          │                                          │
        │          ├── 字段被意外覆盖 ──► 检查合并策略       │
        │          │                                          │
        │          └── 资源缺失 ──► 检查 resources 列表      │
        │                                                     │
        ├── kubectl apply 失败 ──────────────────────────────┤
        │                                                     │
        │   ┌─────────────────────────────────────────┐      │
        │   │ 检查 apply 错误信息                     │      │
        │   └─────────────────────────────────────────┘      │
        │          │                                          │
        │          ├── 验证错误 ──► 检查资源规格             │
        │          │                                          │
        │          ├── 权限不足 ──► 检查 RBAC                │
        │          │                                          │
        │          └── 资源冲突 ──► 检查现有资源             │
        │                                                     │
        └── 应用运行异常 ────────────────────────────────────┤
                                                              │
            ┌─────────────────────────────────────────┐      │
            │ 检查资源间的引用是否正确                │      │
            │ (selector, configMapRef, secretRef)     │      │
            └─────────────────────────────────────────┘      │
                                                              │
                                                              ▼
                                                       ┌────────────┐
                                                       │ 问题定位   │
                                                       │ 完成       │
                                                       └────────────┘
```

### 2.2 排查命令集

#### 构建和验证

```bash
# 基本构建并查看输出
kustomize build <path>
kubectl kustomize <path>

# 构建并保存到文件
kustomize build <path> > output.yaml

# 构建并验证 (dry-run)
kustomize build <path> | kubectl apply --dry-run=client -f -

# 查看 kustomize 版本
kustomize version
kubectl version --client | grep Kustomize

# 检查 kustomization.yaml 语法
kustomize cfg fmt <path>/kustomization.yaml
```

#### 调试命令

```bash
# 查看合并后特定资源
kustomize build <path> | kubectl get -f - -o yaml --dry-run=client

# 查看特定类型资源
kustomize build <path> | grep -A50 "kind: Deployment"

# 比较不同环境的输出
diff <(kustomize build overlays/dev) <(kustomize build overlays/prod)

# 检查资源列表
kustomize build <path> | grep "^kind:"

# 验证 YAML 语法
yamllint kustomization.yaml
```

#### 应用检查

```bash
# 应用并查看变更
kustomize build <path> | kubectl apply -f - --dry-run=server

# 查看实际差异
kustomize build <path> | kubectl diff -f -

# 应用配置
kustomize build <path> | kubectl apply -f -
# 或
kubectl apply -k <path>

# 删除资源
kustomize build <path> | kubectl delete -f -
# 或
kubectl delete -k <path>
```

### 2.3 排查注意事项

| 注意事项 | 说明 | 风险等级 |
|----------|------|----------|
| kustomize 版本差异 | kubectl 内置版本可能较旧 | 中 |
| patch 匹配规则 | Strategic Merge Patch vs JSON Patch | 中 |
| namePrefix/nameSuffix 传播 | 会影响所有引用 | 高 |
| 生成器哈希后缀 | ConfigMap/Secret 名称会变化 | 中 |
| 合并策略差异 | 列表字段的合并行为不同 | 中 |

## 第三部分：解决方案与风险控制

### 3.1 kustomization.yaml 语法错误

**问题现象**：`kustomize build` 报 YAML 解析错误。

**解决步骤**：

```bash
# 步骤 1: 检查 YAML 语法
cat kustomization.yaml
yamllint kustomization.yaml

# 步骤 2: 常见语法问题

# 问题 1: 缩进错误
# 错误
resources:
- deployment.yaml
  - service.yaml  # 缩进错误

# 正确
resources:
- deployment.yaml
- service.yaml

# 问题 2: apiVersion 错误
# 旧版本
apiVersion: kustomize.config.k8s.io/v1beta1  # 对于 Kustomization

# 问题 3: 字段名拼写错误
# 错误
resource:  # 应该是 resources

# 步骤 3: 使用格式化工具
kustomize cfg fmt kustomization.yaml
```

**正确的 kustomization.yaml 结构**：

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# 元数据
namespace: my-namespace  # 可选：设置所有资源的 namespace
namePrefix: dev-         # 可选：名称前缀
nameSuffix: -v1          # 可选：名称后缀

# 通用标签和注解
commonLabels:
  app: my-app
  env: dev

commonAnnotations:
  version: "1.0.0"

# 资源列表
resources:
- deployment.yaml
- service.yaml
- ../base  # 引用 base 目录

# 补丁
patches:
- path: patch.yaml
  target:
    kind: Deployment
    name: my-deployment

# 生成器
configMapGenerator:
- name: app-config
  files:
  - config.properties

secretGenerator:
- name: app-secret
  literals:
  - password=secret123

# 镜像替换
images:
- name: nginx
  newName: my-registry/nginx
  newTag: "1.21"
```

### 3.2 资源文件找不到

**问题现象**：`no such file or directory`

**解决步骤**：

```bash
# 步骤 1: 检查当前目录结构
tree .
ls -la

# 步骤 2: 验证 resources 中的路径
cat kustomization.yaml | grep -A20 "resources:"

# 步骤 3: 检查路径是否正确
# 相对路径是相对于 kustomization.yaml 所在目录
# 例如:
# .
# ├── kustomization.yaml
# ├── base/
# │   └── deployment.yaml
# └── overlays/
#     └── dev/
#         └── kustomization.yaml

# 在 overlays/dev/kustomization.yaml 中引用 base:
# resources:
# - ../../base  # 正确的相对路径

# 步骤 4: 使用绝对路径调试 (不推荐在生产使用)
pwd
# 确认路径关系
```

### 3.3 Patch 未应用/目标未找到

**问题现象**：补丁配置但未生效，或报 `no resources matched`。

**解决步骤**：

```bash
# 步骤 1: 检查 patch 的 target 配置
cat kustomization.yaml | grep -A10 "patches:"

# 步骤 2: 确认目标资源存在
kustomize build <base-path> | grep -E "kind:|name:"

# 步骤 3: 验证 target 选择器完全匹配
```

**Patch 配置示例**：

```yaml
# kustomization.yaml
patches:
# 方式 1: 内联 patch
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
  target:
    kind: Deployment
    name: my-deployment  # 必须与原资源名称完全匹配

# 方式 2: 外部文件 patch (Strategic Merge Patch)
- path: replica-patch.yaml
  target:
    kind: Deployment
    name: my-deployment

# 方式 3: 使用标签选择
- path: common-patch.yaml
  target:
    kind: Deployment
    labelSelector: "app=my-app"  # 匹配所有带此标签的 Deployment

# 方式 4: 匹配所有特定类型
- path: annotation-patch.yaml
  target:
    kind: Service
    # 不指定 name 则匹配所有 Service
```

```yaml
# replica-patch.yaml (Strategic Merge Patch 格式)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment  # 必须与目标名称匹配
spec:
  replicas: 5
```

```yaml
# json-patch.yaml (JSON Patch 格式)
- op: replace
  path: /spec/replicas
  value: 5
- op: add
  path: /metadata/annotations/patched
  value: "true"
```

### 3.4 namePrefix/nameSuffix 导致引用断裂

**问题现象**：Service 无法找到 Deployment 的 Pod。

**解决步骤**：

```bash
# 步骤 1: 检查输出中的资源名称
kustomize build <path> | grep "name:"

# 步骤 2: 检查 selector 是否更新
kustomize build <path> | grep -A10 "selector:"

# 步骤 3: 理解 namePrefix 的行为
# namePrefix 会自动更新:
# - Deployment 名称
# - Service 名称
# - Service 的 selector (如果引用了 Deployment)
# - ConfigMap/Secret 引用

# 但不会更新:
# - 硬编码在 Pod 中的服务名称
# - 外部系统的引用
```

**正确处理 namePrefix**：

```yaml
# kustomization.yaml
namePrefix: dev-

resources:
- deployment.yaml
- service.yaml

# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app  # 会变成 dev-my-app
spec:
  selector:
    matchLabels:
      app: my-app  # 标签不会改变
  template:
    metadata:
      labels:
        app: my-app  # 标签不会改变

# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app  # 会变成 dev-my-app
spec:
  selector:
    app: my-app  # 会正确匹配，因为基于 label 而非名称
```

### 3.5 ConfigMapGenerator 哈希后缀问题

**问题现象**：ConfigMap 名称带哈希，引用失效。

**解决步骤**：

```bash
# 步骤 1: 检查生成的 ConfigMap 名称
kustomize build <path> | grep -A5 "kind: ConfigMap"
# 名称会类似: app-config-abc123

# 步骤 2: 检查引用是否自动更新
kustomize build <path> | grep -A20 "kind: Deployment" | grep configMap

# Kustomize 会自动更新以下位置的引用:
# - envFrom[].configMapRef.name
# - env[].valueFrom.configMapKeyRef.name
# - volumes[].configMap.name
```

**禁用哈希后缀**：

```yaml
# kustomization.yaml
configMapGenerator:
- name: app-config
  files:
  - config.properties
  options:
    disableNameSuffixHash: true  # 禁用哈希后缀

# 或全局禁用
generatorOptions:
  disableNameSuffixHash: true
```

### 3.6 镜像替换不生效

**问题现象**：配置了 images 但镜像未更新。

**解决步骤**：

```bash
# 步骤 1: 检查 images 配置
cat kustomization.yaml | grep -A10 "images:"

# 步骤 2: 检查原始镜像名称
cat deployment.yaml | grep "image:"
# 必须与 images 中的 name 完全匹配

# 步骤 3: 验证输出
kustomize build <path> | grep "image:"
```

**镜像替换配置**：

```yaml
# kustomization.yaml
images:
# 完整替换
- name: nginx  # 原始镜像名称 (不含 tag)
  newName: my-registry.com/nginx
  newTag: "1.21"

# 只改 tag
- name: redis
  newTag: "6.2"

# 只改仓库
- name: postgres
  newName: my-registry.com/postgres

# 使用 digest
- name: mysql
  newName: my-registry.com/mysql
  digest: sha256:abc123...
```

```yaml
# deployment.yaml
# 原始配置
spec:
  containers:
  - name: web
    image: nginx  # 会被替换为 my-registry.com/nginx:1.21
  - name: cache
    image: redis:5.0  # 会被替换为 redis:6.2 (保留原 registry)
```

### 3.7 多环境配置问题

**问题现象**：不同环境的配置混乱或不正确。

**解决步骤**：

```bash
# 步骤 1: 检查目录结构
tree .
# 推荐结构:
# .
# ├── base/
# │   ├── kustomization.yaml
# │   ├── deployment.yaml
# │   └── service.yaml
# └── overlays/
#     ├── dev/
#     │   └── kustomization.yaml
#     ├── staging/
#     │   └── kustomization.yaml
#     └── prod/
#         └── kustomization.yaml

# 步骤 2: 比较各环境输出
diff <(kustomize build overlays/dev) <(kustomize build overlays/prod)

# 步骤 3: 验证环境特定配置
kustomize build overlays/dev | grep -E "replicas:|image:|env:"
```

**最佳实践目录结构**：

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
- configmap.yaml

# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../base

namespace: dev

namePrefix: dev-

patches:
- path: replica-patch.yaml

configMapGenerator:
- name: app-config
  behavior: merge
  literals:
  - LOG_LEVEL=debug

images:
- name: my-app
  newTag: dev-latest

# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../base

namespace: prod

namePrefix: prod-

patches:
- path: replica-patch.yaml
- path: resource-patch.yaml

configMapGenerator:
- name: app-config
  behavior: merge
  literals:
  - LOG_LEVEL=warn

images:
- name: my-app
  newTag: v1.0.0
```

### 3.8 组件 (Components) 使用问题

**问题现象**：可复用组件配置不正确。

**解决步骤**：

```bash
# 步骤 1: 检查组件定义
cat components/monitoring/kustomization.yaml
# kind 应该是 Component

# 步骤 2: 检查组件引用
cat overlays/dev/kustomization.yaml | grep -A5 "components:"
```

**组件配置示例**：

```yaml
# components/monitoring/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component  # 注意: 是 Component 不是 Kustomization

patches:
- path: add-sidecar.yaml
  target:
    kind: Deployment

configMapGenerator:
- name: monitoring-config
  literals:
  - METRICS_ENABLED=true

# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

components:
- ../../components/monitoring  # 引用组件
```

### 3.9 安全生产风险提示

| 操作 | 风险等级 | 潜在风险 | 建议措施 |
|------|----------|----------|----------|
| 修改 base | 高 | 影响所有环境 | 先在 dev 测试 |
| 修改 namePrefix | 高 | 可能导致引用断裂 | 检查所有引用 |
| 禁用哈希后缀 | 中 | 配置更新可能不触发 Pod 重启 | 使用 rollout restart |
| 删除 overlay | 中 | 可能影响部署流水线 | 确认无 CI/CD 依赖 |
| 升级 kustomize 版本 | 中 | 行为可能变化 | 先测试构建输出 |

### 附录：快速诊断命令

```bash
# ===== Kustomize 一键诊断脚本 =====

echo "=== Kustomize 版本 ==="
kustomize version 2>/dev/null || echo "kustomize 未安装"
kubectl version --client 2>/dev/null | grep -i kustomize

echo -e "\n=== 目录结构 ==="
tree . 2>/dev/null || find . -name "kustomization.yaml" -o -name "kustomization.yml"

echo -e "\n=== 构建测试 ==="
if [ -f "kustomization.yaml" ] || [ -f "kustomization.yml" ]; then
  kustomize build . 2>&1 | head -50
else
  echo "当前目录没有 kustomization.yaml"
fi

echo -e "\n=== 资源清单 ==="
if [ -f "kustomization.yaml" ]; then
  kustomize build . 2>/dev/null | grep "^kind:" | sort | uniq -c
fi

echo -e "\n=== Dry-run 验证 ==="
if [ -f "kustomization.yaml" ]; then
  kustomize build . 2>/dev/null | kubectl apply --dry-run=client -f - 2>&1 | head -20
fi
```

### 附录：常用 Kustomize 模式

```yaml
# 1. 环境变量覆盖
# patches/env-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: DATABASE_URL
          value: "postgres://prod-db:5432/app"

# 2. 资源限制补丁
# patches/resources-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: app
        resources:
          limits:
            cpu: "2"
            memory: "2Gi"
          requests:
            cpu: "500m"
            memory: "512Mi"

# 3. 副本数补丁 (JSON Patch)
# patches/replicas-patch.yaml
- op: replace
  path: /spec/replicas
  value: 5

# 在 kustomization.yaml 中使用 JSON Patch:
patches:
- path: patches/replicas-patch.yaml
  target:
    kind: Deployment
    name: my-app

# 4. 添加 Sidecar
# patches/sidecar-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: log-collector
        image: fluent/fluent-bit:latest
        volumeMounts:
        - name: varlog
          mountPath: /var/log
      volumes:
      - name: varlog
        emptyDir: {}

# 5. 替换整个文件
# kustomization.yaml
patchesStrategicMerge:
- deployment-override.yaml

# 6. 从文件生成 ConfigMap
configMapGenerator:
- name: app-config
  files:
  - application.properties
  - config/database.yaml
  literals:
  - EXTRA_CONFIG=value
```
