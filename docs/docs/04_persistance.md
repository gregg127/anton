# Storage

After cleaning up, it's time for the next big step—storage implementation so I can define `PersistentVolumeClaims`. After some research and considering the size of my cluster, which is **3 nodes**, and the fact that each node **only has one disk**, I decided to go with [Local Path Provisioner](https://github.com/rancher/local-path-provisioner). The drawback is that storage isn't replicated, and volumes will be bound to specific nodes. This will need to be considered when deploying services that use volumes.

I don't want to get too deep into the details of my experiments, how Talos Linux occupies disks, and what partitions it creates. You can read about those in the GitHub issues and Talos documentation. Here's the final instruction to achieve what I wanted:

1. First, each machine has to be patched:
   1. Prepare variables:
      ```console
      export MASTER_IP=172.16.0.103
      export NODENAME=worker0
      export NODE_IP=172.16.0.102
      ```
   2. Prepare the machine patch. Kubelet patches that were created are available in the repo under `/cluster-config/patches/disk`.
   3. Apply the patch—no reboot needed:
      ```console
      talosctl patch mc \
      --nodes $NODE_IP \
      --endpoints $MASTER_IP \
      --talosconfig=rendered/talosconfig \
      --patch @patches/disk/$NODENAME-create-data-partition.yml
      ```
2. Prepare and apply the Local Path Provisioner YAML with the path pointing to the destination included in the machine patches and other configuration:
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
3. The installation above doesn't create `Persistent Volume Claims`, but it should create a `Storage Class`. Verify it:
```console
kubectl get storageclass
```
```
NAME         PROVISIONER                            RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path   cluster.local/local-path-provisioner   Delete          WaitForFirstConsumer   true                   133m
```
4. Create and apply an example PVC with a deployment:
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
5. Verify that the PVC works by opening the nginx pod shell, creating a file in the mounted directory, restarting the machines, and checking if the file persisted.

!!! warning
    Remember that this storage isn't replicated and is bound to a specific node.

---

Sources:

* [https://www.talos.dev/v1.9/kubernetes-guides/configuration/storage/](https://www.talos.dev/v1.9/kubernetes-guides/configuration/storage/)
* [https://www.talos.dev/v1.9/kubernetes-guides/configuration/ceph-with-rook/](https://www.talos.dev/v1.9/kubernetes-guides/configuration/ceph-with-rook/)
* [https://www.talos.dev/v1.9/kubernetes-guides/configuration/local-storage/](https://www.talos.dev/v1.9/kubernetes-guides/configuration/local-storage/)
* [https://www.talos.dev/v1.9/talos-guides/configuration/disk-management/](https://www.talos.dev/v1.9/talos-guides/configuration/disk-management/)
* [https://github.com/siderolabs/talos/issues/8367](https://github.com/siderolabs/talos/issues/8367)
* [https://medium.com/@manojkumar_41904/understanding-and-verifying-volume-mounts-in-kubernetes-pods-2fe392435531](https://medium.com/@manojkumar_41904/understanding-and-verifying-volume-mounts-in-kubernetes-pods-2fe392435531)