# 表格17：日志和审计表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/cluster-administration/logging](https://kubernetes.io/docs/concepts/cluster-administration/logging/)

## 日志架构模式

| 模式 | 描述 | 优点 | 缺点 | 适用场景 |
|-----|------|------|------|---------|
| **节点级代理** | DaemonSet收集节点日志 | 低侵入，统一管理 | 无法收集容器内文件日志 | 标准stdout日志 |
| **Sidecar容器** | Pod内Sidecar收集日志 | 灵活，可处理文件日志 | 资源开销 | 文件日志，日志预处理 |
| **直接推送** | 应用直接发送到后端 | 最灵活 | 应用耦合 | 特殊格式日志 |

## 日志组件对比

| 组件 | 类型 | 特点 | 版本要求 | ACK替代 |
|-----|------|------|---------|---------|
| **Fluentd** | 收集器 | 插件丰富，功能全面 | v1.16+ | Logtail |
| **Fluent Bit** | 收集器 | 轻量级，高性能 | v2.2+ | Logtail |
| **Filebeat** | 收集器 | Elastic生态 | v8.x | Logtail |
| **Logtail** | 收集器 | 阿里云原生 | - | 原生 |
| **Loki** | 存储/查询 | 标签索引，低成本 | v2.9+ | SLS |
| **Elasticsearch** | 存储/查询 | 全文索引，功能强 | v8.x | SLS |
| **SLS** | 存储/查询 | 阿里云原生，免运维 | - | 原生 |

## 容器日志配置

| 日志类型 | 路径 | 收集方式 | 配置方法 |
|---------|------|---------|---------|
| **stdout/stderr** | /var/log/containers/*.log | 节点代理自动收集 | 应用输出到标准输出 |
| **容器内文件** | 容器内任意路径 | Sidecar或卷挂载 | 配置卷+Sidecar |
| **emptyDir日志** | emptyDir卷路径 | 节点代理挂载读取 | 卷挂载到节点代理 |

```yaml
# Sidecar日志收集示例
apiVersion: v1
kind: Pod
metadata:
  name: app-with-logging
spec:
  containers:
  - name: app
    image: app:latest
    volumeMounts:
    - name: log-volume
      mountPath: /var/log/app
  - name: log-collector
    image: fluent/fluent-bit:latest
    volumeMounts:
    - name: log-volume
      mountPath: /var/log/app
      readOnly: true
    - name: fluent-bit-config
      mountPath: /fluent-bit/etc/
  volumes:
  - name: log-volume
    emptyDir: {}
  - name: fluent-bit-config
    configMap:
      name: fluent-bit-config
```

## Kubernetes审计日志

| 审计级别 | 记录内容 | 存储影响 | 适用场景 |
|---------|---------|---------|---------|
| **None** | 不记录 | 无 | 健康检查等 |
| **Metadata** | 请求元数据 | 低 | 大多数资源 |
| **Request** | 元数据+请求体 | 中 | 敏感资源 |
| **RequestResponse** | 元数据+请求+响应 | 高 | 关键审计 |

## 审计策略配置

```yaml
# 审计策略示例
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # 不记录只读请求到某些资源
  - level: None
    resources:
    - group: ""
      resources: ["events"]
  
  # 不记录kubelet/kube-proxy的watch请求
  - level: None
    users: ["system:kube-proxy", "system:kubelet"]
    verbs: ["watch"]
    resources:
    - group: ""
      resources: ["endpoints", "services", "services/status"]
  
  # Secrets读取记录Metadata
  - level: Metadata
    resources:
    - group: ""
      resources: ["secrets"]
  
  # Secrets写入记录Request
  - level: Request
    verbs: ["create", "update", "patch", "delete"]
    resources:
    - group: ""
      resources: ["secrets", "configmaps"]
  
  # 其他资源记录Metadata
  - level: Metadata
    omitStages:
    - "RequestReceived"
```

## 审计后端配置

| 后端类型 | 配置参数 | 说明 | 版本支持 |
|---------|---------|------|---------|
| **日志文件** | --audit-log-path | 写入本地文件 | 稳定 |
| **Webhook** | --audit-webhook-config-file | 发送到外部服务 | 稳定 |
| **动态后端** | --audit-dynamic-configuration | 动态配置(已弃用) | 弃用 |

```bash
# API Server审计参数
--audit-log-path=/var/log/kubernetes/audit.log
--audit-log-maxage=30
--audit-log-maxbackup=10
--audit-log-maxsize=100
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
```

## Event API

| 资源 | 用途 | 保留时间 | 版本支持 |
|-----|------|---------|---------|
| **events.k8s.io/v1** | 新版Event API | 可配置 | v1.19+ GA |
| **core/v1 Event** | 旧版Event | 1小时默认 | 稳定 |

```bash
# 查看事件
kubectl get events -A --sort-by='.lastTimestamp'
kubectl events --for pod/<name>  # v1.26+
kubectl get events --field-selector=type=Warning

# 事件保留配置(API Server)
--event-ttl=1h
```

## 结构化日志(v1.19+)

| 特性 | 说明 | 版本支持 |
|-----|------|---------|
| **JSON格式** | 组件日志输出JSON | v1.19+ |
| **日志级别** | -v标志控制详细程度 | 稳定 |
| **日志清理** | 自动轮换 | 组件配置 |

```bash
# 启用JSON日志(kubelet示例)
--logging-format=json
--log-json-info-buffer-size=0
--log-json-split-stream=true

# 日志级别
-v=0  # 最少输出
-v=2  # 有用的稳态信息
-v=4  # 调试级别
-v=6  # API请求/响应
-v=8  # 详细调试
```

## 日志聚合最佳实践

| 实践 | 说明 | 工具 |
|-----|------|------|
| **结构化日志** | JSON格式便于解析 | 应用配置 |
| **统一时间戳** | UTC或统一时区 | 应用配置 |
| **关联ID** | 追踪请求链路 | OpenTelemetry |
| **日志分级** | 按级别过滤 | 应用框架 |
| **采样** | 高流量日志采样 | Fluent Bit |
| **保留策略** | 按需设置保留期 | 存储系统 |

## ACK日志集成

| 功能 | 产品 | 配置方式 |
|-----|------|---------|
| **容器日志** | SLS | Logtail DaemonSet |
| **K8S事件** | SLS | 控制台开启 |
| **审计日志** | SLS | 控制台开启 |
| **Ingress日志** | SLS | 注解配置 |
| **应用追踪** | ARMS | Agent注入 |

```yaml
# ACK Logtail配置
apiVersion: log.alibabacloud.com/v1alpha1
kind: AliyunLogConfig
metadata:
  name: app-logs
spec:
  project: my-project
  logstore: app-logs
  shardCount: 2
  lifeCycle: 30
  logtailConfig:
    inputType: plugin
    configName: app-logs
    inputDetail:
      plugin:
        inputs:
        - type: service_docker_stdout
          detail:
            Stdout: true
            Stderr: true
            IncludeLabel:
              app: myapp
        processors:
        - type: processor_json
          detail:
            SourceKey: content
            KeepSource: false
```

## 日志告警规则

| 告警类型 | 日志模式 | 告警条件 |
|---------|---------|---------|
| **应用错误** | ERROR/FATAL关键字 | >10/分钟 |
| **Pod重启** | Event: BackOff | >3次/小时 |
| **节点问题** | Event: NodeNotReady | 任何发生 |
| **OOM** | OOMKilled | 任何发生 |
| **安全事件** | 审计日志特定操作 | 任何发生 |

## 合规审计要求

| 合规标准 | 日志要求 | 保留期 |
|---------|---------|-------|
| **PCI-DSS** | 访问日志，安全事件 | 1年 |
| **SOC2** | 系统日志，审计日志 | 1年 |
| **等保2.0** | 全面日志记录 | 6个月 |
| **GDPR** | 数据访问日志 | 根据需求 |

---

**日志原则**: 结构化输出，集中存储，建立告警，定期审计
