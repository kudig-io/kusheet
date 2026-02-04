# 91 - 安全扫描与漏洞检测工具

> **适用版本**: Kubernetes v1.25 - v1.32 | **难度**: 中高级 | **参考**: [Trivy](https://aquasecurity.github.io/trivy/) | [Grype](https://github.com/anchore/grype) | [Falco](https://falco.org/)

## 一、安全扫描体系架构

### 1.1 DevSecOps安全扫描全景

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        DevSecOps Security Scanning Architecture                      │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌────────────────────────────────────────────────────────────────────────────────┐ │
│  │                            Development Phase                                    │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │ │
│  │  │    SAST      │  │    SCA       │  │   Secrets    │  │   License    │       │ │
│  │  │  (Semgrep)   │  │  (Snyk/      │  │   Scanning   │  │   Compliance │       │ │
│  │  │              │  │   Dependabot)│  │  (gitleaks)  │  │  (FOSSA)     │       │ │
│  │  │ Code Vulns   │  │ Dependencies │  │ Hardcoded    │  │ OSS License  │       │ │
│  │  │ SQL Injection│  │ CVE Database │  │ Credentials  │  │ Violations   │       │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘       │ │
│  └────────────────────────────────────────────────────────────────────────────────┘ │
│                                         │                                            │
│  ┌──────────────────────────────────────▼───────────────────────────────────────────┐│
│  │                              Build Phase                                         ││
│  │  ┌──────────────────────────────────────────────────────────────────────────┐   ││
│  │  │                        Container Image Scanning                           │   ││
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐         │   ││
│  │  │  │   Trivy    │  │   Grype    │  │   Clair    │  │   Snyk     │         │   ││
│  │  │  │            │  │            │  │            │  │            │         │   ││
│  │  │  │ • OS Pkgs  │  │ • SBOM     │  │ • Harbor   │  │ • SaaS     │         │   ││
│  │  │  │ • Lang Pkgs│  │ • CVE DB   │  │ • Quay.io  │  │ • IDE      │         │   ││
│  │  │  │ • Secrets  │  │ • Offline  │  │ • CoreOS   │  │ • CI/CD    │         │   ││
│  │  │  │ • Misconfig│  │ • SARIF    │  │ • Postgres │  │ • Monitor  │         │   ││
│  │  │  └────────────┘  └────────────┘  └────────────┘  └────────────┘         │   ││
│  │  └──────────────────────────────────────────────────────────────────────────┘   ││
│  │  ┌──────────────────────────────────────────────────────────────────────────┐   ││
│  │  │                            SBOM Generation                               │   ││
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐                         │   ││
│  │  │  │    Syft    │  │  Cyclonedx │  │   SPDX     │                         │   ││
│  │  │  │            │  │            │  │            │                         │   ││
│  │  │  │ • Multi-   │  │ • Standard │  │ • Standard │                         │   ││
│  │  │  │   format   │  │   Format   │  │   Format   │                         │   ││
│  │  │  └────────────┘  └────────────┘  └────────────┘                         │   ││
│  │  └──────────────────────────────────────────────────────────────────────────┘   ││
│  └─────────────────────────────────────────────────────────────────────────────────┘│
│                                         │                                            │
│  ┌──────────────────────────────────────▼───────────────────────────────────────────┐│
│  │                              Deploy Phase                                        ││
│  │  ┌──────────────────────────────────────────────────────────────────────────┐   ││
│  │  │                       Admission Control                                   │   ││
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐         │   ││
│  │  │  │   Kyverno  │  │   OPA/     │  │  Trivy     │  │  Sigstore/ │         │   ││
│  │  │  │            │  │ Gatekeeper │  │  Operator  │  │  Cosign    │         │   ││
│  │  │  │ • Policies │  │ • Rego     │  │ • Runtime  │  │ • Image    │         │   ││
│  │  │  │ • Mutation │  │ • Constr.  │  │   Scan     │  │   Sign     │         │   ││
│  │  │  └────────────┘  └────────────┘  └────────────┘  └────────────┘         │   ││
│  │  └──────────────────────────────────────────────────────────────────────────┘   ││
│  └─────────────────────────────────────────────────────────────────────────────────┘│
│                                         │                                            │
│  ┌──────────────────────────────────────▼───────────────────────────────────────────┐│
│  │                              Runtime Phase                                       ││
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        ││
│  │  │    Falco     │  │   Tetragon  │  │   KubeArmor │  │   Sysdig     │        ││
│  │  │              │  │              │  │              │  │              │        ││
│  │  │ • Syscall    │  │ • eBPF      │  │ • LSM/BPF   │  │ • Commercial │        ││
│  │  │ • K8s Audit  │  │ • Network   │  │ • Policies  │  │ • Platform   │        ││
│  │  │ • Custom     │  │ • Process   │  │ • Block     │  │ • Compliance │        ││
│  │  │   Rules      │  │   Tracing   │  │ • Alert     │  │ • Forensics  │        ││
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘        ││
│  └─────────────────────────────────────────────────────────────────────────────────┘│
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 安全扫描工具全面对比

| 工具 | 扫描目标 | 漏洞源 | SBOM | CI/CD | 运行时 | K8s原生 | 开源 | 适用场景 |
|-----|---------|-------|------|-------|-------|--------|------|---------|
| **Trivy** | 镜像/FS/Git/K8s | 多源聚合 | ✓ | ★★★★★ | ✓ | ★★★★★ | ✓ | 全能首选 |
| **Grype** | 镜像/SBOM | Anchore | ✓ | ★★★★☆ | ✗ | ★★★☆☆ | ✓ | SBOM扫描 |
| **Clair** | 镜像 | CVE | ✗ | ★★★☆☆ | ✗ | ★★★☆☆ | ✓ | Harbor集成 |
| **Snyk** | 全栈 | 商业DB | ✓ | ★★★★★ | ✓ | ★★★★☆ | 部分 | 开发者体验 |
| **Anchore** | 镜像/SBOM | 多源 | ★★★★★ | ★★★★☆ | ✗ | ★★★★☆ | 企业版 | 企业合规 |
| **Falco** | 运行时 | 规则 | ✗ | ✗ | ★★★★★ | ★★★★★ | ✓ | 运行时检测 |
| **Kubescape** | K8s配置 | NSA/MITRE | ✗ | ★★★★☆ | ✓ | ★★★★★ | ✓ | K8s安全 |
| **Checkov** | IaC | 策略 | ✗ | ★★★★★ | ✗ | ★★★☆☆ | ✓ | IaC扫描 |

### 1.3 漏洞严重性与SLA

| 严重性 | CVSS分数 | 修复SLA | 阻断CI/CD | 示例 |
|-------|---------|---------|----------|------|
| **Critical** | 9.0-10.0 | 24小时 | 强制阻断 | Log4Shell, ShellShock |
| **High** | 7.0-8.9 | 7天 | 建议阻断 | 远程代码执行 |
| **Medium** | 4.0-6.9 | 30天 | 警告 | 信息泄露 |
| **Low** | 0.1-3.9 | 90天 | 记录 | 低风险配置 |
| **Unknown** | N/A | 评估 | 评估 | 新发现漏洞 |

---

## 二、Trivy全能扫描

### 2.1 Trivy Operator部署

```yaml
# Trivy Operator安装
apiVersion: v1
kind: Namespace
metadata:
  name: trivy-system
---
# helm repo add aqua https://aquasecurity.github.io/helm-charts/
# helm install trivy-operator aqua/trivy-operator -n trivy-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trivy-operator
  namespace: trivy-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: trivy-operator
  template:
    metadata:
      labels:
        app: trivy-operator
    spec:
      serviceAccountName: trivy-operator
      containers:
      - name: trivy-operator
        image: ghcr.io/aquasecurity/trivy-operator:0.18.4
        
        args:
        - --health-probe-bind-address=:8081
        - --metrics-bind-address=:8080
        - --leader-elect
        
        env:
        # 扫描配置
        - name: OPERATOR_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: OPERATOR_TARGET_NAMESPACES
          value: ""  # 空表示所有命名空间
        
        # Trivy配置
        - name: OPERATOR_VULNERABILITY_SCANNER_ENABLED
          value: "true"
        - name: OPERATOR_CONFIG_AUDIT_SCANNER_ENABLED
          value: "true"
        - name: OPERATOR_RBAC_ASSESSMENT_SCANNER_ENABLED
          value: "true"
        - name: OPERATOR_INFRA_ASSESSMENT_SCANNER_ENABLED
          value: "true"
        - name: OPERATOR_CLUSTER_COMPLIANCE_ENABLED
          value: "true"
        
        # 扫描参数
        - name: OPERATOR_SCANNER_TRIVY_SEVERITY
          value: "CRITICAL,HIGH,MEDIUM"
        - name: OPERATOR_SCANNER_TRIVY_IGNORE_UNFIXED
          value: "true"
        - name: OPERATOR_SCANNER_TRIVY_TIMEOUT
          value: "5m"
        
        # 并发控制
        - name: OPERATOR_CONCURRENT_SCAN_JOBS_LIMIT
          value: "10"
        - name: OPERATOR_SCAN_JOB_RETRY_AFTER
          value: "30s"
        
        ports:
        - containerPort: 8080
          name: metrics
        - containerPort: 8081
          name: health
        
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8081
          initialDelaySeconds: 15
        
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8081
          initialDelaySeconds: 5
        
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop: ["ALL"]
---
# Trivy配置ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: trivy-operator-trivy-config
  namespace: trivy-system
data:
  # 扫描器模式
  trivy.mode: Standalone
  
  # 漏洞数据库
  trivy.dbRepository: ghcr.io/aquasecurity/trivy-db
  trivy.dbRepositoryInsecure: "false"
  
  # Java漏洞数据库
  trivy.javaDbRepository: ghcr.io/aquasecurity/trivy-java-db
  
  # 严重性过滤
  trivy.severity: CRITICAL,HIGH,MEDIUM
  
  # 忽略未修复漏洞
  trivy.ignoreUnfixed: "true"
  
  # 超时设置
  trivy.timeout: "5m0s"
  
  # 资源限制
  trivy.resources.requests.cpu: "100m"
  trivy.resources.requests.memory: "100M"
  trivy.resources.limits.cpu: "500m"
  trivy.resources.limits.memory: "500M"
  
  # 离线模式 (可选)
  # trivy.offlineScan: "true"
  
  # 忽略规则
  trivy.ignorePolicy: |
    package trivy
    import data.lib.trivy
    
    default ignore = false
    
    # 忽略特定CVE
    ignore {
      input.VulnerabilityID == "CVE-2021-44228"
      input.PkgName == "log4j-core"
      input.InstalledVersion == "2.17.0"
    }
```

### 2.2 CI/CD流水线集成

```yaml
# GitLab CI集成
stages:
  - build
  - scan
  - deploy

variables:
  TRIVY_VERSION: "0.48.3"
  TRIVY_SEVERITY: "CRITICAL,HIGH"
  TRIVY_EXIT_CODE: "1"  # 发现漏洞时失败

# 镜像构建
build:
  stage: build
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

# 容器镜像扫描
container-scan:
  stage: scan
  image: aquasec/trivy:$TRIVY_VERSION
  script:
    # 更新漏洞数据库
    - trivy image --download-db-only
    
    # 镜像扫描
    - |
      trivy image \
        --exit-code $TRIVY_EXIT_CODE \
        --severity $TRIVY_SEVERITY \
        --ignore-unfixed \
        --format json \
        --output trivy-image-report.json \
        $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
    
    # 生成HTML报告
    - |
      trivy image \
        --severity $TRIVY_SEVERITY \
        --format template \
        --template "@/contrib/html.tpl" \
        --output trivy-image-report.html \
        $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
    
    # 生成SARIF报告 (GitHub/GitLab集成)
    - |
      trivy image \
        --format sarif \
        --output trivy-image-report.sarif \
        $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  
  artifacts:
    paths:
      - trivy-image-report.json
      - trivy-image-report.html
      - trivy-image-report.sarif
    reports:
      container_scanning: trivy-image-report.json
  
  allow_failure: false

# 文件系统扫描
fs-scan:
  stage: scan
  image: aquasec/trivy:$TRIVY_VERSION
  script:
    - |
      trivy fs \
        --exit-code 0 \
        --severity $TRIVY_SEVERITY \
        --format json \
        --output trivy-fs-report.json \
        .
  artifacts:
    paths:
      - trivy-fs-report.json

# IaC配置扫描
config-scan:
  stage: scan
  image: aquasec/trivy:$TRIVY_VERSION
  script:
    - |
      trivy config \
        --exit-code 0 \
        --severity $TRIVY_SEVERITY \
        --format json \
        --output trivy-config-report.json \
        ./k8s/
  artifacts:
    paths:
      - trivy-config-report.json

# Secret扫描
secret-scan:
  stage: scan
  image: aquasec/trivy:$TRIVY_VERSION
  script:
    - |
      trivy fs \
        --scanners secret \
        --exit-code 1 \
        --format json \
        --output trivy-secret-report.json \
        .
  artifacts:
    paths:
      - trivy-secret-report.json
---
# GitHub Actions集成
name: Security Scan

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  trivy-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Build image
      run: docker build -t myapp:${{ github.sha }} .
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: myapp:${{ github.sha }}
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL,HIGH'
        ignore-unfixed: true
    
    - name: Upload Trivy scan results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'
    
    - name: Run Trivy in IaC mode
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'config'
        scan-ref: './k8s'
        format: 'table'
        exit-code: '0'
```

### 2.3 Trivy高级扫描配置

```bash
#!/bin/bash
# trivy-advanced-scan.sh - Trivy高级扫描脚本

# 环境变量
export TRIVY_DB_REPOSITORY="ghcr.io/aquasecurity/trivy-db"
export TRIVY_JAVA_DB_REPOSITORY="ghcr.io/aquasecurity/trivy-java-db"
export TRIVY_CACHE_DIR="$HOME/.cache/trivy"

# 1. 全面镜像扫描
trivy_image_scan() {
    local image=$1
    local output_dir=${2:-./trivy-reports}
    
    mkdir -p $output_dir
    
    # 漏洞扫描
    trivy image \
        --severity CRITICAL,HIGH,MEDIUM,LOW \
        --ignore-unfixed \
        --scanners vuln \
        --format json \
        --output $output_dir/vulnerabilities.json \
        $image
    
    # Secret扫描
    trivy image \
        --scanners secret \
        --format json \
        --output $output_dir/secrets.json \
        $image
    
    # 配置扫描
    trivy image \
        --scanners misconfig \
        --format json \
        --output $output_dir/misconfigs.json \
        $image
    
    # 生成SBOM
    trivy image \
        --format cyclonedx \
        --output $output_dir/sbom.json \
        $image
    
    # 综合报告
    trivy image \
        --severity CRITICAL,HIGH \
        --ignore-unfixed \
        --format template \
        --template "@contrib/html.tpl" \
        --output $output_dir/report.html \
        $image
    
    echo "扫描完成! 报告位于: $output_dir"
}

# 2. Kubernetes集群扫描
trivy_k8s_scan() {
    local context=${1:-$(kubectl config current-context)}
    local output_dir=${2:-./trivy-k8s-reports}
    
    mkdir -p $output_dir
    
    # 全集群扫描
    trivy k8s \
        --context $context \
        --report all \
        --severity CRITICAL,HIGH \
        --format json \
        --output $output_dir/cluster-report.json
    
    # 特定命名空间扫描
    trivy k8s \
        --context $context \
        --include-namespaces production,staging \
        --report vulnerabilities \
        --format table
    
    # 合规性检查
    trivy k8s \
        --context $context \
        --compliance k8s-nsa \
        --report summary \
        --output $output_dir/compliance-nsa.txt
    
    trivy k8s \
        --context $context \
        --compliance k8s-cis \
        --report summary \
        --output $output_dir/compliance-cis.txt
}

# 3. 定时扫描所有已部署镜像
scan_deployed_images() {
    local output_file=${1:-deployed-images-scan.json}
    
    # 获取所有唯一镜像
    images=$(kubectl get pods --all-namespaces -o jsonpath='{.items[*].spec.containers[*].image}' | \
        tr -s '[[:space:]]' '\n' | sort | uniq)
    
    echo "Found $(echo "$images" | wc -l) unique images"
    
    # 扫描每个镜像
    results=()
    for image in $images; do
        echo "Scanning: $image"
        result=$(trivy image \
            --severity CRITICAL,HIGH \
            --ignore-unfixed \
            --format json \
            --quiet \
            $image 2>/dev/null)
        results+=("$result")
    done
    
    # 合并结果
    echo "${results[@]}" | jq -s '.' > $output_file
    
    # 统计
    critical_count=$(cat $output_file | jq '[.[].Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length')
    high_count=$(cat $output_file | jq '[.[].Results[].Vulnerabilities[]? | select(.Severity=="HIGH")] | length')
    
    echo "扫描完成! Critical: $critical_count, High: $high_count"
}

# 4. SBOM生成与管理
generate_sbom() {
    local image=$1
    local format=${2:-cyclonedx}
    local output_file=${3:-sbom.json}
    
    trivy image \
        --format $format \
        --output $output_file \
        $image
    
    echo "SBOM generated: $output_file (format: $format)"
}

# 5. 忽略规则配置
create_ignore_policy() {
    cat > .trivyignore.rego << 'EOF'
package trivy

import data.lib.trivy

default ignore = false

# 忽略特定CVE (已有缓解措施)
ignore {
    input.VulnerabilityID == "CVE-2023-44487"  # HTTP/2 Rapid Reset
    contains(input.PkgName, "golang")
}

# 忽略开发依赖漏洞
ignore {
    input.Class == "lang-pkgs"
    input.Type == "npm"
    contains(input.PkgPath, "devDependencies")
}

# 忽略特定包的低风险漏洞
ignore {
    input.Severity == "LOW"
    input.PkgName == "openssl"
}

# 忽略已接受风险的漏洞
ignore {
    input.VulnerabilityID == data.accepted_risks[_]
}

accepted_risks = [
    "CVE-2021-3711",
    "CVE-2021-3712"
]
EOF
    
    echo "Ignore policy created: .trivyignore.rego"
}

# 使用示例
# trivy_image_scan "nginx:latest" "./nginx-reports"
# trivy_k8s_scan "my-cluster" "./k8s-reports"
# scan_deployed_images "all-images-report.json"
```

### 2.4 VulnerabilityReport CRD

```yaml
# 查看扫描结果
apiVersion: aquasecurity.github.io/v1alpha1
kind: VulnerabilityReport
metadata:
  name: replicaset-nginx-7b8d6d5d7-nginx
  namespace: default
  labels:
    trivy-operator.resource.kind: ReplicaSet
    trivy-operator.resource.name: nginx-7b8d6d5d7
    trivy-operator.resource.namespace: default
    trivy-operator.container.name: nginx
spec:
  artifact:
    repository: library/nginx
    tag: latest
    digest: sha256:abc123...
  registry:
    server: index.docker.io
  scanner:
    name: Trivy
    vendor: Aqua Security
    version: 0.48.3
  summary:
    criticalCount: 2
    highCount: 15
    mediumCount: 45
    lowCount: 23
    unknownCount: 0
  vulnerabilities:
  - vulnerabilityID: CVE-2023-44487
    resource: nghttp2
    installedVersion: 1.43.0
    fixedVersion: 1.57.0
    severity: CRITICAL
    title: HTTP/2 Rapid Reset Attack
    description: |
      The HTTP/2 protocol allows denial of service...
    primaryLink: https://nvd.nist.gov/vuln/detail/CVE-2023-44487
    score: 7.5
    target: nginx:latest (debian 12.2)
    class: os-pkgs
    packageType: debian
---
# ConfigAuditReport - 配置审计结果
apiVersion: aquasecurity.github.io/v1alpha1
kind: ConfigAuditReport
metadata:
  name: replicaset-nginx-7b8d6d5d7
  namespace: default
spec:
  scanner:
    name: Trivy
    vendor: Aqua Security
    version: 0.48.3
  summary:
    criticalCount: 1
    highCount: 3
    mediumCount: 5
    lowCount: 2
  checks:
  - checkID: KSV001
    title: Process can elevate its own privileges
    description: |
      A program inside the container can elevate its own privileges
      and run as root.
    severity: MEDIUM
    category: Kubernetes Security Check
    success: false
    messages:
    - Container 'nginx' of ReplicaSet 'nginx-7b8d6d5d7' should set
      'securityContext.allowPrivilegeEscalation' to false
```

---

## 三、Grype与SBOM

### 3.1 Syft SBOM生成

```bash
#!/bin/bash
# sbom-workflow.sh - SBOM生成与管理工作流

# 1. 安装Syft
# curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# 2. 生成SBOM (多种格式)
generate_sbom_all_formats() {
    local image=$1
    local output_dir=${2:-./sbom}
    
    mkdir -p $output_dir
    
    # CycloneDX格式 (推荐)
    syft $image -o cyclonedx-json=$output_dir/sbom-cyclonedx.json
    
    # SPDX格式
    syft $image -o spdx-json=$output_dir/sbom-spdx.json
    
    # Syft原生格式
    syft $image -o json=$output_dir/sbom-syft.json
    
    # 表格格式 (人类可读)
    syft $image -o table=$output_dir/sbom-table.txt
    
    echo "SBOM generated in multiple formats: $output_dir"
}

# 3. 从Dockerfile生成SBOM
syft_from_dockerfile() {
    local dockerfile_path=${1:-.}
    
    # 构建并扫描
    docker build -t temp-scan:latest $dockerfile_path
    syft temp-scan:latest -o cyclonedx-json
    docker rmi temp-scan:latest
}

# 4. 扫描目录
syft_scan_directory() {
    local dir=$1
    
    syft dir:$dir -o cyclonedx-json
}

# 示例调用
# generate_sbom_all_formats "nginx:latest" "./nginx-sbom"
```

### 3.2 Grype漏洞扫描

```yaml
# GitLab CI - Grype集成
grype-scan:
  stage: scan
  image: anchore/grype:latest
  script:
    # 更新漏洞数据库
    - grype db update
    
    # 从SBOM扫描
    - |
      grype sbom:./sbom-cyclonedx.json \
        --output json \
        --file grype-report.json \
        --fail-on critical
    
    # 直接扫描镜像
    - |
      grype $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA \
        --output table \
        --only-fixed \
        --fail-on high
  
  artifacts:
    paths:
      - grype-report.json
---
# Grype配置文件 (.grype.yaml)
# 放置在项目根目录
output: "json"
file: "grype-report.json"
distro: ""
add-cpes-if-none: true
by-cve: false
only-fixed: true
fail-on: "critical"

ignore:
  # 忽略特定CVE
  - vulnerability: CVE-2021-44228
    fix-state: not-fixed
  
  # 忽略特定包
  - package:
      name: openssl
      type: deb
    vulnerability: CVE-2023-*

check-for-app-update: true

db:
  auto-update: true
  cache-dir: /tmp/grype-db
```

### 3.3 离线环境扫描

```bash
#!/bin/bash
# offline-scanning.sh - 离线环境扫描配置

# 1. 预下载Trivy数据库
download_trivy_db() {
    local db_dir="/opt/trivy-db"
    mkdir -p $db_dir
    
    # 下载漏洞数据库
    oras pull ghcr.io/aquasecurity/trivy-db:2 \
        --output $db_dir
    
    # 下载Java数据库
    oras pull ghcr.io/aquasecurity/trivy-java-db:1 \
        --output $db_dir/java-db
    
    echo "Trivy DB downloaded to: $db_dir"
}

# 2. 离线扫描
trivy_offline_scan() {
    local image=$1
    local db_dir="/opt/trivy-db"
    
    trivy image \
        --offline-scan \
        --cache-dir $db_dir \
        --severity CRITICAL,HIGH \
        $image
}

# 3. 预下载Grype数据库
download_grype_db() {
    local db_dir="/opt/grype-db"
    mkdir -p $db_dir
    
    GRYPE_DB_CACHE_DIR=$db_dir grype db update
    
    echo "Grype DB downloaded to: $db_dir"
}

# 4. Grype离线扫描
grype_offline_scan() {
    local image=$1
    local db_dir="/opt/grype-db"
    
    GRYPE_DB_CACHE_DIR=$db_dir grype $image --offline
}

# 5. 创建离线扫描镜像
create_offline_scanner_image() {
    cat > Dockerfile.scanner << 'EOF'
FROM aquasec/trivy:latest

# 预下载数据库
RUN trivy image --download-db-only

# 设置离线模式
ENV TRIVY_OFFLINE_SCAN=true

ENTRYPOINT ["trivy"]
EOF
    
    docker build -f Dockerfile.scanner -t trivy-offline:latest .
    echo "Offline scanner image built: trivy-offline:latest"
}
```

---

## 四、Falco运行时安全

### 4.1 Falco部署配置

```yaml
# Falco DaemonSet部署
apiVersion: v1
kind: Namespace
metadata:
  name: falco
---
# helm repo add falcosecurity https://falcosecurity.github.io/charts
# helm install falco falcosecurity/falco -n falco -f falco-values.yaml
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: falco
  namespace: falco
spec:
  selector:
    matchLabels:
      app: falco
  template:
    metadata:
      labels:
        app: falco
    spec:
      serviceAccountName: falco
      
      # 特权模式 (eBPF探针需要)
      hostPID: true
      hostNetwork: true
      
      containers:
      - name: falco
        image: falcosecurity/falco-no-driver:0.37.0
        
        args:
        - /usr/bin/falco
        - --cri=/run/containerd/containerd.sock
        - --cri=/run/crio/crio.sock
        - -K=/var/run/secrets/kubernetes.io/serviceaccount/token
        - -k=https://kubernetes.default
        - --k8s-node=$(FALCO_K8S_NODE_NAME)
        - -pk
        
        env:
        - name: FALCO_K8S_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: FALCO_BPF_PROBE
          value: ""
        
        securityContext:
          privileged: true
        
        resources:
          requests:
            cpu: 100m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1024Mi
        
        volumeMounts:
        # 内核模块/eBPF
        - name: dev
          mountPath: /host/dev
          readOnly: true
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: boot
          mountPath: /host/boot
          readOnly: true
        - name: lib-modules
          mountPath: /host/lib/modules
          readOnly: true
        - name: usr-src
          mountPath: /host/usr
          readOnly: true
        
        # 容器运行时
        - name: containerd-socket
          mountPath: /run/containerd/containerd.sock
          readOnly: true
        - name: crio-socket
          mountPath: /run/crio/crio.sock
          readOnly: true
        
        # 配置
        - name: falco-config
          mountPath: /etc/falco
        - name: falco-rules
          mountPath: /etc/falco/rules.d
      
      volumes:
      - name: dev
        hostPath:
          path: /dev
      - name: proc
        hostPath:
          path: /proc
      - name: boot
        hostPath:
          path: /boot
      - name: lib-modules
        hostPath:
          path: /lib/modules
      - name: usr-src
        hostPath:
          path: /usr
      - name: containerd-socket
        hostPath:
          path: /run/containerd/containerd.sock
      - name: crio-socket
        hostPath:
          path: /run/crio/crio.sock
      - name: falco-config
        configMap:
          name: falco-config
      - name: falco-rules
        configMap:
          name: falco-rules
      
      tolerations:
      - effect: NoSchedule
        operator: Exists
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-config
  namespace: falco
data:
  falco.yaml: |
    # 规则文件
    rules_file:
      - /etc/falco/falco_rules.yaml
      - /etc/falco/falco_rules.local.yaml
      - /etc/falco/rules.d
    
    # 输出配置
    json_output: true
    json_include_output_property: true
    json_include_tags_property: true
    
    # 日志配置
    log_stderr: true
    log_syslog: true
    log_level: info
    
    # 输出通道
    stdout_output:
      enabled: true
    
    syslog_output:
      enabled: true
    
    file_output:
      enabled: true
      keep_alive: false
      filename: /var/log/falco/events.log
    
    http_output:
      enabled: true
      url: http://falcosidekick.falco:2801/
      user_agent: "falco/0.37.0"
    
    grpc:
      enabled: true
      bind_address: "unix:///run/falco/falco.sock"
      threadiness: 0
    
    grpc_output:
      enabled: true
    
    # Kubernetes审计日志
    webserver:
      enabled: true
      listen_port: 8765
      k8s_healthz_endpoint: /healthz
      ssl_enabled: false
    
    # 性能优化
    syscall_event_drops:
      threshold: 0.1
      actions:
        - log
        - alert
    
    buffered_outputs: true
    outputs_queue:
      capacity: 0
```

### 4.2 Falco自定义规则

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-rules
  namespace: falco
data:
  custom_rules.yaml: |
    # ========================
    # 容器安全规则
    # ========================
    
    # 检测容器内执行shell
    - rule: Shell Spawned in Container
      desc: Detect shell spawned in a container
      condition: >
        spawned_process and 
        container and 
        shell_procs and
        not proc.pname in (allowed_shell_parents)
      output: >
        Shell spawned in container 
        (user=%user.name user_loginuid=%user.loginuid command=%proc.cmdline 
        container_id=%container.id container_name=%container.name 
        image=%container.image.repository k8s.ns=%k8s.ns.name 
        k8s.pod=%k8s.pod.name)
      priority: WARNING
      tags: [container, shell, mitre_execution]
    
    # 检测敏感文件访问
    - rule: Read Sensitive File in Container
      desc: Detect reading of sensitive files in container
      condition: >
        open_read and 
        container and 
        sensitive_files and
        not proc.name in (allowed_sensitive_readers)
      output: >
        Sensitive file read in container
        (user=%user.name command=%proc.cmdline file=%fd.name 
        container_id=%container.id image=%container.image.repository)
      priority: WARNING
      tags: [container, filesystem, mitre_credential_access]
    
    # 检测特权容器
    - rule: Privileged Container Started
      desc: Detect when a privileged container is started
      condition: >
        container_started and 
        container.privileged=true
      output: >
        Privileged container started
        (user=%user.name command=%proc.cmdline 
        container_id=%container.id container_name=%container.name 
        image=%container.image.repository k8s.ns=%k8s.ns.name)
      priority: CRITICAL
      tags: [container, privileged, mitre_privilege_escalation]
    
    # ========================
    # Kubernetes安全规则
    # ========================
    
    # 检测匿名访问API Server
    - rule: Anonymous Request to K8s API
      desc: Detect anonymous requests to Kubernetes API server
      condition: >
        jevt.value[/userAgent] contains "kubectl" and
        jevt.value[/user/username] = "system:anonymous"
      output: >
        Anonymous request to K8s API
        (user=%jevt.value[/user/username] verb=%jevt.value[/verb] 
        uri=%jevt.value[/requestURI])
      priority: WARNING
      source: k8s_audit
      tags: [k8s, anonymous, mitre_initial_access]
    
    # 检测创建特权Pod
    - rule: Create Privileged Pod
      desc: Detect creation of privileged pods
      condition: >
        kevt and 
        kcreate and 
        pod and
        jevt.value[/requestObject/spec/containers/0/securityContext/privileged] = "true"
      output: >
        Privileged pod creation attempt
        (user=%ka.user.name pod=%ka.target.name ns=%ka.target.namespace)
      priority: CRITICAL
      source: k8s_audit
      tags: [k8s, privileged, mitre_privilege_escalation]
    
    # 检测Pod exec
    - rule: Attach or Exec to Pod
      desc: Detect any attempt to attach or exec into a pod
      condition: >
        kevt and 
        pod_subresource and 
        kcreate and 
        ka.target.subresource in (attach, exec)
      output: >
        Pod exec/attach detected
        (user=%ka.user.name pod=%ka.target.name ns=%ka.target.namespace 
        subresource=%ka.target.subresource)
      priority: NOTICE
      source: k8s_audit
      tags: [k8s, exec, mitre_execution]
    
    # 检测Secret访问
    - rule: K8s Secret Access
      desc: Detect any access to Kubernetes secrets
      condition: >
        kevt and 
        secret and 
        kget
      output: >
        K8s secret accessed
        (user=%ka.user.name secret=%ka.target.name ns=%ka.target.namespace)
      priority: INFO
      source: k8s_audit
      tags: [k8s, secret, mitre_credential_access]
    
    # ========================
    # 网络安全规则
    # ========================
    
    # 检测容器外连
    - rule: Outbound Connection to Suspicious IP
      desc: Detect outbound connection to suspicious IP ranges
      condition: >
        outbound and 
        container and
        fd.sip.name in (suspicious_ips)
      output: >
        Outbound connection to suspicious IP
        (user=%user.name command=%proc.cmdline connection=%fd.name 
        container_id=%container.id)
      priority: WARNING
      tags: [network, container, mitre_exfiltration]
    
    # 检测加密货币挖矿连接
    - rule: Cryptocurrency Mining Connection
      desc: Detect connection to known mining pools
      condition: >
        outbound and 
        container and
        (fd.sport in (mining_ports) or fd.sip.name in (mining_pools))
      output: >
        Cryptocurrency mining connection detected
        (user=%user.name command=%proc.cmdline connection=%fd.name 
        container_id=%container.id image=%container.image.repository)
      priority: CRITICAL
      tags: [network, mining, mitre_impact]
    
    # ========================
    # 进程安全规则
    # ========================
    
    # 检测反向Shell
    - rule: Reverse Shell Detected
      desc: Detect reverse shell attempts
      condition: >
        spawned_process and 
        container and
        ((proc.name = "bash" and proc.args contains "-i") or
         (proc.name = "nc" and proc.args contains "-e") or
         (proc.name = "python" and proc.args contains "socket"))
      output: >
        Reverse shell detected
        (user=%user.name command=%proc.cmdline 
        container_id=%container.id image=%container.image.repository)
      priority: CRITICAL
      tags: [container, shell, mitre_execution]
    
    # 检测可疑进程
    - rule: Suspicious Process in Container
      desc: Detect suspicious processes in containers
      condition: >
        spawned_process and 
        container and
        proc.name in (suspicious_procs)
      output: >
        Suspicious process spawned in container
        (user=%user.name process=%proc.name command=%proc.cmdline 
        container_id=%container.id)
      priority: WARNING
      tags: [container, process, mitre_execution]
    
    # ========================
    # 宏定义
    # ========================
    
    - macro: sensitive_files
      condition: >
        fd.name startswith /etc/shadow or
        fd.name startswith /etc/passwd or
        fd.name startswith /etc/sudoers or
        fd.name startswith /root/.ssh or
        fd.name contains /kube/config
    
    - macro: suspicious_procs
      condition: >
        proc.name in (nmap, masscan, nikto, sqlmap, metasploit, 
                      hydra, john, hashcat, mimikatz)
    
    - macro: mining_ports
      condition: >
        fd.sport in (3333, 4444, 5555, 7777, 8888, 9999, 14444, 45700)
    
    - list: suspicious_ips
      items: []  # 添加可疑IP列表
    
    - list: mining_pools
      items:
        - pool.minexmr.com
        - xmr.nanopool.org
        - pool.supportxmr.com
```

### 4.3 Falcosidekick告警集成

```yaml
# Falcosidekick部署
apiVersion: apps/v1
kind: Deployment
metadata:
  name: falcosidekick
  namespace: falco
spec:
  replicas: 1
  selector:
    matchLabels:
      app: falcosidekick
  template:
    metadata:
      labels:
        app: falcosidekick
    spec:
      containers:
      - name: falcosidekick
        image: falcosecurity/falcosidekick:2.28.0
        
        env:
        # Slack集成
        - name: SLACK_WEBHOOKURL
          valueFrom:
            secretKeyRef:
              name: falcosidekick-secrets
              key: slack-webhook
        - name: SLACK_MINIMUMPRIORITY
          value: "warning"
        - name: SLACK_OUTPUTFORMAT
          value: "all"
        
        # PagerDuty集成
        - name: PAGERDUTY_ROUTINGKEY
          valueFrom:
            secretKeyRef:
              name: falcosidekick-secrets
              key: pagerduty-key
        - name: PAGERDUTY_MINIMUMPRIORITY
          value: "critical"
        
        # Prometheus Alertmanager
        - name: ALERTMANAGER_HOSTPORT
          value: "http://alertmanager.monitoring:9093"
        - name: ALERTMANAGER_MINIMUMPRIORITY
          value: "warning"
        
        # Elasticsearch
        - name: ELASTICSEARCH_HOSTPORT
          value: "https://elasticsearch.logging:9200"
        - name: ELASTICSEARCH_INDEX
          value: "falco"
        - name: ELASTICSEARCH_TYPE
          value: "_doc"
        
        # Loki
        - name: LOKI_HOSTPORT
          value: "http://loki.logging:3100"
        - name: LOKI_MINIMUMPRIORITY
          value: "notice"
        
        # AWS CloudWatch
        - name: AWS_CLOUDWATCHLOGS_LOGGROUP
          value: "/falco/events"
        - name: AWS_CLOUDWATCHLOGS_LOGSTREAM
          value: "alerts"
        - name: AWS_REGION
          value: "us-west-2"
        
        ports:
        - containerPort: 2801
          name: http
        
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 256Mi
        
        livenessProbe:
          httpGet:
            path: /ping
            port: 2801
        
        readinessProbe:
          httpGet:
            path: /ping
            port: 2801
---
apiVersion: v1
kind: Service
metadata:
  name: falcosidekick
  namespace: falco
spec:
  ports:
  - port: 2801
    targetPort: 2801
  selector:
    app: falcosidekick
```

---

## 五、Kubescape合规扫描

### 5.1 Kubescape部署与扫描

```bash
#!/bin/bash
# kubescape-scanning.sh - Kubescape扫描脚本

# 安装Kubescape
# curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash

# 1. NSA/CISA框架扫描
kubescape_nsa_scan() {
    kubescape scan framework nsa \
        --enable-host-scan \
        --format json \
        --output nsa-scan-results.json \
        --verbose
    
    # 生成HTML报告
    kubescape scan framework nsa \
        --format html \
        --output nsa-scan-report.html
}

# 2. CIS Benchmark扫描
kubescape_cis_scan() {
    kubescape scan framework cis-v1.23-t1.0.1 \
        --enable-host-scan \
        --format json \
        --output cis-scan-results.json
}

# 3. MITRE ATT&CK扫描
kubescape_mitre_scan() {
    kubescape scan framework mitre \
        --format json \
        --output mitre-scan-results.json
}

# 4. 特定命名空间扫描
kubescape_namespace_scan() {
    local namespace=$1
    
    kubescape scan framework nsa \
        --include-namespaces $namespace \
        --format json \
        --output $namespace-scan-results.json
}

# 5. YAML文件扫描
kubescape_yaml_scan() {
    local yaml_path=$1
    
    kubescape scan $yaml_path \
        --format json \
        --output yaml-scan-results.json
}

# 6. Helm Chart扫描
kubescape_helm_scan() {
    local chart_path=$1
    
    kubescape scan $chart_path \
        --format json \
        --output helm-scan-results.json
}

# 7. 持续扫描 (Kubescape Operator)
install_kubescape_operator() {
    helm repo add kubescape https://kubescape.github.io/helm-charts/
    
    helm install kubescape kubescape/kubescape-operator \
        --namespace kubescape \
        --create-namespace \
        --set clusterName="my-cluster" \
        --set capabilities.continuousScan="enable" \
        --set capabilities.vulnerabilityScan="enable" \
        --set capabilities.nodeScan="enable"
}

# 使用示例
# kubescape_nsa_scan
# kubescape_namespace_scan "production"
```

### 5.2 Kubescape CI/CD集成

```yaml
# GitHub Actions - Kubescape
name: Kubernetes Security Scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  kubescape-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Kubescape Scan
      uses: kubescape/github-action@v3
      with:
        format: sarif
        outputFile: kubescape-results.sarif
        frameworks: nsa,mitre
        severityThreshold: high
        controlsConfig: |
          {
            "C-0009": {"severity": "high"},
            "C-0016": {"severity": "critical"}
          }
    
    - name: Upload Kubescape results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: kubescape-results.sarif
---
# GitLab CI - Kubescape
kubescape-scan:
  stage: scan
  image: quay.io/kubescape/kubescape:latest
  script:
    - kubescape scan framework nsa,mitre ./k8s/ 
        --format json 
        --output kubescape-results.json
        --compliance-threshold 80
    - |
      score=$(cat kubescape-results.json | jq '.summaryDetails.complianceScore')
      if (( $(echo "$score < 80" | bc -l) )); then
        echo "Compliance score $score is below threshold"
        exit 1
      fi
  artifacts:
    paths:
      - kubescape-results.json
```

---

## 六、准入控制集成

### 6.1 基于扫描结果的准入策略

```yaml
# Kyverno策略 - 阻止高危镜像
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-vulnerable-images
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: check-vulnerability-report
    match:
      any:
      - resources:
          kinds:
          - Pod
    preconditions:
      all:
      - key: "{{request.operation}}"
        operator: In
        value: ["CREATE", "UPDATE"]
    validate:
      message: "Image has critical vulnerabilities. Please fix before deploying."
      foreach:
      - list: "request.object.spec.containers"
        deny:
          conditions:
            any:
            - key: "{{ images.containers.\"{{element.image}}\".vulnerabilities.critical }}"
              operator: GreaterThan
              value: 0
---
# OPA/Gatekeeper约束
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockVulnerableImages
metadata:
  name: block-critical-vulns
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
    excludedNamespaces:
    - kube-system
    - gatekeeper-system
  parameters:
    maxCriticalVulns: 0
    maxHighVulns: 5
    allowedRegistries:
    - "gcr.io/my-project/"
    - "docker.io/library/"
---
# 约束模板
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sblockvulnerableimages
spec:
  crd:
    spec:
      names:
        kind: K8sBlockVulnerableImages
      validation:
        openAPIV3Schema:
          type: object
          properties:
            maxCriticalVulns:
              type: integer
            maxHighVulns:
              type: integer
            allowedRegistries:
              type: array
              items:
                type: string
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8sblockvulnerableimages
      
      violation[{"msg": msg}] {
        container := input.review.object.spec.containers[_]
        not image_allowed(container.image)
        msg := sprintf("Image %v is not from an allowed registry", [container.image])
      }
      
      violation[{"msg": msg}] {
        container := input.review.object.spec.containers[_]
        vuln_report := data.inventory.namespace[input.review.object.metadata.namespace]["aquasecurity.github.io/v1alpha1"]["VulnerabilityReport"]
        report := vuln_report[_]
        report.metadata.labels["trivy-operator.container.name"] == container.name
        report.spec.summary.criticalCount > input.parameters.maxCriticalVulns
        msg := sprintf("Container %v has %v critical vulnerabilities (max allowed: %v)", 
          [container.name, report.spec.summary.criticalCount, input.parameters.maxCriticalVulns])
      }
      
      image_allowed(image) {
        some i
        startswith(image, input.parameters.allowedRegistries[i])
      }
```

---

## 七、监控与告警

### 7.1 安全扫描监控

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: security-scanning-alerts
  namespace: monitoring
spec:
  groups:
  - name: vulnerability-alerts
    rules:
    # Critical漏洞检测
    - alert: CriticalVulnerabilityDetected
      expr: |
        sum by (namespace, name, image) (
          trivy_vulnerability_total{severity="Critical"}
        ) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "检测到Critical漏洞"
        description: "镜像 {{ $labels.image }} 在 {{ $labels.namespace }}/{{ $labels.name }} 存在Critical漏洞"
    
    # 漏洞数量趋势
    - alert: VulnerabilityCountIncreasing
      expr: |
        delta(sum(trivy_vulnerability_total{severity=~"Critical|High"})[24h:1h]) > 10
      for: 1h
      labels:
        severity: warning
      annotations:
        summary: "漏洞数量持续增加"
    
    # 扫描失败
    - alert: TrivyOperatorScanFailed
      expr: |
        trivy_operator_vulnerability_report_count{status="Failed"} > 0
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Trivy扫描失败"
  
  - name: falco-alerts
    rules:
    # Falco告警
    - alert: FalcoCriticalAlert
      expr: |
        sum by (rule) (
          increase(falco_events{priority="Critical"}[5m])
        ) > 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Falco检测到Critical事件"
        description: "规则: {{ $labels.rule }}"
    
    # Falco事件速率
    - alert: FalcoHighEventRate
      expr: |
        sum(rate(falco_events[5m])) > 100
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Falco事件速率异常"
```

---

## 八、快速参考

### 8.1 扫描命令速查

```bash
# Trivy
trivy image nginx:latest                           # 镜像扫描
trivy image --severity CRITICAL,HIGH nginx:latest  # 过滤严重性
trivy fs .                                         # 文件系统扫描
trivy config ./k8s/                                # IaC扫描
trivy k8s --report summary cluster                 # K8s集群扫描

# Grype
grype nginx:latest                                 # 镜像扫描
grype sbom:./sbom.json                            # SBOM扫描
grype dir:.                                        # 目录扫描

# Syft
syft nginx:latest                                  # 生成SBOM
syft nginx:latest -o cyclonedx-json               # 指定格式

# Kubescape
kubescape scan framework nsa                       # NSA框架扫描
kubescape scan framework cis                       # CIS扫描
kubescape scan ./k8s/                             # YAML扫描

# Falco
falco --list                                       # 列出规则
falco -r custom_rules.yaml                        # 使用自定义规则
```

### 8.2 漏洞修复优先级

| 优先级 | 条件 | 行动 |
|-------|------|------|
| P0 | Critical + 可利用 + 生产环境 | 立即修复 (24h) |
| P1 | Critical + 无修复版本 | 缓解措施 + 跟踪 |
| P2 | High + 可利用 | 7天内修复 |
| P3 | High/Medium + 开发环境 | 下个迭代 |
| P4 | Low + 信息性 | 按需处理 |

---

## 九、最佳实践总结

### 安全扫描检查清单

- [ ] **CI/CD集成**: 所有镜像构建必须扫描
- [ ] **阻断策略**: Critical漏洞阻断部署
- [ ] **SBOM管理**: 生成并存储所有镜像SBOM
- [ ] **运行时监控**: 部署Falco检测异常
- [ ] **合规扫描**: 定期NSA/CIS合规检查
- [ ] **漏洞追踪**: 集成Jira/GitHub Issues
- [ ] **修复SLA**: 明确各级别修复时限
- [ ] **离线能力**: 配置离线漏洞数据库
- [ ] **告警通知**: 配置多渠道告警
- [ ] **审计日志**: 记录所有扫描结果

---

**相关文档**: [90-密钥管理工具](90-secret-management-tools.md) | [92-策略验证工具](92-policy-validation-tools.md) | [93-网络安全策略](93-network-policies.md)

**版本**: Trivy 0.48+ | Grype 0.74+ | Falco 0.37+ | Kubescape 3.0+
