# ============================================================
#  DC - Schritt 5: Verwundbares Zertifikat-Template
#
#  Klon von 'WebServer' als v2-Template "CI Build Server":
#    - Enrollee supplies Subject (msPKI-Certificate-Name-Flag = 0x1)
#    - EKU NUR Server Authentication (kein Client Authentication)
#    - Enroll-Recht fuer 'Domain Computers'
#
#  Nur Server-Auth -> kein ESC1-/PKINIT-Shortcut zur DA; das Zert
#  taugt "nur" zur TLS-Impersonation von wsus.agile-corp.hacklu.
#  Enroll nur fuer Computer + MAQ=0 -> User muss erst per Priv-Esc
#  den Machine Account SRV$ uebernehmen.
#
#  Ohne GUI/externe Module (nur ActiveDirectory + ADCSAdministration).
# ============================================================

# ==== Konfiguration ====
$tplCN      = 'CIBuildServer'
$tplDisplay = 'CI Build Server'
$sourceCN   = 'WebServer'
# =======================

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
Import-Module ADCSAdministration

$configNC     = (Get-ADRootDSE).configurationNamingContext
$tplContainer = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"
$oidContainer = "CN=OID,CN=Public Key Services,CN=Services,$configNC"
$srcDN        = "CN=$sourceCN,$tplContainer"
$newDN        = "CN=$tplCN,$tplContainer"

if (-not (Get-ADObject -LDAPFilter "(cn=$sourceCN)" -SearchBase $tplContainer -ErrorAction SilentlyContinue)) {
    throw "Quell-Template '$sourceCN' fehlt. Wurde die CA (Skript 13) installiert?"
}
if (Get-ADObject -LDAPFilter "(cn=$tplCN)" -SearchBase $tplContainer -ErrorAction SilentlyContinue) {
    Write-Host "[=] Template '$tplCN' existiert bereits - nichts zu tun."; return
}

# --- Struktur-/Binaerattribute von WebServer uebernehmen -------------
$copy = @('flags','pKIDefaultKeySpec','pKIMaxIssuingDepth','pKIKeyUsage',
          'pKICriticalExtensions','pKIExpirationPeriod','pKIOverlapPeriod','pKIDefaultCSPs')
$src = Get-ADObject -Identity $srcDN -Properties $copy

# --- Eindeutige Template-OID + OID-Objekt ----------------------------
$forestOID   = (Get-ADObject -Identity $oidContainer -Properties 'msPKI-Cert-Template-OID').'msPKI-Cert-Template-OID'
$p1          = Get-Random -Minimum 1000000  -Maximum 99999999
$p2          = Get-Random -Minimum 10000000 -Maximum 99999999
$templateOID = "$forestOID.$p1.$p2"
$oidName     = "$p2.$([guid]::NewGuid().ToString('N'))"

New-ADObject -Path $oidContainer -Name $oidName -Type 'msPKI-Enterprise-Oid' -OtherAttributes @{
    'DisplayName'             = $tplDisplay
    'flags'                   = 1
    'msPKI-Cert-Template-OID' = $templateOID
} | Out-Null

# --- Neues Template-Objekt -------------------------------------------
$attrs = @{
    'flags'                                = $src.flags
    'pKIDefaultKeySpec'                    = $src.pKIDefaultKeySpec
    'pKIMaxIssuingDepth'                   = $src.pKIMaxIssuingDepth
    'pKIKeyUsage'                          = $src.pKIKeyUsage
    'pKICriticalExtensions'                = $src.pKICriticalExtensions
    'pKIExpirationPeriod'                  = $src.pKIExpirationPeriod
    'pKIOverlapPeriod'                     = $src.pKIOverlapPeriod
    'pKIDefaultCSPs'                       = $src.pKIDefaultCSPs
    'displayName'                          = $tplDisplay
    'revision'                             = 100
    'msPKI-Template-Schema-Version'        = 2
    'msPKI-Cert-Template-OID'              = $templateOID
    'msPKI-Minimal-Key-Size'               = 2048
    'msPKI-RA-Signature'                   = 0
    'msPKI-Enrollment-Flag'                = 0
    'msPKI-Private-Key-Flag'               = 0x10                 # exportierbar
    'msPKI-Certificate-Name-Flag'          = 0x1                  # ENROLLEE_SUPPLIES_SUBJECT
    'pKIExtendedKeyUsage'                  = '1.3.6.1.5.5.7.3.1'  # Server Authentication
    'msPKI-Certificate-Application-Policy' = '1.3.6.1.5.5.7.3.1'
}
$clean = @{}; foreach ($k in $attrs.Keys) { if ($null -ne $attrs[$k]) { $clean[$k] = $attrs[$k] } }
New-ADObject -Path $tplContainer -Name $tplCN -Type 'pKICertificateTemplate' -OtherAttributes $clean | Out-Null
Write-Host "[+] Template '$tplCN' angelegt (OID $templateOID)."

# --- Enroll-Recht fuer 'Domain Computers' ----------------------------
$sid         = [System.Security.Principal.SecurityIdentifier](Get-ADGroup 'Domain Computers').SID
$enrollRight = [guid]'0e10c968-78fb-11d2-90d4-00c04f79dc55'       # Certificate-Enrollment
$acl = Get-Acl -Path "AD:\$newDN"
$acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule($sid,'ExtendedRight','Allow',$enrollRight,'None')))
$acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule($sid,'GenericRead','Allow')))
Set-Acl -Path "AD:\$newDN" -AclObject $acl
Write-Host "[+] 'Domain Computers' => Read + Enroll."

# --- Veroeffentlichen ------------------------------------------------
$cfg = (Get-ADRootDSE).configurationNamingContext
$es  = Get-ADObject -SearchBase "CN=Enrollment Services,CN=Public Key Services,CN=Services,$cfg" `
         -LDAPFilter '(objectClass=pKIEnrollmentService)' | Select-Object -First 1
Set-ADObject -Identity $es.DistinguishedName -Add @{ certificateTemplates = 'CIBuildServer' }
Restart-Service CertSvc
Write-Host "[+] Template veroeffentlicht."