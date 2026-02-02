# 审计日志故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 高级
>
> **版本说明**:
> - v1.25+ 审计日志支持 omitManagedFields 减少日志体积
> - v1.27+ 支持 audit.k8s.io/v1 的 impersonatedUser 字段
> - 审计级别: None < Metadata < Request < RequestResponse

---

## 第一部分：问题现象与影响分析

### 1.1 Kubernetes 审计日志架构

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    Kubernetes 审计日志系统                               │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌────────────────────────────────────────────────────────────────┐    │
│   │                       API 请求                                  │    │
│   │                                                                 │    │
│   │    用户/SA ──► kubectl/client-go ──► API Server                │    │
│   │                                                                 │    │
│   └────────────────────────────┬───────────────────────────────────┘    │
│                                │                                         │
│                                ▼                                         │
│   ┌────────────────────────────────────────────────────────────────┐    │
│   │                    API Server 审计模块                          │    │
│   │                                                                 │    │
│   │   ┌──────────────────────────────────────────────────────┐    │    │
│   │   │              审计策略 (Audit Policy)                  │    │    │
│   │   │                                                       │    │    │
│   │   │  定义:                                                │    │    │
│   │   │  - 哪些请求需要记录                                   │    │    │
│   │   │  - 记录到什么级别 (None/Metadata/Request/RequestResp) │    │    │
│   │   │  - 基于用户/资源/namespace 的规则                     │    │    │
│   │   │                                                       │    │    │
│   │   └──────────────────────────────────────────────────────┘    │    │
│   │                         │                                      │    │
│   │                         ▼                                      │    │
│   │   ┌──────────────────────────────────────────────────────┐    │    │
│   │   │              审计后端 (Audit Backend)                 │    │    │
│   │   │                                                       │    │    │
│   │   │  ┌────────────────┐    ┌────────────────────────┐   │    │    │
│   │   │  │   Log Backend  │    │   Webhook Backend      │   │    │    │
│   │   │  │   (文件日志)   │    │   (外部接收器)         │   │    │    │
│   │   │  │                │    │                        │   │    │    │
│   │   │  │ --audit-log-   │    │ --audit-webhook-      │   │    │    │
│   │   │  │  path          │    │  config-file          │   │    │    │
│   │   │  └───────┬────────┘    └───────────┬────────────┘   │    │    │
│   │   │          │                         │                 │    │    │
│   │   └──────────┼─────────────────────────┼─────────────────┘    │    │
│   │              │                         │                       │    │
│   └──────────────┼─────────────────────────┼───────────────────────┘    │
│                  │                         │                             │
│                  ▼                         ▼                             │
│   ┌────────────────────────┐   ┌────────────────────────────────────┐  │
│   │     本地审计日志       │   │       外部审计接收系统              │  │
│   │                        │   │                                    │  │
│   │  /var/log/kubernetes/  │   │  - Elasticsearch                   │  │
│   │    audit.log           │   │  - Splunk                          │  │
│   │                        │   │  - 云日志服务                       │  │
│   │  (需要日志轮转和       │   │  - SIEM 系统                        │  │
│   │   收集器处理)          │   │                                    │  │
│   └────────────────────────┘   └────────────────────────────────────┘  │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

审计事件阶段:
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│   请求 ───► RequestReceived ───► ResponseStarted ───► ResponseComplete │
│     │              │                    │                    │          │
│     │              ▼                    ▼                    ▼          │
│     │         记录请求              记录响应开始        记录完整响应   │
│     │         阶段                  (长连接)             阶段          │
│     │                                                                   │
│     └───► Panic (如果发生)                                              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

审计级别:
┌───────────────────────────────────────────────────────────────────────┐
│                                                                       │
│   None        - 不记录                                                │
│   Metadata    - 只记录请求元数据 (用户、时间戳、资源、动词等)        │
│   Request     - 记录元数据 + 请求体                                   │
│   RequestResp - 记录元数据 + 请求体 + 响应体                          │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 错误信息 | 查看方式 |
|----------|----------|----------|----------|
| 审计日志未生成 | 日志文件为空或不存在 | 无 | 检查日志文件 |
| API Server 启动失败 | 因审计配置错误无法启动 | audit policy 错误 | API Server 日志 |
| 日志级别不正确 | 记录了过多或过少信息 | 无 | 检查审计日志内容 |
| 日志文件过大 | 磁盘空间耗尽 | No space left | 系统监控 |
| Webhook 发送失败 | 审计事件丢失 | context deadline | API Server 日志 |
| 日志格式异常 | 无法解析日志 | JSON 解析错误 | 日志处理系统 |
| 性能影响 | API 响应变慢 | 无 | 延迟监控 |
| 敏感信息泄露 | 日志包含 Secret 内容 | 无 | 审计日志审查 |

### 1.3 影响分析

| 问题类型 | 直接影响 | 间接影响 | 影响范围 |
|----------|----------|----------|----------|
| 审计日志缺失 | 无法审计追踪 | 合规性问题 | 安全/合规 |
| 配置错误 | API Server 异常 | 集群不可用 | 整个集群 |
| 磁盘空间问题 | 节点 NotReady | 服务中断 | 控制平面节点 |
| 性能问题 | API 延迟增加 | 操作变慢 | 所有 API 请求 |
| 敏感信息泄露 | 安全风险 | 合规违规 | 安全边界 |

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
审计日志问题
        │
        ▼
┌───────────────────────┐
│  问题类型是什么？      │
└───────────────────────┘
        │
        ├── 审计日志不生成 ──────────────────────────────────┐
        │                                                     │
        │   ┌─────────────────────────────────────────┐      │
        │   │ 检查 API Server 启动参数                │      │
        │   │ 是否配置了审计                          │      │
        │   └─────────────────────────────────────────┘      │
        │                  │                                  │
        │                  ▼                                  │
        │   ┌─────────────────────────────────────────┐      │
        │   │ --audit-policy-file 是否配置?           │      │
        │   └─────────────────────────────────────────┘      │
        │          │                │                         │
        │         否               是                         │
        │          │                │                         │
        │          ▼                ▼                         │
        │   ┌────────────┐   ┌────────────────┐              │
        │   │ 需要配置   │   │ 检查策略文件   │              │
        │   │ 审计参数   │   │ 和后端配置     │              │
        │   └────────────┘   └────────────────┘              │
        │                                                     │
        ├── 日志内容不正确 ──────────────────────────────────┤
        │                                                     │
        │   ┌─────────────────────────────────────────┐      │
        │   │ 检查审计策略规则                        │      │
        │   │ 确认级别和匹配条件                      │      │
        │   └─────────────────────────────────────────┘      │
        │                  │                                  │
        │                  ▼                                  │
        │   ┌─────────────────────────────────────────┐      │
        │   │ 规则匹配顺序是否正确?                   │      │
        │   │ (第一个匹配的规则生效)                  │      │
        │   └─────────────────────────────────────────┘      │
        │                                                     │
        ├── Webhook 问题 ────────────────────────────────────┤
        │                                                     │
        │   ┌─────────────────────────────────────────┐      │
        │   │ 检查 Webhook 配置和目标服务             │      │
        │   └─────────────────────────────────────────┘      │
        │                  │                                  │
        │                  ▼                                  │
        │   ┌─────────────────────────────────────────┐      │
        │   │ 目标服务是否可达?                       │      │
        │   │ TLS 证书是否正确?                       │      │
        │   └─────────────────────────────────────────┘      │
        │                                                     │
        └── 性能/存储问题 ───────────────────────────────────┤
                                                              │
            ┌─────────────────────────────────────────┐      │
            │ 检查日志量和存储使用                    │      │
            │ 检查日志轮转配置                        │      │
            └─────────────────────────────────────────┘      │
                                                              │
                                                              ▼
                                                       ┌────────────┐
                                                       │ 问题定位   │
                                                       │ 完成       │
                                                       └────────────┘
```

### 2.2 排查命令集

#### API Server 配置检查

```bash
# 检查 API Server 进程参数
# 在控制平面节点上
ps aux | grep kube-apiserver | grep audit

# 或查看 static pod 配置
cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -A5 audit

# 检查审计相关参数
# --audit-policy-file       # 审计策略文件
# --audit-log-path          # 日志文件路径
# --audit-log-maxage        # 保留天数
# --audit-log-maxbackup     # 保留文件数
# --audit-log-maxsize       # 单文件最大 MB
# --audit-webhook-config-file  # Webhook 配置文件
```

#### 审计日志检查

```bash
# 查看审计日志文件
ls -la /var/log/kubernetes/
ls -la /var/log/audit/  # 某些发行版的路径

# 查看最近的审计日志
tail -100 /var/log/kubernetes/audit.log

# 统计审计事件
cat /var/log/kubernetes/audit.log | jq -r '.verb' | sort | uniq -c

# 按用户统计
cat /var/log/kubernetes/audit.log | jq -r '.user.username' | sort | uniq -c

# 查找特定资源的审计事件
cat /var/log/kubernetes/audit.log | jq 'select(.objectRef.resource == "secrets")'

# 查找特定用户的操作
cat /var/log/kubernetes/audit.log | jq 'select(.user.username == "admin")'

# 查找失败的请求
cat /var/log/kubernetes/audit.log | jq 'select(.responseStatus.code >= 400)'
```

#### 审计策略验证

```bash
# 检查审计策略文件语法
# 策略文件通常在 /etc/kubernetes/audit-policy.yaml
cat /etc/kubernetes/audit-policy.yaml

# 验证 YAML 语法
python3 -c "import yaml; yaml.safe_load(open('/etc/kubernetes/audit-policy.yaml'))"

# 检查策略是否被正确加载 (API Server 日志)
journalctl -u kube-apiserver | grep -i audit
```

### 2.3 排查注意事项

| 注意事项 | 说明 | 风险等级 |
|----------|------|----------|
| 修改审计配置需重启 API Server | 静态 Pod 会自动重启 | 高 |
| 审计级别影响性能 | RequestResponse 级别会记录响应体 | 中 |
| Secret 内容可能被记录 | Request/RequestResponse 级别 | 高 |
| 日志轮转配置重要 | 避免磁盘空间耗尽 | 高 |
| Webhook 超时影响 API 延迟 | 配置合理的超时时间 | 中 |

## 第三部分：解决方案与风险控制

### 3.1 启用审计日志

**问题现象**：审计日志未配置或未生效。

**解决步骤**：

```bash
# 步骤 1: 创建审计策略文件
cat > /etc/kubernetes/audit-policy.yaml << 'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # 不记录对健康检查的请求
  - level: None
    nonResourceURLs:
    - /healthz*
    - /livez*
    - /readyz*
  
  # 不记录对 kube-system 中 endpoints, services, configmaps 的 watch
  - level: None
    users:
    - system:kube-proxy
    verbs:
    - watch
    resources:
    - endpoints
    - services
    - services/status
  
  # 不记录 kubelet 的节点状态更新
  - level: None
    users:
    - kubelet
    - system:node-*
    - system:serviceaccount:kube-system:*
    verbs:
    - get
    - update
    resources:
    - nodes/status
    - pods/status
  
  # Secrets, ConfigMaps, TokenReviews 只记录元数据 (不记录内容)
  - level: Metadata
    resources:
    - group: ""
      resources: ["secrets", "configmaps", "serviceaccounts/token"]
    - group: authentication.k8s.io
      resources: ["tokenreviews"]
  
  # 对于已知的只读请求，只记录 Metadata
  - level: Request
    users:
    - system:serviceaccount:kube-system:*
    verbs:
    - get
    - list
    - watch
  
  # 默认记录 Request 级别
  - level: Request
    resources:
    - group: ""  # core API
    - group: "apps"
    - group: "batch"
    - group: "rbac.authorization.k8s.io"
  
  # 兜底规则 - 记录所有其他请求的元数据
  - level: Metadata
    omitStages:
    - RequestReceived
EOF

# 步骤 2: 修改 API Server 配置
# 编辑 /etc/kubernetes/manifests/kube-apiserver.yaml
```

**API Server 配置示例**：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - name: kube-apiserver
    command:
    - kube-apiserver
    # ... 其他参数 ...
    
    # 审计配置
    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit.log
    - --audit-log-maxage=30        # 保留 30 天
    - --audit-log-maxbackup=10     # 保留 10 个备份文件
    - --audit-log-maxsize=100      # 每个文件最大 100MB
    
    volumeMounts:
    - mountPath: /etc/kubernetes/audit-policy.yaml
      name: audit-policy
      readOnly: true
    - mountPath: /var/log/kubernetes
      name: audit-log
  
  volumes:
  - hostPath:
      path: /etc/kubernetes/audit-policy.yaml
      type: File
    name: audit-policy
  - hostPath:
      path: /var/log/kubernetes
      type: DirectoryOrCreate
    name: audit-log
```

```bash
# 步骤 3: 等待 API Server 重启并验证
kubectl get pods -n kube-system | grep apiserver

# 检查审计日志是否生成
ls -la /var/log/kubernetes/audit.log
tail -10 /var/log/kubernetes/audit.log
```

### 3.2 配置审计 Webhook

**问题现象**：需要将审计日志发送到外部系统。

**解决步骤**：

```bash
# 步骤 1: 创建 Webhook kubeconfig 文件
cat > /etc/kubernetes/audit-webhook-kubeconfig.yaml << 'EOF'
apiVersion: v1
kind: Config
clusters:
- name: audit-webhook
  cluster:
    server: https://audit-receiver.example.com/audit
    certificate-authority: /etc/kubernetes/pki/audit-webhook-ca.crt
contexts:
- name: audit-webhook
  context:
    cluster: audit-webhook
current-context: audit-webhook
EOF

# 步骤 2: 在 API Server 添加 Webhook 参数
# --audit-webhook-config-file=/etc/kubernetes/audit-webhook-kubeconfig.yaml
# --audit-webhook-initial-backoff=10s
# --audit-webhook-mode=batch  # 或 blocking

# 步骤 3: Webhook 模式说明
# batch: 异步批量发送，对性能影响小
# blocking: 同步发送，保证不丢失但影响性能
```

**API Server Webhook 配置**：

```yaml
# 添加到 kube-apiserver.yaml
command:
- kube-apiserver
# ... 其他参数 ...
- --audit-webhook-config-file=/etc/kubernetes/audit-webhook-kubeconfig.yaml
- --audit-webhook-initial-backoff=10s
- --audit-webhook-batch-buffer-size=10000
- --audit-webhook-batch-max-size=1000
- --audit-webhook-batch-max-wait=30s
- --audit-webhook-mode=batch
```

### 3.3 排查审计日志丢失

**问题现象**：某些操作在审计日志中找不到。

**解决步骤**：

```bash
# 步骤 1: 检查审计策略规则
cat /etc/kubernetes/audit-policy.yaml

# 步骤 2: 确认规则顺序 (第一个匹配的生效)
# 可能被前面的 level: None 规则过滤掉了

# 步骤 3: 临时启用全量日志排查
# 在策略末尾添加 catch-all 规则
```

**调试用审计策略**：

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# 先保留现有规则
# ...

# 添加 catch-all 规则用于调试
- level: Request
  # 记录所有未匹配的请求
```

```bash
# 步骤 4: 查找特定请求
# 例如：查找对 secret 的 create 操作
cat /var/log/kubernetes/audit.log | jq 'select(.verb == "create" and .objectRef.resource == "secrets")'
```

### 3.4 处理日志文件过大

**问题现象**：审计日志占用大量磁盘空间。

**解决步骤**：

```bash
# 步骤 1: 检查当前日志大小
du -sh /var/log/kubernetes/
ls -lh /var/log/kubernetes/audit*

# 步骤 2: 调整日志轮转参数
# --audit-log-maxage=7     # 减少保留天数
# --audit-log-maxbackup=5  # 减少备份数
# --audit-log-maxsize=50   # 减小单文件大小

# 步骤 3: 优化审计策略减少日志量
```

**减少日志量的策略示例**：

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# 排除高频率的只读请求
- level: None
  users:
  - system:serviceaccount:kube-system:*
  verbs:
  - get
  - list
  - watch
  resources:
  - group: ""
    resources: ["configmaps", "endpoints", "services"]

# 排除 node 心跳
- level: None
  users:
  - system:nodes
  - kubelet
  verbs:
  - update
  - patch
  resources:
  - group: ""
    resources: ["nodes/status"]

# 只记录写操作
- level: Request
  verbs:
  - create
  - update
  - patch
  - delete
  - deletecollection

# 读操作只记录元数据
- level: Metadata
  verbs:
  - get
  - list
  - watch

# 兜底规则
- level: Metadata
```

### 3.5 保护敏感信息

**问题现象**：审计日志中包含 Secret 内容等敏感信息。

**解决步骤**：

```yaml
# 确保敏感资源只记录 Metadata 级别
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Secret 和相关敏感资源 - 只记录元数据
- level: Metadata
  resources:
  - group: ""
    resources:
    - secrets
    - configmaps
    - serviceaccounts/token
  - group: authentication.k8s.io
    resources:
    - tokenreviews
    - tokenrequests

# 其他资源可以记录请求体
- level: Request
  resources:
  - group: ""
    resources: ["*"]
```

**注意事项**：
- `level: Metadata` 不会记录请求/响应体
- `level: Request` 会记录请求体（包括 Secret 内容）
- `level: RequestResponse` 会记录请求和响应体

### 3.6 审计 Webhook 故障

**问题现象**：Webhook 发送失败，审计事件丢失。

**解决步骤**：

```bash
# 步骤 1: 检查 API Server 日志
journalctl -u kube-apiserver | grep -i "audit\|webhook"

# 常见错误:
# - "context deadline exceeded" - 超时
# - "connection refused" - 目标不可达
# - "x509: certificate" - 证书问题

# 步骤 2: 测试 Webhook 端点
curl -v https://audit-receiver.example.com/audit

# 步骤 3: 检查证书配置
openssl s_client -connect audit-receiver.example.com:443

# 步骤 4: 调整超时和重试配置
# --audit-webhook-initial-backoff=10s
# --audit-webhook-batch-max-wait=30s
```

### 3.7 审计日志分析

**常用分析命令**：

```bash
# 统计各类操作
cat /var/log/kubernetes/audit.log | jq -r '.verb' | sort | uniq -c | sort -rn

# 统计各用户活动
cat /var/log/kubernetes/audit.log | jq -r '.user.username' | sort | uniq -c | sort -rn

# 查找失败的请求
cat /var/log/kubernetes/audit.log | jq 'select(.responseStatus.code >= 400)' | jq '{user: .user.username, verb: .verb, resource: .objectRef.resource, code: .responseStatus.code}'

# 查找特定时间范围的事件
cat /var/log/kubernetes/audit.log | jq 'select(.requestReceivedTimestamp >= "2024-01-01T00:00:00Z" and .requestReceivedTimestamp <= "2024-01-02T00:00:00Z")'

# 查找对敏感资源的操作
cat /var/log/kubernetes/audit.log | jq 'select(.objectRef.resource == "secrets" and .verb != "list" and .verb != "watch")'

# 查找权限拒绝事件
cat /var/log/kubernetes/audit.log | jq 'select(.responseStatus.code == 403)'

# 导出为 CSV 便于分析
cat /var/log/kubernetes/audit.log | jq -r '[.requestReceivedTimestamp, .user.username, .verb, .objectRef.resource, .objectRef.namespace, .objectRef.name, .responseStatus.code] | @csv'
```

### 3.8 安全生产风险提示

| 操作 | 风险等级 | 潜在风险 | 建议措施 |
|------|----------|----------|----------|
| 启用 RequestResponse 级别 | 高 | 可能记录敏感信息、影响性能 | 仅对非敏感资源使用 |
| 删除审计日志 | 高 | 丢失审计记录，合规问题 | 先备份再删除 |
| 修改审计配置 | 中 | API Server 重启 | 选择维护窗口 |
| 禁用审计 | 高 | 无法追踪操作 | 保持启用 |
| Webhook blocking 模式 | 中 | 影响 API 性能 | 优先使用 batch 模式 |

### 附录：快速诊断命令

```bash
# ===== 审计日志一键诊断脚本 =====

echo "=== API Server 审计配置 ==="
ps aux | grep kube-apiserver | tr ' ' '\n' | grep audit

echo -e "\n=== 审计策略文件 ==="
cat /etc/kubernetes/audit-policy.yaml 2>/dev/null | head -30 || echo "未找到审计策略文件"

echo -e "\n=== 审计日志文件 ==="
ls -lh /var/log/kubernetes/audit* 2>/dev/null || ls -lh /var/log/audit* 2>/dev/null || echo "未找到审计日志"

echo -e "\n=== 最近审计事件 (5条) ==="
tail -5 /var/log/kubernetes/audit.log 2>/dev/null | jq '{time: .requestReceivedTimestamp, user: .user.username, verb: .verb, resource: .objectRef.resource}'

echo -e "\n=== 审计事件统计 ==="
cat /var/log/kubernetes/audit.log 2>/dev/null | jq -r '.verb' | sort | uniq -c | sort -rn | head -10

echo -e "\n=== 失败请求统计 ==="
cat /var/log/kubernetes/audit.log 2>/dev/null | jq 'select(.responseStatus.code >= 400)' | jq -r '.responseStatus.code' | sort | uniq -c
```

### 附录：完整审计策略模板

```yaml
# 生产环境推荐的审计策略
apiVersion: audit.k8s.io/v1
kind: Policy

# 跳过记录 RequestReceived 阶段（减少重复）
omitStages:
  - "RequestReceived"

rules:
  # 1. 完全跳过的请求
  
  # 健康检查
  - level: None
    nonResourceURLs:
      - /healthz*
      - /livez*
      - /readyz*
      - /metrics
  
  # 系统组件的高频操作
  - level: None
    users:
      - system:kube-scheduler
      - system:kube-proxy
      - system:apiserver
      - system:kube-controller-manager
    verbs:
      - get
      - list
      - watch
  
  # 2. 敏感资源 - 只记录元数据
  - level: Metadata
    resources:
      - group: ""
        resources:
          - secrets
          - configmaps
          - serviceaccounts/token
      - group: authentication.k8s.io
        resources:
          - tokenreviews
          - tokenrequests
  
  # 3. 重要操作 - 记录完整请求
  - level: Request
    verbs:
      - create
      - update
      - patch
      - delete
      - deletecollection
    resources:
      - group: ""
        resources: ["*"]
      - group: apps
        resources: ["*"]
      - group: batch
        resources: ["*"]
      - group: rbac.authorization.k8s.io
        resources: ["*"]
      - group: networking.k8s.io
        resources: ["*"]
  
  # 4. 读操作 - 只记录元数据
  - level: Metadata
    verbs:
      - get
      - list
      - watch
  
  # 5. 兜底规则
  - level: Metadata
```
