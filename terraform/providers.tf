# VirtualBox VMs are created by driving VBoxManage through null_resource +
# local-exec (see vms.tf), so there is no VM provider to configure here — this
# removes the old WinRM dependency entirely.

# Talos provider needs no static configuration; everything is wired per-resource.
provider "talos" {}
