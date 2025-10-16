#!/bin/bash
# =====================================================
# 🚀 HOMELAB DEPLOYMENT - STAGE 1: CORE INFRASTRUCTURE
# =====================================================
# Deploy critical infrastructure services first
# Services: VPN, Networking, Media Server, Database
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

# Logging function
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

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    if [[ ! -f "$COMPOSE_FILE" ]]; then
        error "Docker Compose file not found: $COMPOSE_FILE"
        exit 1
    fi

    if [[ ! -f "$DEPLOYMENT_DIR/.env" ]]; then
        error "Environment file not found: $DEPLOYMENT_DIR/.env"
        exit 1
    fi

    if ! command -v docker &> /dev/null; then
        error "Docker not installed"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose not available"
        exit 1
    fi

    success "Prerequisites check passed"
}

# Wait for service to be healthy
wait_for_service() {
    local service_name="$1"
    local max_attempts="${2:-30}"
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

# Deploy Stage 1 services
deploy_stage1() {
    log "🚀 Starting Stage 1: Core Infrastructure Deployment"

    cd "$DEPLOYMENT_DIR"

    # Stage 1 Services (in order)
    local services=(
        "gluetun"           # VPN Gateway - Must be first
        "flaresolverr"      # Cloudflare bypass
        "jellystat-db"      # Database for statistics
        "jellyfin"          # Media server
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

            # Wait for critical services to be ready
            case "$service" in
                "gluetun")
                    log "🔒 Waiting for VPN connection to establish..."
                    wait_for_service "$service" 60
                    sleep 15  # Extra time for VPN to stabilize
                    ;;
                "jellystat-db")
                    log "🗄️ Waiting for database to initialize..."
                    wait_for_service "$service" 45
                    sleep 10  # Extra time for DB initialization
                    ;;
                "jellyfin")
                    log "🎬 Waiting for Jellyfin to start..."
                    wait_for_service "$service" 30
                    ;;
                *)
                    wait_for_service "$service" 20
                    ;;
            esac
        else
            error "Failed to deploy $service"
            return 1
        fi
    done

    success "🎉 Stage 1 deployment completed successfully!"
}

# Verify deployment
verify_deployment() {
    log "🔍 Verifying Stage 1 deployment..."

    local all_healthy=true
    local services=("gluetun" "flaresolverr" "jellystat-db" "jellyfin")

    for service in "${services[@]}"; do
        if docker-compose -f "$COMPOSE_FILE" ps "$service" | grep -q "Up\|healthy"; then
            success "✅ $service is running"
        else
            error "❌ $service is not running properly"
            all_healthy=false
        fi
    done

    if $all_healthy; then
        success "🎯 All Stage 1 services are running correctly!"
        log ""
        log "📋 Next Steps:"
        log "   1. Run: ./deploy_stage2_servarr.sh"
        log "   2. Access Jellyfin: http://localhost:8096"
        log "   3. Check VPN status: docker logs gluetun"
        return 0
    else
        error "⚠️ Some services failed to start properly"
        log "💡 Check logs with: docker-compose logs [service_name]"
        return 1
    fi
}

# Cleanup on failure
cleanup_on_failure() {
    warning "🧹 Cleaning up failed deployment..."
    cd "$DEPLOYMENT_DIR"
    docker-compose down --remove-orphans
}

# Main execution
main() {
    log "=====================================
🔧 HOMELAB STAGE 1: CORE INFRASTRUCTURE
====================================="
    warning "Services: VPN, Media Server, Database, Networking"
    log ""

    # Trap cleanup on failure
    trap cleanup_on_failure ERR

    check_prerequisites
    deploy_stage1
    verify_deployment

    success "🚀 Stage 1 deployment completed! Ready for Stage 2."
}

# Execute main function
main "$@"
