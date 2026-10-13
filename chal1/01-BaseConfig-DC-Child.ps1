<#
    Phase 1: Grundkonfiguration DC-OLD (Child).
    Ohne Parameter - Werte im KONFIG-Block anpassen und Skript einfach ausfuehren.
    WICHTIG: DnsServers zeigt auf den PARENT-DC, sonst findet 03a die Elterndomaene nicht.
    In einer ERHOEHTEN (Administrator) PowerShell starten.
#>

# ===================== KONFIG =====================
$HostName       = 'DC-OLD'
$IPAddress      = '192.168.84.11'
$PrefixLength   = 24
$DefaultGateway = '192.168.84.2'      # '' = kein Gateway (isoliertes Lab)
$DnsServers     = @('192.168.84.10')  # ZEIGT AUF DEN PARENT-DC (DC-NEW)!
$InterfaceAlias = ''                  # '' = Auto-Erkennung des aktiven Adapters
$AutoRestart    = $true
# ==================================================

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Bitte in einer erhoehten (Administrator) PowerShell ausfuehren." }

if (-not $InterfaceAlias) {
    $candidates = Get-NetAdapter -Physical | Where-Object Status -eq 'Up'
    if (@($candidates).Count -eq 0) { throw "Kein aktiver physischer Netzwerkadapter gefunden." }
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

if ($AutoRestart) { Write-Host "[*] Starte neu ..." -ForegroundColor Yellow; Restart-Computer -Force }
else { Write-Host "[!] Bei Gelegenheit: Restart-Computer -Force" -ForegroundColor Yellow }