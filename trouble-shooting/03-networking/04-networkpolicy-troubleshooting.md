# NetworkPolicy 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 中级-高级

---

## 目录

1. [问题现象与影响分析](#1-问题现象与影响分析)
2. [排查方法与步骤](#2-排查方法与步骤)
3. [解决方案与风险控制](#3-解决方案与风险控制)

---

## 1. 问题现象与影响分析

### 1.1 常见问题现象

#### 1.1.1 NetworkPolicy 不生效

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 流量未被阻止 | 应能阻止的流量仍可通过 | 网络测试 | curl/nc/ping |
| 策略创建成功但无效 | 无报错但不生效 | kubectl | `kubectl get networkpolicy` |
| CNI 不支持 | 策略被忽略 | CNI 日志 | CNI Pod 日志 |
| 策略冲突 | 多个策略行为不一致 | 网络测试 | 测试结果分析 |

#### 1.1.2 NetworkPolicy 阻止正常流量

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| Pod 间通信失败 | `connection refused/timeout` | 应用 | 应用日志/curl |
| DNS 解析失败 | `NXDOMAIN/timeout` | 应用 | nslookup |
| 外网访问被阻 | `no route to host` | 应用 | curl |
| 服务发现失败 | Service 不可达 | 应用 | 应用日志 |

#### 1.1.3 策略配置错误

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| selector 不匹配 | 策略未应用到目标 Pod | kubectl | `kubectl describe networkpolicy` |
| 端口配置错误 | 端口未正确开放 | 网络测试 | nc/telnet |
| 命名空间选择器错误 | 跨 NS 流量被错误处理 | 网络测试 | curl |
| CIDR 配置错误 | IP 范围不正确 | 网络测试 | curl |

### 1.2 报错查看方式汇总

```bash
# 查看 NetworkPolicy 列表
kubectl get networkpolicy -A
kubectl get netpol -A  # 简写

# 查看 NetworkPolicy 详情
kubectl describe networkpolicy <policy-name> -n <namespace>
kubectl get networkpolicy <policy-name> -n <namespace> -o yaml

# 检查 Pod 标签（确认 selector 匹配）
kubectl get pods -n <namespace> --show-labels
kubectl get pods -n <namespace> -l <label-selector>

# 检查 Namespace 标签
kubectl get namespaces --show-labels

# 测试网络连通性
kubectl run test --rm -it --image=busybox -- sh
# 在 Pod 内
nc -zv <target-ip> <port>
wget -qO- --timeout=5 http://<target-ip>:<port>

# 检查 CNI 是否支持 NetworkPolicy
kubectl get pods -n kube-system | grep -E "(calico|cilium|weave)"

# Calico 查看策略
calicoctl get networkpolicy -A
calicoctl get globalnetworkpolicy

# Cilium 查看策略
cilium policy get
kubectl get ciliumnetworkpolicies -A
```

### 1.3 影响面分析

#### 1.3.1 直接影响

| 影响范围 | 影响程度 | 影响描述 |
|----------|----------|----------|
| **策略不生效** | 安全风险 | 网络隔离失效，可能导致安全问题 |
| **阻止正常流量** | 服务中断 | 应用间通信失败，服务不可用 |
| **DNS 被阻** | 全面影响 | 服务发现失败，所有依赖 DNS 的功能受影响 |
| **出站被阻** | 部分影响 | 无法访问外部服务 |

#### 1.3.2 间接影响

| 影响范围 | 影响程度 | 影响描述 |
|----------|----------|----------|
| **监控采集** | 可能失败 | Prometheus 无法 scrape 指标 |
| **日志采集** | 可能失败 | 日志 agent 无法连接 |
| **健康检查** | 可能失败 | 外部健康检查被阻止 |
| **CI/CD** | 可能失败 | 部署工具无法访问集群 |

#### 1.3.3 NetworkPolicy 工作原理

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       NetworkPolicy 流量控制模型                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   1. 默认行为（无 NetworkPolicy）                                            │
│      - 所有 Pod 可以相互通信                                                 │
│      - 所有入站和出站流量都允许                                              │
│                                                                              │
│   2. 有 NetworkPolicy 选中 Pod                                               │
│      - 默认拒绝所有未明确允许的流量                                          │
│      - 入站规则（Ingress）：控制哪些流量可以进入 Pod                         │
│      - 出站规则（Egress）：控制 Pod 可以访问哪些目标                         │
│                                                                              │
│   3. 流量匹配逻辑                                                            │
│      - 多个 NetworkPolicy 的规则是 OR 关系                                   │
│      - 同一个 NetworkPolicy 内的多个 from/to 是 OR 关系                      │
│      - from/to 内的多个条件是 AND 关系                                       │
│                                                                              │
│   Pod A ──[NetworkPolicy]──► Pod B                                           │
│                                                                              │
│   检查顺序：                                                                 │
│   ① Pod A 的 Egress 规则是否允许到 Pod B？                                   │
│   ② Pod B 的 Ingress 规则是否允许来自 Pod A？                                │
│   ③ 两者都允许才能通信                                                       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 排查方法与步骤

### 2.1 排查原理

NetworkPolicy 是 Kubernetes 的网络隔离机制，由 CNI 插件实现。排查需要从以下层面：

1. **CNI 支持**：确认 CNI 是否支持 NetworkPolicy
2. **策略配置**：检查策略语法和逻辑是否正确
3. **选择器匹配**：确认 Pod 和 Namespace 选择器正确
4. **规则逻辑**：分析 Ingress/Egress 规则是否符合预期
5. **实际效果**：通过网络测试验证策略效果

### 2.2 排查步骤和具体命令

#### 2.2.1 第一步：确认 CNI 支持 NetworkPolicy

```bash
# 检查使用的 CNI 插件
kubectl get pods -n kube-system | grep -E "(calico|cilium|weave|canal)"

# 支持 NetworkPolicy 的 CNI：
# - Calico ✓
# - Cilium ✓
# - Weave Net ✓
# - Canal (Calico + Flannel) ✓
# - Antrea ✓
# - Kube-router ✓

# 不支持或需要额外配置的 CNI：
# - Flannel ✗ (需要配合 Calico)
# - Kubenet ✗

# 验证 CNI 是否正确处理 NetworkPolicy
# Calico
calicoctl node status
kubectl logs -n kube-system -l k8s-app=calico-node | grep -i policy

# Cilium
cilium status
cilium policy get
```

#### 2.2.2 第二步：检查 NetworkPolicy 配置

```bash
# 列出命名空间中的所有 NetworkPolicy
kubectl get networkpolicy -n <namespace>

# 查看 NetworkPolicy 详细配置
kubectl get networkpolicy <policy-name> -n <namespace> -o yaml

# 关键检查点：
# 1. spec.podSelector - 确认选中正确的 Pod
# 2. spec.policyTypes - 确认策略类型（Ingress/Egress）
# 3. spec.ingress/egress - 确认规则配置正确

# 示例：检查 podSelector 匹配的 Pod
SELECTOR=$(kubectl get networkpolicy <policy-name> -n <namespace> -o jsonpath='{.spec.podSelector.matchLabels}')
echo "Policy selector: $SELECTOR"
kubectl get pods -n <namespace> -l <label-key>=<label-value>
```

#### 2.2.3 第三步：测试网络连通性

```bash
# 创建测试 Pod（在源命名空间）
kubectl run test-source --rm -it --image=busybox -n <source-ns> -- sh

# 在测试 Pod 内测试连通性
# TCP 连接测试
nc -zv <target-pod-ip> <port>
nc -zv <service-name>.<target-ns>.svc.cluster.local <port>

# HTTP 请求测试
wget -qO- --timeout=5 http://<target>:<port>/
curl -v --connect-timeout 5 http://<target>:<port>/

# DNS 测试
nslookup kubernetes.default

# 从特定 Pod 测试
kubectl exec -it <pod-name> -n <namespace> -- nc -zv <target> <port>
```

#### 2.2.4 第四步：分析策略逻辑

```bash
# 检查影响目标 Pod 的所有 NetworkPolicy
kubectl get networkpolicy -n <namespace> -o json | \
  jq -r '.items[] | select(.spec.podSelector.matchLabels.<label-key>=="<label-value>") | .metadata.name'

# 或者使用 kubectl describe
kubectl describe pod <pod-name> -n <namespace> | grep -A20 "Labels:"

# 逐条分析 NetworkPolicy 规则
kubectl get networkpolicy <policy-name> -n <namespace> -o yaml

# 使用 Calico 的策略分析
calicoctl get networkpolicy -n <namespace> -o yaml
calicoctl get globalnetworkpolicy -o yaml

# 使用 Cilium 的策略分析
cilium policy trace --src-k8s-pod <src-ns>:<src-pod> --dst-k8s-pod <dst-ns>:<dst-pod> --dport <port>
```

#### 2.2.5 第五步：检查常见遗漏

```bash
# 检查 DNS 是否被允许（常见遗漏）
# kube-dns/CoreDNS 通常在 kube-system 命名空间，需要允许出站到 UDP 53

# 检查 Namespace 标签（跨 NS 策略需要）
kubectl get namespace <target-ns> --show-labels

# 检查是否有 Default Deny 策略
kubectl get networkpolicy -n <namespace> -o yaml | grep -A5 "policyTypes"
```

### 2.3 排查注意事项

| 注意项 | 说明 | 建议 |
|--------|------|------|
| **CNI 兼容性** | 不同 CNI 对 NetworkPolicy 支持程度不同 | 确认 CNI 支持所有使用的功能 |
| **DNS 访问** | 策略可能意外阻止 DNS | 总是允许到 kube-dns 的出站流量 |
| **测试环境** | 策略应先在测试环境验证 | 避免直接在生产环境实施 |
| **渐进式实施** | 从宽松到严格逐步收紧 | 避免一次性实施过于严格的策略 |
| **日志记录** | 某些 CNI 支持策略日志 | 启用日志便于排查 |

---

## 3. 解决方案与风险控制

### 3.1 NetworkPolicy 不生效

#### 3.1.1 解决步骤

```bash
# 步骤 1：确认 CNI 支持
kubectl get pods -n kube-system | grep -E "(calico|cilium)"

# 如果使用 Flannel，需要安装 Calico 策略引擎
# 参考: https://docs.projectcalico.org/getting-started/kubernetes/flannel/flannel

# 步骤 2：检查 podSelector 是否正确
kubectl get networkpolicy <name> -n <namespace> -o jsonpath='{.spec.podSelector}'
kubectl get pods -n <namespace> --show-labels

# 步骤 3：验证策略已被 CNI 同步
# Calico
calicoctl get networkpolicy -n <namespace>

# Cilium
cilium policy get

# 步骤 4：检查策略类型是否正确声明
kubectl get networkpolicy <name> -n <namespace> -o jsonpath='{.spec.policyTypes}'
# 如果只想控制入站，policyTypes 应包含 "Ingress"
# 如果只想控制出站，policyTypes 应包含 "Egress"

# 步骤 5：测试验证
kubectl run test --rm -it --image=busybox -n <namespace> -- nc -zv <target> <port>
```

#### 3.1.2 安全生产风险提示

```
⚠️  安全生产风险提示：
1. NetworkPolicy 不生效意味着网络隔离失效
2. 先在非生产环境验证 CNI 支持情况
3. 策略变更可能影响安全合规
4. 确保 CNI 插件版本支持所需功能
5. 考虑使用 CNI 原生策略（如 CiliumNetworkPolicy）获得更多功能
```

### 3.2 阻止正常流量 - DNS 问题

#### 3.2.1 解决步骤

```bash
# 步骤 1：确认 DNS 被阻止
kubectl run test --rm -it --image=busybox -n <namespace> -- nslookup kubernetes.default
# 如果超时，说明 DNS 被阻止

# 步骤 2：添加允许 DNS 的出站规则
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: <namespace>
spec:
  podSelector: {}  # 选择所有 Pod
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF

# 步骤 3：验证 DNS 恢复
kubectl run test --rm -it --image=busybox -n <namespace> -- nslookup kubernetes.default
```

#### 3.2.2 安全生产风险提示

```
⚠️  安全生产风险提示：
1. DNS 是基础服务，阻止 DNS 会影响所有服务发现
2. 实施 NetworkPolicy 时必须考虑 DNS 访问
3. 建议使用命名空间选择器而非 IP 选择 DNS
4. kube-system 命名空间的标签可能因集群而异
```

### 3.3 阻止正常流量 - 服务间通信

#### 3.3.1 解决步骤

```bash
# 步骤 1：确认通信被阻止
kubectl exec -it <source-pod> -n <source-ns> -- nc -zv <target-svc>.<target-ns>.svc.cluster.local <port>

# 步骤 2：检查目标 Pod 的 NetworkPolicy
kubectl get networkpolicy -n <target-ns>

# 步骤 3：添加允许入站的规则
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-source
  namespace: <target-ns>
spec:
  podSelector:
    matchLabels:
      app: <target-app>  # 目标 Pod 的标签
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: <source-ns>  # 源命名空间标签
      podSelector:
        matchLabels:
          app: <source-app>  # 源 Pod 标签
    ports:
    - protocol: TCP
      port: <target-port>
EOF

# 步骤 4：如果源 Pod 有 Egress 策略，也需要允许出站
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-to-target
  namespace: <source-ns>
spec:
  podSelector:
    matchLabels:
      app: <source-app>
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: <target-ns>
      podSelector:
        matchLabels:
          app: <target-app>
    ports:
    - protocol: TCP
      port: <target-port>
EOF

# 步骤 5：验证通信恢复
kubectl exec -it <source-pod> -n <source-ns> -- nc -zv <target-svc>.<target-ns>.svc.cluster.local <port>
```

#### 3.3.2 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 添加策略前先明确通信需求
2. 同时检查 Ingress 和 Egress 方向
3. 使用最小权限原则，只开放必要的端口
4. 跨命名空间通信需要正确配置命名空间标签
5. 策略变更后验证所有相关的通信路径
```

### 3.4 常用 NetworkPolicy 模板

#### 3.4.1 默认拒绝所有入站流量

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

#### 3.4.2 默认拒绝所有出站流量

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Egress
```

#### 3.4.3 允许同命名空间通信

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
```

#### 3.4.4 允许特定端口的入站

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-http-ingress
  namespace: <namespace>
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  ingress:
  - from: []  # 允许任何来源
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
```

#### 3.4.5 允许访问外网（带 DNS）

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-egress
  namespace: <namespace>
spec:
  podSelector:
    matchLabels:
      app: external-access
  policyTypes:
  - Egress
  egress:
  # 允许 DNS
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
  # 允许访问外网
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 10.0.0.0/8      # 排除私有网络
        - 172.16.0.0/12
        - 192.168.0.0/16
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
```

---

## 附录

### A. NetworkPolicy 字段说明

| 字段 | 说明 | 必需 |
|------|------|------|
| `spec.podSelector` | 选择策略应用的 Pod | 是 |
| `spec.policyTypes` | 策略类型（Ingress/Egress） | 建议指定 |
| `spec.ingress` | 入站规则 | 否 |
| `spec.egress` | 出站规则 | 否 |
| `from/to.podSelector` | 匹配 Pod | 否 |
| `from/to.namespaceSelector` | 匹配 Namespace | 否 |
| `from/to.ipBlock` | 匹配 IP 范围 | 否 |
| `ports` | 允许的端口 | 否 |

### B. 常见选择器组合

| 组合 | 含义 |
|------|------|
| `podSelector: {}` | 选择所有 Pod |
| `namespaceSelector: {}` | 选择所有 Namespace |
| `podSelector + namespaceSelector` | 同时满足两个条件 |
| `- podSelector: {...}` 和 `- namespaceSelector: {...}` | 满足任一条件 |

### C. 排查清单

- [ ] CNI 支持 NetworkPolicy
- [ ] podSelector 正确匹配目标 Pod
- [ ] policyTypes 正确声明
- [ ] Ingress 和 Egress 规则都检查
- [ ] DNS 访问被允许
- [ ] 端口号和协议正确
- [ ] 命名空间标签正确（跨 NS 场景）
- [ ] 测试验证策略效果
