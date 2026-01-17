# 表格47: Helm Chart开发与管理

## Helm版本对比

| 版本 | K8s兼容性 | 特性 | 状态 |
|-----|----------|------|------|
| Helm 2 | v1.16以下 | Tiller服务端 | 已废弃 |
| Helm 3.0-3.12 | v1.18-v1.27 | 无Tiller | 维护中 |
| Helm 3.13+ | v1.26-v1.30 | OCI支持改进 | 当前稳定 |
| Helm 3.14+ | v1.27-v1.31 | JSON Schema验证 | 当前稳定 |
| Helm 3.16+ | v1.29-v1.32 | 最新特性 | 最新版本 |

## Chart目录结构

```
mychart/
├── Chart.yaml          # Chart元数据
├── Chart.lock          # 依赖锁定文件
├── values.yaml         # 默认配置值
├── values.schema.json  # 值验证Schema
├── .helmignore         # 忽略文件
├── templates/          # 模板目录
│   ├── NOTES.txt       # 安装说明
│   ├── _helpers.tpl    # 模板助手
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── serviceaccount.yaml
│   ├── hpa.yaml
│   └── tests/          # 测试
│       └── test-connection.yaml
├── charts/             # 依赖Chart
└── crds/               # CRD定义
```

## Chart.yaml配置

| 字段 | 类型 | 必需 | 说明 |
|-----|-----|-----|------|
| `apiVersion` | string | ✅ | v2 (Helm 3) |
| `name` | string | ✅ | Chart名称 |
| `version` | string | ✅ | Chart版本(SemVer) |
| `appVersion` | string | ❌ | 应用版本 |
| `description` | string | ❌ | 描述 |
| `type` | string | ❌ | application/library |
| `keywords` | []string | ❌ | 关键字 |
| `home` | string | ❌ | 项目主页 |
| `sources` | []string | ❌ | 源码地址 |
| `dependencies` | []Dependency | ❌ | 依赖Chart |
| `maintainers` | []Maintainer | ❌ | 维护者 |
| `icon` | string | ❌ | 图标URL |
| `deprecated` | bool | ❌ | 废弃标记 |
| `kubeVersion` | string | ❌ | K8s版本约束 |

## Chart.yaml示例

```yaml
apiVersion: v2
name: myapp
version: 1.0.0
appVersion: "2.0.0"
description: My Application Helm Chart
type: application
kubeVersion: ">=1.25.0-0"
keywords:
  - web
  - application
home: https://example.com
sources:
  - https://github.com/example/myapp
maintainers:
  - name: DevOps Team
    email: devops@example.com
dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
  - name: redis
    version: "17.x.x"
    repository: https://charts.bitnami.com/bitnami
    condition: redis.enabled
```

## 常用Helm命令

| 命令 | 说明 |
|-----|------|
| `helm create <name>` | 创建Chart骨架 |
| `helm lint <chart>` | 检查Chart语法 |
| `helm template <chart>` | 渲染模板 |
| `helm install <name> <chart>` | 安装Release |
| `helm upgrade <name> <chart>` | 升级Release |
| `helm rollback <name> <revision>` | 回滚版本 |
| `helm uninstall <name>` | 卸载Release |
| `helm list` | 列出Release |
| `helm history <name>` | 查看历史 |
| `helm get values <name>` | 获取配置值 |
| `helm get manifest <name>` | 获取清单 |
| `helm repo add <name> <url>` | 添加仓库 |
| `helm search repo <keyword>` | 搜索Chart |
| `helm dependency update` | 更新依赖 |
| `helm package <chart>` | 打包Chart |
| `helm push <chart> <repo>` | 推送到OCI仓库 |

## 模板函数

| 函数类别 | 常用函数 | 示例 |
|---------|---------|------|
| 字符串 | `upper`, `lower`, `title`, `trim` | `{{ .Values.name \| upper }}` |
| 默认值 | `default`, `coalesce` | `{{ .Values.port \| default 8080 }}` |
| 条件 | `ternary`, `empty` | `{{ ternary "yes" "no" .Values.enabled }}` |
| 列表 | `list`, `first`, `rest`, `join` | `{{ join "," .Values.hosts }}` |
| 字典 | `dict`, `get`, `set`, `merge` | `{{ get .Values "key" }}` |
| 编码 | `b64enc`, `b64dec`, `toJson` | `{{ .Values.secret \| b64enc }}` |
| 资源 | `toYaml`, `fromYaml` | `{{ toYaml .Values.resources \| nindent 12 }}` |
| 流程 | `include`, `tpl` | `{{ include "mychart.name" . }}` |

## 模板示例

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "mychart.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "mychart.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        ports:
        - containerPort: {{ .Values.service.port }}
        {{- with .Values.resources }}
        resources:
          {{- toYaml . | nindent 10 }}
        {{- end }}
```

## OCI仓库支持

```bash
# 登录OCI仓库
helm registry login registry.example.com

# 推送Chart
helm push mychart-1.0.0.tgz oci://registry.example.com/charts

# 拉取Chart
helm pull oci://registry.example.com/charts/mychart --version 1.0.0

# 安装
helm install myrelease oci://registry.example.com/charts/mychart
```

## ACK应用目录

| 功能 | 说明 |
|-----|------|
| 内置应用 | 预置常用Helm Chart |
| 私有仓库 | 支持ACR Helm仓库 |
| GitOps集成 | ArgoCD/FluxCD |
| 应用管理 | 控制台可视化管理 |
