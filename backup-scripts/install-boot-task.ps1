param([string]$ScriptPath)

# Recuperer le vrai utilisateur connecte (pas Administrator)
$loggedUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName
if (-not $loggedUser) {
    $loggedUser = "$env:COMPUTERNAME\jpellegrini"
}

Write-Host "Enregistrement tache pour : $loggedUser"

$action   = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -Command `"Start-Sleep 180; & '$ScriptPath'`""
$trigger  = New-ScheduledTaskTrigger -AtLogOn -User $loggedUser
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries

Register-ScheduledTask -TaskName "ComponentsBay_DailyReport_Boot" `
    -Action $action -Trigger $trigger -Settings $settings `
    -RunLevel Limited -Force | Out-Null

Write-Host "[OK] Tache Boot enregistree pour : $ScriptPath"
