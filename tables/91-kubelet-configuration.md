# 表格91: kubelet配置优化

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/)

## kubelet关键配置参数

| 参数 | 默认值 | 推荐值 | 说明 |
|-----|-------|-------|------|
| `maxPods` | 110 | 110-250 | 节点最大Pod数 |
| `podPidsLimit` | -1 | 4096 | Pod最大进程数 |
| `imageGCHighThresholdPercent` | 85 | 80 | 镜像GC高水位 |
| `imageGCLowThresholdPercent` | 80 | 70 | 镜像GC低水位 |
| `containerLogMaxSize` | 10Mi | 50Mi | 容器日志大小限制 |
| `containerLogMaxFiles` | 5 | 3 | 容器日志文件数 |
| `serializeImagePulls` | true | false | 并行拉取镜像 |
| `registryPullQPS` | 5 | 10 | 镜像拉取QPS |
| `registryBurst` | 10 | 20 | 镜像拉取突发 |

## 完整kubelet配置示例

```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
# 基础配置
address: 0.0.0.0
port: 10250
readOnlyPort: 0  # 禁用只读端口

# Pod配置
maxPods: 110
podPidsLimit: 4096
maxOpenFiles: 1000000

# 资源预留
systemReserved:
  cpu: "500m"
  memory: "1Gi"
  ephemeral-storage: "1Gi"
kubeReserved:
  cpu: "500m"
  memory: "1Gi"
  ephemeral-storage: "1Gi"
enforceNodeAllocatable:
- pods
- kube-reserved
- system-reserved

# 驱逐配置
evictionHard:
  memory.available: "100Mi"
  nodefs.available: "10%"
  nodefs.inodesFree: "5%"
  imagefs.available: "15%"
evictionSoft:
  memory.available: "500Mi"
  nodefs.available: "15%"
evictionSoftGracePeriod:
  memory.available: "1m30s"
  nodefs.available: "1m30s"
evictionPressureTransitionPeriod: 30s
evictionMaxPodGracePeriod: 120

# 镜像管理
imageGCHighThresholdPercent: 80
imageGCLowThresholdPercent: 70
imageMinimumGCAge: 2m
serializeImagePulls: false
registryPullQPS: 10
registryBurst: 20

# 日志配置
containerLogMaxSize: "50Mi"
containerLogMaxFiles: 3

# 健康检查
nodeStatusUpdateFrequency: 10s
nodeStatusReportFrequency: 5m
syncFrequency: 1m

# 特性门控
featureGates:
  RotateKubeletServerCertificate: true
  GracefulNodeShutdown: true
  TopologyManager: true

# 拓扑管理
topologyManagerPolicy: best-effort
topologyManagerScope: container
cpuManagerPolicy: static
cpuManagerReconcilePeriod: 10s
memoryManagerPolicy: Static

# 认证授权
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
    cacheTTL: 2m
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 5m
    cacheUnauthorizedTTL: 30s

# TLS配置
tlsCipherSuites:
- TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
- TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
tlsMinVersion: VersionTLS12

# 优雅关闭
shutdownGracePeriod: 30s
shutdownGracePeriodCriticalPods: 10s
```

## 场景优化配置

### 高密度部署(多Pod)

```yaml
maxPods: 200
podPidsLimit: 8192
registryPullQPS: 20
registryBurst: 40
serializeImagePulls: false
```

### AI/GPU节点

```yaml
topologyManagerPolicy: single-numa-node
cpuManagerPolicy: static
memoryManagerPolicy: Static
reservedSystemCPUs: "0-1"  # 预留CPU给系统
```

### 边缘节点(资源受限)

```yaml
maxPods: 50
imageGCHighThresholdPercent: 70
imageGCLowThresholdPercent: 50
containerLogMaxSize: "10Mi"
containerLogMaxFiles: 2
```

## kubelet启动参数

```bash
# /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
[Service]
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_EXTRA_ARGS=--node-labels=node-type=worker --max-pods=150"
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_EXTRA_ARGS
```

## 运行时配置

```bash
# 查看当前kubelet配置
kubectl get --raw "/api/v1/nodes/<node>/proxy/configz" | jq

# 动态修改配置(不推荐生产使用)
kubectl patch node <node> -p '{"spec":{"configSource":{"configMap":{"name":"kubelet-config","namespace":"kube-system"}}}}'

# 查看kubelet指标
curl -k https://localhost:10250/metrics
```

## 性能调优

```bash
# 检查kubelet CPU使用
top -p $(pgrep kubelet)

# 检查kubelet内存
ps aux | grep kubelet

# 检查PLEG(Pod Lifecycle Event Generator)性能
curl -k https://localhost:10250/metrics | grep pleg

# 检查cAdvisor性能
curl -k https://localhost:10250/metrics | grep cadvisor
```

## 常见问题配置

| 问题 | 解决配置 |
|-----|---------|
| Pod启动慢 | `serializeImagePulls: false`, 增加`registryPullQPS` |
| 节点频繁驱逐 | 调整`evictionHard`阈值 |
| 日志占满磁盘 | 减小`containerLogMaxSize` |
| 镜像占满磁盘 | 降低`imageGCHighThresholdPercent` |
| 进程数超限 | 增加`podPidsLimit` |

## ACK kubelet配置

```bash
# ACK查看节点kubelet配置
kubectl get node <node> -o yaml | grep -A 20 "kubelet"

# ACK节点池kubelet配置(Terraform)
resource "alicloud_cs_kubernetes_node_pool" "default" {
  # ...
  kubelet_configuration {
    max_pods = 150
    registry_pull_qps = 10
    event_record_qps = 10
  }
}
```

---

**kubelet优化原则**: 合理设置maxPods + 配置资源预留 + 调整驱逐阈值 + 优化镜像管理 + 启用安全特性
