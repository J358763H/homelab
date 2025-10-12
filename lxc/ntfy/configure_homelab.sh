#!/bin/bash

# =====================================================
# 🔧 Configure Homelab for Self-Hosted Ntfy
# =====================================================
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-11
# 
# Updates homelab configuration to use self-hosted Ntfy
# Run this after setting up your Ntfy LXC container
# =====================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =================
# Configuration
# =================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMELAB_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$HOMELAB_ROOT/deployment/.env"
ENV_EXAMPLE="$HOMELAB_ROOT/deployment/.env.example"

# Default Ntfy server (will be updated by user input)
NTFY_SERVER=""
NTFY_TOPIC_ALERTS="homelab-shv-alerts"
NTFY_TOPIC_SUMMARY="homelab-shv-summary"

# =================
# Helper Functions
# =================
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

prompt() {
    echo -e "${BLUE}$1${NC}"
}

# =================
# Get User Input
# =================
echo -e "${GREEN}=== Homelab Ntfy Configuration Update ===${NC}"
echo ""

prompt "Enter your Ntfy server URL (e.g., http://192.168.1.200):"
read -r NTFY_SERVER

if [[ -z "$NTFY_SERVER" ]]; then
    error "Ntfy server URL cannot be empty"
fi

# Validate URL format
if [[ ! "$NTFY_SERVER" =~ ^https?:// ]]; then
    warn "URL should start with http:// or https://"
    prompt "Continue anyway? (y/N):"
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        error "Configuration cancelled"
    fi
fi

prompt "Enter alert topic name (default: $NTFY_TOPIC_ALERTS):"
read -r topic_input
if [[ -n "$topic_input" ]]; then
    NTFY_TOPIC_ALERTS="$topic_input"
fi

prompt "Enter summary topic name (default: $NTFY_TOPIC_SUMMARY):"
read -r topic_input
if [[ -n "$topic_input" ]]; then
    NTFY_TOPIC_SUMMARY="$topic_input"
fi

# =================
# Update .env File
# =================
if [[ -f "$ENV_FILE" ]]; then
    log "Updating existing .env file..."
    
    # Backup existing file
    cp "$ENV_FILE" "$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    log "Backup created: $ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Update Ntfy settings
    sed -i "s|^NTFY_SERVER=.*|NTFY_SERVER=$NTFY_SERVER|" "$ENV_FILE"
    sed -i "s|^NTFY_TOPIC_ALERTS=.*|NTFY_TOPIC_ALERTS=$NTFY_TOPIC_ALERTS|" "$ENV_FILE"
    sed -i "s|^NTFY_TOPIC_SUMMARY=.*|NTFY_TOPIC_SUMMARY=$NTFY_TOPIC_SUMMARY|" "$ENV_FILE"
    
else
    warn ".env file not found. Creating from template..."
    
    if [[ ! -f "$ENV_EXAMPLE" ]]; then
        error ".env.example template not found at $ENV_EXAMPLE"
    fi
    
    # Copy template and update
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    sed -i "s|^NTFY_SERVER=.*|NTFY_SERVER=$NTFY_SERVER|" "$ENV_FILE"
    sed -i "s|^NTFY_TOPIC_ALERTS=.*|NTFY_TOPIC_ALERTS=$NTFY_TOPIC_ALERTS|" "$ENV_FILE"
    sed -i "s|^NTFY_TOPIC_SUMMARY=.*|NTFY_TOPIC_SUMMARY=$NTFY_TOPIC_SUMMARY|" "$ENV_FILE"
    
    log "Created .env file from template"
fi

# =================
# Test Connection
# =================
log "Testing connection to Ntfy server..."

if command -v curl >/dev/null 2>&1; then
    if curl -s --connect-timeout 5 "$NTFY_SERVER" >/dev/null; then
        log "✅ Successfully connected to $NTFY_SERVER"
        
        # Send test message
        prompt "Send test notification? (y/N):"
        read -r send_test
        if [[ "$send_test" == "y" || "$send_test" == "Y" ]]; then
            curl -d "🏠 Homelab-SHV configuration updated! Self-hosted Ntfy is now active." \
                 -H "title: Homelab Setup" \
                 -H "tags: house,gear" \
                 "$NTFY_SERVER/$NTFY_TOPIC_SUMMARY" 2>/dev/null || warn "Test message failed"
            log "Test notification sent to topic: $NTFY_TOPIC_SUMMARY"
        fi
    else
        warn "❌ Could not connect to $NTFY_SERVER"
        warn "Please verify your Ntfy server is running and accessible"
    fi
else
    warn "curl not available for connection testing"
fi

# =================
# Update Documentation
# =================
log "Configuration complete!"
echo ""
echo -e "${GREEN}=== Updated Configuration ===${NC}"
echo -e "Ntfy Server: ${BLUE}$NTFY_SERVER${NC}"
echo -e "Alert Topic: ${BLUE}$NTFY_TOPIC_ALERTS${NC}"
echo -e "Summary Topic: ${BLUE}$NTFY_TOPIC_SUMMARY${NC}"
echo ""
echo -e "${GREEN}=== Next Steps ===${NC}"
echo "1. Restart your homelab services to use the new configuration:"
echo "   ${YELLOW}cd $HOMELAB_ROOT && ./homelab.sh restart${NC}"
echo ""
echo "2. Subscribe to your topics:"
echo "   ${YELLOW}$NTFY_SERVER/$NTFY_TOPIC_ALERTS${NC}"
echo "   ${YELLOW}$NTFY_SERVER/$NTFY_TOPIC_SUMMARY${NC}"
echo ""
echo "3. Test your monitoring scripts:"
echo "   ${YELLOW}cd $HOMELAB_ROOT/scripts/monitoring && ./weekly_system_health.sh${NC}"
echo ""
log "All done! 🎉"