# ACK 关联产品 - ROS 资源编排 (IaC)

> **适用版本**: ACK v1.25 - v1.32 | **最后更新**: 2026-01

---

## 目录

- [IaC 方案对比 (ROS vs Terraform)](#iac-方案对比-ros-vs-terraform)
- [ROS 基本概念与架构](#ros-基本概念与架构)
- [ACK 集群 ROS 模板示例](#ack-集群-ros-模板示例)
- [资源依赖管理 (DependsOn)](#资源依赖管理-dependson)
- [CI/CD 与 GitOps 集成](#cicd-与-gitops-集成)

---

## IaC 方案对比 (ROS vs Terraform)

| 维度 | ROS (资源编排) | Terraform |
|:---|:---|:---|
| **托管方式** | 阿里云全托管，无需管理状态文件 | 自行管理或使用 TF Cloud 管理 State |
| **语言规范** | JSON / YAML (标准阿里云规范) | HCL (HashiCorp 专有语言) |
| **生态支持** | 阿里云产品深度集成，支持嵌套堆栈 | 多云支持，插件丰富 |
| **学习曲线** | 低 (如果你熟悉 YAML/JSON) | 中 (需学习 HCL 语法) |

---

## ROS 基本概念与架构

### 核心要素

- **模板 (Template)**: 定义资源的文本文件。
- **资源 (Resource)**: 如 `ALIYUN::CS::ManagedKubernetesCluster`。
- **参数 (Parameters)**: 动态输入。
- **输出 (Outputs)**: 返回值 (如集群 ID, Kubeconfig)。
- **堆栈 (Stack)**: 真正运行起来的资源集合。

### ACK 创建链路

1. **VPC/vSwitch**: 创建网络基础设施。
2. **Managed Kubernetes**: 定义控制面类型及参数。
3. **NodePool**: 定义计算节点规格及数量。

---

## ACK 集群 ROS 模板示例

```yaml
ROSTemplateFormatVersion: '2015-09-01'
Description: 创建一个 ACK Pro 托管集群
Parameters:
  VpcId:
    Type: String
    Description: 指定已有的 VPC ID
  VSwitchIds:
    Type: CommaDelimitedList
    Description: 指定交换机列表
Resources:
  AckCluster:
    Type: ALIYUN::CS::ManagedKubernetesCluster
    Properties:
      Name: my-ros-cluster
      VpcId: !Ref VpcId
      VSwitchIds: !Ref VSwitchIds
      ClusterSpec: ack.pro.small
      WorkerInstanceTypes: 
        - ecs.c7.xlarge
      ContainerRuntime: containerd
      RuntimeVersion: 1.6.20
Outputs:
  ClusterId:
    Value: !GetAtt AckCluster.ClusterId
```

---

## 资源依赖管理 (DependsOn)

在 IaC 编排中，资源创建的顺序至关重要。

### 处理逻辑

- **显式依赖**: 使用 `DependsOn` 关键字。
- **隐式依赖**: 通过 `!Ref` 或 `!GetAtt` 引用其他资源属性时，ROS 自动计算顺序。

| 场景 | 依赖关系 |
|:---|:---|
| **存储挂载** | ECS 节点池依赖于 NAS/OSS 的创建完成 |
| **网络隔离** | 安全组规则依赖于 VPC 和安全组 ID |
| **监控部署** | ARMS 组件依赖于 ACK 集群状态为 Running |

---

## CI/CD 与 GitOps 集成

### 工作流建议

```mermaid
graph LR
    A[代码提交 Git] --> B[Jenkins/Tekton 调用 CLI]
    B --> C[aliyun ros UpdateStack]
    C --> D[阿里云堆栈自动更新]
```

### 最佳实践

1. **版本化模板**: 将 ROS 模板存放在 Git 中，通过版本号控制环境一致性。
2. **变更预览 (ChangeSet)**: 在应用更新前生成变更集，预览受影响的资源，防止意外删除。
3. **标签管理**: 为所有通过 ROS 创建的资源打上 `iac:ros` 标签，方便成本分摊和资源审计。

---

## 相关文档

- [06-cluster-configuration-parameters.md](./06-cluster-configuration-parameters.md) - 集群配置参数参考
- [156-alibaba-cloud-integration.md](./156-alibaba-cloud-integration.md) - 阿里云集成总表
- [141-hybrid-multi-cloud-design.md](./141-hybrid-multi-cloud-design.md) - 混合云架构设计
