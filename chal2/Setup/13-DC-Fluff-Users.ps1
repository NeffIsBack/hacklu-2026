# ============================================================
#  DC - Schritt 8: Unternehmensstruktur + 25 Mitarbeiter
# ============================================================

# ==== Configuration ====
$DefaultPassword = '1!k4jas123oiajh'
$Domain          = 'agile-corp.hacklu'
$DomainNetbios   = 'AGILE-CORP'
# =======================

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$domainDN = (Get-ADDomain).DistinguishedName
$pw       = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force

# --- OU-Struktur -----------------------------------------------------
$ous = @('Management','Product','Engineering','QA','HR')
foreach ($ou in $ous) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -SearchBase $domainDN -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou -Path "OU=Users,$domainDN" -ProtectedFromAccidentalDeletion $false -ErrorAction SilentlyContinue
    }
}
# Users-Root-OU anlegen falls noch nicht da
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'Users'" -SearchBase $domainDN -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name 'Users' -Path $domainDN -ProtectedFromAccidentalDeletion $false
}
foreach ($ou in $ous) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -SearchBase "OU=Users,$domainDN" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou -Path "OU=Users,$domainDN" -ProtectedFromAccidentalDeletion $false
    }
}
Write-Host "[+] OU-Struktur: Users/{$($ous -join ',')}"

# --- Mitarbeiterliste ------------------------------------------------
# Format: Sam, Vorname, Nachname, Titel, OU, Beschreibung

$users = @(
    # === Management ===
    # Jeff Scrumley  ->  Scrum
    @{ Sam='jeff.scrumley';      First='Jeff';      Last='Scrumley';      Title='Chief Executive Officer';        OU='Management'; Desc='Living the agile dream since 2008' },
    # Patricia Burndown  ->  Burndown Chart
    @{ Sam='patricia.burndown';  First='Patricia';  Last='Burndown';      Title='Chief Financial Officer';        OU='Management'; Desc='Always trending downward' },
    # Aiden Kanban  ->  Kanban
    @{ Sam='aiden.kanban';       First='Aiden';     Last='Kanban';        Title='Chief Technology Officer';       OU='Management'; Desc='WIP limit: 1 (himself)' },
    # Victoria Velocity  ->  Velocity
    @{ Sam='victoria.velocity';  First='Victoria';  Last='Velocity';      Title='VP of Engineering';              OU='Management'; Desc='Story points per sprint: classified' },
    # Marcus Sprint  ->  Sprint
    @{ Sam='marcus.sprint';      First='Marcus';    Last='Sprint';        Title='Chief Operating Officer';        OU='Management'; Desc='"This sprint will be different"' },

    # === Product ===
    # Philip Backlogg  ->  Backlog
    @{ Sam='philip.backlogg';    First='Philip';    Last='Backlogg';      Title='Head of Product';               OU='Product';    Desc='3000 items and growing' },
    # Stacey Holder  ->  Stakeholder
    @{ Sam='stacey.holder';      First='Stacey';    Last='Holder';        Title='Senior Product Manager';        OU='Product';    Desc='Has opinions about everything' },
    # Timothy Boxley  ->  Timebox
    @{ Sam='timothy.boxley';     First='Timothy';   Last='Boxley';        Title='Product Manager';               OU='Product';    Desc='Time is a flat circle' },
    # Barry Cade  ->  Barricade / Backlog
    @{ Sam='barry.cade';         First='Barry';     Last='Cade';          Title='Product Owner';                 OU='Product';    Desc='Blocking since Q1 2019' },
    # Max MVP  ->  Minimum Viable Product
    @{ Sam='max.mvp';            First='Max';       Last='MVP';           Title='Director of Sales';             OU='Product';    Desc='Minimum viable effort, maximum viable title' },

    # === Engineering ===
    # Stan Dupp  ->  Standup
    @{ Sam='stan.dupp';          First='Stan';      Last='Dupp';          Title='Senior Software Engineer';      OU='Engineering'; Desc='Joins every standup 2 min late' },
    # Michael Roservice  ->  Microservice
    @{ Sam='michael.roservice';  First='Michael';   Last='Roservice';     Title='Backend Engineer';              OU='Engineering'; Desc='Split everything into 47 services' },
    # Eric Epicson  ->  Epic
    @{ Sam='eric.epicson';       First='Eric';      Last='Epicson';       Title='Frontend Engineer';             OU='Engineering'; Desc='Every ticket is an epic' },
    # Spike Storrington  ->  Spike + Story
    @{ Sam='spike.storrington';  First='Spike';     Last='Storrington';   Title='Software Engineer';             OU='Engineering'; Desc='3-day spike on a 1-point story' },
    # Al Burnham  ->  Burndown
    @{ Sam='al.burnham';         First='Al';        Last='Burnham';       Title='Software Engineer';             OU='Engineering'; Desc='Chart goes up, not down' },
    # Rich Refactori  ->  Refactor
    @{ Sam='rich.refactori';     First='Rich';      Last='Refactori';     Title='Senior Software Engineer';      OU='Engineering'; Desc='Refactoring since 1997, shipping never' },
    # Devon Opsworth  ->  DevOps
    @{ Sam='devon.opsworth';     First='Devon';     Last='Opsworth';      Title='DevOps Engineer';               OU='Engineering'; Desc='It works on my machine' },
    # Monika Pairing  ->  Pair Programming
    @{ Sam='monika.pairing';     First='Monika';    Last='Pairing';       Title='Software Engineer';             OU='Engineering'; Desc='Navigator in search of a driver' },

    # === Scrum / Agile Coaches ===
    # Donna Finley  ->  Definition of Done  (Don-a Fin-ley)
    @{ Sam='donna.finley';       First='Donna';     Last='Finley';        Title='Agile Coach';                   OU='Engineering'; Desc='Nobody agrees on what done means' },
    # Sara Retro  ->  Retrospective
    @{ Sam='sara.retro';         First='Sara';      Last='Retro';         Title='Scrum Master';                  OU='Engineering'; Desc='What went well: nothing. Again.' },
    # Vince Ceremony  ->  Agile Ceremonies
    @{ Sam='vince.ceremony';     First='Vince';     Last='Ceremony';      Title='Scrum Master';                  OU='Engineering'; Desc='Scheduled 11 meetings to discuss meeting cadence' },

    # === QA ===
    # Tessa Regression  ->  Regression Testing
    @{ Sam='tessa.regression';   First='Tessa';     Last='Regression';    Title='QA Engineer';                   OU='QA';          Desc='Found 47 regressions this sprint' },
    # Wendy Acceptance  ->  Acceptance Testing
    @{ Sam='wendy.acceptance';   First='Wendy';     Last='Acceptance';    Title='Test Automation Engineer';      OU='QA';          Desc='Accepts nothing' },

    # === HR ===
    # Chad Lowfruit  ->  Low-Hanging Fruit
    @{ Sam='chad.lowfruit';      First='Chad';      Last='Lowfruit';      Title='HR Manager';                    OU='HR';          Desc='Picking it since the company was founded' },
    # Karla Impedimenta  ->  Impediment
    @{ Sam='karla.impedimenta';  First='Karla';     Last='Impedimenta';   Title='HR Business Partner';           OU='HR';          Desc='Raised as impediment, closed as wontfix' }
)

# --- Benutzer anlegen ------------------------------------------------
$created = 0; $skipped = 0
foreach ($u in $users) {
    $ouPath = "OU=$($u.OU),OU=Users,$domainDN"
    $upn    = "$($u.Sam)@$Domain"

    if (Get-ADUser -Filter "SamAccountName -eq '$($u.Sam)'" -ErrorAction SilentlyContinue) {
        $skipped++; continue
    }

    New-ADUser `
        -SamAccountName       $u.Sam `
        -UserPrincipalName    $upn `
        -GivenName            $u.First `
        -Surname              $u.Last `
        -Name                 "$($u.First) $($u.Last)" `
        -DisplayName          "$($u.First) $($u.Last)" `
        -Title                $u.Title `
        -Description          $u.Desc `
        -Department           $u.OU `
        -Company              'Agile Corp' `
        -Path                 $ouPath `
        -AccountPassword      $pw `
        -Enabled              $true `
        -PasswordNeverExpires $true

    $created++
}

Write-Host "[+] $created Benutzer angelegt."