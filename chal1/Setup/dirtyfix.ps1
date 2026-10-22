# Paste direkt auf dem betroffenen Server
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' `
    -Name 'DisableBGRefresh' -Value 1 -Type DWord
