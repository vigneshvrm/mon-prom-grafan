# Initial Setup Guide - Production Infrastructure

This guide will help you set up Podman and Prometheus for production use using the new Ansible playbooks.

## Prerequisites

- Ansible 2.9+ installed
- Python 3.6+ installed
- sudo/root access on the target machine
- Internet connection for downloading packages and container images

## Quick Setup (Recommended)

### Step 1: Install Podman

```bash
cd Monitoring
ansible-playbook playbooks/install-podman.yml
```

This will:
- Detect your Linux distribution
- Install Podman with all required tools (buildah, skopeo)
- Configure storage and networking
- Verify installation

### Step 2: Setup Prometheus

```bash
ansible-playbook playbooks/setup-prometheus-podman.yml
```

This will:
- Create Prometheus container with production settings
- Configure resource limits
- Set up health checks
- Create systemd service
- Configure firewall

### Step 3: Verify Setup

```bash
# Check Podman
podman --version
podman ps

# Check Prometheus
curl http://localhost:9090/-/healthy
curl http://localhost:9090/-/ready

# Access Prometheus UI
# Open browser: http://localhost:9090
```

## Custom Configuration

### Using Variables

Create a variables file `playbooks/vars/custom.yml`:

```yaml
prometheus_version: "v2.48.0"
prometheus_port: 9090
prometheus_retention: "90d"
container_memory_limit: "4G"
container_cpu_limit: "4.0"
```

Run with custom variables:

```bash
ansible-playbook playbooks/setup-prometheus-podman.yml -e @playbooks/vars/custom.yml
```

### Command Line Variables

```bash
ansible-playbook playbooks/setup-prometheus-podman.yml \
  -e "prometheus_port=9091" \
  -e "prometheus_retention=60d" \
  -e "container_memory_limit=4G"
```

## Production Features

### Security
- ✅ Non-root container execution
- ✅ Admin API disabled by default
- ✅ Read-only config mount
- ✅ Resource limits enforced

### Reliability
- ✅ Automatic restart on failure
- ✅ Health checks enabled
- ✅ Systemd service integration
- ✅ Graceful shutdown handling

### Performance
- ✅ Memory limits
- ✅ CPU limits
- ✅ Storage retention
- ✅ Query concurrency limits

## Troubleshooting

### Podman Installation Issues

```bash
# Check distribution
cat /etc/os-release

# Manual installation (if playbook fails)
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y podman

# RHEL/CentOS
sudo yum install -y podman

# Verify
podman --version
```

### Prometheus Container Issues

```bash
# Check container status
podman ps -a | grep prometheus

# Check logs
podman logs prometheus

# Check configuration
podman exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Restart container
podman restart prometheus
```

### Port Already in Use

```bash
# Check what's using port 9090
sudo netstat -tuln | grep 9090
# or
sudo ss -tuln | grep 9090

# Change port in playbook or use variable
ansible-playbook playbooks/setup-prometheus-podman.yml -e "prometheus_port=9091"
```

## Next Steps

After successful setup:

1. **Access Prometheus UI**: http://localhost:9090
2. **Install Node Exporters**: Use existing playbooks to install node exporters on target servers
3. **Configure Alerts**: Add alert rules to Prometheus configuration
4. **Set up Grafana**: Connect Grafana to Prometheus for visualization

## Integration with Existing System

The new playbooks are designed to work alongside your existing setup:

- Existing `scripts/install-podman.sh` can still be used
- Existing `scripts/install-prometheus.sh` can still be used
- New Ansible playbooks provide production-grade alternative
- Both approaches can coexist

## Support

For detailed information, see:
- `playbooks/README-PRODUCTION.md` - Detailed documentation
- `README.md` - Main project documentation

