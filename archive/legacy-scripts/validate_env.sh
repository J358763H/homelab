#!/bin/bash

# =====================================================
# 🔧 Environment Configuration Validator
# =====================================================
# Validates that required environment variables are set
# Usage: ./validate_env.sh
# =====================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[VALIDATE] $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Check if .env file exists
if [[ ! -f "deployment/.env" ]]; then
    error ".env file missing"
    echo ""
    echo "📋 To fix this:"
    echo "   cp deployment/.env.example deployment/.env"
    echo "   nano deployment/.env  # Edit with your values"
    exit 1
fi

success ".env file exists"

# Load .env file
set -a
source deployment/.env
set +a

# Required variables
required_vars=(
    "TZ"
    "PUID"
    "PGID"
    "DB_USER"
    "DB_PASS"
    "JWT_SECRET"
)

# Optional but recommended variables
recommended_vars=(
    "VPN_SERVICE_PROVIDER"
    "WIREGUARD_PRIVATE_KEY"
    "RADARR_API_KEY"
    "SONARR_API_KEY"
)

# Check required variables
missing_required=0
for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        error "Required variable $var is not set"
        missing_required=1
    else
        success "Required variable $var is set"
    fi
done

# Check recommended variables
missing_recommended=0
for var in "${recommended_vars[@]}"; do
    if [[ -z "${!var:-}" ]] || [[ "${!var}" == *"your_"* ]]; then
        warn "Recommended variable $var is not configured"
        missing_recommended=1
    else
        success "Recommended variable $var is configured"
    fi
done

echo ""
if [[ $missing_required -eq 0 ]]; then
    success "All required environment variables are set"
    if [[ $missing_recommended -eq 0 ]]; then
        success "All recommended variables are configured"
        echo ""
        echo "🚀 Your environment is ready for deployment!"
    else
        warn "Some recommended variables need configuration"
        echo ""
        echo "📋 Your environment will work but consider configuring the recommended variables"
    fi
else
    error "Missing required environment variables"
    echo ""
    echo "📋 Please edit deployment/.env and set the missing required variables"
    exit 1
fi
