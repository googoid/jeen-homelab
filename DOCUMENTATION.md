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

## Milestone 3 — Migrate from Hyper-V to VirtualBox (2026-06-11)

Replaced the Hyper-V VM layer with **VirtualBox**, driven by `VBoxManage` through
Terraform `null_resource` + `local-exec`. Motivation: remove the WinRM +
`taliesins/hyperv` provider friction (not Hyper-V itself). Nothing was deployed,
so it was a clean rewrite.

**Decisions**
- Dropped the `hyperv` provider entirely; no VM provider — Terraform invokes
  `VBoxManage.exe` on the Windows host from WSL2 over `/mnt/c` (no WinRM).
- Vagrant rejected: Talos has no SSH/WinRM communicator and no boxes, so Vagrant
  would be an awkward VM-creator that still needs the talos provider anyway.
- The proven core is unchanged: per-node Image Factory ISO with an `ip=` kernel
  arg for static IPs on a DHCP-less net; talos provider for config/bootstrap.
- VMs are BIOS firmware, single host-only NIC (Intel 82540EM/e1000), empty SATA
  disk + node ISO, boot order `disk` then `dvd` (empty disk falls through to ISO).

**Delivered**
- `vms.tf` rewritten as a guarded, idempotent `null_resource.vm` per node
  (create + destroy provisioners). `talos.tf` dropped the Hyper-V `hv_*` kernel
  modules. `providers.tf`/`versions.tf` dropped hyperv/WinRM. `variables.tf` swaps
  WinRM vars for `vboxmanage` / `vm_dir` / `hostonly_adapter`.
- `scripts/host-network-setup.ps1` rewritten: allowlist `10.66.6.0/24` in
  VirtualBox `networks.conf` (VBox 7 blocks it), host-only adapter at
  `10.66.6.1/24` with DHCP off, Windows NAT for internet.
- README/tfvars updated for the WinRM-free VirtualBox flow.

**Status / next step**
- `terraform validate` passes. Prerequisites: install VirtualBox 7, run
  `scripts/host-network-setup.ps1`, **verify `ping 10.66.6.1` from WSL2**, then
  `terraform apply`. Watch the guest NIC name (`eth0` vs `enp0s3`) on first boot.

## Milestone 4 — Cilium CNI (eBPF, kube-proxy replacement, Hubble) (2026-06-11)

**Decisions**
- Replace Talos's default flannel + kube-proxy with **Cilium** (eBPF datapath).
- Install via the Terraform **`helm` provider** (`~> 2.17`), authenticated from
  the `talos_cluster_kubeconfig` output — no kubeconfig file on disk.
- **Full kube-proxy replacement**, reaching the API server through Talos
  **KubePrism** (`localhost:7445`) rather than the VIP — up independent of CNI,
  so no bootstrap chicken-and-egg.
- **Hubble** (relay + UI) enabled. No LoadBalancer/L2 yet.
- Also switched VMs to **UEFI** (`--firmware efi64`) and forced `eth0` naming via
  `net.ifnames=0` in the ISO kernel args (consistent `ip=` arg + machine config).

**Delivered**
- `talos.tf`: controlplane `config_patches` set `cluster.network.cni.name=none`
  and `cluster.proxy.disabled=true`.
- `cilium.tf` (new): `helm_release.cilium` with Talos values (cgroup hostRoot,
  unprivileged capability sets), `kubeProxyReplacement=true`, KubePrism endpoint,
  Hubble relay+UI; `depends_on` the kubeconfig.
- `providers.tf`/`versions.tf`: helm provider added/configured. `variables.tf`:
  `cilium_version` (1.19.4) + `cilium_namespace` (kube-system).

**Status / next step**
- `terraform validate` passes. Apply rebuilds VMs (UEFI) → fresh bootstrap with
  `cni: none` → Cilium via Helm. Verify: cilium/operator/hubble pods Running,
  nodes Ready, no kube-proxy DaemonSet, `cilium status` shows
  `KubeProxyReplacement: True`. On a cold run, if the helm provider errors on an
  unknown kubeconfig, `terraform apply -target=talos_cluster_kubeconfig.this`
  then re-apply.
