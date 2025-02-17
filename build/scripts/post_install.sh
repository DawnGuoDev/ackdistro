#!/usr/bin/env bash

scripts_path=$(cd `dirname $0`; pwd)
source "${scripts_path}"/utils.sh

set -x

export DNSDomain=${DNSDomain:-cluster.local}
export HostIPFamily=${HostIPFamily:-4}
export Master0IP=${HostIP}
export RegistryIP=${RegistryIP:-${Master0IP}}
export EnableLocalDNSCache=${EnableLocalDNSCache:-false}
export MTU=${MTU:-1440}
export IPIP=${IPIP:-Always}
export IPv6DualStack=${IPv6DualStack:-true}
export IPAutoDetectionMethod=${IPAutoDetectionMethod:-can-reach=8.8.8.8}
export DisableFailureDomain=${DisableFailureDomain:-false}
export RegistryURL=${RegistryURL:-sea.hub:5000}
export SuspendPeriodHealthCheck=${SuspendPeriodHealthCheck:-false}
export SuspendPeriodBroadcastHealthCheck=${SuspendPeriodBroadcastHealthCheck:-false}
export Addons=${Addons}
export Network=${Network}
export RemoveMasterTaint=${RemoveMasterTaint}
export PlatformType=${PlatformType}
export DefaultStorageClass=${DefaultStorageClass:-yoda-lvm-default}
export ComponentToInstall=${ComponentToInstall}
export GenerateClusterInfo=${GenerateClusterInfo:-true}
export ParalbHostInterface=${ParalbHostInterface}
export deployMode=${deployMode:-offline}
export gatewayDomain=${gatewayDomain:-cnstack.local}
if [ "$DisableGateway" != "true" ];then
  export gatewayExposeMode=${gatewayExposeMode:-ip_domain}
  export gatewayInternalIP=${gatewayInternalIP:-${Master0IP}}
  export gatewayExternalIP=${gatewayExternalIP:-${Master0IP}}
  export gatewayPort=${gatewayPort:-30383}
  export gatewayAPIServerPort=${gatewayAPIServerPort:-30384}
fi
export ingressAddress=${ingressAddress:-ingress.${gatewayDomain}}
export ingressInternalIP=${ingressInternalIP:-${Master0IP}}
export ingressExternalIP=${ingressExternalIP:-${Master0IP}}
export ingressHttpPort=${ingressHttpPort:-80}
export ingressHttpsPort=${ingressHttpsPort:-443}
export harborAddress=${harborAddress:-harbor.${gatewayDomain}}
export vcnsOssAddress=${vcnsOssAddress:-vcns-oss.${gatewayDomain}}
export apiServerInternalIP=${apiServerInternalIP}
export apiServerInternalPort=${apiServerInternalPort}
export KUBECONFIG=/etc/kubernetes/admin.conf

if [ "$Master0IP" == "" ];then
  echo "Master0IP is required"
  exit 1
fi
if [ "$HostIPFamily" == "6" ];then
  export SvcCIDR=${SvcCIDR:-4408:4003:10bb:6a01:83b9:6360:c66d:0000/112,10.96.0.0/16}
  export PodCIDR=${PodCIDR:-3408:4003:10bb:6a01:83b9:6360:c66d:0000/112,100.64.0.0/16}
else
  export SvcCIDR=${SvcCIDR:-10.96.0.0/16,4408:4003:10bb:6a01:83b9:6360:c66d:0000/112}
  if [ "$Network" == "calico" ];then
    export PodCIDR=${PodCIDR:-100.64.0.0/16}
  else
    export PodCIDR=${PodCIDR:-100.64.0.0/16,3408:4003:10bb:6a01:83b9:6360:c66d:0000/112}
  fi
fi

# process taints first
if [ "${RemoveMasterTaint}" == "true" ];then
  kubectl taint node node-role.kubernetes.io/master- --all || true
fi

if [ "${PlatformType}" != "enterprise" ];then
  kubectl label node node-role.kubernetes.io/cnstack-infra="" --all
  kubectl label node node-role.kubernetes.io/proxy="" --all
else
  kubectl taint node node-role.kubernetes.io/cnstack-infra=:NoSchedule -l node-role.kubernetes.io/cnstack-infra="" --overwrite
  kubectl taint node node-role.kubernetes.io/cnstack-infra=:NoSchedule -l node-role.kubernetes.io/proxy="" --overwrite
fi
if [ "${deployMode}" == "online" ];then
  gatewayExposeMode=ip
fi

gatewayAddress=${gatewayDomain}
if [ "$gatewayExposeMode" == "ip" ];then
  if [[ ${gatewayExternalIP} =~ ":" ]];then
    gatewayAddress=[${gatewayExternalIP}]
  else
    gatewayAddress=${gatewayExternalIP}
  fi
fi

bash ${scripts_path}/install_addons.sh
if [ $? -ne 0 ];then
  exit 1
fi

# generate cluster info
if [ "$GenerateClusterInfo" == "true" ];then
  cat >/tmp/clusterinfo-cm.yaml <<EOF
---
apiVersion: v1
data:
  deployMode: "${deployMode}"
  gatewayExposeMode: "${gatewayExposeMode}"
  gatewayAddress: "${gatewayAddress}"
  gatewayDomain: "${gatewayDomain}"
  gatewayExternalIP: "${gatewayExternalIP}"
  gatewayInternalIP: "${gatewayInternalIP}"
  gatewayPort: "${gatewayPort}"
  gatewayAPIServerPort: "${gatewayAPIServerPort}"
  ingressAddress: "${ingressAddress}"
  ingressExternalIP: "${ingressExternalIP}"
  ingressInternalIP: "${ingressInternalIP}"
  ingressHttpPort: "${ingressHttpPort}"
  ingressHttpsPort: "${ingressHttpsPort}"
  harborAddress: "${harborAddress}"
  vcnsOssAddress: "${vcnsOssAddress}"
  clusterDomain: "${DNSDomain}"
  registryURL: "${LocalRegistryURL}"
  registryExternalURL: "${LocalRegistryDomain}:5001"
  RegistryURL: "${LocalRegistryURL}"
  platformType: "${PlatformType}"
  clusterName: "cluster-local"
kind: ConfigMap
metadata:
  name: clusterinfo
  namespace: kube-public
EOF

  kubectl apply -f /tmp/clusterinfo-cm.yaml
  GenerateCAFlag="--generate-ca"
fi

sleep 15
if [ "${ComponentToInstall}" != "" ];then
  ComponentToInstallFlag="--component-to-install ${ComponentToInstall}"
fi
if [ "${PlatformCAPath}" != "" ];then
  PlatformCAFlag="--ca-path ${PlatformCAPath} --key-path ${PlatformCAKeyPath}"
fi
trident on-sealer -f /root/.sealer/Clusterfile --sealer --dump-managed-cluster ${GenerateCAFlag} ${ComponentToInstallFlag} ${PlatformCAFlag}
if [ $? -ne 0 ];then
  exit 1
fi

# set default storageclass and snapshot
kubectl annotate storageclass ${DefaultStorageClass} snapshot.storage.kubernetes.io/is-default-class="true" --overwrite
kubectl annotate storageclass ${DefaultStorageClass} storageclass.kubernetes.io/is-default-class="true" --overwrite

if [ "${SkipHealthCheck}" = "true" ];then
  exit 0
fi
sleep 15
trident health-check
if [ $? -eq 0 ];then
  exit 0
fi
echo "First time health check fail, sleep 30 and try again"
sleep 30
trident health-check --trigger-mode OnlyUnsuccessful
if [ $? -eq 0 ];then
  exit 0
fi
echo "Second time health check fail, sleep 60 and try again"
sleep 60
trident health-check --trigger-mode OnlyUnsuccessful
exit $?