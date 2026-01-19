# 容器运行时深度解析 (Container Runtime Interface Deep Dive)

## 目录

1. [容器运行时演进历史](#1-容器运行时演进历史)
2. [容器运行时架构](#2-容器运行时架构)
3. [CRI 接口规范](#3-cri-接口规范)
4. [containerd 深度解析](#4-containerd-深度解析)
5. [CRI-O 深度解析](#5-cri-o-深度解析)
6. [OCI 运行时详解](#6-oci-运行时详解)
7. [安全容器运行时](#7-安全容器运行时)
8. [镜像管理与分发](#8-镜像管理与分发)
9. [运行时配置与调优](#9-运行时配置与调优)
10. [监控与故障排查](#10-监控与故障排查)
11. [生产实践案例](#11-生产实践案例)

---

## 1. 容器运行时演进历史

### 1.1 Docker 到 Kubernetes 的演进

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Container Runtime Evolution Timeline                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  2013        2014        2015        2016        2017        2018        2019   │
│    │           │           │           │           │           │           │     │
│    ▼           ▼           ▼           ▼           ▼           ▼           ▼     │
│  Docker      Docker      OCI         CRI        containerd  CRI-O      Docker   │
│  诞生        1.0        成立        发布        1.0        1.0        支持     │
│                                                                        containerd│
│                                                                                  │
│  2020        2021        2022        2023        2024        2025               │
│    │           │           │           │           │           │                 │
│    ▼           ▼           ▼           ▼           ▼           ▼                 │
│  dockershim  K8s 1.20   K8s 1.24   containerd  containerd  containerd          │
│  废弃公告    警告日志    移除        2.0        2.1        主流                 │
│                         dockershim                                              │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 运行时演进里程碑

| 时间 | 事件 | 影响 |
|------|------|------|
| 2013 | Docker 开源发布 | 容器技术普及，改变软件交付方式 |
| 2014 | Kubernetes 发布 | Google 开源容器编排系统 |
| 2015 | OCI 成立 | 容器运行时和镜像标准化 |
| 2015 | runc 发布 | OCI 参考实现，低级运行时标准 |
| 2016 | CRI 发布 (K8s 1.5) | Kubernetes 容器运行时接口标准化 |
| 2016 | containerd 开源 | Docker 拆分出独立的容器运行时 |
| 2017 | CRI-O 1.0 | Red Hat 推出轻量级 CRI 实现 |
| 2017 | containerd 1.0 | CNCF 毕业项目 |
| 2018 | Docker 支持 containerd | Docker CE 18.09 默认使用 containerd |
| 2020 | dockershim 废弃公告 | Kubernetes 宣布移除内置 Docker 支持 |
| 2021 | K8s 1.20 警告日志 | kubelet 输出 dockershim 废弃警告 |
| 2022 | K8s 1.24 移除 dockershim | 必须使用 CRI 兼容运行时 |
| 2023 | containerd 2.0 | 重大架构更新，性能提升 |

### 1.3 Docker 架构演进

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         Docker Architecture Evolution                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  早期 Docker (< 1.11)                                                           │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                            docker daemon                                 │    │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐│    │
│  │  │   API       │ │   Image     │ │  Container  │ │      Network        ││    │
│  │  │   Server    │ │   Mgmt      │ │   Mgmt      │ │      Storage        ││    │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────────────┘│    │
│  │                           │                                              │    │
│  │                           ▼                                              │    │
│  │                    ┌─────────────┐                                       │    │
│  │                    │   libcontainer (Go)                                 │    │
│  │                    │   namespace, cgroup, ...                            │    │
│  │                    └─────────────┘                                       │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  现代 Docker (>= 1.11)                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │  docker CLI ──────► dockerd (Docker Daemon)                              │    │
│  │                         │                                                │    │
│  │                         │ gRPC                                           │    │
│  │                         ▼                                                │    │
│  │                    containerd                                            │    │
│  │                         │                                                │    │
│  │                         │ OCI Runtime Spec                               │    │
│  │                         ▼                                                │    │
│  │              containerd-shim ──────► runc                                │    │
│  │                                        │                                 │    │
│  │                                        ▼                                 │    │
│  │                                   Container                              │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 1.4 dockershim 废弃详解

| 方面 | 说明 |
|------|------|
| **废弃原因** | dockershim 是 Kubernetes 内部维护的 Docker 适配层，增加维护负担 |
| **影响范围** | 使用 Docker 作为运行时的 Kubernetes 集群 |
| **迁移方案** | 切换到 containerd 或 CRI-O |
| **Docker 镜像** | 仍然兼容，OCI 镜像格式通用 |
| **docker build** | 仍可使用，镜像构建与运行时无关 |

```yaml
# dockershim 废弃时间线
Kubernetes 1.20 (2020.12): 废弃警告日志
Kubernetes 1.24 (2022.05): 移除 dockershim
Kubernetes 1.27+: 仅支持 CRI 运行时

# 检查当前运行时
kubectl get nodes -o wide
# CONTAINER-RUNTIME 列显示: containerd://1.7.x 或 cri-o://1.28.x

# kubelet 配置运行时
# /var/lib/kubelet/kubeadm-flags.env
KUBELET_KUBEADM_ARGS="--container-runtime-endpoint=unix:///run/containerd/containerd.sock"
```

---

## 2. 容器运行时架构

### 2.1 运行时层次架构

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        Container Runtime Architecture                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                         Kubernetes (kubelet)                             │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                    │                                             │
│                                    │ CRI (gRPC)                                  │
│                                    ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                    High-Level Runtime (CRI Runtime)                      │    │
│  │  ┌─────────────────────────┐   ┌─────────────────────────┐              │    │
│  │  │       containerd        │   │         CRI-O           │              │    │
│  │  │  - Image Management     │   │  - Image Management     │              │    │
│  │  │  - Container Lifecycle  │   │  - Container Lifecycle  │              │    │
│  │  │  - Snapshot Management  │   │  - Storage Management   │              │    │
│  │  │  - Network (CNI)        │   │  - Network (CNI)        │              │    │
│  │  └─────────────────────────┘   └─────────────────────────┘              │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                    │                                             │
│                                    │ OCI Runtime Spec                            │
│                                    ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                       Low-Level Runtime (OCI Runtime)                    │    │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐ │    │
│  │  │   runc    │ │   crun    │ │   youki   │ │  gVisor   │ │   Kata    │ │    │
│  │  │  (Go)     │ │  (C)      │ │  (Rust)   │ │  (runsc)  │ │ Containers│ │    │
│  │  └───────────┘ └───────────┘ └───────────┘ └───────────┘ └───────────┘ │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                    │                                             │
│                                    │ Linux Kernel APIs                           │
│                                    ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                           Linux Kernel                                   │    │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │    │
│  │  │Namespace│ │ Cgroups │ │ Seccomp │ │AppArmor │ │ SELinux │           │    │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘           │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 运行时类型对比

| 特性 | containerd | CRI-O | Docker |
|------|------------|-------|--------|
| **定位** | 通用容器运行时 | Kubernetes 专用 | 开发者工具 |
| **CNCF 状态** | 毕业项目 | 毕业项目 | N/A |
| **镜像格式** | OCI/Docker | OCI/Docker | Docker/OCI |
| **CRI 支持** | 原生 (cri plugin) | 原生 | 需要 cri-dockerd |
| **资源占用** | 中等 | 低 | 高 |
| **功能范围** | 容器运行时 | Kubernetes 运行时 | 完整容器平台 |
| **生态系统** | 丰富 (Docker/K8s) | Kubernetes 专注 | 最丰富 |
| **适用场景** | 通用/生产 | Kubernetes 生产 | 开发/CI |

### 2.3 组件交互流程

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                     Pod Creation Flow (containerd)                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  1. API Server 创建 Pod                                                         │
│     │                                                                            │
│     ▼                                                                            │
│  2. Scheduler 调度 Pod 到 Node                                                  │
│     │                                                                            │
│     ▼                                                                            │
│  3. Kubelet Watch 到 Pod 事件                                                   │
│     │                                                                            │
│     ▼                                                                            │
│  4. Kubelet 调用 CRI: RunPodSandbox()                                           │
│     │                                                                            │
│     ▼                                                                            │
│  5. containerd 创建 Sandbox (pause container)                                   │
│     ├── 调用 CNI 配置网络                                                        │
│     └── 创建 namespace/cgroup                                                    │
│     │                                                                            │
│     ▼                                                                            │
│  6. Kubelet 调用 CRI: PullImage() (如需要)                                      │
│     │                                                                            │
│     ▼                                                                            │
│  7. containerd 拉取镜像                                                          │
│     ├── 解析镜像引用                                                             │
│     ├── 下载镜像层                                                               │
│     └── 解压到 snapshotter                                                       │
│     │                                                                            │
│     ▼                                                                            │
│  8. Kubelet 调用 CRI: CreateContainer()                                         │
│     │                                                                            │
│     ▼                                                                            │
│  9. containerd 准备容器                                                          │
│     ├── 准备 rootfs (overlay)                                                    │
│     ├── 生成 OCI runtime spec                                                    │
│     └── 创建 containerd-shim                                                     │
│     │                                                                            │
│     ▼                                                                            │
│  10. Kubelet 调用 CRI: StartContainer()                                         │
│      │                                                                           │
│      ▼                                                                           │
│  11. containerd-shim 调用 runc create + start                                   │
│      │                                                                           │
│      ▼                                                                           │
│  12. runc 创建容器进程                                                           │
│      ├── clone() with namespaces                                                 │
│      ├── 设置 cgroups                                                            │
│      ├── pivot_root 切换根文件系统                                               │
│      └── exec 用户进程                                                           │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. CRI 接口规范

### 3.1 CRI 服务定义

```protobuf
// CRI 主要服务接口
service RuntimeService {
    // Sandbox (Pod) 管理
    rpc RunPodSandbox(RunPodSandboxRequest) returns (RunPodSandboxResponse);
    rpc StopPodSandbox(StopPodSandboxRequest) returns (StopPodSandboxResponse);
    rpc RemovePodSandbox(RemovePodSandboxRequest) returns (RemovePodSandboxResponse);
    rpc PodSandboxStatus(PodSandboxStatusRequest) returns (PodSandboxStatusResponse);
    rpc ListPodSandbox(ListPodSandboxRequest) returns (ListPodSandboxResponse);
    
    // Container 管理
    rpc CreateContainer(CreateContainerRequest) returns (CreateContainerResponse);
    rpc StartContainer(StartContainerRequest) returns (StartContainerResponse);
    rpc StopContainer(StopContainerRequest) returns (StopContainerResponse);
    rpc RemoveContainer(RemoveContainerRequest) returns (RemoveContainerResponse);
    rpc ListContainers(ListContainersRequest) returns (ListContainersResponse);
    rpc ContainerStatus(ContainerStatusRequest) returns (ContainerStatusResponse);
    
    // 容器操作
    rpc ExecSync(ExecSyncRequest) returns (ExecSyncResponse);
    rpc Exec(ExecRequest) returns (ExecResponse);
    rpc Attach(AttachRequest) returns (AttachResponse);
    rpc PortForward(PortForwardRequest) returns (PortForwardResponse);
    
    // 运行时信息
    rpc Version(VersionRequest) returns (VersionResponse);
    rpc Status(StatusRequest) returns (StatusResponse);
}

service ImageService {
    rpc ListImages(ListImagesRequest) returns (ListImagesResponse);
    rpc ImageStatus(ImageStatusRequest) returns (ImageStatusResponse);
    rpc PullImage(PullImageRequest) returns (PullImageResponse);
    rpc RemoveImage(RemoveImageRequest) returns (RemoveImageResponse);
    rpc ImageFsInfo(ImageFsInfoRequest) returns (ImageFsInfoResponse);
}
```

### 3.2 CRI 接口详解

| 接口类别 | 方法 | 功能描述 |
|----------|------|----------|
| **Sandbox 管理** | RunPodSandbox | 创建 Pod 沙箱（pause 容器） |
| | StopPodSandbox | 停止 Pod 沙箱 |
| | RemovePodSandbox | 删除 Pod 沙箱 |
| | PodSandboxStatus | 获取沙箱状态 |
| | ListPodSandbox | 列出所有沙箱 |
| **容器管理** | CreateContainer | 在沙箱中创建容器 |
| | StartContainer | 启动容器 |
| | StopContainer | 停止容器 |
| | RemoveContainer | 删除容器 |
| | ContainerStatus | 获取容器状态 |
| | ListContainers | 列出所有容器 |
| **容器操作** | ExecSync | 同步执行命令 |
| | Exec | 异步执行命令（流式） |
| | Attach | 附加到容器 |
| | PortForward | 端口转发 |
| **镜像管理** | PullImage | 拉取镜像 |
| | ListImages | 列出镜像 |
| | ImageStatus | 获取镜像状态 |
| | RemoveImage | 删除镜像 |
| | ImageFsInfo | 镜像文件系统信息 |

### 3.3 PodSandbox 概念

```yaml
# PodSandbox 配置示例
PodSandboxConfig:
  metadata:
    name: nginx-pod
    namespace: default
    uid: "12345678-1234-1234-1234-123456789012"
  hostname: nginx-pod
  log_directory: /var/log/pods/default_nginx-pod_12345678
  dns_config:
    servers:
    - "10.96.0.10"
    searches:
    - "default.svc.cluster.local"
    - "svc.cluster.local"
    - "cluster.local"
  port_mappings:
  - container_port: 80
    host_port: 8080
    protocol: TCP
  linux:
    cgroup_parent: /kubepods/burstable/pod12345678
    security_context:
      namespace_options:
        network: POD  # 共享网络命名空间
        pid: CONTAINER  # 每个容器独立 PID 命名空间
        ipc: POD  # 共享 IPC 命名空间
      selinux_options:
        level: "s0:c123,c456"
```

### 3.4 CRI 版本兼容性

| Kubernetes 版本 | CRI 版本 | 主要变更 |
|-----------------|----------|----------|
| 1.20 - 1.22 | v1alpha2 | 基础版本 |
| 1.23 - 1.24 | v1alpha2 → v1 | 过渡期 |
| 1.25 - 1.26 | v1 | 稳定版本 |
| 1.27+ | v1 | RuntimeClass 增强 |
| 1.29+ | v1 | User Namespaces 支持 |

---

## 4. containerd 深度解析

### 4.1 containerd 架构

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          containerd Architecture                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                              Clients                                     │    │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐│    │
│  │  │   kubelet   │ │    ctr      │ │   nerdctl   │ │    Docker Engine    ││    │
│  │  │   (CRI)     │ │ (CLI tool)  │ │ (Docker-like)│ │    (dockerd)       ││    │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────────────┘│    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                    │                                             │
│                                    │ gRPC API                                    │
│                                    ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                           containerd daemon                              │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │                           Core Services                              ││    │
│  │  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────────────────┐││    │
│  │  │  │ Container │ │   Task    │ │  Content  │ │      Snapshot         │││    │
│  │  │  │  Service  │ │  Service  │ │  Service  │ │      Service          │││    │
│  │  │  └───────────┘ └───────────┘ └───────────┘ └───────────────────────┘││    │
│  │  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────────────────┐││    │
│  │  │  │  Image    │ │ Namespace │ │   Diff    │ │       Lease           │││    │
│  │  │  │  Service  │ │  Service  │ │  Service  │ │       Service         │││    │
│  │  │  └───────────┘ └───────────┘ └───────────┘ └───────────────────────┘││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  │                                                                          │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │                            Plugins                                   ││    │
│  │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────────────┐││    │
│  │  │  │   CRI   │ │  CNI    │ │Snapshotter│ │ Runtime │ │   Streaming   │││    │
│  │  │  │ Plugin  │ │ Plugin  │ │ (overlay) │ │ (runc)  │ │   (exec/attach)│││    │
│  │  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────────────┘││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                    │                                             │
│                                    │ OCI Runtime Spec                            │
│                                    ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                         containerd-shim-runc-v2                          │    │
│  │                                  │                                       │    │
│  │                                  ▼                                       │    │
│  │                               runc                                       │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 containerd 核心服务

| 服务 | 功能 | 描述 |
|------|------|------|
| **Container Service** | 容器元数据管理 | 存储容器配置、标签等元数据 |
| **Task Service** | 容器生命周期 | 创建/启动/停止/删除容器进程 |
| **Content Service** | 内容存储 | 管理镜像层 blob 的存储 |
| **Snapshot Service** | 快照管理 | 管理容器文件系统快照 |
| **Image Service** | 镜像管理 | 镜像拉取、存储、删除 |
| **Namespace Service** | 命名空间隔离 | 多租户资源隔离 |
| **Diff Service** | 差异计算 | 计算文件系统差异 |
| **Lease Service** | 资源生命周期 | 管理资源引用和垃圾回收 |

### 4.3 containerd 配置详解

```toml
# /etc/containerd/config.toml
version = 2

# 全局配置
root = "/var/lib/containerd"
state = "/run/containerd"
oom_score = -999

# gRPC 配置
[grpc]
  address = "/run/containerd/containerd.sock"
  tcp_address = ""
  tcp_tls_cert = ""
  tcp_tls_key = ""
  uid = 0
  gid = 0
  max_recv_message_size = 16777216
  max_send_message_size = 16777216

# 调试配置
[debug]
  address = "/run/containerd/debug.sock"
  uid = 0
  gid = 0
  level = "info"
  format = "json"

# 指标配置
[metrics]
  address = "127.0.0.1:1338"
  grpc_histogram = false

# 插件配置
[plugins]
  
  # CRI 插件配置
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.k8s.io/pause:3.9"
    max_container_log_line_size = 16384
    max_concurrent_downloads = 3
    disable_tcp_service = true
    stream_server_address = "127.0.0.1"
    stream_server_port = "0"
    enable_selinux = false
    enable_unprivileged_ports = true
    enable_unprivileged_icmp = true
    
    # CNI 配置
    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"
      conf_template = ""
      max_conf_num = 1
    
    # 容器运行时配置
    [plugins."io.containerd.grpc.v1.cri".containerd]
      default_runtime_name = "runc"
      snapshotter = "overlayfs"
      disable_snapshot_annotations = true
      
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        
        # runc 运行时
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          pod_annotations = []
          container_annotations = []
          privileged_without_host_devices = false
          
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            BinaryName = ""
            CriuPath = ""
            IoGid = 0
            IoUid = 0
            NoNewKeyring = false
            NoPivotRoot = false
            Root = ""
            ShimCgroup = ""
            SystemdCgroup = true  # 使用 systemd cgroup driver
        
        # gVisor 运行时
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
          runtime_type = "io.containerd.runsc.v1"
          
        # Kata Containers 运行时
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata]
          runtime_type = "io.containerd.kata.v2"
    
    # 镜像仓库配置
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = "/etc/containerd/certs.d"
      
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://registry-1.docker.io"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gcr.io"]
          endpoint = ["https://gcr.io"]
    
    # 镜像解密配置
    [plugins."io.containerd.grpc.v1.cri".image_decryption]
      key_model = "node"
  
  # Snapshotter 配置
  [plugins."io.containerd.snapshotter.v1.overlayfs"]
    root_path = ""
    upperdir_label = false
  
  # 运行时 V2 Shim 配置  
  [plugins."io.containerd.runtime.v2.task"]
    platforms = ["linux/amd64", "linux/arm64"]
    sched_core = false

# 超时配置
[timeouts]
  "io.containerd.timeout.bolt.open" = "0s"
  "io.containerd.timeout.shim.cleanup" = "5s"
  "io.containerd.timeout.shim.load" = "5s"
  "io.containerd.timeout.shim.shutdown" = "3s"
  "io.containerd.timeout.task.state" = "2s"
```

### 4.4 containerd Snapshotter

| Snapshotter | 描述 | 适用场景 |
|-------------|------|----------|
| **overlayfs** | 默认，使用 Linux overlay 文件系统 | 通用，性能好 |
| **native** | 使用硬链接和复制 | 不支持 overlay 的系统 |
| **btrfs** | 使用 btrfs 快照 | btrfs 文件系统 |
| **zfs** | 使用 zfs 快照 | zfs 文件系统 |
| **devmapper** | 使用 device mapper thin provisioning | 块设备，适合大规模 |
| **stargz** | 延迟拉取镜像层 | 大镜像快速启动 |
| **nydus** | RAFS 格式，按需加载 | 大镜像，P2P 分发 |

```bash
# 查看 snapshotter 信息
ctr plugins ls | grep snapshotter

# 使用特定 snapshotter
ctr images pull --snapshotter=overlayfs docker.io/library/nginx:latest
```

### 4.5 containerd-shim 详解

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          containerd-shim Architecture                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  containerd-shim 的作用:                                                         │
│  1. 作为容器进程的父进程，containerd 重启不影响容器                              │
│  2. 将容器 stdio 转发到日志文件                                                  │
│  3. 报告容器退出状态                                                             │
│  4. 实现 ttrpc 接口供 containerd 调用                                            │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                           containerd                                     │    │
│  │                               │                                          │    │
│  │                               │ ttrpc                                    │    │
│  │                               ▼                                          │    │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │    │
│  │  │                    containerd-shim-runc-v2                         │  │    │
│  │  │  ┌─────────────────────────────────────────────────────────────┐  │  │    │
│  │  │  │  Shim Process (PID 1 in shim namespace)                     │  │  │    │
│  │  │  │                                                              │  │  │    │
│  │  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │  │  │    │
│  │  │  │  │ Task Manager │  │ Event Queue  │  │  stdio Forwarder │  │  │  │    │
│  │  │  │  └──────────────┘  └──────────────┘  └──────────────────┘  │  │  │    │
│  │  │  │                                                              │  │  │    │
│  │  │  │                          │                                   │  │  │    │
│  │  │  │                          │ fork/exec                         │  │  │    │
│  │  │  │                          ▼                                   │  │  │    │
│  │  │  │  ┌──────────────────────────────────────────────────────┐  │  │  │    │
│  │  │  │  │                      runc                             │  │  │  │    │
│  │  │  │  │                        │                              │  │  │  │    │
│  │  │  │  │                        │ clone(CLONE_NEWNS|...)       │  │  │  │    │
│  │  │  │  │                        ▼                              │  │  │  │    │
│  │  │  │  │  ┌────────────────────────────────────────────────┐  │  │  │  │    │
│  │  │  │  │  │              Container Process                  │  │  │  │  │    │
│  │  │  │  │  │  (isolated namespaces, cgroups, rootfs)         │  │  │  │  │    │
│  │  │  │  │  └────────────────────────────────────────────────┘  │  │  │  │    │
│  │  │  │  └──────────────────────────────────────────────────────┘  │  │  │    │
│  │  │  └─────────────────────────────────────────────────────────────┘  │  │    │
│  │  └───────────────────────────────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 4.6 containerd 命令行工具

```bash
# ctr - containerd 原生 CLI
# 列出命名空间
ctr namespaces ls

# 在 k8s.io 命名空间操作 (Kubernetes 使用)
ctr -n k8s.io images ls
ctr -n k8s.io containers ls
ctr -n k8s.io tasks ls

# 拉取镜像
ctr images pull docker.io/library/nginx:latest

# 运行容器
ctr run -d --rm docker.io/library/nginx:latest nginx

# 执行命令
ctr tasks exec --exec-id exec1 nginx sh

# 查看容器日志 (需要配置)
ctr tasks logs nginx

# nerdctl - Docker 兼容的 CLI
# 安装: https://github.com/containerd/nerdctl
nerdctl run -d --name nginx -p 80:80 nginx:latest
nerdctl ps
nerdctl logs nginx
nerdctl exec -it nginx sh
nerdctl stop nginx
nerdctl rm nginx

# crictl - CRI 调试工具
crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps
crictl pods
crictl images
crictl logs <container-id>
crictl exec -it <container-id> sh
```

---

## 5. CRI-O 深度解析

### 5.1 CRI-O 架构

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              CRI-O Architecture                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                              Kubelet                                     │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                    │                                             │
│                                    │ CRI gRPC                                    │
│                                    ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                              CRI-O Daemon                                │    │
│  │                                                                          │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │                        CRI Implementation                            ││    │
│  │  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────────┐  ││    │
│  │  │  │   Runtime   │ │   Image     │ │   Storage   │ │   Streaming   │  ││    │
│  │  │  │   Handler   │ │   Handler   │ │   Handler   │ │   Handler     │  ││    │
│  │  │  └─────────────┘ └─────────────┘ └─────────────┘ └───────────────┘  ││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  │                                                                          │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │                         Core Components                              ││    │
│  │  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────────┐  ││    │
│  │  │  │  containers │ │  containers │ │   conmon    │ │   CNI         │  ││    │
│  │  │  │  /storage   │ │  /image     │ │  (monitor)  │ │   Plugin      │  ││    │
│  │  │  └─────────────┘ └─────────────┘ └─────────────┘ └───────────────┘  ││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                    │                                             │
│                                    │ OCI Runtime                                 │
│                                    ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐│    │
│  │  │    runc     │ │    crun     │ │   Kata      │ │       gVisor        ││    │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────────────┘│    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 CRI-O vs containerd 对比

| 特性 | CRI-O | containerd |
|------|-------|------------|
| **设计目标** | Kubernetes 专用 | 通用容器运行时 |
| **代码库大小** | 较小，专注 | 较大，功能丰富 |
| **维护者** | Red Hat 主导 | Docker/CNCF |
| **版本同步** | 与 Kubernetes 同步 | 独立发布周期 |
| **功能范围** | 仅 CRI 实现 | CRI + 更多功能 |
| **存储后端** | containers/storage | containerd snapshotter |
| **镜像库** | containers/image | containerd content |
| **Shim** | conmon | containerd-shim |
| **生态工具** | podman/buildah/skopeo | Docker/nerdctl/ctr |
| **典型用户** | OpenShift, Fedora CoreOS | Docker, Kubernetes |

### 5.3 CRI-O 配置详解

```toml
# /etc/crio/crio.conf
[crio]
root = "/var/lib/containers/storage"
runroot = "/var/run/containers/storage"
storage_driver = "overlay"
storage_option = ["overlay.mountopt=nodev"]

# 日志配置
log_level = "info"
log_dir = "/var/log/crio/pods"
log_size_max = 52428800  # 50MB
log_to_journald = false

# API 配置
[crio.api]
listen = "/var/run/crio/crio.sock"
host_ip = ""
stream_address = "127.0.0.1"
stream_port = "0"
stream_enable_tls = false

# 运行时配置
[crio.runtime]
default_runtime = "runc"
no_pivot = false
decryption_keys_path = "/etc/crio/keys/"
conmon = "/usr/bin/conmon"
conmon_cgroup = "pod"
conmon_env = [
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
]
default_env = []
selinux = false
seccomp_profile = ""
apparmor_profile = "crio-default"
cgroup_manager = "systemd"
default_capabilities = [
    "CHOWN",
    "DAC_OVERRIDE",
    "FSETID",
    "FOWNER",
    "SETGID",
    "SETUID",
    "SETPCAP",
    "NET_BIND_SERVICE",
    "KILL",
]
default_sysctls = []
hooks_dir = ["/usr/share/containers/oci/hooks.d"]
pids_limit = 1024
log_size_max = 52428800
container_exits_dir = "/var/run/crio/exits"
container_attach_socket_dir = "/var/run/crio"
namespaces_dir = "/var/run"
pinns_path = "/usr/bin/pinns"

# 运行时定义
[crio.runtime.runtimes.runc]
runtime_path = ""
runtime_type = "oci"
runtime_root = "/run/runc"
allowed_annotations = []
monitor_path = "/usr/bin/conmon"
monitor_cgroup = "pod"
monitor_exec_cgroup = ""
privileged_without_host_devices = false

[crio.runtime.runtimes.crun]
runtime_path = "/usr/bin/crun"
runtime_type = "oci"
runtime_root = "/run/crun"

[crio.runtime.runtimes.kata]
runtime_path = "/usr/bin/containerd-shim-kata-v2"
runtime_type = "vm"
runtime_root = "/run/vc"
privileged_without_host_devices = true

# 镜像配置
[crio.image]
default_transport = "docker://"
global_auth_file = ""
pause_image = "registry.k8s.io/pause:3.9"
pause_image_auth_file = ""
pause_command = "/pause"
signature_policy = ""
image_volumes = "mkdir"
big_files_temporary_dir = ""

# 网络配置
[crio.network]
network_dir = "/etc/cni/net.d/"
plugin_dirs = ["/opt/cni/bin/", "/usr/libexec/cni/"]
```

### 5.4 conmon 详解

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              conmon Architecture                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  conmon (Container Monitor) 的作用:                                              │
│  1. 作为容器的直接父进程                                                         │
│  2. 持有容器的 pty (伪终端)                                                      │
│  3. 处理容器日志                                                                 │
│  4. 记录容器退出码                                                               │
│  5. 支持 CRI-O 和 Podman                                                         │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                         CRI-O / Podman                                   │    │
│  │                              │                                           │    │
│  │                              │ fork                                      │    │
│  │                              ▼                                           │    │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │    │
│  │  │                          conmon                                    │  │    │
│  │  │  ┌─────────────────────────────────────────────────────────────┐  │  │    │
│  │  │  │  - 双 fork 成为 init 的子进程                                │  │  │    │
│  │  │  │  - 持有 pty master 端                                        │  │  │    │
│  │  │  │  - 将 stdio 写入日志文件                                     │  │  │    │
│  │  │  │  - 监听容器退出事件                                          │  │  │    │
│  │  │  │  - 通过 socket 与 CRI-O 通信                                 │  │  │    │
│  │  │  └─────────────────────────────────────────────────────────────┘  │  │    │
│  │  │                              │                                     │  │    │
│  │  │                              │ exec runc                           │  │    │
│  │  │                              ▼                                     │  │    │
│  │  │  ┌───────────────────────────────────────────────────────────┐    │  │    │
│  │  │  │                        runc                                │    │  │    │
│  │  │  │                          │                                 │    │  │    │
│  │  │  │                          ▼                                 │    │  │    │
│  │  │  │  ┌─────────────────────────────────────────────────────┐  │    │  │    │
│  │  │  │  │              Container Process                       │  │    │  │    │
│  │  │  │  │     (pty slave 端连接到 conmon 的 pty master)        │  │    │  │    │
│  │  │  │  └─────────────────────────────────────────────────────┘  │    │  │    │
│  │  │  └───────────────────────────────────────────────────────────┘    │  │    │
│  │  └───────────────────────────────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 5.5 CRI-O 命令行工具

```bash
# crictl - CRI 调试工具 (通用)
export CONTAINER_RUNTIME_ENDPOINT=unix:///var/run/crio/crio.sock
crictl ps
crictl pods
crictl images
crictl logs <container-id>
crictl exec -it <container-id> sh
crictl stats
crictl info

# crio-status - CRI-O 状态工具
crio-status info
crio-status config

# podman - 独立容器工具 (与 CRI-O 共享库)
podman run -d --name nginx nginx:latest
podman ps
podman logs nginx
podman exec -it nginx sh
podman stop nginx
podman rm nginx

# skopeo - 镜像工具
skopeo copy docker://docker.io/library/nginx:latest oci:nginx:latest
skopeo inspect docker://docker.io/library/nginx:latest
skopeo list-tags docker://docker.io/library/nginx

# buildah - 镜像构建
buildah from nginx:latest
buildah run nginx-working-container -- apt-get update
buildah commit nginx-working-container my-nginx:latest
```

---

## 6. OCI 运行时详解

### 6.1 OCI 规范概述

| 规范 | 描述 | 当前版本 |
|------|------|----------|
| **Runtime Spec** | 容器运行时规范 | v1.1.0 |
| **Image Spec** | 镜像格式规范 | v1.1.0 |
| **Distribution Spec** | 镜像分发规范 | v1.1.0 |

### 6.2 OCI Runtime Spec 配置

```json
// config.json - OCI Runtime Spec 示例
{
    "ociVersion": "1.1.0",
    "process": {
        "terminal": true,
        "user": {
            "uid": 0,
            "gid": 0
        },
        "args": ["/bin/sh"],
        "env": [
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "TERM=xterm"
        ],
        "cwd": "/",
        "capabilities": {
            "bounding": ["CAP_AUDIT_WRITE", "CAP_KILL", "CAP_NET_BIND_SERVICE"],
            "effective": ["CAP_AUDIT_WRITE", "CAP_KILL", "CAP_NET_BIND_SERVICE"],
            "permitted": ["CAP_AUDIT_WRITE", "CAP_KILL", "CAP_NET_BIND_SERVICE"],
            "ambient": ["CAP_AUDIT_WRITE", "CAP_KILL", "CAP_NET_BIND_SERVICE"]
        },
        "rlimits": [
            {
                "type": "RLIMIT_NOFILE",
                "hard": 1024,
                "soft": 1024
            }
        ],
        "noNewPrivileges": true
    },
    "root": {
        "path": "rootfs",
        "readonly": false
    },
    "hostname": "container",
    "mounts": [
        {
            "destination": "/proc",
            "type": "proc",
            "source": "proc"
        },
        {
            "destination": "/dev",
            "type": "tmpfs",
            "source": "tmpfs",
            "options": ["nosuid", "strictatime", "mode=755", "size=65536k"]
        },
        {
            "destination": "/dev/pts",
            "type": "devpts",
            "source": "devpts",
            "options": ["nosuid", "noexec", "newinstance", "ptmxmode=0666", "mode=0620"]
        },
        {
            "destination": "/dev/shm",
            "type": "tmpfs",
            "source": "shm",
            "options": ["nosuid", "noexec", "nodev", "mode=1777", "size=65536k"]
        },
        {
            "destination": "/dev/mqueue",
            "type": "mqueue",
            "source": "mqueue",
            "options": ["nosuid", "noexec", "nodev"]
        },
        {
            "destination": "/sys",
            "type": "sysfs",
            "source": "sysfs",
            "options": ["nosuid", "noexec", "nodev", "ro"]
        }
    ],
    "linux": {
        "resources": {
            "memory": {
                "limit": 536870912
            },
            "cpu": {
                "shares": 1024,
                "quota": 100000,
                "period": 100000
            },
            "pids": {
                "limit": 1024
            }
        },
        "namespaces": [
            {"type": "pid"},
            {"type": "network"},
            {"type": "ipc"},
            {"type": "uts"},
            {"type": "mount"},
            {"type": "cgroup"}
        ],
        "maskedPaths": [
            "/proc/acpi",
            "/proc/kcore",
            "/proc/keys",
            "/proc/latency_stats",
            "/proc/timer_list",
            "/proc/timer_stats",
            "/proc/sched_debug",
            "/sys/firmware"
        ],
        "readonlyPaths": [
            "/proc/asound",
            "/proc/bus",
            "/proc/fs",
            "/proc/irq",
            "/proc/sys",
            "/proc/sysrq-trigger"
        ],
        "seccomp": {
            "defaultAction": "SCMP_ACT_ERRNO",
            "architectures": ["SCMP_ARCH_X86_64"],
            "syscalls": [
                {
                    "names": ["read", "write", "exit", "exit_group"],
                    "action": "SCMP_ACT_ALLOW"
                }
            ]
        }
    }
}
```

### 6.3 OCI 运行时对比

| 运行时 | 语言 | 特点 | 适用场景 |
|--------|------|------|----------|
| **runc** | Go | OCI 参考实现，最广泛使用 | 生产默认 |
| **crun** | C | 更快、更轻量 | 性能敏感场景 |
| **youki** | Rust | 内存安全，现代实现 | 安全敏感场景 |
| **runsc (gVisor)** | Go | 内核隔离，安全沙箱 | 多租户隔离 |
| **kata-runtime** | Go | 轻量级 VM 隔离 | 强隔离需求 |
| **runk** | Rust | 实验性，Rust 实现 | 研究/实验 |

### 6.4 runc 详解

```bash
# runc 基本操作
# 创建 OCI bundle
mkdir -p mycontainer/rootfs
docker export $(docker create busybox) | tar -C mycontainer/rootfs -xvf -
cd mycontainer
runc spec  # 生成 config.json

# 创建并运行容器
runc create mycontainer
runc start mycontainer
runc state mycontainer
runc exec mycontainer /bin/sh
runc kill mycontainer SIGTERM
runc delete mycontainer

# runc 检查点/恢复 (CRIU)
runc checkpoint --image-path=/tmp/checkpoint mycontainer
runc restore --image-path=/tmp/checkpoint mycontainer-restored
```

### 6.5 crun 详解

```bash
# crun vs runc 性能对比
# crun 优势:
# - 启动速度更快 (约 2x)
# - 内存占用更少 (约 50%)
# - 支持 cgroup v2 更完善

# 安装 crun
dnf install crun  # Fedora/RHEL
apt install crun  # Debian/Ubuntu

# containerd 配置使用 crun
# /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.crun]
  runtime_type = "io.containerd.runc.v2"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.crun.options]
    BinaryName = "/usr/bin/crun"

# CRI-O 配置使用 crun
# /etc/crio/crio.conf.d/10-crun.conf
[crio.runtime.runtimes.crun]
runtime_path = "/usr/bin/crun"
runtime_type = "oci"
runtime_root = "/run/crun"

# crun 特有功能
crun --version
crun --systemd-cgroup run mycontainer
```

### 6.6 youki 详解

```bash
# youki - Rust 实现的 OCI 运行时
# 特点:
# - 内存安全 (Rust)
# - 无 GC 暂停
# - 现代化代码库

# 安装 youki
cargo install youki

# 或从 release 下载
wget https://github.com/containers/youki/releases/download/v0.3.0/youki_0.3.0_linux_amd64.tar.gz
tar -xzf youki_0.3.0_linux_amd64.tar.gz
mv youki /usr/local/bin/

# containerd 配置使用 youki
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.youki]
  runtime_type = "io.containerd.runc.v2"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.youki.options]
    BinaryName = "/usr/local/bin/youki"

# youki 支持的功能
youki --help
youki create mycontainer
youki start mycontainer
youki state mycontainer
youki delete mycontainer
```

---

## 7. 安全容器运行时

### 7.1 gVisor (runsc) 详解

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              gVisor Architecture                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  传统容器 (runc)                      gVisor (runsc)                            │
│  ┌─────────────────────┐              ┌─────────────────────┐                   │
│  │   Application       │              │   Application       │                   │
│  │        │            │              │        │            │                   │
│  │        │ syscall    │              │        │ syscall    │                   │
│  │        ▼            │              │        ▼            │                   │
│  │  ┌───────────┐      │              │  ┌───────────────┐  │                   │
│  │  │  libc     │      │              │  │    Sentry     │  │  用户态内核       │
│  │  └───────────┘      │              │  │  (用户态)     │  │                   │
│  │        │            │              │  │  - 系统调用   │  │                   │
│  │        │ syscall    │              │  │  - 进程管理   │  │                   │
│  │        ▼            │              │  │  - 内存管理   │  │                   │
│  └────────┼────────────┘              │  │  - 文件系统   │  │                   │
│           │                           │  │  - 网络栈     │  │                   │
│           ▼                           │  └───────┬───────┘  │                   │
│  ┌─────────────────────┐              │          │          │                   │
│  │    Linux Kernel     │              │          │ 受限     │                   │
│  │   (直接系统调用)    │              │          │ syscalls │                   │
│  └─────────────────────┘              │          ▼          │                   │
│                                       │  ┌───────────────┐  │                   │
│                                       │  │    Gofer      │  │  文件代理         │
│                                       │  │  (文件 I/O)   │  │                   │
│                                       │  └───────────────┘  │                   │
│                                       └──────────┼──────────┘                   │
│                                                  │                               │
│                                                  ▼                               │
│                                       ┌─────────────────────┐                   │
│                                       │    Linux Kernel     │                   │
│                                       │  (受限系统调用)     │                   │
│                                       └─────────────────────┘                   │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

```yaml
# gVisor 安装和配置
# 下载 runsc
wget https://storage.googleapis.com/gvisor/releases/release/latest/x86_64/runsc
chmod +x runsc
mv runsc /usr/local/bin/

# containerd 配置
# /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc.options]
    TypeUrl = "io.containerd.runsc.v1.options"
    ConfigPath = "/etc/containerd/runsc.toml"

# runsc 配置
# /etc/containerd/runsc.toml
[runsc_config]
  platform = "systrap"  # 或 "kvm" 如果可用
  network = "sandbox"
  debug = false
  strace = false

# Kubernetes RuntimeClass
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
scheduling:
  nodeSelector:
    sandbox.gvisor.dev/enabled: "true"

---
# 使用 gVisor 运行 Pod
apiVersion: v1
kind: Pod
metadata:
  name: nginx-gvisor
spec:
  runtimeClassName: gvisor
  containers:
  - name: nginx
    image: nginx:latest
```

### 7.2 Kata Containers 详解

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          Kata Containers Architecture                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                              Host System                                 │    │
│  │                                                                          │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │                    containerd / CRI-O                                ││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  │                                    │                                     │    │
│  │                                    │ OCI Runtime                         │    │
│  │                                    ▼                                     │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐│    │
│  │  │                    containerd-shim-kata-v2                           ││    │
│  │  │  ┌─────────────────────────────────────────────────────────────────┐││    │
│  │  │  │                       Kata Runtime                               │││    │
│  │  │  │  - 管理轻量级 VM                                                 │││    │
│  │  │  │  - 处理 OCI 容器请求                                             │││    │
│  │  │  │  - 通过 VSOCK 与 Agent 通信                                      │││    │
│  │  │  └─────────────────────────────────────────────────────────────────┘││    │
│  │  └─────────────────────────────────────────────────────────────────────┘│    │
│  │                                    │                                     │    │
│  │                                    │ VMM (QEMU/Cloud Hypervisor/Firecracker) │
│  │                                    ▼                                     │    │
│  │  ╔═════════════════════════════════════════════════════════════════════╗│    │
│  │  ║                        Lightweight VM                                ║│    │
│  │  ║  ┌─────────────────────────────────────────────────────────────────┐║│    │
│  │  ║  │                       Guest Kernel                               │║│    │
│  │  ║  │               (优化的 Linux 内核)                                │║│    │
│  │  ║  └─────────────────────────────────────────────────────────────────┘║│    │
│  │  ║  ┌─────────────────────────────────────────────────────────────────┐║│    │
│  │  ║  │                       Kata Agent                                 │║│    │
│  │  ║  │  - 接收来自 Runtime 的请求                                       │║│    │
│  │  ║  │  - 管理容器生命周期                                              │║│    │
│  │  ║  │  - 使用 libcontainer/runc 创建容器                               │║│    │
│  │  ║  └─────────────────────────────────────────────────────────────────┘║│    │
│  │  ║  ┌───────────────┐ ┌───────────────┐ ┌───────────────────────────┐  ║│    │
│  │  ║  │  Container 1  │ │  Container 2  │ │      Container N          │  ║│    │
│  │  ║  └───────────────┘ └───────────────┘ └───────────────────────────┘  ║│    │
│  │  ╚═════════════════════════════════════════════════════════════════════╝│    │
│  │                                                                          │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

```yaml
# Kata Containers 配置
# /etc/kata-containers/configuration.toml
[hypervisor.qemu]
path = "/usr/bin/qemu-system-x86_64"
kernel = "/usr/share/kata-containers/vmlinux.container"
image = "/usr/share/kata-containers/kata-containers.img"
machine_type = "q35"
enable_annotations = ["enable_iommu"]
default_vcpus = 1
default_memory = 2048
default_bridges = 1
default_maxvcpus = 0
memory_slots = 10
memory_offset = 0
enable_virtio_mem = true
enable_iothreads = false
disable_block_device_use = false
shared_fs = "virtio-fs"
virtio_fs_daemon = "/usr/libexec/virtiofsd"
virtio_fs_cache_size = 0
virtio_fs_cache = "auto"
block_device_driver = "virtio-blk"
enable_swap = false
msize_9p = 8192
disable_selinux = false
disable_guest_seccomp = true
guest_hook_path = ""
enable_debug = false

[hypervisor.clh]  # Cloud Hypervisor
path = "/usr/bin/cloud-hypervisor"
kernel = "/usr/share/kata-containers/vmlinux.container"
rootfs = "/usr/share/kata-containers/kata-containers.img"

[hypervisor.fc]  # Firecracker
path = "/usr/bin/firecracker"
kernel = "/usr/share/kata-containers/vmlinux.container"
rootfs = "/usr/share/kata-containers/kata-containers-initrd.img"

[agent.kata]
enable_tracing = false
kernel_modules = []
debug_console_enabled = false

[runtime]
enable_debug = false
internetworking_model = "tcfilter"
disable_guest_seccomp = false
sandbox_cgroup_only = false
enable_pprof = false
experimental = []
vfio_mode = "guest-kernel"

# containerd 配置 Kata
# /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata]
  runtime_type = "io.containerd.kata.v2"
  privileged_without_host_devices = true
  pod_annotations = ["io.katacontainers.*"]
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata.options]
    ConfigPath = "/etc/kata-containers/configuration.toml"

# Kubernetes RuntimeClass
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: kata
handler: kata
overhead:
  podFixed:
    memory: "160Mi"
    cpu: "250m"
scheduling:
  nodeSelector:
    katacontainers.io/kata-runtime: "true"

---
# 使用 Kata 运行 Pod
apiVersion: v1
kind: Pod
metadata:
  name: nginx-kata
spec:
  runtimeClassName: kata
  containers:
  - name: nginx
    image: nginx:latest
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
```

### 7.3 安全容器对比

| 特性 | runc (标准) | gVisor | Kata Containers |
|------|-------------|--------|-----------------|
| **隔离级别** | 命名空间隔离 | 用户态内核 | 轻量级 VM |
| **性能开销** | 最低 | 中等 (系统调用) | 较高 (VM 开销) |
| **内存开销** | 最低 | 中等 (~50MB) | 较高 (~100MB+) |
| **启动时间** | 最快 (<100ms) | 快 (~200ms) | 较慢 (~1s) |
| **兼容性** | 完全兼容 | 部分 syscall 不支持 | 完全兼容 |
| **安全性** | 共享内核 | 内核隔离 | 硬件隔离 |
| **适用场景** | 信任工作负载 | 多租户/不信任 | 强隔离需求 |
| **GPU 支持** | 完全支持 | 有限 | 通过直通支持 |

---

## 8. 镜像管理与分发

### 8.1 OCI 镜像格式

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            OCI Image Layout                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  oci-layout/                                                                     │
│  ├── oci-layout              # {"imageLayoutVersion": "1.0.0"}                  │
│  ├── index.json              # Image Index (多架构入口)                         │
│  └── blobs/                                                                      │
│      └── sha256/                                                                 │
│          ├── <manifest>      # Image Manifest                                   │
│          ├── <config>        # Image Config                                     │
│          └── <layer>...      # Image Layers (tar.gz)                            │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                         Image Index (多架构)                             │    │
│  │  {                                                                       │    │
│  │    "schemaVersion": 2,                                                   │    │
│  │    "mediaType": "application/vnd.oci.image.index.v1+json",               │    │
│  │    "manifests": [                                                        │    │
│  │      {                                                                   │    │
│  │        "mediaType": "application/vnd.oci.image.manifest.v1+json",        │    │
│  │        "digest": "sha256:...",                                           │    │
│  │        "size": 1234,                                                     │    │
│  │        "platform": {"architecture": "amd64", "os": "linux"}              │    │
│  │      },                                                                  │    │
│  │      {                                                                   │    │
│  │        "mediaType": "application/vnd.oci.image.manifest.v1+json",        │    │
│  │        "digest": "sha256:...",                                           │    │
│  │        "size": 1234,                                                     │    │
│  │        "platform": {"architecture": "arm64", "os": "linux"}              │    │
│  │      }                                                                   │    │
│  │    ]                                                                     │    │
│  │  }                                                                       │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                         Image Manifest                                   │    │
│  │  {                                                                       │    │
│  │    "schemaVersion": 2,                                                   │    │
│  │    "mediaType": "application/vnd.oci.image.manifest.v1+json",            │    │
│  │    "config": {                                                           │    │
│  │      "mediaType": "application/vnd.oci.image.config.v1+json",            │    │
│  │      "digest": "sha256:...",                                             │    │
│  │      "size": 1234                                                        │    │
│  │    },                                                                    │    │
│  │    "layers": [                                                           │    │
│  │      {                                                                   │    │
│  │        "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",       │    │
│  │        "digest": "sha256:...",                                           │    │
│  │        "size": 12345678                                                  │    │
│  │      }                                                                   │    │
│  │    ]                                                                     │    │
│  │  }                                                                       │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 8.2 镜像拉取流程

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Image Pull Workflow                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  1. 解析镜像引用                                                                 │
│     docker.io/library/nginx:latest                                              │
│     ├── Registry: docker.io (registry-1.docker.io)                              │
│     ├── Repository: library/nginx                                               │
│     └── Tag: latest                                                              │
│                │                                                                 │
│                ▼                                                                 │
│  2. 获取认证 Token                                                              │
│     GET https://auth.docker.io/token?service=registry.docker.io&scope=...       │
│     Response: {"token": "...", "expires_in": 300}                               │
│                │                                                                 │
│                ▼                                                                 │
│  3. 获取 Manifest                                                               │
│     GET https://registry-1.docker.io/v2/library/nginx/manifests/latest          │
│     Accept: application/vnd.oci.image.index.v1+json,                            │
│             application/vnd.oci.image.manifest.v1+json,                         │
│             application/vnd.docker.distribution.manifest.v2+json                │
│                │                                                                 │
│                ▼                                                                 │
│  4. 选择平台 (如果是 multi-arch)                                                │
│     根据本地平台选择对应的 manifest                                              │
│                │                                                                 │
│                ▼                                                                 │
│  5. 下载 Config                                                                 │
│     GET https://registry-1.docker.io/v2/library/nginx/blobs/sha256:...          │
│                │                                                                 │
│                ▼                                                                 │
│  6. 下载 Layers (并行)                                                          │
│     GET https://registry-1.docker.io/v2/library/nginx/blobs/sha256:...          │
│     ├── Layer 1: 基础层                                                          │
│     ├── Layer 2: 应用层                                                          │
│     └── Layer N: ...                                                             │
│                │                                                                 │
│                ▼                                                                 │
│  7. 验证和解压                                                                   │
│     ├── 验证 digest (SHA256)                                                     │
│     ├── 解压 tar.gz                                                              │
│     └── 创建 snapshotter 快照                                                    │
│                │                                                                 │
│                ▼                                                                 │
│  8. 更新镜像元数据                                                               │
│     存储到 containerd content store                                              │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 8.3 镜像加速与分发

| 方案 | 描述 | 适用场景 |
|------|------|----------|
| **Registry Mirror** | 镜像仓库镜像 | 网络限制环境 |
| **Harbor** | 企业级镜像仓库 | 私有云/企业 |
| **Dragonfly** | P2P 镜像分发 | 大规模集群 |
| **Nydus** | 按需加载镜像 | 大镜像场景 |
| **Stargz** | 延迟加载镜像层 | 快速启动 |

```yaml
# containerd 镜像仓库配置
# /etc/containerd/certs.d/docker.io/hosts.toml
server = "https://registry-1.docker.io"

[host."https://mirror.gcr.io"]
  capabilities = ["pull", "resolve"]

[host."https://docker.mirrors.ustc.edu.cn"]
  capabilities = ["pull", "resolve"]

# Harbor 私有仓库
# /etc/containerd/certs.d/harbor.example.com/hosts.toml
server = "https://harbor.example.com"

[host."https://harbor.example.com"]
  capabilities = ["pull", "resolve", "push"]
  ca = "/etc/containerd/certs.d/harbor.example.com/ca.crt"
  client = [["/etc/containerd/certs.d/harbor.example.com/client.crt", "/etc/containerd/certs.d/harbor.example.com/client.key"]]
```

### 8.4 镜像垃圾回收

```bash
# containerd 镜像垃圾回收
# 手动清理未使用的镜像
ctr -n k8s.io images ls
ctr -n k8s.io images rm <image-ref>

# crictl 清理
crictl rmi --prune

# kubelet 自动垃圾回收配置
# /var/lib/kubelet/config.yaml
imageGCHighThresholdPercent: 85  # 磁盘使用率超过 85% 触发 GC
imageGCLowThresholdPercent: 80   # GC 后目标磁盘使用率
imageMinimumGCAge: 2m            # 镜像最小存活时间

# CRI-O 垃圾回收
# /etc/crio/crio.conf
[crio.image]
image_volumes = "mkdir"
```

---

## 9. 运行时配置与调优

### 9.1 Cgroup 驱动配置

| Cgroup 驱动 | 描述 | 推荐场景 |
|-------------|------|----------|
| **systemd** | 使用 systemd 管理 cgroup | 生产推荐 (K8s 1.22+) |
| **cgroupfs** | 直接操作 cgroup 文件系统 | 旧版本/特殊场景 |

```yaml
# kubelet cgroup 配置
# /var/lib/kubelet/config.yaml
cgroupDriver: systemd
cgroupRoot: /
cgroupsPerQOS: true
enforceCPULimits: true
cpuManagerPolicy: static
cpuManagerReconcilePeriod: 10s
memoryManagerPolicy: Static
reservedMemory:
- numaNode: 0
  limits:
    memory: "1Gi"
topologyManagerPolicy: single-numa-node
topologyManagerScope: container

# containerd systemd cgroup
# /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true

# CRI-O systemd cgroup
# /etc/crio/crio.conf
[crio.runtime]
cgroup_manager = "systemd"
```

### 9.2 资源限制配置

```yaml
# Pod 资源配置示例
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
        ephemeral-storage: "1Gi"
      limits:
        memory: "128Mi"
        cpu: "500m"
        ephemeral-storage: "2Gi"
    # 资源对应的 cgroup 配置
    # /sys/fs/cgroup/memory/kubepods/pod<uid>/<container-id>/memory.limit_in_bytes = 134217728
    # /sys/fs/cgroup/cpu/kubepods/pod<uid>/<container-id>/cpu.cfs_quota_us = 50000
    # /sys/fs/cgroup/cpu/kubepods/pod<uid>/<container-id>/cpu.cfs_period_us = 100000

# Cgroup v2 路径
# /sys/fs/cgroup/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-pod<uid>.slice/
#   ├── memory.max = 134217728
#   ├── cpu.max = 50000 100000
#   └── pids.max = 1024
```

### 9.3 运行时性能调优

| 调优项 | containerd | CRI-O | 效果 |
|--------|------------|-------|------|
| **并行镜像下载** | max_concurrent_downloads = 10 | - | 加速镜像拉取 |
| **Snapshotter** | overlayfs (默认) | overlay | 最佳性能 |
| **Shim** | containerd-shim-runc-v2 | conmon | 资源隔离 |
| **OCI Runtime** | crun | crun | 启动速度 +50% |
| **日志大小限制** | max_container_log_line_size | log_size_max | 控制磁盘使用 |

```toml
# containerd 性能调优
# /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri"]
  max_concurrent_downloads = 10
  max_container_log_line_size = 16384
  disable_tcp_service = true

[plugins."io.containerd.grpc.v1.cri".containerd]
  snapshotter = "overlayfs"
  default_runtime_name = "runc"

# 使用 crun 提升性能
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.crun]
  runtime_type = "io.containerd.runc.v2"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.crun.options]
    BinaryName = "/usr/bin/crun"
    SystemdCgroup = true
```

### 9.4 安全加固配置

```yaml
# Seccomp 配置
# /etc/containerd/seccomp/default.json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64", "SCMP_ARCH_AARCH64"],
  "syscalls": [
    {
      "names": ["accept", "accept4", "access", "alarm", ...],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}

# AppArmor 配置
# /etc/apparmor.d/containers/docker-default
profile docker-default flags=(attach_disconnected,mediate_deleted) {
  # 允许网络访问
  network,
  # 允许信号
  signal (send,receive),
  # 拒绝挂载
  deny mount,
  # 拒绝 ptrace
  deny ptrace (read, readby),
  # 文件系统访问
  file,
  deny /proc/sys/kernel/[^shm]* wklx,
  deny /proc/sysrq-trigger rwklx,
  deny /proc/kcore rwklx,
}

# Pod 安全配置
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
```

---

## 10. 监控与故障排查

### 10.1 运行时监控指标

| 指标类别 | containerd 指标 | 描述 |
|----------|-----------------|------|
| **容器** | container_count | 容器数量 |
| | container_memory_usage_bytes | 容器内存使用 |
| | container_cpu_usage_seconds_total | 容器 CPU 使用 |
| **镜像** | image_count | 镜像数量 |
| | image_pull_duration_seconds | 镜像拉取耗时 |
| **运行时** | runtime_container_create_duration | 容器创建耗时 |
| | runtime_container_start_duration | 容器启动耗时 |
| **gRPC** | grpc_server_handled_total | gRPC 请求数 |
| | grpc_server_handling_seconds | gRPC 处理时间 |

```yaml
# Prometheus 采集 containerd 指标
# containerd 配置启用指标
# /etc/containerd/config.toml
[metrics]
  address = "127.0.0.1:1338"
  grpc_histogram = true

# Prometheus ServiceMonitor
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: containerd
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: containerd
  endpoints:
  - port: metrics
    interval: 15s
    path: /v1/metrics
```

### 10.2 日志配置

```yaml
# containerd 日志配置
# /etc/containerd/config.toml
[debug]
  level = "info"  # debug, info, warn, error
  format = "json"

# CRI-O 日志配置
# /etc/crio/crio.conf
[crio]
log_level = "info"
log_dir = "/var/log/crio/pods"
log_to_journald = true

# 查看运行时日志
journalctl -u containerd -f
journalctl -u crio -f

# 容器日志位置
# containerd: /var/log/pods/<namespace>_<pod-name>_<uid>/<container-name>/<n>.log
# CRI-O: /var/log/crio/pods/<pod-id>/<container-id>.log
```

### 10.3 故障排查命令

```bash
# 检查运行时状态
systemctl status containerd
systemctl status crio

# 检查 CRI 连接
crictl --runtime-endpoint unix:///run/containerd/containerd.sock info
crictl --runtime-endpoint unix:///var/run/crio/crio.sock info

# 列出容器和 Pod
crictl ps -a
crictl pods

# 查看容器日志
crictl logs <container-id>
crictl logs --tail=100 --follow <container-id>

# 执行命令
crictl exec -it <container-id> sh

# 查看容器详情
crictl inspect <container-id>
crictl inspectp <pod-id>

# 查看镜像
crictl images
crictl inspecti <image-id>

# 检查运行时配置
containerd config dump
crio config

# 调试模式运行 containerd
containerd --log-level debug

# 检查 shim 进程
ps aux | grep containerd-shim
ps aux | grep conmon

# 查看 cgroup
cat /sys/fs/cgroup/memory/kubepods/*/memory.usage_in_bytes
cat /sys/fs/cgroup/cpu/kubepods/*/cpu.stat

# 检查命名空间
lsns -t net -p <container-pid>
nsenter -t <container-pid> -n ip addr

# 检查 overlay 挂载
mount | grep overlay
cat /proc/<container-pid>/mountinfo
```

### 10.4 常见问题排查

| 问题 | 可能原因 | 排查方法 | 解决方案 |
|------|----------|----------|----------|
| 容器启动失败 | OCI runtime 错误 | `crictl logs`, `journalctl` | 检查 seccomp/apparmor |
| 镜像拉取失败 | 网络/认证问题 | `crictl pull`, 检查 registry 配置 | 配置 mirror/认证 |
| 容器 OOM | 内存限制过低 | `dmesg`, cgroup 日志 | 调整 limits |
| 运行时无响应 | 资源耗尽/死锁 | `containerd/crio` 日志 | 重启运行时 |
| Shim 进程残留 | 清理失败 | `ps aux | grep shim` | 手动清理 |
| 日志写满磁盘 | 日志未轮转 | `du -sh /var/log/pods` | 配置日志限制 |

---

## 11. 生产实践案例

### 11.1 案例一: 从 Docker 迁移到 containerd

```bash
# 迁移步骤

# 1. 安装 containerd
apt-get update
apt-get install -y containerd.io

# 2. 生成默认配置
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# 3. 配置 systemd cgroup
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# 4. 配置镜像加速
mkdir -p /etc/containerd/certs.d/docker.io
cat > /etc/containerd/certs.d/docker.io/hosts.toml << 'EOF'
server = "https://registry-1.docker.io"
[host."https://mirror.gcr.io"]
  capabilities = ["pull", "resolve"]
EOF

# 5. 重启 containerd
systemctl restart containerd
systemctl enable containerd

# 6. 更新 kubelet 配置
# /var/lib/kubelet/kubeadm-flags.env
KUBELET_KUBEADM_ARGS="--container-runtime-endpoint=unix:///run/containerd/containerd.sock"

# 7. 重启 kubelet
systemctl restart kubelet

# 8. 验证
kubectl get nodes -o wide
# CONTAINER-RUNTIME 列应显示 containerd://x.x.x
```

### 11.2 案例二: 多运行时配置 (安全容器)

```yaml
# 场景: 普通工作负载用 runc，敏感工作负载用 Kata

# 1. 安装 Kata Containers
# 参考官方文档安装 kata-containers

# 2. containerd 配置多运行时
# /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri".containerd]
  default_runtime_name = "runc"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata]
  runtime_type = "io.containerd.kata.v2"
  privileged_without_host_devices = true

# 3. 创建 RuntimeClass
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: kata
handler: kata
overhead:
  podFixed:
    memory: "160Mi"
    cpu: "250m"

---
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: runc
handler: runc

# 4. 部署普通工作负载 (默认 runc)
apiVersion: v1
kind: Pod
metadata:
  name: normal-workload
spec:
  containers:
  - name: nginx
    image: nginx

# 5. 部署敏感工作负载 (Kata)
apiVersion: v1
kind: Pod
metadata:
  name: sensitive-workload
spec:
  runtimeClassName: kata
  containers:
  - name: app
    image: myapp:latest
```

### 11.3 案例三: 大规模集群镜像分发优化

```yaml
# 场景: 1000+ 节点集群，大镜像快速分发

# 方案 1: Dragonfly P2P 分发
# 安装 Dragonfly
helm repo add dragonfly https://dragonflyoss.github.io/helm-charts/
helm install dragonfly dragonfly/dragonfly --namespace dragonfly-system

# containerd 配置 Dragonfly
# /etc/containerd/certs.d/docker.io/hosts.toml
server = "https://registry-1.docker.io"
[host."http://127.0.0.1:65001"]
  capabilities = ["pull", "resolve"]
  [host."http://127.0.0.1:65001".header]
    X-Dragonfly-Registry = ["https://registry-1.docker.io"]

# 方案 2: Nydus 按需加载
# 安装 nydus-snapshotter
# /etc/containerd/config.toml
[proxy_plugins]
  [proxy_plugins.nydus]
    type = "snapshot"
    address = "/run/containerd-nydus/containerd-nydus-grpc.sock"

[plugins."io.containerd.grpc.v1.cri".containerd]
  snapshotter = "nydus"
  disable_snapshot_annotations = false

# 方案 3: Harbor + Trivy 扫描 + P2P
# Harbor 配置
# values.yaml for Harbor Helm chart
persistence:
  persistentVolumeClaim:
    registry:
      size: 500Gi
trivy:
  enabled: true
  autoScan: true
```

### 11.4 案例四: 运行时安全加固

```yaml
# 场景: 金融/政企环境安全加固

# 1. 启用 Pod Security Standards
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted

# 2. 强制使用非 root 用户
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: production
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    runAsGroup: 65534
    fsGroup: 65534
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: myapp:latest
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}

# 3. 使用 gVisor 运行不信任代码
apiVersion: v1
kind: Pod
metadata:
  name: untrusted-code
spec:
  runtimeClassName: gvisor
  containers:
  - name: sandbox
    image: user-submitted-code:latest
    securityContext:
      runAsNonRoot: true
      readOnlyRootFilesystem: true
```

### 11.5 运行时选型建议

| 场景 | 推荐运行时 | 理由 |
|------|------------|------|
| **通用生产环境** | containerd + runc | 稳定、广泛支持 |
| **OpenShift/RHEL** | CRI-O + runc | 原生支持、版本同步 |
| **性能敏感** | containerd + crun | 启动更快、资源更少 |
| **多租户 SaaS** | containerd + gVisor | 内核隔离、安全 |
| **强隔离需求** | containerd + Kata | 硬件级隔离 |
| **边缘/IoT** | containerd + runc | 轻量、资源占用少 |
| **大镜像场景** | containerd + Nydus | 按需加载、快速启动 |

---

## 附录

### A. 术语表

| 术语 | 英文 | 解释 |
|------|------|------|
| CRI | Container Runtime Interface | Kubernetes 容器运行时接口 |
| OCI | Open Container Initiative | 开放容器计划标准 |
| Shim | - | 运行时与容器之间的中间进程 |
| Snapshotter | - | 容器文件系统快照管理器 |
| Sandbox | - | Pod 沙箱（pause 容器 + 命名空间） |
| conmon | Container Monitor | CRI-O 的容器监控进程 |

### B. 参考资源

| 资源 | 链接 |
|------|------|
| containerd 官方文档 | https://containerd.io/docs/ |
| CRI-O 官方文档 | https://cri-o.io/ |
| OCI 规范 | https://opencontainers.org/ |
| runc GitHub | https://github.com/opencontainers/runc |
| gVisor 官方文档 | https://gvisor.dev/docs/ |
| Kata Containers | https://katacontainers.io/docs/ |
| Kubernetes CRI | https://kubernetes.io/docs/concepts/architecture/cri/ |

---

*本文档持续更新，建议结合官方文档和实际环境进行验证。*
