# ==== Konfiguration ====
$DomainFqdn = 'agile-corp.hacklu'
$WsusLabel  = 'wsus'
$WsusTarget = '172.16.10.10'    # verwaist
# =======================

$ErrorActionPreference = 'Stop'

Set-DnsServerPrimaryZone -Name $DomainFqdn -DynamicUpdate NonsecureAndSecure