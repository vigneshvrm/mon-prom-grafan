# Node Exporter Installation System

Automated Node Exporter installation with Prometheus integration using Ansible and Podman.

## Features

- 🐧 **Linux Distribution Detection**: Automatically detects and handles Debian/Ubuntu, RHEL/CentOS, Arch, and SUSE
- 🪟 **Windows Support**: Full support for Windows Exporter installation
- 🌐 **Web UI**: Simple, modern web interface for configuration and installation
- 📊 **Prometheus Integration**: Automatically detects node hostname/IP and updates Prometheus configuration
- 🐳 **Podman Support**: Automatically installs Podman and runs Prometheus in a container
- 🔄 **Auto-Reload**: Automatically reloads Prometheus after configuration updates

## Architecture

- **Centralized Server**: Runs this web application and Prometheus server (in Podman container)
- **Target Nodes**: Remote servers where Node Exporter will be installed
- **Automatic Discovery**: Detects hostname/IP and adds to Prometheus automatically

## Quick Start

### Start the Complete Application

The application will automatically:
1. Check and install Podman if needed
2. Start Prometheus in a Podman container (if not running)
3. Launch the web UI

```bash
cd Monitoring
./start-application.sh
```

Access:
- **Web UI**: http://localhost:5000
- **Prometheus UI**: http://localhost:9090

## Manual Start (if needed)

If you just want to start the web UI without Prometheus setup:

```bash
cd Monitoring
./start-ui.sh
```

## Usage

### 1. Start Application

```bash
./start-application.sh
```

### 2. Access Web Interface

Open http://localhost:5000 in your browser

### 3. Install Node Exporter

1. **Section 1: Target Server Credentials**
   - Enter target server IP/hostname
   - Enter SSH/WinRM username and password
   - Select OS (or Auto-detect)

2. **Section 2: Prometheus Settings**
   - Check "Automatically configure Prometheus"
   - Config path auto-detected (Podman container or systemd)
   - Reload API auto-detected

3. Click "🚀 Install Node Exporter"

4. The system will:
   - Install Node Exporter on target server
   - Detect hostname and IP automatically
   - Add scrape target to Prometheus configuration
   - Reload Prometheus automatically

## Project Structure

```
Monitoring/
├── playbooks/              # Ansible playbooks
│   ├── main.yml           # Main orchestration
│   ├── linux-node-exporter.yml
│   └── windows-node-exporter.yml
├── scripts/               # Installation scripts
│   ├── install-podman.sh              # 1. Podman installation
│   ├── install-prometheus.sh          # 2. Prometheus deployment
│   ├── install-linux-node-exporter.sh # 3. Linux Node Exporter
│   ├── install-windows-node-exporter.sh # 4. Windows Node Exporter
│   └── check-prometheus-service.sh    # Helper: Check Prometheus status
├── web-ui/                # Web frontend
│   ├── app.py            # Flask application
│   └── templates/
│       └── index.html    # Web UI
├── prometheus/            # Prometheus manager
│   └── prometheus_manager.py
├── /etc/prometheus/       # Prometheus config (system directory)
│   └── prometheus.yml
└── start-application.sh   # Main startup script
```

## Installation Scripts

### 1. Install Podman
```bash
./scripts/install-podman.sh
```

### 2. Deploy Prometheus
```bash
# Start/Deploy
./scripts/install-prometheus.sh start

# Check status
bash scripts/check-prometheus-service.sh

# Stop container
podman stop prometheus

# Restart container
podman restart prometheus
```

### 3. Install Linux Node Exporter
```bash
./scripts/install-linux-node-exporter.sh <host> <username> <password> [port]
# Example: ./scripts/install-linux-node-exporter.sh 192.168.1.10 admin mypass 9100
```

### 4. Install Windows Node Exporter
```bash
./scripts/install-windows-node-exporter.sh <host> <username> <password> [port]
# Example: ./scripts/install-windows-node-exporter.sh 192.168.1.10 Administrator mypass 9100
```

## Configuration

### Prometheus Configuration Location

- **Configuration Path**: `/etc/prometheus/prometheus.yml`
- **Container**: Prometheus runs in Podman container with `/etc/prometheus` mounted
- **DNS**: Container uses DNS servers 8.8.8.8 and 1.1.1.1
- **Hosts File**: Container mounts `/etc/hosts` from host for name resolution

### Ansible Inventory

You can either:
1. Use the form to enter server details (creates dynamic inventory)
2. Edit `../hosts.yml` for multiple hosts

## Troubleshooting

### Podman Installation Fails

If Podman installation fails, install manually:
- **Ubuntu/Debian**: `sudo apt-get install podman`
- **CentOS/RHEL**: `sudo yum install podman`
- **Arch**: `sudo pacman -S podman`

### Prometheus Not Starting

Check logs:
```bash
podman logs prometheus
```

### Port Already in Use

If port 9090 is already in use:
- Stop existing Prometheus: `podman stop prometheus` or `systemctl stop prometheus`
- Or edit `scripts/install-prometheus.sh` to change the port

## Requirements

- Python 3.8+
- Ansible 7.0+
- Podman (auto-installed)
- SSH/WinRM access to target servers

## License

MIT License
