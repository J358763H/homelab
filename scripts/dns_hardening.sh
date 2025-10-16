#!/bin/bash

# =====================================================
# 🌐 Pi-hole DNS Hardening and Configuration Script
# =====================================================
# Fixes DNS misconfigurations identified in bug scan
# Implements secure DNS forwarding and blocking
# =====================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PIHOLE_CTID="205"
PIHOLE_IP="192.168.1.205"
HOMELAB_SUBNET="192.168.1.0/24"

# Secure DNS servers
SECURE_DNS_SERVERS=(
    "1.1.1.1"        # Cloudflare
    "1.0.0.1"        # Cloudflare
    "9.9.9.9"        # Quad9
    "149.112.112.112" # Quad9
)

# Functions
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARNING] $1${NC}"; }

# Check if Pi-hole container exists and is running
check_pihole_container() {
    log "Checking Pi-hole container status..."
    
    if ! pct status "$PIHOLE_CTID" >/dev/null 2>&1; then
        error "Pi-hole container $PIHOLE_CTID does not exist"
        return 1
    fi
    
    local status=$(pct status "$PIHOLE_CTID" | awk '{print $2}')
    if [[ "$status" != "running" ]]; then
        log "Starting Pi-hole container..."
        pct start "$PIHOLE_CTID"
        sleep 10
    fi
    
    success "Pi-hole container is running"
}

# Configure secure DNS upstream servers
configure_dns_upstream() {
    log "Configuring secure DNS upstream servers..."
    
    # Build DNS server list for Pi-hole
    local dns_servers=""
    for server in "${SECURE_DNS_SERVERS[@]}"; do
        dns_servers="$dns_servers$server;"
    done
    dns_servers=${dns_servers%;}  # Remove trailing semicolon
    
    # Update Pi-hole DNS configuration
    pct exec "$PIHOLE_CTID" -- bash -c "
        # Backup existing configuration
        cp /etc/pihole/setupVars.conf /etc/pihole/setupVars.conf.backup
        
        # Update DNS servers in setupVars.conf
        sed -i 's/^PIHOLE_DNS_.*$/PIHOLE_DNS_1=${SECURE_DNS_SERVERS[0]}/' /etc/pihole/setupVars.conf
        echo 'PIHOLE_DNS_2=${SECURE_DNS_SERVERS[1]}' >> /etc/pihole/setupVars.conf
        echo 'PIHOLE_DNS_3=${SECURE_DNS_SERVERS[2]}' >> /etc/pihole/setupVars.conf
        echo 'PIHOLE_DNS_4=${SECURE_DNS_SERVERS[3]}' >> /etc/pihole/setupVars.conf
        
        # Configure additional security settings
        echo 'DNS_FQDN_REQUIRED=true' >> /etc/pihole/setupVars.conf
        echo 'DNS_BOGUS_PRIV=true' >> /etc/pihole/setupVars.conf
        echo 'DNSSEC=true' >> /etc/pihole/setupVars.conf
        echo 'REV_SERVER=true' >> /etc/pihole/setupVars.conf
        echo 'REV_SERVER_DOMAIN=homelab.local' >> /etc/pihole/setupVars.conf
        echo 'REV_SERVER_TARGET=192.168.1.1' >> /etc/pihole/setupVars.conf
        echo 'REV_SERVER_CIDR=$HOMELAB_SUBNET' >> /etc/pihole/setupVars.conf
    "
    
    success "DNS upstream servers configured"
}

# Configure Pi-hole custom DNS records
configure_custom_dns() {
    log "Configuring custom DNS records..."
    
    pct exec "$PIHOLE_CTID" -- bash -c "
        # Create custom DNS entries for homelab services
        cat > /etc/pihole/custom.list << 'EOF'
# Homelab service DNS records
192.168.1.100 jellyfin.homelab.local
192.168.1.100 sonarr.homelab.local
192.168.1.100 radarr.homelab.local
192.168.1.100 prowlarr.homelab.local
192.168.1.100 bazarr.homelab.local
192.168.1.100 qbittorrent.homelab.local
192.168.1.201 npm.homelab.local
192.168.1.201 proxy.homelab.local
192.168.1.202 tailscale.homelab.local
192.168.1.203 ntfy.homelab.local
192.168.1.204 pihole.homelab.local
192.168.1.205 dns.homelab.local
192.168.1.206 vaultwarden.homelab.local
192.168.1.206 samba.homelab.local
EOF
    "
    
    success "Custom DNS records configured"
}

# Configure advanced blocking lists
configure_blocking_lists() {
    log "Configuring advanced blocking lists..."
    
    pct exec "$PIHOLE_CTID" -- bash -c "
        # Add comprehensive blocklists
        cat > /etc/pihole/adlists.list << 'EOF'
# Default Pi-hole lists
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://mirror1.malwaredomains.com/files/justdomains
https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt
https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt

# Security-focused lists
https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt
https://osint.digitalside.it/Threat-Intel/lists/latestdomains.txt
https://malware-filter.gitlab.io/malware-filter/phishing-filter-hosts.txt
https://raw.githubusercontent.com/AssoEchap/stalkerware-indicators/master/generated/hosts
https://urlhaus.abuse.ch/downloads/hostfile/

# Privacy-focused lists
https://someonewhocares.org/hosts/zero/hosts
https://raw.githubusercontent.com/jdlingyu/ad-wars/master/hosts
https://raw.githubusercontent.com/VeleSila/yhosts/master/hosts

# Homelab security additions
https://raw.githubusercontent.com/hectorm/hmirror/master/data/eth-phishing-detect/list.txt
https://raw.githubusercontent.com/hectorm/hmirror/master/data/pups-filter/list.txt
EOF
    "
    
    success "Advanced blocking lists configured"
}

# Configure DNS security settings
configure_dns_security() {
    log "Configuring DNS security settings..."
    
    pct exec "$PIHOLE_CTID" -- bash -c "
        # Configure dnsmasq for security
        cat >> /etc/dnsmasq.d/99-homelab-security.conf << 'EOF'
# Security hardening for DNS
no-resolv
strict-order
stop-dns-rebind
rebind-localhost-ok
rebind-domain-ok=homelab.local
domain-needed
bogus-priv
expand-hosts
domain=homelab.local

# Rate limiting
dns-forward-max=1000
cache-size=2048
neg-ttl=60

# Block private IP ranges from external resolution
rebind-check

# Log queries for security monitoring
log-queries

# Bind only to specific interfaces
interface=eth0
bind-interfaces

# Security: Don't read /etc/hosts
no-hosts
EOF

        # Set proper permissions
        chmod 644 /etc/dnsmasq.d/99-homelab-security.conf
    "
    
    success "DNS security settings configured"
}

# Configure DNS logging and monitoring
configure_dns_logging() {
    log "Configuring DNS logging and monitoring..."
    
    pct exec "$PIHOLE_CTID" -- bash -c "
        # Configure logrotate for Pi-hole logs
        cat > /etc/logrotate.d/pihole << 'EOF'
/var/log/pihole.log {
    daily
    copytruncate
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 pihole pihole
}

/var/log/pihole-FTL.log {
    daily
    copytruncate
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 pihole pihole
}
EOF

        # Create DNS monitoring script
        cat > /usr/local/bin/dns-monitor.sh << 'EOF'
#!/bin/bash
# DNS monitoring script for Pi-hole

LOG_FILE=\"/var/log/dns-monitor.log\"
ALERT_THRESHOLD=100
MALWARE_THRESHOLD=10

# Get current stats
QUERIES_TODAY=\$(pihole -c | grep \"Queries today\" | awk '{print \$3}' | tr -d ',')
BLOCKED_TODAY=\$(pihole -c | grep \"Blocked today\" | awk '{print \$3}' | tr -d ',')

# Check for high query volume (potential DNS amplification)
if [ \"\$QUERIES_TODAY\" -gt \"\$ALERT_THRESHOLD\" ]; then
    echo \"\$(date): HIGH QUERY VOLUME: \$QUERIES_TODAY queries today\" >> \"\$LOG_FILE\"
fi

# Check for high malware blocks
if [ \"\$BLOCKED_TODAY\" -gt \"\$MALWARE_THRESHOLD\" ]; then
    echo \"\$(date): HIGH MALWARE ACTIVITY: \$BLOCKED_TODAY blocks today\" >> \"\$LOG_FILE\"
fi

# Check DNS service health
if ! dig @127.0.0.1 google.com >/dev/null 2>&1; then
    echo \"\$(date): DNS SERVICE DOWN\" >> \"\$LOG_FILE\"
    systemctl restart pihole-FTL
fi
EOF

        chmod +x /usr/local/bin/dns-monitor.sh
        
        # Add to crontab
        (crontab -l 2>/dev/null; echo '*/5 * * * * /usr/local/bin/dns-monitor.sh') | crontab -
    "
    
    success "DNS logging and monitoring configured"
}

# Configure firewall rules for DNS
configure_dns_firewall() {
    log "Configuring firewall rules for DNS..."
    
    # Allow DNS traffic from homelab subnet only
    iptables -A INPUT -s "$HOMELAB_SUBNET" -d "$PIHOLE_IP" -p tcp --dport 53 -j ACCEPT
    iptables -A INPUT -s "$HOMELAB_SUBNET" -d "$PIHOLE_IP" -p udp --dport 53 -j ACCEPT
    
    # Block external DNS queries
    iptables -A INPUT ! -s "$HOMELAB_SUBNET" -d "$PIHOLE_IP" -p tcp --dport 53 -j DROP
    iptables -A INPUT ! -s "$HOMELAB_SUBNET" -d "$PIHOLE_IP" -p udp --dport 53 -j DROP
    
    # Allow Pi-hole web interface from homelab subnet only
    iptables -A INPUT -s "$HOMELAB_SUBNET" -d "$PIHOLE_IP" -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT ! -s "$HOMELAB_SUBNET" -d "$PIHOLE_IP" -p tcp --dport 80 -j DROP
    
    # Log blocked external DNS attempts
    iptables -A INPUT ! -s "$HOMELAB_SUBNET" -d "$PIHOLE_IP" -p tcp --dport 53 -j LOG --log-prefix "DNS_EXTERNAL_BLOCK: "
    iptables -A INPUT ! -s "$HOMELAB_SUBNET" -d "$PIHOLE_IP" -p udp --dport 53 -j LOG --log-prefix "DNS_EXTERNAL_BLOCK: "
    
    success "DNS firewall rules configured"
}

# Restart Pi-hole services
restart_pihole_services() {
    log "Restarting Pi-hole services..."
    
    pct exec "$PIHOLE_CTID" -- bash -c "
        systemctl restart pihole-FTL
        sleep 5
        systemctl restart dnsmasq
    "
    
    # Wait for services to start
    sleep 10
    
    success "Pi-hole services restarted"
}

# Test DNS functionality
test_dns_functionality() {
    log "Testing DNS functionality..."
    
    # Test DNS resolution from Pi-hole
    if pct exec "$PIHOLE_CTID" -- dig @127.0.0.1 google.com >/dev/null 2>&1; then
        success "Local DNS resolution: OK"
    else
        error "Local DNS resolution: FAILED"
        return 1
    fi
    
    # Test DNS resolution from homelab network
    if dig @"$PIHOLE_IP" google.com >/dev/null 2>&1; then
        success "Remote DNS resolution: OK"
    else
        warn "Remote DNS resolution: FAILED"
    fi
    
    # Test custom DNS records
    if dig @"$PIHOLE_IP" jellyfin.homelab.local >/dev/null 2>&1; then
        success "Custom DNS records: OK"
    else
        warn "Custom DNS records: FAILED"
    fi
    
    # Test blocking functionality
    if dig @"$PIHOLE_IP" doubleclick.net | grep -q "0.0.0.0"; then
        success "DNS blocking: OK"
    else
        warn "DNS blocking: May not be working properly"
    fi
}

# Display DNS status and statistics
show_dns_status() {
    log "DNS Status and Statistics:"
    echo
    
    pct exec "$PIHOLE_CTID" -- bash -c "
        echo '=== Pi-hole Status ==='
        pihole status
        echo
        
        echo '=== Query Statistics ==='
        pihole -c
        echo
        
        echo '=== Top Blocked Domains ==='
        pihole -t 5
        echo
        
        echo '=== Upstream DNS Servers ==='
        cat /etc/pihole/setupVars.conf | grep PIHOLE_DNS
        echo
        
        echo '=== DNS Service Status ==='
        systemctl status pihole-FTL --no-pager -l
    "
}

# Main execution
main() {
    log "Starting Pi-hole DNS Hardening"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root on Proxmox host"
        exit 1
    fi
    
    check_pihole_container
    configure_dns_upstream
    configure_custom_dns
    configure_blocking_lists
    configure_dns_security
    configure_dns_logging
    configure_dns_firewall
    restart_pihole_services
    test_dns_functionality
    show_dns_status
    
    success "Pi-hole DNS hardening completed!"
    success "Key improvements:"
    success "✓ Secure upstream DNS servers configured"
    success "✓ DNSSEC validation enabled"
    success "✓ Advanced malware/phishing blocking lists added"
    success "✓ DNS rebind protection enabled"
    success "✓ Query logging and monitoring configured"
    success "✓ Firewall rules restrict DNS access to homelab subnet"
    success "✓ Custom homelab DNS records configured"
    
    warn "Update your router/DHCP to use Pi-hole DNS: $PIHOLE_IP"
    warn "Pi-hole admin interface: http://$PIHOLE_IP/admin"
}

# Handle command line arguments
case "${1:-configure}" in
    "configure")
        main
        ;;
    "test")
        test_dns_functionality
        ;;
    "status")
        show_dns_status
        ;;
    "restart")
        check_pihole_container
        restart_pihole_services
        ;;
    *)
        echo "Usage: $0 [configure|test|status|restart]"
        echo "  configure - Apply DNS hardening (default)"
        echo "  test      - Test DNS functionality"
        echo "  status    - Show DNS status and stats"
        echo "  restart   - Restart Pi-hole services"
        exit 1
        ;;
esac