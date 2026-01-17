# 表格52: 混沌工程实践

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [chaos-mesh.org](https://chaos-mesh.org/)

## 混沌工程原则

| 原则 | 说明 | 实践方式 |
|-----|------|---------|
| **建立稳态假设** | 定义系统正常行为指标 | SLI/SLO定义 |
| **真实世界事件** | 模拟真实故障场景 | 基于历史故障 |
| **生产环境实验** | 真实环境才能发现真实问题 | 灰度实验 |
| **自动化持续** | 持续运行实验 | CI/CD集成 |
| **最小爆炸半径** | 控制实验影响范围 | 渐进式扩大 |

## 混沌工程工具对比

| 工具 | 架构 | 支持场景 | K8s原生 | 学习曲线 | 社区活跃度 |
|-----|------|---------|--------|---------|-----------|
| **Chaos Mesh** | Operator | 全场景 | ✅ | 中 | ⭐⭐⭐⭐⭐ |
| **LitmusChaos** | Operator | 全场景 | ✅ | 中 | ⭐⭐⭐⭐⭐ |
| **Chaos Monkey** | 独立 | 实例终止 | ❌ | 低 | ⭐⭐⭐ |
| **Gremlin** | SaaS | 全场景 | ✅ | 低 | ⭐⭐⭐⭐ |
| **AWS FIS** | 托管 | AWS资源 | ❌ | 低 | ⭐⭐⭐⭐ |
| **Chaosblade** | Agent | 全场景 | ✅ | 中 | ⭐⭐⭐⭐ |

## Chaos Mesh故障类型

| 类型 | CRD | 说明 |
|-----|-----|------|
| Pod故障 | PodChaos | 杀Pod/容器失败 |
| 网络故障 | NetworkChaos | 延迟/丢包/分区 |
| 文件系统 | IOChaos | IO延迟/错误 |
| 内核故障 | KernelChaos | 内核错误注入 |
| 时间偏移 | TimeChaos | 时钟偏移 |
| 压力测试 | StressChaos | CPU/内存压力 |
| JVM故障 | JVMChaos | Java异常注入 |
| HTTP故障 | HTTPChaos | HTTP请求故障 |
| DNS故障 | DNSChaos | DNS解析故障 |
| AWS故障 | AWSChaos | AWS资源故障 |
| GCP故障 | GCPChaos | GCP资源故障 |
| Azure故障 | AzureChaos | Azure资源故障 |

## PodChaos配置

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-kill-example
spec:
  action: pod-kill  # pod-kill/pod-failure/container-kill
  mode: one        # one/all/fixed/fixed-percent/random-max-percent
  selector:
    namespaces:
    - production
    labelSelectors:
      app: myapp
  duration: "60s"
  scheduler:
    cron: "@every 2h"
```

## NetworkChaos配置

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-delay
spec:
  action: delay
  mode: all
  selector:
    namespaces:
    - production
    labelSelectors:
      app: frontend
  delay:
    latency: "100ms"
    correlation: "25"
    jitter: "10ms"
  direction: to
  target:
    selector:
      namespaces:
      - production
      labelSelectors:
        app: backend
    mode: all
  duration: "5m"
---
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-partition
spec:
  action: partition
  mode: all
  selector:
    namespaces:
    - production
    labelSelectors:
      app: database
  direction: both
  target:
    selector:
      namespaces:
      - production
      labelSelectors:
        app: app-server
    mode: all
  duration: "2m"
```

## StressChaos配置

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: memory-stress
spec:
  mode: one
  selector:
    namespaces:
    - production
    labelSelectors:
      app: myapp
  stressors:
    memory:
      workers: 4
      size: "256MB"
    cpu:
      workers: 2
      load: 50
  duration: "5m"
```

## IOChaos配置

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: IOChaos
metadata:
  name: io-delay
spec:
  action: latency
  mode: one
  selector:
    namespaces:
    - production
    labelSelectors:
      app: database
  volumePath: /var/lib/mysql
  path: /var/lib/mysql/**
  delay: "100ms"
  percent: 50
  duration: "5m"
```

## LitmusChaos ChaosEngine

```yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: nginx-chaos
  namespace: production
spec:
  appinfo:
    appns: production
    applabel: "app=nginx"
    appkind: deployment
  chaosServiceAccount: litmus-admin
  experiments:
  - name: pod-delete
    spec:
      components:
        env:
        - name: TOTAL_CHAOS_DURATION
          value: "60"
        - name: CHAOS_INTERVAL
          value: "10"
        - name: FORCE
          value: "false"
```

## Workflow编排

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: chaos-workflow
spec:
  entry: serial-chaos
  templates:
  - name: serial-chaos
    templateType: Serial
    children:
    - network-delay-step
    - pod-kill-step
  - name: network-delay-step
    templateType: NetworkChaos
    networkChaos:
      action: delay
      mode: all
      selector:
        labelSelectors:
          app: frontend
      delay:
        latency: "200ms"
      duration: "2m"
  - name: pod-kill-step
    templateType: PodChaos
    podChaos:
      action: pod-kill
      mode: one
      selector:
        labelSelectors:
          app: backend
```

## 混沌工程最佳实践

| 实践 | 说明 | 实施方法 |
|-----|------|---------|
| **渐进式实验** | 从小范围开始,逐步扩大 | 先单Pod,后多Pod,最后全集群 |
| **生产环境实验** | 真实环境才能发现真实问题 | 灰度实验+监控 |
| **定义稳态假设** | 明确正常行为指标 | SLI/SLO基线 |
| **自动化实验** | CI/CD集成混沌测试 | Pipeline集成 |
| **回滚机制** | 确保可快速停止实验 | 紧急停止按钮 |
| **监控告警** | 实验期间密切监控 | 实时Dashboard |
| **记录学习** | 记录发现并改进系统 | 事后复盘文档 |
| **团队协作** | 通知相关团队 | 实验日历通知 |

## 稳态指标参考

| 指标类别 | 指标示例 | 阈值建议 | 监控方式 |
|---------|---------|---------|---------|
| **可用性** | 成功请求率 | >99.9% | Prometheus |
| **延迟** | P99响应时间 | <500ms | APM |
| **吞吐量** | QPS | ±10%波动 | Prometheus |
| **错误率** | 5xx比例 | <0.1% | 日志分析 |
| **资源利用** | CPU/内存使用率 | <80% | Metrics Server |
| **队列深度** | 消息堆积 | <1000 | MQ监控 |
| **连接数** | DB连接池 | <80%容量 | 中间件监控 |

## 实验场景设计

```yaml
# 场景1: 验证Pod自愈能力
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: test-pod-recovery
spec:
  action: pod-kill
  mode: fixed-percent
  value: "30"  # 随机杀死30%的Pod
  selector:
    namespaces: [production]
    labelSelectors:
      app: api-server
  duration: "1m"
---
# 场景2: 验证服务降级
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: test-service-degradation
spec:
  action: delay
  mode: all
  selector:
    namespaces: [production]
    labelSelectors:
      app: recommendation-service
  delay:
    latency: "2s"  # 模拟下游服务慢
  duration: "5m"
---
# 场景3: 验证数据库故障转移
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: test-db-failover
spec:
  action: partition
  mode: all
  selector:
    namespaces: [database]
    labelSelectors:
      app: mysql
      role: primary
  direction: both
  target:
    selector:
      namespaces: [production]
    mode: all
  duration: "2m"
---
# 场景4: 验证资源耗尽处理
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: test-resource-exhaustion
spec:
  mode: one
  selector:
    namespaces: [production]
    labelSelectors:
      app: worker
  stressors:
    memory:
      workers: 4
      size: "80%"  # 消耗80%内存
  duration: "3m"
```

## 混沌实验报告模板

```yaml
# 实验报告结构
experiment:
  name: "API服务Pod故障恢复测试"
  date: "2026-01-17"
  owner: "SRE Team"
  
hypothesis:
  description: "当30%的API Pod被杀死时,系统应在60秒内恢复到正常状态"
  steady_state:
    - metric: "success_rate"
      expected: ">99%"
    - metric: "p99_latency"
      expected: "<200ms"

execution:
  blast_radius: "production/api-server (3/10 pods)"
  duration: "60s"
  monitoring: "Grafana Dashboard #123"
  
results:
  success_rate: "99.2%"
  p99_latency: "180ms"
  recovery_time: "45s"
  
findings:
  - "HPA响应及时,新Pod在30秒内启动"
  - "负载均衡正确移除了不健康的Pod"
  - "无数据丢失,所有请求都被正确重试"
  
recommendations:
  - "增加Pod反亲和性,避免Pod集中在同一节点"
  - "优化启动探针配置,减少Pod就绪时间"
```

## ACK混沌工程支持

| 功能 | 说明 | 配置方式 |
|-----|------|---------|
| **Chaos Mesh托管** | 应用目录一键部署 | Helm安装 |
| **ARMS集成** | 实验监控告警 | 自动关联 |
| **故障演练** | 阿里云故障演练服务 | 控制台操作 |
| **SLS集成** | 实验日志采集 | 日志服务 |
| **AHAS** | 应用高可用服务 | 限流降级 |

```bash
# ACK安装Chaos Mesh
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm install chaos-mesh chaos-mesh/chaos-mesh \
  -n chaos-testing --create-namespace \
  --set dashboard.securityMode=false

# 访问Dashboard
kubectl port-forward -n chaos-testing svc/chaos-dashboard 2333:2333

# 安装RBAC权限
kubectl apply -f https://mirrors.chaos-mesh.org/v2.6.0/crd.yaml
```

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| Chaos Mesh 2.5 | 多集群支持改进 |
| Chaos Mesh 2.6 | 物理机故障注入 |
| LitmusChaos 3.0 | GitOps模式支持 |

---

**混沌工程原则**: 从小范围开始 + 定义稳态假设 + 自动化持续 + 及时回滚 + 记录学习改进
