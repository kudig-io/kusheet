# 表格74: 容器生命周期钩子

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/containers/container-lifecycle-hooks](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/)

## 生命周期钩子类型

| 钩子 | 触发时机 | 用途 |
|-----|---------|------|
| PostStart | 容器创建后立即执行 | 初始化任务 |
| PreStop | 容器终止前执行 | 清理任务 |

## 钩子执行方式

| 方式 | 说明 | 示例场景 |
|-----|------|---------|
| exec | 执行命令 | 运行脚本 |
| httpGet | HTTP GET请求 | 通知外部服务 |
| tcpSocket | TCP连接检查 | 端口检查(v1.25+) |
| sleep | 休眠等待 | 简单延迟(v1.29+) |

## 生命周期配置示例

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: lifecycle-demo
spec:
  containers:
  - name: app
    image: myapp:v1
    lifecycle:
      postStart:
        exec:
          command:
          - /bin/sh
          - -c
          - |
            echo "Starting application..."
            /scripts/init.sh
      preStop:
        exec:
          command:
          - /bin/sh
          - -c
          - |
            echo "Graceful shutdown..."
            /scripts/cleanup.sh
            sleep 5
```

## HTTP钩子配置

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: http-hook-demo
spec:
  containers:
  - name: app
    image: myapp:v1
    ports:
    - containerPort: 8080
    lifecycle:
      postStart:
        httpGet:
          path: /api/init
          port: 8080
          scheme: HTTP
      preStop:
        httpGet:
          path: /api/shutdown
          port: 8080
          httpHeaders:
          - name: X-Shutdown-Reason
            value: "Container terminating"
```

## Sleep钩子(v1.29+)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sleep-hook-demo
spec:
  containers:
  - name: app
    image: myapp:v1
    lifecycle:
      preStop:
        sleep:
          seconds: 10
```

## 优雅终止流程

| 步骤 | 操作 | 说明 |
|-----|------|------|
| 1 | 标记Terminating | Pod状态更新 |
| 2 | 执行PreStop钩子 | 并行执行 |
| 3 | 发送SIGTERM | 通知主进程 |
| 4 | 等待terminationGracePeriodSeconds | 默认30s |
| 5 | 发送SIGKILL | 强制终止 |

## 优雅终止配置

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: graceful-shutdown
spec:
  terminationGracePeriodSeconds: 60  # 优雅终止总时间
  containers:
  - name: app
    image: myapp:v1
    lifecycle:
      preStop:
        exec:
          command:
          - /bin/sh
          - -c
          - |
            # 从负载均衡器移除
            curl -X DELETE http://lb-controller/deregister
            # 等待连接排空
            sleep 10
            # 通知应用关闭
            kill -SIGTERM 1
```

## 钩子执行注意事项

| 注意点 | 说明 |
|-------|------|
| 阻塞性 | PostStart阻塞时容器不会标记为Running |
| 超时 | 受terminationGracePeriodSeconds限制 |
| 重试 | 失败不重试 |
| 并发 | PreStop和SIGTERM可能并发 |
| 日志 | 钩子输出不记录到容器日志 |

## 常见PostStart用例

```yaml
# 1. 等待依赖服务
postStart:
  exec:
    command:
    - /bin/sh
    - -c
    - |
      until nc -z database 5432; do
        echo "Waiting for database..."
        sleep 1
      done

# 2. 注册到服务发现
postStart:
  httpGet:
    path: /register
    port: 8500

# 3. 初始化配置
postStart:
  exec:
    command: ["/scripts/setup-config.sh"]
```

## 常见PreStop用例

```yaml
# 1. 优雅关闭(等待请求完成)
preStop:
  exec:
    command:
    - /bin/sh
    - -c
    - |
      # 停止接收新请求
      touch /tmp/shutdown
      # 等待现有请求完成
      sleep 15

# 2. 从服务发现注销
preStop:
  httpGet:
    path: /deregister
    port: 8500

# 3. 数据持久化
preStop:
  exec:
    command:
    - /bin/sh
    - -c
    - |
      redis-cli bgsave
      sleep 5

# 4. Nginx优雅重载
preStop:
  exec:
    command:
    - /bin/sh
    - -c
    - |
      nginx -s quit
      while pgrep nginx; do sleep 1; done
```

## 与探针配合

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    image: myapp:v1
    # 存活探针
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 30
    # 就绪探针
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 5
    # 启动探针(慢启动应用)
    startupProbe:
      httpGet:
        path: /startup
        port: 8080
      failureThreshold: 30
      periodSeconds: 10
    # 生命周期钩子
    lifecycle:
      preStop:
        exec:
          command: ["/scripts/graceful-shutdown.sh"]
```

## 调试钩子执行

```bash
# 查看事件
kubectl describe pod <pod-name>

# 查看容器状态
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].state}'

# 检查终止原因
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].lastState}'
```

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| v1.25 | tcpSocket钩子支持 |
| v1.29 | sleep钩子GA |
| v1.30 | 钩子超时配置改进 |
