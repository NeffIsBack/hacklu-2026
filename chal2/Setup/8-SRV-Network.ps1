# ============================================================
#  SRV - Schritt 1: Netzwerk & Rechnername
#  Auf der SERVER-CORE-KONSOLE von SRV ausfuehren. Danach rebooten.
# ============================================================

# ==== Konfiguration ====
$Name      = 'SRV'
$IP        = '192.168.108.20'
$Prefix    = 24
$Gateway   = '192.168.108.2'
$DnsServer = '192.168.108.10'    # DC
# =======================

$ErrorActionPreference = 'Stop'

$nic = Get-NetAdapter -Physical | Where-Object Status -eq 'Up' | Select-Object -First 1
if (-not $nic) { $nic = Get-NetAdapter -Physical | Select-Object -First 1 }
Write-Host "[*] Adapter '$($nic.Name)'"

Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object PrefixOrigin -ne 'WellKnown' |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetRoute -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue

New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress $IP -PrefixLength $Prefix -DefaultGateway $Gateway | Out-Null
Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses $DnsServer   # -> DC

if ($env:COMPUTERNAME -ne $Name) { Rename-Computer -NewName $Name -Force }

Write-Host "[+] IP $IP/$Prefix, DNS $DnsServer, Name '$Name'."
Restart-Computer -Force