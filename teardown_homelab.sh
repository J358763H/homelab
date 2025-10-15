#!/bin/bash
# =====================================================
# 🧹 Homelab — Teardown Script
# =====================================================
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-11
# =====================================================

set -e

echo "Tearing down Homelab services..."

echo "--> Stopping Docker containers..."
docker compose -f deployment/docker-compose.yml down

echo "--> Removing Docker volumes (optional - uncomment to enable)..."
# docker volume prune -f

echo "--> Removing cron jobs..."
sudo crontab -l 2>/dev/null | grep -v "# Homelab Cron Jobs" | grep -v "restic_backup_with_alerts.sh" | grep -v "hdd_health_check.sh" | grep -v "daily_backup_summary.sh" | grep -v "maintenance_dashboard.sh" | grep -v "weekly_system_health.sh" | grep -v "Homelab_Documentation_Archiver.sh" | sudo crontab -

echo "--> Removing scripts from /usr/local/bin (optional - uncomment to enable)..."
# sudo rm -f /usr/local/bin/restic_backup_with_alerts.sh
# sudo rm -f /usr/local/bin/hdd_health_check.sh
# sudo rm -f /usr/local/bin/daily_backup_summary.sh
# sudo rm -f /usr/local/bin/maintenance_dashboard.sh
# sudo rm -f /usr/local/bin/weekly_system_health.sh
# sudo rm -f /usr/local/bin/Homelab_Documentation_Archiver.sh

echo "✅ Teardown complete."
echo ""
echo "📁 Data preservation:"
echo "  /data directory is preserved (contains your media and configs)"
echo "  Docker volumes are preserved (uncomment line above to remove)"
echo ""
echo "🔄 To completely wipe and start fresh:"
echo "  sudo rm -rf /data"
echo "  docker system prune -a --volumes"