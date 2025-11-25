#!/usr/bin/env python3
"""
Prometheus Configuration Manager
Manages Prometheus scrape configuration and reloads Prometheus after updates
"""

import os
import json
import yaml
import shutil
from datetime import datetime
from typing import Dict, List, Optional

class PrometheusConfigManager:
    """Manage Prometheus configuration files"""
    
    def __init__(self, prometheus_config_path: str = '/etc/prometheus/prometheus.yml',
                 prometheus_reload_api: Optional[str] = None):
        """
        Initialize Prometheus Config Manager
        
        Args:
            prometheus_config_path: Path to prometheus.yml
            prometheus_reload_api: Prometheus reload API URL (e.g., http://localhost:9090/-/reload)
        """
        self.config_path = prometheus_config_path
        self.reload_api = prometheus_reload_api
        
        # Create backup directory in the same directory as config file
        config_dir = os.path.dirname(os.path.abspath(prometheus_config_path))
        self.backup_dir = os.path.join(config_dir, 'backups')
        os.makedirs(self.backup_dir, exist_ok=True)
        
        # If config file doesn't exist, create directory
        config_dir = os.path.dirname(self.config_path)
        if config_dir and not os.path.exists(config_dir):
            os.makedirs(config_dir, exist_ok=True)
    
    def load_config(self) -> Dict:
        """Load Prometheus configuration from file"""
        if not os.path.exists(self.config_path):
            # Create default configuration
            return {
                'global': {
                    'scrape_interval': '15s',
                    'evaluation_interval': '15s'
                },
                'scrape_configs': []
            }
        
        with open(self.config_path, 'r') as f:
            return yaml.safe_load(f) or {}
    
    def save_config(self, config: Dict) -> bool:
        """Save Prometheus configuration to file with backup"""
        try:
            # Create backup
            if os.path.exists(self.config_path):
                backup_path = os.path.join(
                    self.backup_dir,
                    f"prometheus.yml.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
                )
                shutil.copy2(self.config_path, backup_path)
            
            # Save new configuration
            with open(self.config_path, 'w') as f:
                yaml.dump(config, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
            
            return True
        except Exception as e:
            print(f"Error saving config: {e}")
            return False
    
    def add_scrape_target(self, node_info: Dict) -> bool:
        """
        Add a new scrape target to Prometheus configuration
        
        Args:
            node_info: Dictionary containing node information
                - hostname: Hostname of the node
                - ip_address: IP address of the node
                - port: Port where node-exporter is running
                - username: Basic auth username
                - password: Basic auth password
                - instance_label: Label for the instance
                - scheme: http or https
                - job_name: Job name (default: node-exporter)
        """
        config = self.load_config()
        
        # Ensure scrape_configs exists
        if 'scrape_configs' not in config:
            config['scrape_configs'] = []
        
        job_name = node_info.get('job_name', 'node-exporter')
        scheme = node_info.get('scheme', 'https')
        port = node_info.get('port', '9100')
        hostname = node_info.get('hostname', 'localhost')
        ip_address = node_info.get('ip_address', '127.0.0.1')
        instance_label = node_info.get('instance_label', f"{hostname}:{port}")
        username = node_info.get('username', '')
        password = node_info.get('password', '')
        
        # Check if job already exists
        job_exists = False
        for job in config['scrape_configs']:
            if job.get('job_name') == job_name:
                job_exists = True
                # Check if target already exists
                targets = job.get('static_configs', [{}])[0].get('targets', [])
                target = f"{ip_address}:{port}"
                if target not in targets:
                    targets.append(target)
                    job['static_configs'][0]['targets'] = targets
                break
        
        # Create new job if it doesn't exist
        if not job_exists:
            scrape_config = {
                'job_name': job_name,
                'scheme': scheme,
                'static_configs': [{
                    'targets': [f"{ip_address}:{port}"],
                    'labels': {
                        'instance': instance_label,
                        'hostname': hostname,
                        'os': node_info.get('os', 'unknown')
                    }
                }]
            }
            
            # Note: TLS and Basic Auth configuration removed for simplicity
            # If needed, configure Prometheus scrape_config manually with security settings
            
            config['scrape_configs'].append(scrape_config)
        
        # Save configuration
        return self.save_config(config)
    
    def remove_scrape_target(self, ip_address: str, port: str = '9100', job_name: str = 'node-exporter') -> bool:
        """Remove a scrape target from Prometheus configuration"""
        config = self.load_config()
        
        if 'scrape_configs' not in config:
            return False
        
        target = f"{ip_address}:{port}"
        updated = False
        
        for job in config['scrape_configs']:
            if job.get('job_name') == job_name:
                for static_config in job.get('static_configs', []):
                    targets = static_config.get('targets', [])
                    if target in targets:
                        targets.remove(target)
                        updated = True
                        # Remove job if no targets left
                        if not targets:
                            config['scrape_configs'].remove(job)
                        break
        
        if updated:
            return self.save_config(config)
        
        return False
    
    def list_scrape_targets(self) -> List[Dict]:
        """List all scrape targets"""
        config = self.load_config()
        targets = []
        
        for job in config.get('scrape_configs', []):
            for static_config in job.get('static_configs', []):
                for target in static_config.get('targets', []):
                    targets.append({
                        'job_name': job.get('job_name', 'unknown'),
                        'target': target,
                        'labels': static_config.get('labels', {}),
                        'scheme': job.get('scheme', 'http')
                    })
        
        return targets
    
    def reload_prometheus(self) -> bool:
        """Reload Prometheus configuration via API"""
        if not self.reload_api:
            return False
        
        import requests
        try:
            response = requests.post(self.reload_api, timeout=5)
            return response.status_code == 200
        except Exception as e:
            print(f"Error reloading Prometheus: {e}")
            return False
    
    def get_config_path(self) -> str:
        """Get the Prometheus configuration file path"""
        return self.config_path

