## Attack chain idea

1. Unauthenticated RID-Bruteforce um Nutzernamen zu erfahren
2. Username=Passwort sprayen um Niedrig priv. Account (svc_test) zu bekommen
3. Mit svc_test Kerberoasten um Hash von svc_backup zu bekommen
4. Hash mit rockyou+OneRule cracken (maybe nur rockyou dann muss das)
5. svc_backup ist in der Lage das gMSA Passwort von svc_backup_gmsa auszulesen (Account der neuen Domain)
6. svc_backup kann auf SMb Share Backup$ in der neuen Domain zugreifen
7. Dort liegt ein alter NTDS.dit export der Child Domain
8. Die enthaltenen Hashes sind alle wertlos (Passwörter rotiert). Nur der krbtgt Hash ist valid
9. Mit krbtgt Hash sid-History Attack ausführen um Parent Domain zu ownen