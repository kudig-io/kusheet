# 容器运行时故障排查指南

> **适用版本**: containerd v1.6-v1.7, Docker v24+, CRI-O v1.25+ | **最后更新**: 2026-01 | **难度**: 高级

---

## 目录

1. [问题现象与影响分析](#1-问题现象与影响分析)
2. [排查方法与步骤](#2-排查方法与步骤)
3. [解决方案与风险控制](#3-解决方案与风险控制)

---

## 1. 问题现象与影响分析

### 1.1 常见问题现象

#### 1.1.1 容器运行时服务不可用

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| containerd 未运行 | `containerd.service: Failed` | systemd | `systemctl status containerd` |
| Docker 未运行 | `docker.service: Failed` | systemd | `systemctl status docker` |
| CRI socket 不可用 | `unable to connect to runtime` | kubelet | kubelet 日志 |
| 运行时响应超时 | `context deadline exceeded` | kubelet | kubelet 日志 |

#### 1.1.2 容器生命周期问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 容器创建失败 | `failed to create containerd task` | 运行时日志 | 运行时日志 |
| 容器启动失败 | `OCI runtime create failed` | 运行时日志 | 运行时日志 |
| 容器无法停止 | `failed to stop container` | kubectl | kubectl 日志 |
| 容器僵死 | 容器状态不更新 | crictl | `crictl ps` |
| cgroup 错误 | `cgroup: cgroup mountpoint does not exist` | 运行时日志 | 运行时日志 |

#### 1.1.3 镜像相关问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 镜像拉取失败 | `failed to pull image` | 运行时日志 | 运行时日志 |
| 镜像解压失败 | `failed to extract` | 运行时日志 | 运行时日志 |
| 镜像空间不足 | `no space left on device` | 运行时日志 | 运行时日志 |
| 镜像认证失败 | `unauthorized: authentication required` | 运行时日志 | 运行时日志 |
| 镜像损坏 | `invalid checksum` | 运行时日志 | 运行时日志 |

#### 1.1.4 存储驱动问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| overlay 错误 | `overlay: invalid argument` | 运行时日志 | 运行时日志 |
| 存储驱动不支持 | `storage driver not supported` | 运行时日志 | 运行时日志 |
| 文件系统错误 | `input/output error` | 运行时日志 | 运行时日志 |
| 快照创建失败 | `failed to create snapshot` | 运行时日志 | 运行时日志 |

### 1.2 报错查看方式汇总

```bash
# containerd 相关
# 查看 containerd 服务状态
systemctl status containerd

# 查看 containerd 日志
journalctl -u containerd -f --no-pager -l

# 使用 crictl 检查运行时
crictl info
crictl version

# 查看容器列表
crictl ps -a

# 查看镜像列表
crictl images

# Docker 相关（如果使用 Docker）
# 查看 Docker 服务状态
systemctl status docker

# 查看 Docker 日志
journalctl -u docker -f --no-pager -l

# Docker 系统信息
docker info
docker version

# 查看 kubelet 中的运行时错误
journalctl -u kubelet | grep -i "runtime"

# 检查 CRI socket
ls -la /run/containerd/containerd.sock
ls -la /var/run/cri-dockerd.sock  # Docker + cri-dockerd
```

### 1.3 影响面分析

#### 1.3.1 直接影响

| 影响范围 | 影响程度 | 影响描述 |
|----------|----------|----------|
| **容器创建** | 完全失效 | 新容器无法创建 |
| **容器启动** | 完全失效 | 已创建的容器无法启动 |
| **容器停止** | 可能失效 | 容器可能无法正常停止 |
| **镜像管理** | 完全失效 | 镜像拉取、删除等操作失败 |
| **kubelet** | 异常 | kubelet 无法管理容器 |

#### 1.3.2 间接影响

| 影响范围 | 影响程度 | 影响描述 |
|----------|----------|----------|
| **节点状态** | NotReady | 节点被标记为不健康 |
| **Pod 调度** | 受影响 | 新 Pod 无法调度到该节点 |
| **现有容器** | 可能运行 | 已运行的容器可能继续运行 |
| **监控** | 部分失效 | 容器指标采集可能失败 |
| **日志采集** | 部分失效 | 容器日志可能无法采集 |

#### 1.3.3 故障传播链

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      容器运行时故障影响传播链                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   容器运行时故障                                                             │
│       │                                                                      │
│       ├──► kubelet 无法与运行时通信                                          │
│       │         │                                                            │
│       │         ├──► 节点变为 NotReady                                       │
│       │         │                                                            │
│       │         ├──► 新 Pod 无法创建                                         │
│       │         │                                                            │
│       │         └──► Pod 状态无法更新                                        │
│       │                                                                      │
│       ├──► 已有容器可能继续运行（取决于故障类型）                            │
│       │                                                                      │
│       ├──► 镜像操作全部失败                                                  │
│       │                                                                      │
│       └──► 容器指标/日志采集失败                                             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 排查方法与步骤

### 2.1 排查原理

容器运行时是 kubelet 与容器之间的桥梁，负责实际的容器生命周期管理。排查需要从以下层面：

1. **服务层面**：运行时进程是否正常
2. **接口层面**：CRI socket 是否可用
3. **存储层面**：存储驱动和空间
4. **配置层面**：运行时配置是否正确
5. **系统层面**：内核、cgroup、namespace 支持

### 2.2 排查逻辑决策树

```
开始排查
    │
    ├─► 检查运行时服务
    │       │
    │       ├─► 服务未运行 ──► 检查启动失败原因
    │       │
    │       └─► 服务运行中 ──► 继续下一步
    │
    ├─► 检查 CRI socket
    │       │
    │       ├─► socket 不存在 ──► 检查运行时配置
    │       │
    │       └─► socket 存在 ──► 继续下一步
    │
    ├─► 检查运行时功能
    │       │
    │       ├─► crictl 命令失败 ──► 分析具体错误
    │       │
    │       └─► crictl 正常 ──► 继续下一步
    │
    ├─► 检查存储状态
    │       │
    │       ├─► 空间不足 ──► 清理镜像/容器
    │       │
    │       └─► 空间充足 ──► 继续下一步
    │
    └─► 检查具体容器问题
            │
            └─► 根据日志分析具体原因
```

### 2.3 排查步骤和具体命令

#### 2.3.1 第一步：检查运行时服务状态

```bash
# containerd
systemctl status containerd
systemctl is-active containerd

# Docker（如果使用）
systemctl status docker
systemctl status cri-docker  # Docker + cri-dockerd

# 检查进程
ps aux | grep -E "containerd|dockerd" | grep -v grep

# 检查 socket 文件
ls -la /run/containerd/containerd.sock
ls -la /var/run/dockershim.sock  # 旧版本
ls -la /var/run/cri-dockerd.sock  # Docker + cri-dockerd
```

#### 2.3.2 第二步：检查运行时信息

```bash
# containerd 信息
crictl info
crictl version

# 或者直接使用 ctr（containerd 原生工具）
ctr version
ctr plugins ls

# Docker 信息
docker info
docker version

# 检查运行时端点
crictl --runtime-endpoint unix:///run/containerd/containerd.sock info
```

#### 2.3.3 第三步：检查容器状态

```bash
# 列出所有容器
crictl ps -a

# 查看容器详情
crictl inspect <container-id>

# 查看容器日志
crictl logs <container-id>

# 查看正在运行的任务
ctr -n k8s.io tasks ls

# 查看容器指标
crictl stats
```

#### 2.3.4 第四步：检查镜像状态

```bash
# 列出所有镜像
crictl images

# 检查镜像存储使用
crictl imagefsinfo

# 查看镜像详情
crictl inspecti <image-id>

# 拉取测试镜像
crictl pull busybox

# containerd 原生命令
ctr -n k8s.io images ls
ctr -n k8s.io images check
```

#### 2.3.5 第五步：检查存储驱动

```bash
# containerd 存储配置
cat /etc/containerd/config.toml | grep -A10 "\[plugins.*snapshotter\]"

# 检查存储目录
ls -la /var/lib/containerd/
du -sh /var/lib/containerd/

# Docker 存储配置
docker info | grep "Storage Driver"
ls -la /var/lib/docker/

# 检查文件系统
df -h /var/lib/containerd/
df -h /var/lib/docker/

# 检查 overlay 支持
lsmod | grep overlay
cat /proc/filesystems | grep overlay
```

#### 2.3.6 第六步：检查 cgroup 配置

```bash
# 检查 cgroup 版本
mount | grep cgroup
stat -fc %T /sys/fs/cgroup/

# cgroup v1
ls /sys/fs/cgroup/

# cgroup v2
cat /sys/fs/cgroup/cgroup.controllers

# 检查 containerd cgroup 配置
cat /etc/containerd/config.toml | grep -i cgroup

# 检查 kubelet cgroup 配置
cat /var/lib/kubelet/config.yaml | grep cgroupDriver
```

#### 2.3.7 第七步：检查日志

```bash
# containerd 日志
journalctl -u containerd -f --no-pager
journalctl -u containerd -p err --since "1 hour ago"

# Docker 日志
journalctl -u docker -f --no-pager

# 查找特定错误
journalctl -u containerd | grep -iE "(error|failed|unable)" | tail -50

# 查看 kubelet 中的运行时相关日志
journalctl -u kubelet | grep -i "runtime" | tail -50
```

### 2.4 排查注意事项

#### 2.4.1 安全注意事项

| 注意项 | 说明 | 建议 |
|--------|------|------|
| **运行时权限** | 运行时有 root 权限 | 操作需谨慎 |
| **容器数据** | 容器可能包含敏感数据 | 注意数据保护 |
| **镜像安全** | 不要随意拉取未知镜像 | 使用可信镜像 |

#### 2.4.2 操作注意事项

| 注意项 | 说明 | 建议 |
|--------|------|------|
| **重启影响** | 重启运行时会影响所有容器 | 在维护窗口操作 |
| **清理镜像** | 清理正在使用的镜像会失败 | 先停止容器 |
| **配置变更** | 配置变更需要重启服务 | 备份原配置 |
| **cgroup 驱动** | kubelet 和运行时必须一致 | 验证配置一致性 |

---

## 3. 解决方案与风险控制

### 3.1 containerd 服务无法启动

#### 3.1.1 解决步骤

```bash
# 步骤 1：检查启动失败原因
systemctl status containerd
journalctl -u containerd -b --no-pager | tail -100

# 步骤 2：检查配置文件
containerd config check
# 或者
cat /etc/containerd/config.toml

# 步骤 3：生成默认配置（如果配置损坏）
mv /etc/containerd/config.toml /etc/containerd/config.toml.bak
containerd config default > /etc/containerd/config.toml

# 步骤 4：确保 SystemdCgroup 配置正确（使用 systemd cgroup 驱动）
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# 步骤 5：检查必要的目录
mkdir -p /var/lib/containerd
mkdir -p /run/containerd

# 步骤 6：启动服务
systemctl daemon-reload
systemctl start containerd

# 步骤 7：验证启动
systemctl status containerd
crictl info
```

#### 3.1.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **高** | 重启期间所有容器管理中断 | 在维护窗口操作 |
| **中** | 配置重置可能丢失自定义配置 | 备份原配置 |
| **低** | 检查配置无风险 | - |

#### 3.1.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. containerd 重启会影响所有 Kubernetes Pod
2. 已运行的容器在重启后需要重新连接
3. 配置文件语法错误会导致启动失败
4. 确保 cgroup 驱动与 kubelet 一致
5. 重启后验证所有 Pod 状态
```

### 3.2 容器创建/启动失败

#### 3.2.1 解决步骤

```bash
# 步骤 1：获取详细错误信息
crictl ps -a | grep <container-name>
crictl inspect <container-id>

# 步骤 2：查看运行时日志
journalctl -u containerd --since "10 minutes ago" | grep <container-id>

# 步骤 3：常见问题排查
# OCI runtime 错误
crictl logs <container-id>

# 检查镜像是否存在
crictl images | grep <image-name>

# 检查 seccomp/AppArmor 配置
cat /etc/apparmor.d/containerd-default

# 步骤 4：测试容器创建
cat << EOF | crictl run - 
{
  "metadata": {"name": "test"},
  "image": {"image": "busybox:latest"},
  "command": ["sleep", "3600"],
  "linux": {}
}
EOF

# 步骤 5：如果是权限问题
# 检查 SELinux/AppArmor
getenforce  # SELinux
aa-status   # AppArmor

# 临时禁用（测试用）
setenforce 0  # SELinux

# 步骤 6：如果是资源问题
# 检查 cgroup 限制
cat /sys/fs/cgroup/memory/memory.limit_in_bytes
cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us
```

#### 3.2.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 禁用安全模块会降低安全性 | 仅用于诊断 |
| **低** | 检查日志无风险 | - |
| **低** | 测试容器无风险 | 测试后清理 |

#### 3.2.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 不要在生产环境长期禁用安全模块
2. OCI runtime 错误通常是镜像或配置问题
3. 资源限制错误检查 cgroup 配置
4. 测试容器记得清理
5. 某些错误可能需要更新运行时版本
```

### 3.3 镜像拉取失败

#### 3.3.1 解决步骤

```bash
# 步骤 1：确认错误类型
crictl pull <image-name>
# 查看详细错误

# 步骤 2：检查网络连通性
curl -v https://registry-1.docker.io/v2/
ping <registry-domain>

# 步骤 3：检查 DNS 解析
nslookup <registry-domain>

# 步骤 4：检查证书（私有仓库）
openssl s_client -connect <registry>:443

# 步骤 5：配置镜像仓库认证
# containerd 认证配置
mkdir -p /etc/containerd/certs.d/<registry>
cat > /etc/containerd/certs.d/<registry>/hosts.toml << EOF
server = "https://<registry>"

[host."https://<registry>"]
  capabilities = ["pull", "resolve"]
  skip_verify = false
EOF

# 步骤 6：配置镜像加速器
cat >> /etc/containerd/config.toml << EOF
[plugins."io.containerd.grpc.v1.cri".registry.mirrors]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
    endpoint = ["https://mirror.aliyuncs.com"]
EOF

# 步骤 7：重启 containerd 应用配置
systemctl restart containerd

# 步骤 8：验证拉取
crictl pull <image-name>
```

#### 3.3.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 重启 containerd 影响容器 | 在维护窗口操作 |
| **低** | 网络测试无风险 | - |
| **中** | skip_verify 降低安全性 | 仅用于内部仓库 |

#### 3.3.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 不要在生产环境使用 skip_verify
2. 私有仓库应使用正确的 CA 证书
3. 镜像加速器可能有缓存延迟
4. 检查代理配置是否正确
5. 某些镜像需要认证才能拉取
```

### 3.4 存储空间不足

#### 3.4.1 解决步骤

```bash
# 步骤 1：检查空间使用
df -h /var/lib/containerd/
df -h /var/lib/docker/
du -sh /var/lib/containerd/*
du -sh /var/lib/docker/*

# 步骤 2：清理未使用的镜像
# crictl 方式
crictl rmi --prune

# containerd 原生方式
ctr -n k8s.io images prune --all

# Docker 方式
docker system prune -a

# 步骤 3：清理已停止的容器
crictl rm $(crictl ps -a -q --state exited)

# 步骤 4：清理构建缓存（Docker）
docker builder prune

# 步骤 5：检查是否有悬空卷
# Docker
docker volume ls -f dangling=true
docker volume prune

# 步骤 6：清理日志文件
find /var/lib/containerd/ -name "*.log" -mtime +7 -delete

# 步骤 7：如果仍然空间不足，考虑扩容
# 或者迁移数据目录

# 步骤 8：验证空间释放
df -h /var/lib/containerd/
```

#### 3.4.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 清理镜像可能影响 Pod 启动 | 只清理未使用的 |
| **低** | 清理已停止容器无风险 | - |
| **高** | 删除日志可能影响问题排查 | 保留最近的日志 |

#### 3.4.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 清理前确认镜像不被当前 Pod 使用
2. docker system prune -a 会清理所有未使用资源
3. 考虑配置镜像垃圾回收策略
4. 监控存储使用，设置告警
5. 生产环境建议预留足够空间
```

### 3.5 cgroup 驱动不匹配

#### 3.5.1 解决步骤

```bash
# 步骤 1：检查当前配置
# kubelet cgroup 驱动
cat /var/lib/kubelet/config.yaml | grep cgroupDriver

# containerd cgroup 驱动
cat /etc/containerd/config.toml | grep SystemdCgroup

# Docker cgroup 驱动
docker info | grep "Cgroup Driver"

# 步骤 2：统一使用 systemd cgroup 驱动（推荐）
# 修改 containerd 配置
cat > /etc/containerd/config.toml << 'EOF'
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
EOF

# 步骤 3：修改 kubelet 配置
cat > /var/lib/kubelet/config.yaml << 'EOF'
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
# ... 其他配置
EOF

# 或者通过 kubelet 启动参数
# --cgroup-driver=systemd

# 步骤 4：重启服务
systemctl restart containerd
systemctl restart kubelet

# 步骤 5：验证配置
crictl info | grep -i cgroup
cat /var/lib/kubelet/config.yaml | grep cgroupDriver
```

#### 3.5.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **高** | cgroup 驱动变更需要重启所有组件 | 在维护窗口操作 |
| **高** | 驱动不匹配会导致节点不可用 | 确保一致后再重启 |
| **中** | 现有容器可能需要重建 | 做好 Pod 迁移准备 |

#### 3.5.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. cgroup 驱动变更是破坏性操作
2. kubelet 和容器运行时必须使用相同驱动
3. 推荐使用 systemd cgroup 驱动
4. 变更前备份所有配置
5. 考虑先在测试节点验证
6. 变更后验证所有 Pod 状态
```

### 3.6 OCI runtime 错误

#### 3.6.1 解决步骤

```bash
# 步骤 1：确认 runc 版本
runc --version

# 步骤 2：检查 runc 路径
which runc
ls -la /usr/bin/runc

# 步骤 3：检查 containerd 的 runc 配置
cat /etc/containerd/config.toml | grep -A5 "runc"

# 步骤 4：测试 runc
runc spec  # 生成默认 spec
runc --help

# 步骤 5：如果 runc 损坏，重新安装
# Debian/Ubuntu
apt-get install --reinstall runc

# CentOS/RHEL
yum reinstall runc

# 步骤 6：更新 runc 到最新版本（如果需要）
# 从 GitHub releases 下载
wget https://github.com/opencontainers/runc/releases/download/<version>/runc.amd64
chmod +x runc.amd64
mv /usr/bin/runc /usr/bin/runc.bak
mv runc.amd64 /usr/bin/runc

# 步骤 7：重启 containerd
systemctl restart containerd

# 步骤 8：验证
crictl run --help
```

#### 3.6.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **高** | 替换 runc 可能导致容器无法启动 | 备份原文件 |
| **中** | 重启 containerd 影响容器 | 在维护窗口操作 |
| **低** | 检查版本无风险 | - |

#### 3.6.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. runc 是核心组件，更新需谨慎
2. 保留原始 runc 文件用于回滚
3. runc 安全漏洞应及时修复
4. 更新后验证容器能正常创建
5. 某些 CVE 需要更新 runc 版本
```

### 3.7 containerd 配置优化

#### 3.7.1 生产环境推荐配置

```bash
# 生成基础配置
containerd config default > /etc/containerd/config.toml

# 编辑配置文件
cat > /etc/containerd/config.toml << 'EOF'
version = 2
root = "/var/lib/containerd"
state = "/run/containerd"

[grpc]
  address = "/run/containerd/containerd.sock"
  max_recv_message_size = 16777216
  max_send_message_size = 16777216

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.k8s.io/pause:3.9"
    max_concurrent_downloads = 10
    max_container_log_line_size = 16384
    
    [plugins."io.containerd.grpc.v1.cri".containerd]
      snapshotter = "overlayfs"
      default_runtime_name = "runc"
      
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
            
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://registry-1.docker.io"]
EOF

# 重启生效
systemctl restart containerd
```

---

## 附录

### A. 容器运行时关键指标

| 指标名称 | 说明 | 告警阈值建议 |
|----------|------|--------------|
| `container_runtime_operations_duration_seconds` | 运行时操作延迟 | P99 > 10s |
| `container_runtime_operations_errors_total` | 运行时操作错误 | > 0 |
| `containerd_io_*` | containerd IO 指标 | 异常变化 |

### B. 常见配置参数

| 参数 | 说明 | 推荐值 |
|------|------|--------|
| `max_concurrent_downloads` | 并发下载数 | 10 |
| `snapshotter` | 存储驱动 | overlayfs |
| `SystemdCgroup` | cgroup 驱动 | true |
| `sandbox_image` | 沙箱镜像 | 根据版本选择 |

### C. 运行时切换检查清单

- [ ] 备份原有配置
- [ ] 确认新运行时已正确安装
- [ ] 验证 CRI socket 路径
- [ ] 确认 cgroup 驱动一致
- [ ] 更新 kubelet 配置
- [ ] 在测试节点验证
- [ ] 安排维护窗口
- [ ] 逐节点切换
- [ ] 验证所有 Pod 状态
- [ ] 监控节点和 Pod 指标
