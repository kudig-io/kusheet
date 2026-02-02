# 集群高可用与灾备故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32, etcd v3.4 - v3.5 | **最后更新**: 2026-01 | **难度**: 高级
>
> **版本说明**:
> - etcd v3.5.x 推荐用于 K8s v1.25+
> - kubeadm 高可用部署支持堆叠 etcd 或外部 etcd
> - Velero v1.12+ 支持 CSI snapshot 备份
> - K8s v1.28+ 支持 Unknown Version Interoperability Proxy (UVIP)

## 概述

Kubernetes 集群的高可用 (HA) 和灾难恢复 (DR) 能力对于生产环境至关重要。本文档覆盖控制平面高可用、etcd 集群故障、备份恢复、跨区域容灾等场景的诊断与解决方案。

---

## 第一部分：问题现象与影响分析

### 1.1 高可用架构

```
┌─────────────────────────────────────────────────────────────────┐
│                  Kubernetes 高可用架构                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    负载均衡器                             │   │
│  │              (HAProxy/Nginx/Cloud LB)                    │   │
│  │                     :6443                                │   │
│  └──────────────────────┬───────────────────────────────────┘   │
│                         │                                        │
│         ┌───────────────┼───────────────┐                       │
│         ▼               ▼               ▼                       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │
│  │  Master 1   │ │  Master 2   │ │  Master 3   │               │
│  │ API Server  │ │ API Server  │ │ API Server  │               │
│  │ Controller  │ │ Controller  │ │ Controller  │               │
│  │ Scheduler   │ │ Scheduler   │ │ Scheduler   │               │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘               │
│         │               │               │                       │
│         └───────────────┼───────────────┘                       │
│                         │                                        │
│  ┌──────────────────────┼──────────────────────────────────┐   │
│  │                  etcd 集群                               │   │
│  │  ┌────────┐    ┌────────┐    ┌────────┐                 │   │
│  │  │ etcd 1 │◄──▶│ etcd 2 │◄──▶│ etcd 3 │                 │   │
│  │  │(Leader)│    │(Follower)   │(Follower)                │   │
│  │  └────────┘    └────────┘    └────────┘                 │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 常见问题现象

| 问题类型 | 现象描述 | 错误信息示例 | 查看方式 |
|---------|---------|-------------|---------|
| API Server 不可用 | kubectl 无法连接 | `connection refused` | `kubectl cluster-info` |
| etcd 集群不健康 | 数据读写失败 | `etcdserver: no leader` | `etcdctl endpoint health` |
| 脑裂 | 数据不一致 | 不同节点返回不同数据 | etcd 日志 |
| 主节点故障 | 控制平面部分不可用 | API 间歇性失败 | `kubectl get nodes` |
| 备份失败 | 无法创建备份 | `snapshot failed` | 备份任务日志 |
| 恢复失败 | 无法从备份恢复 | `restore failed` | 恢复操作日志 |
| 选主失败 | Controller/Scheduler 无 leader | `leader election lost` | 组件日志 |

### 1.3 影响分析

| 故障类型 | 直接影响 | 间接影响 | 影响范围 |
|---------|---------|---------|---------|
| 单 Master 故障 | API 负载增加 | 性能下降 | 整个集群 (如果没有 HA) |
| etcd 少数节点故障 | 集群仍可用 | 容错能力下降 | 数据持久性 |
| etcd 多数节点故障 | 集群只读或不可用 | 所有写操作失败 | 整个集群 |
| 所有 Master 故障 | 集群完全不可管理 | 新 Pod 无法调度 | 整个集群管理能力 |
| 备份数据丢失 | 无法恢复到特定时间点 | 灾难恢复能力丧失 | 业务连续性 |

---

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
高可用/灾备故障
      │
      ├─── API Server 不可用？
      │         │
      │         ├─ 检查负载均衡器 ──→ VIP/LB 健康检查
      │         ├─ 检查各 Master 节点 ──→ kubectl --server 直连
      │         └─ 检查证书 ──→ 证书过期/配置错误
      │
      ├─── etcd 集群问题？
      │         │
      │         ├─ 无 Leader ──→ 检查节点数/网络分区
      │         ├─ 数据不一致 ──→ 检查成员状态/日志
      │         └─ 性能问题 ──→ 检查磁盘/网络延迟
      │
      ├─── Controller/Scheduler 问题？
      │         │
      │         ├─ 选主失败 ──→ 检查 Lease 资源
      │         └─ 多个 Leader ──→ 检查时钟同步
      │
      └─── 备份/恢复问题？
                │
                ├─ 备份失败 ──→ 检查权限/存储空间
                └─ 恢复失败 ──→ 检查备份完整性/版本兼容
```

### 2.2 排查命令集

#### 2.2.1 控制平面状态检查

```bash
# 检查所有 Master 节点
kubectl get nodes -l node-role.kubernetes.io/control-plane=

# 检查控制平面组件
kubectl get pods -n kube-system -l tier=control-plane

# 检查 API Server 端点
kubectl get endpoints kubernetes -n default

# 直连各 Master 检查
kubectl --server=https://<master1-ip>:6443 get nodes
kubectl --server=https://<master2-ip>:6443 get nodes

# 检查组件健康
kubectl get componentstatuses  # 已废弃但仍可用
kubectl get --raw='/readyz?verbose'
kubectl get --raw='/healthz?verbose'
```

#### 2.2.2 etcd 集群检查

```bash
# 设置 etcdctl 环境变量
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key

# 检查集群健康
etcdctl endpoint health --cluster

# 检查集群状态
etcdctl endpoint status --cluster -w table

# 检查成员列表
etcdctl member list -w table

# 检查 Leader
etcdctl endpoint status --cluster -w json | jq '.[] | select(.Status.leader==.Status.header.member_id)'

# 检查磁盘使用
etcdctl endpoint status --cluster -w table | awk '{print $1, $5}'

# 检查数据库大小
etcdctl endpoint status --cluster -w json | jq '.[].Status.dbSize'
```

#### 2.2.3 选主状态检查

```bash
# 检查 Controller Manager Leader
kubectl get lease kube-controller-manager -n kube-system -o yaml

# 检查 Scheduler Leader
kubectl get lease kube-scheduler -n kube-system -o yaml

# 查看当前 Leader
kubectl get endpoints kube-controller-manager -n kube-system -o yaml
kubectl get endpoints kube-scheduler -n kube-system -o yaml
```

### 2.3 排查注意事项

| 注意事项 | 说明 |
|---------|-----|
| etcd 节点数 | 推荐奇数个 (3, 5, 7)，容忍 (n-1)/2 个故障 |
| 仲裁要求 | etcd 写操作需要多数节点同意 |
| 时钟同步 | 所有节点必须时钟同步 (NTP) |
| 网络延迟 | etcd 对网络延迟敏感，建议 <10ms |
| 磁盘性能 | etcd 需要低延迟磁盘 (SSD) |

---

## 第三部分：解决方案与风险控制

### 3.1 etcd 集群故障

#### 场景 1：etcd 无 Leader

**问题现象：**
```
etcdserver: no leader
```

**解决步骤：**

```bash
# 1. 检查集群成员状态
etcdctl member list -w table
etcdctl endpoint status --cluster -w table

# 2. 检查各节点是否可达
for ep in <etcd1>:2379 <etcd2>:2379 <etcd3>:2379; do
  etcdctl --endpoints=$ep endpoint health
done

# 3. 检查网络分区
# 从各节点 ping 其他节点

# 4. 如果是少数节点故障，等待自动选主
# etcd 会在心跳超时后自动选举

# 5. 如果多数节点故障，需要从备份恢复
# 参见备份恢复章节

# 6. 检查 etcd 日志
kubectl logs -n kube-system etcd-<node> --tail=100
# 或
journalctl -u etcd --tail=100
```

#### 场景 2：etcd 成员故障恢复

```bash
# 场景: 一个 etcd 成员永久故障，需要替换

# 1. 移除故障成员
etcdctl member remove <member-id>

# 2. 在新节点上准备 etcd

# 3. 添加新成员 (先添加，再启动)
etcdctl member add <new-member-name> --peer-urls=https://<new-node-ip>:2380

# 4. 在新节点启动 etcd (使用 --initial-cluster-state=existing)
# kubeadm 方式:
kubeadm join <control-plane-endpoint> \
  --control-plane \
  --certificate-key <key>

# 5. 验证集群状态
etcdctl member list -w table
etcdctl endpoint health --cluster
```

#### 场景 3：etcd 数据压缩和碎片整理

```bash
# 检查数据库大小
etcdctl endpoint status --cluster -w table

# 获取当前修订版本
rev=$(etcdctl endpoint status --write-out="json" | jq -r '.[0].Status.header.revision')

# 压缩历史
etcdctl compact $rev

# 碎片整理 (每个节点单独执行)
etcdctl defrag --endpoints=https://<etcd1>:2379
etcdctl defrag --endpoints=https://<etcd2>:2379
etcdctl defrag --endpoints=https://<etcd3>:2379

# 验证
etcdctl endpoint status --cluster -w table
```

### 3.2 备份与恢复

#### 场景 1：创建 etcd 备份

```bash
# 方式 1: 使用 etcdctl snapshot
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-$(date +%Y%m%d-%H%M%S).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 验证备份
etcdctl snapshot status /backup/etcd-*.db -w table

# 方式 2: 定时备份脚本
cat > /usr/local/bin/etcd-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR=/backup/etcd
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE=$BACKUP_DIR/etcd-$DATE.db

mkdir -p $BACKUP_DIR

ETCDCTL_API=3 etcdctl snapshot save $BACKUP_FILE \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 保留最近 7 天的备份
find $BACKUP_DIR -name "etcd-*.db" -mtime +7 -delete

# 验证
etcdctl snapshot status $BACKUP_FILE
EOF

chmod +x /usr/local/bin/etcd-backup.sh

# 添加定时任务
echo "0 */6 * * * root /usr/local/bin/etcd-backup.sh" >> /etc/crontab
```

#### 场景 2：从备份恢复 etcd

**警告: 此操作会重置整个集群状态，请谨慎执行！**

```bash
# 1. 停止所有控制平面组件
# 在所有 Master 节点执行
mv /etc/kubernetes/manifests /etc/kubernetes/manifests.bak

# 2. 备份现有 etcd 数据
mv /var/lib/etcd /var/lib/etcd.bak

# 3. 在第一个节点恢复
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-backup.db \
  --name=<etcd-node-1> \
  --initial-cluster=<etcd-node-1>=https://<ip1>:2380,<etcd-node-2>=https://<ip2>:2380,<etcd-node-3>=https://<ip3>:2380 \
  --initial-cluster-token=etcd-cluster-1 \
  --initial-advertise-peer-urls=https://<ip1>:2380 \
  --data-dir=/var/lib/etcd

# 4. 在其他节点恢复 (使用相同备份文件)
# 在节点 2:
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-backup.db \
  --name=<etcd-node-2> \
  --initial-cluster=<etcd-node-1>=https://<ip1>:2380,<etcd-node-2>=https://<ip2>:2380,<etcd-node-3>=https://<ip3>:2380 \
  --initial-cluster-token=etcd-cluster-1 \
  --initial-advertise-peer-urls=https://<ip2>:2380 \
  --data-dir=/var/lib/etcd

# 在节点 3 类似执行...

# 5. 恢复控制平面组件
mv /etc/kubernetes/manifests.bak /etc/kubernetes/manifests

# 6. 等待组件启动
sleep 60
kubectl get nodes
kubectl get pods -n kube-system
```

### 3.3 控制平面故障恢复

#### 场景 1：单 Master 节点故障

```bash
# 1. 检查故障节点状态
kubectl get nodes

# 2. 如果节点可恢复
# 尝试重启 kubelet
ssh <failed-master> systemctl restart kubelet

# 3. 如果节点不可恢复，移除节点
kubectl delete node <failed-master>

# 4. 清理 etcd 成员 (如果该节点运行 etcd)
etcdctl member list
etcdctl member remove <member-id>

# 5. 添加新的 Master 节点
# 在新节点执行
kubeadm join <lb-endpoint>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <cert-key>
```

#### 场景 2：所有 Master 故障后恢复

```bash
# 最严重的情况: 所有 Master 都不可用

# 1. 选择一个 Master 节点尝试恢复
# 检查 etcd 数据是否完整
ls -la /var/lib/etcd/member/

# 2. 如果 etcd 数据完整，尝试启动
systemctl restart kubelet

# 3. 如果 etcd 数据损坏，从备份恢复
# 参见上面的备份恢复步骤

# 4. 等待 API Server 启动
kubectl get nodes

# 5. 逐个恢复其他 Master 节点
```

### 3.4 负载均衡器故障

#### 场景 1：检查和修复 LB

```bash
# 检查 LB 后端健康
# HAProxy 示例
echo "show stat" | socat stdio /var/run/haproxy.sock

# Nginx 示例
curl http://localhost:8080/nginx_status

# 检查 API Server 端口
for ip in <master1> <master2> <master3>; do
  nc -zv $ip 6443
done

# 修复 HAProxy 配置示例
cat > /etc/haproxy/haproxy.cfg << EOF
frontend kubernetes-api
    bind *:6443
    mode tcp
    default_backend kubernetes-api-backend

backend kubernetes-api-backend
    mode tcp
    balance roundrobin
    option tcp-check
    server master1 <master1-ip>:6443 check fall 3 rise 2
    server master2 <master2-ip>:6443 check fall 3 rise 2
    server master3 <master3-ip>:6443 check fall 3 rise 2
EOF

systemctl restart haproxy
```

### 3.5 灾难恢复演练

```bash
#!/bin/bash
# 灾难恢复演练检查清单

echo "=== 灾难恢复演练 ==="

# 1. 检查备份
echo -e "\n--- 备份状态 ---"
ls -la /backup/etcd/
etcdctl snapshot status /backup/etcd/latest.db -w table

# 2. 检查 etcd 集群健康
echo -e "\n--- etcd 集群状态 ---"
etcdctl endpoint health --cluster
etcdctl member list -w table

# 3. 检查控制平面
echo -e "\n--- 控制平面状态 ---"
kubectl get nodes -l node-role.kubernetes.io/control-plane=
kubectl get pods -n kube-system -l tier=control-plane

# 4. 检查 Leader 选举
echo -e "\n--- Leader 状态 ---"
kubectl get lease -n kube-system

# 5. 检查证书有效期
echo -e "\n--- 证书状态 ---"
kubeadm certs check-expiration

# 6. 模拟故障 (可选，谨慎!)
# kubectl drain <master-1> --ignore-daemonsets
# systemctl stop kubelet (on master-1)

echo -e "\n=== 检查完成 ==="
```

---

### 3.6 高可用最佳实践

```yaml
# PodDisruptionBudget 示例 - 保护关键应用
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: critical-app-pdb
spec:
  minAvailable: 2  # 或 maxUnavailable: 1
  selector:
    matchLabels:
      app: critical-app
---
# 跨可用区部署
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-app
spec:
  replicas: 3
  template:
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: critical-app
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: critical-app
            topologyKey: kubernetes.io/hostname
```

---

### 3.7 安全生产风险提示

| 操作 | 风险等级 | 风险说明 | 建议 |
|-----|---------|---------|-----|
| etcd 数据恢复 | 高 | 会重置集群状态到备份时间点 | 确认影响，低峰期执行 |
| 移除 etcd 成员 | 高 | 可能影响集群仲裁 | 确保剩余节点 > 50% |
| 压缩/碎片整理 | 中 | 可能短暂影响性能 | 逐节点执行，监控状态 |
| Master 节点维护 | 中 | 控制平面容量下降 | 确保 HA，一次维护一个 |
| 证书更新 | 中 | 可能导致组件通信中断 | 提前规划，快速执行 |
| LB 配置变更 | 中 | 可能导致 API 不可达 | 先测试，灰度生效 |

---

## 附录

### 常用命令速查

```bash
# etcd 操作
etcdctl endpoint health --cluster
etcdctl endpoint status --cluster -w table
etcdctl member list -w table
etcdctl snapshot save /path/to/backup.db
etcdctl snapshot restore /path/to/backup.db

# 控制平面检查
kubectl get nodes -l node-role.kubernetes.io/control-plane=
kubectl get pods -n kube-system -l tier=control-plane
kubectl get lease -n kube-system

# 证书检查
kubeadm certs check-expiration
kubeadm certs renew all
```

### 相关文档

- [etcd 故障排查](../01-control-plane/02-etcd-troubleshooting.md)
- [API Server 故障排查](../01-control-plane/01-apiserver-troubleshooting.md)
- [证书故障排查](../06-security-auth/02-certificate-troubleshooting.md)
- [集群维护故障排查](./01-cluster-maintenance-troubleshooting.md)
