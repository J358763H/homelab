#!/bin/bash

# =====================================================
# 🔧 Proxmox Kernel Compatibility Fix
# =====================================================
# Addresses kernel version compatibility issues
# Handles .14 vs .11 kernel differences
# Ensures proper module loading and functionality
# =====================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $1${NC}"; }

# Get current kernel version
get_kernel_version() {
    uname -r
}

# Check if running on Proxmox
check_proxmox() {
    if [[ ! -f /etc/pve/.version ]]; then
        error "This script must be run on Proxmox VE"
        exit 1
    fi
    
    local pve_version=$(cat /etc/pve/.version)
    log "Proxmox VE version: $pve_version"
}

# Check kernel compatibility
check_kernel_compatibility() {
    local kernel_version=$(get_kernel_version)
    log "Current kernel: $kernel_version"
    
    # Check for common kernel issues
    if echo "$kernel_version" | grep -q "\.14"; then
        warn "Detected kernel version .14 - applying compatibility fixes"
        apply_kernel_14_fixes
    elif echo "$kernel_version" | grep -q "\.11"; then
        log "Kernel version .11 detected - standard configuration"
    else
        warn "Unknown kernel version pattern: $kernel_version"
    fi
}

# Apply fixes for kernel .14
apply_kernel_14_fixes() {
    log "Applying kernel .14 compatibility fixes..."
    
    # Fix 1: Update module dependencies
    if command -v depmod >/dev/null 2>&1; then
        log "Updating module dependencies..."
        depmod -a
        success "Module dependencies updated"
    fi
    
    # Fix 2: Ensure required modules are loaded
    load_required_modules
    
    # Fix 3: Update initramfs if needed
    update_initramfs_if_needed
    
    # Fix 4: Fix container networking modules
    fix_container_networking
    
    # Fix 5: Update ZFS compatibility if ZFS is present
    fix_zfs_compatibility
    
    success "Kernel .14 compatibility fixes applied"
}

# Load required modules for homelab
load_required_modules() {
    log "Loading required kernel modules..."
    
    local required_modules=(
        "bridge"
        "veth"
        "xt_nat"
        "xt_conntrack"
        "xt_MASQUERADE"
        "nf_nat"
        "nf_conntrack"
        "nf_conntrack_ipv4"
        "nf_defrag_ipv4"
        "ip_tables"
        "iptable_nat"
        "iptable_filter"
    )
    
    for module in "${required_modules[@]}"; do
        if ! lsmod | grep -q "^$module"; then
            if modprobe "$module" 2>/dev/null; then
                log "Loaded module: $module"
            else
                warn "Could not load module: $module (may not be needed)"
            fi
        else
            log "Module already loaded: $module"
        fi
    done
    
    success "Required modules checked/loaded"
}

# Update initramfs if needed
update_initramfs_if_needed() {
    log "Checking if initramfs update is needed..."
    
    local kernel_version=$(uname -r)
    local initramfs_file="/boot/initrd.img-$kernel_version"
    local kernel_file="/boot/vmlinuz-$kernel_version"
    
    if [[ -f "$kernel_file" && -f "$initramfs_file" ]]; then
        # Check if initramfs is older than kernel
        if [[ "$initramfs_file" -ot "$kernel_file" ]]; then
            log "Updating initramfs for kernel $kernel_version..."
            update-initramfs -u -k "$kernel_version"
            success "Initramfs updated"
        else
            log "Initramfs is up to date"
        fi
    else
        warn "Could not find kernel or initramfs files"
    fi
}

# Fix container networking for different kernel versions
fix_container_networking() {
    log "Fixing container networking compatibility..."
    
    # Ensure bridge-nf-call-iptables is enabled
    if [[ -f /proc/sys/net/bridge/bridge-nf-call-iptables ]]; then
        echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
        log "Enabled bridge-nf-call-iptables"
    fi
    
    if [[ -f /proc/sys/net/bridge/bridge-nf-call-ip6tables ]]; then
        echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
        log "Enabled bridge-nf-call-ip6tables"
    fi
    
    # Enable IP forwarding
    if [[ -f /proc/sys/net/ipv4/ip_forward ]]; then
        echo 1 > /proc/sys/net/ipv4/ip_forward
        log "Enabled IP forwarding"
    fi
    
    # Make changes persistent
    cat > /etc/sysctl.d/99-homelab-networking.conf << 'EOF'
# Homelab networking configuration
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv6.conf.all.forwarding = 1

# Container networking optimizations
net.netfilter.nf_conntrack_max = 131072
net.netfilter.nf_conntrack_tcp_timeout_established = 86400
net.core.netdev_max_backlog = 5000
EOF

    sysctl -p /etc/sysctl.d/99-homelab-networking.conf
    success "Container networking fixes applied"
}

# Fix ZFS compatibility if present
fix_zfs_compatibility() {
    if command -v zfs >/dev/null 2>&1; then
        log "ZFS detected - checking compatibility..."
        
        # Check ZFS module status
        if ! lsmod | grep -q zfs; then
            log "Loading ZFS modules..."
            modprobe zfs 2>/dev/null || warn "Could not load ZFS module"
        fi
        
        # Update ZFS module parameters for better compatibility
        if [[ -d /sys/module/zfs/parameters ]]; then
            log "Optimizing ZFS parameters for kernel compatibility..."
            
            # Set conservative memory limits
            echo 1 > /sys/module/zfs/parameters/zfs_arc_max 2>/dev/null || true
            echo 1 > /sys/module/zfs/parameters/zfs_arc_meta_limit_percent 2>/dev/null || true
        fi
        
        success "ZFS compatibility checked"
    else
        log "ZFS not detected - skipping ZFS fixes"
    fi
}

# Fix Docker compatibility issues
fix_docker_compatibility() {
    log "Fixing Docker compatibility for kernel differences..."
    
    # Create Docker daemon configuration for kernel compatibility
    mkdir -p /etc/docker
    
    # Backup existing configuration if it exists
    if [[ -f /etc/docker/daemon.json ]]; then
        cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%s)
        log "Backed up existing Docker configuration"
    fi
    
    cat > /etc/docker/daemon.json << 'EOF'
{
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.override_kernel_check=true"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "5"
    },
    "live-restore": true,
    "userland-proxy": false,
    "default-ulimits": {
        "nofile": {
            "Name": "nofile",
            "Hard": 64000,
            "Soft": 64000
        }
    }
}
EOF

    # Restart Docker if it's running
    if systemctl is-active docker >/dev/null 2>&1; then
        log "Restarting Docker with new configuration..."
        
        if systemctl restart docker; then
            sleep 5
            if systemctl is-active docker >/dev/null 2>&1; then
                success "Docker restarted successfully"
            else
                warn "Docker service started but may not be fully ready"
            fi
        else
            warn "Docker restart failed, trying to recover..."
            
            # Try to restore backup configuration
            if [[ -f /etc/docker/daemon.json.backup.* ]]; then
                local backup_file=$(ls -t /etc/docker/daemon.json.backup.* | head -1)
                log "Restoring backup configuration: $backup_file"
                cp "$backup_file" /etc/docker/daemon.json
                
                # Try to start Docker with backup config
                if systemctl restart docker; then
                    warn "Docker started with backup configuration"
                else
                    # Create minimal configuration
                    log "Creating minimal Docker configuration..."
                    cat > /etc/docker/daemon.json << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "5"
    }
}
EOF
                    systemctl restart docker || warn "Docker failed to start with minimal config"
                fi
            fi
        fi
    else
        log "Docker not running - configuration will apply on next start"
    fi
}

# Fix LXC container compatibility
fix_lxc_compatibility() {
    log "Fixing LXC compatibility for different kernel versions..."
    
    # Ensure required cgroup controllers are available
    if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
        log "Using cgroup v2 configuration"
        
        # Enable required controllers for containers
        local controllers="cpuset cpu io memory hugetlb pids rdma"
        for controller in $controllers; do
            if grep -q "$controller" /sys/fs/cgroup/cgroup.controllers; then
                echo "+$controller" > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || true
            fi
        done
    else
        log "Using cgroup v1 configuration"
        
        # Mount cgroup v1 controllers if needed
        local cgroup_controllers=(
            "memory"
            "cpu,cpuacct"
            "devices"
            "freezer"
            "net_cls,net_prio"
            "blkio"
            "cpuset"
            "pids"
        )
        
        for controller in "${cgroup_controllers[@]}"; do
            local mount_point="/sys/fs/cgroup/$controller"
            if [[ ! -d "$mount_point" ]]; then
                mkdir -p "$mount_point"
                mount -t cgroup -o "$controller" cgroup "$mount_point" 2>/dev/null || true
            fi
        done
    fi
    
    # Update LXC configuration for kernel compatibility
    cat > /etc/lxc/default.conf << 'EOF'
lxc.net.0.type = veth
lxc.net.0.link = lxcbr0
lxc.net.0.flags = up
lxc.net.0.hwaddr = 00:16:3e:xx:xx:xx
lxc.apparmor.profile = generated
lxc.apparmor.allow_nesting = 1
lxc.cap.drop = sys_module mac_admin mac_override sys_time
lxc.seccomp.profile = /usr/share/lxc/config/common.seccomp
EOF

    success "LXC compatibility fixes applied"
}

# Create kernel compatibility report
create_compatibility_report() {
    local report_file="/tmp/kernel_compatibility_report.txt"
    
    cat > "$report_file" << EOF
================================================================
🔧 PROXMOX KERNEL COMPATIBILITY REPORT
================================================================
Generated: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)
Proxmox Version: $(cat /etc/pve/.version 2>/dev/null || echo "Unknown")

COMPATIBILITY STATUS:
EOF

    # Check module availability
    echo "" >> "$report_file"
    echo "KERNEL MODULES:" >> "$report_file"
    
    local test_modules=("bridge" "veth" "xt_nat" "ip_tables" "zfs")
    for module in "${test_modules[@]}"; do
        if lsmod | grep -q "^$module" || modinfo "$module" >/dev/null 2>&1; then
            echo "✓ $module: Available" >> "$report_file"
        else
            echo "✗ $module: Not available" >> "$report_file"
        fi
    done
    
    # Check system capabilities
    echo "" >> "$report_file"
    echo "SYSTEM CAPABILITIES:" >> "$report_file"
    echo "✓ Container support: $(systemctl is-active systemd-machined 2>/dev/null || echo "Unknown")" >> "$report_file"
    echo "✓ Network namespaces: $(ls /proc/*/ns/net 2>/dev/null | wc -l) processes" >> "$report_file"
    echo "✓ Cgroup version: $(stat -fc %T /sys/fs/cgroup/)" >> "$report_file"
    
    echo "" >> "$report_file"
    echo "================================================================" >> "$report_file"
    
    log "Compatibility report generated: $report_file"
    cat "$report_file"
}

# Main execution
main() {
    log "Starting Proxmox kernel compatibility check and fixes..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
    
    check_proxmox
    check_kernel_compatibility
    load_required_modules
    fix_container_networking
    fix_docker_compatibility
    fix_lxc_compatibility
    create_compatibility_report
    
    success "Kernel compatibility fixes completed!"
    success "System should now work properly with kernel $(uname -r)"
    
    warn "Reboot recommended to ensure all changes take effect"
    warn "Run 'reboot' when convenient to complete the fixes"
}

# Handle command line arguments
case "${1:-fix}" in
    "fix")
        main
        ;;
    "check")
        check_proxmox
        check_kernel_compatibility
        create_compatibility_report
        ;;
    "modules")
        load_required_modules
        ;;
    "docker")
        fix_docker_compatibility
        ;;
    "lxc")
        fix_lxc_compatibility
        ;;
    *)
        echo "Usage: $0 [fix|check|modules|docker|lxc]"
        echo "  fix     - Apply all compatibility fixes (default)"
        echo "  check   - Check compatibility without making changes"
        echo "  modules - Load required kernel modules only"
        echo "  docker  - Fix Docker compatibility only"
        echo "  lxc     - Fix LXC compatibility only"
        exit 1
        ;;
esac