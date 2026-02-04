# 46 - Kubernetes客户端库

> **适用版本**: v1.25 - v1.32 | **最后更新**: 2026-01 | **参考**: [kubernetes.io/docs/reference/using-api/client-libraries](https://kubernetes.io/docs/reference/using-api/client-libraries/)

## 客户端库架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Kubernetes 客户端库架构                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     应用程序层                                        │  │
│   │   ┌───────────────────────────────────────────────────────────┐    │  │
│   │   │              用户代码 / 控制器 / Operator                  │    │  │
│   │   └───────────────────────────────────────────────────────────┘    │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                        │                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     客户端库抽象层                                    │  │
│   │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                │  │
│   │   │ Clientset   │  │ Dynamic     │  │ Discovery   │                │  │
│   │   │ (类型化)    │  │ Client      │  │ Client      │                │  │
│   │   │             │  │ (动态)      │  │ (API发现)   │                │  │
│   │   └─────────────┘  └─────────────┘  └─────────────┘                │  │
│   │                                                                      │  │
│   │   ┌────────────────────────────────────────────────────────────┐   │  │
│   │   │                    Informer / Lister                        │   │  │
│   │   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │   │  │
│   │   │  │   Reflector  │  │    Store     │  │  Processor   │      │   │  │
│   │   │  │  List+Watch  │─▶│  本地缓存    │─▶│  事件处理    │      │   │  │
│   │   │  └──────────────┘  └──────────────┘  └──────────────┘      │   │  │
│   │   └────────────────────────────────────────────────────────────┘   │  │
│   │                                                                      │  │
│   │   ┌────────────────────────────────────────────────────────────┐   │  │
│   │   │                    WorkQueue                                │   │  │
│   │   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │   │  │
│   │   │  │   AddRateLimited │  DelayingQueue│  │   Worker    │      │   │  │
│   │   │  └──────────────┘  └──────────────┘  └──────────────┘      │   │  │
│   │   └────────────────────────────────────────────────────────────┘   │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                        │                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     REST Client层                                    │  │
│   │   ┌────────────────────────────────────────────────────────────┐   │  │
│   │   │                  rest.RESTClient                            │   │  │
│   │   │  • HTTP请求构建    • 认证处理    • 序列化/反序列化         │   │  │
│   │   │  • 重试逻辑        • 限流控制    • 超时处理                │   │  │
│   │   └────────────────────────────────────────────────────────────┘   │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                        │                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     传输层                                           │  │
│   │   ┌────────────────────────────────────────────────────────────┐   │  │
│   │   │           HTTP/2 + TLS + 认证凭证                           │   │  │
│   │   └────────────────────────────────────────────────────────────┘   │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                        │                                    │
│                                        ▼                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                     Kubernetes API Server                            │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 官方客户端库对比

| 语言 | 仓库 | 维护状态 | 版本对应 | 特点 | 推荐场景 |
|-----|------|---------|---------|------|---------|
| **Go** | kubernetes/client-go | 官方维护 | 与K8s版本同步 | 功能最全,性能最佳 | 控制器/Operator开发 |
| **Python** | kubernetes-client/python | 官方维护 | 与K8s版本同步 | 简单易用 | 脚本/自动化 |
| **Java** | kubernetes-client/java | 官方维护 | 与K8s版本同步 | 企业级支持 | Java应用集成 |
| **JavaScript/TypeScript** | kubernetes-client/javascript | 官方维护 | 与K8s版本同步 | 前端友好 | Node.js应用 |
| **C#** | kubernetes-client/csharp | 官方维护 | 与K8s版本同步 | .NET生态 | .NET应用 |
| **Haskell** | kubernetes-client/haskell | 社区维护 | 延迟同步 | 函数式 | Haskell项目 |

## Go client-go详解

### client-go组件

| 组件 | 功能 | 使用场景 | 包路径 |
|-----|------|---------|-------|
| **Clientset** | 类型化客户端 | 访问内置资源 | k8s.io/client-go/kubernetes |
| **DynamicClient** | 动态客户端 | 访问任意资源 | k8s.io/client-go/dynamic |
| **RESTClient** | REST客户端 | 底层HTTP调用 | k8s.io/client-go/rest |
| **DiscoveryClient** | 发现客户端 | API发现 | k8s.io/client-go/discovery |
| **Informer** | 事件监听 | 控制器开发 | k8s.io/client-go/informers |
| **Lister** | 本地缓存查询 | 控制器开发 | k8s.io/client-go/listers |
| **WorkQueue** | 工作队列 | 控制器开发 | k8s.io/client-go/util/workqueue |

### 基本使用示例

```go
package main

import (
    "context"
    "fmt"
    "os"
    "path/filepath"

    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/tools/clientcmd"
    "k8s.io/client-go/rest"
)

func main() {
    // 方式1: 从kubeconfig加载配置(集群外)
    config, err := getKubeConfig()
    if err != nil {
        panic(err)
    }

    // 配置QPS和Burst
    config.QPS = 100
    config.Burst = 200
    config.Timeout = 30 * time.Second

    // 创建clientset
    clientset, err := kubernetes.NewForConfig(config)
    if err != nil {
        panic(err)
    }

    // 列出default命名空间的Pods
    pods, err := clientset.CoreV1().Pods("default").
        List(context.TODO(), metav1.ListOptions{})
    if err != nil {
        panic(err)
    }

    fmt.Printf("Found %d pods in default namespace\n", len(pods.Items))
    for _, pod := range pods.Items {
        fmt.Printf("  Pod: %s, Phase: %s\n", pod.Name, pod.Status.Phase)
    }

    // 获取单个Pod
    pod, err := clientset.CoreV1().Pods("default").
        Get(context.TODO(), "my-pod", metav1.GetOptions{})
    if err != nil {
        fmt.Printf("Pod not found: %v\n", err)
    } else {
        fmt.Printf("Pod %s is in phase %s\n", pod.Name, pod.Status.Phase)
    }

    // 创建Pod
    newPod := &corev1.Pod{
        ObjectMeta: metav1.ObjectMeta{
            Name:      "test-pod",
            Namespace: "default",
        },
        Spec: corev1.PodSpec{
            Containers: []corev1.Container{
                {
                    Name:  "nginx",
                    Image: "nginx:1.21",
                },
            },
        },
    }
    
    createdPod, err := clientset.CoreV1().Pods("default").
        Create(context.TODO(), newPod, metav1.CreateOptions{})
    if err != nil {
        panic(err)
    }
    fmt.Printf("Created pod: %s\n", createdPod.Name)

    // 删除Pod
    err = clientset.CoreV1().Pods("default").
        Delete(context.TODO(), "test-pod", metav1.DeleteOptions{})
    if err != nil {
        fmt.Printf("Delete failed: %v\n", err)
    }
}

// getKubeConfig 获取Kubernetes配置
func getKubeConfig() (*rest.Config, error) {
    // 集群内运行
    if os.Getenv("KUBERNETES_SERVICE_HOST") != "" {
        return rest.InClusterConfig()
    }
    
    // 集群外运行
    kubeconfig := filepath.Join(os.Getenv("HOME"), ".kube", "config")
    if envConfig := os.Getenv("KUBECONFIG"); envConfig != "" {
        kubeconfig = envConfig
    }
    
    return clientcmd.BuildConfigFromFlags("", kubeconfig)
}
```

### Informer使用

```go
package main

import (
    "fmt"
    "time"

    corev1 "k8s.io/api/core/v1"
    "k8s.io/client-go/informers"
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/tools/cache"
)

func main() {
    // 创建clientset
    config, _ := getKubeConfig()
    clientset, _ := kubernetes.NewForConfig(config)

    // 创建SharedInformerFactory
    // resyncPeriod: 定期全量同步间隔,0表示不重新同步
    factory := informers.NewSharedInformerFactory(clientset, time.Hour)

    // 获取特定命名空间的Informer
    // factory := informers.NewSharedInformerFactoryWithOptions(
    //     clientset,
    //     time.Hour,
    //     informers.WithNamespace("production"),
    // )

    // 获取Pod Informer
    podInformer := factory.Core().V1().Pods()

    // 添加事件处理器
    podInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
        AddFunc: func(obj interface{}) {
            pod := obj.(*corev1.Pod)
            fmt.Printf("Pod ADDED: %s/%s\n", pod.Namespace, pod.Name)
        },
        UpdateFunc: func(oldObj, newObj interface{}) {
            oldPod := oldObj.(*corev1.Pod)
            newPod := newObj.(*corev1.Pod)
            if oldPod.ResourceVersion != newPod.ResourceVersion {
                fmt.Printf("Pod UPDATED: %s/%s\n", newPod.Namespace, newPod.Name)
            }
        },
        DeleteFunc: func(obj interface{}) {
            pod := obj.(*corev1.Pod)
            fmt.Printf("Pod DELETED: %s/%s\n", pod.Namespace, pod.Name)
        },
    })

    // 启动Informer
    stopCh := make(chan struct{})
    factory.Start(stopCh)

    // 等待缓存同步
    if !cache.WaitForCacheSync(stopCh, podInformer.Informer().HasSynced) {
        panic("Failed to sync cache")
    }

    fmt.Println("Cache synced, informer is running...")

    // 使用Lister从本地缓存查询(不会访问API Server)
    lister := podInformer.Lister()
    
    // 列出所有Pod
    pods, _ := lister.List(labels.Everything())
    fmt.Printf("Found %d pods in cache\n", len(pods))

    // 列出特定命名空间的Pod
    defaultPods, _ := lister.Pods("default").List(labels.Everything())
    fmt.Printf("Found %d pods in default namespace\n", len(defaultPods))

    // 获取特定Pod
    pod, err := lister.Pods("default").Get("my-pod")
    if err != nil {
        fmt.Printf("Pod not found in cache: %v\n", err)
    }

    // 阻塞等待
    <-stopCh
}
```

### 控制器开发模式

```go
package main

import (
    "context"
    "fmt"
    "time"

    corev1 "k8s.io/api/core/v1"
    "k8s.io/apimachinery/pkg/util/runtime"
    "k8s.io/apimachinery/pkg/util/wait"
    "k8s.io/client-go/informers"
    "k8s.io/client-go/kubernetes"
    corev1listers "k8s.io/client-go/listers/core/v1"
    "k8s.io/client-go/tools/cache"
    "k8s.io/client-go/util/workqueue"
    "k8s.io/klog/v2"
)

// Controller 控制器结构
type Controller struct {
    clientset     kubernetes.Interface
    podLister     corev1listers.PodLister
    podSynced     cache.InformerSynced
    workqueue     workqueue.RateLimitingInterface
}

// NewController 创建控制器
func NewController(
    clientset kubernetes.Interface,
    factory informers.SharedInformerFactory,
) *Controller {
    podInformer := factory.Core().V1().Pods()

    controller := &Controller{
        clientset: clientset,
        podLister: podInformer.Lister(),
        podSynced: podInformer.Informer().HasSynced,
        workqueue: workqueue.NewNamedRateLimitingQueue(
            workqueue.DefaultControllerRateLimiter(),
            "Pods",
        ),
    }

    // 添加事件处理器
    podInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
        AddFunc: controller.enqueuePod,
        UpdateFunc: func(old, new interface{}) {
            controller.enqueuePod(new)
        },
        DeleteFunc: controller.enqueuePod,
    })

    return controller
}

// enqueuePod 将Pod key加入队列
func (c *Controller) enqueuePod(obj interface{}) {
    var key string
    var err error
    if key, err = cache.MetaNamespaceKeyFunc(obj); err != nil {
        runtime.HandleError(err)
        return
    }
    c.workqueue.Add(key)
}

// Run 运行控制器
func (c *Controller) Run(workers int, stopCh <-chan struct{}) error {
    defer runtime.HandleCrash()
    defer c.workqueue.ShutDown()

    klog.Info("Starting controller")

    // 等待缓存同步
    klog.Info("Waiting for informer caches to sync")
    if ok := cache.WaitForCacheSync(stopCh, c.podSynced); !ok {
        return fmt.Errorf("failed to wait for caches to sync")
    }

    klog.Info("Starting workers")
    // 启动worker
    for i := 0; i < workers; i++ {
        go wait.Until(c.runWorker, time.Second, stopCh)
    }

    klog.Info("Controller started")
    <-stopCh
    klog.Info("Shutting down controller")
    return nil
}

// runWorker 工作循环
func (c *Controller) runWorker() {
    for c.processNextWorkItem() {
    }
}

// processNextWorkItem 处理队列中的下一个item
func (c *Controller) processNextWorkItem() bool {
    obj, shutdown := c.workqueue.Get()
    if shutdown {
        return false
    }

    err := func(obj interface{}) error {
        defer c.workqueue.Done(obj)
        
        key, ok := obj.(string)
        if !ok {
            c.workqueue.Forget(obj)
            return fmt.Errorf("expected string in workqueue but got %#v", obj)
        }

        // 执行reconcile逻辑
        if err := c.syncHandler(key); err != nil {
            // 重新入队
            c.workqueue.AddRateLimited(key)
            return fmt.Errorf("error syncing '%s': %s, requeuing", key, err.Error())
        }

        // 处理成功,清除重试计数
        c.workqueue.Forget(obj)
        klog.Infof("Successfully synced '%s'", key)
        return nil
    }(obj)

    if err != nil {
        runtime.HandleError(err)
        return true
    }

    return true
}

// syncHandler 实际的reconcile逻辑
func (c *Controller) syncHandler(key string) error {
    namespace, name, err := cache.SplitMetaNamespaceKey(key)
    if err != nil {
        return fmt.Errorf("invalid resource key: %s", key)
    }

    // 从缓存获取Pod
    pod, err := c.podLister.Pods(namespace).Get(name)
    if err != nil {
        // Pod已删除
        if errors.IsNotFound(err) {
            klog.Infof("Pod %s/%s has been deleted", namespace, name)
            return nil
        }
        return err
    }

    // 执行业务逻辑
    klog.Infof("Processing Pod %s/%s, Phase: %s", 
        pod.Namespace, pod.Name, pod.Status.Phase)

    // ... 实际业务逻辑

    return nil
}

func main() {
    config, _ := getKubeConfig()
    clientset, _ := kubernetes.NewForConfig(config)

    factory := informers.NewSharedInformerFactory(clientset, time.Hour)
    controller := NewController(clientset, factory)

    stopCh := make(chan struct{})
    factory.Start(stopCh)

    if err := controller.Run(2, stopCh); err != nil {
        klog.Fatalf("Error running controller: %s", err.Error())
    }
}
```

### 动态客户端使用

```go
package main

import (
    "context"
    "fmt"

    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
    "k8s.io/apimachinery/pkg/runtime/schema"
    "k8s.io/client-go/dynamic"
)

func main() {
    config, _ := getKubeConfig()
    
    // 创建动态客户端
    dynamicClient, err := dynamic.NewForConfig(config)
    if err != nil {
        panic(err)
    }

    // 定义GVR (Group, Version, Resource)
    gvr := schema.GroupVersionResource{
        Group:    "",          // core API group为空
        Version:  "v1",
        Resource: "pods",
    }

    // 列出Pods
    unstructuredList, err := dynamicClient.Resource(gvr).
        Namespace("default").
        List(context.TODO(), metav1.ListOptions{})
    if err != nil {
        panic(err)
    }

    for _, item := range unstructuredList.Items {
        name, _, _ := unstructured.NestedString(item.Object, "metadata", "name")
        phase, _, _ := unstructured.NestedString(item.Object, "status", "phase")
        fmt.Printf("Pod: %s, Phase: %s\n", name, phase)
    }

    // 创建自定义资源
    crdGVR := schema.GroupVersionResource{
        Group:    "myapp.example.com",
        Version:  "v1",
        Resource: "myapps",
    }

    myApp := &unstructured.Unstructured{
        Object: map[string]interface{}{
            "apiVersion": "myapp.example.com/v1",
            "kind":       "MyApp",
            "metadata": map[string]interface{}{
                "name":      "my-app-instance",
                "namespace": "default",
            },
            "spec": map[string]interface{}{
                "replicas": 3,
                "image":    "nginx:1.21",
            },
        },
    }

    created, err := dynamicClient.Resource(crdGVR).
        Namespace("default").
        Create(context.TODO(), myApp, metav1.CreateOptions{})
    if err != nil {
        fmt.Printf("Create failed: %v\n", err)
    } else {
        fmt.Printf("Created: %s\n", created.GetName())
    }
}
```

## Python客户端使用

### 基本使用

```python
from kubernetes import client, config, watch
from kubernetes.client.rest import ApiException
import os

def main():
    # 加载配置
    # 集群外
    config.load_kube_config()
    # 集群内
    # config.load_incluster_config()

    # 创建API客户端
    v1 = client.CoreV1Api()
    apps_v1 = client.AppsV1Api()

    # 列出所有命名空间的Pods
    print("=== 列出所有Pods ===")
    pods = v1.list_pod_for_all_namespaces(watch=False)
    for pod in pods.items:
        print(f"{pod.metadata.namespace}/{pod.metadata.name}: {pod.status.phase}")

    # 列出特定命名空间的Pods
    print("\n=== default命名空间的Pods ===")
    pods = v1.list_namespaced_pod(namespace="default")
    for pod in pods.items:
        print(f"  {pod.metadata.name}: {pod.status.phase}")

    # 创建Pod
    print("\n=== 创建Pod ===")
    pod_manifest = client.V1Pod(
        api_version="v1",
        kind="Pod",
        metadata=client.V1ObjectMeta(
            name="test-pod",
            labels={"app": "test"}
        ),
        spec=client.V1PodSpec(
            containers=[
                client.V1Container(
                    name="nginx",
                    image="nginx:1.21",
                    ports=[client.V1ContainerPort(container_port=80)]
                )
            ]
        )
    )
    
    try:
        created_pod = v1.create_namespaced_pod(
            namespace="default",
            body=pod_manifest
        )
        print(f"Created pod: {created_pod.metadata.name}")
    except ApiException as e:
        print(f"Exception when creating pod: {e}")

    # 删除Pod
    print("\n=== 删除Pod ===")
    try:
        v1.delete_namespaced_pod(
            name="test-pod",
            namespace="default"
        )
        print("Pod deleted")
    except ApiException as e:
        print(f"Exception when deleting pod: {e}")

    # 创建Deployment
    print("\n=== 创建Deployment ===")
    deployment = client.V1Deployment(
        api_version="apps/v1",
        kind="Deployment",
        metadata=client.V1ObjectMeta(name="nginx-deployment"),
        spec=client.V1DeploymentSpec(
            replicas=3,
            selector=client.V1LabelSelector(
                match_labels={"app": "nginx"}
            ),
            template=client.V1PodTemplateSpec(
                metadata=client.V1ObjectMeta(labels={"app": "nginx"}),
                spec=client.V1PodSpec(
                    containers=[
                        client.V1Container(
                            name="nginx",
                            image="nginx:1.21",
                            ports=[client.V1ContainerPort(container_port=80)]
                        )
                    ]
                )
            )
        )
    )
    
    try:
        apps_v1.create_namespaced_deployment(
            namespace="default",
            body=deployment
        )
        print("Deployment created")
    except ApiException as e:
        print(f"Exception: {e}")

if __name__ == "__main__":
    main()
```

### Watch事件

```python
from kubernetes import client, config, watch
import threading

def watch_pods():
    config.load_kube_config()
    v1 = client.CoreV1Api()
    
    w = watch.Watch()
    
    print("Starting to watch pods...")
    for event in w.stream(
        v1.list_namespaced_pod,
        namespace="default",
        timeout_seconds=300  # 5分钟超时
    ):
        event_type = event['type']
        pod = event['object']
        print(f"Event: {event_type} Pod: {pod.metadata.name} Phase: {pod.status.phase}")
        
        # 可以在这里添加退出条件
        # if some_condition:
        #     w.stop()
        #     break

def watch_with_resource_version():
    """带资源版本的增量Watch"""
    config.load_kube_config()
    v1 = client.CoreV1Api()
    
    # 先List获取当前资源版本
    pod_list = v1.list_namespaced_pod(namespace="default")
    resource_version = pod_list.metadata.resource_version
    
    print(f"Starting watch from resource_version: {resource_version}")
    
    w = watch.Watch()
    for event in w.stream(
        v1.list_namespaced_pod,
        namespace="default",
        resource_version=resource_version,  # 从指定版本开始
        timeout_seconds=0  # 0表示服务器默认超时
    ):
        print(f"Event: {event['type']} Pod: {event['object'].metadata.name}")

if __name__ == "__main__":
    watch_pods()
```

### 异步客户端

```python
import asyncio
from kubernetes_asyncio import client, config, watch

async def main():
    # 加载配置
    await config.load_kube_config()
    
    # 创建异步API客户端
    async with client.ApiClient() as api:
        v1 = client.CoreV1Api(api)
        
        # 列出Pods
        pods = await v1.list_namespaced_pod(namespace="default")
        for pod in pods.items:
            print(f"Pod: {pod.metadata.name}")
        
        # 异步Watch
        w = watch.Watch()
        async for event in w.stream(
            v1.list_namespaced_pod,
            namespace="default",
            timeout_seconds=60
        ):
            print(f"Event: {event['type']} Pod: {event['object'].metadata.name}")

if __name__ == "__main__":
    asyncio.run(main())
```

## Java客户端使用

### 基本使用

```java
package com.example.k8s;

import io.kubernetes.client.openapi.ApiClient;
import io.kubernetes.client.openapi.ApiException;
import io.kubernetes.client.openapi.Configuration;
import io.kubernetes.client.openapi.apis.CoreV1Api;
import io.kubernetes.client.openapi.apis.AppsV1Api;
import io.kubernetes.client.openapi.models.*;
import io.kubernetes.client.util.Config;

import java.util.Arrays;
import java.util.Map;

public class KubernetesExample {
    public static void main(String[] args) throws Exception {
        // 加载配置
        // 从默认位置加载kubeconfig
        ApiClient client = Config.defaultClient();
        // 或从集群内
        // ApiClient client = Config.fromCluster();
        
        // 配置超时
        client.setConnectTimeout(30000);
        client.setReadTimeout(30000);
        client.setWriteTimeout(30000);
        
        Configuration.setDefaultApiClient(client);
        
        // 创建API实例
        CoreV1Api coreApi = new CoreV1Api();
        AppsV1Api appsApi = new AppsV1Api();
        
        // 列出Pods
        System.out.println("=== 列出Pods ===");
        V1PodList podList = coreApi.listNamespacedPod(
            "default",     // namespace
            null,          // pretty
            null,          // allowWatchBookmarks
            null,          // _continue
            null,          // fieldSelector
            null,          // labelSelector
            null,          // limit
            null,          // resourceVersion
            null,          // resourceVersionMatch
            null,          // sendInitialEvents
            null,          // timeoutSeconds
            null           // watch
        );
        
        for (V1Pod pod : podList.getItems()) {
            System.out.println("Pod: " + pod.getMetadata().getName() + 
                             " Phase: " + pod.getStatus().getPhase());
        }
        
        // 创建Pod
        System.out.println("\n=== 创建Pod ===");
        V1Pod newPod = new V1Pod()
            .apiVersion("v1")
            .kind("Pod")
            .metadata(new V1ObjectMeta()
                .name("test-pod")
                .labels(Map.of("app", "test")))
            .spec(new V1PodSpec()
                .containers(Arrays.asList(
                    new V1Container()
                        .name("nginx")
                        .image("nginx:1.21")
                        .ports(Arrays.asList(
                            new V1ContainerPort().containerPort(80)
                        ))
                )));
        
        try {
            V1Pod createdPod = coreApi.createNamespacedPod(
                "default", newPod, null, null, null, null
            );
            System.out.println("Created pod: " + createdPod.getMetadata().getName());
        } catch (ApiException e) {
            System.out.println("Exception: " + e.getResponseBody());
        }
        
        // 删除Pod
        System.out.println("\n=== 删除Pod ===");
        try {
            coreApi.deleteNamespacedPod(
                "test-pod", "default", null, null, null, null, null, null
            );
            System.out.println("Pod deleted");
        } catch (ApiException e) {
            System.out.println("Exception: " + e.getResponseBody());
        }
    }
}
```

### Watch事件

```java
package com.example.k8s;

import io.kubernetes.client.openapi.ApiClient;
import io.kubernetes.client.openapi.apis.CoreV1Api;
import io.kubernetes.client.openapi.models.V1Pod;
import io.kubernetes.client.util.Config;
import io.kubernetes.client.util.Watch;

import java.util.concurrent.TimeUnit;

public class WatchExample {
    public static void main(String[] args) throws Exception {
        ApiClient client = Config.defaultClient();
        // 设置超时
        client.setHttpClient(client.getHttpClient().newBuilder()
            .readTimeout(0, TimeUnit.SECONDS)  // 无限等待Watch
            .build());
        
        CoreV1Api api = new CoreV1Api(client);
        
        // 创建Watch
        try (Watch<V1Pod> watch = Watch.createWatch(
            client,
            api.listNamespacedPodCall(
                "default",
                null, null, null, null, null, null, null, null, null,
                true,  // watch=true
                null
            ),
            new TypeToken<Watch.Response<V1Pod>>() {}.getType()
        )) {
            System.out.println("Starting watch...");
            for (Watch.Response<V1Pod> event : watch) {
                System.out.println(String.format(
                    "Event: %s Pod: %s Phase: %s",
                    event.type,
                    event.object.getMetadata().getName(),
                    event.object.getStatus().getPhase()
                ));
            }
        }
    }
}
```

## 认证方式

### 认证方式对比

| 方式 | 场景 | 配置方法 | 安全性 |
|-----|------|---------|-------|
| **kubeconfig** | 集群外开发 | 配置文件 | 中 |
| **InCluster** | Pod内运行 | 自动挂载 | 高 |
| **ServiceAccount** | Pod内运行 | Token | 高 |
| **Bearer Token** | API访问 | Token字符串 | 中 |
| **Client证书** | mTLS | 证书+密钥 | 高 |
| **OIDC** | 企业SSO | OAuth2 | 高 |
| **Webhook Token** | 自定义认证 | 外部服务 | 高 |

### 认证配置示例(Go)

```go
package main

import (
    "k8s.io/client-go/rest"
    "k8s.io/client-go/tools/clientcmd"
)

// 方式1: kubeconfig文件
func fromKubeconfig() (*rest.Config, error) {
    return clientcmd.BuildConfigFromFlags("", "/path/to/kubeconfig")
}

// 方式2: 集群内(自动使用ServiceAccount)
func inCluster() (*rest.Config, error) {
    return rest.InClusterConfig()
}

// 方式3: Bearer Token
func withBearerToken() *rest.Config {
    return &rest.Config{
        Host:        "https://kubernetes.default.svc",
        BearerToken: "your-token-here",
        TLSClientConfig: rest.TLSClientConfig{
            CAFile: "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt",
        },
    }
}

// 方式4: 客户端证书
func withClientCert() *rest.Config {
    return &rest.Config{
        Host: "https://kubernetes.default.svc",
        TLSClientConfig: rest.TLSClientConfig{
            CAFile:   "/path/to/ca.crt",
            CertFile: "/path/to/client.crt",
            KeyFile:  "/path/to/client.key",
        },
    }
}

// 方式5: 组合多种认证
func combined() (*rest.Config, error) {
    config, err := rest.InClusterConfig()
    if err != nil {
        // 降级到kubeconfig
        return clientcmd.BuildConfigFromFlags("", clientcmd.RecommendedHomeFile)
    }
    return config, nil
}
```

## 客户端版本兼容性

### 版本对应表

| client-go版本 | K8s版本 | Go版本要求 | 发布日期 |
|--------------|--------|-----------|---------|
| v0.25.x | v1.25 | go1.19+ | 2022-08 |
| v0.26.x | v1.26 | go1.19+ | 2022-12 |
| v0.27.x | v1.27 | go1.20+ | 2023-04 |
| v0.28.x | v1.28 | go1.20+ | 2023-08 |
| v0.29.x | v1.29 | go1.21+ | 2023-12 |
| v0.30.x | v1.30 | go1.22+ | 2024-04 |
| v0.31.x | v1.31 | go1.22+ | 2024-08 |
| v0.32.x | v1.32 | go1.23+ | 2024-12 |

### 兼容性规则

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     客户端版本兼容性规则                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   官方支持矩阵:                                                              │
│   • client-go X.Y 支持 K8s X.Y-1, X.Y, X.Y+1 (±1版本)                      │
│                                                                             │
│   推荐做法:                                                                  │
│   • 生产环境: 客户端版本 <= 服务端版本                                        │
│   • 开发环境: 可以使用较新客户端访问旧版本服务端                               │
│                                                                             │
│   版本选择:                                                                  │
│   ┌─────────────────────────────────────────────────────────────────┐      │
│   │ 服务端版本    推荐客户端版本    兼容客户端版本                   │      │
│   ├─────────────────────────────────────────────────────────────────┤      │
│   │ v1.30         v0.30.x          v0.29.x - v0.31.x              │      │
│   │ v1.29         v0.29.x          v0.28.x - v0.30.x              │      │
│   │ v1.28         v0.28.x          v0.27.x - v0.29.x              │      │
│   └─────────────────────────────────────────────────────────────────┘      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 性能优化

### 优化策略

| 优化项 | 说明 | 实现方式 | 效果 |
|-------|------|---------|------|
| **使用Informer** | 避免频繁List调用 | 本地缓存+Watch | 减少API Server压力 |
| **设置ResourceVersion** | 增量Watch | List后使用RV | 避免全量数据传输 |
| **限制字段返回** | 减少传输数据 | fieldSelector | 减少网络带宽 |
| **分页查询** | 大量资源处理 | limit/continue | 避免超时和内存问题 |
| **复用客户端** | 避免重复创建连接 | 单例模式 | 减少连接开销 |
| **配置QPS限制** | 防止API Server过载 | QPS/Burst配置 | 保护API Server |
| **使用ServerSideApply** | 减少冲突 | Apply操作 | 更好的并发控制 |

### QPS配置

```go
// QPS配置示例
config, _ := clientcmd.BuildConfigFromFlags("", kubeconfig)

// 基础配置
config.QPS = 100              // 每秒请求数
config.Burst = 200            // 突发请求数
config.Timeout = 30 * time.Second

// 根据场景调整
// 控制器场景(高并发)
config.QPS = 200
config.Burst = 400

// 批处理场景(低优先级)
config.QPS = 20
config.Burst = 40

// 监控/观察场景
config.QPS = 50
config.Burst = 100
```

### 分页查询

```go
// 分页查询大量资源
func listAllPods(clientset *kubernetes.Clientset) ([]corev1.Pod, error) {
    var allPods []corev1.Pod
    
    opts := metav1.ListOptions{
        Limit: 100,  // 每页100条
    }
    
    for {
        podList, err := clientset.CoreV1().Pods("").
            List(context.TODO(), opts)
        if err != nil {
            return nil, err
        }
        
        allPods = append(allPods, podList.Items...)
        
        // 检查是否有更多数据
        if podList.Continue == "" {
            break
        }
        opts.Continue = podList.Continue
    }
    
    return allPods, nil
}
```

### ServerSideApply

```go
// Server-Side Apply示例
func applyPod(clientset *kubernetes.Clientset) error {
    pod := &corev1.Pod{
        TypeMeta: metav1.TypeMeta{
            APIVersion: "v1",
            Kind:       "Pod",
        },
        ObjectMeta: metav1.ObjectMeta{
            Name:      "my-pod",
            Namespace: "default",
        },
        Spec: corev1.PodSpec{
            Containers: []corev1.Container{
                {
                    Name:  "nginx",
                    Image: "nginx:1.21",
                },
            },
        },
    }
    
    // 使用Apply(需要设置fieldManager)
    _, err := clientset.CoreV1().Pods("default").Apply(
        context.TODO(),
        &applycorev1.PodApplyConfiguration{
            TypeMetaApplyConfiguration: applymetav1.TypeMetaApplyConfiguration{
                APIVersion: ptr.To("v1"),
                Kind:       ptr.To("Pod"),
            },
            ObjectMetaApplyConfiguration: &applymetav1.ObjectMetaApplyConfiguration{
                Name:      ptr.To("my-pod"),
                Namespace: ptr.To("default"),
            },
            Spec: &applycorev1.PodSpecApplyConfiguration{
                Containers: []applycorev1.ContainerApplyConfiguration{
                    {
                        Name:  ptr.To("nginx"),
                        Image: ptr.To("nginx:1.21"),
                    },
                },
            },
        },
        metav1.ApplyOptions{
            FieldManager: "my-controller",
            Force:        true,
        },
    )
    return err
}
```

## 常见问题与解决方案

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| **连接超时** | 网络问题/API Server负载高 | 增加超时时间,检查网络 |
| **认证失败** | Token过期/证书问题 | 刷新Token,检查证书有效期 |
| **Watch断开** | 超时/资源版本过旧 | 重新List获取RV,重建Watch |
| **资源版本过旧** | 长时间未同步 | 重新List获取最新RV |
| **内存溢出** | 大量资源缓存 | 使用分页,限制Informer范围 |
| **请求被限流** | QPS超限 | 降低QPS,增加重试间隔 |
| **并发冲突** | 多个客户端修改 | 使用ServerSideApply |

## 版本变更记录

| 版本 | 变更内容 | 影响 |
|-----|---------|------|
| v0.25 | Watch Bookmarks GA | 更可靠的Watch |
| v0.26 | 改进的重试逻辑 | 更好的错误处理 |
| v0.27 | Apply配置生成器 | 更容易使用SSA |
| v0.28 | 改进的Informer | 性能提升 |
| v0.29 | 新的认证方式 | 更多认证选项 |
| v0.30 | HTTP/2优化 | 连接性能提升 |

---

**客户端使用原则**: 优先使用Informer → 合理配置QPS → 使用分页查询 → 选择合适的认证方式 → 保持版本兼容

---

**表格底部标记**: Kusheet Project, 作者 Allen Galler (allengaller@gmail.com)
