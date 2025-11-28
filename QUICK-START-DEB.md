# Quick Start: Building .deb Package

## Issue: .deb package not being created

If you see the tarball being created instead of a .deb package, it means:

1. **The repository doesn't have the latest changes** - The new .deb build files need to be added:
   - `debian/` directory with control files
   - `scripts/build-deb.sh` script

2. **Solution**: Copy these files to your repository, or pull the latest changes.

## Quick Fix

If you're on the server and don't have the latest files, you can manually create the .deb:

### Option 1: Use the build script directly

```bash
# Make sure you have the debian directory and build-deb.sh
bash scripts/build-deb.sh
```

### Option 2: Check if files exist

```bash
# Check if required files exist
ls -la debian/
ls -la scripts/build-deb.sh

# If missing, you need to add them from the latest version
```

## Required Files for .deb Build

1. `debian/control` - Package metadata
2. `debian/postinst` - Post-installation script (executable)
3. `debian/prerm` - Pre-removal script (executable)
4. `debian/postrm` - Post-removal script (executable)
5. `scripts/build-deb.sh` - Build script (executable)

## Build Requirements

Before building, ensure you have:

```bash
# Install build tools
sudo apt-get update
sudo apt-get install -y dpkg-dev fakeroot

# Build dependencies
sudo apt-get install -y python3 python3-pip python3-venv podman tar curl

# Node.js for frontend build
sudo apt-get install -y npm
```

## Build the Package

```bash
# Method 1: Using package-release.sh (if updated)
bash scripts/package-release.sh --deb

# Method 2: Direct build
bash scripts/build-deb.sh
```

The .deb file will be created in `dist/inframonitor_1.0.0_all.deb`

## Install the Package

```bash
sudo dpkg -i dist/inframonitor_1.0.0_all.deb
sudo apt-get install -f  # If dependencies needed
```

