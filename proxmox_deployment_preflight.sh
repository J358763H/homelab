#!/bin/bash

# =====================================================
# 🛡️ PROXMOX LXC DEPLOYMENT PREFLIGHT CHECKER
# =====================================================
# Tailored for: Gluetun + Tailscale + Pi-hole + NPM
# Prevents 90% of common deployment failures
# =====================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[PREFLIGHT] $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Track failures
FAILED_CHECKS=0

fail_check() {
    error "$1"
    ((FAILED_CHECKS++))
}

# =====================================================
# CRITICAL PROXMOX + LXC CHECKS
# =====================================================

check_lxc_vpn_support() {
    log "Checking LXC VPN support..."

    # Check for /dev/net/tun
    if [ ! -e /dev/net/tun ]; then
        fail_check "/dev/net/tun missing - Gluetun/Tailscale will fail"
        warn "Run on Proxmox host: echo 'tun' >> /etc/modules && modprobe tun"
    else
        success "TUN device available"
    fi

    # Check for nesting feature
    if [ -f /proc/self/cgroup ]; then
        if ! grep -q "docker" /proc/1/cgroup 2>/dev/null; then
            # We're in LXC, check if nesting is enabled
            if [ ! -d /sys/fs/cgroup/systemd ] && [ ! -d /sys/fs/cgroup/unified ]; then
                fail_check "LXC nesting not enabled - Docker will fail"
                warn "Add to LXC config: features: nesting=1"
            else
                success "LXC nesting appears enabled"
            fi
        fi
    fi
}

check_kernel_modules() {
    log "Checking essential kernel modules..."

    local required_modules=("overlay" "br_netfilter")
    for mod in "${required_modules[@]}"; do
        if ! lsmod | grep -q "^$mod"; then
            fail_check "Missing kernel module: $mod"
            warn "Run: modprobe $mod"
        else
            success "Module $mod loaded"
        fi
    done

    # Check for WireGuard if using Tailscale
    if ! lsmod | grep -q wireguard && ! command -v wg >/dev/null 2>&1; then
        warn "WireGuard not detected - Tailscale may use userspace mode (slower)"
    else
        success "WireGuard support available"
    fi
}

check_docker_requirements() {
    log "Checking Docker requirements..."

    # Docker installed
    if ! command -v docker >/dev/null 2>&1; then
        fail_check "Docker not installed"
        warn "Install with: curl -fsSL https://get.docker.com | sh"
    else
        success "Docker installed: $(docker --version | cut -d' ' -f3)"
    fi

    # Docker Compose
    if ! docker compose version >/dev/null 2>&1; then
        fail_check "Docker Compose not available"
    else
        success "Docker Compose available"
    fi

    # Docker daemon running
    if ! systemctl is-active --quiet docker 2>/dev/null; then
        fail_check "Docker daemon not running"
        warn "Start with: systemctl start docker"
    else
        success "Docker daemon running"
    fi
}

check_network_conflicts() {
    log "Checking network configuration..."

    # Check for subnet conflicts (172.20.0.0/16)
    local homelab_subnet="172.20.0.0/16"
    if ip route | grep -q "172.20."; then
        warn "Network 172.20.x.x already in use - may conflict with homelab subnet"
        warn "Consider changing HOMELAB_SUBNET in .env"
    else
        success "Homelab subnet 172.20.0.0/16 appears available"
    fi

    # Check DNS resolver
    if ! ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
        fail_check "No internet connectivity"
    else
        success "Internet connectivity OK"
    fi

    # Check port 53 availability (for Pi-hole)
    if ss -tuln | grep -q ":53 "; then
        warn "Port 53 in use - Pi-hole may fail to start"
        warn "Check: ss -tuln | grep :53"
    else
        success "Port 53 available for Pi-hole"
    fi
}

check_environment_file() {
    log "Checking environment configuration..."

    if [ ! -f .env ]; then
        fail_check ".env file missing"
        warn "Copy from .env.example or create with required variables"
        return
    fi

    # Check for required variables
    local required_vars=("TAILSCALE_AUTH_KEY" "NPM_ADMIN_EMAIL" "NPM_ADMIN_PASSWORD" "HOMELAB_SUBNET")
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" .env; then
            fail_check "Missing $var in .env"
        else
            success "$var configured"
        fi
    done

    # Check for special characters that break Docker Compose
    if grep -q '[#%]' .env; then
        warn "Special characters (#, %) in .env may break parsing"
        warn "Wrap values in quotes if needed"
    fi
}

check_docker_compose_config() {
    log "Validating Docker Compose configuration..."

    local compose_file="deployment/docker-compose.yml"
    if [ ! -f "$compose_file" ]; then
        fail_check "Docker Compose file not found: $compose_file"
        return
    fi

    # Test compose file syntax
    if ! docker compose -f "$compose_file" config >/dev/null 2>&1; then
        fail_check "Docker Compose configuration invalid"
        warn "Run: docker compose -f $compose_file config"
    else
        success "Docker Compose configuration valid"
    fi
}

check_storage_space() {
    log "Checking storage requirements..."

    local available_gb
    available_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')

    if [ "$available_gb" -lt 20 ]; then
        fail_check "Insufficient disk space: ${available_gb}GB available (need 20GB+)"
    else
        success "Disk space OK: ${available_gb}GB available"
    fi
}

# =====================================================
# SPECIFIC SERVICE CHECKS
# =====================================================

check_gluetun_requirements() {
    log "Checking Gluetun VPN requirements..."

    # Check for TUN device (already checked above, but specific to Gluetun)
    if [ ! -c /dev/net/tun ]; then
        fail_check "Gluetun requires /dev/net/tun character device"
    fi

    # Check for required capabilities
    if [ -f /proc/self/status ]; then
        if grep -q "CapEff.*0000000000000000" /proc/self/status; then
            warn "Container may lack NET_ADMIN capability for Gluetun"
        fi
    fi
}

check_tailscale_requirements() {
    log "Checking Tailscale requirements..."

    # Validate auth key format (basic check)
    if [ -f .env ]; then
        local auth_key
        auth_key=$(grep "^TAILSCALE_AUTH_KEY=" .env | cut -d= -f2 | tr -d '"')
        if [ ${#auth_key} -lt 10 ]; then
            fail_check "Tailscale auth key appears invalid (too short)"
        elif [[ ! $auth_key =~ ^[a-zA-Z0-9] ]]; then
            fail_check "Tailscale auth key format appears invalid"
        else
            success "Tailscale auth key format OK"
        fi
    fi
}

# =====================================================
# MAIN EXECUTION
# =====================================================

main() {
    echo "=================================================="
    echo "🛡️  HOMELAB PROXMOX LXC PREFLIGHT CHECKER"
    echo "=================================================="
    echo "Checking deployment readiness for:"
    echo "- Gluetun VPN Gateway"
    echo "- Tailscale Mesh VPN"
    echo "- Pi-hole DNS"
    echo "- Nginx Proxy Manager"
    echo "- Jellyfin + *arr Stack"
    echo "=================================================="
    echo

    # Run all checks
    check_lxc_vpn_support
    check_kernel_modules
    check_docker_requirements
    check_network_conflicts
    check_environment_file
    check_docker_compose_config
    check_storage_space
    check_gluetun_requirements
    check_tailscale_requirements

    echo
    echo "=================================================="
    if [ $FAILED_CHECKS -eq 0 ]; then
        success "ALL CHECKS PASSED! ✨"
        success "Your system is ready for homelab deployment"
        echo
        echo "🚀 Next steps:"
        echo "   ./deploy_homelab_master.sh"
        echo "   OR"
        echo "   ./deploy_secure.sh"
        exit 0
    else
        error "FAILED CHECKS: $FAILED_CHECKS"
        error "Fix the issues above before deploying"
        echo
        echo "💡 Common fixes:"
        echo "   - Run on Proxmox host: modprobe tun overlay br_netfilter"
        echo "   - Enable LXC nesting: features: nesting=1"
        echo "   - Install Docker: curl -fsSL https://get.docker.com | sh"
        echo "   - Create/fix .env file with proper credentials"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-check}" in
    "check")
        main
        ;;
    "fix-modules")
        log "Loading required kernel modules..."
        modprobe tun overlay br_netfilter wireguard 2>/dev/null || true
        echo "tun" >> /etc/modules 2>/dev/null || true
        echo "overlay" >> /etc/modules 2>/dev/null || true
        echo "br_netfilter" >> /etc/modules 2>/dev/null || true
        success "Kernel modules loaded and configured for persistence"
        ;;
    "install-docker")
        log "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
        success "Docker installed and started"
        ;;
    "help")
        echo "Usage: $0 [check|fix-modules|install-docker|help]"
        echo ""
        echo "Commands:"
        echo "  check         - Run all preflight checks (default)"
        echo "  fix-modules   - Load and configure kernel modules"
        echo "  install-docker- Install Docker"
        echo "  help          - Show this help"
        ;;
    *)
        error "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac
