#!/bin/bash

# Ultimate Rescue USB - Garuda Tools Installation Script
# This script installs comprehensive rescue tools in Garuda Linux

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║           🐉 Ultimate Garuda Rescue Tools Setup          ║"
    echo "║              AI-Powered Multi-Platform Suite             ║"
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

check_garuda() {
    if ! grep -q "Garuda" /etc/os-release 2>/dev/null; then
        log_warn "This script is optimized for Garuda Linux"
        log_warn "Some features may not work on other distributions"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

update_system() {
    log_section "📦 Updating System Packages"
    
    # Update pacman databases
    sudo pacman -Sy --noconfirm
    
    # Update Chaotic-AUR keyring
    if pacman -Q chaotic-keyring >/dev/null 2>&1; then
        sudo pacman -S --noconfirm chaotic-keyring
    fi
    
    log_info "System packages updated"
}

install_yay() {
    if ! command -v yay >/dev/null 2>&1; then
        log_section "🔧 Installing YAY AUR Helper"
        
        sudo pacman -S --noconfirm --needed base-devel git
        
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ~
        
        log_info "YAY AUR helper installed"
    else
        log_info "YAY already installed"
    fi
}

install_core_rescue_tools() {
    log_section "🛠️ Installing Core Rescue Tools"
    
    local core_tools=(
        # Disk and filesystem tools
        gparted
        parted
        fdisk
        gdisk
        ddrescue
        dd
        clonezilla
        testdisk
        photorec
        foremost
        extundelete
        ext4magic
        
        # System rescue
        systemd-boot
        efibootmgr
        grub
        os-prober
        
        # Hardware diagnostics
        hwinfo
        lshw
        lscpu
        lspci
        lsusb
        dmidecode
        smartmontools
        hdparm
        stress
        memtester
        
        # Network tools
        nmap
        wireshark-qt
        tcpdump
        netcat
        wget
        curl
        rsync
        
        # Archive tools
        p7zip
        unrar
        unzip
        tar
        gzip
        bzip2
        xz
    )
    
    sudo pacman -S --noconfirm --needed "${core_tools[@]}"
    log_info "Core rescue tools installed"
}

install_security_forensics() {
    log_section "🔐 Installing Security & Forensics Tools"
    
    # Pacman packages
    local security_pacman=(
        clamav
        clamtk
        chkrootkit
        rkhunter
        nmap
        wireshark-qt
        john
        hashcat
        aircrack-ng
        tcpdump
        ettercap
        nikto
    )
    
    sudo pacman -S --noconfirm --needed "${security_pacman[@]}"
    
    # AUR packages
    local security_aur=(
        sleuthkit
        autopsy
        volatility3
        foremost
        maldetect
        lynis
        tiger
        aide
        samhain
    )
    
    for tool in "${security_aur[@]}"; do
        yay -S --noconfirm --needed "$tool" || log_warn "Failed to install $tool"
    done
    
    log_info "Security & forensics tools installed"
}

install_virtualization() {
    log_section "🖥️ Installing Virtualization & Containers"
    
    local virt_tools=(
        qemu-full
        virt-manager
        virt-viewer
        bridge-utils
        docker
        docker-compose
        virtualbox
        virtualbox-host-modules-arch
    )
    
    sudo pacman -S --noconfirm --needed "${virt_tools[@]}"
    
    # Enable services
    sudo systemctl enable --now libvirtd
    sudo systemctl enable --now docker
    
    # Add user to groups
    sudo usermod -aG libvirt,docker,vboxusers "$USER"
    
    log_info "Virtualization tools installed"
}

install_windows_tools() {
    log_section "🪟 Installing Windows Compatibility Tools"
    
    local wine_tools=(
        wine-staging
        winetricks
        wine-gecko
        wine-mono
        playonlinux
        bottles
    )
    
    sudo pacman -S --noconfirm --needed "${wine_tools[@]}"
    
    # Install additional Windows tools via AUR
    yay -S --noconfirm --needed wineasio || true
    
    log_info "Windows compatibility tools installed"
}

install_mac_tools() {
    log_section "🍎 Installing Mac/Apple Support Tools"
    
    # Pacman packages
    local mac_pacman=(
        hfsprogs
        libimobiledevice
        ifuse
        ideviceinstaller
        usbmuxd
    )
    
    sudo pacman -S --noconfirm --needed "${mac_pacman[@]}"
    
    # AUR packages for enhanced Mac support
    local mac_aur=(
        apfs-fuse-git
        dmg2img
        hfsutils
        mac-precision-touchpad
        macchanger
    )
    
    for tool in "${mac_aur[@]}"; do
        yay -S --noconfirm --needed "$tool" || log_warn "Failed to install $tool"
    done
    
    log_info "Mac/Apple support tools installed"
}

install_android_tools() {
    log_section "📱 Installing Android/Mobile Tools"
    
    local android_tools=(
        android-tools
        android-udev
        scrcpy
        fastboot
        adb
    )
    
    sudo pacman -S --noconfirm --needed "${android_tools[@]}"
    
    # AUR packages
    local android_aur=(
        heimdall
        odin-git
        android-studio
        qtadb
        droidcam
    )
    
    for tool in "${android_aur[@]}"; do
        yay -S --noconfirm --needed "$tool" || log_warn "Failed to install $tool"
    done
    
    log_info "Android/mobile tools installed"
}

install_ai_python_tools() {
    log_section "🧠 Installing AI & Python Development Tools"
    
    local python_tools=(
        python
        python-pip
        python-numpy
        python-scipy
        python-matplotlib
        python-pandas
        python-scikit-learn
        python-tensorflow
        python-pytorch
        jupyter-notebook
        python-requests
        python-beautifulsoup4
        python-selenium
    )
    
    sudo pacman -S --noconfirm --needed "${python_tools[@]}"
    
    # Install additional AI/ML packages via pip
    pip install --user --upgrade \
        torch torchvision torchaudio \
        transformers \
        opencv-python \
        pillow \
        psutil \
        yara-python \
        volatility3 \
        pefile \
        distorm3
    
    log_info "AI & Python tools installed"
}

install_multimedia_tools() {
    log_section "🎨 Installing Multimedia & Graphics Tools"
    
    local media_tools=(
        gimp
        inkscape
        blender
        ffmpeg
        vlc
        audacity
        imagemagick
        graphicsmagick
        exiftool
        mediainfo
    )
    
    sudo pacman -S --noconfirm --needed "${media_tools[@]}"
    
    log_info "Multimedia tools installed"
}

install_development_tools() {
    log_section "👨‍💻 Installing Development Tools"
    
    local dev_tools=(
        git
        vim
        nano
        code
        base-devel
        cmake
        make
        gcc
        gdb
        valgrind
        strace
        ltrace
        hexdump
        xxd
        binutils
        radare2
        ghex
    )
    
    sudo pacman -S --noconfirm --needed "${dev_tools[@]}"
    
    log_info "Development tools installed"
}

install_additional_utilities() {
    log_section "⚙️ Installing Additional Utilities"
    
    # AUR utilities
    local aur_utilities=(
        google-chrome
        discord
        telegram-desktop
        teamviewer
        anydesk-bin
        balena-etcher
        ventoy-bin
        yubico-authenticator
        keepassxc
        veracrypt
        tresorit
        megasync-bin
    )
    
    for tool in "${aur_utilities[@]}"; do
        yay -S --noconfirm --needed "$tool" || log_warn "Failed to install $tool"
    done
    
    log_info "Additional utilities installed"
}

setup_desktop_shortcuts() {
    log_section "🖥️ Setting up Desktop Shortcuts"
    
    local desktop_dir="$HOME/Desktop"
    mkdir -p "$desktop_dir"
    
    # Create rescue tools folder
    mkdir -p "$HOME/Desktop/Rescue-Tools"
    
    # Create shortcut categories
    cat > "$HOME/Desktop/Rescue-Tools/System-Rescue.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=System Rescue Tools
Comment=GParted, TestDisk, DDRescue, Clonezilla
Exec=konsole --title "System Rescue" -e bash -c "echo 'System Rescue Tools:'; echo '1. gparted - Partition editor'; echo '2. testdisk - Data recovery'; echo '3. ddrescue - Disk cloning'; echo '4. clonezilla - Disk imaging'; echo; read -p 'Press Enter to continue...'"
Icon=drive-harddisk
Categories=System;
EOF
    
    chmod +x "$HOME/Desktop/Rescue-Tools/System-Rescue.desktop"
    
    log_info "Desktop shortcuts created"
}

optimize_for_rescue() {
    log_section "⚡ Optimizing System for Rescue Operations"
    
    # Increase file descriptor limits
    echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
    echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
    
    # Optimize I/O scheduler for USB
    echo 'ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"' | \
        sudo tee /etc/udev/rules.d/60-ioschedulers.rules
    
    # Enable memory compression
    echo "zram" | sudo tee /etc/modules-load.d/zram.conf
    
    log_info "System optimized for rescue operations"
}

show_completion() {
    echo
    echo -e "${GREEN}🎉 ULTIMATE RESCUE TOOLS INSTALLATION COMPLETED! 🎉${NC}"
    echo
    echo "Installed tool categories:"
    echo "✅ Core rescue tools (disk, filesystem, recovery)"
    echo "✅ Security & forensics (malware, network analysis)"
    echo "✅ Virtualization (QEMU, VirtualBox, Docker)"
    echo "✅ Windows compatibility (Wine, Windows PE tools)"
    echo "✅ Mac/Apple support (HFS, iOS device tools)"
    echo "✅ Android/mobile tools (ADB, fastboot, recovery)"
    echo "✅ AI & Python tools (ML frameworks, analysis)"
    echo "✅ Multimedia & graphics tools"
    echo "✅ Development tools (debugging, reverse engineering)"
    echo "✅ Additional utilities"
    echo
    echo "Next steps:"
    echo "1. Reboot or logout/login to apply group changes"
    echo "2. Run: ./scripts/create-persistence.sh 70GB"
    echo "3. Copy your ISOs to the Ventoy USB"
    echo "4. Test the rescue environment"
    echo
    echo "Your Garuda system is now a RESCUE POWERHOUSE! 🚀"
}

main() {
    print_banner
    
    check_garuda
    update_system
    install_yay
    
    install_core_rescue_tools
    install_security_forensics
    install_virtualization
    install_windows_tools
    install_mac_tools
    install_android_tools
    install_ai_python_tools
    install_multimedia_tools
    install_development_tools
    install_additional_utilities
    
    setup_desktop_shortcuts
    optimize_for_rescue
    
    show_completion
}

main "$@"
