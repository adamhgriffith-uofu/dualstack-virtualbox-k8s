# -*- mode: ruby -*-
# vi: set ft=ruby :

# Environmental Variables:
ENV['KUBE_VERSION'] = "1.23.*"
ENV['METALLB_VERSION'] = "0.11.0"

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|

  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Avoid updating the guest additions if the user has the plugin installed:
#   if Vagrant.has_plugin?("vagrant-vbguest")
#     config.vbguest.auto_update = false
#   end

  # Display a note when running the machine.
  config.vm.post_up_message = "Remember to switch to root (sudo su -)!"

  # Necessary for mounts (see https://www.puppeteers.net/blog/fixing-vagrant-vbguest-for-the-centos-7-base-box/).
  config.vbguest.installer_options = { allow_kernel_upgrade: true }

  # Share an additional folder to the guest VM.
  config.vm.synced_folder "./work", "/vagrant_work", SharedFoldersEnableSymlinksCreate: false

  ##############################################################
  # Create the master node.                                    #
  ##############################################################
  config.vm.define "master" do |master|
    master.vm.box = "centos/7"
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: "192.168.56.10", netmask: "255.255.255.0"
    master.vm.network "private_network", ip: "fde4:8dba:82e1::c4", netmask: "64"

    # VirtualBox Provider
    master.vm.provider "virtualbox" do |vb|
      # Customize the number of CPUs on the VM:
      vb.cpus = 4

      # Display the VirtualBox GUI when booting the machine:
      vb.gui = false

      # Customize the amount of memory on the VM:
      vb.memory = 8192

      # Customize the name that appears in the VirtualBox GUI
      vb.name = "master"
    end

    # Perform housekeeping on `vagrant destroy`.
    master.trigger.before :destroy do |trigger|
      trigger.warn = "Performing housekeeping before starting destroy..."
      trigger.run_remote = {path: "./scripts/cluster/housekeeping.sh"}
    end

    # Provision with shell scripts.
    master.vm.provision "shell", path: "./scripts/cluster/os-requirements.sh"
    master.vm.provision "shell", path: "./scripts/cluster/docker.sh"
    master.vm.provision "shell" do |script|
      script.env = { KUBE_VERSION:ENV['KUBE_VERSION'] }
      script.path = "./scripts/cluster/kubernetes.sh"
    end
    master.vm.provision "shell" do |script|
      script.env = { METALLB_VERSION:ENV['METALLB_VERSION'] }
      script.path = "./scripts/cluster/master.sh"
    end
  end

  ##############################################################
  # Create the worker nodes.                                   #
  ##############################################################
  (1..2).each do |i|

    config.vm.define "worker#{i}" do |worker|

      worker.vm.box = "centos/7"
      worker.vm.hostname = "worker#{i}"
      worker.vm.network "private_network", ip: "192.168.56.1#{i}", netmask: "255.255.255.0"
      worker.vm.network "private_network", ip: "fde4:8dba:82e1::c4#{i}", netmask: "64"

      # VirtualBox Provider
      worker.vm.provider "virtualbox" do |vb|
        # Customize the number of CPUs on the VM:
        vb.cpus = 2

        # Customize the network drivers:
        vb.default_nic_type = "virtio"

        # Display the VirtualBox GUI when booting the machine:
        vb.gui = false

        # Customize the amount of memory on the VM:
        vb.memory = 4096

        # Customize the name that appears in the VirtualBox GUI:
        vb.name = "worker#{i}"
      end

      # Provision with shell scripts.
      worker.vm.provision "shell", path: "./scripts/cluster/os-requirements.sh"
      worker.vm.provision "shell", path: "./scripts/cluster/docker.sh"
      worker.vm.provision "shell" do |script|
        script.env = { KUBE_VERSION:ENV['KUBE_VERSION'] }
        script.path = "./scripts/cluster/kubernetes.sh"
      end
      worker.vm.provision "shell", path: "./scripts/cluster/worker.sh"
    end
  end
end
