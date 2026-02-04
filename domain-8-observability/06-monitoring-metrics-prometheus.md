# 07 - 监控和指标表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/cluster-administration/system-metrics](https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/)

## kube-apiserver 关键指标

| 指标名称 | 类型 | 来源 | 说明 | 版本添加 | 告警阈值建议 | 运维场景 |
|---------|------|------|------|---------|-------------|---------|
| `apiserver_request_total` | Counter | apiserver | API请求总数(按verb/resource/code分组) | 稳定 | 5xx错误率>1% | 监控API健康 |
| `apiserver_request_duration_seconds` | Histogram | apiserver | API请求延迟 | 稳定 | P99>1s | 性能问题排查 |
| `apiserver_current_inflight_requests` | Gauge | apiserver | 当前进行中请求数 | 稳定 | >80%限制值 | 过载检测 |
| `apiserver_longrunning_requests` | Gauge | apiserver | 长运行请求数(watch等) | 稳定 | 异常增长 | Watch泄漏检测 |
| `apiserver_request_terminations_total` | Counter | apiserver | 请求终止数 | 稳定 | 快速增长 | 超时问题 |
| `apiserver_audit_event_total` | Counter | apiserver | 审计事件数 | v1.29增强 | - | 审计监控 |
| `apiserver_storage_objects` | Gauge | apiserver | etcd对象数(按resource) | 稳定 | 接近配额 | 存储容量 |
| `apiserver_admission_controller_admission_duration_seconds` | Histogram | apiserver | 准入控制延迟 | 稳定 | P99>500ms | 准入性能 |
| `apiserver_watch_events_total` | Counter | apiserver | Watch事件总数 | 稳定 | - | Watch监控 |
| `apiserver_watch_events_sizes` | Histogram | apiserver | Watch事件大小 | 稳定 | 大事件过多 | 带宽问题 |

## etcd 关键指标

| 指标名称 | 类型 | 来源 | 说明 | 版本添加 | 告警阈值建议 | 运维场景 |
|---------|------|------|------|---------|-------------|---------|
| `etcd_server_has_leader` | Gauge | etcd | 是否有Leader | 稳定 | =0 | 集群健康 |
| `etcd_server_leader_changes_seen_total` | Counter | etcd | Leader切换次数 | 稳定 | >3/h | 稳定性问题 |
| `etcd_disk_wal_fsync_duration_seconds` | Histogram | etcd | WAL同步延迟 | 稳定 | P99>10ms | 磁盘性能 |
| `etcd_disk_backend_commit_duration_seconds` | Histogram | etcd | 后端提交延迟 | 稳定 | P99>25ms | 磁盘性能 |
| `etcd_mvcc_db_total_size_in_bytes` | Gauge | etcd | 数据库大小 | 稳定 | >80%配额 | 存储容量 |
| `etcd_mvcc_db_total_size_in_use_in_bytes` | Gauge | etcd | 实际使用大小 | 稳定 | - | 碎片率计算 |
| `etcd_network_peer_round_trip_time_seconds` | Histogram | etcd | 对等节点RTT | 稳定 | P99>100ms | 网络问题 |
| `etcd_server_proposals_failed_total` | Counter | etcd | 失败提案数 | 稳定 | >0持续 | Raft问题 |
| `etcd_server_proposals_pending` | Gauge | etcd | 待处理提案数 | 稳定 | >5 | 性能问题 |
| `etcd_debugging_mvcc_keys_total` | Gauge | etcd | 键总数 | 稳定 | 快速增长 | 对象泄漏 |

## kube-scheduler 关键指标

| 指标名称 | 类型 | 来源 | 说明 | 版本添加 | 告警阈值建议 | 运维场景 |
|---------|------|------|------|---------|-------------|---------|
| `scheduler_pending_pods` | Gauge | scheduler | 待调度Pod数(按queue) | 稳定 | >100持续 | 调度瓶颈 |
| `scheduler_pod_scheduling_duration_seconds` | Histogram | scheduler | 调度延迟 | 稳定 | P99>5s | 调度性能 |
| `scheduler_schedule_attempts_total` | Counter | scheduler | 调度尝试数(按result) | 稳定 | unschedulable增长 | 资源不足 |
| `scheduler_scheduling_algorithm_duration_seconds` | Histogram | scheduler | 算法执行时间 | v1.25框架 | P99>100ms | 算法性能 |
| `scheduler_preemption_attempts_total` | Counter | scheduler | 抢占尝试数 | 稳定 | 持续增长 | 资源竞争 |
| `scheduler_preemption_victims` | Gauge | scheduler | 抢占受害者数 | 稳定 | >0 | 资源压力 |
| `scheduler_framework_extension_point_duration_seconds` | Histogram | scheduler | 插件执行时间 | v1.25框架 | P99>50ms | 插件性能 |
| `scheduler_queue_incoming_pods_total` | Counter | scheduler | 入队Pod数 | 稳定 | - | 流量监控 |

## kube-controller-manager 关键指标

| 指标名称 | 类型 | 来源 | 说明 | 版本添加 | 告警阈值建议 | 运维场景 |
|---------|------|------|------|---------|-------------|---------|
| `workqueue_depth` | Gauge | controller | 工作队列深度(按name) | 稳定 | >100 | 控制器积压 |
| `workqueue_adds_total` | Counter | controller | 队列添加数 | 稳定 | - | 负载监控 |
| `workqueue_queue_duration_seconds` | Histogram | controller | 队列等待时间 | 稳定 | P99>30s | 处理延迟 |
| `workqueue_work_duration_seconds` | Histogram | controller | 处理时间 | 稳定 | P99>10s | 处理性能 |
| `workqueue_retries_total` | Counter | controller | 重试次数 | 稳定 | 快速增长 | 错误率 |
| `node_collector_evictions_total` | Counter | controller | 节点驱逐数 | 稳定 | >0 | 节点故障 |
| `cronjob_controller_cronjob_job_creation_skew_duration_seconds` | Histogram | controller | CronJob偏差 | v1.21+ | P99>60s | 定时准确性 |

## kubelet 关键指标

| 指标名称 | 类型 | 来源 | 说明 | 版本添加 | 告警阈值建议 | 运维场景 |
|---------|------|------|------|---------|-------------|---------|
| `kubelet_running_pods` | Gauge | kubelet | 运行中Pod数 | 稳定 | 接近max-pods | 节点容量 |
| `kubelet_running_containers` | Gauge | kubelet | 运行中容器数 | 稳定 | - | 容器密度 |
| `kubelet_pod_start_duration_seconds` | Histogram | kubelet | Pod启动延迟 | 稳定 | P99>60s | 启动性能 |
| `kubelet_pod_worker_duration_seconds` | Histogram | kubelet | Pod工作时间 | 稳定 | P99>10s | 工作延迟 |
| `kubelet_pleg_relist_duration_seconds` | Histogram | kubelet | PLEG刷新延迟 | 稳定 | P99>3s | PLEG健康 |
| `kubelet_pleg_relist_interval_seconds` | Histogram | kubelet | PLEG刷新间隔 | 稳定 | >3s | PLEG频率 |
| `kubelet_node_status_update_duration_seconds` | Histogram | kubelet | 状态更新延迟 | 稳定 | P99>10s | 状态同步 |
| `kubelet_evictions` | Counter | kubelet | 驱逐次数(按signal) | 稳定 | >0 | 资源压力 |
| `kubelet_volume_stats_used_bytes` | Gauge | kubelet | 卷使用量 | 稳定 | >85% | 存储告警 |
| `kubelet_volume_stats_capacity_bytes` | Gauge | kubelet | 卷容量 | 稳定 | - | 容量规划 |
| `kubelet_cgroup_manager_duration_seconds` | Histogram | kubelet | cgroup管理延迟 | v1.24 cgroup v2 | P99>100ms | cgroup性能 |
| `kubelet_container_log_filesystem_used_bytes` | Gauge | kubelet | 容器日志使用量 | 稳定 | 快速增长 | 日志管理 |

## kube-proxy 关键指标

| 指标名称 | 类型 | 来源 | 说明 | 版本添加 | 告警阈值建议 | 运维场景 |
|---------|------|------|------|---------|-------------|---------|
| `kubeproxy_sync_proxy_rules_duration_seconds` | Histogram | kube-proxy | 规则同步延迟 | 稳定 | P99>5s | 同步性能 |
| `kubeproxy_sync_proxy_rules_last_timestamp_seconds` | Gauge | kube-proxy | 最后同步时间戳 | 稳定 | >60s前 | 同步健康 |
| `kubeproxy_network_programming_duration_seconds` | Histogram | kube-proxy | 网络编程延迟 | 稳定 | P99>10s | 规则更新 |
| `kubeproxy_sync_proxy_rules_iptables_total` | Counter | kube-proxy | iptables规则数 | 稳定 | >10000 | 规则膨胀 |
| `kubeproxy_sync_proxy_rules_endpoint_changes_total` | Counter | kube-proxy | 端点变更数 | 稳定 | - | 变更监控 |
| `kubeproxy_sync_proxy_rules_service_changes_total` | Counter | kube-proxy | Service变更数 | 稳定 | - | 变更监控 |

## 节点资源指标 (Node Exporter / cAdvisor)

| 指标名称 | 类型 | 来源 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|------|-------------|---------|
| `node_cpu_seconds_total` | Counter | node-exporter | CPU使用时间 | 使用率>80% | CPU监控 |
| `node_memory_MemTotal_bytes` | Gauge | node-exporter | 总内存 | - | 容量规划 |
| `node_memory_MemAvailable_bytes` | Gauge | node-exporter | 可用内存 | <10% | 内存告警 |
| `node_filesystem_avail_bytes` | Gauge | node-exporter | 文件系统可用 | <15% | 磁盘告警 |
| `node_filesystem_size_bytes` | Gauge | node-exporter | 文件系统大小 | - | 容量规划 |
| `node_disk_io_time_seconds_total` | Counter | node-exporter | 磁盘IO时间 | 饱和>80% | IO性能 |
| `node_network_receive_bytes_total` | Counter | node-exporter | 网络接收字节 | - | 带宽监控 |
| `node_network_transmit_bytes_total` | Counter | node-exporter | 网络发送字节 | - | 带宽监控 |
| `container_cpu_usage_seconds_total` | Counter | cAdvisor | 容器CPU使用 | - | 容器监控 |
| `container_memory_working_set_bytes` | Gauge | cAdvisor | 容器内存使用 | >limits | OOM风险 |
| `container_network_receive_bytes_total` | Counter | cAdvisor | 容器网络接收 | - | 容器网络 |
| `container_fs_usage_bytes` | Gauge | cAdvisor | 容器文件系统 | - | 存储监控 |

## kube-state-metrics 关键指标

| 指标名称 | 类型 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|-------------|---------|
| `kube_pod_status_phase` | Gauge | Pod阶段状态 | Pending/Failed持续 | Pod健康 |
| `kube_pod_container_status_restarts_total` | Counter | 容器重启次数 | >5/h | 稳定性问题 |
| `kube_pod_container_status_waiting_reason` | Gauge | 容器等待原因 | CrashLoopBackOff | 启动问题 |
| `kube_pod_container_resource_requests` | Gauge | 资源请求 | - | 资源规划 |
| `kube_pod_container_resource_limits` | Gauge | 资源限制 | - | 资源规划 |
| `kube_deployment_status_replicas_available` | Gauge | 可用副本数 | <期望副本 | 部署健康 |
| `kube_deployment_status_replicas_unavailable` | Gauge | 不可用副本数 | >0 | 部署问题 |
| `kube_node_status_condition` | Gauge | 节点状态条件 | Ready!=True | 节点健康 |
| `kube_node_status_allocatable` | Gauge | 节点可分配资源 | - | 容量规划 |
| `kube_namespace_status_phase` | Gauge | 命名空间状态 | Terminating卡住 | 删除问题 |
| `kube_job_status_failed` | Gauge | 失败Job数 | >0 | Job监控 |
| `kube_cronjob_next_schedule_time` | Gauge | 下次调度时间 | - | 定时任务 |
| `kube_persistentvolumeclaim_status_phase` | Gauge | PVC状态 | Pending持续 | 存储问题 |
| `kube_horizontalpodautoscaler_status_current_replicas` | Gauge | HPA当前副本 | 达到max | 扩缩容 |
| `kube_resourcequota_usage` | Gauge | 配额使用量 | >80% | 配额告警 |

## CoreDNS 关键指标

| 指标名称 | 类型 | 说明 | 告警阈值建议 | 运维场景 |
|---------|------|------|-------------|---------|
| `coredns_dns_requests_total` | Counter | DNS请求总数 | - | 流量监控 |
| `coredns_dns_responses_total` | Counter | DNS响应总数(按rcode) | SERVFAIL>1% | DNS健康 |
| `coredns_dns_request_duration_seconds` | Histogram | DNS请求延迟 | P99>100ms | DNS性能 |
| `coredns_cache_hits_total` | Counter | 缓存命中数 | - | 缓存效率 |
| `coredns_cache_misses_total` | Counter | 缓存未命中数 | - | 缓存效率 |
| `coredns_forward_requests_total` | Counter | 转发请求数 | - | 上游负载 |
| `coredns_forward_responses_total` | Counter | 转发响应数(按rcode) | 错误增长 | 上游问题 |
| `coredns_panics_total` | Counter | Panic次数 | >0 | 稳定性 |

## Prometheus 告警规则示例

```yaml
groups:
- name: kubernetes
  rules:
  # API Server
  - alert: KubeAPIServerDown
    expr: absent(up{job="kubernetes-apiservers"} == 1)
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Kubernetes API Server is down"
  
  # API Server 错误率
  - alert: KubeAPIServerErrors
    expr: sum(rate(apiserver_request_total{code=~"5.."}[5m])) / sum(rate(apiserver_request_total[5m])) > 0.01
    for: 5m
    labels:
      severity: warning
  
  # etcd Leader丢失
  - alert: EtcdNoLeader
    expr: etcd_server_has_leader == 0
    for: 1m
    labels:
      severity: critical
  
  # etcd 磁盘延迟
  - alert: EtcdHighFsyncDuration
    expr: histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m])) > 0.01
    for: 5m
    labels:
      severity: warning
  
  # 调度器积压
  - alert: KubeSchedulerPendingPods
    expr: scheduler_pending_pods > 100
    for: 10m
    labels:
      severity: warning
  
  # kubelet PLEG问题
  - alert: KubeletPLEGDurationHigh
    expr: histogram_quantile(0.99, rate(kubelet_pleg_relist_duration_seconds_bucket[5m])) > 3
    for: 5m
    labels:
      severity: warning
  
  # Pod重启频繁
  - alert: PodRestartingTooMuch
    expr: increase(kube_pod_container_status_restarts_total[1h]) > 5
    for: 5m
    labels:
      severity: warning
  
  # 节点NotReady
  - alert: KubeNodeNotReady
    expr: kube_node_status_condition{condition="Ready",status="true"} == 0
    for: 5m
    labels:
      severity: critical
  
  # 节点内存压力
  - alert: NodeMemoryPressure
    expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.9
    for: 5m
    labels:
      severity: warning
  
  # PVC Pending
  - alert: PersistentVolumeClaimPending
    expr: kube_persistentvolumeclaim_status_phase{phase="Pending"} == 1
    for: 15m
    labels:
      severity: warning
```

## ACK 监控集成

| 组件 | ACK集成方式 | 数据源 | 告警配置 |
|-----|------------|-------|---------|
| **ARMS Prometheus** | 自动安装 | 组件指标 | ARMS告警规则 |
| **云监控** | 自动集成 | 节点/Pod指标 | 云监控告警 |
| **SLS** | 可选安装 | 日志/审计 | SLS告警 |
| **AHAS** | 可选安装 | 限流/熔断 | 自定义规则 |

---

**指标获取命令**:
```bash
# 获取组件指标
kubectl get --raw /metrics
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods

# 查看kubelet指标
curl -k https://<node-ip>:10250/metrics

# etcd指标
etcdctl endpoint status --cluster
```

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)