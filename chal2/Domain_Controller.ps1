param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Promote', 'Configure')]
    [string]$Stage,
    [SecureString]$SafeModePassword,
    [SecureString]$DeploymentPassword
)

$ErrorActionPreference = 'Stop'

if ($Stage -eq 'Promote') {
    if ($env:COMPUTERNAME -ne 'DC01') {
        Rename-Computer -NewName 'DC01' -Restart
        return
    }
    if ((Get-CimInstance Win32_ComputerSystem).DomainRole -ge 4) {
        return
    }

    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools | Out-Null
    if (-not $SafeModePassword) {
        $SafeModePassword = Read-Host 'DSRM password' -AsSecureString
    }
    Install-ADDSForest -DomainName 'hack.lu' -InstallDNS -SafeModeAdministratorPassword $SafeModePassword -Force
    return
}

Import-Module ActiveDirectory, GroupPolicy, DnsServer
if (-not $DeploymentPassword) {
    $DeploymentPassword = Read-Host 'svc_mdt password' -AsSecureString
}

# Domain user recovered from the deployment share
$BaseDn = (Get-ADDomain -Identity 'hack.lu').DistinguishedName
if (Get-ADUser -Identity 'svc_mdt' -ErrorAction SilentlyContinue) {
    Set-ADAccountPassword -Identity 'svc_mdt' -NewPassword $DeploymentPassword -Reset
    Set-ADUser -Identity 'svc_mdt' -Enabled $true -PasswordNeverExpires $true -ChangePasswordAtLogon $false
} else {
    New-ADUser -Name 'MDT Deployment' -SamAccountName 'svc_mdt' -AccountPassword $DeploymentPassword -Enabled $true -PasswordNeverExpires $true -ChangePasswordAtLogon $false -Path "CN=Users,$BaseDn"
}

# Editable GPO scoped to the deployment server
$ServerOu = "OU=Deployment Servers,$BaseDn"
if (-not (Get-ADOrganizationalUnit -Identity $ServerOu -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name 'Deployment Servers' -Path $BaseDn -ProtectedFromAccidentalDeletion $false
}
if (-not (Get-GPO -Name 'Deployment Server Management' -ErrorAction SilentlyContinue)) {
    New-GPO -Name 'Deployment Server Management' | Out-Null
}
if (-not ((Get-GPInheritance -Target $ServerOu).GpoLinks | Where-Object DisplayName -eq 'Deployment Server Management')) {
    New-GPLink -Name 'Deployment Server Management' -Target $ServerOu | Out-Null
}
Set-GPPermission -Name 'Deployment Server Management' -TargetName 'svc_mdt' -TargetType User -PermissionLevel GpoEdit -Replace | Out-Null

# Enterprise CA and the machine-enrollable server certificate template
if (-not (Get-WindowsFeature ADCS-Cert-Authority).Installed) {
    Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools | Out-Null
}
if (-not (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\hack-DC01-CA')) {
    Install-AdcsCertificationAuthority -CAType EnterpriseRootCA -CACommonName 'hack-DC01-CA' -CryptoProviderName 'RSA#Microsoft Software Key Storage Provider' -KeyLength 2048 -HashAlgorithmName SHA256 -ValidityPeriod Years -ValidityPeriodUnits 10 -Force | Out-Null
}

$ConfigurationDn = (Get-ADRootDSE).configurationNamingContext
$TemplateDn = "CN=WebServer,CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigurationDn"
$TemplateAcl = Get-Acl "AD:\$TemplateDn"
$ComputerSid = (Get-ADGroup 'Domain Computers').SID
$TemplateAcl.AddAccessRule([System.DirectoryServices.ActiveDirectoryAccessRule]::new($ComputerSid, [System.DirectoryServices.ActiveDirectoryRights]::GenericRead, [System.Security.AccessControl.AccessControlType]::Allow))
$TemplateAcl.AddAccessRule([System.DirectoryServices.ActiveDirectoryAccessRule]::new($ComputerSid, [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight, [System.Security.AccessControl.AccessControlType]::Allow, [Guid]'0e10c968-78fb-11d2-90d4-00c04f79dc55'))
Set-Acl -Path "AD:\$TemplateDn" -AclObject $TemplateAcl

$CaDn = "CN=hack-DC01-CA,CN=Enrollment Services,CN=Public Key Services,CN=Services,$ConfigurationDn"
if ('WebServer' -notin (Get-ADObject -Identity $CaDn -Properties certificateTemplates).certificateTemplates) {
    Set-ADObject -Identity $CaDn -Add @{ certificateTemplates = 'WebServer' }
    Restart-Service CertSvc
}

# The WSUS computer exists only in AD and DNS
if (-not (Get-ADComputer -Identity 'WSUS' -ErrorAction SilentlyContinue)) {
    New-ADComputer -Name 'WSUS' -SamAccountName 'WSUS$' -DNSHostName 'wsus.hack.lu' -Path "CN=Computers,$BaseDn" -Enabled $true
}
if (-not (Get-DnsServerZone -Name 'wsus.hack.lu' -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -Name 'wsus.hack.lu' -ReplicationScope Domain -DynamicUpdate NonsecureAndSecure | Out-Null
} else {
    Set-DnsServerPrimaryZone -Name 'wsus.hack.lu' -DynamicUpdate NonsecureAndSecure | Out-Null
}
if (-not (Get-DnsServerResourceRecord -ZoneName 'wsus.hack.lu' -Name '@' -RRType A -ErrorAction SilentlyContinue)) {
    Add-DnsServerResourceRecordA -ZoneName 'wsus.hack.lu' -Name '@' -IPv4Address '192.0.2.10' -AllowUpdateAny -TimeToLive (New-TimeSpan -Seconds 30)
}

# The DC checks the HTTPS WSUS endpoint every minute
$UpdatePolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
New-Item -Path $UpdatePolicy -Force | Out-Null
New-Item -Path "$UpdatePolicy\AU" -Force | Out-Null
New-ItemProperty -Path $UpdatePolicy -Name WUServer -Value 'https://wsus.hack.lu:8531' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $UpdatePolicy -Name WUStatusServer -Value 'https://wsus.hack.lu:8531' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $UpdatePolicy -Name DoNotConnectToWindowsUpdateInternetLocations -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path "$UpdatePolicy\AU" -Name UseWUServer -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path "$UpdatePolicy\AU" -Name NoAutoUpdate -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path "$UpdatePolicy\AU" -Name AUOptions -Value 4 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path "$UpdatePolicy\AU" -Name ScheduledInstallDay -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path "$UpdatePolicy\AU" -Name ScheduledInstallTime -Value 3 -PropertyType DWord -Force | Out-Null

$UpdateCommand = @'
$searcher = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher()
$searcher.ServerSelection = 1
$searcher.Online = $true
try {
    $null = $searcher.Search("IsInstalled=0 and Type='Software'")
} finally {
    (New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()
}
'@
Register-ScheduledTask -TaskName 'WSUS Detect Every Minute' -Action (New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-NoProfile -NonInteractive -EncodedCommand $([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($UpdateCommand)))") -Trigger (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)) -Settings (New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Seconds 55)) -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
