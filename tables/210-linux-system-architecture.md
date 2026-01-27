# Linux 系统架构与内核基础

> **适用版本**: Linux Kernel 5.x/6.x | **最后更新**: 2026-01

---

## 目录

- [Linux 内核架构](#linux-内核架构)
- [系统启动过程](#系统启动过程)
- [systemd 服务管理](#systemd-服务管理)
- [内核参数调优](#内核参数调优)
- [内核模块管理](#内核模块管理)
- [主流发行版对比](#主流发行版对比)

---

## Linux 内核架构

### 内核层次结构

```
┌─────────────────────────────────────────────────────────────────┐
│                         用户空间                                 │
│   应用程序 │ Shell │ 库 (glibc) │ 系统工具                       │
└─────────────────────────────────┬───────────────────────────────┘
                                  │ 系统调用 (syscall)
┌─────────────────────────────────┴───────────────────────────────┐
│                         内核空间                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  系统调用接口 (System Call Interface)                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐  │
│  │ 进程管理    │ │ 内存管理    │ │ 文件系统    │ │ 网络协议栈  │  │
│  │ (Scheduler)│ │ (MM)       │ │ (VFS)      │ │ (TCP/IP)   │  │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  设备驱动程序 (Device Drivers)                            │  │
│  │  块设备 │ 字符设备 │ 网络设备                              │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  硬件抽象层 (HAL)                                         │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                  │
┌─────────────────────────────────┴───────────────────────────────┐
│                          硬件                                    │
│   CPU │ 内存 │ 磁盘 │ 网卡 │ GPU │ 其他外设                      │
└─────────────────────────────────────────────────────────────────┘
```

### 内核子系统

| 子系统 | 功能 | 核心组件 |
|:---|:---|:---|
| **进程管理** | 进程调度、创建、终止 | CFS 调度器、fork/exec |
| **内存管理** | 虚拟内存、分页、缓存 | 页表、slab 分配器 |
| **文件系统** | VFS、各种文件系统 | ext4、xfs、btrfs |
| **网络子系统** | TCP/IP 协议栈 | socket、netfilter |
| **设备驱动** | 硬件抽象、驱动框架 | 块设备、字符设备 |
| **安全模块** | 访问控制 | SELinux、AppArmor |

### 内核版本

| 版本系列 | LTS 支持 | 主要特性 |
|:---|:---|:---|
| **5.4** | 2024-12 | 基础稳定版本 |
| **5.10** | 2026-12 | exFAT、稳定改进 |
| **5.15** | 2026-10 | NTFS 驱动、改进 |
| **6.1** | 2026-12 | Rust 支持、性能提升 |
| **6.6** | 2026-12+ | 持续改进 |

---

## 系统启动过程

### 启动流程

```
电源开启
    │
    ▼
┌───────────────┐
│  BIOS/UEFI    │  POST 自检、硬件初始化
└───────┬───────┘
        │
        ▼
┌───────────────┐
│  Bootloader   │  GRUB2: 加载内核和 initramfs
└───────┬───────┘
        │
        ▼
┌───────────────┐
│  Linux Kernel │  解压、初始化硬件和驱动
└───────┬───────┘
        │
        ▼
┌───────────────┐
│  initramfs    │  临时根文件系统、挂载真实根
└───────┬───────┘
        │
        ▼
┌───────────────┐
│  systemd      │  PID 1、服务管理、目标切换
│  (init)       │
└───────┬───────┘
        │
        ▼
┌───────────────┐
│  用户空间服务  │  网络、登录、应用服务
└───────────────┘
```

### GRUB2 配置

```bash
# 配置文件
/etc/default/grub          # 主配置
/boot/grub2/grub.cfg       # 生成的配置 (勿直接编辑)

# 常用参数
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX="quiet rhgb"
GRUB_DISABLE_RECOVERY="true"

# 重新生成配置
grub2-mkconfig -o /boot/grub2/grub.cfg
```

### 内核启动参数

| 参数 | 说明 | 示例 |
|:---|:---|:---|
| `quiet` | 减少启动信息 | `quiet` |
| `init=` | 指定 init 程序 | `init=/bin/bash` |
| `root=` | 根文件系统 | `root=/dev/sda1` |
| `single` / `1` | 单用户模式 | `single` |
| `selinux=0` | 禁用 SELinux | `selinux=0` |
| `mem=` | 限制内存 | `mem=4G` |

---

## systemd 服务管理

### 常用命令

| 命令 | 说明 |
|:---|:---|
| `systemctl start <unit>` | 启动服务 |
| `systemctl stop <unit>` | 停止服务 |
| `systemctl restart <unit>` | 重启服务 |
| `systemctl reload <unit>` | 重载配置 |
| `systemctl enable <unit>` | 开机自启 |
| `systemctl disable <unit>` | 禁止自启 |
| `systemctl status <unit>` | 查看状态 |
| `systemctl is-active <unit>` | 检查是否运行 |
| `systemctl list-units` | 列出所有单元 |
| `systemctl daemon-reload` | 重载 unit 文件 |

### Unit 文件

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=appuser
Group=appgroup
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/bin/server
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### Service 类型

| 类型 | 说明 |
|:---|:---|
| `simple` | 默认，ExecStart 进程即主进程 |
| `forking` | fork 后父进程退出 |
| `oneshot` | 一次性任务 |
| `notify` | 服务就绪时通知 systemd |
| `dbus` | 注册 D-Bus 后就绪 |

### 日志查看

```bash
# 查看服务日志
journalctl -u myapp.service

# 实时跟踪
journalctl -u myapp.service -f

# 最近 N 行
journalctl -u myapp.service -n 100

# 本次启动日志
journalctl -u myapp.service -b
```

---

## 内核参数调优

### sysctl 配置

```bash
# 查看参数
sysctl -a | grep <pattern>
sysctl net.ipv4.ip_forward

# 临时修改
sysctl -w net.ipv4.ip_forward=1

# 永久配置
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/99-custom.conf
sysctl --system
```

### 常用内核参数

#### 网络参数

| 参数 | 说明 | 推荐值 |
|:---|:---|:---|
| `net.ipv4.ip_forward` | IP 转发 | 1 (容器/路由) |
| `net.core.somaxconn` | 监听队列 | 65535 |
| `net.ipv4.tcp_max_syn_backlog` | SYN 队列 | 65535 |
| `net.core.netdev_max_backlog` | 网络设备队列 | 65535 |
| `net.ipv4.tcp_fin_timeout` | FIN 超时 | 15 |
| `net.ipv4.tcp_tw_reuse` | TIME_WAIT 重用 | 1 |

#### 内存参数

| 参数 | 说明 | 推荐值 |
|:---|:---|:---|
| `vm.swappiness` | swap 倾向 | 10-30 |
| `vm.dirty_ratio` | 脏页比例 | 20 |
| `vm.dirty_background_ratio` | 后台刷盘比例 | 5 |
| `vm.overcommit_memory` | 内存过量分配 | 0/1/2 |

#### 文件系统参数

| 参数 | 说明 | 推荐值 |
|:---|:---|:---|
| `fs.file-max` | 最大文件数 | 2097152 |
| `fs.inotify.max_user_watches` | inotify 监控数 | 524288 |

### 生产配置示例

```bash
# /etc/sysctl.d/99-kubernetes.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1

vm.swappiness = 10
vm.max_map_count = 262144

fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192
```

---

## 内核模块管理

### 模块操作

```bash
# 查看已加载模块
lsmod

# 加载模块
modprobe br_netfilter
modprobe overlay

# 卸载模块
modprobe -r <module>

# 模块信息
modinfo br_netfilter

# 开机加载
echo "br_netfilter" >> /etc/modules-load.d/kubernetes.conf
```

### 容器相关模块

| 模块 | 用途 |
|:---|:---|
| `overlay` | OverlayFS 存储驱动 |
| `br_netfilter` | 网桥 iptables 过滤 |
| `ip_vs` | IPVS 负载均衡 |
| `ip_vs_rr` | IPVS 轮询调度 |
| `nf_conntrack` | 连接跟踪 |

---

## 主流发行版对比

| 发行版 | 包管理 | 生命周期 | 适用场景 |
|:---|:---|:---|:---|
| **RHEL/CentOS Stream** | dnf/yum | 10 年 | 企业生产 |
| **Ubuntu LTS** | apt | 5 年 | 云/容器 |
| **Debian** | apt | 5 年 | 稳定性优先 |
| **SUSE/openSUSE** | zypper | 10+ 年 | 企业生产 |
| **Alpine** | apk | 2 年 | 容器基础镜像 |
| **Fedora** | dnf | 1 年 | 新技术验证 |

### 容器推荐

| 场景 | 推荐发行版 |
|:---|:---|
| **容器运行时** | RHEL CoreOS, Flatcar, Ubuntu |
| **容器基础镜像** | Alpine, Distroless, Debian-slim |
| **K8s 节点** | Ubuntu, RHEL, Flatcar |

---

## 相关文档

- [211-linux-process-management](./211-linux-process-management.md) - 进程管理
- [212-linux-filesystem-deep-dive](./212-linux-filesystem-deep-dive.md) - 文件系统
- [217-linux-container-fundamentals](./217-linux-container-fundamentals.md) - 容器基础
