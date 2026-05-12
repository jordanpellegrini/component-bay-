@echo off
echo ============================================
echo   Components Bay - Wheel Sync from CARO
echo ============================================
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0sync-wheels-caro.ps1"
if %errorlevel% neq 0 (
    echo.
    echo ERREUR lors de l execution du script!
    echo Code erreur: %errorlevel%
    pause
)
