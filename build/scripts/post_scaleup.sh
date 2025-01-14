#!/usr/bin/env bash

scripts_path=$(cd `dirname $0`; pwd)
source "${scripts_path}"/utils.sh

set -x

export KUBECONFIG=/etc/kubernetes/admin.conf

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

sleep 15
if [ "${ComponentToInstall}" != "" ];then
  ComponentToInstallFlag="--component-to-install ${ComponentToInstall}"
fi
if [ ! -f /root/.sealer/Clusterfile ];then
  mkdir -p /root/.sealer/
  kubectl -n kube-system get cm sealer-clusterfile -ojsonpath='{.data.Clusterfile}' > /root/.sealer/Clusterfile
fi
trident on-sealer -f /root/.sealer/Clusterfile --sealer --dump-managed-cluster ${ComponentToInstallFlag}
if [ $? -ne 0 ];then
  exit 1
fi