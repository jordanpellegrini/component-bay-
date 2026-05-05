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
set PS_FILE=%SCRIPT_DIR%send-daily-report.ps1

REM === Supprimer les anciennes taches ===
schtasks /delete /tn "ComponentsBay_DailyReport" /f >nul 2>&1
schtasks /delete /tn "ComponentsBay_DailyReport_Boot" /f >nul 2>&1

REM === Tache 1 : Tous les jours a 06h00 (sans elevation) ===
schtasks /create /tn "ComponentsBay_DailyReport" /tr "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%PS_FILE%\"" /sc DAILY /st 06:00 /f
if %errorlevel%==0 (echo [OK] Tache 1 creee) else (echo [ERREUR] Tache 1 echouee)

REM === Tache 2 : Au logon via script PS dedie (sans elevation) ===
powershell.exe -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install-boot-task.ps1" "%PS_FILE%"
if %errorlevel%==0 (echo [OK] Tache 2 creee) else (echo [ERREUR] Tache 2 echouee)

echo.
echo ============================================
schtasks /query /tn "ComponentsBay_DailyReport" /fo LIST 2>nul | findstr "TaskName Status"
schtasks /query /tn "ComponentsBay_DailyReport_Boot" /fo LIST 2>nul | findstr "TaskName Status"
echo.
echo   Tache 1 : Email a 06h00 chaque jour
echo   Tache 2 : Email 3 min apres connexion Windows
echo   NOTE: Les taches tournent SANS elevation pour
echo         permettre a Outlook de fonctionner
echo ============================================
echo.
pause
