<#
    Phase 1: Grundkonfiguration DC-OLD (Child).
#>

# ===================== CONFIG =====================
$HostName       = 'DC-OLD'
$IPAddress      = '10.244.0.20'
$PrefixLength   = 24
$DefaultGateway = '10.244.1.2'
$DnsServers     = @('10.244.0.10')
$InterfaceAlias = ''
# ==================================================

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Bitte in einer erhoehten (Administrator) PowerShell ausfuehren." }

if (-not $InterfaceAlias) {
    $candidates = Get-NetAdapter -Physical | Where-Object Status -eq 'Up'
    if (@($candidates).Count -eq 0) { throw "Kein aktiver Netzwerkadapter gefunden." }
    if (@($candidates).Count -gt 1) {
        throw ("Mehrere aktive Adapter: {0}. Bitte `$InterfaceAlias oben explizit setzen." `
               -f ($candidates.Name -join ', '))
    }
    $InterfaceAlias = $candidates.Name
}
Write-Host "[*] Verwende Interface '$InterfaceAlias'" -ForegroundColor Cyan

Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false
Get-NetRoute -InterfaceAlias $InterfaceAlias -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
    Remove-NetRoute -Confirm:$false
Set-NetIPInterface -InterfaceAlias $InterfaceAlias -Dhcp Disabled

$ipParams = @{
    InterfaceAlias = $InterfaceAlias
    IPAddress      = $IPAddress
    PrefixLength   = $PrefixLength
    AddressFamily  = 'IPv4'
}
if ($DefaultGateway) { $ipParams.DefaultGateway = $DefaultGateway }
New-NetIPAddress @ipParams | Out-Null
Write-Host "[*] IP gesetzt: $IPAddress/$PrefixLength" -ForegroundColor Green

Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DnsServers
Write-Host "[*] DNS gesetzt: $($DnsServers -join ', ')  (Parent-DC)" -ForegroundColor Green

if ($env:COMPUTERNAME -ne $HostName) {
    Rename-Computer -NewName $HostName -Force
    Write-Host "[*] Umbenannt: $($env:COMPUTERNAME) -> $HostName (Reboot noetig)" -ForegroundColor Yellow
} else {
    Write-Host "[*] Hostname ist bereits '$HostName'" -ForegroundColor DarkGray
}

Write-Host "[*] Starte neu ..." -ForegroundColor Yellow; Restart-Computer -Force