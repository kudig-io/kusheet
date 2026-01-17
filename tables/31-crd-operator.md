# 表格31: CRD与Operator开发

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)

## CRD版本规范

| API版本 | 状态 | 功能 | K8s版本 |
|--------|-----|------|--------|
| apiextensions.k8s.io/v1beta1 | 已移除 | 基础CRD | v1.22前 |
| apiextensions.k8s.io/v1 | 稳定 | 完整功能 | v1.16+ |

## CRD结构定义

| 字段 | 类型 | 必需 | 说明 |
|-----|-----|-----|------|
| `spec.group` | string | ✅ | API组名 |
| `spec.names.kind` | string | ✅ | 资源类型 |
| `spec.names.plural` | string | ✅ | 复数名称 |
| `spec.names.singular` | string | ❌ | 单数名称 |
| `spec.names.shortNames` | []string | ❌ | 短名称 |
| `spec.scope` | Namespaced/Cluster | ✅ | 作用域 |
| `spec.versions` | []Version | ✅ | 版本列表 |
| `spec.conversion` | Conversion | ❌ | 版本转换 |

## CRD验证规则

| 验证类型 | 字段 | 示例 |
|---------|-----|------|
| 必需字段 | `required` | `required: [name, replicas]` |
| 类型验证 | `type` | `type: string` |
| 枚举值 | `enum` | `enum: [Running, Stopped]` |
| 数值范围 | `minimum/maximum` | `minimum: 1, maximum: 100` |
| 字符串长度 | `minLength/maxLength` | `minLength: 1` |
| 正则匹配 | `pattern` | `pattern: "^[a-z]+$"` |
| 数组长度 | `minItems/maxItems` | `minItems: 1` |
| 默认值 | `default` | `default: 3` |
| CEL验证 | `x-kubernetes-validations` | 自定义验证(v1.25+) |

## CRD示例

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
    plural: applications
    singular: application
    shortNames: [app]
    categories: [all]  # kubectl get all可以看到
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        required: [spec]
        properties:
          spec:
            type: object
            required: [image, replicas]
            properties:
              image:
                type: string
                pattern: "^[a-z0-9.-]+/[a-z0-9.-]+:[a-z0-9.-]+$"
              replicas:
                type: integer
                minimum: 1
                maximum: 100
                default: 1
              ports:
                type: array
                maxItems: 10
                items:
                  type: object
                  required: [port]
                  properties:
                    port:
                      type: integer
                      minimum: 1
                      maximum: 65535
                    protocol:
                      type: string
                      enum: [TCP, UDP]
                      default: TCP
              resources:
                type: object
                properties:
                  cpu:
                    type: string
                    pattern: "^[0-9]+m?$"
                  memory:
                    type: string
                    pattern: "^[0-9]+(Mi|Gi)$"
            # CEL验证规则(v1.25+)
            x-kubernetes-validations:
            - rule: "self.replicas <= 10 || has(self.highAvailability)"
              message: "replicas > 10 requires highAvailability config"
            - rule: "!has(self.resources) || (has(self.resources.cpu) && has(self.resources.memory))"
              message: "if resources specified, both cpu and memory required"
          status:
            type: object
            properties:
              phase:
                type: string
                enum: [Pending, Running, Failed, Succeeded]
              availableReplicas:
                type: integer
              conditions:
                type: array
                items:
                  type: object
                  required: [type, status]
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                      enum: ["True", "False", "Unknown"]
                    reason:
                      type: string
                    message:
                      type: string
                    lastTransitionTime:
                      type: string
                      format: date-time
    subresources:
      status: {}
      scale:
        specReplicasPath: .spec.replicas
        statusReplicasPath: .status.availableReplicas
    additionalPrinterColumns:
    - name: Replicas
      type: integer
      jsonPath: .spec.replicas
    - name: Available
      type: integer
      jsonPath: .status.availableReplicas
    - name: Phase
      type: string
      jsonPath: .status.phase
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
  # 版本转换
  conversion:
    strategy: Webhook
    webhook:
      clientConfig:
        service:
          namespace: system
          name: webhook-service
          path: /convert
      conversionReviewVersions: ["v1"]
```

## CRD版本转换

```yaml
# 多版本CRD示例
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.db.example.com
spec:
  group: db.example.com
  names:
    kind: Database
    plural: databases
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: false  # 不是存储版本
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              size:
                type: string  # v1使用string
  - name: v2
    served: true
    storage: true   # v2是存储版本
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              storageSize:
                type: integer  # v2改为integer(Gi)
              storageClass:
                type: string
  conversion:
    strategy: Webhook
    webhook:
      clientConfig:
        service:
          namespace: system
          name: conversion-webhook
          path: /convert
      conversionReviewVersions: ["v1"]
```

## Operator开发框架对比

| 框架 | 语言 | 学习曲线 | 功能 | 社区活跃度 | 适用场景 |
|-----|-----|---------|-----|-----------|---------|
| **Kubebuilder** | Go | 中 | 完整 | ⭐⭐⭐⭐⭐ | 生产级Operator |
| **Operator SDK** | Go/Ansible/Helm | 中 | 完整 | ⭐⭐⭐⭐⭐ | 多语言支持 |
| **controller-runtime** | Go | 高 | 底层 | ⭐⭐⭐⭐⭐ | 高度定制 |
| **KUDO** | YAML | 低 | 基础 | ⭐⭐⭐ | 简单有状态应用 |
| **Metacontroller** | JS/Python | 低 | 基础 | ⭐⭐⭐ | 快速原型 |
| **kopf** | Python | 低 | 中等 | ⭐⭐⭐⭐ | Python生态 |
| **Java Operator SDK** | Java | 中 | 完整 | ⭐⭐⭐⭐ | Java生态 |

## Kubebuilder开发流程

```bash
# 1. 初始化项目
kubebuilder init --domain example.com --repo github.com/example/app-operator

# 2. 创建API
kubebuilder create api --group app --version v1 --kind Application
# 选择创建Resource和Controller

# 3. 创建Webhook(可选)
kubebuilder create webhook --group app --version v1 --kind Application \
  --defaulting --programmatic-validation

# 4. 编辑类型定义
# api/v1/application_types.go

# 5. 生成代码和清单
make generate    # 生成DeepCopy等
make manifests   # 生成CRD/RBAC/Webhook

# 6. 安装CRD
make install

# 7. 本地运行测试
make run

# 8. 构建和部署
make docker-build docker-push IMG=<registry>/app-operator:v1
make deploy IMG=<registry>/app-operator:v1

# 9. 卸载
make undeploy
make uninstall
```

## Controller核心代码结构

```go
// internal/controller/application_controller.go
package controller

import (
    "context"
    "fmt"
    "time"

    appsv1 "k8s.io/api/apps/v1"
    corev1 "k8s.io/api/core/v1"
    "k8s.io/apimachinery/pkg/api/errors"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
    "sigs.k8s.io/controller-runtime/pkg/log"

    appv1 "github.com/example/app-operator/api/v1"
)

const applicationFinalizer = "app.example.com/finalizer"

type ApplicationReconciler struct {
    client.Client
    Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=app.example.com,resources=applications,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=app.example.com,resources=applications/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=app.example.com,resources=applications/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete

func (r *ApplicationReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    logger := log.FromContext(ctx)

    // 1. 获取CR
    app := &appv1.Application{}
    if err := r.Get(ctx, req.NamespacedName, app); err != nil {
        if errors.IsNotFound(err) {
            return ctrl.Result{}, nil
        }
        return ctrl.Result{}, err
    }

    // 2. 处理删除
    if !app.DeletionTimestamp.IsZero() {
        if controllerutil.ContainsFinalizer(app, applicationFinalizer) {
            // 执行清理逻辑
            if err := r.cleanup(ctx, app); err != nil {
                return ctrl.Result{}, err
            }
            // 移除finalizer
            controllerutil.RemoveFinalizer(app, applicationFinalizer)
            if err := r.Update(ctx, app); err != nil {
                return ctrl.Result{}, err
            }
        }
        return ctrl.Result{}, nil
    }

    // 3. 添加finalizer
    if !controllerutil.ContainsFinalizer(app, applicationFinalizer) {
        controllerutil.AddFinalizer(app, applicationFinalizer)
        if err := r.Update(ctx, app); err != nil {
            return ctrl.Result{}, err
        }
    }

    // 4. 同步Deployment
    deployment := r.constructDeployment(app)
    if err := controllerutil.SetControllerReference(app, deployment, r.Scheme); err != nil {
        return ctrl.Result{}, err
    }

    found := &appsv1.Deployment{}
    err := r.Get(ctx, client.ObjectKeyFromObject(deployment), found)
    if err != nil && errors.IsNotFound(err) {
        logger.Info("Creating Deployment", "name", deployment.Name)
        if err := r.Create(ctx, deployment); err != nil {
            return ctrl.Result{}, err
        }
    } else if err == nil {
        // 更新Deployment
        if err := r.Update(ctx, deployment); err != nil {
            return ctrl.Result{}, err
        }
    } else {
        return ctrl.Result{}, err
    }

    // 5. 更新状态
    app.Status.Phase = "Running"
    app.Status.AvailableReplicas = found.Status.AvailableReplicas
    if err := r.Status().Update(ctx, app); err != nil {
        return ctrl.Result{}, err
    }

    // 6. 返回结果
    return ctrl.Result{RequeueAfter: 30 * time.Second}, nil
}

func (r *ApplicationReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        For(&appv1.Application{}).
        Owns(&appsv1.Deployment{}).
        Complete(r)
}
```

## Reconcile模式

| 模式 | 说明 | 适用场景 |
|-----|------|---------|
| Level-triggered | 基于当前状态 | 大多数场景 |
| Edge-triggered | 基于事件触发 | 特殊场景 |
| 定时同步 | 周期性检查 | 外部资源同步 |

## Operator最佳实践

| 实践 | 说明 | 示例 |
|-----|------|------|
| **幂等性** | Reconcile必须幂等 | 使用CreateOrUpdate |
| **状态管理** | 使用Status子资源 | 分离spec和status更新 |
| **所有权** | 设置OwnerReferences | 级联删除子资源 |
| **事件记录** | 发送K8s Events | 记录关键操作 |
| **重试策略** | 指数退避重试 | RequeueAfter |
| **资源限制** | 设置并发和速率限制 | MaxConcurrentReconciles |
| **监控指标** | 暴露Prometheus指标 | controller-runtime metrics |
| **优雅终止** | 处理终止信号 | LeaderElection graceful |
| **Finalizers** | 清理外部资源 | 删除前执行清理 |
| **条件状态** | 使用Conditions | 标准化状态报告 |

## Controller配置

```go
// main.go
func main() {
    mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
        Scheme:                 scheme,
        MetricsBindAddress:     ":8080",
        HealthProbeBindAddress: ":8081",
        LeaderElection:         true,
        LeaderElectionID:       "app-operator.example.com",
        // 并发控制
        Controller: config.Controller{
            GroupKindConcurrency: map[string]int{
                "Application.app.example.com": 10,  // 最多10个并发
            },
        },
    })

    if err := (&controller.ApplicationReconciler{
        Client: mgr.GetClient(),
        Scheme: mgr.GetScheme(),
    }).SetupWithManager(mgr); err != nil {
        setupLog.Error(err, "unable to create controller")
        os.Exit(1)
    }
}
```

## Webhook开发

```go
// api/v1/application_webhook.go

// +kubebuilder:webhook:path=/mutate-app-example-com-v1-application,mutating=true,failurePolicy=fail,sideEffects=None,groups=app.example.com,resources=applications,verbs=create;update,versions=v1,name=mapplication.kb.io,admissionReviewVersions=v1

var _ webhook.Defaulter = &Application{}

func (r *Application) Default() {
    if r.Spec.Replicas == 0 {
        r.Spec.Replicas = 1
    }
}

// +kubebuilder:webhook:path=/validate-app-example-com-v1-application,mutating=false,failurePolicy=fail,sideEffects=None,groups=app.example.com,resources=applications,verbs=create;update,versions=v1,name=vapplication.kb.io,admissionReviewVersions=v1

var _ webhook.Validator = &Application{}

func (r *Application) ValidateCreate() (admission.Warnings, error) {
    if r.Spec.Replicas > 100 {
        return nil, fmt.Errorf("replicas cannot exceed 100")
    }
    return nil, nil
}

func (r *Application) ValidateUpdate(old runtime.Object) (admission.Warnings, error) {
    oldApp := old.(*Application)
    if r.Spec.Image != oldApp.Spec.Image {
        // 记录镜像变更
    }
    return r.ValidateCreate()
}

func (r *Application) ValidateDelete() (admission.Warnings, error) {
    return nil, nil
}
```

## Operator测试

```go
// internal/controller/application_controller_test.go
var _ = Describe("Application Controller", func() {
    Context("When reconciling a resource", func() {
        const resourceName = "test-application"

        ctx := context.Background()

        typeNamespacedName := types.NamespacedName{
            Name:      resourceName,
            Namespace: "default",
        }
        application := &appv1.Application{}

        BeforeEach(func() {
            By("creating the custom resource")
            err := k8sClient.Get(ctx, typeNamespacedName, application)
            if err != nil && errors.IsNotFound(err) {
                resource := &appv1.Application{
                    ObjectMeta: metav1.ObjectMeta{
                        Name:      resourceName,
                        Namespace: "default",
                    },
                    Spec: appv1.ApplicationSpec{
                        Image:    "nginx:1.25",
                        Replicas: 3,
                    },
                }
                Expect(k8sClient.Create(ctx, resource)).To(Succeed())
            }
        })

        It("should create Deployment", func() {
            By("Reconciling the created resource")
            controllerReconciler := &ApplicationReconciler{
                Client: k8sClient,
                Scheme: k8sClient.Scheme(),
            }

            _, err := controllerReconciler.Reconcile(ctx, reconcile.Request{
                NamespacedName: typeNamespacedName,
            })
            Expect(err).NotTo(HaveOccurred())

            deployment := &appsv1.Deployment{}
            Eventually(func() error {
                return k8sClient.Get(ctx, typeNamespacedName, deployment)
            }).Should(Succeed())
            Expect(*deployment.Spec.Replicas).To(Equal(int32(3)))
        })
    })
})
```

## 版本变更记录

| 版本 | 变更内容 | 影响 |
|------|---------|------|
| v1.25 | CRD验证规则CEL支持GA | 内置复杂验证 |
| v1.26 | SelectableFields Alpha | 自定义字段选择器 |
| v1.27 | CRD验证Ratcheting Beta | 渐进式验证 |
| v1.28 | ValidatingAdmissionPolicy CRD集成 | 简化webhook |
| v1.29 | CRD SelectableFields Beta | 字段选择更稳定 |
| v1.30 | CEL cost估算改进 | 性能优化 |
| v1.31 | CRD元数据验证增强 | 更严格的验证 |
| v1.32 | SelectableFields GA | 生产可用 |

---

**Operator开发原则**: 幂等Reconcile + OwnerReference级联删除 + Finalizer清理外部资源 + Status子资源更新状态 + 完善的测试覆盖
