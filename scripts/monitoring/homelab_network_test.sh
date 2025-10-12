# 🌐 Port Testing & Network Diagnostics Guide

## 📋 Overview

This guide provides comprehensive methods to test if your homelab ports are properly exposed and accessible from the internet, including both internal and external testing approaches.

---

## 🔍 **Quick Port Testing Methods**

### **🌐 External Port Checkers (Easiest)**

#### **Online Port Testing Services:**
```bash
# Test specific ports from external perspective
https://www.yougetsignal.com/tools/open-ports/
https://canyouseeme.org/
https://portchecker.co/
https://www.portchecktool.com/

# Usage:
1. Enter your public IP address (whatismyipaddress.com)
2. Enter the port number you want to test
3. Click "Check Port" 
4. Should show "Open" if properly forwarded
```

#### **Command Line External Testing:**
```bash
# From an external machine/VPS (not your home network)
nmap -p [port] [your-public-ip]
telnet [your-public-ip] [port]
nc -zv [your-public-ip] [port]

# Example:
nmap -p 8096 203.0.113.1  # Test Jellyfin port
telnet 203.0.113.1 443    # Test HTTPS port
```

---

## 🏠 **Internal Network Testing**

### **🔧 Test Container Ports Locally**

#### **Test Individual Container Services:**
```bash
# Test from Proxmox host or any local machine
curl -I http://192.168.1.201:81      # Nginx Proxy Manager
curl -I http://192.168.1.203         # Ntfy notifications
curl -I http://192.168.1.205/admin   # Pi-hole admin panel
curl -I http://192.168.1.206         # Vaultwarden

# Expected response: HTTP/1.1 200 OK (or similar)
```

#### **Port Scanning Internal Network:**
```bash
# Scan all your homelab container ports
nmap -p 80,81,443,53,8080,8096 192.168.1.201-206

# Detailed scan with service detection
nmap -sV -p- 192.168.1.201  # Scan all ports on NPM

# Quick connectivity test
nc -zv 192.168.1.205 53     # Test Pi-hole DNS
nc -zv 192.168.1.201 81     # Test NPM admin
```

---

## 🛠️ **Comprehensive Port Testing Script**

Let me create an automated testing script for your homelab:

<function_calls>
<invoke name="create_file">
<parameter name="content">#!/bin/bash

#!/bin/bash

# 🔍 Homelab Port Testing Script
# Tests all homelab services for connectivity and accessibility

set -euo pipefail

# 🎨 Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 📋 Configuration
PUBLIC_IP=""  # Will be auto-detected
TIMEOUT=5

# 🌐 Homelab Services Configuration
declare -A SERVICES=(
    ["nginx-proxy-manager"]="192.168.1.201:81"
    ["tailscale-vpn"]="192.168.1.202:22"
    ["ntfy-notifications"]="192.168.1.203:80"
    ["media-file-share"]="192.168.1.204:445"
    ["pihole-dns"]="192.168.1.205:53"
    ["pihole-web"]="192.168.1.205:80"
    ["vaultwarden"]="192.168.1.206:80"
)

# 🔍 External ports to test (through router/firewall)
declare -A EXTERNAL_PORTS=(
    ["HTTP"]="80"
    ["HTTPS"]="443"
    ["Jellyfin"]="8096"
    ["NPM-Admin"]="81"
    ["SSH"]="22"
)

print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# 🌐 Get public IP address
get_public_ip() {
    print_status "Detecting public IP address..."
    
    # Try multiple services
    PUBLIC_IP=$(curl -s https://ifconfig.me || curl -s https://ipinfo.io/ip || curl -s https://icanhazip.com)
    
    if [ -n "$PUBLIC_IP" ]; then
        print_success "Public IP detected: $PUBLIC_IP"
    else
        print_error "Could not detect public IP address"
        PUBLIC_IP="UNKNOWN"
    fi
}

# 🏠 Test internal services
test_internal_services() {
    print_header "🏠 Internal Service Connectivity Test"
    
    local success_count=0
    local total_count=${#SERVICES[@]}
    
    for service in "${!SERVICES[@]}"; do
        local address="${SERVICES[$service]}"
        local ip="${address%:*}"
        local port="${address#*:}"
        
        print_status "Testing $service ($address)..."
        
        if nc -z -w$TIMEOUT "$ip" "$port" 2>/dev/null; then
            print_success "$service is accessible"
            ((success_count++))
        else
            print_error "$service is not accessible"
        fi
    done
    
    echo
    print_status "Internal Services: $success_count/$total_count accessible"
    echo
}

# 🌐 Test external accessibility
test_external_ports() {
    print_header "🌐 External Port Accessibility Test"
    
    if [ "$PUBLIC_IP" = "UNKNOWN" ]; then
        print_error "Cannot test external ports without public IP"
        return
    fi
    
    print_status "Testing external accessibility from public IP: $PUBLIC_IP"
    print_warning "Note: This requires port forwarding to be configured on your router"
    echo
    
    for service in "${!EXTERNAL_PORTS[@]}"; do
        local port="${EXTERNAL_PORTS[$service]}"
        
        print_status "Testing $service (port $port)..."
        
        # Use timeout to prevent hanging
        if timeout $TIMEOUT nc -z "$PUBLIC_IP" "$port" 2>/dev/null; then
            print_success "$service (port $port) is externally accessible"
        else
            print_warning "$service (port $port) is not externally accessible (may need port forwarding)"
        fi
    done
    echo
}

# 🔍 Test specific web services
test_web_services() {
    print_header "🌐 Web Service HTTP Response Test"
    
    declare -A WEB_SERVICES=(
        ["Nginx Proxy Manager"]="http://192.168.1.201:81"
        ["Ntfy Notifications"]="http://192.168.1.203"
        ["Pi-hole Admin"]="http://192.168.1.205/admin"
        ["Vaultwarden"]="http://192.168.1.206"
    )
    
    for service in "${!WEB_SERVICES[@]}"; do
        local url="${WEB_SERVICES[$service]}"
        
        print_status "Testing HTTP response for $service..."
        
        if curl -s -I --connect-timeout $TIMEOUT "$url" | head -n1 | grep -q "200\|301\|302"; then
            print_success "$service HTTP response OK"
        else
            print_error "$service HTTP response failed"
        fi
    done
    echo
}

# 🕳️ Test DNS functionality
test_dns_services() {
    print_header "🕳️ DNS Service Test"
    
    print_status "Testing Pi-hole DNS resolution..."
    
    # Test DNS resolution through Pi-hole
    if dig @192.168.1.205 google.com +short | grep -q "^[0-9]"; then
        print_success "Pi-hole DNS resolution working"
    else
        print_error "Pi-hole DNS resolution failed"
    fi
    
    # Test local domain resolution
    if dig @192.168.1.205 pihole.local +short | grep -q "192.168.1.205"; then
        print_success "Pi-hole local domain resolution working"
    else
        print_warning "Pi-hole local domain resolution not configured"
    fi
    
    echo
}

# 📊 Generate summary report
generate_summary() {
    print_header "📊 Network Connectivity Summary"
    
    echo -e "${BLUE}Public IP Address:${NC} $PUBLIC_IP"
    echo -e "${BLUE}Test Date:${NC} $(date)"
    echo
    
    echo -e "${YELLOW}Internal Services Status:${NC}"
    echo "  ✓ Check output above for detailed results"
    echo
    
    echo -e "${YELLOW}External Access Requirements:${NC}"
    echo "  • Router port forwarding must be configured"
    echo "  • Firewall rules must allow inbound traffic"
    echo "  • ISP must not block ports (some block 80, 443, 25, etc.)"
    echo
    
    echo -e "${YELLOW}Common External Ports to Forward:${NC}"
    echo "  • 80/443 → 192.168.1.201 (Nginx Proxy Manager)"
    echo "  • 8096 → 192.168.1.100 (Jellyfin, if using Docker host)"
    echo "  • Custom ports as needed for specific services"
    echo
    
    echo -e "${YELLOW}Useful External Testing URLs:${NC}"
    echo "  • https://www.yougetsignal.com/tools/open-ports/"
    echo "  • https://canyouseeme.org/"
    echo "  • https://portchecker.co/"
}

# 🚀 Main execution
main() {
    print_header "🔍 Homelab Network Connectivity Test"
    echo
    
    get_public_ip
    echo
    
    test_internal_services
    test_web_services
    test_dns_services
    test_external_ports
    generate_summary
    
    print_success "Network connectivity test completed!"
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    for cmd in nc curl dig; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_status "Install with: apt update && apt install netcat-openbsd curl dnsutils"
        exit 1
    fi
}

# Run the test
check_dependencies
main "$@"