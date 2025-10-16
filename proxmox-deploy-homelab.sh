#!/bin/bash
# =====================================================
# 🚀 Proxmox Web UI Homelab Deployment
# =====================================================
# Optimized for Proxmox web interface shell
# Downloads and deploys homelab directly on Proxmox host
# =====================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
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
    header "🏠 HOMELAB DEPLOYMENT FOR PROXMOX WEB UI"
    header "=================================================="
    header "This script deploys your homelab directly on"
    header "Proxmox host via the web interface shell"
    header "=================================================="
    echo ""
}

# Check if we're on Proxmox (relaxed check for web UI)
check_proxmox_environment() {
    log "🔍 Checking Proxmox environment..."
    
    # Multiple ways to detect Proxmox
    if [[ -f /etc/pve/version ]] || command -v pct >/dev/null 2>&1 || command -v qm >/dev/null 2>&1 || [[ $(uname -r) == *"pve"* ]]; then
        success "✅ Proxmox VE environment detected"
        return 0
    else
        warning "⚠️ Proxmox detection uncertain, but proceeding..."
        return 0
    fi
}

# Install required packages
install_dependencies() {
    header "📦 INSTALLING REQUIRED PACKAGES"
    
    log "Updating package lists..."
    apt-get update -qq
    
    log "Installing Docker and Docker Compose..."
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        git \
        wget \
        unzip
    
    # Install Docker if not present
    if ! command -v docker >/dev/null 2>&1; then
        log "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        systemctl enable docker
        systemctl start docker
    else
        log "Docker already installed"
    fi
    
    # Install Docker Compose if not present
    if ! command -v docker-compose >/dev/null 2>&1; then
        log "Installing Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    else
        log "Docker Compose already installed"
    fi
    
    success "Dependencies installed"
}

# Download homelab repository
download_homelab() {
    header "📥 DOWNLOADING HOMELAB REPOSITORY"
    
    # Create homelab directory
    HOMELAB_DIR="/opt/homelab"
    
    if [[ -d "$HOMELAB_DIR" ]]; then
        log "Existing homelab directory found, backing up..."
        mv "$HOMELAB_DIR" "${HOMELAB_DIR}-backup-$(date +%Y%m%d-%H%M%S)"
    fi
    
    log "Downloading latest homelab repository..."
    git clone https://github.com/J358763H/homelab.git "$HOMELAB_DIR"
    
    cd "$HOMELAB_DIR"
    
    # Make scripts executable
    log "Making scripts executable..."
    find . -name "*.sh" -exec chmod +x {} \;
    
    success "Homelab repository downloaded to $HOMELAB_DIR"
}

# Deploy homelab services
deploy_homelab() {
    header "🚀 DEPLOYING HOMELAB SERVICES"
    
    cd "$HOMELAB_DIR"
    
    log "Starting homelab deployment..."
    
    # Check if setup directory exists
    if [[ -d "setup" ]]; then
        cd setup
        
        # Run deployment script
        if [[ -f "deploy-all.sh" ]]; then
            log "Running deploy-all.sh..."
            ./deploy-all.sh
        else
            warning "deploy-all.sh not found, trying manual deployment..."
            
            # Manual deployment fallback
            cd ../containers
            
            # Deploy core services first
            if [[ -d "core" ]]; then
                log "Deploying core services..."
                cd core
                docker-compose up -d
                cd ..
            fi
            
            # Deploy downloads services
            if [[ -d "downloads" ]]; then
                log "Deploying download services..."
                cd downloads
                docker-compose up -d
                cd ..
            fi
            
            # Deploy media services
            if [[ -d "media" ]]; then
                log "Deploying media services..."
                cd media
                docker-compose up -d
                cd ..
            fi
        fi
    else
        warning "Setup directory not found, trying legacy deployment..."
        
        # Legacy deployment fallback
        if [[ -f "docker-compose.yml" ]]; then
            docker-compose up -d
        elif [[ -d "containers" ]]; then
            cd containers
            for dir in */; do
                if [[ -f "$dir/docker-compose.yml" ]]; then
                    log "Deploying $dir services..."
                    cd "$dir"
                    docker-compose up -d
                    cd ..
                fi
            done
        fi
    fi
    
    success "Homelab services deployed"
}

# Show deployment status
show_status() {
    header "📊 DEPLOYMENT STATUS"
    
    cd "$HOMELAB_DIR"
    
    # Check if status script exists
    if [[ -f "setup/status.sh" ]]; then
        log "Running status check..."
        ./setup/status.sh
    else
        log "Checking Docker containers..."
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi
    
    echo ""
    success "🎉 Homelab deployment completed!"
    echo ""
    echo -e "${CYAN}📍 Next steps:"
    echo "1. Access services via Proxmox host IP"
    echo "2. Configure reverse proxy if using Nginx Proxy Manager"
    echo "3. Check logs: docker logs <container-name>"
    echo "4. Manage services: cd $HOMELAB_DIR && docker-compose up/down"
    echo -e "${NC}"
}

# Show help information
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --no-deps      Skip dependency installation"
    echo "  --download-only Download repository only, don't deploy"
    echo "  --deploy-only  Deploy only (assumes repo already downloaded)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Full deployment (recommended)"
    echo "  $0 --download-only    # Just download the repository"
    echo "  $0 --deploy-only      # Deploy existing repository"
    echo ""
}

# Main execution
main() {
    # Parse command line arguments
    SKIP_DEPS=false
    DOWNLOAD_ONLY=false
    DEPLOY_ONLY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --no-deps)
                SKIP_DEPS=true
                shift
                ;;
            --download-only)
                DOWNLOAD_ONLY=true
                shift
                ;;
            --deploy-only)
                DEPLOY_ONLY=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    show_banner
    check_proxmox_environment
    
    if [[ "$DEPLOY_ONLY" != true ]]; then
        if [[ "$SKIP_DEPS" != true ]]; then
            install_dependencies
        fi
        download_homelab
    fi
    
    if [[ "$DOWNLOAD_ONLY" != true ]]; then
        deploy_homelab
        show_status
    fi
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${RED}Deployment interrupted!${NC}"; exit 1' INT

# Execute main function
main "$@"