# 99 - Kubernetes 生产环境故障排查全攻略 (Troubleshooting)

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/tasks/debug](https://kubernetes.io/docs/tasks/debug/)

---

## 目录

- [故障排查方法论](#故障排查方法论)
- [Pod故障排查](#pod故障排查)
- [Node故障排查](#node故障排查)
- [Service/网络故障排查](#service网络故障排查)
- [存储故障排查](#存储故障排查)
- [控制平面故障排查](#控制平面故障排查)
- [调度器故障排查](#调度器故障排查)
- [应用部署故障排查](#应用部署故障排查)
- [安全/权限故障排查](#安全权限故障排查)
- [性能问题排查](#性能问题排查)
- [集群升级故障排查](#集群升级故障排查)
- [版本特定已知问题](#版本特定已知问题)
- [生产级诊断工具集](#生产级诊断工具集)
- [监控告警集成](#监控告警集成)
- [生产SOP流程](#生产sop流程)

---

## 故障排查方法论

### 黄金排查原则

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         故障排查四步法                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│  Step 1: 症状识别 → 资源状态、Events、条件检查                                │
│  Step 2: 范围界定 → 单点问题 vs 全局问题、时间线追溯                          │
│  Step 3: 根因分析 → 日志分析、指标关联、配置审计                              │
│  Step 4: 验证修复 → 修复实施、回归测试、预防措施                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 通用诊断命令矩阵

| 层级 | 诊断命令 | 用途 | 版本说明 |
|:---:|:---|:---|:---|
| **集群** | `kubectl cluster-info` | 集群连通性验证 | 全版本 |
| **集群** | `kubectl get --raw='/readyz?verbose'` | API Server健康检查 | v1.16+ |
| **集群** | `kubectl get componentstatuses` | 控制平面组件状态(已废弃) | v1.25前 |
| **节点** | `kubectl get nodes -o wide` | 节点状态总览 | 全版本 |
| **节点** | `kubectl describe node <name>` | 节点详情/条件/事件 | 全版本 |
| **节点** | `kubectl top nodes` | 节点资源使用 | 需Metrics Server |
| **Pod** | `kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded` | 异常Pod过滤 | 全版本 |
| **Pod** | `kubectl describe pod <name>` | Pod详情/Events | 全版本 |
| **Pod** | `kubectl logs <pod> [-c container] [--previous]` | 容器日志 | 全版本 |
| **Pod** | `kubectl debug <pod> --image=busybox -it` | 临时调试容器 | v1.25+ GA |
| **事件** | `kubectl get events -A --sort-by='.lastTimestamp'` | 全局事件排序 | 全版本 |
| **网络** | `kubectl exec <pod> -- curl -v <service>` | 服务连通性测试 | 全版本 |
| **存储** | `kubectl get pv,pvc -A` | 存储资源状态 | 全版本 |

---

## Pod故障排查

### Pod状态机与故障映射

```yaml
# Pod生命周期状态机
Pod状态流转:
  Pending:
    - 调度中: 等待调度器分配节点
    - 卷挂载: 等待存储卷准备就绪
    - 镜像拉取: 等待容器镜像下载
  Running:
    - 正常运行: 至少一个容器正在运行
    - 探针失败: 存活/就绪探针检测失败
  Succeeded: 所有容器正常退出(exit 0)
  Failed: 至少一个容器异常退出
  Unknown: 节点失联，状态无法获取
```

### Pod Pending 深度排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **Pending - 资源不足** | CPU/Memory不足 | `kubectl describe pod`, `kubectl describe node` | - | 检查ResourceQuota，扩容节点池 | 配置Cluster Autoscaler，设置合理的resource requests |
| **Pending - 调度约束** | nodeSelector/affinity无法满足 | `kubectl describe pod` 查看Events | v1.25+拓扑约束增强 | 检查节点标签，调整调度约束 | 使用preferredDuringScheduling替代required |
| **Pending - PVC未绑定** | StorageClass无provisioner | `kubectl get pvc`, `kubectl describe pvc` | v1.27+存储容量跟踪 | 检查StorageClass，确认provisioner可用 | 配置默认StorageClass，监控存储配额 |
| **Pending - Taint未容忍** | 节点有Taint无对应Toleration | `kubectl describe node \| grep Taint` | - | 添加Toleration或移除Taint | 文档化Taint策略，CI/CD校验 |
| **Pending - Pod亲和性** | requiredDuringScheduling无法满足 | `kubectl describe pod`，检查其他Pod分布 | v1.26拓扑感知增强 | 调整亲和性规则或增加匹配Pod | 使用软亲和性，设置合理的topologyKey |
| **Pending - 节点selector** | 标签不匹配 | `kubectl get nodes --show-labels` | - | 检查节点标签，修正selector | 使用nodeAffinity替代nodeSelector |
| **Pending - ResourceQuota** | 命名空间配额用尽 | `kubectl describe quota -n <ns>` | - | 申请更多配额或优化资源使用 | 监控配额使用率，设置告警 |
| **Pending - LimitRange** | 资源请求超出限制 | `kubectl describe limitrange -n <ns>` | - | 调整Pod资源请求或修改LimitRange | 设置合理的默认值 |
| **Pending - PodDisruptionBudget** | PDB阻止调度 | `kubectl get pdb -A` | v1.27 unhealthyPodEvictionPolicy | 检查PDB配置，等待现有Pod恢复 | 配置合理的minAvailable |
| **Pending - 节点unschedulable** | 节点被cordon | `kubectl get nodes` 检查SCHEDULE状态 | - | uncordon节点或选择其他节点 | 监控节点可调度状态 |

#### Pending诊断脚本

```bash
#!/bin/bash
# pending-pod-diagnose.sh - Pod Pending深度诊断

POD_NAME=$1
NAMESPACE=${2:-default}

echo "=== Pod Pending 诊断报告 ==="
echo "Pod: $POD_NAME, Namespace: $NAMESPACE"
echo ""

# 1. Pod Events
echo "=== Pod Events ==="
kubectl describe pod $POD_NAME -n $NAMESPACE | grep -A 20 "Events:"

# 2. 调度器日志
echo -e "\n=== 调度器相关日志 ==="
kubectl logs -n kube-system -l component=kube-scheduler --tail=50 2>/dev/null | grep -i "$POD_NAME" || echo "未找到相关调度日志"

# 3. 节点资源状态
echo -e "\n=== 节点资源概况 ==="
kubectl top nodes 2>/dev/null || echo "Metrics Server未安装"

# 4. 节点调度条件
echo -e "\n=== 节点可调度状态 ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,SCHEDULABLE:.spec.unschedulable

# 5. ResourceQuota检查
echo -e "\n=== ResourceQuota状态 ==="
kubectl describe quota -n $NAMESPACE 2>/dev/null || echo "无ResourceQuota"

# 6. PVC状态检查
echo -e "\n=== 相关PVC状态 ==="
kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{range .spec.volumes[*]}{.persistentVolumeClaim.claimName}{"\n"}{end}' | xargs -I {} kubectl get pvc {} -n $NAMESPACE 2>/dev/null

# 7. 节点Taint
echo -e "\n=== 节点Taint ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

### Pod CrashLoopBackOff 深度排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **启动即崩溃** | 应用代码异常 | `kubectl logs <pod> --previous` | - | 检查应用日志，修复代码bug | 本地测试，健壮的错误处理 |
| **依赖服务不可用** | 启动依赖未满足 | `kubectl logs <pod>`, 检查Service状态 | v1.28 Native Sidecar | 使用init容器等待依赖，配置重试 | 依赖服务健康检查，就绪探针 |
| **配置错误** | ConfigMap/Secret错误 | `kubectl describe pod`，检查挂载 | - | 检查配置内容，修正挂载路径 | 配置版本化，变更审计 |
| **环境变量缺失** | 必需环境变量未设置 | `kubectl exec <pod> -- env` | - | 补充缺失的环境变量 | 配置校验，使用ConfigMap |
| **权限不足** | 文件/目录权限问题 | `kubectl logs <pod>`，检查fsGroup | - | 配置securityContext，fsGroup | 标准化安全上下文配置 |
| **资源限制** | CPU throttling/OOMKilled | `kubectl describe pod`，检查Terminated原因 | v1.27就地调整 | 增加资源limits，优化应用 | 合理的资源请求，性能测试 |
| **存活探针失败** | 探针配置不当 | `kubectl describe pod`，Liveness probe failed | - | 调整探针超时/阈值，修复健康端点 | 合理的initialDelaySeconds |
| **命令/参数错误** | entrypoint配置错误 | `kubectl describe pod`，检查command/args | - | 修正容器命令配置 | Dockerfile最佳实践 |
| **镜像问题** | 镜像entrypoint缺失 | `kubectl logs <pod>` | - | 检查镜像，指定正确的command | 镜像构建规范 |
| **Init容器失败** | 初始化阶段失败 | `kubectl logs <pod> -c <init-container>` | v1.28 Sidecar增强 | 检查init容器日志，修复初始化 | init容器幂等性设计 |

#### CrashLoopBackOff诊断脚本

```bash
#!/bin/bash
# crashloop-diagnose.sh - CrashLoopBackOff深度诊断

POD_NAME=$1
NAMESPACE=${2:-default}

echo "=== CrashLoopBackOff 诊断报告 ==="
echo "Pod: $POD_NAME, Namespace: $NAMESPACE"

# 1. 获取容器退出状态
echo -e "\n=== 容器状态详情 ==="
kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{range .status.containerStatuses[*]}Container: {.name}
  Ready: {.ready}
  RestartCount: {.restartCount}
  LastState: {.lastState}
  State: {.state}
{end}'

# 2. 获取上一次日志
echo -e "\n=== 上一次容器日志 ==="
kubectl logs $POD_NAME -n $NAMESPACE --previous --tail=100 2>/dev/null || echo "无法获取上一次日志"

# 3. 当前日志
echo -e "\n=== 当前容器日志 ==="
kubectl logs $POD_NAME -n $NAMESPACE --tail=50 2>/dev/null || echo "容器未运行"

# 4. 事件
echo -e "\n=== Pod Events ==="
kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$POD_NAME --sort-by='.lastTimestamp'

# 5. 容器命令检查
echo -e "\n=== 容器命令配置 ==="
kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{range .spec.containers[*]}Container: {.name}
  Image: {.image}
  Command: {.command}
  Args: {.args}
{end}'

# 6. 探针配置
echo -e "\n=== 探针配置 ==="
kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{range .spec.containers[*]}Container: {.name}
  LivenessProbe: {.livenessProbe}
  ReadinessProbe: {.readinessProbe}
{end}'
```

### Pod OOMKilled 深度排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **容器OOMKilled** | 内存超过limits | `kubectl describe pod`, 查看lastState.terminated.reason | v1.27就地Pod调整 | 增加memory limits，优化内存使用 | 压测确定内存需求，监控内存使用 |
| **系统OOM** | 节点内存不足 | `dmesg \| grep -i oom`, `journalctl -k \| grep -i oom` | v1.26驱逐增强 | 驱逐Pod，扩容节点 | 配置系统预留资源，eviction-hard |
| **内存泄漏** | 应用内存持续增长 | Prometheus内存指标，profiling | - | 修复应用内存泄漏 | 定期profiling，内存限制告警 |
| **JVM堆配置** | Java堆超过limits | JVM日志，`-XX:+HeapDumpOnOutOfMemoryError` | - | 配置-Xmx小于limits | 容器感知JVM参数(-XX:+UseContainerSupport) |
| **缓存无限增长** | 应用缓存未设上限 | 应用指标，heap分析 | - | 配置缓存eviction策略 | 监控缓存大小，设置合理TTL |

#### OOMKilled诊断YAML

```yaml
# oom-debug-pod.yaml - 内存诊断Pod
apiVersion: v1
kind: Pod
metadata:
  name: oom-debug
spec:
  containers:
  - name: debug
    image: alpine:3.19
    command: ["sh", "-c", "while true; do cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null || cat /sys/fs/cgroup/memory.current; sleep 5; done"]
    resources:
      requests:
        memory: "64Mi"
      limits:
        memory: "128Mi"
  restartPolicy: Never
```

### Pod ImagePullBackOff 深度排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **镜像不存在** | tag错误/镜像已删除 | `kubectl describe pod`, Events | - | 检查镜像名称和tag，推送正确镜像 | CI/CD验证镜像存在，使用immutable tag |
| **认证失败** | imagePullSecrets配置错误 | `kubectl describe pod`, `kubectl get secret` | - | 检查Secret内容，更新认证信息 | Secret自动轮换，使用ImagePullJob预热 |
| **网络问题** | 无法访问registry | 节点上测试`curl https://registry/v2/` | - | 检查网络策略，代理配置 | 使用私有仓库镜像，配置mirror |
| **速率限制** | Docker Hub/Registry限流 | Events显示429错误 | - | 等待重试，使用认证账户 | 私有registry，配置pull-through cache |
| **平台不匹配** | arm64 vs amd64 | `kubectl describe pod`, exec format error | v1.25+多架构增强 | 使用多架构镜像，指定正确平台 | 构建多架构镜像，node affinity |
| **TLS证书问题** | 私有registry证书不信任 | containerd/Docker日志 | - | 配置insecure-registries或添加CA证书 | 使用公信CA签发证书 |

#### ImagePull诊断脚本

```bash
#!/bin/bash
# imagepull-diagnose.sh - 镜像拉取问题诊断

POD_NAME=$1
NAMESPACE=${2:-default}

echo "=== ImagePull 诊断报告 ==="

# 1. 获取镜像信息
echo "=== 容器镜像 ==="
kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{range .spec.containers[*]}{.name}: {.image}{"\n"}{end}'
kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{range .spec.initContainers[*]}{.name}(init): {.image}{"\n"}{end}'

# 2. 检查imagePullSecrets
echo -e "\n=== ImagePullSecrets ==="
SECRETS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.imagePullSecrets[*].name}')
if [ -z "$SECRETS" ]; then
  echo "未配置imagePullSecrets"
else
  for secret in $SECRETS; do
    echo "Secret: $secret"
    kubectl get secret $secret -n $NAMESPACE -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq '.auths | keys' 2>/dev/null || echo "无法解析Secret"
  done
fi

# 3. 事件
echo -e "\n=== Pod Events ==="
kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$POD_NAME | grep -i "pull\|image"

# 4. 节点上的镜像
NODE=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.nodeName}')
if [ -n "$NODE" ]; then
  echo -e "\n=== 节点 $NODE 上的镜像 ==="
  kubectl debug node/$NODE -it --image=busybox -- crictl images 2>/dev/null | head -20
fi
```

### Pod网络故障排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **Pod无法访问Service** | kube-proxy问题 | `kubectl exec <pod> -- nslookup kubernetes` | v1.29 IPVS增强 | 检查CoreDNS，kube-proxy状态 | 监控DNS解析延迟 |
| **Pod间网络不通** | CNI问题 | `kubectl exec <pod> -- ping <pod-ip>` | v1.25双栈增强 | 检查CNI Pod状态，路由表 | CNI健康监控 |
| **NetworkPolicy阻断** | 入站/出站规则 | `kubectl get networkpolicy -A` | v1.25+增强 | 检查NetworkPolicy规则 | NetworkPolicy测试用例 |
| **DNS解析失败** | CoreDNS问题 | `kubectl exec <pod> -- nslookup google.com` | v1.28 DNS缓存 | 检查CoreDNS日志和配置 | 备用DNS，NodeLocal DNS Cache |
| **跨节点不通** | 节点间路由/防火墙 | `kubectl exec <pod> -- traceroute <target-ip>` | - | 检查节点网络，云安全组 | 网络测试自动化 |

---

## Node故障排查

### Node状态条件解析

```yaml
# Node Conditions 完整说明
Ready:              # kubelet运行正常，可接收Pod
MemoryPressure:     # 节点内存压力
DiskPressure:       # 节点磁盘压力
PIDPressure:        # 进程ID耗尽
NetworkUnavailable: # 节点网络配置不正确
```

### Node NotReady 深度排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **kubelet停止** | 进程崩溃/资源耗尽 | `systemctl status kubelet`, `journalctl -u kubelet` | - | 检查kubelet日志，重启kubelet | 监控kubelet进程，自动恢复 |
| **节点网络断开** | 网络故障 | API Server端检查，节点无法SSH | - | 检查网络连通性，修复网络 | 多网卡冗余，网络监控 |
| **容器运行时问题** | containerd/CRI-O故障 | `systemctl status containerd`, `crictl info` | v1.26 containerd 1.6+ | 重启容器运行时，检查磁盘空间 | 运行时健康监控 |
| **证书过期** | kubelet证书过期 | `openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates` | v1.27证书轮换GA | 重新生成证书或配置自动轮换 | 证书过期告警，自动轮换 |
| **磁盘满** | 根分区/数据分区满 | `df -h`, `du -sh /var/lib/kubelet/*` | v1.26驱逐增强 | 清理日志/镜像，扩容磁盘 | 磁盘使用监控告警 |
| **内存耗尽** | 节点OOM | `dmesg \| grep -i oom`, `free -h` | - | 重启节点，驱逐Pod | 配置system-reserved |
| **API Server不可达** | 控制平面故障 | 节点上`curl -k https://api-server:6443/healthz` | - | 检查API Server状态，网络 | API Server HA部署 |
| **时钟不同步** | NTP问题 | `timedatectl`, `chronyc tracking` | - | 同步时间，配置NTP | NTP监控告警 |
| **内核panic** | 内核bug/硬件故障 | `/var/log/kern.log`, `dmesg` | - | 分析crash dump，更新内核 | 内核版本管理，硬件监控 |

#### Node NotReady诊断脚本

```bash
#!/bin/bash
# node-notready-diagnose.sh - Node NotReady深度诊断

NODE_NAME=$1

echo "=== Node NotReady 诊断报告 ==="
echo "Node: $NODE_NAME"

# 1. Node Conditions
echo -e "\n=== Node Conditions ==="
kubectl get node $NODE_NAME -o jsonpath='{range .status.conditions[*]}{.type}: {.status} (Reason: {.reason}, Message: {.message}){"\n"}{end}'

# 2. Node Events
echo -e "\n=== Node Events ==="
kubectl get events --field-selector involvedObject.name=$NODE_NAME,involvedObject.kind=Node --sort-by='.lastTimestamp'

# 3. 节点资源
echo -e "\n=== 节点资源分配 ==="
kubectl describe node $NODE_NAME | grep -A 10 "Allocated resources"

# 4. 节点上Pod
echo -e "\n=== 节点上的Pod数量 ==="
kubectl get pods -A --field-selector spec.nodeName=$NODE_NAME --no-headers | wc -l

# 5. 如果可以SSH到节点
echo -e "\n=== 需要在节点上执行的命令 ==="
cat << 'EOF'
# 1. kubelet状态
systemctl status kubelet
journalctl -u kubelet --since "30 minutes ago" --no-pager | tail -50

# 2. 容器运行时
systemctl status containerd
crictl info
crictl ps -a | head -20

# 3. 系统资源
free -h
df -h
cat /proc/loadavg

# 4. 证书状态
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates 2>/dev/null

# 5. 网络连通性
curl -k https://<API_SERVER>:6443/healthz
EOF
```

### Node资源压力排查

| 压力类型 | 触发条件 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **MemoryPressure** | memory.available < eviction-hard | `free -h`, `cat /proc/meminfo` | v1.26驱逐增强 | 驱逐Pod，增加内存 | 配置memory.available驱逐阈值 |
| **DiskPressure** | nodefs.available < 10% | `df -h`, `du -sh /var/lib/*` | - | 清理日志/镜像/容器 | 配置imagefs.available阈值 |
| **PIDPressure** | pid.available < 100 | `ps aux \| wc -l`, `/proc/sys/kernel/pid_max` | v1.25+ PID限制 | 清理僵尸进程，重启服务 | 配置--pod-max-pids |

#### 资源压力缓解脚本

```bash
#!/bin/bash
# node-pressure-relief.sh - 节点资源压力缓解

NODE_NAME=$1

echo "=== 节点资源压力缓解 ==="

# 1. 检查当前压力状态
echo "=== 当前Conditions ==="
kubectl get node $NODE_NAME -o jsonpath='{range .status.conditions[*]}{.type}={.status} {end}'

# 2. DiskPressure缓解
echo -e "\n\n=== DiskPressure缓解命令(在节点上执行) ==="
cat << 'EOF'
# 清理已退出的容器
crictl rm $(crictl ps -a -q --state exited)

# 清理未使用镜像
crictl rmi --prune

# 清理日志(谨慎)
find /var/log -name "*.log" -mtime +7 -delete

# 清理kubelet临时文件
rm -rf /var/lib/kubelet/pods/*/volumes/kubernetes.io~empty-dir/*/lost+found
EOF

# 3. MemoryPressure缓解
echo -e "\n=== MemoryPressure缓解 ==="
echo "驱逐BestEffort Pod:"
kubectl get pods -A --field-selector spec.nodeName=$NODE_NAME -o json | jq -r '.items[] | select(.status.qosClass=="BestEffort") | "\(.metadata.namespace)/\(.metadata.name)"'

# 4. PIDPressure缓解
echo -e "\n=== PIDPressure缓解命令(在节点上执行) ==="
cat << 'EOF'
# 查找僵尸进程
ps aux | awk '{if ($8 == "Z") print $0}'

# 查找进程数最多的用户
ps -eo user | sort | uniq -c | sort -rn | head -10
EOF
```

---

## Service/网络故障排查

### Service无法访问深度排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **ClusterIP无响应** | Endpoints为空 | `kubectl get endpoints <svc>` | - | 检查selector与Pod labels匹配 | Service监控，自动化测试 |
| **Endpoints不健康** | Pod就绪探针失败 | `kubectl describe endpoints <svc>` | - | 修复Pod就绪探针 | 探针配置验证 |
| **kube-proxy规则缺失** | kube-proxy问题 | `iptables-save \| grep <svc-ip>` 或 `ipvsadm -ln` | v1.29 IPVS改进 | 重启kube-proxy，检查日志 | kube-proxy监控 |
| **NodePort不通** | 节点防火墙 | `curl <node-ip>:<nodeport>` | - | 检查安全组/防火墙规则 | 安全组自动化配置 |
| **LoadBalancer Pending** | 云控制器问题 | `kubectl describe svc` | - | 检查CCM日志，云API权限 | 云API配额监控 |
| **ExternalName解析失败** | DNS问题 | `nslookup <external-name>` | - | 检查外部DNS配置 | 外部依赖监控 |
| **会话亲和性问题** | sessionAffinity配置 | `kubectl get svc -o yaml` | - | 配置sessionAffinity: ClientIP | 测试会话保持 |
| **端口配置错误** | targetPort不匹配 | `kubectl describe svc`, `kubectl get pod -o yaml` | - | 修正targetPort配置 | 端口配置验证 |

#### Service诊断脚本

```bash
#!/bin/bash
# service-diagnose.sh - Service深度诊断

SVC_NAME=$1
NAMESPACE=${2:-default}

echo "=== Service 诊断报告 ==="
echo "Service: $SVC_NAME, Namespace: $NAMESPACE"

# 1. Service详情
echo -e "\n=== Service配置 ==="
kubectl get svc $SVC_NAME -n $NAMESPACE -o yaml

# 2. Endpoints
echo -e "\n=== Endpoints ==="
kubectl get endpoints $SVC_NAME -n $NAMESPACE -o yaml

# 3. 后端Pod状态
echo -e "\n=== 后端Pod ==="
SELECTOR=$(kubectl get svc $SVC_NAME -n $NAMESPACE -o jsonpath='{.spec.selector}' | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")')
kubectl get pods -n $NAMESPACE -l $SELECTOR -o wide

# 4. 就绪状态检查
echo -e "\n=== Pod就绪状态 ==="
kubectl get pods -n $NAMESPACE -l $SELECTOR -o jsonpath='{range .items[*]}{.metadata.name}: Ready={.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'

# 5. 从测试Pod连接测试
echo -e "\n=== 连通性测试命令 ==="
SVC_IP=$(kubectl get svc $SVC_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
SVC_PORT=$(kubectl get svc $SVC_NAME -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')
echo "kubectl run test-conn --rm -it --image=curlimages/curl --restart=Never -- curl -v http://$SVC_IP:$SVC_PORT"
```

### DNS故障排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **DNS解析超时** | CoreDNS过载/Pod问题 | `kubectl exec <pod> -- nslookup kubernetes` | v1.28 DNS缓存增强 | 扩容CoreDNS，检查负载 | NodeLocal DNS Cache |
| **解析错误域名** | CoreDNS配置错误 | `kubectl get cm coredns -n kube-system -o yaml` | - | 检查Corefile配置 | 配置变更审计 |
| **外部域名解析失败** | 上游DNS问题 | `kubectl exec <pod> -- nslookup google.com` | - | 检查上游DNS配置 | 配置备用上游DNS |
| **间歇性失败** | CoreDNS Pod重启 | `kubectl get pods -n kube-system -l k8s-app=kube-dns` | - | 检查CoreDNS资源，OOM | 资源限制合理配置 |
| **ndots配置问题** | 搜索域过多 | Pod的/etc/resolv.conf | - | 调整dnsConfig.options | 自定义dnsPolicy |
| **search域问题** | FQDN vs 短名称 | `kubectl exec <pod> -- cat /etc/resolv.conf` | - | 使用FQDN或调整search域 | 应用使用FQDN |

#### DNS诊断脚本

```bash
#!/bin/bash
# dns-diagnose.sh - DNS深度诊断

echo "=== DNS 诊断报告 ==="

# 1. CoreDNS Pod状态
echo "=== CoreDNS Pod状态 ==="
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide

# 2. CoreDNS资源使用
echo -e "\n=== CoreDNS资源使用 ==="
kubectl top pods -n kube-system -l k8s-app=kube-dns 2>/dev/null || echo "Metrics Server未安装"

# 3. CoreDNS日志
echo -e "\n=== CoreDNS最近日志 ==="
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=30

# 4. Corefile配置
echo -e "\n=== Corefile配置 ==="
kubectl get cm coredns -n kube-system -o jsonpath='{.data.Corefile}'

# 5. DNS Service
echo -e "\n=== kube-dns Service ==="
kubectl get svc kube-dns -n kube-system -o yaml

# 6. 测试DNS解析
echo -e "\n=== DNS解析测试命令 ==="
cat << 'EOF'
# 集群内解析测试
kubectl run dnstest --rm -it --image=busybox:1.36 --restart=Never -- nslookup kubernetes.default

# 外部域名解析测试
kubectl run dnstest --rm -it --image=busybox:1.36 --restart=Never -- nslookup google.com

# 详细DNS查询
kubectl run dnstest --rm -it --image=tutum/dnsutils --restart=Never -- dig kubernetes.default.svc.cluster.local
EOF
```

### NetworkPolicy排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **入站流量被阻断** | Ingress规则限制 | `kubectl get networkpolicy -n <ns> -o yaml` | v1.25+增强 | 添加允许的ingress规则 | NetworkPolicy测试 |
| **出站流量被阻断** | Egress规则限制 | 同上 | - | 添加允许的egress规则 | 逐步收紧策略 |
| **DNS被阻断** | 未允许kube-dns | 检查是否有DNS egress规则 | - | 添加到kube-dns的egress规则 | 默认允许DNS |
| **CNI不支持** | 使用了不支持的CNI | 检查CNI类型 | - | 使用Calico/Cilium等支持的CNI | 选型时考虑NetworkPolicy |

```yaml
# 允许DNS的NetworkPolicy模板
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
spec:
  podSelector: {}
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  policyTypes:
  - Egress
```

---

## 存储故障排查

### PVC/PV故障深度排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **PVC Pending** | 无匹配PV/StorageClass问题 | `kubectl describe pvc <name>` | v1.29 CSI增强 | 检查StorageClass，创建PV | 配置默认StorageClass |
| **PVC Pending - WaitForFirstConsumer** | 延迟绑定等待调度 | `kubectl describe pvc` | - | 创建使用该PVC的Pod | 理解VolumeBindingMode |
| **PV挂载失败** | CSI驱动问题 | `kubectl describe pod`, CSI控制器日志 | v1.27 CSI增强 | 检查CSI驱动Pod状态 | CSI驱动健康监控 |
| **挂载权限问题** | fsGroup/securityContext | `kubectl logs <pod>`, 挂载错误 | - | 配置正确的fsGroup | 标准化securityContext |
| **多Pod挂载冲突** | RWO访问模式限制 | `kubectl describe pv` | - | 使用RWX存储或StatefulSet | 明确AccessMode需求 |
| **卷扩容失败** | StorageClass不支持扩容 | `kubectl describe pvc` | v1.27扩容增强 | 使用支持扩容的StorageClass | 配置allowVolumeExpansion |
| **快照创建失败** | VolumeSnapshotClass配置 | `kubectl describe volumesnapshot` | v1.27快照GA | 检查VolumeSnapshotClass | 快照策略测试 |
| **PV回收问题** | 回收策略为Retain | `kubectl get pv` | - | 手动清理或修改回收策略 | 理解Reclaim Policy |

#### 存储诊断脚本

```bash
#!/bin/bash
# storage-diagnose.sh - 存储深度诊断

echo "=== 存储 诊断报告 ==="

# 1. StorageClass
echo "=== StorageClasses ==="
kubectl get sc -o wide

# 2. 默认StorageClass
echo -e "\n=== 默认StorageClass ==="
kubectl get sc -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}'

# 3. 问题PVC
echo -e "\n=== 未绑定的PVC ==="
kubectl get pvc -A | grep -v Bound

# 4. 问题PV
echo -e "\n=== Released/Failed PV ==="
kubectl get pv | grep -E "Released|Failed"

# 5. CSI驱动状态
echo -e "\n=== CSI驱动Pod ==="
kubectl get pods -A | grep -E "csi|provisioner|attacher"

# 6. CSI节点状态
echo -e "\n=== CSINode ==="
kubectl get csinodes -o wide

# 特定PVC诊断
if [ -n "$1" ]; then
  PVC_NAME=$1
  NAMESPACE=${2:-default}
  echo -e "\n=== PVC详情: $PVC_NAME ==="
  kubectl describe pvc $PVC_NAME -n $NAMESPACE
  
  # 使用该PVC的Pod
  echo -e "\n=== 使用该PVC的Pod ==="
  kubectl get pods -n $NAMESPACE -o json | jq -r ".items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName==\"$PVC_NAME\") | .metadata.name"
fi
```

### CSI驱动故障排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **provisioner Pod异常** | 资源不足/配置错误 | `kubectl logs <csi-provisioner>` | v1.29 CSI增强 | 检查provisioner日志 | provisioner监控 |
| **attacher超时** | 云API问题 | `kubectl logs <csi-attacher>` | - | 检查云API权限/配额 | 云API监控 |
| **node驱动问题** | 节点上CSI驱动异常 | `kubectl logs <csi-node> -c <driver>` | - | 重启CSI驱动Pod | DaemonSet健康监控 |
| **挂载点泄漏** | 未正常卸载 | 节点上`mount \| grep <pv>` | - | 手动umount，清理 | 正确处理Pod删除 |

---

## 控制平面故障排查

### API Server故障排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **API Server 5xx错误** | etcd问题/过载 | `kubectl get --raw /healthz/etcd` | v1.29审计增强 | 检查etcd健康，增加限流 | API Server HA，APF限流 |
| **请求超时** | API Server过载 | `kubectl logs kube-apiserver` | - | 检查负载，扩容，APF配置 | 合理的APF配置 |
| **认证失败** | 证书过期/token无效 | 检查kubeconfig，证书有效期 | v1.27证书轮换GA | 更新证书/token | 证书自动轮换 |
| **授权失败** | RBAC配置问题 | `kubectl auth can-i --as <user> ...` | - | 检查ClusterRole/RoleBinding | RBAC审计 |
| **准入控制失败** | Webhook问题 | `kubectl logs`，Webhook日志 | - | 检查Webhook可用性 | Webhook HA部署 |
| **限流(429)** | APF限流 | Prometheus `apiserver_flowcontrol*`指标 | v1.29 APF增强 | 调整FlowSchema/PriorityLevel | 监控APF队列 |
| **审计日志过大** | 审计策略问题 | 检查审计策略，磁盘使用 | v1.29审计增强 | 优化审计策略 | 日志轮转，外部存储 |

#### API Server诊断脚本

```bash
#!/bin/bash
# apiserver-diagnose.sh - API Server深度诊断

echo "=== API Server 诊断报告 ==="

# 1. 健康检查
echo "=== 健康检查 ==="
kubectl get --raw='/healthz?verbose' 2>/dev/null | grep -v "^+" || kubectl get --raw='/healthz'

# 2. 就绪检查
echo -e "\n=== 就绪检查 ==="
kubectl get --raw='/readyz?verbose' 2>/dev/null | grep -v "^+" || kubectl get --raw='/readyz'

# 3. API Server Pod状态
echo -e "\n=== API Server Pod ==="
kubectl get pods -n kube-system -l component=kube-apiserver -o wide

# 4. API Server日志(如果可访问)
echo -e "\n=== API Server最近错误日志 ==="
kubectl logs -n kube-system -l component=kube-apiserver --tail=50 2>/dev/null | grep -iE "error|failed|timeout" || echo "无法访问日志"

# 5. APF状态
echo -e "\n=== APF FlowSchemas ==="
kubectl get flowschemas

echo -e "\n=== APF PriorityLevelConfigurations ==="
kubectl get prioritylevelconfigurations

# 6. API资源版本
echo -e "\n=== API Resources ==="
kubectl api-resources --verbs=list --namespaced=false | head -20
```

### etcd故障排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **etcd存储满** | 数据增长/压缩失败 | `etcdctl endpoint status --write-out=table` | - | 压缩+碎片整理，增加配额 | 定期压缩，存储监控 |
| **Leader频繁切换** | 网络问题/磁盘慢 | `etcdctl endpoint status`, etcd日志 | - | 检查网络延迟，使用SSD | 独立etcd节点，网络优化 |
| **集群不健康** | 成员失联 | `etcdctl member list`, `etcdctl endpoint health` | - | 检查成员状态，恢复失联节点 | 3/5节点高可用 |
| **性能下降** | 请求过多/磁盘慢 | Prometheus etcd指标 | - | 优化请求，使用快速磁盘 | SSD，专用磁盘 |
| **数据不一致** | 脑裂/恢复问题 | 检查各节点日志 | - | 从健康成员恢复 | 定期备份 |
| **快照失败** | 磁盘空间/权限 | 检查快照命令输出 | - | 确保磁盘空间，检查权限 | 自动化备份脚本 |

#### etcd诊断脚本

```bash
#!/bin/bash
# etcd-diagnose.sh - etcd深度诊断

echo "=== etcd 诊断报告 ==="

# 需要在etcd节点或有etcd访问权限的地方执行

# 1. 集群状态
echo "=== 集群状态 ==="
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint status --write-out=table

# 2. 集群健康
echo -e "\n=== 集群健康 ==="
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health --write-out=table

# 3. 成员列表
echo -e "\n=== 成员列表 ==="
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list --write-out=table

# 4. 数据库大小
echo -e "\n=== 数据库大小 ==="
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint status --write-out=json | jq '.[].Status.dbSize'

# 5. 告警
echo -e "\n=== etcd告警 ==="
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  alarm list
```

### Controller Manager故障排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **控制器未工作** | Leader选举失败 | `kubectl get lease -n kube-system` | - | 检查Leader选举，重启 | HA部署 |
| **Deployment不更新** | Deployment控制器问题 | `kubectl logs kube-controller-manager` | - | 检查控制器日志 | 控制器监控 |
| **GC未执行** | GC控制器问题 | 检查orphan资源 | - | 手动清理，检查GC设置 | GC监控 |
| **工作队列积压** | 请求过多 | Prometheus `workqueue_depth` | - | 增加并发度 | 队列深度告警 |

---

## 调度器故障排查

### 调度失败深度排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **0/N nodes available** | 资源不足 | `kubectl describe pod`, 节点资源 | - | 扩容节点，调整资源请求 | Cluster Autoscaler |
| **node(s) had taint** | Taint不容忍 | `kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.taints}{"\n"}{end}'` | - | 添加Toleration或移除Taint | Taint策略文档化 |
| **node(s) didn't match selector** | nodeSelector不匹配 | `kubectl get nodes --show-labels` | - | 检查节点标签 | 使用nodeAffinity |
| **pod affinity/anti-affinity** | 亲和性无法满足 | `kubectl describe pod` | v1.26拓扑增强 | 调整亲和性规则 | 使用软亲和性 |
| **volume node affinity** | 存储拓扑限制 | `kubectl describe pv` | - | 检查卷的nodeAffinity | 理解存储拓扑 |
| **PodTopologySpread** | 拓扑分布限制 | `kubectl describe pod` | v1.27增强 | 调整maxSkew或whenUnsatisfiable | 合理的拓扑约束 |
| **调度器过载** | 调度延迟高 | `kubectl logs kube-scheduler` | v1.25框架优化 | 检查调度器负载 | 调度器监控 |

#### 调度诊断脚本

```bash
#!/bin/bash
# scheduler-diagnose.sh - 调度器深度诊断

POD_NAME=$1
NAMESPACE=${2:-default}

echo "=== 调度器 诊断报告 ==="
echo "Pod: $POD_NAME"

# 1. Pod调度需求
echo "=== Pod调度约束 ==="
kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='
nodeSelector: {.spec.nodeSelector}
nodeName: {.spec.nodeName}
affinity: {.spec.affinity}
tolerations: {.spec.tolerations}
topologySpreadConstraints: {.spec.topologySpreadConstraints}
'

# 2. Pod资源请求
echo -e "\n\n=== Pod资源请求 ==="
kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{range .spec.containers[*]}Container: {.name}
  CPU Request: {.resources.requests.cpu}
  Memory Request: {.resources.requests.memory}
{end}'

# 3. 节点可分配资源
echo -e "\n=== 节点可分配资源 ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory,PODS:.status.allocatable.pods

# 4. 节点Taint
echo -e "\n=== 节点Taint ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# 5. 调度器日志
echo -e "\n=== 调度器相关日志 ==="
kubectl logs -n kube-system -l component=kube-scheduler --tail=20 2>/dev/null | grep -i "$POD_NAME" || echo "未找到相关日志"

# 6. 模拟调度
echo -e "\n=== 可调度节点分析 ==="
echo "符合nodeSelector的节点:"
if [ "$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.nodeSelector}')" != "" ]; then
  SELECTOR=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.nodeSelector}' | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")')
  kubectl get nodes -l $SELECTOR --no-headers | wc -l
else
  echo "无nodeSelector限制"
fi
```

---

## 应用部署故障排查

### Deployment滚动更新故障

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **更新卡住** | 新Pod无法就绪 | `kubectl rollout status deployment/<name>` | - | 检查新Pod状态，回滚 | 就绪探针配置 |
| **更新超时** | progressDeadlineSeconds | `kubectl describe deployment` | - | 增加超时或修复问题 | 合理的超时设置 |
| **回滚失败** | 历史版本不可用 | `kubectl rollout history deployment/<name>` | - | 检查revisionHistoryLimit | 保留足够的历史版本 |
| **RollingUpdate过慢** | maxUnavailable/maxSurge | `kubectl get deployment -o yaml` | - | 调整滚动更新策略 | 根据SLA设置策略 |
| **PDB阻止更新** | minAvailable/maxUnavailable | `kubectl get pdb` | v1.27 unhealthyPodEvictionPolicy | 调整PDB配置 | 理解PDB影响 |

#### Deployment诊断脚本

```bash
#!/bin/bash
# deployment-diagnose.sh - Deployment深度诊断

DEPLOY_NAME=$1
NAMESPACE=${2:-default}

echo "=== Deployment 诊断报告 ==="
echo "Deployment: $DEPLOY_NAME"

# 1. Deployment状态
echo "=== Deployment状态 ==="
kubectl get deployment $DEPLOY_NAME -n $NAMESPACE -o wide

# 2. Rollout状态
echo -e "\n=== Rollout状态 ==="
kubectl rollout status deployment/$DEPLOY_NAME -n $NAMESPACE --timeout=5s 2>&1

# 3. ReplicaSets
echo -e "\n=== ReplicaSets ==="
kubectl get rs -n $NAMESPACE -l $(kubectl get deployment $DEPLOY_NAME -n $NAMESPACE -o jsonpath='{.spec.selector.matchLabels}' | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")')

# 4. Pods状态
echo -e "\n=== Pods状态 ==="
kubectl get pods -n $NAMESPACE -l $(kubectl get deployment $DEPLOY_NAME -n $NAMESPACE -o jsonpath='{.spec.selector.matchLabels}' | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")') -o wide

# 5. 条件
echo -e "\n=== Deployment Conditions ==="
kubectl get deployment $DEPLOY_NAME -n $NAMESPACE -o jsonpath='{range .status.conditions[*]}{.type}: {.status} ({.reason}: {.message}){"\n"}{end}'

# 6. 历史版本
echo -e "\n=== 历史版本 ==="
kubectl rollout history deployment/$DEPLOY_NAME -n $NAMESPACE

# 7. 相关Events
echo -e "\n=== Events ==="
kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$DEPLOY_NAME --sort-by='.lastTimestamp'
```

### HPA故障排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **HPA不扩缩** | Metrics不可用 | `kubectl describe hpa`, `kubectl top pods` | v1.23 HPA v2 GA | 检查Metrics Server | Metrics监控 |
| **Targets unknown** | 自定义指标问题 | `kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods"` | v1.25 ContainerResource | 检查metrics-adapter | 指标可用性测试 |
| **扩缩振荡** | 阈值设置问题 | HPA Events | - | 调整stabilizationWindowSeconds | 合理的扩缩策略 |
| **达到上限** | maxReplicas限制 | `kubectl describe hpa` | - | 调整maxReplicas或优化应用 | 容量规划 |

---

## 安全/权限故障排查

### RBAC故障排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **Forbidden错误** | 权限不足 | `kubectl auth can-i <verb> <resource> --as <user>` | - | 添加适当的RBAC规则 | 最小权限原则 |
| **ServiceAccount无权限** | SA未绑定角色 | `kubectl get rolebinding,clusterrolebinding -A \| grep <sa>` | - | 创建RoleBinding | SA权限审计 |
| **跨namespace访问失败** | 需要ClusterRole | 检查Role vs ClusterRole | - | 使用ClusterRole | 理解Role范围 |
| **API group错误** | 资源apiGroups配置错误 | `kubectl api-resources` 检查apiGroup | - | 修正apiGroups配置 | 使用正确的apiGroups |

#### RBAC诊断脚本

```bash
#!/bin/bash
# rbac-diagnose.sh - RBAC深度诊断

USER_OR_SA=$1
NAMESPACE=${2:-default}

echo "=== RBAC 诊断报告 ==="
echo "Subject: $USER_OR_SA"

# 1. 检查是否为ServiceAccount
if [[ $USER_OR_SA == *":"* ]]; then
  SA_NS=$(echo $USER_OR_SA | cut -d: -f1)
  SA_NAME=$(echo $USER_OR_SA | cut -d: -f2)
  echo -e "\n=== ServiceAccount: $SA_NAME in $SA_NS ==="
  kubectl get sa $SA_NAME -n $SA_NS
fi

# 2. 相关RoleBindings
echo -e "\n=== RoleBindings ==="
kubectl get rolebindings -A -o json | jq -r ".items[] | select(.subjects[]?.name==\"$USER_OR_SA\" or .subjects[]?.name==\"system:serviceaccount:$NAMESPACE:$USER_OR_SA\") | \"\(.metadata.namespace)/\(.metadata.name) -> \(.roleRef.kind)/\(.roleRef.name)\""

# 3. 相关ClusterRoleBindings
echo -e "\n=== ClusterRoleBindings ==="
kubectl get clusterrolebindings -o json | jq -r ".items[] | select(.subjects[]?.name==\"$USER_OR_SA\" or .subjects[]?.name==\"system:serviceaccount:$NAMESPACE:$USER_OR_SA\") | \"\(.metadata.name) -> \(.roleRef.kind)/\(.roleRef.name)\""

# 4. 权限测试
echo -e "\n=== 权限测试 ==="
SUBJECT="--as=system:serviceaccount:$NAMESPACE:$USER_OR_SA"
for resource in pods deployments services configmaps secrets; do
  for verb in get list create delete; do
    result=$(kubectl auth can-i $verb $resource -n $NAMESPACE $SUBJECT 2>/dev/null)
    echo "$verb $resource: $result"
  done
done
```

### Pod Security Standards故障排查

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **Pod被拒绝创建** | PSS违规 | `kubectl describe pod`, Events | v1.25 PSS GA | 检查namespace的PSS标签 | 逐步收紧PSS级别 |
| **privileged容器被拒** | baseline/restricted限制 | 检查securityContext配置 | - | 调整securityContext或PSS级别 | 应用安全加固 |
| **hostPath被拒** | restricted级别限制 | 检查volumes配置 | - | 使用替代方案或调整PSS | 避免hostPath |
| **runAsRoot被拒** | restricted级别限制 | 检查runAsNonRoot配置 | - | 使用非root用户运行 | 镜像构建最佳实践 |

---

## 性能问题排查

### 集群性能问题矩阵

| 性能症状 | 可能原因 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **API延迟高** | etcd慢/API Server过载 | Prometheus `apiserver_request_duration_seconds` | v1.29 APF增强 | 优化etcd，扩展API Server | API Server监控 |
| **调度延迟高** | 调度器过载 | `scheduler_pending_pods`, `scheduler_scheduling_duration_seconds` | v1.25框架优化 | 检查调度器性能 | 调度器监控 |
| **Pod启动慢** | 镜像拉取/挂载慢 | Pod Events | - | 镜像预热，本地存储 | 镜像预拉取 |
| **DNS解析慢** | CoreDNS过载 | CoreDNS指标 | v1.28 DNS缓存 | 扩容CoreDNS，NodeLocal DNS | DNS监控 |
| **网络延迟高** | CNI问题 | 网络延迟指标 | - | 优化CNI配置 | 网络性能基准 |
| **存储IO慢** | CSI/后端存储问题 | iostat, 存储指标 | - | 优化存储配置 | 存储性能监控 |

#### 性能诊断脚本

```bash
#!/bin/bash
# performance-diagnose.sh - 性能问题诊断

echo "=== 集群性能 诊断报告 ==="

# 1. API Server延迟(需要Prometheus)
echo "=== API Server延迟 ==="
echo "请检查Prometheus指标: apiserver_request_duration_seconds_bucket"

# 2. 节点负载
echo -e "\n=== 节点负载 ==="
kubectl top nodes 2>/dev/null || echo "Metrics Server未安装"

# 3. 高资源消耗Pod
echo -e "\n=== CPU使用Top 10 Pod ==="
kubectl top pods -A --sort-by=cpu 2>/dev/null | head -11

echo -e "\n=== 内存使用Top 10 Pod ==="
kubectl top pods -A --sort-by=memory 2>/dev/null | head -11

# 4. Pending Pod
echo -e "\n=== Pending Pods ==="
kubectl get pods -A --field-selector=status.phase=Pending

# 5. 重启次数高的Pod
echo -e "\n=== 高重启次数Pod ==="
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.restartCount}{"\t"}{end}{"\n"}{end}' | awk -F'\t' '$3 > 5 {print $0}' | sort -t$'\t' -k3 -nr | head -10

# 6. 事件频率
echo -e "\n=== 最近1小时高频事件 ==="
kubectl get events -A --sort-by='.count' | tail -20
```

---

## 集群升级故障排查

### 升级故障矩阵

| 故障症状 | 根因分类 | 诊断命令 | 版本特性 | 解决方案 | 生产预防措施 |
|:---|:---|:---|:---|:---|:---|
| **控制平面升级失败** | kubeadm/组件问题 | `kubeadm upgrade plan`, 组件日志 | - | 检查兼容性，逐步升级 | 升级前备份 |
| **节点升级失败** | kubelet/运行时问题 | `systemctl status kubelet`, `journalctl -u kubelet` | - | 检查kubelet日志 | 节点升级SOP |
| **API版本废弃** | 使用了废弃API | `kubectl deprecations` (第三方工具) | 版本特定 | 更新资源manifest | API兼容性检查 |
| **Webhook不兼容** | 准入控制器版本问题 | 检查ValidatingWebhookConfiguration | - | 升级Webhook组件 | Webhook兼容性测试 |
| **CNI不兼容** | CNI版本不匹配 | CNI Pod日志 | - | 升级CNI | CNI兼容性矩阵 |
| **存储驱动问题** | CSI版本不兼容 | CSI Pod日志 | - | 升级CSI驱动 | CSI兼容性检查 |

#### 升级前检查脚本

```bash
#!/bin/bash
# upgrade-precheck.sh - 升级前检查

TARGET_VERSION=${1:-"v1.32"}

echo "=== 升级预检查报告 ==="
echo "目标版本: $TARGET_VERSION"

# 1. 当前版本
echo -e "\n=== 当前集群版本 ==="
kubectl version --short 2>/dev/null || kubectl version

# 2. 节点版本
echo -e "\n=== 节点版本 ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion

# 3. etcd备份状态
echo -e "\n=== etcd备份检查 ==="
echo "请确认已执行etcd快照备份"

# 4. 控制平面健康
echo -e "\n=== 控制平面健康 ==="
kubectl get pods -n kube-system -l tier=control-plane

# 5. 废弃API检查
echo -e "\n=== 废弃API检查 ==="
echo "建议使用 kubectl deprecations 或 pluto 工具检查废弃API"

# 6. PDB检查
echo -e "\n=== PodDisruptionBudget ==="
kubectl get pdb -A

# 7. 节点可驱逐性
echo -e "\n=== 节点Pod分布 ==="
for node in $(kubectl get nodes -o name | cut -d'/' -f2); do
  count=$(kubectl get pods -A --field-selector spec.nodeName=$node --no-headers | wc -l)
  echo "$node: $count pods"
done
```

---

## 版本特定已知问题

### v1.32 已知问题与注意事项

| 问题类型 | 描述 | 影响范围 | 解决方案 |
|:---|:---|:---|:---|
| **Feature Gate变更** | 部分Alpha特性默认禁用变更 | 使用相关特性的集群 | 检查Feature Gate配置 |
| **API废弃** | flowcontrol.apiserver.k8s.io/v1beta3 废弃 | APF配置 | 迁移到v1 |

### v1.31 已知问题与注意事项

| 问题类型 | 描述 | 影响范围 | 解决方案 |
|:---|:---|:---|:---|
| **Kubelet内存管理** | 内存管理器增强 | 内存敏感应用 | 测试内存限制行为 |
| **AppArmor GA** | AppArmor字段格式变更 | 使用AppArmor的Pod | 更新配置格式 |

### v1.30 已知问题与注意事项

| 问题类型 | 描述 | 影响范围 | 解决方案 |
|:---|:---|:---|:---|
| **VolumeAttributesClass** | 存储参数动态调整Beta | 高级存储场景 | 测试使用 |
| **Pod调度就绪** | Pod调度就绪条件增强 | 调度控制场景 | 理解新调度行为 |

### v1.29 已知问题与注意事项

| 问题类型 | 描述 | 影响范围 | 解决方案 |
|:---|:---|:---|:---|
| **nftables支持** | kube-proxy nftables模式Beta | 网络代理 | 测试nftables模式 |
| **APF增强** | 流控API v1正式发布 | API限流配置 | 迁移FlowSchema配置 |

### v1.28 已知问题与注意事项

| 问题类型 | 描述 | 影响范围 | 解决方案 |
|:---|:---|:---|:---|
| **Native Sidecar** | 原生Sidecar容器支持 | Sidecar应用场景 | 测试restartPolicy: Always |
| **ValidatingAdmissionPolicy** | CEL验证策略Beta | 准入控制 | 测试迁移方案 |

### v1.27 已知问题与注意事项

| 问题类型 | 描述 | 影响范围 | 解决方案 |
|:---|:---|:---|:---|
| **就地Pod调整** | Pod资源可动态调整(Alpha) | 资源管理 | 启用Feature Gate测试 |
| **证书轮换GA** | kubelet证书自动轮换 | 证书管理 | 确认自动轮换启用 |

### v1.26 已知问题与注意事项

| 问题类型 | 描述 | 影响范围 | 解决方案 |
|:---|:---|:---|:---|
| **优雅关机GA** | 节点优雅关机正式发布 | 节点维护 | 配置shutdownGracePeriod |
| **调度器优化** | 调度器性能改进 | 大规模集群 | 利用调度器改进 |

### v1.25 已知问题与注意事项

| 问题类型 | 描述 | 影响范围 | 解决方案 |
|:---|:---|:---|:---|
| **PSP移除** | PodSecurityPolicy完全移除 | 安全策略 | 迁移到PSS |
| **Ephemeral Containers GA** | 临时容器正式发布 | Pod调试 | 使用kubectl debug |
| **CronJob时区** | 时区支持正式发布 | 定时任务 | 配置.spec.timeZone |

---

## 生产级诊断工具集

### 综合诊断脚本

```bash
#!/bin/bash
# k8s-full-diagnose.sh - Kubernetes生产环境综合诊断

set -e

NAMESPACE=${1:-""}
OUTPUT_DIR="/tmp/k8s-diagnose-$(date +%Y%m%d-%H%M%S)"
mkdir -p $OUTPUT_DIR

echo "=== Kubernetes 综合诊断报告 ==="
echo "输出目录: $OUTPUT_DIR"
echo "开始时间: $(date)"

# 1. 集群基础信息
echo -e "\n[1/10] 收集集群基础信息..."
{
  echo "=== Cluster Info ==="
  kubectl cluster-info
  echo -e "\n=== Server Version ==="
  kubectl version --short 2>/dev/null || kubectl version
  echo -e "\n=== API Resources ==="
  kubectl api-resources --verbs=list --no-headers | wc -l
} > $OUTPUT_DIR/01-cluster-info.txt

# 2. 节点状态
echo "[2/10] 收集节点状态..."
{
  echo "=== Nodes ==="
  kubectl get nodes -o wide
  echo -e "\n=== Node Conditions ==="
  kubectl get nodes -o custom-columns=NAME:.metadata.name,READY:.status.conditions[-1].status,PRESSURE:.status.conditions[0].status,.status.conditions[1].status,.status.conditions[2].status
  echo -e "\n=== Node Resources ==="
  kubectl top nodes 2>/dev/null || echo "Metrics Server未安装"
} > $OUTPUT_DIR/02-nodes.txt

# 3. 控制平面
echo "[3/10] 收集控制平面状态..."
{
  echo "=== Control Plane Pods ==="
  kubectl get pods -n kube-system -l tier=control-plane -o wide
  echo -e "\n=== Health Check ==="
  kubectl get --raw='/healthz?verbose' 2>/dev/null | head -30 || kubectl get --raw='/healthz'
  echo -e "\n=== Readiness Check ==="
  kubectl get --raw='/readyz?verbose' 2>/dev/null | head -30 || kubectl get --raw='/readyz'
} > $OUTPUT_DIR/03-control-plane.txt

# 4. 异常Pod
echo "[4/10] 收集异常Pod..."
{
  echo "=== Non-Running Pods ==="
  kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded -o wide
  echo -e "\n=== High Restart Pods ==="
  kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.restartCount}{"\t"}{end}{"\n"}{end}' | awk -F'\t' '$3 > 3 {print $0}' | sort -t$'\t' -k3 -nr | head -20
} > $OUTPUT_DIR/04-problem-pods.txt

# 5. 事件
echo "[5/10] 收集事件..."
{
  echo "=== Recent Warning Events ==="
  kubectl get events -A --field-selector type=Warning --sort-by='.lastTimestamp' | tail -50
} > $OUTPUT_DIR/05-events.txt

# 6. 网络
echo "[6/10] 收集网络状态..."
{
  echo "=== CoreDNS ==="
  kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
  echo -e "\n=== Services (ClusterIP Issues) ==="
  kubectl get svc -A | grep -v ClusterIP | grep -v TYPE
  echo -e "\n=== Ingress ==="
  kubectl get ingress -A 2>/dev/null || echo "无Ingress资源"
} > $OUTPUT_DIR/06-network.txt

# 7. 存储
echo "[7/10] 收集存储状态..."
{
  echo "=== StorageClasses ==="
  kubectl get sc
  echo -e "\n=== Unbound PVCs ==="
  kubectl get pvc -A | grep -v Bound
  echo -e "\n=== Released/Failed PVs ==="
  kubectl get pv | grep -E "Released|Failed"
} > $OUTPUT_DIR/07-storage.txt

# 8. 安全
echo "[8/10] 收集安全配置..."
{
  echo "=== Namespace PSS Labels ==="
  kubectl get ns -o custom-columns=NAME:.metadata.name,PSS:.metadata.labels.pod-security\\.kubernetes\\.io/enforce
  echo -e "\n=== ClusterRoleBindings (cluster-admin) ==="
  kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | "\(.metadata.name): \(.subjects)"'
} > $OUTPUT_DIR/08-security.txt

# 9. 资源使用
echo "[9/10] 收集资源使用..."
{
  echo "=== ResourceQuotas ==="
  kubectl get quota -A
  echo -e "\n=== LimitRanges ==="
  kubectl get limitrange -A
  echo -e "\n=== Top Pods by CPU ==="
  kubectl top pods -A --sort-by=cpu 2>/dev/null | head -20 || echo "Metrics未安装"
} > $OUTPUT_DIR/09-resources.txt

# 10. 特定namespace(如指定)
if [ -n "$NAMESPACE" ]; then
  echo "[10/10] 收集namespace $NAMESPACE 详情..."
  {
    echo "=== Namespace: $NAMESPACE ==="
    kubectl get all -n $NAMESPACE -o wide
    echo -e "\n=== Events ==="
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'
    echo -e "\n=== Pod Logs (last 50 lines each) ==="
    for pod in $(kubectl get pods -n $NAMESPACE -o name | head -5); do
      echo "--- $pod ---"
      kubectl logs $pod -n $NAMESPACE --tail=50 2>/dev/null || echo "无法获取日志"
    done
  } > $OUTPUT_DIR/10-namespace-$NAMESPACE.txt
else
  echo "[10/10] 未指定namespace，跳过详细收集"
fi

# 打包
echo -e "\n=== 诊断完成 ==="
echo "报告目录: $OUTPUT_DIR"
tar -czf $OUTPUT_DIR.tar.gz -C /tmp $(basename $OUTPUT_DIR)
echo "压缩包: $OUTPUT_DIR.tar.gz"
echo "完成时间: $(date)"
```

### 实时监控脚本

```bash
#!/bin/bash
# k8s-realtime-monitor.sh - 实时监控脚本

watch -n 5 '
echo "=== $(date) ==="
echo ""
echo "=== 节点状态 ==="
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,READY:.status.conditions[-1].status,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory

echo ""
echo "=== 异常Pod ==="
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers | head -10

echo ""
echo "=== 最近事件 ==="
kubectl get events -A --field-selector type=Warning --sort-by=".lastTimestamp" --no-headers | tail -5
'
```

### kubectl debug高级用法

```bash
# 1. 调试运行中的Pod(临时容器)
kubectl debug <pod-name> -it --image=busybox --target=<container-name>

# 2. 调试节点(v1.25+ GA)
kubectl debug node/<node-name> -it --image=busybox

# 3. 创建Pod副本进行调试
kubectl debug <pod-name> -it --copy-to=debug-pod --container=debug --image=busybox

# 4. 调试CrashLoopBackOff的Pod(修改命令)
kubectl debug <pod-name> -it --copy-to=debug-pod --container=app -- sh

# 5. 使用网络诊断镜像
kubectl debug <pod-name> -it --image=nicolaka/netshoot --target=<container-name>
```

---

## 监控告警集成

### 关键Prometheus告警规则

```yaml
# kubernetes-troubleshooting-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kubernetes-troubleshooting-alerts
  namespace: monitoring
spec:
  groups:
  - name: kubernetes-pod-alerts
    rules:
    # Pod异常告警
    - alert: KubernetesPodCrashLooping
      expr: |
        increase(kube_pod_container_status_restarts_total[1h]) > 5
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} 频繁重启"
        description: "Pod在过去1小时内重启超过5次"
    
    - alert: KubernetesPodNotReady
      expr: |
        kube_pod_status_ready{condition="false"} == 1
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} 未就绪"
        description: "Pod持续15分钟未进入Ready状态"
    
    # 节点告警
    - alert: KubernetesNodeNotReady
      expr: |
        kube_node_status_condition{condition="Ready",status="true"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "节点 {{ $labels.node }} NotReady"
        description: "节点持续5分钟处于NotReady状态"
    
    - alert: KubernetesNodeMemoryPressure
      expr: |
        kube_node_status_condition{condition="MemoryPressure",status="true"} == 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "节点 {{ $labels.node }} 内存压力"
        description: "节点处于MemoryPressure状态"
    
    - alert: KubernetesNodeDiskPressure
      expr: |
        kube_node_status_condition{condition="DiskPressure",status="true"} == 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "节点 {{ $labels.node }} 磁盘压力"
        description: "节点处于DiskPressure状态"
    
    # 控制平面告警
    - alert: KubernetesAPIServerLatencyHigh
      expr: |
        histogram_quantile(0.99, sum(rate(apiserver_request_duration_seconds_bucket{verb!~"WATCH|CONNECT"}[5m])) by (verb, resource, le)) > 1
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "API Server延迟过高"
        description: "API请求P99延迟超过1秒"
    
    - alert: KubernetesAPIServerErrors
      expr: |
        sum(rate(apiserver_request_total{code=~"5.."}[5m])) / sum(rate(apiserver_request_total[5m])) > 0.01
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "API Server错误率过高"
        description: "API Server 5xx错误率超过1%"
    
    # etcd告警
    - alert: EtcdHighCommitDurations
      expr: |
        histogram_quantile(0.99, rate(etcd_disk_backend_commit_duration_seconds_bucket[5m])) > 0.25
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "etcd提交延迟过高"
        description: "etcd磁盘提交P99延迟超过250ms"
    
    - alert: EtcdInsufficientMembers
      expr: |
        count(etcd_server_has_leader) < 3
      for: 3m
      labels:
        severity: critical
      annotations:
        summary: "etcd成员不足"
        description: "etcd集群成员少于3个"
    
    # 存储告警
    - alert: KubernetesPVCPending
      expr: |
        kube_persistentvolumeclaim_status_phase{phase="Pending"} == 1
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} Pending"
        description: "PVC持续15分钟处于Pending状态"
    
    # 调度告警
    - alert: KubernetesPodSchedulingFailed
      expr: |
        sum(kube_pod_status_phase{phase="Pending"}) by (namespace, pod) > 0
        and on(namespace, pod) 
        sum(kube_pod_status_scheduled{condition="false"}) by (namespace, pod) > 0
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} 调度失败"
        description: "Pod持续15分钟无法调度"
```

### Grafana Dashboard关键面板

```json
{
  "title": "Kubernetes Troubleshooting Dashboard",
  "panels": [
    {
      "title": "问题Pod统计",
      "type": "stat",
      "targets": [
        {
          "expr": "count(kube_pod_status_phase{phase=~\"Pending|Failed|Unknown\"}) or vector(0)",
          "legendFormat": "问题Pod数"
        }
      ]
    },
    {
      "title": "NotReady节点",
      "type": "stat",
      "targets": [
        {
          "expr": "count(kube_node_status_condition{condition=\"Ready\",status!=\"true\"}) or vector(0)",
          "legendFormat": "NotReady节点数"
        }
      ]
    },
    {
      "title": "Pod重启Top10",
      "type": "table",
      "targets": [
        {
          "expr": "topk(10, sum(increase(kube_pod_container_status_restarts_total[1h])) by (namespace, pod))",
          "format": "table"
        }
      ]
    },
    {
      "title": "API Server错误率",
      "type": "graph",
      "targets": [
        {
          "expr": "sum(rate(apiserver_request_total{code=~\"5..\"}[5m])) / sum(rate(apiserver_request_total[5m])) * 100",
          "legendFormat": "5xx错误率%"
        }
      ]
    },
    {
      "title": "etcd延迟",
      "type": "graph",
      "targets": [
        {
          "expr": "histogram_quantile(0.99, rate(etcd_disk_backend_commit_duration_seconds_bucket[5m]))",
          "legendFormat": "P99延迟"
        }
      ]
    }
  ]
}
```

---

## 生产SOP流程

### 故障响应流程

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           故障响应SOP流程                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. 告警触发 ─────────────────────────────────────────────────────────────  │
│     │                                                                       │
│     ▼                                                                       │
│  2. 影响评估 (P0/P1/P2/P3)                                                  │
│     │  P0: 全局不可用      P1: 核心功能受损                                 │
│     │  P2: 部分功能受损    P3: 边缘功能受损                                 │
│     ▼                                                                       │
│  3. 初步诊断 (5分钟内)                                                      │
│     │  - 集群状态: kubectl cluster-info                                    │
│     │  - 节点状态: kubectl get nodes                                       │
│     │  - 问题Pod: kubectl get pods -A (异常过滤)                           │
│     ▼                                                                       │
│  4. 快速恢复 (优先恢复服务)                                                  │
│     │  - 扩容/重启                                                          │
│     │  - 回滚                                                               │
│     │  - 流量切换                                                           │
│     ▼                                                                       │
│  5. 根因分析 (服务恢复后)                                                    │
│     │  - 日志分析                                                           │
│     │  - 指标关联                                                           │
│     │  - 变更审计                                                           │
│     ▼                                                                       │
│  6. 复盘与预防                                                               │
│     │  - 故障报告                                                           │
│     │  - 监控补充                                                           │
│     │  - 预防措施                                                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 快速恢复Checklist

| 场景 | 快速恢复操作 | 预估恢复时间 |
|:---|:---|:---:|
| **单Pod故障** | `kubectl delete pod <pod>` 触发重建 | <1min |
| **Deployment异常** | `kubectl rollout undo deployment/<name>` | <5min |
| **节点NotReady** | `kubectl drain/uncordon` 或重启kubelet | 5-15min |
| **控制平面故障** | 重启控制平面组件，或切换到备节点 | 5-30min |
| **etcd故障** | 从备份恢复，或剔除故障成员 | 10-60min |
| **网络全局故障** | 重启CNI，检查配置 | 5-30min |
| **存储挂载故障** | 重启CSI驱动，检查后端存储 | 10-30min |

### 值班工程师快速参考

```bash
# ========== 紧急故障快速诊断命令 ==========

# 1. 快速检查集群状态
kubectl cluster-info && kubectl get nodes && kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded | head -20

# 2. 最近关键事件
kubectl get events -A --field-selector type=Warning --sort-by='.lastTimestamp' | tail -20

# 3. 控制平面健康
kubectl get --raw='/healthz?verbose' | grep -v "^+"

# 4. 问题Pod快速定位
kubectl get pods -A -o wide | grep -vE "Running|Completed"

# 5. 高重启Pod
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {range .status.containerStatuses[*]}{.restartCount}{" "}{end}{"\n"}{end}' | awk -F': ' '$2 > 3'

# 6. 节点资源压力
kubectl describe nodes | grep -A 5 "Conditions:"

# 7. DNS快速测试
kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never -- nslookup kubernetes.default

# 8. 快速回滚
kubectl rollout undo deployment/<name> -n <namespace>

# 9. 强制删除卡住的Pod
kubectl delete pod <pod> -n <namespace> --grace-period=0 --force

# 10. 节点维护
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl uncordon <node>
```

---

**排查黄金法则**:
1. 先看Events(发生了什么)
2. 再看Logs(为什么发生)
3. 然后Describe(当前状态)
4. 最后Metrics(趋势分析)

**生产环境原则**:
- 优先恢复服务，再分析根因
- 变更必须可回滚
- 所有操作必须有审计记录
- 故障必须复盘并预防

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)
