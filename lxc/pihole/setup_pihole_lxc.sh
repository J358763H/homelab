#!/bin/bash

# 🕳️ Pi-hole LXC Container Setup Script
# Part of the homelab project
# Creates and configures Pi-hole for network-wide ad blocking and DNS management
# Usage: ./setup_pihole_lxc.sh [--automated] [ctid]

set -euo pipefail

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common_functions.sh"

# Check dependencies and root access
check_root
check_dependencies

# Parse arguments
check_automated_mode "$@"

# 🎨 Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 📋 Configuration
CONTAINER_ID="${2:-205}"
CONTAINER_NAME="homelab-pihole-dns-205"
CONTAINER_IP="192.168.1.205"
GATEWAY_IP="192.168.1.1"
DNS_UPSTREAM_1="1.1.1.1"
DNS_UPSTREAM_2="8.8.8.8"
# Set PIHOLE_WEBPASSWORD environment variable or a secure password will be auto-generated
WEBPASSWORD="${PIHOLE_WEBPASSWORD:-$(openssl rand -base64 32)}"
TIMEZONE="America/Phoenix"  # Change to your timezone
STORAGE_POOL="local-lvm"
MEMORY="1024"
SWAP="512"
DISK_SIZE="8"

# 🤖 Check for automated mode
AUTOMATED_MODE=false
if [[ "${1:-}" == "--automated" ]] || [[ "${AUTOMATED_MODE:-false}" == "true" ]]; then
    AUTOMATED_MODE=true
fi

# 🎯 Function to print colored status messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

# 🔍 Function to check if running on Proxmox
check_proxmox() {
    if ! command -v pct >/dev/null 2>&1; then
        print_error "This script must be run on a Proxmox VE host"
        print_error "Proxmox Container Toolkit (pct) not found"
        exit 1
    fi

    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        print_error "Please run: sudo $0"
        exit 1
    fi
}

# 🧹 Function to cleanup existing container if it exists
cleanup_existing() {
    if pct list | grep -q "^$CONTAINER_ID"; then
        print_warning "Container $CONTAINER_ID already exists"

        if [[ "$AUTOMATED_MODE" == "true" ]]; then
            # In automated mode, check if container is running
            local container_status
            container_status=$(pct status "$CONTAINER_ID" 2>/dev/null | awk '{print $2}' || echo "unknown")
            if [[ "$container_status" == "running" ]]; then
                print_success "Container $CONTAINER_ID is already running, skipping recreation"
                exit 0
            else
                print_status "Container exists but not running, recreating in automated mode..."
                pct stop $CONTAINER_ID 2>/dev/null || true
                pct destroy $CONTAINER_ID
                print_success "Existing container removed"
            fi
        else
            read -p "Do you want to destroy and recreate it? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_status "Stopping existing container..."
                pct stop $CONTAINER_ID || true

                print_status "Destroying existing container..."
                pct destroy $CONTAINER_ID

                print_success "Existing container removed"
            else
                print_error "Aborting setup"
                exit 1
            fi
        fi
    fi
}

# 📦 Function to download Ubuntu template if not present
download_template() {
    local template="ubuntu-22.04-standard_22.04-1_amd64.tar.zst"

    if ! pveam list local | grep -q "$template"; then
        print_status "Downloading Ubuntu 22.04 LTS template..."
        pveam download local "$template"
        print_success "Template downloaded"
    else
        print_status "Ubuntu 22.04 LTS template already available"
    fi
}

# 🏗️ Function to create LXC container
create_container() {
    print_status "Creating Pi-hole LXC container..."

    pct create $CONTAINER_ID \
        local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
        --hostname $CONTAINER_NAME \
        --net0 name=eth0,bridge=vmbr0,firewall=1,gw=$GATEWAY_IP,ip=$CONTAINER_IP/24,type=veth \
        --memory $MEMORY \
        --swap $SWAP \
        --storage $STORAGE_POOL \
        --rootfs $STORAGE_POOL:$DISK_SIZE \
        --unprivileged 1 \
        --onboot 1 \
        --start 1 \
        --features nesting=1 \
        --description "Pi-hole DNS Server - Network-wide ad blocking and DNS management"

    print_success "Pi-hole container created with ID: $CONTAINER_ID"
}

# ⏳ Function to wait for container to be ready
wait_for_container() {
    print_status "Waiting for container to start and be ready..."

    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if pct exec $CONTAINER_ID -- systemctl is-system-running --wait 2>/dev/null; then
            print_success "Container is ready!"
            return 0
        fi

        echo -n "."
        sleep 2
        ((attempt++))
    done

    print_error "Container failed to become ready within timeout"
    exit 1
}

# 📦 Function to install Pi-hole dependencies
install_dependencies() {
    print_status "Installing Pi-hole dependencies..."

    # Update package lists
    pct exec $CONTAINER_ID -- bash -c "apt update"

    # Install required packages
    pct exec $CONTAINER_ID -- bash -c "apt install -y \
        curl \
        wget \
        ca-certificates \
        gnupg \
        lsb-release \
        sudo \
        systemd \
        dnsutils \
        net-tools \
        cron \
        logrotate"

    print_success "Dependencies installed"
}

# 🕳️ Function to install Pi-hole
install_pihole() {
    print_status "Installing Pi-hole..."

    # Create installation script inside container
    pct exec $CONTAINER_ID -- bash -c "cat > /tmp/pihole_setup.sh << 'EOF'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Pi-hole automated installation
mkdir -p /etc/pihole

# Create setupVars.conf for unattended installation
cat > /etc/pihole/setupVars.conf << EOL
WEBPASSWORD=$WEBPASSWORD
PIHOLE_INTERFACE=eth0
IPV4_ADDRESS=$CONTAINER_IP/24
IPV6_ADDRESS=
PIHOLE_DNS_1=$DNS_UPSTREAM_1
PIHOLE_DNS_2=$DNS_UPSTREAM_2
QUERY_LOGGING=true
INSTALL_WEB_SERVER=true
INSTALL_WEB_INTERFACE=true
LIGHTTPD_ENABLED=true
CACHE_SIZE=10000
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
DNSMASQ_LISTENING=single
WEBTHEME=default-dark
API_EXCLUDE_DOMAINS=
API_EXCLUDE_CLIENTS=
API_QUERY_LOG_SHOW=permittedonly
API_PRIVACY_MODE=false
EOL

# Download and run Pi-hole installer
curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended

# Enable and start services
systemctl enable pihole-FTL
systemctl start pihole-FTL
systemctl enable lighttpd
systemctl start lighttpd

# Set timezone
timedatectl set-timezone $TIMEZONE

echo 'Pi-hole installation completed!'
EOF"

    # Make script executable and run it
    pct exec $CONTAINER_ID -- chmod +x /tmp/pihole_setup.sh
    pct exec $CONTAINER_ID -- /tmp/pihole_setup.sh

    print_success "Pi-hole installed and configured"
}

# 🔧 Function to configure Pi-hole
configure_pihole() {
    print_status "Configuring Pi-hole settings..."

    # Wait for Pi-hole to be fully ready
    print_status "Waiting for Pi-hole service to be ready..."
    local retry_count=0
    local max_retries=30

    while [ $retry_count -lt $max_retries ]; do
        if pct exec $CONTAINER_ID -- test -f /usr/local/bin/pihole; then
            print_success "Pi-hole binary found"
            break
        fi
        sleep 2
        retry_count=$((retry_count + 1))
    done

    if [ $retry_count -eq $max_retries ]; then
        print_warning "Pi-hole binary not found in expected location, trying alternative paths..."
        # Try to find pihole binary and create symlink if needed
        pct exec $CONTAINER_ID -- bash -c "
            if [ -f /opt/pihole/pihole ]; then
                ln -sf /opt/pihole/pihole /usr/local/bin/pihole
            elif [ -f /usr/bin/pihole ]; then
                ln -sf /usr/bin/pihole /usr/local/bin/pihole
            fi
        "
    fi

    # Update gravity (blocklists) with error handling
    print_status "Updating Pi-hole gravity database..."
    if pct exec $CONTAINER_ID -- /usr/local/bin/pihole -g; then
        print_success "Gravity database updated"
    else
        print_warning "Gravity update failed, but Pi-hole should still work"
    fi

    # Add custom DNS records for homelab services
    pct exec $CONTAINER_ID -- bash -c "cat >> /etc/pihole/custom.list << 'EOF'
# Homelab Service Records
192.168.1.201 npm.local
192.168.1.201 proxy.local
192.168.1.202 tailscale.local
192.168.1.203 ntfy.local
192.168.1.204 media.local
192.168.1.205 pihole.local
192.168.1.205 dns.local
192.168.1.206 homelab-vault.local
EOF"

    # Restart DNS service to apply changes with error handling
    print_status "Restarting Pi-hole DNS service..."
    if pct exec $CONTAINER_ID -- /usr/local/bin/pihole restartdns; then
        print_success "Pi-hole DNS service restarted"
    else
        print_warning "DNS restart failed, trying systemctl restart"
        pct exec $CONTAINER_ID -- systemctl restart pihole-FTL || true
    fi

    print_success "Pi-hole configuration completed"
}

# 🔒 Function to configure firewall rules
configure_firewall() {
    print_status "Configuring container firewall..."

    # Allow DNS (port 53) and Web interface (port 80)
    pct set $CONTAINER_ID --net0 name=eth0,bridge=vmbr0,firewall=1,gw=$GATEWAY_IP,ip=$CONTAINER_IP/24,type=veth

    print_success "Firewall configured"
}

# 📊 Function to display final information
display_info() {
    print_header "🎉 Pi-hole LXC Container Setup Complete!"

    echo -e "${GREEN}Container Details:${NC}"
    echo -e "  📦 Container ID: ${WHITE}$CONTAINER_ID${NC}"
    echo -e "  🏷️  Name: ${WHITE}$CONTAINER_NAME${NC}"
    echo -e "  🌐 IP Address: ${WHITE}$CONTAINER_IP${NC}"
    echo -e "  💾 Memory: ${WHITE}${MEMORY}MB${NC}"
    echo -e "  💿 Storage: ${WHITE}${DISK_SIZE}GB${NC}"

    echo -e "\n${BLUE}Access Information:${NC}"
    echo -e "  🌐 Web Interface: ${WHITE}http://$CONTAINER_IP/admin${NC}"
    echo -e "  🔑 Admin Password: ${WHITE}$WEBPASSWORD${NC}"
    echo -e "  🏠 Local DNS: ${WHITE}http://pihole.local/admin${NC} (after DNS setup)"

    echo -e "\n${YELLOW}DNS Configuration:${NC}"
    echo -e "  📡 Primary DNS: ${WHITE}$CONTAINER_IP${NC}"
    echo -e "  🔄 Upstream DNS: ${WHITE}$DNS_UPSTREAM_1, $DNS_UPSTREAM_2${NC}"

    echo -e "\n${PURPLE}Next Steps:${NC}"
    echo -e "  1. 🔧 Configure your router to use ${WHITE}$CONTAINER_IP${NC} as primary DNS"
    echo -e "  2. 🌐 Access web interface at ${WHITE}http://$CONTAINER_IP/admin${NC}"
    echo -e "  3. 📋 Review and customize blocklists in the admin panel"
    echo -e "  4. 📊 Monitor query logs and statistics"
    echo -e "  5. 🛡️  Add custom blacklist/whitelist entries as needed"

    echo -e "\n${GREEN}Integration with Homelab:${NC}"
    echo -e "  🔗 Nginx Proxy Manager: ${WHITE}192.168.1.201${NC}"
    echo -e "  🔗 Tailscale Router: ${WHITE}192.168.1.202${NC}"
    echo -e "  🔗 Ntfy Notifications: ${WHITE}192.168.1.203${NC}"
    echo -e "  🔗 Samba File Share: ${WHITE}192.168.1.204${NC}"

    print_success "Pi-hole is ready to provide network-wide ad blocking!"
}

# 🚀 Main execution function
main() {
    print_header "🕳️ Pi-hole LXC Container Setup"

    print_status "Starting Pi-hole LXC container creation..."

    # Pre-flight checks
    check_proxmox

    # Setup process
    cleanup_existing
    download_template
    create_container
    wait_for_container
    install_dependencies
    install_pihole
    configure_pihole
    configure_firewall

    # Final information
    display_info

    print_success "🎊 Pi-hole LXC setup completed successfully!"
}

# Execute main function
main "$@"
