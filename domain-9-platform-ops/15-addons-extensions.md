# 14 - 附加组件和扩展表

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

## 组件资源消耗评估

| 组件 | CPU请求 | 内存请求 | 存储需求 | 节点数 | 月成本估算(ACK) |
|-----|--------|---------|---------|-------|---------------|
| **CoreDNS** | 100m | 70Mi | - | 2副本 | 包含 |
| **Metrics Server** | 100m | 300Mi | - | 1副本 | 包含 |
| **Prometheus** | 1-4核 | 4-16Gi | 100-500Gi | 1 | 800-3000元 |
| **Grafana** | 100m | 128Mi | 10Gi | 1 | 50元 |
| **Loki** | 500m-2核 | 2-8Gi | 100-1000Gi | 1 | 500-2000元 |
| **Istio** | 1核 | 2Gi | - | 控制面1 | 400元 |
| **ArgoCD** | 500m | 512Mi | 10Gi | 1 | 80元 |
| **cert-manager** | 100m | 128Mi | - | 1 | 20元 |
| **KEDA** | 100m | 128Mi | - | 1 | 20元 |
| **Nginx Ingress** | 200m/节点 | 256Mi/节点 | - | DaemonSet | 包含节点成本 |

## 组件安装优先级矩阵

### P0 - 生产必需 (集群创建时安装)

| 组件 | 用途 | 不安装的影响 |
|-----|------|------------|
| **CoreDNS** | 服务发现 | 集群无法解析服务 |
| **CNI Plugin** | Pod网络 | Pod无法通信 |
| **kube-proxy** | Service代理 | Service不可用 |
| **CSI Driver** | 存储 | 无法使用持久化存储 |

### P1 - 运维必需 (集群创建后立即安装)

| 组件 | 用途 | 安装建议 |
|-----|------|---------|
| **Metrics Server** | 资源监控 | 启用HPA/VPA必需 |
| **Ingress Controller** | 流量入口 | 根据南北流量需求选择 |
| **Prometheus** | 指标监控 | 或使用ARMS替代 |
| **日志组件** | 日志收集 | Loki或SLS |

### P2 - 增强功能 (按需安装)

| 组件 | 用途 | 安装时机 |
|-----|------|---------|
| **cert-manager** | 证书管理 | 使用HTTPS时 |
| **ArgoCD/Flux** | GitOps | 采用GitOps模式时 |
| **Service Mesh** | 服务治理 | 微服务复杂度高时 |
| **Cluster Autoscaler** | 节点自动扩缩 | 需要弹性时 |
| **VPA** | Pod资源优化 | 优化资源使用时 |
| **KEDA** | 事件驱动扩缩 | 特殊扩缩容需求 |

### P3 - 高级功能 (特定场景)

| 组件 | 用途 | 安装时机 |
|-----|------|---------|
| **Vault** | 密钥管理 | 严格安全要求 |
| **Falco** | 运行时安全 | 合规要求 |
| **OPA Gatekeeper** | 策略执行 | 多租户/合规 |
| **Jaeger** | 分布式追踪 | 性能排查 |

## 组件部署最佳实践

### Prometheus Stack 生产配置

```yaml
# Prometheus Operator Helm安装
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=15d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=alicloud-disk-essd \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=200Gi \
  --set prometheus.prometheusSpec.resources.requests.cpu=2 \
  --set prometheus.prometheusSpec.resources.requests.memory=8Gi \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.storageClassName=alicloud-disk-essd \
  --set grafana.persistence.size=10Gi \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName=alicloud-disk-essd \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage=10Gi

# 配置数据保留策略
kubectl edit prometheuses.monitoring.coreos.com -n monitoring
# spec.retention: 15d
# spec.retentionSize: 180GB
```

### Nginx Ingress Controller 生产配置

```yaml
# Helm安装
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.replicaCount=3 \
  --set controller.resources.requests.cpu=500m \
  --set controller.resources.requests.memory=512Mi \
  --set controller.service.type=LoadBalancer \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/alibaba-cloud-loadbalancer-spec"="slb.s3.medium" \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=true \
  --set controller.autoscaling.enabled=true \
  --set controller.autoscaling.minReplicas=3 \
  --set controller.autoscaling.maxReplicas=10 \
  --set controller.autoscaling.targetCPUUtilizationPercentage=80

# ConfigMap优化
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
data:
  allow-snippet-annotations: "false"  # 安全: 禁用snippet
  enable-real-ip: "true"  # 获取真实IP
  proxy-body-size: "100m"  # 上传大小限制
  proxy-connect-timeout: "15"
  proxy-read-timeout: "600"
  proxy-send-timeout: "600"
  use-gzip: "true"
  gzip-level: "5"
  client-header-buffer-size: "64k"
  large-client-header-buffers: "4 64k"
  ssl-protocols: "TLSv1.2 TLSv1.3"
  ssl-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256"
```

### cert-manager 生产配置

```bash
# 安装cert-manager
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.0 \
  --set installCRDs=true \
  --set global.leaderElection.namespace=cert-manager
```

```yaml
# Let's Encrypt ClusterIssuer (生产环境)
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
    # 或使用DNS验证(支持通配符证书)
    - dns01:
        aliDNS:
          accessKeyId: LTAI5t...
          accessKeySecretRef:
            name: alidns-secret
            key: accessKeySecret
          regionId: cn-hangzhou

---
# 自动颁发证书的Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

### ArgoCD GitOps 生产配置

```bash
# 安装ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 使用Ingress暴露
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - argocd.example.com
    secretName: argocd-tls
  rules:
  - host: argocd.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
EOF

# 获取初始密码
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## 组件升级策略

| 组件类型 | 升级频率 | 升级方式 | 回滚方案 |
|---------|---------|---------|---------|
| **核心组件** | 随K8S升级 | 集群升级时自动 | 集群回滚 |
| **监控组件** | 季度 | Helm upgrade | Helm rollback |
| **Ingress** | 半年 | 灰度升级 | 回滚镜像版本 |
| **GitOps** | 半年 | 蓝绿部署 | 切换流量 |
| **Service Mesh** | 年度 | 金丝雀升级 | 卸载Sidecar |

### Helm组件升级命令

```bash
# 查看可升级版本
helm repo update
helm search repo <chart-name> --versions

# 升级前备份
helm get values <release-name> -n <namespace> > values-backup.yaml

# 执行升级
helm upgrade <release-name> <chart> -n <namespace> \
  -f values-backup.yaml \
  --version <new-version>

# 验证升级
helm list -n <namespace>
kubectl get pods -n <namespace> -w

# 回滚
helm rollback <release-name> <revision> -n <namespace>
```

## 组件监控与告警

### 关键指标

```yaml
# Prometheus告警规则
groups:
- name: addon_alerts
  rules:
  # CoreDNS监控
  - alert: CoreDNSDown
    expr: up{job="kube-dns"} == 0
    for: 3m
    labels:
      severity: critical
    annotations:
      summary: "CoreDNS is down"
      
  # Ingress Controller监控
  - alert: IngressControllerDown
    expr: up{job="ingress-nginx"} == 0
    for: 3m
    labels:
      severity: critical
      
  - alert: IngressHighErrorRate
    expr: rate(nginx_ingress_controller_requests{status=~"5.."}[5m]) > 0.05
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Ingress 5xx error rate > 5%"
      
  # Metrics Server监控
  - alert: MetricsServerDown
    expr: up{job="metrics-server"} == 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Metrics Server is down, HPA/VPA unavailable"
      
  # cert-manager监控
  - alert: CertificateExpiringSoon
    expr: certmanager_certificate_expiration_timestamp_seconds - time() < 7*24*3600
    for: 1h
    labels:
      severity: warning
    annotations:
      summary: "Certificate {{ $labels.name }} expires in < 7 days"
```

## 组件故障排查

### 通用排查步骤

```bash
# 1. 检查Pod状态
kubectl get pods -n <namespace> -o wide

# 2. 查看Pod事件
kubectl describe pod <pod-name> -n <namespace>

# 3. 查看日志
kubectl logs <pod-name> -n <namespace> --tail=100 -f

# 4. 检查资源配额
kubectl top pods -n <namespace>
kubectl describe resourcequota -n <namespace>

# 5. 检查网络连通性
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
wget -O- http://<service>.<namespace>.svc.cluster.local
```

### Ingress故障排查

```bash
# 检查Ingress配置
kubectl get ingress -A
kubectl describe ingress <ingress-name> -n <namespace>

# 检查Ingress Controller日志
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100 -f

# 检查后端Service和Endpoints
kubectl get svc <service-name> -n <namespace>
kubectl get endpoints <service-name> -n <namespace>

# 测试Ingress Controller配置
kubectl exec -n ingress-nginx <controller-pod> -- nginx -T
```

## ACK组件市场扩展

### ACK原生组件优势

| 组件 | ACK原生 | 开源版本 | 优势 |
|-----|---------|---------|------|
| **日志服务** | SLS集成 | ELK/Loki | 免运维，按量付费 |
| **监控服务** | ARMS | Prometheus | 托管，自动告警 |
| **Ingress** | ALB Ingress | Nginx Ingress | 原生集成，高性能 |
| **网络插件** | Terway | Calico/Flannel | 高性能，ENI直通 |
| **存储** | CSI自动安装 | 手动安装 | 自动配置 |

### ACK组件一键安装

```bash
# 通过ACK控制台"应用市场"安装组件
# 或使用aliyun CLI

# 安装ARMS Prometheus
aliyun cs InstallClusterAddons \
  --ClusterId <cluster-id> \
  --Addons '[{"name":"arms-prometheus"}]'

# 安装SLS日志组件
aliyun cs InstallClusterAddons \
  --ClusterId <cluster-id> \
  --Addons '[{"name":"logtail-ds","config":{"sls_project":"k8s-log-<cluster-id>"}}]'

# 安装Nginx Ingress
aliyun cs InstallClusterAddons \
  --ClusterId <cluster-id> \
  --Addons '[{"name":"nginx-ingress-controller"}]'
```

## 组件安全加固

### 镜像安全

```yaml
# 使用ImagePolicyWebhook限制镜像源
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: registry.cn-hangzhou.aliyuncs.com/namespace/image:tag  # 仅允许企业镜像仓库
```

### 网络隔离

```yaml
# NetworkPolicy隔离组件命名空间
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-external-egress
  namespace: monitoring
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}  # 仅允许集群内通信
  - to:  # 允许DNS
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

### RBAC权限控制

```yaml
# 组件专用ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/metrics", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
```

---

**组件选择原则**: 按需安装，避免过度，关注兼容性，监控先行，安全加固

---

**表格维护**: Kusheet Project | **作者**: Allen Galler (allengaller@gmail.com)