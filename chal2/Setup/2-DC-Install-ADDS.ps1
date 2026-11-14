# ============================================================
#  DC - Schritt 2: AD DS + Forest-Promotion
# ============================================================

# ==== Configuration ====
$DomainFqdn    = 'agile-corp.hacklu'
$DomainNetbios = 'AGILE-CORP'
$DsrmPassword  = 'c3PXFKV6x44FsM4p'
# =======================

$ErrorActionPreference = 'Stop'

Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools | Out-Null
Import-Module ADDSDeployment

$dsrm = ConvertTo-SecureString $DsrmPassword -AsPlainText -Force
Install-ADDSForest `
    -DomainName                    $DomainFqdn `
    -DomainNetbiosName             $DomainNetbios `
    -ForestMode                    WinThreshold `
    -DomainMode                    WinThreshold `
    -InstallDns `
    -SafeModeAdministratorPassword $dsrm `
    -NoRebootOnCompletion:$false `
    -Force