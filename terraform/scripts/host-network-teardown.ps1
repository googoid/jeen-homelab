# Run as Administrator on the Windows host. Idempotent. Reverses host-network-setup.ps1.
# Removes the dedicated host-only adapter named below, its DHCP server, the NAT, and
# the networks.conf allowlist. Stop/destroy the jeen VMs first (e.g. `terraform
# destroy`); an adapter in use by a running VM cannot be removed.
$ErrorActionPreference = 'Stop'

$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$Adapter    = 'VirtualBox Host-Only Ethernet Adapter #2'
$NatName    = 'jeen-nat'

if (-not (Test-Path $VBoxManage)) {
  throw "VBoxManage not found at '$VBoxManage'. Install VirtualBox or edit this script."
}

# 1. Remove the NAT.
if (Get-NetNat -Name $NatName -ErrorAction SilentlyContinue) {
  Remove-NetNat -Name $NatName -Confirm:$false
  Write-Host "Removed NAT '$NatName'"
} else { Write-Host "NAT '$NatName' not present" }

# 1b. Disable IP forwarding on the upstream (WAN) NIC that setup enabled — but
#     only if no other NAT remains, so we don't break another NAT setup. The
#     host-only adapter's own forwarding goes away when it is removed in step 2.
if (-not (Get-NetNat -ErrorAction SilentlyContinue)) {
  $WanIdx = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
             Sort-Object RouteMetric | Select-Object -First 1).ifIndex
  if ($WanIdx) {
    Set-NetIPInterface -ifIndex $WanIdx -Forwarding Disabled
    Write-Host "Disabled IP forwarding on WAN (ifIndex $WanIdx)"
  }
} else { Write-Host "Other NAT present; left WAN forwarding enabled" }

# 2. Remove the dedicated adapter (and its DHCP server).
$ifs = & $VBoxManage list hostonlyifs
if ($ifs -match [regex]::Escape($Adapter)) {
  & $VBoxManage dhcpserver remove --ifname "$Adapter" 2>$null
  & $VBoxManage hostonlyif remove "$Adapter"
  Write-Host "Removed host-only adapter '$Adapter'"
} else { Write-Host "Host-only adapter '$Adapter' not present" }

# 3. Remove the host-only range allowlist.
$NetCfg = Join-Path $env:ProgramData 'VirtualBox\networks.conf'
if (Test-Path $NetCfg) {
  Remove-Item $NetCfg -Force
  Write-Host "Removed $NetCfg"
} else { Write-Host "networks.conf not present" }

Write-Host "`nDone. Teardown complete."
