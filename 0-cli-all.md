# Kubernetes & AI/ML 命令行清单 (Complete CLI Commands Reference)

## 目录
- [1. kubectl 基础命令](#1-kubectl-基础命令)
- [2. 集群管理命令](#2-集群管理命令)
- [3. Pod 调试与交互命令](#3-pod-调试与交互命令)
- [4. 资源创建与管理命令](#4-资源创建与管理命令)
- [5. 集群配置参数](#5-集群配置参数)
- [6. GPU 调度与管理命令](#6-gpu-调度与管理命令)
- [7. AI/ML 工作负载命令](#7-aiml-工作负载命令)
- [8. 故障排查工具命令](#8-故障排查工具命令)
- [9. 安全与认证命令](#9-安全与认证命令)
- [10. 监控与告警命令](#10-监控与告警命令)

---

## 1. kubectl 基础命令

### 1.1 资源查看命令

```bash
# 查看所有 Pod 及其详细信息
kubectl get pods -A -o wide
# 执行方式: 在本地执行，通过API Server查询所有命名空间的Pod信息
# 用途: 检查集群中所有Pod的状态和所在节点
# 原理: 从etcd获取Pod资源定义和状态信息
# 注意事项: -A选项会查询所有命名空间，可能产生大量输出
# 风险说明: 无直接风险，但可能因查询量大而影响性能

# 按节点分组查看 Pod
kubectl get pods -A -o wide --sort-by='.spec.nodeName'
# 执行方式: 本地执行，API Server返回数据后本地排序
# 用途: 了解Pod在各节点上的分布情况
# 原理: 按Pod定义的nodeName字段排序
# 注意事项: 排序在客户端完成，大数据量时可能较慢
# 风险说明: 无风险

# 查看非 Running 状态的 Pod
kubectl get pods -A --field-selector=status.phase!=Running
# 执行方式: 通过API Server的field-selector功能过滤
# 用途: 快速识别异常状态的Pod
# 原理: API Server根据Pod状态字段进行服务端过滤
# 注意事项: phase字段包括Pending、Running、Succeeded、Failed、Unknown
# 风险说明: 无风险

# 查看 Pod 的资源请求和限制
kubectl get pods -o custom-columns=\
'NAME:.metadata.name,'\
'CPU_REQ:.spec.containers[*].resources.requests.cpu,'\
'CPU_LIM:.spec.containers[*].resources.limits.cpu,'\
'MEM_REQ:.spec.containers[*].resources.requests.memory,'\
'MEM_LIM:.spec.containers[*].resources.limits.memory'
# 执行方式: 本地定义输出格式，API Server返回数据后格式化
# 用途: 检查Pod的资源配置情况
# 原理: 使用Go模板自定义输出列，提取Pod资源定义中的值
# 注意事项: 对于多容器Pod，资源值会以逗号分隔显示
# 风险说明: 无风险

# 查看所有镜像及版本
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{range .spec.containers[*]}{.image}{"\n"}{end}{end}'
# 执行方式: 使用jsonpath格式化输出，API Server返回JSON数据
# 用途: 获取集群中所有Pod使用的镜像信息
# 原理: jsonpath表达式遍历返回的JSON数据结构
# 注意事项: 需要熟悉jsonpath语法
# 风险说明: 无风险

# 查看节点资源分配
kubectl get nodes -o custom-columns=\
'NAME:.metadata.name,'\
'CPU:.status.allocatable.cpu,'\
'MEMORY:.status.allocatable.memory,'\
'PODS:.status.allocatable.pods'
# 执行方式: 查询Node资源的allocatable字段
# 用途: 了解各节点的可分配资源容量
# 原理: Node状态中的allocatable字段表示可分配给Pod的资源
# 注意事项: allocatable可能小于capacity，因为系统组件会占用资源
# 风险说明: 无风险

# 查看 PVC 绑定状态
kubectl get pvc -A -o custom-columns=\
'NAMESPACE:.metadata.namespace,'\
'NAME:.metadata.name,'\
'STATUS:.status.phase,'\
'VOLUME:.spec.volumeName,'\
'CAPACITY:.status.capacity.storage,'\
'STORAGCLASS:.spec.storageClassName'
# 执行方式: 查询PersistentVolumeClaim资源
# 用途: 检查PVC的绑定状态和存储容量
# 原理: 从PVC定义和状态中提取相关信息
# 注意事项: STATUS为Bound表示已绑定到PV
# 风险说明: 无风险

# 查看 Service 端点映射
kubectl get svc,ep -A -o wide
# 执行方式: 查询Service和Endpoints资源
# 用途: 检查服务发现和端点配置
# 原理: Service定义服务发现规则，Endpoints列出后端Pod IP
# 注意事项: Endpoint可能因Pod状态变化而动态更新
# 风险说明: 无风险

# 查看带特定标签的资源
kubectl get all -l app=nginx -A
# 执行方式: 使用标签选择器过滤资源
# 用途: 查找具有特定标签的资源
# 原理: API Server根据标签进行服务端过滤
# 注意事项: -l选项支持复杂的标签选择表达式
# 风险说明: 无风险

# 监视资源变化
kubectl get pods -w --output-watch-events
# 执行方式: 建立长期连接监视资源变化
# 用途: 实时观察Pod状态变化
# 原理: 使用Kubernetes Watch API监视资源事件
# 注意事项: 该命令会持续运行直到手动终止
# 风险说明: 长时间运行可能消耗网络和客户端资源

# 查看资源及其 Owner
kubectl get pods -o custom-columns=\
'NAME:.metadata.name,'\
'OWNER_KIND:.metadata.ownerReferences[0].kind,'\
'OWNER_NAME:.metadata.ownerReferences[0].name'
# 执行方式: 查询Pod的ownerReferences字段
# 用途: 了解Pod的父级控制器
# 原理: Kubernetes使用ownerReferences建立资源之间的层次关系
# 注意事项: 独立Pod可能没有ownerReference
# 风险说明: 无风险
```

### 1.2 高级 JSONPath 查询

```bash
# 获取所有节点 IP
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'
# 执行方式: 通过jsonpath表达式查询节点地址信息
# 用途: 获取所有节点的内部IP地址
# 原理: 遍历节点状态中的地址数组，筛选类型为InternalIP的地址
# 注意事项: 节点可能有多个IP地址，此命令仅返回内部IP
# 风险说明: 无风险

# 获取所有 Secret 名称 (排除 service-account-token)
kubectl get secrets -A -o jsonpath='{range .items[?(@.type!="kubernetes.io/service-account-token")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}'
# 执行方式: 使用jsonpath过滤条件排除特定类型的Secret
# 用途: 获取非SA Token类型的Secret列表
# 原理: 使用jsonpath的条件过滤功能排除kubernetes.io/service-account-token类型的Secret
# 注意事项: service-account-token由系统自动生成，通常不需要手动管理
# 风险说明: 无风险

# 获取所有 Ready 节点
kubectl get nodes -o jsonpath='{range .items[?(@.status.conditions[?(@.type=="Ready")].status=="True")]}{.metadata.name}{"\n"}{end}'
# 执行方式: 查询节点状态中的Ready条件
# 用途: 获取所有健康状态的节点列表
# 原理: 遍历节点状态条件，筛选Ready状态为True的节点
# 注意事项: 只有Ready状态的节点才会被返回
# 风险说明: 无风险

# 获取 Pod 重启次数
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.restartCount}{" "}{end}{"\n"}{end}'
# 执行方式: 查询Pod容器状态中的重启计数
# 用途: 检查Pod中容器的重启情况
# 原理: 遍历Pod的容器状态，获取每个容器的restartCount字段
# 注意事项: 多容器Pod会显示所有容器的重启次数
# 风险说明: 重启次数过多可能表示应用或环境存在问题

# 获取使用特定镜像的 Pod
kubectl get pods -A -o jsonpath='{range .items[?(@.spec.containers[*].image=="nginx:1.25")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}'
# 执行方式: 使用jsonpath条件过滤查找使用特定镜像的Pod
# 用途: 查找使用特定镜像的所有Pod
# 原理: 遍历Pod规格中的容器镜像字段，匹配指定镜像
# 注意事项: 镜像名必须完全匹配，包括标签
# 风险说明: 无风险
```

### 1.3 资源描述与解释

```bash
# 查看 Pod 详情 (包含事件)
kubectl describe pod <pod-name>

# 查看节点详情
kubectl describe node <node-name>

# 查看 Service 详情
kubectl describe svc <service-name>

# 查看 PV/PVC 绑定关系
kubectl describe pv <pv-name>
kubectl describe pvc <pvc-name>

# 查看 Deployment 滚动更新状态
kubectl describe deploy <deployment-name>

# 查看 Ingress 规则和后端
kubectl describe ingress <ingress-name>

# 查看 Pod spec 字段
kubectl explain pod.spec

# 查看容器字段
kubectl explain pod.spec.containers

# 查看特定 API 版本
kubectl explain deployment --api-version=apps/v1

# 递归显示所有字段
kubectl explain pod.spec --recursive

# 查看 CRD 字段
kubectl explain prometheusrules.spec
```

### 1.4 事件查询

```bash
# 查看当前命名空间事件
kubectl events

# 查看所有命名空间事件
kubectl events -A

# 按时间排序
kubectl events --sort-by='.lastTimestamp'

# 只看警告事件
kubectl events --types=Warning

# 监视事件
kubectl events -w

# 查看特定资源的事件
kubectl events --for=pod/nginx

# 组合过滤
kubectl events -A --types=Warning --sort-by='.lastTimestamp' | head -50
```

---

## 2. 集群管理命令

### 2.1 资源创建命令

```bash
# 创建命名空间
kubectl create namespace <name>

# 创建 Deployment
kubectl create deployment <name> --image=<image>

# 创建 Service
kubectl create service clusterip <name> --tcp=<port>:<targetPort>

# 创建 ConfigMap
kubectl create configmap <name> --from-file=<path>

# 创建 Secret
kubectl create secret generic <name> --from-literal=<key>=<value>

# 创建 ServiceAccount
kubectl create serviceaccount <name>

# 创建 Job
kubectl create job <name> --image=<image>

# 创建 CronJob
kubectl create cronjob <name> --image=<image> --schedule=<cron>

# 从文件创建
kubectl create -f deployment.yaml

# 应用配置
kubectl apply -f deployment.yaml

# 应用目录下所有文件
kubectl apply -f ./manifests/

# 服务端 Apply
kubectl apply --server-side -f deployment.yaml

# 强制冲突处理
kubectl apply --server-side --force-conflicts -f deployment.yaml

# 查看差异但不应用
kubectl diff -f deployment.yaml
```

### 2.2 资源删除命令

```bash
# 删除单个资源
kubectl delete pod nginx

# 删除多个资源
kubectl delete pod nginx1 nginx2

# 通过文件删除
kubectl delete -f deployment.yaml

# 通过标签删除
kubectl delete pods -l app=nginx

# 删除命名空间下所有 Pod
kubectl delete pods --all -n <namespace>

# 强制删除 (绕过优雅终止)
kubectl delete pod nginx --force --grace-period=0

# 级联删除策略
kubectl delete deployment nginx --cascade=foreground  # 等待所有依赖删除
kubectl delete deployment nginx --cascade=background  # 后台删除 (默认)
kubectl delete deployment nginx --cascade=orphan      # 孤儿依赖

# 删除并等待
kubectl delete pod nginx --wait=true

# 设置超时
kubectl delete pod nginx --timeout=60s

# 删除所有已完成的 Pod
kubectl delete pods --field-selector=status.phase==Succeeded -A

# 删除所有失败的 Pod
kubectl delete pods --field-selector=status.phase==Failed -A

# 删除 Evicted Pod
kubectl get pods -A | grep Evicted | awk '{print $2 " -n " $1}' | xargs -L1 kubectl delete pod
```

### 2.3 集群信息查看

```bash
# 查看集群信息
kubectl cluster-info

# 查看节点信息
kubectl get nodes -o wide

# 查看 API 资源
kubectl api-resources

# 查看支持特定动作的资源
kubectl api-resources --verbs=list,get

# 查看 namespaced 资源
kubectl api-resources --namespaced=true

# 查看特定 API 组资源
kubectl api-resources --api-group=apps

# 按资源名排序
kubectl api-resources --sort-by=name

# 输出宽格式
kubectl api-resources -o wide
```

---

## 3. Pod 调试与交互命令

### 3.1 容器命令执行

```bash
# 在 Pod 中执行命令
kubectl exec <pod-name> -- <command>
# 执行方式: 通过API Server连接到Pod所在节点的kubelet，再通过CRI与容器运行时通信
# 用途: 在容器内执行一次性命令
# 原理: API Server将请求转发到目标节点的kubelet，kubelet调用容器运行时执行命令
# 注意事项: Pod必须处于Running状态，容器必须已启动
# 风险说明: 执行危险命令可能影响应用运行

# 进入交互式 Shell
kubectl exec -it <pod-name> -- /bin/bash
kubectl exec -it <pod-name> -- /bin/sh
# 执行方式: 建立TTY连接到容器
# 用途: 与容器进行交互式操作
# 原理: 使用-i和-t标志分配TTY并保持stdin开放
# 注意事项: 确保容器内存在指定shell
# 风险说明: 交互式修改可能影响应用状态

# 多容器 Pod 指定容器
kubectl exec -it <pod-name> -c <container-name> -- /bin/bash
# 执行方式: 指定Pod中的特定容器
# 用途: 访问多容器Pod中的特定容器
# 原理: 通过-c参数指定容器名
# 注意事项: 容器名必须与Pod定义中的名称完全匹配
# 风险说明: 进入错误容器可能造成误操作

# 执行复杂命令 (使用 sh -c)
kubectl exec <pod-name> -- sh -c 'cat /etc/hosts && echo "---" && cat /etc/resolv.conf'
# 执行方式: 在容器内执行复合命令
# 用途: 执行多个连续命令
# 原理: 通过shell解释器执行复合命令字符串
# 注意事项: 注意引号转义，避免命令注入
# 风险说明: 复杂命令可能产生意外结果

# 查看环境变量
kubectl exec <pod-name> -- env
# 执行方式: 执行env命令显示容器环境变量
# 用途: 检查容器内的环境变量设置
# 原理: 运行env命令打印所有环境变量
# 注意事项: 环境变量可能包含敏感信息
# 风险说明: 可能泄露敏感配置信息

# 查看进程
kubectl exec <pod-name> -- ps aux
# 执行方式: 在容器内运行ps命令
# 用途: 查看容器内运行的进程
# 原理: ps命令显示容器内的进程信息
# 注意事项: 容器内进程视图受限于容器边界
# 风险说明: 无

# 查看网络
kubectl exec <pod-name> -- netstat -tlnp
# 执行方式: 在容器内执行网络工具
# 用途: 检查容器内的网络连接和监听端口
# 原理: netstat显示容器网络状态
# 注意事项: 需要容器内安装相应工具
# 风险说明: 无

# 测试 DNS 解析
kubectl exec <pod-name> -- nslookup kubernetes.default
# 执行方式: 在容器内执行DNS查询
# 用途: 验证集群DNS服务
# 原理: 使用容器内的DNS解析器查询服务
# 注意事项: 需要容器内安装DNS工具
# 风险说明: 无

# 测试服务连通性
kubectl exec <pod-name> -- curl -s http://service-name:port/health
# 执行方式: 在容器内发起HTTP请求
# 用途: 测试服务间连通性
# 原理: curl向目标服务发起HTTP请求
# 注意事项: 需要容器内安装curl或wget
# 风险说明: 可能触发服务异常行为

# 查看挂载点
kubectl exec <pod-name> -- df -h
# 执行方式: 在容器内执行磁盘使用情况命令
# 用途: 检查容器内挂载的存储卷
# 原理: df命令显示容器内文件系统挂载情况
# 注意事项: 显示的是容器视角下的挂载点
# 风险说明: 无

# 批量执行
kubectl get pods -l app=nginx -o name | xargs -I {} kubectl exec {} -- nginx -v
# 执行方式: 结合管道和xargs对多个Pod执行命令
# 用途: 对多个Pod批量执行命令
# 原理: 先获取Pod列表，然后对每个Pod执行exec命令
# 注意事项: 确保所有Pod都存在所需命令
# 风险说明: 批量操作可能影响多个Pod
```

### 3.2 日志查看

```bash
# 查看 Pod 日志
kubectl logs <pod-name>

# 查看指定容器日志
kubectl logs <pod-name> -c <container-name>

# 实时跟踪日志
kubectl logs -f <pod-name>

# 查看最近 N 行
kubectl logs --tail=100 <pod-name>

# 查看最近时间段
kubectl logs --since=1h <pod-name>
kubectl logs --since=30m <pod-name>
kubectl logs --since-time='2024-01-01T10:00:00Z' <pod-name>

# 查看前一个容器的日志 (重启后)
kubectl logs <pod-name> --previous

# 查看所有容器日志
kubectl logs <pod-name> --all-containers=true

# 查看 Init 容器日志
kubectl logs <pod-name> -c <init-container-name>

# 带时间戳
kubectl logs <pod-name> --timestamps=true

# 查看 Deployment 所有 Pod 日志
kubectl logs -l app=nginx --all-containers=true

# 限制输出字节数
kubectl logs <pod-name> --limit-bytes=1048576

# 组合使用
kubectl logs -f --tail=50 --timestamps <pod-name>
```

### 3.3 文件复制与调试

```bash
# 从 Pod 复制到本地
kubectl cp <namespace>/<pod-name>:<path> <local-path>
kubectl cp default/nginx:/etc/nginx/nginx.conf ./nginx.conf

# 从本地复制到 Pod
kubectl cp <local-path> <namespace>/<pod-name>:<path>
kubectl cp ./config.yaml default/nginx:/tmp/config.yaml

# 指定容器
kubectl cp <local-path> <pod-name>:<path> -c <container-name>

# 复制目录
kubectl cp default/nginx:/var/log/ ./logs/

# 创建调试容器 (Ephemeral Container)
kubectl debug -it <pod-name> --image=busybox --target=<container-name>

# 使用调试 profile
kubectl debug -it <pod-name> --image=busybox --profile=general
kubectl debug -it <pod-name> --image=busybox --profile=baseline
kubectl debug -it <pod-name> --image=busybox --profile=restricted
kubectl debug -it <pod-name> --image=busybox --profile=netadmin
kubectl debug -it <pod-name> --image=busybox --profile=sysadmin

# 复制 Pod 进行调试 (修改命令)
kubectl debug <pod-name> -it --copy-to=debug-pod --container=app -- sh

# 复制 Pod 并修改镜像
kubectl debug <pod-name> -it --copy-to=debug-pod --set-image=*=busybox

# 共享进程命名空间
kubectl debug <pod-name> -it --image=busybox --share-processes

# 调试节点
kubectl debug node/<node-name> -it --image=ubuntu
```

---

## 4. 资源创建与管理命令

### 4.1 资源编辑与补丁

```bash
# 编辑资源
kubectl edit deployment nginx
# 执行方式: 在本地打开默认编辑器，修改后应用到API Server
# 用途: 交互式编辑资源定义
# 原理: 获取资源当前配置，使用默认编辑器打开，保存后应用更新
# 注意事项: 编辑器需支持终端交互，如vim、nano等
# 风险说明: 直接修改生产资源需谨慎，可能导致服务中断

# 指定编辑器
KUBE_EDITOR="vim" kubectl edit deployment nginx
KUBE_EDITOR="code --wait" kubectl edit deployment nginx
# 执行方式: 使用环境变量指定编辑器
# 用途: 使用特定编辑器编辑资源
# 原理: 通过KUBE_EDITOR环境变量覆盖默认编辑器
# 注意事项: 图形编辑器需要--wait参数等待编辑完成
# 风险说明: 同上

# 编辑子资源 (v1.28+)
kubectl edit deployment nginx --subresource=status
# 执行方式: 编辑资源的特定子资源
# 用途: 修改资源的状态子资源
# 原理: 直接编辑资源的status字段
# 注意事项: 通常只应由控制器修改status字段
# 风险说明: 手动修改状态可能导致控制器行为异常

# 更新镜像
kubectl patch deployment nginx -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","image":"nginx:1.26"}]}}}}'
# 执行方式: 使用patch命令部分更新资源
# 用途: 更新Deployment中的容器镜像
# 原理: 发送PATCH请求到API Server，应用策略性合并补丁
# 注意事项: JSON格式需正确，否则更新失败
# 风险说明: 镜像更新会触发滚动更新，可能导致服务短暂中断

# 添加环境变量
kubectl patch deployment nginx -p '
spec:
  template:
    spec:
      containers:
      - name: nginx
        env:
        - name: NEW_VAR
          value: "new_value"
' --type=strategic
# 执行方式: 使用YAML格式的策略性补丁
# 用途: 为容器添加环境变量
# 原理: 使用策略性合并补丁，智能合并现有配置
# 注意事项: strategic类型会智能合并数组和对象
# 风险说明: 环境变量可能影响应用行为

# 更新副本数
kubectl patch deployment nginx -p '{"spec":{"replicas":5}}'
# 执行方式: 部分更新Deployment副本数
# 用途: 水平扩展或收缩应用
# 原理: 修改Deployment的期望副本数，触发控制器重新平衡
# 注意事项: 确保集群有足够资源
# 风险说明: 资源不足可能导致Pod无法调度

# 添加标签
kubectl patch deployment nginx -p '{"metadata":{"labels":{"version":"v2"}}}'
# 执行方式: 更新资源元数据标签
# 用途: 为资源添加标识标签
# 原理: 修改资源的metadata.labels字段
# 注意事项: 标签键值对需符合K8s规范
# 风险说明: 标签可能影响服务发现和选择器

# 添加注解
kubectl patch deployment nginx -p '{"metadata":{"annotations":{"description":"Updated deployment"}}}'
# 执行方式: 更新资源元数据注解
# 用途: 为资源添加描述性注解
# 原理: 修改资源的metadata.annotations字段
# 注意事项: 注解值可以是任意字符串
# 风险说明: 无

# 更新 NodeSelector
kubectl patch deployment nginx -p '{"spec":{"template":{"spec":{"nodeSelector":{"disktype":"ssd"}}}}}'
# 执行方式: 更新Pod的节点选择器
# 用途: 限制Pod只能调度到特定节点
# 原理: 修改Pod模板中的nodeSelector字段
# 注意事项: 确保有节点具有指定标签
# 风险说明: 如果没有匹配节点，Pod将无法调度

# JSON Patch - 替换镜像
kubectl patch deployment nginx --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/image","value":"nginx:1.26"}]'
# 执行方式: 使用RFC 6902 JSON Patch格式
# 用途: 精确替换JSON路径的值
# 原理: 执行JSON Patch操作，支持add、replace、remove等
# 注意事项: JSON Patch语法较为严格，路径需准确
# 风险说明: 错误的路径可能修改意外字段

# JSON Patch - 添加容器
kubectl patch deployment nginx --type='json' -p='[{"op":"add","path":"/spec/template/spec/containers/-","value":{"name":"sidecar","image":"busybox"}}]'
# 执行方式: 使用JSON Patch添加新容器
# 用途: 向Pod中添加sidecar容器
# 原理: 在容器数组末尾添加新元素
# 注意事项: 需要确保Pod资源足够
# 风险说明: 添加容器会改变Pod配置，可能影响应用行为
```

### 4.2 资源设置命令

```bash
# 更新镜像
kubectl set image deployment/nginx nginx=nginx:1.26

# 更新多个容器镜像
kubectl set image deployment/app app=app:v2 sidecar=sidecar:v2

# 所有容器使用相同镜像
kubectl set image deployment/nginx *=nginx:1.26

# 设置环境变量
kubectl set env deployment/nginx DB_HOST=mysql
kubectl set env deployment/nginx DB_HOST=mysql DB_PORT=3306

# 从 ConfigMap 设置环境变量
kubectl set env deployment/nginx --from=configmap/app-config

# 从 Secret 设置环境变量
kubectl set env deployment/nginx --from=secret/app-secret

# 删除环境变量
kubectl set env deployment/nginx DB_HOST-

# 查看环境变量
kubectl set env deployment/nginx --list

# 设置资源限制
kubectl set resources deployment/nginx \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=200m,memory=256Mi

# 设置 ServiceAccount
kubectl set serviceaccount deployment/nginx my-sa

# 设置 selector (慎用)
kubectl set selector service nginx 'app=nginx,version=v2'

# 设置 subject (RBAC)
kubectl set subject rolebinding admin --user=alice

# 添加标签
kubectl label pods nginx env=prod

# 更新标签
kubectl label pods nginx env=staging --overwrite

# 删除标签
kubectl label pods nginx env-

# 批量添加标签
kubectl label pods -l app=nginx tier=frontend

# 添加节点标签
kubectl label node node1 node-role.kubernetes.io/worker=

# 查看标签
kubectl get pods --show-labels

# 按标签筛选
kubectl get pods -l 'env in (prod,staging)'
kubectl get pods -l 'env notin (dev)'
kubectl get pods -l 'env'        # 有此标签
kubectl get pods -l '!env'       # 无此标签

# 添加注解
kubectl annotate pods nginx description="Web server"

# 更新注解
kubectl annotate pods nginx description="Updated web server" --overwrite

# 删除注解
kubectl annotate pods nginx description-

# 批量添加
kubectl annotate pods -l app=nginx team=platform
```

---

## 5. 集群配置参数

### 5.1 kube-apiserver 参数

```bash
# 基础网络与存储参数
--etcd-servers=https://etcd1:2379,https://etcd2:2379,https://etcd3:2379
--etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
--etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
--etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
--service-cluster-ip-range=10.96.0.0/12
--bind-address=0.0.0.0
--advertise-address=<master-ip>

# 认证参数
--client-ca-file=/etc/kubernetes/pki/ca.crt
--tls-cert-file=/etc/kubernetes/pki/apiserver.crt
--tls-private-key-file=/etc/kubernetes/pki/apiserver.key
--anonymous-auth=false
--enable-bootstrap-token-auth=true
--service-account-issuer=https://kubernetes.default.svc
--oidc-issuer-url=<oidc-provider-url>
--oidc-client-id=<oauth-client-id>

# 授权参数
--authorization-mode=Node,RBAC

# 准入控制参数
--enable-admission-plugins=\
NodeRestriction,\
PodSecurity,\
LimitRanger,\
ServiceAccount,\
DefaultStorageClass,\
DefaultTolerationSeconds,\
MutatingAdmissionWebhook,\
ValidatingAdmissionWebhook,\
ValidatingAdmissionPolicy,\
ResourceQuota,\
Priority,\
RuntimeClass

# 审计日志参数
--audit-log-path=/var/log/kubernetes/audit.log
--audit-log-maxage=30
--audit-log-maxbackup=10
--audit-log-maxsize=100
--audit-log-compress=true
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
```

### 5.2 kubelet 参数

```bash
# 基础配置参数
--config=/var/lib/kubelet/config.yaml
--kubeconfig=/etc/kubernetes/kubelet.conf
--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf
--hostname-override=<hostname>
--node-ip=<node-ip>

# 容器运行时参数
--container-runtime-endpoint=unix:///run/containerd/containerd.sock
--image-service-endpoint=unix:///run/containerd/containerd.sock
--pod-infra-container-image=registry.k8s.io/pause:3.9

# Pod 与容器限制参数
--max-pods=110
--pod-max-pids=4096

# 资源预留参数
--system-reserved=cpu=500m,memory=1Gi
--kube-reserved=cpu=500m,memory=1Gi
--enforce-node-allocatable=pods,kube-reserved,system-reserved

# 驱逐阈值配置
--eviction-hard=memory.available<500Mi,nodefs.available<15%,nodefs.inodesFree<10%,imagefs.available<15%,pid.available<1000
--eviction-soft=memory.available<1Gi,nodefs.available<20%
--eviction-soft-grace-period=memory.available=2m,nodefs.available=2m

# 镜像管理参数
--image-gc-high-threshold=80
--image-gc-low-threshold=70
--serialize-image-pulls=false

# 安全参数
--rotate-certificates=true
--protect-kernel-defaults=true
--read-only-port=0
--anonymous-auth=false
--authorization-mode=Webhook

# cgroup 参数
--cgroup-driver=systemd
--cpu-manager-policy=static
--memory-manager-policy=Static
--topology-manager-policy=best-effort
```

---

## 6. GPU 调度与管理命令

### 6.1 GPU Operator 部署

```bash
# 部署GPU Operator
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update

helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --create-namespace \
  --version v23.9.1 \
  -f gpu-operator-values.yaml

# 查看 GPU 节点资源
kubectl describe node <gpu-node> | grep -A 10 "Allocated resources"

# 查看 Device Plugin 日志
kubectl logs -n gpu-operator -l app=nvidia-device-plugin-daemonset

# 查看 GPU Operator 状态
kubectl get pods -n gpu-operator

# 查看节点 GPU 标签
kubectl get nodes -L nvidia.com/gpu.product,nvidia.com/gpu.count,nvidia.com/mig.config
```

### 6.2 GPU 诊断命令

```bash
# 基础诊断
nvidia-smi
# 执行方式: 在GPU节点上执行，查询NVIDIA驱动状态
# 用途: 查看GPU基本信息、使用情况和驱动版本
# 原理: 通过NVML库与GPU驱动通信获取状态信息
# 注意事项: 需要在安装了NVIDIA驱动的节点上执行
# 风险说明: 无

nvidia-smi -q
# 执行方式: 详细查询GPU信息
# 用途: 获取GPU的详细硬件和状态信息
# 原理: 查询驱动程序提供的完整设备信息
# 注意事项: 输出信息较多，可能需要过滤
# 风险说明: 无

nvidia-smi topo -m
# 执行方式: 查询GPU拓扑结构
# 用途: 查看GPU之间的连接关系和拓扑
# 原理: 获取PCIe和NVLink拓扑信息
# 注意事项: 有助于优化多GPU通信
# 风险说明: 无

nvidia-smi nvlink -s
# 执行方式: 查询NVLink状态
# 用途: 检查NVLink连接状态和带宽
# 原理: 获取NVLink链路状态信息
# 注意事项: 仅适用于支持NVLink的GPU
# 风险说明: 无

# 性能诊断
nvidia-smi dmon -s pucvmet -d 1
# 执行方式: 实时监控GPU性能指标
# 用途: 持续监控GPU利用率、显存、温度等
# 原理: 以指定频率收集GPU性能数据
# 注意事项: 持续输出，需手动终止
# 风险说明: 无

nvidia-smi pmon -s um -d 1
# 执行方式: 监控运行中的进程
# 用途: 查看哪些进程在使用GPU
# 原理: 监控GPU上运行的进程信息
# 注意事项: 显示当前正在使用GPU的进程
# 风险说明: 无

nvidia-smi -q -d CLOCK
nvidia-smi -q -d POWER
# 执行方式: 查询特定硬件状态
# 用途: 检查时钟频率和功耗
# 原理: 获取GPU硬件监控数据
# 注意事项: 有助于性能调优
# 风险说明: 无

# 故障诊断
dmesg | grep -i "nvrm|xid"
# 执行方式: 在节点上执行，查询内核日志
# 用途: 查找NVIDIA驱动相关错误
# 原理: 搜索内核消息中的GPU错误
# 注意事项: XID错误表明硬件问题
# 风险说明: XID错误可能需要重启或更换GPU

nvidia-smi -q -d ECC
nvidia-smi -q -d PAGE_RETIREMENT
# 执行方式: 查询ECC和页面退役信息
# 用途: 检查GPU内存错误
# 原理: 获取ECC错误计数和显存页面退役状态
# 注意事项: ECC错误可能表明硬件故障
# 风险说明: 持续增加的ECC错误可能需要更换GPU

cat /proc/driver/nvidia/version
# 执行方式: 查看驱动版本文件
# 用途: 确认NVIDIA驱动版本
# 原理: 读取驱动程序版本信息
# 注意事项: 有助于排查版本兼容性问题
# 风险说明: 无

# MIG 诊断
nvidia-smi mig -lgi
nvidia-smi mig -lci
nvidia-smi mig -lgip
nvidia-smi mig -lcip
# 执行方式: 查询MIG实例和配置信息
# 用途: 检查MIG划分和实例状态
# 原理: 获取多实例GPU配置信息
# 注意事项: 仅适用于支持MIG的GPU(A100等)
# 风险说明: MIG配置错误可能影响GPU使用
```

### 6.3 GPU 资源配置

```bash
# Time-Slicing 配置
kubectl label node gpu-train-01 nvidia.com/device-plugin.config=none
kubectl label node gpu-infer-01 nvidia.com/device-plugin.config=inference
kubectl label node gpu-dev-01 nvidia.com/device-plugin.config=development

# MIG 配置应用到节点
kubectl label node gpu-node-01 nvidia.com/mig.config="all-1g.10gb"

# 使用 GPU 资源的 Pod 配置
# 整卡资源: nvidia.com/gpu: 1
# MIG 资源: nvidia.com/mig-1g.10gb: 1
```

---

## 7. AI/ML 工作负载命令

### 7.1 Kubeflow 训练任务

```bash
# 提交 PyTorchJob
kubectl apply -f pytorchjob.yaml

# 查看 PyTorchJob 状态
kubectl get pytorchjob
kubectl describe pytorchjob <job-name>

# 查看分布式训练 Pod
kubectl get pods -l pytorch-job-name=<job-name>

# 查看训练日志
kubectl logs -f -l pytorch-job-name=<job-name> -c pytorch

# 弹性训练配置
# 在 PyTorchJob 中设置 elasticPolicy
```

### 7.2 模型推理服务

```bash
# 部署 KServe InferenceService
kubectl apply -f inference-service.yaml

# 查看推理服务状态
kubectl get inferenceservice
kubectl describe inferenceservice <service-name>

# 查看预测器 Pod
kubectl get pods -l serving.kserve.io/inferenceservice=<service-name>

# 获取服务 URL
kubectl get inferenceservice <service-name> -o jsonpath='{.status.url}'

# 测试推理服务
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Host: <service-name>.<namespace>.example.com" \
  http://<ingress-gateway-ip>/v1/models/<model-name>:predict \
  -d '{"instances": [[1.0, 2.0, 5.0]]}'
```

### 7.3 Spark 数据处理

```bash
# 提交 Spark Application
kubectl apply -f spark-application.yaml

# 查看 Spark 应用状态
kubectl get sparkapplication
kubectl describe sparkapplication <app-name>

# 查看 Driver 和 Executors
kubectl get pods -l spark-app-selector=<app-selector>

# 查看 Spark UI
kubectl port-forward <driver-pod> 4040:4040
```

---

## 8. 故障排查工具命令

### 8.1 K9s 使用

```bash
# 启动 K9s
k9s

# 快捷键
# :pod - 切换到 Pod 视图
# :ns - 切换到 Namespace 视图
# :dp - 切换到 Deployment 视图
# / - 过滤资源
# d - Describe 资源
# y - 查看 YAML
# l - 查看日志
# s - 进入 Shell
# Ctrl-D - 删除资源

# 查看 Pod 详情
kubectl describe pod <pod-name>

# 查看 Pod 日志
kubectl logs <pod-name> -f

# 进入 Pod 容器
kubectl exec -it <pod-name> -- bash
```

### 8.2 Netshoot 网络诊断

```bash
# 临时 Netshoot Pod
kubectl run netshoot --rm -it \
    --image=nicolaka/netshoot \
    --restart=Never \
    -- bash

# Ephemeral Container 调试
kubectl debug -it <pod-name> \
    --image=nicolaka/netshoot \
    --target=<container-name> \
    -- bash

# DNS 诊断
nslookup kubernetes.default
dig kubernetes.default.svc.cluster.local

# 网络连通性测试
nc -zv <service-name> <port>
curl -v http://<service-name>:<port>/healthz

# 抓包分析
tcpdump -i eth0 -nn port 80
```

### 8.3 Stern 多 Pod 日志

```bash
# 查看匹配名称的所有 Pod 日志
stern myapp

# 正则匹配
stern "myapp-.*"

# 按标签过滤
stern -l app=nginx

# 指定命名空间
stern -n production myapp

# 所有命名空间
stern --all-namespaces myapp

# 最近1小时日志
stern --since 1h myapp

# 带时间戳
stern --timestamps myapp
```

### 8.4 kubectl 插件

```bash
# 安装 krew
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

# 安装常用插件
kubectl krew install debug        # 容器调试
kubectl krew install trace       # eBPF追踪
kubectl krew install sniff       # 抓包分析
kubectl krew install tree        # 资源关系树
kubectl krew install neat        # 清理YAML输出
kubectl krew install ctx         # Context切换
kubectl krew install ns          # Namespace切换
kubectl krew install images      # 镜像信息

# 使用插件
kubectl tree deployment/nginx        # 查看资源关系
kubectl neat get pod nginx -o yaml   # 清理YAML输出
kubectl ctx production              # 切换context
kubectl ns monitoring               # 切换namespace
```

---

## 9. 安全与认证命令

### 9.1 RBAC 管理

```bash
# 创建 ServiceAccount
kubectl create serviceaccount <sa-name>

# 创建 Role
kubectl create role <role-name> --verb=get,list,watch --resource=pods

# 创建 RoleBinding
kubectl create rolebinding <rb-name> --role=<role-name> --serviceaccount=<namespace>:<sa-name>

# 创建 ClusterRole
kubectl create clusterrole <cr-name> --verb=get,list,watch --resource=nodes

# 创建 ClusterRoleBinding
kubectl create clusterrolebinding <crb-name> --clusterrole=<cr-name> --serviceaccount=<namespace>:<sa-name>

# 查看权限
kubectl auth can-i get pods
kubectl auth can-i get pods --as=system:serviceaccount:default:my-service-account

# 查看用户权限矩阵
kubectl auth reconcile -f rbac.yaml
```

### 9.2 证书管理

```bash
# 创建 CSR
kubectl create -f csr.yaml

# 查看 CSR
kubectl get csr

# 审批 CSR
kubectl certificate approve <csr-name>

# 拒绝 CSR
kubectl certificate deny <csr-name>

# 查看证书信息
kubectl get csr <csr-name> -o yaml

# 创建 Token
kubectl create token <service-account-name>

# 指定过期时间
kubectl create token <sa-name> --duration=24h
```

---

## 10. 监控与告警命令

### 10.1 资源监控

```bash
# 查看节点资源使用
kubectl top nodes

# 查看 Pod 资源使用
kubectl top pods

# 查看 Pod 容器资源使用
kubectl top pods --containers

# 查看命名空间资源使用
kubectl top pods -n <namespace>

# 查看实时指标
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods
```

### 10.2 事件查看

```bash
# 查看命名空间事件
kubectl get events -n <namespace>

# 查看所有命名空间事件
kubectl get events --all-namespaces

# 按时间排序
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# 查看特定资源事件
kubectl get events -n <namespace> --field-selector involvedObject.name=<resource-name>

# 查看最近事件
kubectl get events -n <namespace> --since=1h
```

### 10.3 健康检查

```bash
# 检查集群组件状态
kubectl get componentstatuses

# 检查集群健康
kubectl cluster-info

# 检查节点状态
kubectl get nodes
kubectl describe node <node-name>

# 检查系统 Pod 状态
kubectl get pods -n kube-system

# 检查 API 服务器连接
kubectl version
```

---

## 附录：常用配置模板

### A.1 Pod 配置模板

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example-pod
  labels:
    app: example
spec:
  containers:
  - name: app
    image: nginx:latest
    ports:
    - containerPort: 80
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 30
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
  restartPolicy: Always
```

### A.2 Deployment 配置模板

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: example
  template:
    metadata:
      labels:
        app: example
    spec:
      containers:
      - name: app
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
```

### A.3 Service 配置模板

```yaml
apiVersion: v1
kind: Service
metadata:
  name: example-service
spec:
  selector:
    app: example
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
```

---

## 命令执行方式说明

| 命令 | 执行位置 | 适用场景 | 说明 |
|------|----------|----------|------|
| kubectl get/describe/apply/delete | Master节点/本地 | 资源管理 | 通过API Server操作，需要认证和授权 |
| kubectl exec/logs | Master节点发起，实际在Pod所在Node执行 | 调试Pod | 需要与kubelet通信，需要Pod所在节点网络可达 |
| kubectl cp | Master节点发起，涉及Pod所在Node | 文件传输 | 需要与Pod所在Node通信，使用tar命令打包传输 |
| kubectl port-forward | 本地执行 | 端口转发 | 建立本地与Pod的连接，需要API Server代理 |
| kubectl proxy | 本地执行 | API代理 | 本地启动代理服务器，转发API请求 |
| kubectl debug | Master节点发起，调试Pod在Node上运行 | Pod调试 | 创建临时调试容器或复制Pod进行调试 |
| nvidia-smi | GPU节点 | GPU诊断 | 在安装了NVIDIA驱动的节点上执行 |
| stern/k9s | 本地执行 | 日志/资源查看 | 通过API Server获取数据 |
| kubectl config | 本地执行 | 配置管理 | 操作本地kubeconfig文件 |
| kubectl auth | Master节点 | 认证授权 | 查询API Server中的认证授权信息 |
| kubectl certificate | Master节点 | 证书管理 | 管理CSR资源 |

## 用途与原理说明

1. **kubectl get命令**：通过 REST API 与 Kubernetes API Server 通信，查询etcd中存储的资源状态，实现对集群资源的查看
2. **kubectl apply命令**：使用服务器端应用(Server-Side Apply)机制，将配置应用到API Server，并触发相应的控制器进行状态同步
3. **kubectl exec命令**：通过API Server连接到目标节点的kubelet，再通过CRI接口与容器运行时通信，执行容器内的命令
4. **kubectl logs命令**：通过API Server连接到Pod所在节点的kubelet，读取容器运行时的日志文件
5. **kubectl port-forward命令**：建立本地端口到Pod的隧道，通过API Server的端口转发功能实现
6. **kubectl proxy命令**：在本地启动HTTP代理服务器，代理所有API请求到API Server，提供便捷的API访问
7. **资源调度**：通过调度器(scheduler)将Pod调度到合适的节点上运行，考虑资源需求、亲和性、污点容忍等因素
8. **网络通信**：通过CNI插件实现Pod间网络通信，支持多种网络方案如Calico、Flannel、Cilium等
9. **存储管理**：通过CSI插件实现持久化存储的管理，支持各种存储后端如NFS、Ceph、云存储等
10. **安全机制**：通过RBAC、准入控制器、Pod安全标准等实现访问控制和安全策略

## 注意事项与风险说明

1. **权限风险**：确保使用最小权限原则，避免过度授权，定期审查RBAC权限
2. **数据丢失**：删除操作可能导致数据丢失，执行前确认，重要数据做好备份
3. **服务中断**：某些操作可能导致服务短暂中断，如drain节点、重启Pod等，应在维护窗口执行
4. **资源配置**：不当的资源限制可能影响应用性能，应根据实际需求合理配置
5. **安全配置**：确保安全配置正确，避免安全漏洞，定期更新证书和密钥
6. **备份策略**：重要操作前备份相关配置，定期备份etcd数据
7. **网络影响**：网络相关的操作可能影响服务可用性，应谨慎操作
8. **GPU资源**：GPU资源昂贵，需合理分配和使用，避免资源浪费
9. **长时间运行**：AI/ML训练任务耗时长，需考虑容错机制和检查点保存
10. **成本控制**：合理使用资源，避免不必要的成本支出，使用资源配额和限制
11. **版本兼容性**：注意kubectl与集群版本的兼容性，差异不应超过一个次要版本
12. **配置错误**：YAML配置错误可能导致资源无法正常运行，使用kubectl diff预览变更
13. **网络策略**：应用网络策略时需确保不会阻断必要的服务通信
14. **存储回收**：删除PVC时注意存储类的回收策略，避免数据意外删除
15. **节点维护**：排空节点前确认节点上的关键Pod已迁移或可接受中断

## 风险缓解措施

1. **使用dry-run**：在执行重要操作前使用`--dry-run=server`验证配置
2. **渐进式变更**：对生产环境使用蓝绿部署或金丝雀发布
3. **监控告警**：实施全面的监控和告警，及时发现问题
4. **自动化测试**：使用CI/CD流水线进行自动化测试和验证
5. **权限审计**：定期审计和清理不必要的权限
6. **备份验证**：定期验证备份的有效性和恢复流程
7. **变更管理**：遵循变更管理流程，在非高峰时段执行变更
8. 回滚计划：制定详细的回滚计划和预案

---

## 11. 容器运行时命令

### 11.1 containerd 命令行工具

```bash
# ctr - containerd 原生 CLI
# 列出命名空间
ctr namespaces ls

# 在 k8s.io 命名空间操作 (Kubernetes 使用)
ctr -n k8s.io images ls
ctr -n k8s.io containers ls
ctr -n k8s.io tasks ls

# 拉取镜像
ctr images pull docker.io/library/nginx:latest

# 运行容器
ctr run -d --rm docker.io/library/nginx:latest nginx

# 执行命令
ctr tasks exec --exec-id exec1 nginx sh

# 查看容器日志 (需要配置)
ctr tasks logs nginx

# nerdctl - Docker 兼容的 CLI
# 安装: https://github.com/containerd/nerdctl
nerdctl run -d --name nginx -p 80:80 nginx:latest
nerdctl ps
nerdctl logs nginx
nerdctl exec -it nginx sh
nerdctl stop nginx
nerdctl rm nginx

# crictl - CRI 调试工具
crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps
crictl pods
crictl images
crictl logs <container-id>
crictl exec -it <container-id> sh
# 执行方式: 在节点上直接执行，通过CRI接口与容器运行时通信
# 用途: 调试容器运行时问题，查看容器状态
# 原理: 直接与容器运行时交互，绕过kubelet
# 注意事项: 需要在节点上执行，需要相应权限
# 风险说明: 直接操作容器可能影响Pod状态
```

### 11.2 CRI-O 命令行工具

```bash
# crictl - CRI 调试工具 (通用)
export CONTAINER_RUNTIME_ENDPOINT=unix:///var/run/crio/crio.sock
crictl ps
crictl pods
crictl images
crictl logs <container-id>
crictl exec -it <container-id> sh
crictl stats
crictl info

# podman - 独立容器工具 (与 CRI-O 共享库)
podman run -d --name nginx nginx:latest
podman ps
podman logs nginx
podman exec -it nginx sh
podman stop nginx
podman rm nginx

# skopeo - 镜像工具
skopeo copy docker://docker.io/library/nginx:latest oci:nginx:latest
skopeo inspect docker://docker.io/library/nginx:latest
skopeo list-tags docker://docker.io/library/nginx

# buildah - 镜像构建
buildah from nginx:latest
buildah run nginx-working-container -- apt-get update
buildah commit nginx-working-container my-nginx:latest
# 执行方式: 在节点上执行，直接操作容器和镜像
# 用途: 容器运行时调试，镜像管理
# 原理: 绕过Kubernetes，直接与容器运行时交互
# 注意事项: 不受Kubernetes资源限制和策略约束
# 风险说明: 可能绕过安全策略，影响节点稳定性
```

---

## 12. CLI 增强工具命令

### 12.1 kubectx / kubens 快速切换

```bash
# 列出所有上下文
kubectx

# 切换上下文
kubectx production

# 切换回上一个上下文
kubectx -

# 列出所有命名空间
kubens

# 切换命名空间
kubens kube-system

# 执行方式: 本地执行，修改kubeconfig文件
# 用途: 快速切换Kubernetes上下文和命名空间
# 原理: 修改kubeconfig中的当前上下文和命名空间
# 注意事项: 需要预先配置多个上下文
# 风险说明: 误操作可能在错误的集群/命名空间执行命令
```

### 12.2 kube-capacity 资源余量

```bash
# 查看所有节点
kube-capacity

# 按节点分组
kube-capacity --sort cpu.util

# 查看 Pod 级别
kube-capacity --pods

# 输出 JSON
kube-capacity -o json

# 执行方式: 本地执行，通过API Server获取资源信息
# 用途: 查看集群资源容量和使用情况
# 原理: 查询API Server获取节点和Pod资源请求/限制
# 注意事项: 需要适当的RBAC权限
# 风险说明: 无直接风险，但需要足够的API权限
```

### 12.3 kubectl 插件和别名

```bash
# kubectl tree - 查看资源依赖树
kubectl tree deployment myapp
kubectl tree statefulset mysql

# kubectl neat - 清理 YAML 输出
kubectl get pod myapp -o yaml | kubectl neat
kubectl get deployment myapp -o yaml | kubectl neat > myapp-clean.yaml

# 常用别名
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kdel='kubectl delete'
alias kl='kubectl logs'
alias kex='kubectl exec -it'
alias kaf='kubectl apply -f'

# 快速查看
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods --all-namespaces'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'

# 实用函数
ksh() {
  kubectl exec -it $1 -- /bin/bash
}

klog() {
  kubectl logs -f $1
}

kdele() {
  kubectl get pods --all-namespaces | grep Evicted | awk '{print $2, "-n", $1}' | xargs kubectl delete pod
}

# 执行方式: 本地执行，通过kubectl与API Server交互
# 用途: 提高kubectl使用效率
# 原理: 通过别名和函数简化常用命令
# 注意事项: 需要正确配置环境和权限
# 风险说明: 简化操作可能导致误操作
```

---

## 13. 故障排查工具命令

### 13.1 K9s 运维工具

```bash
# 启动 K9s
k9s

# 快捷键 (在K9s界面中)
# :pod - 切换到 Pod 视图
# :ns - 切换到 Namespace 视图
# :dp - 切换到 Deployment 视图
# / - 过滤资源
# d - Describe 资源
# y - 查看 YAML
# l - 查看日志
# s - 进入 Shell
# Ctrl-D - 删除资源

# 从命令行直接进入特定资源视图
k9s --context production --namespace kube-system
k9s -c pods -n monitoring

# 执行方式: 本地执行，通过API Server获取实时数据
# 用途: 交互式管理Kubernetes资源
# 原理: 实时监控API Server的资源变化
# 注意事项: 需要适当的RBAC权限
# 风险说明: 交互式删除操作可能导致意外删除
```

### 13.2 Netshoot 网络诊断

```bash
# 临时 Netshoot Pod
kubectl run netshoot --rm -it \
    --image=nicolaka/netshoot \
    --restart=Never \
    -- bash

# Ephemeral Container 调试
kubectl debug -it <pod-name> \
    --image=nicolaka/netshoot \
    --target=<container-name> \
    -- bash

# DNS 诊断
nslookup kubernetes.default
dig kubernetes.default.svc.cluster.local

# 网络连通性测试
nc -zv <service-name> <port>
curl -v http://<service-name>:<port>/healthz

# 抓包分析
tcpdump -i eth0 -nn port 80

# 执行方式: 在Pod中执行网络诊断工具
# 用途: 诊断网络连接和DNS解析问题
# 原理: 在集群网络环境中运行网络工具
# 注意事项: 需要相应的网络权限
# 风险说明: 抓包可能捕获敏感数据
```

### 13.3 DNS 诊断工具

```bash
# 基本查询 (在Pod中执行)
dig @10.96.0.10 nginx.default.svc.cluster.local

# 指定查询类型
dig @10.96.0.10 nginx.default.svc.cluster.local A
dig @10.96.0.10 _http._tcp.nginx.default.svc.cluster.local SRV

# 简短输出
dig @10.96.0.10 nginx.default.svc.cluster.local +short

# 反向解析
dig @10.96.0.10 -x 10.96.0.1

# nslookup 基本查询
nslookup nginx.default.svc.cluster.local 10.96.0.10

# 在Pod内部检查DNS配置
kubectl exec <pod> -- cat /etc/resolv.conf

# 执行方式: 在Pod内执行，查询CoreDNS服务
# 用途: 诊断DNS解析问题
# 原理: 直接查询集群DNS服务
# 注意事项: 需要在Pod网络上下文中执行
# 风险说明: 无直接风险
```

### 13.4 网络故障排查命令

```bash
# 检查 Pod 网络配置
kubectl exec pod-a -- ip addr
kubectl exec pod-a -- ip route

# 检查 veth pair
ip link show | grep veth
bridge link show

# 检查 bridge/cni0
ip addr show cni0
bridge fdb show br cni0

# 检查 iptables
iptables -t filter -L FORWARD -n -v

# 检查 VXLAN 接口 (Flannel)
ip -d link show flannel.1
bridge fdb show dev flannel.1

# 检查路由
ip route | grep <target-pod-cidr>

# 检查 BGP 状态 (Calico)
calicoctl node status

# 检查 Pod DNS 配置
kubectl exec <pod> -- cat /etc/resolv.conf

# DNS 解析测试
kubectl exec <pod> -- nslookup kubernetes.default
kubectl exec <pod> -- nslookup <service-name>.<namespace>

# 执行方式: 在节点或Pod中执行网络诊断命令
# 用途: 诊断CNI网络问题
# 原理: 检查网络接口、路由表、iptables规则等
# 注意事项: 需要有相应节点访问权限
# 风险说明: 修改网络配置可能影响网络连通性
```

---

## 14. 集群组件诊断命令

### 14.1 etcd 诊断命令

```bash
# 基础操作
etcdctl put key value                    # 写入
etcdctl get key                          # 读取
etcdctl get --prefix /registry/          # 前缀查询
etcdctl del key                          # 删除
etcdctl watch key                        # 监听变化

# 集群管理
etcdctl member list                      # 成员列表
etcdctl member add name --peer-urls=url  # 添加成员
etcdctl member remove id                 # 移除成员
etcdctl endpoint health --cluster        # 健康检查
etcdctl endpoint status --cluster        # 状态详情

# 维护操作
etcdctl snapshot save file.db            # 快照备份
etcdctl snapshot restore file.db         # 恢复
etcdctl compact revision                 # 压缩
etcdctl defrag                           # 碎片整理
etcdctl alarm list                       # 告警列表
etcdctl alarm disarm                     # 清除告警

# 执行方式: 在etcd节点上执行，直接操作etcd集群
# 用途: etcd集群管理和维护
# 原理: 通过etcdctl客户端与etcd集群通信
# 注意事项: 需要正确的证书和权限，操作需谨慎
# 风险说明: 错误操作可能导致集群数据不一致或不可用
```

### 14.2 kubelet 诊断命令

```bash
# 检查 kubelet 状态
systemctl status kubelet
journalctl -u kubelet -f --no-pager

# 检查节点状态
kubectl describe node <node-name>

# 检查容器运行时
crictl info
crictl ps -a
crictl logs <container-id>

# 检查 PLEG 健康
curl -s http://localhost:10248/healthz

# 检查 kubelet API (需认证)
curl -k https://localhost:10250/healthz
curl -k https://localhost:10250/pods

# 检查证书
openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates

# 执行方式: 在节点上执行，检查本地kubelet状态
# 用途: 诊断节点和kubelet问题
# 原理: 直接与本地kubelet服务通信
# 注意事项: 需要节点访问权限
# 风险说明: 检查操作一般无风险，但需注意API访问安全
```

### 14.3 通用诊断命令

```bash
# 组件状态
kubectl get --raw='/readyz?verbose'

# etcd诊断
ETCDCTL_API=3 etcdctl member list -w table
ETCDCTL_API=3 etcdctl alarm list
ETCDCTL_API=3 etcdctl endpoint health --cluster

# 容器运行时
crictl ps -a
crictl logs <container-id>
crictl images

# 网络诊断
ipvsadm -Ln  # IPVS模式
iptables -t nat -L -n -v | grep KUBE  # iptables模式
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes

# Pod诊断脚本示例
#!/bin/bash
# pod-diagnose.sh - Pod 诊断脚本
POD_NAME=${1:-}
NAMESPACE=${2:-default}

if [ -z "$POD_NAME" ]; then
    echo "Usage: $0 <pod-name> [namespace]"
    exit 1
fi

echo "=========================================="
echo "Pod 诊断报告: $POD_NAME"
echo "命名空间: $NAMESPACE"
echo "=========================================="

echo -e "\n[1] Pod 基本信息"
kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o wide

echo -e "\n[2] Pod 详细状态"
kubectl describe pod "$POD_NAME" -n "$NAMESPACE"

echo -e "\n[3] 事件记录"
kubectl get events -n "$NAMESPACE" --field-selector=involvedObject.name="$POD_NAME" --sort-by='.lastTimestamp'

echo -e "\n[4] 日志 (最近 50 行)"
kubectl logs "$POD_NAME" -n "$NAMESPACE" --tail=50 2>/dev/null || echo "无法获取日志"

# 执行方式: 通过API Server获取集群组件状态
# 用途: 诊断集群组件健康状况
# 原理: 查询各组件的健康检查端点和状态信息
# 注意事项: 需要适当的API权限
# 风险说明: 一般检查操作无风险
```

---

## 15. 存储与CSI诊断命令

```bash
# 检查 PVC 状态
kubectl get pvc -A
kubectl describe pvc <pvc-name>

# 检查 PV 状态
kubectl get pv
kubectl describe pv <pv-name>

# 检查 VolumeAttachment
kubectl get volumeattachment
kubectl describe volumeattachment <name>

# 检查 CSINode
kubectl get csinode
kubectl describe csinode <node-name>

# 检查 CSI 驱动 Pod
kubectl get pods -n kube-system -l app=csi-controller
kubectl get pods -n kube-system -l app=csi-node

# 查看 CSI 驱动日志
kubectl logs -n kube-system -l app=csi-controller -c csi-driver
kubectl logs -n kube-system -l app=csi-controller -c csi-provisioner
kubectl logs -n kube-system -l app=csi-controller -c csi-attacher

# 查看 Node 端日志
kubectl logs -n kube-system -l app=csi-node -c csi-driver
kubectl logs -n kube-system -l app=csi-node -c node-driver-registrar

# 检查 kubelet 存储日志
journalctl -u kubelet | grep -i "volume\|csi\|mount"

# 检查节点上的挂载
kubectl debug node/<node-name> -it --image=busybox -- mount | grep csi

# 检查 CSI socket
kubectl debug node/<node-name> -it --image=busybox -- ls -la /var/lib/kubelet/plugins/

# 执行方式: 通过API Server和节点访问诊断存储问题
# 用途: 诊断持久化存储和CSI驱动问题
# 原理: 检查存储资源状态和CSI组件日志
# 注意事项: 需要适当权限访问系统命名空间
# 风险说明: 检查操作一般无风险，但挂载/卸载操作需谨慎
```

---

## 16. 包管理工具命令

### 16.1 Helm 命令

```bash
# 仓库管理
helm repo add NAME URL          # 添加仓库
helm repo update                # 更新索引
helm search repo KEYWORD        # 搜索 Chart

# Release 管理
helm install NAME CHART         # 安装
helm upgrade NAME CHART         # 升级
helm upgrade --install NAME     # 安装或升级
helm rollback NAME REVISION     # 回滚
helm uninstall NAME             # 卸载

# 调试
helm template NAME CHART        # 渲染模板
helm lint CHART                 # 语法检查
helm diff upgrade NAME CHART    # 对比差异 (需要helm-diff插件)

# 状态查看
helm list                       # 列出 Release
helm status NAME                # 查看状态
helm history NAME               # 查看历史
helm get values NAME            # 获取 Values

# 执行方式: 本地执行，与Tiller(旧版)/API Server(新版)交互
# 用途: 管理Kubernetes应用包
# 原理: 将Chart模板渲染为Kubernetes资源并应用
# 注意事项: 需要适当的RBAC权限
# 风险说明: 升级操作可能影响正在运行的应用
```

### 16.2 Kustomize 命令

```bash
# 构建
kustomize build DIR             # 构建 manifests
kubectl apply -k DIR            # 构建并应用
kubectl diff -k DIR             # 对比差异

# 编辑
kustomize edit set image        # 设置镜像
kustomize edit add resource     # 添加资源
kustomize edit set namespace    # 设置命名空间
kustomize edit add label        # 添加标签
kustomize edit add annotation   # 添加注解

# 生成资源
kustomize create --resources <resource-file>  # 创建kustomization.yaml

# 执行方式: 本地执行，处理YAML资源
# 用途: 无侵入式定制Kubernetes资源配置
# 原理: 使用kustomization.yaml定义对基础资源的修改
# 注意事项: 需要正确的目录结构和kustomization.yaml文件
# 风险说明: 无直接风险，但应用后会影响集群状态
```

---

## 17. 系统级运维命令

### 17.1 Linux 文件系统命令

```bash
# 挂载相关命令
mount -a                        # 挂载fstab中所有文件系统
mount /dev/sdb1 /data          # 挂载设备到目录
umount /data                   # 卸载文件系统

# 查看磁盘使用情况
df -h                           # 显示磁盘使用情况
du -sh /path                   # 显示目录大小
lsblk                          # 显示块设备信息

# 文件权限相关
ls -la file                    # 查看权限
chmod 755 file                 # 修改权限
chmod u+x file                 # 添加执行权限
chmod go-w file                # 移除写权限
chown user:group file          # 修改所有者
chown -R user:group dir/       # 递归修改所有者

# ACL 扩展权限
getfacl file                   # 查看 ACL
setfacl -m u:username:rwx file # 设置 ACL
setfacl -m g:groupname:rx file # 设置组 ACL
setfacl -x u:username file     # 删除 ACL
setfacl -b file                # 删除所有 ACL

# 执行方式: 在节点上执行
# 用途: 管理文件系统和权限
# 原理: 操作Linux文件系统和权限系统
# 注意事项: 需要适当的权限，修改系统文件需谨慎
# 风险说明: 错误的权限设置可能影响系统安全和功能
```

### 17.2 备份与恢复命令

```bash
# tar 备份命令
tar -czf backup.tar.gz /data            # 创建压缩备份
tar -tzf backup.tar.gz                 # 列出备份内容
tar -xzf backup.tar.gz                 # 解压备份
tar -g snapshot_file -czf inc_backup.tar.gz /data  # 增量备份

# rsync 同步命令
rsync -avz /source/ /destination/      # 基本同步
rsync -avz --delete /source/ /destination/  # 同步删除
rsync -avz --exclude='*.tmp' /source/ /destination/  # 排除特定文件
rsync -avz -e ssh /source/ user@remote:/destination/  # 远程同步
rsync --dry-run -avz /source/ /destination/  # 预览操作

# 执行方式: 在节点上执行
# 用途: 数据备份和同步
# 原理: 创建文件系统备份或同步数据
# 注意事项: 确保有足够的存储空间
# 风险说明: 备份可能包含敏感数据，需妥善保管
```

---

## 18. 紧急操作与故障恢复命令

### 18.1 紧急操作命令

```bash
# 紧急回滚
kubectl rollout undo deployment/<name>

# 紧急扩容
kubectl scale deployment/<name> --replicas=10

# 紧急停止 (缩容到 0)
kubectl scale deployment/<name> --replicas=0

# 强制删除卡住的 Pod
kubectl delete pod <name> --force --grace-period=0

# 紧急排空节点
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --force

# 紧急隔离节点
kubectl cordon <node>

# 查看 API Server 健康
kubectl get --raw='/healthz?verbose'

# 查看 etcd 健康 (需要访问权限)
kubectl get --raw='/healthz/etcd'

# 执行方式: 通过API Server执行紧急操作
# 用途: 处理紧急故障情况
# 原理: 直接修改集群状态
# 注意事项: 这些操作可能影响服务可用性
# 风险说明: 强制操作可能导致数据丢失或服务中断
```

### 18.2 Pod 故障诊断命令

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

# 日志聚合
stern <pod-pattern> -n <ns>
kubectl logs -l app=<label> --all-containers

# 执行方式: 通过API Server诊断Pod和服务
# 用途: 诊断各种资源故障
# 原理: 获取资源状态和事件信息
# 注意事项: 需要适当的权限查看资源
# 风险说明: 一般诊断操作无风险
```

---

## 19. 节点维护命令

### 19.1 节点维护命令

```bash
# 检查节点磁盘压力
kubectl describe node <node-name> | grep -A 5 "Allocated resources"

# 清理容器运行时
# 清理未使用镜像
crictl rmi --prune

# 清理已停止容器
crictl rm $(crictl ps -a -q)

# 检查PID压力
cat /proc/sys/kernel/pid_max
ps aux | wc -l

# 检查CNI状态
ls /etc/cni/net.d/
cat /etc/cni/net.d/*.conf

# 检查网络接口
ip addr
ip route

# 检查iptables
iptables -t nat -L -n | head -50
iptables -L -n | head -50

# 测试与API Server连接
curl -k https://<api-server>:6443/healthz

# 检查必需端口
ss -tlnp | grep -E "6443|10250|10251|10252"

# 执行方式: 在节点上执行系统命令
# 用途: 节点维护和故障排查
# 原理: 检查节点系统状态和网络配置
# 注意事项: 需要节点访问权限
# 风险说明: 系统级操作可能影响节点稳定性
```

---

## 20. 安全扫描与监控命令

### 20.1 安全扫描工具命令

```bash
# Trivy 镜像扫描
trivy image nginx:latest                    # 扫描镜像漏洞
trivy image --severity HIGH,CRITICAL nginx:latest  # 只显示高危和严重漏洞
trivy k8s cluster                           # 扫描集群安全配置
trivy config /path/to/manifests             # 扫描配置文件

# kube-bench 安全基线检查
kube-bench run                              # 运行所有检查
kube-bench run --targets master             # 检查Master节点
kube-bench run --targets node               # 检查Node节点
kube-bench run --targets etcd               # 检查etcd

# kube-hunter 漏洞扫描
kube-hunter                                 # 交互式扫描
kube-hunter --remote <cluster-ip>          # 远程扫描
kube-hunter --cidr <subnet>                # 子网扫描

# kubescan 安全评估
kubescan                                    # 运行安全评估

# NSA/CSS Kubernetes加固指南检查
kubectl get nodes -o yaml | grep -E "(podSecurity|admission)"

# 执行方式: 在本地或节点上执行安全扫描
# 用途: 识别安全漏洞和配置问题
# 原理: 扫描镜像、集群配置和运行时状态
# 注意事项: 扫描可能消耗资源，避免在高峰期运行
# 风险说明: 扫描本身一般无害，但可能暴露安全问题
```

### 20.2 Falco 运行时安全监控

```bash
# Falco 运行时安全监控
falco --help                               # 显示帮助
falco -r /etc/falco/rules.d/               # 加载规则目录
falco -V                                   # 验证规则文件

# Falcoctl 命令行工具
falcoctl rule add                          # 添加规则
falcoctl rule update                       # 更新规则
falcoctl version                           # 显示版本

# Sysdig 命令行工具
sysdig                                     # 启动 sysdig
sysdig -c "evt.type=execve chdir contains '/tmp'"  # 监控特定事件
sysdig -c "proc.name=nginx and fd.type=ipv4"      # 监控nginx网络活动

# 执行方式: 在节点上运行，监控系统调用
# 用途: 实时检测安全威胁
# 原理: 监控系统调用和内核事件
# 注意事项: 需要内核模块或eBPF支持
# 风险说明: 监控本身无害，但可能产生大量告警
```

---

## 21. 高级调试与排错命令

### 21.1 性能分析命令

```bash
# 节点性能分析
kubectl top nodes                          # 查看节点资源使用
kubectl top pods --all-namespaces        # 查看Pod资源使用
kubectl top pods --containers             # 查看容器资源使用

# 自定义指标查询
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods

# 资源容量分析
kubectl describe node <node-name> | grep -A 10 "Capacity\|Allocatable"

# Pod资源限制检查
kubectl describe pod <pod-name> | grep -A 5 "Limits\|Requests"

# 执行方式: 通过API Server获取性能指标
# 用途: 分析资源使用情况
# 原理: 从metrics-server获取资源使用数据
# 注意事项: 需要metrics-server运行
# 风险说明: 查询操作无风险
```

### 21.2 事件与日志分析

```bash
# 事件查询
kubectl get events -A --sort-by='.lastTimestamp'  # 按时间排序查看事件
kubectl get events --field-selector type=Warning  # 只查看警告事件
kubectl get events --field-selector involvedObject.name=<resource-name>  # 查看特定资源事件

# 事件监控
kubectl get events -A -w                        # 监控实时事件

# 自定义资源事件
kubectl events -A --types=Warning --sort-by='.lastTimestamp' | head -50

# 日志分析
kubectl logs <pod-name> --since=1h             # 查看最近1小时日志
kubectl logs <pod-name> --since-time='2024-01-01T10:00:00Z'  # 查看指定时间后日志
kubectl logs <pod-name> --max-log-requests=5    # 限制并发日志请求

# 批量日志查看
kubectl logs -l app=<app-name> --all-containers=true  # 查看带特定标签的所有Pod日志

# 执行方式: 通过API Server获取事件和日志
# 用途: 排查问题和监控集群状态
# 原理: 从etcd和容器运行时获取事件日志
# 注意事项: 大量日志可能影响性能
# 风险说明: 查询操作无风险
```

---

## 22. 总结

本文档提供了全面的Kubernetes命令行参考，涵盖从基础的kubectl命令到高级的故障排查、安全扫描和性能分析工具。每条命令都包含了执行方式、用途、原理、注意事项和风险说明，帮助用户更好地理解和使用这些工具。

### 22.1 使用建议

1. 在生产环境执行任何命令前，先在测试环境验证
2. 对于可能影响服务的操作，选择维护窗口执行
3. 定期备份重要配置和数据
4. 使用最小权限原则分配权限
5. 监控和记录所有操作的影响
6. 保持工具和集群版本的兼容性
7. 定期审查和更新安全配置

### 22.2 学习路径

1. 从kubectl基础命令开始学习
2. 熟悉资源管理和部署操作
3. 掌握故障排查和调试技巧
4. 了解安全和监控工具
5. 学习高级运维和优化技术

这份命令行清单旨在成为Kubernetes管理员和开发者的实用参考，随着技术的发展，将持续更新和完善。

## 23. 补充命令行信息

### 23.1 kubectl 高级命令

```bash
# kubectl events - 事件查询 (v1.26+ GA)
kubectl events                           # 查看当前命名空间事件
kubectl events -A                      # 查看所有命名空间事件
kubectl events --sort-by='.lastTimestamp' # 按时间排序
kubectl events --types=Warning         # 只看警告事件
kubectl events -w                      # 监视事件
kubectl events --for=pod/nginx         # 查看特定资源的事件

# kubectl api-resources - API 资源查询
kubectl api-resources                  # 列出所有 API 资源
kubectl api-resources --verbs=list,get # 列出支持特定动作的资源
kubectl api-resources --namespaced=true # 列出 namespaced 资源
kubectl api-resources --api-group=apps  # 列出特定 API 组资源
kubectl api-resources -o wide          # 输出宽格式

# kubectl explain - API 文档查询
kubectl explain pod.spec              # 查看 Pod spec 字段
kubectl explain pod.spec.containers   # 查看容器字段
kubectl explain deployment --api-version=apps/v1 # 查看特定 API 版本
kubectl explain pod.spec --recursive  # 递归显示所有字段

# kubectl run 高级用法
kubectl run nginx --image=nginx:1.25 --port=80     # 创建并暴露端口
kubectl run debug --image=busybox --rm -it --restart=Never -- sh # 创建临时调试 Pod
kubectl run myapp --image=busybox --restart=Never -- sleep 3600 # 使用自定义命令
kubectl run nginx --image=nginx:1.25 \
  --requests='cpu=100m,memory=128Mi' \
  --limits='cpu=200m,memory=256Mi'    # 指定资源限制
kubectl run myapp --image=myapp:latest \
  --env="DB_HOST=mysql" \
  --env="DB_PORT=3306"               # 指定环境变量
kubectl run nginx --image=nginx:1.25 --labels="app=nginx,env=prod" # 指定标签
kubectl run debug --image=alpine --restart=Never --command -- tail -f /dev/null # 覆盖 entrypoint

# kubectl expose - 服务暴露
kubectl expose deployment nginx --type=NodePort --port=80     # 暴露为 NodePort
kubectl expose deployment nginx --type=LoadBalancer --port=80 # 暴露为 LoadBalancer
kubectl expose deployment nginx --name=nginx-svc --port=80    # 指定服务名
kubectl expose pod nginx --port=80                            # 暴露 Pod
kubectl expose deployment nginx --port=80 --selector='app=nginx,version=v1' # 指定 selector

# kubectl wait - 等待条件
kubectl wait --for=condition=Ready pod/nginx --timeout=60s      # 等待 Pod Ready
kubectl wait --for=condition=Ready pod --all --timeout=120s    # 等待所有 Pod Ready
kubectl wait --for=condition=Available deployment/nginx --timeout=120s # 等待 Deployment 可用
kubectl wait --for=condition=Complete job/myjob --timeout=300s  # 等待 Job 完成
kubectl wait --for=delete pod/nginx --timeout=60s             # 等待删除完成
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/nginx # 使用 JSONPath 条件

# kubectl proxy - API 代理
kubectl proxy                        # 启动 API 代理
kubectl proxy --port=8001           # 指定端口
kubectl proxy --address=0.0.0.0 --accept-hosts='.*' # 监听所有接口

# 执行方式: 本地执行，通过API Server获取数据
# 用途: 查询API资源、暴露服务、等待条件等
# 原理: 通过API Server与etcd通信获取或修改资源状态
# 注意事项: 需要相应的RBAC权限
# 风险说明: 某些操作如删除、修改配置可能存在风险
```

### 23.2 容器运行时命令

```bash
# runc 基本操作
runc create mycontainer              # 创建容器
runc start mycontainer               # 启动容器
runc state mycontainer               # 查看容器状态
runc exec mycontainer /bin/sh        # 执行命令
runc kill mycontainer SIGTERM       # 发送信号
runc delete mycontainer              # 删除容器
runc checkpoint --image-path=/tmp/checkpoint mycontainer # 检查点
runc restore --image-path=/tmp/checkpoint mycontainer-restored # 恢复

# crun 安装和使用
dnf install crun                     # Fedora/RHEL 安装
crun --version                       # 查看版本
crun --systemd-cgroup run mycontainer # 使用 systemd cgroup

# youki 安装和使用
cargo install youki                  # 安装 youki
youki --help                         # 帮助信息
youki create mycontainer             # 创建容器
youki start mycontainer              # 启动容器
youki state mycontainer              # 查看状态
youki delete mycontainer             # 删除容器

# gVisor (runsc) 安装和使用
wget https://storage.googleapis.com/gvisor/releases/release/latest/x86_64/runsc
curl -fsSL https://gvisor.dev/install.sh | bash
runsc --help                         # 帮助信息

# Kata Containers 配置
kata-runtime kata-check              # 检查 Kata 配置

# ctr - containerd 原生 CLI
ctr -n k8s.io images ls             # 在 k8s.io 命名空间操作
ctr images pull docker.io/library/nginx:latest # 拉取镜像
ctr run -d --rm docker.io/library/nginx:latest nginx # 运行容器
ctr tasks exec --exec-id exec1 nginx sh # 执行命令
ctr tasks logs nginx                 # 查看容器日志

# nerdctl - Docker 兼容的 CLI
nerdctl run -d --name nginx -p 80:80 nginx:latest # 运行容器
nerdctl ps                           # 查看容器
nerdctl logs nginx                   # 查看日志
nerdctl exec -it nginx sh           # 执行命令
nerdctl stop nginx                   # 停止容器
nerdctl rm nginx                     # 删除容器

# crictl - CRI 调试工具
crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps # 列出容器
crictl pods                         # 列出 Pod
crictl images                       # 列出镜像
crictl logs <container-id>          # 查看容器日志
crictl exec -it <container-id> sh   # 执行命令
crictl stats                        # 查看统计信息
crictl info                         # 查看信息
crictl pull <image>                 # 拉取镜像
crictl rmi <image>                  # 删除镜像
crictl inspect <container-id>       # 查看容器详情
crictl inspectp <pod-id>            # 查看 Pod 详情
crictl ps -a                        # 列出所有容器

# containerd 配置检查
containerd config dump              # 检查运行时配置

# 检查 shim 进程
ps aux | grep containerd-shim       # 检查 containerd-shim 进程
ps aux | grep conmon                # 检查 conmon 进程 (CRI-O)

# 检查 cgroup
ls /sys/fs/cgroup/memory/kubepods/* # 查看内存 cgroup
ls /sys/fs/cgroup/cpu/kubepods/*    # 查看 CPU cgroup

# 检查 overlay 挂载
mount | grep overlay                 # 检查 overlay 挂载
cat /proc/<container-pid>/mountinfo  # 查看挂载信息

# 执行方式: 在节点上直接执行容器运行时工具
# 用途: 调试容器运行时问题、查看容器状态、管理镜像等
# 原理: 直接与容器运行时交互，绕过 kubelet
# 注意事项: 需要在节点上执行，需要相应权限
# 风险说明: 直接操作容器可能影响 Pod 状态
```

### 23.3 CLI 增强工具

```bash
# kubectx / kubens 快速切换
kubectx                              # 列出所有上下文
kubectx production                   # 切换上下文
kubectx -                            # 切换回上一个上下文
kubens                               # 列出所有命名空间
kubens kube-system                   # 切换命名空间

# 别名配置
alias kx='kubectx'
alias kn='kubens'

# kube-capacity 资源余量
kube-capacity                        # 查看所有节点
kube-capacity --sort cpu.util        # 按节点分组
kube-capacity --pods                 # 查看 Pod 级别
kube-capacity -o json                # 输出 JSON

# kubectl-tree 资源依赖
kubectl tree deployment myapp        # 查看 Deployment 依赖
kubectl tree statefulset mysql       # 查看 StatefulSet 依赖

# kubectl-neat 清理输出
kubectl get pod myapp -o yaml | kubectl neat # 清理 YAML 输出
kubectl get deployment myapp -o yaml | kubectl neat > myapp-clean.yaml # 清理并保存

# kubectl 别名
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kdel='kubectl delete'
alias kl='kubectl logs'
alias kex='kubectl exec -it'
alias kaf='kubectl apply -f'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods --all-namespaces'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'

# 实用函数
ksh() { kubectl exec -it $1 -- /bin/bash; } # 快速进入 Pod Shell
klog() { kubectl logs -f $1; }              # 快速查看 Pod 日志
kdele() { kubectl get pods --all-namespaces | grep Evicted | awk '{print $2, "-n", $1}' | xargs kubectl delete pod; } # 快速删除 Evicted Pod

# kubectl 插件管理 (Krew)
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
) # 安装 Krew

# 推荐插件
kubectl krew install ctx             # kubectx
kubectl krew install ns              # kubens
kubectl krew install tree            # 资源树
kubectl krew install neat            # YAML 清理
kubectl krew install capacity        # 容量查看
kubectl krew install debug           # 调试工具
kubectl krew install tail            # 日志追踪

# 执行方式: 本地执行，增强kubectl功能
# 用途: 提高kubectl使用效率，简化常见操作
# 原理: 通过插件机制扩展kubectl功能
# 注意事项: 需要额外安装工具
# 风险说明: 一般较低，但插件可能存在安全风险
```

### 23.4 生产环境运维脚本

```bash
# 集群健康检查脚本
kubectl cluster-info                 # 集群基本信息
kubectl get nodes -o wide            # 节点状态
kubectl top nodes 2>/dev/null || echo "Metrics server 未安装" # 节点资源使用
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l # 非正常 Pod 数量
kubectl get events -A --field-selector=type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -20 # 最近警告事件

# Pod 诊断脚本
kubectl get pod <pod-name> -n <namespace> -o jsonpath='status.phase' # Pod 状态
kubectl get pod <pod-name> -n <namespace> -o jsonpath='spec.nodeName' # Pod 所在节点
kubectl get pod <pod-name> -n <namespace> -o jsonpath='status.podIP'  # Pod IP
kubectl get pod <pod-name> -n <namespace> -o jsonpath='status.qosClass' # Pod QoS
kubectl get pod <pod-name> -n <namespace> -o jsonpath='status.startTime' # 启动时间
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{range .status.containerStatuses[*]}{.name}{"\t"}{.ready}{"\t"}{.restartCount}{"\n"}{end}' # 容器状态

# 资源清理脚本
kubectl delete jobs --field-selector=status.successful=1 -A 2>/dev/null # 清理已完成的 Job
kubectl delete pods --field-selector=status.phase==Failed -A 2>/dev/null # 清理 Failed Pod
kubectl get pods -A | grep Evicted | awk '{print $2 " -n " $1}' | while read line; do kubectl delete pod $line 2>/dev/null; done # 清理 Evicted Pod
kubectl delete pods --field-selector=status.phase==Succeeded -A 2>/dev/null # 清理已完成的 Pod

# 紧急操作
kubectl scale deployment/<name> --replicas=0 # 紧急停止 (缩容到 0)
kubectl delete pod <name> --force --grace-period=0 # 强制删除卡住的 Pod
kubectl cordon <node>              # 紧急隔离节点
kubectl get --raw='/healthz?verbose' # 查看 API Server 健康

# 执行方式: 通过kubectl与API Server交互
# 用途: 自动化运维、批量操作、紧急处理
# 原理: 基于kubectl命令组合实现复杂操作
# 注意事项: 需要适当的权限和小心验证
# 风险说明: 自动化脚本可能产生意外结果
```

### 23.5 故障排查工具命令

```bash
# K9s 安装与使用
# macOS 安装
brew install derailed/k9s/k9s

# Linux 安装
curl -sS https://webinstall.dev/k9s | bash

# 或从GitHub下载
K9S_VERSION="v0.31.7"
wget https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz
tar -xzf k9s_Linux_amd64.tar.gz
sudo mv k9s /usr/local/bin/

# K9s 快捷键
:pod                           # 切换到Pod视图
:ns                            # 切换到Namespace视图
:dp                            # 切换到Deployment视图
:svc                           # 切换到Service视图
:no                            # 切换到Node视图
/                             # 过滤资源
Esc                           # 返回/取消过滤
Enter                         # 查看详情/进入
d                             # Describe资源
y                             # 查看YAML
l                             # 查看日志
s                             # 进入Shell
e                             # 编辑资源
Ctrl-D                        # 删除资源
Ctrl-K                        # 强制删除
0                             # 查看所有容器日志
1-9                           # 查看指定容器日志
w                             # 切换自动换行
t                             # 切换显示时间戳
f                             # 全屏日志
Ctrl-S                        # 保存日志
?                             # 帮助
:q                            # 退出
:ctx                          # 切换Context
Ctrl-A                        # 查看所有命名空间

# Netshoot 网络诊断工具
kubectl run netshoot --rm -it \
    --image=nicolaka/netshoot \
    --restart=Never \
    -- bash                      # 临时Pod

kubectl debug -it <pod-name> \
    --image=nicolaka/netshoot \
    --target=<container-name> \
    -- bash                      # Ephemeral Container

# Netshoot 诊断命令
dslookup kubernetes.default        # 基本DNS查询
dig kubernetes.default.svc.cluster.local # 详细DNS查询
cat /etc/resolv.conf            # 查看DNS配置
ping -c 3 <pod-ip>             # Ping测试
curl -v http://myservice:80/healthz # HTTP请求测试
ip route                       # 查看路由表
traceroute <target-ip>          # 路由追踪
ip addr                        # 查看网络接口
arp -n                         # 查看ARP表
iptables -L -n -v             # 查看iptables规则
tcpdump -i eth0 -n             # 基本抓包
tcpdump -i eth0 -nn port 80     # 抓取特定端口
nslookup myservice.production   # DNS测试

# kubectl-debug 插件
kubectl krew install debug       # 安装debug插件
kubectl debug -it <pod-name> \
    --image=busybox \
    --target=<container-name>    # 基本调试

kubectl debug -it <pod-name> \
    --image=nicolaka/netshoot \
    --target=<container-name> \
    -- bash                      # 使用Netshoot调试

kubectl debug <pod-name> \
    --copy-to=<pod-name>-debug \
    --container=debug \
    --image=busybox \
    -- sleep infinity            # 复制Pod并添加调试容器

# Stern 多Pod日志工具
brew install stern              # macOS安装
stern myapp                     # 查看匹配名称的所有Pod日志
stern -n production myapp       # 指定命名空间
stern --all-namespaces myapp    # 所有命名空间
stern -l app=nginx             # 按标签过滤
stern --container "^main$" myapp  # 按容器名过滤
stern --since 1h myapp         # 最近1小时
stern --output json myapp       # JSON输出
stern --timestamps myapp        # 带时间戳

# Telepresence 本地调试
brew install datawire/blackbird/telepresence # 安装
telepresence connect             # 连接到集群
telepresence status              # 查看状态
telepresence list                # 列出可拦截的服务
telepresence quit                # 断开连接
telepresence intercept myservice --port 8080:80 # 全局拦截
telepresence intercept myservice \
    --port 8080:80 \
    --http-header x-telepresence-intercept-id=my-intercept # 个人拦截

# 执行方式: 本地执行或在Pod中执行
# 用途: 网络诊断、多Pod日志查看、本地开发调试等
# 原理: 通过不同工具提供特定功能
# 注意事项: 需要适当的权限和网络连通性
# 风险说明: 一般较低，但某些网络诊断可能影响性能

### 23.6 安全与认证命令补充

```bash
# Service Account Token 创建 (v1.24+)
kubectl create token <service-account-name>    # 创建 ServiceAccount Token
kubectl create token <sa-name> --duration=24h  # 指定过期时间
kubectl create token <sa-name> --audience=api   # 指定 audience
kubectl create token <sa-name> --bound-object-kind=Pod --bound-object-name=<pod-name> # 绑定到特定 Pod

# Pod 安全标准 (PSS) 相关
kubectl label namespace <ns> pod-security.kubernetes.io/enforce=restricted # 强制使用受限策略
kubectl label namespace <ns> pod-security.kubernetes.io/audit=restricted # 审计受限策略
kubectl label namespace <ns> pod-security.kubernetes.io/warn=restricted  # 警告受限策略

# 执行方式: 本地执行，通过API Server操作
# 用途: 安全认证、访问控制等
# 原理: 通过Kubernetes认证授权机制
# 注意事项: 需要适当的权限
# 风险说明: 不当的权限分配可能造成安全风险

### 23.7 容器运行时配置与管理

```bash
# containerd 配置管理
containerd config default > /etc/containerd/config.toml  # 生成默认配置
systemctl restart containerd                           # 重启 containerd
systemctl enable containerd                            # 开机自启

# containerd 配置检查
containerd config dump                                # 检查当前配置

# CRI-O 安装和配置
yum install cri-o                                    # 安装 CRI-O
systemctl start crio                                   # 启动 CRI-O
systemctl enable crio                                  # 开机自启
crio-status info                                       # CRI-O 状态检查

# Podman 容器管理 (与 CRI-O 共享库)
podman run -d --name nginx nginx:latest               # 运行容器
podman ps                                             # 查看容器
podman logs nginx                                     # 查看日志
podman exec -it nginx sh                              # 执行命令
podman stop nginx                                     # 停止容器
podman rm nginx                                       # 删除容器

# Skopeo 镜像工具
skopeo copy docker://docker.io/library/nginx:latest oci:nginx:latest # 镜像复制
skopeo inspect docker://docker.io/library/nginx:latest # 检查镜像
skopeo list-tags docker://docker.io/library/nginx     # 列出标签

# Buildah 镜像构建
buildah from nginx:latest                             # 从基础镜像创建
buildah run nginx-working-container -- apt-get update # 运行命令
buildah commit nginx-working-container my-nginx:latest # 提交镜像

# 检查运行时状态
systemctl status containerd                           # 检查 containerd 状态
systemctl status crio                                 # 检查 CRI-O 状态

# 运行时切换配置
# 更新 kubelet 配置
KUBELET_KUBEADM_ARGS="--container-runtime-endpoint=unix:///run/containerd/containerd.sock" # containerd
KUBELET_KUBEADM_ARGS="--container-runtime-endpoint=unix:///var/run/crio/crio.sock" # CRI-O

# 验证运行时
kubectl get nodes -o wide                           # 查看运行时版本

# 执行方式: 在节点上执行系统命令
# 用途: 容器运行时管理、配置、故障排查
# 原理: 直接操作容器运行时服务
# 注意事项: 需要节点访问权限，操作可能影响集群稳定性
# 风险说明: 错误配置可能导致节点不可用

### 23.8 高级 kubectl 功能

```bash
# kubectl patch 高级用法
kubectl patch deployment nginx --type='json' -p='[{"op":"replace","path":"/spec/replicas","value":5}]' # JSON Patch
kubectl patch deployment nginx --type='merge' -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","image":"nginx:1.26"}]}}}}' # Merge Patch
kubectl patch deployment nginx --subresource=status -p '{"status":{"readyReplicas":3}}' # 子资源补丁

# kubectl set 高级用法
kubectl set resources deployment/nginx --limits=cpu=500m,memory=512Mi --requests=cpu=100m,memory=128Mi # 设置资源
kubectl set selector service nginx 'app=nginx,version=v2' # 设置 selector
kubectl set subject rolebinding admin --user=alice --group=developers # 设置 subject

# kubectl apply 高级用法
kubectl apply --server-side -f deployment.yaml --field-manager=my-controller # 服务端 Apply 指定字段管理器
kubectl apply --server-side --force-conflicts -f deployment.yaml # 强制冲突处理

# kubectl autoscale 高级用法
kubectl autoscale deployment nginx --min=2 --max=10 --cpu-percent=80 --memory-percent=70 # 多指标 HPA

# kubectl config 高级用法
kubectl config set-credentials new-user --token=<token> # 设置用户 Token
kubectl config set-cluster new-cluster --server=https://k8s-api.example.com:6443 --certificate-authority=/path/to/ca.crt # 设置集群
kubectl config view --flatten # 查看合并后的配置
kubectl config view --minify # 查看当前上下文的配置

# kubectl explain 高级用法
kubectl explain pod.spec --recursive # 递归显示所有字段
kubectl explain pod.spec.containers --output=plaintext-openapiv2 # OpenAPI v3 输出

# kubectl api-resources 高级用法
kubectl api-resources --verbs=list,get # 列出支持特定动作的资源
kubectl api-resources --namespaced=true # 列出 namespaced 资源
kubectl api-resources --api-group=apps # 列出特定 API 组资源
kubectl api-resources --sort-by=name # 按资源名排序

# 执行方式: 本地执行，通过API Server操作
# 用途: 高级资源管理、配置、自动化
# 原理: 通过API Server与etcd交互
# 注意事项: 需要适当的RBAC权限
# 风险说明: 不当操作可能影响集群稳定性和安全性

### 23.9 高级调试与监控命令

```bash
# kubectl debug profile 使用
kubectl debug -it <pod-name> --image=busybox --profile=general # 通用调试
kubectl debug -it <pod-name> --image=busybox --profile=baseline # 基线安全调试
kubectl debug -it <pod-name> --image=busybox --profile=restricted # 严格安全调试
kubectl debug -it <pod-name> --image=busybox --profile=netadmin # 网络调试
kubectl debug -it <pod-name> --image=busybox --profile=sysadmin # 系统调试

# 节点调试
kubectl debug node/<node-name> -it --image=ubuntu # 调试节点
# 在调试 Pod 中: chroot /host # 访问主机文件系统

# 共享进程命名空间调试
kubectl debug <pod-name> -it --image=busybox --share-processes # 共享进程命名空间

# 镜像和存储相关
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' # 获取所有镜像
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' # 获取所有节点 IP
kubectl get secrets -A -o jsonpath='{range .items[?(@.type!="kubernetes.io/service-account-token")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' # 获取非 SA Token 的 Secrets

# 高级日志命令
kubectl logs -l app=nginx --since=1h --tail=100 --timestamps # 带时间戳的最近日志
kubectl logs -f -l app=nginx --max-log-requests=5 # 限制并发日志请求

# 高级事件命令
kubectl get events -A --field-selector=type=Warning --sort-by='.lastTimestamp' --watch # 实时监控警告事件

# 性能相关命令
kubectl top pods --containers --sort-by=cpu # 按 CPU 使用率排序的 Pod 容器
kubectl top nodes --sort-by=memory # 按内存使用率排序的节点

# 高级查询命令
kubectl get pods -A --field-selector=status.phase!=Running # 非运行状态的 Pod
kubectl get pods -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName' # 自定义列
kubectl get pods -l 'app in (nginx,apache)' # 标签 in 查询
kubectl get pods -l 'env notin (dev,test)' # 标签 notin 查询

# 执行方式: 本地执行，通过API Server获取数据
# 用途: 高级调试、性能分析、监控
# 原理: 通过API Server查询etcd中的资源信息
# 注意事项: 需要适当的RBAC权限
# 风险说明: 查询操作一般无风险，但大量查询可能影响API Server性能
```

## 24. 容器运行时配置与管理

### 24.1 容器运行时配置命令

```bash
# containerd 配置管理
containerd config default > /etc/containerd/config.toml  # 生成默认配置
systemctl restart containerd                           # 重启 containerd
systemctl enable containerd                            # 开机自启

# containerd 配置检查
containerd config dump                                # 检查当前配置

# CRI-O 安装和配置
yum install cri-o                                    # 安装 CRI-O
systemctl start crio                                   # 启动 CRI-O
systemctl enable crio                                  # 开机自启
crio-status info                                       # CRI-O 状态检查

# Podman 容器管理 (与 CRI-O 共享库)
podman run -d --name nginx nginx:latest               # 运行容器
podman ps                                             # 查看容器
podman logs nginx                                     # 查看日志
podman exec -it nginx sh                              # 执行命令
podman stop nginx                                     # 停止容器
podman rm nginx                                       # 删除容器

# Skopeo 镜像工具
skopeo copy docker://docker.io/library/nginx:latest oci:nginx:latest # 镜像复制
skopeo inspect docker://docker.io/library/nginx:latest # 检查镜像
skopeo list-tags docker://docker.io/library/nginx     # 列出标签

# Buildah 镜像构建
buildah from nginx:latest                             # 从基础镜像创建
buildah run nginx-working-container -- apt-get update # 运行命令
buildah commit nginx-working-container my-nginx:latest # 提交镜像

# 检查运行时状态
systemctl status containerd                           # 检查 containerd 状态
systemctl status crio                                 # 检查 CRI-O 状态

# 运行时切换配置
# 更新 kubelet 配置
KUBELET_KUBEADM_ARGS="--container-runtime-endpoint=unix:///run/containerd/containerd.sock" # containerd
KUBELET_KUBEADM_ARGS="--container-runtime-endpoint=unix:///var/run/crio/crio.sock" # CRI-O

# 验证运行时
kubectl get nodes -o wide                           # 查看运行时版本

# 执行方式: 在节点上执行系统命令
# 用途: 容器运行时管理、配置、故障排查
# 原理: 直接操作容器运行时服务
# 注意事项: 需要节点访问权限，操作可能影响集群稳定性
# 风险说明: 错误配置可能导致节点不可用
```

### 24.2 crictl 命令参考

```bash
# crictl 基础命令
crictl ps -a                           # 列出所有容器
crictl pods                            # 列出 Pod
crictl images                          # 列出镜像
crictl pull nginx:latest               # 拉取镜像
crictl logs <container-id>             # 查看容器日志
crictl exec -it <container-id> sh      # 执行命令
crictl inspect <container-id>          # 检查容器
crictl rmi <image>                     # 删除镜像
crictl rm <container-id>               # 删除容器
crictl stats                           # 资源统计

# crictl 配置
cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

# 执行方式: 在节点上直接执行，通过CRI接口与容器运行时通信
# 用途: 调试容器运行时问题，查看容器状态
# 原理: 直接与容器运行时交互，绕过kubelet
# 注意事项: 需要在节点上执行，需要相应权限
# 风险说明: 直接操作容器可能影响Pod状态
```

### 24.3 容器运行时性能对比

| 指标 | containerd | CRI-O | Docker(历史) |
|-----|-----------|-------|-------------|
| **启动延迟** | ~300ms | ~350ms | ~500ms |
| **内存开销** | ~50MB | ~40MB | ~100MB |
| **CPU开销** | 低 | 低 | 中 |
| **镜像拉取** | 快 | 快 | 中 |
| **并发容器** | 高 | 高 | 中 |

### 24.4 安全运行时配置

| 运行时 | 隔离级别 | 原理 | 适用场景 | 性能开销 |
|-------|---------|------|---------|---------|
| **runc** | 命名空间 | Linux NS | 默认 | 无 |
| **gVisor(runsc)** | 用户空间内核 | 系统调用拦截 | 不可信代码 | 20-50% |
| **Kata** | 轻量VM | QEMU/Firecracker | 多租户 | 10-30% |

```yaml
# RuntimeClass配置
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
overhead:
  podFixed:
    memory: "120Mi"
    cpu: "250m"
scheduling:
  nodeSelector:
    runtime: gvisor
---
# 使用RuntimeClass的Pod
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  runtimeClassName: gvisor  # 使用gVisor运行时
  containers:
  - name: app
    image: nginx
```

### 24.5 从Docker迁移到containerd

| 步骤 | 操作 | 命令 |
|-----|------|------|
| 1 | 安装containerd | `apt install containerd` |
| 2 | 配置containerd | 编辑config.toml |
| 3 | 配置kubelet | `--container-runtime-endpoint=unix:///run/containerd/containerd.sock` |
| 4 | 重启kubelet | `systemctl restart kubelet` |
| 5 | 验证 | `crictl info` |

```bash
# Docker到containerd迁移检查
# 1. 停止kubelet
systemctl stop kubelet

# 2. 停止docker
systemctl stop docker

# 3. 配置containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
# 编辑config.toml设置SystemdCgroup = true

# 4. 启动containerd
systemctl enable --now containerd

# 5. 修改kubelet配置
# /var/lib/kubelet/kubeadm-flags.env
# 添加: --container-runtime-endpoint=unix:///run/containerd/containerd.sock

# 6. 启动kubelet
systemctl start kubelet

# 7. 验证
crictl info
kubectl get nodes

# 执行方式: 在节点上执行系统命令
# 用途: 从Docker迁移到containerd运行时
# 原理: 替换容器运行时后更新Kubernetes配置
# 注意事项: 迁移前确保有备份和回滚方案
# 风险说明: 迁移过程可能导致节点暂时不可用
```


## 总结

本文档提供了全面的Kubernetes命令行参考，涵盖从基础的kubectl命令到高级的故障排查、安全扫描和性能分析工具。每条命令都包含了执行方式、用途、原理、注意事项和风险说明，帮助用户更好地理解和使用这些工具。

### 使用建议

1. 在生产环境执行任何命令前，先在测试环境验证
2. 对于可能影响服务的操作，选择维护窗口执行
3. 定期备份重要配置和数据
4. 使用最小权限原则分配权限
5. 监控和记录所有操作的影响
6. 保持工具和集群版本的兼容性
7. 定期审查和更新安全配置

### 学习路径

1. 从kubectl基础命令开始学习
2. 熟悉资源管理和部署操作
3. 掌握故障排查和调试技巧
4. 了解安全和监控工具
5. 学习高级运维和优化技术

这份命令行清单旨在成为Kubernetes管理员和开发者的实用参考，随着技术的发展，将持续更新和完善。
 
 # #   2 5 .   '`��R�gNEe���c�g�]wQ}T�N
 
 
 
 # # #   2 5 . 1   I n s p e k t o r   G a d g e t   e B P F R�g�]wQ
 
 
 
 `  a s h 
 
 #   �[ň  k u b e c t l - g a d g e t   �c�N
 
 k u b e c t l   k r e w   i n s t a l l   g a d g e t 
 
 k u b e c t l   g a d g e t   d e p l o y 
 
 
 
 #   �����[ň
 
 k u b e c t l   g a d g e t   v e r s i o n 
 
 k u b e c t l   g e t   p o d s   - n   g a d g e t 
 
 
 
 #   �gw�S(u  G a d g e t s 
 
 k u b e c t l   g a d g e t   l i s t - g a d g e t s 
 
 ` 
 
 
 
 # #   2 5 .   '`��R�gNEe���c�g�]wQ}T�N
 
 
 
 # # #   2 5 . 1   I n s p e k t o r   G a d g e t   e B P F R�g�]wQ
 
 
 
 `  a s h 
 
 #   �[ň  k u b e c t l - g a d g e t   �c�N
 
 k u b e c t l   k r e w   i n s t a l l   g a d g e t 
 
 k u b e c t l   g a d g e t   d e p l o y 
 
 
 
 #   �����[ň
 
 k u b e c t l   g a d g e t   v e r s i o n 
 
 k u b e c t l   g e t   p o d s   - n   g a d g e t 
 
 
 
 #   �gw�S(u  G a d g e t s 
 
 k u b e c t l   g a d g e t   l i s t - g a d g e t s 
 
 ` 
 
 
