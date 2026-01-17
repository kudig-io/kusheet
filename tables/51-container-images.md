# 表格51: 容器镜像管理

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/containers/images](https://kubernetes.io/docs/concepts/containers/images/)

## 镜像命名规范

| 组成部分 | 示例 | 说明 |
|---------|-----|------|
| Registry | docker.io, registry.cn-hangzhou.aliyuncs.com | 镜像仓库地址 |
| Namespace | library, myproject | 命名空间/项目 |
| Repository | nginx, myapp | 镜像名称 |
| Tag | latest, v1.0.0, sha256:abc123 | 版本标签 |
| 完整格式 | registry/namespace/repo:tag | 完整镜像地址 |

## 镜像拉取策略

| 策略 | 说明 | 适用场景 |
|-----|------|---------|
| Always | 始终拉取 | 使用latest标签 |
| IfNotPresent | 本地不存在时拉取 | 使用固定版本标签 |
| Never | 从不拉取 | 本地预加载镜像 |

## 镜像拉取Secret配置

```yaml
# 创建Docker Registry Secret
kubectl create secret docker-registry regcred \
  --docker-server=registry.cn-hangzhou.aliyuncs.com \
  --docker-username=user \
  --docker-password=pass

# Pod中使用
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  imagePullSecrets:
  - name: regcred
  containers:
  - name: app
    image: registry.cn-hangzhou.aliyuncs.com/myns/myapp:v1.0

# ServiceAccount关联(推荐)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp-sa
imagePullSecrets:
- name: regcred
```

## 多架构镜像

| 架构 | 平台标识 | 说明 |
|-----|---------|------|
| AMD64 | linux/amd64 | x86_64服务器 |
| ARM64 | linux/arm64 | ARM服务器/Mac M系列 |
| ARMv7 | linux/arm/v7 | 树莓派等 |
| s390x | linux/s390x | IBM大型机 |

```bash
# 构建多架构镜像
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 \
  -t myregistry/myapp:v1.0 --push .
```

## 镜像安全扫描工具

| 工具 | 类型 | 集成方式 | 特点 |
|-----|-----|---------|------|
| Trivy | 开源 | CLI/CI | 全面、快速 |
| Grype | 开源 | CLI/CI | Anchore出品 |
| Clair | 开源 | 服务端 | 静态分析 |
| ACR扫描 | 商业 | 托管服务 | ACK原生集成 |
| Snyk | 商业 | SaaS | 开发者友好 |
| Sysdig | 商业 | 运行时 | 运行时保护 |

## Trivy扫描命令

```bash
# 扫描镜像漏洞
trivy image myapp:v1.0

# 仅显示高危漏洞
trivy image --severity HIGH,CRITICAL myapp:v1.0

# 输出JSON格式
trivy image -f json -o results.json myapp:v1.0

# 扫描并设置退出码(CI使用)
trivy image --exit-code 1 --severity CRITICAL myapp:v1.0

# 扫描配置问题
trivy config ./kubernetes/

# 扫描文件系统
trivy fs --security-checks vuln,config ./
```

## 镜像签名与验证

| 工具 | 标准 | 说明 |
|-----|------|------|
| cosign | Sigstore | 主流签名工具 |
| Notary v2 | OCI | Docker Content Trust |
| GPG | - | 传统签名 |

```bash
# cosign签名
cosign sign --key cosign.key myregistry/myapp:v1.0

# cosign验证
cosign verify --key cosign.pub myregistry/myapp:v1.0

# Keyless签名(OIDC)
cosign sign myregistry/myapp:v1.0

# 附加SBOM
cosign attach sbom --sbom sbom.spdx myregistry/myapp:v1.0
```

## 镜像最佳实践

| 实践 | 说明 |
|-----|------|
| 使用固定标签 | 避免使用latest |
| 最小基础镜像 | distroless/alpine |
| 多阶段构建 | 减少镜像大小 |
| 非root用户 | USER指令 |
| 只读文件系统 | 安全加固 |
| 扫描漏洞 | CI/CD集成扫描 |
| 签名验证 | 确保镜像来源 |
| SBOM生成 | 软件物料清单 |

## 高效Dockerfile示例

```dockerfile
# 多阶段构建
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /app/server

# 最小运行时镜像
FROM gcr.io/distroless/static:nonroot
COPY --from=builder /app/server /server
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
```

## ACR(阿里云容器镜像服务)功能

| 功能 | 企业版 | 个人版 |
|-----|-------|-------|
| 镜像托管 | ✅ | ✅ |
| 漏洞扫描 | ✅ | ✅(基础) |
| 镜像签名 | ✅ | ❌ |
| 地域复制 | ✅ | ❌ |
| P2P加速 | ✅ | ❌ |
| Helm Chart | ✅ | ✅ |
| 构建服务 | ✅ | ✅ |
| 清理策略 | ✅ | ✅ |

## 镜像分发加速

| 方案 | 说明 | 适用场景 |
|-----|------|---------|
| 镜像预热 | 提前拉取到节点 | 大规模部署 |
| P2P分发 | Dragonfly/Kraken | 大镜像分发 |
| 镜像缓存 | Harbor/ACR代理 | 跨地域访问 |
| 懒加载 | Stargz/Nydus | 快速启动 |

```yaml
# Dragonfly配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: dragonfly-config
data:
  dfget.yaml: |
    proxy:
      registryMirror:
        url: https://registry-vpc.cn-hangzhou.aliyuncs.com
```

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| v1.25 | CRI v1 API稳定 |
| v1.27 | 镜像Volume支持改进 |
| v1.29 | 镜像拉取进度报告 |
| v1.31 | OCI镜像布局支持 |
