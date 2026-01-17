# 表格5：kubectl命令表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/reference/kubectl](https://kubernetes.io/docs/reference/kubectl/)

## kubectl命令结构

```
kubectl命令结构:
┌─────────────────────────────────────────────────────────────────────────────┐
│  kubectl [command] [TYPE] [NAME] [flags]                                    │
│                                                                             │
│  command: 操作类型 (get, describe, create, apply, delete, edit...)          │
│  TYPE:    资源类型 (pod, deployment, service, node...)                      │
│  NAME:    资源名称 (可选，不指定则操作所有)                                   │
│  flags:   选项标志 (-n namespace, -o output, -l labels...)                  │
│                                                                             │
│  示例:                                                                      │
│  kubectl get pods nginx -n production -o yaml                               │
│          │    │    │        │            │                                  │
│          │    │    │        │            └── 输出格式                        │
│          │    │    │        └── 命名空间                                     │
│          │    │    └── 资源名称                                              │
│          │    └── 资源类型                                                   │
│          └── 命令                                                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 资源查看命令

| 命令 | 语法 | 描述 | 常用选项/标志 | 版本支持/变更 | 生产场景示例 |
|-----|------|------|-------------|--------------|-------------|
| **get** | `kubectl get <resource> [name]` | 列出资源 | `-o wide/yaml/json`, `-l`, `-A`, `--show-labels` | 稳定; v1.27+增强输出 | `kubectl get pods -A -o wide` 查看所有Pod分布 |
| **describe** | `kubectl describe <resource> <name>` | 显示详细信息 | `--show-events` | 稳定 | `kubectl describe pod <name>` 排查Pod问题 |
| **logs** | `kubectl logs <pod> [-c container]` | 查看容器日志 | `-f`, `--tail`, `--since`, `-p`, `--all-containers` | v1.27+流日志优化 | `kubectl logs -f <pod> --tail=100` 实时跟踪 |
| **top** | `kubectl top nodes/pods` | 显示资源使用 | `--containers`, `--sort-by` | 需Metrics Server | `kubectl top pods -A --sort-by=cpu` 找高CPU |
| **events** | `kubectl events` | 查看事件 | `--for`, `--types`, `-A`, `--watch` | v1.26+独立命令 | `kubectl events --for pod/<name>` 查看Pod事件 |
| **api-resources** | `kubectl api-resources` | 列出API资源 | `-o wide`, `--namespaced`, `--api-group` | 稳定 | 检查集群支持的资源类型 |
| **api-versions** | `kubectl api-versions` | 列出API版本 | - | 稳定 | 升级前检查API版本支持 |
| **cluster-info** | `kubectl cluster-info [dump]` | 集群信息 | `dump` 导出诊断 | 稳定 | `kubectl cluster-info dump` 收集诊断信息 |
| **explain** | `kubectl explain <resource>` | 资源字段说明 | `--recursive`, `--api-version` | 稳定 | `kubectl explain pod.spec.containers` 查看字段含义 |

### get命令高级用法

```bash
# 基础查询
kubectl get pods                           # 当前命名空间Pod
kubectl get pods -A                        # 所有命名空间
kubectl get pods -n kube-system            # 指定命名空间
kubectl get pods --all-namespaces -o wide  # 宽输出显示节点

# 标签过滤
kubectl get pods -l app=nginx              # 单标签
kubectl get pods -l 'app in (nginx,redis)' # 标签集合
kubectl get pods -l app=nginx,env=prod     # 多标签AND
kubectl get pods -l '!app'                 # 没有app标签
kubectl get pods -l 'app!=nginx'           # app不等于nginx

# 字段选择器
kubectl get pods --field-selector=status.phase=Running
kubectl get pods --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl get pods --field-selector=spec.nodeName=node01
kubectl get events --field-selector=type=Warning

# 输出格式
kubectl get pods -o yaml                   # YAML格式
kubectl get pods -o json                   # JSON格式
kubectl get pods -o name                   # 仅输出名称
kubectl get pods -o wide                   # 宽格式(含IP和节点)
kubectl get pods -o jsonpath='{.items[*].metadata.name}'  # JSONPath

# 自定义列输出
kubectl get pods -o custom-columns=\
'NAME:.metadata.name,'\
'STATUS:.status.phase,'\
'IP:.status.podIP,'\
'NODE:.spec.nodeName,'\
'RESTARTS:.status.containerStatuses[0].restartCount'

# 排序
kubectl get pods --sort-by='.status.startTime'
kubectl get pods --sort-by='.metadata.creationTimestamp'
kubectl get events --sort-by='.lastTimestamp'

# 监控变化
kubectl get pods -w                        # watch模式
kubectl get pods -w --output-watch-events  # 显示事件类型(v1.27+)
```

## 资源创建与管理命令

| 命令 | 语法 | 描述 | 常用选项/标志 | 版本支持/变更 | 生产场景示例 |
|-----|------|------|-------------|--------------|-------------|
| **apply** | `kubectl apply -f <file/dir/url>` | 声明式应用配置 | `-R`, `--prune`, `--server-side` | v1.22+ Server-side Apply GA | `kubectl apply -f manifests/ -R` 部署应用 |
| **create** | `kubectl create <resource>` | 命令式创建资源 | `--dry-run=client/server`, `-o yaml` | 稳定 | `kubectl create ns <name>` 创建命名空间 |
| **delete** | `kubectl delete <resource> <name>` | 删除资源 | `--force`, `--grace-period`, `--cascade` | v1.27+ foreground级联 | `kubectl delete pod <name> --force` 强制删除 |
| **edit** | `kubectl edit <resource> <name>` | 编辑资源 | `--save-config` | 稳定 | 临时修改配置(不推荐生产使用) |
| **replace** | `kubectl replace -f <file>` | 替换资源 | `--force` | 稳定 | 完全替换资源配置 |
| **patch** | `kubectl patch <resource> <name>` | 部分更新资源 | `--type=merge/strategic/json` | 稳定 | 更新单个字段 |
| **label** | `kubectl label <resource> <name>` | 添加/更新标签 | `--overwrite`, `-l`, `--all` | 稳定 | `kubectl label nodes <name> env=prod` |
| **annotate** | `kubectl annotate <resource> <name>` | 添加/更新注解 | `--overwrite` | 稳定 | 添加运维元数据 |
| **scale** | `kubectl scale <resource> <name>` | 调整副本数 | `--replicas`, `--current-replicas` | 稳定 | `kubectl scale deploy <name> --replicas=5` |

### apply与create对比

| 特性 | apply | create |
|-----|-------|--------|
| 模式 | 声明式 | 命令式 |
| 资源存在时 | 更新 | 报错 |
| 配置来源 | 必须有manifest文件 | 可用参数创建 |
| 历史追踪 | 保留last-applied-configuration | 无 |
| 生产推荐 | **推荐** | 仅临时使用 |
| 三方合并 | 支持 | 不支持 |

### patch命令详解

```bash
# Strategic Merge Patch (默认，智能合并)
kubectl patch deployment nginx -p '{"spec":{"replicas":3}}'

# JSON Merge Patch (完全替换指定字段)
kubectl patch deployment nginx --type=merge -p '{"spec":{"replicas":3}}'

# JSON Patch (精确操作)
kubectl patch deployment nginx --type=json -p='[
  {"op": "replace", "path": "/spec/replicas", "value": 3},
  {"op": "add", "path": "/metadata/labels/version", "value": "v2"}
]'

# 常用patch场景
# 更新镜像
kubectl patch deployment nginx -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","image":"nginx:1.25"}]}}}}'

# 添加环境变量
kubectl patch deployment nginx --type=json -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/env/-", 
   "value": {"name": "DEBUG", "value": "true"}}
]'

# 添加容忍度
kubectl patch deployment nginx -p '{"spec":{"template":{"spec":{"tolerations":[{"key":"dedicated","operator":"Equal","value":"special","effect":"NoSchedule"}]}}}}'

# 更新资源限制
kubectl patch deployment nginx --type=json -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "512Mi"}
]'
```

## 部署管理命令

| 命令 | 语法 | 描述 | 常用选项/标志 | 版本支持/变更 | 生产场景示例 |
|-----|------|------|-------------|--------------|-------------|
| **rollout status** | `kubectl rollout status <resource>` | 查看部署状态 | `--watch`, `--timeout` | 稳定 | CI/CD中等待部署完成 |
| **rollout history** | `kubectl rollout history <resource>` | 查看部署历史 | `--revision` | 稳定 | 查看历史版本信息 |
| **rollout undo** | `kubectl rollout undo <resource>` | 回滚部署 | `--to-revision` | 稳定 | `kubectl rollout undo deploy/<name>` 紧急回滚 |
| **rollout restart** | `kubectl rollout restart <resource>` | 重启部署 | - | v1.15+ | 滚动重启所有Pod |
| **rollout pause** | `kubectl rollout pause <resource>` | 暂停部署 | - | 稳定 | 暂停滚动更新进行检查 |
| **rollout resume** | `kubectl rollout resume <resource>` | 恢复部署 | - | 稳定 | 检查通过后继续更新 |
| **set image** | `kubectl set image <resource>` | 更新镜像 | `--record`(已弃用) | 稳定 | `kubectl set image deploy/<name> app=image:v2` |
| **set resources** | `kubectl set resources <resource>` | 设置资源限制 | `--requests`, `--limits` | 稳定 | 调整资源配额 |
| **set env** | `kubectl set env <resource>` | 设置环境变量 | `--from`, `--overwrite` | 稳定 | 更新配置 |
| **autoscale** | `kubectl autoscale <resource>` | 创建HPA | `--min`, `--max`, `--cpu-percent` | 稳定 | 配置自动扩缩容 |

### 滚动更新与回滚流程

```bash
# 1. 更新前检查
kubectl get deployment nginx -o yaml | grep image
kubectl rollout history deployment/nginx

# 2. 执行更新
kubectl set image deployment/nginx nginx=nginx:1.25
# 或使用apply
kubectl apply -f deployment.yaml

# 3. 监控更新状态
kubectl rollout status deployment/nginx --timeout=5m
kubectl get pods -l app=nginx -w

# 4. 如果有问题，立即回滚
kubectl rollout undo deployment/nginx
# 或回滚到指定版本
kubectl rollout history deployment/nginx
kubectl rollout undo deployment/nginx --to-revision=2

# 5. 金丝雀发布流程
kubectl rollout pause deployment/nginx
kubectl set image deployment/nginx nginx=nginx:1.25
# 观察部分更新的Pod
kubectl get pods -l app=nginx -o wide
# 确认无问题后继续
kubectl rollout resume deployment/nginx
```

## 调试与排查命令

| 命令 | 语法 | 描述 | 常用选项/标志 | 版本支持/变更 | 生产场景示例 |
|-----|------|------|-------------|--------------|-------------|
| **exec** | `kubectl exec <pod> -- <cmd>` | 在容器中执行命令 | `-it`, `-c` | 稳定 | `kubectl exec -it <pod> -- /bin/sh` 进入容器 |
| **debug** | `kubectl debug <pod/node>` | 创建调试容器 | `--image`, `--target`, `--copy-to`, `--profile` | v1.25+ GA | 调试distroless镜像 |
| **port-forward** | `kubectl port-forward <pod> <ports>` | 端口转发 | `--address` | 稳定 | 本地访问服务 |
| **cp** | `kubectl cp <src> <dest>` | 复制文件 | `-c` | 稳定 | 从容器拷贝日志文件 |
| **attach** | `kubectl attach <pod> -c <container>` | 附加到运行容器 | `-it` | 稳定 | 附加到stdin |
| **run** | `kubectl run <name> --image=<image>` | 运行临时Pod | `--rm`, `-it`, `--restart=Never` | 稳定 | 临时调试Pod |
| **proxy** | `kubectl proxy` | 运行API代理 | `--port` | 稳定 | 本地访问Dashboard |
| **auth can-i** | `kubectl auth can-i <verb> <resource>` | 检查权限 | `--as`, `--list`, `-A` | 稳定 | 权限验证 |
| **auth whoami** | `kubectl auth whoami` | 显示当前身份 | - | v1.27+ | 确认当前认证身份 |

### kubectl debug详解 (v1.25+ GA)

```bash
# 调试运行中的Pod (共享进程命名空间)
kubectl debug -it <pod> --image=busybox --target=<container>

# 调试时复制Pod (不影响原Pod)
kubectl debug <pod> -it --copy-to=<pod>-debug --share-processes

# 使用预定义调试配置文件
kubectl debug -it <pod> --image=busybox --profile=general
kubectl debug -it <pod> --image=busybox --profile=baseline  # 受限权限
kubectl debug -it <pod> --image=busybox --profile=restricted

# 调试节点 (创建特权Pod访问节点)
kubectl debug node/<node-name> -it --image=ubuntu
# 进入后可访问节点文件系统
# chroot /host

# 使用netshoot镜像调试网络
kubectl debug -it <pod> --image=nicolaka/netshoot --target=<container>
# 常用网络调试命令
# tcpdump, netstat, ss, ip, curl, dig, nslookup, traceroute

# 调试CrashLoopBackOff的Pod
kubectl debug <pod> -it --copy-to=<pod>-debug --container=<container> -- sh
# 或覆盖启动命令
kubectl run debug-pod --image=<same-image> --restart=Never -it --rm -- sh
```

### 生产调试最佳实践

```bash
# 1. 网络连通性测试
kubectl run nettest --rm -it --image=busybox --restart=Never -- sh
# 在容器内执行
# wget -qO- http://service-name.namespace.svc.cluster.local
# nslookup kubernetes.default

# 2. DNS解析测试
kubectl run dnstest --rm -it --image=busybox:1.28 --restart=Never -- nslookup kubernetes.default

# 3. 检查服务端点
kubectl get endpoints <service-name>
kubectl get endpointslices -l kubernetes.io/service-name=<service-name>

# 4. 容器内进程和网络检查
kubectl exec -it <pod> -- ps aux
kubectl exec -it <pod> -- netstat -tlnp
kubectl exec -it <pod> -- cat /etc/resolv.conf

# 5. 检查挂载的卷
kubectl exec -it <pod> -- df -h
kubectl exec -it <pod> -- ls -la /mounted-volume

# 6. 环境变量检查
kubectl exec -it <pod> -- env | sort

# 7. 查看容器启动命令
kubectl get pod <pod> -o jsonpath='{.spec.containers[0].command}'
kubectl get pod <pod> -o jsonpath='{.spec.containers[0].args}'
```

## 配置管理命令

| 命令 | 语法 | 描述 | 常用选项/标志 | 版本支持/变更 | 生产场景示例 |
|-----|------|------|-------------|--------------|-------------|
| **config view** | `kubectl config view` | 查看kubeconfig | `--minify`, `--raw` | 稳定 | 查看当前配置 |
| **config get-contexts** | `kubectl config get-contexts` | 列出上下文 | - | 稳定 | 查看可用集群 |
| **config use-context** | `kubectl config use-context <name>` | 切换上下文 | - | 稳定 | 切换到生产集群 |
| **config set-context** | `kubectl config set-context <name>` | 设置上下文 | `--namespace`, `--cluster`, `--user` | 稳定 | 设置默认命名空间 |
| **config current-context** | `kubectl config current-context` | 显示当前上下文 | - | 稳定 | 确认当前操作集群 |
| **config set-credentials** | `kubectl config set-credentials` | 设置用户凭证 | `--token`, `--client-certificate` | 稳定 | 配置新用户 |
| **config set-cluster** | `kubectl config set-cluster <name>` | 设置集群 | `--server`, `--certificate-authority` | 稳定 | 添加新集群 |
| **config delete-context** | `kubectl config delete-context <name>` | 删除上下文 | - | 稳定 | 清理无用配置 |
| **config rename-context** | `kubectl config rename-context <old> <new>` | 重命名上下文 | - | 稳定 | 规范命名 |

### 多集群管理配置

```bash
# 查看所有配置
kubectl config view

# 合并多个kubeconfig
export KUBECONFIG=~/.kube/config:~/.kube/cluster2-config
kubectl config view --flatten > ~/.kube/merged-config

# 为不同集群设置别名
kubectl config set-context prod --cluster=production-cluster --user=admin --namespace=production
kubectl config set-context staging --cluster=staging-cluster --user=admin --namespace=staging

# 快速切换命名空间 (设置当前context的默认ns)
kubectl config set-context --current --namespace=production

# 在不切换context的情况下操作其他集群
kubectl --context=staging get pods
kubectl --context=prod apply -f deployment.yaml

# 使用kubectx/kubens工具 (推荐安装)
# brew install kubectx
kubectx                    # 列出所有context
kubectx prod              # 切换到prod
kubectx -                 # 切换到上一个context
kubens                    # 列出所有namespace
kubens production         # 切换到production namespace
```

## 高级查询与过滤

| 用法 | 语法示例 | 描述 | 适用场景 |
|-----|---------|------|---------|
| **标签选择** | `kubectl get pods -l app=nginx,env=prod` | 按标签过滤 | 筛选特定应用Pod |
| **字段选择** | `kubectl get pods --field-selector=status.phase=Running` | 按字段过滤 | 筛选运行中Pod |
| **JSONPath** | `kubectl get pods -o jsonpath='{.items[*].metadata.name}'` | JSON路径查询 | 提取特定字段 |
| **自定义列** | `kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase` | 自定义输出列 | 自定义输出格式 |
| **排序** | `kubectl get pods --sort-by='.status.startTime'` | 排序输出 | 按启动时间排序 |
| **Go模板** | `kubectl get pods -o go-template='{{range .items}}{{.metadata.name}}{{end}}'` | Go模板格式化 | 复杂格式化需求 |

### JSONPath高级用法

```bash
# 基础语法
kubectl get pods -o jsonpath='{.items[0].metadata.name}'

# 遍历数组
kubectl get pods -o jsonpath='{.items[*].metadata.name}'

# 带换行的输出
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'

# 条件过滤
kubectl get pods -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}'

# 获取节点IP
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'

# 获取所有镜像
kubectl get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u

# 获取Pod的CPU和内存限制
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources.limits.cpu}{"\t"}{.spec.containers[*].resources.limits.memory}{"\n"}{end}'

# 复杂表格输出
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.status.podIP}{"\n"}{end}'
```

### Go Template高级用法

```bash
# 基础语法
kubectl get pods -o go-template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'

# 条件判断
kubectl get pods -o go-template='{{range .items}}{{if eq .status.phase "Running"}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}'

# 获取容器状态
kubectl get pods -o go-template='{{range .items}}{{.metadata.name}}:{{range .status.containerStatuses}}{{.ready}}{{end}}{{"\n"}}{{end}}'

# 带格式的表格
kubectl get pods -o go-template='
{{- range .items -}}
  {{- printf "%-40s %-12s %-15s\n" .metadata.name .status.phase .status.podIP -}}
{{- end -}}'
```

## 生产环境常用组合命令

### 问题排查命令集

```bash
# 查看所有非Running状态的Pod
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

# 查看所有问题Pod（含Running但不Ready）
kubectl get pods -A -o wide | awk 'NR==1 || !/Running/ || /0\//'

# 查找高重启次数的Pod
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.restartCount}{"\t"}{end}{"\n"}{end}' | awk -F'\t' '$3>5'

# 查找资源使用最高的Pod
kubectl top pods -A --sort-by=cpu | head -20
kubectl top pods -A --sort-by=memory | head -20

# 批量删除Evicted Pod
kubectl get pods -A --field-selector=status.phase=Failed -o json | \
  jq -r '.items[] | select(.status.reason=="Evicted") | "\(.metadata.namespace) \(.metadata.name)"' | \
  xargs -L1 kubectl delete pod -n

# 批量删除Completed Pod
kubectl delete pods -A --field-selector=status.phase=Succeeded

# 查看节点上的Pod分布
kubectl get pods -A -o wide --sort-by='.spec.nodeName' | awk '{print $8}' | sort | uniq -c | sort -rn

# 查看最近创建的Pod
kubectl get pods -A --sort-by='.metadata.creationTimestamp' | tail -20

# 查看最近的事件
kubectl get events -A --sort-by='.lastTimestamp' | tail -50
kubectl get events -A --field-selector=type=Warning --sort-by='.lastTimestamp'
```

### 资源分析命令集

```bash
# 按命名空间统计Pod数量
kubectl get pods -A --no-headers | awk '{print $1}' | sort | uniq -c | sort -rn

# 统计各节点Pod数量
kubectl get pods -A -o wide --no-headers | awk '{print $8}' | sort | uniq -c | sort -rn

# 查看节点资源分配
kubectl describe nodes | grep -A 5 "Allocated resources"

# 导出资源YAML(去除状态信息)
kubectl get deployment <name> -o yaml | kubectl neat > deploy.yaml
# 或使用yq
kubectl get deployment <name> -o yaml | yq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .status)'

# 检查PVC使用情况
kubectl get pvc -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage,ACCESS_MODE:.spec.accessModes[0],STORAGECLASS:.spec.storageClassName'

# 检查资源配额使用
kubectl get resourcequota -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,USED:.status.used,HARD:.status.hard'
```

### 安全检查命令集

```bash
# 检查使用特权模式的Pod
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[].securityContext.privileged==true) | "\(.metadata.namespace)/\(.metadata.name)"'

# 检查以root运行的Pod
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.securityContext.runAsUser==0 or .spec.containers[].securityContext.runAsUser==0) | "\(.metadata.namespace)/\(.metadata.name)"'

# 检查挂载hostPath的Pod
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.volumes[]?.hostPath != null) | "\(.metadata.namespace)/\(.metadata.name)"'

# 检查使用hostNetwork的Pod
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.hostNetwork==true) | "\(.metadata.namespace)/\(.metadata.name)"'

# 检查cluster-admin绑定
kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'

# 列出所有ServiceAccount权限
kubectl auth can-i --list --as=system:serviceaccount:default:default
```

### 批量操作命令集

```bash
# 批量重启所有Deployment
kubectl get deployments -n <namespace> -o name | xargs -I {} kubectl rollout restart {}

# 批量扩缩容
kubectl get deployments -n <namespace> -o name | xargs -I {} kubectl scale {} --replicas=3

# 批量更新镜像tag
kubectl get deployments -A -o json | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | while read ns name; do
  kubectl set image deployment/$name -n $ns '*=*:v2'
done

# 批量添加标签
kubectl get pods -l app=myapp -o name | xargs kubectl label --overwrite env=production

# 批量添加注解
kubectl get deployments -n production -o name | xargs kubectl annotate --overwrite description="production deployment"

# 导出命名空间所有资源
kubectl get all,configmap,secret,ingress,pvc -n <namespace> -o yaml > namespace-backup.yaml

# 监控多个资源
kubectl get pods,svc,deploy -n production -w
```

## 插件与扩展命令

| 命令 | 语法 | 描述 | 常用选项/标志 | 版本支持/变更 | 生产场景示例 |
|-----|------|------|-------------|--------------|-------------|
| **krew** | `kubectl krew install <plugin>` | 插件管理器 | `search`, `list`, `update` | 外部工具 | 安装kubectl插件 |
| **convert** | `kubectl convert -f <file>` | 转换API版本 | `--output-version` | 需安装插件 | 升级时转换旧YAML |
| **diff** | `kubectl diff -f <file>` | 比较差异 | `-R` | v1.18+ GA | 应用前预览变更 |
| **wait** | `kubectl wait <resource>` | 等待条件满足 | `--for=condition=Ready`, `--timeout` | 稳定 | CI/CD中等待资源就绪 |
| **alpha** | `kubectl alpha <subcommand>` | Alpha功能 | 子命令因版本而异 | 实验性 | 测试新功能 |

### 推荐kubectl插件

```bash
# 安装krew
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# 必装插件
kubectl krew install ctx           # 快速切换context
kubectl krew install ns            # 快速切换namespace
kubectl krew install neat          # 清理YAML输出
kubectl krew install tree          # 显示资源依赖树
kubectl krew install images        # 列出所有使用的镜像
kubectl krew install resource-capacity  # 查看资源容量
kubectl krew install node-shell    # 直接shell到节点
kubectl krew install sniff         # 网络抓包
kubectl krew install stern         # 多Pod日志查看
kubectl krew install view-secret   # 查看解码后的secret
kubectl krew install access-matrix # RBAC权限矩阵
kubectl krew install who-can       # 查看谁有特定权限
kubectl krew install cost          # 成本分析(需配合opencost)

# 插件使用示例
kubectl ctx                        # 列出并选择context
kubectl ns                         # 列出并选择namespace
kubectl tree deployment nginx      # 显示deployment的资源树
kubectl images -A                  # 列出所有镜像
kubectl resource-capacity          # 显示节点资源容量
kubectl sniff <pod>               # 对Pod进行tcpdump
kubectl stern -n production app   # 查看所有app开头Pod的日志
kubectl who-can create pods -n default
```

## ACK特定kubectl配置

```bash
# 获取ACK集群kubeconfig
aliyun cs GET /k8s/<cluster-id>/user_config | jq -r '.config' > ~/.kube/ack-config
# 或使用控制台下载

# 合并ACK配置
export KUBECONFIG=~/.kube/config:~/.kube/ack-config
kubectl config view --flatten > ~/.kube/merged

# 使用RAM账号认证 (临时凭证)
kubectl config set-credentials ack-user --exec-api-version=client.authentication.k8s.io/v1beta1 \
  --exec-command=aliyun-cli-credential-helper

# 多ACK集群管理
kubectl config set-context ack-prod --cluster=<prod-cluster> --user=<user> --namespace=production
kubectl config set-context ack-staging --cluster=<staging-cluster> --user=<user> --namespace=staging

# ACK特有操作
# 查看ACK组件状态
kubectl get pods -n kube-system -l 'k8s-app in (terway-eniip,aliyun-acr-credential-helper)'

# 查看ACK网络配置
kubectl get eniconfigs -A
kubectl get pods -n kube-system -l app=terway-eniip -o wide

# ACK日志组件
kubectl get pods -n kube-system -l app=logtail-ds
```

## 效率配置

### Shell配置

```bash
# ~/.bashrc 或 ~/.zshrc

# kubectl补全
source <(kubectl completion bash)  # bash
source <(kubectl completion zsh)   # zsh

# 别名配置
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec -it'
alias ka='kubectl apply -f'
alias kdel='kubectl delete'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deploy'
alias kgn='kubectl get nodes'
alias kga='kubectl get all'
alias kgaa='kubectl get all -A'
alias kctx='kubectl config use-context'
alias kns='kubectl config set-context --current --namespace'

# 带命名空间的别名
alias kgpa='kubectl get pods -A'
alias kgpw='kubectl get pods -o wide'
alias kgpaw='kubectl get pods -A -o wide'

# 快速函数
kexec() { kubectl exec -it $1 -- ${2:-sh}; }
klogs() { kubectl logs -f --tail=100 $1; }
kdebug() { kubectl debug -it $1 --image=busybox --target=${2:-$1}; }

# 提示符显示当前context和namespace (zsh)
# 安装kube-ps1: brew install kube-ps1
source "/opt/homebrew/opt/kube-ps1/share/kube-ps1.sh"
PS1='$(kube_ps1)'$PS1
```

### 常用单行命令速查

```bash
# 查看当前context和namespace
kubectl config current-context && kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}'

# 强制删除卡住的Pod
kubectl delete pod <name> --grace-period=0 --force

# 获取最新的Pod
kubectl get pods --sort-by=.metadata.creationTimestamp -o name | tail -1

# 复制Pod日志到本地
kubectl logs <pod> > pod.log

# 监控特定Pod的资源使用
watch -n 2 "kubectl top pod <pod-name>"

# 端口转发到Service
kubectl port-forward svc/<service-name> 8080:80

# 临时创建测试Pod
kubectl run tmp --rm -it --image=alpine -- sh

# 检查API Server版本
kubectl version --short

# 列出所有资源类型
kubectl api-resources --verbs=list -o name

# 获取节点的全部标签
kubectl get nodes --show-labels
```

---

**效率提示**: 
1. 安装kubectx/kubens快速切换集群和命名空间
2. 使用krew安装常用插件提高效率
3. 配置shell补全和别名
4. 使用stern查看多Pod日志
5. 使用k9s作为终端UI工具: `brew install k9s`

## kubectl apply示例

```yaml
# 使用kubectl apply部署的完整示例
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```
