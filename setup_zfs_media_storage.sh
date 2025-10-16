#!/bin/bash

# 💾 ZFS Media Storage Setup Script
# Based on identified 2x 8TB HDD configuration
# Creates mirrored pool for media storage redundancy

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[ZFS] $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Configuration
POOL_NAME="mediapool"
DATASET_NAME="media"
MOUNT_POINT="/mnt/media"

log "🗄️  Setting up ZFS mirrored storage for media files..."

# Check if ZFS is available
if ! command -v zpool >/dev/null 2>&1; then
    error "ZFS not found. Installing..."
    apt update && apt install -y zfsutils-linux
fi

# Detect available 8TB drives
log "Detecting available storage devices..."
available_drives=()

# Look for drives that are approximately 8TB (7.3TB usable)
while IFS= read -r line; do
    device=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')

    # Check if size is around 8TB (7-8.5TB range)
    if [[ "$size" =~ ^[7-8]\.[0-9]T$ ]] || [[ "$size" =~ ^8000[0-9]*G$ ]]; then
        # Verify it's not already in use
        if ! lsblk "$device" | grep -q "SWAP\|/"; then
            available_drives+=("$device")
            log "Found candidate drive: $device ($size)"
        fi
    fi
done < <(lsblk -d -n -o NAME,SIZE | grep -E "^sd[a-z]")

if [ ${#available_drives[@]} -lt 2 ]; then
    error "Need at least 2 available drives for mirrored setup"
    echo "Available drives found: ${#available_drives[@]}"
    echo "Drives: ${available_drives[*]}"
    exit 1
fi

# Use first two drives
DRIVE1="/dev/${available_drives[0]}"
DRIVE2="/dev/${available_drives[1]}"

log "Selected drives for mirror:"
log "  Drive 1: $DRIVE1"
log "  Drive 2: $DRIVE2"

# Safety check
warn "This will DESTROY all data on the selected drives!"
echo "Drives to be used:"
lsblk "$DRIVE1" "$DRIVE2"
echo ""
read -p "Continue with ZFS mirror setup? (type 'YES' to confirm): " confirmation

if [ "$confirmation" != "YES" ]; then
    log "Setup cancelled by user"
    exit 0
fi

# Check if pool already exists
if zpool list "$POOL_NAME" >/dev/null 2>&1; then
    warn "Pool '$POOL_NAME' already exists"
    zpool status "$POOL_NAME"
    exit 1
fi

# Create ZFS mirror pool
log "Creating ZFS mirror pool '$POOL_NAME'..."
if zpool create -f "$POOL_NAME" mirror "$DRIVE1" "$DRIVE2"; then
    success "ZFS mirror pool created successfully"
else
    error "Failed to create ZFS pool"
    exit 1
fi

# Configure pool properties
log "Configuring pool properties..."
zpool set autoexpand=on "$POOL_NAME"
zpool set autotrim=on "$POOL_NAME"
success "Pool properties configured"

# Create main dataset
log "Creating media dataset..."
zfs create "$POOL_NAME/$DATASET_NAME"

# Configure dataset properties for media storage
log "Optimizing dataset for media files..."
zfs set compression=lz4 "$POOL_NAME/$DATASET_NAME"
zfs set atime=off "$POOL_NAME/$DATASET_NAME"
zfs set recordsize=1M "$POOL_NAME/$DATASET_NAME"  # Better for large files
zfs set sync=disabled "$POOL_NAME/$DATASET_NAME"  # Better performance for media
zfs set redundant_metadata=most "$POOL_NAME/$DATASET_NAME"

# Set mount point
zfs set mountpoint="$MOUNT_POINT" "$POOL_NAME/$DATASET_NAME"
success "Dataset configured and mounted at $MOUNT_POINT"

# Create subdirectories for different media types
log "Creating media directory structure..."
mkdir -p "$MOUNT_POINT"/{movies,tv,music,books,downloads,backups}

# Set appropriate permissions
chown -R 1000:1000 "$MOUNT_POINT"
chmod -R 755 "$MOUNT_POINT"

# Create additional datasets for organization
datasets=("movies" "tv" "music" "books" "downloads" "backups")
for dataset in "${datasets[@]}"; do
    zfs create "$POOL_NAME/$DATASET_NAME/$dataset"
    success "Created dataset: $POOL_NAME/$DATASET_NAME/$dataset"
done

# Configure automatic snapshots (optional)
log "Setting up snapshot policy..."
# Daily snapshots, keep for 7 days
echo "0 2 * * * root zfs snapshot $POOL_NAME/$DATASET_NAME@\$(date +\%Y-\%m-\%d)" >> /etc/crontab
# Weekly snapshots, keep for 4 weeks
echo "0 3 * * 0 root zfs snapshot $POOL_NAME/$DATASET_NAME@weekly-\$(date +\%Y-\%U)" >> /etc/crontab
# Cleanup old daily snapshots
echo "0 4 * * * root zfs list -H -t snapshot -o name | grep $POOL_NAME/$DATASET_NAME@[0-9] | sort | head -n -7 | xargs -r -n1 zfs destroy" >> /etc/crontab

systemctl restart cron
success "Automatic snapshot policy configured"

# Display final status
echo ""
log "🎉 ZFS media storage setup complete!"
echo ""
success "Pool Status:"
zpool status "$POOL_NAME"
echo ""
success "Dataset Information:"
zfs list -r "$POOL_NAME"
echo ""
success "Mount Points:"
df -h "$MOUNT_POINT"
echo ""
log "Directory Structure:"
ls -la "$MOUNT_POINT"/
echo ""
success "Setup Summary:"
echo "  • Pool: $POOL_NAME (mirrored across 2 drives)"
echo "  • Compression: LZ4 enabled"
echo "  • Mount: $MOUNT_POINT"
echo "  • Datasets: ${#datasets[@]} organized subdirectories"
echo "  • Snapshots: Daily + Weekly automatic snapshots"
echo "  • Optimized: For large media files"
echo ""
warn "Next Steps:"
echo "  • Update Docker Compose volumes to use $MOUNT_POINT"
echo "  • Configure your *arr stack to use new paths"
echo "  • Test performance: dd if=/dev/zero of=$MOUNT_POINT/test bs=1M count=1000"
echo "  • Monitor health: zpool status $POOL_NAME"
