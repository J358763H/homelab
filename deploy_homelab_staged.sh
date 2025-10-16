#!/bin/bash
# =====================================================
# 🚀 HOMELAB MASTER DEPLOYMENT - STAGED APPROACH
# =====================================================
# Orchestrates complete homelab deployment in stages
# Deploys both LXC containers and Docker services
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
    header "🏠 HOMELAB STAGED DEPLOYMENT ORCHESTRATOR"
    header "=================================================="
    header "Maintainer: J35867U"
    header "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    header ""
    header "This script will deploy your complete homelab in"
    header "optimized stages for maximum success rate."
    header "=================================================="
    echo ""
}

# Deployment options
show_deployment_menu() {
    log "📋 Available Deployment Options:"
    echo ""
    echo "  1) 🏗️  Complete Deployment (LXC + Docker)"
    echo "  2) 🐳 Docker Services Only (3 stages)"
    echo "  3) 📦 LXC Containers Only (2 stages)"
    echo "  4) 🔧 Individual Stage Selection"
    echo "  5) 📊 Check Current Status"
    echo "  6) ❌ Exit"
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

    # Check for staged deployment scripts
    local required_scripts=(
        "deploy_stage1_core.sh"
        "deploy_stage2_servarr.sh"
        "deploy_stage3_frontend.sh"
    )

    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$script" ]]; then
            error "Required script not found: $script"
            missing_prereqs=true
        fi
    done

    if $missing_prereqs; then
        error "Prerequisites not met. Please ensure all required files are present."
        exit 1
    fi

    success "Deployment prerequisites satisfied"
}

# Deploy LXC containers in stages
deploy_lxc_staged() {
    header "🏗️ DEPLOYING LXC CONTAINERS IN STAGES"
    echo ""

    # Stage 1: Core LXC Services
    log "Starting LXC Stage 1: Core Services..."
    if [[ -f "$SCRIPT_DIR/deploy_lxc_stage1_core.sh" ]]; then
        if bash "$SCRIPT_DIR/deploy_lxc_stage1_core.sh"; then
            success "✅ LXC Stage 1 completed successfully"
        else
            error "❌ LXC Stage 1 failed"
            return 1
        fi
    else
        warning "LXC Stage 1 script not found, skipping..."
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

    success "🎉 LXC staged deployment completed!"
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
deploy_complete() {
    header "🚀 STARTING COMPLETE HOMELAB DEPLOYMENT"
    echo ""

    warning "This will deploy both LXC containers and Docker services."
    warning "Total estimated time: 15-25 minutes"
    echo ""

    read -p "Continue with complete deployment? (y/N): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Deployment cancelled by user"
        return 0
    fi

    local start_time
    start_time=$(date +%s)

    # Check if on Proxmox for LXC deployment
    if command -v pct &> /dev/null && [[ $EUID -eq 0 ]]; then
        log "🏗️ Proxmox detected, deploying LXC containers first..."
        if deploy_lxc_staged; then
            success "LXC deployment completed"
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

    success "🎉 COMPLETE HOMELAB DEPLOYMENT FINISHED!"
    success "⏱️ Total deployment time: ${minutes}m ${seconds}s"
}

# Check current status
check_status() {
    header "📊 CHECKING CURRENT HOMELAB STATUS"
    echo ""

    # Check LXC containers if on Proxmox
    if command -v pct &> /dev/null; then
        log "🏗️ LXC Container Status:"
        local lxc_containers=("200:pihole" "201:nginx-proxy-manager" "202:samba" "203:ntfy" "204:vaultwarden")
        local lxc_running=0

        for container_info in "${lxc_containers[@]}"; do
            IFS=':' read -r ctid service <<< "$container_info"
            if pct list | grep -q "^$ctid " && pct status "$ctid" | grep -q "running"; then
                success "  ✅ CT$ctid ($service)"
                ((lxc_running++))
            else
                warning "  ❌ CT$ctid ($service)"
            fi
        done

        log "  📊 LXC Status: $lxc_running/5 containers running"
        echo ""
    fi

    # Check Docker services
    if command -v docker &> /dev/null && [[ -f "$SCRIPT_DIR/deployment/docker-compose.yml" ]]; then
        log "🐳 Docker Service Status:"
        cd "$SCRIPT_DIR/deployment"

        local docker_services=(
            "gluetun" "flaresolverr" "jellyfin" "jellystat-db"
            "qbittorrent" "nzbget" "prowlarr" "sonarr" "radarr" "bazarr"
            "jellystat" "jellyseerr" "wizarr" "suggestarr"
        )
        local docker_running=0

        for service in "${docker_services[@]}"; do
            if docker-compose ps "$service" 2>/dev/null | grep -q "Up\|healthy"; then
                success "  ✅ $service"
                ((docker_running++))
            else
                warning "  ❌ $service"
            fi
        done

        log "  📊 Docker Status: $docker_running/${#docker_services[@]} services running"
    else
        warning "Docker not available or compose file not found"
    fi
}

# Individual stage selection
select_individual_stage() {
    header "🔧 INDIVIDUAL STAGE SELECTION"
    echo ""

    log "Available individual stages:"
    echo "  1) LXC Stage 1: Core Services (Pi-hole, NPM)"
    echo "  2) LXC Stage 2: Support Services (Samba, Ntfy, Vaultwarden)"
    echo "  3) Docker Stage 1: Core Infrastructure (VPN, Jellyfin, DB)"
    echo "  4) Docker Stage 2: Servarr Stack (Download clients, Media management)"
    echo "  5) Docker Stage 3: Frontend & Automation (Jellyseerr, Wizarr, etc.)"
    echo "  6) Back to main menu"
    echo ""

    read -p "Select stage to deploy (1-6): " -n 1 -r stage_choice
    echo ""

    case $stage_choice in
        1)
            if [[ -f "$SCRIPT_DIR/deploy_lxc_stage1_core.sh" ]]; then
                bash "$SCRIPT_DIR/deploy_lxc_stage1_core.sh"
            else
                error "LXC Stage 1 script not found"
            fi
            ;;
        2)
            if [[ -f "$SCRIPT_DIR/deploy_lxc_stage2_support.sh" ]]; then
                bash "$SCRIPT_DIR/deploy_lxc_stage2_support.sh"
            else
                error "LXC Stage 2 script not found"
            fi
            ;;
        3)
            bash "$SCRIPT_DIR/deploy_stage1_core.sh"
            ;;
        4)
            bash "$SCRIPT_DIR/deploy_stage2_servarr.sh"
            ;;
        5)
            bash "$SCRIPT_DIR/deploy_stage3_frontend.sh"
            ;;
        6)
            return 0
            ;;
        *)
            error "Invalid selection"
            ;;
    esac
}

# Main menu loop
main_menu() {
    while true; do
        show_deployment_menu
        read -p "Select option (1-6): " -n 1 -r choice
        echo ""
        echo ""

        case $choice in
            1)
                deploy_complete
                ;;
            2)
                deploy_docker_staged
                ;;
            3)
                if command -v pct &> /dev/null && [[ $EUID -eq 0 ]]; then
                    deploy_lxc_staged
                else
                    error "LXC deployment requires Proxmox host with root access"
                fi
                ;;
            4)
                select_individual_stage
                ;;
            5)
                check_status
                ;;
            6)
                log "👋 Goodbye!"
                exit 0
                ;;
            *)
                error "Invalid option. Please select 1-6."
                ;;
        esac

        echo ""
        read -p "Press Enter to continue..." -r
        echo ""
    done
}

# Main execution
main() {
    show_banner
    check_deployment_prerequisites
    main_menu
}

# Execute main function
main "$@"
