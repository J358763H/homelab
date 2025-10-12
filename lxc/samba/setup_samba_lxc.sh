#!/bin/bash

# =====================================================
# 📁 Media Share LXC Container Setup Script
# =====================================================
# Maintainer: J35867U
# Email: mrnash404@protonmail.com
# Last Updated: 2025-10-11
# 
# Sets up a dedicated media file server for network sharing
# Integrates with Docker media stack on Proxmox
# Based on: https://youtu.be/qmSizZUbCOA?si=qWmb60b_BrFNtoLr
# =====================================================

set -euo pipefail

# =================
# Configuration
# =================
CONTAINER_ID=${1:-102}
CONTAINER_NAME="media-share"
TEMPLATE="ubuntu-22.04-standard_22.04-1_amd64.tar.xz"
STORAGE="local-lvm"
MEMORY=1024
SWAP=512
DISK_SIZE=8
CORES=2
BRIDGE="vmbr0"
IP_ADDRESS="192.168.1.102/24"  # Adjust to your network
GATEWAY="192.168.1.1"          # Adjust to your gateway
NAMESERVER="1.1.1.1"

# Mount points for media storage
MEDIA_STORAGE_MOUNT="/mnt/media"  # Where your media storage is mounted on Proxmox host
DOCKER_DATA_MOUNT="/mnt/docker"   # Where your Docker data is stored

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =================
# Helper Functions
# =================
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# =================
# Validation
# =================
if ! command -v pct >/dev/null 2>&1; then
    error "This script must be run on a Proxmox host with 'pct' command available"
fi

if pct list | grep -q "^$CONTAINER_ID"; then
    error "Container ID $CONTAINER_ID already exists. Please choose a different ID or remove the existing container."
fi

log "Setting up Media Share LXC Container..."
echo -e "${BLUE}Container ID: $CONTAINER_ID${NC}"
echo -e "${BLUE}IP Address: ${IP_ADDRESS%/*}${NC}"
echo ""

# =================
# Create LXC Container
# =================
log "Creating privileged LXC container for Media Share..."

pct create $CONTAINER_ID /var/lib/vz/template/cache/$TEMPLATE \
    --hostname $CONTAINER_NAME \
    --memory $MEMORY \
    --swap $SWAP \
    --cores $CORES \
    --net0 name=eth0,bridge=$BRIDGE,ip=$IP_ADDRESS,gw=$GATEWAY \
    --storage $STORAGE \
    --rootfs $STORAGE:$DISK_SIZE \
    --unprivileged 0 \
    --features nesting=1 \
    --onboot 1 \
    --start 0

log "Container created successfully with ID: $CONTAINER_ID"

# =================
# Configure Mount Points
# =================
log "Configuring mount points for media access..."

# Add mount points to container config
cat >> /etc/pve/lxc/$CONTAINER_ID.conf << EOF

# Media storage mount points
mp0: $MEDIA_STORAGE_MOUNT,mp=/media
mp1: $DOCKER_DATA_MOUNT,mp=/docker-data
EOF

log "Mount points configured"

# =================
# Start Container
# =================
log "Starting container..."
pct start $CONTAINER_ID

# Wait for container to be ready
log "Waiting for container to initialize..."
sleep 15

# =================
# Install Samba and Dependencies
# =================
log "Installing Media Share services and dependencies..."

pct exec $CONTAINER_ID -- bash -c "
    # Update system
    apt update && apt upgrade -y
    
    # Install Samba and utilities
    apt install -y samba samba-common-bin smbclient cifs-utils
    apt install -y netatalk avahi-daemon
    apt install -y htop nano curl wget net-tools
    
    # Enable services
    systemctl enable smbd nmbd
    systemctl enable avahi-daemon
"

# =================
# Create Users and Groups
# =================
log "Setting up users and permissions..."

pct exec $CONTAINER_ID -- bash -c "
    # Create media group
    groupadd -g 1500 mediagroup
    
    # Create media user
    useradd -u 1500 -g mediagroup -s /bin/bash -d /home/mediauser mediauser
    mkdir -p /home/mediauser
    chown mediauser:mediagroup /home/mediauser
    
    # Set password for media user (you'll be prompted)
    echo 'Setting password for mediauser...'
    passwd mediauser
    
    # Add mediauser to samba
    smbpasswd -a mediauser
    
    # Create admin user for management
    useradd -u 1501 -G sudo -s /bin/bash -d /home/admin admin
    mkdir -p /home/admin
    chown admin:admin /home/admin
    passwd admin
    smbpasswd -a admin
"

# =================
# Configure Directory Structure
# =================
log "Creating media directory structure..."

pct exec $CONTAINER_ID -- bash -c "
    # Create media directories
    mkdir -p /media/{movies,shows,music,youtube,downloads}
    mkdir -p /media/downloads/{movies,shows,music}
    
    # Set proper permissions
    chown -R mediauser:mediagroup /media
    chmod -R 775 /media
    
    # Create symbolic links for easier access
    ln -sf /media /home/mediauser/media
    ln -sf /docker-data /home/admin/docker-data
"

# =================
# Configure Samba
# =================
log "Configuring Media Share network shares..."

# Backup original config
pct exec $CONTAINER_ID -- cp /etc/samba/smb.conf /etc/samba/smb.conf.backup

# Create new Samba configuration
cat > /tmp/smb.conf << 'EOF'
[global]
   workgroup = WORKGROUP
   server string = Homelab Media Server
   netbios name = HOMELAB-MEDIA
   security = user
   map to guest = bad user
   dns proxy = no
   socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=524288 SO_SNDBUF=524288
   deadtime = 30
   use sendfile = yes
   write cache size = 262144
   min receivefile size = 16384
   aio read size = 16384
   aio write size = 16384
   server multi channel support = yes

   # Logging
   log file = /var/log/samba/log.%m
   max log size = 1000
   log level = 1

   # Performance tuning
   strict allocate = yes
   allocation roundup size = 1048576

   # Modern SMB versions
   server min protocol = SMB2_10
   server max protocol = SMB3_11

[media]
   comment = Media Files
   path = /media
   browseable = yes
   writable = yes
   guest ok = no
   valid users = mediauser, admin
   create mask = 0664
   directory mask = 0775
   force group = mediagroup

[movies]
   comment = Movie Collection
   path = /media/movies
   browseable = yes
   writable = yes
   guest ok = no
   valid users = mediauser, admin
   create mask = 0664
   directory mask = 0775
   force group = mediagroup

[shows]
   comment = TV Shows
   path = /media/shows
   browseable = yes
   writable = yes
   guest ok = no
   valid users = mediauser, admin
   create mask = 0664
   directory mask = 0775
   force group = mediagroup

[music]
   comment = Music Collection
   path = /media/music
   browseable = yes
   writable = yes
   guest ok = no
   valid users = mediauser, admin
   create mask = 0664
   directory mask = 0775
   force group = mediagroup

[youtube]
   comment = YouTube Downloads
   path = /media/youtube
   browseable = yes
   writable = yes
   guest ok = no
   valid users = mediauser, admin
   create mask = 0664
   directory mask = 0775
   force group = mediagroup

[downloads]
   comment = Download Staging
   path = /media/downloads
   browseable = yes
   writable = yes
   guest ok = no
   valid users = mediauser, admin
   create mask = 0664
   directory mask = 0775
   force group = mediagroup

[docker-admin]
   comment = Docker Data (Admin Only)
   path = /docker-data
   browseable = yes
   writable = yes
   guest ok = no
   valid users = admin
   create mask = 0644
   directory mask = 0755
   admin users = admin
EOF

# Copy config to container
pct push $CONTAINER_ID /tmp/smb.conf /etc/samba/smb.conf

# Set proper permissions and restart
pct exec $CONTAINER_ID -- bash -c "
    chown root:root /etc/samba/smb.conf
    chmod 644 /etc/samba/smb.conf
    
    # Test configuration
    testparm -s
    
    # Restart services
    systemctl restart smbd nmbd
    systemctl restart avahi-daemon
    
    # Enable and check status
    systemctl enable smbd nmbd avahi-daemon
    systemctl status smbd --no-pager
"

# Cleanup temp files
rm /tmp/smb.conf

# =================
# Configure Firewall (if needed)
# =================
log "Configuring firewall for Media Share..."

pct exec $CONTAINER_ID -- bash -c "
    # Install UFW if not present
    apt install -y ufw
    
    # Configure UFW for Samba
    ufw allow from 192.168.1.0/24 to any port 139
    ufw allow from 192.168.1.0/24 to any port 445
    ufw allow from 192.168.1.0/24 to any port 137
    ufw allow from 192.168.1.0/24 to any port 138
    
    # SSH access
    ufw allow from 192.168.1.0/24 to any port 22
    
    # Enable firewall
    ufw --force enable
    ufw status
"

# =================
# Create Management Scripts
# =================
log "Creating management scripts..."

pct exec $CONTAINER_ID -- bash -c "
    # Create backup script
    cat > /usr/local/bin/backup-samba-config << 'SCRIPT_EOF'
#!/bin/bash
DATE=\$(date +%Y%m%d_%H%M%S)
cp /etc/samba/smb.conf /root/smb.conf.backup.\$DATE
echo \"Samba config backed up to /root/smb.conf.backup.\$DATE\"
SCRIPT_EOF

    # Create user management script
    cat > /usr/local/bin/manage-samba-users << 'SCRIPT_EOF'
#!/bin/bash
case \$1 in
    add)
        if [ -z \"\$2\" ]; then
            echo \"Usage: manage-samba-users add <username>\"
            exit 1
        fi
        useradd -G mediagroup \$2
        passwd \$2
        smbpasswd -a \$2
        ;;
    remove)
        if [ -z \"\$2\" ]; then
            echo \"Usage: manage-samba-users remove <username>\"
            exit 1
        fi
        smbpasswd -x \$2
        userdel \$2
        ;;
    list)
        pdbedit -L
        ;;
    *)
        echo \"Usage: manage-samba-users {add|remove|list} [username]\"
        exit 1
        ;;
esac
SCRIPT_EOF

    # Make scripts executable
    chmod +x /usr/local/bin/backup-samba-config
    chmod +x /usr/local/bin/manage-samba-users
"

# =================
# Final Status and Instructions
# =================
IP_ONLY=$(echo $IP_ADDRESS | cut -d'/' -f1)

log "Media Share LXC container setup complete!"
echo ""
echo -e "${GREEN}=== Container Information ===${NC}"
echo -e "Container ID: ${BLUE}$CONTAINER_ID${NC}"
echo -e "Container Name: ${BLUE}$CONTAINER_NAME${NC}" 
echo -e "IP Address: ${BLUE}$IP_ONLY${NC}"
echo -e "Users: ${BLUE}mediauser, admin${NC}"
echo ""
echo -e "${GREEN}=== Available Shares ===${NC}"
echo -e "Media (All): ${YELLOW}\\\\$IP_ONLY\\media${NC}"
echo -e "Movies: ${YELLOW}\\\\$IP_ONLY\\movies${NC}"
echo -e "TV Shows: ${YELLOW}\\\\$IP_ONLY\\shows${NC}"
echo -e "Music: ${YELLOW}\\\\$IP_ONLY\\music${NC}"
echo -e "YouTube: ${YELLOW}\\\\$IP_ONLY\\youtube${NC}"
echo -e "Downloads: ${YELLOW}\\\\$IP_ONLY\\downloads${NC}"
echo -e "Docker Admin: ${YELLOW}\\\\$IP_ONLY\\docker-admin${NC} (admin only)"
echo ""
echo -e "${GREEN}=== Management Commands ===${NC}"
echo -e "Backup config: ${YELLOW}pct exec $CONTAINER_ID -- backup-samba-config${NC}"
echo -e "Manage users: ${YELLOW}pct exec $CONTAINER_ID -- manage-samba-users list${NC}"
echo -e "Add user: ${YELLOW}pct exec $CONTAINER_ID -- manage-samba-users add username${NC}"
echo -e "Container shell: ${YELLOW}pct enter $CONTAINER_ID${NC}"
echo ""
echo -e "${GREEN}=== Integration Notes ===${NC}"
echo -e "• Mount points link to your Proxmox host storage"
echo -e "• Compatible with Docker media stack file permissions"
echo -e "• Optimized for large file transfers and streaming"
echo -e "• Ready for Windows, macOS, and Linux client connections"
echo ""
echo -e "${BLUE}Test connection: \\\\$IP_ONLY\\media${NC}"