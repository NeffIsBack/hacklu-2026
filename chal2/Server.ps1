param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Join', 'Configure')]
    [string]$Stage,
    [string]$DcAddress,
    [pscredential]$DomainCredential,
    [securestring]$DeploymentPassword
)

$ErrorActionPreference = 'Stop'

if ($Stage -eq 'Join') {
    if (-not $DcAddress) { throw 'Join requires -DcAddress.' }

    # Rename first; run Join again after this reboot.
    if ($env:COMPUTERNAME -ne 'SRV02') {
        Rename-Computer -NewName 'SRV02' -Restart
        return
    }

    $adapters = @(Get-NetAdapter | Where-Object Status -eq 'Up')
    if ($adapters.Count -ne 1) { throw 'Join requires exactly one active network adapter.' }
    Set-DnsClientServerAddress -InterfaceIndex $adapters[0].InterfaceIndex -ServerAddresses $DcAddress

    $computer = Get-CimInstance Win32_ComputerSystem
    if ($computer.PartOfDomain) {
        if ($computer.Domain -ne 'hack.lu') { throw 'SRV02 is already joined to another domain.' }
        return
    }

    if (-not $DomainCredential) { $DomainCredential = Get-Credential -Message 'Account allowed to join SRV02 to hack.lu' }
    Add-Computer -DomainName 'hack.lu' -OUPath 'OU=Deployment Servers,DC=hack,DC=lu' -Credential $DomainCredential -Restart
    return
}

if ($env:COMPUTERNAME -ne 'SRV02' -or (Get-CimInstance Win32_ComputerSystem).Domain -ne 'hack.lu') {
    throw 'Run Configure on domain-joined SRV02.'
}
if (-not $DeploymentPassword) { $DeploymentPassword = Read-Host -AsSecureString 'Password for hack.lu\svc_mdt' }

# Stage the MDT-style files with one low-privilege domain credential.
$sharePath = Join-Path $env:SystemDrive 'DeploymentShare'
$controlPath = Join-Path $sharePath 'Control'
New-Item -ItemType Directory -Path $controlPath -Force | Out-Null
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($DeploymentPassword)
try {
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
}
if ($plainPassword -match '[\r\n]') { throw 'The deployment password cannot contain a newline.' }

[IO.File]::WriteAllText((Join-Path $controlPath 'Bootstrap.ini'), @"
[Settings]
Priority=Default

[Default]
DeployRoot=\\SRV02\DeploymentShare$
UserDomain=hack.lu
UserID=svc_mdt
UserPassword=$plainPassword
SkipBDDWelcome=YES
"@, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $controlPath 'CustomSettings.ini'), @'
[Settings]
Priority=Default

[Default]
OSInstall=Y
JoinDomain=hack.lu
MachineObjectOU=OU=Deployment Servers,DC=hack,DC=lu
'@, [Text.UTF8Encoding]::new($false))
Remove-Variable plainPassword

# Allow the built-in Guest account to read the share over the network.
$guest = Get-LocalUser | Where-Object { $_.SID.Value -like '*-501' }
Enable-LocalUser -SID $guest.SID
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'LimitBlankPasswordUse' -PropertyType DWord -Value 0 -Force | Out-Null
$policyPath = Join-Path $env:TEMP 'chal2-guest-rights.inf'
$databasePath = Join-Path $env:TEMP 'chal2-guest-rights.sdb'
secedit.exe /export /cfg $policyPath /areas USER_RIGHTS /quiet | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not export local network logon rights.' }

$policy = @(Get-Content -LiteralPath $policyPath -Encoding Unicode)
$guestSid = $guest.SID.Value
$policy = @($policy | ForEach-Object {
    if ($_ -match '^SeDenyNetworkLogonRight\s*=\s*(.*)$') {
        $entries = @($Matches[1] -split ',' | ForEach-Object { $_.Trim() } | Where-Object {
            $_.TrimStart('*') -notin @($guestSid, 'S-1-5-32-546')
        })
        'SeDenyNetworkLogonRight = ' + ($entries -join ',')
    } elseif ($_ -match '^SeNetworkLogonRight\s*=\s*(.*)$') {
        $entries = @($Matches[1] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ("*$guestSid" -notin $entries) { $entries += "*$guestSid" }
        'SeNetworkLogonRight = ' + ($entries -join ',')
    } else { $_ }
})
$policy | Set-Content -LiteralPath $policyPath -Encoding Unicode
secedit.exe /configure /db $databasePath /cfg $policyPath /overwrite /areas USER_RIGHTS /quiet | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not grant Guest network logon rights.' }

# Give Guest and null sessions the same read rights on SMB and NTFS.
$anonymousSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-7')
$administratorsSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
$guestName = $guest.SID.Translate([Security.Principal.NTAccount]).Value
$anonymousName = $anonymousSid.Translate([Security.Principal.NTAccount]).Value
$administratorsName = $administratorsSid.Translate([Security.Principal.NTAccount]).Value
$acl = Get-Acl -LiteralPath $sharePath
foreach ($sid in @($guest.SID, $anonymousSid)) {
    $acl.SetAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
        $sid, 'ReadAndExecute', 'ContainerInherit, ObjectInherit', 'None', 'Allow'))
}
Set-Acl -LiteralPath $sharePath -AclObject $acl

$share = Get-SmbShare -Name 'DeploymentShare$' -ErrorAction SilentlyContinue
if ($share) {
    if ($share.Path -ne $sharePath) { throw 'DeploymentShare$ already points to another folder.' }
    Grant-SmbShareAccess -Name 'DeploymentShare$' -AccountName @($guestName, $anonymousName) -AccessRight Read -Force | Out-Null
} else {
    New-SmbShare -Name 'DeploymentShare$' -Path $sharePath -ReadAccess @($guestName, $anonymousName) -FullAccess $administratorsName | Out-Null
}

New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name 'NullSessionShares' -PropertyType MultiString -Value @('DeploymentShare$') -Force | Out-Null
Set-SmbServerConfiguration -RequireSecuritySignature $false -Force | Out-Null
if (-not (Get-NetFirewallRule -Name 'Chal2-SMB' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'Chal2-SMB' -DisplayName 'Chal2 SMB' -Direction Inbound -Protocol TCP -LocalPort 445 -Action Allow | Out-Null
}
