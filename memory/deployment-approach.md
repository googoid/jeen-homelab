---
name: deployment-approach
description: IaC tooling decision — everything deployed via Terraform
metadata:
  type: feedback
---

The user wants **everything deployed using Terraform** (not manual talosctl/PowerShell steps).

**Why:** Reproducible, declarative cluster lifecycle.

**How to apply:** VM layer = drive **`VBoxManage`** via `null_resource` +
`local-exec` (VirtualBox; no VM provider, no WinRM — migrated off `taliesins/hyperv`
in Milestone 3). Cluster layer = the official `siderolabs/talos` provider
(`talos_machine_secrets`, `talos_machine_configuration`,
`talos_machine_configuration_apply`, `talos_machine_bootstrap`,
`talos_cluster_kubeconfig`) to generate configs, apply them, bootstrap etcd, and
fetch kubeconfig. Prefer Terraform resources over imperative commands. See
[[infrastructure]], [[terraform-stack]].
