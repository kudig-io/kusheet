# CNI 网络插件故障排查指南

> **适用版本**: Kubernetes v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 高级

---

## 目录

1. [问题现象与影响分析](#1-问题现象与影响分析)
2. [排查方法与步骤](#2-排查方法与步骤)
3. [解决方案与风险控制](#3-解决方案与风险控制)

---

## 1. 问题现象与影响分析

### 1.1 常见问题现象

#### 1.1.1 CNI 插件不可用

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| CNI 插件未安装 | `network plugin is not ready: cni config uninitialized` | kubelet | kubelet 日志 |
| CNI 配置错误 | `error parsing CNI config` | kubelet | kubelet 日志 |
| CNI 二进制缺失 | `failed to find plugin "xxx" in path` | kubelet | kubelet 日志 |
| CNI DaemonSet 异常 | CrashLoopBackOff | kubectl | `kubectl get pods -n kube-system` |

#### 1.1.2 Pod 网络问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| Pod 无 IP 地址 | `failed to allocate IP address` | CNI 日志 | CNI 日志 |
| Pod 间无法通信 | `connection timeout` | 应用日志 | 应用日志/ping |
| 跨节点通信失败 | `no route to host` | 应用日志 | 应用日志/ping |
| Pod 到外网不通 | `network is unreachable` | 应用日志 | 应用日志/curl |
| IPAM 地址耗尽 | `no available IPs` | CNI 日志 | CNI 日志 |

#### 1.1.3 CNI 组件问题

| 现象 | 报错信息 | 报错来源 | 查看方式 |
|------|----------|----------|----------|
| Calico 节点未就绪 | `calico/node is not ready` | kubectl | `kubectl get pods -n kube-system` |
| Flannel 后端故障 | `failed to initialize VXLAN backend` | flannel 日志 | flannel Pod 日志 |
| Cilium 异常 | `cilium-agent unhealthy` | kubectl | `kubectl get pods -n kube-system` |
| 网络策略不生效 | 流量未被阻止 | 测试 | 网络测试 |

### 1.2 报错查看方式汇总

```bash
# 查看 CNI 配置目录
ls -la /etc/cni/net.d/
cat /etc/cni/net.d/*.conf*

# 查看 CNI 插件目录
ls -la /opt/cni/bin/

# 查看 kubelet CNI 相关日志
journalctl -u kubelet | grep -i cni | tail -50

# 查看 CNI 组件 Pod 状态
kubectl get pods -n kube-system -l k8s-app=calico-node
kubectl get pods -n kube-system -l app=flannel
kubectl get pods -n kube-system -l k8s-app=cilium

# 查看 CNI 组件日志
# Calico
kubectl logs -n kube-system -l k8s-app=calico-node -c calico-node --tail=200

# Flannel
kubectl logs -n kube-system -l app=flannel --tail=200

# Cilium
kubectl logs -n kube-system -l k8s-app=cilium --tail=200

# 查看节点网络状态
ip addr
ip route
bridge fdb show
```

### 1.3 影响面分析

#### 1.3.1 直接影响

| 影响范围 | 影响程度 | 影响描述 |
|----------|----------|----------|
| **Pod 创建** | 可能失败 | Pod 无法获取 IP 地址 |
| **Pod 网络** | 不可用 | Pod 间无法通信 |
| **Service** | 部分影响 | 依赖 Pod 网络的 Service 不可用 |
| **DNS** | 部分影响 | CoreDNS Pod 可能受影响 |

#### 1.3.2 间接影响

| 影响范围 | 影响程度 | 影响描述 |
|----------|----------|----------|
| **应用服务** | 高 | 服务间调用失败 |
| **外部访问** | 部分影响 | 通过 NodePort/LoadBalancer 可能受影响 |
| **监控** | 部分影响 | 监控数据采集可能失败 |
| **日志** | 部分影响 | 日志采集可能失败 |

---

## 2. 排查方法与步骤

### 2.1 排查原理

CNI（Container Network Interface）负责为 Pod 配置网络。排查需要从以下层面：

1. **安装层面**：CNI 插件和配置是否正确安装
2. **组件层面**：CNI DaemonSet 是否正常运行
3. **配置层面**：CNI 配置是否正确
4. **网络层面**：底层网络（VXLAN/IPIP/BGP）是否正常
5. **IPAM 层面**：IP 地址分配是否正常

### 2.2 排查步骤和具体命令

#### 2.2.1 第一步：检查 CNI 安装

```bash
# 检查 CNI 配置文件
ls -la /etc/cni/net.d/
cat /etc/cni/net.d/10-calico.conflist  # Calico
cat /etc/cni/net.d/10-flannel.conflist  # Flannel
cat /etc/cni/net.d/05-cilium.conf  # Cilium

# 检查 CNI 二进制文件
ls -la /opt/cni/bin/

# 检查必需的 CNI 插件
ls /opt/cni/bin/ | grep -E "(calico|flannel|cilium|portmap|bandwidth)"

# 检查 kubelet CNI 配置
cat /var/lib/kubelet/config.yaml | grep -A5 cni

# 或者检查 kubelet 启动参数
ps aux | grep kubelet | grep cni
```

#### 2.2.2 第二步：检查 CNI 组件状态

```bash
# Calico
kubectl get pods -n kube-system -l k8s-app=calico-node -o wide
kubectl get pods -n kube-system -l k8s-app=calico-kube-controllers -o wide
calicoctl node status

# Flannel
kubectl get pods -n kube-system -l app=flannel -o wide

# Cilium
kubectl get pods -n kube-system -l k8s-app=cilium -o wide
cilium status

# 检查 DaemonSet 状态
kubectl get daemonset -n kube-system
```

#### 2.2.3 第三步：检查 Pod 网络

```bash
# 检查 Pod IP 分配
kubectl get pods -A -o wide

# 进入 Pod 检查网络配置
kubectl exec -it <pod-name> -- sh
# 在 Pod 内执行
ip addr
ip route
cat /etc/resolv.conf

# 测试 Pod 间连通性
kubectl exec -it <pod-a> -- ping <pod-b-ip>

# 测试跨节点连通性
# 找到不同节点的 Pod
kubectl get pods -o wide -A | grep -v <current-node>
kubectl exec -it <pod-a> -- ping <pod-on-other-node-ip>
```

#### 2.2.4 第四步：检查网络底层

```bash
# 检查网络接口
ip link show

# 检查 VXLAN 接口（Flannel VXLAN 模式）
ip -d link show flannel.1

# 检查 IPIP 隧道（Calico IPIP 模式）
ip -d link show tunl0

# 检查 BGP 状态（Calico BGP 模式）
calicoctl node status

# 检查路由表
ip route

# 检查 ARP 表
arp -n

# 检查 FDB 表（VXLAN）
bridge fdb show dev flannel.1
```

#### 2.2.5 第五步：检查 IPAM

```bash
# Calico IPAM
calicoctl ipam show
calicoctl ipam check

# 查看 IP Pool
calicoctl get ippool -o wide

# 查看节点 IP 分配
calicoctl get workloadendpoint -A

# Flannel 检查子网分配
cat /run/flannel/subnet.env
etcdctl get /coreos.com/network/subnets --prefix
```

#### 2.2.6 第六步：抓包分析

```bash
# 在节点上抓包
tcpdump -i any host <pod-ip> -nn

# 抓取 VXLAN 流量
tcpdump -i flannel.1 -nn

# 抓取特定端口流量
tcpdump -i any port 4789 -nn  # VXLAN 端口

# 使用 nsenter 进入 Pod 网络命名空间抓包
# 获取 Pod 的 PID
pid=$(crictl inspect <container-id> | jq '.info.pid')
nsenter -t $pid -n tcpdump -i eth0 -nn
```

### 2.3 排查注意事项

| 注意项 | 说明 | 建议 |
|--------|------|------|
| **CNI 版本兼容** | CNI 版本需与 Kubernetes 兼容 | 查看兼容矩阵 |
| **节点防火墙** | 防火墙可能阻止隧道流量 | 检查 iptables 规则 |
| **MTU 设置** | MTU 不匹配导致分片问题 | 检查 MTU 配置 |
| **IP 地址冲突** | Pod CIDR 与节点网络冲突 | 规划网络地址 |

---

## 3. 解决方案与风险控制

### 3.1 CNI 配置未初始化

#### 3.1.1 解决步骤

```bash
# 步骤 1：检查 CNI 配置目录
ls -la /etc/cni/net.d/

# 步骤 2：如果目录为空，检查 CNI DaemonSet
kubectl get pods -n kube-system | grep -E "(calico|flannel|cilium)"

# 步骤 3：检查 DaemonSet 日志
kubectl logs -n kube-system <cni-pod> --tail=100

# 步骤 4：如果 DaemonSet 未部署，安装 CNI
# Calico
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Flannel
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Cilium
helm install cilium cilium/cilium --namespace kube-system

# 步骤 5：等待 CNI Pod 就绪
kubectl rollout status daemonset -n kube-system calico-node

# 步骤 6：验证配置生成
ls -la /etc/cni/net.d/
```

#### 3.1.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **高** | 初次安装 CNI 可能导致已有 Pod 网络中断 | 在新集群操作 |
| **中** | CNI 版本选择影响功能 | 选择稳定版本 |

#### 3.1.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 生产集群不建议更换 CNI 插件
2. 安装 CNI 前确认 Pod CIDR 配置正确
3. 确保所有节点都能访问 CNI 镜像
4. 安装后验证所有节点 CNI Pod 正常
5. 测试 Pod 间连通性
```

### 3.2 Pod 无法获取 IP 地址

#### 3.2.1 解决步骤

```bash
# 步骤 1：检查 CNI 日志
kubectl logs -n kube-system -l k8s-app=calico-node -c calico-node | grep -i "ip"

# 步骤 2：检查 IP Pool 配置
calicoctl get ippool -o yaml

# 步骤 3：检查 IP Pool 是否有可用 IP
calicoctl ipam show

# 步骤 4：如果 IP 耗尽，扩展 IP Pool
calicoctl apply -f - << EOF
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: new-pool
spec:
  cidr: 10.245.0.0/16
  ipipMode: Always
  natOutgoing: true
EOF

# 步骤 5：或者清理未使用的 IP
calicoctl ipam release --ip=<unused-ip>

# 步骤 6：验证 IP 分配
kubectl get pods -A -o wide | grep Pending
```

#### 3.2.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 新 IP Pool 可能与现有网络冲突 | 规划地址空间 |
| **低** | 释放 IP 不影响运行 Pod | 确认 IP 未使用 |

#### 3.2.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 新增 IP Pool 前确认不与现有网络冲突
2. 不要释放正在使用的 IP
3. IP 耗尽是容量问题，考虑扩容
4. 监控 IP Pool 使用率
5. 预留足够的 IP 地址空间
```

### 3.3 跨节点通信失败

#### 3.3.1 解决步骤

```bash
# 步骤 1：确认问题范围
kubectl get pods -o wide -A
# 找到不同节点的 Pod 测试

# 步骤 2：检查节点间网络
# 在节点 A 上
ping <node-b-ip>

# 步骤 3：检查隧道接口
# VXLAN 模式
ip -d link show flannel.1
# IPIP 模式
ip -d link show tunl0

# 步骤 4：检查路由
ip route | grep <other-node-pod-cidr>

# 步骤 5：检查防火墙规则
# VXLAN 需要 UDP 4789
iptables -L -n | grep 4789
# IPIP 需要协议 4
iptables -L -n | grep ipencap

# 步骤 6：如果防火墙阻止，添加规则
# VXLAN
iptables -A INPUT -p udp --dport 4789 -j ACCEPT
# IPIP
iptables -A INPUT -p 4 -j ACCEPT
# BGP
iptables -A INPUT -p tcp --dport 179 -j ACCEPT

# 步骤 7：检查云平台安全组（如果适用）
# 确保安全组允许节点间通信

# 步骤 8：验证修复
kubectl exec -it <pod-a> -- ping <pod-on-other-node-ip>
```

#### 3.3.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | 防火墙规则变更影响安全 | 仅开放必要端口 |
| **低** | 网络检查无风险 | - |

#### 3.3.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. 不要禁用所有防火墙规则
2. 只开放 CNI 需要的端口
3. 云平台安全组需要同步配置
4. 考虑使用 NetworkPolicy 进行细粒度控制
5. 记录所有防火墙变更
```

### 3.4 MTU 问题导致大包丢失

#### 3.4.1 解决步骤

```bash
# 步骤 1：确认 MTU 问题
# 大包测试
kubectl exec -it <pod-a> -- ping -s 1400 <pod-b-ip>
kubectl exec -it <pod-a> -- ping -s 1472 <pod-b-ip>

# 步骤 2：检查各接口 MTU
ip link show eth0
ip link show flannel.1
ip link show tunl0

# 步骤 3：计算正确的 MTU
# VXLAN: 节点 MTU - 50
# IPIP: 节点 MTU - 20

# 步骤 4：修改 CNI MTU 配置
# Calico
calicoctl patch felixconfiguration default -p '{"spec":{"mtu": 1440}}'

# Flannel（修改 ConfigMap）
kubectl edit configmap -n kube-system kube-flannel-cfg
# 修改 net-conf.json 中的 Backend.MTU

# 步骤 5：重启 CNI Pod 应用配置
kubectl rollout restart daemonset -n kube-system calico-node

# 步骤 6：验证修复
kubectl exec -it <pod-a> -- ping -s 1400 <pod-b-ip>
```

#### 3.4.2 执行风险

| 风险等级 | 风险描述 | 缓解措施 |
|----------|----------|----------|
| **中** | MTU 变更需要重启 CNI Pod | 在维护窗口操作 |
| **低** | MTU 检测无风险 | - |

#### 3.4.3 安全生产风险提示

```
⚠️  安全生产风险提示：
1. MTU 设置过大会导致分片
2. MTU 设置过小影响性能
3. 所有节点 MTU 应该一致
4. 云环境检查网络 MTU 限制
5. 变更后全面测试大数据传输
```

---

## 附录

### A. 常见 CNI 端口

| CNI | 协议 | 端口 | 用途 |
|-----|------|------|------|
| Calico VXLAN | UDP | 4789 | VXLAN 封装 |
| Calico IPIP | IP | 4 | IPIP 隧道 |
| Calico BGP | TCP | 179 | BGP 路由 |
| Flannel VXLAN | UDP | 4789 | VXLAN 封装 |
| Flannel UDP | UDP | 8285 | UDP 封装 |
| Cilium VXLAN | UDP | 8472 | VXLAN 封装 |

### B. CNI 模式对比

| 模式 | 优点 | 缺点 | 适用场景 |
|------|------|------|----------|
| Overlay (VXLAN) | 跨子网、易部署 | 性能开销 | 云环境 |
| IPIP | 比 VXLAN 轻量 | 需要路由支持 | 私有云 |
| BGP | 原生路由、高性能 | 需要网络支持 | 裸金属 |
| Direct | 最高性能 | 网络要求高 | 特定环境 |

### C. 常用诊断命令

```bash
# Calico
calicoctl node status
calicoctl get node -o wide
calicoctl get ippool -o wide
calicoctl ipam check

# Cilium
cilium status
cilium connectivity test
cilium bpf endpoint list

# Flannel
cat /run/flannel/subnet.env

# 通用
ip route
ip link
bridge fdb show
conntrack -L
```
