#!/bin/bash

# 🔧 Proxmox Single-Node Optimization Script
# Based on repository analysis feedback
# Addresses cluster filesystem timeout and performance issues

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[OPTIMIZE] $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Check if running on Proxmox
if ! grep -q "pve" /proc/version 2>/dev/null && [ ! -d "/etc/pve" ]; then
    error "This script must be run on a Proxmox VE host"
    exit 1
fi

log "🏥 Optimizing Proxmox single-node configuration..."

# 1. Fix cluster filesystem timeout
log "Applying cluster filesystem timeout fix..."
mkdir -p /etc/systemd/system/pve-cluster.service.d/
cat > /etc/systemd/system/pve-cluster.service.d/override.conf <<EOF
[Service]
TimeoutStopSec=15s
EOF

systemctl daemon-reload
success "Cluster filesystem timeout reduced to 15s"

# 2. Optimize pmxcfs for single node
log "Configuring pmxcfs for single-node operation..."
if [ -f /etc/default/pve-cluster ]; then
    # Add single-node optimizations
    if ! grep -q "DAEMON_OPTS" /etc/default/pve-cluster; then
        echo 'DAEMON_OPTS="-f"' >> /etc/default/pve-cluster
        success "Added single-node daemon options"
    fi
fi

# 3. Configure corosync for single node (if needed)
if [ -f /etc/pve/corosync.conf ]; then
    log "Checking corosync configuration..."
    if grep -q "two_node: 1" /etc/pve/corosync.conf; then
        success "Corosync already configured for single node"
    else
        warn "Consider reviewing corosync.conf for single-node optimization"
    fi
fi

# 4. Optimize systemd shutdown timeouts
log "Optimizing systemd shutdown timeouts..."
if [ -f /etc/systemd/system.conf ]; then
    # Create backup
    cp /etc/systemd/system.conf /etc/systemd/system.conf.backup

    # Update timeout settings
    sed -i 's/#DefaultTimeoutStopSec=90s/DefaultTimeoutStopSec=30s/' /etc/systemd/system.conf
    sed -i 's/#DefaultTimeoutStartSec=90s/DefaultTimeoutStartSec=30s/' /etc/systemd/system.conf

    systemctl daemon-reload
    success "Reduced systemd timeouts to 30s"
fi

# 5. Configure swap settings for better performance
log "Optimizing swap settings..."
if [ -f /proc/sys/vm/swappiness ]; then
    current_swappiness=$(cat /proc/sys/vm/swappiness)
    if [ "$current_swappiness" -gt 10 ]; then
        echo 'vm.swappiness=10' >> /etc/sysctl.conf
        echo 10 > /proc/sys/vm/swappiness
        success "Reduced swappiness to 10 (was $current_swappiness)"
    else
        success "Swappiness already optimized: $current_swappiness"
    fi
fi

# 6. Enable useful kernel modules for containerization
log "Loading essential kernel modules..."
modules=("overlay" "br_netfilter" "ip_tables" "iptable_nat" "xt_MASQUERADE")
loaded_modules=()

for module in "${modules[@]}"; do
    if modprobe "$module" 2>/dev/null; then
        loaded_modules+=("$module")
        # Make persistent
        if ! grep -q "^$module" /etc/modules; then
            echo "$module" >> /etc/modules
        fi
    fi
done

if [ ${#loaded_modules[@]} -gt 0 ]; then
    success "Loaded kernel modules: ${loaded_modules[*]}"
else
    warn "No additional kernel modules loaded"
fi

# 7. Optimize network bridge settings
log "Optimizing network bridge configuration..."
if [ -d /proc/sys/net/bridge ]; then
    # Disable netfilter on bridges for better performance
    echo 'net.bridge.bridge-nf-call-iptables = 0' >> /etc/sysctl.conf
    echo 'net.bridge.bridge-nf-call-ip6tables = 0' >> /etc/sysctl.conf
    sysctl -p
    success "Optimized bridge netfilter settings"
fi

# 8. Configure log rotation to prevent disk space issues
log "Configuring log rotation..."
if [ ! -f /etc/logrotate.d/pve-cluster ]; then
    cat > /etc/logrotate.d/pve-cluster <<EOF
/var/log/pve-cluster.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}
EOF
    success "Configured pve-cluster log rotation"
fi

# 9. Summary and recommendations
echo ""
log "🎉 Single-node optimization complete!"
echo ""
success "Applied optimizations:"
echo "  • Cluster filesystem timeout: 15s"
echo "  • Systemd timeouts: 30s"
echo "  • Swappiness: 10"
echo "  • Kernel modules loaded: ${#loaded_modules[@]}"
echo "  • Network bridge optimized"
echo "  • Log rotation configured"
echo ""
warn "Recommendations:"
echo "  • Reboot to ensure all changes take effect"
echo "  • Monitor logs: journalctl -f -u pve-cluster"
echo "  • Test shutdown time: time systemctl poweroff"
echo ""
log "Next steps: Run your Proxmox deployment scripts with improved performance!"
