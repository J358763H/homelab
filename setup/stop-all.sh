#!/bin/bash

# Stop all homelab services
echo "🛑 Stopping all homelab services..."

echo "Stopping media services..."
cd ../containers/media || exit
docker-compose down

echo "Stopping download services..."
cd ../downloads || exit
docker-compose down

echo "Stopping core services..."
cd ../core || exit
docker-compose down

echo "✅ All services stopped!"
echo ""
echo "To restart: ./deploy-all.sh"
