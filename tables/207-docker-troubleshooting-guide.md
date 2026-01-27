# Docker 故障排查指南

> **适用版本**: Docker 20.10+ / Docker 24.0+ / Docker 25.0+ | **最后更新**: 2026-01

---

## 目录

- [诊断方法论](#诊断方法论)
- [容器启动失败](#容器启动失败)
- [镜像问题](#镜像问题)
- [网络问题](#网络问题)
- [存储问题](#存储问题)
- [性能问题](#性能问题)
- [Docker Daemon 问题](#docker-daemon-问题)
- [常用诊断命令](#常用诊断命令)

---

## 诊断方法论

### 排查流程

```
问题发现 → 收集信息 → 分析日志 → 定位原因 → 修复验证
    │          │          │          │          │
    ▼          ▼          ▼          ▼          ▼
 告警/用户   docker ps   容器日志    具体诊断   回归测试
 反馈       docker logs  daemon日志  网络/存储
```

### 信息收集

```bash
# 系统信息
docker info
docker version

# 容器状态
docker ps -a
docker inspect <container>

# 容器日志
docker logs --tail 100 <container>

# 资源使用
docker stats --no-stream
```

---

## 容器启动失败

### 常见错误与解决

| 错误 | 原因 | 解决方案 |
|:---|:---|:---|
| `Exited (1)` | 应用错误 | `docker logs` 查看日志 |
| `Exited (137)` | OOM Killed | 增加内存限制 |
| `Exited (139)` | 段错误 | 检查应用二进制 |
| `Exited (143)` | SIGTERM | 正常停止 |
| `OCI runtime create failed` | 运行时错误 | 检查运行时配置 |

### OOM 诊断

```bash
# 检查 OOM 事件
dmesg | grep -i "oom\|killed"

# 检查容器内存
docker stats --no-stream <container>

# 检查 cgroup 内存限制
cat /sys/fs/cgroup/memory/docker/<id>/memory.limit_in_bytes
```

### 启动失败诊断

```bash
# 查看退出码
docker inspect -f '{{.State.ExitCode}}' <container>

# 查看详细状态
docker inspect -f '{{json .State}}' <container> | jq

# 交互式调试
docker run -it --entrypoint /bin/sh <image>
```

---

## 镜像问题

### 常见错误

| 错误 | 原因 | 解决方案 |
|:---|:---|:---|
| `image not found` | 镜像不存在 | 检查镜像名/标签 |
| `unauthorized` | 认证失败 | `docker login` |
| `manifest unknown` | 标签不存在 | 检查标签 |
| `no space left` | 磁盘空间不足 | `docker system prune` |

### 拉取失败

```bash
# 检查网络
ping registry-1.docker.io

# 使用镜像加速
cat /etc/docker/daemon.json
# {"registry-mirrors": ["https://mirror.example.com"]}

# 手动拉取调试
docker pull -q nginx:latest 2>&1
```

### 清理磁盘

```bash
# 查看磁盘使用
docker system df -v

# 清理未使用资源
docker system prune -af --volumes

# 清理构建缓存
docker builder prune -af
```

---

## 网络问题

### 诊断命令

```bash
# 网络列表
docker network ls

# 容器网络配置
docker inspect -f '{{json .NetworkSettings.Networks}}' <container>

# 容器内网络测试
docker exec <container> ping -c 3 <target>
docker exec <container> nslookup <hostname>
```

### 常见问题

| 问题 | 症状 | 解决方案 |
|:---|:---|:---|
| DNS 解析失败 | `nslookup` 失败 | 检查 /etc/resolv.conf |
| 容器间不通 | ping 失败 | 确保同一网络 |
| 端口不可达 | 外部无法访问 | 检查端口映射/防火墙 |
| 网络性能差 | 延迟高 | 检查 MTU 设置 |

### 网络调试容器

```bash
docker run --rm -it --network container:<target> nicolaka/netshoot
# 使用 ping, nslookup, tcpdump, ss 等工具
```

---

## 存储问题

### 常见问题

| 问题 | 症状 | 解决方案 |
|:---|:---|:---|
| 权限拒绝 | Permission denied | 检查 UID/GID 映射 |
| 卷不存在 | volume not found | 创建卷或检查名称 |
| 磁盘满 | no space left | 清理资源或扩容 |
| SELinux 拒绝 | avc: denied | 添加 :z 或 :Z 选项 |

### 诊断命令

```bash
# 检查卷
docker volume ls
docker volume inspect <volume>

# 检查挂载
docker inspect -f '{{json .Mounts}}' <container>

# 检查磁盘使用
du -sh /var/lib/docker/*
```

---

## 性能问题

### 资源监控

```bash
# 实时统计
docker stats

# 容器进程
docker top <container>

# 系统资源
top -c -p $(docker inspect -f '{{.State.Pid}}' <container>)
```

### 性能分析

| 问题 | 指标 | 解决方案 |
|:---|:---|:---|
| CPU 高 | CPU % > 100 | 优化应用/增加 CPU 限制 |
| 内存高 | MEM % 接近限制 | 增加内存/检查内存泄漏 |
| IO 慢 | 高 Block I/O | 使用 SSD/IO 限制 |
| 网络慢 | 高延迟 | 检查网络配置 |

---

## Docker Daemon 问题

### Daemon 日志

```bash
# systemd 系统
journalctl -u docker.service -f

# 非 systemd
tail -f /var/log/docker.log
```

### 常见问题

| 问题 | 症状 | 解决方案 |
|:---|:---|:---|
| Daemon 不启动 | Cannot connect | 检查 daemon 日志 |
| 连接超时 | Timeout | 检查 socket 权限 |
| 资源耗尽 | Too many files | 增加 ulimit |

### Daemon 重启

```bash
systemctl restart docker

# 保持容器运行 (需配置 live-restore)
# daemon.json: {"live-restore": true}
```

---

## 常用诊断命令

### 容器诊断

```bash
# 容器列表与状态
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 容器详情
docker inspect <container>

# 容器日志
docker logs --tail 100 -f <container>

# 进入容器
docker exec -it <container> /bin/sh

# 容器进程
docker top <container>

# 文件变化
docker diff <container>
```

### 系统诊断

```bash
# 系统信息
docker info
docker version

# 磁盘使用
docker system df -v

# 事件监控
docker events --since 1h

# 清理资源
docker system prune -af --volumes
```

### 网络诊断

```bash
# 网络列表
docker network ls

# 网络详情
docker network inspect <network>

# 端口映射
docker port <container>
```

---

## 相关文档

- [200-docker-architecture-overview](./200-docker-architecture-overview.md)
- [203-docker-networking-deep-dive](./203-docker-networking-deep-dive.md)
- [204-docker-storage-volumes](./204-docker-storage-volumes.md)
