#!/bin/bash

source config
curl https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml -o kube-flannel.yml

function separate_ip_mask {
  ip_mask=$1
  ip=$(echo $ip_mask | cut -d'/' -f1)
  mask=$(echo $ip_mask | cut -d'/' -f2)
  echo "$ip $mask"
}

result=$(separate_ip_mask "$K8S_PODSUBNET")
ip=$(echo $result | cut -d' ' -f1)
mask=$(echo $result | cut -d' ' -f2)

if [[ "$(uname)" == "Darwin" ]];
then
    sed -i "" "s/      \"Network\": \"10.244.0.0\/16\",/      \"Network\": \"${ip}\/${mask}\",/g" kube-flannel.yml
else
    sed -i "s/      \"Network\": \"10.244.0.0\/16\",/      \"Network\": \"${ip}\/${mask}\",/g" kube-flannel.yml
fi

kubectl apply -f kube-flannel.yml
