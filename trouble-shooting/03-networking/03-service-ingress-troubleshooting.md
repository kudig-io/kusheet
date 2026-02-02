# Service 与 Ingress 故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 中级

---

## 目录

1. [问题现象与影响分析](#1-问题现象与影响分析)
2. [排查方法与步骤](#2-排查方法与步骤)
3. [解决方案与风险控制](#3-解决方案与风险控制)

---

## 1. 问题现象与影响分析

### 1.1 Service 常见问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| ClusterIP 无法访问 | `connection refused/timeout` | 客户端 | curl/telnet |
| NodePort 无法访问 | `connection refused` | 外部 | curl |
| LoadBalancer 无 External IP | `<pending>` | kubectl | `kubectl get svc` |
| Endpoints 为空 | 无后端 Pod | kubectl | `kubectl get endpoints` |
| 端口映射错误 | 连接错误端口 | 应用 | 连接测试 |

### 1.2 Ingress 常见问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| Ingress Controller 异常 | `CrashLoopBackOff` | kubectl | `kubectl get pods` |
| 路由不生效 | `404 Not Found` | HTTP 响应 | curl |
| TLS 证书错误 | `SSL certificate error` | 浏览器/curl | curl -v |
| 后端不可达 | `502 Bad Gateway` | HTTP 响应 | curl |
| 地址未分配 | `ADDRESS` 为空 | kubectl | `kubectl get ingress` |

### 1.3 报错查看方式汇总

```bash
# Service 相关
kubectl get svc -A
kubectl describe svc <service-name>
kubectl get endpoints <service-name>
kubectl get endpointslices -l kubernetes.io/service-name=<service-name>

# Ingress 相关
kubectl get ingress -A
kubectl describe ingress <ingress-name>

# Ingress Controller 日志
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=200

# 测试 Service
kubectl run test --rm -it --image=busybox -- wget -qO- http://<cluster-ip>:<port>

# 测试 Ingress
curl -v http://<ingress-ip> -H "Host: <hostname>"
```

### 1.4 影响面分析

| 问题类型 | 影响范围 | 影响描述 |
|----------|----------|----------|
| Service 不可用 | 服务间调用 | 微服务调用失败 |
| Ingress 不可用 | 外部访问 | 用户无法访问应用 |
| LoadBalancer 问题 | 外部流量 | 云负载均衡失效 |
| TLS 证书问题 | HTTPS 访问 | 安全连接失败 |

---

## 2. 排查方法与步骤

### 2.1 Service 排查步骤

#### 2.1.1 检查 Service 配置

```bash
# 查看 Service 详情
kubectl get svc <service-name> -o yaml

# 检查 selector 是否匹配 Pod
kubectl get svc <service-name> -o jsonpath='{.spec.selector}'
kubectl get pods -l <selector-key>=<selector-value>

# 检查端口配置
kubectl get svc <service-name> -o jsonpath='{.spec.ports}'

# 检查 Service 类型
kubectl get svc <service-name> -o jsonpath='{.spec.type}'
```

#### 2.1.2 检查 Endpoints

```bash
# 查看 Endpoints
kubectl get endpoints <service-name> -o yaml

# 查看 EndpointSlices
kubectl get endpointslices -l kubernetes.io/service-name=<service-name> -o yaml

# 如果 Endpoints 为空，检查 Pod 状态
kubectl get pods -l <selector> -o wide

# 检查 Pod 是否 Ready
kubectl get pods -l <selector> -o jsonpath='{.items[*].status.conditions}'
```

#### 2.1.3 测试连通性

```bash
# 测试 ClusterIP
kubectl run test --rm -it --image=busybox -- sh
# 在 Pod 内
wget -qO- http://<cluster-ip>:<port>
nc -zv <cluster-ip> <port>

# 测试 NodePort
curl http://<node-ip>:<node-port>

# 检查 iptables/IPVS 规则
iptables -t nat -L -n | grep <cluster-ip>
ipvsadm -Ln -t <cluster-ip>:<port>
```

### 2.2 Ingress 排查步骤

#### 2.2.1 检查 Ingress Controller

```bash
# 检查 Controller Pod 状态
kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# 查看 Controller 日志
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=200

# 检查 Controller Service
kubectl get svc -n ingress-nginx
```

#### 2.2.2 检查 Ingress 配置

```bash
# 查看 Ingress 详情
kubectl get ingress <ingress-name> -o yaml

# 检查 rules 配置
kubectl get ingress <ingress-name> -o jsonpath='{.spec.rules}'

# 检查 TLS 配置
kubectl get ingress <ingress-name> -o jsonpath='{.spec.tls}'

# 验证 Secret 存在
kubectl get secret <tls-secret-name>
```

#### 2.2.3 测试 Ingress

```bash
# 获取 Ingress IP
kubectl get ingress <ingress-name> -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# 测试 HTTP
curl -v http://<ingress-ip> -H "Host: <hostname>"

# 测试 HTTPS
curl -vk https://<ingress-ip> -H "Host: <hostname>"

# 检查证书
openssl s_client -connect <ingress-ip>:443 -servername <hostname>
```

---

## 3. 解决方案与风险控制

### 3.1 Service Endpoints 为空

#### 3.1.1 解决步骤

```bash
# 步骤 1：检查 selector 匹配
SERVICE_SELECTOR=$(kubectl get svc <service-name> -o jsonpath='{.spec.selector}')
echo "Service selector: $SERVICE_SELECTOR"

# 步骤 2：查找匹配的 Pod
kubectl get pods -l <selector-key>=<selector-value>

# 步骤 3：如果 Pod 存在但不在 Endpoints 中
# 检查 Pod 是否 Ready
kubectl get pods -l <selector> -o wide
kubectl describe pod <pod-name> | grep -A5 Conditions

# 步骤 4：如果 Pod 未 Ready
# 检查探针配置
kubectl get pod <pod-name> -o yaml | grep -A10 readinessProbe

# 步骤 5：修复 Pod 或 Service selector
# 修改 Service selector
kubectl patch svc <service-name> -p '{"spec":{"selector":{"app":"correct-label"}}}'

# 或修改 Pod labels
kubectl label pod <pod-name> app=correct-label

# 步骤 6：验证 Endpoints
kubectl get endpoints <service-name>
```

#### 3.1.2 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 修改 selector 会立即影响流量路由
2. 确保新 selector 匹配正确的 Pod
3. 检查 readinessProbe 是否过于严格
4. Pod 未 Ready 不会加入 Endpoints
```

### 3.2 LoadBalancer External IP Pending

#### 3.2.1 解决步骤

```bash
# 步骤 1：检查 Service 状态
kubectl get svc <service-name>
kubectl describe svc <service-name>

# 步骤 2：检查云平台配额
# 阿里云
aliyun slb DescribeLoadBalancers
# AWS
aws elbv2 describe-load-balancers

# 步骤 3：检查是否有 Cloud Controller Manager
kubectl get pods -n kube-system | grep cloud-controller

# 步骤 4：查看 Cloud Controller 日志
kubectl logs -n kube-system -l app=cloud-controller-manager --tail=100

# 步骤 5：检查节点标签（某些云需要）
kubectl get nodes --show-labels | grep -E "node.kubernetes.io|topology"

# 步骤 6：如果是裸金属环境，使用 MetalLB
# 部署 MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml

# 步骤 7：验证 External IP 分配
kubectl get svc <service-name>
```

#### 3.2.2 安全生产风险提示

```
⚠️  安全生产风险提示：
1. LoadBalancer 创建可能需要几分钟
2. 云平台配额限制可能阻止创建
3. 裸金属环境需要额外的负载均衡方案
4. External IP 分配后检查安全组配置
```

### 3.3 Ingress 502 Bad Gateway

#### 3.3.1 解决步骤

```bash
# 步骤 1：检查后端 Service
kubectl get svc <backend-service>
kubectl get endpoints <backend-service>

# 步骤 2：检查后端 Pod 健康
kubectl get pods -l <backend-selector>
kubectl describe pod <backend-pod>

# 步骤 3：检查 Ingress Controller 到后端的连通性
kubectl exec -n ingress-nginx <nginx-pod> -- curl -v http://<service-cluster-ip>:<port>

# 步骤 4：查看 Nginx 配置
kubectl exec -n ingress-nginx <nginx-pod> -- cat /etc/nginx/nginx.conf | grep -A20 "location"

# 步骤 5：检查 Ingress annotations
kubectl get ingress <ingress-name> -o yaml | grep -A10 annotations

# 步骤 6：调整超时配置
kubectl annotate ingress <ingress-name> nginx.ingress.kubernetes.io/proxy-connect-timeout="30"
kubectl annotate ingress <ingress-name> nginx.ingress.kubernetes.io/proxy-read-timeout="60"

# 步骤 7：验证修复
curl -v http://<ingress-ip> -H "Host: <hostname>"
```

#### 3.3.2 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 502 通常表示后端不可达
2. 检查后端 Service 和 Pod 是第一步
3. 超时配置影响慢请求处理
4. Ingress annotations 立即生效
```

### 3.4 TLS 证书配置

#### 3.4.1 解决步骤

```bash
# 步骤 1：检查 TLS Secret 存在
kubectl get secret <tls-secret-name>

# 步骤 2：验证证书内容
kubectl get secret <tls-secret-name> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text

# 步骤 3：检查证书有效期
kubectl get secret <tls-secret-name> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates

# 步骤 4：创建新的 TLS Secret
kubectl create secret tls <tls-secret-name> \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key

# 步骤 5：更新 Ingress 引用
kubectl patch ingress <ingress-name> -p '{
  "spec": {
    "tls": [{
      "hosts": ["example.com"],
      "secretName": "<tls-secret-name>"
    }]
  }
}'

# 步骤 6：验证 TLS
curl -vk https://<ingress-ip> -H "Host: <hostname>"
openssl s_client -connect <ingress-ip>:443 -servername <hostname>
```

#### 3.4.2 安全生产风险提示

```
⚠️  安全生产风险提示：
1. TLS Secret 包含私钥，需要保护
2. 证书更新会立即生效
3. 证书域名必须匹配 Ingress host
4. 定期检查证书有效期
5. 考虑使用 cert-manager 自动管理
```

---

## 附录

### A. Service 类型对比

| 类型 | 访问范围 | External IP | 端口 |
|------|----------|-------------|------|
| ClusterIP | 集群内 | 无 | 任意 |
| NodePort | 集群外 | 节点 IP | 30000-32767 |
| LoadBalancer | 集群外 | 云 LB IP | 任意 |
| ExternalName | DNS 别名 | 无 | - |

### B. 常用 Ingress Annotations

| Annotation | 说明 | 示例值 |
|------------|------|--------|
| `nginx.ingress.kubernetes.io/rewrite-target` | 路径重写 | `/` |
| `nginx.ingress.kubernetes.io/ssl-redirect` | HTTPS 重定向 | `"true"` |
| `nginx.ingress.kubernetes.io/proxy-body-size` | 请求体大小 | `"50m"` |
| `nginx.ingress.kubernetes.io/proxy-connect-timeout` | 连接超时 | `"30"` |

### C. 排查清单

- [ ] Service selector 匹配 Pod labels
- [ ] Pod 状态为 Ready
- [ ] Endpoints 不为空
- [ ] 端口配置正确
- [ ] kube-proxy 规则存在
- [ ] Ingress Controller 正常
- [ ] TLS Secret 有效
- [ ] 网络策略未阻止流量
