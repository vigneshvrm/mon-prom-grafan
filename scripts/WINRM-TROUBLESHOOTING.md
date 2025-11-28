# WinRM Authentication Troubleshooting Guide

## Error: "basic: the specified credentials were rejected by the server"

This error means WinRM is rejecting your credentials even though they work for RDP. This is a **configuration issue**, not a credential issue.

## Quick Fix Steps

### Step 1: Run the Configuration Script

1. **Right-click** `configure-winrm.bat`
2. Select **"Run as Administrator"**
3. Wait for it to complete (should show progress messages)
4. If it exits immediately, see "Script Exits Immediately" section below

### Step 2: Run Diagnostic Script

1. **Right-click** `configure-winrm-diagnose.bat`
2. Select **"Run as Administrator"**
3. Review the output - it will show what's wrong

### Step 3: Manual Verification

Open PowerShell as Administrator and run:

```powershell
# Check if LocalAccountTokenFilterPolicy is set (CRITICAL!)
Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy

# Should show: LocalAccountTokenFilterPolicy : 1
# If missing or 0, that's your problem!
```

If it's missing or 0, run this:

```powershell
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy -Value 1 -PropertyType DWORD -Force
```

## Common Issues

### Issue 1: Script Exits Immediately

**Symptoms:** The .bat file opens and closes instantly

**Causes:**
- PowerShell execution policy blocking
- Syntax error in the script
- Missing PowerShell modules

**Solutions:**

1. **Run from Command Prompt (as Admin):**
   ```cmd
   cd C:\path\to\scripts
   configure-winrm.bat
   ```
   This will show any error messages.

2. **Check PowerShell Execution Policy:**
   ```powershell
   Get-ExecutionPolicy
   ```
   If it's "Restricted", run:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Run PowerShell commands manually:**
   Open PowerShell as Administrator and run each step from the script manually.

### Issue 2: LocalAccountTokenFilterPolicy Not Set

**This is the #1 cause of authentication failures!**

**Check:**
```powershell
Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy -ErrorAction SilentlyContinue
```

**Fix:**
```powershell
# Create registry key if path doesn't exist
if (-not (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System')) {
    New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Force
}

# Set the policy
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy -Value 1 -PropertyType DWORD -Force
```

**Restart WinRM after setting:**
```powershell
Restart-Service WinRM
```

### Issue 3: Basic Authentication Not Enabled

**Check:**
```powershell
winrm get winrm/config/service/auth
```

**Should show:** `Basic = true`

**Fix:**
```powershell
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
Restart-Service WinRM
```

### Issue 4: Firewall Blocking Port 5985

**Check:**
```powershell
Get-NetFirewallRule -DisplayName "*WinRM*"
```

**Fix:**
```powershell
New-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow
```

## Manual Configuration (If Script Fails)

Run these commands in PowerShell **as Administrator**:

```powershell
# 1. Enable PSRemoting
Enable-PSRemoting -Force

# 2. Create firewall rule
New-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" `
    -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow

# 3. Set LocalAccountTokenFilterPolicy (CRITICAL!)
if (-not (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System')) {
    New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Force
}
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
    -Name LocalAccountTokenFilterPolicy -Value 1 -PropertyType DWORD -Force

# 4. Configure WinRM authentication
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/client '@{AllowUnencrypted="true"}'

# 5. Restart WinRM
Restart-Service WinRM

# 6. Verify
winrm get winrm/config/service/auth
Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy
```

## Testing WinRM Connection

### From Windows (on the same machine):
```powershell
winrm id
```

### From Windows (remote):
```cmd
winrs -r:http://TARGET_IP:5985/wsman -u:Administrator -p:YOUR_PASSWORD ipconfig
```

### From Linux/Ansible:
```bash
ansible windows-server -i inventory.yml -m win_ping \
    -e "ansible_user=Administrator" \
    -e "ansible_password=YourPassword" \
    -e "ansible_winrm_transport=basic" \
    -e "ansible_winrm_port=5985"
```

## Still Not Working?

1. **Check Event Viewer:**
   - Windows Logs → System
   - Look for WinRM errors

2. **Check if UAC is blocking:**
   - Some Windows versions require UAC to be configured properly

3. **Try using a domain account instead of local account** (if available)

4. **Check if account is locked or disabled:**
   ```powershell
   Get-LocalUser -Name Administrator
   ```

5. **Verify the account has admin rights:**
   ```powershell
   net localgroup administrators
   ```

## Important Notes

- **LocalAccountTokenFilterPolicy = 1** is REQUIRED for local admin accounts
- Basic authentication over HTTP requires `AllowUnencrypted = true`
- The account must be a member of the Administrators group
- Some Windows Server versions require additional configuration

## Reference

- [Ansible WinRM Setup Guide](https://docs.ansible.com/projects/ansible/latest/os_guide/windows_winrm.html)
- [Microsoft WinRM Documentation](https://docs.microsoft.com/en-us/windows/win32/winrm/installation-and-configuration-for-windows-remote-management)

