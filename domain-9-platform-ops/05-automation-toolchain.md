# 运维自动化工具链 (Operations Automation Toolchain)

## 概述

运维自动化工具链是现代平台运维的核心基础设施，通过整合各类自动化工具，实现从基础设施部署到应用交付的端到端自动化流程。

## 工具链架构

### 基础设施层
```
基础设施即代码(IaC) → 配置管理 → 资源编排
```

### 平台管理层
```
集群管理 → 监控告警 → 日志分析 → 安全管控
```

### 应用交付层
```
CI/CD流水线 → 部署管理 → 配置同步 → 灾难恢复
```

## 基础设施即代码 (IaC)

### Terraform配置管理
```hcl
# Kubernetes集群基础设施
module "kubernetes_cluster" {
  source = "./modules/kubernetes"
  
  cluster_name    = var.cluster_name
  region         = var.region
  node_groups = {
    control_plane = {
      instance_type = "t3.medium"
      desired_capacity = 3
      min_size = 3
      max_size = 5
    }
    worker_nodes = {
      instance_type = "t3.large"
      desired_capacity = 6
      min_size = 3
      max_size = 10
    }
  }
}

# 网络基础设施
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.environment}-vpc"
  }
}

resource "aws_subnet" "private" {
  count = 3
  vpc_id = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "${var.environment}-private-${count.index}"
  }
}
```

### Ansible自动化配置
```yaml
# Kubernetes节点配置playbook
---
- name: Configure Kubernetes nodes
  hosts: k8s_nodes
  become: yes
  vars:
    kubernetes_version: "1.28.0"
    container_runtime: "containerd"
    
  tasks:
  - name: Install container runtime
    apt:
      name: "{{ container_runtime }}"
      state: present
      
  - name: Configure kernel modules
    lineinfile:
      path: /etc/modules-load.d/k8s.conf
      line: "{{ item }}"
      create: yes
    loop:
      - br_netfilter
      - overlay
      
  - name: Configure sysctl settings
    sysctl:
      name: "{{ item.key }}"
      value: "{{ item.value }}"
      sysctl_set: yes
    loop:
      - { key: "net.bridge.bridge-nf-call-iptables", value: "1" }
      - { key: "net.ipv4.ip_forward", value: "1" }
      
  - name: Install Kubernetes components
    apt:
      name:
        - kubelet={{ kubernetes_version }}-00
        - kubeadm={{ kubernetes_version }}-00
        - kubectl={{ kubernetes_version }}-00
      state: present
```

## CI/CD流水线工具

### Jenkins Pipeline
```groovy
// Jenkinsfile示例
pipeline {
    agent any
    
    environment {
        REGISTRY = 'myregistry.com'
        IMAGE_NAME = 'myapp'
        NAMESPACE = 'production'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build') {
            steps {
                script {
                    docker.build("${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}")
                }
            }
        }
        
        stage('Test') {
            parallel {
                stage('Unit Test') {
                    steps {
                        sh 'make test-unit'
                    }
                }
                stage('Integration Test') {
                    steps {
                        sh 'make test-integration'
                    }
                }
            }
        }
        
        stage('Deploy') {
            steps {
                withCredentials([kubeconfigFile(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh """
                        kubectl set image deployment/${IMAGE_NAME} ${IMAGE_NAME}=${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}
                        kubectl rollout status deployment/${IMAGE_NAME}
                    """
                }
            }
        }
        
        stage('Verify') {
            steps {
                sh 'curl -f https://myapp.example.com/health'
            }
        }
    }
    
    post {
        success {
            slackSend channel: '#deployments', message: "✅ Deployment successful: ${IMAGE_NAME}:${BUILD_NUMBER}"
        }
        failure {
            slackSend channel: '#deployments', message: "❌ Deployment failed: ${IMAGE_NAME}:${BUILD_NUMBER}"
        }
    }
}
```

### GitHub Actions
```yaml
# .github/workflows/deploy.yml
name: Deploy to Kubernetes

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
      
    - name: Login to Container Registry
      uses: docker/login-action@v2
      with:
        registry: ghcr.io
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
        
    - name: Build and push
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
        
    - name: Deploy to Kubernetes
      uses: actions-hub/kubectl@master
      with:
        args: set image deployment/myapp myapp=ghcr.io/${{ github.repository }}:${{ github.sha }}
      env:
        KUBE_CONFIG_DATA: ${{ secrets.KUBE_CONFIG_DATA }}
```

## 配置管理工具

### Helm Chart管理
```yaml
# values.yaml模板
replicaCount: 3

image:
  repository: myapp
  tag: latest
  pullPolicy: Always

service:
  type: ClusterIP
  port: 80

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: myapp.example.com
      paths:
        - path: /
          pathType: ImplementationSpecific
```

### Kustomize配置
```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
- configmap.yaml

namespace: production

commonLabels:
  app: myapp
  version: v1.0.0

images:
- name: myapp
  newName: registry.example.com/myapp
  newTag: v1.0.0

configMapGenerator:
- name: app-config
  literals:
  - DATABASE_HOST=mysql.production
  - REDIS_HOST=redis.production
```

## 监控告警自动化

### PrometheusRule自动生成
```yaml
# 自动生成告警规则
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: app-rules
spec:
  groups:
  - name: app.rules
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "High error rate detected"
        description: "{{ $labels.app }} has error rate > 5%"
```

### Grafana仪表板自动化
```json
{
  "dashboard": {
    "id": null,
    "title": "Application Dashboard - {{ .appName }}",
    "tags": ["generated", "{{ .environment }}"],
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total{app=\"{{ .appName }}\"}[5m])",
            "legendFormat": "{{ .appName }} - {{ .environment }}"
          }
        ]
      }
    ]
  }
}
```

## 安全自动化

### 镜像安全扫描
```yaml
# Trivy扫描配置
apiVersion: batch/v1
kind: Job
metadata:
  name: image-scan
spec:
  template:
    spec:
      containers:
      - name: trivy
        image: aquasec/trivy:0.40.0
        command:
        - trivy
        - image
        - --exit-code
        - "1"
        - --severity
        - HIGH,CRITICAL
        - myregistry.com/myapp:latest
      restartPolicy: Never
```

### 策略引擎自动化
```yaml
# Kyverno策略示例
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-requests-limits
spec:
  validationFailureAction: enforce
  rules:
  - name: validate-resources
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "CPU and memory resource requests and limits are required"
      pattern:
        spec:
          containers:
          - resources:
              requests:
                memory: "?*"
                cpu: "?*"
              limits:
                memory: "?*"
                cpu: "?*"
```

## 备份恢复自动化

### Velero备份策略
```yaml
# 备份调度配置
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"  # 每天凌晨2点
  template:
    ttl: "168h"  # 保留7天
    includedNamespaces:
    - production
    - staging
    excludedResources:
    - events
    - nodes
    snapshotVolumes: true
```

### 恢复验证脚本
```bash
#!/bin/bash
# restore-validation.sh

NAMESPACE=$1
BACKUP_NAME=$2

echo "Validating restore for namespace: $NAMESPACE"

# 检查Pod状态
kubectl get pods -n $NAMESPACE --no-headers | while read line; do
    pod_name=$(echo $line | awk '{print $1}')
    pod_status=$(echo $line | awk '{print $3}')
    
    if [[ $pod_status != "Running" ]]; then
        echo "❌ Pod $pod_name is not running: $pod_status"
        exit 1
    fi
done

# 检查服务连通性
SERVICE_ENDPOINT=$(kubectl get svc -n $NAMESPACE -o jsonpath='{.items[0].spec.clusterIP}')
if ! curl -f http://$SERVICE_ENDPOINT/health; then
    echo "❌ Service health check failed"
    exit 1
fi

echo "✅ Restore validation passed"
```

## 故障自愈自动化

### 自动扩容脚本
```python
#!/usr/bin/env python3
import subprocess
import json
import time

def get_cpu_utilization():
    cmd = "kubectl top nodes -o json"
    result = subprocess.run(cmd.split(), capture_output=True, text=True)
    nodes_data = json.loads(result.stdout)
    
    high_util_nodes = []
    for node in nodes_data['rows']:
        cpu_percent = int(node['cpu'].rstrip('%'))
        if cpu_percent > 80:
            high_util_nodes.append({
                'name': node['name'],
                'cpu': cpu_percent
            })
    
    return high_util_nodes

def scale_up_nodes():
    high_util_nodes = get_cpu_utilization()
    
    if len(high_util_nodes) > 0:
        print(f"Scaling up due to high CPU utilization: {high_util_nodes}")
        # 调用云提供商API扩容节点组
        subprocess.run([
            "aws", "autoscaling", "set-desired-capacity",
            "--auto-scaling-group-name", "worker-nodes-asg",
            "--desired-capacity", "8"
        ])

if __name__ == "__main__":
    while True:
        scale_up_nodes()
        time.sleep(300)  # 每5分钟检查一次
```

### 自动故障转移
```yaml
# ExternalDNS配置
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
spec:
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: k8s.gcr.io/external-dns/external-dns:v0.13.0
        args:
        - --source=service
        - --source=ingress
        - --domain-filter=example.com
        - --provider=aws
        - --policy=sync
        - --registry=txt
        - --txt-owner-id=my-identifier
```

## 最佳实践

### 1. 工具链集成
- 统一认证和授权机制
- 标准化接口和协议
- 集中式配置管理

### 2. 安全合规
- 安全扫描集成到CI/CD流程
- 访问控制最小权限原则
- 审计日志完整记录

### 3. 可观察性
- 统一监控指标收集
- 链路追踪全覆盖
- 告警通知及时准确

### 4. 持续改进
- 定期评估工具链效果
- 收集用户反馈优化
- 跟踪新技术发展趋势

通过构建完整的运维自动化工具链，可以大幅提升运维效率，减少人为错误，实现平台的稳定可靠运行。