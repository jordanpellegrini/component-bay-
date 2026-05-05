@echo off
echo ============================================
echo   Installation - Daily Email Report 6h00
echo ============================================
echo.
echo Taches planifiees:
echo   - Nom 1 : ComponentsBay_DailyReport (tous les jours a 06h00)
echo   - Nom 2 : ComponentsBay_DailyReport_Boot (au demarrage)
echo   - Email : jpellegrini@advanced-sm.com
echo.
echo IMPORTANT: Lancer en tant qu'Administrateur!
echo.
pause

set SCRIPT_DIR=%~dp0

REM === Supprimer les anciennes taches si elles existent ===
schtasks /delete /tn "ComponentsBay_DailyReport" /f >nul 2>&1
schtasks /delete /tn "ComponentsBay_DailyReport_Boot" /f >nul 2>&1

REM === Tache 1 : Tous les jours a 06h00 ===
schtasks /create ^
    /tn "ComponentsBay_DailyReport" ^
    /tr "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%SCRIPT_DIR%send-daily-report.ps1\"" ^
    /sc DAILY ^
    /st 06:00 ^
    /rl HIGHEST ^
    /f

REM === Tache 2 : Au demarrage de l'ordinateur (delai 3 min pour laisser Outlook s'ouvrir) ===
schtasks /create ^
    /tn "ComponentsBay_DailyReport_Boot" ^
    /tr "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -Command \"Start-Sleep -Seconds 180; & '%SCRIPT_DIR%send-daily-report.ps1'\"" ^
    /sc ONSTART ^
    /delay 0003:00 ^
    /rl HIGHEST ^
    /f

REM === Options avancees : demarrer si manque, pas de restriction batterie ===
powershell -Command "$names = @('ComponentsBay_DailyReport','ComponentsBay_DailyReport_Boot'); foreach($n in $names){ $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue; if($t){ $s = $t.Settings; $s.StartWhenAvailable = $true; $s.DisallowStartIfOnBatteries = $false; $s.StopIfGoingOnBatteries = $false; Set-ScheduledTask -TaskName $n -Settings $s } }" 2>nul

echo.
echo ============================================
echo   Installation terminee!
echo.
echo   Tache 1 : Email envoye tous les jours a 06h00
echo   Tache 2 : Email envoye 3 min apres le demarrage
echo             (delai pour laisser Outlook s'ouvrir)
echo.
echo   Seulement si items U/S ou echeances dans 90j
echo ============================================
echo.
pause
