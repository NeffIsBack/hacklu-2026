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

<#
    Setzt LDAP Server Signing (und Channel Binding) DAUERHAFT als Security Option
    in der Default Domain Controllers Policy - ueberlebt gpupdate/Reboot.
    Grund: LDAPServerIntegrity ist eine Security Option; die Security-CSE setzt
    sie bei jedem gpupdate aus GptTmpl.inf neu. Reine Registry / registry.pol
    (Set-GPRegistryValue) verliert dagegen. Fuer Core. Auf DC-OLD als Admin.
#>
$ErrorActionPreference = 'Stop'

$guid   = '{6AC1786C-016F-11D2-945F-00C04fB984F9}'   # Default Domain Controllers Policy
$dom    = (Get-ADDomain).DNSRoot
$polDir = "\\$dom\SYSVOL\$dom\Policies\$guid"
$inf    = Join-Path $polDir 'MACHINE\Microsoft\Windows NT\SecEdit\GptTmpl.inf'
$gptIni = Join-Path $polDir 'GPT.ini'

if (-not (Test-Path $inf)) { throw "GptTmpl.inf nicht gefunden: $inf" }

# Ziel-Zeilen (Registry Values Format: TYPE,WERT ; 4 = REG_DWORD)
$targets = @{
    'MACHINE\System\CurrentControlSet\Services\NTDS\Parameters\LDAPServerIntegrity'       = '4,2'  # require signing
    'MACHINE\System\CurrentControlSet\Services\NTDS\Parameters\LdapEnforceChannelBinding' = '4,2'  # always
}

$c = Get-Content $inf

# [Registry Values] Sektion sicherstellen
if ($c -notmatch '\[Registry Values\]') { $c += '', '[Registry Values]' }

foreach ($k in $targets.Keys) {
    $esc  = [regex]::Escape($k)
    $line = "$k=$($targets[$k])"
    if ($c -match "^$esc=") {
        $c = $c -replace "^$esc=.*", $line
        Write-Host "[*] ersetzt: $line" -ForegroundColor Cyan
    } else {
        # direkt hinter [Registry Values] einfuegen
        $c = $c -replace '(\[Registry Values\])', "`$1`r`n$line"
        Write-Host "[*] hinzugefuegt: $line" -ForegroundColor Cyan
    }
}
$c | Set-Content $inf -Encoding Unicode

# GPT.ini Computer-Version hochzaehlen (sonst verteilt AD nichts)
$gi = Get-Content $gptIni
$cur = [int](($gi | Where-Object { $_ -match '^Version=' }) -replace 'Version=','')
$new = $cur + 1
($gi -replace '^Version=.*', "Version=$new") | Set-Content $gptIni -Encoding ASCII
Write-Host "[*] GPT.ini Version $cur -> $new" -ForegroundColor Green

Write-Host "`n[*] gpupdate ..." -ForegroundColor Yellow
gpupdate /target:computer /force | Out-Null

secedit /export /cfg "$env:TEMP\verify.inf" /areas SECURITYPOLICY /quiet | Out-Null
Get-Content "$env:TEMP\verify.inf" | Select-String 'LDAPServerIntegrity','LdapEnforceChannelBinding'
Write-Host "[i] Jetzt NTDS neu starten oder rebooten, damit LDAP die Pflicht uebernimmt." -ForegroundColor Yellow

# --- Remove PS history ---
Remove-Item "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt" -Force -ErrorAction SilentlyContinue

Write-Host "[*] Starte neu ..." -ForegroundColor Yellow; Restart-Computer -Force 