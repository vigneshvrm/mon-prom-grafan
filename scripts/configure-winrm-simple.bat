@echo off
REM Simple WinRM Configuration - Uses PowerShell script file directly
REM This script must be run as Administrator

title WinRM Configuration

echo =========================================
echo   WinRM Configuration Script
echo =========================================
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Must run as Administrator!
    echo Right-click and select "Run as Administrator"
    pause
    exit /b 1
)

echo [OK] Running as Administrator
echo.

REM Check if the PowerShell script exists
if exist "%~dp0configure-winrm-manual.ps1" (
    echo Running PowerShell configuration script...
    echo.
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0configure-winrm-manual.ps1"
) else (
    echo [ERROR] configure-winrm-manual.ps1 not found!
    echo Please ensure both files are in the same directory.
    echo.
    echo You can run the PowerShell commands manually:
    echo 1. Open PowerShell as Administrator
    echo 2. Copy and paste the commands from WINRM-TROUBLESHOOTING.md
    echo.
)

echo.
pause

