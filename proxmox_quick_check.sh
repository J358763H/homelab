#!/bin/bash

# 🏥 Simple Proxmox LXC Deployment Check
# Quick validation for Proxmox deployment readiness

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🏥 Proxmox LXC Deployment Readiness Check${NC}"
echo "========================================"

# Detect environment
PROXMOX_ENV=false
if grep -q "pve" /proc/version 2>/dev/null || [ -d "/etc/pve" ] 2>/dev/null; then
    PROXMOX_ENV=true
    echo -e "${GREEN}✅ Proxmox VE environment detected${NC}"
else
    echo -e "${YELLOW}ℹ️  Standard Linux environment (not Proxmox)${NC}"
fi

echo ""

# Check critical requirements
echo -e "${BLUE}Critical Checks:${NC}"

# 1. TUN device (critical for Gluetun VPN)
if [ -c "/dev/net/tun" ]; then
    echo -e "${GREEN}✅ TUN device available for VPN containers${NC}"
else
    echo -e "${RED}❌ TUN device missing - Gluetun VPN will fail${NC}"
    echo -e "${YELLOW}   Fix: mknod /dev/net/tun c 10 200 && chmod 666 /dev/net/tun${NC}"
fi

# 2. Docker availability
if command -v docker >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker is installed${NC}"
else
    echo -e "${YELLOW}⚠️  Docker not found - will be installed during deployment${NC}"
fi

# 3. DNS configuration (prevent Pi-hole loops)
if [ -f "/etc/resolv.conf" ]; then
    if grep -v "127\|::1" /etc/resolv.conf | grep -q "nameserver" 2>/dev/null; then
        echo -e "${GREEN}✅ External DNS configured - no Pi-hole loop risk${NC}"
    else
        echo -e "${YELLOW}⚠️  DNS may cause Pi-hole bootstrap loop${NC}"
        echo -e "${YELLOW}   Recommendation: Set external DNS first${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No DNS configuration found${NC}"
fi

# 4. Disk space
available_gb=$(df / 2>/dev/null | awk 'NR==2 {printf "%.1f", $4/1024/1024}' || echo "unknown")
if [ "$available_gb" != "unknown" ] && [ $(echo "$available_gb > 5.0" | bc -l 2>/dev/null || echo 0) -eq 1 ]; then
    echo -e "${GREEN}✅ Sufficient disk space: ${available_gb}GB${NC}"
elif [ "$available_gb" != "unknown" ]; then
    echo -e "${YELLOW}⚠️  Limited disk space: ${available_gb}GB (recommend 5GB+)${NC}"
else
    echo -e "${YELLOW}⚠️  Could not determine disk space${NC}"
fi

echo ""

# Proxmox-specific checks
if [ "$PROXMOX_ENV" = true ]; then
    echo -e "${BLUE}Proxmox LXC Specific:${NC}"

    # Check if running in LXC
    if [ -f "/proc/1/cgroup" ] && grep -q "lxc" /proc/1/cgroup 2>/dev/null; then
        echo -e "${GREEN}✅ Running inside LXC container${NC}"

        # Check container privileges
        if grep -q "unconfined" /proc/mounts 2>/dev/null; then
            echo -e "${GREEN}✅ Container has unconfined AppArmor profile${NC}"
        else
            echo -e "${YELLOW}⚠️  Limited container privileges${NC}"
            echo -e "${YELLOW}   Consider: lxc.apparmor.profile: unconfined${NC}"
        fi
    else
        echo -e "${BLUE}ℹ️  Running on Proxmox host (not in container)${NC}"
    fi

    # Kernel version
    kernel=$(uname -r)
    echo -e "${BLUE}ℹ️  Kernel: $kernel${NC}"
fi

echo ""

# Configuration files check
echo -e "${BLUE}Configuration Check:${NC}"

config_ready=true

if [ -f "deployment/.env" ]; then
    echo -e "${GREEN}✅ Docker environment file exists${NC}"
else
    echo -e "${YELLOW}⚠️  Docker .env file missing${NC}"
    echo -e "${YELLOW}   Copy from: cp deployment/.env.example deployment/.env${NC}"
    config_ready=false
fi

if [ -f "deployment/docker-compose.yml" ]; then
    echo -e "${GREEN}✅ Docker Compose file exists${NC}"
else
    echo -e "${RED}❌ Docker Compose file missing${NC}"
    config_ready=false
fi

echo ""

# Final assessment
echo -e "${BLUE}Assessment:${NC}"
if [ "$config_ready" = true ] && [ -c "/dev/net/tun" ]; then
    echo -e "${GREEN}🚀 Ready for deployment!${NC}"
    exit 0
elif [ "$config_ready" = false ]; then
    echo -e "${YELLOW}📋 Configuration needed before deployment${NC}"
    exit 1
else
    echo -e "${RED}🔧 System requirements need attention${NC}"
    exit 1
fi
