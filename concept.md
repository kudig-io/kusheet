# Kubernetes 与 AI/ML 概念参考手册

> 本文档汇总了 kusheet 项目中涉及的所有核心技术概念，包含名称、简述、Wikipedia URL、首次论文及官方文档链接。

---

## 目录

1. [Kubernetes 核心架构概念](#1-kubernetes-核心架构概念)
2. [分布式系统理论](#2-分布式系统理论)
3. [Kubernetes 设计模式](#3-kubernetes-设计模式)
4. [控制平面组件](#4-控制平面组件)
5. [数据平面组件](#5-数据平面组件)
6. [网络概念](#6-网络概念)
7. [存储概念](#7-存储概念)
8. [安全概念](#8-安全概念)
9. [可观测性概念](#9-可观测性概念)
10. [AI/ML 工程概念](#10-aiml-工程概念)
11. [LLM 特有概念](#11-llm-特有概念)
12. [DevOps 工具与实践](#12-devops-工具与实践)

---

## 1. Kubernetes 核心架构概念

### Kubernetes
| 属性 | 内容 |
|------|------|
| **简述** | Google 开源的容器编排平台，用于自动化部署、扩展和管理容器化应用 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes |
| **首次论文** | "Large-scale cluster management at Google with Borg" (EuroSys 2015) - https://research.google/pubs/pub43438/ |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/ |

### Pod
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 最小调度单元，包含一个或多个共享网络和存储的容器 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Pods |
| **首次论文** | Kubernetes 设计文档 (2014) |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/pods/ |

### Node
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 集群中的工作机器，可以是物理机或虚拟机 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Nodes |
| **首次论文** | Kubernetes 设计文档 (2014) |
| **官方文档** | https://kubernetes.io/docs/concepts/architecture/nodes/ |

### Namespace
| 属性 | 内容 |
|------|------|
| **简述** | 用于在单个集群中实现多租户资源隔离的逻辑分区机制 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Namespaces |
| **首次论文** | Kubernetes 设计文档 (2014) |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/ |

### Deployment
| 属性 | 内容 |
|------|------|
| **简述** | 声明式管理 Pod 和 ReplicaSet 的资源对象，支持滚动更新和回滚 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Deployments |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/controllers/deployment/ |

### StatefulSet
| 属性 | 内容 |
|------|------|
| **简述** | 管理有状态应用的工作负载控制器，保证 Pod 的唯一性和持久存储 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/ |

### DaemonSet
| 属性 | 内容 |
|------|------|
| **简述** | 确保所有（或部分）节点运行一个 Pod 副本的控制器 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/ |

### ReplicaSet
| 属性 | 内容 |
|------|------|
| **简述** | 确保指定数量的 Pod 副本始终运行的控制器 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ |

### Job
| 属性 | 内容 |
|------|------|
| **简述** | 创建一个或多个 Pod 执行一次性任务直到成功完成 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/controllers/job/ |

### CronJob
| 属性 | 内容 |
|------|------|
| **简述** | 基于 Cron 表达式定时创建 Job 的控制器 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/ |

---

## 2. 分布式系统理论

### CAP 定理
| 属性 | 内容 |
|------|------|
| **简述** | 分布式系统最多同时满足一致性、可用性、分区容错性中的两个 |
| **Wikipedia** | https://en.wikipedia.org/wiki/CAP_theorem |
| **首次论文** | "Towards Robust Distributed Systems" - Eric Brewer (PODC 2000) - https://www.cs.berkeley.edu/~brewer/cs262b-2004/PODC-keynote.pdf |
| **官方文档** | N/A (理论概念) |

### Raft 共识算法
| 属性 | 内容 |
|------|------|
| **简述** | 易于理解的分布式共识算法，通过 Leader 选举和日志复制保证一致性 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Raft_(algorithm) |
| **首次论文** | "In Search of an Understandable Consensus Algorithm" - Diego Ongaro (ATC 2014) - https://raft.github.io/raft.pdf |
| **官方文档** | https://raft.github.io/ |

### Paxos
| 属性 | 内容 |
|------|------|
| **简述** | 经典的分布式共识算法，Raft 的理论基础 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Paxos_(computer_science) |
| **首次论文** | "The Part-Time Parliament" - Leslie Lamport (ACM TOCS 1998) - https://lamport.azurewebsites.net/pubs/lamport-paxos.pdf |
| **官方文档** | N/A (理论概念) |

### MVCC (多版本并发控制)
| 属性 | 内容 |
|------|------|
| **简述** | 数据库并发控制方法，通过维护数据的多个版本来避免读写冲突 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Multiversion_concurrency_control |
| **首次论文** | "Concurrency Control in Distributed Database Systems" - P.A. Bernstein (ACM Computing Surveys 1981) |
| **官方文档** | https://etcd.io/docs/v3.5/learning/data_model/ |

### 乐观并发控制
| 属性 | 内容 |
|------|------|
| **简述** | 假设冲突较少，在提交时检查版本号来检测并发冲突的机制 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Optimistic_concurrency_control |
| **首次论文** | "On Optimistic Methods for Concurrency Control" - H.T. Kung (ACM TODS 1981) |
| **官方文档** | https://kubernetes.io/docs/reference/using-api/api-concepts/#resource-versions |

### 最终一致性
| 属性 | 内容 |
|------|------|
| **简述** | 分布式系统一致性模型，保证在没有新更新时所有副本最终收敛到相同状态 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Eventual_consistency |
| **首次论文** | "Eventual Consistency" - Werner Vogels (ACM Queue 2008) - https://queue.acm.org/detail.cfm?id=1466448 |
| **官方文档** | N/A (理论概念) |

### Quorum
| 属性 | 内容 |
|------|------|
| **简述** | 分布式系统中达成一致性所需的最小节点数 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Quorum_(distributed_computing) |
| **首次论文** | "A Quorum-Based Commit Protocol" - D. Skeen (BDE 1982) |
| **官方文档** | https://etcd.io/docs/v3.5/faq/#what-is-failure-tolerance |

---

## 3. Kubernetes 设计模式

### 声明式 API
| 属性 | 内容 |
|------|------|
| **简述** | 用户描述期望状态，系统自动驱动实际状态向期望状态收敛 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Declarative_programming |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/kubernetes-api/ |

### 控制器模式 (Reconciliation Loop)
| 属性 | 内容 |
|------|------|
| **简述** | 持续监控资源变化并执行调谐操作，使实际状态趋向期望状态 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Control_loop |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/architecture/controller/ |

### Operator 模式
| 属性 | 内容 |
|------|------|
| **简述** | 使用 CRD 和自定义控制器将运维知识编码为软件的 Kubernetes 扩展模式 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Operators |
| **首次论文** | "Kubernetes Operators" - CoreOS (2016) - https://web.archive.org/web/20170129131616/https://coreos.com/blog/introducing-operators.html |
| **官方文档** | https://kubernetes.io/docs/concepts/extend-kubernetes/operator/ |

### Informer
| 属性 | 内容 |
|------|------|
| **简述** | 基于 List-Watch 机制的客户端缓存组件，减少 API Server 压力 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes client-go 设计文档 |
| **官方文档** | https://pkg.go.dev/k8s.io/client-go/informers |

### WorkQueue
| 属性 | 内容 |
|------|------|
| **简述** | 控制器的任务队列组件，支持去重、限速、延迟等特性 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes client-go 设计文档 |
| **官方文档** | https://pkg.go.dev/k8s.io/client-go/util/workqueue |

### Watch 机制
| 属性 | 内容 |
|------|------|
| **简述** | 通过长连接监听资源变化事件，实现增量更新 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/using-api/api-concepts/#efficient-detection-of-changes |

### Sidecar 模式
| 属性 | 内容 |
|------|------|
| **简述** | 在 Pod 中添加辅助容器扩展主容器功能的设计模式 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Sidecar_pattern |
| **首次论文** | "Design Patterns for Container-based Distributed Systems" - Brendan Burns (HotCloud 2016) - https://www.usenix.org/system/files/conference/hotcloud16/hotcloud16_burns.pdf |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/ |

### Init Container
| 属性 | 内容 |
|------|------|
| **简述** | Pod 启动前顺序执行的初始化容器 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/pods/init-containers/ |

### Finalizers
| 属性 | 内容 |
|------|------|
| **简述** | 资源删除前必须执行的清理操作标记，确保外部资源正确清理 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/working-with-objects/finalizers/ |

### Owner References
| 属性 | 内容 |
|------|------|
| **简述** | 资源所有者引用，用于级联删除和垃圾回收 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/working-with-objects/owners-dependents/ |

---

## 4. 控制平面组件

### etcd
| 属性 | 内容 |
|------|------|
| **简述** | 基于 Raft 的分布式键值存储，是 Kubernetes 集群的唯一持久化数据源 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Etcd |
| **首次论文** | CoreOS etcd 设计文档 (2013) |
| **官方文档** | https://etcd.io/docs/ |

### kube-apiserver
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 控制平面的前端，提供 REST API 和集群状态管理 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#API_server |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/components/#kube-apiserver |

### kube-controller-manager
| 属性 | 内容 |
|------|------|
| **简述** | 运行所有核心控制器的组件，包括 Deployment、Node、Service 控制器等 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/components/#kube-controller-manager |

### kube-scheduler
| 属性 | 内容 |
|------|------|
| **简述** | 负责为新创建的 Pod 选择最优节点的调度器 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Scheduler |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/ |

### Scheduling Framework
| 属性 | 内容 |
|------|------|
| **简述** | kube-scheduler 的可扩展插件架构，支持 PreFilter、Filter、Score 等扩展点 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes KEP-624 |
| **官方文档** | https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/ |

### Node Affinity
| 属性 | 内容 |
|------|------|
| **简述** | 基于节点标签的调度约束，控制 Pod 调度到特定节点 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity |

### Pod Affinity/Anti-Affinity
| 属性 | 内容 |
|------|------|
| **简述** | 基于已运行 Pod 的调度约束，实现 Pod 的共置或分散部署 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity |

### Taints and Tolerations
| 属性 | 内容 |
|------|------|
| **简述** | 节点排斥机制，通过污点标记节点，只有容忍该污点的 Pod 才能调度 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ |

### TopologySpreadConstraints
| 属性 | 内容 |
|------|------|
| **简述** | 跨拓扑域（可用区、节点）均匀分布 Pod 的调度约束 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes KEP-895 |
| **官方文档** | https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/ |

### Priority and Preemption
| 属性 | 内容 |
|------|------|
| **简述** | Pod 优先级和抢占机制，高优先级 Pod 可驱逐低优先级 Pod |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/ |

### QoS Classes
| 属性 | 内容 |
|------|------|
| **简述** | Pod 服务质量等级（Guaranteed/Burstable/BestEffort），影响驱逐优先级 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/ |

### cloud-controller-manager
| 属性 | 内容 |
|------|------|
| **简述** | 运行云平台特定控制器的组件，如负载均衡器和节点生命周期管理 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/components/#cloud-controller-manager |

### Admission Controller
| 属性 | 内容 |
|------|------|
| **简述** | API Server 的插件，在资源持久化前拦截、修改或验证请求 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/ |

### API Aggregation
| 属性 | 内容 |
|------|------|
| **简述** | 允许扩展 Kubernetes API 的机制，支持自定义 API Server |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/apiserver-aggregation/ |

### Custom Resource Definition (CRD)
| 属性 | 内容 |
|------|------|
| **简述** | 允许用户定义新的 Kubernetes 资源类型的扩展机制 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/ |

---

## 5. 数据平面组件

### kubelet
| 属性 | 内容 |
|------|------|
| **简述** | 运行在每个节点上的代理，管理 Pod 和容器的生命周期 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Kubelet |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/components/#kubelet |

### kube-proxy
| 属性 | 内容 |
|------|------|
| **简述** | 运行在每个节点上的网络代理，实现 Service 的虚拟 IP 和负载均衡 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Kube-proxy |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/components/#kube-proxy |

### Container Runtime Interface (CRI)
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 与容器运行时之间的标准接口规范 |
| **Wikipedia** | N/A |
| **首次论文** | "Kubernetes Container Runtime Interface" - Kubernetes SIG-Node |
| **官方文档** | https://kubernetes.io/docs/concepts/architecture/cri/ |

### containerd
| 属性 | 内容 |
|------|------|
| **简述** | 行业标准的高级容器运行时，Docker 的核心组件 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Containerd |
| **首次论文** | containerd 设计文档 |
| **官方文档** | https://containerd.io/docs/ |

### CRI-O
| 属性 | 内容 |
|------|------|
| **简述** | 专为 Kubernetes 优化的轻量级容器运行时 |
| **Wikipedia** | https://en.wikipedia.org/wiki/CRI-O |
| **首次论文** | CRI-O 设计文档 |
| **官方文档** | https://cri-o.io/ |

### RuntimeClass
| 属性 | 内容 |
|------|------|
| **简述** | 选择容器运行时配置的 Kubernetes 资源，支持不同隔离级别的运行时 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes KEP-585 |
| **官方文档** | https://kubernetes.io/docs/concepts/containers/runtime-class/ |

### gVisor
| 属性 | 内容 |
|------|------|
| **简述** | Google 开源的应用内核沙箱，提供容器的内核级隔离 |
| **Wikipedia** | https://en.wikipedia.org/wiki/GVisor |
| **首次论文** | "gVisor: Container Runtime Sandbox" - Google (2018) |
| **官方文档** | https://gvisor.dev/docs/ |

### Kata Containers
| 属性 | 内容 |
|------|------|
| **简述** | 使用轻量级虚拟机提供容器隔离的安全容器运行时 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kata_Containers |
| **首次论文** | Kata Containers 设计文档 (OpenStack Foundation) |
| **官方文档** | https://katacontainers.io/docs/ |

### OCI (Open Container Initiative)
| 属性 | 内容 |
|------|------|
| **简述** | 容器格式和运行时的开放标准，定义镜像规范和运行时规范 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Open_Container_Initiative |
| **首次论文** | OCI Runtime Specification |
| **官方文档** | https://opencontainers.org/ |

### runc
| 属性 | 内容 |
|------|------|
| **简述** | OCI 容器运行时规范的参考实现，是大多数容器运行时的底层组件 |
| **Wikipedia** | N/A |
| **首次论文** | OCI runc 设计文档 |
| **官方文档** | https://github.com/opencontainers/runc |

### PLEG (Pod Lifecycle Event Generator)
| 属性 | 内容 |
|------|------|
| **简述** | kubelet 组件，检测容器状态变化并生成 Pod 生命周期事件 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes kubelet 设计文档 |
| **官方文档** | https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/pleg/pleg.go |

---

## 6. 网络概念

### Container Network Interface (CNI)
| 属性 | 内容 |
|------|------|
| **简述** | 容器网络的标准接口规范，定义容器网络配置的插件架构 |
| **Wikipedia** | N/A |
| **首次论文** | CNI Specification - https://github.com/containernetworking/cni/blob/main/SPEC.md |
| **官方文档** | https://www.cni.dev/ |

### Calico
| 属性 | 内容 |
|------|------|
| **简述** | 基于 BGP 路由的高性能 Kubernetes 网络和网络策略解决方案 |
| **Wikipedia** | N/A |
| **首次论文** | Project Calico 设计文档 |
| **官方文档** | https://docs.tigera.io/calico/latest/about/ |

### Cilium
| 属性 | 内容 |
|------|------|
| **简述** | 基于 eBPF 技术的新一代 Kubernetes 网络、安全和可观测性平台 |
| **Wikipedia** | N/A |
| **首次论文** | "Cilium: BPF & XDP for containers" - Thomas Graf |
| **官方文档** | https://docs.cilium.io/ |

### Flannel
| 属性 | 内容 |
|------|------|
| **简述** | 简单易用的 Kubernetes 网络 overlay 方案 |
| **Wikipedia** | N/A |
| **首次论文** | CoreOS Flannel 设计文档 |
| **官方文档** | https://github.com/flannel-io/flannel |

### Service
| 属性 | 内容 |
|------|------|
| **简述** | 为一组 Pod 提供稳定的网络访问入口和负载均衡 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Services |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/service/ |

### EndpointSlice
| 属性 | 内容 |
|------|------|
| **简述** | Service 端点的可扩展表示，取代 Endpoints 对象，支持更大规模的服务发现 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes KEP-752 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/ |

### Ingress
| 属性 | 内容 |
|------|------|
| **简述** | 管理集群外部到内部服务的 HTTP/HTTPS 访问的 API 对象 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/ingress/ |

### NetworkPolicy
| 属性 | 内容 |
|------|------|
| **简述** | 定义 Pod 间网络访问规则的安全策略 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/network-policies/ |

### CoreDNS
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 默认的 DNS 服务器，提供服务发现功能 |
| **Wikipedia** | N/A |
| **首次论文** | CoreDNS 设计文档 |
| **官方文档** | https://coredns.io/manual/toc/ |

### eBPF
| 属性 | 内容 |
|------|------|
| **简述** | 扩展的伯克利包过滤器，允许在内核中安全运行沙盒程序 |
| **Wikipedia** | https://en.wikipedia.org/wiki/EBPF |
| **首次论文** | "BPF: Tracing and More" - Brendan Gregg |
| **官方文档** | https://ebpf.io/ |

### IPVS
| 属性 | 内容 |
|------|------|
| **简述** | Linux 内核级负载均衡解决方案，比 iptables 性能更高 |
| **Wikipedia** | https://en.wikipedia.org/wiki/IP_Virtual_Server |
| **首次论文** | "The Linux Virtual Server Project" |
| **官方文档** | http://www.linuxvirtualserver.org/ |

### Service Mesh
| 属性 | 内容 |
|------|------|
| **简述** | 微服务间通信的基础设施层，提供流量管理、安全和可观测性 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Service_mesh |
| **首次论文** | "What's a service mesh? And why do I need one?" - William Morgan (2017) |
| **官方文档** | https://istio.io/latest/about/service-mesh/ |

### Istio
| 属性 | 内容 |
|------|------|
| **简述** | 开源服务网格平台，提供流量管理、安全和可观测性 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Istio |
| **首次论文** | Istio 设计文档 |
| **官方文档** | https://istio.io/latest/docs/ |

### Linkerd
| 属性 | 内容 |
|------|------|
| **简述** | 轻量级服务网格，使用 Rust 编写的数据平面，资源开销低 |
| **Wikipedia** | N/A |
| **首次论文** | Buoyant Linkerd 设计文档 |
| **官方文档** | https://linkerd.io/docs/ |

### VirtualService
| 属性 | 内容 |
|------|------|
| **简述** | Istio 流量路由规则，定义请求如何路由到服务的不同版本 |
| **Wikipedia** | N/A |
| **首次论文** | Istio 设计文档 |
| **官方文档** | https://istio.io/latest/docs/reference/config/networking/virtual-service/ |

### DestinationRule
| 属性 | 内容 |
|------|------|
| **简述** | Istio 目标规则，定义流量到达服务后的策略（负载均衡、连接池、熔断） |
| **Wikipedia** | N/A |
| **首次论文** | Istio 设计文档 |
| **官方文档** | https://istio.io/latest/docs/reference/config/networking/destination-rule/ |

### Gateway API
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 下一代 Ingress API，支持角色分离、多协议和更丰富的路由功能 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes SIG-Network Gateway API KEP |
| **官方文档** | https://gateway-api.sigs.k8s.io/ |

### Envoy
| 属性 | 内容 |
|------|------|
| **简述** | 高性能 L7 代理和通信总线，是 Istio 数据平面的核心组件 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Envoy_(software) |
| **首次论文** | Lyft Envoy 设计文档 (2016) |
| **官方文档** | https://www.envoyproxy.io/docs/ |

### NGINX Ingress Controller
| 属性 | 内容 |
|------|------|
| **简述** | 基于 NGINX 的 Kubernetes Ingress 控制器实现 |
| **Wikipedia** | N/A |
| **首次论文** | NGINX Ingress Controller 设计文档 |
| **官方文档** | https://kubernetes.github.io/ingress-nginx/ |

### Topology Aware Routing
| 属性 | 内容 |
|------|------|
| **简述** | 基于拓扑位置（如可用区）优先路由流量到最近端点的服务路由策略 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes EndpointSlice Topology KEP |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/topology-aware-routing/ |

---

## 7. 存储概念

### Container Storage Interface (CSI)
| 属性 | 内容 |
|------|------|
| **简述** | 容器存储的标准接口规范，使存储供应商能通过驱动程序与 Kubernetes 集成 |
| **Wikipedia** | N/A |
| **首次论文** | CSI Specification - https://github.com/container-storage-interface/spec |
| **官方文档** | https://kubernetes-csi.github.io/docs/ |

### PersistentVolume (PV)
| 属性 | 内容 |
|------|------|
| **简述** | 集群级别的存储资源抽象，具有独立的生命周期 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/persistent-volumes/ |

### PersistentVolumeClaim (PVC)
| 属性 | 内容 |
|------|------|
| **简述** | 用户申请存储资源的声明式对象 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims |

### StorageClass
| 属性 | 内容 |
|------|------|
| **简述** | 定义存储供应商和参数的对象，支持动态创建 PV |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/storage-classes/ |

### VolumeSnapshot
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 原生的存储卷快照对象，支持创建卷的时间点副本 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/volume-snapshots/ |

### Dynamic Provisioning
| 属性 | 内容 |
|------|------|
| **简述** | 根据 PVC 请求自动创建 PV 的机制 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/ |

---

## 8. 安全概念

### RBAC (Role-Based Access Control)
| 属性 | 内容 |
|------|------|
| **简述** | 基于角色的访问控制，通过 Role/ClusterRole 定义权限 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Role-based_access_control |
| **首次论文** | "Role-Based Access Controls" - David Ferraiolo (NIST 1992) |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/rbac/ |

### ServiceAccount
| 属性 | 内容 |
|------|------|
| **简述** | Pod 使用的身份验证和授权凭证 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/security/service-accounts/ |

### Pod Security Standards
| 属性 | 内容 |
|------|------|
| **简述** | 定义 Pod 安全配置文件的标准（Privileged、Baseline、Restricted） |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/security/pod-security-standards/ |

### ConfigMap
| 属性 | 内容 |
|------|------|
| **简述** | 存储非敏感配置数据的 Kubernetes 对象，以键值对形式注入 Pod |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/configuration/configmap/ |

### Secret
| 属性 | 内容 |
|------|------|
| **简述** | 存储敏感数据（密码、令牌、密钥）的 Kubernetes 对象 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/configuration/secret/ |

### TLS/mTLS
| 属性 | 内容 |
|------|------|
| **简述** | 传输层安全协议，mTLS 为双向认证的 TLS |
| **Wikipedia** | https://en.wikipedia.org/wiki/Transport_Layer_Security |
| **首次论文** | RFC 8446 - TLS 1.3 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/ingress/#tls |

### Seccomp
| 属性 | 内容 |
|------|------|
| **简述** | Linux 内核安全特性，限制容器可以执行的系统调用 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Seccomp |
| **首次论文** | Linux Kernel 文档 |
| **官方文档** | https://kubernetes.io/docs/tutorials/security/seccomp/ |

### AppArmor
| 属性 | 内容 |
|------|------|
| **简述** | Linux 内核安全模块，提供强制访问控制 |
| **Wikipedia** | https://en.wikipedia.org/wiki/AppArmor |
| **首次论文** | AppArmor 项目文档 |
| **官方文档** | https://kubernetes.io/docs/tutorials/security/apparmor/ |

### OPA (Open Policy Agent)
| 属性 | 内容 |
|------|------|
| **简述** | 通用策略引擎，使用 Rego 语言定义策略，CNCF 毕业项目 |
| **Wikipedia** | N/A |
| **首次论文** | "Rego: A Policy Language for the Cloud" - Styra |
| **官方文档** | https://www.openpolicyagent.org/docs/ |

### Gatekeeper
| 属性 | 内容 |
|------|------|
| **简述** | OPA 的 Kubernetes 原生实现，通过 CRD 管理策略 |
| **Wikipedia** | N/A |
| **首次论文** | OPA Gatekeeper 设计文档 |
| **官方文档** | https://open-policy-agent.github.io/gatekeeper/website/docs/ |

### Kyverno
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 原生策略引擎，使用 YAML 定义策略，CNCF 孵化项目 |
| **Wikipedia** | N/A |
| **首次论文** | Kyverno 设计文档 |
| **官方文档** | https://kyverno.io/docs/ |

### ValidatingAdmissionPolicy
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 内置的策略验证机制，使用 CEL 表达式，无需外部 Webhook |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes KEP-3488 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/ |

### CEL (Common Expression Language)
| 属性 | 内容 |
|------|------|
| **简述** | Google 开源的表达式语言，用于 Kubernetes 准入控制和策略验证 |
| **Wikipedia** | N/A |
| **首次论文** | Google CEL Specification |
| **官方文档** | https://cel.dev/ |

### cert-manager
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 原生的证书管理控制器，自动颁发和续期 TLS 证书 |
| **Wikipedia** | N/A |
| **首次论文** | Jetstack cert-manager 设计文档 |
| **官方文档** | https://cert-manager.io/docs/ |

### Let's Encrypt
| 属性 | 内容 |
|------|------|
| **简述** | 免费、自动化、开放的证书颁发机构，常与 cert-manager 配合使用 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Let%27s_Encrypt |
| **首次论文** | ISRG Let's Encrypt 设计文档 |
| **官方文档** | https://letsencrypt.org/docs/ |

### HashiCorp Vault
| 属性 | 内容 |
|------|------|
| **简述** | 密钥管理和数据保护平台，支持动态密钥、加密和 PKI |
| **Wikipedia** | N/A |
| **首次论文** | HashiCorp Vault 设计文档 |
| **官方文档** | https://developer.hashicorp.com/vault/docs |

---

## 9. 可观测性概念

### Prometheus
| 属性 | 内容 |
|------|------|
| **简述** | 开源的系统监控和告警工具包，CNCF 毕业项目 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Prometheus_(software) |
| **首次论文** | SoundCloud Prometheus 设计文档 (2012) |
| **官方文档** | https://prometheus.io/docs/ |

### Grafana
| 属性 | 内容 |
|------|------|
| **简述** | 开源的数据可视化和监控平台 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Grafana |
| **首次论文** | Grafana Labs 项目文档 |
| **官方文档** | https://grafana.com/docs/ |

### OpenTelemetry
| 属性 | 内容 |
|------|------|
| **简述** | 云原生可观测性框架，统一 traces、metrics、logs 的收集标准 |
| **Wikipedia** | https://en.wikipedia.org/wiki/OpenTelemetry |
| **首次论文** | OpenTelemetry Specification |
| **官方文档** | https://opentelemetry.io/docs/ |

### Jaeger
| 属性 | 内容 |
|------|------|
| **简述** | 开源的分布式链路追踪系统 |
| **Wikipedia** | N/A |
| **首次论文** | Uber Jaeger 设计文档 |
| **官方文档** | https://www.jaegertracing.io/docs/ |

### Loki
| 属性 | 内容 |
|------|------|
| **简述** | Grafana 开源的轻量级日志聚合系统，专注于日志索引而非全文搜索 |
| **Wikipedia** | N/A |
| **首次论文** | Grafana Loki 设计文档 |
| **官方文档** | https://grafana.com/docs/loki/latest/ |

### Fluentd
| 属性 | 内容 |
|------|------|
| **简述** | 开源的数据收集器，统一日志层，CNCF 毕业项目 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Fluentd |
| **首次论文** | Treasure Data Fluentd 设计文档 |
| **官方文档** | https://docs.fluentd.org/ |

### Fluent Bit
| 属性 | 内容 |
|------|------|
| **简述** | 轻量级日志处理器和转发器，资源占用极低，适合边缘和容器环境 |
| **Wikipedia** | N/A |
| **首次论文** | Fluent Bit 设计文档 |
| **官方文档** | https://docs.fluentbit.io/ |

### Elasticsearch
| 属性 | 内容 |
|------|------|
| **简述** | 分布式搜索和分析引擎，ELK/EFK 日志栈的核心组件 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Elasticsearch |
| **首次论文** | Elastic Elasticsearch 设计文档 |
| **官方文档** | https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html |

### Metrics Server
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 核心指标收集组件，为 HPA 和 kubectl top 提供资源指标 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes SIG-Instrumentation 设计文档 |
| **官方文档** | https://github.com/kubernetes-sigs/metrics-server |

### Custom Metrics API
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 自定义指标 API，允许 HPA 基于应用特定指标进行扩缩容 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#scaling-on-custom-metrics |

### Prometheus Adapter
| 属性 | 内容 |
|------|------|
| **简述** | 将 Prometheus 指标暴露为 Kubernetes Custom Metrics API 的适配器 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes SIG-Instrumentation 设计文档 |
| **官方文档** | https://github.com/kubernetes-sigs/prometheus-adapter |

### cAdvisor
| 属性 | 内容 |
|------|------|
| **简述** | 容器资源使用和性能分析工具，内置于 kubelet 中 |
| **Wikipedia** | N/A |
| **首次论文** | Google cAdvisor 设计文档 |
| **官方文档** | https://github.com/google/cadvisor |

### Liveness Probe
| 属性 | 内容 |
|------|------|
| **简述** | 检测容器是否存活的探针，失败时重启容器 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |

### Readiness Probe
| 属性 | 内容 |
|------|------|
| **简述** | 检测容器是否就绪接收流量的探针 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |

### Startup Probe
| 属性 | 内容 |
|------|------|
| **简述** | 检测慢启动应用是否完成初始化的探针 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/ |

---

## 10. AI/ML 工程概念

### Kubeflow
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 上的机器学习工具包，提供端到端 ML 工作流 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubeflow |
| **首次论文** | Kubeflow 设计文档 |
| **官方文档** | https://www.kubeflow.org/docs/ |

### PyTorchJob
| 属性 | 内容 |
|------|------|
| **简述** | Kubeflow 中运行分布式 PyTorch 训练任务的 CRD |
| **Wikipedia** | N/A |
| **首次论文** | Kubeflow Training Operator 设计文档 |
| **官方文档** | https://www.kubeflow.org/docs/components/training/pytorch/ |

### Data Parallelism
| 属性 | 内容 |
|------|------|
| **简述** | 将数据分片到多个设备并行训练的分布式训练策略 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Data_parallelism |
| **首次论文** | "Large Scale Distributed Deep Networks" - Dean et al. (NIPS 2012) - https://papers.nips.cc/paper/2012/hash/6aca97005c68f1206823815f66102863-Abstract.html |
| **官方文档** | https://pytorch.org/tutorials/intermediate/ddp_tutorial.html |

### Model Parallelism
| 属性 | 内容 |
|------|------|
| **简述** | 将模型层分布到多个设备的分布式训练策略 |
| **Wikipedia** | N/A |
| **首次论文** | "Megatron-LM: Training Multi-Billion Parameter Language Models" - NVIDIA (2019) - https://arxiv.org/abs/1909.08053 |
| **官方文档** | https://huggingface.co/docs/transformers/parallelism |

### Pipeline Parallelism
| 属性 | 内容 |
|------|------|
| **简述** | 将模型不同阶段分配到不同设备形成流水线的并行策略 |
| **Wikipedia** | N/A |
| **首次论文** | "GPipe: Efficient Training of Giant Neural Networks" - Google (2019) - https://arxiv.org/abs/1811.06965 |
| **官方文档** | https://www.deepspeed.ai/tutorials/pipeline-parallelism/ |

### Tensor Parallelism
| 属性 | 内容 |
|------|------|
| **简述** | 将单个张量操作分布到多个设备的并行策略 |
| **Wikipedia** | N/A |
| **首次论文** | "Megatron-LM" - NVIDIA (2019) - https://arxiv.org/abs/1909.08053 |
| **官方文档** | https://huggingface.co/docs/transformers/parallelism#tensor-parallelism |

### DeepSpeed
| 属性 | 内容 |
|------|------|
| **简述** | 微软开源的深度学习优化库，提供 ZeRO 优化器和混合精度训练 |
| **Wikipedia** | N/A |
| **首次论文** | "ZeRO: Memory Optimizations Toward Training Trillion Parameter Models" - Microsoft (2020) - https://arxiv.org/abs/1910.02054 |
| **官方文档** | https://www.deepspeed.ai/ |

### ZeRO (Zero Redundancy Optimizer)
| 属性 | 内容 |
|------|------|
| **简述** | 消除数据并行训练中内存冗余的优化技术 |
| **Wikipedia** | N/A |
| **首次论文** | "ZeRO: Memory Optimizations Toward Training Trillion Parameter Models" - Microsoft (2020) - https://arxiv.org/abs/1910.02054 |
| **官方文档** | https://www.deepspeed.ai/tutorials/zero/ |

### Mixed Precision Training
| 属性 | 内容 |
|------|------|
| **简述** | 使用 FP16/BF16 和 FP32 混合精度加速训练的技术 |
| **Wikipedia** | N/A |
| **首次论文** | "Mixed Precision Training" - NVIDIA (2018) - https://arxiv.org/abs/1710.03740 |
| **官方文档** | https://pytorch.org/docs/stable/amp.html |

### Gradient Checkpointing
| 属性 | 内容 |
|------|------|
| **简述** | 通过重计算减少激活值内存占用的技术 |
| **Wikipedia** | N/A |
| **首次论文** | "Training Deep Nets with Sublinear Memory Cost" - Chen et al. (2016) - https://arxiv.org/abs/1604.06174 |
| **官方文档** | https://pytorch.org/docs/stable/checkpoint.html |

### NCCL (NVIDIA Collective Communications Library)
| 属性 | 内容 |
|------|------|
| **简述** | NVIDIA 开源的 GPU 间高效集合通信库，是分布式训练的基础 |
| **Wikipedia** | N/A |
| **首次论文** | NVIDIA NCCL 设计文档 |
| **官方文档** | https://docs.nvidia.com/deeplearning/nccl/user-guide/docs/ |

### Horovod
| 属性 | 内容 |
|------|------|
| **简述** | Uber 开源的分布式深度学习训练框架，支持多种深度学习框架 |
| **Wikipedia** | N/A |
| **首次论文** | "Horovod: fast and easy distributed deep learning in TensorFlow" - Uber (2018) - https://arxiv.org/abs/1802.05799 |
| **官方文档** | https://horovod.ai/ |

### FSDP (Fully Sharded Data Parallel)
| 属性 | 内容 |
|------|------|
| **简述** | PyTorch 原生的完全分片数据并行，将模型参数、梯度和优化器状态分片到多个 GPU |
| **Wikipedia** | N/A |
| **首次论文** | "PyTorch FSDP: Experiences on Scaling Fully Sharded Data Parallel" - Meta (2023) - https://arxiv.org/abs/2304.11277 |
| **官方文档** | https://pytorch.org/docs/stable/fsdp.html |

### Megatron-LM
| 属性 | 内容 |
|------|------|
| **简述** | NVIDIA 开源的大规模 Transformer 模型训练框架，支持张量并行和流水线并行 |
| **Wikipedia** | N/A |
| **首次论文** | "Megatron-LM: Training Multi-Billion Parameter Language Models" - NVIDIA (2019) - https://arxiv.org/abs/1909.08053 |
| **官方文档** | https://github.com/NVIDIA/Megatron-LM |

### GPU Scheduling
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 中 GPU 资源的调度和分配机制 |
| **Wikipedia** | N/A |
| **首次论文** | NVIDIA Device Plugin 设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/ |

### NVIDIA Device Plugin
| 属性 | 内容 |
|------|------|
| **简述** | 使 Kubernetes 能够发现和调度 NVIDIA GPU 的插件 |
| **Wikipedia** | N/A |
| **首次论文** | NVIDIA Device Plugin 设计文档 |
| **官方文档** | https://github.com/NVIDIA/k8s-device-plugin |

### MLflow
| 属性 | 内容 |
|------|------|
| **简述** | 开源的机器学习生命周期管理平台，支持实验跟踪、模型注册和部署 |
| **Wikipedia** | N/A |
| **首次论文** | "MLflow: A Machine Learning Lifecycle Platform" - Databricks (2018) |
| **官方文档** | https://mlflow.org/docs/latest/index.html |

### Kubeflow Pipelines
| 属性 | 内容 |
|------|------|
| **简述** | 基于容器的端到端机器学习工作流编排平台 |
| **Wikipedia** | N/A |
| **首次论文** | Kubeflow Pipelines 设计文档 |
| **官方文档** | https://www.kubeflow.org/docs/components/pipelines/ |

### Ray
| 属性 | 内容 |
|------|------|
| **简述** | 分布式计算框架，支持大规模 ML 训练和推理 |
| **Wikipedia** | N/A |
| **首次论文** | "Ray: A Distributed Framework for Emerging AI Applications" - UC Berkeley (OSDI 2018) - https://www.usenix.org/conference/osdi18/presentation/moritz |
| **官方文档** | https://docs.ray.io/ |

### Feature Store
| 属性 | 内容 |
|------|------|
| **简述** | 集中管理和服务机器学习特征的数据平台 |
| **Wikipedia** | N/A |
| **首次论文** | "Feature Stores: A Hierarchy of Needs" - Feast 设计文档 |
| **官方文档** | https://feast.dev/docs/ |

### AutoML
| 属性 | 内容 |
|------|------|
| **简述** | 自动化机器学习流程的技术，包括特征工程、模型选择和超参数优化 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Automated_machine_learning |
| **首次论文** | "Auto-WEKA: Combined Selection and Hyperparameter Optimization" - Thornton et al. (KDD 2013) |
| **官方文档** | https://www.automl.org/ |

### Hyperband
| 属性 | 内容 |
|------|------|
| **简述** | 高效的超参数优化算法，通过早停策略减少计算资源浪费 |
| **Wikipedia** | N/A |
| **首次论文** | "Hyperband: A Novel Bandit-Based Approach to Hyperparameter Optimization" - Li et al. (JMLR 2018) - https://arxiv.org/abs/1603.06560 |
| **官方文档** | https://optuna.readthedocs.io/en/stable/reference/pruners/generated/optuna.pruners.HyperbandPruner.html |

### Neural Architecture Search (NAS)
| 属性 | 内容 |
|------|------|
| **简述** | 自动搜索最优神经网络架构的技术 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Neural_architecture_search |
| **首次论文** | "Neural Architecture Search with Reinforcement Learning" - Zoph et al. (ICLR 2017) - https://arxiv.org/abs/1611.01578 |
| **官方文档** | https://www.automl.org/automl/nas/ |

### DCGM (Data Center GPU Manager)
| 属性 | 内容 |
|------|------|
| **简述** | NVIDIA 数据中心 GPU 管理和监控工具套件 |
| **Wikipedia** | N/A |
| **首次论文** | NVIDIA DCGM 设计文档 |
| **官方文档** | https://developer.nvidia.com/dcgm |

### KServe
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 原生的无服务器模型推理平台，支持自动扩缩容和金丝雀部署 |
| **Wikipedia** | N/A |
| **首次论文** | KServe (原 KFServing) 设计文档 |
| **官方文档** | https://kserve.github.io/website/ |

### Triton Inference Server
| 属性 | 内容 |
|------|------|
| **简述** | NVIDIA 开源的高性能推理服务器，支持多框架和动态批处理 |
| **Wikipedia** | N/A |
| **首次论文** | NVIDIA Triton 设计文档 |
| **官方文档** | https://docs.nvidia.com/deeplearning/triton-inference-server/user-guide/docs/ |

### TorchServe
| 属性 | 内容 |
|------|------|
| **简述** | PyTorch 官方的模型服务框架，支持模型打包和 REST/gRPC API |
| **Wikipedia** | N/A |
| **首次论文** | AWS/Meta TorchServe 设计文档 |
| **官方文档** | https://pytorch.org/serve/ |

### ONNX Runtime
| 属性 | 内容 |
|------|------|
| **简述** | 跨平台的高性能机器学习推理引擎，支持多种硬件加速 |
| **Wikipedia** | N/A |
| **首次论文** | Microsoft ONNX Runtime 设计文档 |
| **官方文档** | https://onnxruntime.ai/docs/ |

### KubeEdge
| 属性 | 内容 |
|------|------|
| **简述** | CNCF 孵化的云边协同平台，支持边缘节点离线自治和设备管理 |
| **Wikipedia** | N/A |
| **首次论文** | KubeEdge 设计文档 |
| **官方文档** | https://kubeedge.io/docs/ |

### OpenYurt
| 属性 | 内容 |
|------|------|
| **简述** | 阿里开源的 CNCF 边缘计算平台，无侵入式扩展原生 Kubernetes 到边缘 |
| **Wikipedia** | N/A |
| **首次论文** | OpenYurt 设计文档 |
| **官方文档** | https://openyurt.io/docs/ |

### K3s
| 属性 | 内容 |
|------|------|
| **简述** | Rancher 开源的轻量级 Kubernetes 发行版，适合边缘和 IoT 场景 |
| **Wikipedia** | N/A |
| **首次论文** | Rancher K3s 设计文档 |
| **官方文档** | https://docs.k3s.io/ |

---

## 11. LLM 特有概念

### Transformer
| 属性 | 内容 |
|------|------|
| **简述** | 基于自注意力机制的神经网络架构，是现代 LLM 的基础 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Transformer_(machine_learning_model) |
| **首次论文** | "Attention Is All You Need" - Vaswani et al. (NeurIPS 2017) - https://arxiv.org/abs/1706.03762 |
| **官方文档** | https://huggingface.co/docs/transformers/ |

### LoRA (Low-Rank Adaptation)
| 属性 | 内容 |
|------|------|
| **简述** | 通过低秩分解实现参数高效微调的技术，仅训练 0.1% 参数 |
| **Wikipedia** | N/A |
| **首次论文** | "LoRA: Low-Rank Adaptation of Large Language Models" - Microsoft (2021) - https://arxiv.org/abs/2106.09685 |
| **官方文档** | https://huggingface.co/docs/peft/conceptual_guides/lora |

### QLoRA
| 属性 | 内容 |
|------|------|
| **简述** | 结合量化和 LoRA 的高效微调技术，可在消费级 GPU 上微调大模型 |
| **Wikipedia** | N/A |
| **首次论文** | "QLoRA: Efficient Finetuning of Quantized LLMs" - Dettmers et al. (2023) - https://arxiv.org/abs/2305.14314 |
| **官方文档** | https://huggingface.co/docs/peft/developer_guides/quantization |

### RLHF (Reinforcement Learning from Human Feedback)
| 属性 | 内容 |
|------|------|
| **简述** | 使用人类反馈训练奖励模型并通过强化学习对齐 LLM 的技术 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Reinforcement_learning_from_human_feedback |
| **首次论文** | "Training language models to follow instructions with human feedback" - OpenAI (2022) - https://arxiv.org/abs/2203.02155 |
| **官方文档** | https://huggingface.co/docs/trl/index |

### DPO (Direct Preference Optimization)
| 属性 | 内容 |
|------|------|
| **简述** | 无需奖励模型直接从偏好数据优化 LLM 的对齐技术 |
| **Wikipedia** | N/A |
| **首次论文** | "Direct Preference Optimization: Your Language Model is Secretly a Reward Model" - Stanford (2023) - https://arxiv.org/abs/2305.18290 |
| **官方文档** | https://huggingface.co/docs/trl/dpo_trainer |

### SFT (Supervised Fine-Tuning)
| 属性 | 内容 |
|------|------|
| **简述** | 使用监督学习在指令-响应数据集上微调 LLM |
| **Wikipedia** | N/A |
| **首次论文** | "Training language models to follow instructions with human feedback" - OpenAI (2022) |
| **官方文档** | https://huggingface.co/docs/trl/sft_trainer |

### GPTQ
| 属性 | 内容 |
|------|------|
| **简述** | 基于 Hessian 矩阵的逐层后训练量化方法 |
| **Wikipedia** | N/A |
| **首次论文** | "GPTQ: Accurate Post-Training Quantization for Generative Pre-trained Transformers" - IST Austria (2023) - https://arxiv.org/abs/2210.17323 |
| **官方文档** | https://github.com/IST-DASLab/gptq |

### AWQ (Activation-aware Weight Quantization)
| 属性 | 内容 |
|------|------|
| **简述** | 基于激活值分布的权重量化方法，保护重要权重 |
| **Wikipedia** | N/A |
| **首次论文** | "AWQ: Activation-aware Weight Quantization for LLM Compression and Acceleration" - MIT (2023) - https://arxiv.org/abs/2306.00978 |
| **官方文档** | https://github.com/mit-han-lab/llm-awq |

### vLLM
| 属性 | 内容 |
|------|------|
| **简述** | 高吞吐量 LLM 推理引擎，采用 PagedAttention 技术 |
| **Wikipedia** | N/A |
| **首次论文** | "Efficient Memory Management for Large Language Model Serving with PagedAttention" - UC Berkeley (2023) - https://arxiv.org/abs/2309.06180 |
| **官方文档** | https://docs.vllm.ai/ |

### PagedAttention
| 属性 | 内容 |
|------|------|
| **简述** | 借鉴操作系统分页思想管理 KV Cache 的高效注意力机制 |
| **Wikipedia** | N/A |
| **首次论文** | "Efficient Memory Management for Large Language Model Serving with PagedAttention" - UC Berkeley (2023) - https://arxiv.org/abs/2309.06180 |
| **官方文档** | https://docs.vllm.ai/en/latest/design/kernel/paged_attention.html |

### KV Cache
| 属性 | 内容 |
|------|------|
| **简述** | 缓存 Key/Value 向量避免重复计算的推理优化技术 |
| **Wikipedia** | N/A |
| **首次论文** | Transformer 推理优化文献 |
| **官方文档** | https://huggingface.co/docs/transformers/main/en/llm_tutorial_optimization#32-the-key-value-cache |

### Continuous Batching
| 属性 | 内容 |
|------|------|
| **简述** | 动态管理推理批次的技术，提高 GPU 利用率 |
| **Wikipedia** | N/A |
| **首次论文** | "Orca: A Distributed Serving System for Transformer-Based Generative Models" - Microsoft (2022) - https://www.usenix.org/conference/osdi22/presentation/yu |
| **官方文档** | https://docs.vllm.ai/ |

### Speculative Decoding
| 属性 | 内容 |
|------|------|
| **简述** | 使用小模型预测、大模型验证的加速解码技术 |
| **Wikipedia** | N/A |
| **首次论文** | "Fast Inference from Transformers via Speculative Decoding" - Google (2023) - https://arxiv.org/abs/2211.17192 |
| **官方文档** | https://docs.vllm.ai/en/latest/features/spec_decode.html |

### Flash Attention
| 属性 | 内容 |
|------|------|
| **简述** | IO 感知的高效注意力计算算法，减少内存访问 |
| **Wikipedia** | N/A |
| **首次论文** | "FlashAttention: Fast and Memory-Efficient Exact Attention with IO-Awareness" - Stanford (2022) - https://arxiv.org/abs/2205.14135 |
| **官方文档** | https://github.com/Dao-AILab/flash-attention |

### RAG (Retrieval-Augmented Generation)
| 属性 | 内容 |
|------|------|
| **简述** | 结合检索和生成的技术，让 LLM 能访问外部知识 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Retrieval-augmented_generation |
| **首次论文** | "Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks" - Meta (2020) - https://arxiv.org/abs/2005.11401 |
| **官方文档** | https://python.langchain.com/docs/use_cases/question_answering/ |

### Vector Database
| 属性 | 内容 |
|------|------|
| **简述** | 专门存储和检索高维向量的数据库，用于语义搜索 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Vector_database |
| **首次论文** | 各向量数据库设计文档 |
| **官方文档** | https://milvus.io/docs |

### Embedding
| 属性 | 内容 |
|------|------|
| **简述** | 将文本、图像等转换为稠密向量表示的技术 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Word_embedding |
| **首次论文** | "Efficient Estimation of Word Representations in Vector Space" - Google (2013) - https://arxiv.org/abs/1301.3781 |
| **官方文档** | https://platform.openai.com/docs/guides/embeddings |

### Milvus
| 属性 | 内容 |
|------|------|
| **简述** | 开源向量数据库，专为大规模向量相似性搜索设计 |
| **Wikipedia** | N/A |
| **首次论文** | "Milvus: A Purpose-Built Vector Data Management System" - Zilliz (SIGMOD 2021) - https://dl.acm.org/doi/10.1145/3448016.3457550 |
| **官方文档** | https://milvus.io/docs |

### HNSW (Hierarchical Navigable Small World)
| 属性 | 内容 |
|------|------|
| **简述** | 高效的近似最近邻搜索算法，广泛用于向量数据库 |
| **Wikipedia** | N/A |
| **首次论文** | "Efficient and robust approximate nearest neighbor search using Hierarchical Navigable Small World graphs" - Malkov et al. (2016) - https://arxiv.org/abs/1603.09320 |
| **官方文档** | https://github.com/nmslib/hnswlib |

### TensorRT-LLM
| 属性 | 内容 |
|------|------|
| **简述** | NVIDIA 的 LLM 推理优化库，提供极低延迟推理 |
| **Wikipedia** | N/A |
| **首次论文** | NVIDIA TensorRT-LLM 设计文档 |
| **官方文档** | https://nvidia.github.io/TensorRT-LLM/ |

### Text Generation Inference (TGI)
| 属性 | 内容 |
|------|------|
| **简述** | HuggingFace 开源的生产级 LLM 推理服务器 |
| **Wikipedia** | N/A |
| **首次论文** | HuggingFace TGI 设计文档 |
| **官方文档** | https://huggingface.co/docs/text-generation-inference |

### CLIP
| 属性 | 内容 |
|------|------|
| **简述** | OpenAI 的图像-文本对比学习模型，实现跨模态语义理解 |
| **Wikipedia** | N/A |
| **首次论文** | "Learning Transferable Visual Models From Natural Language Supervision" - OpenAI (2021) - https://arxiv.org/abs/2103.00020 |
| **官方文档** | https://github.com/openai/CLIP |

### LLaVA
| 属性 | 内容 |
|------|------|
| **简述** | 大型语言和视觉助手，将视觉编码器与 LLM 结合实现视觉问答 |
| **Wikipedia** | N/A |
| **首次论文** | "Visual Instruction Tuning" - Microsoft/Wisconsin (2023) - https://arxiv.org/abs/2304.08485 |
| **官方文档** | https://llava-vl.github.io/ |

### Whisper
| 属性 | 内容 |
|------|------|
| **简述** | OpenAI 的通用语音识别模型，支持多语言转录和翻译 |
| **Wikipedia** | N/A |
| **首次论文** | "Robust Speech Recognition via Large-Scale Weak Supervision" - OpenAI (2022) - https://arxiv.org/abs/2212.04356 |
| **官方文档** | https://github.com/openai/whisper |

### Stable Diffusion
| 属性 | 内容 |
|------|------|
| **简述** | 开源的文本到图像生成模型，基于潜在扩散模型架构 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Stable_Diffusion |
| **首次论文** | "High-Resolution Image Synthesis with Latent Diffusion Models" - CompVis (2022) - https://arxiv.org/abs/2112.10752 |
| **官方文档** | https://stability.ai/stable-diffusion |

---

## 12. DevOps 工具与实践

### Helm
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 的包管理器，使用 Chart 管理应用 |
| **Wikipedia** | N/A |
| **首次论文** | Helm 设计文档 |
| **官方文档** | https://helm.sh/docs/ |

### Kustomize
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 原生的声明式配置管理工具 |
| **Wikipedia** | N/A |
| **首次论文** | Kustomize 设计文档 |
| **官方文档** | https://kustomize.io/ |

### GitOps
| 属性 | 内容 |
|------|------|
| **简述** | 使用 Git 作为单一事实来源的基础设施和应用交付方法 |
| **Wikipedia** | https://en.wikipedia.org/wiki/GitOps |
| **首次论文** | "GitOps - Operations by Pull Request" - Weaveworks (2017) |
| **官方文档** | https://www.gitops.tech/ |

### ArgoCD
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 原生的声明式 GitOps 持续交付工具 |
| **Wikipedia** | N/A |
| **首次论文** | ArgoCD 设计文档 |
| **官方文档** | https://argo-cd.readthedocs.io/ |

### Flux
| 属性 | 内容 |
|------|------|
| **简述** | 开源的 GitOps 工具集，支持 Kubernetes 的持续交付和渐进式交付 |
| **Wikipedia** | N/A |
| **首次论文** | Weaveworks Flux 设计文档 |
| **官方文档** | https://fluxcd.io/docs/ |

### Tekton
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 原生的 CI/CD 流水线框架，使用 CRD 定义构建任务 |
| **Wikipedia** | N/A |
| **首次论文** | Tekton Pipelines 设计文档 (原 Knative Build) |
| **官方文档** | https://tekton.dev/docs/ |

### Argo Rollouts
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 渐进式交付控制器，支持蓝绿部署、金丝雀发布和渐进式流量转移 |
| **Wikipedia** | N/A |
| **首次论文** | Argo Rollouts 设计文档 |
| **官方文档** | https://argoproj.github.io/argo-rollouts/ |

### Argo Workflows
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 原生的工作流引擎，支持 DAG 和并行任务编排 |
| **Wikipedia** | N/A |
| **首次论文** | Argo Workflows 设计文档 |
| **官方文档** | https://argoproj.github.io/argo-workflows/ |

### Spinnaker
| 属性 | 内容 |
|------|------|
| **简述** | Netflix 开源的多云持续交付平台，支持复杂的部署策略 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Spinnaker_(software) |
| **首次论文** | Netflix Spinnaker 设计文档 |
| **官方文档** | https://spinnaker.io/docs/ |

### Karmada
| 属性 | 内容 |
|------|------|
| **简述** | CNCF 开源的多集群联邦调度系统，支持跨集群资源分发 |
| **Wikipedia** | N/A |
| **首次论文** | Karmada 设计文档 |
| **官方文档** | https://karmada.io/docs/ |

### Rancher
| 属性 | 内容 |
|------|------|
| **简述** | 企业级 Kubernetes 管理平台，支持多集群管理和应用部署 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Rancher_Labs |
| **首次论文** | Rancher Labs 设计文档 |
| **官方文档** | https://ranchermanager.docs.rancher.com/ |

### vCluster
| 属性 | 内容 |
|------|------|
| **简述** | 在 Kubernetes 集群中创建虚拟集群的工具，实现轻量级多租户 |
| **Wikipedia** | N/A |
| **首次论文** | Loft vCluster 设计文档 |
| **官方文档** | https://www.vcluster.com/docs/ |

### Velero
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 集群备份、恢复和迁移工具 |
| **Wikipedia** | N/A |
| **首次论文** | VMware Velero 设计文档 |
| **官方文档** | https://velero.io/docs/ |

### Chaos Engineering
| 属性 | 内容 |
|------|------|
| **简述** | 通过注入故障来验证系统韧性的实践方法 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Chaos_engineering |
| **首次论文** | "Chaos Engineering" - Netflix (2017) - https://netflixtechblog.com/chaos-engineering-upgraded-878d341f15fa |
| **官方文档** | https://principlesofchaos.org/ |

### Chaos Mesh
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 原生的混沌工程平台 |
| **Wikipedia** | N/A |
| **首次论文** | Chaos Mesh 设计文档 |
| **官方文档** | https://chaos-mesh.org/docs/ |

### HPA (Horizontal Pod Autoscaler)
| 属性 | 内容 |
|------|------|
| **简述** | 根据 CPU/内存等指标自动调整 Pod 副本数的控制器 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/ |

### VPA (Vertical Pod Autoscaler)
| 属性 | 内容 |
|------|------|
| **简述** | 根据历史使用情况自动调整 Pod 资源请求的组件 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes VPA 设计文档 |
| **官方文档** | https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler |

### Cluster Autoscaler
| 属性 | 内容 |
|------|------|
| **简述** | 根据 Pod 资源需求自动调整集群节点数量 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes Cluster Autoscaler 设计文档 |
| **官方文档** | https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler |

### KEDA (Kubernetes Event-driven Autoscaling)
| 属性 | 内容 |
|------|------|
| **简述** | 基于事件驱动的自动扩缩容组件，支持从 0 扩展和多种事件源 |
| **Wikipedia** | N/A |
| **首次论文** | Microsoft/Red Hat KEDA 设计文档 |
| **官方文档** | https://keda.sh/docs/ |

### Descheduler
| 属性 | 内容 |
|------|------|
| **简述** | 根据策略重新平衡集群中 Pod 分布的组件 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes SIG-Scheduling Descheduler 设计文档 |
| **官方文档** | https://github.com/kubernetes-sigs/descheduler |

### node-problem-detector
| 属性 | 内容 |
|------|------|
| **简述** | 检测节点问题（内核死锁、容器运行时异常等）并上报的守护进程 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes node-problem-detector 设计文档 |
| **官方文档** | https://github.com/kubernetes/node-problem-detector |

### PodDisruptionBudget (PDB)
| 属性 | 内容 |
|------|------|
| **简述** | 限制主动中断时同时不可用 Pod 数量的策略 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/run-application/configure-pdb/ |

### ResourceQuota
| 属性 | 内容 |
|------|------|
| **简述** | 限制命名空间内资源使用总量的配额机制 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/policy/resource-quotas/ |

### LimitRange
| 属性 | 内容 |
|------|------|
| **简述** | 限制单个 Pod/容器资源请求范围的策略 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/policy/limit-range/ |

### Lease
| 属性 | 内容 |
|------|------|
| **简述** | 用于分布式锁和 Leader 选举的轻量级 Kubernetes 对象 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/architecture/leases/ |

### Kubecost
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 成本监控和优化平台，提供实时成本可视化和分配 |
| **Wikipedia** | N/A |
| **首次论文** | Kubecost 设计文档 |
| **官方文档** | https://docs.kubecost.com/ |

### FinOps
| 属性 | 内容 |
|------|------|
| **简述** | 云财务管理实践，通过工程、财务和业务协作优化云支出 |
| **Wikipedia** | https://en.wikipedia.org/wiki/FinOps |
| **首次论文** | FinOps Foundation 框架文档 |
| **官方文档** | https://www.finops.org/framework/ |

### External DNS
| 属性 | 内容 |
|------|------|
| **简述** | 自动同步 Kubernetes Service/Ingress 到外部 DNS 提供商的控制器 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes SIG-Network External DNS 设计文档 |
| **官方文档** | https://kubernetes-sigs.github.io/external-dns/ |

### Crossplane
| 属性 | 内容 |
|------|------|
| **简述** | 使用 Kubernetes API 管理云基础设施的开源控制平面框架 |
| **Wikipedia** | N/A |
| **首次论文** | Upbound Crossplane 设计文档 |
| **官方文档** | https://docs.crossplane.io/ |

### Terraform
| 属性 | 内容 |
|------|------|
| **简述** | HashiCorp 开源的基础设施即代码工具，支持多云环境 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Terraform_(software) |
| **首次论文** | HashiCorp Terraform 设计文档 |
| **官方文档** | https://developer.hashicorp.com/terraform/docs |

### Kaniko
| 属性 | 内容 |
|------|------|
| **简述** | 在 Kubernetes 中无 Docker daemon 构建容器镜像的工具 |
| **Wikipedia** | N/A |
| **首次论文** | Google Kaniko 设计文档 |
| **官方文档** | https://github.com/GoogleContainerTools/kaniko |

### Buildah
| 属性 | 内容 |
|------|------|
| **简述** | 无守护进程的 OCI 容器镜像构建工具，支持 rootless 构建 |
| **Wikipedia** | N/A |
| **首次论文** | Red Hat Buildah 设计文档 |
| **官方文档** | https://buildah.io/ |

### BuildKit
| 属性 | 内容 |
|------|------|
| **简述** | Docker 下一代构建引擎，支持并行构建、缓存优化和多平台构建 |
| **Wikipedia** | N/A |
| **首次论文** | Moby BuildKit 设计文档 |
| **官方文档** | https://docs.docker.com/build/buildkit/ |

### Harbor
| 属性 | 内容 |
|------|------|
| **简述** | 企业级容器镜像仓库，支持镜像签名、漏洞扫描和 RBAC，CNCF 毕业项目 |
| **Wikipedia** | N/A |
| **首次论文** | VMware Harbor 设计文档 |
| **官方文档** | https://goharbor.io/docs/ |

### Skopeo
| 属性 | 内容 |
|------|------|
| **简述** | 容器镜像和仓库操作工具，支持跨仓库复制和镜像检查 |
| **Wikipedia** | N/A |
| **首次论文** | Red Hat Skopeo 设计文档 |
| **官方文档** | https://github.com/containers/skopeo |

### Podman
| 属性 | 内容 |
|------|------|
| **简述** | 无守护进程的容器引擎，兼容 Docker CLI，支持 rootless 容器 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Podman |
| **首次论文** | Red Hat Podman 设计文档 |
| **官方文档** | https://podman.io/docs/ |

### Cloud Native Buildpacks
| 属性 | 内容 |
|------|------|
| **简述** | 将源代码转换为 OCI 镜像的标准化方法，无需 Dockerfile |
| **Wikipedia** | N/A |
| **首次论文** | CNCF Buildpacks 设计文档 |
| **官方文档** | https://buildpacks.io/docs/ |

---

## 参考资源

### 官方文档
- [Kubernetes 官方文档](https://kubernetes.io/docs/)
- [CNCF 项目列表](https://www.cncf.io/projects/)
- [Hugging Face 文档](https://huggingface.co/docs)

### 学术资源
- [arXiv.org](https://arxiv.org/) - 预印本论文库
- [Papers With Code](https://paperswithcode.com/) - 论文与代码对照
- [Google Scholar](https://scholar.google.com/)

### 社区资源
- [CNCF Slack](https://slack.cncf.io/)
- [Kubernetes GitHub](https://github.com/kubernetes/kubernetes)
- [KubeCon 会议录像](https://www.youtube.com/c/CloudNativeComputingFoundation)

---

*文档生成时间: 2026-01-21*
*涵盖概念数量: 206*
