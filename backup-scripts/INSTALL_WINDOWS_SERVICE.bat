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

echo Installation du service...
python "%SCRIPT_DIR%slide-service.py" install

echo Demarrage du service...
python "%SCRIPT_DIR%slide-service.py" start

echo.
echo ============================================
echo   Service installe et demarre!
echo   Tourne en permanence en arriere-plan.
echo   Pour verifier: http://localhost:5001/status
echo.
echo   Pour arreter : python slide-service.py stop
echo   Pour desinstaller: python slide-service.py remove
echo ============================================
echo.
pause
