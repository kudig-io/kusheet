# 表格12：网络组件表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/cluster-administration/networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/)

## CNI插件对比

| 插件 | 架构模式 | 优势 | 劣势 | 兼容版本 | NetworkPolicy | 适用场景 | ACK支持 |
|-----|---------|------|------|---------|--------------|---------|---------|
| **Calico** | BGP/Overlay/VXLAN | 高性能，功能全面，成熟稳定 | 配置复杂 | v1.25+ | 完整支持 | 大规模生产 | 支持 |
| **Flannel** | VXLAN/host-gw | 简单易用，轻量 | 功能有限，无NetworkPolicy | v1.25+ | 不支持 | 小型集群 | 支持 |
| **Cilium** | eBPF | 高性能，可观测性强，功能丰富 | 内核要求高(4.9+) | v1.25+ | 完整支持+增强 | 大规模/安全敏感 | 支持 |
| **Weave Net** | VXLAN | 简单，自动发现 | 性能一般 | v1.25+ | 支持 | 小型集群 | - |
| **Antrea** | OVS/Geneve | VMware生态，高性能 | 生态较小 | v1.25+ | 完整支持 | VMware环境 | - |
| **Terway** | ENI/ENIIP | 阿里云原生，高性能 | 仅阿里云 | v1.25+ | 支持 | ACK推荐 | 原生 |
| **Canal** | Calico+Flannel | 结合两者优势 | 复杂度增加 | v1.25+ | 支持 | 混合需求 | - |

## CNI性能对比

| CNI | 吞吐量 | 延迟 | CPU开销 | 内存开销 | 大规模表现 |
|-----|-------|------|--------|---------|-----------|
| **Calico BGP** | 高 | 低 | 低 | 中 | 优秀 |
| **Calico VXLAN** | 中-高 | 中 | 中 | 中 | 良好 |
| **Cilium eBPF** | 很高 | 很低 | 低 | 中 | 优秀 |
| **Flannel VXLAN** | 中 | 中 | 低 | 低 | 一般 |
| **Terway ENI** | 很高 | 很低 | 很低 | 低 | 优秀 |

## Service类型详解

| 类型 | 用途 | 端口映射 | 访问范围 | 负载均衡 | 版本变更 |
|-----|------|---------|---------|---------|---------|
| **ClusterIP** | 集群内部访问 | Service端口→Pod端口 | 仅集群内 | kube-proxy | 稳定 |
| **NodePort** | 外部通过节点端口访问 | 节点端口→Service端口→Pod | 节点IP可达范围 | kube-proxy | 稳定 |
| **LoadBalancer** | 外部通过LB访问 | LB端口→Service端口→Pod | 公网/VPC | 云LB | v1.29 IP模式 |
| **ExternalName** | CNAME别名 | - | DNS解析 | 无 | 稳定 |
| **Headless** | 直接访问Pod | - | 集群内 | 无，DNS返回Pod IP | 稳定 |

## kube-proxy模式对比

| 模式 | 实现机制 | 性能 | 规模支持 | 功能 | 版本支持 |
|-----|---------|------|---------|------|---------|
| **iptables** | iptables规则 | 中等 | <1000 Service | 完整 | 默认 |
| **IPVS** | Linux IPVS | 高 | >1000 Service | 完整+更多算法 | 推荐大集群 |
| **nftables** | nftables规则 | 高 | >1000 Service | 完整 | v1.26+ Alpha |
| **userspace** | 用户空间代理 | 低 | 小规模 | 完整 | 已弃用 |

## Ingress控制器对比

| 控制器 | 类型 | 特点 | 版本兼容 | ACK集成 |
|-------|------|------|---------|---------|
| **Nginx Ingress** | 反向代理 | 功能丰富，社区活跃 | v1.25+ | 支持 |
| **Traefik** | 反向代理 | 动态配置，中间件丰富 | v1.25+ | - |
| **HAProxy** | 反向代理 | 高性能，企业级 | v1.25+ | - |
| **Contour** | Envoy代理 | 现代架构，Envoy生态 | v1.25+ | - |
| **ALB Ingress** | 阿里云ALB | 云原生，自动集成 | v1.25+ | 原生 |
| **Kong** | API网关 | API管理功能 | v1.25+ | - |

## DNS配置

| 组件 | 配置文件 | 关键参数 | 版本变更 |
|-----|---------|---------|---------|
| **CoreDNS** | Corefile ConfigMap | forward, cache, kubernetes插件 | v1.28缓存优化 |
| **NodeLocal DNSCache** | 节点级DNS缓存 | 减少CoreDNS压力 | v1.28+推荐 |

```yaml
# CoreDNS Corefile示例
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
            lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
            ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
            max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
```

## NetworkPolicy规则类型

| 规则类型 | 用途 | 示例场景 |
|---------|------|---------|
| **Ingress** | 控制入站流量 | 只允许特定来源访问 |
| **Egress** | 控制出站流量 | 限制外部API访问 |
| **podSelector** | 选择策略应用的Pod | 按标签选择 |
| **namespaceSelector** | 选择允许的命名空间 | 跨NS通信控制 |
| **ipBlock** | IP CIDR规则 | 外部IP白名单 |

```yaml
# NetworkPolicy示例 - 默认拒绝所有入站
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress

---
# 允许特定来源
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    - namespaceSelector:
        matchLabels:
          env: production
    ports:
    - protocol: TCP
      port: 8080
```

## 网络故障排查命令

```bash
# Pod网络连通性
kubectl exec -it <pod> -- ping <target-ip>
kubectl exec -it <pod> -- nc -zv <service> <port>
kubectl exec -it <pod> -- curl -v <url>

# DNS测试
kubectl exec -it <pod> -- nslookup kubernetes
kubectl exec -it <pod> -- nslookup <service>.<namespace>.svc.cluster.local

# Service端点检查
kubectl get endpoints <service>
kubectl get endpointslices -l kubernetes.io/service-name=<service>

# kube-proxy规则
kubectl get pods -n kube-system -l k8s-app=kube-proxy
iptables -t nat -L KUBE-SERVICES
ipvsadm -Ln  # IPVS模式

# CNI状态
kubectl get pods -n kube-system -l k8s-app=calico-node  # Calico
kubectl get pods -n kube-system -l k8s-app=cilium       # Cilium

# NetworkPolicy检查
kubectl get networkpolicy -A
kubectl describe networkpolicy <name>
```

## ACK网络最佳实践

| 实践 | 配置 | 效果 |
|-----|------|------|
| **使用Terway** | 创建集群时选择 | ENI直通，高性能 |
| **IPVS模式** | kube-proxy配置 | 大规模Service |
| **NodeLocal DNS** | 部署组件 | 降低DNS延迟 |
| **SLB复用** | 注解配置 | 节省SLB资源 |
| **Pod ENI** | Terway ENI模式 | 独立网卡，隔离性好 |

---

**网络原则**: 默认拒绝，显式允许，监控流量
