# ============================================================
#  SRV - Schritt 2: Domain-Join (rebootet automatisch)
#  Nach dem Reboot aus Schritt 1 einfuegen. DC muss laufen.
# ============================================================

# ==== Konfiguration ====
$DomainFqdn = 'agile-corp.hacklu'
$JoinUser   = 'AGILE-CORP\Administrator'
$JoinPass   = 'c3PXFKV6x44FsM4p'     # Passwort des Domain-Administrators (= DC-Admin-Passwort)
# =======================

$ErrorActionPreference = 'Stop'

$cred = [pscredential]::new($JoinUser, (ConvertTo-SecureString $JoinPass -AsPlainText -Force))
Add-Computer -DomainName $DomainFqdn -Credential $cred -Restart -Force