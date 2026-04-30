@echo off
echo ============================================
echo  Components Bay - Slide Generator v2
echo ============================================

set NODE_PATH=
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Node.js not found. Install from https://nodejs.org
    pause
    exit /b 1
)

set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

echo Checking pptxgenjs...
node -e "require('pptxgenjs')" >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing pptxgenjs...
    npm install -g pptxgenjs
)

echo Generating slide...
node "%SCRIPT_DIR%generate-slide-v2.js"

if %errorlevel% equ 0 (
    echo.
    echo SUCCESS! Check your Desktop\APP 5.5 folder.
) else (
    echo.
    echo ERROR during generation. Check output above.
)
pause
