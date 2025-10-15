#!/bin/bash

# =====================================================
# 🧪 Homelab Quick Validation Script
# =====================================================
# Tests configuration without full deployment
# Optimized for Intel Quick Sync systems
# =====================================================

set -e

echo "🧪 Homelab Configuration Validation"
echo "========================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

# Test function
test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "✅ ${GREEN}$2${NC}"
    else
        echo -e "❌ ${RED}$2${NC}"
        ((ERRORS++))
    fi
}

echo "🔧 Testing Docker Compose Configuration..."

# Test docker-compose syntax
if docker compose -f deployment/docker-compose.yml config >/dev/null 2>&1; then
    test_result 0 "Docker Compose syntax valid"
else
    test_result 1 "Docker Compose syntax invalid"
fi

echo
echo "📝 Testing Environment Configuration..."

# Check if .env exists
if [ -f "deployment/.env" ]; then
    test_result 0 ".env file exists"
    
    # Check for placeholder values
    if grep -q "changeme\|your_.*_here\|replace_me" deployment/.env; then
        test_result 1 "Placeholder values found in .env"
    else
        test_result 0 "No placeholder values in .env"
    fi
    
    # Check required variables
    required_vars=("PUID" "PGID" "TZ" "DB_PASS" "JWT_SECRET")
    for var in "${required_vars[@]}"; do
        if grep -q "^${var}=" deployment/.env; then
            test_result 0 "$var defined in .env"
        else
            test_result 1 "$var missing from .env"
        fi
    done
else
    test_result 1 ".env file missing"
fi

echo
echo "🔗 Testing VPN Configuration..."

# Check VPN config
if [ -f "deployment/wg0.conf" ]; then
    test_result 0 "wg0.conf file exists"
    
    # Check for required VPN fields
    vpn_fields=("PrivateKey" "PublicKey" "Endpoint")
    for field in "${vpn_fields[@]}"; do
        if grep -q "^${field}" deployment/wg0.conf; then
            test_result 0 "$field configured in wg0.conf"
        else
            test_result 1 "$field missing from wg0.conf"
        fi
    done
else
    test_result 1 "wg0.conf file missing"
fi

echo
echo "🖥️ Testing Intel Quick Sync Support..."

# Check for Intel GPU (if running on target system)
if [ -e "/dev/dri/renderD128" ]; then
    test_result 0 "Intel GPU device found (/dev/dri/renderD128)"
else
    echo -e "⚠️  ${YELLOW}Intel GPU not detected (normal if testing remotely)${NC}"
fi

# Check render group exists
if getent group render >/dev/null 2>&1; then
    test_result 0 "Render group exists"
    
    # Check if GID is 105 (common default)
    render_gid=$(getent group render | cut -d: -f3)
    if [ "$render_gid" = "105" ]; then
        test_result 0 "Render group GID is 105 (matches config)"
    else
        echo -e "⚠️  ${YELLOW}Render group GID is $render_gid (you may need to update RENDER_GROUP_ID in .env)${NC}"
    fi
else
    test_result 1 "Render group not found"
fi

echo
echo "📜 Testing Shell Scripts..."

# Test shell script syntax
scripts=$(find . -name "*.sh" -type f)
for script in $scripts; do
    if bash -n "$script" >/dev/null 2>&1; then
        test_result 0 "Script syntax valid: $script"
    else
        test_result 1 "Script syntax error: $script"
    fi
done

echo
echo "🌐 Testing Network Configuration..."

# Check for Docker
if command -v docker >/dev/null 2>&1; then
    test_result 0 "Docker installed"
    
    # Check Docker Compose
    if docker compose version >/dev/null 2>&1; then
        test_result 0 "Docker Compose available"
    else
        test_result 1 "Docker Compose not available"
    fi
    
    # Test network creation (dry run)
    if docker network create --driver bridge --subnet 172.20.0.0/16 homelab-test --dry-run >/dev/null 2>&1; then
        test_result 0 "Docker network configuration valid"
    else
        test_result 1 "Docker network configuration invalid"
    fi
else
    test_result 1 "Docker not installed"
fi

echo
echo "📊 Validation Summary"
echo "===================="

if [ $ERRORS -eq 0 ]; then
    echo -e "🎉 ${GREEN}All validation tests passed!${NC}"
    echo -e "✅ ${GREEN}Configuration is ready for deployment${NC}"
    echo
    echo "Next steps:"
    echo "1. Deploy to a VM with Intel GPU passthrough"
    echo "2. Run: docker compose -f deployment/docker-compose.yml up -d"
    echo "3. Verify hardware acceleration in Jellyfin admin panel"
else
    echo -e "⚠️  ${YELLOW}Found $ERRORS configuration issues${NC}"
    echo -e "🔧 ${YELLOW}Please fix the issues above before deployment${NC}"
    exit 1
fi