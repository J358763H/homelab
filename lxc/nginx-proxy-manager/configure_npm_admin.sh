#!/bin/bash

# =====================================================
# 🔐 Nginx Proxy Manager Admin Setup Script
# =====================================================
# Configures NPM admin credentials automatically
# =====================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CTID="${1:-201}"
NPM_URL="http://192.168.1.201:81"

# Functions
log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"; exit 1; }

# Load environment configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../.env" ]]; then
    source "$SCRIPT_DIR/../.env"
    log "Loaded environment configuration"
else
    error "Environment file not found at $SCRIPT_DIR/../.env"
fi

# Validate required variables
if [[ -z "${NPM_ADMIN_EMAIL:-}" ]] || [[ -z "${NPM_ADMIN_PASSWORD:-}" ]]; then
    error "NPM_ADMIN_EMAIL and NPM_ADMIN_PASSWORD must be set in .env file"
fi

log "Configuring NPM admin credentials for container $CTID..."

# Wait for NPM to be ready
log "Waiting for NPM to be accessible..."
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if pct exec $CTID -- curl -s -o /dev/null -w '%{http_code}' http://localhost:81 | grep -q '200\|302\|401'; then
        log "NPM is accessible (attempt $attempt)"
        break
    fi
    
    log "NPM not ready, attempt $attempt/$max_attempts"
    sleep 5
    ((attempt++))
    
    if [ $attempt -gt $max_attempts ]; then
        error "NPM failed to become accessible"
    fi
done

# Install jq for JSON processing if not available
pct exec $CTID -- bash -c "
    if ! command -v jq &> /dev/null; then
        apt update && apt install -y jq curl
    fi
"

# Create admin setup script inside container
pct exec $CTID -- bash -c "cat > /tmp/setup_admin.sh << 'SCRIPT_EOF'
#!/bin/bash
set -e

NPM_API=\"http://localhost:81/api\"
ADMIN_EMAIL=\"$NPM_ADMIN_EMAIL\"
ADMIN_PASSWORD=\"$NPM_ADMIN_PASSWORD\"

echo 'Attempting initial login with default credentials...'
LOGIN_RESPONSE=\$(curl -s -X POST \"\$NPM_API/tokens\" \
    -H 'Content-Type: application/json' \
    -d '{\"identity\":\"admin@example.com\",\"secret\":\"changeme\"}' || echo 'failed')

if [[ \"\$LOGIN_RESPONSE\" == 'failed' ]] || ! echo \"\$LOGIN_RESPONSE\" | jq -e '.token' > /dev/null 2>&1; then
    echo 'Default login failed - admin may already be configured'
    echo 'Attempting login with configured credentials...'
    LOGIN_RESPONSE=\$(curl -s -X POST \"\$NPM_API/tokens\" \
        -H 'Content-Type: application/json' \
        -d '{\"identity\":\"'\$ADMIN_EMAIL'\",\"secret\":\"'\$ADMIN_PASSWORD'\"}' || echo 'failed')
    
    if [[ \"\$LOGIN_RESPONSE\" == 'failed' ]] || ! echo \"\$LOGIN_RESPONSE\" | jq -e '.token' > /dev/null 2>&1; then
        echo 'Both login attempts failed - manual configuration may be required'
        exit 1
    else
        echo 'Successfully logged in with configured credentials - admin already set up'
        exit 0
    fi
fi

# Extract token from successful default login
TOKEN=\$(echo \"\$LOGIN_RESPONSE\" | jq -r '.token')
echo \"Successfully logged in with default credentials, token obtained\"

# Get current user info
USER_INFO=\$(curl -s -X GET \"\$NPM_API/users/me\" \
    -H \"Authorization: Bearer \$TOKEN\")

USER_ID=\$(echo \"\$USER_INFO\" | jq -r '.id')
echo \"Current user ID: \$USER_ID\"

# Update admin credentials
echo \"Updating admin credentials...\"
UPDATE_RESPONSE=\$(curl -s -X PUT \"\$NPM_API/users/\$USER_ID\" \
    -H \"Authorization: Bearer \$TOKEN\" \
    -H 'Content-Type: application/json' \
    -d '{
        \"email\": \"'\$ADMIN_EMAIL'\",
        \"nickname\": \"Admin\",
        \"first_name\": \"Homelab\",
        \"last_name\": \"Administrator\",
        \"avatar\": \"\",
        \"roles\": [\"admin\"]
    }')

echo \"Profile update response: \$UPDATE_RESPONSE\"

# Change password
echo \"Updating password...\"
PASSWORD_RESPONSE=\$(curl -s -X PUT \"\$NPM_API/users/\$USER_ID/auth\" \
    -H \"Authorization: Bearer \$TOKEN\" \
    -H 'Content-Type: application/json' \
    -d '{
        \"type\": \"password\",
        \"current\": \"changeme\",
        \"secret\": \"'\$ADMIN_PASSWORD'\"
    }')

echo \"Password update response: \$PASSWORD_RESPONSE\"

# Verify new credentials work
echo \"Verifying new credentials...\"
VERIFY_RESPONSE=\$(curl -s -X POST \"\$NPM_API/tokens\" \
    -H 'Content-Type: application/json' \
    -d '{\"identity\":\"'\$ADMIN_EMAIL'\",\"secret\":\"'\$ADMIN_PASSWORD'\"}')

if echo \"\$VERIFY_RESPONSE\" | jq -e '.token' > /dev/null 2>&1; then
    echo \"✅ Admin credentials successfully configured and verified!\"
    echo \"Email: \$ADMIN_EMAIL\"
    echo \"Password: [configured]\"
else
    echo \"❌ Failed to verify new credentials\"
    exit 1
fi
SCRIPT_EOF

chmod +x /tmp/setup_admin.sh
/tmp/setup_admin.sh
rm /tmp/setup_admin.sh
"

if [[ $? -eq 0 ]]; then
    success "NPM admin credentials configured successfully!"
    echo
    echo -e "${BLUE}NPM Admin Access:${NC}"
    echo -e "URL:      ${GREEN}$NPM_URL${NC}"
    echo -e "Email:    ${GREEN}$NPM_ADMIN_EMAIL${NC}"
    echo -e "Password: ${GREEN}[configured]${NC}"
    echo
else
    error "Failed to configure NPM admin credentials"
fi