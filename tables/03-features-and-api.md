# 表格3：功能和API表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/reference/kubernetes-api](https://kubernetes.io/docs/reference/kubernetes-api/)

## API版本演进概览

```
API版本生命周期:
┌─────────────────────────────────────────────────────────────────────────────┐
│  Alpha (v1alpha1)  →  Beta (v1beta1)  →  Stable (v1)  →  Deprecated  →  Removed  │
│       │                    │                  │               │           │      │
│   实验性功能          功能完善中           生产就绪        弃用警告      已移除    │
│   默认禁用            默认启用             API稳定         迁移周期      不可用    │
│   可能移除            接口可能变           向后兼容         3个版本       -        │
└─────────────────────────────────────────────────────────────────────────────┘

版本号规则:
- Alpha: 功能实验性，随时可能改变或移除，需手动启用Feature Gate
- Beta: 功能基本稳定，默认启用，接口可能有小调整
- Stable: 功能稳定，向后兼容，长期支持
- 弃用后3个minor版本移除 (如v1.21弃用，v1.25移除)
```

## 核心工作负载API

| 功能名称 | API组/版本 | Kind | 稳定性 | 引入版本 | 稳定版本 | 弃用版本 | 移除版本 | 生产使用提示 |
|---------|-----------|------|-------|---------|---------|---------|---------|-------------|
| **Pod** | core/v1 | Pod | Stable | v1.0 | v1.0 | - | - | 不直接创建，使用控制器管理；设置resources requests/limits |
| **ReplicaSet** | apps/v1 | ReplicaSet | Stable | v1.2 | v1.9 | - | - | 不直接使用，由Deployment管理 |
| **Deployment** | apps/v1 | Deployment | Stable | v1.2 | v1.9 | - | - | 无状态应用首选；配置滚动更新策略和PDB |
| **StatefulSet** | apps/v1 | StatefulSet | Stable | v1.5 | v1.9 | - | - | 有状态应用；需配合Headless Service；注意PVC模板 |
| **DaemonSet** | apps/v1 | DaemonSet | Stable | v1.2 | v1.9 | - | - | 节点级守护进程；使用nodeSelector/tolerations精确控制 |
| **Job** | batch/v1 | Job | Stable | v1.2 | v1.9 | - | - | 批处理任务；配置backoffLimit、activeDeadlineSeconds、ttlSecondsAfterFinished |
| **CronJob** | batch/v1 | CronJob | Stable | v1.4 | v1.21 | - | - | 定时任务；v1.25+支持时区设置；配置concurrencyPolicy |
| **ReplicationController** | core/v1 | ReplicationController | Stable | v1.0 | v1.0 | v1.9 | - | **已弃用**，使用Deployment替代 |

### 工作负载API最佳实践

```yaml
# 生产级Deployment配置示例
apiVersion: apps/v1
kind: Deployment
metadata:
  name: production-app
  labels:
    app: production-app
    version: v1.2.0
    team: platform
spec:
  replicas: 3
  revisionHistoryLimit: 5              # 保留5个历史版本用于回滚
  progressDeadlineSeconds: 600         # 部署超时10分钟
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%              # 最多25%不可用
      maxSurge: 25%                    # 最多超出25%
  selector:
    matchLabels:
      app: production-app
  template:
    metadata:
      labels:
        app: production-app
        version: v1.2.0
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      serviceAccountName: production-app-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      terminationGracePeriodSeconds: 60
      containers:
      - name: app
        image: registry.example.com/app:v1.2.0
        imagePullPolicy: IfNotPresent
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "2000m"
            memory: "2Gi"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
              - ALL
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        livenessProbe:
          httpGet:
            path: /healthz
            port: http
          initialDelaySeconds: 15
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        startupProbe:                   # v1.20+ 慢启动应用使用
          httpGet:
            path: /healthz
            port: http
          initialDelaySeconds: 0
          periodSeconds: 5
          failureThreshold: 30          # 允许最多150秒启动
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: config
          mountPath: /etc/config
          readOnly: true
      volumes:
      - name: tmp
        emptyDir: {}
      - name: config
        configMap:
          name: production-app-config
      affinity:
        podAntiAffinity:               # Pod反亲和，分散部署
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: production-app
              topologyKey: kubernetes.io/hostname
      topologySpreadConstraints:       # v1.19+ 拓扑分布约束
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: production-app
---
# 配套PodDisruptionBudget
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: production-app-pdb
spec:
  minAvailable: 2                      # 或 maxUnavailable: 1
  selector:
    matchLabels:
      app: production-app
```

## 服务发现与网络API

| 功能名称 | API组/版本 | Kind | 稳定性 | 引入版本 | 稳定版本 | 弃用版本 | 移除版本 | 生产使用提示 |
|---------|-----------|------|-------|---------|---------|---------|---------|-------------|
| **Service** | core/v1 | Service | Stable | v1.0 | v1.0 | - | - | ClusterIP默认；大集群考虑Headless |
| **Endpoints** | core/v1 | Endpoints | Stable | v1.0 | v1.0 | - | - | 自动管理；大规模使用EndpointSlice |
| **EndpointSlice** | discovery.k8s.io/v1 | EndpointSlice | Stable | v1.16 | v1.21 | - | - | 大规模Service必用；自动创建 |
| **Ingress** | networking.k8s.io/v1 | Ingress | Stable | v1.1 | v1.19 | - | - | HTTP(S)路由；需安装Ingress Controller |
| **IngressClass** | networking.k8s.io/v1 | IngressClass | Stable | v1.18 | v1.19 | - | - | 多Ingress控制器时必需 |
| **NetworkPolicy** | networking.k8s.io/v1 | NetworkPolicy | Stable | v1.3 | v1.7 | - | - | 网络隔离；需CNI支持(Calico/Cilium) |
| **Gateway** | gateway.networking.k8s.io/v1 | Gateway | Stable | v1.24 | v1.31 | - | - | Ingress替代方案；更强大的路由能力 |
| **HTTPRoute** | gateway.networking.k8s.io/v1 | HTTPRoute | Stable | v1.24 | v1.31 | - | - | Gateway API的HTTP路由规则 |
| **GRPCRoute** | gateway.networking.k8s.io/v1 | GRPCRoute | Stable | v1.28 | v1.31 | - | - | Gateway API的gRPC路由 |
| **TCPRoute** | gateway.networking.k8s.io/v1alpha2 | TCPRoute | Alpha | v1.24 | - | - | - | TCP层路由(实验性) |
| **TLSRoute** | gateway.networking.k8s.io/v1alpha2 | TLSRoute | Alpha | v1.24 | - | - | - | TLS路由(实验性) |

### Service类型对比

| Service类型 | 用途 | 访问范围 | 典型场景 | 注意事项 |
|------------|------|---------|---------|---------|
| **ClusterIP** | 集群内部服务发现 | 仅集群内 | 内部微服务通信 | 默认类型 |
| **NodePort** | 在节点上暴露端口 | 节点IP:端口 | 开发测试、临时暴露 | 端口范围30000-32767 |
| **LoadBalancer** | 云负载均衡器 | 外部访问 | 生产对外服务 | 依赖云厂商；有成本 |
| **ExternalName** | DNS别名 | 外部服务 | 访问外部数据库 | 不创建ClusterIP |
| **Headless** | 直接Pod IP | DNS SRV记录 | StatefulSet、服务网格 | clusterIP: None |

### Gateway API vs Ingress对比

| 特性 | Ingress | Gateway API |
|-----|---------|-------------|
| **API成熟度** | Stable (v1.19+) | Stable (v1.31+) |
| **角色分离** | 单一资源 | Gateway/Route分离 |
| **协议支持** | HTTP(S) | HTTP/HTTPS/TCP/UDP/gRPC |
| **跨命名空间** | 需Annotation | 原生支持 |
| **流量分割** | 需控制器支持 | 原生支持 |
| **Header操作** | 需Annotation | 原生支持 |
| **可扩展性** | 有限 | 强大(Policy附加) |
| **推荐** | 简单场景 | 复杂路由需求 |

```yaml
# Gateway API示例
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: production-gateway
  namespace: gateway-system
spec:
  gatewayClassName: nginx  # 或 istio, envoy 等
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: All
  - name: https
    protocol: HTTPS
    port: 443
    tls:
      mode: Terminate
      certificateRefs:
      - name: wildcard-cert
        kind: Secret
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            gateway-access: "true"
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
  namespace: production
spec:
  parentRefs:
  - name: production-gateway
    namespace: gateway-system
  hostnames:
  - "app.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api/v1
    backendRefs:
    - name: api-v1-service
      port: 8080
      weight: 90
    - name: api-v2-service
      port: 8080
      weight: 10              # 金丝雀发布：10%流量到v2
  - matches:
    - path:
        type: PathPrefix
        value: /
    filters:
    - type: RequestHeaderModifier
      requestHeaderModifier:
        add:
        - name: X-Request-ID
          value: "generated-id"
    backendRefs:
    - name: frontend-service
      port: 80
```

## 配置与存储API

| 功能名称 | API组/版本 | Kind | 稳定性 | 引入版本 | 稳定版本 | 弃用版本 | 移除版本 | 生产使用提示 |
|---------|-----------|------|-------|---------|---------|---------|---------|-------------|
| **ConfigMap** | core/v1 | ConfigMap | Stable | v1.2 | v1.2 | - | - | 非敏感配置；immutable字段防误改(v1.21+) |
| **Secret** | core/v1 | Secret | Stable | v1.0 | v1.0 | - | - | 敏感数据；启用etcd加密；考虑外部Secret管理 |
| **PersistentVolume** | core/v1 | PersistentVolume | Stable | v1.0 | v1.0 | - | - | 集群级存储资源；使用StorageClass动态供应 |
| **PersistentVolumeClaim** | core/v1 | PersistentVolumeClaim | Stable | v1.0 | v1.0 | - | - | Pod存储请求；注意accessModes兼容性 |
| **StorageClass** | storage.k8s.io/v1 | StorageClass | Stable | v1.4 | v1.6 | - | - | 动态供应必需；设置默认StorageClass |
| **CSIDriver** | storage.k8s.io/v1 | CSIDriver | Stable | v1.12 | v1.18 | - | - | CSI驱动注册；了解驱动能力 |
| **CSINode** | storage.k8s.io/v1 | CSINode | Stable | v1.12 | v1.17 | - | - | 节点CSI信息；自动管理 |
| **VolumeSnapshot** | snapshot.storage.k8s.io/v1 | VolumeSnapshot | Stable | v1.12 | v1.20 | - | - | 存储快照；需CSI驱动支持 |
| **VolumeSnapshotClass** | snapshot.storage.k8s.io/v1 | VolumeSnapshotClass | Stable | v1.12 | v1.20 | - | - | 快照类定义 |
| **VolumeSnapshotContent** | snapshot.storage.k8s.io/v1 | VolumeSnapshotContent | Stable | v1.12 | v1.20 | - | - | 快照实际内容 |

### 存储AccessModes对比

| AccessMode | 简写 | 说明 | 支持的存储类型 |
|-----------|------|------|--------------|
| **ReadWriteOnce** | RWO | 单节点读写 | 大多数块存储(EBS, 云盘等) |
| **ReadOnlyMany** | ROX | 多节点只读 | NFS, CephFS, 云文件存储 |
| **ReadWriteMany** | RWX | 多节点读写 | NFS, CephFS, GlusterFS |
| **ReadWriteOncePod** | RWOP | 单Pod读写(v1.27+) | 支持的CSI驱动 |

## 扩展与自定义API

| 功能名称 | API组/版本 | Kind | 稳定性 | 引入版本 | 稳定版本 | 弃用版本 | 移除版本 | 生产使用提示 |
|---------|-----------|------|-------|---------|---------|---------|---------|-------------|
| **CustomResourceDefinition** | apiextensions.k8s.io/v1 | CRD | Stable | v1.7 | v1.16 | - | - | 扩展K8S API；配置验证schema |
| **MutatingWebhookConfiguration** | admissionregistration.k8s.io/v1 | - | Stable | v1.9 | v1.16 | - | - | 动态修改资源；注意超时设置 |
| **ValidatingWebhookConfiguration** | admissionregistration.k8s.io/v1 | - | Stable | v1.9 | v1.16 | - | - | 验证准入控制；failurePolicy设置 |
| **ValidatingAdmissionPolicy** | admissionregistration.k8s.io/v1 | - | Stable | v1.26 | v1.30 | - | - | CEL表达式验证；替代Webhook |
| **APIService** | apiregistration.k8s.io/v1 | APIService | Stable | v1.7 | v1.10 | - | - | API聚合层；Metrics Server使用 |

### CRD生产配置示例

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: applications.app.example.com
  annotations:
    controller-gen.kubebuilder.io/version: v0.14.0
spec:
  group: app.example.com
  names:
    kind: Application
    listKind: ApplicationList
    plural: applications
    singular: application
    shortNames:
    - app
    - apps
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    subresources:
      status: {}
      scale:
        specReplicasPath: .spec.replicas
        statusReplicasPath: .status.replicas
    additionalPrinterColumns:
    - name: Replicas
      type: integer
      jsonPath: .spec.replicas
    - name: Available
      type: integer
      jsonPath: .status.availableReplicas
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
    schema:
      openAPIV3Schema:
        type: object
        required:
        - spec
        properties:
          spec:
            type: object
            required:
            - image
            - replicas
            properties:
              image:
                type: string
                pattern: '^[a-z0-9./-]+:[a-zA-Z0-9._-]+$'
              replicas:
                type: integer
                minimum: 0
                maximum: 100
                default: 1
              resources:
                type: object
                properties:
                  cpu:
                    type: string
                    pattern: '^[0-9]+m?$'
                  memory:
                    type: string
                    pattern: '^[0-9]+(Mi|Gi)$'
          status:
            type: object
            properties:
              replicas:
                type: integer
              availableReplicas:
                type: integer
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    lastTransitionTime:
                      type: string
                      format: date-time
                    reason:
                      type: string
                    message:
                      type: string
  conversion:
    strategy: None
```

### ValidatingAdmissionPolicy (CEL验证) 示例

```yaml
# v1.30+ GA - 替代ValidatingWebhook的轻量级方案
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: "require-labels"
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups:   ["apps"]
      apiVersions: ["v1"]
      operations:  ["CREATE", "UPDATE"]
      resources:   ["deployments"]
  validations:
  - expression: "has(object.metadata.labels.app)"
    message: "Deployment must have 'app' label"
  - expression: "has(object.metadata.labels.team)"
    message: "Deployment must have 'team' label"
  - expression: "object.spec.replicas >= 2"
    message: "Production deployments must have at least 2 replicas"
    reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: "require-labels-binding"
spec:
  policyName: "require-labels"
  validationActions: [Deny]
  matchResources:
    namespaceSelector:
      matchLabels:
        environment: production
```

## 安全与访问控制API

| 功能名称 | API组/版本 | Kind | 稳定性 | 引入版本 | 稳定版本 | 弃用版本 | 移除版本 | 生产使用提示 |
|---------|-----------|------|-------|---------|---------|---------|---------|-------------|
| **ServiceAccount** | core/v1 | ServiceAccount | Stable | v1.0 | v1.0 | - | - | Pod身份；使用专用SA避免default |
| **Role** | rbac.authorization.k8s.io/v1 | Role | Stable | v1.6 | v1.8 | - | - | 命名空间级权限 |
| **ClusterRole** | rbac.authorization.k8s.io/v1 | ClusterRole | Stable | v1.6 | v1.8 | - | - | 集群级权限；聚合规则 |
| **RoleBinding** | rbac.authorization.k8s.io/v1 | RoleBinding | Stable | v1.6 | v1.8 | - | - | 绑定Role到用户/组/SA |
| **ClusterRoleBinding** | rbac.authorization.k8s.io/v1 | ClusterRoleBinding | Stable | v1.6 | v1.8 | - | - | 集群级绑定；谨慎授予 |
| **PodSecurityPolicy** | policy/v1beta1 | PSP | **已移除** | v1.3 | - | v1.21 | **v1.25** | 已移除！迁移到Pod Security Admission |
| **PodDisruptionBudget** | policy/v1 | PDB | Stable | v1.4 | v1.21 | - | - | 保护工作负载；设置minAvailable |
| **LimitRange** | core/v1 | LimitRange | Stable | v1.0 | v1.0 | - | - | 命名空间资源限制 |
| **ResourceQuota** | core/v1 | ResourceQuota | Stable | v1.0 | v1.0 | - | - | 命名空间配额 |

## 自动扩缩容API

| 功能名称 | API组/版本 | Kind | 稳定性 | 引入版本 | 稳定版本 | 弃用版本 | 移除版本 | 生产使用提示 |
|---------|-----------|------|-------|---------|---------|---------|---------|-------------|
| **HorizontalPodAutoscaler** | autoscaling/v2 | HPA | Stable | v1.1 | v1.23 | - | - | 自动扩缩Pod数；v2支持自定义指标 |
| **VerticalPodAutoscaler** | autoscaling.k8s.io/v1 | VPA | Stable | 外部项目 | - | - | - | 自动调整资源；注意与HPA冲突 |
| **PodAutoscaler** | autoscaling.k8s.io/v1alpha1 | - | Alpha | v1.27 | - | - | - | 多维度扩缩(实验性) |

### HPA配置策略对比

| 扩缩策略 | 说明 | 适用场景 |
|---------|------|---------|
| **stabilizationWindow** | 防止频繁扩缩的稳定窗口 | 流量波动大的应用 |
| **selectPolicy: Max** | 选择最大扩缩幅度 | 快速响应流量激增 |
| **selectPolicy: Min** | 选择最小扩缩幅度 | 平滑扩缩 |
| **selectPolicy: Disabled** | 禁止该方向扩缩 | 只扩不缩场景 |

## API版本演进重要变更

| 版本 | API变更 | 影响资源 | 迁移操作 | 工具命令 |
|-----|--------|---------|---------|---------|
| **v1.16** | extensions/v1beta1弃用 | Deployment, DaemonSet, ReplicaSet | 更新apiVersion到apps/v1 | `kubectl convert` |
| **v1.16** | CRD v1稳定 | CustomResourceDefinition | 迁移schema到OpenAPI v3 | 手动更新 |
| **v1.19** | Ingress v1稳定 | Ingress | 更新apiVersion到networking.k8s.io/v1 | `kubectl convert` |
| **v1.21** | CronJob v1稳定 | CronJob | 更新apiVersion到batch/v1 | 自动 |
| **v1.22** | 移除多个beta API | Ingress, CRD等 | 必须使用v1 API | 检查并更新YAML |
| **v1.25** | 移除PodSecurityPolicy | 安全策略 | 迁移到Pod Security Admission | 重新设计安全策略 |
| **v1.26** | FlowSchema v1稳定 | API优先级 | 可选升级 | - |
| **v1.27** | HPA v2 GA | HorizontalPodAutoscaler | 迁移到autoscaling/v2 | 更新YAML |
| **v1.29** | 移除flowcontrol.apiserver.k8s.io/v1beta2 | FlowSchema | 升级到v1 | kubectl convert |
| **v1.31** | Gateway API v1 GA | Gateway, HTTPRoute | 生产可用 | 官方迁移指南 |
| **v1.32** | 多个Beta API升级 | 多个 | 检查变更日志 | - |

## 功能门控(Feature Gates)状态

| 功能名称 | 功能门控 | v1.25 | v1.28 | v1.30 | v1.32 | 说明 | 启用建议 |
|---------|---------|-------|-------|-------|-------|------|---------|
| **Pod Security Admission** | PodSecurity | GA | GA | GA | GA | PSP替代方案 | 必须启用 |
| **Ephemeral Containers** | EphemeralContainers | GA | GA | GA | GA | 调试容器 | 推荐启用 |
| **Server-side Apply** | ServerSideApply | GA | GA | GA | GA | 声明式管理 | 推荐使用 |
| **IPv6 DualStack** | IPv6DualStack | GA | GA | GA | GA | 双栈网络 | 按需 |
| **Graceful Node Shutdown** | GracefulNodeShutdown | Beta | GA | GA | GA | 优雅关机 | 推荐启用 |
| **In-Place Pod Resize** | InPlacePodVerticalScaling | - | Alpha | Beta | GA | 就地调整资源 | v1.32+可用 |
| **Sidecar Containers** | SidecarContainers | - | Beta | GA | GA | Sidecar生命周期 | v1.30+推荐 |
| **CEL Admission** | ValidatingAdmissionPolicy | - | Beta | GA | GA | CEL验证策略 | v1.30+推荐 |
| **User Namespaces** | UserNamespacesSupport | Alpha | Beta | Beta | GA | 用户命名空间 | 安全增强 |
| **Dynamic Resource Allocation** | DynamicResourceAllocation | Alpha | Beta | Beta | GA | GPU等设备分配 | v1.32+可用 |
| **Pod Scheduling Readiness** | PodSchedulingReadiness | Alpha | Beta | GA | GA | 调度就绪门控 | 批处理场景 |
| **Service Internal Traffic Policy** | ServiceInternalTrafficPolicy | Beta | GA | GA | GA | 本地流量优先 | 性能优化 |

## API废弃时间线

```
已移除API时间线:
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  v1.16   v1.22   v1.25   v1.27   v1.29   v1.32                            │
│    │       │       │       │       │       │                              │
│    └─ extensions/v1beta1 Deployment/DaemonSet/RS 移除                      │
│            │                                                               │
│            └─ networking.k8s.io/v1beta1 Ingress 移除                       │
│                    │                                                       │
│                    └─ policy/v1beta1 PSP 移除                              │
│                    └─ batch/v1beta1 CronJob 移除                           │
│                            │                                               │
│                            └─ storage.k8s.io/v1beta1 CSIStorageCapacity 移除│
│                                    │                                       │
│                                    └─ flowcontrol/v1beta2 移除             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

| 资源类型 | 旧API版本 | 新API版本 | 弃用版本 | 移除版本 | 迁移优先级 |
|---------|----------|----------|---------|---------|-----------|
| Deployment | extensions/v1beta1 | apps/v1 | v1.9 | v1.16 | **已移除** |
| DaemonSet | extensions/v1beta1 | apps/v1 | v1.9 | v1.16 | **已移除** |
| ReplicaSet | extensions/v1beta1 | apps/v1 | v1.9 | v1.16 | **已移除** |
| Ingress | extensions/v1beta1 | networking.k8s.io/v1 | v1.14 | v1.22 | **已移除** |
| Ingress | networking.k8s.io/v1beta1 | networking.k8s.io/v1 | v1.19 | v1.22 | **已移除** |
| CronJob | batch/v1beta1 | batch/v1 | v1.21 | v1.25 | **已移除** |
| PodSecurityPolicy | policy/v1beta1 | (无,使用PSA) | v1.21 | v1.25 | **已移除** |
| EndpointSlice | discovery.k8s.io/v1beta1 | discovery.k8s.io/v1 | v1.21 | v1.25 | **已移除** |
| FlowSchema | flowcontrol/v1beta1 | flowcontrol/v1 | v1.26 | v1.29 | **已移除** |
| CSIStorageCapacity | storage.k8s.io/v1beta1 | storage.k8s.io/v1 | v1.24 | v1.27 | **已移除** |
| HPA | autoscaling/v2beta2 | autoscaling/v2 | v1.23 | v1.26 | **已移除** |

## 生产环境API使用检查

### 检查已弃用API使用

```bash
# 检查集群中使用的已弃用API
kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis

# 详细查看已弃用API调用
kubectl get --raw /metrics 2>/dev/null | grep "apiserver_request_total" | grep -E "(v1beta|deprecated)"

# 使用kubectl检查资源API版本
kubectl api-resources -o wide

# 查看所有API组和版本
kubectl api-versions | sort

# 查找使用旧API的资源（检查YAML文件）
find . -name "*.yaml" -exec grep -l "apiVersion: extensions/v1beta1" {} \;
find . -name "*.yaml" -exec grep -l "apiVersion: networking.k8s.io/v1beta1" {} \;

# 使用pluto工具检测已弃用API
# 安装: brew install fairwindsops/tap/pluto
pluto detect-files -d ./manifests/
pluto detect-helm -o wide
pluto detect-api-resources -o wide
```

### API版本转换

```bash
# 安装kubectl-convert插件
kubectl krew install convert

# 转换旧API到新版本
kubectl convert -f old-deployment.yaml --output-version apps/v1 -o yaml > new-deployment.yaml

# 批量转换
for f in *.yaml; do
  kubectl convert -f "$f" --output-version apps/v1 -o yaml > "converted-$f"
done

# 检查Helm charts中的API版本
helm template my-release ./my-chart | pluto detect -
```

### ACK特定API检查

```bash
# 检查ACK集群支持的API版本
kubectl api-versions | grep -E "(ack|alibabacloud)"

# ACK特有资源
kubectl api-resources | grep -E "(alibabacloud|ack)"

# 检查ALB Ingress Controller
kubectl get ingressclass
kubectl get alb

# 检查Terway网络插件
kubectl get eniconfigs
kubectl get pods -n kube-system -l app=terway-eniip
```

## 升级前API兼容性检查清单

| 检查项 | 命令/工具 | 通过标准 |
|-------|---------|---------|
| 已弃用API检查 | `pluto detect-api-resources` | 无已移除API |
| Helm charts检查 | `pluto detect-helm` | charts更新到新API |
| YAML文件检查 | `pluto detect-files -d ./` | 所有YAML使用新API |
| 运行时API检查 | `kubectl get --raw /metrics` | deprecated_apis = 0 |
| CRD schema检查 | `kubectl get crd -o yaml` | 使用v1 API |
| Webhook配置检查 | `kubectl get mutatingwebhookconfigurations` | 配置正确 |
| RBAC权限检查 | `kubectl auth can-i --list` | 新API权限就绪 |

---

**兼容性提示**: 升级前务必使用pluto等工具检查API版本兼容性，使用`kubectl api-versions`确认目标版本支持的API。建议在staging环境完整测试后再升级生产集群。
