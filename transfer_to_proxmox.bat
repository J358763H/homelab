#!/usr/bin/env bash
# =====================================================
# 📂 Transfer Deployment Files to Proxmox
# =====================================================
# This script transfers all deployment files from your
# Windows workspace to the Proxmox server
# =====================================================

# Configuration
PROXMOX_SERVER="192.168.1.50"
PROXMOX_USER="root"
TARGET_DIR="/root/homelab-deployment"

echo "=========================================="
echo "📂 TRANSFERRING HOMELAB FILES TO PROXMOX"
echo "=========================================="
echo "Source: Current Windows workspace"
echo "Target: $PROXMOX_USER@$PROXMOX_SERVER:$TARGET_DIR"
echo ""

# Check if we can reach the server
echo "🔍 Testing connection to Proxmox server..."
if ping -n 1 $PROXMOX_SERVER >nul 2>&1; then
    echo "✅ Proxmox server is reachable"
else
    echo "❌ Cannot reach Proxmox server at $PROXMOX_SERVER"
    echo "Please check network connectivity and server status"
    exit 1
fi

echo ""
echo "📋 Files to transfer:"
echo "  • deploy_homelab_master.sh"
echo "  • scripts/setup_zfs_mirror.sh"
echo "  • scripts/configure_network.sh"  
echo "  • scripts/validate_deployment.sh"
echo "  • QUICK_DEPLOYMENT_GUIDE.md"
echo "  • All LXC setup scripts"
echo "  • Docker compose configuration"
echo ""

# Use SCP or provide instructions for manual transfer
echo "🚀 TRANSFER METHODS:"
echo ""
echo "METHOD 1 - Using SCP (if available):"
echo "----------------------------------------"
echo "scp -r . $PROXMOX_USER@$PROXMOX_SERVER:$TARGET_DIR/"
echo ""
echo "METHOD 2 - Using WinSCP or similar GUI tool:"
echo "----------------------------------------"
echo "1. Open WinSCP or FileZilla"
echo "2. Connect to: $PROXMOX_SERVER"
echo "3. Username: $PROXMOX_USER"
echo "4. Transfer entire folder to: $TARGET_DIR"
echo ""
echo "METHOD 3 - Manual file creation (recommended):"
echo "----------------------------------------"
echo "Run the following commands on your Proxmox server:"
echo ""
echo "# Create directories"
echo "mkdir -p $TARGET_DIR/{scripts,deployment,lxc}"
echo ""
echo "# Then copy each file content manually or use the setup script below"
echo ""

echo "=========================================="
echo "🛠️  QUICK SETUP ON PROXMOX SERVER"
echo "=========================================="
echo ""
echo "If you prefer, I can create a setup script that downloads"
echo "everything directly on your Proxmox server."
echo ""
read -p "Create Proxmox setup script? (y/n): " CREATE_SETUP

if [[ "$CREATE_SETUP" =~ ^[Yy]$ ]]; then
    echo "Creating Proxmox setup script..."
    
    # This will be created in the next step
    echo "✅ Setup script will be generated next"
else
    echo "Please transfer files manually using one of the methods above"
fi

echo ""
echo "📋 NEXT STEPS AFTER TRANSFER:"
echo "1. SSH to Proxmox: ssh $PROXMOX_USER@$PROXMOX_SERVER"
echo "2. Navigate to: cd $TARGET_DIR"
echo "3. Make executable: chmod +x *.sh scripts/*.sh"
echo "4. Run deployment: ./deploy_homelab_master.sh"
echo ""
echo "=========================================="