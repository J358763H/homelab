#!/bin/bash

# Deploy all homelab services in correct order
echo "🏠 Deploying Complete Homelab Stack..."

# Check if .env exists
if [ ! -f ../.env ]; then
    echo "❌ .env file not found. Run ./prepare.sh first!"
    exit 1
fi

# Deploy core services first (VPN)
echo "🔒 Starting core infrastructure..."
cd ../containers/core || exit
docker-compose up -d
echo "Waiting for VPN to establish..."
sleep 30

# Deploy downloads (depends on VPN)
echo "📥 Starting download clients..."
cd ../downloads || exit
docker-compose up -d
echo "Waiting for download clients..."
sleep 15

# Deploy media services
echo "🎬 Starting media services..."
cd ../media || exit
docker-compose up -d

echo ""
echo "✅ Homelab deployment complete!"
echo ""
echo "🌐 Service Access:"
echo "  Jellyfin:     http://localhost:8096"
echo "  qBittorrent:  http://localhost:8080"
echo "  NZBGet:       http://localhost:6789"
echo "  Prowlarr:     http://localhost:9696"
echo "  Sonarr:       http://localhost:8989"
echo "  Radarr:       http://localhost:7878"
echo "  Bazarr:       http://localhost:6767"
echo "  JellyStat:    http://localhost:3000"
echo ""
echo "🔧 Setup Order:"
echo "1. Configure VPN in Gluetun (check logs if downloads don't work)"
echo "2. Setup Jellyfin media library"
echo "3. Configure Prowlarr with indexers"
echo "4. Add download clients to Prowlarr"
echo "5. Configure Sonarr/Radarr with Prowlarr"

# Optional LXC deployment
echo ""
echo "📦 Optional: Deploy LXC Infrastructure Services"
echo "These run on Proxmox and provide additional functionality:"
echo "  - Nginx Proxy Manager (reverse proxy)"
echo "  - Pi-hole (network DNS & ad blocking)"
echo "  - Tailscale (VPN & remote access)"
echo ""
read -p "Deploy LXC services? (requires Proxmox) (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Starting LXC deployment..."
    if bash "./deploy-lxc.sh"; then
        echo "✅ LXC services deployed successfully"
    else
        echo "⚠️  LXC deployment completed with some issues"
    fi
else
    echo "⏭️  Skipping LXC deployment"
fi
