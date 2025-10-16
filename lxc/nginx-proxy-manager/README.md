# 🌐 Nginx Proxy Manager LXC Container Setup
## Overview
This LXC container provides a dedicated Nginx Proxy Manager instance for reverse proxy and SSL certificate management across your entire homelab infrastructure.

## Container Specifications
- **OS**: Ubuntu 22.04 LTS
- **RAM**: 1GB
- **Storage**: 4GB
- **CPU**: 1 core
- **Network**: Bridge mode with static IP
- **Privileges**: Unprivileged container

## Features
- Web-based proxy host management
- Automatic Let's Encrypt SSL certificates
- Access control and authentication
- Real-time log monitoring
- Database backup and restore
- Custom SSL certificate support

## Prerequisites
- Proxmox VE host
- Ubuntu 22.04 LTS template
- Available static IP address
- Domain name (optional, for SSL)

## Quick Setup

### **Option 1: From Homelab Setup (Recommended)**
```bash
# Deploy with main homelab
cd setup
./deploy-all.sh

# Or deploy LXC services only
./deploy-lxc.sh
```

### **Option 2: Individual Deployment**
```bash
# Run the automated setup script
cd lxc/nginx-proxy-manager
chmod +x setup_npm_lxc.sh
./setup_npm_lxc.sh

```
## Manual Setup Steps
### 1. Create LXC Container
```bash
# Create container (adjust CTID and IP)
pct create 201 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname npm-homelab \
  --memory 1024 \
  --swap 512 \
  --cores 1 \
  --rootfs local-lvm:4 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.201/24,gw=192.168.1.1 \
  --features nesting=1 \
  --unprivileged 1 \
  --start 1

```
### 2. Container Configuration
```bash
# Enter container
pct enter 201

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

# Add user to docker group
usermod -aG docker root

```
### 3. Deploy NPM
```bash
# Create directories
mkdir -p /opt/nginx-proxy-manager/{data,letsencrypt}

# Create docker-compose.yml
cat > /opt/nginx-proxy-manager/docker-compose.yml << 'EOF'
version: '3.8'

services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Phoenix
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    ports:
      - "80:80"     # HTTP
      - "443:443"   # HTTPS
      - "81:81"     # Admin Web UI
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:81/api/nginx/health"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

# Deploy NPM
cd /opt/nginx-proxy-manager
docker compose up -d

```
### 4. Configure Systemd Service
```bash
# Create systemd service for auto-start
cat > /etc/systemd/system/nginx-proxy-manager.service << 'EOF'
[Unit]
Description=Nginx Proxy Manager
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/nginx-proxy-manager
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Enable service
systemctl enable nginx-proxy-manager.service
systemctl start nginx-proxy-manager.service

```
## Access Information
- **Web UI**: `http://192.168.1.201:81`
- **Default Login**:
  - Email: `admin@example.com`
  - Password: `changeme`
  - **⚠️ Change immediately after first login!**

## Proxy Configuration Examples
### Docker Services (from Docker host)

```
# Jellyfin
Domain: jellyfin.yourdomain.com
Forward to: 192.168.1.100:8096  # Docker host IP

# Jellyseerr
Domain: requests.yourdomain.com
Forward to: 192.168.1.100:5055

```
### LXC Services

```
# Ntfy
Domain: notifications.yourdomain.com
Forward to: 192.168.1.203:80  # Ntfy LXC IP

# Samba Web UI (if enabled)
Domain: files.yourdomain.com
Forward to: 192.168.1.202:445

```
## SSL Certificate Setup
### Option 1: Let's Encrypt (Automatic)

1. Ensure ports 80/443 are forwarded to this container
2. Configure DNS A records pointing to your external IP
3. Use NPM interface to request certificates

### Option 2: Cloudflare DNS Challenge

1. Get Cloudflare API token
2. Configure DNS challenge in NPM
3. No port forwarding required

## Security Considerations
- **Firewall**: Only expose ports 80/443 externally
- **Updates**: Regularly update container and NPM image
- **Backups**: Backup `/opt/nginx-proxy-manager/data` directory
- **Access Control**: Use NPM's access lists feature
- **Headers**: Configure security headers for all proxy hosts

## Maintenance
### Backup Configuration

```bash
# Create backup
tar -czf npm-backup-$(date +%Y%m%d).tar.gz /opt/nginx-proxy-manager/data

# Restore backup
tar -xzf npm-backup-YYYYMMDD.tar.gz -C /

```
### Update NPM

```bash
cd /opt/nginx-proxy-manager
docker compose pull
docker compose up -d

```
### View Logs

```bash
cd /opt/nginx-proxy-manager
docker compose logs -f

```
## Integration with Homelab
This NPM instance can proxy to:

- **Docker services** on main host (192.168.1.100:ports)
- **Other LXC containers** (individual IPs)
- **External services** (other servers, NAS, etc.)
- **Tailscale services** (via Tailscale IPs)

Perfect for creating a unified access point with SSL for your entire homelab!
