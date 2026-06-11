# SOPS/age decryption key for Flux. The age PRIVATE key (generated once on the
# host with `age-keygen -o <sops_age_key_file>`) is applied as the sops-age
# Secret in flux-system. Flux's Kustomizations reference it via
# `decryption: { provider: sops, secretRef: { name: sops-age } }`.
#
# The private key never enters Git; it does land in (local, gitignored) TF
# state — acceptable for a homelab. The matching PUBLIC key goes in .sops.yaml.
#
# We create the namespace here (rather than relying on flux_bootstrap_git) so the
# Secret can exist before Flux's first reconcile; bootstrap tolerates the
# pre-existing namespace.
resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }
}

resource "kubernetes_secret" "sops_age" {
  metadata {
    name      = "sops-age"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
  }
  data = {
    "age.agekey" = file(pathexpand(var.sops_age_key_file))
  }
}
