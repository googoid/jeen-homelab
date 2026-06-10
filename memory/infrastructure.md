---
name: infrastructure
description: Core infrastructure facts — Hyper-V host, Talos, WSL2 control machine
metadata:
  type: project
---

The Talos Kubernetes cluster runs as VMs on **Hyper-V** (Windows host).

- Control/management is done from **WSL2** (Ubuntu 24.04 on the same Windows host). `talosctl`/`kubectl`/`terraform` installed in `~/.local/bin`.
- The Hyper-V provider (`taliesins/hyperv`) reaches the Windows host over **WinRM** (default HTTP/5985 + NTLM), which must be enabled on Windows.
- WSL2 uses **mirrored networking** (`networkingMode=mirrored`) and sits on the host LAN `192.168.1.0/24` at `192.168.1.21` (gateway `192.168.1.1`).
- The cluster is on an **isolated** `10.66.6.0/24` Internal switch with the host as gateway+NAT. WSL2 must still reach `10.66.6.x` for the Talos provider to work — verify with `ping 10.66.6.1`.

See [[deployment-approach]] for the IaC tooling decision.
