# 表格11：升级路径表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/tasks/administer-cluster/cluster-upgrade](https://kubernetes.io/releases/version-skew-policy/)

## 版本支持策略

| 版本 | 发布日期 | EOL日期 | 支持状态 | 迁移紧迫性 |
|-----|---------|--------|---------|-----------|
| **v1.25** | 2022-08 | 2023-10 | **EOL** | 紧急迁移 |
| **v1.26** | 2022-12 | 2024-02 | **EOL** | 紧急迁移 |
| **v1.27** | 2023-04 | 2024-06 | **EOL** | 尽快迁移 |
| **v1.28** | 2023-08 | 2024-10 | **EOL** | 计划迁移 |
| **v1.29** | 2023-12 | 2025-02 | 维护中 | 关注 |
| **v1.30** | 2024-04 | 2025-06 | 维护中 | 稳定 |
| **v1.31** | 2024-08 | 2025-10 | 维护中 | 推荐 |
| **v1.32** | 2024-12 | 2026-02 | 最新稳定 | 推荐 |

## 版本偏差策略

| 组件 | 与apiserver版本偏差 | 说明 | 升级顺序 |
|-----|-------------------|------|---------|
| **kube-apiserver** | 同一HA集群内可差1个次版本 | HA升级期间允许 | 1(最先) |
| **kubelet** | 可比apiserver低2个次版本 | 节点可晚升级 | 3(最后) |
| **kube-controller-manager** | 不能高于apiserver | 必须先升级apiserver | 2 |
| **kube-scheduler** | 不能高于apiserver | 必须先升级apiserver | 2 |
| **kube-proxy** | 与kubelet相同 | 随节点升级 | 3 |
| **kubectl** | 可与apiserver差1个次版本 | 客户端灵活 | 任意 |

## 升级路径规划

| 起始版本 | 目标版本 | 升级步骤 | 关键变更 | 预计停机 | 风险等级 |
|---------|---------|---------|---------|---------|---------|
| **v1.25** | v1.26 | 直接升级 | nftables Alpha | 滚动零停机 | 低 |
| **v1.26** | v1.27 | 直接升级 | 就地调整Alpha | 滚动零停机 | 低 |
| **v1.27** | v1.28 | 直接升级 | Sidecar容器Beta | 滚动零停机 | 低 |
| **v1.28** | v1.29 | 直接升级 | LB IP模式 | 滚动零停机 | 低 |
| **v1.29** | v1.30 | 直接升级 | CEL准入GA | 滚动零停机 | 低 |
| **v1.30** | v1.31 | 直接升级 | AppArmor GA | 滚动零停机 | 低 |
| **v1.31** | v1.32 | 直接升级 | DRA改进 | 滚动零停机 | 低 |
| **v1.25** | v1.32 | 逐版本升级(7步) | 多项重大变更 | 需规划 | 中-高 |

## 重大破坏性变更时间线

| 版本 | 变更内容 | 影响范围 | 迁移工作 | 回滚难度 |
|-----|---------|---------|---------|---------|
| **v1.24** | 移除Dockershim | 所有使用Docker的节点 | 迁移到containerd | 需要重新配置 |
| **v1.25** | 移除PodSecurityPolicy | 使用PSP的集群 | 迁移到PSA | 需要重新设计 |
| **v1.25** | 移除多个beta API | 使用旧API的YAML | 更新API版本 | 低 |
| **v1.27** | flowcontrol v1beta2移除 | 自定义限流配置 | 升级到v1 | 低 |
| **v1.29** | 移除部分弃用API | 检查deprecation警告 | 更新资源定义 | 低 |

## 升级前检查清单

| 检查项 | 命令/方法 | 通过标准 | 阻塞级别 |
|-------|---------|---------|---------|
| **API弃用检查** | `kubectl get --raw /metrics \| grep apiserver_requested_deprecated_apis` | 无弃用API使用 | P0 |
| **etcd健康** | `etcdctl endpoint health` | 所有节点healthy | P0 |
| **etcd备份** | `etcdctl snapshot save` | 备份成功 | P0 |
| **控制平面健康** | `kubectl get cs` 或 `/readyz` | 所有组件健康 | P0 |
| **节点状态** | `kubectl get nodes` | 所有节点Ready | P0 |
| **PDB检查** | `kubectl get pdb -A` | 允许中断 | P1 |
| **存储状态** | `kubectl get pv,pvc -A` | 无Pending/Lost | P1 |
| **Webhook检查** | `kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations` | Webhook可用 | P1 |
| **资源配额** | 检查云资源配额 | 足够扩容 | P1 |
| **版本兼容性** | 检查组件版本矩阵 | 兼容 | P0 |

## kubeadm升级步骤

```bash
# 1. 升级第一个控制平面节点
# 查看可用版本
apt update
apt-cache madison kubeadm

# 升级kubeadm
apt-mark unhold kubeadm
apt-get update && apt-get install -y kubeadm=1.32.x-00
apt-mark hold kubeadm

# 验证升级计划
kubeadm upgrade plan

# 执行升级
kubeadm upgrade apply v1.32.x

# 升级kubelet和kubectl
apt-mark unhold kubelet kubectl
apt-get update && apt-get install -y kubelet=1.32.x-00 kubectl=1.32.x-00
apt-mark hold kubelet kubectl

# 重启kubelet
systemctl daemon-reload
systemctl restart kubelet

# 2. 升级其他控制平面节点
kubeadm upgrade node

# 3. 升级工作节点
# 腾空节点
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# 升级kubeadm, kubelet, kubectl(同上)
kubeadm upgrade node

# 重启kubelet
systemctl daemon-reload
systemctl restart kubelet

# 恢复调度
kubectl uncordon <node-name>
```

## ACK升级方式

| 升级方式 | 适用场景 | 控制平面 | 节点 | 停机影响 |
|---------|---------|---------|------|---------|
| **控制台一键升级** | 托管版 | 自动 | 手动/自动 | 滚动零停机 |
| **节点池滚动升级** | 节点升级 | - | 滚动替换 | 滚动零停机 |
| **蓝绿升级** | 大版本跨越 | 新集群 | 新节点 | 切换窗口 |
| **原地升级** | 小版本 | 原地 | 原地 | 可能短暂中断 |

```bash
# ACK CLI升级示例
aliyun cs UpgradeCluster --ClusterId <cluster-id> --version 1.32.x

# 查看升级状态
aliyun cs DescribeClusterDetail --ClusterId <cluster-id>
```

## 升级后验证

| 验证项 | 命令 | 期望结果 |
|-------|------|---------|
| **版本确认** | `kubectl version` | 目标版本 |
| **节点状态** | `kubectl get nodes -o wide` | 全部Ready，版本正确 |
| **系统Pod** | `kubectl get pods -n kube-system` | 全部Running |
| **CoreDNS** | `kubectl run test --rm -it --image=busybox -- nslookup kubernetes` | 解析成功 |
| **应用健康** | `kubectl get pods -A` | 全部正常 |
| **Service访问** | 测试关键Service | 正常响应 |
| **存储** | `kubectl get pv,pvc -A` | 状态正常 |
| **Ingress** | 测试Ingress路由 | 正常访问 |
| **监控** | 检查Prometheus/Grafana | 指标正常 |
| **日志** | 检查日志系统 | 日志正常 |

## 回滚策略

| 场景 | 回滚方法 | 数据影响 | 时间估计 |
|-----|---------|---------|---------|
| **控制平面升级失败** | etcd快照恢复 | 可能丢失最近数据 | 30-60分钟 |
| **节点升级失败** | 重建节点或降级 | 无数据丢失 | 根据节点数 |
| **应用不兼容** | 回滚Deployment | 无 | 分钟级 |
| **全集群问题** | 从备份恢复 | 恢复到备份点 | 1-2小时 |

```bash
# etcd快照恢复
etcdctl snapshot restore snapshot.db \
  --data-dir=/var/lib/etcd-restore \
  --name=<node-name> \
  --initial-cluster=<initial-cluster> \
  --initial-advertise-peer-urls=https://<ip>:2380
```

## 升级窗口规划

| 阶段 | 时间 | 活动 | 人员 |
|-----|------|------|------|
| **准备(D-7)** | 1-2天 | 检查清单，备份，测试环境验证 | SRE |
| **通知(D-3)** | - | 发送变更通知 | PM |
| **预检(D-1)** | 2小时 | 最终检查，确认备份 | SRE |
| **升级(D)** | 2-4小时 | 执行升级 | SRE |
| **验证(D)** | 1-2小时 | 功能验证 | SRE+QA |
| **监控(D+1~3)** | 持续 | 监控异常 | SRE |
| **收尾(D+7)** | - | 文档更新，复盘 | Team |

---

**升级原则**: 充分测试，逐步推进，随时回滚
