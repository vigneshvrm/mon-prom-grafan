# Installation Scripts

This directory contains 4 installation scripts and 1 deployment script.

## Installation Scripts

### 1. `install-podman.sh`
Installs Podman container runtime.
- **Usage**: `./install-podman.sh`
- **What it does**: Checks if Podman is installed, if not, installs it using the correct repository method
- **Auto-detects**: Ubuntu version and installs accordingly

### 2. `install-prometheus.sh`
Deploys Prometheus in a Podman container.
- **Usage**: `./install-prometheus.sh start|stop|restart|status`
- **What it does**: 
  - Checks for existing Prometheus (systemd or container)
  - Creates `/etc/prometheus` directory
  - Deploys Prometheus container with proper configuration
  - Uses DNS: 8.8.8.8 and 1.1.1.1
  - Mounts `/etc/hosts` for name resolution

### 3. `install-linux-node-exporter.sh`
Installs Node Exporter on Linux servers.
- **Usage**: `./install-linux-node-exporter.sh <host> <username> <password> [port]`
- **Example**: `./install-linux-node-exporter.sh 192.168.1.10 admin mypass 9100`
- **What it does**: Uses Ansible to install Node Exporter on target Linux server

### 4. `install-windows-node-exporter.sh`
Installs Node Exporter on Windows servers.
- **Usage**: `./install-windows-node-exporter.sh <host> <username> <password> [port]`
- **Example**: `./install-windows-node-exporter.sh 192.168.1.10 Administrator mypass 9100`
- **What it does**: Uses Ansible to install Node Exporter on target Windows server

## Deployment Script

### `start-application.sh` (in root directory)
Main deployment script that orchestrates everything.
- **Usage**: `./start-application.sh`
- **What it does**:
  1. Checks and installs Podman if needed
  2. Checks and deploys Prometheus if needed
  3. Verifies all installation scripts are available
  4. Starts the Web UI

## Helper Scripts

- `check-prometheus-service.sh` - Checks if Prometheus is running (used by deployment script)
- `generate-cert.sh` - Generates SSL certificates (optional)
- `generate-password-hash.py` - Generates password hashes (optional)

## Quick Start

```bash
# Deploy everything (Podman + Prometheus + Web UI)
./start-application.sh

# Or install components individually:
./scripts/install-podman.sh
./scripts/install-prometheus.sh start
./scripts/install-linux-node-exporter.sh 192.168.1.10 admin password
./scripts/install-windows-node-exporter.sh 192.168.1.10 Administrator password
```

