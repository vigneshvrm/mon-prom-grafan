# Project Structure

```
ansible/
├── playbooks/                          # Ansible playbooks
│   ├── main.yml                        # Main orchestration playbook
│   ├── linux-node-exporter.yml        # Linux installation with distro detection
│   └── windows-node-exporter.yml      # Windows installation
│
├── scripts/                            # Helper scripts
│   ├── generate-cert.sh               # Certificate generation script
│   └── generate-password-hash.py      # Password hashing utility
│
├── web-ui/                             # Web frontend
│   ├── app.py                         # Flask web application
│   └── templates/
│       └── index.html                 # Web UI frontend
│
├── certs/                              # Generated certificates (auto-created)
│   ├── node_exporter.crt              # SSL certificate
│   └── node_exporter.key              # Private key
│
├── hosts.yml                           # Ansible inventory file
├── config.yml.example                  # Configuration template
├── requirements.txt                    # Python dependencies
├── README.md                           # Main documentation
├── INSTALL.md                          # Installation guide
├── start-ui.sh                         # Start script (Linux/Mac)
├── start-ui.bat                        # Start script (Windows)
└── .gitignore                          # Git ignore file
```

## File Descriptions

### Playbooks

- **main.yml**: Main orchestration playbook that detects OS and routes to appropriate playbook
- **linux-node-exporter.yml**: Linux installation with automatic distribution detection (Debian/Ubuntu, RHEL/CentOS, Arch, SUSE)
- **windows-node-exporter.yml**: Windows installation using Windows Exporter

### Scripts

- **generate-cert.sh**: Generates self-signed SSL/TLS certificates for secure communication
- **generate-password-hash.py**: Generates bcrypt password hashes for Basic Authentication

### Web UI

- **app.py**: Flask backend that:
  - Provides REST API for installation
  - Generates certificates and password hashes
  - Executes Ansible playbooks
  - Validates configuration

- **index.html**: Modern web interface for:
  - User input (OS, username, password, port)
  - Configuration validation
  - Installation execution
  - Real-time output display

## Features

### Security Features

1. **TLS/SSL Encryption**: Self-signed certificates with 2048-bit RSA keys
2. **Basic Authentication**: Bcrypt password hashing (cost factor 12)
3. **Firewall Configuration**: Automatic firewall rule setup
4. **Secure File Permissions**: Proper file permissions for certificates and keys

### Linux Support

- Automatic distribution detection
- Package manager detection (apt, yum, pacman, zypper)
- Distribution-specific dependency installation
- Systemd service creation
- Firewall configuration (iptables, firewalld, ufw)

### Windows Support

- Windows Exporter installation
- Windows Firewall configuration
- Service management
- Certificate generation using PowerShell

## Workflow

1. User fills form in web UI
2. Frontend validates configuration
3. Backend generates certificates (if needed)
4. Backend generates password hash
5. Backend executes Ansible playbook with extra vars
6. Ansible detects OS and runs appropriate playbook
7. Playbook installs Node Exporter with security features
8. Results displayed in web UI

## Configuration Flow

```
User Input (Web UI)
    ↓
Configuration Validation
    ↓
Certificate Generation (if needed)
    ↓
Password Hashing
    ↓
Ansible Extra Vars Creation
    ↓
Ansible Playbook Execution
    ↓
OS Detection
    ↓
Distribution-Specific Installation
    ↓
Security Configuration (TLS + Basic Auth)
    ↓
Service Start & Verification
    ↓
Result Display
```

