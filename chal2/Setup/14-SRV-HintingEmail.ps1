# ============================================================
#  SRV - Schritt 4: Admin-Mail auf dem Administrator-Desktop
# ============================================================

$ErrorActionPreference = 'Stop'

$desktop = 'C:\Users\Administrator\Desktop'
New-Item -ItemType Directory -Path $desktop -Force | Out-Null

$eml = @'
From: devon.opsworth@agile-corp.hacklu
To: aiden.kanban@agile-corp.hacklu
Date: Mon, 14 Oct 2024 09:23:41 +0200
Subject: WSUS is finally on HTTPS + temp. scheduled task on DC
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8

Hey Aiden,

just a quick heads-up before youre leaveing for vacation.

I finally got around to migrating the WSUS endpoint to HTTPS
(and updated the GPO). It's been sitting in
the backlog since Q2, but you know how it is.

For debugging purposes Ive set up a scheduled Task on the DC
(WSUS-FastScan) that triggers a Windows Update scan every few
minutes so we can verify clients are actually picking up the new
endpoint. Seemed easier than waiting around for the default
detection interval.

Once you're back from vacation and we've confirmed everything is
working, feel free to remove the task - it's not exactly
something we want running permanently in prod. You know, security
and all that. But for now it's fine.

Let me know if anything looks off on your end.

Cheers,
Devon

--
Devon Opsworth | DevOps Engineer | Agile Corp
"It works on my machine" is not a deployment strategy.
(but it is a starting point)
'@

Set-Content -Path (Join-Path $desktop 'RE- WSUS migration status.eml') -Value $eml -Encoding UTF8
Write-Host "[+] Admin-Mail -> $desktop\RE- WSUS migration status.eml"