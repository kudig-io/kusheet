# 05 - 告警管理策略 (Alerting Management)

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [prometheus.io/docs/alerting](https://prometheus.io/docs/alerting/)

## 概述

本文档详细介绍 Kubernetes 环境下的告警管理体系，涵盖告警策略设计、规则编写、通知路由、抑制去重、SLO驱动告警等核心内容，为企业构建智能化告警系统提供完整指导。

---

## 一、告警策略设计原则

### 1.1 SLO驱动的告警层次

#### 服务质量目标(SLO)映射
```yaml
slo_based_alerting:
  user_facing_slos:
    availability_slo: 99.9%
    latency_slo: 95%请求<200ms
    error_rate_slo: <0.1%
    
  alert_thresholds:
    critical_alert:
      breach_condition: SLO违约>1%
      response_time: 15分钟内
      notification: 电话+短信
      
    warning_alert:
      breach_condition: SLO违约>0.1%
      response_time: 1小时内
      notification: 邮件+Slack
      
    info_alert:
      breach_condition: SLO接近阈值
      response_time: 4小时内
      notification: Slack通知
```

### 1.2 告警成熟度模型

#### 五个告警成熟度级别
```
告警成熟度等级:

Level 1 - 基础告警
├── 系统组件宕机告警
├── 资源耗尽告警
├── 简单阈值告警
└── 手动处理流程

Level 2 - 标准告警
├── 多维度告警规则
├── 自动化通知路由
├── 告警分组和抑制
├── 基础告警分析

Level 3 - 智能告警
├── 异常检测算法
├── 预测性告警
├── 根因关联分析
├── 动态阈值调整

Level 4 - 自适应告警
├── 机器学习驱动
├── 业务影响评估
├── 自动化响应
├── 智能降噪

Level 5 - 自主运维
├── 完全自动处理
├── 预防性维护
├── 业务驱动优化
└── 持续自我改进
```

---

## 二、Prometheus告警规则

### 2.1 核心基础设施告警

#### Kubernetes组件告警
```yaml
# kubernetes-infrastructure-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kubernetes-infrastructure
  namespace: monitoring
spec:
  groups:
  - name: kubernetes-system
    rules:
    # === Critical Infrastructure Alerts ===
    
    # API Server健康检查
    - alert: KubeAPIServerDown
      expr: absent(up{job="kubernetes-apiservers"} == 1)
      for: 5m
      labels:
        severity: critical
        category: infrastructure
        team: sre
      annotations:
        summary: "Kubernetes API Server is down"
        description: "API Server has been unreachable for more than 5 minutes. Cluster operations may be affected."
        runbook_url: "https://internal.runbook/kube-apiserver-down"
        
    # etcd集群健康
    - alert: EtcdNoLeader
      expr: etcd_server_has_leader == 0
      for: 1m
      labels:
        severity: critical
        category: infrastructure
        team: sre
      annotations:
        summary: "etcd has no leader"
        description: "etcd cluster has lost quorum. Data consistency is at risk."
        
    # 节点状态异常
    - alert: KubeNodeNotReady
      expr: kube_node_status_condition{condition="Ready",status="true"} == 0
      for: 5m
      labels:
        severity: critical
        category: infrastructure
        team: sre
      annotations:
        summary: "Node {{ $labels.node }} is NotReady"
        description: "Node has been NotReady for more than 5 minutes"
        
    # === Warning Infrastructure Alerts ===
    
    # etcd性能问题
    - alert: EtcdHighFsyncDuration
      expr: histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m])) > 0.01
      for: 5m
      labels:
        severity: warning
        category: infrastructure
        team: sre
      annotations:
        summary: "etcd fsync duration high"
        description: "etcd WAL fsync duration is above 10ms (99th percentile)"
        
    # 调度器积压
    - alert: KubeSchedulerPendingPods
      expr: scheduler_pending_pods{queue="active"} > 100
      for: 10m
      labels:
        severity: warning
        category: infrastructure
        team: sre
      annotations:
        summary: "Too many pending pods"
        description: "{{ $value }} pods are pending scheduling for more than 10 minutes"
        
    # kubelet PLEG问题
    - alert: KubeletPLEGDurationHigh
      expr: histogram_quantile(0.99, rate(kubelet_pleg_relist_duration_seconds_bucket[5m])) > 3
      for: 5m
      labels:
        severity: warning
        category: infrastructure
        team: sre
      annotations:
        summary: "Kubelet PLEG duration high"
        description: "Kubelet PLEG relist duration is above 3 seconds"
```

### 2.2 应用层告警规则

#### 应用健康度告警
```yaml
# application-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: application-alerts
  namespace: monitoring
spec:
  groups:
  - name: application-health
    rules:
    # Pod重启频繁
    - alert: PodRestartingTooMuch
      expr: increase(kube_pod_container_status_restarts_total[1h]) > 5
      for: 5m
      labels:
        severity: warning
        category: application
        team: app-team
      annotations:
        summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} restarting frequently"
        description: "Pod has restarted {{ $value }} times in the last hour"
        
    # Deployment副本不匹配
    - alert: DeploymentReplicasMismatch
      expr: |
        kube_deployment_status_replicas_available !=
        kube_deployment_spec_replicas
      for: 10m
      labels:
        severity: warning
        category: application
        team: app-team
      annotations:
        summary: "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} replicas mismatch"
        description: "Available replicas ({{ $value }}) don't match desired replicas"
        
    # PVC挂起
    - alert: PersistentVolumeClaimPending
      expr: kube_persistentvolumeclaim_status_phase{phase="Pending"} == 1
      for: 15m
      labels:
        severity: warning
        category: storage
        team: sre
      annotations:
        summary: "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} is pending"
        description: "PersistentVolumeClaim has been pending for more than 15 minutes"
        
    # HPA达到最大副本
    - alert: HPAMaxedOut
      expr: |
        kube_horizontalpodautoscaler_status_current_replicas ==
        kube_horizontalpodautoscaler_spec_max_replicas
      for: 10m
      labels:
        severity: warning
        category: autoscaling
        team: sre
      annotations:
        summary: "HPA {{ $labels.namespace }}/{{ $labels.horizontalpodautoscaler }} maxed out"
        description: "HorizontalPodAutoscaler has reached maximum replicas"
```

### 2.3 业务指标告警

#### 业务SLI/SLO告警
```yaml
# business-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: business-alerts
  namespace: monitoring
spec:
  groups:
  - name: business-metrics
    rules:
    # 高错误率
    - alert: HighErrorRate
      expr: |
        sum(rate(http_requests_total{status=~"5.."}[5m])) by (service, namespace) /
        sum(rate(http_requests_total[5m])) by (service, namespace) > 0.01
      for: 5m
      labels:
        severity: warning
        category: business
        team: app-team
      annotations:
        summary: "High error rate in {{ $labels.service }}"
        description: "Error rate is {{ $value | humanizePercentage }} (threshold: 1%)"
        
    # 高延迟
    - alert: HighLatency
      expr: |
        histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
      for: 5m
      labels:
        severity: warning
        category: business
        team: app-team
      annotations:
        summary: "High latency in {{ $labels.service }}"
        description: "95th percentile latency is {{ $value }}s (threshold: 500ms)"
        
    # 低成功率
    - alert: LowSuccessRate
      expr: |
        sum(rate(http_requests_total{status=~"2.."}[5m])) by (service) /
        sum(rate(http_requests_total[5m])) by (service) < 0.99
      for: 5m
      labels:
        severity: critical
        category: business
        team: app-team
      annotations:
        summary: "Low success rate in {{ $labels.service }}"
        description: "Success rate is {{ $value | humanizePercentage }} (SLO: 99%)"
```

---

## 三、Alertmanager配置

### 3.1 通知路由策略

#### 分层通知配置
```yaml
# alertmanager.yml
global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp.company.com:587'
  smtp_from: 'alerts@company.com'
  smtp_auth_username: 'alerts'
  smtp_auth_password: 'password'
  slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 3h
  
  # 默认接收者
  receiver: 'default-receiver'
  
  # 路由树
  routes:
    # SRE团队路由
    - matchers:
        - team = "sre"
      receiver: 'sre-team'
      routes:
        - matchers:
            - severity = "critical"
          receiver: 'sre-critical'
          repeat_interval: 30m
        - matchers:
            - severity = "warning"
          receiver: 'sre-warning'
          repeat_interval: 2h
          
    # 应用团队路由
    - matchers:
        - team = "app-team"
      receiver: 'app-team'
      group_by: ['alertname', 'service']
      
    # 业务告警路由
    - matchers:
        - category = "business"
      receiver: 'business-team'
      group_wait: 1m
      group_interval: 10m

# 告警抑制规则
inhibit_rules:
  # 当节点宕机时，抑制该节点上的所有告警
  - source_matchers:
      - alertname = "KubeNodeNotReady"
    target_matchers:
      - alertname =~ "Pod.*|Kubelet.*"
    equal: ['node', 'instance']
    
  # 当API Server宕机时，抑制所有相关告警
  - source_matchers:
      - alertname = "KubeAPIServerDown"
    target_matchers:
      - alertname =~ "Kube.*|Etcd.*"
    equal: ['cluster']

# 接收者配置
receivers:
  - name: 'default-receiver'
    email_configs:
    - to: 'oncall@sre.company.com'
      send_resolved: true
      html: '{{ template "email.default.html" . }}'
      
  - name: 'sre-critical'
    webhook_configs:
    - url: 'http://pagerduty-gateway:8080/critical'
      send_resolved: false
    email_configs:
    - to: 'sre-team@sre.company.com'
      send_resolved: true
      
  - name: 'sre-warning'
    slack_configs:
    - channel: '#sre-alerts'
      send_resolved: true
      title: '{{ template "slack.title" . }}'
      text: '{{ template "slack.text" . }}'
      
  - name: 'app-team'
    webhook_configs:
    - url: 'http://teams-gateway:8080/app-alerts'
      send_resolved: true
    email_configs:
    - to: 'app-team@company.com'
      send_resolved: true
      
  - name: 'business-team'
    slack_configs:
    - channel: '#business-impact'
      send_resolved: true
      color: '{{ if eq .Status "firing" }}danger{{ else }}good{{ end }}'
    pagerduty_configs:
    - service_key: 'BUSINESS_SERVICE_KEY'
      send_resolved: true
```

### 3.2 告警模板定制

#### 自定义告警模板
```gotemplate
{{/* templates/default.tmpl */}}

{{ define "email.default.html" }}
<!DOCTYPE html>
<html>
<head>
    <style>
        .alert-header { background-color: #f8f9fa; padding: 10px; border-left: 4px solid #dc3545; }
        .alert-body { padding: 15px; }
        .alert-footer { background-color: #f8f9fa; padding: 10px; font-size: 12px; }
    </style>
</head>
<body>
    <div class="alert-header">
        <h2>{{ .Alerts | len }} Alert{{ if gt (len .Alerts) 1 }}s{{ end }} for {{ .GroupLabels.alertname }}</h2>
        <p>Status: <strong>{{ .Status | title }}</strong></p>
    </div>
    
    <div class="alert-body">
        {{ range .Alerts }}
        <div style="margin-bottom: 20px; border: 1px solid #dee2e6; border-radius: 5px;">
            <div style="padding: 10px; background-color: {{ if eq .Labels.severity "critical" }}#f8d7da{{ else if eq .Labels.severity "warning" }}#fff3cd{{ else }}#cce7ff{{ end }}">
                <strong>Severity:</strong> {{ .Labels.severity | title }}
                <strong>Team:</strong> {{ .Labels.team }}
            </div>
            <div style="padding: 10px;">
                <p><strong>Summary:</strong> {{ .Annotations.summary }}</p>
                <p><strong>Description:</strong> {{ .Annotations.description }}</p>
                {{ if .Annotations.runbook_url }}
                <p><strong>Runbook:</strong> <a href="{{ .Annotations.runbook_url }}">{{ .Annotations.runbook_url }}</a></p>
                {{ end }}
                <p><strong>Started:</strong> {{ .StartsAt.Format "2006-01-02 15:04:05 MST" }}</p>
                {{ if ne .Status "firing" }}
                <p><strong>Resolved:</strong> {{ .EndsAt.Format "2006-01-02 15:04:05 MST" }}</p>
                {{ end }}
            </div>
        </div>
        {{ end }}
    </div>
    
    <div class="alert-footer">
        <p>Sent by Alertmanager at {{ .Alerts | len }} alerts</p>
    </div>
</body>
</html>
{{ end }}

{{ define "slack.title" }}
[{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ .CommonLabels.alertname }}
{{ end }}

{{ define "slack.text" }}
{{ range .Alerts }}
*Severity:* `{{ .Labels.severity }}`
*Summary:* {{ .Annotations.summary }}
*Description:* {{ .Annotations.description }}
{{ if .Annotations.runbook_url }}*Runbook:* <{{ .Annotations.runbook_url }}|Link>{{ end }}
*Started:* <!date^{{ .StartsAt.Unix }}^{date_num} at {time_secs}|{{ .StartsAt.Format "2006-01-02 15:04:05 MST" }}>
{{ end }}
{{ end }}
```

---

## 四、智能告警实践

### 4.1 异常检测算法

#### 基于机器学习的异常检测
```yaml
ml_based_detection:
  algorithms:
    statistical_methods:
      - z_score: 基于标准差的异常检测
      - modified_z_score: 改进的Z-score方法
      - percentiles: 百分位数检测
      
    time_series_methods:
      - holt_winters: Holt-Winters预测模型
      - seasonal_arima: 季节性ARIMA模型
      - exponential_smoothing: 指数平滑
      
    ml_methods:
      - isolation_forest: 孤立森林算法
      - one_class_svm: 单类SVM
      - lstm_autoencoder: LSTM自编码器

  implementation_example:
    # 使用Prometheus的预测函数
    predictive_alerting:
      - alert: CPUPredictionAnomaly
        expr: |
          predict_linear(node_cpu_seconds_total[1h], 4*3600) > 0.9
        for: 10m
        labels:
          severity: warning
          detection_method: predictive
          
      - alert: MemoryTrendAnomaly
        expr: |
          avg_over_time(node_memory_MemAvailable_bytes[24h]) -
          node_memory_MemAvailable_bytes < 1e9
        for: 30m
        labels:
          severity: warning
          detection_method: trend_analysis
```

### 4.2 动态阈值调整

#### 自适应阈值配置
```yaml
adaptive_thresholds:
  baseline_calculation:
    methods:
      - moving_average: 滑动平均线
      - seasonal_baseline: 季节性基线
      - historical_percentile: 历史百分位数
      - machine_learning: 机器学习模型
      
  configuration_example:
    dynamic_cpu_alert:
      alert: DynamicCPUThreshold
      expr: |
        node_cpu_seconds_total >
        (
          avg_over_time(node_cpu_seconds_total[7d:1h])
          * (1 + scalar(0.2 + 0.1 * day_of_week()))
        )
      for: 15m
      labels:
        severity: warning
        threshold_type: dynamic
        
    adaptive_error_rate:
      alert: AdaptiveErrorRate
      expr: |
        rate(http_requests_total{status=~"5.."}[5m]) /
        rate(http_requests_total[5m]) >
        (
          avg_over_time(
            rate(http_requests_total{status=~"5.."}[5m]) /
            rate(http_requests_total[5m])[24h:5m]
          ) * 1.5
        )
      for: 10m
      labels:
        severity: warning
        threshold_type: adaptive
```

---

## 五、告警治理与优化

### 5.1 告警质量评估

#### 告警健康度指标
```yaml
alert_quality_metrics:
  effectiveness_indicators:
    - alert_accuracy: 告警准确率 (>90%)
    - mttd_mean_time_to_detection: 平均检测时间 (<5分钟)
    - mttr_mean_time_to_resolution: 平均解决时间 (<30分钟)
    - false_positive_rate: 误报率 (<5%)
    - alert_silence_rate: 告警静默率 (<10%)
    
  governance_rules:
    - regular_review_cycle: 定期审查 (每月)
    - alert_retirement_policy: 告警退役策略
    - performance_benchmarking: 性能基准测试
    - stakeholder_feedback: 利益相关者反馈
```

### 5.2 告警降噪策略

#### 智能降噪实践
```yaml
noise_reduction_strategies:
  alert_suppression:
    time_based:
      - maintenance_windows: 维护窗口期间静默
      - business_hours_only: 仅工作时间告警
      - weekend_suppression: 周末降级告警
      
    context_based:
      - deployment_in_progress: 部署期间抑制
      - known_issues: 已知问题静默
      - correlation_filtering: 关联过滤
      
  intelligent_grouping:
    similarity_detection:
      - alert_fingerprinting: 告警指纹识别
      - root_cause_analysis: 根因分析聚类
      - dependency_mapping: 依赖关系分组
      
  automation_integration:
    auto_resolution:
      - self_healing_playbooks: 自愈剧本
      - runbook_execution: 运行手册执行
      - escalation_policies: 升级策略
```

---

## 六、生产运维最佳实践

### 6.1 告警演练机制

#### 定期告警演练
```yaml
alert_exercise_program:
  frequency:
    - weekly: 基础告警测试
    - monthly: 完整演练
    - quarterly: 灾难恢复演练
    
  exercise_types:
    - synthetic_alerts: 合成告警注入
    - chaos_engineering: 混沌工程实验
    - incident_simulation: 事故模拟
    - communication_drills: 沟通演练
    
  success_metrics:
    - response_time_compliance: 响应时间达标率
    - team_coordination_score: 团队协作评分
    - tool_effectiveness: 工具有效性评估
    - process_improvement: 流程改进点识别
```

### 6.2 告警生命周期管理

#### 完整生命周期流程
```
告警生命周期管理:

1. 需求分析
   ├─ 业务影响评估
   ├─ SLO/SLE定义
   └─ 告警优先级设定
   
2. 设计开发
   ├─ 告警规则编写
   ├─ 通知路由配置
   └─ 模板定制开发
   
3. 测试验证
   ├─ 告警准确性测试
   ├─ 通知渠道验证
   └─ 响应流程演练
   
4. 上线部署
   ├─ 分阶段 rollout
   ├─ 监控效果观察
   └─ 快速迭代优化
   
5. 运营维护
   ├─ 定期效果评估
   ├─ 规则持续优化
   └─ 团队培训更新
   
6. 退役归档
   ├─ 告警有效性评审
   ├─ 替代方案实施
   └─ 历史数据分析
```

---

**告警哲学**: 从"噪声制造者"到"价值创造者"，从"被动响应"到"主动预防"

---

**实施建议**: 告警质量优于数量，精准及时胜过全面覆盖，持续优化保持有效性

---

**表格维护**: Kusheet Project | **作者**: Allen Galler (allengaller@gmail.com)