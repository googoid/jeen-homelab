# Flux CD bootstrap. Installs Flux into the cluster and commits its sync
# manifests (clusters/jeen/flux-system/*) to the GitHub repo, which then drives
# GitOps reconciliation. Ordering: Cilium must be up (pods need a CNI) and the
# sops-age Secret must exist before Flux reconciles encrypted resources.

# ed25519 deploy key for Flux's read/write access to the repo over SSH.
resource "tls_private_key" "flux" {
  algorithm = "ED25519"
}

# Register the public key as a repo deploy key. read_only MUST be false —
# flux_bootstrap_git commits the flux-system manifests back to the repo.
resource "github_repository_deploy_key" "flux" {
  title      = "flux-${var.cluster_name}"
  repository = var.github_repository
  key        = tls_private_key.flux.public_key_openssh
  read_only  = false
}

resource "flux_bootstrap_git" "this" {
  path               = var.flux_path
  version            = var.flux_version
  embedded_manifests = true

  depends_on = [
    github_repository_deploy_key.flux,
    helm_release.cilium,        # CNI up → Flux controllers can schedule
    kubernetes_secret.sops_age, # decryption key present before first reconcile
  ]
}
