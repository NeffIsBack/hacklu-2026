# ============================================================
#  DC - Schritt 5: Verwundbares Zertifikat-Template
#
#  Wir nutzen das Stock-Template 'WebServer'. Das hat von Haus aus
#  exakt die gewuenschten Eigenschaften:
#    - EKU NUR Server Authentication (kein Client Auth)
#    - Enrollee supplies Subject
#  und enrollt als echtes Built-in garantiert (kein handgebautes v2,
#  das die CA mit "cert type not supported" ablehnt).
#
#  Der Misconfig: Enroll-Recht fuer 'Domain Computers' + publishen.
#  MAQ=0 (Skript 16) erzwingt weiterhin den Umweg ueber SRV$.
#
#  Server-Auth-only -> kein ESC1-/PKINIT-Shortcut zur DA; das Zert
#  taugt nur zur TLS-Impersonation von wsus.agile-corp.hacklu.
# ============================================================

# ==== Konfiguration ====
$Template = 'WebServer'
# =======================

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$configNC = (Get-ADRootDSE).configurationNamingContext
$tplDN    = "CN=$Template,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"

# --- Enroll-Recht fuer 'Domain Computers' ----------------------------
$sid         = [System.Security.Principal.SecurityIdentifier](Get-ADGroup 'Domain Computers').SID
$enrollRight = [guid]'0e10c968-78fb-11d2-90d4-00c04f79dc55'       # Certificate-Enrollment
$acl = Get-Acl -Path "AD:\$tplDN"
$acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule($sid,'ExtendedRight','Allow',$enrollRight,'None')))
$acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule($sid,'GenericRead','Allow')))
Set-Acl -Path "AD:\$tplDN" -AclObject $acl
Write-Host "[+] '$Template': 'Domain Computers' => Read + Enroll."

# --- Veroeffentlichen (robust via LDAP) ------------------------------
$esBase = "CN=Enrollment Services,CN=Public Key Services,CN=Services,$configNC"
$es = Get-ADObject -SearchBase $esBase -LDAPFilter '(objectClass=pKIEnrollmentService)' | Select-Object -First 1
Set-ADObject -Identity $es.DistinguishedName -Add @{ certificateTemplates = $Template }
Restart-Service CertSvc
Write-Host "[+] '$Template' veroeffentlicht (certificateTemplates += $Template)."