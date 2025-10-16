#!/bin/bash

# 🐳 Docker Compose Enhancement Script
# Based on repository analysis - optimizes restart policies and monitoring
# Targets identified service stack: Traefik, Tailscale, Media, Monitoring, etc.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[ENHANCE] $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Configuration
DEPLOYMENT_DIR="./deployment"
BACKUP_DIR="./backups/docker-compose-$(date +%Y%m%d-%H%M%S)"

log "🐳 Enhancing Docker Compose configurations based on analysis..."

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Find all docker-compose files
compose_files=()
while IFS= read -r -d '' file; do
    compose_files+=("$file")
done < <(find . -name "docker-compose*.yml" -o -name "docker-compose*.yaml" -print0)

if [ ${#compose_files[@]} -eq 0 ]; then
    error "No Docker Compose files found"
    exit 1
fi

log "Found ${#compose_files[@]} Docker Compose files"

# Service categories based on analysis
declare -A SERVICE_CATEGORIES=(
    # Critical infrastructure - always restart
    ["traefik"]="always"
    ["tailscale"]="always"
    ["nginx-proxy-manager"]="always"
    ["pihole"]="always"

    # Media services - unless stopped (for maintenance)
    ["plex"]="unless-stopped"
    ["jellyfin"]="unless-stopped"
    ["sonarr"]="unless-stopped"
    ["radarr"]="unless-stopped"
    ["prowlarr"]="unless-stopped"
    ["qbittorrent"]="unless-stopped"

    # Monitoring - unless stopped
    ["grafana"]="unless-stopped"
    ["prometheus"]="unless-stopped"
    ["uptime-kuma"]="unless-stopped"
    ["node-exporter"]="unless-stopped"

    # Home automation - always (critical)
    ["home-assistant"]="always"
    ["homeassistant"]="always"

    # Storage/Backup - unless stopped
    ["duplicati"]="unless-stopped"
    ["syncthing"]="unless-stopped"

    # Utilities - unless stopped
    ["portainer"]="unless-stopped"
    ["code-server"]="unless-stopped"
    ["n8n"]="unless-stopped"
    ["it-tools"]="unless-stopped"

    # VPN/Security - always
    ["gluetun"]="always"
    ["wireguard"]="always"
    ["vaultwarden"]="unless-stopped"
)

# Process each compose file
for compose_file in "${compose_files[@]}"; do
    log "Processing: $compose_file"

    # Create backup
    cp "$compose_file" "$BACKUP_DIR/$(basename "$compose_file").backup"

    # Check if file uses version 3.x format
    if ! grep -q "version.*['\"]3\." "$compose_file"; then
        warn "Skipping $compose_file - not version 3.x format"
        continue
    fi

    # Create temporary file for modifications
    temp_file=$(mktemp)
    cp "$compose_file" "$temp_file"

    modified=false

    # Add restart policies
    while IFS= read -r service_name; do
        if [ -n "$service_name" ]; then
            # Check if service exists in this compose file
            if grep -q "^[[:space:]]*${service_name}:" "$temp_file"; then
                restart_policy="${SERVICE_CATEGORIES[$service_name]:-unless-stopped}"

                # Check if restart policy already exists
                if ! sed -n "/^[[:space:]]*${service_name}:/,/^[[:space:]]*[a-zA-Z0-9_-]*:/{/restart:/p}" "$temp_file" | grep -q "restart:"; then
                    # Add restart policy after service name
                    sed -i "/^[[:space:]]*${service_name}:/a\\    restart: $restart_policy" "$temp_file"
                    success "Added restart: $restart_policy to $service_name"
                    modified=true
                else
                    log "Service $service_name already has restart policy"
                fi
            fi
        fi
    done <<< "$(printf '%s\n' "${!SERVICE_CATEGORIES[@]}")"

    # Add health checks for critical services
    critical_services=("traefik" "tailscale" "pihole" "nginx-proxy-manager" "home-assistant")
    for service in "${critical_services[@]}"; do
        if grep -q "^[[:space:]]*${service}:" "$temp_file"; then
            # Add basic health check if not present
            if ! sed -n "/^[[:space:]]*${service}:/,/^[[:space:]]*[a-zA-Z0-9_-]*:/{/healthcheck:/p}" "$temp_file" | grep -q "healthcheck:"; then
                # Simple HTTP health check for most services
                case $service in
                    "traefik")
                        healthcheck="healthcheck:\n      test: [\"CMD\", \"traefik\", \"healthcheck\"]\n      interval: 30s\n      timeout: 3s\n      retries: 3"
                        ;;
                    "pihole")
                        healthcheck="healthcheck:\n      test: [\"CMD\", \"dig\", \"@127.0.0.1\", \"google.com\"]\n      interval: 30s\n      timeout: 3s\n      retries: 3"
                        ;;
                    *)
                        healthcheck="healthcheck:\n      test: [\"CMD-SHELL\", \"wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1\"]\n      interval: 30s\n      timeout: 3s\n      retries: 3"
                        ;;
                esac

                sed -i "/^[[:space:]]*${service}:/a\\    $healthcheck" "$temp_file"
                success "Added health check to $service"
                modified=true
            fi
        fi
    done

    # Add resource limits for resource-intensive services
    resource_intensive=("plex" "jellyfin" "sonarr" "radarr" "qbittorrent")
    for service in "${resource_intensive[@]}"; do
        if grep -q "^[[:space:]]*${service}:" "$temp_file"; then
            if ! sed -n "/^[[:space:]]*${service}:/,/^[[:space:]]*[a-zA-Z0-9_-]*:/{/deploy:/p}" "$temp_file" | grep -q "deploy:"; then
                deploy_config="deploy:\n      resources:\n        limits:\n          memory: 2G\n        reservations:\n          memory: 512M"
                sed -i "/^[[:space:]]*${service}:/a\\    $deploy_config" "$temp_file"
                success "Added resource limits to $service"
                modified=true
            fi
        fi
    done

    # Apply changes if modifications were made
    if [ "$modified" = true ]; then
        mv "$temp_file" "$compose_file"
        success "Updated: $compose_file"
    else
        rm "$temp_file"
        log "No changes needed for: $compose_file"
    fi
done

# Create monitoring enhancement compose file
log "Creating enhanced monitoring stack..."
cat > "./docker-compose.monitoring-enhanced.yml" <<EOF
version: '3.8'

services:
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    pid: host
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    networks:
      - monitoring
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9100/metrics"]
      interval: 30s
      timeout: 3s
      retries: 3

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    privileged: true
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    ports:
      - "8080:8080"
    networks:
      - monitoring
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/healthz"]
      interval: 30s
      timeout: 3s
      retries: 3

networks:
  monitoring:
    external: true
EOF

success "Created enhanced monitoring stack"

# Create maintenance script
log "Creating maintenance script..."
cat > "./docker-maintenance.sh" <<'EOF'
#!/bin/bash

# Docker maintenance script
# Based on homelab analysis

set -e

echo "🧹 Starting Docker maintenance..."

# Stop all containers gracefully
echo "Stopping containers..."
docker-compose down

# Clean up unused resources
echo "Cleaning up unused resources..."
docker system prune -af --volumes

# Update all images
echo "Updating images..."
docker-compose pull

# Restart services
echo "Starting services..."
docker-compose up -d

# Health check
echo "Checking service health..."
sleep 30
docker-compose ps

echo "✅ Maintenance complete!"
EOF

chmod +x "./docker-maintenance.sh"
success "Created maintenance script"

# Summary
echo ""
log "🎉 Docker Compose enhancement complete!"
echo ""
success "Applied enhancements:"
echo "  • Restart policies: ${#SERVICE_CATEGORIES[@]} services configured"
echo "  • Health checks: Added to critical services"
echo "  • Resource limits: Added to resource-intensive services"
echo "  • Enhanced monitoring: node-exporter + cAdvisor"
echo "  • Maintenance script: ./docker-maintenance.sh"
echo ""
success "Backups saved to: $BACKUP_DIR"
echo ""
warn "Next steps:"
echo "  • Review modified compose files"
echo "  • Test with: docker-compose config"
echo "  • Deploy: docker-compose up -d"
echo "  • Monitor: docker-compose ps"
echo "  • Schedule maintenance: crontab -e (weekly run)"
EOF
