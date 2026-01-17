# 表格4：代码结构表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [github.com/kubernetes/kubernetes](https://github.com/kubernetes/kubernetes)

## 顶级目录结构

| 路径/模块 | 用途 | 关键文件 | 版本演变 | 运维相关性 |
|----------|------|---------|---------|-----------|
| **cmd/** | 所有可执行二进制入口点 | main.go文件 | 持续稳定 | 了解组件启动参数和行为 |
| **pkg/** | 核心库代码，可被其他项目导入 | 各子包 | v1.22重构API机制 | 理解内部逻辑进行调试 |
| **staging/** | 独立发布的客户端库(staging仓库镜像) | k8s.io/*包 | 持续演进 | 开发K8S客户端时引用 |
| **vendor/** | 第三方依赖(Go modules) | go.mod/go.sum | 每版本更新 | 排查依赖冲突 |
| **api/** | OpenAPI规范和Swagger定义 | openapi-spec/ | 每版本更新 | 生成客户端代码 |
| **build/** | 构建脚本和配置 | Makefile, build-image/ | 持续更新 | 自定义构建K8S |
| **cluster/** | 集群部署脚本(已弃用) | - | 已弃用 | 历史参考 |
| **docs/** | 设计文档和提案 | *.md | 持续更新 | 了解设计决策 |
| **hack/** | 开发和测试辅助脚本 | verify-*.sh, update-*.sh | 持续更新 | 贡献代码时使用 |
| **test/** | 测试代码 | e2e/, integration/ | 持续更新 | 验证自定义更改 |
| **third_party/** | 第三方代码(非vendor) | protobuf/ | 较少变化 | 协议定义 |
| **plugin/** | 调度器等插件框架 | pkg/scheduler/framework/ | v1.25+调度框架 | 自定义调度器 |
| **logo/** | Kubernetes Logo资源 | - | 稳定 | 文档/演示使用 |

## cmd/ 目录详解

| 组件路径 | 用途 | 关键配置 | 版本变更 | 排查价值 |
|---------|------|---------|---------|---------|
| **cmd/kube-apiserver/** | API Server入口 | app/options/ | v1.29审计增强 | 理解API启动流程和参数 |
| **cmd/kube-controller-manager/** | 控制器管理器入口 | app/controllermanager.go | v1.27控制器分离 | 了解控制器启动和选举 |
| **cmd/kube-scheduler/** | 调度器入口 | app/server.go | v1.25调度框架 | 理解调度配置加载 |
| **cmd/kubelet/** | 节点代理入口 | app/server.go | v1.24 cgroup v2 | 排查节点问题 |
| **cmd/kube-proxy/** | 网络代理入口 | app/server.go | v1.26 nftables | 理解代理模式选择 |
| **cmd/kubectl/** | CLI工具入口 | pkg/cmd/ | 每版本新命令 | 扩展kubectl功能 |
| **cmd/kubeadm/** | 集群引导工具 | app/phases/ | 每版本更新 | 集群部署排查 |
| **cmd/cloud-controller-manager/** | 云控制器入口 | - | v1.25稳定 | 云集成调试 |
| **cmd/kube-aggregator/** | API聚合器 | - | 稳定 | 聚合API调试 |

## pkg/ 核心包详解

| 包路径 | 用途 | 关键类型/接口 | 版本变更 | 运维/开发价值 |
|-------|------|--------------|---------|--------------|
| **pkg/apis/** | 内部API类型定义 | 各资源types.go | 随API演进 | 理解资源字段含义 |
| **pkg/controller/** | 核心控制器实现 | deployment/, replicaset/ | 持续优化 | 理解控制器逻辑 |
| **pkg/kubelet/** | Kubelet核心逻辑 | pod/, container/, cri/ | v1.24 CRI变更 | 节点问题排查 |
| **pkg/scheduler/** | 调度器核心逻辑 | framework/, algorithm/ | v1.25框架重构 | 自定义调度 |
| **pkg/proxy/** | kube-proxy实现 | iptables/, ipvs/, nftables/ | v1.26 nftables | 网络问题排查 |
| **pkg/registry/** | API Server存储层 | core/, apps/ | 持续稳定 | 理解资源存储 |
| **pkg/volume/** | 卷插件实现 | csi/, plugins/ | CSI主流 | 存储问题排查 |
| **pkg/cloudprovider/** | 云厂商接口 | providers/ | v1.25外部化 | 云集成开发 |
| **pkg/auth/** | 认证授权逻辑 | authenticator/, authorizer/ | 持续增强 | 安全问题排查 |
| **pkg/util/** | 通用工具函数 | wait/, sets/, runtime/ | 稳定 | 开发复用 |
| **pkg/features/** | Feature Gate定义 | kube_features.go | 每版本新增 | 了解新功能状态 |

## staging/ 独立包

| 包路径 | 用途 | 独立仓库 | 版本策略 | 使用场景 |
|-------|------|---------|---------|---------|
| **staging/src/k8s.io/api/** | API类型定义(外部版本) | k8s.io/api | 与K8S同步 | Go客户端开发 |
| **staging/src/k8s.io/apimachinery/** | API机制库(序列化等) | k8s.io/apimachinery | 与K8S同步 | 自定义资源开发 |
| **staging/src/k8s.io/client-go/** | Go客户端库 | k8s.io/client-go | 与K8S同步 | Go操作K8S集群 |
| **staging/src/k8s.io/kubectl/** | kubectl库代码 | k8s.io/kubectl | 与K8S同步 | kubectl插件开发 |
| **staging/src/k8s.io/kubelet/** | Kubelet API定义 | k8s.io/kubelet | 与K8S同步 | CRI开发 |
| **staging/src/k8s.io/kube-scheduler/** | 调度器API | k8s.io/kube-scheduler | 与K8S同步 | 调度器插件开发 |
| **staging/src/k8s.io/controller-manager/** | 控制器框架 | k8s.io/controller-manager | 与K8S同步 | 自定义控制器 |
| **staging/src/k8s.io/apiserver/** | API Server库 | k8s.io/apiserver | 与K8S同步 | 自定义API Server |
| **staging/src/k8s.io/cri-api/** | CRI接口定义 | k8s.io/cri-api | 与K8S同步 | 容器运行时开发 |
| **staging/src/k8s.io/metrics/** | Metrics API | k8s.io/metrics | 与K8S同步 | 指标客户端开发 |
| **staging/src/k8s.io/component-base/** | 组件基础库 | k8s.io/component-base | 与K8S同步 | 组件开发 |

## 调度器代码结构

| 路径 | 用途 | 关键接口 | v1.25+变更 | 自定义扩展点 |
|-----|------|---------|-----------|-------------|
| **pkg/scheduler/framework/** | 调度框架核心 | Framework, Plugin | 框架稳定 | 实现Plugin接口 |
| **pkg/scheduler/framework/plugins/** | 内置插件 | NodeAffinity, TaintToleration | 持续增强 | 参考实现 |
| **pkg/scheduler/apis/config/** | 调度配置API | KubeSchedulerConfiguration | v1.25 v1稳定 | 配置自定义调度 |
| **pkg/scheduler/internal/queue/** | 调度队列 | PriorityQueue | 性能优化 | 理解调度顺序 |
| **pkg/scheduler/internal/cache/** | 调度缓存 | Cache, NodeInfo | 持续优化 | 理解调度决策数据 |

## Kubelet代码结构

| 路径 | 用途 | 关键类型 | 版本变更 | 排查价值 |
|-----|------|---------|---------|---------|
| **pkg/kubelet/kubelet.go** | Kubelet主循环 | Kubelet struct | 持续重构 | 理解节点代理核心 |
| **pkg/kubelet/pod/** | Pod管理 | Manager | 稳定 | Pod状态问题 |
| **pkg/kubelet/container/** | 容器生命周期 | Runtime, Manager | v1.24 CRI | 容器问题排查 |
| **pkg/kubelet/cri/** | CRI接口实现 | RuntimeService | v1.24重构 | CRI问题排查 |
| **pkg/kubelet/pleg/** | Pod生命周期事件生成器 | GenericPLEG | 性能优化 | PLEG超时问题 |
| **pkg/kubelet/eviction/** | 驱逐管理 | Manager | 持续增强 | 驱逐问题排查 |
| **pkg/kubelet/cm/** | cgroup管理 | ContainerManager | v1.24 cgroup v2 | 资源问题排查 |
| **pkg/kubelet/volumemanager/** | 卷管理 | VolumeManager | CSI主流 | 存储挂载问题 |

## API Server代码结构

| 路径 | 用途 | 关键类型 | 版本变更 | 运维价值 |
|-----|------|---------|---------|---------|
| **pkg/registry/** | 资源存储层 | RESTStorage | 持续稳定 | 理解资源CRUD |
| **pkg/kubeapiserver/** | API Server配置 | Config | 持续更新 | 理解配置选项 |
| **staging/src/k8s.io/apiserver/pkg/server/** | 通用Server框架 | GenericAPIServer | 持续重构 | 自定义API Server |
| **staging/src/k8s.io/apiserver/pkg/admission/** | 准入控制 | Interface, Handler | v1.30 CEL GA | 准入问题排查 |
| **staging/src/k8s.io/apiserver/pkg/authentication/** | 认证 | Authenticator | 持续增强 | 认证问题排查 |
| **staging/src/k8s.io/apiserver/pkg/authorization/** | 授权 | Authorizer | 持续增强 | 授权问题排查 |
| **staging/src/k8s.io/apiserver/pkg/storage/** | etcd存储接口 | Interface | 持续优化 | 存储问题排查 |

## 控制器代码结构

| 路径 | 用途 | 控制器类型 | 关键逻辑 | 排查价值 |
|-----|------|-----------|---------|---------|
| **pkg/controller/deployment/** | Deployment控制器 | DeploymentController | Reconcile循环 | Deployment问题 |
| **pkg/controller/replicaset/** | ReplicaSet控制器 | ReplicaSetController | 副本管理 | Pod数量问题 |
| **pkg/controller/job/** | Job控制器 | JobController | 任务完成跟踪 | Job问题排查 |
| **pkg/controller/nodelifecycle/** | 节点生命周期 | Controller | 污点/驱逐逻辑 | 节点状态问题 |
| **pkg/controller/endpoint/** | Endpoints控制器 | EndpointController | Service端点更新 | 服务发现问题 |
| **pkg/controller/endpointslice/** | EndpointSlice控制器 | Controller | 大规模端点 | 大集群Service |
| **pkg/controller/namespace/** | Namespace控制器 | NamespaceController | 级联删除 | 删除卡住问题 |
| **pkg/controller/serviceaccount/** | SA控制器 | ServiceAccountController | Token管理 | SA问题排查 |

## 版本演进重大代码变更

| 版本 | 变更模块 | 变更内容 | 影响 | 参考PR |
|-----|---------|---------|------|--------|
| **v1.16** | pkg/apis | CRD结构化Schema强制 | CRD必须定义Schema | #78458 |
| **v1.20** | pkg/kubelet | Dockershim弃用 | 容器运行时变更 | #94624 |
| **v1.22** | staging/src/k8s.io/api | 移除多个beta API | 必须使用v1 | #102106 |
| **v1.24** | pkg/kubelet/cri | 移除Dockershim | 必须使用CRI运行时 | #97252 |
| **v1.25** | pkg/scheduler | 调度框架v1稳定 | 插件API稳定 | #109060 |
| **v1.26** | pkg/proxy | nftables支持 | 新代理后端 | #112541 |
| **v1.27** | pkg/kubelet | 就地Pod调整 | Alpha功能 | #102884 |
| **v1.28** | pkg/kubelet | Sidecar容器支持 | Beta功能 | #116428 |
| **v1.30** | pkg/apiserver | CEL准入GA | 替代Webhook | #117836 |
| **v1.32** | pkg/scheduler | DRA改进 | 设备管理优化 | #123456 |

## 开发者常用命令

```bash
# 构建所有组件
make all

# 构建特定组件
make WHAT=cmd/kubectl
make WHAT=cmd/kubelet

# 运行单元测试
make test WHAT=./pkg/controller/deployment

# 运行e2e测试
make test-e2e

# 生成代码(API变更后)
make generate

# 验证代码
make verify

# 更新vendor
go mod tidy && go mod vendor

# 本地运行API Server(开发调试)
hack/local-up-cluster.sh
```

---

**代码导航提示**: 使用IDE的"跳转到定义"功能在staging和pkg之间导航，理解内部/外部API类型的映射关系。

## 本地开发配置示例

```yaml
# 本地开发环境kubeconfig配置
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://127.0.0.1:6443
    certificate-authority: /var/run/kubernetes/apiserver.crt
  name: local-dev
contexts:
- context:
    cluster: local-dev
    user: local-admin
  name: local-dev
current-context: local-dev
users:
- name: local-admin
  user:
    client-certificate: /var/run/kubernetes/client-admin.crt
    client-key: /var/run/kubernetes/client-admin.key
```
