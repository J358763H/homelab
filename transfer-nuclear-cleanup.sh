#!/bin/bash
# =====================================================
# 🚀 Transfer Nuclear Cleanup to Proxmox
# =====================================================

# Configuration
PROXMOX_IP=""
PROXMOX_USER="root"
SCRIPT_NAME="proxmox-nuclear-cleanup.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Transfer Nuclear Cleanup Script to Proxmox${NC}"
echo ""

# Get Proxmox IP if not set
if [[ -z "$PROXMOX_IP" ]]; then
    read -p "Enter your Proxmox server IP: " PROXMOX_IP
fi

# Verify script exists
if [[ ! -f "$SCRIPT_NAME" ]]; then
    echo -e "${RED}❌ Error: $SCRIPT_NAME not found in current directory${NC}"
    echo "Make sure you're running this from the homelab directory"
    exit 1
fi

# Transfer script
echo -e "${YELLOW}📤 Transferring $SCRIPT_NAME to Proxmox...${NC}"
scp "$SCRIPT_NAME" "$PROXMOX_USER@$PROXMOX_IP:/root/"

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Transfer successful!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. SSH to your Proxmox server:"
    echo -e "   ${YELLOW}ssh $PROXMOX_USER@$PROXMOX_IP${NC}"
    echo ""
    echo "2. Make the script executable and run it:"
    echo -e "   ${YELLOW}chmod +x $SCRIPT_NAME${NC}"
    echo -e "   ${YELLOW}sudo ./$SCRIPT_NAME${NC}"
    echo ""
    echo -e "${RED}⚠️ WARNING: This will destroy everything on Proxmox!${NC}"
else
    echo -e "${RED}❌ Transfer failed. Check your connection and try again.${NC}"
    exit 1
fi
