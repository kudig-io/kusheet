# 表格24：边缘计算集成表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubeedge.io](https://kubeedge.io/) | [openyurt.io](https://openyurt.io/)

## 边缘计算框架对比

| 框架 | 维护方 | 特点 | K8S兼容 | 离线支持 | ACK集成 |
|-----|-------|------|---------|---------|---------|
| **KubeEdge** | CNCF | 云边协同，设备管理 | v1.25+ | 强 | 支持 |
| **OpenYurt** | CNCF/阿里 | 无侵入，原生兼容 | v1.25+ | 强 | 原生 |
| **K3s** | Rancher | 轻量级K8S | 独立发行版 | 强 | - |
| **MicroK8s** | Canonical | 单节点K8S | 独立发行版 | 中 | - |
| **SuperEdge** | 腾讯 | 边缘自治 | v1.25+ | 强 | - |
| **Akri** | Microsoft | 设备发现 | v1.25+ | 中 | - |

## KubeEdge架构

| 组件 | 位置 | 功能 | 部署方式 |
|-----|------|------|---------|
| **CloudCore** | 云端 | 云边通信，同步管理 | Deployment |
| **EdgeCore** | 边缘 | 节点代理，本地管理 | 二进制/容器 |
| **EdgeMesh** | 边缘 | 边边通信，服务发现 | DaemonSet |
| **Mapper** | 边缘 | 设备协议适配 | DaemonSet |
| **DeviceController** | 云端 | 设备管理 | Deployment |

```bash
# KubeEdge安装
# 云端
keadm init --advertise-address="云端IP" --kubeedge-version=1.15.0

# 边缘
keadm join --cloudcore-ipport=云端IP:10000 \
  --token=<token> \
  --kubeedge-version=1.15.0 \
  --edgenode-name=edge-node-1
```

```yaml
# KubeEdge设备模型
apiVersion: devices.kubeedge.io/v1alpha2
kind: DeviceModel
metadata:
  name: temperature-sensor
spec:
  properties:
  - name: temperature
    description: 温度值
    type:
      int:
        accessMode: ReadOnly
        maximum: 100
        minimum: -40
        unit: 摄氏度
---
# 设备实例
apiVersion: devices.kubeedge.io/v1alpha2
kind: Device
metadata:
  name: temperature-sensor-01
spec:
  deviceModelRef:
    name: temperature-sensor
  nodeSelector:
    nodeSelectorTerms:
    - matchExpressions:
      - key: "node-role.kubernetes.io/edge"
        operator: In
        values: [""]
  protocol:
    modbus:
      slaveID: 1
```

## OpenYurt架构

| 组件 | 位置 | 功能 | 部署方式 |
|-----|------|------|---------|
| **Yurt-Manager** | 云端 | 控制器管理 | Deployment |
| **Yurt-Controller-Manager** | 云端 | 节点和Pod生命周期 | Deployment |
| **YurtHub** | 边缘 | API缓存代理 | Static Pod |
| **Yurt-Tunnel-Server** | 云端 | 云边隧道服务端 | Deployment |
| **Yurt-Tunnel-Agent** | 边缘 | 云边隧道客户端 | DaemonSet |
| **Raven** | 边缘 | 跨地域网络 | DaemonSet |

```bash
# OpenYurt安装
# 使用yurtadm
yurtadm init --apiserver-advertise-address=<master-ip> \
  --openyurt-version=latest \
  --pod-network-cidr=10.244.0.0/16

# 转换现有集群
yurtadm convert --cloud-nodes=<cloud-node> \
  --openyurt-version=latest
  
# 添加边缘节点
yurtadm join <master-ip>:6443 --token <token> \
  --node-type=edge \
  --discovery-token-ca-cert-hash sha256:<hash>
```

```yaml
# OpenYurt NodePool
apiVersion: apps.openyurt.io/v1beta1
kind: NodePool
metadata:
  name: beijing-edge
spec:
  type: Edge
  annotations:
    node.openyurt.io/autonomy: "true"
  taints:
  - key: apps.openyurt.io/nodepool
    value: beijing-edge
    effect: NoSchedule
---
# YurtAppSet(边缘应用)
apiVersion: apps.openyurt.io/v1alpha1
kind: YurtAppSet
metadata:
  name: nginx-edge
spec:
  selector:
    matchLabels:
      app: nginx-edge
  workloadTemplate:
    deploymentTemplate:
      metadata:
        labels:
          app: nginx-edge
      spec:
        replicas: 1
        selector:
          matchLabels:
            app: nginx-edge
        template:
          metadata:
            labels:
              app: nginx-edge
          spec:
            containers:
            - name: nginx
              image: nginx:latest
  topology:
    pools:
    - beijing-edge
    - shanghai-edge
```

## 边缘节点管理

| 功能 | KubeEdge | OpenYurt | K3s |
|-----|---------|---------|-----|
| **离线自治** | EdgeCore缓存 | YurtHub缓存 | 本地etcd |
| **云边通信** | WebSocket | 反向隧道 | N/A |
| **设备管理** | Device CRD | 需扩展 | 需扩展 |
| **边边通信** | EdgeMesh | Raven | Flannel |
| **资源要求** | 中等 | 低 | 很低 |

## 边缘应用部署模式

| 模式 | 描述 | 适用场景 | 实现方式 |
|-----|------|---------|---------|
| **单元化部署** | 每个边缘节点池独立副本 | 地域分布应用 | NodePool+YurtAppSet |
| **流量本地化** | 优先访问本地服务 | 减少延迟 | 服务拓扑 |
| **边缘自治** | 离线时保持运行 | 弱网环境 | 本地缓存 |
| **设备直连** | Pod直连设备 | IoT场景 | 设备映射 |

## 边缘网络

| 网络类型 | 特点 | 实现方式 | 适用场景 |
|---------|------|---------|---------|
| **云边网络** | 云端访问边缘 | 隧道/VPN | 管理运维 |
| **边边网络** | 边缘节点间 | Overlay/直连 | 服务调用 |
| **边设网络** | 边缘访问设备 | 协议转换 | IoT |

## 边缘存储

| 存储类型 | 描述 | 适用场景 |
|---------|------|---------|
| **本地存储** | hostPath/local PV | 高性能，单节点 |
| **边缘分布式** | MinIO/边缘NAS | 多节点共享 |
| **云端同步** | 定期同步到云 | 数据备份 |

## ACK@Edge

| 功能 | 描述 | 配置方式 |
|-----|------|---------|
| **边缘托管节点池** | 托管边缘节点 | 控制台创建 |
| **单元化部署** | UnitedDeployment | YAML |
| **边缘自治** | 离线运行 | 自动 |
| **流量闭环** | 本地优先 | ServiceTopology |
| **边缘Ingress** | 边缘入口 | 边缘Ingress控制器 |

```yaml
# ACK@Edge UnitedDeployment
apiVersion: apps.kruise.io/v1alpha1
kind: UnitedDeployment
metadata:
  name: nginx-united
spec:
  replicas: 6
  selector:
    matchLabels:
      app: nginx
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:latest
  topology:
    pools:
    - name: beijing
      nodeSelectorTerm:
        matchExpressions:
        - key: apps.openyurt.io/nodepool
          operator: In
          values: [beijing-edge]
      replicas: 2
    - name: shanghai
      nodeSelectorTerm:
        matchExpressions:
        - key: apps.openyurt.io/nodepool
          operator: In
          values: [shanghai-edge]
      replicas: 2
    - name: cloud
      nodeSelectorTerm:
        matchExpressions:
        - key: node-role.kubernetes.io/master
          operator: DoesNotExist
      replicas: 2
```

## 边缘场景最佳实践

| 实践 | 说明 | 优先级 |
|-----|------|-------|
| **离线测试** | 验证断网后应用运行 | P0 |
| **资源限制** | 边缘资源有限，设置limits | P0 |
| **镜像预置** | 提前分发镜像到边缘 | P1 |
| **本地存储** | 使用本地存储减少延迟 | P1 |
| **监控上报** | 配置边缘监控 | P1 |
| **增量更新** | 减少更新流量 | P2 |

---

**边缘原则**: 边缘自治，本地优先，弱网适应
