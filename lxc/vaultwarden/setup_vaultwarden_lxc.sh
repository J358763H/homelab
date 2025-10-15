#!/bin/bash

# 🔐 Vaultwarden LXC Container Setup Script
# Part of the Homelab project
# Creates and configures Vaultwarden for secure password management

set -euo pipefail

# 🎨 Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 📋 Configuration
CONTAINER_ID="206"
CONTAINER_NAME="vaultwarden"
CONTAINER_IP="192.168.1.206"
GATEWAY_IP="192.168.1.1"
ADMIN_TOKEN=""  # Will be generated automatically
DOMAIN_NAME="homelab-vault.local"  # Change to your domain
TIMEZONE="America/Phoenix"  # Change to your timezone
STORAGE_POOL="local-lvm"
MEMORY="2048"
SWAP="1024"
DISK_SIZE="20"

# Database configuration
DB_TYPE="sqlite"  # sqlite or postgresql
DB_PATH="/opt/vaultwarden/data/db.sqlite3"

# Security settings
SIGNUPS_ALLOWED="false"  # Disable after initial setup
INVITATIONS_ALLOWED="true"
WEB_VAULT_ENABLED="true"
WEBSOCKET_ENABLED="true"

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

# 🔒 Function to generate secure admin token
generate_admin_token() {
    ADMIN_TOKEN=$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-64)
    print_success "Generated secure admin token"
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
    print_status "Creating Vaultwarden LXC container..."
    
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
        --description "Vaultwarden Password Manager - Secure self-hosted Bitwarden alternative"
    
    print_success "Vaultwarden container created with ID: $CONTAINER_ID"
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

# 📦 Function to install system dependencies
install_dependencies() {
    print_status "Installing system dependencies..."
    
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
        openssl \
        sqlite3 \
        build-essential \
        pkg-config \
        libssl-dev \
        libc6-dev \
        libpq-dev \
        libmariadb-dev \
        cron \
        logrotate \
        nginx \
        certbot \
        python3-certbot-nginx"
    
    print_success "System dependencies installed"
}

# 🦀 Function to install Rust (required for Vaultwarden)
install_rust() {
    print_status "Installing Rust toolchain..."
    
    pct exec $CONTAINER_ID -- bash -c "
        # Install Rust as vaultwarden user
        useradd -m -s /bin/bash vaultwarden
        
        # Install Rust for vaultwarden user
        sudo -u vaultwarden bash -c '
            curl --proto \"=https\" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source ~/.cargo/env
            rustup update stable
        '
    "
    
    print_success "Rust toolchain installed"
}

# 🔐 Function to compile and install Vaultwarden
install_vaultwarden() {
    print_status "Compiling and installing Vaultwarden..."
    
    pct exec $CONTAINER_ID -- bash -c "
        # Create application directories
        mkdir -p /opt/vaultwarden/{bin,data,web-vault}
        chown -R vaultwarden:vaultwarden /opt/vaultwarden
        
        # Compile Vaultwarden as vaultwarden user
        sudo -u vaultwarden bash -c '
            cd /home/vaultwarden
            source ~/.cargo/env
            
            # Clone and build Vaultwarden
            git clone https://github.com/dani-garcia/vaultwarden.git
            cd vaultwarden
            
            # Build with SQLite support (add postgresql/mysql features if needed)
            cargo build --features sqlite,web-vault --release
            
            # Copy binary to installation directory
            cp target/release/vaultwarden /opt/vaultwarden/bin/
        '
        
        # Set proper permissions
        chown vaultwarden:vaultwarden /opt/vaultwarden/bin/vaultwarden
        chmod +x /opt/vaultwarden/bin/vaultwarden
    "
    
    print_success "Vaultwarden compiled and installed"
}

# 🌐 Function to download and setup web vault
setup_web_vault() {
    print_status "Setting up Vaultwarden web vault..."
    
    pct exec $CONTAINER_ID -- bash -c "
        # Download latest web vault
        cd /tmp
        VAULT_VERSION=\$(curl -s https://api.github.com/repos/dani-garcia/bw_web_builds/releases/latest | grep 'tag_name' | cut -d'\"' -f4)
        wget https://github.com/dani-garcia/bw_web_builds/releases/download/\$VAULT_VERSION/bw_web_\$VAULT_VERSION.tar.gz
        
        # Extract web vault
        tar -xzf bw_web_\$VAULT_VERSION.tar.gz -C /opt/vaultwarden/web-vault --strip-components=1
        
        # Set permissions
        chown -R vaultwarden:vaultwarden /opt/vaultwarden/web-vault
        
        # Cleanup
        rm bw_web_\$VAULT_VERSION.tar.gz
    "
    
    print_success "Web vault installed"
}

# ⚙️ Function to configure Vaultwarden
configure_vaultwarden() {
    print_status "Configuring Vaultwarden..."
    
    # Generate admin token if not set
    if [ -z "$ADMIN_TOKEN" ]; then
        generate_admin_token
    fi
    
    # Create configuration file
    pct exec $CONTAINER_ID -- bash -c "cat > /opt/vaultwarden/.env << 'EOF'
# Vaultwarden Configuration
# Generated: $(date)

## Basic settings
DATA_FOLDER=/opt/vaultwarden/data
WEB_VAULT_FOLDER=/opt/vaultwarden/web-vault
WEB_VAULT_ENABLED=$WEB_VAULT_ENABLED

## Server settings
ROCKET_ADDRESS=0.0.0.0
ROCKET_PORT=8080
WEBSOCKET_ENABLED=$WEBSOCKET_ENABLED
WEBSOCKET_ADDRESS=0.0.0.0
WEBSOCKET_PORT=3012

## Database
DATABASE_URL=$DB_PATH

## Security settings
ADMIN_TOKEN=$ADMIN_TOKEN
SIGNUPS_ALLOWED=$SIGNUPS_ALLOWED
INVITATIONS_ALLOWED=$INVITATIONS_ALLOWED
EMERGENCY_ACCESS_ALLOWED=true
SENDS_ALLOWED=true
PASSWORD_ITERATIONS=100000

## Domain configuration
DOMAIN=https://$DOMAIN_NAME

## Email configuration (configure SMTP settings here)
# SMTP_HOST=smtp.gmail.com
# SMTP_FROM=vaultwarden@$DOMAIN_NAME
# SMTP_PORT=587
# SMTP_SECURITY=starttls
# SMTP_USERNAME=your-email@gmail.com
# SMTP_PASSWORD=your-app-password

## Logging
LOG_LEVEL=info
LOG_FILE=/opt/vaultwarden/data/vaultwarden.log
EXTENDED_LOGGING=true

## Other settings
ROCKET_WORKERS=10
SHOW_PASSWORD_HINT=false
ORG_CREATION_USERS=all
ORG_ATTACHMENT_LIMIT=100000
USER_ATTACHMENT_LIMIT=100000
EOF"
    
    # Set proper permissions
    pct exec $CONTAINER_ID -- bash -c "
        chown vaultwarden:vaultwarden /opt/vaultwarden/.env
        chmod 600 /opt/vaultwarden/.env
        
        # Create data directory
        mkdir -p /opt/vaultwarden/data
        chown -R vaultwarden:vaultwarden /opt/vaultwarden/data
        chmod 700 /opt/vaultwarden/data
    "
    
    print_success "Vaultwarden configured"
}

# 🔧 Function to create systemd service
create_systemd_service() {
    print_status "Creating systemd service..."
    
    pct exec $CONTAINER_ID -- bash -c "cat > /etc/systemd/system/vaultwarden.service << 'EOF'
[Unit]
Description=Vaultwarden Server (Bitwarden compatible server written in Rust)
Documentation=https://github.com/dani-garcia/vaultwarden
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=vaultwarden
Group=vaultwarden
ExecStart=/opt/vaultwarden/bin/vaultwarden
EnvironmentFile=/opt/vaultwarden/.env
WorkingDirectory=/opt/vaultwarden
LimitNOFILE=65535
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=/opt/vaultwarden/data
AmbientCapabilities=CAP_NET_BIND_SERVICE
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF"
    
    # Enable and start the service
    pct exec $CONTAINER_ID -- bash -c "
        systemctl daemon-reload
        systemctl enable vaultwarden
        systemctl start vaultwarden
    "
    
    print_success "Systemd service created and started"
}

# 🌐 Function to configure Nginx reverse proxy
configure_nginx() {
    print_status "Configuring Nginx reverse proxy..."
    
    pct exec $CONTAINER_ID -- bash -c "cat > /etc/nginx/sites-available/vaultwarden << 'EOF'
server {
    listen 80;
    server_name $DOMAIN_NAME $CONTAINER_IP;
    
    # Redirect HTTP to HTTPS (uncomment when SSL is configured)
    # return 301 https://\$server_name\$request_uri;
    
    # Allow HTTP for initial setup (remove after SSL setup)
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Server \$host;
        proxy_redirect off;
        
        # WebSocket support for notifications
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"upgrade\";
    }
    
    # WebSocket endpoint
    location /notifications/hub {
        proxy_pass http://127.0.0.1:3012;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"upgrade\";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection \"1; mode=block\";
    add_header Strict-Transport-Security \"max-age=63072000; includeSubDomains; preload\";
}

# HTTPS configuration (uncomment and configure after obtaining SSL certificate)
# server {
#     listen 443 ssl http2;
#     server_name $DOMAIN_NAME;
#     
#     ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
#     
#     # SSL configuration
#     ssl_protocols TLSv1.2 TLSv1.3;
#     ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
#     ssl_prefer_server_ciphers off;
#     
#     location / {
#         proxy_pass http://127.0.0.1:8080;
#         proxy_set_header Host \$host;
#         proxy_set_header X-Real-IP \$remote_addr;
#         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto \$scheme;
#         proxy_set_header X-Forwarded-Host \$host;
#         proxy_set_header X-Forwarded-Server \$host;
#         proxy_redirect off;
#         
#         # WebSocket support
#         proxy_http_version 1.1;
#         proxy_set_header Upgrade \$http_upgrade;
#         proxy_set_header Connection \"upgrade\";
#     }
#     
#     location /notifications/hub {
#         proxy_pass http://127.0.0.1:3012;
#         proxy_set_header Upgrade \$http_upgrade;
#         proxy_set_header Connection \"upgrade\";
#         proxy_set_header Host \$host;
#         proxy_set_header X-Real-IP \$remote_addr;
#         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto \$scheme;
#     }
# }
EOF"
    
    # Enable the site
    pct exec $CONTAINER_ID -- bash -c "
        ln -sf /etc/nginx/sites-available/vaultwarden /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
        nginx -t
        systemctl restart nginx
        systemctl enable nginx
    "
    
    print_success "Nginx configured and started"
}

# 🔒 Function to setup firewall
configure_firewall() {
    print_status "Configuring container firewall..."
    
    pct exec $CONTAINER_ID -- bash -c "
        # Install and configure ufw
        apt install -y ufw
        
        # Default policies
        ufw default deny incoming
        ufw default allow outgoing
        
        # Allow SSH (if needed)
        ufw allow ssh
        
        # Allow HTTP and HTTPS
        ufw allow 80/tcp
        ufw allow 443/tcp
        
        # Allow from homelab network
        ufw allow from 192.168.1.0/24
        
        # Enable firewall
        echo 'y' | ufw enable
    "
    
    print_success "Firewall configured"
}

# 📊 Function to setup logging and monitoring
setup_logging() {
    print_status "Setting up logging and log rotation..."
    
    pct exec $CONTAINER_ID -- bash -c "
        # Create log rotation configuration
        cat > /etc/logrotate.d/vaultwarden << 'EOF'
/opt/vaultwarden/data/vaultwarden.log {
    daily
    missingok
    rotate 30
    compress
    notifempty
    create 644 vaultwarden vaultwarden
    postrotate
        systemctl reload vaultwarden
    endscript
}
EOF
        
        # Create monitoring script
        cat > /usr/local/bin/vaultwarden-health-check.sh << 'EOF'
#!/bin/bash
# Vaultwarden health check script

LOG_FILE=\"/var/log/vaultwarden-health.log\"
TIMESTAMP=\$(date '+%Y-%m-%d %H:%M:%S')

# Check Vaultwarden service
if ! systemctl is-active --quiet vaultwarden; then
    echo \"\$TIMESTAMP ERROR: Vaultwarden service is not running\" >> \$LOG_FILE
    systemctl restart vaultwarden
fi

# Check web interface
if ! curl -s http://localhost:80/alive > /dev/null; then
    echo \"\$TIMESTAMP ERROR: Vaultwarden web interface not responding\" >> \$LOG_FILE
fi

# Check Nginx
if ! systemctl is-active --quiet nginx; then
    echo \"\$TIMESTAMP ERROR: Nginx service is not running\" >> \$LOG_FILE
    systemctl restart nginx
fi

# Log successful check
echo \"\$TIMESTAMP INFO: Vaultwarden health check passed\" >> \$LOG_FILE
EOF
        
        chmod +x /usr/local/bin/vaultwarden-health-check.sh
        
        # Add to crontab
        echo '*/5 * * * * /usr/local/bin/vaultwarden-health-check.sh' | crontab -
    "
    
    print_success "Logging and monitoring configured"
}

# 💾 Function to setup backup script
create_backup_script() {
    print_status "Creating backup script..."
    
    pct exec $CONTAINER_ID -- bash -c "
        cat > /usr/local/bin/vaultwarden-backup.sh << 'EOF'
#!/bin/bash
# Vaultwarden backup script

BACKUP_DIR=\"/opt/vaultwarden/backups\"
TIMESTAMP=\$(date '+%Y%m%d_%H%M%S')
BACKUP_NAME=\"vaultwarden_backup_\$TIMESTAMP\"

# Create backup directory
mkdir -p \$BACKUP_DIR

# Stop Vaultwarden service temporarily
systemctl stop vaultwarden

# Create backup
tar -czf \"\$BACKUP_DIR/\$BACKUP_NAME.tar.gz\" -C /opt/vaultwarden data .env

# Restart Vaultwarden service
systemctl start vaultwarden

# Keep only last 7 backups
find \$BACKUP_DIR -name \"vaultwarden_backup_*.tar.gz\" -type f -mtime +7 -delete

echo \"Backup completed: \$BACKUP_NAME.tar.gz\"
EOF
        
        chmod +x /usr/local/bin/vaultwarden-backup.sh
        
        # Schedule daily backups at 2 AM
        echo '0 2 * * * /usr/local/bin/vaultwarden-backup.sh' | crontab -
    "
    
    print_success "Backup script created and scheduled"
}

# 📊 Function to display final information
display_info() {
    print_header "🎉 Vaultwarden LXC Container Setup Complete!"
    
    echo -e "${GREEN}Container Details:${NC}"
    echo -e "  📦 Container ID: ${WHITE}$CONTAINER_ID${NC}"
    echo -e "  🏷️  Name: ${WHITE}$CONTAINER_NAME${NC}"
    echo -e "  🌐 IP Address: ${WHITE}$CONTAINER_IP${NC}"
    echo -e "  💾 Memory: ${WHITE}${MEMORY}MB${NC}"
    echo -e "  💿 Storage: ${WHITE}${DISK_SIZE}GB${NC}"
    
    echo -e "\n${BLUE}Access Information:${NC}"
    echo -e "  🌐 Web Interface: ${WHITE}http://$CONTAINER_IP${NC}"
    echo -e "  🏠 Local Domain: ${WHITE}http://$DOMAIN_NAME${NC}"
    echo -e "  🔑 Admin Panel: ${WHITE}http://$CONTAINER_IP/admin${NC}"
    echo -e "  🗝️  Admin Token: ${WHITE}$ADMIN_TOKEN${NC}"
    
    echo -e "\n${YELLOW}Security Configuration:${NC}"
    echo -e "  🔒 Signups: ${WHITE}$SIGNUPS_ALLOWED${NC} (Enable temporarily for user creation)"
    echo -e "  📧 Invitations: ${WHITE}$INVITATIONS_ALLOWED${NC}"
    echo -e "  🌐 Web Vault: ${WHITE}$WEB_VAULT_ENABLED${NC}"
    echo -e "  🔔 WebSocket: ${WHITE}$WEBSOCKET_ENABLED${NC}"
    
    echo -e "\n${PURPLE}Important Next Steps:${NC}"
    echo -e "  1. 🔧 Access admin panel: ${WHITE}http://$CONTAINER_IP/admin${NC}"
    echo -e "  2. 🔑 Use admin token: ${WHITE}$ADMIN_TOKEN${NC}"
    echo -e "  3. 📧 Configure SMTP settings for email notifications"
    echo -e "  4. 🔒 Temporarily enable signups to create your first user"
    echo -e "  5. 👤 Create your admin account via web interface"
    echo -e "  6. 🛡️  Disable signups after account creation"
    echo -e "  7. 🌐 Configure SSL certificate for HTTPS"
    echo -e "  8. 🔗 Add to Nginx Proxy Manager for external access"
    
    echo -e "\n${GREEN}Integration with Homelab:${NC}"
    echo -e "  🔗 Nginx Proxy Manager: ${WHITE}192.168.1.201${NC} (for SSL termination)"
    echo -e "  🔒 Tailscale VPN: ${WHITE}192.168.1.202${NC} (for secure remote access)"
    echo -e "  📢 Ntfy Notifications: ${WHITE}192.168.1.203${NC} (for alerts)"
    echo -e "  🕳️  Pi-hole DNS: ${WHITE}192.168.1.205${NC} (for local domain resolution)"
    
    echo -e "\n${CYAN}Backup & Maintenance:${NC}"
    echo -e "  💾 Daily backups: ${WHITE}Automated at 2 AM${NC}"
    echo -e "  📊 Health checks: ${WHITE}Every 5 minutes${NC}"
    echo -e "  📝 Logs: ${WHITE}/opt/vaultwarden/data/vaultwarden.log${NC}"
    echo -e "  🔄 Manual backup: ${WHITE}/usr/local/bin/vaultwarden-backup.sh${NC}"
    
    print_success "🔐 Vaultwarden is ready for secure password management!"
}

# 🚀 Main execution function
main() {
    print_header "🔐 Vaultwarden LXC Container Setup"
    
    print_status "Starting Vaultwarden LXC container creation..."
    
    # Pre-flight checks
    check_proxmox
    
    # Setup process
    cleanup_existing
    download_template
    create_container
    wait_for_container
    install_dependencies
    install_rust
    install_vaultwarden
    setup_web_vault
    configure_vaultwarden
    create_systemd_service
    configure_nginx
    configure_firewall
    setup_logging
    create_backup_script
    
    # Final information
    display_info
    
    print_success "🎊 Vaultwarden LXC setup completed successfully!"
}

# Execute main function
main "$@"