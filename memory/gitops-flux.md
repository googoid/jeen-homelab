---
name: gitops-flux
description: Flux CD GitOps setup — Terraform bootstrap, monorepo layout, Cilium adoption, SOPS/age
metadata:
  type: project
---

**GitOps = Flux CD (Milestone 5).** Cluster state declared in Git, reconciled by
Flux. Git host **GitHub**, **monorepo** (Flux dirs alongside `terraform/`),
installed via the Terraform **`fluxcd/flux` provider** (everything-via-Terraform).

**Terraform wiring** (`terraform/flux.tf` + `sops.tf`, providers/versions/variables):
- `tls_private_key.flux` (ed25519) → `github_repository_deploy_key.flux`
  (**read_only=false** — bootstrap commits manifests) → `flux_bootstrap_git.this`
  (`path=clusters/jeen`, `version=var.flux_version` v2.8.5, `embedded_manifests=true`).
- `kubernetes_namespace.flux_system` + `kubernetes_secret.sops_age` (key
  `age.agekey` = `file(pathexpand(var.sops_age_key_file))`) created **before**
  bootstrap so Flux can decrypt on first reconcile.
- Providers `flux`/`kubernetes` reuse the talos kubeconfig auth (same as helm);
  `github` uses `var.github_owner`/`var.github_token` (PAT, repo scope). New vars:
  github_owner/token/repository, flux_branch/path/version, sops_age_key_file.

**Repo layout (Flux recommended):** `clusters/jeen/` (flux-system owned by
bootstrap + `infrastructure.yaml`+`apps.yaml` Kustomizations) → `infrastructure/
controllers/` (cilium HelmRepository+HelmRelease) + `infrastructure/configs/` →
`apps/jeen/`. Dependency chain flux-system → infra-controllers → infra-configs →
apps; every Kustomization has `decryption: {provider: sops, secretRef: {name:
sops-age}}`. **Contents:** controllers = cilium + rook-ceph (operator); configs =
rook-ceph-cluster (CephCluster + StorageClasses); apps = empty. See
[[storage-rook-ceph]].

**Cilium chicken-and-egg → adoption (key):** Flux pods need a CNI to schedule, so
Terraform still installs Cilium once via `helm_release.cilium`. Flux's Cilium
`HelmRelease` (releaseName/ns/version/values **byte-identical** to cilium.tf)
makes helm-controller **adopt** the existing release — no reinstall, no pod churn.
**Handoff:** after `flux get hr -n kube-system cilium` is Ready, delete the
`helm_release` block from cilium.tf and `terraform state rm helm_release.cilium`
(**never `terraform destroy`** — that deletes the live CNI). Bump Cilium only via
Git afterward; parity is mandatory at adoption or step triggers a real upgrade.

**SOPS/age:** `age-keygen -o ~/.config/sops/age/jeen.agekey`; public key goes in
root `.sops.yaml` (encrypted_regex `^(data|stringData)$`), private key → host file
+ in-cluster sops-age Secret, **never committed** (`.gitignore`: `*.agekey`). It
does land in local gitignored TF state (acceptable homelab tradeoff).

**Prereqs before apply:** create GitHub repo + `git remote add origin`, age-keygen
+ fill `.sops.yaml`, set github_owner/token in tfvars, commit+push Flux manifests.

**Gotchas:** cold-run provider-unknown (flux/kubernetes/github read same-apply
kubeconfig) → `terraform apply -target=helm_release.cilium` then full apply.
Deploy key must be writable. `flux_bootstrap_git` still supported in provider
1.8.x (Flux now also offers a flux-operator module). See [[terraform-stack]],
[[deployment-approach]], [[cluster-topology]].
