# General info

Anton is a cluster of servers managed with Kubernetes, serving as my homelab. The name was inspired by the ‘Silicon Valley’ series.
This documentation is a guide how I setup the homelab and what services I have put on it.

## Anton specs

Swipe the table to the right to see more details.

| **Machine Name** | **Role(s)**                          | **RAM** | **Storage** | **CPU**                          | **Model**              | **Notes**                              |
| ---------------- | ------------------------------------ | ------- | ----------- | -------------------------------- | ---------------------- | -------------------------------------- |
| **anton**        | k3s server (master) + agent (worker) | 8 GB    | 256 GB SSD  | Intel i3-6100T, 3.20GHz, 2 cores | HP ProDesk 600 G3 Mini | Control plane + runs workloads         |
| **worker-0**     | k3s agent (worker)                   | 8 GB    | 256 GB SSD  | Intel i3-6100T, 3.20GHz, 2 cores | HP ProDesk 600 G3 Mini | Worker node, use for heavy workloads   |
| **worker-1**     | k3s agent (worker)                   | 8 GB    | 512 GB HDD  | Intel i3-6100T, 3.20GHz, 2 cores | HP ProDesk 600 G3 Mini | Worker node, ideal for light workloads |

## Kubernetes

I am using k3s ([https://k3s.io](https://k3s.io)) Kubernetes distribution due to its simplicity in configuration.
