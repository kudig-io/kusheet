# Docker 安全最佳实践

> **适用版本**: Docker 20.10+ / Docker 24.0+ / Docker 25.0+ | **最后更新**: 2026-01

---

## 目录

- [容器安全基础](#容器安全基础)
- [镜像安全](#镜像安全)
- [容器运行时安全](#容器运行时安全)
- [Linux 安全机制](#linux-安全机制)
- [Docker Daemon 安全](#docker-daemon-安全)
- [安全检查清单](#安全检查清单)

---

## 容器安全基础

### 容器隔离机制

| 层次 | 机制 | 作用 |
|:---|:---|:---|
| **应用层** | 代码安全、依赖安全 | 防止应用漏洞 |
| **运行时层** | 非 root、只读 FS、能力删除 | 限制容器权限 |
| **内核层** | Namespaces、Cgroups、Seccomp | 隔离与限制 |
| **主机层** | SELinux/AppArmor、审计 | 强制访问控制 |

### 攻击面与防护

| 攻击面 | 风险 | 防护措施 |
|:---|:---|:---|
| **镜像漏洞** | 已知 CVE | 镜像扫描、可信源 |
| **权限提升** | root 逃逸 | 非 root、删除能力 |
| **容器逃逸** | 挂载敏感路径 | 只读 FS、禁止特权 |
| **资源耗尽** | DoS 攻击 | 资源限制 |

---

## 镜像安全

### 可信基础镜像

| 镜像类型 | 安全性 | 推荐场景 |
|:---|:---|:---|
| **Distroless** | 最高 | 生产环境 |
| **Alpine** | 高 (精简) | 减少攻击面 |
| **官方镜像** | 高 | 通用场景 |

### 安全 Dockerfile

```dockerfile
FROM python:3.12-slim-bookworm AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

FROM gcr.io/distroless/python3-debian12
COPY --from=builder /root/.local /root/.local
COPY --chown=nonroot:nonroot app.py .
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["python", "app.py"]
```

### 镜像扫描

```bash
# Trivy 扫描
trivy image --severity HIGH,CRITICAL myapp:latest

# Grype 扫描
grype myapp:latest
```

---

## 容器运行时安全

### 非 root 用户

```bash
docker run --user 1000:1000 myapp
```

### 只读文件系统

```bash
docker run --read-only \
  --tmpfs /tmp:size=100m \
  --tmpfs /run:size=10m \
  myapp
```

### 能力管理

```bash
docker run \
  --cap-drop ALL \
  --cap-add NET_BIND_SERVICE \
  myapp
```

| 能力 | 风险 | 建议 |
|:---|:---:|:---|
| `CAP_SYS_ADMIN` | 极高 | 禁止 |
| `CAP_NET_ADMIN` | 高 | 按需 |
| `CAP_NET_BIND_SERVICE` | 低 | 允许 |

### 禁止权限提升

```bash
docker run --security-opt no-new-privileges:true myapp
```

### 资源限制

```bash
docker run \
  --memory 512m \
  --cpus 1.0 \
  --pids-limit 100 \
  myapp
```

---

## Linux 安全机制

### Seccomp

```bash
docker run --security-opt seccomp=./profile.json myapp
```

### AppArmor

```bash
docker run --security-opt apparmor=myprofile myapp
```

---

## Docker Daemon 安全

### 安全配置

```json
{
  "icc": false,
  "live-restore": true,
  "no-new-privileges": true,
  "userns-remap": "default"
}
```

### Rootless Docker

```bash
curl -fsSL https://get.docker.com/rootless | sh
```

---

## 安全检查清单

### 镜像安全

| 项目 | 检查内容 |
|:---|:---|
| ☐ 特定标签 | 避免 :latest |
| ☐ 可信来源 | 官方或已验证 |
| ☐ 漏洞扫描 | 无高危漏洞 |
| ☐ 非 root | 定义 USER |

### 运行时安全

| 项目 | 检查内容 |
|:---|:---|
| ☐ 非特权 | privileged=false |
| ☐ 非 root | user != 0 |
| ☐ 只读 FS | read_only=true |
| ☐ 能力限制 | cap_drop ALL |

### Docker Bench

```bash
docker run --rm --net host --pid host \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  docker/docker-bench-security
```

---

## 相关文档

- [200-docker-architecture-overview](./200-docker-architecture-overview.md)
- [217-linux-container-fundamentals](./217-linux-container-fundamentals.md)
