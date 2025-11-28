#!/usr/bin/env bash
#
# Build InfraMonitor as a Debian package (.deb)
#
# This creates a professional .deb package that installs silently,
# hiding all installation details from the client.
#
# Requirements:
#   - dpkg-deb
#   - fakeroot (for building as non-root)
#   - bash, tar, python3, npm

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
DEB_DIR="${DIST_DIR}/deb-build"
PKG_NAME="inframonitor"
PKG_VERSION="1.0.0"
DEB_NAME="${PKG_NAME}_${PKG_VERSION}_all"

echo "========================================="
echo "  Building InfraMonitor Debian Package"
echo "========================================="
echo ""

# Clean previous builds
echo "[1/7] Cleaning previous builds..."
rm -rf "${DEB_DIR}"
mkdir -p "${DEB_DIR}/${DEB_NAME}"

# Build React frontend
echo "[2/7] Building React frontend..."
pushd "${ROOT_DIR}/web-ui" >/dev/null
if [ ! -d "node_modules" ]; then
    echo "  Installing npm dependencies..."
    npm install >/dev/null 2>&1 || {
        echo "ERROR: npm install failed" >&2
        popd >/dev/null
        exit 1
    }
fi
echo "  Running npm build..."
npm run build || {
    echo "ERROR: npm run build failed" >&2
    echo "Please check the errors above and fix them before building the package." >&2
    popd >/dev/null
    exit 1
}
if [ ! -d "dist" ]; then
    echo "ERROR: web-ui/dist directory not found after build" >&2
    popd >/dev/null
    exit 1
fi
popd >/dev/null

# Create package directory structure
echo "[3/7] Creating package structure..."
mkdir -p "${DEB_DIR}/${DEB_NAME}/usr/share/${PKG_NAME}"
mkdir -p "${DEB_DIR}/${DEB_NAME}/DEBIAN"

# Copy application files
echo "[4/7] Copying application files..."

# Backend + web assets
cp -r "${ROOT_DIR}/web-ui/app.py" \
      "${ROOT_DIR}/web-ui/database.py" \
      "${ROOT_DIR}/web-ui/security_utils.py" \
      "${ROOT_DIR}/web-ui/templates" \
      "${ROOT_DIR}/web-ui/metadata.json" \
      "${DEB_DIR}/${DEB_NAME}/usr/share/${PKG_NAME}/web-ui/" 2>/dev/null || true

# Include static directory if it exists
if [ -d "${ROOT_DIR}/web-ui/static" ]; then
    cp -r "${ROOT_DIR}/web-ui/static" "${DEB_DIR}/${DEB_NAME}/usr/share/${PKG_NAME}/web-ui/"
fi

# React build artifacts
if [ -d "${ROOT_DIR}/web-ui/dist" ]; then
    cp -r "${ROOT_DIR}/web-ui/dist" "${DEB_DIR}/${DEB_NAME}/usr/share/${PKG_NAME}/web-ui/"
else
    echo "WARNING: web-ui/dist not found. Ensure 'npm run build' succeeded." >&2
fi

# Supporting directories
cp -r "${ROOT_DIR}/playbooks" "${DEB_DIR}/${DEB_NAME}/usr/share/${PKG_NAME}/"
cp -r "${ROOT_DIR}/prometheus" "${DEB_DIR}/${DEB_NAME}/usr/share/${PKG_NAME}/"
cp -r "${ROOT_DIR}/scripts" "${DEB_DIR}/${DEB_NAME}/usr/share/${PKG_NAME}/"

# Root level files
cp "${ROOT_DIR}/requirements.txt" "${DEB_DIR}/${DEB_NAME}/usr/share/${PKG_NAME}/"
cp "${ROOT_DIR}/start-application.sh" "${DEB_DIR}/${DEB_NAME}/usr/share/${PKG_NAME}/"
if [ -f "${ROOT_DIR}/config.yml.example" ]; then
    cp "${ROOT_DIR}/config.yml.example" "${DEB_DIR}/${DEB_NAME}/usr/share/${PKG_NAME}/"
fi

# Copy Debian control files
echo "[5/7] Setting up Debian package files..."
cp "${ROOT_DIR}/debian/control" "${DEB_DIR}/${DEB_NAME}/DEBIAN/control"
cp "${ROOT_DIR}/debian/postinst" "${DEB_DIR}/${DEB_NAME}/DEBIAN/postinst"
cp "${ROOT_DIR}/debian/prerm" "${DEB_DIR}/${DEB_NAME}/DEBIAN/prerm"
cp "${ROOT_DIR}/debian/postrm" "${DEB_DIR}/${DEB_NAME}/DEBIAN/postrm"

# Make scripts executable
chmod +x "${DEB_DIR}/${DEB_NAME}/DEBIAN/postinst"
chmod +x "${DEB_DIR}/${DEB_NAME}/DEBIAN/prerm"
chmod +x "${DEB_DIR}/${DEB_NAME}/DEBIAN/postrm"

# Calculate package size
echo "[6/7] Calculating package size..."
INSTALLED_SIZE=$(du -sk "${DEB_DIR}/${DEB_NAME}/usr" | cut -f1)
sed -i "s/^Installed-Size:.*/Installed-Size: ${INSTALLED_SIZE}/" "${DEB_DIR}/${DEB_NAME}/DEBIAN/control" || true

# Build .deb package
echo "[7/7] Building .deb package..."
mkdir -p "${DIST_DIR}"
pushd "${DEB_DIR}" >/dev/null

# Use fakeroot if available, otherwise require root
if command -v fakeroot >/dev/null 2>&1; then
    fakeroot dpkg-deb --build "${DEB_NAME}" >/dev/null
else
    echo "WARNING: fakeroot not found. Building as current user (may have permission issues)." >&2
    echo "         Install fakeroot for better results: apt-get install fakeroot" >&2
    dpkg-deb --build "${DEB_NAME}" >/dev/null
fi

# Move .deb to dist directory
mv "${DEB_NAME}.deb" "${DIST_DIR}/"

popd >/dev/null

# Clean up build directory
rm -rf "${DEB_DIR}"

echo ""
echo "✓ Debian package built successfully!"
echo ""
echo "Package: ${DIST_DIR}/${DEB_NAME}.deb"
echo ""
echo "To install:"
echo "  sudo dpkg -i ${DIST_DIR}/${DEB_NAME}.deb"
echo ""
echo "To install with dependency resolution:"
echo "  sudo apt-get install -f && sudo dpkg -i ${DIST_DIR}/${DEB_NAME}.deb"
echo ""

