# Manual WinRM Configuration Script
# Run this in PowerShell as Administrator if the .bat file doesn't work
# Copy and paste this entire script into PowerShell (as Administrator)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  WinRM Manual Configuration" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "[1/6] Enabling PSRemoting..." -ForegroundColor Green
Enable-PSRemoting -Force
Write-Host "  [OK] PSRemoting enabled" -ForegroundColor Green
Write-Host ""

Write-Host "[2/6] Creating Windows Firewall rule..." -ForegroundColor Green
$existingRule = Get-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -ErrorAction SilentlyContinue
if ($existingRule) {
    Enable-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -ErrorAction SilentlyContinue
    Write-Host "  [OK] Firewall rule enabled" -ForegroundColor Green
} else {
    $firewallParams = @{
        Action      = 'Allow'
        Description = 'Inbound rule for Windows Remote Management via WS-Management. [TCP 5985]'
        Direction   = 'Inbound'
        DisplayName = 'Windows Remote Management (HTTP-In)'
        LocalPort   = 5985
        Profile     = 'Any'
        Protocol    = 'TCP'
    }
    New-NetFirewallRule @firewallParams
    Write-Host "  [OK] Firewall rule created" -ForegroundColor Green
}
Write-Host ""

Write-Host "[3/6] Setting LocalAccountTokenFilterPolicy (CRITICAL)..." -ForegroundColor Green
if (-not (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System')) {
    New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Force | Out-Null
}
$tokenFilterParams = @{
    Path         = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    Name         = 'LocalAccountTokenFilterPolicy'
    Value        = 1
    PropertyType = 'DWORD'
    Force        = $true
}
New-ItemProperty @tokenFilterParams | Out-Null
Write-Host "  [OK] LocalAccountTokenFilterPolicy set to 1" -ForegroundColor Green
Write-Host ""

Write-Host "[4/6] Configuring WinRM service authentication..." -ForegroundColor Green
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
Write-Host "  [OK] Basic auth and unencrypted enabled" -ForegroundColor Green
Write-Host ""

Write-Host "[5/6] Configuring WinRM client..." -ForegroundColor Green
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/client '@{AllowUnencrypted="true"}'
Write-Host "  [OK] Client configured" -ForegroundColor Green
Write-Host ""

Write-Host "[6/6] Restarting WinRM service..." -ForegroundColor Green
Restart-Service WinRM
Write-Host "  [OK] WinRM service restarted" -ForegroundColor Green
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Configuration Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Verifying LocalAccountTokenFilterPolicy..." -ForegroundColor Yellow
$policy = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy
Write-Host "  Value: $($policy.LocalAccountTokenFilterPolicy)" -ForegroundColor $(if ($policy.LocalAccountTokenFilterPolicy -eq 1) { 'Green' } else { 'Red' })
Write-Host ""

Write-Host "Verifying Basic Auth..." -ForegroundColor Yellow
winrm get winrm/config/service/auth | Select-String "Basic"
Write-Host ""

Write-Host "WinRM is now configured!" -ForegroundColor Green
Write-Host ""

