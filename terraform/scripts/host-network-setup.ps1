# Run as Administrator on the Windows Hyper-V host. Idempotent.
# Creates the isolated cluster network the Hyper-V Terraform provider can't manage:
#   - Internal vSwitch
#   - host gateway vNIC (10.66.6.1/24)
#   - NAT so nodes reach the internet through the host's LAN NIC
$ErrorActionPreference = 'Stop'

$Switch  = 'jeen-internal'
$GwIp    = '10.66.6.1'
$Prefix  = 24
$Subnet  = '10.66.6.0/24'
$NatName = 'jeen-nat'

if (-not (Get-VMSwitch -Name $Switch -ErrorAction SilentlyContinue)) {
  New-VMSwitch -Name $Switch -SwitchType Internal | Out-Null
  Write-Host "Created Internal switch '$Switch'"
} else { Write-Host "Switch '$Switch' already exists" }

$ifAlias = "vEthernet ($Switch)"
if (-not (Get-NetIPAddress -InterfaceAlias $ifAlias -IPAddress $GwIp -ErrorAction SilentlyContinue)) {
  New-NetIPAddress -InterfaceAlias $ifAlias -IPAddress $GwIp -PrefixLength $Prefix | Out-Null
  Write-Host "Assigned $GwIp/$Prefix to '$ifAlias'"
} else { Write-Host "$GwIp already on '$ifAlias'" }

if (-not (Get-NetNat -Name $NatName -ErrorAction SilentlyContinue)) {
  New-NetNat -Name $NatName -InternalIPInterfaceAddressPrefix $Subnet | Out-Null
  Write-Host "Created NAT '$NatName' for $Subnet"
} else { Write-Host "NAT '$NatName' already exists" }

Write-Host "`nDone. From WSL2, verify reachability:  ping $GwIp"
