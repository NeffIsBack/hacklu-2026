<#
    Setzt "Network access: Allow anonymous SID/Name translation" = Enabled
    DAUERHAFT in der Default Domain Controllers Policy (ueberlebt gpupdate/Reboot).
    Fuer Server Core. Auf DC-OLD als OLD\Administrator ausfuehren.
#>
$ErrorActionPreference = 'Stop'

# Default Domain Controllers Policy hat IMMER diese GUID:
$guid   = '{6AC1786C-016F-11D2-945F-00C04fB984F9}'
$domain = (Get-ADDomain).DNSRoot
$polDir = "\\$domain\SYSVOL\$domain\Policies\$guid"
$secDir = Join-Path $polDir 'MACHINE\Microsoft\Windows NT\SecEdit'
$inf    = Join-Path $secDir 'GptTmpl.inf'
$gptIni = Join-Path $polDir 'GPT.ini'

if (-not (Test-Path $secDir)) { New-Item -ItemType Directory -Path $secDir -Force | Out-Null }

# --- GptTmpl.inf (Unicode!) anlegen/patchen ---
if (-not (Test-Path $inf)) {
@"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[System Access]
LSAAnonymousNameLookup = 1
"@ | Set-Content $inf -Encoding Unicode
    Write-Host "[*] GptTmpl.inf neu angelegt." -ForegroundColor Cyan
} else {
    $c = Get-Content $inf
    if ($c -match 'LSAAnonymousNameLookup') {
        $c = $c -replace 'LSAAnonymousNameLookup\s*=\s*\d','LSAAnonymousNameLookup = 1'
    } elseif ($c -match '\[System Access\]') {
        $c = $c -replace '(\[System Access\])',"`$1`r`nLSAAnonymousNameLookup = 1"
    } else {
        $c += '','[System Access]','LSAAnonymousNameLookup = 1'
    }
    $c | Set-Content $inf -Encoding Unicode
    Write-Host "[*] GptTmpl.inf gepatcht." -ForegroundColor Cyan
}

# --- GPT.ini Versionsnummer hochzaehlen (sonst verteilt AD die Aenderung nicht) ---
if (Test-Path $gptIni) {
    $gi = Get-Content $gptIni
    $verLine = $gi | Where-Object { $_ -match '^Version=' }
    $cur = [int]($verLine -replace 'Version=','')
    $new = $cur + 1
    ($gi -replace '^Version=.*',"Version=$new") | Set-Content $gptIni -Encoding ASCII
    Write-Host "[*] GPT.ini Version $cur -> $new" -ForegroundColor Green
} else {
@"
[General]
Version=1
"@ | Set-Content $gptIni -Encoding ASCII
    Write-Host "[*] GPT.ini neu angelegt (Version=1)." -ForegroundColor Green
}

Write-Host "`n[*] gpupdate ..." -ForegroundColor Yellow
gpupdate /target:computer /force | Out-Null

# --- Verifikation ---
$t = "$env:TEMP\verify.inf"
secedit /export /cfg $t /areas SECURITYPOLICY /quiet | Out-Null
$line = (Get-Content $t | Select-String 'LSAAnonymousNameLookup').Line
if ($line -match '= 1') { Write-Host "[OK] $line  (dauerhaft in der GPO verankert)" -ForegroundColor Green }
else { Write-Host "[!] $line  - Replikation evtl. noch nicht durch; in 1-2 Min erneut 'gpupdate /force' + pruefen." -ForegroundColor Red }

Restart-Computer -Force