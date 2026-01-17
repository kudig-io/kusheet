# 表格39：容器运行时对比表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/setup/production-environment/container-runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)

## 容器运行时对比

| 运行时 | 类型 | 优势 | 劣势 | K8S版本 | ACK支持 |
|-------|------|------|------|--------|---------|
| **containerd** | CRI原生 | 轻量，K8S默认 | 功能比Docker少 | v1.24+默认 | 默认 |
| **CRI-O** | CRI原生 | 轻量，OCI标准 | 生态较小 | v1.24+ | 支持 |
| **Docker** | dockershim | 功能丰富，生态成熟 | **已移除** | <v1.24 | 不支持 |
| **gVisor** | 沙箱 | 安全隔离 | 性能开销 | v1.25+ | 支持 |
| **Kata Containers** | 轻量VM | 强隔离 | 资源开销 | v1.25+ | 支持 |
| **Firecracker** | microVM | 极轻量VM | AWS生态 | v1.25+ | - |

## containerd详解

| 特性 | 说明 | 配置方式 |
|-----|------|---------|
| **CRI插件** | K8S原生支持 | /etc/containerd/config.toml |
| **镜像管理** | 拉取/存储/分发 | crictl命令 |
| **容器生命周期** | 创建/启动/停止 | 自动管理 |
| **CNI集成** | 网络插件 | /etc/cni/net.d/ |
| **快照** | 文件系统快照 | overlayfs/native |

```toml
# /etc/containerd/config.toml 示例
version = 2

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.k8s.io/pause:3.9"
    [plugins."io.containerd.grpc.v1.cri".containerd]
      default_runtime_name = "runc"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://mirror.ccs.tencentyun.com"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.cn-hangzhou.aliyuncs.com"]
          endpoint = ["https://registry.cn-hangzhou.aliyuncs.com"]
```

## CRI-O详解

| 特性 | 说明 | 配置文件 |
|-----|------|---------|
| **OCI兼容** | 完全OCI标准 | /etc/crio/crio.conf |
| **版本对齐** | 与K8S版本同步 | 版本号一致 |
| **安全** | 最小攻击面 | 配置 |

```toml
# /etc/crio/crio.conf 示例
[crio]
  [crio.runtime]
    default_runtime = "runc"
    [crio.runtime.runtimes.runc]
      runtime_path = "/usr/bin/runc"
      runtime_type = "oci"
  [crio.image]
    pause_image = "registry.k8s.io/pause:3.9"
  [crio.network]
    network_dir = "/etc/cni/net.d/"
    plugin_dirs = ["/opt/cni/bin/"]
```

## 性能对比

| 指标 | containerd | CRI-O | Docker(历史) |
|-----|-----------|-------|-------------|
| **启动延迟** | ~300ms | ~350ms | ~500ms |
| **内存开销** | ~50MB | ~40MB | ~100MB |
| **CPU开销** | 低 | 低 | 中 |
| **镜像拉取** | 快 | 快 | 中 |
| **并发容器** | 高 | 高 | 中 |

## 安全运行时

| 运行时 | 隔离级别 | 原理 | 适用场景 | 性能开销 |
|-------|---------|------|---------|---------|
| **runc** | 命名空间 | Linux NS | 默认 | 无 |
| **gVisor(runsc)** | 用户空间内核 | 系统调用拦截 | 不可信代码 | 20-50% |
| **Kata** | 轻量VM | QEMU/Firecracker | 多租户 | 10-30% |

```yaml
# RuntimeClass配置
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
overhead:
  podFixed:
    memory: "120Mi"
    cpu: "250m"
scheduling:
  nodeSelector:
    runtime: gvisor
---
# 使用RuntimeClass的Pod
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  runtimeClassName: gvisor  # 使用gVisor运行时
  containers:
  - name: app
    image: nginx
```

## 从Docker迁移到containerd

| 步骤 | 操作 | 命令 |
|-----|------|------|
| 1 | 安装containerd | `apt install containerd` |
| 2 | 配置containerd | 编辑config.toml |
| 3 | 配置kubelet | `--container-runtime-endpoint=unix:///run/containerd/containerd.sock` |
| 4 | 重启kubelet | `systemctl restart kubelet` |
| 5 | 验证 | `crictl info` |

```bash
# Docker到containerd迁移检查
# 1. 停止kubelet
systemctl stop kubelet

# 2. 停止docker
systemctl stop docker

# 3. 配置containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
# 编辑config.toml设置SystemdCgroup = true

# 4. 启动containerd
systemctl enable --now containerd

# 5. 修改kubelet配置
# /var/lib/kubelet/kubeadm-flags.env
# 添加: --container-runtime-endpoint=unix:///run/containerd/containerd.sock

# 6. 启动kubelet
systemctl start kubelet

# 7. 验证
crictl info
kubectl get nodes
```

## crictl命令参考

| 命令 | 用途 | 示例 |
|-----|------|------|
| **crictl ps** | 列出容器 | `crictl ps -a` |
| **crictl pods** | 列出Pod | `crictl pods` |
| **crictl images** | 列出镜像 | `crictl images` |
| **crictl pull** | 拉取镜像 | `crictl pull nginx:latest` |
| **crictl logs** | 查看日志 | `crictl logs <container-id>` |
| **crictl exec** | 执行命令 | `crictl exec -it <id> sh` |
| **crictl inspect** | 检查容器 | `crictl inspect <id>` |
| **crictl rmi** | 删除镜像 | `crictl rmi <image>` |
| **crictl rm** | 删除容器 | `crictl rm <id>` |
| **crictl stats** | 资源统计 | `crictl stats` |

```bash
# crictl配置
cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
```

## 镜像加速配置

```toml
# containerd镜像加速
[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
      endpoint = ["https://registry.cn-hangzhou.aliyuncs.com"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gcr.io"]
      endpoint = ["https://gcr.mirrors.ustc.edu.cn"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
      endpoint = ["https://registry.cn-hangzhou.aliyuncs.com/google_containers"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs]
    [plugins."io.containerd.grpc.v1.cri".registry.configs."registry.cn-hangzhou.aliyuncs.com".auth]
      username = "user"
      password = "password"
```

## 运行时故障排查

| 问题 | 症状 | 诊断命令 | 解决方案 |
|-----|------|---------|---------|
| **容器无法启动** | ContainerCreating | `crictl logs` | 检查运行时日志 |
| **镜像拉取失败** | ImagePullBackOff | `crictl pull <image>` | 检查仓库配置 |
| **运行时不响应** | 节点NotReady | `systemctl status containerd` | 重启运行时 |
| **存储满** | 创建失败 | `df -h` | 清理未用镜像/容器 |

```bash
# 清理未使用镜像
crictl rmi --prune

# 清理停止的容器
crictl rm $(crictl ps -a -q --state exited)

# 检查运行时状态
systemctl status containerd
journalctl -u containerd -f
```

## ACK容器运行时

| 运行时 | ACK配置 | 适用场景 |
|-------|--------|---------|
| **containerd** | 默认 | 标准工作负载 |
| **安全沙箱** | 节点池选择 | 安全敏感 |

---

**运行时原则**: v1.24+使用containerd，安全场景用沙箱运行时
