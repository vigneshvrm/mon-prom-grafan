#!/bin/bash
# Install Windows Node Exporter on target server
# Usage: ./install-windows-node-exporter.sh <target_host> <username> <password> [port]

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MONITORING_DIR="$( cd "${SCRIPT_DIR}/.." && pwd )"

if [ $# -lt 3 ]; then
    echo "Usage: $0 <target_host> <username> <password> [port]"
    echo "Example: $0 192.168.1.10 Administrator mypassword 9100"
    exit 1
fi

TARGET_HOST="$1"
TARGET_USER="$2"
TARGET_PASS="$3"
NODE_EXPORTER_PORT="${4:-9100}"

echo "========================================="
echo "  Windows Node Exporter Installation"
echo "========================================="
echo "Target Host: $TARGET_HOST"
echo "Username: $TARGET_USER"
echo "Port: $NODE_EXPORTER_PORT"
echo ""

# Create temporary inventory file
TEMP_INVENTORY=$(mktemp)
cat > "$TEMP_INVENTORY" <<EOF
[windows]
${TARGET_HOST} ansible_host=${TARGET_HOST} ansible_user=${TARGET_USER} ansible_password=${TARGET_PASS} ansible_connection=winrm ansible_port=5985 ansible_winrm_transport=basic ansible_winrm_server_cert_validation=ignore ansible_become=false
EOF

# Create temporary extra vars file
TEMP_VARS=$(mktemp)
cat > "$TEMP_VARS" <<EOF
{
  "target_os": "windows",
  "node_exporter_port": "${NODE_EXPORTER_PORT}"
}
EOF

echo "Running Ansible playbook..."
cd "$MONITORING_DIR"

ansible-playbook \
    -i "$TEMP_INVENTORY" \
    playbooks/windows-node-exporter.yml \
    -e "@${TEMP_VARS}" \
    -v

# Cleanup
rm -f "$TEMP_INVENTORY" "$TEMP_VARS"

echo ""
echo "========================================="
echo "Installation complete!"
echo "Node Exporter should be running on: http://${TARGET_HOST}:${NODE_EXPORTER_PORT}/metrics"
echo "========================================="

