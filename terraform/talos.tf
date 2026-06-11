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
        # VirtualBox exposes an AHCI (SATA) disk and an Intel 82540EM (e1000) NIC,
        # both already supported by the Talos metal image — no extra kernel
        # modules needed (unlike the Hyper-V hv_* paravirtual drivers).
        install = {
          disk  = var.install_disk
          image = local.installer_image
        }
        network = {
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

  config_patches = [
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      hostname   = "${each.key}"
      auto       = "off"
    }),
    # This makes sure the network interface is eth0
    # TODO: this will probably fail if the node has more than one NIC
    yamlencode({
      apiVersion = "v1alpha1"
      kind = "LinkAliasConfig"
      name = "eth0"
      selector = {
        match = true
      }
    }),
    local.node_patches[each.key]
  ]

  depends_on = [null_resource.vm]
}

# # Absorb the post-install reboot: poll each node's Talos API (apid, port 50000)
# # until it answers again before moving on to bootstrap.
# resource "null_resource" "wait_for_port" {
#   for_each = local.nodes

#   depends_on = [talos_machine_configuration_apply.node]

#   triggers = {
#     node = each.value.ip
#   }

#   provisioner "local-exec" {
#     command = <<-EOT
#       sleep 60
#       printf "Waiting for Talos API on ${each.value.ip}:50000"
#       until nc -z -w5 ${each.value.ip} 50000; do
#         printf '.'
#         sleep 5
#       done
#       echo " up!"
#     EOT
#   }
# }

# Bootstrap etcd on the first control plane (connect directly to its IP; the VIP
# is not live until the cluster is up).
resource "talos_machine_bootstrap" "this" {
  # depends_on = [null_resource.wait_for_port]
  depends_on = [talos_machine_configuration_apply.node]

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
