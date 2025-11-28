#!/bin/bash
# Install Linux Node Exporter on target server
# Usage: ./install-linux-node-exporter.sh <target_host> <username> <password> [port]

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MONITORING_DIR="$( cd "${SCRIPT_DIR}/.." && pwd )"

if [ $# -lt 3 ]; then
    echo "Usage: $0 <target_host> <username> <password> [port]"
    echo "Example: $0 192.168.1.10 admin mypassword 9100"
    exit 1
fi

TARGET_HOST="$1"
TARGET_USER="$2"
TARGET_PASS="$3"
NODE_EXPORTER_PORT="${4:-9100}"

echo "========================================="
echo "  Linux Node Exporter Installation"
echo "========================================="
echo "Target Host: $TARGET_HOST"
echo "Username: $TARGET_USER"
echo "Port: $NODE_EXPORTER_PORT"
echo ""

# Create temporary inventory file
TEMP_INVENTORY=$(mktemp)
cat > "$TEMP_INVENTORY" <<EOF
[linux]
${TARGET_HOST} ansible_host=${TARGET_HOST} ansible_user=${TARGET_USER} ansible_password=${TARGET_PASS} ansible_become=true ansible_become_pass=${TARGET_PASS} ansible_ssh_common_args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
EOF

# Create temporary extra vars file
TEMP_VARS=$(mktemp)
cat > "$TEMP_VARS" <<EOF
{
  "target_os": "linux",
  "node_exporter_port": "${NODE_EXPORTER_PORT}"
}
EOF

echo "Running Ansible playbook..."
cd "$MONITORING_DIR"

ansible-playbook \
    -i "$TEMP_INVENTORY" \
    playbooks/linux-node-exporter.yml \
    -e "@${TEMP_VARS}" \
    -v

# Cleanup
rm -f "$TEMP_INVENTORY" "$TEMP_VARS"

echo ""
echo "========================================="
echo "Installation complete!"
echo "Node Exporter should be running on: http://${TARGET_HOST}:${NODE_EXPORTER_PORT}/metrics"
echo "========================================="

