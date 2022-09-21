#!/bin/bash

set -o errexit
CURDIR=$(pwd)
MODE=${1:-'mesh'}

help() {
    echo "部署calico网络插件"
    echo "usage: sudo ./calico_setup.sh [mesh|rr]"
    echo "默认为full-mesh模式"
}

if [[ "${MODE}" != "mesh" && "${MODE}" != "rr" ]]; then
    help
    exit 1
fi

curl -L https://github.com/projectcalico/calico/releases/download/v3.24.1/calicoctl-linux-amd64 -o calicoctl \
&& chmod +x calicoctl

podman cp ${CURDIR}/calicoctl dev-control-plane:/usr/local/bin/calicoctl
podman cp ${CURDIR}/calicoctl dev-worker:/usr/local/bin/calicoctl
podman cp ${CURDIR}/calicoctl dev-worker2:/usr/local/bin/calicoctl
# podman cp ${CURDIR}/calicoctl dev-worker3:/usr/local/bin/calicoctl

rm -f ${CURDIR}/calicoctl

curl https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/calico-typha.yaml -o calico.yaml

if [[ "$(uname)" == "Darwin" ]];
then
    sed -i "" "s/            # - name: CALICO_IPV4POOL_CIDR/            - name: CALICO_IPV4POOL_CIDR/g" calico.yaml
    sed -i "" "s/            #   value: \"192.168.0.0\/16\"/              value: \"10.224.0.0\/16\"/g" calico.yaml
else
    sed -i "s/            # - name: CALICO_IPV4POOL_CIDR/            - name: CALICO_IPV4POOL_CIDR/g" calico.yaml
    sed -i "s/            #   value: \"192.168.0.0\/16\"/              value: \"10.224.0.0\/16\"/g" calico.yaml
fi

if [[ "${MODE}" == "rr" ]]; then
    if [[ "$(uname)" == "Darwin" ]];
    then
        sed -i "" "s/              value: \"Always\"/              value: \"Never\"/g" calico.yaml
    else
        sed -i "s/              value: \"Always\"/              value: \"Never\"/g" calico.yaml
    fi
fi

kubectl apply -f ${CURDIR}/calico.yaml

if [[ "${MODE}" == "rr" ]]; then

cat << 'EOF' >> bgpconfiguration.yaml
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  logSeverityScreen: Info
  nodeToNodeMeshEnabled: false
  asNumber: 64512
EOF

cat << 'EOF' >> bgppeer.yaml
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: peer-with-route-reflectors
spec:
  nodeSelector: all()
  peerSelector: route-reflector == "true"
EOF

podman cp ${CURDIR}/bgpconfiguration.yaml dev-control-plane:/root/bgpconfiguration.yaml
podman cp ${CURDIR}/bgppeer.yaml dev-control-plane:/root/bgppeer.yaml

echo "Waiting 180 seconds to ensure calico node running"
sleep 180

kubectl label node dev-control-plane route-reflector=true

podman exec -it dev-control-plane /usr/local/bin/calicoctl create -f /root/bgpconfiguration.yaml
podman exec -it dev-control-plane /usr/local/bin/calicoctl create -f /root/bgppeer.yaml

rm -f ${CURDIR}/bgppeer.yaml ${CURDIR}/bgpconfiguration.yaml

fi

echo "Calico CNI Plugin Deployed..."

rm -f ${CURDIR}/calico.yaml
