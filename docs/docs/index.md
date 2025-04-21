# Introduction

Anton is a cluster of servers managed with Kubernetes, serving as my homelab. The name was inspired by the ‘Silicon Valley’ series.
This site is a journal, changelog, documentation, and step-by-step guide on how I set up the homelab and the services running on it.
The goal of this documentation is to outline the steps I followed while saving some of the most important commands, so I can reproduce any step if something goes wrong.

To see the final version of the installation, go to the last chapter - [Quickstart](../99_quickstart).
All chapters before that are incremental, meaning that in some chapters I might have made mistakes or bad choices that are later fixed and described in subsequent chapters.

## Anton nodes specs

The table below lists the servers that are part of the cluster. Swipe the table to the right to see more details.

| **Machine Name** | **Role(s)**           | **Model**              | **RAM** | **Storage** | **CPU**                          | **Graphics**          | **Idle PC** |
| ---------------- | --------------------- | ---------------------- | ------- | ----------- | -------------------------------- | --------------------- | ----------- |
| **overlord**     | control plane, worker | HP ProDesk 600 G3 Mini | 8 GB    | 256 GB SSD  | Intel i3-6100T, 3.20GHz, 2 cores | Intel HD Graphics 530 | 8–15 Watts  |
| **worker0**      | worker                | HP ProDesk 600 G3 Mini | 8 GB    | 256 GB SSD  | Intel i3-6100T, 3.20GHz, 2 cores | Intel HD Graphics 530 | 8–15 Watts  |
| **worker1**      | worker                | HP ProDesk 600 G3 Mini | 8 GB    | 512 GB HDD  | Intel i3-6100T, 3.20GHz, 2 cores | Intel HD Graphics 530 | 8–15 Watts  |

## Kubernetes

I decided to use Talos Linux as the operating system for all the machines. I made this decision for several reasons:

* Talos is purpose-built for Kubernetes clusters, so there's no need to install additional software.
* It's very minimal and lightweight, which makes it a great alternative to running Ubuntu on the machines.
* It's secure, which is important to me since I might eventually allow external traffic to the cluster to use it outside my local network.
* It's well-regarded by the DevOps community and YouTubers with experience in setting up Kubernetes clusters.

## Costs

TODO