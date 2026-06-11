# Run as Administrator on the Windows host (where VirtualBox is installed). Idempotent.
# Creates a DEDICATED host-only network for the Talos nodes, leaving any other
# host-only adapters (e.g. the default 192.168.56.1) untouched:
#   - allowlists 10.66.6.0/24 for host-only use (VirtualBox 7 blocks it by default)
#   - the host-only adapter named below at 10.66.6.1/24 with its DHCP server disabled
#   - a Windows NAT so the nodes reach the internet through the host's LAN NIC
# $Adapter is hard-coded and must match var.hostonly_adapter in Terraform. The "#2"
# name is what VirtualBox assigns to the second host-only adapter (after the
# default "VirtualBox Host-Only Ethernet Adapter").
$ErrorActionPreference = 'Stop'

$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$Adapter    = 'VirtualBox Host-Only Ethernet Adapter #2'
$GwIp       = '10.66.6.1'
$Mask       = '255.255.255.0'
$Prefix     = 24
$Subnet     = '10.66.6.0/24'
$NatName    = 'jeen-nat'

if (-not (Test-Path $VBoxManage)) {
  throw "VBoxManage not found at '$VBoxManage'. Install VirtualBox or edit this script."
}

# 1. Allowlist the host-only range. VirtualBox 7 rejects host-only IPs outside
#    192.168.56.0/21 unless they are listed in networks.conf.
$NetCfgDir = Join-Path $env:ProgramData 'VirtualBox'
$NetCfg    = Join-Path $NetCfgDir 'networks.conf'
New-Item -ItemType Directory -Path $NetCfgDir -Force | Out-Null
$wanted = @('* 192.168.56.0/21', "* $Subnet")
$current = if (Test-Path $NetCfg) { Get-Content $NetCfg } else { @() }
if (($current -join "`n") -ne ($wanted -join "`n")) {
  Set-Content -Path $NetCfg -Value $wanted -Encoding ascii
  Write-Host "Wrote host-only allowlist to $NetCfg"
} else { Write-Host "Host-only allowlist already set" }

# 2. Ensure the dedicated adapter exists. If absent, create one — on a host that
#    already has the default adapter, the new one becomes "#2".
$ifs = & $VBoxManage list hostonlyifs
if (-not ($ifs -match [regex]::Escape($Adapter))) {
  $out = & $VBoxManage hostonlyif create 2>&1
  if ($out -match "Interface '(.+?)' was successfully created") {
    if ($matches[1] -ne $Adapter) {
      throw "VirtualBox created '$($matches[1])', not '$Adapter'. Set var.hostonly_adapter and `$Adapter to match, or remove stray host-only adapters."
    }
    Write-Host "Created dedicated host-only adapter '$Adapter'"
  } else { throw "Could not parse created host-only adapter name from: $out" }
} else { Write-Host "Host-only adapter '$Adapter' already exists" }

# 3. Assign the gateway IP to the dedicated adapter.
& $VBoxManage hostonlyif ipconfig "$Adapter" --ip $GwIp --netmask $Mask
Write-Host "Set $GwIp/$Prefix on '$Adapter'"

# 4. Disable the adapter's DHCP server (nodes get static IPs via kernel arg).
& $VBoxManage dhcpserver modify --ifname "$Adapter" --disable 2>$null
if ($LASTEXITCODE -ne 0) {
  & $VBoxManage dhcpserver add --ifname "$Adapter" --ip $GwIp --netmask $Mask `
    --lowerip 10.66.6.250 --upperip 10.66.6.250 --disable 2>$null
}
Write-Host "DHCP disabled on '$Adapter'"

# 5. NAT 10.66.6.0/24 to the internet via the host's default route.
if (-not (Get-NetNat -Name $NatName -ErrorAction SilentlyContinue)) {
  New-NetNat -Name $NatName -InternalIPInterfaceAddressPrefix $Subnet | Out-Null
  Write-Host "Created NAT '$NatName' for $Subnet"
} else { Write-Host "NAT '$NatName' already exists" }

# 6. Enable IP forwarding on both the host-only adapter and the upstream (LAN)
#    NIC. New-NetNat does the address translation but does NOT route packets
#    between interfaces — without this the nodes can reach 10.66.6.1 but have no
#    internet. Interfaces are resolved dynamically (host-only by its $GwIp, WAN
#    by the default route) so this works regardless of adapter index.
$HoIdx  = (Get-NetIPAddress -IPAddress $GwIp -ErrorAction Stop).ifIndex
$WanIdx = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop |
           Sort-Object RouteMetric | Select-Object -First 1).ifIndex
Set-NetIPInterface -ifIndex $HoIdx  -Forwarding Enabled
Set-NetIPInterface -ifIndex $WanIdx -Forwarding Enabled
Write-Host "Enabled IP forwarding on host-only (ifIndex $HoIdx) and WAN (ifIndex $WanIdx)"

Write-Host "`nDone. Dedicated adapter: '$Adapter' ($GwIp)."
Write-Host "From WSL2, verify reachability:  ping $GwIp"
