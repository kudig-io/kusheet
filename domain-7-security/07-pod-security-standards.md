# 66 - Pod安全标准详解

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/security/pod-security-standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)

## Pod Security Standards (PSS) 级别

| 级别 | 限制程度 | 适用场景 | 特点 | 安全性 |
|-----|---------|---------|------|-------|
| **Privileged** | 无限制 | 系统组件、基础设施 | 不受任何限制 | 低 |
| **Baseline** | 基础限制 | 一般工作负载 | 防止已知提权 | 中 |
| **Restricted** | 严格限制 | 安全敏感工作负载 | 最佳安全实践 | 高 |

## PSS级别详细对比

| 控制项 | Privileged | Baseline | Restricted |
|-------|-----------|----------|------------|
| 特权容器 | ✅ | ❌ | ❌ |
| hostNetwork | ✅ | ❌ | ❌ |
| hostPID | ✅ | ❌ | ❌ |
| hostIPC | ✅ | ❌ | ❌ |
| hostPath卷 | ✅ | ✅ | ❌ |
| 任意Capabilities | ✅ | 部分 | 仅NET_BIND_SERVICE |
| 特权提升 | ✅ | ✅ | ❌ |
| 非root运行 | 可选 | 可选 | 必须 |
| Seccomp | 可选 | 推荐 | 必须 |
| 只读根文件系统 | 可选 | 可选 | 推荐 |

## PSS执行模式

| 模式 | 效果 | 说明 |
|-----|------|------|
| enforce | 拒绝违规Pod | 生产环境使用 |
| audit | 记录审计日志 | 监控违规情况 |
| warn | 返回警告信息 | 迁移过渡期使用 |

## 命名空间标签配置

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    # 强制执行restricted级别
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.32
    
    # 审计baseline级别
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/audit-version: v1.32
    
    # 警告baseline级别
    pod-security.kubernetes.io/warn: baseline
    pod-security.kubernetes.io/warn-version: v1.32
```

## Baseline级别限制

| 控制项 | 允许值 | 字段路径 |
|-------|-------|---------|
| HostProcess | false | `securityContext.windowsOptions.hostProcess` |
| Host Namespaces | false | `hostNetwork`, `hostPID`, `hostIPC` |
| Privileged | false | `securityContext.privileged` |
| Capabilities | 特定列表 | `securityContext.capabilities.add` |
| HostPath Volumes | 无限制 | `volumes[*].hostPath` |
| Host Ports | 无限制 | `containers[*].ports[*].hostPort` |
| AppArmor | 运行时默认或自定义 | `metadata.annotations` |
| SELinux | 仅允许特定类型 | `securityContext.seLinuxOptions.type` |
| /proc Mount Type | 默认 | `securityContext.procMount` |
| Seccomp | RuntimeDefault或Localhost | `securityContext.seccompProfile.type` |
| Sysctls | 安全子集 | `securityContext.sysctls[*].name` |

## Restricted级别限制

| 控制项 | 要求 | 字段路径 |
|-------|-----|---------|
| Volume Types | 仅允许安全类型 | `volumes[*]` |
| Privilege Escalation | 禁止 | `securityContext.allowPrivilegeEscalation` |
| Running as Non-root | 必须 | `securityContext.runAsNonRoot` |
| Running as Non-root user | 必须 | `securityContext.runAsUser` (非0) |
| Seccomp | RuntimeDefault或Localhost | `securityContext.seccompProfile.type` |
| Capabilities | 仅允许NET_BIND_SERVICE | `securityContext.capabilities` |

## Baseline级别允许的Capabilities

```
AUDIT_WRITE
CHOWN
DAC_OVERRIDE
FOWNER
FSETID
KILL
MKNOD
NET_BIND_SERVICE
SETFCAP
SETGID
SETPCAP
SETUID
SYS_CHROOT
```

## Restricted级别合规Pod示例

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: myapp:v1.0
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    resources:
      limits:
        cpu: "1"
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
  volumes:
  - name: data
    emptyDir: {}
  - name: config
    configMap:
      name: app-config
```

## Restricted允许的Volume类型

```
configMap
csi
downwardAPI
emptyDir
ephemeral
persistentVolumeClaim
projected
secret
```

## 豁免配置

```yaml
# API Server配置
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: PodSecurity
  configuration:
    apiVersion: pod-security.admission.config.k8s.io/v1
    kind: PodSecurityConfiguration
    defaults:
      enforce: baseline
      enforce-version: latest
      audit: restricted
      audit-version: latest
      warn: restricted
      warn-version: latest
    exemptions:
      usernames:
      - system:serviceaccount:kube-system:*
      runtimeClasses:
      - gvisor
      namespaces:
      - kube-system
      - istio-system
```

## PSA迁移步骤

| 步骤 | 操作 | 说明 |
|-----|------|------|
| 1 | 评估现状 | 使用dry-run检查违规 |
| 2 | 设置warn/audit | 收集违规信息 |
| 3 | 修复工作负载 | 更新不合规Pod |
| 4 | 启用enforce | 强制执行 |
| 5 | 持续监控 | 监控审计日志 |

## 检查违规命令

```bash
# 检查命名空间违规情况
kubectl label --dry-run=server --overwrite ns \
  <namespace> pod-security.kubernetes.io/enforce=restricted

# 查看所有命名空间PSA标签
kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels}{"\n"}{end}'

# 审计日志查询
kubectl logs -n kube-system -l component=kube-apiserver | grep "pod-security"
```

## 版本变更记录

| 版本 | 变更内容 | 影响 |
|------|---------|------|
| v1.22 | PodSecurity Admission Alpha | 功能预览 |
| v1.23 | PodSecurity Admission Beta | 可生产使用 |
| v1.25 | PodSecurity Admission GA, PSP移除 | 必须迁移 |
| v1.28 | 用户命名空间支持改进 | 增强隔离 |
| v1.29 | AppArmor注解改为字段 | 配置简化 |
| v1.30 | AppArmor字段GA | 生产可用 |

## 安全加固建议

| 建议 | 说明 | 优先级 |
|-----|------|-------|
| **使用Restricted** | 尽可能使用restricted级别 | P0 |
| **非root运行** | 所有容器以非root运行 | P0 |
| **禁止特权提升** | allowPrivilegeEscalation: false | P0 |
| **只读根文件系统** | readOnlyRootFilesystem: true | P1 |
| **删除所有Capabilities** | drop: ALL | P1 |
| **启用Seccomp** | RuntimeDefault或自定义 | P1 |
| **资源限制** | 设置requests和limits | P1 |
| **网络策略** | 配合NetworkPolicy | P2 |

## ACK Pod安全配置

```bash
# ACK集群默认启用PodSecurity
# 查看集群PSA配置
kubectl get ns --show-labels | grep pod-security

# 批量设置命名空间安全级别
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v kube-); do
  kubectl label ns $ns \
    pod-security.kubernetes.io/enforce=baseline \
    pod-security.kubernetes.io/warn=restricted \
    --overwrite
done
```

---

**Pod安全原则**: 最小权限 + 非root运行 + 禁止特权提升 + 启用Seccomp + 持续审计监控

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)