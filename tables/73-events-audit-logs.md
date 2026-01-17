# 表格73: 事件与审计日志

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/tasks/debug/debug-cluster/audit](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)

## Kubernetes事件(Events)

| 字段 | 说明 |
|-----|------|
| `type` | Normal/Warning |
| `reason` | 事件原因(如Scheduled, Pulled, Created) |
| `message` | 事件详情 |
| `involvedObject` | 相关对象 |
| `source` | 事件来源组件 |
| `firstTimestamp` | 首次发生时间 |
| `lastTimestamp` | 最后发生时间 |
| `count` | 发生次数 |

## 常见事件类型

| 原因 | 类型 | 组件 | 说明 |
|-----|------|------|------|
| Scheduled | Normal | scheduler | Pod已调度 |
| Pulling | Normal | kubelet | 正在拉取镜像 |
| Pulled | Normal | kubelet | 镜像已拉取 |
| Created | Normal | kubelet | 容器已创建 |
| Started | Normal | kubelet | 容器已启动 |
| Killing | Normal | kubelet | 正在终止容器 |
| BackOff | Warning | kubelet | 容器重启退避 |
| Failed | Warning | kubelet | 容器启动失败 |
| FailedScheduling | Warning | scheduler | 调度失败 |
| Unhealthy | Warning | kubelet | 健康检查失败 |
| FailedMount | Warning | kubelet | 挂载失败 |
| OOMKilling | Warning | kubelet | 内存不足被杀 |
| NodeNotReady | Warning | controller | 节点未就绪 |
| Evicted | Warning | kubelet | Pod被驱逐 |

## 事件查看命令

```bash
# 查看所有事件
kubectl get events --sort-by='.lastTimestamp'

# 查看特定命名空间事件
kubectl get events -n production

# 查看特定Pod事件
kubectl describe pod <pod-name>

# 仅显示Warning事件
kubectl get events --field-selector type=Warning

# 实时监控事件
kubectl get events -w

# JSON格式输出
kubectl get events -o json

# 按对象过滤
kubectl get events --field-selector involvedObject.name=myapp
```

## 审计日志配置

| 日志级别 | 记录内容 |
|---------|---------|
| None | 不记录 |
| Metadata | 请求元数据(用户、时间、资源等) |
| Request | 元数据+请求体 |
| RequestResponse | 元数据+请求体+响应体 |

## 审计策略配置

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# 不审计只读操作
- level: None
  verbs: ["get", "list", "watch"]

# 不审计系统请求
- level: None
  users: ["system:kube-proxy"]

# Secret内容不记录
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]

# 认证相关请求详细记录
- level: RequestResponse
  resources:
  - group: "authentication.k8s.io"
    resources: ["tokenreviews"]

# 高危操作详细记录
- level: RequestResponse
  verbs: ["create", "update", "patch", "delete"]
  resources:
  - group: ""
    resources: ["pods", "services"]
  - group: "apps"
    resources: ["deployments", "statefulsets"]

# 默认记录元数据
- level: Metadata
```

## API Server审计参数

| 参数 | 说明 |
|-----|------|
| `--audit-policy-file` | 审计策略文件路径 |
| `--audit-log-path` | 日志文件路径 |
| `--audit-log-maxage` | 日志保留天数 |
| `--audit-log-maxbackup` | 保留文件数 |
| `--audit-log-maxsize` | 单文件最大MB |
| `--audit-webhook-config-file` | Webhook配置 |
| `--audit-webhook-batch-buffer-size` | Webhook批量缓冲 |

## 审计日志示例

```json
{
  "kind": "Event",
  "apiVersion": "audit.k8s.io/v1",
  "level": "RequestResponse",
  "auditID": "12345678-1234-1234-1234-123456789012",
  "stage": "ResponseComplete",
  "requestURI": "/api/v1/namespaces/default/pods",
  "verb": "create",
  "user": {
    "username": "admin@example.com",
    "groups": ["system:authenticated"]
  },
  "sourceIPs": ["192.168.1.100"],
  "objectRef": {
    "resource": "pods",
    "namespace": "default",
    "name": "nginx",
    "apiVersion": "v1"
  },
  "responseStatus": {
    "metadata": {},
    "code": 201
  },
  "requestReceivedTimestamp": "2024-01-15T10:30:00.000000Z",
  "stageTimestamp": "2024-01-15T10:30:00.100000Z"
}
```

## 审计Webhook配置

```yaml
apiVersion: v1
kind: Config
clusters:
- name: audit-webhook
  cluster:
    server: https://audit.example.com/audit
    certificate-authority: /etc/kubernetes/pki/audit-ca.crt
contexts:
- name: default
  context:
    cluster: audit-webhook
current-context: default
users:
- name: default
  user:
    token: <audit-token>
```

## Falco安全监控

```yaml
# Falco规则示例
- rule: Terminal shell in container
  desc: Detect shell opened in container
  condition: >
    spawned_process and container
    and shell_procs and proc.tty != 0
  output: >
    Shell opened (user=%user.name container=%container.id 
    shell=%proc.name)
  priority: WARNING
```

## 事件归档方案

| 方案 | 说明 |
|-----|------|
| Elasticsearch | EFK日志栈 |
| Loki | 轻量级日志 |
| 对象存储 | S3/OSS长期存储 |
| SIEM | 安全信息事件管理 |

## ACK审计日志

| 功能 | 说明 |
|-----|------|
| 控制平面审计 | 托管日志采集 |
| SLS集成 | 日志服务存储分析 |
| ActionTrail | 云账号操作审计 |
| 合规报告 | 自动生成审计报告 |

## 监控告警规则

| 事件类型 | 告警条件 | 优先级 |
|---------|---------|--------|
| OOMKilling | 发生 | 高 |
| FailedScheduling | 持续>5min | 中 |
| BackOff | count>10 | 中 |
| NodeNotReady | 发生 | 高 |
| FailedMount | 发生 | 高 |

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| v1.25 | 审计日志增强 |
| v1.27 | 审计性能优化 |
| v1.29 | Events API改进 |
