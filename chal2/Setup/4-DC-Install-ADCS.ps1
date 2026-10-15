# ============================================================
#  DC - Schritt 4: ADCS Enterprise Root CA
#
#  NUR CA-Rolle, KEIN Web-Enrollment/NDES -> ESC8 bewusst aus.
# ============================================================

# ==== Konfiguration ====
$CaCommonName = 'agile-corp-Root-CA'
# =======================

$ErrorActionPreference = 'Stop'

Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools | Out-Null
Install-AdcsCertificationAuthority `
    -CAType            EnterpriseRootCA `
    -CACommonName      $CaCommonName `
    -KeyLength         2048 `
    -HashAlgorithmName SHA256 `
    -ValidityPeriod    Years -ValidityPeriodUnits 10 `
    -Force

Write-Host "[+] CA '$CaCommonName' installiert (ohne Web-Enrollment)."