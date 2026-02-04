# 90 - 密钥与敏感信息管理工具

> **适用版本**: Kubernetes v1.25 - v1.32 | **难度**: 高级 | **参考**: [External Secrets](https://external-secrets.io/) | [HashiCorp Vault](https://developer.hashicorp.com/vault) | [Sealed Secrets](https://sealed-secrets.netlify.app/)

## 一、密钥管理架构全景

### 1.1 企业级密钥管理架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                      Enterprise Secret Management Architecture                       │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌────────────────────────────────────────────────────────────────────────────────┐ │
│  │                           External Secret Stores                                │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │ │
│  │  │  HashiCorp   │  │   AWS        │  │   Azure      │  │   GCP        │       │ │
│  │  │    Vault     │  │   Secrets    │  │   Key Vault  │  │   Secret     │       │ │
│  │  │              │  │   Manager    │  │              │  │   Manager    │       │ │
│  │  │  ┌────────┐  │  │  ┌────────┐  │  │  ┌────────┐  │  │  ┌────────┐  │       │ │
│  │  │  │ KV V2  │  │  │  │Secrets │  │  │  │ Keys   │  │  │  │Versions│  │       │ │
│  │  │  │ PKI    │  │  │  │Rotation│  │  │  │Secrets │  │  │  │ IAM    │  │       │ │
│  │  │  │ Transit│  │  │  │  IAM   │  │  │  │Certs   │  │  │  │Rotation│  │       │ │
│  │  │  │ SSH    │  │  │  │  KMS   │  │  │  │  RBAC  │  │  │  │ Labels │  │       │ │
│  │  │  └────────┘  │  │  └────────┘  │  │  └────────┘  │  │  └────────┘  │       │ │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │ │
│  └─────────┼─────────────────┼─────────────────┼─────────────────┼────────────────┘ │
│            │                 │                 │                 │                  │
│            └─────────────────┴─────────────────┴─────────────────┘                  │
│                                       │                                             │
│  ┌────────────────────────────────────▼───────────────────────────────────────────┐ │
│  │                        Secret Sync Controllers                                  │ │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐              │ │
│  │  │ External Secrets │  │  Sealed Secrets  │  │   Vault Agent    │              │ │
│  │  │    Operator      │  │   Controller     │  │    Injector      │              │ │
│  │  │                  │  │                  │  │                  │              │ │
│  │  │ - Multi-provider │  │ - GitOps native  │  │ - Sidecar mode   │              │ │
│  │  │ - Auto-refresh   │  │ - Asymmetric enc │  │ - Template       │              │ │
│  │  │ - Templating     │  │ - Cluster-wide   │  │ - Dynamic creds  │              │ │
│  │  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘              │ │
│  └───────────┼─────────────────────┼─────────────────────┼────────────────────────┘ │
│              │                     │                     │                          │
│              └─────────────────────┴─────────────────────┘                          │
│                                    │                                                │
│  ┌─────────────────────────────────▼──────────────────────────────────────────────┐ │
│  │                          Kubernetes Secrets                                     │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐   │ │
│  │  │                    Native K8s Secret (etcd encrypted)                   │   │ │
│  │  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐            │   │ │
│  │  │  │  Opaque   │  │   TLS     │  │ dockercfg │  │  SA Token │            │   │ │
│  │  │  │  Secrets  │  │  Secrets  │  │  Secrets  │  │  Secrets  │            │   │ │
│  │  │  └───────────┘  └───────────┘  └───────────┘  └───────────┘            │   │ │
│  │  └─────────────────────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                                │
│  ┌─────────────────────────────────▼──────────────────────────────────────────────┐ │
│  │                         Application Consumption                                 │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │ │
│  │  │   Volume     │  │    Env       │  │   CSI        │  │   Sidecar    │       │ │
│  │  │   Mount      │  │   Variable   │  │   Driver     │  │   Injection  │       │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘       │ │
│  └────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 密钥管理方案全面对比

| 方案 | 架构模式 | 多云支持 | 动态密钥 | GitOps | 审计 | 复杂度 | 适用场景 |
|-----|---------|---------|---------|-------|------|-------|---------|
| **External Secrets Operator** | 同步控制器 | ★★★★★ | ✓ | ★★★★☆ | ★★★☆☆ | 中 | 多云/混合云 |
| **HashiCorp Vault** | 外部密钥库 | ★★★★☆ | ★★★★★ | ★★★☆☆ | ★★★★★ | 高 | 企业安全 |
| **Sealed Secrets** | 加密控制器 | ★☆☆☆☆ | ✗ | ★★★★★ | ★★☆☆☆ | 低 | GitOps工作流 |
| **SOPS** | 文件加密 | ★★★★☆ | ✗ | ★★★★★ | ★★☆☆☆ | 低 | 小团队 |
| **AWS Secrets Manager** | 托管服务 | AWS only | ★★★★★ | ★★★☆☆ | ★★★★★ | 低 | AWS原生 |
| **Azure Key Vault** | 托管服务 | Azure only | ★★★★☆ | ★★★☆☆ | ★★★★★ | 低 | Azure原生 |
| **GCP Secret Manager** | 托管服务 | GCP only | ★★★★☆ | ★★★☆☆ | ★★★★★ | 低 | GCP原生 |
| **CyberArk Conjur** | 企业方案 | ★★★★★ | ★★★★★ | ★★★☆☆ | ★★★★★ | 高 | 大型企业 |

### 1.3 密钥类型与安全等级

| 密钥类型 | 安全等级 | 轮换周期 | 存储建议 | 访问控制 |
|---------|---------|---------|---------|---------|
| **数据库凭证** | 高 | 30天 | Vault/云KMS | 应用专用 |
| **API密钥** | 高 | 90天 | ESO同步 | 服务账户 |
| **TLS证书** | 高 | 365天 | cert-manager | 命名空间隔离 |
| **SSH密钥** | 高 | 签发制 | Vault SSH | 动态签发 |
| **配置密钥** | 中 | 按需 | Sealed Secrets | RBAC控制 |
| **加密密钥** | 极高 | 按需 | HSM/CloudHSM | 最小权限 |

---

## 二、External Secrets Operator

### 2.1 ESO架构与部署

```yaml
# External Secrets Operator 安装
apiVersion: v1
kind: Namespace
metadata:
  name: external-secrets
---
# 使用Helm安装
# helm repo add external-secrets https://charts.external-secrets.io
# helm install external-secrets external-secrets/external-secrets -n external-secrets
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-secrets
  namespace: external-secrets
spec:
  replicas: 2
  selector:
    matchLabels:
      app: external-secrets
  template:
    metadata:
      labels:
        app: external-secrets
    spec:
      serviceAccountName: external-secrets
      containers:
      - name: external-secrets
        image: ghcr.io/external-secrets/external-secrets:v0.9.11
        args:
        - --concurrent=5
        - --metrics-addr=:8080
        - --health-probe-bind-address=:8081
        - --enable-leader-election
        - --loglevel=info
        
        ports:
        - containerPort: 8080
          name: metrics
        - containerPort: 8081
          name: health
        
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8081
          initialDelaySeconds: 15
          periodSeconds: 20
        
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8081
          initialDelaySeconds: 5
          periodSeconds: 10
        
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop: ["ALL"]
      
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: external-secrets
              topologyKey: kubernetes.io/hostname
```

### 2.2 多云SecretStore配置

```yaml
# ========================
# AWS Secrets Manager
# ========================
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets
---
# ========================
# Azure Key Vault
# ========================
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: azure-keyvault
spec:
  provider:
    azurekv:
      tenantId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      vaultUrl: "https://my-vault.vault.azure.net"
      authType: ManagedIdentity
      identityId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
---
# ========================
# GCP Secret Manager
# ========================
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: gcp-secret-manager
spec:
  provider:
    gcpsm:
      projectID: my-gcp-project
      auth:
        workloadIdentity:
          clusterLocation: us-central1
          clusterName: my-cluster
          clusterProjectID: my-gcp-project
          serviceAccountRef:
            name: external-secrets-gcp-sa
            namespace: external-secrets
---
# ========================
# HashiCorp Vault
# ========================
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com:8200"
      path: "secret"
      version: "v2"
      namespace: "admin"
      caProvider:
        type: ConfigMap
        name: vault-ca
        namespace: external-secrets
        key: ca.crt
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
          serviceAccountRef:
            name: external-secrets-vault-sa
            namespace: external-secrets
---
# ========================
# 阿里云 KMS
# ========================
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: alicloud-kms
  namespace: production
spec:
  provider:
    alibaba:
      regionID: cn-hangzhou
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: alicloud-credentials
            key: access-key-id
          accessKeySecretSecretRef:
            name: alicloud-credentials
            key: access-key-secret
```

### 2.3 ExternalSecret高级配置

```yaml
# 基础ExternalSecret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  
  target:
    name: db-secret
    creationPolicy: Owner
    deletionPolicy: Retain
    template:
      type: Opaque
      metadata:
        labels:
          app: myapp
          managed-by: external-secrets
      data:
        # 使用模板语法
        connection-string: |
          postgresql://{{ .username }}:{{ .password }}@{{ .host }}:5432/{{ .database }}?sslmode=require
  
  data:
  - secretKey: username
    remoteRef:
      key: prod/database
      property: username
  - secretKey: password
    remoteRef:
      key: prod/database
      property: password
  - secretKey: host
    remoteRef:
      key: prod/database
      property: host
  - secretKey: database
    remoteRef:
      key: prod/database
      property: database
---
# 使用dataFrom获取所有键值
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-config
  namespace: production
spec:
  refreshInterval: 30m
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  
  target:
    name: app-config-secret
    creationPolicy: Owner
  
  dataFrom:
  - extract:
      key: prod/app-config
  - find:
      name:
        regexp: "^prod/features/.*"
      tags:
        environment: production
---
# 多来源聚合
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: multi-source-secret
  namespace: production
spec:
  refreshInterval: 1h
  
  target:
    name: aggregated-secrets
    creationPolicy: Owner
  
  data:
  # 从AWS获取
  - secretKey: aws-api-key
    sourceRef:
      storeRef:
        name: aws-secrets-manager
        kind: ClusterSecretStore
    remoteRef:
      key: prod/api-keys
      property: aws
  
  # 从Vault获取
  - secretKey: db-password
    sourceRef:
      storeRef:
        name: vault-backend
        kind: ClusterSecretStore
    remoteRef:
      key: database/creds/myapp
      property: password
  
  # 从GCP获取
  - secretKey: gcp-service-account
    sourceRef:
      storeRef:
        name: gcp-secret-manager
        kind: ClusterSecretStore
    remoteRef:
      key: service-account-key
---
# PushSecret - 反向同步到外部存储
apiVersion: external-secrets.io/v1alpha1
kind: PushSecret
metadata:
  name: push-to-vault
  namespace: production
spec:
  refreshInterval: 10m
  secretStoreRefs:
  - name: vault-backend
    kind: ClusterSecretStore
  
  selector:
    secret:
      name: local-generated-secret
  
  data:
  - match:
      secretKey: api-key
      remoteRef:
        remoteKey: prod/generated/api-key
```

### 2.4 ESO监控与告警

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: external-secrets-alerts
  namespace: external-secrets
spec:
  groups:
  - name: external-secrets
    rules:
    # Secret同步失败
    - alert: ExternalSecretSyncFailed
      expr: |
        externalsecret_status_condition{condition="Ready", status="False"} == 1
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "ExternalSecret同步失败"
        description: "Secret {{ $labels.namespace }}/{{ $labels.name }} 同步失败"
    
    # SecretStore不可用
    - alert: SecretStoreUnhealthy
      expr: |
        secretstore_status_condition{condition="Ready", status="False"} == 1
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "SecretStore不健康"
        description: "SecretStore {{ $labels.namespace }}/{{ $labels.name }} 状态异常"
    
    # 同步延迟
    - alert: ExternalSecretSyncDelay
      expr: |
        time() - externalsecret_status_sync_time > 7200
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "ExternalSecret同步延迟"
        description: "Secret {{ $labels.namespace }}/{{ $labels.name }} 超过2小时未同步"
    
    # 控制器重启
    - alert: ExternalSecretsControllerRestart
      expr: |
        increase(kube_pod_container_status_restarts_total{
          namespace="external-secrets",
          container="external-secrets"
        }[1h]) > 3
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "ESO控制器频繁重启"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: eso-grafana-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  external-secrets.json: |
    {
      "dashboard": {
        "title": "External Secrets Operator",
        "panels": [
          {
            "title": "Secret Sync Status",
            "type": "stat",
            "targets": [{
              "expr": "count(externalsecret_status_condition{condition=\"Ready\", status=\"True\"})"
            }]
          },
          {
            "title": "Failed Syncs",
            "type": "graph",
            "targets": [{
              "expr": "count(externalsecret_status_condition{condition=\"Ready\", status=\"False\"})"
            }]
          },
          {
            "title": "Sync Duration",
            "type": "graph",
            "targets": [{
              "expr": "histogram_quantile(0.99, rate(externalsecret_sync_duration_seconds_bucket[5m]))"
            }]
          }
        ]
      }
    }
```

---

## 三、HashiCorp Vault

### 3.1 Vault高可用部署

```yaml
# Vault HA部署配置
apiVersion: v1
kind: Namespace
metadata:
  name: vault
---
# 使用Helm安装
# helm repo add hashicorp https://helm.releases.hashicorp.com
# helm install vault hashicorp/vault -n vault -f vault-values.yaml
---
# vault-values.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-helm-values
  namespace: vault
data:
  values.yaml: |
    global:
      enabled: true
      tlsDisable: false
    
    injector:
      enabled: true
      replicas: 2
      resources:
        requests:
          memory: 256Mi
          cpu: 250m
        limits:
          memory: 512Mi
          cpu: 500m
      
      # Webhook配置
      webhook:
        failurePolicy: Ignore
        matchPolicy: Exact
        timeoutSeconds: 30
      
      # 注入配置
      agentDefaults:
        cpuLimit: "500m"
        cpuRequest: "250m"
        memLimit: "128Mi"
        memRequest: "64Mi"
    
    server:
      enabled: true
      image:
        repository: hashicorp/vault
        tag: "1.15.4"
      
      # HA配置
      ha:
        enabled: true
        replicas: 3
        raft:
          enabled: true
          setNodeId: true
          config: |
            ui = true
            
            listener "tcp" {
              address = "[::]:8200"
              cluster_address = "[::]:8201"
              tls_cert_file = "/vault/userconfig/vault-tls/tls.crt"
              tls_key_file = "/vault/userconfig/vault-tls/tls.key"
              tls_client_ca_file = "/vault/userconfig/vault-tls/ca.crt"
            }
            
            storage "raft" {
              path = "/vault/data"
              retry_join {
                leader_api_addr = "https://vault-0.vault-internal:8200"
                leader_ca_cert_file = "/vault/userconfig/vault-tls/ca.crt"
              }
              retry_join {
                leader_api_addr = "https://vault-1.vault-internal:8200"
                leader_ca_cert_file = "/vault/userconfig/vault-tls/ca.crt"
              }
              retry_join {
                leader_api_addr = "https://vault-2.vault-internal:8200"
                leader_ca_cert_file = "/vault/userconfig/vault-tls/ca.crt"
              }
            }
            
            seal "awskms" {
              region     = "us-west-2"
              kms_key_id = "alias/vault-unseal-key"
            }
            
            service_registration "kubernetes" {}
            
            telemetry {
              prometheus_retention_time = "30s"
              disable_hostname = true
            }
      
      # 资源配置
      resources:
        requests:
          memory: 1Gi
          cpu: 500m
        limits:
          memory: 2Gi
          cpu: 1000m
      
      # 数据持久化
      dataStorage:
        enabled: true
        size: 50Gi
        storageClass: fast-ssd
      
      # 审计日志
      auditStorage:
        enabled: true
        size: 50Gi
        storageClass: standard
      
      # 服务账户
      serviceAccount:
        create: true
        annotations:
          eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/vault-kms-unseal
      
      # 亲和性
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app.kubernetes.io/name: vault
            topologyKey: kubernetes.io/hostname
    
    ui:
      enabled: true
      serviceType: LoadBalancer
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-internal: "true"
        service.beta.kubernetes.io/aws-load-balancer-type: nlb
```

### 3.2 Vault策略与认证配置

```hcl
# vault-policies.hcl - Vault策略配置

# 管理员策略
path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# 应用读取策略
path "secret/data/{{identity.entity.aliases.auth_kubernetes_xxx.metadata.service_account_namespace}}/*" {
  capabilities = ["read", "list"]
}

# 数据库动态凭证策略
path "database/creds/{{identity.entity.aliases.auth_kubernetes_xxx.metadata.service_account_namespace}}-*" {
  capabilities = ["read"]
}

# PKI证书签发策略
path "pki/issue/{{identity.entity.aliases.auth_kubernetes_xxx.metadata.service_account_namespace}}" {
  capabilities = ["create", "update"]
}

# Transit加密策略
path "transit/encrypt/{{identity.entity.aliases.auth_kubernetes_xxx.metadata.service_account_namespace}}-*" {
  capabilities = ["update"]
}

path "transit/decrypt/{{identity.entity.aliases.auth_kubernetes_xxx.metadata.service_account_namespace}}-*" {
  capabilities = ["update"]
}
```

```bash
#!/bin/bash
# vault-setup.sh - Vault初始化脚本

# 启用Kubernetes认证
vault auth enable kubernetes

vault write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    issuer="https://kubernetes.default.svc.cluster.local"

# 创建角色
vault write auth/kubernetes/role/myapp \
    bound_service_account_names=myapp-sa \
    bound_service_account_namespaces=production \
    policies=myapp-policy \
    ttl=1h

# 启用KV secrets引擎
vault secrets enable -path=secret kv-v2

# 启用数据库secrets引擎
vault secrets enable database

vault write database/config/postgres \
    plugin_name=postgresql-database-plugin \
    allowed_roles="production-*" \
    connection_url="postgresql://{{username}}:{{password}}@postgres.database:5432/mydb?sslmode=require" \
    username="vault" \
    password="vault-password"

vault write database/roles/production-readonly \
    db_name=postgres \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

# 启用PKI引擎
vault secrets enable pki
vault secrets tune -max-lease-ttl=87600h pki

vault write pki/root/generate/internal \
    common_name="example.com" \
    ttl=87600h

vault write pki/roles/example-dot-com \
    allowed_domains="example.com" \
    allow_subdomains=true \
    max_ttl=72h

# 启用Transit引擎
vault secrets enable transit

vault write -f transit/keys/myapp-encryption \
    type=aes256-gcm96

# 启用审计日志
vault audit enable file file_path=/vault/audit/audit.log
```

### 3.3 Vault Agent Sidecar注入

```yaml
# 应用Pod带Vault Agent注入
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
      annotations:
        # Vault Agent Injector注解
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "myapp"
        vault.hashicorp.com/agent-pre-populate-only: "false"
        vault.hashicorp.com/agent-revoke-on-shutdown: "true"
        vault.hashicorp.com/agent-revoke-grace: "180"
        
        # 注入数据库凭证
        vault.hashicorp.com/agent-inject-secret-db-creds: "database/creds/production-readonly"
        vault.hashicorp.com/agent-inject-template-db-creds: |
          {{- with secret "database/creds/production-readonly" -}}
          export DB_USER="{{ .Data.username }}"
          export DB_PASS="{{ .Data.password }}"
          {{- end }}
        
        # 注入应用配置
        vault.hashicorp.com/agent-inject-secret-app-config: "secret/data/production/myapp"
        vault.hashicorp.com/agent-inject-template-app-config: |
          {{- with secret "secret/data/production/myapp" -}}
          {
            "api_key": "{{ .Data.data.api_key }}",
            "encryption_key": "{{ .Data.data.encryption_key }}",
            "webhook_secret": "{{ .Data.data.webhook_secret }}"
          }
          {{- end }}
        
        # 注入TLS证书
        vault.hashicorp.com/agent-inject-secret-tls-cert: "pki/issue/example-dot-com"
        vault.hashicorp.com/agent-inject-template-tls-cert: |
          {{- with secret "pki/issue/example-dot-com" "common_name=myapp.example.com" -}}
          {{ .Data.certificate }}
          {{ .Data.ca_chain }}
          {{- end }}
        
        vault.hashicorp.com/agent-inject-secret-tls-key: "pki/issue/example-dot-com"
        vault.hashicorp.com/agent-inject-template-tls-key: |
          {{- with secret "pki/issue/example-dot-com" "common_name=myapp.example.com" -}}
          {{ .Data.private_key }}
          {{- end }}
    
    spec:
      serviceAccountName: myapp-sa
      containers:
      - name: myapp
        image: myapp:latest
        command:
        - /bin/sh
        - -c
        - |
          source /vault/secrets/db-creds
          ./myapp --config /vault/secrets/app-config
        
        ports:
        - containerPort: 8080
        
        volumeMounts:
        - name: vault-secrets
          mountPath: /vault/secrets
          readOnly: true
        
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
      
      volumes:
      - name: vault-secrets
        emptyDir:
          medium: Memory
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp-sa
  namespace: production
```

### 3.4 Vault CSI Provider

```yaml
# Vault CSI Provider配置
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: vault-db-creds
  namespace: production
spec:
  provider: vault
  parameters:
    vaultAddress: "https://vault.vault:8200"
    roleName: "myapp"
    
    objects: |
      - objectName: "db-username"
        secretPath: "database/creds/production-readonly"
        secretKey: "username"
      - objectName: "db-password"
        secretPath: "database/creds/production-readonly"
        secretKey: "password"
      - objectName: "api-key"
        secretPath: "secret/data/production/myapp"
        secretKey: "api_key"
  
  # 同步为Kubernetes Secret
  secretObjects:
  - secretName: myapp-db-creds
    type: Opaque
    data:
    - objectName: db-username
      key: username
    - objectName: db-password
      key: password
---
# 使用CSI挂载的Pod
apiVersion: v1
kind: Pod
metadata:
  name: myapp-csi
  namespace: production
spec:
  serviceAccountName: myapp-sa
  containers:
  - name: myapp
    image: myapp:latest
    volumeMounts:
    - name: secrets-store
      mountPath: "/mnt/secrets"
      readOnly: true
    
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: myapp-db-creds
          key: username
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: myapp-db-creds
          key: password
  
  volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "vault-db-creds"
```

---

## 四、Sealed Secrets

### 4.1 Sealed Secrets部署与使用

```yaml
# Sealed Secrets Controller部署
apiVersion: v1
kind: Namespace
metadata:
  name: sealed-secrets
---
# 使用Helm安装
# helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
# helm install sealed-secrets sealed-secrets/sealed-secrets -n sealed-secrets
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sealed-secrets-controller
  namespace: sealed-secrets
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sealed-secrets-controller
  template:
    metadata:
      labels:
        app: sealed-secrets-controller
    spec:
      serviceAccountName: sealed-secrets-controller
      containers:
      - name: controller
        image: bitnami/sealed-secrets-controller:v0.25.0
        args:
        - --update-status
        - --key-renew-period=720h
        - --key-prefix=sealed-secrets-key
        - --rate-limit=10
        - --rate-limit-burst=50
        
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 8081
          name: metrics
        
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi
        
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
        
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
        
        volumeMounts:
        - name: sealed-secrets-keys
          mountPath: /var/run/secrets/sealed-secrets
          readOnly: true
      
      volumes:
      - name: sealed-secrets-keys
        secret:
          secretName: sealed-secrets-key
```

### 4.2 Sealed Secrets工作流

```bash
#!/bin/bash
# sealed-secrets-workflow.sh - Sealed Secrets工作流

# 1. 安装kubeseal CLI
# brew install kubeseal  # macOS
# wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.25.0/kubeseal-0.25.0-linux-amd64.tar.gz

# 2. 获取集群公钥
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  > pub-sealed-secrets.pem

# 3. 创建并加密Secret
# 方式A: 从字面值创建
kubectl create secret generic my-secret \
  --namespace=production \
  --dry-run=client \
  --from-literal=username=admin \
  --from-literal=password=secretpassword \
  -o yaml | \
kubeseal \
  --cert pub-sealed-secrets.pem \
  --format yaml > sealed-my-secret.yaml

# 方式B: 从文件创建
kubectl create secret generic tls-secret \
  --namespace=production \
  --dry-run=client \
  --from-file=tls.crt=./server.crt \
  --from-file=tls.key=./server.key \
  -o yaml | \
kubeseal \
  --cert pub-sealed-secrets.pem \
  --format yaml > sealed-tls-secret.yaml

# 方式C: 只加密特定值 (原始模式)
echo -n "mysupersecretpassword" | \
kubeseal --raw \
  --cert pub-sealed-secrets.pem \
  --namespace production \
  --name my-secret \
  --from-file=/dev/stdin

# 4. 提交到Git
git add sealed-*.yaml
git commit -m "Add sealed secrets"
git push

# 5. 应用SealedSecret
kubectl apply -f sealed-my-secret.yaml

# 6. 验证Secret已创建
kubectl get secret my-secret -n production -o yaml
```

### 4.3 SealedSecret配置选项

```yaml
# 集群范围的SealedSecret
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: cluster-wide-secret
  namespace: production
  annotations:
    sealedsecrets.bitnami.com/cluster-wide: "true"
spec:
  encryptedData:
    password: AgBy8hCi...encrypted...
  template:
    metadata:
      labels:
        app: myapp
      annotations:
        description: "Cluster-wide secret"
    type: Opaque
---
# 命名空间范围的SealedSecret
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: namespace-scoped-secret
  namespace: production
  annotations:
    sealedsecrets.bitnami.com/namespace-wide: "true"
spec:
  encryptedData:
    api-key: AgBy8hCi...encrypted...
  template:
    type: Opaque
---
# 严格范围 (默认,绑定到名称和命名空间)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: strict-secret
  namespace: production
spec:
  encryptedData:
    username: AgBy8hCi...encrypted...
    password: AgCQx7ki...encrypted...
  template:
    metadata:
      labels:
        managed-by: sealed-secrets
    type: kubernetes.io/basic-auth
```

### 4.4 密钥轮换

```bash
#!/bin/bash
# sealed-secrets-key-rotation.sh - 密钥轮换

# 1. 备份当前密钥
kubectl get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-keys-backup.yaml

# 2. 获取新密钥
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  > new-pub-cert.pem

# 3. 重新加密所有SealedSecrets
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
  for ss in $(kubectl get sealedsecrets -n $ns -o jsonpath='{.items[*].metadata.name}'); do
    echo "Re-encrypting $ns/$ss"
    
    # 获取原始Secret
    kubectl get secret $ss -n $ns -o yaml > /tmp/secret.yaml
    
    # 重新加密
    kubeseal --cert new-pub-cert.pem < /tmp/secret.yaml > /tmp/sealed-secret.yaml
    
    # 应用新的SealedSecret
    kubectl apply -f /tmp/sealed-secret.yaml
  done
done

# 4. 清理临时文件
rm /tmp/secret.yaml /tmp/sealed-secret.yaml
```

---

## 五、SOPS加密

### 5.1 SOPS配置与使用

```yaml
# .sops.yaml - SOPS配置文件
creation_rules:
  # 生产环境使用AWS KMS
  - path_regex: .*production.*\.yaml$
    kms: arn:aws:kms:us-west-2:123456789012:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    encrypted_regex: ^(data|stringData)$
  
  # 开发环境使用AGE
  - path_regex: .*development.*\.yaml$
    age: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
    encrypted_regex: ^(data|stringData)$
  
  # 默认使用PGP
  - path_regex: .*\.yaml$
    pgp: FBC7B9E2A4F9289AC0C1D4843D16CEE4A27381B4
    encrypted_regex: ^(data|stringData)$
```

```bash
#!/bin/bash
# sops-workflow.sh - SOPS工作流

# 1. 安装SOPS
# brew install sops  # macOS
# apt install sops  # Ubuntu

# 2. 创建未加密的Secret YAML
cat > secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: production
type: Opaque
stringData:
  username: admin
  password: supersecretpassword
  api-key: abcd1234
EOF

# 3. 加密文件
sops --encrypt secret.yaml > secret.enc.yaml

# 4. 编辑加密文件 (会自动解密编辑后重新加密)
sops secret.enc.yaml

# 5. 解密并应用
sops --decrypt secret.enc.yaml | kubectl apply -f -

# 6. 仅加密特定键
sops --encrypt --encrypted-regex '^(data|stringData)$' secret.yaml > secret.enc.yaml

# 7. 使用环境变量中的密钥
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
sops --decrypt secret.enc.yaml

# 8. 轮换密钥
sops --rotate --in-place secret.enc.yaml
```

### 5.2 SOPS与GitOps集成

```yaml
# ArgoCD SOPS插件配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  configManagementPlugins: |
    - name: sops
      init:
        command: ["/bin/sh", "-c"]
        args: ["echo 'Initializing SOPS...'"]
      generate:
        command: ["/bin/sh", "-c"]
        args:
          - |
            find . -name '*.enc.yaml' -o -name '*.enc.yml' | while read file; do
              sops --decrypt "$file"
            done
---
# Flux SOPS解密配置
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: production-secrets
  namespace: flux-system
spec:
  interval: 10m
  path: ./production
  prune: true
  sourceRef:
    kind: GitRepository
    name: infrastructure
  decryption:
    provider: sops
    secretRef:
      name: sops-age
---
apiVersion: v1
kind: Secret
metadata:
  name: sops-age
  namespace: flux-system
stringData:
  age.agekey: |
    # created: 2024-01-01T00:00:00Z
    # public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
    AGE-SECRET-KEY-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

---

## 六、etcd加密配置

### 6.1 EncryptionConfiguration

```yaml
# /etc/kubernetes/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
    - secrets
    - configmaps
    providers:
    # 推荐: 使用外部KMS
    - kms:
        apiVersion: v2
        name: aws-encryption-provider
        endpoint: unix:///var/run/kmsplugin/socket.sock
        cachesize: 1000
        timeout: 3s
    # 备选: AES-GCM
    - aescbc:
        keys:
        - name: key1
          secret: <base64-encoded-32-byte-key>
    # 兼容旧数据
    - identity: {}
---
# API Server配置
# kube-apiserver --encryption-provider-config=/etc/kubernetes/encryption-config.yaml
```

### 6.2 AWS KMS Provider

```yaml
# AWS KMS加密提供者
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: aws-encryption-provider
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: aws-encryption-provider
  template:
    metadata:
      labels:
        app: aws-encryption-provider
    spec:
      hostNetwork: true
      containers:
      - name: aws-encryption-provider
        image: amazon/aws-encryption-provider:v1.0.0
        args:
        - --key=arn:aws:kms:us-west-2:123456789012:key/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
        - --region=us-west-2
        - --listen=/var/run/kmsplugin/socket.sock
        
        volumeMounts:
        - name: socket
          mountPath: /var/run/kmsplugin
      
      volumes:
      - name: socket
        hostPath:
          path: /var/run/kmsplugin
          type: DirectoryOrCreate
      
      nodeSelector:
        node-role.kubernetes.io/control-plane: ""
      
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
```

---

## 七、安全最佳实践

### 7.1 密钥管理安全检查清单

| 检查项 | 风险等级 | 检查方法 | 修复建议 |
|-------|---------|---------|---------|
| **硬编码密钥** | 极高 | grep -r "password=" | 移至Secret/Vault |
| **明文Secret** | 高 | kubectl get secret -o yaml | 启用etcd加密 |
| **过宽RBAC** | 高 | kubectl auth can-i | 最小权限原则 |
| **无轮换策略** | 中 | 检查密钥创建时间 | 设置自动轮换 |
| **无审计日志** | 中 | 检查审计配置 | 启用审计日志 |
| **镜像内密钥** | 高 | trivy image scan | 移除并重建镜像 |
| **Git中的密钥** | 极高 | git-secrets scan | 使用Sealed Secrets |

### 7.2 RBAC最小权限配置

```yaml
# 应用专用Secret读取权限
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: production
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["myapp-db-creds", "myapp-api-keys"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: myapp-secret-reader
  namespace: production
subjects:
- kind: ServiceAccount
  name: myapp-sa
  namespace: production
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
---
# 禁止列出Secret
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: deny-secret-list
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["list", "watch"]
```

### 7.3 密钥审计配置

```yaml
# 审计策略 - 记录所有Secret访问
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# 记录所有Secret操作
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
  
# 记录ServiceAccount Token创建
- level: Metadata
  resources:
  - group: ""
    resources: ["serviceaccounts/token"]
  verbs: ["create"]

# 记录RBAC变更
- level: RequestResponse
  resources:
  - group: "rbac.authorization.k8s.io"
    resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
```

---

## 八、监控与告警

### 8.1 密钥管理监控

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: secret-management-alerts
  namespace: monitoring
spec:
  groups:
  - name: secret-security
    rules:
    # Secret未加密存储
    - alert: SecretNotEncrypted
      expr: |
        kube_secret_info unless on(namespace, secret) 
        externalsecret_status_condition{condition="Ready", status="True"}
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "发现未通过ESO管理的Secret"
        description: "Secret {{ $labels.namespace }}/{{ $labels.secret }} 未加密管理"
    
    # Secret访问异常
    - alert: UnusualSecretAccess
      expr: |
        increase(apiserver_request_total{
          resource="secrets",
          verb=~"get|list"
        }[5m]) > 100
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Secret访问频率异常"
    
    # Vault不健康
    - alert: VaultUnhealthy
      expr: vault_core_unsealed == 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Vault处于sealed状态"
    
    # 密钥即将过期
    - alert: SecretExpiringSoon
      expr: |
        (vault_secret_lease_expiration_time_seconds - time()) < 86400
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "Vault租约即将过期"
```

---

## 九、快速参考

### 9.1 方案选择决策树

```
需要密钥管理方案?
    │
    ├─ 多云/混合云环境?
    │   └─ YES → External Secrets Operator
    │
    ├─ 需要动态密钥/证书签发?
    │   └─ YES → HashiCorp Vault
    │
    ├─ 纯GitOps工作流?
    │   └─ YES → Sealed Secrets
    │
    ├─ 小团队快速起步?
    │   └─ YES → SOPS
    │
    └─ 单一云环境?
        └─ YES → 云原生方案 (AWS SM/Azure KV/GCP SM)
```

### 9.2 常用命令速查

```bash
# External Secrets
kubectl get externalsecrets -A
kubectl describe externalsecret <name> -n <namespace>

# Vault
vault status
vault kv get secret/myapp
vault login -method=kubernetes role=myapp

# Sealed Secrets
kubeseal --fetch-cert > pub-cert.pem
kubectl create secret generic mysecret --dry-run=client -o yaml | kubeseal -o yaml

# SOPS
sops --encrypt secret.yaml > secret.enc.yaml
sops --decrypt secret.enc.yaml | kubectl apply -f -

# 检查Secret
kubectl get secrets -A -o json | jq '.items[] | select(.type=="Opaque") | .metadata.name'
```

---

## 十、最佳实践总结

### 密钥管理检查清单

- [ ] **禁止硬编码**: 代码/配置中不含明文密钥
- [ ] **etcd加密**: 启用EncryptionConfiguration
- [ ] **外部存储**: 使用ESO/Vault/云KMS
- [ ] **最小权限**: RBAC限制Secret访问
- [ ] **自动轮换**: 设置密钥轮换策略
- [ ] **审计日志**: 记录所有密钥访问
- [ ] **GitOps安全**: 使用Sealed Secrets/SOPS
- [ ] **监控告警**: 异常访问检测
- [ ] **灾备恢复**: 密钥备份策略
- [ ] **合规检查**: 定期安全扫描

---

**相关文档**: [91-安全扫描工具](91-security-scanning-tools.md) | [92-策略验证工具](92-policy-validation-tools.md) | [89-RBAC权限管理](89-rbac-permissions.md)

**版本**: External Secrets 0.9+ | Vault 1.15+ | Sealed Secrets 0.25+ | SOPS 3.8+
