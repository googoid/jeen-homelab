---
name: terraform-stack
description: Terraform layout, provider versions, and deploy gotchas for the cluster
metadata:
  type: project
---

Terraform in `terraform/`. Providers (pinned in `.terraform.lock.hcl`):
- `siderolabs/talos` **v0.11.0** — schematics, machine config, apply, bootstrap, kubeconfig.
- `hashicorp/helm` **~> 2.17** — installs Cilium (`cilium.tf`), authenticated from
  `talos_cluster_kubeconfig.this.kubernetes_client_configuration` (no kubeconfig file).
- `fluxcd/flux` **~> 1.8** + `integrations/github` **~> 6.1** + `hashicorp/tls`
  **~> 4.0** + `hashicorp/kubernetes` **~> 2.30** — Flux GitOps bootstrap
  (`flux.tf`) + sops-age Secret (`sops.tf`). See [[gitops-flux]].
- `hashicorp/null` (ISO download + VM lifecycle), `hashicorp/time` (reboot delay).
- **No VM provider:** VirtualBox VMs are created by driving `VBoxManage` via
  `null_resource` + `local-exec` (`vms.tf`). The old `taliesins/hyperv` provider
  and all WinRM config were removed (Milestone 3).

Files: versions/providers/variables/locals/network/isos/vms/talos/cilium/flux/sops/outputs.tf +
`scripts/host-network-setup.ps1`, `terraform.tfvars.example`, `.gitignore`, `README.md`.
Flux GitOps manifests live OUTSIDE terraform/ (monorepo): `clusters/jeen/`,
`infrastructure/`, `apps/`, root `.sops.yaml` — see [[gitops-flux]].

**CNI = Cilium (Milestone 4):** controlplane `config_patches` (talos.tf) set
`cluster.network.cni.name=none` + `cluster.proxy.disabled=true`; `cilium.tf`
`helm_release` (chart `cilium` `var.cilium_version`=1.19.4, ns kube-system) does
**full kube-proxy replacement** reaching the API via **KubePrism**
(`k8sServiceHost=localhost`, `k8sServicePort=7445` — up independent of CNI/VIP).
Talos-required values: `cgroup.autoMount=false`+`hostRoot=/sys/fs/cgroup`, explicit
`securityContext.capabilities` (Cilium runs unprivileged). **Hubble** relay+UI on.
Nodes stay NotReady until the helm_release lands. Cold-run gotcha: helm provider
reads kubeconfig from a same-apply resource — if it errors, `terraform apply
-target=talos_cluster_kubeconfig.this` then re-apply.

**Isolated-network bootstrap (key design, unchanged):** host-only adapter has NO
DHCP, so each node gets its static IP at first boot via a **per-node Image Factory
ISO** with an `ip=` kernel arg (`isos.tf`: `talos_image_factory_schematic` +
`talos_image_factory_urls` + `null_resource` curl to `/mnt/c/talos/<node>.iso`).
`ip=` syntax: `ip=<client>::<gw>:<netmask>:<host>:<dev>:none`. Node IP == endpoint
throughout (idempotent). Image Factory urls field is `urls.iso`.

**VM creation (`vms.tf`):** one guarded/idempotent `null_resource.vm` per node.
Create provisioner: `createvm` → `modifyvm` (cpus/memory, `--firmware bios`,
`--nic1 hostonly --hostonlyadapter1 "<name>" --nictype1 82540EM`,
`--boot1 disk --boot2 dvd`) → `createhd` sized VDI → `storagectl SATA` (IntelAhci)
→ attach VDI (port 0) + node ISO (port 1) → `startvm --type headless`. Destroy
provisioner: `controlvm poweroff` + `unregistervm --delete`. Empty disk has no
boot sector → BIOS falls through to ISO; after install Talos boots disk. Install
disk `/dev/sda` (SATA). No `hv_*` kernel modules (those were Hyper-V only).

**Host networking is a PowerShell prerequisite** (`scripts/host-network-setup.ps1`,
revert with `scripts/host-network-teardown.ps1`): allowlists `10.66.6.0/24` in
VirtualBox `%PROGRAMDATA%\VirtualBox\networks.conf` (**VBox 7 blocks
non-192.168.56.x host-only ranges by default**), creates a **dedicated** host-only
adapter at 10.66.6.1/24 (leaves the default 192.168.56.1 one untouched), disables
its DHCP, `New-NetNat` for internet, **and enables IP forwarding** on both the
host-only adapter and the upstream LAN NIC (`Set-NetIPInterface -Forwarding
Enabled`, resolved dynamically by IP/default-route). **Gotcha:** `New-NetNat`
alone only translates addresses — without forwarding on both NICs, nodes reach
10.66.6.1 but have NO internet. The adapter name is **hard-coded**
`VirtualBox Host-Only Ethernet Adapter #2` in both the script (`$Adapter`) and
Terraform (`var.hostonly_adapter`) — keep them in sync.

**CRITICAL unverified dependency:** the Talos provider runs in WSL2 and must reach
10.66.6.0/24. Confirm `ping 10.66.6.1` from WSL2 after the host script.

**Interface naming:** ISO kernel args include `net.ifnames=0` (isos.tf) so the NIC
is always `eth0`, keeping the `ip=` arg and machine-config interface (both
`var.node_interface`, default `eth0`) consistent regardless of PCI slot. Verify
once with `talosctl get links`.

**VMs use UEFI** (`--firmware efi64`, `firmware` trigger in vms.tf); empty disk has
no EFI boot entry so firmware falls through to the ISO. If a node drops to the EFI
Shell on first boot, `controlvm <node> reset` or pick the DVD in Boot Manager.

**Gotchas:** VBoxManage paths are Windows-form (e.g. `C:\talos\cp-01.iso`) even
when invoked from WSL2.

Tooling (talosctl v1.13.4, kubectl v1.36.1, terraform v1.15.5) in `~/.local/bin`.
WSL2 mirrored mode on; host LAN 192.168.1.0/24. See [[cluster-topology]], [[infrastructure]].
