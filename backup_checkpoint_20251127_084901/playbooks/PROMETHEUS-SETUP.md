# Prometheus Container Setup

This document describes the Prometheus container configuration used in this project.

## Container Command

The Prometheus container is started with the following command:

```bash
podman run -d \
  --name prometheus \
  -v /etc/hosts:/etc/hosts \
  --dns 8.8.8.8 \
  --dns 1.1.1.1 \
  -v /etc/prometheus:/etc/prometheus \
  -p 9090:9090 \
  docker.io/prom/prometheus:latest \
  --config.file=/etc/prometheus/prometheus.yml
```

## Configuration Details

### Volume Mounts
- `/etc/hosts:/etc/hosts` - Mounts host's hosts file for name resolution
- `/etc/prometheus:/etc/prometheus` - Mounts Prometheus configuration directory

### DNS Configuration
- Primary DNS: `8.8.8.8` (Google DNS)
- Secondary DNS: `1.1.1.1` (Cloudflare DNS)

### Network
- Port mapping: `9090:9090` (host:container)
- Container can be accessed at: `http://localhost:9090`

### Configuration File
- Location: `/etc/prometheus/prometheus.yml`
- Managed on host system
- Automatically loaded by container

## Setup Methods

### Method 1: Using Ansible Playbook (Recommended)

```bash
ansible-playbook playbooks/setup-prometheus-podman.yml
```

This will:
1. Create `/etc/prometheus` directory if it doesn't exist
2. Create default `prometheus.yml` configuration
3. Pull Prometheus image
4. Start container with proper configuration

### Method 2: Using Shell Script

```bash
bash scripts/install-prometheus.sh start
```

### Method 3: Manual Setup

```bash
# Create directory
sudo mkdir -p /etc/prometheus

# Create default config (if needed)
sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

# Start container
podman run -d \
  --name prometheus \
  -v /etc/hosts:/etc/hosts \
  --dns 8.8.8.8 \
  --dns 1.1.1.1 \
  -v /etc/prometheus:/etc/prometheus \
  -p 9090:9090 \
  docker.io/prom/prometheus:latest \
  --config.file=/etc/prometheus/prometheus.yml
```

## Container Management

### Check Status
```bash
podman ps --filter "name=prometheus"
```

### View Logs
```bash
podman logs prometheus
```

### Stop Container
```bash
podman stop prometheus
```

### Start Container
```bash
podman start prometheus
```

### Restart Container
```bash
podman restart prometheus
```

### Remove Container
```bash
podman stop prometheus
podman rm prometheus
```

## Configuration Updates

### Edit Configuration
```bash
sudo nano /etc/prometheus/prometheus.yml
```

### Reload Configuration (without restart)
```bash
curl -X POST http://localhost:9090/-/reload
```

Note: The `--web.enable-lifecycle` flag must be enabled for reload to work.

### Restart Container (after config changes)
```bash
podman restart prometheus
```

## Verification

### Check Health
```bash
curl http://localhost:9090/-/healthy
```

### Check Readiness
```bash
curl http://localhost:9090/-/ready
```

### Access Web UI
Open browser: `http://localhost:9090`

## Troubleshooting

### Container Won't Start
1. Check logs: `podman logs prometheus`
2. Verify config: `podman exec prometheus promtool check config /etc/prometheus/prometheus.yml`
3. Check directory permissions: `ls -la /etc/prometheus`

### Configuration Not Loading
1. Verify file exists: `ls -la /etc/prometheus/prometheus.yml`
2. Check file permissions: Should be readable by container
3. Validate YAML syntax: `podman exec prometheus promtool check config /etc/prometheus/prometheus.yml`

### DNS Issues
- Container uses DNS servers 8.8.8.8 and 1.1.1.1
- Hosts file is mounted from `/etc/hosts`
- Check DNS resolution: `podman exec prometheus nslookup example.com`

