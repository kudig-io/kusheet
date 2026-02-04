# 02 - 指标监控体系详解 (Monitoring Metrics System)

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [prometheus.io/docs](https://prometheus.io/docs/)

## 概述

本文档深入解析 Kubernetes 指标监控体系，涵盖 Prometheus 生态、核心组件指标、自定义指标扩展、告警规则设计等关键内容，为构建生产级监控系统提供完整指导。

---

## 一、Prometheus 监控架构

### 1.1 核心组件架构

#### Prometheus生态系统组件
```yaml
prometheus_ecosystem:
  core_components:
    prometheus_server:
      function: 数据采集、存储、查询引擎
      features:
        - pull_based_scraping
        - tsdb_storage
        - promql_query_language
        - http_api
        
    alertmanager:
      function: 告警路由、去重、抑制
      features:
        - receiver_routing
        - silencing
        - inhibition_rules
        - high_availability
        
    pushgateway:
      function: 短生命周期作业指标推送
      use_cases:
        - cron_jobs
        - batch_processes
        - ci_cd_pipelines
        
  kubernetes_operators:
    prometheus_operator:
      function: Prometheus实例生命周期管理
      crds:
        - prometheus
        - servicemonitor
        - podmonitor
        - prometheusrule
        - alertmanagerconfig
        
    kube_prometheus_stack:
      function: 完整监控栈部署
      components:
        - prometheus_operator
        - prometheus
        - alertmanager
        - grafana
        - node_exporter
        - kube_state_metrics
```

### 1.2 高可用部署架构

#### Prometheus HA方案
```yaml
prometheus_ha_deployment:
  # 方案一：Thanos架构
  thanos_approach:
    components:
      - prometheus_with_thanos_sidecar
      - thanos_querier
      - thanos_store_gateway
      - thanos_compactor
      - thanos_ruler
      
    advantages:
      - 全局查询视图
      - 长期存储支持
      - 无单点故障
      - 水平扩展能力
      
  # 方案二：联邦架构
  federation_approach:
    levels:
      - leaf_prometheus: 区域级监控
      - global_prometheus: 全局聚合
      
    configuration:
      leaf_config: |
        global:
          external_labels:
            region: cn-beijing
            replica: "$(HOSTNAME)"
            
      global_config: |
        scrape_configs:
        - job_name: federate
          scrape_interval: 15s
          honor_labels: true
          metrics_path: /federate
          params:
            'match[]':
              - '{job=~"kubernetes-.*"}'
              - '{__name__=~"job:.*"}'
```

---

## 二、核心组件监控指标

### 2.1 API Server关键指标

#### API Server性能指标
| 指标名称 | 类型 | 说明 | 告警阈值 | 运维场景 |
|---------|------|------|---------|---------|
| `apiserver_request_total` | Counter | API请求总数(按verb/resource/code分组) | 5xx错误率>1% | 监控API健康 |
| `apiserver_request_duration_seconds` | Histogram | API请求延迟 | P99>1s | 性能问题排查 |
| `apiserver_current_inflight_requests` | Gauge | 当前进行中请求数 | >80%限制值 | 过载检测 |
| `apiserver_longrunning_requests` | Gauge | 长运行请求数(watch等) | 异常增长 | Watch泄漏检测 |
| `apiserver_request_terminations_total` | Counter | 请求终止数 | 快速增长 | 超时问题 |
| `apiserver_audit_event_total` | Counter | 审计事件数 | - | 审计监控 |
| `apiserver_storage_objects` | Gauge | etcd对象数(按resource) | 接近配额 | 存储容量 |

#### API Server监控配置
```yaml
# ServiceMonitor配置
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kube-apiserver
  namespace: monitoring
spec:
  endpoints:
  - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
    interval: 30s
    metricRelabelings:
    - action: keep
      regex: apiserver_request_(latency|count|duration)|etcd_(server|disk|network)
      sourceLabels:
      - __name__
    port: https
    scheme: https
    tlsConfig:
      caFile: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      serverName: kubernetes
  jobLabel: component
  namespaceSelector:
    matchNames:
    - default
  selector:
    matchLabels:
      component: apiserver
      provider: kubernetes
```

### 2.2 etcd关键指标

#### etcd稳定性指标
| 指标名称 | 类型 | 说明 | 告警阈值 | 运维场景 |
|---------|------|------|---------|---------|
| `etcd_server_has_leader` | Gauge | 是否有Leader | =0 | 集群健康 |
| `etcd_server_leader_changes_seen_total` | Counter | Leader切换次数 | >3/h | 稳定性问题 |
| `etcd_disk_wal_fsync_duration_seconds` | Histogram | WAL同步延迟 | P99>10ms | 磁盘性能 |
| `etcd_disk_backend_commit_duration_seconds` | Histogram | 后端提交延迟 | P99>25ms | 磁盘性能 |
| `etcd_mvcc_db_total_size_in_bytes` | Gauge | 数据库大小 | >80%配额 | 存储容量 |
| `etcd_network_peer_round_trip_time_seconds` | Histogram | 对等节点RTT | P99>100ms | 网络问题 |
| `etcd_server_proposals_failed_total` | Counter | 失败提案数 | >0持续 | Raft问题 |

#### etcd监控最佳实践
```yaml
# etcd监控配置
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: etcd
  namespace: monitoring
spec:
  podMetricsEndpoints:
  - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
    interval: 15s
    metricRelabelings:
    - action: keep
      regex: etcd_(server|disk|network|mvcc)
      sourceLabels:
      - __name__
    port: metrics
    scheme: https
    tlsConfig:
      ca:
        secret:
          key: etcd-ca.crt
          name: etcd-client-tls
      cert:
        secret:
          key: etcd-client.crt
          name: etcd-client-tls
      keySecret:
        key: etcd-client.key
        name: etcd-client-tls
  selector:
    matchLabels:
      component: etcd
```

### 2.3 调度器关键指标

#### 调度器性能指标
| 指标名称 | 类型 | 说明 | 告警阈值 | 运维场景 |
|---------|------|------|---------|---------|
| `scheduler_pending_pods` | Gauge | 待调度Pod数(按queue) | >100持续 | 调度瓶颈 |
| `scheduler_pod_scheduling_duration_seconds` | Histogram | 调度延迟 | P99>5s | 调度性能 |
| `scheduler_schedule_attempts_total` | Counter | 调度尝试数(按result) | unschedulable增长 | 资源不足 |
| `scheduler_preemption_attempts_total` | Counter | 抢占尝试数 | 持续增长 | 资源竞争 |
| `scheduler_framework_extension_point_duration_seconds` | Histogram | 插件执行时间 | P99>50ms | 插件性能 |

---

## 三、自定义指标扩展

### 3.1 Application Metrics

#### 应用指标暴露方式
```yaml
# 应用Prometheus配置
application_metrics_setup:
  # 1. 应用端暴露metrics端点
  metrics_endpoint: /metrics
  port: 8080
  
  # 2. ServiceMonitor配置
  service_monitor:
    apiVersion: monitoring.coreos.com/v1
    kind: ServiceMonitor
    metadata:
      name: app-metrics
      namespace: monitoring
    spec:
      endpoints:
      - interval: 30s
        path: /metrics
        port: http-metrics
      selector:
        matchLabels:
          app: my-application
          
  # 3. 应用指标示例
  sample_metrics:
    http_requests_total:
      type: Counter
      help: Total number of HTTP requests
      
    http_request_duration_seconds:
      type: Histogram
      help: HTTP request latencies in seconds
      
    current_users:
      type: Gauge
      help: Current number of active users
```

### 3.2 自定义Exporter开发

#### Exporter开发模板
```go
// Go语言Exporter示例
package main

import (
    "net/http"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    httpRequestTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )
    
    httpRequestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request latencies in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "endpoint"},
    )
)

func init() {
    prometheus.MustRegister(httpRequestTotal)
    prometheus.MustRegister(httpRequestDuration)
}

func metricsMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        
        // 执行原始handler
        next.ServeHTTP(w, r)
        
        // 记录指标
        duration := time.Since(start).Seconds()
        httpRequestTotal.WithLabelValues(r.Method, r.URL.Path, "200").Inc()
        httpRequestDuration.WithLabelValues(r.Method, r.URL.Path).Observe(duration)
    })
}
```

---

## 四、告警规则体系

### 4.1 告警规则分类

#### 分层告警策略
```yaml
alert_categories:
  infrastructure_alerts:
    critical:
      - KubeAPIServerDown
      - EtcdNoLeader
      - NodeNotReady
    warning:
      - EtcdHighFsyncDuration
      - KubeSchedulerPendingPods
      - NodeMemoryPressure
      
  application_alerts:
    critical:
      - PodCrashLooping
      - DeploymentReplicasMismatch
      - PersistentVolumeClaimPending
    warning:
      - HighErrorRate
      - HighLatency
      - LowSuccessRate
      
  business_alerts:
    critical:
      - BusinessTransactionFailure
      - RevenueImpactAlert
    warning:
      - SLAViolation
      - PerformanceDegradation
```

### 4.2 生产级告警规则

#### 核心告警规则集
```yaml
# PrometheusRule配置
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kubernetes-rules
  namespace: monitoring
spec:
  groups:
  - name: kubernetes-system
    rules:
    # === Critical Alerts ===
    - alert: KubeAPIServerDown
      expr: absent(up{job="kubernetes-apiservers"} == 1)
      for: 5m
      labels:
        severity: critical
        category: infrastructure
      annotations:
        summary: "Kubernetes API Server is down"
        description: "API Server has been unreachable for more than 5 minutes"
        
    - alert: EtcdNoLeader
      expr: etcd_server_has_leader == 0
      for: 1m
      labels:
        severity: critical
        category: infrastructure
      annotations:
        summary: "etcd has no leader"
        description: "etcd cluster has lost quorum"
        
    # === Warning Alerts ===
    - alert: KubeSchedulerPendingPods
      expr: scheduler_pending_pods{queue="active"} > 100
      for: 10m
      labels:
        severity: warning
        category: infrastructure
      annotations:
        summary: "Too many pending pods"
        description: "{{ $value }} pods are pending scheduling"
        
    - alert: NodeMemoryPressure
      expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.9
      for: 5m
      labels:
        severity: warning
        category: infrastructure
      annotations:
        summary: "Node {{ $labels.instance }} memory pressure"
        description: "Memory usage is above 90%"
        
    # === Application Alerts ===
    - alert: PodRestartingTooMuch
      expr: increase(kube_pod_container_status_restarts_total[1h]) > 5
      for: 5m
      labels:
        severity: warning
        category: application
      annotations:
        summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} restarting frequently"
        description: "Pod has restarted {{ $value }} times in the last hour"
```

### 4.3 告警抑制与去重

#### 告警管理策略
```yaml
alertmanager_config:
  global:
    resolve_timeout: 5m
    
  route:
    group_by: ['alertname', 'cluster']
    group_wait: 30s
    group_interval: 5m
    repeat_interval: 3h
    receiver: 'default-receiver'
    
  inhibit_rules:
    # 当节点宕机时，抑制该节点上的所有告警
    - source_match:
        alertname: NodeNotReady
      target_match:
        alertname: PodNotReady
      equal: ['node']
      
    # 当API Server宕机时，抑制所有相关告警
    - source_match:
        alertname: KubeAPIServerDown
      target_match_re:
        alertname: ^(Kube|Etcd).*
        
  receivers:
    - name: 'default-receiver'
      email_configs:
      - to: 'alerts@example.com'
        send_resolved: true
      webhook_configs:
      - url: 'http://alert-gateway:8080/webhook'
```

---

## 五、性能优化与调优

### 5.1 Prometheus性能调优

#### 存储与查询优化
```yaml
prometheus_optimization:
  storage_tuning:
    # TSDB配置优化
    tsdb_config:
      retention.time: 15d
      retention.size: "50GB"
      wal-compression: true
      max-block-duration: 2h
      min-block-duration: 2h
      
    # 资源限制
    resources:
      requests:
        memory: 4Gi
        cpu: 2
      limits:
        memory: 8Gi
        cpu: 4
        
  scrape_optimization:
    # 抓取配置优化
    scrape_configs:
      - job_name: 'kubernetes-nodes'
        scrape_interval: 30s
        scrape_timeout: 10s
        sample_limit: 5000
        metric_relabel_configs:
        - source_labels: [__name__]
          regex: '(go_|process_).*'
          action: drop
          
  query_optimization:
    # 查询性能优化
    query_config:
      lookback-delta: 5m
      max-concurrency: 20
      timeout: 2m
      max-samples: 50000000
```

### 5.2 长期存储方案

#### Thanos长期存储配置
```yaml
thanos_components:
  # Sidecar配置
  sidecar:
    args:
      - sidecar
      - --prometheus.url=http://localhost:9090
      - --objstore.config-file=/etc/thanos/objstore.yml
      - --tsdb.path=/prometheus
      - --reloader.config-file=/etc/prometheus/prometheus.yml
      
  # Store Gateway配置
  store_gateway:
    args:
      - store
      - --data-dir=/data
      - --objstore.config-file=/etc/thanos/objstore.yml
      - --index-cache-size=500MB
      - --chunk-pool-size=2GB
      
  # Compactor配置
  compactor:
    args:
      - compact
      - --data-dir=/data
      - --objstore.config-file=/etc/thanos/objstore.yml
      - --retention.resolution-raw=30d
      - --retention.resolution-5m=120d
      - --retention.resolution-1h=1y
```

---

## 六、监控成熟度模型

### 6.1 监控成熟度等级

#### 五个成熟度级别
```
监控成熟度等级:

Level 1 - 基础监控 (Basic Monitoring)
├── 核心组件状态监控
├── 基本告警配置
├── 简单仪表板展示
└── 手动故障排查

Level 2 - 标准监控 (Standard Monitoring)
├── 全面指标收集
├── 自动化告警
├── 丰富的可视化
├── 标准化监控流程
└── 基础性能分析

Level 3 - 高级监控 (Advanced Monitoring)
├── 智能告警策略
├── 预测性分析
├── 自动化诊断
├── 成本优化监控
└── 用户体验监控

Level 4 - 智能监控 (Intelligent Monitoring)
├── AI驱动的异常检测
├── 自适应阈值设置
├── 根因分析自动化
├── 智能容量规划
└── 业务影响评估

Level 5 - 自主运维 (Autonomous Operations)
├── 完全自动化的运维
├── 预防性问题解决
├── 动态资源优化
├── 业务连续性保障
└── 持续改进机制
```

### 6.2 成熟度评估标准

#### 各级别评估指标
| 成熟度级别 | 关键指标 | 实施要求 | 价值收益 |
|-----------|---------|---------|---------|
| **Level 1** | 95%核心组件监控覆盖率 | 基础Prometheus部署 | 基本稳定性保障 |
| **Level 2** | 99%监控覆盖率，<5分钟MTTD | 完整监控栈 | 主动问题发现 |
| **Level 3** | 智能告警，预测性维护 | ML辅助分析 | 降低故障影响 |
| **Level 4** | 自动根因分析，自适应阈值 | AI/ML深度集成 | 提升运维效率 |
| **Level 5** | 自主运维，业务驱动优化 | 完全自动化 | 最大化业务价值 |

---

**监控哲学**: 从"被动响应"到"主动预防"，从"局部可见"到"全局洞察"，从"人治"到"智治"

---

**实施建议**: 循序渐进，先保证基础监控完备，再逐步提升智能化水平

---

**表格维护**: Kusheet Project | **作者**: Allen Galler (allengaller@gmail.com)