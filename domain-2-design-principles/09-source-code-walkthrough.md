# 19 - Kubernetes源码结构与阅读指南 (Source Code Walkthrough)

## 源码仓库结构

| 目录 | 说明 |
|-----|------|
| /cmd | 各组件入口main函数 |
| /pkg | 核心库代码 |
| /staging | 独立发布的client库 |
| /api | API定义(OpenAPI规范) |
| /build | 构建脚本和配置 |
| /hack | 开发辅助脚本 |
| /test | 测试代码 |
| /vendor | 依赖库 |

## /cmd目录详解

| 子目录 | 组件 | 说明 |
|-------|-----|------|
| /cmd/kube-apiserver | API Server | API服务入口 |
| /cmd/kube-controller-manager | Controller Manager | 控制器管理器 |
| /cmd/kube-scheduler | Scheduler | 调度器 |
| /cmd/kubelet | Kubelet | 节点代理 |
| /cmd/kube-proxy | Kube-proxy | 网络代理 |
| /cmd/kubectl | Kubectl | CLI工具 |
| /cmd/kubeadm | Kubeadm | 集群引导工具 |

## /pkg核心包

| 包 | 说明 |
|---|------|
| /pkg/api | 内部API类型 |
| /pkg/apis | API注册 |
| /pkg/controller | 控制器实现 |
| /pkg/scheduler | 调度器实现 |
| /pkg/kubelet | Kubelet实现 |
| /pkg/proxy | Kube-proxy实现 |
| /pkg/registry | API存储层 |
| /pkg/volume | 存储卷插件 |

## /staging独立库

| 库 | 导入路径 | 说明 |
|---|---------|------|
| client-go | k8s.io/client-go | K8s客户端库 |
| api | k8s.io/api | API类型定义 |
| apimachinery | k8s.io/apimachinery | API基础机制 |
| apiserver | k8s.io/apiserver | API Server库 |
| controller-runtime | sigs.k8s.io/controller-runtime | 控制器框架 |

## API Server核心流程

| 阶段 | 代码位置 | 说明 |
|-----|---------|------|
| 入口 | cmd/kube-apiserver/apiserver.go | main函数 |
| 初始化 | pkg/controlplane/instance.go | 创建APIServer实例 |
| 认证 | staging/src/k8s.io/apiserver/pkg/authentication | 认证处理 |
| 授权 | staging/src/k8s.io/apiserver/pkg/authorization | RBAC授权 |
| 准入 | staging/src/k8s.io/apiserver/pkg/admission | 准入控制 |
| 存储 | pkg/registry | etcd存储层 |

### API请求处理链

```
请求 → Authentication → Authorization → Admission(Mutating) 
    → Validation → Admission(Validating) → etcd持久化 → 响应
```

## Controller Manager核心

| 文件 | 说明 |
|-----|------|
| cmd/kube-controller-manager/app/controllermanager.go | 入口和启动 |
| pkg/controller/deployment/deployment_controller.go | Deployment控制器 |
| pkg/controller/replicaset/replica_set.go | ReplicaSet控制器 |
| pkg/controller/job/job_controller.go | Job控制器 |
| pkg/controller/garbagecollector/garbagecollector.go | GC控制器 |

### 控制器注册表

```go
// 位置: cmd/kube-controller-manager/app/controllermanager.go
func NewControllerInitializers() map[string]InitFunc {
    controllers := map[string]InitFunc{}
    controllers["deployment"] = startDeploymentController
    controllers["replicaset"] = startReplicaSetController
    controllers["statefulset"] = startStatefulSetController
    controllers["daemonset"] = startDaemonSetController
    controllers["job"] = startJobController
    // ... 更多控制器
    return controllers
}
```

## Scheduler核心

| 文件 | 说明 |
|-----|------|
| cmd/kube-scheduler/app/server.go | 入口 |
| pkg/scheduler/scheduler.go | 调度器主逻辑 |
| pkg/scheduler/framework/interface.go | 调度框架接口 |
| pkg/scheduler/framework/plugins | 调度插件实现 |

### 调度流程

| 阶段 | 说明 | 插件类型 |
|-----|------|---------|
| PreFilter | 预处理检查 | PreFilterPlugin |
| Filter | 节点过滤 | FilterPlugin |
| PostFilter | 过滤后处理 | PostFilterPlugin |
| PreScore | 预评分 | PreScorePlugin |
| Score | 节点评分 | ScorePlugin |
| Reserve | 资源预留 | ReservePlugin |
| Permit | 批准检查 | PermitPlugin |
| PreBind | 预绑定 | PreBindPlugin |
| Bind | 实际绑定 | BindPlugin |
| PostBind | 绑定后处理 | PostBindPlugin |

## Kubelet核心

| 文件 | 说明 |
|-----|------|
| cmd/kubelet/kubelet.go | 入口 |
| pkg/kubelet/kubelet.go | Kubelet主逻辑 |
| pkg/kubelet/pod/pod_manager.go | Pod管理 |
| pkg/kubelet/container/runtime.go | 容器运行时接口 |
| pkg/kubelet/cri/remote/remote_runtime.go | CRI客户端 |

### Kubelet主循环

```go
// pkg/kubelet/kubelet.go
func (kl *Kubelet) syncLoop(updates <-chan kubetypes.PodUpdate) {
    for {
        select {
        case u := <-updates:
            switch u.Op {
            case kubetypes.ADD:
                kl.HandlePodAdditions(u.Pods)
            case kubetypes.UPDATE:
                kl.HandlePodUpdates(u.Pods)
            case kubetypes.DELETE:
                kl.HandlePodRemoves(u.Pods)
            case kubetypes.RECONCILE:
                kl.HandlePodReconcile(u.Pods)
            }
        }
    }
}
```

## client-go核心组件

| 组件 | 路径 | 说明 |
|-----|-----|------|
| Clientset | kubernetes/clientset.go | 类型化客户端集 |
| DynamicClient | dynamic/interface.go | 动态客户端 |
| Informer | tools/cache/shared_informer.go | 缓存+事件 |
| Lister | tools/cache/listers.go | 缓存读取 |
| WorkQueue | util/workqueue | 工作队列 |

## 代码阅读技巧

| 技巧 | 说明 |
|-----|------|
| 从cmd入口开始 | 理解启动流程 |
| 关注接口定义 | interface定义核心抽象 |
| 使用IDE跳转 | GoLand/VSCode |
| 看注释和文档 | 代码注释详尽 |
| 运行单元测试 | 理解预期行为 |
| 使用日志调试 | 添加klog输出 |

## 核心接口

| 接口 | 位置 | 说明 |
|-----|-----|------|
| runtime.Object | apimachinery/pkg/runtime | 所有API对象基接口 |
| client.Client | controller-runtime/pkg/client | 统一客户端接口 |
| Reconciler | controller-runtime/pkg/reconcile | 调谐器接口 |
| Manager | controller-runtime/pkg/manager | 控制器管理器 |

## 开发调试

| 工具 | 用途 |
|-----|------|
| dlv | Go调试器 |
| kind | 本地K8s集群 |
| make | 构建系统 |
| hack/local-up-cluster.sh | 本地启动集群 |

### 本地构建

```bash
# 构建所有组件
make

# 构建特定组件
make WHAT=cmd/kubectl

# 运行测试
make test

# 本地启动集群
hack/local-up-cluster.sh
```

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)
