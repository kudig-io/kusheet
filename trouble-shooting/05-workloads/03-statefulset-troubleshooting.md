# StatefulSet 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 中级-高级
>
> **版本说明**:
> - v1.26+ StatefulSetStartOrdinal GA (支持起始序号)
> - v1.27+ StatefulSetAutoDeletePVC Beta (自动删除 PVC)
> - v1.31+ StatefulSetAutoDeletePVC GA

## 概述

StatefulSet 是 Kubernetes 中用于管理有状态应用的工作负载控制器，为 Pod 提供稳定的网络标识、持久化存储和有序部署/扩缩/删除能力。本文档覆盖 StatefulSet 常见故障的诊断与解决方案。

---

## 第一部分：问题现象与影响分析

### 1.1 常见问题现象

| 问题类型 | 现象描述 | 错误信息示例 | 查看方式 |
|---------|---------|-------------|---------|
| Pod 创建阻塞 | StatefulSet 的 Pod 卡在 Pending 状态，后续 Pod 无法创建 | `pod has unbound immediate PersistentVolumeClaims` | `kubectl get pods -l app=<statefulset>` |
| Pod 顺序启动失败 | 前序 Pod 未 Ready，后续 Pod 不会创建 | Pod 数量少于期望副本数 | `kubectl get sts <name>` |
| PVC 绑定失败 | volumeClaimTemplates 创建的 PVC 处于 Pending | `waiting for a volume to be created` | `kubectl get pvc` |
| 网络标识异常 | Headless Service 无法解析 Pod DNS | `nslookup: can't resolve '<pod>.<svc>'` | `kubectl exec -- nslookup` |
| 滚动更新卡住 | 更新策略导致 Pod 更新停滞 | `updateRevision` 与 `currentRevision` 不一致 | `kubectl describe sts` |
| Pod 删除阻塞 | Pod 处于 Terminating 状态无法删除 | `pod is being terminated` | `kubectl get pods` |
| 扩缩容失败 | 副本数无法达到期望值 | Replicas 数量不变 | `kubectl get sts` |
| 数据持久化丢失 | Pod 重建后数据丢失 | 应用层数据不一致 | 应用日志 |

### 1.2 错误信息来源

| 来源 | 查看命令 | 说明 |
|-----|---------|-----|
| StatefulSet 事件 | `kubectl describe sts <name>` | 控制器级别事件 |
| Pod 事件 | `kubectl describe pod <pod-name>` | Pod 调度和运行事件 |
| PVC 事件 | `kubectl describe pvc <pvc-name>` | 存储卷绑定事件 |
| Controller Manager 日志 | `kubectl logs -n kube-system kube-controller-manager-<node>` | StatefulSet 控制器日志 |
| kubelet 日志 | `journalctl -u kubelet` | 节点级 Pod 创建日志 |

### 1.3 影响分析

| 故障类型 | 直接影响 | 间接影响 | 影响范围 |
|---------|---------|---------|---------|
| Pod 创建阻塞 | 服务实例不足，无法提供完整服务 | 有状态应用集群无法形成，如数据库无法选主 | 单个 StatefulSet |
| PVC 绑定失败 | Pod 无法启动，数据无法持久化 | 应用数据丢失风险，服务不可用 | 单个 Pod 及依赖服务 |
| 网络标识异常 | Pod 间无法通过稳定 DNS 通信 | 有状态集群内部通信中断，如 Redis Cluster 节点发现失败 | 整个 StatefulSet 集群 |
| 滚动更新卡住 | 新版本无法部署，旧版本继续运行 | 功能更新延迟，安全补丁无法应用 | 单个 StatefulSet |
| 数据持久化丢失 | 应用数据不一致或丢失 | 业务数据损坏，可能需要从备份恢复 | 业务层面 |

---

## 第二部分：排查原理与方法

### 2.1 StatefulSet 工作原理

```
┌─────────────────────────────────────────────────────────────────┐
│                    StatefulSet Controller                        │
├─────────────────────────────────────────────────────────────────┤
│  1. 有序部署: Pod 按 {name}-0, {name}-1, {name}-2 顺序创建       │
│  2. 稳定网络标识: 每个 Pod 有固定 DNS: {pod}.{service}.{ns}.svc  │
│  3. 持久化存储: volumeClaimTemplates 为每个 Pod 创建独立 PVC     │
│  4. 有序扩缩: 扩容按序号递增，缩容按序号递减                      │
│  5. 有序更新: 默认从最大序号开始逐个更新 (RollingUpdate)          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      核心组件依赖                                │
├──────────────────┬──────────────────┬───────────────────────────┤
│  Headless Service │  PersistentVolume │  Pod Management Policy   │
│  (clusterIP:None) │  (StorageClass)   │  (OrderedReady/Parallel) │
└──────────────────┴──────────────────┴───────────────────────────┘
```

### 2.2 排查决策树

```
StatefulSet 故障
       │
       ├─── Pod 数量不足？
       │         │
       │         ├─ 是 ──→ 检查 Pod 状态
       │         │              │
       │         │              ├─ Pending ──→ 检查 PVC 绑定 / 节点资源 / 调度约束
       │         │              ├─ ContainerCreating ──→ 检查镜像拉取 / 存储挂载
       │         │              └─ 前序 Pod 未 Ready ──→ 排查前序 Pod 问题
       │         │
       │         └─ 否 ──→ 检查 Pod 运行状态
       │
       ├─── 网络标识异常？
       │         │
       │         ├─ Headless Service 存在？ ──→ 检查 Service selector
       │         ├─ DNS 解析失败？ ──→ 检查 CoreDNS / Service 配置
       │         └─ Pod 间通信失败？ ──→ 检查 NetworkPolicy / CNI
       │
       ├─── 存储问题？
       │         │
       │         ├─ PVC Pending ──→ 检查 StorageClass / PV 可用性
       │         ├─ 挂载失败 ──→ 检查 CSI 驱动 / 节点存储
       │         └─ 数据丢失 ──→ 检查 PV ReclaimPolicy / 实际存储
       │
       └─── 更新问题？
                 │
                 ├─ 更新卡住 ──→ 检查 Pod 健康检查 / 更新策略
                 ├─ 分区更新 ──→ 检查 partition 设置
                 └─ 需要回滚 ──→ 使用 rollout undo
```

### 2.3 排查命令集

#### 2.3.1 基础状态检查

```bash
# 查看 StatefulSet 状态
kubectl get sts <name> -o wide

# 查看详细信息和事件
kubectl describe sts <name>

# 查看 StatefulSet YAML 配置
kubectl get sts <name> -o yaml

# 查看关联的 Pod
kubectl get pods -l app=<statefulset-name> -o wide

# 查看 Pod 详细状态
kubectl get pods -l app=<statefulset-name> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'
```

#### 2.3.2 PVC 和存储检查

```bash
# 查看 StatefulSet 关联的 PVC
kubectl get pvc -l app=<statefulset-name>

# 查看 PVC 详细信息
kubectl describe pvc <pvc-name>

# 查看 PVC 绑定的 PV
kubectl get pv | grep <pvc-name>

# 检查 StorageClass
kubectl get storageclass
kubectl describe storageclass <name>

# 检查 CSI 驱动状态
kubectl get csidrivers
kubectl get pods -n kube-system -l app=csi-*
```

#### 2.3.3 网络标识检查

```bash
# 检查 Headless Service
kubectl get svc <service-name> -o yaml
# 确认 clusterIP: None

# 验证 DNS 解析 (从集群内 Pod 执行)
kubectl run dns-test --rm -it --image=busybox:1.28 --restart=Never -- nslookup <pod-name>.<service-name>.<namespace>.svc.cluster.local

# 检查 Endpoints
kubectl get endpoints <service-name>

# 验证 Pod DNS 配置
kubectl exec <pod-name> -- cat /etc/resolv.conf
```

#### 2.3.4 更新状态检查

```bash
# 查看更新状态
kubectl rollout status sts <name>

# 查看更新历史
kubectl rollout history sts <name>

# 查看当前和更新版本
kubectl get sts <name> -o jsonpath='{.status.currentRevision}{"\n"}{.status.updateRevision}'

# 查看各 Pod 的 controller-revision-hash
kubectl get pods -l app=<statefulset-name> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.controller-revision-hash}{"\n"}{end}'
```

#### 2.3.5 控制器日志检查

```bash
# 查看 StatefulSet 控制器日志
kubectl logs -n kube-system -l component=kube-controller-manager --tail=100 | grep -i statefulset

# 查看特定 StatefulSet 相关日志
kubectl logs -n kube-system -l component=kube-controller-manager | grep <statefulset-name>
```

### 2.4 排查注意事项

| 注意事项 | 说明 |
|---------|-----|
| 有序性依赖 | StatefulSet 默认使用 OrderedReady 策略，前序 Pod 必须 Ready 后续才会创建 |
| PVC 不自动删除 | 删除 StatefulSet 或缩容时，PVC 默认保留，需手动清理 |
| Headless Service 必需 | StatefulSet 需要 Headless Service 提供网络标识 |
| 存储类可用性 | volumeClaimTemplates 依赖 StorageClass 动态供应或预创建 PV |
| 更新策略影响 | RollingUpdate 策略的 partition 参数会影响更新范围 |
| Pod 管理策略 | Parallel 策略可加速部署但失去有序性保证 |

---

## 第三部分：解决方案与风险控制

### 3.1 Pod 创建阻塞问题

#### 场景 1：PVC 绑定失败导致 Pod Pending

**问题现象：**
```
Events:
  Warning  FailedScheduling  pod has unbound immediate PersistentVolumeClaims
```

**解决步骤：**

```bash
# 1. 检查 PVC 状态
kubectl get pvc -l app=<statefulset-name>

# 2. 查看 PVC 详细事件
kubectl describe pvc <pvc-name>

# 3. 检查 StorageClass 是否存在且可用
kubectl get storageclass
kubectl describe storageclass <storage-class-name>

# 4. 如果是动态供应，检查 Provisioner
kubectl get pods -n kube-system | grep provisioner

# 5. 如果需要手动创建 PV
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-<statefulset>-<ordinal>
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: <storage-class>
  hostPath:  # 或其他存储后端
    path: /data/<statefulset>-<ordinal>
EOF

# 6. 验证 PVC 绑定
kubectl get pvc <pvc-name> -w
```

**风险提示：**
- 手动创建 PV 时确保存储路径存在且有正确权限
- hostPath 仅适用于测试环境，生产环境应使用网络存储
- 修改 StorageClass 不会影响已创建的 PVC

#### 场景 2：前序 Pod 未 Ready 阻塞后续创建

**问题现象：**
```bash
$ kubectl get pods -l app=mysql
NAME      READY   STATUS    RESTARTS   AGE
mysql-0   0/1     Running   0          5m
# mysql-1, mysql-2 未创建
```

**解决步骤：**

```bash
# 1. 检查 Pod-0 的 Ready 条件
kubectl describe pod <statefulset>-0 | grep -A5 "Conditions:"

# 2. 检查健康检查配置
kubectl get sts <name> -o jsonpath='{.spec.template.spec.containers[*].readinessProbe}' | jq

# 3. 检查应用日志
kubectl logs <statefulset>-0

# 4. 如果健康检查配置不当，修改 readinessProbe
kubectl patch sts <name> --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/initialDelaySeconds", "value": 30},
  {"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/periodSeconds", "value": 10}
]'

# 5. 如果需要跳过有序性约束 (仅限特殊场景)
kubectl patch sts <name> -p '{"spec":{"podManagementPolicy":"Parallel"}}'
```

**风险提示：**
- 修改 podManagementPolicy 需要删除重建 StatefulSet
- Parallel 策略可能导致有状态应用初始化问题
- 优先排查应用本身的启动问题

---

### 3.2 网络标识问题

#### 场景 1：Headless Service 配置错误

**问题现象：**
```bash
$ kubectl exec mysql-0 -- nslookup mysql-1.mysql-headless
nslookup: can't resolve 'mysql-1.mysql-headless'
```

**解决步骤：**

```bash
# 1. 检查 Headless Service 配置
kubectl get svc <service-name> -o yaml

# 2. 确认 Service 是 Headless (clusterIP: None)
kubectl get svc <service-name> -o jsonpath='{.spec.clusterIP}'
# 应该输出 "None"

# 3. 检查 selector 是否匹配 Pod 标签
kubectl get svc <service-name> -o jsonpath='{.spec.selector}'
kubectl get pods -l <selector-key>=<selector-value>

# 4. 检查 Endpoints
kubectl get endpoints <service-name>

# 5. 如果 Service 不正确，重新创建
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: <statefulset>-headless
  labels:
    app: <statefulset>
spec:
  ports:
  - port: <port>
    name: <port-name>
  clusterIP: None
  selector:
    app: <statefulset>
EOF

# 6. 确保 StatefulSet 引用正确的 serviceName
kubectl get sts <name> -o jsonpath='{.spec.serviceName}'
```

**风险提示：**
- 修改 Service 会导致短暂的 DNS 解析中断
- StatefulSet 的 serviceName 字段不可修改，需删除重建

#### 场景 2：DNS 解析延迟或缓存

**问题现象：**
新创建的 Pod DNS 无法立即解析

**解决步骤：**

```bash
# 1. 检查 CoreDNS 状态
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 2. 查看 CoreDNS 日志
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50

# 3. 检查 Endpoints 是否已更新
kubectl get endpoints <service-name> -w

# 4. 强制刷新 DNS 缓存 (重启 CoreDNS)
kubectl rollout restart deployment coredns -n kube-system

# 5. 检查 Pod 的 DNS 策略
kubectl get pod <pod-name> -o jsonpath='{.spec.dnsPolicy}'
```

---

### 3.3 滚动更新问题

#### 场景 1：更新卡住

**问题现象：**
```bash
$ kubectl rollout status sts mysql
Waiting for 1 pods to be ready...
```

**解决步骤：**

```bash
# 1. 查看更新状态
kubectl get sts <name> -o jsonpath='{.status}'

# 2. 检查哪个 Pod 在更新
kubectl get pods -l app=<statefulset> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.controller-revision-hash}{"\n"}{end}'

# 3. 查看卡住的 Pod 状态
kubectl describe pod <stuck-pod>

# 4. 检查 Pod 日志
kubectl logs <stuck-pod> --previous  # 如果有重启
kubectl logs <stuck-pod>

# 5. 如果是健康检查失败，调整探针
kubectl patch sts <name> --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/failureThreshold", "value": 5}
]'

# 6. 如果需要强制继续更新 (删除卡住的 Pod)
kubectl delete pod <stuck-pod>

# 7. 检查更新是否继续
kubectl rollout status sts <name>
```

**风险提示：**
- 强制删除 Pod 可能导致数据丢失
- 有状态应用删除前应确保数据已同步

#### 场景 2：需要回滚更新

**解决步骤：**

```bash
# 1. 查看更新历史
kubectl rollout history sts <name>

# 2. 查看特定版本详情
kubectl rollout history sts <name> --revision=<revision>

# 3. 回滚到上一版本
kubectl rollout undo sts <name>

# 4. 回滚到指定版本
kubectl rollout undo sts <name> --to-revision=<revision>

# 5. 验证回滚状态
kubectl rollout status sts <name>
```

#### 场景 3：分区更新 (金丝雀发布)

**解决步骤：**

```bash
# 1. 设置 partition，只更新序号 >= partition 的 Pod
kubectl patch sts <name> -p '{"spec":{"updateStrategy":{"type":"RollingUpdate","rollingUpdate":{"partition":2}}}}'
# 只有 pod-2 及以上会更新

# 2. 验证金丝雀 Pod
kubectl exec <statefulset>-2 -- <version-check-command>

# 3. 确认无问题后，逐步降低 partition
kubectl patch sts <name> -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":1}}}}'

# 4. 完成全部更新
kubectl patch sts <name> -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":0}}}}'
```

---

### 3.4 存储和数据问题

#### 场景 1：PVC 清理与重建

**问题现象：**
需要清理 StatefulSet 残留的 PVC

**解决步骤：**

```bash
# 1. 列出关联的 PVC
kubectl get pvc -l app=<statefulset>

# 2. 确认数据是否需要保留
# 如果需要保留，先备份数据

# 3. 删除 StatefulSet (保留 PVC)
kubectl delete sts <name> --cascade=orphan

# 4. 删除 PVC (数据将丢失!)
kubectl delete pvc -l app=<statefulset>

# 5. 如果需要保留数据，修改 PV 回收策略
kubectl patch pv <pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
```

**风险提示：**
- 删除 PVC 会导致数据永久丢失
- 删除前务必确认数据已备份
- Retain 策略的 PV 需要手动清理

#### 场景 2：存储容量扩展

**解决步骤：**

```bash
# 1. 确认 StorageClass 支持扩展
kubectl get storageclass <name> -o jsonpath='{.allowVolumeExpansion}'

# 2. 扩展 PVC 容量
kubectl patch pvc <pvc-name> -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# 3. 查看扩展状态
kubectl get pvc <pvc-name> -o jsonpath='{.status.conditions}'

# 4. 某些存储需要重启 Pod 才能识别新容量
kubectl delete pod <pod-name>
# StatefulSet 会自动重建 Pod

# 5. 验证容量
kubectl exec <pod-name> -- df -h <mount-path>
```

---

### 3.5 扩缩容问题

#### 场景 1：扩容失败

**解决步骤：**

```bash
# 1. 扩容 StatefulSet
kubectl scale sts <name> --replicas=5

# 2. 检查扩容状态
kubectl get sts <name> -w

# 3. 如果新 Pod 未创建，检查资源配额
kubectl describe quota -n <namespace>

# 4. 检查节点资源
kubectl describe nodes | grep -A5 "Allocated resources"

# 5. 检查 PVC 创建
kubectl get pvc -l app=<statefulset>
```

#### 场景 2：缩容清理

**解决步骤：**

```bash
# 1. 缩容 StatefulSet
kubectl scale sts <name> --replicas=2

# 2. 等待缩容完成
kubectl get sts <name> -w

# 3. 注意：PVC 不会自动删除
kubectl get pvc -l app=<statefulset>

# 4. 如需清理 PVC (数据将丢失!)
kubectl delete pvc <pvc-name>

# 5. 如果 Pod 删除卡住
kubectl delete pod <pod-name> --grace-period=0 --force
```

**风险提示：**
- 缩容时从最大序号开始删除
- PVC 保留是为了防止数据丢失
- 强制删除可能导致数据不一致

---

### 3.6 完整的 StatefulSet 示例

```yaml
# Headless Service (必需)
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None  # 关键：必须是 None
  selector:
    app: nginx
---
# StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nginx
spec:
  serviceName: "nginx-headless"  # 关联 Headless Service
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: data
          mountPath: /usr/share/nginx/html
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 20
  volumeClaimTemplates:  # 每个 Pod 独立 PVC
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: "standard"
      resources:
        requests:
          storage: 1Gi
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0  # 默认更新所有 Pod
  podManagementPolicy: OrderedReady  # 有序部署
```

---

### 3.7 安全生产风险提示

| 操作 | 风险等级 | 风险说明 | 建议 |
|-----|---------|---------|-----|
| 删除 PVC | 高 | 数据永久丢失 | 操作前备份数据，确认无误后执行 |
| 强制删除 Pod | 中 | 可能导致数据不一致 | 仅在 Pod 卡死时使用，优先正常删除 |
| 修改 podManagementPolicy | 中 | 需要删除重建 StatefulSet | 提前规划，低峰期执行 |
| 扩展 PVC 容量 | 低 | 部分存储不支持在线扩展 | 确认 StorageClass 支持，可能需要重启 Pod |
| 回滚更新 | 中 | 可能影响已处理的数据 | 确认应用支持版本回滚，检查数据兼容性 |
| 修改 Headless Service | 中 | 短暂 DNS 解析中断 | 低峰期执行，做好应用重连准备 |
| 跨版本升级 | 高 | 数据格式可能不兼容 | 按官方升级指南逐版本升级 |

---

## 附录

### 常用排查命令速查

```bash
# StatefulSet 状态
kubectl get sts -o wide
kubectl describe sts <name>
kubectl get sts <name> -o yaml

# Pod 状态
kubectl get pods -l app=<sts> -o wide
kubectl describe pod <pod>
kubectl logs <pod>

# PVC 状态
kubectl get pvc -l app=<sts>
kubectl describe pvc <pvc>

# 网络检查
kubectl exec <pod> -- nslookup <pod>.<svc>
kubectl get endpoints <svc>

# 更新操作
kubectl rollout status sts <name>
kubectl rollout history sts <name>
kubectl rollout undo sts <name>

# 扩缩容
kubectl scale sts <name> --replicas=<n>
```

### 相关文档

- [Pod 故障排查](./01-pod-troubleshooting.md)
- [PV/PVC 故障排查](../04-storage/01-pv-pvc-troubleshooting.md)
- [DNS 故障排查](../03-networking/02-dns-troubleshooting.md)
- [调度故障排查](../01-control-plane/03-scheduler-troubleshooting.md)
