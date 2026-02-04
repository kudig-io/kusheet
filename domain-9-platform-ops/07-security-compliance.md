# 安全合规管理 (Security & Compliance Management)

## 概述

安全合规管理是平台运维的基础要求，通过实施零信任安全架构、持续安全监控和合规性检查，确保Kubernetes平台的安全稳定运行。

## 零信任安全架构

### 核心原则
```
永不信任，始终验证 (Never Trust, Always Verify)
```

### 安全层级模型
```
身份认证 → 访问授权 → 网络隔离 → 数据保护 → 持续监控
```

## 身份认证与授权

### OIDC集成配置
```yaml
# Dex OAuth2配置
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dex
  namespace: auth
spec:
  replicas: 2
  selector:
    matchLabels:
      app: dex
  template:
    metadata:
      labels:
        app: dex
    spec:
      containers:
      - name: dex
        image: dexidp/dex:v2.37.0
        ports:
        - containerPort: 5556
        args:
        - dex
        - serve
        - /etc/dex/config.yaml
        volumeMounts:
        - name: config
          mountPath: /etc/dex
      volumes:
      - name: config
        configMap:
          name: dex-config

---
# Dex配置文件
issuer: https://dex.example.com
storage:
  type: kubernetes
  config:
    inCluster: true
web:
  http: 0.0.0.0:5556
connectors:
- type: ldap
  name: LDAP
  id: ldap
  config:
    host: ldap.example.com:636
    insecureNoSSL: false
    bindDN: cn=admin,dc=example,dc=com
    bindPW: password
    usernamePrompt: Username
    userSearch:
      baseDN: ou=People,dc=example,dc=com
      filter: "(objectClass=person)"
      username: uid
      idAttr: uid
      emailAttr: mail
      nameAttr: cn
```

### RBAC精细化权限
```yaml
# 命名空间管理员角色
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-admin
  namespace: production
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets", "daemonsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies", "ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

---
# 角色绑定
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-a-admin
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-admin
subjects:
- kind: Group
  name: team-a-admins
  apiGroup: rbac.authorization.k8s.io
```

### 服务账户管理
```yaml
# 限制性服务账户
apiVersion: v1
kind: ServiceAccount
metadata:
  name: restricted-sa
  namespace: production
automountServiceAccountToken: false

---
# Pod安全上下文
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  serviceAccountName: restricted-sa
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
  containers:
  - name: app
    image: myapp:latest
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

## 网络安全策略

### NetworkPolicy配置
```yaml
# 默认拒绝策略
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
# 允许特定流量
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 5432

---
# 外部访问控制
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-controller
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
```

### Istio服务网格安全
```yaml
# PeerAuthentication双向TLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT

---
# AuthorizationPolicy访问控制
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: frontend-policy
  namespace: production
spec:
  selector:
    matchLabels:
      app: frontend
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/production/sa/backend-sa"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]
  - when:
    - key: request.auth.claims[groups]
      values: ["admin"]
```

## 镜像安全管理

### Harbor私有镜像仓库
```yaml
# Harbor部署配置
apiVersion: apps/v1
kind: Deployment
metadata:
  name: harbor-core
  namespace: harbor
spec:
  replicas: 2
  selector:
    matchLabels:
      app: harbor
      component: core
  template:
    metadata:
      labels:
        app: harbor
        component: core
    spec:
      containers:
      - name: core
        image: goharbor/harbor-core:v2.8.0
        env:
        - name: CORE_SECRET
          valueFrom:
            secretKeyRef:
              name: harbor-core-secret
              key: secret
        - name: JOBSERVICE_SECRET
          valueFrom:
            secretKeyRef:
              name: harbor-jobservice-secret
              key: secret
        ports:
        - containerPort: 8080
        livenessProbe:
          httpGet:
            path: /api/v2.0/ping
            port: 8080
          initialDelaySeconds: 300
          periodSeconds: 10
```

### 镜像扫描策略
```yaml
# Trivy扫描配置
apiVersion: batch/v1
kind: CronJob
metadata:
  name: image-scanner
  namespace: security
spec:
  schedule: "0 2 * * *"  # 每天凌晨2点执行
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: trivy
            image: aquasec/trivy:0.40.0
            command:
            - /bin/sh
            - -c
            - |
              trivy image --exit-code 1 --severity HIGH,CRITICAL \
                --ignore-unfixed $IMAGE_NAME
            env:
            - name: IMAGE_NAME
              valueFrom:
                configMapKeyRef:
                  name: scan-targets
                  key: image-list
          restartPolicy: OnFailure
```

### 镜像签名验证
```yaml
# Cosign签名策略
apiVersion: policy.sigstore.dev/v1alpha1
kind: ClusterImagePolicy
metadata:
  name: image-policy
spec:
  images:
  - glob: "registry.example.com/**"
  authorities:
  - key:
      kms: gcpkms://projects/my-project/locations/global/keyRings/my-ring/cryptoKeys/my-key
    attestations:
    - name: custom
      predicateType: custom
      policy:
        type: cue
        data: |
          predicateType: "cosign.sigstore.dev/attestation/v1"
          subject:
            name: string
```

## 密钥管理

### HashiCorp Vault集成
```yaml
# Vault Agent Injector配置
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault-agent-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: vault-agent-demo
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "app-role"
        vault.hashicorp.com/agent-inject-secret-database-config.txt: "secret/database/config"
        vault.hashicorp.com/agent-inject-template-database-config.txt: |
          {{- with secret "secret/database/config" -}}
          username: {{ .Data.username }}
          password: {{ .Data.password }}
          {{- end }}
      labels:
        app: vault-agent-demo
    spec:
      serviceAccountName: vault-agent
      containers:
      - name: app
        image: myapp:latest
        volumeMounts:
        - name: vault-secrets
          mountPath: /vault/secrets
          readOnly: true
```

### SealedSecrets加密
```yaml
# SealedSecret创建
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: database-credentials
  namespace: production
spec:
  encryptedData:
    username: AgCQX1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+/=
    password: AgCQX1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+/=
  template:
    metadata:
      name: database-credentials
      namespace: production
    data:
      username: ""
      password: ""
```

## 合规性检查

### CIS基准扫描
```yaml
# kube-bench配置
apiVersion: batch/v1
kind: Job
metadata:
  name: cis-benchmark
  namespace: security
spec:
  template:
    spec:
      hostPID: true
      containers:
      - name: kube-bench
        image: aquasec/kube-bench:0.6.12
        command: ["kube-bench", "run", "--targets", "node,master,etcd,policies"]
        volumeMounts:
        - name: var-lib-etcd
          mountPath: /var/lib/etcd
          readOnly: true
        - name: var-lib-kubelet
          mountPath: /var/lib/kubelet
          readOnly: true
        - name: etc-systemd
          mountPath: /etc/systemd
          readOnly: true
        - name: etc-kubernetes
          mountPath: /etc/kubernetes
          readOnly: true
      volumes:
      - name: var-lib-etcd
        hostPath:
          path: "/var/lib/etcd"
      - name: var-lib-kubelet
        hostPath:
          path: "/var/lib/kubelet"
      - name: etc-systemd
        hostPath:
          path: "/etc/systemd"
      - name: etc-kubernetes
        hostPath:
          path: "/etc/kubernetes"
      restartPolicy: Never
```

### 安全基线检查
```bash
# 安全配置检查脚本
#!/bin/bash

echo "=== Kubernetes Security Baseline Check ==="

# 检查匿名访问
echo "1. Checking anonymous access..."
if kubectl get --raw='/healthz?verbose' | grep -q "anon"; then
    echo "❌ Anonymous access enabled"
else
    echo "✅ Anonymous access disabled"
fi

# 检查RBAC启用
echo "2. Checking RBAC status..."
if kubectl api-versions | grep -q "rbac.authorization.k8s.io"; then
    echo "✅ RBAC enabled"
else
    echo "❌ RBAC not enabled"
fi

# 检查网络策略
echo "3. Checking network policies..."
np_count=$(kubectl get networkpolicies --all-namespaces --no-headers | wc -l)
if [[ $np_count -gt 0 ]]; then
    echo "✅ Network policies configured ($np_count policies)"
else
    echo "❌ No network policies found"
fi

# 检查Pod安全策略
echo "4. Checking Pod security..."
kubectl get pods --all-namespaces -o json | jq -r '
  .items[] | 
  select(.spec.containers[].securityContext.privileged == true) |
  "\(.metadata.namespace)/\(.metadata.name) - privileged container"
'
```

## 安全监控告警

### Falco入侵检测
```yaml
# Falco配置
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: falco
  namespace: security
spec:
  selector:
    matchLabels:
      app: falco
  template:
    metadata:
      labels:
        app: falco
    spec:
      containers:
      - name: falco
        image: falcosecurity/falco:0.35.0
        securityContext:
          privileged: true
        volumeMounts:
        - name: dev-fs
          mountPath: /dev
        - name: proc-fs
          mountPath: /proc
        - name: boot-fs
          mountPath: /boot
        - name: lib-modules
          mountPath: /lib/modules
        - name: usr-fs
          mountPath: /usr
        - name: etc-fs
          mountPath: /etc
        env:
        - name: SYSDIG_BPF_PROBE
          value: ""
        - name: FALCO_FRONTEND
          value: "noninteractive"
      volumes:
      - name: dev-fs
        hostPath:
          path: /dev
      - name: proc-fs
        hostPath:
          path: /proc
      - name: boot-fs
        hostPath:
          path: /boot
      - name: lib-modules
        hostPath:
          path: /lib/modules
      - name: usr-fs
        hostPath:
          path: /usr
      - name: etc-fs
        hostPath:
          path: /etc
```

### 安全事件告警
```yaml
# 安全告警规则
groups:
- name: security.rules
  rules:
  - alert: HighPrivilegeContainer
    expr: kube_pod_container_info{container_security_context_privileged="true"} == 1
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "检测到特权容器"
      description: "命名空间 {{ $labels.namespace }} 中的Pod {{ $labels.pod }} 包含特权容器"

  - alert: UnauthorizedAccess
    expr: rate(apiserver_request_total{code=~"4.."}[5m]) > 10
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "API Server未授权访问"
      description: "检测到大量4xx错误请求"

  - alert: FailedLoginAttempts
    expr: rate(authentication_attempts{result="failure"}[5m]) > 5
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "认证失败尝试过多"
      description: "检测到频繁的认证失败尝试"
```

## 审计日志管理

### Audit Policy配置
```yaml
# 审计策略
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
  - group: authentication.k8s.io
    resources: ["tokenreviews"]
  verbs: ["create", "update", "delete"]

- level: RequestResponse
  resources:
  - group: ""
    resources: ["pods", "services", "deployments"]
  verbs: ["create", "update", "delete"]

- level: None
  users: ["system:kube-proxy"]
  verbs: ["watch"]

- level: None
  userGroups: ["system:authenticated"]
  nonResourceURLs:
  - "/api*"
  - "/version"
```

### 审计日志分析
```python
# 审计日志分析脚本
import json
from datetime import datetime, timedelta

class AuditAnalyzer:
    def __init__(self, log_file):
        self.log_file = log_file
        self.suspicious_patterns = [
            self.detect_privilege_escalation,
            self.detect_unauthorized_access,
            self.detect_anomalous_behavior
        ]
    
    def analyze_logs(self):
        alerts = []
        with open(self.log_file, 'r') as f:
            for line in f:
                event = json.loads(line)
                for pattern in self.suspicious_patterns:
                    alert = pattern(event)
                    if alert:
                        alerts.append(alert)
        return alerts
    
    def detect_privilege_escalation(self, event):
        if (event.get('verb') == 'create' and 
            'rolebinding' in event.get('objectRef', {}).get('resource', '')):
            return {
                'type': 'privilege_escalation',
                'timestamp': event['requestReceivedTimestamp'],
                'user': event['user']['username'],
                'resource': event['objectRef']
            }
        return None
```

## 最佳实践

### 1. 安全设计原则
- 最小权限原则
- 深度防御策略
- 安全左移实践
- 零信任架构

### 2. 持续安全监控
- 实时威胁检测
- 异常行为分析
- 安全事件响应
- 漏洞管理流程

### 3. 合规性保障
- 定期安全审计
- 合规性检查自动化
- 安全培训常态化
- 第三方安全评估

### 4. 应急响应
- 安全事件预案
- 快速响应机制
- 损失控制措施
- 事后复盘改进

通过建立完善的安全合规管理体系，可以有效防范安全威胁，满足监管要求，为业务发展提供安全可靠的平台基础。