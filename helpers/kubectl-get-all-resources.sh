#!/usr/bin/env bash

# get all resources from given namespace
NAMESPACE="${1:-default}"
kubectl -n $NAMESPACE get $(kubectl api-resources --namespaced=true -o name | egrep -v 'events|nodes' | paste -s -d, - )
