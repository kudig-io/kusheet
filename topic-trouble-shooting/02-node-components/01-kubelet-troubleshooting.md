# kubelet 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 高级

---

## 目录

1. [问题现象与影响分析](#1-问题现象与影响分析)
2. [排查方法与步骤](#2-排查方法与步骤)
3. [解决方案与风险控制](#3-解决方案与风险控制)

---

## 1. 问题现象与影响分析

### 1.1 常见问题现象

#### 1.1.1 kubelet 服务不可用

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 进程未运行 | `kubelet.service: Failed` | systemd | `systemctl status kubelet` |
| 启动失败 | `failed to run kubelet` | kubelet 日志 | `journalctl -u kubelet` |
| 证书错误 | `x509: certificate has expired` | kubelet 日志 | kubelet 日志 |
| 配置错误 | `failed to load kubelet config` | kubelet 日志 | kubelet 启动日志 |
| API Server 连接失败 | `unable to connect to API server` | kubelet 日志 | kubelet 日志 |

#### 1.1.2 节点状态异常

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 节点 NotReady | `KubeletNotReady` | kubectl | `kubectl get nodes` |
| 节点 Unknown | `NodeStatusUnknown` | kubectl | `kubectl get nodes` |
| 节点压力 | `MemoryPressure/DiskPressure/PIDPressure` | kubectl | `kubectl describe node` |
| 容器运行时不可用 | `container runtime is down` | kubelet 日志 | kubelet 日志 |

#### 1.1.3 Pod 管理问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| Pod 无法创建 | `failed to create pod` | Pod Events | `kubectl describe pod` |
| Pod 无法启动 | `failed to start container` | Pod Events | `kubectl describe pod` |
| 镜像拉取失败 | `ImagePullBackOff/ErrImagePull` | Pod Events | `kubectl describe pod` |
| 探针失败 | `Liveness/Readiness probe failed` | Pod Events | `kubectl describe pod` |
| Pod 被驱逐 | `The node was low on resource` | Pod Events | `kubectl describe pod` |
| CSI 卷挂载失败 | `MountVolume.SetUp failed` | Pod Events | `kubectl describe pod` |

#### 1.1.4 资源相关问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 磁盘空间不足 | `DiskPressure` | 节点状态 | `kubectl describe node` |
| 内存不足 | `MemoryPressure` | 节点状态 | `kubectl describe node` |
| PID 耗尽 | `PIDPressure` | 节点状态 | `kubectl describe node` |
| inode 耗尽 | `inodes exhausted` | kubelet 日志 | kubelet 日志 |
| cgroup 配置错误 | `cgroup driver mismatch` | kubelet 日志 | kubelet 日志 |

### 1.2 报错查看方式汇总

```bash
# 查看 kubelet 服务状态
systemctl status kubelet

# 查看 kubelet 日志
journalctl -u kubelet -f --no-pager -l

# 查看最近的错误日志
journalctl -u kubelet -p err --since "1 hour ago"

# 查看节点状态
kubectl get nodes
kubectl describe node <node-name>

# 查看节点条件
kubectl get node <node-name> -o jsonpath='{.status.conditions[*]}' | jq

# 查看节点事件
kubectl get events --field-selector=involvedObject.kind=Node

# 检查 kubelet 健康状态
curl -k https://localhost:10250/healthz

# 查看 kubelet 指标
curl -k https://localhost:10250/metrics

# 查看 Pod 列表（kubelet API）
curl -k https://localhost:10250/pods
```

### 1.3 影响面分析

#### 1.3.1 直接影响

| 影响范围 | 影响程度 | 影响描述 |
|----------|----------|----------|
| **该节点所有 Pod** | 高 | Pod 状态无法更新，新 Pod 无法创建 |
| **节点状态报告** | 完全失效 | 节点状态无法上报给 API Server |
| **容器生命周期** | 失效 | 容器无法创建、启动、停止 |
| **健康检查** | 失效 | 探针检查无法执行 |
| **日志采集** | 部分影响 | kubelet 日志 API 不可用 |
| **指标采集** | 部分影响 | kubelet 指标 API 不可用 |

#### 1.3.2 间接影响

| 影响范围 | 影响程度 | 影响描述 |
|----------|----------|----------|
| **已运行的容器** | 容器继续运行 | 但无法被管理和监控 |
| **服务发现** | 部分影响 | Endpoints 可能过期 |
| **调度** | 受影响 | 新 Pod 可能被调度到异常节点 |
| **节点驱逐** | 触发 | 节点长时间 NotReady 会触发 Pod 驱逐 |
| **监控告警** | 可能失效 | 节点级监控数据缺失 |

#### 1.3.3 故障传播链

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         kubelet 故障影响传播链                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   kubelet 故障                                                               │
│       │                                                                      │
│       ├──► 节点状态无法上报 ──► 节点变为 NotReady                            │
│       │                              │                                       │
│       │                              └──► 触发 Node Controller                │
│       │                                        │                             │
│       │                                        └──► 超时后驱逐 Pod            │
│       │                                                                      │
│       ├──► Pod 状态无法更新 ──► Pod 状态显示为旧状态                         │
│       │                                                                      │
│       ├──► 新 Pod 无法创建 ──► 该节点上新调度的 Pod 卡在 Pending             │
│       │                                                                      │
│       ├──► 容器运行时交互失败 ──► 容器无法创建/删除                          │
│       │                                                                      │
│       ├──► 健康检查停止 ──► 已有 Pod 状态可能不准确                          │
│       │                                                                      │
│       └──► 卷管理失效 ──► 卷挂载/卸载失败                                    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 排查方法与步骤

### 2.1 排查原理

kubelet 是节点上的核心代理，负责 Pod 生命周期管理。排查需要从以下层面：

1. **服务层面**：kubelet 进程是否正常运行
2. **连接层面**：与 API Server、容器运行时的连接
3. **配置层面**：kubelet 配置是否正确
4. **资源层面**：节点资源是否充足
5. **证书层面**：证书是否有效

### 2.2 排查逻辑决策树

```
开始排查
    │
    ├─► 检查 kubelet 进程
    │       │
    │       ├─► 进程不存在 ──► 检查启动失败原因
    │       │
    │       └─► 进程存在 ──► 继续下一步
    │
    ├─► 检查容器运行时
    │       │
    │       ├─► 运行时故障 ──► 排查容器运行时
    │       │
    │       └─► 运行时正常 ──► 继续下一步
    │
    ├─► 检查 API Server 连接
    │       │
    │       ├─► 连接失败 ──► 检查网络和证书
    │       │
    │       └─► 连接正常 ──► 继续下一步
    │
    ├─► 检查节点资源
    │       │
    │       ├─► 资源不足 ──► 清理资源或扩容
    │       │
    │       └─► 资源充足 ──► 继续下一步
    │
    └─► 检查具体错误
            │
            ├─► Pod 创建失败 ──► 分析 Pod Events
            │
            └─► 其他错误 ──► 根据日志分析
```

### 2.3 排查步骤和具体命令

#### 2.3.1 第一步：检查 kubelet 进程状态

```bash
# 检查 kubelet 服务状态
systemctl status kubelet

# 检查进程是否存在
ps aux | grep kubelet | grep -v grep

# 查看启动参数
cat /proc/$(pgrep kubelet)/cmdline | tr '\0' '\n'

# 检查 kubelet 配置文件
cat /var/lib/kubelet/config.yaml

# 查看 kubelet 启动配置
cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# 检查健康端点
curl -k https://localhost:10250/healthz

# 查看 kubelet 版本
kubelet --version
```

#### 2.3.2 第二步：检查容器运行时

```bash
# 检查 containerd 状态
systemctl status containerd

# 检查 Docker 状态（如果使用 Docker）
systemctl status docker

# 使用 crictl 检查运行时
crictl info

# 列出所有容器
crictl ps -a

# 检查容器运行时 socket
ls -la /run/containerd/containerd.sock
# 或
ls -la /var/run/cri-dockerd.sock

# 测试容器运行时连接
crictl version
```

#### 2.3.3 第三步：检查 API Server 连接

```bash
# 检查 kubelet 证书
ls -la /var/lib/kubelet/pki/

# 检查证书有效期
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates

# 测试 API Server 连接
kubectl --kubeconfig=/etc/kubernetes/kubelet.conf get nodes

# 查看 kubelet 日志中的连接错误
journalctl -u kubelet | grep -iE "(unable to connect|connection refused)" | tail -20

# 检查 API Server 地址配置
grep server /etc/kubernetes/kubelet.conf
```

#### 2.3.4 第四步：检查节点资源

```bash
# 检查磁盘空间
df -h
df -i  # inode 使用

# 检查内存
free -h

# 检查 PID 数量
ls /proc | grep -E "^[0-9]+$" | wc -l
cat /proc/sys/kernel/pid_max

# 检查容器镜像占用
crictl images
du -sh /var/lib/containerd/
du -sh /var/lib/docker/  # 如果使用 Docker

# 检查日志占用
du -sh /var/log/

# 检查节点压力
kubectl describe node $(hostname) | grep -A5 Conditions
```

#### 2.3.5 第五步：检查 cgroup 配置

```bash
# 检查 kubelet cgroup 驱动配置
cat /var/lib/kubelet/config.yaml | grep cgroupDriver

# 检查容器运行时 cgroup 驱动
# containerd
cat /etc/containerd/config.toml | grep SystemdCgroup

# Docker
docker info | grep "Cgroup Driver"

# 检查系统 cgroup 版本
mount | grep cgroup
cat /sys/fs/cgroup/cgroup.controllers  # cgroup v2
```

#### 2.3.6 第六步：检查 Pod 相关问题

```bash
# 查看节点上的 Pod 列表
kubectl get pods --all-namespaces --field-selector=spec.nodeName=$(hostname)

# 查看 Pod Events
kubectl get events --field-selector=involvedObject.kind=Pod --sort-by='.lastTimestamp'

# 检查特定 Pod 详情
kubectl describe pod <pod-name> -n <namespace>

# 查看 Pod 日志
kubectl logs <pod-name> -n <namespace>

# 通过 kubelet API 查看 Pod
curl -k https://localhost:10250/pods | jq '.items[].metadata.name'

# 检查静态 Pod 目录
ls -la /etc/kubernetes/manifests/
```

#### 2.3.7 第七步：检查日志

```bash
# 实时查看 kubelet 日志
journalctl -u kubelet -f --no-pager

# 查看最近错误
journalctl -u kubelet -p err --since "30 minutes ago"

# 查看启动日志
journalctl -u kubelet -b | head -100

# 查找特定错误
journalctl -u kubelet | grep -iE "(error|failed|unable)" | tail -50

# 查找镜像相关错误
journalctl -u kubelet | grep -i "image" | tail -30

# 查找卷相关错误
journalctl -u kubelet | grep -i "volume" | tail -30

# 查找探针相关错误
journalctl -u kubelet | grep -i "probe" | tail -30
```

### 2.4 排查注意事项

#### 2.4.1 安全注意事项

| 注意项 | 说明 | 建议 |
|--------|------|------|
| **kubelet 证书** | 包含节点认证信息 | 不要泄露 |
| **kubeconfig** | 有节点权限 | 妥善保管 |
| **kubelet API** | 可以访问 Pod 信息 | 限制访问 |
| **日志敏感性** | 可能包含敏感信息 | 注意分享范围 |

#### 2.4.2 操作注意事项

| 注意项 | 说明 | 建议 |
|--------|------|------|
| **重启影响** | 重启 kubelet 会影响 Pod 管理 | 在维护窗口操作 |
| **容器运行时依赖** | kubelet 依赖容器运行时 | 先检查运行时 |
| **静态 Pod** | 静态 Pod 由 kubelet 直接管理 | 修改 manifest 需谨慎 |
| **驱逐时间** | kubelet 长时间不可用会触发驱逐 | 尽快恢复 |

---

## 3. 解决方案与风险控制

### 3.1 kubelet 进程未运行

#### 3.1.1 解决步骤

```bash
# 步骤 1：检查启动失败原因
journalctl -u kubelet -b --no-pager | tail -100

# 步骤 2：检查配置文件
cat /var/lib/kubelet/config.yaml

# 步骤 3：验证配置语法
kubelet --config=/var/lib/kubelet/config.yaml --dry-run

# 步骤 4：检查依赖服务
systemctl status containerd
# 或
systemctl status docker

# 步骤 5：修复问题后重启
systemctl daemon-reload
systemctl restart kubelet

# 步骤 6：验证恢复
systemctl status kubelet
kubectl get node $(hostname)
```

#### 3.1.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 重启期间 Pod 管理中断 | 在维护窗口操作 |
| **低** | 配置检查一般无风险 | - |
| **中** | 配置修改可能引入新问题 | 修改前备份 |

#### 3.1.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. kubelet 重启期间节点上的 Pod 管理暂停
2. 已运行的容器不会被停止
3. 长时间故障会触发 Pod 驱逐
4. 修改配置前备份原始文件
5. 确保容器运行时正常后再重启 kubelet
```

### 3.2 节点 NotReady

#### 3.2.1 解决步骤

```bash
# 步骤 1：确认节点状态
kubectl get node $(hostname) -o wide
kubectl describe node $(hostname) | grep -A10 Conditions

# 步骤 2：检查 kubelet 状态
systemctl status kubelet
journalctl -u kubelet --since "10 minutes ago" | tail -50

# 步骤 3：检查容器运行时
systemctl status containerd
crictl info

# 步骤 4：检查网络连接
ping -c 3 <api-server-ip>
curl -k https://<api-server-ip>:6443/healthz

# 步骤 5：如果是证书问题，续签证书
kubeadm certs renew kubelet-client

# 步骤 6：重启 kubelet
systemctl restart kubelet

# 步骤 7：验证恢复
kubectl get node $(hostname)
```

#### 3.2.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | NotReady 持续可能触发驱逐 | 尽快恢复 |
| **低** | 检查状态无风险 | - |
| **中** | 证书续签需要重启 | 在维护窗口操作 |

#### 3.2.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 节点 NotReady 超过 pod-eviction-timeout 会触发驱逐
2. 默认驱逐超时为 5 分钟
3. 先排除网络问题再考虑重启
4. 证书续签会短暂中断连接
5. 监控节点状态恢复时间
```

### 3.3 节点资源压力（DiskPressure/MemoryPressure/PIDPressure）

#### 3.3.1 解决步骤

```bash
# 步骤 1：确认压力类型
kubectl describe node $(hostname) | grep -A10 Conditions

# DiskPressure 解决方案
# 步骤 2a：清理无用镜像
crictl rmi --prune

# 步骤 3a：清理已退出的容器
crictl rm $(crictl ps -a -q --state exited)

# 步骤 4a：清理日志
find /var/log -type f -name "*.log" -mtime +7 -delete
journalctl --vacuum-time=3d

# 步骤 5a：检查大文件
du -sh /* | sort -rh | head -10

# MemoryPressure 解决方案
# 步骤 2b：查找内存占用高的进程
ps aux --sort=-%mem | head -20

# 步骤 3b：查找内存占用高的 Pod
kubectl top pods --all-namespaces --sort-by=memory

# 步骤 4b：考虑驱逐低优先级 Pod
kubectl delete pod <low-priority-pod> -n <namespace>

# PIDPressure 解决方案
# 步骤 2c：查找 PID 占用多的进程
ps -eo pid,ppid,cmd | wc -l
for pid in $(ls /proc | grep -E "^[0-9]+$"); do
  threads=$(ls /proc/$pid/task 2>/dev/null | wc -l)
  if [ "$threads" -gt 100 ]; then
    echo "PID $pid: $threads threads"
  fi
done

# 步骤 3c：增加 PID 限制
echo 65536 > /proc/sys/kernel/pid_max

# 验证恢复
kubectl describe node $(hostname) | grep -A10 Conditions
```

#### 3.3.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 清理镜像可能影响 Pod 启动 | 只清理未使用的镜像 |
| **中** | 删除 Pod 会影响服务 | 优先删除非关键 Pod |
| **低** | 清理日志一般无风险 | 保留最近的日志 |

#### 3.3.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 节点压力会触发 Pod 驱逐
2. 清理前确认不会影响正在运行的服务
3. 增加 PID 限制需要评估系统承载能力
4. 考虑配置节点资源预留（system-reserved）
5. 长期方案是增加节点资源或分散负载
```

### 3.4 镜像拉取失败

#### 3.4.1 解决步骤

```bash
# 步骤 1：确认错误类型
kubectl describe pod <pod-name> | grep -A5 "Events:"

# 常见错误类型：
# - ImagePullBackOff: 多次拉取失败后的退避状态
# - ErrImagePull: 拉取失败
# - ErrImageNeverPull: imagePullPolicy=Never 但本地无镜像

# 步骤 2：测试镜像拉取
crictl pull <image-name>

# 步骤 3：检查镜像仓库认证
kubectl get secret -n <namespace> | grep -i registry
kubectl get pod <pod-name> -o yaml | grep -A5 imagePullSecrets

# 步骤 4：检查镜像仓库连通性
curl -v https://<registry-url>/v2/

# 步骤 5：如果是私有仓库认证问题，创建 Secret
kubectl create secret docker-registry regcred \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email> \
  -n <namespace>

# 步骤 6：更新 Pod 使用 imagePullSecrets
kubectl patch serviceaccount default -n <namespace> \
  -p '{"imagePullSecrets": [{"name": "regcred"}]}'

# 步骤 7：重新创建 Pod
kubectl delete pod <pod-name> -n <namespace>
```

#### 3.4.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **低** | 创建 Secret 无风险 | - |
| **中** | 删除 Pod 会导致服务中断 | 确保有副本或在维护窗口 |
| **低** | 测试拉取无风险 | - |

#### 3.4.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 镜像仓库凭证是敏感信息
2. 不要在命令历史中留下密码
3. 优先使用 ServiceAccount 绑定 imagePullSecrets
4. 考虑使用镜像缓存或镜像仓库代理
5. 检查网络策略是否阻止了镜像拉取
```

### 3.5 探针失败

#### 3.5.1 解决步骤

```bash
# 步骤 1：确认探针配置
kubectl get pod <pod-name> -o yaml | grep -A20 livenessProbe
kubectl get pod <pod-name> -o yaml | grep -A20 readinessProbe

# 步骤 2：查看探针失败日志
kubectl describe pod <pod-name> | grep -A10 Events

# 步骤 3：进入容器手动测试探针
kubectl exec -it <pod-name> -- sh

# HTTP 探针测试
curl -v http://localhost:<port>/<path>

# TCP 探针测试
nc -zv localhost <port>

# 命令探针测试
<probe-command>

# 步骤 4：检查应用日志
kubectl logs <pod-name>

# 步骤 5：调整探针参数（如果探针配置不合理）
kubectl patch deployment <name> -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "<container-name>",
          "livenessProbe": {
            "initialDelaySeconds": 60,
            "periodSeconds": 10,
            "timeoutSeconds": 5,
            "failureThreshold": 3
          }
        }]
      }
    }
  }
}'

# 步骤 6：验证修复
kubectl get pod <pod-name> -w
```

#### 3.5.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **低** | 查看探针配置无风险 | - |
| **中** | 修改探针参数可能影响故障检测 | 评估后再调整 |
| **低** | 手动测试探针无风险 | - |

#### 3.5.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 探针过于激进可能导致不必要的重启
2. 探针过于宽松可能延迟故障检测
3. 修改前理解应用启动特性
4. initialDelaySeconds 要大于应用启动时间
5. 生产环境建议同时配置 liveness 和 readiness 探针
```

### 3.6 卷挂载失败

#### 3.6.1 解决步骤

```bash
# 步骤 1：确认错误类型
kubectl describe pod <pod-name> | grep -A10 Events

# 常见错误：
# - MountVolume.SetUp failed: volume not attached
# - MountVolume.WaitForAttach failed
# - Unable to mount volumes: timed out

# 步骤 2：检查 PVC 状态
kubectl get pvc -n <namespace>
kubectl describe pvc <pvc-name> -n <namespace>

# 步骤 3：检查 PV 状态
kubectl get pv
kubectl describe pv <pv-name>

# 步骤 4：检查 CSI 驱动状态
kubectl get pods -n kube-system | grep csi
kubectl logs -n kube-system <csi-pod>

# 步骤 5：检查节点上的挂载
mount | grep <volume-name>
ls -la /var/lib/kubelet/pods/<pod-uid>/volumes/

# 步骤 6：如果是云盘，检查云平台状态
# 阿里云
aliyun ecs DescribeDisks --DiskIds='["<disk-id>"]'
# AWS
aws ec2 describe-volumes --volume-ids <volume-id>

# 步骤 7：强制卸载并重新挂载
# ⚠️ 危险操作，确认后执行
umount /var/lib/kubelet/pods/<pod-uid>/volumes/<volume-type>/<volume-name>

# 步骤 8：重启 Pod
kubectl delete pod <pod-name> -n <namespace>
```

#### 3.6.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **高** | 强制卸载可能导致数据损坏 | 确保数据已同步 |
| **中** | 删除 Pod 会导致服务中断 | 在维护窗口操作 |
| **低** | 检查状态无风险 | - |

#### 3.6.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 卷挂载失败可能是云平台配额问题
2. 强制卸载前确认没有写操作进行
3. 检查 CSI 驱动的 RBAC 权限
4. 多 AZ 场景注意卷和节点的 AZ 匹配
5. 考虑使用卷快照进行数据保护
```

### 3.7 kubelet 证书问题

#### 3.7.1 解决步骤

```bash
# 步骤 1：检查证书状态
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates -subject

# 步骤 2：检查证书是否即将过期
kubeadm certs check-expiration

# 步骤 3：如果证书过期，续签证书
# 方法 1：使用 kubeadm 续签
kubeadm certs renew kubelet-client

# 方法 2：重新加入集群（如果证书完全不可用）
# 在 master 节点获取 token
kubeadm token create --print-join-command

# 在工作节点执行
kubeadm reset
kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>

# 步骤 4：重启 kubelet
systemctl restart kubelet

# 步骤 5：验证恢复
kubectl get node $(hostname)
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates
```

#### 3.7.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **高** | kubeadm reset 会删除节点配置 | 仅在必要时使用 |
| **中** | 重新加入需要停止节点上的 Pod | 在维护窗口操作 |
| **低** | 证书续签一般无风险 | 验证后重启 |

#### 3.7.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. kubelet 证书续签会短暂中断服务
2. 建议配置自动证书轮转
3. 在 kubelet 配置中设置 rotateCertificates: true
4. 定期检查证书有效期，设置告警
5. kubeadm reset 是破坏性操作，谨慎使用
```

---

## 附录

### A. kubelet 关键指标

| 指标名称 | 说明 | 告警阈值建议 |
|----------|------|--------------|
| `kubelet_running_containers` | 运行中的容器数 | 异常变化 |
| `kubelet_runtime_operations_duration_seconds` | 运行时操作延迟 | P99 > 10s |
| `kubelet_runtime_operations_errors_total` | 运行时操作错误 | > 0 |
| `kubelet_volume_stats_used_bytes` | 卷使用量 | > 80% 容量 |
| `kubelet_pod_start_duration_seconds` | Pod 启动时间 | P99 > 30s |

### B. 常见配置参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--container-runtime-endpoint` | - | 容器运行时 socket |
| `--cgroup-driver` | cgroupfs | cgroup 驱动 |
| `--max-pods` | 110 | 最大 Pod 数 |
| `--eviction-hard` | - | 硬驱逐阈值 |
| `--eviction-soft` | - | 软驱逐阈值 |
| `--system-reserved` | - | 系统预留资源 |
| `--kube-reserved` | - | Kubernetes 预留资源 |

### C. kubelet 配置文件示例

```yaml
# /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
containerRuntimeEndpoint: unix:///run/containerd/containerd.sock
evictionHard:
  imagefs.available: 15%
  memory.available: 100Mi
  nodefs.available: 10%
  nodefs.inodesFree: 5%
evictionSoft:
  imagefs.available: 20%
  memory.available: 200Mi
  nodefs.available: 15%
evictionSoftGracePeriod:
  imagefs.available: 1m
  memory.available: 1m
  nodefs.available: 1m
rotateCertificates: true
```
