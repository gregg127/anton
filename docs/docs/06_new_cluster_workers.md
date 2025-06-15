# New cluster workers

I bought another two machines to have additional computational resources if needed. This chapter describes how I added new worker nodes to my existing cluster. The computers are HP ProDesk 600 G2 Mini with the following specifications:

* 8GB RAM
* Intel Core i5 6th Gen processor
* 128GB SSD drive

## Adding workers

For each computer, I followed the instructions from chapter [Cluster Setup](01_cluster.md#control-plane-node-setup):

1. Set the secure boot configuration to **Legacy Support Disable and Secure Boot Disable**
2. Formatted the hard drive
3. Created a new patch file in the `patches` directory with appropriate disk selector
4. Generated configuration using `talosctl gen config`
5. Installed Talos from USB drive
6. When Talos was installed, applied the configuration to the machine using `talosctl apply-config`

After this, I needed to apply one more patch - the patch for *Local Path Provisioning* volume mounts as described in chapter [Storage](04_persistance.md). For each node:

1. Created `workerX-create-data-partition.yml` patch in the repository *disk* directory, where X is the worker number
2. Applied the patch to the node using `talosctl patch mc`

## Verification

1. Checked if the new node joined the cluster:
```console
kubectl get nodes -o wide
```
2. Verified that the node was in **Ready** state

## Summary

Adding new worker nodes to my existing Talos cluster proved to be straightforward. The instructions from the initial cluster setup worked perfectly for the new nodes. The process mainly consisted of:

* Following the same BIOS and installation steps as for the initial cluster setup
* Creating and applying appropriate patch files for each new node
* Setting up Local Path Provisioning for storage
