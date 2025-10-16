#!/bin/bash
# =====================================================
# 🚀 HOMELAB MASTER DEPLOYMENT - NO PI-HOLE VERSION
# =====================================================
# Orchestrates complete homelab deployment in stages
# SKIPS Pi-hole to avoid networking issues
# =====================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Show banner
show_banner() {
    clear
    header "=================================================="
    header "🏠 HOMELAB STAGED DEPLOYMENT (NO PI-HOLE)"
    header "=================================================="
    header "Maintainer: J35867U"
    header "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    header ""
    header "Deploys complete homelab EXCEPT Pi-hole"
    header "Uses system/public DNS instead"
    header "=================================================="
    echo ""
}

# Check prerequisites
check_deployment_prerequisites() {
    log "🔍 Checking deployment prerequisites..."
    
    local missing_prereqs=false
    
    # Check if deployment files exist
    if [[ ! -d "$SCRIPT_DIR/deployment" ]]; then
        error "Deployment directory not found"
        missing_prereqs=true
    fi
    
    if [[ ! -f "$SCRIPT_DIR/deployment/.env" ]]; then
        error "Environment configuration not found (.env file)"
        missing_prereqs=true
    fi
    
    if [[ ! -f "$SCRIPT_DIR/deployment/docker-compose.yml" ]]; then
        error "Docker Compose file not found"
        missing_prereqs=true
    fi
    
    if $missing_prereqs; then
        error "Prerequisites not met. Please ensure all required files are present."
        exit 1
    fi
    
    success "Deployment prerequisites satisfied"
}

# Deploy LXC containers in stages (NO PI-HOLE)
deploy_lxc_staged_no_pihole() {
    header "🏗️ DEPLOYING LXC CONTAINERS IN STAGES (NO PI-HOLE)"
    echo ""
    
    # Stage 1: Core LXC Services (NO PI-HOLE)
    log "Starting LXC Stage 1: Core Services (NO PI-HOLE)..."
    if [[ -f "$SCRIPT_DIR/deploy_lxc_stage1_no_pihole.sh" ]]; then
        if bash "$SCRIPT_DIR/deploy_lxc_stage1_no_pihole.sh"; then
            success "✅ LXC Stage 1 completed successfully (Pi-hole skipped)"
        else
            error "❌ LXC Stage 1 failed"
            return 1
        fi
    else
        warning "LXC Stage 1 (no Pi-hole) script not found, skipping..."
    fi
    
    echo ""
    log "⏳ Waiting 30 seconds before Stage 2..."
    sleep 30
    
    # Stage 2: Support LXC Services
    log "Starting LXC Stage 2: Support Services..."
    if [[ -f "$SCRIPT_DIR/deploy_lxc_stage2_support.sh" ]]; then
        if bash "$SCRIPT_DIR/deploy_lxc_stage2_support.sh"; then
            success "✅ LXC Stage 2 completed successfully"
        else
            warning "⚠️ LXC Stage 2 had issues, but continuing..."
        fi
    else
        warning "LXC Stage 2 script not found, skipping..."
    fi
    
    success "🎉 LXC staged deployment completed (Pi-hole skipped)!"
}

# Deploy Docker services in stages
deploy_docker_staged() {
    header "🐳 DEPLOYING DOCKER SERVICES IN STAGES"
    echo ""
    
    # Stage 1: Core Infrastructure
    log "Starting Docker Stage 1: Core Infrastructure..."
    if bash "$SCRIPT_DIR/deploy_stage1_core.sh"; then
        success "✅ Docker Stage 1 completed successfully"
    else
        error "❌ Docker Stage 1 failed"
        return 1
    fi
    
    echo ""
    log "⏳ Waiting 60 seconds for services to stabilize..."
    sleep 60
    
    # Stage 2: Servarr Stack
    log "Starting Docker Stage 2: Servarr Stack..."
    if bash "$SCRIPT_DIR/deploy_stage2_servarr.sh"; then
        success "✅ Docker Stage 2 completed successfully"
    else
        error "❌ Docker Stage 2 failed"
        return 1
    fi
    
    echo ""
    log "⏳ Waiting 45 seconds for media services to initialize..."
    sleep 45
    
    # Stage 3: Frontend & Automation
    log "Starting Docker Stage 3: Frontend & Automation..."
    if bash "$SCRIPT_DIR/deploy_stage3_frontend.sh"; then
        success "✅ Docker Stage 3 completed successfully"
    else
        warning "⚠️ Docker Stage 3 had issues, but core services should be working..."
    fi
    
    success "🎉 Docker staged deployment completed!"
}

# Complete deployment
deploy_complete_no_pihole() {
    header "🚀 STARTING COMPLETE HOMELAB DEPLOYMENT (NO PI-HOLE)"
    echo ""
    
    warning "This will deploy LXC containers and Docker services."
    warning "Pi-hole will be SKIPPED due to networking issues."
    warning "Total estimated time: 15-25 minutes"
    echo ""
    
    read -p "Continue with deployment (no Pi-hole)? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Deployment cancelled by user"
        return 0
    fi
    
    local start_time
    start_time=$(date +%s)
    
    # Check if on Proxmox for LXC deployment
    if command -v pct &> /dev/null && [[ $EUID -eq 0 ]]; then
        log "🏗️ Proxmox detected, deploying LXC containers (SKIPPING PI-HOLE)..."
        if deploy_lxc_staged_no_pihole; then
            success "LXC deployment completed (Pi-hole skipped)"
        else
            warning "LXC deployment had issues, continuing with Docker..."
        fi
        
        echo ""
        log "⏳ Waiting 2 minutes for LXC services to fully initialize..."
        sleep 120
    else
        warning "Not running on Proxmox as root, skipping LXC deployment"
    fi
    
    # Deploy Docker services
    log "🐳 Starting Docker services deployment..."
    if deploy_docker_staged; then
        success "Docker deployment completed"
    else
        error "Docker deployment failed"
        return 1
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    success "🎉 COMPLETE HOMELAB DEPLOYMENT FINISHED (NO PI-HOLE)!"
    success "⏱️ Total deployment time: ${minutes}m ${seconds}s"
    echo ""
    warning "📋 DNS Configuration:"
    warning "   Pi-hole was skipped - configure DNS manually:"
    warning "   • Use router DNS settings"
    warning "   • Use public DNS (8.8.8.8, 1.1.1.1)"
    warning "   • Or add Pi-hole as Docker container later"
}

# Main execution
main() {
    show_banner
    check_deployment_prerequisites
    deploy_complete_no_pihole
    
    success "🚀 Deployment completed without Pi-hole!"
}

# Execute main function
main "$@"