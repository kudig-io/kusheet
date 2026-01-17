# 核心组件参考

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/overview/components](https://kubernetes.io/docs/concepts/overview/components/)

## 控制平面组件详解

### kube-apiserver

| 配置项 | 默认值 | 生产推荐 | 说明 |
|--------|--------|----------|------|
| --max-requests-inflight | 400 | 800-1600 | 非变更请求并发 |
| --max-mutating-requests-inflight | 200 | 400-800 | 变更请求并发 |
| --request-timeout | 1m | 1m | 请求超时 |
| --min-request-timeout | 1800s | 1800s | Watch最小超时 |
| --watch-cache-sizes | 默认 | 按资源调整 | Watch缓存大小 |
| --default-watch-cache-size | 100 | 500-1000 | 默认缓存大小 |
| --etcd-compaction-interval | 5m | 5m | etcd压缩间隔 |
| --audit-log-maxsize | 100 | 100 | 审计日志大小MB |
| --audit-log-maxbackup | 10 | 10 | 审计日志备份数 |
| --audit-log-maxage | 30 | 30 | 审计日志保留天数 |

#### API Server 完整配置示例

```yaml
# /etc/kubernetes/manifests/kube-apiserver.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
  labels:
    component: kube-apiserver
    tier: control-plane
spec:
  hostNetwork: true
  priorityClassName: system-node-critical
  containers:
  - name: kube-apiserver
    image: registry.k8s.io/kube-apiserver:v1.30.0
    command:
    - kube-apiserver
    # 认证配置
    - --anonymous-auth=false
    - --client-ca-file=/etc/kubernetes/pki/ca.crt
    - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
    - --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
    - --tls-min-version=VersionTLS12
    # 授权配置
    - --authorization-mode=Node,RBAC
    - --enable-admission-plugins=NodeRestriction,PodSecurity,ResourceQuota,LimitRanger
    # etcd配置
    - --etcd-servers=https://127.0.0.1:2379
    - --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
    - --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
    - --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
    - --etcd-compaction-interval=5m
    # 服务配置
    - --service-cluster-ip-range=10.96.0.0/12
    - --service-account-issuer=https://kubernetes.default.svc.cluster.local
    - --service-account-key-file=/etc/kubernetes/pki/sa.pub
    - --service-account-signing-key-file=/etc/kubernetes/pki/sa.key
    # 性能调优
    - --max-requests-inflight=800
    - --max-mutating-requests-inflight=400
    - --default-watch-cache-size=500
    - --watch-cache-sizes=pods#5000,nodes#1000,services#1000,secrets#1000
    # 审计配置
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
    - --audit-log-maxage=30
    - --audit-log-maxbackup=10
    - --audit-log-maxsize=100
    - --audit-log-format=json
    # 加密配置
    - --encryption-provider-config=/etc/kubernetes/encryption/config.yaml
    # 安全配置
    - --profiling=false
    - --enable-priority-and-fairness=true
    # 功能门控
    - --feature-gates=ValidatingAdmissionPolicy=true
    resources:
      requests:
        cpu: 250m
        memory: 1Gi
      limits:
        cpu: 4
        memory: 8Gi
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /livez
        port: 6443
        scheme: HTTPS
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 15
      failureThreshold: 8
    readinessProbe:
      httpGet:
        host: 127.0.0.1
        path: /readyz
        port: 6443
        scheme: HTTPS
      initialDelaySeconds: 0
      periodSeconds: 1
      timeoutSeconds: 15
    volumeMounts:
    - name: etc-kubernetes
      mountPath: /etc/kubernetes
      readOnly: true
    - name: ca-certs
      mountPath: /etc/ssl/certs
      readOnly: true
    - name: audit-log
      mountPath: /var/log/kubernetes/audit
  volumes:
  - name: etc-kubernetes
    hostPath:
      path: /etc/kubernetes
      type: DirectoryOrCreate
  - name: ca-certs
    hostPath:
      path: /etc/ssl/certs
      type: DirectoryOrCreate
  - name: audit-log
    hostPath:
      path: /var/log/kubernetes/audit
      type: DirectoryOrCreate
```

### etcd

| 配置项 | 默认值 | 生产推荐 | 说明 |
|--------|--------|----------|------|
| --quota-backend-bytes | 2GB | 8GB | 存储配额 |
| --snapshot-count | 100000 | 10000 | 快照触发计数 |
| --auto-compaction-mode | periodic | revision | 压缩模式 |
| --auto-compaction-retention | 0 | 1h或1000 | 压缩保留 |
| --max-txn-ops | 128 | 256 | 单事务最大操作数 |
| --max-request-bytes | 1.5MB | 10MB | 最大请求大小 |
| --heartbeat-interval | 100ms | 100ms | 心跳间隔 |
| --election-timeout | 1000ms | 1000ms | 选举超时 |

#### etcd 集群配置示例

```yaml
# /etc/kubernetes/manifests/etcd.yaml
apiVersion: v1
kind: Pod
metadata:
  name: etcd
  namespace: kube-system
  labels:
    component: etcd
    tier: control-plane
spec:
  hostNetwork: true
  priorityClassName: system-node-critical
  containers:
  - name: etcd
    image: registry.k8s.io/etcd:3.5.12-0
    command:
    - etcd
    # 成员配置
    - --name=master-0
    - --data-dir=/var/lib/etcd
    - --listen-client-urls=https://0.0.0.0:2379
    - --advertise-client-urls=https://10.0.0.10:2379
    - --listen-peer-urls=https://0.0.0.0:2380
    - --initial-advertise-peer-urls=https://10.0.0.10:2380
    - --initial-cluster=master-0=https://10.0.0.10:2380,master-1=https://10.0.0.11:2380,master-2=https://10.0.0.12:2380
    - --initial-cluster-token=etcd-cluster
    - --initial-cluster-state=new
    # TLS配置
    - --cert-file=/etc/kubernetes/pki/etcd/server.crt
    - --key-file=/etc/kubernetes/pki/etcd/server.key
    - --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
    - --client-cert-auth=true
    - --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt
    - --peer-key-file=/etc/kubernetes/pki/etcd/peer.key
    - --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
    - --peer-client-cert-auth=true
    # 性能调优
    - --quota-backend-bytes=8589934592
    - --snapshot-count=10000
    - --auto-compaction-mode=revision
    - --auto-compaction-retention=1000
    - --max-txn-ops=256
    - --max-request-bytes=10485760
    # 加密
    - --cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
    resources:
      requests:
        cpu: 100m
        memory: 512Mi
      limits:
        cpu: 2
        memory: 4Gi
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /health?serializable=true
        port: 2379
        scheme: HTTPS
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 15
      failureThreshold: 8
    volumeMounts:
    - name: etcd-data
      mountPath: /var/lib/etcd
    - name: etcd-certs
      mountPath: /etc/kubernetes/pki/etcd
      readOnly: true
  volumes:
  - name: etcd-data
    hostPath:
      path: /var/lib/etcd
      type: DirectoryOrCreate
  - name: etcd-certs
    hostPath:
      path: /etc/kubernetes/pki/etcd
      type: DirectoryOrCreate
```

### kube-scheduler

| 配置项 | 默认值 | 生产推荐 | 说明 |
|--------|--------|----------|------|
| --kube-api-qps | 50 | 100-200 | API请求QPS |
| --kube-api-burst | 100 | 200-400 | API突发请求 |
| --leader-elect | true | true | 启用leader选举 |
| --leader-elect-lease-duration | 15s | 15s | 租约时长 |
| --leader-elect-renew-deadline | 10s | 10s | 续租期限 |

#### Scheduler 配置示例

```yaml
# /etc/kubernetes/scheduler-config.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  acceptContentTypes: ""
  burst: 200
  contentType: application/vnd.kubernetes.protobuf
  kubeconfig: /etc/kubernetes/scheduler.conf
  qps: 100
leaderElection:
  leaderElect: true
  leaseDuration: 15s
  renewDeadline: 10s
  retryPeriod: 2s
profiles:
- schedulerName: default-scheduler
  plugins:
    score:
      enabled:
      - name: NodeResourcesBalancedAllocation
        weight: 1
      - name: ImageLocality
        weight: 1
      - name: InterPodAffinity
        weight: 1
      - name: NodeResourcesFit
        weight: 1
      - name: NodeAffinity
        weight: 1
      - name: PodTopologySpread
        weight: 2
      - name: TaintToleration
        weight: 1
  pluginConfig:
  - name: PodTopologySpread
    args:
      defaultingType: List
      defaultConstraints:
      - maxSkew: 3
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
      - maxSkew: 5
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
```

### kube-controller-manager

| 配置项 | 默认值 | 生产推荐 | 说明 |
|--------|--------|----------|------|
| --concurrent-deployment-syncs | 5 | 10-20 | Deployment并发 |
| --concurrent-replicaset-syncs | 5 | 10-20 | ReplicaSet并发 |
| --concurrent-service-syncs | 5 | 10-20 | Service并发 |
| --concurrent-gc-syncs | 20 | 30-50 | GC并发 |
| --node-monitor-period | 5s | 5s | 节点检查周期 |
| --node-monitor-grace-period | 40s | 40s | 节点宽限期 |
| --pod-eviction-timeout | 5m | 5m | 驱逐超时 |
| --kube-api-qps | 20 | 50-100 | API请求QPS |

## 节点组件详解

### kubelet

| 配置项 | 默认值 | 生产推荐 | 说明 |
|--------|--------|----------|------|
| --max-pods | 110 | 110-250 | 最大Pod数 |
| --pod-max-pids | -1 | 4096 | Pod最大PID |
| --image-gc-high-threshold | 85 | 80 | 镜像GC高水位 |
| --image-gc-low-threshold | 80 | 70 | 镜像GC低水位 |
| --serialize-image-pulls | true | false | 串行拉取镜像 |
| --registry-qps | 5 | 10-20 | 镜像仓库QPS |
| --registry-burst | 10 | 20-40 | 镜像仓库突发 |
| --node-status-update-frequency | 10s | 10s | 状态更新频率 |
| --rotate-certificates | true | true | 证书轮换 |
| --protect-kernel-defaults | false | true | 保护内核默认值 |
| --read-only-port | 10255 | 0 | 只读端口(禁用) |

#### kubelet 完整配置

```yaml
# /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
# 认证授权
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 2m0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 5m0s
    cacheUnauthorizedTTL: 30s
# TLS配置
tlsCipherSuites:
- TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
- TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
tlsMinVersion: VersionTLS12
# 资源管理
maxPods: 110
podPidsLimit: 4096
# 系统预留
systemReserved:
  cpu: 500m
  memory: 1Gi
  ephemeral-storage: 10Gi
kubeReserved:
  cpu: 500m
  memory: 1Gi
  ephemeral-storage: 10Gi
enforceNodeAllocatable:
- pods
- kube-reserved
- system-reserved
# 驱逐配置
evictionHard:
  imagefs.available: 15%
  memory.available: 500Mi
  nodefs.available: 10%
  nodefs.inodesFree: 5%
  pid.available: "1000"
evictionSoft:
  imagefs.available: 20%
  memory.available: 1Gi
  nodefs.available: 15%
evictionSoftGracePeriod:
  imagefs.available: 2m
  memory.available: 2m
  nodefs.available: 2m
evictionPressureTransitionPeriod: 5m
evictionMaxPodGracePeriod: 120
# 镜像管理
imageGCHighThresholdPercent: 80
imageGCLowThresholdPercent: 70
imageMinimumGCAge: 2m
serializeImagePulls: false
registryPullQPS: 10
registryBurst: 20
# 日志配置
containerLogMaxSize: 50Mi
containerLogMaxFiles: 5
# 健康检查
nodeStatusUpdateFrequency: 10s
nodeStatusReportFrequency: 5m
# 特性配置
cgroupDriver: systemd
cgroupsPerQOS: true
cpuManagerPolicy: static
cpuManagerReconcilePeriod: 10s
topologyManagerPolicy: best-effort
# 证书轮换
rotateCertificates: true
serverTLSBootstrap: true
# 安全配置
readOnlyPort: 0
protectKernelDefaults: true
makeIPTablesUtilChains: true
# 优雅关机
shutdownGracePeriod: 30s
shutdownGracePeriodCriticalPods: 10s
```

### kube-proxy

| 配置项 | 默认值 | 生产推荐 | 说明 |
|--------|--------|----------|------|
| --proxy-mode | iptables | ipvs | 代理模式 |
| --ipvs-scheduler | rr | rr/lc/sh | IPVS调度算法 |
| --conntrack-max-per-core | 32768 | 65536 | 每核conntrack |
| --conntrack-min | 131072 | 262144 | 最小conntrack |

#### kube-proxy IPVS 模式配置

```yaml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
ipvs:
  scheduler: rr
  syncPeriod: 30s
  minSyncPeriod: 2s
  tcpTimeout: 0s
  tcpFinTimeout: 0s
  udpTimeout: 0s
  excludeCIDRs: []
conntrack:
  maxPerCore: 65536
  min: 262144
  tcpEstablishedTimeout: 86400s
  tcpCloseWaitTimeout: 1h
metricsBindAddress: 0.0.0.0:10249
healthzBindAddress: 0.0.0.0:10256
clusterCIDR: 10.244.0.0/16
```

## 附加组件

### CoreDNS

| 配置项 | 说明 | 推荐值 |
|--------|------|--------|
| 副本数 | DNS服务副本 | max(2, nodes/100) |
| 内存限制 | CoreDNS内存 | 170Mi基础 + 节点数*0.5Mi |
| 缓存TTL | DNS缓存时间 | 30s |
| 前向超时 | 上游DNS超时 | 2s |

#### CoreDNS Corefile 配置

```yaml
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
            prefer_udp
        }
        cache 30
        loop
        reload
        loadbalance
    }
```

### Metrics Server

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-server
  namespace: kube-system
spec:
  replicas: 2
  selector:
    matchLabels:
      k8s-app: metrics-server
  template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      serviceAccountName: metrics-server
      containers:
      - name: metrics-server
        image: registry.k8s.io/metrics-server/metrics-server:v0.7.0
        args:
        - --cert-dir=/tmp
        - --secure-port=10250
        - --kubelet-preferred-address-types=InternalIP,Hostname,InternalDNS,ExternalDNS,ExternalIP
        - --kubelet-use-node-status-port
        - --metric-resolution=15s
        # 生产环境不建议使用
        # - --kubelet-insecure-tls
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
          limits:
            cpu: 500m
            memory: 500Mi
        securityContext:
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
        volumeMounts:
        - name: tmp-dir
          mountPath: /tmp
      volumes:
      - name: tmp-dir
        emptyDir: {}
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            k8s-app: metrics-server
```

## 组件版本兼容性矩阵

| K8s版本 | etcd | containerd | CoreDNS | Metrics Server | Calico | Cilium |
|---------|------|------------|---------|----------------|--------|--------|
| v1.25 | 3.5.x | 1.6+ | 1.9+ | 0.6+ | 3.24+ | 1.12+ |
| v1.26 | 3.5.x | 1.6+ | 1.9+ | 0.6+ | 3.25+ | 1.13+ |
| v1.27 | 3.5.x | 1.7+ | 1.10+ | 0.6+ | 3.26+ | 1.14+ |
| v1.28 | 3.5.x | 1.7+ | 1.10+ | 0.7+ | 3.27+ | 1.14+ |
| v1.29 | 3.5.x | 1.7+ | 1.11+ | 0.7+ | 3.27+ | 1.15+ |
| v1.30 | 3.5.x | 1.7+/2.0 | 1.11+ | 0.7+ | 3.28+ | 1.15+ |
| v1.31 | 3.5.x | 1.7+/2.0 | 1.11+ | 0.7+ | 3.28+ | 1.16+ |
| v1.32 | 3.5.x | 2.0+ | 1.11+ | 0.7+ | 3.28+ | 1.16+ |

## 组件资源规划

| 集群规模 | API Server | etcd | Scheduler | Controller | CoreDNS |
|----------|------------|------|-----------|------------|---------|
| <50节点 | 2C/4G | 2C/4G SSD | 1C/2G | 2C/4G | 2副本,100m/128Mi |
| 50-200 | 4C/8G | 4C/8G SSD | 2C/4G | 4C/8G | 3副本,200m/256Mi |
| 200-1000 | 8C/16G | 8C/16G NVMe | 4C/8G | 8C/16G | 5副本,500m/512Mi |
| 1000+ | 16C/32G | 16C/32G NVMe | 8C/16G | 16C/32G | 10副本,1C/1Gi |

## 监控告警规则

```yaml
groups:
- name: kubernetes-components
  rules:
  # API Server
  - alert: KubeAPIServerDown
    expr: absent(up{job="kubernetes-apiservers"} == 1)
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "API Server 不可用"
      
  - alert: KubeAPIServerLatencyHigh
    expr: |
      histogram_quantile(0.99, sum(rate(apiserver_request_duration_seconds_bucket{verb!="WATCH"}[5m])) by (le)) > 1
    for: 5m
    labels:
      severity: warning
      
  # etcd
  - alert: EtcdNoLeader
    expr: etcd_server_has_leader == 0
    for: 1m
    labels:
      severity: critical
      
  - alert: EtcdHighFsyncDuration
    expr: histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m])) > 0.01
    for: 5m
    labels:
      severity: warning
      
  - alert: EtcdDatabaseSpaceExceeded
    expr: etcd_mvcc_db_total_size_in_bytes / etcd_server_quota_backend_bytes > 0.8
    for: 5m
    labels:
      severity: warning
      
  # Scheduler
  - alert: KubeSchedulerDown
    expr: absent(up{job="kube-scheduler"} == 1)
    for: 5m
    labels:
      severity: critical
      
  - alert: KubeSchedulerPendingPods
    expr: scheduler_pending_pods > 100
    for: 10m
    labels:
      severity: warning
      
  # Controller Manager
  - alert: KubeControllerManagerDown
    expr: absent(up{job="kube-controller-manager"} == 1)
    for: 5m
    labels:
      severity: critical
      
  # kubelet
  - alert: KubeletDown
    expr: absent(up{job="kubelet"} == 1)
    for: 5m
    labels:
      severity: critical
      
  - alert: KubeletPLEGDurationHigh
    expr: histogram_quantile(0.99, rate(kubelet_pleg_relist_duration_seconds_bucket[5m])) > 3
    for: 5m
    labels:
      severity: warning
      
  # CoreDNS
  - alert: CoreDNSDown
    expr: absent(up{job="coredns"} == 1)
    for: 5m
    labels:
      severity: critical
      
  - alert: CoreDNSLatencyHigh
    expr: histogram_quantile(0.99, sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le)) > 0.1
    for: 5m
    labels:
      severity: warning
```

## 诊断命令速查

```bash
# 控制平面健康检查
kubectl get --raw='/readyz?verbose'
kubectl get --raw='/livez?verbose'
kubectl get componentstatuses

# etcd 诊断
etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  endpoint health --cluster
  
etcdctl endpoint status --cluster -w table

# etcd 碎片整理
etcdctl defrag --cluster

# kubelet 诊断
systemctl status kubelet
journalctl -u kubelet -f --no-pager | tail -100
crictl info
crictl ps

# kube-proxy 诊断
kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=100
iptables -L -t nat | head -50  # iptables模式
ipvsadm -Ln  # IPVS模式

# CoreDNS 诊断
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=100
kubectl exec -it <pod> -- nslookup kubernetes.default
```
