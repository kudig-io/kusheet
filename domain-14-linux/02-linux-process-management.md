# 02 - Linux 进程管理与系统监控：生产环境运维专家实践

> **适用版本**: Linux Kernel 5.x/6.x | **最后更新**: 2026-02 | **作者**: Allen Galler (allengaller@gmail.com)

---

## 摘要

本文档从生产环境运维专家视角，深入讲解 Linux 进程管理、系统监控和性能分析的核心技能。涵盖进程生命周期管理、资源监控、性能瓶颈诊断、自动化运维等关键内容，为构建高可用、高性能的生产系统提供实战指导。

**核心价值**：
- 🔄 **进程生命周期管理**：生产环境进程创建、监控、终止的最佳实践
- 📊 **系统性能监控**：实时监控、历史数据分析、趋势预测
- 🔍 **故障诊断技巧**：快速定位和解决进程相关问题
- 🛠️ **自动化运维工具**：批量化管理脚本和监控告警配置
- 📈 **容量规划方法**：基于历史数据的资源规划和扩容决策

---

## 目录

- [进程基础概念](#进程基础概念)
- [进程生命周期](#进程生命周期)
- [进程管理命令](#进程管理命令)
- [信号与进程控制](#信号与进程控制)
- [进程优先级](#进程优先级)
- [作业控制](#作业控制)
- [进程监控分析](#进程监控分析)

---

## 进程基础概念

### 进程与线程

| 概念 | 说明 | 特点 |
|:---|:---|:---|
| **进程** | 程序执行实例 | 独立地址空间、资源 |
| **线程** | 进程内执行单元 | 共享进程资源 |
| **PID** | 进程标识符 | 唯一标识 |
| **PPID** | 父进程 ID | 创建者进程 |
| **PGID** | 进程组 ID | 作业控制 |
| **SID** | 会话 ID | 终端会话 |

### 进程类型

| 类型 | 说明 | 示例 |
|:---|:---|:---|
| **前台进程** | 占用终端 | 交互式命令 |
| **后台进程** | 不占用终端 | `command &` |
| **守护进程** | 系统后台服务 | sshd, nginx |
| **僵尸进程** | 已终止未回收 | Z 状态 |
| **孤儿进程** | 父进程已终止 | 被 init 收养 |

---

## 进程生命周期

### 状态机

```
          fork()              调度运行
┌───────┐ ────► ┌───────────┐ ────► ┌───────────┐
│ 不存在 │       │ 就绪 (R)   │ ◄──── │ 运行 (R)  │
└───────┘       └───────────┘ 时间片  └─────┬─────┘
                     ▲                     │
                     │                     │ I/O、信号
                     │ I/O 完成            ▼
                     │               ┌───────────┐
                     └────────────── │ 睡眠 (S/D) │
                                     └─────┬─────┘
                                           │ exit()
                                           ▼
                                     ┌───────────┐
                                     │ 僵尸 (Z)   │
                                     └─────┬─────┘
                                           │ wait()
                                           ▼
                                     ┌───────────┐
                                     │ 终止      │
                                     └───────────┘
```

### 进程状态

| 状态码 | 名称 | 说明 |
|:---:|:---|:---|
| **R** | Running | 运行中或就绪 |
| **S** | Sleeping | 可中断睡眠 |
| **D** | Disk Sleep | 不可中断睡眠 (I/O) |
| **T** | Stopped | 已停止 |
| **Z** | Zombie | 僵尸进程 |
| **I** | Idle | 空闲内核线程 |

---

## 进程管理命令

### ps 命令

```bash
# 标准格式
ps aux                    # BSD 风格
ps -ef                    # System V 风格

# 显示进程树
ps -ejH
ps axjf

# 自定义输出
ps -eo pid,ppid,user,%cpu,%mem,stat,cmd --sort=-%cpu

# 查找进程
ps aux | grep nginx
```

### ps 输出字段

| 字段 | 说明 |
|:---|:---|
| PID | 进程 ID |
| PPID | 父进程 ID |
| USER | 用户 |
| %CPU | CPU 使用率 |
| %MEM | 内存使用率 |
| VSZ | 虚拟内存 |
| RSS | 物理内存 |
| STAT | 状态 |
| START | 启动时间 |
| TIME | CPU 时间 |
| CMD | 命令 |

### top / htop

```bash
# top 常用快捷键
# P - 按 CPU 排序
# M - 按内存排序
# k - 杀死进程
# q - 退出

# 批处理模式
top -bn1 | head -20

# htop (推荐)
htop -u username    # 按用户过滤
```

### 进程查找与终止

```bash
# 查找进程
pgrep nginx
pgrep -u root

# 终止进程
kill <pid>           # SIGTERM
kill -9 <pid>        # SIGKILL
kill -HUP <pid>      # 重载配置

# 按名称终止
pkill nginx
killall nginx
```

---

## 信号与进程控制

### 常用信号

| 信号 | 编号 | 说明 | 默认动作 |
|:---|:---:|:---|:---|
| **SIGHUP** | 1 | 终端挂起 | 终止 |
| **SIGINT** | 2 | 中断 (Ctrl+C) | 终止 |
| **SIGQUIT** | 3 | 退出 (Ctrl+\) | 终止+core |
| **SIGKILL** | 9 | 强制终止 | 终止 (不可捕获) |
| **SIGTERM** | 15 | 终止请求 | 终止 |
| **SIGSTOP** | 19 | 停止 | 停止 (不可捕获) |
| **SIGCONT** | 18 | 继续 | 继续执行 |
| **SIGUSR1** | 10 | 用户自定义 | 终止 |
| **SIGUSR2** | 12 | 用户自定义 | 终止 |

### 信号发送

```bash
# 发送信号
kill -<signal> <pid>
kill -SIGTERM 1234
kill -15 1234

# 列出所有信号
kill -l

# 批量发送
pkill -<signal> <pattern>
killall -<signal> <name>
```

---

## 进程优先级

### nice 值

| nice 值 | 优先级 | 说明 |
|:---:|:---:|:---|
| -20 | 最高 | 需要 root |
| 0 | 默认 | 普通进程 |
| 19 | 最低 | 后台任务 |

### 调整优先级

```bash
# 启动时设置
nice -n 10 command

# 调整运行进程
renice 10 -p <pid>
renice -n 5 -u username
```

### 实时优先级

```bash
# 设置实时优先级 (需要 root)
chrt -f 50 command     # FIFO
chrt -r 50 command     # Round-Robin

# 查看调度策略
chrt -p <pid>
```

---

## 作业控制

### 后台运行

```bash
# 后台启动
command &

# 挂起到后台
# Ctrl+Z

# 查看作业
jobs

# 后台继续
bg %1

# 前台继续
fg %1

# 终止作业
kill %1
```

### nohup 与 disown

```bash
# 忽略 SIGHUP
nohup command &

# 从 shell 分离
disown -h %1

# 完全后台化
nohup command > /dev/null 2>&1 &
```

### screen / tmux

```bash
# screen
screen -S session_name     # 创建会话
screen -r session_name     # 恢复会话
# Ctrl+a d 分离

# tmux
tmux new -s session_name   # 创建
tmux attach -t session_name # 恢复
# Ctrl+b d 分离
```

---

## 进程监控分析

### 资源监控

```bash
# 实时监控
top
htop
atop

# 系统负载
uptime
w

# CPU 统计
mpstat -P ALL 1

# 内存统计
free -h
vmstat 1
```

### 进程分析

```bash
# 查看进程文件描述符
ls -la /proc/<pid>/fd
lsof -p <pid>

# 查看进程内存映射
cat /proc/<pid>/maps
pmap <pid>

# 查看进程限制
cat /proc/<pid>/limits

# 查看进程环境
cat /proc/<pid>/environ | tr '\0' '\n'
```

### 性能分析

```bash
# strace - 系统调用追踪
strace -p <pid>
strace -c command      # 统计

# ltrace - 库调用追踪
ltrace -p <pid>

# perf - 性能分析
perf top
perf stat command
perf record command
perf report
```

### 僵尸进程处理

```bash
# 查找僵尸进程
ps aux | awk '$8=="Z"'
ps -eo pid,ppid,stat,cmd | grep Z

# 查找父进程
ps -o ppid= -p <zombie_pid>

# 处理方法
# 1. 终止父进程
# 2. 父进程调用 wait()
```

---

## 相关文档

- [210-linux-system-architecture](./210-linux-system-architecture.md) - 系统架构
- [215-linux-performance-tuning](./215-linux-performance-tuning.md) - 性能调优
- [217-linux-container-fundamentals](./217-linux-container-fundamentals.md) - 容器基础
