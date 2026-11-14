<#
    Phase 5b: FLAVOR fuer velocity.hacklu
#>

# ===================== KONFIG =====================
$Domain  = 'velocity.hacklu'
$Base    = 'DC=velocity,DC=hacklu'
$OUName  = 'Velocity Staff'
$Company = 'Velocity Industries'
$Pw      = 'Fl@vor-Lab-2026!xZ'
# ==================================================

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

if (-not (Get-ADOrganizationalUnit -Server $Domain -Filter "Name -eq '$OUName'" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name $OUName -Path $Base -Server $Domain -ProtectedFromAccidentalDeletion $false
    Write-Host "[*] OU '$OUName' angelegt." -ForegroundColor Cyan
}
$OU = "OU=$OUName,$Base"

# Velocity: "agile".
$users = @(
  @{Sam='c.vogt';      G='Claudia';  S='Vogt';      T='Chief Visionary Officer';        D='Leadership';     En=$true; Desc='Serial unicorn-whisperer disrupting legacy paradigms at scale. Eats roadmaps for breakfast. #founder-energy'}
  @{Sam='m.thiel';     G='Markus';   S='Thiel';     T='Chief Trust Evangelist';         D='Security';       En=$true; Desc='Zero-trust thought-leader weaponizing synergy to 10x our security posture. Breach-proof mindset, growth-hacking the threat landscape.'}
  @{Sam='a.krause';    G='Andreas';  S='Krause';    T='Head of Platform Velocity';      D='IT';             En=$true; Desc='Owns the Granite migration end-to-end. Also: cloud-native change-agent, rearchitecting tech debt into shareholder delight.'}
  @{Sam='n.schuster';  G='Nina';     S='Schuster';  T='Infrastructure Ninja';           D='IT';             En=$true; Desc='Maintains the backup server and the Granite AD export. Full-stack firefighter turning 3am pages into learnings.'}
  @{Sam='t.winkler';   G='Thomas';   S='Winkler';   T='Chief Value Architect';          D='Finance';        En=$true; Desc='Monetizing optionality and operationalizing EBITDA across the value-chain. Spreadsheets are my love language.'}
  @{Sam='l.boettcher'; G='Laura';    S='Boettcher'; T='People & Culture Alchemist';     D='People';         En=$true; Desc='Transforming humans into high-performing rockstar-families. Vibe-curator. Radical candor advocate.'}
  @{Sam='s.maier';     G='Sven';     S='Maier';     T='Threat-Hunting Growth Hacker';   D='Security';       En=$true; Desc='Proactively leaning into the kill-chain to delight our SOC stakeholders. Blue-team, but make it agile.'}
  @{Sam='k.albrecht';  G='Katrin';   S='Albrecht';  T='VP of Revenue Momentum';         D='Sales';          En=$true; Desc='Crushing quota while building authentic funnels of frictionless customer joy. ABC = Always Be Closing (synergistically).'}
  @{Sam='p.jung';      G='Philipp';  S='Jung';      T='DevOps Rockstar';                D='IT';             En=$true; Desc='Shifting left so hard we arrived yesterday. YAML poet, pipeline sommelier, kubernetes whisperer.'}
  @{Sam='j.kaiser';    G='Julia';    S='Kaiser';    T='Transformation Catalyst';        D='IT';             En=$true; Desc='Coordinates the Granite-to-Velocity merger. Agile at heart, holistic by design, impact-obsessed by choice.'}
  @{Sam='d.roth';      G='Daniel';   S='Roth';      T='Ledger Experience Lead';         D='Finance';        En=$true; Desc='Reimagining double-entry bookkeeping as a seamless customer journey. Reconciliation, but delightful.'}
  @{Sam='s.lorenz';    G='Sophie';   S='Lorenz';    T='Chief Storytelling Officer';     D='Brand';          En=$true; Desc='Crafting omnichannel narratives that move hearts, minds and KPIs. Brand is a feeling. The feeling is velocity.'}
  @{Sam='m.berg';      G='Michael';  S='Berg';      T='Head of Strategic Sourcing Synergy'; D='Procurement'; En=$true; Desc='Unlocking win-win-win supplier ecosystems. Negotiation is a team sport and I am the MVP.'}
  @{Sam='c.pohl';      G='Christine'; S='Pohl';     T='Executive Enablement Partner';   D='Leadership';     En=$true; Desc='Empowering C-suite superpowers through radical calendar synergy. Making the impossible merely late.'}
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

Write-Host "`n[fertig] Velocity-Flavor angelegt." -ForegroundColor Yellow