# ============================================================
#  DC - Schritt 7: MAQ=0, Flag, WSUS-Client (ohne echten Server)
#
#   - ms-DS-MachineAccountQuota = 0  (erzwingt Priv-Esc fuer Machine Account)
#   - Flag auf den Administrator-Desktop
#   - DC als WSUS-Client: WUServer = https://wsus...:8531 (verwaist, HTTPS-fix)
#   - Scheduled Task: alle 5 min WU-Scan (Playability)
#
#  Kein echter WSUS-Server: Im Angriff biegt der Spieler den DNS-Record
#  auf seinen Host um und faehrt dort wsuks mit dem ADCS-Zert -> RCE.
# ============================================================

# ==== Konfiguration ====
$WsusUrl   = 'https://wsus.agile-corp.hacklu:8531'
$ScanEvery = 5   # Minuten
# =======================

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

# --- MAQ = 0 ---------------------------------------------------------
Set-ADObject -Identity (Get-ADDomain).DistinguishedName -Replace @{'ms-DS-MachineAccountQuota'=0}
Write-Host "[+] ms-DS-MachineAccountQuota = 0"

# --- WSUS-Client-Policy (nur HTTPS, Ziel verwaist) -------------------
$wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$au = "$wu\AU"
New-Item -Path $au -Force | Out-Null
Set-ItemProperty -Path $wu -Name 'WUServer'       -Value $WsusUrl -Type String
Set-ItemProperty -Path $wu -Name 'WUStatusServer' -Value $WsusUrl -Type String
Set-ItemProperty -Path $au -Name 'UseWUServer'    -Value 1 -Type DWord
Set-ItemProperty -Path $au -Name 'NoAutoUpdate'   -Value 0 -Type DWord
Set-ItemProperty -Path $au -Name 'AUOptions'      -Value 4 -Type DWord   # auto download + install
Write-Host "[+] WUServer = $WsusUrl (HTTPS-fix)"

# --- 5-min-Scan-Task -------------------------------------------------
$action  = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\UsoClient.exe" -Argument 'StartScan'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
             -RepetitionInterval (New-TimeSpan -Minutes $ScanEvery) `
             -RepetitionDuration (New-TimeSpan -Days 3650)
Register-ScheduledTask -TaskName 'WSUS-FastScan' -Action $action -Trigger $trigger `
    -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
Write-Host "[+] Scan-Task 'WSUS-FastScan' alle $ScanEvery min."

Write-Host "`n[i] Scan-Trigger auf 2022 beim Durchspielen verifizieren (UsoClient StartScan)."
Write-Host "    Fallbacks: COM (Microsoft.Update.AutoUpdate).DetectNow() oder wuauclt /detectnow."