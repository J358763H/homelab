#!/bin/bash
# =====================================================
# 🚀 HOMELAB DEPLOYMENT - STAGE 3: FRONTEND & AUTOMATION
# =====================================================
# Deploy user interfaces and automation services
# Services: Request Management, User Management, Automation
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
DEPLOYMENT_DIR="$SCRIPT_DIR/deployment"
COMPOSE_FILE="$DEPLOYMENT_DIR/docker-compose.yml"

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

# Check if previous stages are running
check_prerequisites() {
    log "🔍 Checking prerequisites from previous stages..."

    local required_services=("gluetun" "jellyfin" "sonarr" "radarr")
    local all_running=true

    for service in "${required_services[@]}"; do
        if ! docker-compose -f "$COMPOSE_FILE" ps "$service" | grep -q "Up\|healthy"; then
            error "$service from previous stages is not running"
            all_running=false
        fi
    done

    if ! $all_running; then
        error "Previous stage services must be running first."
        log "Run in order: ./deploy_stage1_core.sh -> ./deploy_stage2_servarr.sh"
        exit 1
    fi

    success "Prerequisites from previous stages satisfied"
}

# Wait for service to be healthy
wait_for_service() {
    local service_name="$1"
    local max_attempts="${2:-15}"
    local attempt=1

    log "Waiting for $service_name to be ready..."

    while [ $attempt -le $max_attempts ]; do
        if docker-compose -f "$COMPOSE_FILE" ps "$service_name" | grep -q "healthy\|Up"; then
            success "$service_name is ready (attempt $attempt)"
            return 0
        fi

        warning "$service_name not ready, attempt $attempt/$max_attempts"
        sleep 10
        attempt=$((attempt + 1))
    done

    error "$service_name failed to become ready"
    return 1
}

# Check if service is already running
is_service_running() {
    local service_name="$1"
    docker-compose -f "$COMPOSE_FILE" ps -q "$service_name" | grep -q .
}

# Deploy Stage 3 services
deploy_stage3() {
    log "🚀 Starting Stage 3: Frontend & Automation Deployment"

    cd "$DEPLOYMENT_DIR"

    # Stage 3 Services (in logical order)
    local services=(
        "jellystat"         # Jellyfin statistics (depends on jellystat-db)
        "jellyseerr"        # Request management
        "wizarr"           # User invitation system
        "suggestarr"       # Content suggestions
        "ytdl-sub"         # YouTube content downloader
        "jellyfin-youtube-automation"  # YouTube automation
        "tunarr"           # Channel/playlist management
    )

    for service in "${services[@]}"; do
        log "📦 Deploying $service..."

        if is_service_running "$service"; then
            warning "$service is already running, skipping..."
            continue
        fi

        # Deploy individual service
        if docker-compose up -d "$service"; then
            success "$service deployment started"

            # Wait for service to be ready
            case "$service" in
                "jellystat")
                    log "📊 Waiting for statistics service to connect to database..."
                    wait_for_service "$service" 20
                    ;;
                "jellyseerr")
                    log "📋 Waiting for request management to start..."
                    wait_for_service "$service" 25
                    sleep 10  # Extra time for API initialization
                    ;;
                "wizarr")
                    log "👥 Waiting for user management to start..."
                    wait_for_service "$service" 15
                    ;;
                "ytdl-sub")
                    log "📺 Starting YouTube downloader..."
                    wait_for_service "$service" 15
                    ;;
                "jellyfin-youtube-automation")
                    log "🤖 Starting YouTube automation..."
                    wait_for_service "$service" 20
                    ;;
                *)
                    wait_for_service "$service" 15
                    ;;
            esac
        else
            error "Failed to deploy $service"
            return 1
        fi
    done

    success "🎉 Stage 3 deployment completed successfully!"
}

# Verify deployment
verify_deployment() {
    log "🔍 Verifying Stage 3 deployment..."

    local all_healthy=true
    local services=("jellystat" "jellyseerr" "wizarr" "suggestarr" "ytdl-sub" "jellyfin-youtube-automation" "tunarr")

    for service in "${services[@]}"; do
        if docker-compose -f "$COMPOSE_FILE" ps "$service" | grep -q "Up\|healthy"; then
            success "✅ $service is running"
        else
            error "❌ $service is not running properly"
            all_healthy=false
        fi
    done

    if $all_healthy; then
        success "🎯 All Stage 3 services are running correctly!"
        log ""
        log "🌐 Frontend Service URLs:"
        log "   Jellyseerr (Requests):     http://localhost:5055"
        log "   Wizarr (User Invites):     http://localhost:5690"
        log "   Suggestarr (Suggestions):  http://localhost:${SUGGESTARR_PORT:-5000}"
        log "   JellyStat (Statistics):    http://localhost:3000"
        log "   Tunarr (Channels):         http://localhost:${TUNARR_SERVER_PORT:-8000}"
        log ""
        log "🎉 COMPLETE HOMELAB DEPLOYMENT FINISHED!"
        log ""
        log "📋 Final Setup Steps:"
        log "   1. Complete Jellyfin setup: http://localhost:8096"
        log "   2. Configure Jellyseerr with Sonarr/Radarr APIs"
        log "   3. Set up user invitations in Wizarr"
        log "   4. Configure indexers in Prowlarr"
        log "   5. Test download clients connectivity"
        return 0
    else
        error "⚠️ Some services failed to start properly"
        log "💡 Check logs with: docker-compose logs [service_name]"
        return 1
    fi
}

# Show complete deployment status
show_complete_status() {
    log ""
    log "================================"
    log "🏠 COMPLETE HOMELAB STATUS"
    log "================================"

    # All services across all stages
    local services=(
        "gluetun" "flaresolverr" "jellyfin" "jellystat-db"
        "qbittorrent" "nzbget" "prowlarr" "sonarr" "radarr" "bazarr" "recyclarr"
        "jellystat" "jellyseerr" "wizarr" "suggestarr" "ytdl-sub" "jellyfin-youtube-automation" "tunarr"
    )

    local running_count=0
    local total_count=${#services[@]}

    for service in "${services[@]}"; do
        if docker-compose -f "$COMPOSE_FILE" ps "$service" | grep -q "Up\|healthy"; then
            success "✅ $service"
            ((running_count++))
        else
            error "❌ $service"
        fi
    done

    log ""
    log "📊 Overall Status: $running_count/$total_count services running"

    if [ $running_count -eq $total_count ]; then
        success "🎉 Perfect! All homelab services are operational!"
    else
        warning "⚠️ Some services need attention"
    fi
}

# Cleanup on failure
cleanup_on_failure() {
    warning "🧹 Cleaning up failed Stage 3 deployment..."
    cd "$DEPLOYMENT_DIR"
    local services=("tunarr" "jellyfin-youtube-automation" "ytdl-sub" "suggestarr" "wizarr" "jellyseerr" "jellystat")
    for service in "${services[@]}"; do
        docker-compose stop "$service" 2>/dev/null || true
    done
}

# Main execution
main() {
    log "====================================
🔧 HOMELAB STAGE 3: FRONTEND & AUTOMATION
===================================="
    warning "Services: Request Management, User Interfaces, Automation"
    log ""

    # Trap cleanup on failure
    trap cleanup_on_failure ERR

    check_prerequisites
    deploy_stage3
    verify_deployment
    show_complete_status

    success "🚀 Complete homelab deployment finished!"
}

# Execute main function
main "$@"
