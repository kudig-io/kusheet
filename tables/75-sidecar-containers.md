# 表格75: Sidecar容器模式

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/workloads/pods/sidecar-containers](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/)

## Sidecar容器类型(v1.28+)

| 类型 | 特点 | 用途 |
|-----|------|------|
| 原生Sidecar | restartPolicy: Always | 辅助服务 |
| Init容器 | 顺序启动,完成后退出 | 初始化 |
| 普通容器 | 与主容器并行 | 传统方式 |

## 原生Sidecar配置(v1.28+)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: native-sidecar
spec:
  initContainers:
  # 原生Sidecar容器(不会阻塞主容器启动)
  - name: log-collector
    image: fluent-bit:latest
    restartPolicy: Always  # 关键配置,标识为Sidecar
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  - name: proxy
    image: envoy:latest
    restartPolicy: Always
    ports:
    - containerPort: 15001
  containers:
  - name: app
    image: myapp:v1
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  volumes:
  - name: logs
    emptyDir: {}
```

## Sidecar启动顺序

| 阶段 | v1.28之前 | v1.28+ 原生Sidecar |
|-----|----------|-------------------|
| 1 | Init容器顺序启动 | Init容器顺序启动 |
| 2 | Init完成后主容器启动 | Sidecar启动(不等待完成) |
| 3 | - | 主容器启动 |
| 4 | Pod终止时同时停止 | Sidecar在主容器后停止 |

## 传统Sidecar模式

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: traditional-sidecar
spec:
  containers:
  # 主应用
  - name: app
    image: myapp:v1
    ports:
    - containerPort: 8080
    volumeMounts:
    - name: shared-data
      mountPath: /data
  # Sidecar: 日志收集
  - name: log-shipper
    image: fluent-bit:latest
    volumeMounts:
    - name: shared-data
      mountPath: /data
  # Sidecar: 代理
  - name: proxy
    image: envoy:latest
    ports:
    - containerPort: 15001
  volumes:
  - name: shared-data
    emptyDir: {}
```

## 常见Sidecar用例

| 用例 | Sidecar | 功能 |
|-----|---------|------|
| 日志收集 | Fluent Bit/Filebeat | 收集转发日志 |
| 服务网格 | Envoy/Istio Proxy | 流量管理 |
| 监控代理 | Prometheus Exporter | 暴露指标 |
| 配置刷新 | ConfigMap Reloader | 配置热更新 |
| 安全代理 | Vault Agent | Secret注入 |
| 调试工具 | tcpdump/strace | 网络/进程调试 |

## 日志收集Sidecar

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: logging-sidecar
spec:
  initContainers:
  - name: fluent-bit
    image: fluent/fluent-bit:latest
    restartPolicy: Always
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
    - name: fluent-config
      mountPath: /fluent-bit/etc
  containers:
  - name: app
    image: myapp:v1
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  volumes:
  - name: logs
    emptyDir: {}
  - name: fluent-config
    configMap:
      name: fluent-bit-config
```

## Vault Agent Sidecar

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: vault-sidecar
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/agent-inject-secret-db-creds: "database/creds/myapp"
    vault.hashicorp.com/role: "myapp"
spec:
  serviceAccountName: myapp
  containers:
  - name: app
    image: myapp:v1
    volumeMounts:
    - name: vault-secrets
      mountPath: /vault/secrets
```

## Envoy Sidecar(手动注入)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: envoy-sidecar
spec:
  initContainers:
  - name: envoy
    image: envoyproxy/envoy:v1.28.0
    restartPolicy: Always
    ports:
    - containerPort: 15001
      name: envoy-outbound
    - containerPort: 15006
      name: envoy-inbound
    - containerPort: 15090
      name: envoy-stats
    volumeMounts:
    - name: envoy-config
      mountPath: /etc/envoy
  containers:
  - name: app
    image: myapp:v1
    ports:
    - containerPort: 8080
  volumes:
  - name: envoy-config
    configMap:
      name: envoy-config
```

## Sidecar资源配置

```yaml
# Sidecar资源建议
initContainers:
- name: sidecar
  image: sidecar:latest
  restartPolicy: Always
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 256Mi
```

## Sidecar与主容器通信

| 方式 | 说明 | 示例 |
|-----|------|------|
| 共享Volume | emptyDir | 日志文件 |
| localhost | 127.0.0.1 | TCP/HTTP通信 |
| Unix Socket | 共享Volume中的socket | 高性能通信 |
| 环境变量 | Downward API | 配置传递 |

## 监控Sidecar状态

```bash
# 查看所有容器状态
kubectl get pod <pod-name> -o jsonpath='{.status.initContainerStatuses[*].name}'

# 查看Sidecar日志
kubectl logs <pod-name> -c <sidecar-name>

# 检查Sidecar就绪状态
kubectl get pod <pod-name> -o jsonpath='{.status.initContainerStatuses[*].ready}'
```

## ACK Sidecar支持

| 功能 | 说明 |
|-----|------|
| ASM Sidecar | Istio代理自动注入 |
| ARMS Agent | 可观测性Agent |
| Logtail | 日志采集Sidecar |

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| v1.28 | 原生Sidecar容器Alpha |
| v1.29 | 原生Sidecar容器Beta |
| v1.30 | Sidecar启动顺序改进 |
| v1.31 | 原生Sidecar GA准备 |
