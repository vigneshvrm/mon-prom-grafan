# Debian Package Installation Guide

## Building the .deb Package

To create a Debian package for distribution:

```bash
cd Monitoring
bash scripts/package-release.sh --deb
```

This will create: `dist/inframonitor_1.0.0_all.deb`

## Installation

### On Debian/Ubuntu Systems

```bash
# Install the package
sudo dpkg -i dist/inframonitor_1.0.0_all.deb

# If dependencies are missing, install them:
sudo apt-get install -f
```

### What Happens During Installation

The installation process is **completely silent** - clients will not see:
- Ansible playbook execution
- Python dependency installation
- Prometheus container deployment
- System configuration details

All installation logs are written to `/var/log/inframonitor-install.log` (accessible only to root).

### Post-Installation

After installation, the service is automatically:
- Installed to `/opt/inframonitor`
- Configured as systemd service `inframonitor.service`
- Enabled to start on boot
- Started automatically

Check status:
```bash
sudo systemctl status inframonitor.service
sudo podman ps  # Should show prometheus container
```

## Uninstallation

```bash
sudo apt-get remove inframonitor
```

This will:
- Stop and disable the service
- Remove systemd service file
- Optionally remove `/opt/inframonitor` (if configured)

## Benefits of .deb Package

1. **Silent Installation**: All Ansible playbook execution is hidden
2. **Professional**: Standard Debian package format
3. **Dependency Management**: Automatic resolution of required packages
4. **Clean Uninstall**: Proper removal via package manager
5. **Logging**: Installation details logged to `/var/log/inframonitor-install.log`

## Troubleshooting

If installation fails silently, check the log:
```bash
sudo cat /var/log/inframonitor-install.log
```

Check service status:
```bash
sudo systemctl status inframonitor.service
sudo journalctl -u inframonitor.service -n 50
```

