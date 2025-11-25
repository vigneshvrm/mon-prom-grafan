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
echo "[1/3] Checking Podman installation..."
if ! command -v podman &> /dev/null; then
    echo "Podman is not installed. Attempting to install..."
    if [ -f "${SCRIPT_DIR}/scripts/check-podman.sh" ]; then
        bash "${SCRIPT_DIR}/scripts/check-podman.sh"
    else
        echo "Error: check-podman.sh not found"
        exit 1
    fi
else
    PODMAN_VERSION=$(podman --version)
    echo "✓ Podman is installed: $PODMAN_VERSION"
fi
echo ""

# Step 2: Check Prometheus status and start if needed
echo "[2/3] Checking Prometheus status..."
if [ -f "${SCRIPT_DIR}/scripts/check-prometheus-service.sh" ]; then
    PROM_STATUS=$(bash "${SCRIPT_DIR}/scripts/check-prometheus-service.sh" 2>/dev/null || echo "not_running")
    
    if [ "$PROM_STATUS" = "not_running" ]; then
        echo "Prometheus is not running. Attempting to start Prometheus container..."
        echo "Note: This will check for existing installations first."
        if [ -f "${SCRIPT_DIR}/scripts/setup-prometheus.sh" ]; then
            bash "${SCRIPT_DIR}/scripts/setup-prometheus.sh" start || {
                echo "Warning: Failed to start Prometheus container. This may be because:"
                echo "  - Prometheus is already installed as a systemd service"
                echo "  - Prometheus container is already running"
                echo "  - Installation failed (check logs above)"
                echo ""
                echo "You can check status with:"
                echo "  bash ${SCRIPT_DIR}/scripts/check-prometheus-service.sh"
                echo "Or start manually with:"
                echo "  bash ${SCRIPT_DIR}/scripts/setup-prometheus.sh start"
            }
        else
            echo "Warning: setup-prometheus.sh not found. Skipping Prometheus setup."
        fi
    else
        echo "✓ Prometheus is already running (${PROM_STATUS})"
        echo "  No installation needed."
    fi
else
    echo "Warning: check-prometheus-service.sh not found. Skipping Prometheus check."
fi
echo ""

# Step 3: Start Web UI
echo "[3/3] Starting Web UI..."
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

# Check if Python dependencies are installed
if ! python3 -c "import flask" &> /dev/null; then
    echo "Installing required Python packages..."
    pip install -r requirements.txt
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
