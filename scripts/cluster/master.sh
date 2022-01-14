#!/bin/bash

# Enable strict mode:
set -euo pipefail

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~ Configure Kubernetes Master Node                                                ~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

echo "Initializing the Kubernetes cluster with Kubeadm.."
kubeadm config images pull
cat << EOF > /tmp/kubeadm-config.yml
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "${IPV4_ADDR}"
  bindPort: 6443
nodeRegistration:
  kubeletExtraArgs:
    node-ip: ${IPV4_ADDR},${IPV6_ADDR}
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
networking:
  podSubnet: fc00:db8:42:0::/56,10.233.0.0/16
  serviceSubnet: fc00:db8:42:1::/112,10.233.64.0/16
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
---
EOF
kubeadm init --config=/tmp/kubeadm-config.yml

echo "Enabling kubectl access for root..."
mkdir -p "$HOME/.kube"
cp -i "/etc/kubernetes/admin.conf" "$HOME/.kube/config"
chown $(id -u):$(id -g) "$HOME/.kube/config"

echo "Creating Pod network via Calico..."
kubectl apply -f /vagrant/resources/manifests/calico.yml
#kubectl apply -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
#kubectl apply -f https://docs.projectcalico.org/manifests/custom-resources.yaml

echo "Creating new cluster join script..."
touch /vagrant_work/join.sh
chmod +x /vagrant_work/join.sh
kubeadm token create --print-join-command > /vagrant_work/join.sh

#echo "Creating load-balancing via MetalLB..."
#kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/manifests/namespace.yaml
#kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/manifests/metallb.yaml
#cat <<EOF > /tmp/metallb-config.yaml
#apiVersion: v1
#kind: ConfigMap
#metadata:
#  namespace: metallb-system
#  name: config
#data:
#  config: |
#    address-pools:
#    - name: default
#      protocol: layer2
#      addresses:
#      - 192.168.56.11-192.168.56.12
#EOF
#kubectl apply -f /tmp/metallb-config.yaml

# TODO: Put the master node taint back. This is temporary while debugging.
echo "Temporarily removing master taint for debugging..."
kubectl taint nodes --all node-role.kubernetes.io/master-