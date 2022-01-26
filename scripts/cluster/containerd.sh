#!/bin/bash

# Enable strict mode:
set -euo pipefail

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "~ Install and configure containerd                                                ~"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

echo "Adding the yum-config-manager tool..."
yum install yum-utils -y

echo "Adding the stable Docker repo to yum..."
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

echo "Installing the latest version of containerd..."
yum install containerd.io -y

echo "Configuring the systemd cgroup driver..."
CONTAINDERD_CONFIG_PATH=/etc/containerd/config.toml
rm "${CONTAINDERD_CONFIG_PATH}"
containerd config default > "${CONTAINDERD_CONFIG_PATH}"
sed -i "/runc.options/a\            SystemdCgroup = true" "${CONTAINDERD_CONFIG_PATH}"

echo "Enabling containerd through systemctl..."
systemctl enable --now containerd

echo "Applying changes..."
systemctl restart containerd