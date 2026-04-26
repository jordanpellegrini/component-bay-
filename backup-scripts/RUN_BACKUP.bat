@echo off
:: ============================================================
:: Components Bay - Weekly Backup Launcher
:: ============================================================

echo.
echo  ====================================
echo   Components Bay - Backup Launcher
echo  ====================================
echo.
echo  Lancement du backup...
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0backup-components-bay.ps1"

echo.
echo  ---
echo  Si vous voyez une erreur ci-dessus, faites une capture d ecran.
echo.
pause
