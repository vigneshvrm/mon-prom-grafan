# Complete Workflow

## Overview

This system provides a complete end-to-end solution for deploying Node Exporter and automatically configuring Prometheus.

## Workflow Steps

### 1. User Input (Web Frontend)
- User provides login credentials (SSH/WinRM) for target machine
- User configures Node Exporter settings (port, username, password)
- User optionally enables Prometheus auto-configuration

### 2. Ansible Installation
- System connects to target machine using provided credentials
- Detects operating system (Linux/Windows)
- Detects Linux distribution (Debian/Ubuntu, RHEL/CentOS, Arch, SUSE)
- Installs Node Exporter with secure configuration:
  - TLS/SSL certificates
  - Basic Authentication
  - Firewall rules

### 3. Node Information Collection
After successful installation:
- **Hostname**: Detected automatically using Ansible facts
- **IP Address**: Detected automatically (primary network interface)
- **Port**: From user input
- **Credentials**: Stored securely for Prometheus scraping

### 4. Prometheus Configuration Update
If enabled:
- Reads current `prometheus.yml` configuration
- Adds new scrape job with detected node information:
  - Target: `<ip_address>:<port>`
  - Labels: hostname, instance, OS
  - TLS/Basic Auth configuration
- Creates backup of previous configuration
- Saves updated configuration

### 5. Prometheus Reload
If Prometheus Reload API is configured:
- Sends POST request to Prometheus reload endpoint
- Prometheus picks up new configuration without restart
- New node starts being scraped immediately

## Example Flow

```
1. User fills form:
   - OS: Linux
   - Username: prometheus
   - Password: mySecurePassword
   - Port: 9100
   - ✅ Automatically configure Prometheus
   - Prometheus Config: /etc/prometheus/prometheus.yml
   - Prometheus Reload API: http://prometheus-server:9090/-/reload

2. System executes:
   ansible-playbook -i hosts.yml playbooks/main.yml
   → Installs Node Exporter on target
   → Detects: hostname=webserver01, ip=192.168.1.100

3. System updates Prometheus:
   → Reads /etc/prometheus/prometheus.yml
   → Adds scrape_config:
     - job_name: node-exporter
     - targets: ['192.168.1.100:9100']
     - labels: {instance: webserver01-192.168.1.100, hostname: webserver01}

4. System reloads Prometheus:
   → POST http://prometheus-server:9090/-/reload
   → Prometheus starts scraping new node

5. Result:
   ✅ Node Exporter running on webserver01:9100
   ✅ Prometheus scraping metrics automatically
   ✅ Secure communication (HTTPS + Basic Auth)
```

## Configuration Files

### Prometheus Configuration Format

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node-exporter'
    scheme: https
    tls_config:
      insecure_skip_verify: true
    basic_auth:
      username: prometheus
      password: mySecurePassword
    static_configs:
      - targets:
          - '192.168.1.100:9100'
        labels:
          instance: 'webserver01-192.168.1.100'
          hostname: 'webserver01'
          os: 'Debian'
```

### Node Information Format

```json
{
  "hostname": "webserver01",
  "fqdn": "webserver01.example.com",
  "ip_address": "192.168.1.100",
  "port": "9100",
  "username": "prometheus",
  "password": "mySecurePassword",
  "os": "Debian",
  "instance_label": "webserver01-192.168.1.100",
  "scheme": "https",
  "job_name": "node-exporter"
}
```

## Security Considerations

1. **Credentials Storage**: Passwords are stored in Prometheus config file. Ensure proper file permissions (644, readable by Prometheus user only).

2. **Certificate Management**: Self-signed certificates are generated per-node. For production, consider using a proper CA.

3. **Backup**: Prometheus configuration is automatically backed up before modification.

4. **Network Security**: Firewall rules are automatically configured to allow Prometheus server access.

## Troubleshooting

### Node Information Not Collected

If node information is not collected:
- Check Ansible facts gathering: `gather_facts: true`
- Verify network connectivity to target
- Check `/tmp/node_exporter_info.json` (Linux) or `C:\Temp\node_exporter_info.json` (Windows)

### Prometheus Configuration Not Updated

If Prometheus configuration is not updated:
- Verify file path is correct and writable
- Check file permissions on `prometheus.yml`
- Review backup directory for previous configurations

### Prometheus Not Reloading

If Prometheus doesn't reload:
- Verify Prometheus Reload API is enabled
- Check Prometheus server connectivity
- Verify API endpoint: `http://prometheus-server:9090/-/reload`
- Check Prometheus logs for errors

## Manual Prometheus Reload

If automatic reload fails, manually reload Prometheus:

```bash
# Using curl
curl -X POST http://prometheus-server:9090/-/reload

# Or restart Prometheus service
systemctl reload prometheus  # If systemd
# or
systemctl restart prometheus
```

