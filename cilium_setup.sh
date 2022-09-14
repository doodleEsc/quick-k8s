#!/bin/bash

set -o errexit

CURDIR=$(pwd)

CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz ${CURDIR}/
docker cp ${CURDIR}/cilium dev-control-plane:/usr/local/bin/cilium
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum} cilium

HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz ${CURDIR}/
docker cp ${CURDIR}/hubble dev-control-plane:/usr/local/bin/hubble
rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum} hubble

KIND_CIDR=$(docker inspect -f '{{(index .IPAM.Config 0).Subnet}}' kind)

helm repo add cilium https://helm.cilium.io/

helm install cilium cilium/cilium --version 1.12.1 \
    --namespace kube-system \
    --set tunnel=disabled \
    --set image.pullPolicy=IfNotPresent \
    --set ipam.mode=kubernetes \
    --set kubeProxyReplacement=strict \
    --set k8sServiceHost=dev-control-plane \
    --set k8sServicePort=6443 \
    --set autoDirectNodeRoutes=true \
    --set localRedirectPolicy=true \
    --set ipv4NativeRoutingCIDR=${KIND_CIDR} \
    --set ipam.operator.clusterPoolIPv4PodCIDR=10.244.0.0/16 \
    --set cgroup.hostRoot=/sys/fs/cgroup \
    --set nodePort.enabled=true \
    --set socketLB.enabled=true \
    --set hostPort.enabled=true \
    --set externalIPs.enabled=true \
    --set hubble.enabled=true \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true \
    --set hubble.ui.service.type=NodePort \
    --set hubble.ui.service.type=NodePort \
    --set hubble.ui.service.nodePort=30001

