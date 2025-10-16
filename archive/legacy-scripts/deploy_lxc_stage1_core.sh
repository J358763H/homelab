#!/bin/bash
# =====================================================
# 🚀 HOMELAB LXC DEPLOYMENT - STAGE 1: CORE SERVICES
# =====================================================
# Deploy essential LXC containers first
# Services: Pi-hole (DNS), Nginx Proxy Manager (Reverse Proxy)
# =====================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LXC_DIR="$SCRIPT_DIR/lxc"

# Import common functions if available
if [[ -f "$SCRIPT_DIR/scripts/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/scripts/common_functions.sh"
fi

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

# Check Proxmox prerequisites
check_prerequisites() {
    log "🔍 Checking Proxmox prerequisites..."

    # Check if running on Proxmox
    if ! command -v pct &> /dev/null; then
        error "This script must be run on a Proxmox host (pct command not found)"
        exit 1
    fi

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi

    # Check if LXC scripts exist
    if [[ ! -d "$LXC_DIR" ]]; then
        error "LXC directory not found: $LXC_DIR"
        exit 1
    fi

    success "Proxmox prerequisites satisfied"
}

# Check if container exists
container_exists() {
    local ctid="$1"
    pct list | grep -q "^$ctid "
}

# Wait for container to be ready
wait_for_container() {
    local ctid="$1"
    local service_name="$2"
    local max_attempts="${3:-20}"
    local attempt=1

    log "⏳ Waiting for container $ctid ($service_name) to be ready..."

    while [ $attempt -le $max_attempts ]; do
        if pct status "$ctid" | grep -q "running"; then
            # Additional check for service readiness
            sleep 5
            if pct exec "$ctid" -- systemctl is-active --quiet docker 2>/dev/null || \
               pct exec "$ctid" -- systemctl is-active --quiet ssh 2>/dev/null; then
                success "Container $ctid ($service_name) is ready"
                return 0
            fi
        fi

        warning "Container $ctid not ready, attempt $attempt/$max_attempts"
        sleep 15
        attempt=$((attempt + 1))
    done

    error "Container $ctid ($service_name) failed to become ready"
    return 1
}

# Deploy LXC Stage 1 services
deploy_lxc_stage1() {
    log "🚀 Starting LXC Stage 1: Core Services Deployment"

    # Stage 1 LXC Services (in order of importance)
    local services=(
        "pihole:200:DNS & Ad Blocking"
        "nginx-proxy-manager:201:Reverse Proxy & SSL"
    )

    for service_info in "${services[@]}"; do
        IFS=':' read -r service ctid description <<< "$service_info"

        log "📦 Deploying $service (CT$ctid) - $description..."

        if container_exists "$ctid"; then
            warning "Container $ctid already exists, checking status..."
            if pct status "$ctid" | grep -q "running"; then
                success "Container $ctid is already running, skipping..."
                continue
            else
                log "Starting existing container $ctid..."
                pct start "$ctid"
                wait_for_container "$ctid" "$service" 15
                continue
            fi
        fi

        # Deploy the LXC container
        local setup_script="$LXC_DIR/$service/setup_${service}_lxc.sh"

        if [[ ! -f "$setup_script" ]]; then
            error "Setup script not found: $setup_script"
            continue
        fi

        log "🔧 Running setup script for $service..."
        if bash "$setup_script"; then
            success "$service (CT$ctid) deployment completed"
            wait_for_container "$ctid" "$service" 30

            # Additional service-specific wait time
            case "$service" in
                "pihole")
                    log "🛡️ Waiting for Pi-hole DNS service to initialize..."
                    sleep 30
                    ;;
                "nginx-proxy-manager")
                    log "🔒 Waiting for Nginx Proxy Manager to start..."
                    sleep 20
                    ;;
            esac
        else
            error "Failed to deploy $service (CT$ctid)"
            return 1
        fi
    done

    success "🎉 LXC Stage 1 deployment completed successfully!"
}

# Verify LXC deployment
verify_lxc_deployment() {
    log "🔍 Verifying LXC Stage 1 deployment..."

    local services=("200:pihole" "201:nginx-proxy-manager")
    local all_healthy=true

    for service_info in "${services[@]}"; do
        IFS=':' read -r ctid service <<< "$service_info"

        if container_exists "$ctid" && pct status "$ctid" | grep -q "running"; then
            success "✅ CT$ctid ($service) is running"

            # Service-specific health checks
            case "$service" in
                "pihole")
                    local ip
                    ip=$(pct exec "$ctid" -- hostname -I | awk '{print $1}')
                    log "   Pi-hole Admin: http://$ip/admin"
                    ;;
                "nginx-proxy-manager")
                    local ip
                    ip=$(pct exec "$ctid" -- hostname -I | awk '{print $1}')
                    log "   NPM Admin: http://$ip:81"
                    ;;
            esac
        else
            error "❌ CT$ctid ($service) is not running properly"
            all_healthy=false
        fi
    done

    if $all_healthy; then
        success "🎯 All LXC Stage 1 services are running correctly!"
        log ""
        log "📋 Next Steps:"
        log "   1. Configure Pi-hole DNS settings"
        log "   2. Set up NPM reverse proxy rules"
        log "   3. Run: ./deploy_lxc_stage2_support.sh"
        return 0
    else
        error "⚠️ Some LXC services failed to start properly"
        log "💡 Check container logs with: pct exec [CTID] -- journalctl -f"
        return 1
    fi
}

# Cleanup on failure
cleanup_on_failure() {
    warning "🧹 Cleaning up failed LXC Stage 1 deployment..."

    local containers=("201" "200")  # Reverse order for cleanup
    for ctid in "${containers[@]}"; do
        if container_exists "$ctid"; then
            log "Stopping container $ctid..."
            pct stop "$ctid" 2>/dev/null || true
        fi
    done
}

# Main execution
main() {
    log "=====================================
🔧 HOMELAB LXC STAGE 1: CORE SERVICES
====================================="
    warning "Services: Pi-hole (DNS), Nginx Proxy Manager (Reverse Proxy)"
    log ""

    # Trap cleanup on failure
    trap cleanup_on_failure ERR

    check_prerequisites
    deploy_lxc_stage1
    verify_lxc_deployment

    success "🚀 LXC Stage 1 deployment completed! Ready for Stage 2."
}

# Execute main function
main "$@"
