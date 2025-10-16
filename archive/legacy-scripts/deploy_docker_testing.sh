#!/bin/bash

# =====================================================
# 🐳 Docker-Only Homelab Deployment
# =====================================================
# Deploys homelab services using Docker Compose only
# Perfect for testing on any system with Docker
# No VMs or LXC containers required
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
HOMELAB_DIR="$(pwd)"
COMPOSE_FILE="docker-compose.testing.yml"

# Functions
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
step() { echo -e "${PURPLE}[STEP] $1${NC}"; }

# Check if Docker is available
check_docker() {
    step "Checking Docker availability..."
    
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed"
        echo "Install Docker from: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        error "Docker daemon is not running"
        echo "Start Docker and try again"
        exit 1
    fi
    
    success "Docker is available"
}

# Create testing Docker Compose configuration
create_testing_compose() {
    step "Creating Docker Compose configuration for testing..."
    
    cat > "$COMPOSE_FILE" << 'EOF'
version: '3.8'

services:
  # Jellyfin Media Server
  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - jellyfin_config:/config
      - jellyfin_cache:/cache
      - ./media:/media:ro
    ports:
      - "8096:8096"
    restart: unless-stopped
    networks:
      - homelab

  # Sonarr (TV Shows)
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - sonarr_config:/config
      - ./media/tv:/tv
      - ./downloads:/downloads
    ports:
      - "8989:8989"
    restart: unless-stopped
    networks:
      - homelab

  # Radarr (Movies)
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - radarr_config:/config
      - ./media/movies:/movies
      - ./downloads:/downloads
    ports:
      - "7878:7878"
    restart: unless-stopped
    networks:
      - homelab

  # Prowlarr (Indexer Management)
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - prowlarr_config:/config
    ports:
      - "9696:9696"
    restart: unless-stopped
    networks:
      - homelab

  # qBittorrent
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
      - WEBUI_PORT=8080
    volumes:
      - qbittorrent_config:/config
      - ./downloads:/downloads
    ports:
      - "8080:8080"
    restart: unless-stopped
    networks:
      - homelab

  # Nginx Proxy Manager
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: npm
    environment:
      - PUID=1000
      - PGID=1000
    volumes:
      - npm_data:/data
      - npm_letsencrypt:/etc/letsencrypt
    ports:
      - "80:80"
      - "443:443"
      - "81:81"
    restart: unless-stopped
    networks:
      - homelab

  # Pi-hole DNS
  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    environment:
      - TZ=America/New_York
      - WEBPASSWORD=admin123
      - PIHOLE_DNS_1=1.1.1.1
      - PIHOLE_DNS_2=1.0.0.1
    volumes:
      - pihole_etc:/etc/pihole
      - pihole_dnsmasq:/etc/dnsmasq.d
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "8053:80"
    restart: unless-stopped
    networks:
      - homelab

  # Vaultwarden (Bitwarden)
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    environment:
      - WEBSOCKET_ENABLED=true
      - SIGNUPS_ALLOWED=false
      - ADMIN_TOKEN=your-admin-token-here
    volumes:
      - vaultwarden_data:/data
    ports:
      - "8200:80"
    restart: unless-stopped
    networks:
      - homelab

  # NTFY Notifications
  ntfy:
    image: binwiederhier/ntfy:latest
    container_name: ntfy
    command: serve
    environment:
      - NTFY_BASE_URL=http://localhost:8300
    volumes:
      - ntfy_cache:/var/cache/ntfy
      - ntfy_etc:/etc/ntfy
    ports:
      - "8300:80"
    restart: unless-stopped
    networks:
      - homelab

  # Monitoring - Netdata
  netdata:
    image: netdata/netdata:latest
    container_name: netdata
    hostname: netdata
    environment:
      - PGID=999
    volumes:
      - netdata_lib:/var/lib/netdata
      - netdata_cache:/var/cache/netdata
      - /etc/passwd:/host/etc/passwd:ro
      - /etc/group:/host/etc/group:ro
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /etc/os-release:/host/etc/os-release:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    ports:
      - "19999:19999"
    restart: unless-stopped
    cap_add:
      - SYS_PTRACE
    security_opt:
      - apparmor:unconfined
    networks:
      - homelab

volumes:
  jellyfin_config:
  jellyfin_cache:
  sonarr_config:
  radarr_config:
  prowlarr_config:
  qbittorrent_config:
  npm_data:
  npm_letsencrypt:
  pihole_etc:
  pihole_dnsmasq:
  vaultwarden_data:
  ntfy_cache:
  ntfy_etc:
  netdata_lib:
  netdata_cache:

networks:
  homelab:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF

    success "Docker Compose configuration created: $COMPOSE_FILE"
}

# Create directory structure
create_directories() {
    step "Creating directory structure..."
    
    mkdir -p media/{movies,tv,music}
    mkdir -p downloads/{complete,incomplete}
    mkdir -p config/{jellyfin,sonarr,radarr,prowlarr,qbittorrent,npm,pihole,vaultwarden,ntfy}
    
    success "Directory structure created"
}

# Create sample media files
create_sample_content() {
    step "Creating sample content..."
    
    # Create sample movie
    mkdir -p "media/movies/Sample Movie (2023)"
    echo "This is a sample movie file for testing" > "media/movies/Sample Movie (2023)/sample-movie.txt"
    
    # Create sample TV show
    mkdir -p "media/tv/Sample TV Show/Season 01"
    echo "This is a sample TV episode for testing" > "media/tv/Sample TV Show/Season 01/Sample.S01E01.mkv.txt"
    
    success "Sample content created"
}

# Deploy services
deploy_services() {
    step "Deploying homelab services..."
    
    log "Pulling Docker images (this may take a while)..."
    docker-compose -f "$COMPOSE_FILE" pull
    
    log "Starting services..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    success "Services deployed"
}

# Show service status
show_status() {
    step "Checking service status..."
    
    docker-compose -f "$COMPOSE_FILE" ps
    
    echo
    success "Services are starting up - it may take a few minutes for all to be ready"
}

# Show access URLs
show_access_info() {
    step "Service Access Information"
    echo
    echo "🌐 Web Interfaces:"
    echo "  • Jellyfin Media Server:     http://localhost:8096"
    echo "  • Sonarr (TV Shows):         http://localhost:8989"
    echo "  • Radarr (Movies):           http://localhost:7878"
    echo "  • Prowlarr (Indexers):       http://localhost:9696"
    echo "  • qBittorrent:               http://localhost:8080"
    echo "  • Nginx Proxy Manager:       http://localhost:81"
    echo "  • Pi-hole DNS:               http://localhost:8053"
    echo "  • Vaultwarden:               http://localhost:8200"
    echo "  • NTFY Notifications:        http://localhost:8300"
    echo "  • Netdata Monitoring:        http://localhost:19999"
    echo
    echo "🔐 Default Credentials:"
    echo "  • Pi-hole Admin:             admin123"
    echo "  • Nginx Proxy Manager:       admin@example.com / changeme"
    echo "  • qBittorrent:                admin / adminpass"
    echo
    echo "📁 Directories:"
    echo "  • Media: ./media (movies, tv, music)"
    echo "  • Downloads: ./downloads"
    echo "  • Config: Docker volumes"
    echo
    echo "🔧 Management Commands:"
    echo "  • View logs: docker-compose -f $COMPOSE_FILE logs [service]"
    echo "  • Restart: docker-compose -f $COMPOSE_FILE restart [service]"
    echo "  • Stop all: docker-compose -f $COMPOSE_FILE down"
    echo "  • Update: docker-compose -f $COMPOSE_FILE pull && docker-compose -f $COMPOSE_FILE up -d"
}

# Stop services
stop_services() {
    step "Stopping homelab services..."
    docker-compose -f "$COMPOSE_FILE" down
    success "Services stopped"
}

# Remove everything
cleanup() {
    step "Removing all homelab services and data..."
    
    read -p "This will remove all containers and volumes. Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose -f "$COMPOSE_FILE" down -v --remove-orphans
        docker system prune -f
        success "Cleanup completed"
    else
        log "Cleanup cancelled"
    fi
}

# Main execution
main() {
    echo "================================================================"
    echo "🐳 HOMELAB DOCKER TESTING DEPLOYMENT"
    echo "================================================================"
    echo "Platform: Docker Compose"
    echo "Location: $(pwd)"
    echo "Timestamp: $(date)"
    echo "================================================================"
    echo
    
    check_docker
    create_testing_compose
    create_directories
    create_sample_content
    deploy_services
    show_status
    show_access_info
    
    success "Docker homelab deployment completed!"
    echo
    echo "🎉 Your homelab is now running in Docker containers!"
    echo "📖 See service URLs above to access your applications"
}

# Handle command line arguments
case "${1:-deploy}" in
    "deploy"|"start")
        main
        ;;
    "stop")
        stop_services
        ;;
    "status")
        show_status
        ;;
    "logs")
        docker-compose -f "$COMPOSE_FILE" logs -f "${2:-}"
        ;;
    "restart")
        docker-compose -f "$COMPOSE_FILE" restart "${2:-}"
        ;;
    "update")
        docker-compose -f "$COMPOSE_FILE" pull
        docker-compose -f "$COMPOSE_FILE" up -d
        success "Services updated"
        ;;
    "cleanup")
        cleanup
        ;;
    "info")
        show_access_info
        ;;
    *)
        echo "Usage: $0 [deploy|stop|status|logs|restart|update|cleanup|info]"
        echo "  deploy  - Deploy all services (default)"
        echo "  stop    - Stop all services"
        echo "  status  - Show service status"
        echo "  logs    - Show logs (optionally specify service)"
        echo "  restart - Restart services (optionally specify service)"
        echo "  update  - Update all images and restart"
        echo "  cleanup - Remove all containers and data"
        echo "  info    - Show access information"
        exit 1
        ;;
esac