# Docker Compose 编排

> **适用版本**: Docker Compose v2.x (Compose Spec) | **最后更新**: 2026-01

---

## 目录

- [Compose 概述](#compose-概述)
- [配置文件完整参考](#配置文件完整参考)
- [服务配置](#服务配置)
- [网络配置](#网络配置)
- [存储配置](#存储配置)
- [多环境管理](#多环境管理)
- [生产环境配置](#生产环境配置)
- [常用命令](#常用命令)

---

## Compose 概述

### 版本演进

| 版本 | 特性 | 状态 |
|:---|:---|:---|
| Compose v1 | docker-compose 命令 (Python) | 废弃 |
| Compose v2 | docker compose 命令 (Go) | 当前推荐 |
| Compose Spec | 开放标准、无版本号 | 规范标准 |

### 基本结构

```yaml
# compose.yaml (推荐) 或 docker-compose.yml
name: myproject  # 可选，默认使用目录名

services:
  webapp:
    image: nginx:alpine
    ports:
      - "80:80"
    depends_on:
      - api
      
  api:
    build: ./api
    environment:
      - DATABASE_URL=postgres://db:5432/app
    depends_on:
      db:
        condition: service_healthy
        
  db:
    image: postgres:16
    volumes:
      - db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  db-data:

networks:
  default:
    driver: bridge
```

---

## 配置文件完整参考

### 顶级配置

| 字段 | 说明 | 示例 |
|:---|:---|:---|
| `name` | 项目名称 | `name: myapp` |
| `version` | 废弃字段 | 不再使用 |
| `services` | 服务定义 | 见下方 |
| `networks` | 网络定义 | 见下方 |
| `volumes` | 卷定义 | 见下方 |
| `configs` | 配置定义 | Swarm/configs |
| `secrets` | 密钥定义 | Swarm/secrets |
| `x-*` | 扩展字段 | YAML 锚点复用 |

### 扩展字段 (YAML 锚点)

```yaml
x-common-env: &common-env
  TZ: Asia/Shanghai
  NODE_ENV: production

x-common-labels: &common-labels
  app.team: platform
  app.env: production

x-logging: &default-logging
  driver: json-file
  options:
    max-size: "100m"
    max-file: "3"

services:
  app1:
    image: myapp:v1
    environment:
      <<: *common-env
      APP_NAME: app1
    labels:
      <<: *common-labels
    logging:
      <<: *default-logging
      
  app2:
    image: myapp:v2
    environment:
      <<: *common-env
      APP_NAME: app2
    labels:
      <<: *common-labels
    logging:
      <<: *default-logging
```

---

## 服务配置

### 镜像与构建

```yaml
services:
  # 使用镜像
  nginx:
    image: nginx:1.25-alpine
    
  # 构建镜像
  app:
    build:
      context: ./app
      dockerfile: Dockerfile.prod
      args:
        - VERSION=1.0.0
        - BUILD_DATE=${BUILD_DATE}
      target: production
      cache_from:
        - myapp:cache
      labels:
        - "com.example.version=1.0"
      network: host
      shm_size: '256m'
      
  # 简写构建
  simple-build:
    build: ./app
    
  # 构建并指定镜像名
  named-build:
    build: ./app
    image: myregistry/myapp:${TAG:-latest}
```

### 容器配置

```yaml
services:
  app:
    image: myapp:latest
    
    # 基本配置
    container_name: myapp-container
    hostname: myapp
    domainname: example.com
    
    # 命令与入口点
    command: ["npm", "start"]
    entrypoint: ["/entrypoint.sh"]
    working_dir: /app
    
    # 用户与权限
    user: "1000:1000"
    privileged: false
    read_only: true
    
    # 交互模式
    stdin_open: true
    tty: true
    
    # 初始化进程
    init: true
    
    # 停止配置
    stop_signal: SIGTERM
    stop_grace_period: 30s
```

### 环境与配置

```yaml
services:
  app:
    # 环境变量 - 多种方式
    environment:
      DEBUG: "true"
      DATABASE_URL: postgres://user:pass@db:5432/app
      
    # 从文件加载
    env_file:
      - .env
      - .env.local
      - path: .env.prod
        required: false  # 可选文件
        
    # 标签
    labels:
      com.example.description: "My application"
      com.example.team: platform
```

### 健康检查

```yaml
services:
  app:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
      start_interval: 5s
      
  # 禁用健康检查
  no-health:
    healthcheck:
      disable: true
```

### 依赖管理

```yaml
services:
  web:
    depends_on:
      - db       # 简单依赖
      - redis
      
  api:
    depends_on:
      db:
        condition: service_healthy      # 等待健康
        restart: true                   # 依赖重启时重启
      redis:
        condition: service_started      # 等待启动
      migration:
        condition: service_completed_successfully  # 等待完成
```

### 资源限制

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 1G
          pids: 100
        reservations:
          cpus: '0.5'
          memory: 256M
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
              
    # 旧版语法 (仍支持)
    mem_limit: 1g
    memswap_limit: 2g
    mem_reservation: 256m
    cpus: 2.0
    cpu_shares: 1024
    pids_limit: 100
    
    # ulimits
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
      nproc: 4096
```

### 重启策略

```yaml
services:
  app:
    restart: unless-stopped
    
  # 可选值:
  # - no           (默认，不重启)
  # - always       (始终重启)
  # - on-failure   (失败时重启)
  # - unless-stopped (除非手动停止)
  
  # deploy 模式下
  worker:
    deploy:
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
        window: 120s
```

### 安全配置

```yaml
services:
  app:
    # 能力管理
    cap_add:
      - NET_ADMIN
      - SYS_TIME
    cap_drop:
      - ALL
      
    # 安全选项
    security_opt:
      - no-new-privileges:true
      - seccomp:./seccomp-profile.json
      - apparmor:myprofile
      
    # SELinux
    # security_opt:
    #   - label:type:container_runtime_t
    
    # Sysctls
    sysctls:
      net.core.somaxconn: 1024
      net.ipv4.tcp_syncookies: 0
      
    # 设备
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0
      
    # 只读根文件系统
    read_only: true
    tmpfs:
      - /tmp
      - /run
```

---

## 网络配置

### 网络定义

```yaml
networks:
  # 默认网络
  default:
    driver: bridge
    
  # 前端网络
  frontend:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.enable_icc: "true"
    ipam:
      driver: default
      config:
        - subnet: 172.20.0.0/24
          gateway: 172.20.0.1
          ip_range: 172.20.0.0/25
          
  # 后端内部网络
  backend:
    driver: bridge
    internal: true  # 禁止外部访问
    
  # 使用已存在的网络
  external-net:
    external: true
    name: my-existing-network
```

### 服务网络配置

```yaml
services:
  web:
    networks:
      - frontend
      
  app:
    networks:
      frontend:
        ipv4_address: 172.20.0.10
        ipv6_address: 2001:db8::10
        aliases:
          - api
          - backend-api
        priority: 1000
      backend:
        aliases:
          - app
```

### DNS 配置

```yaml
services:
  app:
    dns:
      - 8.8.8.8
      - 8.8.4.4
    dns_search:
      - example.com
      - internal.example.com
    dns_opt:
      - timeout:2
      - attempts:3
    extra_hosts:
      - "api.internal:192.168.1.10"
      - "db.internal:192.168.1.11"
```

### 端口配置

```yaml
services:
  web:
    ports:
      # 短语法
      - "80:80"
      - "443:443"
      - "8080-8090:80-90"
      
      # 长语法
      - target: 80
        published: 8080
        protocol: tcp
        mode: host
        
      # 仅容器内暴露
      - "3000"
      
      # 指定主机 IP
      - "127.0.0.1:8080:80"
      
    expose:
      - "3000"
      - "8000"
```

---

## 存储配置

### 卷定义

```yaml
volumes:
  # 命名卷
  db-data:
  
  # 带配置的卷
  app-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=nfs.example.com,rw
      device: ":/path/to/share"
      
  # 外部卷
  shared-data:
    external: true
    name: my-existing-volume
    
  # 标签
  logs:
    labels:
      - "backup=true"
      - "env=production"
```

### 服务存储配置

```yaml
services:
  app:
    volumes:
      # 命名卷
      - db-data:/var/lib/postgresql/data
      
      # 绑定挂载
      - ./config:/app/config:ro
      
      # 匿名卷
      - /app/node_modules
      
      # 长语法
      - type: volume
        source: app-data
        target: /app/data
        read_only: false
        volume:
          nocopy: true
          
      - type: bind
        source: ./src
        target: /app/src
        read_only: true
        bind:
          propagation: rprivate
          create_host_path: true
          selinux: z
          
      - type: tmpfs
        target: /app/temp
        tmpfs:
          size: 100000000  # 100MB
          mode: 1777
```

---

## 多环境管理

### 环境文件

```bash
# .env (默认加载)
COMPOSE_PROJECT_NAME=myapp
TAG=latest
DATABASE_URL=postgres://localhost:5432/dev

# .env.prod
TAG=v1.2.3
DATABASE_URL=postgres://prod-db:5432/app
```

```yaml
# compose.yaml
services:
  app:
    image: myapp:${TAG:-latest}
    environment:
      DATABASE_URL: ${DATABASE_URL}
```

### 多文件组合

```bash
# 基础 + 开发覆盖
docker compose -f compose.yaml -f compose.dev.yaml up

# 基础 + 生产覆盖
docker compose -f compose.yaml -f compose.prod.yaml up
```

```yaml
# compose.yaml (基础)
services:
  app:
    image: myapp:${TAG:-latest}
    
# compose.dev.yaml (开发覆盖)
services:
  app:
    build: .
    volumes:
      - ./src:/app/src
    environment:
      DEBUG: "true"
    ports:
      - "3000:3000"
      
# compose.prod.yaml (生产覆盖)
services:
  app:
    deploy:
      replicas: 3
      resources:
        limits:
          memory: 1G
    environment:
      DEBUG: "false"
```

### Profiles

```yaml
services:
  app:
    image: myapp:latest
    
  debug-tools:
    image: nicolaka/netshoot
    profiles:
      - debug
      
  db-admin:
    image: dpage/pgadmin4
    profiles:
      - tools
      - debug
```

```bash
# 仅启动默认服务
docker compose up

# 包含 debug profile
docker compose --profile debug up

# 多个 profiles
docker compose --profile debug --profile tools up
```

---

## 生产环境配置

### 完整生产配置示例

```yaml
name: production-app

x-logging: &default-logging
  driver: json-file
  options:
    max-size: "100m"
    max-file: "5"
    compress: "true"

x-common-deploy: &common-deploy
  restart_policy:
    condition: on-failure
    delay: 5s
    max_attempts: 3
  update_config:
    parallelism: 1
    delay: 10s
    order: start-first

services:
  nginx:
    image: nginx:1.25-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - static-files:/usr/share/nginx/html:ro
    depends_on:
      api:
        condition: service_healthy
    deploy:
      <<: *common-deploy
      resources:
        limits:
          cpus: '1.0'
          memory: 256M
    logging: *default-logging
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - frontend

  api:
    image: myregistry/api:${TAG:-latest}
    environment:
      NODE_ENV: production
      DATABASE_URL: postgres://postgres:${DB_PASSWORD}@db:5432/app
      REDIS_URL: redis://redis:6379
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    deploy:
      <<: *common-deploy
      replicas: 2
      resources:
        limits:
          cpus: '2.0'
          memory: 1G
        reservations:
          memory: 512M
    logging: *default-logging
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      start_period: 60s
      retries: 3
    networks:
      - frontend
      - backend
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp:size=100m

  worker:
    image: myregistry/worker:${TAG:-latest}
    environment:
      DATABASE_URL: postgres://postgres:${DB_PASSWORD}@db:5432/app
      REDIS_URL: redis://redis:6379
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    deploy:
      <<: *common-deploy
      replicas: 3
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
    logging: *default-logging
    networks:
      - backend

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: app
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - db-data:/var/lib/postgresql/data
      - ./postgres/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
    logging: *default-logging
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backend

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis-data:/data
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
    logging: *default-logging
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backend

volumes:
  db-data:
    driver: local
  redis-data:
    driver: local
  static-files:
    driver: local

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true
```

### 安全加固配置

```yaml
services:
  secure-app:
    image: myapp:latest
    
    # 非特权用户
    user: "1000:1000"
    
    # 只读文件系统
    read_only: true
    tmpfs:
      - /tmp:size=100m,mode=1777
      - /run:size=10m
    
    # 删除所有能力
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
      
    # 安全选项
    security_opt:
      - no-new-privileges:true
      
    # 资源限制
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
          pids: 100
          
    # 非特权模式
    privileged: false
```

---

## 常用命令

### 生命周期管理

| 命令 | 说明 | 示例 |
|:---|:---|:---|
| `docker compose up` | 创建并启动 | `docker compose up -d` |
| `docker compose down` | 停止并删除 | `docker compose down -v` |
| `docker compose start` | 启动服务 | `docker compose start app` |
| `docker compose stop` | 停止服务 | `docker compose stop app` |
| `docker compose restart` | 重启服务 | `docker compose restart app` |
| `docker compose pause` | 暂停服务 | `docker compose pause` |
| `docker compose unpause` | 恢复服务 | `docker compose unpause` |

### up 命令选项

```bash
# 后台运行
docker compose up -d

# 强制重建
docker compose up -d --build --force-recreate

# 指定服务
docker compose up -d app db

# 扩展服务
docker compose up -d --scale app=3

# 不启动依赖
docker compose up -d --no-deps app

# 移除孤立容器
docker compose up -d --remove-orphans

# 等待超时
docker compose up -d --wait --wait-timeout 60
```

### down 命令选项

```bash
# 停止并删除
docker compose down

# 删除卷
docker compose down -v

# 删除镜像
docker compose down --rmi all

# 删除网络
docker compose down --remove-orphans
```

### 查看状态

```bash
# 服务状态
docker compose ps
docker compose ps -a  # 包括已停止

# 服务日志
docker compose logs
docker compose logs -f app       # 跟踪
docker compose logs --tail 100   # 最后100行

# 资源使用
docker compose top

# 配置检查
docker compose config
docker compose config --services
docker compose config --volumes
```

### 执行与调试

```bash
# 执行命令
docker compose exec app sh
docker compose exec -u root app bash

# 一次性运行
docker compose run --rm app npm test

# 拉取镜像
docker compose pull

# 构建镜像
docker compose build
docker compose build --no-cache
docker compose build --pull
```

---

## 相关文档

- [200-docker-architecture-overview](./200-docker-architecture-overview.md) - Docker 架构
- [202-docker-container-lifecycle](./202-docker-container-lifecycle.md) - 容器生命周期
- [203-docker-networking-deep-dive](./203-docker-networking-deep-dive.md) - Docker 网络
- [204-docker-storage-volumes](./204-docker-storage-volumes.md) - Docker 存储
- [125-gitops-workflow-argocd](./125-gitops-workflow-argocd.md) - GitOps 工作流
