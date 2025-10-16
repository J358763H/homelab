#!/bin/bash

# =====================================================
# 🌐 Nginx Proxy Manager LXC Setup Script
# =====================================================
# Creates and configures NPM in an LXC container
# Usage: ./setup_npm_lxc.sh [--automated] [ctid]
# =====================================================

set -euo pipefail

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common_functions.sh"

# Check dependencies and root access
check_root
check_dependencies

# Parse arguments
check_automated_mode "$@"
CTID="${2:-201}"

# Configuration
HOSTNAME="homelab-nginx-proxy-201"
MEMORY="1024"
SWAP="512"
CORES="1"
STORAGE="4"
TEMPLATE="local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"

# Network configuration (homelab subnet)
BRIDGE="vmbr0"
IP="192.168.1.201"
NETMASK="24"
GATEWAY="192.168.1.1"
NAMESERVER="192.168.1.1"

# Handle existing container
if ! handle_existing_container "$CTID"; then
    exit 1
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
if ! wait_for_container_ready "$CTID"; then
    error "Container setup failed"
    exit 1
fi

# Wait for network connectivity
if ! wait_for_network "$CTID"; then
    error "Network setup failed"
    exit 1
fi

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
    if ! docker compose up -d; then
        echo 'Failed to start NPM with docker compose'
        exit 1
    fi
    
    # Wait for NPM to be ready with proper health check
    wait_for_npm() {
        local max_attempts=60
        local attempt=1
        
        echo 'Waiting for NPM to be ready...'
        while [ \$attempt -le \$max_attempts ]; do
            if curl -s -o /dev/null -w '%{http_code}' http://localhost:81 | grep -q '200\|302\|401'; then
                echo \"NPM is ready (attempt \$attempt)\"
                return 0
            fi
            
            echo \"NPM not ready, attempt \$attempt/\$max_attempts\"
            sleep 3
            attempt=\$((attempt + 1))
        done
        
        echo 'NPM failed to become ready'
        return 1
    }
    
    if ! wait_for_npm; then
        echo 'NPM health check failed'
        exit 1
    fi
"

# Final validation
log "Performing final validation..."

# Validate Docker service
if ! validate_docker_service "$CTID" "nginx-proxy-manager"; then
    error "NPM Docker service validation failed"
    exit 1
fi

# Validate HTTP endpoint
if ! wait_for_http_endpoint "$CTID" "http://localhost:81" "NPM Web UI"; then
    warn "NPM Web UI not responding immediately (may need more time)"
fi

# Display service information
additional_info="${YELLOW}Default Login:${NC}
Email:    ${GREEN}admin@example.com${NC}
Password: ${GREEN}changeme${NC}
${RED}⚠️  Change these credentials immediately!${NC}

${BLUE}Additional Ports:${NC}
HTTP Proxy:  ${GREEN}http://$IP:80${NC}
HTTPS Proxy: ${GREEN}https://$IP:443${NC}

${BLUE}Configuration:${NC}
Config path: ${GREEN}/opt/nginx-proxy-manager/${NC}
Data backup: ${GREEN}/opt/nginx-proxy-manager/data${NC}
Docker logs: ${GREEN}pct exec $CTID -- docker logs nginx-proxy-manager${NC}"

display_service_info "Nginx Proxy Manager" "$CTID" "$IP" "81" "$additional_info"