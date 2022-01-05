#!/bin/bash

# Enable strict mode:
set -euo pipefail

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~ Apply OS Requirements                                                           ~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

echo "Setting SELinux to permissive mode..."
setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

echo "Disabling swap..."
swapoff -a
sed -e '/swap/s/^/#/g' -i /etc/fstab

echo "Disabling firewalld..."
systemctl disable --now firewalld

#echo "Installing IPVS-required kernel modules..."
#yum install -y ipvsadm
#cat <<EOF > /etc/modules-load.d/01-ipvs.conf
#ip_vs
#ip_vs_rr
#ip_vs_wrr
#ip_vs_sh
#nf_conntrack_ipv4
#EOF

echo "Setting iptables for bridged network traffic..."
cat <<EOF >  /etc/sysctl.d/01-k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

echo "Enabling IP forwarding..."
cat <<EOF > /etc/sysctl.d/02-fwd.conf
net.ipv4.conf.all.forwarding=1
net.ipv6.conf.all.forwarding=1
EOF

sysctl --system