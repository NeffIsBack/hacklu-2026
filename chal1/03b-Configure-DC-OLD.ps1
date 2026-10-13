<#
    Phase 3b: "Legitime" Child-Objekte in old.velocity.hacklu anlegen.
    Auf DC-OLD ausfuehren, angemeldet als OLD\Administrator
    (Passwort = LocalAdminPassword aus 03a). Idempotent.

    Enthaelt:
      - Universal-Gruppe ServiceAccounts (SID landet forest-weit im Token)
      - kerberoastbaren svc_granite_sync (mit SPN, BEWUSST crackbarem Passwort)
      - ein paar Mitarbeiter-User als Population fuer die RID-Enumeration
    KDS Root Key wird NICHT erneut angelegt - der ist forest-weit (siehe 02b).
    Die eigentlichen Foothold-Schwaechungen (anonyme Enumeration,
    username=password) kommen spaeter in der Vulnerability-Phase.
#>

# ===================== KONFIG =====================
$Domain    = 'old.velocity.hacklu'
$UsersPath = 'CN=Users,DC=old,DC=velocity,DC=hacklu'

# BEWUSST SCHWACH - muss in einer Wordlist crackbar sein:
$SvcGranitePassword = 'Granite2021'
# Normale Mitarbeiter - darf stark sein:
$UserPassword       = 'Str0ng-Lab-P@ss-2026!'

$Employees = @(
    @{ Sam='m.becker';   Name='Marie Becker' }
    @{ Sam='t.hoffmann'; Name='Tobias Hoffmann' }
    @{ Sam='s.klein';    Name='Sabine Klein' }
    @{ Sam='j.wagner';   Name='Jonas Wagner' }
    @{ Sam='l.schulz';   Name='Lena Schulz' }
    @{ Sam='f.richter';  Name='Felix Richter' }
    @{ Sam='a.neumann';  Name='Anna Neumann' }
)
# ==================================================

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

# --- Universal-Gruppe ---
if (-not (Get-ADGroup -Server $Domain -Filter "SamAccountName -eq 'ServiceAccounts'" -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Erstelle Gruppe 'Service Accounts' (Universal) ..." -ForegroundColor Cyan
    New-ADGroup -Name "Service Accounts" -SamAccountName "ServiceAccounts" `
        -GroupScope Universal -GroupCategory Security `
        -Path $UsersPath -Server $Domain `
        -Description "Service identities for various tasks"
} else { Write-Host "[*] Gruppe 'ServiceAccounts' existiert bereits." -ForegroundColor DarkGray }

# --- kerberoastbarer Account MIT SPN ---
if (-not (Get-ADUser -Server $Domain -Filter "SamAccountName -eq 'svc_granite_sync'" -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Erstelle svc_granite_sync (SPN, schwaches Passwort) ..." -ForegroundColor Cyan
    New-ADUser -Name "svc_granite_sync" -SamAccountName "svc_granite_sync" `
        -UserPrincipalName "svc_granite_sync@$Domain" `
        -AccountPassword (ConvertTo-SecureString $SvcGranitePassword -AsPlainText -Force) `
        -ServicePrincipalNames @("MSSQLSvc/svc_granite_sync.$Domain:1433") `
        -Enabled $true -PasswordNeverExpires $true -Server $Domain `
        -OtherAttributes @{ 'msDS-SupportedEncryptionTypes' = 4 } `
        -Description "Legacy Granite backup sync account - TEMPORARY, remove after migration (2021)"
} else { Write-Host "[*] svc_granite_sync existiert bereits." -ForegroundColor DarkGray }

Add-ADGroupMember -Server $Domain -Identity "ServiceAccounts" -Members "svc_granite_sync" -ErrorAction SilentlyContinue

# --- Mitarbeiter-User (Population fuer RID-Enumeration) ---
foreach ($e in $Employees) {
    if (-not (Get-ADUser -Server $Domain -Filter "SamAccountName -eq '$($e.Sam)'" -ErrorAction SilentlyContinue)) {
        New-ADUser -Name $e.Name -SamAccountName $e.Sam `
            -UserPrincipalName "$($e.Sam)@$Domain" `
            -AccountPassword (ConvertTo-SecureString $UserPassword -AsPlainText -Force) `
            -Enabled $true -Server $Domain
        Write-Host "[*] User angelegt: $($e.Sam)" -ForegroundColor Green
    }
}
Write-Host "`n[fertig] Child-Objekte stehen. Weiter mit 03c auf DC-NEW." -ForegroundColor Yellow