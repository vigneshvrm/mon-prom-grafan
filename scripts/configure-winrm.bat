@echo off
setlocal enabledelayedexpansion
REM =========================================
REM   WinRM Configuration Script
REM   For InfraMonitor Agent Installation
REM   This script must be run as Administrator
REM =========================================

title WinRM Configuration Script

echo =========================================
echo   WinRM Configuration Script
echo   For InfraMonitor Agent Installation
echo =========================================
echo.

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] This script must be run as Administrator!
    echo.
    echo Right-click this file and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)

echo [OK] Running as Administrator
echo [INFO] Starting WinRM configuration...
echo.
echo This may take a minute. Please wait...
echo.

REM Create a temporary PowerShell script file
set "PS_SCRIPT=%TEMP%\configure_winrm_%RANDOM%.ps1"

REM Write PowerShell script to file (escaping special chars)
(
echo $ErrorActionPreference = 'Continue'
echo Write-Host '=========================================' -ForegroundColor Cyan
echo Write-Host '  WinRM Configuration Script' -ForegroundColor Cyan
echo Write-Host '  For InfraMonitor Agent Installation' -ForegroundColor Cyan
echo Write-Host '=========================================' -ForegroundColor Cyan
echo Write-Host ''
echo Write-Host '[1/6] Enabling PSRemoting...' -ForegroundColor Green
echo try {
echo     Enable-PSRemoting -Force -ErrorAction Stop
echo     Write-Host '  [OK] PSRemoting enabled successfully' -ForegroundColor Green
echo } catch {
echo     Write-Host '  [ERROR] Failed to enable PSRemoting:' $_.Exception.Message -ForegroundColor Red
echo     exit 1
echo }
echo Write-Host ''
echo Write-Host '[2/6] Creating Windows Firewall rule for WinRM ^(port 5985^)...' -ForegroundColor Green
echo try {
echo     $existingRule = Get-NetFirewallRule -DisplayName 'Windows Remote Management ^(HTTP-In^)' -ErrorAction SilentlyContinue
echo     if ^($existingRule^) {
echo         Write-Host '  [INFO] Firewall rule already exists, ensuring it is enabled...' -ForegroundColor Yellow
echo         Enable-NetFirewallRule -DisplayName 'Windows Remote Management ^(HTTP-In^)' -ErrorAction SilentlyContinue
echo     } else {
echo         $firewallParams = @{
echo             Action      = 'Allow'
echo             Description = 'Inbound rule for Windows Remote Management via WS-Management. [TCP 5985]'
echo             Direction   = 'Inbound'
echo             DisplayName = 'Windows Remote Management ^(HTTP-In^)'
echo             LocalPort   = 5985
echo             Profile     = 'Any'
echo             Protocol    = 'TCP'
echo         }
echo         New-NetFirewallRule @firewallParams -ErrorAction Stop
echo         Write-Host '  [OK] Firewall rule created successfully' -ForegroundColor Green
echo     }
echo } catch {
echo     Write-Host '  [ERROR] Failed to create firewall rule:' $_.Exception.Message -ForegroundColor Red
echo     Write-Host '  [INFO] You may need to manually allow port 5985 in Windows Firewall' -ForegroundColor Yellow
echo }
echo Write-Host ''
echo Write-Host '[3/6] Configuring LocalAccountTokenFilterPolicy ^(CRITICAL^)...' -ForegroundColor Green
echo try {
echo     if ^(-not ^(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'^)^) {
echo         New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Force ^| Out-Null
echo     }
echo     $tokenFilterParams = @{
echo         Path         = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
echo         Name         = 'LocalAccountTokenFilterPolicy'
echo         Value        = 1
echo         PropertyType = 'DWORD'
echo         Force        = $true
echo     }
echo     New-ItemProperty @tokenFilterParams -ErrorAction Stop ^| Out-Null
echo     Write-Host '  [OK] LocalAccountTokenFilterPolicy set to 1' -ForegroundColor Green
echo } catch {
echo     Write-Host '  [ERROR] Failed to set LocalAccountTokenFilterPolicy:' $_.Exception.Message -ForegroundColor Red
echo     Write-Host '  [CRITICAL] This is REQUIRED for local admin accounts!' -ForegroundColor Red
echo     exit 1
echo }
echo Write-Host ''
echo Write-Host '[4/6] Configuring WinRM service authentication...' -ForegroundColor Green
echo try {
echo     winrm set winrm/config/service/auth '@{Basic="true"}' ^| Out-Null
echo     Write-Host '  [OK] Basic authentication enabled' -ForegroundColor Green
echo     winrm set winrm/config/service '@{AllowUnencrypted="true"}' ^| Out-Null
echo     Write-Host '  [OK] Unencrypted connections allowed' -ForegroundColor Green
echo } catch {
echo     Write-Host '  [ERROR] Failed to configure WinRM service:' $_.Exception.Message -ForegroundColor Red
echo     exit 1
echo }
echo Write-Host ''
echo Write-Host '[5/6] Configuring WinRM client...' -ForegroundColor Green
echo try {
echo     winrm set winrm/config/client/auth '@{Basic="true"}' ^| Out-Null
echo     Write-Host '  [OK] Client Basic authentication enabled' -ForegroundColor Green
echo     winrm set winrm/config/client '@{AllowUnencrypted="true"}' ^| Out-Null
echo     Write-Host '  [OK] Client unencrypted connections allowed' -ForegroundColor Green
echo } catch {
echo     Write-Host '  [ERROR] Failed to configure WinRM client:' $_.Exception.Message -ForegroundColor Red
echo     exit 1
echo }
echo Write-Host ''
echo Write-Host '[6/6] Verifying WinRM configuration...' -ForegroundColor Green
echo try {
echo     Restart-Service WinRM -ErrorAction Stop
echo     Write-Host '  [OK] WinRM service restarted' -ForegroundColor Green
echo     $winrmStatus = Get-Service WinRM
echo     if ^($winrmStatus.Status -eq 'Running'^) {
echo         Write-Host '  [OK] WinRM service is running' -ForegroundColor Green
echo     } else {
echo         Write-Host '  [ERROR] WinRM service is not running' -ForegroundColor Red
echo         exit 1
echo     }
echo     $winrmConfig = winrm get winrm/config 2^>^&1
echo     if ^($winrmConfig^) {
echo         Write-Host '  [OK] WinRM configuration verified' -ForegroundColor Green
echo     }
echo } catch {
echo     Write-Host '  [ERROR] Failed to verify WinRM:' $_.Exception.Message -ForegroundColor Red
echo     exit 1
echo }
echo Write-Host ''
echo Write-Host '=========================================' -ForegroundColor Cyan
echo Write-Host '  WinRM Configuration Complete!' -ForegroundColor Green
echo Write-Host '=========================================' -ForegroundColor Cyan
echo Write-Host ''
echo Write-Host 'WinRM is now configured and ready for:' -ForegroundColor White
echo Write-Host '  - Ansible automation' -ForegroundColor White
echo Write-Host '  - InfraMonitor agent installation' -ForegroundColor White
echo Write-Host '  - Remote management' -ForegroundColor White
echo Write-Host ''
echo Write-Host 'Configuration Summary:' -ForegroundColor Yellow
echo Write-Host '  Port: 5985 ^(HTTP^)' -ForegroundColor White
echo Write-Host '  Authentication: Basic' -ForegroundColor White
echo Write-Host '  Encryption: Unencrypted ^(for Basic auth over HTTP^)' -ForegroundColor White
echo Write-Host ''
echo Write-Host 'IMPORTANT: Verify LocalAccountTokenFilterPolicy is set to 1:' -ForegroundColor Yellow
echo Write-Host '  Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name LocalAccountTokenFilterPolicy' -ForegroundColor White
echo Write-Host ''
) > "%PS_SCRIPT%"

REM Execute the PowerShell script
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%PS_SCRIPT%"
set PS_EXIT_CODE=%errorLevel%

REM Clean up
del "%PS_SCRIPT%" >nul 2>&1

echo.
echo =========================================
if %PS_EXIT_CODE% equ 0 (
    echo   Configuration Completed Successfully!
    echo =========================================
    echo.
) else (
    echo   Configuration FAILED
    echo =========================================
    echo.
    echo Check the errors above for details.
    echo.
    echo Common issues:
    echo   - WinRM service might not be installed
    echo   - LocalAccountTokenFilterPolicy might not be set
    echo   - PowerShell execution policy might be blocking
    echo.
    echo Try running: configure-winrm-diagnose.bat
    echo Or use: configure-winrm-manual.ps1
    echo.
)

pause
exit /b %PS_EXIT_CODE%
