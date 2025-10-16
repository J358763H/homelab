#!/usr/bin/env bash
# =====================================================
# 🚀 Homelab-SHV Bootstrap Script
# =====================================================
# Prepares the system and installs required scripts
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-15
# =====================================================

set -euo pipefail

# Check if running as root (required for /usr/local/bin operations)
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root"
   echo "Usage: sudo $0"
   exit 1
fi

echo "=== Homelab-SHV Bootstrap Starting ==="

# Create required directories
echo "--> Creating directory structure..."
mkdir -p /data/{docker,media,backups,logs}
mkdir -p /data/docker/{servarr,jellyfin-youtube,gluetun,jellyfin,jellystat,ytdl-sub}
mkdir -p /data/media/{movies,shows,music,youtube}

# Check for required commands
echo "--> Checking system dependencies..."
for cmd in docker curl git rsync; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Required command not found: $cmd"
    echo "Please install the missing dependencies and run this script again."
    exit 1
  fi
done

# Install scripts to /usr/local/bin
echo "--> Installing scripts to /usr/local/bin..."

# Function to safely copy script if it exists
copy_script_if_exists() {
    local src="$1"
    local filename
    filename=$(basename "$src")

    if [[ -f "$src" ]]; then
        cp "$src" "/usr/local/bin/"
        chmod +x "/usr/local/bin/$filename"
        echo "✅ Installed: $filename"
    else
        echo "⚠️  Warning: $src not found, skipping"
    fi
}

# Backup scripts
copy_script_if_exists "scripts/backup/restic_backup_with_alerts.sh"
copy_script_if_exists "scripts/backup/daily_backup_summary.sh"

# Monitoring scripts
copy_script_if_exists "scripts/monitoring/hdd_health_check.sh"
copy_script_if_exists "scripts/monitoring/weekly_system_health.sh"
copy_script_if_exists "scripts/monitoring/maintenance_dashboard.sh"

# Documentation scripts
copy_script_if_exists "scripts/docs/Homelab_Documentation_Archiver.sh"

# Set proper ownership for /data
echo "--> Setting up permissions..."
chown -R 1000:1000 /data

# Create basic configuration files if they don't exist
echo "--> Setting up initial configuration..."

# Create .env if it doesn't exist
if [ ! -f "deployment/.env" ]; then
    echo "⚠️  Creating .env from template - PLEASE EDIT WITH YOUR SECRETS!"
    cp deployment/.env.example deployment/.env
fi

# Create wg0.conf if it doesn't exist
if [ ! -f "deployment/wg0.conf" ]; then
    echo "⚠️  Creating wg0.conf from template - PLEASE EDIT WITH YOUR VPN DETAILS!"
    cp deployment/wg0.conf.example deployment/wg0.conf
fi

# Create log directory for scripts
sudo mkdir -p /var/log/homelab-shv
sudo chown 1000:1000 /var/log/homelab-shv

echo "✅ Bootstrap complete!"
echo ""
echo "📋 Next Steps:"
echo "  1. Edit deployment/.env with your secrets and settings"
echo "  2. Edit deployment/wg0.conf with your VPN configuration"
echo "  3. Run: docker compose -f deployment/docker-compose.yml up -d"
echo ""
echo "🔧 Scripts installed in /usr/local/bin/:"
echo "  - restic_backup_with_alerts.sh"
echo "  - daily_backup_summary.sh"
echo "  - hdd_health_check.sh"
echo "  - weekly_system_health.sh"
echo "  - maintenance_dashboard.sh"
echo "  - Homelab_Documentation_Archiver.sh"
