#!/bin/bash

# Generate SSL/TLS certificate for Node Exporter
# Usage: ./generate-cert.sh [hostname] [ip_address]

set -e

HOSTNAME=${1:-$(hostname)}
IP_ADDRESS=${2:-127.0.0.1}
CERT_DIR="certs"
KEY_FILE="${CERT_DIR}/node_exporter.key"
CERT_FILE="${CERT_DIR}/node_exporter.crt"

# Create certs directory if it doesn't exist
mkdir -p "${CERT_DIR}"

echo "Generating SSL/TLS certificate for Node Exporter..."
echo "Hostname: ${HOSTNAME}"
echo "IP Address: ${IP_ADDRESS}"

# Generate certificate and key
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
  -keyout "${KEY_FILE}" \
  -out "${CERT_FILE}" \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=${HOSTNAME}" \
  -addext "subjectAltName = DNS:${HOSTNAME},DNS:localhost,IP:${IP_ADDRESS},IP:127.0.0.1"

# Set proper permissions
chmod 600 "${KEY_FILE}"
chmod 644 "${CERT_FILE}"

echo "Certificate generated successfully!"
echo "Certificate: ${CERT_FILE}"
echo "Private Key: ${KEY_FILE}"

# Display certificate info
echo ""
echo "Certificate Information:"
openssl x509 -in "${CERT_FILE}" -noout -subject -issuer -dates

