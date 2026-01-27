# Flux, Helm, GitOps

To avoid cluttering the repository with copy-pasted YAML manifests from external sources, I decided to use [Helm](https://helm.sh) charts managed through [Flux](https://fluxcd.io) GitOps workflows.

Instead of manually running `helm install` commands or maintaining static YAML files, I plan to use Flux's `GitRepository`, `HelmRepository`, and `HelmRelease` Custom Resource Definitions (CRDs) to declaratively manage all cluster resources. This GitOps approach means the cluster continuously monitors this Git repository for changes and automatically applies them, ensuring the cluster state always matches what's defined in version control.

The cluster resources are organized into three main directories:

* **flux/** - Contains Flux GitOps system configuration and bootstrapping files. The automatic GitOps sync is based on the files in this directory, which tell Flux what to monitor and deploy from the other directories.
* **infrastructure/** - Houses core cluster components like ingress controllers, cert-manager, etc.
* **services/** - Stores application deployments and user-facing services/apps running on the cluster.

!!! warning
    While experimenting with Flux, I ran into an error with kustomization that I couldn't resolve. In the end, I decided to wipe the cluster, reinstall everything, and start over. This turned out to be a good opportunity to verify if my previous cluster setup instructions were accurate.

    Also running ```flux uninstall``` followed by ```flux bootstrap``` again helps between experimental retries. 

## Flux installation

After some minor inconveniences, I got this working by following the instructions below.

### Bootstrap Flux

1. Export your GitHub username:
```console
export GITHUB_USER=gregg127
```

2. Export the GitHub **secret** token (Settings -> Developer settings -> Personal access tokens -> Fine-grained tokens):
```console
export GITHUB_TOKEN=<your_secret_token>
```

3. Install Flux on your laptop/PC:
```console
brew install fluxcd/tap/flux
```
Alternatively use:
```console
curl -s https://fluxcd.io/install.sh | sudo bash
```

4. Bootstrap Flux (this will install Flux in the cluster, **commit and push** the `flux-system` to the repo):
```console
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=anton \
  --branch=main \
  --path=./cluster-resources/flux \
  --personal
```
This should end with something like:
```
► connecting to github.com
► cloning branch "main" from Git repository "https://github.com/gregg127/anton.git"
✔ cloned repository
► generating component manifests
✔ generated component manifests
✔ component manifests are up to date
► installing components in "flux-system" namespace
✔ installed components
✔ reconciled components
► determining if source secret "flux-system/flux-system" exists
► generating source secret
✔ public key: ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBOgc/LKPvk2+ou+zGqrWkwSbiSeGKA56//FoqOxXDsVNlwpJ5uAZGvUeT2nYnYLBLUi4LObQHtJXZXkqqStmR+PVcZpbqrVA7eaRxmcoCgofKTJhd/wWQqSlXyN0Si+DzQ==
✔ configured deploy key "flux-system-main-flux-system-./cluster-resources/flux" for "https://github.com/gregg127/anton"
► applying source secret "flux-system/flux-system"
✔ reconciled source secret
► generating sync manifests
✔ generated sync manifests
✔ committed sync manifests to "main" ("4cc3f5a35bc3dee46184e5a39b97e135bc6d095d")
► pushing sync manifests to "https://github.com/gregg127/anton.git"
► applying sync manifests
✔ reconciled sync configuration
◎ waiting for GitRepository "flux-system/flux-system" to be reconciled
✔ GitRepository reconciled successfully
◎ waiting for Kustomization "flux-system/flux-system" to be reconciled
✔ Kustomization reconciled successfully
► confirming components are healthy
✔ helm-controller: deployment ready
✔ kustomize-controller: deployment ready
✔ notification-controller: deployment ready
✔ source-controller: deployment ready
✔ all components are healthy
► connecting to github.com
► cloning branch "main" from Git repository "https://github.com/gregg127/anton.git"
✔ cloned repository
► generating component manifests
✔ generated component manifests
✔ component manifests are up to date
► installing components in "flux-system" namespace
✔ installed components
✔ reconciled components
► determining if source secret "flux-system/flux-system" exists
► generating source secret
✔ public key: ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBOgc/LKPvk2+ou+zGqrWkwSbiSeGKA56//FoqOxXDsVNlwpJ5uAZGvUeT2nYnYLBLUi4LObQHtJXZXkqqStmR+PVcZpbqrVA7eaRxmcoCgofKTJhd/wWQqSlXyN0Si+DzQ==
✔ configured deploy key "flux-system-main-flux-system-./cluster-resources/flux" for "https://github.com/gregg127/anton"
► applying source secret "flux-system/flux-system"
✔ reconciled source secret
► generating sync manifests
✔ generated sync manifests
✔ committed sync manifests to "main" ("4cc3f5a35bc3dee46184e5a39b97e135bc6d095d")
► pushing sync manifests to "https://github.com/gregg127/anton.git"
► applying sync manifests
✔ reconciled sync configuration
◎ waiting for GitRepository "flux-system/flux-system" to be reconciled
✔ GitRepository reconciled successfully
◎ waiting for Kustomization "flux-system/flux-system" to be reconciled
✔ Kustomization reconciled successfully
► confirming components are healthy
✔ helm-controller: deployment ready
✔ kustomize-controller: deployment ready
✔ notification-controller: deployment ready
✔ source-controller: deployment ready
✔ all components are healthy
```
4. Verify that *gitrepository* and *kustomization* are in a ready state:
```console
flux get all
```
```
NAME                     	REVISION          	SUSPENDED	READY	MESSAGE                                           
gitrepository/flux-system	main@sha1:bd5fb487	False    	True 	stored artifact for revision 'main@sha1:bd5fb487'	

NAME                     	REVISION          	SUSPENDED	READY	MESSAGE                              
kustomization/flux-system	main@sha1:bd5fb487	False    	True 	Applied revision: main@sha1:bd5fb487	
```
5. See the resources that were installed in the cluster:
```console
kubectl get all,cm,secret,ing -n flux-system
```
```
NAME                                           READY   STATUS    RESTARTS   AGE
pod/helm-controller-74988df57b-d4fqx           1/1     Running   0          4m17s
pod/kustomize-controller-6b646448f6-lp7x9      1/1     Running   0          4m17s
pod/notification-controller-6c9f6f77d8-fsxz4   1/1     Running   0          4m17s
pod/source-controller-56c7f45479-ggssx         1/1     Running   0          4m17s

NAME                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/notification-controller   ClusterIP   10.104.184.4     <none>        80/TCP    4m17s
service/source-controller         ClusterIP   10.107.172.214   <none>        80/TCP    4m17s
service/webhook-receiver          ClusterIP   10.104.44.48     <none>        80/TCP    4m17s

NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/helm-controller           1/1     1            1           4m17s
deployment.apps/kustomize-controller      1/1     1            1           4m17s
deployment.apps/notification-controller   1/1     1            1           4m17s
deployment.apps/source-controller         1/1     1            1           4m17s

NAME                                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/helm-controller-74988df57b           1         1         1       4m17s
replicaset.apps/kustomize-controller-6b646448f6      1         1         1       4m17s
replicaset.apps/notification-controller-6c9f6f77d8   1         1         1       4m17s
replicaset.apps/source-controller-56c7f45479         1         1         1       4m17s

NAME                         DATA   AGE
configmap/kube-root-ca.crt   1      4m19s

NAME                 TYPE     DATA   AGE
secret/flux-system   Opaque   3      4m15s
```

### Deploy podinfo in a GitOps manner

First, add the application definition to a dedicated directory in *services*:

1. Create directory `/cluster-resources/services/podinfo`
2. Add the [podinfo](https://artifacthub.io/packages/helm/podinfo/podinfo) YAML file with name `podinfo.yaml` that contains `GitRepository` and `Kustomization`:
```yaml
--- 
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: podinfo
  namespace: default
spec:
  interval: 1m15s # check for new commits every minute and 15 seconds and apply changes
  ref:
    branch: master
  url: https://github.com/stefanprodan/podinfo
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: podinfo
  namespace: default
spec:
  path: ./kustomize # path to https://github.com/stefanprodan/podinfo/tree/master/kustomize containing configuration
  interval: 60m0s # detect drift and undo kubectl edits every hour
  timeout: 3m0s # give up waiting after three minutes
  retryInterval: 2m0s # retry every two minutes on apply or waiting failures
  prune: true # remove stale resources from cluster
  targetNamespace: default # will deploy app to the cluster's default namespace
  sourceRef:
    kind: GitRepository
    name: podinfo
```
3. In the same directory, add `kustomization.yaml` that serves as an entry point:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - podinfo.yaml
```

Having the application definition, it is now necessary for the GitOps workflow to add a Kustomization file that will monitor the podinfo service directory:

1. Create file `podinfo.yaml` in the `cluster-resources/flux/services` directory
2. Add Kustomization definition that will reference the podinfo service directory:
```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: podinfo # name of the Kustomization resource for the application
  namespace: flux-system
spec:
  interval: 10m0s
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system # references the GitRepository resource defined in gotk-sync.yaml
  path: ./cluster-resources/services/podinfo # path within the Git repository
```
3. Commit and push to the repository
4. Check if the new Kustomization was created in Flux:
```console
flux get all
```
```
NAME                     	REVISION          	SUSPENDED	READY	MESSAGE                                           
gitrepository/flux-system	main@sha1:e66b323a	False    	True 	stored artifact for revision 'main@sha1:e66b323a'	

NAME                     	REVISION          	SUSPENDED	READY	MESSAGE                              
kustomization/flux-system	main@sha1:e66b323a	False    	True 	Applied revision: main@sha1:e66b323a	
kustomization/podinfo    	main@sha1:e66b323a	False    	True 	Applied revision: main@sha1:e66b323a	
```
5. Check if pods were created:
```console
kubectl get pods
```
```
NAME                      READY   STATUS    RESTARTS   AGE
podinfo-8b99d95f7-8fwdd   1/1     Running   0          15m
podinfo-8b99d95f7-jdqfj   1/1     Running   0          15m

```

## Summary

This chapter demonstrates implementing a complete GitOps workflow using Flux, where the key architectural requirement is proper directory separation and Flux configuration management. **For GitOps to work correctly, all Kustomization definitions that monitor infrastructure and services must be placed in the `flux/` directory**, while the actual resource definitions are organized separately in `infrastructure/` and `services/` directories - this separation allows Flux to automatically detect and apply changes from the Git repository to the cluster.

The podinfo example in this chapter uses `GitRepository` and `Kustomization` for deployment, but it's important to note that exactly the same results can be achieved using `HelmRepository` and `HelmRelease` instead. The choice between these approaches depends on your use case: `GitRepository` is better suited for custom-made applications that reside in your repository and are not packaged as Helm charts, while the `HelmRepository` approach is often preferred for managing official Helm charts as it provides better versioning and configuration management capabilities. For comprehensive examples of this pattern, refer to the [Flux Helm example repository](https://github.com/fluxcd/flux2-kustomize-helm-example).

Sources:

* [https://datavirke.dk/posts/bare-metal-kubernetes-part-1-talos-on-hetzner/](https://datavirke.dk/posts/bare-metal-kubernetes-part-1-talos-on-hetzner/)
* [https://fluxcd.io/flux/concepts/](https://fluxcd.io/flux/concepts/)
* [https://fluxcd.io/flux/guides/repository-structure/](https://fluxcd.io/flux/guides/repository-structure/)
* [https://github.com/fluxcd/flux2-kustomize-helm-example](https://github.com/fluxcd/flux2-kustomize-helm-example)
* [https://fluxcd.io/flux/cmd/flux_bootstrap_github/](https://fluxcd.io/flux/cmd/flux_bootstrap_github/)
* [https://fluxcd.io/flux/components/kustomize/kustomizations/](https://fluxcd.io/flux/components/kustomize/kustomizations/)
* [https://fluxcd.io/flux/components/source/gitrepositories/](https://fluxcd.io/flux/components/source/gitrepositories/)
