#!/usr/bin/env bash
# =====================================================
# 🚀 Homelab Master Deployment Script
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
HOMELAB_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/homelab_deployment_$(date +%Y%m%d_%H%M%S).log"

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

# Check prerequisites
check_prerequisites() {
    step "Checking deployment prerequisites..."
    
    # Check if running on Proxmox
    if ! command -v pct >/dev/null 2>&1; then
        error "This script must be run on Proxmox VE"
        exit 1
    fi
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
    
    # Check network connectivity
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        error "No internet connectivity"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Display deployment plan
show_deployment_plan() {
    echo ""
    echo "=========================================="
    echo "🏗️  HOMELAB DEPLOYMENT PLAN"
    echo "=========================================="
    echo ""
    echo "📍 Primary Server: 192.168.1.50 (Proxmox)"
    echo "🐳 Docker Network: 172.20.0.0/16"
    echo "🏠 LXC Network: 192.168.1.201-206"
    echo ""
    echo "📦 LXC Containers to Deploy:"
    echo "  • 201 - Nginx Proxy Manager (Reverse Proxy)"
    echo "  • 202 - Tailscale VPN (Secure Access)"
    echo "  • 203 - Ntfy Notifications (Alerts)"
    echo "  • 204 - Samba File Share (Storage)"
    echo "  • 205 - Pi-hole DNS (Ad Blocking)"
    echo "  • 206 - Vaultwarden (Password Manager)"
    echo ""
    echo "🐳 Docker Services:"
    echo "  • Servarr Stack (Sonarr, Radarr, Bazarr, Prowlarr)"
    echo "  • Jellyfin Media Server"
    echo "  • qBittorrent + Gluetun VPN"
    echo "  • YouTube Automation (ytdl-sub)"
    echo "  • Analytics & Monitoring"
    echo ""
    echo "=========================================="
    echo ""
}

# ZFS Mirror Setup (Optional)
setup_zfs_mirror() {
    echo ""
    read -p "🗄️  Do you want to setup ZFS mirror for aging drives? (y/n): " SETUP_ZFS
    
    if [[ "$SETUP_ZFS" =~ ^[Yy]$ ]]; then
        step "Setting up ZFS mirror..."
        
        if [[ -f "$SCRIPT_DIR/setup_zfs_mirror.sh" ]]; then
            chmod +x "$SCRIPT_DIR/setup_zfs_mirror.sh"
            "$SCRIPT_DIR/setup_zfs_mirror.sh"
        else
            error "ZFS setup script not found at $SCRIPT_DIR/setup_zfs_mirror.sh"
            exit 1
        fi
        
        success "ZFS mirror setup completed"
    else
        log "Skipping ZFS mirror setup"
    fi
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
    
    for vmid in "${!LXC_SERVICES[@]}"; do
        service="${LXC_SERVICES[$vmid]}"
        script_path="$HOMELAB_ROOT/lxc/$service/setup_${service//-/_}_lxc.sh"
        
        log "Deploying LXC $vmid: $service"
        
        if [[ -f "$script_path" ]]; then
            chmod +x "$script_path"
            
            # Run the setup script
            if "$script_path"; then
                success "LXC $vmid ($service) deployed successfully"
                sleep 5  # Allow container to stabilize
            else
                error "Failed to deploy LXC $vmid ($service)"
                read -p "Continue with deployment? (y/n): " CONTINUE
                if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
                    exit 1
                fi
            fi
        else
            warning "Setup script not found for $service at $script_path"
        fi
    done
    
    success "All LXC containers deployed"
}

# Prepare Docker environment
prepare_docker_environment() {
    step "Preparing Docker environment..."
    
    # Create Docker host VM if it doesn't exist
    if ! pct status 100 >/dev/null 2>&1; then
        log "Creating Docker host VM (VMID 100)..."
        
        # Create Ubuntu LXC for Docker
        pct create 100 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
            --hostname docker-host \
            --cores 4 \
            --memory 8192 \
            --rootfs local-lvm:32 \
            --net0 name=eth0,bridge=vmbr0,ip=192.168.1.100/24,gw=192.168.1.1 \
            --features nesting=1,keyctl=1 \
            --unprivileged 1 \
            --onboot 1
        
        # Start the container
        pct start 100
        sleep 10
        
        # Install Docker in the container
        pct exec 100 -- bash -c "
            apt update && apt upgrade -y
            apt install -y curl wget git
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            systemctl enable docker
            systemctl start docker
            
            # Install Docker Compose
            curl -L 'https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)' -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
            
            # Create directories
            mkdir -p /data/{docker,media,backups,logs}
            mkdir -p /data/media/{movies,shows,music,youtube,downloads}
        "
        
        success "Docker host VM created and configured"
    else
        log "Docker host VM already exists, skipping creation"
    fi
}

# Deploy Docker stack
deploy_docker_stack() {
    step "Deploying Docker stack..."
    
    # Copy deployment files to Docker host
    log "Copying deployment files..."
    pct push 100 "$HOMELAB_ROOT/deployment/" /opt/homelab/ --recursive
    
    # Ensure .env file exists
    if [[ ! -f "$HOMELAB_ROOT/deployment/.env" ]]; then
        warning ".env file not found, creating from template..."
        if [[ -f "$HOMELAB_ROOT/deployment/.env.example" ]]; then
            cp "$HOMELAB_ROOT/deployment/.env.example" "$HOMELAB_ROOT/deployment/.env"
            pct push 100 "$HOMELAB_ROOT/deployment/.env" /opt/homelab/.env
        else
            error ".env file and template not found"
            exit 1
        fi
    fi
    
    # Deploy the stack
    pct exec 100 -- bash -c "
        cd /opt/homelab
        
        # Make scripts executable
        chmod +x bootstrap.sh
        
        # Run bootstrap
        ./bootstrap.sh
        
        # Start the stack
        docker-compose up -d
        
        # Wait for services to start
        sleep 30
        
        # Show status
        docker-compose ps
    "
    
    success "Docker stack deployed"
}

# Validate deployment
validate_deployment() {
    step "Validating deployment..."
    
    # Check LXC containers
    log "Checking LXC container status..."
    for vmid in 201 202 203 204 205 206; do
        if pct status "$vmid" | grep -q "running"; then
            success "LXC $vmid is running"
        else
            error "LXC $vmid is not running"
        fi
    done
    
    # Check Docker services
    log "Checking Docker services..."
    pct exec 100 -- bash -c "
        cd /opt/homelab
        docker-compose ps --format 'table {{.Service}}\t{{.Status}}'
    "
    
    # Network connectivity tests
    log "Testing network connectivity..."
    
    # Test Docker host
    if ping -c 1 192.168.1.100 >/dev/null 2>&1; then
        success "Docker host (192.168.1.100) is reachable"
    else
        error "Docker host is not reachable"
    fi
    
    # Test key services
    declare -A SERVICE_PORTS=(
        ["192.168.1.201"]="81"    # Nginx Proxy Manager
        ["192.168.1.205"]="80"    # Pi-hole
        ["192.168.1.100"]="8096"  # Jellyfin
        ["192.168.1.100"]="8989"  # Sonarr
    )
    
    for ip_port in "${!SERVICE_PORTS[@]}"; do
        port="${SERVICE_PORTS[$ip_port]}"
        if nc -z -w3 "$ip_port" "$port" 2>/dev/null; then
            success "Service at $ip_port:$port is responding"
        else
            warning "Service at $ip_port:$port is not responding (may still be starting)"
        fi
    done
    
    success "Deployment validation completed"
}

# Display final status and next steps
show_final_status() {
    echo ""
    echo "=========================================="
    echo "🎉 HOMELAB DEPLOYMENT COMPLETE!"
    echo "=========================================="
    echo ""
    echo "📊 Service Access URLs:"
    echo "  • Jellyfin Media Server:    http://192.168.1.100:8096"
    echo "  • Sonarr (TV Shows):        http://192.168.1.100:8989"
    echo "  • Radarr (Movies):          http://192.168.1.100:7878"
    echo "  • Prowlarr (Indexers):      http://192.168.1.100:9696"
    echo "  • qBittorrent:              http://192.168.1.100:8080"
    echo "  • Nginx Proxy Manager:      http://192.168.1.201:81"
    echo "  • Pi-hole Admin:            http://192.168.1.205/admin"
    echo "  • Vaultwarden:              http://192.168.1.206"
    echo ""
    echo "🔐 Default Credentials:"
    echo "  • Pi-hole Password:         X#zunVV!kDWdYUt0zAAg"
    echo "  • Nginx Proxy Manager:      admin@example.com / changeme"
    echo "  • qBittorrent:              admin / adminadmin"
    echo ""
    echo "📋 Next Steps:"
    echo "  1. Access Nginx Proxy Manager and set up SSL certificates"
    echo "  2. Configure Pi-hole with your preferred blocklists"
    echo "  3. Set up Prowlarr indexers in Sonarr/Radarr"
    echo "  4. Configure Jellyfin libraries and metadata"
    echo "  5. Set up Tailscale for secure remote access"
    echo ""
    echo "📚 Documentation:"
    echo "  • Main README:              $HOMELAB_ROOT/README.md"
    echo "  • Troubleshooting:          $HOMELAB_ROOT/deployment/TROUBLESHOOTING.md"
    echo "  • Network Scheme:           $HOMELAB_ROOT/NETWORK_ADDRESSING_SCHEME.md"
    echo ""
    echo "📝 Logs saved to: $LOG_FILE"
    echo "=========================================="
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