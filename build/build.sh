#!/usr/bin/env bash

set -x;set -e

if ! which sealer;then
    echo "sealer not found, please download latest sealer"
    exit 1
fi

KUBE_VERSION=$1
TAG=$2
MULTI_ARCH=$3
ARCH=$4

if [[ "$KUBE_VERSION" == "" ]];then
    echo "Usage: bash build.sh VERSION"
    exit 1
fi

if [ ! -d $KUBE_VERSION ];then
    echo "Directory $KUBE_VERSION not found"
    exit 1
fi

mkdir -p _build/${KUBE_VERSION}
for f in chart etc plugins scripts statics yamls Kubefile VERSION;do
  cp -r $f _build/${KUBE_VERSION}/ || true
done
cp -r ./${KUBE_VERSION}/* _build/${KUBE_VERSION}/
cd _build/${KUBE_VERSION}

echo -n "${KUBE_VERSION}" > KUBE_VERSION
cat imageList-standard | grep koord-scheduler | cut -d "/" -f 3 > KOORD_SCHE_VERSION

if [[ "$TAG" == "" ]];then
    echo "Usage: bash build.sh VERSION TAG"
    exit 1
fi

if [[ "$MULTI_ARCH" == "" ]];then
    echo "MULTI_ARCH is not set, default is false, if you want build multi arch, please run 'bash build.sh VERSION TAG true'"
    MULTI_ARCH=false
fi

if [[ "$ARCH" == "" ]];then
    echo "ARCH is not set, default is amd64, if you want build other arch, please run 'bash build.sh VERSION TAG false ARCH'"
    ARCH=amd64
fi

archs=$ARCH
if [[ "$MULTI_ARCH" == "true" ]];then
    archs="amd64 arm64"
fi

platform=""
for arch in $archs;do
  platform="${platform},linux/${arch}"
done
platform=${platform:1}

trident_version=1.14.1
if [ "$SKIP_DOWNLOAD_BINS" != "true" ];then
    for arch in $archs;do
        rm -rf ${arch}
        mkdir -p ${arch}/bin
        mkdir -p ${arch}/rpm
        mkdir -p ${arch}/tgz

        bins=(kubectl kubelet kubeadm)
        for bin in ${bins[@]};do
            wget https://ack-a-aecp.oss-cn-hangzhou.aliyuncs.com/ack-distro/bin/${arch}/${KUBE_VERSION}/${bin} -O ${arch}/bin/${bin}
        done

        bins=(helm seautil mc etcdctl nerdctl velero)
        for bin in ${bins[@]};do
            wget https://ack-a-aecp.oss-cn-hangzhou.aliyuncs.com/ack-distro/bin/${arch}/${bin} -O ${arch}/bin/${bin}
        done

        wget "https://ack-a-aecp.oss-cn-hangzhou.aliyuncs.com/trident/release/trident_license_off-linux-${arch}_${trident_version}.bin" -O ${arch}/bin/trident

        if [ "$arch" == "amd64" ];then
          rpm_suffix=x86_64
        else
          rpm_suffix=aarch64
        fi

        rpms=(kubernetes-cni)
        for rpm in ${rpms[@]};do
            rpmfile=${rpm}.${rpm_suffix}.rpm
            wget https://ack-a-aecp.oss-cn-hangzhou.aliyuncs.com/ack-distro/rpm/${arch}/${KUBE_VERSION}/${rpmfile} -O ${arch}/rpm/${rpmfile}
        done

        rpms=(socat-1.7.3.2-2.el7 libseccomp-2.3.1-4.el7)
        for rpm in ${rpms[@]};do
            rpmfile=${rpm}.${rpm_suffix}.rpm
            wget https://ack-a-aecp.oss-cn-hangzhou.aliyuncs.com/ack-distro/rpm/${arch}/${rpmfile} -O ${arch}/rpm/${rpmfile}
        done

        if [ "$arch" == "amd64" ];then
            wget https://ack-a-aecp.oss-cn-hangzhou.aliyuncs.com/ack-distro/tgz/${arch}/nvidia.tgz -O ${arch}/tgz/nvidia.tgz
        fi
        tgzs=(lvm-el7.tgz lvm-el8.tgz s3fs-el7.tgz s3fs-el8.tgz)
        for tgz in ${tgzs[@]};do
            wget https://ack-a-aecp.oss-cn-hangzhou.aliyuncs.com/ack-distro/tgz/${arch}/${tgz} -O ${arch}/tgz/${tgz}
        done

        wget https://ack-a-aecp.oss-cn-hangzhou.aliyuncs.com/ack-distro/tgz/${arch}/cri-containerd-cni-1.5.13-linux-${arch}.tar.gz -O ${arch}/tgz/containerd.tgz
    done
fi

version=`git log -1 --pretty=format:%h` || true
if [ "$version" != "" ];then
  echo -n  > VERSION
fi

#if [ "$(git branch --show-current)" == "main" ]; then
#  wget https://gosspublic.alicdn.com/ossutil/1.7.8/ossutil64?spm=a2c4g.11186623.0.0.bcbf1770zMJhXK -O ossutil64
#  chmod +x ossutil64
#  ./ossutil64 --endpoint http://oss-cn-hangzhou.aliyuncs.com cp -f build/imageList oss://ack-a-aecp/ack-agility/ack-distro-imagelist-main.info
#fi

#
# shellcheck disable=SC2016
#sudo sed -i "s/v1.19.8/$k8s_version/g" rootfs/etc/kubeadm.yml ##change k8s_version

if [ "$BUILD_MODE" == "lite" ];then
  cp -f imageList-lite imageList
else
  cp -f imageList-standard imageList
fi

# Build sealer image
sealer rmi ack-agility-registry.cn-shanghai.cr.aliyuncs.com/ecp_builder/ackdistro:${TAG} || true
sealer build -f Kubefile -t ack-agility-registry.cn-shanghai.cr.aliyuncs.com/ecp_builder/ackdistro:${TAG} --platform ${platform} .