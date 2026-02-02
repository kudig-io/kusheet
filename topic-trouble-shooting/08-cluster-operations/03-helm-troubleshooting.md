# Helm 部署故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32, Helm v3.12+ | **最后更新**: 2026-01 | **难度**: 中级-高级
>
> **版本说明**:
> - Helm v3.12+ 支持 OCI registry 作为 chart 仓库
> - Helm v3.13+ 支持 JSON schema 验证改进
> - Helm v3.14+ 改进的 diff 和 upgrade 行为
> - Helm v2.x 已停止维护，务必使用 v3.x

## 概述

Helm 是 Kubernetes 的包管理工具，用于简化应用部署和管理。本文档覆盖 Helm Chart 安装、升级、回滚等操作中常见故障的诊断与解决方案。

---

## 第一部分：问题现象与影响分析

### 1.1 Helm 架构

```
┌─────────────────────────────────────────────────────────────────┐
│                      Helm 3 架构                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐                                               │
│  │  Helm CLI    │ ◄── helm install/upgrade/rollback             │
│  └──────┬───────┘                                               │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Chart 处理流程                               │   │
│  │  1. 读取 Chart 模板 (templates/)                          │   │
│  │  2. 合并 values (values.yaml + --set + -f)               │   │
│  │  3. 渲染 Kubernetes manifests                            │   │
│  │  4. 发送到 Kubernetes API Server                         │   │
│  └──────────────────────────────────────────────────────────┘   │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Release 存储                                 │   │
│  │  存储位置: Secret (默认) 或 ConfigMap                     │   │
│  │  内容: Release 元数据、渲染后的 manifests、values         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 错误信息示例 | 查看方式 |
|---------|---------|-------------|---------|
| 安装失败 | Release 未创建 | `Error: INSTALLATION FAILED` | `helm install` 输出 |
| 升级失败 | Release 状态异常 | `Error: UPGRADE FAILED` | `helm upgrade` 输出 |
| 回滚失败 | 无法恢复到旧版本 | `Error: rollback failed` | `helm rollback` 输出 |
| 渲染错误 | 模板语法问题 | `template: xxx: function "xxx" not defined` | `helm template` |
| 值覆盖问题 | 配置未生效 | 应用配置不符合预期 | `helm get values` |
| 资源冲突 | 资源已存在 | `resource already exists` | `helm install` 输出 |
| 超时 | 安装/升级超时 | `timed out waiting for the condition` | 命令输出 |
| 挂起状态 | Release 状态为 pending | `status: pending-install` | `helm list` |

### 1.3 Release 状态说明

| 状态 | 说明 | 处理方式 |
|-----|-----|---------|
| deployed | 正常部署 | 无需处理 |
| failed | 部署失败 | 检查错误、修复后重试 |
| pending-install | 安装中 | 等待或排查卡住原因 |
| pending-upgrade | 升级中 | 等待或排查卡住原因 |
| pending-rollback | 回滚中 | 等待或排查卡住原因 |
| superseded | 已被新版本替代 | 历史版本，无需处理 |
| uninstalled | 已卸载 | 已清理 |

### 1.4 影响分析

| 故障类型 | 直接影响 | 间接影响 | 影响范围 |
|---------|---------|---------|---------|
| 安装失败 | 应用无法部署 | 服务不可用 | 目标命名空间 |
| 升级失败 | 新版本无法生效 | 停留在旧版本 | 目标 Release |
| 回滚失败 | 无法恢复稳定版本 | 服务持续异常 | 目标 Release |
| Release 状态异常 | 后续操作受阻 | 需要手动修复 | 目标 Release |

---

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
Helm 部署故障
      │
      ├─── 安装/升级失败？
      │         │
      │         ├─ 模板错误 ──→ helm template 检查
      │         ├─ 资源错误 ──→ 检查 Kubernetes 资源状态
      │         ├─ 权限不足 ──→ 检查 RBAC
      │         └─ 超时 ──→ 增加超时/检查资源状态
      │
      ├─── Release 状态异常？
      │         │
      │         ├─ pending 状态 ──→ 检查后台操作/手动修复
      │         ├─ failed 状态 ──→ 分析失败原因/重新部署
      │         └─ 无法卸载 ──→ 检查 hooks/finalizers
      │
      └─── 配置未生效？
                │
                ├─ values 优先级 ──→ 检查 --set/-f 顺序
                ├─ 模板渲染 ──→ helm get manifest 检查
                └─ 缓存问题 ──→ helm repo update
```

### 2.2 排查命令集

#### 2.2.1 Release 状态检查

```bash
# 列出所有 Release
helm list -A

# 列出特定命名空间的 Release
helm list -n <namespace>

# 列出所有状态的 Release (包括失败的)
helm list -A --all

# 查看 Release 详情
helm status <release-name> -n <namespace>

# 查看 Release 历史
helm history <release-name> -n <namespace>
```

#### 2.2.2 模板和配置检查

```bash
# 渲染模板但不安装 (检查模板语法)
helm template <release-name> <chart> -n <namespace> --values values.yaml

# 渲染并显示生成的 manifests
helm template <release-name> <chart> -n <namespace> --debug

# 查看 Release 实际使用的 values
helm get values <release-name> -n <namespace>

# 查看所有 values (包括默认值)
helm get values <release-name> -n <namespace> --all

# 查看 Release 的 manifest
helm get manifest <release-name> -n <namespace>

# 查看 Release 的 hooks
helm get hooks <release-name> -n <namespace>

# 查看 Release 的所有信息
helm get all <release-name> -n <namespace>
```

#### 2.2.3 Chart 检查

```bash
# 检查 Chart 结构
helm lint <chart-path>

# 显示 Chart 信息
helm show chart <chart>
helm show values <chart>
helm show readme <chart>

# 下载 Chart 查看内容
helm pull <chart> --untar

# 更新仓库索引
helm repo update

# 搜索 Chart
helm search repo <keyword>
helm search hub <keyword>
```

#### 2.2.4 调试模式

```bash
# 安装时启用调试
helm install <release> <chart> -n <namespace> --debug --dry-run

# 升级时启用调试
helm upgrade <release> <chart> -n <namespace> --debug --dry-run

# 详细输出
helm install <release> <chart> -n <namespace> --debug 2>&1 | tee helm-debug.log
```

### 2.3 排查注意事项

| 注意事项 | 说明 |
|---------|-----|
| 命名空间 | Release 是命名空间级别的 |
| values 优先级 | --set > -f (后面覆盖前面) |
| hooks 执行 | pre-install/post-install/pre-upgrade 等 |
| 原子操作 | --atomic 失败时自动回滚 |
| 等待资源 | --wait 等待资源就绪 |

---

## 第三部分：解决方案与风险控制

### 3.1 安装失败

#### 场景 1：模板渲染错误

**问题现象：**
```
Error: INSTALLATION FAILED: template: mychart/templates/deployment.yaml:15: 
  function "toYaml" not defined
```

**解决步骤：**

```bash
# 1. 本地渲染检查模板
helm template <release> <chart> --debug 2>&1 | head -50

# 2. 检查模板语法
helm lint <chart-path>

# 3. 常见模板错误

# 错误 A: 函数未定义
# 检查 Helm 版本和 Chart 要求
helm version

# 错误 B: 缩进问题
# YAML 缩进错误
# 使用 nindent 而非 indent
{{ .Values.config | toYaml | nindent 4 }}

# 错误 C: 空值处理
# 添加默认值
{{ .Values.replicas | default 1 }}

# 错误 D: 类型问题
# 确保正确引用
replicas: {{ .Values.replicas }}  # 数字
name: {{ .Values.name | quote }}   # 字符串

# 4. 使用 --dry-run 测试
helm install <release> <chart> --dry-run --debug
```

#### 场景 2：资源已存在冲突

**问题现象：**
```
Error: INSTALLATION FAILED: cannot re-use a name that is still in use
# 或
Error: rendered manifests contain a resource that already exists
```

**解决步骤：**

```bash
# 1. 检查是否有同名 Release
helm list -A | grep <release-name>

# 2. 检查资源是否存在
kubectl get all -n <namespace> -l app.kubernetes.io/instance=<release-name>

# 3. 方案 A: 卸载旧 Release
helm uninstall <release-name> -n <namespace>

# 4. 方案 B: 使用不同名称
helm install <new-release-name> <chart> -n <namespace>

# 5. 方案 C: 采用现有资源 (Helm 3.2+)
helm install <release> <chart> --adopt-existing-resources

# 6. 方案 D: 如果是孤立资源，添加 Helm 标签
kubectl label <resource> <name> \
  app.kubernetes.io/managed-by=Helm \
  meta.helm.sh/release-name=<release> \
  meta.helm.sh/release-namespace=<namespace>
kubectl annotate <resource> <name> \
  meta.helm.sh/release-name=<release> \
  meta.helm.sh/release-namespace=<namespace>
```

#### 场景 3：安装超时

**问题现象：**
```
Error: timed out waiting for the condition
```

**解决步骤：**

```bash
# 1. 增加超时时间
helm install <release> <chart> -n <namespace> --timeout 10m

# 2. 不等待资源就绪
helm install <release> <chart> -n <namespace> --wait=false

# 3. 检查资源状态
kubectl get pods -n <namespace> -l app.kubernetes.io/instance=<release>
kubectl describe pod <pod-name> -n <namespace>

# 4. 常见超时原因
# - 镜像拉取慢
# - 健康检查配置不当
# - 依赖服务未就绪
# - 资源不足无法调度

# 5. 检查事件
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### 3.2 升级失败

#### 场景 1：升级失败后修复

**问题现象：**
```
Error: UPGRADE FAILED: another operation is in progress
# 或
Release status: failed
```

**解决步骤：**

```bash
# 1. 检查 Release 状态
helm status <release> -n <namespace>
helm history <release> -n <namespace>

# 2. 如果是 pending 状态卡住
# 检查 Release Secret
kubectl get secret -n <namespace> -l owner=helm,name=<release>

# 3. 回滚到上一个成功版本
helm rollback <release> <revision> -n <namespace>

# 4. 如果回滚也失败，强制修复
# 删除失败的 Release Secret
kubectl delete secret -n <namespace> sh.helm.release.v1.<release>.v<version>

# 5. 重新安装 (如果可以接受重建)
helm uninstall <release> -n <namespace>
helm install <release> <chart> -n <namespace> -f values.yaml
```

#### 场景 2：使用原子升级

```bash
# 使用 --atomic 标志，失败时自动回滚
helm upgrade <release> <chart> -n <namespace> \
  --atomic \
  --timeout 10m \
  -f values.yaml

# 或使用 --install 标志，不存在时安装
helm upgrade --install <release> <chart> -n <namespace> \
  --atomic \
  -f values.yaml
```

### 3.3 回滚问题

#### 场景 1：回滚到指定版本

```bash
# 1. 查看历史版本
helm history <release> -n <namespace>

# 2. 回滚到指定版本
helm rollback <release> <revision> -n <namespace>

# 3. 回滚到上一个版本
helm rollback <release> 0 -n <namespace>

# 4. 回滚时启用调试
helm rollback <release> <revision> -n <namespace> --debug

# 5. 等待回滚完成
helm rollback <release> <revision> -n <namespace> --wait --timeout 5m
```

#### 场景 2：回滚失败处理

```bash
# 1. 检查回滚目标版本的 manifest
helm get manifest <release> -n <namespace> --revision <revision>

# 2. 检查资源差异
helm diff rollback <release> <revision> -n <namespace>  # 需要 helm-diff 插件

# 3. 如果 Release 损坏，手动重建
# 导出当前配置
helm get values <release> -n <namespace> -o yaml > values-backup.yaml
helm get manifest <release> -n <namespace> > manifest-backup.yaml

# 删除 Release (保留资源)
helm uninstall <release> -n <namespace> --keep-history

# 重新安装
helm install <release> <chart> -n <namespace> -f values-backup.yaml
```

### 3.4 配置问题

#### 场景 1：Values 优先级

```bash
# values 优先级 (从低到高):
# 1. Chart 默认 values.yaml
# 2. 父 Chart 的 values
# 3. -f/--values 文件 (按顺序，后面覆盖前面)
# 4. --set 参数 (按顺序，后面覆盖前面)

# 示例: 后面的覆盖前面的
helm install myapp ./chart \
  -f values-base.yaml \
  -f values-prod.yaml \
  --set image.tag=v2.0.0 \
  --set replicas=3

# 检查最终使用的 values
helm get values <release> -n <namespace> --all

# 仅查看用户设置的 values
helm get values <release> -n <namespace>
```

#### 场景 2：复杂值设置

```bash
# 设置嵌套值
helm install myapp ./chart \
  --set 'server.config.database\.host=mysql.example.com'

# 设置数组
helm install myapp ./chart \
  --set 'ingress.hosts[0].host=example.com' \
  --set 'ingress.hosts[0].paths[0].path=/'

# 设置多行字符串 (使用文件)
helm install myapp ./chart \
  --set-file 'config=./config.yaml'

# 设置 JSON
helm install myapp ./chart \
  --set-json 'resources={"limits":{"cpu":"1","memory":"512Mi"}}'
```

### 3.5 Hooks 问题

#### 场景 1：Hook 执行失败

**问题现象：**
安装/升级卡在 hook 执行阶段

**解决步骤：**

```bash
# 1. 查看 hooks
helm get hooks <release> -n <namespace>

# 2. 检查 hook Job/Pod 状态
kubectl get jobs -n <namespace> -l app.kubernetes.io/instance=<release>
kubectl get pods -n <namespace> -l job-name=<hook-job>

# 3. 查看 hook 日志
kubectl logs -n <namespace> -l job-name=<hook-job>

# 4. 跳过 hooks (谨慎使用)
helm upgrade <release> <chart> -n <namespace> --no-hooks

# 5. 删除失败的 hook Job
kubectl delete job -n <namespace> <hook-job-name>
```

### 3.6 仓库问题

#### 场景 1：Chart 下载失败

```bash
# 1. 更新仓库索引
helm repo update

# 2. 检查仓库配置
helm repo list

# 3. 添加/更新仓库
helm repo add <name> <url>
helm repo add <name> <url> --username <user> --password <pass>

# 4. 清理缓存
rm -rf ~/.cache/helm/repository

# 5. 使用代理
export HTTPS_PROXY=http://proxy:port
helm repo update
```

### 3.7 完整的 Helm 操作示例

```bash
# 标准安装流程
# 1. 添加仓库
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 2. 搜索 Chart
helm search repo nginx

# 3. 查看 Chart 配置项
helm show values bitnami/nginx > nginx-values.yaml

# 4. 编辑配置
vim nginx-values.yaml

# 5. 安装 (dry-run 先验证)
helm install nginx bitnami/nginx -n web --create-namespace \
  -f nginx-values.yaml \
  --dry-run --debug

# 6. 正式安装
helm install nginx bitnami/nginx -n web \
  -f nginx-values.yaml \
  --atomic \
  --timeout 10m

# 7. 验证
helm status nginx -n web
kubectl get all -n web

# 8. 升级
helm upgrade nginx bitnami/nginx -n web \
  -f nginx-values.yaml \
  --set image.tag=1.25.0 \
  --atomic

# 9. 回滚 (如需要)
helm rollback nginx 1 -n web

# 10. 卸载
helm uninstall nginx -n web
```

---

### 3.8 安全生产风险提示

| 操作 | 风险等级 | 风险说明 | 建议 |
|-----|---------|---------|-----|
| helm upgrade 无 --atomic | 中 | 失败后可能处于不一致状态 | 始终使用 --atomic |
| 删除 Release Secret | 高 | 丢失 Release 历史和元数据 | 仅在必要时执行 |
| --no-hooks | 中 | 跳过重要初始化步骤 | 了解 hooks 作用后使用 |
| 强制卸载 | 中 | 可能遗留孤立资源 | 检查并清理残留资源 |
| 生产环境升级 | 中 | 服务可能中断 | 先在测试环境验证 |

---

## 附录

### 常用命令速查

```bash
# 仓库管理
helm repo add <name> <url>
helm repo update
helm repo list
helm search repo <keyword>

# Release 管理
helm install <release> <chart> -n <ns>
helm upgrade <release> <chart> -n <ns>
helm rollback <release> <revision> -n <ns>
helm uninstall <release> -n <ns>

# 查看信息
helm list -A
helm status <release> -n <ns>
helm history <release> -n <ns>
helm get values <release> -n <ns>
helm get manifest <release> -n <ns>

# 调试
helm template <release> <chart> --debug
helm lint <chart>
helm install <release> <chart> --dry-run --debug
```

### 相关文档

- [Pod 故障排查](../05-workloads/01-pod-troubleshooting.md)
- [Deployment 故障排查](../05-workloads/02-deployment-troubleshooting.md)
- [ConfigMap/Secret 故障排查](../05-workloads/06-configmap-secret-troubleshooting.md)
