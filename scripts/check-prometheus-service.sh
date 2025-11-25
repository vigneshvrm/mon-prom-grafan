#!/bin/bash
# Check if Prometheus is running as systemd service or Podman container

check_podman_container() {
    if command -v podman &> /dev/null; then
        if podman ps --format "{{.Names}}" 2>/dev/null | grep -q "^prometheus$"; then
            # Check if container is actually running and healthy
            if podman inspect prometheus --format='{{.State.Status}}' 2>/dev/null | grep -q "running"; then
                return 0
            fi
        fi
    fi
    return 1
}

check_systemd_service() {
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet prometheus 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

check_port_listening() {
    # Check if port 9090 is listening (any process)
    if command -v ss &> /dev/null; then
        if ss -tuln 2>/dev/null | grep -q ":9090"; then
            return 0
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":9090"; then
            return 0
        fi
    fi
    return 1
}

main() {
    # Check Podman container first
    if check_podman_container; then
        echo "podman_container"
        exit 0
    fi
    
    # Check systemd service
    if check_systemd_service; then
        echo "systemd_service"
        exit 0
    fi
    
    # Check if port is listening
    if check_port_listening; then
        echo "port_listening"
        exit 0
    fi
    
    # Not running
    echo "not_running"
    exit 1
}

main "$@"

