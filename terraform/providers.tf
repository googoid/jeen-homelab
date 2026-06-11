# VirtualBox VMs are created by driving VBoxManage through null_resource +
# local-exec (see vms.tf), so there is no VM provider to configure here — this
# removes the old WinRM dependency entirely.

# Talos provider needs no static configuration; everything is wired per-resource.
provider "talos" {}

# Helm provider, authenticated straight from the kubeconfig the talos provider
# produces — no kubeconfig file on disk. These attributes are only known after
# talos_cluster_kubeconfig.this is created, so on a cold run the provider is
# configured once that resource exists (see README for the rare -target note).
provider "helm" {
  kubernetes {
    host                   = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
    client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
  }
}

# kubernetes provider — same talos-derived auth as helm. Used to apply the
# sops-age Secret (and the flux-system namespace) before Flux first reconciles.
provider "kubernetes" {
  host                   = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
  client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
}

# GitHub provider — registers the Flux deploy key on the GitOps repo.
provider "github" {
  owner = var.github_owner
  token = var.github_token
}

# Flux provider — bootstraps Flux into the cluster (kubernetes{}) and points it
# at the GitHub repo over SSH (git{}). Same cold-run note as helm: the kube auth
# attributes are known only after talos_cluster_kubeconfig.this exists.
provider "flux" {
  kubernetes = {
    host                   = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
    client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
  }
  git = {
    url    = "ssh://git@github.com/${var.github_owner}/${var.github_repository}.git"
    branch = var.flux_branch
    ssh = {
      username    = "git"
      private_key = tls_private_key.flux.private_key_pem
    }
  }
}
