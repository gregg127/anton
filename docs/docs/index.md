# Introduction

Anton is a cluster of servers managed with Kubernetes, serving as my homelab. The name was inspired by the ‘Silicon Valley’ series.
This site is a journal, changelog, documentation, and step-by-step guide on how I set up the homelab and the services running on it.
The goal of this documentation is to outline the steps I followed while saving some of the most important commands, so I can reproduce any step if something goes wrong.

To see the final version of the installation, go to the last chapter - [Quickstart](../99_quickstart).
All chapters before that are incremental, meaning that in some chapters I might have made mistakes or bad choices that are later fixed and described in subsequent chapters.

## Anton nodes specs

The table below lists the servers that are part of the cluster. Swipe the table to the right to see more details.

| **Machine Name** | **Role(s)**           | **Model**              | **RAM** | **Storage** | **CPU**                          | **Graphics**          |
| ---------------- | --------------------- | ---------------------- | ------- | ----------- | -------------------------------- | --------------------- |
| **overlord**     | control plane, worker | HP ProDesk 600 G3 Mini | 8 GB    | 256 GB SSD  | Intel i3-6100T, 3.20GHz, 2 cores | Intel HD Graphics 530 |
| **worker0**      | worker                | HP ProDesk 600 G3 Mini | 8 GB    | 256 GB SSD  | Intel i3-6100T, 3.20GHz, 2 cores | Intel HD Graphics 530 |
| **worker1**      | worker                | HP ProDesk 600 G3 Mini | 8 GB    | 512 GB HDD  | Intel i3-6100T, 3.20GHz, 2 cores | Intel HD Graphics 530 |

## Kubernetes

I decided to use Talos Linux as the operating system for all the machines. I made this decision for several reasons:

* Talos is purpose-built for Kubernetes clusters, so there's no need to install additional software.
* It's very minimal and lightweight, which makes it a great alternative to running Ubuntu on the machines.
* It's secure, which is important to me since I might eventually allow external traffic to the cluster to use it outside my local network.
* It's well-regarded by the DevOps community and YouTubers with experience in setting up Kubernetes clusters.

## Costs

| Category             | Item                         | Description                                        | Qty | Unit Price | Total         |
| -------------------- | ---------------------------- | -------------------------------------------------- | --- | ---------- | ------------- |
| **Computers**        | HP ProDesk 600 G3 Mini       | 8GB RAM, 256GB SSD, one of the first 3 machines    | 1   | 290 PLN    | 290 PLN       |
|                      | HP ProDesk 600 G3 Mini       | 8GB RAM, 256GB SSD, one of the first 3 machines    | 1   | 320 PLN    | 320 PLN       |
|                      | HP ProDesk 600 G3 Mini       | 8GB RAM, 512GB HDD, one of the first 3 machines    | 1   | 284 PLN    | 284 PLN       |
| **Power Monitoring** | LTC M1149                    | Wattmeter for cluster power consumption monitoring | 1   | 45 PLN     | 45 PLN        |
| **Rack Equipment**   | Lanberg WF10-2309-10B        | 10", 9U black rack                                 | 1   | 162 PLN    | 162 PLN       |
|                      | Lanberg rack shelves (1U)    | Shelves for the rack                               | 4   | 30 PLN     | 120 PLN       |
|                      | Power strip / extension cord | 3m length, 5 sockets                               | 1   | 32 PLN     | 32 PLN        |
| **Networking**       | TP-Link LS1005G              | 5-port Gigabit network switch                      | 1   | 45 PLN     | 45 PLN        |
|                      | CCA UTP RJ45 LAN CAT.5 Cable | 20 meters of Ethernet cable                        | 1   | 25 PLN     | 25 PLN        |
|                      | RJ45 crimping tool set       | Includes crimper, cable tester, and 50 RJ45 plugs  | 1   | 60 PLN     | 60 PLN        |
|                      |                              |                                                    |     | **Total**  | **1,383 PLN** |

Power consumption of the whole cluster is in the range of **28–38 Watts**. 
This results in a daily energy usage of around **0.69 kilowatt-hours**, as measured by the wattmeter after a full day of running the cluster.
That costs me around **X PLN** per day.