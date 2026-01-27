This directory contains Flux GitOps configuration and resources. All resources in this directory are synced with the cluster by Flux using the GitOps workflow.

Configuration files added to this directory do not require manual `kubectl apply` to the cluster - Flux automatically detects changes and applies them through its GitOps reconciliation process.