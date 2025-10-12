#!/bin/bash

# =====================================================
# 🌐 Nginx Proxy Manager LXC Setup Script
# =====================================================
# Creates and configures NPM in an LXC container
# =====================================================

set -euo pipefail

# Configuration
CTID="${1:-201}"
HOSTNAME="npm-homelab"
MEMORY="1024"
SWAP="512"
CORES="1"
STORAGE="4"
TEMPLATE="local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"

# Network configuration (adjust for your environment)
BRIDGE="vmbr0"
IP="192.168.1.201"
NETMASK="24"
GATEWAY="192.168.1.1"
NAMESERVER="192.168.1.1"

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

log "Creating Nginx Proxy Manager LXC container..."

# Create LXC container
pct create $CTID $TEMPLATE \
    --hostname $HOSTNAME \
    --memory $MEMORY \
    --swap $SWAP \
    --cores $CORES \
    --rootfs local-lvm:$STORAGE \
    --net0 name=eth0,bridge=$BRIDGE,ip=$IP/$NETMASK,gw=$GATEWAY \
    --nameserver $NAMESERVER \
    --features nesting=1 \
    --unprivileged 1 \
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
    apt install -y curl wget git nano htop

    # Install Docker
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    
    # Create NPM directory structure
    mkdir -p /opt/nginx-proxy-manager/{data,letsencrypt}
    
    # Create docker-compose.yml
    cat > /opt/nginx-proxy-manager/docker-compose.yml << 'EOF'
version: '3.8'

services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Phoenix
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    ports:
      - \"80:80\"     # HTTP
      - \"443:443\"   # HTTPS  
      - \"81:81\"     # Admin Web UI
    restart: unless-stopped
    healthcheck:
      test: [\"CMD\", \"curl\", \"-f\", \"http://localhost:81/api/nginx/health\"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

    # Create systemd service
    cat > /etc/systemd/system/nginx-proxy-manager.service << 'EOF'
[Unit]
Description=Nginx Proxy Manager
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/nginx-proxy-manager
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start service
    systemctl daemon-reload
    systemctl enable nginx-proxy-manager.service
    
    # Start NPM
    cd /opt/nginx-proxy-manager
    docker compose up -d
    
    # Wait for NPM to be ready
    sleep 30
"

# Verify installation
log "Verifying installation..."
if pct exec $CTID -- docker ps | grep -q nginx-proxy-manager; then
    log "✅ Nginx Proxy Manager is running successfully!"
else
    error "❌ NPM installation failed!"
fi

# Display access information
log "🎉 Setup complete!"
echo
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  NPM Access Information${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "Web UI: ${GREEN}http://$IP:81${NC}"
echo -e "HTTP:   ${GREEN}http://$IP:80${NC}"
echo -e "HTTPS:  ${GREEN}https://$IP:443${NC}"
echo
echo -e "${YELLOW}Default Login:${NC}"
echo -e "Email:    ${GREEN}admin@example.com${NC}"
echo -e "Password: ${GREEN}changeme${NC}"
echo -e "${RED}⚠️  Change these credentials immediately!${NC}"
echo
echo -e "${BLUE}Container Commands:${NC}"
echo -e "Enter container: ${GREEN}pct enter $CTID${NC}"
echo -e "Stop container:  ${GREEN}pct stop $CTID${NC}"
echo -e "Start container: ${GREEN}pct start $CTID${NC}"
echo -e "View logs:       ${GREEN}pct exec $CTID -- docker logs nginx-proxy-manager${NC}"
echo
echo -e "${BLUE}Configuration:${NC}"
echo -e "Config path: ${GREEN}/opt/nginx-proxy-manager/${NC}"
echo -e "Data backup: ${GREEN}/opt/nginx-proxy-manager/data${NC}"
echo -e "${BLUE}================================${NC}"

log "Nginx Proxy Manager LXC setup completed successfully!"