@echo off
echo ============================================
echo   EFS Auto-Sync from C.A.R.O.
echo   Lancement manuel...
echo ============================================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0sync-efs-caro.ps1"
pause
