# 36 - 集群健康检查表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/tasks/debug/debug-cluster](https://kubernetes.io/docs/tasks/debug/debug-cluster/)

## 集群健康检查架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Kubernetes 集群健康检查体系                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     Layer 1: 控制平面健康                            │  │
│   │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │  │
│   │  │ API Server  │ │    etcd     │ │ Scheduler   │ │ Controller  │   │  │
│   │  │  /healthz   │ │ /health     │ │ /healthz    │ │  Manager    │   │  │
│   │  │  /readyz    │ │ /readiness  │ │             │ │  /healthz   │   │  │
│   │  │  /livez     │ │             │ │             │ │             │   │  │
│   │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                        │                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     Layer 2: 节点健康                                │  │
│   │  ┌────────────────────────────────────────────────────────────┐    │  │
│   │  │                     Worker Node                             │    │  │
│   │  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │    │  │
│   │  │  │   kubelet   │ │ containerd  │ │ kube-proxy  │           │    │  │
│   │  │  │  /healthz   │ │  systemctl  │ │  /healthz   │           │    │  │
│   │  │  └─────────────┘ └─────────────┘ └─────────────┘           │    │  │
│   │  │  ┌────────────────────────────────────────────────────┐    │    │  │
│   │  │  │ Node Conditions:                                    │    │    │  │
│   │  │  │ Ready | MemoryPressure | DiskPressure | PIDPressure│    │    │  │
│   │  │  └────────────────────────────────────────────────────┘    │    │  │
│   │  └────────────────────────────────────────────────────────────┘    │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                        │                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     Layer 3: 网络健康                                │  │
│   │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │  │
│   │  │   CoreDNS   │ │    CNI      │ │  Ingress    │ │ NetworkPolicy│  │  │
│   │  │  DNS解析    │ │ Pod网络     │ │ 入口流量    │ │ 网络策略    │   │  │
│   │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                        │                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     Layer 4: 存储健康                                │  │
│   │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │  │
│   │  │ PV/PVC状态  │ │ StorageClass│ │ CSI Driver  │ │ 后端存储    │   │  │
│   │  │ Bound/      │ │ Provisioner │ │ 健康检查    │ │ 连通性      │   │  │
│   │  │ Available   │ │ 可用性      │ │             │ │             │   │  │
│   │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                        │                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     Layer 5: 工作负载健康                            │  │
│   │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │  │
│   │  │  Pod状态    │ │ Deployment  │ │ StatefulSet │ │  DaemonSet  │   │  │
│   │  │ Running/    │ │ 副本数      │ │ 有序更新    │ │ 节点覆盖    │   │  │
│   │  │ Pending     │ │ 就绪状态    │ │             │ │             │   │  │
│   │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 控制平面健康检查

### API Server健康检查矩阵

| 端点 | 用途 | 检查内容 | 预期响应 | 版本变更 |
|-----|------|---------|---------|---------|
| `/healthz` | 存活检查 | API Server是否存活 | `ok` | 稳定 |
| `/livez` | 存活探针 | 进程是否存活 | `ok` | v1.16+ |
| `/readyz` | 就绪探针 | 是否可以处理请求 | `ok` | v1.16+ |
| `/readyz?verbose` | 详细就绪 | 所有子系统状态 | 各项检查状态 | v1.28增强 |
| `/healthz/etcd` | etcd连接 | etcd后端健康 | `ok` | 稳定 |
| `/healthz/poststarthook/*` | 启动钩子 | 各启动钩子状态 | `ok` | 稳定 |

### 控制平面检查命令

```bash
#!/bin/bash
# control-plane-health-check.sh

echo "====== 控制平面健康检查 ======"
echo "时间: $(date)"
echo ""

# 1. API Server健康检查
echo "=== 1. API Server健康状态 ==="
echo "基础健康: $(kubectl get --raw='/healthz' 2>/dev/null || echo 'FAILED')"
echo "存活检查: $(kubectl get --raw='/livez' 2>/dev/null || echo 'FAILED')"
echo "就绪检查: $(kubectl get --raw='/readyz' 2>/dev/null || echo 'FAILED')"

# 详细就绪检查
echo -e "\n--- /readyz 详细状态 ---"
kubectl get --raw='/readyz?verbose' 2>/dev/null | grep -E "^\[|\-\]" | head -20

# 2. etcd健康检查
echo -e "\n=== 2. etcd健康状态 ==="
echo "etcd健康: $(kubectl get --raw='/healthz/etcd' 2>/dev/null || echo 'FAILED')"

# 如果可以访问etcd
if command -v etcdctl &> /dev/null; then
    export ETCDCTL_API=3
    ETCD_ENDPOINTS=${ETCD_ENDPOINTS:-"https://127.0.0.1:2379"}
    ETCD_CACERT=${ETCD_CACERT:-"/etc/kubernetes/pki/etcd/ca.crt"}
    ETCD_CERT=${ETCD_CERT:-"/etc/kubernetes/pki/etcd/healthcheck-client.crt"}
    ETCD_KEY=${ETCD_KEY:-"/etc/kubernetes/pki/etcd/healthcheck-client.key"}
    
    echo -e "\n--- etcd endpoint状态 ---"
    etcdctl --endpoints="$ETCD_ENDPOINTS" \
            --cacert="$ETCD_CACERT" \
            --cert="$ETCD_CERT" \
            --key="$ETCD_KEY" \
            endpoint health 2>/dev/null || echo "无法连接etcd"
            
    echo -e "\n--- etcd成员列表 ---"
    etcdctl --endpoints="$ETCD_ENDPOINTS" \
            --cacert="$ETCD_CACERT" \
            --cert="$ETCD_CERT" \
            --key="$ETCD_KEY" \
            member list 2>/dev/null || echo "无法获取成员列表"
fi

# 3. Scheduler健康检查
echo -e "\n=== 3. Scheduler健康状态 ==="
kubectl get --raw='/healthz/kube-scheduler' 2>/dev/null || \
kubectl get pods -n kube-system -l component=kube-scheduler -o wide

# 4. Controller Manager健康检查
echo -e "\n=== 4. Controller Manager健康状态 ==="
kubectl get --raw='/healthz/kube-controller-manager' 2>/dev/null || \
kubectl get pods -n kube-system -l component=kube-controller-manager -o wide

# 5. 组件状态(已弃用但仍可用)
echo -e "\n=== 5. 组件状态(componentstatuses) ==="
kubectl get componentstatuses 2>/dev/null || echo "componentstatuses API已弃用"

# 6. kube-system核心组件Pod
echo -e "\n=== 6. kube-system核心Pod状态 ==="
kubectl get pods -n kube-system -o wide | grep -E "etcd|apiserver|scheduler|controller"
```

### etcd深度健康检查

```bash
#!/bin/bash
# etcd-health-check.sh

echo "====== etcd深度健康检查 ======"

export ETCDCTL_API=3
ETCD_ENDPOINTS=${ETCD_ENDPOINTS:-"https://127.0.0.1:2379"}
ETCD_CACERT=${ETCD_CACERT:-"/etc/kubernetes/pki/etcd/ca.crt"}
ETCD_CERT=${ETCD_CERT:-"/etc/kubernetes/pki/etcd/healthcheck-client.crt"}
ETCD_KEY=${ETCD_KEY:-"/etc/kubernetes/pki/etcd/healthcheck-client.key"}

ETCD_OPTS="--endpoints=$ETCD_ENDPOINTS --cacert=$ETCD_CACERT --cert=$ETCD_CERT --key=$ETCD_KEY"

# 1. 集群健康
echo "=== 1. 集群健康状态 ==="
etcdctl $ETCD_OPTS endpoint health --cluster

# 2. 集群状态
echo -e "\n=== 2. 集群状态 ==="
etcdctl $ETCD_OPTS endpoint status --cluster -w table

# 3. 成员列表
echo -e "\n=== 3. 成员列表 ==="
etcdctl $ETCD_OPTS member list -w table

# 4. 数据库大小
echo -e "\n=== 4. 数据库大小 ==="
etcdctl $ETCD_OPTS endpoint status --cluster -w json | jq -r '.[] | "\(.Endpoint): \(.Status.dbSize / 1024 / 1024 | floor) MB"'

# 5. Leader信息
echo -e "\n=== 5. Leader信息 ==="
etcdctl $ETCD_OPTS endpoint status --cluster -w json | jq -r '.[] | select(.Status.leader == .Status.header.member_id) | "Leader: \(.Endpoint)"'

# 6. 告警检查
echo -e "\n=== 6. 告警检查 ==="
etcdctl $ETCD_OPTS alarm list

# 7. 键数量
echo -e "\n=== 7. 键数量统计 ==="
echo "总键数: $(etcdctl $ETCD_OPTS get / --prefix --keys-only 2>/dev/null | wc -l)"

# 8. 性能检查
echo -e "\n=== 8. 性能检查(读写延迟) ==="
etcdctl $ETCD_OPTS check perf --load="s" 2>/dev/null || echo "性能检查不可用"
```

## 节点健康检查

### Node Condition状态详解

| Condition | True含义 | False含义 | Unknown含义 | 检查方法 |
|----------|---------|----------|------------|---------|
| **Ready** | 节点健康可调度 | 节点不健康 | kubelet停止上报 | kubelet状态 |
| **MemoryPressure** | 内存低于阈值 | 内存充足 | - | free -h |
| **DiskPressure** | 磁盘空间不足 | 磁盘充足 | - | df -h |
| **PIDPressure** | PID接近限制 | PID充足 | - | ps aux \| wc -l |
| **NetworkUnavailable** | 网络未配置 | 网络正常 | - | CNI状态 |

### 节点健康检查命令

```bash
#!/bin/bash
# node-health-check.sh

echo "====== 节点健康检查 ======"
echo "时间: $(date)"
echo ""

# 1. 节点总体状态
echo "=== 1. 节点状态概览 ==="
kubectl get nodes -o wide
echo ""
echo "Ready节点: $(kubectl get nodes --no-headers | grep " Ready" | wc -l)"
echo "NotReady节点: $(kubectl get nodes --no-headers | grep -v " Ready" | wc -l)"

# 2. 节点Conditions详情
echo -e "\n=== 2. 节点Conditions ==="
kubectl get nodes -o json | jq -r '
.items[] | 
"\(.metadata.name):" + 
(.status.conditions | map("\n  \(.type): \(.status)") | join(""))'

# 3. 节点资源使用
echo -e "\n=== 3. 节点资源使用 ==="
kubectl top nodes 2>/dev/null || echo "Metrics Server未安装"

# 4. 节点资源分配情况
echo -e "\n=== 4. 节点资源分配 ==="
for node in $(kubectl get nodes -o name); do
    echo "--- $node ---"
    kubectl describe $node | grep -A 10 "Allocated resources:"
    echo ""
done

# 5. 节点Taints
echo -e "\n=== 5. 节点Taints ==="
kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name): \(.spec.taints // "无taint")"'

# 6. 异常节点详情
echo -e "\n=== 6. 异常节点详情 ==="
for node in $(kubectl get nodes --no-headers | grep -v " Ready" | awk '{print $1}'); do
    echo "=== 异常节点: $node ==="
    kubectl describe node $node | grep -A 20 "Conditions:"
done
```

### 节点内部健康检查

```bash
#!/bin/bash
# node-internal-health.sh (在节点上执行)

echo "====== 节点内部健康检查 ======"
echo "主机名: $(hostname)"
echo "时间: $(date)"
echo ""

# 1. 系统服务状态
echo "=== 1. 关键服务状态 ==="
for svc in kubelet containerd; do
    status=$(systemctl is-active $svc 2>/dev/null)
    echo "$svc: $status"
done

# 2. kubelet健康
echo -e "\n=== 2. kubelet健康检查 ==="
curl -sk https://localhost:10250/healthz 2>/dev/null || echo "kubelet healthz不可访问"

# 3. 容器运行时
echo -e "\n=== 3. 容器运行时状态 ==="
crictl info 2>/dev/null | head -20 || echo "crictl不可用"

# 4. 系统资源
echo -e "\n=== 4. 系统资源 ==="
echo "--- 内存 ---"
free -h
echo -e "\n--- 磁盘 ---"
df -h | grep -E "Filesystem|^/dev"
echo -e "\n--- CPU负载 ---"
uptime

# 5. 进程数
echo -e "\n=== 5. 进程状态 ==="
echo "当前进程数: $(ps aux | wc -l)"
echo "僵尸进程: $(ps aux | grep -c "Z")"

# 6. 网络状态
echo -e "\n=== 6. 网络状态 ==="
ip addr show | grep -E "^[0-9]+:|inet " | head -10
echo ""
echo "默认路由: $(ip route show default)"

# 7. 时间同步
echo -e "\n=== 7. 时间同步 ==="
timedatectl status | grep -E "Local time|System clock|NTP"

# 8. 内核日志错误
echo -e "\n=== 8. 最近内核错误 ==="
dmesg | tail -50 | grep -iE "error|fail|warn|oom" | tail -10
```

## Pod健康检查

### Pod状态检查矩阵

| 状态 | 含义 | 常见原因 | 排查方向 |
|-----|------|---------|---------|
| **Pending** | 等待调度 | 资源不足/亲和性/PVC | kubectl describe pod |
| **Running** | 正常运行 | - | 检查容器状态 |
| **Succeeded** | 成功完成 | Job/一次性任务 | - |
| **Failed** | 失败 | 容器退出非0 | kubectl logs |
| **Unknown** | 状态未知 | 节点不可达 | 检查节点状态 |
| **CrashLoopBackOff** | 反复崩溃 | 应用错误/配置问题 | kubectl logs --previous |
| **ImagePullBackOff** | 拉取镜像失败 | 镜像不存在/认证失败 | 检查镜像和密钥 |
| **ContainerCreating** | 创建中 | 等待资源/挂载卷 | kubectl describe pod |

### Pod健康检查命令

```bash
#!/bin/bash
# pod-health-check.sh

NAMESPACE=${1:-"--all-namespaces"}

echo "====== Pod健康检查 ======"
echo "命名空间: $NAMESPACE"
echo "时间: $(date)"
echo ""

# 1. Pod状态统计
echo "=== 1. Pod状态统计 ==="
if [ "$NAMESPACE" == "--all-namespaces" ]; then
    kubectl get pods -A --no-headers | awk '{print $4}' | sort | uniq -c | sort -rn
else
    kubectl get pods -n "$NAMESPACE" --no-headers | awk '{print $3}' | sort | uniq -c | sort -rn
fi

# 2. 问题Pod列表
echo -e "\n=== 2. 问题Pod列表 ==="
kubectl get pods $NAMESPACE --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | head -20

# 3. 高重启Pod
echo -e "\n=== 3. 高重启Pod(>3次) ==="
kubectl get pods $NAMESPACE -o json | jq -r '
.items[] | 
select(.status.containerStatuses != null) |
select([.status.containerStatuses[].restartCount] | add > 3) |
"\(.metadata.namespace)/\(.metadata.name): \([.status.containerStatuses[].restartCount] | add) 次重启"' | head -20

# 4. 未就绪Pod
echo -e "\n=== 4. 未就绪Pod ==="
kubectl get pods $NAMESPACE -o json | jq -r '
.items[] |
select(.status.containerStatuses != null) |
select([.status.containerStatuses[].ready] | all | not) |
"\(.metadata.namespace)/\(.metadata.name): 未就绪"' | head -20

# 5. Pending Pod详情
echo -e "\n=== 5. Pending Pod ==="
for pod in $(kubectl get pods $NAMESPACE --field-selector=status.phase=Pending -o name 2>/dev/null | head -5); do
    echo "--- $pod ---"
    kubectl describe $pod 2>/dev/null | grep -A 10 "Events:" | tail -5
done

# 6. 最近失败事件
echo -e "\n=== 6. 最近Pod Warning事件 ==="
kubectl get events $NAMESPACE --field-selector=type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -20
```

### Pod资源使用检查

```bash
#!/bin/bash
# pod-resource-check.sh

echo "====== Pod资源使用检查 ======"

# 1. 内存使用Top10
echo "=== 1. 内存使用Top10 Pod ==="
kubectl top pods -A --sort-by=memory 2>/dev/null | head -11

# 2. CPU使用Top10
echo -e "\n=== 2. CPU使用Top10 Pod ==="
kubectl top pods -A --sort-by=cpu 2>/dev/null | head -11

# 3. 内存使用率高的Pod
echo -e "\n=== 3. 内存使用率>80%的Pod ==="
kubectl get pods -A -o json | jq -r '
.items[] |
select(.spec.containers[].resources.limits.memory != null) |
"\(.metadata.namespace)/\(.metadata.name)"' | while read pod; do
    ns=$(echo $pod | cut -d'/' -f1)
    name=$(echo $pod | cut -d'/' -f2)
    usage=$(kubectl top pod $name -n $ns --no-headers 2>/dev/null | awk '{print $3}')
    limit=$(kubectl get pod $name -n $ns -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null)
    if [ -n "$usage" ] && [ -n "$limit" ]; then
        echo "$pod: $usage / $limit"
    fi
done 2>/dev/null | head -20

# 4. 无资源限制的Pod
echo -e "\n=== 4. 无内存限制的Pod ==="
kubectl get pods -A -o json | jq -r '
.items[] |
select(.status.phase == "Running") |
select(.spec.containers[].resources.limits.memory == null) |
"\(.metadata.namespace)/\(.metadata.name)"' | head -20
```

## 网络健康检查

### 网络组件检查

```bash
#!/bin/bash
# network-health-check.sh

echo "====== 网络健康检查 ======"
echo "时间: $(date)"
echo ""

# 1. CoreDNS状态
echo "=== 1. CoreDNS状态 ==="
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
kubectl get svc -n kube-system kube-dns

# 2. kube-proxy状态
echo -e "\n=== 2. kube-proxy状态 ==="
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide | head -10
kubectl get ds -n kube-system kube-proxy

# 3. CNI状态(以Calico为例)
echo -e "\n=== 3. CNI组件状态 ==="
# Calico
kubectl get pods -n kube-system -l k8s-app=calico-node -o wide 2>/dev/null | head -10
# Cilium
kubectl get pods -n kube-system -l k8s-app=cilium -o wide 2>/dev/null | head -10
# Flannel
kubectl get pods -n kube-system -l app=flannel -o wide 2>/dev/null | head -10

# 4. Service Endpoints
echo -e "\n=== 4. 无Endpoints的Service ==="
kubectl get endpoints -A -o json | jq -r '
.items[] |
select(.subsets == null or .subsets == []) |
"\(.metadata.namespace)/\(.metadata.name)"' | head -20

# 5. DNS解析测试
echo -e "\n=== 5. DNS解析测试 ==="
kubectl run dns-test --image=busybox:1.36 --rm -it --restart=Never --timeout=60s -- \
    nslookup kubernetes.default.svc.cluster.local 2>/dev/null || echo "DNS测试失败或超时"

# 6. NetworkPolicy数量
echo -e "\n=== 6. NetworkPolicy统计 ==="
kubectl get networkpolicy -A --no-headers 2>/dev/null | wc -l
```

### 网络连通性测试

```bash
#!/bin/bash
# network-connectivity-test.sh

echo "====== 网络连通性测试 ======"

# 创建测试Pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: network-test
  namespace: default
spec:
  containers:
  - name: test
    image: nicolaka/netshoot:latest
    command: ["sleep", "3600"]
EOF

echo "等待测试Pod就绪..."
kubectl wait --for=condition=Ready pod/network-test --timeout=120s

# 1. DNS测试
echo -e "\n=== 1. DNS解析测试 ==="
kubectl exec network-test -- nslookup kubernetes.default.svc.cluster.local
kubectl exec network-test -- nslookup google.com

# 2. Service访问测试
echo -e "\n=== 2. Kubernetes API访问 ==="
kubectl exec network-test -- curl -sk https://kubernetes.default.svc:443/healthz

# 3. 外部网络测试
echo -e "\n=== 3. 外部网络测试 ==="
kubectl exec network-test -- curl -s -o /dev/null -w "%{http_code}" https://www.google.com --connect-timeout 5 || echo "外部网络不可达"

# 4. 跨节点Pod通信
echo -e "\n=== 4. 跨节点通信测试 ==="
# 获取其他节点上的Pod IP
OTHER_POD_IP=$(kubectl get pods -A -o wide --no-headers | grep -v "$(kubectl get pod network-test -o jsonpath='{.spec.nodeName}')" | head -1 | awk '{print $7}')
if [ -n "$OTHER_POD_IP" ]; then
    kubectl exec network-test -- ping -c 3 $OTHER_POD_IP || echo "跨节点通信失败"
fi

# 清理
kubectl delete pod network-test --force --grace-period=0 2>/dev/null
```

## 存储健康检查

### 存储组件检查

```bash
#!/bin/bash
# storage-health-check.sh

echo "====== 存储健康检查 ======"
echo "时间: $(date)"
echo ""

# 1. StorageClass
echo "=== 1. StorageClass ==="
kubectl get sc
echo ""
DEFAULT_SC=$(kubectl get sc -o json | jq -r '.items[] | select(.metadata.annotations["storageclass.kubernetes.io/is-default-class"]=="true") | .metadata.name')
echo "默认StorageClass: ${DEFAULT_SC:-无}"

# 2. PV状态
echo -e "\n=== 2. PersistentVolume状态 ==="
kubectl get pv
echo ""
echo "PV状态统计:"
kubectl get pv -o json | jq -r '.items[].status.phase' | sort | uniq -c

# 3. PVC状态
echo -e "\n=== 3. PersistentVolumeClaim状态 ==="
kubectl get pvc -A
echo ""
echo "PVC状态统计:"
kubectl get pvc -A -o json | jq -r '.items[].status.phase' | sort | uniq -c

# 4. Pending PVC
echo -e "\n=== 4. Pending PVC ==="
kubectl get pvc -A --field-selector=status.phase=Pending --no-headers 2>/dev/null

# 5. Released PV(需要手动处理)
echo -e "\n=== 5. Released PV(待清理) ==="
kubectl get pv --field-selector=status.phase=Released --no-headers 2>/dev/null

# 6. CSI Driver
echo -e "\n=== 6. CSI Driver ==="
kubectl get csidrivers 2>/dev/null || echo "无CSI Driver"

# 7. VolumeAttachment
echo -e "\n=== 7. VolumeAttachment状态 ==="
kubectl get volumeattachment 2>/dev/null | head -10
```

## 安全健康检查

### 安全配置检查

```bash
#!/bin/bash
# security-health-check.sh

echo "====== 安全健康检查 ======"
echo "时间: $(date)"
echo ""

# 1. RBAC状态
echo "=== 1. RBAC状态 ==="
kubectl api-versions | grep -q "rbac.authorization.k8s.io" && echo "RBAC已启用" || echo "⚠️ RBAC未启用"

# 2. Pod Security Standards
echo -e "\n=== 2. Pod Security Standards ==="
kubectl get ns -L pod-security.kubernetes.io/enforce | grep -v "NAME"

# 3. ServiceAccount检查
echo -e "\n=== 3. 使用default SA的Pod ==="
kubectl get pods -A -o json | jq -r '
.items[] |
select(.spec.serviceAccountName == "default" or .spec.serviceAccountName == null) |
"\(.metadata.namespace)/\(.metadata.name)"' | head -20

# 4. 特权容器
echo -e "\n=== 4. 特权容器 ==="
kubectl get pods -A -o json | jq -r '
.items[] |
select(.spec.containers[].securityContext.privileged == true) |
"\(.metadata.namespace)/\(.metadata.name)"' | head -20

# 5. hostNetwork Pod
echo -e "\n=== 5. hostNetwork Pod ==="
kubectl get pods -A -o json | jq -r '
.items[] |
select(.spec.hostNetwork == true) |
"\(.metadata.namespace)/\(.metadata.name)"' | head -20

# 6. Secret检查
echo -e "\n=== 6. Secret统计 ==="
kubectl get secrets -A --no-headers | wc -l
echo "类型分布:"
kubectl get secrets -A -o json | jq -r '.items[].type' | sort | uniq -c | sort -rn | head -10

# 7. NetworkPolicy覆盖
echo -e "\n=== 7. NetworkPolicy覆盖 ==="
TOTAL_NS=$(kubectl get ns --no-headers | wc -l)
NS_WITH_NP=$(kubectl get networkpolicy -A -o json | jq -r '.items[].metadata.namespace' | sort -u | wc -l)
echo "有NetworkPolicy的命名空间: $NS_WITH_NP / $TOTAL_NS"
```

## 自动化健康检查脚本

### 完整健康检查脚本

```bash
#!/bin/bash
# k8s-full-health-check.sh - Kubernetes集群完整健康检查

set -e

OUTPUT_FILE=${1:-"/tmp/k8s-health-report-$(date +%Y%m%d-%H%M%S).txt"}

exec > >(tee -a "$OUTPUT_FILE") 2>&1

echo "============================================================"
echo "       Kubernetes 集群健康检查报告"
echo "============================================================"
echo "检查时间: $(date)"
echo "集群信息: $(kubectl cluster-info | head -1)"
echo "Kubernetes版本: $(kubectl version --short 2>/dev/null | grep Server || kubectl version -o json | jq -r '.serverVersion.gitVersion')"
echo ""

# 健康状态计数
WARNINGS=0
ERRORS=0

check_pass() {
    echo "[PASS] $1"
}

check_warn() {
    echo "[WARN] $1"
    ((WARNINGS++))
}

check_fail() {
    echo "[FAIL] $1"
    ((ERRORS++))
}

# ==================== 控制平面检查 ====================
echo ""
echo "==================== 1. 控制平面健康 ===================="

# API Server
API_HEALTH=$(kubectl get --raw='/healthz' 2>/dev/null || echo "failed")
if [ "$API_HEALTH" == "ok" ]; then
    check_pass "API Server健康"
else
    check_fail "API Server不健康"
fi

# etcd
ETCD_HEALTH=$(kubectl get --raw='/healthz/etcd' 2>/dev/null || echo "failed")
if [ "$ETCD_HEALTH" == "ok" ]; then
    check_pass "etcd健康"
else
    check_fail "etcd不健康"
fi

# Scheduler Pod
SCHEDULER_RUNNING=$(kubectl get pods -n kube-system -l component=kube-scheduler --no-headers 2>/dev/null | grep -c Running)
if [ "$SCHEDULER_RUNNING" -ge 1 ]; then
    check_pass "Scheduler运行中 ($SCHEDULER_RUNNING个实例)"
else
    check_fail "Scheduler未运行"
fi

# Controller Manager Pod
CM_RUNNING=$(kubectl get pods -n kube-system -l component=kube-controller-manager --no-headers 2>/dev/null | grep -c Running)
if [ "$CM_RUNNING" -ge 1 ]; then
    check_pass "Controller Manager运行中 ($CM_RUNNING个实例)"
else
    check_fail "Controller Manager未运行"
fi

# ==================== 节点检查 ====================
echo ""
echo "==================== 2. 节点健康 ===================="

TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
READY_NODES=$(kubectl get nodes --no-headers | grep " Ready" | wc -l)
NOTREADY_NODES=$((TOTAL_NODES - READY_NODES))

echo "总节点数: $TOTAL_NODES"
echo "Ready节点: $READY_NODES"
echo "NotReady节点: $NOTREADY_NODES"

if [ "$NOTREADY_NODES" -eq 0 ]; then
    check_pass "所有节点Ready"
else
    check_fail "存在 $NOTREADY_NODES 个NotReady节点"
    kubectl get nodes | grep -v " Ready"
fi

# 节点资源压力
PRESSURE_NODES=$(kubectl get nodes -o json | jq -r '.items[] | select(.status.conditions[] | select(.type != "Ready" and .status == "True")) | .metadata.name' | wc -l)
if [ "$PRESSURE_NODES" -eq 0 ]; then
    check_pass "无节点资源压力"
else
    check_warn "存在 $PRESSURE_NODES 个节点有资源压力"
fi

# ==================== Pod检查 ====================
echo ""
echo "==================== 3. Pod健康 ===================="

# 问题Pod
PENDING_PODS=$(kubectl get pods -A --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
FAILED_PODS=$(kubectl get pods -A --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l)
CRASHLOOP_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c CrashLoopBackOff || echo 0)

if [ "$PENDING_PODS" -eq 0 ]; then
    check_pass "无Pending Pod"
else
    check_warn "存在 $PENDING_PODS 个Pending Pod"
fi

if [ "$FAILED_PODS" -eq 0 ]; then
    check_pass "无Failed Pod"
else
    check_warn "存在 $FAILED_PODS 个Failed Pod"
fi

if [ "$CRASHLOOP_PODS" -eq 0 ]; then
    check_pass "无CrashLoopBackOff Pod"
else
    check_fail "存在 $CRASHLOOP_PODS 个CrashLoopBackOff Pod"
fi

# kube-system Pod
KUBE_SYSTEM_ISSUES=$(kubectl get pods -n kube-system --no-headers | grep -v Running | grep -v Completed | wc -l)
if [ "$KUBE_SYSTEM_ISSUES" -eq 0 ]; then
    check_pass "kube-system所有Pod正常"
else
    check_fail "kube-system存在 $KUBE_SYSTEM_ISSUES 个问题Pod"
    kubectl get pods -n kube-system | grep -v Running | grep -v Completed
fi

# ==================== 网络检查 ====================
echo ""
echo "==================== 4. 网络健康 ===================="

# CoreDNS
COREDNS_READY=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c Running)
if [ "$COREDNS_READY" -ge 1 ]; then
    check_pass "CoreDNS运行中 ($COREDNS_READY个副本)"
else
    check_fail "CoreDNS未运行"
fi

# kube-proxy
KUBE_PROXY_READY=$(kubectl get pods -n kube-system -l k8s-app=kube-proxy --no-headers 2>/dev/null | grep -c Running)
if [ "$KUBE_PROXY_READY" -ge 1 ]; then
    check_pass "kube-proxy运行中 ($KUBE_PROXY_READY个节点)"
else
    check_fail "kube-proxy未运行"
fi

# 无Endpoints的Service
NO_ENDPOINTS=$(kubectl get endpoints -A -o json | jq -r '.items[] | select(.subsets == null or .subsets == []) | select(.metadata.name != "kubernetes") | .metadata.name' | wc -l)
if [ "$NO_ENDPOINTS" -eq 0 ]; then
    check_pass "所有Service有Endpoints"
else
    check_warn "存在 $NO_ENDPOINTS 个Service无Endpoints"
fi

# ==================== 存储检查 ====================
echo ""
echo "==================== 5. 存储健康 ===================="

# PVC状态
PENDING_PVC=$(kubectl get pvc -A --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
if [ "$PENDING_PVC" -eq 0 ]; then
    check_pass "无Pending PVC"
else
    check_warn "存在 $PENDING_PVC 个Pending PVC"
fi

# Released PV
RELEASED_PV=$(kubectl get pv --field-selector=status.phase=Released --no-headers 2>/dev/null | wc -l)
if [ "$RELEASED_PV" -eq 0 ]; then
    check_pass "无Released PV"
else
    check_warn "存在 $RELEASED_PV 个Released PV需要处理"
fi

# ==================== 安全检查 ====================
echo ""
echo "==================== 6. 安全状态 ===================="

# RBAC
if kubectl api-versions | grep -q "rbac.authorization.k8s.io"; then
    check_pass "RBAC已启用"
else
    check_fail "RBAC未启用"
fi

# 特权容器
PRIVILEGED_PODS=$(kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[].securityContext.privileged == true) | .metadata.name' | wc -l)
if [ "$PRIVILEGED_PODS" -lt 10 ]; then
    check_pass "特权容器数量合理 ($PRIVILEGED_PODS个)"
else
    check_warn "特权容器数量较多 ($PRIVILEGED_PODS个)"
fi

# ==================== 总结 ====================
echo ""
echo "============================================================"
echo "                      检查总结"
echo "============================================================"
echo "警告数: $WARNINGS"
echo "错误数: $ERRORS"
echo ""

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo "状态: ✅ 集群健康"
elif [ "$ERRORS" -eq 0 ]; then
    echo "状态: ⚠️ 集群基本健康,有 $WARNINGS 个警告需关注"
else
    echo "状态: ❌ 集群存在问题,有 $ERRORS 个错误需立即处理"
fi

echo ""
echo "报告已保存到: $OUTPUT_FILE"
```

## Prometheus监控指标

### 关键健康指标

| 指标 | 告警条件 | 严重性 | 说明 |
|-----|---------|-------|------|
| `up{job="kubernetes-apiservers"}` | == 0 | Critical | API Server不可用 |
| `etcd_server_has_leader` | == 0 | Critical | etcd无Leader |
| `kube_node_status_condition{condition="Ready",status="true"}` | == 0 | Critical | 节点NotReady |
| `kube_pod_status_phase{phase="Failed"}` | > 0 持续5m | Warning | Pod失败 |
| `kubelet_pleg_relist_duration_seconds_bucket` | P99 > 3s | Warning | kubelet PLEG慢 |
| `scheduler_pending_pods` | > 100 持续10m | Warning | 调度积压 |
| `etcd_mvcc_db_total_size_in_bytes` | > 6GB | Warning | etcd数据库过大 |
| `apiserver_request_duration_seconds_bucket` | P99 > 1s | Warning | API请求慢 |

### Prometheus告警规则

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cluster-health-alerts
  namespace: monitoring
spec:
  groups:
  - name: cluster.health
    interval: 30s
    rules:
    # API Server告警
    - alert: KubeAPIServerDown
      expr: up{job="kubernetes-apiservers"} == 0
      for: 3m
      labels:
        severity: critical
      annotations:
        summary: "Kubernetes API Server不可用"
        
    - alert: KubeAPIServerLatencyHigh
      expr: |
        histogram_quantile(0.99, sum(rate(apiserver_request_duration_seconds_bucket{verb!="WATCH"}[5m])) by (verb, le)) > 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "API Server请求延迟高"
        
    # etcd告警
    - alert: EtcdNoLeader
      expr: etcd_server_has_leader == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "etcd集群无Leader"
        
    - alert: EtcdDatabaseSizeHigh
      expr: etcd_mvcc_db_total_size_in_bytes > 6*1024*1024*1024
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "etcd数据库大小超过6GB"
        
    # 节点告警
    - alert: KubeNodeNotReady
      expr: kube_node_status_condition{condition="Ready",status="true"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "节点 {{ $labels.node }} NotReady"
        
    # Pod告警
    - alert: KubePodCrashLooping
      expr: |
        rate(kube_pod_container_status_restarts_total[15m]) * 60 * 5 > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} 频繁重启"
        
    # 调度告警
    - alert: KubeSchedulerPendingPods
      expr: scheduler_pending_pods > 100
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "调度队列积压超过100个Pod"
```

## ACK健康检查

### 阿里云ACK特有检查

| 功能 | 入口 | 检查内容 | 说明 |
|-----|------|---------|------|
| **集群诊断** | 控制台-运维管理 | 全面健康检查 | 一键诊断 |
| **节点诊断** | 控制台-节点管理 | 节点问题排查 | 单节点诊断 |
| **网络诊断** | 控制台-网络 | 网络连通性 | VPC/ENI检查 |
| **ARMS监控** | ARMS控制台 | 组件指标 | 深度监控 |
| **日志服务** | SLS控制台 | 日志分析 | 审计/诊断日志 |

```bash
# ACK集群诊断CLI
# 安装ack-diagnose工具
curl -O https://alibabacloud-china.github.io/diagnose-tools/scripts/installer.sh
bash installer.sh

# 集群诊断
ack-diagnose cluster --cluster-id <cluster-id>

# 节点诊断
ack-diagnose node --cluster-id <cluster-id> --node-name <node-name>

# 网络诊断
ack-diagnose network --cluster-id <cluster-id> --source-pod <pod-name> --target-pod <pod-name>

# 使用aliyun CLI
aliyun cs DescribeClusterDetail --ClusterId <cluster-id>
aliyun cs DescribeClusterNodes --ClusterId <cluster-id>
```

## 最佳实践

### 健康检查频率建议

| 检查类型 | 建议频率 | 自动化 | 说明 |
|---------|---------|-------|------|
| 控制平面 | 1分钟 | 是 | Prometheus监控 |
| 节点状态 | 1分钟 | 是 | 节点exporter |
| Pod状态 | 5分钟 | 是 | kube-state-metrics |
| 网络连通性 | 15分钟 | 是 | 黑盒探测 |
| 存储状态 | 5分钟 | 是 | CSI监控 |
| 安全审计 | 每日 | 是 | 定期扫描 |
| 完整报告 | 每日 | 是 | 自动化脚本 |

### 检查清单总结

```
□ 控制平面
  ├── API Server /healthz, /readyz
  ├── etcd健康和集群状态
  ├── Scheduler运行状态
  └── Controller Manager运行状态

□ 节点
  ├── 所有节点Ready
  ├── 无资源压力(Memory/Disk/PID)
  ├── kubelet和containerd正常
  └── 资源使用率合理

□ Pod
  ├── 无Pending/Failed/CrashLoopBackOff
  ├── kube-system组件正常
  ├── 重启次数合理
  └── 资源配置合理

□ 网络
  ├── CoreDNS正常
  ├── kube-proxy正常
  ├── CNI组件正常
  └── Service有Endpoints

□ 存储
  ├── PVC全部Bound
  ├── 无Released PV
  └── CSI Driver正常

□ 安全
  ├── RBAC启用
  ├── PSS/PSA配置
  └── 特权容器审计
```

## 版本变更记录

| 版本 | 变更内容 | 影响 |
|-----|---------|------|
| v1.16 | /livez和/readyz端点 | 更细粒度健康检查 |
| v1.24 | componentstatuses弃用 | 使用/readyz替代 |
| v1.26 | 节点日志API | 远程获取kubelet日志 |
| v1.28 | /readyz?verbose增强 | 更详细状态信息 |
| v1.29 | 健康检查指标增强 | 更多诊断指标 |
| v1.30 | 节点问题检测器增强 | 更好的问题发现 |

---

**健康检查原则**: 定期检查 → 自动化监控 → 快速响应 → 根因分析 → 持续改进

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)
