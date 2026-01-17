# 表格82: DNS优化与调优

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/)

## CoreDNS性能参数

| 参数 | 默认值 | 推荐值 | 说明 |
|-----|-------|-------|------|
| 副本数 | 2 | 按需扩展 | 每1000节点+1副本 |
| CPU请求 | 100m | 200m | 高负载增加 |
| 内存请求 | 70Mi | 170Mi | 缓存增加时 |
| 缓存TTL | 30s | 60-300s | 减少查询 |

## CoreDNS资源配置

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coredns
  namespace: kube-system
spec:
  replicas: 3  # 根据集群规模调整
  template:
    spec:
      containers:
      - name: coredns
        resources:
          requests:
            cpu: 200m
            memory: 170Mi
          limits:
            cpu: 1000m
            memory: 512Mi
```

## CoreDNS HPA

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: coredns
  namespace: kube-system
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: coredns
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## 优化后的Corefile

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
    
    # 增加缓存
    cache {
       success 9984 300  # 成功缓存5分钟
       denial 9984 30    # 失败缓存30秒
       prefetch 10 1m 10%  # 预取
    }
    
    # 上游DNS
    forward . /etc/resolv.conf {
       max_concurrent 2000  # 增加并发
       policy sequential    # 顺序查询
       health_check 5s
    }
    
    prometheus :9153
    loop
    reload
    loadbalance round_robin
}
```

## NodeLocal DNSCache配置

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-local-dns
  namespace: kube-system
spec:
  template:
    spec:
      containers:
      - name: node-cache
        image: registry.k8s.io/dns/k8s-dns-node-cache:1.22.28
        args:
        - -localip
        - "169.254.20.10"
        - -conf
        - /etc/Corefile
        - -upstreamsvc
        - kube-dns-upstream
        resources:
          requests:
            cpu: 25m
            memory: 25Mi
          limits:
            cpu: 100m
            memory: 128Mi
        volumeMounts:
        - name: config-volume
          mountPath: /etc/coredns
        - name: xtables-lock
          mountPath: /run/xtables.lock
      volumes:
      - name: config-volume
        configMap:
          name: node-local-dns
      - name: xtables-lock
        hostPath:
          path: /run/xtables.lock
          type: FileOrCreate
```

## Pod DNS优化

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dns-optimized
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers:
    - 169.254.20.10  # NodeLocal DNS
    - 10.96.0.10     # CoreDNS fallback
    searches:
    - default.svc.cluster.local
    - svc.cluster.local
    - cluster.local
    options:
    - name: ndots
      value: "2"  # 减少搜索域查询
    - name: timeout
      value: "2"
    - name: attempts
      value: "2"
    - name: single-request-reopen  # 避免conntrack冲突
```

## ndots优化说明

| ndots值 | 查询`api`的行为 | 查询数 |
|--------|----------------|-------|
| 5(默认) | 先搜索所有域后查外部 | 5-6次 |
| 2 | 先查外部后搜索域 | 1-3次 |
| 1 | 几乎直接查外部 | 1-2次 |

## 自定义域名解析

```yaml
# CoreDNS配置添加hosts插件
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        hosts /etc/coredns/customdomains.db {
           fallthrough
        }
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
        }
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
  customdomains.db: |
    10.0.0.100 internal-api.company.com
    10.0.0.101 internal-db.company.com
```

## DNS监控指标

| 指标 | 类型 | 告警阈值 |
|-----|-----|---------|
| `coredns_dns_requests_total` | Counter | - |
| `coredns_dns_responses_total` | Counter | - |
| `coredns_dns_request_duration_seconds` | Histogram | p99>1s |
| `coredns_cache_hits_total` | Counter | - |
| `coredns_cache_misses_total` | Counter | 命中率<70% |
| `coredns_forward_requests_total` | Counter | - |
| `coredns_forward_responses_total` | Counter | - |
| `coredns_panics_total` | Counter | >0 |

## DNS故障排查

```bash
# 检查CoreDNS状态
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 查看CoreDNS日志(启用log插件)
kubectl logs -n kube-system -l k8s-app=kube-dns

# DNS解析测试
kubectl run dnstest --image=busybox:1.28 --rm -it -- nslookup kubernetes

# 检查resolv.conf
kubectl exec <pod> -- cat /etc/resolv.conf

# 检查NodeLocal DNS
kubectl get pods -n kube-system -l k8s-app=node-local-dns
```

## ACK DNS优化

| 功能 | 说明 |
|-----|------|
| NodeLocal DNS | 一键开启 |
| DNS自动扩缩 | 按需扩展 |
| PrivateZone | 私有域名解析 |
| DNS缓存 | 本地缓存加速 |
