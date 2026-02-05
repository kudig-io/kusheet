# Domain-8: Kubernetes 可观测性

> **文档数量**: 17 篇 | **最后更新**: 2026-02 | **适用版本**: Kubernetes v1.25-v1.32

---

## 概述

Kubernetes 可观测性域全面涵盖监控指标、日志收集、链路追踪、告警管理等可观测性核心技术。从架构设计到工具实践，为企业构建完整的可观测性体系提供系统性指导。

**核心价值**：
- 📊 **监控体系**：Prometheus监控、指标收集、性能分析
- 📝 **日志架构**：日志收集、分析、存储一体化方案
- 🔗 **链路追踪**：分布式追踪、OpenTelemetry、Jaeger集成
- ⚠️ **告警管理**：SLO驱动告警、故障预警、智能告警

---

## 文档目录

### 监控与指标 (01-07)

| # | 文档 | 关键内容 | 监控维度 |
|:---:|:---|:---|:---|
| 01 | [可观测性架构](./01-observability-architecture-overview.md) | 可观测性架构体系、设计原则 | 整体架构 |
| 02 | [监控指标系统](./02-monitoring-metrics-system.md) | Prometheus监控体系、指标设计 | 指标监控 |
| 06 | [Prometheus详解](./06-monitoring-metrics-prometheus.md) | Prometheus部署、配置、最佳实践 | 监控工具 |
| 07 | [自定义指标适配](./07-custom-metrics-adapter.md) | Metrics API扩展、HPA集成 | 扩展监控 |
| 10 | [可观测工具栈](./10-observability-tools.md) | 可观测性工具栈选型对比 | 工具选型 |

### 日志与审计 (03-04, 08-09, 11)

| # | 文档 | 关键内容 | 日志处理 |
|:---:|:---|:---|:---|
| 03 | [日志架构设计](./03-logging-architecture.md) | 日志收集架构、EFK/Loki方案 | 架构设计 |
| 08 | [日志审计实践](./08-logging-auditing.md) | 日志收集架构、审计日志配置 | 实践指南 |
| 09 | [事件审计日志](./09-events-audit-logs.md) | K8s事件与审计、日志分析 | 事件处理 |
| 11 | [日志聚合工具](./11-log-aggregation-tools.md) | EFK/Loki方案对比、部署实践 | 工具实践 |

### 诊断与分析 (12-15)

| # | 文档 | 关键内容 | 诊断能力 |
|:---:|:---|:---|:---|
| 12 | [故障排查概览](./12-troubleshooting-overview.md) | 生产级故障排查全攻略、SOP流程 | 故障诊断 |
| 13 | [排查工具集](./13-troubleshooting-tools.md) | kubectl debug/netshoot、诊断工具 | 工具使用 |
| 14 | [性能分析工具](./14-performance-profiling-tools.md) | pprof/perf、性能瓶颈分析 | 性能分析 |
| 15 | [集群健康检查](./15-cluster-health-check.md) | 集群健康检查、状态评估 | 健康监控 |

### 质量保障 (05, 16-17)

| # | 文档 | 关键内容 | 质量管理 |
|:---:|:---|:---|:---|
| 05 | [告警管理系统](./05-alerting-management.md) | SLO驱动告警策略、告警管理 | 告警体系 |
| 04 | [分布式链路追踪](./04-distributed-tracing.md) | OpenTelemetry/Jaeger、链路追踪 | 链路追踪 |
| 16 | [混沌工程实践](./16-chaos-engineering.md) | Chaos Mesh/Litmus、故障注入 | 韧性测试 |
| 17 | [扩展性能测试](./17-scaling-performance.md) | 扩展性测试、性能基准 | 性能验证 |

---

## 可观测性金字塔

```
        ┌─────────────────────────────────┐
        │         告警(Alerting)           │  ← 最终目标
        ├─────────────────────────────────┤
        │         指标(Metrics)            │  ← 主要手段
        ├─────────────────────────────────┤
        │         日志(Logs)              │  ← 上下文信息
        ├─────────────────────────────────┤
        │         链路(Traces)             │  ← 因果关系
        └─────────────────────────────────┘
```

---

## 学习路径建议

### 📊 监控入门路径
**01 → 02 → 06 → 07**  
从可观测性架构开始，掌握 Prometheus 监控体系

### 📝 日志处理路径  
**03 → 08 → 11**  
构建完整的日志收集和分析体系

### 🔍 故障诊断路径
**12 → 13 → 14 → 15**  
掌握系统性的故障排查和性能分析方法

### 🛡️ 质量保障路径
**05 → 04 → 16 → 17**  
建立完整的质量保障和性能测试体系

---

## 相关领域

- **[Domain-3: 控制平面](../domain-3-control-plane)** - 控制平面监控
- **[Domain-12: 故障排查](../domain-12-troubleshooting)** - 故障诊断实践
- **[Domain-9: 平台运维](../domain-9-platform-ops)** - 运维可观测性

---

**维护者**: Kusheet Observability Team | **许可证**: MIT