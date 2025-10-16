#!/bin/bash

# Simple homelab status checker including LXC services
echo "🏠 Homelab Status Report"
echo "========================"

# Check Docker services
echo ""
echo "🐳 Docker Services:"
if command -v docker &> /dev/null; then
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -v "NAMES"; then
        echo "✅ Docker services running"
    else
        echo "⚠️  No Docker services running"
    fi
else
    echo "❌ Docker not available"
fi

# Check LXC services (if on Proxmox)
echo ""
echo "📦 LXC Services:"
if command -v pct &> /dev/null; then
    echo "Checking LXC containers..."

    # Define LXC services
    declare -A LXC_SERVICES=(
        ["201"]="Nginx Proxy Manager"
        ["202"]="Tailscale VPN"
        ["203"]="Ntfy Notifications"
        ["204"]="Samba File Share"
        ["205"]="Pi-hole DNS"
        ["206"]="Vaultwarden Passwords"
    )

    for ctid in "${!LXC_SERVICES[@]}"; do
        service_name="${LXC_SERVICES[$ctid]}"
        if pct status "$ctid" >/dev/null 2>&1; then
            status=$(pct status "$ctid" | awk '{print $2}')
            if [[ "$status" == "running" ]]; then
                echo "✅ CT $ctid ($service_name): Running"
            else
                echo "⚠️  CT $ctid ($service_name): $status"
            fi
        else
            echo "❌ CT $ctid ($service_name): Not found"
        fi
    done
else
    echo "ℹ️  Not running on Proxmox (LXC services not available)"
fi

# Check key services
echo ""
echo "🌐 Service Accessibility:"

# Docker services
services=(
    "localhost:8096:Jellyfin"
    "localhost:8080:qBittorrent"
    "localhost:9696:Prowlarr"
    "localhost:8989:Sonarr"
    "localhost:7878:Radarr"
)

for service in "${services[@]}"; do
    IFS=':' read -r host port name <<< "$service"
    if timeout 2 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        echo "✅ $name: http://$host:$port"
    else
        echo "❌ $name: http://$host:$port (not accessible)"
    fi
done

# LXC services (if available)
if command -v pct &> /dev/null; then
    lxc_services=(
        "192.168.1.201:81:Nginx Proxy Manager"
        "192.168.1.205:80:Pi-hole"
        "192.168.1.203:80:Ntfy"
        "192.168.1.206:80:Vaultwarden"
    )

    for service in "${lxc_services[@]}"; do
        IFS=':' read -r host port name <<< "$service"
        if timeout 2 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            echo "✅ $name: http://$host:$port"
        else
            echo "❌ $name: http://$host:$port (not accessible)"
        fi
    done
fi

echo ""
echo "📊 Quick Stats:"
echo "  Docker containers: $(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)"
if command -v pct &> /dev/null; then
    echo "  LXC containers: $(pct list | tail -n +2 | wc -l)"
fi

echo ""
echo "🔧 Management Commands:"
echo "  Check Docker logs: docker logs [container_name]"
echo "  Restart Docker service: cd containers/[group] && docker-compose restart"
if command -v pct &> /dev/null; then
    echo "  Check LXC logs: pct exec [ctid] -- journalctl -f"
    echo "  LXC status: pct status [ctid]"
fi
