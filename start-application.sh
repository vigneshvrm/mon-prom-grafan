#!/bin/bash
# Start the complete application (Podman check, Prometheus, Web UI)

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "========================================="
echo "  Node Exporter Installation System"
echo "========================================="
echo ""

# Step 1: Check and install Podman if needed
echo "[1/5] Checking Podman installation..."
if ! command -v podman &> /dev/null; then
    echo "Podman is not installed. Installing..."
    if [ -f "${SCRIPT_DIR}/scripts/install-podman.sh" ]; then
        bash "${SCRIPT_DIR}/scripts/install-podman.sh"
    else
        echo "Error: install-podman.sh not found"
        exit 1
    fi
else
    PODMAN_VERSION=$(podman --version)
    echo "✓ Podman is installed: $PODMAN_VERSION"
fi
echo ""

# Step 2: Check Prometheus status and deploy if needed
echo "[2/5] Checking Prometheus deployment..."
if [ -f "${SCRIPT_DIR}/scripts/check-prometheus-service.sh" ]; then
    PROM_STATUS=$(bash "${SCRIPT_DIR}/scripts/check-prometheus-service.sh" 2>/dev/null || echo "not_running")
    
    if [ "$PROM_STATUS" = "not_running" ]; then
        echo "Prometheus is not running. Deploying Prometheus..."
        if [ -f "${SCRIPT_DIR}/scripts/install-prometheus.sh" ]; then
            bash "${SCRIPT_DIR}/scripts/install-prometheus.sh" start || {
                echo "Warning: Failed to deploy Prometheus. This may be because:"
                echo "  - Prometheus is already installed as a systemd service"
                echo "  - Prometheus container is already running"
                echo "  - Installation failed (check logs above)"
                echo ""
                echo "You can check status with:"
                echo "  bash ${SCRIPT_DIR}/scripts/check-prometheus-service.sh"
                echo "Or deploy manually with:"
                echo "  bash ${SCRIPT_DIR}/scripts/install-prometheus.sh start"
            }
        else
            echo "Error: install-prometheus.sh not found"
            exit 1
        fi
    else
        echo "✓ Prometheus is already running (${PROM_STATUS})"
    fi
else
    echo "Warning: check-prometheus-service.sh not found. Skipping Prometheus check."
fi
echo ""

# Step 3: Install project dependencies
echo "[3/5] Installing project dependencies..."

APT_PACKAGES=(python3 python3-pip python3-venv sshpass curl)
MISSING_APT=()

for pkg in "${APT_PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING_APT+=("$pkg")
    fi
done

if [ ${#MISSING_APT[@]} -gt 0 ]; then
    echo "Installing system packages: ${MISSING_APT[*]}"
    sudo apt-get update
    sudo apt-get install -y "${MISSING_APT[@]}"
else
    echo "✓ System packages already installed."
fi

export PATH="$HOME/.local/bin:$PATH"

if [ -f "${SCRIPT_DIR}/requirements.txt" ]; then
    echo "Installing Python dependencies..."
    python3 -m pip install --upgrade pip
    python3 -m pip install -r "${SCRIPT_DIR}/requirements.txt"
else
    echo "Warning: requirements.txt not found. Skipping Python dependencies."
fi
echo ""

# Step 4: Build React UI (if Node.js is available)
echo "[4/6] Building React UI..."
cd "${SCRIPT_DIR}/web-ui"

if command -v npm &> /dev/null; then
    # Check if node_modules exists, if not install dependencies
    if [ ! -d "node_modules" ]; then
        echo "Installing Node.js dependencies..."
        npm install
    fi
    
    # Build React app
    if [ -d "node_modules" ]; then
        echo "Building React application..."
        npm run build || {
            echo "Warning: React build failed. The application will use fallback template."
        }
    fi
else
    echo "Warning: npm not found. React UI will not be built."
    echo "Install Node.js to build the modern UI: sudo apt install nodejs npm"
fi

cd "${SCRIPT_DIR}"
echo ""

# Step 5: Verify installation scripts are available
echo "[5/6] Verifying installation scripts..."
INSTALL_SCRIPTS=(
    "install-podman.sh"
    "install-prometheus.sh"
    "install-linux-node-exporter.sh"
    "install-windows-node-exporter.sh"
)

for script in "${INSTALL_SCRIPTS[@]}"; do
    if [ -f "${SCRIPT_DIR}/scripts/${script}" ]; then
        chmod +x "${SCRIPT_DIR}/scripts/${script}"
        echo "✓ ${script}"
    else
        echo "✗ ${script} not found"
    fi
done
echo ""

# Step 5: Build React UI
echo "[5/6] Building React UI..."
cd "${SCRIPT_DIR}/web-ui"

# Check if node_modules exists, if not install dependencies
if [ ! -d "node_modules" ]; then
    echo "Installing Node.js dependencies..."
    if command -v npm &> /dev/null; then
        npm install
    else
        echo "Warning: npm not found. React UI will not be built."
        echo "Install Node.js and npm to build the UI, or use the old template."
    fi
fi

# Build React app if npm is available
if command -v npm &> /dev/null && [ -d "node_modules" ]; then
    echo "Building React application..."
    npm run build || {
        echo "Warning: React build failed. The application will use fallback template."
    }
else
    echo "Warning: Skipping React build. Using fallback template."
fi

cd "${SCRIPT_DIR}"
echo ""

# Step 6: Start Web UI
echo "[6/6] Starting Web UI..."
echo ""

# Create necessary directories
mkdir -p "${SCRIPT_DIR}/certs"
mkdir -p "${SCRIPT_DIR}/web-ui/uploads"
mkdir -p "${SCRIPT_DIR}/tmp"

# Create /etc/prometheus directory if it doesn't exist (requires sudo)
if [ ! -d "/etc/prometheus" ]; then
    echo "Creating /etc/prometheus directory..."
    sudo mkdir -p /etc/prometheus
    sudo chmod 755 /etc/prometheus
fi

echo "========================================="
echo "  Starting Web Application..."
echo "========================================="
echo ""
echo "Access the application at: http://localhost:5000"
echo "Prometheus UI at: http://localhost:9090"
echo ""
echo "Press Ctrl+C to stop"
echo ""

cd "${SCRIPT_DIR}/web-ui"
python3 app.py
