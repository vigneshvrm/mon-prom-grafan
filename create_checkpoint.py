#!/usr/bin/env python3
"""
Security Fix Checkpoint Creator
Creates a backup before applying security fixes
"""

import os
import shutil
import subprocess
from datetime import datetime
from pathlib import Path

def create_checkpoint():
    """Create a checkpoint backup of critical files"""
    
    script_dir = Path(__file__).parent.absolute()
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir = script_dir / f"backup_checkpoint_{timestamp}"
    
    print("=" * 50)
    print("  Creating Security Fix Checkpoint")
    print("=" * 50)
    print(f"Timestamp: {timestamp}")
    print(f"Backup Directory: {backup_dir}")
    print()
    
    # Create backup directory
    backup_dir.mkdir(exist_ok=True)
    
    # Files and directories to backup
    items_to_backup = [
        "web-ui",
        "playbooks",
        "scripts",
        "prometheus",
        "start-application.sh",
        "requirements.txt",
        ".gitignore",
        "config.yml.example"
    ]
    
    print("[1/4] Backing up critical files...")
    backed_up = []
    
    for item in items_to_backup:
        source = script_dir / item
        if source.exists():
            dest = backup_dir / item
            try:
                if source.is_dir():
                    shutil.copytree(source, dest, dirs_exist_ok=True)
                else:
                    shutil.copy2(source, dest)
                print(f"  ✓ Backed up {item}")
                backed_up.append(item)
            except Exception as e:
                print(f"  ✗ Failed to backup {item}: {e}")
    
    print()
    print("[2/4] Creating restore script...")
    
    # Create restore script
    restore_script = backup_dir / "RESTORE.sh"
    restore_content = f"""#!/bin/bash
# Restore from Security Fix Checkpoint
# Usage: ./RESTORE.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd)"
BACKUP_DIR="${{SCRIPT_DIR}}"
PARENT_DIR="$(dirname "${{BACKUP_DIR}}")"

echo "========================================="
echo "  Restoring from Checkpoint"
echo "========================================="
echo "Backup Directory: ${{BACKUP_DIR}}"
echo "Target Directory: ${{PARENT_DIR}}"
echo ""
echo "WARNING: This will overwrite current files!"
read -p "Are you sure you want to restore? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled."
    exit 1
fi

echo ""
echo "Restoring files..."

# Restore directories
for dir in web-ui playbooks scripts prometheus; do
    if [ -d "${{BACKUP_DIR}}/$dir" ]; then
        echo "  Restoring $dir/..."
        rm -rf "${{PARENT_DIR}}/$dir"
        cp -r "${{BACKUP_DIR}}/$dir" "${{PARENT_DIR}}/"
        echo "  ✓ Restored $dir/"
    fi
done

# Restore files
for file in start-application.sh requirements.txt .gitignore config.yml.example; do
    if [ -f "${{BACKUP_DIR}}/$file" ]; then
        echo "  Restoring $file..."
        cp "${{BACKUP_DIR}}/$file" "${{PARENT_DIR}}/"
        echo "  ✓ Restored $file"
    fi
done

echo ""
echo "========================================="
echo "  Restore Complete!"
echo "========================================="
echo "All files have been restored from checkpoint."
echo "You may need to restart the application."
"""
    
    with open(restore_script, 'w') as f:
        f.write(restore_content)
    
    # Make executable
    os.chmod(restore_script, 0o755)
    print("  ✓ Created RESTORE.sh")
    
    print()
    print("[3/4] Creating backup manifest...")
    
    # Create manifest
    manifest = backup_dir / "MANIFEST.txt"
    manifest_content = f"""Security Fix Checkpoint
=======================
Created: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
Timestamp: {timestamp}
Backup Directory: {backup_dir}

Files Backed Up:
{chr(10).join(f"- {item}" for item in backed_up)}

Purpose:
This checkpoint was created before applying security fixes to the application.
If security fixes cause issues, use RESTORE.sh to revert all changes.

To Restore:
1. cd to the backup directory: {backup_dir}
2. Run: ./RESTORE.sh
3. Follow the prompts

Security Fixes Planned:
- Authentication/Authorization implementation
- Input validation and sanitization
- CSRF protection
- Path traversal fixes
- Command injection prevention
- Security headers
- Error handling improvements
- Rate limiting

Note: Database files (servers.db) are NOT backed up as they contain runtime data.
"""
    
    with open(manifest, 'w') as f:
        f.write(manifest_content)
    print("  ✓ Created MANIFEST.txt")
    
    print()
    print("[4/4] Attempting Git checkpoint...")
    
    # Try git commit
    try:
        if Path(script_dir / ".git").exists():
            # Check if there are changes
            result = subprocess.run(
                ["git", "status", "--porcelain"],
                cwd=script_dir,
                capture_output=True,
                text=True
            )
            
            if result.stdout.strip():
                subprocess.run(
                    ["git", "add", "-A"],
                    cwd=script_dir,
                    check=False
                )
                subprocess.run(
                    ["git", "commit", "-m", f"Checkpoint: Before security fixes ({timestamp})"],
                    cwd=script_dir,
                    check=False
                )
                print("  ✓ Git checkpoint created")
            else:
                print("  ℹ No changes to commit (already up to date)")
        else:
            print("  ℹ Not a git repository")
    except Exception as e:
        print(f"  ℹ Git not available: {e}")
    
    print()
    print("=" * 50)
    print("  Checkpoint Created Successfully!")
    print("=" * 50)
    print(f"Backup Location: {backup_dir}")
    print()
    print("To restore from this checkpoint:")
    print(f"  cd {backup_dir}")
    print("  ./RESTORE.sh")
    print()
    print("You can now proceed with security fixes.")
    print("If anything breaks, use the restore script to revert.")
    print()
    
    return backup_dir

if __name__ == "__main__":
    create_checkpoint()

