#!/usr/bin/env bash
#
# Build InfraMonitor release package.
#
# Options:
#   --deb    Build as Debian package (.deb) - recommended for production
#   --tar    Build as tarball with INSTALL.sh (default)
#
# Debian package (.deb):
#   - Professional installation via dpkg
#   - Silent installation (hides Ansible playbook execution)
#   - Automatic dependency management
#   - Clean uninstall support
#
# Tarball:
#   - Self-contained archive with INSTALL.sh
#   - Manual installation process
#
# Requirements:
#   - bash, tar, python3, python3-venv, pip
#   - npm (for building the frontend)
#   - dpkg-deb, fakeroot (for .deb builds)

set -euo pipefail

# Check for build type argument
BUILD_TYPE="tar"  # Default to tarball
if [ "${1:-}" = "--deb" ]; then
    BUILD_TYPE="deb"
elif [ "${1:-}" = "--tar" ]; then
    BUILD_TYPE="tar"
elif [ -n "${1:-}" ] && [ "${1:-}" != "--help" ] && [ "${1:-}" != "-h" ]; then
    echo "ERROR: Unknown option: ${1}" >&2
    echo "Usage: $0 [--deb|--tar]" >&2
    exit 1
elif [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: $0 [--deb|--tar]"
    echo ""
    echo "  --deb    Build as Debian package (.deb) - silent installation"
    echo "  --tar    Build as tarball with INSTALL.sh (default)"
    echo ""
    echo "If no option is provided, builds tarball by default."
    exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"

# If building .deb, use the dedicated script
if [ "${BUILD_TYPE}" = "deb" ]; then
    echo "Building Debian package (.deb)..."
    echo ""
    BUILD_DEB_SCRIPT="${ROOT_DIR}/scripts/build-deb.sh"
    if [ ! -f "${BUILD_DEB_SCRIPT}" ]; then
        echo "ERROR: build-deb.sh not found at ${BUILD_DEB_SCRIPT}" >&2
        exit 1
    fi
    if [ ! -x "${BUILD_DEB_SCRIPT}" ]; then
        chmod +x "${BUILD_DEB_SCRIPT}"
    fi
    bash "${BUILD_DEB_SCRIPT}"
    exit $?
fi

# Continue with tarball build
echo "========================================="
echo "  Building InfraMonitor Tarball Package"
echo "========================================="
echo ""
PKG_NAME="inframonitor-$(date +%Y%m%d-%H%M%S)"
PKG_DIR="${DIST_DIR}/${PKG_NAME}"

echo "[1/6] Preparing dist directory..."
rm -rf "${PKG_DIR}"
mkdir -p "${PKG_DIR}" || {
    echo "ERROR: Failed to create package directory" >&2
    exit 1
}

echo "[2/6] Building React frontend..."
pushd "${ROOT_DIR}/web-ui" >/dev/null || {
    echo "ERROR: Failed to change to web-ui directory" >&2
    exit 1
}
if [ ! -d "node_modules" ]; then
    echo "  Installing npm dependencies..."
    npm install || {
        echo "ERROR: npm install failed" >&2
        popd >/dev/null
        exit 1
    }
fi
echo "  Running npm build..."
npm run build || {
    echo "ERROR: npm run build failed" >&2
    popd >/dev/null
    exit 1
}
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

APP_NAME="inframonitor"
INSTALL_DIR="/opt/${APP_NAME}"
SERVICE_NAME="inframonitor.service"

if [[ $EUID -ne 0 ]]; then
  echo "Please run INSTALL.sh as root (sudo)." >&2
  exit 1
fi

echo "[*] Installing required system packages..."
if command -v apt-get >/dev/null; then
  apt-get update
  apt-get install -y python3 python3-venv python3-pip podman tar sshpass curl
elif command -v yum >/dev/null; then
  yum install -y python3 python3-virtualenv python3-pip podman tar sshpass curl
else
  echo "Unsupported package manager. Install Python 3, pip, Podman, sshpass, and curl manually." >&2
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

echo "[*] Deploying Prometheus (Podman)..."
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
Description=InfraMonitor Monitoring Service
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

echo "[+] InfraMonitor installation completed."
echo "    Service status: systemctl status ${SERVICE_NAME}"
EOF
chmod +x "${PKG_DIR}/INSTALL.sh"

echo "[5/6] Generating manifest..."
cat > "${PKG_DIR}/MANIFEST.txt" <<EOF
InfraMonitor Release
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
mkdir -p "${DIST_DIR}" || {
    echo "ERROR: Failed to create dist directory" >&2
    exit 1
}
pushd "${DIST_DIR}" >/dev/null || {
    echo "ERROR: Failed to change to dist directory" >&2
    exit 1
}
echo "  Compressing package..."
tar -czf "${PKG_NAME}.tar.gz" "${PKG_NAME}" || {
    echo "ERROR: Failed to create tarball" >&2
    popd >/dev/null
    exit 1
}
popd >/dev/null

echo ""
echo "✓ Tarball package created successfully!"
echo ""
echo "Package: ${DIST_DIR}/${PKG_NAME}.tar.gz"
echo ""
echo "To install:"
echo "  tar -xzf ${PKG_NAME}.tar.gz"
echo "  cd ${PKG_NAME}"
echo "  sudo ./INSTALL.sh"
echo ""

