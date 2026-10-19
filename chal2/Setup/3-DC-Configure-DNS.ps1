# ============================================================
#  DC - Schritt 3: DNS-Misconfig + wsus-Record
# ============================================================

# ==== Konfiguration ====
$DomainFqdn = 'agile-corp.hacklu'
$WsusLabel  = 'wsus'
$WsusTarget = '172.16.10.10'    # verwaist 
# =======================

$ErrorActionPreference = 'Stop'

Set-DnsServerPrimaryZone -Name $DomainFqdn -DynamicUpdate NonsecureAndSecure

if (-not (Get-DnsServerResourceRecord -ZoneName $DomainFqdn -Name $WsusLabel -RRType A -ErrorAction SilentlyContinue)) {
    Add-DnsServerResourceRecordA -ZoneName $DomainFqdn -Name $WsusLabel -IPv4Address $WsusTarget
    Write-Host "[+] $WsusLabel.$DomainFqdn -> $WsusTarget (verwaist)"
} else {
    Write-Host "[=] Record '$WsusLabel' existiert bereits."
}
Write-Host "[+] Zone '$DomainFqdn': dynamische Updates = NonsecureAndSecure (angreifbar)."