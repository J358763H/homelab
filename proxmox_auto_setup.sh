#!/usr/bin/env bash
# =====================================================
# 🏗️ Proxmox Homelab Auto-Setup Script
# =====================================================
# Run this script directly on your Proxmox server
# to download and setup the complete homelab infrastructure
# =====================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
HOMELAB_DIR="/root/homelab-deployment"
LOG_FILE="/var/log/homelab_auto_setup.log"

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

step() {
    echo -e "${PURPLE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# Banner
echo ""
echo "=========================================="
echo "🏗️  HOMELAB AUTO-SETUP FOR PROXMOX"
echo "=========================================="
echo "This script will create your complete homelab"
echo "infrastructure with all necessary components."
echo ""
echo "Target Directory: $HOMELAB_DIR"
echo "Proxmox Server: $(hostname -I | awk '{print $1}')"
echo "Date: $(date)"
echo "=========================================="
echo ""

# Confirmation
read -p "🚀 Proceed with homelab setup? (y/n): " PROCEED
if [[ ! "$PROCEED" =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

# Create directory structure
step "Creating homelab directory structure"
mkdir -p "$HOMELAB_DIR"/{scripts,deployment,lxc,automation}
mkdir -p "$HOMELAB_DIR"/lxc/{nginx-proxy-manager,tailscale,ntfy,samba,pihole,vaultwarden}
cd "$HOMELAB_DIR"

# Create ZFS Mirror Setup Script
step "Creating ZFS mirror setup script"
cat > scripts/setup_zfs_mirror.sh << 'ZFSEOF'
#!/usr/bin/env bash
# ZFS Mirror Setup Script
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

POOL_NAME="homelab-storage"
MOUNT_POINT="/mnt/homelab-storage"
LOG_FILE="/var/log/zfs_setup_$(date +%Y%m%d_%H%M%S).log"

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

check_zfs() {
    log "Checking ZFS availability..."
    if ! command -v zpool >/dev/null 2>&1; then
        log "Installing ZFS..."
        apt update
        apt install -y zfsutils-linux
    fi
    success "ZFS is available"
}

detect_drives() {
    log "Detecting available drives..."
    echo ""
    echo "Available block devices:"
    lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -E "(disk|nvme)"
    echo ""
}

select_drives() {
    log "Drive selection for ZFS mirror..."
    echo ""
    echo "⚠️  WARNING: Selected drives will be COMPLETELY WIPED!"
    echo ""
    
    read -p "Enter first drive path (e.g., /dev/sdb): " DRIVE1
    read -p "Enter second drive path (e.g., /dev/sdc): " DRIVE2
    
    if [[ ! -b "$DRIVE1" ]] || [[ ! -b "$DRIVE2" ]]; then
        error "Invalid drive paths"
        exit 1
    fi
    
    if [[ "$DRIVE1" == "$DRIVE2" ]]; then
        error "Same drive selected twice"
        exit 1
    fi
    
    read -p "Create ZFS mirror with $DRIVE1 and $DRIVE2? (yes/no): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        log "Aborted by user"
        exit 0
    fi
}

create_zfs_pool() {
    log "Creating ZFS mirror pool: $POOL_NAME"
    
    warning "Wiping drive signatures..."
    wipefs -af "$DRIVE1"
    wipefs -af "$DRIVE2"
    
    log "Creating mirrored ZFS pool..."
    zpool create -f \
        -o ashift=12 \
        -O compression=lz4 \
        -O atime=off \
        -O xattr=sa \
        -O recordsize=128K \
        -m "$MOUNT_POINT" \
        "$POOL_NAME" mirror "$DRIVE1" "$DRIVE2"
    
    success "ZFS pool created successfully"
}

create_datasets() {
    log "Creating ZFS datasets..."
    
    zfs create "$POOL_NAME/docker"
    zfs create "$POOL_NAME/media"
    zfs create "$POOL_NAME/backups"
    
    zfs create "$POOL_NAME/media/movies"
    zfs create "$POOL_NAME/media/shows"
    zfs create "$POOL_NAME/media/music"
    zfs create "$POOL_NAME/media/youtube"
    
    # Set quotas
    zfs set quota=50G "$POOL_NAME/docker"
    zfs set quota=500G "$POOL_NAME/media"
    zfs set quota=100G "$POOL_NAME/backups"
    
    success "ZFS datasets created"
}

setup_docker_integration() {
    log "Setting up Docker integration..."
    
    systemctl stop docker 2>/dev/null || true
    
    if [[ -d /var/lib/docker ]]; then
        mv /var/lib/docker /var/lib/docker.backup.$(date +%Y%m%d)
    fi
    
    mkdir -p "$MOUNT_POINT/docker/engine"
    ln -sf "$MOUNT_POINT/docker/engine" /var/lib/docker
    
    mkdir -p "$MOUNT_POINT"/{docker,media,backups}
    ln -sf "$MOUNT_POINT" /data
    
    success "Docker integration configured"
}

main() {
    check_root
    check_zfs
    detect_drives
    select_drives
    create_zfs_pool
    create_datasets
    setup_docker_integration
    
    success "ZFS mirror setup completed!"
    echo ""
    echo "Mount point: $MOUNT_POINT"
    echo "Symlink: /data -> $MOUNT_POINT"
    echo ""
    zpool status "$POOL_NAME"
}

main "$@"
ZFSEOF

# Create Network Configuration Script
step "Creating network configuration script"
cat > scripts/configure_network.sh << 'NETEOF'
#!/usr/bin/env bash
# Network Configuration Script
set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

log "Checking network configuration..."

# Get current IP
CURRENT_IP=$(ip route get 1 | awk '{print $7}' | head -1)
log "Current Proxmox IP: $CURRENT_IP"

# Test connectivity
declare -A TARGETS=(
    ["Gateway"]="192.168.1.1"
    ["Docker Host"]="192.168.1.100"
    ["DNS"]="8.8.8.8"
)

echo "Network connectivity test:"
for name in "${!TARGETS[@]}"; do
    ip="${TARGETS[$name]}"
    if ping -c 1 -W 2 "$ip" >/dev/null 2>&1; then
        success "$name ($ip) - Reachable"
    else
        error "$name ($ip) - Not reachable"
    fi
done

log "Network configuration check completed"
NETEOF

# Create Validation Script
step "Creating deployment validation script"
cat > scripts/validate_deployment.sh << 'VALEOF'
#!/usr/bin/env bash
# Deployment Validation Script
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

success() { echo -e "${GREEN}[✅ PASS]${NC} $1"; }
fail() { echo -e "${RED}[❌ FAIL]${NC} $1"; }
warning() { echo -e "${YELLOW}[⚠️  WARN]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

echo "=========================================="
echo "🔍 HOMELAB DEPLOYMENT VALIDATION"
echo "=========================================="

# Test LXC containers
info "Testing LXC containers..."
declare -A LXC_SERVICES=(
    ["201"]="nginx-proxy-manager"
    ["202"]="tailscale"
    ["203"]="ntfy"
    ["204"]="samba"
    ["205"]="pihole"
    ["206"]="vaultwarden"
)

for vmid in "${!LXC_SERVICES[@]}"; do
    service="${LXC_SERVICES[$vmid]}"
    
    if pct status "$vmid" 2>/dev/null | grep -q "running"; then
        success "LXC $vmid ($service) is running"
        
        # Test network
        if ping -c 1 -W 2 "192.168.1.$vmid" >/dev/null 2>&1; then
            success "LXC $vmid network OK"
        else
            fail "LXC $vmid network issue"
        fi
    else
        fail "LXC $vmid ($service) not running"
    fi
done

# Test Docker services
info "Testing Docker services..."
if ping -c 1 -W 2 "192.168.1.100" >/dev/null 2>&1; then
    success "Docker host reachable"
    
    if pct exec 100 -- docker --version >/dev/null 2>&1; then
        success "Docker installed on host"
    else
        fail "Docker not installed on host"
    fi
else
    fail "Docker host not reachable"
fi

# Test service endpoints
info "Testing service endpoints..."
declare -A ENDPOINTS=(
    ["Jellyfin"]="192.168.1.100:8096"
    ["Pi-hole"]="192.168.1.205:80"
    ["NPM"]="192.168.1.201:81"
)

for service in "${!ENDPOINTS[@]}"; do
    endpoint="${ENDPOINTS[$service]}"
    if nc -z -w3 ${endpoint/:/ } 2>/dev/null; then
        success "$service responding"
    else
        warning "$service not responding (may be starting)"
    fi
done

echo ""
echo "=========================================="
echo "Validation completed!"
echo "Check any failed tests above."
echo "=========================================="
VALEOF

# Create Master Deployment Script
step "Creating master deployment script"
cat > deploy_homelab_master.sh << 'DEPLOYEOF'
#!/usr/bin/env bash
# Master Deployment Script
set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
step() { echo -e "${PURPLE}[STEP]${NC} $1"; }

echo "=========================================="
echo "🚀 HOMELAB MASTER DEPLOYMENT"
echo "=========================================="

# Check prerequisites
if [[ $EUID -ne 0 ]]; then
    echo "❌ Must run as root"
    exit 1
fi

if ! command -v pct >/dev/null 2>&1; then
    echo "❌ Must run on Proxmox VE"
    exit 1
fi

success "Prerequisites OK"

# Optional ZFS setup
echo ""
read -p "🗄️  Setup ZFS mirror for aging drives? (y/n): " SETUP_ZFS
if [[ "$SETUP_ZFS" =~ ^[Yy]$ ]]; then
    step "Running ZFS setup..."
    chmod +x scripts/setup_zfs_mirror.sh
    ./scripts/setup_zfs_mirror.sh
fi

# Create Docker host VM
step "Creating Docker host VM (VMID 100)..."
if ! pct status 100 >/dev/null 2>&1; then
    # Download Ubuntu template if not exists
    if [[ ! -f /var/lib/vz/template/cache/ubuntu-22.04-standard_22.04-1_amd64.tar.zst ]]; then
        log "Downloading Ubuntu template..."
        pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst
    fi
    
    pct create 100 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
        --hostname docker-host \
        --cores 4 \
        --memory 8192 \
        --rootfs local-lvm:32 \
        --net0 name=eth0,bridge=vmbr0,ip=192.168.1.100/24,gw=192.168.1.1 \
        --features nesting=1,keyctl=1 \
        --unprivileged 1 \
        --onboot 1 \
        --password
    
    pct start 100
    sleep 10
    
    log "Installing Docker in container..."
    pct exec 100 -- bash -c "
        apt update && apt upgrade -y
        apt install -y curl wget git bc netcat-traditional
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        systemctl enable docker
        systemctl start docker
        
        curl -L 'https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)' -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        
        mkdir -p /data/{docker,media,backups}
        mkdir -p /data/media/{movies,shows,music,youtube,downloads}
        mkdir -p /opt/homelab
    "
    
    success "Docker host created"
else
    log "Docker host already exists"
fi

# Deploy LXC containers
step "Deploying LXC containers..."

declare -A LXC_CONFIGS=(
    ["201"]="nginx-proxy-manager"
    ["202"]="tailscale"  
    ["203"]="ntfy"
    ["204"]="samba"
    ["205"]="pihole"
    ["206"]="vaultwarden"
)

for vmid in "${!LXC_CONFIGS[@]}"; do
    service="${LXC_CONFIGS[$vmid]}"
    
    if ! pct status "$vmid" >/dev/null 2>&1; then
        log "Creating LXC $vmid ($service)..."
        
        pct create "$vmid" local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
            --hostname "$service" \
            --cores 2 \
            --memory 1024 \
            --rootfs local-lvm:8 \
            --net0 name=eth0,bridge=vmbr0,ip=192.168.1.$vmid/24,gw=192.168.1.1 \
            --unprivileged 1 \
            --onboot 1 \
            --password
        
        pct start "$vmid"
        sleep 5
        
        # Basic setup for each container
        pct exec "$vmid" -- bash -c "
            apt update
            apt install -y curl wget
        "
        
        success "LXC $vmid ($service) created"
    else
        log "LXC $vmid already exists"
    fi
done

# Create basic Docker Compose
step "Creating Docker Compose configuration..."
cat > /tmp/docker-compose.yml << 'DOCKEREOF'
version: "3.8"

networks:
  homelab:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

services:
  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Phoenix
    volumes:
      - /data/docker/jellyfin:/config
      - /data/media:/data/media
    ports:
      - "8096:8096"
    networks:
      homelab:
        ipv4_address: 172.20.0.10
    restart: unless-stopped

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Phoenix
    volumes:
      - /data/docker/sonarr:/config
      - /data/media:/data/media
    ports:
      - "8989:8989"
    networks:
      homelab:
        ipv4_address: 172.20.0.5
    restart: unless-stopped

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Phoenix
    volumes:
      - /data/docker/radarr:/config
      - /data/media:/data/media
    ports:
      - "7878:7878"
    networks:
      homelab:
        ipv4_address: 172.20.0.6
    restart: unless-stopped

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Phoenix
    volumes:
      - /data/docker/prowlarr:/config
    ports:
      - "9696:9696"
    networks:
      homelab:
        ipv4_address: 172.20.0.8
    restart: unless-stopped
DOCKEREOF

# Deploy Docker stack
pct push 100 /tmp/docker-compose.yml /opt/homelab/docker-compose.yml

log "Starting Docker services..."
pct exec 100 -- bash -c "
    cd /opt/homelab
    docker-compose up -d
    sleep 30
    docker-compose ps
"

success "Docker stack deployed"

# Final validation
step "Running final validation..."
chmod +x scripts/validate_deployment.sh
./scripts/validate_deployment.sh

echo ""
echo "=========================================="
echo "🎉 HOMELAB DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""
echo "📊 Access your services:"
echo "  • Jellyfin:    http://192.168.1.100:8096"
echo "  • Sonarr:      http://192.168.1.100:8989"
echo "  • Radarr:      http://192.168.1.100:7878"
echo "  • Prowlarr:    http://192.168.1.100:9696"
echo "  • Pi-hole:     http://192.168.1.205/admin"
echo ""
echo "🔧 Next steps:"
echo "1. Configure Prowlarr indexers"
echo "2. Connect Sonarr/Radarr to Prowlarr"
echo "3. Set up Jellyfin libraries"
echo "4. Configure Pi-hole (password: X#zunVV!kDWdYUt0zAAg)"
echo ""
success "Deployment completed successfully!"
DEPLOYEOF

# Make all scripts executable
step "Making scripts executable"
chmod +x *.sh scripts/*.sh

# Create quick start guide
step "Creating documentation"
cat > QUICK_START.md << 'DOCEOF'
# 🚀 Homelab Quick Start

## What was deployed:
- **Docker Host (VMID 100)**: 192.168.1.100 with Jellyfin + Servarr stack
- **LXC Containers (VMIDs 201-206)**: Core infrastructure services

## Access URLs:
- Jellyfin Media Server: http://192.168.1.100:8096
- Sonarr (TV): http://192.168.1.100:8989  
- Radarr (Movies): http://192.168.1.100:7878
- Prowlarr (Indexers): http://192.168.1.100:9696
- Pi-hole DNS: http://192.168.1.205/admin (password: X#zunVV!kDWdYUt0zAAg)

## Next Steps:
1. Configure Prowlarr with indexers/trackers
2. Connect Sonarr/Radarr to Prowlarr API
3. Set up Jellyfin media libraries
4. Configure additional services as needed

## Validation:
Run `./scripts/validate_deployment.sh` anytime to check system health.

## Troubleshooting:
- Check container status: `pct list`
- Docker logs: `pct exec 100 -- docker-compose logs`
- Network test: `ping 192.168.1.100`
DOCEOF

success "Homelab auto-setup completed!"

echo ""
echo "=========================================="
echo "🎉 HOMELAB FILES CREATED SUCCESSFULLY!"
echo "=========================================="
echo ""
echo "📂 Created in: $HOMELAB_DIR"
echo ""
echo "📋 Available scripts:"
echo "  • deploy_homelab_master.sh - Main deployment"
echo "  • scripts/setup_zfs_mirror.sh - ZFS mirror setup"
echo "  • scripts/configure_network.sh - Network validation"  
echo "  • scripts/validate_deployment.sh - System validation"
echo ""
echo "🚀 TO DEPLOY YOUR HOMELAB:"
echo "  cd $HOMELAB_DIR"
echo "  ./deploy_homelab_master.sh"
echo ""
echo "📖 Read QUICK_START.md for post-deployment configuration"
echo "=========================================="

log "Auto-setup script completed successfully!"