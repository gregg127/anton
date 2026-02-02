# Ingress, DNS, Cloudflare

After many experiments, research and considering that I am working with a **bare metal** cluster, I made the following decisions for external cluster accessibility:

* Routing will be done with `Ingress` manifests.
* To get this working, the cluster must contain an **Ingress controller**.
* No external **Load Balancer** will be used.
* `NodePorts` will not be used due to the awkward port range `30000-32767`.
* A `DaemonSet` with an **Ingress controller** will be used so that every cluster node has a pod with the controller.
* Each pod with the controller will use the **host network** by adding the configuration `template.spec.hostNetwork: true`. Thanks to this:
    * I can avoid the port range `30000-32767`, and the controller can bind ports `80` and `443` directly to cluster nodes that run applications.
    * If I run web applications, they will be accessible without using the port range `30000-32767`. For example, the `nginx` service will be accessible from outside the cluster by the address `http://nginx.cluster.local`, assuming that an `Ingress` with the host `nginx.cluster.local` pointing to the `nginx` service is added and an external DNS pointing the domain to the cluster is configured (DNS issues will be described later).
* The **control plane** must allow scheduling so that a pod with the controller can run on this node.

This solution has some drawbacks and security considerations. I won't describe these here. For a detailed explanation about this and the solution above, check out the sources my work is based on: [ingress-nginx baremetal](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/), [datavirke's blog](https://datavirke.dk/posts/bare-metal-kubernetes-part-4-ingress-dns-certificates/).


## Ingress 
### Nginx Ingress

To implement the solution above, the following steps must be followed:

1. Prepare `nginx-ingress.yaml` file in `cluster-resources/infrastructure/nginx-ingress` directory with Helm configuration (note the custom configuration in *values*):
```yaml
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
2. Prepare `kustomization.yaml` in the same directory:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - nginx-ingress.yaml
```
3. Prepare Flux GitOps Kustomization in `cluster-resources/flux/infrastructure/nginx-ingress.yaml`:
```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: nginx-ingress # name of the Kustomization resource for the application
  namespace: flux-system
spec:
  interval: 10m0s
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system # references the GitRepository resource defined in gotk-sync.yaml
  path: ./cluster-resources/infrastructure/nginx-ingress # path within the Git repository
```
4. Commit, push, and wait for changes to apply
5. Verify ingress resources were created:
```console
kubectl -n ingress-nginx get all -o=wide
``` 
```
NAME                                 READY   STATUS    RESTARTS   AGE   IP             NODE        NOMINATED NODE   READINESS GATES
pod/ingress-nginx-controller-4f726   1/1     Running   0          18m   192.168.10.5   worker2     <none>           <none>
pod/ingress-nginx-controller-6tcsg   1/1     Running   0          18m   192.168.10.2   overlord0   <none>           <none>
pod/ingress-nginx-controller-8pfv2   1/1     Running   0          18m   192.168.10.6   worker3     <none>           <none>
pod/ingress-nginx-controller-ctbcf   1/1     Running   0          18m   192.168.10.4   worker1     <none>           <none>
pod/ingress-nginx-controller-pzns4   1/1     Running   0          18m   192.168.10.3   worker0     <none>           <none>

NAME                                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/ingress-nginx-controller-admission   ClusterIP   10.111.179.70   <none>        443/TCP   18m   app.kubernetes.io/component=controller,app.kubernetes.io/instance=ingress-nginx,app.kubernetes.io/name=ingress-nginx

NAME                                      DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE   CONTAINERS   IMAGES                                                                                                                    SELECTOR
daemonset.apps/ingress-nginx-controller   5         5         5       5            5           kubernetes.io/os=linux   18m   controller   registry.k8s.io/ingress-nginx/controller:v1.8.5@sha256:5831fa630e691c0c8c93ead1b57b37a6a8e5416d3d2364afeb8fe36fe0fef680   app.kubernetes.io/component=controller,app.kubernetes.io/instance=ingress-nginx,app.kubernetes.io/name=ingress-nginx
```

Note the number of `ingress-nginx-controller` pods and their assigned IP addresses.

### Simple NGINX Web Server

To test the nginx ingress configuration, I will manually deploy nginx on the cluster:

1. Prepare YAML file containing Deployment, Service, and Ingress to apply to the cluster:
```yaml
# nginx-test.yaml
---
# Deployment definition for nginx 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        runAsGroup: 101
        fsGroup: 101
      containers:
        - name: nginx
          image: nginxinc/nginx-unprivileged:1.27.4
          ports:
            - containerPort: 8080
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "200m"
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            seccompProfile:
              type: RuntimeDefault
---
# Service definition so that nginx pods are accessible within the cluster
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
---
# Ingress definition to expose nginx service outside the cluster
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: anton-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  ingressClassName: nginx
  rules:
    - host: nginx.anton.cluster
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-service
                port:
                  number: 8080
```
2. Apply to the cluster:
```console
kubectl apply -f nginx-test.yaml
```
3. Add local entry in `/etc/hosts` file so that the host mentioned in Ingress can be mapped to the cluster:
```
<control_plane_ip_address> nginx.anton.cluster
```
4. Verify that it works:
```console
curl http://nginx.anton.cluster 
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
5. Additionally, verify that the deployed Nginx processed the request:
```console
kubectl logs -f <nginx_pod_name>
```
```
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: /etc/nginx/conf.d/default.conf differs from the packaged version
/docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2026/01/27 20:34:55 [notice] 1#1: using the "epoll" event method
2026/01/27 20:34:55 [notice] 1#1: nginx/1.27.4
2026/01/27 20:34:55 [notice] 1#1: built by gcc 12.2.0 (Debian 12.2.0-14) 
2026/01/27 20:34:55 [notice] 1#1: OS: Linux 6.18.5-talos
2026/01/27 20:34:55 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1048576:1048576
2026/01/27 20:34:55 [notice] 1#1: start worker processes
[...]
10.244.0.0 - - [27/Jan/2026:20:37:51 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/8.5.0" "192.168.0.100"
```
6. Clean up the cluster:
```console
kubectl delete -f nginx-test.yaml
```
7. Remove entry from `/etc/hosts`.

## Public access configuration

Now that the cluster has a working web server accessible from outside the cluster, the next step is to configure public access through a domain. The following steps do not cover firewall and router settings, which are described in the *Network Setup* chapter. Assuming that the firewall and router are properly configured, including NAT entries for HTTP and SSL, the required steps are:

1. Purchase and configure a domain with your chosen domain provider
2. Configure the domain in Cloudflare and point it to a static IP address  
3. Configure Dynamic DNS to automatically update the cluster's IP address in Cloudflare

### Domain Provider Configuration

1. Purchase a domain from your chosen domain provider, e.g. OVH
2. Change DNS servers to Cloudflare's nameservers:
   ```
   kai.ns.cloudflare.com
   ximena.ns.cloudflare.com
   ```
3. Remove additional DNS entries from the domain provider panel if necessary, as DNS management will be handled by Cloudflare.

### Cloudflare Configuration

1. Register the new domain in Cloudflare
2. Add a DNS `A` record pointing to your public IP address
3. Verify accessibility - ensure that your cluster is accessible via the domain and that the domain points to Cloudflare servers

!!!warning
    DNS changes require time to propagate across the internet, which can sometimes take several hours.

### Dynamic DNS Setup

Since I have a dynamic IP address, I need to deploy a service within the cluster that uses DDNS (Dynamic DNS) to automatically update DNS records in Cloudflare for domains that route to my cluster. For this purpose, I will use the [ddns-updater](https://github.com/qdm12/ddns-updater) Docker image.

The deployment consists of the following components:

1. `namespace.yaml` - defines a namespace for ddns-updater resources
2. `deployment.yaml` - configures the application using the `qmcgaw/ddns-updater` image from Docker Hub
3. `secret.yaml` - contains Cloudflare API configuration:

```yaml
apiVersion: v1
kind: Secret
metadata:
    name: ddns-updater-config
    namespace: ddns
type: Opaque
stringData:
    CONFIG: |-
        {
            "settings":
            [
                {
                    "provider": "cloudflare",
                    "zone_identifier": "<zone_id>",
                    "domain": "<domain>",
                    "ttl": 600,
                    "token": "<token>",
                    "ip_version": "ipv4",
                    "ipv6_suffix": ""
                }
            ]
        }
```

Configuration parameters:

- `<zone_id>` - Available from Cloudflare's domain dashboard
- `<domain>` - Your domain name (e.g., `example.com`)
- `<token>` - Generate this by navigating to the User API tokens page and creating a token from the **Edit zone DNS** template

All files are available in the project repository. Since the deployment is managed by Flux, an additional YAML file must be created to deploy the service to the cluster using GitOps methodology, similar to the process described in the *Nginx Ingress* section.

-----

Sources:

* [https://www.copado.com/resources/blog/kubernetes-deployment-vs-service-managing-your-pods](https://www.copado.com/resources/blog/kubernetes-deployment-vs-service-managing-your-pods)
* [https://hub.docker.com/r/nginxinc/nginx-unprivileged](https://hub.docker.com/r/nginxinc/nginx-unprivileged)
* [https://kubernetes.github.io/ingress-nginx/deploy/baremetal/](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/)
* [https://datavirke.dk/posts/bare-metal-kubernetes-part-4-ingress-dns-certificates/](https://datavirke.dk/posts/bare-metal-kubernetes-part-4-ingress-dns-certificates/)
* [https://medium.com/@muppedaanvesh/%EF%B8%8F-exploring-types-of-routing-based-ingresses-in-kubernetes-da56f51b3a6b](https://medium.com/@muppedaanvesh/%EF%B8%8F-exploring-types-of-routing-based-ingresses-in-kubernetes-da56f51b3a6b)
