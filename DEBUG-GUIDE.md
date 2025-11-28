# Debug Guide for InfraMonitor

## Enabling Debug Mode

To enable debug logging and see detailed error messages:

### Method 1: Environment Variable (Recommended)

```bash
export DEBUG_MODE=true
python3 web-ui/app.py
```

Or for systemd service:
```bash
sudo systemctl edit inframonitor.service
```

Add:
```ini
[Service]
Environment="DEBUG_MODE=true"
```

Then restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart inframonitor.service
```

### Method 2: Check Logs

Logs are written to:
- **System logs**: `/var/log/inframonitor.log` (or check with `journalctl -u inframonitor.service`)
- **Application logs**: Check the log file path shown when starting the app

View logs:
```bash
# For systemd service
sudo journalctl -u inframonitor.service -f

# Or check the log file directly
tail -f /var/log/inframonitor.log
```

## Debugging Server Health Issues

### Check Server Health via API

```bash
# Get detailed health check for a specific server
curl http://localhost:5000/api/servers/<server_id>/health

# Example response:
{
  "success": true,
  "online": false,
  "status": "ERROR",
  "details": {
    "port_check": "SUCCESS",
    "node_exporter_check": "CONNECTION_ERROR",
    "port_open": true,
    "node_exporter_online": false,
    "errors": [
      "Node Exporter connection refused: Connection refused"
    ]
  },
  "server": {
    "name": "windows-zone-b-01",
    "ip": "123.176.58.128",
    "port": 5986,
    "os": "Windows"
  }
}
```

### Common Issues and Solutions

#### Issue 1: Port 9100 Not Accessible (404 Error)

**Symptoms:**
- Server shows as "ERROR" status
- Port 9100 returns 404 when accessed
- Health check shows `node_exporter_check: "CONNECTION_ERROR"`

**Diagnosis:**
```bash
# Check if Node Exporter is running on the target server
# On Linux:
ssh user@server "systemctl status node_exporter"
ssh user@server "curl http://localhost:9100/metrics"

# On Windows:
# RDP to server and check:
# - Services: node_exporter service
# - Port: netstat -an | findstr 9100
```

**Solutions:**
1. **Node Exporter not installed**: Re-run the installation playbook
2. **Node Exporter not running**: Start the service
   - Linux: `sudo systemctl start node_exporter`
   - Windows: Check Windows Services
3. **Firewall blocking**: Allow port 9100 in firewall
4. **Wrong port**: Check if Node Exporter is running on a different port

#### Issue 2: Port Closed (SSH/WinRM Not Accessible)

**Symptoms:**
- Health check shows `port_check: "FAILED"`
- `port_open: false`
- Error: "Port X is not accessible"

**Diagnosis:**
```bash
# Test port connectivity from InfraMonitor server
telnet <server_ip> <port>
# Or
nc -zv <server_ip> <port>
```

**Solutions:**
1. **Server is down**: Check if server is running
2. **Firewall blocking**: Allow SSH (22) or WinRM (5985/5986) in firewall
3. **Service not running**: 
   - Linux: Check SSH service
   - Windows: Check WinRM service

#### Issue 3: Windows Server - Credentials Rejected

**Symptoms:**
- Installation shows "credentials rejected"
- Health check fails immediately after installation

**Diagnosis:**
- Check WinRM configuration (see `scripts/WINRM-TROUBLESHOOTING.md`)
- Most common: `LocalAccountTokenFilterPolicy` not set to 1

**Solution:**
Run `configure-winrm.bat` on Windows server as Administrator

## Viewing Real-time Logs

### Method 1: Systemd Journal

```bash
# Follow logs in real-time
sudo journalctl -u inframonitor.service -f

# View last 100 lines
sudo journalctl -u inframonitor.service -n 100

# View logs with timestamps
sudo journalctl -u inframonitor.service -o short-precise
```

### Method 2: Application Log File

```bash
# Find log file location (shown at startup)
# Usually: /var/log/inframonitor.log

# Follow logs
tail -f /var/log/inframonitor.log

# Search for errors
grep -i error /var/log/inframonitor.log

# Search for specific server
grep "windows-zone-b-01" /var/log/inframonitor.log
```

## Health Check Details

The health check performs two tests:

1. **Port Connectivity**: Tests if SSH (Linux) or WinRM (Windows) port is open
2. **Node Exporter**: Tests if Node Exporter is responding on port 9100

**Status Meanings:**
- `ONLINE`: Both port and Node Exporter are accessible
- `ERROR`: Either port is closed OR Node Exporter is not responding

**Check Details:**
- `port_check`: SUCCESS, FAILED, or ERROR
- `node_exporter_check`: SUCCESS, CONNECTION_ERROR, TIMEOUT, or SKIPPED
- `errors`: Array of error messages explaining what failed

## Testing Node Exporter Manually

### From InfraMonitor Server

```bash
# Test if Node Exporter is accessible
curl http://<server_ip>:9100/metrics

# Should return Prometheus metrics if working
# If 404 or connection refused, Node Exporter is not running
```

### From Target Server (Linux)

```bash
# Check if service is running
systemctl status node_exporter

# Check if port is listening
netstat -tlnp | grep 9100
# Or
ss -tlnp | grep 9100

# Test locally
curl http://localhost:9100/metrics
```

### From Target Server (Windows)

```powershell
# Check if service is running
Get-Service node_exporter

# Check if port is listening
netstat -an | findstr 9100

# Test locally
Invoke-WebRequest -Uri http://localhost:9100/metrics
```

## Enabling Debug Mode Permanently

Edit the systemd service file:

```bash
sudo systemctl edit inframonitor.service
```

Add:
```ini
[Service]
Environment="DEBUG_MODE=true"
```

Reload and restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart inframonitor.service
```

## API Endpoints for Debugging

- `GET /api/servers/<server_id>/health` - Detailed health check with diagnostics
- `POST /api/servers/health-check-all` - Check all servers

Both endpoints return detailed information about what's failing.

