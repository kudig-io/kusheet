# PV/PVC 故障排查

## 概述

PersistentVolume (PV) 和 PersistentVolumeClaim (PVC) 是 Kubernetes 存储抽象的核心组件。本文档详细介绍 PV/PVC 生命周期、常见故障场景的诊断方法和解决方案。

## 存储架构

### PV/PVC 生命周期

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              PV/PVC 生命周期状态机                                   │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │                           PersistentVolume 生命周期                          │   │
│   │                                                                              │   │
│   │   ┌───────────┐      ┌───────────┐      ┌───────────┐      ┌───────────┐   │   │
│   │   │ Available │ ───► │  Bound    │ ───► │ Released  │ ───► │  Failed   │   │   │
│   │   │           │      │           │      │           │      │           │   │   │
│   │   │ 等待绑定   │      │ 已绑定PVC │      │ PVC已删除 │      │ 回收失败  │   │   │
│   │   └─────┬─────┘      └─────┬─────┘      └─────┬─────┘      └───────────┘   │   │
│   │         │                  │                  │                            │   │
│   │         │                  │                  │                            │   │
│   │         │                  │            ┌─────┴─────┐                      │   │
│   │         │                  │            │  Reclaim  │                      │   │
│   │         │                  │            │  Policy   │                      │   │
│   │         │                  │            └─────┬─────┘                      │   │
│   │         │                  │                  │                            │   │
│   │         │                  │     ┌───────────┼───────────┐                │   │
│   │         │                  │     │           │           │                │   │
│   │         │                  │     ▼           ▼           ▼                │   │
│   │         │                  │  Retain     Recycle     Delete              │   │
│   │         │                  │  (保留)      (回收)      (删除)              │   │
│   │         │                  │     │           │           │                │   │
│   │         │                  │     │           │           │                │   │
│   │         │                  │     ▼           ▼           ▼                │   │
│   │         │                  │  手动清理    重新可用    卷被删除            │   │
│   │         │                  │  数据后      (已废弃)                        │   │
│   │         │                  │  Available                                   │   │
│   │         │                  │                                              │   │
│   └─────────┴──────────────────┴──────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │                        PersistentVolumeClaim 生命周期                        │   │
│   │                                                                              │   │
│   │   ┌───────────┐      ┌───────────┐      ┌───────────┐                      │   │
│   │   │  Pending  │ ───► │  Bound    │ ───► │  Lost     │                      │   │
│   │   │           │      │           │      │           │                      │   │
│   │   │ 等待绑定   │      │ 已绑定PV  │      │ PV丢失    │                      │   │
│   │   └─────┬─────┘      └───────────┘      └───────────┘                      │   │
│   │         │                                                                   │   │
│   │         │ 动态供应/静态匹配                                                 │   │
│   │         │                                                                   │   │
│   │         ▼                                                                   │   │
│   │   ┌───────────────────────────────────────────────────────────────────┐    │   │
│   │   │                      绑定条件检查                                  │    │   │
│   │   │                                                                   │    │   │
│   │   │  • 存储大小: PV >= PVC                                            │    │   │
│   │   │  • 访问模式: PV ⊇ PVC                                             │    │   │
│   │   │  • StorageClass: PV == PVC (或为空)                               │    │   │
│   │   │  • Selector: PV labels 匹配 PVC selector                         │    │   │
│   │   │  • VolumeMode: PV == PVC (Filesystem/Block)                      │    │   │
│   │   │                                                                   │    │   │
│   │   └───────────────────────────────────────────────────────────────────┘    │   │
│   │                                                                              │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

### CSI 架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              CSI (Container Storage Interface) 架构                  │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │                              Control Plane                                   │   │
│   │                                                                              │   │
│   │   ┌────────────────────┐      ┌────────────────────┐                        │   │
│   │   │   kube-controller  │      │  external-provisioner │                     │   │
│   │   │     -manager       │      │                       │                     │   │
│   │   │                    │      │  • 监听 PVC 创建       │                     │   │
│   │   │  • PV Controller   │      │  • 调用 CSI CreateVolume │                  │   │
│   │   │  • AttachDetach    │      │  • 创建 PV 对象        │                     │   │
│   │   │    Controller      │      └───────────┬───────────┘                     │   │
│   │   └────────────────────┘                  │                                 │   │
│   │                                           │                                 │   │
│   │   ┌────────────────────┐      ┌───────────┴───────────┐                     │   │
│   │   │  external-attacher │      │  external-snapshotter │                     │   │
│   │   │                    │      │                       │                     │   │
│   │   │  • 监听 VolumeAttachment │ │  • 监听 VolumeSnapshot │                   │   │
│   │   │  • 调用 CSI ControllerPublish │ • 调用 CSI CreateSnapshot │              │   │
│   │   └────────────────────┘      └───────────────────────┘                     │   │
│   │                                                                              │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                           │                                          │
│                                           │ gRPC                                     │
│                                           │                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │                               CSI Driver                                     │   │
│   │                                                                              │   │
│   │   ┌────────────────────────────────────────────────────────────────────┐    │   │
│   │   │                         Controller Plugin                           │    │   │
│   │   │                                                                     │    │   │
│   │   │   CreateVolume    DeleteVolume    ControllerPublishVolume          │    │   │
│   │   │   CreateSnapshot  DeleteSnapshot  ControllerUnpublishVolume        │    │   │
│   │   │   ControllerExpandVolume         ListVolumes                       │    │   │
│   │   │                                                                     │    │   │
│   │   └────────────────────────────────────────────────────────────────────┘    │   │
│   │                                                                              │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                           │                                          │
│                                           │ gRPC (Node Socket)                       │
│                                           │                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │                              Node (每个节点)                                 │   │
│   │                                                                              │   │
│   │   ┌────────────────────┐      ┌────────────────────────────────────────┐    │   │
│   │   │      kubelet       │      │              Node Plugin               │    │   │
│   │   │                    │      │                                        │    │   │
│   │   │  Volume Manager    │ ───► │  NodeStageVolume    (挂载到staging)    │    │   │
│   │   │                    │      │  NodePublishVolume  (挂载到Pod)        │    │   │
│   │   │  • Mount/Unmount   │      │  NodeUnstageVolume  (卸载staging)     │    │   │
│   │   │  • Attach/Detach   │      │  NodeUnpublishVolume(卸载Pod)         │    │   │
│   │   │                    │      │  NodeGetVolumeStats (获取统计)        │    │   │
│   │   └────────────────────┘      └────────────────────────────────────────┘    │   │
│   │                                           │                                 │   │
│   │                                           │                                 │   │
│   │   ┌────────────────────────────────────────────────────────────────────┐    │   │
│   │   │                         Storage Backend                            │    │   │
│   │   │                                                                     │    │   │
│   │   │   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │    │   │
│   │   │   │AWS EBS   │  │Azure Disk│  │GCE PD    │  │Ceph RBD  │          │    │   │
│   │   │   └──────────┘  └──────────┘  └──────────┘  └──────────┘          │    │   │
│   │   │                                                                     │    │   │
│   │   │   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │    │   │
│   │   │   │阿里云盘   │  │NFS       │  │iSCSI     │  │Local PV  │          │    │   │
│   │   │   └──────────┘  └──────────┘  └──────────┘  └──────────┘          │    │   │
│   │   │                                                                     │    │   │
│   │   └────────────────────────────────────────────────────────────────────┘    │   │
│   │                                                                              │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

## 状态详解

### PVC 状态说明

| 状态 | 描述 | 常见原因 | 解决方向 |
|-----|------|---------|---------|
| **Pending** | 等待绑定 | 无匹配 PV、StorageClass 问题、配额不足 | 检查匹配条件、SC 配置、配额 |
| **Bound** | 已绑定到 PV | 正常状态 | - |
| **Lost** | 绑定的 PV 不存在 | PV 被误删、后端存储故障 | 恢复 PV 或重新创建 |

### PV 状态说明

| 状态 | 描述 | 常见原因 | 解决方向 |
|-----|------|---------|---------|
| **Available** | 可用,等待绑定 | 新创建或回收后 | 正常状态 |
| **Bound** | 已绑定到 PVC | 正常状态 | - |
| **Released** | PVC 已删除,等待回收 | PVC 删除后 | 根据回收策略处理 |
| **Failed** | 回收操作失败 | 后端存储问题 | 检查存储后端 |

### 访问模式对比

| 访问模式 | 缩写 | 描述 | 支持的存储类型 |
|---------|-----|------|--------------|
| **ReadWriteOnce** | RWO | 单节点读写 | 块存储 (EBS, Azure Disk, GCE PD) |
| **ReadOnlyMany** | ROX | 多节点只读 | NFS, CephFS, Azure File |
| **ReadWriteMany** | RWX | 多节点读写 | NFS, CephFS, Azure File, EFS |
| **ReadWriteOncePod** | RWOP | 单 Pod 读写 (v1.22+) | 部分 CSI 驱动 |

## 故障诊断流程

### PVC Pending 诊断

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              PVC Pending 诊断决策树                                  │
│                                                                                      │
│                              PVC 状态为 Pending                                      │
│                                     │                                                │
│                                     ▼                                                │
│                         ┌─────────────────────┐                                     │
│                         │ 检查 StorageClass   │                                     │
│                         │ 是否存在且正确?      │                                     │
│                         └──────────┬──────────┘                                     │
│                                    │                                                │
│                    ┌───────────────┴───────────────┐                                │
│                    │                               │                                │
│                   否                              是                                │
│                    │                               │                                │
│                    ▼                               ▼                                │
│         ┌──────────────────┐          ┌─────────────────────┐                      │
│         │ 创建/修正        │          │ 检查 provisioner    │                      │
│         │ StorageClass     │          │ 是否正常运行?       │                      │
│         └──────────────────┘          └──────────┬──────────┘                      │
│                                                  │                                  │
│                                  ┌───────────────┴───────────────┐                  │
│                                  │                               │                  │
│                                 否                              是                  │
│                                  │                               │                  │
│                                  ▼                               ▼                  │
│                       ┌──────────────────┐          ┌─────────────────────┐        │
│                       │ 检查 CSI Driver  │          │ 检查存储后端        │        │
│                       │ Pod 状态和日志    │          │ 容量和配额          │        │
│                       └──────────────────┘          └──────────┬──────────┘        │
│                                                                │                    │
│                                                ┌───────────────┴───────────────┐    │
│                                                │                               │    │
│                                              不足                            足够    │
│                                                │                               │    │
│                                                ▼                               ▼    │
│                                     ┌──────────────────┐        ┌────────────────┐ │
│                                     │ 扩容存储或清理   │        │ 检查 PVC 参数  │ │
│                                     │ 资源释放配额     │        │ 与 PV 匹配条件 │ │
│                                     └──────────────────┘        └────────┬───────┘ │
│                                                                          │         │
│                                                          ┌───────────────┴─────┐   │
│                                                          │                     │   │
│                                                        不匹配               匹配   │
│                                                          │                     │   │
│                                                          ▼                     ▼   │
│                                               ┌──────────────────┐  ┌────────────┐ │
│                                               │ 调整 PVC 参数    │  │ 检查节点   │ │
│                                               │ 或创建匹配的 PV  │  │ 拓扑约束   │ │
│                                               └──────────────────┘  └────────────┘ │
│                                                                                      │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

### 综合诊断脚本

```bash
#!/bin/bash
# pv-pvc-diagnostics.sh
# PV/PVC 综合诊断脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo -e "\n${GREEN}=== $1 ===${NC}"
}

print_warning() {
    echo -e "${YELLOW}[警告] $1${NC}"
}

print_error() {
    echo -e "${RED}[错误] $1${NC}"
}

echo "=========================================="
echo "     PV/PVC 综合诊断报告"
echo "=========================================="
echo "时间: $(date)"
echo ""

# 检查参数
PVC_NAME=${1:-""}
NAMESPACE=${2:-"default"}

if [ -n "$PVC_NAME" ]; then
    echo "诊断目标: PVC $PVC_NAME (namespace: $NAMESPACE)"
fi

print_header "1. PV/PVC 概览"

echo "--- PVC 统计 ---"
echo "Pending PVC:"
kubectl get pvc --all-namespaces --field-selector=status.phase=Pending 2>/dev/null | wc -l
echo ""
echo "Bound PVC:"
kubectl get pvc --all-namespaces --field-selector=status.phase=Bound 2>/dev/null | wc -l
echo ""

echo "--- PV 统计 ---"
echo "Available PV:"
kubectl get pv --field-selector=status.phase=Available 2>/dev/null | wc -l
echo ""
echo "Bound PV:"
kubectl get pv --field-selector=status.phase=Bound 2>/dev/null | wc -l
echo ""
echo "Released PV:"
kubectl get pv --field-selector=status.phase=Released 2>/dev/null | wc -l
echo ""

print_header "2. Pending PVC 详情"

PENDING_PVCS=$(kubectl get pvc --all-namespaces --field-selector=status.phase=Pending -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null)

if [ -z "$PENDING_PVCS" ]; then
    echo "没有 Pending 状态的 PVC"
else
    echo "发现以下 Pending PVC:"
    for pvc in $PENDING_PVCS; do
        NS=$(echo $pvc | cut -d'/' -f1)
        NAME=$(echo $pvc | cut -d'/' -f2)
        echo ""
        echo "--- $NS/$NAME ---"
        
        # 获取 PVC 详情
        kubectl get pvc $NAME -n $NS -o yaml 2>/dev/null | grep -E "storageClassName|accessModes|storage:" | head -10
        
        # 获取事件
        echo "最近事件:"
        kubectl get events -n $NS --field-selector involvedObject.name=$NAME --sort-by='.lastTimestamp' 2>/dev/null | tail -5
    done
fi

print_header "3. StorageClass 状态"

echo "--- StorageClass 列表 ---"
kubectl get sc -o custom-columns=\
NAME:.metadata.name,\
PROVISIONER:.provisioner,\
RECLAIM:.reclaimPolicy,\
BINDING:.volumeBindingMode,\
EXPANSION:.allowVolumeExpansion,\
DEFAULT:.metadata.annotations."storageclass\.kubernetes\.io/is-default-class"

echo ""

# 检查默认 StorageClass
DEFAULT_SC=$(kubectl get sc -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' 2>/dev/null)
if [ -z "$DEFAULT_SC" ]; then
    print_warning "没有设置默认 StorageClass"
else
    echo "默认 StorageClass: $DEFAULT_SC"
fi

print_header "4. CSI Driver 状态"

echo "--- CSI Driver 列表 ---"
kubectl get csidriver 2>/dev/null || echo "未找到 CSI Driver"
echo ""

echo "--- CSI 相关 Pod ---"
kubectl get pods --all-namespaces -l app.kubernetes.io/component=csi-driver 2>/dev/null || \
kubectl get pods --all-namespaces | grep -E "csi|ebs|disk|storage" || echo "未找到 CSI Pod"
echo ""

# 检查 CSI Pod 状态
CSI_PODS=$(kubectl get pods --all-namespaces -o wide 2>/dev/null | grep -i csi | grep -v Running || true)
if [ -n "$CSI_PODS" ]; then
    print_warning "发现异常 CSI Pod:"
    echo "$CSI_PODS"
fi

print_header "5. VolumeAttachment 状态"

echo "--- VolumeAttachment 列表 ---"
kubectl get volumeattachment 2>/dev/null | head -20 || echo "未找到 VolumeAttachment"
echo ""

# 检查 Pending VolumeAttachment
PENDING_VA=$(kubectl get volumeattachment -o jsonpath='{range .items[?(@.status.attached==false)]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
if [ -n "$PENDING_VA" ]; then
    print_warning "发现未 Attached 的 VolumeAttachment:"
    echo "$PENDING_VA"
fi

print_header "6. 节点存储状态"

echo "--- 节点存储容量 ---"
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
EPHEMERAL:.status.allocatable.ephemeral-storage 2>/dev/null

echo ""

echo "--- CSINode 状态 ---"
kubectl get csinode 2>/dev/null | head -10 || echo "未找到 CSINode"

print_header "7. ResourceQuota 检查"

echo "--- 存储相关 ResourceQuota ---"
kubectl get resourcequota --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
PVC_USED:.status.used.persistentvolumeclaims,\
PVC_HARD:.status.hard.persistentvolumeclaims,\
STORAGE_USED:.status.used.requests\\.storage,\
STORAGE_HARD:.status.hard.requests\\.storage 2>/dev/null || echo "未配置存储配额"

print_header "8. 常见问题检查"

# 检查 Released 但未清理的 PV
RELEASED_PV=$(kubectl get pv --field-selector=status.phase=Released -o name 2>/dev/null | wc -l)
if [ "$RELEASED_PV" -gt 0 ]; then
    print_warning "发现 $RELEASED_PV 个 Released 状态的 PV,需要手动处理"
    kubectl get pv --field-selector=status.phase=Released 2>/dev/null
fi

# 检查 Failed 的 PV
FAILED_PV=$(kubectl get pv --field-selector=status.phase=Failed -o name 2>/dev/null | wc -l)
if [ "$FAILED_PV" -gt 0 ]; then
    print_error "发现 $FAILED_PV 个 Failed 状态的 PV"
    kubectl get pv --field-selector=status.phase=Failed 2>/dev/null
fi

# 检查 Lost 的 PVC
LOST_PVC=$(kubectl get pvc --all-namespaces --field-selector=status.phase=Lost -o name 2>/dev/null | wc -l)
if [ "$LOST_PVC" -gt 0 ]; then
    print_error "发现 $LOST_PVC 个 Lost 状态的 PVC"
    kubectl get pvc --all-namespaces --field-selector=status.phase=Lost 2>/dev/null
fi

# 特定 PVC 诊断
if [ -n "$PVC_NAME" ]; then
    print_header "9. 特定 PVC 诊断: $PVC_NAME"
    
    echo "--- PVC 详情 ---"
    kubectl get pvc $PVC_NAME -n $NAMESPACE -o yaml 2>/dev/null || echo "PVC 不存在"
    
    echo ""
    echo "--- PVC 事件 ---"
    kubectl describe pvc $PVC_NAME -n $NAMESPACE 2>/dev/null | grep -A 20 "Events:" || true
    
    # 获取关联的 PV
    PV_NAME=$(kubectl get pvc $PVC_NAME -n $NAMESPACE -o jsonpath='{.spec.volumeName}' 2>/dev/null)
    if [ -n "$PV_NAME" ]; then
        echo ""
        echo "--- 关联 PV: $PV_NAME ---"
        kubectl get pv $PV_NAME -o yaml 2>/dev/null
    fi
    
    # 检查使用该 PVC 的 Pod
    echo ""
    echo "--- 使用该 PVC 的 Pod ---"
    kubectl get pods -n $NAMESPACE -o json 2>/dev/null | jq -r ".items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName == \"$PVC_NAME\") | .metadata.name" 2>/dev/null || echo "未找到"
fi

print_header "10. 诊断建议"

echo "根据以上检查结果,请注意以下几点:"
echo ""
echo "1. Pending PVC 常见原因:"
echo "   - StorageClass 不存在或配置错误"
echo "   - CSI Driver 未正常运行"
echo "   - 存储后端容量或配额不足"
echo "   - 节点拓扑约束不满足"
echo ""
echo "2. 挂载失败常见原因:"
echo "   - VolumeAttachment 失败"
echo "   - 节点无法连接存储后端"
echo "   - 多节点同时挂载 RWO 卷"
echo ""
echo "3. 建议执行的后续检查:"
echo "   - kubectl logs <csi-controller-pod> -c csi-provisioner"
echo "   - kubectl logs <csi-node-pod> -c csi-node"
echo "   - 检查云厂商存储服务状态"

echo ""
echo "=========================================="
echo "       诊断报告结束"
echo "=========================================="
```

## 常见问题与解决方案

### PVC Pending 原因矩阵

| 原因类别 | 具体原因 | 诊断命令 | 解决方案 |
|---------|---------|---------|---------|
| **StorageClass** | SC 不存在 | `kubectl get sc` | 创建或修正 SC 名称 |
| | SC provisioner 错误 | `kubectl describe sc <name>` | 修正 provisioner 配置 |
| | 无默认 SC | `kubectl get sc` | 设置默认 SC |
| **CSI Driver** | Driver 未安装 | `kubectl get csidriver` | 安装 CSI Driver |
| | Controller Pod 异常 | `kubectl get pods -n kube-system` | 检查 Pod 日志 |
| | Node Plugin 异常 | `kubectl get pods -n kube-system -o wide` | 检查节点上的 CSI Pod |
| **容量/配额** | 存储后端容量不足 | 检查云厂商控制台 | 扩容或清理存储 |
| | ResourceQuota 限制 | `kubectl get resourcequota` | 调整配额或释放资源 |
| | LimitRange 限制 | `kubectl get limitrange` | 调整限制或 PVC 大小 |
| **匹配条件** | 容量不匹配 | `kubectl get pv,pvc` | 调整 PV/PVC 大小 |
| | 访问模式不匹配 | `kubectl get pv,pvc -o wide` | 修正访问模式 |
| | Label Selector 不匹配 | `kubectl describe pvc` | 调整 selector/labels |
| **拓扑约束** | 节点不在允许区域 | `kubectl describe pv` | 检查 nodeAffinity |
| | WaitForFirstConsumer 模式 | `kubectl describe sc` | Pod 调度后自动解决 |

### Mount 失败诊断

```bash
#!/bin/bash
# mount-failure-diagnostics.sh
# Pod 挂载失败诊断脚本

POD_NAME=$1
NAMESPACE=${2:-"default"}

if [ -z "$POD_NAME" ]; then
    echo "用法: $0 <pod-name> [namespace]"
    exit 1
fi

echo "=== Pod 挂载诊断: $POD_NAME ==="
echo ""

# 获取 Pod 信息
echo "--- Pod 状态 ---"
kubectl get pod $POD_NAME -n $NAMESPACE -o wide
echo ""

# 获取 Pod 事件
echo "--- Pod 事件 ---"
kubectl describe pod $POD_NAME -n $NAMESPACE | grep -A 30 "Events:" | head -35
echo ""

# 获取 Pod 使用的 PVC
echo "--- Pod 使用的 PVC ---"
PVC_NAMES=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.volumes[*].persistentVolumeClaim.claimName}')
for pvc in $PVC_NAMES; do
    echo ""
    echo "PVC: $pvc"
    kubectl get pvc $pvc -n $NAMESPACE
    
    # 获取关联的 PV
    PV_NAME=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.spec.volumeName}')
    if [ -n "$PV_NAME" ]; then
        echo "PV: $PV_NAME"
        kubectl get pv $PV_NAME
        
        # 检查 VolumeAttachment
        echo ""
        echo "VolumeAttachment:"
        kubectl get volumeattachment | grep $PV_NAME || echo "未找到关联的 VolumeAttachment"
    fi
done

# 获取节点信息
NODE_NAME=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.nodeName}')
if [ -n "$NODE_NAME" ]; then
    echo ""
    echo "--- 节点信息: $NODE_NAME ---"
    kubectl get node $NODE_NAME
    
    echo ""
    echo "--- 节点 CSI 状态 ---"
    kubectl get csinode $NODE_NAME -o yaml 2>/dev/null || echo "CSINode 信息不可用"
    
    echo ""
    echo "--- 节点上的 CSI Pod ---"
    kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=$NODE_NAME | grep -i csi
fi

echo ""
echo "--- Kubelet 日志 (需要节点访问权限) ---"
echo "请在节点上运行: journalctl -u kubelet | grep -i 'volume\\|mount\\|attach' | tail -50"
```

### 存储扩容故障排查

```bash
#!/bin/bash
# volume-expansion-diagnostics.sh
# 卷扩容诊断脚本

PVC_NAME=$1
NAMESPACE=${2:-"default"}

if [ -z "$PVC_NAME" ]; then
    echo "用法: $0 <pvc-name> [namespace]"
    exit 1
fi

echo "=== 卷扩容诊断: $PVC_NAME ==="
echo ""

# 检查 PVC 状态
echo "--- PVC 状态 ---"
kubectl get pvc $PVC_NAME -n $NAMESPACE -o yaml
echo ""

# 检查 PVC conditions
echo "--- PVC Conditions ---"
kubectl get pvc $PVC_NAME -n $NAMESPACE -o jsonpath='{.status.conditions}' | jq . 2>/dev/null || \
kubectl get pvc $PVC_NAME -n $NAMESPACE -o jsonpath='{.status.conditions}'
echo ""

# 获取 StorageClass 信息
SC_NAME=$(kubectl get pvc $PVC_NAME -n $NAMESPACE -o jsonpath='{.spec.storageClassName}')
echo "--- StorageClass: $SC_NAME ---"
kubectl get sc $SC_NAME -o yaml
echo ""

# 检查是否支持扩容
ALLOW_EXPANSION=$(kubectl get sc $SC_NAME -o jsonpath='{.allowVolumeExpansion}')
if [ "$ALLOW_EXPANSION" != "true" ]; then
    echo "[错误] StorageClass 不支持卷扩容 (allowVolumeExpansion: $ALLOW_EXPANSION)"
    echo "解决方案: 修改 StorageClass 设置 allowVolumeExpansion: true"
    exit 1
fi

# 获取 PV 信息
PV_NAME=$(kubectl get pvc $PVC_NAME -n $NAMESPACE -o jsonpath='{.spec.volumeName}')
if [ -n "$PV_NAME" ]; then
    echo "--- PV 状态: $PV_NAME ---"
    kubectl get pv $PV_NAME -o yaml
fi

# 检查使用 PVC 的 Pod
echo ""
echo "--- 使用该 PVC 的 Pod ---"
PODS=$(kubectl get pods -n $NAMESPACE -o json | jq -r ".items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName == \"$PVC_NAME\") | .metadata.name")
if [ -n "$PODS" ]; then
    echo "Pod 列表: $PODS"
    echo ""
    echo "[提示] 某些 CSI 驱动要求 Pod 重启后才能完成文件系统扩容"
    echo "可以尝试: kubectl rollout restart deployment/<deployment-name> -n $NAMESPACE"
else
    echo "无 Pod 使用此 PVC"
fi

# 检查 CSI Driver 日志
echo ""
echo "--- CSI Controller 最近日志 ---"
CSI_CONTROLLER=$(kubectl get pods --all-namespaces -l app.kubernetes.io/component=csi-driver -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$CSI_CONTROLLER" ]; then
    CSI_NS=$(kubectl get pods --all-namespaces -l app.kubernetes.io/component=csi-driver -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null)
    kubectl logs $CSI_CONTROLLER -n $CSI_NS -c csi-resizer --tail=20 2>/dev/null || echo "无法获取 CSI resizer 日志"
fi
```

## StorageClass 配置

### 常见 StorageClass 示例

```yaml
# storageclass-examples.yaml

---
# AWS EBS gp3 StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
  fsType: ext4
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
mountOptions:
  - noatime
  - nodiratime

---
# Azure Disk Premium StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-premium-ssd
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS
  cachingMode: ReadOnly
  fsType: ext4
  networkAccessPolicy: AllowPrivate
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true

---
# GCP PD SSD StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gcp-pd-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd
  fsType: ext4
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true

---
# 阿里云 ESSD PL1 StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alicloud-essd-pl1
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
  performanceLevel: PL1
  fsType: ext4
  encrypted: "true"
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true

---
# NFS StorageClass (使用 NFS CSI Driver)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-csi
provisioner: nfs.csi.k8s.io
parameters:
  server: nfs-server.example.com
  share: /exported/path
  mountPermissions: "0755"
reclaimPolicy: Delete
volumeBindingMode: Immediate
mountOptions:
  - nfsvers=4.1
  - hard
  - noresvport

---
# Local PV StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer

---
# Ceph RBD StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-rbd
provisioner: rbd.csi.ceph.com
parameters:
  clusterID: <cluster-id>
  pool: kubernetes
  imageFeatures: layering
  csi.storage.k8s.io/provisioner-secret-name: csi-rbd-secret
  csi.storage.k8s.io/provisioner-secret-namespace: ceph-csi
  csi.storage.k8s.io/controller-expand-secret-name: csi-rbd-secret
  csi.storage.k8s.io/controller-expand-secret-namespace: ceph-csi
  csi.storage.k8s.io/node-stage-secret-name: csi-rbd-secret
  csi.storage.k8s.io/node-stage-secret-namespace: ceph-csi
  csi.storage.k8s.io/fstype: ext4
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
```

### 拓扑感知配置

```yaml
# topology-aware-storageclass.yaml

---
# 带拓扑约束的 StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: topology-aware-ebs
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer  # 延迟绑定,等待 Pod 调度
allowVolumeExpansion: true
allowedTopologies:
  - matchLabelExpressions:
      - key: topology.ebs.csi.aws.com/zone
        values:
          - us-east-1a
          - us-east-1b
          - us-east-1c

---
# PV 示例 (带 nodeAffinity)
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-example
spec:
  capacity:
    storage: 100Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/disks/ssd1
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - node-1
                - node-2
```

## 快照与恢复

### VolumeSnapshot 配置

```yaml
# volume-snapshot-example.yaml

---
# VolumeSnapshotClass
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ebs-snapshot-class
driver: ebs.csi.aws.com
deletionPolicy: Delete
parameters:
  # 可选参数
  # tagSpecification_1: "key=environment,value=production"

---
# 创建快照
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: mysql-data-snapshot
  namespace: database
spec:
  volumeSnapshotClassName: ebs-snapshot-class
  source:
    persistentVolumeClaimName: mysql-data-pvc

---
# 从快照恢复 PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-data-restored
  namespace: database
spec:
  storageClassName: ebs-gp3
  dataSource:
    name: mysql-data-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi  # 必须 >= 原始大小

---
# 从现有 PVC 克隆
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-data-clone
  namespace: database
spec:
  storageClassName: ebs-gp3
  dataSource:
    name: mysql-data-pvc
    kind: PersistentVolumeClaim
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
```

### 快照故障排查

```bash
#!/bin/bash
# snapshot-diagnostics.sh
# 快照诊断脚本

SNAPSHOT_NAME=$1
NAMESPACE=${2:-"default"}

if [ -z "$SNAPSHOT_NAME" ]; then
    echo "用法: $0 <snapshot-name> [namespace]"
    exit 1
fi

echo "=== 快照诊断: $SNAPSHOT_NAME ==="
echo ""

# 获取快照状态
echo "--- VolumeSnapshot 状态 ---"
kubectl get volumesnapshot $SNAPSHOT_NAME -n $NAMESPACE -o yaml
echo ""

# 获取 VolumeSnapshotContent
CONTENT_NAME=$(kubectl get volumesnapshot $SNAPSHOT_NAME -n $NAMESPACE -o jsonpath='{.status.boundVolumeSnapshotContentName}')
if [ -n "$CONTENT_NAME" ]; then
    echo "--- VolumeSnapshotContent: $CONTENT_NAME ---"
    kubectl get volumesnapshotcontent $CONTENT_NAME -o yaml
fi

# 检查快照类
SC_NAME=$(kubectl get volumesnapshot $SNAPSHOT_NAME -n $NAMESPACE -o jsonpath='{.spec.volumeSnapshotClassName}')
if [ -n "$SC_NAME" ]; then
    echo ""
    echo "--- VolumeSnapshotClass: $SC_NAME ---"
    kubectl get volumesnapshotclass $SC_NAME -o yaml
fi

# 检查事件
echo ""
echo "--- 相关事件 ---"
kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$SNAPSHOT_NAME --sort-by='.lastTimestamp'
```

## 监控告警

### Prometheus 监控规则

```yaml
# pv-pvc-monitoring-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: pv-pvc-monitoring-rules
  namespace: monitoring
spec:
  groups:
    # =================================================================
    # PVC 状态告警
    # =================================================================
    - name: pvc.alerts
      interval: 30s
      rules:
        - alert: PVCPending
          expr: |
            kube_persistentvolumeclaim_status_phase{phase="Pending"} == 1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "PVC 处于 Pending 状态"
            description: "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} 已 Pending 超过 5 分钟"
            
        - alert: PVCPendingLong
          expr: |
            kube_persistentvolumeclaim_status_phase{phase="Pending"} == 1
          for: 30m
          labels:
            severity: critical
          annotations:
            summary: "PVC 长时间 Pending"
            description: "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} 已 Pending 超过 30 分钟"
            
        - alert: PVCLost
          expr: |
            kube_persistentvolumeclaim_status_phase{phase="Lost"} == 1
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "PVC 丢失"
            description: "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} 状态为 Lost,可能数据丢失"
            
    # =================================================================
    # PV 状态告警
    # =================================================================
    - name: pv.alerts
      interval: 30s
      rules:
        - alert: PVFailed
          expr: |
            kube_persistentvolume_status_phase{phase="Failed"} == 1
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "PV 状态为 Failed"
            description: "PV {{ $labels.persistentvolume }} 状态为 Failed"
            
        - alert: PVReleased
          expr: |
            kube_persistentvolume_status_phase{phase="Released"} == 1
          for: 1h
          labels:
            severity: warning
          annotations:
            summary: "PV 长时间处于 Released 状态"
            description: "PV {{ $labels.persistentvolume }} 已 Released 超过 1 小时,需要手动处理"
            
    # =================================================================
    # 存储容量告警
    # =================================================================
    - name: storage.capacity.alerts
      interval: 1m
      rules:
        - alert: PVCStorageCapacityLow
          expr: |
            (
              kubelet_volume_stats_available_bytes / 
              kubelet_volume_stats_capacity_bytes
            ) < 0.15
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "PVC 存储容量低"
            description: "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} 剩余容量低于 15%"
            
        - alert: PVCStorageCapacityCritical
          expr: |
            (
              kubelet_volume_stats_available_bytes / 
              kubelet_volume_stats_capacity_bytes
            ) < 0.05
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "PVC 存储容量严重不足"
            description: "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} 剩余容量低于 5%"
            
        - alert: PVCInodeUsageHigh
          expr: |
            (
              kubelet_volume_stats_inodes_used / 
              kubelet_volume_stats_inodes
            ) > 0.9
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "PVC Inode 使用率高"
            description: "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} Inode 使用率超过 90%"
            
    # =================================================================
    # CSI Driver 告警
    # =================================================================
    - name: csi.alerts
      interval: 30s
      rules:
        - alert: CSIDriverNotReady
          expr: |
            sum(kube_pod_status_ready{pod=~".*csi.*", condition="true"}) by (pod, namespace) == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "CSI Driver Pod 未就绪"
            description: "CSI Driver Pod {{ $labels.namespace }}/{{ $labels.pod }} 未就绪"
            
        - alert: CSIProvisionerErrors
          expr: |
            rate(csi_operations_seconds_count{driver_name=~".+", operation_name="CreateVolume", status="error"}[5m]) > 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "CSI Provisioner 创建卷失败"
            description: "CSI Driver {{ $labels.driver_name }} 创建卷操作出现错误"
            
    # =================================================================
    # VolumeAttachment 告警
    # =================================================================
    - name: volumeattachment.alerts
      interval: 30s
      rules:
        - alert: VolumeAttachmentFailed
          expr: |
            time() - kube_volumeattachment_created > 300 
            and kube_volumeattachment_status_attached == 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "卷挂载失败"
            description: "VolumeAttachment {{ $labels.volumeattachment }} 创建超过 5 分钟仍未完成"
            
    # =================================================================
    # 记录规则
    # =================================================================
    - name: storage.recording
      interval: 30s
      rules:
        - record: pvc:storage:usage_ratio
          expr: |
            kubelet_volume_stats_used_bytes / 
            kubelet_volume_stats_capacity_bytes
            
        - record: pvc:storage:available_bytes
          expr: kubelet_volume_stats_available_bytes
          
        - record: pvc:inode:usage_ratio
          expr: |
            kubelet_volume_stats_inodes_used / 
            kubelet_volume_stats_inodes
            
        - record: cluster:pvc:pending_count
          expr: |
            count(kube_persistentvolumeclaim_status_phase{phase="Pending"})
            
        - record: cluster:pv:released_count
          expr: |
            count(kube_persistentvolume_status_phase{phase="Released"})
```

### 常用监控命令

```bash
#!/bin/bash
# storage-monitoring-commands.sh
# 存储监控常用命令集合

echo "=== PVC 容量使用情况 ==="
kubectl get pvc --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
STATUS:.status.phase,\
VOLUME:.spec.volumeName,\
CAPACITY:.status.capacity.storage,\
STORAGECLASS:.spec.storageClassName

echo ""
echo "=== 按 StorageClass 统计 PVC ==="
kubectl get pvc --all-namespaces -o json | jq -r '
  .items | group_by(.spec.storageClassName) | 
  map({
    storageClass: .[0].spec.storageClassName,
    count: length,
    totalSize: (map(.spec.resources.requests.storage // "0") | join(", "))
  }) | .[] | "\(.storageClass): \(.count) PVCs"'

echo ""
echo "=== 卷使用率 Top 10 (需要 metrics) ==="
kubectl top pvc --all-namespaces 2>/dev/null | head -11 || echo "需要安装 metrics-server"

echo ""
echo "=== 检查即将满的 PVC ==="
# 通过 kubelet metrics 检查
kubectl get --raw "/api/v1/nodes/$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')/proxy/stats/summary" 2>/dev/null | \
jq -r '.pods[].volume[]? | select(.usedBytes != null and .capacityBytes != null) | 
  select((.usedBytes / .capacityBytes) > 0.8) | 
  "PVC: \(.pvcRef.name // .name) Usage: \((.usedBytes / .capacityBytes * 100 | floor))%"' 2>/dev/null || \
echo "无法获取卷使用率数据"
```

## 版本变更记录

| 版本 | 变更内容 | 影响 |
|-----|---------|------|
| **v1.31** | VolumeAttributesClass GA | 支持动态修改卷属性 |
| | RecoverVolumeExpansionFailure GA | 自动恢复扩容失败 |
| **v1.30** | ReadWriteOncePod GA | 单 Pod 独占访问 |
| | CSI VolumeHealth GA | 卷健康监控 |
| **v1.29** | VolumeGroupSnapshot Alpha | 支持多卷一致性快照 |
| | CrossNamespaceVolumeDataSource Beta | 跨命名空间数据源 |
| **v1.28** | CSI SELinux Mount GA | SELinux 挂载选项支持 |
| | VolumeResourceQuota GA | 卷资源配额支持 |

## 最佳实践总结

### 故障预防清单

- [ ] 为生产环境配置 StorageClass 默认值
- [ ] 启用 `allowVolumeExpansion` 以支持在线扩容
- [ ] 使用 `WaitForFirstConsumer` 避免跨 AZ 调度问题
- [ ] 配置合适的 `reclaimPolicy` (生产环境建议 Retain)
- [ ] 部署存储容量监控和告警
- [ ] 定期检查 Released/Failed 状态的 PV
- [ ] 为重要数据配置定期快照
- [ ] 记录各 CSI Driver 的限制和最佳实践

### 关键监控指标

- `kube_persistentvolumeclaim_status_phase` - PVC 状态
- `kube_persistentvolume_status_phase` - PV 状态
- `kubelet_volume_stats_*` - 卷容量/Inode 使用
- `csi_operations_seconds_*` - CSI 操作延迟和错误
- `kube_volumeattachment_status_attached` - 挂载状态

---

**参考资料**:
- [Kubernetes 持久化存储](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [CSI 规范](https://github.com/container-storage-interface/spec)
- [Volume Snapshots](https://kubernetes.io/docs/concepts/storage/volume-snapshots/)
