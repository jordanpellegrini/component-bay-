@echo off
echo ============================================
echo   Components Bay - Weekly Slide Generator
echo ============================================
echo.
set PYTHON_PATH=C:\Program Files\Python314\python.exe
if not exist "%PYTHON_PATH%" set PYTHON_PATH=C:\Program Files\Python313\python.exe
if not exist "%PYTHON_PATH%" set PYTHON_PATH=C:\Program Files\Python312\python.exe
if not exist "%PYTHON_PATH%" set PYTHON_PATH=C:\Program Files\Python311\python.exe
if not exist "%PYTHON_PATH%" (
    echo ERREUR: Python introuvable!
    pause
    exit /b 1
)
echo Generation du PowerPoint depuis Supabase...
echo.
"%PYTHON_PATH%" "%~dp0generate-weekly-slide.py"
echo.
echo Le fichier a ete sauvegarde dans APP 5.5.
echo.
pause
