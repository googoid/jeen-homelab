---
name: storage-rook-ceph
description: Rook-Ceph storage — worker disks, Talos prep, Flux layout, RBD+CephFS StorageClasses
metadata:
  type: project
---

**Persistent storage = Rook-Ceph (Milestone 6), deployed via Flux.** Provides
block (RBD) + shared filesystem (CephFS). Rook **v1.20.0** (charts `rook-ceph`
operator + `rook-ceph-cluster` from `https://charts.rook.io/release`).

**Disks (Terraform):** workers only get two 60GB raw disks each → 6 OSDs, 360GB
raw, ~120GB usable @ replica 3 (failureDomain host). `terraform/locals.tf` node
map has `ceph_disks` (workers `[60,60]`, CPs `[]`). `terraform/vms.tf` triggers add
`portcount` (4 if ceph disks else 2) + `ceph_disks` ("port|winpath|sizeMB" list,
ceph disks at SATA ports 2/3 → `/dev/sdb`,`/dev/sdc`); a bash loop createhd+attach
(idempotent). VDIs under `var.vm_dir` so `unregistervm --delete` cleans them.
Disks added via VM triggers → **`apply` recreates VMs** (cluster lost, Flux
re-bootstraps). OS disk (`/dev/sda` port 0) untouched.

**Talos prep (`terraform/talos.tf`, worker config only):** `machine.kernel.modules`
rbd+nbd (rbd is built-in on Talos amd64 but loaded defensively) + sysctls
(inotify instances/watches, aio-max-nr). `/var/lib/rook` needs NO extraMount
(Talos /var is writable+persistent). **PSA:** the `rook-ceph` namespace is labelled
`pod-security.kubernetes.io/enforce|audit|warn: privileged` (not cluster-wide).

**Flux layout:** operator in `infrastructure/controllers/rook-ceph/` (namespace +
HelmRepository `rook-release` + HelmRelease `rook-ceph-operator`, `crds:
Create/CreateReplace`) — added to controllers kustomization. Cluster in
`infrastructure/configs/rook-ceph-cluster/` (HelmRepository + HelmRelease
`rook-ceph-cluster`, `dependsOn: rook-ceph-operator`). Ordering: infra-configs
dependsOn infra-controllers (wait:true) ⇒ CRDs/operator Ready before the
CephCluster CR. See [[gitops-flux]].

**Cluster spec:** 3 mon / 2 mgr, dashboard on (ssl off), toolbox on, all daemons
kept off control planes via nodeAffinity (`node-role.kubernetes.io/control-plane
DoesNotExist`). Storage `useAllNodes/useAllDevices:false`, explicit wk-0{1,2,3}
devices sdb+sdc. StorageClasses: **`ceph-block`** (RBD, **default**, ext4, RWO) +
**`ceph-filesystem`** (CephFS, RWX). No object store.

**Verify:** `kubectl -n rook-ceph get pods` (3 mon, 6 osd, 2 mgr, 2 mds, toolbox);
`kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status` HEALTH_OK;
`kubectl get sc`. **Gotchas:** OSDs need clean disks (fresh VDIs OK; reused →
`sgdisk --zap-all`); OSDs take minutes (transient HEALTH_WARN); no data survives a
VM-replacing apply. See [[cluster-topology]], [[terraform-stack]].
