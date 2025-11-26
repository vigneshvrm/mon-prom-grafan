#!/bin/bash
# Start the complete application (Podman check, Prometheus, Web UI)

# Don't exit on error - we handle errors explicitly
set +e

# Set environment variables to prevent ALL interactive prompts
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export UCF_FORCE_CONFFNEW=1
export APT_LISTCHANGES_FRONTEND=none

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
        # Prevent ALL interactive prompts during package installation
        export DEBIAN_FRONTEND=noninteractive
        export NEEDRESTART_MODE=a
        
        # Prevent interactive prompts during package installation
        if ! command -v debconf-set-selections &> /dev/null; then
            echo "Installing debconf-utils to prevent interactive prompts..."
            sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq debconf-utils
        fi
        
        # Configure debconf to avoid ALL service restart prompts and other interactive dialogs
        echo "* libraries/restart-without-asking boolean true" | sudo debconf-set-selections
        echo "debconf debconf/frontend select noninteractive" | sudo debconf-set-selections
        echo "console-setup console-setup/charmap47 select UTF-8" | sudo debconf-set-selections
        echo "grub-pc grub-pc/install_devices multiselect" | sudo debconf-set-selections
        
        local packages=(python3 python3-pip python3-venv sshpass npm curl)
        local missing=()

        for pkg in "${packages[@]}"; do
            if ! dpkg -s "$pkg" >/dev/null 2>&1; then
                missing+=("$pkg")
            fi
        done

        if [ ${#missing[@]} -gt 0 ]; then
            echo "Installing system packages: ${missing[*]}"
            sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get update -qq
            sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get install -y -qq "${missing[@]}"
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
        export DEBIAN_FRONTEND=noninteractive
        export NEEDRESTART_MODE=a
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get install -y -qq nodejs
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
    
    # Install remaining requirements (includes ansible, flask, bcrypt, etc.)
    echo "Installing packages from requirements.txt..."
    if ! "$PIP_BIN" install -r "${SCRIPT_DIR}/requirements.txt"; then
        echo "Error: Failed to install packages from requirements.txt"
        echo "Attempting to install packages individually..."
        
        # Install critical packages individually
        "$PIP_BIN" install Flask>=2.3.0 || echo "Warning: Flask installation failed"
        "$PIP_BIN" install Werkzeug>=2.3.0 || echo "Warning: Werkzeug installation failed"
        "$PIP_BIN" install bcrypt>=4.0.0 || echo "Warning: bcrypt installation failed"
        "$PIP_BIN" install PyYAML>=6.0 || echo "Warning: PyYAML installation failed"
        "$PIP_BIN" install pywinrm>=0.3.0 || echo "Warning: pywinrm installation failed"
        "$PIP_BIN" install requests>=2.31.0 || echo "Warning: requests installation failed"
        "$PIP_BIN" install "ansible>=6.0.0" || echo "Warning: ansible installation failed"
        "$PIP_BIN" install "ansible-core>=2.13.0" || echo "Warning: ansible-core installation failed"
    fi
    
    # Verify Ansible is installed
    if [ ! -f "${VENV_PATH}/bin/ansible-playbook" ]; then
        echo "Warning: ansible-playbook not found in virtual environment."
        echo "Attempting to install Ansible explicitly..."
        "$PIP_BIN" install ansible ansible-core || {
            echo "Error: Failed to install Ansible."
            exit 1
        }
    fi
    
    # Verify installation
    if [ -f "${VENV_PATH}/bin/ansible-playbook" ]; then
        ANSIBLE_VERSION=$("${VENV_PATH}/bin/ansible-playbook" --version 2>/dev/null | head -n 1)
        echo "✓ Ansible installed: ${ANSIBLE_VERSION}"
    else
        echo "Error: Failed to install Ansible. Please install manually:"
        echo "  ${PIP_BIN} install ansible ansible-core"
        exit 1
    fi
    
    # Verify ansible-playbook is available
    if ! "$VENV_PATH/bin/ansible-playbook" --version &>/dev/null; then
        echo "Warning: ansible-playbook not found after installation."
        echo "You may need to install Ansible manually: $PIP_BIN install ansible"
    else
        echo "✓ Ansible installed successfully"
    fi
    
    # Verify all critical packages are installed
    echo "Verifying critical Python packages..."
    
    CRITICAL_PACKAGES=("flask" "bcrypt" "yaml" "requests")
    MISSING_PACKAGES=()
    
    for package in "${CRITICAL_PACKAGES[@]}"; do
        if ! "${PYTHON_BIN}" -c "import ${package}" 2>/dev/null; then
            MISSING_PACKAGES+=("${package}")
        fi
    done
    
    if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
        echo "Warning: Missing packages: ${MISSING_PACKAGES[*]}"
        echo "Installing missing packages..."
        
        for package in "${MISSING_PACKAGES[@]}"; do
            case "$package" in
                "flask")
                    echo "Installing Flask and Werkzeug..."
                    "$PIP_BIN" install --upgrade Flask Werkzeug || {
                        echo "Error: Failed to install Flask"
                        exit 1
                    }
                    ;;
                "bcrypt")
                    echo "Installing bcrypt..."
                    "$PIP_BIN" install --upgrade bcrypt || {
                        echo "Error: Failed to install bcrypt"
                        exit 1
                    }
                    ;;
                "yaml")
                    echo "Installing PyYAML..."
                    "$PIP_BIN" install --upgrade --ignore-installed PyYAML || {
                        echo "Error: Failed to install PyYAML"
                        exit 1
                    }
                    ;;
                "requests")
                    echo "Installing requests..."
                    "$PIP_BIN" install --upgrade requests || {
                        echo "Error: Failed to install requests"
                        exit 1
                    }
                    ;;
            esac
        done
        
        # Verify again - this is critical, fail if still missing
        echo "Verifying installed packages..."
        for package in "${MISSING_PACKAGES[@]}"; do
            if ! "${PYTHON_BIN}" -c "import ${package}" 2>/dev/null; then
                echo "Error: ${package} still not available after installation attempt."
                echo "This is a critical package. Please install manually:"
                echo "  ${PIP_BIN} install ${package}"
                exit 1
            fi
        done
        echo "✓ All missing packages installed successfully"
    fi
    
    # Show installed versions
    if "${PYTHON_BIN}" -c "import flask" 2>/dev/null; then
        FLASK_VERSION=$("${PYTHON_BIN}" -c "import flask; print(flask.__version__)" 2>/dev/null)
        echo "✓ Flask: ${FLASK_VERSION}"
    fi
    
    if "${PYTHON_BIN}" -c "import bcrypt" 2>/dev/null; then
        echo "✓ bcrypt: installed"
    fi
    
    if "${PYTHON_BIN}" -c "import yaml" 2>/dev/null; then
        echo "✓ PyYAML: installed"
    fi
    
    if "${PYTHON_BIN}" -c "import requests" 2>/dev/null; then
        echo "✓ requests: installed"
    fi
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
        # Pass non-interactive environment to child script
        DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a bash "${SCRIPT_DIR}/scripts/install-podman.sh"
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
    # Run check script - it exits with 1 if not running, which is expected
    # Use || true to prevent set -e from exiting
    PROM_STATUS=$(bash "${SCRIPT_DIR}/scripts/check-prometheus-service.sh" 2>/dev/null || echo "not_running")
    
    # Clean up the status string
    PROM_STATUS=$(echo "$PROM_STATUS" | tail -n 1 | tr -d '\r\n' | xargs)
    
    case "$PROM_STATUS" in
        "podman_container")
            echo "✓ Prometheus is already running in Podman container"
            ;;
        "systemd_service")
            echo "✓ Prometheus is already running as systemd service"
            ;;
        "port_listening")
            echo "✓ Prometheus is already running (port 9090 is listening)"
            ;;
        "not_running"|"")
            # Check if container exists but is stopped
            CONTAINER_STOPPED=false
            if command -v podman &> /dev/null; then
                if podman ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^prometheus$"; then
                    CONTAINER_STATUS=$(podman inspect prometheus --format='{{.State.Status}}' 2>/dev/null || echo "")
                    if [ "$CONTAINER_STATUS" = "exited" ] || [ "$CONTAINER_STATUS" = "stopped" ]; then
                        echo "Prometheus container exists but is stopped. Starting it..."
                        if podman start prometheus 2>/dev/null; then
                            echo "✓ Prometheus container started"
                            sleep 3
                            # Verify it's running
                            if podman ps --format "{{.Names}}" 2>/dev/null | grep -q "^prometheus$"; then
                                echo "✓ Prometheus is now running"
                                CONTAINER_STOPPED=true
                            fi
                        fi
                    fi
                fi
            fi
            
            # If still not running, deploy fresh
            if [ "$CONTAINER_STOPPED" = "false" ]; then
                echo "Prometheus is not running. Deploying Prometheus..."
                if [ -f "${SCRIPT_DIR}/scripts/install-prometheus.sh" ]; then
                    # Temporarily disable exit on error for this command
                    set +e
                    DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a bash "${SCRIPT_DIR}/scripts/install-prometheus.sh" start
                    INSTALL_EXIT=$?
                    set -e
                    
                    if [ $INSTALL_EXIT -ne 0 ]; then
                        echo "Warning: Prometheus deployment returned exit code $INSTALL_EXIT"
                        echo "This may be because:"
                        echo "  - Prometheus is already installed as a systemd service"
                        echo "  - Prometheus container is already running"
                        echo "  - Installation failed (check logs above)"
                        echo ""
                        echo "Continuing anyway - you can check status with:"
                        echo "  bash ${SCRIPT_DIR}/scripts/check-prometheus-service.sh"
                        echo "Or deploy manually with:"
                        echo "  bash ${SCRIPT_DIR}/scripts/install-prometheus.sh start"
                    else
                        echo "✓ Prometheus deployment completed"
                    fi
                else
                    echo "Error: install-prometheus.sh not found"
                    echo "Continuing without Prometheus deployment..."
                fi
            fi
            ;;
        *)
            echo "Unknown Prometheus status: ${PROM_STATUS}"
            echo "Attempting to deploy Prometheus..."
            if [ -f "${SCRIPT_DIR}/scripts/install-prometheus.sh" ]; then
                set +e
                DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a bash "${SCRIPT_DIR}/scripts/install-prometheus.sh" start
                set -e
            fi
            ;;
    esac
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

# Final verification of all critical packages before starting Flask
echo "Verifying all critical Python packages..."
CRITICAL_PACKAGES=("flask" "bcrypt" "yaml" "requests")
MISSING_CRITICAL=()

for package in "${CRITICAL_PACKAGES[@]}"; do
    if ! "${PYTHON_BIN}" -c "import ${package}" 2>/dev/null; then
        MISSING_CRITICAL+=("${package}")
    fi
done

if [ ${#MISSING_CRITICAL[@]} -gt 0 ]; then
    echo "Error: Missing critical packages: ${MISSING_CRITICAL[*]}"
    echo "Installing missing packages..."
    
    for package in "${MISSING_CRITICAL[@]}"; do
        case "$package" in
            "flask")
                "${PIP_BIN}" install --upgrade Flask Werkzeug || {
                    echo "Error: Failed to install Flask"
                    exit 1
                }
                ;;
            "bcrypt")
                "${PIP_BIN}" install --upgrade bcrypt || {
                    echo "Error: Failed to install bcrypt"
                    exit 1
                }
                ;;
            "yaml")
                "${PIP_BIN}" install --upgrade --ignore-installed PyYAML || {
                    echo "Error: Failed to install PyYAML"
                    exit 1
                }
                ;;
            "requests")
                "${PIP_BIN}" install --upgrade requests || {
                    echo "Error: Failed to install requests"
                    exit 1
                }
                ;;
        esac
    done
    
    # Final verification - fail if still missing
    for package in "${MISSING_CRITICAL[@]}"; do
        if ! "${PYTHON_BIN}" -c "import ${package}" 2>/dev/null; then
            echo "Error: ${package} still not available after installation."
            echo "Please install manually:"
            echo "  cd ${SCRIPT_DIR}"
            echo "  source .venv/bin/activate"
            echo "  pip install ${package}"
            exit 1
        fi
    done
fi

echo "✓ Flask and dependencies verified"
echo ""

"${PYTHON_BIN}" app.py
