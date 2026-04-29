@echo off
echo ============================================
echo   Daily Report - Test manuel
echo ============================================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0send-daily-report.ps1"
pause
