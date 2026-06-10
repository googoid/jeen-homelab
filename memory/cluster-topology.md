---
name: cluster-topology
description: Node inventory, IPs, sizing, and network layout of the jeen Talos cluster
metadata:
  type: project
---

Cluster name **jeen**: 3 HA control planes + 3 dedicated workers, Talos **v1.13.4**.

**Network is ISOLATED.** Host LAN is `192.168.1.0/24` (WSL2 sits there at
192.168.1.21 via mirrored mode). The cluster runs on a separate **Internal
Hyper-V switch** on `10.66.6.0/24`; the Windows host is the gateway+NAT at
**10.66.6.1** (`vEthernet (jeen-internal)`). Node DNS: 1.1.1.1 / 8.8.8.8.
Control-plane endpoint = Talos shared **VIP 10.66.6.10** (`https://10.66.6.10:6443`).

| Node  | Role | IP | vCPU | RAM | Disk | MAC |
|-------|------|----|------|-----|------|-----|
| cp-01 | controlplane | 10.66.6.11 | 2 | 4GB | 40GB | 00155D660611 |
| cp-02 | controlplane | 10.66.6.12 | 2 | 4GB | 40GB | 00155D660612 |
| cp-03 | controlplane | 10.66.6.13 | 2 | 4GB | 40GB | 00155D660613 |
| wk-01 | worker | 10.66.6.21 | 4 | 8GB | 100GB | 00155D660621 |
| wk-02 | worker | 10.66.6.22 | 4 | 8GB | 100GB | 00155D660622 |
| wk-03 | worker | 10.66.6.23 | 4 | 8GB | 100GB | 00155D660623 |

VMs are Gen2 with **Secure Boot OFF**. cp-01 bootstraps. Inventory in
`terraform/locals.tf`. See [[infrastructure]], [[deployment-approach]], [[terraform-stack]].
