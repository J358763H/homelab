#!/bin/bash

# =====================================================
# 🔧 Quick Deployment Fix for Git Conflicts
# =====================================================
# Resolves git merge conflicts during deployment
# Allows deployment to continue successfully
# =====================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $1${NC}"; }

HOMELAB_DIR="/opt/homelab"

# Fix git repository state
fix_repository() {
    log "Fixing homelab repository state..."
    
    if [[ -d "$HOMELAB_DIR" ]]; then
        cd "$HOMELAB_DIR"
        
        # Check if we're in a git repository
        if [[ -d ".git" ]]; then
            log "Found git repository, fixing conflicts..."
            
            # Stash any local changes
            if ! git diff-index --quiet HEAD --; then
                log "Stashing local changes..."
                git stash push -m "Auto-stash deployment fix $(date)"
                success "Local changes stashed"
            fi
            
            # Reset to clean state
            log "Resetting to clean state..."
            git reset --hard HEAD
            
            # Pull latest changes
            log "Pulling latest changes..."
            git pull origin main
            
            success "Repository state fixed"
        else
            warn "Not a git repository, removing and re-cloning..."
            cd /opt
            rm -rf homelab
            git clone https://github.com/J358763H/homelab.git
            success "Repository re-cloned"
        fi
    else
        log "Repository doesn't exist, cloning..."
        cd /opt
        git clone https://github.com/J358763H/homelab.git
        success "Repository cloned"
    fi
    
    # Make scripts executable
    cd "$HOMELAB_DIR"
    chmod +x scripts/*.sh 2>/dev/null || true
    chmod +x *.sh 2>/dev/null || true
    
    success "Repository is ready for deployment"
}

# Run kernel compatibility fixes
run_kernel_fixes() {
    log "Running kernel compatibility fixes..."
    
    cd "$HOMELAB_DIR"
    
    if [[ -f "fix_kernel_compatibility.sh" ]]; then
        chmod +x fix_kernel_compatibility.sh
        ./fix_kernel_compatibility.sh fix
        success "Kernel compatibility fixes applied"
    else
        warn "Kernel compatibility script not found, applying basic fixes..."
        
        # Apply basic kernel .14 fixes
        local kernel_version=$(uname -r)
        if echo "$kernel_version" | grep -q "\.14"; then
            log "Applying basic .14 kernel fixes..."
            
            # Load essential modules
            modprobe bridge 2>/dev/null || true
            modprobe veth 2>/dev/null || true
            modprobe xt_nat 2>/dev/null || true
            modprobe ip_tables 2>/dev/null || true
            
            # Enable networking
            echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true
            echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables 2>/dev/null || true
            
            success "Basic kernel .14 fixes applied"
        fi
    fi
}

# Continue deployment
continue_deployment() {
    log "Continuing secure deployment..."
    
    cd "$HOMELAB_DIR"
    
    if [[ -f "deploy_secure.sh" ]]; then
        chmod +x deploy_secure.sh
        log "Running updated secure deployment script..."
        ./deploy_secure.sh
    else
        error "Deployment script not found"
        return 1
    fi
}

# Main execution
main() {
    echo "================================================================"
    echo "🔧 FIXING DEPLOYMENT GIT CONFLICTS"
    echo "================================================================"
    echo "Timestamp: $(date)"
    echo "Host: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo "================================================================"
    echo
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
    
    fix_repository
    run_kernel_fixes
    
    success "Repository fixed and ready for deployment!"
    echo
    echo "================================================================"
    echo "🚀 NOW RUN THE DEPLOYMENT:"
    echo "================================================================"
    echo "cd /opt/homelab"
    echo "./deploy_secure.sh"
    echo "================================================================"
}

# Handle command line arguments
case "${1:-fix}" in
    "fix")
        main
        ;;
    "deploy")
        fix_repository
        run_kernel_fixes
        continue_deployment
        ;;
    *)
        echo "Usage: $0 [fix|deploy]"
        echo "  fix    - Fix repository conflicts only"
        echo "  deploy - Fix conflicts and continue deployment"
        exit 1
        ;;
esac