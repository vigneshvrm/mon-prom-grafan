#!/bin/bash
# Setup and start Prometheus in Podman container

set -e

PROMETHEUS_IMAGE="docker.io/prom/prometheus:latest"
PROMETHEUS_CONTAINER_NAME="prometheus"
PROMETHEUS_PORT="9090"
PROMETHEUS_CONFIG_DIR="/etc/prometheus"

check_existing_prometheus() {
    # Check if Prometheus is running as systemd service
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet prometheus 2>/dev/null; then
            echo "ERROR: Prometheus is already installed and running as a systemd service."
            echo "Please stop it first with: sudo systemctl stop prometheus"
            echo "Or use the existing installation."
            exit 1
        fi
    fi
    
    # Check if Prometheus container is running
    if command -v podman &> /dev/null; then
        if podman ps --format "{{.Names}}" 2>/dev/null | grep -q "^${PROMETHEUS_CONTAINER_NAME}$"; then
            if podman inspect "${PROMETHEUS_CONTAINER_NAME}" --format='{{.State.Status}}' 2>/dev/null | grep -q "running"; then
                echo "ERROR: Prometheus container is already running."
                echo "Use 'podman restart prometheus' or 'podman stop prometheus' to manage it."
                exit 1
            fi
        fi
    fi
    
    echo "✓ No existing Prometheus installation found. Proceeding with installation..."
}

ensure_podman() {
    if ! command -v podman &> /dev/null; then
        echo "Podman is not installed. Please install it first."
        exit 1
    fi
}

check_container_running() {
    if podman ps --format "{{.Names}}" | grep -q "^${PROMETHEUS_CONTAINER_NAME}$"; then
        return 0
    else
        return 1
    fi
}

check_container_exists() {
    if podman ps -a --format "{{.Names}}" | grep -q "^${PROMETHEUS_CONTAINER_NAME}$"; then
        return 0
    else
        return 1
    fi
}

create_prometheus_config() {
    # Create directory with sudo if needed
    if [ ! -d "${PROMETHEUS_CONFIG_DIR}" ]; then
        sudo mkdir -p "${PROMETHEUS_CONFIG_DIR}"
        sudo chmod 755 "${PROMETHEUS_CONFIG_DIR}"
    fi
    
    if [ ! -f "${PROMETHEUS_CONFIG_DIR}/prometheus.yml" ]; then
        sudo tee "${PROMETHEUS_CONFIG_DIR}/prometheus.yml" > /dev/null <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF
        sudo chmod 644 "${PROMETHEUS_CONFIG_DIR}/prometheus.yml"
        echo "Created default Prometheus configuration at ${PROMETHEUS_CONFIG_DIR}/prometheus.yml"
    fi
}

pull_prometheus_image() {
    echo "Pulling Prometheus image..."
    podman pull "${PROMETHEUS_IMAGE}"
}

start_prometheus_container() {
    if check_container_exists; then
        echo "Container ${PROMETHEUS_CONTAINER_NAME} exists. Starting it..."
        podman start "${PROMETHEUS_CONTAINER_NAME}"
    else
        echo "Creating and starting Prometheus container..."
        podman run -d \
            --name "${PROMETHEUS_CONTAINER_NAME}" \
            -v /etc/hosts:/etc/hosts \
            --dns 8.8.8.8 \
            --dns 1.1.1.1 \
            -v "${PROMETHEUS_CONFIG_DIR}:/etc/prometheus" \
            -p "${PROMETHEUS_PORT}:9090" \
            "${PROMETHEUS_IMAGE}" \
            --config.file=/etc/prometheus/prometheus.yml
        
        echo "Prometheus container created and started."
    fi
    
    # Wait for Prometheus to be ready
    echo "Waiting for Prometheus to start..."
    sleep 5
    
    # Check if Prometheus is responding
    for i in {1..30}; do
        if curl -s http://localhost:${PROMETHEUS_PORT}/-/healthy > /dev/null 2>&1; then
            echo "✓ Prometheus is running and healthy on port ${PROMETHEUS_PORT}"
            return 0
        fi
        sleep 1
    done
    
    echo "Warning: Prometheus container started but health check failed."
    return 1
}

stop_prometheus_container() {
    if check_container_running; then
        echo "Stopping Prometheus container..."
        podman stop "${PROMETHEUS_CONTAINER_NAME}"
    fi
}

restart_prometheus_container() {
    stop_prometheus_container
    sleep 2
    start_prometheus_container
}

get_prometheus_status() {
    if check_container_running; then
        echo "running"
    elif check_container_exists; then
        echo "stopped"
    else
        echo "not_found"
    fi
}

main() {
    case "${1:-start}" in
        start)
            # Check for existing Prometheus installation first
            check_existing_prometheus
            ensure_podman
            create_prometheus_config
            if ! check_container_running; then
                pull_prometheus_image
                start_prometheus_container
            else
                echo "✓ Prometheus container is already running"
            fi
            ;;
        stop)
            stop_prometheus_container
            ;;
        restart)
            restart_prometheus_container
            ;;
        status)
            STATUS=$(get_prometheus_status)
            echo "Prometheus container status: ${STATUS}"
            ;;
        *)
            echo "Usage: $0 {start|stop|restart|status}"
            exit 1
            ;;
    esac
}

main "$@"

