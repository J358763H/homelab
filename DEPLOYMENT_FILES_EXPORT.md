# 🚀 Homelab Deployment Files Export

**Critical files for bug scanning and deployment validation**

---

## 1. MASTER DEPLOYMENT SCRIPT

### File: deploy_homelab_master.sh

```bash
#!/usr/bin/env bash
# =====================================================
# � Homelab Master Deployment Script
# =====================================================
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Created: 2025-10-14
# 
# Orchestrates complete homelab deployment:
# 1. ZFS mirror setup (optional)
# 2. LXC container creation
# 3. Docker stack deployment
# 4. Service validation
# =====================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_ROOT="$SCRIPT_DIR"
LOG_FILE="/var/log/homelab_deployment_$(date +%Y%m%d_%H%M%S).log"

# Load environment configuration
if [[ -f "$HOMELAB_ROOT/.env" ]]; then
    source "$HOMELAB_ROOT/.env"
    log "Loaded environment configuration"
else
    warning "Environment file not found at $HOMELAB_ROOT/.env"
fi

# Functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

step() {
    echo -e "${PURPLE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# Health check functions
wait_for_container_ready() {
    local ctid=$1
    local max_attempts=${2:-30}
    local attempt=1
    
    log "Waiting for container $ctid to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if pct exec $ctid -- systemctl is-system-running --wait >/dev/null 2>&1; then
            success "Container $ctid is ready (attempt $attempt)"
            return 0
        fi
        
        log "Container $ctid not ready, attempt $attempt/$max_attempts"
        sleep 2
        ((attempt++))
    done
    
    error "Container $ctid failed to become ready after $max_attempts attempts"
    return 1
}

wait_for_service_ready() {
    local ctid=$1
    local service_name=$2
    local port=$3
    local max_attempts=${4:-60}
    local attempt=1
    
    log "Waiting for $service_name on container $ctid:$port to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if pct exec $ctid -- netstat -tln 2>/dev/null | grep -q ":$port "; then
            success "$service_name is ready on port $port (attempt $attempt)"
            return 0
        fi
        
        log "$service_name not ready, attempt $attempt/$max_attempts"
        sleep 2
        ((attempt++))
    done
    
    error "$service_name failed to start after $max_attempts attempts"
    return 1
}

validate_docker_service() {
    local container_name=$1
    local max_attempts=${2:-30}
    local attempt=1
    
    log "Validating Docker service: $container_name"
    
    while [ $attempt -le $max_attempts ]; do
        if pct exec 100 -- docker ps --format "table {{.Names}}" | grep -q "^$container_name$"; then
            local status=$(pct exec 100 -- docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null)
            if [ "$status" = "running" ]; then
                success "Docker service $container_name is running"
                return 0
            fi
        fi
        
        log "Docker service $container_name not ready, attempt $attempt/$max_attempts"
        sleep 3
        ((attempt++))
    done
    
    error "Docker service $container_name failed to start properly"
    return 1
}

# Deploy LXC containers
deploy_lxc_containers() {
    step "Deploying LXC containers..."
    
    # Array of LXC services to deploy
    declare -A LXC_SERVICES=(
        ["201"]="nginx-proxy-manager"
        ["202"]="tailscale"
        ["203"]="ntfy"
        ["204"]="samba"
        ["205"]="pihole"
        ["206"]="vaultwarden"
    )
    
    # Map service names to their actual script names
    declare -A SCRIPT_NAMES=(
        ["nginx-proxy-manager"]="setup_npm_lxc.sh"
        ["tailscale"]="setup_tailscale_lxc.sh"
        ["ntfy"]="setup_ntfy_lxc.sh"
        ["samba"]="setup_samba_lxc.sh"
        ["pihole"]="setup_pihole_lxc.sh"
        ["vaultwarden"]="setup_vaultwarden_lxc.sh"
    )
    
    for vmid in "${!LXC_SERVICES[@]}"; do
        service="${LXC_SERVICES[$vmid]}"
        script_name="${SCRIPT_NAMES[$service]}"
        script_path="$HOMELAB_ROOT/lxc/$service/$script_name"
        
        log "Deploying LXC $vmid: $service"
        
        # Check if container already exists and is running
        if pct status "$vmid" >/dev/null 2>&1; then
            local container_status=$(pct status "$vmid" | awk '{print $2}')
            if [[ "$container_status" == "running" ]]; then
                success "LXC $vmid ($service) already running, skipping deployment"
                continue
            else
                log "LXC $vmid exists but is $container_status, will attempt deployment"
            fi
        fi
        
        if [[ -f "$script_path" ]]; then
            chmod +x "$script_path"
            
            # Set environment variable for automation
            export HOMELAB_DEPLOYMENT=true
            export AUTOMATED_MODE=true
            
            # Run the setup script with automation flag
            if "$script_path" --automated; then
                # Wait for container to be ready instead of sleep
                if wait_for_container_ready "$vmid"; then
                    success "LXC $vmid ($service) deployed and ready"
                else
                    error "LXC $vmid ($service) failed to become ready"
                    if [[ "${CONTINUE_ON_ERROR:-false}" == "true" ]] || [[ "${AUTOMATED_MODE:-false}" == "true" ]]; then
                        warning "Continuing deployment despite error (CONTINUE_ON_ERROR=true or AUTOMATED_MODE=true)"
                    else
                        return 1
                    fi
                fi
            else
                error "Failed to deploy LXC $vmid ($service)"
                if [[ "${CONTINUE_ON_ERROR:-false}" == "true" ]] || [[ "${AUTOMATED_MODE:-false}" == "true" ]]; then
                    warning "Continuing deployment despite error (CONTINUE_ON_ERROR=true or AUTOMATED_MODE=true)"
                else
                    return 1
                fi
            fi
        else
            warning "Setup script not found for $service at $script_path"
            if [[ "${CONTINUE_ON_ERROR:-false}" != "true" ]]; then
                return 1
            fi
        fi
    done
    
    success "All LXC containers deployed"
}

# Main execution
main() {
    log "Starting Homelab Master Deployment"
    
    check_prerequisites
    show_deployment_plan
    
    read -p "🚀 Proceed with deployment? (y/n): " PROCEED
    if [[ ! "$PROCEED" =~ ^[Yy]$ ]]; then
        log "Deployment cancelled by user"
        exit 0
    fi
    
    setup_zfs_mirror
    deploy_lxc_containers
    prepare_docker_environment
    deploy_docker_stack
    validate_deployment
    show_final_status
    
    success "Homelab deployment completed successfully!"
}

# Trap for cleanup
trap 'error "Deployment interrupted"; exit 130' INT TERM

# Execute main function
main "$@"
```

---

## 2. COMMON FUNCTIONS LIBRARY

### File: lxc/common_functions.sh

```bash
#!/bin/bash

# =====================================================
# 🔧 Common LXC Setup Functions
# =====================================================
# Shared functions for all LXC setup scripts
# Source this file in your LXC setup scripts
# =====================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Enhanced logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

# Check if running in automated mode
check_automated_mode() {
    AUTOMATED_MODE=false
    
    # Check command line argument
    if [[ "$1" == "--automated" ]]; then
        AUTOMATED_MODE=true
    fi
    
    # Check environment variable
    if [[ "${AUTOMATED_MODE:-false}" == "true" ]]; then
        AUTOMATED_MODE=true
    fi
    
    # Check if called from deployment script
    if [[ -n "${HOMELAB_DEPLOYMENT:-}" ]]; then
        AUTOMATED_MODE=true
    fi
    
    if [[ "$AUTOMATED_MODE" == "true" ]]; then
        log "Running in automated mode"
    fi
    
    export AUTOMATED_MODE
}

# Enhanced container existence check
handle_existing_container() {
    local ctid=$1
    
    if pct status "$ctid" >/dev/null 2>&1; then
        local container_status=$(pct status "$ctid" 2>/dev/null | awk '{print $2}' || echo "unknown")
        warn "Container $ctid already exists (status: $container_status)"
        
        if [[ "$AUTOMATED_MODE" == "true" ]]; then
            if [[ "$container_status" == "running" ]]; then
                success "Container $ctid is already running, skipping recreation"
                return 2  # Special return code to indicate skip
            else
                log "Automated mode: Container exists but not running, recreating..."
                pct stop "$ctid" 2>/dev/null || true
                sleep 2
                pct destroy "$ctid" 2>/dev/null || true
                sleep 2
                
                # Verify container is gone
                if pct status "$ctid" >/dev/null 2>&1; then
                    error "Failed to destroy existing container $ctid"
                    return 1
                fi
                success "Existing container $ctid removed"
            fi
        else
            read -p "Do you want to destroy and recreate it? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log "Stopping and destroying container $ctid..."
                pct stop "$ctid" 2>/dev/null || true
                sleep 2
                pct destroy "$ctid" 2>/dev/null || true
                sleep 2
            else
                error "Aborted. Choose a different container ID or use --automated flag."
                return 1
            fi
        fi
    fi
    return 0
}

# Wait for container to be ready with proper health check
wait_for_container_ready() {
    local ctid=$1
    local max_attempts=${2:-30}
    local attempt=1
    
    log "Waiting for container $ctid to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        # Check if container is running
        if ! pct status "$ctid" 2>/dev/null | grep -q "running"; then
            log "Container $ctid is not running, attempt $attempt/$max_attempts"
            sleep 3
            ((attempt++))
            continue
        fi
        
        # Check if system is ready
        if pct exec "$ctid" -- systemctl is-system-running --wait >/dev/null 2>&1; then
            success "Container $ctid is ready (attempt $attempt)"
            return 0
        fi
        
        log "Container $ctid system not ready, attempt $attempt/$max_attempts"
        sleep 3
        ((attempt++))
    done
    
    error "Container $ctid failed to become ready after $max_attempts attempts"
    return 1
}

# Display final status and access information
display_service_info() {
    local service_name=$1
    local ctid=$2
    local ip=$3
    local port=$4
    local additional_info=${5:-""}
    
    success "$service_name setup completed successfully!"
    echo
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  $service_name Access Information${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "Container ID: ${GREEN}$ctid${NC}"
    echo -e "IP Address:   ${GREEN}$ip${NC}"
    echo -e "Service URL:  ${GREEN}http://$ip:$port${NC}"
    
    if [[ -n "$additional_info" ]]; then
        echo -e "$additional_info"
    fi
    
    echo
    echo -e "${BLUE}Container Management:${NC}"
    echo -e "Enter container: ${GREEN}pct enter $ctid${NC}"
    echo -e "Stop container:  ${GREEN}pct stop $ctid${NC}"
    echo -e "Start container: ${GREEN}pct start $ctid${NC}"
    echo -e "Container logs:  ${GREEN}pct exec $ctid -- journalctl -f${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
       error "This script must be run as root (on Proxmox host)"
       exit 1
    fi
}

# Validate required tools
check_dependencies() {
    local required_tools=("pct" "curl" "wget")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing_tools[*]}"
        error "Please install missing dependencies"
        return 1
    fi
    
    return 0
}

# Export all functions for use in other scripts
export -f log warn error success check_automated_mode handle_existing_container
export -f wait_for_container_ready wait_for_network wait_for_service_port
export -f wait_for_http_endpoint validate_systemd_service validate_docker_service
export -f display_service_info check_root check_dependencies
```

---

## 3. CRITICAL LXC SETUP SCRIPTS

### File: lxc/pihole/setup_pihole_lxc.sh

```bash
#!/bin/bash

# =====================================================
# 🚫 Pi-hole LXC Setup Script
# =====================================================
# Creates and configures Pi-hole in an LXC container
# Usage: ./setup_pihole_lxc.sh [--automated] [ctid]
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
CTID="${2:-205}"

# Configuration
HOSTNAME="homelab-pihole-205"
MEMORY="512"
SWAP="256"
CORES="1"
STORAGE="2"
TEMPLATE="local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"

# Network configuration (homelab subnet)
BRIDGE="vmbr0"
IP="192.168.1.205"
NETMASK="24"
GATEWAY="192.168.1.1"
NAMESERVER="8.8.8.8"

# Handle existing container
handle_result=$(handle_existing_container "$CTID")
if [[ $? -eq 1 ]]; then
    exit 1
elif [[ $? -eq 2 ]]; then
    log "Pi-hole container $CTID already running, skipping setup"
    exit 0
fi

log "Creating Pi-hole LXC container..."

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

# Configure container
log "Configuring Pi-hole..."
pct exec $CTID -- bash -c "
    # Update system
    apt update && apt upgrade -y
    
    # Install required packages
    apt install -y curl wget git nano htop

    # Download and install Pi-hole
    curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended
    
    # Configure Pi-hole
    pihole -a -p 'X#zunVV!kDWdYUt0zAAg'
    
    # Enable Pi-hole service
    systemctl enable pihole-FTL
    systemctl start pihole-FTL
"

# Wait for Pi-hole to be ready
if ! wait_for_service_port "$CTID" "80" "Pi-hole Web Interface"; then
    error "Pi-hole failed to start properly"
    exit 1
fi

# Display final information
additional_info="${YELLOW}Admin Password:${NC}
Password: ${GREEN}X#zunVV!kDWdYUt0zAAg${NC}
${RED}⚠️  Save this password securely!${NC}

${BLUE}Configuration:${NC}
Admin URL:    ${GREEN}http://$IP/admin${NC}
DNS Server:   ${GREEN}$IP${NC}
Config path:  ${GREEN}/etc/pihole/${NC}
Log files:    ${GREEN}/var/log/pihole.log${NC}"

display_service_info "Pi-hole" "$CTID" "$IP" "80" "$additional_info"
```

### File: lxc/tailscale/setup_tailscale_lxc.sh

```bash
#!/bin/bash

# =====================================================
# 🔒 Tailscale LXC Setup Script
# =====================================================
# Creates and configures Tailscale subnet router
# Usage: ./setup_tailscale_lxc.sh [--automated] [ctid]
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
CTID="${2:-202}"

# Configuration
HOSTNAME="homelab-tailscale-vpn-202"
MEMORY="512"
SWAP="256"
CORES="1" 
STORAGE="2"
TEMPLATE="local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"

# Network configuration (homelab subnet)
BRIDGE="vmbr0"
IP="192.168.1.202"
NETMASK="24"
GATEWAY="192.168.1.1"
NAMESERVER="192.168.1.1"
SUBNET_ROUTE="192.168.1.0/24"

# Get Tailscale auth key (from environment or prompt)
if [[ -n "${TAILSCALE_AUTH_KEY:-}" ]]; then
    AUTH_KEY="$TAILSCALE_AUTH_KEY"
    log "Using Tailscale auth key from environment"
elif [[ "${AUTOMATED_MODE:-false}" == "true" ]]; then
    error "TAILSCALE_AUTH_KEY environment variable required in automated mode"
else
    # Interactive mode - prompt for auth key
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Tailscale Auth Key Required${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "Visit: ${GREEN}https://login.tailscale.com/admin/settings/keys${NC}"
    echo -e "Create a reusable, preauthorized key with tag: ${GREEN}homelab-router${NC}"
    echo
    read -p "Enter your Tailscale auth key: " -r AUTH_KEY
fi

if [[ -z "$AUTH_KEY" ]]; then
    error "Auth key is required!"
fi

# Handle existing container
handle_result=$(handle_existing_container "$CTID")
if [[ $? -eq 1 ]]; then
    exit 1
elif [[ $? -eq 2 ]]; then
    log "Tailscale container $CTID already running, skipping setup"
    exit 0
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
if ! wait_for_container_ready "$CTID"; then
    error "Container setup failed"
    exit 1
fi

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

success "Tailscale LXC setup completed successfully!"
```

---

## 4. ENVIRONMENT CONFIGURATION

### File: .env

```bash
# ==============================================
# 🔐 Homelab Environment Configuration
# ==============================================
# Secure storage for deployment credentials
# ==============================================

# Tailscale Configuration
TAILSCALE_AUTH_KEY="kJh982WgWy11CNTRL"

# Nginx Proxy Manager Configuration  
NPM_ADMIN_EMAIL="nginx.detail266@passmail.net"
NPM_ADMIN_PASSWORD="rBgn%WkpyK#nZKYkMw6N"

# Deployment Configuration
HOMELAB_TIMEZONE="America/Phoenix"
HOMELAB_PUID="1000"
HOMELAB_PGID="1000"

# Network Configuration
HOMELAB_SUBNET="192.168.1.0/24"
HOMELAB_GATEWAY="192.168.1.1"
HOMELAB_DNS="192.168.1.1"

# Container IP Assignments
NPM_IP="192.168.1.201"
TAILSCALE_IP="192.168.1.202"
NTFY_IP="192.168.1.203"
PIHOLE_IP="192.168.1.204"
VAULTWARDEN_IP="192.168.1.205"
SAMBA_IP="192.168.1.206"
DOCKER_HOST_IP="192.168.1.100"
```

### File: deployment/.env

```properties
# =====================================================
# 🔧 Homelab Environment Configuration
# =====================================================
# Copy this file to .env and fill in your actual values
# NEVER commit the actual .env file to version control
# =====================================================

# =================
# General Settings
# =================
TZ=America/Phoenix
PUID=1000
PGID=1000

# =================
# VPN Configuration
# =================
VPN_SERVICE_PROVIDER=protonvpn
VPN_TYPE=wireguard
WIREGUARD_PUBLIC_KEY=bPm9LS4EuRi+cXob6bCu1PnRS/VXzHlJl/1jULep1Xw=
WIREGUARD_PRIVATE_KEY=6NrVLnzYF/38b60euj9LLpTLWIDITqBArDgbClO5vEY=
WIREGUARD_ADDRESSES=10.2.0.2/32
SERVER_COUNTRIES=Japan
SERVER_CITIES=Tokyo
HEALTH_VPN_DURATION_INITIAL=120s

# =================
# Database Settings
# =================
DB_USER=J857638T
DB_PASS=w4ypyPmJfYSn0Pq&!sja
JWT_SECRET=U#FbkEP6z*8YQk5HUET7

# =================
# API Keys
# =================
RADARR_API_KEY=your_radarr_api_key_here
SONARR_API_KEY=your_sonarr_api_key_here

# =================
# Admin Credentials
# =================
# Nginx Proxy Manager
NPM_ADMIN_EMAIL=nginx.detail266@passmail.net
NPM_ADMIN_PASSWORD=rBgn%WkpyK#nZKYkMw6N

# Tailscale Configuration
TAILSCALE_AUTH_KEY=kJh982WgWy11CNTRL

# =================
# Service Ports
# =================
SUGGESTARR_PORT=5000
TUNARR_SERVER_PORT=8000

# =================
# Backup Configuration
# =================
RESTIC_REPOSITORY=sftp:backup-server:/backups/homelab
RESTIC_PASSWORD=gAQ%1$g2dM2YYhA13NPe
```

---

## 5. DOCKER COMPOSE CONFIGURATION

### File: deployment/docker-compose.yml

```yaml
# =====================================================
# 🐳 Homelab — Reorganized Docker Compose File
# =====================================================
# Based on TechHut's Proxmox Homelab Series Structure
# Maintainer: J35867U
# Last Updated: 2025-10-15
# 
# Organized Servarr + Jellyfin + Automation Stack
# Following best practices for media server deployment
# =====================================================

networks:
  homelab:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

services:
  # =====================================================
  # 🔒 VPN & NETWORKING LAYER
  # =====================================================
  # VPN Gateway - All download traffic routes through this
  gluetun:
    image: qmcgaw/gluetun:latest
    container_name: gluetun
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - "8080:8080"   # qBittorrent WebUI
      - "6881:6881"   # qBittorrent P2P
      - "6881:6881/udp"
      - "6789:6789"   # NZBGet WebUI
    volumes:
      - ./wg0.conf:/gluetun/wireguard/wg0.conf:ro
    env_file:
      - .env
    networks:
      homelab:
        ipv4_address: 172.20.0.5
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8000/v1/openvpn/status"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Torrent client - Routes through VPN
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Phoenix
      - WEBUI_PORT=8080
    volumes:
      - /data/docker/qbittorrent:/config
      - /data/media/downloads:/downloads
    network_mode: "service:gluetun"  # Routes through VPN
    depends_on:
      - gluetun
    restart: unless-stopped

  # =====================================================
  # 🎬 MEDIA SERVER LAYER
  # =====================================================
  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Phoenix
    volumes:
      - /data/docker/jellyfin:/config
      - /data/media/movies:/data/movies
      - /data/media/shows:/data/tvshows
      - /data/media/music:/data/music
    ports:
      - "8096:8096"
    networks:
      homelab:
        ipv4_address: 172.20.0.10
    restart: unless-stopped

  # =====================================================
  # 🎯 SERVARR AUTOMATION LAYER
  # =====================================================
  # Indexer manager
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Phoenix
    volumes:
      - /data/docker/prowlarr:/config
    ports:
      - "9696:9696"
    networks:
      homelab:
        ipv4_address: 172.20.0.20
    restart: unless-stopped

  # TV Shows automation
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Phoenix
    volumes:
      - /data/docker/sonarr:/config
      - /data/media/shows:/tv
      - /data/media/downloads:/downloads
    ports:
      - "8989:8989"
    networks:
      homelab:
        ipv4_address: 172.20.0.21
    restart: unless-stopped

  # Movies automation
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Phoenix
    volumes:
      - /data/docker/radarr:/config
      - /data/media/movies:/movies
      - /data/media/downloads:/downloads
    ports:
      - "7878:7878"
    networks:
      homelab:
        ipv4_address: 172.20.0.22
    restart: unless-stopped

  # Subtitles automation
  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    container_name: bazarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Phoenix
    volumes:
      - /data/docker/bazarr:/config
      - /data/media/movies:/movies
      - /data/media/shows:/tv
    ports:
      - "6767:6767"
    networks:
      homelab:
        ipv4_address: 172.20.0.23
    restart: unless-stopped
```

---

## 6. NETWORK AND SYSTEM SCRIPTS

### File: scripts/validate_deployment.sh

```bash
#!/bin/bash

# =====================================================
# ✅ Deployment Validation Script
# =====================================================
# Validates homelab services are running correctly
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

# Test service endpoint
test_endpoint() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    log "Testing $name: $url"
    
    local response_code=$(curl -s -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "000")
    
    if [[ "$response_code" == "$expected_code" ]] || [[ "$response_code" =~ ^[23] ]]; then
        success "$name is responding (HTTP $response_code)"
        return 0
    else
        error "$name failed (HTTP $response_code)"
        return 1
    fi
}

# Main validation
main() {
    log "Starting homelab validation..."
    
    # Test LXC services
    test_endpoint "Nginx Proxy Manager" "http://192.168.1.201:81" "200"
    test_endpoint "Pi-hole Admin" "http://192.168.1.205/admin" "200"
    test_endpoint "Vaultwarden" "http://192.168.1.206" "200"
    
    # Test Docker services
    test_endpoint "Jellyfin" "http://192.168.1.100:8096" "200"
    test_endpoint "Sonarr" "http://192.168.1.100:8989" "200"
    test_endpoint "Radarr" "http://192.168.1.100:7878" "200"
    test_endpoint "Prowlarr" "http://192.168.1.100:9696" "200"
    test_endpoint "qBittorrent" "http://192.168.1.100:8080" "200"
    
    success "Homelab validation completed"
}

main "$@"
```

---

## 7. POTENTIAL BUG AREAS TO SCAN

### **Critical Issues to Check:**

1. **Script Path Resolution**
   - Variable: `$SCRIPT_DIR` and `$HOMELAB_ROOT`
   - Issue: May fail if scripts moved or called from different directories

2. **Container ID Conflicts** 
   - Function: `handle_existing_container()`
   - Issue: Race conditions when destroying/recreating containers

3. **Network Connectivity Waits**
   - Functions: `wait_for_container_ready()`, `wait_for_network()`
   - Issue: Timeout values may be too short for slow systems

4. **Environment Variable Loading**
   - Files: `.env` loading in deployment script
   - Issue: Variables may not be exported to child processes

5. **Docker Service Validation**
   - Function: `validate_docker_service()`
   - Issue: Container name matching and status checking logic

6. **Automated Mode Detection**
   - Function: `check_automated_mode()`
   - Issue: Multiple detection methods may conflict

7. **File Copy Operations**
   - Command: `pct push` operations in deployment
   - Issue: Source files may not exist or have wrong permissions

8. **VPN Configuration**
   - File: `wg0.conf` referenced in docker-compose
   - Issue: WireGuard config file may not exist

9. **Port Conflicts**
   - Services: Multiple services binding to same ports
   - Issue: Docker Compose port mapping conflicts

10. **Error Handling**
    - Pattern: `CONTINUE_ON_ERROR` logic
    - Issue: May mask critical failures in automation

### **Commands to Test Manually:**
```bash
# Test script directory resolution
echo "SCRIPT_DIR: $SCRIPT_DIR"
echo "HOMELAB_ROOT: $HOMELAB_ROOT"

# Test container operations
pct status 201
pct exec 201 -- systemctl is-system-running

# Test network connectivity
ping -c 1 192.168.1.201
curl -I http://192.168.1.201:81

# Test Docker operations
pct exec 100 -- docker ps
pct exec 100 -- docker-compose ps
```

---

**END OF EXPORT**

This export contains all critical deployment files for bug scanning and validation.
