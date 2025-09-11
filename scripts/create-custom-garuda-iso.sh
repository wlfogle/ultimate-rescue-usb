#!/bin/bash

# Ultimate Rescue USB - Custom Garuda ISO Creator
# This script creates a customized Garuda ISO with all rescue tools pre-installed

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WORK_DIR="$HOME/garuda-rescue-iso-build"

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║         🐉 Custom Garuda Rescue ISO Creator              ║"
    echo "║           Ultimate Pre-Configured Rescue System          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_section() {
    echo -e "${MAGENTA}[SECTION]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    log_section "🔍 Checking Dependencies"
    
    local deps=(
        archiso
        git
        wget
        rsync
        squashfs-tools
    )
    
    local missing=()
    for dep in "${deps[@]}"; do
        if ! pacman -Q "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_info "Installing missing dependencies: ${missing[*]}"
        sudo pacman -S --noconfirm --needed "${missing[@]}"
    fi
    
    log_info "All dependencies satisfied"
}

setup_build_environment() {
    log_section "🏗️ Setting Up Build Environment"
    
    # Clean and create work directory
    if [ -d "$WORK_DIR" ]; then
        log_warn "Removing existing build directory"
        sudo rm -rf "$WORK_DIR"
    fi
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    # Copy archiso profile
    cp -r /usr/share/archiso/configs/releng/ garuda-rescue/
    cd garuda-rescue/
    
    log_info "Build environment created at $WORK_DIR/garuda-rescue/"
}

customize_packages() {
    log_section "📦 Customizing Package List"
    
    # Create our custom package list
    cat > packages.x86_64 << 'EOF'
# Base system
base
base-devel
linux-zen
linux-zen-headers
linux-firmware
intel-ucode
amd-ucode

# Boot and EFI
grub
efibootmgr
os-prober
systemd-boot

# KDE Plasma Desktop
plasma-meta
plasma-wayland-session
kde-applications-meta
sddm
konsole
dolphin
kate
gwenview
spectacle

# Garuda specific
garuda-common
garuda-settings-manager
garuda-boot-manager
chaotic-keyring
chaotic-mirrorlist

# Core rescue tools
gparted
parted
testdisk
ddrescue
clonezilla
photorec
foremost
extundelete

# Hardware diagnostics
hwinfo
lshw
smartmontools
memtest86-efi
stress
hdparm

# Network tools
nmap
wireshark-qt
tcpdump
wget
curl
rsync
networkmanager

# Security & forensics
clamav
chkrootkit
rkhunter
john
hashcat

# Filesystem support
ntfs-3g
exfatprogs
hfsprogs
dosfstools
btrfs-progs
xfsprogs
jfsutils
reiserfsprogs

# Archive tools
p7zip
unrar
zip
unzip
tar
xz

# Virtualization
qemu-full
docker
virtualbox

# Windows compatibility
wine-staging
winetricks

# Mac/Apple support
libimobiledevice
ifuse
usbmuxd

# Android tools
android-tools
scrcpy

# Development tools
git
vim
nano
code
python
python-pip

# Multimedia
vlc
gimp
audacity
ffmpeg

# Additional utilities
firefox
chromium
keepassxc
veracrypt
balena-etcher
teamviewer

# System utilities
htop
neofetch
tree
lsof
strace
ltrace
EOF
    
    log_info "Custom package list created"
}

customize_airootfs() {
    log_section "🛠️ Customizing Root Filesystem"
    
    # Create custom user setup
    mkdir -p airootfs/etc/skel/Desktop
    mkdir -p airootfs/usr/local/bin
    
    # Copy our rescue tool setup script
    cp "$PROJECT_ROOT/scripts/setup-garuda-tools.sh" airootfs/usr/local/bin/
    chmod +x airootfs/usr/local/bin/setup-garuda-tools.sh
    
    # Create rescue desktop shortcuts
    cat > airootfs/etc/skel/Desktop/Ultimate-Rescue-Tools.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=🚀 Ultimate Rescue Tools Setup
Comment=Install all rescue tools and configure the system
Exec=konsole --title "Ultimate Rescue Setup" -e sudo /usr/local/bin/setup-garuda-tools.sh
Icon=applications-system
Categories=System;
EOF
    
    chmod +x airootfs/etc/skel/Desktop/Ultimate-Rescue-Tools.desktop
    
    # Create custom systemd service for auto-setup
    mkdir -p airootfs/etc/systemd/system
    cat > airootfs/etc/systemd/system/garuda-rescue-setup.service << 'EOF'
[Unit]
Description=Garuda Ultimate Rescue Setup
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-garuda-tools.sh
RemainAfterExit=yes
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable the service
    mkdir -p airootfs/etc/systemd/system/multi-user.target.wants
    ln -sf ../garuda-rescue-setup.service airootfs/etc/systemd/system/multi-user.target.wants/
    
    log_info "Root filesystem customized"
}

customize_profile() {
    log_section "⚙️ Customizing ISO Profile"
    
    # Update ISO label and description
    sed -i 's/iso_label="ARCH_.*"/iso_label="GARUDA_RESCUE"/' profiledef.sh
    sed -i 's/iso_publisher=".*"/iso_publisher="Ultimate Rescue USB Project"/' profiledef.sh
    sed -i 's/iso_application=".*"/iso_application="Garuda Ultimate Rescue System"/' profiledef.sh
    
    # Set default boot parameters
    mkdir -p efiboot/loader/entries
    cat > efiboot/loader/entries/01-archiso-x86_64-linux.conf << 'EOF'
title    Garuda Ultimate Rescue (UEFI)
sort-key 01
linux    /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux-zen
initrd   /%INSTALL_DIR%/boot/intel-ucode.img
initrd   /%INSTALL_DIR%/boot/amd-ucode.img
initrd   /%INSTALL_DIR%/boot/x86_64/initramfs-linux-zen.img
options  archisobasedir=%INSTALL_DIR% archisolabel=GARUDA_RESCUE cow_spacesize=4G module_blacklist=nouveau nomodeset
EOF
    
    log_info "ISO profile customized"
}

build_iso() {
    log_section "🔨 Building Custom Garuda ISO"
    
    local output_dir="$WORK_DIR/output"
    local work_build_dir="$WORK_DIR/work"
    
    mkdir -p "$output_dir"
    
    log_info "Starting ISO build process..."
    log_warn "This may take 30-60 minutes depending on your system"
    
    # Build the ISO
    if sudo mkarchiso -v -w "$work_build_dir" -o "$output_dir" ./; then
        log_info "✅ ISO built successfully!"
        
        # Find the generated ISO
        local iso_file=$(find "$output_dir" -name "*.iso" -type f | head -1)
        if [ -n "$iso_file" ]; then
            local iso_name="garuda-ultimate-rescue-$(date +%Y%m%d).iso"
            mv "$iso_file" "$output_dir/$iso_name"
            log_info "ISO saved as: $output_dir/$iso_name"
            
            # Calculate checksums
            cd "$output_dir"
            sha256sum "$iso_name" > "${iso_name}.sha256"
            md5sum "$iso_name" > "${iso_name}.md5"
            
            log_info "Checksums generated"
        fi
    else
        log_error "ISO build failed!"
        exit 1
    fi
}

show_completion() {
    local output_dir="$WORK_DIR/output"
    
    echo
    echo -e "${GREEN}🎉 CUSTOM GARUDA RESCUE ISO CREATED! 🎉${NC}"
    echo
    echo "ISO Details:"
    echo "├── Location: $output_dir/"
    echo "├── Features: KDE Plasma X11, All rescue tools pre-installed"
    echo "├── Size: ~4-6GB (depending on packages)"
    echo "└── Boot: UEFI + Legacy BIOS compatible"
    echo
    echo "What's included:"
    echo "✅ Garuda Linux Dr460nized base"
    echo "✅ All Ultimate Rescue tools pre-configured"
    echo "✅ Windows, Mac, Android support"
    echo "✅ AI-powered diagnostics"
    echo "✅ Security & forensics suite"
    echo "✅ Virtualization environment"
    echo
    echo "Next steps:"
    echo "1. Test the ISO in a VM first"
    echo "2. Use with Ventoy or write directly to USB"
    echo "3. Boot and enjoy your ultimate rescue environment!"
    echo
}

main() {
    print_banner
    
    if [[ $EUID -eq 0 ]]; then
        log_error "Don't run this script as root! It will use sudo when needed."
        exit 1
    fi
    
    check_dependencies
    setup_build_environment
    customize_packages
    customize_airootfs
    customize_profile
    build_iso
    
    show_completion
}

main "$@"
