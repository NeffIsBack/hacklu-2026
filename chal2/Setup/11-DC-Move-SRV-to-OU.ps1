# ============================================================
#  DC - Abschluss: SRV nach OU=Servers verschieben
# ============================================================

# ==== Configuration ====
$SrvName = 'SRV'
$OuName  = 'Servers'
# =======================

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$ouDN = "OU=$OuName,$((Get-ADDomain).DistinguishedName)"
$comp = Get-ADComputer -Identity $SrvName
Move-ADObject -Identity $comp.DistinguishedName -TargetPath $ouDN
Write-Host "[+] '$SrvName' nach '$ouDN' verschoben."
gpupdate /force