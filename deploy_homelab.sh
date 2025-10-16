#!/bin/bash
# =====================================================
# 🚀 Homelab — Deployment Script (Dual-Subnet)
# =====================================================
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-15
#
# Network: PVE-Homelab (192.168.1.50) - Main Services
# =====================================================

set -euo pipefail

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root"
   echo "Usage: sudo $0"
   exit 1
fi

# Check if .env file exists
if [[ ! -f "deployment/.env" ]]; then
   echo "❌ Missing deployment/.env file"
   echo "📋 Please copy deployment/.env.example to deployment/.env"
   echo "📋 Then edit deployment/.env with your actual configuration"
   exit 1
fi

echo "🚀 Starting Homelab Deployment (PVE-Homelab 192.168.1.50)..."
echo "📋 Network: 192.168.1.x subnet - Main homelab services"

echo "--> Creating required directories..."
mkdir -p /data/{docker,media,backups,logs}
mkdir -p /data/docker/{servarr,jellyfin-youtube,gluetun,jellyfin,jellystat,ytdl-sub}
mkdir -p /data/media/{movies,shows,music,youtube}
chown -R 1000:1000 /data

echo "--> Installing core packages..."

# Validate Docker is available or install it
if ! command -v docker &> /dev/null; then
    echo "📦 Docker not found, installing..."
    apt-get update -y
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
else
    echo "✅ Docker is already installed"
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
    curl -fsSL "https://pkgs.tailscale.com/stable/debian/$(lsb_release -cs).noarmor.gpg" | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian \"$(lsb_release -cs)\" main" | tee /etc/apt/sources.list.d/tailscale.list
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

echo "--> Validating Docker Compose configuration..."
if ! docker compose -f deployment/docker-compose.yml config -q; then
    echo "❌ Docker Compose configuration is invalid"
    echo "Run: docker compose -f deployment/docker-compose.yml config"
    exit 1
fi

echo "--> Starting Docker containers..."
if ! docker compose -f deployment/docker-compose.yml up -d; then
    echo "❌ Failed to start Docker containers"
    echo "Check logs: docker compose -f deployment/docker-compose.yml logs"
    exit 1
fi

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
# Get primary IP address safely
PRIMARY_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || echo "localhost")
echo "  Jellyfin      → http://${PRIMARY_IP}:8096"
echo "  Sonarr        → http://${PRIMARY_IP}:8989"
echo "  Radarr        → http://${PRIMARY_IP}:7878"
echo "  Prowlarr      → http://${PRIMARY_IP}:9696"
echo "  Jellyseerr    → http://${PRIMARY_IP}:5055"
echo "  Jellystat     → http://${PRIMARY_IP}:3000"
echo ""
echo "📋 Next Steps:"
echo "  1. Configure your VPN settings in deployment/.env"
echo "  2. Set up indexers in Prowlarr"
echo "  3. Configure download clients in Sonarr/Radarr"
echo "  4. Run: ./homelab.sh status to verify everything is running"
