#!/bin/bash
# Start the Node Exporter Installation Web UI

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed"
    exit 1
fi

# Check if required packages are installed
if ! python3 -c "import flask" &> /dev/null; then
    echo "Installing required Python packages..."
    pip install -r requirements.txt
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create necessary directories
mkdir -p "${SCRIPT_DIR}/certs"
mkdir -p "${SCRIPT_DIR}/web-ui/uploads"
mkdir -p "${SCRIPT_DIR}/tmp"

# Start the Flask application
echo "Starting Node Exporter Installation Web UI..."
echo "Access the application at http://localhost:5000"
echo "Press Ctrl+C to stop"
echo ""

cd "${SCRIPT_DIR}/web-ui"
python3 app.py

