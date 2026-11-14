<#
    Phase 5c: FLAVOR fuer den Backup-Share (Backup$) auf DC-NEW
#>

# ===================== CONFIG =====================
$Root = 'C:\Shares\Backup'
# ==================================================

$ErrorActionPreference = 'Stop'

foreach ($d in @('Export','FileServer','SQL','MailExport')) {
    $p = Join-Path $Root $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}
function Write-Flavor($Path, $Text) {
    if (-not (Test-Path $Path)) { $Text | Set-Content -Path $Path -Encoding UTF8 }
}

Write-Flavor (Join-Path $Root 'README.txt') @'
VELOCITY INDUSTRIES - BACKUP SERVER (DC-NEW)
============================================
Share: Backup$  (hidden; backup service account + admins only)

Contents:
  \Export       Authoritative AD export of legacy systems (Granite migration)
  \FileServer   Backed-up Granite file server shares
  \SQL          Granite ERP database dumps

Migration note: Granite legacy systems are decommissioned after migration.
Exports are retained for 90 days for compliance.
Owner: n.schuster@velocity.hacklu
'@

Write-Flavor (Join-Path $Root 'backup_jobs.log') @'
[OK]   2026-02-02 01:00  FileServer\Granite      (12.4 GB)
[OK]   2026-02-02 01:40  SQL\granite_erp_full    (3.1 GB)
[OK]   2026-02-02 02:10  Export\MailExport       (0.8 GB)
[WARN] 2026-02-02 02:15  Export\ntds             Source: old Granite DC (offline copy)
[OK]   2026-02-02 02:30  Verification complete
'@

Write-Flavor (Join-Path $Root 'Export\_EXPORT_MANIFEST.txt') @'
GRANITE AD - AUTHORITATIVE EXPORT
=================================
Source  : GRANITE-DC01 (old domain, prior to decommissioning)
Purpose : Rollback safeguard for the migration to velocity.hacklu
Created : 2026-02-02 by a.krause

Files:
  ntds.dit   Directory database of the Granite domain
  SYSTEM

NOTE (internal): After cutover, ALL Granite user passwords were force-reset.
This offline copy is therefore useless for authentication - structure backup
only. Service/system accounts are reviewed separately (open, ticket INF-2291).
'@

Write-Flavor (Join-Path $Root 'FileServer\Salary_List_2025.csv') @'
Name;Department;Annual Salary
Werner Brandt;Management;180000
Ingrid Falk;Finance;92000
Dieter Koch;IT;74000
Karl Simon;Engineering;81000
'@
Write-Flavor (Join-Path $Root 'FileServer\Acquisition_Agreement_DRAFT.txt') @'
DRAFT - Share Purchase Agreement, Velocity Industries / Granite Industries
Confidential. Not for distribution. Legal dept., as of 11/2025.
'@
Write-Flavor (Join-Path $Root 'SQL\granite_erp_full.bak') @'
-- SQL Server Backup (placeholder) --
-- Database: GRANITE_ERP | Recovery: FULL | Size ~3.1 GB --
-- (decoy for the lab, not a real dump) --
'@

$mail = Join-Path $Root 'MailExport'

Write-Flavor (Join-Path $mail '01_Acquisition-Announcement.eml') @'
From: Claudia Vogt <c.vogt@velocity.hacklu>
To: all-staff@velocity.hacklu; all-staff@old.velocity.hacklu
Date: Mon, 12 Jan 2026 08:30:00 +0100
Subject: Welcome Granite! Our journey to synergy begins NOW
Content-Type: text/plain; charset=utf-8

Rockstars,

HUGE news: Velocity Industries has officially acquired Granite Industries!
A warm, radically inclusive welcome to all our new Granite family members.

To unlock cross-org synergy at scale, the existing Granite environment has
been onboarded into our ecosystem as a connected sub-domain (trust fully
established). Over the coming sprints our platform team will converge both
worlds into one frictionless, future-proof source of truth.

Let's disrupt the quarry business together. Onward and upward!
Claudia Vogt, Chief Visionary Officer
'@

Write-Flavor (Join-Path $mail '02_Granite-DC-Decommission.eml') @'
From: Andreas Krause <a.krause@velocity.hacklu>
To: it-platform@velocity.hacklu
Cc: n.schuster@velocity.hacklu
Date: Fri, 30 Jan 2026 17:12:00 +0100
Subject: Granite DC decommission & AD export
Content-Type: text/plain; charset=utf-8

Team,

the old Granite DC goes offline next week. Before that we pulled a full
authoritative export of the Granite AD database and placed it on the backup
server under Backup$\Export - a rollback safeguard in case the migration
goes sideways.

Important: all Granite USER passwords were force-reset after cutover, so the
offline copy is useless for logins. Service and system accounts we review
separately (ticket INF-2291) - didn't want to rush that one.

Cheers, Andreas
'@

Write-Flavor (Join-Path $mail '03_Test-Accounts.eml') @'
From: Otto Fuchs <o.fuchs@old.velocity.hacklu>
To: it-support@old.velocity.hacklu
Date: Wed, 21 Jan 2026 10:05:00 +0100
Subject: Clean up test accounts before migration
Content-Type: text/plain; charset=utf-8

Hi,

I created a few accounts for the migration tests. The password is the same as
the username in each case, so we can test quickly. Please disable them all
when we're done - svc_test is still open.

Also, the old Granite backup sync still runs under a legacy account that uses
old encryption for compatibility reasons. Werner didn't want it touched before
the migration.

Otto
'@

Write-Flavor (Join-Path $mail '04_Security-Review.eml') @'
From: Audit Team <review@extern-sec.example>
To: m.thiel@velocity.hacklu
Date: Tue, 09 Dec 2025 14:40:00 +0100
Subject: Granite - Pre-Acquisition Security Review (summary)
Content-Type: text/plain; charset=utf-8

Dear Mr Thiel,

please find the summary of our pre-acquisition review of the Granite
environment. Notable findings:

- Anonymous directory enumeration is enabled (legacy configuration).
- Several service accounts with weak / guessable passwords.
- Deprecated Kerberos encryption (RC4) still permitted.
- Backup share with overly broad read permissions for service accounts.

We recommend remediating these BEFORE converging with the Velocity
environment, otherwise the weaknesses propagate into the combined forest.

Kind regards,
Audit Team
'@

Write-Host "[fertig] Backup-Share-Flavor + Postfach-Export (EN) angelegt unter $Root" -ForegroundColor Green
Get-ChildItem $Root -Recurse -File | Select-Object FullName | Format-Table -AutoSize