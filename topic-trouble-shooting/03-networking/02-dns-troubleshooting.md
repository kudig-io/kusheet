# CoreDNS/DNS 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32, CoreDNS v1.9+ | **最后更新**: 2026-01 | **难度**: 中级-高级

---

## 目录

1. [问题现象与影响分析](#1-问题现象与影响分析)
2. [排查方法与步骤](#2-排查方法与步骤)
3. [解决方案与风险控制](#3-解决方案与风险控制)

---

## 1. 问题现象与影响分析

### 1.1 常见问题现象

#### 1.1.1 CoreDNS 服务不可用

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| CoreDNS Pod 异常 | `CrashLoopBackOff` | kubectl | `kubectl get pods -n kube-system` |
| DNS Service 无 Endpoints | Endpoints 为空 | kubectl | `kubectl get endpoints -n kube-system kube-dns` |
| CoreDNS 配置错误 | `plugin/errors: 2 errors` | CoreDNS 日志 | CoreDNS Pod 日志 |
| 资源不足 | `OOMKilled` | kubectl | `kubectl describe pod` |

#### 1.1.2 DNS 解析失败

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 集群内域名解析失败 | `NXDOMAIN` | nslookup/dig | `nslookup <service>.<ns>.svc.cluster.local` |
| 外部域名解析失败 | `SERVFAIL` | nslookup/dig | `nslookup google.com` |
| 解析超时 | `connection timed out` | nslookup/dig | DNS 查询结果 |
| 间歇性解析失败 | 偶发失败 | 应用日志 | 应用日志 |

#### 1.1.3 DNS 性能问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 解析延迟高 | 响应时间长 | 应用监控 | 应用监控 |
| DNS 请求超时 | `i/o timeout` | 应用日志 | 应用日志 |
| CoreDNS 负载高 | CPU/内存高 | 监控 | `kubectl top pods` |
| 上游 DNS 慢 | `plugin/forward: unhealthy` | CoreDNS 日志 | CoreDNS 日志 |

### 1.2 报错查看方式汇总

```bash
# 查看 CoreDNS Pod 状态
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 查看 CoreDNS 日志
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=200

# 查看 CoreDNS 配置
kubectl get configmap -n kube-system coredns -o yaml

# 查看 DNS Service
kubectl get svc -n kube-system kube-dns
kubectl get endpoints -n kube-system kube-dns

# 在 Pod 内测试 DNS
kubectl run test-dns --rm -it --image=busybox:1.28 -- sh
# 在 Pod 内执行
nslookup kubernetes.default
nslookup google.com

# 使用 dnsutils 镜像进行详细测试
kubectl run dnsutils --rm -it --image=registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3 -- sh
# 在 Pod 内执行
dig kubernetes.default.svc.cluster.local
dig @10.96.0.10 kubernetes.default.svc.cluster.local

# 查看 Pod 的 DNS 配置
kubectl exec <pod-name> -- cat /etc/resolv.conf
```

### 1.3 影响面分析

#### 1.3.1 直接影响

| 影响范围 | 影响程度 | 影响描述 |
|----------|----------|----------|
| **Service 发现** | 完全失效 | 通过 DNS 名称的服务发现不可用 |
| **外部域名解析** | 失效 | Pod 无法解析外部域名 |
| **Ingress** | 部分影响 | 基于名称的路由可能受影响 |
| **证书验证** | 可能失败 | HTTPS 证书验证需要 DNS |

#### 1.3.2 间接影响

| 影响范围 | 影响程度 | 影响描述 |
|----------|----------|----------|
| **服务间调用** | 高 | 使用 Service 名称的调用失败 |
| **数据库连接** | 可能失败 | 外部数据库连接可能失败 |
| **外部 API** | 失败 | 调用外部 API 失败 |
| **镜像拉取** | 可能失败 | 使用域名的镜像仓库不可用 |

---

## 2. 排查方法与步骤

### 2.1 排查原理

CoreDNS 是 Kubernetes 集群的 DNS 服务，负责服务发现和外部域名解析。排查需要从以下层面：

1. **服务层面**：CoreDNS Pod 是否正常运行
2. **配置层面**：CoreDNS 配置是否正确
3. **网络层面**：Pod 到 CoreDNS 的网络是否通畅
4. **上游层面**：上游 DNS 是否正常
5. **客户端层面**：Pod 的 DNS 配置是否正确

### 2.2 排查步骤和具体命令

#### 2.2.1 第一步：检查 CoreDNS 状态

```bash
# 查看 CoreDNS Pod 状态
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide

# 查看 Pod 详情
kubectl describe pod -n kube-system -l k8s-app=kube-dns

# 查看 CoreDNS Deployment
kubectl get deployment -n kube-system coredns

# 查看 DNS Service
kubectl get svc -n kube-system kube-dns -o yaml

# 验证 Endpoints 存在
kubectl get endpoints -n kube-system kube-dns
```

#### 2.2.2 第二步：检查 CoreDNS 配置

```bash
# 查看 CoreDNS ConfigMap
kubectl get configmap -n kube-system coredns -o yaml

# 检查 Corefile 语法
# CoreDNS 配置示例
# .:53 {
#     errors
#     health {
#        lameduck 5s
#     }
#     ready
#     kubernetes cluster.local in-addr.arpa ip6.arpa {
#        pods insecure
#        fallthrough in-addr.arpa ip6.arpa
#        ttl 30
#     }
#     prometheus :9153
#     forward . /etc/resolv.conf {
#        max_concurrent 1000
#     }
#     cache 30
#     loop
#     reload
#     loadbalance
# }

# 查看 CoreDNS 日志检查配置错误
kubectl logs -n kube-system -l k8s-app=kube-dns | grep -i "error"
```

#### 2.2.3 第三步：测试 DNS 解析

```bash
# 创建测试 Pod
kubectl run test-dns --rm -it --image=busybox:1.28 -- sh

# 在测试 Pod 内执行
# 测试集群内域名
nslookup kubernetes.default
nslookup kube-dns.kube-system.svc.cluster.local

# 测试外部域名
nslookup google.com

# 查看 DNS 配置
cat /etc/resolv.conf

# 使用 dig 进行详细测试（需要 dnsutils 镜像）
kubectl run dnsutils --rm -it --image=registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3 -- sh
dig kubernetes.default.svc.cluster.local
dig +trace google.com
```

#### 2.2.4 第四步：检查网络连通性

```bash
# 在测试 Pod 内检查到 CoreDNS 的连通性
# 获取 kube-dns ClusterIP
kubectl get svc -n kube-system kube-dns -o jsonpath='{.spec.clusterIP}'

# 在 Pod 内测试
nc -zvu <kube-dns-ip> 53

# 检查 kube-proxy 规则
iptables -t nat -L -n | grep <kube-dns-ip>

# 检查 Pod 到 CoreDNS Pod 的连通性
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
# 直接 ping CoreDNS Pod IP
ping <coredns-pod-ip>
```

#### 2.2.5 第五步：检查上游 DNS

```bash
# 查看节点的 DNS 配置
cat /etc/resolv.conf

# 测试节点上的 DNS 解析
nslookup google.com
dig google.com

# 查看 CoreDNS 上游配置
kubectl get configmap -n kube-system coredns -o yaml | grep -A5 forward

# 检查 CoreDNS 日志中的上游错误
kubectl logs -n kube-system -l k8s-app=kube-dns | grep -i "forward"
```

#### 2.2.6 第六步：检查 DNS 性能

```bash
# 查看 CoreDNS 指标
kubectl port-forward -n kube-system svc/kube-dns 9153:9153 &
curl http://localhost:9153/metrics

# 关键指标
# coredns_dns_request_duration_seconds - 请求延迟
# coredns_dns_requests_total - 请求总数
# coredns_dns_responses_total - 响应总数
# coredns_forward_healthcheck_failures_total - 上游健康检查失败

# 查看 CoreDNS 资源使用
kubectl top pods -n kube-system -l k8s-app=kube-dns

# 检查是否有大量错误
kubectl logs -n kube-system -l k8s-app=kube-dns | grep -c "NXDOMAIN"
kubectl logs -n kube-system -l k8s-app=kube-dns | grep -c "SERVFAIL"
```

### 2.3 排查注意事项

| 注意项 | 说明 | 建议 |
|--------|------|------|
| **ndots 设置** | 影响解析行为 | 检查 ndots 配置 |
| **search 域** | 影响短域名解析 | 检查 search 配置 |
| **DNS 策略** | Pod 的 dnsPolicy | 检查 Pod spec |
| **缓存** | CoreDNS 缓存影响更新 | 考虑缓存时间 |

---

## 3. 解决方案与风险控制

### 3.1 CoreDNS Pod 异常

#### 3.1.1 解决步骤

```bash
# 步骤 1：检查 Pod 状态
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl describe pod -n kube-system <coredns-pod>

# 步骤 2：查看错误日志
kubectl logs -n kube-system <coredns-pod> --previous

# 步骤 3：检查配置是否有语法错误
kubectl get configmap -n kube-system coredns -o yaml

# 步骤 4：如果是资源不足，增加资源限制
kubectl edit deployment -n kube-system coredns
# 修改 resources:
#   requests:
#     cpu: 100m
#     memory: 70Mi
#   limits:
#     cpu: 1000m
#     memory: 170Mi

# 步骤 5：如果是配置错误，修复配置
kubectl edit configmap -n kube-system coredns

# 步骤 6：重启 CoreDNS
kubectl rollout restart deployment -n kube-system coredns

# 步骤 7：验证恢复
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl run test --rm -it --image=busybox -- nslookup kubernetes
```

#### 3.1.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **高** | 重启期间 DNS 短暂不可用 | 确保多副本 |
| **中** | 配置错误导致无法启动 | 修改前备份 |

#### 3.1.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. CoreDNS 是关键服务，修改需谨慎
2. 确保至少有 2 个 CoreDNS 副本
3. 配置变更前先在测试环境验证
4. 修改后立即测试 DNS 解析
5. 考虑使用 PodDisruptionBudget
```

### 3.2 DNS 解析失败

#### 3.2.1 解决步骤

```bash
# 步骤 1：确认故障范围
# 测试集群内域名
kubectl run test --rm -it --image=busybox -- nslookup kubernetes.default

# 测试外部域名
kubectl run test --rm -it --image=busybox -- nslookup google.com

# 步骤 2：如果集群内域名失败
# 检查 kubernetes 插件配置
kubectl get configmap -n kube-system coredns -o yaml | grep -A10 "kubernetes"

# 检查 cluster.local 域是否正确
kubectl get configmap -n kube-system coredns -o yaml | grep "cluster.local"

# 步骤 3：如果外部域名失败
# 检查 forward 配置
kubectl get configmap -n kube-system coredns -o yaml | grep -A5 "forward"

# 检查上游 DNS 是否可达
kubectl exec -n kube-system <coredns-pod> -- nslookup google.com 8.8.8.8

# 步骤 4：修复配置（如果需要）
kubectl edit configmap -n kube-system coredns

# 常见修复：指定可靠的上游 DNS
# forward . 8.8.8.8 8.8.4.4 {
#    max_concurrent 1000
# }

# 步骤 5：重新加载配置
kubectl rollout restart deployment -n kube-system coredns

# 步骤 6：验证修复
kubectl run test --rm -it --image=busybox -- nslookup kubernetes.default
kubectl run test --rm -it --image=busybox -- nslookup google.com
```

#### 3.2.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 上游 DNS 变更可能影响解析 | 使用可靠的公共 DNS |
| **低** | 测试解析无风险 | - |

#### 3.2.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 上游 DNS 应该可靠且低延迟
2. 考虑配置多个上游 DNS 备份
3. 企业环境考虑使用内部 DNS
4. 注意 DNS 流量的安全性
5. 监控 DNS 解析延迟
```

### 3.3 DNS 性能优化

#### 3.3.1 解决步骤

```bash
# 步骤 1：检查当前性能
kubectl top pods -n kube-system -l k8s-app=kube-dns

# 步骤 2：扩展 CoreDNS 副本数
kubectl scale deployment -n kube-system coredns --replicas=3

# 步骤 3：优化 CoreDNS 配置
kubectl edit configmap -n kube-system coredns
# 优化配置示例：
# .:53 {
#     errors
#     health {
#        lameduck 5s
#     }
#     ready
#     kubernetes cluster.local in-addr.arpa ip6.arpa {
#        pods insecure
#        fallthrough in-addr.arpa ip6.arpa
#        ttl 30
#     }
#     prometheus :9153
#     forward . 8.8.8.8 8.8.4.4 {
#        max_concurrent 1000
#        policy sequential
#     }
#     cache 60 {
#        success 9984 60
#        denial 9984 5
#     }
#     loop
#     reload
#     loadbalance
# }

# 步骤 4：考虑启用 NodeLocal DNSCache
# 部署 NodeLocal DNSCache
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/nodelocaldns/nodelocaldns.yaml

# 步骤 5：增加资源限制
kubectl edit deployment -n kube-system coredns
# resources:
#   requests:
#     cpu: 200m
#     memory: 128Mi
#   limits:
#     cpu: 2000m
#     memory: 512Mi

# 步骤 6：应用配置
kubectl rollout restart deployment -n kube-system coredns

# 步骤 7：验证性能改善
# 测试解析延迟
time kubectl run test --rm -it --image=busybox -- nslookup kubernetes.default
```

#### 3.3.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | NodeLocal DNS 部署复杂 | 先在测试环境验证 |
| **低** | 扩展副本数一般无风险 | 确保资源充足 |
| **中** | 配置变更需要重启 | 确保多副本 |

#### 3.3.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. DNS 扩容需要评估节点资源
2. NodeLocal DNSCache 需要节点支持
3. 缓存时间过长可能导致更新延迟
4. 监控 DNS 请求量和延迟
5. 考虑 DNS 查询的 QPS 限制
```

### 3.4 Pod DNS 配置问题

#### 3.4.1 解决步骤

```bash
# 步骤 1：检查 Pod 的 DNS 配置
kubectl exec <pod-name> -- cat /etc/resolv.conf

# 步骤 2：检查 Pod 的 dnsPolicy
kubectl get pod <pod-name> -o yaml | grep -A10 dnsPolicy

# dnsPolicy 说明：
# - ClusterFirst: 优先使用集群 DNS（默认）
# - ClusterFirstWithHostNet: hostNetwork Pod 使用集群 DNS
# - Default: 使用节点 DNS 配置
# - None: 完全自定义 DNS

# 步骤 3：如果需要自定义 DNS，使用 dnsConfig
kubectl patch pod <pod-name> -p '{
  "spec": {
    "dnsPolicy": "None",
    "dnsConfig": {
      "nameservers": ["10.96.0.10"],
      "searches": ["default.svc.cluster.local", "svc.cluster.local", "cluster.local"],
      "options": [{"name": "ndots", "value": "5"}]
    }
  }
}'

# 步骤 4：调整 ndots（减少不必要的搜索）
# 对于频繁解析外部域名的应用
# dnsConfig:
#   options:
#     - name: ndots
#       value: "1"

# 步骤 5：使用 FQDN 减少搜索
# 应用中使用完整域名：google.com.（注意末尾的点）

# 步骤 6：验证 DNS 配置
kubectl exec <pod-name> -- cat /etc/resolv.conf
kubectl exec <pod-name> -- nslookup kubernetes.default.svc.cluster.local
```

#### 3.4.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **低** | DNS 策略变更影响解析行为 | 测试后再应用 |
| **低** | ndots 调整影响短域名解析 | 理解业务需求 |

#### 3.4.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 不同 dnsPolicy 行为不同，理解后再配置
2. ndots 设置影响解析性能
3. hostNetwork Pod 默认不使用集群 DNS
4. 自定义 DNS 配置需要维护
5. 使用 FQDN 可以提高解析效率
```

---

## 附录

### A. CoreDNS 关键指标

| 指标名称 | 说明 | 告警阈值建议 |
|----------|------|--------------|
| `coredns_dns_request_duration_seconds` | 请求延迟 | P99 > 100ms |
| `coredns_dns_requests_total` | 请求总数 | 监控趋势 |
| `coredns_dns_responses_total{rcode="SERVFAIL"}` | 失败响应 | > 1% |
| `coredns_forward_healthcheck_failures_total` | 上游失败 | > 0 |

### B. 常见 DNS 策略

| 策略 | 说明 | 适用场景 |
|------|------|----------|
| ClusterFirst | 优先集群 DNS | 大多数 Pod |
| ClusterFirstWithHostNet | hostNetwork 用集群 DNS | hostNetwork Pod |
| Default | 继承节点 DNS | 需要节点 DNS |
| None | 完全自定义 | 特殊需求 |

### C. DNS 调试清单

- [ ] CoreDNS Pod 正常运行
- [ ] kube-dns Service 有 Endpoints
- [ ] Pod 到 CoreDNS 网络通畅
- [ ] CoreDNS 配置正确
- [ ] 上游 DNS 可用
- [ ] Pod resolv.conf 正确
- [ ] ndots 设置合理
