# Cluster setup

**Talos Linux v1.9.5** will be used as the OS on all nodes. Before installing Talos on the machines, make sure to install **talosctl** and **kubectl** on your laptop/PC:
```console
brew install siderolabs/tap/talosctl
```
```console
brew install kubernetes-cli
```
and prepare a USB drive with the *bare-metal* Talos ISO image.

## Configuration patches

Before setting up the control plane and workers, we need to prepare basic configuration patches for Talos. These consist of a file with secrets and patches for nodes. To generate the secret bundle file:
```console
talosctl gen secrets -o secrets.yaml
```
Apart from that, the repository contains patches:

* `patch-overlord.yml` - patch for control plane configuration
* `patch-worker0.yml` - patch for worker0 configuration
* `patch-worker1.yml` - patch for worker1 configuration

These will be used as arguments for the `talosctl gen config` command.

The most important change in the patches is the *diskSelector* rule, which matches the disk that Talos will be installed on based on the model name expression. Without this, Talos always installs on */dev/sda*. In my case, when installing Talos on the control plane node, this device was the USB drive with the Talos ISO. The goal is to install Talos on the server's hard drive so that the USB drive is no longer needed.

## Control plane node setup

To set up a server node, follow these steps:

1. In BIOS, set the secure boot configuration to **Legacy Support Disable and Secure Boot Disable**.
2. Type in the confirmation code to disable secure boot.
3. Plug the USB drive into the rear USB port of the device.
4. Boot from the USB drive and wait for Talos to start and reach the **READY** state.
5. With Talos started, it's time to set up the master node and cluster:
    1. Save the IP address to a variable (accessible from the Talos dashboard):
    ```console
    export MASTER_IP=172.16.0.103
    ```
    2. Generate the control plane and Talos configuration using the secrets and patch:
    ```console
    talosctl gen config \
    --with-secrets patches/secrets.yaml \
    --config-patch-control-plane @patches/patch-overlord.yml \
    --output-types controlplane,talosconfig \
    --output rendered/ \
    anton https://$MASTER_IP:6443
    ```
    3. Apply the configuration to the machine (this step will trigger Talos installation to disk):
    ```console
    talosctl apply-config --insecure \
    --nodes $MASTER_IP \
    --file rendered/controlplane.yaml
    ```
    4. Wait for the installation to complete, which will end with a system restart.
    5. Wait for Talos `Kubelet` to reach a healthy state.
    6. With Talos ready, set up Kubernetes:
    ```console
    talosctl bootstrap \
    --nodes $MASTER_IP \
    --endpoints $MASTER_IP \
    --talosconfig=rendered/talosconfig
    ```
    7. Wait until all checkboxes under *controlplane* are healthy and the **READY** state is true.
    8. Shut down the machine, unplug the USB drive, and start it again.
    9. Make sure everything works fine:
    ```console
    talosctl health \
    --nodes $MASTER_IP \
    --endpoints $MASTER_IP \
    --talosconfig=rendered/talosconfig
    ```
    10. Set up the kubectl configuration:
    ```console
    talosctl kubeconfig \
    --nodes $MASTER_IP \
    --endpoints $MASTER_IP \
    --talosconfig=rendered/talosconfig
    ```
    11. Check the Kubernetes configuration:
    ```console
    kubectl cluster-info
    ```
    ```console
    kubectl get nodes -o=wide
    ```
    12. Access the Talos dashboard remotely:
    ```console
    talosctl dashboard \
    --nodes $MASTER_IP \
    --endpoints $MASTER_IP \
    --talosconfig=rendered/talosconfig
    ```

After completing the above steps, the cluster should be set up and ready to accept workers.

## Worker node setup

Now that the cluster is set up with the *controlplane* node, it's time to add worker nodes:

1. First, set up the machine. For that, follow steps 1-4 from the previous instructions.
2. With Talos started on the machine, configure a worker node:
    1. Save the IP address to a variable (accessible from the Talos dashboard) and save the control plane IP:
    ```console
    export WORKER_IP=172.16.0.102
    export WORKER=worker0
    export MASTER_IP=172.16.0.103
    ```
    2. Generate the worker configuration using the secrets and patch:
    ```console
    talosctl gen config \
    --with-secrets patches/secrets.yaml \
    --config-patch-worker @patches/patch-$WORKER.yml \
    --output-types worker \
    --output rendered/$WORKER.yaml \
    anton https://$WORKER_IP:6443
    ```
    3. Apply the configuration to the machine (this step will trigger Talos installation to disk):
    ```console
    talosctl apply-config --insecure \
    --nodes $WORKER_IP \
    --file rendered/$WORKER.yaml
    ```
    4. Wait for the installation to finish.
    5. Once finished, check if the worker has successfully joined the cluster:
    ```console
    kubectl get nodes -o=wide
    ```
    6. Shut down the machine, remove the USB drive, and start the machine again.
    7. After some time, check if the node is in the **READY** status:
    ```console
    kubectl get nodes -o=wide
    ```
    8. Check the dashboard:
    ```console
    talosctl dashboard \
    --nodes $WORKER_IP \
    --endpoints $MASTER_IP \
    --talosconfig=rendered/talosconfig 
    ```

The instructions above work for a single worker. Before adding another worker to the cluster, you have to create a patch file in `/cluster-config/patches` for the worker and change the **WORKER_IP** and **WORKER** variables in the instructions.

At this point, I have three machines in my cluster—a control plane and two workers. Everything is set up and ready to serve services.

-----

Revision summarizing work done in this chapter: `938602404874b8de4c741ecd7a9a3e89d5bd19ec`

Sources:

* [https://www.talos.dev/v1.9/introduction/getting-started/](https://www.talos.dev/v1.9/introduction/getting-started/)
* [https://www.talos.dev/v1.9/introduction/prodnotes/](https://www.talos.dev/v1.9/introduction/prodnotes/)
* [https://github.com/siderolabs/talos/discussions/9256](https://github.com/siderolabs/talos/discussions/9256)
* [https://github.com/siderolabs/talos/discussions/10081](https://github.com/siderolabs/talos/discussions/10081)
* [https://www.talos.dev/v1.9/talos-guides/configuration/patching/](https://www.talos.dev/v1.9/talos-guides/configuration/patching/)
* [https://github.com/siderolabs/talos/issues/9369](https://github.com/siderolabs/talos/issues/9369)
* [https://factory.talos.dev](https://factory.talos.dev)
* [https://www.talos.dev/v1.9/talos-guides/resetting-a-machine/](https://www.talos.dev/v1.9/talos-guides/resetting-a-machine/)
* [https://datavirke.dk/posts/bare-metal-kubernetes-part-1-talos-on-hetzner/](https://datavirke.dk/posts/bare-metal-kubernetes-part-1-talos-on-hetzner/)