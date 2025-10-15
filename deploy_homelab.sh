#!/bin/bash
# =====================================================
# 🚀 Homelab — Deployment Script (Dual-Subnet)
# =====================================================
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-14
# 
# Network: PVE-Homelab (192.168.1.50) - Main Services
# =====================================================

set -e

echo "🚀 Starting Homelab Deployment (PVE-Homelab 192.168.1.50)..."
echo "📋 Network: 192.168.1.x subnet - Main homelab services"

echo "--> Creating required directories..."
mkdir -p /data/{docker,media,backups,logs}
mkdir -p /data/docker/{servarr,jellyfin-youtube,gluetun,jellyfin,jellystat,ytdl-sub}
mkdir -p /data/media/{movies,shows,music,youtube}
chown -R 1000:1000 /data

echo "--> Installing core packages..."

# Install sudo if not available
if ! command -v sudo &> /dev/null; then
    apt-get update -y && apt-get install -y sudo
fi

# Install lsb-release first (needed for repository setup)
sudo apt-get update -y && sudo apt-get install -y lsb-release curl gnupg

# Add Docker repository
if [ ! -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

# Add Tailscale repository
if [ ! -f /usr/share/keyrings/tailscale-archive-keyring.gpg ]; then
    curl -fsSL https://pkgs.tailscale.com/stable/debian/$(lsb_release -cs).noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/tailscale.list
fi

# Update and install packages
sudo apt-get update -y && sudo apt-get install -y \
  rsync restic smartmontools lm-sensors zfsutils-linux \
  tailscale docker.io docker-compose-plugin tree mailutils

echo "--> Enabling and starting core services..."
sudo systemctl enable --now docker tailscaled

echo "--> Detecting system sensors..."
sudo sensors-detect --auto || true

echo "--> Running bootstrap script to place scripts in /usr/local/bin..."
chmod +x deployment/bootstrap.sh && ./deployment/bootstrap.sh

echo "--> Starting Docker containers..."
docker compose -f deployment/docker-compose.yml up -d

echo "--> Setting up cron jobs..."
CRON_ENTRIES="
# Homelab Cron Jobs
0 2 * * * /usr/local/bin/restic_backup_with_alerts.sh >/dev/null 2>&1
0 3 * * * /usr/local/bin/hdd_health_check.sh >/dev/null 2>&1
0 4 * * * /usr/local/bin/daily_backup_summary.sh >/dev/null 2>&1
0 4 * * * /usr/local/bin/maintenance_dashboard.sh >/dev/null 2>&1
0 8 * * 1 /usr/local/bin/weekly_system_health.sh >/dev/null 2>&1
0 3 * * * /usr/local/bin/Homelab_Documentation_Archiver.sh >/dev/null 2>&1
"

# Remove any existing Homelab cron entries first, then add new ones
( sudo crontab -l 2>/dev/null | grep -v "# Homelab Cron Jobs" | grep -v "restic_backup_with_alerts.sh" | grep -v "hdd_health_check.sh" | grep -v "daily_backup_summary.sh" | grep -v "maintenance_dashboard.sh" | grep -v "weekly_system_health.sh" | grep -v "Homelab_Documentation_Archiver.sh"; echo "$CRON_ENTRIES" ) | sudo crontab -

echo "✅ Homelab deployed and scheduled."
echo ""
echo "🌐 Access your services:"
echo "  Jellyfin      → http://$(hostname -I | awk '{print $1}'):8096"
echo "  Sonarr        → http://$(hostname -I | awk '{print $1}'):8989" 
echo "  Radarr        → http://$(hostname -I | awk '{print $1}'):7878"
echo "  Prowlarr      → http://$(hostname -I | awk '{print $1}'):9696"
echo "  Jellyseerr    → http://$(hostname -I | awk '{print $1}'):5055"
echo "  Jellystat     → http://$(hostname -I | awk '{print $1}'):3000"
echo ""
echo "📋 Next Steps:"
echo "  1. Configure your VPN settings in deployment/.env"
echo "  2. Set up indexers in Prowlarr"
echo "  3. Configure download clients in Sonarr/Radarr"
echo "  4. Run: ./homelab.sh status to verify everything is running"