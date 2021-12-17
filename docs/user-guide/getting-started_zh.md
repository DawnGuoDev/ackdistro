# 开始
## 安装方法
通过以下Sealer指令，您可以快速地在离线环境搭建一套ACK Distro集群，无需到达公有云就可以感受和ACK一致的使用体验。您也可以查阅[Sealer Get-Started](https://github.com/alibaba/sealer/blob/main/docs/user-guide/get-started.md)来获得更全面的集群使用方法。

### 创建集群
获取最新版sealer：
```bash
wget "https://acs-ecp.oss-cn-hangzhou.aliyuncs.com/tmp/sealer" -O /usr/bin/sealer && chmod +x /usr/bin/sealer 
```
使用sealer获取ACK Distro制品，并创建集群：
```bash
sealer run aecp-turbo-registry.cn-hangzhou.cr.aliyuncs.com/oecp/ackdistro:v1.20.4-aliyun.1-alpha5 -m ${master_ip1}[,${master_ip2},${master_ip3}] [ -n ${worker_ip1}...] -p password
```
查看集群状态：
```bash
kubectl get cs
```

### 运维集群
扩容节点：
```bash
sealer join -m ${master_ip1}[,${master_ip2},${master_ip3}] [ -n ${worker_ip1}...]
```
缩容节点：
```bash
sealer delete -m ${master_ip1}[,${master_ip2},${master_ip3}] [ -n ${worker_ip1}...]
```

### 清理集群
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