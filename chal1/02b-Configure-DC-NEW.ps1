<#
    Phase 2b: Parent-Objekte auf DC-NEW anlegen (nach Promotion + Reboot).
    Ohne Parameter - Werte im KONFIG-Block anpassen und Skript einfach ausfuehren.
    Als Domain Admin auf DC-NEW ausfuehren. Idempotent.

    FINALE ARCHITEKTUR:
      - Kerberoastbarer Account + Gruppe leben im CHILD (siehe 03b).
      - Hier im PARENT nur: KDS Root Key (forest-weit) + gMSA (noch OHNE
        Leseberechtigte) + SMB-Share Backup$.
      - Die Verknuepfung "Child-Gruppe darf gMSA-Passwort lesen" setzt 03c.
#>

# ===================== KONFIG =====================
$NetBIOS   = 'VELOCITY'
$Domain    = 'velocity.hacklu'
$ShareRoot = 'C:\Shares\Backup'
# ==================================================

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

# --- 1) KDS Root Key (forest-weit, nur einmal noetig; rueckdatiert => sofort nutzbar) ---
if (-not (Get-KdsRootKey -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Lege KDS Root Key an (rueckdatiert) ..." -ForegroundColor Cyan
    Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10)) | Out-Null
} else {
    Write-Host "[*] KDS Root Key existiert bereits." -ForegroundColor DarkGray
}

# --- 2) gMSA im Parent (Leseberechtigte werden erst in 03c gesetzt) ---
if (-not (Get-ADServiceAccount -Filter "SamAccountName -eq 'svc_backup_gmsa$'" -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Erstelle gMSA svc_backup_gmsa (noch ohne Leseberechtigte) ..." -ForegroundColor Cyan
    New-ADServiceAccount -Name "svc_backup_gmsa" `
        -DNSHostName "svc_backup_gmsa.$Domain" `
        -Enabled $true `
        -Description "Velocity backup service managed account"
} else {
    Write-Host "[*] svc_backup_gmsa existiert bereits." -ForegroundColor DarkGray
}

# --- 3) Backup$-Share (Ordner + NTFS-ACL + SMB-Freigabe) ---
if (-not (Test-Path $ShareRoot)) {
    New-Item -ItemType Directory -Path $ShareRoot -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $ShareRoot 'Export') -Force | Out-Null
    Write-Host "[*] Ordner $ShareRoot (+ \Export) angelegt." -ForegroundColor Cyan
}

$acl = Get-Acl $ShareRoot
$acl.SetAccessRuleProtection($true, $false)
$rules = @(
    New-Object System.Security.AccessControl.FileSystemAccessRule(
        "BUILTIN\Administrators","FullControl","ContainerInherit,ObjectInherit","None","Allow")
    New-Object System.Security.AccessControl.FileSystemAccessRule(
        "NT AUTHORITY\SYSTEM","FullControl","ContainerInherit,ObjectInherit","None","Allow")
    New-Object System.Security.AccessControl.FileSystemAccessRule(
        "$NetBIOS\svc_backup_gmsa$","ReadAndExecute","ContainerInherit,ObjectInherit","None","Allow")
)
foreach ($r in $rules) { $acl.AddAccessRule($r) }
Set-Acl $ShareRoot $acl
Write-Host "[*] NTFS-ACL gesetzt." -ForegroundColor Green

if (-not (Get-SmbShare -Name 'Backup$' -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name 'Backup$' -Path $ShareRoot `
        -ReadAccess "$NetBIOS\svc_backup_gmsa$" `
        -FullAccess "BUILTIN\Administrators" | Out-Null
    Write-Host "[*] SMB-Share 'Backup\$' erstellt." -ForegroundColor Green
} else {
    Write-Host "[*] SMB-Share 'Backup\$' existiert bereits." -ForegroundColor DarkGray
}

Write-Host "`n[fertig] In \Export gehoert spaeter die veraltete NTDS.dit der alten Domain." -ForegroundColor Yellow