#!/bin/bash
# =====================================================
# ☢️ PROXMOX NUCLEAR CLEANUP - GUARANTEED CLEAN SLATE
# =====================================================
# ⚠️ WARNING: THIS WILL DESTROY EVERYTHING! ⚠️
# Use this when you want a completely fresh start
# More thorough than reinstalling in most cases
# =====================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

header() {
    echo -e "${CYAN}$1${NC}"
}

critical() {
    echo -e "${PURPLE}[CRITICAL]${NC} $1"
}

# Nuclear warning banner
show_nuclear_warning() {
    clear
    echo -e "${RED}"
    echo "☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️"
    echo "☢️                                                      ☢️"
    echo "☢️                ⚠️ NUCLEAR CLEANUP ⚠️                 ☢️"
    echo "☢️                                                      ☢️"
    echo "☢️  THIS WILL COMPLETELY DESTROY YOUR PROXMOX SETUP!   ☢️"
    echo "☢️                                                      ☢️"
    echo "☢️  • ALL VMs AND LXC CONTAINERS                        ☢️"
    echo "☢️  • ALL STORAGE AND BACKUPS                           ☢️"
    echo "☢️  • ALL NETWORK CONFIGURATION                         ☢️"
    echo "☢️  • ALL USER DATA AND SETTINGS                        ☢️"
    echo "☢️  • EVERYTHING EXCEPT BASE PROXMOX INSTALL            ☢️"
    echo "☢️                                                      ☢️"
    echo "☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️☢️"
    echo -e "${NC}"
    echo ""
    echo -e "${YELLOW}This script provides a more thorough cleanup than:"
    echo "• Fresh OS installation (preserves hardware optimization)"
    echo "• Manual cleanup (catches everything you might miss)"
    echo "• Standard reset scripts (goes deeper into system state)"
    echo -e "${NC}"
    echo ""
}

# Check if running on Proxmox
check_proxmox_host() {
    if [[ ! -f /etc/pve/version ]]; then
        error "This script must be run on a Proxmox VE host!"
        error "If you want to clean a regular Linux system, use a different cleanup script."
        exit 1
    fi

    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root!"
        error "Run: sudo $0"
        exit 1
    fi

    log "✅ Running on Proxmox VE as root"
}

# Get final confirmation
get_nuclear_confirmation() {
    echo -e "${RED}To proceed with NUCLEAR CLEANUP, you must:"
    echo "1. Type exactly: I UNDERSTAND THE RISKS"
    echo "2. Then type: NUKE EVERYTHING"
    echo -e "${NC}"
    echo ""

    read -p "Step 1 - Type 'I UNDERSTAND THE RISKS': " confirmation1
    if [[ "$confirmation1" != "I UNDERSTAND THE RISKS" ]]; then
        echo "❌ Confirmation failed. Exiting for safety."
        exit 1
    fi

    read -p "Step 2 - Type 'NUKE EVERYTHING': " confirmation2
    if [[ "$confirmation2" != "NUKE EVERYTHING" ]]; then
        echo "❌ Confirmation failed. Exiting for safety."
        exit 1
    fi

    echo ""
    critical "🚨 FINAL WARNING: Starting nuclear cleanup in 10 seconds..."
    critical "🚨 Press Ctrl+C NOW if you changed your mind!"

    for i in {10..1}; do
        echo -ne "\r${RED}💣 Detonation in $i seconds... ${NC}"
        sleep 1
    done
    echo ""
    echo -e "${RED}💥 NUCLEAR CLEANUP INITIATED! 💥${NC}"
    echo ""
}

# Stop all VMs and containers
stop_all_services() {
    header "🛑 STOPPING ALL RUNNING SERVICES"

    log "Stopping all running VMs..."
    for vmid in $(qm list | awk 'NR>1 {print $1}'); do
        if qm status $vmid | grep -q "running"; then
            log "Stopping VM $vmid..."
            qm stop $vmid --timeout 30 || qm stop $vmid --skiplock || true
        fi
    done

    log "Stopping all running LXC containers..."
    for ctid in $(pct list | awk 'NR>1 {print $1}'); do
        if pct status $ctid | grep -q "running"; then
            log "Stopping container $ctid..."
            pct stop $ctid --timeout 30 || pct stop $ctid --force || true
        fi
    done

    success "All services stopped"
}

# Destroy all VMs and containers
destroy_all_guests() {
    header "💥 DESTROYING ALL VMs AND CONTAINERS"

    # Destroy all VMs
    log "Destroying all VMs..."
    for vmid in $(qm list | awk 'NR>1 {print $1}'); do
        log "Destroying VM $vmid..."
        qm destroy $vmid --purge --skiplock || true
    done

    # Destroy all LXC containers
    log "Destroying all LXC containers..."
    for ctid in $(pct list | awk 'NR>1 {print $1}'); do
        log "Destroying container $ctid..."
        pct destroy $ctid --purge || true
    done

    success "All guests destroyed"
}

# Clean storage completely
nuclear_storage_cleanup() {
    header "🗂️ NUCLEAR STORAGE CLEANUP"

    # Remove all VM disks from local storage
    log "Cleaning local VM storage..."
    rm -rf /var/lib/vz/images/* 2>/dev/null || true
    rm -rf /var/lib/vz/dump/* 2>/dev/null || true
    rm -rf /var/lib/vz/template/* 2>/dev/null || true

    # Clean ZFS pools if they exist
    if command -v zfs >/dev/null 2>&1; then
        log "Cleaning ZFS datasets..."
        for dataset in $(zfs list -H -o name | grep -E "(vm-|subvol-)" 2>/dev/null || true); do
            log "Destroying ZFS dataset: $dataset"
            zfs destroy -r "$dataset" 2>/dev/null || true
        done
    fi

    # Clean LVM volumes
    if command -v lvs >/dev/null 2>&1; then
        log "Cleaning LVM volumes..."
        for lv in $(lvs --noheadings -o lv_path | grep -E "(vm-|data)" 2>/dev/null || true); do
            log "Removing LV: $lv"
            lvremove -f "$lv" 2>/dev/null || true
        done
    fi

    # Remove backup files
    log "Removing all backups..."
    find /var/lib/vz/dump -name "*.tar*" -delete 2>/dev/null || true
    find /var/lib/vz/dump -name "*.vma*" -delete 2>/dev/null || true

    success "Storage nuked"
}

# Reset network configuration
reset_networking() {
    header "🌐 RESETTING NETWORK CONFIGURATION"

    # Backup current network config
    cp /etc/network/interfaces /etc/network/interfaces.nuclear-backup || true

    # Remove all bridge configurations
    log "Removing virtual bridges..."
    for bridge in $(ip link show | grep "vmbr" | cut -d: -f2 | cut -d' ' -f2 || true); do
        log "Removing bridge: $bridge"
        ip link delete "$bridge" 2>/dev/null || true
    done

    # Reset to basic network configuration
    log "Resetting to basic network configuration..."
    cat > /etc/network/interfaces << 'EOF'
# Nuclear cleanup - basic configuration
# Edit this file to configure your network

auto lo
iface lo inet loopback

# Primary network interface
# Configure your main network interface here
# Example:
# auto eth0
# iface eth0 inet dhcp

# Management bridge (add your configuration)
# auto vmbr0
# iface vmbr0 inet dhcp
#     bridge-ports eth0
#     bridge-stp off
#     bridge-fd 0
EOF

    success "Network configuration reset (requires reboot to take effect)"
}

# Clean user configurations
clean_user_configs() {
    header "👥 CLEANING USER CONFIGURATIONS"

    # Reset user.cfg (keeps root and pam users)
    log "Resetting user configuration..."
    cp /etc/pve/user.cfg /etc/pve/user.cfg.nuclear-backup || true
    echo "# User configuration reset by nuclear cleanup" > /etc/pve/user.cfg

    # Clean ceph configuration if it exists
    if [[ -f /etc/ceph/ceph.conf ]]; then
        log "Removing Ceph configuration..."
        rm -rf /etc/ceph/* || true
    fi

    # Remove custom certificates
    log "Cleaning certificates..."
    rm -f /etc/pve/nodes/*/pve-ssl.pem || true
    rm -f /etc/pve/nodes/*/pve-ssl.key || true

    success "User configurations cleaned"
}

# Clean system caches and logs
system_deep_clean() {
    header "🧹 DEEP SYSTEM CLEANING"

    # Clean logs
    log "Cleaning system logs..."
    journalctl --vacuum-time=1d || true
    rm -rf /var/log/pve-firewall.log* || true
    rm -rf /var/log/pveproxy/* || true

    # Clean caches
    log "Cleaning package caches..."
    apt-get clean || true
    apt-get autoremove -y || true

    # Clean temporary files
    log "Cleaning temporary files..."
    rm -rf /tmp/* || true
    rm -rf /var/tmp/* || true

    # Clear bash history
    log "Clearing command history..."
    true > ~/.bash_history || true
    history -c || true

    success "System deep cleaned"
}

# Restart essential services
restart_services() {
    header "🔄 RESTARTING ESSENTIAL SERVICES"

    log "Restarting Proxmox services..."
    systemctl restart pvedaemon || true
    systemctl restart pveproxy || true
    systemctl restart pvestatd || true
    systemctl restart pvescheduler || true

    success "Services restarted"
}

# Show completion summary
show_completion_summary() {
    clear
    success "☢️ NUCLEAR CLEANUP COMPLETED! ☢️"
    echo ""
    echo -e "${GREEN}✅ What was destroyed:"
    echo "  • All VMs and LXC containers"
    echo "  • All virtual disks and storage"
    echo "  • All backups and templates"
    echo "  • Network bridge configurations"
    echo "  • User settings and certificates"
    echo "  • System logs and caches"
    echo -e "${NC}"
    echo ""
    echo -e "${YELLOW}⚠️ What you need to do next:"
    echo "  1. REBOOT the Proxmox server"
    echo "  2. Configure network interfaces (/etc/network/interfaces)"
    echo "  3. Access web interface and set up storage"
    echo "  4. Deploy your homelab services fresh"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}💡 Backup files created:"
    echo "  • /etc/network/interfaces.nuclear-backup"
    echo "  • /etc/pve/user.cfg.nuclear-backup"
    echo -e "${NC}"
    echo ""
    echo -e "${RED}🚨 REBOOT REQUIRED: Run 'reboot' when ready${NC}"
}

# Main execution
main() {
    show_nuclear_warning
    check_proxmox_host
    get_nuclear_confirmation

    stop_all_services
    destroy_all_guests
    nuclear_storage_cleanup
    reset_networking
    clean_user_configs
    system_deep_clean
    restart_services

    show_completion_summary
}

# Execute main function
main "$@"
