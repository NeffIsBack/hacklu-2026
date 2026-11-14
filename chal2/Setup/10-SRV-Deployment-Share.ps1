# ============================================================
#  SRV - Schritt 3: Deployment-Share (Guest-lesbar)
# ============================================================

# ==== Configuration ====
$ShareName = 'REMINST'
$SharePath = 'C:\RemoteInstall'
$User      = 'svc_deploy'
$Domain    = 'AGILE-CORP'
$UserPass  = 'D3pl0y!_AgileCorp'
$WsusUrl   = 'https://wsus.agile-corp.hacklu:8531'
# =======================

$ErrorActionPreference = 'Stop'

# --- Ordnerstruktur + unattend.xml -----------------------------------
$unattendDir = Join-Path $SharePath 'WdsClientUnattend'
New-Item -ItemType Directory -Path $unattendDir -Force | Out-Null

$b64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($UserPass + 'Password'))

$unattend = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <AutoLogon>
        <Enabled>true</Enabled>
        <LogonCount>1</LogonCount>
        <Username>$User</Username>
        <Domain>$Domain</Domain>
        <Password>
          <Value>$b64</Value>
          <PlainText>false</PlainText>
        </Password>
      </AutoLogon>
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <CommandLine>reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v WUServer /t REG_SZ /d $WsusUrl /f</CommandLine>
          <Description>Register node with corporate WSUS (CD pipeline)</Description>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
          <Order>2</Order>
          <CommandLine>reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v UseWUServer /t REG_DWORD /d 1 /f</CommandLine>
          <Description>Use corporate WSUS</Description>
        </SynchronousCommand>
      </FirstLogonCommands>
    </component>
  </settings>
</unattend>
"@
Set-Content -Path (Join-Path $unattendDir 'ImageUnattend.xml') -Value $unattend -Encoding UTF8
Write-Host "[+] ImageUnattend.xml geschrieben (Passwort base64, WSUS-Hinweis enthalten)."

# --- Guest-Konto aktivieren ------------------------------------------
try { Enable-LocalUser -Name 'Guest'; Write-Host "[+] Guest-Konto aktiviert." }
catch { Write-Host "[!] Guest nicht aktivierbar: $($_.Exception.Message)" }

# --- NTFS: Everyone + Guest lesen -------------------
$acl = Get-Acl $SharePath
foreach ($who in @('Everyone','Guest')) {
    $acl.AddAccessRule( (New-Object System.Security.AccessControl.FileSystemAccessRule(
        $who,'ReadAndExecute','ContainerInherit,ObjectInherit','None','Allow')) )
}
Set-Acl -Path $SharePath -AclObject $acl

# --- SMB-Share: Everyone + Guest Read --------------------------------
if (Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue) { Remove-SmbShare -Name $ShareName -Force }
New-SmbShare -Name $ShareName -Path $SharePath -ReadAccess 'Everyone' | Out-Null
Grant-SmbShareAccess -Name $ShareName -AccountName 'Guest' -AccessRight Read -Force | Out-Null

Write-Host "[+] Share '\\$env:COMPUTERNAME\$ShareName' -> $SharePath (Guest-lesbar, kein Null-Session)."