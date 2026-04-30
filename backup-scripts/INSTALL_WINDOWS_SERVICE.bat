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

:: Python installed for all users - direct path
set PYTHON_PATH=C:\Program Files\Python314\python.exe
if not exist "%PYTHON_PATH%" set PYTHON_PATH=C:\Program Files\Python313\python.exe
if not exist "%PYTHON_PATH%" set PYTHON_PATH=C:\Program Files\Python312\python.exe
if not exist "%PYTHON_PATH%" set PYTHON_PATH=C:\Program Files\Python311\python.exe
if not exist "%PYTHON_PATH%" (
    echo ERREUR: Python introuvable dans C:\Program Files\
    echo Verifiez le chemin d'installation.
    pause
    exit /b 1
)

echo Python trouve: %PYTHON_PATH%
echo.

echo Installation du service...
"%PYTHON_PATH%" "%SCRIPT_DIR%slideservice.py" install

echo Demarrage du service...
"%PYTHON_PATH%" "%SCRIPT_DIR%slideservice.py" start

echo.
echo ============================================
echo   Service installe et demarre!
echo   Tourne en permanence en arriere-plan.
echo   Pour verifier: http://localhost:5001/status
echo.
echo   Pour arreter    : "%PYTHON_PATH%" slideservice.py stop
echo   Pour desinstaller: "%PYTHON_PATH%" slideservice.py remove
echo ============================================
echo.
pause
