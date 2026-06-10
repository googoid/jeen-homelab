# Per-node Image Factory schematic: a plain metal image plus the node's static
# IP kernel arg. This is what lets a node come up reachable at its fixed IP on a
# DHCP-less Internal switch.
resource "talos_image_factory_schematic" "node" {
  for_each = local.nodes

  schematic = yamlencode({
    customization = {
      extraKernelArgs = [local.node_kernel_ip[each.key]]
    }
  })
}

data "talos_image_factory_urls" "node" {
  for_each = local.nodes

  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.node[each.key].id
  platform      = "metal"
  architecture  = "amd64"
}

# Download each per-node ISO into the WSL2 path that maps to the Windows host
# directory Hyper-V reads from. Re-downloads only when the URL changes.
resource "null_resource" "iso" {
  for_each = local.nodes

  triggers = {
    url  = data.talos_image_factory_urls.node[each.key].urls.iso
    dest = "${var.iso_dir_wsl}/${each.key}.iso"
  }

  provisioner "local-exec" {
    command = "mkdir -p '${var.iso_dir_wsl}' && curl -fL --retry 3 -o '${self.triggers.dest}' '${self.triggers.url}'"
  }
}
