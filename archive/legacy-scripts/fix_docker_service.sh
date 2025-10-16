#!/bin/bash

# =====================================================
# 🐳 Docker Service Recovery Script
# =====================================================
# Fixes Docker startup issues after configuration changes
# Provides fallback configurations for compatibility
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

# Check Docker status
check_docker_status() {
    log "Checking Docker service status..."
    
    if systemctl is-active docker >/dev/null 2>&1; then
        success "Docker is running"
        docker version --format '{{.Server.Version}}' 2>/dev/null && success "Docker daemon is responsive"
        return 0
    else
        warn "Docker is not running"
        return 1
    fi
}

# Show Docker logs
show_docker_logs() {
    log "Recent Docker service logs:"
    journalctl -u docker.service -n 20 --no-pager || warn "Could not retrieve Docker logs"
}

# Create minimal Docker configuration
create_minimal_config() {
    log "Creating minimal Docker configuration..."
    
    mkdir -p /etc/docker
    
    # Backup current config if it exists
    if [[ -f /etc/docker/daemon.json ]]; then
        cp /etc/docker/daemon.json /etc/docker/daemon.json.failed.$(date +%s)
        log "Backed up failed configuration"
    fi
    
    # Create minimal working configuration
    cat > /etc/docker/daemon.json << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "5"
    },
    "live-restore": true
}
EOF

    success "Minimal Docker configuration created"
}

# Create compatible Docker configuration
create_compatible_config() {
    log "Creating kernel-compatible Docker configuration..."
    
    mkdir -p /etc/docker
    
    cat > /etc/docker/daemon.json << 'EOF'
{
    "storage-driver": "overlay2",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "5"
    },
    "live-restore": true,
    "userland-proxy": false,
    "default-ulimits": {
        "nofile": {
            "Name": "nofile",
            "Hard": 64000,
            "Soft": 64000
        }
    }
}
EOF

    success "Compatible Docker configuration created"
}

# Restart Docker with retries
restart_docker_with_retries() {
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log "Attempting to restart Docker (attempt $attempt/$max_attempts)..."
        
        if systemctl restart docker; then
            sleep 5
            
            if systemctl is-active docker >/dev/null 2>&1; then
                success "Docker restarted successfully on attempt $attempt"
                return 0
            else
                warn "Docker service started but not active on attempt $attempt"
            fi
        else
            warn "Docker restart failed on attempt $attempt"
        fi
        
        ((attempt++))
        sleep 2
    done
    
    error "Docker failed to restart after $max_attempts attempts"
    return 1
}

# Fix Docker service
fix_docker_service() {
    log "Attempting to fix Docker service..."
    
    # Stop Docker cleanly
    log "Stopping Docker service..."
    systemctl stop docker docker.socket containerd 2>/dev/null || true
    sleep 3
    
    # Clean up Docker state if needed
    if [[ -d /var/lib/docker ]]; then
        log "Docker state directory exists, preserving data..."
    fi
    
    # Try compatible configuration first
    create_compatible_config
    
    if restart_docker_with_retries; then
        success "Docker fixed with compatible configuration"
        return 0
    fi
    
    # Fall back to minimal configuration
    warn "Compatible config failed, trying minimal configuration..."
    create_minimal_config
    
    if restart_docker_with_retries; then
        success "Docker fixed with minimal configuration"
        return 0
    fi
    
    # Last resort - completely reset Docker config
    warn "Minimal config failed, removing all Docker configuration..."
    rm -f /etc/docker/daemon.json
    
    if restart_docker_with_retries; then
        success "Docker fixed with default configuration"
        return 0
    fi
    
    error "Unable to fix Docker service automatically"
    return 1
}

# Continue homelab deployment
continue_deployment() {
    log "Continuing homelab deployment..."
    
    if [[ -f "/opt/homelab/deploy_secure.sh" ]]; then
        cd /opt/homelab
        chmod +x deploy_secure.sh
        
        log "Resuming secure deployment..."
        ./deploy_secure.sh
    else
        warn "Deployment script not found, manual deployment required"
    fi
}

# Main execution
main() {
    echo "================================================================"
    echo "🐳 DOCKER SERVICE RECOVERY"
    echo "================================================================"
    echo "Timestamp: $(date)"
    echo "Host: $(hostname)"
    echo "================================================================"
    echo
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
    
    if ! check_docker_status; then
        show_docker_logs
        echo
        
        if fix_docker_service; then
            success "Docker service has been fixed!"
            echo
            check_docker_status
        else
            error "Could not fix Docker service automatically"
            echo
            echo "Manual steps to try:"
            echo "1. Check logs: journalctl -u docker.service -f"
            echo "2. Reset Docker: systemctl reset-failed docker"
            echo "3. Remove config: rm /etc/docker/daemon.json"
            echo "4. Restart: systemctl restart docker"
            exit 1
        fi
    else
        success "Docker service is already running correctly"
    fi
    
    echo
    echo "================================================================"
    echo "🚀 DOCKER IS READY - DEPLOYMENT CAN CONTINUE"
    echo "================================================================"
}

# Handle command line arguments
case "${1:-fix}" in
    "fix")
        main
        ;;
    "deploy")
        main
        continue_deployment
        ;;
    "check")
        check_docker_status
        ;;
    "logs")
        show_docker_logs
        ;;
    *)
        echo "Usage: $0 [fix|deploy|check|logs]"
        echo "  fix    - Fix Docker service issues"
        echo "  deploy - Fix Docker and continue deployment"
        echo "  check  - Check Docker status only"
        echo "  logs   - Show Docker service logs"
        exit 1
        ;;
esac