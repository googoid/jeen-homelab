# ---------------------------------------------------------------------------
# VirtualBox control (VBoxManage on the Windows host, invoked from WSL2)
# Terraform drives VBoxManage.exe over the /mnt/c bridge — no WinRM involved.
# ---------------------------------------------------------------------------
variable "vboxmanage" {
  description = "Path to the VBoxManage binary as seen from where Terraform runs (WSL2 sees the Windows exe under /mnt/c)."
  type        = string
  default     = "/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe"
}

# ---------------------------------------------------------------------------
# Host paths (Windows-side, as VBoxManage expects them)
# ISOs are downloaded from WSL2 to iso_dir_wsl, which maps to the Windows path
# iso_dir_host that VBoxManage attaches. Default C:\talos == /mnt/c/talos.
# ---------------------------------------------------------------------------
variable "iso_dir_host" {
  description = "Windows path where per-node Talos ISOs live (attached by VBoxManage)."
  type        = string
  default     = "C:\\talos"
}

variable "iso_dir_wsl" {
  description = "WSL2 path mapping to iso_dir_host (where Terraform downloads the ISOs)."
  type        = string
  default     = "/mnt/c/talos"
}

variable "vm_dir" {
  description = "Windows directory where node OS disks (.vdi) are created by VBoxManage."
  type        = string
  default     = "C:\\VBox\\jeen"
}

# ---------------------------------------------------------------------------
# Isolated cluster network (VirtualBox host-only adapter + Windows NAT)
# The host-only adapter IP (10.66.6.1), its DHCP-off state, and the NAT are set
# by the one-time host script scripts/host-network-setup.ps1. VMs attach to the
# adapter by name (see vms.tf).
# ---------------------------------------------------------------------------
variable "hostonly_adapter" {
  description = "Name of the dedicated VirtualBox host-only adapter the nodes attach to (as shown by `VBoxManage list hostonlyifs`)."
  type        = string
  default     = "VirtualBox Host-Only Ethernet Adapter #2"
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
  description = "Disk device Talos installs to (the VirtualBox SATA/AHCI disk appears as /dev/sda)."
  type        = string
  default     = "/dev/sda"
}

variable "node_interface" {
  description = "Guest network interface name. Forced to eth0 by net.ifnames=0 in the ISO kernel args (isos.tf); verify once with `talosctl get links`."
  type        = string
  default     = "eth0"
}

# ---------------------------------------------------------------------------
# Cilium CNI (installed via the helm provider; see cilium.tf)
# Talos's default CNI + kube-proxy are disabled (talos.tf); Cilium replaces both
# with its eBPF datapath, reaching the API server through Talos KubePrism.
# ---------------------------------------------------------------------------
variable "cilium_version" {
  description = "Cilium Helm chart version (https://helm.cilium.io)."
  type        = string
  default     = "1.19.4"
}

variable "cilium_namespace" {
  description = "Namespace Cilium is installed into (kube-system is the Talos-recommended CNI namespace)."
  type        = string
  default     = "kube-system"
}

# ---------------------------------------------------------------------------
# Flux CD / GitOps (see flux.tf)
# Flux is bootstrapped into the cluster via the fluxcd/flux provider and synced
# from a GitHub repo. A deploy key is generated and registered on the repo, and
# the SOPS/age private key is applied as a Secret so Flux can decrypt secrets.
# ---------------------------------------------------------------------------
variable "github_owner" {
  description = "GitHub user/org that owns the GitOps repo."
  type        = string
}

variable "github_token" {
  description = "GitHub PAT (repo scope) used to register the Flux deploy key."
  type        = string
  sensitive   = true
}

variable "github_repository" {
  description = "Name of the GitHub repo Flux syncs from (this monorepo)."
  type        = string
  default     = "jeen"
}

variable "flux_branch" {
  description = "Git branch Flux reconciles from."
  type        = string
  default     = "main"
}

variable "flux_path" {
  description = "Path in the repo Flux bootstraps/reconciles (the cluster's flux-system lives here)."
  type        = string
  default     = "clusters/jeen"
}

variable "flux_version" {
  description = "Flux version to install (pins gotk-components)."
  type        = string
  default     = "v2.8.5"
}

variable "sops_age_key_file" {
  description = "Host path to the age PRIVATE key, applied as the sops-age Secret so Flux can decrypt. Never committed."
  type        = string
  default     = "~/.config/sops/age/jeen.agekey"
}
