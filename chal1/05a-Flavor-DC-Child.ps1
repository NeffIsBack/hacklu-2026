<#
    Phase 5a: FLAVOR fuer old.velocity.hacklu (Granite - aufgekaufte Firma).
    Auf DC-OLD als OLD\Administrator ausfuehren. Idempotent, additiv.

    TONALITAET: Granite ist die alte Firma -> Beschreibungen bewusst knapp,
    konservativ, buerokratisch (wie aus einem Aktenordner). Hints in ENGLISCH.
    Ruehrt svc_granite_sync, svc_test und die Angriffskette NICHT an.
#>

# ===================== KONFIG =====================
$Domain  = 'old.velocity.hacklu'
$Base    = 'DC=old,DC=velocity,DC=hacklu'
$OUName  = 'Granite Staff'
$Company = 'Granite Industries'
$Pw      = 'Fl@vor-Lab-2026!xZ'
# ==================================================

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

if (-not (Get-ADOrganizationalUnit -Server $Domain -Filter "Name -eq '$OUName'" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name $OUName -Path $Base -Server $Domain -ProtectedFromAccidentalDeletion $false
    Write-Host "[*] OU '$OUName' angelegt." -ForegroundColor Cyan
}
$OU = "OU=$OUName,$Base"

# Granite: trockene, aktenhafte Beschreibungen. Die drei Hint-Zeilen (d.koch,
# o.fuchs, w.brandt) bleiben sachlich und unaufgeregt.
$users = @(
  @{Sam='w.brandt';  G='Werner';   S='Brandt';  T='Managing Director';     D='Management';  En=$true;  Desc='Managing Director. Employed since 1987. Signing authority per bylaws.'}
  @{Sam='i.falk';    G='Ingrid';   S='Falk';    T='Head of Finance';       D='Finance';     En=$true;  Desc='Head of Finance. Responsible for general ledger and annual accounts.'}
  @{Sam='d.koch';    G='Dieter';   S='Koch';    T='System Administrator';  D='IT';          En=$true;  Desc='Administers the Granite domain. Handover to Velocity IT pending.'}
  @{Sam='p.lang';    G='Petra';    S='Lang';    T='Head of Personnel';     D='Personnel';   En=$true;  Desc='Head of Personnel department. Processes employment records.'}
  @{Sam='k.simon';   G='Karl';     S='Simon';   T='Technical Director';    D='Engineering'; En=$true;  Desc='Technical Director. Oversees production and maintenance.'}
  @{Sam='u.beck';    G='Ursula';   S='Beck';    T='Accountant';            D='Finance';     En=$true;  Desc='Accounts payable and receivable. Desk 2, second floor.'}
  @{Sam='h.vogel';   G='Horst';    S='Vogel';   T='Sales Representative';  D='Sales';       En=$true;  Desc='Field sales, southern region. Company car assigned.'}
  @{Sam='r.boehm';   G='Renate';   S='Boehm';   T='Clerk';                 D='Personnel';   En=$true;  Desc='Payroll clerk. Works part-time (Mon-Wed).'}
  @{Sam='g.walter';  G='Gerd';     S='Walter';  T='Warehouse Manager';     D='Logistics';   En=$true;  Desc='Warehouse and dispatch. Key holder, building C.'}
  @{Sam='m.ernst';   G='Monika';   S='Ernst';   T='Executive Assistant';   D='Management';  En=$true;  Desc='Assistant to the Managing Director. Handles correspondence.'}
  @{Sam='j.hahn';    G='Juergen';  S='Hahn';    T='Technician';            D='Engineering'; En=$true;  Desc='Maintenance technician. On-call rotation.'}
  @{Sam='o.fuchs';   G='Otto';     S='Fuchs';   T='IT Support';            D='IT';          En=$true;  Desc='Helpdesk. Creates and maintains migration test accounts.'}
  @{Sam='h.scholz';  G='Helga';    S='Scholz';  T='Receptionist';          D='Administration'; En=$true; Desc='Front desk and switchboard. Office hours 08:00-16:00.'}
  @{Sam='r.peters';  G='Rolf';     S='Peters';  T='Purchaser';             D='Procurement'; En=$true;  Desc='Procurement. Approves orders up to EUR 5,000.'}
  @{Sam='s.arnold';  G='Sabine';   S='Arnold';  T='Sales Representative';  D='Sales';       En=$false; Desc='Left the company following the acquisition.'}
  @{Sam='e.sommer';  G='Erika';    S='Sommer';  T='Controller';            D='Finance';     En=$false; Desc='Left the company following the acquisition.'}
)

foreach ($u in $users) {
    if (-not (Get-ADUser -Server $Domain -Filter "SamAccountName -eq '$($u.Sam)'" -ErrorAction SilentlyContinue)) {
        New-ADUser -Server $Domain -Path $OU `
            -Name "$($u.G) $($u.S)" -SamAccountName $u.Sam `
            -GivenName $u.G -Surname $u.S -DisplayName "$($u.G) $($u.S)" `
            -UserPrincipalName "$($u.Sam)@$Domain" `
            -Title $u.T -Department $u.D -Company $Company -Description $u.Desc `
            -AccountPassword (ConvertTo-SecureString $Pw -AsPlainText -Force) `
            -Enabled $u.En
        Write-Host "  + $($u.Sam)" -ForegroundColor Green
    }
}


Write-Host "`n[fertig] Granite-Flavor angelegt." -ForegroundColor Yellow