# 🏠 Simple Homelab Setup

Clean, organized Docker homelab with manual control over service groups.

**Maintainer:** J35867U
**Last Updated:** 2025-10-16

## Structure

```
homelab/
├── containers/
│   ├── core/           # VPN & networking (Gluetun, FlareSolverr)
│   ├── downloads/      # Download clients (qBittorrent, NZBGet)
│   └── media/          # Media management & streaming (Jellyfin, Servarr)
├── setup/              # Simple deployment scripts
└── docs/               # Documentation
```

## Quick Start

### 1. Setup Environment
```bash
cd setup
./prepare.sh
```

### 2. Deploy Step by Step
```bash
# Start core services first (VPN)
cd containers/core
docker-compose up -d

# Then downloads (depends on VPN)
cd ../downloads
docker-compose up -d

# Finally media services
cd ../media
docker-compose up -d
```

### 3. Or Deploy Everything
```bash
cd setup
./deploy-all.sh
```

## Service Access

Once deployed, access your services at:

### 🎬 **Media Services**
- **Jellyfin**: http://localhost:8096 - Media server
- **Sonarr**: http://localhost:8989 - TV show automation
- **Radarr**: http://localhost:7878 - Movie automation
- **Bazarr**: http://localhost:6767 - Subtitles
- **Prowlarr**: http://localhost:9696 - Indexer management
- **JellyStat**: http://localhost:3000 - Analytics

### 📥 **Download Services**
- **qBittorrent**: http://localhost:8080 - Torrent client
- **NZBGet**: http://localhost:6789 - Usenet client

### 🔧 **Optional: LXC Infrastructure** (Proxmox only)
- **Nginx Proxy Manager**: http://192.168.1.201:81 - Reverse proxy
- **Pi-hole**: http://192.168.1.205:80 - DNS & ad blocking
- **Ntfy**: http://192.168.1.203:80 - Push notifications
- **Vaultwarden**: http://192.168.1.206:80 - Password manager

## Management

```bash
# Check status
docker ps

# View logs
docker logs [container_name]

# Restart service group
cd containers/[group]
docker-compose restart

# Deploy LXC services (Proxmox)
cd setup
./deploy-lxc.sh

# Stop everything
cd setup
./stop-all.sh
```

- **Jellyfin** (Media Server): `http://your-server-ip:8096`
- **Sonarr** (TV Shows): `http://your-server-ip:8989`
- **Radarr** (Movies): `http://your-server-ip:7878`
- **Prowlarr** (Indexers): `http://your-server-ip:9696`
- **Jellyseerr** (Requests): `http://your-server-ip:5055`
- **qBittorrent** (Downloads): `http://your-server-ip:8080`

## 🔄 Lifecycle Management
- **`./homelab.sh deploy`** → Build and schedule everything
- **`./homelab.sh teardown`** → Stop containers, remove cron jobs, preserve data
- **`./homelab.sh reset`** → Teardown and redeploy in one go
- **`./homelab.sh status`** → Check containers, cron jobs, services, and system health

## 🏗️ What's Included
### 🎬 Media Stack

- **Jellyfin** - Media server and streaming platform
- **Sonarr** - TV show collection manager
- **Radarr** - Movie collection manager
- **Bazarr** - Subtitle manager
- **Prowlarr** - Indexer manager for torrents and usenet
- **Jellyseerr** - Request management for users

### 📥 Download Clients

- **qBittorrent** - Torrent client (VPN-protected)
- **NZBGet** - Usenet client
- **Gluetun** - VPN container for secure downloading

### 🤖 Automation & Analytics

- **Jellystat** - Jellyfin usage analytics
- **YouTube Integration** - Automated YouTube content downloading
- **Recyclarr** - Quality profile management
- **Tunarr** - Custom channel creation

### 📊 Monitoring & Maintenance

- **Daily backup summaries** with Restic
- **Weekly system health reports**
- **HDD health monitoring** with SMART
- **Automated maintenance tasks**
- **Ntfy notifications** for alerts and summaries

## 🛡️ Security Features
- **VPN Integration** - All download traffic routed through VPN
- **Network Isolation** - Containers on dedicated Docker network
- **Secret Management** - Environment variables for sensitive data
- **Regular Updates** - Automated security update notifications

## 📦 System Requirements
- **OS**: Ubuntu/Debian-based system (20.04+ recommended)
- **RAM**: Minimum 4GB, 8GB+ recommended
- **Storage**: 100GB minimum, 500GB+ recommended for media
- **Network**: Reliable internet connection
- **Dependencies**: Docker, Docker Compose, Git

📋 **For detailed hardware specifications and architecture planning, see [Hardware Architecture Guide](HARDWARE_ARCHITECTURE.md)**

## 🔧 Configuration
### Environment Variables

Edit `deployment/.env` with your settings:

- VPN credentials (WireGuard)
- Database passwords
- API keys
- Notification settings
- Backup configuration

### VPN Setup

Configure `deployment/wg0.conf` with your VPN provider's WireGuard settings.

### Media Organization

The system organizes media in `/data/media/`:

```
/data/media/
├── movies/     # Movie files
├── shows/      # TV show files
├── music/      # Music library
└── youtube/    # YouTube downloads

```
## 📚 Documentation
Comprehensive documentation is available in the `/docs` directory:

- **[Getting Started](docs/Documentation_Master.md)** - Complete documentation index
- **[Directory Structure](docs/Directory_Tree_v1.0.txt)** - File organization
- **[Troubleshooting](deployment/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Deployment Checklist](deployment/DEPLOYMENT_CHECKLIST.md)** - Pre-deployment verification

## 🔄 Backup & Recovery
### Automated Backups

- **Restic** - Encrypted, incremental backups
- **Daily summaries** - Backup status reports
- **Documentation archiving** - Config and documentation backups

### Disaster Recovery

1. **Fresh Installation**: Clone repo on new system
2. **Configuration**: Copy backed-up `.env` and `wg0.conf`
3. **Deployment**: Run `./homelab.sh deploy`
4. **Data Restoration**: Restore from Restic backup

## 📈 Monitoring & Alerts
### Health Checks

- Container status monitoring
- System resource tracking
- Disk health (SMART) monitoring
- Network connectivity verification

### Notifications

Integrated with **Ntfy** for real-time alerts:

- Backup completion/failure
- System health summaries
- Critical service failures
- Weekly health reports

## 🤝 Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📝 Changelog
See [changelog.md](changelog.md) for detailed version history.

## 📞 Support
- **Issues**: Use GitHub Issues for bug reports and feature requests
- **Discussions**: GitHub Discussions for questions and community support
- **Maintainer**: J35867U (<mrnash404@protonmail.com>)

## ⚖️ License
This project is open source. See individual components for their respective licenses.

## 🙏 Acknowledgments
Built with and inspired by:

- **Linuxserver.io** containers
- **Servarr** applications
- **Jellyfin** media server
- **Gluetun** VPN client
- **Restic** backup tool

---

**⭐ Star this repository if you find it helpful!**

Made with ❤️ for the self-hosting community.
