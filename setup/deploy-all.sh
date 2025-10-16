#!/bin/bash

# Deploy all homelab services in correct order
echo "🏠 Deploying Complete Homelab Stack..."

# Enhanced compatibility for Proxmox web UI
echo "🌐 Proxmox Web UI Compatible Deployment"

# Check if we have Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    systemctl enable docker
    systemctl start docker
    echo "✅ Docker installed"
fi

# Check if we have Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Installing..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed"
fi

# Check if .env exists, create if missing
if [ ! -f ../.env ]; then
    echo "⚠️ .env file not found. Creating default..."
    cat > ../.env << 'EOF'
# Homelab Environment Configuration
PUID=1000
PGID=1000
TZ=America/New_York
DATA_ROOT=/opt/homelab-data
EOF
    echo "✅ Default .env created"
fi

# Create data directories
echo "📁 Creating data directories..."
mkdir -p /opt/homelab-data/{downloads,media,config}
mkdir -p /data/{docker,media}/{qbittorrent,nzbget,jellyfin,sonarr,radarr,prowlarr,bazarr,jellystat,jellystat-db}
mkdir -p /data/media/{downloads,movies,shows,music}
chmod -R 777 /opt/homelab-data
chmod -R 755 /data

# Deploy core services first (VPN)
echo "🔒 Starting core infrastructure..."
cd ../containers/core || exit

# Check if VPN config exists
if [ ! -f "wg0.conf" ]; then
    echo "⚠️ Warning: VPN config not found (wg0.conf)"
    echo "   Download services may not work without VPN"
    echo "   See wg0.conf.example for setup instructions"
    echo ""
fi

docker-compose up -d
echo "Waiting for VPN to establish..."
sleep 30

# Check if VPN is working
if docker logs gluetun 2>/dev/null | grep -q "Connected"; then
    echo "✅ VPN connection established"
else
    echo "⚠️ VPN may not be connected - check gluetun logs"
fi

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
