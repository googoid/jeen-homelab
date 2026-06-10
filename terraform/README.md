# jeen — Talos HA cluster on Hyper-V (Terraform)

3 control planes + 3 workers as Hyper-V Gen2 VMs on an **isolated** `10.66.6.0/24`
network, deployed from WSL2. Talos **v1.13.4**.

| Node  | Role          | IP          | vCPU | RAM  | Disk   |
|-------|---------------|-------------|------|------|--------|
| VIP   | API endpoint  | 10.66.6.10  | —    | —    | —      |
| cp-01 | control plane | 10.66.6.11  | 2    | 4 GB | 40 GB  |
| cp-02 | control plane | 10.66.6.12  | 2    | 4 GB | 40 GB  |
| cp-03 | control plane | 10.66.6.13  | 2    | 4 GB | 40 GB  |
| wk-01 | worker        | 10.66.6.21  | 4    | 8 GB | 100 GB |
| wk-02 | worker        | 10.66.6.22  | 4    | 8 GB | 100 GB |
| wk-03 | worker        | 10.66.6.23  | 4    | 8 GB | 100 GB |

Gateway/DNS-route `10.66.6.1` (the Windows host vNIC, which NATs to the internet).
Node DNS resolvers: `1.1.1.1` / `8.8.8.8`.

## How it works

The host LAN is `192.168.1.0/24`; the cluster lives on an **isolated Internal
Hyper-V switch** (`10.66.6.0/24`) with the host as gateway + NAT. Because an
Internal switch has **no DHCP**, each node gets its static IP at first boot from a
**per-node Talos ISO** built by Image Factory with an `ip=` kernel argument.
Terraform builds those ISOs, stages them to the host via `/mnt/c`, creates the
VMs, applies Talos config, bootstraps etcd, and fetches the kubeconfig.

---

## Prerequisites (one-time)

### 1. WSL2 mirrored networking
Add to `C:\Users\<you>\.wslconfig`, then `wsl --shutdown`:
```ini
[wsl2]
networkingMode=mirrored
```
`hostname -I` should show the host's LAN IP (e.g. `192.168.1.x`).

### 2. WinRM on the host (run as Administrator)
```powershell
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Service\Auth\Negotiate $true
Set-Item WSMan:\localhost\Service\AllowUnencrypted $true   # HTTP; use HTTPS to harden
Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 2048
New-NetFirewallRule -DisplayName "WinRM HTTP" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow
```

### 3. Create the isolated cluster network (run as Administrator)
```powershell
# from this repo:
powershell -ExecutionPolicy Bypass -File terraform\scripts\host-network-setup.ps1
```
Then **verify from WSL2** that the isolated network is reachable:
```bash
ping -c1 10.66.6.1
```
If this fails, mirrored mode is not exposing the Internal switch to WSL2 and the
Talos provider won't be able to configure the nodes — stop and resolve this first.

---

## Deploy
```bash
cp terraform.tfvars.example terraform.tfvars   # edit WinRM host/user/password
terraform init
terraform apply
```
`apply` will: build + stage 6 per-node ISOs → create 6 VMs → apply Talos config
(static IPs + VIP, install to disk) → bootstrap etcd on cp-01 → fetch kubeconfig.

### Save credentials & verify
```bash
mkdir -p ~/.kube ~/.talos
terraform output -raw kubeconfig  > ~/.kube/jeen.yaml
terraform output -raw talosconfig > ~/.talos/config
export KUBECONFIG=~/.kube/jeen.yaml

talosctl -n 10.66.6.11 --talosconfig ~/.talos/config health
kubectl get nodes -o wide      # expect 3 control-plane + 3 worker, Ready
kubectl get pods -A
```

---

## Operational notes
- **WSL2 ↔ isolated net** is the critical dependency (step 3 verify). The Talos
  provider runs in WSL2 and must reach `10.66.6.x`.
- **Boot order:** Gen2 VMs boot the ISO because the OS disk starts empty. If a VM
  hangs at firmware, set the DVD first once:
  `Set-VMFirmware -VMName cp-01 -FirstBootDevice (Get-VMDvdDrive -VMName cp-01)`.
- **Interface name** assumed `eth0`; verify with `talosctl -n <ip> get links` and
  adjust `node_interface` if different (it also feeds the boot `ip=` arg).
- **Internet for nodes** depends on the host NAT (step 3). If image pulls fail,
  check `Get-NetNat` and that the host itself has internet.
