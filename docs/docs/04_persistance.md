# Storage

After cleaning up now it's time for the next big step - storage implementation so that I can define `PersisentVolumeClaims`. After reasearch and considering size of my cluster, which is **3 nodes** and that each node **only has one disk** I decided to go with [Local Path Provisioner](https://github.com/rancher/local-path-provisioner). The drawback is that storage is not replicated and volumes will be bound to specific nodes. This will have to be considered when deploying services that use volumes.

I do not want to get into too much details of my experiments, how Talos Linux occupies disks and what partitions it creates. Those can be read in the Github issues and Talos documentation. The final instruction to get what I wanted is:

1. first each machine has to be patched:
      1. prepare variables:
      ```console
      export MASTER_IP=172.16.0.103
      export NODENAME=worker0
      export NODE_IP=172.16.0.102
      ```
      2. prepare machine patch, kubelet patches that were created are available in repo in directory `/cluster-config/patches/disk`
      3. apply the patch, no reboot needed:
      ```console
      talosctl patch mc \
      --nodes $NODE_IP \
      --endpoints $MASTER_IP \
      --talosconfig=rendered/talosconfig \
      --patch @patches/disk/$NODENAME-create-data-partition.yml
      ```
2. prepare and apply Local Path Provisioner YAML with path pointing to the destination included in machine patches and other configuration:
```yaml
# local-path-provisioner.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: local-path-storage
  labels:
    pod-security.kubernetes.io/enforce: privileged
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: local-path-provisioner
  namespace: local-path-storage
spec:
  interval: 5m0s
  url: https://charts.containeroo.ch # https://artifacthub.io/packages/helm/containeroo/local-path-provisioner?modal=install
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: local-path-provisioner
  namespace: local-path-storage
spec:
  interval: 5m
  chart:
    spec:
      chart: local-path-provisioner
      version: ">=0.0.32 <0.0.45"
      sourceRef:
        kind: HelmRepository
        name: local-path-provisioner
        namespace: local-path-storage
      interval: 1m
  values:
    storageClass.defaultClass: true
    nodePathMap: [{"node": "DEFAULT_PATH_FOR_NON_LISTED_NODES", "paths": ["/var/local-path-provisioner"]}]
```
1. installation above does not create `Persistent Volume Claims`, but should create `Storage Class`. Verify it:
```console
kubectl get storageclass
```
```
NAME         PROVISIONER                            RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path   cluster.local/local-path-provisioner   Delete          WaitForFirstConsumer   true                   133m
```
1. create and apply example PVC with deployment:
```yaml
# nginx-pvc.yaml
# Example deployment with attached PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-local-volume-pvc
  annotations:
    volumeType: local
    volume.kubernetes.io/selected-node: worker0
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 128Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-with-pvc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-with-pvc
  template:
    metadata:
      labels:
        app: nginx-with-pvc
    spec:
      containers:
        - name: nginx
          image: nginx:stable-alpine
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
          volumeMounts:
            - name: storage
              mountPath: /usr/share/nginx/html
      volumes:
        - name: storage
          persistentVolumeClaim:
            claimName: nginx-local-volume-pvc
```
1. verify that the PVC works by opening nginx's pod shell, creating file in mounted directory, restarting machines and checking if file persisted.

!!! warning
    Remember that this storage is not replicated and bound to a node.

---

Sources:

* [https://www.talos.dev/v1.9/kubernetes-guides/configuration/storage/](https://www.talos.dev/v1.9/kubernetes-guides/configuration/storage/)
* [https://www.talos.dev/v1.9/kubernetes-guides/configuration/ceph-with-rook/](https://www.talos.dev/v1.9/kubernetes-guides/configuration/ceph-with-rook/)
* [https://www.talos.dev/v1.9/kubernetes-guides/configuration/local-storage/](https://www.talos.dev/v1.9/kubernetes-guides/configuration/local-storage/)
* [https://www.talos.dev/v1.9/talos-guides/configuration/disk-management/](https://www.talos.dev/v1.9/talos-guides/configuration/disk-management/)
* [https://github.com/siderolabs/talos/issues/8367](https://github.com/siderolabs/talos/issues/8367)
* [https://medium.com/@manojkumar_41904/understanding-and-verifying-volume-mounts-in-kubernetes-pods-2fe392435531](https://medium.com/@manojkumar_41904/understanding-and-verifying-volume-mounts-in-kubernetes-pods-2fe392435531)