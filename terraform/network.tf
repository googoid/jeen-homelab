# The isolated cluster network is created by the one-time host script
# scripts/host-network-setup.ps1, because the taliesins/hyperv provider cannot
# manage a vNIC IP address or a NAT object (it only creates the bare switch).
#
# That script creates:
#   - Internal vSwitch  : var.switch_name (default "jeen-internal")
#   - Host gateway vNIC : 10.66.6.1/24 on "vEthernet (jeen-internal)"
#   - NAT               : 10.66.6.0/24 -> internet via the host's LAN NIC
#
# Terraform references the switch by name in vms.tf (network_adaptors.switch_name).
