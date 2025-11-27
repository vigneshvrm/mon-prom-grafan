#!/usr/bin/env python3
"""
SQLite database module for persistent server storage
"""

import sqlite3
import json
import os
import logging
from typing import List, Dict, Optional
from datetime import datetime

# Set up logger for database operations
logger = logging.getLogger(__name__)

class ServerDatabase:
    """File-based SQLite database for storing monitored servers"""
    
    def __init__(self, db_path: str = 'servers.db'):
        """
        Initialize database connection
        
        Args:
            db_path: Path to SQLite database file (relative to web-ui directory)
        """
        # Get absolute path relative to this file's directory
        base_dir = os.path.dirname(os.path.abspath(__file__))
        self.db_path = os.path.join(base_dir, db_path)
        self._init_database()
    
    def _init_database(self):
        """Initialize database schema"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Create servers table
        # SECURITY NOTE: This table does NOT store passwords or credentials.
        # Passwords are only used during installation and are never persisted.
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS servers (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                ip TEXT NOT NULL,
                port INTEGER NOT NULL,
                os TEXT NOT NULL,
                ssh_user TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'PENDING',
                metrics TEXT,  -- JSON string
                ansible_playbook TEXT,
                prometheus_config TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Create index on IP for faster lookups
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_servers_ip ON servers(ip)
        ''')
        
        conn.commit()
        conn.close()
    
    def _get_connection(self):
        """Get database connection"""
        return sqlite3.connect(self.db_path)
    
    def add_server(self, server: Dict) -> Dict:
        """
        Add a new server to the database
        
        SECURITY NOTE: Passwords are NEVER stored. This method explicitly filters out
        any password-related fields to ensure credentials are not persisted.
        
        Args:
            server: Server dictionary with id, name, ip, port, os, sshUser, status, metrics
                   NOTE: password fields are automatically filtered out
        
        Returns:
            Server dictionary with created_at and updated_at
        """
        # SECURITY: Explicitly remove any password fields to prevent accidental storage
        server = {k: v for k, v in server.items() 
                  if not any(pwd_key in k.lower() for pwd_key in ['password', 'passwd', 'pwd', 'secret', 'credential'])}
        
        logger.info(f"Adding server to database: {server.get('name', 'unknown')} ({server.get('ip', 'unknown')})")
        
        conn = self._get_connection()
        cursor = conn.cursor()
        
        # Convert metrics to JSON string
        metrics_json = json.dumps(server.get('metrics', {
            'cpu': [],
            'memory': [],
            'timestamps': []
        }))
        
        cursor.execute('''
            INSERT OR REPLACE INTO servers 
            (id, name, ip, port, os, ssh_user, status, metrics, ansible_playbook, prometheus_config, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        ''', (
            server['id'],
            server['name'],
            server['ip'],
            server['port'],
            server['os'],
            server.get('sshUser', ''),
            server.get('status', 'PENDING'),
            metrics_json,
            server.get('ansiblePlaybook'),
            server.get('prometheusConfig')
        ))
        
        conn.commit()
        
        # Fetch the created server
        result = self.get_server(server['id'])
        conn.close()
        logger.info(f"Server added successfully: {result.get('name')} (ID: {result.get('id')})")
        return result
    
    def get_server(self, server_id: str) -> Optional[Dict]:
        """
        Get a server by ID
        
        Args:
            server_id: Server ID
        
        Returns:
            Server dictionary or None if not found
        """
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT id, name, ip, port, os, ssh_user, status, metrics, 
                   ansible_playbook, prometheus_config, created_at, updated_at
            FROM servers
            WHERE id = ?
        ''', (server_id,))
        
        row = cursor.fetchone()
        conn.close()
        
        if not row:
            return None
        
        # Convert row to dictionary
        metrics = json.loads(row[7]) if row[7] else {'cpu': [], 'memory': [], 'timestamps': []}
        
        return {
            'id': row[0],
            'name': row[1],
            'ip': row[2],
            'port': row[3],
            'os': row[4],
            'sshUser': row[5],
            'status': row[6],
            'metrics': metrics,
            'ansiblePlaybook': row[8],
            'prometheusConfig': row[9],
            'createdAt': row[10],
            'updatedAt': row[11]
        }
    
    def get_all_servers(self) -> List[Dict]:
        """
        Get all servers
        
        Returns:
            List of server dictionaries
        """
        logger.debug("Retrieving all servers from database")
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT id, name, ip, port, os, ssh_user, status, metrics, 
                   ansible_playbook, prometheus_config, created_at, updated_at
            FROM servers
            ORDER BY created_at DESC
        ''')
        
        rows = cursor.fetchall()
        conn.close()
        
        logger.debug(f"Retrieved {len(rows)} servers from database")
        servers = []
        for row in rows:
            metrics = json.loads(row[7]) if row[7] else {'cpu': [], 'memory': [], 'timestamps': []}
            servers.append({
                'id': row[0],
                'name': row[1],
                'ip': row[2],
                'port': row[3],
                'os': row[4],
                'sshUser': row[5],
                'status': row[6],
                'metrics': metrics,
                'ansiblePlaybook': row[8],
                'prometheusConfig': row[9],
                'createdAt': row[10],
                'updatedAt': row[11]
            })
        
        return servers
    
    def update_server(self, server_id: str, updates: Dict) -> Optional[Dict]:
        """
        Update a server
        
        SECURITY NOTE: Passwords are NEVER stored. This method explicitly filters out
        any password-related fields to ensure credentials are not persisted.
        
        Args:
            server_id: Server ID
            updates: Dictionary with fields to update
                    NOTE: password fields are automatically filtered out
        
        Returns:
            Updated server dictionary or None if not found
        """
        # SECURITY: Explicitly remove any password fields to prevent accidental storage
        updates = {k: v for k, v in updates.items() 
                  if not any(pwd_key in k.lower() for pwd_key in ['password', 'passwd', 'pwd', 'secret', 'credential'])}
        
        conn = self._get_connection()
        cursor = conn.cursor()
        
        # Build update query dynamically
        update_fields = []
        values = []
        
        allowed_fields = ['name', 'ip', 'port', 'os', 'ssh_user', 'status', 
                         'metrics', 'ansible_playbook', 'prometheus_config']
        
        for key, value in updates.items():
            db_key = key if key in allowed_fields else None
            if db_key:
                if db_key == 'metrics' and isinstance(value, dict):
                    value = json.dumps(value)
                elif db_key == 'sshUser':
                    db_key = 'ssh_user'
                elif db_key == 'ansiblePlaybook':
                    db_key = 'ansible_playbook'
                elif db_key == 'prometheusConfig':
                    db_key = 'prometheus_config'
                
                update_fields.append(f"{db_key} = ?")
                values.append(value)
        
        if not update_fields:
            conn.close()
            return self.get_server(server_id)
        
        # Add updated_at
        update_fields.append("updated_at = CURRENT_TIMESTAMP")
        values.append(server_id)
        
        query = f"UPDATE servers SET {', '.join(update_fields)} WHERE id = ?"
        cursor.execute(query, values)
        
        conn.commit()
        result = self.get_server(server_id)
        conn.close()
        
        return result
    
    def delete_server(self, server_id: str) -> bool:
        """
        Delete a server
        
        Args:
            server_id: Server ID
        
        Returns:
            True if deleted, False if not found
        """
        logger.info(f"Deleting server from database: {server_id}")
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute('DELETE FROM servers WHERE id = ?', (server_id,))
        deleted = cursor.rowcount > 0
        
        conn.commit()
        conn.close()
        
        if deleted:
            logger.info(f"Server deleted successfully: {server_id}")
        else:
            logger.warning(f"Server not found for deletion: {server_id}")
        
        return deleted
    
    def server_exists(self, server_id: str) -> bool:
        """
        Check if a server exists
        
        Args:
            server_id: Server ID
        
        Returns:
            True if exists, False otherwise
        """
        conn = self._get_connection()
        cursor = conn.cursor()
        
        cursor.execute('SELECT 1 FROM servers WHERE id = ?', (server_id,))
        exists = cursor.fetchone() is not None
        
        conn.close()
        return exists

# Global database instance
_db_instance = None

def get_database() -> ServerDatabase:
    """Get or create database instance"""
    global _db_instance
    if _db_instance is None:
        _db_instance = ServerDatabase()
    return _db_instance

