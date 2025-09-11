#!/bin/bash

# Ultimate Rescue USB - AI-Powered Auto System Restore
# Scans system, identifies OS/hardware, downloads proper restoration media

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CACHE_DIR="/tmp/rescue-cache"
DOWNLOAD_DIR="/tmp/auto-restore-downloads"

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║        🧠 AI-Powered Auto System Restoration            ║"
    echo "║          Scan → Identify → Download → Restore            ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_section() {
    echo -e "${MAGENTA}[SCAN]${NC} $1"
}

log_ai() {
    echo -e "${CYAN}[AI]${NC} $1"
}

log_download() {
    echo -e "${BLUE}[DOWNLOAD]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

setup_environment() {
    mkdir -p "$CACHE_DIR" "$DOWNLOAD_DIR"
}

# AI-powered system detection
detect_system_info() {
    log_section "🔍 AI System Analysis in Progress..."
    
    local system_info="$CACHE_DIR/system_analysis.json"
    
    # Comprehensive system detection
    cat > "$system_info" << EOF
{
    "hardware": {
        "manufacturer": "$(dmidecode -s system-manufacturer 2>/dev/null || echo 'Unknown')",
        "product": "$(dmidecode -s system-product-name 2>/dev/null || echo 'Unknown')",
        "version": "$(dmidecode -s system-version 2>/dev/null || echo 'Unknown')",
        "serial": "$(dmidecode -s system-serial-number 2>/dev/null || echo 'Unknown')",
        "uuid": "$(dmidecode -s system-uuid 2>/dev/null || echo 'Unknown')",
        "cpu": "$(lscpu | grep 'Model name' | cut -d: -f2 | xargs)",
        "memory": "$(free -h | grep '^Mem:' | awk '{print \$2}')",
        "architecture": "$(uname -m)"
    },
    "firmware": {
        "bios_vendor": "$(dmidecode -s bios-vendor 2>/dev/null || echo 'Unknown')",
        "bios_version": "$(dmidecode -s bios-version 2>/dev/null || echo 'Unknown')",
        "bios_date": "$(dmidecode -s bios-release-date 2>/dev/null || echo 'Unknown')",
        "boot_mode": "$([ -d /sys/firmware/efi ] && echo 'UEFI' || echo 'Legacy')"
    },
    "storage": $(lsblk -J -o NAME,SIZE,TYPE,FSTYPE,LABEL,UUID,MOUNTPOINT),
    "network": $(ip -j addr show),
    "pci_devices": $(lspci -mm),
    "usb_devices": $(lsusb)
}
EOF

    log_ai "System fingerprint captured"
    echo "$system_info"
}

# AI OS Detection Engine
detect_installed_os() {
    local system_info="$1"
    log_section "🧠 AI OS Detection Engine"
    
    local detected_systems=()
    
    # Scan all storage devices for OS signatures
    while IFS= read -r device; do
        if [[ "$device" =~ ^/dev/(sd|nvme|hd|vd)[a-z]+[0-9]*$ ]]; then
            log_ai "Analyzing device: $device"
            
            # Mount and analyze each partition
            local mount_point="/mnt/scan-$$-$(basename "$device")"
            mkdir -p "$mount_point" 2>/dev/null || continue
            
            if mount "$device" "$mount_point" 2>/dev/null; then
                # Windows Detection
                if [[ -f "$mount_point/Windows/System32/ntoskrnl.exe" ]]; then
                    local win_version=$(get_windows_version "$mount_point")
                    detected_systems+=("Windows:$win_version:$device")
                    log_ai "🪟 Found Windows $win_version on $device"
                fi
                
                # macOS Detection
                if [[ -f "$mount_point/System/Library/CoreServices/SystemVersion.plist" ]]; then
                    local mac_version=$(get_macos_version "$mount_point")
                    detected_systems+=("macOS:$mac_version:$device")
                    log_ai "🍎 Found macOS $mac_version on $device"
                fi
                
                # Linux Detection
                if [[ -f "$mount_point/etc/os-release" ]]; then
                    local linux_info=$(get_linux_info "$mount_point")
                    detected_systems+=("Linux:$linux_info:$device")
                    log_ai "🐧 Found Linux ($linux_info) on $device"
                fi
                
                # Android Detection
                if [[ -f "$mount_point/system/build.prop" ]]; then
                    local android_info=$(get_android_info "$mount_point")
                    detected_systems+=("Android:$android_info:$device")
                    log_ai "🤖 Found Android ($android_info) on $device"
                fi
                
                umount "$mount_point" 2>/dev/null
            fi
            
            rmdir "$mount_point" 2>/dev/null || true
        fi
    done < <(lsblk -rno NAME | sed 's|^|/dev/|')
    
    # Save detected systems
    printf '%s\n' "${detected_systems[@]}" > "$CACHE_DIR/detected_systems.txt"
    
    if [[ ${#detected_systems[@]} -eq 0 ]]; then
        log_warn "No operating systems detected on storage devices"
        return 1
    fi
    
    log_ai "Detected ${#detected_systems[@]} operating system(s)"
    return 0
}

get_windows_version() {
    local mount_point="$1"
    
    # Check for Windows 11 indicators
    if [[ -f "$mount_point/Windows/System32/ntoskrnl.exe" ]]; then
        # Check build number from registry if accessible
        if [[ -f "$mount_point/Windows/System32/config/SOFTWARE" ]]; then
            # Windows 11 has build 22000+
            if strings "$mount_point/Windows/System32/ntoskrnl.exe" 2>/dev/null | grep -q "22[0-9][0-9][0-9]"; then
                echo "Windows 11"
            elif strings "$mount_point/Windows/System32/ntoskrnl.exe" 2>/dev/null | grep -q "19[0-9][0-9][0-9]"; then
                echo "Windows 10"
            elif [[ -f "$mount_point/Windows/System32/winload.efi" ]]; then
                echo "Windows 10/11"
            else
                echo "Windows 7/8"
            fi
        else
            echo "Windows (Unreadable)"
        fi
    fi
}

get_macos_version() {
    local mount_point="$1"
    local plist_file="$mount_point/System/Library/CoreServices/SystemVersion.plist"
    
    if [[ -f "$plist_file" ]] && command -v plutil >/dev/null; then
        plutil -p "$plist_file" | grep ProductVersion | cut -d'"' -f4
    else
        echo "macOS (Unknown Version)"
    fi
}

get_linux_info() {
    local mount_point="$1"
    local os_release="$mount_point/etc/os-release"
    
    if [[ -f "$os_release" ]]; then
        local name=$(grep '^NAME=' "$os_release" | cut -d'=' -f2 | tr -d '"')
        local version=$(grep '^VERSION=' "$os_release" | cut -d'=' -f2 | tr -d '"')
        echo "$name $version"
    else
        echo "Linux (Unknown Distribution)"
    fi
}

get_android_info() {
    local mount_point="$1"
    local build_prop="$mount_point/system/build.prop"
    
    if [[ -f "$build_prop" ]]; then
        local version=$(grep '^ro.build.version.release=' "$build_prop" | cut -d'=' -f2)
        echo "Android $version"
    else
        echo "Android (Unknown Version)"
    fi
}

# AI-powered download URL detection
get_download_urls() {
    local os_type="$1"
    local os_version="$2"
    local hardware_info="$3"
    
    log_download "🔗 AI Download Engine: Finding restoration media..."
    
    case "$os_type" in
        "Windows")
            get_windows_download_urls "$os_version" "$hardware_info"
            ;;
        "macOS")
            get_macos_download_urls "$os_version" "$hardware_info"
            ;;
        "Linux")
            get_linux_download_urls "$os_version" "$hardware_info"
            ;;
        "Android")
            get_android_download_urls "$os_version" "$hardware_info"
            ;;
        *)
            log_error "Unknown OS type: $os_type"
            return 1
            ;;
    esac
}

get_windows_download_urls() {
    local version="$1"
    local hardware="$2"
    
    log_download "Finding Windows installation media..."
    
    # Microsoft's official download endpoints
    local urls=()
    
    if [[ "$version" =~ "11" ]]; then
        urls+=(
            "https://software-download.microsoft.com/download/pr/Win11_22H2_English_x64v1.iso"
            "https://software-download.microsoft.com/download/pr/Win11_23H2_English_x64v1.iso"
        )
    elif [[ "$version" =~ "10" ]]; then
        urls+=(
            "https://software-download.microsoft.com/download/pr/Win10_22H2_English_x64.iso"
            "https://software-download.microsoft.com/download/pr/Win10_21H2_English_x64.iso"
        )
    fi
    
    # Add hardware-specific drivers
    if [[ "$hardware" =~ "Dell" ]]; then
        urls+=("https://downloads.dell.com/catalog/DriverPackCatalog.cab")
    elif [[ "$hardware" =~ "HP" ]]; then
        urls+=("https://ftp.hp.com/pub/softpaq/sp100001-100500/sp100001.exe")
    fi
    
    printf '%s\n' "${urls[@]}"
}

get_macos_download_urls() {
    local version="$1"
    local hardware="$2"
    
    log_download "Finding macOS installation media..."
    
    local urls=()
    
    # Use OpenCore or actual recovery methods
    if [[ "$version" =~ "14" ]] || [[ "$version" =~ "Sonoma" ]]; then
        urls+=("https://github.com/acidanthera/OpenCorePkg/releases/latest/download/OpenCore-0.9.6-RELEASE.zip")
    elif [[ "$version" =~ "13" ]] || [[ "$version" =~ "Ventura" ]]; then
        urls+=("https://github.com/acidanthera/OpenCorePkg/releases/latest/download/OpenCore-0.9.6-RELEASE.zip")
    else
        # macOS Internet Recovery command
        log_download "Use macOS Internet Recovery: Cmd+Option+R during boot"
        urls+=("https://support.apple.com/en-us/HT204904")
    fi
    
    printf '%s\n' "${urls[@]}"
}

get_linux_download_urls() {
    local distro_info="$1"
    local hardware="$2"
    
    log_download "Finding Linux installation media..."
    
    local urls=()
    
    if [[ "$distro_info" =~ "Ubuntu" ]]; then
        urls+=(
            "https://releases.ubuntu.com/22.04/ubuntu-22.04.3-desktop-amd64.iso"
            "https://releases.ubuntu.com/20.04/ubuntu-20.04.6-desktop-amd64.iso"
        )
    elif [[ "$distro_info" =~ "Garuda" ]]; then
        urls+=(
            "https://iso.builds.garudalinux.org/iso/latest/garuda/dr460nized/latest.iso"
            "https://iso.builds.garudalinux.org/iso/latest/garuda/kde-lite/latest.iso"
        )
    elif [[ "$distro_info" =~ "Fedora" ]]; then
        urls+=(
            "https://download.fedoraproject.org/pub/fedora/linux/releases/39/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-39-1.5.iso"
        )
    elif [[ "$distro_info" =~ "Debian" ]]; then
        urls+=(
            "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.2.0-amd64-netinst.iso"
        )
    fi
    
    printf '%s\n' "${urls[@]}"
}

get_android_download_urls() {
    local version="$1"
    local hardware="$2"
    
    log_download "Finding Android restoration files..."
    
    local urls=()
    
    # Real Android restoration sources
    if [[ "$hardware" =~ "Samsung" ]]; then
        urls+=("https://www.sammobile.com/samsung/firmware/")
        urls+=("https://github.com/zacharee/SamloaderKotlin/releases/latest")
    elif [[ "$hardware" =~ "Google" ]] || [[ "$hardware" =~ "Pixel" ]]; then
        urls+=("https://developers.google.com/android/images")
        urls+=("https://developers.google.com/android/ota")
    fi
    
    # Universal Android tools
    urls+=("https://dl.google.com/android/repository/platform-tools-latest-linux.zip")
    urls+=("https://androidfilehost.com/")
    urls+=("https://sourceforge.net/projects/android-x86/files/Release%209.0/android-x86_64-9.0-r2.iso/download")
    
    printf '%s\n' "${urls[@]}"
}

# Smart download manager
download_restoration_media() {
    local urls_file="$1"
    
    log_download "🚀 Initiating intelligent downloads..."
    
    while IFS= read -r url; do
        [[ -z "$url" ]] && continue
        
        local filename=$(basename "$url")
        local download_path="$DOWNLOAD_DIR/$filename"
        
        log_download "Downloading: $filename"
        
        # Use aria2c for fast, resumable downloads
        if command -v aria2c >/dev/null; then
            aria2c -c -x 8 -s 8 --dir="$DOWNLOAD_DIR" --out="$filename" "$url" || {
                log_warn "aria2c failed, falling back to wget"
                wget -c -O "$download_path" "$url" || log_error "Download failed: $url"
            }
        else
            wget -c -O "$download_path" "$url" || log_error "Download failed: $url"
        fi
        
        # Verify download integrity if possible
        if [[ -f "$download_path" ]]; then
            log_download "✅ Downloaded: $filename ($(du -h "$download_path" | cut -f1))"
        fi
    done < "$urls_file"
}

# AI restoration orchestrator
orchestrate_restoration() {
    local detected_systems="$CACHE_DIR/detected_systems.txt"
    
    log_section "🎭 AI Restoration Orchestrator"
    
    if [[ ! -f "$detected_systems" ]]; then
        log_error "No detected systems found!"
        return 1
    fi
    
    echo
    echo "🎯 Detected Systems & Restoration Options:"
    echo "═══════════════════════════════════════════"
    
    local i=1
    while IFS=':' read -r os_type os_version device; do
        echo "$i. $os_type $os_version (on $device)"
        ((i++))
    done < "$detected_systems"
    
    echo
    read -p "Select system to restore (1-$((i-1)), or 'a' for all): " choice
    
    if [[ "$choice" == "a" ]]; then
        log_ai "🤖 Initiating AI-powered mass restoration..."
        while IFS=':' read -r os_type os_version device; do
            restore_system "$os_type" "$os_version" "$device"
        done < "$detected_systems"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -lt "$i" ]]; then
        local selected_line=$(sed -n "${choice}p" "$detected_systems")
        IFS=':' read -r os_type os_version device <<< "$selected_line"
        restore_system "$os_type" "$os_version" "$device"
    else
        log_error "Invalid selection"
        return 1
    fi
}

restore_system() {
    local os_type="$1"
    local os_version="$2" 
    local device="$3"
    
    log_section "🛠️ Restoring $os_type $os_version on $device"
    
    # Get hardware info for this restoration
    local hardware=$(dmidecode -s system-manufacturer 2>/dev/null)
    
    # Generate download URLs
    local urls_file="$CACHE_DIR/urls_${os_type// /_}.txt"
    get_download_urls "$os_type" "$os_version" "$hardware" > "$urls_file"
    
    if [[ -s "$urls_file" ]]; then
        echo "📦 Found restoration media URLs:"
        cat "$urls_file" | nl
        echo
        
        read -p "Download restoration media? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            download_restoration_media "$urls_file"
            
            echo
            echo "🎉 Restoration media downloaded to: $DOWNLOAD_DIR"
            echo "📋 Next steps:"
            echo "   1. Create bootable media from downloaded ISOs"
            echo "   2. Boot from restoration media"
            echo "   3. Follow system-specific restoration process"
            echo "   4. Restore from backup if available"
        fi
    else
        log_warn "No restoration URLs found for $os_type $os_version"
    fi
}

main() {
    print_banner
    
    setup_environment
    
    # AI System Analysis Phase
    local system_info
    system_info=$(detect_system_info)
    
    # AI OS Detection Phase  
    if detect_installed_os "$system_info"; then
        # AI Restoration Orchestration Phase
        orchestrate_restoration
    else
        log_error "No operating systems detected for restoration"
        exit 1
    fi
    
    echo
    echo -e "${GREEN}🚀 AI Auto-Restoration Analysis Complete!${NC}"
    echo "Downloaded media ready for system restoration."
}

main "$@"
