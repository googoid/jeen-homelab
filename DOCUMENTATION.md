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

---

## Milestone 5 — Flux GitOps (Terraform bootstrap, Cilium adopted into Flux, SOPS/age) (2026-06-11)

**Decisions**
- Adopt **Flux CD** for GitOps: cluster state declared in Git, continuously
  reconciled. Git host = **GitHub**; **monorepo** (Flux manifests alongside
  `terraform/`); install via the Terraform **`fluxcd/flux` provider**.
- **Move Cilium into Flux** (manage as a `HelmRelease`) and set up **SOPS + age**
  for encrypted secrets in Git from the start.

**Cilium chicken-and-egg → adoption**
- Flux pods need a CNI to schedule, so Terraform still installs Cilium once via
  `helm_release.cilium`. Flux then reconciles a Cilium `HelmRelease` with matching
  `releaseName`/namespace/version/values → helm-controller **adopts** the existing
  release (no reinstall). Handoff: delete the TF block + `terraform state rm
  helm_release.cilium` (never `destroy`). Flux becomes sole owner.

**Delivered**
- TF: `flux.tf` (ed25519 deploy key via `tls_private_key` + `github_repository_deploy_key`
  read/write, `flux_bootstrap_git` path `clusters/jeen`), `sops.tf` (flux-system ns
  + `sops-age` Secret from the host age key), `providers.tf`/`versions.tf` add
  `flux`/`github`/`kubernetes`/`tls` providers, `variables.tf` adds github_* +
  flux_* + `sops_age_key_file`.
- Repo: `clusters/jeen/{infrastructure,apps}.yaml` Kustomizations (SOPS decryption,
  dependsOn chain), `infrastructure/controllers/cilium/*` (HelmRepository +
  HelmRelease mirroring `cilium.tf`), `infrastructure/configs` + `apps/jeen`
  placeholders, root `.sops.yaml`.

**Status / next step**
- Prereqs before apply: create the GitHub repo + remote, `age-keygen` and put the
  public key in `.sops.yaml`, set `github_owner`/`github_token` in tfvars, commit +
  push the Flux manifests. Apply: Talos → Cilium (TF) → deploy key → sops-age
  Secret → `flux_bootstrap_git` → Flux reconciles + adopts Cilium. Then do the TF
  `state rm` handoff. Verify: `flux check`, `flux get kustomizations -A` Ready,
  nodes Ready, `flux get hr -n kube-system cilium` Ready (no Cilium pod restart),
  SOPS round-trip decrypts a test secret. Same cold-run `-target` caveat as helm.

---

## Milestone 6 — Rook-Ceph (RBD + CephFS) via Flux (2026-06-11)

**Decisions**
- Add persistent storage with **Rook-Ceph** (v1.20.0), deployed through the Flux
  pipeline. Provide **block (RBD)** + **shared filesystem (CephFS)** StorageClasses.
- **Disks on workers only:** each of the 3 workers gets **two 60 GB raw disks**
  (→ 6 OSDs, 360 GB raw, ~120 GB usable @ replica 3). Control planes get none.
- Apply via **full VM rebuild** (disks folded into the VM triggers).

**Delivered**
- TF: `locals.tf` `ceph_disks` per node (workers `[60,60]`, CPs `[]`); `vms.tf`
  `portcount`/`ceph_disks` triggers + idempotent createhd/attach loop (SATA ports
  2/3 → `/dev/sdb`,`/dev/sdc`); `talos.tf` worker `config_patches` (rbd/nbd kernel
  modules + inotify/aio sysctls).
- Flux: `infrastructure/controllers/rook-ceph/` (privileged-PSA namespace +
  HelmRepository + operator HelmRelease, CRDs Create/CreateReplace) wired into the
  controllers kustomization; `infrastructure/configs/rook-ceph-cluster/`
  (`rook-ceph-cluster` HelmRelease: 3 mon/2 mgr, dashboard, toolbox, OSDs on
  wk-0{1,2,3} sdb+sdc, daemons kept off CPs, **`ceph-block`** RBD SC [default] +
  **`ceph-filesystem`** CephFS SC) wired into the configs kustomization.

**Status / next step**
- Apply recreates the 6 VMs (workers with sdb/sdc raw) → fresh bootstrap → Cilium →
  Flux. Commit + push the Rook manifests so Flux reconciles them: controllers
  (operator) → configs (cluster). Verify: `kubectl -n rook-ceph get pods` (3 mon,
  6 osd, 2 mgr, 2 mds, toolbox), `ceph status` HEALTH_OK, `kubectl get sc` shows
  both classes, PVC bind test on each. OSDs take a few minutes (transient
  HEALTH_WARN); no Ceph data persists across a VM-replacing apply.

---

## Milestone 7 — Traefik ingress + Cilium LB-IPAM/L2 (2026-06-12)

**Decisions**
- Add **Traefik** (chart 40.3.0, Traefik v3.7.4) as the ingress controller via the
  Flux pipeline.
- Expose it with a **Service type=LoadBalancer** backed by **Cilium LB-IPAM + L2
  announcements** (no cloud LB on the isolated 10.66.6.0/24 host-only net). VIP
  pool **10.66.6.200-250**; Traefik pinned to **10.66.6.200**.
- Enable the **dashboard** via the chart's built-in IngressRoute at
  `http://traefik.jeen.local` (web entrypoint, internal only, no auth yet).

**Delivered**
- Cilium: `l2announcements.enabled=true` + `k8sClientRateLimit` 20/40 (default 5/10
  too low for L2) added to **both** `terraform/cilium.tf` and the Flux
  `infrastructure/controllers/cilium/helmrelease.yaml` (kept in parity — helm_release
  not yet handed off to Flux).
- Flux controllers: `infrastructure/controllers/traefik/` (namespace + HelmRepository
  + HelmRelease, LB service pinned via `lbipam.cilium.io/ips`, dashboard IngressRoute)
  wired into the controllers kustomization.
- Flux configs: `infrastructure/configs/cilium-lb/` (`CiliumLoadBalancerIPPool`
  cilium.io/v2 `jeen-pool` .200-.250 + `CiliumL2AnnouncementPolicy` cilium.io/v2alpha1
  `jeen-l2`, loadBalancerIPs only, iface `^eth[0-9]+`) wired into the configs
  kustomization.

**Status / next step**
- Cilium values changed → next `terraform apply` (or Flux reconcile) upgrades Cilium
  (pod churn expected). Commit + push so Flux reconciles: controllers (cilium upgrade
  + traefik) → configs (LB pool/policy). Verify: `kubectl -n traefik get svc traefik`
  shows EXTERNAL-IP 10.66.6.200; `cilium status`; ARP-reachable from the Windows host;
  add `10.66.6.200 traefik.jeen.local` to hosts and open the dashboard.
