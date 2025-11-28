# InfraMonitor Quick Start Guide

Get up and running in 5 minutes!

---

## Installation (Choose One Method)

### Method 1: Debian Package (Recommended)

```bash
sudo dpkg -i inframonitor_1.0.0_all.deb
sudo apt-get install -f  # If needed
```

### Method 2: Tarball

```bash
tar -xzf inframonitor-*.tar.gz
cd inframonitor-*
sudo ./INSTALL.sh
```

---

## Access the Dashboard

Open your browser: **`http://your-server-ip:5000`**

---

## Adding Servers

### Linux Server

1. Click **"+ Add Node"**
2. Enter:
   - Server Name
   - IP Address
   - Username & Password
   - OS: **Linux**
   - Port: **22**
3. Click **"Add Server"**
4. Wait ~1 minute for installation

### Windows Server

**First:** Configure WinRM on Windows server:

1. Copy `configure-winrm.bat` to Windows server
2. Right-click → **"Run as Administrator"**
3. Wait for completion

**Then:** Add to InfraMonitor:

1. Click **"+ Add Node"**
2. Enter:
   - Server Name
   - IP Address
   - Username & Password (Administrator)
   - OS: **Windows**
   - Port: **5985**
3. Click **"Add Server"**
4. Wait ~2 minutes for installation

---

## Verify

- Servers appear in dashboard
- Status shows **"ONLINE"** (green)
- Metrics are being collected

---

## Troubleshooting

**Server shows ERROR?**
- Linux: Check SSH access and Node Exporter service
- Windows: Verify WinRM is configured (run `configure-winrm-diagnose.bat`)

**Port 9100 not accessible?**
- Linux: Check firewall rules
- Windows: Run `fix-windows-exporter-firewall.ps1`

See `USER-GUIDE.md` for detailed instructions.


