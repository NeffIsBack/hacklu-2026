## Attack chain idea

### Step-by-step
1. Unauthenticated RID-Bruteforce um Nutzernamen zu erfahren
2. Username=Passwort sprayen um Niedrig priv. Account (svc_test) zu bekommen
3. Mit svc_test Kerberoasten um Hash von svc_backup zu bekommen
4. Hash mit rockyou+OneRule cracken (maybe nur rockyou dann muss das)
5. svc_backup ist in der Lage das gMSA Passwort von svc_backup_gmsa auszulesen (Account der neuen Domain)
6. svc_backup kann auf SMb Share Backup$ in der neuen Domain zugreifen
7. Dort liegt ein alter NTDS.dit export der Child Domain
8. Die enthaltenen Hashes sind alle wertlos (Passwörter rotiert). Nur der krbtgt Hash ist valid
9. Mit krbtgt Hash sid-History Attack ausführen um Parent Domain zu ownen

### Commands




## Manual configuration steps
### NTDS.dit export
1. Extract NTDS.dit and SYSTEM hive: `ntdsutil "activate instance ntds" "ifm" "create full C:\Windows\Temp\NTDS" quit quit`
2. Download the files from Child:
   1. `poetry run nxc smb 192.168.108.20 -u Administrator -p qcSiecDUATD63Kxm --get-file '\Windows\Temp\NTDS\Active Directory\ntds.dit' NTDS.dit`
   2. `poetry run nxc smb 192.168.108.20 -u Administrator -p qcSiecDUATD63Kxm --get-file '\Windows\Temp\NTDS\registry\SYSTEM' SYSTEM`
3. Remove NTDS extraction: `Remove-Item -Recurse -Force C:\Windows\Temp\NTDS`
4. Upload files to Parent:
   1. `poetry run nxc smb 192.168.108.10 -u Administrator -p C8J33i45kt4HXHMQ --share Backup$ --put-file NTDS.dit '\Export\NTDS.dit'`
   2. `poetry run nxc smb 192.168.108.10 -u Administrator -p C8J33i45kt4HXHMQ --share Backup$ --put-file SYSTEM '\Export\SYSTEM'`


# Flag
Part1: flag{m0v3_f4st_br34k
Part2: _th3_f0r3st_89a71f9g}