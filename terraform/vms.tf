# One VirtualBox VM per node, created by driving VBoxManage on the Windows host.
#
# Boot flow: an empty SATA disk has no EFI boot entry, so the UEFI firmware falls
# through to the attached per-node Talos ISO (--boot1 disk --boot2 dvd). The ISO's
# ip= kernel arg brings the node up at its static IP; the Talos provider then
# applies config and installs to /dev/sda, which writes the disk's EFI boot entry
# so it boots first afterwards.
#
# The create steps are guarded so a re-run after a partial apply does not error
# on an already-existing VM/disk/controller. Destroy powers off and deletes.
resource "null_resource" "vm" {
  for_each = local.nodes

  triggers = {
    vbm      = var.vboxmanage
    name     = each.key
    cpus     = each.value.vcpu
    memory   = each.value.mem_gb * 1024
    disk_mb  = each.value.disk_gb * 1024
    vdi      = "${var.vm_dir}\\${each.key}.vdi"
    iso      = "${var.iso_dir_host}\\${each.key}.iso"
    adapter  = var.hostonly_adapter
    firmware = "efi64"
  }

  # The per-node ISO must be staged on the host before the VM boots.
  depends_on = [null_resource.iso]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VBM="${self.triggers.vbm}"

      "$VBM" showvminfo "${self.triggers.name}" >/dev/null 2>&1 \
        || "$VBM" createvm --name "${self.triggers.name}" --ostype Linux_64 --register

      "$VBM" modifyvm "${self.triggers.name}" \
        --cpus ${self.triggers.cpus} --memory ${self.triggers.memory} \
        --firmware ${self.triggers.firmware} --rtcuseutc on \
        --nic1 hostonly --hostonlyadapter1 "${self.triggers.adapter}" --nictype1 82540EM \
        --boot1 disk --boot2 dvd --boot3 none --boot4 none

      [ -f "${self.triggers.vdi}" ] \
        || "$VBM" createhd --filename "${self.triggers.vdi}" --size ${self.triggers.disk_mb} --variant Standard

      "$VBM" storagectl "${self.triggers.name}" --name SATA --add sata --controller IntelAhci --portcount 2 --bootable on 2>/dev/null || true

      "$VBM" storageattach "${self.triggers.name}" --storagectl SATA --port 0 --device 0 --type hdd      --medium "${self.triggers.vdi}"
      "$VBM" storageattach "${self.triggers.name}" --storagectl SATA --port 1 --device 0 --type dvddrive --medium "${self.triggers.iso}"

      "$VBM" startvm "${self.triggers.name}" --type headless
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      VBM="${self.triggers.vbm}"
      "$VBM" controlvm "${self.triggers.name}" poweroff 2>/dev/null || true
      sleep 2
      "$VBM" unregistervm "${self.triggers.name}" --delete 2>/dev/null || true
    EOT
  }
}

resource "null_resource" "noboot" {
  depends_on = [talos_machine_bootstrap.this]

  for_each = local.nodes

  triggers = {
    vbm  = var.vboxmanage
    name = each.key
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      VBM="${self.triggers.vbm}"

      "$VBM" showvminfo "${self.triggers.name}" >/dev/null 2>&1 \
        && "$VBM" storageattach "${self.triggers.name}" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium emptydrive

    EOT
  }
}
