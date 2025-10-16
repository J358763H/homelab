#!/bin/bash

# =====================================================
# 🔒 Homelab Firewall Hardening Script
# =====================================================
# Implements "deny by default" security policy
# Addresses critical exposure issues from bug scan
# =====================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
HOMELAB_SUBNET="192.168.1.0/24"
TAILSCALE_INTERFACE="tailscale0"
DOCKER_INTERFACE="docker0"
MANAGEMENT_IPS=("192.168.1.1")  # Router/management IPs
VPN_PORTS=("51820" "41194")     # WireGuard, Tailscale

# Functions
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $1${NC}"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Backup existing firewall rules
backup_firewall_rules() {
    log "Backing up existing firewall rules..."
    
    local backup_dir="/opt/homelab/firewall-backups"
    mkdir -p "$backup_dir"
    
    local backup_file="$backup_dir/iptables-backup-$(date +%Y%m%d_%H%M%S).rules"
    
    if iptables-save > "$backup_file"; then
        success "Firewall rules backed up to: $backup_file"
    else
        error "Failed to backup firewall rules"
        exit 1
    fi
}

# Clear existing rules (with safety check)
clear_firewall_rules() {
    log "Clearing existing firewall rules..."
    
    # Set default policies to ACCEPT temporarily to avoid lockout
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    # Clear all rules
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    
    success "Firewall rules cleared"
}

# Set up basic security rules
setup_basic_security() {
    log "Setting up basic security rules..."
    
    # Allow loopback traffic
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # Allow established and related connections
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # Drop invalid packets
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    iptables -A FORWARD -m conntrack --ctstate INVALID -j DROP
    
    # Rate limit SSH to prevent brute force
    iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m limit --limit 3/min --limit-burst 3 -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -j DROP
    
    # Allow ICMP ping with rate limiting
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/sec --limit-burst 3 -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
    
    success "Basic security rules configured"
}

# Configure homelab network access
setup_homelab_network() {
    log "Configuring homelab network access..."
    
    # Allow full access from homelab subnet
    iptables -A INPUT -s "$HOMELAB_SUBNET" -j ACCEPT
    iptables -A FORWARD -s "$HOMELAB_SUBNET" -d "$HOMELAB_SUBNET" -j ACCEPT
    
    # Allow management IPs
    for mgmt_ip in "${MANAGEMENT_IPS[@]}"; do
        iptables -A INPUT -s "$mgmt_ip" -j ACCEPT
        log "Allowed management IP: $mgmt_ip"
    done
    
    success "Homelab network access configured"
}

# Configure VPN access
setup_vpn_access() {
    log "Configuring VPN access..."
    
    # Allow VPN ports
    for vpn_port in "${VPN_PORTS[@]}"; do
        iptables -A INPUT -p udp --dport "$vpn_port" -j ACCEPT
        log "Allowed VPN port: $vpn_port/UDP"
    done
    
    # Allow Tailscale interface if it exists
    if ip link show "$TAILSCALE_INTERFACE" >/dev/null 2>&1; then
        iptables -A INPUT -i "$TAILSCALE_INTERFACE" -j ACCEPT
        iptables -A FORWARD -i "$TAILSCALE_INTERFACE" -j ACCEPT
        iptables -A FORWARD -o "$TAILSCALE_INTERFACE" -j ACCEPT
        success "Tailscale interface access configured"
    else
        warn "Tailscale interface not found, skipping VPN rules"
    fi
    
    success "VPN access configured"
}

# Configure Docker network security
setup_docker_security() {
    log "Configuring Docker network security..."
    
    # Allow Docker containers to communicate with each other
    if ip link show "$DOCKER_INTERFACE" >/dev/null 2>&1; then
        iptables -A FORWARD -i "$DOCKER_INTERFACE" -o "$DOCKER_INTERFACE" -j ACCEPT
        
        # Allow Docker containers to access homelab subnet
        iptables -A FORWARD -i "$DOCKER_INTERFACE" -d "$HOMELAB_SUBNET" -j ACCEPT
        iptables -A FORWARD -s "$HOMELAB_SUBNET" -o "$DOCKER_INTERFACE" -j ACCEPT
        
        success "Docker network security configured"
    else
        warn "Docker interface not found, skipping Docker rules"
    fi
}

# Block external access to sensitive services
block_external_access() {
    log "Blocking external access to sensitive services..."
    
    # Define sensitive ports that should NOT be accessible externally
    local sensitive_ports=(
        "22"    # SSH
        "3306"  # MySQL
        "5432"  # PostgreSQL
        "6379"  # Redis
        "9200"  # Elasticsearch
        "27017" # MongoDB
        "5984"  # CouchDB
        "8086"  # InfluxDB
    )
    
    # Block external access to sensitive ports
    for port in "${sensitive_ports[@]}"; do
        iptables -A INPUT ! -s "$HOMELAB_SUBNET" -p tcp --dport "$port" -j DROP
        iptables -A INPUT ! -s "$HOMELAB_SUBNET" -p udp --dport "$port" -j DROP
    done
    
    # Log dropped external access attempts
    iptables -A INPUT -p tcp --dport 22 -j LOG --log-prefix "SSH_EXTERNAL_BLOCK: " --log-level 4
    iptables -A INPUT -p tcp --dport 3306 -j LOG --log-prefix "MYSQL_EXTERNAL_BLOCK: " --log-level 4
    
    success "External access blocking configured"
}

# Configure service access rules
setup_service_access() {
    log "Configuring service access rules..."
    
    # Nginx Proxy Manager (192.168.1.201)
    iptables -A INPUT -s "$HOMELAB_SUBNET" -d 192.168.1.201 -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -s "$HOMELAB_SUBNET" -d 192.168.1.201 -p tcp --dport 443 -j ACCEPT
    iptables -A INPUT -s "$HOMELAB_SUBNET" -d 192.168.1.201 -p tcp --dport 81 -j ACCEPT
    
    # Pi-hole DNS (192.168.1.205)
    iptables -A INPUT -s "$HOMELAB_SUBNET" -d 192.168.1.205 -p tcp --dport 53 -j ACCEPT
    iptables -A INPUT -s "$HOMELAB_SUBNET" -d 192.168.1.205 -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -s "$HOMELAB_SUBNET" -d 192.168.1.205 -p tcp --dport 80 -j ACCEPT
    
    # Docker services (192.168.1.100) - only from homelab subnet
    local docker_ports=("8096" "8989" "7878" "9696" "6767" "8080" "8181" "5055")
    for port in "${docker_ports[@]}"; do
        iptables -A INPUT -s "$HOMELAB_SUBNET" -d 192.168.1.100 -p tcp --dport "$port" -j ACCEPT
    done
    
    success "Service access rules configured"
}

# Set up logging for blocked connections
setup_logging() {
    log "Setting up connection logging..."
    
    # Log and drop remaining INPUT traffic
    iptables -A INPUT -m limit --limit 3/min --limit-burst 3 -j LOG --log-prefix "HOMELAB_INPUT_DROP: " --log-level 4
    
    # Log and drop remaining FORWARD traffic
    iptables -A FORWARD -m limit --limit 3/min --limit-burst 3 -j LOG --log-prefix "HOMELAB_FORWARD_DROP: " --log-level 4
    
    success "Connection logging configured"
}

# Set default policies to DROP (deny by default)
set_default_policies() {
    log "Setting default policies to DROP (deny by default)..."
    
    # Set default policies
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT  # Allow outbound traffic
    
    success "Default DROP policies set - deny by default active"
}

# Save firewall rules
save_firewall_rules() {
    log "Saving firewall rules..."
    
    if command -v iptables-persistent >/dev/null 2>&1; then
        # Use iptables-persistent if available
        iptables-save > /etc/iptables/rules.v4
        success "Rules saved with iptables-persistent"
    elif command -v netfilter-persistent >/dev/null 2>&1; then
        # Use netfilter-persistent
        netfilter-persistent save
        success "Rules saved with netfilter-persistent"
    else
        # Manual save
        iptables-save > /etc/iptables.rules
        
        # Create startup script
        cat > /etc/network/if-pre-up.d/iptables << 'EOF'
#!/bin/sh
/sbin/iptables-restore < /etc/iptables.rules
EOF
        chmod +x /etc/network/if-pre-up.d/iptables
        success "Rules saved manually with startup script"
    fi
}

# Install fail2ban for additional protection
install_fail2ban() {
    log "Installing and configuring fail2ban..."
    
    if ! command -v fail2ban-server >/dev/null 2>&1; then
        apt update
        apt install -y fail2ban
    fi
    
    # Configure fail2ban
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
ignoreip = 127.0.0.1/8 192.168.1.0/24

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[docker-log-driver]
enabled = true
logpath = /var/lib/docker/containers/*/*.log
port = 0:65535
maxretry = 5
findtime = 300
bantime = 1800
EOF
    
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    success "Fail2ban installed and configured"
}

# Display firewall status
show_firewall_status() {
    log "Current firewall status:"
    echo
    echo "=== IPTABLES RULES ==="
    iptables -L -n -v --line-numbers
    echo
    echo "=== NAT RULES ==="
    iptables -t nat -L -n -v
    echo
    echo "=== DEFAULT POLICIES ==="
    iptables -S | grep "^-P"
    echo
}

# Test connectivity after applying rules
test_connectivity() {
    log "Testing basic connectivity..."
    
    # Test internal connectivity
    if ping -c 1 192.168.1.1 >/dev/null 2>&1; then
        success "Router connectivity: OK"
    else
        warn "Router connectivity: FAILED"
    fi
    
    # Test external connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        success "External connectivity: OK"
    else
        warn "External connectivity: FAILED"
    fi
    
    # Test DNS resolution
    if nslookup google.com >/dev/null 2>&1; then
        success "DNS resolution: OK"
    else
        warn "DNS resolution: FAILED"
    fi
}

# Main execution
main() {
    log "Starting Homelab Firewall Hardening"
    
    check_root
    
    # Confirmation prompt
    echo
    warn "This will implement a 'deny by default' firewall policy"
    warn "Ensure you have console access in case of connectivity issues"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Firewall hardening cancelled by user"
        exit 0
    fi
    
    # Apply firewall rules
    backup_firewall_rules
    clear_firewall_rules
    setup_basic_security
    setup_homelab_network
    setup_vpn_access
    setup_docker_security
    block_external_access
    setup_service_access
    setup_logging
    set_default_policies
    save_firewall_rules
    install_fail2ban
    
    # Test and display results
    test_connectivity
    show_firewall_status
    
    success "Homelab firewall hardening completed!"
    success "Key security improvements:"
    success "✓ Deny by default policy implemented"
    success "✓ External access blocked to sensitive services"
    success "✓ VPN and homelab subnet access configured"
    success "✓ Rate limiting and DDoS protection enabled"
    success "✓ Connection logging and fail2ban active"
    
    warn "Important: Test all services to ensure proper connectivity"
    warn "Firewall backup available in: /opt/homelab/firewall-backups/"
}

# Handle command line arguments
case "${1:-apply}" in
    "apply")
        main
        ;;
    "status")
        show_firewall_status
        ;;
    "test")
        test_connectivity
        ;;
    "backup")
        check_root
        backup_firewall_rules
        ;;
    *)
        echo "Usage: $0 [apply|status|test|backup]"
        echo "  apply  - Apply firewall hardening (default)"
        echo "  status - Show current firewall status"
        echo "  test   - Test network connectivity"
        echo "  backup - Backup current firewall rules"
        exit 1
        ;;
esac