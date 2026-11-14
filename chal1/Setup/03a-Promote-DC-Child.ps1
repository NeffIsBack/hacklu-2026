<#
    Phase 3a: DC-OLD als Child-Domain 'old.velocity.hacklu' promoten.
#>

# ===================== CONFIG =====================
$NewDomainName       = 'old'
$ParentDomain        = 'velocity.hacklu'
$NewNetbios          = 'OLD'
$ParentNetbios       = 'VELOCITY'
$ParentDcIp          = '10.244.0.10'

$LocalAdminPassword  = 'qcSiecDUATD63Kxm'
$DsrmPassword        = 'qcSiecDUATD63Kxm'
$ParentAdminPassword = 'C8J33i45kt4HXHMQ'
# ==================================================

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Bitte in einer erhoehten (Administrator) PowerShell ausfuehren." }

Write-Host "[*] Pruefe Verbindung zum Parent-DC ($ParentDcIp) ..." -ForegroundColor Cyan
if (-not (Test-Connection -ComputerName $ParentDcIp -Count 1 -Quiet)) {
    throw "Parent-DC $ParentDcIp nicht erreichbar. Netzwerk/Adapter pruefen."
}
try { Resolve-DnsName -Name $ParentDomain -ErrorAction Stop | Out-Null }
catch { throw "DNS kann '$ParentDomain' nicht aufloesen. Zeigt DNS auf $ParentDcIp? (01-BaseConfig-DC-OLD)" }
if (-not (Resolve-DnsName -Type SRV "_ldap._tcp.dc._msdcs.$ParentDomain" -ErrorAction SilentlyContinue)) {
    throw "Kein DC-Locator-SRV-Record fuer $ParentDomain gefunden. DNS zeigt nicht korrekt auf den Parent-DC."
}
Write-Host "[*] Parent erreichbar, DNS + SRV loesen auf." -ForegroundColor Green

Write-Host "[*] Setze Passwort fuer lokalen Administrator ..." -ForegroundColor Cyan
Set-LocalUser -Name "Administrator" `
    -Password (ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force)

Write-Host "[*] Installiere AD-DS-Rolle ..." -ForegroundColor Cyan
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools | Out-Null

$eaCred = New-Object System.Management.Automation.PSCredential(
    "Administrator@$ParentDomain",
    (ConvertTo-SecureString $ParentAdminPassword -AsPlainText -Force))

Write-Host "[*] Erstelle Child-Domain '$NewDomainName.$ParentDomain'" -ForegroundColor Yellow
Install-ADDSDomain `
    -NewDomainName                  $NewDomainName `
    -ParentDomainName               $ParentDomain `
    -NewDomainNetbiosName           $NewNetbios `
    -DomainType                     ChildDomain `
    -DomainMode                     'WinThreshold' `
    -InstallDns `
    -Credential                     $eaCred `
    -SafeModeAdministratorPassword  (ConvertTo-SecureString $DsrmPassword -AsPlainText -Force) `
    -Force