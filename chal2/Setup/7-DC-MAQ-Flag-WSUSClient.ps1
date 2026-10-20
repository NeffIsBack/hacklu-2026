# ============================================================
#  DC - Schritt 7: MAQ=0, Flag, WSUS-Client
# ============================================================

# ==== Konfiguration ====
$WsusUrl   = 'https://wsus.agile-corp.hacklu:8531'
$ScanEvery = 1   
$WsusGpo    = 'Windows-Update-Policy'
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

# --- PSWindowsUpdate installieren -----

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers
Write-Host "[+] PSWindowsUpdate installiert."

# --- Scan-Task: erst DNS flushen, dann via WSUS installieren ---------

$flush  = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\ipconfig.exe" -Argument '/flushdns'
$update = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
             -Argument '-NoProfile -ExecutionPolicy Bypass -Command "Import-Module PSWindowsUpdate; Install-WindowsUpdate -AcceptAll -IgnoreReboot | Out-Null"'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
             -RepetitionInterval (New-TimeSpan -Minutes $ScanEvery) `
             -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
Register-ScheduledTask -TaskName 'WSUS-FastScan' -Action $flush,$update -Trigger $trigger `
    -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
Write-Host "[+] Scan-Task 'WSUS-FastScan' alle $ScanEvery min (flushdns + Install-WindowsUpdate)."

# --- GPO fuer WSUS-Client (schreibt registry.pol nach SYSVOL) --------
# wsuks --discover liest SYSVOL-GPOs und findet WUServer darin.
# Damit ist der WSUS-Endpunkt fuer den Angreifer nach dem initialen
# Access (svc_deploy-Creds) sauber auffindbar ohne Ratespiel.
if (-not (Get-GPO -Name $WsusGpo -ErrorAction SilentlyContinue)) {
    New-GPO -Name $WsusGpo -Comment 'Corporate Windows Update configuration' | Out-Null
    Write-Host "[+] GPO '$WsusGpo' angelegt."
} else { Write-Host "[=] GPO '$WsusGpo' existiert bereits." }
 
$wuKey = 'HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate'
$auKey = "$wuKey\AU"
Set-GPRegistryValue -Name $WsusGpo -Key $wuKey -ValueName 'WUServer'       -Type String -Value $WsusUrl | Out-Null
Set-GPRegistryValue -Name $WsusGpo -Key $wuKey -ValueName 'WUStatusServer' -Type String -Value $WsusUrl | Out-Null
Set-GPRegistryValue -Name $WsusGpo -Key $auKey -ValueName 'UseWUServer'    -Type DWord  -Value 1        | Out-Null
Set-GPRegistryValue -Name $WsusGpo -Key $auKey -ValueName 'NoAutoUpdate'   -Type DWord  -Value 0        | Out-Null
Set-GPRegistryValue -Name $WsusGpo -Key $auKey -ValueName 'AUOptions'      -Type DWord  -Value 4        | Out-Null
 
# GPO an Domain-Root verknuepfen (alle Computer, inkl. DC, bekommen sie)
$domainDN = (Get-ADDomain).DistinguishedName
try { New-GPLink -Name $WsusGpo -Target $domainDN -LinkEnabled Yes -ErrorAction Stop | Out-Null
      Write-Host "[+] GPO '$WsusGpo' an Domain-Root verknuepft." }
catch { Write-Host "[=] GPO-Link vermutlich bereits vorhanden." }
 
Write-Host "[+] WSUS-URL via SYSVOL/registry.pol auffindbar."
