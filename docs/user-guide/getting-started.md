# Getting started

## Installation
With the following commands, you can quickly install an ACK Distro cluster in an offline environment and experience the same user experience as ACK without reaching the public cloud. You can also check out  [Sealer Get-Started](https://github.com/alibaba/sealer/blob/main/docs/design) for a more comprehensive guide on how to use the cluster.

### Install cluster quickly
First of all, please check your cluster according to [requirements](requirements_zh.md).

Get sealer：

```bash
ARCH=amd64 # or arm64
wget http://ack-a-aecp.oss-cn-hangzhou.aliyuncs.com/ack-distro/sealer/sealer-0.9.2-beta2-linux-${ARCH}.tar.gz -O sealer-latest-linux-${ARCH}.tar.gz && \
      tar -xvf sealer-latest-linux-${ARCH}.tar.gz -C /usr/bin
```

Use sealer to get ACK Distro artifacts and create clusters:

```bash
sealer run ack-agility-registry.cn-shanghai.cr.aliyuncs.com/ecp_builder/ackdistro:v1-22-15-ack-4 -m ${master_ip1}[,${master_ip2},${master_ip3}] [ -n ${worker_ip1}...] -p password
```

If you want install ACK-D on an air-gap cluster, you can:

```bash
##########################################################
# The following command should be run on machine with internet access
# Use sealer to pull ACK-D cluster image,
# Also you can use --platform to specify the arch of cluster image you want to pull, if you want pull multi archs, please use ',' to join them, for example: --platform linux/amd64,linux/arm64
sealer --platform linux/amd64 pull ack-agility-registry.cn-shanghai.cr.aliyuncs.com/ecp_builder/ackdistro:v1-22-15-ack-4

# Save cluster image as a tar
sealer save ack-agility-registry.cn-shanghai.cr.aliyuncs.com/ecp_builder/ackdistro:v1-22-15-ack-4 -o ackdistro.tar

##########################################################
# The following command should be run on the target air gap cluster
copy ackdistro.tar to the air-gap machine.

sealer load -i ackdistro.tar

# Then execute sealer run as usual
```

Check cluster status:

```bash
kubectl get cs
```

### [Advanced] Install with production-level configuration

ACK Distro has extensive production-level cluster management experience, and we currently provide the following production-level features.

#### 1) automatically manage disk capacity for k8s daemons
> Partition isolation and capacity management for K8s control can improve cluster performance and stability.

If you want ACK Distro to better manage the disks it uses, prepare raw data disks as needed (no partitioning and mounting required):

- EtcdDevice: the disk allocated to etcd must be larger than 20GiB and IOPS>3300, only required by the Master node
- StorageDevice: the disk allocated to docker and kubelet
- DockerRunDiskSize, KubeletRunDiskSize: The size of the disk partition allocated to docker and kubelet is 100GiB by default; ACK-D uses [LVM](https://wiki.archlinux.org/title/LVM) to manage disk partitions, so you can scale the size during the operation and maintenance phase

Configure your ClusterFile:

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
# install
sealer run -f ClusterFile
```

#### 2) Flexible configuration of ssh access channel

- Support ssh private key: need to send the corresponding public key file to all nodes in the cluster through ssh-copy-id or other methods
- Support configuring different ssh access methods for different node groups
- Support sudo user mode, requiring the user to have password-free sudo permissions

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

#### 3) Use a lite image

In versions after v1-22-15-ack-4 and v1-20-11-ack-17, ACK-D will provide cluster images of both the full and lite mode. The tag of the lite mode is "${full_mode_tag}-lite", for example v1-22-15-ack-4-lite

The lightweight version of the image (about 0.4GiB) is much smaller than the full version (about 1.4GiB), mainly because the lightweight version of the image does not save all the container images that ACK-D depends on. Therefore, if you need to use the lightweight Version mirroring must meet the following two requirements:

1. All nodes of the cluster to be deployed must be able to access ack-agility-registry.cn-shanghai.cr.aliyuncs.com
2. Configure .spec.registry as follows, NOTE: both externalRegistry and localRegistry are required

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

#### 4) Use preflight

The preflight tool can detect hidden dangers that may affect the stability of the cluster before cluster deployment.

```bash
# When deploying a cluster, the cluster precheck tool will run by default. If there is a precheck error ErrorX, but you think the error can be ignored, please do as follows
# specify IgnoreErrors=ErrorX[,ErrorY] in .spec.env of ClusterFile, and run again
sealer run -f ClusterFile

# Also you can ignore all errors

# specify SkipPreflight=true in .spec.env of ClusterFile, and run again
sealer run -f ClusterFile
```

#### 5) Use health check

The cluster health check tool can check whether the cluster is healthy with one click. After the cluster deployment is completed, a health check will be triggered by default. If the check fails, an error will be reported directly; after that, the health check will run periodically.

```bash
# You can query the health check result of the last run
trident health-check

# Also you can trigger a new check
trident health-check --trigger-all

# more see
trident health-check --help
```

#### 6) Configure container runtime

Currently, ACK-D provides both docker and containerd container runtimes, and will stop supporting docker in the 1.24 K8s. You can specify the container runtime through the following configuration:

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

#### 7) IPv6 dual stack
> This section is about ipv6 dual stack configuration, if you just need ipv6 only, please use the method described in the previous section.

How to configure for IPv6 dual stack mode:

1. Node IP: The IP family of all node addresses passed needs to be consistent, either ipv4 or ipv6, ACK-Distro will definitely open the dual-stack mode, so it will try to find an additional IP address on each node corresponding to the default route of another address family, as the Second Host IP
2. SvcCIDR (if not necessary, you can skip set it, and the default value will be used): two svc network segments (ipv4 segment and ipv6 segment) must be passed, separated by ','. The IP family of the first service cidr need to be consistent with the IP family of all nodes,
3. PodCIDR (if not necessary, you can skip set it, and the default value will be used): same as SvcCIDR
4. The control plane pod will use the IP assigned by the first PodCIDR

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

#### 8) Other configs

In ClusterFile's .spec.env, you can also modify the following configuration

- Addons: Additional components that need to be deployed, currently support [ack-node-problem-detector](https://github.com/AliyunContainerService/node-problem-detector), paralb, kube-prometheus-crds, the default is empty
- Network: The network plugin to use, currently supports hybridnet, calico, the default is hybridnet
- DNSDomain: Kubernetes Service Domain suffix, can be customized, the default is "cluster.local"
- ServiceNodePortRange: Kubernetes NodePort Service port range, which can be customized, the default is 30000-32767
- EnableLocalDNSCache: Whether to enable the Local DNS Cache, the default is false
- RemoveMasterTaint: Whether to automatically remove the master taint, the default is false
- CertSANs: The domain name/IP that needs to be additionally issued for the APIServer certificate
- IgnoreErrors: Preflight error items to ignore
- TrustedRegistry: The registry domain that needs to be trusted by the container runtime

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

### Operation and maintenance cluster

#### Scale-up node

```bash
sealer join -m ${master_ip1}[,${master_ip2},${master_ip3}] [ -n ${worker_ip1}...]
```

#### Scale-down node

```bash
sealer delete -m ${master_ip1}[,${master_ip2},${master_ip3}] [ -n ${worker_ip1}...]
```

#### Add new SANs for APIServer

```bash
sealer cert --alt-names ${new_apiserver_ip},${new_apiserver_domain}
```

#### Scale-up open-local pool

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

#### etcd cron backup

No configuration is required. By default, etcd is backed up at 2 am every day. If you need to restore etcd, you can check the /backup/etcd/snapshots/ directory of any master node to obtain the backup file, and then follow https://etcd.io/docs/v3.3/op-guide/recovery/ for recovery.

#### K8s cluster audit log

No configuration is required. By default, only write operations are recorded. For a 3m+3w cluster, 1GiB space can be used to record about 72h of cluster write operations. Audit log files are stored in /var/log/kubernetes/audit.log of all Master nodes

### Cleanup cluster

```bash
sealer delete -a
```

## Usage
### Kubernetes Usage
Please refer to Alibaba Help Center and Kubernetes community for the usage of standard Kubernetes:

- [https://help.aliyun.com/document_detail/309552.html](https://help.aliyun.com/document_detail/309552.html)
- [https://kubernetes.io/#](https://kubernetes.io/#)

### ACK Distro’s recommendation on how to use the network plugin:
[Hybridnet user manual](https://github.com/alibaba/hybridnet/wiki)

### ACK-Distro’s recommendation on how to use the storage plugin:
[Open-local local storage plug-in user manul](https://github.com/alibaba/open-local/blob/main/docs/user-guide/user-guide_zh_CN.md)

### Use ACK to manage ACK-Distro cluster:
[https://help.aliyun.com/document_detail/121053.html](https://help.aliyun.com/document_detail/121053.html)
