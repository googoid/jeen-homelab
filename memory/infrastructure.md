---
name: infrastructure
description: Core infrastructure facts — VirtualBox host, Talos, WSL2 control machine
metadata:
  type: project
---

The Talos Kubernetes cluster runs as VMs on **VirtualBox** (Windows host). It was
migrated off Hyper-V to drop the WinRM + `taliesins/hyperv` provider friction
(Milestone 3).

- Control/management is done from **WSL2** (Ubuntu 24.04 on the same Windows host). `talosctl`/`kubectl`/`terraform` installed in `~/.local/bin`.
- Terraform drives **`VBoxManage.exe`** on the Windows host from WSL2 over the `/mnt/c` bridge (default `/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe`). **No WinRM.**
- WSL2 uses **mirrored networking** (`networkingMode=mirrored`) and sits on the host LAN `192.168.1.0/24` at `192.168.1.21` (gateway `192.168.1.1`).
- The cluster is on an **isolated** `10.66.6.0/24` VirtualBox **host-only network** with the host as gateway+NAT (10.66.6.1). WSL2 must still reach `10.66.6.x` for the Talos provider to work — verify with `ping 10.66.6.1`.
- VirtualBox 7 coexists with WSL2 via the Windows Hypervisor Platform.

See [[deployment-approach]] for the IaC tooling decision.
