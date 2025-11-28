#!/usr/bin/env python3
"""
Generate bcrypt password hash for Node Exporter Basic Authentication
Usage: python3 generate-password-hash.py [password]
"""

import sys
import getpass
import bcrypt

def generate_hash(password=None):
    """Generate bcrypt hash for password"""
    if password is None:
        password = getpass.getpass("Enter password: ")
    
    if not password:
        print("Error: Password cannot be empty", file=sys.stderr)
        sys.exit(1)
    
    # Generate bcrypt hash with cost factor 12 (industry standard)
    hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt(rounds=12))
    
    return hashed.decode('utf-8')

if __name__ == "__main__":
    password = None
    
    if len(sys.argv) > 1:
        password = sys.argv[1]
    
    try:
        hashed_password = generate_hash(password)
        print(hashed_password)
    except KeyboardInterrupt:
        print("\nOperation cancelled", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

