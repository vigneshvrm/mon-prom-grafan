#!/usr/bin/env bash
#
# Build a self-contained OpsMonitor release archive.
#
# The resulting tarball contains:
#   - Backend (Flask) application
#   - Compiled React frontend assets
#   - Ansible playbooks and helper scripts
#   - An INSTALL.sh script that sets up a Python virtual environment,
#     installs dependencies, registers a systemd service, and starts it.
#
# Requirements:
#   - bash, tar, python3, python3-venv, pip
#   - npm (for building the frontend)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
PKG_NAME="opsmonitor-$(date +%Y%m%d-%H%M%S)"
PKG_DIR="${DIST_DIR}/${PKG_NAME}"

echo "[1/6] Preparing dist directory..."
rm -rf "${PKG_DIR}"
mkdir -p "${PKG_DIR}"

echo "[2/6] Building React frontend..."
pushd "${ROOT_DIR}/web-ui" >/dev/null
npm install >/dev/null
npm run build >/dev/null
popd >/dev/null

echo "[3/6] Copying project assets..."
# Backend + web assets
mkdir -p "${PKG_DIR}/web-ui"
cp -r "${ROOT_DIR}/web-ui/app.py" \
      "${ROOT_DIR}/web-ui/database.py" \
      "${ROOT_DIR}/web-ui/security_utils.py" \
      "${ROOT_DIR}/web-ui/templates" \
      "${ROOT_DIR}/web-ui/metadata.json" \
      "${PKG_DIR}/web-ui/" || true

# Include optional static directory if it exists
if [[ -d "${ROOT_DIR}/web-ui/static" ]]; then
  cp -r "${ROOT_DIR}/web-ui/static" "${PKG_DIR}/web-ui/"
fi

# React build artifacts
if [[ -d "${ROOT_DIR}/web-ui/dist" ]]; then
  cp -r "${ROOT_DIR}/web-ui/dist" "${PKG_DIR}/web-ui/"
else
  echo "WARNING: web-ui/dist not found. Ensure 'npm run build' succeeded." >&2
fi

# Supporting directories
cp -r "${ROOT_DIR}/playbooks" "${PKG_DIR}/"
cp -r "${ROOT_DIR}/prometheus" "${PKG_DIR}/"
cp -r "${ROOT_DIR}/scripts" "${PKG_DIR}/"

# Root level files
cp "${ROOT_DIR}/requirements.txt" "${PKG_DIR}/"
cp "${ROOT_DIR}/start-application.sh" "${PKG_DIR}/"
cp "${ROOT_DIR}/config.yml.example" "${PKG_DIR}/"

echo "[4/6] Creating installation script..."
cat > "${PKG_DIR}/INSTALL.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="opsmonitor"
INSTALL_DIR="/opt/${APP_NAME}"
SERVICE_NAME="opsmonitor.service"

if [[ $EUID -ne 0 ]]; then
  echo "Please run INSTALL.sh as root (sudo)." >&2
  exit 1
fi

echo "[*] Installing required system packages..."
if command -v apt-get >/dev/null; then
  apt-get update
  apt-get install -y python3 python3-venv python3-pip podman tar
elif command -v yum >/dev/null; then
  yum install -y python3 python3-virtualenv python3-pip podman tar
else
  echo "Unsupported package manager. Install Python 3, pip, and Podman manually." >&2
fi

echo "[*] Creating application directory at ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
cp -r ./* "${INSTALL_DIR}/"

echo "[*] Creating Python virtual environment..."
python3 -m venv "${INSTALL_DIR}/.venv"
source "${INSTALL_DIR}/.venv/bin/activate"
pip install --upgrade pip
pip install -r "${INSTALL_DIR}/requirements.txt"
deactivate

echo "[*] Deploying Prometheus (Podman) via Ansible..."
(
  cd "${INSTALL_DIR}"
  source "${INSTALL_DIR}/.venv/bin/activate"
  ansible-playbook -i localhost, -c local playbooks/setup-prometheus-podman.yml
  deactivate
)

echo "[*] Ensuring Prometheus container systemd unit is enabled..."
if systemctl list-unit-files | grep -q "container-prometheus.service"; then
  systemctl enable --now container-prometheus.service || true
fi

echo "[*] Writing systemd service..."
cat <<SERVICE >/etc/systemd/system/${SERVICE_NAME}
[Unit]
Description=OpsMonitor Monitoring Service
After=network-online.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
Environment="PYTHONUNBUFFERED=1"
ExecStart=${INSTALL_DIR}/.venv/bin/python ${INSTALL_DIR}/web-ui/app.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICE

echo "[*] Reloading systemd and starting service..."
systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}"

echo "[+] OpsMonitor installation completed."
echo "    Service status: systemctl status ${SERVICE_NAME}"
EOF
chmod +x "${PKG_DIR}/INSTALL.sh"

echo "[5/6] Generating manifest..."
cat > "${PKG_DIR}/MANIFEST.txt" <<EOF
OpsMonitor Release
==================
Package: ${PKG_NAME}
Built: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

Contents:
  - web-ui/           Flask backend + compiled React UI
  - playbooks/        Ansible automation
  - scripts/          Helper scripts
  - prometheus/       Prometheus config helpers
  - INSTALL.sh        Installer script
  - requirements.txt
  - start-application.sh
EOF

echo "[6/6] Creating tarball..."
mkdir -p "${DIST_DIR}"
pushd "${DIST_DIR}" >/dev/null
tar -czf "${PKG_NAME}.tar.gz" "${PKG_NAME}"
popd >/dev/null

echo ""
echo "Release created:"
echo "  ${DIST_DIR}/${PKG_NAME}.tar.gz"

