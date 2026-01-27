# Linux 文件系统详解

> **适用版本**: Linux Kernel 5.x/6.x | **最后更新**: 2026-01

---

## 目录

- [VFS 虚拟文件系统](#vfs-虚拟文件系统)
- [文件系统类型](#文件系统类型)
- [磁盘分区与挂载](#磁盘分区与挂载)
- [文件权限与 ACL](#文件权限与-acl)
- [inode 与链接](#inode-与链接)
- [文件系统管理](#文件系统管理)

---

## VFS 虚拟文件系统

### VFS 架构

```
┌─────────────────────────────────────────────────────────────────┐
│                         用户空间                                 │
│     应用程序: open(), read(), write(), close()                   │
└───────────────────────────┬─────────────────────────────────────┘
                            │ 系统调用
┌───────────────────────────┴─────────────────────────────────────┐
│                  VFS (Virtual File System)                       │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  通用文件模型: superblock, inode, dentry, file         │    │
│  └─────────────────────────────────────────────────────────┘    │
│       │              │              │              │             │
│       ▼              ▼              ▼              ▼             │
│  ┌─────────┐    ┌─────────┐   ┌─────────┐   ┌─────────┐        │
│  │  ext4   │    │   xfs   │   │  btrfs  │   │ overlay │        │
│  └─────────┘    └─────────┘   └─────────┘   └─────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

### VFS 核心对象

| 对象 | 说明 | 作用 |
|:---|:---|:---|
| **superblock** | 文件系统元数据 | 文件系统类型、大小、状态 |
| **inode** | 文件元数据 | 权限、大小、时间、数据块位置 |
| **dentry** | 目录项 | 文件名到 inode 映射 |
| **file** | 打开的文件 | 进程文件描述符关联 |

---

## 文件系统类型

### 本地文件系统对比

| 文件系统 | 最大文件 | 最大卷 | 特点 | 推荐场景 |
|:---|:---|:---|:---|:---|
| **ext4** | 16TB | 1EB | 稳定、广泛支持 | 通用场景 |
| **xfs** | 8EB | 8EB | 高性能、大文件 | 生产环境 |
| **btrfs** | 16EB | 16EB | CoW、快照、校验 | 高级功能需求 |
| **zfs** | 16EB | 256ZB | 企业级、完整性 | 需要 ZFS 特性 |

### 特殊文件系统

| 文件系统 | 说明 | 挂载点 |
|:---|:---|:---|
| **tmpfs** | 内存文件系统 | /tmp, /dev/shm |
| **proc** | 进程信息 | /proc |
| **sysfs** | 设备/驱动信息 | /sys |
| **devtmpfs** | 设备节点 | /dev |
| **cgroup** | 控制组 | /sys/fs/cgroup |

---

## 磁盘分区与挂载

### 分区工具

```bash
# fdisk (MBR)
fdisk /dev/sdb

# gdisk (GPT)
gdisk /dev/sdb

# parted (通用)
parted /dev/sdb

# 查看分区
lsblk
fdisk -l
```

### 创建文件系统

```bash
# ext4
mkfs.ext4 /dev/sdb1

# xfs
mkfs.xfs /dev/sdb1

# 带标签
mkfs.ext4 -L data /dev/sdb1

# 查看文件系统
blkid
```

### 挂载管理

```bash
# 临时挂载
mount /dev/sdb1 /mnt/data
mount -t xfs /dev/sdb1 /mnt/data
mount -o rw,noatime /dev/sdb1 /mnt/data

# 卸载
umount /mnt/data

# 查看挂载
mount | grep sdb
df -Th
```

### /etc/fstab 配置

```bash
# /etc/fstab
# <device>       <mountpoint>  <type>  <options>      <dump> <pass>
/dev/sdb1        /data         xfs     defaults,noatime  0      2
UUID=xxx-xxx     /backup       ext4    defaults          0      2
LABEL=data       /mnt/data     xfs     defaults          0      2
```

### 常用挂载选项

| 选项 | 说明 |
|:---|:---|
| `defaults` | 默认选项 (rw,suid,dev,exec,auto,nouser,async) |
| `noatime` | 不更新访问时间 (性能优化) |
| `nodiratime` | 不更新目录访问时间 |
| `noexec` | 禁止执行 |
| `nosuid` | 忽略 SUID |
| `ro` | 只读 |
| `rw` | 读写 |

---

## 文件权限与 ACL

### 基本权限

```bash
# 查看权限
ls -la file

# 修改权限
chmod 755 file
chmod u+x file
chmod go-w file

# 修改所有者
chown user:group file
chown -R user:group dir/
```

### 权限位

| 权限 | 数值 | 文件 | 目录 |
|:---:|:---:|:---|:---|
| r | 4 | 读取内容 | 列出内容 |
| w | 2 | 修改内容 | 创建/删除文件 |
| x | 1 | 执行 | 进入目录 |

### 特殊权限

| 权限 | 数值 | 位置 | 说明 |
|:---|:---:|:---|:---|
| SUID | 4000 | 用户x -> s | 以文件所有者执行 |
| SGID | 2000 | 组x -> s | 以文件所属组执行 |
| Sticky | 1000 | 其他x -> t | 仅所有者可删除 |

### ACL 扩展权限

```bash
# 查看 ACL
getfacl file

# 设置 ACL
setfacl -m u:username:rwx file
setfacl -m g:groupname:rx file
setfacl -m d:u:username:rwx dir/  # 默认 ACL

# 删除 ACL
setfacl -x u:username file
setfacl -b file  # 删除所有
```

---

## inode 与链接

### inode 结构

| 内容 | 说明 |
|:---|:---|
| 文件类型 | 普通文件、目录、链接等 |
| 权限 | rwxrwxrwx |
| 所有者 | UID, GID |
| 大小 | 字节数 |
| 时间戳 | atime, mtime, ctime |
| 数据块指针 | 直接/间接块 |

### 查看 inode

```bash
# 查看 inode 信息
stat file
ls -i file

# inode 使用情况
df -i
```

### 硬链接 vs 软链接

| 特性 | 硬链接 | 软链接 |
|:---|:---|:---|
| inode | 相同 | 不同 |
| 跨文件系统 | 不可 | 可以 |
| 链接目录 | 不可 | 可以 |
| 源删除影响 | 无影响 | 失效 |

```bash
# 硬链接
ln source link

# 软链接
ln -s source link
```

---

## 文件系统管理

### 扩展文件系统

```bash
# ext4
resize2fs /dev/sdb1

# xfs (只能扩展)
xfs_growfs /mnt/data
```

### 检查修复

```bash
# 检查
fsck /dev/sdb1         # 通用
e2fsck /dev/sdb1       # ext 系列
xfs_repair /dev/sdb1   # xfs

# 注意：必须先卸载
```

### 磁盘配额

```bash
# 启用配额
mount -o usrquota,grpquota /dev/sdb1 /data

# 创建配额文件
quotacheck -cug /data
quotaon /data

# 设置配额
edquota -u username
setquota -u username 1000000 1500000 0 0 /data

# 查看配额
quota -u username
repquota /data
```

### 常用命令

```bash
# 磁盘使用
df -Th
du -sh *

# 块设备
lsblk
blkid

# 文件类型
file filename

# 查找
find /path -name "*.log" -size +100M
locate filename
```

---

## 相关文档

- [210-linux-system-architecture](./210-linux-system-architecture.md) - 系统架构
- [214-linux-storage-management](./214-linux-storage-management.md) - 存储管理
- [232-raid-storage-redundancy](./232-raid-storage-redundancy.md) - RAID 配置
