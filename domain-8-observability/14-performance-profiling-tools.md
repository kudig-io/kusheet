# 109 - 性能分析与调优工具 (Performance Profiling)

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **难度**: 高级

## 性能分析工具生态架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        Kubernetes 性能分析工具生态                                    │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                           应用层 Profile (Application Layer)                  │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │    │
│  │  │  Pyroscope  │  │   Grafana   │  │    Async    │  │   Language Native   │ │    │
│  │  │ Continuous  │  │   Profiler  │  │  Profiler   │  │  (pprof/JFR/perf)   │ │    │
│  │  │  Profiling  │  │    Agent    │  │   (Python)  │  │                     │ │    │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘ │    │
│  └─────────┼────────────────┼────────────────┼───────────────────┼────────────┘    │
│            │                │                │                   │                  │
│  ┌─────────┼────────────────┼────────────────┼───────────────────┼────────────┐    │
│  │         ▼                ▼                ▼                   ▼            │    │
│  │                    eBPF 内核探针层 (Kernel Probes)                          │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐   │    │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐    │   │    │
│  │  │  │ kprobes    │  │ uprobes    │  │ tracepoint │  │ perf_event │    │   │    │
│  │  │  │ (内核函数) │  │ (用户函数) │  │  (静态点)  │  │  (性能计数) │    │   │    │
│  │  │  └────────────┘  └────────────┘  └────────────┘  └────────────┘    │   │    │
│  │  └─────────────────────────────────────────────────────────────────────┘   │    │
│  │                                                                             │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐   │    │
│  │  │                    eBPF 工具集                                       │   │    │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │   │    │
│  │  │  │  Inspektor   │  │    Pixie     │  │        bpftrace          │  │   │    │
│  │  │  │   Gadget     │  │   Auto-      │  │    (动态追踪脚本)         │  │   │    │
│  │  │  │ (K8s Native) │  │  Telemetry   │  │                          │  │   │    │
│  │  │  └──────────────┘  └──────────────┘  └──────────────────────────┘  │   │    │
│  │  └─────────────────────────────────────────────────────────────────────┘   │    │
│  └────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                         控制平面分析 (Control Plane)                         │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │    │
│  │  │   Kperf     │  │   etcd      │  │   API      │  │   Controller-Mgr   │ │    │
│  │  │  Benchmark  │  │  Analyzer   │  │  Priority  │  │      Profiler      │ │    │
│  │  │   (API)     │  │             │  │  & Fair.   │  │                     │ │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────────┘ │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                           存储与可视化 (Storage & Visualization)             │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │    │
│  │  │  Pyroscope  │  │   Grafana   │  │   Jaeger/   │  │   Prometheus +     │ │    │
│  │  │   Server    │  │   Explore   │  │   Tempo     │  │   Thanos/Mimir     │ │    │
│  │  │             │  │  火焰图     │  │   Traces    │  │                     │ │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────────┘ │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 性能分析工具全景对比矩阵

| 工具 (Tool) | 分析对象 (Target) | 技术栈 (Tech) | 采样开销 | 适用场景 | ACK 集成 |
|------------|-----------------|--------------|---------|---------|---------|
| **Inspektor Gadget** | 系统调用/网络/文件 | eBPF | <1% | 内核级性能分析 | ✅ DaemonSet |
| **Pyroscope** | 应用代码 CPU/内存/锁 | 持续 Profiling | 1-3% | CPU/内存热点定位 | ✅ Helm Chart |
| **Pixie** | 全栈可观测 | eBPF + WASM | 2-5% | 零侵入性监控 | ⚠️ 需配置 |
| **Kperf** | Kubernetes API Server | Go 压测 | N/A | 控制平面性能基准 | ✅ 工具级 |
| **pprof** | Go 应用 | 原生 runtime | 1-5% | Go 程序深度优化 | ✅ 内置 |
| **async-profiler** | JVM 应用 | Native Agent | <1% | Java 应用分析 | ✅ Agent |
| **perf** | Linux 全系统 | 硬件计数器 | <1% | 系统级瓶颈 | ✅ Node 级 |
| **bpftrace** | 动态追踪 | eBPF + 脚本 | 可变 | 临时调试探针 | ✅ 工具级 |

## Inspektor Gadget eBPF 分析平台

### 1. 架构与安装

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         Inspektor Gadget 架构                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────┐                                                                │
│  │   kubectl   │──── kubectl gadget ─────┐                                      │
│  │   gadget    │                          │                                      │
│  │   plugin    │                          ▼                                      │
│  └─────────────┘              ┌───────────────────────┐                         │
│                               │    Gadget Tracer      │                         │
│                               │   (gadget-tracer-     │                         │
│                               │     manager pod)      │                         │
│                               └───────────┬───────────┘                         │
│                                           │                                      │
│          ┌────────────────────────────────┼────────────────────────────────┐    │
│          │                                │                                 │    │
│          ▼                                ▼                                 ▼    │
│  ┌───────────────┐              ┌───────────────┐              ┌───────────────┐│
│  │  Node Agent   │              │  Node Agent   │              │  Node Agent   ││
│  │  (DaemonSet)  │              │  (DaemonSet)  │              │  (DaemonSet)  ││
│  │               │              │               │              │               ││
│  │ ┌───────────┐ │              │ ┌───────────┐ │              │ ┌───────────┐ ││
│  │ │ eBPF Prog │ │              │ │ eBPF Prog │ │              │ │ eBPF Prog │ ││
│  │ └─────┬─────┘ │              │ └─────┬─────┘ │              │ └─────┬─────┘ ││
│  │       │       │              │       │       │              │       │       ││
│  │ ┌─────▼─────┐ │              │ ┌─────▼─────┐ │              │ ┌─────▼─────┐ ││
│  │ │  Kernel   │ │              │ │  Kernel   │ │              │ │  Kernel   │ ││
│  │ │  Events   │ │              │ │  Events   │ │              │ │  Events   │ ││
│  │ └───────────┘ │              │ └───────────┘ │              │ └───────────┘ ││
│  └───────────────┘              └───────────────┘              └───────────────┘│
│       Node 1                         Node 2                         Node 3      │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 2. 完整部署配置

```yaml
# inspektor-gadget-deployment.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: gadget
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gadget
  namespace: gadget
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: gadget-cluster-role
rules:
  - apiGroups: [""]
    resources: ["namespaces", "nodes", "pods"]
    verbs: ["get", "watch", "list"]
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["list"]
  - apiGroups: ["apps"]
    resources: ["daemonsets", "deployments", "replicasets", "statefulsets"]
    verbs: ["list"]
  - apiGroups: ["gadget.kinvolk.io"]
    resources: ["traces"]
    verbs: ["create", "get", "list", "watch", "delete", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gadget-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: gadget-cluster-role
subjects:
  - kind: ServiceAccount
    name: gadget
    namespace: gadget
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: gadget
  namespace: gadget
  labels:
    k8s-app: gadget
spec:
  selector:
    matchLabels:
      k8s-app: gadget
  template:
    metadata:
      labels:
        k8s-app: gadget
    spec:
      serviceAccountName: gadget
      hostPID: true
      hostNetwork: true
      containers:
        - name: gadget
          image: ghcr.io/inspektor-gadget/inspektor-gadget:v0.28.0
          imagePullPolicy: Always
          terminationMessagePolicy: FallbackToLogsOnError
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: GADGET_POD_UID
              valueFrom:
                fieldRef:
                  fieldPath: metadata.uid
            - name: TRACELOOP_NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: TRACELOOP_POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: TRACELOOP_POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: INSPEKTOR_GADGET_VERSION
              value: "v0.28.0"
            - name: INSPEKTOR_GADGET_OPTION_HOOK_MODE
              value: "auto"
          securityContext:
            privileged: true
            capabilities:
              add:
                - SYS_ADMIN
                - SYS_PTRACE
                - NET_ADMIN
                - SYS_RESOURCE
          volumeMounts:
            - name: host
              mountPath: /host
            - name: run
              mountPath: /run
            - name: modules
              mountPath: /lib/modules
            - name: debugfs
              mountPath: /sys/kernel/debug
            - name: cgroup
              mountPath: /sys/fs/cgroup
            - name: bpffs
              mountPath: /sys/fs/bpf
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 1Gi
      tolerations:
        - effect: NoSchedule
          operator: Exists
        - effect: NoExecute
          operator: Exists
      volumes:
        - name: host
          hostPath:
            path: /
        - name: run
          hostPath:
            path: /run
        - name: cgroup
          hostPath:
            path: /sys/fs/cgroup
        - name: modules
          hostPath:
            path: /lib/modules
        - name: bpffs
          hostPath:
            path: /sys/fs/bpf
        - name: debugfs
          hostPath:
            path: /sys/kernel/debug
```

### 3. Gadget 完整使用手册

```bash
# ==================== 安装与验证 ====================

# 方式一: 使用 kubectl-gadget 插件 (推荐)
kubectl krew install gadget
kubectl gadget deploy

# 方式二: 手动部署
kubectl apply -f inspektor-gadget-deployment.yaml

# 验证安装
kubectl gadget version
kubectl get pods -n gadget

# 查看可用 Gadgets
kubectl gadget list-gadgets

# ==================== 进程追踪 ====================

# 追踪所有 exec 系统调用
kubectl gadget trace exec -A

# 追踪指定命名空间
kubectl gadget trace exec -n production

# 追踪指定 Pod
kubectl gadget trace exec -n production -p nginx-pod

# 追踪指定容器
kubectl gadget trace exec -n production -p nginx-pod -c nginx

# 按标签过滤
kubectl gadget trace exec -n production -l app=nginx

# 输出 JSON 格式
kubectl gadget trace exec -n production -o json

# ==================== 网络分析 ====================

# TCP 连接追踪
kubectl gadget trace tcpconnect -n production

# TCP 连接追踪 (包含延迟)
kubectl gadget trace tcpconnect -n production --latency

# TCP 重传追踪 (定位网络问题)
kubectl gadget trace tcpretrans -A

# TCP 状态追踪
kubectl gadget trace tcpstate -n production

# DNS 查询追踪
kubectl gadget trace dns -n production

# DNS 查询追踪 (带详细信息)
kubectl gadget trace dns -n production --latency

# 网络带宽 top
kubectl gadget top tcp -n production

# ==================== 文件系统分析 ====================

# 文件打开追踪
kubectl gadget trace open -n production

# 过滤特定文件
kubectl gadget trace open -n production --filename "/etc/passwd"

# 文件读写统计
kubectl gadget top file -n production

# 文件系统延迟分析
kubectl gadget trace fsslower -n production --min-latency 10ms

# ==================== 内存分析 ====================

# OOM 事件监控
kubectl gadget trace oomkill

# 内存分配追踪
kubectl gadget trace malloc -n production

# 页错误分析
kubectl gadget trace pagefault -n production

# ==================== 安全审计 ====================

# 能力使用追踪
kubectl gadget trace capabilities -n production

# 信号追踪
kubectl gadget trace signal -n production

# Seccomp 违规追踪
kubectl gadget trace seccomp -n production

# ==================== 性能 Top ====================

# eBPF 程序 CPU 使用 top
kubectl gadget top ebpf

# 块设备 I/O top
kubectl gadget top block-io -n production

# 文件 I/O top
kubectl gadget top file -n production

# TCP 连接 top
kubectl gadget top tcp -n production

# ==================== 高级功能 ====================

# 追踪结果保存到文件
kubectl gadget trace exec -n production -o json > exec-trace.json

# 实时 Profile (需要 gadget 支持)
kubectl gadget profile cpu -n production --duration 30s

# 快照功能 - 获取当前进程列表
kubectl gadget snapshot process -n production

# 快照功能 - 获取当前 socket 列表
kubectl gadget snapshot socket -n production
```

### 4. 自定义 eBPF Gadget 开发

```go
// custom-gadget/main.go
package main

import (
    "context"
    "fmt"
    "os"
    "os/signal"
    "syscall"
    
    "github.com/cilium/ebpf"
    "github.com/cilium/ebpf/link"
    "github.com/cilium/ebpf/rlimit"
)

//go:generate go run github.com/cilium/ebpf/cmd/bpf2go -target amd64 customGadget custom_gadget.c

type Event struct {
    Pid      uint32
    Comm     [16]byte
    Filename [256]byte
    Latency  uint64
}

func main() {
    // 提升内存限制
    if err := rlimit.RemoveMemlock(); err != nil {
        fmt.Fprintf(os.Stderr, "failed to remove memlock limit: %v\n", err)
        os.Exit(1)
    }
    
    // 加载 eBPF 对象
    objs := customGadgetObjects{}
    if err := loadCustomGadgetObjects(&objs, nil); err != nil {
        fmt.Fprintf(os.Stderr, "failed to load eBPF objects: %v\n", err)
        os.Exit(1)
    }
    defer objs.Close()
    
    // 附加到 kprobe
    kp, err := link.Kprobe("vfs_open", objs.TraceVfsOpen, nil)
    if err != nil {
        fmt.Fprintf(os.Stderr, "failed to attach kprobe: %v\n", err)
        os.Exit(1)
    }
    defer kp.Close()
    
    // 信号处理
    ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
    defer cancel()
    
    fmt.Println("Tracing vfs_open... Press Ctrl+C to exit")
    
    // 读取事件
    reader, err := perf.NewReader(objs.Events, 4096)
    if err != nil {
        fmt.Fprintf(os.Stderr, "failed to create perf reader: %v\n", err)
        os.Exit(1)
    }
    defer reader.Close()
    
    go func() {
        for {
            record, err := reader.Read()
            if err != nil {
                return
            }
            
            var event Event
            if err := binary.Read(bytes.NewReader(record.RawSample), binary.LittleEndian, &event); err != nil {
                continue
            }
            
            fmt.Printf("PID: %d, Comm: %s, File: %s, Latency: %dμs\n",
                event.Pid,
                nullTerminatedString(event.Comm[:]),
                nullTerminatedString(event.Filename[:]),
                event.Latency/1000,
            )
        }
    }()
    
    <-ctx.Done()
    fmt.Println("\nExiting...")
}

func nullTerminatedString(b []byte) string {
    for i, c := range b {
        if c == 0 {
            return string(b[:i])
        }
    }
    return string(b)
}
```

```c
// custom-gadget/custom_gadget.c
#include "vmlinux.h"
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>
#include <bpf/bpf_core_read.h>

char LICENSE[] SEC("license") = "GPL";

struct event {
    u32 pid;
    char comm[16];
    char filename[256];
    u64 latency;
};

struct {
    __uint(type, BPF_MAP_TYPE_PERF_EVENT_ARRAY);
    __uint(key_size, sizeof(u32));
    __uint(value_size, sizeof(u32));
} events SEC(".maps");

struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 10240);
    __type(key, u64);
    __type(value, u64);
} start SEC(".maps");

SEC("kprobe/vfs_open")
int BPF_KPROBE(trace_vfs_open, const struct path *path, struct file *file)
{
    u64 pid_tgid = bpf_get_current_pid_tgid();
    u64 ts = bpf_ktime_get_ns();
    
    bpf_map_update_elem(&start, &pid_tgid, &ts, BPF_ANY);
    
    return 0;
}

SEC("kretprobe/vfs_open")
int BPF_KRETPROBE(trace_vfs_open_ret, int ret)
{
    u64 pid_tgid = bpf_get_current_pid_tgid();
    u64 *tsp;
    
    tsp = bpf_map_lookup_elem(&start, &pid_tgid);
    if (!tsp)
        return 0;
    
    u64 latency = bpf_ktime_get_ns() - *tsp;
    bpf_map_delete_elem(&start, &pid_tgid);
    
    // 只记录延迟超过 1ms 的操作
    if (latency < 1000000)
        return 0;
    
    struct event event = {};
    event.pid = pid_tgid >> 32;
    event.latency = latency;
    bpf_get_current_comm(&event.comm, sizeof(event.comm));
    
    bpf_perf_event_output(ctx, &events, BPF_F_CURRENT_CPU, &event, sizeof(event));
    
    return 0;
}
```

## Pyroscope 持续性能分析平台

### 1. 架构概览

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Pyroscope 持续 Profiling 架构                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                        应用层 (Applications)                              │   │
│  │                                                                           │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │   │
│  │  │   Go App    │  │  Java App   │  │ Python App  │  │   Node.js App   │  │   │
│  │  │             │  │             │  │             │  │                 │  │   │
│  │  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────────┐ │  │   │
│  │  │ │  pprof  │ │  │ │   JFR   │ │  │ │py-spy   │ │  │ │  v8 prof    │ │  │   │
│  │  │ │  agent  │ │  │ │  async  │ │  │ │ agent   │ │  │ │   agent     │ │  │   │
│  │  │ └────┬────┘ │  │ └────┬────┘ │  │ └────┬────┘ │  │ └──────┬──────┘ │  │   │
│  │  └──────┼──────┘  └──────┼──────┘  └──────┼──────┘  └────────┼────────┘  │   │
│  └─────────┼────────────────┼────────────────┼──────────────────┼───────────┘   │
│            │                │                │                  │               │
│            └────────────────┴────────────────┴──────────────────┘               │
│                                      │                                          │
│                                      ▼                                          │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                    Pyroscope Agent / eBPF Profiler                        │   │
│  │                                                                           │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐   │   │
│  │  │  Pull 模式      │  │  Push 模式       │  │   eBPF 模式             │   │   │
│  │  │  (scrape)       │  │  (SDK 推送)      │  │   (零侵入)              │   │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                          │
│                                      ▼                                          │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                         Pyroscope Server                                  │   │
│  │                                                                           │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │   │
│  │  │  Ingester   │  │  Compactor  │  │   Querier   │  │   Store-gateway │  │   │
│  │  │             │  │             │  │             │  │                 │  │   │
│  │  │ 接收 prof   │  │  压缩存储   │  │  查询引擎   │  │   对象存储网关  │  │   │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └────────┬────────┘  │   │
│  │         │                │                │                  │            │   │
│  │         └────────────────┴────────────────┴──────────────────┘            │   │
│  │                                 │                                          │   │
│  └─────────────────────────────────┼──────────────────────────────────────────┘   │
│                                    │                                              │
│                                    ▼                                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                              存储层                                       │   │
│  │                                                                           │   │
│  │  ┌─────────────────────────┐  ┌───────────────────────────────────────┐  │   │
│  │  │      本地 Block         │  │           S3/GCS/MinIO                 │  │   │
│  │  │      Storage            │  │        对象存储 (生产推荐)             │  │   │
│  │  └─────────────────────────┘  └───────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 2. 生产级 Helm 部署

```yaml
# pyroscope-values.yaml
pyroscope:
  replicaCount: 3
  
  image:
    repository: grafana/pyroscope
    tag: 1.5.0
    pullPolicy: IfNotPresent
  
  # 单体模式或微服务模式
  # target: all (单体) | ingester,querier,compactor,store-gateway (微服务)
  extraArgs:
    - "-target=all"
    - "-config.expand-env=true"
  
  config: |
    # 通用配置
    analytics:
      reporting_enabled: false
    
    # 服务器配置
    server:
      http_listen_port: 4040
      grpc_listen_port: 9095
      log_level: info
    
    # 分布式配置
    memberlist:
      join_members:
        - pyroscope-memberlist
    
    # Ingester 配置
    ingester:
      lifecycler:
        ring:
          kvstore:
            store: memberlist
          replication_factor: 3
    
    # 查询前端配置
    query_frontend:
      address: "pyroscope-query-frontend:9095"
    
    # 存储配置 - 生产使用对象存储
    storage:
      backend: s3
      s3:
        endpoint: "s3.cn-hangzhou.aliyuncs.com"
        bucket_name: "pyroscope-profiles"
        region: "cn-hangzhou"
        access_key_id: "${AWS_ACCESS_KEY_ID}"
        secret_access_key: "${AWS_SECRET_ACCESS_KEY}"
    
    # 限流配置
    limits:
      max_query_length: 24h
      max_query_parallelism: 32
      ingestion_rate_mb: 64
      ingestion_burst_size_mb: 128
    
    # 压缩器配置
    compactor:
      data_dir: /data/compactor
      compaction_interval: 1h
      block_retention: 720h  # 30天
  
  resources:
    requests:
      cpu: "500m"
      memory: "2Gi"
    limits:
      cpu: "2"
      memory: "8Gi"
  
  persistence:
    enabled: true
    storageClassName: alicloud-disk-ssd
    size: 100Gi
  
  # 环境变量 (从 Secret 注入)
  envFrom:
    - secretRef:
        name: pyroscope-s3-credentials

# Grafana Agent 配置 - eBPF 模式采集
grafanaAgent:
  enabled: true
  
  agent:
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
    
    extraArgs:
      - -config.expand-env=true
      - -enable-features=integrations-next
    
    configMap:
      content: |
        server:
          log_level: info
        
        pyroscope.ebpf "instance" {
          forward_to = [pyroscope.write.endpoint.receiver]
          
          targets = [
            {"__address__" = "pyroscope:4040", "service_name" = "all"},
          ]
          
          collect_interval = "15s"
          sample_rate = 97
          
          # 按命名空间过滤
          targets_only = true
          default_target = {
            "__address__" = "localhost",
          }
        }
        
        pyroscope.write "endpoint" {
          endpoint {
            url = "http://pyroscope:4040"
          }
          
          external_labels = {
            cluster = "production",
            env     = "prod",
          }
        }

# Ingress 配置
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
  hosts:
    - host: pyroscope.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: pyroscope-tls
      hosts:
        - pyroscope.example.com

# ServiceMonitor 配置
serviceMonitor:
  enabled: true
  interval: 30s
  scrapeTimeout: 10s
```

### 3. 多语言 SDK 集成

```go
// Go 应用集成 - 使用 pprof SDK
package main

import (
    "context"
    "log"
    "os"
    "runtime"
    
    "github.com/grafana/pyroscope-go"
)

func main() {
    // 配置 Pyroscope
    pyroscope.Start(pyroscope.Config{
        ApplicationName: "my-go-service",
        ServerAddress:   os.Getenv("PYROSCOPE_SERVER_ADDRESS"),
        
        // 可选: 添加标签
        Tags: map[string]string{
            "hostname": os.Getenv("HOSTNAME"),
            "region":   os.Getenv("REGION"),
            "version":  "v1.2.3",
        },
        
        // 启用所有 Profile 类型
        ProfileTypes: []pyroscope.ProfileType{
            pyroscope.ProfileCPU,
            pyroscope.ProfileAllocObjects,
            pyroscope.ProfileAllocSpace,
            pyroscope.ProfileInuseObjects,
            pyroscope.ProfileInuseSpace,
            pyroscope.ProfileGoroutines,
            pyroscope.ProfileMutexCount,
            pyroscope.ProfileMutexDuration,
            pyroscope.ProfileBlockCount,
            pyroscope.ProfileBlockDuration,
        },
        
        // 上传间隔
        UploadRate: 10,  // 10秒上传一次
        
        // 日志
        Logger: pyroscope.StandardLogger,
    })
    
    // 应用逻辑...
    runApp()
}

// 使用 span 进行细粒度追踪
func processRequest(ctx context.Context) {
    // 开始一个命名的 span
    pyroscope.TagWrapper(ctx, pyroscope.Labels("request_type", "api"), func(c context.Context) {
        // 处理逻辑
        doWork()
    })
}
```

```java
// Java 应用集成 - 使用 async-profiler
// pom.xml
/*
<dependency>
    <groupId>io.pyroscope</groupId>
    <artifactId>agent</artifactId>
    <version>0.13.0</version>
</dependency>
*/

package com.example;

import io.pyroscope.http.Format;
import io.pyroscope.javaagent.PyroscopeAgent;
import io.pyroscope.javaagent.config.Config;
import io.pyroscope.javaagent.EventType;

public class Application {
    public static void main(String[] args) {
        // 配置 Pyroscope Agent
        PyroscopeAgent.start(
            new Config.Builder()
                .setApplicationName("my-java-service")
                .setServerAddress(System.getenv("PYROSCOPE_SERVER_ADDRESS"))
                .setProfilingEvent(EventType.ITIMER)
                .setProfilingAlloc("512k")  // 分配采样阈值
                .setProfilingLock("10ms")   // 锁采样阈值
                .setFormat(Format.JFR)      // 使用 JFR 格式
                .setLabels(Map.of(
                    "hostname", System.getenv("HOSTNAME"),
                    "version", "1.0.0"
                ))
                .build()
        );
        
        // 启动应用
        SpringApplication.run(Application.class, args);
    }
}

// 在代码中添加标签
import io.pyroscope.javaagent.api.Pyroscope;

public class OrderService {
    public void processOrder(Order order) {
        Pyroscope.LabelsWrapper.run(
            new LabelsSet("order_type", order.getType()),
            () -> {
                // 处理订单
                doProcess(order);
            }
        );
    }
}
```

```python
# Python 应用集成
import os
import pyroscope

# 配置 Pyroscope
pyroscope.configure(
    application_name="my-python-service",
    server_address=os.getenv("PYROSCOPE_SERVER_ADDRESS"),
    
    # 可选标签
    tags={
        "hostname": os.getenv("HOSTNAME"),
        "region": os.getenv("REGION"),
        "version": "1.0.0",
    },
    
    # 采样率 (Hz)
    sample_rate=100,
    
    # 启用分配追踪
    detect_subprocesses=True,
    oncpu=True,
    gil_only=False,  # 也追踪非 GIL 持有时间
)

# 使用上下文管理器进行细粒度追踪
from pyroscope import tag_wrapper

def process_request(request):
    with tag_wrapper({"request_type": "api", "endpoint": request.path}):
        # 处理逻辑
        return handle_request(request)

# 手动标签设置
def batch_process():
    pyroscope.add_tags({"job_type": "batch"})
    try:
        process_batch()
    finally:
        pyroscope.remove_tags({"job_type": "batch"})
```

```javascript
// Node.js 应用集成
const Pyroscope = require('@pyroscope/nodejs');

// 初始化 Pyroscope
Pyroscope.init({
  serverAddress: process.env.PYROSCOPE_SERVER_ADDRESS,
  appName: 'my-nodejs-service',
  
  tags: {
    hostname: process.env.HOSTNAME,
    region: process.env.REGION,
    version: '1.0.0',
  },
  
  // Wall-clock 采样
  wallCollectCpuTime: true,
  
  // 采样率
  samplingIntervalMicros: 10000,  // 10ms
});

// 启动 Profiling
Pyroscope.start();

// Express 中间件 - 自动添加标签
const express = require('express');
const app = express();

app.use((req, res, next) => {
  Pyroscope.wrapWithLabels(
    {
      endpoint: req.path,
      method: req.method,
    },
    () => next()
  );
});

// 关闭时停止
process.on('SIGTERM', () => {
  Pyroscope.stop();
  process.exit(0);
});
```

### 4. Kubernetes 部署配置

```yaml
# deployment-with-pyroscope.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
      annotations:
        # Pyroscope scrape 配置
        pyroscope.io/scrape: "true"
        pyroscope.io/port: "6060"
        pyroscope.io/path: "/debug/pprof"
    spec:
      containers:
        - name: myapp
          image: myapp:v1.0.0
          ports:
            - containerPort: 8080
              name: http
            - containerPort: 6060
              name: pprof
          env:
            # Push 模式配置
            - name: PYROSCOPE_SERVER_ADDRESS
              value: "http://pyroscope.monitoring:4040"
            - name: PYROSCOPE_APPLICATION_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.labels['app']
            - name: HOSTNAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: PYROSCOPE_TAGS
              value: "namespace=$(NAMESPACE),pod=$(HOSTNAME)"
            - name: NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          resources:
            requests:
              cpu: 200m
              memory: 512Mi
            limits:
              cpu: "1"
              memory: 1Gi
```

### 5. 火焰图分析与解读

```bash
# ==================== Pyroscope CLI 使用 ====================

# 安装 CLI
brew install pyroscope-io/tap/pyroscope

# 连接到 Pyroscope 服务器
export PYROSCOPE_SERVER_ADDRESS=http://pyroscope.example.com

# 查询应用列表
pyroscope admin app list

# 导出 Profile 数据
pyroscope export \
  --from="now-1h" \
  --to="now" \
  --app-name="my-go-service" \
  --output-format=collapsed \
  > profile.txt

# 对比分析
pyroscope compare \
  --baseline 'my-go-service{version="v1.0"}' \
  --comparison 'my-go-service{version="v1.1"}' \
  --from="now-1h" \
  --to="now"

# 生成差异火焰图
pyroscope diff \
  --baseline-from="2024-01-15T00:00:00Z" \
  --baseline-to="2024-01-15T01:00:00Z" \
  --comparison-from="2024-01-16T00:00:00Z" \
  --comparison-to="2024-01-16T01:00:00Z" \
  --app-name="my-go-service"

# ==================== Profile 类型说明 ====================

# CPU Profile - 识别计算密集型函数
# - 火焰图宽度表示函数占用 CPU 时间比例
# - 关注最宽的 "plateau" (平台)

# Heap/Memory Profile - 内存分配热点
# - alloc_objects: 分配的对象数量
# - alloc_space: 分配的内存大小 (bytes)
# - inuse_objects: 当前使用的对象数量 (检测泄漏)
# - inuse_space: 当前使用的内存大小

# Goroutine Profile (Go) - 并发瓶颈
# - 大量 goroutine 阻塞在同一函数表示瓶颈

# Mutex Profile - 锁竞争
# - contentions: 锁争用次数
# - delay: 等待锁的总时间

# Block Profile - 阻塞分析
# - 识别 channel 操作、系统调用等阻塞点
```

## Kperf - Kubernetes API Server 压测

### 1. 完整安装与配置

```bash
# 安装 Kperf
go install sigs.k8s.io/kperf@latest

# 或从源码编译
git clone https://github.com/kubernetes-sigs/kperf.git
cd kperf
make build
cp bin/kperf /usr/local/bin/
```

### 2. 压测场景配置

```yaml
# kperf-scenarios.yaml
# Pod 创建压测
scenarios:
  - name: pod-creation-burst
    description: "测试 Pod 突发创建性能"
    type: pod
    config:
      replicas: 500
      qps: 100
      burst: 200
      duration: 5m
      namespace: perf-test
      podTemplate:
        spec:
          containers:
            - name: nginx
              image: nginx:alpine
              resources:
                requests:
                  cpu: 10m
                  memory: 16Mi
                limits:
                  cpu: 50m
                  memory: 64Mi
          terminationGracePeriodSeconds: 0
    
  - name: service-endpoint-scale
    description: "测试大规模 Endpoint 更新性能"
    type: service
    config:
      services: 100
      endpointsPerService: 100
      qps: 50
      duration: 10m

  - name: configmap-heavy-read
    description: "测试 ConfigMap 读取性能"
    type: custom
    config:
      action: get
      resource: configmaps
      qps: 1000
      clients: 50
      duration: 5m
```

```bash
# ==================== 基础压测命令 ====================

# Pod 创建压测
kperf pod \
  --replicas 100 \
  --duration 60s \
  --qps 20 \
  --namespace perf-test

# Service 创建压测
kperf service \
  --replicas 50 \
  --duration 30s \
  --qps 10

# ConfigMap 创建压测
kperf configmap \
  --replicas 200 \
  --duration 60s \
  --qps 50

# ==================== 高级压测场景 ====================

# 自定义 QPS 和并发
kperf pod \
  --replicas 500 \
  --qps 100 \
  --burst 200 \
  --namespace perf-test \
  --kubeconfig ~/.kube/config

# 带资源清理的压测
kperf pod \
  --replicas 100 \
  --duration 5m \
  --cleanup=true \
  --cleanup-timeout 2m

# 指定 Pod 模板
kperf pod \
  --replicas 100 \
  --pod-template ./pod-template.yaml \
  --duration 5m

# ==================== 结果分析 ====================

# 输出 JSON 格式报告
kperf pod \
  --replicas 100 \
  --duration 60s \
  --output json > results.json

# 分析关键指标
cat results.json | jq '.summary | {
  p50_latency: .p50Latency,
  p95_latency: .p95Latency,
  p99_latency: .p99Latency,
  total_requests: .totalRequests,
  success_rate: .successRate,
  qps_achieved: .actualQPS
}'
```

### 3. API Server 性能基准脚本

```bash
#!/bin/bash
# api-server-benchmark.sh

set -euo pipefail

NAMESPACE="api-benchmark"
RESULTS_DIR="./benchmark-results"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 创建测试命名空间
setup() {
    log "Setting up benchmark namespace..."
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    mkdir -p $RESULTS_DIR
}

# 清理资源
cleanup() {
    log "Cleaning up resources..."
    kubectl delete namespace $NAMESPACE --ignore-not-found --wait=false
}

trap cleanup EXIT

# 测试 1: Pod 创建延迟
test_pod_creation_latency() {
    log "Test 1: Pod Creation Latency"
    
    local results_file="$RESULTS_DIR/pod-creation-$TIMESTAMP.json"
    
    kperf pod \
        --replicas 100 \
        --qps 10 \
        --duration 60s \
        --namespace $NAMESPACE \
        --output json > "$results_file"
    
    local p50=$(jq -r '.summary.p50Latency' "$results_file")
    local p99=$(jq -r '.summary.p99Latency' "$results_file")
    
    log "Pod Creation - P50: ${p50}ms, P99: ${p99}ms"
    
    # 性能阈值检查
    if (( $(echo "$p99 > 5000" | bc -l) )); then
        warn "P99 latency exceeds 5s threshold!"
        return 1
    fi
}

# 测试 2: List 操作性能
test_list_performance() {
    log "Test 2: List Operations Performance"
    
    # 创建测试数据
    for i in $(seq 1 1000); do
        kubectl create configmap "cm-$i" \
            --from-literal="key=value-$i" \
            -n $NAMESPACE \
            --dry-run=client -o yaml
    done | kubectl apply -f - --server-side
    
    # 测试 List 性能
    local start_time=$(date +%s.%N)
    kubectl get configmaps -n $NAMESPACE -o name | wc -l
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    log "List 1000 ConfigMaps: ${duration}s"
}

# 测试 3: Watch 性能
test_watch_performance() {
    log "Test 3: Watch Performance"
    
    local watch_count=0
    local timeout=30
    
    # 启动 Watch
    kubectl get pods -n $NAMESPACE -w --output-watch-events &
    local watch_pid=$!
    
    # 创建触发事件的 Pod
    for i in $(seq 1 50); do
        kubectl run "test-pod-$i" \
            --image=nginx:alpine \
            --restart=Never \
            -n $NAMESPACE \
            --dry-run=client -o yaml | kubectl apply -f - &
    done
    wait
    
    sleep 5
    kill $watch_pid 2>/dev/null || true
    
    log "Watch test completed"
}

# 测试 4: 并发请求压力
test_concurrent_requests() {
    log "Test 4: Concurrent Requests"
    
    local concurrent=50
    local requests=1000
    
    # 使用 GNU parallel 发送并发请求
    seq 1 $requests | parallel -j $concurrent \
        "kubectl get nodes -o name > /dev/null 2>&1"
    
    log "Completed $requests requests with $concurrent concurrency"
}

# 测试 5: etcd 性能
test_etcd_performance() {
    log "Test 5: etcd Performance Check"
    
    # 获取 etcd metrics (需要访问权限)
    local etcd_pod=$(kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}')
    
    if [[ -n "$etcd_pod" ]]; then
        # 检查 etcd 延迟
        kubectl exec -n kube-system $etcd_pod -- \
            etcdctl endpoint status --write-out=table 2>/dev/null || true
    else
        warn "etcd pod not found or not accessible"
    fi
}

# 生成报告
generate_report() {
    log "Generating benchmark report..."
    
    cat > "$RESULTS_DIR/report-$TIMESTAMP.md" << EOF
# Kubernetes API Server Benchmark Report

**Date**: $(date)
**Cluster**: $(kubectl config current-context)

## Summary

### Pod Creation Performance
$(cat "$RESULTS_DIR/pod-creation-$TIMESTAMP.json" 2>/dev/null | jq -r '.summary' || echo "N/A")

## Recommendations

Based on the benchmark results:

1. **If P99 > 5s**: Consider scaling API Server replicas
2. **If List operations slow**: Enable pagination, consider etcd compaction
3. **If Watch lag**: Check network bandwidth, increase watch cache size

EOF

    log "Report saved to $RESULTS_DIR/report-$TIMESTAMP.md"
}

# 主流程
main() {
    setup
    
    test_pod_creation_latency
    test_list_performance
    test_watch_performance
    test_concurrent_requests
    test_etcd_performance
    
    generate_report
    
    log "Benchmark completed successfully!"
}

main "$@"
```

## pprof - Go 应用深度分析

### 1. 完整集成方案

```go
// pkg/profiling/profiler.go
package profiling

import (
    "context"
    "fmt"
    "log"
    "net/http"
    _ "net/http/pprof"
    "os"
    "os/signal"
    "runtime"
    "runtime/pprof"
    "sync"
    "syscall"
    "time"
)

// Config 配置 profiler
type Config struct {
    // HTTP pprof 端口
    HTTPPort int
    
    // 是否启用连续 CPU Profile
    ContinuousCPUProfile bool
    
    // CPU Profile 文件路径前缀
    CPUProfilePath string
    
    // CPU Profile 持续时间
    CPUProfileDuration time.Duration
    
    // 内存 Profile 间隔
    MemProfileInterval time.Duration
    
    // 内存 Profile 文件路径前缀
    MemProfilePath string
    
    // 阻塞 Profile 采样率
    BlockProfileRate int
    
    // 互斥锁 Profile 采样率
    MutexProfileFraction int
}

// DefaultConfig 返回默认配置
func DefaultConfig() *Config {
    return &Config{
        HTTPPort:             6060,
        ContinuousCPUProfile: false,
        CPUProfilePath:       "/tmp/cpu",
        CPUProfileDuration:   30 * time.Second,
        MemProfileInterval:   5 * time.Minute,
        MemProfilePath:       "/tmp/mem",
        BlockProfileRate:     1,
        MutexProfileFraction: 1,
    }
}

// Profiler 管理所有 profiling
type Profiler struct {
    config *Config
    server *http.Server
    wg     sync.WaitGroup
    ctx    context.Context
    cancel context.CancelFunc
}

// New 创建新的 Profiler
func New(config *Config) *Profiler {
    if config == nil {
        config = DefaultConfig()
    }
    
    ctx, cancel := context.WithCancel(context.Background())
    
    return &Profiler{
        config: config,
        ctx:    ctx,
        cancel: cancel,
    }
}

// Start 启动 Profiler
func (p *Profiler) Start() error {
    // 设置阻塞和互斥锁 Profile 采样率
    runtime.SetBlockProfileRate(p.config.BlockProfileRate)
    runtime.SetMutexProfileFraction(p.config.MutexProfileFraction)
    
    // 启动 HTTP pprof 服务器
    p.wg.Add(1)
    go p.startHTTPServer()
    
    // 启动连续 CPU Profile (如果启用)
    if p.config.ContinuousCPUProfile {
        p.wg.Add(1)
        go p.continuousCPUProfile()
    }
    
    // 启动定期内存 Profile
    if p.config.MemProfileInterval > 0 {
        p.wg.Add(1)
        go p.periodicMemProfile()
    }
    
    log.Printf("Profiler started on port %d", p.config.HTTPPort)
    return nil
}

// Stop 停止 Profiler
func (p *Profiler) Stop() error {
    p.cancel()
    
    if p.server != nil {
        ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
        defer cancel()
        p.server.Shutdown(ctx)
    }
    
    p.wg.Wait()
    log.Println("Profiler stopped")
    return nil
}

func (p *Profiler) startHTTPServer() {
    defer p.wg.Done()
    
    mux := http.NewServeMux()
    
    // 注册 pprof handlers
    mux.HandleFunc("/debug/pprof/", http.DefaultServeMux.ServeHTTP)
    
    // 自定义端点
    mux.HandleFunc("/debug/pprof/cmdline", pprof.Cmdline)
    mux.HandleFunc("/debug/pprof/profile", pprof.Profile)
    mux.HandleFunc("/debug/pprof/symbol", pprof.Symbol)
    mux.HandleFunc("/debug/pprof/trace", pprof.Trace)
    
    // 添加健康检查
    mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        fmt.Fprintln(w, "ok")
    })
    
    // 添加 runtime 统计
    mux.HandleFunc("/debug/stats", func(w http.ResponseWriter, r *http.Request) {
        var m runtime.MemStats
        runtime.ReadMemStats(&m)
        
        fmt.Fprintf(w, "Alloc = %v MiB\n", bToMb(m.Alloc))
        fmt.Fprintf(w, "TotalAlloc = %v MiB\n", bToMb(m.TotalAlloc))
        fmt.Fprintf(w, "Sys = %v MiB\n", bToMb(m.Sys))
        fmt.Fprintf(w, "NumGC = %v\n", m.NumGC)
        fmt.Fprintf(w, "Goroutines = %v\n", runtime.NumGoroutine())
    })
    
    p.server = &http.Server{
        Addr:    fmt.Sprintf(":%d", p.config.HTTPPort),
        Handler: mux,
    }
    
    if err := p.server.ListenAndServe(); err != http.ErrServerClosed {
        log.Printf("HTTP server error: %v", err)
    }
}

func (p *Profiler) continuousCPUProfile() {
    defer p.wg.Done()
    
    ticker := time.NewTicker(p.config.CPUProfileDuration)
    defer ticker.Stop()
    
    counter := 0
    for {
        select {
        case <-p.ctx.Done():
            return
        case <-ticker.C:
            filename := fmt.Sprintf("%s_%d.prof", p.config.CPUProfilePath, counter)
            p.captureCPUProfile(filename, p.config.CPUProfileDuration)
            counter++
        }
    }
}

func (p *Profiler) captureCPUProfile(filename string, duration time.Duration) error {
    f, err := os.Create(filename)
    if err != nil {
        return fmt.Errorf("could not create CPU profile: %v", err)
    }
    defer f.Close()
    
    if err := pprof.StartCPUProfile(f); err != nil {
        return fmt.Errorf("could not start CPU profile: %v", err)
    }
    
    time.Sleep(duration)
    pprof.StopCPUProfile()
    
    log.Printf("CPU profile saved to %s", filename)
    return nil
}

func (p *Profiler) periodicMemProfile() {
    defer p.wg.Done()
    
    ticker := time.NewTicker(p.config.MemProfileInterval)
    defer ticker.Stop()
    
    counter := 0
    for {
        select {
        case <-p.ctx.Done():
            return
        case <-ticker.C:
            filename := fmt.Sprintf("%s_%d.prof", p.config.MemProfilePath, counter)
            p.captureMemProfile(filename)
            counter++
        }
    }
}

func (p *Profiler) captureMemProfile(filename string) error {
    f, err := os.Create(filename)
    if err != nil {
        return fmt.Errorf("could not create memory profile: %v", err)
    }
    defer f.Close()
    
    runtime.GC()
    if err := pprof.WriteHeapProfile(f); err != nil {
        return fmt.Errorf("could not write memory profile: %v", err)
    }
    
    log.Printf("Memory profile saved to %s", filename)
    return nil
}

func bToMb(b uint64) uint64 {
    return b / 1024 / 1024
}

// CaptureOnSignal 在收到信号时捕获 profile
func (p *Profiler) CaptureOnSignal() {
    sigCh := make(chan os.Signal, 1)
    signal.Notify(sigCh, syscall.SIGUSR1, syscall.SIGUSR2)
    
    go func() {
        for sig := range sigCh {
            switch sig {
            case syscall.SIGUSR1:
                // SIGUSR1: 捕获 CPU profile
                filename := fmt.Sprintf("%s_signal_%d.prof", p.config.CPUProfilePath, time.Now().Unix())
                go p.captureCPUProfile(filename, 30*time.Second)
                log.Printf("SIGUSR1 received, capturing CPU profile to %s", filename)
                
            case syscall.SIGUSR2:
                // SIGUSR2: 捕获内存 profile
                filename := fmt.Sprintf("%s_signal_%d.prof", p.config.MemProfilePath, time.Now().Unix())
                go p.captureMemProfile(filename)
                log.Printf("SIGUSR2 received, capturing memory profile to %s", filename)
            }
        }
    }()
}
```

### 2. pprof 分析命令大全

```bash
# ==================== 基础采集 ====================

# CPU Profile (30秒)
go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30

# 内存 Profile - 当前分配
go tool pprof http://localhost:6060/debug/pprof/heap

# 内存 Profile - 全部分配历史
go tool pprof http://localhost:6060/debug/pprof/allocs

# Goroutine Profile
go tool pprof http://localhost:6060/debug/pprof/goroutine

# 阻塞 Profile
go tool pprof http://localhost:6060/debug/pprof/block

# 互斥锁 Profile
go tool pprof http://localhost:6060/debug/pprof/mutex

# Trace (用于 go tool trace)
curl -o trace.out http://localhost:6060/debug/pprof/trace?seconds=5
go tool trace trace.out

# ==================== 交互模式命令 ====================

# 进入交互模式
go tool pprof cpu.prof

# 常用命令
(pprof) top              # 显示 top 函数
(pprof) top10            # 显示 top 10
(pprof) top -cum         # 按累计时间排序
(pprof) list funcName    # 显示函数源码
(pprof) disasm funcName  # 显示汇编
(pprof) web              # 生成 SVG 并在浏览器打开
(pprof) weblist funcName # 在浏览器中显示带注解的源码
(pprof) png > output.png # 导出 PNG
(pprof) pdf > output.pdf # 导出 PDF
(pprof) traces           # 显示调用栈
(pprof) tree             # 树状显示调用关系

# ==================== 过滤与聚焦 ====================

# 聚焦特定函数
(pprof) focus=funcName
(pprof) top

# 忽略特定函数
(pprof) ignore=runtime.*
(pprof) top

# 显示特定路径的函数
(pprof) show=mypackage
(pprof) top

# 隐藏特定路径
(pprof) hide=vendor
(pprof) top

# ==================== 对比分析 ====================

# 对比两个 Profile
go tool pprof -base=cpu_before.prof cpu_after.prof

# 进入对比模式后
(pprof) top -diff_base  # 显示差异

# ==================== 直接命令行分析 ====================

# 直接输出 top
go tool pprof -top cpu.prof

# 输出特定函数的调用图
go tool pprof -png -focus=myFunc cpu.prof > output.png

# 文本格式输出
go tool pprof -text cpu.prof

# 输出 Callgrind 格式 (用于 KCachegrind)
go tool pprof -callgrind cpu.prof > callgrind.out

# ==================== 远程分析 ====================

# 分析远程服务
go tool pprof https://example.com/debug/pprof/profile

# 带认证
go tool pprof -http_user user -http_password pass \
    https://example.com/debug/pprof/profile

# 通过 kubectl port-forward
kubectl port-forward pod/myapp-xxx 6060:6060
go tool pprof http://localhost:6060/debug/pprof/profile

# ==================== Web UI 模式 ====================

# 启动 Web UI
go tool pprof -http=:8080 cpu.prof

# Web UI 功能:
# - 火焰图 (Flame Graph)
# - 调用图 (Graph)
# - Top 函数列表
# - 源码视图
# - Peek (调用者/被调用者分析)
```

### 3. 常见性能问题诊断

```go
// examples/performance_issues.go

package main

import (
    "context"
    "fmt"
    "runtime"
    "sync"
    "time"
)

// 问题1: 内存泄漏 - goroutine 泄漏
func leakyGoroutine() {
    // 错误示例: goroutine 永远不会退出
    for i := 0; i < 1000; i++ {
        go func() {
            ch := make(chan struct{})
            <-ch // 永远阻塞
        }()
    }
}

// 修复: 使用 context 控制 goroutine 生命周期
func fixedGoroutine(ctx context.Context) {
    for i := 0; i < 1000; i++ {
        go func() {
            select {
            case <-ctx.Done():
                return
            }
        }()
    }
}

// 问题2: 内存分配热点
func allocHotspot() {
    // 错误示例: 循环中频繁分配
    for i := 0; i < 10000; i++ {
        data := make([]byte, 1024) // 每次迭代都分配
        _ = data
    }
}

// 修复: 复用内存
func fixedAlloc() {
    data := make([]byte, 1024)
    for i := 0; i < 10000; i++ {
        // 复用 data
        for j := range data {
            data[j] = 0
        }
    }
}

// 或使用 sync.Pool
var bufferPool = sync.Pool{
    New: func() interface{} {
        return make([]byte, 1024)
    },
}

func pooledAlloc() {
    for i := 0; i < 10000; i++ {
        data := bufferPool.Get().([]byte)
        // 使用 data
        bufferPool.Put(data)
    }
}

// 问题3: 锁竞争
type Counter struct {
    mu    sync.Mutex
    count int
}

func (c *Counter) Increment() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}

// 修复: 使用原子操作或分片锁
import "sync/atomic"

type AtomicCounter struct {
    count int64
}

func (c *AtomicCounter) Increment() {
    atomic.AddInt64(&c.count, 1)
}

// 分片锁
type ShardedCounter struct {
    shards [256]struct {
        sync.Mutex
        count int
    }
}

func (c *ShardedCounter) Increment() {
    // 根据 goroutine ID 选择分片
    shard := &c.shards[runtime.GOMAXPROCS(0)%256]
    shard.Lock()
    shard.count++
    shard.Unlock()
}

// 问题4: 字符串拼接
func stringConcat() {
    // 错误示例: 循环中使用 + 拼接
    s := ""
    for i := 0; i < 10000; i++ {
        s += fmt.Sprintf("item-%d,", i)
    }
}

// 修复: 使用 strings.Builder
import "strings"

func fixedStringConcat() {
    var builder strings.Builder
    for i := 0; i < 10000; i++ {
        builder.WriteString(fmt.Sprintf("item-%d,", i))
    }
    _ = builder.String()
}

// 问题5: 不必要的内存逃逸
func escape() *int {
    x := 42
    return &x // x 逃逸到堆
}

// 修复: 尽量在栈上分配
func noEscape() int {
    x := 42
    return x
}

// 检查逃逸分析
// go build -gcflags="-m" main.go
```

## 性能监控与告警集成

### 1. Prometheus 性能指标采集

```yaml
# prometheus-perf-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: performance-alerts
  namespace: monitoring
spec:
  groups:
    - name: application-performance
      interval: 30s
      rules:
        # CPU 使用率过高
        - alert: HighCPUUsage
          expr: |
            sum(rate(container_cpu_usage_seconds_total{namespace="production"}[5m])) by (pod)
            / 
            sum(kube_pod_container_resource_limits{resource="cpu", namespace="production"}) by (pod)
            > 0.9
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Pod {{ $labels.pod }} CPU 使用率超过 90%"
            description: "建议: 1) 检查 pprof CPU profile 2) 考虑水平扩容"
            runbook_url: "https://wiki.example.com/runbooks/high-cpu"
        
        # 内存使用率过高
        - alert: HighMemoryUsage
          expr: |
            sum(container_memory_working_set_bytes{namespace="production"}) by (pod)
            /
            sum(kube_pod_container_resource_limits{resource="memory", namespace="production"}) by (pod)
            > 0.85
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Pod {{ $labels.pod }} 内存使用率超过 85%"
            description: "建议: 1) 检查 pprof heap profile 2) 检查是否存在内存泄漏"
        
        # Goroutine 数量异常
        - alert: HighGoroutineCount
          expr: |
            go_goroutines{job="my-app"} > 10000
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "应用 {{ $labels.instance }} goroutine 数量异常"
            description: "当前 goroutine 数: {{ $value }}，可能存在 goroutine 泄漏"
        
        # GC 暂停时间过长
        - alert: LongGCPause
          expr: |
            increase(go_gc_duration_seconds_sum[5m]) / increase(go_gc_duration_seconds_count[5m]) > 0.1
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "应用 {{ $labels.instance }} GC 暂停时间过长"
            description: "平均 GC 暂停时间: {{ $value | printf \"%.3f\" }}s"
        
        # 堆内存增长过快
        - alert: RapidHeapGrowth
          expr: |
            deriv(go_memstats_heap_alloc_bytes[10m]) > 100 * 1024 * 1024
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "应用 {{ $labels.instance }} 堆内存增长过快"
            description: "堆内存增长速率: {{ $value | humanize }}B/s"
        
        # P99 延迟过高
        - alert: HighP99Latency
          expr: |
            histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))
            > 2
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "服务 {{ $labels.service }} P99 延迟超过 2s"
            description: "当前 P99 延迟: {{ $value | printf \"%.2f\" }}s"

    - name: kubernetes-performance
      rules:
        # API Server 延迟
        - alert: APIServerHighLatency
          expr: |
            histogram_quantile(0.99, sum(rate(apiserver_request_duration_seconds_bucket{verb!="WATCH"}[5m])) by (le, verb, resource))
            > 1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "API Server {{ $labels.verb }} {{ $labels.resource }} P99 延迟过高"
            description: "P99 延迟: {{ $value | printf \"%.2f\" }}s"
        
        # etcd 延迟
        - alert: EtcdHighLatency
          expr: |
            histogram_quantile(0.99, sum(rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m])) by (le, instance))
            > 0.1
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "etcd {{ $labels.instance }} WAL fsync 延迟过高"
            description: "P99 延迟: {{ $value | printf \"%.3f\" }}s"
        
        # 调度器延迟
        - alert: SchedulerHighLatency
          expr: |
            histogram_quantile(0.99, sum(rate(scheduler_scheduling_duration_seconds_bucket[5m])) by (le))
            > 0.5
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Scheduler 调度延迟过高"
            description: "P99 调度延迟: {{ $value | printf \"%.2f\" }}s"
```

### 2. Grafana Dashboard 配置

```json
{
  "dashboard": {
    "title": "Application Performance Dashboard",
    "uid": "app-perf",
    "panels": [
      {
        "title": "CPU Profile Summary",
        "type": "timeseries",
        "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8},
        "targets": [
          {
            "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"production\"}[5m])) by (pod)",
            "legendFormat": "{{ pod }}"
          }
        ]
      },
      {
        "title": "Memory Profile Summary",
        "type": "timeseries",
        "gridPos": {"x": 12, "y": 0, "w": 12, "h": 8},
        "targets": [
          {
            "expr": "sum(go_memstats_heap_alloc_bytes{namespace=\"production\"}) by (pod)",
            "legendFormat": "{{ pod }} - Heap"
          },
          {
            "expr": "sum(go_memstats_heap_inuse_bytes{namespace=\"production\"}) by (pod)",
            "legendFormat": "{{ pod }} - In Use"
          }
        ]
      },
      {
        "title": "Goroutine Count",
        "type": "stat",
        "gridPos": {"x": 0, "y": 8, "w": 6, "h": 4},
        "targets": [
          {
            "expr": "sum(go_goroutines{namespace=\"production\"}) by (pod)"
          }
        ]
      },
      {
        "title": "GC Pause Duration",
        "type": "heatmap",
        "gridPos": {"x": 6, "y": 8, "w": 18, "h": 8},
        "targets": [
          {
            "expr": "sum(rate(go_gc_duration_seconds_bucket[1m])) by (le)"
          }
        ]
      },
      {
        "title": "Pyroscope Flame Graph",
        "type": "flamegraph",
        "gridPos": {"x": 0, "y": 16, "w": 24, "h": 12},
        "datasource": "Pyroscope",
        "targets": [
          {
            "profileTypeId": "process_cpu:cpu:nanoseconds:cpu:nanoseconds",
            "query": "{service_name=\"my-app\"}"
          }
        ]
      }
    ]
  }
}
```

## 性能调优速查表

### CPU 性能问题诊断

| 症状 | 诊断命令 | 可能原因 | 解决方案 |
|------|----------|----------|----------|
| CPU 100% | `kubectl gadget top ebpf` | 计算密集 | 优化算法/并行化 |
| 高系统态 | `kubectl gadget trace syscall` | 频繁系统调用 | 减少 IO/批量操作 |
| 锁竞争 | `go tool pprof mutex` | 互斥锁过热 | 分片锁/无锁结构 |
| 调度延迟 | `perf sched` | CPU 不足 | 增加 CPU 限制 |

### 内存性能问题诊断

| 症状 | 诊断命令 | 可能原因 | 解决方案 |
|------|----------|----------|----------|
| OOM | `kubectl gadget trace oomkill` | 内存泄漏/限制过低 | 检查泄漏/增加限制 |
| 频繁 GC | `go tool pprof heap` | 分配过多临时对象 | 对象池/预分配 |
| GC 暂停长 | `GODEBUG=gctrace=1` | 堆过大 | 减少堆大小/GOGC |
| 内存增长 | `go tool pprof -diff_base` | 内存泄漏 | 对比分析定位 |

### 网络性能问题诊断

| 症状 | 诊断命令 | 可能原因 | 解决方案 |
|------|----------|----------|----------|
| 高延迟 | `kubectl gadget trace tcpconnect --latency` | 网络拥塞/DNS 慢 | 优化 MTU/本地 DNS |
| 连接超时 | `kubectl gadget trace tcpstate` | 连接池耗尽 | 增加连接池/复用连接 |
| 重传多 | `kubectl gadget trace tcpretrans` | 网络丢包 | 检查 CNI/节点网络 |
| 带宽瓶颈 | `kubectl gadget top tcp` | 网络饱和 | 升级网络/流量整形 |

### I/O 性能问题诊断

| 症状 | 诊断命令 | 可能原因 | 解决方案 |
|------|----------|----------|----------|
| 读写慢 | `kubectl gadget trace fsslower` | 磁盘 IOPS 不足 | 使用 SSD/优化 I/O 模式 |
| 文件 FD 耗尽 | `kubectl gadget trace open` | 文件泄漏 | 检查未关闭文件 |
| 高 I/O 等待 | `kubectl gadget top block-io` | I/O 密集 | 异步 I/O/缓存 |

## 最佳实践清单

### 性能分析最佳实践

- [ ] **建立性能基线**: 在生产环境稳定后记录基准指标
- [ ] **持续 Profiling**: 部署 Pyroscope 进行 7x24 小时持续采集
- [ ] **定期压测**: 使用 Kperf 定期进行 API Server 压力测试
- [ ] **版本对比**: 每次发布前后对比性能 Profile
- [ ] **告警阈值**: 基于 P99 延迟设置告警，而非平均值
- [ ] **采样控制**: 生产环境采样率控制在 1-5%

### 性能优化原则

- [ ] **先测量后优化**: 用数据驱动优化决策
- [ ] **关注热点**: 优化火焰图中最宽的 "plateau"
- [ ] **避免过早优化**: 只优化真正的瓶颈
- [ ] **渐进式优化**: 每次只改一个变量
- [ ] **回归测试**: 优化后验证没有引入新问题

### eBPF 分析注意事项

- [ ] **内核版本**: 确保内核 >= 4.15 以获得完整 eBPF 支持
- [ ] **权限配置**: 正确配置 securityContext 和 capabilities
- [ ] **资源限制**: 为 eBPF agent 设置合理的资源限制
- [ ] **过滤优化**: 使用命名空间/标签过滤减少数据量
- [ ] **安全审计**: 定期审计 eBPF 程序权限

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)
