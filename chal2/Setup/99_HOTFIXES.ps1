# Fix Scheduled Task
$flush  = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\ipconfig.exe" -Argument '/flushdns'
$update = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -Argument '-NoProfile -ExecutionPolicy Bypass -NonInteractive -Command "Import-Module PSWindowsUpdate; Install-WindowsUpdate -AcceptAll -IgnoreReboot | Out-Null"'
$trigger  = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
Register-ScheduledTask -TaskName 'WSUS-FastScan' -Action $flush,$update -Trigger $trigger `
    -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force