resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version
}

data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version
}

locals {
  # Per-node config patch: hostname, static IP/gateway/DNS (matching the boot
  # kernel arg so the address persists after install), install target, and the
  # shared VIP on control-plane nodes.
  node_patches = {
    for k, v in local.nodes : k => yamlencode({
      machine = {
        install = {
          disk  = var.install_disk
          image = local.installer_image
        }
        network = {
          hostname    = k
          nameservers = var.nameservers
          interfaces = [
            merge(
              {
                interface = var.node_interface
                addresses = ["${v.ip}/${var.subnet_cidr_suffix}"]
                routes = [{
                  network = "0.0.0.0/0"
                  gateway = var.gateway
                }]
              },
              v.role == "controlplane" ? { vip = { ip = var.control_plane_vip } } : {}
            )
          ]
        }
      }
    })
  }
}

# Apply config at each node's static IP (the node is reachable there from first
# boot thanks to the ip= kernel arg). This installs Talos and reboots; the IP is
# unchanged before and after, so node == endpoint throughout.
resource "talos_machine_configuration_apply" "node" {
  for_each = local.nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = each.value.role == "controlplane" ? data.talos_machine_configuration.controlplane.machine_configuration : data.talos_machine_configuration.worker.machine_configuration

  node     = each.value.ip
  endpoint = each.value.ip

  config_patches = [local.node_patches[each.key]]

  depends_on = [hyperv_machine_instance.node]
}

# Absorb the post-install reboot before bootstrapping.
resource "time_sleep" "wait_for_reboot" {
  depends_on      = [talos_machine_configuration_apply.node]
  create_duration = "150s"
}

# Bootstrap etcd on the first control plane (connect directly to its IP; the VIP
# is not live until the cluster is up).
resource "talos_machine_bootstrap" "this" {
  depends_on = [time_sleep.wait_for_reboot]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.nodes[local.first_cp_name].ip
  endpoint             = local.nodes[local.first_cp_name].ip
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.nodes[local.first_cp_name].ip
  endpoint             = var.control_plane_vip
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for k, v in local.control_plane_nodes : v.ip]
  nodes                = [for k, v in local.nodes : v.ip]
}
