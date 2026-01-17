# 表格5：kubectl命令表

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/reference/kubectl](https://kubernetes.io/docs/reference/kubectl/)

## 资源查看命令

| 命令 | 语法 | 描述 | 常用选项/标志 | 版本支持/变更 | 生产场景示例 |
|-----|------|------|-------------|--------------|-------------|
| **get** | `kubectl get <resource> [name]` | 列出资源 | `-o wide/yaml/json`, `-l`, `-A`, `--show-labels` | 稳定; v1.27+增强输出 | `kubectl get pods -A -o wide` 查看所有Pod分布 |
| **describe** | `kubectl describe <resource> <name>` | 显示详细信息 | `--show-events` | 稳定 | `kubectl describe pod <name>` 排查Pod问题 |
| **logs** | `kubectl logs <pod> [-c container]` | 查看容器日志 | `-f`, `--tail`, `--since`, `-p`, `--all-containers` | v1.27+流日志优化 | `kubectl logs -f <pod> --tail=100` 实时跟踪 |
| **top** | `kubectl top nodes/pods` | 显示资源使用 | `--containers`, `--sort-by` | 需Metrics Server | `kubectl top pods -A --sort-by=cpu` 找高CPU |
| **events** | `kubectl events` | 查看事件 | `--for`, `--types`, `-A` | v1.26+独立命令 | `kubectl events --for pod/<name>` 查看Pod事件 |
| **api-resources** | `kubectl api-resources` | 列出API资源 | `-o wide`, `--namespaced` | 稳定 | 检查集群支持的资源类型 |
| **api-versions** | `kubectl api-versions` | 列出API版本 | - | 稳定 | 升级前检查API版本支持 |
| **cluster-info** | `kubectl cluster-info [dump]` | 集群信息 | `dump` 导出诊断 | 稳定 | `kubectl cluster-info dump` 收集诊断信息 |

## 资源创建与管理命令

| 命令 | 语法 | 描述 | 常用选项/标志 | 版本支持/变更 | 生产场景示例 |
|-----|------|------|-------------|--------------|-------------|
| **apply** | `kubectl apply -f <file/dir/url>` | 声明式应用配置 | `-R`, `--prune`, `--server-side` | v1.22+ Server-side Apply GA | `kubectl apply -f manifests/ -R` 部署应用 |
| **create** | `kubectl create <resource>` | 命令式创建资源 | `--dry-run=client/server`, `-o yaml` | 稳定 | `kubectl create ns <name>` 创建命名空间 |
| **delete** | `kubectl delete <resource> <name>` | 删除资源 | `--force`, `--grace-period`, `--cascade` | v1.27+ foreground级联 | `kubectl delete pod <name> --force` 强制删除 |
| **edit** | `kubectl edit <resource> <name>` | 编辑资源 | `--save-config` | 稳定 | 临时修改配置(不推荐生产使用) |
| **replace** | `kubectl replace -f <file>` | 替换资源 | `--force` | 稳定 | 完全替换资源配置 |
| **patch** | `kubectl patch <resource> <name>` | 部分更新资源 | `--type=merge/strategic/json` | 稳定 | `kubectl patch deploy <name> -p '{"spec":{"replicas":3}}'` |
| **label** | `kubectl label <resource> <name>` | 添加/更新标签 | `--overwrite`, `-l` | 稳定 | `kubectl label nodes <name> env=prod` |
| **annotate** | `kubectl annotate <resource> <name>` | 添加/更新注解 | `--overwrite` | 稳定 | 添加运维元数据 |
| **scale** | `kubectl scale <resource> <name>` | 调整副本数 | `--replicas`, `--current-replicas` | 稳定 | `kubectl scale deploy <name> --replicas=5` |

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
| **autoscale** | `kubectl autoscale <resource>` | 创建HPA | `--min`, `--max`, `--cpu-percent` | 稳定 | 配置自动扩缩容 |

## 调试与排查命令

| 命令 | 语法 | 描述 | 常用选项/标志 | 版本支持/变更 | 生产场景示例 |
|-----|------|------|-------------|--------------|-------------|
| **exec** | `kubectl exec <pod> -- <cmd>` | 在容器中执行命令 | `-it`, `-c` | 稳定 | `kubectl exec -it <pod> -- /bin/sh` 进入容器 |
| **debug** | `kubectl debug <pod/node>` | 创建调试容器 | `--image`, `--target`, `--copy-to` | v1.25+ GA | `kubectl debug -it <pod> --image=busybox` |
| **port-forward** | `kubectl port-forward <pod> <ports>` | 端口转发 | `--address` | 稳定 | `kubectl port-forward svc/<name> 8080:80` 本地访问 |
| **cp** | `kubectl cp <src> <dest>` | 复制文件 | `-c` | 稳定 | 从容器拷贝日志文件 |
| **attach** | `kubectl attach <pod> -c <container>` | 附加到运行容器 | `-it` | 稳定 | 附加到stdin |
| **run** | `kubectl run <name> --image=<image>` | 运行临时Pod | `--rm`, `-it`, `--restart=Never` | 稳定 | `kubectl run test --rm -it --image=busybox -- sh` |
| **proxy** | `kubectl proxy` | 运行API代理 | `--port` | 稳定 | 本地访问Dashboard |
| **auth can-i** | `kubectl auth can-i <verb> <resource>` | 检查权限 | `--as`, `--list` | 稳定 | `kubectl auth can-i create pods` 权限验证 |
| **auth whoami** | `kubectl auth whoami` | 显示当前身份 | - | v1.27+ | 确认当前认证身份 |

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

## 插件与扩展命令

| 命令 | 语法 | 描述 | 常用选项/标志 | 版本支持/变更 | 生产场景示例 |
|-----|------|------|-------------|--------------|-------------|
| **krew** | `kubectl krew install <plugin>` | 插件管理器 | `search`, `list`, `update` | 外部工具 | 安装kubectl插件 |
| **convert** | `kubectl convert -f <file>` | 转换API版本 | `--output-version` | 需安装插件 | 升级时转换旧YAML |
| **diff** | `kubectl diff -f <file>` | 比较差异 | `-R` | v1.18+ GA | 应用前预览变更 |
| **wait** | `kubectl wait <resource>` | 等待条件满足 | `--for=condition=Ready`, `--timeout` | 稳定 | CI/CD中等待资源就绪 |
| **alpha** | `kubectl alpha <subcommand>` | Alpha功能 | 子命令因版本而异 | 实验性 | 测试新功能 |

## 高级查询与过滤

| 用法 | 语法示例 | 描述 | 适用场景 |
|-----|---------|------|---------|
| **标签选择** | `kubectl get pods -l app=nginx,env=prod` | 按标签过滤 | 筛选特定应用Pod |
| **字段选择** | `kubectl get pods --field-selector=status.phase=Running` | 按字段过滤 | 筛选运行中Pod |
| **JSONPath** | `kubectl get pods -o jsonpath='{.items[*].metadata.name}'` | JSON路径查询 | 提取特定字段 |
| **自定义列** | `kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase` | 自定义输出列 | 自定义输出格式 |
| **排序** | `kubectl get pods --sort-by='.status.startTime'` | 排序输出 | 按启动时间排序 |
| **Go模板** | `kubectl get pods -o go-template='{{range .items}}{{.metadata.name}}{{end}}'` | Go模板格式化 | 复杂格式化需求 |

## 命令版本变更历史

| 版本 | 命令变更 | 变更类型 | 迁移说明 |
|-----|---------|---------|---------|
| **v1.18** | `kubectl diff` GA | 新功能稳定 | 可在CI/CD中使用 |
| **v1.20** | `--dry-run` 必须指定值 | 行为变更 | 使用`--dry-run=client`或`--dry-run=server` |
| **v1.22** | Server-side Apply GA | 新功能稳定 | 推荐使用`--server-side` |
| **v1.23** | `kubectl events` 增强 | 新功能 | 更好的事件查询 |
| **v1.25** | `kubectl debug` GA | 新功能稳定 | 替代临时调试Pod |
| **v1.26** | `kubectl events` 独立命令 | 新功能 | 不再是alpha |
| **v1.27** | `kubectl auth whoami` | 新功能 | 显示当前身份 |
| **v1.28** | 增强的`kubectl logs` | 优化 | 更好的流日志支持 |
| **v1.29** | `kubectl rollout` 改进 | 优化 | 更多状态信息 |

## 生产环境常用组合命令

```bash
# 快速查看所有问题Pod
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

# 查找高资源使用Pod
kubectl top pods -A --sort-by=cpu | head -20

# 批量删除Evicted Pod
kubectl get pods -A --field-selector=status.phase=Failed -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' | xargs -L1 kubectl delete pod -n

# 查看节点上的Pod分布
kubectl get pods -A -o wide --sort-by='.spec.nodeName'

# 导出资源YAML(不含状态)
kubectl get deploy <name> -o yaml | kubectl neat > deploy.yaml

# 监控资源变化
kubectl get pods -w

# 查看Pod重启次数
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.restartCount}{"\t"}{end}{"\n"}{end}' | sort -t$'\t' -k3 -nr

# 检查集群所有资源(排查残留)
kubectl api-resources --verbs=list --namespaced -o name | xargs -n1 kubectl get -A --ignore-not-found

# 滚动更新并等待
kubectl set image deploy/<name> app=image:v2 && kubectl rollout status deploy/<name> --timeout=300s
```

## ACK特定kubectl配置

```bash
# 获取ACK集群kubeconfig
aliyun cs GET /k8s/<cluster-id>/user_config | jq -r '.config' > ~/.kube/config

# 使用RAM账号认证
kubectl config set-credentials ack-user --exec-api-version=client.authentication.k8s.io/v1beta1 \
  --exec-command=aliyun-cli-credential-helper

# 多集群管理
kubectl config set-context ack-prod --cluster=<cluster> --user=<user> --namespace=production
```

---

**效率提示**: 使用Shell别名和kubectl插件(如kubectx/kubens)提高日常操作效率。
