@echo off
echo ============================================
echo   Installation - Daily Email Report 6h00
echo ============================================
echo.
echo Tache planifiee:
echo   - Nom   : ComponentsBay_DailyReport
echo   - Quand : Tous les jours a 06h00
echo   - Email : jpellegrini@advanced-sm.com
echo.
echo IMPORTANT: Lancer en tant qu'Administrateur!
echo.
pause

set SCRIPT_DIR=%~dp0

schtasks /delete /tn "ComponentsBay_DailyReport" /f >nul 2>&1

schtasks /create ^
    /tn "ComponentsBay_DailyReport" ^
    /tr "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%SCRIPT_DIR%send-daily-report.ps1\"" ^
    /sc DAILY ^
    /st 06:00 ^
    /rl HIGHEST ^
    /f

powershell -Command "$t = Get-ScheduledTask -TaskName 'ComponentsBay_DailyReport'; $s = $t.Settings; $s.StartWhenAvailable = $true; $s.DisallowStartIfOnBatteries = $false; $s.StopIfGoingOnBatteries = $false; Set-ScheduledTask -TaskName 'ComponentsBay_DailyReport' -Settings $s" 2>nul

echo.
echo ============================================
echo   Installe! Email envoye tous les jours a 06h00
echo   Seulement si items U/S ou echeances dans 90j
echo ============================================
echo.
pause
