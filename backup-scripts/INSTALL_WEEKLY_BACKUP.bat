@echo off
:: ============================================================
:: Components Bay - Installer le Backup Automatique Hebdomadaire
:: ============================================================
:: EXECUTEZ CE FICHIER UNE SEULE FOIS (clic droit > Executer en tant qu'administrateur)
:: ============================================================

echo.
echo  ================================================
echo   Installation du Backup Automatique Hebdomadaire
echo  ================================================
echo.

:: Supprimer l'ancienne tache si elle existe
schtasks /delete /tn "ComponentsBay_WeeklyBackup" /f >nul 2>&1

:: Creer la tache planifiee avec rattrapage si PC eteint/veille
schtasks /create /tn "ComponentsBay_WeeklyBackup" /tr "powershell -ExecutionPolicy Bypass -File \"%~dp0backup-components-bay.ps1\"" /sc weekly /d WED /st 12:00 /ri 60 /du 24:00 /f

:: Activer "Run as soon as possible after a scheduled start is missed"
powershell -ExecutionPolicy Bypass -Command "$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries; Set-ScheduledTask -TaskName 'ComponentsBay_WeeklyBackup' -Settings $settings" >nul 2>&1

if %ERRORLEVEL% == 0 (
    echo.
    echo  Tache planifiee creee avec succes!
    echo.
    echo  Frequence  : Chaque Dimanche
    echo  Heure      : 06h00
    echo  Rattrapage : OUI (se lance au reveil si PC etait eteint/veille)
    echo  Batterie   : OUI (fonctionne aussi sur batterie)
    echo  Dossier    : %%USERPROFILE%%\Documents\ComponentsBay_Backups
    echo.
    echo  Pour modifier: Planificateur de taches ^> ComponentsBay_WeeklyBackup
    echo.
) else (
    echo.
    echo  Erreur! Relancez ce fichier en tant qu'administrateur
    echo     (Clic droit ^> Executer en tant qu'administrateur)
    echo.
)

pause
