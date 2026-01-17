# 表格46: Kubernetes客户端库

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/reference/using-api/client-libraries](https://kubernetes.io/docs/reference/using-api/client-libraries/)

## 官方客户端库

| 语言 | 仓库 | 维护状态 | 版本对应 |
|-----|------|---------|---------|
| Go | kubernetes/client-go | 官方维护 | 与K8s版本同步 |
| Python | kubernetes-client/python | 官方维护 | 与K8s版本同步 |
| Java | kubernetes-client/java | 官方维护 | 与K8s版本同步 |
| JavaScript/TypeScript | kubernetes-client/javascript | 官方维护 | 与K8s版本同步 |
| C# | kubernetes-client/csharp | 官方维护 | 与K8s版本同步 |
| Haskell | kubernetes-client/haskell | 社区维护 | 延迟同步 |

## Go client-go使用

```go
package main

import (
    "context"
    "fmt"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/tools/clientcmd"
)

func main() {
    // 从kubeconfig加载配置
    config, err := clientcmd.BuildConfigFromFlags("", 
        "/home/user/.kube/config")
    if err != nil {
        panic(err)
    }
    
    // 创建clientset
    clientset, err := kubernetes.NewForConfig(config)
    if err != nil {
        panic(err)
    }
    
    // 列出Pods
    pods, err := clientset.CoreV1().Pods("default").
        List(context.TODO(), metav1.ListOptions{})
    if err != nil {
        panic(err)
    }
    
    for _, pod := range pods.Items {
        fmt.Printf("Pod: %s\n", pod.Name)
    }
}
```

## client-go组件

| 组件 | 功能 | 使用场景 |
|-----|------|---------|
| kubernetes.Clientset | 类型化客户端 | 访问内置资源 |
| dynamic.Client | 动态客户端 | 访问任意资源 |
| rest.RESTClient | REST客户端 | 底层HTTP调用 |
| discovery.Client | 发现客户端 | API发现 |
| informers | 事件监听 | 控制器开发 |
| listers | 本地缓存查询 | 控制器开发 |
| workqueue | 工作队列 | 控制器开发 |

## Informer使用

```go
import (
    "k8s.io/client-go/informers"
    "k8s.io/client-go/tools/cache"
)

// 创建SharedInformerFactory
factory := informers.NewSharedInformerFactory(clientset, time.Hour)

// 获取Pod Informer
podInformer := factory.Core().V1().Pods()

// 添加事件处理器
podInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
    AddFunc: func(obj interface{}) {
        pod := obj.(*v1.Pod)
        fmt.Printf("Pod added: %s\n", pod.Name)
    },
    UpdateFunc: func(oldObj, newObj interface{}) {
        // 处理更新
    },
    DeleteFunc: func(obj interface{}) {
        // 处理删除
    },
})

// 启动Informer
stopCh := make(chan struct{})
factory.Start(stopCh)
factory.WaitForCacheSync(stopCh)
```

## Python客户端使用

```python
from kubernetes import client, config, watch

# 加载配置
config.load_kube_config()  # 从kubeconfig
# 或 config.load_incluster_config()  # 集群内

# 创建API客户端
v1 = client.CoreV1Api()

# 列出Pods
pods = v1.list_namespaced_pod(namespace="default")
for pod in pods.items:
    print(f"Pod: {pod.metadata.name}")

# Watch事件
w = watch.Watch()
for event in w.stream(v1.list_namespaced_pod, namespace="default"):
    print(f"Event: {event['type']} Pod: {event['object'].metadata.name}")
```

## Java客户端使用

```java
import io.kubernetes.client.openapi.ApiClient;
import io.kubernetes.client.openapi.Configuration;
import io.kubernetes.client.openapi.apis.CoreV1Api;
import io.kubernetes.client.util.Config;

public class Example {
    public static void main(String[] args) throws Exception {
        // 加载配置
        ApiClient client = Config.defaultClient();
        Configuration.setDefaultApiClient(client);
        
        // 创建API实例
        CoreV1Api api = new CoreV1Api();
        
        // 列出Pods
        V1PodList list = api.listNamespacedPod(
            "default", null, null, null, null, 
            null, null, null, null, null, null);
        
        for (V1Pod pod : list.getItems()) {
            System.out.println("Pod: " + pod.getMetadata().getName());
        }
    }
}
```

## 认证方式

| 方式 | 场景 | 配置方法 |
|-----|------|---------|
| kubeconfig | 集群外开发 | `clientcmd.BuildConfigFromFlags` |
| InCluster | Pod内运行 | `rest.InClusterConfig()` |
| ServiceAccount | Pod内运行 | 自动挂载Token |
| Bearer Token | API访问 | `BearerToken` 配置 |
| Client证书 | mTLS | 证书+密钥 |

## 客户端ServiceAccount配置

```yaml
# 为Operator/Controller配置ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-operator
  namespace: operators
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: my-operator-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: my-operator-binding
subjects:
- kind: ServiceAccount
  name: my-operator
  namespace: operators
roleRef:
  kind: ClusterRole
  name: my-operator-role
  apiGroup: rbac.authorization.k8s.io
```

## 客户端版本兼容性

| client-go版本 | K8s版本 | Go版本要求 |
|--------------|--------|-----------|
| v0.25.x | v1.25 | go1.19+ |
| v0.26.x | v1.26 | go1.19+ |
| v0.27.x | v1.27 | go1.20+ |
| v0.28.x | v1.28 | go1.20+ |
| v0.29.x | v1.29 | go1.21+ |
| v0.30.x | v1.30 | go1.22+ |
| v0.31.x | v1.31 | go1.22+ |
| v0.32.x | v1.32 | go1.23+ |

## 性能优化建议

| 优化项 | 说明 |
|-------|------|
| 使用Informer | 避免频繁List调用 |
| 设置ResourceVersion | 增量Watch |
| 限制字段返回 | 使用fieldSelector |
| 分页查询 | 大量资源使用limit/continue |
| 复用客户端 | 避免重复创建连接 |
| 配置QPS限制 | 防止API Server过载 |

## QPS配置

```go
config, _ := clientcmd.BuildConfigFromFlags("", kubeconfig)
config.QPS = 100        // 每秒请求数
config.Burst = 200      // 突发请求数
config.Timeout = 30 * time.Second
```
