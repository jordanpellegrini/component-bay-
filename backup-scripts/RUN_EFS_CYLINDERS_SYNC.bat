@echo off
echo ============================================
echo   EFS Cylinders Auto-Sync from C.A.R.O.
echo   Lancement manuel...
echo ============================================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0sync-efs-cylinders-caro.ps1"
pause
