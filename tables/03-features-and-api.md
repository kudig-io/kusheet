# 表格3：功能和API表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/reference/kubernetes-api](https://kubernetes.io/docs/reference/kubernetes-api/)

## 核心工作负载API

| 功能名称 | API组/版本 | Kind | 稳定性 | 引入版本 | 稳定版本 | 弃用版本 | 移除版本 | 生产使用提示 |
|---------|-----------|------|-------|---------|---------|---------|---------|-------------|
| **Pod** | core/v1 | Pod | Stable | v1.0 | v1.0 | - | - | 不直接创建，使用控制器管理；设置资源requests/limits |
| **ReplicaSet** | apps/v1 | ReplicaSet | Stable | v1.2 | v1.9 | - | - | 不直接使用，由Deployment管理 |
| **Deployment** | apps/v1 | Deployment | Stable | v1.2 | v1.9 | - | - | 无状态应用首选；配置滚动更新策略 |
| **StatefulSet** | apps/v1 | StatefulSet | Stable | v1.5 | v1.9 | - | - | 有状态应用；需配合Headless Service |
| **DaemonSet** | apps/v1 | DaemonSet | Stable | v1.2 | v1.9 | - | - | 节点级守护进程；使用nodeSelector精确控制 |
| **Job** | batch/v1 | Job | Stable | v1.2 | v1.9 | - | - | 批处理任务；配置backoffLimit和activeDeadlineSeconds |
| **CronJob** | batch/v1 | CronJob | Stable | v1.4 | v1.21 | - | - | 定时任务；注意时区设置(v1.25+支持) |
| **ReplicationController** | core/v1 | ReplicationController | Stable | v1.0 | v1.0 | v1.9 | - | **已弃用**，使用Deployment替代 |

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

## 配置与存储API

| 功能名称 | API组/版本 | Kind | 稳定性 | 引入版本 | 稳定版本 | 弃用版本 | 移除版本 | 生产使用提示 |
|---------|-----------|------|-------|---------|---------|---------|---------|-------------|
| **ConfigMap** | core/v1 | ConfigMap | Stable | v1.2 | v1.2 | - | - | 非敏感配置；immutable字段防误改(v1.21+) |
| **Secret** | core/v1 | Secret | Stable | v1.0 | v1.0 | - | - | 敏感数据；启用etcd加密；考虑外部Secret管理 |
| **PersistentVolume** | core/v1 | PersistentVolume | Stable | v1.0 | v1.0 | - | - | 集群级存储资源；使用StorageClass动态供应 |
| **PersistentVolumeClaim** | core/v1 | PersistentVolumeClaim | Stable | v1.0 | v1.0 | - | - | Pod存储请求；注意accessModes兼容性 |
| **StorageClass** | storage.k8s.io/v1 | StorageClass | Stable | v1.4 | v1.6 | - | - | 动态供应必需；设置默认StorageClass |
| **CSIDriver** | storage.k8s.io/v1 | CSIDriver | Stable | v1.12 | v1.18 | - | - | CSI驱动注册；了解驱动能力 |
| **VolumeSnapshot** | snapshot.storage.k8s.io/v1 | VolumeSnapshot | Stable | v1.12 | v1.20 | - | - | 存储快照；需CSI驱动支持 |

## 扩展与自定义API

| 功能名称 | API组/版本 | Kind | 稳定性 | 引入版本 | 稳定版本 | 弃用版本 | 移除版本 | 生产使用提示 |
|---------|-----------|------|-------|---------|---------|---------|---------|-------------|
| **CustomResourceDefinition** | apiextensions.k8s.io/v1 | CRD | Stable | v1.7 | v1.16 | - | - | 扩展K8S API；配置验证schema |
| **MutatingWebhookConfiguration** | admissionregistration.k8s.io/v1 | - | Stable | v1.9 | v1.16 | - | - | 动态修改资源；注意超时设置 |
| **ValidatingWebhookConfiguration** | admissionregistration.k8s.io/v1 | - | Stable | v1.9 | v1.16 | - | - | 验证准入控制；failurePolicy设置 |
| **ValidatingAdmissionPolicy** | admissionregistration.k8s.io/v1 | - | Stable | v1.26 | v1.30 | - | - | CEL表达式验证；替代Webhook |
| **APIService** | apiregistration.k8s.io/v1 | APIService | Stable | v1.7 | v1.10 | - | - | API聚合层；Metrics Server使用 |

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

## 自动扩缩容API

| 功能名称 | API组/版本 | Kind | 稳定性 | 引入版本 | 稳定版本 | 弃用版本 | 移除版本 | 生产使用提示 |
|---------|-----------|------|-------|---------|---------|---------|---------|-------------|
| **HorizontalPodAutoscaler** | autoscaling/v2 | HPA | Stable | v1.1 | v1.23 | - | - | 自动扩缩Pod数；v2支持自定义指标 |
| **VerticalPodAutoscaler** | autoscaling.k8s.io/v1 | VPA | Stable | 外部项目 | - | - | - | 自动调整资源；注意与HPA冲突 |
| **PodAutoscaler** | autoscaling.k8s.io/v1alpha1 | - | Alpha | v1.27 | - | - | - | 多维度扩缩(实验性) |

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
| **v1.29** | 移除flowcontrol.apiserver.k8s.io/v1beta2 | FlowSchema | 升级到v1 | kubectl convert |
| **v1.32** | 多个Beta API升级 | 多个 | 检查变更日志 | - |

## 功能门控(Feature Gates)状态

| 功能名称 | 功能门控 | v1.25 | v1.26 | v1.27 | v1.28 | v1.29 | v1.30 | v1.31 | v1.32 | 说明 |
|---------|---------|-------|-------|-------|-------|-------|-------|-------|-------|------|
| **Pod Security Admission** | PodSecurity | GA | GA | GA | GA | GA | GA | GA | GA | PSP替代方案 |
| **Ephemeral Containers** | EphemeralContainers | GA | GA | GA | GA | GA | GA | GA | GA | 调试容器 |
| **Server-side Apply** | ServerSideApply | GA | GA | GA | GA | GA | GA | GA | GA | 声明式管理 |
| **IPv6 DualStack** | IPv6DualStack | GA | GA | GA | GA | GA | GA | GA | GA | 双栈网络 |
| **Graceful Node Shutdown** | GracefulNodeShutdown | Beta | GA | GA | GA | GA | GA | GA | GA | 优雅关机 |
| **In-Place Pod Resize** | InPlacePodVerticalScaling | - | Alpha | Alpha | Alpha | Beta | Beta | Beta | GA | 就地调整资源 |
| **Sidecar Containers** | SidecarContainers | - | - | Alpha | Beta | Beta | GA | GA | GA | Sidecar生命周期 |
| **CEL Admission** | ValidatingAdmissionPolicy | - | Alpha | Beta | Beta | GA | GA | GA | GA | CEL验证策略 |
| **User Namespaces** | UserNamespacesSupport | Alpha | Alpha | Beta | Beta | Beta | Beta | GA | GA | 用户命名空间 |
| **Dynamic Resource Allocation** | DynamicResourceAllocation | Alpha | Alpha | Alpha | Beta | Beta | Beta | Beta | GA | GPU等设备分配 |

## API废弃时间线

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

## 生产环境API使用检查

```bash
# 检查集群中使用的已弃用API
kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis

# 使用kubectl检查资源API版本
kubectl api-resources -o wide

# 查找使用旧API的资源
kubectl get deploy,ds,rs -A -o yaml | grep "apiVersion: extensions"

# 转换旧API到新版本(需要kubectl-convert插件)
kubectl convert -f old-deployment.yaml --output-version apps/v1
```

---

**兼容性提示**: 升级前务必检查API版本兼容性，使用`kubectl api-versions`确认目标版本支持的API。
