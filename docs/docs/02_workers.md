# Worker node setup

Now that cluster is setup with *controlplane* node it's time to add worker nodes:

1. first step is to setup the machine. For that steps 1-4 from the previous instruction must be followed.
2. with Talos started on the machine it's time to configure a worker node:
    1. save IP address to a variable (accessible from Talos dashboard) and save control plane IP:
    ```bash
    export WORKER_IP=172.16.0.102
    export WORKER=worker0
    export MASTER_IP=172.16.0.100
    ```
    2. generate worker configuration using secrets and patch:
    ```bash
    talosctl gen config \
    --with-secrets patches/secrets.yaml \
    --config-patch-worker @patches/patch-$WORKER.yml \
    --output-types worker \
    --output rendered/$WORKER.yaml \
    anton https://$WORKER_IP:6443
    ```
    3. apply the configuration to the machine (this step will trigger Talos installation to disk):
    ```bash
    talosctl apply-config --insecure \
    --nodes $WORKER_IP \
    --file rendered/$WORKER.yaml
    ```
    4. wait for the installation to finish
    5. once finished check if worker has successfully joined the cluster:
    ```bash
    kubectl get nodes -o=wide
    ```
    6. shutdown the machine, remove USB Drive and start the machine again
    7. after some time check if the node is in **READY** status:
    ```bash
    kubectl get nodes -o=wide
    ```
    8. check the dashboard:
    ```bash
    talosctl dashboard \
    --nodes $WORKER_IP \
    --endpoints $MASTER_IP \
    --talosconfig=rendered/talosconfig 
    ```

Sources:

* [https://datavirke.dk/posts/bare-metal-kubernetes-part-1-talos-on-hetzner/](https://datavirke.dk/posts/bare-metal-kubernetes-part-1-talos-on-hetzner/)