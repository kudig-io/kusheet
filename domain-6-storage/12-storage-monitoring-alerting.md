# 12 - 存储监控告警与性能调优

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-02 | **运维重点**: 监控体系、告警策略、性能优化

## 目录

1. [存储监控指标体系](#存储监控指标体系)
2. [Prometheus监控配置](#prometheus监控配置)
3. [告警规则设计](#告警规则设计)
4. [性能瓶颈诊断](#性能瓶颈诊断)
5. [容量规划与预测](#容量规划与预测)
6. [存储性能调优](#存储性能调优)
7. [可视化仪表板](#可视化仪表板)
8. [自动化运维脚本](#自动化运维脚本)

---

## 存储监控指标体系

### 核心监控指标分类

```yaml
# 存储监控指标体系
storage_metrics:
  # 容量相关指标
  capacity:
    - kubelet_volume_stats_capacity_bytes      # 总容量
    - kubelet_volume_stats_available_bytes     # 可用空间
    - kubelet_volume_stats_used_bytes          # 已使用空间
    - kubelet_volume_stats_inodes              # inode总数
    - kubelet_volume_stats_inodes_free         # 可用inode
    
  # 性能相关指标
  performance:
    - kubelet_volume_stats_used_percent        # 使用率百分比
    - container_fs_writes_bytes_total          # 写入字节数
    - container_fs_reads_bytes_total           # 读取字节数
    - container_fs_writes_total                # 写入操作数
    - container_fs_reads_total                 # 读取操作数
    
  # 状态相关指标
  status:
    - kube_persistentvolume_status_phase       # PV状态
    - kube_persistentvolumeclaim_status_phase  # PVC状态
    - kube_storageclass_info                   # StorageClass信息
    
  # CSI相关指标
  csi:
    - csi_sidecar_operations_seconds           # CSI操作耗时
    - csi_sidecar_operations_failed_total      # CSI操作失败数
    - volume_attachment_status                 # 卷挂载状态
```

### 关键性能指标(KPI)定义

```yaml
# 存储系统KPI指标
storage_kpis:
  availability:
    metric: up{job="kubelet"}
    threshold: "> 99.9%"
    sla: "月度可用性99.9%"
    
  latency:
    metric: histogram_quantile(0.95, rate(container_fs_write_seconds_bucket[5m]))
    threshold: "< 10ms"
    target: "95%写入延迟低于10ms"
    
  throughput:
    metric: rate(container_fs_writes_bytes_total[5m])
    threshold: "> 100MB/s"
    target: "持续写入吞吐量100MB/s"
    
  utilization:
    metric: kubelet_volume_stats_used_percent
    threshold: "< 85%"
    target: "存储使用率保持在85%以下"
    
  error_rate:
    metric: rate(csi_sidecar_operations_failed_total[5m])
    threshold: "< 0.1%"
    target: "CSI操作错误率低于0.1%"
```

---

## Prometheus监控配置

### kubelet存储指标采集

```yaml
# prometheus-config.yaml
scrape_configs:
  # kubelet存储指标采集
  - job_name: 'kubernetes-kubelet'
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      insecure_skip_verify: true
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    kubernetes_sd_configs:
    - role: node
    relabel_configs:
    - action: labelmap
      regex: __meta_kubernetes_node_label_(.+)
    - target_label: __address__
      replacement: kubernetes.default.svc:443
    - source_labels: [__meta_kubernetes_node_name]
      regex: (.+)
      target_label: __metrics_path__
      replacement: /api/v1/nodes/${1}/proxy/metrics
    metric_relabel_configs:
    # 只保留存储相关指标
    - source_labels: [__name__]
      regex: '(kubelet_volume_stats_.+|container_fs_.+)'
      action: keep
```

### 存储专用ServiceMonitor

```yaml
# storage-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: storage-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: storage-exporter
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    relabelings:
    - sourceLabels: [__meta_kubernetes_pod_node_name]
      targetLabel: node
    metricRelabelings:
    - sourceLabels: [__name__]
      regex: '(kubelet_volume_stats_.+|storage_.+)'
      action: keep
```

### 自定义存储Exporter

```yaml
# storage-exporter-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storage-exporter
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: storage-exporter
  template:
    metadata:
      labels:
        app: storage-exporter
    spec:
      serviceAccountName: storage-exporter
      containers:
      - name: exporter
        image: kudig/storage-exporter:latest
        ports:
        - containerPort: 9100
          name: metrics
        env:
        - name: STORAGE_CLASSES
          value: "fast-ssd,standard-ssd,economy-ssd"
        - name: CHECK_INTERVAL
          value: "60s"
        resources:
          requests:
            memory: 128Mi
            cpu: 100m
          limits:
            memory: 256Mi
            cpu: 200m
---
apiVersion: v1
kind: Service
metadata:
  name: storage-exporter
  namespace: monitoring
  labels:
    app: storage-exporter
spec:
  ports:
  - port: 9100
    targetPort: 9100
    name: metrics
  selector:
    app: storage-exporter
```

---

## 告警规则设计

### 存储容量告警

```yaml
# storage-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: storage-alerts
  namespace: monitoring
spec:
  groups:
  # =================================================================
  # 容量相关告警
  # =================================================================
  - name: storage.capacity.alerts
    rules:
    # PVC使用率告警
    - alert: PVCUsageHighWarning
      expr: |
        (kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100 > 85
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "PVC {{ $labels.persistentvolumeclaim }} 使用率过高"
        description: "{{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} 使用率达到 {{ $value | printf \"%.2f\" }}%"
        runbook_url: "https://internal-docs/storage/runbooks/pvc-high-usage"
        
    - alert: PVCUsageHighCritical
      expr: |
        (kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100 > 95
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "PVC {{ $labels.persistentvolumeclaim }} 使用率严重过高"
        description: "{{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} 使用率达到 {{ $value | printf \"%.2f\" }}%，需要立即处理"
        
    # inode使用率告警
    - alert: PVCInodeUsageHigh
      expr: |
        (1 - (kubelet_volume_stats_inodes_free / kubelet_volume_stats_inodes)) * 100 > 90
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "PVC {{ $labels.persistentvolumeclaim }} inode使用率过高"
        description: "{{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} inode使用率达到 {{ $value | printf \"%.2f\" }}%"
        
    # 存储类容量告警
    - alert: StorageClassCapacityLow
      expr: |
        sum(kubelet_volume_stats_available_bytes) by (storageclass) / 
        sum(kubelet_volume_stats_capacity_bytes) by (storageclass) * 100 < 15
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "StorageClass {{ $labels.storageclass }} 可用容量不足"
        description: "存储类 {{ $labels.storageclass }} 可用容量仅剩 {{ $value | printf \"%.2f\" }}%"
```

### 存储性能告警

```yaml
  # =================================================================
  # 性能相关告警
  # =================================================================
  - name: storage.performance.alerts
    rules:
    # I/O延迟告警
    - alert: StorageHighLatency
      expr: |
        histogram_quantile(0.95, rate(container_fs_write_seconds_bucket[5m])) > 0.05
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "存储写入延迟过高"
        description: "95%写入操作延迟超过50ms，当前值: {{ $value | printf \"%.3f\" }}s"
        
    # I/O吞吐量异常
    - alert: StorageLowThroughput
      expr: |
        rate(container_fs_writes_bytes_total[5m]) < 1048576  # 1MB/s
      for: 10m
      labels:
        severity: warning
        category: performance
      annotations:
        summary: "存储写入吞吐量过低"
        description: "写入吞吐量低于1MB/s，当前值: {{ $value | printf \"%.2f\" }} bytes/s"
        
    # IOPS异常
    - alert: StorageHighIOPS
      expr: |
        rate(container_fs_writes_total[5m]) > 10000
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "存储IOPS过高"
        description: "写入IOPS超过10000，当前值: {{ $value | printf \"%.0f\" }}"
```

### 存储状态告警

```yaml
  # =================================================================
  # 状态相关告警
  # =================================================================
  - name: storage.status.alerts
    rules:
    # PVC状态异常
    - alert: PVCPendingTooLong
      expr: |
        kube_persistentvolumeclaim_status_phase{phase="Pending"} == 1
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "PVC长时间处于Pending状态"
        description: "{{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} 已Pending超过10分钟"
        
    - alert: PVCLost
      expr: |
        kube_persistentvolumeclaim_status_phase{phase="Lost"} == 1
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "PVC状态为Lost"
        description: "{{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} 状态为Lost，可能存在数据风险"
        
    # PV状态异常
    - alert: PVFailed
      expr: |
        kube_persistentvolume_status_phase{phase="Failed"} == 1
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "PV状态为Failed"
        description: "PV {{ $labels.persistentvolume }} 状态为Failed"
        
    # CSI驱动异常
    - alert: CSIDriverDown
      expr: |
        up{job="csi-driver"} == 0
      for: 3m
      labels:
        severity: critical
      annotations:
        summary: "CSI驱动服务不可用"
        description: "CSI驱动 {{ $labels.instance }} 不可用超过3分钟"
```

---

## 性能瓶颈诊断

### 存储性能分析工具

```bash
#!/bin/bash
# storage-performance-analyzer.sh

NAMESPACE=${1:-"default"}
OUTPUT_DIR="/tmp/storage-analysis-$(date +%Y%m%d-%H%M%S)"

mkdir -p $OUTPUT_DIR

analyze_storage_performance() {
  echo "🔬 存储性能分析开始..."
  echo "分析命名空间: $NAMESPACE"
  echo "输出目录: $OUTPUT_DIR"
  
  # 1. 收集基础指标
  echo "1. 收集存储基础指标..."
  kubectl get pvc -n $NAMESPACE -o json > $OUTPUT_DIR/pvc-info.json
  kubectl get pv -o json > $OUTPUT_DIR/pv-info.json
  
  # 2. 性能数据采样
  echo "2. 采样性能数据..."
  
  # 获取使用该存储的Pod列表
  PODS=$(kubectl get pods -n $NAMESPACE -o json | \
    jq -r '.items[] | select(.spec.volumes[]?.persistentVolumeClaim) | .metadata.name')
  
  for POD in $PODS; do
    echo "分析Pod: $POD"
    
    # I/O统计
    kubectl exec $POD -n $NAMESPACE -- iostat -x 1 10 > $OUTPUT_DIR/${POD}-iostat.txt 2>/dev/null || true
    
    # 磁盘使用情况
    kubectl exec $POD -n $NAMESPACE -- df -h > $OUTPUT_DIR/${POD}-disk-usage.txt 2>/dev/null || true
    
    # 文件系统统计
    kubectl exec $POD -n $NAMESPACE -- du -sh / 2>/dev/null | head -20 > $OUTPUT_DIR/${POD}-dir-sizes.txt || true
  done
  
  # 3. 生成分析报告
  echo "3. 生成分析报告..."
  
  cat > $OUTPUT_DIR/analysis-report.md <<EOF
# 存储性能分析报告

## 基础信息
- 分析时间: $(date)
- 命名空间: $NAMESPACE
- 分析Pod数量: $(echo $PODS | wc -w)

## PVC统计
$(jq -r '.items[] | "- \(.metadata.name): \(.spec.resources.requests.storage) (\(.status.phase))"' $OUTPUT_DIR/pvc-info.json)

## 性能发现
TODO: 自动生成性能分析结论

## 建议优化项
TODO: 根据分析结果提供优化建议
EOF
  
  echo "✅ 分析完成，报告位置: $OUTPUT_DIR"
}

analyze_storage_performance
```

### 瓶颈识别矩阵

```markdown
## 存储性能瓶颈识别矩阵

| 症状 | 可能原因 | 诊断方法 | 解决方案 |
|------|---------|---------|---------|
| **高延迟** | IOPS不足 | `iostat -x`检查await | 升级存储类型 |
| | 网络延迟 | `ping storage-endpoint` | 优化网络配置 |
| | 文件系统碎片 | `fsck`检查 | 重建文件系统 |
| **低吞吐量** | 带宽限制 | `iperf`测试 | 调整挂载参数 |
| | 并发不足 | `iotop`检查 | 增加iodepth |
| | 缓存未命中 | 检查应用缓存 | 优化应用缓存 |
| **CPU占用高** | 加密开销 | `top`检查进程 | 调整加密算法 |
| | 压缩比过高 | 检查压缩设置 | 调整压缩级别 |
| **内存不足** | 页面缓存过大 | `free -h`检查 | 调整vm参数 |
```

---

## 容量规划与预测

### 容量趋势分析

```python
#!/usr/bin/env python3
# capacity-planner.py

import json
import numpy as np
from datetime import datetime, timedelta
import matplotlib.pyplot as plt
from sklearn.linear_model import LinearRegression

class StorageCapacityPlanner:
    def __init__(self):
        self.history_data = []
        
    def load_history_data(self, pvc_stats_file):
        """加载历史使用数据"""
        with open(pvc_stats_file, 'r') as f:
            self.history_data = json.load(f)
            
    def predict_growth(self, pvc_name, days_ahead=30):
        """预测存储增长趋势"""
        pvc_data = [item for item in self.history_data if item['pvc'] == pvc_name]
        
        if len(pvc_data) < 7:  # 至少需要一周数据
            return None
            
        # 准备训练数据
        dates = [datetime.fromisoformat(item['timestamp']) for item in pvc_data]
        usage = [item['used_bytes'] for item in pvc_data]
        
        # 转换为天数序列
        day_numbers = [(date - dates[0]).days for date in dates]
        X = np.array(day_numbers).reshape(-1, 1)
        y = np.array(usage)
        
        # 线性回归预测
        model = LinearRegression()
        model.fit(X, y)
        
        # 预测未来
        future_days = np.arange(len(dates), len(dates) + days_ahead).reshape(-1, 1)
        predictions = model.predict(future_days)
        
        return {
            'current_usage': usage[-1],
            'growth_rate': model.coef_[0],  # 每天增长字节数
            'predictions': predictions.tolist(),
            'days_ahead': days_ahead
        }
    
    def generate_recommendations(self, pvc_name, capacity_bytes):
        """生成扩容建议"""
        prediction = self.predict_growth(pvc_name)
        if not prediction:
            return "数据不足，无法预测"
            
        current_usage = prediction['current_usage']
        growth_rate = prediction['growth_rate']
        predictions = prediction['predictions']
        
        # 计算何时达到阈值
        threshold_85 = capacity_bytes * 0.85
        threshold_95 = capacity_bytes * 0.95
        
        days_to_85 = (threshold_85 - current_usage) / growth_rate if growth_rate > 0 else float('inf')
        days_to_95 = (threshold_95 - current_usage) / growth_rate if growth_rate > 0 else float('inf')
        
        recommendations = []
        
        if days_to_85 < 7:
            recommendations.append("🔴 紧急: 7天内将达到85%使用率，建议立即扩容")
        elif days_to_85 < 30:
            recommendations.append("🟡 警告: 30天内将达到85%使用率，建议计划扩容")
        else:
            recommendations.append("🟢 正常: 使用率增长可控")
            
        if growth_rate > 0:
            monthly_growth = growth_rate * 30 / (1024**3)  # GB/月
            recommendations.append(f"📈 月度增长预测: {monthly_growth:.2f} GB/月")
            
        return '\n'.join(recommendations)

# 使用示例
if __name__ == "__main__":
    planner = StorageCapacityPlanner()
    planner.load_history_data('/tmp/storage-history.json')
    
    # 为每个PVC生成报告
    pvcs = set(item['pvc'] for item in planner.history_data)
    
    for pvc in pvcs:
        print(f"\n=== {pvc} 容量规划报告 ===")
        recommendation = planner.generate_recommendations(pvc, capacity_bytes=100*1024**3)  # 100GB
        print(recommendation)
```

### 自动化容量监控脚本

```bash
#!/bin/bash
# capacity-monitor.sh

MONITOR_NAMESPACE="production"
THRESHOLD_WARNING=80
THRESHOLD_CRITICAL=90
REPORT_FILE="/tmp/capacity-report-$(date +%Y%m%d).csv"

# 收集容量数据
collect_capacity_data() {
  echo "timestamp,pvc_namespace,pvc_name,capacity_bytes,used_bytes,usage_percent" > $REPORT_FILE
  
  kubectl get pvc -n $MONITOR_NAMESPACE -o json | \
    jq -r '.items[] | 
           "\(.metadata.creationTimestamp),\(.metadata.namespace),\(.metadata.name),\(.status.capacity.storage),\(.status.usedBytes // 0),
           \((.status.usedBytes // 0) * 100 / (.status.capacity.storage | rtrimstr("Gi") | tonumber * 1024*1024*1024))"' \
    >> $REPORT_FILE
}

# 分析容量趋势
analyze_capacity_trends() {
  echo "📊 容量趋势分析报告"
  echo "=================="
  
  # 高使用率PVC
  HIGH_USAGE=$(awk -F',' 'NR>1 && $6 > '$THRESHOLD_WARNING'' $REPORT_FILE)
  if [ -n "$HIGH_USAGE" ]; then
    echo "⚠️  高使用率PVC (>80%):"
    echo "$HIGH_USAGE" | column -t -s ','
  fi
  
  # 临界PVC
  CRITICAL_USAGE=$(awk -F',' 'NR>1 && $6 > '$THRESHOLD_CRITICAL'' $REPORT_FILE)
  if [ -n "$CRITICAL_USAGE" ]; then
    echo "🚨 临界使用率PVC (>90%):"
    echo "$CRITICAL_USAGE" | column -t -s ','
  fi
  
  # 统计信息
  TOTAL_PVC=$(($(wc -l < $REPORT_FILE) - 1))
  HIGH_COUNT=$(echo "$HIGH_USAGE" | wc -l)
  CRITICAL_COUNT=$(echo "$CRITICAL_USAGE" | wc -l)
  
  echo ""
  echo "📈 统计摘要:"
  echo "总PVC数量: $TOTAL_PVC"
  echo "高使用率数量: $HIGH_COUNT ($(echo "scale=2; $HIGH_COUNT*100/$TOTAL_PVC" | bc)%)"
  echo "临界使用率数量: $CRITICAL_COUNT ($(echo "scale=2; $CRITICAL_COUNT*100/$TOTAL_PVC" | bc)%)"
}

# 生成告警
generate_alerts() {
  CRITICAL_PVCS=$(awk -F',' 'NR>1 && $6 > '$THRESHOLD_CRITICAL'' $REPORT_FILE | cut -d',' -f3)
  
  if [ -n "$CRITICAL_PVCS" ]; then
    echo "🚨 发送临界容量告警..."
    # 这里可以集成到告警系统
    for pvc in $CRITICAL_PVCS; do
      echo "PVC $pvc 使用率超过临界值"
      # webhook调用或其他告警方式
    done
  fi
}

# 主执行流程
main() {
  collect_capacity_data
  analyze_capacity_trends
  generate_alerts
  
  echo ""
  echo "📋 详细报告已保存到: $REPORT_FILE"
}

main
```

---

## 存储性能调优

### 文件系统优化

```yaml
# 优化的挂载配置
apiVersion: v1
kind: PersistentVolume
metadata:
  name: optimized-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteOnce
  mountOptions:
    # 性能优化选项
    - noatime          # 不更新访问时间戳
    - nodiratime       # 目录不更新访问时间戳  
    - discard          # 启用TRIM支持
    - nobarrier        # 禁用写屏障（谨慎使用）
    - data=ordered     # 数据写入顺序保证
    - commit=30        # 提交间隔30秒
    - acl              # 启用ACL
  csi:
    driver: diskplugin.csi.alibabacloud.com
    fsType: ext4
    volumeAttributes:
      performanceLevel: "PL2"
      filesystemOpts: "noatime,nodiratime,discard"
```

### 应用层优化建议

```markdown
## 应用层存储优化建议

### 数据库优化
```sql
-- MySQL优化参数
SET GLOBAL innodb_flush_method = 'O_DIRECT';    -- 直接I/O
SET GLOBAL innodb_io_capacity = 2000;           -- I/O能力
SET GLOBAL innodb_io_capacity_max = 4000;       -- 最大I/O能力
SET GLOBAL innodb_flush_neighbors = 0;          -- 避免相邻页刷新
```

### 缓存策略
```yaml
# Redis持久化优化
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
data:
  redis.conf: |
    save 900 1           # 15分钟1个变更
    save 300 10          # 5分钟10个变更  
    save 60 10000        # 1分钟10000个变更
    appendfsync everysec # 每秒同步
    no-appendfsync-on-rewrite yes  # 重写时不刷盘
```

### 日志优化
```yaml
# 应用日志轮转配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: logrotate-config
data:
  logrotate.conf: |
    /var/log/app/*.log {
        daily
        rotate 30
        compress
        delaycompress
        copytruncate
        missingok
        notifempty
    }
```
```

---

## 可视化仪表板

### Grafana存储仪表板JSON

```json
{
  "dashboard": {
    "id": null,
    "title": "Kubernetes Storage Overview",
    "timezone": "browser",
    "panels": [
      {
        "type": "graph",
        "title": "Storage Usage Trend",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "sum(kubelet_volume_stats_used_bytes) by (persistentvolumeclaim, namespace)",
            "legendFormat": "{{namespace}}/{{persistentvolumeclaim}}"
          }
        ],
        "yaxes": [
          {
            "format": "bytes",
            "label": "Used Space"
          }
        ]
      },
      {
        "type": "stat",
        "title": "High Usage PVCs (>85%)",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "count((kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100 > 85)"
          }
        ]
      },
      {
        "type": "table",
        "title": "Storage Performance Metrics",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "rate(container_fs_writes_bytes_total[5m])",
            "legendFormat": "Write Throughput"
          },
          {
            "expr": "histogram_quantile(0.95, rate(container_fs_write_seconds_bucket[5m]))",
            "legendFormat": "95th Percentile Write Latency"
          }
        ]
      }
    ]
  }
}
```

---

## 自动化运维脚本

### 智能扩容脚本

```bash
#!/bin/bash
# smart-auto-expansion.sh

check_and_expand() {
  PVC_NAME=$1
  NAMESPACE=$2
  THRESHOLD_PERCENT=85
  EXPANSION_INCREMENT="50Gi"
  
  # 获取当前使用率
  USAGE_PERCENT=$(kubectl get pvc $PVC_NAME -n $NAMESPACE -o jsonpath='{.status.capacity.storage}' | \
    awk '{gsub(/Gi$/,""); print $1}')
    
  CURRENT_REQUEST=$(kubectl get pvc $PVC_NAME -n $NAMESPACE -o jsonpath='{.spec.resources.requests.storage}' | \
    awk '{gsub(/Gi$/,""); print $1}')
    
  USAGE_RATIO=$(echo "scale=2; $USAGE_PERCENT / $CURRENT_REQUEST * 100" | bc)
  
  echo "PVC: $NAMESPACE/$PVC_NAME"
  echo "当前使用率: ${USAGE_RATIO}%"
  
  # 判断是否需要扩容
  if (( $(echo "$USAGE_RATIO > $THRESHOLD_PERCENT" | bc -l) )); then
    NEW_SIZE=$(echo "$CURRENT_REQUEST + ${EXPANSION_INCREMENT%Gi}" | bc)
    echo "🔄 触发自动扩容: ${CURRENT_REQUEST}Gi → ${NEW_SIZE}Gi"
    
    # 创建快照备份
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: auto-backup-${PVC_NAME}-${TIMESTAMP}
  namespace: $NAMESPACE
spec:
  volumeSnapshotClassName: default-snapshot-class
  source:
    persistentVolumeClaimName: $PVC_NAME
EOF
    
    # 执行扩容
    kubectl patch pvc $PVC_NAME -n $NAMESPACE -p '{"spec":{"resources":{"requests":{"storage":"'${NEW_SIZE}'Gi"}}}}'
    
    echo "✅ 扩容完成"
  else
    echo "✅ 使用率正常，无需扩容"
  fi
}

# 批量检查所有PVC
kubectl get pvc --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}' | \
  while read namespace pvc; do
    check_and_expand "$pvc" "$namespace"
  done
```

---