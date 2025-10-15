# 🎮 Game Server

> **Moonlight GameStream + CoinOps Emulation Platform for Proxmox VMs**

A dedicated game server solution for Proxmox VE that provides game streaming via Moonlight and retro gaming emulation. **No dedicated GPU required** - optimized for CPU-based encoding and designed to be hands-off like your other homelab services.

## 🚀 Quick Start

### One-Command Setup

```bash
# On your Ubuntu 22.04 VM
wget -O setup.sh https://raw.githubusercontent.com/J35867U/game-server/main/setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

### What You Get

- **🌙 Moonlight GameStream Server** - Stream games to any device
- **🕹️ CoinOps Emulation Platform** - Retro gaming with web interface  
- **🎯 Game Server Templates** - Minecraft, Valheim, and more
- **🌐 Web Management** - Control everything via browser
- **🔒 Security Hardened** - Firewall and authentication configured
- **📊 Monitoring Ready** - Integrates with your existing monitoring stack
- **🔄 Backup Integration** - Follows your homelab backup patterns

## 📋 Requirements

### Hardware (No GPU Required!)
- **CPU**: 4+ cores, 3.0GHz+ (Intel i5-6500 or equivalent)
- **RAM**: 8GB minimum (16GB recommended)
- **Storage**: 100GB+ SSD for OS + game storage
- **Network**: Gigabit Ethernet recommended

### Software
- **Proxmox VE** host
- **Ubuntu 22.04 LTS** VM
- **Static IP** address (recommended: 192.168.100.252)

## 🏗️ Architecture

Follows the same patterns as your existing homelab infrastructure:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Moonlight     │───▶│   Game Server    │◀───│   CoinOps Web   │
│   Clients       │    │      VM          │    │   Interface     │
│                 │    │ 192.168.100.252  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
        │                        │                        │
        │              ┌──────────────────┐              │
        └──────────────│  Docker Game     │──────────────┘
                       │    Servers       │
                       │ (Minecraft, etc) │
                       └──────────────────┘
```

## 🎮 Services Included

- **Moonlight GameStream Server** (Sunshine) - Stream PC games to any device
- **CoinOps Emulation Platform** - RetroArch-based multi-system emulator
- **Web Management Interface** - Control and monitor via web browser
- **Docker Game Servers** - Ready-to-deploy Minecraft, Valheim, Factorio
- **Prometheus Metrics** - Monitoring integration for Grafana
- **Automated Backups** - Game saves and configurations

## 🌐 Network Configuration

### VM Specification
- **VMID**: 252
- **IP Address**: 192.168.100.252
- **Follows your homelab naming convention**

### Required Ports
```bash
47984-47990/tcp+udp  # Moonlight GameStream
8080/tcp             # CoinOps Web Interface
22/tcp               # SSH Management
25565/tcp            # Minecraft (optional)
2456-2458/udp        # Valheim (optional)
```

## 🎯 VM Setup Guide

### 1. Create Proxmox VM

```bash
# Create VM following your infrastructure pattern
qm create 252 \
  --name "gamelab-moonlight-stream-252" \
  --memory 16384 \
  --cores 8 \
  --net0 virtio,bridge=vmbr0 \
  --boot c --bootdisk scsi0 \
  --ostype l26 \
  --scsi0 local-lvm:100 \
  --ide2 local:iso/ubuntu-22.04-server-amd64.iso,media=cdrom \
  --agent enabled=1 \
  --cpu host

# Optional: Enable Intel iGPU passthrough if available
# qm set 252 -hostpci0 00:02,pcie=1
```

### 2. Install Ubuntu 22.04
- Boot VM and install Ubuntu 22.04 LTS Server
- Configure static IP: `192.168.100.252`
- Enable SSH server during installation
- Create initial user account

### 3. Run Setup Script

```bash
# SSH into your VM
ssh username@192.168.100.252

# Download and run setup
wget -O setup.sh https://raw.githubusercontent.com/J35867U/game-server/main/setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

## 📱 Client Setup

### Install Moonlight Client
- **Android**: [Google Play Store](https://play.google.com/store/apps/details?id=com.limelight)
- **iOS**: [App Store](https://apps.apple.com/app/moonlight-game-streaming/id1000551566)
- **Windows**: [GitHub Releases](https://github.com/moonlight-stream/moonlight-qt/releases)
- **Linux**: `sudo apt install moonlight-qt`

### Connect to Server
1. Open Moonlight client
2. Add server: `192.168.100.252`
3. Enter pairing PIN from web interface
4. Start streaming!

## 🔧 Management

### Web Interfaces
- **CoinOps**: `http://192.168.100.252:8080`
- **Sunshine Config**: `https://192.168.100.252:47990`

### Command Line
```bash
# Check service status
sudo systemctl status sunshine coinops-web

# View logs
sudo journalctl -u sunshine -f

# Restart services
sudo systemctl restart sunshine coinops-web
```

## 🔄 Integration with Existing Homelab

### Backup Integration
Game server data is backed up following your existing patterns:

```bash
# Backup locations (following your structure)
/home/gameuser/saves/     # Game saves
/home/gameuser/configs/   # Emulator configurations  
/opt/coinops/roms/        # ROM files
/home/gameuser/.config/   # Service configurations
```

### Monitoring Integration
- **Ntfy Notifications** - Status alerts sent to your notification system
- **Prometheus Metrics** - Exposed on port 9090 for Grafana integration
- **Health Checks** - Weekly system health reports
- **Log Integration** - Follows your logging standards

### Tailscale Access
Access your game server remotely via your existing Tailscale setup:

```bash
# Stream games from anywhere via Tailscale subnet routing
moonlight 192.168.100.252  # Direct access through your VPN
```

## 📊 Monitoring & Alerts

Following your homelab monitoring patterns:

- **System Health**: Weekly automated health checks
- **Service Status**: Real-time monitoring of all game services
- **Performance Metrics**: CPU, memory, and network usage tracking
- **Backup Status**: Daily backup verification and alerts
- **Security Monitoring**: Failed login attempts and firewall events

## 🔒 Security Features

- **Dedicated User**: `gameuser` with limited privileges
- **UFW Firewall**: Only gaming ports exposed
- **SSL/TLS**: Encrypted Sunshine streaming
- **SSH Hardening**: Key-based authentication recommended
- **Container Isolation**: Game servers run in Docker containers

## 📚 Documentation Structure

```
/
├── README.md                 # This file
├── setup.sh                 # Main setup script
├── status.sh                # Status check script
├── scripts/
│   ├── backup/              # Backup scripts
│   ├── monitoring/          # Health check scripts  
│   └── maintenance/         # Maintenance utilities
├── configs/
│   ├── sunshine/            # Moonlight server config
│   ├── coinops/             # Emulation platform config
│   └── systemd/             # Service definitions
├── game-servers/
│   ├── minecraft/           # Minecraft server template
│   ├── valheim/             # Valheim server template
│   └── factorio/            # Factorio server template
└── docs/
    ├── TROUBLESHOOTING.md   # Common issues and solutions
    ├── PERFORMANCE.md       # Optimization guide
    └── BACKUP_GUIDE.md      # Backup and restore procedures
```

## 🚨 Troubleshooting

### Quick Diagnostics
```bash
# Check all services
./status.sh

# View recent logs  
./scripts/monitoring/check_logs.sh

# Test connectivity
./scripts/monitoring/network_test.sh
```

### Common Issues

**Moonlight can't find server**
```bash
# Check firewall
sudo ufw status

# Verify service
sudo systemctl status sunshine
```

**Poor streaming quality**
```bash
# Check resources
htop

# Verify network
iperf3 -c 192.168.100.252
```

## 🎯 Performance Tuning

Optimized for hands-off operation like your other homelab services:

### CPU Optimization
```bash
# Performance governor (automatically set)
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

### Network Optimization  
```bash
# Gaming network buffers (automatically configured)
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
```

## 🤝 Contributing

Contributions welcome! Please follow the same patterns as your main homelab repository:

1. Fork the repository
2. Create a feature branch
3. Test your changes
4. Submit a pull request

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Ready to game? Let's get started!** 🎮

This game server integrates seamlessly with your existing homelab infrastructure while maintaining the same operational standards for monitoring, backups, and security.