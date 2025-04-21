# A step back - Flux, Helm, GitOps

There's still a lot to do, but I decided to take a little side quest. Right now, I keep YAML manifests downloaded from the source (e.g., `cert-manager`) in the repository. This makes my repo bloated with copy-pasted code and complicates version management for these manifests. So, I decided to switch to [Helm](https://helm.sh) and migrate all my current configuration.

To keep all the configuration needed to set up my cluster in the Git repository, I should use the `HelmRelease` and `HelmRepository` CRDs. The alternative would be to use the `helm install` command with the proper arguments for each thing I want to install. But to keep things clean and follow good practices, I decided to install [Flux](https://fluxcd.io) in my cluster. This way, I can configure everything in a GitOps manner and use the mentioned CRDs. This will reduce the amount of code in my repository for infrastructure/management elements of my cluster and allow me to create and deploy my applications in a GitOps manner using GitHub.

!!! warning
    While experimenting with Flux, I ran into an error with kustomization that I couldn't resolve. In the end, I decided to wipe the cluster, reinstall everything, and start over. This turned out to be a good opportunity to verify if my previous cluster setup instructions were accurate.

## Flux installation

After some minor inconveniences, I got this working by following the instructions below.

### Bootstrap Flux

1. First, generate a GitHub token and export the variables:
```
export GITHUB_USER=gregg127
export GITHUB_TOKEN=<secret_token>
```
2. Install Flux on your laptop/PC:
```
brew install fluxcd/tap/flux
```
3. Bootstrap Flux (this will install Flux in the cluster and commit the `flux-system` to the repo):
```
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=anton \
  --branch=main \
  --path=./cluster-resources/infrastructure/flux \
  --personal
```
This should end with:
```
► connecting to github.com
► cloning branch "main" from Git repository "https://github.com/gregg127/anton.git"
✔ cloned repository
► generating component manifests
✔ generated component manifests
✔ committed component manifests to "main" ("55f1a26637b65d91216711e07b47e2407c9f972f")
► pushing component manifests to "https://github.com/gregg127/anton.git"
► installing components in "flux-system" namespace
✔ installed components
✔ reconciled components
► determining if source secret "flux-system/flux-system" exists
► generating source secret
✔ public key: ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBCpUQg7lUAKAIoj/zOAzS+5FYmAnGTp+x9WARy+RzPfjY2UU6HZ/fuoP/bjTBKOBxkieutX6bOQ6YsBflQINclgFlOuoCDTIyBW11yLr2ViNTE4496lDxFF/G2nnGrcDfQ==
✔ configured deploy key "flux-system-main-flux-system-./cluster-resources/infrastructure/flux" for "https://github.com/gregg127/anton"
► applying source secret "flux-system/flux-system"
✔ reconciled source secret
► generating sync manifests
✔ generated sync manifests
✔ committed sync manifests to "main" ("910d044b2fe99bd9fe257706fc6f1a2c634561d6")
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
4. Verify if kustomizations are in a ready state:
```console
flux get kustomizations
```
```
NAME       	REVISION          	SUSPENDED	READY	MESSAGE
flux-system	main@sha1:910d044b	False    	True 	Applied revision: main@sha1:910d044b
```
5. See the resources that were installed:
```console
kubectl get all,cm,secret,ing -n flux-system
```
```
NAME                                           READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
pod/helm-controller-b6767d66-4mxtx             1/1     Running   0          83m   10.244.0.6   overlord   <none>           <none>
pod/kustomize-controller-57c7ff5596-9wrx9      1/1     Running   0          83m   10.244.0.8   overlord   <none>           <none>
pod/notification-controller-58ffd586f7-5cjqq   1/1     Running   0          83m   10.244.0.7   overlord   <none>           <none>
pod/source-controller-6ff87cb475-7v9cq         1/1     Running   0          83m   10.244.0.9   overlord   <none>           <none>

NAME                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/notification-controller   ClusterIP   10.108.44.134    <none>        80/TCP    83m   app=notification-controller
service/source-controller         ClusterIP   10.101.167.174   <none>        80/TCP    83m   app=source-controller
service/webhook-receiver          ClusterIP   10.105.119.215   <none>        80/TCP    83m   app=notification-controller

NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                                          SELECTOR
deployment.apps/helm-controller           1/1     1            1           83m   manager      ghcr.io/fluxcd/helm-controller:v1.2.0           app=helm-controller
deployment.apps/kustomize-controller      1/1     1            1           83m   manager      ghcr.io/fluxcd/kustomize-controller:v1.5.1      app=kustomize-controller
deployment.apps/notification-controller   1/1     1            1           83m   manager      ghcr.io/fluxcd/notification-controller:v1.5.0   app=notification-controller
deployment.apps/source-controller         1/1     1            1           83m   manager      ghcr.io/fluxcd/source-controller:v1.5.0         app=source-controller

NAME                                                 DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES                                          SELECTOR
replicaset.apps/helm-controller-b6767d66             1         1         1       83m   manager      ghcr.io/fluxcd/helm-controller:v1.2.0           app=helm-controller,pod-template-hash=b6767d66
replicaset.apps/kustomize-controller-57c7ff5596      1         1         1       83m   manager      ghcr.io/fluxcd/kustomize-controller:v1.5.1      app=kustomize-controller,pod-template-hash=57c7ff5596
replicaset.apps/notification-controller-58ffd586f7   1         1         1       83m   manager      ghcr.io/fluxcd/notification-controller:v1.5.0   app=notification-controller,pod-template-hash=58ffd586f7
replicaset.apps/source-controller-6ff87cb475         1         1         1       83m   manager      ghcr.io/fluxcd/source-controller:v1.5.0         app=source-controller,pod-template-hash=6ff87cb475

NAME                         DATA   AGE
configmap/kube-root-ca.crt   1      83m

NAME                 TYPE     DATA   AGE
secret/flux-system   Opaque   3      83m
```

### Deploy podinfo

1. Add the [podinfo](https://artifacthub.io/packages/helm/podinfo/podinfo) service YAML with `GitRepository` and `Kustomization`, apply it, and verify:
```yaml
# podinfo.yaml
# This is an example of how Flux's GitRepository and Kustomization work
--- 
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: podinfo
  namespace: flux-system
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
  namespace: flux-system
spec:
  path: ./kustomize # path to https://github.com/stefanprodan/podinfo/tree/master/kustomize containing configuration
  interval: 60m0s # detect drift and undo kubectl edits every hour
  timeout: 3m0s # give up waiting after three minutes
  retryInterval: 2m0s # retry every two minutes on apply or waiting failures
  prune: true # remove stale resources from cluster
  targetNamespace: default
  sourceRef:
    kind: GitRepository
    name: podinfo
```
```console
flux get all
```
```
NAME                     	REVISION            	SUSPENDED	READY	MESSAGE
gitrepository/flux-system	main@sha1:1475ff71  	False    	True 	stored artifact for revision 'main@sha1:1475ff71'
gitrepository/podinfo    	master@sha1:b3396adb	False    	True 	stored artifact for revision 'master@sha1:b3396adb'

NAME                     	REVISION            	SUSPENDED	READY	MESSAGE
kustomization/flux-system	main@sha1:1475ff71  	False    	True 	Applied revision: main@sha1:1475ff71
kustomization/podinfo    	master@sha1:b3396adb	False    	True 	Applied revision: master@sha1:b3396adb
```
See the details of kustomization (the output shows many reconciliations, that's because I updated the YAML file after some time):
```console
kubectl describe kustomization podinfo -n flux-system
```
```
Name:         podinfo
Namespace:    flux-system
Labels:       <none>
Annotations:  <none>
API Version:  kustomize.toolkit.fluxcd.io/v1
Kind:         Kustomization
Metadata:
  Creation Timestamp:  2025-04-13T09:05:41Z
  Finalizers:
    finalizers.fluxcd.io
  Generation:        2
  Resource Version:  16951
  UID:               f943370e-7b87-4d48-95c8-f779e788bedd
Spec:
  Force:           false
  Interval:        60m0s
  Path:            ./kustomize
  Prune:           true
  Retry Interval:  2m0s
  Source Ref:
    Kind:            GitRepository
    Name:            podinfo
  Target Namespace:  default
  Timeout:           3m0s
Status:
  Conditions:
    Last Transition Time:  2025-04-13T09:46:37Z
    Message:               Applied revision: master@sha1:b3396adb98a6a0f5eeedd1a600beaf5e954a1f28
    Observed Generation:   2
    Reason:                ReconciliationSucceeded
    Status:                True
    Type:                  Ready
  Inventory:
    Entries:
      Id:                   default_podinfo__Service
      V:                    v1
      Id:                   default_podinfo_apps_Deployment
      V:                    v1
      Id:                   default_podinfo_autoscaling_HorizontalPodAutoscaler
      V:                    v2
  Last Applied Revision:    master@sha1:b3396adb98a6a0f5eeedd1a600beaf5e954a1f28
  Last Attempted Revision:  master@sha1:b3396adb98a6a0f5eeedd1a600beaf5e954a1f28
  Observed Generation:      2
Events:
  Type    Reason       Age   From                  Message
  ----    ------       ----  ----                  -------
  Normal  Progressing  41m   kustomize-controller  Service/default/podinfo created
Deployment/default/podinfo created
HorizontalPodAutoscaler/default/podinfo created
  Normal  ReconciliationSucceeded  41m                  kustomize-controller  Reconciliation finished in 200.936063ms, next run in 5m0s
  Normal  ReconciliationSucceeded  41m                  kustomize-controller  Reconciliation finished in 206.241609ms, next run in 5m0s
  Normal  ReconciliationSucceeded  36m                  kustomize-controller  Reconciliation finished in 191.209835ms, next run in 5m0s
  Normal  ReconciliationSucceeded  31m                  kustomize-controller  Reconciliation finished in 203.291106ms, next run in 5m0s
  Normal  ReconciliationSucceeded  26m                  kustomize-controller  Reconciliation finished in 200.983881ms, next run in 5m0s
  Normal  ReconciliationSucceeded  20m                  kustomize-controller  Reconciliation finished in 155.978416ms, next run in 5m0s
  Normal  ReconciliationSucceeded  15m                  kustomize-controller  Reconciliation finished in 229.980797ms, next run in 5m0s
  Normal  ReconciliationSucceeded  10m                  kustomize-controller  Reconciliation finished in 210.430338ms, next run in 5m0s
  Normal  ReconciliationSucceeded  5m24s                kustomize-controller  Reconciliation finished in 168.166691ms, next run in 5m0s
  Normal  ReconciliationSucceeded  37s (x2 over 2m29s)  kustomize-controller  (combined from similar events): Reconciliation finished in 162.143086ms, next run in 1h0m0s
```
2. see details on what was deployed:
```console
kubectl get pods
```
```
NAME                       READY   STATUS    RESTARTS   AGE
podinfo-6b885b7698-kd99s   1/1     Running   0          5m33s
podinfo-6b885b7698-rsvvs   1/1     Running   0          5m48s
```
```console
kubectl describe deployment podinfo
```
```
Name:                   podinfo
Namespace:              default
CreationTimestamp:      Sun, 13 Apr 2025 11:05:43 +0200
Labels:                 kustomize.toolkit.fluxcd.io/name=podinfo
                        kustomize.toolkit.fluxcd.io/namespace=flux-system
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=podinfo
Replicas:               2 desired | 2 updated | 2 total | 2 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        3
RollingUpdateStrategy:  0 max unavailable, 25% max surge
Pod Template:
  Labels:       app=podinfo
  Annotations:  prometheus.io/port: 9797
                prometheus.io/scrape: true
  Containers:
   podinfod:
    Image:       ghcr.io/stefanprodan/podinfo:6.8.0
    Ports:       9898/TCP, 9797/TCP, 9999/TCP
    Host Ports:  0/TCP, 0/TCP, 0/TCP
    Command:
      ./podinfo
      --port=9898
      --port-metrics=9797
      --grpc-port=9999
      --grpc-service-name=podinfo
      --level=info
      --random-delay=false
      --random-error=false
    Limits:
      cpu:     2
      memory:  512Mi
    Requests:
      cpu:      100m
      memory:   64Mi
    Liveness:   exec [podcli check http localhost:9898/healthz] delay=5s timeout=5s period=10s #success=1 #failure=3
    Readiness:  exec [podcli check http localhost:9898/readyz] delay=5s timeout=5s period=10s #success=1 #failure=3
    Environment:
      PODINFO_UI_COLOR:  #34577c
    Mounts:
      /data from data (rw)
  Volumes:
   data:
    Type:          EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:
    SizeLimit:     <unset>
  Node-Selectors:  <none>
  Tolerations:     <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  <none>
NewReplicaSet:   podinfo-6b885b7698 (2/2 replicas created)
Events:
  Type    Reason             Age    From                   Message
  ----    ------             ----   ----                   -------
  Normal  ScalingReplicaSet  6m38s  deployment-controller  Scaled up replica set podinfo-6b885b7698 from 0 to 1
  Normal  ScalingReplicaSet  6m23s  deployment-controller  Scaled up replica set podinfo-6b885b7698 from 1 to 2
```
!!! note
    Note the podinfo deployment configuration. Everything here came from the YAML file containing `GitRepository` and `Kustomization`. This configuration, along with others, was taken from [https://github.com/stefanprodan/podinfo/tree/master/kustomize](https://github.com/stefanprodan/podinfo/tree/master/kustomize), where the `kustomization.yaml` file location in the source repo is described by the `spec.path` parameter in `Kustomization`. The whole point of this and GitOps is that the cluster listens for changes in the configured repo and applies them to the cluster if anything changes. So, if anything is pushed to the podinfo repository, the cluster will detect it and apply the changes.

Considering everything above, it looks like the installation works fine.

## Static YAMLs migration  

While working with the Flux setup, I wiped the cluster and deleted the previously created:

* `nginx-ingress`
* `cert-manager`
* cert issuers
* `anton-ingress`
* `nginx` deployment

These were defined by static YAMLs. Now it's time to bring them all back, but using Flux and Helm.

### nginx-ingress

1. Create YAML configuration for `nginx-service`:
```yaml
# nginx-ingress.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/enforce-version: latest
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
spec:
  interval: 5m0s
  url: https://kubernetes.github.io/ingress-nginx # https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
spec:
  interval: 5m
  chart:
    spec:
      chart: ingress-nginx
      version: ">=v4.7.0 <4.8.0"
      sourceRef:
        kind: HelmRepository
        name: ingress-nginx
        namespace: ingress-nginx
      interval: 1m
  values:
    controller:
      hostNetwork: true
      hostPort:
        enabled: true
      kind: DaemonSet
      service:
        enabled: false
```
2. Apply the configuration:
```console
kubectl apply -f nginx-ingress.yaml
```
```
namespace/ingress-nginx created
helmrepository.source.toolkit.fluxcd.io/ingress-nginx created
helmrelease.helm.toolkit.fluxcd.io/ingress-nginx created
```
3. See resources that were added to the namespace:
```console
kubectl get all -n ingress-nginx -o=wide
```
```
NAME                                 READY   STATUS    RESTARTS   AGE   IP             NODE       NOMINATED NODE   READINESS GATES
pod/ingress-nginx-controller-fl58t   1/1     Running   0          13m   172.16.0.100   worker1    <none>           <none>
pod/ingress-nginx-controller-jj2lq   1/1     Running   0          13m   172.16.0.103   overlord   <none>           <none>
pod/ingress-nginx-controller-vxqwr   1/1     Running   0          13m   172.16.0.102   worker0    <none>           <none>

NAME                                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/ingress-nginx-controller-admission   ClusterIP   10.104.176.30   <none>        443/TCP   13m   app.kubernetes.io/component=controller,app.kubernetes.io/instance=ingress-nginx,app.kubernetes.io/name=ingress-nginx

NAME                                      DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE   CONTAINERS   IMAGES                                                                                                                    SELECTOR
daemonset.apps/ingress-nginx-controller   3         3         3       3            3           kubernetes.io/os=linux   13m   controller   registry.k8s.io/ingress-nginx/controller:v1.8.5@sha256:5831fa630e691c0c8c93ead1b57b37a6a8e5416d3d2364afeb8fe36fe0fef680   app.kubernetes.io/component=controller,app.kubernetes.io/instance=ingress-nginx,app.kubernetes.io/name=ingress-nginx
```

### cert-manager

1. Create YAML configuration for cert-manager:
```yaml
# cert-manager.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: jetstack
  namespace: cert-manager
spec:
  interval: 5m0s
  url: https://charts.jetstack.io
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: cert-manager
  namespace: cert-manager
spec:
  interval: 5m
  chart:
    spec:
      chart: cert-manager
      version: ">=v1.12.0 <1.13.0"
      sourceRef:
        kind: HelmRepository
        name: jetstack
        namespace: cert-manager
      interval: 1m
  values:
    installCRDs: true
```
2. Apply the configuration:
```console
kubectl apply -f cert-manager.yaml
```
```
namespace/cert-manager created
helmrepository.source.toolkit.fluxcd.io/jetstack created
helmrelease.helm.toolkit.fluxcd.io/cert-manager created
```
3. See resources that were added to the namespace:
```console
kubectl get all -n cert-manager -o=wide
```
```
NAME                                           READY   STATUS    RESTARTS   AGE     IP           NODE      NOMINATED NODE   READINESS GATES
pod/cert-manager-7687c8fcf7-wfhdx              1/1     Running   0          3m58s   10.244.1.4   worker0   <none>           <none>
pod/cert-manager-cainjector-567d9d5568-l4cqb   1/1     Running   0          3m58s   10.244.3.7   worker1   <none>           <none>
pod/cert-manager-webhook-54b5d8cb64-bmxtj      1/1     Running   0          3m58s   10.244.3.6   worker1   <none>           <none>

NAME                           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE     SELECTOR
service/cert-manager           ClusterIP   10.102.39.228   <none>        9402/TCP   3m58s   app.kubernetes.io/component=controller,app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=cert-manager
service/cert-manager-webhook   ClusterIP   10.109.66.56    <none>        443/TCP    3m58s   app.kubernetes.io/component=webhook,app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=webhook

NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS                IMAGES                                              SELECTOR
deployment.apps/cert-manager              1/1     1            1           3m58s   cert-manager-controller   quay.io/jetstack/cert-manager-controller:v1.12.16   app.kubernetes.io/component=controller,app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=cert-manager
deployment.apps/cert-manager-cainjector   1/1     1            1           3m58s   cert-manager-cainjector   quay.io/jetstack/cert-manager-cainjector:v1.12.16   app.kubernetes.io/component=cainjector,app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=cainjector
deployment.apps/cert-manager-webhook      1/1     1            1           3m58s   cert-manager-webhook      quay.io/jetstack/cert-manager-webhook:v1.12.16      app.kubernetes.io/component=webhook,app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=webhook

NAME                                                 DESIRED   CURRENT   READY   AGE     CONTAINERS                IMAGES                                              SELECTOR
replicaset.apps/cert-manager-7687c8fcf7              1         1         1       3m58s   cert-manager-controller   quay.io/jetstack/cert-manager-controller:v1.12.16   app.kubernetes.io/component=controller,app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=cert-manager,pod-template-hash=7687c8fcf7
replicaset.apps/cert-manager-cainjector-567d9d5568   1         1         1       3m58s   cert-manager-cainjector   quay.io/jetstack/cert-manager-cainjector:v1.12.16   app.kubernetes.io/component=cainjector,app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=cainjector,pod-template-hash=567d9d5568
replicaset.apps/cert-manager-webhook-54b5d8cb64      1         1         1       3m58s   cert-manager-webhook      quay.io/jetstack/cert-manager-webhook:v1.12.16      app.kubernetes.io/component=webhook,app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=webhook,pod-template-hash=54b5d8cb64
```

### certification issuers

1. Create YAML configuration for cluster issuers:
```yaml
# certificate-issuers.yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    # The ACME server URL
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: grzegorz.golebiowski127@gmail.com
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-staging-private-key
    # Enable the HTTP-01 challenge provider
    solvers:
      - http01:
          ingress:
            class: nginx
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: grzegorz.golebiowski127@gmail.com
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod-private-key
    # Enable the HTTP-01 challenge provider
    solvers:
      - http01:
          ingress:
            class: nginx
```
2. Apply the configuration:
```console
kubectl apply -f certificate-issuers.yaml
```
```
clusterissuer.cert-manager.io/letsencrypt-staging created
clusterissuer.cert-manager.io/letsencrypt-prod created
```
3. Verify that ACME accounts were registered:
```console
kubectl get clusterissuers -o=wide
```
```
NAME                  READY   STATUS                                                 AGE
letsencrypt-prod      True    The ACME account was registered with the ACME server   3m20s
letsencrypt-staging   True    The ACME account was registered with the ACME server   3m20s
```

### ingress

1. Restore and apply YAML configuration for Ingress. This remained unchanged:
```yaml
# anton-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: anton-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - anton.golebiowski.dev
      secretName: letsencrypt-prod-anton-tls-secret
  rules:
    - host: anton.golebiowski.dev
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: podinfo
                port:
                  number: 9898
```
2. After some time, verify that the certificate was successfully created:
```console
kubectl get certificaterequests,certificates
```
```
NAME                                                                         APPROVED   DENIED   READY   ISSUER             REQUESTOR                                         AGE
certificaterequest.cert-manager.io/letsencrypt-prod-anton-tls-secret-47g6q   True                True    letsencrypt-prod   system:serviceaccount:cert-manager:cert-manager   2m1s

NAME                                                            READY   SECRET                              AGE
certificate.cert-manager.io/letsencrypt-prod-anton-tls-secret   True    letsencrypt-prod-anton-tls-secret   2m1s
```
3. Verify SSL:
```
curl https://anton.golebiowski.dev
```
```json
{
  "hostname": "podinfo-6b885b7698-ngmgk",
  "version": "6.8.0",
  "revision": "b3396adb98a6a0f5eeedd1a600beaf5e954a1f28",
  "color": "#34577c",
  "logo": "https://raw.githubusercontent.com/stefanprodan/podinfo/gh-pages/cuddle_clap.gif",
  "message": "greetings from podinfo v6.8.0",
  "goos": "linux",
  "goarch": "amd64",
  "runtime": "go1.24.1",
  "num_goroutine": "9",
  "num_cpu": "4"
}
```

!!! note
    DNS configuration was not mentioned in this chapter. Please remember that I use dynamic DNS and subdomain configuration set by my domain provider. This was described in the previous chapter.

## Summary
To summarize what I did while working on this chapter:

* Removed all previous YAML manifests.
* Wiped my cluster and set it up again.
* Set up Flux and implemented GitOps.
* Deployed podinfo as an example and testing application (replacement for nginx-unprivileged).
* Restored and migrated nginx-ingress.
* Restored and migrated cert-manager.
* Restored and refactored cert issuers manifest(s).
* Restored ingress.

Now the repository looks much better, and a huge amount of code from previous static YAMLs was removed.

After this, the directory structure with my cluster resources looks like this:
```
tree cluster-resources 
```
```
cluster-resources
├── infrastructure
│   ├── README.md
│   ├── cert-manager
│   │   ├── README.md
│   │   └── cert-manager.yaml
│   ├── flux
│   │   └── flux-system
│   │       ├── gotk-components.yaml
│   │       ├── gotk-sync.yaml
│   │       └── kustomization.yaml
│   └── nginx-ingress
│       ├── README.md
│       └── nginx-ingress.yaml
├── ingress
│   ├── README.txt
│   ├── anton-ingress.yaml
│   └── cert-issuers
│       └── certificate-issuers.yaml
└── services
    ├── README.txt
    └── podinfo
        └── podinfo.yaml
```
---

Sources:

* [https://datavirke.dk/posts/bare-metal-kubernetes-part-1-talos-on-hetzner/](https://datavirke.dk/posts/bare-metal-kubernetes-part-1-talos-on-hetzner/)
* [https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
* [https://fluxcd.io/flux/get-started/](https://fluxcd.io/flux/get-started/)
* [https://fluxcd.io/flux/components/](https://fluxcd.io/flux/components/)
* [https://fluxcd.io/flux/components/kustomize/kustomizations/](https://fluxcd.io/flux/components/kustomize/kustomizations/)
* [https://fluxcd.io/flux/components/source/gitrepositories/](https://fluxcd.io/flux/components/source/gitrepositories/)
* [https://fluxcd.io/flux/components/source/api/v1/](https://fluxcd.io/flux/components/source/api/v1/)
* [https://artifacthub.io/packages/helm/podinfo/podinfo](https://artifacthub.io/packages/helm/podinfo/podinfo)
* [https://fluxcd.io/flux/cheatsheets/troubleshooting/](https://fluxcd.io/flux/cheatsheets/troubleshooting/)