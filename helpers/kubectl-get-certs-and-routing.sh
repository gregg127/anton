#!/usr/bin/env bash

NAMESPACE="${1:-envoy-gateway-system}"
GATEWAY_NAME="envoy-gateway"
section() { echo; echo "--- $1 ---"; }

section "cluster issuers"
kubectl get clusterissuer

section "certificates"
kubectl get certificate,certificaterequest,order,challenge -n "$NAMESPACE"
kubectl get challenge -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}: {.status.state} - {.status.reason}{"\n"}{end}'

section "tls secrets"
for s in $(kubectl get certificate -n "$NAMESPACE" -o jsonpath='{.items[*].spec.secretName}'); do
    echo "$s:"
    if kubectl get secret "$s" -n "$NAMESPACE" >/dev/null 2>&1; then
        kubectl get secret "$s" -n "$NAMESPACE" -o jsonpath='{.data.tls\.crt}' | base64 -d \
            | openssl x509 -noout -issuer -enddate -ext subjectAltName 2>/dev/null | sed 's/^/  /'
    else
        echo "  missing (not issued yet)"
    fi
done

section "gateway routes"
GATEWAY() { kubectl get gateway "$GATEWAY_NAME" -n "$NAMESPACE" -o jsonpath="$1"; }
paste \
    <(GATEWAY '{range .spec.listeners[*]}{.name}{"\t"}{.port}{"\t"}{.protocol}{"\t"}{.hostname}{"\n"}{end}') \
    <(GATEWAY '{range .status.listeners[*]}routes={.attachedRoutes}{"\t"}{range .conditions[*]}{.type}={.status} {end}{"\n"}{end}') \
    | column -t -s $'\t'

section "http routes"
kubectl get httproute -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.spec.hostnames}{"\t"}{.spec.parentRefs[*].sectionName}{"\t"}accepted={.status.parents[*].conditions[?(@.type=="Accepted")].status}{"\t"}refs={.status.parents[*].conditions[?(@.type=="ResolvedRefs")].status}{"\n"}{end}' \
    | column -t -s $'\t'

section "https check against gateway ip"
IP=$(GATEWAY '{.status.addresses[0].value}')
for h in $(GATEWAY '{.spec.listeners[*].hostname}'); do
    code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 5 --resolve "$h:443:$IP" "https://$h/")
    echo "$h -> $IP : HTTP $code"
done
