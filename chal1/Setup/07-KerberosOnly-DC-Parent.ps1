<#
    Phase 7: Kerberos-only fuer den PARENT
#>

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Bitte in einer erhoehten (Administrator) PowerShell ausfuehren." }

$lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
$msv = "$lsa\MSV1_0"
$nl  = 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters'
New-Item $msv -Force -ErrorAction SilentlyContinue | Out-Null

Set-ItemProperty $nl  -Name RestrictNTLMInDomain       -Value 7 -Type DWord   # 7 = Deny all (domaenenweit)
Set-ItemProperty $msv -Name RestrictReceivingNTLMTraffic -Value 2 -Type DWord # 2 = Deny all incoming
Set-ItemProperty $msv -Name RestrictSendingNTLMTraffic   -Value 2 -Type DWord # 2 = Deny all outgoing
Set-ItemProperty $lsa -Name LmCompatibilityLevel         -Value 5 -Type DWord # NTLMv2 only / refuse LM+NTLM
Write-Host "[*] ENFORCE-Modus: NTLM im Parent gesperrt (Kerberos-only)." -ForegroundColor Green

Write-Host "`n[fertig] REBOOT noetig." -ForegroundColor Yellow
Restart-Computer -Force