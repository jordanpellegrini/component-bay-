@echo off
echo ============================================
echo   Installation - Slide Server au demarrage
echo ============================================
echo.
echo Ce script va creer une tache planifiee:
echo   - Nom   : ComponentsBay_SlideServer
echo   - Quand : Au demarrage de Windows
echo   - Action: Demarre le serveur local port 5001
echo.
echo IMPORTANT: Lancer en tant qu'Administrateur!
echo.
pause

set SCRIPT_DIR=%~dp0

schtasks /delete /tn "ComponentsBay_SlideServer" /f >nul 2>&1

schtasks /create ^
    /tn "ComponentsBay_SlideServer" ^
    /tr "python \"%SCRIPT_DIR%slide-server.py\"" ^
    /sc ONSTART ^
    /rl HIGHEST ^
    /f

powershell -Command "$t = Get-ScheduledTask -TaskName 'ComponentsBay_SlideServer'; $s = $t.Settings; $s.StartWhenAvailable = $true; Set-ScheduledTask -TaskName 'ComponentsBay_SlideServer' -Settings $s" 2>nul

echo.
echo ============================================
echo   Installe! Le serveur demarre avec Windows.
echo   Pour demarrer maintenant: START_SLIDE_SERVER.bat
echo ============================================
echo.
pause
