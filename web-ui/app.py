#!/usr/bin/env python3
"""
Flask web application for Node Exporter installation via Ansible
"""

import os
import json
import subprocess
import tempfile
import shutil
import sys
import logging
from logging.handlers import RotatingFileHandler
from datetime import datetime
from flask import Flask, render_template, request, jsonify, send_from_directory, after_this_request
from werkzeug.utils import secure_filename
import bcrypt
import yaml
from functools import wraps

# Add parent directory (Monitoring) to path for prometheus_manager import
monitoring_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, monitoring_dir)
from prometheus.prometheus_manager import PrometheusConfigManager
from database import get_database
from security_utils import (
    validate_ip_address, validate_port, sanitize_hostname, sanitize_username,
    sanitize_server_name, sanitize_server_id, sanitize_path, escape_ansible_value,
    validate_install_request
)

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['SECRET_KEY'] = os.urandom(24)

# SECURITY: Add security headers to all responses
@app.after_request
def set_security_headers(response):
    """Add security headers to all responses"""
    # Add basic security headers to all responses
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    
    # Only add CSP to HTML responses (not API or static assets)
    # CSP needs to allow React/Vite inline scripts and styles
    if not request.path.startswith('/api/') and not request.path.startswith('/assets/'):
        # Relaxed CSP for React to work - allows inline scripts/styles needed by Vite/React
        # In production, consider tightening this
        response.headers['Content-Security-Policy'] = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' http://localhost:* ws://localhost:*;"
    
    # HSTS only for HTTPS (skip for HTTP to avoid issues)
    # response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    
    return response

# SECURITY: Simple rate limiting decorator (basic implementation)
# For production, use Flask-Limiter
_rate_limit_store = {}
_rate_limit_window = 60  # 60 seconds
_rate_limit_max_requests = 100  # 100 requests per window

def rate_limit(f):
    """Simple rate limiting decorator"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        client_ip = request.remote_addr
        current_time = datetime.now().timestamp()
        
        # Clean old entries
        if client_ip in _rate_limit_store:
            _rate_limit_store[client_ip] = [
                req_time for req_time in _rate_limit_store[client_ip]
                if current_time - req_time < _rate_limit_window
            ]
        else:
            _rate_limit_store[client_ip] = []
        
        # Check rate limit
        if len(_rate_limit_store[client_ip]) >= _rate_limit_max_requests:
            app.logger.warning(f"Rate limit exceeded for IP: {client_ip}")
            return jsonify({
                'success': False,
                'error': 'Rate limit exceeded. Please try again later.'
            }), 429
        
        # Add current request
        _rate_limit_store[client_ip].append(current_time)
        
        return f(*args, **kwargs)
    return decorated_function

# Ensure upload and certs directories exist
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs('certs', exist_ok=True)

# Configure debug mode from environment variable or default to False
DEBUG_MODE = os.getenv('DEBUG_MODE', 'false').lower() in ('true', '1', 'yes', 'on')
app.config['DEBUG'] = DEBUG_MODE

# Configure logging to /var/log
LOG_DIR = '/var/log'
LOG_FILE = os.path.join(LOG_DIR, 'monitoring-app.log')
LOG_FORMAT = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
LOG_DATE_FORMAT = '%Y-%m-%d %H:%M:%S'

# Create log directory if it doesn't exist (requires appropriate permissions)
try:
    os.makedirs(LOG_DIR, exist_ok=True)
except PermissionError:
    # If we can't create /var/log, fall back to local logs directory
    LOG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'logs')
    LOG_FILE = os.path.join(LOG_DIR, 'monitoring-app.log')
    os.makedirs(LOG_DIR, exist_ok=True)

# Set log levels based on debug mode
# Debug mode: DEBUG, INFO, WARNING, ERROR (all logs)
# Normal mode: INFO, WARNING, ERROR (no DEBUG logs)
if DEBUG_MODE:
    FILE_LOG_LEVEL = logging.DEBUG
    CONSOLE_LOG_LEVEL = logging.DEBUG
    ROOT_LOG_LEVEL = logging.DEBUG
else:
    FILE_LOG_LEVEL = logging.INFO  # INFO and above (INFO, WARNING, ERROR)
    CONSOLE_LOG_LEVEL = logging.INFO
    ROOT_LOG_LEVEL = logging.INFO

# Configure logging
logging.basicConfig(
    level=ROOT_LOG_LEVEL,
    format=LOG_FORMAT,
    datefmt=LOG_DATE_FORMAT
)

# Create file handler with rotation (10MB max, keep 5 backup files)
file_handler = RotatingFileHandler(
    LOG_FILE,
    maxBytes=10*1024*1024,  # 10MB
    backupCount=5,
    encoding='utf-8'
)
file_handler.setLevel(FILE_LOG_LEVEL)
file_handler.setFormatter(logging.Formatter(LOG_FORMAT, LOG_DATE_FORMAT))

# Create console handler for development
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(CONSOLE_LOG_LEVEL)
console_handler.setFormatter(logging.Formatter(LOG_FORMAT, LOG_DATE_FORMAT))

# Get the Flask app logger and add handlers
app.logger.setLevel(ROOT_LOG_LEVEL)
app.logger.addHandler(file_handler)
app.logger.addHandler(console_handler)

# Also configure root logger
root_logger = logging.getLogger()
root_logger.setLevel(ROOT_LOG_LEVEL)
root_logger.addHandler(file_handler)
root_logger.addHandler(console_handler)

# Log application startup
app.logger.info("="*60)
app.logger.info("Monitoring Application Starting")
app.logger.info(f"Log file: {LOG_FILE}")
app.logger.info(f"Debug mode: {'ENABLED' if DEBUG_MODE else 'DISABLED'}")
app.logger.info(f"Log level: {'DEBUG (all logs)' if DEBUG_MODE else 'INFO (INFO, WARNING, ERROR only)'}")
app.logger.info(f"Python version: {sys.version}")
app.logger.info("="*60)

# Request logging middleware
@app.before_request
def log_request_info():
    """Log all incoming API requests"""
    if request.path.startswith('/api/'):
        app.logger.info(f"API Request: {request.method} {request.path} from {request.remote_addr}")

@app.after_request
def log_response_info(response):
    """Log API responses (only in debug mode)"""
    if request.path.startswith('/api/'):
        if DEBUG_MODE:
            app.logger.debug(f"API Response: {request.method} {request.path} - Status {response.status_code}")
        else:
            # Only log errors in non-debug mode
            if response.status_code >= 400:
                app.logger.warning(f"API Error Response: {request.method} {request.path} - Status {response.status_code}")
    return response

def check_prometheus_status():
    """Check if Prometheus is running (Podman container or systemd service)"""
    prometheus_config_path = '/etc/prometheus/prometheus.yml'
    
    # Check Podman container first
    try:
        result = subprocess.run(
            ['podman', 'ps', '--format', '{{.Names}}'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if 'prometheus' in result.stdout:
            # Verify container is actually running
            status_result = subprocess.run(
                ['podman', 'inspect', 'prometheus', '--format', '{{.State.Status}}'],
                capture_output=True,
                text=True,
                timeout=5
            )
            if 'running' in status_result.stdout:
                return {
                    'running': True,
                    'type': 'podman_container',
                    'config_path': prometheus_config_path,
                    'reload_api': 'http://localhost:9090/-/reload'
                }
    except:
        pass
    
    # Check systemd service
    try:
        result = subprocess.run(
            ['systemctl', 'is-active', 'prometheus'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            return {
                'running': True,
                'type': 'systemd_service',
                'config_path': '/etc/prometheus/prometheus.yml',
                'reload_api': 'http://localhost:9090/-/reload'
            }
    except:
        pass
    
    # Check if port 9090 is listening
    try:
        # Try ss first, then netstat
        try:
            result = subprocess.run(
                ['ss', '-tuln'],
                capture_output=True,
                text=True,
                timeout=5
            )
        except:
            result = subprocess.run(
                ['netstat', '-tuln'],
                capture_output=True,
                text=True,
                timeout=5
            )
        
        if ':9090' in result.stdout:
            return {
                'running': True,
                'type': 'port_listening',
                'config_path': '/etc/prometheus/prometheus.yml',
                'reload_api': 'http://localhost:9090/-/reload'
            }
    except:
        pass
    
    return {
        'running': False,
        'type': 'not_running',
        'config_path': prometheus_config_path,
        'reload_api': 'http://localhost:9090/-/reload'
    }

def generate_password_hash(password):
    """Generate bcrypt hash for password"""
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt(rounds=12)).decode('utf-8')

def create_ansible_config(config_data):
    """Create Ansible extra vars file"""
    # Normalize OS to lowercase and ensure it's valid
    os_value = config_data.get('os', 'linux')
    if isinstance(os_value, str):
        os_value = os_value.lower()
        if os_value == 'auto':
            os_value = 'linux'  # Default auto to linux
    
    extra_vars = {
        'target_os': os_value,
        'node_exporter_port': '9100',  # Default port, no config needed
    }
    
    # Add target server info if provided (for dynamic inventory)
    if config_data.get('target_host'):
        extra_vars['target_host'] = config_data.get('target_host')
        extra_vars['target_username'] = config_data.get('target_username', '')
        extra_vars['target_password'] = config_data.get('target_password', '')
    
    return extra_vars

def create_dynamic_inventory(target_host, target_username, target_password, os_type, monitoring_dir):
    """
    Create a temporary inventory file for a single host
    SECURITY: All inputs are validated and sanitized to prevent command injection
    """
    import tempfile
    
    # SECURITY: Validate and sanitize inputs
    sanitized_host = sanitize_hostname(target_host)
    if not sanitized_host:
        raise ValueError(f"Invalid target_host format: {target_host}")
    
    sanitized_user = sanitize_username(target_username)
    if not sanitized_user:
        raise ValueError(f"Invalid username format: {target_username}")
    
    # Password doesn't need sanitization for Ansible (it's used as-is in inventory)
    # But we'll escape it to be safe
    escaped_password = escape_ansible_value(target_password) if target_password else '""'
    
    # Determine connection type based on OS (normalize to lowercase)
    os_type = os_type.lower() if os_type else 'linux'
    
    # SECURITY: Use escaped values to prevent injection
    escaped_host = escape_ansible_value(sanitized_host)
    escaped_user = escape_ansible_value(sanitized_user)
    
    if os_type == 'windows':
        # Windows uses WinRM on port 5985 (HTTP) or 5986 (HTTPS)
        # Use port 5985 for basic auth (simpler setup)
        # Extended timeouts for WinRM operations
        inventory_content = f"""[windows]
{escaped_host} ansible_host={escaped_host} ansible_user={escaped_user} ansible_password={escaped_password} ansible_connection=winrm ansible_port=5985 ansible_winrm_transport=basic ansible_winrm_server_cert_validation=ignore ansible_become=false ansible_winrm_read_timeout_sec=60 ansible_winrm_operation_timeout_sec=60 ansible_winrm_connection_timeout=30
"""
    else:  # linux or auto (default to linux)
        inventory_content = f"""[linux]
{escaped_host} ansible_host={escaped_host} ansible_user={escaped_user} ansible_password={escaped_password} ansible_become=true ansible_become_pass={escaped_password} ansible_ssh_common_args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
"""
    
    # SECURITY: Create temporary inventory file in /tmp instead of project directory
    # Use system temp directory which is more secure
    temp_dir = tempfile.gettempdir()
    temp_inventory = tempfile.NamedTemporaryFile(mode='w', suffix='.yml', delete=False, dir=temp_dir)
    temp_inventory.write(inventory_content)
    temp_inventory.close()
    
    # Set restrictive permissions (read/write for owner only)
    os.chmod(temp_inventory.name, 0o600)
    
    return temp_inventory.name

def run_ansible_playbook(extra_vars, inventory_file='hosts.yml', prometheus_config=None):
    """Run Ansible playbook with given extra vars and optionally update Prometheus"""
    # Get Monitoring directory (parent of web-ui)
    monitoring_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    playbook_path = os.path.join(monitoring_dir, 'playbooks', 'main.yml')
    
    # Check if we need to create a dynamic inventory
    dynamic_inventory = None
    if extra_vars.get('target_host'):
        # Create dynamic inventory for single host
        dynamic_inventory = create_dynamic_inventory(
            extra_vars['target_host'],
            extra_vars.get('target_username', ''),
            extra_vars.get('target_password', ''),
            extra_vars.get('target_os', extra_vars.get('os', 'linux')),  # Use target_os or fallback to os
            monitoring_dir
        )
        inventory_path = dynamic_inventory
    else:
        # Use provided inventory file (should be in parent of Monitoring - ansible root)
        inventory_path = os.path.join(os.path.dirname(monitoring_dir), inventory_file)
    
    # Enable Prometheus auto-configuration if config is provided
    if prometheus_config:
        extra_vars['prometheus_auto_configure'] = True
    
    # SECURITY: Create temporary file in /tmp instead of project directory
    temp_dir = tempfile.gettempdir()
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False, dir=temp_dir) as f:
        json.dump(extra_vars, f)
        extra_vars_file = f.name
        # Set restrictive permissions
        os.chmod(extra_vars_file, 0o600)
    
    node_info_path = None
    try:
        # Create ansible config with aggressive timeouts to prevent hanging
        ansible_cfg_content = """[defaults]
host_key_checking = False
timeout = 10
retry_files_enabled = False
forks = 1
deprecation_warnings = False
command_warnings = False

[ssh_connection]
ssh_args = -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 -o ControlMaster=no -o ControlPersist=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
timeout = 10
pipelining = True
retries = 1

[winrm]
connection_timeout = 10
read_timeout_sec = 10
operation_timeout_sec = 10
"""
        ansible_cfg_path = os.path.join(monitoring_dir, 'ansible.cfg')
        with open(ansible_cfg_path, 'w') as f:
            f.write(ansible_cfg_content)
        
        # Find ansible-playbook command - prioritize virtual environment
        ansible_playbook_cmd = None
        
        # Check in virtual environment first (required)
        venv_path = os.path.join(monitoring_dir, '.venv')
        venv_ansible = os.path.join(venv_path, 'bin', 'ansible-playbook')
        if os.path.exists(venv_ansible):
            ansible_playbook_cmd = venv_ansible
            print(f"Using Ansible from virtual environment: {ansible_playbook_cmd}")
        else:
            # Fallback to system-wide
            import shutil
            ansible_playbook_cmd = shutil.which('ansible-playbook')
            if ansible_playbook_cmd:
                print(f"Using system Ansible: {ansible_playbook_cmd}")
        
        # If still not found, try common paths
        if not ansible_playbook_cmd:
            common_paths = [
                '/usr/local/bin/ansible-playbook',
                '/usr/bin/ansible-playbook',
                '/opt/homebrew/bin/ansible-playbook',
            ]
            for path in common_paths:
                if os.path.exists(path):
                    ansible_playbook_cmd = path
                    print(f"Using Ansible from: {ansible_playbook_cmd}")
                    break
        
        if not ansible_playbook_cmd:
            raise Exception(
                'ansible-playbook not found. Please run ./start-application.sh to install dependencies.\n'
                'Or install manually:\n'
                '  cd ' + monitoring_dir + '\n'
                '  source .venv/bin/activate\n'
                '  pip install ansible ansible-core'
            )
        
        # Debug: Print what we're running (SECURITY: Don't print passwords)
        print(f"Running Ansible playbook: {playbook_path}")
        print(f"Inventory: {inventory_path}")
        # SECURITY: Don't log passwords - create sanitized copy for logging
        sanitized_vars = {k: ('***REDACTED***' if 'password' in k.lower() or 'passwd' in k.lower() or 'pwd' in k.lower() else v) 
                         for k, v in extra_vars.items()}
        print(f"Extra vars: {sanitized_vars}")
        
        # Run ansible-playbook with aggressive timeout settings
        cmd = [
            ansible_playbook_cmd,
            '-i', inventory_path,
            playbook_path,
            '-e', f'@{extra_vars_file}',
            '-v',
            '--forks=1',  # Run one host at a time
            '--timeout=10',  # 10 second connection timeout
        ]
        
        # Add SSH args for Linux connections (check target_os, not os)
        target_os_value = extra_vars.get('target_os', 'linux').lower()
        if target_os_value != 'windows':
            cmd.extend([
                '--ssh-common-args=-o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2'
            ])
        
        # Run with timeout - much shorter now
        print(f"Executing Ansible command: {' '.join(cmd)}")
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=monitoring_dir,
            timeout=600,  # 10 minutes max (should be much faster with timeouts)
            env={**os.environ, 'ANSIBLE_CONFIG': ansible_cfg_path}
        )
        
        # Log result for debugging
        app.logger.info(f"Ansible playbook execution completed with return code: {result.returncode}")
        if result.returncode != 0:
            app.logger.error(f"Ansible playbook failed (return code: {result.returncode})")
            if result.stdout:
                app.logger.debug(f"Ansible stdout (last 20 lines):\n{chr(10).join(result.stdout.split(chr(10))[-20:])}")
            if result.stderr:
                app.logger.error(f"Ansible stderr (last 20 lines):\n{chr(10).join(result.stderr.split(chr(10))[-20:])}")
        else:
            app.logger.info("Ansible playbook executed successfully")
        
        # Clean up ansible.cfg
        if os.path.exists(ansible_cfg_path):
            try:
                os.unlink(ansible_cfg_path)
            except:
                pass
        
        # If installation succeeded and Prometheus config is provided, update Prometheus
        prometheus_updated = False
        node_info = None
        
        if result.returncode == 0 and prometheus_config:
            # Try to find node info file
            node_info_paths = [
                os.path.join(monitoring_dir, 'tmp', 'node_exporter_info.json'),
                os.path.join(os.path.dirname(monitoring_dir), 'tmp', 'node_exporter_info.json'),
                '/tmp/node_exporter_info.json',
                'C:\\Temp\\node_exporter_info.json'
            ]
            
            for path in node_info_paths:
                if os.path.exists(path):
                    try:
                        # SECURITY: Check file size before reading
                        file_size = os.path.getsize(path)
                        if file_size > 1024 * 1024:  # 1MB limit
                            app.logger.warning(f"Node info file too large: {path} ({file_size} bytes)")
                            break
                        
                        with open(path, 'r') as f:
                            node_info = json.load(f)
                        node_info_path = path  # Store path for cleanup
                        break
                    except (json.JSONDecodeError, IOError) as e:
                        app.logger.warning(f"Error reading node info file {path}: {e}")
                        continue
            
            # Update Prometheus if node info found
            if node_info:
                try:
                    prom_manager = PrometheusConfigManager(
                        prometheus_config_path=prometheus_config.get('config_path', '/etc/prometheus/prometheus.yml'),
                        prometheus_reload_api=prometheus_config.get('reload_api')
                    )
                    
                    if prom_manager.add_scrape_target(node_info):
                        prometheus_updated = True
                        app.logger.info(f"Prometheus scrape target added: {node_info.get('hostname', 'unknown')}")
                        # Reload Prometheus if API is configured
                        if prometheus_config.get('reload_api'):
                            prom_manager.reload_prometheus()
                            app.logger.info("Prometheus configuration reloaded")
                except Exception as e:
                    app.logger.error(f"Error updating Prometheus: {e}", exc_info=True)
        
        # Get the last few lines of output for better error display
        stdout_lines = result.stdout.split('\n') if result.stdout else []
        stderr_lines = result.stderr.split('\n') if result.stderr else []
        
        # Filter out deprecation warnings from stderr if playbook succeeded
        # These are warnings, not errors, and shouldn't cause failures
        if result.returncode == 0:
            stderr_lines = [line for line in stderr_lines 
                          if 'DEPRECATION WARNING' not in line.upper() 
                          and 'deprecation' not in line.lower()]
        
        # Extract last 50 lines for display
        stdout_display = '\n'.join(stdout_lines[-50:]) if len(stdout_lines) > 50 else result.stdout or ''
        stderr_display = '\n'.join(stderr_lines[-50:]) if len(stderr_lines) > 50 else '\n'.join(stderr_lines) if stderr_lines else ''
        
        # If playbook succeeded but there's only deprecation warnings in stderr, clear it
        if result.returncode == 0 and stderr_display:
            # Check if stderr only contains deprecation-related messages
            stderr_lower = stderr_display.lower()
            if 'deprecation' in stderr_lower and 'error' not in stderr_lower and 'failed' not in stderr_lower:
                stderr_display = ''  # Clear stderr if it's only deprecation warnings
        
        # Extract error message from output if playbook failed
        error_message = None
        if result.returncode != 0:
            # Look for common error patterns in stdout/stderr
            all_output = (result.stdout or '') + '\n' + (result.stderr or '')
            output_lines = all_output.split('\n')
            
            # Look for "fatal", "failed", "error" lines
            error_lines = []
            for line in output_lines:
                line_lower = line.lower()
                if any(keyword in line_lower for keyword in ['fatal:', 'failed:', 'error:', 'unreachable:', 'unable to']):
                    if 'deprecation' not in line_lower:  # Skip deprecation warnings
                        error_lines.append(line.strip())
            
            if error_lines:
                # Take the last few error lines (most relevant)
                error_message = ' | '.join(error_lines[-3:])
            else:
                # If no specific error found, use last non-empty line from stderr or stdout
                for line in reversed(output_lines):
                    line = line.strip()
                    if line and 'deprecation' not in line.lower():
                        error_message = line
                        break
            
            # Fallback error message
            if not error_message:
                error_message = f'Ansible playbook failed with return code {result.returncode}'
        
        return {
            'success': result.returncode == 0,
            'stdout': stdout_display,
            'stderr': stderr_display,
            'stdout_full': result.stdout or '',
            'stderr_full': result.stderr or '',
            'returncode': result.returncode,
            'error': error_message,  # Add extracted error message
            'prometheus_updated': prometheus_updated,
            'node_info': node_info
        }
    except subprocess.TimeoutExpired:
        app.logger.error("Ansible playbook execution timed out after 10 minutes")
        return {
            'success': False,
            'error': 'Installation timed out after 10 minutes. The process may still be running.',
            'stdout': '',
            'stderr': 'Timeout: Installation took longer than 10 minutes. Please check the target server manually.',
            'returncode': -1,
            'prometheus_updated': False,
            'node_info': None
        }
    except Exception as e:
        # SECURITY: Don't expose internal error details
        app.logger.error(f"Error running Ansible playbook: {str(e)}", exc_info=True)
        return {
            'success': False,
            'error': 'Ansible playbook execution failed. Please check the logs for details.',
            'stdout': '',
            'stderr': '',
            'returncode': -1,
            'prometheus_updated': False,
            'node_info': None
        }
    finally:
        # SECURITY: Clean up temp files containing credentials
        # These files may contain passwords, so they must be securely deleted
        if os.path.exists(extra_vars_file):
            try:
                # Overwrite with zeros before deletion (if possible)
                with open(extra_vars_file, 'wb') as f:
                    f.write(b'\x00' * os.path.getsize(extra_vars_file))
                os.unlink(extra_vars_file)
            except:
                os.unlink(extra_vars_file)
        
        if dynamic_inventory and os.path.exists(dynamic_inventory):
            try:
                # Overwrite with zeros before deletion (if possible)
                with open(dynamic_inventory, 'wb') as f:
                    f.write(b'\x00' * os.path.getsize(dynamic_inventory))
                os.unlink(dynamic_inventory)
            except:
                os.unlink(dynamic_inventory)
        
        if node_info_path and os.path.exists(node_info_path):
            os.unlink(node_info_path)

@app.route('/api/system/check-podman')
def check_podman():
    """Check if Podman is installed"""
    try:
        result = subprocess.run(
            ['podman', '--version'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            return jsonify({
                'installed': True,
                'version': result.stdout.strip()
            })
        else:
            return jsonify({
                'installed': False,
                'version': None
            })
    except:
        return jsonify({
            'installed': False,
            'version': None
        })

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve_react_app(path):
    """
    Serve React application
    SECURITY: Path is validated to prevent path traversal attacks
    Flask's send_from_directory already handles path traversal securely
    """
    # Serve React build files
    static_dir = os.path.join(os.path.dirname(__file__), 'static')
    
    # SECURITY: Basic validation - reject obvious path traversal attempts
    if path:
        # Reject paths with .. (path traversal)
        if '..' in path:
            app.logger.warning(f"Path traversal attempt blocked: {path}")
            return jsonify({'error': 'Invalid path'}), 400
        
        # Use Flask's send_from_directory which securely handles path traversal
        # It automatically prevents access outside the specified directory
        try:
            # Check if file exists before trying to serve
            file_path = os.path.join(static_dir, path)
            if os.path.exists(file_path) and os.path.isfile(file_path):
                # Verify it's actually within static_dir (double-check for security)
                abs_static = os.path.abspath(static_dir)
                abs_file = os.path.abspath(file_path)
                if abs_file.startswith(abs_static):
                    # Flask's send_from_directory is secure - use it directly
                    return send_from_directory(static_dir, path)
        except Exception as e:
            app.logger.debug(f"Could not serve static file {path}: {e}")
            # Fall through to serve index.html for SPA routing
    
    # Otherwise serve index.html for React Router (SPA routing)
    # This handles all non-file routes for client-side routing
    index_path = os.path.join(static_dir, 'index.html')
    if os.path.exists(index_path):
        return send_from_directory(static_dir, 'index.html')
    
    # Fallback to old template if React build doesn't exist
    prometheus_status = check_prometheus_status()
    return render_template('index.html', prometheus_status=prometheus_status)

@app.route('/api/prometheus-status')
@rate_limit
def prometheus_status():
    """Get Prometheus running status"""
    return jsonify(check_prometheus_status())

@app.route('/api/install', methods=['POST'])
@rate_limit
def install():
    """Handle installation request"""
    try:
        data = request.json
        if not data:
            return jsonify({
                'success': False,
                'error': 'Invalid request: JSON data required'
            }), 400
        
        app.logger.info(f"Installation request received for host: {data.get('target_host', 'unknown')}, OS: {data.get('os', 'unknown')}")
        
        # SECURITY: Validate request using security utilities
        is_valid, error_msg = validate_install_request(data)
        if not is_valid:
            app.logger.warning(f"Invalid installation request: {error_msg}")
            return jsonify({
                'success': False,
                'error': error_msg
            }), 400
        
        # Map new field names to backend expected names
        # Support both old and new field names for backward compatibility
        data['port'] = '9100'  # Default port, no configuration needed
        data['os'] = data.get('os', 'auto')
        
        # Also set target_os from os field if provided
        if 'os' in data:
            data['target_os'] = data['os']
        
        # Create Ansible extra vars
        extra_vars = create_ansible_config(data)
        
        # Prepare Prometheus configuration if provided
        prometheus_config = None
        if data.get('prometheus_enabled', False):
            # Auto-detect Prometheus config path if not provided
            prom_status = check_prometheus_status()
            config_path = data.get('prometheus_config_path') or prom_status.get('config_path') or '/etc/prometheus/prometheus.yml'
            reload_api = data.get('prometheus_reload_api') or prom_status.get('reload_api') or 'http://localhost:9090/-/reload'
            
            prometheus_config = {
                'config_path': config_path,
                'reload_api': reload_api
            }
        
        # Run Ansible playbook with error handling
        try:
            app.logger.info(f"Starting Ansible playbook execution for {data.get('target_host', 'unknown')}")
            result = run_ansible_playbook(extra_vars, data.get('inventory', 'hosts.yml'), prometheus_config)
            if result.get('success'):
                app.logger.info(f"Installation successful for {data.get('target_host', 'unknown')}")
            else:
                app.logger.error(f"Installation failed for {data.get('target_host', 'unknown')}: {result.get('error', 'Unknown error')}")
            return jsonify(result)
        except subprocess.TimeoutExpired as e:
            app.logger.error(f"Installation timeout: {str(e)}", exc_info=True)
            return jsonify({
                'success': False,
                'error': 'Installation timed out after 10 minutes',
                'stdout': '',
                'stderr': '',
                'returncode': -1,
                'prometheus_updated': False,
                'node_info': None
            }), 500
        except Exception as e:
            # SECURITY: Don't expose internal error details to client
            app.logger.error(f"Installation failed: {str(e)}", exc_info=True)
            return jsonify({
                'success': False,
                'error': 'Installation failed. Please check the logs for details.',
                'stdout': '',
                'stderr': '',
                'returncode': -1,
                'prometheus_updated': False,
                'node_info': None
            }), 500
    
    except Exception as e:
        # SECURITY: Don't expose internal error details to client
        app.logger.error(f"Error processing installation request: {str(e)}", exc_info=True)
        return jsonify({
            'success': False,
            'error': 'Invalid request. Please check your input and try again.'
        }), 500

@app.route('/api/validate', methods=['POST'])
@rate_limit
def validate():
    """Validate configuration without running installation"""
    try:
        data = request.json
        if not data:
            return jsonify({
                'valid': False,
                'error': 'Invalid request: JSON data required'
            }), 400
        
        # SECURITY: Use security utilities for validation
        is_valid, error_msg = validate_install_request(data)
        
        if not is_valid:
            return jsonify({
                'valid': False,
                'errors': [error_msg]
            }), 400
        
        return jsonify({
            'valid': True,
            'message': 'Configuration is valid'
        })
    
    except Exception as e:
        # SECURITY: Don't expose internal error details
        app.logger.error(f"Validation error: {str(e)}", exc_info=True)
        return jsonify({
            'valid': False,
            'error': 'Validation failed. Please check your input.'
        }), 500

@app.route('/api/generate-hash', methods=['POST'])
@rate_limit
def generate_hash():
    """Generate password hash"""
    try:
        data = request.json
        password = data.get('password')
        
        if not password:
            return jsonify({
                'success': False,
                'error': 'Password is required'
            }), 400
        
        hashed = generate_password_hash(password)
        
        return jsonify({
            'success': True,
            'hash': hashed
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# Server persistence API endpoints
@app.route('/api/servers', methods=['GET'])
@rate_limit
def get_servers():
    """Get all monitored servers"""
    try:
        db = get_database()
        servers = db.get_all_servers()
        if DEBUG_MODE:
            app.logger.debug(f"Retrieved {len(servers)} servers from database")
        return jsonify({
            'success': True,
            'servers': servers
        })
    except Exception as e:
        app.logger.error(f"Error retrieving servers from database: {str(e)}", exc_info=True)
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/servers', methods=['POST'])
@rate_limit
def add_server():
    """
    Add a new server
    
    SECURITY: Passwords are NEVER stored. This endpoint explicitly filters out
    any password-related fields before saving to the database.
    """
    try:
        data = request.json
        if not data:
            return jsonify({
                'success': False,
                'error': 'Invalid request: JSON data required'
            }), 400
        
        app.logger.info(f"Adding server to database: {data.get('name', 'unknown')} ({data.get('ip', 'unknown')})")
        
        # SECURITY: Validate and sanitize input data
        # Validate required fields
        required_fields = ['id', 'name', 'ip', 'port', 'os']
        for field in required_fields:
            if field not in data:
                app.logger.warning(f"Missing required field when adding server: {field}")
                return jsonify({
                    'success': False,
                    'error': f'Missing required field: {field}'
                }), 400
        
        # SECURITY: Sanitize server ID
        sanitized_id = sanitize_server_id(data.get('id', ''))
        if not sanitized_id:
            return jsonify({
                'success': False,
                'error': 'Invalid server ID format'
            }), 400
        data['id'] = sanitized_id
        
        # SECURITY: Sanitize server name
        sanitized_name = sanitize_server_name(data.get('name', ''))
        if not sanitized_name:
            return jsonify({
                'success': False,
                'error': 'Invalid server name format'
            }), 400
        data['name'] = sanitized_name
        
        # SECURITY: Validate IP address or hostname
        ip_value = data.get('ip', '')
        if not validate_ip_address(ip_value):
            sanitized_ip = sanitize_hostname(ip_value)
            if not sanitized_ip:
                return jsonify({
                    'success': False,
                    'error': 'Invalid IP address or hostname format'
                }), 400
            data['ip'] = sanitized_ip
        
        # SECURITY: Validate port
        try:
            port = int(data.get('port', 0))
            if not validate_port(port):
                return jsonify({
                    'success': False,
                    'error': 'Invalid port number (must be 1-65535)'
                }), 400
            data['port'] = port
        except (ValueError, TypeError):
            return jsonify({
                'success': False,
                'error': 'Invalid port format'
            }), 400
        
        # SECURITY: Remove any password fields before processing
        # Passwords should only be used during installation, never stored
        data = {k: v for k, v in data.items() 
                if not any(pwd_key in k.lower() for pwd_key in ['password', 'passwd', 'pwd', 'secret', 'credential'])}
        
        db = get_database()
        server = db.add_server(data)
        app.logger.info(f"Server added successfully: {server.get('name')} (ID: {server.get('id')})")
        
        return jsonify({
            'success': True,
            'server': server
        })
    except Exception as e:
        # SECURITY: Don't expose internal error details
        app.logger.error(f"Error adding server to database: {str(e)}", exc_info=True)
        return jsonify({
            'success': False,
            'error': 'Failed to add server'
        }), 500

@app.route('/api/servers/<server_id>', methods=['GET'])
@rate_limit
def get_server(server_id):
    """Get a specific server by ID"""
    try:
        # SECURITY: Validate and sanitize server_id
        sanitized_id = sanitize_server_id(server_id)
        if not sanitized_id:
            app.logger.warning(f"Invalid server_id format: {server_id}")
            return jsonify({
                'success': False,
                'error': 'Invalid server ID format'
            }), 400
        
        db = get_database()
        server = db.get_server(sanitized_id)
        
        if not server:
            return jsonify({
                'success': False,
                'error': 'Server not found'
            }), 404
        
        return jsonify({
            'success': True,
            'server': server
        })
    except Exception as e:
        # SECURITY: Don't expose internal error details
        app.logger.error(f"Error retrieving server: {str(e)}", exc_info=True)
        return jsonify({
            'success': False,
            'error': 'Failed to retrieve server information'
        }), 500

@app.route('/api/servers/<server_id>', methods=['PUT'])
@rate_limit
def update_server(server_id):
    """
    Update a server
    
    SECURITY: Passwords are NEVER stored. This endpoint explicitly filters out
    any password-related fields before updating the database.
    """
    try:
        # SECURITY: Validate and sanitize server_id
        sanitized_id = sanitize_server_id(server_id)
        if not sanitized_id:
            app.logger.warning(f"Invalid server_id format: {server_id}")
            return jsonify({
                'success': False,
                'error': 'Invalid server ID format'
            }), 400
        
        data = request.json
        if not data:
            return jsonify({
                'success': False,
                'error': 'Invalid request: JSON data required'
            }), 400
        
        app.logger.info(f"Updating server: {sanitized_id}")
        
        # SECURITY: Validate and sanitize input data
        if 'name' in data:
            sanitized_name = sanitize_server_name(data['name'])
            if not sanitized_name:
                return jsonify({
                    'success': False,
                    'error': 'Invalid server name format'
                }), 400
            data['name'] = sanitized_name
        
        if 'ip' in data:
            if not validate_ip_address(data['ip']):
                sanitized_ip = sanitize_hostname(data['ip'])
                if not sanitized_ip:
                    return jsonify({
                        'success': False,
                        'error': 'Invalid IP address or hostname format'
                    }), 400
                data['ip'] = sanitized_ip
        
        if 'port' in data:
            try:
                port = int(data['port'])
                if not validate_port(port):
                    return jsonify({
                        'success': False,
                        'error': 'Invalid port number (must be 1-65535)'
                    }), 400
                data['port'] = port
            except (ValueError, TypeError):
                return jsonify({
                    'success': False,
                    'error': 'Invalid port format'
                }), 400
        
        # SECURITY: Remove any password fields before processing
        # Passwords should only be used during installation, never stored
        data = {k: v for k, v in data.items() 
                if not any(pwd_key in k.lower() for pwd_key in ['password', 'passwd', 'pwd', 'secret', 'credential'])}
        
        db = get_database()
        
        # Check if server exists
        if not db.server_exists(sanitized_id):
            app.logger.warning(f"Update requested for non-existent server: {sanitized_id}")
            return jsonify({
                'success': False,
                'error': 'Server not found'
            }), 404
        
        server = db.update_server(sanitized_id, data)
        app.logger.info(f"Server updated successfully: {sanitized_id}")
        
        return jsonify({
            'success': True,
            'server': server
        })
    except Exception as e:
        # SECURITY: Don't expose internal error details
        app.logger.error(f"Error updating server {server_id}: {str(e)}", exc_info=True)
        return jsonify({
            'success': False,
            'error': 'Failed to update server'
        }), 500

@app.route('/api/servers/<server_id>', methods=['DELETE'])
@rate_limit
def delete_server(server_id):
    """Delete a server"""
    try:
        # SECURITY: Validate and sanitize server_id
        sanitized_id = sanitize_server_id(server_id)
        if not sanitized_id:
            app.logger.warning(f"Invalid server_id format: {server_id}")
            return jsonify({
                'success': False,
                'error': 'Invalid server ID format'
            }), 400
        
        app.logger.info(f"Delete request for server: {sanitized_id}")
        db = get_database()
        deleted = db.delete_server(sanitized_id)
        
        if not deleted:
            app.logger.warning(f"Delete requested for non-existent server: {sanitized_id}")
            return jsonify({
                'success': False,
                'error': 'Server not found'
            }), 404
        
        app.logger.info(f"Server deleted successfully: {sanitized_id}")
        return jsonify({
            'success': True,
            'message': 'Server deleted successfully'
        })
    except Exception as e:
        # SECURITY: Don't expose internal error details
        app.logger.error(f"Error deleting server {server_id}: {str(e)}", exc_info=True)
        return jsonify({
            'success': False,
            'error': 'Failed to delete server'
        }), 500

if __name__ == '__main__':
    app.logger.info("Starting Node Exporter Installation Web UI...")
    app.logger.info("Access the application at http://localhost:5000")
    app.logger.info(f"Logging to: {LOG_FILE}")
    app.logger.info(f"Debug mode: {'ENABLED' if DEBUG_MODE else 'DISABLED'}")
    print("Starting Node Exporter Installation Web UI...")
    print(f"Access the application at http://localhost:5000")
    print(f"Log file: {LOG_FILE}")
    print(f"Debug mode: {'ENABLED' if DEBUG_MODE else 'DISABLED'}")
    print(f"Log level: {'DEBUG (all logs)' if DEBUG_MODE else 'INFO (INFO, WARNING, ERROR only)'}")
    app.run(host='0.0.0.0', port=5000, debug=DEBUG_MODE)
