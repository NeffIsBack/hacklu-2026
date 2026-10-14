<#
    Phase 6: Passwort-Rotation in old.velocity.hacklu (Story: "alle Passwoerter
    rotiert, nur krbtgt noch gueltig").
    Auf DC-OLD als OLD\Administrator ausfuehren. Idempotent (random reset).

    MACHT DIE LIVE-HASHES ANDERS ALS DIE IN DER EXPORTIERTEN ntds.dit, damit aus
    dem Export nur noch der krbtgt-Hash nutzbar ist.

    >>> VORAUSSETZUNG <<<
    - Die ntds.dit in Backup$\Export existiert BEREITS (vor der Rotation).
    - Nach dieser Rotation den Export NICHT neu ziehen (sonst Twist kaputt).
    - Snapshot der VM VORHER empfohlen.

    HART AUSGESCHLOSSEN (werden NIE rotiert):
      krbtgt            -> Export-krbtgt muss == Live bleiben (Golden Ticket)
      svc_test          -> Foothold-Passwort (= Username) muss bleiben
      svc_granite_sync  -> Kerberoast-Crack (Granite2021) muss bleiben
      svc_backup_gmsa   -> gMSA (managed), nie anfassen
      Guest             -> deaktiviert, egal
#>

# ===================== KONFIG =====================
$Domain              = 'old.velocity.hacklu'

# Administrator wird rotiert (schliesst den PtH-Shortcut aus dem Export),
# bekommt aber ein BEKANNTES neues Passwort, damit du weiter Zugriff hast.
$RotateAdministrator = $true
$NewAdminPassword    = 'KPLewbdd5piHs3ZD'   # <-- ab jetzt das Live-Admin-PW!

$Protect = @('krbtgt','svc_test','svc_granite_sync','svc_backup_gmsa','Guest')
# ==================================================
 
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
 
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw "Bitte in einer erhoehten (Administrator) PowerShell ausfuehren." }
 
Write-Host "[!] Erinnerung: Export muss bereits existieren und wird danach NICHT neu gezogen." -ForegroundColor Yellow
 
$rotated = 0; $skipped = @()
function New-RandomPw { ([guid]::NewGuid().ToString('N') + 'Aa1!') }
 
foreach ($u in (Get-ADUser -Server $Domain -Filter * )) {
    $sam = $u.SamAccountName
 
    # Trust-/Maschinenkonten (enden auf '$') NIE anfassen. z.B. VELOCITY$ ist
    # das Interdomain-Trust-Konto zum Parent - ein Reset wuerde den Trust und
    # damit den SID-History-Angriff zerstoeren.
    if ($sam -like '*$') { $skipped += $sam; continue }
 
    if ($sam -eq 'Administrator') {
        if ($RotateAdministrator) {
            Set-ADAccountPassword -Server $Domain -Identity $sam -Reset `
                -NewPassword (ConvertTo-SecureString $NewAdminPassword -AsPlainText -Force)
            Write-Host "  ~ Administrator -> NEUES bekanntes PW: $NewAdminPassword" -ForegroundColor Magenta
            $rotated++
        } else { $skipped += $sam }
        continue
    }
 
    if ($Protect -contains $sam) { $skipped += $sam; continue }
 
    Set-ADAccountPassword -Server $Domain -Identity $sam -Reset `
        -NewPassword (ConvertTo-SecureString (New-RandomPw) -AsPlainText -Force)
    $rotated++
    Write-Host "  ~ rotiert: $sam" -ForegroundColor DarkGray
}
 
Write-Host "`n[fertig] Rotiert: $rotated Konten." -ForegroundColor Green
Write-Host "        Ausgeschlossen (bewusst): $($skipped -join ', ')" -ForegroundColor Yellow
if ($RotateAdministrator) {
    Write-Host "        >>> OLD\Administrator meldet sich ab jetzt mit: $NewAdminPassword <<<" -ForegroundColor Magenta
}
