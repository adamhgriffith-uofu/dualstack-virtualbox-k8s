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

echo "Setting iptables for bridged network traffic..."
cat <<EOF >  /etc/sysctl.d/01-k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

echo "Enabling IP forwarding..."
cat <<EOF > /etc/sysctl.d/02-fwd.conf
net.ipv6.conf.all.forwarding=1
net.ipv4.conf.all.forwarding=1
EOF

echo "Configuring eth1..."
cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-eth1
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=no
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
NAME=eth1
DEVICE=eth1
ONBOOT=yes
IPADDR=${IPV4_ADDR}
PREFIX=${IPV4_MASK}
GATEWAY=${IPV4_GW}
DNS1=155.101.3.11
DOMAIN="${SEARCH_DOMAINS}"
IPV6ADDR=${IPV6_ADDR}/${IPV6_MASK}
IPV6_DEFAULTGW=${IPV6_GW}
IPV6_PRIVACY=no
ZONE=public
EOF

echo "Applying changes..."
sysctl --system
systemctl restart NetworkManager