#!/bin/bash
# =====================================================
# 🧹 HOMELAB COMPLETE CLEANUP SCRIPT
# =====================================================
# Cleans out previous homelab installation completely
# Use before starting fresh staged deployment
# =====================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# Show cleanup banner
show_banner() {
    clear
    header "=================================================="
    header "🧹 HOMELAB COMPLETE CLEANUP UTILITY"
    header "=================================================="
    header "This will remove ALL homelab services and data"
    header "Use this before starting fresh staged deployment"
    header "=================================================="
    echo ""
}

# Cleanup Docker services
cleanup_docker() {
    header "🐳 CLEANING UP DOCKER SERVICES"
    echo ""

    log "Stopping all Docker containers..."
    if [[ -f "deployment/docker-compose.yml" ]]; then
        cd deployment
        docker-compose down --remove-orphans || true
        cd ..
        success "Docker containers stopped"
    else
        warning "Docker Compose file not found, skipping Docker cleanup"
    fi

    # Optional: Remove all containers, images, and volumes
    read -p "🗑️ Remove ALL Docker containers, images, and volumes? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Removing all Docker containers..."
        docker container prune -f || true

        log "Removing all Docker images..."
        docker image prune -a -f || true

        log "Removing all Docker volumes..."
        docker volume prune -f || true

        log "Removing all Docker networks..."
        docker network prune -f || true

        success "Docker system completely cleaned"
    else
        log "Skipping Docker system cleanup"
    fi
}

# Cleanup LXC containers
cleanup_lxc() {
    header "🏗️ CLEANING UP LXC CONTAINERS"
    echo ""

    # Check if we're on Proxmox
    if ! command -v pct &> /dev/null; then
        warning "Not running on Proxmox, skipping LXC cleanup"
        return 0
    fi

    # Common homelab LXC container IDs
    local lxc_containers=("200" "201" "202" "203" "204" "100")
    local lxc_names=("pihole" "nginx-proxy-manager" "samba" "ntfy" "vaultwarden" "docker-host")

    log "Checking for homelab LXC containers..."

    for i in "${!lxc_containers[@]}"; do
        local ctid="${lxc_containers[$i]}"
        local name="${lxc_names[$i]}"

        if pct list | grep -q "^$ctid "; then
            warning "Found LXC container CT$ctid ($name)"
            read -p "Remove CT$ctid ($name)? (y/N): " -n 1 -r
            echo ""

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log "Stopping CT$ctid..."
                pct stop "$ctid" || true

                log "Destroying CT$ctid..."
                pct destroy "$ctid" || true

                success "CT$ctid ($name) removed"
            else
                log "Keeping CT$ctid ($name)"
            fi
        fi
    done
}

# Cleanup data directories
cleanup_data() {
    header "📁 CLEANING UP DATA DIRECTORIES"
    echo ""

    local data_dirs=("/data" "/opt/homelab" "/var/lib/docker/volumes")

    for dir in "${data_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            warning "Found data directory: $dir"

            # Show directory size
            local size
            size=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "unknown")
            log "Directory size: $size"

            read -p "Remove $dir? (y/N): " -n 1 -r
            echo ""

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log "Removing $dir..."
                sudo rm -rf "$dir" || true
                success "$dir removed"
            else
                log "Keeping $dir"
            fi
        fi
    done
}

# Cleanup system services and cron jobs
cleanup_system() {
    header "⚙️ CLEANING UP SYSTEM CONFIGURATION"
    echo ""

    log "Removing homelab cron jobs..."
    # Remove homelab-related cron jobs
    (crontab -l 2>/dev/null | grep -v "homelab\|restic_backup\|hdd_health\|maintenance_dashboard" | crontab -) || true
    success "Cron jobs cleaned"

    log "Removing homelab scripts from /usr/local/bin..."
    sudo find /usr/local/bin -name "*homelab*" -delete 2>/dev/null || true
    sudo find /usr/local/bin -name "*restic*" -delete 2>/dev/null || true
    success "System scripts cleaned"

    log "Removing homelab systemd services..."
    sudo find /etc/systemd/system -name "*homelab*" -delete 2>/dev/null || true
    sudo systemctl daemon-reload || true
    success "Systemd services cleaned"
}

# Cleanup network configuration
cleanup_network() {
    header "🌐 CLEANING UP NETWORK CONFIGURATION"
    echo ""

    log "Removing Docker networks..."
    docker network ls --format "{{.Name}}" | grep -E "homelab|servarr" | while read -r network; do
        docker network rm "$network" 2>/dev/null || true
    done
    success "Docker networks cleaned"

    # Note: We don't remove system network configs as they might be needed
    warning "Manual check recommended for /etc/netplan/ or network configs"
}

# Verification
verify_cleanup() {
    header "🔍 VERIFYING CLEANUP"
    echo ""

    log "Checking remaining Docker containers..."
    local running_containers
    running_containers=$(docker ps -q | wc -l)
    log "Running containers: $running_containers"

    log "Checking remaining LXC containers..."
    if command -v pct &> /dev/null; then
        local lxc_count
        lxc_count=$(pct list | grep -c "running\|stopped" || echo "0")
        log "LXC containers: $lxc_count"
    fi

    log "Checking data directories..."
    local data_size
    data_size=$(du -sh /data 2>/dev/null | cut -f1 || echo "not found")
    log "/data directory: $data_size"

    success "Cleanup verification complete"
}

# Main cleanup function
main_cleanup() {
    show_banner

    warning "⚠️  THIS WILL REMOVE ALL HOMELAB SERVICES AND DATA ⚠️"
    warning "Make sure you have backups of any important data!"
    echo ""

    read -p "Continue with complete cleanup? (y/N): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Cleanup cancelled by user"
        exit 0
    fi

    echo ""
    log "Starting complete homelab cleanup..."

    cleanup_docker
    cleanup_lxc
    cleanup_system
    cleanup_network
    cleanup_data
    verify_cleanup

    success "🎉 Complete homelab cleanup finished!"
    echo ""
    log "📋 Next Steps:"
    log "   1. Reboot system (recommended)"
    log "   2. Run staged deployment: ./deploy_homelab_staged.sh"
    log "   3. Select Option 1 for complete fresh deployment"
}

# Execute main cleanup
main_cleanup "$@"
