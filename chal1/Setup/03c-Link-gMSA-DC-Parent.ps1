<#
    Phase 3c: gMSA (Parent) mit der Child-Gruppe verknuepfen
#>

# ===================== CONFIG =====================
$ParentDomain = 'velocity.hacklu'
$ChildDomain  = 'old.velocity.hacklu'
$GmsaName     = 'svc_backup_gmsa'
$GroupSam     = 'ServiceAccounts'
# ==================================================

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$childGroup = Get-ADGroup -Server $ChildDomain -Identity $GroupSam
Write-Host "[*] Child-Gruppe: $($childGroup.DistinguishedName)" -ForegroundColor Cyan

# --- gMSA auf die Child-Gruppe berechtigen ---
$sid   = New-Object System.Security.Principal.SecurityIdentifier($childGroup.SID)
$sddl  = "O:BAG:BAD:(A;;0xf01ff;;;$($sid.Value))"
$rsd   = New-Object System.Security.AccessControl.RawSecurityDescriptor($sddl)
$bytes = New-Object byte[] ($rsd.BinaryLength)
$rsd.GetBinaryForm($bytes, 0)

$gmsaDn = (Get-ADServiceAccount -Identity $GmsaName).DistinguishedName
Set-ADObject -Identity $gmsaDn -Replace @{ 'msDS-GroupMSAMembership' = $bytes }
Write-Host "[*] '$GmsaName' ist jetzt fuer '$GroupSam' ($ChildDomain) lesbar." -ForegroundColor Green
