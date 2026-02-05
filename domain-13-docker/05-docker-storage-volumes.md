# Docker 存储与数据卷

> **适用版本**: Docker 20.10+ / Docker 24.0+ / Docker 25.0+ | **最后更新**: 2026-01
> 
> **生产环境运维专家注**: 涵盖持久化存储、数据备份恢复、存储性能优化、存储加密、多云存储适配等企业级存储解决方案，确保数据安全性和可靠性。

---

## 目录

- [存储架构概述](#存储架构概述)
- [存储驱动](#存储驱动)
- [数据卷类型](#数据卷类型)
- [Volume 管理](#volume-管理)
- [Bind Mount](#bind-mount)
- [tmpfs 挂载](#tmpfs-挂载)
- [存储性能优化](#存储性能优化)
- [数据备份与恢复](#数据备份与恢复)

---

## 存储架构概述

### Docker 存储层级

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              容器层 (Container Layer)                        │
│                            可读写层 - 容器运行时数据                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│    ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐            │
│    │    Volume       │  │   Bind Mount    │  │     tmpfs       │            │
│    │  /var/lib/      │  │   /host/path    │  │   (memory)      │            │
│    │  docker/volumes │  │                 │  │                 │            │
│    └────────┬────────┘  └────────┬────────┘  └────────┬────────┘            │
│             │                    │                    │                      │
│             └────────────────────┼────────────────────┘                      │
│                                  │                                           │
│                         ┌────────┴────────┐                                  │
│                         │  容器文件系统    │                                  │
│                         │   /data         │                                  │
│                         └─────────────────┘                                  │
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                              镜像层 (Image Layers)                           │
│                            只读层 - 共享、重用                                │
│     ┌─────────────────────────────────────────────────────────────────┐     │
│     │  Layer N   │  COPY app.jar /app/                               │     │
│     ├─────────────────────────────────────────────────────────────────┤     │
│     │  Layer N-1 │  RUN apt-get install java                          │     │
│     ├─────────────────────────────────────────────────────────────────┤     │
│     │  Layer 1   │  FROM ubuntu:22.04                                 │     │
│     └─────────────────────────────────────────────────────────────────┘     │
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                              存储驱动 (Storage Driver)                       │
│                     overlay2 / btrfs / zfs / devicemapper                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 存储类型对比

| 类型 | 存储位置 | 生命周期 | 性能 | 共享 | 备份 |
|:---|:---|:---|:---|:---|:---|
| **Volume** | /var/lib/docker/volumes | 独立于容器 | 高 | 多容器 | 易 |
| **Bind Mount** | 主机任意路径 | 主机控制 | 高 | 多容器 | 直接 |
| **tmpfs** | 内存 | 容器生命周期 | 最高 | 不可 | 不可 |
| **容器层** | 存储驱动管理 | 容器生命周期 | 中 | 不可 | 困难 |

---

## 存储驱动

### 存储驱动对比

| 驱动 | 后端文件系统 | 支持版本 | 特点 | 推荐场景 |
|:---|:---|:---|:---|:---|
| **overlay2** | xfs/ext4 | 4.0+ | 默认驱动、性能好 | 生产环境首选 |
| **fuse-overlayfs** | 任意 | - | Rootless 模式 | Rootless Docker |
| **btrfs** | btrfs | - | 原生快照支持 | btrfs 文件系统 |
| **zfs** | zfs | - | 高级功能 | ZFS 环境 |
| **devicemapper** | 直接块设备 | - | 废弃中 | 旧版 CentOS |
| **vfs** | 任意 | - | 无 CoW、性能差 | 测试/特殊场景 |

### overlay2 原理

```
┌─────────────────────────────────────────────────────────────────┐
│                     merged (合并视图)                            │
│  /var/lib/docker/overlay2/<id>/merged                           │
└──────────────────────────┬──────────────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
┌────────▼──────┐  ┌───────▼───────┐  ┌─────▼───────────┐
│  upperdir     │  │  workdir      │  │    lowerdir     │
│  (可写层)      │  │  (工作目录)    │  │   (只读层)      │
│  容器变更      │  │  原子操作      │  │  镜像层叠加     │
└───────────────┘  └───────────────┘  └─────────────────┘
```

### overlay2 配置

```json
// /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true",
    "overlay2.size=10G"
  ]
}
```

### 查看存储驱动

```bash
# 查看当前存储驱动
docker info | grep -i storage

# 查看存储详情
docker info --format '{{json .Driver}}'

# 查看磁盘使用
docker system df -v

# 存储位置
ls -la /var/lib/docker/overlay2/
```

---

## 数据卷类型

### Volume (命名卷)

```bash
# 创建卷
docker volume create mydata

# 使用卷
docker run -d -v mydata:/app/data myapp

# 使用 --mount (推荐)
docker run -d \
  --mount type=volume,source=mydata,target=/app/data \
  myapp
```

**特点**:
- Docker 完全管理
- 存储在 /var/lib/docker/volumes/
- 支持卷驱动插件
- 易于备份和迁移
- 推荐用于持久化数据

### Bind Mount (绑定挂载)

```bash
# 使用 -v
docker run -d -v /host/path:/container/path myapp

# 使用 --mount (推荐)
docker run -d \
  --mount type=bind,source=/host/path,target=/container/path \
  myapp

# 只读挂载
docker run -d \
  --mount type=bind,source=/host/config,target=/app/config,readonly \
  myapp
```

**特点**:
- 直接映射主机目录
- 依赖主机目录结构
- 主机和容器共享文件
- 适合开发环境

### tmpfs 挂载

```bash
# 使用 --tmpfs
docker run -d --tmpfs /app/temp:size=100m,mode=1777 myapp

# 使用 --mount
docker run -d \
  --mount type=tmpfs,target=/app/temp,tmpfs-size=100m,tmpfs-mode=1777 \
  myapp
```

**特点**:
- 存储在内存中
- 性能最高
- 容器停止数据丢失
- 适合敏感临时数据

---

## Volume 管理

### 卷操作命令

| 命令 | 说明 | 示例 |
|:---|:---|:---|
| `docker volume create` | 创建卷 | `docker volume create mydata` |
| `docker volume ls` | 列出卷 | `docker volume ls` |
| `docker volume inspect` | 卷详情 | `docker volume inspect mydata` |
| `docker volume rm` | 删除卷 | `docker volume rm mydata` |
| `docker volume prune` | 清理未用卷 | `docker volume prune -f` |

### 创建卷选项

```bash
# 基本创建
docker volume create mydata

# 指定驱动
docker volume create --driver local mydata

# 驱动选项 (NFS 示例)
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=nfs-server.example.com,rw \
  --opt device=:/path/to/share \
  nfs-volume

# 指定标签
docker volume create --label env=prod --label team=platform mydata
```

### 本地卷驱动选项

```bash
# tmpfs 类型卷
docker volume create \
  --driver local \
  --opt type=tmpfs \
  --opt device=tmpfs \
  --opt o=size=100m,uid=1000 \
  tmpfs-vol

# btrfs 子卷
docker volume create \
  --driver local \
  --opt type=btrfs \
  --opt device=/dev/sdb1 \
  btrfs-vol

# 绑定挂载类型卷
docker volume create \
  --driver local \
  --opt type=none \
  --opt o=bind \
  --opt device=/host/path \
  bind-vol
```

### 卷数据查看

```bash
# 卷存储位置
docker volume inspect mydata --format '{{.Mountpoint}}'
# /var/lib/docker/volumes/mydata/_data

# 查看卷内容 (需要 root)
sudo ls -la /var/lib/docker/volumes/mydata/_data

# 通过临时容器查看
docker run --rm -v mydata:/data alpine ls -la /data
```

### 卷共享

```bash
# 多容器共享同一卷
docker run -d --name writer -v shared-data:/data myapp-writer
docker run -d --name reader -v shared-data:/data:ro myapp-reader

# 从其他容器复制卷配置
docker run -d --volumes-from source_container myapp
```

---

## Bind Mount

### 挂载语法对比

```bash
# -v 语法 (旧)
docker run -v /host/path:/container/path myapp
docker run -v /host/path:/container/path:ro myapp

# --mount 语法 (推荐)
docker run \
  --mount type=bind,source=/host/path,target=/container/path \
  myapp

docker run \
  --mount type=bind,source=/host/path,target=/container/path,readonly \
  myapp
```

### 挂载选项

| 选项 | 说明 | 示例 |
|:---|:---|:---|
| `readonly/ro` | 只读 | `readonly` 或 `:ro` |
| `bind-propagation` | 传播模式 | `bind-propagation=rslave` |
| `consistency` | 一致性 (macOS) | `consistency=cached` |

### 绑定传播

| 传播模式 | 说明 |
|:---|:---|
| `rprivate` | 默认，挂载不传播 |
| `private` | 私有，不可见其他挂载 |
| `rshared` | 主机和容器双向传播 |
| `shared` | 共享，主机子挂载可见 |
| `rslave` | 从属，主机挂载传播到容器 |
| `slave` | 单向从主机传播 |

```bash
# 使用 rslave 传播
docker run -d \
  --mount type=bind,source=/mnt,target=/mnt,bind-propagation=rslave \
  myapp
```

### SELinux 标签

```bash
# z: 共享标签 (多容器共享)
docker run -v /host/path:/container/path:z myapp

# Z: 私有标签 (单容器)
docker run -v /host/path:/container/path:Z myapp

# --mount 语法
--mount type=bind,source=/host/path,target=/path,bind-selinux-opt=z
```

### 常见问题

| 问题 | 原因 | 解决方案 |
|:---|:---|:---|
| 权限拒绝 | UID/GID 不匹配 | 调整主机权限或使用 `--user` |
| 文件不存在 | 主机路径不存在 | 确保路径存在或使用 volume |
| SELinux 拒绝 | 缺少标签 | 添加 `:z` 或 `:Z` |
| 性能差 (macOS) | osxfs 限制 | 使用 `consistency=cached` |

---

## tmpfs 挂载

### tmpfs 配置

```bash
# 基本 tmpfs
docker run -d --tmpfs /app/temp myapp

# 带选项的 tmpfs
docker run -d \
  --tmpfs /app/temp:size=100m,mode=1777,uid=1000,gid=1000 \
  myapp

# --mount 语法
docker run -d \
  --mount type=tmpfs,target=/app/temp,tmpfs-size=100m,tmpfs-mode=1777 \
  myapp
```

### tmpfs 选项

| 选项 | 说明 | 示例 |
|:---|:---|:---|
| `size` | 大小限制 | `size=100m` |
| `mode` | 权限模式 | `mode=1777` |
| `uid` | 所有者 UID | `uid=1000` |
| `gid` | 所有者 GID | `gid=1000` |
| `nr_inodes` | inode 数量 | `nr_inodes=1024` |
| `noexec` | 禁止执行 | `noexec` |
| `nosuid` | 忽略 SUID | `nosuid` |
| `nodev` | 忽略设备文件 | `nodev` |

### 使用场景

```bash
# 敏感临时数据
docker run -d \
  --read-only \
  --tmpfs /tmp:size=100m \
  --tmpfs /run:size=10m \
  secure-app

# 高性能缓存
docker run -d \
  --tmpfs /app/cache:size=500m \
  cache-intensive-app

# 会话存储
docker run -d \
  --tmpfs /app/sessions:size=50m \
  web-app
```

---

## 存储性能优化

### 存储驱动优化

```json
// /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
```

### 文件系统选择

| 文件系统 | overlay2 支持 | 特点 | 推荐 |
|:---|:---:|:---|:---|
| **xfs** | ✓ (d_type) | 高性能、企业级 | 生产首选 |
| **ext4** | ✓ (d_type) | 稳定、广泛支持 | 通用场景 |
| **btrfs** | 使用 btrfs 驱动 | CoW、快照 | btrfs 环境 |
| **zfs** | 使用 zfs 驱动 | 高级功能 | ZFS 环境 |

### XFS 优化

```bash
# 创建 XFS (确保 d_type)
mkfs.xfs -n ftype=1 /dev/sdb1

# 验证 d_type
xfs_info /dev/sdb1 | grep ftype
# ftype=1

# 挂载选项
mount -o noatime,nodiratime /dev/sdb1 /var/lib/docker
```

### 卷性能对比

| 类型 | 顺序读写 | 随机 IO | 延迟 | 适用场景 |
|:---|:---|:---|:---|:---|
| **tmpfs** | 最高 | 最高 | 最低 | 临时数据 |
| **本地 SSD** | 高 | 高 | 低 | 生产数据 |
| **本地 HDD** | 中 | 低 | 中 | 归档数据 |
| **NFS** | 中 | 低 | 高 | 共享存储 |
| **云盘** | 中 | 中 | 中 | 云环境 |

### 最佳实践

```bash
# 分离数据和日志
docker run -d \
  --mount type=volume,source=app-data,target=/app/data \
  --mount type=tmpfs,target=/app/logs,tmpfs-size=200m \
  myapp

# 读写分离
docker run -d \
  --mount type=bind,source=/config,target=/app/config,readonly \
  --mount type=volume,source=data,target=/app/data \
  myapp

# 使用 io 限制
docker run -d \
  --device-read-bps /dev/sda:100mb \
  --device-write-bps /dev/sda:50mb \
  io-intensive-app
```

---

## 数据备份与恢复

### 卷备份

```bash
# 方法1: 使用临时容器备份
docker run --rm \
  -v mydata:/source:ro \
  -v $(pwd):/backup \
  alpine tar czf /backup/mydata-backup.tar.gz -C /source .

# 方法2: 直接备份卷目录 (需要 root)
sudo tar czf mydata-backup.tar.gz \
  -C /var/lib/docker/volumes/mydata/_data .

# 方法3: 使用 docker cp
docker run -d --name temp -v mydata:/data alpine sleep infinity
docker cp temp:/data ./backup
docker rm -f temp
```

### 卷恢复

```bash
# 创建新卷并恢复
docker volume create mydata-restored

docker run --rm \
  -v mydata-restored:/target \
  -v $(pwd):/backup:ro \
  alpine tar xzf /backup/mydata-backup.tar.gz -C /target
```

### 容器备份

```bash
# 导出容器文件系统
docker export container_name > container-backup.tar

# 导入为镜像
docker import container-backup.tar myapp:backup

# 包含卷的完整备份
docker run --rm \
  --volumes-from source_container \
  -v $(pwd):/backup \
  alpine tar czf /backup/full-backup.tar.gz /data /logs
```

### 数据迁移

```bash
# 跨主机迁移卷数据
# 源主机
docker run --rm -v mydata:/data -v $(pwd):/backup alpine \
  tar czf /backup/mydata.tar.gz -C /data .

scp mydata.tar.gz target-host:~

# 目标主机
docker volume create mydata
docker run --rm -v mydata:/data -v $(pwd):/backup alpine \
  tar xzf /backup/mydata.tar.gz -C /data
```

### 自动备份脚本

```bash
#!/bin/bash
# backup-volumes.sh

BACKUP_DIR="/backup/docker-volumes"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# 获取所有卷
for volume in $(docker volume ls -q); do
    echo "Backing up volume: $volume"
    docker run --rm \
        -v "$volume":/source:ro \
        -v "$BACKUP_DIR":/backup \
        alpine tar czf "/backup/${volume}_${DATE}.tar.gz" -C /source .
done

# 清理旧备份 (保留7天)
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR"
```

### 卷驱动插件

| 插件 | 用途 | 特点 |
|:---|:---|:---|
| **local** | 本地存储 | 默认驱动 |
| **nfs** | NFS 共享 | 网络文件系统 |
| **rexray** | 多云存储 | AWS EBS, GCE PD 等 |
| **convoy** | 快照备份 | 支持增量备份 |
| **portworx** | 分布式存储 | 企业级功能 |
| **flocker** | 数据迁移 | 已停止维护 |

```bash
# 安装卷驱动插件
docker plugin install rexray/ebs

# 使用插件创建卷
docker volume create --driver rexray/ebs --opt size=100 ebs-volume
```

---

## 相关文档

- [200-docker-architecture-overview](./200-docker-architecture-overview.md) - Docker 架构
- [202-docker-container-lifecycle](./202-docker-container-lifecycle.md) - 容器生命周期
- [203-docker-networking-deep-dive](./203-docker-networking-deep-dive.md) - Docker 网络
- [214-linux-storage-management](./214-linux-storage-management.md) - Linux 存储管理
- [230-storage-technologies-overview](./230-storage-technologies-overview.md) - 存储技术概述
