# Flux, Helm, GitOps, SOPS

To avoid cluttering the repository with copy-pasted YAML manifests from external sources, I decided to use [Helm](https://helm.sh) charts managed through [Flux](https://fluxcd.io) GitOps workflows.

Instead of manually running `helm install` commands or maintaining static YAML files, I plan to use Flux's `GitRepository`, `HelmRepository`, and `HelmRelease` Custom Resource Definitions (CRDs) to declaratively manage all cluster resources. This GitOps approach means the cluster continuously monitors this Git repository for changes and automatically applies them, ensuring the cluster state always matches what's defined in version control.

The cluster resources are organized into three main directories:

* **flux/** - Contains Flux GitOps system configuration and bootstrapping files. The automatic GitOps sync is based on the files in this directory, which tells Flux what to monitor and deploy from the other directories.
* **infrastructure/** - Houses core cluster components like ingress controllers, cert-manager, etc.
* **services/** - Stores application deployments and user-facing services/apps running on the cluster.

!!! warning
    While experimenting with Flux, I ran into an error with kustomization that I couldn't resolve. In the end, I decided to wipe the cluster, reinstall everything, and start over. This turned out to be a good opportunity to verify if my previous cluster setup instructions were accurate.

    Also running ```flux uninstall``` followed by ```flux bootstrap``` again helps between experimental retries. 

## Bootstrap Flux

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

## Deploy podinfo in a GitOps manner

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

!!!note
    To manually test applications without committing changes to the repository, use `kubectl apply -k example-directory` to apply an entire directory to the cluster. The directory must contain a `kustomization.yaml` file that defines the resources to be applied.

## Secret Encryption with SOPS

Services and infrastructure components often require secret values such as API keys, passwords, and certificates. These secrets are typically stored as separate YAML files. Using SOPS (Secrets OPerationS), these secret files can be partially encrypted before committing them to the repository. The cluster must contain a GPG secret key to decrypt secrets committed to the repository.

### Generate GPG keys for the cluster

1. Install SOPS and GnuPG:
```console
brew install gnupg sops
```
Alternatively, install using the instructions at [https://github.com/getsops/sops/releases](https://github.com/getsops/sops/releases)
2. Create GPG keys for the cluster:
```console
export KEY_NAME="anton"                  
export KEY_COMMENT="secrets"     

gpg --batch --full-generate-key <<EOF
%no-protection
Key-Type: 1
Key-Length: 4096
Subkey-Type: 1
Subkey-Length: 4096
Expire-Date: 0
Name-Comment: ${KEY_COMMENT}
Name-Real: ${KEY_NAME}
EOF
```
3. Retrieve the generated key fingerprint:
```console
gpg --list-keys $KEY_NAME
```
This should output something similar to:
```
pub   rsa4096 2026-02-02 [SCEAR]
      EA65B90F135CF8C5E331DA40C87A0BEB390664D3
uid           [ultimate] anton (secrets)
sub   rsa4096 2026-02-02 [SEA]
```
4. Store the fingerprint in a variable:
```console
export KEY_FP=EA65B90F135CF8C5E331DA40C87A0BEB390664D3
```

### Create SOPS Configuration and encrypt example file

The repository will contain a SOPS configuration file to guide encryption and decryption of specific files. This configuration can be extended as needed.

1. Create `.sops.yaml` configuration file in the repository root directory:
```yaml
# Repository SOPS configuration, rules on how to encrypt specific files
---
creation_rules:
  - path_regex: cluster-resources/services/.*/.*.yaml
    encrypted_regex: ^(data|stringData)$
    pgp: >-
      EA65B90F135CF8C5E331DA40C87A0BEB390664D3
```
**Important**: According to the [Flux SOPS guide](https://fluxcd.io/flux/guides/mozilla-sops/), only `data` and `stringData` fields should be encrypted for Kubernetes Secrets. Encrypting metadata, kind, or apiVersion fields is not supported by Flux's kustomize-controller.
2. Create a new secret file (example: `cluster-resources/services/podinfo/secret.yaml`):
```yaml
# secret to test SOPS encryption
apiVersion: v1
kind: Secret
metadata:
    name: podinfo-secret
    namespace: default
type: Opaque
stringData:
    SECRET: top-secret-data
```
3. Encrypt the file (SOPS will encrypt and decrypt files based on the configuration file added above):
```console
sops --encrypt --in-place cluster-resources/services/podinfo/secret.yaml
```
This should transform the file from plain YAML to an encrypted version suitable for repository storage:
```yaml
# secret to test SOPS encryption
apiVersion: v1
kind: Secret
metadata:
    name: podinfo-secret
    namespace: default
type: Opaque
stringData:
    SECRET: ENC[AES256_GCM,data:ESqjM6ruXUTZFZ7mx7Nz,iv:FkwfWjugSAOg4TOaRzDKDCgTmcV2FnaMVRKaQHlvdw8=,tag:dA91YwE3jFomXTemWDKvMw==,type:str]
sops:
    lastmodified: "2026-02-02T13:16:24Z"
    mac: ENC[AES256_GCM,data:0T/vLQZjLojGXqa21BWJ9c/uEy0/BOfg5GWX5lwm0fi0kHKAw5KX6oPjcshOxVlnsbu4sz7/SHeA0+j+eGFdybxtvOj8mlYcI59ZA08KDj63RzexYqzBty3ZwJYEIZWYTD5Fl1ISwauxeC3edWfJMDH/qv/6JhOuPYiXYxtUDtE=,iv:8InrOB2SUrIAwMKDJvyQK+CIF+uXF8EXfY2xr55ddqw=,tag:ocyyut39S/IzAn82FpSp9A==,type:str]
    pgp:
        - created_at: "2026-02-02T13:16:24Z"
          enc: |-
            -----BEGIN PGP MESSAGE-----

            hQIMAwSeVs53q4TjARAAr0P5Rcy0cfdMElDd3OFqrylfSfF0Ntl2PuxuS/yU19L6
            zUwXRm2gsKUYTfDipsz/nKYS4TWAtKwZ+6hcINKvAscuYLqj3Vo+y4SU/v0gxWpk
            29FNbTDST+GeFs8lAITsTqMyrTu515vbJT29qRMB5L+3MMO+qPdM9EliHqydZ1Ns
            z4ZOWFLmeB2O5dJ9h0Noe9sJzJ1e1/8b/Z1lpK9KPWMmK0gTCDMxGHtqEblJZ5Eu
            PBB6mpWxtqUm/Gndq+bEfmQXlEseIqI8HCNQ+gbIM4njL602cL1kdHQfpK0AY0Iq
            TAKkukPCTZ2lH8ji4Ks4KH/kwZfxuSgrThqLAKdECXel4Cr1y6826A7YmQqPZHb4
            wPvCloDhlUD6kL0QR2mjnw8F70Q9vcwZ+9FYqW1ys79gCWBeo9U1ZujtRHXjnW0E
            Y6XKRjuxdjNcgf9yEVqoumDPmMrfBq2/xY4wmA6KAnD2D7JsJPDG07H0eXLsPNBP
            XOX9XRvRwF6SCIxaivwmJsMGgZAKc9q1SwZx0k+vXwOdVWNcudQ0oZHlmFfY0l1U
            RzOksLsnHG3miU13gQmAjjX7aQbkRbCly6nHilb6b0D5qhlsbU6i4111pAgQn2D4
            /VbqZ3OcVGjeB+uflCzCNtxhIG7h42MO3RPDnAbOg4ZF22JjZjURTjq6Fx1VDkzU
            aAEJAhA4SDNQN6jVQ+gTyq4bnsljl7huI3FNEgz3I4ig4vtq6KGwB/ESmgj5Jw/H
            c56w4A7sEjYG+Z4N5FUwPrVHuOfT7/5gebbFTrXNsENq0GWWgBlpJu+J3EJi/GTa
            TYA2bjZL6r5/
            =+1Wa
            -----END PGP MESSAGE-----
          fp: EA65B90F135CF8C5E331DA40C87A0BEB390664D3
    encrypted_regex: ^(data|stringData)$
    version: 3.11.0
```
4. Update the `kustomization.yaml` file (in this case `cluster-resources/services/podinfo/kustomization.yaml`) to include the secret file:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - podinfo.yaml
  - secret.yaml
```
5. Commit changes to the repository.

### Configure cluster and Flux

1. Export the private key and create a Kubernetes secret:
```console
gpg --export-secret-keys --armor $KEY_FP |
kubectl create secret generic sops-gpg \
--namespace=flux-system \
--from-file=sops.asc=/dev/stdin
```
2. Update the Flux Kustomization manifest to enable SOPS decryption:
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
  decryption:
    provider: sops
    secretRef:
      name: sops-gpg
```
3. Commit changes and push to the repository
4. Verify that the secret was automatically created:
```console
kubectl get secrets
```
Expected output:
```
NAME             TYPE     DATA   AGE
podinfo-secret   Opaque   1      105s
```
5. Backup the cluster secret key to a password manager or other secure location:
```console
gpg --export-secret-keys --armor "${KEY_FP}"
```
6. Remove the secret key from your local machine:
```console
gpg --delete-secret-keys "${KEY_FP}"
```

!!!note 
    **Security Note**: Before removing the cluster key, consider adding additional GPG keys for decryption and encryption on your development machines. The cluster secret key should be removed from personal computers since it is deployed in the flux-system namespace and used automatically for decryption.

## Summary

This chapter demonstrates implementing a complete GitOps workflow using Flux. **For GitOps to work correctly, all Kustomization definitions that monitor infrastructure and services must be placed in the `flux/` directory**, while the actual resource definitions are organized separately in `infrastructure/` and `services/` directories. This separation allows Flux to automatically detect and apply changes from the Git repository to the cluster and allows user to store YAML files that will not be a part of GitOps workflow.

The podinfo example in this chapter uses `GitRepository` and `Kustomization` for deployment, but it's important to note that exactly the same results can be achieved using `HelmRepository` and `HelmRelease` instead. The choice between these approaches depends on your use case: `GitRepository` is better suited for custom-made applications that reside in your repository and are not packaged as Helm charts, while the `HelmRepository` approach is often preferred for managing official Helm charts as it provides better versioning and configuration management capabilities. For example of using Helm to deploy PodInfo, refer to the [Flux Helm example repository](https://github.com/fluxcd/flux2-kustomize-helm-example).

Additionally, this chapter covers secret management using [SOPS (Secrets OPerationS)](https://github.com/getsops/sops) for encrypting sensitive data before storing it in Git repositories, ensuring secure GitOps workflows.

-----

Sources:

* [https://fluxcd.io/flux/concepts/](https://fluxcd.io/flux/concepts/)
* [https://fluxcd.io/flux/guides/repository-structure/](https://fluxcd.io/flux/guides/repository-structure/)
* [https://github.com/fluxcd/flux2-kustomize-helm-example](https://github.com/fluxcd/flux2-kustomize-helm-example)
* [https://fluxcd.io/flux/cmd/flux_bootstrap_github/](https://fluxcd.io/flux/cmd/flux_bootstrap_github/)
* [https://fluxcd.io/flux/components/kustomize/kustomizations/](https://fluxcd.io/flux/components/kustomize/kustomizations/)
* [https://fluxcd.io/flux/components/source/gitrepositories/](https://fluxcd.io/flux/components/source/gitrepositories/)
* [https://fluxcd.io/flux/guides/mozilla-sops/](https://fluxcd.io/flux/guides/mozilla-sops/)
* [https://datavirke.dk/posts/bare-metal-kubernetes-part-3-encrypted-gitops-with-fluxcd/](https://datavirke.dk/posts/bare-metal-kubernetes-part-3-encrypted-gitops-with-fluxcd/)