#!/bin/bash
# =====================================================
# 🚀 HOMELAB DEPLOYMENT - STAGE 2: SERVARR STACK
# =====================================================
# Deploy download management and media automation services
# Services: Download Clients, Indexers, Media Management
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

# Check if Stage 1 is running
check_stage1_prerequisites() {
    log "🔍 Checking Stage 1 prerequisites..."

    local required_services=("gluetun" "jellyfin")
    local all_running=true

    for service in "${required_services[@]}"; do
        if ! docker-compose -f "$COMPOSE_FILE" ps "$service" | grep -q "Up\|healthy"; then
            error "$service from Stage 1 is not running"
            all_running=false
        fi
    done

    if ! $all_running; then
        error "Stage 1 services must be running first. Run: ./deploy_stage1_core.sh"
        exit 1
    fi

    success "Stage 1 prerequisites satisfied"
}

# Wait for service to be healthy
wait_for_service() {
    local service_name="$1"
    local max_attempts="${2:-20}"
    local attempt=1

    log "Waiting for $service_name to be ready..."

    while [ $attempt -le $max_attempts ]; do
        if docker-compose -f "$COMPOSE_FILE" ps "$service_name" | grep -q "healthy\|Up"; then
            success "$service_name is ready (attempt $attempt)"
            return 0
        fi

        warning "$service_name not ready, attempt $attempt/$max_attempts"
        sleep 15
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

# Test VPN connectivity for download clients
test_vpn_connectivity() {
    log "🔒 Testing VPN connectivity..."

    if docker exec gluetun wget --quiet --timeout=10 --tries=1 --spider https://ipinfo.io; then
        success "VPN connectivity confirmed"
        return 0
    else
        error "VPN connectivity test failed"
        return 1
    fi
}

# Deploy Stage 2 services
deploy_stage2() {
    log "🚀 Starting Stage 2: Servarr Stack Deployment"

    cd "$DEPLOYMENT_DIR"

    # Test VPN before deploying download clients
    test_vpn_connectivity

    # Stage 2 Services (in dependency order)
    local services=(
        "qbittorrent"       # Torrent client (through VPN)
        "nzbget"           # Usenet client (through VPN)
        "prowlarr"         # Indexer manager
        "sonarr"           # TV show manager
        "radarr"           # Movie manager
        "bazarr"           # Subtitle manager
        "recyclarr"        # Quality profile manager
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

            # Wait for service to be ready with specific timeouts
            case "$service" in
                "qbittorrent"|"nzbget")
                    log "⬇️ Waiting for download client to initialize..."
                    wait_for_service "$service" 30
                    sleep 10  # Extra time for VPN-routed services
                    ;;
                "prowlarr")
                    log "🔍 Waiting for indexer manager to start..."
                    wait_for_service "$service" 25
                    sleep 15  # Extra time for Prowlarr to initialize
                    ;;
                "sonarr"|"radarr")
                    log "📺 Waiting for media manager to start..."
                    wait_for_service "$service" 30
                    sleep 10  # Time for initial setup
                    ;;
                "bazarr")
                    log "📝 Waiting for subtitle manager to start..."
                    wait_for_service "$service" 20
                    ;;
                "recyclarr")
                    log "♻️ Starting quality profile manager..."
                    wait_for_service "$service" 15
                    ;;
            esac
        else
            error "Failed to deploy $service"
            return 1
        fi
    done

    success "🎉 Stage 2 deployment completed successfully!"
}

# Verify deployment
verify_deployment() {
    log "🔍 Verifying Stage 2 deployment..."

    local all_healthy=true
    local services=("qbittorrent" "nzbget" "prowlarr" "sonarr" "radarr" "bazarr" "recyclarr")

    for service in "${services[@]}"; do
        if docker-compose -f "$COMPOSE_FILE" ps "$service" | grep -q "Up\|healthy"; then
            success "✅ $service is running"
        else
            error "❌ $service is not running properly"
            all_healthy=false
        fi
    done

    if $all_healthy; then
        success "🎯 All Stage 2 services are running correctly!"
        log ""
        log "📋 Service URLs:"
        log "   Prowlarr (Indexers):  http://localhost:9696"
        log "   Sonarr (TV Shows):    http://localhost:8989"
        log "   Radarr (Movies):      http://localhost:7878"
        log "   Bazarr (Subtitles):   http://localhost:6767"
        log "   qBittorrent:          http://localhost:8080"
        log "   NZBGet:               http://localhost:6789"
        log ""
        log "📋 Next Steps:"
        log "   1. Configure indexers in Prowlarr"
        log "   2. Set up download clients in Sonarr/Radarr"
        log "   3. Run: ./deploy_stage3_frontend.sh"
        return 0
    else
        error "⚠️ Some services failed to start properly"
        log "💡 Check logs with: docker-compose logs [service_name]"
        return 1
    fi
}

# Cleanup on failure
cleanup_on_failure() {
    warning "🧹 Cleaning up failed Stage 2 deployment..."
    cd "$DEPLOYMENT_DIR"
    local services=("recyclarr" "bazarr" "radarr" "sonarr" "prowlarr" "nzbget" "qbittorrent")
    for service in "${services[@]}"; do
        docker-compose stop "$service" 2>/dev/null || true
    done
}

# Main execution
main() {
    log "=====================================
🔧 HOMELAB STAGE 2: SERVARR STACK
====================================="
    warning "Services: Download Clients, Indexers, Media Management"
    log ""

    # Trap cleanup on failure
    trap cleanup_on_failure ERR

    check_stage1_prerequisites
    deploy_stage2
    verify_deployment

    success "🚀 Stage 2 deployment completed! Ready for Stage 3."
}

# Execute main function
main "$@"
