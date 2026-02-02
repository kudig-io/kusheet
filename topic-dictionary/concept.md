# Kubernetes 与 AI/ML 概念参考手册（完整恢复版）

> 本文档包含kusheet项目涉及的300+核心技术概念，涵盖Kubernetes、分布式系统、AI/ML、DevOps等领域的完整知识体系。

---

## 目录

1. [Kubernetes 核心概念](#1-kubernetes-核心概念)
2. [API 与认证机制](#2-api-与认证机制)
3. [控制平面组件](#3-控制平面组件)
4. [数据平面组件](#4-数据平面组件)
5. [工作负载资源](#5-工作负载资源)
6. [网络与服务发现](#6-网络与服务发现)
7. [存储管理](#7-存储管理)
8. [安全与权限控制](#8-安全与权限控制)
9. [可观测性与监控](#9-可观测性与监控)
10. [分布式系统理论](#10-分布式系统理论)
11. [设计模式与架构](#11-设计模式与架构)
12. [AI/ML 工程概念](#12-aiml-工程概念)
13. [LLM 特有概念](#13-llm-特有概念)
14. [DevOps 工具与实践](#14-devops-工具与实践)
15. [补充技术概念](#15-补充技术概念)

---

## 1. Kubernetes 核心概念

### 概念解释

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

### Label
| 属性 | 内容 |
|------|------|
| **简述** | 附加到对象上的键值对，用于组织和选择对象 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Labels |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |

### Annotation
| 属性 | 内容 |
|------|------|
| **简述** | 用于存储非标识性元数据的键值对 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Annotations |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |

### Taint
| 属性 | 内容 |
|------|------|
| **简述** | 应用到节点上的污点，用于排斥某些 Pod |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Taints_and_Tolerations |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ |

### Toleration
| 属性 | 内容 |
|------|------|
| **简述** | Pod 对节点污点的容忍度设置 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Taints_and_Tolerations |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ |

### Affinity
| 属性 | 内容 |
|------|------|
| **简述** | Pod 亲和性规则，控制 Pod 调度偏好 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Affinity |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity |

### Anti-Affinity
| 属性 | 内容 |
|------|------|
| **简述** | Pod 反亲和性规则，避免 Pod 调度到特定节点 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Affinity |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity |

### Resource Quota
| 属性 | 内容 |
|------|------|
| **简述** | 限制命名空间中对象使用的计算资源总量 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Resource_quotas |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/policy/resource-quotas/ |

### Limit Range
| 属性 | 内容 |
|------|------|
| **简述** | 限制单个容器或 Pod 可以使用的资源量 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Limit_ranges |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/policy/limit-range/ |

### QoS Class
| 属性 | 内容 |
|------|------|
| **简述** | Pod 的服务质量等级：Guaranteed、Burstable、BestEffort |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Quality_of_Service |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/configure-pod-container/quality-service-pod/ |

### Control Plane
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 控制平面，包含管理集群状态的核心组件 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Control_plane |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/components/#control-plane-components |

### Data Plane
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 数据平面，运行工作负载的节点组件 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Node_components |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/components/#node-components |

### Master Node
| 属性 | 内容 |
|------|------|
| **简述** | 运行控制平面组件的节点，负责集群管理 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Control_plane |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/components/#control-plane-components |

### Worker Node
| 属性 | 内容 |
|------|------|
| **简述** | 运行工作负载的节点，承载 Pod 和容器 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Node_components |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/architecture/nodes/ |

### Cluster
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 集群，包含控制平面和工作节点的完整系统 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes |
| **首次论文** | "Large-scale cluster management at Google with Borg" (EuroSys 2015) |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/components/ |

### 工具解释

#### kubectl
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 命令行工具，用于与集群进行交互 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubectl |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/kubectl/ |

#### minikube
| 属性 | 内容 |
|------|------|
| **简述** | 本地 Kubernetes 环境，用于开发和测试 |
| **Wikipedia** | N/A |
| **首次论文** | minikube 项目文档 |
| **官方文档** | https://minikube.sigs.k8s.io/docs/ |

#### kubeadm
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 集群部署工具，用于快速搭建生产环境 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/setup-tools/kubeadm/ |

---

## 2. API 与认证机制

### 概念解释

#### API Server
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes API 服务器，提供 REST API 接口，是整个系统的统一入口和数据中心 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#API_server |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/ |

### Authentication
| 属性 | 内容 |
|------|------|
| **简述** | 身份验证机制，验证用户或服务的身份 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Authentication |
| **首次论文** | 计算机安全身份验证相关文献 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/authentication/ |

### Authorization
| 属性 | 内容 |
|------|------|
| **简述** | 授权机制，控制经过认证的主体可以执行的操作 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Authorization |
| **首次论文** | 访问控制相关文献 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/authorization/ |

### Certificate
| 属性 | 内容 |
|------|------|
| **简述** | PKI 证书，用于 Kubernetes 组件间 TLS 加密通信 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Public_key_certificate |
| **首次论文** | PKI (Public Key Infrastructure) 相关文献 |
| **官方文档** | https://kubernetes.io/docs/setup/best-practices/certificates/ |

### TLS
| 属性 | 内容 |
|------|------|
| **简述** | 传输层安全协议，为 Kubernetes 组件提供加密通信 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Transport_Layer_Security |
| **首次论文** | TLS 协议 RFC 5246 |
| **官方文档** | https://kubernetes.io/docs/concepts/security/controlling-access/#transport-security |

### SSL
| 属性 | 内容 |
|------|------|
| **简述** | 安全套接字层协议，TLS 的前身，用于加密网络通信 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Transport_Layer_Security |
| **首次论文** | SSL 协议相关文献 |
| **官方文档** | https://kubernetes.io/docs/concepts/security/controlling-access/ |

### Token
| 属性 | 内容 |
|------|------|
| **简述** | 访问令牌，用于 API 认证和授权 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Access_token |
| **首次论文** | OAuth 2.0 相关文献 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/authentication/#service-account-tokens |

### Admission Controller
| 属性 | 内容 |
|------|------|
| **简述** | 在对象持久化之前拦截请求并进行修改或验证的插件机制 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes Admission Control 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/ |

### Webhook
| 属性 | 内容 |
|------|------|
| **简述** | Web 钩子，用于扩展 Kubernetes API 行为 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Webhook |
| **首次论文** | Kubernetes Webhook 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/ |

### Validation
| 属性 | 内容 |
|------|------|
| **简述** | 验证机制，检查资源配置是否符合要求 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 准入控制设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#validatingadmissionwebhook |

### Mutation
| 属性 | 内容 |
|------|------|
| **简述** | 变更机制，在资源持久化前修改其配置 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 准入控制设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#mutatingadmissionwebhook |

### Audit
| 属性 | 内容 |
|------|------|
| **简述** | 审计日志，记录 Kubernetes API 的所有操作 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 审计系统设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/ |

### API Aggregation
| 属性 | 内容 |
|------|------|
| **简述** | API 聚合机制，扩展 Kubernetes API 的方式 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes API Aggregation 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/apiserver-aggregation/ |

### Custom Resource Definition (CRD)
| 属性 | 内容 |
|------|------|
| **简述** | 自定义资源定义，扩展 Kubernetes API 的标准方式 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes CRD 设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/ |

### OpenAPI
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes API 的 OpenAPI 规范定义 |
| **Wikipedia** | https://en.wikipedia.org/wiki/OpenAPI_Specification |
| **首次论文** | OpenAPI 规范文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/kubernetes-api/ |

### Webhook
| 属性 | 内容 |
|------|------|
| **简述** | Web 钩子，用于扩展 Kubernetes API 行为 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Webhook |
| **首次论文** | Kubernetes Webhook 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/ |

### Validation
| 属性 | 内容 |
|------|------|
| **简述** | 验证机制，检查资源配置是否符合要求 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 准入控制设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#validatingadmissionwebhook |

### Mutation
| 属性 | 内容 |
|------|------|
| **简述** | 变更机制，在资源持久化前修改其配置 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 准入控制设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#mutatingadmissionwebhook |

### Audit
| 属性 | 内容 |
|------|------|
| **简述** | 审计日志，记录 Kubernetes API 的所有操作 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 审计系统设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/ |

### API Aggregation
| 属性 | 内容 |
|------|------|
| **简述** | API 聚合机制，扩展 Kubernetes API 的方式 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes API Aggregation 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/apiserver-aggregation/ |

### Custom Resource Definition (CRD)
| 属性 | 内容 |
|------|------|
| **简述** | 自定义资源定义，扩展 Kubernetes API 的标准方式 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes CRD 设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/ |

### OpenAPI
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes API 的 OpenAPI 规范定义 |
| **Wikipedia** | https://en.wikipedia.org/wiki/OpenAPI_Specification |
| **首次论文** | OpenAPI 规范文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/overview/kubernetes-api/ |

### 工具解释

#### kubectl api-resources
| 属性 | 内容 |
|------|------|
| **简述** | 查看 Kubernetes API 资源类型的命令 |
| **Wikipedia** | N/A |
| **首次论文** | kubectl 工具文档 |
| **官方文档** | https://kubernetes.io/docs/reference/kubectl/generated/kubectl_api-resources/ |

#### kubectl auth can-i
| 属性 | 内容 |
|------|------|
| **简述** | 检查用户是否有特定权限的命令 |
| **Wikipedia** | N/A |
| **首次论文** | kubectl 权限检查工具文档 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/authorization/ |

#### cfssl
| 属性 | 内容 |
|------|------|
| **简述** | CloudFlare 开发的 PKI 工具，用于生成和管理证书 |
| **Wikipedia** | N/A |
| **首次论文** | cfssl 项目文档 |
| **官方文档** | https://github.com/cloudflare/cfssl |

---

## 3. 控制平面组件

### 概念解释

#### Controller
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 中负责维护系统期望状态的控制组件，通过持续调谐驱动实际状态向期望状态收敛 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Controllers |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/architecture/controller/ |

### Scheduler
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 默认调度器，负责将 Pod 调度到合适的节点上运行 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Scheduler |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/ |

### etcd
| 属性 | 内容 |
|------|------|
| **简述** | 基于 Raft 算法的分布式键值存储，作为 Kubernetes 的核心数据存储 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Etcd |
| **首次论文** | CoreOS etcd 项目文档 |
| **官方文档** | https://etcd.io/docs/ |

### kube-apiserver
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes API 服务器，提供 REST API 接口和认证授权功能 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Components |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/ |

### kube-controller-manager
| 属性 | 内容 |
|------|------|
| **简述** | 运行核心控制器进程的组件，包括节点控制器、副本控制器等 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Components |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/ |

### kube-scheduler
| 属性 | 内容 |
|------|------|
| **简述** | 负责将 Pod 调度到合适的节点上的核心调度器 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Components |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/command-line-tools-reference/kube-scheduler/ |

### cloud-controller-manager
| 属性 | 内容 |
|------|------|
| **简述** | 与云提供商交互的控制器管理器，管理云特定的控制器 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Components |
| **首次论文** | Kubernetes Cloud Provider 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/command-line-tools-reference/cloud-controller-manager/ |

### Leader Election
| 属性 | 内容 |
|------|------|
| **简述** | 控制平面组件的领导者选举机制，确保高可用性 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Leader_election |
| **首次论文** | 分布式系统领导者选举算法 |
| **官方文档** | https://kubernetes.io/docs/concepts/architecture/leases/ |

### Lease
| 属性 | 内容 |
|------|------|
| **简述** | 用于实现领导者选举和心跳检测的资源对象 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes Lease 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/architecture/leases/ |

### Health Check
| 属性 | 内容 |
|------|------|
| **简述** | 组件健康检查机制，监控控制平面组件状态 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Health_check |
| **首次论文** | 系统可靠性设计文献 |
| **官方文档** | https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/ |

### Reconciliation Loop
| 属性 | 内容 |
|------|------|
| **简述** | 控制器的核心工作机制，持续调谐实际状态向期望状态收敛 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Control_loop |
| **首次论文** | Kubernetes 控制器模式设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/architecture/controller/ |

### Informer
| 属性 | 内容 |
|------|------|
| **简述** | 基于 List-Watch 机制的客户端缓存组件，减小 API Server 压力 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes client-go 设计文档 |
| **官方文档** | https://pkg.go.dev/k8s.io/client-go/informers |

### WorkQueue
| 属性 | 内容 |
|------|------|
| **简述** | 控制器中用于存储待处理资源 key 的队列，支持去重和限速 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes client-go 设计文档 |
| **官方文档** | https://pkg.go.dev/k8s.io/client-go/util/workqueue |

### Watch-List 机制
| 属性 | 内容 |
|------|------|
| **简述** | 通过建立长连接持续监听资源变化的高效数据同步机制 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/using-api/api-concepts/#watch |

### Client-Go
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes Go 语言客户端库，提供 API 访问和工具组件 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes client-go 设计文档 |
| **官方文档** | https://github.com/kubernetes/client-go |

### Controller Runtime
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 控制器开发框架，简化 Operator 开发 |
| **Wikipedia** | N/A |
| **首次论文** | Controller Runtime 项目文档 |
| **官方文档** | https://pkg.go.dev/sigs.k8s.io/controller-runtime |

### KubeBuilder
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes API 开发工具包，用于构建自定义控制器 |
| **Wikipedia** | N/A |
| **首次论文** | KubeBuilder 项目文档 |
| **官方文档** | https://book.kubebuilder.io/ |

### 工具解释

#### kube-controller-manager
| 属性 | 内容 |
|------|------|
| **简述** | 控制器管理器二进制文件，运行各种核心控制器 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 控制器设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/ |

#### kube-scheduler
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 调度器二进制文件，负责 Pod 调度决策 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 调度器设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/command-line-tools-reference/kube-scheduler/ |

#### etcdctl
| 属性 | 内容 |
|------|------|
| **简述** | etcd 命令行客户端工具，用于管理 etcd 集群 |
| **Wikipedia** | N/A |
| **首次论文** | etcd 项目文档 |
| **官方文档** | https://etcd.io/docs/latest/dev-guide/interacting_v3/ |

#### Raft Consensus
| 属性 | 内容 |
|------|------|
| **简述** | 分布式系统共识算法，etcd 使用的核心算法 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Raft_(algorithm) |
| **首次论文** | "In Search of an Understandable Consensus Algorithm" - Diego Ongaro (ATC 2014) |
| **官方文档** | https://raft.github.io/ |

#### MVCC (Multi-Version Concurrency Control)
| 属性 | 内容 |
|------|------|
| **简述** | 多版本并发控制，etcd 存储引擎的核心技术 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Multiversion_concurrency_control |
| **首次论文** | "Concurrency Control in Distributed Database Systems" - P.A. Bernstein (ACM Computing Surveys 1981) |
| **官方文档** | https://etcd.io/docs/v3.5/learning/data_model/ |

#### WAL (Write-Ahead Log)
| 属性 | 内容 |
|------|------|
| **简述** | 预写式日志，etcd 持久化数据变更的核心机制 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Write-ahead_logging |
| **首次论文** | 数据库存储系统相关文献 |
| **官方文档** | https://etcd.io/docs/v3.5/learning/design-client/ |

#### Snapshot
| 属性 | 内容 |
|------|------|
| **简述** | 快照机制，定期保存 etcd 状态以压缩日志 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Snapshot_(computer_storage) |
| **首次论文** | 分布式系统快照算法 |
| **官方文档** | https://etcd.io/docs/v3.5/op-guide/maintenance/ |

#### BoltDB
| 属性 | 内容 |
|------|------|
| **简述** | 嵌入式键值数据库，etcd 的持久化存储后端 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Bolt_(key/value_database) |
| **首次论文** | BoltDB 项目文档 |
| **官方文档** | https://github.com/boltdb/bolt |

#### gRPC
| 属性 | 内容 |
|------|------|
| **简述** | 高性能 RPC 框架，etcd 客户端通信协议 |
| **Wikipedia** | https://en.wikipedia.org/wiki/GRPC |
| **首次论文** | gRPC 设计文档 |
| **官方文档** | https://grpc.io/docs/ |

#### Lease
| 属性 | 内容 |
|------|------|
| **简述** | 租约机制，用于实现 TTL 和心跳检测 |
| **Wikipedia** | N/A |
| **首次论文** | 分布式系统租约算法 |
| **官方文档** | https://etcd.io/docs/v3.5/dev-guide/interacting_v3/#lease-grant |

#### Compaction
| 属性 | 内容 |
|------|------|
| **简述** | 压缩机制，清理历史版本以回收存储空间 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Data_compaction |
| **首次论文** | 数据库压缩算法 |
| **官方文档** | https://etcd.io/docs/v3.5/op-guide/maintenance/#auto-compaction |

#### API Aggregation
| 属性 | 内容 |
|------|------|
| **简述** | API 聚合机制，扩展 Kubernetes API 的方式 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes API Aggregation 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/apiserver-aggregation/ |

#### Audit Logging
| 属性 | 内容 |
|------|------|
| **简述** | 审计日志，记录 Kubernetes API 的所有操作 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 审计系统设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/ |

#### Rate Limiting
| 属性 | 内容 |
|------|------|
| **简述** | 限流机制，防止 API Server 过载 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Rate_limiting |
| **首次论文** | 分布式系统限流算法 |
| **官方文档** | https://kubernetes.io/docs/concepts/cluster-administration/flow-control/ |

#### API Priority and Fairness (APF)
| 属性 | 内容 |
|------|------|
| **简述** | API 优先级和公平性机制，确保关键请求优先处理 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes APF 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/cluster-administration/flow-control/ |

#### Deployment
| 属性 | 内容 |
|------|------|
| **简述** | 无状态应用的部署控制器，管理Pod副本和滚动更新 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Deployments |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/controllers/deployment/ |

#### StatefulSet
| 属性 | 内容 |
|------|------|
| **简述** | 有状态应用的控制器，提供稳定的网络标识和持久化存储 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#StatefulSets |
| **首次论文** | Kubernetes StatefulSet 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/ |

#### DaemonSet
| 属性 | 内容 |
|------|------|
| **简述** | 确保每个节点运行一个Pod副本的控制器 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#DaemonSets |
| **首次论文** | Kubernetes DaemonSet 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/ |

#### Job
| 属性 | 内容 |
|------|------|
| **简述** | 批处理任务控制器，运行完成后自动终止 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Jobs |
| **首次论文** | Kubernetes Job 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/controllers/job/ |

#### CronJob
| 属性 | 内容 |
|------|------|
| **简述** | 定时任务控制器，基于cron表达式周期性执行Job |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#CronJobs |
| **首次论文** | Kubernetes CronJob 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/ |

#### Service
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 服务发现和负载均衡抽象 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Services |
| **首次论文** | Kubernetes Service 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/service/ |

#### ClusterIP
| 属性 | 内容 |
|------|------|
| **简述** | Service 的默认类型，在集群内部提供虚拟IP服务 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes Service 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types |

#### NodePort
| 属性 | 内容 |
|------|------|
| **简述** | 通过节点端口暴露Service的服务类型 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes Service 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/service/#nodeport |

#### LoadBalancer
| 属性 | 内容 |
|------|------|
| **简述** | 通过云提供商负载均衡器暴露Service |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes Service 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer |

#### Headless Service
| 属性 | 内容 |
|------|------|
| **简述** | 不分配ClusterIP的Service，直接返回Pod IPs |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes Service 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/service/#headless-services |

#### Ingress
| 属性 | 内容 |
|------|------|
| **简述** | HTTP/HTTPS 路由规则管理器，提供七层负载均衡 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Ingress_(Kubernetes) |
| **首次论文** | Kubernetes Ingress 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/ingress/ |

#### NetworkPolicy
| 属性 | 内容 |
|------|------|
| **简述** | 网络策略，控制Pod之间的网络通信 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes NetworkPolicy 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/network-policies/ |

#### CNI (Container Network Interface)
| 属性 | 内容 |
|------|------|
| **简述** | 容器网络接口标准，定义容器网络插件规范 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Container_Network_Interface |
| **首次论文** | CNI 规范文档 |
| **官方文档** | https://github.com/containernetworking/cni |

#### CoreDNS
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 集群DNS服务，提供服务发现功能 |
| **Wikipedia** | https://en.wikipedia.org/wiki/CoreDNS |
| **首次论文** | CoreDNS 项目文档 |
| **官方文档** | https://coredns.io/ |

#### kube-proxy
| 属性 | 内容 |
|------|------|
| **简述** | 运行在每个节点上的网络代理，维护网络规则 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Components |
| **首次论文** | Kubernetes 网络设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/ |

#### PersistentVolume (PV)
| 属性 | 内容 |
|------|------|
| **简述** | 集群级存储资源，定义存储的容量、访问模式等属性 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Volumes |
| **首次论文** | Kubernetes 存储设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/persistent-volumes/ |

#### PersistentVolumeClaim (PVC)
| 属性 | 内容 |
|------|------|
| **简述** | 命名空间级存储请求，用户申请存储资源的接口 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Volumes |
| **首次论文** | Kubernetes 存储设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/persistent-volumes/ |

#### StorageClass
| 属性 | 内容 |
|------|------|
| **简述** | 存储类，定义动态卷供给的模板和参数 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes StorageClass 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/storage-classes/ |

#### CSI (Container Storage Interface)
| 属性 | 内容 |
|------|------|
| **简述** | 容器存储接口标准，定义存储插件的统一接口 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Container_Storage_Interface |
| **首次论文** | CSI 规范文档 |
| **官方文档** | https://kubernetes-csi.github.io/docs/ |

#### Access Modes
| 属性 | 内容 |
|------|------|
| **简述** | 存储访问模式，定义存储卷的读写权限和并发访问能力 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 存储设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes |

#### Reclaim Policy
| 属性 | 内容 |
|------|------|
| **简述** | PV回收策略，定义PVC删除后PV的处理方式 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 存储设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/persistent-volumes/#reclaiming |

#### VolumeSnapshot
| 属性 | 内容 |
|------|------|
| **简述** | 存储卷快照，用于数据备份和恢复 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes VolumeSnapshot 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/volume-snapshots/ |

#### RBAC (Role-Based Access Control)
| 属性 | 内容 |
|------|------|
| **简述** | 基于角色的访问控制，Kubernetes 的授权机制 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Role-based_access_control |
| **首次论文** | RBAC 相关文献 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/rbac/ |

#### Pod Security Standards
| 属性 | 内容 |
|------|------|
| **简述** | Pod 安全标准，定义容器安全基线 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes Pod Security 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/security/pod-security-standards/ |

#### NetworkPolicy
| 属性 | 内容 |
|------|------|
| **简述** | 网络策略，控制Pod之间的网络通信 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes NetworkPolicy 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/network-policies/ |

#### Secrets
| 属性 | 内容 |
|------|------|
| **简述** | 敏感信息存储对象，用于保存密码、token等 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Secrets |
| **首次论文** | Kubernetes Secrets 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/configuration/secret/ |

#### ServiceAccount
| 属性 | 内容 |
|------|------|
| **简述** | 服务账户，为Pod提供身份认证 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Service_accounts |
| **首次论文** | Kubernetes ServiceAccount 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/ |

#### Admission Control
| 属性 | 内容 |
|------|------|
| **简述** | 准入控制，拦截并验证或修改API请求 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes Admission Control 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/ |

#### PodSecurityPolicy (PSP)
| 属性 | 内容 |
|------|------|
| **简述** | Pod安全策略，已弃用的安全控制机制 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes PSP 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/security/pod-security-policy/ |

#### EncryptionConfiguration
| 属性 | 内容 |
|------|------|
| **简述** | 加密配置，用于etcd中敏感数据的加密 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 加密设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/ |

#### Audit Logs
| 属性 | 内容 |
|------|------|
| **简述** | 审计日志，记录Kubernetes API的所有操作 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 审计系统设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/ |

#### Prometheus
| 属性 | 内容 |
|------|------|
| **简述** | 开源监控和告警工具包，用于收集和查询指标 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Prometheus_(software) |
| **首次论文** | Prometheus 项目文档 |
| **官方文档** | https://prometheus.io/docs/introduction/overview/ |

#### Grafana
| 属性 | 内容 |
|------|------|
| **简述** | 开源可视化平台，用于展示监控数据和指标 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Grafana |
| **首次论文** | Grafana 项目文档 |
| **官方文档** | https://grafana.com/docs/grafana/latest/ |

#### Alertmanager
| 属性 | 内容 |
|------|------|
| **简述** | Prometheus 告警管理器，处理和路由告警 |
| **Wikipedia** | N/A |
| **首次论文** | Prometheus Alertmanager 文档 |
| **官方文档** | https://prometheus.io/docs/alerting/latest/alertmanager/ |

#### kube-state-metrics
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 集群状态指标收集器 |
| **Wikipedia** | N/A |
| **首次论文** | kube-state-metrics 项目文档 |
| **官方文档** | https://github.com/kubernetes/kube-state-metrics |

#### node-exporter
| 属性 | 内容 |
|------|------|
| **简述** | 节点级系统指标收集器 |
| **Wikipedia** | N/A |
| **首次论文** | Prometheus node_exporter 文档 |
| **官方文档** | https://github.com/prometheus/node_exporter |

#### cAdvisor
| 属性 | 内容 |
|------|------|
| **简述** | 容器资源使用和性能分析代理 |
| **Wikipedia** | https://en.wikipedia.org/wiki/CAdvisor |
| **首次论文** | cAdvisor 项目文档 |
| **官方文档** | https://github.com/google/cadvisor |

#### Fluentd
| 属性 | 内容 |
|------|------|
| **简述** | 开源数据收集器，用于统一日志层 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Fluentd |
| **首次论文** | Fluentd 项目文档 |
| **官方文档** | https://docs.fluentd.org/ |

#### Elasticsearch
| 属性 | 内容 |
|------|------|
| **简述** | 分布式搜索和分析引擎，用于日志存储和检索 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Elasticsearch |
| **首次论文** | Elasticsearch 项目文档 |
| **官方文档** | https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html |

#### Kibana
| 属性 | 内容 |
|------|------|
| **简述** | Elasticsearch 的可视化界面 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kibana |
| **首次论文** | Kibana 项目文档 |
| **官方文档** | https://www.elastic.co/guide/en/kibana/current/index.html |

#### CRD (Custom Resource Definition)
| 属性 | 内容 |
|------|------|
| **简述** | 自定义资源定义，扩展Kubernetes API的标准方式 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes CRD 设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/ |

#### Operator
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 应用管理自动化模式 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Operator_(software) |
| **首次论文** | CoreOS Operator Pattern |
| **官方文档** | https://operatorframework.io/ |

#### Helm
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 包管理器，用于应用部署和管理 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Helm_(software) |
| **首次论文** | Helm 项目文档 |
| **官方文档** | https://helm.sh/docs/ |

#### ArgoCD
| 属性 | 内容 |
|------|------|
| **简述** | GitOps 持续交付工具，基于声明式配置管理 |
| **Wikipedia** | N/A |
| **首次论文** | ArgoCD 项目文档 |
| **官方文档** | https://argo-cd.readthedocs.io/ |

#### Flux
| 属性 | 内容 |
|------|------|
| **简述** | CNCF孵化项目的GitOps工具 |
| **Wikipedia** | N/A |
| **首次论文** | Flux 项目文档 |
| **官方文档** | https://fluxcd.io/docs/ |

#### Tekton
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 原生CI/CD框架 |
| **Wikipedia** | N/A |
| **首次论文** | Tekton 项目文档 |
| **官方文档** | https://tekton.dev/docs/ |

#### Velero
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 集群备份和灾难恢复工具 |
| **Wikipedia** | N/A |
| **首次论文** | Velero 项目文档 |
| **官方文档** | https://velero.io/docs/ |

#### KubeVirt
| 属性 | 内容 |
|------|------|
| **简述** | 在Kubernetes上运行虚拟机 |
| **Wikipedia** | N/A |
| **首次论文** | KubeVirt 项目文档 |
| **官方文档** | https://kubevirt.io/user-guide/ |

#### Volcano
| 属性 | 内容 |
|------|------|
| **简述** | AI/大数据场景的批处理调度器 |
| **Wikipedia** | N/A |
| **首次论文** | Volcano 项目文档 |
| **官方文档** | https://volcano.sh/ |

#### Kubeflow
| 属性 | 内容 |
|------|------|
| **简述** | 机器学习工具包，在Kubernetes上部署ML工作流 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubeflow |
| **首次论文** | Kubeflow 项目文档 |
| **官方文档** | https://www.kubeflow.org/docs/ |

#### PyTorchJob
| 属性 | 内容 |
|------|------|
| **简述** | Kubeflow中用于PyTorch分布式训练的CRD |
| **Wikipedia** | N/A |
| **首次论文** | Kubeflow PyTorch Operator 文档 |
| **官方文档** | https://www.kubeflow.org/docs/components/training/pytorch/ |

#### TFJob
| 属性 | 内容 |
|------|------|
| **简述** | Kubeflow中用于TensorFlow分布式训练的CRD |
| **Wikipedia** | N/A |
| **首次论文** | Kubeflow TensorFlow Operator 文档 |
| **官方文档** | https://www.kubeflow.org/docs/components/training/tftraining/ |

#### MPIJob
| 属性 | 内容 |
|------|------|
| **简述** | Kubeflow中用于MPI分布式训练的CRD |
| **Wikipedia** | N/A |
| **首次论文** | Kubeflow MPI Operator 文档 |
| **官方文档** | https://www.kubeflow.org/docs/components/training/mpi/ |

#### Ray
| 属性 | 内容 |
|------|------|
| **简述** | 分布式计算框架，用于AI和数据分析 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Ray_(software) |
| **首次论文** | Ray: A Distributed Framework for Emerging AI Applications |
| **官方文档** | https://docs.ray.io/ |

#### MLflow
| 属性 | 内容 |
|------|------|
| **简述** | 机器学习生命周期管理平台 |
| **Wikipedia** | https://en.wikipedia.org/wiki/MLflow |
| **首次论文** | MLflow 项目文档 |
| **官方文档** | https://mlflow.org/docs/latest/index.html |

#### Triton Inference Server
| 属性 | 内容 |
|------|------|
| **简述** | NVIDIA推理服务，支持多种ML框架 |
| **Wikipedia** | N/A |
| **首次论文** | Triton Inference Server 文档 |
| **官方文档** | https://github.com/triton-inference-server/server |

#### vLLM
| 属性 | 内容 |
|------|------|
| **简述** | 大语言模型推理加速库 |
| **Wikipedia** | N/A |
| **首次论文** | vLLM: Easy, Fast, and Cheap LLM Serving with PagedAttention |
| **官方文档** | https://github.com/vllm-project/vllm |

#### kubectl describe
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 资源详细信息查看命令 |
| **Wikipedia** | N/A |
| **首次论文** | kubectl 工具文档 |
| **官方文档** | https://kubernetes.io/docs/reference/kubectl/generated/kubectl_describe/ |

#### kubectl logs
| 属性 | 内容 |
|------|------|
| **简述** | 查看Pod容器日志的命令 |
| **Wikipedia** | N/A |
| **首次论文** | kubectl 工具文档 |
| **官方文档** | https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/ |

#### kubectl exec
| 属性 | 内容 |
|------|------|
| **简述** | 在运行中的容器内执行命令 |
| **Wikipedia** | N/A |
| **首次论文** | kubectl 工具文档 |
| **官方文档** | https://kubernetes.io/docs/reference/kubectl/generated/kubectl_exec/ |

#### kubectl debug
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 故障调试工具 |
| **Wikipedia** | N/A |
| **首次论文** | kubectl debug 工具文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/ |

#### stern
| 属性 | 内容 |
|------|------|
| **简述** | 多Pod日志查看工具 |
| **Wikipedia** | N/A |
| **首次论文** | stern 项目文档 |
| **官方文档** | https://github.com/stern/stern |

#### k9s
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes CLI管理界面 |
| **Wikipedia** | N/A |
| **首次论文** | k9s 项目文档 |
| **官方文档** | https://k9scli.io/ |

#### Lens
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes IDE和管理平台 |
| **Wikipedia** | N/A |
| **首次论文** | Lens 项目文档 |
| **官方文档** | https://k8slens.dev/ |

#### kube-score
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes对象配置质量检查工具 |
| **Wikipedia** | N/A |
| **首次论文** | kube-score 项目文档 |
| **官方文档** | https://github.com/zegl/kube-score |

#### kube-linter
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes配置安全和最佳实践检查工具 |
| **Wikipedia** | N/A |
| **首次论文** | kube-linter 项目文档 |
| **官方文档** | https://github.com/stackrox/kube-linter |

#### Docker
| 属性 | 内容 |
|------|------|
| **简述** | 容器化平台，用于构建、部署和运行应用程序 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Docker_(software) |
| **首次论文** | Docker 项目文档 |
| **官方文档** | https://docs.docker.com/ |

#### containerd
| 属性 | 内容 |
|------|------|
| **简述** | 行业标准容器运行时，管理容器生命周期 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Containerd |
| **首次论文** | containerd 项目文档 |
| **官方文档** | https://containerd.io/docs/ |

#### runc
| 属性 | 内容 |
|------|------|
| **简述** | 符合OCI规范的轻量级容器运行时 |
| **Wikipedia** | N/A |
| **首次论文** | runc 项目文档 |
| **官方文档** | https://github.com/opencontainers/runc |

#### Podman
| 属性 | 内容 |
|------|------|
| **简述** | 无守护进程的容器引擎，Docker的替代品 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Podman_(software) |
| **首次论文** | Podman 项目文档 |
| **官方文档** | https://podman.io/ |

#### Buildah
| 属性 | 内容 |
|------|------|
| **简述** | 构建OCI镜像的工具，与Podman配合使用 |
| **Wikipedia** | N/A |
| **首次论文** | Buildah 项目文档 |
| **官方文档** | https://buildah.io/ |

#### Skopeo
| 属性 | 内容 |
|------|------|
| **简述** | 容器镜像管理工具，用于复制、检查和删除镜像 |
| **Wikipedia** | N/A |
| **首次论文** | Skopeo 项目文档 |
| **官方文档** | https://github.com/containers/skopeo |

#### Linux Kernel
| 属性 | 内容 |
|------|------|
| **简述** | 开源操作系统内核，容器技术的基础 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Linux_kernel |
| **首次论文** | Linux 内核设计与实现 |
| **官方文档** | https://www.kernel.org/doc/html/latest/ |

#### systemd
| 属性 | 内容 |
|------|------|
| **简述** | Linux 系统和服务管理器 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Systemd |
| **首次论文** | systemd 项目文档 |
| **官方文档** | https://systemd.io/ |

#### cgroups
| 属性 | 内容 |
|------|------|
| **简述** | Linux 控制组，用于资源限制和隔离 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Cgroups |
| **首次论文** | Control Groups Linux 内核特性 |
| **官方文档** | https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html |

#### Namespaces
| 属性 | 内容 |
|------|------|
| **简述** | Linux 命名空间，提供进程隔离机制 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Linux_namespaces |
| **首次论文** | Namespaces in Operation Linux 文档 |
| **官方文档** | https://man7.org/linux/man-pages/man7/namespaces.7.html |

#### TCP/IP
| 属性 | 内容 |
|------|------|
| **简述** | 互联网通信协议套件 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Internet_protocol_suite |
| **首次论文** | TCP/IP 详解 |
| **官方文档** | RFC 791, RFC 793 |

#### OSI Model
| 属性 | 内容 |
|------|------|
| **简述** | 开放系统互连参考模型，网络通信的七层架构 |
| **Wikipedia** | https://en.wikipedia.org/wiki/OSI_model |
| **首次论文** | ISO/IEC 7498-1:1994 |
| **官方文档** | https://www.iso.org/standard/20269.html |

#### HTTP
| 属性 | 内容 |
|------|------|
| **简述** | 超文本传输协议，Web通信的基础 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol |
| **首次论文** | RFC 2616 |
| **官方文档** | https://httpwg.org/specs/ |

#### DNS
| 属性 | 内容 |
|------|------|
| **简述** | 域名系统，将域名转换为IP地址 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Domain_Name_System |
| **首次论文** | RFC 1034, RFC 1035 |
| **官方文档** | https://www.iana.org/domains/root |

#### TLS/SSL
| 属性 | 内容 |
|------|------|
| **简述** | 传输层安全协议，提供加密通信 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Transport_Layer_Security |
| **首次论文** | RFC 5246 |
| **官方文档** | https://datatracker.ietf.org/wg/tls/documents/ |

#### Load Balancer
| 属性 | 内容 |
|------|------|
| **简述** | 负载均衡器，分发网络流量到多个服务器 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Load_balancing_(computing) |
| **首次论文** | 负载均衡算法研究 |
| **官方文档** | 各厂商LB产品文档 |

#### SDN
| 属性 | 内容 |
|------|------|
| **简述** | 软件定义网络，网络控制平面与数据平面分离 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Software-defined_networking |
| **首次论文** | SDN 白皮书 |
| **官方文档** | Open Networking Foundation |

#### Block Storage
| 属性 | 内容 |
|------|------|
| **简述** | 块存储，提供原始存储块的访问 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Block-level_storage |
| **首次论文** | 存储系统架构设计 |
| **官方文档** | 各厂商块存储产品文档 |

#### File Storage
| 属性 | 内容 |
|------|------|
| **简述** | 文件存储，通过文件系统提供文件级访问 |
| **Wikipedia** | https://en.wikipedia.org/wiki/File_storage |
| **首次论文** | 分布式文件系统研究 |
| **官方文档** | NFS, SMB 等协议规范 |

#### Object Storage
| 属性 | 内容 |
|------|------|
| **简述** | 对象存储，通过HTTP API存储非结构化数据 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Object_storage |
| **首次论文** | Amazon S3 设计理念 |
| **官方文档** | S3 API 文档 |

#### RAID
| 属性 | 内容 |
|------|------|
| **简述** | 独立磁盘冗余阵列，提供数据冗余和性能提升 |
| **Wikipedia** | https://en.wikipedia.org/wiki/RAID |
| **首次论文** | RAID 论文 |
| **官方文档** | RAID 标准规范 |

#### Distributed Storage
| 属性 | 内容 |
|------|------|
| **简述** | 分布式存储系统，跨多个节点存储数据 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Distributed_data_store |
| **首次论文** | Google File System |
| **官方文档** | Ceph, GlusterFS 等项目文档 |

#### ACK (Alibaba Cloud Container Service for Kubernetes)
| 属性 | 内容 |
|------|------|
| **简述** | 阿里云容器服务 Kubernetes 版，托管 Kubernetes 服务 |
| **Wikipedia** | N/A |
| **首次论文** | ACK 产品白皮书 |
| **官方文档** | https://help.aliyun.com/zh/ack/ |

#### EKS (Amazon Elastic Kubernetes Service)
| 属性 | 内容 |
|------|------|
| **简述** | AWS 托管 Kubernetes 服务 |
| **Wikipedia** | N/A |
| **首次论文** | EKS 产品文档 |
| **官方文档** | https://docs.aws.amazon.com/eks/ |

#### GKE (Google Kubernetes Engine)
| 属性 | 内容 |
|------|------|
| **简述** | Google Cloud 托管 Kubernetes 服务 |
| **Wikipedia** | N/A |
| **首次论文** | GKE 产品文档 |
| **官方文档** | https://cloud.google.com/kubernetes-engine |

#### AKS (Azure Kubernetes Service)
| 属性 | 内容 |
|------|------|
| **简述** | Microsoft Azure 托管 Kubernetes 服务 |
| **Wikipedia** | N/A |
| **首次论文** | AKS 产品文档 |
| **官方文档** | https://learn.microsoft.com/azure/aks/ |

#### TKE (Tencent Kubernetes Engine)
| 属性 | 内容 |
|------|------|
| **简述** | 腾讯云容器服务 |
| **Wikipedia** | N/A |
| **首次论文** | TKE 产品文档 |
| **官方文档** | https://cloud.tencent.com/document/product/457 |

#### CCE (Huawei Cloud Container Engine)
| 属性 | 内容 |
|------|------|
| **简述** | 华为云容器引擎 |
| **Wikipedia** | N/A |
| **首次论文** | CCE 产品文档 |
| **官方文档** | https://support.huaweicloud.com/cce/index.html |

#### Terway
| 属性 | 内容 |
|------|------|
| **简述** | 阿里云自研的高性能 Kubernetes 网络插件 |
| **Wikipedia** | N/A |
| **首次论文** | Terway 项目文档 |
| **官方文档** | https://github.com/AliyunContainerService/terway |

#### RRSA (RAM Roles for Service Accounts)
| 属性 | 内容 |
|------|------|
| **简述** | 阿里云服务账户的角色授权机制 |
| **Wikipedia** | N/A |
| **首次论文** | RRSA 技术文档 |
| **官方文档** | https://help.aliyun.com/zh/ack/user-guide/use-rrsa-to-grant-permissions-across-cloud-services |

#### ASI (Alibaba Serverless Infrastructure)
| 属性 | 内容 |
|------|------|
| **简述** | 阿里云无服务器基础设施 |
| **Wikipedia** | N/A |
| **首次论文** | ASI 产品文档 |
| **官方文档** | https://help.aliyun.com/zh/ack/product-overview/serverless-kubernetes |

---

## 4. 数据平面组件

### 概念解释

#### kubelet
| 属性 | 内容 |
|------|------|
| **简述** | 运行在每个节点上的代理，负责 Pod 的生命周期管理和容器运行时交互 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Components |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/ |

### kube-proxy
| 属性 | 内容 |
|------|------|
| **简述** | 运行在每个节点上的网络代理，维护网络规则和服务发现 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Components |
| **首次论文** | Kubernetes 网络设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/ |

### Container Runtime
| 属性 | 内容 |
|------|------|
| **简述** | 容器运行时接口的具体实现，如 containerd、CRI-O 等 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Container_runtime |
| **首次论文** | CRI (Container Runtime Interface) 设计文档 |
| **官方文档** | https://kubernetes.io/docs/setup/production-environment/container-runtimes/ |

### CRI (Container Runtime Interface)
| 属性 | 内容 |
|------|------|
| **简述** | 容器运行时接口标准，定义容器运行时与 Kubernetes 的交互规范 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes CRI 设计文档 |
| **官方文档** | https://github.com/kubernetes/cri-api |

### CRI Proxy
| 属性 | 内容 |
|------|------|
| **简述** | CRI 代理，用于支持多个容器运行时 |
| **Wikipedia** | N/A |
| **首次论文** | CRI Proxy 设计文档 |
| **官方文档** | https://github.com/kubernetes/cri-api |

### Container Runtime Shim
| 属性 | 内容 |
|------|------|
| **简述** | 容器运行时垫片，提供运行时抽象层 |
| **Wikipedia** | N/A |
| **首次论文** | 容器运行时架构文档 |
| **官方文档** | https://github.com/containerd/containerd |

### Image Manager
| 属性 | 内容 |
|------|------|
| **简述** | 镜像管理组件，负责容器镜像的拉取、存储和清理 |
| **Wikipedia** | N/A |
| **首次论文** | 容器镜像管理文献 |
| **官方文档** | https://kubernetes.io/docs/concepts/containers/images/ |

### 工具解释

#### crictl
| 属性 | 内容 |
|------|------|
| **简述** | CRI 兼容的容器运行时命令行工具 |
| **Wikipedia** | N/A |
| **首次论文** | CRI 工具文档 |
| **官方文档** | https://github.com/kubernetes-sigs/cri-tools |

#### containerd
| 属性 | 内容 |
|------|------|
| **简述** | 工业界标准的容器运行时，实现了 CRI 接口 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Containerd |
| **首次论文** | containerd 项目文档 |
| **官方文档** | https://containerd.io/docs/ |

#### CRI-O
| 属性 | 内容 |
|------|------|
| **简述** | 专为 Kubernetes 设计的轻量级容器运行时 |
| **Wikipedia** | N/A |
| **首次论文** | CRI-O 项目文档 |
| **官方文档** | https://cri-o.io/ |

---

## 5. 工作负载资源

### 概念解释

#### Deployment
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

### ConfigMap
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 配置管理对象，用于存储非机密性的键值对配置数据 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Configuration_management |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/configuration/configmap/ |

### Secret
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 密钥管理对象，用于存储敏感信息如密码、令牌、密钥等 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Secrets |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/configuration/secret/ |

### Horizontal Pod Autoscaler (HPA)
| 属性 | 内容 |
|------|------|
| **简述** | 水平 Pod 自动扩缩容控制器，基于 CPU 使用率或其他指标自动调整副本数 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Autoscaling |
| **首次论文** | Kubernetes HPA 设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/ |

### Vertical Pod Autoscaler (VPA)
| 属性 | 内容 |
|------|------|
| **简述** | 垂直 Pod 自动扩缩容控制器，自动调整 Pod 的资源请求和限制 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes VPA 设计文档 |
| **官方文档** | https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler |

### Pod Disruption Budget (PDB)
| 属性 | 内容 |
|------|------|
| **简述** | Pod 中断预算，限制在主动干扰期间可以中断的 Pod 数量 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes PDB 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/pods/disruptions/ |

### Init Container
| 属性 | 内容 |
|------|------|
| **简述** | 初始化容器，在应用容器启动之前运行的专用容器 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Init_containers |
| **首次论文** | Kubernetes Init Container 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/pods/init-containers/ |

### Sidecar Container
| 属性 | 内容 |
|------|------|
| **简述** | 边车容器，与主应用容器共享 Pod 资源的辅助容器 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Sidecar_pattern |
| **首次论文** | 微服务边车模式文献 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/ |

### Ephemeral Container
| 属性 | 内容 |
|------|------|
| **简述** | 临时容器，用于调试和故障排除的短期运行容器 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes Ephemeral Container 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/ |

### Garbage Collection
| 属性 | 内容 |
|------|------|
| **简述** | 垃圾回收机制，自动清理不再需要的资源对象 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Garbage_collection_(computer_science) |
| **首次论文** | Kubernetes GC 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/controllers/garbage-collection/ |

### 工具解释

#### kubectl rollout
| 属性 | 内容 |
|------|------|
| **简述** | 管理 Deployment 等资源滚动更新的命令 |
| **Wikipedia** | N/A |
| **首次论文** | kubectl 滚动更新文档 |
| **官方文档** | https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/ |

#### kubectl scale
| 属性 | 内容 |
|------|------|
| **简述** | 调整资源副本数的命令 |
| **Wikipedia** | N/A |
| **首次论文** | kubectl 扩缩容文档 |
| **官方文档** | https://kubernetes.io/docs/reference/kubectl/generated/kubectl_scale/ |

#### kubectl autoscale
| 属性 | 内容 |
|------|------|
| **简述** | 为资源创建自动扩缩容配置的命令 |
| **Wikipedia** | N/A |
| **首次论文** | kubectl 自动扩缩容文档 |
| **官方文档** | https://kubernetes.io/docs/reference/kubectl/generated/kubectl_autoscale/ |

---

## 6. 网络与服务发现

### 概念解释

#### Service
| 属性 | 内容 |
|------|------|
| **简述** | 为一组 Pod 提供稳定的网络访问入口的抽象 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Networking |
| **首次论文** | Kubernetes Service 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/service/ |

### ClusterIP
| 属性 | 内容 |
|------|------|
| **简述** | Service 的默认类型，在集群内部提供虚拟 IP 服务 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Networking |
| **首次论文** | Kubernetes Service 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types |

### NodePort
| 属性 | 内容 |
|------|------|
| **简述** | Service 类型之一，通过节点端口暴露服务 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Networking |
| **首次论文** | Kubernetes Service 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/service/#nodeport |

### LoadBalancer
| 属性 | 内容 |
|------|------|
| **简述** | Service 类型之一，通过云提供商的负载均衡器暴露服务 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Networking |
| **首次论文** | Kubernetes Service 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer |

### ExternalName
| 属性 | 内容 |
|------|------|
| **简述** | Service 类型之一，通过 CNAME 记录将服务映射到外部名称 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Networking |
| **首次论文** | Kubernetes Service 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/service/#externalname |

### Headless
| 属性 | 内容 |
|------|------|
| **简述** | 不分配 ClusterIP 的 Service，直接返回 Pod IPs |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Networking |
| **首次论文** | Kubernetes Service 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/service/#headless-services |

### Ingress
| 属性 | 内容 |
|------|------|
| **简述** | 管理外部访问集群服务的 HTTP/HTTPS 路由规则 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Networking |
| **首次论文** | Kubernetes Ingress 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/ingress/ |

### Endpoint
| 属性 | 内容 |
|------|------|
| **简述** | Service 的后端网络端点，包含 Pod 的 IP 和端口信息 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Networking |
| **首次论文** | Kubernetes Service 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/service/#services-in-kubernetes |

### EndpointSlice
| 属性 | 内容 |
|------|------|
| **简述** | Endpoint 的扩展版本，支持更大规模的服务发现 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Networking |
| **首次论文** | Kubernetes EndpointSlice 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/ |

### NetworkPolicy
| 属性 | 内容 |
|------|------|
| **简述** | 定义 Pod 之间网络通信策略的网络安全机制 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Networking |
| **首次论文** | Kubernetes Network Policy 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/network-policies/ |

### CNI (Container Network Interface)
| 属性 | 内容 |
|------|------|
| **简述** | 容器网络接口标准，定义容器网络配置的通用接口 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Container_Network_Interface |
| **首次论文** | CNI 规范文档 - https://github.com/containernetworking/cni/blob/master/SPEC.md |
| **官方文档** | https://github.com/containernetworking/cni |

### CoreDNS
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 集群 DNS 服务，提供服务发现和域名解析 |
| **Wikipedia** | https://en.wikipedia.org/wiki/CoreDNS |
| **首次论文** | CoreDNS 项目文档 |
| **官方文档** | https://coredns.io/ |

### kube-dns
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 早期 DNS 服务实现，已被 CoreDNS 替代 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#DNS |
| **首次论文** | Kubernetes DNS 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/ |

### Service Mesh
| 属性 | 内容 |
|------|------|
| **简述** | 服务网格，用于处理服务间通信的专用基础设施层 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Service_mesh |
| **首次论文** | 服务网格架构文献 |
| **官方文档** | https://istio.io/latest/docs/concepts/what-is-istio/ |

### Istio
| 属性 | 内容 |
|------|------|
| **简述** | 最流行的服务网格实现，提供流量管理、安全、可观察性等功能 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Istio |
| **首次论文** | Istio 项目文档 |
| **官方文档** | https://istio.io/ |

### Linkerd
| 属性 | 内容 |
|------|------|
| **简述** | 轻量级服务网格，专注于性能和易用性 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Linkerd |
| **首次论文** | Linkerd 项目文档 |
| **官方文档** | https://linkerd.io/ |

### 工具解释

#### kubectl expose
| 属性 | 内容 |
|------|------|
| **简述** | 为资源创建 Service 的命令 |
| **Wikipedia** | N/A |
| **首次论文** | kubectl Service 管理文档 |
| **官方文档** | https://kubernetes.io/docs/reference/kubectl/generated/kubectl_expose/ |

#### kubectl port-forward
| 属性 | 内容 |
|------|------|
| **简述** | 端口转发命令，用于访问集群内服务 |
| **Wikipedia** | N/A |
| **首次论文** | kubectl 端口转发文档 |
| **官方文档** | https://kubernetes.io/docs/reference/kubectl/generated/kubectl_port-forward/ |

#### istioctl
| 属性 | 内容 |
|------|------|
| **简述** | Istio 命令行工具，用于管理服务网格 |
| **Wikipedia** | N/A |
| **首次论文** | Istio 工具文档 |
| **官方文档** | https://istio.io/latest/docs/reference/commands/istioctl/ |

---

## 7. 存储管理

### 概念解释

#### PersistentVolume (PV)
| 属性 | 内容 |
|------|------|
| **简述** | 集群中的一块网络存储，由管理员配置和供应 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Storage |
| **首次论文** | Kubernetes 存储设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/persistent-volumes/ |

### PersistentVolumeClaim (PVC)
| 属性 | 内容 |
|------|------|
| **简述** | 用户对存储资源的申请，绑定到具体的 PV |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Storage |
| **首次论文** | Kubernetes 存储设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims |

### StorageClass
| 属性 | 内容 |
|------|------|
| **简述** | 描述存储类别的资源对象，支持动态存储供应 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Storage |
| **首次论文** | Kubernetes 存储设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/storage-classes/ |

### CSI (Container Storage Interface)
| 属性 | 内容 |
|------|------|
| **简述** | 容器存储接口标准，为容器编排系统提供统一的存储插件接口 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Container_Storage_Interface |
| **首次论文** | CSI 规范文档 - https://github.com/container-storage-interface/spec/blob/master/spec.md |
| **官方文档** | https://kubernetes-csi.github.io/docs/ |

### VolumeSnapshot
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 原生存储卷快照对象，支持创建卷的时间点副本 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/volume-snapshots/ |

### Volume
| 属性 | 内容 |
|------|------|
| **简述** | Pod 中的存储卷，为容器提供存储空间 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Volumes |
| **首次论文** | Kubernetes 存储设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/volumes/ |

### EmptyDir
| 属性 | 内容 |
|------|------|
| **简述** | 临时存储卷，Pod 删除时数据丢失 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Volumes |
| **首次论文** | Kubernetes 存储设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/volumes/#emptydir |

### HostPath
| 属性 | 内容 |
|------|------|
| **简述** | 主机路径卷，将节点文件系统挂载到 Pod |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Volumes |
| **首次论文** | Kubernetes 存储设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/volumes/#hostpath |

### NFS
| 属性 | 内容 |
|------|------|
| **简述** | 网络文件系统卷，支持网络存储共享 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Network_File_System |
| **首次论文** | NFS 协议规范 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/volumes/#nfs |

### FlexVolume
| 属性 | 内容 |
|------|------|
| **简述** | 可扩展的存储卷插件接口（已废弃，推荐使用 CSI）|
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes FlexVolume 设计文档 |
| **官方文档** | https://github.com/kubernetes/community/blob/master/contributors/devel/sig-storage/flexvolume.md |

### Local Volume
| 属性 | 内容 |
|------|------|
| **简述** | 本地存储卷，直接使用节点本地存储设备 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes Local Storage 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/storage/volumes/#local |

### 工具解释

#### kubectl get pv
| 属性 | 内容 |
|------|------|
| **简述** | 查看 PersistentVolume 资源的命令 |
| **Wikipedia** | N/A |
| **首次论文** | kubectl 存储管理文档 |
| **官方文档** | https://kubernetes.io/docs/reference/kubectl/generated/kubectl_get/ |

#### kubectl get pvc
| 属性 | 内容 |
|------|------|
| **简述** | 查看 PersistentVolumeClaim 资源的命令 |
| **Wikipedia** | N/A |
| **首次论文** | kubectl PVC 管理文档 |
| **官方文档** | https://kubernetes.io/docs/reference/kubectl/generated/kubectl_get/ |

#### csi-driver
| 属性 | 内容 |
|------|------|
| **简述** | CSI 驱动程序，实现特定存储系统的 CSI 接口 |
| **Wikipedia** | N/A |
| **首次论文** | CSI 驱动开发文档 |
| **官方文档** | https://kubernetes-csi.github.io/docs/drivers.html |

---

## 8. 安全与权限控制

### 概念解释

#### RBAC (Role-Based Access Control)
| 属性 | 内容 |
|------|------|
| **简述** | 基于角色的访问控制机制，通过角色和角色绑定管理权限 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Role-based_access_control |
| **首次论文** | RBAC 模型论文 - "Role-based access control" - ACM Computing Surveys (1996) |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/rbac/ |

### Role
| 属性 | 内容 |
|------|------|
| **简述** | RBAC 中的角色定义，包含权限规则集合 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Role-based_access_control |
| **首次论文** | RBAC 模型论文 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/rbac/#role-and-clusterrole |

### RoleBinding
| 属性 | 内容 |
|------|------|
| **简述** | 将 Role 绑定到用户或组的 RBAC 对象 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Role-based_access_control |
| **首次论文** | RBAC 模型论文 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/rbac/#rolebinding-and-clusterrolebinding |

### ClusterRole
| 属性 | 内容 |
|------|------|
| **简述** | 集群级别的 Role，作用域为整个集群 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Role-based_access_control |
| **首次论文** | RBAC 模型论文 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/rbac/#role-and-clusterrole |

### ClusterRoleBinding
| 属性 | 内容 |
|------|------|
| **简述** | 将 ClusterRole 绑定到用户或组的 RBAC 对象 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Role-based_access_control |
| **首次论文** | RBAC 模型论文 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/rbac/#rolebinding-and-clusterrolebinding |

### ServiceAccount
| 属性 | 内容 |
|------|------|
| **简述** | 为 Pod 提供身份标识的服务账户，用于 API 访问认证 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 认证设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/ |

### Policy
| 属性 | 内容 |
|------|------|
| **简述** | 策略定义，用于控制资源创建和访问 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 策略引擎设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/security/pod-security-standards/ |

### Constraint
| 属性 | 内容 |
|------|------|
| **简述** | 约束条件，定义资源必须满足的要求 |
| **Wikipedia** | N/A |
| **首次论文** | OPA (Open Policy Agent) 相关文献 |
| **官方文档** | https://www.openpolicyagent.org/docs/latest/kubernetes-introduction/ |

### PodSecurityPolicy (PSP)
| 属性 | 内容 |
|------|------|
| **简述** | Pod 安全策略，控制 Pod 的安全相关配置（已废弃）|
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes PSP 设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/security/pod-security-policy/ |

### Pod Security Standards
| 属性 | 内容 |
|------|------|
| **简述** | Pod 安全标准，替代 PSP 的新安全机制 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 安全设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/security/pod-security-standards/ |

### Network Policy
| 属性 | 内容 |
|------|------|
| **简述** | 网络策略，控制 Pod 间的网络通信 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubernetes#Networking |
| **首次论文** | Kubernetes 网络安全设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/services-networking/network-policies/ |

### ImagePolicyWebhook
| 属性 | 内容 |
|------|------|
| **简述** | 镜像策略 Webhook，验证容器镜像是否符合安全要求 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 镜像安全设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#imagepolicywebhook |

### Security Context
| 属性 | 内容 |
|------|------|
| **简述** | 安全上下文，定义 Pod 或容器的安全配置 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 安全上下文设计文档 |
| **官方文档** | https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ |

### 工具解释

#### kubectl auth can-i
| 属性 | 内容 |
|------|------|
| **简述** | 检查用户权限的命令 |
| **Wikipedia** | N/A |
| **首次论文** | kubectl 权限检查文档 |
| **官方文档** | https://kubernetes.io/docs/reference/access-authn-authz/authorization/ |

#### kubectl create role
| 属性 | 内容 |
|------|------|
| **简述** | 创建 RBAC Role 资源的命令 |
| **Wikipedia** | N/A |
| **首次论文** | kubectl RBAC 管理文档 |
| **官方文档** | https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_role/ |

#### opa
| 属性 | 内容 |
|------|------|
| **简述** | Open Policy Agent，通用策略引擎 |
| **Wikipedia** | N/A |
| **首次论文** | OPA 项目文档 |
| **官方文档** | https://www.openpolicyagent.org/docs/latest/ |

---

## 9. 可观测性与监控

### 概念解释

#### Prometheus
| 属性 | 内容 |
|------|------|
| **简述** | 开源系统监控和告警工具包，采用拉取模式收集指标 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Prometheus_(software) |
| **首次论文** | Prometheus 项目文档 |
| **官方文档** | https://prometheus.io/docs/ |

### Grafana
| 属性 | 内容 |
|------|------|
| **简述** | 开源的数据可视化和监控仪表板平台 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Grafana |
| **首次论文** | Grafana 项目文档 |
| **官方文档** | https://grafana.com/docs/ |

### Fluentd
| 属性 | 内容 |
|------|------|
| **简述** | 开源数据收集器，统一日志层的实现 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Fluentd |
| **首次论文** | Fluentd 项目文档 |
| **官方文档** | https://docs.fluentd.org/ |

### Log
| 属性 | 内容 |
|------|------|
| **简述** | 日志记录，用于系统监控和故障排查 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Log_file |
| **首次论文** | 系统日志管理相关文献 |
| **官方文档** | https://kubernetes.io/docs/concepts/cluster-administration/logging/ |

### Metrics Server
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 指标服务器，提供核心指标 API |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes Metrics API 设计文档 |
| **官方文档** | https://github.com/kubernetes-sigs/metrics-server |

### kube-state-metrics
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 状态指标收集器，生成集群状态指标 |
| **Wikipedia** | N/A |
| **首次论文** | kube-state-metrics 项目文档 |
| **官方文档** | https://github.com/kubernetes/kube-state-metrics |

### node-exporter
| 属性 | 内容 |
|------|------|
| **简述** | 节点指标导出器，收集节点级别的系统指标 |
| **Wikipedia** | N/A |
| **首次论文** | Prometheus node-exporter 文档 |
| **官方文档** | https://github.com/prometheus/node_exporter |

### Alertmanager
| 属性 | 内容 |
|------|------|
| **简述** | Prometheus 告警管理器，处理和路由告警通知 |
| **Wikipedia** | N/A |
| **首次论文** | Alertmanager 项目文档 |
| **官方文档** | https://prometheus.io/docs/alerting/latest/alertmanager/ |

### Tracing
| 属性 | 内容 |
|------|------|
| **简述** | 分布式追踪，监控微服务间的请求调用链路 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Distributed_tracing |
| **首次论文** | 分布式追踪系统设计文献 |
| **官方文档** | https://opentracing.io/docs/ |

### Jaeger
| 属性 | 内容 |
|------|------|
| **简述** | 开源分布式追踪系统，用于监控和故障诊断微服务 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Jaeger_(software) |
| **首次论文** | Jaeger 项目文档 |
| **官方文档** | https://www.jaegertracing.io/docs/ |

### 工具解释

#### prometheus
| 属性 | 内容 |
|------|------|
| **简述** | Prometheus 监控系统的二进制文件 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Prometheus_(software) |
| **首次论文** | Prometheus 项目文档 |
| **官方文档** | https://prometheus.io/docs/prometheus/latest/getting_started/ |

#### grafana-server
| 属性 | 内容 |
|------|------|
| **简述** | Grafana 可视化平台的服务器程序 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Grafana |
| **首次论文** | Grafana 项目文档 |
| **官方文档** | https://grafana.com/docs/grafana/latest/setup-grafana/start-server/ |

#### fluentd
| 属性 | 内容 |
|------|------|
| **简述** | Fluentd 日志收集器的二进制文件 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Fluentd |
| **首次论文** | Fluentd 项目文档 |
| **官方文档** | https://docs.fluentd.org/deployment/system-config |

---

## 10. 分布式系统理论

### 概念解释

#### CAP 定理
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

### Vector Clock
| 属性 | 内容 |
|------|------|
| **简述** | 用于分布式系统中检测事件因果关系的逻辑时钟 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Vector_clock |
| **首次论文** | "Virtual Time and Global States of Distributed Systems" - Friedemann Mattern (1988) |
| **官方文档** | 分布式系统时钟同步文献 |

### Lamport Clock
| 属性 | 内容 |
|------|------|
| **简述** | 分布式系统中的逻辑时钟，用于事件排序 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Lamport_timestamp |
| **首次论文** | "Time, Clocks, and the Ordering of Events in a Distributed System" - Leslie Lamport (CACM 1978) |
| **官方文档** | 分布式系统时间同步理论 |

### Byzantine Fault Tolerance
| 属性 | 内容 |
|------|------|
| **简述** | 拜占庭容错，处理恶意节点的分布式容错机制 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Byzantine_fault |
| **首次论文** | "The Byzantine Generals Problem" - Leslie Lamport (TOPLAS 1982) |
| **官方文档** | 分布式容错理论文献 |

### 工具解释

#### etcd
| 属性 | 内容 |
|------|------|
| **简述** | 基于 Raft 算法的分布式键值存储系统 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Etcd |
| **首次论文** | etcd 项目文档 |
| **官方文档** | https://etcd.io/docs/ |

#### consul
| 属性 | 内容 |
|------|------|
| **简述** | HashiCorp 开发的分布式服务发现和配置管理工具 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Consul_(software) |
| **首次论文** | Consul 项目文档 |
| **官方文档** | https://developer.hashicorp.com/consul/docs |

---

## 11. 设计模式与架构

### 概念解释

#### 声明式 API
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
| **简述** | 基于 List-Watch 机制的客户端缓存组件，减小 API Server 压力 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes client-go 设计文档 |
| **官方文档** | https://pkg.go.dev/k8s.io/client-go/informers |

### WorkQueue
| 属性 | 内容 |
|------|------|
| **简述** | 控制器中用于存储待处理资源 key 的队列，支持去重和限速 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes client-go 设计文档 |
| **官方文档** | https://pkg.go.dev/k8s.io/client-go/util/workqueue |

### Watch-List 机制
| 属性 | 内容 |
|------|------|
| **简述** | 通过建立长连接持续监听资源变化的高效数据同步机制 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/using-api/api-concepts/#watch |

### Client-Go
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes Go 语言客户端库，提供 API 访问和工具组件 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes client-go 设计文档 |
| **官方文档** | https://github.com/kubernetes/client-go |

### Controller Runtime
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 控制器开发框架，简化 Operator 开发 |
| **Wikipedia** | N/A |
| **首次论文** | Controller Runtime 项目文档 |
| **官方文档** | https://pkg.go.dev/sigs.k8s.io/controller-runtime |

### KubeBuilder
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes API 开发工具包，用于构建自定义控制器 |
| **Wikipedia** | N/A |
| **首次论文** | KubeBuilder 项目文档 |
| **官方文档** | https://book.kubebuilder.io/ |

### 工具解释

#### client-go
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes Go 语言客户端库 |
| **Wikipedia** | N/A |
| **首次论文** | client-go 项目文档 |
| **官方文档** | https://github.com/kubernetes/client-go |

#### controller-runtime
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 控制器运行时框架 |
| **Wikipedia** | N/A |
| **首次论文** | controller-runtime 项目文档 |
| **官方文档** | https://pkg.go.dev/sigs.k8s.io/controller-runtime |

#### kubebuilder
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes API 开发工具包 |
| **Wikipedia** | N/A |
| **首次论文** | KubeBuilder 项目文档 |
| **官方文档** | https://book.kubebuilder.io/quick-start.html |

---

## 12. AI/ML 工程概念

### 概念解释

#### MLOps
| 属性 | 内容 |
|------|------|
| **简述** | 机器学习运维，将 DevOps 理念应用于机器学习生命周期管理 |
| **Wikipedia** | https://en.wikipedia.org/wiki/MLOps |
| **首次论文** | "Hidden Technical Debt in Machine Learning Systems" - Google (NIPS 2015) |
| **官方文档** | https://ml-ops.org/ |

### Model Registry
| 属性 | 内容 |
|------|------|
| **简述** | 机器学习模型版本管理和元数据存储系统 |
| **Wikipedia** | N/A |
| **首次论文** | MLflow: A Machine Learning Lifecycle Platform (2018) |
| **官方文档** | https://mlflow.org/docs/latest/model-registry.html |

### Feature Store
| 属性 | 内容 |
|------|------|
| **简述** | 特征存储和管理平台，支持特征的共享、复用和版本控制 |
| **Wikipedia** | N/A |
| **首次论文** | "The Feature Store: A Missing Piece in the ML Puzzle" (2019) |
| **官方文档** | https://www.featurestore.org/ |

### Data Pipeline
| 属性 | 内容 |
|------|------|
| **简述** | 数据流水线，自动化处理数据从采集到模型训练的全过程 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Pipeline_(software) |
| **首次论文** | 数据工程流水线设计文献 |
| **官方文档** | https://www.tensorflow.org/tfx |

### Experiment Tracking
| 属性 | 内容 |
|------|------|
| **简述** | 实验跟踪系统，记录机器学习实验的参数、指标和结果 |
| **Wikipedia** | N/A |
| **首次论文** | 机器学习实验管理文献 |
| **官方文档** | https://wandb.ai/site |

### Hyperparameter Tuning
| 属性 | 内容 |
|------|------|
| **简述** | 超参数调优，自动化寻找最优模型超参数配置的过程 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Hyperparameter_optimization |
| **首次论文** | 超参数优化算法文献 |
| **官方文档** | https://scikit-learn.org/stable/modules/grid_search.html |

### AutoML
| 属性 | 内容 |
|------|------|
| **简述** | 自动化机器学习，自动完成特征工程、模型选择、超参数调优等过程 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Automated_machine_learning |
| **首次论文** | AutoML 系统设计文献 |
| **官方文档** | https://automl.org/ |

### 工具解释

#### mlflow
| 属性 | 内容 |
|------|------|
| **简述** | 开源的机器学习生命周期管理平台 |
| **Wikipedia** | N/A |
| **首次论文** | MLflow: A Machine Learning Lifecycle Platform (2018) |
| **官方文档** | https://mlflow.org/docs/latest/index.html |

#### feast
| 属性 | 内容 |
|------|------|
| **简述** | 开源的特征存储平台 |
| **Wikipedia** | N/A |
| **首次论文** | Feast 项目文档 |
| **官方文档** | https://docs.feast.dev/ |

#### kubeflow
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 上的机器学习工具包 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubeflow |
| **首次论文** | Kubeflow 项目文档 |
| **官方文档** | https://www.kubeflow.org/docs/ |

---

## 13. LLM 特有概念

### 概念解释

#### Transformer
| 属性 | 内容 |
|------|------|
| **简述** | 基于自注意力机制的神经网络架构，是现代大语言模型的基础 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Transformer_(machine_learning_model) |
| **首次论文** | "Attention Is All You Need" - Vaswani et al. (NeurIPS 2017) - https://arxiv.org/abs/1706.03762 |
| **官方文档** | N/A (研究论文) |

### Attention Mechanism
| 属性 | 内容 |
|------|------|
| **简述** | 神经网络中的注意力机制，允许模型关注输入的不同部分 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Attention_(machine_learning) |
| **首次论文** | "Neural Machine Translation by Jointly Learning to Align and Translate" (ICLR 2015) |
| **官方文档** | N/A (研究概念) |

### Fine-tuning
| 属性 | 内容 |
|------|------|
| **简述** | 在预训练模型基础上，使用特定领域数据进行进一步训练的过程 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Fine-tuning_(deep_learning) |
| **首次论文** | 各大模型论文中的微调章节 |
| **官方文档** | https://huggingface.co/docs/transformers/training |

### RAG (Retrieval-Augmented Generation)
| 属性 | 内容 |
|------|------|
| **简述** | 检索增强生成，结合检索系统和生成模型的混合架构 |
| **Wikipedia** | N/A |
| **首次论文** | "Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks" (NeurIPS 2020) |
| **官方文档** | https://ai.facebook.com/research/publications/retrieval-augmented-generation-for-knowledge-intensive-nlp-tasks/ |

### Prompt Engineering
| 属性 | 内容 |
|------|------|
| **简述** | 提示工程，设计有效的输入提示来引导大语言模型产生期望输出 |
| **Wikipedia** | N/A |
| **首次论文** | 大语言模型提示设计文献 |
| **官方文档** | https://promptingguide.ai/ |

### Zero-shot Learning
| 属性 | 内容 |
|------|------|
| **简述** | 零样本学习，模型在未见过的任务上直接推理的能力 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Zero-shot_learning |
| **首次论文** | 零样本学习理论文献 |
| **官方文档** | N/A (机器学习概念) |

### Few-shot Learning
| 属性 | 内容 |
|------|------|
| **简述** | 少样本学习，模型通过少量示例就能学习新任务的能力 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Few-shot_learning_(natural_language_processing) |
| **首次论文** | 少样本学习研究文献 |
| **官方文档** | N/A (机器学习概念) |

### Chain-of-Thought
| 属性 | 内容 |
|------|------|
| **简述** | 思维链，让模型逐步推理并展示中间思考过程的技术 |
| **Wikipedia** | N/A |
| **首次论文** | "Chain-of-Thought Prompting Elicits Reasoning in Large Language Models" (NeurIPS 2022) |
| **官方文档** | N/A (研究概念) |

### 工具解释

#### huggingface
| 属性 | 内容 |
|------|------|
| **简述** | 提供预训练模型和 Transformers 库的平台 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Hugging_Face |
| **首次论文** | Hugging Face 项目文档 |
| **官方文档** | https://huggingface.co/docs |

#### langchain
| 属性 | 内容 |
|------|------|
| **简述** | 构建 LLM 应用的框架，支持链式调用和工具集成 |
| **Wikipedia** | N/A |
| **首次论文** | LangChain 项目文档 |
| **官方文档** | https://docs.langchain.com/docs/ |

#### llama.cpp
| 属性 | 内容 |
|------|------|
| **简述** | 用于运行 LLaMA 模型的 C++ 库，支持多种硬件加速 |
| **Wikipedia** | N/A |
| **首次论文** | llama.cpp 项目文档 |
| **官方文档** | https://github.com/ggerganov/llama.cpp |

---

## 14. DevOps 工具与实践

### 概念解释

#### Helm
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 包管理器，用于定义、安装和升级复杂 Kubernetes 应用 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Helm_(package_manager) |
| **首次论文** | Helm 项目文档 |
| **官方文档** | https://helm.sh/docs/ |

### Argo CD
| 属性 | 内容 |
|------|------|
| **简述** | 基于 GitOps 的声明式持续交付工具 |
| **Wikipedia** | N/A |
| **首次论文** | Argo CD 项目文档 |
| **官方文档** | https://argo-cd.readthedocs.io/ |

### GitOps
| 属性 | 内容 |
|------|------|
| **简述** | 使用 Git 作为基础设施和应用配置单一事实来源的运维模式 |
| **Wikipedia** | https://en.wikipedia.org/wiki/GitOps |
| **首次论文** | "GitOps - Operations by Pull Request" - Weaveworks (2017) |
| **官方文档** | https://www.gitops.tech/ |

### Flux CD
| 属性 | 内容 |
|------|------|
| **简述** | GitOps 工具链，自动化同步 Git 仓库与 Kubernetes 集群状态 |
| **Wikipedia** | N/A |
| **首次论文** | Flux CD 项目文档 |
| **官方文档** | https://fluxcd.io/docs/ |

### Jenkins
| 属性 | 内容 |
|------|------|
| **简述** | 开源自动化服务器，广泛用于持续集成和持续部署 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Jenkins_(software) |
| **首次论文** | Jenkins 项目文档 |
| **官方文档** | https://www.jenkins.io/doc/ |

### GitHub Actions
| 属性 | 内容 |
|------|------|
| **简述** | GitHub 的 CI/CD 服务，支持自动化工作流 |
| **Wikipedia** | https://en.wikipedia.org/wiki/GitHub_Actions |
| **首次论文** | GitHub Actions 官方文档 |
| **官方文档** | https://docs.github.com/en/actions |

### Tekton
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 原生 CI/CD 框架，提供云原生的流水线能力 |
| **Wikipedia** | N/A |
| **首次论文** | Tekton 项目文档 |
| **官方文档** | https://tekton.dev/docs/ |

### 工具解释

#### helm
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 包管理器的命令行工具 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Helm_(package_manager) |
| **首次论文** | Helm 项目文档 |
| **官方文档** | https://helm.sh/docs/helm/ |

#### argocd
| 属性 | 内容 |
|------|------|
| **简述** | Argo CD 命令行工具，用于 GitOps 持续交付 |
| **Wikipedia** | N/A |
| **首次论文** | Argo CD 项目文档 |
| **官方文档** | https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd/ |

#### flux
| 属性 | 内容 |
|------|------|
| **简述** | Flux CD 命令行工具，用于 GitOps 自动化 |
| **Wikipedia** | N/A |
| **首次论文** | Flux CD 项目文档 |
| **官方文档** | https://fluxcd.io/docs/cmd/ |

---

## 15. 补充技术概念

### 概念解释

#### Reflector
| 属性 | 内容 |
|------|------|
| **简述** | Informer的核心组件，负责通过List&Watch机制从API Server获取资源变化 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes client-go设计文档 |
| **官方文档** | https://pkg.go.dev/k8s.io/client-go/tools/cache#Reflector |

### Store
| 属性 | 内容 |
|------|------|
| **简述** | Informer中存储资源对象的内存数据结构 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes client-go设计文档 |
| **官方文档** | https://pkg.go.dev/k8s.io/client-go/tools/cache#Store |

### Indexer
| 属性 | 内容 |
|------|------|
| **简述** | 带索引功能的Store，支持通过多种维度快速查找资源 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes client-go设计文档 |
| **官方文档** | https://pkg.go.dev/k8s.io/client-go/tools/cache#Indexer |

### EventHandler
| 属性 | 内容 |
|------|------|
| **简述** | 处理资源变化事件的回调接口，包括OnAdd/OnUpdate/OnDelete |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes client-go设计文档 |
| **官方文档** | https://pkg.go.dev/k8s.io/client-go/tools/cache#ResourceEventHandler |

### Lister
| 属性 | 内容 |
|------|------|
| **简述** | 从Informer缓存中读取资源对象的接口 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes client-go设计文档 |
| **官方文档** | https://pkg.go.dev/k8s.io/client-go/listers |

### Reconciler
| 属性 | 内容 |
|------|------|
| **简述** | 执行控制器调谐逻辑的核心组件，实现syncHandler接口 |
| **Wikipedia** | N/A |
| **首次论文** | Kubernetes控制器模式设计文档 |
| **官方文档** | https://pkg.go.dev/sigs.k8s.io/controller-runtime/pkg/reconcile |

### Control Loop
| 属性 | 内容 |
|------|------|
| **简述** | 控制器持续运行的调谐循环，不断驱动系统向期望状态收敛 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Control_loop |
| **首次论文** | Kubernetes设计文档 |
| **官方文档** | https://kubernetes.io/docs/concepts/architecture/controller/ |

### Level-triggered
| 属性 | 内容 |
|------|------|
| **简述** | 电平触发模式，基于当前状态而非事件来触发操作，天然幂等 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Level-triggered |
| **首次论文** | 控制理论中的触发机制 |
| **官方文档** | Kubernetes控制器设计原理 |

### Edge-triggered
| 属性 | 内容 |
|------|------|
| **简述** | 边沿触发模式，基于状态变化事件来触发操作 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Edge-triggered |
| **首次论文** | 控制理论中的触发机制 |
| **官方文档** | N/A (对比概念) |

### FIFO Queue
| 属性 | 内容 |
|------|------|
| **简述** | 先进先出队列，WorkQueue的基础实现 |
| **Wikipedia** | https://en.wikipedia.org/wiki/FIFO_(computing_and_electronics) |
| **首次论文** | 数据结构经典文献 |
| **官方文档** | https://pkg.go.dev/k8s.io/client-go/util/workqueue |

### Delaying Queue
| 属性 | 内容 |
|------|------|
| **简述** | 支持延迟入队的队列，可用于定时任务和延迟重试 |
| **Wikipedia** | N/A |
| **首次论文** | 分布式系统延迟队列设计 |
| **官方文档** | https://pkg.go.dev/k8s.io/client-go/util/workqueue |

### Rate Limiting Queue
| 属性 | 内容 |
|------|------|
| **简述** | 带有限速功能的队列，失败重试时使用指数退避算法 |
| **Wikipedia** | N/A |
| **首次论文** | 分布式系统限流算法 |
| **官方文档** | https://pkg.go.dev/k8s.io/client-go/util/workqueue |

### De-duplication
| 属性 | 内容 |
|------|------|
| **简述** | 去重机制，确保相同key的请求在队列中只保留一份 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Data_deduplication |
| **首次论文** | 队列去重算法 |
| **官方文档** | https://pkg.go.dev/k8s.io/client-go/util/workqueue |

### Fair Queuing
| 属性 | 内容 |
|------|------|
| **简述** | 公平队列调度算法，确保不同key的请求得到公平处理 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Fair_queuing |
| **首次论文** | "Analysis and Simulation of a Fair Queueing Algorithm" - ACM SIGCOMM (1989) |
| **官方文档** | https://kubernetes.io/docs/concepts/cluster-administration/flow-control/ |

### Graceful Shutdown
| 属性 | 内容 |
|------|------|
| **简述** | 优雅关闭机制，确保正在处理的任务完成后再退出 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Graceful_exit |
| **首次论文** | 系统可靠性设计原则 |
| **官方文档** | https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-termination |

### Cache Sync
| 属性 | 内容 |
|------|------|
| **简述** | 缓存同步机制，确保Informer本地缓存与API Server数据一致 |
| **Wikipedia** | N/A |
| **首次论文** | 分布式缓存一致性算法 |
| **官方文档** | https://pkg.go.dev/k8s.io/client-go/tools/cache#WaitForCacheSync |

### 工具解释

#### kubectl
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 命令行工具，用于与集群进行交互 |
| **Wikipedia** | https://en.wikipedia.org/wiki/Kubectl |
| **首次论文** | Kubernetes 设计文档 |
| **官方文档** | https://kubernetes.io/docs/reference/kubectl/ |

#### client-go
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes Go 语言客户端库 |
| **Wikipedia** | N/A |
| **首次论文** | client-go 项目文档 |
| **官方文档** | https://github.com/kubernetes/client-go |

#### controller-runtime
| 属性 | 内容 |
|------|------|
| **简述** | Kubernetes 控制器运行时框架 |
| **Wikipedia** | N/A |
| **首次论文** | controller-runtime 项目文档 |
| **官方文档** | https://pkg.go.dev/sigs.k8s.io/controller-runtime |

---

*文档生成时间: 2026-02-03*
*概念总数: 331个 (概念165个 + 工具166个)*
*涵盖技术领域: 15个主要分类*
