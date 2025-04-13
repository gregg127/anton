# Introduction

Anton is a cluster of servers managed with Kubernetes, serving as my homelab. The name was inspired by the ‘Silicon Valley’ series.
This site is a journal/changelog/documentation/step by step guide how I setup the homelab and what services I have put on it.
The goal of this documentation is to show steps that I went through while saving some of the most important commands etc. so 
that I can reproduce any given step if something goes wrong.

To get the final version of installation go to the last chapter - [Quickstart](../99_quickstart).
All chapters before that are done incrementally, meaning that in some chapters I might have done some mistakes and made bad choices that later on would be fixed and described in the following chapters. 

## Anton nodes specs

The table below represents servers that are part of the cluster. Swipe the table to the right to see more details. 

| **Machine Name** | **Role(s)**           | **Model**              | **RAM** | **Storage** | **CPU**                          | **Graphics**          | **Idle PC** |
| ---------------- | --------------------- | ---------------------- | ------- | ----------- | -------------------------------- | --------------------- | ----------- |
| **overlord**     | control plane, worker | HP ProDesk 600 G3 Mini | 8 GB    | 512 GB HDD  | Intel i3-6100T, 3.20GHz, 2 cores | Intel HD Graphics 530 | 8–15 Watts  |
| **worker-0**     | worker                | HP ProDesk 600 G3 Mini | 8 GB    | 256 GB SSD  | Intel i3-6100T, 3.20GHz, 2 cores | Intel HD Graphics 530 | 8–15 Watts  |
| **worker-1**     | worker                | HP ProDesk 600 G3 Mini | 8 GB    | 256 GB SSD  | Intel i3-6100T, 3.20GHz, 2 cores | Intel HD Graphics 530 | 8–15 Watts  |

## Kubernetes

I decided to go with Talos Linux as an operating system for all the machines. I made this decision due to several factors:

* Talos's sole purpose is to be in Kubernetes cluster, no need to install additional software 
* very minimal and lightweight, which is a good alternative to having Ubuntu installed on the machine
* secure, which is important for me because some day I might allow external traffic to the cluster so that I could use it outside my local network
* liked by the devops community and youtubers that have experience in setting up Kubernetes clusters

## Costs

TODO