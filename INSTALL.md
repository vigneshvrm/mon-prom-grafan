# Installation Guide

## Quick Start

### 1. Install Python Dependencies

```bash
pip install -r requirements.txt
```

### 2. Start the Web UI

```bash
cd web-ui
python app.py
```

The web interface will be available at `http://localhost:5000`

### 3. Configure and Install

1. Open your browser and navigate to `http://localhost:5000`
2. Fill in the installation form:
   - **OS**: Select your target OS (Linux, Windows, or Auto-detect)
   - **Username**: Username for Basic Authentication (default: prometheus)
   - **Password**: Strong password for Basic Authentication
   - **Port**: Port to listen on (default: 9100)
   - **Hostname/IP**: Optional, for certificate generation
3. Click "🚀 Install Node Exporter"
4. Monitor the installation progress

## Manual Installation

### Generate Certificate

```bash
chmod +x scripts/generate-cert.sh
./scripts/generate-cert.sh [hostname] [ip_address]
```

### Generate Password Hash

```bash
python3 scripts/generate-password-hash.py [password]
```

### Run Ansible Playbook

```bash
ansible-playbook -i hosts.yml playbooks/main.yml \
  -e "target_os=linux" \
  -e "node_exporter_port=9100" \
  -e "node_exporter_username=prometheus" \
  -e "node_exporter_password_hash=<bcrypt-hash>" \
  -e "node_exporter_password=<plain-password>"
```

## Verification

After installation, verify Node Exporter is running:

### Linux
```bash
curl -k https://localhost:9100/metrics -u prometheus:yourpassword
```

### Windows
```powershell
Invoke-WebRequest -Uri "http://localhost:9100/metrics" -UseBasicParsing
```

Note: Windows Exporter has limited TLS/Basic Auth support. Consider using a reverse proxy for full security.

