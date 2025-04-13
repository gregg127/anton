# First service and communication   

Now that I have cluster setup it's time to deploy first services. At the very beggining, for testing purpose I decided to go with [nginx unpriviliged](https://hub.docker.com/r/nginxinc/nginx-unprivileged) that at the very beggining will serve just nginx's default page.
  
This will help me figure out DNS and routing. My two main goals for this step are:

* make deploying new services as easy as possible
* make routing to those services from outside the cluster as easy as possible

For now I decided not to use Helm or any GitOps solutions. I will go with `kubectl` and YAML manifests.

## Deploying application
I have created `nginx.yaml` configuration containing:

* `kind: Deployment` - contains mainly specification for pods, containers and resources. This is used to manage application.
* `kind: Service` - contains communication configuration for the deployment. Ensures that given application is accessible **within the cluster** by the service name. 

These two are the main components of deployed application. After deploying nginx, default namespace of the cluster looks like this:
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

## Cluster accessibility

For now cluster contains deployment and service pointing to the deployment pods. The problem is that now `nginx` is accessible only
within the cluster. After many painful experiments and research, considering that I am working with **bare metal** cluster I made decisions:

* routing will be done with `Ingress` manifests
* to get this working cluster must contain **Ingress controller**
* no external **Load Balancer** will be used
* `NodePorts` will not be used, due to awkward port range `30000-32767`
* `DaemonSet` with **Ingress controller** will be used, so that every cluster node has pod with the controller
* each pod with the controller will use **host network** by adding configuration `template.spec.hostNetwork: true`. Thanks to that:
    * I can avoid port range `30000-32767` and the controller can bind ports `80` and `443` directly to cluster nodes that run applications
    * if I run web applications those will be acccessible without using port range `30000-32767`. For example `nginx` service will be accessible from outside the cluster by address `http://nginx.cluster.local` assuming that `Ingress` with host `nginx.cluster.local` pointing to `nginx` service will be added and external DNS pointing the domain to the cluster will be configured (DNS issue will be described later).
* **control plane** will have to allow scheduling, so that pod with the controller can run on this node.

This solution has some drawbacks and security considerations. I will not describe these here. For detailed explanation about this and the solution above go to sources that my work is based on: [ingress-nginx baremetal](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/), [datavirke's blog](https://datavirke.dk/posts/bare-metal-kubernetes-part-4-ingress-dns-certificates/).

I implemented this idea by:

* adding Kubernetes [ingress-nginx](https://kubernetes.github.io/ingress-nginx/):
    * firstly I copied [bare metal YAML manifest](https://github.com/kubernetes/ingress-nginx/blob/main/deploy/static/provider/baremetal/deploy.yaml) to a file so that I will by able to deploy it using `kubectl apply`
    * from the manifest I removed `Service` with name `ingress-nginx-controller`. This will not be needed because of daemon set
    * `Deployment` with name `ingress-nginx-controller` was changed to `DaemonSet` with added `template.spec.hostNetwork: true` configuration and removed configuration specific for `Deployment` 
    * in order to get `template.spec.hostNetwork: true` working I had to add to nginx-ingress namespace labels `pod-security.kubernetes.io/enforce: privileged` and `pod-security.kubernetes.io/enforce-version: latest`
* adding `Ingress` with `ingressClassName: nginx` (this is a name of `IngressClass` from ingress-nginx) and host `nginx.anton.cluster` routing to `Service` with name `nginx-service` (my service that serves only nginx's default page)

Configuration of [ingress-nginx](https://kubernetes.github.io/ingress-nginx/) is considered as a part of cluster infrastructure and has dedicated namespace with name `ingress-nginx` so that it can be separated from other things and default namespace that will contain my services. `Ingress` configuration(s) will be a part of the default namespace, as this will be changed based on the services that I deploy. Directory structure with cluster resources configuration at this point looks like this:
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
Note the number of `ingress-nginx-controller` pods and assigned IP addresses.

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

The problem at this point is that I have to communicate with cluster by the IP address of control plane. Cluster should be accessible by some domain name, lets say `anton.golebiowski.dev`.

### Domain configuration for development

Temporary solution is to add entry in `/etc/hosts` with domain that points to the IP address of the cluster:
```console
172.16.0.100 anton.golebiowski.dev
```
This will enable communication with cluster by the domain name only from machine that contains this entry. Also appriopriate host entry must be added to `Ingress`.

### Dynamic DNS

To be able to communicate with the cluster outside local network I have to make my local network public and point domain to my IP address. There is another problem - I have changing IP address. So in order to make this work I need to configure dynamic DNS entry both on the domain provider side and on my local network router. To achieve that I need to:

* buy domain (eg. `golebiowski.dev`)
* configure Dynamic DNS
    * at the domain provider configuration panel I need to add credentials for the subdomain that will be used as dynamic DNS entry
    * at the domain provider configuration panel I need to create dynamic DNS entry with subdomain `anton.golebiowski.dev`
    * on my router I need to configure dynamic DNS with previously generated credentials, so that changed IP address can be announced and updated on the provider side
* configure my router to accept connections from the Internet on ports `80` and `443` and route it to my cluster's control plane. **This can be disabled at any moment**.

The options above address only domain name resolution problem. Now it's time to deal with certificates to ensure safe communication.

## Certification

For managing certificates, issuers etc. I used [cert-manager](https://cert-manager.io). Certificate are ordered through Lets Encrypt. Setup was quite easy:

* first cert-manager YAML manifest was downloaded and deployed, no changes needed
* then I had to create staging and prod Issuers in the **default namespace**
* after that I had to reconfigure Ingress to use TLS

Staging issuer is for testing purposes, due to limitations in calling Lets Encrypt prod server. Ingress is responsible for creating certificate request etc. Everything happens automatically after Ingress creation. To verify if certificate was successfully created run:
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

To summarize this chapter I ended up with:

* working nginx `Deployment` and `Service`
* subdomain configured to point to my networkć 
* dynamic DNS to update IP address that the subdomain points to
* deployed `cert-manager` to handle certification
* updated `Ingress` so that it requests and sets up certificate for configured host.
  
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
