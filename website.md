# Kusheet 工具与开源项目 URL 汇总

> **最后更新**: 2026-01-21 | **项目数**: 315+

---

## 目录

- [Kubernetes 核心](#kubernetes-核心)
- [容器运行时 (CRI)](#容器运行时-cri)
- [容器网络 (CNI)](#容器网络-cni)
- [容器存储 (CSI)](#容器存储-csi)
- [Ingress 控制器](#ingress-控制器)
- [服务网格](#服务网格)
- [DNS 与服务发现](#dns-与服务发现)
- [包管理与部署](#包管理与部署)
- [GitOps 与 CI/CD](#gitops-与-cicd)
- [基础设施即代码](#基础设施即代码)
- [镜像构建工具](#镜像构建工具)
- [镜像仓库](#镜像仓库)
- [监控与可观测性](#监控与可观测性)
- [日志聚合](#日志聚合)
- [安全扫描工具](#安全扫描工具)
- [认证与授权](#认证与授权)
- [密钥管理](#密钥管理)
- [策略引擎](#策略引擎)
- [备份与恢复](#备份与恢复)
- [混沌工程](#混沌工程)
- [GPU 与 AI/ML](#gpu-与-aiml)
- [数据处理与编排](#数据处理与编排)
- [LLM 推理服务](#llm-推理服务)
- [LLM 微调工具](#llm-微调工具)
- [LLM 安全工具](#llm-安全工具)
- [模型量化](#模型量化)
- [向量数据库与 RAG](#向量数据库与-rag)
- [成本管理](#成本管理)
- [CLI 增强工具](#cli-增强工具)
- [多集群管理](#多集群管理)
- [本地开发环境](#本地开发环境)
- [平台产品](#平台产品)
- [边缘计算](#边缘计算)
- [自动扩缩容](#自动扩缩容)
- [开发框架与库](#开发框架与库)
- [消息队列与数据库 Operator](#消息队列与数据库-operator)
- [云厂商服务](#云厂商服务)

---

## Kubernetes 核心

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Kubernetes | https://kubernetes.io | https://github.com/kubernetes/kubernetes | https://kubernetes.io/docs/ | https://en.wikipedia.org/wiki/Kubernetes |
| etcd | https://etcd.io | https://github.com/etcd-io/etcd | https://etcd.io/docs/ | https://en.wikipedia.org/wiki/Etcd |
| kubectl | https://kubernetes.io/docs/reference/kubectl/ | https://github.com/kubernetes/kubectl | https://kubernetes.io/docs/reference/kubectl/ | - |
| kubeadm | https://kubernetes.io/docs/reference/setup-tools/kubeadm/ | https://github.com/kubernetes/kubeadm | https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ | - |
| kube-scheduler | https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/ | https://github.com/kubernetes/kube-scheduler | https://kubernetes.io/docs/reference/scheduling/ | - |
| kube-proxy | https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/ | https://github.com/kubernetes/kubernetes | https://kubernetes.io/docs/concepts/services-networking/service/#proxy-mode-ipvs | - |

---

## 容器运行时 (CRI)

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| containerd | https://containerd.io | https://github.com/containerd/containerd | https://containerd.io/docs/ | https://en.wikipedia.org/wiki/Containerd |
| CRI-O | https://cri-o.io | https://github.com/cri-o/cri-o | https://cri-o.io/docs/ | - |
| Docker | https://www.docker.com | https://github.com/moby/moby | https://docs.docker.com/ | https://en.wikipedia.org/wiki/Docker_(software) |
| runc | https://github.com/opencontainers/runc | https://github.com/opencontainers/runc | https://github.com/opencontainers/runc/blob/main/README.md | - |
| crun | https://github.com/containers/crun | https://github.com/containers/crun | https://github.com/containers/crun/blob/main/README.md | - |
| youki | https://github.com/containers/youki | https://github.com/containers/youki | https://github.com/containers/youki/blob/main/README.md | - |
| gVisor | https://gvisor.dev | https://github.com/google/gvisor | https://gvisor.dev/docs/ | https://en.wikipedia.org/wiki/GVisor |
| Kata Containers | https://katacontainers.io | https://github.com/kata-containers/kata-containers | https://katacontainers.io/docs/ | https://en.wikipedia.org/wiki/Kata_Containers |
| nerdctl | https://github.com/containerd/nerdctl | https://github.com/containerd/nerdctl | https://github.com/containerd/nerdctl/blob/main/README.md | - |
| crictl | https://github.com/kubernetes-sigs/cri-tools | https://github.com/kubernetes-sigs/cri-tools | https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/ | - |
| Podman | https://podman.io | https://github.com/containers/podman | https://docs.podman.io/ | https://en.wikipedia.org/wiki/Podman |

---

## 容器网络 (CNI)

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Calico | https://www.tigera.io/project-calico/ | https://github.com/projectcalico/calico | https://docs.tigera.io/calico/ | https://en.wikipedia.org/wiki/Calico_(software) |
| Cilium | https://cilium.io | https://github.com/cilium/cilium | https://docs.cilium.io/ | https://en.wikipedia.org/wiki/Cilium_(software) |
| Flannel | https://github.com/flannel-io/flannel | https://github.com/flannel-io/flannel | https://github.com/flannel-io/flannel/blob/master/README.md | - |
| Weave Net | https://www.weave.works/oss/net/ | https://github.com/weaveworks/weave | https://www.weave.works/docs/net/latest/overview/ | - |
| Antrea | https://antrea.io | https://github.com/antrea-io/antrea | https://antrea.io/docs/ | - |
| Terway | https://github.com/AliyunContainerService/terway | https://github.com/AliyunContainerService/terway | https://github.com/AliyunContainerService/terway/blob/main/README.md | - |
| Canal | https://github.com/projectcalico/canal | https://github.com/projectcalico/canal | https://github.com/projectcalico/canal/blob/master/README.md | - |
| Hubble | https://github.com/cilium/hubble | https://github.com/cilium/hubble | https://docs.cilium.io/en/stable/gettingstarted/hubble/ | - |
| MetalLB | https://metallb.universe.tf | https://github.com/metallb/metallb | https://metallb.universe.tf/configuration/ | - |
| Multus CNI | https://github.com/k8snetworkplumbingwg/multus-cni | https://github.com/k8snetworkplumbingwg/multus-cni | https://github.com/k8snetworkplumbingwg/multus-cni/blob/master/docs/quickstart.md | - |
| whereabouts | https://github.com/k8snetworkplumbingwg/whereabouts | https://github.com/k8snetworkplumbingwg/whereabouts | https://github.com/k8snetworkplumbingwg/whereabouts#readme | - |

---

## 容器存储 (CSI)

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| AWS EBS CSI | https://aws.amazon.com/ebs/ | https://github.com/kubernetes-sigs/aws-ebs-csi-driver | https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/README.md | - |
| AWS EFS CSI | https://aws.amazon.com/efs/ | https://github.com/kubernetes-sigs/aws-efs-csi-driver | https://github.com/kubernetes-sigs/aws-efs-csi-driver/blob/master/README.md | - |
| Azure Disk CSI | https://azure.microsoft.com | https://github.com/kubernetes-sigs/azuredisk-csi-driver | https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/README.md | - |
| Azure File CSI | https://azure.microsoft.com | https://github.com/kubernetes-sigs/azurefile-csi-driver | https://github.com/kubernetes-sigs/azurefile-csi-driver/blob/master/README.md | - |
| GCE PD CSI | https://cloud.google.com/persistent-disk | https://github.com/kubernetes-sigs/gcp-compute-persistent-disk-csi-driver | https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/gce-pd-csi-driver | - |
| Alibaba Cloud CSI | https://www.alibabacloud.com | https://github.com/kubernetes-sigs/alibaba-cloud-csi-driver | https://github.com/kubernetes-sigs/alibaba-cloud-csi-driver/blob/master/README.md | - |
| Ceph CSI | https://ceph.io | https://github.com/ceph/ceph-csi | https://docs.ceph.com/en/latest/rbd/rbd-kubernetes/ | https://en.wikipedia.org/wiki/Ceph_(software) |
| OpenEBS | https://openebs.io | https://github.com/openebs/openebs | https://openebs.io/docs | - |
| TopoLVM | https://github.com/topolvm/topolvm | https://github.com/topolvm/topolvm | https://github.com/topolvm/topolvm/blob/main/README.md | - |
| Local Path Provisioner | https://github.com/rancher/local-path-provisioner | https://github.com/rancher/local-path-provisioner | https://github.com/rancher/local-path-provisioner/blob/master/README.md | - |
| Rook | https://rook.io | https://github.com/rook/rook | https://rook.io/docs/rook/latest/ | - |
| Longhorn | https://longhorn.io | https://github.com/longhorn/longhorn | https://longhorn.io/docs/ | - |
| MinIO | https://min.io | https://github.com/minio/minio | https://min.io/docs/ | https://en.wikipedia.org/wiki/MinIO |
| JuiceFS | https://juicefs.com | https://github.com/juicedata/juicefs | https://juicefs.com/docs/ | - |

---

## Ingress 控制器

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| NGINX Ingress Controller | https://kubernetes.github.io/ingress-nginx/ | https://github.com/kubernetes/ingress-nginx | https://kubernetes.github.io/ingress-nginx/ | https://en.wikipedia.org/wiki/Nginx |
| Traefik | https://traefik.io | https://github.com/traefik/traefik | https://doc.traefik.io/traefik/ | https://en.wikipedia.org/wiki/Traefik |
| HAProxy Ingress | https://haproxy-ingress.github.io | https://github.com/haproxy-ingress/ingress | https://haproxy-ingress.github.io/docs/ | https://en.wikipedia.org/wiki/HAProxy |
| Contour | https://projectcontour.io | https://github.com/projectcontour/contour | https://projectcontour.io/docs/ | - |
| Kong Ingress | https://konghq.com/products/kong-ingress-controller | https://github.com/Kong/kubernetes-ingress-controller | https://docs.konghq.com/kubernetes-ingress-controller/ | https://en.wikipedia.org/wiki/Kong_(software) |
| Ambassador/Emissary | https://www.getambassador.io | https://github.com/emissary-ingress/emissary | https://www.getambassador.io/docs/ | - |
| Envoy | https://www.envoyproxy.io | https://github.com/envoyproxy/envoy | https://www.envoyproxy.io/docs/ | https://en.wikipedia.org/wiki/Envoy_(software) |
| Gateway API | https://gateway-api.sigs.k8s.io | https://github.com/kubernetes-sigs/gateway-api | https://gateway-api.sigs.k8s.io/ | - |
| AWS Load Balancer Controller | https://kubernetes-sigs.github.io/aws-load-balancer-controller/ | https://github.com/kubernetes-sigs/aws-load-balancer-controller | https://kubernetes-sigs.github.io/aws-load-balancer-controller/ | - |
| Skipper | https://opensource.zalando.com/skipper/ | https://github.com/zalando/skipper | https://opensource.zalando.com/skipper/reference/backends/ | - |
| APISIX Ingress | https://apisix.apache.org/docs/ingress-controller/getting-started/ | https://github.com/apache/apisix-ingress-controller | https://apisix.apache.org/docs/ingress-controller/getting-started/ | - |
| Gloo Edge | https://docs.solo.io/gloo-edge/latest/ | https://github.com/solo-io/gloo | https://docs.solo.io/gloo-edge/latest/ | - |

---

## 服务网格

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Istio | https://istio.io | https://github.com/istio/istio | https://istio.io/latest/docs/ | https://en.wikipedia.org/wiki/Istio |
| Linkerd | https://linkerd.io | https://github.com/linkerd/linkerd2 | https://linkerd.io/docs/ | https://en.wikipedia.org/wiki/Linkerd |
| Consul Connect | https://www.consul.io | https://github.com/hashicorp/consul | https://developer.hashicorp.com/consul/docs | https://en.wikipedia.org/wiki/Consul_(software) |

---

## DNS 与服务发现

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| CoreDNS | https://coredns.io | https://github.com/coredns/coredns | https://coredns.io/manual/toc/ | - |
| ExternalDNS | https://github.com/kubernetes-sigs/external-dns | https://github.com/kubernetes-sigs/external-dns | https://github.com/kubernetes-sigs/external-dns/blob/master/README.md | - |
| node-local-dns | https://kubernetes.io/docs/tasks/administer-cluster/nodelocaldns/ | https://github.com/kubernetes/dns | https://kubernetes.io/docs/tasks/administer-cluster/nodelocaldns/ | - |

---

## 包管理与部署

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Helm | https://helm.sh | https://github.com/helm/helm | https://helm.sh/docs/ | https://en.wikipedia.org/wiki/Helm_(package_manager) |
| Kustomize | https://kustomize.io | https://github.com/kubernetes-sigs/kustomize | https://kubectl.docs.kubernetes.io/references/kustomize/ | - |
| Carvel (ytt, kapp) | https://carvel.dev | https://github.com/carvel-dev | https://carvel.dev/docs/ | - |
| Helmfile | https://helmfile.readthedocs.io | https://github.com/helmfile/helmfile | https://helmfile.readthedocs.io/en/latest/ | - |
| kubeval | https://www.kubeval.com | https://github.com/instrumenta/kubeval | https://www.kubeval.com/ | - |
| kubeconform | https://github.com/yannh/kubeconform | https://github.com/yannh/kubeconform | https://github.com/yannh/kubeconform#readme | - |

---

## GitOps 与 CI/CD

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Argo CD | https://argoproj.github.io/cd/ | https://github.com/argoproj/argo-cd | https://argo-cd.readthedocs.io/ | - |
| Flux CD | https://fluxcd.io | https://github.com/fluxcd/flux2 | https://fluxcd.io/docs/ | - |
| Argo Workflows | https://argoproj.github.io/workflows/ | https://github.com/argoproj/argo-workflows | https://argoproj.github.io/argo-workflows/ | - |
| Argo Events | https://argoproj.github.io/events/ | https://github.com/argoproj/argo-events | https://argoproj.github.io/argo-events/ | - |
| Argo Rollouts | https://argoproj.github.io/rollouts/ | https://github.com/argoproj/argo-rollouts | https://argoproj.github.io/argo-rollouts/ | - |
| Tekton | https://tekton.dev | https://github.com/tektoncd/pipeline | https://tekton.dev/docs/ | - |
| Jenkins X | https://jenkins-x.io | https://github.com/jenkins-x/jx | https://jenkins-x.io/docs/ | https://en.wikipedia.org/wiki/Jenkins_(software) |
| Spinnaker | https://spinnaker.io | https://github.com/spinnaker/spinnaker | https://spinnaker.io/docs/ | - |
| Flagger | https://flagger.app | https://github.com/fluxcd/flagger | https://docs.flagger.app/ | - |
| Jenkins | https://www.jenkins.io | https://github.com/jenkinsci/jenkins | https://www.jenkins.io/doc/ | https://en.wikipedia.org/wiki/Jenkins_(software) |
| GitLab CI | https://about.gitlab.com/stages-devops-lifecycle/continuous-integration/ | https://gitlab.com/gitlab-org/gitlab | https://docs.gitlab.com/ee/ci/ | https://en.wikipedia.org/wiki/GitLab |
| GitHub Actions | https://github.com/features/actions | https://github.com/actions | https://docs.github.com/en/actions | - |

---

## 基础设施即代码

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Terraform | https://www.terraform.io | https://github.com/hashicorp/terraform | https://developer.hashicorp.com/terraform/docs | https://en.wikipedia.org/wiki/Terraform_(software) |
| Pulumi | https://www.pulumi.com | https://github.com/pulumi/pulumi | https://www.pulumi.com/docs/ | - |
| Crossplane | https://crossplane.io | https://github.com/crossplane/crossplane | https://docs.crossplane.io/ | - |
| OpenTofu | https://opentofu.org | https://github.com/opentofu/opentofu | https://opentofu.org/docs/ | - |
| CDK for Terraform | https://developer.hashicorp.com/terraform/cdktf | https://github.com/hashicorp/terraform-cdk | https://developer.hashicorp.com/terraform/cdktf | - |

---

## 镜像构建工具

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Buildah | https://buildah.io | https://github.com/containers/buildah | https://buildah.io/blogs/ | - |
| Kaniko | https://github.com/GoogleContainerTools/kaniko | https://github.com/GoogleContainerTools/kaniko | https://github.com/GoogleContainerTools/kaniko/blob/main/README.md | - |
| ko | https://ko.build | https://github.com/ko-build/ko | https://ko.build/reference/ | - |
| Skopeo | https://github.com/containers/skopeo | https://github.com/containers/skopeo | https://github.com/containers/skopeo/blob/main/README.md | - |
| Buildpacks | https://buildpacks.io | https://github.com/buildpacks | https://buildpacks.io/docs/ | - |
| Jib | https://github.com/GoogleContainerTools/jib | https://github.com/GoogleContainerTools/jib | https://github.com/GoogleContainerTools/jib/blob/master/README.md | - |

---

## 镜像仓库

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Harbor | https://goharbor.io | https://github.com/goharbor/harbor | https://goharbor.io/docs/ | - |
| Quay | https://quay.io | https://github.com/quay/quay | https://docs.projectquay.io/ | - |
| Docker Registry | https://docs.docker.com/registry/ | https://github.com/distribution/distribution | https://docs.docker.com/registry/ | - |
| Nexus Repository | https://www.sonatype.com/products/sonatype-nexus-repository | https://github.com/sonatype/nexus-public | https://help.sonatype.com/repomanager3 | - |
| JFrog Artifactory | https://jfrog.com/artifactory/ | - | https://jfrog.com/help/r/jfrog-artifactory-documentation | - |
| Dragonfly | https://d7y.io | https://github.com/dragonflyoss/Dragonfly2 | https://d7y.io/docs/ | - |

---

## 监控与可观测性

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Prometheus | https://prometheus.io | https://github.com/prometheus/prometheus | https://prometheus.io/docs/ | https://en.wikipedia.org/wiki/Prometheus_(software) |
| Grafana | https://grafana.com | https://github.com/grafana/grafana | https://grafana.com/docs/grafana/ | https://en.wikipedia.org/wiki/Grafana |
| Alertmanager | https://prometheus.io/docs/alerting/latest/alertmanager/ | https://github.com/prometheus/alertmanager | https://prometheus.io/docs/alerting/latest/alertmanager/ | - |
| Prometheus Operator | https://prometheus-operator.dev | https://github.com/prometheus-operator/prometheus-operator | https://prometheus-operator.dev/docs/prologue/introduction/ | - |
| kube-state-metrics | https://github.com/kubernetes/kube-state-metrics | https://github.com/kubernetes/kube-state-metrics | https://github.com/kubernetes/kube-state-metrics#readme | - |
| metrics-server | https://github.com/kubernetes-sigs/metrics-server | https://github.com/kubernetes-sigs/metrics-server | https://github.com/kubernetes-sigs/metrics-server#readme | - |
| node-exporter | https://prometheus.io/docs/guides/node-exporter/ | https://github.com/prometheus/node_exporter | https://prometheus.io/docs/guides/node-exporter/ | - |
| Blackbox Exporter | https://github.com/prometheus/blackbox_exporter | https://github.com/prometheus/blackbox_exporter | https://github.com/prometheus/blackbox_exporter#readme | - |
| Pushgateway | https://github.com/prometheus/pushgateway | https://github.com/prometheus/pushgateway | https://github.com/prometheus/pushgateway#readme | - |
| cAdvisor | https://github.com/google/cadvisor | https://github.com/google/cadvisor | https://github.com/google/cadvisor#readme | - |
| Thanos | https://thanos.io | https://github.com/thanos-io/thanos | https://thanos.io/tip/thanos/getting-started.md/ | - |
| Cortex | https://cortexmetrics.io | https://github.com/cortexproject/cortex | https://cortexmetrics.io/docs/ | - |
| Mimir | https://grafana.com/oss/mimir/ | https://github.com/grafana/mimir | https://grafana.com/docs/mimir/latest/ | - |
| VictoriaMetrics | https://victoriametrics.com | https://github.com/VictoriaMetrics/VictoriaMetrics | https://docs.victoriametrics.com/ | - |
| Jaeger | https://www.jaegertracing.io | https://github.com/jaegertracing/jaeger | https://www.jaegertracing.io/docs/ | https://en.wikipedia.org/wiki/Jaeger_(software) |
| Zipkin | https://zipkin.io | https://github.com/openzipkin/zipkin | https://zipkin.io/pages/quickstart | https://en.wikipedia.org/wiki/Zipkin |
| OpenTelemetry | https://opentelemetry.io | https://github.com/open-telemetry | https://opentelemetry.io/docs/ | - |
| Pyroscope | https://pyroscope.io | https://github.com/grafana/pyroscope | https://grafana.com/docs/pyroscope/latest/ | - |
| Inspektor Gadget | https://www.inspektor-gadget.io | https://github.com/inspektor-gadget/inspektor-gadget | https://www.inspektor-gadget.io/docs/ | - |
| Pixie | https://px.dev | https://github.com/pixie-io/pixie | https://docs.px.dev/ | - |

---

## 日志聚合

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Elasticsearch | https://www.elastic.co/elasticsearch | https://github.com/elastic/elasticsearch | https://www.elastic.co/guide/en/elasticsearch/reference/current/ | https://en.wikipedia.org/wiki/Elasticsearch |
| Kibana | https://www.elastic.co/kibana | https://github.com/elastic/kibana | https://www.elastic.co/guide/en/kibana/current/ | - |
| Logstash | https://www.elastic.co/logstash | https://github.com/elastic/logstash | https://www.elastic.co/guide/en/logstash/current/ | https://en.wikipedia.org/wiki/Logstash |
| Loki | https://grafana.com/oss/loki/ | https://github.com/grafana/loki | https://grafana.com/docs/loki/latest/ | - |
| Fluent Bit | https://fluentbit.io | https://github.com/fluent/fluent-bit | https://docs.fluentbit.io/ | - |
| Fluentd | https://www.fluentd.org | https://github.com/fluent/fluentd | https://docs.fluentd.org/ | https://en.wikipedia.org/wiki/Fluentd |
| Promtail | https://grafana.com/docs/loki/latest/clients/promtail/ | https://github.com/grafana/loki | https://grafana.com/docs/loki/latest/clients/promtail/ | - |
| Vector | https://vector.dev | https://github.com/vectordotdev/vector | https://vector.dev/docs/ | - |

---

## 安全扫描工具

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Trivy | https://aquasecurity.github.io/trivy/ | https://github.com/aquasecurity/trivy | https://aquasecurity.github.io/trivy/latest/ | - |
| Grype | https://github.com/anchore/grype | https://github.com/anchore/grype | https://github.com/anchore/grype/blob/main/README.md | - |
| Clair | https://quay.github.io/clair/ | https://github.com/quay/clair | https://quay.github.io/clair/ | - |
| Falco | https://falco.org | https://github.com/falcosecurity/falco | https://falco.org/docs/ | - |
| Kubescape | https://kubescape.io | https://github.com/kubescape/kubescape | https://kubescape.io/docs/ | - |
| Snyk | https://snyk.io | https://github.com/snyk/cli | https://docs.snyk.io/ | - |
| Syft | https://github.com/anchore/syft | https://github.com/anchore/syft | https://github.com/anchore/syft/blob/main/README.md | - |
| Tetragon | https://tetragon.io | https://github.com/cilium/tetragon | https://tetragon.io/docs/ | - |
| KubeArmor | https://kubearmor.io | https://github.com/kubearmor/KubeArmor | https://docs.kubearmor.io/ | - |
| Checkov | https://www.checkov.io | https://github.com/bridgecrewio/checkov | https://www.checkov.io/1.Introduction/Getting%20Started.html | - |
| Semgrep | https://semgrep.dev | https://github.com/semgrep/semgrep | https://semgrep.dev/docs/ | - |
| gitleaks | https://gitleaks.io | https://github.com/gitleaks/gitleaks | https://github.com/gitleaks/gitleaks/blob/master/README.md | - |
| Cosign | https://docs.sigstore.dev/cosign/overview/ | https://github.com/sigstore/cosign | https://docs.sigstore.dev/cosign/overview/ | - |
| ModSecurity | https://modsecurity.org | https://github.com/SpiderLabs/ModSecurity | https://modsecurity.org/documentation/ | https://en.wikipedia.org/wiki/ModSecurity |
| OWASP CRS | https://coreruleset.org | https://github.com/coreruleset/coreruleset | https://coreruleset.org/docs/ | - |
| kube-bench | https://aquasecurity.github.io/kube-bench/ | https://github.com/aquasecurity/kube-bench | https://aquasecurity.github.io/kube-bench/latest/ | - |
| kube-hunter | https://aquasecurity.github.io/kube-hunter/ | https://github.com/aquasecurity/kube-hunter | https://aquasecurity.github.io/kube-hunter/ | - |
| Polaris | https://www.fairwinds.com/polaris | https://github.com/FairwindsOps/polaris | https://polaris.docs.fairwinds.com/ | - |
| Pluto | https://pluto.docs.fairwinds.com/ | https://github.com/FairwindsOps/pluto | https://pluto.docs.fairwinds.com/ | - |

---

## 认证与授权

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| OAuth2 Proxy | https://oauth2-proxy.github.io/oauth2-proxy/ | https://github.com/oauth2-proxy/oauth2-proxy | https://oauth2-proxy.github.io/oauth2-proxy/docs/ | - |
| Authelia | https://www.authelia.com | https://github.com/authelia/authelia | https://www.authelia.com/docs/ | - |
| Dex | https://dexidp.io | https://github.com/dexidp/dex | https://dexidp.io/docs/ | - |
| Keycloak | https://www.keycloak.org | https://github.com/keycloak/keycloak | https://www.keycloak.org/documentation | https://en.wikipedia.org/wiki/Keycloak |

---

## 密钥管理

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| HashiCorp Vault | https://www.vaultproject.io | https://github.com/hashicorp/vault | https://developer.hashicorp.com/vault/docs | https://en.wikipedia.org/wiki/Vault_(software) |
| External Secrets Operator | https://external-secrets.io | https://github.com/external-secrets/external-secrets | https://external-secrets.io/latest/ | - |
| Sealed Secrets | https://sealed-secrets.netlify.app | https://github.com/bitnami-labs/sealed-secrets | https://github.com/bitnami-labs/sealed-secrets/blob/main/README.md | - |
| SOPS | https://github.com/getsops/sops | https://github.com/getsops/sops | https://github.com/getsops/sops/blob/main/README.md | - |
| cert-manager | https://cert-manager.io | https://github.com/cert-manager/cert-manager | https://cert-manager.io/docs/ | - |

---

## 策略引擎

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| OPA (Open Policy Agent) | https://www.openpolicyagent.org | https://github.com/open-policy-agent/opa | https://www.openpolicyagent.org/docs/ | - |
| Gatekeeper | https://open-policy-agent.github.io/gatekeeper/ | https://github.com/open-policy-agent/gatekeeper | https://open-policy-agent.github.io/gatekeeper/website/docs/ | - |
| Kyverno | https://kyverno.io | https://github.com/kyverno/kyverno | https://kyverno.io/docs/ | - |

---

## 备份与恢复

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Velero | https://velero.io | https://github.com/vmware-tanzu/velero | https://velero.io/docs/ | - |
| Kasten K10 | https://www.kasten.io | - | https://docs.kasten.io/ | - |
| Restic | https://restic.net | https://github.com/restic/restic | https://restic.readthedocs.io/ | - |
| Stash | https://stash.run | https://github.com/stashed/stash | https://stash.run/docs/ | - |

---

## 混沌工程

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Chaos Mesh | https://chaos-mesh.org | https://github.com/chaos-mesh/chaos-mesh | https://chaos-mesh.org/docs/ | - |
| LitmusChaos | https://litmuschaos.io | https://github.com/litmuschaos/litmus | https://litmuschaos.io/docs/ | - |
| Chaos Monkey | https://netflix.github.io/chaosmonkey/ | https://github.com/Netflix/chaosmonkey | https://netflix.github.io/chaosmonkey/ | https://en.wikipedia.org/wiki/Chaos_engineering |
| Chaosblade | https://chaosblade.io | https://github.com/chaosblade-io/chaosblade | https://chaosblade.io/docs/ | - |
| Gremlin | https://www.gremlin.com | - | https://www.gremlin.com/docs/ | - |
| Pumba | https://github.com/alexei-led/pumba | https://github.com/alexei-led/pumba | https://github.com/alexei-led/pumba/blob/master/README.md | - |
| Toxiproxy | https://github.com/Shopify/toxiproxy | https://github.com/Shopify/toxiproxy | https://github.com/Shopify/toxiproxy/blob/main/README.md | - |

---

## GPU 与 AI/ML

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| NVIDIA Device Plugin | https://github.com/NVIDIA/k8s-device-plugin | https://github.com/NVIDIA/k8s-device-plugin | https://github.com/NVIDIA/k8s-device-plugin#readme | - |
| NVIDIA GPU Operator | https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/ | https://github.com/NVIDIA/gpu-operator | https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/ | - |
| DCGM Exporter | https://github.com/NVIDIA/dcgm-exporter | https://github.com/NVIDIA/dcgm-exporter | https://docs.nvidia.com/datacenter/dcgm/latest/ | - |
| Kubeflow | https://www.kubeflow.org | https://github.com/kubeflow/kubeflow | https://www.kubeflow.org/docs/ | https://en.wikipedia.org/wiki/Kubeflow |
| Kubeflow Training Operator | https://www.kubeflow.org/docs/components/training/ | https://github.com/kubeflow/training-operator | https://www.kubeflow.org/docs/components/training/ | - |
| Ray | https://www.ray.io | https://github.com/ray-project/ray | https://docs.ray.io/ | - |
| Volcano | https://volcano.sh | https://github.com/volcano-sh/volcano | https://volcano.sh/en/docs/ | - |
| Kueue | https://kueue.sigs.k8s.io | https://github.com/kubernetes-sigs/kueue | https://kueue.sigs.k8s.io/docs/ | - |
| Karpenter | https://karpenter.sh | https://github.com/aws/karpenter | https://karpenter.sh/docs/ | - |
| Descheduler | https://github.com/kubernetes-sigs/descheduler | https://github.com/kubernetes-sigs/descheduler | https://github.com/kubernetes-sigs/descheduler#readme | - |
| PyTorch | https://pytorch.org | https://github.com/pytorch/pytorch | https://pytorch.org/docs/ | https://en.wikipedia.org/wiki/PyTorch |
| TensorFlow | https://www.tensorflow.org | https://github.com/tensorflow/tensorflow | https://www.tensorflow.org/api_docs | https://en.wikipedia.org/wiki/TensorFlow |
| MLflow | https://mlflow.org | https://github.com/mlflow/mlflow | https://mlflow.org/docs/latest/ | - |
| Weights & Biases | https://wandb.ai | https://github.com/wandb/wandb | https://docs.wandb.ai/ | - |
| Katib | https://www.kubeflow.org/docs/components/katib/ | https://github.com/kubeflow/katib | https://www.kubeflow.org/docs/components/katib/overview/ | - |
| Feast | https://feast.dev | https://github.com/feast-dev/feast | https://docs.feast.dev/ | - |
| Seldon Core | https://www.seldon.io | https://github.com/SeldonIO/seldon-core | https://docs.seldon.io/projects/seldon-core/en/latest/ | - |
| TorchServe | https://pytorch.org/serve/ | https://github.com/pytorch/serve | https://pytorch.org/serve/getting_started.html | - |
| Alluxio | https://www.alluxio.io | https://github.com/Alluxio/alluxio | https://docs.alluxio.io/ | - |
| Fluid | https://fluid-cloudnative.github.io | https://github.com/fluid-cloudnative/fluid | https://fluid-cloudnative.github.io/docs/ | - |

---

## 数据处理与编排

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Apache Spark | https://spark.apache.org | https://github.com/apache/spark | https://spark.apache.org/docs/latest/ | https://en.wikipedia.org/wiki/Apache_Spark |
| Spark on K8s Operator | https://github.com/GoogleCloudPlatform/spark-on-k8s-operator | https://github.com/GoogleCloudPlatform/spark-on-k8s-operator | https://github.com/GoogleCloudPlatform/spark-on-k8s-operator/blob/master/docs/user-guide.md | - |
| Apache Flink | https://flink.apache.org | https://github.com/apache/flink | https://nightlies.apache.org/flink/flink-docs-stable/ | https://en.wikipedia.org/wiki/Apache_Flink |
| Apache Airflow | https://airflow.apache.org | https://github.com/apache/airflow | https://airflow.apache.org/docs/ | https://en.wikipedia.org/wiki/Apache_Airflow |
| Prefect | https://www.prefect.io | https://github.com/PrefectHQ/prefect | https://docs.prefect.io/ | - |
| Dask | https://dask.org | https://github.com/dask/dask | https://docs.dask.org/ | - |
| DVC | https://dvc.org | https://github.com/iterative/dvc | https://dvc.org/doc | - |
| Kubeflow Pipelines | https://www.kubeflow.org/docs/components/pipelines/ | https://github.com/kubeflow/pipelines | https://www.kubeflow.org/docs/components/pipelines/ | - |
| DataHub | https://datahubproject.io | https://github.com/datahub-project/datahub | https://datahubproject.io/docs/ | - |
| Amundsen | https://www.amundsen.io | https://github.com/amundsen-io/amundsen | https://www.amundsen.io/amundsen/ | - |

---

## LLM 推理服务

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| vLLM | https://docs.vllm.ai | https://github.com/vllm-project/vllm | https://docs.vllm.ai/en/latest/ | - |
| Text Generation Inference (TGI) | https://huggingface.co/docs/text-generation-inference | https://github.com/huggingface/text-generation-inference | https://huggingface.co/docs/text-generation-inference | - |
| Text Embeddings Inference (TEI) | https://huggingface.co/docs/text-embeddings-inference | https://github.com/huggingface/text-embeddings-inference | https://huggingface.co/docs/text-embeddings-inference | - |
| TensorRT-LLM | https://nvidia.github.io/TensorRT-LLM/ | https://github.com/NVIDIA/TensorRT-LLM | https://nvidia.github.io/TensorRT-LLM/ | - |
| llama.cpp | https://github.com/ggerganov/llama.cpp | https://github.com/ggerganov/llama.cpp | https://github.com/ggerganov/llama.cpp#readme | - |
| DeepSpeed-MII | https://github.com/microsoft/DeepSpeed-MII | https://github.com/microsoft/DeepSpeed-MII | https://github.com/microsoft/DeepSpeed-MII#readme | - |
| SGLang | https://sgl-project.github.io | https://github.com/sgl-project/sglang | https://sgl-project.github.io/docs/ | - |
| LMDeploy | https://lmdeploy.readthedocs.io | https://github.com/InternLM/lmdeploy | https://lmdeploy.readthedocs.io/en/latest/ | - |
| KServe | https://kserve.github.io/website/ | https://github.com/kserve/kserve | https://kserve.github.io/website/master/get_started/ | - |
| Triton Inference Server | https://developer.nvidia.com/triton-inference-server | https://github.com/triton-inference-server/server | https://docs.nvidia.com/deeplearning/triton-inference-server/ | - |
| Ollama | https://ollama.ai | https://github.com/ollama/ollama | https://github.com/ollama/ollama#readme | - |

---

## LLM 微调工具

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| PEFT | https://huggingface.co/docs/peft | https://github.com/huggingface/peft | https://huggingface.co/docs/peft | - |
| TRL | https://huggingface.co/docs/trl | https://github.com/huggingface/trl | https://huggingface.co/docs/trl | - |
| DeepSpeed | https://www.deepspeed.ai | https://github.com/microsoft/DeepSpeed | https://www.deepspeed.ai/tutorials/ | - |
| Accelerate | https://huggingface.co/docs/accelerate | https://github.com/huggingface/accelerate | https://huggingface.co/docs/accelerate | - |
| Transformers | https://huggingface.co/docs/transformers | https://github.com/huggingface/transformers | https://huggingface.co/docs/transformers | - |
| LLaMA-Factory | https://github.com/hiyouga/LLaMA-Factory | https://github.com/hiyouga/LLaMA-Factory | https://github.com/hiyouga/LLaMA-Factory#readme | - |
| Axolotl | https://github.com/OpenAccess-AI-Collective/axolotl | https://github.com/OpenAccess-AI-Collective/axolotl | https://github.com/OpenAccess-AI-Collective/axolotl#readme | - |
| Unsloth | https://unsloth.ai | https://github.com/unslothai/unsloth | https://github.com/unslothai/unsloth#readme | - |

---

## LLM 安全工具

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| NeMo Guardrails | https://github.com/NVIDIA/NeMo-Guardrails | https://github.com/NVIDIA/NeMo-Guardrails | https://github.com/NVIDIA/NeMo-Guardrails#readme | - |
| LangKit | https://github.com/whylabs/langkit | https://github.com/whylabs/langkit | https://github.com/whylabs/langkit#readme | - |
| Opacus | https://opacus.ai | https://github.com/pytorch/opacus | https://opacus.ai/docs/ | - |
| CleverHans | https://github.com/cleverhans-lab/cleverhans | https://github.com/cleverhans-lab/cleverhans | https://github.com/cleverhans-lab/cleverhans#readme | - |
| TextAttack | https://github.com/QData/TextAttack | https://github.com/QData/TextAttack | https://textattack.readthedocs.io/ | - |
| Guardrails AI | https://www.guardrailsai.com | https://github.com/guardrails-ai/guardrails | https://docs.guardrailsai.com/ | - |

---

## 模型量化

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| AutoGPTQ | https://github.com/AutoGPTQ/AutoGPTQ | https://github.com/AutoGPTQ/AutoGPTQ | https://github.com/AutoGPTQ/AutoGPTQ#readme | - |
| AWQ | https://github.com/mit-han-lab/llm-awq | https://github.com/mit-han-lab/llm-awq | https://github.com/mit-han-lab/llm-awq#readme | - |
| bitsandbytes | https://github.com/TimDettmers/bitsandbytes | https://github.com/TimDettmers/bitsandbytes | https://github.com/TimDettmers/bitsandbytes#readme | - |
| GPTQ | https://github.com/IST-DASLab/gptq | https://github.com/IST-DASLab/gptq | https://github.com/IST-DASLab/gptq#readme | - |
| GGML/GGUF | https://github.com/ggerganov/ggml | https://github.com/ggerganov/ggml | https://github.com/ggerganov/ggml#readme | - |

---

## 向量数据库与 RAG

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Milvus | https://milvus.io | https://github.com/milvus-io/milvus | https://milvus.io/docs | - |
| Weaviate | https://weaviate.io | https://github.com/weaviate/weaviate | https://weaviate.io/developers/weaviate | - |
| Qdrant | https://qdrant.tech | https://github.com/qdrant/qdrant | https://qdrant.tech/documentation/ | - |
| Pinecone | https://www.pinecone.io | - | https://docs.pinecone.io/ | - |
| Chroma | https://www.trychroma.com | https://github.com/chroma-core/chroma | https://docs.trychroma.com/ | - |
| pgvector | https://github.com/pgvector/pgvector | https://github.com/pgvector/pgvector | https://github.com/pgvector/pgvector#readme | - |
| LangChain | https://python.langchain.com | https://github.com/langchain-ai/langchain | https://python.langchain.com/docs/ | - |
| LlamaIndex | https://www.llamaindex.ai | https://github.com/run-llama/llama_index | https://docs.llamaindex.ai/ | - |

---

## 成本管理

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Kubecost | https://www.kubecost.com | https://github.com/kubecost/cost-analyzer-helm-chart | https://docs.kubecost.com/ | - |
| OpenCost | https://www.opencost.io | https://github.com/opencost/opencost | https://www.opencost.io/docs/ | - |
| CAST AI | https://cast.ai | - | https://docs.cast.ai/ | - |

---

## CLI 增强工具

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| K9s | https://k9scli.io | https://github.com/derailed/k9s | https://k9scli.io/ | - |
| Lens | https://k8slens.dev | https://github.com/lensapp/lens | https://docs.k8slens.dev/ | - |
| Octant | https://octant.dev | https://github.com/vmware-tanzu/octant | https://octant.dev/docs/ | - |
| Headlamp | https://headlamp.dev | https://github.com/headlamp-k8s/headlamp | https://headlamp.dev/docs/ | - |
| kubectx/kubens | https://github.com/ahmetb/kubectx | https://github.com/ahmetb/kubectx | https://github.com/ahmetb/kubectx#readme | - |
| Stern | https://github.com/stern/stern | https://github.com/stern/stern | https://github.com/stern/stern#readme | - |
| krew | https://krew.sigs.k8s.io | https://github.com/kubernetes-sigs/krew | https://krew.sigs.k8s.io/plugins/ | - |
| Netshoot | https://github.com/nicolaka/netshoot | https://github.com/nicolaka/netshoot | https://github.com/nicolaka/netshoot#readme | - |
| Telepresence | https://www.telepresence.io | https://github.com/telepresenceio/telepresence | https://www.telepresence.io/docs/ | - |
| kubefwd | https://github.com/txn2/kubefwd | https://github.com/txn2/kubefwd | https://github.com/txn2/kubefwd#readme | - |
| ksniff | https://github.com/eldadru/ksniff | https://github.com/eldadru/ksniff | https://github.com/eldadru/ksniff#readme | - |
| kail | https://github.com/boz/kail | https://github.com/boz/kail | https://github.com/boz/kail#readme | - |
| kubetail | https://github.com/johanhaleby/kubetail | https://github.com/johanhaleby/kubetail | https://github.com/johanhaleby/kubetail#readme | - |
| kubectl-tree | https://github.com/ahmetb/kubectl-tree | https://github.com/ahmetb/kubectl-tree | https://github.com/ahmetb/kubectl-tree#readme | - |
| kubectl-neat | https://github.com/itaysk/kubectl-neat | https://github.com/itaysk/kubectl-neat | https://github.com/itaysk/kubectl-neat#readme | - |

---

## 多集群管理

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Karmada | https://karmada.io | https://github.com/karmada-io/karmada | https://karmada.io/docs/ | - |
| KubeFed | https://github.com/kubernetes-sigs/kubefed | https://github.com/kubernetes-sigs/kubefed | https://github.com/kubernetes-sigs/kubefed#readme | - |
| vCluster | https://www.vcluster.com | https://github.com/loft-sh/vcluster | https://www.vcluster.com/docs/ | - |
| Loft | https://loft.sh | https://github.com/loft-sh/loft | https://loft.sh/docs/ | - |
| Rancher | https://rancher.com | https://github.com/rancher/rancher | https://ranchermanager.docs.rancher.com/ | https://en.wikipedia.org/wiki/Rancher_Labs |
| Submariner | https://submariner.io | https://github.com/submariner-io/submariner | https://submariner.io/operations/ | - |
| Skupper | https://skupper.io | https://github.com/skupperproject/skupper | https://skupper.io/docs/ | - |
| Liqo | https://liqo.io | https://github.com/liqotech/liqo | https://docs.liqo.io/ | - |
| Cluster API | https://cluster-api.sigs.k8s.io | https://github.com/kubernetes-sigs/cluster-api | https://cluster-api.sigs.k8s.io/introduction.html | - |

---

## 本地开发环境

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| minikube | https://minikube.sigs.k8s.io | https://github.com/kubernetes/minikube | https://minikube.sigs.k8s.io/docs/ | - |
| kind | https://kind.sigs.k8s.io | https://github.com/kubernetes-sigs/kind | https://kind.sigs.k8s.io/docs/ | - |
| k3s | https://k3s.io | https://github.com/k3s-io/k3s | https://docs.k3s.io/ | - |
| k3d | https://k3d.io | https://github.com/k3d-io/k3d | https://k3d.io/ | - |
| MicroK8s | https://microk8s.io | https://github.com/canonical/microk8s | https://microk8s.io/docs | - |
| Docker Desktop | https://www.docker.com/products/docker-desktop/ | - | https://docs.docker.com/desktop/ | - |

---

## 平台产品

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| KubeSphere | https://kubesphere.io | https://github.com/kubesphere/kubesphere | https://kubesphere.io/docs/ | - |
| Portainer | https://www.portainer.io | https://github.com/portainer/portainer | https://docs.portainer.io/ | - |
| OpenShift | https://www.redhat.com/en/technologies/cloud-computing/openshift | https://github.com/openshift/origin | https://docs.openshift.com/ | https://en.wikipedia.org/wiki/OpenShift |
| Tanzu | https://tanzu.vmware.com | - | https://docs.vmware.com/en/VMware-Tanzu/index.html | - |
| Anthos | https://cloud.google.com/anthos | - | https://cloud.google.com/anthos/docs | - |
| Backstage | https://backstage.io | https://github.com/backstage/backstage | https://backstage.io/docs/ | - |

---

## 边缘计算

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| KubeEdge | https://kubeedge.io | https://github.com/kubeedge/kubeedge | https://kubeedge.io/docs/ | - |
| OpenYurt | https://openyurt.io | https://github.com/openyurtio/openyurt | https://openyurt.io/docs/ | - |
| SuperEdge | https://superedge.io | https://github.com/superedge/superedge | https://superedge.io/docs/ | - |
| Akri | https://docs.akri.sh | https://github.com/project-akri/akri | https://docs.akri.sh/ | - |
| k0s | https://k0sproject.io | https://github.com/k0sproject/k0s | https://docs.k0sproject.io/ | - |

---

## 自动扩缩容

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Cluster Autoscaler | https://github.com/kubernetes/autoscaler | https://github.com/kubernetes/autoscaler | https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler | - |
| VPA (Vertical Pod Autoscaler) | https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler | https://github.com/kubernetes/autoscaler | https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler | - |
| KEDA | https://keda.sh | https://github.com/kedacore/keda | https://keda.sh/docs/ | - |
| Knative | https://knative.dev | https://github.com/knative/serving | https://knative.dev/docs/ | - |
| OpenKruise | https://openkruise.io | https://github.com/openkruise/kruise | https://openkruise.io/docs/ | - |

---

## 开发框架与库

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| client-go | https://pkg.go.dev/k8s.io/client-go | https://github.com/kubernetes/client-go | https://pkg.go.dev/k8s.io/client-go | - |
| Operator SDK | https://sdk.operatorframework.io | https://github.com/operator-framework/operator-sdk | https://sdk.operatorframework.io/docs/ | - |
| Kubebuilder | https://kubebuilder.io | https://github.com/kubernetes-sigs/kubebuilder | https://kubebuilder.io/quick-start.html | - |
| controller-runtime | https://pkg.go.dev/sigs.k8s.io/controller-runtime | https://github.com/kubernetes-sigs/controller-runtime | https://pkg.go.dev/sigs.k8s.io/controller-runtime | - |
| kopf | https://kopf.readthedocs.io | https://github.com/nolar/kopf | https://kopf.readthedocs.io/en/stable/ | - |
| KUDO | https://kudo.dev | https://github.com/kudobuilder/kudo | https://kudo.dev/docs/ | - |
| Metacontroller | https://metacontroller.github.io/metacontroller/ | https://github.com/metacontroller/metacontroller | https://metacontroller.github.io/metacontroller/guide/ | - |
| Skaffold | https://skaffold.dev | https://github.com/GoogleContainerTools/skaffold | https://skaffold.dev/docs/ | - |
| Tilt | https://tilt.dev | https://github.com/tilt-dev/tilt | https://docs.tilt.dev/ | - |
| DevSpace | https://devspace.sh | https://github.com/loft-sh/devspace | https://devspace.sh/docs/ | - |

---

## 消息队列与数据库 Operator

| 工具/项目 | 首页 URL | GitHub URL | 文档 URL | Wikipedia |
|----------|----------|------------|----------|-----------|
| Strimzi (Kafka) | https://strimzi.io | https://github.com/strimzi/strimzi-kafka-operator | https://strimzi.io/documentation/ | - |
| Apache Kafka | https://kafka.apache.org | https://github.com/apache/kafka | https://kafka.apache.org/documentation/ | https://en.wikipedia.org/wiki/Apache_Kafka |
| Redis | https://redis.io | https://github.com/redis/redis | https://redis.io/docs/ | https://en.wikipedia.org/wiki/Redis |
| Redis Operator | https://github.com/spotahome/redis-operator | https://github.com/spotahome/redis-operator | https://github.com/spotahome/redis-operator#readme | - |
| RabbitMQ Cluster Operator | https://www.rabbitmq.com/kubernetes/operator/operator-overview.html | https://github.com/rabbitmq/cluster-operator | https://www.rabbitmq.com/kubernetes/operator/operator-overview.html | https://en.wikipedia.org/wiki/RabbitMQ |
| NATS | https://nats.io | https://github.com/nats-io/nats-server | https://docs.nats.io/ | - |
| Pulsar | https://pulsar.apache.org | https://github.com/apache/pulsar | https://pulsar.apache.org/docs/ | - |

---

## 云厂商服务

| 云厂商 | 服务 | 首页 URL | 文档 URL |
|-------|------|----------|----------|
| **AWS** | EKS | https://aws.amazon.com/eks/ | https://docs.aws.amazon.com/eks/ |
| **AWS** | Secrets Manager | https://aws.amazon.com/secrets-manager/ | https://docs.aws.amazon.com/secretsmanager/ |
| **AWS** | EBS | https://aws.amazon.com/ebs/ | https://docs.aws.amazon.com/ebs/ |
| **AWS** | EFS | https://aws.amazon.com/efs/ | https://docs.aws.amazon.com/efs/ |
| **AWS** | Route 53 | https://aws.amazon.com/route53/ | https://docs.aws.amazon.com/route53/ |
| **AWS** | ALB/NLB | https://aws.amazon.com/elasticloadbalancing/ | https://docs.aws.amazon.com/elasticloadbalancing/ |
| **Azure** | AKS | https://azure.microsoft.com/en-us/products/kubernetes-service | https://docs.microsoft.com/en-us/azure/aks/ |
| **Azure** | Key Vault | https://azure.microsoft.com/en-us/products/key-vault | https://docs.microsoft.com/en-us/azure/key-vault/ |
| **Azure** | Managed Disks | https://azure.microsoft.com/en-us/products/storage/disks | https://docs.microsoft.com/en-us/azure/virtual-machines/managed-disks-overview |
| **GCP** | GKE | https://cloud.google.com/kubernetes-engine | https://cloud.google.com/kubernetes-engine/docs |
| **GCP** | Secret Manager | https://cloud.google.com/secret-manager | https://cloud.google.com/secret-manager/docs |
| **GCP** | Persistent Disk | https://cloud.google.com/persistent-disk | https://cloud.google.com/persistent-disk/docs |
| **阿里云** | ACK | https://www.alibabacloud.com/product/kubernetes | https://www.alibabacloud.com/help/ack |
| **阿里云** | KMS | https://www.alibabacloud.com/product/kms | https://www.alibabacloud.com/help/kms |
| **阿里云** | ESSD | https://www.alibabacloud.com/product/disk | https://www.alibabacloud.com/help/ecs/latest/cloud-disks |
| **阿里云** | NAS | https://www.alibabacloud.com/product/nas | https://www.alibabacloud.com/help/nas |
| **阿里云** | SLB/ALB/NLB | https://www.alibabacloud.com/product/server-load-balancer | https://www.alibabacloud.com/help/slb |

---

## 参考资源

| 资源 | URL |
|------|-----|
| Kubernetes 官方文档 | https://kubernetes.io/docs/ |
| CNCF Landscape | https://landscape.cncf.io/ |
| Awesome Kubernetes | https://github.com/ramitsurana/awesome-kubernetes |
| Kubernetes GitHub | https://github.com/kubernetes/kubernetes |
| CNCF 项目列表 | https://www.cncf.io/projects/ |

---

**表格底部标记**: Kusheet Project | 作者: Allen Galler (allengaller@gmail.com)
