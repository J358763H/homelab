#!/bin/bash

# 🎯 FINAL DEPLOYMENT ASSESSMENT
# Last check before deployment - focuses on critical success factors
# Run this immediately before deploying

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🎯 FINAL DEPLOYMENT ASSESSMENT${NC}"
echo "============================================"
echo -e "${BLUE}Checking critical factors for deployment success...${NC}"

BLOCKERS=0
WARNINGS=0

# BLOCKER 1: Proxmox cluster timeout (will hang deployment)
echo -e "\n${BLUE}🏥 Proxmox Environment${NC}"
if grep -q "pve" /proc/version 2>/dev/null || [ -d "/etc/pve" ] 2>/dev/null; then
    echo -e "${GREEN}✅ Proxmox VE detected${NC}"

    if [ -f "/etc/systemd/system/pve-cluster.service.d/override.conf" ]; then
        timeout=$(grep "TimeoutStopSec" /etc/systemd/system/pve-cluster.service.d/override.conf 2>/dev/null | cut -d'=' -f2)
        echo -e "${GREEN}✅ Cluster timeout fixed: $timeout${NC}"
    else
        echo -e "${RED}❌ DEPLOYMENT BLOCKER: Cluster timeout not fixed${NC}"
        echo -e "${YELLOW}   Will cause 90+ second hangs during deployment${NC}"
        echo -e "${YELLOW}   Fix: ./fix_critical_deployment.sh${NC}"
        ((BLOCKERS++))
    fi
else
    echo -e "${BLUE}ℹ️  Standard Linux environment${NC}"
fi

# BLOCKER 2: Environment configuration
echo -e "\n${BLUE}⚙️  Environment Configuration${NC}"
if [ -f ".env" ]; then
    echo -e "${GREEN}✅ .env file exists${NC}"

    # Check critical variables (check for your actual variable names)
    critical_vars=("HOMELAB_TIMEZONE" "TAILSCALE_AUTH_KEY" "NPM_ADMIN_EMAIL")
    missing_vars=0

    for var in "${critical_vars[@]}"; do
        if ! grep -q "^${var}=" .env 2>/dev/null; then
            echo -e "${RED}❌ Missing critical variable: $var${NC}"
            ((missing_vars++))
        fi
    done

    if [ $missing_vars -gt 0 ]; then
        echo -e "${RED}❌ DEPLOYMENT BLOCKER: $missing_vars critical variables missing${NC}"
        ((BLOCKERS++))
    else
        echo -e "${GREEN}✅ Critical environment variables configured${NC}"
    fi

    # Check for placeholder values
    if grep -q "changeme\|your_\|placeholder" .env 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Contains placeholder values - may cause issues${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}❌ DEPLOYMENT BLOCKER: .env file missing${NC}"
    echo -e "${YELLOW}   Required for Docker Compose variable substitution${NC}"
    ((BLOCKERS++))
fi

# BLOCKER 3: Docker availability
echo -e "\n${BLUE}🐳 Docker Environment${NC}"
if command -v docker >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker installed: $(docker --version | cut -d' ' -f3)${NC}"

    if docker compose version >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker Compose available${NC}"
    else
        echo -e "${RED}❌ DEPLOYMENT BLOCKER: Docker Compose not available${NC}"
        ((BLOCKERS++))
    fi

    # Check if Docker daemon is running
    if docker info >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker daemon running${NC}"
    else
        echo -e "${RED}❌ DEPLOYMENT BLOCKER: Docker daemon not running${NC}"
        echo -e "${YELLOW}   Fix: systemctl start docker${NC}"
        ((BLOCKERS++))
    fi
else
    echo -e "${RED}❌ DEPLOYMENT BLOCKER: Docker not installed${NC}"
    ((BLOCKERS++))
fi

# BLOCKER 4: Compose file validation
echo -e "\n${BLUE}📋 Docker Compose Validation${NC}"
compose_files=($(find . -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null || true))

if [ ${#compose_files[@]} -eq 0 ]; then
    echo -e "${RED}❌ DEPLOYMENT BLOCKER: No Docker Compose files found${NC}"
    ((BLOCKERS++))
else
    echo -e "${GREEN}✅ Found ${#compose_files[@]} compose file(s)${NC}"

    syntax_errors=0
    for compose_file in "${compose_files[@]}"; do
        if command -v docker >/dev/null 2>&1; then
            if docker compose -f "$compose_file" config >/dev/null 2>&1; then
                echo -e "${GREEN}✅ $(basename "$compose_file") - syntax valid${NC}"
            else
                echo -e "${RED}❌ $(basename "$compose_file") - syntax errors${NC}"
                ((syntax_errors++))
            fi
        fi
    done

    if [ $syntax_errors -gt 0 ]; then
        echo -e "${RED}❌ DEPLOYMENT BLOCKER: $syntax_errors compose file(s) have errors${NC}"
        ((BLOCKERS++))
    fi
fi

# WARNING: Storage check
echo -e "\n${BLUE}💾 Storage Assessment${NC}"
available_gb=$(df / 2>/dev/null | awk 'NR==2 {printf "%.1f", $4/1024/1024}' || echo "unknown")
if [ "$available_gb" != "unknown" ]; then
    if (( $(echo "$available_gb > 20.0" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "${GREEN}✅ Sufficient storage: ${available_gb}GB available${NC}"
    elif (( $(echo "$available_gb > 5.0" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "${YELLOW}⚠️  Limited storage: ${available_gb}GB available${NC}"
        echo -e "${YELLOW}   Consider cleanup before deployment${NC}"
        ((WARNINGS++))
    else
        echo -e "${RED}❌ DEPLOYMENT BLOCKER: Insufficient storage: ${available_gb}GB${NC}"
        echo -e "${YELLOW}   Need at least 5GB for safe deployment${NC}"
        ((BLOCKERS++))
    fi
fi

# WARNING: Network conflicts
echo -e "\n${BLUE}🌐 Network Conflicts${NC}"
if netstat -tulpn 2>/dev/null | grep -q ":80\|:443\|:8080" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Common ports (80, 443, 8080) may be in use${NC}"
    echo -e "${YELLOW}   Could cause container startup failures${NC}"
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ Common ports appear available${NC}"
fi

# WARNING: Critical services resource limits
echo -e "\n${BLUE}🎯 Resource Management${NC}"
resource_intensive=("plex" "jellyfin" "sonarr" "radarr" "qbittorrent" "prometheus")
services_without_limits=0

for service in "${resource_intensive[@]}"; do
    if grep -r "^[[:space:]]*${service}:" . --include="*.yml" >/dev/null 2>&1; then
        if ! grep -A 20 "^[[:space:]]*${service}:" $(find . -name "*.yml") | grep -q "deploy:.*resources\|mem_limit:" 2>/dev/null; then
            ((services_without_limits++))
        fi
    fi
done

if [ $services_without_limits -eq 0 ]; then
    echo -e "${GREEN}✅ Resource limits configured${NC}"
elif [ $services_without_limits -le 2 ]; then
    echo -e "${YELLOW}⚠️  $services_without_limits service(s) without resource limits${NC}"
    echo -e "${YELLOW}   May cause memory exhaustion during deployment${NC}"
    ((WARNINGS++))
else
    echo -e "${RED}❌ DEPLOYMENT BLOCKER: $services_without_limits services without limits${NC}"
    echo -e "${YELLOW}   High risk of out-of-memory kills${NC}"
    ((BLOCKERS++))
fi

echo ""
echo "=============================================="

# FINAL VERDICT
if [ $BLOCKERS -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}🚀 DEPLOYMENT READY - PROCEED NOW!${NC}"
        echo -e "${GREEN}All critical checks passed${NC}"
        echo ""
        echo -e "${BLUE}Recommended deployment sequence:${NC}"
        echo "1. ./proxmox_deployment_preflight.sh check"
        echo "2. ./deploy_homelab_master.sh"
        echo ""
        echo -e "${GREEN}Success probability: Very High ✨${NC}"
        exit 0
    else
        echo -e "${YELLOW}🟡 DEPLOYMENT READY WITH WARNINGS${NC}"
        echo -e "${YELLOW}$WARNINGS warning(s) - deployment possible but monitor closely${NC}"
        echo ""
        echo -e "${BLUE}You can proceed, but consider addressing warnings${NC}"
        echo -e "${GREEN}Success probability: High 📈${NC}"
        exit 1
    fi
else
    echo -e "${RED}🛑 DEPLOYMENT BLOCKED${NC}"
    echo -e "${RED}$BLOCKERS critical blocker(s) MUST be fixed before deployment${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}$WARNINGS additional warning(s) should also be addressed${NC}"
    fi
    echo ""
    echo -e "${BLUE}🔧 Quick fix:${NC}"
    echo "./fix_critical_deployment.sh"
    echo ""
    echo -e "${BLUE}Then re-run:${NC}"
    echo "./final_deployment_assessment.sh"
    echo ""
    echo -e "${RED}Success probability: Low ❌${NC}"
    exit 2
fi
