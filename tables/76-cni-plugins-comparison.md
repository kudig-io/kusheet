# 表格76: CNI插件深度对比

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/cluster-administration/networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/)

## CNI插件功能对比

| 功能 | Calico | Cilium | Flannel | Terway(ACK) | Antrea |
|-----|--------|--------|---------|-------------|--------|
| **网络模式** | VXLAN/IPIP/BGP | VXLAN/Native | VXLAN/host-gw | VPC/ENIIP | VXLAN/Geneve |
| **NetworkPolicy** | ✅ 完整 | ✅ 完整+L7 | ❌ | ✅ 完整 | ✅ 完整 |
| **eBPF数据面** | ✅ (可选) | ✅ (原生) | ❌ | ✅ | ❌ |
| **服务网格** | ❌ | ✅ (Cilium Mesh) | ❌ | ASM集成 | ❌ |
| **带宽限制** | ✅ | ✅ | ❌ | ✅ | ✅ |
| **多集群** | ✅ | ✅ ClusterMesh | ❌ | ACK One | ✅ |
| **Windows** | ✅ | ⚠️ Beta | ✅ | ✅ | ✅ |
| **IPv6** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **双栈** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **加密** | WireGuard | WireGuard/IPsec | ❌ | ✅ | IPsec |
| **可观测性** | ✅ | ✅ Hubble | 基础 | ARMS集成 | ✅ |

## Calico配置

```yaml
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: default-ipv4-ippool
spec:
  cidr: 10.244.0.0/16
  ipipMode: Always  # Always/CrossSubnet/Never
  vxlanMode: Never  # Always/CrossSubnet/Never
  natOutgoing: true
  nodeSelector: all()
  blockSize: 26
---
apiVersion: projectcalico.org/v3
kind: FelixConfiguration
metadata:
  name: default
spec:
  bpfEnabled: true
  bpfDataIfacePattern: "^(en|eth|ens|eno).*"
  bpfConnectTimeLoadBalancingEnabled: true
  bpfExternalServiceMode: DSR
  ipipEnabled: false
  vxlanEnabled: false
  wireguardEnabled: true  # 加密
```

## Cilium配置

```yaml
# Helm values
apiVersion: v1
kind: ConfigMap
metadata:
  name: cilium-config
data:
  values.yaml: |
    cluster:
      name: production
      id: 1
    
    ipam:
      mode: cluster-pool
      operator:
        clusterPoolIPv4PodCIDRList:
          - 10.244.0.0/16
        clusterPoolIPv4MaskSize: 24
    
    kubeProxyReplacement: true
    k8sServiceHost: kubernetes.default.svc
    k8sServicePort: 443
    
    bpf:
      masquerade: true
      hostLegacyRouting: false
    
    loadBalancer:
      mode: dsr
      algorithm: maglev
    
    hubble:
      enabled: true
      relay:
        enabled: true
      ui:
        enabled: true
    
    encryption:
      enabled: true
      type: wireguard
    
    bandwidthManager:
      enabled: true
    
    egressGateway:
      enabled: true
```

## Flannel配置

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-flannel-cfg
  namespace: kube-flannel
data:
  net-conf.json: |
    {
      "Network": "10.244.0.0/16",
      "Backend": {
        "Type": "vxlan",
        "VNI": 1,
        "Port": 8472,
        "DirectRouting": true
      }
    }
```

## Terway配置(ACK)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: eni-config
  namespace: kube-system
data:
  eni_conf: |
    {
      "version": "1",
      "max_pool_size": 25,
      "min_pool_size": 10,
      "credential_path": "/var/addon/token-config",
      "vswitches": {
        "cn-hangzhou-h": ["vsw-xxx"],
        "cn-hangzhou-i": ["vsw-yyy"]
      },
      "security_groups": ["sg-xxx"],
      "service_cidr": "172.21.0.0/20"
    }
```

## CNI性能对比

| CNI | Pod启动时间 | 吞吐量 | 延迟 | CPU开销 |
|-----|-----------|-------|------|--------|
| Calico VXLAN | 中 | 高 | 中 | 中 |
| Calico eBPF | 快 | 很高 | 低 | 低 |
| Cilium | 快 | 很高 | 低 | 低 |
| Flannel VXLAN | 中 | 中 | 中 | 低 |
| Terway ENIIP | 快 | 最高 | 最低 | 最低 |

## CNI选型建议

| 场景 | 推荐CNI | 原因 |
|-----|--------|------|
| 通用生产 | Calico | 成熟稳定,功能全面 |
| 高性能/安全 | Cilium | eBPF原生,L7策略 |
| 简单场景 | Flannel | 配置简单 |
| 阿里云 | Terway | VPC原生,性能最优 |
| 多集群 | Cilium | ClusterMesh |

## CNI故障排查

| 问题 | 诊断命令 | 解决方向 |
|-----|---------|---------|
| Pod无IP | `kubectl describe pod` | 检查IPAM配置 |
| 跨节点不通 | `calicoctl node status` | 检查BGP/隧道状态 |
| 策略不生效 | `cilium policy get` | 检查策略配置 |
| 性能差 | `cilium monitor` | 检查数据路径 |
| DNS解析失败 | `kubectl exec -- nslookup` | 检查CoreDNS |
| 服务不可达 | `kubectl get endpoints` | 检查kube-proxy |

```bash
# Calico诊断
calicoctl node status
calicoctl get ippool -o wide
calicoctl get workloadendpoint

# Cilium诊断
cilium status
cilium connectivity test
cilium hubble observe --follow

# 网络连通性测试
kubectl run test --rm -it --image=nicolaka/netshoot -- bash
# 在容器内: ping, curl, dig, traceroute, iperf3

# 查看CNI配置
cat /etc/cni/net.d/*.conf
ls -la /opt/cni/bin/

# 检查iptables规则
iptables -t nat -L -n -v
iptables -t filter -L -n -v
```

## 版本兼容性

| CNI | v1.25 | v1.28 | v1.32 | 推荐版本 |
|-----|-------|-------|-------|---------|
| Calico | 3.24+ | 3.26+ | 3.28+ | 3.28 |
| Cilium | 1.12+ | 1.14+ | 1.16+ | 1.16 |
| Flannel | 0.20+ | 0.22+ | 0.25+ | 0.25 |
| Terway | 1.5+ | 1.7+ | 1.9+ | 1.9 |

---

**CNI选型原则**: 根据场景选择(通用Calico/高性能Cilium/云原生Terway) + 评估功能需求 + 考虑运维复杂度
