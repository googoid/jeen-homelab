---
name: terraform-stack
description: Terraform layout, provider versions, and deploy gotchas for the cluster
metadata:
  type: project
---

Terraform in `terraform/`. Providers (pinned in `.terraform.lock.hcl`):
- `taliesins/hyperv` **v1.2.1** — VMs/vhd over WinRM.
- `siderolabs/talos` **v0.11.0** — schematics, machine config, apply, bootstrap, kubeconfig.
- `hashicorp/null` (ISO download), `hashicorp/time` (reboot delay).

Files: versions/providers/variables/locals/network/isos/vms/talos/outputs.tf +
`scripts/host-network-setup.ps1`, `terraform.tfvars.example`, `.gitignore`, `README.md`.

**Isolated-network bootstrap (key design):** Internal switch has NO DHCP, so each
node gets its static IP at first boot via a **per-node Image Factory ISO** with an
`ip=` kernel arg (`isos.tf`: `talos_image_factory_schematic` +
`talos_image_factory_urls` + `null_resource` curl to `/mnt/c/talos/<node>.iso`).
`ip=` syntax: `ip=<client>::<gw>:<netmask>:<host>:<dev>:none`. Node IP == endpoint
the whole time (no read-back, idempotent). Image Factory urls field is `urls.iso`.

**Host networking is a PowerShell prerequisite** (`scripts/host-network-setup.ps1`),
NOT Terraform: the hyperv provider can't set a vNIC IP or NAT. Script makes the
Internal switch + host vNIC 10.66.6.1/24 + `New-NetNat` 10.66.6.0/24.

**CRITICAL unverified dependency:** the Talos provider runs in WSL2 and must reach
10.66.6.0/24. Confirm `ping 10.66.6.1` from WSL2 after the host script; if mirrored
mode doesn't expose the Internal switch, the whole apply can't configure nodes.

**hyperv v1.2.1 schema gotchas:** set only ONE of `static_memory`/`dynamic_memory`;
`wait_for_ips_*` are numbers (seconds); no boot-order arg (empty disk falls through
to ISO; fallback `Set-VMFirmware -FirstBootDevice`); Gen2 disk+DVD are SCSI; install
disk `/dev/sda`; VIP needs `mac_address_spoofing = "On"`.

Tooling (talosctl v1.13.4, kubectl v1.36.1, terraform v1.15.5) in `~/.local/bin`.
WSL2 mirrored mode on; host LAN 192.168.1.0/24. See [[cluster-topology]], [[infrastructure]].
