# Docker 镜像管理深度解析

> **适用版本**: Docker 20.10+ / Docker 24.0+ / Docker 25.0+ | **最后更新**: 2026-01

---

## 目录

- [镜像分层原理](#镜像分层原理)
- [Dockerfile 完全参考](#dockerfile-完全参考)
- [多阶段构建](#多阶段构建)
- [BuildKit 高级特性](#buildkit-高级特性)
- [镜像仓库管理](#镜像仓库管理)
- [镜像安全扫描](#镜像安全扫描)
- [镜像签名与验证](#镜像签名与验证)
- [镜像优化最佳实践](#镜像优化最佳实践)

---

## 镜像分层原理

### 镜像层级结构

```
┌─────────────────────────────────────────────────────────────────┐
│                    容器层 (Container Layer)                      │
│                    可读写层 (R/W)                                 │
├─────────────────────────────────────────────────────────────────┤
│  镜像层 N    │  COPY . /app                    │  Layer (R/O)   │
├─────────────────────────────────────────────────────────────────┤
│  镜像层 N-1  │  RUN npm install                │  Layer (R/O)   │
├─────────────────────────────────────────────────────────────────┤
│  镜像层 N-2  │  RUN apt-get install nodejs     │  Layer (R/O)   │
├─────────────────────────────────────────────────────────────────┤
│  ...         │  ...                            │  Layer (R/O)   │
├─────────────────────────────────────────────────────────────────┤
│  基础镜像层  │  FROM ubuntu:22.04              │  Layer (R/O)   │
└─────────────────────────────────────────────────────────────────┘
```

### UnionFS 联合文件系统

| 存储驱动 | 文件系统要求 | 特点 | 推荐场景 |
|:---|:---|:---|:---|
| **overlay2** | xfs/ext4 | 默认驱动、高性能 | 生产环境首选 |
| **fuse-overlayfs** | 任意 | Rootless 模式 | Rootless Docker/Podman |
| **btrfs** | btrfs | 原生快照支持 | 大量容器场景 |
| **zfs** | zfs | 高级存储功能 | 需要 ZFS 特性 |
| **vfs** | 任意 | 无 CoW，性能差 | 测试/特殊场景 |

### 镜像层内容寻址

```bash
# 镜像 manifest
docker manifest inspect nginx:1.25 --verbose

# 镜像层 digest
docker image inspect nginx:1.25 --format '{{range .RootFS.Layers}}{{.}}{{println}}{{end}}'

# 层内容位置
ls /var/lib/docker/overlay2/
```

### OCI 镜像结构

| 组件 | 文件 | 说明 |
|:---|:---|:---|
| **Index** | index.json | 多架构索引 |
| **Manifest** | manifest.json | 镜像层列表 |
| **Config** | config.json | 镜像配置 (ENV, CMD等) |
| **Layers** | layer.tar | 文件系统层 (gzip压缩) |
| **Blobs** | sha256:xxx | 内容寻址存储 |

---

## Dockerfile 完全参考

### 指令参考表

| 指令 | 语法 | 说明 | 示例 |
|:---|:---|:---|:---|
| **FROM** | `FROM image:tag [AS name]` | 基础镜像 | `FROM golang:1.22 AS builder` |
| **RUN** | `RUN command` | 执行命令 | `RUN apt-get update && apt-get install -y curl` |
| **CMD** | `CMD ["executable","param"]` | 默认命令 | `CMD ["nginx", "-g", "daemon off;"]` |
| **ENTRYPOINT** | `ENTRYPOINT ["executable"]` | 入口点 | `ENTRYPOINT ["/entrypoint.sh"]` |
| **COPY** | `COPY [--chown=user:group] src dest` | 复制文件 | `COPY --chown=1000:1000 . /app` |
| **ADD** | `ADD src dest` | 复制(支持URL/解压) | `ADD app.tar.gz /app` |
| **WORKDIR** | `WORKDIR /path` | 工作目录 | `WORKDIR /app` |
| **ENV** | `ENV key=value` | 环境变量 | `ENV NODE_ENV=production` |
| **ARG** | `ARG name[=default]` | 构建参数 | `ARG VERSION=1.0` |
| **EXPOSE** | `EXPOSE port` | 声明端口 | `EXPOSE 8080/tcp` |
| **VOLUME** | `VOLUME ["/data"]` | 声明卷 | `VOLUME ["/var/lib/mysql"]` |
| **USER** | `USER user[:group]` | 运行用户 | `USER 1000:1000` |
| **LABEL** | `LABEL key="value"` | 元数据标签 | `LABEL version="1.0"` |
| **HEALTHCHECK** | `HEALTHCHECK [options] CMD command` | 健康检查 | 见下方示例 |
| **SHELL** | `SHELL ["executable", "parameters"]` | 默认 Shell | `SHELL ["/bin/bash", "-c"]` |
| **STOPSIGNAL** | `STOPSIGNAL signal` | 停止信号 | `STOPSIGNAL SIGTERM` |
| **ONBUILD** | `ONBUILD instruction` | 延迟执行 | `ONBUILD COPY . /app` |

### HEALTHCHECK 配置

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
```

| 参数 | 默认值 | 说明 |
|:---|:---|:---|
| `--interval` | 30s | 检查间隔 |
| `--timeout` | 30s | 超时时间 |
| `--start-period` | 0s | 启动宽限期 |
| `--retries` | 3 | 重试次数 |
| `--start-interval` (1.44+) | 5s | 启动期间检查间隔 |

### CMD vs ENTRYPOINT

| 场景 | CMD | ENTRYPOINT | 效果 |
|:---|:---|:---|:---|
| 只有 CMD | `["nginx"]` | - | 可被 docker run 参数覆盖 |
| 只有 ENTRYPOINT | - | `["nginx"]` | docker run 参数追加到后面 |
| 两者配合 | `["-g", "daemon off;"]` | `["nginx"]` | CMD 作为 ENTRYPOINT 的默认参数 |

```dockerfile
# 推荐模式：ENTRYPOINT + CMD
ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]

# 使用示例
docker run nginx               # 执行: nginx -g daemon off;
docker run nginx -c /etc/nginx.conf  # 执行: nginx -c /etc/nginx.conf
```

### Shell 形式 vs Exec 形式

| 形式 | 语法 | PID 1 | 信号处理 | 变量展开 |
|:---|:---|:---|:---|:---|
| **Shell** | `RUN apt-get install` | /bin/sh -c | 不传递 | 支持 |
| **Exec** | `RUN ["apt-get", "install"]` | 直接执行 | 正常传递 | 不支持 |

```dockerfile
# Shell 形式 - 支持变量展开，但信号问题
CMD echo "Hello $USER"    # 实际执行: /bin/sh -c 'echo Hello $USER'

# Exec 形式 - 推荐，正确接收信号
CMD ["echo", "Hello"]     # 直接执行: echo Hello
```

---

## 多阶段构建

### 基本多阶段构建

```dockerfile
# ========== 构建阶段 ==========
FROM golang:1.22-alpine AS builder

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/server ./cmd/server

# ========== 运行阶段 ==========
FROM alpine:3.19 AS runtime

RUN apk add --no-cache ca-certificates tzdata && \
    adduser -D -u 1000 appuser

COPY --from=builder /app/server /app/server
COPY --from=builder /src/configs /app/configs

USER appuser
WORKDIR /app
EXPOSE 8080
ENTRYPOINT ["/app/server"]
```

### 高级多阶段模式

```dockerfile
# ========== 基础依赖 ==========
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# ========== 开发依赖 ==========
FROM deps AS dev-deps
RUN npm ci

# ========== 构建 ==========
FROM dev-deps AS builder
COPY . .
RUN npm run build

# ========== 测试 ==========
FROM dev-deps AS tester
COPY . .
RUN npm run test
RUN npm run lint

# ========== 生产镜像 ==========
FROM node:20-alpine AS production
WORKDIR /app
ENV NODE_ENV=production

# 仅复制必要文件
COPY --from=deps /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY package.json ./

USER node
EXPOSE 3000
CMD ["node", "dist/main.js"]
```

### 跨阶段复制

```dockerfile
# 从指定阶段复制
COPY --from=builder /app/binary /usr/local/bin/

# 从外部镜像复制
COPY --from=nginx:alpine /etc/nginx/nginx.conf /etc/nginx/nginx.conf

# 从 scratch 构建最小镜像
FROM scratch
COPY --from=builder /app/server /server
COPY --from=alpine:3.19 /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
ENTRYPOINT ["/server"]
```

---

## BuildKit 高级特性

### 启用 BuildKit

```bash
# 方式1: 环境变量
export DOCKER_BUILDKIT=1
docker build .

# 方式2: docker buildx (推荐)
docker buildx build .

# 方式3: daemon.json 配置
{
  "features": {
    "buildkit": true
  }
}
```

### BuildKit 缓存挂载

```dockerfile
# 包管理器缓存
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y curl

# Go 模块缓存
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o /app/server .

# npm 缓存
RUN --mount=type=cache,target=/root/.npm \
    npm ci

# pip 缓存
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

### BuildKit Secret 挂载

```dockerfile
# 使用 secret
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci

# 使用 SSH
RUN --mount=type=ssh \
    git clone git@github.com:org/private-repo.git
```

```bash
# 构建时传入 secret
docker buildx build --secret id=npmrc,src=$HOME/.npmrc .

# 使用 SSH agent
docker buildx build --ssh default .
```

### BuildKit 并行构建

```dockerfile
# syntax=docker/dockerfile:1.6

# 并行构建多个组件
FROM golang:1.22 AS builder-api
COPY api/ /src/
RUN go build -o /api ./...

FROM golang:1.22 AS builder-worker
COPY worker/ /src/
RUN go build -o /worker ./...

FROM golang:1.22 AS builder-cli
COPY cli/ /src/
RUN go build -o /cli ./...

# 合并到最终镜像
FROM alpine:3.19
COPY --from=builder-api /api /usr/local/bin/
COPY --from=builder-worker /worker /usr/local/bin/
COPY --from=builder-cli /cli /usr/local/bin/
```

### 多平台构建

```bash
# 创建多平台构建器
docker buildx create --name multiarch --driver docker-container --use

# 构建多架构镜像并推送
docker buildx build \
  --platform linux/amd64,linux/arm64,linux/arm/v7 \
  --tag myrepo/app:v1.0 \
  --push .

# 仅针对特定平台构建
docker buildx build --platform linux/arm64 -t app:arm64 --load .
```

### 构建进度输出

```bash
# 纯文本输出 (CI 环境)
docker buildx build --progress=plain .

# TTY 输出 (终端)
docker buildx build --progress=tty .

# 自动检测
docker buildx build --progress=auto .
```

---

## 镜像仓库管理

### 常用镜像仓库

| 仓库 | 类型 | 特点 | 地址 |
|:---|:---|:---|:---|
| **Docker Hub** | 公共 | 官方、镜像最多 | docker.io |
| **GitHub Container Registry** | 公共/私有 | GitHub 集成 | ghcr.io |
| **Google Container Registry** | 公共 | K8s 官方镜像 | gcr.io / registry.k8s.io |
| **Amazon ECR** | 私有 | AWS 集成 | xxx.dkr.ecr.region.amazonaws.com |
| **Alibaba ACR** | 公共/私有 | 阿里云集成 | registry.cn-xxx.aliyuncs.com |
| **Harbor** | 私有 | 企业级、功能丰富 | 自建 |
| **Nexus** | 私有 | 多格式仓库 | 自建 |

### Harbor 部署

```bash
# 下载Harbor
wget https://github.com/goharbor/harbor/releases/download/v2.10.0/harbor-offline-installer-v2.10.0.tgz
tar xzf harbor-offline-installer-v2.10.0.tgz
cd harbor

# 配置
cp harbor.yml.tmpl harbor.yml
vim harbor.yml
```

```yaml
# harbor.yml 关键配置
hostname: registry.example.com
http:
  port: 80
https:
  port: 443
  certificate: /your/certificate/path
  private_key: /your/private/key/path
harbor_admin_password: Harbor12345
database:
  password: root123
  max_idle_conns: 100
  max_open_conns: 900
data_volume: /data
storage_service:
  s3:
    accesskey: AKIAXXXXXX
    secretkey: xxxxx
    region: us-east-1
    bucket: harbor
trivy:
  ignore_unfixed: false
  security_check: vuln
  insecure: false
```

```bash
# 安装
./install.sh --with-trivy --with-notary
```

### 镜像操作命令

```bash
# 登录仓库
docker login registry.example.com
docker login --username user --password-stdin <<< "password"

# 标记镜像
docker tag myapp:latest registry.example.com/project/myapp:v1.0

# 推送镜像
docker push registry.example.com/project/myapp:v1.0

# 拉取镜像
docker pull registry.example.com/project/myapp:v1.0

# 查看远程标签
docker manifest inspect registry.example.com/project/myapp:v1.0

# 删除远程镜像 (需要仓库支持)
# Harbor: 通过 API 或 Web UI
# ECR: aws ecr batch-delete-image
```

### 镜像仓库认证配置

```bash
# ~/.docker/config.json
{
  "auths": {
    "registry.example.com": {
      "auth": "base64(username:password)"
    },
    "https://index.docker.io/v1/": {
      "auth": "base64(username:password)"
    }
  },
  "credHelpers": {
    "gcr.io": "gcloud",
    "asia.gcr.io": "gcloud",
    "xxx.dkr.ecr.us-east-1.amazonaws.com": "ecr-login"
  }
}
```

### Kubernetes 镜像拉取凭据

```bash
# 创建 Secret
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=password \
  --docker-email=user@example.com

# 在 Pod 中使用
spec:
  imagePullSecrets:
    - name: regcred
  containers:
    - name: app
      image: registry.example.com/project/app:v1
```

---

## 镜像安全扫描

### 扫描工具对比

| 工具 | 类型 | 漏洞库 | 集成 |
|:---|:---|:---|:---|
| **Trivy** | 开源 | NVD, GitHub Advisory | CI/CD, Harbor, K8s |
| **Grype** | 开源 | NVD, GitHub, RedHat | CI/CD |
| **Clair** | 开源 | NVD, 多来源 | Harbor, Quay |
| **Snyk** | 商业 | 自有 | CI/CD, IDE |
| **Docker Scout** | 商业 | 多来源 | Docker Desktop |

### Trivy 使用

```bash
# 安装 Trivy
brew install aquasecurity/trivy/trivy  # macOS
apt-get install trivy                   # Debian/Ubuntu

# 扫描镜像
trivy image nginx:1.25

# 只显示严重和高危漏洞
trivy image --severity CRITICAL,HIGH nginx:1.25

# JSON 输出
trivy image --format json --output result.json nginx:1.25

# 扫描 Dockerfile
trivy config --policy ./policies Dockerfile

# CI 模式 (有漏洞则失败)
trivy image --exit-code 1 --severity CRITICAL myimage:latest

# 忽略未修复的漏洞
trivy image --ignore-unfixed nginx:1.25

# 扫描本地镜像
trivy image --input image.tar

# 扫描文件系统
trivy fs /path/to/project

# 扫描 SBOM
trivy sbom --artifact-type oci-image nginx:1.25
```

### Trivy 配置文件

```yaml
# trivy.yaml
severity:
  - CRITICAL
  - HIGH
ignore-unfixed: true
vulnerability:
  type:
    - os
    - library
format: table
exit-code: 1
cache:
  backend: fs
  ttl: 24h
db:
  download-java-db: false
```

### CI/CD 集成示例

```yaml
# GitHub Actions
name: Security Scan
on: [push, pull_request]
jobs:
  trivy:
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
          exit-code: '1'
      
      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
```

---

## 镜像签名与验证

### Docker Content Trust (DCT)

```bash
# 启用 DCT
export DOCKER_CONTENT_TRUST=1

# 签名并推送
docker push myregistry/myimage:v1  # 会自动签名

# 拉取时验证
docker pull myregistry/myimage:v1  # 自动验证签名

# 查看签名信息
docker trust inspect myregistry/myimage:v1

# 管理签名者
docker trust signer add --key cert.pem alice myregistry/myimage
docker trust signer remove alice myregistry/myimage

# 撤销签名
docker trust revoke myregistry/myimage:v1
```

### Cosign (Sigstore)

```bash
# 安装 cosign
brew install cosign  # macOS
go install github.com/sigstore/cosign/v2/cmd/cosign@latest

# 生成密钥对
cosign generate-key-pair

# 签名镜像
cosign sign --key cosign.key myregistry/myimage:v1

# 无密钥签名 (OIDC)
cosign sign myregistry/myimage@sha256:xxx

# 验证签名
cosign verify --key cosign.pub myregistry/myimage:v1

# 使用证书签名
cosign sign --key cosign.key --certificate cert.pem myregistry/myimage:v1

# 附加 SBOM
cosign attach sbom --sbom sbom.spdx myregistry/myimage:v1

# 验证 SBOM
cosign verify-attestation --key cosign.pub myregistry/myimage:v1
```

### Kubernetes Admission 验证

```yaml
# Kyverno Policy - 强制签名验证
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: enforce
  background: false
  rules:
    - name: verify-signature
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "myregistry/*"
          attestors:
            - entries:
                - keys:
                    publicKeys: |
                      -----BEGIN PUBLIC KEY-----
                      MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
                      -----END PUBLIC KEY-----
```

---

## 镜像优化最佳实践

### 减小镜像体积

| 技术 | 节省比例 | 说明 |
|:---|:---|:---|
| **使用 Alpine 基础镜像** | 60-80% | 5MB vs 100MB+ |
| **多阶段构建** | 50-90% | 仅保留运行时文件 |
| **从 scratch 构建** | 95%+ | 仅包含二进制 (静态编译) |
| **使用 distroless** | 70-90% | Google 维护的最小镜像 |
| **删除包管理器缓存** | 10-30% | apt clean, rm -rf /var/lib/apt |
| **合并 RUN 指令** | 5-15% | 减少层数 |
| **使用 .dockerignore** | 可变 | 排除不必要文件 |
| **压缩二进制** | 20-50% | UPX 压缩 |

### 基础镜像选择

| 镜像 | 大小 | 特点 | 适用场景 |
|:---|:---|:---|:---|
| **scratch** | 0 | 空白镜像 | 静态编译 Go/Rust |
| **alpine** | ~5MB | musl libc, apk | 大多数场景 |
| **distroless/static** | ~2MB | 无 shell/包管理 | 静态二进制 |
| **distroless/base** | ~20MB | glibc, ca-certs | 动态链接程序 |
| **debian-slim** | ~75MB | glibc, apt | 需要 apt 的场景 |
| **ubuntu** | ~78MB | 完整 Ubuntu | 开发/调试 |

### .dockerignore 示例

```dockerfile
# Git
.git
.gitignore

# 构建产物
node_modules
dist
build
*.pyc
__pycache__

# IDE
.idea
.vscode
*.swp

# 测试
test
tests
coverage
.coverage

# 文档
README.md
docs

# Docker
Dockerfile*
docker-compose*
.docker

# 敏感文件
.env
.env.*
*.pem
*.key
secrets.yaml
```

### 最佳实践 Dockerfile 示例

```dockerfile
# syntax=docker/dockerfile:1.6

# ========== 基础镜像选择 ==========
FROM python:3.12-slim-bookworm AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# ========== 构建阶段 ==========
FROM base AS builder

WORKDIR /app

# 使用 BuildKit 缓存
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=bind,source=requirements.txt,target=requirements.txt \
    pip install --target=/app/deps -r requirements.txt

# ========== 运行阶段 ==========
FROM base AS runtime

# 创建非 root 用户
RUN addgroup --system --gid 1000 appgroup && \
    adduser --system --uid 1000 --gid 1000 --no-create-home appuser

WORKDIR /app

# 复制依赖
COPY --from=builder /app/deps /app/deps
ENV PYTHONPATH=/app/deps

# 复制应用代码
COPY --chown=appuser:appgroup src/ /app/src/

# 安全配置
USER appuser
EXPOSE 8000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# 元数据
LABEL org.opencontainers.image.title="My Application" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.authors="team@example.com"

ENTRYPOINT ["python", "-m", "src.main"]
```

### 镜像分析工具

```bash
# Dive - 分析镜像层
dive nginx:1.25
# 显示每层内容变化，识别大文件

# Docker 官方工具
docker image inspect nginx:1.25
docker history --no-trunc nginx:1.25

# Slim - 自动优化镜像
slim build --target nginx:1.25 --tag nginx:slim
# 自动分析移除不必要文件
```

---

## 相关文档

- [200-docker-architecture-overview](./200-docker-architecture-overview.md) - Docker 架构概述
- [202-docker-container-lifecycle](./202-docker-container-lifecycle.md) - 容器生命周期
- [206-docker-security-best-practices](./206-docker-security-best-practices.md) - Docker 安全
- [128-image-build-tools](./128-image-build-tools.md) - 镜像构建工具
- [86-image-security-scanning](./86-image-security-scanning.md) - K8s 镜像安全
