# 表格43：镜像安全扫描表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/containers/images](https://kubernetes.io/docs/concepts/containers/images/)

## 扫描工具对比

| 工具 | 类型 | 扫描内容 | 部署方式 | 成本 | ACK集成 |
|-----|------|---------|---------|------|---------|
| **Trivy** | 开源 | CVE/配置/Secret | CLI/Operator | 免费 | 支持 |
| **Clair** | 开源 | CVE | 服务 | 免费 | - |
| **Anchore** | 开源/商业 | CVE/策略 | 服务 | 免费/付费 | - |
| **Snyk** | 商业 | CVE/代码 | SaaS/CLI | 付费 | - |
| **ACR扫描** | 云服务 | CVE | 原生 | 企业版 | 原生 |
| **Grype** | 开源 | CVE | CLI | 免费 | - |
| **Falco** | 开源 | 运行时 | DaemonSet | 免费 | - |

## 扫描类型

| 扫描类型 | 描述 | 工具支持 | 时机 |
|---------|------|---------|------|
| **CVE扫描** | 已知漏洞检测 | Trivy/Clair | CI/运行时 |
| **配置扫描** | Dockerfile/K8S配置 | Trivy/Checkov | CI |
| **Secret检测** | 泄露凭证检测 | Trivy/GitLeaks | CI |
| **许可证扫描** | 开源许可证 | Trivy | CI |
| **运行时扫描** | 运行时行为 | Falco | 运行时 |
| **SBOM生成** | 软件物料清单 | Trivy/Syft | CI |

## Trivy使用

```bash
# 镜像扫描
trivy image nginx:latest
trivy image --severity HIGH,CRITICAL nginx:latest
trivy image --format json -o result.json nginx:latest

# K8S集群扫描
trivy k8s --report summary cluster
trivy k8s --report all --format json cluster

# 配置扫描
trivy config ./manifests
trivy config --severity HIGH ./Dockerfile

# SBOM生成
trivy image --format spdx nginx:latest > sbom.spdx
trivy image --format cyclonedx nginx:latest > sbom.json
```

## Trivy Operator

```yaml
# Trivy Operator安装
# helm install trivy-operator aquasecurity/trivy-operator -n trivy-system --create-namespace

# 查看漏洞报告
kubectl get vulnerabilityreports -A
kubectl describe vulnerabilityreport <name>

# 查看配置审计报告
kubectl get configauditreports -A
kubectl describe configauditreport <name>

# VulnerabilityReport示例
apiVersion: aquasecurity.github.io/v1alpha1
kind: VulnerabilityReport
metadata:
  name: pod-nginx-nginx
spec:
  report:
    artifact:
      repository: nginx
      tag: latest
    summary:
      criticalCount: 2
      highCount: 15
      mediumCount: 30
      lowCount: 10
    vulnerabilities:
    - vulnerabilityID: CVE-2023-xxxxx
      severity: CRITICAL
      title: "..."
      installedVersion: "1.0.0"
      fixedVersion: "1.0.1"
```

## CI/CD集成

```yaml
# GitLab CI示例
stages:
  - build
  - scan
  - deploy

build:
  stage: build
  script:
    - docker build -t $IMAGE_NAME:$CI_COMMIT_SHA .
    - docker push $IMAGE_NAME:$CI_COMMIT_SHA

scan:
  stage: scan
  image: aquasec/trivy:latest
  script:
    - trivy image --exit-code 1 --severity HIGH,CRITICAL $IMAGE_NAME:$CI_COMMIT_SHA
  allow_failure: false

deploy:
  stage: deploy
  script:
    - kubectl set image deployment/app app=$IMAGE_NAME:$CI_COMMIT_SHA
  only:
    - main
---
# GitHub Actions示例
name: Security Scan

on: [push, pull_request]

jobs:
  trivy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Build image
      run: docker build -t myapp:${{ github.sha }} .
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'myapp:${{ github.sha }}'
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL,HIGH'
        exit-code: '1'
    
    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'
```

## 漏洞等级处理

| 等级 | CVSS分数 | 处理时限 | 处理方式 |
|-----|---------|---------|---------|
| **Critical** | 9.0-10.0 | 24小时 | 立即修复或下线 |
| **High** | 7.0-8.9 | 7天 | 优先修复 |
| **Medium** | 4.0-6.9 | 30天 | 计划修复 |
| **Low** | 0.1-3.9 | 90天 | 评估后修复 |

## 准入控制(镜像策略)

```yaml
# Kyverno策略 - 禁止使用latest标签
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: enforce
  rules:
  - name: require-image-tag
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "使用latest标签的镜像不允许"
      pattern:
        spec:
          containers:
          - image: "!*:latest"
---
# Kyverno策略 - 只允许可信仓库
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: allowed-registries
spec:
  validationFailureAction: enforce
  rules:
  - name: validate-registries
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "镜像必须来自可信仓库"
      pattern:
        spec:
          containers:
          - image: "registry.cn-*.aliyuncs.com/*"
---
# OPA Gatekeeper约束
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRepos
metadata:
  name: allowed-repos
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
  parameters:
    repos:
    - "registry.cn-hangzhou.aliyuncs.com/"
    - "registry.k8s.io/"
```

## 镜像签名验证

```bash
# Cosign签名
cosign sign --key cosign.key registry.example.com/app:v1.0.0

# Cosign验证
cosign verify --key cosign.pub registry.example.com/app:v1.0.0
```

```yaml
# Sigstore Policy Controller
apiVersion: policy.sigstore.dev/v1alpha1
kind: ClusterImagePolicy
metadata:
  name: image-policy
spec:
  images:
  - glob: "registry.example.com/**"
  authorities:
  - keyless:
      url: https://fulcio.sigstore.dev
      identities:
      - issuer: https://accounts.google.com
        subject: user@example.com
```

## ACR安全扫描

```bash
# ACR漏洞扫描(企业版)
# 自动扫描已开启，查看扫描结果
aliyun cr GetRepoTagScanStatus --RepoNamespace <ns> --RepoName <name> --Tag <tag>

# 查看扫描结果
aliyun cr GetRepoTagScanSummary --RepoNamespace <ns> --RepoName <name> --Tag <tag>
```

| 功能 | ACR企业版 | 说明 |
|-----|----------|------|
| **自动扫描** | ✓ | 推送时自动扫描 |
| **定时扫描** | ✓ | 周期性重新扫描 |
| **漏洞报告** | ✓ | 详细漏洞信息 |
| **阻止拉取** | ✓ | 高危镜像阻止 |
| **签名验证** | ✓ | 内容信任 |

## 安全扫描最佳实践

| 实践 | 说明 | 优先级 |
|-----|------|-------|
| **CI集成** | 构建时扫描 | P0 |
| **阻止高危** | Critical/High不允许部署 | P0 |
| **基础镜像管理** | 使用可信基础镜像 | P0 |
| **定期重扫** | 发现新漏洞 | P1 |
| **运行时扫描** | 部署Trivy Operator | P1 |
| **SBOM管理** | 生成并存储SBOM | P2 |

---

**扫描原则**: 左移安全，自动化扫描，阻止高危
