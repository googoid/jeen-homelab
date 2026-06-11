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
