#!/bin/bash

# Simple LXC deployment script for homelab infrastructure services
echo "📦 Deploying LXC Infrastructure Services..."

# Check if running on Proxmox
if ! command -v pct &> /dev/null; then
    echo "❌ This script requires Proxmox VE (pct command not found)"
    echo "ℹ️  LXC services are optional and run on Proxmox hosts only"
    echo "✅ Docker services can still be deployed without LXC"
    exit 0
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "❌ LXC deployment requires root privileges"
    echo "Usage: sudo ./deploy-lxc.sh"
    exit 1
fi

echo "🔍 Checking Proxmox environment..."

# Check for Ubuntu template
if ! pveam list local | grep -q "ubuntu-22.04"; then
    echo "⚠️  Ubuntu 22.04 LXC template not found"
    echo "📥 Download with: pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
    echo "🔄 Continuing without template check..."
fi

# LXC services in deployment order
LXC_SERVICES=(
    "nginx-proxy-manager:201:Reverse Proxy & SSL"
    "pihole:205:DNS & Ad Blocking"
    "tailscale:202:VPN & Remote Access"
    "ntfy:203:Push Notifications"
    "samba:204:File Sharing"
    "vaultwarden:206:Password Manager"
)

echo ""
echo "🚀 Available LXC Services:"
for service_info in "${LXC_SERVICES[@]}"; do
    IFS=':' read -r service ctid description <<< "$service_info"
    printf "  %-20s (CT %-3s) - %s\n" "$service" "$ctid" "$description"
done

echo ""
read -p "Deploy all LXC services? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ LXC deployment cancelled"
    exit 0
fi

echo ""
echo "📦 Starting LXC service deployment..."

# Deploy each service
for service_info in "${LXC_SERVICES[@]}"; do
    IFS=':' read -r service ctid description <<< "$service_info"

    echo ""
    echo "🔧 Deploying $service (CT $ctid) - $description"

    # Check if container already exists
    if pct status "$ctid" >/dev/null 2>&1; then
        container_status=$(pct status "$ctid" | awk '{print $2}')
        if [[ "$container_status" == "running" ]]; then
            echo "✅ Container $ctid ($service) already running, skipping..."
            continue
        else
            echo "ℹ️  Container $ctid exists but is $container_status"
        fi
    fi

    # Run setup script
    setup_script="../lxc/$service/setup_${service}_lxc.sh"
    if [[ -f "$setup_script" ]]; then
        echo "🔧 Running setup script for $service..."
        if bash "$setup_script" --automated "$ctid"; then
            echo "✅ $service (CT $ctid) deployed successfully"
        else
            echo "❌ Failed to deploy $service (CT $ctid)"
            echo "🔍 Check logs: pct exec $ctid -- journalctl -f"
        fi
    else
        echo "❌ Setup script not found: $setup_script"
    fi

    # Brief pause between deployments
    sleep 5
done

echo ""
echo "🎉 LXC deployment completed!"
echo ""
echo "🌐 Access your services:"
echo "  Nginx Proxy Manager: http://192.168.1.201:81"
echo "  Pi-hole:             http://192.168.1.205:80"
echo "  Ntfy:                http://192.168.1.203:80"
echo "  Vaultwarden:         http://192.168.1.206:80"
echo ""
echo "🔧 Next steps:"
echo "1. Configure Nginx Proxy Manager with your Docker services"
echo "2. Set up Pi-hole as your network DNS server"
echo "3. Configure Tailscale for remote access"
echo ""
echo "📖 For detailed configuration, see: lxc/*/README.md"
