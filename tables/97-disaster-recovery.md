# Kubernetes 灾难恢复

> Kubernetes 版本: v1.25 - v1.32 | 适用环境: 生产集群

## 灾难恢复等级

| DR 等级 | RTO | RPO | 成本 | 实现方式 |
|---------|-----|-----|------|----------|
| 冷备 | 4-24小时 | 24小时 | 低 | 定期备份恢复 |
| 温备 | 1-4小时 | 1-4小时 | 中 | 备用集群 + 同步备份 |
| 热备 | <1小时 | <1小时 | 中高 | 多集群主备切换 |
| 双活 | 分钟级 | 接近0 | 高 | 多集群同时运行 |

## 集群级灾难恢复架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        全局负载均衡 (GSLB)                        │
└─────────────────────────────────────────────────────────────────┘
                    │                           │
           ┌───────┴───────┐           ┌───────┴───────┐
           │   主集群       │           │   备集群       │
           │  (Region A)   │           │  (Region B)   │
           └───────────────┘           └───────────────┘
                    │                           │
           ┌───────┴───────┐           ┌───────┴───────┐
           │  数据库主库    │  ──────>  │  数据库从库    │
           │  (RDS/MySQL)  │   同步     │  (RDS/MySQL)  │
           └───────────────┘           └───────────────┘
                    │                           │
           ┌───────┴───────┐           ┌───────┴───────┐
           │  对象存储      │  ──────>  │  对象存储      │
           │  (OSS/S3)     │   复制     │  (OSS/S3)     │
           └───────────────┘           └───────────────┘
```

## 控制平面灾难恢复

```bash
#!/bin/bash
# 控制平面完整恢复脚本

set -e

BACKUP_DIR=$1
NEW_MASTER_IP=$2

echo "=== 控制平面恢复开始 ==="

# 1. 恢复 etcd 数据
echo "步骤1: 恢复 etcd 数据..."
ETCDCTL_API=3 etcdctl snapshot restore ${BACKUP_DIR}/etcd-snapshot.db \
  --data-dir=/var/lib/etcd \
  --initial-cluster="master-0=https://${NEW_MASTER_IP}:2380" \
  --initial-advertise-peer-urls="https://${NEW_MASTER_IP}:2380" \
  --name=master-0

# 2. 恢复 PKI 证书
echo "步骤2: 恢复 PKI 证书..."
cp -r ${BACKUP_DIR}/pki /etc/kubernetes/

# 3. 恢复 kubeconfig 文件
echo "步骤3: 恢复 kubeconfig..."
cp ${BACKUP_DIR}/*.conf /etc/kubernetes/

# 4. 更新证书中的 IP (如果 IP 变化)
echo "步骤4: 检查证书..."
kubeadm certs check-expiration

# 5. 恢复 Static Pod manifests
echo "步骤5: 恢复 Static Pod manifests..."
cp -r ${BACKUP_DIR}/manifests /etc/kubernetes/

# 6. 启动 kubelet
echo "步骤6: 启动 kubelet..."
systemctl daemon-reload
systemctl restart kubelet

# 7. 等待控制平面就绪
echo "步骤7: 等待控制平面就绪..."
until kubectl get nodes; do
  echo "等待 API Server 启动..."
  sleep 10
done

# 8. 恢复集群资源 (使用 Velero)
echo "步骤8: 恢复集群资源..."
velero restore create --from-backup latest-backup

echo "=== 控制平面恢复完成 ==="
```

## 跨区域故障切换

```yaml
# ExternalDNS 配置 (用于自动 DNS 切换)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: registry.k8s.io/external-dns/external-dns:v0.14.0
        args:
        - --source=service
        - --source=ingress
        - --provider=alibabacloud
        - --policy=sync
        - --registry=txt
        - --txt-owner-id=my-cluster
        - --domain-filter=example.com
        env:
        - name: ALICLOUD_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: alicloud-credentials
              key: access-key
        - name: ALICLOUD_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: alicloud-credentials
              key: secret-key
```

## 数据库灾难恢复

```yaml
# MySQL 主从切换脚本 ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-failover-scripts
data:
  promote-slave.sh: |
    #!/bin/bash
    # 提升从库为主库
    
    # 1. 停止从库复制
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "STOP SLAVE;"
    
    # 2. 重置从库状态
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "RESET SLAVE ALL;"
    
    # 3. 启用写入
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SET GLOBAL read_only = OFF;"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "SET GLOBAL super_read_only = OFF;"
    
    # 4. 创建复制用户 (供其他从库使用)
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY '${REPL_PASSWORD}';"
    mysql -u root -p${MYSQL_ROOT_PASSWORD} -e "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';"
    
    echo "Slave promoted to master successfully"
---
# 切换 Service 指向
apiVersion: v1
kind: Service
metadata:
  name: mysql-primary
  annotations:
    service.kubernetes.io/topology-mode: Auto
spec:
  selector:
    app: mysql
    role: primary  # 修改此标签以切换
  ports:
  - port: 3306
```

## 应用级故障切换

```yaml
# Argo Rollouts 跨集群渐进式切换
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: app-multicluster
spec:
  replicas: 10
  strategy:
    canary:
      trafficRouting:
        managedRoutes:
        - name: primary-route
        plugins:
          argoproj-labs/gatewayAPI:
            httpRoute: app-route
            namespace: production
      steps:
      # 灾难切换步骤
      - setWeight: 10  # 10% 流量到备集群
      - pause: {duration: 5m}
      - analysis:
          templates:
          - templateName: success-rate
      - setWeight: 50
      - pause: {duration: 5m}
      - analysis:
          templates:
          - templateName: success-rate
      - setWeight: 100  # 完全切换
```

## 故障切换检查清单

```yaml
# 切换前检查 ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: failover-checklist
data:
  pre-failover.md: |
    ## 故障切换前检查清单
    
    ### 备集群状态检查
    - [ ] 所有节点 Ready
    - [ ] 控制平面组件正常
    - [ ] CNI 网络正常
    - [ ] CoreDNS 正常
    - [ ] 存储类可用
    
    ### 数据同步检查
    - [ ] etcd 备份时间 < 1小时
    - [ ] 数据库复制延迟 < 1分钟
    - [ ] 对象存储同步完成
    - [ ] 配置同步完成
    
    ### 应用就绪检查
    - [ ] 关键应用 Deployment 就绪
    - [ ] PVC 绑定正常
    - [ ] Secret/ConfigMap 同步
    - [ ] 外部依赖可访问
    
  post-failover.md: |
    ## 故障切换后检查清单
    
    ### 服务可用性
    - [ ] DNS 切换生效
    - [ ] 负载均衡健康检查通过
    - [ ] 关键 API 响应正常
    - [ ] 用户访问正常
    
    ### 数据一致性
    - [ ] 数据库主从切换完成
    - [ ] 应用数据验证
    - [ ] 缓存预热完成
    
    ### 监控告警
    - [ ] 监控指标正常
    - [ ] 告警规则生效
    - [ ] 日志收集正常
```

## DR 演练流程

```bash
#!/bin/bash
# DR 演练脚本

set -e

DRILL_ID="dr-drill-$(date +%Y%m%d)"
LOG_FILE="/var/log/dr-drills/${DRILL_ID}.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a ${LOG_FILE}
}

log "=== DR 演练开始: ${DRILL_ID} ==="

# 1. 演练前检查
log "步骤1: 演练前检查..."
kubectl get nodes -o wide
kubectl get pods -A | grep -v Running | grep -v Completed

# 2. 模拟主集群故障 (标记为不可调度)
log "步骤2: 模拟主集群故障..."
# kubectl cordon 主集群节点 (在演练环境执行)

# 3. 触发故障切换
log "步骤3: 触发故障切换..."
# 执行故障切换脚本

# 4. 验证备集群服务
log "步骤4: 验证备集群服务..."
# curl 检查关键服务

# 5. 验证数据一致性
log "步骤5: 验证数据一致性..."
# 数据校验脚本

# 6. 恢复主集群
log "步骤6: 恢复主集群..."
# kubectl uncordon 主集群节点

# 7. 故障回切
log "步骤7: 故障回切..."
# 切回主集群

# 8. 演练总结
log "步骤8: 生成演练报告..."
cat << EOF >> ${LOG_FILE}

## DR 演练报告

- 演练ID: ${DRILL_ID}
- 演练时间: $(date)
- RTO 实际: XX 分钟
- RPO 实际: XX 分钟
- 发现问题: 
  - 问题1
  - 问题2
- 改进建议:
  - 建议1
  - 建议2

EOF

log "=== DR 演练完成 ==="
```

## 监控告警规则

```yaml
groups:
- name: disaster-recovery
  rules:
  - alert: BackupClusterUnhealthy
    expr: |
      kube_node_status_condition{cluster="backup",condition="Ready",status="true"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "备集群节点不健康"
      
  - alert: DataReplicationLag
    expr: |
      mysql_slave_seconds_behind_master > 60
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "数据库复制延迟 > 60秒"
      
  - alert: CrossRegionLatencyHigh
    expr: |
      probe_duration_seconds{job="cross-region-probe"} > 0.5
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "跨区域延迟 > 500ms"
```

## DR 最佳实践

| 项目 | 建议 |
|------|------|
| RTO/RPO | 明确定义并与业务对齐 |
| 演练频率 | 每季度至少一次完整演练 |
| 自动化 | 尽可能自动化切换流程 |
| 文档 | 维护详细的恢复手册 |
| 监控 | 实时监控备集群和复制状态 |
| 通知 | 建立故障通知链 |
| 回滚 | 准备回滚计划 |
