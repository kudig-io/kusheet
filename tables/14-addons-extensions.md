# 表格14：附加组件和扩展表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/cluster-administration/addons](https://kubernetes.io/docs/concepts/cluster-administration/addons/)

## 必备附加组件

| 组件 | 用途 | 部署方式 | 版本兼容 | 生产必需 | ACK集成 |
|-----|------|---------|---------|---------|---------|
| **CoreDNS** | 集群DNS服务 | Deployment | 与K8S同步 | 是 | 自动安装 |
| **Metrics Server** | 资源指标API | Deployment | v0.7+ for v1.28+ | 是(HPA/VPA需要) | 可选安装 |
| **CNI Plugin** | 容器网络 | DaemonSet | 取决于插件 | 是 | Terway/Flannel |
| **kube-proxy** | Service网络代理 | DaemonSet | 与K8S同步 | 是 | 自动安装 |
| **CSI Driver** | 存储接口 | DaemonSet+Deployment | 取决于驱动 | 是(使用存储) | 云盘/NAS CSI |

## 可观测性组件

| 组件 | 用途 | 部署方式 | 版本兼容 | 资源需求 | ACK替代 |
|-----|------|---------|---------|---------|---------|
| **Prometheus** | 指标收集和存储 | Operator/Helm | v2.45+ | 中-高 | ARMS Prometheus |
| **Grafana** | 指标可视化 | Helm | v10+ | 低-中 | Grafana服务 |
| **Alertmanager** | 告警管理 | Operator/Helm | 与Prometheus配套 | 低 | ARMS告警 |
| **Loki** | 日志聚合 | Helm | v2.9+ | 中-高 | SLS |
| **Jaeger** | 分布式追踪 | Operator/Helm | v1.50+ | 中 | 链路追踪服务 |
| **kube-state-metrics** | K8S对象状态指标 | Deployment | v2.10+ | 低 | ARMS集成 |
| **node-exporter** | 节点指标 | DaemonSet | v1.7+ | 很低 | 云监控 |

## Ingress控制器

| 组件 | 特点 | 部署方式 | 版本要求 | 生产推荐 | ACK集成 |
|-----|------|---------|---------|---------|---------|
| **Nginx Ingress** | 功能全面，社区活跃 | Helm/YAML | v1.9+ | 是 | 支持 |
| **Traefik** | 动态配置，中间件 | Helm | v2.10+ | 是 | - |
| **Kong Ingress** | API网关功能 | Helm | v3.4+ | API场景 | - |
| **ALB Ingress** | 阿里云原生 | 自动 | v1.25+ | ACK推荐 | 原生 |
| **Contour** | Envoy代理 | YAML/Helm | v1.28+ | 是 | - |

## Service Mesh

| 组件 | 特点 | 部署方式 | 版本要求 | 复杂度 | ACK集成 |
|-----|------|---------|---------|-------|---------|
| **Istio** | 功能最全面 | istioctl/Helm | v1.20+ | 高 | ASM托管 |
| **Linkerd** | 轻量级，低资源 | CLI/Helm | v2.14+ | 中 | - |
| **Cilium Service Mesh** | eBPF原生 | Helm | v1.15+ | 中 | - |
| **Consul Connect** | 多环境支持 | Helm | v1.17+ | 中-高 | - |

## 安全组件

| 组件 | 用途 | 部署方式 | 版本要求 | 功能 |
|-----|------|---------|---------|------|
| **cert-manager** | 证书自动管理 | Helm | v1.13+ | 自动申请/续期证书 |
| **External Secrets** | 外部密钥同步 | Helm | v0.9+ | 同步Vault/云KMS |
| **Vault** | 密钥管理 | Helm | v1.15+ | 动态密钥，加密即服务 |
| **Falco** | 运行时安全监控 | Helm | v0.37+ | 异常行为检测 |
| **OPA Gatekeeper** | 策略执行 | Helm | v3.14+ | 准入策略 |
| **Kyverno** | 策略引擎 | Helm | v1.11+ | 资源验证/变更 |
| **Trivy Operator** | 漏洞扫描 | Helm | v0.18+ | 镜像/配置扫描 |

## GitOps/CD组件

| 组件 | 用途 | 部署方式 | 版本要求 | 模式 | ACK集成 |
|-----|------|---------|---------|------|---------|
| **ArgoCD** | GitOps持续交付 | Helm | v2.9+ | Pull | - |
| **Flux** | GitOps工具包 | CLI | v2.2+ | Pull | - |
| **Tekton** | CI/CD流水线 | YAML | v0.53+ | Pipeline | - |
| **Jenkins X** | K8S原生CI/CD | CLI | v3+ | Pipeline | - |

## 自动扩缩容组件

| 组件 | 用途 | 部署方式 | 版本要求 | 功能 |
|-----|------|---------|---------|------|
| **Cluster Autoscaler** | 节点自动扩缩容 | Deployment | v1.28+ | 基于Pod需求扩缩节点 |
| **VPA** | 垂直Pod自动扩缩 | Deployment | v1.0+ | 自动调整资源请求 |
| **KEDA** | 事件驱动扩缩容 | Helm | v2.12+ | 基于事件/指标扩缩 |
| **Karpenter** | 快速节点扩缩容 | Helm | v0.33+ | 更快的节点供应 |

## 开发者工具

| 组件 | 用途 | 安装方式 | 功能 |
|-----|------|---------|------|
| **Helm** | 包管理器 | 二进制 | Chart安装/管理 |
| **Kustomize** | 配置定制 | kubectl内置 | 声明式配置管理 |
| **Skaffold** | 开发工作流 | 二进制 | 本地开发迭代 |
| **Telepresence** | 本地开发调试 | 二进制 | 本地连接远程集群 |
| **k9s** | 终端UI | 二进制 | 交互式集群管理 |
| **Lens** | 桌面IDE | 安装包 | 可视化管理 |
| **kubectx/kubens** | 上下文切换 | 二进制 | 快速切换集群/命名空间 |

## Operator框架

| 框架 | 语言 | 特点 | 版本要求 |
|-----|------|------|---------|
| **Operator SDK** | Go/Ansible/Helm | Red Hat官方 | v1.33+ |
| **Kubebuilder** | Go | K8S SIG官方 | v3.14+ |
| **KUDO** | YAML | 声明式Operator | v0.19+ |
| **Metacontroller** | 任意语言 | Lambda式控制器 | v2.6+ |

## 常用Operator

| Operator | 管理对象 | 部署方式 | 生产成熟度 |
|---------|---------|---------|-----------|
| **Prometheus Operator** | Prometheus/Alertmanager | Helm | 高 |
| **Cert-Manager** | 证书 | Helm | 高 |
| **Strimzi** | Kafka | Helm/YAML | 高 |
| **MySQL Operator** | MySQL | Helm | 中-高 |
| **PostgreSQL Operator** | PostgreSQL | Helm | 高 |
| **Redis Operator** | Redis | Helm | 中-高 |
| **Elasticsearch Operator** | ES集群 | Helm | 高 |
| **MongoDB Operator** | MongoDB | Helm | 中-高 |

## 组件版本兼容矩阵

| 组件 | v1.28 | v1.29 | v1.30 | v1.31 | v1.32 |
|-----|-------|-------|-------|-------|-------|
| **Metrics Server** | v0.6+ | v0.7+ | v0.7+ | v0.7+ | v0.7+ |
| **Nginx Ingress** | v1.9+ | v1.9+ | v1.10+ | v1.10+ | v1.11+ |
| **cert-manager** | v1.13+ | v1.13+ | v1.14+ | v1.14+ | v1.15+ |
| **ArgoCD** | v2.8+ | v2.9+ | v2.10+ | v2.11+ | v2.12+ |
| **Prometheus** | v2.47+ | v2.48+ | v2.50+ | v2.52+ | v2.54+ |
| **Istio** | v1.19+ | v1.20+ | v1.21+ | v1.22+ | v1.23+ |

## ACK组件市场

| 组件类别 | 可选组件 | 安装方式 |
|---------|---------|---------|
| **日志监控** | Logtail, ARMS, SLS | 控制台一键安装 |
| **网络** | Terway, Nginx Ingress, ALB | 创建时选择/后续安装 |
| **存储** | 云盘CSI, NAS CSI, OSS CSI | 自动安装 |
| **安全** | 云安全中心, KMS | 控制台配置 |
| **DevOps** | 云效, Jenkins | 控制台安装 |

---

**组件选择原则**: 按需安装，避免过度，关注兼容性
