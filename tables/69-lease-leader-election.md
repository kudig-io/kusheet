# 表格69: Lease与Leader选举

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/concepts/architecture/leases](https://kubernetes.io/docs/concepts/architecture/leases/)

## Lease对象

| 字段 | 类型 | 说明 |
|-----|-----|------|
| `spec.holderIdentity` | string | 当前持有者标识 |
| `spec.leaseDurationSeconds` | int | 租约持续时间 |
| `spec.acquireTime` | MicroTime | 获取时间 |
| `spec.renewTime` | MicroTime | 最后续租时间 |
| `spec.leaseTransitions` | int | 租约转移次数 |

## 系统Lease用途

| Lease | 命名空间 | 用途 |
|-------|---------|------|
| `kube-controller-manager` | kube-system | 控制器管理器选举 |
| `kube-scheduler` | kube-system | 调度器选举 |
| `<node-name>` | kube-node-lease | 节点心跳 |
| `cloud-controller-manager` | kube-system | 云控制器选举 |

## 节点心跳Lease

```yaml
apiVersion: coordination.k8s.io/v1
kind: Lease
metadata:
  name: node-1
  namespace: kube-node-lease
  ownerReferences:
  - apiVersion: v1
    kind: Node
    name: node-1
spec:
  holderIdentity: node-1
  leaseDurationSeconds: 40
  renewTime: "2024-01-15T10:30:00.000000Z"
```

## Leader选举参数

| 参数 | 默认值 | 说明 |
|-----|-------|------|
| `--leader-elect` | true | 启用Leader选举 |
| `--leader-elect-lease-duration` | 15s | 租约持续时间 |
| `--leader-elect-renew-deadline` | 10s | 续租截止时间 |
| `--leader-elect-retry-period` | 2s | 重试间隔 |
| `--leader-elect-resource-lock` | leases | 锁资源类型 |
| `--leader-elect-resource-name` | - | 锁资源名称 |
| `--leader-elect-resource-namespace` | kube-system | 锁资源命名空间 |

## client-go Leader选举

```go
package main

import (
    "context"
    "os"
    "time"
    
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/tools/leaderelection"
    "k8s.io/client-go/tools/leaderelection/resourcelock"
)

func main() {
    clientset := getClientset()
    
    // 创建锁
    lock := &resourcelock.LeaseLock{
        LeaseMeta: metav1.ObjectMeta{
            Name:      "my-controller-lock",
            Namespace: "default",
        },
        Client: clientset.CoordinationV1(),
        LockConfig: resourcelock.ResourceLockConfig{
            Identity: os.Getenv("POD_NAME"),
        },
    }
    
    // 配置Leader选举
    leaderelection.RunOrDie(context.TODO(), leaderelection.LeaderElectionConfig{
        Lock:            lock,
        ReleaseOnCancel: true,
        LeaseDuration:   15 * time.Second,
        RenewDeadline:   10 * time.Second,
        RetryPeriod:     2 * time.Second,
        Callbacks: leaderelection.LeaderCallbacks{
            OnStartedLeading: func(ctx context.Context) {
                // 成为Leader时执行
                runController(ctx)
            },
            OnStoppedLeading: func() {
                // 失去Leader时执行
                os.Exit(0)
            },
            OnNewLeader: func(identity string) {
                // 新Leader产生时回调
                if identity == os.Getenv("POD_NAME") {
                    return
                }
                log.Printf("new leader: %s", identity)
            },
        },
    })
}
```

## controller-runtime选举

```go
import (
    "sigs.k8s.io/controller-runtime/pkg/manager"
)

func main() {
    mgr, err := manager.New(cfg, manager.Options{
        LeaderElection:          true,
        LeaderElectionID:        "my-controller",
        LeaderElectionNamespace: "default",
        LeaseDuration:           15 * time.Second,
        RenewDeadline:           10 * time.Second,
        RetryPeriod:             2 * time.Second,
    })
}
```

## Lease监控命令

```bash
# 查看所有Lease
kubectl get leases -A

# 查看节点心跳
kubectl get leases -n kube-node-lease

# 查看控制器选举状态
kubectl get lease -n kube-system kube-controller-manager -o yaml

# 查看调度器选举状态
kubectl get lease -n kube-system kube-scheduler -o yaml
```

## Leader选举故障排查

| 问题 | 症状 | 排查方法 |
|-----|------|---------|
| 双主 | 两个实例同时工作 | 检查时间同步 |
| 无主 | 无实例工作 | 检查API Server连接 |
| 频繁切换 | Leader频繁变化 | 检查网络稳定性 |
| 续租失败 | Leader丢失 | 检查API Server负载 |

## Lease最佳实践

| 实践 | 说明 |
|-----|------|
| 合理设置超时 | leaseDuration > renewDeadline > retryPeriod |
| 监控选举 | 关注leaseTransitions |
| 时间同步 | 确保NTP同步 |
| 优雅退出 | ReleaseOnCancel=true |
| 身份唯一 | 使用Pod名作为identity |

## 节点心跳配置

| kubelet参数 | 默认值 | 说明 |
|------------|-------|------|
| `--node-lease-duration-seconds` | 40 | 租约持续时间 |
| `--node-status-update-frequency` | 10s | 状态更新频率 |

## 版本变更记录

| 版本 | 变更内容 |
|------|---------|
| v1.14 | Node Lease GA |
| v1.17 | Lease作为默认Leader选举资源 |
| v1.20 | Endpoints不再用于选举 |
| v1.27 | Lease优化 |
