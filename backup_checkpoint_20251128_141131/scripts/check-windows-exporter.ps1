# PowerShell script to check Windows Exporter status
# Run this on the Windows server to diagnose issues

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Windows Exporter Diagnostic Tool" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1] Checking Windows Exporter Service..." -ForegroundColor Yellow
$service = Get-Service windows_exporter -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "  Service Name: $($service.Name)" -ForegroundColor White
    Write-Host "  Service Status: $($service.Status)" -ForegroundColor $(if ($service.Status -eq 'Running') { 'Green' } else { 'Red' })
    Write-Host "  Start Type: $($service.StartType)" -ForegroundColor White
} else {
    Write-Host "  [ERROR] Windows Exporter service NOT FOUND!" -ForegroundColor Red
    Write-Host "  Windows Exporter is not installed." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
Write-Host ""

Write-Host "[2] Checking if port 9100 is listening..." -ForegroundColor Yellow
$port = Get-NetTCPConnection -LocalPort 9100 -ErrorAction SilentlyContinue
if ($port) {
    Write-Host "  [OK] Port 9100 is LISTENING" -ForegroundColor Green
    Write-Host "    State: $($port.State)" -ForegroundColor White
    Write-Host "    Local Address: $($port.LocalAddress):$($port.LocalPort)" -ForegroundColor White
} else {
    Write-Host "  [ERROR] Port 9100 is NOT listening!" -ForegroundColor Red
    Write-Host "  Windows Exporter service may not be running correctly." -ForegroundColor Yellow
}
Write-Host ""

Write-Host "[3] Testing HTTP endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:9100/metrics" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  [OK] HTTP endpoint is ACCESSIBLE" -ForegroundColor Green
    Write-Host "    Status Code: $($response.StatusCode)" -ForegroundColor White
    Write-Host "    Content Length: $($response.Content.Length) bytes" -ForegroundColor White
    Write-Host "    First 200 chars of response:" -ForegroundColor Gray
    Write-Host "    $($response.Content.Substring(0, [Math]::Min(200, $response.Content.Length)))" -ForegroundColor Gray
} catch {
    Write-Host "  [ERROR] HTTP endpoint is NOT accessible!" -ForegroundColor Red
    Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Yellow
    if ($_.Exception.Response) {
        Write-Host "    HTTP Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
    }
}
Write-Host ""

Write-Host "[4] Checking Windows Firewall..." -ForegroundColor Yellow
$firewallRule = Get-NetFirewallRule -DisplayName "*9100*" -ErrorAction SilentlyContinue
if ($firewallRule) {
    Write-Host "  [OK] Firewall rule found:" -ForegroundColor Green
    $firewallRule | ForEach-Object {
        $status = if ($_.Enabled) { 'ENABLED' } else { 'DISABLED' }
        $color = if ($_.Enabled) { 'Green' } else { 'Red' }
        Write-Host "    $($_.DisplayName) - $status" -ForegroundColor $color
    }
} else {
    Write-Host "  [WARNING] No firewall rule found for port 9100!" -ForegroundColor Yellow
    Write-Host "  Port may be blocked by Windows Firewall." -ForegroundColor Yellow
}
Write-Host ""

Write-Host "[5] Checking service configuration..." -ForegroundColor Yellow
$serviceConfig = Get-WmiObject -Class Win32_Service -Filter "Name='windows_exporter'"
if ($serviceConfig) {
    Write-Host "  Service Path: $($serviceConfig.PathName)" -ForegroundColor White
    Write-Host "  Start Mode: $($serviceConfig.StartMode)" -ForegroundColor White
    Write-Host "  State: $($serviceConfig.State)" -ForegroundColor White
    Write-Host "  Status: $($serviceConfig.Status)" -ForegroundColor White
    
    # Check if port is in the service arguments
    if ($serviceConfig.PathName -match "LISTEN_PORT") {
        Write-Host "  [OK] Port configuration found in service arguments" -ForegroundColor Green
    } else {
        Write-Host "  [WARNING] Port configuration not found in service arguments" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [ERROR] Could not retrieve service configuration" -ForegroundColor Red
}
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Diagnostic Complete" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if ($service -and $service.Status -eq 'Running' -and $port -and $response) {
    Write-Host "Windows Exporter appears to be working correctly!" -ForegroundColor Green
} else {
    Write-Host "Windows Exporter has issues. Check the errors above." -ForegroundColor Red
    Write-Host ""
    Write-Host "Common fixes:" -ForegroundColor Yellow
    Write-Host "  1. If service is not running: Start-Service windows_exporter" -ForegroundColor White
    Write-Host "  2. If port is not listening: Restart-Service windows_exporter" -ForegroundColor White
    Write-Host "  3. If firewall is blocking: Run configure-winrm.bat" -ForegroundColor White
    Write-Host "  4. If service doesn't exist: Re-run the installation playbook" -ForegroundColor White
}
Write-Host ""

