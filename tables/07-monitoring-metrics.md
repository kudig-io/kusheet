# 表格7：监控和指标表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/cluster-administration/system-metrics](https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/)

## 监控架构概览

```
Kubernetes监控架构:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         Prometheus Stack                             │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐    │   │
│  │  │Prometheus│  │Alertman- │  │ Grafana  │  │ Thanos/Cortex    │    │   │
│  │  │ Server   │  │  ager    │  │Dashboard │  │  (长期存储)       │    │   │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────────┬─────────┘    │   │
│  └───────┼─────────────┼─────────────┼─────────────────┼──────────────┘   │
│          │             │             │                 │                   │
│  ┌───────┴─────────────┴─────────────┴─────────────────┴──────────────┐   │
│  │                        指标采集层                                    │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐           │   │
│  │  │kube-state│  │  node-   │  │ cAdvisor │  │ 组件自带  │           │   │
│  │  │-metrics  │  │ exporter │  │ (kubelet)│  │  /metrics │           │   │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘           │   │
│  └───────┼─────────────┼─────────────┼─────────────┼──────────────────┘   │
│          │             │             │             │                       │
│  ┌───────┴─────────────┴─────────────┴─────────────┴──────────────────┐   │
│  │                        Kubernetes 集群                               │   │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐        │   │
│  │  │ Control Plane  │  │  Worker Nodes  │  │   Workloads    │        │   │
│  │  │ apiserver      │  │  kubelet       │  │   应用Pod      │        │   │
│  │  │ scheduler      │  │  kube-proxy    │  │   业务指标     │        │   │
│  │  │ controller     │  │  容器运行时     │  │                │        │   │
│  │  │ etcd           │  │                │  │                │        │   │
│  │  └────────────────┘  └────────────────┘  └────────────────┘        │   │
│  └────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

指标类型说明:
• Counter:  累计值，只增不减 (如请求总数)
• Gauge:    即时值，可增可减 (如当前连接数)
• Histogram: 分布统计，含bucket (如延迟分布)
• Summary:  类似Histogram，预计算分位数
```

## kube-apiserver 关键指标

### 请求指标

| 指标名称 | 类型 | 标签 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|------|-------------|---------|
| `apiserver_request_total` | Counter | verb, resource, code, component | API请求总数 | 5xx错误率>1% | 监控API健康 |
| `apiserver_request_duration_seconds` | Histogram | verb, resource | API请求延迟 | P99>1s | 性能问题排查 |
| `apiserver_current_inflight_requests` | Gauge | request_kind | 当前进行中请求数 | >80%限制值 | 过载检测 |
| `apiserver_longrunning_requests` | Gauge | verb, resource | 长运行请求数(watch等) | 异常增长 | Watch泄漏检测 |
| `apiserver_request_terminations_total` | Counter | verb, resource, code | 请求终止数 | 快速增长 | 超时问题 |
| `apiserver_dropped_requests_total` | Counter | request_kind | 被丢弃请求数 | >0 | 过载保护触发 |

### 审计和认证指标

| 指标名称 | 类型 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|-------------|---------|
| `apiserver_audit_event_total` | Counter | 审计事件数 | - | 审计监控 |
| `apiserver_audit_error_total` | Counter | 审计错误数 | >0 | 审计系统问题 |
| `apiserver_authentication_attempts` | Counter | 认证尝试数 | 失败率>5% | 认证问题 |
| `apiserver_authentication_duration_seconds` | Histogram | 认证延迟 | P99>100ms | 认证性能 |

### 存储指标

| 指标名称 | 类型 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|-------------|---------|
| `apiserver_storage_objects` | Gauge | etcd对象数(按resource) | 接近配额 | 存储容量 |
| `apiserver_storage_list_duration_seconds` | Histogram | 列表操作延迟 | P99>1s | etcd性能 |
| `apiserver_storage_db_total_size_in_bytes` | Gauge | etcd数据库大小 | >6GB | 存储容量 |

### Watch指标

| 指标名称 | 类型 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|-------------|---------|
| `apiserver_watch_events_total` | Counter | Watch事件总数 | - | Watch监控 |
| `apiserver_watch_events_sizes` | Histogram | Watch事件大小 | 大事件过多 | 带宽问题 |
| `apiserver_registered_watchers` | Gauge | 注册的Watch数 | 快速增长 | Watch泄漏 |

## etcd 关键指标

### 集群健康指标

| 指标名称 | 类型 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|-------------|---------|
| `etcd_server_has_leader` | Gauge | 是否有Leader | =0 **严重** | 集群健康 |
| `etcd_server_leader_changes_seen_total` | Counter | Leader切换次数 | >3/h | 稳定性问题 |
| `etcd_server_is_leader` | Gauge | 是否是Leader | - | Leader分布 |
| `etcd_server_proposals_committed_total` | Counter | 已提交提案数 | - | Raft健康 |
| `etcd_server_proposals_applied_total` | Counter | 已应用提案数 | 落后committed | 应用延迟 |
| `etcd_server_proposals_pending` | Gauge | 待处理提案数 | >5 | 性能问题 |
| `etcd_server_proposals_failed_total` | Counter | 失败提案数 | >0持续 | Raft问题 |

### 磁盘性能指标

| 指标名称 | 类型 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|-------------|---------|
| `etcd_disk_wal_fsync_duration_seconds` | Histogram | WAL同步延迟 | P99>10ms **警告** | 磁盘性能 |
| `etcd_disk_backend_commit_duration_seconds` | Histogram | 后端提交延迟 | P99>25ms | 磁盘性能 |
| `etcd_disk_backend_defrag_duration_seconds` | Histogram | 碎片整理延迟 | - | 维护监控 |
| `etcd_disk_backend_snapshot_duration_seconds` | Histogram | 快照延迟 | >30s | 备份性能 |

### 存储指标

| 指标名称 | 类型 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|-------------|---------|
| `etcd_mvcc_db_total_size_in_bytes` | Gauge | 数据库大小 | >80%配额 | 存储容量 |
| `etcd_mvcc_db_total_size_in_use_in_bytes` | Gauge | 实际使用大小 | - | 碎片率计算 |
| `etcd_debugging_mvcc_keys_total` | Gauge | 键总数 | 快速增长 | 对象泄漏 |
| `etcd_debugging_mvcc_pending_events_total` | Gauge | 待处理事件数 | - | 事件积压 |

### 网络指标

| 指标名称 | 类型 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|-------------|---------|
| `etcd_network_peer_round_trip_time_seconds` | Histogram | 对等节点RTT | P99>100ms | 网络问题 |
| `etcd_network_peer_sent_bytes_total` | Counter | 发送到对等节点字节 | - | 网络流量 |
| `etcd_network_client_grpc_sent_bytes_total` | Counter | gRPC发送字节 | - | 客户端流量 |

## kube-scheduler 关键指标

| 指标名称 | 类型 | 标签 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|------|-------------|---------|
| `scheduler_pending_pods` | Gauge | queue | 待调度Pod数 | >100持续10m | 调度瓶颈 |
| `scheduler_pod_scheduling_duration_seconds` | Histogram | attempts | 调度延迟 | P99>5s | 调度性能 |
| `scheduler_schedule_attempts_total` | Counter | result, profile | 调度尝试数 | unschedulable增长 | 资源不足 |
| `scheduler_scheduling_algorithm_duration_seconds` | Histogram | - | 算法执行时间 | P99>100ms | 算法性能 |
| `scheduler_preemption_attempts_total` | Counter | - | 抢占尝试数 | 持续增长 | 资源竞争 |
| `scheduler_preemption_victims` | Gauge | - | 抢占受害者数 | >0 | 资源压力 |
| `scheduler_framework_extension_point_duration_seconds` | Histogram | extension_point, profile | 插件执行时间 | P99>50ms | 插件性能 |
| `scheduler_queue_incoming_pods_total` | Counter | event, queue | 入队Pod数 | - | 流量监控 |
| `scheduler_unschedulable_pods` | Gauge | plugin, profile | 不可调度Pod数 | >0持续 | 调度问题 |

## kube-controller-manager 关键指标

| 指标名称 | 类型 | 标签 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|------|-------------|---------|
| `workqueue_depth` | Gauge | name | 工作队列深度 | >100 | 控制器积压 |
| `workqueue_adds_total` | Counter | name | 队列添加数 | - | 负载监控 |
| `workqueue_queue_duration_seconds` | Histogram | name | 队列等待时间 | P99>30s | 处理延迟 |
| `workqueue_work_duration_seconds` | Histogram | name | 处理时间 | P99>10s | 处理性能 |
| `workqueue_retries_total` | Counter | name | 重试次数 | 快速增长 | 错误率 |
| `workqueue_longest_running_processor_seconds` | Gauge | name | 最长运行处理器 | >5m | 处理卡住 |
| `node_collector_evictions_total` | Counter | zone | 节点驱逐数 | >0 | 节点故障 |
| `cronjob_controller_cronjob_job_creation_skew_duration_seconds` | Histogram | - | CronJob偏差 | P99>60s | 定时准确性 |

## kubelet 关键指标

### Pod和容器指标

| 指标名称 | 类型 | 标签 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|------|-------------|---------|
| `kubelet_running_pods` | Gauge | - | 运行中Pod数 | 接近max-pods | 节点容量 |
| `kubelet_running_containers` | Gauge | container_state | 运行中容器数 | - | 容器密度 |
| `kubelet_pod_start_duration_seconds` | Histogram | - | Pod启动延迟 | P99>60s | 启动性能 |
| `kubelet_pod_worker_duration_seconds` | Histogram | operation_type | Pod工作时间 | P99>10s | 工作延迟 |
| `kubelet_containers_per_pod_count` | Histogram | - | 每Pod容器数 | - | 容器分布 |

### PLEG指标 (关键)

| 指标名称 | 类型 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|-------------|---------|
| `kubelet_pleg_relist_duration_seconds` | Histogram | PLEG刷新延迟 | **P99>3s 严重** | PLEG健康 |
| `kubelet_pleg_relist_interval_seconds` | Histogram | PLEG刷新间隔 | >3s | PLEG频率 |
| `kubelet_pleg_last_seen_seconds` | Gauge | 最后一次PLEG时间 | >5分钟前 | PLEG卡死 |
| `kubelet_pleg_discard_events` | Counter | 丢弃事件数 | >0 | 事件丢失 |

### 资源和驱逐指标

| 指标名称 | 类型 | 标签 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|------|-------------|---------|
| `kubelet_evictions` | Counter | eviction_signal | 驱逐次数 | >0 | 资源压力 |
| `kubelet_node_status_update_duration_seconds` | Histogram | - | 状态更新延迟 | P99>10s | 状态同步 |
| `kubelet_volume_stats_used_bytes` | Gauge | namespace, pvc | 卷使用量 | >85%容量 | 存储告警 |
| `kubelet_volume_stats_capacity_bytes` | Gauge | namespace, pvc | 卷容量 | - | 容量规划 |
| `kubelet_volume_stats_available_bytes` | Gauge | namespace, pvc | 卷可用量 | <15% | 存储告警 |
| `kubelet_volume_stats_inodes_used` | Gauge | namespace, pvc | inode使用 | >90% | inode告警 |

### cgroup和运行时指标

| 指标名称 | 类型 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|-------------|---------|
| `kubelet_cgroup_manager_duration_seconds` | Histogram | cgroup管理延迟 | P99>100ms | cgroup性能 |
| `kubelet_container_log_filesystem_used_bytes` | Gauge | 容器日志使用量 | 快速增长 | 日志管理 |
| `kubelet_runtime_operations_total` | Counter | 运行时操作总数 | - | 运行时负载 |
| `kubelet_runtime_operations_duration_seconds` | Histogram | 运行时操作延迟 | P99>1s | 运行时性能 |
| `kubelet_runtime_operations_errors_total` | Counter | 运行时操作错误 | >0持续 | 运行时问题 |

## kube-proxy 关键指标

| 指标名称 | 类型 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|-------------|---------|
| `kubeproxy_sync_proxy_rules_duration_seconds` | Histogram | 规则同步延迟 | P99>5s | 同步性能 |
| `kubeproxy_sync_proxy_rules_last_timestamp_seconds` | Gauge | 最后同步时间戳 | >60s前 | 同步健康 |
| `kubeproxy_network_programming_duration_seconds` | Histogram | 网络编程延迟 | P99>10s | 规则更新 |
| `kubeproxy_sync_proxy_rules_iptables_total` | Counter | iptables规则数 | >10000 | 规则膨胀 |
| `kubeproxy_sync_proxy_rules_endpoint_changes_total` | Counter | 端点变更数 | - | 变更监控 |
| `kubeproxy_sync_proxy_rules_service_changes_total` | Counter | Service变更数 | - | 变更监控 |
| `kubeproxy_sync_proxy_rules_iptables_restore_failures_total` | Counter | iptables恢复失败 | >0 | 规则问题 |

## 节点资源指标 (Node Exporter / cAdvisor)

### 节点级指标 (Node Exporter)

| 指标名称 | 类型 | 说明 | 告警阈值建议 | PromQL示例 |
|---------|------|------|-------------|-----------|
| `node_cpu_seconds_total` | Counter | CPU使用时间 | 使用率>80% | `rate(node_cpu_seconds_total{mode!="idle"}[5m])` |
| `node_memory_MemTotal_bytes` | Gauge | 总内存 | - | - |
| `node_memory_MemAvailable_bytes` | Gauge | 可用内存 | <10% | `node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes` |
| `node_filesystem_avail_bytes` | Gauge | 文件系统可用 | <15% | - |
| `node_filesystem_size_bytes` | Gauge | 文件系统大小 | - | - |
| `node_disk_io_time_seconds_total` | Counter | 磁盘IO时间 | 饱和>80% | `rate(node_disk_io_time_seconds_total[5m])` |
| `node_disk_read_bytes_total` | Counter | 磁盘读取字节 | - | `rate(node_disk_read_bytes_total[5m])` |
| `node_disk_written_bytes_total` | Counter | 磁盘写入字节 | - | `rate(node_disk_written_bytes_total[5m])` |
| `node_network_receive_bytes_total` | Counter | 网络接收字节 | - | `rate(node_network_receive_bytes_total[5m])` |
| `node_network_transmit_bytes_total` | Counter | 网络发送字节 | - | `rate(node_network_transmit_bytes_total[5m])` |
| `node_load1` | Gauge | 1分钟负载 | >CPU核数 | - |
| `node_load5` | Gauge | 5分钟负载 | >CPU核数 | - |
| `node_load15` | Gauge | 15分钟负载 | >CPU核数 | - |

### 容器级指标 (cAdvisor)

| 指标名称 | 类型 | 标签 | 说明 | 告警阈值建议 |
|---------|------|------|------|-------------|
| `container_cpu_usage_seconds_total` | Counter | container, pod, namespace | 容器CPU使用 | 接近limits |
| `container_cpu_cfs_throttled_seconds_total` | Counter | container, pod, namespace | CPU被限流时间 | >0持续 |
| `container_memory_working_set_bytes` | Gauge | container, pod, namespace | 容器内存使用 | >limits触发OOM |
| `container_memory_rss` | Gauge | container, pod, namespace | 容器RSS内存 | - |
| `container_network_receive_bytes_total` | Counter | pod, namespace | 容器网络接收 | - |
| `container_network_transmit_bytes_total` | Counter | pod, namespace | 容器网络发送 | - |
| `container_fs_usage_bytes` | Gauge | container, pod, namespace | 容器文件系统使用 | >80% |
| `container_fs_reads_bytes_total` | Counter | container, pod, namespace | 容器文件系统读取 | - |
| `container_fs_writes_bytes_total` | Counter | container, pod, namespace | 容器文件系统写入 | - |
| `container_oom_events_total` | Counter | container, pod, namespace | OOM事件数 | >0 |

## kube-state-metrics 关键指标

### Pod状态指标

| 指标名称 | 类型 | 标签 | 说明 | 告警阈值建议 |
|---------|------|------|------|-------------|
| `kube_pod_status_phase` | Gauge | phase, namespace, pod | Pod阶段状态 | Pending/Failed持续 |
| `kube_pod_container_status_restarts_total` | Counter | namespace, pod, container | 容器重启次数 | >5/h |
| `kube_pod_container_status_waiting_reason` | Gauge | reason, namespace, pod | 容器等待原因 | CrashLoopBackOff |
| `kube_pod_container_status_terminated_reason` | Gauge | reason, namespace, pod | 容器终止原因 | OOMKilled |
| `kube_pod_container_resource_requests` | Gauge | resource, namespace, pod | 资源请求 | - |
| `kube_pod_container_resource_limits` | Gauge | resource, namespace, pod | 资源限制 | - |
| `kube_pod_status_ready` | Gauge | namespace, pod | Pod就绪状态 | =0持续 |
| `kube_pod_status_scheduled` | Gauge | namespace, pod | Pod调度状态 | =0 |

### 部署和控制器指标

| 指标名称 | 类型 | 标签 | 说明 | 告警阈值建议 |
|---------|------|------|------|-------------|
| `kube_deployment_status_replicas` | Gauge | namespace, deployment | 当前副本数 | - |
| `kube_deployment_status_replicas_available` | Gauge | namespace, deployment | 可用副本数 | <期望副本 |
| `kube_deployment_status_replicas_unavailable` | Gauge | namespace, deployment | 不可用副本数 | >0 |
| `kube_deployment_spec_replicas` | Gauge | namespace, deployment | 期望副本数 | - |
| `kube_statefulset_status_replicas_ready` | Gauge | namespace, statefulset | 就绪副本数 | <期望 |
| `kube_daemonset_status_number_unavailable` | Gauge | namespace, daemonset | 不可用数 | >0 |
| `kube_replicaset_status_ready_replicas` | Gauge | namespace, replicaset | 就绪副本数 | - |

### 节点状态指标

| 指标名称 | 类型 | 标签 | 说明 | 告警阈值建议 |
|---------|------|------|------|-------------|
| `kube_node_status_condition` | Gauge | condition, status, node | 节点状态条件 | Ready!=True |
| `kube_node_status_allocatable` | Gauge | resource, node | 节点可分配资源 | - |
| `kube_node_status_capacity` | Gauge | resource, node | 节点容量 | - |
| `kube_node_spec_unschedulable` | Gauge | node | 节点不可调度 | =1 |
| `kube_node_spec_taint` | Gauge | key, effect, node | 节点污点 | - |

### 其他重要指标

| 指标名称 | 类型 | 说明 | 告警阈值建议 |
|---------|------|------|-------------|
| `kube_namespace_status_phase` | Gauge | 命名空间状态 | Terminating卡住 |
| `kube_job_status_failed` | Gauge | 失败Job数 | >0 |
| `kube_job_status_succeeded` | Gauge | 成功Job数 | - |
| `kube_cronjob_next_schedule_time` | Gauge | 下次调度时间 | - |
| `kube_cronjob_status_last_schedule_time` | Gauge | 上次调度时间 | 超过预期 |
| `kube_persistentvolumeclaim_status_phase` | Gauge | PVC状态 | Pending持续 |
| `kube_persistentvolume_status_phase` | Gauge | PV状态 | Failed/Released |
| `kube_horizontalpodautoscaler_status_current_replicas` | Gauge | HPA当前副本 | 达到max |
| `kube_horizontalpodautoscaler_spec_max_replicas` | Gauge | HPA最大副本 | - |
| `kube_resourcequota_used` | Gauge | 配额使用量 | >80% |
| `kube_resourcequota_hard` | Gauge | 配额限制 | - |

## CoreDNS 关键指标

| 指标名称 | 类型 | 标签 | 说明 | 告警阈值建议 |
|---------|------|------|------|-------------|
| `coredns_dns_requests_total` | Counter | server, type, proto | DNS请求总数 | - |
| `coredns_dns_responses_total` | Counter | server, rcode | DNS响应总数 | SERVFAIL>1% |
| `coredns_dns_request_duration_seconds` | Histogram | server, type | DNS请求延迟 | P99>100ms |
| `coredns_cache_hits_total` | Counter | server, type | 缓存命中数 | - |
| `coredns_cache_misses_total` | Counter | server | 缓存未命中数 | 命中率<50% |
| `coredns_cache_size` | Gauge | server, type | 缓存大小 | - |
| `coredns_forward_requests_total` | Counter | to | 转发请求数 | - |
| `coredns_forward_responses_total` | Counter | to, rcode | 转发响应数 | 错误增长 |
| `coredns_forward_healthcheck_failures_total` | Counter | to | 健康检查失败 | >0 |
| `coredns_panics_total` | Counter | - | Panic次数 | >0 |
| `coredns_dns_do_count_total` | Counter | server | DNSSEC请求数 | - |

## Prometheus 告警规则示例

### 控制平面告警

```yaml
groups:
- name: kubernetes-control-plane
  rules:
  # API Server告警
  - alert: KubeAPIServerDown
    expr: absent(up{job="kubernetes-apiservers"} == 1)
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Kubernetes API Server is down"
      description: "API Server {{ $labels.instance }} is not responding"
  
  - alert: KubeAPIServerLatencyHigh
    expr: |
      histogram_quantile(0.99, 
        sum(rate(apiserver_request_duration_seconds_bucket{verb!="WATCH"}[5m])) by (le, verb, resource)
      ) > 1
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "API Server high latency"
      description: "API Server {{ $labels.verb }} {{ $labels.resource }} P99 latency > 1s"
  
  - alert: KubeAPIServerErrors
    expr: |
      sum(rate(apiserver_request_total{code=~"5.."}[5m])) 
      / sum(rate(apiserver_request_total[5m])) > 0.01
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "API Server error rate high"
      description: "API Server 5xx error rate > 1%"
  
  - alert: KubeAPIServerOverloaded
    expr: |
      apiserver_current_inflight_requests / on() group_left() 
      (apiserver_current_inflight_requests_limit) > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "API Server is overloaded"

  # etcd告警
  - alert: EtcdNoLeader
    expr: etcd_server_has_leader == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "etcd cluster has no leader"
      description: "etcd member {{ $labels.instance }} has no leader"
  
  - alert: EtcdHighLeaderChanges
    expr: increase(etcd_server_leader_changes_seen_total[1h]) > 3
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd leader changes frequently"
  
  - alert: EtcdHighFsyncDuration
    expr: |
      histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m])) > 0.01
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd fsync latency high"
      description: "etcd WAL fsync P99 > 10ms, indicates disk performance issue"
  
  - alert: EtcdDatabaseSpaceExceeded
    expr: etcd_mvcc_db_total_size_in_bytes > 7516192768  # 7GB
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "etcd database size approaching quota"
  
  - alert: EtcdHighNumberOfFailedProposals
    expr: increase(etcd_server_proposals_failed_total[1h]) > 5
    for: 5m
    labels:
      severity: warning

  # 调度器告警
  - alert: KubeSchedulerPendingPods
    expr: scheduler_pending_pods > 100
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Scheduler has too many pending pods"
      description: "{{ $value }} pods pending for scheduling"
  
  - alert: KubeSchedulerLatencyHigh
    expr: |
      histogram_quantile(0.99, rate(scheduler_pod_scheduling_duration_seconds_bucket[5m])) > 5
    for: 10m
    labels:
      severity: warning
```

### 节点和kubelet告警

```yaml
groups:
- name: kubernetes-nodes
  rules:
  # 节点状态
  - alert: KubeNodeNotReady
    expr: kube_node_status_condition{condition="Ready",status="true"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Node {{ $labels.node }} is not ready"
  
  - alert: KubeNodeUnschedulable
    expr: kube_node_spec_unschedulable == 1
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Node {{ $labels.node }} is unschedulable"
  
  # kubelet PLEG
  - alert: KubeletPLEGDurationHigh
    expr: |
      histogram_quantile(0.99, rate(kubelet_pleg_relist_duration_seconds_bucket[5m])) > 3
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Kubelet PLEG duration high"
      description: "PLEG relist duration P99 > 3s on {{ $labels.node }}"
  
  - alert: KubeletPodStartLatencyHigh
    expr: |
      histogram_quantile(0.99, rate(kubelet_pod_start_duration_seconds_bucket[5m])) > 60
    for: 10m
    labels:
      severity: warning
  
  # 资源压力
  - alert: NodeMemoryPressure
    expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.9
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Node {{ $labels.instance }} memory usage > 90%"
  
  - alert: NodeDiskPressure
    expr: |
      (1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) > 0.85
    for: 5m
    labels:
      severity: warning
  
  - alert: NodeCPUPressure
    expr: |
      100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 10m
    labels:
      severity: warning

  # 驱逐
  - alert: KubeletEvictions
    expr: increase(kubelet_evictions[1h]) > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Kubelet evictions detected"
      description: "Node {{ $labels.node }} has evictions"
```

### 工作负载告警

```yaml
groups:
- name: kubernetes-workloads
  rules:
  # Pod重启
  - alert: PodRestartingTooMuch
    expr: increase(kube_pod_container_status_restarts_total[1h]) > 5
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Pod restarting frequently"
      description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} restarted {{ $value }} times in 1h"
  
  # Pod状态
  - alert: PodNotReady
    expr: |
      sum by (namespace, pod) (kube_pod_status_phase{phase=~"Pending|Unknown"}) > 0
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "Pod not ready"
  
  - alert: PodCrashLooping
    expr: |
      kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"} == 1
    for: 5m
    labels:
      severity: warning
  
  # OOM
  - alert: ContainerOOMKilled
    expr: |
      kube_pod_container_status_terminated_reason{reason="OOMKilled"} == 1
    for: 0m
    labels:
      severity: warning
    annotations:
      summary: "Container OOMKilled"
      description: "Container {{ $labels.container }} in {{ $labels.namespace }}/{{ $labels.pod }} was OOMKilled"
  
  # Deployment
  - alert: DeploymentReplicasMismatch
    expr: |
      kube_deployment_status_replicas_available != kube_deployment_spec_replicas
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "Deployment replicas mismatch"
  
  - alert: DeploymentGenerationMismatch
    expr: |
      kube_deployment_status_observed_generation != kube_deployment_metadata_generation
    for: 10m
    labels:
      severity: warning
  
  # DaemonSet
  - alert: DaemonSetNotScheduled
    expr: |
      kube_daemonset_status_desired_number_scheduled - kube_daemonset_status_current_number_scheduled > 0
    for: 10m
    labels:
      severity: warning
  
  # StatefulSet
  - alert: StatefulSetReplicasMismatch
    expr: |
      kube_statefulset_status_replicas_ready != kube_statefulset_status_replicas
    for: 15m
    labels:
      severity: warning

  # HPA
  - alert: HPAMaxedOut
    expr: |
      kube_horizontalpodautoscaler_status_current_replicas == kube_horizontalpodautoscaler_spec_max_replicas
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "HPA has reached max replicas"
```

### PVC和存储告警

```yaml
groups:
- name: kubernetes-storage
  rules:
  - alert: PersistentVolumeClaimPending
    expr: kube_persistentvolumeclaim_status_phase{phase="Pending"} == 1
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "PVC pending"
      description: "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} is pending"
  
  - alert: PersistentVolumeError
    expr: kube_persistentvolume_status_phase{phase=~"Failed|Released"} == 1
    for: 5m
    labels:
      severity: warning
  
  - alert: PVCUsageHigh
    expr: |
      kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "PVC usage > 85%"
      description: "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} usage is {{ $value | humanizePercentage }}"
  
  - alert: PVCInodeUsageHigh
    expr: |
      kubelet_volume_stats_inodes_used / kubelet_volume_stats_inodes > 0.9
    for: 5m
    labels:
      severity: warning
```

## 指标获取命令

```bash
# 获取API Server指标
kubectl get --raw /metrics

# 获取Metrics API (需要Metrics Server)
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods

# 查看kubelet指标 (需要适当权限)
kubectl get --raw /api/v1/nodes/<node>/proxy/metrics

# 获取etcd指标 (在master节点上)
curl -k --cert /etc/kubernetes/pki/etcd/server.crt \
  --key /etc/kubernetes/pki/etcd/server.key \
  https://localhost:2379/metrics

# 查看kube-state-metrics指标
kubectl get --raw /api/v1/namespaces/monitoring/services/kube-state-metrics:8080/proxy/metrics

# 检查特定指标
kubectl get --raw /metrics | grep apiserver_request_total
kubectl get --raw /metrics | grep etcd_server_has_leader
kubectl get --raw /metrics | grep scheduler_pending_pods

# 使用promtool检查告警规则
promtool check rules alerts.yaml

# 测试告警规则
promtool test rules test.yaml
```

## ACK 监控集成

| 组件 | ACK集成方式 | 数据源 | 告警配置 | 说明 |
|-----|------------|-------|---------|------|
| **ARMS Prometheus** | 一键安装 | 全组件指标 | ARMS告警规则 | 推荐方案 |
| **云监控** | 自动集成 | 节点/Pod基础指标 | 云监控告警 | 基础监控 |
| **SLS** | 可选安装 | 日志/审计 | SLS告警 | 日志分析 |
| **AHAS** | 可选安装 | 应用级指标 | 自定义规则 | 限流熔断 |

### ACK ARMS Prometheus配置示例

```yaml
# 在ACK中配置自定义告警规则
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: custom-alerts
  namespace: arms-prom
  labels:
    prometheus: k8s
    role: alert-rules
spec:
  groups:
  - name: custom.rules
    rules:
    - alert: HighPodCPUUsage
      expr: |
        sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (namespace, pod)
        / sum(kube_pod_container_resource_limits{resource="cpu"}) by (namespace, pod) > 0.9
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod CPU usage > 90% of limit"
```

---

**监控最佳实践**:
1. 建立监控金字塔: 基础设施 → 平台 → 应用
2. 告警分级: Critical(立即响应) → Warning(关注) → Info(记录)
3. 避免告警疲劳: 合理设置阈值和持续时间
4. 建立Runbook: 每个告警对应处理流程
5. 定期审查: 清理无效告警，优化阈值
