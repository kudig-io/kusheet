# 表格33: 服务发现与DNS配置

## CoreDNS配置

| 配置项 | 默认值 | 说明 |
|-------|-------|------|
| Corefile位置 | ConfigMap coredns | CoreDNS配置 |
| 集群域名 | cluster.local | 集群DNS后缀 |
| 上游DNS | /etc/resolv.conf | 外部DNS服务器 |
| 缓存时间 | 30s | DNS缓存TTL |

## Corefile配置示例

```
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

## CoreDNS插件

| 插件 | 功能 | 配置示例 |
|-----|------|---------|
| kubernetes | K8s服务发现 | `kubernetes cluster.local` |
| forward | DNS转发 | `forward . 8.8.8.8` |
| cache | DNS缓存 | `cache 60` |
| loop | 循环检测 | `loop` |
| reload | 配置热加载 | `reload` |
| health | 健康检查 | `health :8080` |
| ready | 就绪检查 | `ready :8181` |
| prometheus | 监控指标 | `prometheus :9153` |
| errors | 错误日志 | `errors` |
| log | 查询日志 | `log` |
| hosts | 本地hosts | `hosts /etc/hosts` |
| rewrite | 重写规则 | `rewrite name...` |
| template | 模板响应 | `template...` |

## DNS策略

| 策略 | 说明 | 适用场景 |
|-----|------|---------|
| ClusterFirst | 优先集群DNS | 默认策略 |
| ClusterFirstWithHostNet | hostNetwork优先集群 | hostNetwork Pod |
| Default | 继承节点DNS | 需要节点DNS |
| None | 自定义DNS | 完全自定义 |

## Pod DNS配置

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dns-example
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers:
    - 10.96.0.10      # CoreDNS ClusterIP
    - 8.8.8.8         # 外部DNS
    searches:
    - default.svc.cluster.local
    - svc.cluster.local
    - cluster.local
    options:
    - name: ndots
      value: "5"
    - name: timeout
      value: "2"
    - name: attempts
      value: "3"
    - name: single-request-reopen
```

## 服务DNS记录格式

| 记录类型 | 格式 | 示例 |
|---------|-----|------|
| ClusterIP Service | `<svc>.<ns>.svc.<domain>` | `nginx.default.svc.cluster.local` |
| Headless Service | `<pod>.<svc>.<ns>.svc.<domain>` | `pod-0.nginx.default.svc.cluster.local` |
| ExternalName | CNAME记录 | 指向外部域名 |
| SRV记录 | `_<port>._<proto>.<svc>.<ns>.svc.<domain>` | `_http._tcp.nginx.default.svc.cluster.local` |

## NodeLocal DNSCache

| 配置项 | 默认值 | 说明 |
|-------|-------|------|
| 本地IP | 169.254.20.10 | 本地监听地址 |
| 缓存大小 | 无限制 | 缓存条目数 |
| 上游DNS | CoreDNS ClusterIP | 上游服务器 |
| 协议 | TCP/UDP | 支持协议 |

## NodeLocal DNSCache配置

```yaml
# 节点本地DNS缓存ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: node-local-dns
  namespace: kube-system
data:
  Corefile: |
    cluster.local:53 {
        errors
        cache {
            success 9984 30
            denial 9984 5
        }
        reload
        loop
        bind 169.254.20.10
        forward . __PILLAR__CLUSTER__DNS__ {
            force_tcp
        }
        prometheus :9253
    }
    .:53 {
        errors
        cache 30
        reload
        loop
        bind 169.254.20.10
        forward . __PILLAR__UPSTREAM__SERVERS__
        prometheus :9253
    }
```

## DNS性能优化

| 优化项 | 配置 | 效果 |
|-------|-----|------|
| 启用缓存 | `cache 60` | 减少查询 |
| NodeLocal DNS | 部署DaemonSet | 降低延迟 |
| 减少ndots | `ndots: 2` | 减少搜索域 |
| 使用FQDN | 完整域名查询 | 避免搜索 |
| 增加副本 | 多CoreDNS Pod | 提高吞吐 |

## DNS监控指标

| 指标 | 类型 | 说明 |
|-----|-----|------|
| `coredns_dns_requests_total` | Counter | DNS请求总数 |
| `coredns_dns_responses_total` | Counter | DNS响应总数 |
| `coredns_dns_request_duration_seconds` | Histogram | 请求延迟 |
| `coredns_cache_hits_total` | Counter | 缓存命中 |
| `coredns_cache_misses_total` | Counter | 缓存未命中 |
| `coredns_forward_requests_total` | Counter | 转发请求数 |

## 故障排查命令

```bash
# 测试DNS解析
kubectl run dnsutils --image=registry.k8s.io/e2e-test-images/jessie-dnsutils:1.3 -it --rm -- nslookup kubernetes

# 查看CoreDNS日志
kubectl logs -n kube-system -l k8s-app=kube-dns

# 检查CoreDNS配置
kubectl get cm coredns -n kube-system -o yaml

# 查看DNS策略
kubectl get pod <pod-name> -o jsonpath='{.spec.dnsPolicy}'

# 检查resolv.conf
kubectl exec <pod-name> -- cat /etc/resolv.conf
```

## ACK DNS增强

| 功能 | 说明 |
|-----|------|
| PrivateZone集成 | 阿里云私有DNS |
| DNS自动扩缩 | 基于负载扩缩 |
| 智能DNS缓存 | NodeLocal DNS |

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| v1.25 | CoreDNS 1.9.3+ |
| v1.27 | DNS插件改进 |
| v1.28 | CoreDNS 1.10+ |
| v1.30 | CoreDNS 1.11+ |
