#!/bin/bash
# Check and install Podman if needed

set -e

# Set non-interactive mode if not already set
export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"
export NEEDRESTART_MODE="${NEEDRESTART_MODE:-a}"

check_podman() {
    if command -v podman &> /dev/null; then
        return 0
    else
        return 1
    fi
}

install_podman_ubuntu() {
    echo "Installing Podman on Ubuntu..."
    
    # Detect Ubuntu version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        UBUNTU_VERSION="$VERSION_ID"
    else
        echo "Error: Cannot detect Ubuntu version"
        exit 1
    fi
    
    echo "Detected Ubuntu version: $UBUNTU_VERSION"
    
    # Step 1: Install curl if not available
    if ! command -v curl &> /dev/null; then
        echo "Installing curl..."
        sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get update -qq
        sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get install -y -qq curl ca-certificates
    fi
    
    # Step 2: Add Podman repository (method that works perfectly)
    echo "Adding Podman repository..."
    echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${UBUNTU_VERSION}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list > /dev/null
    
    # Step 3: Add GPG key (method that works perfectly)
    echo "Adding GPG key..."
    curl -fsSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${UBUNTU_VERSION}/Release.key" | sudo apt-key add - > /dev/null 2>&1
    
    # Step 4: Update apt cache
    echo "Updating apt cache..."
    sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt update -qq
    
    # Step 5: Install Podman
    echo "Installing Podman..."
    sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt install -y -qq podman
}

install_podman_centos() {
    echo "Installing Podman on CentOS/RHEL..."
    sudo yum install -y podman
}

install_podman_arch() {
    echo "Installing Podman on Arch Linux..."
    sudo pacman -S --noconfirm podman
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    elif [ -f /etc/redhat-release ]; then
        echo "centos"
    else
        echo "unknown"
    fi
}

main() {
    echo "Checking for Podman installation..."
    
    if check_podman; then
        PODMAN_VERSION=$(podman --version)
        echo "✓ Podman is already installed: $PODMAN_VERSION"
        return 0
    fi
    
    echo "Podman is not installed. Attempting to install..."
    
    OS=$(detect_os)
    case $OS in
        ubuntu|debian)
            install_podman_ubuntu
            ;;
        centos|rhel|fedora)
            install_podman_centos
            ;;
        arch|manjaro)
            install_podman_arch
            ;;
        *)
            echo "Warning: Unknown OS. Please install Podman manually."
            echo "Visit: https://podman.io/getting-started/installation"
            exit 1
            ;;
    esac
    
    if check_podman; then
        echo "✓ Podman installed successfully"
        podman --version
        return 0
    else
        echo "✗ Failed to install Podman. Please install manually."
        exit 1
    fi
}

main "$@"

