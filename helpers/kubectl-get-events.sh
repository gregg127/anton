#!/usr/bin/env bash

NAMESPACE="${1:-default}"
kubectl get events --sort-by='.lastTimestamp' --namespace $NAMESPACE
