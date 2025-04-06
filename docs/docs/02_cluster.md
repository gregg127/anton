# Cluster setup

**Talos Linux v1.9.5** will be used as an OS on all nodes. Before installing Talos on the machines make sure to install **talosctl** and **kubectl** on your laptop/PC:
```
brew install siderolabs/tap/talosctl
```
```
brew install kubernetes-cli
```
and prepare USB drive with *bare-metal* Talos ISO image.

## configuration patches

Before setting up master and workers we need to prepare basic configuration patches for Talos. These consist of file with secrets and patches for nodes. To generate secret bundle file:
```
talosctl gen secrets -o secrets.yaml
```
Apart from that repository contains following patches: *patch-overlord.yml*, *patch-worker-0.yml*, *patch-worker-1.yml*. All of the mentioned will be used as arguments for `talosctl gen config` command.

The most important change in patches is the *diskSelector* rule that matches the disk that Talos will be installed on based on model name expression. Without this Talos always installs on */dev/sda*. In my case this device was the USB Drive with Talos ISO. The goal is to install Talos on server's hard drive, so that USB Drive is not needed.

## master setup

To set up a server node, the following steps need to be followed:

1. in BIOS set secure boot configuration to **Legacy Support Disable and Secure Boot Disable**
2. type in confirmation code to disable secure boot
3. plug USB drive to rear USB port of the device
4. boot from USB drive and wait for Talos to start and be in *ready* state
5. with Talos started its time to setup master node and cluster:
    1. save IP address to a variable (accessible from Talos dashboard):
    ```
    export IP=172.16.0.100
    ```
    2. generate configuration using secrets and patch:
    ```
    talosctl gen config --with-secrets secrets.yaml --config-patch-control-plane @patch-overlord.yml anton https://$IP:6443
    ```
    3. apply the configuration to the machine (this step will trigger Talos installation to disk):
    ```
    talosctl apply-config --insecure -n $IP --file controlplane.yaml
    ```
    4. wait for the installation to be complete, which will end with system restart
    5. shutdown the machine, unplug USB drive and start it again
    6. wait for Talos to boot (be patient, it may take up to 10 minutes or even more)
    7. having Talos started, setup Kubernetes:
    ```
    talosctl bootstrap --nodes $IP --endpoints $IP --talosconfig=./talosconfig
    ```
    8. wait until all checkboxes under *controlplane* will be healthy and *ready* state will be true
    9.  synchronize Kubernetes client configuration (TODO - remove and test)
    ```
    talosctl kubeconfig --nodes $IP --endpoints $IP --talosconfig=./talosconfig
    ```
    10. make sure everything works fine
    ```
    talosctl --nodes $IP --endpoints $IP --talosconfig=./talosconfig health
    ```
    11. additional check using kubectl
    ```
    kubectl get nodes -o=wide
    ```

Sources:

* [https://www.talos.dev/v1.9/introduction/getting-started/](https://www.talos.dev/v1.9/introduction/getting-started/)
* [https://www.talos.dev/v1.9/introduction/prodnotes/](https://www.talos.dev/v1.9/introduction/prodnotes/)
* [https://github.com/siderolabs/talos/discussions/9256](https://github.com/siderolabs/talos/discussions/9256)
* [https://github.com/siderolabs/talos/discussions/10081](https://github.com/siderolabs/talos/discussions/10081)
* [https://www.talos.dev/v1.9/talos-guides/configuration/patching/](https://www.talos.dev/v1.9/talos-guides/configuration/patching/)
* [https://github.com/siderolabs/talos/issues/9369](https://github.com/siderolabs/talos/issues/9369)
* [https://factory.talos.dev](https://factory.talos.dev)
* [https://www.talos.dev/v1.9/talos-guides/resetting-a-machine/](https://www.talos.dev/v1.9/talos-guides/resetting-a-machine/)