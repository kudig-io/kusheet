# Linux 容器技术基础

> **适用版本**: Linux Kernel 5.x/6.x | **最后更新**: 2026-01

---

## 目录

- [容器技术概述](#容器技术概述)
- [Namespaces 详解](#namespaces-详解)
- [Cgroups 详解](#cgroups-详解)
- [容器文件系统](#容器文件系统)
- [容器安全特性](#容器安全特性)
- [手动创建容器](#手动创建容器)

---

## 容器技术概述

### 容器 vs 虚拟机

| 特性 | 容器 | 虚拟机 |
|:---|:---|:---|
| **隔离级别** | 进程级 | 硬件级 |
| **启动时间** | 毫秒级 | 分钟级 |
| **资源开销** | 较小 | 较大 |
| **内核共享** | 共享宿主内核 | 独立内核 |
| **安全性** | 中等 | 较高 |

### 核心技术

| 技术 | 功能 |
|:---|:---|
| **Namespaces** | 资源隔离 |
| **Cgroups** | 资源限制 |
| **OverlayFS** | 分层文件系统 |
| **Seccomp** | 系统调用过滤 |
| **Capabilities** | 权限细分 |

---

## Namespaces 详解

### Namespace 类型

| 类型 | Flag | 隔离内容 |
|:---|:---|:---|
| **PID** | CLONE_NEWPID | 进程 ID |
| **Network** | CLONE_NEWNET | 网络栈 |
| **Mount** | CLONE_NEWNS | 挂载点 |
| **UTS** | CLONE_NEWUTS | 主机名/域名 |
| **IPC** | CLONE_NEWIPC | 进程间通信 |
| **User** | CLONE_NEWUSER | 用户/组 ID |
| **Cgroup** | CLONE_NEWCGROUP | Cgroup 根 |
| **Time** | CLONE_NEWTIME | 系统时间 (5.6+) |

### 查看 Namespace

```bash
# 查看进程 namespace
ls -la /proc/<pid>/ns/

# 查看当前 namespace
ls -la /proc/self/ns/

# 比较两个进程
ls -la /proc/1/ns/
ls -la /proc/$$/ns/
```

### nsenter 进入 Namespace

```bash
# 进入容器网络 namespace
nsenter --target <pid> --net ip addr

# 进入多个 namespace
nsenter --target <pid> --mount --uts --ipc --net --pid /bin/bash

# 使用 Docker
docker exec -it <container> /bin/sh
```

### unshare 创建 Namespace

```bash
# 创建新的 UTS namespace
unshare --uts /bin/bash
hostname container-host

# 创建新的 PID namespace
unshare --pid --fork --mount-proc /bin/bash
ps aux

# 创建网络 namespace
unshare --net /bin/bash
ip link
```

---

## Cgroups 详解

### Cgroups v1 vs v2

| 特性 | Cgroups v1 | Cgroups v2 |
|:---|:---|:---|
| **层级** | 多个层级 | 单一层级 |
| **控制器** | 分散挂载 | 统一挂载 |
| **资源分配** | 按控制器 | 统一管理 |
| **状态** | 逐步淘汰 | 推荐使用 |

### Cgroups v2 控制器

| 控制器 | 功能 | 主要参数 |
|:---|:---|:---|
| **cpu** | CPU 限制 | cpu.max, cpu.weight |
| **memory** | 内存限制 | memory.max, memory.high |
| **io** | I/O 限制 | io.max, io.weight |
| **pids** | 进程数限制 | pids.max |

### Cgroups v2 操作

```bash
# 查看层级
mount | grep cgroup2
ls /sys/fs/cgroup/

# 创建 cgroup
mkdir /sys/fs/cgroup/mygroup

# 启用控制器
echo "+cpu +memory" > /sys/fs/cgroup/cgroup.subtree_control

# 设置 CPU 限制 (50%)
echo "50000 100000" > /sys/fs/cgroup/mygroup/cpu.max

# 设置内存限制 (512MB)
echo "536870912" > /sys/fs/cgroup/mygroup/memory.max

# 添加进程
echo $$ > /sys/fs/cgroup/mygroup/cgroup.procs

# 查看统计
cat /sys/fs/cgroup/mygroup/cpu.stat
cat /sys/fs/cgroup/mygroup/memory.current
```

### Docker Cgroup 配置

```bash
# 查看容器 cgroup
docker inspect --format '{{.HostConfig.CgroupParent}}' <container>

# 查看容器资源限制
cat /sys/fs/cgroup/system.slice/docker-<id>.scope/memory.max
```

---

## 容器文件系统

### OverlayFS 原理

```
┌─────────────────────────────────────────────────────────────────┐
│                     merged (联合视图)                           │
│                     用户看到的文件系统                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  upperdir (可写层)                                        │  │
│  │  容器运行时的修改                                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  lowerdir (只读层)                                        │  │
│  │  镜像层叠加                                               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 手动挂载 OverlayFS

```bash
# 准备目录
mkdir -p /tmp/overlay/{lower,upper,work,merged}

# 创建测试文件
echo "from lower" > /tmp/overlay/lower/file.txt

# 挂载
mount -t overlay overlay \
  -o lowerdir=/tmp/overlay/lower,upperdir=/tmp/overlay/upper,workdir=/tmp/overlay/work \
  /tmp/overlay/merged

# 查看结果
ls /tmp/overlay/merged/

# 修改文件
echo "modified" > /tmp/overlay/merged/file.txt

# 检查 upper 层
cat /tmp/overlay/upper/file.txt
```

---

## 容器安全特性

### Capabilities

| 能力 | 说明 |
|:---|:---|
| CAP_NET_ADMIN | 网络管理 |
| CAP_SYS_ADMIN | 系统管理 |
| CAP_SYS_PTRACE | 进程跟踪 |
| CAP_NET_BIND_SERVICE | 绑定低端口 |

```bash
# 查看进程能力
cat /proc/<pid>/status | grep Cap
getpcaps <pid>

# 设置能力
setcap cap_net_bind_service=+ep /usr/bin/python3

# 查看文件能力
getcap /usr/bin/python3
```

### Seccomp

```bash
# 查看 seccomp 状态
cat /proc/<pid>/status | grep Seccomp

# 状态值
# 0 - 禁用
# 1 - 严格模式
# 2 - 过滤模式
```

### 容器安全默认配置

| 特性 | Docker 默认 |
|:---|:---|
| Capabilities | 删除危险能力 |
| Seccomp | 禁用危险系统调用 |
| AppArmor | 默认 profile |
| User Namespace | 默认禁用 |
| Read-only | 需显式启用 |

---

## 手动创建容器

### 最小容器示例

```bash
#!/bin/bash
# 创建最小容器

# 准备根文件系统
mkdir -p /tmp/container/rootfs
# 使用 busybox 或解压基础镜像

# 创建隔离进程
unshare --pid --fork --mount --uts --ipc \
  --mount-proc=/tmp/container/rootfs/proc \
  chroot /tmp/container/rootfs /bin/sh
```

### 使用 runc 创建容器

```bash
# 创建 bundle 目录
mkdir -p /tmp/mycontainer/rootfs

# 准备根文件系统
docker export $(docker create alpine) | tar -C /tmp/mycontainer/rootfs -xf -

# 生成 config.json
cd /tmp/mycontainer
runc spec

# 运行容器
runc run mycontainer
```

---

## 相关文档

- [200-docker-architecture-overview](./200-docker-architecture-overview.md) - Docker 架构
- [165-cri-container-runtime-deep-dive](./165-cri-container-runtime-deep-dive.md) - CRI 详解
- [206-docker-security-best-practices](./206-docker-security-best-practices.md) - Docker 安全
