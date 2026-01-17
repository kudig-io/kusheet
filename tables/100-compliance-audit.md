# Kubernetes 合规与审计

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/tasks/debug/debug-cluster/audit](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)

## 合规框架对照

| 框架 | 范围 | K8s 相关要求 |
|------|------|-------------|
| CIS Kubernetes Benchmark | 容器平台 | 配置安全基线 |
| SOC 2 | 服务组织 | 安全、可用性、完整性 |
| ISO 27001 | 信息安全 | ISMS 管理体系 |
| PCI DSS | 支付卡 | 数据保护、访问控制 |
| HIPAA | 医疗健康 | PHI 数据保护 |
| GDPR | 数据隐私 | 个人数据保护 |
| 等保 2.0 | 国内等保 | 网络安全等级保护 |

## 审计日志配置

```yaml
# 审计策略
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# 记录所有认证失败
- level: Metadata
  users: ["system:anonymous"]
  verbs: ["*"]
  
# 安全敏感操作 - 完整记录
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets", "serviceaccounts/token"]
  - group: "rbac.authorization.k8s.io"
    resources: ["*"]
  - group: "certificates.k8s.io"
    resources: ["*"]
  
# 配置变更 - 请求级别
- level: Request
  verbs: ["create", "update", "patch", "delete"]
  resources:
  - group: ""
    resources: ["configmaps", "services", "persistentvolumeclaims"]
  - group: "apps"
    resources: ["deployments", "statefulsets", "daemonsets"]
  - group: "networking.k8s.io"
    resources: ["networkpolicies", "ingresses"]

# 工作负载操作 - 元数据
- level: Metadata
  verbs: ["create", "update", "patch", "delete"]
  resources:
  - group: ""
    resources: ["pods", "pods/exec", "pods/attach"]
    
# 只读操作 - 不记录
- level: None
  verbs: ["get", "list", "watch"]
  users:
  - system:kube-proxy
  - system:node
  
# 默认 - 元数据
- level: Metadata
  omitStages:
  - RequestReceived
```

## 审计日志采集

```yaml
# Fluent Bit 审计日志采集
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-audit-config
  namespace: logging
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         5
        Log_Level     info
        Daemon        off
        Parsers_File  parsers.conf

    [INPUT]
        Name              tail
        Path              /var/log/kubernetes/audit/audit.log
        Parser            json
        Tag               audit.*
        Refresh_Interval  5
        Mem_Buf_Limit     50MB

    [FILTER]
        Name          modify
        Match         audit.*
        Add           cluster ${CLUSTER_NAME}

    [OUTPUT]
        Name          es
        Match         audit.*
        Host          elasticsearch.logging
        Port          9200
        Index         k8s-audit
        Type          _doc
        
  parsers.conf: |
    [PARSER]
        Name        json
        Format      json
        Time_Key    requestReceivedTimestamp
        Time_Format %Y-%m-%dT%H:%M:%S.%LZ
```

## 合规检查工具

```yaml
# Polaris 合规检查
apiVersion: batch/v1
kind: Job
metadata:
  name: polaris-audit
spec:
  template:
    spec:
      restartPolicy: Never
      serviceAccountName: polaris
      containers:
      - name: polaris
        image: quay.io/fairwinds/polaris:8.0
        command:
        - polaris
        - audit
        - --format=json
        - --output-file=/output/report.json
        volumeMounts:
        - name: output
          mountPath: /output
      volumes:
      - name: output
        emptyDir: {}
---
# Trivy 安全扫描
apiVersion: batch/v1
kind: CronJob
metadata:
  name: trivy-scan
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: trivy
            image: aquasec/trivy:latest
            command:
            - trivy
            - k8s
            - --report=all
            - --format=json
            - --output=/output/trivy-report.json
            - cluster
```

## 等保 2.0 检查项

| 控制域 | 检查项 | K8s 实现 |
|--------|--------|----------|
| 身份鉴别 | 双因素认证 | OIDC + MFA |
| 身份鉴别 | 口令复杂度 | 证书或 Token |
| 访问控制 | 最小权限 | RBAC |
| 访问控制 | 特权账户管理 | ServiceAccount |
| 安全审计 | 操作日志 | Audit Log |
| 安全审计 | 日志保护 | 外部存储 |
| 入侵防范 | 网络隔离 | NetworkPolicy |
| 数据保密 | 传输加密 | TLS |
| 数据保密 | 存储加密 | Secret 加密 |
| 数据备份 | 备份策略 | etcd/Velero |

## 合规报告生成

```bash
#!/bin/bash
# 合规报告生成脚本

REPORT_DATE=$(date +%Y%m%d)
REPORT_DIR="/var/reports/compliance"
mkdir -p ${REPORT_DIR}

echo "=== Kubernetes 合规报告 ===" > ${REPORT_DIR}/report-${REPORT_DATE}.md
echo "生成时间: $(date)" >> ${REPORT_DIR}/report-${REPORT_DATE}.md
echo "" >> ${REPORT_DIR}/report-${REPORT_DATE}.md

# 1. CIS Benchmark 检查
echo "## 1. CIS Benchmark 检查" >> ${REPORT_DIR}/report-${REPORT_DATE}.md
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
sleep 60
kubectl logs job/kube-bench >> ${REPORT_DIR}/report-${REPORT_DATE}.md

# 2. RBAC 审计
echo "## 2. RBAC 审计" >> ${REPORT_DIR}/report-${REPORT_DATE}.md
echo "### Cluster Admin 绑定" >> ${REPORT_DIR}/report-${REPORT_DATE}.md
kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name' >> ${REPORT_DIR}/report-${REPORT_DATE}.md

# 3. Pod 安全检查
echo "## 3. Pod 安全检查" >> ${REPORT_DIR}/report-${REPORT_DATE}.md
echo "### 特权容器" >> ${REPORT_DIR}/report-${REPORT_DATE}.md
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[].securityContext.privileged==true) | .metadata.namespace + "/" + .metadata.name' >> ${REPORT_DIR}/report-${REPORT_DATE}.md

# 4. 网络策略覆盖
echo "## 4. 网络策略覆盖" >> ${REPORT_DIR}/report-${REPORT_DATE}.md
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  np_count=$(kubectl get networkpolicy -n $ns --no-headers 2>/dev/null | wc -l)
  echo "- $ns: $np_count 个策略" >> ${REPORT_DIR}/report-${REPORT_DATE}.md
done

# 5. 镜像安全
echo "## 5. 镜像安全" >> ${REPORT_DIR}/report-${REPORT_DATE}.md
echo "### 使用 latest 标签的镜像" >> ${REPORT_DIR}/report-${REPORT_DATE}.md
kubectl get pods -A -o json | jq -r '.items[].spec.containers[] | select(.image | endswith(":latest")) | .image' | sort -u >> ${REPORT_DIR}/report-${REPORT_DATE}.md

echo "报告已生成: ${REPORT_DIR}/report-${REPORT_DATE}.md"
```

## 持续合规监控

```yaml
# 合规监控 Dashboard ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: compliance-dashboard
  namespace: monitoring
data:
  dashboard.json: |
    {
      "title": "Kubernetes 合规监控",
      "panels": [
        {
          "title": "CIS 检查通过率",
          "type": "gauge",
          "targets": [
            {"expr": "kube_bench_pass_total / (kube_bench_pass_total + kube_bench_fail_total) * 100"}
          ]
        },
        {
          "title": "特权容器数量",
          "type": "stat",
          "targets": [
            {"expr": "count(kube_pod_container_info{privileged=\"true\"})"}
          ]
        },
        {
          "title": "NetworkPolicy 覆盖率",
          "type": "gauge",
          "targets": [
            {"expr": "count(kube_namespace_labels{networkpolicy=\"enabled\"}) / count(kube_namespace_labels) * 100"}
          ]
        },
        {
          "title": "审计事件趋势",
          "type": "graph",
          "targets": [
            {"expr": "sum(rate(apiserver_audit_event_total[5m])) by (verb)"}
          ]
        }
      ]
    }
```

## 告警规则

```yaml
groups:
- name: compliance
  rules:
  - alert: AuditLogMissing
    expr: |
      absent(apiserver_audit_event_total)
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "审计日志未启用或采集失败"
      
  - alert: PrivilegedPodCreated
    expr: |
      increase(apiserver_audit_event_total{verb="create",objectRef_resource="pods"}[5m]) > 0
      and on() count(kube_pod_container_info{privileged="true"}) > 0
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "创建了特权 Pod"
      
  - alert: ClusterAdminUsage
    expr: |
      sum(rate(apiserver_audit_event_total{user_username!~"system:.*",user_groups=~".*cluster-admin.*"}[5m])) > 0
    for: 1m
    labels:
      severity: info
    annotations:
      summary: "cluster-admin 权限被使用"
      
  - alert: SecretAccessWithoutAudit
    expr: |
      rate(apiserver_request_total{resource="secrets",verb="get"}[5m]) > 0
      and on() absent(apiserver_audit_event_total{objectRef_resource="secrets"})
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Secret 访问未被审计"
```

## 合规最佳实践

| 项目 | 建议 |
|------|------|
| 基线 | 定义并执行安全基线 |
| 自动化 | 自动化合规检查 |
| 持续 | 持续监控合规状态 |
| 审计 | 保留完整审计日志 |
| 报告 | 定期生成合规报告 |
| 改进 | 建立合规改进流程 |
| 培训 | 团队安全合规培训 |
