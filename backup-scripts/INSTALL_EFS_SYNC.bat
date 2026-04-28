@echo off
echo ============================================
echo   Installation - EFS Sync Mercredi 12h00
echo ============================================
echo.
echo Ce script va creer une tache planifiee Windows:
echo   - Nom     : ComponentsBay_EFS_Sync
echo   - Quand   : Tous les mercredis a 12h00
echo   - Action  : Sync EFS depuis C.A.R.O.
echo   - Rattrapage : Oui (si PC eteint le mercredi)
echo.
echo IMPORTANT: Ce script doit etre lance en tant qu'Administrateur!
echo.
pause

:: Get the directory where this script is located
set SCRIPT_DIR=%~dp0

:: Delete existing task if any
schtasks /delete /tn "ComponentsBay_EFS_Sync" /f >nul 2>&1

:: Create weekly task - Wednesday at 12:00
schtasks /create ^
    /tn "ComponentsBay_EFS_Sync" ^
    /tr "powershell.exe -ExecutionPolicy Bypass -WindowStyle Normal -File \"%SCRIPT_DIR%sync-efs-caro.ps1\"" ^
    /sc WEEKLY ^
    /d WED ^
    /st 12:00 ^
    /rl HIGHEST ^
    /f

:: Enable "Start when available" (rattrapage) and "Allow on battery"
powershell -Command "$t = Get-ScheduledTask -TaskName 'ComponentsBay_EFS_Sync'; $s = $t.Settings; $s.StartWhenAvailable = $true; $s.DisallowStartIfOnBatteries = $false; $s.StopIfGoingOnBatteries = $false; Set-ScheduledTask -TaskName 'ComponentsBay_EFS_Sync' -Settings $s" 2>nul

echo.
echo ============================================
echo   Tache planifiee installee avec succes!
echo ============================================
echo.
echo   Nom  : ComponentsBay_EFS_Sync
echo   Quand: Mercredi 12h00 (chaque semaine)
echo.
echo   Pour tester manuellement:
echo   Double-cliquez sur RUN_EFS_SYNC.bat
echo.
echo   Pour supprimer la tache:
echo   schtasks /delete /tn "ComponentsBay_EFS_Sync" /f
echo.
pause
