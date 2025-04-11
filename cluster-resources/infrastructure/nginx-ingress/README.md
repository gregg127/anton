This directory contains configuration of Kubernetes nginx-ingress. That configuration contains resources:
* `kind: Namespace` with name `ingress-nginx`
* `kind: ServiceAccount` with name `ingress-nginx`
* `kind: ServiceAccount` with name `ingress-nginx-admission`
* `kind: Role` with name `ingress-nginx`
* `kind: Role` with name `ingress-nginx-admission`
* `kind: ClusterRole` with name `ingress-nginx`
* `kind: ClusterRole` with name `ingress-nginx-admission`
* `kind: RoleBinding` with name `ingress-nginx`
* `kind: RoleBinding` with name `ingress-nginx-admission`
* `kind: ClusterRoleBinding` with name `ingress-nginx`
* `kind: ClusterRoleBinding` with name `ingress-nginx-admission`
* `kind: ConfigMap` with name `ingress-nginx-controller`
* `kind: DaemonSet` with name `ingress-nginx-controller`
* `kind: Service` with name `ingress-nginx-controller-admission`
* `kind: Job` with name `ingress-nginx-admission-create`
* `kind: Job` with name `ingress-nginx-admission-patch`
* `kind: IngressClass` with name `nginx`
* `kind: ValidatingWebhookConfiguration` with name `ingress-nginx-admission`

YAML manifest source: https://github.com/kubernetes/ingress-nginx/blob/main/deploy/static/provider/baremetal/deploy.yaml.
Changed to the original manifest are described in the documentation.