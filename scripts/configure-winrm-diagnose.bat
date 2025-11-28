@echo off
setlocal enabledelayedexpansion
REM =========================================
REM   WinRM Diagnostic Script
REM   Checks WinRM configuration status
REM =========================================

title WinRM Diagnostic Tool

echo =========================================
echo   WinRM Diagnostic Tool
echo =========================================
echo.

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [WARNING] Not running as Administrator - some checks may fail
    echo.
)

echo Running diagnostics...
echo.

REM Create a temporary PowerShell script file
set "PS_SCRIPT=%TEMP%\diagnose_winrm_%RANDOM%.ps1"

REM Write PowerShell script to file using echo (escaping special chars)
(
echo Write-Host '=========================================' -ForegroundColor Cyan
echo Write-Host '  WinRM Configuration Diagnostics' -ForegroundColor Cyan
echo Write-Host '=========================================' -ForegroundColor Cyan
echo Write-Host ''
echo Write-Host '[1] Checking WinRM Service Status...' -ForegroundColor Yellow
echo $service = Get-Service WinRM -ErrorAction SilentlyContinue
echo if ^($service^) {
echo     if ^($service.Status -eq 'Running'^) {
echo         Write-Host '  [OK] WinRM service is RUNNING' -ForegroundColor Green
echo     } else {
echo         Write-Host '  [ERROR] WinRM service is NOT running. Status:' $service.Status -ForegroundColor Red
echo         Write-Host '  [INFO] Try: Start-Service WinRM' -ForegroundColor Yellow
echo     }
echo } else {
echo     Write-Host '  [ERROR] WinRM service not found!' -ForegroundColor Red
echo }
echo Write-Host ''
echo Write-Host '[2] Checking WinRM Listeners...' -ForegroundColor Yellow
echo try {
echo     $listeners = winrm enumerate winrm/config/Listener 2^>^&1
echo     if ^($listeners -match 'Transport.*HTTP'^) {
echo         Write-Host '  [OK] HTTP listener found ^(port 5985^)' -ForegroundColor Green
echo         $listeners ^| Select-String -Pattern 'Transport^|Address' ^| ForEach-Object { Write-Host ^('    ' + $_.Line^) -ForegroundColor Gray }
echo     } else {
echo         Write-Host '  [ERROR] HTTP listener NOT found!' -ForegroundColor Red
echo         Write-Host '  [INFO] Run: Enable-PSRemoting -Force' -ForegroundColor Yellow
echo     }
echo } catch {
echo     Write-Host '  [ERROR] Failed to check listeners:' $_.Exception.Message -ForegroundColor Red
echo }
echo Write-Host ''
echo Write-Host '[3] Checking Authentication Settings...' -ForegroundColor Yellow
echo try {
echo     $authConfig = winrm get winrm/config/service/auth 2^>^&1
echo     if ^($authConfig -match 'Basic.*=.*true'^) {
echo         Write-Host '  [OK] Basic authentication is ENABLED' -ForegroundColor Green
echo     } else {
echo         Write-Host '  [ERROR] Basic authentication is NOT enabled!' -ForegroundColor Red
echo         Write-Host '  [INFO] Run: winrm set winrm/config/service/auth @{Basic="true"}' -ForegroundColor Yellow
echo     }
echo } catch {
echo     Write-Host '  [ERROR] Failed to check auth config:' $_.Exception.Message -ForegroundColor Red
echo }
echo Write-Host ''
echo Write-Host '[4] Checking AllowUnencrypted Setting...' -ForegroundColor Yellow
echo try {
echo     $serviceConfig = winrm get winrm/config/service 2^>^&1
echo     if ^($serviceConfig -match 'AllowUnencrypted.*=.*true'^) {
echo         Write-Host '  [OK] AllowUnencrypted is TRUE' -ForegroundColor Green
echo     } else {
echo         Write-Host '  [WARNING] AllowUnencrypted may not be set to true' -ForegroundColor Yellow
echo         Write-Host '  [INFO] Run: winrm set winrm/config/service @{AllowUnencrypted="true"}' -ForegroundColor Yellow
echo     }
echo } catch {
echo     Write-Host '  [ERROR] Failed to check service config:' $_.Exception.Message -ForegroundColor Red
echo }
echo Write-Host ''
echo Write-Host '[5] Checking LocalAccountTokenFilterPolicy ^(CRITICAL for local admin^)...' -ForegroundColor Yellow
echo try {
echo     $policy = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy -ErrorAction SilentlyContinue
echo     if ^($policy -and $policy.LocalAccountTokenFilterPolicy -eq 1^) {
echo         Write-Host '  [OK] LocalAccountTokenFilterPolicy = 1 ^(CORRECT^)' -ForegroundColor Green
echo     } else {
echo         Write-Host '  [ERROR] LocalAccountTokenFilterPolicy is NOT set to 1!' -ForegroundColor Red
echo         Write-Host '  [CRITICAL] This is REQUIRED for local administrator accounts!' -ForegroundColor Red
echo         Write-Host '  [INFO] Run configure-winrm.bat to fix this' -ForegroundColor Yellow
echo         Write-Host '  [INFO] Or run manually:' -ForegroundColor Yellow
echo         Write-Host '    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name LocalAccountTokenFilterPolicy -Value 1 -PropertyType DWORD -Force' -ForegroundColor Gray
echo     }
echo } catch {
echo     Write-Host '  [ERROR] Failed to check registry:' $_.Exception.Message -ForegroundColor Red
echo     Write-Host '  [INFO] Registry key may not exist - this is a problem!' -ForegroundColor Yellow
echo }
echo Write-Host ''
echo Write-Host '[6] Checking Firewall Rules...' -ForegroundColor Yellow
echo try {
echo     $firewallRules = Get-NetFirewallRule -DisplayName '*WinRM*' -ErrorAction SilentlyContinue
echo     if ^($firewallRules^) {
echo         Write-Host '  [OK] WinRM firewall rules found:' -ForegroundColor Green
echo         $firewallRules ^| ForEach-Object {
echo             $status = if ^($_.Enabled^) { 'ENABLED' } else { 'DISABLED' }
echo             $color = if ^($_.Enabled^) { 'Green' } else { 'Red' }
echo             Write-Host ^('    ' + $_.DisplayName + ' - ' + $status^) -ForegroundColor $color
echo         }
echo     } else {
echo         Write-Host '  [WARNING] No WinRM firewall rules found!' -ForegroundColor Yellow
echo         Write-Host '  [INFO] Port 5985 may be blocked' -ForegroundColor Yellow
echo     }
echo } catch {
echo     Write-Host '  [ERROR] Failed to check firewall:' $_.Exception.Message -ForegroundColor Red
echo }
echo Write-Host ''
echo Write-Host '[7] Testing Local WinRM Connection...' -ForegroundColor Yellow
echo try {
echo     $testResult = winrm id 2^>^&1
echo     if ^($LASTEXITCODE -eq 0^) {
echo         Write-Host '  [OK] Local WinRM connection works' -ForegroundColor Green
echo     } else {
echo         Write-Host '  [ERROR] Local WinRM connection failed' -ForegroundColor Red
echo         Write-Host '  [INFO] Error:' $testResult -ForegroundColor Yellow
echo     }
echo } catch {
echo     Write-Host '  [ERROR] Failed to test WinRM:' $_.Exception.Message -ForegroundColor Red
echo }
echo Write-Host ''
echo Write-Host '=========================================' -ForegroundColor Cyan
echo Write-Host '  Diagnostic Complete' -ForegroundColor Cyan
echo Write-Host '=========================================' -ForegroundColor Cyan
echo Write-Host ''
echo Write-Host 'If you see any [ERROR] items above, those need to be fixed.' -ForegroundColor Yellow
echo Write-Host 'Run configure-winrm.bat as Administrator to fix configuration issues.' -ForegroundColor Yellow
echo Write-Host ''
) > "%PS_SCRIPT%"

REM Execute the PowerShell script
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%PS_SCRIPT%"

REM Clean up
del "%PS_SCRIPT%" >nul 2>&1

echo.
pause
