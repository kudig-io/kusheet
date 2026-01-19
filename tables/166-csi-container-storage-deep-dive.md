# CSI 容器存储接口深度解析 (Container Storage Interface Deep Dive)

## 目录

1. [CSI 架构概述](#1-csi-架构概述)
2. [CSI 规范详解](#2-csi-规范详解)
3. [CSI 组件架构](#3-csi-组件架构)
4. [CSI 驱动开发](#4-csi-驱动开发)
5. [主流 CSI 驱动详解](#5-主流-csi-驱动详解)
6. [存储卷操作](#6-存储卷操作)
7. [高级特性](#7-高级特性)
8. [CSI 配置与调优](#8-csi-配置与调优)
9. [监控与故障排查](#9-监控与故障排查)
10. [生产实践案例](#10-生产实践案例)

---

## 1. CSI 架构概述

### 1.1 存储接口演进历史

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                     Kubernetes Storage Interface Evolution                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  Kubernetes 1.0 - 1.8          Kubernetes 1.9 - 1.12      Kubernetes 1.13+      │
│  ┌─────────────────────┐       ┌─────────────────────┐    ┌─────────────────────┐│
│  │   In-Tree Plugins   │       │   Flexvolume + CSI  │    │     CSI Only        ││
│  │                     │       │      (过渡期)        │    │    (推荐)           ││
│  │  - AWS EBS          │       │                     │    │                     ││
│  │  - GCE PD           │  ───► │  - In-Tree 废弃     │ ──►│  - CSI 驱动         ││
│  │  - Azure Disk       │       │  - CSI Alpha/Beta   │    │  - In-Tree 迁移     ││
│  │  - Cinder           │       │  - Flexvolume       │    │  - 统一接口         ││
│  │  - NFS              │       │                     │    │                     ││
│  │  - ...              │       │                     │    │                     ││
│  └─────────────────────┘       └─────────────────────┘    └─────────────────────┘│
│                                                                                  │
│  问题:                          过渡方案:                  优势:                 │
│  - 代码耦合在 K8s 核心          - Flexvolume 脚本化       - 解耦                 │
│  - 发布周期受限                 - CSI 标准化              - 独立发布             │
│  - 跨平台困难                   - 双轨并行                - 跨平台               │
│                                                           - 标准化              │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 CSI 里程碑

| 版本 | Kubernetes 版本 | CSI 状态 | 主要特性 |
|------|-----------------|----------|----------|
| v0.1 | 1.9 | Alpha | 初始设计 |
| v0.2 | 1.10 | Alpha | Snapshot 支持 |
| v0.3 | 1.11 | Beta | 拓扑感知 |
| v1.0 | 1.13 | GA | 稳定版本 |
| v1.1 | 1.14 | GA | Volume Expansion |
| v1.2 | 1.15 | GA | 原始块设备 |
| v1.3 | 1.17 | GA | Volume Cloning |
| v1.4 | 1.18 | GA | Snapshot GA |
| v1.5 | 1.20 | GA | FSGroup Policy |
| v1.6 | 1.23 | GA | Volume Health |
| v1.7 | 1.24 | GA | ReadWriteOncePod |
| v1.8 | 1.27 | GA | SELinux Context |
| v1.9 | 1.29 | GA | VolumeAttributesClass |

### 1.3 CSI 架构概览

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           CSI Architecture Overview                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                        Kubernetes Control Plane                          │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │                         API Server                                   ││    │
│  │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────────────┐││    │
│  │  │  │   PV    │ │  PVC    │ │   SC    │ │ VSClass │ │VolumeSnapshot   │││    │
│  │  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────────────┘││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                    │                                             │
│          ┌─────────────────────────┼─────────────────────────┐                  │
│          │                         │                         │                   │
│          ▼                         ▼                         ▼                   │
│  ┌───────────────┐        ┌───────────────┐         ┌───────────────┐           │
│  │  external-    │        │  external-    │         │  external-    │           │
│  │  provisioner  │        │  attacher     │         │  snapshotter  │           │
│  │               │        │               │         │               │           │
│  │ (动态创建 PV)  │        │ (挂载到节点)   │         │ (快照管理)    │           │
│  └───────┬───────┘        └───────┬───────┘         └───────┬───────┘           │
│          │                        │                         │                   │
│          │ CSI gRPC               │ CSI gRPC                │ CSI gRPC          │
│          │                        │                         │                   │
│          ▼                        ▼                         ▼                   │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                         CSI Controller Plugin                            │    │
│  │                    (通常与 Sidecar 容器一起部署)                          │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │  Controller Service                                                  ││    │
│  │  │  - CreateVolume / DeleteVolume                                       ││    │
│  │  │  - ControllerPublishVolume / ControllerUnpublishVolume               ││    │
│  │  │  - CreateSnapshot / DeleteSnapshot                                   ││    │
│  │  │  - ControllerExpandVolume                                            ││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ════════════════════════════════════════════════════════════════════════════   │
│                                  节点边界                                        │
│  ════════════════════════════════════════════════════════════════════════════   │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                              Node (每个节点)                             │    │
│  │  ┌───────────────┐                                                       │    │
│  │  │    Kubelet    │                                                       │    │
│  │  └───────┬───────┘                                                       │    │
│  │          │ CSI gRPC                                                      │    │
│  │          ▼                                                               │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │                          CSI Node Plugin                             ││    │
│  │  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────────────┐││    │
│  │  │  │ node-driver │ │  livenessp  │ │          Node Service           │││    │
│  │  │  │  registrar  │ │    robe     │ │  - NodeStageVolume              │││    │
│  │  │  └─────────────┘ └─────────────┘ │  - NodeUnstageVolume            │││    │
│  │  │                                   │  - NodePublishVolume            │││    │
│  │  │                                   │  - NodeUnpublishVolume          │││    │
│  │  │                                   │  - NodeGetCapabilities          │││    │
│  │  │                                   └─────────────────────────────────┘││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  │                                    │                                     │    │
│  │                                    ▼                                     │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │                         Storage Backend                              ││    │
│  │  │     (云盘 / NFS / Ceph / 本地存储 / ...)                             ││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 1.4 CSI vs In-Tree vs Flexvolume

| 特性 | In-Tree Plugin | Flexvolume | CSI |
|------|----------------|------------|-----|
| **代码位置** | Kubernetes 核心 | 外部可执行文件 | 外部容器化驱动 |
| **发布周期** | 与 K8s 同步 | 独立 | 独立 |
| **接口类型** | Go 接口 | Shell 脚本 | gRPC |
| **部署方式** | 内置 | 主机二进制 | DaemonSet + Deployment |
| **动态配置** | 有限 | 有限 | 完整支持 |
| **功能丰富度** | 完整 | 有限 | 完整 |
| **社区支持** | 逐步废弃 | 已废弃 | 活跃 |
| **跨平台** | 困难 | 中等 | 良好 |

---

## 2. CSI 规范详解

### 2.1 CSI 服务定义

```protobuf
// CSI Identity Service - 必须实现
service Identity {
    // 获取插件信息
    rpc GetPluginInfo(GetPluginInfoRequest) returns (GetPluginInfoResponse);
    // 获取插件能力
    rpc GetPluginCapabilities(GetPluginCapabilitiesRequest) returns (GetPluginCapabilitiesResponse);
    // 健康检查
    rpc Probe(ProbeRequest) returns (ProbeResponse);
}

// CSI Controller Service - Controller 端实现
service Controller {
    // 创建卷
    rpc CreateVolume(CreateVolumeRequest) returns (CreateVolumeResponse);
    // 删除卷
    rpc DeleteVolume(DeleteVolumeRequest) returns (DeleteVolumeResponse);
    // 发布卷到节点 (Attach)
    rpc ControllerPublishVolume(ControllerPublishVolumeRequest) returns (ControllerPublishVolumeResponse);
    // 从节点取消发布卷 (Detach)
    rpc ControllerUnpublishVolume(ControllerUnpublishVolumeRequest) returns (ControllerUnpublishVolumeResponse);
    // 验证卷能力
    rpc ValidateVolumeCapabilities(ValidateVolumeCapabilitiesRequest) returns (ValidateVolumeCapabilitiesResponse);
    // 列出卷
    rpc ListVolumes(ListVolumesRequest) returns (ListVolumesResponse);
    // 获取容量
    rpc GetCapacity(GetCapacityRequest) returns (GetCapacityResponse);
    // 获取 Controller 能力
    rpc ControllerGetCapabilities(ControllerGetCapabilitiesRequest) returns (ControllerGetCapabilitiesResponse);
    // 创建快照
    rpc CreateSnapshot(CreateSnapshotRequest) returns (CreateSnapshotResponse);
    // 删除快照
    rpc DeleteSnapshot(DeleteSnapshotRequest) returns (DeleteSnapshotResponse);
    // 列出快照
    rpc ListSnapshots(ListSnapshotsRequest) returns (ListSnapshotsResponse);
    // 扩展卷
    rpc ControllerExpandVolume(ControllerExpandVolumeRequest) returns (ControllerExpandVolumeResponse);
    // 获取卷
    rpc ControllerGetVolume(ControllerGetVolumeRequest) returns (ControllerGetVolumeResponse);
}

// CSI Node Service - Node 端实现
service Node {
    // Stage 卷到全局挂载点
    rpc NodeStageVolume(NodeStageVolumeRequest) returns (NodeStageVolumeResponse);
    // Unstage 卷
    rpc NodeUnstageVolume(NodeUnstageVolumeRequest) returns (NodeUnstageVolumeResponse);
    // 发布卷到 Pod 目录
    rpc NodePublishVolume(NodePublishVolumeRequest) returns (NodePublishVolumeResponse);
    // 取消发布卷
    rpc NodeUnpublishVolume(NodeUnpublishVolumeRequest) returns (NodeUnpublishVolumeResponse);
    // 获取卷统计
    rpc NodeGetVolumeStats(NodeGetVolumeStatsRequest) returns (NodeGetVolumeStatsResponse);
    // 扩展卷
    rpc NodeExpandVolume(NodeExpandVolumeRequest) returns (NodeExpandVolumeResponse);
    // 获取 Node 能力
    rpc NodeGetCapabilities(NodeGetCapabilitiesRequest) returns (NodeGetCapabilitiesResponse);
    // 获取节点信息
    rpc NodeGetInfo(NodeGetInfoRequest) returns (NodeGetInfoResponse);
}
```

### 2.2 CSI 能力矩阵

| 能力 | Controller | Node | 描述 |
|------|------------|------|------|
| **CREATE_DELETE_VOLUME** | ✓ | - | 创建/删除卷 |
| **PUBLISH_UNPUBLISH_VOLUME** | ✓ | - | Attach/Detach 卷 |
| **LIST_VOLUMES** | ✓ | - | 列出所有卷 |
| **GET_CAPACITY** | ✓ | - | 获取存储容量 |
| **CREATE_DELETE_SNAPSHOT** | ✓ | - | 创建/删除快照 |
| **LIST_SNAPSHOTS** | ✓ | - | 列出快照 |
| **CLONE_VOLUME** | ✓ | - | 克隆卷 |
| **EXPAND_VOLUME** | ✓ | - | 扩展卷 (Controller) |
| **STAGE_UNSTAGE_VOLUME** | - | ✓ | Stage/Unstage 卷 |
| **GET_VOLUME_STATS** | - | ✓ | 获取卷统计 |
| **EXPAND_VOLUME** | - | ✓ | 扩展卷 (Node) |
| **VOLUME_CONDITION** | ✓ | ✓ | 卷健康状态 |
| **SINGLE_NODE_MULTI_WRITER** | - | ✓ | 单节点多写 |

### 2.3 CSI 访问模式

| 访问模式 | 缩写 | 描述 | 典型存储 |
|----------|------|------|----------|
| ReadWriteOnce | RWO | 单节点读写 | 块存储 (EBS, Azure Disk) |
| ReadOnlyMany | ROX | 多节点只读 | NFS, CephFS |
| ReadWriteMany | RWX | 多节点读写 | NFS, CephFS, GlusterFS |
| ReadWriteOncePod | RWOP | 单 Pod 读写 | 块存储 (K8s 1.22+) |

### 2.4 CSI 卷模式

| 卷模式 | 描述 | 使用场景 |
|--------|------|----------|
| **Filesystem** | 格式化为文件系统后挂载 | 大多数应用 |
| **Block** | 原始块设备直接挂载 | 数据库、高性能存储 |

```yaml
# Filesystem 模式 (默认)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fs-pvc
spec:
  accessModes:
  - ReadWriteOnce
  volumeMode: Filesystem  # 默认
  resources:
    requests:
      storage: 10Gi

---
# Block 模式
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: block-pvc
spec:
  accessModes:
  - ReadWriteOnce
  volumeMode: Block  # 原始块设备
  resources:
    requests:
      storage: 10Gi

---
# 使用 Block 模式的 Pod
apiVersion: v1
kind: Pod
metadata:
  name: block-pod
spec:
  containers:
  - name: app
    image: myapp
    volumeDevices:  # 注意：使用 volumeDevices 而非 volumeMounts
    - name: data
      devicePath: /dev/xvda  # 设备路径
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: block-pvc
```

---

## 3. CSI 组件架构

### 3.1 CSI Sidecar 容器

| Sidecar 组件 | 功能 | 部署位置 |
|--------------|------|----------|
| **external-provisioner** | 动态创建/删除 PV | Controller |
| **external-attacher** | Attach/Detach 卷到节点 | Controller |
| **external-snapshotter** | 创建/删除快照 | Controller |
| **external-resizer** | 扩展卷 | Controller |
| **livenessprobe** | 健康检查 | Controller/Node |
| **node-driver-registrar** | 向 Kubelet 注册驱动 | Node |
| **csi-proxy** | Windows 节点支持 | Node (Windows) |

### 3.2 CSI Controller 部署架构

```yaml
# CSI Controller Deployment 示例
apiVersion: apps/v1
kind: Deployment
metadata:
  name: csi-controller
  namespace: kube-system
spec:
  replicas: 2  # 高可用
  selector:
    matchLabels:
      app: csi-controller
  template:
    metadata:
      labels:
        app: csi-controller
    spec:
      serviceAccountName: csi-controller-sa
      priorityClassName: system-cluster-critical
      nodeSelector:
        node-role.kubernetes.io/control-plane: ""
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      containers:
      # CSI 驱动主容器
      - name: csi-driver
        image: myregistry/csi-driver:v1.0.0
        args:
        - --endpoint=$(CSI_ENDPOINT)
        - --nodeid=$(NODE_ID)
        env:
        - name: CSI_ENDPOINT
          value: unix:///csi/csi.sock
        - name: NODE_ID
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        volumeMounts:
        - name: socket-dir
          mountPath: /csi
        resources:
          limits:
            memory: 256Mi
            cpu: 200m
          requests:
            memory: 128Mi
            cpu: 100m
      
      # external-provisioner
      - name: csi-provisioner
        image: registry.k8s.io/sig-storage/csi-provisioner:v3.6.0
        args:
        - --csi-address=$(ADDRESS)
        - --v=5
        - --feature-gates=Topology=true
        - --leader-election=true
        - --leader-election-namespace=$(NAMESPACE)
        - --timeout=60s
        - --retry-interval-start=1s
        - --retry-interval-max=5m
        env:
        - name: ADDRESS
          value: /csi/csi.sock
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: socket-dir
          mountPath: /csi
      
      # external-attacher
      - name: csi-attacher
        image: registry.k8s.io/sig-storage/csi-attacher:v4.4.0
        args:
        - --csi-address=$(ADDRESS)
        - --v=5
        - --leader-election=true
        - --leader-election-namespace=$(NAMESPACE)
        - --timeout=60s
        env:
        - name: ADDRESS
          value: /csi/csi.sock
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: socket-dir
          mountPath: /csi
      
      # external-snapshotter
      - name: csi-snapshotter
        image: registry.k8s.io/sig-storage/csi-snapshotter:v6.3.0
        args:
        - --csi-address=$(ADDRESS)
        - --v=5
        - --leader-election=true
        - --leader-election-namespace=$(NAMESPACE)
        env:
        - name: ADDRESS
          value: /csi/csi.sock
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: socket-dir
          mountPath: /csi
      
      # external-resizer
      - name: csi-resizer
        image: registry.k8s.io/sig-storage/csi-resizer:v1.9.0
        args:
        - --csi-address=$(ADDRESS)
        - --v=5
        - --leader-election=true
        - --leader-election-namespace=$(NAMESPACE)
        env:
        - name: ADDRESS
          value: /csi/csi.sock
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: socket-dir
          mountPath: /csi
      
      # livenessprobe
      - name: liveness-probe
        image: registry.k8s.io/sig-storage/livenessprobe:v2.11.0
        args:
        - --csi-address=/csi/csi.sock
        - --health-port=9808
        volumeMounts:
        - name: socket-dir
          mountPath: /csi
      
      volumes:
      - name: socket-dir
        emptyDir: {}
```

### 3.3 CSI Node 部署架构

```yaml
# CSI Node DaemonSet 示例
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: csi-node
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: csi-node
  template:
    metadata:
      labels:
        app: csi-node
    spec:
      serviceAccountName: csi-node-sa
      priorityClassName: system-node-critical
      hostNetwork: true
      containers:
      # CSI 驱动主容器
      - name: csi-driver
        image: myregistry/csi-driver:v1.0.0
        args:
        - --endpoint=$(CSI_ENDPOINT)
        - --nodeid=$(NODE_ID)
        env:
        - name: CSI_ENDPOINT
          value: unix:///csi/csi.sock
        - name: NODE_ID
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        securityContext:
          privileged: true
        volumeMounts:
        - name: socket-dir
          mountPath: /csi
        - name: mountpoint-dir
          mountPath: /var/lib/kubelet/pods
          mountPropagation: Bidirectional
        - name: plugin-dir
          mountPath: /var/lib/kubelet/plugins
          mountPropagation: Bidirectional
        - name: device-dir
          mountPath: /dev
      
      # node-driver-registrar
      - name: node-driver-registrar
        image: registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.9.0
        args:
        - --csi-address=$(ADDRESS)
        - --kubelet-registration-path=$(DRIVER_REG_SOCK_PATH)
        - --v=5
        env:
        - name: ADDRESS
          value: /csi/csi.sock
        - name: DRIVER_REG_SOCK_PATH
          value: /var/lib/kubelet/plugins/my-csi-driver/csi.sock
        volumeMounts:
        - name: socket-dir
          mountPath: /csi
        - name: registration-dir
          mountPath: /registration
      
      # livenessprobe
      - name: liveness-probe
        image: registry.k8s.io/sig-storage/livenessprobe:v2.11.0
        args:
        - --csi-address=/csi/csi.sock
        - --health-port=9808
        volumeMounts:
        - name: socket-dir
          mountPath: /csi
      
      volumes:
      - name: socket-dir
        hostPath:
          path: /var/lib/kubelet/plugins/my-csi-driver
          type: DirectoryOrCreate
      - name: mountpoint-dir
        hostPath:
          path: /var/lib/kubelet/pods
          type: Directory
      - name: plugin-dir
        hostPath:
          path: /var/lib/kubelet/plugins
          type: Directory
      - name: registration-dir
        hostPath:
          path: /var/lib/kubelet/plugins_registry
          type: Directory
      - name: device-dir
        hostPath:
          path: /dev
          type: Directory
```

### 3.4 CSI 卷挂载流程

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         CSI Volume Mount Workflow                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  1. PVC 创建                                                                     │
│     kubectl apply -f pvc.yaml                                                   │
│           │                                                                      │
│           ▼                                                                      │
│  2. external-provisioner Watch PVC                                              │
│     检测到 PVC 使用对应 StorageClass                                             │
│           │                                                                      │
│           ▼                                                                      │
│  3. external-provisioner 调用 CSI CreateVolume                                  │
│     CSI Driver ──► 存储后端创建卷                                                │
│           │                                                                      │
│           ▼                                                                      │
│  4. 创建 PV 对象并绑定 PVC                                                       │
│     PV.spec.claimRef = PVC                                                      │
│           │                                                                      │
│           ▼                                                                      │
│  5. Pod 调度到节点                                                               │
│     Scheduler 考虑存储拓扑约束                                                   │
│           │                                                                      │
│           ▼                                                                      │
│  6. external-attacher Watch VolumeAttachment                                    │
│     AD Controller 创建 VolumeAttachment 对象                                    │
│           │                                                                      │
│           ▼                                                                      │
│  7. external-attacher 调用 CSI ControllerPublishVolume                          │
│     CSI Driver ──► 存储后端 Attach 卷到节点                                      │
│           │                                                                      │
│           ▼                                                                      │
│  8. Kubelet VolumeManager Watch Pod                                             │
│     检测到 Pod 需要挂载卷                                                        │
│           │                                                                      │
│           ▼                                                                      │
│  9. Kubelet 调用 CSI NodeStageVolume                                            │
│     CSI Driver ──► 格式化并挂载到全局目录                                        │
│     /var/lib/kubelet/plugins/kubernetes.io/csi/pv/<pv-name>/globalmount         │
│           │                                                                      │
│           ▼                                                                      │
│  10. Kubelet 调用 CSI NodePublishVolume                                         │
│      CSI Driver ──► bind mount 到 Pod 目录                                      │
│      /var/lib/kubelet/pods/<pod-uid>/volumes/kubernetes.io~csi/<pv-name>/mount  │
│           │                                                                      │
│           ▼                                                                      │
│  11. 容器启动，卷挂载完成                                                        │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. CSI 驱动开发

### 4.1 CSI 驱动项目结构

```
my-csi-driver/
├── cmd/
│   └── csi-driver/
│       └── main.go           # 入口文件
├── pkg/
│   ├── driver/
│   │   ├── driver.go         # 驱动主逻辑
│   │   ├── identity.go       # Identity Service
│   │   ├── controller.go     # Controller Service
│   │   └── node.go           # Node Service
│   ├── cloud/
│   │   └── provider.go       # 存储后端交互
│   └── util/
│       └── util.go           # 工具函数
├── deploy/
│   ├── kubernetes/
│   │   ├── controller.yaml   # Controller 部署
│   │   ├── node.yaml         # Node 部署
│   │   ├── rbac.yaml         # RBAC 配置
│   │   └── storageclass.yaml # StorageClass
│   └── helm/
│       └── csi-driver/
│           ├── Chart.yaml
│           ├── values.yaml
│           └── templates/
├── Dockerfile
├── Makefile
└── go.mod
```

### 4.2 Identity Service 实现

```go
package driver

import (
    "context"
    
    "github.com/container-storage-interface/spec/lib/go/csi"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
)

type IdentityServer struct {
    name    string
    version string
}

func NewIdentityServer(name, version string) *IdentityServer {
    return &IdentityServer{
        name:    name,
        version: version,
    }
}

// GetPluginInfo 返回插件信息
func (s *IdentityServer) GetPluginInfo(
    ctx context.Context,
    req *csi.GetPluginInfoRequest,
) (*csi.GetPluginInfoResponse, error) {
    return &csi.GetPluginInfoResponse{
        Name:          s.name,
        VendorVersion: s.version,
    }, nil
}

// GetPluginCapabilities 返回插件能力
func (s *IdentityServer) GetPluginCapabilities(
    ctx context.Context,
    req *csi.GetPluginCapabilitiesRequest,
) (*csi.GetPluginCapabilitiesResponse, error) {
    return &csi.GetPluginCapabilitiesResponse{
        Capabilities: []*csi.PluginCapability{
            {
                Type: &csi.PluginCapability_Service_{
                    Service: &csi.PluginCapability_Service{
                        Type: csi.PluginCapability_Service_CONTROLLER_SERVICE,
                    },
                },
            },
            {
                Type: &csi.PluginCapability_Service_{
                    Service: &csi.PluginCapability_Service{
                        Type: csi.PluginCapability_Service_VOLUME_ACCESSIBILITY_CONSTRAINTS,
                    },
                },
            },
            {
                Type: &csi.PluginCapability_VolumeExpansion_{
                    VolumeExpansion: &csi.PluginCapability_VolumeExpansion{
                        Type: csi.PluginCapability_VolumeExpansion_ONLINE,
                    },
                },
            },
        },
    }, nil
}

// Probe 健康检查
func (s *IdentityServer) Probe(
    ctx context.Context,
    req *csi.ProbeRequest,
) (*csi.ProbeResponse, error) {
    return &csi.ProbeResponse{
        Ready: &wrapperspb.BoolValue{Value: true},
    }, nil
}
```

### 4.3 Controller Service 实现

```go
package driver

import (
    "context"
    "fmt"
    
    "github.com/container-storage-interface/spec/lib/go/csi"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
)

type ControllerServer struct {
    cloud CloudProvider
    caps  []*csi.ControllerServiceCapability
}

func NewControllerServer(cloud CloudProvider) *ControllerServer {
    return &ControllerServer{
        cloud: cloud,
        caps:  getControllerServiceCapabilities(),
    }
}

// CreateVolume 创建卷
func (s *ControllerServer) CreateVolume(
    ctx context.Context,
    req *csi.CreateVolumeRequest,
) (*csi.CreateVolumeResponse, error) {
    // 参数验证
    if req.Name == "" {
        return nil, status.Error(codes.InvalidArgument, "volume name is required")
    }
    
    // 获取请求的容量
    requiredBytes := req.CapacityRange.GetRequiredBytes()
    if requiredBytes == 0 {
        requiredBytes = 10 * 1024 * 1024 * 1024 // 默认 10GB
    }
    
    // 获取存储参数
    params := req.GetParameters()
    volumeType := params["type"]
    if volumeType == "" {
        volumeType = "gp3"
    }
    
    // 处理拓扑约束
    var zone string
    if req.AccessibilityRequirements != nil {
        for _, topo := range req.AccessibilityRequirements.Preferred {
            if z, ok := topo.Segments["topology.kubernetes.io/zone"]; ok {
                zone = z
                break
            }
        }
    }
    
    // 检查是否是从快照恢复
    var snapshotID string
    if req.VolumeContentSource != nil {
        if snapshot := req.VolumeContentSource.GetSnapshot(); snapshot != nil {
            snapshotID = snapshot.SnapshotId
        }
    }
    
    // 调用云 API 创建卷
    volume, err := s.cloud.CreateVolume(ctx, CreateVolumeInput{
        Name:       req.Name,
        SizeBytes:  requiredBytes,
        VolumeType: volumeType,
        Zone:       zone,
        SnapshotID: snapshotID,
        Tags:       params,
    })
    if err != nil {
        return nil, status.Errorf(codes.Internal, "failed to create volume: %v", err)
    }
    
    return &csi.CreateVolumeResponse{
        Volume: &csi.Volume{
            VolumeId:      volume.ID,
            CapacityBytes: volume.SizeBytes,
            VolumeContext: map[string]string{
                "volumeType": volumeType,
            },
            AccessibleTopology: []*csi.Topology{
                {
                    Segments: map[string]string{
                        "topology.kubernetes.io/zone": volume.Zone,
                    },
                },
            },
        },
    }, nil
}

// DeleteVolume 删除卷
func (s *ControllerServer) DeleteVolume(
    ctx context.Context,
    req *csi.DeleteVolumeRequest,
) (*csi.DeleteVolumeResponse, error) {
    if req.VolumeId == "" {
        return nil, status.Error(codes.InvalidArgument, "volume ID is required")
    }
    
    if err := s.cloud.DeleteVolume(ctx, req.VolumeId); err != nil {
        return nil, status.Errorf(codes.Internal, "failed to delete volume: %v", err)
    }
    
    return &csi.DeleteVolumeResponse{}, nil
}

// ControllerPublishVolume Attach 卷到节点
func (s *ControllerServer) ControllerPublishVolume(
    ctx context.Context,
    req *csi.ControllerPublishVolumeRequest,
) (*csi.ControllerPublishVolumeResponse, error) {
    if req.VolumeId == "" {
        return nil, status.Error(codes.InvalidArgument, "volume ID is required")
    }
    if req.NodeId == "" {
        return nil, status.Error(codes.InvalidArgument, "node ID is required")
    }
    
    devicePath, err := s.cloud.AttachVolume(ctx, req.VolumeId, req.NodeId)
    if err != nil {
        return nil, status.Errorf(codes.Internal, "failed to attach volume: %v", err)
    }
    
    return &csi.ControllerPublishVolumeResponse{
        PublishContext: map[string]string{
            "devicePath": devicePath,
        },
    }, nil
}

// ControllerUnpublishVolume Detach 卷
func (s *ControllerServer) ControllerUnpublishVolume(
    ctx context.Context,
    req *csi.ControllerUnpublishVolumeRequest,
) (*csi.ControllerUnpublishVolumeResponse, error) {
    if err := s.cloud.DetachVolume(ctx, req.VolumeId, req.NodeId); err != nil {
        return nil, status.Errorf(codes.Internal, "failed to detach volume: %v", err)
    }
    
    return &csi.ControllerUnpublishVolumeResponse{}, nil
}

// CreateSnapshot 创建快照
func (s *ControllerServer) CreateSnapshot(
    ctx context.Context,
    req *csi.CreateSnapshotRequest,
) (*csi.CreateSnapshotResponse, error) {
    snapshot, err := s.cloud.CreateSnapshot(ctx, req.SourceVolumeId, req.Name)
    if err != nil {
        return nil, status.Errorf(codes.Internal, "failed to create snapshot: %v", err)
    }
    
    return &csi.CreateSnapshotResponse{
        Snapshot: &csi.Snapshot{
            SnapshotId:     snapshot.ID,
            SourceVolumeId: req.SourceVolumeId,
            CreationTime:   timestamppb.New(snapshot.CreationTime),
            ReadyToUse:     snapshot.Ready,
            SizeBytes:      snapshot.SizeBytes,
        },
    }, nil
}

// ControllerExpandVolume 扩展卷
func (s *ControllerServer) ControllerExpandVolume(
    ctx context.Context,
    req *csi.ControllerExpandVolumeRequest,
) (*csi.ControllerExpandVolumeResponse, error) {
    newSize := req.CapacityRange.GetRequiredBytes()
    
    if err := s.cloud.ResizeVolume(ctx, req.VolumeId, newSize); err != nil {
        return nil, status.Errorf(codes.Internal, "failed to expand volume: %v", err)
    }
    
    return &csi.ControllerExpandVolumeResponse{
        CapacityBytes:         newSize,
        NodeExpansionRequired: true, // 需要在节点上扩展文件系统
    }, nil
}

// ControllerGetCapabilities 返回 Controller 能力
func (s *ControllerServer) ControllerGetCapabilities(
    ctx context.Context,
    req *csi.ControllerGetCapabilitiesRequest,
) (*csi.ControllerGetCapabilitiesResponse, error) {
    return &csi.ControllerGetCapabilitiesResponse{
        Capabilities: s.caps,
    }, nil
}

func getControllerServiceCapabilities() []*csi.ControllerServiceCapability {
    caps := []csi.ControllerServiceCapability_RPC_Type{
        csi.ControllerServiceCapability_RPC_CREATE_DELETE_VOLUME,
        csi.ControllerServiceCapability_RPC_PUBLISH_UNPUBLISH_VOLUME,
        csi.ControllerServiceCapability_RPC_CREATE_DELETE_SNAPSHOT,
        csi.ControllerServiceCapability_RPC_LIST_SNAPSHOTS,
        csi.ControllerServiceCapability_RPC_CLONE_VOLUME,
        csi.ControllerServiceCapability_RPC_EXPAND_VOLUME,
        csi.ControllerServiceCapability_RPC_LIST_VOLUMES,
        csi.ControllerServiceCapability_RPC_VOLUME_CONDITION,
    }
    
    var capabilities []*csi.ControllerServiceCapability
    for _, cap := range caps {
        capabilities = append(capabilities, &csi.ControllerServiceCapability{
            Type: &csi.ControllerServiceCapability_Rpc{
                Rpc: &csi.ControllerServiceCapability_RPC{
                    Type: cap,
                },
            },
        })
    }
    return capabilities
}
```

### 4.4 Node Service 实现

```go
package driver

import (
    "context"
    "os"
    "path/filepath"
    
    "github.com/container-storage-interface/spec/lib/go/csi"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
    "k8s.io/mount-utils"
)

type NodeServer struct {
    nodeID  string
    mounter mount.Interface
    caps    []*csi.NodeServiceCapability
}

func NewNodeServer(nodeID string) *NodeServer {
    return &NodeServer{
        nodeID:  nodeID,
        mounter: mount.New(""),
        caps:    getNodeServiceCapabilities(),
    }
}

// NodeStageVolume 将卷挂载到全局目录
func (s *NodeServer) NodeStageVolume(
    ctx context.Context,
    req *csi.NodeStageVolumeRequest,
) (*csi.NodeStageVolumeResponse, error) {
    volumeID := req.GetVolumeId()
    stagingTargetPath := req.GetStagingTargetPath()
    
    // 获取设备路径
    devicePath := req.PublishContext["devicePath"]
    if devicePath == "" {
        return nil, status.Error(codes.InvalidArgument, "device path is required")
    }
    
    // 检查是否已挂载
    notMnt, err := s.mounter.IsLikelyNotMountPoint(stagingTargetPath)
    if err != nil {
        if os.IsNotExist(err) {
            if err := os.MkdirAll(stagingTargetPath, 0750); err != nil {
                return nil, status.Errorf(codes.Internal, "failed to create staging path: %v", err)
            }
            notMnt = true
        } else {
            return nil, status.Errorf(codes.Internal, "failed to check mount point: %v", err)
        }
    }
    
    if !notMnt {
        // 已经挂载
        return &csi.NodeStageVolumeResponse{}, nil
    }
    
    // 获取文件系统类型
    fsType := "ext4"
    if req.VolumeCapability.GetMount() != nil {
        if fs := req.VolumeCapability.GetMount().FsType; fs != "" {
            fsType = fs
        }
    }
    
    // 格式化并挂载
    mountOptions := []string{}
    if req.VolumeCapability.GetMount() != nil {
        mountOptions = req.VolumeCapability.GetMount().MountFlags
    }
    
    if err := s.mounter.FormatAndMount(devicePath, stagingTargetPath, fsType, mountOptions); err != nil {
        return nil, status.Errorf(codes.Internal, "failed to format and mount: %v", err)
    }
    
    return &csi.NodeStageVolumeResponse{}, nil
}

// NodeUnstageVolume 卸载全局目录
func (s *NodeServer) NodeUnstageVolume(
    ctx context.Context,
    req *csi.NodeUnstageVolumeRequest,
) (*csi.NodeUnstageVolumeResponse, error) {
    stagingTargetPath := req.GetStagingTargetPath()
    
    if err := mount.CleanupMountPoint(stagingTargetPath, s.mounter, true); err != nil {
        return nil, status.Errorf(codes.Internal, "failed to unmount staging path: %v", err)
    }
    
    return &csi.NodeUnstageVolumeResponse{}, nil
}

// NodePublishVolume 挂载到 Pod 目录
func (s *NodeServer) NodePublishVolume(
    ctx context.Context,
    req *csi.NodePublishVolumeRequest,
) (*csi.NodePublishVolumeResponse, error) {
    volumeID := req.GetVolumeId()
    targetPath := req.GetTargetPath()
    stagingTargetPath := req.GetStagingTargetPath()
    
    // 创建目标目录
    if err := os.MkdirAll(filepath.Dir(targetPath), 0750); err != nil {
        return nil, status.Errorf(codes.Internal, "failed to create target path: %v", err)
    }
    
    // 检查是否已挂载
    notMnt, err := s.mounter.IsLikelyNotMountPoint(targetPath)
    if err != nil {
        if os.IsNotExist(err) {
            if err := os.MkdirAll(targetPath, 0750); err != nil {
                return nil, status.Errorf(codes.Internal, "failed to create target path: %v", err)
            }
            notMnt = true
        } else {
            return nil, status.Errorf(codes.Internal, "failed to check mount point: %v", err)
        }
    }
    
    if !notMnt {
        return &csi.NodePublishVolumeResponse{}, nil
    }
    
    // 获取挂载选项
    mountOptions := []string{"bind"}
    if req.Readonly {
        mountOptions = append(mountOptions, "ro")
    }
    
    // 执行 bind mount
    if err := s.mounter.Mount(stagingTargetPath, targetPath, "", mountOptions); err != nil {
        return nil, status.Errorf(codes.Internal, "failed to mount: %v", err)
    }
    
    return &csi.NodePublishVolumeResponse{}, nil
}

// NodeUnpublishVolume 卸载 Pod 目录
func (s *NodeServer) NodeUnpublishVolume(
    ctx context.Context,
    req *csi.NodeUnpublishVolumeRequest,
) (*csi.NodeUnpublishVolumeResponse, error) {
    targetPath := req.GetTargetPath()
    
    if err := mount.CleanupMountPoint(targetPath, s.mounter, true); err != nil {
        return nil, status.Errorf(codes.Internal, "failed to unmount: %v", err)
    }
    
    return &csi.NodeUnpublishVolumeResponse{}, nil
}

// NodeGetVolumeStats 获取卷统计信息
func (s *NodeServer) NodeGetVolumeStats(
    ctx context.Context,
    req *csi.NodeGetVolumeStatsRequest,
) (*csi.NodeGetVolumeStatsResponse, error) {
    volumePath := req.GetVolumePath()
    
    var statfs syscall.Statfs_t
    if err := syscall.Statfs(volumePath, &statfs); err != nil {
        return nil, status.Errorf(codes.Internal, "failed to get volume stats: %v", err)
    }
    
    availableBytes := int64(statfs.Bavail) * int64(statfs.Bsize)
    totalBytes := int64(statfs.Blocks) * int64(statfs.Bsize)
    usedBytes := totalBytes - availableBytes
    
    availableInodes := int64(statfs.Ffree)
    totalInodes := int64(statfs.Files)
    usedInodes := totalInodes - availableInodes
    
    return &csi.NodeGetVolumeStatsResponse{
        Usage: []*csi.VolumeUsage{
            {
                Available: availableBytes,
                Total:     totalBytes,
                Used:      usedBytes,
                Unit:      csi.VolumeUsage_BYTES,
            },
            {
                Available: availableInodes,
                Total:     totalInodes,
                Used:      usedInodes,
                Unit:      csi.VolumeUsage_INODES,
            },
        },
    }, nil
}

// NodeExpandVolume 扩展文件系统
func (s *NodeServer) NodeExpandVolume(
    ctx context.Context,
    req *csi.NodeExpandVolumeRequest,
) (*csi.NodeExpandVolumeResponse, error) {
    volumePath := req.GetVolumePath()
    
    // 获取设备路径
    devicePath, _, err := mount.GetDeviceNameFromMount(s.mounter, volumePath)
    if err != nil {
        return nil, status.Errorf(codes.Internal, "failed to get device path: %v", err)
    }
    
    // 扩展文件系统
    resizer := mount.NewResizeFs(s.mounter.(*mount.SafeFormatAndMount).Exec)
    if _, err := resizer.Resize(devicePath, volumePath); err != nil {
        return nil, status.Errorf(codes.Internal, "failed to resize filesystem: %v", err)
    }
    
    return &csi.NodeExpandVolumeResponse{
        CapacityBytes: req.CapacityRange.GetRequiredBytes(),
    }, nil
}

// NodeGetInfo 获取节点信息
func (s *NodeServer) NodeGetInfo(
    ctx context.Context,
    req *csi.NodeGetInfoRequest,
) (*csi.NodeGetInfoResponse, error) {
    // 获取节点所在可用区
    zone := getNodeZone()
    
    return &csi.NodeGetInfoResponse{
        NodeId: s.nodeID,
        MaxVolumesPerNode: 16,  // 最大卷数
        AccessibleTopology: &csi.Topology{
            Segments: map[string]string{
                "topology.kubernetes.io/zone": zone,
            },
        },
    }, nil
}

// NodeGetCapabilities 返回 Node 能力
func (s *NodeServer) NodeGetCapabilities(
    ctx context.Context,
    req *csi.NodeGetCapabilitiesRequest,
) (*csi.NodeGetCapabilitiesResponse, error) {
    return &csi.NodeGetCapabilitiesResponse{
        Capabilities: s.caps,
    }, nil
}

func getNodeServiceCapabilities() []*csi.NodeServiceCapability {
    caps := []csi.NodeServiceCapability_RPC_Type{
        csi.NodeServiceCapability_RPC_STAGE_UNSTAGE_VOLUME,
        csi.NodeServiceCapability_RPC_EXPAND_VOLUME,
        csi.NodeServiceCapability_RPC_GET_VOLUME_STATS,
    }
    
    var capabilities []*csi.NodeServiceCapability
    for _, cap := range caps {
        capabilities = append(capabilities, &csi.NodeServiceCapability{
            Type: &csi.NodeServiceCapability_Rpc{
                Rpc: &csi.NodeServiceCapability_RPC{
                    Type: cap,
                },
            },
        })
    }
    return capabilities
}
```

---

## 5. 主流 CSI 驱动详解

### 5.1 云厂商 CSI 驱动对比

| CSI 驱动 | 存储类型 | 访问模式 | 快照 | 扩展 | 拓扑 |
|----------|----------|----------|------|------|------|
| **AWS EBS CSI** | 块存储 | RWO | ✓ | ✓ | ✓ |
| **AWS EFS CSI** | 文件存储 | RWX | - | - | ✓ |
| **Azure Disk CSI** | 块存储 | RWO | ✓ | ✓ | ✓ |
| **Azure File CSI** | 文件存储 | RWX | ✓ | ✓ | - |
| **GCE PD CSI** | 块存储 | RWO/ROX | ✓ | ✓ | ✓ |
| **Alibaba Cloud Disk** | 块存储 | RWO | ✓ | ✓ | ✓ |
| **Alibaba Cloud NAS** | 文件存储 | RWX | ✓ | ✓ | - |

### 5.2 AWS EBS CSI 驱动

```yaml
# StorageClass 配置
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
  kmsKeyId: arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012
  fsType: ext4
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer  # 延迟绑定
reclaimPolicy: Delete

---
# 安装 AWS EBS CSI 驱动
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::123456789012:role/ebs-csi-role \
  --set node.tolerateAllTaints=true

# IAM 策略 (EBS CSI Driver)
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSnapshot",
        "ec2:AttachVolume",
        "ec2:DetachVolume",
        "ec2:ModifyVolume",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeInstances",
        "ec2:DescribeSnapshots",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DescribeVolumesModifications"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags"
      ],
      "Resource": [
        "arn:aws:ec2:*:*:volume/*",
        "arn:aws:ec2:*:*:snapshot/*"
      ],
      "Condition": {
        "StringEquals": {
          "ec2:CreateAction": [
            "CreateVolume",
            "CreateSnapshot"
          ]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteTags"
      ],
      "Resource": [
        "arn:aws:ec2:*:*:volume/*",
        "arn:aws:ec2:*:*:snapshot/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/ebs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/ebs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteSnapshot"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/CSIVolumeSnapshotName": "*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:CreateGrant",
        "kms:ListGrants",
        "kms:RevokeGrant"
      ],
      "Resource": "*",
      "Condition": {
        "Bool": {
          "kms:GrantIsForAWSResource": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    }
  ]
}
```

### 5.3 阿里云 CSI 驱动

```yaml
# 阿里云云盘 StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alicloud-disk-essd
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd  # cloud_efficiency, cloud_ssd, cloud_essd
  performanceLevel: PL1  # PL0, PL1, PL2, PL3
  fstype: ext4
  encrypted: "true"
  kmsKeyId: "key-xxx"
  # 多可用区配置
  zoneId: cn-hangzhou-a,cn-hangzhou-b
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer

---
# 阿里云 NAS StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alicloud-nas
provisioner: nasplugin.csi.alibabacloud.com
parameters:
  volumeAs: subpath  # subpath 或 filesystem
  server: "xxx.cn-hangzhou.nas.aliyuncs.com"
  path: "/share"
  vers: "4.0"
  options: "noresvport,nolock"
  # 极速型 NAS
  # server: "xxx.cn-hangzhou.extreme.nas.aliyuncs.com"
  # protocolType: "NFS"
reclaimPolicy: Retain
mountOptions:
  - nolock
  - proto=tcp
  - rsize=1048576
  - wsize=1048576

---
# 阿里云 OSS StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alicloud-oss
provisioner: ossplugin.csi.alibabacloud.com
parameters:
  bucket: my-bucket
  url: oss-cn-hangzhou.aliyuncs.com
  akId: "xxxx"
  akSecret: "xxxx"
  otherOpts: "-o max_stat_cache_size=0 -o allow_other"
reclaimPolicy: Retain
```

### 5.4 Ceph CSI 驱动

```yaml
# Ceph RBD StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-rbd
provisioner: rbd.csi.ceph.com
parameters:
  clusterID: <cluster-id>
  pool: kubernetes
  imageFormat: "2"
  imageFeatures: layering
  csi.storage.k8s.io/provisioner-secret-name: csi-rbd-secret
  csi.storage.k8s.io/provisioner-secret-namespace: ceph-csi
  csi.storage.k8s.io/controller-expand-secret-name: csi-rbd-secret
  csi.storage.k8s.io/controller-expand-secret-namespace: ceph-csi
  csi.storage.k8s.io/node-stage-secret-name: csi-rbd-secret
  csi.storage.k8s.io/node-stage-secret-namespace: ceph-csi
  csi.storage.k8s.io/fstype: ext4
reclaimPolicy: Delete
allowVolumeExpansion: true
mountOptions:
  - discard

---
# Ceph Secret
apiVersion: v1
kind: Secret
metadata:
  name: csi-rbd-secret
  namespace: ceph-csi
stringData:
  userID: kubernetes
  userKey: AQBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx==

---
# CephFS StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-filesystem
provisioner: cephfs.csi.ceph.com
parameters:
  clusterID: <cluster-id>
  fsName: cephfs
  pool: cephfs_data
  csi.storage.k8s.io/provisioner-secret-name: csi-cephfs-secret
  csi.storage.k8s.io/provisioner-secret-namespace: ceph-csi
  csi.storage.k8s.io/controller-expand-secret-name: csi-cephfs-secret
  csi.storage.k8s.io/controller-expand-secret-namespace: ceph-csi
  csi.storage.k8s.io/node-stage-secret-name: csi-cephfs-secret
  csi.storage.k8s.io/node-stage-secret-namespace: ceph-csi
reclaimPolicy: Delete
allowVolumeExpansion: true
```

### 5.5 本地存储 CSI 驱动

```yaml
# OpenEBS Local PV Hostpath
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: openebs-hostpath
provisioner: openebs.io/local
parameters:
  basePath: "/var/openebs/local"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete

---
# TopoLVM (LVM based local storage)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: topolvm-provisioner
provisioner: topolvm.cybozu.com
parameters:
  topolvm.cybozu.com/device-class: ssd
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true

---
# Local Path Provisioner (Rancher)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

---

## 6. 存储卷操作

### 6.1 动态存储配置流程

```yaml
# 1. 创建 StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "5000"
  throughput: "250"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer

---
# 2. 创建 PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 100Gi

---
# 3. 使用 PVC 的 Pod
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-pvc
```

### 6.2 快照操作

```yaml
# VolumeSnapshotClass
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snapclass
driver: ebs.csi.aws.com
deletionPolicy: Delete
parameters:
  # AWS 特定参数
  tagSpecification_1: "key=environment,value=production"

---
# 创建快照
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: my-snapshot
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: my-pvc

---
# 从快照恢复
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 100Gi
  dataSource:
    name: my-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

### 6.3 卷克隆

```yaml
# 从现有 PVC 克隆
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cloned-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 100Gi  # 必须 >= 源 PVC 大小
  dataSource:
    name: my-pvc  # 源 PVC
    kind: PersistentVolumeClaim
```

### 6.4 卷扩展

```yaml
# 在线扩展 PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 200Gi  # 从 100Gi 扩展到 200Gi

# 检查扩展状态
# kubectl get pvc my-pvc -o yaml
# status:
#   conditions:
#   - type: FileSystemResizePending  # 等待文件系统扩展
#   - type: Resizing                  # 正在扩展
```

### 6.5 StatefulSet 存储配置

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 50Gi
```

---

## 7. 高级特性

### 7.1 存储拓扑感知

```yaml
# 启用拓扑感知的 StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: topology-aware
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
volumeBindingMode: WaitForFirstConsumer  # 关键配置
allowedTopologies:
- matchLabelExpressions:
  - key: topology.kubernetes.io/zone
    values:
    - us-east-1a
    - us-east-1b
    - us-east-1c

---
# CSINode 拓扑信息
apiVersion: storage.k8s.io/v1
kind: CSINode
metadata:
  name: worker-1
spec:
  drivers:
  - name: ebs.csi.aws.com
    nodeID: i-0123456789abcdef0
    topologyKeys:
    - topology.kubernetes.io/zone
    allocatable:
      count: 25  # 最大卷数
```

### 7.2 卷健康监控 (Volume Health)

```yaml
# 启用卷健康监控的 CSI 驱动配置
# VolumeHealth 需要 CSI 驱动支持 VOLUME_CONDITION 能力

# 查看卷健康状态
# kubectl get pv <pv-name> -o yaml
# status:
#   volumeCondition:
#     abnormal: false
#     message: "volume is healthy"

# 外部健康监控配置
apiVersion: apps/v1
kind: Deployment
metadata:
  name: csi-external-health-monitor
spec:
  template:
    spec:
      containers:
      - name: csi-external-health-monitor-controller
        image: registry.k8s.io/sig-storage/csi-external-health-monitor-controller:v0.10.0
        args:
        - --csi-address=/csi/csi.sock
        - --leader-election=true
        - --http-endpoint=:8080
        - --monitor-interval=1m
        volumeMounts:
        - name: socket-dir
          mountPath: /csi
```

### 7.3 Ephemeral Inline Volumes (临时内联卷)

```yaml
# CSI Ephemeral Inline Volume
apiVersion: v1
kind: Pod
metadata:
  name: my-csi-app
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "1000000"]
    volumeMounts:
    - name: secrets
      mountPath: /mnt/secrets
      readOnly: true
  volumes:
  - name: secrets
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "aws-secrets"

---
# SecretProviderClass (Secrets Store CSI Driver)
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: aws-secrets
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "my-secret"
        objectType: "secretsmanager"
        objectVersion: "AWSCURRENT"
```

### 7.4 Generic Ephemeral Volumes (通用临时卷)

```yaml
# Generic Ephemeral Volume
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: scratch
      mountPath: /scratch
  volumes:
  - name: scratch
    ephemeral:
      volumeClaimTemplate:
        metadata:
          labels:
            type: scratch-volume
        spec:
          accessModes: ["ReadWriteOnce"]
          storageClassName: fast-ssd
          resources:
            requests:
              storage: 10Gi
```

### 7.5 VolumeAttributesClass (卷属性类)

```yaml
# VolumeAttributesClass (K8s 1.29+)
apiVersion: storage.k8s.io/v1alpha1
kind: VolumeAttributesClass
metadata:
  name: high-iops
driverName: ebs.csi.aws.com
parameters:
  iops: "10000"
  throughput: "500"

---
# 使用 VolumeAttributesClass 的 PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast-ssd
  volumeAttributesClassName: high-iops  # 引用 VolumeAttributesClass
  resources:
    requests:
      storage: 100Gi

---
# 动态修改卷属性
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  volumeAttributesClassName: ultra-high-iops  # 修改为新的属性类
```

### 7.6 ReadWriteOncePod 访问模式

```yaml
# ReadWriteOncePod (K8s 1.22+)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rwop-pvc
spec:
  accessModes:
  - ReadWriteOncePod  # 单 Pod 独占
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 10Gi

# 优势:
# - 防止多个 Pod 同时挂载
# - 强制单写者语义
# - 适用于需要独占访问的应用 (如数据库)
```

---

## 8. CSI 配置与调优

### 8.1 CSI 驱动配置参数

| 参数 | 描述 | 推荐值 |
|------|------|--------|
| **--timeout** | gRPC 调用超时 | 60s |
| **--retry-interval-start** | 重试起始间隔 | 1s |
| **--retry-interval-max** | 重试最大间隔 | 5m |
| **--worker-threads** | 工作线程数 | 100 |
| **--kube-api-qps** | API 请求 QPS | 20 |
| **--kube-api-burst** | API 请求突发 | 100 |
| **--leader-election** | Leader 选举 | true |

### 8.2 存储性能调优

```yaml
# StorageClass 性能参数
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: high-performance
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "64000"       # 最高 IOPS
  throughput: "1000"  # MB/s
  encrypted: "true"
  fsType: xfs         # XFS 适合大文件
mountOptions:
  - noatime           # 禁用访问时间更新
  - nodiratime        # 禁用目录访问时间
  - discard           # 启用 TRIM

---
# NFS 性能调优
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-performance
provisioner: nfs.csi.k8s.io
parameters:
  server: nfs-server.example.com
  share: /exports/data
mountOptions:
  - nfsvers=4.1
  - rsize=1048576     # 读缓冲区 1MB
  - wsize=1048576     # 写缓冲区 1MB
  - hard              # 硬挂载
  - timeo=600         # 超时 60s
  - retrans=2         # 重试次数
  - noresvport        # 不保留端口
  - async             # 异步写入 (性能优先)
```

### 8.3 资源限制配置

```yaml
# CSI Controller 资源配置
apiVersion: apps/v1
kind: Deployment
metadata:
  name: csi-controller
spec:
  template:
    spec:
      containers:
      - name: csi-driver
        resources:
          limits:
            memory: 512Mi
            cpu: 500m
          requests:
            memory: 256Mi
            cpu: 100m
      - name: csi-provisioner
        resources:
          limits:
            memory: 256Mi
            cpu: 200m
          requests:
            memory: 128Mi
            cpu: 50m
      - name: csi-attacher
        resources:
          limits:
            memory: 256Mi
            cpu: 200m
          requests:
            memory: 128Mi
            cpu: 50m

# CSI Node 资源配置
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: csi-node
spec:
  template:
    spec:
      containers:
      - name: csi-driver
        resources:
          limits:
            memory: 256Mi
            cpu: 200m
          requests:
            memory: 128Mi
            cpu: 50m
```

---

## 9. 监控与故障排查

### 9.1 CSI 监控指标

| 指标 | 类型 | 描述 |
|------|------|------|
| **csi_operations_seconds** | Histogram | CSI 操作延迟 |
| **csi_sidecar_operations_seconds** | Histogram | Sidecar 操作延迟 |
| **persistent_volume_claim_resource_requests_storage_bytes** | Gauge | PVC 请求存储 |
| **volume_manager_total_volumes** | Gauge | 卷管理器总卷数 |
| **kubelet_volume_stats_available_bytes** | Gauge | 可用存储字节 |
| **kubelet_volume_stats_capacity_bytes** | Gauge | 总存储容量 |
| **kubelet_volume_stats_used_bytes** | Gauge | 已用存储字节 |
| **kubelet_volume_stats_inodes** | Gauge | 总 inode 数 |
| **kubelet_volume_stats_inodes_free** | Gauge | 可用 inode 数 |

```yaml
# Prometheus 告警规则
groups:
- name: csi-alerts
  rules:
  - alert: PersistentVolumeUsageHigh
    expr: |
      (kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) > 0.85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "PV 使用率超过 85%"
      description: "PV {{ $labels.persistentvolumeclaim }} 使用率为 {{ $value | humanizePercentage }}"

  - alert: PersistentVolumeInodesLow
    expr: |
      (kubelet_volume_stats_inodes_free / kubelet_volume_stats_inodes) < 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "PV inode 不足"
      description: "PV {{ $labels.persistentvolumeclaim }} 可用 inode 少于 10%"

  - alert: CSIOperationLatencyHigh
    expr: |
      histogram_quantile(0.99, sum(rate(csi_operations_seconds_bucket[5m])) by (le, operation)) > 30
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "CSI 操作延迟过高"
      description: "CSI {{ $labels.operation }} P99 延迟为 {{ $value }}s"

  - alert: VolumeAttachmentStuck
    expr: |
      kube_volumeattachment_status_attached == 0 and
      time() - kube_volumeattachment_created > 300
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "VolumeAttachment 卡住"
      description: "VolumeAttachment {{ $labels.volumeattachment }} 超过 5 分钟未完成"
```

### 9.2 故障排查命令

```bash
# 检查 PVC 状态
kubectl get pvc -A
kubectl describe pvc <pvc-name>

# 检查 PV 状态
kubectl get pv
kubectl describe pv <pv-name>

# 检查 VolumeAttachment
kubectl get volumeattachment
kubectl describe volumeattachment <name>

# 检查 CSINode
kubectl get csinode
kubectl describe csinode <node-name>

# 检查 CSI 驱动 Pod
kubectl get pods -n kube-system -l app=csi-controller
kubectl get pods -n kube-system -l app=csi-node

# 查看 CSI 驱动日志
kubectl logs -n kube-system -l app=csi-controller -c csi-driver
kubectl logs -n kube-system -l app=csi-controller -c csi-provisioner
kubectl logs -n kube-system -l app=csi-controller -c csi-attacher

# 查看 Node 端日志
kubectl logs -n kube-system -l app=csi-node -c csi-driver
kubectl logs -n kube-system -l app=csi-node -c node-driver-registrar

# 检查 kubelet 存储日志
journalctl -u kubelet | grep -i "volume\|csi\|mount"

# 检查节点上的挂载
kubectl debug node/<node-name> -it --image=busybox -- mount | grep csi

# 检查 CSI socket
kubectl debug node/<node-name> -it --image=busybox -- ls -la /var/lib/kubelet/plugins/
```

### 9.3 常见问题排查

| 问题 | 可能原因 | 排查方法 | 解决方案 |
|------|----------|----------|----------|
| PVC Pending | StorageClass 不存在 | `kubectl get sc` | 创建 StorageClass |
| PVC Pending | 资源不足 | 检查云平台配额 | 增加配额或清理资源 |
| PVC Pending | 拓扑约束不满足 | 检查节点标签和 allowedTopologies | 调整节点或配置 |
| Attach 失败 | 卷已被其他节点使用 | `kubectl get volumeattachment` | 等待或强制解绑 |
| Mount 失败 | 设备路径不存在 | 检查 CSI node 日志 | 重启 CSI node Pod |
| Mount 失败 | 文件系统损坏 | `fsck` 检查 | 修复或重建卷 |
| 扩展失败 | StorageClass 不支持 | 检查 allowVolumeExpansion | 启用扩展支持 |
| 快照失败 | VolumeSnapshotClass 不存在 | `kubectl get volumesnapshotclass` | 创建 VolumeSnapshotClass |

---

## 10. 生产实践案例

### 10.1 案例一: 高可用数据库存储配置

```yaml
# 场景: MySQL 主从集群存储配置

# 高性能 StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: mysql-storage
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "10000"
  encrypted: "true"
  fsType: xfs
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Retain  # 生产环境保留数据

---
# MySQL StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql
  replicas: 3
  podManagementPolicy: Parallel
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: mysql
            topologyKey: topology.kubernetes.io/zone
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
        resources:
          requests:
            cpu: "2"
            memory: "4Gi"
          limits:
            cpu: "4"
            memory: "8Gi"
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: mysql-storage
      resources:
        requests:
          storage: 100Gi

---
# 定期快照 CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mysql-backup
spec:
  schedule: "0 2 * * *"  # 每天凌晨 2 点
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: bitnami/kubectl
            command:
            - /bin/sh
            - -c
            - |
              for i in 0 1 2; do
                kubectl apply -f - <<EOF
              apiVersion: snapshot.storage.k8s.io/v1
              kind: VolumeSnapshot
              metadata:
                name: mysql-${i}-$(date +%Y%m%d)
              spec:
                volumeSnapshotClassName: csi-snapclass
                source:
                  persistentVolumeClaimName: data-mysql-${i}
              EOF
              done
          restartPolicy: OnFailure
```

### 10.2 案例二: 多租户存储隔离

```yaml
# 场景: 不同租户使用独立的存储配置

# 租户 A: 高性能存储
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tenant-a-storage
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "10000"
  tagSpecification_1: "tenant=a"
allowedTopologies:
- matchLabelExpressions:
  - key: topology.kubernetes.io/zone
    values:
    - us-east-1a
    - us-east-1b
volumeBindingMode: WaitForFirstConsumer

---
# 租户 B: 标准存储
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tenant-b-storage
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  tagSpecification_1: "tenant=b"
allowedTopologies:
- matchLabelExpressions:
  - key: topology.kubernetes.io/zone
    values:
    - us-east-1c
volumeBindingMode: WaitForFirstConsumer

---
# ResourceQuota 限制租户存储
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-a-storage-quota
  namespace: tenant-a
spec:
  hard:
    requests.storage: "1Ti"
    persistentvolumeclaims: "100"
    tenant-a-storage.storageclass.storage.k8s.io/requests.storage: "1Ti"
    tenant-a-storage.storageclass.storage.k8s.io/persistentvolumeclaims: "100"
```

### 10.3 案例三: 大数据存储优化

```yaml
# 场景: Spark/Flink 大数据处理存储配置

# 高吞吐量存储 (适合顺序读写)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: bigdata-throughput
provisioner: ebs.csi.aws.com
parameters:
  type: st1  # 吞吐量优化型 HDD
  encrypted: "true"
  fsType: xfs
volumeBindingMode: WaitForFirstConsumer
mountOptions:
  - noatime
  - nodiratime

---
# 低延迟存储 (适合随机读写)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: bigdata-iops
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "64000"
  encrypted: "true"
  fsType: xfs
volumeBindingMode: WaitForFirstConsumer

---
# 共享存储 (Spark Shuffle)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: spark-shuffle
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-xxxxx
  directoryPerms: "700"
  uid: "1000"
  gid: "1000"
mountOptions:
  - tls
  - iam

---
# Spark Executor Pod 配置
apiVersion: v1
kind: Pod
metadata:
  name: spark-executor
spec:
  containers:
  - name: executor
    image: spark:3.5
    volumeMounts:
    - name: data
      mountPath: /data
    - name: shuffle
      mountPath: /shuffle
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: spark-data-pvc
  - name: shuffle
    ephemeral:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteMany"]
          storageClassName: spark-shuffle
          resources:
            requests:
              storage: 100Gi
```

### 10.4 CSI 驱动选型建议

| 场景 | 推荐 CSI 驱动 | 理由 |
|------|---------------|------|
| **AWS EKS** | AWS EBS CSI + EFS CSI | 原生支持，性能最优 |
| **Azure AKS** | Azure Disk CSI + Azure File CSI | 原生支持 |
| **GKE** | GCE PD CSI | 原生支持 |
| **阿里云 ACK** | Alibaba Cloud CSI | 原生支持 |
| **私有云 (块存储)** | Ceph RBD CSI | 成熟稳定 |
| **私有云 (文件存储)** | CephFS CSI / NFS CSI | 共享存储 |
| **本地存储** | TopoLVM / OpenEBS | 高性能本地 |
| **对象存储挂载** | s3fs / goofys | 大数据场景 |
| **Secret 管理** | Secrets Store CSI | 安全敏感应用 |

---

## 附录

### A. CSI 规范版本对照

| CSI 版本 | Kubernetes 最低版本 | 主要特性 |
|----------|---------------------|----------|
| v1.0 | 1.13 | 基础功能 |
| v1.1 | 1.14 | Volume Expansion |
| v1.2 | 1.15 | Block Volumes |
| v1.3 | 1.17 | Volume Cloning |
| v1.4 | 1.18 | Snapshot GA |
| v1.5 | 1.20 | FSGroup Policy |
| v1.6 | 1.23 | Volume Health |
| v1.7 | 1.24 | ReadWriteOncePod |
| v1.8 | 1.27 | SELinux Mount |
| v1.9 | 1.29 | VolumeAttributesClass |

### B. 参考资源

| 资源 | 链接 |
|------|------|
| CSI 规范 | https://github.com/container-storage-interface/spec |
| Kubernetes CSI 文档 | https://kubernetes-csi.github.io/docs/ |
| CSI Sidecar 容器 | https://kubernetes-csi.github.io/docs/sidecar-containers.html |
| AWS EBS CSI | https://github.com/kubernetes-sigs/aws-ebs-csi-driver |
| Ceph CSI | https://github.com/ceph/ceph-csi |

---

*本文档持续更新，建议结合官方文档和实际环境进行验证。*
