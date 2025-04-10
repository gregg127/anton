# Cluster setup

**Talos Linux v1.9.5** will be used as an OS on all nodes. Before installing Talos on the machines make sure to install **talosctl** and **kubectl** on your laptop/PC:
```bash
brew install siderolabs/tap/talosctl
```
```bash
brew install kubernetes-cli
```
and prepare USB drive with *bare-metal* Talos ISO image.

## Configuration patches

Before setting up master and workers we need to prepare basic configuration patches for Talos. These consist of file with secrets and patches for nodes. To generate secret bundle file:
```bash
talosctl gen secrets -o secrets.yaml
```
Apart from that repository contains *patch-overlord.yml* which is a patch for configuration generation. This will be used as arguments for `talosctl gen config` command.

The most important change in patches is the *diskSelector* rule that matches the disk that Talos will be installed on based on model name expression. Without this Talos always installs on */dev/sda*. In my case this device was the USB Drive with Talos ISO. The goal is to install Talos on server's hard drive, so that USB Drive is not needed.

## Master setup

To set up a server node, the following steps need to be followed:

1. in BIOS set secure boot configuration to **Legacy Support Disable and Secure Boot Disable**
2. type in confirmation code to disable secure boot
3. plug USB drive to rear USB port of the device
4. boot from USB drive and wait for Talos to start and be in **READY** state
5. with Talos started its time to setup master node and cluster:
    1. save IP address to a variable (accessible from Talos dashboard):
    ```bash
    export MASTER_IP=172.16.0.100
    ```
    2. generate control plane and Talos configuration using secrets and patch:
    ```bash
    talosctl gen config \
    --with-secrets patches/secrets.yaml \
    --config-patch-control-plane @patches/patch-overlord.yml \
    --output-types controlplane,talosconfig \
    --output rendered/ \
    anton https://$MASTER_IP:6443
    ```
    3. apply the configuration to the machine (this step will trigger Talos installation to disk):
    ```bash
    talosctl apply-config --insecure \
    --nodes $MASTER_IP \
    --file rendered/controlplane.yaml
    ```
    4. wait for the installation to be complete, which will end with system restart
    5. shutdown the machine, unplug USB drive and start it again
    6. wait for Talos to boot (this may take up to 10 minutes or even more)
    7. having Talos started, setup Kubernetes:
    ```bash
    talosctl bootstrap \
    --nodes $MASTER_IP \
    --endpoints $MASTER_IP \
    --talosconfig=rendered/talosconfig
    ```
    8. wait until all checkboxes under *controlplane* will be healthy and **READY** state will be true
    9.  make sure everything works fine
    ```bash
    talosctl health \
    --nodes $MASTER_IP \
    --endpoints $MASTER_IP \
    --talosconfig=rendered/talosconfig
    ```
    10. setup kubectl configuration:
    ```bash
    talosctl kubeconfig \
    --nodes $MASTER_IP \
    --endpoints $MASTER_IP \
    --talosconfig=rendered/talosconfig
    ```
    11. check kubernetes configuration:
    ```bash
    kubectl cluster-info
    ```
    ```bash
    kubectl get nodes -o=wide
    ```
    12. access Talos dashboard remotely
    ```bash
    talosctl dashboard \
    --nodes $MASTER_IP \
    --endpoints $MASTER_IP \
    --talosconfig=rendered/talosconfig
    ```

After all of the above cluster should be set up and ready to accept workers.

Sources:

* [https://www.talos.dev/v1.9/introduction/getting-started/](https://www.talos.dev/v1.9/introduction/getting-started/)
* [https://www.talos.dev/v1.9/introduction/prodnotes/](https://www.talos.dev/v1.9/introduction/prodnotes/)
* [https://github.com/siderolabs/talos/discussions/9256](https://github.com/siderolabs/talos/discussions/9256)
* [https://github.com/siderolabs/talos/discussions/10081](https://github.com/siderolabs/talos/discussions/10081)
* [https://www.talos.dev/v1.9/talos-guides/configuration/patching/](https://www.talos.dev/v1.9/talos-guides/configuration/patching/)
* [https://github.com/siderolabs/talos/issues/9369](https://github.com/siderolabs/talos/issues/9369)
* [https://factory.talos.dev](https://factory.talos.dev)
* [https://www.talos.dev/v1.9/talos-guides/resetting-a-machine/](https://www.talos.dev/v1.9/talos-guides/resetting-a-machine/)