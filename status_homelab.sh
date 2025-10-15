#!/bin/bash
# =====================================================
# 📊 Homelab — Status Script
# =====================================================
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-11
# =====================================================

echo "=== Homelab Status Check ==="
echo ""

echo "--- Docker Container Status ---"
if docker compose -f deployment/docker-compose.yml ps 2>/dev/null; then
    echo ""
    echo "--- Container Health Check ---"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(gluetun|sonarr|radarr|jellyfin|prowlarr)"
else 
    echo "❌ Docker Compose not running or configuration file not found"
fi

echo ""
echo "--- System Services Status ---"
echo "Docker: $(systemctl is-active docker 2>/dev/null || echo 'not installed')"
echo "Tailscale: $(systemctl is-active tailscaled 2>/dev/null || echo 'not installed')"

echo ""
echo "--- Network Connectivity ---"
if command -v docker >/dev/null 2>&1; then
    if docker ps --filter "name=gluetun" --format "{{.Names}}" | grep -q gluetun; then
        echo "VPN Status: $(docker exec gluetun sh -c 'curl -s ifconfig.me 2>/dev/null' || echo 'VPN check failed')"
    else
        echo "VPN Status: Container not running"
    fi
    
    echo "External IP: $(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo 'Unable to reach external services')"
fi

echo ""
echo "--- Cron Job Schedule ---"
if sudo crontab -l 2>/dev/null | grep -q "Homelab"; then
    echo "Active Homelab cron jobs:"
    sudo crontab -l 2>/dev/null | grep -A 10 "# Homelab Cron Jobs" | grep -v "^#" | grep -v "^$"
else
    echo "❌ No Homelab cron jobs found"
fi

echo ""
echo "--- Storage Status ---"
if [ -d "/data" ]; then
    echo "Disk Usage (/data):"
    df -h /data 2>/dev/null || echo "❌ /data directory not found"
    
    echo ""
    echo "Data Directory Structure:"
    ls -la /data/ 2>/dev/null || echo "❌ Cannot access /data directory"
else
    echo "❌ /data directory does not exist"
fi

echo ""
echo "--- ZFS Status (if available) ---"
if command -v zpool >/dev/null 2>&1; then
    zpool status 2>/dev/null | head -20 || echo "No ZFS pools found"
else
    echo "ZFS not installed"
fi

echo ""
echo "--- System Load ---"
uptime
echo "Memory Usage:"
free -h

echo ""
echo "--- Quick Service Check ---"
if command -v docker >/dev/null 2>&1; then
    SERVICES=("gluetun" "sonarr" "radarr" "prowlarr" "jellyfin" "qbittorrent")
    for service in "${SERVICES[@]}"; do
        if docker ps --filter "name=$service" --format "{{.Names}}" | grep -q "$service"; then
            echo "✅ $service: Running"
        else
            echo "❌ $service: Not running"
        fi
    done
fi

echo ""
echo "✅ Status check complete."
echo ""
echo "🌐 Quick Access URLs (replace <IP> with your server IP):"
echo "  http://<IP>:8096  - Jellyfin"
echo "  http://<IP>:8989  - Sonarr"
echo "  http://<IP>:7878  - Radarr"
echo "  http://<IP>:9696  - Prowlarr"
echo "  http://<IP>:5055  - Jellyseerr"
echo "  http://<IP>:3000  - Jellystat"