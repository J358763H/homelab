#!/bin/bash
# =====================================================
# 🏠 Homelab-SHV — Master Control Script
# =====================================================
# Usage:
#   ./homelab.sh deploy    # Run deploy_homelab.sh
#   ./homelab.sh teardown  # Run teardown_homelab.sh
#   ./homelab.sh reset     # Run reset_homelab.sh
#   ./homelab.sh status    # Run status_homelab.sh
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
  echo "Usage: $0 {deploy|teardown|reset|status}"
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
  *)
    echo "Invalid option: $ACTION"
    echo "Usage: $0 {deploy|teardown|reset|status}"
    exit 1
    ;;
esac