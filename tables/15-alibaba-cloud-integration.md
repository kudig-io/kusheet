# 表格15：阿里云特定集成表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [help.aliyun.com/product/85222.html](https://help.aliyun.com/product/85222.html)

## ACK产品版本对比

| 版本 | 控制平面 | 适用场景 | 成本 | SLA | 功能差异 |
|-----|---------|---------|------|-----|---------|
| **ACK专有版** | 用户管理 | 完全控制需求 | 按ECS计费 | 99.5% | 自行维护控制平面 |
| **ACK托管版** | 阿里云托管 | 一般生产环境 | 免控制平面费 | 99.95% | 自动运维控制平面 |
| **ACK Pro版** | 阿里云托管增强 | 大规模/高可用 | 按集群计费 | 99.95% | 增强调度/安全/可观测 |
| **ACK Serverless** | 完全托管 | 弹性场景 | 按Pod计费 | 99.95% | 无需管理节点 |
| **ACK Edge** | 边缘托管 | 边缘计算 | 混合计费 | - | 边缘节点管理 |
| **ACK One** | 多集群管理 | 多集群场景 | 按集群计费 | - | 跨集群编排 |

## ACK版本支持

| K8S版本 | ACK支持状态 | 推荐度 | EOL日期 |
|--------|------------|-------|--------|
| **v1.28** | 维护中 | 可用 | 参考官方 |
| **v1.29** | 维护中 | 推荐 | 参考官方 |
| **v1.30** | 维护中 | 推荐 | 参考官方 |
| **v1.31** | 最新稳定 | 强烈推荐 | - |
| **v1.32** | 最新 | 推荐 | - |

## ACR(容器镜像服务)集成

| 功能 | 配置方式 | 版本要求 | 说明 |
|-----|---------|---------|------|
| **免密拉取** | 集群配置开启 | v1.25+ | ACK自动配置imagePullSecrets |
| **镜像加速** | 按需开启 | v1.25+ | P2P加速大镜像分发 |
| **漏洞扫描** | ACR企业版 | - | 自动扫描CVE |
| **镜像签名** | ACR企业版 | v1.28+ | 内容信任验证 |
| **制品同步** | ACR配置 | - | 跨地域镜像同步 |
| **Helm Chart** | ACR企业版 | - | Helm Chart仓库 |

```yaml
# ACK免密拉取配置
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: registry.cn-hangzhou.aliyuncs.com/namespace/image:tag
  # 无需配置imagePullSecrets，ACK自动注入
```

## 云盘CSI集成

| 云盘类型 | StorageClass | IOPS | 适用场景 |
|---------|-------------|------|---------|
| **ESSD PL0** | alicloud-disk-essd-pl0 | 10,000 | 开发测试 |
| **ESSD PL1** | alicloud-disk-essd | 50,000 | 一般生产 |
| **ESSD PL2** | alicloud-disk-essd-pl2 | 100,000 | 中型数据库 |
| **ESSD PL3** | alicloud-disk-essd-pl3 | 1,000,000 | 大型数据库 |
| **SSD** | alicloud-disk-ssd | 25,000 | 一般应用 |
| **高效云盘** | alicloud-disk-efficiency | 5,000 | 冷数据 |

```yaml
# ESSD PL1 StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alicloud-disk-essd
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
  performanceLevel: PL1
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

## NAS CSI集成

| NAS类型 | 特点 | StorageClass | 适用场景 |
|--------|------|-------------|---------|
| **通用型NAS** | 标准性能 | alicloud-nas | 文件共享 |
| **极速型NAS** | 高性能 | alicloud-nas-extreme | 高IO需求 |
| **CPFS** | 并行文件系统 | alicloud-cpfs | AI/HPC |

## SLB负载均衡集成

| 注解 | 用途 | 示例值 |
|-----|------|-------|
| `service.beta.kubernetes.io/alibaba-cloud-loadbalancer-spec` | SLB规格 | slb.s2.small |
| `service.beta.kubernetes.io/alibaba-cloud-loadbalancer-address-type` | 地址类型 | internet/intranet |
| `service.beta.kubernetes.io/alibaba-cloud-loadbalancer-id` | 复用已有SLB | lb-xxx |
| `service.beta.kubernetes.io/alibaba-cloud-loadbalancer-force-override-listeners` | 覆盖监听 | true |
| `service.beta.kubernetes.io/alibaba-cloud-loadbalancer-bandwidth` | 带宽 | 100 |
| `service.beta.kubernetes.io/alibaba-cloud-loadbalancer-cert-id` | HTTPS证书 | cert-xxx |
| `service.beta.kubernetes.io/alibaba-cloud-loadbalancer-health-check-flag` | 健康检查 | on |

```yaml
# SLB Service示例
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
  annotations:
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-spec: "slb.s2.small"
    service.beta.kubernetes.io/alibaba-cloud-loadbalancer-address-type: "internet"
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx
```

## ALB Ingress集成

| 功能 | 注解 | 说明 |
|-----|------|------|
| **健康检查** | `alb.ingress.kubernetes.io/healthcheck-path` | 健康检查路径 |
| **SSL证书** | `alb.ingress.kubernetes.io/ssl-redirect` | HTTPS重定向 |
| **灰度发布** | `alb.ingress.kubernetes.io/canary` | 灰度流量控制 |
| **限流** | `alb.ingress.kubernetes.io/traffic-limit-qps` | QPS限制 |
| **跨域** | `alb.ingress.kubernetes.io/enable-cors` | CORS支持 |
| **后端协议** | `alb.ingress.kubernetes.io/backend-protocol` | HTTP/HTTPS/gRPC |

## Terway CNI网络模式

| 模式 | 说明 | 性能 | IP消耗 | 适用场景 |
|-----|------|------|-------|---------|
| **VPC** | VPC路由模式 | 高 | 低 | 小型集群 |
| **ENI** | 弹性网卡模式 | 最高 | 高 | 性能敏感 |
| **ENIIP** | ENI多IP模式 | 高 | 中 | 大型集群推荐 |
| **Trunk ENI** | 中继ENI模式 | 最高 | 中 | 高密度部署 |

## ARMS可观测性集成

| 功能 | 配置方式 | 数据源 |
|-----|---------|-------|
| **Prometheus监控** | 组件安装 | 组件指标 |
| **应用监控** | Agent注入 | APM数据 |
| **前端监控** | SDK集成 | 前端性能 |
| **告警** | 控制台配置 | 所有数据源 |
| **Grafana** | 自动集成 | Prometheus |

## SLS日志集成

| 功能 | 配置方式 | 采集对象 |
|-----|---------|---------|
| **容器日志** | Logtail DaemonSet | stdout/文件日志 |
| **K8S事件** | 控制台开启 | Event API |
| **Ingress日志** | 注解配置 | 访问日志 |
| **审计日志** | 控制台开启 | API审计 |

```yaml
# Logtail采集配置
apiVersion: log.alibabacloud.com/v1alpha1
kind: AliyunLogConfig
metadata:
  name: app-stdout
spec:
  logstore: app-stdout
  shardCount: 2
  lifeCycle: 30
  logtailConfig:
    inputType: plugin
    configName: app-stdout
    inputDetail:
      plugin:
        inputs:
        - type: service_docker_stdout
          detail:
            Stdout: true
            Stderr: true
            IncludeEnv:
              APP: "myapp"
```

## 弹性伸缩集成

| 功能 | 配置方式 | 触发条件 |
|-----|---------|---------|
| **节点自动伸缩** | 节点池配置 | Pod资源需求 |
| **定时伸缩** | 节点池配置 | Cron表达式 |
| **Virtual Node** | 组件安装 | ECI扩展 |
| **Spot实例** | 节点池配置 | 成本优化 |

## 安全集成

| 功能 | 产品 | 配置方式 |
|-----|------|---------|
| **Secret加密** | KMS | 集群配置 |
| **镜像签名** | ACR+KMS | 策略配置 |
| **网络隔离** | 安全组 | 节点池配置 |
| **运行时安全** | 云安全中心 | Agent安装 |
| **审计** | 操作审计 | 自动集成 |
| **合规检查** | 配置审计 | 规则配置 |

## ACK常用CLI命令

```bash
# 获取集群列表
aliyun cs DescribeClustersV1

# 获取kubeconfig
aliyun cs GET /k8s/<cluster-id>/user_config | jq -r '.config' > ~/.kube/config

# 获取集群详情
aliyun cs DescribeClusterDetail --ClusterId <cluster-id>

# 升级集群
aliyun cs UpgradeCluster --ClusterId <cluster-id> --version 1.31.x

# 添加节点池
aliyun cs CreateClusterNodePool --ClusterId <cluster-id> --body '{...}'

# 扩容节点池
aliyun cs ScaleClusterNodePool --ClusterId <cluster-id> --NodepoolId <nodepool-id> --body '{"count": 5}'
```

## ACK成本优化

| 优化项 | 方法 | 节省比例 |
|-------|------|---------|
| **Spot实例** | 节点池配置 | 50-90% |
| **预留实例** | 提前购买 | 30-60% |
| **节省计划** | 承诺使用 | 20-50% |
| **弹性伸缩** | 按需扩缩 | 变化 |
| **资源画像** | ARMS分析 | 优化资源配置 |
| **SLB复用** | 注解配置 | 减少SLB数量 |

---

**ACK最佳实践**: 使用Pro版，配置弹性伸缩，集成ARMS监控，启用安全加固

## ACK版本对齐详表

> **官方版本说明**: [https://help.aliyun.com/document_detail/86508.html](https://help.aliyun.com/document_detail/86508.html)

| ACK版本 | 对应K8S | 发布状态 | EOL | 独特特性 | 兼容变更 | 运维提示 |
|--------|---------|---------|-----|---------|---------|---------|
| **ACK 1.28** | K8S 1.28 | 维护中 | 官方公告 | Sidecar原生支持 | 调度API | 升级建议 |
| **ACK 1.29** | K8S 1.29 | 维护中 | 官方公告 | registry.k8s.io | 镜像仓库 | ACR配置 |
| **ACK 1.30** | K8S 1.30 | 推荐 | ~2025-06 | CEL校验、ACR加速 | SLB API | RAM权限 |
| **ACK 1.31** | K8S 1.31 | 强烈推荐 | ~2025-10 | Sidecar GA、ASM集成 | 网络策略 | 配额检查 |
| **ACK 1.32** | K8S 1.32 | 最新 | ~2026-02 | Job可观测、GPU优化 | CSI增强 | 存储验证 |

### ACK vs 原生K8s差异

| 差异项 | 原生K8s | ACK | 说明 |
|-------|---------|-----|------|
| **控制平面** | 自行管理 | 托管 | 免运维 |
| **etcd** | 自行部署 | 托管+备份 | 自动备份 |
| **网络** | 任意CNI | Terway/Flannel | 云原生 |
| **存储** | 任意CSI | 云盘/NAS/OSS | 云集成 |
| **监控** | 自行配置 | ARMS集成 | 一键开启 |
| **安全** | 自行配置 | 云安全中心 | 托管扫描 |
| **升级** | 手动 | 控制台/API | 灰度支持 |
