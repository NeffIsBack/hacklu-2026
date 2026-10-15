# ============================================================
#  DC - Abschluss: SRV nach OU=Servers verschieben
#  ERST ausfuehren, nachdem SRV der Domaene beigetreten ist (Skript 21).
#  Damit greift die GPO 'SRV-Baseline' auf SRV.
# ============================================================

# ==== Konfiguration ====
$SrvName = 'SRV'
$OuName  = 'Servers'
# =======================

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$ouDN = "OU=$OuName,$((Get-ADDomain).DistinguishedName)"
$comp = Get-ADComputer -Identity $SrvName
Move-ADObject -Identity $comp.DistinguishedName -TargetPath $ouDN
Write-Host "[+] '$SrvName' nach '$ouDN' verschoben."
Write-Host "[i] Auf SRV wirkt die GPO nach max. 5 min (oder 'gpupdate /force')."
gpupdate /force