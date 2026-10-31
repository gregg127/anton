# Gateway API, Envoy Gateway, MetalLB

I moved from the Nginx Ingress Controller to [Envoy Gateway](https://gateway.envoyproxy.io) and [MetalLB](https://metallb.io).

Why?

* Ingress NGINX is not supported anymore. The project was retired in March 2026, so it no longer gets releases, bug fixes or security patches.
* All traffic from the internet was forwarded to a single machine, the control plane. If that node went down, every site went down with it, even though the Ingress controller was running on all the nodes.
* Envoy Gateway is an implementation of the Gateway API, which is the successor of the `Ingress` API in Kubernetes. Instead of moving to another `Ingress` controller, I can start using the newer standard.

What happened?

* I added **MetalLB** in **L2 mode** as the load balancer. Previously there was no load balancer and all the traffic went to the control plane node. L2 mode adds a virtual IP address (`192.168.10.30`) that isn't tied to one machine. One node at a time answers ARP requests for it, and if that node fails, another one takes over, so the router always forwards traffic to the same address.
* I centralized the routing configuration in the Envoy `Gateway`. Previously each `Ingress` defined its own hostnames and TLS next to the application. Now all hostnames, TLS settings and certificates are in the `envoy-gateway` directory, and each application only keeps an `HTTPRoute` that attaches to its listener.
* I removed `hostNetwork` and the `DaemonSet`. Envoy now runs as a regular `Deployment` with **2 replicas**. Previously the controller ran on every node, with pods bound directly to ports `80` and `443` of the machines. With MetalLB, traffic enters through the `LoadBalancer` service on its own IP address, so the Envoy pods stay on the regular pod network, nothing occupies ports `80` and `443` on the nodes, and the scheduler decides where the pods run. As long as the two replicas are on different nodes, the cluster survives losing one of them, because MetalLB can announce the IP from the node with the other Envoy pod.

## How it works

A request from the internet now takes this path (simplified):

```
Client
  ↓
Cloudflare
  ↓
Cluster router - NAT rules forward ports 80 and 443 to 192.168.10.30
  ↓
MetalLB - one node answers ARP requests for this IP
  ↓
kube-proxy - forwards traffic to the Envoy service (type LoadBalancer)
  ↓
Envoy pod - TLS termination, host and path matching from HTTPRoutes
  ↓
Application pod
```

* **MetalLB does not receive traffic.** It only makes an IP address reachable on the LAN. The speaker on one node answers ARP requests for that IP, and from there kube-proxy delivers the traffic to pods. The router has to forward to the MetalLB IP instead of a node IP.
* **Assigning an IP and advertising it are two separate things.** The `IPAddressPool` only says which addresses MetalLB can hand out to services. The `L2Advertisement` is what tells MetalLB to announce them on the network. When a device asks who has `192.168.10.30`, the speaker on one node replies with that node's MAC address, so packets for this IP go to that nod.
* **L2 mode is failover, not load balancing.** Each IP is announced by one node at a time. If that node dies, another one takes over the IP and the address stays the same.
* **One `Gateway` means one `LoadBalancer` service and one IP.** Envoy Gateway creates the service, and MetalLB assigns it an IP from the pool. All sites share this entry point. The service passes traffic to the Envoy pods. Envoy is what picks the application, based on the hostname and path from the `HTTPRoutes`.
* **Envoy Gateway has separate control and data planes.** In ingress-nginx one pod did both jobs. Here the `envoy-gateway` pod only watches resources and pushes configuration to the Envoy proxy pods, and it's never in the request path. The Helm chart installs **only the controller**. Proxy pods and their `LoadBalancer` service appear once a valid `Gateway` exists.

## MetalLB

MetalLB consists of two main components:

* **Controller** - a single `Deployment` that assigns IPs. It watches services of type `LoadBalancer` and gives each of them an address from the pool.
* **Speaker** - a `DaemonSet` with a pod on every node that makes these IPs reachable. In L2 mode the speakers choose one node to announce each IP, and this node answers ARP requests for it. If the node fails, a speaker on another node takes over.

The interesting part of the MetalLB configuration is the address pool and the L2 advertisement. The rest is a standard installation, and all the files are in the `cluster-resources/infrastructure/metallb` directory.

An `IPAddressPool` doesn't create any network, it's just a list of addresses MetalLB is allowed to hand out. In L2 mode they must be in the same subnet as the nodes, must not be node IPs, and must be outside the router's DHCP range:

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.10.30-192.168.10.60
  autoAssign: true
```

An `L2Advertisement` announces the addresses from the pool on the network. Without it IPs are assigned, but never announced, so `EXTERNAL-IP` shows up on the service and nothing can reach it:

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - default-pool
```

## Envoy Gateway

The configuration includes four resources:

* `GatewayClass` - says which controller handles the `Gateways` of this class. It's a cluster-wide resource, similar to `IngressClass`. Here it points to the Envoy Gateway controller.
* `Gateway` - the entry point to the cluster. It defines listeners, which are combinations of port, protocol, hostname and TLS certificate. Based on this resource Envoy Gateway creates the Envoy pods and their `LoadBalancer` service.
* `EnvoyProxy` - defines how the Envoy pods and their service run, for example the number of replicas or service annotations. It's specific to Envoy Gateway and isn't part of the Gateway API.
* `HTTPRoute` - defines where the traffic goes, based on hostname and path. It lives next to the application and points to its `Service` with `backendRefs`. A route can attach to a listener only if the listener allows it with `allowedRoutes`.

### Adding a new service

Exposing a new service requires three changes:

1. Create a `Certificate` in the `envoy-gateway-system` namespace, because the listeners look for TLS secrets in the namespace of the `Gateway`. The file goes to the `cluster-resources/infrastructure/envoy-gateway` directory, and it must also be added to `kustomization.yaml` there:
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-certificate
  namespace: envoy-gateway-system
spec:
  secretName: letsencrypt-prod-example-tls-secret
  dnsNames:
    - example.com
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
    group: cert-manager.io
```
2. Add a listener to the `Gateway`. `certificateRefs` must match `secretName` from the `Certificate`:
```yaml
    - name: https-example
      protocol: HTTPS
      port: 443
      hostname: example.com
      tls:
        mode: Terminate
        certificateRefs:
          - name: letsencrypt-prod-example-tls-secret
      allowedRoutes:
        namespaces:
          from: All
```
3. Create an `HTTPRoute` next to the application. `sectionName` must match the name of the listener:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: example-route
  namespace: example
spec:
  parentRefs:
    - name: envoy-gateway
      namespace: envoy-gateway-system
      sectionName: https-example
  hostnames:
    - example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: example-service
          port: 8080
```
---

Sources:

* [https://medium.com/@damindubandara/setting-up-envoy-gateway-in-kubernetes-233f9428ca8c](https://medium.com/@damindubandara/setting-up-envoy-gateway-in-kubernetes-233f9428ca8c)
* [https://oneuptime.com/blog/post/2026-03-05-helmrelease-deploy-metallb-flux/view](https://oneuptime.com/blog/post/2026-03-05-helmrelease-deploy-metallb-flux/view)
* [https://gateway.envoyproxy.io/docs/install/install-flux/](https://gateway.envoyproxy.io/docs/install/install-flux/)
* [https://metallb.io/usage/](https://metallb.io/usage/)
