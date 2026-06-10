# Empty OS disk per node (Talos installs onto this).
resource "hyperv_vhd" "node" {
  for_each = local.nodes

  path     = "${var.vhd_dir}\\${each.key}.vhdx"
  vhd_type = "Dynamic"
  size     = each.value.disk_gb * 1024 * 1024 * 1024
}

# Gen2 VM per node. Secure Boot is OFF (Hyper-V cannot trust Talos's cert chain).
# Boot flow: empty disk is non-bootable -> firmware boots the per-node Talos ISO,
# whose ip= kernel arg brings the node up at its static IP -> Talos provider
# applies config and installs to /dev/sda.
resource "hyperv_machine_instance" "node" {
  for_each = local.nodes

  name            = each.key
  generation      = 2
  processor_count = each.value.vcpu

  static_memory        = true
  memory_startup_bytes = each.value.mem_gb * 1024 * 1024 * 1024

  state = "Running"

  vm_firmware {
    enable_secure_boot = "Off"
  }

  # OS disk on SCSI 0:0
  hard_disk_drives {
    controller_type     = "Scsi"
    controller_number   = 0
    controller_location = 0
    path                = hyperv_vhd.node[each.key].path
  }

  # Per-node Talos ISO on SCSI 0:1 (carries this node's static-IP kernel arg).
  dvd_drives {
    controller_number   = 0
    controller_location = 1
    path                = "${var.iso_dir_host}\\${each.key}.iso"
  }

  network_adaptors {
    name                 = "primary"
    switch_name          = var.switch_name
    dynamic_mac_address  = false
    static_mac_address   = each.value.mac
    mac_address_spoofing = "On" # required so the control-plane VIP can float
  }

  # The ISO must be staged on the host before the VM boots.
  depends_on = [null_resource.iso]
}
