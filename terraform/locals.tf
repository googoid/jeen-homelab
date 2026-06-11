locals {
  # Canonical node inventory. MACs use the Hyper-V default OUI (00:15:5D); they
  # stay stable across reboots. IPs are assigned statically at first boot via a
  # per-node kernel arg (see isos.tf) and persisted by machine config (talos.tf).
  # ceph_disks = extra raw disks (GB) attached for Rook-Ceph OSDs. Workers get two
  # 60 GB disks (→ /dev/sdb, /dev/sdc); control planes get none (see vms.tf).
  nodes = {
    "cp-01" = { role = "controlplane", ip = "10.66.6.11", vcpu = 1, mem_gb = 2, disk_gb = 20, ceph_disks = [] }
    "cp-02" = { role = "controlplane", ip = "10.66.6.12", vcpu = 1, mem_gb = 2, disk_gb = 20, ceph_disks = [] }
    "cp-03" = { role = "controlplane", ip = "10.66.6.13", vcpu = 1, mem_gb = 2, disk_gb = 20, ceph_disks = [] }
    "wk-01" = { role = "worker", ip = "10.66.6.21", vcpu = 4, mem_gb = 8, disk_gb = 40, ceph_disks = [60, 60] }
    "wk-02" = { role = "worker", ip = "10.66.6.22", vcpu = 4, mem_gb = 8, disk_gb = 40, ceph_disks = [60, 60] }
    "wk-03" = { role = "worker", ip = "10.66.6.23", vcpu = 4, mem_gb = 8, disk_gb = 40, ceph_disks = [60, 60] }
  }

  control_plane_nodes = { for k, v in local.nodes : k => v if v.role == "controlplane" }
  worker_nodes        = { for k, v in local.nodes : k => v if v.role == "worker" }

  first_cp_name = "cp-01"

  cluster_endpoint = "https://${var.control_plane_vip}:6443"
  installer_image  = "ghcr.io/siderolabs/installer:${var.talos_version}"

  netmask = cidrnetmask("0.0.0.0/${var.subnet_cidr_suffix}")

  # Kernel arg giving each node its static IP in maintenance mode (no DHCP on the
  # Internal switch). Format: ip=<client>:<server>:<gw>:<netmask>:<host>:<dev>:<autoconf>
  node_kernel_ip = {
    for k, v in local.nodes :
    k => "ip=${v.ip}::${var.gateway}:${local.netmask}:${k}:${var.node_interface}:none"
  }
}
