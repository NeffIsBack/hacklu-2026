# ============================================================
#  DC - Schritt 3: DNS-Misconfig + wsus-Record (verwaist)
#  Nach der Promotion einfuegen.
#
#  - Zone erlaubt NICHT-sichere dynamische Updates
#    -> Angreifer kann 'wsus' spaeter ueberschreiben
#  - 'wsus' zeigt nominal auf den DC, es lauscht aber NICHTS auf 8531.
#    Ein echter WSUS-Server ist nicht noetig.
# ============================================================

# ==== Konfiguration ====
$DomainFqdn = 'agile-corp.hacklu'
$WsusLabel  = 'wsus'
$WsusTarget = '172.16.10.10'    # verwaist (DC-IP)
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