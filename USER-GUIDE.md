# InfraMonitor User Guide

Complete step-by-step guide for installing and using InfraMonitor to monitor your infrastructure.

---

## Table of Contents

1. [Installation](#installation)
   - [Option 1: Debian Package (.deb)](#option-1-debian-package-deb)
   - [Option 2: Tarball Package](#option-2-tarball-package)
2. [Accessing the Web Interface](#accessing-the-web-interface)
3. [Adding Servers to Monitor](#adding-servers-to-monitor)
   - [Adding Linux Servers](#adding-linux-servers)
   - [Adding Windows Servers](#adding-windows-servers)
4. [Verifying Installation](#verifying-installation)
5. [Troubleshooting](#troubleshooting)

---

## Installation

### Option 1: Debian Package (.deb) - Recommended

**Best for:** Debian/Ubuntu systems, professional deployments

#### Step 1: Download the Package

Download the `.deb` package file (e.g., `inframonitor_1.0.0_all.deb`)

#### Step 2: Install the Package

```bash
sudo dpkg -i inframonitor_1.0.0_all.deb
```

If dependencies are missing, install them:

```bash
sudo apt-get install -f
```

#### Step 3: Verify Installation

```bash
# Check service status
sudo systemctl status inframonitor.service

# Check Prometheus container
sudo podman ps
```

The installation is **completely automated** and runs silently. All components (Python dependencies, Prometheus, services) are installed automatically.

**Access the web interface:** Open your browser and go to `http://your-server-ip:5000`

---

### Option 2: Tarball Package

**Best for:** Manual installations, non-Debian systems

#### Step 1: Extract the Package

```bash
tar -xzf inframonitor-20251128-092327.tar.gz
cd inframonitor-20251128-092327
```

#### Step 2: Run the Installer

```bash
sudo ./INSTALL.sh
```

The installer will:
- Install required system packages (Python, Podman, sshpass, etc.)
- Create Python virtual environment
- Install Python dependencies
- Deploy Prometheus container
- Configure and start the InfraMonitor service

#### Step 3: Verify Installation

```bash
# Check service status
sudo systemctl status inframonitor.service

# Check Prometheus container
sudo podman ps
```

**Access the web interface:** Open your browser and go to `http://your-server-ip:5000`

---

## Accessing the Web Interface

1. **Open your web browser**
2. **Navigate to:** `http://your-server-ip:5000`
   - Replace `your-server-ip` with the IP address of the server where InfraMonitor is installed
   - Example: `http://192.168.1.100:5000` or `http://123.176.58.198:5000`

3. **You should see:**
   - Infrastructure Overview dashboard
   - Summary cards showing total nodes, health status, and Prometheus status
   - "Add Node" button in the top right

---

## Adding Servers to Monitor

### Adding Linux Servers

#### Prerequisites

- **SSH access** to the target Linux server
- **Username and password** (or SSH key) with sudo/root privileges
- **Port 22** (SSH) must be accessible from InfraMonitor server
- **Port 9100** will be opened automatically for Node Exporter

#### Step-by-Step Instructions

1. **Click the "+ Add Node" button** in the top right of the dashboard

2. **Fill in the server details:**
   - **Server Name:** A friendly name (e.g., `web-server-01`, `database-server`)
   - **Host/IP Address:** The IP address or hostname of the target server
   - **Username:** SSH username (e.g., `root`, `ubuntu`, `admin`)
   - **Password:** SSH password for the user
   - **Operating System:** Select `Linux`
   - **Port:** Leave as `22` (default SSH port)

3. **Click "Add Server"**

4. **Wait for installation:**
   - The system will connect to your server
   - Install Node Exporter automatically
   - Configure firewall rules
   - Start the monitoring service
   - This typically takes 1-2 minutes

5. **Verify status:**
   - The server should appear in the dashboard
   - Status should show "ONLINE" (green) when Node Exporter is running
   - If it shows "ERROR", see [Troubleshooting](#troubleshooting) section

#### What Gets Installed

- **Node Exporter:** Prometheus metrics exporter (runs on port 9100)
- **Firewall Rules:** Port 9100 is automatically opened
- **Systemd Service:** Node Exporter is configured to start on boot

---

### Adding Windows Servers

#### Prerequisites

- **WinRM access** to the target Windows server
- **Administrator account** credentials
- **Port 5985** (WinRM HTTP) must be accessible from InfraMonitor server
- **Port 9100** will be opened automatically for Windows Exporter

#### Step 1: Configure WinRM on Windows Server

**IMPORTANT:** WinRM must be configured on the Windows server **BEFORE** adding it to InfraMonitor.

##### Method 1: Using the Configuration Script (Recommended)

1. **Copy the script to Windows server:**
   - Copy `configure-winrm.bat` to the Windows server
   - You can download it or copy from the InfraMonitor server

2. **Run as Administrator:**
   - Right-click `configure-winrm.bat`
   - Select **"Run as Administrator"**
   - Wait for the configuration to complete (about 1 minute)

3. **Verify configuration:**
   ```powershell
   # Check if LocalAccountTokenFilterPolicy is set
   Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy
   
   # Should show: LocalAccountTokenFilterPolicy : 1
   ```

##### Method 2: Manual Configuration (If Script Fails)

If the script doesn't work, run these commands in PowerShell **as Administrator**:

```powershell
# 1. Enable PSRemoting
Enable-PSRemoting -Force

# 2. Create firewall rule for WinRM
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
Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy
```

**Troubleshooting WinRM Setup:**
- See `scripts/WINRM-TROUBLESHOOTING.md` for detailed troubleshooting
- Run `configure-winrm-diagnose.bat` to check configuration status

#### Step 2: Add Windows Server to InfraMonitor

1. **Click the "+ Add Node" button** in the top right of the dashboard

2. **Fill in the server details:**
   - **Server Name:** A friendly name (e.g., `windows-server-01`, `exchange-server`)
   - **Host/IP Address:** The IP address of the Windows server
   - **Username:** Windows Administrator username (e.g., `Administrator`)
   - **Password:** Windows Administrator password
   - **Operating System:** Select `Windows`
   - **Port:** 
     - Use `5985` for WinRM HTTP (recommended, simpler setup)
     - Use `5986` for WinRM HTTPS (requires certificates)

3. **Click "Add Server"**

4. **Wait for installation:**
   - The system will connect via WinRM
   - Download and install Windows Exporter
   - Configure firewall rules
   - Start the monitoring service
   - This typically takes 2-3 minutes

5. **Verify status:**
   - The server should appear in the dashboard
   - Status should show "ONLINE" (green) when Windows Exporter is running
   - If it shows "ERROR", see [Troubleshooting](#troubleshooting) section

#### What Gets Installed

- **Windows Exporter:** Prometheus metrics exporter for Windows (runs on port 9100)
- **Firewall Rules:** Port 9100 is automatically opened for external access
- **Windows Service:** Windows Exporter is configured to start automatically on boot

---

## Verifying Installation

### Check Server Status in Dashboard

1. **View the dashboard:**
   - Servers are listed in the "Monitored Servers" section
   - **Green border** = ONLINE (Node Exporter is running)
   - **Red border** = ERROR (Node Exporter is not accessible)

2. **Check individual server:**
   - Click on a server card to see details
   - View metrics and status information

### Manual Verification

#### Linux Server

```bash
# SSH to the Linux server
ssh user@server-ip

# Check Node Exporter service
sudo systemctl status node_exporter

# Check if port 9100 is listening
sudo netstat -tlnp | grep 9100
# Or
sudo ss -tlnp | grep 9100

# Test metrics endpoint
curl http://localhost:9100/metrics
```

#### Windows Server

```powershell
# Check Windows Exporter service
Get-Service windows_exporter

# Check if port 9100 is listening
netstat -an | findstr 9100

# Test metrics endpoint
Invoke-WebRequest -Uri http://localhost:9100/metrics
```

### Test from InfraMonitor Server

```bash
# Test Node Exporter on a monitored server
curl http://<server-ip>:9100/metrics

# Should return Prometheus metrics if working
```

---

## Troubleshooting

### Server Shows "ERROR" Status

#### For Linux Servers

1. **Check SSH connectivity:**
   ```bash
   # From InfraMonitor server
   ssh user@server-ip
   ```

2. **Check Node Exporter service:**
   ```bash
   # On the target Linux server
   sudo systemctl status node_exporter
   ```

3. **Check firewall:**
   ```bash
   # On the target Linux server
   sudo firewall-cmd --list-ports  # For firewalld
   # Or
   sudo ufw status  # For ufw
   ```

4. **Check port 9100:**
   ```bash
   # On the target Linux server
   curl http://localhost:9100/metrics
   ```

5. **Reinstall if needed:**
   - Remove the server from dashboard
   - Add it again to trigger reinstallation

#### For Windows Servers

1. **Check WinRM connectivity:**
   ```bash
   # From InfraMonitor server
   telnet <windows-ip> 5985
   ```

2. **Verify WinRM configuration:**
   - Run `configure-winrm-diagnose.bat` on Windows server
   - Ensure `LocalAccountTokenFilterPolicy = 1`

3. **Check Windows Exporter service:**
   ```powershell
   # On Windows server
   Get-Service windows_exporter
   ```

4. **Check firewall:**
   ```powershell
   # On Windows server
   Get-NetFirewallRule -DisplayName "*9100*"
   ```

5. **Fix firewall if needed:**
   ```powershell
   # On Windows server, run as Administrator
   .\fix-windows-exporter-firewall.ps1
   ```

6. **Reinstall if needed:**
   - Remove the server from dashboard
   - Add it again to trigger reinstallation

### Common Issues

#### Issue: "Credentials Rejected" (Windows)

**Cause:** `LocalAccountTokenFilterPolicy` not set to 1

**Solution:**
1. Run `configure-winrm.bat` on Windows server as Administrator
2. Verify: `Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy`
3. Should show: `LocalAccountTokenFilterPolicy : 1`

#### Issue: Port 9100 Not Accessible

**Cause:** Firewall blocking external access

**Solution (Linux):**
```bash
# On target Linux server
sudo firewall-cmd --add-port=9100/tcp --permanent
sudo firewall-cmd --reload
```

**Solution (Windows):**
```powershell
# On Windows server, run as Administrator
.\fix-windows-exporter-firewall.ps1
```

#### Issue: Service Not Starting

**Solution (Linux):**
```bash
# Check logs
sudo journalctl -u node_exporter -n 50

# Restart service
sudo systemctl restart node_exporter
```

**Solution (Windows):**
```powershell
# Check service
Get-Service windows_exporter

# Restart service
Restart-Service windows_exporter

# Check event logs
Get-EventLog -LogName Application -Source windows_exporter -Newest 10
```

### Getting Help

1. **Check logs:**
   ```bash
   # InfraMonitor service logs
   sudo journalctl -u inframonitor.service -f
   
   # Or check log file
   tail -f /var/log/inframonitor.log
   ```

2. **Enable debug mode:**
   ```bash
   # Edit service file
   sudo systemctl edit inframonitor.service
   
   # Add:
   [Service]
   Environment="DEBUG_MODE=true"
   
   # Reload and restart
   sudo systemctl daemon-reload
   sudo systemctl restart inframonitor.service
   ```

3. **Check health status via API:**
   ```bash
   # Get detailed health check
   curl http://localhost:5000/api/servers/<server-id>/health
   ```

---

## Quick Reference

### Installation Commands

**Debian Package:**
```bash
sudo dpkg -i inframonitor_1.0.0_all.deb
sudo apt-get install -f  # If dependencies needed
```

**Tarball:**
```bash
tar -xzf inframonitor-*.tar.gz
cd inframonitor-*
sudo ./INSTALL.sh
```

### Service Management

```bash
# Check status
sudo systemctl status inframonitor.service

# Start/Stop/Restart
sudo systemctl start inframonitor.service
sudo systemctl stop inframonitor.service
sudo systemctl restart inframonitor.service

# View logs
sudo journalctl -u inframonitor.service -f
```

### Windows WinRM Configuration

**Quick Setup:**
1. Copy `configure-winrm.bat` to Windows server
2. Right-click → Run as Administrator
3. Verify: `Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy`

### Accessing the Interface

- **URL:** `http://your-server-ip:5000`
- **Default Port:** 5000
- **No authentication required** (for local network use)

---

## Support Files

The following helper scripts are included:

- **`configure-winrm.bat`** - Windows WinRM configuration (run on Windows server)
- **`configure-winrm-diagnose.bat`** - Diagnose WinRM issues (run on Windows server)
- **`fix-windows-exporter-firewall.ps1`** - Fix Windows Exporter firewall (run on Windows server)
- **`check-windows-exporter.ps1`** - Check Windows Exporter status (run on Windows server)
- **`verify-winrm-config.ps1`** - Verify WinRM configuration (run on Windows server)

All scripts should be run **as Administrator** on the Windows server.

---

## Next Steps

After installation:

1. ✅ Install InfraMonitor (using .deb or tarball)
2. ✅ Access web interface at `http://your-server-ip:5000`
3. ✅ Configure WinRM on Windows servers (if monitoring Windows)
4. ✅ Add servers to monitor via web interface
5. ✅ Verify servers show as "ONLINE" in dashboard
6. ✅ View metrics and monitor your infrastructure

For detailed troubleshooting, see `DEBUG-GUIDE.md` and `WINRM-TROUBLESHOOTING.md`.


