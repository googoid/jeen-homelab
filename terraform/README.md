# jeen — Talos HA cluster on VirtualBox (Terraform)

3 control planes + 3 workers as VirtualBox VMs on an **isolated** `10.66.6.0/24`
network, deployed from WSL2 by driving `VBoxManage` on the Windows host (no
WinRM). Talos **v1.13.4**.

| Node  | Role          | IP          | vCPU | RAM  | Disk   |
|-------|---------------|-------------|------|------|--------|
| VIP   | API endpoint  | 10.66.6.10  | —    | —    | —      |
| cp-01 | control plane | 10.66.6.11  | 2    | 4 GB | 40 GB  |
| cp-02 | control plane | 10.66.6.12  | 2    | 4 GB | 40 GB  |
| cp-03 | control plane | 10.66.6.13  | 2    | 4 GB | 40 GB  |
| wk-01 | worker        | 10.66.6.21  | 4    | 8 GB | 100 GB |
| wk-02 | worker        | 10.66.6.22  | 4    | 8 GB | 100 GB |
| wk-03 | worker        | 10.66.6.23  | 4    | 8 GB | 100 GB |

Gateway/NAT `10.66.6.1` (the Windows host's host-only adapter, which NATs to the
internet). Node DNS resolvers: `1.1.1.1` / `8.8.8.8`.

## How it works

The host LAN is `192.168.1.0/24`; the cluster lives on an **isolated VirtualBox
host-only network** (`10.66.6.0/24`) with the host as gateway + NAT. Because the
adapter's DHCP is disabled, each node gets its static IP at first boot from a
**per-node Talos ISO** built by Image Factory with an `ip=` kernel argument.
Terraform builds those ISOs, then drives `VBoxManage` to create each VM (empty
SATA disk + the node's ISO), boots it, applies Talos config, bootstraps etcd, and
fetches the kubeconfig. The empty disk has no boot sector, so the BIOS falls
through to the ISO; after Talos installs to `/dev/sda`, the disk boots first.

---

## Prerequisites (one-time)

### 1. Install VirtualBox 7 on the Windows host
VirtualBox 7 coexists with WSL2 via the Windows Hypervisor Platform. Confirm
`VBoxManage` is reachable from WSL2:
```bash
"/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" --version
```

### 2. WSL2 mirrored networking
Add to `C:\Users\<you>\.wslconfig`, then `wsl --shutdown`:
```ini
[wsl2]
networkingMode=mirrored
```
`hostname -I` should show the host's LAN IP (e.g. `192.168.1.x`).

### 3. Create the isolated cluster network (run as Administrator on Windows)
```powershell
powershell -ExecutionPolicy Bypass -File terraform\scripts\host-network-setup.ps1
```
This allowlists `10.66.6.0/24` for host-only use (VirtualBox 7 blocks it by
default), creates a **dedicated** host-only adapter (`VirtualBox Host-Only
Ethernet Adapter #2`) at `10.66.6.1/24` with DHCP off (leaving the default
`192.168.56.1` adapter untouched), and adds a NAT for internet. That adapter name
is hard-coded in both the script (`$Adapter`) and Terraform
(`var.hostonly_adapter`) — keep them in sync. Then **verify from WSL2**:
```bash
ping -c1 10.66.6.1
```
If this fails, mirrored mode is not exposing the host-only adapter to WSL2 and the
Talos provider won't be able to configure the nodes — resolve this first.

### 4. GitOps prerequisites (Flux + SOPS)
Flux syncs the cluster from this repo on GitHub, so before `apply`:
```bash
# a. Create a GitHub repo (e.g. jeen) and wire the remote:
git remote add origin git@github.com:<owner>/jeen.git

# b. Generate the SOPS age key on the host (private key — never committed):
age-keygen -o ~/.config/sops/age/jeen.agekey
age-keygen -y ~/.config/sops/age/jeen.agekey   # prints the public key
# put that public key into the repo-root .sops.yaml (replace the placeholder)

# c. Set github_owner + github_token (PAT, repo scope) in terraform.tfvars

# d. Commit + push the Flux manifests so bootstrap has something to reconcile:
git add clusters infrastructure apps .sops.yaml && git commit -m "flux manifests" && git push -u origin main
```

---

## Deploy
```bash
cp terraform.tfvars.example terraform.tfvars   # defaults are usually fine
terraform init
terraform apply
```
`apply` will: build + stage 6 per-node ISOs → create + boot 6 VirtualBox VMs →
apply Talos config (static IPs + VIP, install to disk, **CNI/kube-proxy disabled**)
→ bootstrap etcd on cp-01 → fetch kubeconfig → **install Cilium via Helm**. Nodes
stay `NotReady` until Cilium lands, then go `Ready`.

…then bootstrap **Flux** and have it adopt Cilium (see GitOps below).

> Cold-run note: the `helm`, `flux`, `kubernetes`, and `github` providers are all
> configured from the kubeconfig produced in the same apply. This normally works
> in one pass; if it errors that the kubeconfig is unknown, run
> `terraform apply -target=helm_release.cilium` once, then `terraform apply` again.

### Save credentials & verify
```bash
mkdir -p ~/.kube ~/.talos
terraform output -raw kubeconfig  > ~/.kube/jeen.yaml
terraform output -raw talosconfig > ~/.talos/config
export KUBECONFIG=~/.kube/jeen.yaml

talosctl -n 10.66.6.11 --talosconfig ~/.talos/config health
kubectl get nodes -o wide      # expect 3 control-plane + 3 worker, Ready
kubectl get pods -n kube-system   # cilium-*, cilium-operator, hubble-relay/ui Running
kubectl -n kube-system get ds     # no kube-proxy DaemonSet (Cilium replaced it)

# Confirm eBPF kube-proxy replacement, then open Hubble:
kubectl -n kube-system exec ds/cilium -- cilium status | grep -i kubeproxy
kubectl -n kube-system port-forward svc/hubble-ui 12000:80   # http://localhost:12000
```

---

## GitOps with Flux

Flux is bootstrapped by the `fluxcd/flux` provider (`flux.tf`) and syncs this
repo's `clusters/jeen` path. Layout (monorepo, outside `terraform/`):
`clusters/jeen/{infrastructure,apps}.yaml` Kustomizations → `infrastructure/
controllers` (Cilium) + `infrastructure/configs` → `apps/jeen`. Secrets are
SOPS-encrypted with age; the private key is applied as the `sops-age` Secret by
`sops.tf`.

**Cilium is handed off from Terraform to Flux.** Terraform installs Cilium once
(`cilium.tf`) so the CNI exists before Flux pods schedule; Flux's Cilium
`HelmRelease` (identical name/version/values) then *adopts* the release. After
adoption is healthy, complete the one-time handoff so only Flux manages it:
```bash
flux get helmrelease -n kube-system cilium     # Ready (adopted)
# then remove the helm_release "cilium" block from cilium.tf and:
terraform state rm helm_release.cilium         # NOT terraform destroy
```

Verify:
```bash
flux check
flux get kustomizations -A      # flux-system, infra-controllers, infra-configs, apps Ready
flux get sources git -A         # flux-system GitRepository Ready
# SOPS round-trip: encrypt a test secret, commit, then:
flux reconcile kustomization apps --with-source
```

---

## Operational notes
- **Tear down the host network** (after `terraform destroy` removes the VMs):
  `powershell -ExecutionPolicy Bypass -File terraform\scripts\host-network-teardown.ps1`
  as Administrator. It finds the adapter by IP and removes it, its DHCP server,
  the NAT, and the allowlist.
- **WSL2 ↔ isolated net** is the critical dependency (step 3 verify). The Talos
  provider runs in WSL2 and must reach `10.66.6.x`.
- **Interface name** is assumed `eth0`; VirtualBox + Talos metal may expose
  `enp0s3` instead. Verify with `talosctl -n <ip> get links` and adjust
  `node_interface` if different (it also feeds the boot `ip=` arg).
- **Boot order** is `disk` then `dvd`; if a VM hangs at the BIOS, confirm the ISO
  is attached on SATA port 1 (`VBoxManage showvminfo <node>`).
- **Internet for nodes** depends on the host NAT (step 3). `New-NetNat` only does
  address translation — Windows also needs **IP forwarding enabled** on both the
  host-only adapter and the upstream LAN NIC, or nodes reach `10.66.6.1` but have
  no internet. `host-network-setup.ps1` enables this (step 6). If image pulls
  fail, confirm `Get-NetNat` shows `jeen-nat` Active and
  `Get-NetIPInterface -AddressFamily IPv4 | ? Forwarding -eq Enabled` lists both
  interfaces.
