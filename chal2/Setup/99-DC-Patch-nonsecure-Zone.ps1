# ==== Configuration ====
$DomainFqdn = 'agile-corp.hacklu'
$WsusLabel  = 'wsus'
$WsusTarget = '172.16.10.10'
# =======================

$ErrorActionPreference = 'Stop'

Set-DnsServerPrimaryZone -Name $DomainFqdn -DynamicUpdate NonsecureAndSecure