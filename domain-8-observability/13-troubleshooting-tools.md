# 100 - 故障排查增强工具

> **适用版本**: Kubernetes v1.25 - v1.32 | **难度**: 中高级 | **参考**: [K9s](https://k9scli.io/) | [Netshoot](https://github.com/nicolaka/netshoot) | [kubectl-debug](https://github.com/aylei/kubectl-debug)

## 一、故障排查工具体系

### 1.1 Kubernetes故障排查工具全景

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                     Kubernetes Troubleshooting Tools Ecosystem                       │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌────────────────────────────────────────────────────────────────────────────────┐ │
│  │                            Interactive TUI Tools                                │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │ │
│  │  │     K9s      │  │    Lens      │  │   Octant     │  │   Headlamp   │       │ │
│  │  │              │  │              │  │              │  │              │       │ │
│  │  │ • Terminal   │  │ • Desktop    │  │ • Web UI     │  │ • Web UI     │       │ │
│  │  │ • Fast nav   │  │ • Multi-     │  │ • Plugin     │  │ • In-cluster │       │ │
│  │  │ • Logs/Shell │  │   cluster    │  │   system     │  │ • OIDC auth  │       │ │
│  │  │ • Plugins    │  │ • Extensions │  │ • Resource   │  │ • Multi-     │       │ │
│  │  │              │  │              │  │   viewer     │  │   tenant     │       │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘       │ │
│  └────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                      │
│  ┌────────────────────────────────────────────────────────────────────────────────┐ │
│  │                             Debug Containers                                    │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │ │
│  │  │   Netshoot   │  │   Busybox    │  │   Alpine     │  │   Ubuntu     │       │ │
│  │  │              │  │              │  │              │  │              │       │ │
│  │  │ • Network    │  │ • Basic      │  │ • Light-     │  │ • Full       │       │ │
│  │  │   tools      │  │   utils      │  │   weight     │  │   toolset    │       │ │
│  │  │ • tcpdump    │  │ • sh/ash     │  │ • Package    │  │ • apt-get    │       │ │
│  │  │ • curl/wget  │  │ • nc/wget    │  │   manager    │  │ • systemd    │       │ │
│  │  │ • dig/nslook │  │              │  │              │  │              │       │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘       │ │
│  └────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                      │
│  ┌────────────────────────────────────────────────────────────────────────────────┐ │
│  │                           kubectl Plugins (krew)                                │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐         │ │
│  │  │  debug   │  │  trace   │  │  sniff   │  │  tree    │  │  neat    │         │ │
│  │  │          │  │          │  │          │  │          │  │          │         │ │
│  │  │ • Epheme │  │ • eBPF   │  │ • Packet │  │ • Owner  │  │ • Clean  │         │ │
│  │  │   -ral   │  │ • Tracing│  │   capture│  │   refs   │  │   output │         │ │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘         │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐         │ │
│  │  │  images  │  │  ctx     │  │  ns      │  │  node-   │  │  access- │         │ │
│  │  │          │  │          │  │          │  │  shell   │  │  matrix  │         │ │
│  │  │ • Image  │  │ • Switch │  │ • Switch │  │ • Node   │  │ • RBAC   │         │ │
│  │  │   info   │  │   context│  │   ns     │  │   debug  │  │   check  │         │ │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘         │ │
│  └────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                      │
│  ┌────────────────────────────────────────────────────────────────────────────────┐ │
│  │                              Log Tools                                          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │ │
│  │  │    Stern     │  │    Loki      │  │   kail       │  │   kubetail   │       │ │
│  │  │              │  │              │  │              │  │              │       │ │
│  │  │ • Multi-pod  │  │ • Log aggr   │  │ • Stream     │  │ • Tail       │       │ │
│  │  │ • Regex      │  │ • Grafana    │  │ • Label      │  │   multiple   │       │ │
│  │  │ • Colors     │  │ • LogQL      │  │   selector   │  │ • Simple     │       │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘       │ │
│  └────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                      │
│  ┌────────────────────────────────────────────────────────────────────────────────┐ │
│  │                           Network Debug Tools                                   │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │ │
│  │  │ Telepresence │  │   kubefwd    │  │   ksniff     │  │   Cilium     │       │ │
│  │  │              │  │              │  │              │  │   CLI        │       │ │
│  │  │ • Intercept  │  │ • Port-fwd   │  │ • tcpdump    │  │ • Policy     │       │ │
│  │  │ • Local dev  │  │ • Bulk fwd   │  │ • Wireshark  │  │ • Flow       │       │ │
│  │  │ • VPN-like   │  │ • DNS rewr   │  │ • eBPF       │  │ • Hubble     │       │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘       │ │
│  └────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 故障排查工具对比

| 工具 | 类型 | 主要功能 | 学习曲线 | 适用场景 | 安装方式 |
|-----|------|---------|---------|---------|---------|
| **K9s** | TUI | 集群管理/日志/Shell | 低 | 日常运维 | Binary |
| **Netshoot** | 容器 | 网络诊断 | 低 | 网络问题 | Image |
| **kubectl-debug** | 插件 | 容器调试 | 中 | 深度调试 | krew |
| **Stern** | CLI | 多Pod日志 | 低 | 日志聚合 | Binary |
| **Telepresence** | CLI | 本地开发 | 中 | 开发调试 | Binary |
| **ksniff** | 插件 | 抓包分析 | 中 | 网络分析 | krew |
| **kubefwd** | CLI | 批量端口转发 | 低 | 本地开发 | Binary |
| **Lens** | Desktop | 可视化管理 | 低 | 团队协作 | Desktop |

---

## 二、K9s高效运维

### 2.1 K9s安装与配置

```bash
#!/bin/bash
# k9s-setup.sh - K9s安装与配置

# 安装方式
# macOS
brew install derailed/k9s/k9s

# Linux
curl -sS https://webinstall.dev/k9s | bash

# 或从GitHub下载
K9S_VERSION="v0.31.7"
wget https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz
tar -xzf k9s_Linux_amd64.tar.gz
sudo mv k9s /usr/local/bin/

# 配置文件位置
# Linux/macOS: ~/.config/k9s/
# Windows: %LOCALAPPDATA%\k9s\
```

### 2.2 K9s配置文件

```yaml
# ~/.config/k9s/config.yaml
k9s:
  # 刷新率
  refreshRate: 2
  
  # 最大连接重试
  maxConnRetry: 5
  
  # 只读模式
  readOnly: false
  
  # 无头模式 (无表头)
  noHeader: false
  
  # Logo显示
  logoless: false
  
  # 崩溃报告
  crumbsless: false
  
  # 无图标模式
  noIcons: false
  
  # 日志配置
  logger:
    tail: 100
    buffer: 5000
    sinceSeconds: 60
    textWrap: false
    showTime: false
  
  # 当前集群
  currentContext: production
  currentCluster: production
  
  # 集群配置
  clusters:
    production:
      namespace:
        active: default
        lockFavorites: false
        favorites:
        - default
        - kube-system
        - production
        - monitoring
      view:
        active: pod
      featureGates:
        nodeShell: true
      shellPod:
        image: nicolaka/netshoot:latest
        namespace: default
        limits:
          cpu: 100m
          memory: 100Mi
      portForwardAddress: localhost
---
# ~/.config/k9s/views.yaml - 自定义视图
k9s:
  views:
    v1/pods:
      columns:
        - AGE
        - NAMESPACE
        - NAME
        - READY
        - STATUS
        - RESTARTS
        - CPU
        - MEM
        - %CPU/R
        - %MEM/R
        - IP
        - NODE
    
    v1/services:
      columns:
        - AGE
        - NAMESPACE
        - NAME
        - TYPE
        - CLUSTER-IP
        - EXTERNAL-IP
        - PORTS
        - SELECTOR
    
    apps/v1/deployments:
      columns:
        - AGE
        - NAMESPACE
        - NAME
        - READY
        - UP-TO-DATE
        - AVAILABLE
        - CONTAINERS
        - IMAGES
    
    v1/nodes:
      columns:
        - NAME
        - STATUS
        - ROLES
        - VERSION
        - INTERNAL-IP
        - CPU
        - MEM
        - %CPU
        - %MEM
---
# ~/.config/k9s/hotkeys.yaml - 自定义快捷键
hotKeys:
  # 快速切换命名空间
  shift-1:
    shortCut: Shift-1
    description: Switch to default namespace
    command: namespace default
  shift-2:
    shortCut: Shift-2
    description: Switch to production namespace
    command: namespace production
  shift-3:
    shortCut: Shift-3
    description: Switch to monitoring namespace
    command: namespace monitoring
  
  # 快速执行命令
  shift-d:
    shortCut: Shift-D
    description: Delete resource
    command: delete
  shift-l:
    shortCut: Shift-L
    description: View logs
    command: logs
  shift-s:
    shortCut: Shift-S
    description: Shell into container
    command: shell
  
  # 自定义命令
  ctrl-r:
    shortCut: Ctrl-R
    description: Rollout restart
    command: |
      kubectl rollout restart deploy/$NAME -n $NAMESPACE
---
# ~/.config/k9s/plugins.yaml - 插件配置
plugins:
  # 调试容器
  debug:
    shortCut: Shift-D
    description: Add debug container
    scopes:
    - pods
    command: kubectl
    background: false
    args:
    - debug
    - -it
    - $NAME
    - -n
    - $NAMESPACE
    - --image=nicolaka/netshoot
    - --target=$NAME
  
  # 查看资源使用
  resource-usage:
    shortCut: Shift-R
    description: View resource usage
    scopes:
    - pods
    command: sh
    background: false
    args:
    - -c
    - |
      kubectl top pod $NAME -n $NAMESPACE --containers
  
  # 查看事件
  events:
    shortCut: Shift-E
    description: View events for resource
    scopes:
    - pods
    - deployments
    - services
    command: sh
    background: false
    args:
    - -c
    - |
      kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$NAME --sort-by='.lastTimestamp'
  
  # 端口转发
  port-forward:
    shortCut: Shift-P
    description: Port forward
    scopes:
    - pods
    - services
    command: sh
    background: true
    args:
    - -c
    - |
      kubectl port-forward $NAME -n $NAMESPACE 8080:80
  
  # 导出YAML
  export-yaml:
    shortCut: Shift-Y
    description: Export YAML
    scopes:
    - all
    command: sh
    background: false
    args:
    - -c
    - |
      kubectl get $RESOURCE_NAME $NAME -n $NAMESPACE -o yaml | kubectl neat
  
  # Helm历史
  helm-history:
    shortCut: Shift-H
    description: Helm release history
    scopes:
    - helm
    command: sh
    background: false
    args:
    - -c
    - |
      helm history $NAME -n $NAMESPACE
  
  # 查看镜像漏洞
  trivy-scan:
    shortCut: Ctrl-T
    description: Scan image with Trivy
    scopes:
    - pods
    command: sh
    background: false
    args:
    - -c
    - |
      IMAGE=$(kubectl get pod $NAME -n $NAMESPACE -o jsonpath='{.spec.containers[0].image}')
      trivy image --severity HIGH,CRITICAL $IMAGE
```

### 2.3 K9s快捷键速查

| 快捷键 | 功能 | 说明 |
|-------|------|------|
| **导航** |
| `:pod` | 切换到Pod视图 | 可输入任何资源类型 |
| `:ns` | 切换到Namespace视图 | |
| `:dp` | 切换到Deployment视图 | |
| `:svc` | 切换到Service视图 | |
| `:no` | 切换到Node视图 | |
| `/` | 过滤资源 | 支持正则表达式 |
| `Esc` | 返回/取消过滤 | |
| **操作** |
| `Enter` | 查看详情/进入 | |
| `d` | Describe资源 | |
| `y` | 查看YAML | |
| `l` | 查看日志 | |
| `s` | 进入Shell | |
| `e` | 编辑资源 | |
| `Ctrl-D` | 删除资源 | |
| `Ctrl-K` | 强制删除 | |
| **日志** |
| `0` | 查看所有容器日志 | |
| `1-9` | 查看指定容器日志 | |
| `w` | 切换自动换行 | |
| `t` | 切换显示时间戳 | |
| `f` | 全屏日志 | |
| `Ctrl-S` | 保存日志 | |
| **其他** |
| `?` | 帮助 | |
| `:q` | 退出 | |
| `:ctx` | 切换Context | |
| `Ctrl-A` | 查看所有命名空间 | |

---

## 三、Netshoot网络诊断

### 3.1 Netshoot部署方式

```bash
#!/bin/bash
# netshoot-debug.sh - Netshoot网络诊断

# 方式1: 临时Pod
kubectl run netshoot --rm -it \
    --image=nicolaka/netshoot \
    --restart=Never \
    -- bash

# 方式2: 临时Pod (指定命名空间)
kubectl run netshoot --rm -it \
    --image=nicolaka/netshoot \
    --restart=Never \
    -n production \
    -- bash

# 方式3: Ephemeral Container (K8s 1.25+)
kubectl debug -it <pod-name> \
    --image=nicolaka/netshoot \
    --target=<container-name> \
    -- bash

# 方式4: 复制Pod并添加调试容器
kubectl debug <pod-name> \
    --copy-to=<pod-name>-debug \
    --container=debug \
    --image=nicolaka/netshoot \
    -- sleep infinity

# 方式5: 节点调试
kubectl debug node/<node-name> \
    -it \
    --image=nicolaka/netshoot
```

### 3.2 Netshoot诊断命令大全

```bash
#!/bin/bash
# netshoot-commands.sh - Netshoot诊断命令集

# ========================
# DNS诊断
# ========================

# 基本DNS查询
nslookup kubernetes.default
nslookup myservice.myns.svc.cluster.local

# 详细DNS查询
dig kubernetes.default.svc.cluster.local
dig @10.96.0.10 myservice.production.svc.cluster.local +short

# DNS服务器测试
dig @10.96.0.10 any kubernetes.default.svc.cluster.local

# 反向DNS查询
dig -x 10.244.1.5

# DNS延迟测试
time dig myservice.production.svc.cluster.local

# 查看/etc/resolv.conf
cat /etc/resolv.conf

# ========================
# 网络连通性测试
# ========================

# Ping测试
ping -c 3 <pod-ip>
ping -c 3 <service-cluster-ip>

# TCP连接测试
nc -zv <service-name> <port>
nc -zv myservice.production 80

# HTTP请求测试
curl -v http://myservice.production:80/healthz
curl -sS http://myservice:8080/api/status | jq .

# 带超时的测试
curl --connect-timeout 5 --max-time 10 http://myservice:80

# HTTPS测试
curl -k https://kubernetes.default.svc:443/healthz

# ========================
# 路由与网络
# ========================

# 查看路由表
ip route
route -n

# 路由追踪
traceroute <target-ip>
mtr -n <target-ip>

# 查看网络接口
ip addr
ifconfig

# 查看ARP表
arp -n
ip neigh

# 查看iptables规则
iptables -L -n -v
iptables -t nat -L -n -v

# ========================
# 抓包分析
# ========================

# 基本抓包
tcpdump -i eth0 -n

# 抓取特定端口
tcpdump -i eth0 -nn port 80

# 抓取特定IP
tcpdump -i eth0 -nn host 10.244.1.5

# 抓包并保存
tcpdump -i eth0 -nn -w capture.pcap port 80

# 抓取HTTP请求
tcpdump -i eth0 -A -s 0 'tcp port 80 and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)'

# ========================
# 带宽与延迟测试
# ========================

# iperf3 服务端
iperf3 -s

# iperf3 客户端
iperf3 -c <server-ip>

# 网络延迟测试
hping3 -S -p 80 -c 10 <target-ip>

# ========================
# SSL/TLS诊断
# ========================

# 检查证书
openssl s_client -connect myservice:443 -showcerts

# 检查证书有效期
echo | openssl s_client -connect myservice:443 2>/dev/null | openssl x509 -noout -dates

# 测试TLS版本
openssl s_client -connect myservice:443 -tls1_2
openssl s_client -connect myservice:443 -tls1_3

# ========================
# 进程与端口
# ========================

# 查看监听端口
ss -tlnp
netstat -tlnp

# 查看连接状态
ss -tanp
netstat -tanp

# 查看进程
ps aux

# ========================
# HTTP调试
# ========================

# 详细HTTP请求
curl -v -X GET http://myservice:80/api/health

# 带Header请求
curl -H "Authorization: Bearer token" http://myservice:80/api/data

# POST请求
curl -X POST -H "Content-Type: application/json" \
    -d '{"key":"value"}' \
    http://myservice:80/api/create

# 跟踪重定向
curl -L -v http://myservice:80/redirect

# HTTP/2测试
curl --http2 -v https://myservice:443/
```

### 3.3 常见网络问题诊断流程

```bash
#!/bin/bash
# network-troubleshoot.sh - 网络故障排查流程

diagnose_network() {
    local target_pod=$1
    local target_ns=${2:-default}
    local target_port=${3:-80}
    
    echo "=== 网络诊断报告 ==="
    echo "目标: $target_pod.$target_ns:$target_port"
    echo ""
    
    # 1. DNS解析
    echo "--- 1. DNS解析测试 ---"
    DNS_RESULT=$(nslookup $target_pod.$target_ns.svc.cluster.local 2>&1)
    if echo "$DNS_RESULT" | grep -q "Address:"; then
        echo "DNS解析: 成功"
        echo "$DNS_RESULT" | grep "Address:" | tail -1
    else
        echo "DNS解析: 失败"
        echo "检查CoreDNS是否正常运行:"
        echo "  kubectl get pods -n kube-system -l k8s-app=kube-dns"
        return 1
    fi
    echo ""
    
    # 2. 获取Service ClusterIP
    echo "--- 2. Service信息 ---"
    kubectl get svc $target_pod -n $target_ns -o wide 2>/dev/null || \
        echo "Service不存在或无法访问"
    echo ""
    
    # 3. 检查Endpoints
    echo "--- 3. Endpoints检查 ---"
    ENDPOINTS=$(kubectl get endpoints $target_pod -n $target_ns -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
    if [ -n "$ENDPOINTS" ]; then
        echo "Endpoints: $ENDPOINTS"
    else
        echo "Endpoints为空! 检查:"
        echo "  - Pod是否健康且Ready"
        echo "  - Service selector是否匹配Pod labels"
        return 1
    fi
    echo ""
    
    # 4. TCP连接测试
    echo "--- 4. TCP连接测试 ---"
    for ep in $ENDPOINTS; do
        if nc -zv -w 3 $ep $target_port 2>&1 | grep -q "succeeded"; then
            echo "端点 $ep:$target_port 连接成功"
        else
            echo "端点 $ep:$target_port 连接失败"
        fi
    done
    echo ""
    
    # 5. HTTP请求测试
    echo "--- 5. HTTP请求测试 ---"
    HTTP_RESULT=$(curl -sS -o /dev/null -w "%{http_code}" \
        --connect-timeout 5 \
        http://$target_pod.$target_ns:$target_port/ 2>&1)
    echo "HTTP状态码: $HTTP_RESULT"
    echo ""
    
    # 6. 网络策略检查
    echo "--- 6. NetworkPolicy检查 ---"
    NP_COUNT=$(kubectl get networkpolicy -n $target_ns -o json 2>/dev/null | \
        jq '.items | length')
    if [ "$NP_COUNT" -gt 0 ]; then
        echo "命名空间有 $NP_COUNT 个NetworkPolicy"
        echo "可能影响流量,请检查策略规则"
        kubectl get networkpolicy -n $target_ns
    else
        echo "无NetworkPolicy限制"
    fi
    
    echo ""
    echo "=== 诊断完成 ==="
}

# 使用示例
# diagnose_network "myservice" "production" "8080"
```

---

## 四、kubectl-debug深度调试

### 4.1 Ephemeral Containers调试

```bash
#!/bin/bash
# ephemeral-debug.sh - Ephemeral Container调试

# 1. 基本调试
kubectl debug -it <pod-name> \
    --image=busybox \
    --target=<container-name>

# 2. 使用Netshoot调试
kubectl debug -it <pod-name> \
    --image=nicolaka/netshoot \
    --target=<container-name> \
    -- bash

# 3. 共享进程命名空间调试
kubectl debug -it <pod-name> \
    --image=busybox \
    --target=<container-name> \
    --share-processes \
    -- sh

# 4. 调试CrashLoopBackOff的Pod
kubectl debug <pod-name> \
    --copy-to=<pod-name>-debug \
    --container=debug \
    --image=busybox \
    -- sleep infinity

# 然后进入调试Pod
kubectl exec -it <pod-name>-debug -c debug -- sh

# 5. 修改镜像调试 (启动命令变为sleep)
kubectl debug <pod-name> \
    --copy-to=<pod-name>-debug \
    --set-image=*=busybox \
    -- sleep infinity

# 6. 节点调试
kubectl debug node/<node-name> \
    -it \
    --image=ubuntu \
    -- bash

# 进入节点后访问主机文件系统
# chroot /host
```

### 4.2 krew插件安装与使用

```bash
#!/bin/bash
# krew-plugins.sh - krew插件管理

# 安装krew
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

# 添加到PATH
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# 更新插件索引
kubectl krew update

# 安装常用插件
kubectl krew install debug        # 容器调试
kubectl krew install trace       # eBPF追踪
kubectl krew install sniff       # 抓包分析
kubectl krew install tree        # 资源关系树
kubectl krew install neat        # 清理YAML输出
kubectl krew install ctx         # Context切换
kubectl krew install ns          # Namespace切换
kubectl krew install images      # 镜像信息
kubectl krew install access-matrix # RBAC矩阵
kubectl krew install node-shell  # 节点Shell
kubectl krew install resource-capacity # 资源容量
kubectl krew install view-secret # 查看Secret
kubectl krew install whoami      # 当前用户信息
kubectl krew install get-all     # 获取所有资源
kubectl krew install fleet       # 多集群管理
kubectl krew install df-pv       # PV使用情况
kubectl krew install cert-manager # 证书管理

# 列出已安装插件
kubectl krew list

# 使用示例
kubectl tree deployment/nginx        # 查看资源关系
kubectl neat get pod nginx -o yaml   # 清理YAML输出
kubectl ctx production              # 切换context
kubectl ns monitoring               # 切换namespace
kubectl access-matrix               # 查看RBAC权限
kubectl node-shell <node-name>      # 进入节点
kubectl resource-capacity           # 查看资源容量
kubectl view-secret mysecret        # 查看Secret内容
kubectl whoami                      # 当前用户
kubectl get-all -n production       # 获取所有资源
kubectl df-pv                       # PV使用情况
```

### 4.3 kubectl-trace eBPF追踪

```bash
#!/bin/bash
# kubectl-trace.sh - eBPF追踪

# 安装
kubectl krew install trace

# 1. 追踪Pod系统调用
kubectl trace run <pod-name> -e 'tracepoint:syscalls:sys_enter_* { @[comm] = count(); }'

# 2. 追踪文件打开
kubectl trace run <pod-name> -e '
tracepoint:syscalls:sys_enter_openat {
    printf("%s opened %s\n", comm, str(args->filename));
}'

# 3. 追踪网络连接
kubectl trace run <pod-name> -e '
tracepoint:syscalls:sys_enter_connect {
    printf("%s connecting...\n", comm);
}'

# 4. 追踪进程创建
kubectl trace run <pod-name> -e '
tracepoint:syscalls:sys_enter_execve {
    printf("%s executing %s\n", comm, str(args->filename));
}'

# 5. 追踪Node
kubectl trace run node/<node-name> -e '
tracepoint:syscalls:sys_enter_* {
    @[probe] = count();
}'

# 6. 追踪特定时间
kubectl trace run <pod-name> \
    --timeout=60s \
    -e 'tracepoint:syscalls:sys_enter_read { @[comm] = count(); }'
```

---

## 五、Stern多Pod日志

### 5.1 Stern安装与基本使用

```bash
#!/bin/bash
# stern-usage.sh - Stern日志聚合

# 安装
# macOS
brew install stern

# Linux
wget https://github.com/stern/stern/releases/download/v1.28.0/stern_1.28.0_linux_amd64.tar.gz
tar -xzf stern_1.28.0_linux_amd64.tar.gz
sudo mv stern /usr/local/bin/

# ========================
# 基本用法
# ========================

# 查看匹配名称的所有Pod日志
stern myapp

# 正则匹配
stern "myapp-.*"
stern "^nginx-"

# 指定命名空间
stern -n production myapp

# 所有命名空间
stern --all-namespaces myapp

# ========================
# 过滤选项
# ========================

# 按标签过滤
stern -l app=nginx
stern -l "app in (nginx, apache)"

# 按容器名过滤
stern --container "^main$" myapp
stern -c sidecar myapp

# 排除容器
stern --exclude-container istio-proxy myapp

# 排除Pod
stern --exclude ".*-debug" myapp

# ========================
# 时间过滤
# ========================

# 最近1小时
stern --since 1h myapp

# 最近10分钟
stern --since 10m myapp

# 指定时间之后
stern --since-time "2024-01-15T10:00:00Z" myapp

# ========================
# 输出格式
# ========================

# JSON输出
stern --output json myapp

# 原始输出 (无前缀)
stern --output raw myapp

# 自定义模板
stern --template '{{.PodName}} {{.ContainerName}} {{.Message}}' myapp

# 带时间戳
stern --timestamps myapp

# ========================
# 高级用法
# ========================

# 高亮关键词
stern myapp | grep --color=always -E "error|Error|ERROR|"

# 输出到文件
stern myapp > myapp.log

# 仅显示匹配行
stern myapp --include "error"

# 排除特定内容
stern myapp --exclude "health check"

# 同时查看多个应用
stern "frontend|backend|database"

# 按上下文
stern --context production myapp
```

### 5.2 Stern与其他工具结合

```bash
#!/bin/bash
# stern-advanced.sh - Stern高级用法

# 1. 结合jq处理JSON日志
stern --output json myapp | jq 'select(.level == "error")'

# 2. 实时统计错误
stern myapp | grep -c "error" --line-buffered

# 3. 发送到日志系统
stern myapp | nc -u logserver 514

# 4. 结合watch监控
watch -n 5 "stern --since 5s myapp | tail -20"

# 5. 错误告警脚本
stern myapp --output json | while read line; do
    level=$(echo $line | jq -r '.level // empty')
    if [ "$level" = "error" ]; then
        message=$(echo $line | jq -r '.message')
        # 发送告警
        curl -X POST -H "Content-Type: application/json" \
            -d "{\"text\": \"Error in myapp: $message\"}" \
            $SLACK_WEBHOOK_URL
    fi
done

# 6. 日志分析
stern --since 1h myapp --output json > logs.json
cat logs.json | jq -r '.level' | sort | uniq -c | sort -rn
```

---

## 六、Telepresence本地调试

### 6.1 Telepresence安装与配置

```bash
#!/bin/bash
# telepresence-setup.sh - Telepresence设置

# 安装
# macOS
brew install datawire/blackbird/telepresence

# Linux
sudo curl -fL https://app.getambassador.io/download/tel2/linux/amd64/latest/telepresence -o /usr/local/bin/telepresence
sudo chmod a+x /usr/local/bin/telepresence

# 连接到集群
telepresence connect

# 查看状态
telepresence status

# 列出可拦截的服务
telepresence list

# 断开连接
telepresence quit
```

### 6.2 Telepresence流量拦截

```bash
#!/bin/bash
# telepresence-intercept.sh - 流量拦截

# 1. 全局拦截 (所有流量)
telepresence intercept myservice --port 8080:80

# 2. 个人拦截 (基于Header)
telepresence intercept myservice \
    --port 8080:80 \
    --http-header x-telepresence-intercept-id=my-intercept

# 3. 带环境变量
telepresence intercept myservice \
    --port 8080:80 \
    --env-file myservice.env

# 4. 挂载远程卷
telepresence intercept myservice \
    --port 8080:80 \
    --mount /tmp/myservice

# 5. 指定命名空间
telepresence intercept myservice \
    --namespace production \
    --port 8080:80

# 6. 启动后运行本地服务
telepresence intercept myservice --port 8080:80 -- ./myservice

# 7. 查看拦截状态
telepresence status

# 8. 离开拦截
telepresence leave myservice

# ========================
# 本地开发示例
# ========================

# 步骤1: 连接集群
telepresence connect

# 步骤2: 拦截服务
telepresence intercept myservice --port 8080:80 --env-file .env

# 步骤3: 加载环境变量
source .env

# 步骤4: 运行本地服务
./myservice --port 8080

# 现在:
# - 发往myservice的流量会路由到本地
# - 本地服务可以访问集群内其他服务
# - 可以使用本地调试器

# 步骤5: 完成后退出
telepresence leave myservice
telepresence quit
```

---

## 七、故障排查流程与脚本

### 7.1 系统化故障排查流程

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Kubernetes Troubleshooting Flowchart                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐                                                            │
│  │  发现问题    │                                                            │
│  └──────┬───────┘                                                            │
│         │                                                                    │
│         ▼                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                     确定问题层面                                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│         │                                                                    │
│    ┌────┼────┬─────────┬─────────┬─────────┐                               │
│    │    │    │         │         │         │                               │
│    ▼    ▼    ▼         ▼         ▼         ▼                               │
│  ┌────┐ ┌────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                        │
│  │Pod │ │Node│ │Network│ │Storage│ │RBAC │ │Config│                        │
│  │问题│ │问题│ │ 问题  │ │ 问题  │ │问题 │ │ 问题 │                        │
│  └─┬──┘ └─┬──┘ └──┬───┘ └──┬───┘ └──┬──┘ └──┬───┘                        │
│    │      │       │        │        │       │                               │
│    ▼      ▼       ▼        ▼        ▼       ▼                               │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                      诊断命令                                       │    │
│  │                                                                      │    │
│  │  Pod:     kubectl describe pod, kubectl logs, kubectl exec         │    │
│  │  Node:    kubectl describe node, kubectl top node, dmesg           │    │
│  │  Network: nslookup, curl, tcpdump, iptables                        │    │
│  │  Storage: kubectl describe pvc, df -h, mount                        │    │
│  │  RBAC:    kubectl auth can-i, kubectl get rolebindings             │    │
│  │  Config:  kubectl get cm, kubectl get secret                        │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│         │                                                                    │
│         ▼                                                                    │
│  ┌──────────────┐                                                            │
│  │  分析原因    │                                                            │
│  └──────┬───────┘                                                            │
│         │                                                                    │
│         ▼                                                                    │
│  ┌──────────────┐                                                            │
│  │  实施修复    │                                                            │
│  └──────┬───────┘                                                            │
│         │                                                                    │
│         ▼                                                                    │
│  ┌──────────────┐                                                            │
│  │  验证恢复    │                                                            │
│  └──────────────┘                                                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 一键诊断脚本

```bash
#!/bin/bash
# k8s-diagnose.sh - Kubernetes一键诊断脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 诊断函数
diagnose_pod() {
    local pod=$1
    local ns=${2:-default}
    
    echo ""
    echo "=========================================="
    echo "诊断Pod: $ns/$pod"
    echo "=========================================="
    
    # 1. Pod状态
    log_info "1. Pod状态"
    kubectl get pod $pod -n $ns -o wide
    
    # 2. Pod详情
    log_info "2. Pod Events"
    kubectl describe pod $pod -n $ns | grep -A 20 "Events:"
    
    # 3. 容器状态
    log_info "3. 容器状态"
    kubectl get pod $pod -n $ns -o jsonpath='{range .status.containerStatuses[*]}{.name}: {.state}{"\n"}{end}'
    
    # 4. 最近日志
    log_info "4. 最近日志 (最后50行)"
    kubectl logs $pod -n $ns --tail=50 --all-containers 2>/dev/null || \
        log_warn "无法获取日志"
    
    # 5. 资源使用
    log_info "5. 资源使用"
    kubectl top pod $pod -n $ns 2>/dev/null || \
        log_warn "无法获取资源使用 (需要metrics-server)"
    
    # 6. 重启历史
    log_info "6. 重启次数"
    kubectl get pod $pod -n $ns -o jsonpath='{range .status.containerStatuses[*]}{.name}: {.restartCount} restarts{"\n"}{end}'
}

diagnose_deployment() {
    local deploy=$1
    local ns=${2:-default}
    
    echo ""
    echo "=========================================="
    echo "诊断Deployment: $ns/$deploy"
    echo "=========================================="
    
    # 1. Deployment状态
    log_info "1. Deployment状态"
    kubectl get deployment $deploy -n $ns -o wide
    
    # 2. ReplicaSet
    log_info "2. ReplicaSets"
    kubectl get rs -n $ns -l app=$deploy
    
    # 3. Pod列表
    log_info "3. Pods"
    kubectl get pods -n $ns -l app=$deploy -o wide
    
    # 4. Events
    log_info "4. Events"
    kubectl describe deployment $deploy -n $ns | grep -A 10 "Events:"
    
    # 5. 滚动更新状态
    log_info "5. Rollout状态"
    kubectl rollout status deployment/$deploy -n $ns --timeout=5s 2>/dev/null || \
        log_warn "Rollout未完成或超时"
}

diagnose_service() {
    local svc=$1
    local ns=${2:-default}
    
    echo ""
    echo "=========================================="
    echo "诊断Service: $ns/$svc"
    echo "=========================================="
    
    # 1. Service详情
    log_info "1. Service详情"
    kubectl get svc $svc -n $ns -o wide
    
    # 2. Endpoints
    log_info "2. Endpoints"
    kubectl get endpoints $svc -n $ns
    
    # 3. 连通性测试
    log_info "3. DNS解析"
    kubectl run dns-test --rm -it --restart=Never \
        --image=busybox:1.28 \
        -- nslookup $svc.$ns.svc.cluster.local 2>/dev/null || \
        log_warn "DNS测试失败"
}

diagnose_node() {
    local node=$1
    
    echo ""
    echo "=========================================="
    echo "诊断Node: $node"
    echo "=========================================="
    
    # 1. Node状态
    log_info "1. Node状态"
    kubectl get node $node -o wide
    
    # 2. Node Conditions
    log_info "2. Node Conditions"
    kubectl describe node $node | grep -A 15 "Conditions:"
    
    # 3. 资源使用
    log_info "3. 资源分配"
    kubectl describe node $node | grep -A 10 "Allocated resources:"
    
    # 4. Pod分布
    log_info "4. 运行的Pods"
    kubectl get pods --all-namespaces --field-selector spec.nodeName=$node -o wide
    
    # 5. Taints
    log_info "5. Taints"
    kubectl describe node $node | grep "Taints:"
}

diagnose_cluster() {
    echo ""
    echo "=========================================="
    echo "集群健康检查"
    echo "=========================================="
    
    # 1. 组件状态
    log_info "1. 控制面组件"
    kubectl get componentstatuses 2>/dev/null || \
        kubectl get pods -n kube-system -l tier=control-plane
    
    # 2. Node状态
    log_info "2. Node状态"
    kubectl get nodes -o wide
    
    # 3. 系统Pod
    log_info "3. 系统Pods"
    kubectl get pods -n kube-system
    
    # 4. 资源使用
    log_info "4. 资源使用概览"
    kubectl top nodes 2>/dev/null || log_warn "无法获取资源使用"
    
    # 5. 最近Events
    log_info "5. 最近集群Events (Warning)"
    kubectl get events --all-namespaces --field-selector type=Warning \
        --sort-by='.lastTimestamp' | tail -20
    
    # 6. 不健康Pods
    log_info "6. 异常Pods"
    kubectl get pods --all-namespaces --field-selector 'status.phase!=Running,status.phase!=Succeeded'
}

# 主程序
case "$1" in
    pod)
        diagnose_pod "$2" "${3:-default}"
        ;;
    deploy|deployment)
        diagnose_deployment "$2" "${3:-default}"
        ;;
    svc|service)
        diagnose_service "$2" "${3:-default}"
        ;;
    node)
        diagnose_node "$2"
        ;;
    cluster)
        diagnose_cluster
        ;;
    *)
        echo "用法: $0 {pod|deploy|svc|node|cluster} [name] [namespace]"
        echo ""
        echo "示例:"
        echo "  $0 pod nginx default"
        echo "  $0 deploy myapp production"
        echo "  $0 svc myservice"
        echo "  $0 node worker-1"
        echo "  $0 cluster"
        exit 1
        ;;
esac
```

---

## 八、快速参考

### 8.1 常用诊断命令速查

```bash
# Pod诊断
kubectl describe pod <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous
kubectl logs <pod> -n <ns> -c <container>
kubectl exec -it <pod> -n <ns> -- sh
kubectl top pod <pod> -n <ns>

# Deployment诊断
kubectl rollout status deployment/<deploy> -n <ns>
kubectl rollout history deployment/<deploy> -n <ns>
kubectl rollout undo deployment/<deploy> -n <ns>

# Service诊断
kubectl get endpoints <svc> -n <ns>
kubectl describe svc <svc> -n <ns>

# Node诊断
kubectl describe node <node>
kubectl drain <node> --ignore-daemonsets
kubectl uncordon <node>

# Events
kubectl get events -n <ns> --sort-by='.lastTimestamp'
kubectl get events --field-selector type=Warning

# 日志
stern <pod-pattern> -n <ns>
kubectl logs -l app=<label> --all-containers
```

### 8.2 快速诊断检查清单

| 问题类型 | 检查项 | 命令 |
|---------|--------|------|
| **Pod不启动** | Events | `kubectl describe pod` |
| | 镜像拉取 | `kubectl get events --field-selector reason=Failed` |
| | 资源不足 | `kubectl describe node` |
| **Pod崩溃** | 日志 | `kubectl logs --previous` |
| | 资源限制 | `kubectl top pod` |
| | 健康检查 | `kubectl describe pod` |
| **网络问题** | DNS | `nslookup <service>` |
| | Endpoints | `kubectl get endpoints` |
| | NetworkPolicy | `kubectl get networkpolicy` |
| **性能问题** | CPU/内存 | `kubectl top pod/node` |
| | 慢请求 | `curl -w "%{time_total}"` |

---

## 九、最佳实践总结

### 故障排查检查清单

- [ ] **工具准备**: 安装K9s, Stern, kubectl plugins
- [ ] **诊断镜像**: 准备Netshoot等调试镜像
- [ ] **日志聚合**: 配置集中日志系统
- [ ] **监控告警**: Prometheus/Grafana就绪
- [ ] **文档记录**: 维护故障排查手册
- [ ] **演练测试**: 定期故障演练
- [ ] **权限管理**: 调试权限最小化
- [ ] **网络策略**: 允许调试Pod访问

---

**相关文档**: [101-性能分析工具](101-performance-profiling-tools.md) | [98-日志聚合工具](98-log-aggregation-tools.md) | [97-可观测性工具](97-observability-tools.md)

**版本**: K9s 0.31+ | Stern 1.28+ | Telepresence 2.17+ | Netshoot latest
