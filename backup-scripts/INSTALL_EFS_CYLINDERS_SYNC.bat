@echo off
echo ============================================
echo   Installation - EFS Cylinders Sync Mercredi 12h00
echo ============================================
echo.
echo Ce script va creer une tache planifiee Windows:
echo   - Nom     : ComponentsBay_EFSCylinders_Sync
echo   - Quand   : Tous les mercredis a 12h00
echo   - Action  : Sync EFS Cylinders depuis C.A.R.O.
echo   - Rattrapage : Oui (si PC eteint le mercredi)
echo.
echo IMPORTANT: Ce script doit etre lance en tant qu'Administrateur!
echo.
pause

set SCRIPT_DIR=%~dp0

schtasks /delete /tn "ComponentsBay_EFSCylinders_Sync" /f >nul 2>&1

schtasks /create ^
    /tn "ComponentsBay_EFSCylinders_Sync" ^
    /tr "powershell.exe -ExecutionPolicy Bypass -WindowStyle Normal -File \"%SCRIPT_DIR%sync-efs-cylinders-caro.ps1\"" ^
    /sc WEEKLY ^
    /d WED ^
    /st 12:00 ^
    /rl HIGHEST ^
    /f

powershell -Command "$t = Get-ScheduledTask -TaskName 'ComponentsBay_EFSCylinders_Sync'; $s = $t.Settings; $s.StartWhenAvailable = $true; $s.DisallowStartIfOnBatteries = $false; $s.StopIfGoingOnBatteries = $false; Set-ScheduledTask -TaskName 'ComponentsBay_EFSCylinders_Sync' -Settings $s" 2>nul

echo.
echo ============================================
echo   Tache planifiee installee avec succes!
echo ============================================
echo.
echo   Nom  : ComponentsBay_EFSCylinders_Sync
echo   Quand: Mercredi 12h00 (chaque semaine)
echo.
echo   Pour tester manuellement:
echo   Double-cliquez sur RUN_EFS_CYLINDERS_SYNC.bat
echo.
pause
