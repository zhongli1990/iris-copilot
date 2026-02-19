@echo off
REM ================================================================
REM IRIS Copilot — Windows Deployment Script
REM ================================================================
REM
REM This script copies the AIAgent classes to your IRIS instance
REM directory and provides the IRIS Terminal commands to run.
REM
REM Usage:
REM   deploy-windows.bat [IRIS_INSTALL_DIR] [NAMESPACE]
REM
REM Example:
REM   deploy-windows.bat C:\InterSystems\IRIS HSBUS
REM
REM ================================================================

set IRIS_DIR=%1
set NAMESPACE=%2

if "%IRIS_DIR%"=="" (
    echo.
    echo IRIS Copilot Deployment
    echo ========================
    echo.
    echo Usage: deploy-windows.bat [IRIS_INSTALL_DIR] [NAMESPACE]
    echo.
    echo Example:
    echo   deploy-windows.bat C:\InterSystems\IRIS HSBUS
    echo.
    echo Or deploy manually:
    echo.
    echo   1. Copy the cls\ folder to your IRIS server
    echo   2. Open IRIS Terminal and run:
    echo      do $system.OBJ.Load("C:\path\to\deploy\ImportAll.cls", "ck"^)
    echo      do ##class(AIAgent.Deploy.ImportAll^).Run("C:\path\to\cls\"^)
    echo      do ##class(AIAgent.Install.Installer^).Run(^)
    echo.
    pause
    exit /b 0
)

if "%NAMESPACE%"=="" set NAMESPACE=HSBUS

echo.
echo ================================================================
echo  IRIS Copilot — Deploying to %IRIS_DIR%
echo  Namespace: %NAMESPACE%
echo ================================================================
echo.

REM Get the directory where this script lives
set SCRIPT_DIR=%~dp0
set CLS_DIR=%SCRIPT_DIR%..\cls\

echo Source: %CLS_DIR%
echo.

REM Check source exists
if not exist "%CLS_DIR%AIAgent\" (
    echo ERROR: Cannot find cls\AIAgent\ directory.
    echo Expected at: %CLS_DIR%AIAgent\
    pause
    exit /b 1
)

REM Create target directory
set TARGET_DIR=%IRIS_DIR%\mgr\%NAMESPACE%\AIAgent\
echo Creating target directory: %TARGET_DIR%
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

REM Copy all .cls files preserving directory structure
echo Copying 24 ObjectScript classes...
xcopy /s /y /q "%CLS_DIR%AIAgent\*" "%TARGET_DIR%"
if errorlevel 1 (
    echo ERROR: Failed to copy files.
    pause
    exit /b 1
)

REM Also copy the ImportAll helper
echo Copying deployment helper...
copy /y "%SCRIPT_DIR%ImportAll.cls" "%IRIS_DIR%\mgr\%NAMESPACE%\"

echo.
echo ================================================================
echo  Files copied successfully!
echo ================================================================
echo.
echo Now open the IRIS Terminal for namespace %NAMESPACE% and run:
echo.
echo   do $system.OBJ.Load("%IRIS_DIR%\mgr\%NAMESPACE%\ImportAll.cls", "ck")
echo   do ##class(AIAgent.Deploy.ImportAll).Run("%TARGET_DIR%..\..\")
echo   do ##class(AIAgent.Install.Installer).Run()
echo.
echo Or for a one-step deploy:
echo   do $system.OBJ.Load("%IRIS_DIR%\mgr\%NAMESPACE%\ImportAll.cls", "ck")
echo   do ##class(AIAgent.Deploy.ImportAll).QuickDeploy("%TARGET_DIR%..\..\")
echo.
echo ================================================================
pause
