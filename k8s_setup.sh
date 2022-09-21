#!/bin/bash

set -o errexit
CURDIR=$(pwd)
KUBE_PROXY_MODE=${1:-'iptables'}
DOMAIN=${2:-'cluster.k8s.dev'}
help() {
    echo "部署kubernetes集群"
    echo "usage: sudo ./k8s.sh [iptables|ipvs|none] DOMAIN"
    echo "创建时请选择kube-proxy模式，默认为iptables"
}

if [[ "${KUBE_PROXY_MODE}" != "iptables" && "${KUBE_PROXY_MODE}" != "ipvs" && "${KUBE_PROXY_MODE}" != "none" ]]; then
    help
    exit 1
fi

cat << EOF | kind create cluster --name dev --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "0.0.0.0"
  apiServerPort: 6443
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/16"
  disableDefaultCNI: true
  kubeProxyMode: "${KUBE_PROXY_MODE}"
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
        - "${DOMAIN}"
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

sleep 10

mkdir cni-plugins \
&& wget -O ./cni-plugins/cni-plugins.tgz https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz \
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
