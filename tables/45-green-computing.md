# 表格45：可持续性与绿色运维表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/blog/2023/06/29/kepler](https://www.cncf.io/projects/kepler/)

## 绿色计算指标

| 指标 | 描述 | 单位 | 监控方式 |
|-----|------|------|---------|
| **能耗** | 总能源消耗 | kWh | Kepler/云监控 |
| **碳排放** | CO2排放量 | kg CO2e | 计算公式 |
| **PUE** | 数据中心效率 | 比率 | 数据中心指标 |
| **资源利用率** | CPU/内存使用率 | % | Prometheus |
| **空闲资源** | 未使用资源 | 核/GB | 资源审计 |

## Kepler(Kubernetes Energy Efficiency)

```yaml
# Kepler部署
# helm repo add kepler https://sustainable-computing-io.github.io/kepler-helm-chart
# helm install kepler kepler/kepler -n kepler --create-namespace

# Kepler指标
# kepler_container_joules_total - 容器能耗(焦耳)
# kepler_node_core_joules_total - 节点CPU能耗
# kepler_node_dram_joules_total - 节点内存能耗
# kepler_node_platform_joules_total - 节点总能耗
```

```yaml
# Kepler DaemonSet配置
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kepler
  namespace: kepler
spec:
  selector:
    matchLabels:
      app: kepler
  template:
    metadata:
      labels:
        app: kepler
    spec:
      containers:
      - name: kepler
        image: quay.io/sustainable_computing_io/kepler:latest
        securityContext:
          privileged: true
        ports:
        - containerPort: 9102
          name: metrics
        volumeMounts:
        - name: lib-modules
          mountPath: /lib/modules
        - name: tracing
          mountPath: /sys/kernel/debug
        - name: proc
          mountPath: /proc
      volumes:
      - name: lib-modules
        hostPath:
          path: /lib/modules
      - name: tracing
        hostPath:
          path: /sys/kernel/debug
      - name: proc
        hostPath:
          path: /proc
```

## 能耗优化策略

| 策略 | 描述 | 实施方式 | 节省潜力 |
|-----|------|---------|---------|
| **资源右置** | 减少过度配置 | VPA/资源审计 | 20-40% |
| **自动扩缩容** | 按需使用资源 | HPA/CA | 20-50% |
| **节点整合** | 合并低利用节点 | Descheduler | 10-30% |
| **Spot实例** | 使用闲置资源 | 节点池配置 | - |
| **调度优化** | 优化Pod分布 | 调度策略 | 5-15% |
| **关闭空闲节点** | 缩容到零 | CA配置 | 变化大 |

## Descheduler节点整合

```yaml
# Descheduler策略
apiVersion: descheduler/v1alpha1
kind: DeschedulerPolicy
profiles:
- name: default
  pluginConfig:
  - name: LowNodeUtilization
    args:
      thresholds:
        cpu: 20
        memory: 20
        pods: 20
      targetThresholds:
        cpu: 50
        memory: 50
        pods: 50
      numberOfNodes: 3  # 至少3个低利用节点才触发
  - name: RemovePodsHavingTooManyRestarts
    args:
      podRestartThreshold: 100
      includingInitContainers: true
  - name: RemoveDuplicates
  plugins:
    balance:
      enabled:
      - LowNodeUtilization
      - RemoveDuplicates
    deschedule:
      enabled:
      - RemovePodsHavingTooManyRestarts
```

## 碳排放计算

```yaml
# 碳排放公式
# Carbon = Energy (kWh) × Carbon Intensity (kg CO2e/kWh)

# 各地区碳排放系数(示例)
# 中国平均: 0.581 kg CO2e/kWh
# 美国平均: 0.417 kg CO2e/kWh
# 欧洲平均: 0.276 kg CO2e/kWh
# 可再生能源: ~0 kg CO2e/kWh

# Prometheus查询示例
# 每小时容器能耗(Wh)
sum(increase(kepler_container_joules_total[1h])) / 3600
# 估算碳排放(kg CO2e)
sum(increase(kepler_container_joules_total[24h])) / 3600000 * 0.581
```

## 绿色调度

```yaml
# 碳感知调度器配置(示例概念)
apiVersion: v1
kind: ConfigMap
metadata:
  name: carbon-aware-scheduler-config
data:
  config.yaml: |
    regions:
      - name: cn-hangzhou
        carbonIntensity: 0.6
      - name: cn-shanghai
        carbonIntensity: 0.58
      - name: eu-west-1
        carbonIntensity: 0.25
    scheduling:
      preferLowCarbon: true
      carbonThreshold: 0.4
```

## 资源利用率优化

```yaml
# 资源利用率告警规则
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: resource-efficiency
spec:
  groups:
  - name: efficiency
    rules:
    # 低利用率节点告警
    - alert: NodeLowUtilization
      expr: |
        (1 - avg by(node) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) < 0.2
        and
        (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) < 0.3
      for: 1h
      labels:
        severity: info
      annotations:
        summary: "节点 {{ $labels.node }} 资源利用率低"
    
    # 过度配置Pod告警
    - alert: PodOverProvisioned
      expr: |
        (sum by(namespace, pod) (container_cpu_usage_seconds_total) / 
         sum by(namespace, pod) (kube_pod_container_resource_requests{resource="cpu"})) < 0.2
      for: 24h
      labels:
        severity: info
      annotations:
        summary: "Pod {{ $labels.pod }} CPU使用率持续低于请求的20%"
```

## 绿色运维检查清单

| 检查项 | 目标 | 当前状态 | 优化建议 |
|-------|------|---------|---------|
| **平均CPU利用率** | >50% | 检查 | 启用HPA/VPA |
| **平均内存利用率** | >60% | 检查 | 资源审计 |
| **Spot实例比例** | >30% | 检查 | 增加Spot节点 |
| **空闲节点** | 0 | 检查 | 配置缩容到零 |
| **过度配置Pod** | <10% | 检查 | VPA调整 |
| **能耗监控** | 启用 | 检查 | 部署Kepler |

## 阿里云绿色计算

| 功能 | 说明 | 配置方式 |
|-----|------|---------|
| **碳账本** | 碳排放追踪 | 云账单 |
| **绿色实例** | 可再生能源数据中心 | 选择地域 |
| **Spot实例** | 闲置资源利用 | 节点池配置 |
| **弹性伸缩** | 按需使用 | ESS配置 |

## 绿色运维报告模板

```markdown
# 月度绿色运维报告

## 摘要
- 总能耗: XXX kWh
- 碳排放: XXX kg CO2e
- 平均资源利用率: XX%

## 优化成果
- 节点整合: 减少X个节点
- 能耗节省: XX%
- 成本节省: XX%

## 改进建议
1. 增加Spot实例比例
2. 优化低利用率工作负载
3. 考虑迁移到绿色数据中心
```

---

**绿色原则**: 监控能耗，优化利用率，持续改进
