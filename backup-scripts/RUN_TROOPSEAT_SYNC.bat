@echo off
echo ============================================
echo   Troop Seat Sync - Lancement manuel
echo ============================================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0sync-troopseat.ps1"
pause
