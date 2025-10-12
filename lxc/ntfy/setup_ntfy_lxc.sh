#!/bin/bash

# =====================================================
# 📦 Ntfy LXC Container Setup Script
# =====================================================
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-11
# 
# Sets up a dedicated LXC container for Ntfy notifications
# Run this on your Proxmox host or LXC-capable system
# =====================================================

set -euo pipefail

# =================
# Configuration
# =================
CONTAINER_ID=${1:-200}
CONTAINER_NAME="ntfy-server"
TEMPLATE="ubuntu-22.04-standard_22.04-1_amd64.tar.xz"
STORAGE="local-lvm"
MEMORY=512
SWAP=512
DISK_SIZE=2
CORES=1
BRIDGE="vmbr0"
IP_ADDRESS="192.168.1.200/24"  # Adjust to your network
GATEWAY="192.168.1.1"          # Adjust to your gateway
NAMESERVER="1.1.1.1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =================
# Helper Functions
# =================
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

# =================
# Validation
# =================
if ! command -v pct >/dev/null 2>&1; then
    error "This script must be run on a Proxmox host with 'pct' command available"
fi

if pct list | grep -q "^$CONTAINER_ID"; then
    error "Container ID $CONTAINER_ID already exists. Please choose a different ID or remove the existing container."
fi

# =================
# Create LXC Container
# =================
log "Creating LXC container for Ntfy..."

pct create $CONTAINER_ID /var/lib/vz/template/cache/$TEMPLATE \
    --hostname $CONTAINER_NAME \
    --memory $MEMORY \
    --swap $SWAP \
    --cores $CORES \
    --net0 name=eth0,bridge=$BRIDGE,ip=$IP_ADDRESS,gw=$GATEWAY \
    --storage $STORAGE \
    --rootfs $STORAGE:$DISK_SIZE \
    --unprivileged 1 \
    --onboot 1 \
    --start 0

log "Container created successfully with ID: $CONTAINER_ID"

# =================
# Start Container
# =================
log "Starting container..."
pct start $CONTAINER_ID

# Wait for container to be ready
log "Waiting for container to initialize..."
sleep 10

# =================
# Install Ntfy
# =================
log "Installing Ntfy server..."

pct exec $CONTAINER_ID -- bash -c "
    # Update system
    apt update && apt upgrade -y
    
    # Install prerequisites
    apt install -y curl gnupg2 software-properties-common apt-transport-https
    
    # Add Ntfy repository (new secure method)
    mkdir -p /etc/apt/keyrings
    curl -L -o /etc/apt/keyrings/ntfy.gpg https://archive.ntfy.sh/apt/keyring.gpg
    echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/ntfy.gpg] https://archive.ntfy.sh/apt stable main' > /etc/apt/sources.list.d/ntfy.list
    
    # Install Ntfy
    apt update
    apt install -y ntfy
    
    # Enable and start service
    systemctl enable ntfy
    systemctl start ntfy
    
    # Create config directory
    mkdir -p /etc/ntfy
"

# =================
# Configure Ntfy
# =================
log "Configuring Ntfy server..."

# Create Ntfy configuration
cat > /tmp/server.yml << 'EOF'
# Ntfy server configuration
# Documentation: https://docs.ntfy.sh/config/

# Server settings
base-url: "http://IP_PLACEHOLDER"
listen-http: ":80"
cache-file: "/var/cache/ntfy/cache.db"
cache-duration: "12h"
auth-file: "/var/lib/ntfy/auth.db"
auth-default-access: "deny-all"
attachment-cache-dir: "/var/cache/ntfy/attachments"
keepalive-interval: "45s"
manager-interval: "1m"

# Logging
log-level: "INFO"
log-format: "text"

# Rate limiting (adjust as needed)
visitor-request-limit-burst: 60
visitor-request-limit-replenish: "10s"
visitor-email-limit-burst: 16
visitor-email-limit-replenish: "1h"

# Message limits
message-limit: 4096
title-limit: 256

# Enable web UI
enable-web-ui: true

# Security headers
enable-cors: true
EOF

# Replace IP placeholder with actual IP
IP_ONLY=$(echo $IP_ADDRESS | cut -d'/' -f1)
sed "s/IP_PLACEHOLDER/$IP_ONLY/g" /tmp/server.yml > /tmp/server_final.yml

# Copy config to container
pct push $CONTAINER_ID /tmp/server_final.yml /etc/ntfy/server.yml

# Set proper permissions and restart
pct exec $CONTAINER_ID -- bash -c "
    chown ntfy:ntfy /etc/ntfy/server.yml
    chmod 640 /etc/ntfy/server.yml
    systemctl restart ntfy
    systemctl status ntfy --no-pager
"

# Cleanup temp files
rm /tmp/server.yml /tmp/server_final.yml

# =================
# Create Admin User
# =================
log "Setting up admin user..."
log "Please create an admin user for your Ntfy server:"
echo -e "${BLUE}Run this command inside the container to create an admin user:${NC}"
echo -e "${YELLOW}pct exec $CONTAINER_ID -- ntfy user add --role=admin admin${NC}"
echo ""

# =================
# Final Status
# =================
log "Ntfy LXC container setup complete!"
echo ""
echo -e "${GREEN}=== Container Information ===${NC}"
echo -e "Container ID: ${BLUE}$CONTAINER_ID${NC}"
echo -e "Container Name: ${BLUE}$CONTAINER_NAME${NC}"
echo -e "IP Address: ${BLUE}$IP_ONLY${NC}"
echo -e "Web UI: ${BLUE}http://$IP_ONLY${NC}"
echo ""
echo -e "${GREEN}=== Next Steps ===${NC}"
echo "1. Create admin user: ${YELLOW}pct exec $CONTAINER_ID -- ntfy user add --role=admin admin${NC}"
echo "2. Update your homelab .env file:"
echo "   ${YELLOW}NTFY_SERVER=http://$IP_ONLY${NC}"
echo "3. Test the server: ${YELLOW}curl -d 'Test message' $IP_ONLY/test-topic${NC}"
echo "4. Configure firewall rules if needed"
echo ""
echo -e "${GREEN}Documentation: https://docs.ntfy.sh/${NC}"