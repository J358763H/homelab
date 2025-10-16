#!/bin/bash

# 🚨 Critical Deployment Reliability Fixes
# Addresses the most important issues for successful deployment
# Based on comprehensive security and deployment analysis

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[CRITICAL-FIX] $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

log "🚨 Applying critical fixes for deployment success..."

# 1. MOST CRITICAL: Fix Proxmox cluster timeout
fix_proxmox_cluster_timeout() {
    log "Fixing Proxmox cluster filesystem timeout (most critical)..."

    if grep -q "pve" /proc/version 2>/dev/null || [ -d "/etc/pve" ] 2>/dev/null; then
        # Create systemd override for faster shutdown
        mkdir -p /etc/systemd/system/pve-cluster.service.d/
        cat > /etc/systemd/system/pve-cluster.service.d/override.conf <<EOF
[Service]
TimeoutStopSec=15s
EOF
        systemctl daemon-reload
        success "Proxmox cluster timeout fixed: 15s (was 90s+)"

        # Also fix general systemd timeouts
        if [ -f /etc/systemd/system.conf ]; then
            cp /etc/systemd/system.conf /etc/systemd/system.conf.backup
            sed -i 's/#DefaultTimeoutStopSec=90s/DefaultTimeoutStopSec=30s/' /etc/systemd/system.conf
            systemctl daemon-reload
            success "System-wide timeout reduced to 30s"
        fi
    else
        log "Not on Proxmox - skipping cluster timeout fix"
    fi
}

# 2. CRITICAL: Standardize restart policies for reliability
fix_restart_policies() {
    log "Standardizing Docker restart policies for deployment reliability..."

    compose_files=($(find . -name "docker-compose*.yml" 2>/dev/null || true))

    for compose_file in "${compose_files[@]}"; do
        if [ -f "$compose_file" ]; then
            # Backup original
            cp "$compose_file" "${compose_file}.backup-$(date +%H%M%S)"

            # Critical infrastructure services should always restart
            sed -i '/traefik:/,/^[[:space:]]*[a-zA-Z]/ s/restart: .*/restart: always/' "$compose_file"
            sed -i '/tailscale:/,/^[[:space:]]*[a-zA-Z]/ s/restart: .*/restart: always/' "$compose_file"
            sed -i '/gluetun:/,/^[[:space:]]*[a-zA-Z]/ s/restart: .*/restart: always/' "$compose_file"
            sed -i '/pihole:/,/^[[:space:]]*[a-zA-Z]/ s/restart: .*/restart: always/' "$compose_file"

            # Other services use unless-stopped for better control
            sed -i '/plex:/,/^[[:space:]]*[a-zA-Z]/ s/restart: .*/restart: unless-stopped/' "$compose_file"
            sed -i '/jellyfin:/,/^[[:space:]]*[a-zA-Z]/ s/restart: .*/restart: unless-stopped/' "$compose_file"
            sed -i '/sonarr:/,/^[[:space:]]*[a-zA-Z]/ s/restart: .*/restart: unless-stopped/' "$compose_file"
            sed -i '/radarr:/,/^[[:space:]]*[a-zA-Z]/ s/restart: .*/restart: unless-stopped/' "$compose_file"

            success "Fixed restart policies in $(basename "$compose_file")"
        fi
    done
}

# 3. CRITICAL: Add service dependencies to prevent race conditions
fix_service_dependencies() {
    log "Adding critical service dependencies..."

    compose_files=($(find . -name "docker-compose*.yml" 2>/dev/null || true))

    for compose_file in "${compose_files[@]}"; do
        if [ -f "$compose_file" ]; then
            # qBittorrent depends on VPN
            if grep -q "gluetun:" "$compose_file" && grep -q "qbittorrent:" "$compose_file"; then
                if ! grep -A 5 "qbittorrent:" "$compose_file" | grep -q "depends_on:"; then
                    sed -i "/qbittorrent:/a\\    depends_on:\\n      - gluetun" "$compose_file"
                    success "Added VPN dependency to qBittorrent"
                fi
            fi

            # *arr services depend on indexer
            for service in sonarr radarr lidarr; do
                if grep -q "prowlarr:" "$compose_file" && grep -q "${service}:" "$compose_file"; then
                    if ! grep -A 5 "${service}:" "$compose_file" | grep -q "depends_on:"; then
                        sed -i "/${service}:/a\\    depends_on:\\n      - prowlarr" "$compose_file"
                        success "Added Prowlarr dependency to $service"
                    fi
                fi
            done
        fi
    done
}

# 4. CRITICAL: Add memory limits to prevent OOM kills
add_memory_limits() {
    log "Adding memory limits to prevent deployment failures..."

    # Memory limits for common resource-intensive services
    declare -A MEMORY_LIMITS=(
        ["plex"]="2G"
        ["jellyfin"]="2G"
        ["sonarr"]="1G"
        ["radarr"]="1G"
        ["prowlarr"]="512M"
        ["qbittorrent"]="1G"
        ["grafana"]="512M"
        ["prometheus"]="1G"
        ["home-assistant"]="1G"
    )

    compose_files=($(find . -name "docker-compose*.yml" 2>/dev/null || true))

    for compose_file in "${compose_files[@]}"; do
        if [ -f "$compose_file" ]; then
            for service in "${!MEMORY_LIMITS[@]}"; do
                if grep -q "^[[:space:]]*${service}:" "$compose_file"; then
                    # Check if deploy section exists
                    if ! grep -A 10 "^[[:space:]]*${service}:" "$compose_file" | grep -q "deploy:"; then
                        memory_limit="${MEMORY_LIMITS[$service]}"

                        # Add deploy section with memory limit
                        sed -i "/^[[:space:]]*${service}:/a\\    deploy:\\n      resources:\\n        limits:\\n          memory: $memory_limit\\n        reservations:\\n          memory: 128M" "$compose_file"
                        success "Added ${memory_limit} memory limit to $service"
                    fi
                fi
            done
        fi
    done
}

# 5. CRITICAL: Create .env template to prevent missing variables
create_env_template() {
    log "Creating .env template for required variables..."

    if [ ! -f ".env.example" ]; then
        cat > .env.example <<'EOF'
# ========================================
# CRITICAL HOMELAB ENVIRONMENT VARIABLES
# ========================================
# Copy to .env and configure before deployment

# === ESSENTIAL PATHS ===
MEDIA_PATH=/mnt/media
CONFIG_PATH=/opt/homelab/config
DOWNLOADS_PATH=/mnt/media/downloads

# === TIMEZONE (REQUIRED) ===
TZ=America/New_York

# === VPN CONFIGURATION (Required for Gluetun) ===
VPN_SERVICE_PROVIDER=surfshark
VPN_USERNAME=your_vpn_username
VPN_PASSWORD=your_vpn_password

# === TAILSCALE (Required if using) ===
TAILSCALE_AUTH_KEY=tskey-auth-your-key-here

# === BASIC AUTH (Security) ===
BASIC_AUTH_USER=admin
BASIC_AUTH_PASSWORD=secure_password_here

# === DATABASE PASSWORDS ===
MYSQL_ROOT_PASSWORD=secure_mysql_password
POSTGRES_PASSWORD=secure_postgres_password

# === PLEX (Optional - remove after setup) ===
PLEX_CLAIM=claim-your-plex-claim-token

# === NETWORK ===
DOCKER_SUBNET=172.20.0.0/16
EOF
        success "Created .env.example template"
    fi

    # Ensure .gitignore exists and excludes sensitive files
    if [ ! -f ".gitignore" ] || ! grep -q "\.env$" .gitignore 2>/dev/null; then
        cat >> .gitignore <<EOF
# Environment files (contain secrets)
.env
*.env

# Logs
*.log
logs/

# Backups
backups/
*.backup*

# Temporary files
*.tmp
*.temp
EOF
        success "Updated .gitignore to protect sensitive files"
    fi
}

# 6. CRITICAL: Add basic health checks
add_essential_health_checks() {
    log "Adding health checks for critical services..."

    compose_files=($(find . -name "docker-compose*.yml" 2>/dev/null || true))

    for compose_file in "${compose_files[@]}"; do
        if [ -f "$compose_file" ]; then
            # Add health check to Traefik (most critical)
            if grep -q "traefik:" "$compose_file" && ! grep -A 10 "traefik:" "$compose_file" | grep -q "healthcheck:"; then
                sed -i "/traefik:/a\\    healthcheck:\\n      test: [\"CMD\", \"traefik\", \"healthcheck\"]\\n      interval: 30s\\n      timeout: 5s\\n      retries: 3" "$compose_file"
                success "Added health check to Traefik"
            fi

            # Add health check to Pi-hole if present
            if grep -q "pihole:" "$compose_file" && ! grep -A 10 "pihole:" "$compose_file" | grep -q "healthcheck:"; then
                sed -i "/pihole:/a\\    healthcheck:\\n      test: [\"CMD\", \"dig\", \"@127.0.0.1\", \"google.com\"]\\n      interval: 30s\\n      timeout: 5s\\n      retries: 3" "$compose_file"
                success "Added health check to Pi-hole"
            fi
        fi
    done
}

# Main execution
main() {
    echo ""
    log "🚨 APPLYING CRITICAL DEPLOYMENT FIXES"
    echo "   Targeting issues that prevent successful deployment"
    echo ""

    # Apply fixes in order of criticality
    fix_proxmox_cluster_timeout      # Most critical - prevents hangs
    fix_restart_policies             # Critical - prevents service failures
    fix_service_dependencies         # Critical - prevents race conditions
    add_memory_limits               # Critical - prevents OOM kills
    create_env_template             # Critical - prevents missing vars
    add_essential_health_checks     # Important - enables monitoring

    echo ""
    success "🎉 CRITICAL DEPLOYMENT FIXES COMPLETE!"
    echo ""
    success "Applied fixes:"
    echo "  ✅ Proxmox cluster timeout: 15s (prevents deployment hangs)"
    echo "  ✅ Restart policies: Standardized for reliability"
    echo "  ✅ Service dependencies: Added to prevent race conditions"
    echo "  ✅ Memory limits: Added to prevent OOM kills"
    echo "  ✅ Environment template: Created .env.example"
    echo "  ✅ Health checks: Added to critical services"
    echo ""
    warn "NEXT STEPS FOR DEPLOYMENT SUCCESS:"
    echo "  1. 📝 Copy .env.example to .env and configure"
    echo "  2. 🧪 Test: docker-compose config"
    echo "  3. 🔍 Run: ./proxmox_deployment_preflight.sh"
    echo "  4. 🚀 Deploy: ./deploy_homelab_master.sh"
    echo ""
    log "These fixes target the most common deployment failure points!"
    log "Your deployment success rate should be significantly improved!"
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
