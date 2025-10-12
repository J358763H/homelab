#!/bin/bash

# =====================================================
# 🔒 Tailscale LXC Setup Script
# =====================================================
# Creates and configures Tailscale subnet router
# =====================================================

set -euo pipefail

# Configuration
CTID="${1:-202}"
HOSTNAME="tailscale-homelab"
MEMORY="512"
SWAP="256"
CORES="1" 
STORAGE="2"
TEMPLATE="local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"

# Network configuration (adjust for your environment)
BRIDGE="vmbr0"
IP="192.168.1.202"
NETMASK="24"
GATEWAY="192.168.1.1"
NAMESERVER="192.168.1.1"
SUBNET_ROUTE="192.168.1.0/24"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (on Proxmox host)"
fi

# Check if container ID already exists
if pct status $CTID >/dev/null 2>&1; then
    warn "Container $CTID already exists!"
    read -p "Do you want to destroy and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Stopping and destroying container $CTID..."
        pct stop $CTID 2>/dev/null || true
        pct destroy $CTID
    else
        error "Aborted. Choose a different container ID."
    fi
fi

# Prompt for Tailscale auth key
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Tailscale Auth Key Required${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "Visit: ${GREEN}https://login.tailscale.com/admin/settings/keys${NC}"
echo -e "Create a reusable, preauthorized key with tag: ${GREEN}homelab-router${NC}"
echo
read -p "Enter your Tailscale auth key: " -r AUTH_KEY

if [[ -z "$AUTH_KEY" ]]; then
    error "Auth key is required!"
fi

log "Creating Tailscale LXC container..."

# Create LXC container (privileged for routing)
pct create $CTID $TEMPLATE \
    --hostname $HOSTNAME \
    --memory $MEMORY \
    --swap $SWAP \
    --cores $CORES \
    --rootfs local-lvm:$STORAGE \
    --net0 name=eth0,bridge=$BRIDGE,ip=$IP/$NETMASK,gw=$GATEWAY \
    --nameserver $NAMESERVER \
    --features nesting=1 \
    --unprivileged 0 \
    --onboot 1

log "Starting container..."
pct start $CTID

# Wait for container to be ready
log "Waiting for container to be ready..."
sleep 10

# Configure container
log "Configuring container..."
pct exec $CTID -- bash -c "
    # Update system
    apt update && apt upgrade -y
    
    # Install required packages
    apt install -y curl wget git nano htop iptables-persistent

    # Install Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh
    
    # Enable IP forwarding
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
    echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf
    sysctl -p
    
    # Configure iptables for forwarding
    iptables -A FORWARD -i tailscale0 -j ACCEPT
    iptables -A FORWARD -o tailscale0 -j ACCEPT
    iptables-save > /etc/iptables/rules.v4
    
    # Start and authenticate Tailscale
    systemctl enable tailscaled
    systemctl start tailscaled
    
    # Connect to Tailscale with enhanced privacy settings
    tailscale up --authkey=$AUTH_KEY \
        --advertise-routes=$SUBNET_ROUTE \
        --ssh \
        --accept-dns=false \
        --accept-routes=false \
        --shields-up \
        --netfilter-mode=on \
        --hostname=$HOSTNAME
    
    # Additional privacy configurations
    sleep 5
    tailscale set --accept-dns=false
    tailscale set --shields-up=true
        
    # Wait for connection
    sleep 10
"

# Verify installation
log "Verifying Tailscale connection..."
if pct exec $CTID -- tailscale status | grep -q "logged in"; then
    log "✅ Tailscale is connected successfully!"
else
    warn "⚠️  Tailscale connection may need manual verification"
fi

# Get Tailscale status
TAILSCALE_STATUS=$(pct exec $CTID -- tailscale status 2>/dev/null || echo "Status unavailable")
TAILSCALE_IP=$(echo "$TAILSCALE_STATUS" | grep "$HOSTNAME" | awk '{print $1}' || echo "IP unavailable")

# Display access information
log "🎉 Setup complete!"
echo
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Tailscale Access Information${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "Container IP:  ${GREEN}$IP${NC}"
echo -e "Tailscale IP:  ${GREEN}$TAILSCALE_IP${NC}"
echo -e "Subnet Route:  ${GREEN}$SUBNET_ROUTE${NC}"
echo
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "1. ${GREEN}Approve subnet routes${NC} in Tailscale admin console:"
echo -e "   https://login.tailscale.com/admin/machines"
echo -e "2. ${GREEN}Install Tailscale${NC} on your devices"
echo -e "3. ${GREEN}Access homelab services${NC} via $SUBNET_ROUTE network"
echo
echo -e "${BLUE}Access Examples:${NC}"
echo -e "NPM Admin:     ${GREEN}http://192.168.1.201:81${NC}"
echo -e "Docker Host:   ${GREEN}http://192.168.1.100:8096${NC} (Jellyfin)"
echo -e "SSH to host:   ${GREEN}ssh user@192.168.1.100${NC}"
echo
echo -e "${BLUE}Container Commands:${NC}"
echo -e "Enter container:   ${GREEN}pct enter $CTID${NC}"
echo -e "Tailscale status:  ${GREEN}pct exec $CTID -- tailscale status${NC}"
echo -e "View routes:       ${GREEN}pct exec $CTID -- ip route show${NC}"
echo -e "Check forwarding:  ${GREEN}pct exec $CTID -- cat /proc/sys/net/ipv4/ip_forward${NC}"
echo
echo -e "${RED}⚠️  Important:${NC}"
echo -e "• Approve subnet routes in Tailscale admin console"
echo -e "• Container runs privileged for routing capabilities"
echo -e "• Monitor network access and logs regularly"
echo -e "${BLUE}================================${NC}"

# Display current Tailscale status
if [[ "$TAILSCALE_STATUS" != "Status unavailable" ]]; then
    echo
    echo -e "${BLUE}Current Tailscale Status:${NC}"
    echo "$TAILSCALE_STATUS"
fi

log "Tailscale LXC setup completed successfully!"