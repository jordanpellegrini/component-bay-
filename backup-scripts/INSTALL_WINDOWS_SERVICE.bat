@echo off
echo ============================================
echo   Installation Service Windows - Slide Server
echo ============================================
echo.
echo Ce script installe ComponentsBay Slide Server
echo comme service Windows (tourne en permanence,
echo meme sans fenetre ouverte).
echo.
echo IMPORTANT: Lancer en tant qu'Administrateur!
echo.
pause

set SCRIPT_DIR=%~dp0

:: Find Python path
set PYTHON_PATH=
for /f "tokens=*" %%i in ('where python3 2^>nul') do set PYTHON_PATH=%%i
if "%PYTHON_PATH%"=="" (
    for /f "tokens=*" %%i in ('where python 2^>nul') do set PYTHON_PATH=%%i
)
if "%PYTHON_PATH%"=="" (
    for /f "tokens=*" %%i in ('where py 2^>nul') do set PYTHON_PATH=%%i
)

if "%PYTHON_PATH%"=="" (
    echo ERREUR: Python introuvable!
    echo Verifiez que Python est installe et dans le PATH.
    pause
    exit /b 1
)

echo Python trouve: %PYTHON_PATH%
echo.

echo Installation du service...
"%PYTHON_PATH%" "%SCRIPT_DIR%slide-service.py" install

echo Demarrage du service...
"%PYTHON_PATH%" "%SCRIPT_DIR%slide-service.py" start

echo.
echo ============================================
echo   Service installe et demarre!
echo   Tourne en permanence en arriere-plan.
echo   Pour verifier: http://localhost:5001/status
echo.
echo   Pour arreter    : "%PYTHON_PATH%" slide-service.py stop
echo   Pour desinstaller: "%PYTHON_PATH%" slide-service.py remove
echo ============================================
echo.
pause
