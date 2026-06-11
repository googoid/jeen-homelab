output "kubeconfig" {
  description = "Kubeconfig for the cluster. Save with: terraform output -raw kubeconfig > ~/.kube/jeen.yaml"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "Talosconfig. Save with: terraform output -raw talosconfig > ~/.talos/config"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "control_plane_endpoint" {
  description = "Kubernetes API endpoint (control-plane VIP)."
  value       = local.cluster_endpoint
}

output "node_ips" {
  description = "Static IP assigned to each node."
  value       = { for k, v in local.nodes : k => v.ip }
}

output "iso_urls" {
  description = "Per-node Image Factory ISO URLs (staged to the host by Terraform)."
  value       = { for k, v in data.talos_image_factory_urls.node : k => v.urls.iso }
}

output "flux_deploy_public_key" {
  description = "Public deploy key registered on the GitHub repo for Flux (informational)."
  value       = tls_private_key.flux.public_key_openssh
}
