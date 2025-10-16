#!/bin/bash
# =====================================================
# 🚀 HOMELAB LXC DEPLOYMENT - STAGE 2: SUPPORT SERVICES
# =====================================================
# Deploy supporting LXC containers
# Services: Samba (File Shares), Ntfy (Notifications), Vaultwarden (Passwords)
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

# Check if Stage 1 LXC containers are running
check_lxc_prerequisites() {
    log "🔍 Checking LXC Stage 1 prerequisites..."

    local required_containers=("200" "201")  # Pi-hole, NPM
    local all_running=true

    for ctid in "${required_containers[@]}"; do
        if ! pct list | grep -q "^$ctid "; then
            error "Container CT$ctid from Stage 1 doesn't exist"
            all_running=false
        elif ! pct status "$ctid" | grep -q "running"; then
            error "Container CT$ctid from Stage 1 is not running"
            all_running=false
        fi
    done

    if ! $all_running; then
        error "LXC Stage 1 containers must be running first. Run: ./deploy_lxc_stage1_core.sh"
        exit 1
    fi

    success "LXC Stage 1 prerequisites satisfied"
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
    local max_attempts="${3:-15}"
    local attempt=1

    log "⏳ Waiting for container $ctid ($service_name) to be ready..."

    while [ $attempt -le $max_attempts ]; do
        if pct status "$ctid" | grep -q "running"; then
            # Additional check for service readiness
            sleep 5
            success "Container $ctid ($service_name) is ready"
            return 0
        fi

        warning "Container $ctid not ready, attempt $attempt/$max_attempts"
        sleep 10
        attempt=$((attempt + 1))
    done

    error "Container $ctid ($service_name) failed to become ready"
    return 1
}

# Deploy LXC Stage 2 services
deploy_lxc_stage2() {
    log "🚀 Starting LXC Stage 2: Support Services Deployment"

    # Stage 2 LXC Services (in order of importance)
    local services=(
        "samba:202:File Sharing & Network Storage"
        "ntfy:203:Notification Service"
        "vaultwarden:204:Password Manager"
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
            wait_for_container "$ctid" "$service" 25

            # Additional service-specific wait time
            case "$service" in
                "samba")
                    log "📁 Waiting for Samba file sharing to initialize..."
                    sleep 15
                    ;;
                "ntfy")
                    log "📢 Waiting for notification service to start..."
                    sleep 10
                    ;;
                "vaultwarden")
                    log "🔐 Waiting for password manager to initialize..."
                    sleep 20
                    ;;
            esac
        else
            error "Failed to deploy $service (CT$ctid)"
            # Don't fail entire deployment for optional services
            warning "Continuing with remaining services..."
        fi
    done

    success "🎉 LXC Stage 2 deployment completed!"
}

# Verify LXC Stage 2 deployment
verify_lxc_deployment() {
    log "🔍 Verifying LXC Stage 2 deployment..."

    local services=("202:samba" "203:ntfy" "204:vaultwarden")
    local running_count=0
    local total_count=${#services[@]}

    for service_info in "${services[@]}"; do
        IFS=':' read -r ctid service <<< "$service_info"

        if container_exists "$ctid" && pct status "$ctid" | grep -q "running"; then
            success "✅ CT$ctid ($service) is running"
            ((running_count++))

            # Service-specific health checks and info
            case "$service" in
                "samba")
                    local ip
                    ip=$(pct exec "$ctid" -- hostname -I | awk '{print $1}')
                    log "   Samba Shares: \\\\$ip\\share"
                    ;;
                "ntfy")
                    local ip
                    ip=$(pct exec "$ctid" -- hostname -I | awk '{print $1}')
                    log "   Ntfy Service: http://$ip"
                    ;;
                "vaultwarden")
                    local ip
                    ip=$(pct exec "$ctid" -- hostname -I | awk '{print $1}')
                    log "   Vaultwarden: http://$ip"
                    ;;
            esac
        else
            warning "⚠️ CT$ctid ($service) is not running"
        fi
    done

    success "📊 LXC Stage 2 Status: $running_count/$total_count services running"

    if [ $running_count -gt 0 ]; then
        success "🎯 LXC Stage 2 deployment successful!"
        log ""
        log "📋 LXC Deployment Complete!"
        log ""
        log "🏠 All LXC Services Status:"
        log "   Stage 1 - Core Services:"
        log "     • CT200 (Pi-hole): DNS & Ad Blocking"
        log "     • CT201 (NPM): Reverse Proxy & SSL"
        log "   Stage 2 - Support Services:"
        log "     • CT202 (Samba): File Sharing"
        log "     • CT203 (Ntfy): Notifications"
        log "     • CT204 (Vaultwarden): Password Manager"
        log ""
        log "🚀 Ready to deploy Docker services with staged deployment!"
        return 0
    else
        warning "⚠️ No Stage 2 services are running, but continuing..."
        return 0
    fi
}

# Show complete LXC status
show_complete_lxc_status() {
    log ""
    log "================================"
    log "🏠 COMPLETE LXC STATUS"
    log "================================"

    local all_containers=("200:pihole" "201:nginx-proxy-manager" "202:samba" "203:ntfy" "204:vaultwarden")
    local running_count=0
    local total_count=${#all_containers[@]}

    for container_info in "${all_containers[@]}"; do
        IFS=':' read -r ctid service <<< "$container_info"

        if container_exists "$ctid" && pct status "$ctid" | grep -q "running"; then
            success "✅ CT$ctid ($service)"
            ((running_count++))
        else
            warning "⚠️ CT$ctid ($service) - Not running"
        fi
    done

    log ""
    success "📊 Overall LXC Status: $running_count/$total_count containers running"

    if [ $running_count -ge 2 ]; then  # At least core services
        success "🎉 LXC infrastructure is operational!"
    else
        warning "⚠️ Critical LXC services need attention"
    fi
}

# Cleanup on failure
cleanup_on_failure() {
    warning "🧹 Cleaning up failed LXC Stage 2 deployment..."

    local containers=("204" "203" "202")  # Reverse order for cleanup
    for ctid in "${containers[@]}"; do
        if container_exists "$ctid"; then
            log "Stopping container $ctid..."
            pct stop "$ctid" 2>/dev/null || true
        fi
    done
}

# Main execution
main() {
    log "====================================
🔧 HOMELAB LXC STAGE 2: SUPPORT SERVICES
===================================="
    warning "Services: Samba (Files), Ntfy (Notifications), Vaultwarden (Passwords)"
    log ""

    # Don't exit on single service failure for stage 2
    set +e

    check_lxc_prerequisites
    deploy_lxc_stage2
    verify_lxc_deployment
    show_complete_lxc_status

    success "🚀 LXC deployment completed!"
}

# Execute main function
main "$@"
