# Change keyboard to Englisch US International
$Lang = Get-WinUserLanguageList
$Lang[0].InputMethodTips.Clear() 
$Lang[0].InputMethodTips.Add("0409:00020409") # 0409:00020409 = US-International
Set-WinUserLanguageList -LanguageList $Lang -Force

# Disable password expiration for all users
Get-ADUser -Filter * | Set-ADUser -PasswordNeverExpires:$True

# Echo Flag into Desktop/flag.txt
$text = Read-Host "Enter Flag"
$text | Out-File -FilePath "$env:USERPROFILE\Desktop\flag.txt"