<#
    Phase 6: Passwort-Rotation in old.velocity.hacklu
#>

# ===================== CONFIG =====================
$Domain              = 'old.velocity.hacklu'

$RotateAdministrator = $true
$NewAdminPassword    = 'KPLewbdd5piHs3YD'

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
