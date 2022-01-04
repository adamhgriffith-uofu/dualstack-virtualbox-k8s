#!/bin/bash

# Enable strict mode:
set -euo pipefail

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~ Configure Kubernetes Master Node                                                ~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

echo "Initializing the Kubernetes cluster with Kubeadm.."
kubeadm init --apiserver-advertise-address=192.168.56.10 --pod-network-cidr=192.168.0.0/16

echo "Enabling kubectl access for root..."
mkdir -p "$HOME/.kube"
cp -i "/etc/kubernetes/admin.conf" "$HOME/.kube/config"
chown $(id -u):$(id -g) "$HOME/.kube/config"

echo "Creating Pod network via Calico..."
kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml

echo "Creating new cluster join script..."
touch /vagrant_work/join.sh
chmod +x /vagrant_work/join.sh
kubeadm token create --print-join-command > /vagrant_work/join.sh

echo "Creating load-balancing via MetalLB..."
kubectl create -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/namespace.yaml
kubectl create -f https://raw.githubusercontent.com/metallb/metallb/v0.10.2/manifests/metallb.yaml
cat <<EOF > /tmp/metallb-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.56.11-192.168.56.12
EOF
kubectl apply -f /tmp/metallb-config.yaml