---
name: cluster-topology
description: Node inventory, IPs, sizing, and network layout of the jeen Talos cluster
metadata:
  type: project
---

Cluster name **jeen**: 3 HA control planes + 3 dedicated workers, Talos **v1.13.4**.

**Network is ISOLATED.** Host LAN is `192.168.1.0/24` (WSL2 sits there at
192.168.1.21 via mirrored mode). The cluster runs on a separate **VirtualBox
host-only network** on `10.66.6.0/24`; the Windows host is the gateway+NAT at
**10.66.6.1** (the "VirtualBox Host-Only Ethernet Adapter"). Node DNS: 1.1.1.1 /
8.8.8.8. Control-plane endpoint = Talos shared **VIP 10.66.6.10**
(`https://10.66.6.10:6443`).

| Node  | Role | IP | vCPU | RAM | OS disk | Ceph disks |
|-------|------|----|------|-----|---------|------------|
| cp-01 | controlplane | 10.66.6.11 | 1 | 2GB | 20GB | — |
| cp-02 | controlplane | 10.66.6.12 | 1 | 2GB | 20GB | — |
| cp-03 | controlplane | 10.66.6.13 | 1 | 2GB | 20GB | — |
| wk-01 | worker | 10.66.6.21 | 4 | 8GB | 40GB | 2×60GB (sdb,sdc) |
| wk-02 | worker | 10.66.6.22 | 4 | 8GB | 40GB | 2×60GB (sdb,sdc) |
| wk-03 | worker | 10.66.6.23 | 4 | 8GB | 40GB | 2×60GB (sdb,sdc) |

VirtualBox VMs use **UEFI firmware** (`efi64`), a single host-only NIC, and SATA
disks: OS on port 0 (`/dev/sda`, Talos installs here), per-node ISO on port 1.
**Workers** also get two 60GB raw disks on ports 2/3 (`/dev/sdb`,`/dev/sdc`) for
**Rook-Ceph OSDs** (6 OSDs, 360GB raw, ~120GB usable @ replica 3 — see
[[storage-rook-ceph]]). MACs auto-assigned (design keys on interface name + static
IP). cp-01 bootstraps. Inventory in `terraform/locals.tf` (`ceph_disks` per node).
See [[infrastructure]], [[deployment-approach]], [[terraform-stack]].
