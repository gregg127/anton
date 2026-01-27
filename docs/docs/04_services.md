# First Service and Communication   

Now that I have the cluster set up, it's time to deploy the first services. At the very beginning, for testing purposes, I decided to go with [nginx unprivileged](https://hub.docker.com/r/nginxinc/nginx-unprivileged), which will initially serve just nginx's default page.
  
This will help me figure out DNS and routing. My two main goals for this step are:

* Make deploying new services as easy as possible.
* Make routing to those services from outside the cluster as easy as possible.

For now, I decided not to use Helm or any GitOps solutions. I'll stick with `kubectl` and YAML manifests.

## Deploying the Application
I created an `nginx.yaml` configuration containing:

* `kind: Deployment` - mainly specifies pods, containers, and resources. This is used to manage the application.
* `kind: Service` - contains communication configuration for the deployment. It ensures that the application is accessible **within the cluster** by the service name. 

These two are the main components of the deployed application. After deploying nginx, the default namespace of the cluster looks like this:
```console
kubectl -o=wide get nodes,services,deployments,replicasets,pods
```
```
NAME            STATUS   ROLES           AGE    VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE         KERNEL-VERSION   CONTAINER-RUNTIME
node/overlord   Ready    control-plane   44h    v1.32.3   172.16.0.100   <none>        Talos (v1.9.5)   6.12.18-talos    containerd://2.0.3
node/worker0    Ready    <none>          43h    v1.32.3   172.16.0.102   <none>        Talos (v1.9.5)   6.12.18-talos    containerd://2.0.3
node/worker1    Ready    <none>          114m   v1.32.3   172.16.0.103   <none>        Talos (v1.9.5)   6.12.18-talos    containerd://2.0.3

NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE   SELECTOR
service/kubernetes      ClusterIP   10.96.0.1       <none>        443/TCP    44h   <none>
service/nginx-service   ClusterIP   10.96.198.221   <none>        8080/TCP   26m   app=nginx

NAME                    READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES         SELECTOR
deployment.apps/nginx   1/1     1            1           38m   nginx        nginx:1.27.4   app=nginx

NAME                               DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES         SELECTOR
replicaset.apps/nginx-7f94bbff4f   1         1         1       20m   nginx        nginx:1.27.4   app=nginx,pod-template-hash=7f94bbff4f

NAME                         READY   STATUS    RESTARTS   AGE   IP           NODE      NOMINATED NODE   READINESS GATES
pod/nginx-7f94bbff4f-pwp4j   1/1     Running   0          20m   10.244.1.4   worker0   <none>           <none>
```

## Cluster Accessibility

For now, the cluster contains a deployment and a service pointing to the deployment pods. The problem is that `nginx` is accessible only within the cluster. After many painful experiments and research, and considering that I am working with a **bare metal** cluster, I made the following decisions:

* Routing will be done with `Ingress` manifests.
* To get this working, the cluster must contain an **Ingress controller**.
* No external **Load Balancer** will be used.
* `NodePorts` will not be used due to the awkward port range `30000-32767`.
* A `DaemonSet` with an **Ingress controller** will be used so that every cluster node has a pod with the controller.
* Each pod with the controller will use the **host network** by adding the configuration `template.spec.hostNetwork: true`. Thanks to this:
    * I can avoid the port range `30000-32767`, and the controller can bind ports `80` and `443` directly to cluster nodes that run applications.
    * If I run web applications, they will be accessible without using the port range `30000-32767`. For example, the `nginx` service will be accessible from outside the cluster by the address `http://nginx.cluster.local`, assuming that an `Ingress` with the host `nginx.cluster.local` pointing to the `nginx` service is added and an external DNS pointing the domain to the cluster is configured (DNS issues will be described later).
* The **control plane** will have to allow scheduling so that a pod with the controller can run on this node.

This solution has some drawbacks and security considerations. I won't describe these here. For a detailed explanation about this and the solution above, check out the sources my work is based on: [ingress-nginx baremetal](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/), [datavirke's blog](https://datavirke.dk/posts/bare-metal-kubernetes-part-4-ingress-dns-certificates/).

I implemented this idea by:

* Adding Kubernetes [ingress-nginx](https://kubernetes.github.io/ingress-nginx/):
    * First, I copied the [bare metal YAML manifest](https://github.com/kubernetes/ingress-nginx/blob/main/deploy/static/provider/baremetal/deploy.yaml) to a file so that I could deploy it using `kubectl apply`.
    * From the manifest, I removed the `Service` with the name `ingress-nginx-controller`. This won't be needed because of the DaemonSet.
    * The `Deployment` with the name `ingress-nginx-controller` was changed to a `DaemonSet` with the added `template.spec.hostNetwork: true` configuration and removed configurations specific to `Deployment`. 
    * To get `template.spec.hostNetwork: true` working, I had to add the following labels to the nginx-ingress namespace: `pod-security.kubernetes.io/enforce: privileged` and `pod-security.kubernetes.io/enforce-version: latest`.
* Adding an `Ingress` with `ingressClassName: nginx` (this is the name of the `IngressClass` from ingress-nginx) and the host `nginx.anton.cluster` routing to the `Service` with the name `nginx-service` (my service that serves only nginx's default page).

The configuration of [ingress-nginx](https://kubernetes.github.io/ingress-nginx/) is considered part of the cluster infrastructure and has a dedicated namespace named `ingress-nginx` so that it can be separated from other things and the default namespace, which will contain my services. `Ingress` configurations will be part of the default namespace, as these will change based on the services I deploy. The directory structure with cluster resource configurations at this point looks like this:
```console
tree cluster-resources
```
```console
cluster-resources
├── infrastructure
│   ├── README.md
│   └── nginx-ingress
│       ├── README.md
│       └── nginx-ingress.yaml
├── ingress
│   ├── README.txt
│   └── ingress.yaml
└── services
    └── nginx
        ├── README.txt
        └── nginx.yaml
```

!!! warning
    This structure was changed in the following chapters.

The `ingress-nginx` namespace looks like this:
```console
kubectl -n ingress-nginx get all -o=wide
```
```console
NAME                                       READY   STATUS      RESTARTS   AGE     IP             NODE       NOMINATED NODE   READINESS GATES
pod/ingress-nginx-admission-create-fdpwq   0/1     Completed   0          6m38s   10.244.1.45    worker0    <none>           <none>
pod/ingress-nginx-admission-patch-swscx    0/1     Completed   0          6m38s   10.244.2.42    worker1    <none>           <none>
pod/ingress-nginx-controller-4pq95         1/1     Running     0          6m38s   172.16.0.100   overlord   <none>           <none>
pod/ingress-nginx-controller-gl4f2         1/1     Running     0          6m38s   172.16.0.103   worker1    <none>           <none>
pod/ingress-nginx-controller-j6f7g         1/1     Running     0          6m38s   172.16.0.102   worker0    <none>           <none>

NAME                                         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE     SELECTOR
service/ingress-nginx-controller-admission   ClusterIP   10.96.56.81   <none>        443/TCP   6m38s   app.kubernetes.io/component=controller,app.kubernetes.io/instance=ingress-nginx,app.kubernetes.io/name=ingress-nginx

NAME                                      DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE     CONTAINERS   IMAGES                                                                                                                     SELECTOR
daemonset.apps/ingress-nginx-controller   3         3         3       3            3           kubernetes.io/os=linux   6m38s   controller   registry.k8s.io/ingress-nginx/controller:v1.12.1@sha256:d2fbc4ec70d8aa2050dd91a91506e998765e86c96f32cffb56c503c9c34eed5b   app.kubernetes.io/component=controller,app.kubernetes.io/instance=ingress-nginx,app.kubernetes.io/name=ingress-nginx

NAME                                       STATUS     COMPLETIONS   DURATION   AGE     CONTAINERS   IMAGES                                                                                                                              SELECTOR
job.batch/ingress-nginx-admission-create   Complete   1/1           4s         6m38s   create       registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.5.2@sha256:e8825994b7a2c7497375a9b945f386506ca6a3eda80b89b74ef2db743f66a5ea   batch.kubernetes.io/controller-uid=9a15f7e8-7d2f-4363-9e3b-4608232bf2ab
job.batch/ingress-nginx-admission-patch    Complete   1/1           5s         6m38s   patch        registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.5.2@sha256:e8825994b7a2c7497375a9b945f386506ca6a3eda80b89b74ef2db743f66a5ea   batch.kubernetes.io/controller-uid=5db90429-36bf-4743-ac08-15746aec21b2
```
Note the number of `ingress-nginx-controller` pods and their assigned IP addresses.

Default namespace looks like this:
```console
kubectl get all -o=wide
```
```console
NAME                         READY   STATUS    RESTARTS   AGE    IP            NODE      NOMINATED NODE   READINESS GATES
pod/nginx-57f7cbcdcc-wx5gj   1/1     Running   0          9m2s   10.244.2.41   worker1   <none>           <none>

NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE     SELECTOR
service/kubernetes      ClusterIP   10.96.0.1       <none>        443/TCP    2d15h   <none>
service/nginx-service   ClusterIP   10.110.154.55   <none>        8080/TCP   9m2s    app=nginx

NAME                    READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS   IMAGES                               SELECTOR
deployment.apps/nginx   1/1     1            1           9m2s   nginx        nginxinc/nginx-unprivileged:1.27.4   app=nginx

NAME                               DESIRED   CURRENT   READY   AGE    CONTAINERS   IMAGES                               SELECTOR
replicaset.apps/nginx-57f7cbcdcc   1         1         1       9m2s   nginx        nginxinc/nginx-unprivileged:1.27.4   app=nginx,pod-template-hash=57f7cbcdcc
```

Test to confirm that nginx pod from default workspace is accessible by the **control plane IP** with routing by host:
```console
curl -H "Host: nginx.anton.cluster" http://172.16.0.100/
```
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```
and proof that one of nginx's pods served the request:
```console
kubectl get pods -o=wide
```
```console
NAME                     READY   STATUS    RESTARTS   AGE     IP            NODE      NOMINATED NODE   READINESS GATES
nginx-7f7fc686d9-8xb4f   1/1     Running   0          2m26s   10.244.2.43   worker1   <none>           <none>
nginx-7f7fc686d9-c4grf   1/1     Running   0          2m23s   10.244.1.47   worker0   <none>           <none>
```
```console
kubectl logs nginx-7f7fc686d9-8xb4f | grep curl
```
```console
10.244.0.0 - - [11/Apr/2025:10:54:22 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/8.7.1" "172.16.0.90"
```

## DNS

The problem at this point is that I have to communicate with the cluster by the IP address of the control plane. The cluster should be accessible by some domain name, let's say `anton.golebiowski.dev`.

### Domain Configuration for Development

A temporary solution is to add an entry in `/etc/hosts` with a domain that points to the IP address of the cluster:
```console
172.16.0.100 anton.golebiowski.dev
```
This will enable communication with the cluster by the domain name only from the machine that contains this entry. Also, an appropriate host entry must be added to `Ingress`.

### Dynamic DNS

To be able to communicate with the cluster outside the local network, I have to make my local network public and point the domain to my IP address. There is another problem - I have a changing IP address. So in order to make this work, I need to configure a dynamic DNS entry both on the domain provider side and on my local network router. To achieve that I need to:

* Buy a domain (e.g., `golebiowski.dev`).
* Configure Dynamic DNS:
    * At the domain provider configuration panel, I need to add credentials for the subdomain that will be used as a dynamic DNS entry.
    * At the domain provider configuration panel, I need to create a dynamic DNS entry with the subdomain `anton.golebiowski.dev`.
    * On my router, I need to configure dynamic DNS with previously generated credentials so that the changed IP address can be announced and updated on the provider side.
* Configure my router to accept connections from the Internet on ports `80` and `443` and route them to my cluster's control plane. **This can be disabled at any moment**.

The options above address only the domain name resolution problem. Now it's time to deal with certificates to ensure safe communication.

## Certification

For managing certificates, issuers, etc., I used [cert-manager](https://cert-manager.io). Certificates are ordered through Let's Encrypt. The setup was quite easy:

* First, the cert-manager YAML manifest was downloaded and deployed, no changes needed.
* Then I had to create staging and prod Issuers in the **default namespace**.
* After that, I had to reconfigure Ingress to use TLS.

The staging issuer is for testing purposes, due to limitations in calling the Let's Encrypt prod server. Ingress is responsible for creating certificate requests, etc. Everything happens automatically after Ingress creation. To verify if a certificate was successfully created, run:
```console
kubectl get certificates
```
```console
NAME                                READY   SECRET                              AGE
letsencrypt-prod-anton-tls-secret   True    letsencrypt-prod-anton-tls-secret   18h
```

To verify that SSL is working:
```console
curl https://anton.golebiowski.dev
```
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
```

## Summary

To summarize this chapter, I ended up with:

* A working nginx `Deployment` and `Service`.
* A subdomain configured to point to my network.
* Dynamic DNS to update the IP address that the subdomain points to.
* Deployed `cert-manager` to handle certification.
* Updated `Ingress` so that it requests and sets up a certificate for the configured host.
  
-----

Revision summarizing work done in this chapter: `58f8b0cde65cfad9813d2bfa66732f63700e2cde`

Sources:

* [https://hub.docker.com/r/nginxinc/nginx-unprivileged](https://hub.docker.com/r/nginxinc/nginx-unprivileged)
* [https://www.copado.com/resources/blog/kubernetes-deployment-vs-service-managing-your-pods](https://www.copado.com/resources/blog/kubernetes-deployment-vs-service-managing-your-pods)
* [https://hub.docker.com/r/nginxinc/nginx-unprivileged](https://hub.docker.com/r/nginxinc/nginx-unprivileged)
* [https://kubernetes.github.io/ingress-nginx/deploy/baremetal/](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/)
* [https://datavirke.dk/posts/bare-metal-kubernetes-part-1-talos-on-hetzner/](https://datavirke.dk/posts/bare-metal-kubernetes-part-1-talos-on-hetzner/)
* [https://medium.com/@muppedaanvesh/%EF%B8%8F-exploring-types-of-routing-based-ingresses-in-kubernetes-da56f51b3a6b](https://medium.com/@muppedaanvesh/%EF%B8%8F-exploring-types-of-routing-based-ingresses-in-kubernetes-da56f51b3a6b)
* [https://cert-manager.io/docs/tutorials/acme/nginx-ingress/](https://cert-manager.io/docs/tutorials/acme/nginx-ingress/)
* [https://cert-manager.io/docs/installation/kubectl/](https://cert-manager.io/docs/installation/kubectl/)
