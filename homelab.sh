#!/bin/bash
# =====================================================
# 🏠 Homelab-SHV — Master Control Script
# =====================================================
# Usage:
#   ./homelab.sh deploy    # Run deploy_homelab.sh
#   ./homelab.sh teardown  # Run teardown_homelab.sh
#   ./homelab.sh reset     # Run reset_homelab.sh
#   ./homelab.sh status    # Run status_homelab.sh
#   ./homelab.sh lxc       # Deploy LXC containers (NPM, Tailscale, Ntfy, Samba, Pi-hole)
# =====================================================
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-11
# =====================================================

set -e

ACTION=$1

# Make sure all scripts are executable
chmod +x ./*.sh

if [ -z "$ACTION" ]; then
  echo "Usage: $0 {deploy|teardown|reset|status|lxc}"
  exit 1
fi

case "$ACTION" in
  deploy)
    echo "🚀 Deploying Homelab-SHV..."
    chmod +x deploy_homelab.sh
    ./deploy_homelab.sh
    ;;
  teardown)
    echo "🧹 Tearing down Homelab-SHV..."
    chmod +x teardown_homelab.sh
    ./teardown_homelab.sh
    ;;
  reset)
    echo "🔄 Resetting Homelab-SHV..."
    chmod +x reset_homelab.sh
    ./reset_homelab.sh
    ;;
  status)
    echo "📊 Checking Homelab-SHV status..."
    chmod +x status_homelab.sh
    ./status_homelab.sh
    ;;
  lxc)
    echo "📦 Deploying LXC containers..."
    echo "Available LXC deployments:"
    echo "  1. Nginx Proxy Manager (192.168.1.201)"
    echo "  2. Tailscale Router (192.168.1.202)" 
    echo "  3. Ntfy Notifications (192.168.1.203)"
    echo "  4. Samba File Share (192.168.1.204)"
    echo "  5. Pi-hole DNS/Ad Blocker (192.168.1.205)"
    echo ""
    read -p "Enter container number to deploy (1-5) or 'all' for everything: " choice
    
    case "$choice" in
      1)
        echo "🔗 Deploying Nginx Proxy Manager..."
        chmod +x lxc/nginx-proxy-manager/setup_npm_lxc.sh
        ./lxc/nginx-proxy-manager/setup_npm_lxc.sh
        ;;
      2)
        echo "🔒 Deploying Tailscale Router..."
        chmod +x lxc/tailscale/setup_tailscale_lxc.sh
        ./lxc/tailscale/setup_tailscale_lxc.sh
        ;;
      3)
        echo "📢 Deploying Ntfy Notifications..."
        chmod +x lxc/ntfy/setup_ntfy_lxc.sh
        ./lxc/ntfy/setup_ntfy_lxc.sh
        ;;
      4)
        echo "📁 Deploying Samba File Share..."
        chmod +x lxc/samba/setup_samba_lxc.sh
        ./lxc/samba/setup_samba_lxc.sh
        ;;
      5)
        echo "🕳️ Deploying Pi-hole DNS/Ad Blocker..."
        chmod +x lxc/pihole/setup_pihole_lxc.sh
        ./lxc/pihole/setup_pihole_lxc.sh
        ;;
      all)
        echo "🚀 Deploying all LXC containers..."
        echo "This will deploy NPM, Tailscale, Ntfy, Samba, and Pi-hole..."
        read -p "Continue? (y/N): " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
          chmod +x lxc/nginx-proxy-manager/setup_npm_lxc.sh
          chmod +x lxc/tailscale/setup_tailscale_lxc.sh
          chmod +x lxc/ntfy/setup_ntfy_lxc.sh
          chmod +x lxc/samba/setup_samba_lxc.sh
          chmod +x lxc/pihole/setup_pihole_lxc.sh
          
          echo "1/5 🔗 Deploying Nginx Proxy Manager..."
          ./lxc/nginx-proxy-manager/setup_npm_lxc.sh
          
          echo "2/5 🔒 Deploying Tailscale Router..."
          ./lxc/tailscale/setup_tailscale_lxc.sh
          
          echo "3/5 📢 Deploying Ntfy Notifications..."
          ./lxc/ntfy/setup_ntfy_lxc.sh
          
          echo "4/5 📁 Deploying Samba File Share..."
          ./lxc/samba/setup_samba_lxc.sh
          
          echo "5/5 🕳️ Deploying Pi-hole DNS/Ad Blocker..."
          ./lxc/pihole/setup_pihole_lxc.sh
          
          echo "🎉 All LXC containers deployed successfully!"
        else
          echo "❌ Deployment cancelled"
        fi
        ;;
      *)
        echo "Invalid choice. Please select 1-5 or 'all'"
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Invalid option: $ACTION"
    echo "Usage: $0 {deploy|teardown|reset|status|lxc}"
    exit 1
    ;;
esac