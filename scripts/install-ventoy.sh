#!/bin/bash

# Ultimate Rescue USB - Ventoy Installation Script
# This script installs Ventoy bootloader on the target USB device

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VENTOY_VERSION="1.0.99"
VENTOY_URL="https://github.com/ventoy/Ventoy/releases/download/v${VENTOY_VERSION}/ventoy-${VENTOY_VERSION}-linux.tar.gz"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                🚀 Ultimate Rescue USB                    ║"
    echo "║                  Ventoy Installation                     ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (sudo)"
        exit 1
    fi
}

validate_device() {
    local device=$1
    
    if [[ ! -b "$device" ]]; then
        log_error "Device $device does not exist or is not a block device"
        exit 1
    fi
    
    # Check if it's a USB device
    if ! lsblk -d -o TRAN "$device" 2>/dev/null | grep -q "usb"; then
        log_warn "Device $device may not be a USB device"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Show device info
    log_info "Device information:"
    lsblk -f "$device"
    echo
    
    # Final confirmation
    log_warn "⚠️  WARNING: This will DESTROY all data on $device"
    echo -e "${RED}Are you absolutely sure? This action cannot be undone!${NC}"
    read -p "Type 'DESTROY' to continue: " confirmation
    
    if [[ "$confirmation" != "DESTROY" ]]; then
        log_info "Operation cancelled by user"
        exit 0
    fi
}

download_ventoy() {
    local temp_dir="/tmp/ventoy-install-$$"
    mkdir -p "$temp_dir"
    
    log_info "Downloading Ventoy v${VENTOY_VERSION}..."
    
    if ! wget -O "$temp_dir/ventoy.tar.gz" "$VENTOY_URL"; then
        log_error "Failed to download Ventoy"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    log_info "Extracting Ventoy..."
    if ! tar -xzf "$temp_dir/ventoy.tar.gz" -C "$temp_dir"; then
        log_error "Failed to extract Ventoy"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    echo "$temp_dir"
}

install_ventoy() {
    local device=$1
    local temp_dir=$2
    
    local ventoy_dir="$temp_dir/ventoy-${VENTOY_VERSION}"
    
    if [[ ! -d "$ventoy_dir" ]]; then
        log_error "Ventoy directory not found: $ventoy_dir"
        exit 1
    fi
    
    log_info "Installing Ventoy to $device..."
    
    # Use Ventoy2Disk.sh to install
    if ! "$ventoy_dir/Ventoy2Disk.sh" -i "$device"; then
        log_error "Failed to install Ventoy"
        exit 1
    fi
    
    log_info "✅ Ventoy installed successfully!"
}

setup_iso_structure() {
    local device=$1
    
    # Wait for system to recognize the new partitions
    sleep 3
    udevadm settle
    
    # Find the Ventoy partition (usually the larger one)
    local ventoy_partition
    for partition in "${device}"*; do
        if [[ -b "$partition" && "$partition" != "$device" ]]; then
            local fs_type=$(blkid -o value -s TYPE "$partition" 2>/dev/null || echo "")
            if [[ "$fs_type" == "exfat" || "$fs_type" == "vfat" ]]; then
                ventoy_partition="$partition"
                break
            fi
        fi
    done
    
    if [[ -z "$ventoy_partition" ]]; then
        log_error "Could not find Ventoy data partition"
        exit 1
    fi
    
    log_info "Setting up ISO folder structure on $ventoy_partition..."
    
    # Create mount point
    local mount_point="/mnt/ventoy-$$"
    mkdir -p "$mount_point"
    
    # Mount the partition
    if ! mount "$ventoy_partition" "$mount_point"; then
        log_error "Failed to mount Ventoy partition"
        rmdir "$mount_point"
        exit 1
    fi
    
    # Create folder structure
    mkdir -p "$mount_point/ISO/01-PRIMARY-GARUDA"
    mkdir -p "$mount_point/ISO/02-WINDOWS-RESCUE"
    mkdir -p "$mount_point/ISO/03-WINDOWS-INSTALL"
    mkdir -p "$mount_point/ISO/04-MACOS-INSTALL"
    mkdir -p "$mount_point/ISO/05-LINUX-RESCUE"
    mkdir -p "$mount_point/ISO/06-ANDROID-TOOLS"
    mkdir -p "$mount_point/ISO/07-UTILITIES"
    mkdir -p "$mount_point/ISO/08-BOOT-REPAIR"
    
    # Copy Ventoy configuration
    if [[ -f "$PROJECT_ROOT/configs/ventoy.json" ]]; then
        cp "$PROJECT_ROOT/configs/ventoy.json" "$mount_point/"
        log_info "Ventoy configuration copied"
    fi
    
    # Create README files for each folder
    cat > "$mount_point/ISO/01-PRIMARY-GARUDA/README.txt" << EOF
Primary Garuda Linux rescue environments
- Place garuda-dr460nized-*.iso here
- These will be the default boot options
EOF

    cat > "$mount_point/ISO/02-WINDOWS-RESCUE/README.txt" << EOF
Windows rescue and recovery tools
- Sergei Strelec WinPE
- Gandalf's Windows PE
- Hiren's BootCD PE
EOF

    # Unmount
    umount "$mount_point"
    rmdir "$mount_point"
    
    log_info "✅ ISO folder structure created successfully!"
}

show_next_steps() {
    echo
    log_info "🎉 Ventoy installation completed!"
    echo
    echo "Next steps:"
    echo "1. Copy your ISOs to the appropriate folders"
    echo "2. Run: ./scripts/setup-garuda-tools.sh"
    echo "3. Run: ./scripts/create-persistence.sh 70GB"
    echo
    echo "Folder structure created:"
    echo "├── ISO/01-PRIMARY-GARUDA/     (Main Garuda rescue environment)"
    echo "├── ISO/02-WINDOWS-RESCUE/     (Windows PE rescue tools)"
    echo "├── ISO/03-WINDOWS-INSTALL/    (Windows installation media)"
    echo "├── ISO/04-MACOS-INSTALL/      (macOS installation media)"
    echo "├── ISO/05-LINUX-RESCUE/       (Linux rescue tools)"
    echo "├── ISO/06-ANDROID-TOOLS/      (Android/mobile tools)"
    echo "├── ISO/07-UTILITIES/          (Hardware utilities)"
    echo "└── ISO/08-BOOT-REPAIR/        (Boot repair tools)"
    echo
}

main() {
    print_banner
    
    if [[ $# -ne 1 ]]; then
        echo "Usage: $0 <device>"
        echo "Example: $0 /dev/sdc"
        echo
        echo "Available devices:"
        lsblk -d -o NAME,SIZE,TRAN,MODEL | grep -E "(usb|USB)"
        exit 1
    fi
    
    local device=$1
    
    check_root
    validate_device "$device"
    
    local temp_dir
    temp_dir=$(download_ventoy)
    
    install_ventoy "$device" "$temp_dir"
    setup_iso_structure "$device"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    show_next_steps
}

main "$@"
