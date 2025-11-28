@echo off
REM =========================================
REM   WinRM Configuration Script
REM   For InfraMonitor Agent Installation
REM   This script must be run as Administrator
REM =========================================
REM
REM Usage: Right-click and "Run as Administrator"

echo =========================================
echo   WinRM Configuration Script
echo   For InfraMonitor Agent Installation
echo =========================================
echo.

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator!
    echo Right-click this file and select "Run as Administrator"
    pause
    exit /b 1
)

echo Running WinRM configuration...
echo.

REM Execute PowerShell commands inline
powershell -ExecutionPolicy Bypass -NoProfile -Command ^
"^
$ErrorActionPreference = 'Stop'; ^
Write-Host '=========================================' -ForegroundColor Cyan; ^
Write-Host '  WinRM Configuration Script' -ForegroundColor Cyan; ^
Write-Host '  For InfraMonitor Agent Installation' -ForegroundColor Cyan; ^
Write-Host '=========================================' -ForegroundColor Cyan; ^
Write-Host ''; ^
Write-Host '[1/6] Enabling PSRemoting...' -ForegroundColor Green; ^
try { ^
    Enable-PSRemoting -Force -ErrorAction Stop; ^
    Write-Host '  [OK] PSRemoting enabled successfully' -ForegroundColor Green; ^
} catch { ^
    Write-Host '  [ERROR] Failed to enable PSRemoting:' $_.Exception.Message -ForegroundColor Red; ^
    exit 1; ^
}; ^
Write-Host ''; ^
Write-Host '[2/6] Creating Windows Firewall rule for WinRM (port 5985)...' -ForegroundColor Green; ^
try { ^
    $existingRule = Get-NetFirewallRule -DisplayName 'Windows Remote Management (HTTP-In)' -ErrorAction SilentlyContinue; ^
    if ($existingRule) { ^
        Write-Host '  [INFO] Firewall rule already exists, ensuring it is enabled...' -ForegroundColor Yellow; ^
        Enable-NetFirewallRule -DisplayName 'Windows Remote Management (HTTP-In)' -ErrorAction SilentlyContinue; ^
    } else { ^
        $firewallParams = @{ ^
            Action      = 'Allow'; ^
            Description = 'Inbound rule for Windows Remote Management via WS-Management. [TCP 5985]'; ^
            Direction   = 'Inbound'; ^
            DisplayName = 'Windows Remote Management (HTTP-In)'; ^
            LocalPort   = 5985; ^
            Profile     = 'Any'; ^
            Protocol    = 'TCP'; ^
        }; ^
        New-NetFirewallRule @firewallParams -ErrorAction Stop; ^
        Write-Host '  [OK] Firewall rule created successfully' -ForegroundColor Green; ^
    }; ^
} catch { ^
    Write-Host '  [ERROR] Failed to create firewall rule:' $_.Exception.Message -ForegroundColor Red; ^
    Write-Host '  [INFO] You may need to manually allow port 5985 in Windows Firewall' -ForegroundColor Yellow; ^
}; ^
Write-Host ''; ^
Write-Host '[3/6] Configuring LocalAccountTokenFilterPolicy...' -ForegroundColor Green; ^
try { ^
    if (-not (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System')) { ^
        New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Force | Out-Null; ^
    }; ^
    $tokenFilterParams = @{ ^
        Path         = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; ^
        Name         = 'LocalAccountTokenFilterPolicy'; ^
        Value        = 1; ^
        PropertyType = 'DWORD'; ^
        Force        = $true; ^
    }; ^
    New-ItemProperty @tokenFilterParams -ErrorAction Stop | Out-Null; ^
    Write-Host '  [OK] LocalAccountTokenFilterPolicy set to 1' -ForegroundColor Green; ^
} catch { ^
    Write-Host '  [ERROR] Failed to set LocalAccountTokenFilterPolicy:' $_.Exception.Message -ForegroundColor Red; ^
    Write-Host '  [INFO] This may prevent local admin accounts from working with WinRM' -ForegroundColor Yellow; ^
}; ^
Write-Host ''; ^
Write-Host '[4/6] Configuring WinRM service authentication...' -ForegroundColor Green; ^
try { ^
    winrm set winrm/config/service/auth '@{Basic=\"true\"}' | Out-Null; ^
    Write-Host '  [OK] Basic authentication enabled' -ForegroundColor Green; ^
    winrm set winrm/config/service '@{AllowUnencrypted=\"true\"}' | Out-Null; ^
    Write-Host '  [OK] Unencrypted connections allowed' -ForegroundColor Green; ^
} catch { ^
    Write-Host '  [ERROR] Failed to configure WinRM service:' $_.Exception.Message -ForegroundColor Red; ^
    exit 1; ^
}; ^
Write-Host ''; ^
Write-Host '[5/6] Configuring WinRM client...' -ForegroundColor Green; ^
try { ^
    winrm set winrm/config/client/auth '@{Basic=\"true\"}' | Out-Null; ^
    Write-Host '  [OK] Client Basic authentication enabled' -ForegroundColor Green; ^
    winrm set winrm/config/client '@{AllowUnencrypted=\"true\"}' | Out-Null; ^
    Write-Host '  [OK] Client unencrypted connections allowed' -ForegroundColor Green; ^
} catch { ^
    Write-Host '  [ERROR] Failed to configure WinRM client:' $_.Exception.Message -ForegroundColor Red; ^
    exit 1; ^
}; ^
Write-Host ''; ^
Write-Host '[6/6] Verifying WinRM configuration...' -ForegroundColor Green; ^
try { ^
    Restart-Service WinRM -ErrorAction Stop; ^
    Write-Host '  [OK] WinRM service restarted' -ForegroundColor Green; ^
    $winrmStatus = Get-Service WinRM; ^
    if ($winrmStatus.Status -eq 'Running') { ^
        Write-Host '  [OK] WinRM service is running' -ForegroundColor Green; ^
    } else { ^
        Write-Host '  [ERROR] WinRM service is not running' -ForegroundColor Red; ^
        exit 1; ^
    }; ^
    $winrmConfig = winrm get winrm/config; ^
    if ($winrmConfig) { ^
        Write-Host '  [OK] WinRM configuration verified' -ForegroundColor Green; ^
    }; ^
} catch { ^
    Write-Host '  [ERROR] Failed to verify WinRM:' $_.Exception.Message -ForegroundColor Red; ^
    exit 1; ^
}; ^
Write-Host ''; ^
Write-Host '=========================================' -ForegroundColor Cyan; ^
Write-Host '  WinRM Configuration Complete!' -ForegroundColor Green; ^
Write-Host '=========================================' -ForegroundColor Cyan; ^
Write-Host ''; ^
Write-Host 'WinRM is now configured and ready for:' -ForegroundColor White; ^
Write-Host '  - Ansible automation' -ForegroundColor White; ^
Write-Host '  - InfraMonitor agent installation' -ForegroundColor White; ^
Write-Host '  - Remote management' -ForegroundColor White; ^
Write-Host ''; ^
Write-Host 'Configuration Summary:' -ForegroundColor Yellow; ^
Write-Host '  Port: 5985 (HTTP)' -ForegroundColor White; ^
Write-Host '  Authentication: Basic' -ForegroundColor White; ^
Write-Host '  Encryption: Unencrypted (for Basic auth over HTTP)' -ForegroundColor White; ^
Write-Host ''; ^
Write-Host 'Security Note:' -ForegroundColor Yellow; ^
Write-Host '  This configuration allows unencrypted connections.' -ForegroundColor White; ^
Write-Host '  For production, consider using HTTPS (port 5986) with certificates.' -ForegroundColor White; ^
Write-Host ''
"

if %errorLevel% neq 0 (
    echo.
    echo Configuration failed. Check the errors above.
    pause
    exit /b 1
)

echo.
echo Configuration completed successfully!
echo.
pause
