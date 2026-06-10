# ---------------------------------------------------------------------------
# WinRM connection to the Hyper-V (Windows) host
# ---------------------------------------------------------------------------
variable "winrm_host" {
  description = "Hostname or IP of the Windows Hyper-V host reachable from WSL2 (its LAN IP, e.g. 192.168.1.x)."
  type        = string
}

variable "winrm_user" {
  description = "Windows username for WinRM (local admin or domain account)."
  type        = string
}

variable "winrm_password" {
  description = "Password for the WinRM user."
  type        = string
  sensitive   = true
}

variable "winrm_port" {
  description = "WinRM port (5985 for HTTP, 5986 for HTTPS)."
  type        = number
  default     = 5985
}

variable "winrm_https" {
  description = "Use HTTPS for WinRM."
  type        = bool
  default     = false
}

variable "winrm_insecure" {
  description = "Skip TLS verification (only relevant when winrm_https = true)."
  type        = bool
  default     = true
}

variable "winrm_use_ntlm" {
  description = "Use NTLM authentication for WinRM."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Host paths
# ISOs are staged from WSL2 (iso_dir_wsl) which maps to the Windows path
# (iso_dir_host) that Hyper-V reads from. Default C:\talos == /mnt/c/talos.
# ---------------------------------------------------------------------------
variable "iso_dir_host" {
  description = "Windows path where per-node Talos ISOs live (read by Hyper-V)."
  type        = string
  default     = "C:\\talos"
}

variable "iso_dir_wsl" {
  description = "WSL2 path mapping to iso_dir_host (where Terraform downloads the ISOs)."
  type        = string
  default     = "/mnt/c/talos"
}

variable "vhd_dir" {
  description = "Directory on the Windows host where node OS disks (.vhdx) are created."
  type        = string
  default     = "C:\\Hyper-V\\jeen"
}

# ---------------------------------------------------------------------------
# Isolated cluster network (Internal switch + host NAT)
# The switch, the host gateway vNIC (10.66.6.1), and NAT are created by the
# one-time host script scripts/host-network-setup.ps1 (the Hyper-V provider
# cannot manage vNIC IPs or NAT). Terraform references the switch by name.
# ---------------------------------------------------------------------------
variable "switch_name" {
  description = "Name of the Internal Hyper-V virtual switch the nodes attach to."
  type        = string
  default     = "jeen-internal"
}

variable "subnet_cidr_suffix" {
  description = "CIDR prefix length for the node subnet."
  type        = number
  default     = 24
}

variable "gateway" {
  description = "Default gateway for the nodes (the host vNIC on the Internal switch)."
  type        = string
  default     = "10.66.6.1"
}

variable "nameservers" {
  description = "DNS servers for the nodes (reached through host NAT; the host is not a resolver)."
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "control_plane_vip" {
  description = "Shared virtual IP for the HA control-plane endpoint."
  type        = string
  default     = "10.66.6.10"
}

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------
variable "cluster_name" {
  description = "Talos/Kubernetes cluster name."
  type        = string
  default     = "jeen"
}

variable "talos_version" {
  description = "Talos Linux version (used for the ISO and installer image)."
  type        = string
  default     = "v1.13.4"
}

variable "install_disk" {
  description = "Disk device Talos installs to (Gen2 SCSI disk appears as /dev/sda)."
  type        = string
  default     = "/dev/sda"
}

variable "node_interface" {
  description = "Guest network interface name (verify with `talosctl get links`)."
  type        = string
  default     = "eth0"
}
