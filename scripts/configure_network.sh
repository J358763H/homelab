#!/usr/bin/env bash
# =====================================================
# 🌐 Network Configuration Alignment Script
# =====================================================
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Created: 2025-10-14
# 
# Aligns network configuration for primary server at
# 192.168.1.50 with proper Docker and LXC networking
# =====================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PRIMARY_SERVER="192.168.1.50"
DOCKER_HOST_IP="192.168.1.100"
DOCKER_NETWORK="172.20.0.0/16"

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check current network configuration
check_network_config() {
    log "Checking current network configuration..."
    
    echo "Current Proxmox host IP:"
    ip addr show | grep "inet " | grep -v "127.0.0.1" | head -5
    
    echo ""
    echo "Current routing table:"
    ip route | head -5
    
    echo ""
    echo "DNS configuration:"
    cat /etc/resolv.conf
}

# Verify Docker network doesn't conflict
verify_docker_network() {
    log "Verifying Docker network configuration..."
    
    # Check if 172.20.0.0/16 conflicts with existing routes
    if ip route | grep -q "172.20."; then
        warning "172.20.0.0/16 network already exists in routing table"
        ip route | grep "172.20."
    else
        success "Docker network 172.20.0.0/16 is available"
    fi
    
    # Check if primary server is reachable
    if ping -c 1 "$PRIMARY_SERVER" >/dev/null 2>&1; then
        success "Primary server $PRIMARY_SERVER is reachable"
    else
        error "Primary server $PRIMARY_SERVER is not reachable"
        echo "Please verify network configuration"
    fi
}

# Update Proxmox network configuration if needed
configure_proxmox_network() {
    log "Configuring Proxmox network settings..."
    
    # Check if we're already on the target IP
    current_ip=$(ip addr show | grep "inet.*192.168.1" | grep -v "127.0.0.1" | awk '{print $2}' | cut -d'/' -f1 | head -1)
    
    if [[ "$current_ip" == "$PRIMARY_SERVER" ]]; then
        success "Already configured with primary server IP: $PRIMARY_SERVER"
    else
        warning "Current IP ($current_ip) differs from target ($PRIMARY_SERVER)"
        echo "Manual network configuration may be required"
        echo ""
        echo "Expected network configuration for Proxmox:"
        echo "  Interface: vmbr0"
        echo "  IP: $PRIMARY_SERVER/24"
        echo "  Gateway: 192.168.1.1"
        echo "  DNS: 192.168.1.1, 8.8.8.8"
    fi
}

# Configure LXC network settings
configure_lxc_network() {
    log "Configuring LXC network settings..."
    
    # Verify bridge configuration
    if ip link show vmbr0 >/dev/null 2>&1; then
        success "Bridge vmbr0 exists"
        
        # Show bridge details
        echo "Bridge vmbr0 configuration:"
        ip addr show vmbr0
    else
        error "Bridge vmbr0 not found"
        echo "Create vmbr0 bridge in Proxmox web interface:"
        echo "  Datacenter → Node → System → Network → Create → Linux Bridge"
        echo "  Bridge: vmbr0"
        echo "  IPv4/CIDR: $PRIMARY_SERVER/24"
        echo "  Gateway: 192.168.1.1"
    fi
}

# Test network connectivity between services
test_network_connectivity() {
    log "Testing network connectivity..."
    
    declare -A TEST_IPS=(
        ["Gateway"]="192.168.1.1"
        ["Primary Server"]="$PRIMARY_SERVER"
        ["Docker Host"]="$DOCKER_HOST_IP"
        ["NPM"]="192.168.1.201"
        ["Pi-hole"]="192.168.1.205"
        ["Google DNS"]="8.8.8.8"
    )
    
    echo "Network connectivity test results:"
    for name in "${!TEST_IPS[@]}"; do
        ip="${TEST_IPS[$name]}"
        if ping -c 1 -W 2 "$ip" >/dev/null 2>&1; then
            echo -e "  ✅ $name ($ip): Reachable"
        else
            echo -e "  ❌ $name ($ip): Not reachable"
        fi
    done
}

# Generate network validation report
generate_network_report() {
    log "Generating network validation report..."
    
    report_file="/tmp/network_validation_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "HOMELAB NETWORK VALIDATION REPORT"
        echo "Generated: $(date)"
        echo "=========================================="
        echo ""
        
        echo "PRIMARY CONFIGURATION:"
        echo "  Proxmox Host: $PRIMARY_SERVER"
        echo "  Docker Host: $DOCKER_HOST_IP"
        echo "  Docker Network: $DOCKER_NETWORK"
        echo ""
        
        echo "LXC IP ASSIGNMENTS:"
        echo "  201 - Nginx Proxy Manager: 192.168.1.201"
        echo "  202 - Tailscale VPN: 192.168.1.202"
        echo "  203 - Ntfy Notifications: 192.168.1.203"
        echo "  204 - Samba File Share: 192.168.1.204"
        echo "  205 - Pi-hole DNS: 192.168.1.205"
        echo "  206 - Vaultwarden: 192.168.1.206"
        echo ""
        
        echo "DOCKER SERVICE IPs (Internal):"
        echo "  Gluetun VPN: 172.20.0.2"
        echo "  NZBGet: 172.20.0.4"
        echo "  Sonarr: 172.20.0.5"
        echo "  Radarr: 172.20.0.6"
        echo "  Bazarr: 172.20.0.7"
        echo "  Prowlarr: 172.20.0.8"
        echo "  Jellyfin: 172.20.0.10"
        echo ""
        
        echo "NETWORK INTERFACES:"
        ip addr show
        echo ""
        
        echo "ROUTING TABLE:"
        ip route
        echo ""
        
        echo "DNS CONFIGURATION:"
        cat /etc/resolv.conf
        echo ""
        
        echo "=========================================="
    } > "$report_file"
    
    success "Network report generated: $report_file"
    echo "Report contents:"
    cat "$report_file"
}

# Create network troubleshooting guide
create_troubleshooting_guide() {
    log "Creating network troubleshooting guide..."
    
    cat > /tmp/network_troubleshooting.md << 'EOF'
# 🌐 Homelab Network Troubleshooting Guide

## Common Network Issues and Solutions

### 1. Proxmox Host Network Configuration

**Issue**: Proxmox host not accessible at 192.168.1.50

**Solution**:
```bash
# Edit network configuration
nano /etc/network/interfaces

# Add/modify bridge configuration:
auto vmbr0
iface vmbr0 inet static
    address 192.168.1.50/24
    gateway 192.168.1.1
    bridge-ports enp0s3  # Replace with your interface
    bridge-stp off
    bridge-fd 0

# Apply configuration
systemctl restart networking
```

### 2. LXC Container Network Issues

**Issue**: LXC containers not getting expected IP addresses

**Solution**:
```bash
# Check container network configuration
pct config <VMID>

# Update container network
pct set <VMID> -net0 name=eth0,bridge=vmbr0,ip=192.168.1.20X/24,gw=192.168.1.1

# Restart container
pct restart <VMID>
```

### 3. Docker Network Conflicts

**Issue**: Docker network 172.20.0.0/16 conflicts with existing networks

**Solution**:
```bash
# Check existing networks
docker network ls
ip route

# Remove conflicting docker network
docker network rm homelab

# Recreate with different subnet in docker-compose.yml:
networks:
  homelab:
    driver: bridge
    ipam:
      config:
        - subnet: 172.19.0.0/16  # Change if needed
```

### 4. DNS Resolution Issues

**Issue**: Services cannot resolve hostnames

**Solution**:
```bash
# Configure Pi-hole as primary DNS
echo "nameserver 192.168.1.205" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# Test DNS resolution
nslookup google.com 192.168.1.205
```

### 5. Port Conflicts

**Issue**: Services cannot bind to expected ports

**Solution**:
```bash
# Check port usage
netstat -tulpn | grep :<PORT>
ss -tulpn | grep :<PORT>

# Kill conflicting processes if safe
kill <PID>

# Use alternative ports in docker-compose.yml if needed
```

## Network Validation Commands

```bash
# Test connectivity to all services
ping 192.168.1.201  # Nginx Proxy Manager
ping 192.168.1.202  # Tailscale
ping 192.168.1.203  # Ntfy
ping 192.168.1.204  # Samba
ping 192.168.1.205  # Pi-hole
ping 192.168.1.206  # Vaultwarden

# Test Docker services
curl -I http://192.168.1.100:8096  # Jellyfin
curl -I http://192.168.1.100:8989  # Sonarr
curl -I http://192.168.1.100:7878  # Radarr

# Check Docker internal network
docker exec <container> ping 172.20.0.1
```

## Emergency Network Reset

```bash
# Reset Proxmox network (CAUTION: May lose SSH access)
systemctl stop networking
ip addr flush dev vmbr0
systemctl start networking

# Reset Docker networks
docker system prune -af --volumes
docker-compose down
docker-compose up -d
```
EOF

    success "Network troubleshooting guide created: /tmp/network_troubleshooting.md"
}

# Main execution
main() {
    echo "=========================================="
    echo "🌐 HOMELAB NETWORK CONFIGURATION"
    echo "=========================================="
    echo ""
    echo "Primary Server: $PRIMARY_SERVER"
    echo "Docker Host: $DOCKER_HOST_IP"
    echo "Docker Network: $DOCKER_NETWORK"
    echo ""
    
    check_network_config
    echo ""
    verify_docker_network
    echo ""
    configure_proxmox_network
    echo ""
    configure_lxc_network
    echo ""
    test_network_connectivity
    echo ""
    generate_network_report
    echo ""
    create_troubleshooting_guide
    
    success "Network configuration validation completed!"
}

# Execute main function
main "$@"