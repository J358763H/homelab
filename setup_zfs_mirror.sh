#!/usr/bin/env bash
# =====================================================
# 🗄️ ZFS Mirror Setup Script for Proxmox
# =====================================================
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Created: 2025-10-14
# 
# Sets up ZFS mirror for aging drives with proper
# configuration for homelab data protection
# =====================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
POOL_NAME="homelab-storage"
MOUNT_POINT="/mnt/homelab-storage"
BACKUP_MOUNT="/mnt/homelab-backup"

# Logging
LOG_FILE="/var/log/zfs_setup_$(date +%Y%m%d_%H%M%S).log"

# Functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Check if ZFS is available
check_zfs() {
    log "Checking ZFS availability..."
    if ! command -v zpool >/dev/null 2>&1; then
        error "ZFS not found. Installing..."
        apt update
        apt install -y zfsutils-linux
    fi
    success "ZFS is available"
}

# Detect available drives
detect_drives() {
    log "Detecting available drives..."
    echo ""
    echo "Available block devices:"
    lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -E "(disk|nvme)"
    echo ""
    
    # Show current ZFS pools if any
    if zpool list >/dev/null 2>&1; then
        echo "Existing ZFS pools:"
        zpool list
        echo ""
    fi
    
    # Show drive health
    log "Checking drive health with smartctl..."
    for drive in /dev/sd* /dev/nvme*; do
        if [[ -b "$drive" ]] && [[ ! "$drive" =~ [0-9]$ ]]; then
            echo "=== Drive: $drive ==="
            smartctl -H "$drive" 2>/dev/null | grep -E "(SMART overall-health|Health Status)" || true
            echo ""
        fi
    done
}

# Interactive drive selection
select_drives() {
    log "Please select drives for ZFS mirror..."
    echo ""
    echo "⚠️  WARNING: Selected drives will be COMPLETELY WIPED!"
    echo "⚠️  Ensure you have backups of any important data!"
    echo ""
    
    read -p "Enter first drive path (e.g., /dev/sdb): " DRIVE1
    read -p "Enter second drive path (e.g., /dev/sdc): " DRIVE2
    
    # Validation
    if [[ ! -b "$DRIVE1" ]] || [[ ! -b "$DRIVE2" ]]; then
        error "Invalid drive paths provided"
        exit 1
    fi
    
    if [[ "$DRIVE1" == "$DRIVE2" ]]; then
        error "Same drive selected twice"
        exit 1
    fi
    
    # Check if drives are in use
    if mount | grep -q "$DRIVE1\|$DRIVE2"; then
        error "One or both drives are currently mounted"
        exit 1
    fi
    
    echo ""
    echo "Selected drives:"
    echo "  Primary: $DRIVE1"
    echo "  Mirror:  $DRIVE2"
    echo ""
    
    # Final confirmation
    read -p "Are you ABSOLUTELY SURE you want to proceed? (yes/no): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        log "Aborted by user"
        exit 0
    fi
}

# Create ZFS pool with mirror
create_zfs_pool() {
    log "Creating ZFS mirror pool: $POOL_NAME"
    
    # Wipe drives first (optional but recommended)
    warning "Wiping drive signatures..."
    wipefs -af "$DRIVE1"
    wipefs -af "$DRIVE2"
    
    # Create the mirrored pool
    log "Creating mirrored ZFS pool..."
    zpool create -f \
        -o ashift=12 \
        -o feature@async_destroy=enabled \
        -o feature@bookmarks=enabled \
        -o feature@embedded_data=enabled \
        -o feature@empty_bpobj=enabled \
        -o feature@enabled_txg=enabled \
        -o feature@extensible_dataset=enabled \
        -o feature@filesystem_limits=enabled \
        -o feature@hole_birth=enabled \
        -o feature@large_blocks=enabled \
        -o feature@lz4_compress=enabled \
        -o feature@spacemap_histogram=enabled \
        -O compression=lz4 \
        -O atime=off \
        -O xattr=sa \
        -O recordsize=128K \
        -m "$MOUNT_POINT" \
        "$POOL_NAME" mirror "$DRIVE1" "$DRIVE2"
    
    success "ZFS pool created successfully"
}

# Configure datasets
create_datasets() {
    log "Creating ZFS datasets for homelab..."
    
    # Main datasets
    zfs create "$POOL_NAME/docker"
    zfs create "$POOL_NAME/media"
    zfs create "$POOL_NAME/backups"
    zfs create "$POOL_NAME/logs"
    
    # Media subdatasets
    zfs create "$POOL_NAME/media/movies"
    zfs create "$POOL_NAME/media/shows"
    zfs create "$POOL_NAME/media/music"
    zfs create "$POOL_NAME/media/youtube"
    zfs create "$POOL_NAME/media/downloads"
    
    # Docker subdatasets
    zfs create "$POOL_NAME/docker/servarr"
    zfs create "$POOL_NAME/docker/jellyfin"
    zfs create "$POOL_NAME/docker/monitoring"
    
    # Set quotas (optional)
    zfs set quota=50G "$POOL_NAME/docker"
    zfs set quota=500G "$POOL_NAME/media"
    zfs set quota=100G "$POOL_NAME/backups"
    
    # Set compression for different workloads
    zfs set compression=gzip-6 "$POOL_NAME/backups"  # Better compression for backups
    zfs set compression=lz4 "$POOL_NAME/media"       # Fast compression for media
    zfs set compression=lz4 "$POOL_NAME/docker"      # Fast compression for containers
    
    success "ZFS datasets created"
}

# Set up automatic snapshots
setup_snapshots() {
    log "Setting up automatic ZFS snapshots..."
    
    # Create snapshot script
    cat > /usr/local/bin/zfs_snapshot.sh << 'EOF'
#!/bin/bash
# Automatic ZFS snapshot script

POOL_NAME="homelab-storage"
DATE=$(date +%Y%m%d_%H%M%S)

# Create snapshots
for dataset in docker media backups; do
    zfs snapshot "$POOL_NAME/$dataset@auto_$DATE"
done

# Clean up old snapshots (keep last 7 daily)
for dataset in docker media backups; do
    zfs list -t snapshot -o name -s creation "$POOL_NAME/$dataset" | grep "auto_" | head -n -7 | xargs -r -n 1 zfs destroy
done

logger "ZFS automatic snapshots completed for $POOL_NAME"
EOF

    chmod +x /usr/local/bin/zfs_snapshot.sh
    
    # Add to crontab (daily at 2 AM)
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/zfs_snapshot.sh") | crontab -
    
    success "Automatic snapshots configured"
}

# Create symbolic links for Docker
setup_docker_integration() {
    log "Setting up Docker integration..."
    
    # Stop Docker if running
    systemctl stop docker 2>/dev/null || true
    
    # Backup existing Docker directory
    if [[ -d /var/lib/docker ]]; then
        mv /var/lib/docker /var/lib/docker.backup.$(date +%Y%m%d)
        warning "Existing Docker data backed up to /var/lib/docker.backup.$(date +%Y%m%d)"
    fi
    
    # Create new Docker directory on ZFS
    mkdir -p "$MOUNT_POINT/docker/engine"
    ln -sf "$MOUNT_POINT/docker/engine" /var/lib/docker
    
    # Create data directories
    mkdir -p "$MOUNT_POINT"/{docker,media,backups,logs}
    mkdir -p "$MOUNT_POINT/media"/{movies,shows,music,youtube,downloads}
    
    # Set proper permissions
    chown -R root:root "$MOUNT_POINT/docker"
    chmod -R 755 "$MOUNT_POINT/docker"
    
    # Create symlinks for homelab paths
    ln -sf "$MOUNT_POINT" /data
    
    success "Docker integration configured"
}

# Health monitoring setup
setup_monitoring() {
    log "Setting up ZFS health monitoring..."
    
    # Create health check script
    cat > /usr/local/bin/zfs_health_check.sh << 'EOF'
#!/bin/bash
# ZFS Health Check Script

POOL_NAME="homelab-storage"
LOG_FILE="/var/log/zfs_health.log"

# Check pool health
HEALTH=$(zpool status "$POOL_NAME" | grep "state:" | awk '{print $2}')

if [[ "$HEALTH" != "ONLINE" ]]; then
    echo "$(date): ZFS Pool $POOL_NAME is $HEALTH" >> "$LOG_FILE"
    logger "CRITICAL: ZFS Pool $POOL_NAME health is $HEALTH"
    
    # Send notification if ntfy is available
    if command -v curl >/dev/null 2>&1; then
        curl -d "ZFS Pool $POOL_NAME health issue: $HEALTH" \
             -H "Title: ZFS Health Alert" \
             -H "Priority: urgent" \
             -H "Tags: warning,storage" \
             ntfy.sh/homelab_alerts_juju 2>/dev/null || true
    fi
else
    echo "$(date): ZFS Pool $POOL_NAME is healthy" >> "$LOG_FILE"
fi

# Check disk usage
USAGE=$(zfs get -Ho value used "$POOL_NAME" | sed 's/G//')
if (( $(echo "$USAGE > 80" | bc -l) )); then
    logger "WARNING: ZFS Pool $POOL_NAME is ${USAGE}% full"
fi
EOF

    chmod +x /usr/local/bin/zfs_health_check.sh
    
    # Add to crontab (every hour)
    (crontab -l 2>/dev/null; echo "0 * * * * /usr/local/bin/zfs_health_check.sh") | crontab -
    
    success "Health monitoring configured"
}

# Display final status
show_status() {
    log "ZFS Mirror Setup Complete!"
    echo ""
    echo "=== ZFS Pool Status ==="
    zpool status "$POOL_NAME"
    echo ""
    echo "=== Dataset List ==="
    zfs list -r "$POOL_NAME"
    echo ""
    echo "=== Mount Points ==="
    echo "Main storage: $MOUNT_POINT"
    echo "Docker data:  /data -> $MOUNT_POINT"
    echo ""
    echo "=== Next Steps ==="
    echo "1. Start Docker: systemctl start docker"
    echo "2. Verify mount points: df -h"
    echo "3. Test snapshots: zfs snapshot $POOL_NAME/docker@test"
    echo "4. Deploy homelab stack: cd /path/to/homelab && docker-compose up -d"
    echo ""
    success "Setup completed successfully!"
}

# Main execution
main() {
    log "Starting ZFS Mirror Setup for Homelab"
    
    check_root
    check_zfs
    detect_drives
    select_drives
    create_zfs_pool
    create_datasets
    setup_snapshots
    setup_docker_integration
    setup_monitoring
    show_status
}

# Trap for cleanup on exit
trap 'error "Script interrupted"; exit 130' INT TERM

# Run main function
main "$@"