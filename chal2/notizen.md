## Attack chain idea
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
