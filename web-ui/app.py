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
from flask import Flask, render_template, request, jsonify, send_from_directory
from werkzeug.utils import secure_filename
import bcrypt
import yaml

# Add parent directory (Monitoring) to path for prometheus_manager import
monitoring_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, monitoring_dir)
from prometheus.prometheus_manager import PrometheusConfigManager

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['SECRET_KEY'] = os.urandom(24)

# Ensure upload and certs directories exist
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs('certs', exist_ok=True)

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
    extra_vars = {
        'target_os': config_data.get('os', 'linux'),
        'node_exporter_port': '9100',  # Default port, no config needed
    }
    
    # Add target server info if provided (for dynamic inventory)
    if config_data.get('target_host'):
        extra_vars['target_host'] = config_data.get('target_host')
        extra_vars['target_username'] = config_data.get('target_username', '')
        extra_vars['target_password'] = config_data.get('target_password', '')
    
    return extra_vars

def create_dynamic_inventory(target_host, target_username, target_password, os_type, monitoring_dir):
    """Create a temporary inventory file for a single host"""
    import tempfile
    
    # Determine connection type based on OS (normalize to lowercase)
    os_type = os_type.lower() if os_type else 'linux'
    
    if os_type == 'windows':
        # Windows uses WinRM on port 5985 (HTTP) or 5986 (HTTPS)
        # Use port 5985 for basic auth (simpler setup)
        # Extended timeouts for WinRM operations
        inventory_content = f"""[windows]
{target_host} ansible_host={target_host} ansible_user={target_username} ansible_password={target_password} ansible_connection=winrm ansible_port=5985 ansible_winrm_transport=basic ansible_winrm_server_cert_validation=ignore ansible_become=false ansible_winrm_read_timeout_sec=60 ansible_winrm_operation_timeout_sec=60 ansible_winrm_connection_timeout=30
"""
    else:  # linux or auto (default to linux)
        inventory_content = f"""[linux]
{target_host} ansible_host={target_host} ansible_user={target_username} ansible_password={target_password} ansible_become=true ansible_become_pass={target_password} ansible_ssh_common_args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
"""
    
    # Create temporary inventory file
    temp_inventory = tempfile.NamedTemporaryFile(mode='w', suffix='.yml', delete=False, dir=monitoring_dir)
    temp_inventory.write(inventory_content)
    temp_inventory.close()
    
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
    
    # Create temporary file for extra vars
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump(extra_vars, f)
        extra_vars_file = f.name
    
    node_info_path = None
    try:
        # Create ansible config with aggressive timeouts to prevent hanging
        ansible_cfg_content = """[defaults]
host_key_checking = False
timeout = 10
retry_files_enabled = False
forks = 1
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
        
        # Add SSH args for Linux connections
        if extra_vars.get('os', 'linux') != 'windows':
            cmd.extend([
                '--ssh-common-args=-o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2'
            ])
        
        # Run with timeout - much shorter now
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=monitoring_dir,
            timeout=600,  # 10 minutes max (should be much faster with timeouts)
            env={**os.environ, 'ANSIBLE_CONFIG': ansible_cfg_path}
        )
        
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
                    with open(path, 'r') as f:
                        node_info = json.load(f)
                    break
            
            # Update Prometheus if node info found
            if node_info:
                try:
                    prom_manager = PrometheusConfigManager(
                        prometheus_config_path=prometheus_config.get('config_path', '/etc/prometheus/prometheus.yml'),
                        prometheus_reload_api=prometheus_config.get('reload_api')
                    )
                    
                    if prom_manager.add_scrape_target(node_info):
                        prometheus_updated = True
                        # Reload Prometheus if API is configured
                        if prometheus_config.get('reload_api'):
                            prom_manager.reload_prometheus()
                except Exception as e:
                    print(f"Error updating Prometheus: {e}")
        
        # Get the last few lines of output for better error display
        stdout_lines = result.stdout.split('\n') if result.stdout else []
        stderr_lines = result.stderr.split('\n') if result.stderr else []
        
        # Extract last 50 lines for display
        stdout_display = '\n'.join(stdout_lines[-50:]) if len(stdout_lines) > 50 else result.stdout or ''
        stderr_display = '\n'.join(stderr_lines[-50:]) if len(stderr_lines) > 50 else result.stderr or ''
        
        return {
            'success': result.returncode == 0,
            'stdout': stdout_display,
            'stderr': stderr_display,
            'stdout_full': result.stdout or '',
            'stderr_full': result.stderr or '',
            'returncode': result.returncode,
            'prometheus_updated': prometheus_updated,
            'node_info': node_info
        }
    except subprocess.TimeoutExpired:
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
        return {
            'success': False,
            'error': f'Error running Ansible playbook: {str(e)}',
            'stdout': '',
            'stderr': str(e),
            'returncode': -1,
            'prometheus_updated': False,
            'node_info': None
        }
    finally:
        # Clean up temp files
        if os.path.exists(extra_vars_file):
            os.unlink(extra_vars_file)
        if dynamic_inventory and os.path.exists(dynamic_inventory):
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
    """Serve React application"""
    # Serve React build files
    static_dir = os.path.join(os.path.dirname(__file__), 'static')
    
    # If requesting a file that exists in static, serve it
    if path and os.path.exists(os.path.join(static_dir, path)):
        return send_from_directory(static_dir, path)
    
    # Otherwise serve index.html for React Router
    index_path = os.path.join(static_dir, 'index.html')
    if os.path.exists(index_path):
        return send_from_directory(static_dir, 'index.html')
    
    # Fallback to old template if React build doesn't exist
    prometheus_status = check_prometheus_status()
    return render_template('index.html', prometheus_status=prometheus_status)

@app.route('/api/prometheus-status')
def prometheus_status():
    """Get Prometheus running status"""
    return jsonify(check_prometheus_status())

@app.route('/api/install', methods=['POST'])
def install():
    """Handle installation request"""
    try:
        data = request.json
        
        # Map new field names to backend expected names
        # Support both old and new field names for backward compatibility
        data['port'] = '9100'  # Default port, no configuration needed
        data['os'] = data.get('os', 'auto')
        
        # Also set target_os from os field if provided
        if 'os' in data:
            data['target_os'] = data['os']
        
        # Validate required fields - only need OS now
        required_fields = ['os']
        for field in required_fields:
            if field not in data or not data[field]:
                return jsonify({
                    'success': False,
                    'error': f'Missing required field: {field}'
                }), 400
        
        # Validate target server credentials if provided
        if data.get('target_host'):
            if not data.get('target_username') or not data.get('target_password'):
                return jsonify({
                    'success': False,
                    'error': 'Target server username and password are required when target host is provided'
                }), 400
        
        # Validate OS
        if data['os'] not in ['linux', 'windows', 'auto']:
            return jsonify({
                'success': False,
                'error': 'Invalid OS. Must be "linux", "windows", or "auto"'
            }), 400
        
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
            result = run_ansible_playbook(extra_vars, data.get('inventory', 'hosts.yml'), prometheus_config)
            return jsonify(result)
        except subprocess.TimeoutExpired as e:
            return jsonify({
                'success': False,
                'error': 'Installation timed out after 10 minutes',
                'stdout': '',
                'stderr': str(e),
                'returncode': -1,
                'prometheus_updated': False,
                'node_info': None
            }), 500
        except Exception as e:
            return jsonify({
                'success': False,
                'error': f'Failed to run installation: {str(e)}',
                'stdout': '',
                'stderr': str(e),
                'returncode': -1,
                'prometheus_updated': False,
                'node_info': None
            }), 500
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/validate', methods=['POST'])
def validate():
    """Validate configuration without running installation"""
    try:
        data = request.json
        
        # Validate required fields - only need OS now
        required_fields = ['os']
        for field in required_fields:
            if field not in data:
                return jsonify({
                    'valid': False,
                    'error': f'Missing required field: {field}'
                }), 400
        
        # Validate values
        validation_errors = []
        
        if data['os'] not in ['linux', 'windows', 'auto']:
            validation_errors.append('Invalid OS. Must be "linux", "windows", or "auto"')
        
        # Validate target server credentials if provided
        if data.get('target_host'):
            if not data.get('target_username') or not data.get('target_password'):
                validation_errors.append('Target server username and password are required when target host is provided')
        
        if validation_errors:
            return jsonify({
                'valid': False,
                'errors': validation_errors
            }), 400
        
        return jsonify({
            'valid': True,
            'message': 'Configuration is valid'
        })
    
    except Exception as e:
        return jsonify({
            'valid': False,
            'error': str(e)
        }), 500

@app.route('/api/generate-hash', methods=['POST'])
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

if __name__ == '__main__':
    print("Starting Node Exporter Installation Web UI...")
    print("Access the application at http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=True)
