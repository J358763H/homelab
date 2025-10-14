# 🎮 Game Server Deployment

Complete deployment structure for managing a **Moonlight GameStream + CoinOps Emulation** game server with comprehensive monitoring, backup, and management tools.

## Quick Start

### One-Click Deployment
```bash
# Download and run the standalone deployer
wget https://raw.githubusercontent.com/J35867U/homelab-deployment/main/game-server-deployment/scripts/standalone-deploy.sh
chmod +x standalone-deploy.sh
sudo ./standalone-deploy.sh
```

### After Installation
```bash
# Check system status
game-server status

# Run monitoring dashboard  
game-server monitor

# Create backup
game-server backup daily

# Start web interface
game-server web
# Access at: http://server-ip:8080
```

## Repository Integration

This deployment is designed to work with the main game server repository:
- **Main Repository**: [J35867U/game-server](https://github.com/J35867U/game-server)
- **Setup Script**: Compatible with `setup.sh` from main repository
- **Platform**: Ubuntu 22.04 LTS with Moonlight + CoinOps

## What's Included

### 🛠️ Management Scripts
- **`docs-archiver.sh`** - Archives documentation and configurations with GPG encryption
- **`monitoring.sh`** - Real-time system monitoring with NTFY alerts
- **`backup.sh`** - Automated ROM/save/config backups with retention policies
- **`enhanced-web.js`** - Modern Node.js dashboard with Prometheus metrics
- **`status.sh`** - Comprehensive health checking and validation
- **`standalone-deploy.sh`** - One-click installation of entire suite

### 📊 Features
- **Real-time Monitoring**: System resources, services, hardware acceleration
- **Automated Backups**: Daily/weekly/monthly with GPG encryption
- **Web Dashboard**: Mobile-responsive interface with live metrics
- **NTFY Integration**: Unified alerting and notifications
- **Prometheus Metrics**: Standard monitoring endpoint at `/metrics`
- **Systemd Services**: Proper service management and automation

### 🎮 Game Server Support
- **Sunshine GameStream**: Monitoring and configuration management
- **CoinOps Emulation**: Web interface enhancement and backup
- **RetroArch**: Configuration backup and status monitoring  
- **Hardware acceleration**: VAAPI/NVIDIA detection and optimization

## Directory Structure

```
game-server-deployment/
├── scripts/                    # All management scripts
│   ├── docs-archiver.sh       # Documentation & config archiving
│   ├── monitoring.sh          # System monitoring dashboard
│   ├── backup.sh              # ROM/save game backups
│   ├── enhanced-web.js        # Enhanced web interface
│   ├── status.sh              # Health status checker
│   └── standalone-deploy.sh   # One-click deployer
├── docs/                      # Complete documentation
│   ├── README.md             # Detailed overview and usage
│   ├── DEPLOYMENT_GUIDE.md   # Step-by-step deployment
│   └── TOOLS_SUMMARY.md      # Comprehensive tool reference
└── deployment/               # Deployment configurations
    └── systemd/              # Service definitions
```

## Installation Methods

### Method 1: Standalone Deployment (Recommended)
```bash
# Downloads, installs, and configures everything
sudo ./scripts/standalone-deploy.sh

# Creates 'game-server' command for easy management
# Sets up systemd services and automation
# Configures monitoring, backups, and web interface
```

### Method 2: Manual Installation
```bash
# Clone this deployment structure
git clone <this-repo>
cd game-server-deployment

# Make scripts executable
chmod +x scripts/*.sh

# Install individually
./scripts/monitoring.sh       # System monitoring
./scripts/backup.sh daily     # Backup creation
node scripts/enhanced-web.js  # Web interface
```

## Configuration

### Environment Setup
```bash
# NTFY Notifications (recommended)
export NTFY_SERVER="https://ntfy.sh"
export NTFY_TOPIC_GAMESERVER="gameserver-$(hostname)"

# Game Server Paths
export ROMS_PATH="/opt/coinops/roms"
export SAVES_PATH="/opt/coinops/saves"
export CONFIG_PATH="/home/gameuser/.config"

# Backup Settings
export BACKUP_DIR="/data/backups/game-server"
export ENCRYPT_BACKUPS="true"
export GPG_RECIPIENT="your-email@domain.com"
```

### NTFY Notifications Setup
```bash
# 1. Install NTFY app on phone/desktop
# 2. Choose unique topic name
export NTFY_TOPIC_GAMESERVER="gameserver-$(hostname)-$(date +%s)"

# 3. Test notification
curl -d "Game server is ready!" https://ntfy.sh/$NTFY_TOPIC_GAMESERVER

# 4. Subscribe to your topic in NTFY app
```

## Usage Examples

### Daily Operations
```bash
# Quick status check
game-server status quick

# Full monitoring dashboard
game-server monitor

# Create manual backup
game-server backup daily

# Check web interface
curl http://localhost:8080/api/status
```

### Automated Services
```bash
# Web interface (systemd service)
systemctl status game-server-web
systemctl restart game-server-web

# Monitoring timer (every 15 minutes)
systemctl status game-server-monitor.timer

# Check scheduled backups
crontab -l | grep game-server
```

## Integration with Main Game Server

### Before Using These Tools
1. **Install the main game server** using the repository setup script:
   ```bash
   wget https://raw.githubusercontent.com/J35867U/game-server/main/setup.sh
   chmod +x setup.sh
   sudo ./setup.sh
   ```

2. **Configure your game server** (Sunshine, CoinOps, RetroArch)

3. **Then deploy these management tools** for monitoring and maintenance

### Compatibility
- Designed for Ubuntu 22.04 LTS (main game server platform)
- Compatible with existing Sunshine and CoinOps configurations
- Integrates with RetroArch and emulation setup
- Works alongside existing systemd services

## Homelab Integration

### Monitoring Integration
- **Prometheus metrics** available at `http://server:8080/metrics`
- **Grafana dashboards** can use the metrics for visualization
- **NTFY notifications** integrate with homelab alerting

### Backup Integration
- **Retention policies** align with homelab backup strategies
- **GPG encryption** compatible with homelab security practices
- **Storage locations** can be configured for NAS or shared storage

### Network Integration  
- **Tailscale compatible** for secure remote access
- **UFW firewall** follows homelab security patterns
- **Port management** documented for network planning

## Security Features

### Data Protection
- **GPG encryption** for backup archives and sensitive configurations
- **Proper file permissions** and access controls
- **Dedicated service user** (gameuser) for isolation

### Network Security
- **Firewall integration** with UFW
- **VPN compatibility** (Tailscale/WireGuard)
- **Local network restrictions** and access controls

## Troubleshooting

### Common Issues
```bash
# Services not running
systemctl status sunshine coinops-web
journalctl -u game-server-web -f

# Network connectivity
ss -tulpn | grep -E "(47984|8080)"
curl http://localhost:8080

# Hardware acceleration
vainfo                    # Intel/AMD
nvidia-smi               # NVIDIA

# Backup issues  
tail -f /var/log/game-server/backup.log
```

### Log Locations
- **Management tools**: `/var/log/game-server/`
- **System services**: `journalctl -u game-server-*`
- **Web interface**: `journalctl -u game-server-web`

## Support and Documentation

### Complete Documentation
- **[README.md](docs/README.md)** - Detailed overview and usage guide
- **[DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md)** - Complete deployment instructions  
- **[TOOLS_SUMMARY.md](docs/TOOLS_SUMMARY.md)** - Comprehensive tool reference

### Getting Help
- **Main Repository**: [J35867U/game-server](https://github.com/J35867U/game-server)
- **Issues**: Submit to main repository for game server issues
- **Tools**: Management tool issues can be addressed separately

### Contact
- **Maintainer**: J35867U
- **Email**: mrnash404@protonmail.com

---

## 🎮 Ready to Deploy!

This deployment provides enterprise-grade management tools for your game server:

✅ **Comprehensive Monitoring** - Real-time system and service monitoring  
✅ **Automated Backups** - ROMs, saves, and configurations protected  
✅ **Enhanced Web Interface** - Modern dashboard with live metrics  
✅ **Professional Logging** - Centralized logs and error tracking  
✅ **NTFY Integration** - Unified alerting and notifications  
✅ **Homelab Compatible** - Integrates with existing infrastructure  

**Quick Deploy**: `sudo ./scripts/standalone-deploy.sh`  
**Quick Status**: `game-server status`  
**Web Dashboard**: `http://server-ip:8080`

Happy gaming! 🎮