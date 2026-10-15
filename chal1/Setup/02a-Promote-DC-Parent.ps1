<#
    Phase 2a: DC-NEW zum Forest-Root promoten (velocity.hacklu).
    Ohne Parameter - Werte im KONFIG-Block anpassen und Skript einfach ausfuehren.
    Voraussetzung: Phase 1 (01-BaseConfig-DC-NEW) gelaufen + rebootet.
    ACHTUNG: rebootet am Ende automatisch. Danach 02b ausfuehren.

    ForestMode/DomainMode = WinThreshold (=FFL/DFL 2016). NICHT auf 2025 heben,
    sonst kommt spaeter kein Down-Level-Child-DC (2019/2022) mehr rein.
#>

# ===================== KONFIG =====================
$DomainName         = 'velocity.hacklu'
$DomainNetbios      = 'VELOCITY'

# LAB-ONLY, hartkodiert. Komplexitaet noetig (Gross/Klein/Ziffer/Sonderzeichen).
# LocalAdminPassword wird bei der Promotion zum DOMAIN-ADMIN-Passwort -> merken!
$LocalAdminPassword = 'C8J33i45kt4HXHMQ'
$DsrmPassword       = 'C8J33i45kt4HXHMQ'
# ==================================================

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Bitte in einer erhoehten (Administrator) PowerShell ausfuehren." }

Write-Host "[*] Setze Passwort fuer lokalen Administrator ..." -ForegroundColor Cyan
Set-LocalUser -Name "Administrator" `
    -Password (ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force)

Write-Host "[*] Installiere AD-DS-Rolle ..." -ForegroundColor Cyan
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools | Out-Null

Write-Host "[*] Erstelle Forest '$DomainName' (FFL/DFL 2016) - reboot folgt automatisch." -ForegroundColor Yellow
Install-ADDSForest `
    -DomainName                     $DomainName `
    -DomainNetbiosName              $DomainNetbios `
    -ForestMode                     'WinThreshold' `
    -DomainMode                     'WinThreshold' `
    -InstallDns `
    -SafeModeAdministratorPassword  (ConvertTo-SecureString $DsrmPassword -AsPlainText -Force) `
    -Force