# 🎮 Game Server Deployment

## Overview
This directory contains a complete deployment structure for managing a **Moonlight GameStream + CoinOps Emulation** game server. The tools are designed as a companion to the main game server setup, providing comprehensive monitoring, backup, and management capabilities.

## Repository Integration
- **Main Repository**: [J35867U/game-server](https://github.com/J35867U/game-server)
- **Setup Script**: Based on `setup.sh` from the main repository
- **Documentation**: Automated archiving of repository documentation
- **Compatibility**: Designed for Ubuntu 22.04 LTS game servers

## Directory Structure
```
game-server-deployment/
├── scripts/                    # Management scripts
│   ├── docs-archiver.sh       # Documentation archiving with GPG encryption
│   ├── monitoring.sh          # Comprehensive system monitoring
│   ├── backup.sh              # Automated backup with retention policies
│   ├── enhanced-web.js        # Enhanced Node.js web interface
│   ├── status.sh              # System status checker
│   └── standalone-deploy.sh   # One-click deployment script
├── docs/                      # Documentation
│   ├── README.md             # This file
│   ├── DEPLOYMENT_GUIDE.md   # Complete deployment instructions
│   ├── TOOLS_SUMMARY.md      # Overview of all management tools
│   └── INTEGRATION_GUIDE.md  # Integration with homelab infrastructure
└── deployment/               # Deployment configurations
    ├── docker-compose.yml    # Container orchestration (if needed)
    ├── systemd/             # Systemd service definitions
    └── configs/             # Configuration templates
```

## Core Components

### 🎮 Game Server Platform
- **Sunshine**: Moonlight GameStream server for game streaming
- **CoinOps**: Retro gaming emulation platform with web interface
- **RetroArch**: Multi-system emulator backend
- **X11 Server**: Virtual display server for headless operation

### 📊 Management Tools
1. **Documentation Archiver** (`docs-archiver.sh`)
   - Archives GitHub repository content
   - Creates system snapshots and configuration backups
   - GPG encryption support for sensitive data
   - NTFY notifications for completion status

2. **Monitoring Dashboard** (`monitoring.sh`)
   - Real-time system resource monitoring
   - Service health checks and status reporting
   - Hardware acceleration detection (VAAPI/NVIDIA)
   - Gaming-specific metrics and performance data
   - Automated alerting via NTFY

3. **Backup System** (`backup.sh`)
   - Automated backup of ROMs, save games, and configurations
   - Flexible retention policies (daily/weekly/monthly)
   - GPG encryption for backup security
   - Integrity verification and automated cleanup

4. **Enhanced Web Interface** (`enhanced-web.js`)
   - Modern Node.js dashboard replacing basic CoinOps web
   - Prometheus metrics endpoint for monitoring integration
   - Real-time system status and gaming statistics
   - Mobile-responsive design with auto-refresh

5. **Status Checker** (`status.sh`)
   - Comprehensive health verification
   - Service status validation
   - Network connectivity testing
   - Hardware acceleration verification

6. **Standalone Deployer** (`standalone-deploy.sh`)
   - One-click installation of all management tools
   - Systemd service creation and automation setup
   - Cron job configuration for scheduled tasks
   - Complete environment preparation

## Quick Start

### 1. Clone or Download
```bash
# If you have access to the deployment structure
git clone <this-deployment-repo>
cd game-server-deployment

# Or download individual scripts as needed
```

### 2. Quick Deployment
```bash
# Run the standalone deployer for complete setup
sudo ./scripts/standalone-deploy.sh

# This installs all tools and creates the 'game-server' command
```

### 3. Manual Installation
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Test individual components
./scripts/status.sh
./scripts/monitoring.sh
./scripts/backup.sh daily
```

### 4. Integration with Existing Game Server
If you already have a game server running:
```bash
# Copy scripts to your server
scp scripts/*.sh gameserver:/opt/game-server-tools/

# Run monitoring
./scripts/monitoring.sh

# Setup automated backups
./scripts/backup.sh daily
```

## Configuration

### Environment Variables
```bash
# NTFY Notifications (recommended for alerts)
export NTFY_SERVER="https://ntfy.sh"
export NTFY_TOPIC_GAMESERVER="your-game-server-topic"

# Game Server Paths
export ROMS_PATH="/opt/coinops/roms"
export SAVES_PATH="/opt/coinops/saves"
export CONFIG_PATH="/home/gameuser/.config"

# Web Interface
export COINOPS_PORT="8080"
export MOONLIGHT_PORT="47984"

# Backup Configuration
export BACKUP_DIR="/data/backups/game-server"
export ENCRYPT_BACKUPS="true"
export GPG_RECIPIENT="your-email@domain.com"
```

### NTFY Notifications Setup
```bash
# 1. Choose a unique topic name
export NTFY_TOPIC_GAMESERVER="gameserver-$(hostname)-$(date +%s)"

# 2. Test notifications
curl -d "Test notification from game server" https://ntfy.sh/$NTFY_TOPIC_GAMESERVER

# 3. Subscribe on your phone/desktop
# Install NTFY app and subscribe to your topic
```

## Service Integration

### Systemd Services (Created by standalone deployer)
```bash
# Web interface service
systemctl enable --now game-server-web
systemctl status game-server-web

# Monitoring timer (every 15 minutes)
systemctl enable --now game-server-monitor.timer
systemctl list-timers game-server-*

# Check logs
journalctl -u game-server-web -f
```

### Cron Jobs (Automated backups)
```bash
# Daily backup at 2 AM
0 2 * * * /opt/game-server-tools/scripts/backup.sh daily

# Weekly backup on Sunday at 3 AM  
0 3 * * 0 /opt/game-server-tools/scripts/backup.sh weekly

# Monthly backup on 1st at 4 AM
0 4 1 * * /opt/game-server-tools/scripts/backup.sh monthly
```

## Usage Examples

### Daily Operations
```bash
# Check overall system status
game-server status

# Run monitoring dashboard
game-server monitor

# Create manual backup
game-server backup daily

# Start web interface
game-server web
```

### Monitoring and Alerts
```bash
# Quick system check
./scripts/monitoring.sh quick

# Full monitoring with all metrics
./scripts/monitoring.sh

# Service-specific checks
./scripts/monitoring.sh services

# Performance monitoring
./scripts/monitoring.sh performance
```

### Backup Management
```bash
# Different backup types
./scripts/backup.sh daily
./scripts/backup.sh weekly  
./scripts/backup.sh monthly

# Check backup status
./scripts/backup.sh status

# Cleanup old backups
./scripts/backup.sh cleanup
```

### Documentation Archiving
```bash
# Archive repository and system info
./scripts/docs-archiver.sh

# Archives are saved to: /data/backups/game-server-docs/
# Includes: repo content, configs, system info, logs
```

## Integration with Homelab Infrastructure

### Monitoring Integration
- **Prometheus**: Enhanced web interface provides `/metrics` endpoint
- **Grafana**: Dashboard templates available for visualization
- **NTFY**: Unified notification system with homelab alerts

### Backup Integration
- **Retention Policies**: Align with homelab backup strategies
- **Storage**: Can use same backup infrastructure as homelab
- **Encryption**: GPG encryption compatible with homelab security

### Network Integration
- **Tailscale**: Compatible with homelab VPN setup
- **Firewall**: Uses UFW like other homelab services
- **Ports**: Documented port usage for network management

## Security Considerations

### Backup Security
- ROMs and save games are encrypted using GPG
- Backup archives use strong compression and encryption
- Retention policies prevent unlimited storage growth

### Network Security  
- Firewall configuration for required ports only
- Integration with Tailscale for secure remote access
- Web interface includes basic authentication options

### Access Control
- Dedicated `gameuser` account for service isolation
- Proper file permissions and directory structure
- Systemd service security with user/group isolation

## Troubleshooting

### Common Issues

**Services not starting:**
```bash
# Check service status
systemctl status sunshine coinops-web x11-server

# Check logs
journalctl -u sunshine -f
journalctl -u coinops-web -f

# Verify ports
ss -tulpn | grep -E "(47984|8080)"
```

**Hardware acceleration issues:**
```bash
# Check VAAPI
vainfo

# Check NVIDIA
nvidia-smi

# Check Intel graphics
lspci | grep -i "intel.*graphics"
```

**Backup failures:**
```bash
# Check backup logs
tail -f /var/log/game-server/backup.log

# Verify directories
ls -la /opt/coinops/roms/
ls -la /data/backups/game-server/

# Test GPG encryption
gpg --list-keys
```

**Network connectivity:**
```bash
# Test Moonlight port
telnet localhost 47984

# Test web interface
curl http://localhost:8080

# Check firewall
ufw status
```

### Log Locations
- **Game Server Logs**: `/var/log/game-server/`
- **System Logs**: `journalctl -u game-server-*`
- **Backup Logs**: `/var/log/game-server/backup.log`
- **Monitoring Logs**: `/var/log/game-server/monitoring.log`

## Development and Customization

### Extending the Tools
The management scripts are designed to be modular and extensible:

1. **Add new monitoring checks** in `monitoring.sh`
2. **Customize backup retention** in `backup.sh`  
3. **Enhance web interface** by modifying `enhanced-web.js`
4. **Add new status checks** in `status.sh`

### Contributing
This toolset complements the main game server repository:
- Main game server: [J35867U/game-server](https://github.com/J35867U/game-server)
- Issues and improvements: Submit to the main repository
- Management tools: Can be extended independently

## Support

### Getting Help
- **Documentation**: Check `docs/` directory for detailed guides
- **Logs**: Review log files for error details  
- **Status**: Run `game-server status` for system overview
- **Community**: Main repository issues and discussions

### Contact Information
- **Maintainer**: J35867U
- **Email**: mrnash404@protonmail.com
- **Repository**: [J35867U/game-server](https://github.com/J35867U/game-server)

---

## 🎮 Ready to Game!

This deployment structure provides enterprise-grade management tools for your game server, ensuring reliable operation, comprehensive monitoring, and automated maintenance. Whether you're running a single game server or integrating with a larger homelab infrastructure, these tools provide the foundation for professional game server management.

**Next Steps:**
1. Deploy the tools using `standalone-deploy.sh`
2. Configure NTFY notifications for monitoring alerts
3. Set up automated backups for your ROMs and save games
4. Monitor your game server through the enhanced web interface
5. Integrate with your existing homelab monitoring and backup systems

Happy gaming! 🎮