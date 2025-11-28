# Fix Windows Exporter Firewall Rule
# Run this on Windows server to ensure port 9100 is accessible externally

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Windows Exporter Firewall Fix" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$port = 9100

Write-Host "[1] Checking existing firewall rules..." -ForegroundColor Yellow
$existingRules = Get-NetFirewallRule -DisplayName "*$port*" -ErrorAction SilentlyContinue
if ($existingRules) {
    Write-Host "  Found existing rules:" -ForegroundColor White
    $existingRules | ForEach-Object {
        Write-Host "    - $($_.DisplayName) (Enabled: $($_.Enabled))" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "  Removing existing rules..." -ForegroundColor Yellow
    $existingRules | Remove-NetFirewallRule -ErrorAction SilentlyContinue
}

Write-Host "[2] Creating firewall rule for port $port..." -ForegroundColor Yellow
try {
    New-NetFirewallRule -DisplayName "Windows Exporter $port" `
        -Direction Inbound `
        -LocalPort $port `
        -Protocol TCP `
        -Action Allow `
        -Profile Domain,Private,Public `
        -Enabled True `
        -ErrorAction Stop
    
    Write-Host "  [OK] Firewall rule created successfully" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Failed to create firewall rule: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[3] Verifying firewall rule..." -ForegroundColor Yellow
$rule = Get-NetFirewallRule -DisplayName "Windows Exporter $port" -ErrorAction SilentlyContinue
if ($rule -and $rule.Enabled) {
    Write-Host "  [OK] Firewall rule is ENABLED" -ForegroundColor Green
    
    # Get associated port filter
    $portFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $rule
    Write-Host "    Port: $($portFilter.LocalPort)" -ForegroundColor White
    Write-Host "    Protocol: $($portFilter.Protocol)" -ForegroundColor White
    Write-Host "    Profiles: $($rule.Profile -join ', ')" -ForegroundColor White
} else {
    Write-Host "  [ERROR] Firewall rule not found or disabled!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[4] Testing local endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:$port/metrics" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  [OK] Local endpoint is accessible (Status: $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Local endpoint test failed: $_" -ForegroundColor Red
    Write-Host "  Windows Exporter service may not be running correctly." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Firewall Configuration Complete" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Port $port should now be accessible from external hosts." -ForegroundColor Green
Write-Host ""
Write-Host "To test from another machine:" -ForegroundColor Yellow
Write-Host "  curl http://<windows-server-ip>:$port/metrics" -ForegroundColor White
Write-Host ""

