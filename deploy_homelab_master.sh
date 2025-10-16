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
HOMELAB_ROOT="$SCRIPT_DIR"
LOG_FILE="/var/log/homelab_deployment_$(date +%Y%m%d_%H%M%S).log"

# Proxmox detection
PROXMOX_ENV=false
if grep -q "pve" /proc/version 2>/dev/null || [ -d "/etc/pve" ] 2>/dev/null; then
    PROXMOX_ENV=true
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

# Load environment configuration
if [[ -f "$HOMELAB_ROOT/.env" ]]; then
    source "$HOMELAB_ROOT/.env"
    log "Loaded environment configuration"
else
    warning "Environment file not found at $HOMELAB_ROOT/.env"
fi

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

# Check kernel compatibility for Proxmox
check_kernel_compatibility() {
    log "Checking kernel compatibility..."

    local kernel_version=$(uname -r)
    log "Current kernel: $kernel_version"

    # Check for known problematic kernel versions
    if echo "$kernel_version" | grep -q "\.14"; then
        warning "Detected kernel .14 - applying compatibility fixes"

        # Load required modules
        local required_modules=("bridge" "veth" "xt_nat" "xt_conntrack" "ip_tables")
        for module in "${required_modules[@]}"; do
            if ! lsmod | grep -q "^$module"; then
                if modprobe "$module" 2>/dev/null; then
                    log "Loaded module: $module"
                else
                    warning "Could not load module: $module"
                fi
            fi
        done

        # Fix networking parameters
        echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true
        echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables 2>/dev/null || true

        # Create kernel compatibility fix script for later use
        if [[ -f "$HOMELAB_ROOT/fix_kernel_compatibility.sh" ]]; then
            log "Running comprehensive kernel compatibility fixes..."
            chmod +x "$HOMELAB_ROOT/fix_kernel_compatibility.sh"
            "$HOMELAB_ROOT/fix_kernel_compatibility.sh" check >/dev/null 2>&1 || warning "Kernel compatibility script had issues"
        fi

        success "Kernel .14 compatibility fixes applied"
    elif echo "$kernel_version" | grep -q "\.11"; then
        log "Kernel .11 detected - standard configuration"
    else
        log "Kernel version: $kernel_version (assuming compatible)"
    fi
}

# Check prerequisites

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

    # Check kernel compatibility
    check_kernel_compatibility

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
    # Check environment variable or use default
    local setup_zfs=${SETUP_ZFS:-"auto"}

    if [[ "$setup_zfs" == "auto" ]]; then
        # Auto-detect if ZFS setup is needed
        if ! zpool list >/dev/null 2>&1; then
            log "No ZFS pools detected, will set up ZFS mirror"
            setup_zfs="yes"
        else
            log "ZFS pools already exist, skipping ZFS setup"
            setup_zfs="no"
        fi
    fi

    if [[ "$setup_zfs" =~ ^[Yy]|yes|YES$ ]]; then
        step "Setting up ZFS mirror..."

        # Check multiple possible locations for the ZFS setup script
        ZFS_SCRIPT=""
        if [[ -f "$SCRIPT_DIR/scripts/setup_zfs_mirror.sh" ]]; then
            ZFS_SCRIPT="$SCRIPT_DIR/scripts/setup_zfs_mirror.sh"
        elif [[ -f "$SCRIPT_DIR/setup_zfs_mirror.sh" ]]; then
            ZFS_SCRIPT="$SCRIPT_DIR/setup_zfs_mirror.sh"
        elif [[ -f "/opt/homelab/setup_zfs_mirror.sh" ]]; then
            ZFS_SCRIPT="/opt/homelab/setup_zfs_mirror.sh"
        fi

        if [[ -n "$ZFS_SCRIPT" ]]; then
            chmod +x "$ZFS_SCRIPT"
            if "$ZFS_SCRIPT"; then
                success "ZFS mirror setup completed"
            else
                error "ZFS mirror setup failed"
                return 1
            fi
        else
            warning "ZFS setup script not found at any expected location, skipping ZFS configuration"
            log "Searched locations:"
            log "  - $SCRIPT_DIR/scripts/setup_zfs_mirror.sh"
            log "  - $SCRIPT_DIR/setup_zfs_mirror.sh"
            log "  - /opt/homelab/setup_zfs_mirror.sh"
        fi
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

# Prepare Docker environment
prepare_docker_environment() {
    step "Preparing Docker environment..."

    # Create Docker host VM if it doesn't exist
    if ! pct status 100 >/dev/null 2>&1; then
        log "Creating Docker host VM (VMID 100)..."

        # Download Ubuntu template if not exists
        if [[ ! -f /var/lib/vz/template/cache/ubuntu-22.04-standard_22.04-1_amd64.tar.zst ]]; then
            log "Downloading Ubuntu 22.04 LXC template..."
            pveam update
            pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst
        fi

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

        # Wait for container to be ready instead of sleep
        if ! wait_for_container_ready 100; then
            error "Docker host container failed to start properly"
            return 1
        fi

        # Install Docker in the container
        pct exec 100 -- bash -c "
            # Update system
            apt update && apt upgrade -y
            apt install -y curl wget git netstat-nat

            # Install Docker
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            systemctl enable docker
            systemctl start docker

            # Wait for Docker to be ready
            timeout=30
            while [ \$timeout -gt 0 ] && ! docker info >/dev/null 2>&1; do
                echo 'Waiting for Docker to start...'
                sleep 2
                timeout=\$((timeout-2))
            done

            if ! docker info >/dev/null 2>&1; then
                echo 'Docker failed to start properly'
                exit 1
            fi

            # Install Docker Compose
            curl -L 'https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)' -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose

            # Verify Docker Compose installation
            if ! docker-compose version >/dev/null 2>&1; then
                echo 'Docker Compose installation failed'
                exit 1
            fi

            # Create directories
            mkdir -p /data/{docker,media,backups,logs}
            mkdir -p /data/media/{movies,shows,music,youtube,downloads}

            echo 'Docker installation completed successfully'
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

    # Create directory in container first
    pct exec 100 -- mkdir -p /opt/homelab

    # Copy files individually (pct push doesn't support --recursive)
    for file in "$HOMELAB_ROOT/deployment"/*; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            log "Copying $filename..."
            pct push 100 "$file" "/opt/homelab/$filename"
        fi
    done

    # Copy ZFS script to container if it exists (for compatibility)
    if [[ -f "$HOMELAB_ROOT/setup_zfs_mirror.sh" ]]; then
        pct push 100 "$HOMELAB_ROOT/setup_zfs_mirror.sh" /opt/homelab/setup_zfs_mirror.sh
    elif [[ -f "$HOMELAB_ROOT/scripts/setup_zfs_mirror.sh" ]]; then
        pct push 100 "$HOMELAB_ROOT/scripts/setup_zfs_mirror.sh" /opt/homelab/setup_zfs_mirror.sh
    fi

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
        if ! ./bootstrap.sh; then
            echo 'Bootstrap script failed'
            exit 1
        fi

        # Start the stack with staged deployment (prevents race conditions)
        echo 'Starting Docker stack with race condition prevention...'

        # Stage 1: Start VPN first (required for other services)
        if docker-compose ps gluetun >/dev/null 2>&1; then
            echo 'Starting Gluetun VPN...'
            docker-compose up -d gluetun
            sleep 15  # Wait for VPN connection
        fi

        # Stage 2: Start Tailscale (networking)
        if docker-compose ps tailscale >/dev/null 2>&1; then
            echo 'Starting Tailscale...'
            docker-compose up -d tailscale
            sleep 10
        fi

        # Stage 3: Start core infrastructure (DNS, proxy)
        echo 'Starting core infrastructure...'
        docker-compose up -d pihole nginx-proxy-manager 2>/dev/null || true
        sleep 15  # Wait for Pi-hole to stabilize

        # Stage 4: Start remaining services
        echo 'Starting remaining services...'
        if ! docker-compose up -d; then
            echo 'Docker compose deployment failed'
            exit 1
        fi

        echo 'Docker stack deployment initiated successfully'
    "

    # Validate core services are starting
    log "Validating core Docker services..."

    # Wait for and validate essential services
    local essential_services=("jellyfin" "sonarr" "radarr" "prowlarr" "qbittorrent" "gluetun")

    for service in "${essential_services[@]}"; do
        if validate_docker_service "$service"; then
            success "Essential service $service is running"
        else
            error "Essential service $service failed to start"
            return 1
        fi
    done

    success "Docker stack deployed"
}

# Validate deployment
validate_deployment() {
    step "Validating deployment..."
    local validation_failed=false

    # Check LXC containers
    log "Checking LXC container status..."
    declare -A LXC_SERVICES=(
        ["201"]="nginx-proxy-manager"
        ["202"]="tailscale"
        ["203"]="ntfy"
        ["204"]="samba"
        ["205"]="pihole"
        ["206"]="vaultwarden"
    )

    for vmid in "${!LXC_SERVICES[@]}"; do
        local service="${LXC_SERVICES[$vmid]}"
        if pct status "$vmid" 2>/dev/null | grep -q "running"; then
            success "LXC $vmid ($service) is running"
        else
            error "LXC $vmid ($service) is not running"
            validation_failed=true
        fi
    done

    # Check Docker host connectivity
    log "Testing Docker host connectivity..."
    if ping -c 3 -W 2 192.168.1.100 >/dev/null 2>&1; then
        success "Docker host (192.168.1.100) is reachable"
    else
        error "Docker host is not reachable"
        validation_failed=true
        return 1
    fi

    # Check Docker services status
    log "Checking Docker services status..."
    local docker_status=$(pct exec 100 -- bash -c "cd /opt/homelab && docker-compose ps --format json" 2>/dev/null)

    if [[ -n "$docker_status" ]]; then
        # Count running vs total services
        local total_services=$(echo "$docker_status" | wc -l)
        local running_services=$(echo "$docker_status" | grep -c '"State":"running"' || echo "0")

        log "Docker services: $running_services/$total_services running"

        if [[ $running_services -gt 0 ]]; then
            success "Docker stack is operational"
        else
            error "No Docker services are running"
            validation_failed=true
        fi
    else
        error "Unable to get Docker services status"
        validation_failed=true
    fi

    # Test key service endpoints
    log "Testing key service endpoints..."
    declare -A SERVICE_TESTS=(
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

# 🏥 Proxmox LXC Preflight Checks
check_proxmox_lxc_requirements() {
    log "🏥 Performing Proxmox LXC compatibility checks..."

    local errors=0

    # Check if running in LXC container
    if [ -f "/proc/1/cgroup" ] && grep -q "lxc" /proc/1/cgroup 2>/dev/null; then
        log "Running inside LXC container"

        # Critical: Check TUN device for Gluetun VPN
        if [ ! -c "/dev/net/tun" ]; then
            error "TUN device missing - Gluetun VPN will fail"
            warning "Fix: Add to LXC config: lxc.cgroup2.devices.allow: c 10:200 rwm"
            warning "Then run: mknod /dev/net/tun c 10 200 && chmod 666 /dev/net/tun"
            ((errors++))
        else
            success "TUN device available for VPN containers"
        fi

        # Check container nesting capabilities
        if ! grep -q "unconfined" /proc/mounts 2>/dev/null; then
            warning "Limited container privileges detected"
            warning "Consider adding to LXC config: lxc.apparmor.profile: unconfined"
        else
            success "Container has sufficient privileges"
        fi
    else
        log "Running on Proxmox host (not in container)"
    fi

    # Check DNS configuration to prevent Pi-hole loops
    if [ -f "/etc/resolv.conf" ]; then
        if ! grep -v "127\|::1" /etc/resolv.conf | grep -q "nameserver"; then
            warning "DNS may cause bootstrap loop with Pi-hole"
            warning "Fix: Set external DNS before deployment"
            warning "Example: echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
        else
            success "External DNS configured - no Pi-hole loop risk"
        fi
    fi

    # Check kernel modules for networking
    local required_modules=("bridge" "veth" "ip_tables")
    for module in "${required_modules[@]}"; do
        if ! lsmod | grep -q "^$module" && ! modinfo "$module" >/dev/null 2>&1; then
            warning "Kernel module '$module' not available"
            warning "May affect container networking"
        fi
    done

    # Check disk space
    local available_gb=$(df / | awk 'NR==2 {printf "%.1f", $4/1024/1024}')
    if (( $(echo "$available_gb < 2.0" | bc -l) )); then
        warning "Low disk space: ${available_gb}GB available"
        warning "Recommend at least 5GB for deployment"
    else
        success "Sufficient disk space: ${available_gb}GB available"
    fi

    if [ $errors -gt 0 ]; then
        error "$errors critical Proxmox LXC issues found"
        error "Please fix the above issues before deployment"
        echo ""
        echo "📋 Quick fix commands:"
        echo "1. On Proxmox host, edit LXC config: nano /etc/pve/lxc/{CTID}.conf"
        echo "2. Add lines:"
        echo "   lxc.cgroup2.devices.allow: c 10:200 rwm"
        echo "   lxc.mount.entry: /dev/net dev/net none bind,create=dir"
        echo "   lxc.apparmor.profile: unconfined"
        echo "3. Restart LXC container"
        echo "4. Inside container: mknod /dev/net/tun c 10 200 && chmod 666 /dev/net/tun"
        echo ""
        exit 1
    else
        success "Proxmox LXC environment ready for deployment"
    fi
}

# Main execution
main() {
    log "Starting Homelab Master Deployment"

    # Proxmox-specific preflight checks
    if [ "$PROXMOX_ENV" = true ]; then
        log "🏥 Proxmox environment detected - running LXC preflight checks"
        check_proxmox_lxc_requirements
    fi

    check_prerequisites
    show_deployment_plan    read -p "🚀 Proceed with deployment? (y/n): " PROCEED
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
