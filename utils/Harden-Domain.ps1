<#
    Reboot noetig, damit die Signing-Settings greifen.

    - MachineAccountQuota = 0
    - SMB Signing: required
    - LDAP Signing: required            (NTDS\LDAPServerIntegrity = 2)
    - LDAP Channel Binding: always      (NTDS\LdapEnforceChannelBinding = 2)
    - Remove PS history                 (ConsoleHost_history.txt)

#>

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Bitte in einer erhoehten (Administrator) PowerShell ausfuehren." }

# --- MachineAccountQuota = 0 (eigene Domaene) ---
$dn = (Get-ADDomain).DistinguishedName
Set-ADObject -Identity $dn -Replace @{ 'ms-DS-MachineAccountQuota' = 0 }
Write-Host "[*] ms-DS-MachineAccountQuota = 0 ($dn)" -ForegroundColor Green

# --- SMB Signing: required ---
$srv = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
Set-ItemProperty $srv -Name RequireSecuritySignature -Value 1 -Type DWord
Set-ItemProperty $srv -Name EnableSecuritySignature  -Value 1 -Type DWord
Write-Host "[*] SMB Signing: required" -ForegroundColor Green

# --- LDAP Signing + Channel Binding ---
$ntds = 'HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters'
Set-ItemProperty $ntds -Name LDAPServerIntegrity        -Value 2 -Type DWord   # 2 = require signing
Set-ItemProperty $ntds -Name LdapEnforceChannelBinding  -Value 2 -Type DWord   # 2 = always
Write-Host "[*] LDAP Signing: required, Channel Binding: always" -ForegroundColor Green

Write-Host "`n[fertig] Basis-Haertung gesetzt. REBOOT noetig, damit Signing greift." -ForegroundColor Yellow

# --- Remove PS history ---
Remove-Item "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt" -Force -ErrorAction SilentlyContinue

Write-Host "[*] Starte neu ..." -ForegroundColor Yellow; Restart-Computer -Force 