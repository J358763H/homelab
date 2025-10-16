#!/bin/bash

# Simple environment preparation for homelab
echo "🏠 Preparing Homelab Environment..."

# Create directory structure
echo "Creating directory structure..."
sudo mkdir -p /data/{docker,media}/{downloads,movies,shows,youtube}
sudo mkdir -p /data/docker/{qbittorrent,nzbget,prowlarr,sonarr,radarr,bazarr,recyclarr,jellyfin,jellystat-db,jellystat}

# Set permissions
echo "Setting permissions..."
sudo chown -R $USER:$USER /data
sudo chmod -R 755 /data

# Copy environment file if it doesn't exist
if [ ! -f ../.env ]; then
    echo "Creating .env file..."
    cp env.example ../.env
    echo "⚠️  Please edit .env file with your settings before deploying!"
else
    echo "✅ .env file already exists"
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Please install Docker Compose first."
    exit 1
fi

echo "✅ Environment preparation complete!"
echo ""
echo "Next steps:"
echo "1. Edit .env file with your settings"
echo "2. Run ./deploy-all.sh to start services"
