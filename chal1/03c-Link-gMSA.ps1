<#
    Phase 3c: gMSA (Parent) mit der Child-Gruppe verknuepfen - der Cross-Domain-Kern.
    Auf DC-NEW ausfuehren, angemeldet als VELOCITY\Administrator. Idempotent.
    Setzt PrincipalsAllowedToRetrieveManagedPassword von svc_backup_gmsa
    auf die Universal-Gruppe ServiceAccounts der Child-Domain.
    Voraussetzung: 03b ist gelaufen (Child-Gruppe existiert).
#>

# ===================== KONFIG =====================
$ParentDomain = 'velocity.hacklu'
$ChildDomain  = 'old.velocity.hacklu'
$GmsaName     = 'svc_backup_gmsa'
$GroupSam     = 'ServiceAccounts'
# ==================================================

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

# --- Child-Gruppe cross-domain holen ---
$childGroup = Get-ADGroup -Server $ChildDomain -Identity $GroupSam
Write-Host "[*] Child-Gruppe: $($childGroup.DistinguishedName)" -ForegroundColor Cyan

# --- gMSA auf die Child-Gruppe berechtigen ---
# -PrincipalsAllowedToRetrieveManagedPassword loest den Principal NUR in der
# Domaene des Ziel-DCs auf und findet eine CHILD-SID nicht ("... under
# DC=velocity,DC=hacklu"). Wir schreiben msDS-GroupMSAMembership daher direkt
# als Security Descriptor mit der Child-Gruppen-SID - das umgeht die Aufloesung.
$sid   = New-Object System.Security.Principal.SecurityIdentifier($childGroup.SID)
$sddl  = "O:BAG:BAD:(A;;0xf01ff;;;$($sid.Value))"
$rsd   = New-Object System.Security.AccessControl.RawSecurityDescriptor($sddl)
$bytes = New-Object byte[] ($rsd.BinaryLength)
$rsd.GetBinaryForm($bytes, 0)

$gmsaDn = (Get-ADServiceAccount -Identity $GmsaName).DistinguishedName
Set-ADObject -Identity $gmsaDn -Replace @{ 'msDS-GroupMSAMembership' = $bytes }
Write-Host "[*] '$GmsaName' ist jetzt fuer '$GroupSam' ($ChildDomain) lesbar." -ForegroundColor Green

# --- Vorsorgliche Bereinigung alter, im Parent falsch platzierter Artefakte ---
$oldGrp = Get-ADGroup -Server $ParentDomain -Filter "SamAccountName -eq '$GroupSam'" -ErrorAction SilentlyContinue
if ($oldGrp) { Remove-ADGroup -Identity $oldGrp -Confirm:$false; Write-Host "[*] Alte Parent-Gruppe entfernt." -ForegroundColor Yellow }
$oldUsr = Get-ADUser -Server $ParentDomain -Filter "SamAccountName -eq 'svc_granite_sync'" -ErrorAction SilentlyContinue
if ($oldUsr) { Remove-ADUser -Identity $oldUsr -Confirm:$false; Write-Host "[*] Alter Parent-User entfernt." -ForegroundColor Yellow }

# --- Verifikation (rohe SD lesen -> keine Namensaufloesung noetig) ---
Write-Host "`n[verify] Erlaubte SID(s) in msDS-GroupMSAMembership:" -ForegroundColor Cyan
try {
    $v = (Get-ADObject -Identity $gmsaDn -Properties 'msDS-GroupMSAMembership').'msDS-GroupMSAMembership'
    if     ($v -is [byte[]]) { $sdBytes = $v }
    elseif ($v -is [System.DirectoryServices.ActiveDirectorySecurity]) { $sdBytes = $v.GetSecurityDescriptorBinaryForm() }
    else   { $sdBytes = [byte[]]$v[0] }
    $chk = New-Object System.Security.AccessControl.RawSecurityDescriptor($sdBytes, 0)
    $chk.DiscretionaryAcl | ForEach-Object { Write-Host "   $($_.SecurityIdentifier.Value)" }
    Write-Host "[i] Child-Gruppe '$GroupSam' hat SID: $($sid.Value)" -ForegroundColor DarkGray
} catch {
    Write-Host "[i] Verifikation uebersprungen ($($_.Exception.Message)). Das Setzen war erfolgreich." -ForegroundColor DarkGray
}