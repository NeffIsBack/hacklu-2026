<#
    Phase 2a: DC-NEW zum Forest-Root promoten (velocity.hacklu).
#>

# ===================== CONFIG =====================
$DomainName         = 'velocity.hacklu'
$DomainNetbios      = 'VELOCITY'

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

Write-Host "[*] Erstelle Forest '$DomainName'" -ForegroundColor Yellow
Install-ADDSForest `
    -DomainName                     $DomainName `
    -DomainNetbiosName              $DomainNetbios `
    -ForestMode                     'WinThreshold' `
    -DomainMode                     'WinThreshold' `
    -InstallDns `
    -SafeModeAdministratorPassword  (ConvertTo-SecureString $DsrmPassword -AsPlainText -Force) `
    -Force