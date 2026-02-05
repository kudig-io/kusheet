# Docker 自动化运维与CI/CD集成

> **适用版本**: Docker 20.10+ / Docker 24.0+ / Docker 25.0+ | **最后更新**: 2026-01
> 
> **生产环境运维专家注**: 本章节深入探讨 Docker 环境下的自动化运维体系、CI/CD 流水线设计、基础设施即代码实践以及 DevOps 工具链集成等企业级自动化解决方案。

---

## 目录

- [自动化运维体系架构](#自动化运维体系架构)
- [基础设施即代码 (IaC)](#基础设施即代码-iac)
- [CI/CD 流水线设计](#cicd-流水线设计)
- [镜像构建自动化](#镜像构建自动化)
- [容器部署自动化](#容器部署自动化)
- [配置管理与密钥管理](#配置管理与密钥管理)
- [监控告警自动化](#监控告警自动化)
- [灾备与回滚机制](#灾备与回滚机制)

---

## 自动化运维体系架构

### 企业级自动化运维全景图

```
┌─────────────────────────────────────────────────────────────────────┐
│                           开发阶段                                  │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│  │  代码    │  │  单元测试 │  │  静态分析 │  │  安全扫描 │  │  构建   │ │
│  │  提交    │─▶│          │─▶│          │─▶│          │─▶│  镜像   │ │
│  └─────────┘  └──────────┘  └──────────┘  └──────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           测试环境                                  │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│  │  部署    │  │  集成测试 │  │  性能测试 │  │  安全测试 │  │  验证   │ │
│  │  到测试  │─▶│          │─▶│          │─▶│          │─▶│  签名   │ │
│  └─────────┘  └──────────┘  └──────────┘  └──────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           预发布环境                                │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│  │  灰度部署│  │  用户验收 │  │  回归测试 │  │  最终验证 │  │  批准   │ │
│  │         │─▶│  测试     │─▶│          │─▶│          │─▶│  发布   │ │
│  └─────────┘  └──────────┘  └──────────┘  └──────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           生产环境                                  │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│  │  蓝绿部署│  │  监控告警 │  │  自动扩容 │  │  故障自愈 │  │  运维   │ │
│  │         │─▶│          │─▶│          │─▶│          │─▶│  管理   │ │
│  └─────────┘  └──────────┘  └──────────┘  └──────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### 自动化成熟度模型

#### Level 1: 手动操作
- 手工构建镜像
- 手工部署容器
- 手工配置环境

#### Level 2: 脚本化
- Shell 脚本自动化
- 基础的 CI/CD 流水线
- 简单的配置管理

#### Level 3: 平台化
- 完整的 CI/CD 平台
- 基础设施即代码
- 自动化测试覆盖

#### Level 4: 智能化 (推荐)
- AI 辅助决策
- 自适应部署策略
- 预测性运维
- 自主故障修复

## 基础设施即代码 (IaC)

### Docker Compose 生产级配置

#### 多环境配置管理
```yaml
# docker-compose.base.yml - 基础配置
version: '3.8'
services:
  app:
    image: ${IMAGE_NAME}:${IMAGE_TAG}
    environment:
      - ENVIRONMENT=${ENVIRONMENT}
      - LOG_LEVEL=${LOG_LEVEL}
    deploy:
      replicas: ${REPLICAS:-1}
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

# docker-compose.dev.yml - 开发环境
version: '3.8'
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
      - "9229:9229"  # Node.js 调试端口
    volumes:
      - .:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development

# docker-compose.prod.yml - 生产环境
version: '3.8'
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.prod
      args:
        BUILDKIT_INLINE_CACHE: 1
    deploy:
      replicas: 3
      placement:
        constraints:
          - node.role == worker
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

#### 配置文件组织结构
```bash
# 项目配置结构
.
├── docker-compose.yml          # 主配置文件
├── docker-compose.override.yml # 本地开发覆盖
├── environments/
│   ├── dev/
│   │   └── docker-compose.env.yml
│   ├── staging/
│   │   └── docker-compose.env.yml
│   └── prod/
│       └── docker-compose.env.yml
├── configs/
│   ├── app.env
│   ├── database.env
│   └── redis.env
└── scripts/
    ├── deploy.sh
    ├── rollback.sh
    └── health-check.sh
```

### Terraform Docker Provider 配置

#### 基础设施定义
```hcl
# main.tf
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "tcp://localhost:2376"
  
  # TLS 配置 (生产环境必须)
  ca_material   = file("${path.module}/certs/ca.pem")
  cert_material = file("${path.module}/certs/cert.pem")
  key_material  = file("${path.module}/certs/key.pem")
}

# 网络配置
resource "docker_network" "app_network" {
  name   = "app-network"
  driver = "overlay"
  
  ipam_config {
    subnet = "172.20.0.0/16"
  }
}

# 镜像构建
resource "docker_image" "app" {
  name = "myapp:${var.image_tag}"
  
  build {
    context = "."
    dockerfile = "Dockerfile.prod"
    tag    = ["myapp:${var.image_tag}", "myapp:latest"]
    
    build_arg = {
      BUILD_DATE      = timestamp()
      VCS_REF         = var.git_commit
      VERSION         = var.app_version
    }
  }
}

# 服务部署
resource "docker_service" "app" {
  name = "app-service"
  
  task_spec {
    container_spec {
      image = docker_image.app.name
      
      env = {
        ENVIRONMENT = var.environment
        DATABASE_URL = var.database_url
        REDIS_URL    = var.redis_url
      }
      
      mounts {
        target = "/app/logs"
        source = "app-logs"
        type   = "volume"
      }
    }
    
    networks_advanced {
      name = docker_network.app_network.name
    }
    
    resources {
      limits {
        memory_bytes = 536870912  # 512MB
        nano_cpus    = 500000000  # 0.5 CPU
      }
      
      reservation {
        memory_bytes = 268435456  # 256MB
        nano_cpus    = 250000000  # 0.25 CPU
      }
    }
  }
  
  mode {
    replicated {
      replicas = var.replica_count
    }
  }
  
  update_config {
    parallelism     = 1
    delay           = "10s"
    failure_action  = "rollback"
    monitor         = "30s"
    max_failure_ratio = "0.3"
  }
  
  rollback_config {
    parallelism = 1
    delay       = "10s"
  }
  
  endpoint_spec {
    ports {
      target_port    = 3000
      published_port = 80
      protocol       = "tcp"
      publish_mode   = "ingress"
    }
  }
}
```

#### 变量和输出配置
```hcl
# variables.tf
variable "environment" {
  description = "部署环境"
  type        = string
  default     = "dev"
}

variable "image_tag" {
  description = "镜像标签"
  type        = string
}

variable "replica_count" {
  description = "副本数量"
  type        = number
  default     = 1
}

variable "database_url" {
  description = "数据库连接字符串"
  type        = string
  sensitive   = true
}

variable "redis_url" {
  description = "Redis连接字符串"
  type        = string
  sensitive   = true
}

# outputs.tf
output "service_endpoint" {
  description = "服务访问地址"
  value       = "http://${docker_service.app.endpoint_spec[0].ports[0].published_port}"
}

output "service_name" {
  description = "服务名称"
  value       = docker_service.app.name
}
```

## CI/CD 流水线设计

### GitHub Actions 流水线

#### 完整的 CI/CD 工作流
```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  # 代码质量检查
  code-quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
        
      - name: Run linters
        run: |
          npm run lint
          npm run type-check
          
      - name: Security audit
        run: npm audit --audit-level high

  # 安全扫描
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          ignore-unfixed: true
          format: 'sarif'
          output: 'trivy-results.sarif'
          
      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

  # 构建和测试
  build-and-test:
    needs: [code-quality, security-scan]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
        
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}
            
      - name: Login to Container Registry
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile.prod
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            BUILDKIT_INLINE_CACHE=1
            GIT_COMMIT=${{ github.sha }}
            BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # 集成测试
  integration-test:
    needs: build-and-test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Start services
        run: |
          docker-compose -f docker-compose.test.yml up -d
          sleep 30  # 等待服务启动
          
      - name: Run integration tests
        run: |
          docker-compose -f docker-compose.test.yml exec -T app npm run test:integration
          
      - name: Cleanup
        if: always()
        run: docker-compose -f docker-compose.test.yml down -v

  # 部署到不同环境
  deploy:
    needs: integration-test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [staging, production]
    environment: ${{ matrix.environment }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy to ${{ matrix.environment }}
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.DEPLOY_HOST }}
          username: ${{ secrets.DEPLOY_USER }}
          key: ${{ secrets.DEPLOY_KEY }}
          script: |
            cd /opt/deploy/${{ matrix.environment }}
            export IMAGE_TAG=${{ github.sha }}
            docker-compose pull
            docker-compose up -d
            docker system prune -af --volumes
            
      - name: Health check
        run: |
          sleep 60
          curl -f http://deploy-host:${{ matrix.environment == 'staging' && 8080 || 80 }}/health || exit 1
```

### GitLab CI/CD 配置

#### 多阶段流水线
```yaml
# .gitlab-ci.yml
stages:
  - build
  - test
  - security
  - deploy-staging
  - deploy-production

variables:
  DOCKER_REGISTRY: registry.gitlab.com
  DOCKER_IMAGE: $DOCKER_REGISTRY/$CI_PROJECT_PATH
  DOCKER_TLS_CERTDIR: "/certs"

before_script:
  - docker info

# 构建阶段
build:
  stage: build
  image: docker:24.0-cli
  services:
    - docker:24.0-dind
  script:
    - |
      docker build \
        --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
        --build-arg VCS_REF=$CI_COMMIT_SHA \
        --build-arg VERSION=$CI_COMMIT_TAG \
        -t $DOCKER_IMAGE:$CI_COMMIT_SHA \
        -t $DOCKER_IMAGE:latest \
        -f Dockerfile.prod .
    - docker push $DOCKER_IMAGE:$CI_COMMIT_SHA
    - docker push $DOCKER_IMAGE:latest
  only:
    - main
    - tags

# 测试阶段
test:
  stage: test
  image: docker/compose:latest
  services:
    - docker:24.0-dind
  script:
    - docker-compose -f docker-compose.test.yml up -d
    - sleep 30
    - docker-compose -f docker-compose.test.yml exec -T app npm test
    - docker-compose -f docker-compose.test.yml down -v
  except:
    - schedules

# 安全扫描阶段
security-scan:
  stage: security
  image: 
    name: aquasec/trivy:latest
    entrypoint: [""]
  script:
    - trivy image --exit-code 1 --severity HIGH,CRITICAL $DOCKER_IMAGE:$CI_COMMIT_SHA
  allow_failure: true

# 部署到预发布环境
deploy-staging:
  stage: deploy-staging
  image: bitnami/kubectl:latest
  environment:
    name: staging
    url: https://staging.example.com
  script:
    - kubectl set image deployment/app app=$DOCKER_IMAGE:$CI_COMMIT_SHA
    - kubectl rollout status deployment/app
    - kubectl get pods
  only:
    - main
  when: manual

# 部署到生产环境
deploy-production:
  stage: deploy-production
  image: bitnami/kubectl:latest
  environment:
    name: production
    url: https://example.com
  script:
    - kubectl set image deployment/app app=$DOCKER_IMAGE:$CI_COMMIT_SHA
    - kubectl rollout status deployment/app --timeout=300s
    - kubectl get pods
  only:
    - tags
  when: manual
```

## 镜像构建自动化

### 多阶段构建优化

#### 生产级 Dockerfile 示例
```dockerfile
# Dockerfile.prod
# 构建阶段
FROM node:18-alpine AS builder

# 安装构建依赖
RUN apk add --no-cache python3 make g++

# 设置工作目录
WORKDIR /app

# 复制 package 文件
COPY package*.json ./

# 安装依赖 (利用层缓存)
RUN npm ci --only=production && npm cache clean --force

# 复制源代码
COPY . .

# 运行测试
RUN npm test

# 构建应用
RUN npm run build

# 生产阶段
FROM node:18-alpine AS production

# 创建非root用户
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# 安装运行时依赖
RUN apk add --no-cache dumb-init

# 设置工作目录
WORKDIR /app

# 从构建阶段复制必要文件
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public

# 更改文件所有权
RUN chown -R nextjs:nodejs /app
USER nextjs

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# 使用 init 系统
ENTRYPOINT ["dumb-init", "--"]
CMD ["npm", "start"]
```

### 构建缓存优化策略

#### BuildKit 高级特性
```dockerfile
# 利用 BuildKit 特性
# syntax=docker/dockerfile:1.4

FROM node:18-alpine AS base
WORKDIR /app

# 分离依赖安装以最大化缓存命中
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --only=production

# 分离源码复制
COPY . .

# 条件化构建步骤
ARG BUILD_ENV=production
RUN if [ "$BUILD_ENV" = "production" ]; then \
      npm run build; \
    else \
      echo "Skipping build for development"; \
    fi
```

#### 构建脚本自动化
```bash
#!/bin/bash
# build.sh - 智能构建脚本

set -e

# 配置变量
REGISTRY="${REGISTRY:-localhost:5000}"
IMAGE_NAME="${IMAGE_NAME:-myapp}"
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(git rev-parse HEAD)
VERSION=${VERSION:-$(git describe --tags --always)}

# 检查是否有变更需要构建
check_changes() {
    local last_image_hash=$(docker images -q ${REGISTRY}/${IMAGE_NAME}:latest)
    if [ -n "$last_image_hash" ]; then
        local current_context_hash=$(find . -type f -not -path "./node_modules/*" -not -path "./.git/*" -exec md5sum {} \; | sort | md5sum | cut -d' ' -f1)
        local last_context_hash=$(docker history --no-trunc ${REGISTRY}/${IMAGE_NAME}:latest | head -2 | tail -1 | awk '{print $1}')
        
        if [ "$current_context_hash" = "$last_context_hash" ]; then
            echo "No changes detected, skipping build"
            exit 0
        fi
    fi
}

# 执行构建
build_image() {
    echo "Building image: ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
    
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        --build-arg BUILD_DATE="$BUILD_DATE" \
        --build-arg GIT_COMMIT="$GIT_COMMIT" \
        --build-arg VERSION="$VERSION" \
        --tag ${REGISTRY}/${IMAGE_NAME}:${VERSION} \
        --tag ${REGISTRY}/${IMAGE_NAME}:latest \
        --push \
        -f Dockerfile.prod \
        .
    
    echo "Build completed successfully"
}

# 主执行流程
main() {
    check_changes
    build_image
    
    # 推送标签
    if git describe --tags --exact-match HEAD >/dev/null 2>&1; then
        docker buildx imagetools create \
            --tag ${REGISTRY}/${IMAGE_NAME}:$(git describe --tags) \
            ${REGISTRY}/${IMAGE_NAME}:${VERSION}
    fi
}

main "$@"
```

## 容器部署自动化

### 蓝绿部署策略

#### Docker Compose 蓝绿部署
```bash
#!/bin/bash
# blue-green-deploy.sh

set -e

APP_NAME="myapp"
NEW_VERSION=$1
ENVIRONMENT=${2:-production}

# 配置路径
CONFIG_DIR="./environments/$ENVIRONMENT"
BLUE_STACK="${APP_NAME}-blue"
GREEN_STACK="${APP_NAME}-green"

# 确定当前活跃环境
CURRENT_STACK=$(docker stack ls | grep -E "(blue|green)" | awk '{print $1}')

if [ "$CURRENT_STACK" = "$BLUE_STACK" ]; then
    DEPLOY_STACK=$GREEN_STACK
    ROUTE_TRAFFIC_TO=$GREEN_STACK
else
    DEPLOY_STACK=$BLUE_STACK
    ROUTE_TRAFFIC_TO=$BLUE_STACK
fi

echo "Deploying $NEW_VERSION to $DEPLOY_STACK"

# 部署新版本
docker stack deploy -c $CONFIG_DIR/docker-compose.yml \
    -c $CONFIG_DIR/docker-compose.$DEPLOY_STACK.yml \
    --with-registry-auth \
    $DEPLOY_STACK

# 等待服务就绪
echo "Waiting for services to be ready..."
sleep 60

# 健康检查
HEALTH_CHECK_URL="http://${DEPLOY_STACK}.internal/health"
for i in {1..30}; do
    if curl -f $HEALTH_CHECK_URL; then
        echo "Health check passed"
        break
    fi
    echo "Health check failed, retrying... ($i/30)"
    sleep 10
done

if [ $i -eq 30 ]; then
    echo "Health check failed after 30 attempts"
    docker stack rm $DEPLOY_STACK
    exit 1
fi

# 切换流量
echo "Switching traffic to $DEPLOY_STACK"
docker service update \
    --label-add traefik.backend.loadbalancer.stickiness=true \
    ${ROUTE_TRAFFIC_TO}_traefik

# 优雅关闭旧环境
echo "Shutting down old stack: $CURRENT_STACK"
docker stack rm $CURRENT_STACK

echo "Deployment completed successfully"
```

### 滚动更新配置

#### Kubernetes 滚动更新策略
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1        # 最大不可用副本数
      maxSurge: 1             # 最大额外副本数
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        version: v1.0.0
    spec:
      containers:
      - name: app
        image: myapp:v1.0.0
        ports:
        - containerPort: 3000
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

## 配置管理与密钥管理

### HashiCorp Vault 集成

#### 密钥管理架构
```yaml
# vault-agent 配置
auto_auth:
  method:
    type: approle
    config:
      role_id_file_path: "/vault/config/role-id"
      secret_id_file_path: "/vault/config/secret-id"
  sink:
    - type: file
      config:
        path: "/home/vault/.vault-token"

template_config:
  exit_on_retry_failure: true
  static_secret_render_interval: "1m"

template:
  - source: "/vault/templates/app-config.ctmpl"
    destination: "/app/config/app.env"
    perms: 0644
```

#### 应用配置模板
```go
// app-config.ctmpl
DATABASE_URL=postgresql://{{ with secret "database/creds/app" }}{{ .Data.username }}:{{ .Data.password }}@postgres:5432/app{{ end }}
REDIS_URL=redis://{{ with secret "redis/creds/app" }}{{ .Data.username }}:{{ .Data.password }}@redis:6379{{ end }}
API_KEY={{ with secret "app/api-key" }}{{ .Data.key }}{{ end }}
JWT_SECRET={{ with secret "app/jwt-secret" }}{{ .Data.secret }}{{ end }}
LOG_LEVEL={{ env "LOG_LEVEL" | default "info" }}
```

### 配置热更新机制

#### Consul Template 集成
```go
// 配置监听和热更新
package main

import (
    "context"
    "fmt"
    "log"
    "os"
    "os/signal"
    "syscall"
    "time"
    
    "github.com/hashicorp/consul/api"
)

type ConfigManager struct {
    client     *api.Client
    configPath string
    watcher    chan struct{}
}

func NewConfigManager(address, configPath string) (*ConfigManager, error) {
    config := api.DefaultConfig()
    config.Address = address
    
    client, err := api.NewClient(config)
    if err != nil {
        return nil, err
    }
    
    return &ConfigManager{
        client:     client,
        configPath: configPath,
        watcher:    make(chan struct{}),
    }, nil
}

func (cm *ConfigManager) WatchConfig(ctx context.Context) {
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()
    
    for {
        select {
        case <-ticker.C:
            cm.updateConfig()
        case <-ctx.Done():
            return
        }
    }
}

func (cm *ConfigManager) updateConfig() {
    kv := cm.client.KV()
    
    // 获取配置
    pair, _, err := kv.Get(cm.configPath, nil)
    if err != nil {
        log.Printf("Failed to get config: %v", err)
        return
    }
    
    if pair == nil {
        log.Println("Config not found")
        return
    }
    
    // 更新应用配置
    // 这里实现具体的配置更新逻辑
    log.Println("Configuration updated successfully")
    
    // 通知应用重新加载配置
    cm.watcher <- struct{}{}
}

func main() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    
    // 处理信号
    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
    
    // 初始化配置管理器
    cm, err := NewConfigManager("consul:8500", "app/config")
    if err != nil {
        log.Fatal(err)
    }
    
    // 启动配置监听
    go cm.WatchConfig(ctx)
    
    // 应用主循环
    for {
        select {
        case <-cm.watcher:
            fmt.Println("Reloading application configuration...")
            // 重新加载应用配置的逻辑
            
        case <-sigChan:
            fmt.Println("Shutting down...")
            return
        }
    }
}
```

## 监控告警自动化

### Prometheus 监控集成

#### 服务发现配置
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert.rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

scrape_configs:
  - job_name: 'docker-containers'
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 30s
    relabel_configs:
      - source_labels: [__meta_docker_container_name]
        regex: '/(.*)'
        target_label: container
      - source_labels: [__meta_docker_container_label_com_docker_compose_service]
        target_label: service
      - source_labels: [__meta_docker_network_ip]
        target_label: ip_address
    metrics_path: /metrics
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
```

#### 告警规则定义
```yaml
# alert.rules.yml
groups:
  - name: docker.rules
    rules:
      - alert: ContainerDown
        expr: absent(container_last_seen{container_label_com_docker_compose_service!="", container_label_com_docker_compose_project!=""}) == 1
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Container is down"
          description: "Container {{ $labels.container_label_com_docker_compose_service }} is down"

      - alert: HighCPUUsage
        expr: rate(container_cpu_usage_seconds_total[1m]) * 100 > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "Container {{ $labels.name }} CPU usage is above 80% for more than 2 minutes"

      - alert: HighMemoryUsage
        expr: (container_memory_usage_bytes / container_spec_memory_limit_bytes * 100) > 85
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Container {{ $labels.name }} memory usage is above 85% for more than 2 minutes"

      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes * 100) < 15
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space"
          description: "Disk space on {{ $labels.mountpoint }} is below 15%"
```

### 自动化运维脚本

#### 健康检查和自愈脚本
```bash
#!/bin/bash
# auto-healing.sh

set -e

LOG_FILE="/var/log/auto-healing.log"
MAX_RESTARTS=3
RESTART_WINDOW=3600  # 1小时窗口

# 日志函数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

# 检查容器健康状态
check_container_health() {
    local container_name=$1
    local health_status=$(docker inspect --format='{{json .State.Health}}' $container_name 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log "ERROR: Container $container_name not found"
        return 2
    fi
    
    if [ "$health_status" = "null" ]; then
        # 没有健康检查，检查是否运行
        local status=$(docker inspect --format='{{.State.Running}}' $container_name)
        if [ "$status" = "true" ]; then
            return 0
        else
            return 1
        fi
    else
        local health=$(echo $health_status | jq -r '.Status')
        case $health in
            "healthy")
                return 0
                ;;
            "unhealthy")
                return 1
                ;;
            *)
                return 2
                ;;
        esac
    fi
}

# 重启容器
restart_container() {
    local container_name=$1
    local restart_count_file="/tmp/${container_name}_restart_count"
    
    # 检查重启频率
    local now=$(date +%s)
    local last_restart=0
    local restart_count=0
    
    if [ -f $restart_count_file ]; then
        read last_restart restart_count < $restart_count_file
    fi
    
    # 如果在重启窗口内，增加计数；否则重置
    if [ $((now - last_restart)) -lt $RESTART_WINDOW ]; then
        restart_count=$((restart_count + 1))
    else
        restart_count=1
    fi
    
    # 检查是否超过最大重启次数
    if [ $restart_count -gt $MAX_RESTARTS ]; then
        log "WARNING: Max restarts exceeded for $container_name, sending alert"
        send_alert "max_restarts" $container_name
        return 1
    fi
    
    # 执行重启
    log "INFO: Restarting container $container_name (attempt $restart_count)"
    docker restart $container_name
    
    # 记录重启信息
    echo "$now $restart_count" > $restart_count_file
    
    # 等待容器启动
    sleep 30
    
    # 验证重启结果
    check_container_health $container_name
    local health_result=$?
    
    if [ $health_result -eq 0 ]; then
        log "INFO: Container $container_name restarted successfully"
        return 0
    else
        log "ERROR: Container $container_name failed to become healthy after restart"
        return 1
    fi
}

# 发送告警
send_alert() {
    local alert_type=$1
    local container_name=$2
    local message=""
    
    case $alert_type in
        "health_failed")
            message="Container health check failed: $container_name"
            ;;
        "max_restarts")
            message="Container exceeded max restart attempts: $container_name"
            ;;
        "disk_full")
            message="Disk space critically low on host"
            ;;
    esac
    
    # 发送邮件告警
    echo "$message" | mail -s "Docker Auto-Healing Alert" ops-team@company.com
    
    # 发送到监控系统
    curl -X POST "http://monitoring-system/alert" \
         -H "Content-Type: application/json" \
         -d "{\"type\":\"$alert_type\",\"container\":\"$container_name\",\"message\":\"$message\"}"
}

# 主监控循环
main() {
    log "INFO: Starting auto-healing monitor"
    
    while true; do
        # 检查所有运行的容器
        docker ps --format "{{.Names}}" | while read container; do
            check_container_health $container
            local result=$?
            
            case $result in
                1)  # 不健康
                    log "WARNING: Container $container is unhealthy, attempting restart"
                    restart_container $container
                    if [ $? -ne 0 ]; then
                        send_alert "health_failed" $container
                    fi
                    ;;
                2)  # 状态未知
                    log "WARNING: Unable to determine health status for $container"
                    ;;
            esac
        done
        
        # 检查磁盘空间
        local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
        if [ $disk_usage -gt 90 ]; then
            log "CRITICAL: Disk usage is ${disk_usage}%"
            send_alert "disk_full" "host"
        fi
        
        sleep 60
    done
}

# 信号处理
trap 'log "INFO: Shutting down auto-healing monitor"; exit 0' TERM INT

main "$@"
```

## 灾备与回滚机制

### 数据备份策略

#### 自动化备份脚本
```bash
#!/bin/bash
# backup-docker-data.sh

set -e

BACKUP_DIR="/backup/docker"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# 创建备份目录
mkdir -p $BACKUP_DIR/{volumes,configs,images}

# 备份 Docker 卷
backup_volumes() {
    echo "Backing up Docker volumes..."
    
    docker volume ls -q | while read volume; do
        echo "Backing up volume: $volume"
        docker run --rm \
            -v $volume:/volume \
            -v $BACKUP_DIR/volumes:/backup \
            alpine tar czf /backup/${volume}_${DATE}.tar.gz -C /volume .
    done
}

# 备份配置文件
backup_configs() {
    echo "Backing up Docker configurations..."
    
    # 备份 compose 文件
    find /opt/deploy -name "docker-compose*.yml" -exec tar czf $BACKUP_DIR/configs/compose_${DATE}.tar.gz {} +
    
    # 备份 Docker daemon 配置
    tar czf $BACKUP_DIR/configs/daemon_${DATE}.tar.gz /etc/docker/
}

# 备份重要镜像
backup_images() {
    echo "Backing up important images..."
    
    # 导出关键镜像
    IMAGES=("nginx:latest" "redis:alpine" "postgres:15")
    
    for image in "${IMAGES[@]}"; do
        echo "Exporting image: $image"
        docker save $image | gzip > $BACKUP_DIR/images/${image//\//_}_${DATE}.tar.gz
    done
}

# 清理旧备份
cleanup_old_backups() {
    echo "Cleaning up old backups..."
    find $BACKUP_DIR -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete
}

# 验证备份完整性
verify_backup() {
    echo "Verifying backup integrity..."
    
    # 验证卷备份
    find $BACKUP_DIR/volumes -name "*.tar.gz" | while read backup; do
        if ! gunzip -t $backup 2>/dev/null; then
            echo "ERROR: Backup verification failed for $backup"
            return 1
        fi
    done
    
    echo "Backup verification completed successfully"
}

# 主执行流程
main() {
    echo "Starting Docker backup at $(date)"
    
    backup_volumes
    backup_configs
    backup_images
    cleanup_old_backups
    verify_backup
    
    echo "Docker backup completed at $(date)"
}

main "$@"
```

### 快速回滚机制

#### 回滚脚本
```bash
#!/bin/bash
# rollback.sh

set -e

SERVICE_NAME=$1
TARGET_VERSION=$2
ROLLBACK_TIMEOUT=300

if [ $# -ne 2 ]; then
    echo "Usage: $0 <service_name> <target_version>"
    exit 1
fi

echo "Rolling back $SERVICE_NAME to version $TARGET_VERSION"

# 检查目标版本是否存在
if ! docker images | grep -q "$SERVICE_NAME.*$TARGET_VERSION"; then
    echo "ERROR: Target version $TARGET_VERSION not found"
    exit 1
fi

# 获取当前部署信息
CURRENT_VERSION=$(docker service inspect $SERVICE_NAME --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' | cut -d: -f2)
echo "Current version: $CURRENT_VERSION"

# 执行回滚
echo "Executing rollback..."
docker service update \
    --image $SERVICE_NAME:$TARGET_VERSION \
    --update-failure-action rollback \
    --update-monitor 30s \
    --rollback-parallelism 1 \
    --rollback-monitor 30s \
    $SERVICE_NAME

# 等待回滚完成
echo "Waiting for rollback to complete..."
for i in {1..50}; do
    if docker service ps $SERVICE_NAME | grep -q "Running.*$TARGET_VERSION"; then
        echo "Rollback completed successfully"
        break
    fi
    
    if [ $i -eq 50 ]; then
        echo "ERROR: Rollback timed out"
        exit 1
    fi
    
    sleep 6
done

# 验证服务状态
echo "Verifying service health..."
sleep 30

HEALTH_CHECK_URL="http://localhost/health"
if curl -f $HEALTH_CHECK_URL; then
    echo "Service health check passed"
else
    echo "WARNING: Service health check failed"
fi

echo "Rollback process completed"
```

通过这套完整的自动化运维体系，可以实现从代码提交到生产部署的全流程自动化，大大提高运维效率和系统稳定性。