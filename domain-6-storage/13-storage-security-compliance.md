# 13 - 存储安全与合规管理

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-02 | **运维重点**: 数据加密、访问控制、合规审计

## 目录

1. [存储加密策略](#存储加密策略)
2. [访问控制与权限管理](#访问控制与权限管理)
3. [数据保护与备份](#数据保护与备份)
4. [安全审计与合规](#安全审计与合规)
5. [漏洞扫描与防护](#漏洞扫描与防护)
6. [密钥管理最佳实践](#密钥管理最佳实践)
7. [合规性检查清单](#合规性检查清单)
8. [应急响应预案](#应急响应预案)

---

## 存储加密策略

### 静态数据加密

```yaml
# 启用静态加密的StorageClass配置
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: encrypted-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
  performanceLevel: PL1
  # 静态加密配置
  encrypted: "true"  # 启用加密
  kmsKeyId: "kms-key-12345678-1234-1234-1234-123456789012"  # KMS密钥ID
  encryptionAlgorithm: "AES-256"  # 加密算法
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### 加密状态验证脚本

```bash
#!/bin/bash
# encryption-validator.sh

validate_encryption_status() {
  echo "🔐 存储加密状态验证报告"
  echo "========================"
  
  # 1. 检查启用加密的StorageClass
  echo "1. 加密StorageClass检查:"
  ENCRYPTED_SC=$(kubectl get sc -o json | jq -r '.items[] | select(.parameters.encrypted=="true") | .metadata.name')
  if [ -n "$ENCRYPTED_SC" ]; then
    echo "✅ 已启用加密的StorageClass:"
    echo "$ENCRYPTED_SC"
  else
    echo "❌ 未发现启用加密的StorageClass"
  fi
  
  # 2. 检查加密PV统计
  echo ""
  echo "2. 加密PV统计:"
  TOTAL_PV=$(kubectl get pv --no-headers | wc -l)
  ENCRYPTED_PV=$(kubectl get pv -o json | jq -r '[.items[] | select(.spec.csi.volumeAttributes.encrypted=="true")] | length')
  
  echo "总PV数量: $TOTAL_PV"
  echo "加密PV数量: $ENCRYPTED_PV"
  echo "加密覆盖率: $((ENCRYPTED_PV * 100 / TOTAL_PV))%"
  
  # 3. 检查未加密的敏感数据PVC
  echo ""
  echo "3. 未加密敏感数据检查:"
  SENSITIVE_NAMESPACES=("production" "database" "finance")
  
  for NS in "${SENSITIVE_NAMESPACES[@]}"; do
    if kubectl get ns $NS >/dev/null 2>&1; then
      UNENCRYPTED_PVC=$(kubectl get pvc -n $NS -o json | \
        jq -r '.items[] | select(.spec.storageClassName as $sc | 
              [$sc] | inside($ENCRYPTED_SC)) | .metadata.name')
      
      if [ -n "$UNENCRYPTED_PVC" ]; then
        echo "⚠️  命名空间 $NS 中发现未使用加密StorageClass的PVC:"
        echo "$UNENCRYPTED_PVC"
      fi
    fi
  done
  
  # 4. KMS密钥状态检查
  echo ""
  echo "4. KMS密钥状态检查:"
  # 这里需要根据具体的云服务商API实现
  echo "TODO: 实现KMS密钥有效性检查"
}

# 生成合规报告
generate_compliance_report() {
  REPORT_FILE="/tmp/encryption-compliance-$(date +%Y%m%d).txt"
  
  cat > $REPORT_FILE <<EOF
存储加密合规报告
================
生成时间: $(date)
检查范围: 所有命名空间

主要发现:
1. 加密StorageClass数量: $(echo "$ENCRYPTED_SC" | wc -l)
2. 加密PV覆盖率: $((ENCRYPTED_PV * 100 / TOTAL_PV))%
3. 未加密敏感数据PVC: $(echo "$UNENCRYPTED_PVC" | wc -l)

合规建议:
- 确保所有生产环境PVC使用加密StorageClass
- 定期轮换KMS密钥
- 实施密钥访问审计
EOF
  
  echo "合规报告已生成: $REPORT_FILE"
}

validate_encryption_status
generate_compliance_report
```

### 传输加密配置

```yaml
# NFS存储传输加密配置
apiVersion: v1
kind: PersistentVolume
metadata:
  name: secure-nfs-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteMany
  mountOptions:
    - vers=4.1
    - sec=sys  # 使用系统认证
    - hard
    - timeo=600
    - retrans=2
  nfs:
    server: secure-nfs.example.com
    path: /secure/data
  # 通过网络策略限制访问
---
# 网络策略限制存储访问
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: storage-access-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: storage-client
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/8  # 限制只能访问内部存储网络
    ports:
    - protocol: TCP
      port: 2049  # NFS端口
```

---

## 访问控制与权限管理

### RBAC存储权限配置

```yaml
# 存储管理员角色
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: storage-admin
rules:
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses", "csidrivers", "csinodes"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["persistentvolumes", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["snapshot.storage.k8s.io"]
  resources: ["volumesnapshots", "volumesnapshotcontents", "volumesnapshotclasses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

---
# 存储只读角色
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: storage-viewer
rules:
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses", "csidrivers", "csinodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["persistentvolumes", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["snapshot.storage.k8s.io"]
  resources: ["volumesnapshots", "volumesnapshotcontents", "volumesnapshotclasses"]
  verbs: ["get", "list", "watch"]

---
# 命名空间级别存储权限
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-storage-user
  namespace: production
rules:
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["get", "list"]
```

### Pod安全策略配置

```yaml
# 限制容器直接访问主机存储
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted-storage-access
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - configMap
    - emptyDir
    - projected
    - secret
    - downwardAPI
    - persistentVolumeClaim  # 只允许通过PVC访问存储
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'MustRunAs'
    ranges:
      - min: 1
        max: 65535
  fsGroup:
    rule: 'MustRunAs'
    ranges:
      - min: 1
        max: 65535
  readOnlyRootFilesystem: true
```

### 存储访问审计

```bash
#!/bin/bash
# storage-access-audit.sh

AUDIT_NAMESPACE="production"
LOG_OUTPUT="/var/log/storage-audit.log"

audit_storage_access() {
  echo "$(date): 开始存储访问审计" >> $LOG_OUTPUT
  
  # 1. 检查未授权的PVC创建
  echo "$(date): 检查未授权PVC创建" >> $LOG_OUTPUT
  kubectl get events -n $AUDIT_NAMESPACE --field-selector reason=FailedCreate \
    | grep -i "persistentvolumeclaim" >> $LOG_OUTPUT 2>&1
  
  # 2. 检查异常的存储访问模式
  echo "$(date): 检查异常访问模式" >> $LOG_OUTPUT
  kubectl get pvc -n $AUDIT_NAMESPACE -o json | \
    jq -r '.items[] | select(.spec.accessModes[] == "ReadWriteMany" and .metadata.labels.app != "shared-service") | 
           "异常RWX访问: \(.metadata.name) 应用: \(.metadata.labels.app // "unknown")"' >> $LOG_OUTPUT
  
  # 3. 检查过大的存储请求
  echo "$(date): 检查过大存储请求" >> $LOG_OUTPUT
  kubectl get pvc -n $AUDIT_NAMESPACE -o json | \
    jq -r '.items[] | .spec.resources.requests.storage as $size | 
           select($size | endswith("Ti") or (.[:-2] | tonumber > 1000)) |
           "大容量请求: \(.metadata.name) 大小: $size"' >> $LOG_OUTPUT
  
  # 4. 生成审计报告
  SUMMARY=$(tail -20 $LOG_OUTPUT)
  echo "存储访问审计摘要:"
  echo "$SUMMARY"
  
  # 发送告警（如果发现异常）
  if echo "$SUMMARY" | grep -q "异常\|大容量"; then
    echo "🚨 发现存储访问异常，发送告警..."
    # 集成到告警系统
  fi
}

# 定期执行审计
while true; do
  audit_storage_access
  sleep 3600  # 每小时执行一次
done
```

---

## 数据保护与备份

### 备份策略配置

```yaml
# 自动化备份策略
apiVersion: batch/v1
kind: CronJob
metadata:
  name: storage-backup-cronjob
  namespace: backup-system
spec:
  schedule: "0 2 * * *"  # 每天凌晨2点执行
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: backup-operator
          containers:
          - name: backup-manager
            image: kudig/backup-manager:latest
            env:
            - name: BACKUP_RETENTION_DAYS
              value: "30"
            - name: STORAGE_CLASSES
              value: "fast-ssd,standard-ssd"
            - name: NAMESPACE_SELECTOR
              value: "environment=production"
            command:
            - /backup-manager
            - --mode=snapshot
            - --verify=true
            - --encrypt=true
            volumeMounts:
            - name: backup-config
              mountPath: /etc/backup
          volumes:
          - name: backup-config
            configMap:
              name: backup-policy-config
          restartPolicy: OnFailure
---
# 备份策略配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: backup-policy-config
  namespace: backup-system
data:
  backup-policy.yaml: |
    policies:
      critical-data:
        schedule: "0 2 * * *"
        retention: 30d
        encryption: true
        verification: true
        namespaces:
          - production
          - database
        pvc-labels:
          backup: "critical"
          
      standard-data:
        schedule: "0 3 * * 0"  # 每周日凌晨3点
        retention: 7d
        encryption: true
        namespaces:
          - staging
          - development
```

### 备份验证脚本

```bash
#!/bin/bash
# backup-verifier.sh

verify_backups() {
  echo "🔍 存储备份验证报告"
  echo "==================="
  
  # 1. 检查备份任务状态
  echo "1. 备份任务状态检查:"
  kubectl get cronjob -n backup-system | grep storage-backup
  kubectl get jobs -n backup-system --sort-by=.status.startTime | tail -5
  
  # 2. 验证快照完整性
  echo ""
  echo "2. 快照完整性验证:"
  SNAPSHOTS=$(kubectl get volumesnapshot -A -o json | \
    jq -r '.items[] | select(.status.readyToUse==true) | 
           "\(.metadata.namespace)/\(.metadata.name) - \(.status.creationTime)"')
  
  echo "可用快照数量: $(echo "$SNAPSHOTS" | wc -l)"
  echo "最近快照:"
  echo "$SNAPSHOTS" | tail -10
  
  # 3. 检查备份数据一致性
  echo ""
  echo "3. 数据一致性检查:"
  # 模拟数据校验过程
  CONSISTENT_SNAPSHOTS=$(kubectl get volumesnapshot -A -o json | \
    jq -r '[.items[] | select(.status.readyToUse==true and .status.error==null)] | length')
    
  TOTAL_SNAPSHOTS=$(kubectl get volumesnapshot -A --no-headers | wc -l)
  
  CONSISTENCY_RATE=$(echo "scale=2; $CONSISTENT_SNAPSHOTS * 100 / $TOTAL_SNAPSHOTS" | bc)
  echo "数据一致性率: ${CONSISTENCY_RATE}%"
  
  # 4. 备份容量统计
  echo ""
  echo "4. 备份容量统计:"
  BACKUP_STORAGE_USED=$(kubectl get volumesnapshotcontent -o json | \
    jq -r '[.items[].status.restoreSize // 0] | add / 1024/1024/1024')
  echo "备份存储使用总量: ${BACKUP_STORAGE_USED} Gi"
  
  # 5. 过期备份清理检查
  echo ""
  echo "5. 过期备份检查:"
  EXPIRED_SNAPSHOTS=$(kubectl get volumesnapshot -A -o json | \
    jq -r '.items[] | select(.metadata.creationTimestamp < "'$(date -d '30 days ago' --iso-8601)'") | 
           "\(.metadata.namespace)/\(.metadata.name)"')
           
  if [ -n "$EXPIRED_SNAPSHOTS" ]; then
    echo "⚠️  发现过期快照需要清理:"
    echo "$EXPIRED_SNAPSHOTS"
  else
    echo "✅ 无过期快照"
  fi
}

# 生成验证报告
generate_verification_report() {
  REPORT_FILE="/tmp/backup-verification-$(date +%Y%m%d).md"
  
  cat > $REPORT_FILE <<EOF
# 存储备份验证报告

## 基本信息
- 验证时间: $(date)
- 验证范围: 所有命名空间

## 验证结果
1. **备份任务状态**: $(kubectl get cronjob -n backup-system 2>/dev/null | grep -c "storage-backup") 个活跃任务
2. **可用快照数量**: $(echo "$SNAPSHOTS" | wc -l) 个
3. **数据一致性率**: ${CONSISTENCY_RATE}%
4. **备份存储使用**: ${BACKUP_STORAGE_USED} Gi
5. **过期快照**: $(echo "$EXPIRED_SNAPSHOTS" | wc -l) 个待清理

## 建议措施
- 定期验证备份数据可恢复性
- 监控备份任务执行状态
- 及时清理过期备份以节省成本
- 建立备份恢复演练机制
EOF
  
  echo "验证报告已生成: $REPORT_FILE"
}

verify_backups
generate_verification_report
```

---

## 安全审计与合规

### 审计日志配置

```yaml
# 启用存储操作审计
apiVersion: audit.k8s.io/v1
kind: Policy
metadata:
  name: storage-audit-policy
rules:
# 记录所有存储相关操作
- level: RequestResponse
  resources:
  - group: ""
    resources: ["persistentvolumes", "persistentvolumeclaims"]
  - group: "storage.k8s.io"
    resources: ["storageclasses", "csidrivers"]
  - group: "snapshot.storage.k8s.io"
    resources: ["volumesnapshots", "volumesnapshotcontents"]
  verbs: ["create", "update", "patch", "delete"]
  
# 详细记录敏感操作
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]  # 存储相关的密钥
  verbs: ["get", "list", "watch"]

---
# 审计Webhook配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: audit-webhook-config
  namespace: kube-system
data:
  audit-webhook.yaml: |
    apiVersion: audit.k8s.io/v1
    kind: Webhook
    clientConfig:
      url: "https://audit-collector.internal:8443/audit"
      caBundle: <base64-encoded-ca-cert>
    throttleQPS: 10
    throttleBurst: 15
```

### 合规性检查脚本

```bash
#!/bin/bash
# compliance-checker.sh

COMPLIANCE_REPORT="/tmp/compliance-report-$(date +%Y%m%d).html"

generate_compliance_report() {
  cat > $COMPLIANCE_REPORT <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>存储安全合规报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; }
        .compliant { color: green; }
        .non-compliant { color: red; }
        .warning { color: orange; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>存储安全合规报告</h1>
    <p>生成时间: $(date)</p>
    
    <div class="section">
        <h2>1. 加密合规检查</h2>
EOF

  # 检查加密配置
  ENCRYPTED_PV=$(kubectl get pv -o json | jq '[.items[] | select(.spec.csi.volumeAttributes.encrypted=="true")] | length')
  TOTAL_PV=$(kubectl get pv --no-headers | wc -l)
  
  if [ $ENCRYPTED_PV -eq $TOTAL_PV ] && [ $TOTAL_PV -gt 0 ]; then
    STATUS_CLASS="compliant"
    STATUS_TEXT="✅ 全部PV已加密"
  elif [ $ENCRYPTED_PV -gt 0 ]; then
    STATUS_CLASS="warning"
    STATUS_TEXT="⚠️ 部分PV已加密 ($ENCRYPTED_PV/$TOTAL_PV)"
  else
    STATUS_CLASS="non-compliant"
    STATUS_TEXT="❌ 未启用存储加密"
  fi
  
  cat >> $COMPLIANCE_REPORT <<EOF
        <p class="$STATUS_CLASS">$STATUS_TEXT</p>
    </div>
    
    <div class="section">
        <h2>2. 访问控制检查</h2>
EOF

  # 检查RBAC配置
  STORAGE_ROLES=$(kubectl get clusterroles | grep -c "storage")
  if [ $STORAGE_ROLES -gt 0 ]; then
    cat >> $COMPLIANCE_REPORT <<EOF
        <p class="compliant">✅ 已配置存储相关RBAC角色 ($STORAGE_ROLES 个)</p>
EOF
  else
    cat >> $COMPLIANCE_REPORT <<EOF
        <p class="non-compliant">❌ 未配置存储RBAC角色</p>
EOF
  fi
  
  cat >> $COMPLIANCE_REPORT <<EOF
    </div>
    
    <div class="section">
        <h2>3. 备份合规检查</h2>
EOF

  # 检查备份配置
  BACKUP_CRONJOBS=$(kubectl get cronjob -A | grep -c "backup")
  if [ $BACKUP_CRONJOBS -gt 0 ]; then
    cat >> $COMPLIANCE_REPORT <<EOF
        <p class="compliant">✅ 已配置自动备份策略 ($BACKUP_CRONJOBS 个任务)</p>
EOF
  else
    cat >> $COMPLIANCE_REPORT <<EOF
        <p class="non-compliant">❌ 未配置自动备份</p>
EOF
  fi
  
  cat >> $COMPLIANCE_REPORT <<EOF
    </div>
    
    <div class="section">
        <h2>4. 详细检查结果</h2>
        <table>
            <tr>
                <th>检查项</th>
                <th>状态</th>
                <th>详情</th>
            </tr>
            <tr>
                <td>PV加密状态</td>
                <td>$ENCRYPTED_PV/$TOTAL_PV</td>
                <td>加密覆盖率: $((ENCRYPTED_PV * 100 / TOTAL_PV))%</td>
            </tr>
            <tr>
                <td>RBAC角色配置</td>
                <td>$STORAGE_ROLES 个角色</td>
                <td>包括: storage-admin, storage-viewer</td>
            </tr>
            <tr>
                <td>备份任务配置</td>
                <td>$BACKUP_CRONJOBS 个任务</td>
                <td>每日自动执行</td>
            </tr>
        </table>
    </div>
</body>
</html>
EOF

  echo "合规报告已生成: $COMPLIANCE_REPORT"
}

# 执行合规检查
generate_compliance_report
echo "📋 存储安全合规检查完成"
```

---

## 漏洞扫描与防护

### 存储组件安全扫描

```bash
#!/bin/bash
# storage-security-scanner.sh

scan_storage_components() {
  echo "🛡️  存储安全扫描开始"
  echo "==================="
  
  VULNERABILITY_REPORT="/tmp/storage-vulnerabilities-$(date +%Y%m%d).txt"
  
  # 1. 扫描CSI驱动镜像
  echo "1. 扫描CSI驱动镜像..." | tee -a $VULNERABILITY_REPORT
  CSI_IMAGES=$(kubectl get pods -n kube-system -o jsonpath='{.items[*].spec.containers[*].image}' | \
    tr ' ' '\n' | grep -i csi)
    
  for IMAGE in $CSI_IMAGES; do
    echo "扫描镜像: $IMAGE" | tee -a $VULNERABILITY_REPORT
    # 这里集成镜像扫描工具，如Trivy、Clair等
    # trivy image --severity HIGH,CRITICAL $IMAGE >> $VULNERABILITY_REPORT
  done
  
  # 2. 检查存储配置安全
  echo "" | tee -a $VULNERABILITY_REPORT
  echo "2. 存储配置安全检查..." | tee -a $VULNERABILITY_REPORT
  
  # 检查是否使用默认密码
  DEFAULT_PASSWORDS=$(kubectl get secrets -A -o json | \
    jq -r '.items[] | select(.data.password) | .metadata.namespace + "/" + .metadata.name')
    
  if [ -n "$DEFAULT_PASSWORDS" ]; then
    echo "⚠️  发现包含密码的Secret:" | tee -a $VULNERABILITY_REPORT
    echo "$DEFAULT_PASSWORDS" | tee -a $VULNERABILITY_REPORT
  fi
  
  # 3. 网络安全检查
  echo "" | tee -a $VULNERABILITY_REPORT
  echo "3. 存储网络安全检查..." | tee -a $VULNERABILITY_REPORT
  
  # 检查开放的存储端口
  OPEN_PORTS=$(kubectl get svc -A -o json | \
    jq -r '.items[] | select(.spec.ports[].port as $port | [111,2049,3260] | inside([$port])) | 
           "\(.metadata.namespace)/\(.metadata.name):\(.spec.ports[].port)"')
           
  if [ -n "$OPEN_PORTS" ]; then
    echo "⚠️  发现开放的存储相关端口:" | tee -a $VULNERABILITY_REPORT
    echo "$OPEN_PORTS" | tee -a $VULNERABILITY_REPORT
  fi
  
  # 4. 生成安全评分
  echo "" | tee -a $VULNERABILITY_REPORT
  echo "4. 安全评分..." | tee -a $VULNERABILITY_REPORT
  
  SCORE=100
  if [ -n "$DEFAULT_PASSWORDS" ]; then SCORE=$((SCORE - 20)); fi
  if [ -n "$OPEN_PORTS" ]; then SCORE=$((SCORE - 15)); fi
  # 根据漏洞扫描结果扣分
  
  echo "总体安全评分: $SCORE/100" | tee -a $VULNERABILITY_REPORT
  
  if [ $SCORE -lt 80 ]; then
    echo "❌ 安全评分较低，建议立即修复" | tee -a $VULNERABILITY_REPORT
  elif [ $SCORE -lt 95 ]; then
    echo "⚠️  安全评分中等，建议优化配置" | tee -a $VULNERABILITY_REPORT
  else
    echo "✅ 安全评分良好" | tee -a $VULNERABILITY_REPORT
  fi
}

# 定期安全扫描
scan_storage_components
```

---

## 密钥管理最佳实践

### KMS集成配置

```yaml
# Kubernetes KMS Provider配置
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
metadata:
  name: storage-encryption-config
resources:
  - resources:
    - persistentvolumes
    - persistentvolumeclaims
    providers:
    - kms:
        name: aws-kms
        endpoint: unix:///var/run/kmsplugin/socket.sock
        cachesize: 1000
        timeout: 3s
    - identity: {}  # fallback provider
---
# KMS插件DaemonSet
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kms-plugin
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: kms-plugin
  template:
    metadata:
      labels:
        app: kms-plugin
    spec:
      containers:
      - name: kms-plugin
        image: kudig/kms-plugin:latest
        args:
        - --provider=aws
        - --key-id=arn:aws:kms:region:account:key/key-id
        - --socket-file=/var/run/kmsplugin/socket.sock
        volumeMounts:
        - name: kms-socket
          mountPath: /var/run/kmsplugin
      volumes:
      - name: kms-socket
        hostPath:
          path: /var/run/kmsplugin
```

### 密钥轮换策略

```bash
#!/bin/bash
# key-rotation-manager.sh

KEY_ROTATION_POLICY="30d"  # 30天轮换一次
DRY_RUN=${DRY_RUN:-false}

rotate_encryption_keys() {
  echo "🔄 开始密钥轮换流程"
  
  # 1. 检查上次轮换时间
  LAST_ROTATION=$(kubectl get configmap key-rotation-metadata -n kube-system -o jsonpath='{.data.last-rotation}' 2>/dev/null || echo "never")
  echo "上次轮换时间: $LAST_ROTATION"
  
  # 2. 生成新密钥
  echo "生成新加密密钥..."
  NEW_KEY_ID=$(aws kms create-key --description "Kubernetes Storage Encryption Key" --query 'KeyMetadata.KeyId' --output text)
  
  if [ "$DRY_RUN" = "true" ]; then
    echo "🧪 模拟模式: 新密钥ID为 $NEW_KEY_ID"
    return
  fi
  
  # 3. 更新KMS配置
  echo "更新KMS配置..."
  kubectl patch deployment kms-plugin -n kube-system -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"kms-plugin\",\"args\":[\"--key-id=$NEW_KEY_ID\"]}]}}}}"
  
  # 4. 重新加密现有数据
  echo "重新加密现有存储数据..."
  kubectl get pv -o json | jq -r '.items[].metadata.name' | while read pv; do
    echo "重新加密PV: $pv"
    # 这里需要具体的重新加密逻辑
  done
  
  # 5. 更新元数据
  kubectl create configmap key-rotation-metadata -n kube-system \
    --from-literal=last-rotation=$(date --iso-8601) \
    --from-literal=current-key=$NEW_KEY_ID \
    --dry-run=client -o yaml | kubectl apply -f -
  
  echo "✅ 密钥轮换完成"
}

# 根据策略决定是否执行轮换
should_rotate() {
  LAST_ROTATION=$(kubectl get configmap key-rotation-metadata -n kube-system -o jsonpath='{.data.last-rotation}' 2>/dev/null || echo "1970-01-01")
  
  DAYS_SINCE_LAST=$(($(date +%s) - $(date -d "$LAST_ROTATION" +%s)) / 86400)
  
  if [ $DAYS_SINCE_LAST -ge 30 ]; then
    return 0  # 应该轮换
  else
    return 1  # 不需要轮换
  fi
}

# 主执行逻辑
if should_rotate; then
  rotate_encryption_keys
else
  echo "ℹ️  未到密钥轮换时间"
fi
```

---

## 合规性检查清单

```markdown
# 存储安全合规检查清单

## 🔐 加密合规
- [ ] 所有生产环境PV启用静态加密
- [ ] 使用企业级KMS服务管理密钥
- [ ] 实施密钥轮换策略（每90天）
- [ ] 加密传输通道（TLS/SSL）
- [ ] 定期验证加密有效性

## 👥 访问控制
- [ ] 配置最小权限RBAC策略
- [ ] 实施Pod安全策略(PSP)
- [ ] 网络策略限制存储访问
- [ ] 定期审查访问权限
- [ ] 启用审计日志记录

## 📦 数据保护
- [ ] 制定备份策略和SLA
- [ ] 实施多地备份
- [ ] 定期验证备份可恢复性
- [ ] 建立数据销毁流程
- [ ] 实施数据分类标记

## 🛡️ 安全防护
- [ ] 定期进行安全扫描
- [ ] 及时应用安全补丁
- [ ] 实施入侵检测系统
- [ ] 配置安全监控告警
- [ ] 建立应急响应流程

## 📋 合规要求
- [ ] 符合GDPR数据保护要求
- [ ] 满足行业特定合规标准
- [ ] 通过第三方安全审计
- [ ] 保持合规文档更新
- [ ] 定期进行合规培训

## 📊 监控审计
- [ ] 实施全面监控体系
- [ ] 配置关键指标告警
- [ ] 定期生成合规报告
- [ ] 保留审计日志至少1年
- [ ] 建立违规事件处理流程
```

---

## 应急响应预案

### 数据泄露应急流程

```bash
#!/bin/bash
# data-breach-response.sh

INCIDENT_ID="incident-$(date +%Y%m%d-%H%M%S)"
RESPONSE_LOG="/var/log/incident-response/$INCIDENT_ID.log"

# 立即响应动作
immediate_response() {
  echo "$(date): 数据泄露事件响应开始 - Incident ID: $INCIDENT_ID" | tee -a $RESPONSE_LOG
  
  # 1. 隔离受影响系统
  echo "$(date): 隔离受影响的存储系统" | tee -a $RESPONSE_LOG
  kubectl scale deployment --all -n affected-namespace --replicas=0
  
  # 2. 阻止进一步数据访问
  echo "$(date): 阻止数据访问" | tee -a $RESPONSE_LOG
  kubectl delete networkpolicy -n affected-namespace --all
  
  # 3. 创建取证快照
  echo "$(date): 创建取证快照" | tee -a $RESPONSE_LOG
  kubectl get pvc -n affected-namespace -o json | \
    jq -r '.items[].metadata.name' | while read pvc; do
      kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: forensic-snapshot-$pvc-$INCIDENT_ID
  namespace: affected-namespace
  labels:
    incident-id: $INCIDENT_ID
spec:
  volumeSnapshotClassName: forensic-snapshot-class
  source:
    persistentVolumeClaimName: $pvc
EOF
    done
}

# 调查分析
investigation_phase() {
  echo "$(date): 进入调查分析阶段" | tee -a $RESPONSE_LOG
  
  # 1. 收集相关日志
  echo "$(date): 收集审计日志" | tee -a $RESPONSE_LOG
  kubectl get events -n affected-namespace --since=24h > /tmp/incident-events-$INCIDENT_ID.log
  
  # 2. 分析访问模式
  echo "$(date): 分析异常访问模式" | tee -a $RESPONSE_LOG
  # 实现具体的日志分析逻辑
  
  # 3. 评估影响范围
  echo "$(date): 评估影响范围" | tee -a $RESPONSE_LOG
  AFFECTED_PVC=$(kubectl get pvc -n affected-namespace -o json | \
    jq -r '.items[].metadata.name' | wc -l)
  echo "受影响PVC数量: $AFFECTED_PVC" | tee -a $RESPONSE_LOG
}

# 恢复与改进
recovery_and_improvement() {
  echo "$(date): 进入恢复改进阶段" | tee -a $RESPONSE_LOG
  
  # 1. 数据恢复（如有备份）
  echo "$(date): 执行数据恢复" | tee -a $RESPONSE_LOG
  # 从安全备份恢复数据
  
  # 2. 系统加固
  echo "$(date): 实施安全加固措施" | tee -a $RESPONSE_LOG
  # 更新安全配置，加强访问控制
  
  # 3. 生成事件报告
  cat > /tmp/incident-report-$INCIDENT_ID.md <<EOF
# 数据泄露事件报告

## 事件基本信息
- 事件ID: $INCIDENT_ID
- 发现时间: $(date)
- 影响范围: $AFFECTED_PVC 个PVC

## 响应措施
1. 系统隔离完成
2. 取证快照创建完成
3. 日志收集完成

## 后续行动计划
- 完成根本原因分析
- 实施长期防护措施
- 更新安全策略
EOF
  
  echo "事件报告已生成: /tmp/incident-report-$INCIDENT_ID.md"
}

# 主响应流程
main() {
  immediate_response
  investigation_phase
  recovery_and_improvement
  
  echo "$(date): 应急响应流程完成" | tee -a $RESPONSE_LOG
  echo "📋 详细响应日志: $RESPONSE_LOG"
}

main
```

---