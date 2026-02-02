# 集群运维与升级故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 高级
>
> **版本说明**:
> - v1.25+ 移除 PodSecurityPolicy，使用 PSA 替代
> - v1.27+ 移除部分废弃 API (如 CSIStorageCapacity v1beta1)
> - v1.28+ 支持 UVIP (Unknown Version Interoperability Proxy)
> - kubeadm 支持最多跨 2 个次版本升级 (如 1.26→1.28)

---

## 第一部分：问题现象与影响分析

### 1.1 集群升级架构与流程

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    Kubernetes 集群升级流程                                │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    升级前准备阶段                                │   │
│   │  1. 检查版本兼容性 (版本倾斜策略)                               │   │
│   │  2. 备份 etcd 数据                                              │   │
│   │  3. 检查集群健康状态                                            │   │
│   │  4. 审计废弃 API 使用情况                                       │   │
│   │  5. 准备回滚方案                                                │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                    │                                     │
│                                    ▼                                     │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                  第一步：升级控制平面                            │   │
│   │                                                                 │   │
│   │   Master-1 (首个) ──────────────────────────────────────────►  │   │
│   │   │  kubeadm upgrade apply v1.xx.x                             │   │
│   │   │  升级: kube-apiserver, kube-controller-manager,            │   │
│   │   │        kube-scheduler, etcd (如果内置)                      │   │
│   │   │                                                             │   │
│   │   ├─► Master-2 ─────────────────────────────────────────────►  │   │
│   │   │   kubeadm upgrade node                                      │   │
│   │   │                                                             │   │
│   │   └─► Master-3 ─────────────────────────────────────────────►  │   │
│   │       kubeadm upgrade node                                      │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                    │                                     │
│                                    ▼                                     │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                  第二步：升级 kubelet/kubectl                    │   │
│   │                                                                 │   │
│   │   每个节点 (控制平面 + 工作节点):                               │   │
│   │   1. kubectl cordon <node>  # 禁止调度                         │   │
│   │   2. kubectl drain <node>   # 驱逐 Pod                         │   │
│   │   3. 升级 kubelet, kubectl 软件包                               │   │
│   │   4. systemctl restart kubelet                                  │   │
│   │   5. kubectl uncordon <node> # 恢复调度                        │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                    │                                     │
│                                    ▼                                     │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                  第三步：验证与清理                              │   │
│   │  1. 验证所有节点版本                                            │   │
│   │  2. 验证核心组件健康                                            │   │
│   │  3. 验证工作负载正常                                            │   │
│   │  4. 更新集群文档                                                │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│   版本倾斜策略 (必须遵守):                                               │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │  kube-apiserver   ← 基准版本                                    │   │
│   │  kube-controller-manager  ≤ kube-apiserver (可低 1 个次版本)    │   │
│   │  kube-scheduler           ≤ kube-apiserver (可低 1 个次版本)    │   │
│   │  kubelet                  ≤ kube-apiserver (可低 2 个次版本)    │   │
│   │  kube-proxy               ≤ kube-apiserver (可低 2 个次版本)    │   │
│   │  kubectl                  ± kube-apiserver (可高/低 1 个次版本) │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### 1.2 常见问题现象

#### 1.2.1 集群升级问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 升级前检查失败 | `cannot upgrade to a higher version` | kubeadm | kubeadm upgrade plan |
| 版本倾斜违规 | `version skew policy violated` | kubeadm | kubeadm upgrade |
| 控制平面升级失败 | `failed to upgrade control plane` | kubeadm | kubeadm 输出 |
| etcd 升级失败 | `etcd cluster is not healthy` | kubeadm | kubeadm 输出 |
| 组件启动失败 | `kube-apiserver: failed to start` | systemd | journalctl |
| 证书过期 | `certificate has expired` | kubeadm | kubeadm certs check-expiration |
| 配置不兼容 | `unknown flag` / `invalid config` | 组件日志 | journalctl |

#### 1.2.2 节点管理问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 节点 drain 卡住 | `cannot evict pod` | kubectl | kubectl drain 输出 |
| 节点加入失败 | `unable to join cluster` | kubeadm | kubeadm join 输出 |
| 节点 NotReady | `node not ready` | kubectl | kubectl get nodes |
| kubelet 启动失败 | `kubelet: failed to start` | systemd | journalctl -u kubelet |
| 节点证书过期 | `certificate expired` | kubelet | kubelet 日志 |
| 节点无法删除 | `node has finalizers` | kubectl | kubectl describe node |

#### 1.2.3 备份恢复问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| 快照创建失败 | `snapshot failed` | etcdctl | etcdctl 输出 |
| 快照恢复失败 | `restore failed` | etcdctl | etcdctl 输出 |
| 数据目录冲突 | `data-dir already exists` | etcdctl | etcdctl 输出 |
| 集群成员不一致 | `member count mismatch` | etcdctl | etcdctl member list |

### 1.3 报错查看方式汇总

```bash
# 集群版本信息
kubectl version
kubectl get nodes -o wide
kubeadm version

# 控制平面组件状态
kubectl get pods -n kube-system -o wide
kubectl get componentstatuses  # 已废弃，但部分版本仍可用

# 控制平面组件日志
journalctl -u kubelet -f
crictl logs $(crictl ps -q --name kube-apiserver)
crictl logs $(crictl ps -q --name kube-controller-manager)
crictl logs $(crictl ps -q --name kube-scheduler)

# 升级计划和检查
kubeadm upgrade plan
kubeadm upgrade plan --config kubeadm-config.yaml

# 证书状态
kubeadm certs check-expiration

# etcd 状态
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  endpoint status --cluster --write-out=table

# 节点状态
kubectl get nodes
kubectl describe node <node-name>
```

### 1.4 影响面分析

| 问题类型 | 直接影响 | 间接影响 | 影响范围 |
|----------|----------|----------|----------|
| 控制平面升级失败 | API 不可用 | 所有操作失败 | 集群级 |
| 版本不兼容 | 组件通信失败 | 服务中断 | 集群级 |
| etcd 故障 | 数据不可用 | 集群完全不可用 | 集群级 |
| 节点 drain 失败 | 节点无法维护 | 升级阻塞 | 节点级 |
| kubelet 故障 | Pod 无法运行 | 服务降级 | 节点级 |
| 证书过期 | 认证失败 | 集群不可用 | 集群级 |

---

## 第二部分：排查原理与方法

### 2.1 排查决策树

```
集群运维问题
    │
    ├─► 升级问题
    │       │
    │       ├─► 升级前检查失败
    │       │       │
    │       │       ├─► 版本跨度过大 ──► 分步升级
    │       │       ├─► etcd 不健康 ──► 修复 etcd
    │       │       ├─► 证书即将过期 ──► 先续期证书
    │       │       └─► 废弃 API 使用 ──► 迁移 API
    │       │
    │       ├─► 控制平面升级失败
    │       │       │
    │       │       ├─► 组件启动失败 ──► 检查配置和日志
    │       │       ├─► 镜像拉取失败 ──► 检查镜像仓库
    │       │       └─► 配置不兼容 ──► 更新配置文件
    │       │
    │       └─► 节点升级失败
    │               │
    │               ├─► kubelet 启动失败 ──► 检查配置
    │               ├─► 版本不匹配 ──► 检查版本倾斜
    │               └─► 证书问题 ──► 重新生成证书
    │
    ├─► 节点管理问题
    │       │
    │       ├─► drain 卡住
    │       │       │
    │       │       ├─► PDB 阻止 ──► 检查/调整 PDB
    │       │       ├─► 本地存储 ──► 添加 --delete-emptydir-data
    │       │       ├─► DaemonSet Pod ──► 添加 --ignore-daemonsets
    │       │       └─► Finalizer 阻塞 ──► 检查 Finalizer
    │       │
    │       ├─► 节点加入失败
    │       │       │
    │       │       ├─► Token 过期 ──► 生成新 Token
    │       │       ├─► 网络不通 ──► 检查网络
    │       │       └─► 端口冲突 ──► 检查端口占用
    │       │
    │       └─► 节点 NotReady
    │               │
    │               ├─► kubelet 未运行 ──► 启动 kubelet
    │               ├─► 容器运行时故障 ──► 检查 containerd
    │               └─► 网络问题 ──► 检查节点网络
    │
    └─► 备份恢复问题
            │
            ├─► 备份失败 ──► 检查磁盘空间和权限
            │
            └─► 恢复失败
                    │
                    ├─► 数据目录存在 ──► 清理旧目录
                    ├─► 成员配置错误 ──► 检查集群配置
                    └─► 快照损坏 ──► 使用其他备份
```

### 2.2 排查命令集

#### 2.2.1 升级前检查

```bash
# 检查当前版本
kubectl version --short
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}: {.status.nodeInfo.kubeletVersion}{"\n"}{end}'

# 检查升级计划
kubeadm upgrade plan

# 检查废弃 API
kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis

# 使用 kubent 检查废弃 API (需要安装)
kubent

# 检查证书有效期
kubeadm certs check-expiration

# 检查 etcd 健康状态
etcdctl endpoint health --cluster

# 检查集群组件状态
kubectl get pods -n kube-system

# 检查节点状态
kubectl get nodes
kubectl top nodes
```

#### 2.2.2 控制平面升级

```bash
# 查看可用版本
apt-cache madison kubeadm  # Debian/Ubuntu
yum list kubeadm --showduplicates  # RHEL/CentOS

# 升级 kubeadm
apt-mark unhold kubeadm
apt-get update && apt-get install -y kubeadm=1.xx.x-00
apt-mark hold kubeadm

# 验证 kubeadm 版本
kubeadm version

# 模拟升级 (dry-run)
kubeadm upgrade apply v1.xx.x --dry-run

# 执行升级 (第一个控制平面节点)
kubeadm upgrade apply v1.xx.x

# 其他控制平面节点
kubeadm upgrade node

# 升级 kubelet 和 kubectl
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.xx.x-00 kubectl=1.xx.x-00
apt-mark hold kubelet kubectl

# 重启 kubelet
systemctl daemon-reload
systemctl restart kubelet
```

#### 2.2.3 节点维护

```bash
# 禁止调度
kubectl cordon <node-name>

# 驱逐 Pod
kubectl drain <node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force \
  --grace-period=30

# 检查驱逐进度
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=<node-name>

# 恢复调度
kubectl uncordon <node-name>

# 删除节点
kubectl delete node <node-name>

# 在节点上重置 (用于重新加入)
kubeadm reset
rm -rf /etc/kubernetes/ /var/lib/kubelet/ /var/lib/etcd/

# 生成加入 token
kubeadm token create --print-join-command

# 节点加入集群
kubeadm join <api-server>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

#### 2.2.4 etcd 备份恢复

```bash
# 设置环境变量
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/healthcheck-client.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/healthcheck-client.key

# 创建备份
etcdctl snapshot save /backup/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db

# 验证备份
etcdctl snapshot status /backup/etcd-snapshot.db --write-out=table

# 恢复备份 (单节点)
# 1. 停止控制平面
mv /etc/kubernetes/manifests/*.yaml /tmp/

# 2. 备份当前数据
mv /var/lib/etcd /var/lib/etcd.bak

# 3. 恢复
etcdctl snapshot restore /backup/etcd-snapshot.db \
  --data-dir=/var/lib/etcd \
  --name=<etcd-name> \
  --initial-cluster=<etcd-name>=https://<ip>:2380 \
  --initial-advertise-peer-urls=https://<ip>:2380

# 4. 恢复控制平面
mv /tmp/*.yaml /etc/kubernetes/manifests/

# 5. 验证
kubectl get nodes
```

### 2.3 排查注意事项

| 注意项 | 说明 | 风险 |
|--------|------|------|
| 升级顺序 | 必须先控制平面后工作节点 | 版本倾斜导致故障 |
| 备份 etcd | 升级前必须备份 | 数据丢失无法恢复 |
| 证书有效期 | 升级前检查证书 | 证书过期导致失败 |
| 废弃 API | 检查并迁移废弃 API | 应用部署失败 |
| drain 超时 | 设置合理超时时间 | 长时间阻塞 |
| 回滚准备 | 准备回滚脚本和镜像 | 无法快速恢复 |

---

## 第三部分：解决方案与风险控制

### 3.1 升级失败回滚

#### 3.1.1 控制平面回滚

```bash
# 如果升级过程中失败，etcd 数据未损坏
# 1. 恢复旧版本 kubeadm
apt-get install -y kubeadm=<old-version>

# 2. 手动回滚静态 Pod 配置
# 如果有备份
cp /etc/kubernetes/manifests.backup/*.yaml /etc/kubernetes/manifests/

# 3. 降级 kubelet 和 kubectl
apt-get install -y kubelet=<old-version> kubectl=<old-version>
systemctl daemon-reload
systemctl restart kubelet

# 如果需要从 etcd 备份恢复
# 参考 etcd 恢复步骤
```

#### 3.1.2 使用 etcd 备份完整回滚

```bash
# 1. 停止所有控制平面节点的控制平面组件
# 在每个控制平面节点执行：
mv /etc/kubernetes/manifests/*.yaml /tmp/manifests-backup/

# 2. 在所有 etcd 节点恢复数据
# 清理旧数据
mv /var/lib/etcd /var/lib/etcd.failed

# 恢复快照 (需要在每个 etcd 节点执行，使用对应的配置)
etcdctl snapshot restore /backup/etcd-snapshot.db \
  --data-dir=/var/lib/etcd \
  --name=<etcd-node-name> \
  --initial-cluster=<etcd1>=https://<ip1>:2380,<etcd2>=https://<ip2>:2380,<etcd3>=https://<ip3>:2380 \
  --initial-cluster-token=etcd-cluster-1 \
  --initial-advertise-peer-urls=https://<this-node-ip>:2380

# 3. 恢复控制平面组件
mv /tmp/manifests-backup/*.yaml /etc/kubernetes/manifests/

# 4. 验证
kubectl get nodes
kubectl get pods -A
```

### 3.2 节点 drain 卡住解决

#### 3.2.1 诊断原因

```bash
# 检查哪些 Pod 阻止了 drain
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=<node-name>

# 检查 PDB 状态
kubectl get pdb -A

# 检查 Pod 的 PDB 约束
kubectl get pdb -A -o jsonpath='{range .items[*]}{.metadata.name}: {.status.disruptionsAllowed}{"\n"}{end}'
```

#### 3.2.2 解决方案

```bash
# 方案 1：使用更强的 drain 选项
kubectl drain <node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force \
  --grace-period=60 \
  --timeout=300s

# 方案 2：临时调整 PDB
# 查看阻塞的 PDB
kubectl get pdb <pdb-name> -o yaml

# 临时增加 maxUnavailable
kubectl patch pdb <pdb-name> -p '{"spec":{"maxUnavailable":1}}'

# 方案 3：手动删除阻塞的 Pod (最后手段)
kubectl delete pod <pod-name> --grace-period=30

# 方案 4：处理有 finalizer 的 Pod
kubectl patch pod <pod-name> -p '{"metadata":{"finalizers":null}}'
```

### 3.3 证书过期处理

#### 3.3.1 检查和续期

```bash
# 检查证书有效期
kubeadm certs check-expiration

# 续期所有证书
kubeadm certs renew all

# 续期特定证书
kubeadm certs renew apiserver
kubeadm certs renew apiserver-kubelet-client
kubeadm certs renew front-proxy-client

# 重启控制平面组件以加载新证书
# 对于静态 Pod，移动文件触发重启
cd /etc/kubernetes/manifests
mv kube-apiserver.yaml /tmp/ && sleep 5 && mv /tmp/kube-apiserver.yaml .
mv kube-controller-manager.yaml /tmp/ && sleep 5 && mv /tmp/kube-controller-manager.yaml .
mv kube-scheduler.yaml /tmp/ && sleep 5 && mv /tmp/kube-scheduler.yaml .

# 更新 kubeconfig
cp /etc/kubernetes/admin.conf ~/.kube/config
```

#### 3.3.2 kubelet 证书续期

```bash
# 检查 kubelet 证书
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates

# kubelet 自动续期配置 (v1.19+)
# 确保 kubelet 配置包含：
cat /var/lib/kubelet/config.yaml | grep -A2 "serverTLSBootstrap"

# 手动续期 kubelet 证书 (如果自动续期未启用)
# 删除旧证书，重启 kubelet 会自动申请新证书
rm /var/lib/kubelet/pki/kubelet-client-current.pem
systemctl restart kubelet

# 批准 CSR (如果需要)
kubectl get csr | grep Pending
kubectl certificate approve <csr-name>
```

### 3.4 升级检查清单

```bash
# 升级前检查脚本
#!/bin/bash
echo "=== 升级前检查 ==="

echo "1. 当前版本:"
kubectl version --short

echo "2. 节点状态:"
kubectl get nodes

echo "3. 证书有效期:"
kubeadm certs check-expiration

echo "4. etcd 健康:"
etcdctl endpoint health --cluster

echo "5. 控制平面组件:"
kubectl get pods -n kube-system | grep -E "apiserver|controller|scheduler|etcd"

echo "6. 废弃 API 检查:"
kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis | head -10

echo "7. PDB 状态 (可能影响 drain):"
kubectl get pdb -A

echo "8. 磁盘空间:"
df -h /var/lib/etcd /var/lib/kubelet

echo "=== 检查完成 ==="
```

### 3.5 安全生产风险提示

| 操作 | 风险等级 | 风险描述 | 防护措施 |
|------|----------|----------|----------|
| 集群升级 | 高 | 可能导致服务中断 | 维护窗口执行，准备回滚 |
| etcd 备份恢复 | 高 | 数据覆盖，丢失变更 | 确认时间点，多副本验证 |
| 节点 drain | 中 | 服务临时降级 | 检查 PDB，逐节点执行 |
| 证书续期 | 中 | 短暂服务中断 | 重启组件时间要快 |
| 节点删除 | 高 | 本地数据丢失 | 确认 Pod 已迁移 |
| 强制删除 Pod | 中 | 数据丢失风险 | 仅用于无状态 Pod |
| kubeadm reset | 高 | 节点配置清除 | 确认是目标节点 |

```
⚠️  安全生产风险提示：
1. 升级前必须备份 etcd，并验证备份可恢复
2. 严格遵守版本倾斜策略，不要跨多个版本升级
3. 升级在维护窗口执行，准备回滚方案
4. 先升级控制平面，再升级工作节点
5. 逐个节点升级，验证后再继续下一个
6. 检查并迁移废弃 API，避免升级后应用故障
7. 升级 etcd 时确保有多数节点可用
8. 证书续期后必须重启组件加载新证书
```

---

## 附录

### A. 版本倾斜策略速查

| 组件 | 与 kube-apiserver 版本关系 | 示例 |
|------|------------------------------|------|
| kube-apiserver | 基准版本 | 1.28 |
| kube-controller-manager | 同版本或低 1 个次版本 | 1.28 或 1.27 |
| kube-scheduler | 同版本或低 1 个次版本 | 1.28 或 1.27 |
| cloud-controller-manager | 同版本或低 1 个次版本 | 1.28 或 1.27 |
| kubelet | 同版本或低 2 个次版本 | 1.28, 1.27, 或 1.26 |
| kube-proxy | 同版本或低 2 个次版本 | 1.28, 1.27, 或 1.26 |
| kubectl | ±1 个次版本 | 1.29, 1.28, 或 1.27 |

### B. 升级检查清单

**升级前**:
- [ ] 已备份 etcd (验证备份可用)
- [ ] 证书有效期 > 30 天
- [ ] 已检查废弃 API 使用
- [ ] 节点资源充足
- [ ] 已准备回滚方案
- [ ] 已安排维护窗口
- [ ] 已通知相关团队
- [ ] 已验证升级路径合规

**升级中**:
- [ ] 第一个控制平面节点升级成功
- [ ] 所有控制平面节点升级成功
- [ ] 控制平面 kubelet 升级成功
- [ ] 逐个工作节点升级

**升级后**:
- [ ] 所有节点版本一致
- [ ] 控制平面组件健康
- [ ] 工作负载正常运行
- [ ] 监控告警正常
- [ ] 已更新文档记录

### C. 常用命令速查

```bash
# 版本检查
kubectl version
kubeadm version
kubelet --version

# 升级
kubeadm upgrade plan
kubeadm upgrade apply v1.xx.x
kubeadm upgrade node

# 节点管理
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl uncordon <node>

# 证书管理
kubeadm certs check-expiration
kubeadm certs renew all

# etcd 备份
etcdctl snapshot save /path/to/backup.db
etcdctl snapshot status /path/to/backup.db
etcdctl snapshot restore /path/to/backup.db --data-dir=/var/lib/etcd

# Token 管理
kubeadm token list
kubeadm token create --print-join-command
```

### D. 故障恢复联系清单

遇到以下情况建议立即升级处理：
- etcd 数据损坏或不可用
- 多数控制平面节点故障
- 集群完全不可用
- 证书全部过期
- 安全相关紧急事件
