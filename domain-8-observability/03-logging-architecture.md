# 03 - 日志收集架构详解 (Logging Architecture)

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/cluster-administration/logging](https://kubernetes.io/docs/concepts/cluster-administration/logging/)

## 概述

本文档深入解析 Kubernetes 日志收集架构，涵盖日志架构模式、组件选型、配置管理、结构化日志最佳实践等内容，为企业构建生产级日志系统提供完整指导。

---

## 一、日志架构设计

### 1.1 日志架构模式

#### 三层日志架构
```
┌─────────────────────────────────────────────────────────────────────┐
│                           应用层日志                                 │
├─────────────────────────────────────────────────────────────────────┤
│  • 业务日志 (stdout/stderr)                                         │
│  • 访问日志 (access.log)                                            │
│  • 错误日志 (error.log)                                             │
│  • 审计日志 (audit.log)                                             │
└─────────────────┬───────────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        容器运行时层                                  │
├─────────────────────────────────────────────────────────────────────┤
│  • Docker/Containerd日志驱动                                        │
│  • 日志文件 (/var/log/containers/*.log)                             │
│  • 日志轮转 (logrotate)                                             │
└─────────────────┬───────────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         基础设施层                                   │
├─────────────────────────────────────────────────────────────────────┤
│  • 节点级采集器 (DaemonSet)                                         │
│  • Sidecar采集器                                                    │
│  • 应用直推                                                         │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 日志收集模式对比

#### 三种主流收集模式
| 模式 | 架构描述 | 优点 | 缺点 | 适用场景 |
|-----|---------|------|------|---------|
| **节点级代理** | DaemonSet在每个节点部署采集器 | 低侵入，统一管理，资源效率高 | 无法收集容器内文件日志 | 标准stdout日志 |
| **Sidecar容器** | Pod内部署专门的日志采集容器 | 灵活，可处理文件日志，预处理能力强 | 资源开销较大，配置复杂 | 文件日志，日志预处理 |
| **直接推送** | 应用直接发送日志到后端存储 | 最灵活，实时性强，功能丰富 | 应用耦合度高，维护成本大 | 特殊格式日志 |

---

## 二、日志组件选型

### 2.1 核心组件对比

#### 日志收集器对比
| 组件 | 类型 | 特点 | 版本要求 | 资源消耗 | ACK替代 |
|-----|------|------|---------|---------|---------|
| **Fluentd** | 收集器 | 插件丰富，功能全面，社区活跃 | v1.16+ | 中等(200-500MB) | Logtail |
| **Fluent Bit** | 收集器 | 轻量级，高性能，低资源占用 | v2.2+ | 低(<100MB) | Logtail |
| **Filebeat** | 收集器 | Elastic生态，稳定可靠 | v8.x | 低(<150MB) | Logtail |
| **Vector** | 收集器 | Rust编写，极高性能 | v0.30+ | 极低(<50MB) | 原生支持有限 |

#### 日志存储对比
| 组件 | 类型 | 特点 | 查询能力 | 成本效益 | 适用规模 |
|-----|------|------|---------|---------|---------|
| **Loki** | 存储/查询 | 标签索引，低成本，易部署 | LogQL查询 | 高 | 中小型集群 |
| **Elasticsearch** | 存储/查询 | 全文索引，功能强大，生态完善 | Lucene查询 | 中 | 大型集群 |
| **SLS** | 存储/查询 | 阿里云原生，免运维，高可用 | SQL查询 | 高 | 云环境 |
| **OpenSearch** | 存储/查询 | 开源替代，兼容ES API | Lucene查询 | 中 | 中大型集群 |

### 2.2 生产推荐组合

#### 推荐架构栈
```yaml
recommended_logging_stack:
  small_cluster:  # < 50节点
    collector: fluent_bit
    storage: loki
    visualization: grafana
    cost: 低
    
  medium_cluster:  # 50-200节点
    collector: fluent_bit
    storage: elasticsearch/opensearch
    visualization: grafana/kibana
    cost: 中
    
  large_cluster:  # > 200节点
    collector: fluentd/vector (混合)
    storage: elasticsearch + s3归档
    visualization: kibana/grafana
    cost: 高
    
  cloud_native:  # ACK/AWS/EKS
    collector: logtail/cloudwatch
    storage: sls/cloudwatch
    visualization: 原生控制台
    cost: 按量付费
```

---

## 三、Fluent Bit 生产配置

### 3.1 核心配置详解

#### Fluent Bit主配置
```ini
# fluent-bit.conf
[SERVICE]
    Flush         5
    Daemon        off
    Log_Level     info
    Parsers_File  parsers.conf
    Plugins_File  plugins.conf
    HTTP_Server   On
    HTTP_Listen   0.0.0.0
    HTTP_Port     2020
    Health_Check  On
    HC_Errors_Count 5
    HC_Retry_Failure_Count 5
    HC_Period 60

[INPUT]
    Name              tail
    Path              /var/log/containers/*.log
    Parser            docker
    Tag               kube.*
    Refresh_Interval  5
    Mem_Buf_Limit     50MB
    Skip_Long_Lines   On
    DB                /var/log/flb_kube.db
    DB.Sync           Normal

[INPUT]
    Name              systemd
    Tag               host.*
    Systemd_Filter    _SYSTEMD_UNIT=kubelet.service
    Systemd_Filter    _SYSTEMD_UNIT=docker.service
    Read_From_Tail    On

[FILTER]
    Name                kubernetes
    Match               kube.*
    Kube_URL            https://kubernetes.default.svc:443
    Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
    Kube_Tag_Prefix     kube.var.log.containers.
    Merge_Log           On
    Merge_Log_Key       log_processed
    Keep_Log            Off
    K8S-Logging.Parser  On
    K8S-Logging.Exclude On
    Annotations         Off
    Labels              On

[FILTER]
    Name    modify
    Match   kube.*
    Add     cluster_name prod-cluster
    Add     region cn-hangzhou
    Rename  log message

[OUTPUT]
    Name  loki
    Match kube.*
    Url   http://loki.monitoring.svc:3100/loki/api/v1/push
    BatchWait 1s
    BatchSize 30720
    Labels job=fluentbit, nodename=${NODE_NAME}
    RemoveKeys kubernetes, stream
    AutoKubernetesLabels true

[OUTPUT]
    Name  es
    Match kube.*
    Host  elasticsearch.logging.svc.cluster.local
    Port  9200
    Index k8s-logs-%Y.%m.%d
    Type  _doc
    Logstash_Format On
    Logstash_Prefix k8s
    Time_Key @timestamp
    Replace_Dots On
    Retry_Limit False
```

### 3.2 解析器配置

#### parsers.conf配置
```ini
[PARSER]
    Name        docker
    Format      json
    Time_Key    time
    Time_Format %Y-%m-%dT%H:%M:%S.%LZ
    Time_Keep   On
    Decode_Field_As escaped_utf8 log do_next
    Decode_Field_As json log

[PARSER]
    Name        nginx
    Format      regex
    Regex       ^(?<remote>[^ ]*) - (?<host>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^\"]*?)(?: +\S*)?)?" (?<code>[^ ]*) (?<size>[^ ]*)(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)"(?:\s+(?<http_x_forwarded_for>[^ ]+))?)?$
    Time_Key    time
    Time_Format %d/%b/%Y:%H:%M:%S %z
    Time_Keep   On

[PARSER]
    Name        json
    Format      json
    Time_Key    timestamp
    Time_Format %Y-%m-%dT%H:%M:%S.%L
    Time_Keep   On
```

---

## 四、结构化日志最佳实践

### 4.1 应用日志格式标准

#### 推荐JSON日志格式
```json
{
  "timestamp": "2026-01-18T10:30:00.123Z",
  "level": "ERROR",
  "service": "user-api",
  "version": "v1.2.3",
  "trace_id": "abc123def456",
  "span_id": "span789",
  "user_id": "12345",
  "session_id": "sess98765",
  "request_id": "req123456789",
  "method": "POST",
  "path": "/api/users",
  "query_params": {
    "page": "1",
    "limit": "20"
  },
  "status": 500,
  "duration_ms": 234,
  "bytes_in": 1024,
  "bytes_out": 512,
  "client_ip": "192.168.1.100",
  "user_agent": "Mozilla/5.0...",
  "referrer": "https://example.com",
  "error": "Database connection timeout",
  "error_code": "DB_TIMEOUT",
  "stack_trace": "at com.example.UserService.createUser(UserService.java:45)...",
  "business_context": {
    "order_id": "ORD-2026-001",
    "customer_tier": "premium",
    "region": "cn-hangzhou"
  },
  "kubernetes": {
    "namespace": "production",
    "pod": "user-api-7d4f5b8c9-xk2p4",
    "container": "app",
    "node": "node-1",
    "pod_ip": "10.244.1.10"
  },
  "resource": {
    "cpu_cores": 0.5,
    "memory_mb": 256,
    "threads": 8
  }
}
```

### 4.2 不同语言日志配置

#### Java应用配置
```xml
<!-- logback-spring.xml -->
<configuration>
    <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder class="net.logstash.logback.encoder.LoggingEventCompositeJsonEncoder">
            <providers>
                <timestamp>
                    <fieldName>timestamp</fieldName>
                    <timeZone>UTC</timeZone>
                </timestamp>
                <logLevel>
                    <fieldName>level</fieldName>
                </logLevel>
                <loggerName>
                    <fieldName>logger</fieldName>
                </loggerName>
                <message>
                    <fieldName>message</fieldName>
                </message>
                <mdc/>
                <arguments/>
                <stackTrace>
                    <fieldName>stack_trace</fieldName>
                </stackTrace>
            </providers>
        </encoder>
    </appender>
    
    <springProfile name="production">
        <root level="INFO">
            <appender-ref ref="STDOUT" />
        </root>
    </springProfile>
</configuration>
```

#### Go应用配置
```go
// structured_logger.go
package main

import (
    "context"
    "go.uber.org/zap"
    "go.uber.org/zap/zapcore"
)

func NewStructuredLogger() *zap.Logger {
    config := zap.Config{
        Level:       zap.NewAtomicLevelAt(zap.InfoLevel),
        Development: false,
        Sampling: &zap.SamplingConfig{
            Initial:    100,
            Thereafter: 100,
        },
        Encoding:         "json",
        EncoderConfig:    zapcore.EncoderConfig{
            TimeKey:        "timestamp",
            LevelKey:       "level",
            NameKey:        "logger",
            CallerKey:      "caller",
            MessageKey:     "message",
            StacktraceKey:  "stack_trace",
            LineEnding:     zapcore.DefaultLineEnding,
            EncodeLevel:    zapcore.LowercaseLevelEncoder,
            EncodeTime:     zapcore.ISO8601TimeEncoder,
            EncodeDuration: zapcore.SecondsDurationEncoder,
            EncodeCaller:   zapcore.ShortCallerEncoder,
        },
        OutputPaths:      []string{"stdout"},
        ErrorOutputPaths: []string{"stderr"},
    }
    
    logger, _ := config.Build()
    return logger
}

// 使用示例
func HandleRequest(ctx context.Context, logger *zap.Logger) {
    reqID := ctx.Value("request_id").(string)
    userID := ctx.Value("user_id").(string)
    
    logger.Info("Processing request",
        zap.String("request_id", reqID),
        zap.String("user_id", userID),
        zap.String("path", "/api/users"),
        zap.Int("status", 200),
        zap.Duration("duration", time.Since(start)),
    )
}
```

#### Python应用配置
```python
# structured_logging.py
import logging
import json
from pythonjsonlogger import jsonlogger

class CustomJsonFormatter(jsonlogger.JsonFormatter):
    def add_fields(self, log_record, record, message_dict):
        super(CustomJsonFormatter, self).add_fields(log_record, record, message_dict)
        if not log_record.get('timestamp'):
            log_record['timestamp'] = record.created
        if log_record.get('level'):
            log_record['level'] = log_record['level'].upper()
        else:
            log_record['level'] = record.levelname

def setup_structured_logging():
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    
    handler = logging.StreamHandler()
    formatter = CustomJsonFormatter(
        '%(timestamp)s %(level)s %(name)s %(message)s %(pathname)s %(lineno)d'
    )
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    
    return logger

# 使用示例
logger = setup_structured_logging()

def process_user_request(user_id, request_data):
    logger.info(
        "Processing user request",
        extra={
            'user_id': user_id,
            'request_type': 'CREATE_USER',
            'ip_address': request.remote_addr,
            'user_agent': request.headers.get('User-Agent')
        }
    )
```

---

## 五、日志采集高级配置

### 5.1 多路径日志收集

#### 复杂日志路径配置
```yaml
# 多种日志路径收集
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: logging
data:
  fluent-bit.conf: |
    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        Parser            docker
        Tag               kube.*
        Exclude_Path      *_test_*.log
        
    [INPUT]
        Name              tail
        Path              /var/log/application/*.log
        Parser            json
        Tag               app.*
        Path_Key          filepath
        
    [INPUT]
        Name              tail
        Path              /var/log/nginx/access.log
        Parser            nginx
        Tag               nginx.access
        
    [INPUT]
        Name              tail
        Path              /var/log/nginx/error.log
        Parser            nginx-error
        Tag               nginx.error
        
    [FILTER]
        Name    rewrite_tag
        Match   kube.*
        Rule    $kubernetes['namespace_name'] ^(production)$ kube.production.$TAG false
        Rule    $kubernetes['namespace_name'] ^(staging)$ kube.staging.$TAG false
        Rule    $kubernetes['labels']['app'] ^(.+)$ kube.app.$1.$TAG false
```

### 5.2 日志过滤与采样

#### 智能日志处理
```ini
# 日志过滤和采样配置
[FILTER]
    Name    grep
    Match   kube.*
    # 过滤掉健康检查日志
    Exclude log .*GET /health.*

[FILTER]
    Name    throttle
    Match   kube.*
    # 限制日志速率
    Rate    1000
    Window  5

[FILTER]
    Name    lua
    Match   kube.*
    Script  sampling.lua
    Call    sample_log

[FILTER]
    Name    nest
    Match   kube.*
    Operation lift
    Nested_under kubernetes
```

#### 采样Lua脚本
```lua
-- sampling.lua
function sample_log(tag, timestamp, record)
    -- 基于trace_id进行一致性采样
    if record.trace_id then
        local hash = 0
        for i = 1, #record.trace_id do
            hash = hash + string.byte(record.trace_id, i)
        end
        -- 10%采样率
        if hash % 100 < 10 then
            return 1, timestamp, record
        else
            return -1, timestamp, record
        end
    end
    return 1, timestamp, record
end
```

---

## 六、日志存储与查询

### 6.1 Loki查询语法

#### LogQL查询示例
```logql
# 基础查询
{namespace="production", app="user-api"} |= "ERROR"

# 时间范围查询
{job="fluentbit"} |~ "timeout" [5m]

# JSON日志解析
{app="api"} | json | level="error" | line_format "{{.message}}"

# 聚合统计
sum(count_over_time({namespace="production"} |~ "ERROR" [1h])) by (app)

# 复杂过滤
{namespace="production"} 
  | json 
  | level="ERROR" 
  | status >= 500 
  | duration_ms > 1000
  | line_format "{{.error}} - {{.path}}"

# 关联查询
{trace_id="abc123"} |~ "database"
```

### 6.2 Elasticsearch查询

#### ES查询DSL示例
```json
{
  "query": {
    "bool": {
      "must": [
        {
          "term": {
            "kubernetes.namespace": "production"
          }
        },
        {
          "range": {
            "@timestamp": {
              "gte": "now-1h",
              "lt": "now"
            }
          }
        }
      ],
      "filter": [
        {
          "terms": {
            "level": ["ERROR", "FATAL"]
          }
        }
      ]
    }
  },
  "aggs": {
    "errors_by_app": {
      "terms": {
        "field": "kubernetes.labels.app.keyword",
        "size": 10
      }
    }
  },
  "sort": [
    {
      "@timestamp": {
        "order": "desc"
      }
    }
  ]
}
```

---

## 七、日志告警与分析

### 7.1 日志告警规则

#### 基于日志的告警
```yaml
# Loki告警规则
groups:
- name: log_alerts
  rules:
  # 应用错误率过高
  - alert: HighErrorRate
    expr: |
      sum(rate({namespace="production", app!="health-check"} 
      |= "ERROR" [5m])) > 10
    for: 5m
    labels:
      severity: warning
      category: application
    annotations:
      summary: "High error rate in {{ $labels.app }}"
      description: "{{ $value }} errors per second"

  # 特定错误模式
  - alert: DatabaseConnectionFailures
    expr: |
      sum(count_over_time({app="user-api"} 
      |~ "database.*connection.*failed" [10m])) > 5
    for: 2m
    labels:
      severity: critical
      category: database
    annotations:
      summary: "Database connection failures detected"
      description: "Multiple database connection failures in user-api"

  # 业务异常
  - alert: PaymentProcessingErrors
    expr: |
      sum(count_over_time({app="payment-service"} 
      | json | error_code="PAYMENT_FAILED" [15m])) > 3
    for: 5m
    labels:
      severity: critical
      category: business
    annotations:
      summary: "Payment processing errors"
      description: "Payment failures detected in payment service"
```

### 7.2 日志分析实践

#### 常见分析场景
```sql
-- 慢请求分析 (Loki)
topk(10, 
  sum by(path) (
    rate({app="api"} 
    | json 
    | duration_ms > 1000 [5m])
  )
)

-- 错误趋势分析 (Elasticsearch)
GET /k8s-logs-*/_search
{
  "aggs": {
    "errors_over_time": {
      "date_histogram": {
        "field": "@timestamp",
        "calendar_interval": "1h"
      },
      "aggs": {
        "error_types": {
          "terms": {
            "field": "error_code.keyword"
          }
        }
      }
    }
  }
}

-- 用户行为分析
{app="frontend"} 
  | json 
  | user_id != "" 
  | line_format "{{.user_id}} {{.page_visited}}" 
  | pattern "<user> <page>"
```

---

## 八、合规与安全管理

### 8.1 日志保留策略

#### 合规保留要求
| 合规标准 | 日志类型 | 保留期限 | 加密要求 | 审计要求 |
|---------|---------|---------|---------|---------|
| **PCI-DSS** | 访问日志、安全事件 | 1年 | 传输加密+静态加密 | 定期审计 |
| **SOC2** | 系统日志、审计日志 | 1年 | AES-256加密 | 第三方审计 |
| **等保2.0** | 全面日志记录 | 6个月 | 国密算法 | 自主审计 |
| **GDPR** | 数据访问日志 | 根据需求 | 端到端加密 | DPIA评估 |

### 8.2 敏感信息处理

#### 日志脱敏配置
```yaml
# 敏感信息过滤
[FILTER]
    Name    modify
    Match   kube.*
    # 移除敏感字段
    Remove  credit_card_number
    Remove  password
    Remove  ssn
    
[FILTER]
    Name    record_modifier
    Match   kube.*
    Record  email ${EMAIL:anonymous@example.com}
    
[FILTER]
    Name    lua
    Match   kube.*
    Script  mask_sensitive.lua
    Call    mask_fields

[FILTER]
    Name    aws_sigv4
    Match   *
    Enabled On
    Role_arn arn:aws:iam::123456789012:role/log-forwarder
```

#### 脱敏Lua脚本
```lua
-- mask_sensitive.lua
function mask_fields(tag, timestamp, record)
    -- 脱敏手机号
    if record.phone then
        record.phone = string.gsub(record.phone, "(%d{3})%d+(%d{4})", "%1****%2")
    end
    
    -- 脱敏邮箱
    if record.email then
        record.email = string.gsub(record.email, "(%w+)@(.+)", "***@%2")
    end
    
    -- 脱敏身份证
    if record.id_card then
        record.id_card = string.gsub(record.id_card, "(%d{6})%d+(%d{4})", "%1********%2")
    end
    
    return 1, timestamp, record
end
```

---

**日志原则**: 结构化输出，集中存储，建立告警，定期审计，合规保留

---

**实施建议**: 从简单开始，逐步完善，重视质量和安全性胜过功能丰富性

---

**表格维护**: Kusheet Project | **作者**: Allen Galler (allengaller@gmail.com)