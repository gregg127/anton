# Ingress, DNS, Cloudflare, certification

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

## TLS Certificates

For managing certificates and issuers, I use [cert-manager](https://cert-manager.io). Certificates are automatically provisioned through Let's Encrypt. The following steps demonstrate how to configure this system:

### Setup cert-manager and certificate issuers

1. Prepare *cert-manager* Helm YAML configuration files in the `cluster-resources/infrastructure/cert-manager` directory. This directory contains the *HelmRepository*, *HelmRelease*, and appropriate namespace definitions.

2. Apply the configuration to the cluster:
```console
kubectl apply -k cluster-resources/infrastructure/cert-manager
```

3. Verify that the changes were applied successfully:
```console
kubectl get all -n cert-manager
```
```
NAME                                           READY   STATUS    RESTARTS   AGE
pod/cert-manager-6fc7c98586-jj9nv              1/1     Running   0          6m24s
pod/cert-manager-cainjector-6d5fcb7b56-vpj6z   1/1     Running   0          6m24s
pod/cert-manager-webhook-5cf564fd96-qsj2r      1/1     Running   0          6m24s

NAME                           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/cert-manager           ClusterIP   10.98.2.243      <none>        9402/TCP   6m24s
service/cert-manager-webhook   ClusterIP   10.103.177.147   <none>        443/TCP    6m24s

NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/cert-manager              1/1     1            1           6m24s
deployment.apps/cert-manager-cainjector   1/1     1            1           6m24s
deployment.apps/cert-manager-webhook      1/1     1            1           6m24s

NAME                                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/cert-manager-6fc7c98586              1         1         1       6m24s
replicaset.apps/cert-manager-cainjector-6d5fcb7b56   1         1         1       6m24s
replicaset.apps/cert-manager-webhook-5cf564fd96      1         1         1       6m24s
```

4. Prepare certificate issuer configuration files in the `cluster-resources/infrastructure/cert-issuers` directory. This directory contains staging and production certificate issuers along with the appropriate namespace configuration.

5. Apply the issuer configuration to the cluster:
```console
kubectl apply -k cluster-resources/infrastructure/cert-issuers
```

6. Verify that the cluster issuers were created successfully:
```console
kubectl get clusterissuer
```
```
NAME                  READY   AGE
letsencrypt-prod      True    2m31s
letsencrypt-staging   True    2m31s
```

!!!note 
    The staging issuer is used for testing purposes due to rate limiting restrictions on the Let's Encrypt production server. The **Ingress** resource is responsible for creating certificate requests automatically. All certificate provisioning occurs automatically after **Ingress** creation.

### Create example service with TLS

The following example demonstrates deploying a service that will be accessible from the internet with automatic TLS certificate provisioning:

1. **Prerequisites**: Ensure that the domain you will be using is properly configured and points to your cluster. In this example, `golebiowski.dev` is configured in Cloudflare with DNS entries pointing to the cluster network.

2. Create a YAML file with an example application and Ingress configuration:
```yaml
# nginx-tls-test.yaml
---
# deployment definition for nginx 
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
# service definition so that nginx pods are accessible within the cluster
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
# ingress definition to expose nginx service outside the cluster
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: anton-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - golebiowski.dev
      secretName: letsencrypt-prod-nginx-tls-secret
  rules:
    - host: golebiowski.dev 
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
note important Ingress configuration values:
    - `cert-manager.io/cluster-issuer`: points to the certificate issuer (letsencrypt-prod)
    - `tls.hosts`: domain for which the certificate will be issued
    - `tls.secretName`: this configuration creates a secret to store the certificate

3. Apply the YAML configuration to the cluster:
```console
kubectl apply -f nginx-tls-test.yaml
```

4. Verify that the TLS secret was created:
```console
kubectl get secrets
```
```
NAME                                      TYPE     DATA   AGE
letsencrypt-prod-nginx-tls-secret-xzsxh   Opaque   1      3s
...
```

5. Verify that the certificate was created:
```console
kubectl get certificates
```
```
NAME                                READY   SECRET                              AGE
letsencrypt-prod-nginx-tls-secret   True    letsencrypt-prod-nginx-tls-secret   65s
```

6. Verify that the certificate was successfully issued:
```console
kubectl describe certificate letsencrypt-prod-nginx-tls-secret
```
```
Name:         letsencrypt-prod-nginx-tls-secret
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  cert-manager.io/v1
Kind:         Certificate
Metadata:
  Creation Timestamp:  2026-02-02T18:48:47Z
  Generation:          1
  Owner References:
    API Version:           networking.k8s.io/v1
    Block Owner Deletion:  true
    Controller:            true
    Kind:                  Ingress
    Name:                  anton-ingress
    UID:                   849937f9-c4ca-4f11-994d-60ff363c5b16
  Resource Version:        399902
  UID:                     b9c83066-26e2-44d2-b817-d43870b36f30
Spec:
  Dns Names:
    golebiowski.dev
  Issuer Ref:
    Group:      cert-manager.io
    Kind:       ClusterIssuer
    Name:       letsencrypt-prod
  Secret Name:  letsencrypt-prod-nginx-tls-secret
  Usages:
    digital signature
    key encipherment
Status:
  Conditions:
    Last Transition Time:  2026-02-02T18:49:17Z
    Message:               Certificate is up to date and has not expired
    Observed Generation:   1
    Reason:                Ready
    Status:                True
    Type:                  Ready
  Not After:               2026-05-03T17:50:43Z
  Not Before:              2026-02-02T17:50:44Z
  Renewal Time:            2026-04-03T17:50:43Z
  Revision:                1
Events:
  Type    Reason     Age   From                                       Message
  ----    ------     ----  ----                                       -------
  Normal  Issuing    2m2s  cert-manager-certificates-trigger          Issuing certificate as Secret does not exist
  Normal  Generated  2m1s  cert-manager-certificates-key-manager      Stored new private key in temporary Secret resource "letsencrypt-prod-nginx-tls-secret-xzsxh"
  Normal  Requested  2m1s  cert-manager-certificates-request-manager  Created new CertificateRequest resource "letsencrypt-prod-nginx-tls-secret-9j2xk"
  Normal  Issuing    92s   cert-manager-certificates-issuing          The certificate has been successfully issued
```

7. As an additional check add an entry to `/etc/hosts` for the domain so that requests go directly to the cluster from your local machine:
```
<control_plane_ip> golebiowski.dev
```

8. Verify the certificate using OpenSSL:
```console
openssl s_client -showcerts -connect golebiowski.dev:443 </dev/null
```
```
CONNECTED(00000003)
depth=2 C = US, O = Internet Security Research Group, CN = ISRG Root X1
verify return:1
depth=1 C = US, O = Let's Encrypt, CN = R12
verify return:1
depth=0 CN = golebiowski.dev
verify return:1
---
Certificate chain
 0 s:CN = golebiowski.dev
   i:C = US, O = Let's Encrypt, CN = R12
   a:PKEY: rsaEncryption, 2048 (bit); sigalg: RSA-SHA256
   v:NotBefore: Feb  2 17:50:44 2026 GMT; NotAfter: May  3 17:50:43 2026 GMT
-----BEGIN CERTIFICATE-----
MIIFAzCCA+ugAwIBAgISBskH9gXccrdALc1rB8twXfz8MA0GCSqGSIb3DQEBCwUA
MDMxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQwwCgYDVQQD
EwNSMTIwHhcNMjYwMjAyMTc1MDQ0WhcNMjYwNTAzMTc1MDQzWjAaMRgwFgYDVQQD
Ew9nb2xlYmlvd3NraS5kZXYwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
AQC2OUeEvuNtiNU9d/CQEEwfLKWx0195Nmro3AKbe/OdQ92q090ZO8GGOGBF7t6Q
CuNeFmuYsS8OvbMV7PwZh/u9nqW9aSK/Jg6KIZMV/zr2GVO8LugRQLCwPlNTPPXT
3W8wnmdvJ/b3HowHrsyCpOPXahIst4kGJiWslPNLHRU2XP7RcO3KP41utFaNXW7A
4spLwGHBKvEvrJ/X0BpZpE32MGlsZmB7grjO31oTTTZdBmJbioQJmDvIyym8jx5U
LwJEzMKZy6iZRUodGAHbuDxGLRhGaAl6WKEtbar8J0seGWaFA/kbbnqhivmB1T1U
PPQvyj6gyqyuTc65JW00HKcFAgMBAAGjggIoMIICJDAOBgNVHQ8BAf8EBAMCBaAw
HQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMAwGA1UdEwEB/wQCMAAwHQYD
VR0OBBYEFDx0padRkXPnINg0eLt9ejHPVMBJMB8GA1UdIwQYMBaAFAC1KfItjm8x
6JtMrXg++tzpDNHSMDMGCCsGAQUFBwEBBCcwJTAjBggrBgEFBQcwAoYXaHR0cDov
L3IxMi5pLmxlbmNyLm9yZy8wGgYDVR0RBBMwEYIPZ29sZWJpb3dza2kuZGV2MBMG
A1UdIAQMMAowCAYGZ4EMAQIBMC8GA1UdHwQoMCYwJKAioCCGHmh0dHA6Ly9yMTIu
Yy5sZW5jci5vcmcvMTI1LmNybDCCAQwGCisGAQQB1nkCBAIEgf0EgfoA+AB+AOMj
jfKNoojgquCs8PqQyYXwtr/10qUnsAH8HERYxLboAAABnB+wAhwACAAABQAxSaB0
BAMARzBFAiAMkgokpBFsz6COIEfdx8478UWFjwVw3CgEBSCtoGihYwIhAOj59a6E
ib9qU4ptB+9loYx96prHa6+Q6AGj95CX61+UAHYADleUvPOuqT4zGyyZB7P3kN+b
wj1xMiXdIaklrGHFTiEAAAGcH7AJxgAABAMARzBFAiEAqyR4GsBhvzaRZxSmjDAW
dFW6oa6NSgk/hXsRRuW2Ju0CIAfoqJoNaSmmVPke7ibaU0a6v8Cb0uQ5jff8stfp
gVDdMA0GCSqGSIb3DQEBCwUAA4IBAQBhB0VoJNIMGimQBRQ+jwxNumqaBL/ZWqub
YKCWtYyBx+tXUVwPwgYun1fenUPEWmtl8Udd5zBLAvanW4afRG6iFgMO/mmGV4dO
lIMCC5cNOa6Kqgk3qDgW9nP9t/pEikM9L6qFVnwKqOoP7crCDXA8dh9Z1zuvKgvG
zSF40pfz4lFybqrUddcdyD5m39WGIi5GGhlUB019HhJG6sjNG6f8HWyMWuwTVacI
b8ozsuNgcMepaZHc7TF+GB9287oYO7Ak4iSQOyg1KLc/yJMgPfgYezWSFCgoPp6J
MAt6VaAxtTUur8UOPEZOupTCLPxcBPk5/k6ns7W5OQYZzbn9BaOg
-----END CERTIFICATE-----
 1 s:C = US, O = Let's Encrypt, CN = R12
   i:C = US, O = Internet Security Research Group, CN = ISRG Root X1
   a:PKEY: rsaEncryption, 2048 (bit); sigalg: RSA-SHA256
   v:NotBefore: Mar 13 00:00:00 2024 GMT; NotAfter: Mar 12 23:59:59 2027 GMT
-----BEGIN CERTIFICATE-----
MIIFBjCCAu6gAwIBAgIRAMISMktwqbSRcdxA9+KFJjwwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMjQwMzEzMDAwMDAw
WhcNMjcwMzEyMjM1OTU5WjAzMQswCQYDVQQGEwJVUzEWMBQGA1UEChMNTGV0J3Mg
RW5jcnlwdDEMMAoGA1UEAxMDUjEyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
CgKCAQEA2pgodK2+lP474B7i5Ut1qywSf+2nAzJ+Npfs6DGPpRONC5kuHs0BUT1M
5ShuCVUxqqUiXXL0LQfCTUA83wEjuXg39RplMjTmhnGdBO+ECFu9AhqZ66YBAJpz
kG2Pogeg0JfT2kVhgTU9FPnEwF9q3AuWGrCf4yrqvSrWmMebcas7dA8827JgvlpL
Thjp2ypzXIlhZZ7+7Tymy05v5J75AEaz/xlNKmOzjmbGGIVwx1Blbzt05UiDDwhY
XS0jnV6j/ujbAKHS9OMZTfLuevYnnuXNnC2i8n+cF63vEzc50bTILEHWhsDp7CH4
WRt/uTp8n1wBnWIEwii9Cq08yhDsGwIDAQABo4H4MIH1MA4GA1UdDwEB/wQEAwIB
hjAdBgNVHSUEFjAUBggrBgEFBQcDAgYIKwYBBQUHAwEwEgYDVR0TAQH/BAgwBgEB
/wIBADAdBgNVHQ4EFgQUALUp8i2ObzHom0yteD763OkM0dIwHwYDVR0jBBgwFoAU
ebRZ5nu25eQBc4AIiMgaWPbpm24wMgYIKwYBBQUHAQEEJjAkMCIGCCsGAQUFBzAC
hhZodHRwOi8veDEuaS5sZW5jci5vcmcvMBMGA1UdIAQMMAowCAYGZ4EMAQIBMCcG
A1UdHwQgMB4wHKAaoBiGFmh0dHA6Ly94MS5jLmxlbmNyLm9yZy8wDQYJKoZIhvcN
AQELBQADggIBAI910AnPanZIZTKS3rVEyIV29BWEjAK/duuz8eL5boSoVpHhkkv3
4eoAeEiPdZLj5EZ7G2ArIK+gzhTlRQ1q4FKGpPPaFBSpqV/xbUb5UlAXQOnkHn3m
FVj+qYv87/WeY+Bm4sN3Ox8BhyaU7UAQ3LeZ7N1X01xxQe4wIAAE3JVLUCiHmZL+
qoCUtgYIFPgcg350QMUIWgxPXNGEncT921ne7nluI02V8pLUmClqXOsCwULw+PVO
ZCB7qOMxxMBoCUeL2Ll4oMpOSr5pJCpLN3tRA2s6P1KLs9TSrVhOk+7LX28NMUlI
usQ/nxLJID0RhAeFtPjyOCOscQBA53+NRjSCak7P4A5jX7ppmkcJECL+S0i3kXVU
y5Me5BbrU8973jZNv/ax6+ZK6TM8jWmimL6of6OrX7ZU6E2WqazzsFrLG3o2kySb
zlhSgJ81Cl4tv3SbYiYXnJExKQvzf83DYotox3f0fwv7xln1A2ZLplCb0O+l/AK0
YE0DS2FPxSAHi0iwMfW2nNHJrXcY3LLHD77gRgje4Eveubi2xxa+Nmk/hmhLdIET
iVDFanoCrMVIpQ59XWHkzdFmoHXHBV7oibVjGSO7ULSQ7MJ1Nz51phuDJSgAIU7A
0zrLnOrAj/dfrlEWRhCvAgbuwLZX1A2sjNjXoPOHbsPiy+lO1KF8/XY7
-----END CERTIFICATE-----
---
Server certificate
subject=CN = golebiowski.dev
issuer=C = US, O = Let's Encrypt, CN = R12
---
No client certificate CA names sent
Peer signing digest: SHA256
Peer signature type: RSA-PSS
Server Temp Key: X25519, 253 bits
---
SSL handshake has read 3142 bytes and written 397 bytes
Verification: OK
---
New, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384
Server public key is 2048 bit
Secure Renegotiation IS NOT supported
Compression: NONE
Expansion: NONE
No ALPN negotiated
Early data was not sent
Verify return code: 0 (ok)
---
DONE
```
9. Cleanup: 
    * remove the entry from the `/etc/hosts` file
    * remove the test Nginx deployment:
    ```console
    kubectl delete -f nginx-tls-test.yaml
    ```
10. Add new YAML files for *cert-manager* and *cert-issuers* for Flux system.

-----

Sources:

* [https://www.copado.com/resources/blog/kubernetes-deployment-vs-service-managing-your-pods](https://www.copado.com/resources/blog/kubernetes-deployment-vs-service-managing-your-pods)
* [https://hub.docker.com/r/nginxinc/nginx-unprivileged](https://hub.docker.com/r/nginxinc/nginx-unprivileged)
* [https://kubernetes.github.io/ingress-nginx/deploy/baremetal/](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/)
* [https://datavirke.dk/posts/bare-metal-kubernetes-part-4-ingress-dns-certificates/](https://datavirke.dk/posts/bare-metal-kubernetes-part-4-ingress-dns-certificates/)
* [https://medium.com/@muppedaanvesh/%EF%B8%8F-exploring-types-of-routing-based-ingresses-in-kubernetes-da56f51b3a6b](https://medium.com/@muppedaanvesh/%EF%B8%8F-exploring-types-of-routing-based-ingresses-in-kubernetes-da56f51b3a6b)