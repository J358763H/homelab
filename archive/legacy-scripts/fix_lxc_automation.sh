#!/bin/bash

# 🔧 LXC Script Automation Fixer
# Adds automation support to all LXC setup scripts

set -euo pipefail

echo "🔧 Fixing LXC Script Automation Issues..."

# Find all LXC setup scripts
LXC_SCRIPTS=(
    "lxc/nginx-proxy-manager/setup_npm_lxc.sh"
    "lxc/tailscale/setup_tailscale_lxc.sh"
    "lxc/ntfy/setup_ntfy_lxc.sh"
    "lxc/samba/setup_samba_lxc.sh"
    "lxc/vaultwarden/setup_vaultwarden_lxc.sh"
)

for script in "${LXC_SCRIPTS[@]}"; do
    if [[ -f "$script" ]]; then
        echo "📝 Processing: $script"
        
        # Add automated mode check if not present
        if ! grep -q "AUTOMATED_MODE" "$script"; then
            echo "  ➤ Adding automation support..."
            
            # Find the line after the shebang and color definitions
            sed -i '/^# 📋 Configuration/i\
# 🤖 Check for automated mode\
AUTOMATED_MODE=false\
if [[ "${1:-}" == "--automated" ]] || [[ "${AUTOMATED_MODE:-false}" == "true" ]] || [[ -n "${HOMELAB_DEPLOYMENT:-}" ]]; then\
    AUTOMATED_MODE=true\
fi\
' "$script"
        fi
        
        # Fix interactive prompts
        if grep -q "read -p.*destroy and recreate" "$script"; then
            echo "  ➤ Fixing interactive prompts..."
            
            # Replace the interactive prompt section
            sed -i '/read -p.*destroy and recreate/,/fi/c\
        if [[ "$AUTOMATED_MODE" == "true" ]]; then\
            # In automated mode, check if container is running\
            local container_status=$(pct status "$CONTAINER_ID" 2>/dev/null | awk '\''{print $2}'\'' || echo "unknown")\
            if [[ "$container_status" == "running" ]]; then\
                echo "[SUCCESS] Container $CONTAINER_ID is already running, skipping recreation"\
                exit 0\
            else\
                echo "[INFO] Container exists but not running, recreating in automated mode..."\
                pct stop "$CONTAINER_ID" 2>/dev/null || true\
                pct destroy "$CONTAINER_ID"\
                echo "[SUCCESS] Existing container removed"\
            fi\
        else\
            read -p "Do you want to destroy and recreate it? (y/N): " -n 1 -r\
            echo\
            if [[ $REPLY =~ ^[Yy]$ ]]; then\
                pct stop "$CONTAINER_ID" || true\
                pct destroy "$CONTAINER_ID"\
                echo "[SUCCESS] Existing container removed"\
            else\
                echo "[ERROR] Aborting setup"\
                exit 1\
            fi\
        fi' "$script"
        fi
        
        # Fix Tailscale auth key prompt specifically
        if [[ "$script" == *"tailscale"* ]] && grep -q "read -p.*auth key" "$script"; then
            echo "  ➤ Fixing Tailscale auth key prompt..."
            
            sed -i '/read -p.*auth key/c\
if [[ "$AUTOMATED_MODE" == "true" ]]; then\
    if [[ -z "${TAILSCALE_AUTH_KEY:-}" ]]; then\
        echo "[ERROR] TAILSCALE_AUTH_KEY environment variable required in automated mode"\
        exit 1\
    fi\
    AUTH_KEY="$TAILSCALE_AUTH_KEY"\
else\
    read -p "Enter your Tailscale auth key: " -r AUTH_KEY\
fi' "$script"
        fi
        
        echo "  ✅ Processed: $script"
    else
        echo "  ⚠️  Script not found: $script"
    fi
done

echo "🎉 LXC script automation fixes complete!"
echo ""
echo "📋 Usage Notes:"
echo "  - Scripts now support --automated flag"
echo "  - Set AUTOMATED_MODE=true environment variable"
echo "  - For Tailscale: set TAILSCALE_AUTH_KEY environment variable"
echo "  - Existing running containers will be skipped automatically"