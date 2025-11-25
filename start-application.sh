#!/bin/bash
# Start the complete application (Podman check, Prometheus, Web UI)

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

VENV_PATH="${SCRIPT_DIR}/.venv"
PYTHON_BIN="${VENV_PATH}/bin/python"
PIP_BIN="${VENV_PATH}/bin/pip"
REQUIRED_NODE_MAJOR=20

echo "========================================="
echo "  Node Exporter Installation System"
echo "========================================="
echo ""

ensure_system_packages() {
    if command -v apt-get &> /dev/null; then
        local packages=(python3 python3-pip python3-venv sshpass npm curl)
        local missing=()

        for pkg in "${packages[@]}"; do
            if ! dpkg -s "$pkg" >/dev/null 2>&1; then
                missing+=("$pkg")
            fi
        done

        if [ ${#missing[@]} -gt 0 ]; then
            echo "Installing system packages: ${missing[*]}"
            sudo apt-get update
            sudo apt-get install -y "${missing[@]}"
        else
            echo "✓ System packages already installed."
        fi
    else
        echo "Warning: Unsupported package manager."
        echo "Install manually: python3 python3-pip python3-venv sshpass curl npm"
    fi
}

install_nodejs_20() {
    if command -v apt-get &> /dev/null; then
        echo "Installing Node.js 20.x from NodeSource..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
    else
        echo "Warning: Automatic Node.js install only supported on apt-based systems."
        echo "Please install Node.js 20.x manually from https://nodejs.org/"
    fi
}

ensure_node_runtime() {
    if command -v node &> /dev/null; then
        local version major
        version="$(node -v | sed 's/v//')"
        major="${version%%.*}"
        if [ "$major" -lt "$REQUIRED_NODE_MAJOR" ]; then
            echo "Node.js $version detected (need >=${REQUIRED_NODE_MAJOR}). Upgrading..."
            install_nodejs_20
        else
            echo "✓ Node.js $(node -v) detected."
        fi
    else
        echo "Node.js not found. Installing..."
        install_nodejs_20
    fi
}

ensure_python_venv() {
    if [ ! -d "$VENV_PATH" ]; then
        echo "Creating Python virtual environment at ${VENV_PATH}..."
        python3 -m venv "$VENV_PATH"
    fi
    if [ ! -x "$PYTHON_BIN" ]; then
        echo "Error: virtual environment not created correctly."
        exit 1
    fi
}

install_python_dependencies() {
    if [ ! -f "${SCRIPT_DIR}/requirements.txt" ]; then
        echo "Warning: requirements.txt not found. Skipping Python dependencies."
        return
    fi

    echo "Installing Python dependencies inside ${VENV_PATH}..."
    "$PIP_BIN" install --upgrade pip setuptools wheel
    "$PIP_BIN" install -r "${SCRIPT_DIR}/requirements.txt"
}

build_react_ui() {
    cd "${SCRIPT_DIR}/web-ui"

    if ! command -v npm &> /dev/null; then
        echo "Warning: npm not found. React UI will not be built."
        echo "Install Node.js 20+ to build the modern UI."
        cd "$SCRIPT_DIR"
        return
    fi

    if [ ! -d "node_modules" ]; then
        echo "Installing Node.js dependencies..."
        npm install || {
            echo "Warning: npm install failed. Using fallback template."
            cd "$SCRIPT_DIR"
            return
        }
    fi

    echo "Building React application..."
    npm run build || {
        echo "Warning: React build failed. The application will use fallback template."
    }

    cd "$SCRIPT_DIR"
}

# Step 1: Prepare base system dependencies
echo "[1/7] Preparing base system dependencies..."
ensure_system_packages
ensure_python_venv
ensure_node_runtime
echo ""

# Step 2: Install Python packages inside virtual environment
echo "[2/7] Installing Python dependencies (isolated virtualenv)..."
install_python_dependencies
echo ""

# Step 3: Check Podman installation
echo "[3/7] Checking Podman installation..."
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

# Step 4: Check Prometheus deployment
echo "[4/7] Checking Prometheus deployment..."
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

# Step 5: Build React UI
echo "[5/7] Building React UI..."
build_react_ui
echo ""

# Step 6: Verify installation scripts are available
echo "[6/7] Verifying installation scripts..."
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

# Step 7: Start Web UI
echo "[7/7] Starting Web UI..."
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
"${PYTHON_BIN}" app.py
