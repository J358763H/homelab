# 🎮 Game Server Deployment Guide

## Overview
Complete deployment guide for the Moonlight GameStream + CoinOps Emulation game server with comprehensive management tools.

## Prerequisites

### System Requirements
- **Operating System**: Ubuntu 22.04 LTS (recommended)
- **RAM**: Minimum 8GB (16GB recommended for optimal performance)
- **Storage**: Minimum 100GB (more for ROM collection)
- **CPU**: Modern multi-core processor with hardware acceleration support
- **Network**: Stable internet connection and local network access

### Hardware Acceleration
- **Intel**: Integrated graphics with VAAPI support
- **NVIDIA**: Dedicated GPU with NVENC support (optional but recommended)
- **AMD**: VAAPI-compatible graphics (experimental support)

### Network Requirements
- **Ports**: 47984-47990 (Sunshine GameStream), 8080 (Web Interface)
- **Bandwidth**: Minimum 10 Mbps upload for local streaming
- **Firewall**: UFW or iptables for security

## Pre-Deployment Checklist

### 1. System Preparation
- [ ] Ubuntu 22.04 LTS installed and updated
- [ ] SSH access configured with key authentication
- [ ] User account with sudo privileges created
- [ ] Network connectivity verified
- [ ] Hardware acceleration drivers installed

### 2. Network Configuration
- [ ] Static IP address assigned (recommended)
- [ ] Router port forwarding configured (if remote access needed)
- [ ] Firewall rules planned
- [ ] DNS resolution working

### 3. Storage Planning
- [ ] Adequate disk space for ROMs, saves, and backups
- [ ] Backup storage location identified
- [ ] Directory structure planned

## Deployment Methods

### Method 1: One-Click Deployment (Recommended)

#### Step 1: Download Deployment Script
```bash
# Download the standalone deployer
wget https://raw.githubusercontent.com/J35867U/homelab-deployment/main/game-server-deployment/scripts/standalone-deploy.sh

# Make executable
chmod +x standalone-deploy.sh
```

#### Step 2: Run Deployment
```bash
# Run as root for full system setup
sudo ./standalone-deploy.sh

# Follow the interactive prompts
# The script will install all dependencies and configure services
```

#### Step 3: Verify Installation
```bash
# Test the main command
game-server status

# Check web interface
curl http://localhost:8080

# Verify services
systemctl status game-server-web
```

### Method 2: Manual Component Installation

#### Step 1: Install Dependencies
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y \
    curl wget git bc jq unzip tar gzip \
    nodejs npm python3 python3-pip \
    systemd cron ufw \
    vainfo mesa-utils \
    lm-sensors htop net-tools \
    gpg rng-tools

# Install Node.js (if newer version needed)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

#### Step 2: Create Directory Structure
```bash
# Create main directories
sudo mkdir -p /opt/game-server-tools/{scripts,docs,config}
sudo mkdir -p /var/log/game-server
sudo mkdir -p /data/backups/game-server/{daily,weekly,monthly}
sudo mkdir -p /etc/game-server

# Set permissions
sudo chown -R $USER:$USER /opt/game-server-tools
sudo chmod -R 755 /opt/game-server-tools
```

#### Step 3: Install Management Scripts
```bash
# Clone the deployment repository
git clone <deployment-repo-url>
cd game-server-deployment

# Copy scripts
sudo cp scripts/* /opt/game-server-tools/scripts/
sudo chmod +x /opt/game-server-tools/scripts/*.sh

# Install Node.js dependencies
cd /opt/game-server-tools
sudo npm install express
```

#### Step 4: Configure Services
```bash
# Create systemd services
sudo cp deployment/systemd/* /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable services
sudo systemctl enable game-server-web
sudo systemctl enable game-server-monitor.timer
```

### Method 3: Docker Deployment (Alternative)

#### Step 1: Install Docker
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt install docker-compose-plugin
```

#### Step 2: Deploy with Docker Compose
```bash
# Use the provided docker-compose.yml
cd game-server-deployment/deployment
docker compose up -d

# Check status
docker compose ps
docker compose logs -f
```

## Main Game Server Installation

### Step 1: Install Core Components
```bash
# Download the main setup script
wget https://raw.githubusercontent.com/J35867U/game-server/main/setup.sh
chmod +x setup.sh

# Run installation
sudo ./setup.sh
```

### Step 2: Configure Sunshine GameStream
```bash
# Edit Sunshine configuration
sudo nano /etc/sunshine/sunshine.conf

# Key settings:
# - sunshine_name = your-server-name
# - port = 47984
# - encoder = software (or hardware if available)
# - fps = [30, 60]
# - resolutions = [1280x720, 1920x1080]
```

### Step 3: Configure CoinOps
```bash
# Setup ROM directory
sudo mkdir -p /opt/coinops/roms
sudo chown gameuser:gameuser /opt/coinops/roms

# Configure web interface
sudo nano /home/gameuser/coinops-web/config.json

# Key settings:
# - port: 8080
# - romsPath: "/opt/coinops/roms"
# - savesPath: "/opt/coinops/saves"
```

### Step 4: Setup X11 Display
```bash
# Configure virtual display
sudo nano /etc/X11/xorg.conf

# Add virtual display configuration for headless operation
# Configure appropriate resolution and color depth
```

## Service Configuration

### Systemd Services

#### Game Server Web Interface
```bash
# Enable and start web interface
sudo systemctl enable --now game-server-web

# Check status
systemctl status game-server-web

# View logs
journalctl -u game-server-web -f
```

#### Monitoring Timer
```bash
# Enable monitoring timer
sudo systemctl enable --now game-server-monitor.timer

# Check timer status
systemctl list-timers game-server-*

# Run manual monitoring check
sudo systemctl start game-server-monitor.service
```

#### Core Game Services
```bash
# Enable core services
sudo systemctl enable --now sunshine
sudo systemctl enable --now x11-server
sudo systemctl enable --now openbox

# Check all service status
game-server status
```

### Automated Tasks

#### Backup Cron Jobs
```bash
# Edit crontab for automated backups
sudo crontab -e

# Add backup schedules:
# Daily at 2 AM
0 2 * * * /opt/game-server-tools/scripts/backup.sh daily

# Weekly on Sunday at 3 AM  
0 3 * * 0 /opt/game-server-tools/scripts/backup.sh weekly

# Monthly on 1st at 4 AM
0 4 1 * * /opt/game-server-tools/scripts/backup.sh monthly
```

#### Monitoring Schedule
```bash
# Monitoring runs every 15 minutes via systemd timer
# Additional status checks can be scheduled:

# Daily status email at 8 AM
0 8 * * * /opt/game-server-tools/scripts/status.sh | mail -s "Game Server Status" admin@example.com
```

## Network and Security Setup

### Firewall Configuration
```bash
# Enable UFW firewall
sudo ufw enable

# Allow SSH (adjust port as needed)
sudo ufw allow 22/tcp

# Allow Sunshine GameStream ports
sudo ufw allow 47984:47990/tcp
sudo ufw allow 47984:47990/udp

# Allow web interface
sudo ufw allow 8080/tcp

# Allow local network access (adjust range as needed)
sudo ufw allow from 192.168.1.0/24

# Check firewall status
sudo ufw status verbose
```

### Tailscale Integration (Optional)
```bash
# Install Tailscale for secure remote access
curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate and connect
sudo tailscale up

# Configure for game streaming
sudo tailscale set --accept-routes --accept-dns=false
```

### SSL/TLS Setup (Optional)
```bash
# Install certbot for Let's Encrypt certificates
sudo apt install certbot

# Generate certificate (requires domain name)
sudo certbot certonly --standalone -d gameserver.yourdomain.com

# Configure services to use certificates
# Update Sunshine and web interface configurations
```

## Configuration and Customization

### NTFY Notifications
```bash
# Configure NTFY for alerts and status updates
export NTFY_SERVER="https://ntfy.sh"
export NTFY_TOPIC_GAMESERVER="gameserver-$(hostname)-alerts"

# Test notification
curl -d "Game server deployment completed" \
     -H "Title: Game Server Alert" \
     -H "Priority: low" \
     -H "Tags: gaming,deployment" \
     $NTFY_SERVER/$NTFY_TOPIC_GAMESERVER

# Add to environment configuration
echo "export NTFY_TOPIC_GAMESERVER='$NTFY_TOPIC_GAMESERVER'" >> ~/.bashrc
```

### Backup Configuration
```bash
# Configure backup settings
sudo nano /etc/game-server/game-server.conf

# Key backup settings:
# - retention_daily = 7
# - retention_weekly = 4  
# - retention_monthly = 3
# - encrypt_backups = true
# - gpg_recipient = your-email@domain.com

# Setup GPG for backup encryption
gpg --gen-key
gpg --export-secret-keys > /secure/location/private-key.asc
```

### Web Interface Customization
```bash
# Customize web interface settings
sudo nano /opt/game-server-tools/enhanced-web.js

# Environment variables:
export COINOPS_PORT=8080
export COINOPS_HOST=0.0.0.0
export SERVER_NAME="My Game Server"
export ADMIN_EMAIL="admin@example.com"

# Restart web interface
sudo systemctl restart game-server-web
```

## ROM and Game Setup

### ROM Collection Management
```bash
# Create ROM directory structure
sudo mkdir -p /opt/coinops/roms/{arcade,console,handheld}
sudo chown -R gameuser:gameuser /opt/coinops/roms

# Set proper permissions
sudo chmod -R 755 /opt/coinops/roms

# Example ROM organization:
# /opt/coinops/roms/
# ├── arcade/
# │   ├── mame/
# │   └── fbneo/
# ├── console/
# │   ├── nes/
# │   ├── snes/  
# │   ├── genesis/
# │   └── n64/
# └── handheld/
#     ├── gb/
#     ├── gbc/
#     └── gba/
```

### RetroArch Configuration
```bash
# Configure RetroArch
sudo -u gameuser retroarch --menu

# Key configurations:
# - Video driver: gl (hardware acceleration)
# - Audio driver: pulse
# - Input driver: udev
# - Core directory: /usr/lib/x86_64-linux-gnu/libretro/

# Save configuration
# Configuration saved to: /home/gameuser/.config/retroarch/
```

### Save Game Management
```bash
# Setup save game directories
sudo mkdir -p /opt/coinops/saves/{arcade,console,handheld}
sudo mkdir -p /opt/coinops/saves/states
sudo chown -R gameuser:gameuser /opt/coinops/saves

# Configure automatic save game backups
# Save games are included in automated backup system
```

## Testing and Validation

### System Testing
```bash
# Run comprehensive status check
game-server status

# Test individual components
game-server monitor
game-server backup daily
curl http://localhost:8080

# Check service dependencies
systemctl list-dependencies sunshine
systemctl list-dependencies game-server-web
```

### Network Testing
```bash
# Test Moonlight connectivity
telnet localhost 47984

# Test from client device
ping <server-ip>
telnet <server-ip> 47984

# Test web interface
curl -I http://<server-ip>:8080
```

### Performance Testing
```bash
# Check hardware acceleration
vainfo
nvidia-smi (if NVIDIA GPU)

# Monitor system resources during gaming
htop
iostat -x 1
iftop

# Test streaming performance
# Use Moonlight client to connect and test various games
```

## Client Setup

### Moonlight Client Installation

#### Windows
```powershell
# Download from GitHub releases
# Install Moonlight PC client
# Add server IP address
# Pair with PIN from web interface
```

#### Android/iOS
```bash
# Install Moonlight app from store
# Add server by IP address
# Pair with PIN code
# Configure streaming quality
```

#### Linux
```bash
# Install Moonlight Qt
sudo apt install moonlight-qt

# Or compile from source
git clone https://github.com/moonlight-stream/moonlight-qt.git
```

### Client Configuration
- **Resolution**: Match your display capabilities
- **Bitrate**: Adjust based on network bandwidth
- **Frame Rate**: 30 FPS for compatibility, 60 FPS for performance
- **HDR**: Enable if supported by both client and server

## Monitoring and Maintenance

### Daily Operations
```bash
# Check system status
game-server status

# Monitor resources
game-server monitor

# Check recent backups
ls -la /data/backups/game-server/daily/

# Review logs
tail -f /var/log/game-server/monitoring.log
```

### Weekly Maintenance
```bash
# Update system packages
sudo apt update && sudo apt upgrade

# Check disk usage
df -h
du -sh /opt/coinops/roms/

# Verify backups
game-server backup status

# Review service logs
journalctl --since="1 week ago" -u sunshine
journalctl --since="1 week ago" -u game-server-web
```

### Monthly Tasks
```bash
# Full system health check
game-server status full

# Archive old logs
sudo logrotate -f /etc/logrotate.conf

# Update ROM collection
# Add new games and remove unused ROMs

# Review and update configurations
# Check for new Sunshine/RetroArch releases
```

## Troubleshooting

### Common Issues

#### Services Not Starting
```bash
# Check service status
systemctl status sunshine coinops-web x11-server

# Check logs for errors
journalctl -u sunshine -n 50
journalctl -u coinops-web -n 50

# Verify configuration files
sudo -u gameuser sunshine --help
```

#### Streaming Issues
```bash
# Check network connectivity
ping <client-ip>
iperf3 -s (on server)
iperf3 -c <server-ip> (on client)

# Check hardware acceleration
vainfo
dmesg | grep -i "video\|gpu"

# Verify display server
echo $DISPLAY
xrandr (if display available)
```

#### Performance Issues
```bash
# Monitor system resources
htop
iotop
nethogs

# Check for bottlenecks
perf top
systemd-analyze blame

# Optimize settings
# Reduce streaming quality
# Close unnecessary services
# Enable hardware acceleration
```

#### Backup Issues
```bash
# Check backup logs
tail -f /var/log/game-server/backup.log

# Verify disk space
df -h /data/backups/

# Test GPG encryption
gpg --list-keys
echo "test" | gpg --encrypt -r your-email@domain.com
```

### Log Analysis
```bash
# Game server logs
tail -f /var/log/game-server/*.log

# System logs
journalctl -f -u sunshine
journalctl -f -u game-server-web

# Kernel logs
dmesg -T
tail -f /var/log/kern.log

# Network logs
tail -f /var/log/ufw.log
ss -tulpn | grep -E "(47984|8080)"
```

## Performance Optimization

### Hardware Acceleration
```bash
# Intel Quick Sync (recommended)
sudo apt install intel-media-va-driver
export LIBVA_DRIVER_NAME=iHD

# NVIDIA NVENC (if available)
sudo apt install libnvidia-encode1
export CUDA_VISIBLE_DEVICES=0

# Configure Sunshine for hardware encoding
# Edit /etc/sunshine/sunshine.conf:
# encoder = vaapi (for Intel)
# encoder = nvenc (for NVIDIA)
```

### Network Optimization
```bash
# Optimize network settings
echo 'net.core.rmem_max = 16777216' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 16777216' >> /etc/sysctl.conf
sysctl -p

# Enable TCP BBR congestion control
echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
```

### System Optimization
```bash
# CPU governor for gaming
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl disable cups

# Optimize I/O scheduler
echo mq-deadline | sudo tee /sys/block/sda/queue/scheduler
```

## Integration with Homelab

### Monitoring Integration
```bash
# Prometheus metrics available at:
# http://<server-ip>:8080/metrics

# Grafana dashboard configuration:
# Import game server metrics
# Create alerts for service failures
# Monitor streaming performance
```

### Backup Integration
```bash
# Integrate with existing backup systems
# Configure remote backup destinations
# Setup backup verification and restore testing

# Example: Sync to NAS
rsync -av /data/backups/game-server/ nas:/backups/game-server/
```

### Network Integration
```bash
# DNS configuration
# Add game server to local DNS
# Configure reverse DNS for monitoring

# Load balancer integration (if multiple game servers)
# Configure HAProxy or nginx for load balancing
# Setup health checks and failover
```

## Security Best Practices

### Access Control
```bash
# Use SSH key authentication only
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Configure fail2ban
sudo apt install fail2ban
sudo systemctl enable --now fail2ban

# Regular security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
```

### Data Protection
```bash
# Encrypt sensitive directories
sudo apt install ecryptfs-utils
sudo ecryptfs-setup-private

# Setup automatic backup encryption
# Configure GPG keys for backup security
# Implement backup verification procedures
```

### Network Security
```bash
# VPN-only access (recommended for remote access)
# Configure Tailscale or WireGuard
# Disable direct internet access to game server

# Monitor network activity
sudo apt install netdata
sudo systemctl enable --now netdata
```

## Conclusion

This deployment guide provides a comprehensive approach to setting up a professional-grade game server with full management capabilities. The combination of Moonlight GameStream, CoinOps emulation, and the comprehensive management tools creates a robust gaming platform suitable for home use or small-scale deployment.

### Key Success Factors
1. **Hardware acceleration** properly configured for optimal performance
2. **Network optimization** for smooth streaming experience  
3. **Automated monitoring** and alerting for proactive maintenance
4. **Regular backups** to protect valuable ROM collections and save games
5. **Security measures** to protect against unauthorized access
6. **Integration** with existing infrastructure for scalability

### Next Steps
1. Complete the deployment following this guide
2. Test all components thoroughly
3. Configure monitoring and alerting
4. Set up automated backups
5. Integrate with existing homelab infrastructure
6. Document any customizations for future reference

For ongoing support and updates, refer to the main game server repository and community resources.

---
*Happy gaming! 🎮*