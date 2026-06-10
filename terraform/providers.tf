# Hyper-V provider talks to the Windows host over WinRM.
# For a trusted LAN we default to HTTP/5985 + NTLM; flip to HTTPS/5986 with a
# cert for a hardened setup. Credentials come from variables (terraform.tfvars).
provider "hyperv" {
  user     = var.winrm_user
  password = var.winrm_password
  host     = var.winrm_host
  port     = var.winrm_port
  https    = var.winrm_https
  insecure = var.winrm_insecure
  use_ntlm = var.winrm_use_ntlm

  # Where the provider drops temp PowerShell scripts on the host.
  script_path = "C:/Temp/terraform_%RAND%.cmd"
  timeout     = "30s"
}

# Talos provider needs no static configuration; everything is wired per-resource.
provider "talos" {}
