# VirtualBox and Dual-stack Kubernetes

Tools to create dual-stack K8s with VirtualBox.

## Requirements

### VirtualBox

See [Virtual Box](https://www.virtualbox.org/) for download and installation instructions.

#### Linux

VirtualBox on Linux requires a little extra love.

1. On the host add the following to `/etc/vbox/networks.conf`:
  
   ```shell
   * fde4:8dba:82e1::c4/64
   ```

### Vagrant

* [Download vagrant](https://www.vagrantup.com/downloads) and follow the installer's instructions.
* Install the Virtualbox Guest Additions via the following command:

  ```shell
  vagrant plugin install vagrant-vbguest
  ```

  **Note:** you will receive the mount errors described in [Vagrant No VirtualBox Guest Additions installation found](https://www.devopsroles.com/vagrant-no-virtualbox-guest-additions-installation-found-fixed/).
* Enable autocompletion:

  ```shell
  vagrant autocomplete install --bash
  ```

## Build and Run

Bring up the three virtual machines `master`, `worker1`, and `worker2`:

```shell
vagrant up
```

### Initialize K8s Cluster

Initialization is done for you.

* The host directory `/<repo-location>/work` is mounted at `/vagrant_work` on each virtual machine.
* When `master` is created it will create `/<repo-location>/work/join.sh`.
* `/<repo-location>/work/join.sh` will be used by the workers to join the Kubernetes cluster automatically.

## Teardown

Tearing down the virtual machines and clearing the old `/<repo-location>/work/join.sh` is done with a single command:

```shell
vagrant destroy -f
```

See [Vagrant: Destroy](https://www.vagrantup.com/docs/cli/destroy) for additional information.

## References

* [IPv4/IPv6 dual-stack](https://kubernetes.io/docs/concepts/services-networking/dual-stack/#enable-ipv4-ipv6-dual-stack)
* [Dual-stack support with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/dual-stack-support/)
* [Calico: Configure dual stack or IPv6 only](https://projectcalico.docs.tigera.io/networking/ipv6)
* [Calico: IP autodetection methods](https://projectcalico.docs.tigera.io/reference/node/configuration#ip-autodetection-methods)