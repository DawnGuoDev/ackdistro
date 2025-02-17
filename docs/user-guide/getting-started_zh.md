# 开始

## 安装方法
通过以下Sealer指令，您可以快速地在离线环境搭建一套ACK Distro集群，无需到达公有云就可以感受和ACK一致的使用体验。您也可以查阅[Sealer Get-Started](https://github.com/alibaba/sealer/blob/main/docs/design)来获得更全面的集群使用方法。

### 快速创建ACK Distro集群
在创建集群之前，请根据[部署要求](requirements_zh.md)来检查您的环境是否满足ACK Distro的部署要求。

获取sealer：

```bash
ARCH=amd64 # or arm64
wget http://ack-a-aecp.oss-cn-hangzhou.aliyuncs.com/ack-distro/sealer/sealer-0.9.2-beta2-linux-${ARCH}.tar.gz -O sealer-latest-linux-${ARCH}.tar.gz && \
      tar -xvf sealer-latest-linux-${ARCH}.tar.gz -C /usr/bin
```

使用sealer获取ACK Distro制品，并创建集群：

```bash
sealer run ack-agility-registry.cn-shanghai.cr.aliyuncs.com/ecp_builder/ackdistro:v1-22-15-ack-4 -m ${master_ip1}[,${master_ip2},${master_ip3}] [ -n ${worker_ip1}...] -p password
```

如果您想在离网环境安装，请按如下操作：

```bash
##########################################################
# 以下操作在联网环境执行
# 使用sealer pull拉取ACK-D集群镜像；
# 可以通过--platform拉取指定架构的集群镜像，多种架构以,隔开，例如--platform linux/amd64,linux/arm64
sealer --platform linux/amd64 pull ack-agility-registry.cn-shanghai.cr.aliyuncs.com/ecp_builder/ackdistro:v1-22-15-ack-4

# 保存集群镜像为tar文件
sealer save ack-agility-registry.cn-shanghai.cr.aliyuncs.com/ecp_builder/ackdistro:v1-22-15-ack-4 -o ackdistro.tar

##########################################################
# 以下操作在离网环境执行
将ackdistro.tar传输到离网环境

sealer load -i ackdistro.tar

然后再照常执行sealer run
```

查看集群状态：

```bash
kubectl get cs
```

### 【进阶】使用生产级别的配置创建Distro集群

ACK Distro有丰富的生产级别集群管理经验，我们目前提供了以下生产级别的功能。

#### 1) 管理K8s管控组件的分区
> 对K8s管控进行分区隔离和容量管理，可以提升集群性能以及稳定性。

如果想让ACK Distro更好地管理它使用的磁盘，请按需准备好裸的数据盘（无需分区及挂载）：

- EtcdDevice: 分配给etcd的磁盘，容量必须大于20GiB，IOPS>3300，仅Master节点需要
- StorageDevice: 分配给docker和kubelet的磁盘的盘符
- DockerRunDiskSize, KubeletRunDiskSize: 分配给docker和kubelet的磁盘分区大小，默认各100GiB；ACK-D使用[LVM](https://wiki.archlinux.org/title/LVM)来管理磁盘分区，因此您可以在运维阶段按需伸缩磁盘分区的大小

准备好磁盘后，配置您的ClusterFile文件

```yaml
apiVersion: sealer.cloud/v2
kind: Cluster
metadata:
  name: my-cluster # must be my-cluster
spec:
  image: ack-agility-registry.cn-shanghai.cr.aliyuncs.com/ecp_builder/ackdistro:v1-22-15-ack-4
  env:
    - EtcdDevice=/dev/vdb # EtcdDevice is device for etcd, default is "", which will use system disk
    - StorageDevice=/dev/vdc # StorageDevice is device for kubelet and container daemon, default is "", which will use system disk
    - YodaDevice=/dev/vdd # YodaDevice is device for open-local, if not specified, open local can't provision pv
    - DockerRunDiskSize=100 # unit is GiB, capacity for /var/lib/docker, default is 100
    - KubeletRunDiskSize=100 # unit is GiB, capacity for /var/lib/kubelet, default is 100
  ssh:
    passwd: "password"
  hosts:
    - ips: # support ipv6
        - 1.1.1.1
        - 2.2.2.2
        - 3.3.3.3
      roles: [ master ] # add role field to specify the node role
      env: # all env are NOT necessary, rewrite some nodes has different env config
        - EtcdDevice=/dev/vdb
        - StorageDevice=/dev/vde
    - ips: # support ipv6
        - 4.4.4.4
        - 5.5.5.5
      roles: [ node ]
```

```bash
# 使用sealer进行高阶部署
sealer run -f ClusterFile
```

#### 2) 灵活配置ssh访问通道

- 支持ssh私钥方式：需要将对应的公钥文件通过ssh-copy-id或者其他方式下发到集群内所有节点
- 支持为不同节点组配置不同的ssh访问方式
- 支持sudo user模式，要求该user有免密sudo的权限

```yaml
apiVersion: sealer.cloud/v2
kind: Cluster
metadata:
  name: my-cluster
spec:
  ...
  ssh:
    passwd: "password"
    #user: root # default is root
    #port: "22" # default is 22
    #pk: /root/.ssh/id_rsa
    #pkPasswd: xxx
  hosts:
    - ips:
        - 1.1.1.1
      ssh:
        user: root # sudo user, default is root
        passwd: passwd
        port: "22"
      ...
    - ips: # use default ssh
        - 4.4.4.4
      roles: [ node ]
      ...
  ...
```

#### 3) 使用轻量版镜像

在v1-22-15-ack-4、v1-20-11-ack-17之后的版本，ACK-D会同时提供全量版和轻量版两个模式的镜像，轻量版的tag为"${全量版tag}-lite"，例如v1-22-15-ack-4-lite

轻量版的镜像(约0.4GiB)相比全量版(约1.4GiB)要小很多，主要是因为轻量版镜像没有将ACK-D依赖的全部容器镜像保存下来，因此，如果需要使用轻量版镜像，需要满足以下两点要求：

1. 待部署的集群的所有节点，必须可以访问到ACK—D的官方容器镜像仓库：ack-agility-registry.cn-shanghai.cr.aliyuncs.com
2. 按照如下方式配置.spec.registry，注意：externalRegistry和localRegistry都需要

```yaml
apiVersion: sealer.cloud/v2
kind: Cluster
metadata:
  name: my-cluster
spec:
  ...
  registry:
    externalRegistry: # external registry configuration
      domain: ack-agility-registry.cn-shanghai.cr.aliyuncs.com # if use lite mode image, externalRegistry must be set as this
    localRegistry: # local registry configuration
      domain: sea.hub # domain for local registry, default is sea.hub 
      port: 5000 # port for local registry, default is 5000
  ...
```

#### 4) 使用集群预检工具

集群预检工具可以在集群部署之前检查出可能影响集群稳定性的隐患。

```bash
# When deploying a cluster, the cluster precheck tool will run by default. If there is a precheck error ErrorX, but you think the error can be ignored, please do as follows
# specify IgnoreErrors=ErrorX[,ErrorY] in .spec.env of ClusterFile, and run again
sealer run -f ClusterFile

# Also you can ignore all errors

# specify SkipPreflight=true in .spec.env of ClusterFile, and run again
sealer run -f ClusterFile
```

#### 5) 使用集群健康检查工具

集群健康检查工具，可以一键检查集群是否健康。集群部署完成后，会默认触发一次健康检查，检查不通过会直接报错；之后，健康检查会周期性运行。

```bash
#您可以查询上一次周期运行的健康检查结果
trident health-check

#您也可以触发一次全新的健康检查
trident health-check --trigger-all

#更多功能
trident health-check --help
```

#### 6) 配置容器运行时

目前，ACK-D同时提供了docker和containerd两个容器运行时，并会在1.24的K8s版本中停止支持docker，您可以通过如下配置指定容器运行时：

```yaml
apiVersion: sealer.cloud/v2
kind: Cluster
metadata:
  name: my-cluster
spec:
  ...
  containerRuntime:
    type: docker # which container runtime, support containerd/docker, default is docker
  ...
```

#### 7) 使用ipv6双栈模式
> 本节描述的是双栈模式的配置，如果您只是想使用IPv6的IP，而不需要双栈，请按1）所述的标准方式，将所有ip、ip段换成ipv6，然后部署即可

IPv6双栈的配置说明：

1. 节点IP:部署时传入的所有节点地址的地址族需要保持一致，要么都是ipv4，要么都是ipv6，ACK-Distro一定会打开双栈模式，因此会尝试额外寻找每个节点上的另一个地址族的默认路由IP，作为Second Host IP
2. SvcCIDR(如无必要，可以不填，会使用默认值):部署时必须传入两个svc网段(ipv4段和ipv6段)，用,分隔，第一个svc网段的地址族需要与所有节点的地址族保持一致，
3. PodCIDR(如无必要，可以不填，会使用默认值):与SvcCIDR一致
4. 集群组件将使用第一个PodCIDR分配的IP

```yaml
apiVersion: sealer.cloud/v2
kind: Cluster
metadata:
  name: my-cluster
spec:
  ...
  env:
    - PodCIDR=5408:4003:10bb:6a01:83b9:6360:c66d:0000/112,101.64.0.0/16
    - SvcCIDR=6408:4003:10bb:6a01:83b9:6360:c66d:0000/112,11.96.0.0/16
  hosts:
    - ips:
        - 2408:4003:10bb:6a01:83b9:6360:c66d:ed57
        - 2408:4003:10bb:6a01:83b9:6360:c66d:ed58
      roles: [ master ] # add role field to specify the node role
    - ips:
        - 2408:4003:10bb:6a01:83b9:6360:c66d:ed59
      roles: [ node ]
```

#### 8) 其他可配置项

在ClusterFile的.spec.env中，您还可以修改如下配置

- Addons: 需要部署的额外组件，目前支持[ack-node-problem-detector](https://github.com/AliyunContainerService/node-problem-detector)、paralb、kube-prometheus-crds，默认为空
- Network: 网络插件，目前支持hybridnet、calico，默认为hybridnet
- DNSDomain: Kubernetes Service Domain后缀，可自定义，默认为cluster.local
- ServiceNodePortRange: Kubernetes NodePort Service端口号范围，可自定义，默认为30000-32767
- EnableLocalDNSCache: 是否打开Local DNS Cache功能，默认为false
- RemoveMasterTaint: 是否自动去除master污点，默认为false
- CertSANs: 需要为APIServer证书额外签发的域名/IP
- IgnoreErrors: 需要忽略的预检错误项
- TrustedRegistry: 需要让容器运行时信任的镜像仓库地址

```yaml
apiVersion: sealer.cloud/v2
kind: Cluster
metadata:
  name: my-cluster # must be my-cluster
spec:
  ...
  env: # all env are NOT necessary
    - Addons=paralb,kube-prometheus-crds,ack-node-problem-detector # addons to install, now support paralb, kube-prometheus-crds, ack-node-problem-detector
    - Network=hybridnet # support hybridnet/calico, default is hybridnet
    - DNSDomain=cluster.local # default is cluster.local
    - ServiceNodePortRange=30000-32767 # default is 30000-32767
    - EnableLocalDNSCache=false # enable local dns cache component, default is false
    - RemoveMasterTaint=false # remove master taint or not, default is false
    - CertSANs=1.1.1.1 # extra cert sans, if gatewayInternalIP not empty, must set it in CertSANs too
    - IgnoreErrors=OS # ignore errors for preflight
    - TrustedRegistry=your.registry.url # Registry Domain to be trusted by container runtime
  ...
```

### 运维ACK Distro集群

#### 扩容节点

```bash
sealer join -m ${master_ip1}[,${master_ip2},${master_ip3}] [ -n ${worker_ip1}...]
```

#### 缩容节点

```bash
sealer delete -m ${master_ip1}[,${master_ip2},${master_ip3}] [ -n ${worker_ip1}...]
```

#### 为APIServer证书增签新的域名/IP

```bash
sealer cert --alt-names ${new_apiserver_ip},${new_apiserver_domain}
```

#### 扩容open-local存储池

```bash
# if follow not exist, cp /root/.sealer/Clusterfile .
vim Clusterfile

---
apiVersion: sealer.cloud/v2
kind: Cluster
spec:
  image: ack-agility-registry.cn-shanghai.cr.aliyuncs.com/ecp_builder/ackdistro:v1-22-15-ack-4
  env:
    # add new device /dev/vde for open-local, if more than one, join them with ','
    - YodaDevice=/dev/vde

trident on-sealer -f Clusterfile  --sealer
```

#### etcd周期备份

无需配置，默认每天凌晨2点进行etcd备份，如需恢复etcd，可以查看任意master节点的/backup/etcd/snapshots/目录，获取备份文件，然后根据https://etcd.io/docs/v3.3/op-guide/recovery/进行恢复。

#### K8s集群审计日志

无需配置，默认仅记录写操作，对于3m+3w集群，可以用1GiB空间记录约72h的集群写操作，审计日志文件存储在所有Master节点的/var/log/kubernetes/audit.log

### 清理ACK Distro集群

```bash
sealer delete -a
```

## 使用方法
### Kubernetes使用方法
请参考Alibaba帮助中心、Kubernetes社区获取标准Kubernetes的使用方法：

- [https://help.aliyun.com/document_detail/309552.html](https://help.aliyun.com/document_detail/309552.html)
- [https://kubernetes.io/#](https://kubernetes.io/#)

### 网络插件的使用方法：
[Hybridnet 使用手册](https://github.com/alibaba/hybridnet/wiki)

### 存储插件的使用方法：
[Open-Local 本地存储插件用户手册](https://github.com/alibaba/open-local/blob/main/docs/user-guide/user-guide_zh_CN.md)

### 使用ACK纳管ACK-Distro集群：
[https://help.aliyun.com/document_detail/121053.html](https://help.aliyun.com/document_detail/121053.html)
