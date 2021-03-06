#!/bin/bash

# Enable strict mode:
set -euo pipefail

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~ Configure Kubernetes Control Plane                                              ~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

# NOTE: Changes to CLUSTER_CIDR must be reflected in /resources/manifests/calico.yml's
#       CALICO_IPV4POOL_CIDR and CALICO_IPV6POOL_CIDR environmental variables.
API_BIND_IP=0.0.0.0
CLUSTER_CIDR=10.10.0.0/16,fc00:db8:1234:5678:8:2::/104
CLUSTER_DNS=10.20.0.10
KUBELET_HEALTHZ_BIND_IP=127.0.0.1
SERVICE_CLUSTER_IP_RANGE=10.20.0.0/16,fc00:db8:1234:5678:8:3::/112

echo "Initializing the Kubernetes cluster with Kubeadm..."
#kubeadm config images pull
cat << EOF > /tmp/kubeadm-config.yml
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${IPV4_ADDR}
nodeRegistration:
  criSocket: /var/run/containerd/containerd.sock
  name: ${HOSTNAME}
  kubeletExtraArgs:
    cluster-dns: ${CLUSTER_DNS}
    node-ip: ${IPV4_ADDR},${IPV6_ADDR}
---
apiServer:
  extraArgs:
    advertise-address: ${IPV4_ADDR}
    bind-address: ${API_BIND_IP}
    etcd-servers: https://${IPV4_ADDR}:2379
    service-cluster-ip-range: ${SERVICE_CLUSTER_IP_RANGE}
apiVersion: kubeadm.k8s.io/v1beta2
controllerManager:
  extraArgs:
    allocate-node-cidrs: 'true'
    bind-address: ${API_BIND_IP}
    cluster-cidr: ${CLUSTER_CIDR}
    node-cidr-mask-size-ipv4: '24'
    node-cidr-mask-size-ipv6: '120'
    service-cluster-ip-range: ${SERVICE_CLUSTER_IP_RANGE}
etcd:
  local:
    dataDir: /var/lib/etcd
    extraArgs:
      advertise-client-urls: https://${IPV4_ADDR}:2379
      initial-advertise-peer-urls: https://${IPV4_ADDR}:2380
      initial-cluster: ${HOSTNAME}=https://${IPV4_ADDR}:2380
      listen-client-urls: https://${IPV4_ADDR}:2379
      listen-peer-urls: https://${IPV4_ADDR}:2380
kind: ClusterConfiguration
networking:
  serviceSubnet: ${SERVICE_CLUSTER_IP_RANGE}
scheduler:
  extraArgs:
    bind-address: ${API_BIND_IP}
---
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
clusterDNS:
- ${CLUSTER_DNS}
healthzBindAddress: ${KUBELET_HEALTHZ_BIND_IP}
kind: KubeletConfiguration
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clusterCIDR: ${CLUSTER_CIDR}
kind: KubeProxyConfiguration
ipvs:
  strictARP: true
mode: ipvs
---
EOF
kubeadm init --config=/tmp/kubeadm-config.yml

echo "Enabling kubectl access for root..."
mkdir -p "$HOME/.kube"
cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
chown $(id -u):$(id -g) "$HOME/.kube/config"

echo "TEMPORARY: Copying kubeconfig (admin.conf) to /vagrant_work..."
# TODO: Figure out why worker nodes are inappropriately needing a local copy of admin.conf.
HACK_KUBECONFIG_PATH=/vagrant_work/admin.conf
cp -i /etc/kubernetes/admin.conf "${HACK_KUBECONFIG_PATH}"

echo "Removing control-plane pod taint..."
kubectl taint nodes --all node-role.kubernetes.io/master-

echo "Creating Pod network via Calico..."
cat <<EOF > /tmp/calico-config.yml
# Source: calico/templates/calico-config.yaml
# This ConfigMap is used to configure a self-hosted Calico installation.
kind: ConfigMap
apiVersion: v1
metadata:
  name: calico-config
  namespace: kube-system
data:
  # Typha is disabled.
  typha_service_name: "none"
  # Configure the backend to use.
  calico_backend: "bird"

  # Configure the MTU to use for workload interfaces and tunnels.
  # By default, MTU is auto-detected, and explicitly setting this field should not be required.
  # You can override auto-detection by providing a non-zero value.
  veth_mtu: "0"

  # The CNI network configuration to install on each node. The special
  # values in this config will be automatically populated.
  cni_network_config: |-
    {
      "name": "k8s-pod-network",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "calico",
          "log_level": "info",
          "log_file_path": "/var/log/calico/cni/cni.log",
          "datastore_type": "kubernetes",
          "nodename": "${HOSTNAME}",
          "mtu": 1500,
          "ipam": {
              "type": "calico-ipam",
              "assign_ipv4": "true",
              "assign_ipv6": "true"
          },
          "policy": {
              "type": "k8s"
          },
          "kubernetes": {
              "kubeconfig": "${HACK_KUBECONFIG_PATH}"
          }
        },
        {
          "type": "portmap",
          "snat": true,
          "capabilities": {"portMappings": true}
        },
        {
          "type": "bandwidth",
          "capabilities": {"bandwidth": true}
        }
      ]
    }
EOF
kubectl apply -f /tmp/calico-config.yml
kubectl apply -f /vagrant/resources/manifests/calico.yml
#kubectl apply -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
#kubectl apply -f https://docs.projectcalico.org/manifests/custom-resources.yaml

echo "Installing calicoctl..."
kubectl apply -f /vagrant/resources/manifests/calicoctl.yml
cat <<EOF >> $HOME/.bashrc
alias calicoctl="kubectl exec -i -n kube-system calicoctl -- /calicoctl"
EOF

echo "Creating portion of new cluster join config..."
K8_TOKEN=$(kubeadm token create)
K8_DISCO_CERT=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
cat <<EOF > /vagrant_work/join-config.yml.part
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: "${IPV4_ADDR}:6443"
    token: "${K8_TOKEN}"
    caCertHashes:
    - "sha256:${K8_DISCO_CERT}"
EOF

echo "Creating load-balancing via MetalLB..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/manifests/metallb.yaml
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
      - ${METALLB_ADDRESSES}
EOF
kubectl apply -f /tmp/metallb-config.yaml
