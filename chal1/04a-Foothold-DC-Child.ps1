<#
    Phase 4a: FOOTHOLD-Schwaechungen im Child (old.velocity.hacklu).
    Auf DC-OLD ausfuehren, angemeldet als OLD\Administrator. Idempotent.

    Baut die drei Story-Schwachstellen fuer den initialen Zugang:
      1. Anonyme Enumeration erlauben (RID-Bruteforce ohne Creds)
      2. Passwort-Policy lockern (damit username=password moeglich ist)
      3. Vergessener Testaccount mit username = password (Domain Users, low priv)

    ACHTUNG: LSA-/Policy-Aenderungen greifen erst nach einem Reboot.
    Das Skript rebootet am Ende (AutoRestart), wenn nicht anders gesetzt.
#>

# ===================== KONFIG =====================
$Domain      = 'old.velocity.hacklu'
$UsersPath   = 'CN=Users,DC=old,DC=velocity,DC=hacklu'

# Testaccount: Passwort wird GLEICH dem SamAccountName gesetzt (username=password).
$TestUserSam = 'svc_test'

$AutoRestart = $true
# ==================================================

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Bitte in einer erhoehten (Administrator) PowerShell ausfuehren." }

# --- 1) Passwort-Policy lockern (Complexity aus, Mindestlaenge runter) ---
Write-Host "[*] Lockere Default Domain Password Policy ..." -ForegroundColor Cyan
Set-ADDefaultDomainPasswordPolicy -Identity $Domain `
    -ComplexityEnabled $false -MinPasswordLength 1

# --- 2) Testaccount mit username = password ---
if (-not (Get-ADUser -Server $Domain -Filter "SamAccountName -eq '$TestUserSam'" -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Erstelle Testaccount '$TestUserSam' (Passwort = Username) ..." -ForegroundColor Cyan
    New-ADUser -Name $TestUserSam -SamAccountName $TestUserSam `
        -UserPrincipalName "$TestUserSam@$Domain" `
        -AccountPassword (ConvertTo-SecureString $TestUserSam -AsPlainText -Force) `
        -Enabled $true -PasswordNeverExpires $true -Server $Domain `
        -Description "Temporary migration test account - DO NOT USE IN PROD"
} else {
    # Falls schon vorhanden: Passwort sicher auf = Username setzen
    Set-ADAccountPassword -Server $Domain -Identity $TestUserSam -Reset `
        -NewPassword (ConvertTo-SecureString $TestUserSam -AsPlainText -Force)
    Write-Host "[*] Testaccount '$TestUserSam' existiert - Passwort auf Username zurueckgesetzt." -ForegroundColor DarkGray
}

# --- 3) Anonyme Enumeration: LSA-Registry ---
Write-Host "[*] Setze LSA-Anonymous-Registry ..." -ForegroundColor Cyan
$lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
Set-ItemProperty $lsa -Name RestrictAnonymous       -Value 0 -Type DWord
Set-ItemProperty $lsa -Name RestrictAnonymousSAM    -Value 0 -Type DWord
Set-ItemProperty $lsa -Name EveryoneIncludesAnonymous -Value 1 -Type DWord

# RestrictRemoteSam: sonst blockt Server 2025 anonymes SAMR (--rid-brute) mit
# STATUS_ACCESS_DENIED. Default erlaubt nur Built-in Admins (BA); wir ergaenzen
# Everyone (WD) und Anonymous Logon (AN).
Set-ItemProperty $lsa -Name RestrictRemoteSam `
    -Value 'O:BAG:BAD:(A;;RC;;;BA)(A;;RC;;;WD)(A;;RC;;;AN)' -Type String

# --- 3a2) Anonyme Named-Pipe-Zugriffe erlauben. Ohne das wird schon das
#          OEFFNEN von \pipe\lsarpc bzw. \pipe\samr mit STATUS_ACCESS_DENIED
#          (0xc0000022) abgewiesen - egal ob LSAR- oder SAMR-Methode. ---
$srv = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
Set-ItemProperty $srv -Name RestrictNullSessAccess -Value 0 -Type DWord
Set-ItemProperty $srv -Name NullSessionPipes -Value @('samr','lsarpc','netlogon') -Type MultiString

# --- 3d) RC4 fuer Kerberos DC-weit wieder erlauben. Server 2025 deaktiviert RC4
#          per Default -> Kerberoasting (etype 23) laeuft sonst in
#          KDC_ERR_ETYPE_NOSUPP, selbst wenn der Account RC4 kann. ---
$kerb = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters'
New-Item $kerb -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty $kerb -Name SupportedEncryptionTypes -Value 0x7FFFFFFF -Type DWord

# --- 3b) "Allow anonymous SID/Name translation" (LSAAnonymousNameLookup) ---
Write-Host "[*] Aktiviere anonyme SID/Name-Translation (secedit) ..." -ForegroundColor Cyan
$inf = Join-Path $env:TEMP 'sec_export.inf'
$sdb = Join-Path $env:TEMP 'sec_apply.sdb'
secedit /export /cfg "$inf" /areas SECURITYPOLICY /quiet | Out-Null
$content = Get-Content "$inf"
if ($content -match 'LSAAnonymousNameLookup') {
    $content = $content -replace 'LSAAnonymousNameLookup\s*=\s*\d', 'LSAAnonymousNameLookup = 1'
} else {
    $content = $content -replace '(\[System Access\])', "`$1`r`nLSAAnonymousNameLookup = 1"
}
$content | Set-Content "$inf" -Encoding Unicode   # WICHTIG: secedit-INF muss Unicode (UTF-16) sein
secedit /configure /db "$sdb" /cfg "$inf" /areas SECURITYPOLICY | Out-Null

# Verifikation direkt hier (vor dem Reboot):
secedit /export /cfg "$inf" /areas SECURITYPOLICY /quiet | Out-Null
if (Get-Content "$inf" | Select-String 'LSAAnonymousNameLookup = 1') {
    Write-Host "[*] LSAAnonymousNameLookup = 1 bestaetigt." -ForegroundColor Green
} else {
    Write-Host "[!] LSAAnonymousNameLookup NICHT gesetzt - secedit-Ausgabe pruefen." -ForegroundColor Red
}

# --- 3c) Anonymous Logon + Everyone in "Pre-Windows 2000 Compatible Access" ---
Write-Host "[*] Fuege Anonymous/Everyone zu 'Pre-Windows 2000 Compatible Access' hinzu ..." -ForegroundColor Cyan
# stderr INNERHALB von cmd nach nul + exit 0, damit "schon Mitglied" (Fehler 1378)
# das Skript unter ErrorActionPreference=Stop nicht abbricht.
cmd /c 'net localgroup "Pre-Windows 2000 Compatible Access" "anonymous logon" /add 2>nul & exit /b 0' | Out-Null
cmd /c 'net localgroup "Pre-Windows 2000 Compatible Access" "everyone" /add 2>nul & exit /b 0'         | Out-Null

Write-Host "`n[fertig] Foothold-Schwaechungen gesetzt." -ForegroundColor Green
Write-Host "         Testaccount: $TestUserSam / $TestUserSam" -ForegroundColor Yellow
Write-Host "         LSA-/Policy-Aenderungen greifen erst nach REBOOT." -ForegroundColor Yellow

if ($AutoRestart) { Write-Host "[*] Starte neu ..." -ForegroundColor Yellow; Restart-Computer -Force }
else { Write-Host "[!] Bitte neu starten: Restart-Computer -Force" -ForegroundColor Yellow }

# --- 3d) Fix permissions for RID brute ---
$inf="$env:TEMP\s.inf"; $sdb="$env:TEMP\s.sdb"
secedit /export /cfg $inf /areas SECURITYPOLICY /quiet
(Get-Content $inf) -replace 'LSAAnonymousNameLookup\s*=\s*\d','LSAAnonymousNameLookup = 1' | Set-Content $inf -Encoding Unicode
secedit /configure /db $sdb /cfg $inf /areas SECURITYPOLICY
secedit /export /cfg $inf /areas SECURITYPOLICY /quiet; Select-String LSAAnonymousNameLookup $inf
Restart-Computer -Force