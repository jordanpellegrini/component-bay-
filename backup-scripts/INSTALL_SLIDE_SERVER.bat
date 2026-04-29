@echo off
echo ============================================
echo   Installation - Slide Server au demarrage
echo ============================================
echo.
echo IMPORTANT: Lancer en tant qu'Administrateur!
echo.
pause

set SCRIPT_DIR=%~dp0

schtasks /delete /tn "ComponentsBay_SlideServer" /f >nul 2>&1

schtasks /create ^
    /tn "ComponentsBay_SlideServer" ^
    /tr "pythonw \"%SCRIPT_DIR%slide-server.py\"" ^
    /sc ONSTART ^
    /rl HIGHEST ^
    /f ^
    /ru "%USERNAME%"

powershell -Command "$t = Get-ScheduledTask -TaskName 'ComponentsBay_SlideServer'; $s = $t.Settings; $s.StartWhenAvailable = $true; $s.ExecutionTimeLimit = 'PT0S'; Set-ScheduledTask -TaskName 'ComponentsBay_SlideServer' -Settings $s" 2>nul

echo.
echo ============================================
echo   Installe! Le serveur demarre avec Windows
echo   sans fenetre visible (pythonw).
echo   Pour demarrer maintenant: START_SLIDE_SERVER.bat
echo ============================================
echo.
pause
