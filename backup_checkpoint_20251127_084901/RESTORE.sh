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

# Restore directories
for dir in web-ui playbooks scripts prometheus; do
    if [ -d "${BACKUP_DIR}/$dir" ]; then
        echo "  Restoring $dir/..."
        rm -rf "${PARENT_DIR}/$dir"
        cp -r "${BACKUP_DIR}/$dir" "${PARENT_DIR}/"
        echo "  ✓ Restored $dir/"
    fi
done

# Restore files
for file in start-application.sh requirements.txt .gitignore config.yml.example; do
    if [ -f "${BACKUP_DIR}/$file" ]; then
        echo "  Restoring $file..."
        cp "${BACKUP_DIR}/$file" "${PARENT_DIR}/"
        echo "  ✓ Restored $file"
    fi
done

echo ""
echo "========================================="
echo "  Restore Complete!"
echo "========================================="
echo "All files have been restored from checkpoint."
echo "You may need to restart the application."
