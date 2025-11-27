#!/bin/bash
# Security Fix Checkpoint Creator
# Creates a backup before applying security fixes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${SCRIPT_DIR}/backup_checkpoint_${TIMESTAMP}"
RESTORE_SCRIPT="${BACKUP_DIR}/RESTORE.sh"

echo "========================================="
echo "  Creating Security Fix Checkpoint"
echo "========================================="
echo "Timestamp: ${TIMESTAMP}"
echo "Backup Directory: ${BACKUP_DIR}"
echo ""

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Critical files and directories to backup
echo "[1/4] Backing up critical files..."

# Web UI (Flask application)
if [ -d "web-ui" ]; then
    cp -r web-ui "${BACKUP_DIR}/"
    echo "  ✓ Backed up web-ui/"
fi

# Playbooks
if [ -d "playbooks" ]; then
    cp -r playbooks "${BACKUP_DIR}/"
    echo "  ✓ Backed up playbooks/"
fi

# Scripts
if [ -d "scripts" ]; then
    cp -r scripts "${BACKUP_DIR}/"
    echo "  ✓ Backed up scripts/"
fi

# Prometheus manager
if [ -d "prometheus" ]; then
    cp -r prometheus "${BACKUP_DIR}/"
    echo "  ✓ Backed up prometheus/"
fi

# Main startup script
if [ -f "start-application.sh" ]; then
    cp start-application.sh "${BACKUP_DIR}/"
    echo "  ✓ Backed up start-application.sh"
fi

# Requirements
if [ -f "requirements.txt" ]; then
    cp requirements.txt "${BACKUP_DIR}/"
    echo "  ✓ Backed up requirements.txt"
fi

# Git ignore
if [ -f ".gitignore" ]; then
    cp .gitignore "${BACKUP_DIR}/"
    echo "  ✓ Backed up .gitignore"
fi

# Configuration files
if [ -f "config.yml.example" ]; then
    cp config.yml.example "${BACKUP_DIR}/"
    echo "  ✓ Backed up config.yml.example"
fi

echo ""
echo "[2/4] Creating restore script..."

# Create restore script
cat > "${RESTORE_SCRIPT}" << 'RESTORE_EOF'
#!/bin/bash
# Restore from Security Fix Checkpoint
# Usage: ./RESTORE.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}"
PARENT_DIR="$(dirname "${BACKUP_DIR}")"

echo "========================================="
echo "  Restoring from Checkpoint"
echo "========================================="
echo "Backup Directory: ${BACKUP_DIR}"
echo "Target Directory: ${PARENT_DIR}"
echo ""
echo "WARNING: This will overwrite current files!"
read -p "Are you sure you want to restore? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled."
    exit 1
fi

echo ""
echo "Restoring files..."

# Restore web-ui
if [ -d "${BACKUP_DIR}/web-ui" ]; then
    echo "  Restoring web-ui/..."
    rm -rf "${PARENT_DIR}/web-ui"
    cp -r "${BACKUP_DIR}/web-ui" "${PARENT_DIR}/"
    echo "  ✓ Restored web-ui/"
fi

# Restore playbooks
if [ -d "${BACKUP_DIR}/playbooks" ]; then
    echo "  Restoring playbooks/..."
    rm -rf "${PARENT_DIR}/playbooks"
    cp -r "${BACKUP_DIR}/playbooks" "${PARENT_DIR}/"
    echo "  ✓ Restored playbooks/"
fi

# Restore scripts
if [ -d "${BACKUP_DIR}/scripts" ]; then
    echo "  Restoring scripts/..."
    rm -rf "${PARENT_DIR}/scripts"
    cp -r "${BACKUP_DIR}/scripts" "${PARENT_DIR}/"
    echo "  ✓ Restored scripts/"
fi

# Restore prometheus
if [ -d "${BACKUP_DIR}/prometheus" ]; then
    echo "  Restoring prometheus/..."
    rm -rf "${PARENT_DIR}/prometheus"
    cp -r "${BACKUP_DIR}/prometheus" "${PARENT_DIR}/"
    echo "  ✓ Restored prometheus/"
fi

# Restore individual files
for file in start-application.sh requirements.txt .gitignore config.yml.example; do
    if [ -f "${BACKUP_DIR}/${file}" ]; then
        echo "  Restoring ${file}..."
        cp "${BACKUP_DIR}/${file}" "${PARENT_DIR}/"
        echo "  ✓ Restored ${file}"
    fi
done

echo ""
echo "========================================="
echo "  Restore Complete!"
echo "========================================="
echo "All files have been restored from checkpoint."
echo "You may need to restart the application."
RESTORE_EOF

chmod +x "${RESTORE_SCRIPT}"
echo "  ✓ Created RESTORE.sh"

echo ""
echo "[3/4] Creating backup manifest..."

# Create manifest
cat > "${BACKUP_DIR}/MANIFEST.txt" << MANIFEST_EOF
Security Fix Checkpoint
=======================
Created: $(date)
Timestamp: ${TIMESTAMP}
Backup Directory: ${BACKUP_DIR}

Files Backed Up:
- web-ui/ (Flask application, React frontend, database)
- playbooks/ (Ansible playbooks and templates)
- scripts/ (Installation and utility scripts)
- prometheus/ (Prometheus configuration manager)
- start-application.sh (Main startup script)
- requirements.txt (Python dependencies)
- .gitignore (Git ignore patterns)
- config.yml.example (Configuration example)

Purpose:
This checkpoint was created before applying security fixes to the application.
If security fixes cause issues, use RESTORE.sh to revert all changes.

To Restore:
1. cd to the backup directory: ${BACKUP_DIR}
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
MANIFEST_EOF

echo "  ✓ Created MANIFEST.txt"

echo ""
echo "[4/4] Attempting Git checkpoint..."

# Try to create git commit if git is available
if command -v git &> /dev/null && [ -d ".git" ]; then
    echo "  Git repository detected, creating commit..."
    
    # Check if there are changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        git add -A
        git commit -m "Checkpoint: Before security fixes (${TIMESTAMP})" || echo "  ⚠ Git commit failed (may need to configure git)"
        echo "  ✓ Git checkpoint created"
    else
        echo "  ℹ No changes to commit (already up to date)"
    fi
else
    echo "  ℹ Git not available or not a git repository"
fi

echo ""
echo "========================================="
echo "  Checkpoint Created Successfully!"
echo "========================================="
echo "Backup Location: ${BACKUP_DIR}"
echo ""
echo "To restore from this checkpoint:"
echo "  cd ${BACKUP_DIR}"
echo "  ./RESTORE.sh"
echo ""
echo "You can now proceed with security fixes."
echo "If anything breaks, use the restore script to revert."
echo ""

