# Production-Grade Infrastructure Setup

This directory contains production-ready Ansible playbooks for setting up Podman and Prometheus in a production environment.

## Playbooks Overview

### 1. `install-podman.yml`
Production-grade Podman installation playbook that:
- Supports multiple Linux distributions (Ubuntu/Debian, RHEL/CentOS, Fedora, Arch, SUSE)
- Installs Podman with all required tools (buildah, skopeo)
- Configures storage and networking
- Sets up rootless container support (optional)
- Configures log rotation
- Verifies installation with test containers

### 2. `setup-prometheus-podman.yml`
Production-grade Prometheus setup in Podman that:
- Creates Prometheus container with production settings
- Configures resource limits (CPU, memory)
- Sets up health checks and monitoring
- Configures data retention and storage limits
- Enables lifecycle management API
- Creates systemd service for container management
- Configures firewall rules

### 3. `setup-infrastructure.yml`
Orchestration playbook that runs both Podman installation and Prometheus setup.

## Quick Start

### Option 1: Run Complete Setup (Recommended)

```bash
# Install Podman first
ansible-playbook playbooks/install-podman.yml

# Then setup Prometheus
ansible-playbook playbooks/setup-prometheus-podman.yml
```

### Option 2: Run Individual Playbooks

```bash
# Only install Podman
ansible-playbook playbooks/install-podman.yml

# Only setup Prometheus (requires Podman)
ansible-playbook playbooks/setup-prometheus-podman.yml
```

## Configuration

### Podman Installation Variables

Edit `playbooks/install-podman.yml` or pass variables:

```yaml
podman_version: "latest"  # or specific version like "4.5.1"
enable_rootless: false
configure_networking: true
configure_storage: true
storage_driver: "overlay"
```

### Prometheus Setup Variables

Edit `playbooks/setup-prometheus-podman.yml` or pass variables:

```yaml
prometheus_version: "latest"  # or "v2.48.0"
prometheus_port: 9090
prometheus_retention: "30d"
prometheus_scrape_interval: "15s"
container_memory_limit: "2G"
container_cpu_limit: "2.0"
```

### Using Variables File

Create `playbooks/vars/production.yml`:

```yaml
prometheus_version: "v2.48.0"
prometheus_port: 9090
prometheus_retention: "90d"
container_memory_limit: "4G"
container_cpu_limit: "4.0"
```

Then run:

```bash
ansible-playbook playbooks/setup-prometheus-podman.yml -e @playbooks/vars/production.yml
```

## Production Best Practices

### Security
- Prometheus runs as non-root user (`nobody`)
- Admin API is disabled by default
- Container uses read-only config mount
- Health checks enabled for automatic recovery

### Resource Management
- Memory limits prevent resource exhaustion
- CPU limits ensure fair resource sharing
- Storage retention prevents disk fill
- Max query concurrency limits

### High Availability
- Container restart policy: `unless-stopped`
- Systemd service for automatic startup
- Health checks with automatic recovery
- Graceful shutdown handling

### Monitoring
- Self-monitoring enabled
- Health endpoint: `http://localhost:9090/-/healthy`
- Readiness endpoint: `http://localhost:9090/-/ready`
- Metrics endpoint: `http://localhost:9090/metrics`

## Verification

### Check Podman Installation

```bash
podman --version
podman info
podman run --rm hello-world
```

### Check Prometheus Container

```bash
# Check container status
podman ps --filter "name=prometheus"

# Check container logs
podman logs prometheus

# Check container health
podman inspect prometheus --format='{{.State.Health.Status}}'

# Test Prometheus API
curl http://localhost:9090/-/healthy
curl http://localhost:9090/-/ready
```

### Check Systemd Service

```bash
systemctl status prometheus-podman.service
systemctl enable prometheus-podman.service
```

## Troubleshooting

### Podman Installation Fails

1. Check distribution support:
   ```bash
   cat /etc/os-release
   ```

2. Install dependencies manually if needed:
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install -y podman buildah skopeo
   ```

### Prometheus Container Won't Start

1. Check logs:
   ```bash
   podman logs prometheus
   ```

2. Check configuration:
   ```bash
   podman exec prometheus promtool check config /etc/prometheus/prometheus.yml
   ```

3. Check port availability:
   ```bash
   netstat -tuln | grep 9090
   ```

### Container Health Check Fails

1. Check container status:
   ```bash
   podman inspect prometheus --format='{{.State.Status}}'
   ```

2. Check resource usage:
   ```bash
   podman stats prometheus
   ```

3. Restart container:
   ```bash
   podman restart prometheus
   ```

## Maintenance

### Update Prometheus

```bash
# Pull new image
podman pull docker.io/prom/prometheus:latest

# Stop and remove old container
podman stop prometheus
podman rm prometheus

# Run setup playbook again
ansible-playbook playbooks/setup-prometheus-podman.yml
```

### Backup Prometheus Configuration

```bash
# Backup configuration
sudo cp /etc/prometheus/prometheus.yml /etc/prometheus/prometheus.yml.backup.$(date +%Y%m%d)
```

### Reload Prometheus Configuration

```bash
# Reload without restart (if lifecycle API enabled)
curl -X POST http://localhost:9090/-/reload

# Or restart container
podman restart prometheus
```

## Integration with Node Exporter Setup

After setting up Podman and Prometheus, you can use the existing node exporter playbooks:

```bash
# Install node exporter on target servers
ansible-playbook -i hosts.yml playbooks/main.yml
```

The Prometheus configuration will automatically include node exporter targets.

## Support

For issues or questions:
1. Check container logs: `podman logs prometheus`
2. Check systemd logs: `journalctl -u prometheus-podman.service`
3. Verify configuration: `podman exec prometheus promtool check config /etc/prometheus/prometheus.yml`

