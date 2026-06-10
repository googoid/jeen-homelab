# jeen — Project Documentation

Milestone log for the Talos Kubernetes homelab cluster.

## Milestone 1 — Terraform scaffold for the cluster (2026-06-10)

Designed and scaffolded the full Terraform stack to deploy a 3-control-plane +
3-worker Talos **v1.13.4** cluster as Hyper-V Gen2 VMs, driven from WSL2.

**Decisions**
- Topology: 3 HA control planes + 3 dedicated workers on `10.66.6.0/24`,
  gateway/DNS `10.66.6.1`, control-plane VIP `10.66.6.10`.
- Sizing: CP 2 vCPU / 4 GB / 40 GB, workers 4 vCPU / 8 GB / 100 GB.
- Gen2 VMs with **Secure Boot OFF** (Hyper-V can't trust Talos's cert chain).
- Static IPs via Talos config; maintenance-mode IP discovered by Hyper-V read-back
  (manual override available as fallback).
- External vSwitch created by Terraform with `allow_management_os = true`.

**Delivered**
- Tooling installed in WSL2 `~/.local/bin`: talosctl v1.13.4, kubectl v1.36.1,
  terraform v1.15.5.
- `terraform/` stack: providers `taliesins/hyperv` v1.2.1, `siderolabs/talos`
  v0.11.0, `hashicorp/time`. `terraform validate` passes.
- Runbook in `terraform/README.md` covering WSL2 mirrored networking, WinRM setup,
  host NIC discovery, and Talos ISO download.

**Status / next step**
- Initial scaffold done; superseded by Milestone 2 (network redesign).

## Milestone 2 — Isolated network redesign (2026-06-10)

Enabled WSL2 mirrored networking and discovered the real LAN is `192.168.1.0/24`
(WSL2 at 192.168.1.21), not `10.66.6.0/24`. Chose to keep the cluster **isolated**
on `10.66.6.0/24` via an **Internal Hyper-V switch** with the host as gateway+NAT.

**Consequences handled**
- An Internal switch has no DHCP, so the maintenance read-back approach was
  dropped. Each node now gets its static IP at first boot from a **per-node Image
  Factory ISO** with an `ip=` kernel arg (`isos.tf`); Terraform builds + stages the
  ISOs to the host via `/mnt/c`. Node IP == endpoint throughout (idempotent).
- Host networking (Internal switch + vNIC 10.66.6.1/24 + NAT) became a one-time
  PowerShell prerequisite (`scripts/host-network-setup.ps1`) since the Hyper-V
  provider can't manage vNIC IPs or NAT.
- Node DNS switched to public resolvers (1.1.1.1/8.8.8.8) reached through NAT.

**Status / next step**
- `terraform validate` passes. Pending user prerequisites: run
  `scripts/host-network-setup.ps1`, then **verify `ping 10.66.6.1` from WSL2**
  (critical — the Talos provider runs in WSL2 and must reach the isolated net).
  Then fill `terraform.tfvars` and `terraform apply`.
