# 04 - 分布式追踪体系 (Distributed Tracing)

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [opentelemetry.io](https://opentelemetry.io/)

## 概述

本文档详细介绍 Kubernetes 环境下的分布式追踪体系，涵盖 OpenTelemetry 标准、Jaeger/Tempo 部署、应用埋点实践、链路分析等核心内容，帮助企业构建完整的分布式追踪能力。

---

## 一、分布式追踪基础概念

### 1.1 核心术语定义

#### 追踪基本概念
```yaml
tracing_concepts:
  trace:
    definition: 一个完整的请求在分布式系统中的执行路径
    composition: 由多个span组成
    identifier: trace_id (全局唯一)
    
  span:
    definition: 单个工作单元的执行表示
    contains:
      - operation_name: 操作名称
      - span_id: span唯一标识
      - parent_span_id: 父span标识
      - start_time: 开始时间
      - end_time: 结束时间
      - attributes: 键值对属性
      - events: 时间点事件
      - status: 执行状态
      
  context_propagation:
    purpose: 在服务间传递追踪上下文
    headers:
      - traceparent: W3C标准头部
      - tracestate: 追踪状态信息
      - baggage: 跨服务传递的元数据
```

### 1.2 追踪数据模型

#### Span数据结构
```json
{
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "parent_span_id": "00f067aa0ba902b6",
  "name": "HTTP GET /api/users",
  "kind": "SERVER",
  "start_time_unix_nano": 1502788081928613000,
  "end_time_unix_nano": 1502788081928659000,
  "attributes": {
    "http.method": "GET",
    "http.url": "http://localhost:8080/api/users",
    "http.status_code": 200,
    "user.id": "12345"
  },
  "events": [
    {
      "time_unix_nano": 1502788081928630000,
      "name": "DB query started",
      "attributes": {
        "db.statement": "SELECT * FROM users WHERE ..."
      }
    }
  ],
  "status": {
    "code": "STATUS_CODE_OK"
  }
}
```

---

## 二、OpenTelemetry 标准体系

### 2.1 OpenTelemetry架构

#### 统一可观测性框架
```yaml
opentelemetry_architecture:
  instrumentation:
    auto_instrumentation:
      languages_supported:
        - java: javaagent
        - go: otelhttp, otelgrpc
        - python: opentelemetry-instrumentation
        - nodejs: @opentelemetry/auto-instrumentations-node
      benefits:
        - 零代码侵入
        - 自动捕获常用框架
        - 快速上线
        
    manual_instrumentation:
      use_cases:
        - 业务逻辑埋点
        - 自定义span创建
        - 特殊场景处理
      api_components:
        - tracer: 创建spans
        - meter: 创建metrics
        - logger: 创建logs
        
  collector:
    components:
      receivers:
        - otlp: OpenTelemetry协议
        - jaeger: Jaeger协议
        - zipkin: Zipkin协议
        - prometheus: Prometheus指标
      processors:
        - batch: 批量处理
        - memory_limiter: 内存限制
        - attributes: 属性处理
        - spanmetrics: span指标生成
      exporters:
        - jaeger: 发送到Jaeger
        - otlp: 发送到OTLP后端
        - prometheus: 导出指标
        - logging: 日志输出
        
  backend:
    traces_storage:
      - jaeger: 功能完整，社区活跃
      - tempo: 轻量级，与Grafana集成好
      - signoz: 开源APM平台
    metrics_storage:
      - prometheus: 标准指标存储
      - victoria_metrics: 高性能替代
    logs_storage:
      - loki: 与traces集成好
      - elasticsearch: 功能丰富
```

### 2.2 Collector配置示例

#### 生产级Collector配置
```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
        
  jaeger:
    protocols:
      thrift_http:
        endpoint: 0.0.0.0:14268
      grpc:
        endpoint: 0.0.0.0:14250
        
  zipkin:
    endpoint: 0.0.0.0:9411

processors:
  batch:
    timeout: 5s
    send_batch_size: 8192
    
  memory_limiter:
    limit_mib: 400
    spike_limit_mib: 100
    
  attributes:
    actions:
      - key: environment
        value: production
        action: insert
      - key: k8s.namespace
        from_attribute: k8s.namespace.name
        action: upsert
        
  spanmetrics:
    metrics_exporter: prometheus
    dimensions:
      - name: http.method
      - name: http.status_code
      - name: k8s.namespace.name

exporters:
  jaeger:
    endpoint: jaeger-collector:14250
    tls:
      insecure: true
      
  prometheus:
    endpoint: "0.0.0.0:8889"
    namespace: otel
    
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    headers:
      "X-Scope-OrgID": "production"

extensions:
  health_check:
  pprof:
  zpages:

service:
  extensions: [health_check, pprof, zpages]
  pipelines:
    traces:
      receivers: [otlp, jaeger, zipkin]
      processors: [memory_limiter, batch, attributes]
      exporters: [jaeger]
      
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch, spanmetrics]
      exporters: [prometheus]
      
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [loki]
```

---

## 三、应用埋点实践

### 3.1 不同语言埋点示例

#### Java应用埋点
```java
// OpenTelemetry Java示例
@Configuration
public class OpenTelemetryConfig {
    
    @Bean
    public OpenTelemetry openTelemetry() {
        return OpenTelemetrySdk.builder()
            .setTracerProvider(SdkTracerProvider.builder()
                .addSpanProcessor(BatchSpanProcessor.builder(
                    OtlpGrpcSpanExporter.builder()
                        .setEndpoint("http://otel-collector:4317")
                        .build())
                    .build())
                .build())
            .build();
    }
}

@RestController
@RequestMapping("/api/users")
public class UserController {
    
    private final Tracer tracer = GlobalOpenTelemetry.getTracer("user-service");
    
    @GetMapping("/{id}")
    public ResponseEntity<User> getUser(@PathVariable String id, HttpServletRequest request) {
        // 从HTTP头部提取trace context
        Context parentContext = OpenTelemetryServletUtil.extract(request, Context.current());
        
        Span span = tracer.spanBuilder("GET /api/users/{id}")
            .setParent(parentContext)
            .setAttribute("user.id", id)
            .setAttribute("http.method", "GET")
            .startSpan();
            
        try (Scope scope = span.makeCurrent()) {
            // 添加事件
            span.addEvent("Database query started");
            
            User user = userService.findById(id);
            
            span.addEvent("Database query completed");
            span.setAttribute("user.exists", user != null);
            
            return ResponseEntity.ok(user);
        } catch (Exception e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, e.getMessage());
            throw e;
        } finally {
            span.end();
        }
    }
}
```

#### Go应用埋点
```go
// OpenTelemetry Go示例
package main

import (
    "context"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/propagation"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
    "go.opentelemetry.io/otel/trace"
    "google.golang.org/grpc"
)

func initTracer() (*sdktrace.TracerProvider, error) {
    ctx := context.Background()
    
    res, err := resource.New(ctx,
        resource.WithAttributes(
            semconv.ServiceName("user-service"),
            semconv.ServiceVersion("1.0.0"),
        ),
    )
    if err != nil {
        return nil, err
    }

    conn, err := grpc.DialContext(ctx, "otel-collector:4317", grpc.WithInsecure())
    if err != nil {
        return nil, err
    }

    traceExporter, err := otlptracegrpc.New(ctx, otlptracegrpc.WithGRPCConn(conn))
    if err != nil {
        return nil, err
    }

    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(traceExporter),
        sdktrace.WithResource(res),
    )
    
    otel.SetTracerProvider(tp)
    otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
        propagation.TraceContext{}, 
        propagation.Baggage{},
    ))
    
    return tp, nil
}

func getUserHandler(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    
    // 从HTTP请求中提取trace context
    ctx = otel.GetTextMapPropagator().Extract(ctx, propagation.HeaderCarrier(r.Header))
    
    tracer := otel.Tracer("user-service")
    ctx, span := tracer.Start(ctx, "GET /api/users/{id}",
        trace.WithAttributes(
            attribute.String("http.method", r.Method),
            attribute.String("http.url", r.URL.String()),
        ),
    )
    defer span.End()
    
    // 添加事件
    span.AddEvent("Database query started")
    
    vars := mux.Vars(r)
    userID := vars["id"]
    
    user, err := userService.GetByID(ctx, userID)
    if err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    
    span.AddEvent("Database query completed")
    span.SetAttributes(
        attribute.Bool("user.found", user != nil),
        attribute.String("user.id", userID),
    )
    
    // 返回响应
    json.NewEncoder(w).Encode(user)
}
```

#### Python应用埋点
```python
# OpenTelemetry Python示例
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

def setup_opentelemetry():
    resource = Resource(attributes={
        "service.name": "user-service",
        "service.version": "1.0.0",
    })
    
    provider = TracerProvider(resource=resource)
    
    processor = BatchSpanProcessor(
        OTLPSpanExporter(endpoint="http://otel-collector:4317")
    )
    provider.add_span_processor(processor)
    
    trace.set_tracer_provider(provider)

# Flask应用示例
from flask import Flask, request
import requests

app = Flask(__name__)
setup_opentelemetry()
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()

@app.route('/api/users/<user_id>')
def get_user(user_id):
    tracer = trace.get_tracer(__name__)
    
    with tracer.start_as_current_span("GET /api/users/{id}") as span:
        span.set_attribute("user.id", user_id)
        span.set_attribute("http.method", request.method)
        
        span.add_event("Database query started")
        
        # 调用数据库
        user = get_user_from_db(user_id)
        
        span.add_event("Database query completed")
        span.set_attribute("user.found", user is not None)
        
        if user:
            # 调用外部服务
            with tracer.start_as_current_span("call-payment-service") as child_span:
                response = requests.get(f"http://payment-service/api/balance/{user_id}")
                child_span.set_attribute("http.status_code", response.status_code)
        
        return {"user": user}

def get_user_from_db(user_id):
    # 数据库查询逻辑
    pass
```

---

## 四、Jaeger 部署与配置

### 4.1 Jaeger生产部署

#### Helm部署配置
```yaml
# values.yaml
jaeger:
  provisionDataStore:
    cassandra: false
    elasticsearch: true
    
  storage:
    type: elasticsearch
    elasticsearch:
      host: elasticsearch.logging.svc.cluster.local
      port: 9200
      scheme: http
      user: elastic
      password: changeme
      
  agent:
    enabled: true
    cmdlineParams:
      processor.jaeger-binary.server-host-port: :6832
      processor.jaeger-compact.server-host-port: :6831
      
  collector:
    enabled: true
    cmdlineParams:
      collector.zipkin.http-port: 9411
    service:
      zipkin:
        port: 9411
        
  query:
    enabled: true
    service:
      type: LoadBalancer
      port: 80
      
  ingester:
    enabled: false  # 如果使用Kafka可以启用
```

### 4.2 Jaeger查询界面

#### 关键查询功能
```yaml
jaeger_query_features:
  trace_search:
    search_criteria:
      - trace_id: 精确trace查找
      - service: 服务名称过滤
      - operation: 操作名称过滤
      - tags: 标签过滤
      - duration: 耗时范围
      - time_range: 时间范围
      
  trace_analysis:
    capabilities:
      - dependency_graph: 服务依赖关系图
      - trace_comparison: trace对比分析
      - statistics: 性能统计
      - flame_graph: 火焰图展示
      
  integration:
    grafana:
      dashboard_url: "/d/jaeger/jaeger-dashboard"
      variables:
        - service
        - operation
    prometheus:
      metrics_correlation: true
      span_metrics: true
```

---

## 五、链路分析与优化

### 5.1 性能瓶颈识别

#### 常见性能问题模式
```yaml
performance_patterns:
  database_bottlenecks:
    indicators:
      - db.query.duration > 100ms
      - high number of sequential queries
      - connection pool exhaustion
    solutions:
      - query optimization
      - connection pooling
      - caching strategies
      
  network_latency:
    indicators:
      - http.client.duration spikes
      - cross-region calls
      - third-party service delays
    solutions:
      - CDN optimization
      - regional deployment
      - async processing
      
  resource_contention:
    indicators:
      - thread/blocking time high
      - GC pause durations
      - memory allocation spikes
    solutions:
      - resource scaling
      - profiling and optimization
      - load balancing
```

### 5.2 链路优化实践

#### 优化策略示例
```yaml
optimization_strategies:
  async_processing:
    pattern: fire_and_forget
    implementation:
      - message_queues: kafka, rabbitmq
      - event_driven_architecture
      - background_jobs
      
  caching_layers:
    types:
      - local_cache: redis, memcached
      - distributed_cache: hazelcast, ignite
      - cdn_cache: cloudfront, akamai
      
  database_optimization:
    techniques:
      - connection_pooling: hikariCP, HikariDataSource
      - query_optimization: indexes, query plans
      - read_replicas: master-slave setup
      - sharding: horizontal partitioning
```

---

## 六、生产最佳实践

### 6.1 采样策略

#### 智能采样配置
```yaml
sampling_strategies:
  probabilistic_sampling:
    rate: 0.1  # 10%采样率
    configuration:
      - default: 10%
      - high_priority: 100%
      - low_priority: 1%
      
  adaptive_sampling:
    algorithm: throughput_based
    parameters:
      target_spans_per_second: 1000
      adjustment_interval: 1m
      min_rate: 0.01
      max_rate: 1.0
      
  rule_based_sampling:
    rules:
      - condition: "error = true"
        sampling_rate: 1.0
      - condition: "http.status_code >= 500"
        sampling_rate: 1.0
      - condition: "user.tier = 'premium'"
        sampling_rate: 0.5
      - condition: "path matches '/api/critical/*'"
        sampling_rate: 1.0
```

### 6.2 标签管理规范

#### 标准化标签体系
```yaml
standard_tags:
  required_tags:
    - service.name: 服务名称
    - span.kind: span类型 (CLIENT/SERVER/PRODUCER/CONSUMER/INTERNAL)
    - http.method: HTTP方法
    - http.status_code: HTTP状态码
    
  recommended_tags:
    - user.id: 用户ID
    - request.id: 请求ID
    - trace_id: 链路ID
    - version: 服务版本
    - environment: 环境标识
    
  business_tags:
    - order.id: 订单ID
    - payment.id: 支付ID
    - session.id: 会话ID
    - tenant.id: 租户ID
```

---

**追踪价值**: 从黑盒到透明，从猜测到精确诊断，从被动到主动优化

---

**实施建议**: 优先核心链路埋点，逐步扩展覆盖范围，重视数据质量和分析价值

---

**表格维护**: Kusheet Project | **作者**: Allen Galler (allengaller@gmail.com)