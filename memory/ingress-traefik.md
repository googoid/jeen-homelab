---
name: ingress-traefik
description: Traefik ingress controller + Cilium LB-IPAM/L2 announcements for the jeen cluster
metadata:
  type: project
---

**Ingress = Traefik (Milestone 7)**, chart 40.3.0 (Traefik v3.7.4), deployed via
Flux. Lives in `infrastructure/controllers/traefik/` (namespace + HelmRepository
`https://traefik.github.io/charts` + HelmRelease), wired into the controllers
kustomization.

**Exposure = Cilium LB-IPAM + L2 announcements** (no cloud LB on the isolated
10.66.6.0/24 host-only net). Service type=LoadBalancer; Cilium hands out a VIP and
ARP-announces it on `eth0`.
- Config in `infrastructure/configs/cilium-lb/`: `CiliumLoadBalancerIPPool`
  (**cilium.io/v2**) `jeen-pool` blocks **10.66.6.200-250**; `CiliumL2AnnouncementPolicy`
  (**cilium.io/v2alpha1**) `jeen-l2`, `loadBalancerIPs: true`, interfaces `^eth[0-9]+`.
  Node IPs are .10-.23, so .200+ is free.
- Traefik svc pinned to **10.66.6.200** via annotation `lbipam.cilium.io/ips`.

**Cilium change (keep in parity!):** L2 needs `l2announcements.enabled=true` and a
raised `k8sClientRateLimit` (20/40; default 5/10 too low). Added to **both**
`terraform/cilium.tf` and the Flux cilium HelmRelease because `helm_release.cilium`
is **not yet handed off** to Flux — values must match or the two fight. See the
adoption/handoff note in [[gitops-flux]].

**Dashboards (all on `web`, internal-only, no auth yet):**
- Traefik: chart's built-in IngressRoute, `Host(\`traefik.jeen.local\`)`.
- Hubble + Ceph: IngressRoutes in `infrastructure/configs/dashboard-routes/`
  (`traefik.io/v1alpha1`). Each lives in the **target service's namespace**
  (Traefik v3 requires same-ns service refs by default): `hubble.jeen.local` →
  `hubble-ui:80` in kube-system; `ceph.jeen.local` → `rook-ceph-mgr-dashboard:7000`
  in rook-ceph (HTTP because ceph dashboard `ssl:false`).
All resolve to the Traefik VIP — point each host at `10.66.6.200` in your hosts file.

**Verify:** `kubectl -n traefik get svc traefik` → EXTERNAL-IP 10.66.6.200; svc IP
ARP-reachable from the Windows host. CRD apiVersions are version-specific to Cilium
1.19 — recheck on Cilium bump. See [[cluster-topology]], [[terraform-stack]].
