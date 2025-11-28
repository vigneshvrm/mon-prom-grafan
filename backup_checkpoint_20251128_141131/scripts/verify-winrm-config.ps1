# Quick verification script for WinRM configuration
# Run this on Windows server to verify everything is set correctly

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  WinRM Configuration Verification" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1] Checking LocalAccountTokenFilterPolicy..." -ForegroundColor Yellow
$policy = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy -ErrorAction SilentlyContinue
if ($policy -and $policy.LocalAccountTokenFilterPolicy -eq 1) {
    Write-Host "  [OK] LocalAccountTokenFilterPolicy = 1" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] LocalAccountTokenFilterPolicy is NOT set to 1!" -ForegroundColor Red
    Write-Host "  This will cause authentication failures!" -ForegroundColor Red
}
Write-Host ""

Write-Host "[2] Checking WinRM Service..." -ForegroundColor Yellow
$service = Get-Service WinRM -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq 'Running') {
    Write-Host "  [OK] WinRM service is RUNNING" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] WinRM service is not running!" -ForegroundColor Red
}
Write-Host ""

Write-Host "[3] Checking WinRM Listeners..." -ForegroundColor Yellow
$listeners = winrm enumerate winrm/config/Listener 2>&1
if ($listeners -match 'Transport.*HTTP') {
    Write-Host "  [OK] HTTP listener (port 5985) is configured" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] HTTP listener not found!" -ForegroundColor Red
}
Write-Host ""

Write-Host "[4] Checking Basic Authentication..." -ForegroundColor Yellow
$auth = winrm get winrm/config/service/auth 2>&1
if ($auth -match 'Basic.*=.*true') {
    Write-Host "  [OK] Basic authentication is ENABLED" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Basic authentication is NOT enabled!" -ForegroundColor Red
}
Write-Host ""

Write-Host "[5] Checking Firewall..." -ForegroundColor Yellow
$firewall = Get-NetFirewallRule -DisplayName "*WinRM*" -ErrorAction SilentlyContinue
if ($firewall) {
    $enabled = $firewall | Where-Object { $_.Enabled -eq $true }
    if ($enabled) {
        Write-Host "  [OK] WinRM firewall rules are ENABLED" -ForegroundColor Green
    } else {
        Write-Host "  [WARNING] WinRM firewall rules exist but may be disabled" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [WARNING] No WinRM firewall rules found" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Verification Complete" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if ($policy -and $policy.LocalAccountTokenFilterPolicy -eq 1 -and $service -and $service.Status -eq 'Running') {
    Write-Host "WinRM is properly configured!" -ForegroundColor Green
    Write-Host "You can now proceed with Windows Exporter installation." -ForegroundColor Green
} else {
    Write-Host "WinRM configuration has issues. Please fix them before proceeding." -ForegroundColor Red
}
Write-Host ""

