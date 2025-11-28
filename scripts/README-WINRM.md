# WinRM Configuration for Windows Servers

This directory contains scripts to configure Windows Remote Management (WinRM) on Windows servers to allow Ansible and InfraMonitor to connect and install the Node Exporter agent.

## Quick Start

### Option 1: PowerShell Script (Recommended)

1. **Right-click** `configure-winrm.ps1`
2. Select **"Run with PowerShell"** (must be as Administrator)
3. Follow the on-screen instructions

Or run from PowerShell (as Administrator):
```powershell
cd scripts
.\configure-winrm.ps1
```

### Option 2: Batch File (Easier for non-technical users)

1. **Right-click** `configure-winrm.bat`
2. Select **"Run as Administrator"**
3. The script will automatically run the PowerShell configuration

## What the Script Does

1. **Enables PSRemoting** - Allows PowerShell remote sessions
2. **Creates Firewall Rule** - Opens port 5985 for WinRM HTTP
3. **Configures WinRM Service** - Enables Basic authentication and unencrypted connections
4. **Configures WinRM Client** - Allows client connections with Basic auth
5. **Verifies Configuration** - Restarts WinRM service and verifies it's working

## Requirements

- **Windows Server 2012 or later** (or Windows 10/11)
- **Administrator privileges** (required)
- **PowerShell 3.0 or later** (included in Windows Server 2012+)

## Configuration Details

After running the script, WinRM will be configured with:

- **Port**: 5985 (HTTP)
- **Authentication**: Basic
- **Encryption**: Unencrypted (required for Basic auth over HTTP)

## Security Considerations

⚠️ **Important**: This configuration allows unencrypted connections for simplicity. 

For production environments, consider:

1. **Use HTTPS (port 5986)** with certificates
2. **Use Kerberos authentication** instead of Basic
3. **Restrict firewall rules** to specific source IPs
4. **Use Group Policy** to manage WinRM settings centrally

## Manual Configuration (Alternative)

If you prefer to configure WinRM manually, run these commands in PowerShell (as Administrator):

```powershell
# Enable PSRemoting
Enable-PSRemoting -Force

# Create firewall rule
New-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" `
    -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow

# Configure WinRM service
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

# Configure WinRM client
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/client '@{AllowUnencrypted="true"}'

# Restart WinRM
Restart-Service WinRM
```

## Verification

After configuration, verify WinRM is working:

```powershell
# Check WinRM service status
Get-Service WinRM

# Test WinRM locally
winrm quickconfig

# View WinRM configuration
winrm get winrm/config
```

## Troubleshooting

### "Access Denied" Error
- Ensure you're running as Administrator
- Right-click the script and select "Run as Administrator"

### "Execution Policy" Error
- Run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
- Or use the batch file which bypasses execution policy

### Firewall Blocking
- Check Windows Firewall is not blocking port 5985
- Verify the firewall rule was created: `Get-NetFirewallRule -DisplayName "*WinRM*"`

### WinRM Service Not Starting
- Check Event Viewer for errors
- Verify Windows Remote Management service is enabled
- Run: `Get-Service WinRM | Start-Service`

## Testing Connection

From the InfraMonitor server, test the connection:

```bash
# Test WinRM connection (from Linux/Ansible server)
ansible windows-server -i inventory.yml -m win_ping \
    -e "ansible_user=Administrator" \
    -e "ansible_password=YourPassword" \
    -e "ansible_winrm_transport=basic" \
    -e "ansible_winrm_port=5985"
```

## Related Files

- `playbooks/configure-winrm.yml` - Ansible playbook that performs the same configuration
- `playbooks/windows-node-exporter.yml` - Installs Node Exporter on Windows

