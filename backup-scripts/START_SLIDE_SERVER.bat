@echo off
echo Demarrage ComponentsBay Slide Server...
set PYTHON_PATH=C:\Program Files\Python314\python.exe
if not exist "%PYTHON_PATH%" set PYTHON_PATH=C:\Program Files\Python313\python.exe
if not exist "%PYTHON_PATH%" set PYTHON_PATH=C:\Program Files\Python312\python.exe
if not exist "%PYTHON_PATH%" set PYTHON_PATH=C:\Program Files\Python311\python.exe
if not exist "%PYTHON_PATH%" (
    echo ERREUR: Python introuvable!
    pause
    exit /b 1
)
"%PYTHON_PATH%" "%~dp0slide-server.py"
