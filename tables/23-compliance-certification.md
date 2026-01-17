# 表格23：合规与认证表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/security](https://kubernetes.io/docs/concepts/security/)

## 合规标准概览

| 标准 | 适用行业 | K8S相关要求 | 审计频率 |
|-----|---------|------------|---------|
| **CIS Benchmark** | 通用 | 集群安全配置 | 持续 |
| **PCI-DSS** | 支付卡 | 数据保护，访问控制 | 年度 |
| **SOC2** | SaaS | 安全性，可用性 | 年度 |
| **HIPAA** | 医疗 | 数据隐私保护 | 年度 |
| **GDPR** | 欧盟数据 | 数据保护，隐私 | 持续 |
| **等保2.0** | 中国 | 网络安全等级保护 | 年度 |
| **ISO 27001** | 通用 | 信息安全管理 | 年度 |

## CIS Kubernetes Benchmark

| 类别 | 检查项数量 | 关键检查项 | 版本变更 |
|-----|-----------|-----------|---------|
| **1. Control Plane** | 50+ | API Server参数，etcd加密 | v1.8.0 for K8S 1.27+ |
| **2. etcd** | 10+ | 加密通信，权限控制 | 稳定 |
| **3. Control Plane配置** | 20+ | 控制器参数 | 稳定 |
| **4. Worker Node** | 30+ | kubelet配置，文件权限 | v1.24+ CRI相关 |
| **5. Policies** | 30+ | RBAC，PSA，NetworkPolicy | v1.25+ PSA相关 |

```bash
# 运行kube-bench
# 使用Job运行
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml

# 查看结果
kubectl logs job/kube-bench

# 或直接运行
docker run --rm -v /etc:/etc:ro -v /var:/var:ro \
  aquasec/kube-bench:latest run --targets=master,node
```

## CIS关键检查项

| 编号 | 检查项 | 推荐值 | 修复方法 | 影响 |
|-----|-------|-------|---------|------|
| **1.1.1** | API Server进程文件权限 | 644 | `chmod 644 /etc/kubernetes/manifests/kube-apiserver.yaml` | 防止未授权修改 |
| **1.2.1** | 匿名认证禁用 | --anonymous-auth=false | API Server参数 | 防止匿名访问 |
| **1.2.6** | RBAC授权模式 | --authorization-mode包含RBAC | API Server参数 | 强制授权 |
| **1.2.16** | 审计日志启用 | --audit-log-path配置 | API Server参数 | 审计追踪 |
| **1.2.29** | etcd加密 | --encryption-provider-config | API Server参数 | 数据保护 |
| **2.1** | etcd TLS | 配置证书 | etcd参数 | 通信加密 |
| **4.2.1** | kubelet认证 | --anonymous-auth=false | kubelet配置 | 节点安全 |
| **4.2.6** | 只读端口禁用 | --read-only-port=0 | kubelet配置 | 防止信息泄露 |
| **5.1.1** | RBAC限制cluster-admin | 最小化绑定 | 权限审计 | 最小权限 |
| **5.2.1** | Pod安全标准 | enforce: restricted | NS标签 | 容器安全 |
| **5.3.1** | NetworkPolicy | 存在默认拒绝策略 | 创建NetworkPolicy | 网络隔离 |

## 等保2.0 K8S相关要求

| 等保要求 | K8S对应措施 | 实施方法 | 证据收集 |
|---------|------------|---------|---------|
| **身份鉴别** | RBAC+认证 | OIDC/LDAP集成 | 用户列表，权限矩阵 |
| **访问控制** | RBAC | Role/ClusterRole | 角色定义文档 |
| **安全审计** | 审计日志 | API审计配置 | 审计日志样本 |
| **入侵防范** | NetworkPolicy+WAF | 网络策略+Ingress | 策略配置 |
| **数据完整性** | etcd备份+加密 | 备份策略 | 备份记录 |
| **数据保密性** | TLS+Secret加密 | 证书管理 | 加密配置 |
| **数据备份恢复** | etcd快照+Velero | 备份策略 | 恢复测试记录 |

## PCI-DSS K8S要求

| 要求 | 描述 | K8S实施 | 验证方法 |
|-----|------|--------|---------|
| **Req 1** | 防火墙保护 | NetworkPolicy | 策略审计 |
| **Req 2** | 默认密码更改 | Secret管理 | 配置审计 |
| **Req 3** | 保护存储的数据 | etcd加密，PV加密 | 加密验证 |
| **Req 4** | 传输加密 | TLS/mTLS | 证书审计 |
| **Req 6** | 安全开发 | 镜像扫描 | 扫描报告 |
| **Req 7** | 访问控制 | RBAC | 权限审计 |
| **Req 8** | 身份识别 | ServiceAccount | SA审计 |
| **Req 10** | 日志监控 | 审计日志+监控 | 日志样本 |
| **Req 11** | 安全测试 | 渗透测试 | 测试报告 |
| **Req 12** | 安全策略 | 文档化 | 策略文档 |

## 安全扫描工具

| 工具 | 功能 | 扫描对象 | 部署方式 |
|-----|------|---------|---------|
| **kube-bench** | CIS基准检查 | 集群配置 | Job/二进制 |
| **kube-hunter** | 渗透测试 | 集群漏洞 | Job/二进制 |
| **Trivy** | 漏洞扫描 | 镜像/配置 | CLI/Operator |
| **Falco** | 运行时检测 | 系统调用 | DaemonSet |
| **OPA/Gatekeeper** | 策略执行 | 资源定义 | Deployment |
| **Polaris** | 最佳实践检查 | 工作负载配置 | Dashboard |
| **kubescape** | 综合扫描 | 多维度 | CLI/Operator |

```bash
# Trivy镜像扫描
trivy image nginx:latest

# Trivy K8S扫描
trivy k8s --report summary cluster

# kubescape扫描
kubescape scan framework nsa --exclude-namespaces kube-system
kubescape scan framework cis-v1.23
```

## 审计日志配置

```yaml
# 合规审计策略
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # 记录所有认证失败
  - level: Metadata
    omitStages: ["RequestReceived"]
    
  # Secrets操作完整记录
  - level: RequestResponse
    resources:
    - group: ""
      resources: ["secrets"]
    
  # ServiceAccount操作
  - level: Request
    resources:
    - group: ""
      resources: ["serviceaccounts"]
    verbs: ["create", "update", "patch", "delete"]
    
  # RBAC变更
  - level: Request
    resources:
    - group: "rbac.authorization.k8s.io"
      resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
    
  # Pod执行命令
  - level: Request
    resources:
    - group: ""
      resources: ["pods/exec", "pods/attach"]
    
  # 其他Metadata级别
  - level: Metadata
    omitStages: ["RequestReceived"]
```

## 合规检查清单

| 检查项 | 命令/方法 | 合规标准 | 优先级 |
|-------|---------|---------|-------|
| RBAC启用 | `kubectl api-versions \| grep rbac` | 全部 | P0 |
| 审计日志 | 检查API Server参数 | 全部 | P0 |
| etcd加密 | 检查EncryptionConfiguration | PCI/等保 | P0 |
| NetworkPolicy | `kubectl get networkpolicy -A` | PCI/CIS | P1 |
| Pod安全标准 | 检查NS标签 | CIS | P1 |
| TLS证书 | 证书有效期检查 | 全部 | P1 |
| 镜像扫描 | Trivy扫描结果 | PCI | P1 |
| 备份验证 | 恢复测试 | 全部 | P2 |

## ACK合规支持

| 合规项 | ACK支持 | 配置方式 |
|-------|--------|---------|
| **等保2.0** | 三级支持 | 安全加固版 |
| **审计日志** | SLS集成 | 控制台开启 |
| **etcd加密** | 托管自动 | Pro版 |
| **网络隔离** | 安全组+NetworkPolicy | 配置 |
| **漏洞扫描** | ACR集成 | 企业版 |
| **合规报告** | 配置审计 | 云安全中心 |

---

**合规原则**: 持续审计，自动化检查，证据留存
