#!/bin/bash

set -o errexit
source config
CURDIR=$(pwd)

cat << EOF | kind create cluster --name dev --image kindest/node:$K8S_VERSION --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "0.0.0.0"
  apiServerPort: 6443
  podSubnet: "$K8S_PODSUBNET"
  serviceSubnet: "$K8S_SVCSUBNET"
  disableDefaultCNI: true
  kubeProxyMode: "$KUBE_PROXY_MODE"
nodes:
  - role: control-plane
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "ingress-ready=true"
    - |
      kind: ClusterConfiguration
      apiServer:
        certSANs:
        - "$K8S_API_DOMAIN"
        - "127.0.0.1"
        - "0.0.0.0"
    extraPortMappings:
    - containerPort: 80
      hostPort: 8080
      protocol: TCP
    - containerPort: 443
      hostPort: 8443
      protocol: TCP
    - containerPort: 30000
      hostPort: 30000
      protocol: TCP
    - containerPort: 30001
      hostPort: 30001
      protocol: TCP
    - containerPort: 30002
      hostPort: 30002
      protocol: TCP
    - containerPort: 30003
      hostPort: 30003
      protocol: TCP
  - role: worker
  - role: worker
  - role: worker
EOF

sleep 20

CNI_PLUGINS_VERSION=$(curl --silent "https://api.github.com/repos/containernetworking/plugins/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

mkdir cni-plugins \
&& wget -O ./cni-plugins/cni-plugins.tgz https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION}.tgz \
&& tar xf ./cni-plugins/cni-plugins.tgz -C ./cni-plugins \
&& rm -f ./cni-plugins/cni-plugins.tgz

docker cp ./cni-plugins dev-control-plane:/cni-plugins
docker exec -it dev-control-plane /bin/bash -c "mv /cni-plugins/* /opt/cni/bin"

docker cp ./cni-plugins dev-worker:/cni-plugins
docker exec -it dev-worker /bin/bash -c "mv /cni-plugins/* /opt/cni/bin"

docker cp ./cni-plugins dev-worker2:/cni-plugins
docker exec -it dev-worker2 /bin/bash -c "mv /cni-plugins/* /opt/cni/bin"

docker cp ./cni-plugins dev-worker3:/cni-plugins
docker exec -it dev-worker3 /bin/bash -c "mv /cni-plugins/* /opt/cni/bin"

rm -rf ./cni-plugins
