# Docker 容器生命周期管理

> **适用版本**: Docker 20.10+ / Docker 24.0+ / Docker 25.0+ | **最后更新**: 2026-01

---

## 目录

- [容器状态机](#容器状态机)
- [容器创建与运行](#容器创建与运行)
- [资源限制配置](#资源限制配置)
- [健康检查配置](#健康检查配置)
- [容器日志管理](#容器日志管理)
- [信号处理与优雅停止](#信号处理与优雅停止)
- [容器重启策略](#容器重启策略)
- [容器监控与调试](#容器监控与调试)

---

## 容器状态机

### 状态流转图

```
                        docker create
           ┌──────────────────────────────────────────┐
           │                                          ▼
       ┌───────┐                                  ┌───────────┐
       │       │                                  │           │
       │ None  │                                  │  Created  │
       │       │                                  │           │
       └───────┘                                  └─────┬─────┘
           ▲                                            │
           │ docker rm                                  │ docker start
           │                                            ▼
       ┌───────────┐     docker stop/kill         ┌───────────┐
       │           │◄─────────────────────────────│           │
       │  Exited   │                              │  Running  │◄───────┐
       │           │─────────────────────────────►│           │        │
       └───────────┘     docker start             └─────┬─────┘        │
           ▲                                            │              │
           │                                            │ docker pause │
           │ 进程退出                                   ▼              │
       ┌───────────┐                              ┌───────────┐        │
       │           │                              │           │        │
       │   Dead    │                              │  Paused   │────────┘
       │           │                              │           │ docker unpause
       └───────────┘                              └───────────┘
```

### 容器状态详解

| 状态 | 说明 | docker ps 显示 | 触发条件 |
|:---|:---|:---|:---|
| **created** | 已创建未启动 | Created | `docker create` |
| **running** | 运行中 | Up X seconds | `docker start/run` |
| **paused** | 已暂停 | Up (Paused) | `docker pause` |
| **restarting** | 重启中 | Restarting | 重启策略触发 |
| **exited** | 已退出 | Exited (code) | 进程正常/异常退出 |
| **dead** | 死亡状态 | Dead | 删除失败等异常 |
| **removing** | 删除中 | Removal In Progress | `docker rm` |

### 退出码含义

| 退出码 | 含义 | 常见原因 |
|:---|:---|:---|
| **0** | 正常退出 | 程序正常完成 |
| **1** | 一般性错误 | 应用错误 |
| **2** | Shell 内置错误 | 命令用法错误 |
| **126** | 命令不可执行 | 权限问题 |
| **127** | 命令未找到 | 路径或命令错误 |
| **128** | exit 参数无效 | exit 参数非数字 |
| **128+N** | 信号 N 终止 | 如 137=128+9(SIGKILL) |
| **137** | SIGKILL (9) | OOM 或 docker kill |
| **139** | SIGSEGV (11) | 段错误 |
| **143** | SIGTERM (15) | docker stop |
| **255** | 退出码越界 | 异常情况 |

---

## 容器创建与运行

### docker run 完整参数参考

#### 基本配置

| 参数 | 说明 | 示例 |
|:---|:---|:---|
| `--name` | 容器名称 | `--name myapp` |
| `--hostname` | 容器主机名 | `--hostname webapp` |
| `--domainname` | 域名 | `--domainname example.com` |
| `-d, --detach` | 后台运行 | `-d` |
| `-it` | 交互式终端 | `-it bash` |
| `--rm` | 退出后删除 | `--rm` |
| `-w, --workdir` | 工作目录 | `-w /app` |
| `--entrypoint` | 覆盖入口点 | `--entrypoint /bin/sh` |

#### 环境与配置

| 参数 | 说明 | 示例 |
|:---|:---|:---|
| `-e, --env` | 环境变量 | `-e "DEBUG=true"` |
| `--env-file` | 环境变量文件 | `--env-file .env` |
| `-l, --label` | 标签 | `-l "app=web"` |
| `--label-file` | 标签文件 | `--label-file labels.txt` |

#### 网络配置

| 参数 | 说明 | 示例 |
|:---|:---|:---|
| `-p, --publish` | 端口映射 | `-p 8080:80` |
| `-P` | 随机端口映射 | `-P` |
| `--network` | 网络模式 | `--network host` |
| `--network-alias` | 网络别名 | `--network-alias db` |
| `--dns` | DNS 服务器 | `--dns 8.8.8.8` |
| `--dns-search` | DNS 搜索域 | `--dns-search example.com` |
| `--add-host` | 添加 hosts | `--add-host "db:192.168.1.10"` |
| `--mac-address` | MAC 地址 | `--mac-address 02:42:ac:11:00:02` |
| `--ip` | 指定 IP | `--ip 172.18.0.100` |
| `--link` | 连接容器 (废弃) | `--link mysql:db` |

#### 存储配置

| 参数 | 说明 | 示例 |
|:---|:---|:---|
| `-v, --volume` | 挂载卷 | `-v /host:/container:ro` |
| `--mount` | 高级挂载 | `--mount type=bind,src=/data,dst=/app` |
| `--tmpfs` | tmpfs 挂载 | `--tmpfs /tmp:size=100m` |
| `--volumes-from` | 继承卷 | `--volumes-from datacontainer` |
| `--read-only` | 只读根文件系统 | `--read-only` |

### mount 类型详解

```bash
# bind mount
--mount type=bind,source=/host/path,target=/container/path,readonly

# volume
--mount type=volume,source=myvolume,target=/data,volume-driver=local

# tmpfs
--mount type=tmpfs,target=/app/temp,tmpfs-size=100m,tmpfs-mode=1777

# npipe (Windows)
--mount type=npipe,source=\\.\pipe\docker_engine,target=\\.\pipe\docker_engine
```

### 容器层级配置

```bash
# 完整生产配置示例
docker run -d \
  --name production-app \
  --hostname app-server \
  --restart unless-stopped \
  --user 1000:1000 \
  --read-only \
  --tmpfs /tmp:size=100m,mode=1777 \
  --tmpfs /run:size=10m \
  --mount type=bind,src=/app/config,dst=/config,ro \
  --mount type=volume,src=app-data,dst=/data \
  -p 8080:8080 \
  -e "NODE_ENV=production" \
  --memory 512m \
  --memory-reservation 256m \
  --cpus 1.0 \
  --pids-limit 100 \
  --security-opt no-new-privileges:true \
  --cap-drop ALL \
  --cap-add NET_BIND_SERVICE \
  --health-cmd "curl -f http://localhost:8080/health || exit 1" \
  --health-interval 30s \
  --health-timeout 10s \
  --health-retries 3 \
  --log-driver json-file \
  --log-opt max-size=100m \
  --log-opt max-file=3 \
  myapp:v1.0
```

---

## 资源限制配置

### 内存限制

| 参数 | 说明 | 示例 |
|:---|:---|:---|
| `--memory, -m` | 内存硬限制 | `-m 512m` |
| `--memory-reservation` | 内存软限制 | `--memory-reservation 256m` |
| `--memory-swap` | 内存+swap 限制 | `--memory-swap 1g` |
| `--memory-swappiness` | swap 倾向 (0-100) | `--memory-swappiness 10` |
| `--oom-kill-disable` | 禁用 OOM killer | `--oom-kill-disable` |
| `--oom-score-adj` | OOM 优先级调整 | `--oom-score-adj -500` |
| `--kernel-memory` | 内核内存限制 (废弃) | - |

#### Swap 配置说明

| --memory | --memory-swap | 效果 |
|:---|:---|:---|
| 512m | 不设置 | 可用 swap = 内存的 2 倍 (1G) |
| 512m | 1g | 可用 swap = 512m |
| 512m | 512m | 禁用 swap |
| 512m | -1 | 无限 swap |
| 512m | 0 | 不设置 (同不设置) |

### CPU 限制

| 参数 | 说明 | 示例 |
|:---|:---|:---|
| `--cpus` | CPU 核心数 | `--cpus 1.5` |
| `--cpu-shares, -c` | CPU 相对权重 (1024基准) | `-c 512` |
| `--cpu-period` | CFS 周期 (微秒) | `--cpu-period 100000` |
| `--cpu-quota` | CFS 配额 (微秒) | `--cpu-quota 150000` |
| `--cpuset-cpus` | 绑定 CPU 核心 | `--cpuset-cpus 0,2` |
| `--cpuset-mems` | 绑定内存节点 | `--cpuset-mems 0` |
| `--cpu-rt-period` | 实时调度周期 | `--cpu-rt-period 1000000` |
| `--cpu-rt-runtime` | 实时调度时间 | `--cpu-rt-runtime 950000` |

#### CPU 限制换算

```
--cpus 1.5  ≈  --cpu-period 100000 --cpu-quota 150000

计算公式:
cpus = cpu-quota / cpu-period
例: 150000 / 100000 = 1.5 个 CPU
```

### I/O 限制

| 参数 | 说明 | 示例 |
|:---|:---|:---|
| `--blkio-weight` | 块 I/O 权重 (10-1000) | `--blkio-weight 500` |
| `--blkio-weight-device` | 设备权重 | `--blkio-weight-device /dev/sda:100` |
| `--device-read-bps` | 读取速率限制 | `--device-read-bps /dev/sda:10mb` |
| `--device-write-bps` | 写入速率限制 | `--device-write-bps /dev/sda:10mb` |
| `--device-read-iops` | 读取 IOPS 限制 | `--device-read-iops /dev/sda:1000` |
| `--device-write-iops` | 写入 IOPS 限制 | `--device-write-iops /dev/sda:1000` |

### 其他限制

| 参数 | 说明 | 示例 |
|:---|:---|:---|
| `--pids-limit` | 进程数限制 | `--pids-limit 100` |
| `--ulimit` | ulimit 配置 | `--ulimit nofile=65536:65536` |
| `--shm-size` | /dev/shm 大小 | `--shm-size 256m` |
| `--gpus` | GPU 访问 | `--gpus all` |
| `--device` | 设备访问 | `--device /dev/nvidia0` |

### ulimit 常用配置

```bash
docker run -d \
  --ulimit nofile=65536:65536 \
  --ulimit nproc=4096:4096 \
  --ulimit core=0:0 \
  --ulimit memlock=-1:-1 \
  myapp
```

| ulimit 类型 | 说明 | 推荐值 |
|:---|:---|:---|
| nofile | 打开文件数 | 65536 |
| nproc | 进程数 | 4096 |
| core | core dump 大小 | 0 (禁用) / unlimited |
| memlock | 锁定内存 | -1 (无限) |
| stack | 栈大小 | 8388608 (8MB) |

---

## 健康检查配置

### 健康检查参数

| 参数 | 默认值 | 说明 |
|:---|:---|:---|
| `--health-cmd` | - | 健康检查命令 |
| `--health-interval` | 30s | 检查间隔 |
| `--health-timeout` | 30s | 超时时间 |
| `--health-retries` | 3 | 失败重试次数 |
| `--health-start-period` | 0s | 启动宽限期 |
| `--health-start-interval` | 5s | 启动期检查间隔 (Docker 25+) |
| `--no-healthcheck` | - | 禁用健康检查 |

### 健康检查状态

| 状态 | 说明 | 触发条件 |
|:---|:---|:---|
| **starting** | 启动中 | 在 start-period 内 |
| **healthy** | 健康 | 检查命令返回 0 |
| **unhealthy** | 不健康 | 连续 N 次检查失败 |

### 健康检查示例

```bash
# HTTP 健康检查
docker run -d \
  --health-cmd "curl -f http://localhost:8080/health || exit 1" \
  --health-interval 30s \
  --health-timeout 10s \
  --health-retries 3 \
  --health-start-period 60s \
  myapp

# TCP 端口检查
docker run -d \
  --health-cmd "nc -z localhost 3306 || exit 1" \
  --health-interval 10s \
  mysql

# 命令检查
docker run -d \
  --health-cmd "pg_isready -U postgres" \
  --health-interval 10s \
  postgres

# 文件检查
docker run -d \
  --health-cmd "test -f /var/run/app.pid" \
  --health-interval 30s \
  myapp
```

### Dockerfile 健康检查

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# 禁用健康检查
HEALTHCHECK NONE
```

### 查看健康状态

```bash
# 查看健康状态
docker inspect --format='{{.State.Health.Status}}' container_name

# 查看健康检查日志
docker inspect --format='{{json .State.Health}}' container_name | jq

# 健康检查事件
docker events --filter 'event=health_status'
```

---

## 容器日志管理

### 日志驱动对比

| 驱动 | 特点 | 存储位置 | docker logs |
|:---|:---|:---|:---:|
| **json-file** | 默认、易用 | 本地 JSON 文件 | ✓ |
| **local** | 性能优化版 json-file | 本地压缩文件 | ✓ |
| **journald** | 集成 systemd | journald | ✓ |
| **syslog** | syslog 协议 | syslog 服务器 | ✗ |
| **gelf** | Graylog 格式 | GELF 服务器 | ✗ |
| **fluentd** | Fluentd 转发 | Fluentd | ✗ |
| **awslogs** | AWS CloudWatch | AWS | ✗ |
| **splunk** | Splunk HEC | Splunk | ✗ |
| **gcplogs** | GCP Logging | GCP | ✗ |
| **none** | 禁用日志 | 无 | ✗ |

### json-file 配置

```bash
docker run -d \
  --log-driver json-file \
  --log-opt max-size=100m \
  --log-opt max-file=5 \
  --log-opt compress=true \
  --log-opt labels=app,env \
  myapp
```

| 选项 | 默认值 | 说明 |
|:---|:---|:---|
| max-size | -1 (无限) | 单文件最大大小 |
| max-file | 1 | 文件轮转数量 |
| compress | false | 压缩轮转文件 |
| labels | - | 添加到日志的标签 |
| env | - | 添加到日志的环境变量 |

### 日志命令

```bash
# 查看日志
docker logs container_name

# 实时跟踪
docker logs -f container_name

# 最后 100 行
docker logs --tail 100 container_name

# 时间范围
docker logs --since 2024-01-01T00:00:00 --until 2024-01-02T00:00:00 container_name

# 带时间戳
docker logs -t container_name

# stderr 输出
docker logs container_name 2>&1 | grep ERROR
```

### 全局日志配置

```json
// /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3",
    "compress": "true"
  }
}
```

### 清理日志

```bash
# 查看日志文件位置
docker inspect --format='{{.LogPath}}' container_name

# 清空日志 (谨慎使用)
truncate -s 0 $(docker inspect --format='{{.LogPath}}' container_name)

# 重置所有容器日志
for container in $(docker ps -q); do
    truncate -s 0 $(docker inspect --format='{{.LogPath}}' $container)
done
```

---

## 信号处理与优雅停止

### Linux 信号参考

| 信号 | 编号 | 说明 | 默认行为 |
|:---|:---:|:---|:---|
| SIGHUP | 1 | 挂起 | 终止 |
| SIGINT | 2 | 中断 (Ctrl+C) | 终止 |
| SIGQUIT | 3 | 退出 | 终止+core dump |
| SIGKILL | 9 | 强制终止 | 终止 (不可捕获) |
| SIGTERM | 15 | 终止请求 | 终止 |
| SIGUSR1 | 10 | 用户自定义 | 终止 |
| SIGUSR2 | 12 | 用户自定义 | 终止 |

### 停止容器流程

```
docker stop container
    │
    ▼
发送 SIGTERM (或 STOPSIGNAL)
    │
    ▼
等待 stop-timeout (默认 10s)
    │
    ├── 容器退出 → 完成
    │
    └── 超时 → 发送 SIGKILL → 强制终止
```

### 停止命令

```bash
# 优雅停止 (SIGTERM + 10s 超时 + SIGKILL)
docker stop container_name

# 指定超时时间
docker stop -t 30 container_name

# 立即终止
docker kill container_name

# 发送特定信号
docker kill -s SIGUSR1 container_name

# 停止所有容器
docker stop $(docker ps -q)
```

### 应用端优雅停止实现

```python
# Python 示例
import signal
import sys
import time

def graceful_shutdown(signum, frame):
    print("Received SIGTERM, shutting down gracefully...")
    # 停止接收新请求
    # 等待现有请求完成
    # 关闭数据库连接
    # 清理资源
    time.sleep(5)  # 模拟清理
    print("Cleanup complete, exiting...")
    sys.exit(0)

signal.signal(signal.SIGTERM, graceful_shutdown)
signal.signal(signal.SIGINT, graceful_shutdown)

# 主循环
while True:
    # 业务逻辑
    time.sleep(1)
```

```go
// Go 示例
package main

import (
    "context"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"
)

func main() {
    server := &http.Server{Addr: ":8080"}

    go func() {
        if err := server.ListenAndServe(); err != http.ErrServerClosed {
            log.Fatalf("HTTP server error: %v", err)
        }
    }()

    // 等待终止信号
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    // 优雅关闭，最多等待 30 秒
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := server.Shutdown(ctx); err != nil {
        log.Fatalf("Server forced to shutdown: %v", err)
    }

    log.Println("Server exited gracefully")
}
```

### Dockerfile STOPSIGNAL

```dockerfile
# 设置停止信号
STOPSIGNAL SIGQUIT

# Nginx 默认使用 SIGQUIT 优雅关闭
FROM nginx:alpine
STOPSIGNAL SIGQUIT
```

---

## 容器重启策略

### 重启策略类型

| 策略 | 说明 | docker run 参数 |
|:---|:---|:---|
| **no** | 不自动重启 (默认) | `--restart no` |
| **always** | 始终重启 | `--restart always` |
| **on-failure** | 仅失败时重启 | `--restart on-failure[:max]` |
| **unless-stopped** | 除非手动停止 | `--restart unless-stopped` |

### 策略对比

| 场景 | no | always | on-failure | unless-stopped |
|:---|:---:|:---:|:---:|:---:|
| 正常退出 (exit 0) | ✗ | ✓ | ✗ | ✓ |
| 异常退出 (exit non-0) | ✗ | ✓ | ✓ | ✓ |
| Docker daemon 重启 | ✗ | ✓ | ✓ | ✓ |
| 手动 docker stop 后 daemon 重启 | ✗ | ✓ | ✗ | ✗ |

### 使用示例

```bash
# 基本配置
docker run -d --restart unless-stopped nginx

# 限制重启次数
docker run -d --restart on-failure:5 myapp

# 修改已运行容器的重启策略
docker update --restart unless-stopped container_name

# 查看重启次数
docker inspect --format='{{.RestartCount}}' container_name
```

### 重启延迟

Docker 使用指数退避算法：
- 首次等待 100ms
- 每次翻倍：100ms → 200ms → 400ms → ...
- 最大等待 1 分钟
- 容器运行超过 10 秒后重置计数

---

## 容器监控与调试

### 资源监控

```bash
# 实时资源统计
docker stats

# 单个容器统计 (非流式)
docker stats --no-stream container_name

# 格式化输出
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# JSON 输出
docker stats --format '{{json .}}'
```

### 容器内进程

```bash
# 查看进程
docker top container_name

# 详细进程信息
docker top container_name -aux

# 使用 ps 格式
docker top container_name -o pid,ppid,user,cmd
```

### 调试技术

```bash
# 进入运行中的容器
docker exec -it container_name /bin/sh

# 以 root 进入
docker exec -u root -it container_name /bin/bash

# 设置环境变量
docker exec -e DEBUG=true -it container_name /bin/sh

# 在容器外执行命令
docker exec container_name ls -la /app

# 文件传输
docker cp container_name:/app/logs/app.log ./
docker cp ./config.json container_name:/app/config/
```

### 调试镜像

```bash
# 使用调试镜像
docker run --rm -it --network container:myapp nicolaka/netshoot

# 挂载容器文件系统
docker run --rm -it --volumes-from container_name alpine sh

# 使用 docker debug (Docker 25+)
docker debug container_name

# 创建调试容器进入同一 namespace
docker run --rm -it \
  --pid container:myapp \
  --network container:myapp \
  busybox
```

### 事件监控

```bash
# 监听所有事件
docker events

# 过滤特定容器
docker events --filter 'container=myapp'

# 过滤事件类型
docker events --filter 'event=start' --filter 'event=stop'

# 时间范围
docker events --since '2024-01-01' --until '2024-01-02'

# JSON 格式
docker events --format '{{json .}}'
```

### 容器 diff

```bash
# 查看文件系统变化
docker diff container_name

# 输出说明:
# A = 添加的文件
# C = 修改的文件
# D = 删除的文件
```

---

## 相关文档

- [200-docker-architecture-overview](./200-docker-architecture-overview.md) - Docker 架构
- [201-docker-images-management](./201-docker-images-management.md) - 镜像管理
- [203-docker-networking-deep-dive](./203-docker-networking-deep-dive.md) - Docker 网络
- [204-docker-storage-volumes](./204-docker-storage-volumes.md) - Docker 存储
- [207-docker-troubleshooting-guide](./207-docker-troubleshooting-guide.md) - 故障排查
