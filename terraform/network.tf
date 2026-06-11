# The isolated cluster network is set up by the one-time host script
# scripts/host-network-setup.ps1, because VBoxManage configures the host-only
# adapter IP but not internet NAT, and VirtualBox 7 blocks non-default host-only
# ranges until they are allowlisted.
#
# That script:
#   - allowlists 10.66.6.0/24 for host-only use (%PROGRAMDATA%\VirtualBox\networks.conf)
#   - a dedicated host-only adapter at 10.66.6.1/24, DHCP disabled (leaves other
#     host-only adapters, e.g. the default 192.168.56.1, untouched)
#   - NAT               : New-NetNat 10.66.6.0/24 -> internet via the host's LAN NIC
#
# Terraform attaches each VM to the adapter by name in vms.tf (--hostonlyadapter1);
# var.hostonly_adapter (default "VirtualBox Host-Only Ethernet Adapter #2") must
# match $Adapter in the script.
