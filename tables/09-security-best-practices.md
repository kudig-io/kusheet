# 表格9：安全最佳实践表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/security](https://kubernetes.io/docs/concepts/security/)

## Pod安全标准(Pod Security Standards)

| 安全级别 | 描述 | 限制内容 | 适用场景 | 版本支持 | 实施方式 |
|---------|------|---------|---------|---------|---------|
| **Privileged** | 无限制，完全开放 | 无 | 系统组件，信任的工作负载 | v1.23+ | `pod-security.kubernetes.io/enforce: privileged` |
| **Baseline** | 最低限度限制 | 禁止hostNetwork/hostPID/hostIPC等特权 | 大多数应用 | v1.23+ | `pod-security.kubernetes.io/enforce: baseline` |
| **Restricted** | 严格限制，最佳实践 | 必须非root，只读根文件系统，限制capabilities | 安全敏感应用 | v1.23+ | `pod-security.kubernetes.io/enforce: restricted` |

## Pod安全准入(PSA)配置

| 配置项 | 用途 | 标签格式 | 示例值 | 版本变更 | 生产建议 |
|-------|------|---------|-------|---------|---------|
| **enforce** | 强制执行，违反则拒绝 | `pod-security.kubernetes.io/enforce` | privileged/baseline/restricted | v1.25+ GA | 生产命名空间使用 |
| **enforce-version** | 强制执行的版本 | `pod-security.kubernetes.io/enforce-version` | latest/v1.28 | v1.25+ | 指定版本避免升级影响 |
| **audit** | 审计模式，记录违规 | `pod-security.kubernetes.io/audit` | baseline/restricted | v1.25+ | 迁移时启用审计 |
| **audit-version** | 审计的版本 | `pod-security.kubernetes.io/audit-version` | latest/v1.28 | v1.25+ | 与enforce配合 |
| **warn** | 警告模式，提示用户 | `pod-security.kubernetes.io/warn` | baseline/restricted | v1.25+ | 开发环境使用 |
| **warn-version** | 警告的版本 | `pod-security.kubernetes.io/warn-version` | latest/v1.28 | v1.25+ | 与warn配合 |

## RBAC最佳实践

| 实践领域 | 最佳实践 | 实施步骤 | 版本强制 | 风险说明 | 审计方法 |
|---------|---------|---------|---------|---------|---------|
| **最小权限原则** | 仅授予必需权限 | 使用Role而非ClusterRole，限制verbs | 稳定 | 权限过大导致横向移动 | `kubectl auth can-i --list` |
| **服务账户隔离** | 每个工作负载独立SA | 不使用default SA，创建专用SA | 稳定 | 共享SA导致权限泄露 | 检查Pod的serviceAccountName |
| **限制cluster-admin** | 避免过度使用 | 仅限紧急操作，日常使用受限角色 | 稳定 | 完全控制集群 | 审计ClusterRoleBinding |
| **禁用自动挂载Token** | 不需要API访问时禁用 | `automountServiceAccountToken: false` | 稳定 | Token泄露风险 | 检查Pod挂载 |
| **使用聚合ClusterRole** | 简化角色管理 | 定义聚合规则，组合权限 | 稳定 | 便于审计 | 检查aggregationRule |
| **定期审计权限** | 发现过度授权 | 使用工具如rbac-police | 稳定 | 权限膨胀 | 定期执行审计脚本 |

## Secrets管理

| 实践领域 | 最佳实践 | 实施步骤 | 版本要求 | 安全影响 | ACK集成 |
|---------|---------|---------|---------|---------|---------|
| **etcd加密** | 加密存储的Secrets | 配置EncryptionConfiguration | v1.13+ | 防止etcd数据泄露 | 托管版自动加密 |
| **外部Secret管理** | 使用Vault/KMS | 部署External Secrets Operator | 外部工具 | 集中管理，审计追踪 | 阿里云KMS集成 |
| **限制Secret访问** | RBAC控制 | 仅授权必需的SA访问 | 稳定 | 防止未授权访问 | RAM策略集成 |
| **Secret轮换** | 定期更新凭证 | 自动化轮换流程 | 外部工具 | 限制泄露影响 | KMS自动轮换 |
| **避免环境变量** | 使用卷挂载 | `secretKeyRef`改为`volumeMounts` | 稳定 | 环境变量易泄露 | - |
| **审计Secret访问** | 记录访问日志 | 启用API审计日志 | v1.29增强 | 追踪访问行为 | SLS审计集成 |

## 网络安全

| 实践领域 | 最佳实践 | 实施步骤 | 版本要求 | 风险说明 | 工具支持 |
|---------|---------|---------|---------|---------|---------|
| **默认拒绝策略** | 默认禁止所有流量 | 创建deny-all NetworkPolicy | 稳定 | 未授权访问 | Calico/Cilium |
| **命名空间隔离** | 限制跨NS通信 | 配置NS级NetworkPolicy | 稳定 | 横向移动 | CNI支持 |
| **出站流量控制** | 限制Egress | 白名单外部访问 | 稳定 | 数据外泄 | Egress NetworkPolicy |
| **mTLS** | 加密服务间通信 | 部署Service Mesh | 外部工具 | 中间人攻击 | Istio/Linkerd |
| **API Server访问限制** | 限制源IP | 配置--api-server-allow-cidrs | 云平台 | 未授权API访问 | ACK白名单 |

## 容器安全

| 实践领域 | 最佳实践 | 实施步骤 | 版本要求 | 风险说明 | 验证方法 |
|---------|---------|---------|---------|---------|---------|
| **非root运行** | runAsNonRoot: true | Pod SecurityContext配置 | 稳定 | 容器逃逸风险 | PSA restricted |
| **只读根文件系统** | readOnlyRootFilesystem: true | 配置emptyDir用于写入 | 稳定 | 恶意文件写入 | PSA restricted |
| **禁止特权容器** | privileged: false | SecurityContext配置 | 稳定 | 完全主机访问 | PSA baseline |
| **限制Capabilities** | drop ALL，仅添加必需 | 配置capabilities | 稳定 | 权限提升 | PSA restricted |
| **禁止主机命名空间** | hostNetwork/PID/IPC: false | Pod spec配置 | 稳定 | 主机级访问 | PSA baseline |
| **镜像签名验证** | 验证镜像来源 | 配置ImagePolicyWebhook | v1.28增强 | 供应链攻击 | Sigstore/Cosign |
| **漏洞扫描** | 扫描已知CVE | CI集成Trivy/Clair | 外部工具 | 已知漏洞利用 | ACR扫描 |

## 审计配置

| 审计级别 | 记录内容 | 适用资源 | 性能影响 | 存储需求 |
|---------|---------|---------|---------|---------|
| **None** | 不记录 | 健康检查等 | 无 | 无 |
| **Metadata** | 请求元数据 | 大多数资源 | 低 | 中等 |
| **Request** | 元数据+请求体 | 敏感资源 | 中 | 较高 |
| **RequestResponse** | 元数据+请求+响应 | 关键资源 | 高 | 很高 |

```yaml
# 审计策略示例
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # 不记录健康检查
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
      - group: ""
        resources: ["endpoints", "services", "services/status"]
  # Secrets访问记录Request级别
  - level: Request
    resources:
      - group: ""
        resources: ["secrets", "configmaps"]
  # 其他记录Metadata
  - level: Metadata
    omitStages:
      - "RequestReceived"
```

## 安全检查清单

| 检查项 | 命令/方法 | 期望结果 | 优先级 |
|-------|---------|---------|-------|
| 匿名认证禁用 | 检查apiserver `--anonymous-auth=false` | false | P0 |
| RBAC启用 | `kubectl api-versions \| grep rbac` | 存在 | P0 |
| etcd加密 | 检查EncryptionConfiguration | 已配置 | P0 |
| Pod Security启用 | 检查NS标签 | 已配置 | P1 |
| 审计日志启用 | 检查apiserver `--audit-log-path` | 已配置 | P1 |
| NetworkPolicy存在 | `kubectl get networkpolicy -A` | 存在策略 | P1 |
| 默认SA无特权 | 检查default SA绑定 | 无cluster-admin | P1 |
| Secrets非明文 | `etcdctl get /registry/secrets` | 加密 | P0 |
| 镜像来自可信仓库 | 检查Pod镜像源 | 私有仓库 | P2 |
| 资源限制配置 | `kubectl describe ns` | 存在LimitRange | P2 |

## CIS Kubernetes Benchmark检查

| CIS编号 | 检查项 | 自动化工具 | 版本变更 |
|--------|-------|-----------|---------|
| 1.1.x | API Server文件权限 | kube-bench | 稳定 |
| 1.2.x | API Server参数 | kube-bench | v1.25+ PSA相关 |
| 2.x | etcd配置 | kube-bench | 稳定 |
| 3.x | 控制平面配置 | kube-bench | 稳定 |
| 4.x | Worker节点 | kube-bench | v1.24+ CRI相关 |
| 5.x | Policies | kube-bench | v1.25+ PSA替代PSP |

```bash
# 运行kube-bench
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs -f job/kube-bench
```

---

**安全原则**: 纵深防御，最小权限，持续审计
