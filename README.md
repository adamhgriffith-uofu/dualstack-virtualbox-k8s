# dualstack-virtualbox-k8s
Tools to create dual-stack K8s with VirtualBox.

## Host Operating System Issues

### Linux

VirtualBox on Linux requires a little extra love.

1. On the host add the following to `/etc/vbox/networks.conf`:
  
   ```shell
   * fe80::800:27ff:fe00:0/64
   ```

## References

* [Dual-stack support with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/dual-stack-support/)
* [Calico: Configure dual stack or IPv6 only](https://projectcalico.docs.tigera.io/networking/ipv6)