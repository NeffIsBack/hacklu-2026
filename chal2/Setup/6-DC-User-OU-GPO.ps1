# ============================================================
#  DC - Schritt 6: Deploy-User + OU + verwundbare GPO
# ============================================================

# ==== Configuration ====
$UserSam     = 'svc_deploy'
$UserDisplay = 'WDS Deployment Service'
$UserUpn     = 'svc_deploy@agile-corp.hacklu'
$UserPass    = 'D3pl0y!_AgileCorp'
$OuName      = 'Servers'
$GpoName     = 'SRV-Baseline'
$RefreshMin  = 5
# =======================

$ErrorActionPreference = 'Stop'
if (-not (Get-WindowsFeature GPMC).Installed) { Install-WindowsFeature GPMC | Out-Null }
Import-Module ActiveDirectory
Import-Module GroupPolicy

$domainDN = (Get-ADDomain).DistinguishedName
$ouDN     = "OU=$OuName,$domainDN"

# --- 1) User ---------------------------------------------------------
if (-not (Get-ADUser -Filter "SamAccountName -eq '$UserSam'" -ErrorAction SilentlyContinue)) {
    New-ADUser -Name $UserDisplay -SamAccountName $UserSam -UserPrincipalName $UserUpn `
        -AccountPassword (ConvertTo-SecureString $UserPass -AsPlainText -Force) `
        -Enabled $true -PasswordNeverExpires $true -Description 'WDS/Deployment service account'
    Write-Host "[+] User '$UserSam' angelegt."
} else { Write-Host "[=] User '$UserSam' existiert bereits." }

# --- 2) OU -----------------------------------------------------------
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$OuName'" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name $OuName -Path $domainDN -ProtectedFromAccidentalDeletion $false
    Write-Host "[+] OU '$ouDN' angelegt."
} else { Write-Host "[=] OU '$ouDN' existiert bereits." }

# --- 3) GPO + Link ---------------------------------------------------
if (-not (Get-GPO -Name $GpoName -ErrorAction SilentlyContinue)) {
    New-GPO -Name $GpoName -Comment 'Server baseline policy' | Out-Null
    Write-Host "[+] GPO '$GpoName' angelegt."
} else { Write-Host "[=] GPO '$GpoName' existiert bereits." }
try { New-GPLink -Name $GpoName -Target $ouDN -LinkEnabled Yes -ErrorAction Stop | Out-Null
      Write-Host "[+] GPO an '$ouDN' verknuepft." }
catch { Write-Host "[=] GPO-Link vermutlich bereits vorhanden." }

# --- 4) GP-Refresh 5 min -------------------------------
$sysKey = 'HKLM\Software\Policies\Microsoft\Windows\System'
Set-GPRegistryValue -Name $GpoName -Key $sysKey -ValueName 'GroupPolicyRefreshTime'       -Type DWord -Value $RefreshMin | Out-Null
Set-GPRegistryValue -Name $GpoName -Key $sysKey -ValueName 'GroupPolicyRefreshTimeOffset' -Type DWord -Value 0          | Out-Null
Write-Host "[+] GP-Refresh fuer SRV = $RefreshMin min."

# --- 5) MISCONFIG: Edit-Delegation an svc_deploy ---------------------
Set-GPPermission -Name $GpoName -TargetName $UserSam -TargetType User `
    -PermissionLevel GpoEditDeleteModifySecurity -Replace | Out-Null
