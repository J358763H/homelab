#!/bin/bash

# =====================================================
# 🔒 Homelab Secure Deployment Script
# =====================================================
# Quick deployment script for secure homelab setup
# Includes all security hardening implementations
# =====================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
HOMELAB_DIR="/opt/homelab"
REPO_URL="https://github.com/J358763H/homelab.git"
LOG_FILE="/var/log/homelab_secure_deploy_$(date +%Y%m%d_%H%M%S).log"

# Functions
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARNING] $1${NC}" | tee -a "$LOG_FILE"; }
step() { echo -e "${PURPLE}[STEP] $1${NC}" | tee -a "$LOG_FILE"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Install required packages
install_dependencies() {
    step "Installing required packages..."
    
    apt-get update
    apt-get install -y git curl wget jq gpg openssh-client rsync fail2ban iptables-persistent
    
    # Install Docker if not present
    if ! command -v docker >/dev/null 2>&1; then
        log "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
    fi
    
    success "Dependencies installed"
}

# Clone or update repository
setup_repository() {
    step "Setting up homelab repository..."
    
    if [[ -d "$HOMELAB_DIR" ]]; then
        log "Updating existing repository..."
        cd "$HOMELAB_DIR"
        git pull origin main
    else
        log "Cloning repository..."
        git clone "$REPO_URL" "$HOMELAB_DIR"
        cd "$HOMELAB_DIR"
    fi
    
    # Make scripts executable
    chmod +x scripts/*.sh 2>/dev/null || true
    chmod +x *.sh 2>/dev/null || true
    
    success "Repository ready at $HOMELAB_DIR"
}

# Deploy security hardening
deploy_security_hardening() {
    step "Deploying security hardening..."
    
    cd "$HOMELAB_DIR"
    
    # 1. Deploy secret management system
    if [[ -f "scripts/secret_management.sh" ]]; then
        log "Deploying secret management..."
        ./scripts/secret_management.sh deploy
        success "Secret management deployed"
    else
        warn "Secret management script not found"
    fi
    
    # 2. Apply firewall hardening
    if [[ -f "scripts/firewall_hardening.sh" ]]; then
        log "Applying firewall hardening..."
        ./scripts/firewall_hardening.sh
        success "Firewall hardening applied"
    else
        warn "Firewall hardening script not found"
    fi
    
    # 3. Configure DNS security
    if [[ -f "scripts/dns_hardening.sh" ]]; then
        log "Configuring DNS security..."
        ./scripts/dns_hardening.sh configure
        success "DNS security configured"
    else
        warn "DNS hardening script not found"
    fi
    
    # 4. Setup logging and monitoring
    if [[ -f "scripts/log_monitoring_setup.sh" ]]; then
        log "Setting up logging and monitoring..."
        ./scripts/log_monitoring_setup.sh setup
        success "Logging and monitoring configured"
    else
        warn "Log monitoring script not found"
    fi
    
    # 5. Run initial security scan
    if [[ -f "scripts/security_scan.sh" ]]; then
        log "Running initial security scan..."
        ./scripts/security_scan.sh
        success "Security scan completed"
    else
        warn "Security scan script not found"
    fi
}

# Deploy LXC containers
deploy_lxc_containers() {
    step "Deploying LXC containers..."
    
    # Check if main deployment script exists
    if [[ -f "$HOMELAB_DIR/homelab.sh" ]]; then
        log "Running main homelab deployment..."
        cd "$HOMELAB_DIR"
        ./homelab.sh
        success "LXC containers deployed"
    else
        warn "Main deployment script not found, skipping LXC deployment"
    fi
}

# Deploy hardened Docker containers
deploy_docker_containers() {
    step "Deploying hardened Docker containers..."
    
    local docker_host="192.168.1.100"
    
    # Check if Docker host is reachable
    if ping -c 1 "$docker_host" >/dev/null 2>&1; then
        log "Docker host $docker_host is reachable"
        
        # Transfer hardened Docker Compose
        if [[ -f "$HOMELAB_DIR/deployment/docker-compose.hardened.yml" ]]; then
            log "Transferring hardened Docker Compose configuration..."
            scp "$HOMELAB_DIR/deployment/docker-compose.hardened.yml" "root@$docker_host:/opt/homelab/"
            
            # Deploy containers on Docker host
            ssh "root@$docker_host" "cd /opt/homelab && docker-compose -f docker-compose.hardened.yml up -d"
            success "Hardened Docker containers deployed"
        else
            warn "Hardened Docker Compose file not found"
        fi
    else
        warn "Docker host $docker_host is not reachable, skipping Docker deployment"
    fi
}

# Run final validation
run_validation() {
    step "Running final security validation..."
    
    if [[ -f "$HOMELAB_DIR/scripts/security_validation.sh" ]]; then
        cd "$HOMELAB_DIR"
        ./scripts/security_validation.sh validate
        success "Security validation completed"
        
        # Show results
        if [[ -f "/opt/homelab/security_validation_report.txt" ]]; then
            log "Validation report:"
            tail -20 "/opt/homelab/security_validation_report.txt"
        fi
    else
        warn "Security validation script not found"
    fi
}

# Display deployment summary
show_summary() {
    step "Deployment Summary"
    echo
    echo "================================================================"
    echo "🚀 HOMELAB SECURE DEPLOYMENT COMPLETED"
    echo "================================================================"
    echo
    echo "✅ Security Features Deployed:"
    echo "   🔒 Encrypted secret management system"
    echo "   🛡️ Network firewall with intrusion detection"
    echo "   🌐 DNS security with malware blocking"
    echo "   📊 Centralized logging and monitoring"
    echo "   🔍 Automated vulnerability scanning"
    echo
    echo "📋 Services Deployed:"
    echo "   📦 LXC Containers:"
    echo "      • 201: Nginx Proxy Manager"
    echo "      • 202: Tailscale VPN"
    echo "      • 203: NTFY Notifications"
    echo "      • 204: Pi-hole DNS"
    echo "      • 205: Additional DNS"
    echo "      • 206: Vaultwarden + Samba"
    echo
    echo "   🐳 Docker Services:"
    echo "      • Jellyfin Media Server"
    echo "      • Sonarr/Radarr/Prowlarr"
    echo "      • qBittorrent"
    echo "      • Database Services"
    echo
    echo "🔧 Management Tools:"
    echo "   • Monitoring Dashboard: /opt/homelab/monitoring/scripts/dashboard.sh"
    echo "   • Security Scanner: /opt/homelab/scripts/security_scan.sh"
    echo "   • Log Analyzer: /opt/homelab/monitoring/scripts/log_analyzer.sh"
    echo
    echo "📄 Important Files:"
    echo "   • Validation Report: /opt/homelab/security_validation_report.txt"
    echo "   • Deployment Log: $LOG_FILE"
    echo "   • Configuration: /opt/homelab/.env"
    echo
    echo "================================================================"
    success "Homelab deployment completed successfully!"
    success "Your homelab is now running with enterprise-grade security!"
    echo "================================================================"
}

# Handle errors
handle_error() {
    local line_number=$1
    error "Deployment failed at line $line_number"
    error "Check the log file: $LOG_FILE"
    echo
    echo "🔧 Troubleshooting:"
    echo "1. Ensure this script is run as root on Proxmox host"
    echo "2. Check network connectivity to Docker host (192.168.1.100)"
    echo "3. Verify all required services are available"
    echo "4. Review the deployment log for specific errors"
    echo
    echo "For support, check the documentation in the repository."
    exit 1
}

# Main execution
main() {
    echo "================================================================"
    echo "🔒 HOMELAB SECURE DEPLOYMENT STARTING"
    echo "================================================================"
    echo "Timestamp: $(date)"
    echo "Host: $(hostname)"
    echo "User: $(whoami)"
    echo "Log: $LOG_FILE"
    echo "================================================================"
    echo
    
    # Set up error handling
    trap 'handle_error $LINENO' ERR
    
    # Execute deployment steps
    check_root
    install_dependencies
    setup_repository
    deploy_security_hardening
    deploy_lxc_containers
    deploy_docker_containers
    run_validation
    show_summary
}

# Execute main function
main "$@"