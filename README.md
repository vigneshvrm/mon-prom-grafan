# Node Exporter Installation System

Automated Node Exporter installation with Prometheus integration using Ansible and Podman.

## Features

- 🐧 **Linux Distribution Detection**: Automatically detects and handles Debian/Ubuntu, RHEL/CentOS, Arch, and SUSE
- 🪟 **Windows Support**: Full support for Windows Exporter installation
- 🌐 **Modern React UI**: Professional, responsive web interface with real-time system status
- 📊 **Prometheus Integration**: Automatically detects node hostname/IP and updates Prometheus configuration
- 🐳 **Podman Support**: Automatically installs Podman and runs Prometheus in a container
- 🔄 **Auto-Reload**: Automatically reloads Prometheus after configuration updates
- 🎨 **Boot Sequence**: Animated system initialization with real-time status checks
- 📈 **Dashboard**: Real-time infrastructure overview with metrics and stats

## Architecture

- **Centralized Server**: Runs this web application and Prometheus server (in Podman container)
- **Target Nodes**: Remote servers where Node Exporter will be installed
- **Automatic Discovery**: Detects hostname/IP and adds to Prometheus automatically

## Quick Start

### Start the Complete Application

The application will automatically:
1. Install base packages (python3, pip, venv, sshpass, curl, npm) on Debian/Ubuntu
2. Create an isolated `.venv/` and install Python dependencies safely (no system package conflicts)
3. Ensure Node.js 20.x + npm are installed (via NodeSource) for the React UI build
4. Check and install Podman if needed
5. Start Prometheus in a Podman container (if not running)
6. Build the React UI (falls back to classic template if build fails)
7. Launch the Flask web application

```bash
cd Monitoring
./start-application.sh
```

Access:
- **Web UI**: http://localhost:5000 (Modern React UI)
- **Prometheus UI**: http://localhost:9090

## Automatic Dependencies

`start-application.sh` installs all required dependencies automatically:

- **System packages** (Debian/Ubuntu): `python3`, `python3-pip`, `python3-venv`, `sshpass`, `npm`, `curl`
- **Python packages**: Installed inside `.venv/` so system packages (PyYAML, blinker, etc.) remain untouched
- **Node.js runtime**: Ensures Node.js **20.x** + npm via NodeSource (required by Vite/React Router 7)
- **Node.js packages**: Runs `npm install && npm run build` automatically (falls back gracefully if build fails)

### Optional: Node.js for Modern UI

The React UI requires **Node.js 20+**. The startup script installs it automatically on apt-based systems. If you need to install manually:

```bash
# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Other platforms
# Download installer from https://nodejs.org/en/download/prebuilt-installer
```

If you run scripts manually, ensure these are installed first:

```bash
# System packages (Debian/Ubuntu)
sudo apt-get install -y python3 python3-pip python3-venv sshpass npm curl

# Python virtual environment (avoids distutils conflicts)
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt

# Node.js 20.x (required for Vite / React Router 7)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# React build (optional – only needed for manual builds)
cd web-ui
npm install
npm run build
```

**Note**: The virtual environment keeps system packages (PyYAML 5.3.1, blinker 1.4, etc.) untouched and prevents `uninstall-distutils-installed-package` errors. Deactivate with `deactivate` when finished.

## Manual Start (if needed)

### Build React UI Manually

If you want to build the React UI separately:

```bash
cd web-ui
npm install          # First time only
npm run build        # Build for production
```

### Development Mode

For development with hot reload:

```bash
cd web-ui
npm install
npm run dev          # Starts Vite dev server on port 3000
```

The dev server proxies API calls to Flask on port 5000.

## Usage

### 1. Start Application

```bash
./start-application.sh
```

### 2. Access Web Interface

Open http://localhost:5000 in your browser

You'll see:
- **Boot Sequence**: Animated system initialization (first time)
- **Dashboard**: Overview with system stats and monitored servers
- **Add Server**: Professional modal to add and monitor new servers
- **Settings**: System configuration and status

### 3. Install Node Exporter

1. Click **"Add Server"** button (or "+" icon in sidebar)
2. **Fill in Server Details**:
   - Server name
   - IP address/hostname
   - SSH/WinRM port (22 for Linux, 5986 for Windows)
   - Username
   - Password
   - Select OS (Linux or Windows)

3. Click **"🚀 Deploy Node Exporter"**

4. The system will:
   - Install Node Exporter on target server via Ansible
   - Detect hostname and IP automatically
   - Add scrape target to Prometheus configuration
   - Reload Prometheus automatically
   - Show server in dashboard with real-time status

## Project Structure

```
Monitoring/
├── playbooks/              # Ansible playbooks
│   ├── install-podman.yml
│   ├── setup-prometheus-podman.yml
│   ├── linux-node-exporter.yml
│   └── windows-node-exporter.yml
├── scripts/               # Installation scripts
│   ├── install-podman.sh              # 1. Podman installation
│   ├── install-prometheus.sh          # 2. Prometheus deployment
│   ├── install-linux-node-exporter.sh # 3. Linux Node Exporter
│   ├── install-windows-node-exporter.sh # 4. Windows Node Exporter
│   └── check-prometheus-service.sh    # Helper: Check Prometheus status
├── web-ui/                # Web frontend (React + Flask)
│   ├── app.py            # Flask backend (serves React build)
│   ├── static/           # React build output (generated)
│   ├── components/       # React components
│   │   ├── BootSequence.tsx
│   │   ├── ServerCard.tsx
│   │   ├── AddServerModal.tsx
│   │   └── MetricsChart.tsx
│   ├── services/         # API services
│   │   ├── apiService.ts # Flask API client
│   │   └── geminiService.ts
│   ├── App.tsx           # Main React app
│   ├── index.tsx         # React entry point
│   ├── package.json      # Node.js dependencies
│   ├── vite.config.ts    # Vite build config
│   └── templates/        # Fallback template (if React not built)
│       └── index.html
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

### React UI Not Loading

If the modern UI doesn't appear:
1. Check if React was built: `ls web-ui/static/index.html`
2. If missing, build manually: `cd web-ui && npm install && npm run build`
3. Check browser console for errors
4. Flask will fallback to template if React build doesn't exist

### Python Packages Complain About distutils (PyYAML, blinker, click, etc.)

Ubuntu ships several Python libs via `distutils`, which pip refuses to uninstall. The fix is to use a virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt
```

The startup script now creates `.venv/` automatically, so you should only see this if running manual commands.

### Node.js Build Fails

If `npm run build` fails:
1. Check Node.js version: `node --version` (must be **>=20** for React Router 7 + Vite 6)
2. Remove old dependencies: `rm -rf node_modules package-lock.json`
3. Re-install: `npm install`
4. Rebuild: `npm run build`
5. If it still fails, capture the error log in `web-ui` and verify TypeScript errors
6. The app will still work with fallback template even if the React build fails

### Node.js / npm Too Old

Errors such as `Unsupported engine for react-router-dom@7.9.6` or `esbuild postinstall` mean Node 10/12 is still active. Install Node.js 20+:

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
node -v   # should show v20.x.y
npm -v    # npm 10+
```

After upgrading, delete `node_modules` and run `npm install` again.

### Podman Installation Fails

If Podman installation fails, install manually:
- **Ubuntu/Debian**: Follow the script method (add repo, GPG key, then install)
- **CentOS/RHEL**: `sudo yum install podman`
- **Arch**: `sudo pacman -S podman`

### Prometheus Not Starting

Check logs:
```bash
podman logs prometheus
```

Check status:
```bash
bash scripts/check-prometheus-service.sh
```

### Port Already in Use

If port 9090 is already in use:
- Stop existing Prometheus: `podman stop prometheus` or `systemctl stop prometheus`
- Or edit `scripts/install-prometheus.sh` to change the port

If port 5000 is in use:
- Stop existing Flask app or change port in `web-ui/app.py`

## Requirements

### Required
- **Python 3.8+**: For Flask backend and Ansible
- **Ansible 7.0+**: For remote server automation
- **Podman**: Auto-installed by the script
- **SSH/WinRM access**: To target servers

### Optional (for Modern UI)
- **Node.js 20+**: Required for Vite 6 / React Router 7 build
- **npm 10+**: Installed automatically with Node.js 20

The application works without Node.js (uses fallback template), but the modern React UI provides a much better experience.

## License

MIT License
