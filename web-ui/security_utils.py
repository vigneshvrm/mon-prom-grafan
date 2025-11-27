#!/usr/bin/env python3
"""
Security Utilities Module
Provides input validation, sanitization, and security helpers
"""

import re
import ipaddress
from typing import Optional, Tuple
from urllib.parse import quote


def validate_ip_address(ip: str) -> bool:
    """
    Validate IP address format (IPv4 or IPv6)
    
    Args:
        ip: IP address string to validate
        
    Returns:
        True if valid IP address, False otherwise
    """
    try:
        ipaddress.ip_address(ip)
        return True
    except ValueError:
        return False


def validate_port(port: int) -> bool:
    """
    Validate port number is in valid range
    
    Args:
        port: Port number to validate
        
    Returns:
        True if port is in range 1-65535, False otherwise
    """
    return isinstance(port, int) and 1 <= port <= 65535


def sanitize_hostname(hostname: str) -> Optional[str]:
    """
    Sanitize hostname to prevent command injection
    Only allows alphanumeric, dots, hyphens, and underscores
    
    Args:
        hostname: Hostname to sanitize
        
    Returns:
        Sanitized hostname or None if invalid
    """
    if not hostname or not isinstance(hostname, str):
        return None
    
    # Remove any whitespace
    hostname = hostname.strip()
    
    # Check if it's a valid IP address
    if validate_ip_address(hostname):
        return hostname
    
    # For hostnames, allow only alphanumeric, dots, hyphens, underscores
    # Max length 253 characters (RFC 1123)
    if len(hostname) > 253:
        return None
    
    # Pattern: alphanumeric, dots, hyphens, underscores
    # Must start and end with alphanumeric
    pattern = r'^[a-zA-Z0-9]([a-zA-Z0-9\-_\.]*[a-zA-Z0-9])?$'
    if re.match(pattern, hostname):
        return hostname
    
    return None


def sanitize_username(username: str) -> Optional[str]:
    """
    Sanitize username to prevent command injection
    Allows alphanumeric, dots, hyphens, underscores, @ symbol
    
    Args:
        username: Username to sanitize
        
    Returns:
        Sanitized username or None if invalid
    """
    if not username or not isinstance(username, str):
        return None
    
    username = username.strip()
    
    # Max length 255 characters
    if len(username) > 255 or len(username) == 0:
        return None
    
    # Allow alphanumeric, dots, hyphens, underscores, @
    # Must start with alphanumeric or @
    pattern = r'^[a-zA-Z0-9@]([a-zA-Z0-9\-_\.@]*[a-zA-Z0-9])?$'
    if re.match(pattern, username):
        return username
    
    return None


def sanitize_server_name(name: str) -> Optional[str]:
    """
    Sanitize server name to prevent injection
    Allows alphanumeric, spaces, dots, hyphens, underscores
    
    Args:
        name: Server name to sanitize
        
    Returns:
        Sanitized name or None if invalid
    """
    if not name or not isinstance(name, str):
        return None
    
    name = name.strip()
    
    # Max length 100 characters
    if len(name) > 100 or len(name) == 0:
        return None
    
    # Allow alphanumeric, spaces, dots, hyphens, underscores
    pattern = r'^[a-zA-Z0-9]([a-zA-Z0-9\s\-_\.]*[a-zA-Z0-9])?$'
    if re.match(pattern, name):
        return name
    
    return None


def sanitize_server_id(server_id: str) -> Optional[str]:
    """
    Sanitize server ID to prevent path traversal and injection
    Allows alphanumeric, hyphens, underscores
    
    Args:
        server_id: Server ID to sanitize
        
    Returns:
        Sanitized ID or None if invalid
    """
    if not server_id or not isinstance(server_id, str):
        return None
    
    server_id = server_id.strip()
    
    # Max length 100 characters
    if len(server_id) > 100 or len(server_id) == 0:
        return None
    
    # Only alphanumeric, hyphens, underscores
    pattern = r'^[a-zA-Z0-9]([a-zA-Z0-9\-_]*[a-zA-Z0-9])?$'
    if re.match(pattern, server_id):
        return server_id
    
    return None


def sanitize_path(path: str, base_dir: str) -> Optional[str]:
    """
    Sanitize file path to prevent path traversal
    Ensures path is within base_dir
    
    Args:
        path: Path to sanitize
        base_dir: Base directory that path must be within
        
    Returns:
        Sanitized absolute path or None if invalid
    """
    import os
    
    if not path or not isinstance(path, str):
        return None
    
    # Remove any null bytes
    path = path.replace('\x00', '')
    
    # Remove leading/trailing whitespace
    path = path.strip()
    
    # Normalize path separators (handle both / and \)
    path = path.replace('\\', '/')
    
    # Remove leading slashes to make it relative
    path = path.lstrip('/')
    
    # Check for path traversal attempts - reject if contains ..
    if '..' in path:
        return None
    
    # Resolve to absolute path
    abs_base = os.path.abspath(base_dir)
    abs_path = os.path.abspath(os.path.join(base_dir, path))
    
    # Ensure the resolved path is within base_dir
    # Use os.path.commonpath for better cross-platform support
    try:
        common_path = os.path.commonpath([abs_base, abs_path])
        if common_path != abs_base:
            return None
    except ValueError:
        # Paths on different drives (Windows) or invalid
        return None
    
    return abs_path


def escape_ansible_value(value: str) -> str:
    """
    Escape special characters for Ansible inventory values
    Prevents command injection in Ansible inventory files
    
    Args:
        value: Value to escape
        
    Returns:
        Escaped value safe for Ansible inventory
    """
    if not isinstance(value, str):
        value = str(value)
    
    # Replace special characters that could be used for injection
    # Ansible uses these characters: =, :, [, ], space, newline
    # We'll quote the value if it contains special characters
    special_chars = ['=', ':', '[', ']', ' ', '\n', '\r', '\t', '"', "'", '\\']
    
    if any(char in value for char in special_chars):
        # Escape backslashes and quotes, then wrap in quotes
        escaped = value.replace('\\', '\\\\').replace('"', '\\"')
        return f'"{escaped}"'
    
    return value


def validate_install_request(data: dict) -> Tuple[bool, Optional[str]]:
    """
    Validate installation request data
    
    Args:
        data: Request data dictionary
        
    Returns:
        Tuple of (is_valid, error_message)
    """
    # Validate OS
    if 'os' not in data:
        return False, 'Missing required field: os'
    
    os_value = data.get('os', '').lower()
    if os_value not in ['linux', 'windows', 'auto']:
        return False, 'Invalid OS. Must be "linux", "windows", or "auto"'
    
    # If target_host is provided, validate it
    if data.get('target_host'):
        target_host = data.get('target_host', '').strip()
        if not target_host:
            return False, 'target_host cannot be empty'
        
        # Validate hostname or IP
        sanitized_host = sanitize_hostname(target_host)
        if not sanitized_host:
            return False, 'Invalid target_host format'
        
        # Validate credentials if host is provided
        if not data.get('target_username') or not data.get('target_password'):
            return False, 'Target server username and password are required when target host is provided'
        
        # Validate username
        sanitized_user = sanitize_username(data.get('target_username', ''))
        if not sanitized_user:
            return False, 'Invalid username format'
    
    return True, None

